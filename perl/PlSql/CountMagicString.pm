

package PlSql::CountMagicString ;
# Module de comptage P23 des literaux chaines

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;
use Erreurs;

sub CountMagicString($$$);


sub _callbackExecutiveNode($$)
{
  my ( $node, $context )= @_;
  if ( not IsKind ( $node, ExecutiveKind ) )
  {
    return 0; # sera analyse par ailleurs.
  }
  my $statement = PlSql::PlSqlNode::GetStatement($node);
  return undef if not defined $statement;
  if ( $statement =~ m/\bchaine_[0_9]+\b/sim )
  {
      $context->[0] += 1;
  }
  return undef;
}


# Routine point d'entree du module.
sub CountMagicString($$$) 
{
  my (undef, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_MagicString();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0, 0 );
  
  my @executiveNodes = GetNodesByKindFromSpecificView( $root, ExecutiveKind);
  for my $node ( @executiveNodes )
  {
    Lib::Node::Iterate($node, 0, \&_callbackExecutiveNode, \@context);
  }
  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



