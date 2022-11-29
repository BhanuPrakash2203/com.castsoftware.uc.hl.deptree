package Swift::CountFunction;
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

my $MethodImplementations__mnemo = Ident::Alias_MethodImplementations();
my $FunctionImplementations__mnemo = Ident::Alias_FunctionImplementations();
my $FunctionExpressions__mnemo = Ident::Alias_FunctionExpressions();
my $EmptyMethods__mnemo = Ident::Alias_EmptyMethods();
my $MultipleReturnFunctionsMethods__mnemo = Ident::Alias_MultipleReturnFunctionsMethods();
my $WithTooMuchParametersMethods__mnemo = Ident::Alias_WithTooMuchParametersMethods();
my $BadReturnStatement__mnemo = Ident::Alias_BadReturnStatement();
my $UnusedParameters__mnemo = Ident::Alias_UnusedParameters();
my $ImplicitReturn__mnemo = Ident::Alias_ImplicitReturn();
my $NestedClosure__mnemo = Ident::Alias_NestedClosure();
my $MisplacedParam__mnemo = Ident::Alias_MisplacedParam();

my $nb_MethodImplementations= 0;
my $nb_FunctionImplementations= 0;
my $nb_FunctionExpressions= 0;
my $nb_EmptyMethods= 0;
my $nb_MultipleReturnFunctionsMethods= 0;
my $nb_WithTooMuchParametersMethods= 0;
my $nb_BadReturnStatement= 0;
my $nb_UnusedParameters= 0;
my $nb_ImplicitReturn= 0;
my $nb_NestedClosure= 0;
my $nb_MisplacedParam= 0;

sub CountFunction($$$) {
    my ($file, $vue, $compteurs) = @_;

    my $ret = 0;
    $nb_EmptyMethods = 0;
    $nb_MultipleReturnFunctionsMethods = 0;
    $nb_WithTooMuchParametersMethods = 0;
    $nb_BadReturnStatement = 0;
    $nb_UnusedParameters = 0;
    $nb_ImplicitReturn = 0;
    $nb_NestedClosure = 0;
    $nb_MisplacedParam = 0;
    $nb_MethodImplementations= 0;
    $nb_FunctionImplementations = 0;
    $nb_FunctionExpressions = 0;

    my $root = \$vue->{'code'};
    my $MixBloc_NumLinesComment = $vue->{'MixBloc_NumLinesComment'};

    if ((!defined $root)) {
        $ret |= Couples::counter_add($compteurs, $EmptyMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MultipleReturnFunctionsMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $BadReturnStatement__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $ImplicitReturn__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $NestedClosure__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MisplacedParam__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MethodImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $FunctionImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $FunctionExpressions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
    my @funcs = @{$vue->{'KindsLists'}->{'FunctionDeclaration'}};
    my @closures = @{$vue->{'KindsLists'}->{'Closure'}};
    my @methods = @{$vue->{'KindsLists'}->{'Method'}};
    my @functionsAll = (@funcs, @closures, @methods);

    $nb_MethodImplementations += scalar @methods;
    $nb_FunctionImplementations += scalar @funcs;
    $nb_FunctionExpressions += scalar @closures;

    for my $func (@functionsAll) {
        my @listAcco = GetChildrenByKind($func, AccoKind);

        ## FUNCTION DECLARATION
        if (IsKind($func, FunctionDeclarationKind) || IsKind($func, MethodKind)) {
            my $children = Lib::NodeUtil::GetChildren($listAcco[0]);
            # HL-1089 : Functions and closures should not be empty
            if (defined $children && scalar @{$children} == 0) {
                my $beginningLine = Lib::NodeUtil::GetLine($listAcco[0]);
                my $endingLine = Lib::NodeUtil::GetEndline($listAcco[0]);

                my $boolComment = 0;
                for (my $numLine = $beginningLine; $numLine <= $endingLine; $numLine++) {
                    if (exists $MixBloc_NumLinesComment->{$numLine}) {
                        $boolComment = 1;
                    }
                }
                if ($boolComment == 0) {
                    # Empty function body => 0 comment & instruction
                    $nb_EmptyMethods++;
                    Erreurs::VIOLATION($EmptyMethods__mnemo, "Empty function at line " . GetLine($func) . ".");
                }
            }
            # HL-1101 : Functions should not contain too many return statements
            my @KindList = (ReturnKind);
            my @listReturn = GetNodesByKindList($listAcco[0], \@KindList, 0); # flag 1 signifies we want only the first loop encountered on each path ...
            if (scalar @listReturn > 3) {
                # print "Functions should not contain too many return statements at line ".GetLine($func)."\n";
                $nb_MultipleReturnFunctionsMethods++;
                Erreurs::VIOLATION($MultipleReturnFunctionsMethods__mnemo, "Functions should not contain too many return statements at line " . GetLine($func) . ".");
            }
            # HL-1118 Functions should not return constants
            for my $return (@listReturn) {
                my $stmt = GetStatement($return);
                if ($$stmt =~ /^\s*[0-9]+\s*$/m) {
                    # print "Functions should not return constants at line ".GetLine($return)."\n";
                    $nb_BadReturnStatement++;
                    Erreurs::VIOLATION($BadReturnStatement__mnemo, "Functions should not return constants at line " . GetLine($return) . ".");
                }
            }
            # HL-1102 : Functions should not have too many parameters
            my $params = Lib::NodeUtil::GetXKindData($func, 'parameters');
            if (defined $params && scalar @{$params} > 4) {
                # print "Functions should not have too many parameters at line ".GetLine($func)."\n";
                $nb_WithTooMuchParametersMethods++;
                Erreurs::VIOLATION($WithTooMuchParametersMethods__mnemo, "Functions should not have too many parameters at line " . GetLine($func) . ".");
            }
            # HL-1116 : Unused function parameters should be removed
            my @nameParam;
            my @typeParam;
            for my $param (@{$params}) {
                if (defined $param->[0]) {
                    push (@nameParam, $param->[4]);
                }
                if (defined $param->[1]) {
                    push (@typeParam, $param->[1]);
                }
            }
            # HL-1100 Function type parameters should come at the end of the parameter list
            for (my $position = 0; $position < (scalar @typeParam) - 1; $position++) {
                if ($typeParam[$position] =~ /\-\>/) {
                    # print "Function type of parameter \"$nameParam[$position]\" should come at the end of the parameter list at line ".GetLine($func)."\n";
                    $nb_MisplacedParam++;
                    Erreurs::VIOLATION($MisplacedParam__mnemo, "Function type of parameter \"$nameParam[$position]\" should come at the end of the parameter list at line " . GetLine($func) . ".");
				}
            }

            my $modifier = Lib::NodeUtil::GetXKindData($func, 'modifiers');
            my $codeBody = Lib::NodeUtil::GetXKindData($func, 'code_body');

            for my $nameParam (@nameParam) {
                $nameParam = quotemeta($nameParam); # Avoid regex error (e.g. function type as ()->Void)
                if ($$codeBody !~ /\b$nameParam\b/) {
                    if (defined $modifier && $modifier eq 'override') {
                        # HL-1116 : Do an exception...
                    }
                    else {
                        # print "Unused function parameter \"$nameParam\" should be removed at line " . GetLine($func) . "\n";
                        $nb_UnusedParameters++;
                        Erreurs::VIOLATION($UnusedParameters__mnemo, "Unused function parameter \"$nameParam\" should be removed at line " . GetLine($func) . ".");
                    }
                }
            }
        }

        ## CLOSURE
        if (IsKind($func, ClosureKind)) {
            my $childrenClosure = Lib::NodeUtil::GetChildren($func);
            # HL-1119 : "return" should be omitted from single-expression closures
            if (scalar @{$childrenClosure} == 1) {
                if (IsKind($childrenClosure->[0], ReturnKind)) {
                    # print "\"return\" should be omitted from single-expression closures at line " . GetLine($func) . "\n";
                    $nb_ImplicitReturn++;
                    Erreurs::VIOLATION($ImplicitReturn__mnemo, "\"return\" should be omitted from single-expression closures at line " . GetLine($func) . ".");
                }
            }
            # HL-1089 : Functions and closures should not be empty
            # closure (not present in a function declaration)
            if (GetKind(GetParent($func)) ne FunctionDeclarationKind) {
                if (scalar @{$childrenClosure} == 0) {
                    $nb_EmptyMethods++;
                    Erreurs::VIOLATION($EmptyMethods__mnemo, "Empty closure at line " . GetLine($func) . ".");
                }
            }
            # HL-1098 : Closure expressions should not be nested too deeply
            my @closures_lev1 = GetNodesByKindList($func, [ClosureKind], 1);
            for my $closures_lev1 (@closures_lev1) {
                if (GetNodesByKindList($closures_lev1, [ClosureKind], 1)) {
                    # print "Closure expressions should not be nested too deeply at line " . GetLine($func) . "\n";
                    $nb_NestedClosure++;
                    Erreurs::VIOLATION($NestedClosure__mnemo, "Closure expressions should not be nested too deeply at line " . GetLine($func) . ".");
                }
            }
        }
    }

    $ret |= Couples::counter_add($compteurs, $EmptyMethods__mnemo, $nb_EmptyMethods );
    $ret |= Couples::counter_add($compteurs, $MultipleReturnFunctionsMethods__mnemo, $nb_MultipleReturnFunctionsMethods );
    $ret |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods__mnemo, $nb_WithTooMuchParametersMethods );
    $ret |= Couples::counter_add($compteurs, $BadReturnStatement__mnemo, $nb_BadReturnStatement );
    $ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, $nb_UnusedParameters );
    $ret |= Couples::counter_add($compteurs, $ImplicitReturn__mnemo, $nb_ImplicitReturn );
    $ret |= Couples::counter_add($compteurs, $NestedClosure__mnemo, $nb_NestedClosure );
    $ret |= Couples::counter_add($compteurs, $MisplacedParam__mnemo, $nb_MisplacedParam );
    $ret |= Couples::counter_add($compteurs, $MethodImplementations__mnemo, $nb_MethodImplementations );
    $ret |= Couples::counter_add($compteurs, $FunctionImplementations__mnemo, $nb_FunctionImplementations );
    $ret |= Couples::counter_add($compteurs, $FunctionExpressions__mnemo, $nb_FunctionExpressions );

    return $ret;
}



1;
