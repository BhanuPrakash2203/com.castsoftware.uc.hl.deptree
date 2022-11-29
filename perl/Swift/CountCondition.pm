package Swift::CountCondition;
# les modules importes
use strict;
use warnings;

use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use Swift::SwiftNode;
use Swift::Identifiers;
use Swift::SwiftConfig;

my $DEBUG = 0;

my $MissingFinalElses__mnemo = Ident::Alias_MissingFinalElses();
my $UnexpectedBreakStatement__mnemo = Ident::Alias_UnexpectedBreakStatement();
my $NestedTernary__mnemo = Ident::Alias_NestedTernary();
my $SmallSwitchCase__mnemo = Ident::Alias_SmallSwitchCase();
my $SwitchLengthAverage__mnemo = Ident::Alias_SwitchLengthAverage();
my $CaseLengthAverage__mnemo = Ident::Alias_CaseLengthAverage();
my $TernaryOperators__mnemo = Ident::Alias_TernaryOperators();
my $ComplexConditions__mnemo = Ident::Alias_ComplexConditions();

my $nb_MissingFinalElses= 0;
my $nb_UnexpectedBreakStatement= 0;
my $nb_NestedTernary= 0;
my $nb_SmallSwitchCase= 0;
my $nb_SwitchLengthAverage= 0;
my $nb_CaseLengthAverage= 0;
my $nb_TernaryOperators= 0;
my $nb_ComplexConditions= 0;

my $THRESHOLD_COMPLEX = 2;

sub CountCondition($$$) 
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_MissingFinalElses = 0;
    $nb_UnexpectedBreakStatement = 0;
    $nb_NestedTernary = 0;
    $nb_SmallSwitchCase = 0;
    $nb_SwitchLengthAverage = 0;
    $nb_CaseLengthAverage = 0;
    $nb_TernaryOperators = 0;
    $nb_ComplexConditions = 0;

    my $root =  \$vue->{'code'} ;
    my $root_structured =  $vue->{'structured_code'} ;

    if ( ( ! defined $root ) )
    {
        $ret |= Couples::counter_add($compteurs, $MissingFinalElses__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $UnexpectedBreakStatement__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $NestedTernary__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $SmallSwitchCase__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $SwitchLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $CaseLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $TernaryOperators__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
    if ( ( ! defined $root_structured ) )
    {	
        $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	my @IfConditions = @{$vue->{'KindsLists'}->{'If'}};
	my @BreakStatements = @{$vue->{'KindsLists'}->{'Break'}};
	my @TernaryOperators = @{$vue->{'KindsLists'}->{'Ternary'}};
	my @SwitchConditions = @{$vue->{'KindsLists'}->{'Switch'}};

    my @conds = GetNodesByKind($root_structured, CondKind);

    for my $cond (@conds) {
        my $flatCond = Lib::NodeUtil::GetXKindData($cond, 'flatexpr');

		if (defined $flatCond && isComplex($flatCond)) {
          $nb_ComplexConditions++;
        }
	}

    for my $ifCondition (@IfConditions) {

        my @elseStatements = GetChildrenByKind($ifCondition, ElseKind);
        if (scalar @elseStatements > 0) {
            my $fistChild = GetChildren ($elseStatements[0]);
            if (IsKind ($fistChild->[0], IfKind)) {
                # print "else if at line ".GetLine($fistChild->[0])."\n";

                my $children = GetChildren($fistChild->[0]);
                my $lastChild = $children->[-1];

                # HL-1091 : "if ... else if" constructs should end with "else" clauses
                if (!IsKind($lastChild, ElseKind)) {
                    # print "\"if ... else if\" constructs should end with \"else\" clauses at line " . GetLine($ifCondition) . "\n";
                    $nb_MissingFinalElses++;
                    Erreurs::VIOLATION($MissingFinalElses__mnemo, "\"if ... else if\" constructs should end with \"else\" clauses at line " . GetLine($ifCondition) . ".");
                }
            }
        }
    }

    # HL-1104 : "break" should be the only statement in a "case"
    for my $breakStatement (@BreakStatements) {
        my $parent = GetParent ($breakStatement);
        if (IsKind ($parent, CaseKind)) {
            my $children = GetChildren ($parent);
            # case node has always a child node as a case_expr
            # so the size limit of a case is : 1 case_expr + 1 break node + 1 other node = 3 => ALERT
            # and sometimes a cond node (a where condition)
            my $sizeLimit = 2;
            $sizeLimit++ if (IsKind ($children->[1], CondKind));

            if (scalar @{$children} > $sizeLimit) {
                # print "\"break\" should be the only statement in a \"case\" at line " . GetLine($parent) . "\n";
                $nb_UnexpectedBreakStatement++;
                Erreurs::VIOLATION($UnexpectedBreakStatement__mnemo, "\"break\" should be the only statement in a \"case\" at line " . GetLine($parent) . ".");
            }
        }
    }

    # HL-1103 Ternary operators should not be nested
    for my $ternaryOperator (@TernaryOperators) {
		$nb_TernaryOperators++;
        my @elseStatements = GetChildrenByKind ($ternaryOperator, ElseKind);
        my $nestedTernary = GetChildren ($elseStatements[0]);
        if (scalar @{$nestedTernary} > 0 && IsKind($nestedTernary->[0], TernaryKind)) {
            # print "Ternary operators should not be nested at line " . GetLine ($ternaryOperator) ."\n";
            $nb_NestedTernary++;
            Erreurs::VIOLATION($NestedTernary__mnemo, "Ternary operators should not be nested at line " . GetLine($ternaryOperator) . ".");
        }
    }

    my $bonusCases;
    my $bonusLineCases;
    my $totalSwitches;
    my $totalCases;
    for my $switchCondition (@SwitchConditions) {
        my @caseStatements = GetChildrenByKind ($switchCondition, CaseKind);

        # HL-1096 "switch case" clauses should not have too many lines of code
        for my $caseStatement (@caseStatements) {
            my $sizeBlocCase = GetEndline($caseStatement) - GetLine($caseStatement) + 1;
            if ($sizeBlocCase >= 5) {
                $bonusLineCases += $sizeBlocCase - 5;
            }
            $totalCases++;
        }

        # HL-1107 "switch" statements should have at least 3 "case" clauses
        if (scalar @caseStatements == 1 || scalar @caseStatements == 2) {
            # print "\"switch\" statements should have at least 3 \"case\" clauses at line " . GetLine($switchCondition) ."\n";
            $nb_SmallSwitchCase++;
            Erreurs::VIOLATION($SmallSwitchCase__mnemo, "\"switch\" statements should have at least 3 \"case\" clauses at line " . GetLine($switchCondition) . ".");
        }
        # HL-1095 "switch" statements should not have too many "case" clauses
        elsif (scalar @caseStatements > 3) {
            $bonusCases += scalar @caseStatements - 3;
        }
        $totalSwitches++;
    }

    # HL-1095 "switch" statements should not have too many "case" clauses
    if (defined $bonusCases && defined $totalSwitches && $totalSwitches > 0) {
        $nb_SwitchLengthAverage = $bonusCases / $totalSwitches;
        # rounding to nearest integer
        $nb_SwitchLengthAverage = int($nb_SwitchLengthAverage + $nb_SwitchLengthAverage/abs($nb_SwitchLengthAverage*2));
        # print "\"switch\" statements should not have too many \"case\" clauses (average = $nb_SwitchLengthAverage)\n";
        Erreurs::VIOLATION($SwitchLengthAverage__mnemo, "\"switch\" statements should not have too many \"case\" clauses (average = $nb_SwitchLengthAverage).");
    }

    # HL-1096 "switch case" clauses should not have too many lines of code
    if (defined $bonusLineCases && defined $totalCases && $totalCases > 0) {
        $nb_CaseLengthAverage = $bonusLineCases / $totalCases;
		if ($nb_CaseLengthAverage  != 0) {
			# rounding to nearest integer
			$nb_CaseLengthAverage = int($nb_CaseLengthAverage + $nb_CaseLengthAverage/abs($nb_CaseLengthAverage*2));
		}
        # print "\"switch case\" clauses should not have too many lines of code (average = $nb_CaseLengthAverage)\n";
        Erreurs::VIOLATION($CaseLengthAverage__mnemo, "\"switch case\" clauses should not have too many lines of code (average = $nb_CaseLengthAverage).");
    }

    $ret |= Couples::counter_add($compteurs, $MissingFinalElses__mnemo, $nb_MissingFinalElses );
    $ret |= Couples::counter_add($compteurs, $UnexpectedBreakStatement__mnemo, $nb_UnexpectedBreakStatement );
    $ret |= Couples::counter_add($compteurs, $NestedTernary__mnemo, $nb_NestedTernary );
    $ret |= Couples::counter_add($compteurs, $SmallSwitchCase__mnemo, $nb_SmallSwitchCase );
    $ret |= Couples::counter_add($compteurs, $SwitchLengthAverage__mnemo, $nb_SwitchLengthAverage );
    $ret |= Couples::counter_add($compteurs, $CaseLengthAverage__mnemo, $nb_CaseLengthAverage );
    $ret |= Couples::counter_add($compteurs, $TernaryOperators__mnemo, $nb_TernaryOperators );
    $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, $nb_ComplexConditions );

    return $ret;
}

sub isComplex($) {
  my $stmt = shift;
  # Calcul du nombre de && et de ||
  my $nb_ET = () = $$stmt =~ /\&\&/sg ;
  my $nb_OU = () = $$stmt =~ /\|\|/sg ;

  if ( ($nb_ET > 0) && ($nb_OU > 0) ) {
    if ( $nb_ET + $nb_OU >= $THRESHOLD_COMPLEX) {
      return 1;;
    }
  }
  return 0;
}


1;
