package Clojure::CountFunction;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::Node;
use Lib::NodeUtil;

use Clojure::ClojureNode;
use Clojure::Config;

my $FunctionMethodImplementations__mnemo = Ident::Alias_FunctionMethodImplementations();
my $BadArityIndentation__mnemo = Ident::Alias_BadArityIndentation();
my $BadMultiArityOrder__mnemo = Ident::Alias_BadMultiArityOrder();
my $MethodsLengthAverage__mnemo = Ident::Alias_MethodsLengthAverage();
my $LongArtifact__mnemo = Ident::Alias_LongArtifact();
my $WithTooMuchParametersMethods__mnemo = Ident::Alias_WithTooMuchParametersMethods();
my $ParametersAverage__mnemo = Ident::Alias_ParametersAverage();
my $GlobalDefInsideFunctions__mnemo = Ident::Alias_GlobalDefInsideFunctions();
my $LongFunctionLiteral__mnemo = Ident::Alias_LongFunctionLiteral();
my $ParameterShadow__mnemo = Ident::Alias_ParameterShadow();
my $BodyBeginOnSameLineThanParams__mnemo = Ident::Alias_BodyBeginOnSameLineThanParams();
my $TooDepthArtifact__mnemo = Ident::Alias_TooDepthArtifact();
my $ArtifactDepthAverage__mnemo = Ident::Alias_ArtifactDepthAverage();

my $nb_FunctionMethodImplementations = 0;
my $nb_BadArityIndentation = 0;
my $nb_BadMultiArityOrder = 0;
my $nb_MethodsLengthAverage = 0;
my $nb_LongArtifact = 0;
my $nb_WithTooMuchParametersMethods = 0;
my $nb_ParametersAverage = 0;
my $nb_GlobalDefInsideFunctions = 0;
my $nb_LongFunctionLiteral = 0;
my $nb_ParameterShadow = 0;
my $nb_BodyBeginOnSameLineThanParams = 0;
my $nb_TooDepthArtifact = 0;
my $nb_ArtifactDepthAverage = 0;

sub checkInnerDef($) {
	my $func = shift;
	
	my @defs = GetNodesByKindList_StopAtBlockingNode($func, [DefKind], [FunctionKind, FunctionArityKind]);
	
	for my $def (@defs) {
		$nb_GlobalDefInsideFunctions++;
		Erreurs::VIOLATION($GlobalDefInsideFunctions__mnemo, "Glonal definition ".(GetName($def)||"??")." declared inside a function at line ".GetLine($def));
	}
}

sub checkParameterShadow($$) {
	my $func = shift;
	my $params = shift;
	
	my %H_PARAM = ();
	for my $param (@$params) {
		$H_PARAM{$param} =1;
	}
	
	my @lets = GetNodesByKind($func, LetKind);
	
	for my $let (@lets) {
		my $H_variables = Clojure::ClojureNode::getClojureKindData($let, 'variables');
		
		for my $var (keys %$H_variables) {
			if (exists $H_PARAM{$var}) {
				$nb_ParameterShadow++;
				Erreurs::VIOLATION($ParameterShadow__mnemo, "Local variable at line ".GetLine($let)." is shadowing parameter '$var' at line ".GetLine($func));
			}
		}
	}
}

sub checkBodyLineBeginning($) {
	my $func = shift;
	
	my $endParametersLine = Clojure::ClojureNode::getClojureKindData($func, 'params_end_line');
	
	return if (! defined $endParametersLine);
	
	my $children = GetChildren($func);
	
	if (scalar @$children == 0) {
		print Lib::Log::WARNING("No body for function at line ".GetLine($func));
		return;
	}
	
	my $bodyLineBeginning = GetLine($children->[0]);
	
	if (!defined $bodyLineBeginning) {
		print Lib::Log::WARNING("Missing line for first instruction (kind = ".GetKind($children->[0]).") of function at line ".GetLine($func));
		return;
	}
	
	# Do not check if the body consists in only one form.
	return if ((scalar @$children <= 1) && (scalar @{GetChildren($children->[0])} == 0) );
	
	if ($bodyLineBeginning == $endParametersLine) {
		
		my $lastFormNode;
		while (defined $children->[-1]) {
			$lastFormNode = $children->[-1];
			$children = GetChildren($lastFormNode);			
		}
		my $lineOfLastForm = GetLine($lastFormNode);
		if ($lineOfLastForm != $endParametersLine) {
			$nb_BodyBeginOnSameLineThanParams++;
			Erreurs::VIOLATION($BodyBeginOnSameLineThanParams__mnemo, "Body takes several lines and begin on same line than parameters for function at line ".GetLine($func)."\n");
		}
	}
}

# node that should interrupt the depth calculus ...
my %STOP_DEEPNESS = (
	#&FunctionLiteralKind() => 1,
	&MapKind() => 1,
	&VectorKind() =>1,
	#&AnonymousKind() => 1,
	&ConditionKind() => 1,
);

# nodes that do not introduce a depth level (transparency nodes).
my %NO_DEPTH = (
	&ThenKind() => 1,
	&ElseKind() => 1,
	&CaseKind() => 1,
	&DefaultKind() => 1,
	&UnknowKind() => 1,
	&FunctionKind() => 1,
	&FunctionArityKind() => 1,
);

sub getDepthDepth($);
sub getDepthDepth($) {
	my $node = shift;

	my $children = GetChildren($node);
	my $kind = GetKind($node);
	
	my $depth = (exists $NO_DEPTH{$kind} ? 0 : 1);
	my $maxChildDepth = 0;
	for my $child (@$children) {
		$kind = GetKind($child);
		if (! exists $STOP_DEEPNESS{$kind}) {
			my $childDepth = getDepthDepth($child);
			if ($childDepth > $maxChildDepth) {
				$maxChildDepth = $childDepth;
			}
		}
	}
	$depth += $maxChildDepth;

	return $depth;
}

sub CountFunction($$$)
{
	my ($file, $vue, $compteurs) = @_ ;
    
	my $ret = 0;
    $nb_FunctionMethodImplementations = 0;
    $nb_BadArityIndentation = 0;
    $nb_BadMultiArityOrder = 0;
    $nb_MethodsLengthAverage = 0;
    $nb_LongArtifact = 0;
    $nb_WithTooMuchParametersMethods = 0;
    $nb_ParametersAverage = 0;
    $nb_GlobalDefInsideFunctions = 0;
    $nb_ParameterShadow = 0;
    $nb_BodyBeginOnSameLineThanParams = 0;

	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $FunctionMethodImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadArityIndentation__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MethodsLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ParametersAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ParameterShadow__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BodyBeginOnSameLineThanParams__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
			
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $nb_ArtifactDepthAverage = 0;
	
	# FUNCTION
	my $funcs = $KindsLists->{&FunctionKind};
	my $funcsArity = $KindsLists->{&FunctionArityKind};
	
	my @Functions = (@$funcs, @$funcsArity);
	
	my $nb_FunctionMethodImplementations = scalar @Functions;
	my $totalFunctionsLines = 0;
	my $totalParameters = 0;
	
	for my $func (@Functions) {
		# CHECK length
		my $lineBodyBegin = Clojure::ClojureNode::getClojureKindData($func, 'lineBodyBegin');
		my $lineBodyEnd = Clojure::ClojureNode::getClojureKindData($func, 'lineBodyEnd');
		
		my $agglo = \$vue->{'agglo'};
		my $aggloIndexes = $vue->{'agglo_LinesIndex'};
		
		my $beginIdx = $aggloIndexes->[$lineBodyBegin];
		my $endIdx = $aggloIndexes->[$lineBodyEnd];
		
		my $fctAgglo = substr($$agglo, $beginIdx, ($endIdx-$beginIdx+1));
		my $nbFctLines = () = $fctAgglo =~ /P/g;
		$totalFunctionsLines += $nbFctLines;
#print STDERR "BEGIN $lineBodyBegin, END $lineBodyEnd => LENGTH = $nbFctLines\n";
		
		if ($nbFctLines > Clojure::Config::LONG_METHOD_THRESHOLD) {
			$nb_LongArtifact++;
			Erreurs::VIOLATION($BadMultiArityOrder__mnemo, "Function with too many lines ($nbFctLines) ".GetName($func)." at line ".GetLine($func));
		}
		
		# CHECK PARAMETERS
		my $params = Clojure::ClojureNode::getClojureKindData($func, 'params');
		if (defined $params) {
			my $nb = scalar @$params;
			$totalParameters += $nb;
			if ($nb > Clojure::Config::TOO_MANY_PARAMETERS_THRESHOLD) {
				$nb_WithTooMuchParametersMethods++;
				Erreurs::VIOLATION($WithTooMuchParametersMethods__mnemo, "Function ".GetName($func)." has too many parameters ($nb) at line ".GetLine($func));
			}
			
			checkParameterShadow($func, $params);
		}
		
		# CHECK INNER GLOBAL DEFINITION
		checkInnerDef($func);
		
		# CHECK PARAMS vs BODY line position 
		checkBodyLineBeginning($func);
		
		# COMPUTE Depth
		my $funcDepth = getDepthDepth($func);
#print STDERR "Function ".GetName($func).": depth = $funcDepth at line ".GetLine($func)."\n";
		$nb_ArtifactDepthAverage += $funcDepth;
		
		if ($funcDepth > Clojure::Config::DEEP_ARTIFACT_THRESHOLD) {
			$nb_TooDepthArtifact++;
			Erreurs::VIOLATION($TooDepthArtifact__mnemo, "Too deep polymorph function ".GetName($func)." at line ".GetLine($func));
		}
	}
	
	if ($nb_FunctionMethodImplementations) {
		$nb_MethodsLengthAverage = int($totalFunctionsLines / $nb_FunctionMethodImplementations);
		$nb_ParametersAverage = int($totalParameters / $nb_FunctionMethodImplementations);
	}
	
	Erreurs::VIOLATION($MethodsLengthAverage__mnemo, "METRIC : function length average = $nb_MethodsLengthAverage");
	Erreurs::VIOLATION($ParametersAverage__mnemo, "METRIC : parameters average = $nb_ParametersAverage");
	
	# FUNCTION POLYMORPHIC ONLY
	my $funcPolym = $KindsLists->{&FunctionPolymorphicKind};
	my $nb_polymorfunc = 0;
	for my $poly (@$funcPolym) {
		my $childrens = GetChildren($poly);

		my $expectedIndentation;
		
		$nb_polymorfunc++;
		
		# for each arity
		my $nb_maxParameter = 0;
		for my $child (@$childrens) {
			
			if (IsKind($child, FunctionArityKind)) {
				
				# CHECK order by number of parameters
				my $params = Clojure::ClojureNode::getClojureKindData($child, 'params');
				if (defined $params) {
					my $nb = scalar @$params;
					if ($nb >= $nb_maxParameter) {
						$nb_maxParameter = $nb;
					}
					else {
						$nb_BadMultiArityOrder++;
						Erreurs::VIOLATION($BadMultiArityOrder__mnemo, "bad arity order by params for function ".GetName($poly)." at line ".GetLine($child));
					}
				}
				
				
				# CHECK arity indentation
				
	# VERSION CHECKING ALIGNMENT OF ARITIES each against others
				#if (! defined $expectedIndentation) {
				#	$expectedIndentation = Clojure::ClojureNode::getClojureKindData($child, 'indentation');
				#	next;
				#}
				
				#my $indentation = Clojure::ClojureNode::getClojureKindData($child, 'indentation');
				
	# VERSION CHECKING ALIGNMENT OF BODIES against parameters list
				$expectedIndentation = Clojure::ClojureNode::getClojureKindData($child, 'params_indentation');
				my $indentation = Clojure::ClojureNode::getClojureKindData($child, 'body_indentation');
				if ($indentation ne $expectedIndentation) {
					$nb_BadArityIndentation++;
					Erreurs::VIOLATION($BadArityIndentation__mnemo, "bad arity indentation for function ".GetName($poly)." at line ".GetLine($child));
				}
			}
		}
		
		# COMPUTE depth
		my $funcDepth = getDepthDepth($poly);
#print STDERR "Function polymorphic".GetName($poly).": depth = $funcDepth at line ".GetLine($poly)."\n";
		$nb_ArtifactDepthAverage += $funcDepth;
		
		if ($funcDepth > Clojure::Config::DEEP_ARTIFACT_THRESHOLD) {
			$nb_TooDepthArtifact++;
			Erreurs::VIOLATION($TooDepthArtifact__mnemo, "Too deep polymorph function ".GetName($poly)." at line ".GetLine($poly));
		}
	}
	
	# FUNCTION ANONYMOUS
	my $funcAno = $KindsLists->{&AnonymousKind};
	for my $ano (@$funcAno) {
		
	}
	
	if ($nb_FunctionMethodImplementations + $nb_polymorfunc) {
		$nb_ArtifactDepthAverage = int ($nb_ArtifactDepthAverage / ($nb_FunctionMethodImplementations + $nb_polymorfunc));
	}

	Erreurs::VIOLATION($ArtifactDepthAverage__mnemo, "[METRIC] : artifacts depth average = $nb_ArtifactDepthAverage");
	
	$ret |= Couples::counter_update($compteurs, $FunctionMethodImplementations__mnemo, $nb_FunctionMethodImplementations );
	$ret |= Couples::counter_update($compteurs, $BadArityIndentation__mnemo, $nb_BadArityIndentation );
	$ret |= Couples::counter_update($compteurs, $BadMultiArityOrder__mnemo, $nb_BadMultiArityOrder );
	$ret |= Couples::counter_update($compteurs, $MethodsLengthAverage__mnemo, $nb_MethodsLengthAverage );
	$ret |= Couples::counter_update($compteurs, $LongArtifact__mnemo, $nb_LongArtifact );
	$ret |= Couples::counter_update($compteurs, $WithTooMuchParametersMethods__mnemo, $nb_WithTooMuchParametersMethods );
	$ret |= Couples::counter_update($compteurs, $ParametersAverage__mnemo, $nb_ParametersAverage );
	$ret |= Couples::counter_update($compteurs, $GlobalDefInsideFunctions__mnemo, $nb_GlobalDefInsideFunctions );
	$ret |= Couples::counter_update($compteurs, $ParameterShadow__mnemo, $nb_ParameterShadow );
	$ret |= Couples::counter_update($compteurs, $BodyBeginOnSameLineThanParams__mnemo, $nb_BodyBeginOnSameLineThanParams );
	$ret |= Couples::counter_update($compteurs, $ArtifactDepthAverage__mnemo, $nb_ArtifactDepthAverage );
	$ret |= Couples::counter_update($compteurs, $TooDepthArtifact__mnemo, $nb_TooDepthArtifact );
	
    return $ret;
}

# SPEC LongFunctionLiteral
# in #(...), the first element should be a command and other are parameters of these command.
# to have a literal function with several instructions, we must use 'do'
#       ==> #( do (command 1) (command 2))
#
# Count one VIOLATION each time the first paramter of a #(...) is 'do' and the #(...) contains more than two elements

sub CountFunctionLiteral($$$) {
	my ($file, $vue, $compteurs) = @_ ;
    
	my $ret = 0;
    $nb_LongFunctionLiteral = 0;

	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $LongFunctionLiteral__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $funcs = $KindsLists->{&FunctionLiteralKind};
	
	for my $func (@$funcs) {
		my $children = GetChildren($func);
		if ((scalar @$children > 2) && (${GetStatement($children->[0])} eq 'do')) {
			$nb_LongFunctionLiteral++;
			Erreurs::VIOLATION($LongFunctionLiteral__mnemo, "Function literal with several forms at line ".GetLine($func));
		}
	}
	
	$ret |= Couples::counter_update($compteurs, $LongFunctionLiteral__mnemo, $nb_LongFunctionLiteral );
    return $ret;
}

1;


