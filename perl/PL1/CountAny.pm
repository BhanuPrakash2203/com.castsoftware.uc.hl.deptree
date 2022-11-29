

package PL1::CountAny;
# Module du comptage TDB: Nombre de procedures internes non referencees.

use strict;
use warnings;

use PL1::PL1Node;
use Lib::NodeUtil;

use Erreurs;
use CountUtil;
use Ident;

my $NullStatement__mnemo = Ident::Alias_NullStatement();

my $nb_NullStatement=0;



sub CountAny($$$) 
{
  my ($Filename, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_NullStatement=0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $NullStatement__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Nulls = Lib::NodeUtil::GetNodesByKind( $root, NulKind);
  $nb_NullStatement = scalar @Nulls;

  $ret |= Couples::counter_add($compteurs, $NullStatement__mnemo, $nb_NullStatement );

  return $ret;
}

1;



