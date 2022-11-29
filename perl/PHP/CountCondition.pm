package PHP::CountCondition;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use PHP::PHPNode;

my $nb_MaxNestedLoops = 4;
my $COMPLEX_CONDITION_THRESHOLD = 4;

my $MissingIdenticalOperator__mnemo = Ident::Alias_MissingIdenticalOperator();
my $UnconditionalCondition__mnemo = Ident::Alias_UnconditionalCondition();
my $ComplexConditions__mnemo = Ident::Alias_ComplexConditions();
my $BadVariableDefinitionCheck__mnemo = Ident::Alias_BadVariableDefinitionCheck();

my $nb_MissingIdenticalOperator = 0;
my $nb_UnconditionalCondition = 0;
my $nb_ComplexConditions = 0;
my $nb_BadVariableDefinitionCheck = 0;


sub isComplexCondition($) {
  my $cond = shift;
  my $nb_AND = () = $$cond =~ /&&|\band\b/gi ;
  my $nb_OR = () = $$cond =~ /\|\||\bor\b/gi ;
  my $nb_XOR = () = $$cond =~ /\bxor\b/gi ;

  my $nb_diff_op = 0;
  if ( $nb_AND ) { $nb_diff_op++; }
  if ( $nb_OR ) { $nb_diff_op++; }
  if ( $nb_XOR ) { $nb_diff_op++; }

  if ( $nb_diff_op > 1 ) {
    if ( $nb_AND + $nb_OR + $nb_XOR >= $COMPLEX_CONDITION_THRESHOLD) {
#print "==> COMPLEX CONDITION\n";
      return 1;
    }
  }
  return 0;
}

# Differencies with CodeSniffer :
#
# if (1) ===> violation for codesniffer
# if (!($i && $j)) ===> only one implicit comparison for codesniffer
# for ( ..; cond ; ..) ===> not addressed by codesniffer.

sub CountMissingIdenticalOp($) {
  my $cond = shift;
 
  # conditional expression can contain anonymous functions whose body contain ";"
  # ex : 
  #   if ($product->getImages()->filter(function(Image $i) {
  #          return $i->getType()->getValue() == ImageType::COVER;
  #      })->count()) {
  #
  # so, to detect "for" conditions with the pattern " for ( ..; cond ; ..) " we should discard ";" of anonymous functions's bodies !
  # The pattern of an anonymous function is "funcion(...) { ... }" 
  # so, consider that a ";" of a "for" instruction should not be preceded by a "{" 
  
  if ( $$cond =~ /\A([^;\{]*;)/m ) {
    my ($condfor) = $$cond =~ /^\s*\([^;]*;([^;]*);.*\)\s*$/sm ;
    $cond = \$condfor;
  }

  if ( $$cond =~ /\A\s*\(?\s*(?:1|0|true|false)\s*\)?\s*\Z/is) {
    return 0;
  }

  my $nb_NotVar = () = $$cond =~ /!\s*\$/isg;
  my $nb_illegalOp = () = $$cond =~ /[^=]==[^=]|!=[^=]|<>|!\s*(?:\$|\()/isg;
  my $NB_illegalOperators = $nb_illegalOp ;

  my $nb_Logical = () = $$cond =~ /\b(?:and|or|xor)|&&|\|\|/isg ;
  my $nb_Comparison = () = $$cond =~ /===?|!==?|<>|<|[^-]>|<=|>=/isg ;
  my $NB_implicitOperators = ($nb_Logical+1) - $nb_Comparison ; 

  if ($NB_implicitOperators < 0) {
    $NB_implicitOperators = 0;
  }

  # RQ: substract $nb_NotVar to the result because this pattern is counted in both cases
  # illegal and implicit operators ...
  # Ex : (!$i || $j) 
  #              | ==> 2 implicits operators : 
  #                           !$i in place of ($i === false)
  #                            $j in place of ($j === true)
  #              | ==> 1 illegal operator    : 
  #                           !$i in place of ($i === false)
  #
  #  ==> !$i is counted to times, but it is the same violation ...
#print "------\n";
#print "Illegal = $NB_illegalOperators, implicit = $NB_implicitOperators, NotVar = $nb_NotVar\n";
  return  $NB_illegalOperators + $NB_implicitOperators - $nb_NotVar;
}

sub CountCondition($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_MissingIdenticalOperator = 0;
  $nb_ComplexConditions = 0;
  $nb_BadVariableDefinitionCheck = 0;


  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $MissingIdenticalOperator__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $BadVariableDefinitionCheck__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Conds = GetNodesByKind( $root, CondKind);

  for my $cond (@Conds) {
    my $stmt = GetStatement($cond);

    my $nb = CountMissingIdenticalOp($stmt);
#print "$$stmt ==> ".($nb)." violations\n";
    $nb_MissingIdenticalOperator += $nb;

    $nb_ComplexConditions += isComplexCondition($stmt);

    if (IsKind(PHP::PHPNode::GetParent($cond), IfKind)) {
      if ( $$stmt =~ /^\s*\(\s*\$/s ) {
        if ( $$stmt !~ /=|>|<|!|\|\||&&|\b(?:instanceof|and|or|xor)\b/is ) {
	  $nb_BadVariableDefinitionCheck++;
#print "BAD VARIABLE DEFINITION CHECK : $$stmt !!!\n";
	}
      }
    }

  }

  $ret |= Couples::counter_add($compteurs, $MissingIdenticalOperator__mnemo, $nb_MissingIdenticalOperator );
  $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, $nb_ComplexConditions );
  $ret |= Couples::counter_add($compteurs, $BadVariableDefinitionCheck__mnemo, $nb_BadVariableDefinitionCheck );

  return $ret;
}

sub CountUnconditionalCondition($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_UnconditionalCondition = 0;


  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $UnconditionalCondition__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Ifs = GetNodesByKindList( $root, [IfKind, ElsifKind] );

  for my $if (@Ifs) {
    my $children = GetSubBloc($if);
 
    if (${GetStatement($children->[0])} =~ /\(\s*\b(?:false|true)\b\s*\)/si) {
#print "UNCONDITIONAL CONDITION\n";
      $nb_UnconditionalCondition++;
    }
  }

  $ret |= Couples::counter_add($compteurs, $UnconditionalCondition__mnemo, $nb_UnconditionalCondition );

  return $ret;
}

1;
