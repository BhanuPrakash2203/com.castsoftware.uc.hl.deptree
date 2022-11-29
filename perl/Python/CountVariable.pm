package Python::CountVariable;

use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Python::PythonNode;
use Python::PythonConf;
use Python::CountNaming;

my $GlobalVariableHidding__mnemo = Ident::Alias_GlobalVariableHidding();
my $OverridenBuiltInException__mnemo = Ident::Alias_OverridenBuiltInException();
my $GlobalVariables__mnemo = Ident::Alias_GlobalVariables();
my $VarNotUsed__mnemo = Ident::Alias_VarNotUsed();
my $LocalVarAverage__mnemo = Ident::Alias_LocalVarAverage();
my $BadVariableNames__mnemo = Ident::Alias_BadVariableNames();
my $BadAttributeNames__mnemo = Ident::Alias_BadAttributeNames();
my $MagicNumbers__mnemo = Ident::Alias_MagicNumbers();

my $nb_GlobalVariableHidding = 0;
my $nb_OverridenBuiltInException = 0;
my $nb_GlobalVariables = 0;
my $nb_VarNotUsed = 0;
my $nb_LocalVarAverage = 0;
my $nb_BadVariableNames = 0;
my $nb_BadAttributeNames = 0;
my $nb_MagicNumbers = 0;

sub isConstant($$) {
	my $var = shift;
	my $code = shift;
#print "CONST $var ???\n";
	my $nbFound = 0;
	# Count number of assignment. 
	# if assigned more than on time, then it's not a constant.
	while ($$code =~ /(?:^|[^\.,\(])\s*$var\s*=\s*(?:(?:CHAINE_\d+|\d|\[)|(.))/smg) {
		$nbFound++;
		if (	($nbFound > 1) ||   # more than one assignment
				(defined $1)) {     # assignment of a non literal
			# ==> not a constant
			pos($$code) = undef;
#print "--> NO !!\n";
			return 0;
		}
	}
#print "--> YES !\n";
	return 1;
}

sub checkVarName($$) {
	my $name = shift;
	my $consts = shift;
	
	if (exists $consts->{$name}) {
		if ( ! Python::CountNaming::isValidConstantName($name)) {
			$nb_BadVariableNames++;
			Erreurs::VIOLATION($BadVariableNames__mnemo, "Bad constant name : $name");
		}
	}
	elsif ( ! Python::CountNaming::isValidVariableName($name)) {
		$nb_BadVariableNames++;
		Erreurs::VIOLATION($BadVariableNames__mnemo, "Bad variable name : $name");
	}
}

sub checkAttributeName($) {
	my $name = shift;
	if ( ! Python::CountNaming::isValidAttributeName($name)) {
		$nb_BadAttributeNames++;
		Erreurs::VIOLATION($BadAttributeNames__mnemo, "Bad attribute name : $name");
	}
}

sub checkVarUses($$$$) {
	my $vars = shift;
	my $used = shift;
	my $unused = shift;
	my $code = shift;

	for my $var (@$vars) {
#print "CHECK VAR : $var in $$code\n";
		if ($$code =~ /\b$var\b\s*(?:==|[^=\s]|$)/m) {
#print "Var $var is used !!!\n";
			$used->{$var} = 1;
			delete $unused->{$var};
		}
		else {
#print "Var $var is not used !!!\n";
			$unused->{$var} = 1;
		}
	}
}

our $integer = '\b(?:0[xX])?[0123456789ABCDEF]+[lL]?\b';
our $decimal  = '(?:[0-9]*\.[0-9]+|[0-9]+\.)';
our $real = '[0-9]+[eE][+-]?[0-9]+';

sub countMagicNumbers($$) {
	my $code = shift;
	my $consts = shift;
	
	pos($$code) = undef;
	while ($$code =~ /(?:(\w+)\s*=\s*)?($real|$decimal|$integer)[ \t]*(;|\n|$)?/msg ) {
		# if the magic number
		# - is not assigned to an identifier..
		# - is not the last item of the instruction (i.e. not followed by a ";" or "\n")
		# - OR is assigned to an indent that isn't a constant ..
		if ((! defined $1) || (! defined $3) ||(! exists $consts->{$1}) ) {
			my $value = $2;
			if ($value !~ /^(?:\d|0\.|\.0|0\.0|1\.0)$/) {
				$nb_MagicNumbers++;
				Erreurs::VIOLATION($MagicNumbers__mnemo, "Magic number : $value");
			}
		}
	}
}

sub checkArtifact($$$);
sub checkArtifact($$$) {
	my $artifact = shift;
	my $context = shift;
	my $artifactView = shift;
#print "CHECKING : ".GetName($artifact)."\n";
	my $artikey = getPythonKindData($artifact, 'artifact_key');
	my $artifactCode = \$artifactView->{$artikey};
	
	my $children = Lib::NodeUtil::GetChildren($artifact);
	
	my $localVar = {};
	
	my $contextID = "#";    # for a class
	if ((IsKind($artifact, FunctionKind)) || (IsKind($artifact, MethodKind))) {
		# For a FUNCTION/METHOD ...
		$contextID = "/";    # for a function
		$localVar = getPythonKindData($artifact, 'local_variables');
		my $consts = getPythonKindData($artifact, 'local_constants');
		
		for my $var ( keys %$localVar ) {
			checkVarName($var, $consts);
		}
		
		# check magic numbers in function/methods ...
		countMagicNumbers($artifactCode, $consts);       # count inside body
		countMagicNumbers(GetStatement($artifact), {});  # count inside prototype
	}
	else {
		# For a CLASS ...
		my $attributes = getPythonKindData($artifact, 'local_variables');
		for my $var ( keys %$attributes ) {
			checkAttributeName($var);
		}
		# check magic numbers in classes ...
		countMagicNumbers($artifactCode, {});
	}
	$contextID .= GetName($artifact);
	
	my $localUsed = {};
	my $localUnused = {};

	my $localContext = [$localVar, $contextID, {}, {} ];

	# check if previous levels vars are hidden by local var ...
	# NOTE : contexts the stack of vars info for each class/function nested levels
	for my $ctx (@$context) {
		# get the local var of the context being iterated ...
		my $varlist = $ctx->[0];
		my $used = $ctx->[2];
		my $unused = $ctx->[3];
		for my $var (keys %$varlist) {
			if (defined $localVar->{$var}) {
				Erreurs::VIOLATION($GlobalVariableHidding__mnemo, "Local variable ($var) is hidding global declaration in function (".GetName($artifact).")");
				$nb_GlobalVariableHidding++;
				delete $localVar->{$var};
			}
			# the var is not hidden by a local var ==> check if it is used in the artifact !
			else {
				# check if the var is already used elsewhere ...
				if (! exists $used->{$var}) {
					#... if not, check if used in this artifact ...
					checkVarUses([$var], $used, $unused, $artifactCode);
				}
			}
		}
	}

	# check if local var are used ...
	my @vars = keys %$localVar;
	checkVarUses(\@vars, $localUsed, $localUnused, $artifactCode);
	
	push @$context, $localContext;
	
	for my $child (@$children) {
		if (IsKind($child, FunctionKind) || IsKind($child, MethodKind) || IsKind($child, ClassKind)) {
			checkArtifact($child, $context, $artifactView);
		}
	}
	pop @$context;
	
#print "--> used : ".join(',', keys %$localUsed)."\n";
#print "--> unused : ".join(',', keys %$localUnused)."\n";
	
	for my $unusedVar (keys %{$localUnused}) {
		$nb_VarNotUsed++;
		Erreurs::VIOLATION($VarNotUsed__mnemo, "unused variable: $unusedVar");
	}
	$localUnused
}

sub CountVariablesHidding($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	my $ret =0;

	$nb_GlobalVariableHidding = 0;
	$nb_VarNotUsed = 0;
	$nb_BadVariableNames = 0;
	$nb_BadAttributeNames = 0;
	$nb_MagicNumbers = 0;

	my $r_code = \$vue->{'code'};
	my $artifactView = $vue->{'artifact'};
	my $root = $vue->{'structured_code'};
	
	if (( ! defined $r_code ) || (!defined $artifactView) || (! defined $root)) {
		$ret |= Couples::counter_add($compteurs, $GlobalVariableHidding__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $VarNotUsed__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadVariableNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadAttributeNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MagicNumbers__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $children = Lib::NodeUtil::GetChildren($root);
	
	my $rootVar = getPythonKindData($root, 'local_variables');
	my $rootConsts = getPythonKindData($root, 'local_constants');
	
	my $rootCode = \$artifactView->{'root'};
	
	# check magic numbers in root ...
	countMagicNumbers($rootCode, $rootConsts);
	
	for my $var (keys %$rootVar) {
		checkVarName($var, $rootConsts);
	}
	
	my @vars = keys %$rootVar;
	my $used = {};
	my $unused = {};
	checkVarUses(\@vars, $used, $unused, $rootCode);
	
	#my $contexts = [[$rootVar, "", $used, $unused]];
	
	for my $child (@$children) {
		if (IsKind($child, FunctionKind) || IsKind($child, MethodKind) || IsKind($child, ClassKind)) {
			checkArtifact($child, [[$rootVar, "", $used, $unused]], $artifactView);
		}
	}

	for my $unusedVar (keys %{$unused}) {
		$nb_VarNotUsed++;
		Erreurs::VIOLATION($VarNotUsed__mnemo, "unused variable: $unusedVar");
	}

	$ret |= Couples::counter_add($compteurs, $GlobalVariableHidding__mnemo, $nb_GlobalVariableHidding );
	$ret |= Couples::counter_add($compteurs, $VarNotUsed__mnemo, $nb_VarNotUsed );
	$ret |= Couples::counter_add($compteurs, $BadVariableNames__mnemo, $nb_BadVariableNames );
	$ret |= Couples::counter_add($compteurs, $BadAttributeNames__mnemo, $nb_BadAttributeNames );
	$ret |= Couples::counter_add($compteurs, $MagicNumbers__mnemo, $nb_MagicNumbers );

	return $ret;
}

sub checkVariable($) {
	my $var = shift;
	
	if (exists $Python::PythonConf::BUILTIN_EXCEPTION_NAME{$var}) {
		$nb_OverridenBuiltInException++;
		Erreurs::VIOLATION($OverridenBuiltInException__mnemo, "Assignment to builtin exception : $var");
	}
}

sub CountVariables($$$) {
	my ($file, $views, $compteurs) = @_ ;
	my $ret =0;

	$nb_OverridenBuiltInException = 0;
	$nb_GlobalVariables = 0;
	$nb_LocalVarAverage = 0;
	
	my $kindLists = $views->{'KindsLists'};
	my $root = $views->{'structured_code'};
	
	if (( ! defined $kindLists ) || (!defined $root)) {
		$ret |= Couples::counter_add($compteurs, $OverridenBuiltInException__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $GlobalVariables__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $LocalVarAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my @funcs = (@{$kindLists->{&FunctionKind}}, @{$kindLists->{&MethodKind}});
	
	# check root (global !!) var ...
	for my $var (keys %{getPythonKindData($root, 'local_variables')}) {
		checkVariable($var);
		if ($var =~ /[a-z]/) { 
			$nb_GlobalVariables++;
			Erreurs::VIOLATION($GlobalVariables__mnemo, "Global variable : $var");
		}
	}

	my $NB_FUNCS = 0;
	my $NB_LOCAL_VAR = 0;
	# check functions's var...
	for my $func (@funcs) {
		$NB_FUNCS++;
		for my $var (keys %{getPythonKindData($func, 'local_variables')}) {
			checkVariable($var);
			$NB_LOCAL_VAR++;
		}
	}
	
	if ($NB_FUNCS) {
		$nb_LocalVarAverage = int ($NB_LOCAL_VAR/$NB_FUNCS);
	}
	Erreurs::VIOLATION($LocalVarAverage__mnemo, "Local variables average : $nb_LocalVarAverage");
	
	$ret |= Couples::counter_update($compteurs, $OverridenBuiltInException__mnemo, $nb_OverridenBuiltInException );
	$ret |= Couples::counter_update($compteurs, $GlobalVariables__mnemo, $nb_GlobalVariables );
	$ret |= Couples::counter_update($compteurs, $LocalVarAverage__mnemo, $nb_LocalVarAverage );

	return $ret;
}

1;


