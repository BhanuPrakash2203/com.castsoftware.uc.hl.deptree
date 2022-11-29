package Kotlin::CountRoutines;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;
use Lib::CountUtils;

use Kotlin::KotlinNode;


my $EmptyArtifact__mnemo = Ident::Alias_EmptyArtifact();
my $UnusedParameters__mnemo = Ident::Alias_UnusedParameters();
my $UnusedPrivateMethods__mnemo = Ident::Alias_UnusedPrivateMethods();
my $UnusedLocalVariables__mnemo = Ident::Alias_UnusedLocalVariables();
my $WithUnexpectedBodyFunctions__mnemo = Ident::Alias_WithUnexpectedBodyFunctions();
my $ParametersAverage__mnemo = Ident::Alias_ParametersAverage();
my $FunctionExpressions__mnemo = Ident::Alias_FunctionExpressions();
my $FunctionImplementations__mnemo = Ident::Alias_FunctionImplementations();
my $RoutinesLengthIndicator__mnemo = Ident::Alias_RoutinesLengthIndicator();
my $LabeledReturnsInLambda__mnemo = Ident::Alias_LabeledReturnsInLambda();
my $LabeledReturnEndingLambda__mnemo = Ident::Alias_LabeledReturnEndingLambda();
my $BadFunctionNames__mnemo = Ident::Alias_BadFunctionNames();
my $BadMethodNames__mnemo = Ident::Alias_BadMethodNames();
my $RoutineNameLengthAverage__mnemo = Ident::Alias_RoutineNameLengthAverage();
my $VgAverage__mnemo = Ident::Alias_VgAverage();

my $nb_EmptyArtifact = 0;
my $nb_UnusedParameters = 0;
my $nb_UnusedPrivateMethods = 0;
my $nb_UnusedLocalVariables = 0;
my $nb_WithUnexpectedBodyFunctions = 0;
my $nb_ParametersAverage = 0;
my $nb_FunctionExpressions = 0;
my $nb_FunctionImplementations = 0;
my $nb_RoutinesLengthIndicator = 0;
my $nb_LabeledReturnsInLambda = 0;
my $nb_LabeledReturnEndingLambda = 0;
my $nb_RoutineNameLengthAverage = 0;
my $nb_VgAverage = 0;

sub DetectCommentBetweenTwoLines($$$)
{

    my $views = shift;
    my $BeginningLine = shift;
    my $EndLine = shift;

    my $index1 = $views->{'agglo_LinesIndex'}->[$BeginningLine];
    my $index2 = $views->{'agglo_LinesIndex'}->[$EndLine+1];
#print "line $BeginningLine a $EndLine \n";
#print "index $index1 a index $index2 \n";

    my $bloc;
    if (defined $index2) {
#print "BLOC ($index1 - $index2) = ".substr ($views->{'agglo'}, $index1, ($index2-$index1))."\n";
        $bloc = substr ($views->{'agglo'}, $index1, ($index2-$index1));
    }
    else {
        $bloc = substr ($views->{'agglo'}, $index1);
    }
# print 'bloc ' . $bloc."\n";
    if ($bloc  !~ /C/)
    {
        # alert
        return 0;    
    }        
    return 1;

}

sub searchInsideInterpolatedString($$$$$) {
	my $code = shift;
	my $begin = shift;
	my $length = shift;
	my $reg = shift;
	my $HString = shift; 
	
	my @Strings = substr($$code, $begin, $length) =~ /(\bCHAINE_\d+\b)/g;
	for my $str (@Strings) {
		if ($HString->{$str} =~ /$reg/) {
			return 1;
		}
	}
	return 0;
}

sub atleastOneOccurence($$$$) {
	my $name = shift;
	my $code = shift;
	my $codePosition = shift;
	my $reg = shift;
	
	if (substr($$code, $codePosition->{'begin'}, $codePosition->{'length'}) =~ /$reg/) {
		return 1;
	}
	else {
		return 0;
	}
}

sub atLeastTwoOccurences($$$$) {
	my $name = shift;
	my $code = shift;
	my $codePosition = shift;
	my $reg = shift;
	
	my $nb = () = substr($$code, $codePosition->{'begin'}, $codePosition->{'length'}) =~ /$reg/g;
	if ($nb > 1) {
		return 1;
	}
	else {
		return 0;
	}
}

sub isVariableUsed($$$$;$) {
	my $name = shift;
	my $code = shift;
	my $codePosition = shift;
	my $HString = shift;
	my $searchInCode = shift || \&atleastOneOccurence;
	
	my $reg = qr/(?:\.\.|[^\.\s])\s*\b$name\b/;
	#if (substr($$code, $codePosition->{'begin'}, $codePosition->{'length'}) !~ /\b$name\b/) {
	if (! $searchInCode->($name, $code, $codePosition, $reg)) {
						
		# not found in the code ...
		# so search in interpolated strings ...
		if (! searchInsideInterpolatedString($code, $codePosition->{'begin'}, $codePosition->{'length'}, qr/(?:\$$name\b|\$\{[^\}]*\b$name\b[^\}]*\})/, $HString)) {
			return 0;
		}
		#my @Strings = substr($$code, $codePosition->{'begin'}, $codePosition->{'length'}) =~ /(\bCHAINE_\d+\b)/g;
		#for my $str (@Strings) {
		#	if ($HString->{$str} =~ /(?:\$$param\b|\$\{[^\}]*\b$param\b[^\}]*\})/) {
		#		return 1
		#	}
		#}
	}
	return 1;
}

sub isEmptyRoutine($$$) {   
	my $routine = shift;
	my $views = shift;
	my $H_modifiers = shift;
          
	my $instructions = GetChildren($routine);

	if (scalar @$instructions == 0)
	{
		# Routine is empty ... but ...
		if (! exists $H_modifiers->{'abstract'}) {
			# it is not abstract ..
			
			if (exists $H_modifiers->{'override'}) {
				my $resultDetectComment = DetectCommentBetweenTwoLines ($views, GetLine($routine), GetEndline($routine));

				if ($resultDetectComment == 0) {
					# Routine is an uncommented EMPTY OVERRIDE
					Erreurs::VIOLATION($EmptyArtifact__mnemo, "Empty (uncommented override) routine ".(GetName($routine)||"??")." at line ".(GetLine($routine)||"??"));
					return 1;
				}
			}
			else
			{
				# routine is NOT an OVERRIDE  
				Erreurs::VIOLATION($EmptyArtifact__mnemo, "Empty routine ".(GetName($routine)||"??")." at line ".(GetLine($routine)||"??"));
				return 1;
			}
		}
	}
    
    return 0;
}

sub CountRoutines($$$) 
{
	my ($file, $views, $compteurs) = @_ ;
    
	my $ret = 0;
	$nb_EmptyArtifact = 0;
	$nb_UnusedParameters = 0;
	$nb_UnusedPrivateMethods = 0;
	$nb_UnusedLocalVariables = 0;
	$nb_WithUnexpectedBodyFunctions = 0;
	$nb_ParametersAverage = 0;
	$nb_FunctionExpressions = 0;
	$nb_FunctionImplementations = 0;
	$nb_RoutinesLengthIndicator = 0;
	$nb_RoutineNameLengthAverage = 0;
	$nb_VgAverage = 0;

    my $KindsLists = $views->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $EmptyArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnusedPrivateMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnusedLocalVariables__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $WithUnexpectedBodyFunctions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ParametersAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $FunctionExpressions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $FunctionImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $RoutinesLengthIndicator__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $RoutineNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $VgAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	# Init counters that wil be updated in CountNaming
	$ret |= Couples::counter_update($compteurs, $BadFunctionNames__mnemo, 0 );
	$ret |= Couples::counter_update($compteurs, $BadMethodNames__mnemo, 0 );
  
	my $Functions = $KindsLists->{&FunctionKind};
	my $FunctionExpressions = $KindsLists->{&FunctionExpressionKind};
	my $Routines = [@$Functions, @$FunctionExpressions];

	$nb_FunctionImplementations = scalar @$Functions;
	$nb_FunctionExpressions = scalar @$FunctionExpressions;

	my $code = \$views->{'code'};

	my @Routines_LOC = ();
	
	my $namedRoutines = 0;
	
	for my $routine (@$Routines) {
		
		$ret |= Kotlin::CountNaming::checkFunctionNaming( $routine, $compteurs );
		
		my $bodyPosition = Lib::NodeUtil::GetXKindData($routine, 'position');

		my $name = GetName($routine);
		if (defined $name) {
			$nb_RoutineNameLengthAverage += length($name);
			$namedRoutines++;
		}
		
		my $line = GetLine($routine)||"??";

		my $H_modifiers = Lib::NodeUtil::GetXKindData($routine, 'H_modifiers') || {};
		my $routinePosition = Lib::NodeUtil::GetXKindData($routine, 'position');

		# check emptyness ...
		#--------------------
		$nb_EmptyArtifact++ if (isEmptyRoutine($routine, $views, $H_modifiers));

		# Check parameters
		#-----------------
		if (defined $bodyPosition) {
			my $params = Lib::NodeUtil::GetXKindData($routine, 'parameters');
			if (defined $params) {
				my $unusedAllowed = 0;
				
				$nb_ParametersAverage += scalar keys %$params;
				
				if (exists $H_modifiers->{'override'}) {
					my $children = GetChildren($routine);
					if (scalar @$children == 1) {
						if (IsKind($children->[0], ThrowKind)) {
							# override method that only rethrow => such unimplemented methods are exempt from parameter usage mandatory
							$unusedAllowed = 1;
						}
					}
				}
				
				# check a given parameter
				for my $param (keys %$params) {
					
					# check usage 
					if (! $unusedAllowed) {
						
						if (! isVariableUsed($param, $code, $bodyPosition, $views->{'HString'})) {
							# parameter is unused
							$nb_UnusedParameters++;
							Erreurs::VIOLATION($UnusedParameters__mnemo, "unused parameter ($param) at line $line");
						}
					}
				}
			}
		}
		
		# check private methods
		#-----------------------
		if (exists $H_modifiers->{'private'}) {
			my $parent = GetParent($routine);
			my $kind = GetKind($parent);
			if (($kind eq ClassKind) || ($kind eq ObjectDeclarationKind) || ($kind eq ObjectExpressionKind)) {
				my $ClassBodyPosition = Lib::NodeUtil::GetXKindData($parent, 'position');
				
				if (defined $ClassBodyPosition) {
					my $classBodyBegin = $ClassBodyPosition->{'begin'};
					my $classEnd = $ClassBodyPosition->{'end'};
					my $methBegin = $routinePosition->{'protoPos'};
					my $methEnd = $routinePosition->{'end'};
					
					# check in the body of the class if the method is used.
#print "PARENT CLASS BODY(except meth $name) = \n";
#print substr($$code, $classBodyBegin, $methBegin-$classBodyBegin)."\n";
#print "[ ... ]\n";
#print substr($$code, $methEnd, $classEnd-$methEnd)."\n";

					if (($methBegin > $classBodyBegin) && ($methEnd < $classEnd)) {
						if ((substr($$code, $classBodyBegin, $methBegin-$classBodyBegin) !~ /\b$name\b/) &&
							(substr($$code, $methEnd, $classEnd-$methEnd) !~ /\b$name\b/)) {
							
							my $reg = qr/(?:\$\{[^\}]*$name[^\}]*\})/;
							if (	(!searchInsideInterpolatedString($code, $classBodyBegin	, $methBegin-$classBodyBegin	, $reg, $views->{'HString'}) ) &&
									(!searchInsideInterpolatedString($code, $methEnd		, $classEnd-$methEnd			, $reg, $views->{'HString'}) ) ){
								Erreurs::VIOLATION($UnusedPrivateMethods__mnemo, "unused private method ($name) at line $line");
								$nb_UnusedPrivateMethods++;
							}
						}
					}
					else {
						Lib::Log::WARNING("method position doesn't fit inside class !!!");
					}
				}
			}
		}
		
		# check children
		#---------------
		my $children = GetChildren($routine);
		for my $child (@$children) {
			my $kind = GetKind($child);
			if (($kind eq VarKind) || ($kind eq ValKind) ) {
				# check local variables
				my $varName = GetName($child);
				my $varLine = GetLine($child)||"??";
				
				# We have to find at least 2 matches : one for the variable declaration et at least another one for a use case.
				if (! isVariableUsed($varName, $code, $routinePosition, $views->{'HString'}, \&atLeastTwoOccurences)) {
					Erreurs::VIOLATION($UnusedLocalVariables__mnemo, "unused local variable ($varName) at line $varLine (in method $name)");
					$nb_UnusedLocalVariables++;
				}	
			}
		}

		if (scalar @$children == 1) {
			# function contains a signgle instruction
			if (Lib::NodeUtil::GetXKindData($routine, 'implementation') eq "body") {
				# function is implemented with a body syntax
				my $firstChild = $children->[0];
				my $childKind = GetKind($firstChild);
				my $beginLine = GetLine($firstChild);
				my $endLine = GetEndline($routine);
				
				if ($endLine - $beginLine < 5) {
					# body length is less tha 5 lines ...
					if (( $childKind ne IfKind) && ( $childKind ne WhileKind) && ( $childKind ne ForKind) && ( $childKind ne WhenKind)) {
						$nb_WithUnexpectedBodyFunctions++;
						Erreurs::VIOLATION($WithUnexpectedBodyFunctions__mnemo, "function should rather be implemented with expression syntax at line $line (lentgh=".($endLine - $beginLine).")(".${GetStatement($firstChild)}.")");
					}	
				}
			}
		}
		
		my $nb_LOC = Lib::NodeUtil::getArtifactLinesOfCode($routine, $views);
		
		if (defined $nb_LOC) {
			push @Routines_LOC, $nb_LOC;
		}
		
		# Compute VG Average
		if (IsKind($routine, FunctionKind)) {
			my @items = GetNodesByKindList_StopAtBlockingNode(
								$routine,
								[IfKind, ElsifKind, BreakKind, ContinueKind, WhileKind, ForKind, ThrowKind, TryKind, CaseKind, LambdaKind, ReturnKind],
								#[ClassKind, FunctionKind, FunctionExpressionKind]);
								[ClassKind, FunctionKind]);
			$nb_VgAverage += scalar @items;
			if ((scalar @$children) && (IsKind($children->[-1], ReturnKind))) {
				# do not count "return" statement if placed at end of the routine.
				$nb_VgAverage--;
			}
		}
	}
	
	# LENGTH indicator
	my ($max, $average, $median) = Lib::CountUtils::getStatistic(\@Routines_LOC);
	my $nb_RoutinesLengthIndicator = int($max + $average + $median);
	my $nb_routinesUsed = scalar @Routines_LOC;
	$average = int($average);
	$median = int($median);
	Erreurs::VIOLATION($RoutinesLengthIndicator__mnemo, "METRIC : routines lentgh indicator is $nb_RoutinesLengthIndicator (MAX=$max, AVERAGE=$average, MEDIAN=$median for a total of $nb_routinesUsed routines used");
	
	# NB PARAMS AVERAGE
    my $nb_routines = $nb_FunctionExpressions + $nb_FunctionImplementations;
    if ($nb_routines) {
		$nb_ParametersAverage = int ($nb_ParametersAverage / ($nb_routines));
		Erreurs::VIOLATION($ParametersAverage__mnemo, "METRIC : functions parameters average is $nb_ParametersAverage for a total of $nb_routines");
	}
    
    # NB FUNCTIONS
    Erreurs::VIOLATION($FunctionImplementations__mnemo, "METRIC : number of functions && methods = $nb_FunctionImplementations");
    
    # NB FUNCTIONS EXPRESSION
    Erreurs::VIOLATION($FunctionExpressions__mnemo, "METRIC : number of lambdas = $nb_FunctionExpressions");
    
    # NAME LENGTH
    if ($namedRoutines) {
		$nb_RoutineNameLengthAverage = int($nb_RoutineNameLengthAverage/$namedRoutines);
	}
	Erreurs::VIOLATION($RoutineNameLengthAverage__mnemo, "METRIC : Routine name average = $nb_RoutineNameLengthAverage");
    
    # VG AVERAGE
    if ($nb_FunctionImplementations) {
		$nb_VgAverage = int ($nb_VgAverage / $nb_FunctionImplementations);
	}
    Erreurs::VIOLATION($VgAverage__mnemo, "METRIC : Vg (average) = $nb_VgAverage");
    
    $ret |= Couples::counter_add($compteurs, $EmptyArtifact__mnemo, $nb_EmptyArtifact );
    $ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, $nb_UnusedParameters );
    $ret |= Couples::counter_add($compteurs, $UnusedPrivateMethods__mnemo, $nb_UnusedPrivateMethods );
    $ret |= Couples::counter_add($compteurs, $UnusedLocalVariables__mnemo, $nb_UnusedLocalVariables );
    $ret |= Couples::counter_add($compteurs, $WithUnexpectedBodyFunctions__mnemo, $nb_WithUnexpectedBodyFunctions );
    $ret |= Couples::counter_add($compteurs, $ParametersAverage__mnemo, $nb_ParametersAverage );
    $ret |= Couples::counter_add($compteurs, $FunctionExpressions__mnemo, $nb_FunctionExpressions );
    $ret |= Couples::counter_add($compteurs, $FunctionImplementations__mnemo, $nb_FunctionImplementations );
    $ret |= Couples::counter_add($compteurs, $RoutinesLengthIndicator__mnemo, $nb_RoutinesLengthIndicator );
    $ret |= Couples::counter_add($compteurs, $RoutineNameLengthAverage__mnemo, $nb_RoutineNameLengthAverage );
    $ret |= Couples::counter_add($compteurs, $VgAverage__mnemo, $nb_VgAverage );
    
    return $ret;
}

sub CountLambdaReturn($$$) {
	my ($file, $views, $compteurs) = @_ ;
    
	my $ret = 0;
	$nb_LabeledReturnsInLambda = 0;
	$nb_LabeledReturnEndingLambda = 0;

#print STDERR "COUNT RETURN !!!!\n";
  
	my $KindsLists = $views->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $LabeledReturnsInLambda__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $LabeledReturnEndingLambda__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $lambdas = $KindsLists->{&LambdaKind};
	
	for my $lambda (@$lambdas) {
		my @returns = GetNodesByKind($lambda, ReturnKind);
		
		my $nb_labelledReturn = 0;
		for my $return (@returns) {
			#print STDERR "RETURN".${GetStatement($return)}."\n";
			if (${GetStatement($return)} =~ /^\s*\@/) {
				$nb_labelledReturn++;
			}
		}
		if ($nb_labelledReturn > 1) {
			Erreurs::VIOLATION($LabeledReturnsInLambda__mnemo, "too many labeled return ($nb_labelledReturn) in lambda at line ".GetLine($lambda));
			$nb_LabeledReturnsInLambda++;
		}
		my $children = GetChildren($lambda);
		if ((scalar @$children) && (IsKind($children->[-1], ReturnKind)) && (${GetStatement($children->[-1])} =~ /^\s*\@/)) {
			Erreurs::VIOLATION($LabeledReturnEndingLambda__mnemo, "useless labeled return at end of lambda at line ".GetLine($children->[-1]));
			$nb_LabeledReturnEndingLambda++;
		}
	}
	
    $ret |= Couples::counter_add($compteurs, $LabeledReturnsInLambda__mnemo, $nb_LabeledReturnsInLambda );
    $ret |= Couples::counter_add($compteurs, $LabeledReturnEndingLambda__mnemo, $nb_LabeledReturnEndingLambda );
    
    return $ret;
}

1;


