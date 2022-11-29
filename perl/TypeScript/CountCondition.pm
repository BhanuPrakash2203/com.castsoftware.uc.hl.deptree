package TypeScript::CountCondition;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use TypeScript::TypeScriptNode;
use TypeScript::Identifiers;

my $IDENTIFIER = TypeScript::Identifiers::getIdentifiersPattern();
my $IDENT_CHAR = TypeScript::Identifiers::getIdentifiersCharacters();

my $THRESHOLD_COMPLEX = 4;

my $DEBUG = 0;
my $MissingIdenticalOperator__mnemo = Ident::Alias_MissingIdenticalOperator();
my $ComplexConditions__mnemo = Ident::Alias_ComplexConditions();
my $AssignmentsInConditionalExpr__mnemo = Ident::Alias_AssignmentsInConditionalExpr();
my $Conditions__mnemo = Ident::Alias_Conditions();
my $OnlyRethrowingCatches__mnemo = Ident::Alias_OnlyRethrowingCatches();
my $OutOfFinallyJumps__mnemo = Ident::Alias_OutOfFinallyJumps();
my $TernaryOperators__mnemo = Ident::Alias_TernaryOperators();

my $nb_MissingIdenticalOperator = 0;
my $nb_ComplexConditions = 0;
my $nb_AssignmentsInConditionalExpr = 0;
my $nb_Conditions = 0;
my $nb_OnlyRethrowingCatches = 0;
my $nb_OutOfFinallyJumps = 0;
my $nb_TernaryOperators = 0;

my $ComparisonOp = '<=|>=|<|>|===|==|!==|!=';
my $LogicalOp = '&&|\|\|';

sub isFalsy($$) {
  my $value = shift;
  my $view = shift;
  if ($value =~ /\b(?:undefined|false|0)\b|\[\s*\]/) {
#print "$value ==> FALSY !!!\n";
    return 1;
  }
# ---------------------------------------------------------
# useless since tests are using flat conditions expression 
# ---------------------------------------------------------
#  elsif ($value =~ /\[__(TAB\d+)__\]/) {
#    # get the name of the tab.
#    my $name = $1;
#    my $root = $view->{'structured_code'};
#    my @tabs = GetNodesByKind($root, BracketKind);
#    # search the tab corresponding to the name ...
#    for my $tab (@tabs) {
#      if (GetName($tab) eq $name) {
#	# If the content of the tab is empty (only spaces), the it is a falsy value !
#        if (${GetStatement($tab)} =~ /^\s*$/sm) {
#print "$value ==> FALSY !!!\n";
#          return 1;
#	}
#	else {
#          last;
#	}
#      }
#    }
#  }
  elsif ($value =~ /\bCHAINE_\d+\b/) {
    my $strings = $view->{'HString'};
    if (defined $strings) {
      my $string_value = $strings->{$value};
      if ( (defined $string_value) &&
	   (($string_value eq '""') || ($string_value eq "''")) ) {
#print "$string_value ==> FALSY !!!\n";
        return 1;
      }
    }
  }
  return 0;
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


sub CountCondition($$$) 
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_MissingIdenticalOperator = 0;
    $nb_ComplexConditions = 0;
    $nb_AssignmentsInConditionalExpr = 0;
    $nb_OnlyRethrowingCatches = 0;
    $nb_OutOfFinallyJumps = 0;
    $nb_TernaryOperators = 0;

    my $root =  $vue->{'structured_code'} ;

    if ( ! defined $root )
    {
        $ret |= Couples::counter_add($compteurs, $MissingIdenticalOperator__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $AssignmentsInConditionalExpr__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $Conditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $OnlyRethrowingCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $OutOfFinallyJumps__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $TernaryOperators__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @conds = GetNodesByKind($root, CondKind);

    $nb_Conditions = scalar @conds;

    for my $cond (@conds) {
	  #my $stmt = GetStatement($cond);
        my $flatCond = Lib::NodeUtil::GetXKindData($cond, 'flatexpr');
#print "\nCONDITION : $$flatCond\n";

    if ( $$flatCond !~ /__ternary_(\d+)__/) {

        if ($$flatCond !~ /$ComparisonOp|$LogicalOp/s) {
            $nb_MissingIdenticalOperator++;
        #print "====> Missing identical Op (no OP) !!\n";
        }
        else {
            my $falsyPattern = '\w+|\[\s*\]';
            while ( $$flatCond =~ /(?:($falsyPattern)|[^!=])\s*(?:==|!=)\s*(?:($falsyPattern)|[^!=])/sg) {
                if ( ((defined $1) && (isFalsy($1, $vue))) ||
                   ((defined $2) && (isFalsy($2, $vue))) ) {
                    $nb_MissingIdenticalOperator++;
                #print "====> Missing identical Op !!\n";
                }
            }
        }
    }

        pos($$flatCond) = 0;
        # remove "init" and "inc" for clause.
    #    if (IsKind(GetParent($cond), ForKind)) {
    #      $$flatCond =~ s/^[^;]*;//sm;
    #      $$flatCond =~ s/;[^;]*$//sm;
    #    }

        if (isComplex($flatCond)) {
          $nb_ComplexConditions++;
        }

        my $nbAss = () = $$flatCond =~ /(?:[^=!><]=[^=]|>>>=|>>=|<<=)/sg;
        if ($nbAss) {
			Erreurs::VIOLATION($AssignmentsInConditionalExpr__mnemo, "$nbAss assignment(s) found in conditional expression at line ".(GetLine($cond)||"??"));
			$nb_AssignmentsInConditionalExpr += $nbAss;
		}
    }
    
    # HL-834 11/04/2019 "catch" clauses should do more than rethrow
    my @catch = GetNodesByKind($root, CatchKind);
    for my $catch (@catch) {

        my $cond = Lib::NodeUtil::GetChildren($catch)->[0];
        my $acco = Lib::NodeUtil::GetChildren($catch)->[1];
        my $childCatch = Lib::NodeUtil::GetChildren($acco);
        
        my $stmt_cond = ${GetStatement($cond)};
        $stmt_cond =~ s/\s+//g;
        
        if ( defined $childCatch and scalar(@$childCatch) == 1 and GetKind($childCatch->[0]) eq ThrowKind )
        {
            my $stmt_throw = ${GetStatement($childCatch->[0])};
            $stmt_throw =~ s/\s+//g;
            
            if ($stmt_cond eq $stmt_throw)
            {
                print "Catch clause contains only one throw instruction at line ".GetLine($childCatch->[0])."\n" if $DEBUG;
                $nb_OnlyRethrowingCatches++;
                Erreurs::VIOLATION($OnlyRethrowingCatches__mnemo, "Catch clause contains only one throw instruction at line ".GetLine($childCatch->[0]));
            }
       }
    }
    
    # HL-848 17/04/2019 Jump statements should not occur in "finally" blocks
    my @finally = GetNodesByKind($root, FinallyKind);
    for my $final (@finally) {
    
        my @jumpStatement = Lib::NodeUtil::GetNodesByKindList($final, [ReturnKind, BreakKind, ThrowKind]);
     
        if (defined scalar (@jumpStatement) and scalar (@jumpStatement) > 0)
        {
            for my $jump (@jumpStatement)
            {
                print "Jump statements should not occur in \"finally\" blocks at line ".GetLine($jump)."\n" if $DEBUG;
                $nb_OutOfFinallyJumps++;
                Erreurs::VIOLATION($OutOfFinallyJumps__mnemo, "Jump statements should not occur in \"finally\" blocks at line ".GetLine($jump));
            }
        }
    }
  
	# HL-972 05/08/2019 Avoid ternary operator
    my @ternaryConds = GetNodesByKind($root, TernaryKind);
    for my $ternary (@ternaryConds) {
		print "Ternary operators are not recommended at line ".GetLine($ternary)."\n" if $DEBUG;
		$nb_TernaryOperators++;
		Erreurs::VIOLATION($TernaryOperators__mnemo, "Ternary operators are not recommended at line ".GetLine($ternary));
    }

    $ret |= Couples::counter_add($compteurs, $MissingIdenticalOperator__mnemo, $nb_MissingIdenticalOperator );
    $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, $nb_ComplexConditions );
    $ret |= Couples::counter_add($compteurs, $AssignmentsInConditionalExpr__mnemo, $nb_AssignmentsInConditionalExpr );
    $ret |= Couples::counter_add($compteurs, $Conditions__mnemo, $nb_Conditions );
    $ret |= Couples::counter_add($compteurs, $OnlyRethrowingCatches__mnemo, $nb_OnlyRethrowingCatches );
    $ret |= Couples::counter_add($compteurs, $OutOfFinallyJumps__mnemo, $nb_OutOfFinallyJumps );
    $ret |= Couples::counter_add($compteurs, $TernaryOperators__mnemo, $nb_TernaryOperators );

    return $ret;
}


1;
