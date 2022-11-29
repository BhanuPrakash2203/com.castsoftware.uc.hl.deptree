

package PlSql::CountFunctionImplementations ;
# Module de comptage des fonctions implementees

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountFunctionImplementations($$$);



# Routine point d'entree du module.
sub CountFunctionImplementations($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_FunctionImplementations();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nb=0;
  my @functionsNodes = GetNodesByKindFromSpecificView( $root, FunctionKind);
  for my $node ( @functionsNodes)
  {
    if ( defined Lib::Node::GetSubBloc($node) )
    {
      $nb += 1;
    }
  }

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



