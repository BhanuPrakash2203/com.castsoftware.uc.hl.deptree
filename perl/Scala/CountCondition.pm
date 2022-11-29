package Scala::CountCondition;
# les modules importes
use strict;
use warnings;

use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use Scala::ScalaNode;
use Scala::ScalaConfig;

my $DEBUG = 0;

my $LARGE_MATCH_LENGTH_THRESHOLD = 3;
my $THRESHOLD_LONG_ELSIF = 2;

my $DuplicatedCondition__mnemo = Ident::Alias_DuplicatedCondition();
my $MissingFinalElses__mnemo = Ident::Alias_MissingFinalElses();
my $SwitchNested__mnemo = Ident::Alias_SwitchNested();
my $LargeSwitches__mnemo = Ident::Alias_LargeSwitches();
my $MissingBraces__mnemo = Ident::Alias_MissingBraces();
my $If__mnemo = Ident::Alias_If();
my $For__mnemo = Ident::Alias_For();
my $While__mnemo = Ident::Alias_While();
my $Do__mnemo = Ident::Alias_Do();
my $Case__mnemo = Ident::Alias_Case();
my $LongElsif__mnemo = Ident::Alias_LongElsif();
my $InvertedLogic__mnemo = Ident::Alias_InvertedLogic();
my $CollapsibleIf__mnemo = Ident::Alias_CollapsibleIf();
my $ComplexConditions__mnemo = Ident::Alias_ComplexConditions();
my $ConditionComplexityAverage__mnemo = Ident::Alias_ConditionComplexityAverage();

my $nb_DuplicatedCondition = 0;
my $nb_MissingFinalElses = 0;
my $nb_MatchNested = 0;
my $nb_LargeMatches = 0;
my $nb_MissingBraces = 0;
my $nb_If = 0;
my $nb_For = 0;
my $nb_While = 0;
my $nb_Do = 0;
my $nb_Case = 0;
my $nb_LongElsif = 0;
my $nb_InvertedLogic = 0;
my $nb_CollapsibleIf = 0;
my $nb_ComplexConditions = 0;
my $nb_ConditionComplexityAverage = 0;

sub CountCondition($$$) {
    my ($file, $vue, $compteurs) = @_;

    my $ret = 0;
    $nb_DuplicatedCondition = 0;
    $nb_MissingFinalElses = 0;
    $nb_MatchNested = 0;
    $nb_LargeMatches = 0;
    $nb_MissingBraces = 0;
    $nb_If = 0;
    $nb_For = 0;
    $nb_While = 0;
    $nb_Do = 0;
    $nb_Case = 0;
    $nb_LongElsif = 0;
    $nb_InvertedLogic = 0;
    $nb_CollapsibleIf = 0;
    $nb_ComplexConditions = 0;
    $nb_ConditionComplexityAverage = 0;

    my $root = \$vue->{'code'};

    if (!defined $root) {
        $ret |= Couples::counter_add($compteurs, $DuplicatedCondition__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MissingFinalElses__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $SwitchNested__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $LargeSwitches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MissingBraces__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $If__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $For__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $While__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $Do__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $Case__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $LongElsif__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $InvertedLogic__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $CollapsibleIf__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $ConditionComplexityAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);

        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @IfStatements = @{$vue->{'KindsLists'}->{&IfKind}};
    my @ElseStatements = @{$vue->{'KindsLists'}->{&ElseKind}};
    my @CaseStatements = @{$vue->{'KindsLists'}->{&CaseKind}};
    my @MatchStatements = @{$vue->{'KindsLists'}->{&MatchKind}};
    my @WhileStatements = @{$vue->{'KindsLists'}->{&WhileKind}};
    my @ForLoops = @{$vue->{'KindsLists'}->{&ForKind}};
    my @DoWhileStatements = @{$vue->{'KindsLists'}->{&DoWhileKind}};

	my $nb_MixConditions = 0;
	my $nb_TotalLogicalOperator = 0;

    ## IF / ELSIF
    my %hashSameCond;
    for my $ifNode (@IfStatements) {
        my $condNode = GetChildren($ifNode)->[0];
        my $cond_stmt = ${GetStatement($condNode)};
        # CLASSIC IF
        if (!IsKind(GetParent($ifNode), ElseKind)) {
            # initialize
            %hashSameCond = ();
            my $boolElsif = 0;
            my $boolFinalElse = 0;
            my $boolFinalElsif = 0;
            my $nodeFinalElse;

            my $lineIfWithFinalElse;
            my $lineToCompare = GetLine($ifNode);
            if ($lineIfWithFinalElse = ReturnFinalElse($ifNode)) {
                if ($lineToCompare == $lineIfWithFinalElse) {
                    $boolFinalElse = 1;
               }
            }
            my $lineIfWithFinalElsIf;
            if ($lineIfWithFinalElsIf = ReturnFinalElsif($ifNode)) {
                if ($lineToCompare == $lineIfWithFinalElsIf) {
                    $boolFinalElsif = 1;
                }
            }

            # for future listing of else if nodes
            my $elseNode = GetChildren($ifNode)->[2];
            my $nb_Elsif = 0;
            while (defined $elseNode) {
                my $elsifNode = GetChildren($elseNode)->[0];
                if (defined $elsifNode && IsKind($elsifNode, IfKind)) {
                    $boolElsif = 1;
                    $nb_Elsif++;
                    $elseNode = GetChildren($elsifNode)->[2];
                }
                else {
                    $elseNode = undef;
                }
            }

            # HL-1984 24/03/2022 "if ... else if" constructs should end with "else" clauses
            if ($boolFinalElse == 0 && $boolElsif == 1) {
                # print "'if\/else if' constructs should end with 'else' clauses at line " . GetLine($ifNode) . "\n";
                $nb_MissingFinalElses++;
                Erreurs::VIOLATION($MissingFinalElses__mnemo, "'if\/else if' constructs should end with 'else' clauses at line " . GetLine($ifNode));
            }

            # HL-1998 31/03/2022 Enforce pattern matching over else-if nesting
            if ($nb_Elsif > $THRESHOLD_LONG_ELSIF) {
                # print "Avoid long elsif chain in if condition at line " . GetLine($ifNode) . "\n";
                $nb_LongElsif++;
                Erreurs::VIOLATION($LongElsif__mnemo, "Avoid long elsif chain in if condition at line " . GetLine($ifNode));
            }

            # HL-2000 01/04/2022 Collapsible "if" statements should be merged
            if ($boolFinalElse == 0 && $boolFinalElsif == 0) {
                my $thenNode = GetChildren($ifNode)->[1];
                my $children = GetChildren($thenNode);
                if (defined $children && exists $children->[0]) {
                    if (IsKind($children->[0], AccoKind)) {
                        my $childrenAcco = GetChildren($children->[0]);
                        if (defined $childrenAcco && scalar @{$childrenAcco} == 1
                            && IsKind($childrenAcco->[0], IfKind)) {
                            my $lineFinalElse = ReturnFinalElse($childrenAcco->[0]);
                            my $lineFinalElsif = ReturnFinalElsif($childrenAcco->[0]);
                            if (!defined $lineFinalElse && !defined $lineFinalElsif) {
                                # print "Collapsible 'if' statements should be merged at line " . GetLine($childrenAcco->[0]) . "\n";
                                $nb_CollapsibleIf++;
                                Erreurs::VIOLATION($CollapsibleIf__mnemo, "Collapsible 'if' statements should be merged at line " . GetLine($childrenAcco->[0]));
                            }
                         }
                    }
                    # if body without accolades
                    elsif (IsKind($children->[0], IfKind)) {
                        if (defined $children->[0] && scalar @{$children} == 1) {
                            my $lineFinalElse = ReturnFinalElse($children->[0]);
                            my $lineFinalElsif = ReturnFinalElsif($children->[0]);
                            if (!defined $lineFinalElse && !defined $lineFinalElsif) {
                                # print "Collapsible 'if' statements should be merged at line " . GetLine($children->[0]) . "\n";
                                $nb_CollapsibleIf++;
                                Erreurs::VIOLATION($CollapsibleIf__mnemo, "Collapsible 'if' statements should be merged at line " . GetLine($children->[0]));
                            }
                        }
                    }
                    else {
                        if (scalar @{$children} == 1
                            && IsKind($children->[0], IfKind)) {
                            # print "Collapsible 'if' statements should be merged at line " . GetLine($children->[0]) . "\n";
                            $nb_CollapsibleIf++;
                            Erreurs::VIOLATION($CollapsibleIf__mnemo, "Collapsible 'if' statements should be merged at line " . GetLine($children->[0]));
                        }
                    }
                }
            }
        }
        if (defined $cond_stmt) {
            my $cond_label = $cond_stmt;
            # HL-1975 21/03/2022 Related "if"/"else if" statements and "case" in a "match" should not have the same condition
            $cond_stmt =~ s/\s+//g;
            if (exists $hashSameCond{$cond_stmt}) {
                # print "if/elsif statement should not have the same condition '$cond_label' at line " . GetLine($ifNode) . "\n";
                $nb_DuplicatedCondition++;
                Erreurs::VIOLATION($DuplicatedCondition__mnemo, "if/elsif statement should not have the same condition '$cond_label' at line " . GetLine($ifNode));
            }
            else {
                $hashSameCond{$cond_stmt} = 1;
            }

            # HL-2024 20/04/2022 Avoid complex conditions
            if ($cond_stmt =~ /\&\&/ && $cond_stmt =~ /\|\|/) {
                my $nb_logicalOperator = () = $cond_stmt =~ /\&\&|\|\|/g;
                $nb_TotalLogicalOperator += $nb_logicalOperator;
                $nb_MixConditions++;
                if ($nb_logicalOperator > Scala::ScalaConfig::THRESHOLD_COMPLEX_CONDITION) {
                    # print "Complex condition '$cond_label' at line " . GetLine($ifNode) . "\n";
                    $nb_ComplexConditions++;
                    Erreurs::VIOLATION($ComplexConditions__mnemo, "Complex condition '$cond_label' at line " . GetLine($ifNode));
                }
            }
        }
        # HL-1993 29/03/2022 Enforce curly braces
        my $thenNode = GetChildren($ifNode)->[1];
        my $children = GetChildren($thenNode);
        my $firstChild = $children->[0];
        if (defined $firstChild && !IsKind($firstChild, AccoKind)) {
            # print "Missing curly braces at line " . GetLine($ifNode) . "\n";
            $nb_MissingBraces++;
            Erreurs::VIOLATION($MissingBraces__mnemo, "Missing curly braces at line " . GetLine($ifNode));
        }
        # HL-1999 01/04/2022 Enforce simplification of boolean expressions
        if ($cond_stmt =~ /^\s*\!/m) {
            # print "Condition using '!' operator at line " . GetLine($ifNode) . "\n";
            $nb_InvertedLogic++;
            Erreurs::VIOLATION($InvertedLogic__mnemo, "Condition using '!' operator at line " . GetLine($ifNode));
        }
    }
    ## ELSE
    for my $elseNode (@ElseStatements) {
        # HL-1993 08/04/2022 Enforce curly braces
        my $children = GetChildren($elseNode);
        my $firstChild = $children->[0];
        # CLASSIC ELSE (not else if)
        if (defined $firstChild && !IsKind($firstChild, IfKind)) {
            if (!IsKind($firstChild, AccoKind)) {
                # print "Missing curly braces at line " . GetLine($elseNode) . "\n";
                $nb_MissingBraces++;
                Erreurs::VIOLATION($MissingBraces__mnemo, "Missing curly braces at line " . GetLine($elseNode));
            }
        }
    }
    ## MATCH
    for my $matchNode (@MatchStatements) {
        my @nestedMatchStatements = GetNodesByKindList($matchNode, [ MatchKind ], 1);
        # HL-1985 24/03/2022 "match" statements should not be nested
        if (@nestedMatchStatements && scalar @nestedMatchStatements > 0) {
            for my $nestedMatch (@nestedMatchStatements) {
                # print "'match' statements should not be nested at line " . GetLine($nestedMatch) . "\n";
                $nb_MatchNested++;
                Erreurs::VIOLATION($SwitchNested__mnemo, "'match' statements should not be nested at line " . GetLine($nestedMatch));
            }
        }
        # HL-1987 25/03/2022 "match" expressions should not have too many "case" clauses
        my $accoNode = GetChildren($matchNode)->[0];
        my $children = GetChildren($accoNode);
        if (scalar @{$children} > $LARGE_MATCH_LENGTH_THRESHOLD) {
            # print "match with more than " . $LARGE_MATCH_LENGTH_THRESHOLD . " case statements at line " . GetLine($matchNode) . "\n";
            $nb_LargeMatches++;
            Erreurs::VIOLATION($LargeSwitches__mnemo, "match with more than " . $LARGE_MATCH_LENGTH_THRESHOLD . " case statements at line " . GetLine($matchNode));
        }
        # HL-1975 21/03/2022 Related "if"/"else if" statements and "case" in a "match" should not have the same condition
        my %hashSameCond;
        for my $caseNode (@CaseStatements) {
            my $condNode = GetChildren($caseNode)->[0];
            my $cond_stmt = ${GetStatement($condNode)};
            if (defined $cond_stmt) {
                $cond_stmt =~ s/\s+//g;
                if (exists $hashSameCond{$cond_stmt}) {
                    # print "case statement should not have the same condition '$cond_stmt' at line " . GetLine($caseNode) . "\n";
                    $nb_DuplicatedCondition++;
                    Erreurs::VIOLATION($DuplicatedCondition__mnemo, "case statement should not have the same condition '$cond_stmt' at line " . GetLine($caseNode));
                }
                else {
                    $hashSameCond{$cond_stmt} = 1;
                }
            }
        }
    }
    ## WHILE
    for my $whileNode (@WhileStatements) {
        # HL-1993 29/03/2022 Enforce curly braces
        my $children = GetChildren($whileNode);
        my $secondChild = $children->[1];
        if (defined $secondChild && !IsKind($secondChild, AccoKind)) {
            # print "Missing curly braces at line " . GetLine($whileStatement) . "\n";
            $nb_MissingBraces++;
            Erreurs::VIOLATION($MissingBraces__mnemo, "Missing curly braces at line " . GetLine($whileNode));
        }
        # HL-1999 01/04/2022 Enforce simplification of boolean expressions
        my $firstChild = $children->[0];
        my $cond_stmt = ${GetStatement($firstChild)};
        if (defined $cond_stmt) {
            my $cond_label = $cond_stmt;
            if ($cond_stmt =~ /^\s*\!/m) {
                # print "Condition using '!' operator at line " . GetLine($whileNode) . "\n";
                $nb_InvertedLogic++;
                Erreurs::VIOLATION($InvertedLogic__mnemo, "Condition using '!' operator at line " . GetLine($whileNode));
            }
            # HL-2024 20/04/2022 Avoid complex conditions
            if ($cond_stmt =~ /\&\&/ && $cond_stmt =~ /\|\|/) {
                my $nb_logicalOperator = () = $cond_stmt =~ /\&\&|\|\|/g;
                $nb_TotalLogicalOperator += $nb_logicalOperator;
                $nb_MixConditions++;
                if ($nb_logicalOperator > Scala::ScalaConfig::THRESHOLD_COMPLEX_CONDITION) {
                    # print "Complex condition '$cond_label' at line " . GetLine($whileNode) . "\n";
                    $nb_ComplexConditions++;
                    Erreurs::VIOLATION($ComplexConditions__mnemo, "Complex condition '$cond_label' at line " . GetLine($whileNode));
                }
            }
        }
    }
    ## FOR
    for my $forNode (@ForLoops) {
        # HL-1993 08/04/2022 Enforce curly braces
        my $children = GetChildren($forNode);
        my $secondChild = $children->[1];
        if (defined $secondChild && !IsKind($secondChild, AccoKind)) {
            # print "Missing curly braces at line " . GetLine($forNode) . "\n";
            $nb_MissingBraces++;
            Erreurs::VIOLATION($MissingBraces__mnemo, "Missing curly braces at line " . GetLine($forNode));
        }
    }
    ## DO WHILE
    for my $doWhileNode (@DoWhileStatements) {
        # HL-1993 08/04/2022 Enforce curly braces
        my $children = GetChildren($doWhileNode);
        my $fistChild = $children->[0];
        if (defined $fistChild && !IsKind($fistChild, AccoKind)) {
            # print "Missing curly braces at line " . GetLine($doWhileNode) . "\n";
            $nb_MissingBraces++;
            Erreurs::VIOLATION($MissingBraces__mnemo, "Missing curly braces at line " . GetLine($doWhileNode));
        }
    }
    ## METRICS
    $nb_If = scalar(@IfStatements);
    $nb_For = scalar(@ForLoops);
    $nb_While = scalar(@WhileStatements);
    $nb_Do = scalar(@DoWhileStatements);
    $nb_Case = scalar(@CaseStatements);

    # AVERAGES
    if ($nb_MixConditions > 0) {
        $nb_ConditionComplexityAverage = int($nb_TotalLogicalOperator / $nb_MixConditions);
    }

    $ret |= Couples::counter_add($compteurs, $DuplicatedCondition__mnemo, $nb_DuplicatedCondition);
    $ret |= Couples::counter_add($compteurs, $MissingFinalElses__mnemo, $nb_MissingFinalElses);
    $ret |= Couples::counter_add($compteurs, $SwitchNested__mnemo, $nb_MatchNested);
    $ret |= Couples::counter_add($compteurs, $LargeSwitches__mnemo, $nb_LargeMatches);
    $ret |= Couples::counter_add($compteurs, $MissingBraces__mnemo, $nb_MissingBraces);
    $ret |= Couples::counter_add($compteurs, $If__mnemo, $nb_If);
    $ret |= Couples::counter_add($compteurs, $For__mnemo, $nb_For);
    $ret |= Couples::counter_add($compteurs, $While__mnemo, $nb_While);
    $ret |= Couples::counter_add($compteurs, $Do__mnemo, $nb_Do);
    $ret |= Couples::counter_add($compteurs, $Case__mnemo, $nb_Case);
    $ret |= Couples::counter_add($compteurs, $LongElsif__mnemo, $nb_LongElsif);
    $ret |= Couples::counter_add($compteurs, $InvertedLogic__mnemo, $nb_InvertedLogic);
    $ret |= Couples::counter_add($compteurs, $CollapsibleIf__mnemo, $nb_CollapsibleIf);
    $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, $nb_ComplexConditions);
    $ret |= Couples::counter_add($compteurs, $ConditionComplexityAverage__mnemo, $nb_ConditionComplexityAverage);

    return $ret;
}

sub ReturnFinalElse($) {
    my $nodeToCheck = shift;
    my $lineIfOrigin = GetLine($nodeToCheck);
    while (defined $nodeToCheck) {
        my $elseNode = GetChildren($nodeToCheck)->[2];
        if (defined $elseNode) {
            my $child = GetChildren($elseNode)->[0];
            if (defined $child) {
                # elsif node
                if (IsKind($child, IfKind)) {
                    $nodeToCheck = $child;
                }
                # final else
                elsif (IsKind(GetParent($child), ElseKind) && IsKind($child, AccoKind)) {
                    # print "If condition at line $lineIfOrigin has final else at line " . GetLine($elseNode) . "\n";
                    return $lineIfOrigin;
                }
                else {
                    $nodeToCheck = undef;
                }
            }
            else {
                $nodeToCheck = undef;
            }
        }
        else {
            $nodeToCheck = undef;
        }
    }
    return undef;
}

sub ReturnFinalElsif($) {
    my $nodeToCheck = shift;
    my $lineIfOrigin = GetLine($nodeToCheck);
    my $finalElsif = 0;
    while (defined $nodeToCheck) {
        my $elseNode = GetChildren($nodeToCheck)->[2];
        if (defined $elseNode) {
            my $child = GetChildren($elseNode)->[0];
            if (defined $child) {
                # elsif node
                if (IsKind($child, IfKind)) {
                    $nodeToCheck = $child;
                    $finalElsif = 1;
                }
                else {
                    $nodeToCheck = $child;
                    $finalElsif = 0;
                }
            }
            else {
                $nodeToCheck = undef;
            }
        }
        else {
            $nodeToCheck = undef;
        }
    }
    if ($finalElsif == 1) {
        # print "If condition at line $lineIfOrigin has final elsif\n";
        return $lineIfOrigin;
    }
    return undef;
}
1;
