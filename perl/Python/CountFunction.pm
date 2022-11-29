package Python::CountFunction;

use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Python::PythonNode;
use Python::PythonConf;
use Python::CountNaming;

my $OverridenBuiltInException__mnemo = Ident::Alias_OverridenBuiltInException();
my $UnusedPara = Ident::Alias_UnusedParameters();
my $WithTooMuchParametersMethods__mnemo = Ident::Alias_WithTooMuchParametersMethods();
my $EmptyReturn__mnemo = Ident::Alias_EmptyReturn();
my $MultipleReturnFunctionsMethods__mnemo = Ident::Alias_MultipleReturnFunctionsMethods();
my $FunctionImplementations__mnemo = Ident::Alias_FunctionImplementations();
my $ShortFunctionNamesLT__mnemo = Ident::Alias_ShortFunctionNamesLT();
my $ShortMethodNamesLT__mnemo = Ident::Alias_ShortMethodNamesLT();
my $FunctionNameLengthAverage__mnemo = Ident::Alias_FunctionNameLengthAverage();
my $MethodNameLengthAverage__mnemo = Ident::Alias_MethodNameLengthAverage();
my $BadFunctionNames__mnemo = Ident::Alias_BadFunctionNames();
my $BadMethodNames__mnemo = Ident::Alias_BadMethodNames();
my $Para = Ident::Alias_Para();

my $xxxx__mnemo = "xxx";


my $nb_OverridenBuiltInException = 0;
my $nb_UnusedParameters = 0;
my $nb_WithTooMuchParametersMethods = 0;
my $nb_EmptyReturn = 0;
my $nb_MultipleReturnFunctionsMethods = 0;
my $nb_FunctionImplementations = 0;
my $nb_ShortFunctionNamesLT = 0;
my $nb_ShortMethodNamesLT = 0;
my $nb_FunctionNameLengthAverage = 0;
my $nb_MethodNameLengthAverage = 0;
my $nb_BadFunctionNames = 0;
my $nb_BadMethodNames = 0;
my $nb_Para = 0;

my $nb_xxxx = 0;

my $NB_METHODS = 0;
my $nb_MaxArgs = 0;
my $nb_ArgsAverage = 0;

my $MAX_ARGS = 3;

sub isUsedArg($$) {
	my $arg = shift;
	my $code = shift;
	
	# Arg is used if :
	# - preceded by [\n:;] AND followed by "="   (assignation at instruction beginning)
	# OR
	# - not preceded by "." AND not followed by "=".    (not a field nor an assignation)
	if ($$code =~ /([\n:;][ \t]*$arg[ \t]*=|[^\.]\b$arg\b[ \t]*(?:[^=\s]|$))/m) {
		return 1;
	}
	return 0;
}

sub checkFunction($$$$);
sub checkNestedFunctions($$$$);

sub checkNestedFunctions($$$$) {
	my $node =  shift;
	my $unused_args = shift;
	my $checked = shift;
	my $artifacts = shift;
	
	for my $child (@{Lib::NodeUtil::GetChildren($node)}) {
		if ((IsKind($child, FunctionKind)) || (IsKind($child, MethodKind))) {
			checkFunction($child, $unused_args, $checked, $artifacts);
		}
		# Search functions/methods in local classes
		elsif (IsKind($child, ClassKind)) {
			checkNestedFunctions($child, $unused_args, $checked, $artifacts);
			#for my $member (@{Lib::NodeUtil::GetChildren($child)}) {
			#	if ((IsKind($member, FunctionKind)) || (IsKind($member, MethodKind))) {
			#		checkFunction($member, $unused_args, $checked, $artifacts);
			#	}
			#}
		}
	}
}

sub checkFunction($$$$) {
	my $func = shift;
	my $unused_args = shift;
	my $checked = shift;
	my $artifacts = shift;

	my @localUnused = ();
	
	my $name = GetName($func);
	my $line = GetLine($func);

	if (exists $checked->{$name}) {
		# function has already been checked.
		return;
	}
	else {
		# indicate the function has been checked.
		$checked->{$name} = 1;
	}

	my @arguments = keys %{getPythonKindData($func, 'arguments')};
	
	$nb_Para += scalar @arguments;
	
	my $nbArgs = scalar @arguments;
	if ($nbArgs > $MAX_ARGS) {
		$nb_WithTooMuchParametersMethods++;
		Erreurs::VIOLATION($WithTooMuchParametersMethods__mnemo, "function ".GetName($func)." has too many parameters ($nbArgs).");
	}
	
	# CHECK NAME
	if (IsKind($func, FunctionKind)) {
		$nb_FunctionImplementations++;
		$nb_FunctionNameLengthAverage += length($name);
		if (Python::CountNaming::isShortFunctionName($name)) {
			$nb_ShortFunctionNamesLT++;
			Erreurs::VIOLATION($ShortFunctionNamesLT__mnemo, "Too short function name : $name at line : $line");
		}
		if ( ! Python::CountNaming::isValidFunctionName($name)) {
			$nb_BadFunctionNames++;
			Erreurs::VIOLATION($BadFunctionNames__mnemo, "Bad function name : $name at line : $line");
		}
	}
	else {
		$NB_METHODS++;
		$nb_MethodNameLengthAverage += length($name);
		if (Python::CountNaming::isShortMethodName($name)) {
			$nb_ShortMethodNamesLT++;
			Erreurs::VIOLATION($ShortMethodNamesLT__mnemo, "Too short method name : $name at line : $line");
		}
		if ( ! Python::CountNaming::isValidMethodName($name)) {
			$nb_BadMethodNames++;
			Erreurs::VIOLATION($BadMethodNames__mnemo, "Bad function name : $name at line : $line");
		}
	}

# STATISTICS	
#$nb_ArgsAverage += scalar @arguments;
#if (scalar @arguments > $nb_MaxArgs) {
#	$nb_MaxArgs = scalar @arguments;
#}

	# CHECK THE FUNCTION ITSELF
	
	my $artikey = Lib::NodeUtil::buildArtifactKeyByData('func_'.GetName($func), GetLine($func));
	my $funcode = \$artifacts->{$artikey};
	
	# Count significant returns :
	my ($totalReturn, $emptyReturns, $noneReturns, $falseReturns, $significantReturns) = (0,0,0,0,0);
	while ( $$funcode =~ /\breturn\b[ \t]*(?:(\n)|(None)|(False)|([^\n]+))/g ) {
		if (defined $1) {
#print "EMPTY return\n";
			$emptyReturns++;
		}
		elsif (defined $2) {
#print "NONE return\n";
			$noneReturns++;
		}
		elsif (defined $3) {
#print "FALSE return\n";
			$falseReturns++;
		}
		else {
#print "SIGNIFICANT return : $4\n";
			$significantReturns++;
		}
		$totalReturn++;
	}
	
	if ($significantReturns > 1) {
		$nb_MultipleReturnFunctionsMethods++;
		Erreurs::VIOLATION($MultipleReturnFunctionsMethods__mnemo, "function $name has several ($significantReturns) significant returns.");
	}
	
	if ($significantReturns > 0) {
		
		my $children = Lib::NodeUtil::GetChildren($func);
#print "Last child is ".$children->[-1]->[0]."\n";
#print "TOTAL RETURN = $totalReturn\n";
		if	($emptyReturns ||
			 (! IsKind($children->[-1], ReturnKind))) {
			$nb_EmptyReturn++;
			Erreurs::VIOLATION($EmptyReturn__mnemo, "Inconsistent returns in function $name declared at line $line.");
		}
	}
	
	# check previous unchecked args
	# note : $arg is an array [<name>, <function line>]
	for my $list (@$unused_args) {
		for my $arg (@$list) {
			if (isUsedArg($arg->[0], $funcode)) {
				$arg = undef;
			}
		}
		@$list = grep defined, @$list;
	}
	
	# CHECK ARGUMENTS
	for my $arg (@arguments) {
			
		# check if used
		if ($arg ne 'self') {
			if (!isUsedArg($arg, $funcode)) {
				# Arg is unused in the current function's body
				push @localUnused, [$arg, $line];
			}
		}
			
		# FIXME : check if the arg is a builtin exception 
		if (exists($Python::PythonConf::BUILTIN_EXCEPTION_NAME{$arg})) {
			$nb_OverridenBuiltInException++;
			Erreurs::VIOLATION($OverridenBuiltInException__mnemo, "Builtin exception ($arg) overriden by function's argument at line ".$line);
		}
	}

	push @$unused_args, \@localUnused;

	# CHECK NESTED FUNCTIONS
	checkNestedFunctions($func, $unused_args, $checked, $artifacts);
	
	# COUNT VIOLATIONS
	for my $arg (@localUnused) {
		$nb_UnusedParameters++;
		Erreurs::VIOLATION($UnusedPara, "Unused parameter ($arg->[0]) at line $arg->[1]");
	}
	pop @$unused_args;
}


sub CountFunctions($$$) {
	my ($file, $views, $compteurs) = @_ ;
	my $ret =0;

	$nb_OverridenBuiltInException = 0;
	$nb_UnusedParameters = 0;
	$nb_WithTooMuchParametersMethods = 0;
	$nb_EmptyReturn = 0;
	$nb_MultipleReturnFunctionsMethods = 0;
	$nb_FunctionImplementations = 0;
	$NB_METHODS = 0;
	$nb_ShortFunctionNamesLT = 0;
	$nb_ShortMethodNamesLT = 0;
	$nb_FunctionNameLengthAverage = 0;
	$nb_MethodNameLengthAverage = 0;
	$nb_BadFunctionNames = 0;
	$nb_BadMethodNames = 0;
	$nb_Para = 0;
	
	$nb_MaxArgs = 0;
	$nb_ArgsAverage = 0;
	
	my $kindLists = $views->{'KindsLists'};
	my $artifacts = $views->{'artifact'};
	my $root = $views->{'structured_code'};
	
	if (( ! defined $root ) && (!defined $artifacts)) {
		$ret |= Couples::counter_add($compteurs, $OverridenBuiltInException__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnusedPara, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $EmptyReturn__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MultipleReturnFunctionsMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $FunctionImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ShortFunctionNamesLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ShortMethodNamesLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $FunctionNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MethodNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadFunctionNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadMethodNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $Para, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $already_checked = {};
	# treat all functions/methods in hierarchical order from root ...
	checkNestedFunctions($root, [], $already_checked, $artifacts);

if ($nb_FunctionImplementations) {
	$nb_FunctionNameLengthAverage = int ( $nb_FunctionNameLengthAverage / $nb_FunctionImplementations );
}
else {
	$nb_FunctionNameLengthAverage = 0;
}

if ($NB_METHODS) {
	$nb_MethodNameLengthAverage = int ( $nb_MethodNameLengthAverage / $NB_METHODS );
}
else {
	$nb_MethodNameLengthAverage = 0;
}

if ($NB_METHODS + $nb_FunctionImplementations) {
	$nb_ArgsAverage = int ( $nb_ArgsAverage / ($NB_METHODS + $nb_FunctionImplementations) );
}
else {
	$nb_ArgsAverage = 0;
}


#print "ARGS AVERAGE = $nb_ArgsAverage\n";
#print "MAX ARGS  = $nb_MaxArgs\n";
#print "FUNCTION TOO MANY PARAMS = $nb_WithTooMuchParametersMethods\n";
	Erreurs::VIOLATION($FunctionNameLengthAverage__mnemo, "Function name length average : $nb_FunctionNameLengthAverage");
	Erreurs::VIOLATION($MethodNameLengthAverage__mnemo, "Method name length average : $nb_MethodNameLengthAverage");

	$ret |= Couples::counter_update($compteurs, $OverridenBuiltInException__mnemo, $nb_OverridenBuiltInException );
	$ret |= Couples::counter_update($compteurs, $UnusedPara, $nb_UnusedParameters );
	$ret |= Couples::counter_update($compteurs, $WithTooMuchParametersMethods__mnemo, $nb_WithTooMuchParametersMethods );
	$ret |= Couples::counter_update($compteurs, $EmptyReturn__mnemo, $nb_EmptyReturn );
	$ret |= Couples::counter_update($compteurs, $MultipleReturnFunctionsMethods__mnemo, $nb_MultipleReturnFunctionsMethods );
	$ret |= Couples::counter_update($compteurs, $FunctionImplementations__mnemo, $nb_FunctionImplementations );
	$ret |= Couples::counter_update($compteurs, $ShortFunctionNamesLT__mnemo, $nb_ShortFunctionNamesLT );
	$ret |= Couples::counter_update($compteurs, $ShortMethodNamesLT__mnemo, $nb_ShortMethodNamesLT );
	$ret |= Couples::counter_update($compteurs, $FunctionNameLengthAverage__mnemo, $nb_FunctionNameLengthAverage );
	$ret |= Couples::counter_update($compteurs, $MethodNameLengthAverage__mnemo, $nb_MethodNameLengthAverage );
	$ret |= Couples::counter_update($compteurs, $BadFunctionNames__mnemo, $nb_BadFunctionNames );
	$ret |= Couples::counter_update($compteurs, $BadMethodNames__mnemo, $nb_BadMethodNames );
	$ret |= Couples::counter_update($compteurs, $Para, $nb_Para );
	return $ret;
}



sub CountLambda($$$) {
	my ($file, $views, $compteurs) = @_ ;
	my $ret =0;

	# FIXME : desactivated => lambda restriction may be a little polemist ...
	return 0;

	$nb_xxxx = 0;

	my $code = \$views->{'code'};
	
	if ( ! defined $code ) {
		$ret |= Couples::counter_add($compteurs, $xxxx__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	while ($$code =~ /([^(,]\s*<ident>\s*=\s*lambda\b.....)|(.....\blambda\b.....)/sg) {
		if (defined $1) {
			Erreurs::VIOLATION("TBD", "Lambda assigned to variable encoutered : $1\n");
		}
		else {
			Erreurs::VIOLATION("TBD", "Lambda : $2\n");
		}
	}
	
	$ret |= Couples::counter_update($compteurs, $xxxx__mnemo, $nb_xxxx );
}

1;



