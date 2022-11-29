package JS::CountCondition;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use JS::JSNode;
use JS::Identifiers;

my $IDENTIFIER = JS::Identifiers::getIdentifiersPattern();
my $IDENT_CHAR = JS::Identifiers::getIdentifiersCharacters();

my $THRESHOLD_COMPLEX = 4;

my $MissingIdenticalOperator__mnemo = Ident::Alias_MissingIdenticalOperator();
my $ComplexConditions__mnemo = Ident::Alias_ComplexConditions();
my $AssignmentsInConditionalExpr__mnemo = Ident::Alias_AssignmentsInConditionalExpr();
my $Conditions__mnemo = Ident::Alias_Conditions();

my $nb_MissingIdenticalOperator = 0;
my $nb_ComplexConditions = 0;
my $nb_AssignmentsInConditionalExpr = 0;
my $nb_Conditions = 0;

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

  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $MissingIdenticalOperator__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $AssignmentsInConditionalExpr__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Conditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @conds = GetNodesByKind($root, CondKind);

  $nb_Conditions = scalar @conds;

  for my $cond (@conds) {
	  #my $stmt = GetStatement($cond);
    my $flatCond = Lib::NodeUtil::GetKindData($cond);
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

    $nb_AssignmentsInConditionalExpr += () = $$flatCond =~ /(?:[^=!><]=[^=]|>>>=|>>=|<<=)/sg;
#print "AssignmentsInConditionalExpr = $nb_AssignmentsInConditionalExpr\n";

  }
  $ret |= Couples::counter_add($compteurs, $MissingIdenticalOperator__mnemo, $nb_MissingIdenticalOperator );
  $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, $nb_ComplexConditions );
  $ret |= Couples::counter_add($compteurs, $AssignmentsInConditionalExpr__mnemo, $nb_AssignmentsInConditionalExpr );
  $ret |= Couples::counter_add($compteurs, $Conditions__mnemo, $nb_Conditions );

  return $ret;
}


1;
