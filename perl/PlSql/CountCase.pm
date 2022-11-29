

package PlSql::CountCase;
# Module du comptage G160: Nombre de blocs case.

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountCase($$$);


# Routine point d'entree du module.
sub CountCase($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_Case();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @caseNodes = GetNodesByKindFromSpecificView( $root, CaseKind);
  my $nb = scalar (  @caseNodes );

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



