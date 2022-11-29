

package PlSql::CountLocalVariables ;
# Module de comptage des variables locales

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountLocalVariables($$$);


# Comptage de chaque instruction jusqu'au premier begin.
sub _callbackCountVariables($$)
{
  my ( $node, $context )= @_;
  #my $kind = PlSql::PlSqlNode::GetKind($node);
  #if ( $context->[1] == 0)
  {
    #if ( IsKind ($node, BeginKind ) )
    if ( IsKind ($node, VariableDeclarationKind ) )
    {
      #$context->[1] = 1;
      $context->[0] += 1;
    }
  }
}

# Reperage de chaque fonction/procedure/package, 
# pour rechercher leurs variables locales.
sub _callbackDeclarativeNode($$)
{
  my ( $node, $context )= @_;
  #my $kind = PlSql::PlSqlNode::GetKind($node);
  my $parent = PlSql::PlSqlNode::GetParent($node);
  #if ( not IsKind ( $parent, PackageKind ) )
  {
    #$context->[1] = 0;
    Lib::Node::ForEachDirectChild($node, \& _callbackCountVariables, $context);
  }
}


# Routine point d'entree du module.
sub CountLocalVariables($$$) 
{
  my (undef, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_LocalVariables();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0, 0 );
  
  my @declarativeNodes = GetNodesByKindFromSpecificView( $root, DeclarativeKind);
  for my $node ( @declarativeNodes )
  {
    _callbackDeclarativeNode ($node,\@context);
  }
  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



