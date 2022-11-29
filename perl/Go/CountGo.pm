package Go::CountGo;
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

my $SuspiciousOperator__mnemo = Ident::Alias_SuspiciousOperator();
my $BadValuesOperator__mnemo = Ident::Alias_BadValuesOperator();
my $EmptyStatementBloc__mnemo = Ident::Alias_EmptyStatementBloc();
my $InvertedLogic__mnemo = Ident::Alias_InvertedLogic();
my $MultipleStatementsOnSameLine__mnemo = Ident::Alias_MultipleStatementsOnSameLine();
my $CaseLengthAverage__mnemo = Ident::Alias_CaseLengthAverage();
my $MultipleBreakLoops__mnemo = Ident::Alias_MultipleBreakLoops();
my $InstanciationWithNew__mnemo = Ident::Alias_InstanciationWithNew();

my $nb_SuspiciousOperator = 0;
my $nb_BadValuesOperator = 0;
my $nb_EmptyStatementBloc = 0;
my $nb_InvertedLogic = 0;
my $nb_MultipleStatementsOnSameLine = 0;
my $nb_CaseLengthAverage = 0;
my $nb_MultipleBreakLoops = 0;
my $nb_InstanciationWithNew = 0;

sub CountGo($$$) {
    my ($file, $vue, $compteurs) = @_;

    my $ret = 0;
    $nb_SuspiciousOperator = 0;
    $nb_BadValuesOperator = 0;
    $nb_EmptyStatementBloc = 0;
    $nb_InvertedLogic = 0;
    $nb_MultipleStatementsOnSameLine = 0;
    $nb_CaseLengthAverage = 0;
    $nb_MultipleBreakLoops = 0;
    $nb_InstanciationWithNew = 0;

    my $root = \$vue->{'code'};
    my $MixBloc_NumLinesComment = $vue->{'MixBloc_NumLinesComment'};

    my @ifConditions = @{$vue->{'KindsLists'}->{&IfKind}};
    my @elseConditions = @{$vue->{'KindsLists'}->{&ElseKind}};
    my @forLoops = @{$vue->{'KindsLists'}->{&ForKind}};
    my @switch = @{$vue->{'KindsLists'}->{&SwitchKind}};

    if ((!defined $root)) {
        $ret |= Couples::counter_add($compteurs, $SuspiciousOperator__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $BadValuesOperator__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $EmptyStatementBloc__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $InvertedLogic__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MultipleStatementsOnSameLine__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $CaseLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MultipleBreakLoops__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $InstanciationWithNew__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @controlFlow = (@ifConditions, @elseConditions, @forLoops, @switch);

    my $numLine = 1;
    while ($$root =~ /(\n)|(\=\+|\=\-|\=\!)|(.*\;.*)|\b(new)\b/g) {
        if (defined $1 && $1 eq "\n") {
            $numLine++;
        }
        # HL 1591 15/01/2021 "=+" should not be used instead of "+=" (same rule for operators =-, or =! )
        elsif (defined $2) {
            # print "Suspicious operator '$2' is used at line $numLine\n";
            $nb_SuspiciousOperator++;
            Erreurs::VIOLATION($SuspiciousOperator__mnemo, "Suspicious operator '$2' is used at line $numLine.");
        }
        # HL 1610 26/01/2021 Statements should be on separate lines
        elsif (defined $3 && $3 !~ /\b(?:if|for|switch)\b/) {
            my $lineCode = $3;
            $lineCode =~ s/ //g;
            my @split_line = split(/\;/, $lineCode);
            if (@split_line && scalar @split_line >= 2) {
                # print "Statements should be on separate lines at line $numLine\n";
                $nb_MultipleStatementsOnSameLine++;
                Erreurs::VIOLATION($MultipleStatementsOnSameLine__mnemo, "Statements should be on separate lines at line $numLine");
            }
        }
        # HL-1641 05/02/2021 Avoid "new" keyword
        elsif (defined $4) {
            # print "Avoid 'new' keyword at line $numLine\n";
            $nb_InstanciationWithNew++;
            Erreurs::VIOLATION($InstanciationWithNew__mnemo, "Avoid 'new' keyword at line $numLine");
        }
    }
    $numLine = 1;
    my $root_without_spaces = $$root;
    $root_without_spaces =~ s/ //g;
    while ($root_without_spaces =~ /(.*?)\s*(?:\&\&|\|\|)\s*(\1)|(\=\!|\!\()|(\n)/g) {
        if (defined $4 && $4 eq "\n") {
            $numLine++;
        }
        # HL 1593 18/01/2021 Identical expressions should not be used on both sides of a binary operator
        elsif (defined $1 && defined $2 && $2 ne "") {
            # print "Identical expressions should not be used on both sides of a binary operator at line $numLine\n";
            $nb_BadValuesOperator++;
            Erreurs::VIOLATION($BadValuesOperator__mnemo, "Identical expressions should not be used on both sides of a binary operator at line $numLine");
        }
        # HL 1600 22/01/2021 Boolean checks should not be inverted
        elsif (defined $3) {
            # print "Boolean checks should not be inverted at line $numLine\n";
            $nb_InvertedLogic++;
            Erreurs::VIOLATION($InvertedLogic__mnemo, "Boolean checks should not be inverted at line $numLine");
        }
    }

    my $bonusLineCases;
    my $totalCases;

    # HL-1598 21/01/2021 Nested blocks of code should not be left empty
    for my $controlFlow (@controlFlow) {
        my $parent = GetParent($controlFlow);
        # if & elsif
        if (IsKind($controlFlow, IfKind) && IsKind($parent, AccoKind)) {
            my @then = GetNodesByKind($controlFlow, ThenKind, 1);

            for my $then (@then) {
                my $acco = GetChildren($then);
                my $body = GetChildren($acco->[0]);
                if (defined $body && scalar @{$body} == 0) {
                    my $beginningLine = GetLine($then);
                    my $endingLine = GetEndline($acco->[0]);
                    my $boolComment = commentChecker($MixBloc_NumLinesComment, $beginningLine, $endingLine);
                    if ($boolComment == 0) {
                        # print "Nested blocks of code 'if/else if' should not be left empty at line " . GetLine($then) . "\n";
                        $nb_EmptyStatementBloc++;
                        Erreurs::VIOLATION($EmptyStatementBloc__mnemo, "Nested blocks of code 'if/else if' should not be left empty at line " . GetLine($then));
                    }
                }
            }
        }
        # else
        elsif (IsKind($controlFlow, ElseKind)) {
            my $acco = GetChildren($controlFlow);
            my $body = GetChildren($acco->[0]);
            if (defined $body && scalar @{$body} == 0) {
                my $beginningLine = GetLine($controlFlow);
                my $endingLine = GetEndline($acco->[0]);
                my $boolComment = commentChecker($MixBloc_NumLinesComment, $beginningLine, $endingLine);
                if ($boolComment == 0) {
                    # print "Nested blocks of code 'else' should not be left empty at line " . GetLine($controlFlow) . "\n";
                    $nb_EmptyStatementBloc++;
                    Erreurs::VIOLATION($EmptyStatementBloc__mnemo, "Nested blocks of code 'else' should not be left empty at line " . GetLine($controlFlow));
                }
            }
        }
        #for
        elsif (IsKind($controlFlow, ForKind)) {
            my @acco = GetNodesByKind($controlFlow, AccoKind);
            my $body = GetChildren($acco[0]);
            if (defined $body && scalar @{$body} == 0) {
                my $beginningLine = GetLine($controlFlow);
                my $endingLine = GetEndline($acco[0]);
                my $boolComment = commentChecker($MixBloc_NumLinesComment, $beginningLine, $endingLine);
                if ($boolComment == 0) {
                    # print "Nested blocks of code 'for' should not be left empty at line " . GetLine($controlFlow) . "\n";
                    $nb_EmptyStatementBloc++;
                    Erreurs::VIOLATION($EmptyStatementBloc__mnemo, "Nested blocks of code 'else' should not be left empty at line " . GetLine($controlFlow));
                }
            }

            # HL-1624 04/02/2021 Avoid multiple breaks in loops
            my @breaks = GetNodesByKindList($controlFlow, , [BreakKind]);
            if (scalar @breaks > 1) {
                my $i = 0;
                for my $break (@breaks) {
                    if ($i >= 1) {
                        # print "Avoid multiple breaks in loop at line " . GetLine($break) . "\n";
                        $nb_MultipleBreakLoops++;
                        Erreurs::VIOLATION($MultipleBreakLoops__mnemo, "Avoid multiple breaks in loop at line " . GetLine($break));
                    }
                    $i++;
                }
            }
        }
        #switch
        elsif (IsKind($controlFlow, SwitchKind)) {
            my @cases = GetNodesByKindList($controlFlow, , [CaseKind, DefaultKind]);
            # case / default
            for my $case (@cases) {
                my $children = GetChildren($case);
                #case
                if (IsKind($case, CaseKind)) {
                    if (defined $children) {
                        if (scalar @{$children} == 1) {
                            my $beginningLine = GetLine($case);
                            my $endingLine = GetEndline($case);
                            my $boolComment = commentChecker($MixBloc_NumLinesComment, $beginningLine, $endingLine);
                            if ($boolComment == 0) {
                                # print "Nested blocks of code 'case' should not be left empty at line " . GetLine($case) . "\n";
                                $nb_EmptyStatementBloc++;
                                Erreurs::VIOLATION($EmptyStatementBloc__mnemo, "Nested blocks of code 'else' should not be left empty at line " . GetLine($case));
                            }
                        }
                        # HL-1611 27/01/2021 "switch case" clauses should not have too many lines
                        my $sizeBlocCase = GetEndline($case) - GetLine($case) - 2;
                        if ($sizeBlocCase >= 5) {
                            $bonusLineCases += $sizeBlocCase - 5;
                        }
                    }
                    $totalCases++;
                }
                #default
                else {
                    if (defined $children && scalar @{$children} == 0) {
                        my $beginningLine = GetLine($case);
                        my $endingLine = GetEndline($case);
                        my $boolComment = commentChecker($MixBloc_NumLinesComment, $beginningLine, $endingLine);
                        if ($boolComment == 0) {
                            # print "Nested blocks of code 'default' should not be left empty at line " . GetLine($case) . "\n";
                            $nb_EmptyStatementBloc++;
                            Erreurs::VIOLATION($EmptyStatementBloc__mnemo, "Nested blocks of code 'default' should not be left empty at line " . GetLine($case));
                        }
                    }
                }
            }
        }
    }

    # HL-1611 27/01/2021 "switch case" clauses should not have too many lines
    if (defined $bonusLineCases && defined $totalCases && $totalCases > 0) {
        $nb_CaseLengthAverage = $bonusLineCases / $totalCases;
        if ($nb_CaseLengthAverage  != 0) {
            # rounding to nearest integer
            $nb_CaseLengthAverage = int($nb_CaseLengthAverage + $nb_CaseLengthAverage/abs($nb_CaseLengthAverage*2));
        }
        # print "'switch' case clauses should not have too many lines of code (average = $nb_CaseLengthAverage)\n";
        Erreurs::VIOLATION($CaseLengthAverage__mnemo, "'switch' case clauses should not have too many lines of code (average = $nb_CaseLengthAverage).");
    }

    $ret |= Couples::counter_add($compteurs, $SuspiciousOperator__mnemo, $nb_SuspiciousOperator );
    $ret |= Couples::counter_add($compteurs, $BadValuesOperator__mnemo, $nb_BadValuesOperator );
    $ret |= Couples::counter_add($compteurs, $EmptyStatementBloc__mnemo, $nb_EmptyStatementBloc );
    $ret |= Couples::counter_add($compteurs, $InvertedLogic__mnemo, $nb_InvertedLogic );
    $ret |= Couples::counter_add($compteurs, $MultipleStatementsOnSameLine__mnemo, $nb_MultipleStatementsOnSameLine );
    $ret |= Couples::counter_add($compteurs, $CaseLengthAverage__mnemo, $nb_CaseLengthAverage );
    $ret |= Couples::counter_add($compteurs, $MultipleBreakLoops__mnemo, $nb_MultipleBreakLoops );
    $ret |= Couples::counter_add($compteurs, $InstanciationWithNew__mnemo, $nb_InstanciationWithNew );

    return $ret;
}

sub commentChecker($$$) {
    my $MixBloc_NumLinesComment = shift;
    my $beginningLine = shift;
    my $endingLine = shift;

    my $boolComment = 0;
    for (my $numLine = $beginningLine; $numLine <= $endingLine; $numLine++) {
        if (exists $MixBloc_NumLinesComment->{$numLine}) {
            $boolComment = 1;
        }
    }

    return $boolComment;
}

sub CountItem($$$$) {
    my ($item, $mnemo_Item, $code, $compteurs) = @_ ;
    my $status = 0;

    if (!defined $$code )
    {
        $status |= Couples::counter_add($compteurs, $mnemo_Item, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $nbr_Item = () = $$code =~ /${item}/sg;

    $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);

    return $status;
}

sub CountKeywords($$$) {
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $code = \$vue->{'code'};

    $status |= CountItem('\bif\b', Ident::Alias_If(), $code, $compteurs);
    $status |= CountItem('\bbreak\b', Ident::Alias_Break(), $code, $compteurs);
    $status |= CountItem('\bcontinue\b', Ident::Alias_Continue(), $code, $compteurs);
    $status |= CountItem('\bfor\b', Ident::Alias_For(), $code, $compteurs);
    $status |= CountItem('\bcase\b', Ident::Alias_Case(), $code, $compteurs);
    $status |= CountItem('\breturn\b', Ident::Alias_Return(), $code, $compteurs);

    return $status;
}

1;
