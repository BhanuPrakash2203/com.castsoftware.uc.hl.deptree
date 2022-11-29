package Go::CountFunction;
# les modules importes
use strict;
use warnings;

use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use Go::GoNode;
use Go::GoConfig;

use constant MAX_METHOD_PARAMETERS => 7;
use constant ARTIFACT_MAX_DEPTH => 3;

my $DEBUG = 0;

my $EmptyMethods__mnemo = Ident::Alias_EmptyMethods();
my $DeadCode__mnemo = Ident::Alias_DeadCode();
my $WithTooMuchParametersMethods__mnemo = Ident::Alias_WithTooMuchParametersMethods();
my $TooDepthArtifact__mnemo = Ident::Alias_TooDepthArtifact();
my $OverDepthAverage__mnemo = Ident::Alias_OverDepthAverage();
my $FunctionImplementations__mnemo = Ident::Alias_FunctionImplementations();
my $FunctionMethodImplementations__mnemo = Ident::Alias_FunctionMethodImplementations();
my $UnusedParameters__mnemo = Ident::Alias_UnusedParameters();
my $UnnamedData__mnemo = Ident::Alias_UnnamedData();
my $UnusedNamedReceiver__mnemo = Ident::Alias_UnusedNamedReceiver();
my $TotalParameters__mnemo = Ident::Alias_TotalParameters();

my $nb_EmptyMethods= 0;
my $nb_DeadCode= 0;
my $nb_WithTooMuchParametersMethods= 0;
my $nb_TooDepthArtifact = 0;
my $avg_OverDepthAverage = 0;
my $nb_FunctionImplementations = 0;
my $nb_FunctionMethodImplementations = 0;
my $nb_UnusedParameters = 0;
my $nb_UnnamedData = 0;
my $nb_UnusedNamedReceiver = 0;
my $nb_TotalParameters = 0;

sub CountFunction($$$) {
    my ($file, $vue, $compteurs) = @_;

    my $ret = 0;
    $nb_EmptyMethods = 0;
    $nb_DeadCode = 0;
    $nb_WithTooMuchParametersMethods = 0;
    $nb_TooDepthArtifact = 0;
    $avg_OverDepthAverage = 0;
    $nb_FunctionImplementations = 0;
    $nb_FunctionMethodImplementations = 0;
    $nb_UnusedParameters = 0;
    $nb_UnnamedData = 0;
    $nb_UnusedNamedReceiver = 0;
    $nb_TotalParameters = 0;

    my $root = \$vue->{'code'};
    my $MixBloc_NumLinesComment = $vue->{'MixBloc_NumLinesComment'};

    if ((!defined $root)) {
        $ret |= Couples::counter_add($compteurs, $EmptyMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $DeadCode__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $TooDepthArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $OverDepthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $FunctionImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $FunctionMethodImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $UnnamedData__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $UnusedNamedReceiver__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $TotalParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @funcsDeclaration = @{$vue->{'KindsLists'}->{&FunctionDeclarationKind}};
    my @funcsCall = @{$vue->{'KindsLists'}->{&FunctionCallKind}};
    my $funcs = [ @funcsDeclaration, @funcsCall ];
    my @methods = @{$vue->{'KindsLists'}->{&MethodKind}};
    $nb_FunctionImplementations = scalar @funcsDeclaration;
    $nb_FunctionMethodImplementations = scalar @methods;

    for my $func (@{$funcs}) {
        my @listAcco = GetChildrenByKind($func, AccoKind);
        my @methodEmbedded = GetChildrenByKind($func, MethodKind);

        ## FUNCTION DECLARATION
        if (IsKind($func, FunctionDeclarationKind)) {
            my $children = Lib::NodeUtil::GetChildren($listAcco[0]);
            # HL-1589 14/01/2021 Functions and methods should not be empty
            if (defined $children && scalar @{$children} == 0) {
                my $beginningLine = Lib::NodeUtil::GetLine($func);
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
                    Erreurs::VIOLATION($EmptyMethods__mnemo, "Empty function or method at line " . GetLine($func) . ".");
                }
            }

            # HL-1603 26/01/2021 Control flow statements "if", "for" and "switch" should not be nested too deeply
            my $kindNodes =[IfKind, ForKind, SwitchKind];
            my @OverDepthAverage;
            if (my @childrenNodes = GetNodesByKindList($listAcco[0], $kindNodes, 1)) {
                my $depth = 1;
                for my $child (@childrenNodes) {
                    my @result = calculate_depth($child, $kindNodes, $depth);
                    for my $result (@result) {
                        my ($kind, $line, $depth) = split(/\|/, $result);
                        if ($depth > ARTIFACT_MAX_DEPTH) {
                            # print "Control flow statements '$kind' should not be nested too deeply at line $line\n";
                            $nb_TooDepthArtifact++;
                            Erreurs::VIOLATION($TooDepthArtifact__mnemo, "Control flow statements '$kind' should not be nested too deeply at line $line");
                            push(@OverDepthAverage, $depth - ARTIFACT_MAX_DEPTH);
                        }
                    }
                }
            }
            # calculating OverDepthAverage
            if (scalar @OverDepthAverage > 0) {
                my $totalOverDepth = 0;
                for my $overDepth (@OverDepthAverage) {
                    $totalOverDepth += $overDepth;
                }
                # rounded to the nearest integer
                $avg_OverDepthAverage = sprintf "%.0f", ($totalOverDepth / scalar @OverDepthAverage);
            }

            # HL-1594 All code should be reachable
            my @expectedKinds = (ReturnKind, BreakKind, GotoKind, ContinueKind);
            my @kindList = GetNodesByKindList($listAcco[0], \@expectedKinds, 0); # flag 1 signifies we want only the first loop encountered on each path ...

            for my $node (@kindList) {
                my $nextSibling = Lib::Node::GetNextSibling($node);
                if (defined $nextSibling) {
                    # print "All code should be reachable '".GetKind($node)."' is not the final statement at line ".GetLine($node). "\n";
                    $nb_DeadCode++;
                    Erreurs::VIOLATION($DeadCode__mnemo, "All code should be reachable '".GetKind($node)."' is not the final statement at line ".GetLine($node));
                }
            }

            # HL-1599 21/01/2021 Functions should not have too many parameters
            my $params = Lib::NodeUtil::GetXKindData($func, 'parameters');
            my $paramsMeth = Lib::NodeUtil::GetXKindData($methodEmbedded[0], 'parameters');
            if ((defined $params && scalar @{$params} > MAX_METHOD_PARAMETERS)
                || (defined $paramsMeth && scalar @{$paramsMeth} > MAX_METHOD_PARAMETERS)) {
                # print "Function/method should not have too many parameters at line ". GetLine($func) ."\n";
                $nb_WithTooMuchParametersMethods++;
                Erreurs::VIOLATION($WithTooMuchParametersMethods__mnemo, "Function/method should not have too many parameters at line ".GetLine($func));
            }

            # HL-1622 29/01/2021 Avoid unused parameters
            my $codeBody = Lib::NodeUtil::GetXKindData($func, 'codeBody');
            my %nameParam;
            for my $method (@methodEmbedded) {
                my $paramsMethod = Lib::NodeUtil::GetXKindData($method, 'parameters');
                for my $paramMethod (@{$paramsMethod}) {
                    $nb_TotalParameters++;
                    my $nameArgMethod = GetName($paramMethod);
                    $nameArgMethod =~ s/\s+//g;
                    $nameParam{'method'}{$nameArgMethod} = 1 if ($nameArgMethod ne '_');
                }
            }

            for my $param (@{$params}) {
                my $nameArg = GetName($param);
                $nameArg =~ s/\s+//g;
                if (@methodEmbedded && scalar @methodEmbedded > 0) {
                    $nameParam{'receiver'}{$nameArg} = 1 if ($nameArg ne '_');
                }
                else {
                    $nb_TotalParameters++;
                    $nameParam{'function'}{$nameArg} = 1 if ($nameArg ne '_');
                }
            }

            foreach my $kindParam (keys %nameParam) {
                foreach my $nameParam (keys %{$nameParam{$kindParam}}) {
                    if ($$codeBody !~ /\b$nameParam\b/) {
                        # HL-1642 09/02/2021 Avoid unused method receiver names
                        # func is a receiver
                        if ($kindParam eq 'receiver') {
                            # print "Avoid unused method receiver names <$nameParam> in method body at line " . GetLine($func) . "\n";
                            $nb_UnusedNamedReceiver++;
                            Erreurs::VIOLATION($UnusedNamedReceiver__mnemo, "Avoid unused method receiver names <$nameParam> in method body at line " . GetLine($func));
                        }
                        # func is classic
                        else {
                            # print "Avoid unused parameters <$nameParam> for function/method at line " . GetLine($func) . "\n";
                            $nb_UnusedParameters++;
                            Erreurs::VIOLATION($UnusedParameters__mnemo, "Avoid unused parameters <$nameParam> for function/method at line " . GetLine($func));
                        }
                    }
                }
            }
        }
        ## FUNCTION CALL
        if (IsKind($func, FunctionCallKind)) {
            my $statement = GetStatement($func);
            # HL-1629 08/02/2021 Use field names to initialize structs
            if (defined $statement && $$statement =~ /^\s*\w+\s*\{([\"\w\s]\,?)+\}/m) {
                # print "Use field names to initialize structs at line " . GetLine($func) . "\n";
                $nb_UnnamedData++;
                Erreurs::VIOLATION($UnnamedData__mnemo, "Use field names to initialize structs at line " . GetLine($func));
            }
        }
    }

    $ret |= Couples::counter_add($compteurs, $EmptyMethods__mnemo, $nb_EmptyMethods );
    $ret |= Couples::counter_add($compteurs, $DeadCode__mnemo, $nb_DeadCode );
    $ret |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods__mnemo, $nb_WithTooMuchParametersMethods );
    $ret |= Couples::counter_add($compteurs, $TooDepthArtifact__mnemo, $nb_TooDepthArtifact );
    $ret |= Couples::counter_add($compteurs, $OverDepthAverage__mnemo, $avg_OverDepthAverage );
    $ret |= Couples::counter_add($compteurs, $FunctionImplementations__mnemo, $nb_FunctionImplementations );
    $ret |= Couples::counter_add($compteurs, $FunctionMethodImplementations__mnemo, $nb_FunctionMethodImplementations );
    $ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, $nb_UnusedParameters );
    $ret |= Couples::counter_update($compteurs, $UnnamedData__mnemo, $nb_UnnamedData );
    $ret |= Couples::counter_add($compteurs, $UnusedNamedReceiver__mnemo, $nb_UnusedNamedReceiver );
    $ret |= Couples::counter_add($compteurs, $TotalParameters__mnemo, $nb_TotalParameters );

    return $ret;
}

# RECURSIVE SUB
sub calculate_depth($$$);
sub calculate_depth($$$) {
    my $currentChild = shift;
    my $kindNodes = shift;
    my $depth = shift;
    my @result= ();

    my @childrenSubNodes = GetNodesByKindList($currentChild, $kindNodes, 1);
    # for loop of children which type is equals to $kindNodes
    # (i.e. if, else, while, for, case, try...)
    for my $childrenSubNode (@childrenSubNodes) {
        my $depth_child = $depth;
        # if at least kind of a child is equals to $kindNodes
        if (GetNodesByKindList($childrenSubNode, $kindNodes, 1)) {
            # level down
            $depth++;
            push(@result, calculate_depth($childrenSubNode,$kindNodes, $depth));
        }
        # if no kind of child is equals to $kindNodes and depth > ARTIFACT_MAX_DEPTH
        else {
            $depth++;
            if ($depth > ARTIFACT_MAX_DEPTH) {
                # push violation
                push(@result, GetKind($childrenSubNode)."|".GetLine($childrenSubNode)."|$depth");
            }
        }
        # continue for loop with origin level
        $depth = $depth_child;
    }

    return @result;
}

1;
