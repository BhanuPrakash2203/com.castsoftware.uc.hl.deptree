package PL1::CountCondition;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Ident;
use PL1::PL1Node;
use Lib::NodeUtil;
use CountUtil;


my $fichier = "";

my $AndOr__mnemo = Ident::Alias_AndOr();
my $ComplexConditions__mnemo = Ident::Alias_ComplexConditions();

my $nb_AndOr = 0 ;
my $nb_ComplexConditions = 0 ;

my $seuil = 4;

sub getIfCondition($) {
  my ($ifNode) = @_ ;

  if ( ${ GetStatement($ifNode)} =~ /\bif\b\s*(.*)/ig ) {
    return $1;
  }
  else {
    return '';
  }
}

sub getWhenCondition($) {
  my ($whenNode) = @_ ;

  my ($r_cond) = CountUtil::splitAtPeer(GetStatement($whenNode), '(', ')');

  if ( $$r_cond =~ /\bwhen\b\s*\((.*)\)/ig ) {
    return $1;
  }
  else {
    return '';
  }
}

sub getLoopCondition($) {
  my ($ifNode) = @_ ;

  my @conditions = ();

  if ( ${ GetStatement($ifNode)} =~ /\bwhile\b\s*(.*)(?:\b(?:until|repeat|to|by|upthru|downthru)\b|\s*$)/ig ) {
    push @conditions, $1;
  }

  if ( ${ GetStatement($ifNode)} =~ /\buntil\b\s*(.*)(?:\b(?:while|repeat|to|by|upthru|downthru)\b|\s*$)/ig ) {
    push @conditions, $1;
  }

  return \@conditions;
}

sub isComplex($) {
 my ($cond) = @_ ;

#  print "TESTING $cond\n";

 # Calcul du nombre de & et de |
 my $nb_ET = () = $cond =~ /(\&|\band\b)/isg ;
 my $nb_OU = () = $cond =~ /(\||\bor\b)/isg ;

 $nb_AndOr += $nb_ET + $nb_OU ;

 if ( ($nb_ET > 0) && ($nb_OU > 0) ) {
  if ( $nb_ET + $nb_OU >= $seuil) {
    Erreurs::LogInternalTraces('TRACE', "<unkfile>", 1, $ComplexConditions__mnemo, $cond); # Erreurs::LogInternalTraces
     return 1;
   }
 }
 return 0;
}

sub CountComplexConditions($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_AndOr = 0 ;
  $nb_ComplexConditions = 0 ;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $AndOr__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Ifs = Lib::NodeUtil::GetNodesByKind( $root, IfKind);
  for my $ifNode (@Ifs) {
    my $cond = getIfCondition($ifNode);
    if ( isComplex($cond) ) {
      $nb_ComplexConditions++
    }
  }

  my @Loops = Lib::NodeUtil::GetNodesByKind( $root, DoloopKind);
  for my $loop (@Loops) {
    my $r_T_conds = getLoopCondition($loop);

    for my $cond (@{ $r_T_conds }) {
      if ( isComplex($cond) ) {
        $nb_ComplexConditions++
      }
    }

  }

  my @Whens = Lib::NodeUtil::GetNodesByKind( $root, WhenKind);
  for my $when (@Whens) {
    my $cond = getWhenCondition($when);
    if ( isComplex($cond) ) {
      $nb_ComplexConditions++
    }
  }

  $ret |= Couples::counter_add($compteurs, $AndOr__mnemo, $nb_AndOr );
  $ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, $nb_ComplexConditions );

  return $ret;
}


1;
