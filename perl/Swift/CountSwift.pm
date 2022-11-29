package Swift::CountSwift;
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

my $IncrDecrOperatorComplexUses__mnemo = Ident::Alias_BadIncDecUse();
my $UnexpectedCast__mnemo = Ident::Alias_UnexpectedCast();
my $ToManyNestedControlFlow__mnemo = Ident::Alias_ToManyNestedControlFlow();
my $DeadCode__mnemo = Ident::Alias_DeadCode();

my $nb_IncrDecrOperatorComplexUses= 0;
my $nb_UnexpectedCast= 0;
my $nb_ToManyNestedControlFlow= 0;
my $nb_DeadCode= 0;

sub CountSwift($$$)
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_IncrDecrOperatorComplexUses = 0;
    $nb_UnexpectedCast = 0;
    $nb_ToManyNestedControlFlow = 0;
    $nb_DeadCode = 0;

    my $code =  $vue->{'code'} ;
    my @ifConditions = @{$vue->{'KindsLists'}->{'If'}};
    my @forLoops = @{$vue->{'KindsLists'}->{'For'}};
    my @while = @{$vue->{'KindsLists'}->{'While'}};
    my @repeatWhile = @{$vue->{'KindsLists'}->{'RepeatWhile'}};
    my @switch = @{$vue->{'KindsLists'}->{'Switch'}};
    my @return = @{$vue->{'KindsLists'}->{'Return'}};
    my @break = @{$vue->{'KindsLists'}->{'Break'}};
    my @continue = @{$vue->{'KindsLists'}->{'Continue'}};
    my @fallthrough = @{$vue->{'KindsLists'}->{'Fallthrough'}};

    if ( ! defined $code  )
    {
        $ret |= Couples::counter_add($compteurs, $IncrDecrOperatorComplexUses__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $UnexpectedCast__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $ToManyNestedControlFlow__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $DeadCode__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }


    my @controlFlow = (@ifConditions, @forLoops, @while, @repeatWhile, @switch);
    my @jumpStatements = (@return, @break, @continue, @fallthrough);

    my $numLine = 1;
    while ($code =~ /(\n)|(\bas\!)|(.+)(?:[+-]{2}\w+\b|\b\w+[+-]{2})(.*)|[^\n]/g) {
        my $previousPatt = $3;
        my $followingPatt = $4;
        if (defined $1) {
            $numLine++;
        }
        # HL-1099: Force casts should not be used
        elsif (defined $2) {
            $nb_UnexpectedCast++;
            # print "Force casts should not be used at line $numLine\n";
            Erreurs::VIOLATION($UnexpectedCast__mnemo, "Force casts should not be used at line $numLine");
        }
		# HL-1097: Increment (++) and decrement (--) operators should not be used in a method call or mixed with other operators in an expression
		else {
			if (defined $previousPatt && $previousPatt !~ /^\s+$/m && $previousPatt !~ /\=\s*$/m) {
                $nb_IncrDecrOperatorComplexUses++;
				# print "Increment (++) and decrement (--) operators should not be used in a method call or mixed with other operators in an expression at line $numLine\n";
				Erreurs::VIOLATION($IncrDecrOperatorComplexUses__mnemo, "Increment (++) and decrement (--) operators should not be used in a method call or mixed with other operators in an expression at line $numLine.");
			}
			elsif (defined $followingPatt && $followingPatt !~ /^\s+$/m && $followingPatt !~ /^\;\s*$/m) {
                $nb_IncrDecrOperatorComplexUses++;
				# print "Increment (++) and decrement (--) operators should not be used in a method call or mixed with other operators in an expression at line $numLine\n";
				Erreurs::VIOLATION($IncrDecrOperatorComplexUses__mnemo, "Increment (++) and decrement (--) operators should not be used in a method call or mixed with other operators in an expression at line $numLine.");
			}
		}
    }

    # HL-1094 : Control flow statements "if", "for in", "while", "repeat while" and "switch" should not be nested too deeply
    my $controlFlowKind = [IfKind, ForKind, WhileKind, RepeatKind, SwitchKind];
    for my $controlFlow (@controlFlow) {
        if (IsKind (GetParent ($controlFlow), RootKind)
            || IsKind (GetParent(GetParent ($controlFlow)), FunctionDeclarationKind)) {  # Level 0 : for FunctionDeclarationKind the first child is acco

            if (my @children_lev1 = GetNodesByKindList_StopAtBlockingNode($controlFlow,$controlFlowKind, $controlFlowKind)) {
                for my $children_lev1 (@children_lev1) {
                    if (my @children_lev2 = GetNodesByKindList_StopAtBlockingNode($children_lev1,$controlFlowKind, $controlFlowKind)) {
                        for my $children_lev2 (@children_lev2) {
                            if (my @children_lev3 = GetNodesByKindList_StopAtBlockingNode($children_lev2, $controlFlowKind,$controlFlowKind)) {
                                # print "Control flow statements \"if\", \"for in\", \"while\", \"repeat while\" and \"switch\" should not be nested too deeply at line " . GetLine ($children_lev3[0])."\n";
                                $nb_ToManyNestedControlFlow++;
                                Erreurs::VIOLATION($ToManyNestedControlFlow__mnemo, "Control flow statements \"if\", \"for in\", \"while\", \"repeat while\" and \"switch\" should not be nested too deeply at line ".GetLine ($children_lev3[0]).".");
                            }
                        }
                    }
                }
            }
        }
    }

    # HL-1120 All code should be reachable
    for my $jumpStatement (@jumpStatements) {
        my $parentNode = GetParent($jumpStatement);
        my $children =  GetChildren($parentNode);
        my $lastChild = $children->[-1];
        if (!IsKind($lastChild, ReturnKind) && !IsKind($lastChild, BreakKind)
            && !IsKind($lastChild, ContinueKind) && !IsKind($lastChild, FallthroughKind)) {
            # print "All code should be reachable at line " . GetLine ($lastChild)."\n";
            $nb_DeadCode++;
            Erreurs::VIOLATION($DeadCode__mnemo, "All code should be reachable at line ".GetLine ($lastChild).".");
        }
    }

    $ret |= Couples::counter_add($compteurs, $IncrDecrOperatorComplexUses__mnemo, $nb_IncrDecrOperatorComplexUses );
    $ret |= Couples::counter_add($compteurs, $UnexpectedCast__mnemo, $nb_UnexpectedCast );
    $ret |= Couples::counter_add($compteurs, $ToManyNestedControlFlow__mnemo, $nb_ToManyNestedControlFlow );
    $ret |= Couples::counter_add($compteurs, $DeadCode__mnemo, $nb_DeadCode );

    return $ret;
}

sub CountItem($$$$)
{
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

sub CountKeywords($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $code = \$vue->{'code'};

    $status |= CountItem('\|\||&&', Ident::Alias_AndOr(), $code, $compteurs);
    $status |= CountItem('\bif\b', Ident::Alias_If(), $code, $compteurs);
    $status |= CountItem('\bwhile\b', Ident::Alias_While(), $code, $compteurs);
    $status |= CountItem('\bfor\b', Ident::Alias_For(), $code, $compteurs);
    $status |= CountItem('\bcase\b', Ident::Alias_Case(), $code, $compteurs);
    $status |= CountItem('\bdefault\b', Ident::Alias_Default(), $code, $compteurs);
    $status |= CountItem('\bswitch\b', Ident::Alias_Switch(), $code, $compteurs);
    $status |= CountItem('\bcatch\b', Ident::Alias_Catch(), $code, $compteurs);

    return $status;
}

1;
