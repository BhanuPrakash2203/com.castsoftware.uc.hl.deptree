package Groovy::CountCondition;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Groovy::GroovyNode;
use Groovy::Config;

my $UnconditionalCondition__mnemo = Ident::Alias_UnconditionalCondition();
my $ComplexConditions__mnemo = Ident::Alias_ComplexConditions();
my $ConditionComplexityAverage__mnemo = Ident::Alias_ConditionComplexityAverage(); 
my $AssignmentsInConditionalExpr__mnemo = Ident::Alias_AssignmentsInConditionalExpr(); 
my $MissingBreakInCasePath__mnemo = Ident::Alias_MissingBreakInCasePath(); 
my $LongElsif__mnemo = Ident::Alias_LongElsif(); 
my $CollapsibleIf__mnemo = Ident::Alias_CollapsibleIf(); 
my $CouldBeElvis__mnemo = Ident::Alias_CouldBeElvis(); 

my $nb_UnconditionalCondition = 0;
my $nb_ComplexConditions = 0;
my $nb_ConditionComplexityAverage = 0;
my $nb_AssignmentsInConditionalExpr = 0;
my $nb_MissingBreakInCasePath = 0;
my $nb_LongElsif = 0;
my $nb_CollapsibleIf = 0;
my $nb_CouldBeElvis = 0;


sub CountUnconditionalCondition($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_UnconditionalCondition = 0;

  my $code = \$vue->{'code'};
  
  if ( ! defined $$code )
  {
    $ret |= Couples::counter_add($compteurs, $UnconditionalCondition__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  $nb_UnconditionalCondition += () = $$code =~ /\bif\s*\(\s*(?:true|false)\s*\)/g;

# ------------ VERSION WITH PARSER VIEW --------------------  
# my $root =  $vue->{'structured_code'} ;
  
#  if ( ! defined $root ) )
#  {
#    $ret |= Couples::counter_add($compteurs, $UnconditionalCondition__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
#    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
#  }
  
#  my @Ifs = GetNodesByKindList( $root, [IfKind] );

#  for my $if (@Ifs) {
#    my $children = GetSubBloc($if);
 
#    if (${GetStatement($children->[0])} =~ /\(\s*\b(?:false|true)\b\s*\)/si) {
#print "UNCONDITIONAL CONDITION\n";
#      $nb_UnconditionalCondition++;
#    }
#  }

  $ret |= Couples::counter_add($compteurs, $UnconditionalCondition__mnemo, $nb_UnconditionalCondition );

  return $ret;
}

sub CountCondition($$$) {
	my ($file, $vue, $compteurs) = @_ ;

	$nb_ComplexConditions = 0;
	$nb_ConditionComplexityAverage = 0;
	$nb_AssignmentsInConditionalExpr = 0;
	$nb_CollapsibleIf = 0;
	$nb_CouldBeElvis = 0;

	my $ret = 0;

	my $KindsLists = $vue->{'KindsLists'};
	
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ConditionComplexityAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $AssignmentsInConditionalExpr__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $CollapsibleIf__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $CouldBeElvis__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $Conditions = $KindsLists->{&ConditionKind};
	my $ifs = $KindsLists->{&IfKind};

	# 26/11/2020 HL-1564 Avoid collapsible if
	for my $if (@{$ifs}) {
		
		my $childrenIfOrigin = GetChildren($if);
		
		# not collapsible if has an associated "else"
		next if (defined $childrenIfOrigin->[2]);
		
		my $parent = GetParent($if);

		if ( IsKind($parent, ThenKind)) {
			
			my $grandParent = GetParent($parent);
			
			if ( IsKind($grandParent, IfKind)) {
				# not collapsible if encompassing "if" has an associated "else"
				next if (defined GetChildren($grandParent)->[2]);
				
				# not collapsible if not the only instruction of the encompassing "if"
				next if (scalar @{GetChildren($parent)} > 1);
				
				$nb_CollapsibleIf++;
				Erreurs::VIOLATION($CollapsibleIf__mnemo, "Collapsible if at line " . GetLine($if));
			}
		}
		
		
		
		if (0) {
		
		my $ifParent = GetParent($if);

		# select only encompassing if, named here if
		if (! IsKind($ifParent, ThenKind)) {

			my $childrenIfOrigin = GetChildren($if);
			my $countElse = 0;
			if (scalar @{$childrenIfOrigin} > 0) {
				for my $child (@$childrenIfOrigin) {
					$countElse++ if (IsKind($child, ElseKind));
				}
			}
			# if instruction without else
			if ($countElse == 0) {
				my $thenNodeOrigin = GetChildren($if)->[1];
				my $childrenThenOrigin = GetChildren($thenNodeOrigin);
				my $countIf = 0;
				if (scalar @{$childrenThenOrigin} > 0) {
					for my $child (@$childrenThenOrigin) {
						$countIf++ if (IsKind($child, IfKind));
					}
				}
				# if then origin owns only if instructions
				if (scalar @{$childrenThenOrigin} == $countIf && $countIf > 0) {
					my @ifNodes = GetChildrenByKind($thenNodeOrigin, IfKind);
					for my $ifNode (@ifNodes) {
						my $childrenIf = GetChildren($ifNode);
						$countElse = 0;
						if (scalar @{$childrenIf} > 0) {
							for my $child (@$childrenIf) {
								$countElse++ if (IsKind($child, ElseKind));
							}
						}
						# if instruction without else
						if ($countElse == 0) {
							# print "Collapsible if at line " . GetLine($ifNode) . "\n";
							$nb_CollapsibleIf++;
							Erreurs::VIOLATION($CollapsibleIf__mnemo, "Collapsible if at line " . GetLine($ifNode));
						}
					}
				}
			}
		}
		}
		
		# check if that could be elvis notation
		my $children = GetChildren($if);
		my $cond = $children->[0];
		if (${GetStatement($cond)} =~ /\(\s*!\s*(.*)\)\s*$/m) {
			
			# if the "if" has no else ...
			if (! defined $children->[2]) {
				my $then = $children->[1];
				my $thenInstr = GetChildren($then);
				
				# if the "if" has only one instruction
				if (scalar @$thenInstr == 1) {
					if (${GetStatement($thenInstr->[0])} =~ /^\s*$1\s*=[^=]/m) {
						$nb_CouldBeElvis++;
						Erreurs::VIOLATION($CouldBeElvis__mnemo, "If statement could be Elvis notation at line ".GetLine($if));
					}
				}
			}
		}
		
	}

	my $nb_compoundConditions = 0;
	my $totalComplexity = 0;
	
	for my $cond (@$Conditions) {
		my $stmt = GetStatement($cond);
		my $line = GetLine($cond);
		
		my $nb_AND = () = $$stmt =~ /\&\&/g;
		my $nb_OR = () = $$stmt =~ /\|\|/g;
		
		if ($nb_AND > 0 && $nb_OR > 0) {
			$nb_compoundConditions++;
			$totalComplexity += $nb_AND + $nb_OR;
			
			if ($nb_AND + $nb_OR > Groovy::Config::MAX_CONDITION_COMPLEXITY) {
				$nb_ComplexConditions++;
				Erreurs::VIOLATION($ComplexConditions__mnemo, "Complex condition above theshold ".Groovy::Config::MAX_CONDITION_COMPLEXITY." at line $line");
			}
		}
		
		if ($$stmt =~ /[^=!<>]=[^=]/) {
			$nb_AssignmentsInConditionalExpr++;
			Erreurs::VIOLATION($AssignmentsInConditionalExpr__mnemo, "Assignment in conditional expression at line $line");
		}
	}

	if ($nb_compoundConditions) {
		$nb_ConditionComplexityAverage  = int($totalComplexity / $nb_compoundConditions);
	}
	
	Erreurs::VIOLATION($ComplexConditions__mnemo, "METRIC : Condition complexity average = $nb_ConditionComplexityAverage");
	
	$ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, $nb_ComplexConditions );
	$ret |= Couples::counter_add($compteurs, $ConditionComplexityAverage__mnemo, $nb_ConditionComplexityAverage );
	$ret |= Couples::counter_add($compteurs, $AssignmentsInConditionalExpr__mnemo, $nb_AssignmentsInConditionalExpr );
	$ret |= Couples::counter_add($compteurs, $CollapsibleIf__mnemo, $nb_CollapsibleIf );
	$ret |= Couples::counter_update($compteurs, $CouldBeElvis__mnemo, $nb_CouldBeElvis );

  return $ret;
}

sub CountSwitch($$$) {
	my ($file, $vue, $compteurs) = @_ ;

	$nb_MissingBreakInCasePath = 0;
	
	my $ret = 0;

	my $KindsLists = $vue->{'KindsLists'};
	
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $MissingBreakInCasePath__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );	
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $Switches = $KindsLists->{&SwitchKind};
	
	for my $switch (@$Switches) {
		my $then = GetChildren($switch)->[1];
		
		# process cases/default
		my $cases = GetChildren($then);
		my $nb_cases = scalar @$cases;
		my $case_id = 1;
		for my $case (@$cases) {
			
			# process case instructions
			my $caseInstrs = GetChildren($case);
			if (scalar @$caseInstrs > 0) {
				my $last = $caseInstrs->[-1];
				
				if (! IsKind($last, BreakKind)) {
					# last instruction is not a break ...
					if ((! IsKind($case, DefaultKind)) || ($case_id != $nb_cases)) {
						# the case is not default, or is not in last position ...
						$nb_MissingBreakInCasePath++;
						Erreurs::VIOLATION($MissingBreakInCasePath__mnemo, "Missing break at end of case statement at line ". GetLine($case));
					}
				}
			}
			$case_id++;
		}
	}

	$ret |= Couples::counter_add($compteurs, $MissingBreakInCasePath__mnemo, $nb_MissingBreakInCasePath );
}

# 20/11/2020 HL-1552 Avoid long elsif chain
sub CountElsif($$$) {
	my ($file, $vue, $compteurs) = @_ ;

	$nb_LongElsif = 0;
	
	my $ret = 0;

	my $KindsLists = $vue->{'KindsLists'};
	
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $LongElsif__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );	
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $ifInstr = $KindsLists->{&IfKind};
	
	for my $if (@$ifInstr) {

		# ifInstr also contains if of elsif statements which should not be counted
		if (! IsKind(GetParent($if), ElseKind)) {
			
			my $else = GetChildren($if)->[2];
			my $nbElsif = 0;
			while (defined $else) {
				my $child = GetChildren($else)->[0];
				if (IsKind($child, IfKind)) {
					$nbElsif++;
					$else = GetChildren($child)->[2];
				}
				else {
					$else = undef;
				}
			}
			
			if ($nbElsif >= 2) {
				$nb_LongElsif++;
				Erreurs::VIOLATION($LongElsif__mnemo, "Long elsif chain ($nbElsif elsif) at line " . GetLine($if));
			}
		}
	}

	$ret |= Couples::counter_add($compteurs, $LongElsif__mnemo, $nb_LongElsif );
}

1;
