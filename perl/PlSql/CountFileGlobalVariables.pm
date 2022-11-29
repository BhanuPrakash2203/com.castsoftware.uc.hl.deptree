

package PlSql::CountFileGlobalVariables ;
# Comptage G53
# Module de comptage des variables globales à un package.

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountFileGlobalVariables($$$);


# Comptage de chaque instruction jusqu'au premier begin.
sub _callbackCountVariables($$)
{
  my ( $node, $context )= @_;
  my $kind = PlSql::PlSqlNode::GetKind($node);
  #if ( $context->[1] == 0)
  {
    if ( IsKind ($node, VariableDeclarationKind ) )
    {
      $context->[0] += 1;
    }
  }
}

# Reperage de chaque fonction/procedure/package, 
# pour rechercher leurs variables locales.
sub _callbackPackage($$)
{
  my ( $node, $context )= @_;
  if ( IsKind ( $node, DeclarativeKind) )
  {
    #$context->[1] = 0;
    Lib::Node::ForEachDirectChild($node, \& _callbackCountVariables, $context);
  }
}


# Routine point d'entree du module.
sub CountFileGlobalVariables($$$) 
{
  my (undef, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_GlobalVariables();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @context = ( 0, undef );
  
  my @packageNodes = GetNodesByKindFromSpecificView( $root, PackageKind);
  for my $node ( @packageNodes)
  {
    Lib::Node::ForEachDirectChild($node, \&_callbackPackage, \@context);
  }
  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



