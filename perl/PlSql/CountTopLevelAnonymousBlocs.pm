

package PlSql::CountTopLevelAnonymousBlocs;
# Module de comptage des blocs anonymes non imbriques

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;



# Comptage du noeud, s'il s'agit d'un bloc anonyme.
# correspondant aux critere d'imbrication voulu
sub _callbackAnonymousBlocsNode($$)
{
  my ( $node, $context )= @_;
  my $parent = PlSql::PlSqlNode::GetParent($node);
  $node = $parent;
  while ( ( not IsKind ( $node, RootKind) ) and 
          ( not IsKind ( $node, ProcedureKind) ) and 
          ( not IsKind ( $node, FunctionKind) ) and 
          ( not IsKind ( $node, TriggerKind) ) and 
          ( not IsKind ( $node, AnonymousKind) ) )
  {
    $parent = PlSql::PlSqlNode::GetParent($node);
    $node = $parent;
  }
  if ( IsKind ( $node, RootKind) )
  {
    $context->[0] += 1;
  }
}


# Routine point d'entree du module.
sub CountTopLevelAnonymousBlocs($$$) 
{
  my (undef, $Vue, $Compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $Root =  $Vue->{$NomVueCode} ;
  my $Mnemo = Ident::Alias_TopLevelAnonymousBlocs();

  if ( ! defined $Root )
  {
    $ret |= Couples::counter_add($Compteurs, $Mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @context = ( 0, undef );
  
  my @anonymousBlocsNodes = GetNodesByKindFromSpecificView( $Root, AnonymousKind);
  for my $node ( @anonymousBlocsNodes )
  {
    _callbackAnonymousBlocsNode ($node, \@context);
  }
  my $nb = $context[0];

  $ret |= Couples::counter_add($Compteurs, $Mnemo, $nb);

  return $ret;
}

1;



