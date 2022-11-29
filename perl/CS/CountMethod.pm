package CS::CountMethod;

use strict;
use warnings;

use Erreurs;
use Lib::NodeUtil;
use CS::CSNode;
use CS::CountNaming;

my $TotalParameters_mnemo = Ident::Alias_TotalParameters();
my $ShortMethodNamesLT_mnemo = Ident::Alias_ShortMethodNamesLT();
my $MethodNameLengthAverage_mnemo = Ident::Alias_MethodNameLengthAverage();
my $FunctionMethodImplementations_mnemo = Ident::Alias_FunctionMethodImplementations();
my $Finalize_mnemo = Ident::Alias_Finalize();
my $WithTooMuchParametersMethods_mnemo = Ident::Alias_WithTooMuchParametersMethods();
my $ParametersAverage_mnemo = Ident::Alias_ParametersAverage();
my $UnusedParameters_mnemo = Ident::Alias_UnusedParameters();
my $UnusedLocalVariables_mnemo = Ident::Alias_UnusedLocalVariables();
my $LostInitialization_mnemo = Ident::Alias_LostInitialization();
my $EmptyMethods_mnemo = Ident::Alias_EmptyMethods();
my $MethodsLengthAverage_mnemo = Ident::Alias_MethodsLengthAverage();
my $LongArtifact_mnemo = Ident::Alias_LongArtifact();
my $FunctionOutParameters_mnemo = Ident::Alias_FunctionOutParameters();
my $BadMethodNames_mnemo = Ident::Alias_BadMethodNames();

my $nb_TotalParameters = 0;
my $nb_ShortMethodNamesLT = 0;
my $nb_MethodNameLengthAverage = 0;
my $nb_FunctionMethodImplementations = 0;
my $nb_Finalize = 0;
my $nb_WithTooMuchParametersMethods = 0;
my $nb_ParametersAverage = 0;
my $nb_UnusedParameters = 0;
my $nb_UnusedLocalVariables = 0;
my $nb_LostInitialization = 0;
my $nb_EmptyMethods = 0;
my $nb_MethodsLengthAverage = 0;
my $nb_LongArtifact = 0;
my $nb_FunctionOutParameters = 0;
my $nb_BadMethodNames = 0;

sub CountFinalyzer($$$$) {
	my ($fichier, $views, $compteurs, $options) = @_;
    
    $nb_Finalize = 0;
    
	my $status = 0;
	
	my $KindsLists = $views->{'KindsLists'};

	if ( ! defined $KindsLists ) {
		$status |= Couples::counter_add($compteurs, $Finalize_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $Dtors = $KindsLists->{&DestructorKind};
	
			# check finalize
	for my $finalyzer (@$Dtors) {
		$nb_Finalize++;
		Erreurs::VIOLATION($Finalize_mnemo, "Finalizer declaration at line ".GetLine($finalyzer));
	}
	
	$status |= Couples::counter_add($compteurs, $Finalize_mnemo, $nb_Finalize);

	return $status;
}


sub getBody_nbLOC($$) {
	my $meth = shift;
	my $views = shift;
	
	my $agglo = \$views->{'agglo'};
	my $agglo_LinesIndex = $views->{'agglo_LinesIndex'};
	my $code = \$views->{'code'};
	
	my $bodyLineBegin = getCSKindData($meth, 'body_line_begin');
	
	return 0 if (!defined $bodyLineBegin);
	
	my $bodyLineEnd = GetEndline($meth);
	
	my $beginIdx = $agglo_LinesIndex->[$bodyLineBegin];
	my $endIdx = $agglo_LinesIndex->[$bodyLineEnd];
	
	my $LOC = () = substr($$agglo, $beginIdx, $endIdx-$beginIdx) =~ /P/g;
	
	return $LOC;
}

sub CountMethods($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
	my $status = 0;
	
	$nb_TotalParameters = 0;
	$nb_ShortMethodNamesLT = 0;
	$nb_MethodNameLengthAverage = 0;
	$nb_FunctionMethodImplementations = 0;
	$nb_WithTooMuchParametersMethods = 0;
	$nb_ParametersAverage = 0;
	$nb_UnusedParameters = 0;
	$nb_UnusedLocalVariables = 0;
	$nb_LostInitialization = 0;
	$nb_EmptyMethods = 0;
	$nb_MethodsLengthAverage = 0;
	$nb_LongArtifact = 0;
	$nb_FunctionOutParameters = 0;
	$nb_BadMethodNames = 0;
	
	my $KindsLists = $views->{'KindsLists'};
	my $HString = $views->{'HString'};

	if ( ! defined $KindsLists ) {
		$status |= Couples::counter_add($compteurs, $TotalParameters_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $ShortMethodNamesLT_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $FunctionMethodImplementations_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $Finalize_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $UnusedParameters_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $UnusedLocalVariables_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $LostInitialization_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $EmptyMethods_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $LongArtifact_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $FunctionOutParameters_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $BadMethodNames_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $methods = $KindsLists->{&MethodKind};
	
	$nb_FunctionMethodImplementations = scalar @$methods;
	
	my $nb_namesToCheck = 0;
	my $nb_fct_with_params = 0;
	my $nbWithBodyMethods = 0;
	
	for my $meth (@$methods) {
		
		my $name = GetName($meth);
		my $line = GetLine($meth);
		my $H_modifiers = getCSKindData($meth, 'H_modifiers');
		
		my $methodCodeBody = Lib::NodeUtil::GetKindData($meth)->{'codeBody'};

		# BODY
		if (defined $methodCodeBody) {
			if ($$methodCodeBody !~ /\S/) {
				$nb_EmptyMethods++;
				Erreurs::VIOLATION($EmptyMethods_mnemo, "Empty method '$name' at line $line");
			}	
		}
		
		# length
		my $nbLOC = getBody_nbLOC($meth, $views);

		if ($nbLOC) {
			$nb_MethodsLengthAverage += $nbLOC;
			$nbWithBodyMethods++;
		}
	
		if ($nbLOC > CS::CSConfig::MAX_METHOD_LENGTH) {
			$nb_LongArtifact++;
			Erreurs::VIOLATION($LongArtifact_mnemo, "Method $name has too many lines ($nbLOC)");
		}

#print STDERR "BODY($name) =\n$$methodCodeBody\n";
		# NAME
		$nb_MethodNameLengthAverage += length($name);
		$nb_namesToCheck++;
		if (CS::CountNaming::checkMethodNameLength($name)) {
			Erreurs::VIOLATION($ShortMethodNamesLT_mnemo, "Too short method name : $name at line $line");
			$nb_ShortMethodNamesLT++;
		}
		
		if (CS::CountNaming::checkMethodName($name)) {
			Erreurs::VIOLATION($BadMethodNames_mnemo, "Too short method name : $name at line $line");
			$nb_BadMethodNames++;
		}
		
		my $args = getCSKindData($meth, 'arguments');
		
		my $nb_params = scalar @$args;
		$nb_TotalParameters += $nb_params;
		
		if ($nb_params) {
			$nb_ParametersAverage += $nb_params;
			$nb_fct_with_params++;
		}
		
		if ($nb_params > CS::CSConfig::MAX_PARAMETERS) {
			$nb_WithTooMuchParametersMethods++;
			Erreurs::VIOLATION($WithTooMuchParametersMethods_mnemo, "Too many parameters ($nb_params) for method '$name' at line $line");
		}
		
		# ARGUMENTS
		for my $arg (@$args) {
			my $paramName = $arg->{'name'};
			
			if (((exists $arg->{'mode'}->{'out'}) || (exists $arg->{'mode'}->{'ref'})) && (exists $H_modifiers->{'public'})) {
				$nb_FunctionOutParameters++;
				Erreurs::VIOLATION($FunctionOutParameters_mnemo, "OUT/REF argument at line $arg->{'line'}");
			}		
			
			if (defined $paramName) {
				if (defined $methodCodeBody) {
					
					# check usage of the parameter
					if ($$methodCodeBody =~ /[^\.]\b$paramName\b\s*/gc) {
						# check if used with dereferencement or assignment
						if ($$methodCodeBody =~ /\G(\.|=)[^=]/gc) {
							# Found the first instruction using the parameter.
							if ($1 eq "=") {
								if (! exists $arg->{'mode'}->{'out'}) {
									pos($$methodCodeBody)--;
									$$methodCodeBody =~ /\G([^;]+)/gc;
									my $assignExpr = $1;
									if ($assignExpr !~ /\b$paramName\b/) {
										$nb_LostInitialization++;
										Erreurs::VIOLATION($LostInitialization_mnemo, "Parameter '$paramName' with possible useless default value for method '$name' at line $line");
									}
								}
							}
							else {
								# dereferencement operator (dot) encountered before assignment operator (=)
								# ==> parameter is dereferenced, so even if assigned, it is only a field, not the whole parameter
							}
						}
					}
					else {
						# parameter is not used
						$nb_UnusedParameters++;
						Erreurs::VIOLATION($WithTooMuchParametersMethods_mnemo, "Unused parameter $paramName for method '$name' at line $line");
					}
				}
			}
			pos($$methodCodeBody) = 0 if (defined $methodCodeBody);
		}
		
		# LOCAL VARIABLE
		if (defined $methodCodeBody) {
			my @variables = GetNodesByKind($meth, VariableKind);

			for my $var (@variables) {
				my $variableName = quotemeta GetName($var);

				# use [^\w] instead of \b because $variableName can begin with @
				my $nbOccurences = () = $$methodCodeBody =~ /[^\w]$variableName\b/g;

				if ($nbOccurences < 2) {
				
					# check inside interpolated strings
					my $found_inside_string = 0;
					while ($$methodCodeBody =~ /\b(CHAINE_\d+)\b/g) {
						my $id_string = $1;
						if ($HString->{$id_string} =~ /\A\$"/) {
							# use a pattern beginning with [^\w] $variableName can begin with @				
							if ($HString->{$id_string} =~ /\{[^\}]*(?:\b$variableName\b|[^\w]$variableName\b)/) {
								$found_inside_string = 1;
								last;
							}
						}
					}
					if (! $found_inside_string) {
						$nb_UnusedLocalVariables++;
						Erreurs::VIOLATION($UnusedLocalVariables_mnemo, "Unused local variable $variableName in method '$name' at line ".GetLine($var));
					}
				}
			}
		}
	}
	
	if ($nb_namesToCheck) {
		$nb_MethodNameLengthAverage = int($nb_MethodNameLengthAverage/$nb_namesToCheck);
	}
	
	if ($nb_FunctionMethodImplementations) {
		$nb_ParametersAverage = int( $nb_ParametersAverage / $nb_FunctionMethodImplementations);
	}
	
	if ($nbWithBodyMethods) {
		$nb_MethodsLengthAverage = int($nb_MethodsLengthAverage / $nbWithBodyMethods);
	}
	
	$status |= Couples::counter_add($compteurs, $TotalParameters_mnemo, $nb_TotalParameters);
	$status |= Couples::counter_add($compteurs, $ShortMethodNamesLT_mnemo, $nb_ShortMethodNamesLT);
	$status |= Couples::counter_add($compteurs, $MethodNameLengthAverage_mnemo, $nb_MethodNameLengthAverage);
	$status |= Couples::counter_add($compteurs, $FunctionMethodImplementations_mnemo, $nb_FunctionMethodImplementations);
	$status |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods_mnemo, $nb_Finalize);
	$status |= Couples::counter_add($compteurs, $ParametersAverage_mnemo, $nb_ParametersAverage);
	$status |= Couples::counter_add($compteurs, $UnusedParameters_mnemo, $nb_UnusedParameters);
	$status |= Couples::counter_add($compteurs, $UnusedLocalVariables_mnemo, $nb_UnusedLocalVariables);
	$status |= Couples::counter_add($compteurs, $LostInitialization_mnemo, $nb_LostInitialization);
	$status |= Couples::counter_add($compteurs, $EmptyMethods_mnemo, $nb_EmptyMethods);
	$status |= Couples::counter_add($compteurs, $MethodsLengthAverage_mnemo, $nb_MethodsLengthAverage);
	$status |= Couples::counter_add($compteurs, $LongArtifact_mnemo, $nb_LongArtifact);
	$status |= Couples::counter_add($compteurs, $FunctionOutParameters_mnemo, $nb_FunctionOutParameters);
	$status |= Couples::counter_add($compteurs, $BadMethodNames_mnemo, $nb_BadMethodNames);
	
	return $status;
} 

sub CountDestructors($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
    #$nb_EmptyDestructors = 0;
    
	my $status = 0;
	
	my $KindsLists = $views->{'KindsLists'};
	my $HString = $views->{'HString'};

	if ( ! defined $KindsLists ) {
		#$status |= Couples::counter_add($compteurs, $EmptyDestructors_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $destructors = $KindsLists->{&DestructorKind};
	
	for my $dest (@$destructors) {
		my $body = Lib::NodeUtil::GetKindData($dest)->{'codeBody'};

		if (defined $body) {
			if ($$body !~ /\S/) {
				#$nb_EmptyDestructors++;
				#Erreurs::VIOLATION($EmptyDestructors_mnemo, "Empty destructor at line ".GetLine($dest));
				Erreurs::VIOLATION("EMPTY DESTRUCTOR", "Empty destructor at line ".GetLine($dest));
			}	
		}
	}
	
	#$status |= Couples::counter_add($compteurs, $EmptyDestructors_mnemo, $nb_EmptyDestructors);

	return $status;
} 

1;

