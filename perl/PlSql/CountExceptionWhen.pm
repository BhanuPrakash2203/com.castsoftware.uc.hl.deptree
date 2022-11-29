

package PlSql::CountExceptionWhen ;
# Module de comptage des and et or dans des conditions;

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountExceptionWhen($$$);


# Comptage de chaque instruction jusqu'au premier begin.
sub _callbackExceptionStatements($$)
{
  my ( $node, $context )= @_;
  my $stmt = PlSql::PlSqlNode::GetStatement($node);
  if ( $stmt =~ /\bwhen\b/smi )
  {
    $context->[0] += 1;
  }
}

# Reperage de chaque fonction/procedure/package, 
# pour rechercher leurs variables locales.
sub _callbackNode($$)
{
  my ( $node, $context )= @_;
  my $kind = PlSql::PlSqlNode::GetKind($node);
  if ( IsKind ( $node, ExceptionKind ) )
  {
    Lib::Node::ForEachDirectChild($node, \& _callbackExceptionStatements, $context);
  }
  return undef;
}


# Routine point d'entree du module.
sub CountExceptionWhen($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $input =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_ExceptionWhen();

  if ( ! defined $input )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0 );
  
  Lib::Node::Iterate ($input, 0, \& _callbackNode, \@context) ;
  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



