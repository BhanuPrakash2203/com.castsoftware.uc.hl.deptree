

package PlSql::CountWithExit_ConditionalLoops;
# Comptage P29
# Module de comptage du nombre de boucles contenant des sorties internes.

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountWithExit_ConditionalLoops($$$);


# callback appele pour chaque instruction presente dans une boucle
sub _callbackNode($$)
{
  my ( $node, $context )= @_;
  my $statement = GetStatement ( $node);
  return undef if not defined $statement;
  if ( $statement =~ /\A\s*(?:exit|return)\b/sim )
  {
    $context->[1] += 1;
  }
  return undef;
}


# Routine point d'entree du module.
sub CountWithExit_ConditionalLoops($$$) 
{
  my (undef, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_WithExit_ConditionalLoops();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @context = ( 0, undef );
  
  my @loopNodes = GetNodesByKindFromSpecificView( $root, LoopKind);
  for my $node ( @loopNodes)
  {
    $context[1] = 0;
    Lib::Node::Iterate ($node, 0, \& _callbackNode, \@context) ;
    # Si la boucle contient une sortie interne de boucle
    if ( $context[1] > 0 )
    {
      # Le nombre de boucle concerne est incremente
      $context[0] += 1; 
    }
  }
  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



