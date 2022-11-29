
package TypeScript::CountVariable ;

use strict;
use warnings;

use Erreurs;
use Lib::Node;
use Lib::NodeUtil;
use TypeScript::TypeScriptNode;

use Ident;
use TypeScript::Identifiers;
use TypeScript::CountNaming;

my $IDENTIFIER = TypeScript::Identifiers::getIdentifiersPattern();
my $IDENT_CHAR = TypeScript::Identifiers::getIdentifiersCharacters();
my $DEREF_EXPR = TypeScript::Identifiers::getDereferencementPattern();
my $DEBUG = 0;

my $SELECTOR = '(?:document\.getElementById|\$)\s*\(';

use constant LIMIT_SHORT_GLOBALVAR_NAMES => 5;

my $mnemo_ShortGlobalNamesLT = Ident::Alias_ShortGlobalNamesLT();
my $mnemo_BadVariableNames = Ident::Alias_BadVariableNames();
my $mnemo_BadSelectorCaching = Ident::Alias_BadSelectorCaching();
my $mnemo_ImpliedGlobalVar = Ident::Alias_ImpliedGlobalVar();
my $mnemo_MultipleDeclarationsInSameStatement = Ident::Alias_MultipleDeclarationsInSameStatement();
my $mnemo_VariableShadow = Ident::Alias_VariableShadow();
my $mnemo_ParameterShadow = Ident::Alias_ParameterShadow();

my $nb_ShortGlobalNamesLT = 0;
my $nb_BadVariableNames = 0;
my $nb_BadSelectorCaching = 0;
my $nb_ImpliedGlobalVar = 0;
my $nb_MultipleDeclarationsInSameStatement = 0;
my $nb_MultipleDeclarationShadow = 0;
my $nb_VariableShadow = 0;
my $nb_ParameterShadow = 0;
#my $nb_VariableDeclarations = 0;

my $UnitAnalysisStarted = 0;

sub startUnitAnalysis() {
  $UnitAnalysisStarted = 1;
}

sub incUnitCounter($;$) {
  my $counter = shift;
  my $value = shift;

  if ($UnitAnalysisStarted) {
    if (defined $value) {
      $$counter += $value;
    }
    else {
      $$counter++;
    }
  }
}

sub getVarDecl($) {
	my $var = shift;
	return GetChildren($var);
}

my $level = 0;

sub checkVar($$$$) {
	my $varDecl = shift;
	my $ENV_var = shift;
	my $selectorVar = shift;
	# the parameters list, if the current scope is a function !!!
	my $params = shift; 
	
	my $name = GetName($varDecl);
	#->->->->->-> treatment for declared variable ------
	#---------------------------------------------------
	incUnitCounter(\$nb_BadVariableNames, TypeScript::CountNaming::checkLocalVarNaming(\$name));
#print "  "x($level+1)."--> LOCAL ".$name."\n";
					
	# Check shadowing
#print "CHECK SHADOW $name in :\n";
	for my $env (@$ENV_var) {
#print " - ".join(',', keys %$env)."\n";
		if (exists $env->{$name}) {
			my $shadowed = $env->{$name};
			my $shadowedLine;
			if (ref $shadowed eq "ARRAY") {
				# variable shadowed
				$shadowedLine = GetLine($shadowed);
				incUnitCounter(\$nb_VariableShadow, 1);
				Erreurs::VIOLATION($mnemo_VariableShadow, "Variable $name at line ".(GetLine($varDecl)||"?")." is shadowing variable at line $shadowedLine");
			}
			else {
				# parameter shadowed
				$shadowedLine = $shadowed;
				incUnitCounter(\$nb_ParameterShadow, 1);
				Erreurs::VIOLATION($mnemo_ParameterShadow, "Variable $name at line ".(GetLine($varDecl)||"?")." is shadowing parameter at line $shadowedLine");
			}
			last;
		}
	}
	
	# check current scope parameter shadowing (if current scope is a function)
	if (exists $params->{$name}) {
		incUnitCounter(\$nb_ParameterShadow, 1);
		Erreurs::VIOLATION($mnemo_ParameterShadow, "Variable $name at line ".(GetLine($varDecl)||"?")." is shadowing parameter at line $params->{$name}");
	}
		# check if the variable is caching a selector
	my $children = GetChildren($varDecl);
	if (scalar @$children > 0) {
		my $stmt = GetStatement($children->[0]);
#print "  --> variable INITIALISATION = $$stmt";
		if ($$stmt =~ /\A\s*($SELECTOR)/) {
			$selectorVar->{$name}=1;
#print " ==> $name is CACHING a selector !!!";
		}
#print "\n";			
	}
}

sub checkParam($$$) {
	my $paramName = shift;
	my $ENV_var = shift;
	my $line = shift;

	for my $env (@$ENV_var) {
#print " - ".join(',', keys %$env)."\n";
		if (exists $env->{$paramName}) {
			my $shadowed = $env->{$paramName};
			if (ref $shadowed eq "ARRAY") {
				# paramter is shadowing a variable
				incUnitCounter(\$nb_VariableShadow, 1);
				Erreurs::VIOLATION($mnemo_VariableShadow, "Parameter $paramName at line $line is shadowing variable at line ".GetLine($shadowed));
			}
			else {
				# paramter is shadowing a parameter
				incUnitCounter(\$nb_ParameterShadow, 1);
				Erreurs::VIOLATION($mnemo_ParameterShadow, "Parameter $paramName at line $line is shadowing another parameter at line $shadowed");
			}
			last;
		}
	}
}

sub analyzeArtifact($$$$$;$);

sub analyzeArtifact($$$$$;$) {
	my $unit = shift;            	# unit to be analyzed
	my $ENV_var = shift;
	my $ENV_SelectorVar = shift;
	my $scopeNode = shift;				# start node
	my $artifactView = shift;
$level++;
	# List of functions contained in the artifact.
	my @LOCAL_func = ();
	# List of var declared or used in the artifact.
	# When a variable is referenced in this list, it can not be considered
	# as an undeclared variable (and then an implicit global variable)
	my %LOCAL_or_IMPLICIT_GLOBAL_var = ();

	my %alreadyPunishedSelectorVar = ();
	my %selectorVar = ();
	my $scopeParams = {}; # to store function arguments, if the scope node is a function

	# ARTIFACT or just a scope ?
	#----------------------------
	my $artifactNode;
	if (IsKind($scopeNode, RootKind) || IsKind($scopeNode, FunctionDeclarationKind) || IsKind($scopeNode, FunctionDeclarationKind) || IsKind($scopeNode, MethodKind)) {
		# the scope node is already an artifact node ...
		$artifactNode = $scopeNode;
	}
	else {
		# check if the scope node (certainly AccoKind) is related to an artifact (then get this artifact !)
		my $parent = GetParent($scopeNode);
		if (IsKind($parent, FunctionDeclarationKind) || IsKind($parent, FunctionExpressionKind) || IsKind($scopeNode, MethodKind)) {
			$artifactNode = GetParent($scopeNode);
		}
	}

	my $line = GetLine($scopeNode);
#print "  "x$level . "SCOPE <".GetKind($artifactNode||$scopeNode)."> at line : ".($line||"?")."\n";

	# Check if the node is the unit we want to analyze...
	if ((defined $artifactNode) &&  ($artifactNode == $unit)) {
		# From now, violations will be counted. 
		startUnitAnalysis();
	}
  
	# CASE FUNCTION or ROOT
	#-----------------------
	if (defined $artifactNode) {
		#-------------------------------------------------------------
		#----------- Get parameters ----------------------------------
		#-------------------------------------------------------------
		if (! IsKind($artifactNode, RootKind)) {
			# it's a function ...
			my $params = Lib::NodeUtil::GetXKindData($artifactNode, 'parameters');
			for my $param (@$params) {
#print "  "x($level+1)."--> parameter = $param\n";
				my $pname = $param->[0];
				$LOCAL_or_IMPLICIT_GLOBAL_var{$pname} = $line; # as a not nul value, assign the line where the parameter is declared ...
				$scopeParams->{$pname} = $line;
				checkParam($pname, $ENV_var, $line);
			}
		}
	
		#---------------------------------------------------------------
		#----------- Get "var" variables -------------------------------
		#---------------------------------------------------------------

		# Retrieve variables and functions declared in the scope (do not search into functions).
		my @vars = GetNodesByKindList_StopAtBlockingNode(
			$scopeNode, 
			[VarKind],
			[FunctionDeclarationKind, FunctionExpressionKind, MethodKind]);

		for my $node1 (@vars) {
			if (IsKind($node1, VarKind)) {
				# all var of the declaration statement 
				for my $varDecl (@{getVarDecl($node1)}) {
					my $name = GetName($varDecl);
#print "========================== VAR $name\n";
					$LOCAL_or_IMPLICIT_GLOBAL_var{$name} = $varDecl;
					
					checkVar($varDecl, $ENV_var, \%selectorVar, $scopeParams);
				}
			}
		}
	}
	
	# ALL CASES
	
	#-------------------------------------------------------------------
	#------------ Get inner scopes && "let/const" variables ------------
	#-------------------------------------------------------------------
	
	my @innerScopesAndLet = GetNodesByKindList($scopeNode, [AccoKind, LetKind, ConstKind], 1);
	my @innerScopes =();
	for my $item (@innerScopesAndLet) {
		if (IsKind($item, AccoKind)) {
			push @innerScopes, $item;
		}
		else {
			# $item is a var, let or const node. It can contain scope of function expression
			# retrieve scope ...
			push @innerScopes, GetNodesByKindList($item, [AccoKind], 1);
			
			# manage declarations ...
			for my $varDecl (@{getVarDecl($item)}) {
				my $name = GetName($varDecl);
				$LOCAL_or_IMPLICIT_GLOBAL_var{$name} = $varDecl;
				checkVar($varDecl, $ENV_var, \%selectorVar, $scopeParams);
			}
		}
	}
	
	#-------------------------------------------------------------------
	#------             Get instruction                            -----
	#------                   &                                    -----
	#------ check undeclared (implied global) variables assignment -----
	#-------------------------------------------------------------------
	my @instrNodes = GetNodesByKindList_StopAtBlockingNode($scopeNode, [UnknowKind, CondKind], [AccoKind], 1);
	
	# iterate on each node aimed to contain variable initialization
	for my $instruction (@instrNodes) {
		my $stmt = GetStatement($instruction);
		my $line = GetLine($instruction)||"?";

		# search VAR in a variable init expression of the form :
		#     VAR[.FIELD1.FIELD2. ...] = ...
		#     VAR[.FIELD1.FIELD2. ...] = $(...)
		#     VAR[.FIELD1.FIELD2. ...] = document.getElementById(...)
		#
		if ($$stmt =~ /(?:\A|[^\.])\s*($IDENTIFIER)(\s*\.\s*$DEREF_EXPR)?\s*(?:[+\-*\/\%\&\^\|]|<<|>>>?)?=(?:\s*($SELECTOR)|[^=])/sg) {

			# get name of the variable
			# ------------------------
			my $name = $1;
#print "*** VARIABLE $name at line ".(GetLine($instruction)||"?")."\n";
    
			# Some name to exclude from the rule ...
			if ( $name =~ /^this|document|window|localStorage|sessionStorage$/ ) {
				next;
			}

			# detect if the variable is initialized with a selector.
			# -----------------------------------------------------
			my $selector = $3;
			if (defined $selector) {
#	print "   --> SELECTOR : $selector\n";

			# check if already stored as caching a selector in upper level
				for my $env (@$ENV_SelectorVar) {
					if (!exists $env->{$name}) {
						# add to local selector caching variable list.
						$selectorVar{$name}=1;
					}
				}
			}
			# If it is a prototype modification, go to next.
			# ----------------------------------------------
			if (defined $2) {
#print "DEREF = $2\n";
				if ( $2 =~ /\A\s*\.\s*prototype\b/ ) {
					next;
				}
			}

			# check if the variable has been declared before.
			# ------------------------------------------------
			my $declared_outside = 0;
			for my $env (@$ENV_var) {
				if ( exists $env->{$name}) {
#print "   --> is declared outside.\n";
					$declared_outside = 1;
					last;
				}
			}
			
			# If variable is not local
			if (! exists $LOCAL_or_IMPLICIT_GLOBAL_var{$name}) {

				# If variable is not from outside
				if (! $declared_outside ) {
					#->->->->->-> treatment for NEVER declared variable (implicit global) ----
					#-------------------------------------------------------------------------
#print "   --> implicit global !!!\n";
					incUnitCounter(\$nb_BadVariableNames,TypeScript::CountNaming::checkGlobalVarNaming(\$name));
					incUnitCounter(\$nb_ShortGlobalNamesLT, TypeScript::CountNaming::isNameTooShort(\$name, LIMIT_SHORT_GLOBALVAR_NAMES));
					Erreurs::VIOLATION($mnemo_BadSelectorCaching, "Implied global variable : $name");
					incUnitCounter(\$nb_ImpliedGlobalVar, 1);

					if (defined $selector) {
						# The variable is caching a selector and is implicit global.
						# If it has not already been encountered in this artifact,
						# punish it !!
						if (! exists $alreadyPunishedSelectorVar{$name}) {
#print "VIOLATION : bad selector caching (implicit global caching) ($name)!!!\n";
							Erreurs::VIOLATION($mnemo_BadSelectorCaching, "Bad selector caching (implicit global caching) ($name)");
							incUnitCounter(\$nb_BadSelectorCaching, 1);
							$alreadyPunishedSelectorVar{$name}=1;
						} 
					}

					# if the variable was not declared, it is now known : in the future don't
					# count the violation several time in its scope (this artifact and inner func).
					#
					# RQ : LOCAL_or_IMPLICIT_GLOBAL_var has been added to the %ENV_var list, it's because the
					# var will not continue to be considered undeclared ... (!)
					$LOCAL_or_IMPLICIT_GLOBAL_var{$name} = 1;
				}
				else {
					# Variable has been declared in calling environment.
					#---------------------------------------------------
					# If it use a selector, it will share it at upper level ==> punish it !!
					if (defined $selector) {
						if (! exists $alreadyPunishedSelectorVar{$name}) {
#print "VIOLATION : bad selector caching (caching at upper level) ($name)!!!\n";
							Erreurs::VIOLATION($mnemo_BadSelectorCaching, "Bad selector caching (caching at upper level) ($name)");
							incUnitCounter(\$nb_BadSelectorCaching, 1);
							$alreadyPunishedSelectorVar{$name} = 1;
						}
					}
					#else {
						## check if the variable is caching selector from upper level
						#for my $env (@$ENV_SelectorVar) {
							#if (exists $env->{$name}) {
								#if (! exists $alreadyPunishedSelectorVar{$name}) {
##print "VIOLATION : bad selector caching (cached from upper level) ($name)!!!\n";
									#Erreurs::VIOLATION($mnemo_BadSelectorCaching, "Bad selector caching (using selector cached from upper level) ($selectorName)");
									#incUnitCounter(\$nb_BadSelectorCaching, 1);
									#$alreadyPunishedSelectorVar{$name} = 1;
								#}
							#}
						#}
					#}
				}
			}		
		}
		
		# Check if the instruction is using a selector cached in upper level.
		for my $env (@$ENV_SelectorVar) {
			for my $selectorName (keys %$env) {
				if (! exists $LOCAL_or_IMPLICIT_GLOBAL_var{$selectorName}) {
					my $name = quotemeta $selectorName;
#print "CHECKING selector usage $selectorName in $$stmt\n";
					if ($$stmt =~ /(?:\A|[^\.\w\$])$name(?:[^\w\$]|\z)/) {
						if (! exists $alreadyPunishedSelectorVar{$selectorName}) {
#print "VIOLATION : bad selector caching (using selector cached at upper level) ($selectorName)!!!\n";
							Erreurs::VIOLATION($mnemo_BadSelectorCaching, "Bad selector caching (using selector cached from upper level) ($selectorName) at line $line");
							incUnitCounter(\$nb_BadSelectorCaching, 1);
							$alreadyPunishedSelectorVar{$selectorName} = 1;
						}
#else {
#print " --> already punished !!!\n";
#}
					}
				}
			}
		}
	}
	
	# record selector list for this scope.
	unshift @$ENV_SelectorVar, \%selectorVar;
	
	## Add new selector caching vars in the list for inner artifacts analysis.
	#for my $SV (@SelectorVar) {
		#$ENV_SelectorVar->{$SV} = 1;
	#}
	
	# Add local data to env for context of inner function ...
	# use unshift to put them at beginning,, so that they will be treated first !
	unshift @$ENV_var, \%LOCAL_or_IMPLICIT_GLOBAL_var;

	#-------------------------------------------------------------
	#----------- Analyze inner function artifact -----------------
	#-------------------------------------------------------------
	if (!IsKind($unit, RootKind)) {
		# $node is the function that has just been analyzed. If $node == $unit,
		# don't analyzed it twice !!!
		# Don't start the unit analysis too if it is allready started !!!
		if  (($unit != $scopeNode) && (! $UnitAnalysisStarted)) {
			analyzeArtifact($unit, $ENV_var, $ENV_SelectorVar, $unit, $artifactView);
		}
		else {
			for my $scope (@innerScopes) {
				analyzeArtifact($unit, $ENV_var, $ENV_SelectorVar, $scope, $artifactView);
			}
		}
	}
	else {
		for my $scope (@innerScopes) {
			analyzeArtifact($unit, $ENV_var, $ENV_SelectorVar, $scope, $artifactView);
		}
	}

	# remove local data ...
	shift @$ENV_var;
	shift @$ENV_SelectorVar;
$level--;
}

sub CountVariable($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;
  my $status = 0;
  $nb_ShortGlobalNamesLT = 0;
  $nb_BadVariableNames = 0;
  $nb_BadSelectorCaching = 0;
  $nb_ImpliedGlobalVar = 0;
  $nb_VariableShadow = 0;
  $UnitAnalysisStarted = 0;
  $nb_VariableShadow = 0;
  $nb_ParameterShadow = 0;
  
  if (not defined $vue->{'structured_code'})
  {
      $status |= Couples::counter_add ($compteurs, $mnemo_ShortGlobalNamesLT, Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BadVariableNames, Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BadSelectorCaching, Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_ImpliedGlobalVar, Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_VariableShadow, Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_ParameterShadow, Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
  }

  my $root = $vue->{'structured_code'};

  # by default, the unit to analyze is root.
  my $unitArtifact = $root;

  # But if it is a virtual root (created for containing an unit), then the unit
  # to analyze should be extracted.
  if (GetName($root) eq 'virtualRoot') {

    # get the unit to analyze. 
    $unitArtifact = Lib::NodeUtil::GetChildren($root)->[0];

    # get the root corresponding to the full file (the original root)
    $root = $vue->{'full_file'}->{'structured_code'};
  }

  my $artifactView = $vue->{'artifact'};

  my @func = ();
  my %H_var = ();

  my @ENV_var         = (\%H_var);
  my @ENV_SelectorVar = ();

  # We will record only violations for $unitArtifact, but the analysis will 
  # start from the original root, because we need the context from the top
  # level.
  $level = 0;
  analyzeArtifact($unitArtifact, \@ENV_var, \@ENV_SelectorVar, $root, $artifactView);
  
  $status |= Couples::counter_add ($compteurs, $mnemo_ShortGlobalNamesLT, $nb_ShortGlobalNamesLT);
  $status |= Couples::counter_add ($compteurs, $mnemo_BadVariableNames, $nb_BadVariableNames);
  $status |= Couples::counter_add ($compteurs, $mnemo_BadSelectorCaching, $nb_BadSelectorCaching);
  $status |= Couples::counter_add ($compteurs, $mnemo_ImpliedGlobalVar, $nb_ImpliedGlobalVar);
  $status |= Couples::counter_add ($compteurs, $mnemo_VariableShadow, $nb_VariableShadow);
  $status |= Couples::counter_add ($compteurs, $mnemo_ParameterShadow, $nb_ParameterShadow);

  return $status;
}

sub CountMultipleDeclarations($$$) {
    my ($fichier, $vue, $compteurs, $options) = @_ ;
    my $status = 0;
    my %Decl_var;
    $nb_MultipleDeclarationsInSameStatement = 0;
    $nb_MultipleDeclarationShadow = 0;
    
    #$nb_VariableDeclarations = 0;

    my $root = $vue->{'structured_code'};

    if (not defined $root)
    {
      $status |= Couples::counter_add ($compteurs, $mnemo_MultipleDeclarationsInSameStatement, Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_VariableShadow, Erreurs::COMPTEUR_ERREUR_VALUE);
    }

    my @vars = GetNodesByKind($root, VarKind);
    
    my @varTypeScript = GetNodesByKindList($root, [VarKind, LetKind]);

  #$nb_VariableDeclarations = scalar @vars;

    for my $var (@vars) 
    {
        my @decl = GetNodesByKind($var, VarDeclKind, 1); # 1 : do not walk into subnodes.
        if (scalar @decl > 1) {
            $nb_MultipleDeclarationsInSameStatement++;
        }
    }
    for my $var (@varTypeScript) 
    {
        my @decl = GetNodesByKind($var, VarDeclKind); 
   
        if (defined scalar @decl and scalar @decl > 0) 
        {
            if ( exists $Decl_var{ ${GetStatement($decl[0])} } )
            {
                #print " Variable ".${GetStatement($decl[0])}." should not be shadowed at line ".GetLine($var)."\n" if $DEBUG;
                #$nb_MultipleDeclarationShadow++;
                #Erreurs::VIOLATION($mnemo_VariableShadow, "Variable ".${GetStatement($decl[0])}." should not be shadowed at line ".GetLine($var));
            }
            else 
            {
                $Decl_var{ ${GetStatement($decl[0])} } = 1;
            }
        }
    }
    $status |= Couples::counter_add ($compteurs, $mnemo_MultipleDeclarationsInSameStatement, $nb_MultipleDeclarationsInSameStatement);
    #$status |= Couples::counter_add ($compteurs, $mnemo_VariableShadow, $nb_MultipleDeclarationShadow);
}

1;
