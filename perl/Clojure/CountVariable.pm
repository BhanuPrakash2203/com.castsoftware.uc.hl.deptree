package Clojure::CountVariable;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Clojure::ClojureNode;
use Clojure::Config;

my $BadVariableUpdate__mnemo = Ident::Alias_BadVariableUpdate();
my $UnexpectedConditionalLet__mnemo = Ident::Alias_UnexpectedConditionalLet();
my $VariableNameLengthAverage__mnemo = Ident::Alias_VariableNameLengthAverage();
my $ShortVarName__mnemo = Ident::Alias_ShortVarName();
my $GlobalVariableHidding__mnemo = Ident::Alias_GlobalVariableHidding();

my $nb_BadVariableUpdate = 0;
my $nb_UnexpectedConditionalLet = 0;
my $nb_VariableNameLengthAverage = 0;
my $nb_ShortVarName = 0;
my $nb_GlobalVariableHidding = 0;

sub checkVariableLength($$$$) {
	my $name = shift;
	my $defTotalLength = shift;
	my $nb_explicitNamedDef = shift;
	my $line = shift;
	
	if ($name =~ /^[\w#\;]/m) {
		$$defTotalLength += length $name;
		$$nb_explicitNamedDef++;
		if (length $name < Clojure::Config::VARIABLE_LENGTH_THRESHOLD) {
			$nb_ShortVarName++;
			Erreurs::VIOLATION($ShortVarName__mnemo, "Short variable name ($name) at line $line");
		}
	}
}

sub CountVariable($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_BadVariableUpdate = 0;
    $nb_VariableNameLengthAverage = 0;
    $nb_ShortVarName = 0;
    $nb_UnexpectedConditionalLet = 0;
    $nb_GlobalVariableHidding = 0;
    

	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $BadVariableUpdate__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnexpectedConditionalLet__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $GlobalVariableHidding__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my %H_names = ();
	
	my $nb_explicitNamedDef;
	my $defTotalLength = 0;

	#*******************************************************************
	#                    GLOBAL VARIABLE
	#*******************************************************************
	
	my $defs = $KindsLists->{&DefKind};
	my %H_GLOBAL = ();
	
	for my $def (@$defs) {
		my $name = GetName($def);
		$H_GLOBAL{$name} = GetLine($def);
	
		checkVariableLength($name, \$defTotalLength, \$nb_explicitNamedDef, GetLine($def));
		
		if (defined $name) {
			if (exists $H_names{$name}) {
				$nb_BadVariableUpdate++;
				Erreurs::VIOLATION($BadVariableUpdate__mnemo, "Bad global variable update ($name) at line ".GetLine($def));
			}
		}
		$H_names{$name} = 1;
	}
	
	# CHECK for gloval var shadowed by function parameter
	my @Functions = (
		@{$KindsLists->{&FunctionKind}},
		@{$KindsLists->{&FunctionArityKind}},
		@{$KindsLists->{&AnonymousKind}}
	);
		
	for my $func (@Functions) {
		my $params = Clojure::ClojureNode::getClojureKindData($func, 'params') || [];
		
		for my $param (@$params) {
			if (exists $H_GLOBAL{$param}) {
				$nb_GlobalVariableHidding++;
				Erreurs::VIOLATION($GlobalVariableHidding__mnemo, "parameter at line ".GetLine($func)." is hidding global var '$param' at line $H_GLOBAL{$param}\n");
			}
		}
	}
	
	#*******************************************************************
	#                    LOCAL VARIABLE
	#*******************************************************************
	
	# SPEC : missing if-let
	# if-let does not support several variables.

	# Count one violation each time a let has:
	# - a single parameter
	# - a single instruction that is a 'if'
	# - the variable is involved in the condition of the if

	my $lets = $KindsLists->{&LetKind};
	
	for my $let (@$lets) {
		my $H_variables = Clojure::ClojureNode::getClojureKindData($let, 'variables');
		my @vars = keys %$H_variables;
		
		# CHECK for global variable shadowing
		for my $var (@vars) {
			
			checkVariableLength($var, \$defTotalLength, \$nb_explicitNamedDef, GetLine($let));
			
			if (exists $H_GLOBAL{$var}) {
				$nb_GlobalVariableHidding++;
				Erreurs::VIOLATION($GlobalVariableHidding__mnemo, "local var at line ".GetLine($let)." is hidding global var '$var' at line $H_GLOBAL{$var}\n");
			}
		}
		
		# CHECH for missing if-let ONLY if :
		# 1 - there is only one variable
		if (scalar @vars ==1) {
			my $varName = $vars[0];
			
			# 2 - the variable is not a list of variable (destructuring assignment)
			if ($varName !~ /\s*\[/) {
				my $children = GetChildren($let);
				if (scalar @$children == 1) {
					my $child = $children->[0]; 
					if (IsKind($child, IfKind) || IsKind($child, WhenKind)) {
						my $ifChildren = GetChildren($child);
						my $cond = ${GetStatement($ifChildren ->[0])};
						# 3 - the variable is involved in the condition
						if ($cond =~ /$varName/) {
							$nb_UnexpectedConditionalLet++;
							Erreurs::VIOLATION($UnexpectedConditionalLet__mnemo, "Missing ".(IsKind($child, IfKind) ? "if-let" : "when-let")." (for variable '$varName') at line ".GetLine($let));
						}
					}
				}
			}
		}
	}
	
	if ($nb_explicitNamedDef) {
		$nb_VariableNameLengthAverage = int($defTotalLength/$nb_explicitNamedDef);
	}
	
	Erreurs::VIOLATION($VariableNameLengthAverage__mnemo, "[METRIC] Variable name length average = $nb_VariableNameLengthAverage");
	
	$ret |= Couples::counter_update($compteurs, $BadVariableUpdate__mnemo, $nb_BadVariableUpdate );
	$ret |= Couples::counter_update($compteurs, $VariableNameLengthAverage__mnemo, $nb_VariableNameLengthAverage );
	$ret |= Couples::counter_update($compteurs, $ShortVarName__mnemo, $nb_ShortVarName );
	$ret |= Couples::counter_update($compteurs, $UnexpectedConditionalLet__mnemo, $nb_UnexpectedConditionalLet );
	$ret |= Couples::counter_update($compteurs, $GlobalVariableHidding__mnemo, $nb_GlobalVariableHidding );
	
    return $ret;
}

1;



