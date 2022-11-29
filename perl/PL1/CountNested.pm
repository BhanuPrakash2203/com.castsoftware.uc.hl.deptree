package PL1::CountNested;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use PL1::PL1Node;

my $nb_MaxNestedLoops = 4;
my $nb_MaxNestedIfs = 4;

my $ToManyNestedLoop__mnemo = Ident::Alias_ToManyNestedLoop();
my $ToManyNestedIf__mnemo = Ident::Alias_ToManyNestedIf();

my $nb_ToManyNestedLoop = 0 ;
my $nb_ToManyNestedIf = 0 ;


sub CountToManyNestedKind($$$) ;

sub CountToManyNestedKind($$$) 
{
  my ($root, $kind, $threshold) = @_ ;
  my $nb_violation=0;

  my @Kinds = GetFirstNodesByKind( $root, $kind);

  if (($threshold == 0) && (scalar @Kinds > 0)) {
    # if the node contains other nodes of same kind in its tree while the threshold
    # is 1, then this node is a violation.
    return 1; 
  }

  # For ALL first loops 
  for my $kindNode (@Kinds) {

     # How many nested Kind ? 
     #my $nb_nested = CountNodesByKind($kindNode, $kind);
     $nb_violation += CountToManyNestedKind($kindNode, $kind,$threshold - 1);


  }
  return $nb_violation;
}



sub CountToManyNestedLoop($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_ToManyNestedLoop = 0 ;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
  $ret |= Couples::counter_add($compteurs, $ToManyNestedLoop__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

    $nb_ToManyNestedLoop += CountToManyNestedKind($root, DoloopKind, $nb_MaxNestedLoops);

  $ret |= Couples::counter_add($compteurs, $ToManyNestedLoop__mnemo, $nb_ToManyNestedLoop );

  return $ret;
}

sub CountToManyNestedIf($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_ToManyNestedIf = 0 ;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
  $ret |= Couples::counter_add($compteurs, $ToManyNestedIf__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

    $nb_ToManyNestedIf += CountToManyNestedKind($root, IfKind, $nb_MaxNestedIfs);
  $ret |= Couples::counter_add($compteurs, $ToManyNestedIf__mnemo, $nb_ToManyNestedIf );
  return $ret;
}

1;
