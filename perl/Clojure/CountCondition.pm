package Clojure::CountCondition;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Clojure::ClojureNode;
use Clojure::Config;

my $IfShouldBeWhen__mnemo = Ident::Alias_IfShouldBeWhen();
my $MissingDefaults__mnemo = Ident::Alias_MissingDefaults();
my $BadSwitchForm__mnemo = Ident::Alias_BadSwitchForm();
my $If__mnemo = Ident::Alias_If();
my $Case__mnemo = Ident::Alias_Case();
my $Default__mnemo = Ident::Alias_Default();
my $ComplexConditions__mnemo = Ident::Alias_ComplexConditions();
my $InvertedLogic__mnemo = Ident::Alias_InvertedLogic();

my $nb_IfShouldBeWhen = 0;
my $nb_MissingDefaults = 0;
my $nb_BadSwitchForm = 0;
my $nb_If = 0;
my $nb_Case = 0;
my $nb_Default = 0;
my $nb_ComplexConditions = 0;
my $nb_InvertedLogic = 0;


my %DUAL_OPERATORS = (
	"not" => 1,
	"not=" => 1,
	"=" => 1,
	"<" => 1,
	">" => 1,
	"<=" => 1,
	">=" => 1,
	"or" => 1,
	"and" => 1,
);

sub countInvertableLogic($);
sub countInvertableLogic($) {
	my $cond = shift;
	
	my $gain = 0;
	
	my $name = GetName($cond);
	
	return 0 if (! defined $name);

	if (exists $DUAL_OPERATORS{$name} ) {
		$gain = 1;
	}
	else {
		$gain = -1;
	}
	
	my $children = GetChildren($cond);
	
	for my $child (@$children) {
		$gain += countInvertableLogic($child);
	}

	return $gain;
}

# Threshold : 1, 2, 3
# Presence of NOT operator ? another diag or make condition more complex ? 
sub checkComplexCondition($) {
	my $cond =shift;
	
	my @lists = GetNodesByKind($cond, ListKind);
	
	my $nb_and = 0;
	my $nb_or = 0;
	my $nb_not = 0;
	my $invertedLogic = 0;
	for my $list (@lists) {
		my $name = GetName($list);

		if (!defined $name) {
			#print STDERR "MISSING NAME for list at line ".GetLine($list)."\n";
			next;
		}
		
		if ($name eq "and") {
			$nb_and++;
		}
		elsif ($name eq "or") {
			$nb_or++;
		}
		elsif ($name eq "not") {
			if ((! $invertedLogic ) && (countInvertableLogic($list) > 0)) {
				$invertedLogic =1;
			}
		}
	}
	
	if ($invertedLogic) {
		$nb_InvertedLogic++;
		Erreurs::VIOLATION($InvertedLogic__mnemo, "Inverted logic at line ".GetLine($cond));
	}

#print STDERR "AND=$nb_and, OR=$nb_or, NOT=$nb_not at line ".GetLine($cond)."\n";
	
	if ($nb_and && $nb_or) {
		$nb_ComplexConditions++;
		Erreurs::VIOLATION($InvertedLogic__mnemo, "ComplexCondition at line ".GetLine($cond));
	}
}


sub CountIf($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_IfShouldBeWhen = 0;
    $nb_If = 0;
    $nb_ComplexConditions = 0;
    $nb_InvertedLogic = 0;

	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $IfShouldBeWhen__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $InvertedLogic__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $ifs = $KindsLists->{&IfKind};
	
	for my $if (@$ifs) {
		$nb_If++;
		my $children = GetChildren($if);
		# search only 'if' with two childs : cond + then !!!
		if (scalar @$children == 2) {
			$nb_IfShouldBeWhen++;
			Erreurs::VIOLATION($IfShouldBeWhen__mnemo, "'if' should be 'when' at line ".GetLine($if));
		}
		
		checkComplexCondition($children->[0]);
	}
	
	
	$ret |= Couples::counter_update($compteurs, $IfShouldBeWhen__mnemo, $nb_IfShouldBeWhen );
	$ret |= Couples::counter_update($compteurs, $If__mnemo, $nb_If );
	$ret |= Couples::counter_update($compteurs, $ComplexConditions__mnemo, $nb_ComplexConditions );
	$ret |= Couples::counter_update($compteurs, $InvertedLogic__mnemo, $nb_InvertedLogic );
	
    return $ret;
}


sub checkCondVSCondp($) {
			my $switch = shift;
	
		
#print STDERR "*** cond ***\n";
			my $children = GetChildren($switch);
#print STDERR (scalar @$children)." CHILDREN\n";
			my $nb_ref_elements;
			my @ref_elements = ();
			my $ref_command;
			my $idx_case_value;
			my $status = "FAIL";
			
			# check conditions
CONDITION:	for my $child (@$children) {
				# ignore default statement
				if ($child->[0] eq CaseKind) {
					my $cond = GetChildren($child)->[0];
					my $condExpr = GetChildren($cond)->[0];
					
					if (! defined $condExpr) {
						# ABORT because no node for the expression, and so element to compare are not visible.
#print STDERR "------> CONDITION = (".${GetStatement($cond)}.")\n";
						$status = "OK";
						last CONDITION;
					}
					elsif ($condExpr->[0] eq ListKind) {
						my $command = GetName($condExpr);
						my $elements = GetChildren($condExpr);
						
						# BUILD reference
						if (! defined $nb_ref_elements) {
							$nb_ref_elements = scalar @$elements;
							$ref_command = $command;
							for my $el (@$elements) {
								my $stmt = GetStatement($el);
								if ($$stmt ne "") {
									push @ref_elements, $stmt;
								}
								else {
									# ABORT, because cannot compare non scalar data.
									$status = "OK";
									last CONDITION;
								}
							}
						}
						# COMPARE wirh reference
						elsif ($nb_ref_elements == scalar @$elements) {
							if ($command ne $ref_command) {
								# ABORT, because not the same command
								$status = "OK";
								last CONDITION;
							}
							my $idx = 0;
							for my $el (@$elements) {
								my $stmt = GetStatement($el);

								if ($$stmt eq "") {
									# ABORT, because cannot compare non scalar data.
									$status = "OK";
									last CONDITION;
								}
								
								if ($$stmt ne ${$ref_elements[$idx]}) {
									if (! defined $idx_case_value) {
										$idx_case_value = $idx;
									}
									else {
										if ($idx != $idx_case_value) {
											# ABORT because only the data at index $idx_case_value can differ at each iteration.
											$status = "OK";
											last CONDITION;
										}
									}
								}
								$idx++;
							}
						}
						else {
							# ABORT, because not the same number of elements
							$status = "OK";
							last CONDITION;
						}
						
#my $p1 = ${GetStatement($elements->[0])} if defined $elements->[0];
#my $p2 = ${GetStatement($elements->[1])} if defined $elements->[1];
#$p2 = $p2||"";
#print STDERR "------> CONDITION = (".($command||"??")." $p1 $p2)\n";

					}
				}
			}
			
			if ($status eq "FAIL") {
				$nb_BadSwitchForm++;
				Erreurs::VIOLATION($BadSwitchForm__mnemo, "cond COULD BE condp at line ".GetLine($switch));
			}
}

sub checkCondpVSCase($) {
	my $condp = shift;
	
	my $parameters = Clojure::ClojureNode::getClojureKindData($condp, 'parameters');
	
	if ((defined ${$parameters->[0]}) && (${$parameters->[0]} eq "=")) {
		my $children = GetChildren($condp);
		return if (scalar @$children == 0);
		
		my $status = "FAIL";
		
		for my $child (@$children) {
			if (IsKind($child, CaseKind)) {
				my $cond = GetChildren($child)->[0];
				my $stmt = GetStatement($cond);
				if ($$stmt !~ /^(?:\d+|CHAINE_\d+)$/) {
					# Abort because test value is not a literal !!
					$status = "OK";
					last;
				}
			}
		}
		if ($status eq "FAIL") {
			$nb_BadSwitchForm++;
			Erreurs::VIOLATION($BadSwitchForm__mnemo, "condp COULD BE case at line ".GetLine($condp));
		}
	}
	
}

sub CountSwitch($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_MissingDefaults = 0;
    $nb_BadSwitchForm = 0;
    $nb_Case = 0;
    $nb_Default = 0;

	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $MissingDefaults__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadSwitchForm__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $Case__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $Default__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $switchs = $KindsLists->{&SwitchKind};
	my $switchps = $KindsLists->{&SwitchpKind};
	my $switchCases = $KindsLists->{&SwitchCaseKind};
	my @AllSwitchs = (@$switchs, @$switchps, @$switchCases);
	
	for my $switch (@AllSwitchs) {
		my $children = GetChildren($switch);
		
		my $defaultIsPresent = 0;
		for my $case (@$children) {
			
			if (IsKind($case, DefaultKind)) {
				# total of default statement in the file
				$nb_Default++;
				# default statement present (or not) in current switch
				$defaultIsPresent = 1;
			}
			else {
				# total of case statement in the file
				$nb_Case++;
			}
			
		}
		if (! $defaultIsPresent) {
			$nb_MissingDefaults++;
			Erreurs::VIOLATION($MissingDefaults__mnemo, "Missing default for 'switch' at line ".GetLine($switch));
		}
		
		# CHECK cond vs condp
		if (IsKind($switch, SwitchKind)) {
			checkCondVSCondp($switch);
		}
		
		# CHECK condp vs case
		if (IsKind($switch, SwitchpKind)) {
			checkCondpVSCase($switch);
		}
	}
	
	Erreurs::VIOLATION($Case__mnemo, "[METRIC] number of 'case' = $nb_Case");
	
	$ret |= Couples::counter_update($compteurs, $MissingDefaults__mnemo, $nb_MissingDefaults );
	$ret |= Couples::counter_update($compteurs, $BadSwitchForm__mnemo, $nb_BadSwitchForm );
	$ret |= Couples::counter_update($compteurs, $Case__mnemo, $nb_Case );
	$ret |= Couples::counter_update($compteurs, $Default__mnemo, $nb_Default );
	
    return $ret;
}

1;
