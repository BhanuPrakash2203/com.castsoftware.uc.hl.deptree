package Python::CountClass;

use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Python::PythonNode;
use Python::PythonConf;
use Python::CountNaming;

my $IllegalException__mnemo = Ident::Alias_IllegalException();
my $ConstructorWithReturn__mnemo = Ident::Alias_ConstructorWithReturn();
my $FromScratchClasses__mnemo = Ident::Alias_FromScratchClasses();
my $MagicMethodsCalls__mnemo = Ident::Alias_MagicMethodsCalls();
my $BadGetterSetter__mnemo = Ident::Alias_BadGetterSetter();
my $MissingParentConstructor__mnemo = Ident::Alias_MissingParentConstructor();
my $BadStaticOrClassMethods__mnemo = Ident::Alias_BadStaticOrClassMethods();
my $MethodsAverage__mnemo = Ident::Alias_MethodsAverage();
my $BadClassNames__mnemo = Ident::Alias_BadClassNames();
my $ClassImplementations__mnemo = Ident::Alias_ClassImplementations();
my $MethodImplementations__mnemo = Ident::Alias_MethodImplementations();

my $nb_IllegalException = 0;
my $nb_ConstructorWithReturn = 0;
my $nb_FromScratchClasses = 0;
my $nb_MagicMethodsCalls = 0;
my $nb_BadGetterSetter = 0;
my $nb_MissingParentConstructor = 0;
my $nb_BadStaticOrClassMethods = 0;
my $nb_MethodsAverage = 0;
my $nb_BadClassNames = 0;
my $nb_ClassImplementations = 0;
my $nb_MethodImplementations = 0;

my $artifactView;

sub checkMethod($$$$) {
	my $func = shift;
	my $className = shift;
	my $parentsClasses = shift;
	my $H_getset = shift;
	
	my $meth = $func->[0];
	my $H_decorators = $func->[1];
	my $H_args = getPythonKindData($meth, 'arguments');
	my $methName = GetName($meth);

	my $artikey = getPythonKindData($meth, 'artifact_key');
	my $artifactCode = \$artifactView->{$artikey};
	
	# check java-style getters ...
	for my $getter (keys %$H_getset) {
		# for each function whose name complies with a getter nomenclature, check if it is used "as is" (i.e. preceded from "self")...
		if ($$artifactCode =~ /\bself\._*$getter\b[\.\w]*\s*[^(]/i) {
			$nb_BadGetterSetter++;
			Erreurs::VIOLATION($BadGetterSetter__mnemo, "Unexpected java-style getter : $H_getset->{$getter}");
			delete $H_getset->{$getter};
		}
	}
	
	# check static / class methods
		if (exists $H_decorators->{'classmethod'}) {
		if (! exists $H_args->{'cls'}) {
			$nb_BadStaticOrClassMethods++;
			Erreurs::VIOLATION($BadStaticOrClassMethods__mnemo, "Missing cls parameter for class method at line ".GetLine($meth));
		}
	}
	elsif (! exists $H_decorators->{'staticmethod'}) {
		if (! exists $H_args->{'self'}) {
			$nb_BadStaticOrClassMethods++;
			Erreurs::VIOLATION($BadStaticOrClassMethods__mnemo, "Missing self parameter for non-static method at line ".GetLine($meth));
		}
	}
	
	#while ($$artifactCode =~ /\bself\.(\w+)\b[\.\w]*\s*[^(]/sg) {
	#	#$H_members{$1} = 1;
	#}
	
	#my @T_parenthesises = split ',', $parenthesises;
	#my $nbParents = scalar @T_parenthesises;
	#for my $parent (@T_parenthesises) {
	#	$parent =~ s/\s+//g;
	#	if ($artifactCode =~ /\b$parent\./) {
#print "HARD REFERENCE TO PARENT CLASS : $parent ($nbParents parents)!!!\n";
	#	}
	#}

	if ($methName eq '__init__') {
#		if ($artifactCode =~ /\breturn\b[ \t]+(?:[ \t]*\\\n)*[ \t]*[^ \t\n\\]/) {
		if (Lib::NodeUtil::IsContainingKind($meth, ReturnKind)) {
			$nb_ConstructorWithReturn++;
			Erreurs::VIOLATION($ConstructorWithReturn__mnemo, "Returning a value from $className.__init__()");
		}
		
		if ($$artifactCode !~ /\bsuper\s*\([^)]*\)\s*\.\s*__init__\s*\(/) {
			for my $parent (@$parentsClasses) {
				if ($parent ne 'object') {
					if ($$artifactCode !~ /\b$parent\s*\.\s*__init__\s*\(/) {
						$nb_MissingParentConstructor++;
						Erreurs::VIOLATION($MissingParentConstructor__mnemo, "Missing call to parent init $parent.__init__()");
						last;
					}
				}
			}
		}
	}

	while ($$artifactCode =~ /\w+.(__\w+__)\s*\(/sg ) {
		if ($1 ne $methName) {
			# $1 is not a call to an overriden methode, so it's a violation
			$nb_MagicMethodsCalls++;
			Erreurs::VIOLATION($MagicMethodsCalls__mnemo, "Call to the magic method ($1) in method $methName of class $className");
		}
	}
}

sub CountClasses($$$) {
	my ($file, $views, $compteurs) = @_ ;
	my $ret =0;

	$nb_IllegalException = 0;
	$nb_ConstructorWithReturn = 0;
	$nb_FromScratchClasses = 0;
	$nb_MagicMethodsCalls = 0;
	$nb_BadGetterSetter = 0;
	$nb_MissingParentConstructor = 0;
	$nb_BadStaticOrClassMethods = 0;
	$nb_MethodsAverage = 0;
	$nb_BadClassNames = 0;
	$nb_ClassImplementations = 0;
	$nb_MethodImplementations = 0;
	
	my $kindLists = $views->{'KindsLists'};
	my $root = $views->{'structured_code'};
	$artifactView = $views->{'artifact'};
	
	if (( ! defined $kindLists ) || (!defined $root)) {
		$ret |= Couples::counter_add($compteurs, $IllegalException__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ConstructorWithReturn__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MagicMethodsCalls__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadGetterSetter__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MissingParentConstructor__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadStaticOrClassMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadClassNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ClassImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MethodImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $classes = $kindLists->{&ClassKind};

	# check functions's var...
	for my $class (@$classes) {
		
		my $className = GetName($class);
		
		if ( ! Python::CountNaming::isValidClassName($className)) {
			$nb_BadClassNames++;
			Erreurs::VIOLATION($BadClassNames__mnemo, "Bad class name $className at line ".GetLine($class));
		}
		
		my ($parenthesises) = ${GetStatement($class)} =~ /\(([^)]*)\)/;

		$nb_ClassImplementations++;

		if (! defined $parenthesises) {
			$nb_FromScratchClasses++;
			Erreurs::VIOLATION($FromScratchClasses__mnemo, "No parent declaration for class $className at line ".GetLine($class));
		}
		
		if (defined $parenthesises) {
			if ($className =~ /(?:Exception|Error)$/m) {
				if (($parenthesises !~ /(?:Exception|Error)\b/) || ($parenthesises =~ /\bBaseException\b/)) {
					$nb_IllegalException += 1;
					Erreurs::VIOLATION($IllegalException__mnemo, "Exception class $className is badly derived at line ".GetLine($class) );
				}
			}
		}
		
		my @T_parents = ();
		if (defined $parenthesises) {
			# if parent list contain parentheses, do not capture. Capture only simple list of parents classes, not functions call returning a list of parent class.
			if ($parenthesises !~ /\(/) {
				@T_parents = split ',', $parenthesises;
			}
		}
		my $nbParents = scalar @T_parents;
		for my $parent (@T_parents) {
			$parent =~ s/\s+//g;
		}

		my @T_FuncNodes = ();
		my %H_getset = ();
		my $propertyDecoratorFound = 0;
		my $H_decorator = {};

		my $children = Lib::NodeUtil::GetChildren($class);
		for my $child (@$children) {
			if ((IsKind($child, FunctionKind)) || (IsKind($child, MethodKind))) {
				
				push @T_FuncNodes, [$child, $H_decorator];
				if (! $propertyDecoratorFound) {
					if (GetName($child) =~ /^[gs]et(?:_)*(\w+)$/m) {
						# Add to the list of methods having a getter/setter javastyle name.
						$H_getset{$1} = GetName($child);
					}
				}
				$propertyDecoratorFound = 0;
				$H_decorator = {};
			}
			elsif (IsKind($child, DecorationKind)) {
				my $decoStmt = GetStatement($child);
				if ($$decoStmt =~ /\bproperty\b|\b\w+\.setter\b/) {
					$propertyDecoratorFound = 1;
					$H_decorator->{'property'} = 1;
				}
				elsif ($$decoStmt =~ /\bstaticmethod\b/) {
					$H_decorator->{'staticmethod'} = 1;
				}
				elsif ($$decoStmt =~ /\bclassmethod\b/) {
					$H_decorator->{'classmethod'} = 1;
				}
			}
		}

		for my $func (@T_FuncNodes) {
			$nb_MethodImplementations++;
			checkMethod($func, $className, \@T_parents, \%H_getset);
		}
	}
	
	if ($nb_ClassImplementations) {
		$nb_MethodsAverage = int( $nb_MethodImplementations / $nb_ClassImplementations);
	}
	else {
		$nb_MethodsAverage = 0;
	}
	Erreurs::VIOLATION($MethodsAverage__mnemo, "Number of methods average is $nb_MethodsAverage");

	$ret |= Couples::counter_update($compteurs, $IllegalException__mnemo, $nb_IllegalException );
	$ret |= Couples::counter_update($compteurs, $ConstructorWithReturn__mnemo, $nb_ConstructorWithReturn );
	$ret |= Couples::counter_update($compteurs, $MagicMethodsCalls__mnemo, $nb_MagicMethodsCalls );
	$ret |= Couples::counter_update($compteurs, $BadGetterSetter__mnemo, $nb_BadGetterSetter );
	$ret |= Couples::counter_update($compteurs, $MissingParentConstructor__mnemo, $nb_MissingParentConstructor );
	$ret |= Couples::counter_update($compteurs, $BadStaticOrClassMethods__mnemo, $nb_BadStaticOrClassMethods );
	$ret |= Couples::counter_update($compteurs, $MethodsAverage__mnemo, $nb_MethodsAverage );
	$ret |= Couples::counter_update($compteurs, $BadClassNames__mnemo, $nb_BadClassNames );
	$ret |= Couples::counter_update($compteurs, $ClassImplementations__mnemo, $nb_ClassImplementations );
	$ret |= Couples::counter_update($compteurs, $MethodImplementations__mnemo, $nb_MethodImplementations );

	return $ret;
}

1;



