package Go::CountCondition;
# les modules importes
use strict;
use warnings;

use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use Go::GoNode;
use Go::GoConfig;

my $DEBUG = 0;
my $THRESHOLD_COMPLEX = 4;
my $THRESHOLD_LONG_ELSIF = 2;

my $DuplicatedCondition__mnemo = Ident::Alias_DuplicatedCondition();
my $SwitchLengthAverage__mnemo = Ident::Alias_SwitchLengthAverage();
my $SwitchNested__mnemo = Ident::Alias_SwitchNested();
my $MissingDefaults__mnemo = Ident::Alias_MissingDefaults();
my $ComplexConditions__mnemo = Ident::Alias_ComplexConditions();
my $MissingFinalElses__mnemo = Ident::Alias_MissingFinalElses();
my $UnconditionalCondition__mnemo = Ident::Alias_UnconditionalCondition();
my $EqualityInLoopCondition__mnemo = Ident::Alias_EqualityInLoopCondition();
my $LongElsif__mnemo = Ident::Alias_LongElsif();
my $CollapsibleIf__mnemo = Ident::Alias_CollapsibleIf();
my $LargeSwitches__mnemo = Ident::Alias_LargeSwitches();


my $nb_DuplicatedCondition= 0;
my $nb_SwitchLengthAverage= 0;
my $nb_SwitchNested= 0;
my $nb_MissingDefaults= 0;
my $nb_ComplexConditions= 0;
my $nb_MissingFinalElses= 0;
my $nb_UnconditionalCondition= 0;
my $nb_EqualityInLoopCondition= 0;
my $nb_LongElsif= 0;
my $nb_CollapsibleIf= 0;
my $nb_LargeSwitches = 0;

sub CountCondition($$$) {
    my ($file, $vue, $compteurs) = @_;

    my $ret = 0;
    $nb_DuplicatedCondition = 0;
    $nb_SwitchLengthAverage = 0;
    $nb_SwitchNested = 0;
    $nb_MissingDefaults = 0;
    $nb_ComplexConditions = 0;
    $nb_MissingFinalElses = 0;
    $nb_UnconditionalCondition = 0;
    $nb_EqualityInLoopCondition = 0;
    $nb_LongElsif = 0;
    $nb_CollapsibleIf = 0;
    $nb_LargeSwitches = 0;

    my $root = \$vue->{'code'};

    if (!defined $root) {
        $ret |= Couples::counter_add($compteurs, $DuplicatedCondition__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $SwitchLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $SwitchNested__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MissingDefaults__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MissingFinalElses__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $UnconditionalCondition__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $EqualityInLoopCondition__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $LongElsif__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $CollapsibleIf__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $LargeSwitches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @IfStatements = @{$vue->{'KindsLists'}->{&IfKind}};
    my @SwitchStatements = @{$vue->{'KindsLists'}->{&SwitchKind}};
    my @CaseStatements = @{$vue->{'KindsLists'}->{&CaseKind}};
    my @ForStatements = @{$vue->{'KindsLists'}->{&ForKind}};

    my $KindStatements = [ @IfStatements, @CaseStatements, @ForStatements ];
    my %hashSameCond;
    my $linePrimaryNode = 0;
    my $boolNoReturn = 0;
    my $boolElsif = 0;
    my $boolFinalElse = 0;
    my %hashElsif;

    #################
    # IF & CASE & FOR
    #################
    for my $kindNode (@{$KindStatements}) {
        my $kind = GetKind($kindNode);

        ############
        # CONDITIONS
        ############
        if (IsKind(GetParent($kindNode), AccoKind) || IsKind(GetParent($kindNode), CaseKind)
            || IsKind(GetParent($kindNode), SelectKind)) {
            # re initialize
            %hashSameCond = ();
        }

        my $condNode = GetChildren($kindNode)->[0];
        my $cond_stmt = ${GetStatement($condNode)};
        if (defined $cond_stmt) {
            $cond_stmt =~ s/\s//g;
            # HL-1592 15/01/2021 Related "if/else if" & cases statements should not have the same condition
            #############################
            # IF/ELSE IF & CASE CONDITION
            #############################
            if ($kind eq 'if' || $kind eq 'case') {
                if (exists $hashSameCond{$cond_stmt}) {
                    # print "$kind statements should not have the same condition <$cond_stmt> at line " . GetLine($kindNode) . "\n";
                    $nb_DuplicatedCondition++;
                    Erreurs::VIOLATION($DuplicatedCondition__mnemo, "$kind statements should not have the same condition <$cond_stmt> at line " . GetLine($kindNode));
                }
                elsif ($cond_stmt =~ /\,|\&\&|\|\|/) {
                    my @split_cond_stmt = split(/\,|\&\&|\|\|/, $cond_stmt);
                    foreach my $split_cond_stmt (@split_cond_stmt) {
                        if (exists $hashSameCond{$split_cond_stmt}) {
                            # print "$kind statements should not have the same condition <$split_cond_stmt> at line " . GetLine($kindNode) . "\n";
                            $nb_DuplicatedCondition++;
                            Erreurs::VIOLATION($DuplicatedCondition__mnemo, "$kind statements should not have the same condition <$split_cond_stmt> at line " . GetLine($kindNode));
                        }
                        else {
                            $hashSameCond{$split_cond_stmt} = 1;
                        }
                    }
                    # HL-1607 25/01/2021 Expressions conditions should not be too complex
                    # if / else if
                    if ($kind eq 'if') {
                        my @split_complex_operator = split(/\&\&|\|\|/, $cond_stmt);
                        if (@split_complex_operator && scalar @split_complex_operator > $THRESHOLD_COMPLEX) {
                            # print "Expressions conditions should not be too complex at line " . GetLine($kindNode) . "\n";
                            $nb_ComplexConditions++;
                            Erreurs::VIOLATION($DuplicatedCondition__mnemo, "Expressions conditions should not be too complex at line " . GetLine($kindNode));
                        }
                    }
                }
                # HL-1609 25/01/2021 Useless "if(true) {...}" and "if(false){...}" blocks should be removed
                elsif ($kind eq 'if' && $cond_stmt =~ /^[\s\(]*(true|false)[\s\)]*$/m) {
                    # print "Useless if($1) block should be removed at line " . GetLine($kindNode) . "\n";
                    $nb_UnconditionalCondition++;
                    Erreurs::VIOLATION($UnconditionalCondition__mnemo, "Useless if($1) block should be removed at line " . GetLine($kindNode));
                }
                else {
                    $hashSameCond{$cond_stmt} = 1;
                }
            }
            ####################
            # FOR CONDITION
            ####################
            elsif ($kind eq 'for') {
                # HL-1623 04/02/2021 Avoid equality operators in for loop condition
                if ($cond_stmt =~ /.*\;(.*)\;.*/) {
                    my $endingLoop = $1;
                    if ($endingLoop =~ /\!\=|\=\=/) {
                        # print "Avoid equality operators in for loop condition at line " . GetLine($kindNode) . "\n";
                        $nb_EqualityInLoopCondition++;
                        Erreurs::VIOLATION($EqualityInLoopCondition__mnemo, "Avoid equality operators in for loop condition at line " . GetLine($kindNode));
                    }
                }
            }
        }
        ############
        # STATEMENTS
        ############
        # HL-1606 25/01/2021 "if ... else if" constructs should end with "else" clauses
        #############
        # IF/ELSE IF
        #############
        if ($kind eq 'if') {
            if (!IsKind(GetParent($kindNode), ElseKind)) {
                # initialize
                $boolNoReturn = 0;
                $boolElsif = 0;
                $boolFinalElse = 0;
                my $nodeFinalElse;
                my $linePrimaryNode = GetLine($kindNode);

                my @accos = GetNodesByKindList($kindNode, [ AccoKind ], 1);
                $boolNoReturn = CheckReturnNodes($accos[0], $boolNoReturn);

                # for future listing of else if nodes
                my @ifNodes = GetNodesByKindList($kindNode, [ IfKind ], 0);

                for my $ifNode (@ifNodes) {
                    if (IsKind(GetParent($ifNode), ElseKind)) {
                        $hashElsif{$linePrimaryNode}++;
                        $boolElsif = 1;
                        @accos = GetNodesByKindList($ifNode, [ AccoKind ], 1);
                        $boolNoReturn = CheckReturnNodes($accos[0], $boolNoReturn);
                        $nodeFinalElse = ReturnFinalElse($ifNode);
                        $boolFinalElse = 1 if (defined $nodeFinalElse);
                    }
                    # classic if we want only else if
                    else {
                        last;
                    }
                }

                # check presence of final else on primary if with no elsif
                if ($boolFinalElse == 0) {
                    $nodeFinalElse = ReturnFinalElse($kindNode);
                    if (defined $nodeFinalElse) {
                        $boolFinalElse = 1;
                        @accos = GetNodesByKindList($kindNode, [ AccoKind ], 1);
                        $boolNoReturn = CheckReturnNodes($accos[0], $boolNoReturn);
                    }
                }

                # HL-1606 25/01/2021 "if ... else if" constructs should end with "else" clauses
                if ($boolFinalElse == 0 && $boolElsif == 1 && $boolNoReturn == 1) {
                    # print "'if\/else if' constructs should end with 'else' clauses at line " . GetLine($kindNode) . "\n";
                    $nb_MissingFinalElses++;
                    Erreurs::VIOLATION($MissingFinalElses__mnemo, "'if\/else if' constructs should end with 'else' clauses at line " . GetLine($kindNode));
                }

                # HL-1627 05/02/2021 Avoid collapsible if
                if ($boolFinalElse == 0) {
                    my @accos = GetNodesByKindList($kindNode, [ AccoKind ], 1);
                    my $acco = GetParent($kindNode);
                    my $children = GetChildren($accos[0]);
                    if (defined $children && scalar @{$children} == 1
                        && IsKind($children->[0], IfKind)) {
                        $nodeFinalElse = ReturnFinalElse($children->[0]);
                        if (!defined $nodeFinalElse) {
                            # print "Avoid collapsible if at line " . GetLine($children->[0]) . "\n";
                            $nb_CollapsibleIf++;
                            Erreurs::VIOLATION($CollapsibleIf__mnemo, "Avoid collapsible if at line " . GetLine($children->[0]));
                        }
                    }
                }
            }
        }
    }

    # HL-1625 04/02/2021 Avoid long elsif chain
    foreach my $lineBlocIf (keys %hashElsif) {
        if ($hashElsif{$lineBlocIf} >= $THRESHOLD_LONG_ELSIF) {
            # print "Avoid long elsif chain in if condition at line $lineBlocIf\n";
            $nb_LongElsif++;
            Erreurs::VIOLATION($LongElsif__mnemo, "Avoid long elsif chain in if condition at line $lineBlocIf");
        }
    }

    #############
    # SWITCH
    #############
    my $totalSwitches;
    my $totalSwitches_Over_Three_Statements = 0;
    my $bonusCases;
    for my $switchStatement (@SwitchStatements) {
        my %hashCond;
        my @caseStatements = GetChildrenByKind($switchStatement, CaseKind);
        my @nestedSwitchStatements = GetNodesByKindList($switchStatement, [ SwitchKind ], 1);
        my @defaultStatements = GetChildrenByKind($switchStatement, DefaultKind);


		if (scalar @caseStatements > Go::GoConfig::LARGE_SWITCH_LENTGH_THRESHOLD) {
            $nb_LargeSwitches++;
            Erreurs::VIOLATION($LargeSwitches__mnemo, "switch with more than ".Go::GoConfig::LARGE_SWITCH_LENTGH_THRESHOLD." statements at line " . GetLine($switchStatement));
        }
        
        if (scalar @caseStatements > 3) {
            #print "cases=" . scalar @caseStatements - 3 ."\n";
            $bonusCases += scalar @caseStatements - 3;
            $totalSwitches_Over_Three_Statements++;
        }
        $totalSwitches++;

        # HL-1602 "switch" statements should not be nested
        if (@nestedSwitchStatements && scalar @nestedSwitchStatements > 0) {
            for my $nestedSwitch (@nestedSwitchStatements) {
                # print "'switch' statements should not be nested at line " . GetLine($nestedSwitch) . "\n";
                $nb_SwitchNested++;
                Erreurs::VIOLATION($SwitchNested__mnemo, "'switch' statements should not be nested at line " . GetLine($nestedSwitch));
            }
        }

        # HL-1605 "switch" statements should have "default" clauses
        if (!@defaultStatements) {
            # print "'switch' statements should have 'default' clauses at line " . GetLine($switchStatement) . "\n";
            $nb_MissingDefaults++;
            Erreurs::VIOLATION($MissingDefaults__mnemo, "'switch' statements should not be nested at line " . GetLine($switchStatement));
        }
    }

    # HL-1596 20/01/2021 "switch" statements should not have too many "case" clauses
    if (defined $bonusCases && $totalSwitches_Over_Three_Statements > 0) {
        $nb_SwitchLengthAverage = $bonusCases / $totalSwitches_Over_Three_Statements;
        # rounding to nearest integer
        $nb_SwitchLengthAverage = int($nb_SwitchLengthAverage + $nb_SwitchLengthAverage / abs($nb_SwitchLengthAverage * 2));
        # print "bonusCases=$bonusCases\n";
        # print "totalSwitches=$totalSwitches\n";
        # print "'switch' statements should not have too many 'case' clauses (average = $nb_SwitchLengthAverage)\n";
        Erreurs::VIOLATION($SwitchLengthAverage__mnemo, "'switch' statements should not have too many 'case' clauses (average = $nb_SwitchLengthAverage).");
    }

    $ret |= Couples::counter_add($compteurs, $DuplicatedCondition__mnemo, $nb_DuplicatedCondition);
    $ret |= Couples::counter_add($compteurs, $SwitchLengthAverage__mnemo, $nb_SwitchLengthAverage);
    $ret |= Couples::counter_add($compteurs, $SwitchNested__mnemo, $nb_SwitchNested);
    $ret |= Couples::counter_add($compteurs, $MissingDefaults__mnemo, $nb_MissingDefaults);
    $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, $nb_ComplexConditions);
    $ret |= Couples::counter_add($compteurs, $MissingFinalElses__mnemo, $nb_MissingFinalElses);
    $ret |= Couples::counter_add($compteurs, $UnconditionalCondition__mnemo, $nb_UnconditionalCondition);
    $ret |= Couples::counter_add($compteurs, $EqualityInLoopCondition__mnemo, $nb_EqualityInLoopCondition);
    $ret |= Couples::counter_add($compteurs, $LongElsif__mnemo, $nb_LongElsif);
    $ret |= Couples::counter_add($compteurs, $CollapsibleIf__mnemo, $nb_CollapsibleIf);
    $ret |= Couples::counter_add($compteurs, $LargeSwitches__mnemo, $nb_LargeSwitches);

    return $ret;
}

sub CheckReturnNodes($$) {
    my $accoNode = shift;
    my $boolNoReturn = shift;
    my @returnStatements = GetNodesByKind($accoNode, ReturnKind, 1);
    if (scalar @returnStatements == 0) {
        $boolNoReturn = 1;
    }
    return $boolNoReturn;
}

sub ReturnFinalElse($$) {
    my $nodeToCheck = shift;
    my $boolFinalElse = shift;

    my $lastChild = GetChildren($nodeToCheck)->[-1];
    if (defined $lastChild && IsKind($lastChild, ElseKind)) {
        my $firstChildElseFinal = GetChildren($lastChild)->[0];
        if (defined $firstChildElseFinal && !IsKind($firstChildElseFinal, IfKind)) {
            return $firstChildElseFinal;
        }
    }
    return undef;
}

1;
