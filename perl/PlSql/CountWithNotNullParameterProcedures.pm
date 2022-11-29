

package PlSql::CountWithNotNullParameterProcedures ;
# Module de comptage des variables not null de procedures.
# Comptage P18.

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountWithNotNullParameterProcedures($$$);


my $mnemo = Ident::Alias_NotNullVariables();

# Pour rechercher leurs variables locales ayant une contrainte not null
sub _callbackProcedureVariableNode($$)
{
  my ( $node, $context )= @_;
  if ( IsKind ( $node, VariableDeclarationKind ) )
  {
    my $statement = GetStatement($node);
    if ( $statement =~ m/\bnot\s\s*null\b/sim )
    {
      $context->[0] += 1;
      Erreurs::LogInternalTraces('trace', undef, undef, $mnemo, $statement);
    }
  }
}


# Routine point d'entree du module.
sub CountWithNotNullParameterProcedures($$$)
{
  my (undef, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0, 0 );
  
  my @declarativeNodes = GetNodesByKindFromSpecificView( $root, DeclarativeKind);
  for my $node ( @declarativeNodes )
  {
    my $parentNode = GetParent( $node) ;
    if (IsKind ($parentNode, ProcedureKind))
    {
      Lib::Node::ForEachDirectChild($node, \&_callbackProcedureVariableNode, \@context);
    }
  }
  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



