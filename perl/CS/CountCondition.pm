package CS::CountCondition;

use strict;
use warnings;

use Erreurs;
use Lib::NodeUtil;
use CS::CSNode;
use CS::CSConfig;

my $ConditionComplexityAverage_mnemo = Ident::Alias_ConditionComplexityAverage();
my $ComplexConditions_mnemo = Ident::Alias_ComplexConditions();
my $AssignmentsInConditionalExpr_mnemo = Ident::Alias_AssignmentsInConditionalExpr();
my $MissingFinalElses_mnemo = Ident::Alias_MissingFinalElses();
my $CollapsibleIf_mnemo = Ident::Alias_CollapsibleIf();
my $NestedTernary_mnemo = Ident::Alias_NestedTernary();

my $nb_ConditionComplexityAverage = 0;
my $nb_ComplexConditions = 0;
my $nb_AssignmentsInConditionalExpr = 0;
my $nb_MissingFinalElses = 0;
my $nb_CollapsibleIf = 0;
my $nb_NestedTernary = 0;

sub CountConditions($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
	my $status = 0;
	
	$nb_ConditionComplexityAverage = 0;
	$nb_ComplexConditions = 0;
	$nb_AssignmentsInConditionalExpr = 0;
	
	my $nb_MixedConditions = 0;
	
	my $KindsLists = $views->{'KindsLists'};

	if ( ! defined $KindsLists ) {
		$status |= Couples::counter_add($compteurs, $ConditionComplexityAverage_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $ComplexConditions_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $AssignmentsInConditionalExpr_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
	
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $conditions = $KindsLists->{&ConditionKind};
	
	for my $cond (@$conditions) {
		
		my $line = GetLine($cond);
		
		my $statement = GetStatement($cond);
		my ($init, $condexpr, $incr) = $$statement =~ /([^;]*);([^;]*);([^;]*)/;
		if (! defined $condexpr) {
			$condexpr = $$statement;
		}

		my $nb_AND = () = $condexpr =~ /\&\&/g;
		my $nb_OR = () = $condexpr =~ /\|\|/g;

		if (($nb_AND > 0) && ($nb_OR > 0)) {
			if (($nb_AND + $nb_OR) > CS::CSConfig::MAX_CONDITION_COMPLEXITY) {
				$nb_ComplexConditions++;
				Erreurs::VIOLATION($ComplexConditions_mnemo, "Complex condition : $condexpr at line $line");
			}
			
			$nb_MixedConditions++;
			$nb_ConditionComplexityAverage += ($nb_AND + $nb_OR);
		}

		if ($condexpr =~ /[^=!<>]=[^=]/) {
			$nb_AssignmentsInConditionalExpr++;
			Erreurs::VIOLATION($AssignmentsInConditionalExpr_mnemo, "Assignment in consitional expression at line $line");
		}
		
	}
	
	if ($nb_MixedConditions) {
		$nb_ConditionComplexityAverage = int($nb_ConditionComplexityAverage / $nb_MixedConditions);
	}

	Erreurs::VIOLATION($ConditionComplexityAverage_mnemo, "METRIC : Condition complexity average : $nb_ConditionComplexityAverage");

	$status |= Couples::counter_add($compteurs, $ConditionComplexityAverage_mnemo, $nb_ConditionComplexityAverage);
	$status |= Couples::counter_add($compteurs, $ComplexConditions_mnemo, $nb_ComplexConditions);
	$status |= Couples::counter_add($compteurs, $AssignmentsInConditionalExpr_mnemo, $nb_AssignmentsInConditionalExpr);
	
	return $status;
} 


sub CountIfs($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
	my $status = 0;
	
	$nb_MissingFinalElses = 0;
	$nb_CollapsibleIf = 0;
	
	my $nb_MixedConditions = 0;
	
	my $KindsLists = $views->{'KindsLists'};

	if ( ! defined $KindsLists ) {
		$status |= Couples::counter_add($compteurs, $MissingFinalElses_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $CollapsibleIf_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
	
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $ifs = $KindsLists->{&IfKind};
	
	for my $if (@$ifs) {
		my $line = GetLine($if);
		my $children = GetChildren($if);
		
		# CHECK "else if" chain
		# Consider only "if" that are the beginning of a "else if" chain, that is:
		# - the parent of the if is NOT a "else"
		# - or the parent has more than one child.
		my $parent = GetParent($if);
		if ( (! IsKind($parent, ElseKind)) || (scalar @{GetChildren($parent)} != 1) ) {
			my $if2check = $if;
			my $finalElse = 0;
			my $nb_Elsif = 0;
			while ($if2check) {
				$finalElse = 0;
				my $else = GetChildren($if2check)->[2];
				if (defined $else) {
					$finalElse = 1;
					my $elseChildren = GetChildren($else);
					if ((scalar @$elseChildren == 1) && (IsKind($elseChildren->[0], IfKind))) {
						$if2check = $elseChildren->[0];
						$nb_Elsif++;
					}
					else {
						# no elsif
						last;
					}
				}
				else {
					# no else
					last;
				}
			}

			if (($nb_Elsif > 0) && (! $finalElse)) {
				$nb_MissingFinalElses++;
				Erreurs::VIOLATION($MissingFinalElses_mnemo, "Missing final else for 'else if' chain at line $line");
			}
		}
		
		# CHECK COLLAPSIBLE
		if (! defined $children->[2] ) {
			# main "if" has no "else"
			my $thenChildren = GetChildren($children->[1]);
			if ((scalar @$thenChildren == 1) && IsKind($thenChildren->[0], IfKind)) {
				# "then" has only one statement that is a nested "if"
				my $nestedIf = $thenChildren->[0];
				
				if (! defined GetChildren($nestedIf)->[2]) {
					# nested "if" has no "else"
						$nb_CollapsibleIf++;
						Erreurs::VIOLATION($CollapsibleIf_mnemo, "Collapsible 'if' at line $line\n");
				}
			}
		}
		
	}
	
	$status |= Couples::counter_add($compteurs, $MissingFinalElses_mnemo, $nb_MissingFinalElses);
	$status |= Couples::counter_add($compteurs, $CollapsibleIf_mnemo, $nb_CollapsibleIf);
	
	return $status;
}

sub CountTernary($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
	my $status = 0;
	
	$nb_NestedTernary = 0;
	
	my $KindsLists = $views->{'KindsLists'};

	if ( ! defined $KindsLists ) {
		$status |= Couples::counter_add($compteurs, $NestedTernary_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
	
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $Ternaries = $KindsLists->{&TernaryKind};

	for my $ternary (@$Ternaries) {
		my @subTernaries = GetNodesByKind($ternary, TernaryKind);
		if (scalar @subTernaries > 0) {
			$nb_NestedTernary++;
			Erreurs::VIOLATION($NestedTernary_mnemo, "Nested ternary operator at line ".GetLine($ternary));
		}
	}

	$status |= Couples::counter_add($compteurs, $NestedTernary_mnemo, $nb_NestedTernary);
	
	return $status;
} 

1;
