package Clojure::CountNaming;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Clojure::ClojureNode;
use Clojure::Config;

my $BadVariableNames__mnemo = Ident::Alias_BadVariableNames();
my $BadFunctionNames__mnemo = Ident::Alias_BadFunctionNames();
my $BadProtocolNames__mnemo = Ident::Alias_BadProtocolNames();
my $BadTypeNames__mnemo = Ident::Alias_BadTypeNames();
my $BadConversionFunctionNames__mnemo = Ident::Alias_BadConversionFunctionNames();
my $BadDynamicVarNames__mnemo = Ident::Alias_BadDynamicVarNames();

my $nb_BadVariableNames = 0;
my $nb_BadFunctionNames = 0;
my $nb_BadProtocolNames = 0;
my $nb_BadTypeNames = 0;
my $nb_BadConversionFunctionNames = 0;
my $nb_BadDynamicVarNames = 0;

sub checkConversionFunctionName($) {
	my $name = shift;
	
	if ($name =~ /\w-to-\w/) {
		return 0;
	}
	return 1;
}

sub isLispNaming($) {
	my $name = shift;
	
	return 1 if ($name eq "_");
	
	# no violation if the name is dynamically obtained (presence of function call)
	return 1 if ($name =~ /\(/);
	
	if ($name =~ /[A-Z_]/) {
		return 0;
	}
	return 1;
}

sub isPascalNaming($) {
	my $name = shift;
	
	return 1 if ($name eq "_");
	
	# no violation if the name is dynamically obtained (presence of function call)
	return 1 if ($name =~ /\(/);
	
	if ($name =~ /^[A-Z][^_-]*$/m) {
		return 1;
	}
	
	return 0;
}

sub getDefName($) {
	my $code = shift;
	
	# step over metadata
	while ($$code =~ /\G\s*\^/gc) {
		if ($$code =~ /\G\s*\{/gc) {
			$$code =~ /\G\s*[^\}]*\}/gc;
		}
		else {
			$$code =~ /\G\s*(\S+)/gc;
		}
	}
	
	# get name
	if ($$code =~ /\G\s*(\S+)/gc) {
		return $1;
	}
	return undef;
}

my %COUNTER = (	"defprotocol" => \$nb_BadProtocolNames,
				"defrecord" =>  \$nb_BadTypeNames,
				"defstruct" =>  \$nb_BadTypeNames,
				"deftype" =>  \$nb_BadTypeNames,
);

my %MNEMO = (	"defprotocol" => $BadProtocolNames__mnemo,
				"defrecord" => $BadTypeNames__mnemo,
				"defstruct" => $BadTypeNames__mnemo,
				"deftype" => $BadTypeNames__mnemo
);

sub CountNaming($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_BadVariableNames = 0;
    $nb_BadFunctionNames = 0;
    $nb_BadProtocolNames = 0;
    $nb_BadTypeNames = 0;
    $nb_BadConversionFunctionNames = 0;
    $nb_BadDynamicVarNames = 0;

	my $KindsLists = $vue->{'KindsLists'};
	my $code = \$vue->{'code'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $BadVariableNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadFunctionNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadConversionFunctionNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadConversionFunctionNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadDynamicVarNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	
	# check FUNCTIONS
	my $funcs = $KindsLists->{&FunctionKind};
	my $funcsArity = $KindsLists->{&FunctionArityKind};
	my @Functions = (@$funcs, @$funcsArity);
	
	for my $func (@Functions) {
		my $name = GetName($func);
		if (! isLispNaming($name)) {
			$nb_BadFunctionNames++;
			Erreurs::VIOLATION($BadFunctionNames__mnemo, "bad name for function $name at line ".GetLine($func));
		}
		
		if (checkConversionFunctionName($name) == 0) {
			$nb_BadConversionFunctionNames++;
			Erreurs::VIOLATION($BadConversionFunctionNames__mnemo, "Bad name for conversion function $name at line ".GetLine($func));
		}
	}
	
	# check GLOBAL VAR
	my $defs = $KindsLists->{&DefKind};
	
	for my $def (@$defs) {
		my $name = GetName($def);
		if (! isLispNaming($name)) {
			$nb_BadVariableNames++;
			Erreurs::VIOLATION($BadVariableNames__mnemo, "bad name for global variable $name at line ".GetLine($def));
		}
		my $metadata = Clojure::ClojureNode::getClojureKindData($def, 'metadata');
		
		if ($$metadata =~ /:dynamic\b/) {
			if ($name !~ /^\*[^\*]+\*$/m) {
				$nb_BadDynamicVarNames++;
				Erreurs::VIOLATION($BadDynamicVarNames__mnemo, "bad name for dynamic variable $name at line ".GetLine($def));
			}
		}
	}
	
	# check LOCAL VAR
	my $lets = $KindsLists->{&LetKind};
	
	for my $let (@$lets) {
		my $H_variables = Clojure::ClojureNode::getClojureKindData($let, 'variables');
		
		for my $name (keys %$H_variables) {
			if (! isLispNaming($name)) {
				$nb_BadVariableNames++;
				Erreurs::VIOLATION($BadVariableNames__mnemo, "bad name for local variable $name at line ".GetLine($let));
			}
		}
	}
	
	# check protocol, records, structs and types
	my $line = 1;
	while ($$code =~ /\b(defprotocol|defrecord|defstruct|deftype)\b\s|(\n)/gc) {
		if (defined $2) {
			$line++;
		}
		else {
			my $name = getDefName($code);
#print STDERR "[$1] $name at line $line\n";
			
			if (! isPascalNaming($name)) {
				$nb_BadVariableNames++;
				${$COUNTER{$1}}++;
				Erreurs::VIOLATION($MNEMO{$1}, "bad name for [$1] $name at line $line");
			}
		}
	}
	
	$ret |= Couples::counter_update($compteurs, $BadVariableNames__mnemo, $nb_BadVariableNames );
	$ret |= Couples::counter_update($compteurs, $BadFunctionNames__mnemo, $nb_BadFunctionNames );
	$ret |= Couples::counter_update($compteurs, $BadProtocolNames__mnemo, $nb_BadProtocolNames );
	$ret |= Couples::counter_update($compteurs, $BadTypeNames__mnemo, $nb_BadTypeNames );
	$ret |= Couples::counter_update($compteurs, $BadConversionFunctionNames__mnemo, $nb_BadConversionFunctionNames );
	$ret |= Couples::counter_update($compteurs, $BadDynamicVarNames__mnemo, $nb_BadDynamicVarNames );
	
    return $ret;
}

1;


