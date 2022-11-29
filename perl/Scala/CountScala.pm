package Scala::CountScala;
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

my $ToManyNestedControlFlow__mnemo = Ident::Alias_ToManyNestedControlFlow();
my $MultipleStatementsOnSameLine__mnemo = Ident::Alias_MultipleStatementsOnSameLine();
my $BadReturnStatement__mnemo = Ident::Alias_BadReturnStatement();
my $CompareToNull__mnemo = Ident::Alias_CompareToNull();
my $Default__mnemo = Ident::Alias_Default();
my $Instanceof__mnemo = Ident::Alias_Instanceof();
my $MagicNumbers__mnemo = Ident::Alias_MagicNumbers();
my $MissingDefaults__mnemo = Ident::Alias_MissingDefaults();
my $EmptyCatches__mnemo = Ident::Alias_EmptyCatches();
my $GenericCatches__mnemo = Ident::Alias_GenericCatches();

my $nb_ToManyNestedControlFlow= 0;
my $nb_MultipleStatementsOnSameLine= 0;
my $nb_BadReturnStatement= 0;
my $nb_CompareToNull= 0;
my $nb_Default= 0;
my $nb_Instanceof= 0;
my $nb_MagicNumbers= 0;
my $nb_MissingDefaults= 0;
my $nb_EmptyCatches= 0;
my $nb_GenericCatches= 0;

sub CountScala($$$) {
    my ($file, $vue, $compteurs) = @_;

    my $ret = 0;
    $nb_ToManyNestedControlFlow = 0;
    $nb_MultipleStatementsOnSameLine = 0;
    $nb_BadReturnStatement = 0;
    $nb_CompareToNull = 0;
    $nb_Default = 0;
    $nb_Instanceof = 0;
    $nb_MagicNumbers = 0;
    $nb_MissingDefaults = 0;
    $nb_EmptyCatches = 0;
    $nb_GenericCatches = 0;

    my $code = $vue->{'code'};
    my @ifConditions = @{$vue->{'KindsLists'}->{&IfKind}};
    my @forLoops = @{$vue->{'KindsLists'}->{&ForKind}};
    my @while = @{$vue->{'KindsLists'}->{&WhileKind}};
    my @matches = @{$vue->{'KindsLists'}->{&MatchKind}};
    my @try = @{$vue->{'KindsLists'}->{&TryKind}};
    my @returns = @{$vue->{'KindsLists'}->{&ReturnKind}};

    if (!defined $code) {
        $ret |= Couples::counter_add($compteurs, $ToManyNestedControlFlow__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MultipleStatementsOnSameLine__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $BadReturnStatement__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $CompareToNull__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $Default__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $Instanceof__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MagicNumbers__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MissingDefaults__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $EmptyCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $GenericCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @controlFlow = (@ifConditions, @forLoops, @while, @matches, @try);

    # HL-1982 23/03/2022 Control flow statements "if", "for", "while", "match" and "try" should not be nested too deeply
    my $controlFlowKind = [ IfKind, ForKind, WhileKind, MatchKind, TryKind ];
    for my $controlFlow (@controlFlow) {
        if (IsKind(GetParent(GetParent($controlFlow)), FunctionDeclarationKind)
            || (IsKind(GetParent($controlFlow), MethodKind))) { # Level 0 corresponds to acco for function
            if (my @children_lev1 = GetNodesByKindList_StopAtBlockingNode($controlFlow, $controlFlowKind, $controlFlowKind)) {
                for my $children_lev1 (@children_lev1) {
                    if (my @children_lev2 = GetNodesByKindList_StopAtBlockingNode($children_lev1, $controlFlowKind, $controlFlowKind)) {
                        for my $children_lev2 (@children_lev2) {
                            if (my @children_lev3 = GetNodesByKindList_StopAtBlockingNode($children_lev2, $controlFlowKind, $controlFlowKind)) {
                                # print "Control flow statements \"if\", \"for\", \"while\", \"match\" and \"try\" should not be nested too deeply at line " . GetLine($children_lev3[0]) . "\n";
                                $nb_ToManyNestedControlFlow++;
                                Erreurs::VIOLATION($ToManyNestedControlFlow__mnemo, "Control flow statements \"if\", \"for\", \"while\", \"match\" and \"try\" should not be nested too deeply at line " . GetLine($children_lev3[0]) . ".");
                            }
                        }
                    }
                }
            }
        }
        if ((IsKind($controlFlow, MatchKind)) || (IsKind($controlFlow, TryKind))) {
            my @cases = GetNodesByKind($controlFlow, CaseKind);
            if (scalar @cases > 0) {
                for my $case (@cases) {
                    my @condNodes = GetChildrenByKind($case, ConditionKind);
                    my $caseStatement = GetStatement($condNodes[0]);
                    if (defined $caseStatement) {
                        $$caseStatement =~ s/\s+//g;
                        if ($$caseStatement =~ /^\_/m) {
                            $nb_Default++;
                        }
                    }
                }
                # HL-2027 21/04/2022 Avoid missing default
                my $lastCase = $cases[-1];
                my @condNodes = GetChildrenByKind($lastCase, ConditionKind);
                my $lastCaseStatement = GetStatement($condNodes[0]);
                if (defined $lastCaseStatement) {
                    $$lastCaseStatement =~ s/\s+//g;
                    if ($$lastCaseStatement !~ /^\_/m) {
                        # print "Missing default case at line " . GetLine($lastCase) . "\n";
                        $nb_MissingDefaults++;
                        Erreurs::VIOLATION($MissingDefaults__mnemo, "Missing default case at line " . GetLine($lastCase));
                    }
                }
                # HL-2029 22/04/2022 Avoid generic catches
                if (IsKind($controlFlow, TryKind)) {
                    my $firstCase = $cases[0];
                    my @condNodes = GetChildrenByKind($firstCase, ConditionKind);
                    my $firstCaseStatement = GetStatement($condNodes[0]);
                    my $caseStatementKind;
                    if ($$firstCaseStatement =~ /\:(.*)$/m) {
                        $caseStatementKind = $1;
                    }
                    if (defined $caseStatementKind && $caseStatementKind =~ /\b(Error|Exception|Throwable)\b/) {
                        # print "Generic catch at line " . GetLine($firstCase) . "\n";
                        $nb_GenericCatches++;
                        Erreurs::VIOLATION($GenericCatches__mnemo, "Generic catch at line " . GetLine($firstCase));
                    }
                }
            }
            else {
                # HL-2028 21/04/2022 Avoid empty catches
                if (IsKind($controlFlow, TryKind)) {
                    # print "Empty catch at line " . GetLine($controlFlow) . "\n";
                    $nb_EmptyCatches++;
                    Erreurs::VIOLATION($EmptyCatches__mnemo, "Empty catch at line " . GetLine($controlFlow));
                }
            }
        }
    }
    my $numLine = 1;
    my $integer = '\b(?:0[xX])?[0123456789ABCDEF]+[lL]?\b';
    my $decimal  = '(?:[0-9]*\.[0-9]+|[0-9]+\.)';
    while ($code =~ /(\n)|(.*\;.*)|(\bnull\b)|(\.isInstanceOf\b)|[^=\s]\s*($decimal|$integer)/g) {
        if (defined $1) {
            $numLine++;
        }
        # HL-1986 25/03/2022 Statements should be on separate lines
        elsif (defined $2) {
            my $lineCode = $2;
            $lineCode =~ s/ //g;
            my @split_line = split(/\;/, $lineCode);
            if (@split_line && scalar @split_line >= 2) {
                # print "Statements should be on separate lines at line $numLine\n";
                $nb_MultipleStatementsOnSameLine++;
                Erreurs::VIOLATION($MultipleStatementsOnSameLine__mnemo, "Statements should be on separate lines at line $numLine");
            }
        }
        # HL-2002 04/04/2022 Do not use null
        elsif (defined $3) {
            # print "Use of a null statement at line $numLine\n";
            $nb_CompareToNull++;
            Erreurs::VIOLATION($CompareToNull__mnemo, "Use of a null statement at line $numLine");
        }
        # HL-2025 20/04/2022 Avoid using .isInstanceOf()
        elsif (defined $4) {
            # print "Use of .isInstanceOf() method at line $numLine\n";
            $nb_Instanceof++;
            Erreurs::VIOLATION($Instanceof__mnemo, "Use of .isInstanceOf() method at line $numLine");
        }
        # HL-2026 21/04/2022 Avoid magic number
        elsif (defined $5 && $5 !~ /^(?:\d|0\.|\.0|0\.0|1\.0)$/) {
            # print "Magic number : $5 at line $numLine\n";
            $nb_MagicNumbers++;
            Erreurs::VIOLATION($MagicNumbers__mnemo, "Magic number : $5 at line $numLine");
        }
    }
    # HL-1992 25/03/2022 Use of return statements is not recommended
    for my $return (@returns) {
        # print "Use of return statements is not recommended at line " . GetLine($return) . "\n";
        $nb_BadReturnStatement++;
        Erreurs::VIOLATION($BadReturnStatement__mnemo, "Use of return statements is not recommended at line " . GetLine($return));
    }

    $ret |= Couples::counter_add($compteurs, $ToManyNestedControlFlow__mnemo, $nb_ToManyNestedControlFlow);
    $ret |= Couples::counter_add($compteurs, $MultipleStatementsOnSameLine__mnemo, $nb_MultipleStatementsOnSameLine);
    $ret |= Couples::counter_add($compteurs, $BadReturnStatement__mnemo, $nb_BadReturnStatement);
    $ret |= Couples::counter_add($compteurs, $CompareToNull__mnemo, $nb_CompareToNull);
    $ret |= Couples::counter_add($compteurs, $Default__mnemo, $nb_Default);
    $ret |= Couples::counter_add($compteurs, $Instanceof__mnemo, $nb_Instanceof);
    $ret |= Couples::counter_add($compteurs, $MagicNumbers__mnemo, $nb_MagicNumbers);
    $ret |= Couples::counter_add($compteurs, $MissingDefaults__mnemo, $nb_MissingDefaults);
    $ret |= Couples::counter_add($compteurs, $EmptyCatches__mnemo, $nb_EmptyCatches);
    $ret |= Couples::counter_add($compteurs, $GenericCatches__mnemo, $nb_GenericCatches);

    return $ret;
}

# sub CountItem($$$$) {
#     my ($item, $mnemo_Item, $code, $compteurs) = @_;
#     my $status = 0;
#
#     if (!defined $$code) {
#         $status |= Couples::counter_add($compteurs, $mnemo_Item, Erreurs::COMPTEUR_ERREUR_VALUE);
#         $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
#         return $status;
#     }
#
#     my $nbr_Item = () = $$code =~ /${item}/sg;
#
#     $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);
#
#     return $status;
# }

# sub CountKeywords($$$)
# {
#     my ($fichier, $vue, $compteurs) = @_ ;
#     my $status = 0;
#
#     my $code = \$vue->{'code'};
#
#     $status |= CountItem('\|\||&&', Ident::Alias_AndOr(), $code, $compteurs);
#     $status |= CountItem('\bif\b', Ident::Alias_If(), $code, $compteurs);
#     $status |= CountItem('\bwhile\b', Ident::Alias_While(), $code, $compteurs);
#     $status |= CountItem('\bfor\b', Ident::Alias_For(), $code, $compteurs);
#     $status |= CountItem('\bcase\b', Ident::Alias_Case(), $code, $compteurs);
#     $status |= CountItem('\bdefault\b', Ident::Alias_Default(), $code, $compteurs);
#     $status |= CountItem('\bswitch\b', Ident::Alias_Switch(), $code, $compteurs);
#     $status |= CountItem('\bcatch\b', Ident::Alias_Catch(), $code, $compteurs);
#
#     return $status;
# }

1;
