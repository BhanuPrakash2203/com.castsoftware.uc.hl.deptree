package Scala::CountFunction;
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
use constant MAX_PARAMETERS => 4;

my $EmptyMethods__mnemo = Ident::Alias_EmptyMethods();
my $DeadCode__mnemo = Ident::Alias_DeadCode();
my $WithTooMuchParametersMethods__mnemo = Ident::Alias_WithTooMuchParametersMethods();
my $UnusedParameters__mnemo = Ident::Alias_UnusedParameters();
my $TotalParameters__mnemo = Ident::Alias_TotalParameters();
my $MethodImplementations__mnemo = Ident::Alias_MethodImplementations();

my $nb_EmptyMethods = 0;
my $nb_DeadCode = 0;
my $nb_WithTooMuchParametersMethods = 0;
my $nb_UnusedParameters = 0;
my $nb_TotalParameters = 0;
my $nb_MethodImplementations = 0;

sub CountFunction($$$) {
    my ($file, $vue, $compteurs) = @_;

    my $ret = 0;
    $nb_EmptyMethods = 0;
    $nb_DeadCode = 0;
    $nb_WithTooMuchParametersMethods = 0;
    $nb_UnusedParameters = 0;
    $nb_TotalParameters = 0;
    $nb_MethodImplementations = 0;
    my %lineDetected;

    my $root = \$vue->{'code'};
    my $MixBloc_NumLinesComment = $vue->{'MixBloc_NumLinesComment'};

    if ((!defined $root)) {
        $ret |= Couples::counter_add($compteurs, $EmptyMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $DeadCode__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $TotalParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MethodImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @methods = @{$vue->{'KindsLists'}->{&MethodKind}};
    my @functions = @{$vue->{'KindsLists'}->{&FunctionDeclarationKind}};
    my $kinds = [ @methods, @functions ];
    for my $functionOrMethod (@{$kinds}) {
        ## METHODS
        if (IsKind($functionOrMethod, MethodKind)) {
            my $children = Lib::NodeUtil::GetChildren($functionOrMethod);
            # HL-1974 21/03/2022 Methods should not be empty
            my $bool_empty_method = 1;
            for my $child (@{$children}) {
                if (!IsKind($child, ParamKind) && !IsKind($child, ReturnTypeKind)) {
                    $bool_empty_method = 0;
                    last;
                }
            }

            if ($bool_empty_method == 1) {
                my $beginningLine = Lib::NodeUtil::GetLine($functionOrMethod);
                my $endingLine = Lib::NodeUtil::GetEndline($functionOrMethod);

                my $boolComment = 0;
                for (my $numLine = $beginningLine; $numLine <= $endingLine; $numLine++) {
                    if (exists $MixBloc_NumLinesComment->{$numLine}) {
                        $boolComment = 1;
                    }
                }
                if ($boolComment == 0) {
                    # Empty method body => 0 comment & instruction
                    $nb_EmptyMethods++;
                    Erreurs::VIOLATION($EmptyMethods__mnemo, "Empty method at line " . GetLine($functionOrMethod) . ".");
                }
            }
        }

        ## FUNCTIONS
        #elsif (IsKind($functionOrMethod, FunctionDeclarationKind)) {
        #}

        ## BOTH METHODS/FUNCTIONS
        # HL-1976 22/03/2022 All code should be reachable
        my @returnNodes = GetNodesByKindList($functionOrMethod, [ ReturnKind ], 1); # flag 1 signifies we want only the first loop encountered on each path ...
        for my $node (@returnNodes) {
            my $nextSibling = Lib::Node::GetNextSibling($node);
            my $line = GetLine($nextSibling);
            if (defined $nextSibling && !exists $lineDetected{GetLine($nextSibling)}) {
                # print "All code should be reachable '" . GetKind($node) . "' is not the final statement at line " . GetLine($node) . "\n";
                $nb_DeadCode++;
                $lineDetected{GetLine($nextSibling)} = 1;
                Erreurs::VIOLATION($DeadCode__mnemo, "All code should be reachable '" . GetKind($node) . "' is not the final statement at line " . GetLine($node));
            }
        }
        # HL-1976 23/03/2022 Functions/methods should not have too many parameters
        my @parameterNodes = GetChildrenByKind($functionOrMethod, ParamKind);
        if (scalar @parameterNodes > MAX_PARAMETERS) {
            # print "Function/method should not have too many parameters at line ". GetLine($functionOrMethod) ."\n";
            $nb_WithTooMuchParametersMethods++;
            Erreurs::VIOLATION($WithTooMuchParametersMethods__mnemo, "Function/method should not have too many parameters at line " . GetLine($functionOrMethod));
        }
        for my $param (@parameterNodes) {
            $nb_TotalParameters++;
            # HL-1981 23/03/2022 Unused function parameters should be removed
            my $codeBody = Lib::NodeUtil::GetXKindData($functionOrMethod, 'codeBody');
            my $nameParam = GetName($param);
            if (defined $nameParam) {
                $nameParam =~ s/\s+//g;
                if (defined $codeBody && $$codeBody !~ /\b$nameParam\b/) {
                    # print "Avoid unused parameters <$nameParam> for function/method at line " . GetLine($functionOrMethod) . "\n";
                    $nb_UnusedParameters++;
                    Erreurs::VIOLATION($UnusedParameters__mnemo, "Avoid unused parameters <$nameParam> for function/method at line " . GetLine($functionOrMethod));
                }
            }
        }
    }

    ## METRICS
    $nb_MethodImplementations = scalar(@methods);

    $ret |= Couples::counter_add($compteurs, $EmptyMethods__mnemo, $nb_EmptyMethods);
    $ret |= Couples::counter_add($compteurs, $DeadCode__mnemo, $nb_DeadCode);
    $ret |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods__mnemo, $nb_WithTooMuchParametersMethods);
    $ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, $nb_UnusedParameters);
    $ret |= Couples::counter_add($compteurs, $TotalParameters__mnemo, $nb_TotalParameters);
    $ret |= Couples::counter_add($compteurs, $MethodImplementations__mnemo, $nb_MethodImplementations);

    return $ret;
}

1;
