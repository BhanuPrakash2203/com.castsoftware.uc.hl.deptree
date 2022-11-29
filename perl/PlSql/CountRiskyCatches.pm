

package PlSql::CountRiskyCatches ;
# Module de comptage TOAD 3004

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountRiskyCatches($$$);


sub _callbackWhen($$)
{
  my ( $node, $context )= @_;
  my $stmt = PlSql::PlSqlNode::GetStatement($node);
  return if not defined $stmt;
  if ( $context->[1] == 0)
  {
    if ( $stmt =~ /\A\s*(?:\breturn\b\s*)?(?:\bnull\b|\bfalse\b)\s*(?:;\s*)?\z/smi )
    {
    $context->[0] += 1;
    }
  }
  $context->[1] += 1;
}

# Comptage de 
sub _callbackExceptionStatements($$)
{
  my ( $node, $context )= @_;
  my $stmt = PlSql::PlSqlNode::GetStatement($node);
  if ( $stmt !~ /\bwhen\b\s*no_data_found/smi )
  {
    $context->[1] = 0;
    Lib::Node::ForEachDirectChild($node, \&_callbackWhen, $context);
  }
}


# Routine point d'entree du module.
sub CountRiskyCatches($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_RiskyCatches();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0, undef );
  
  my @exceptionNodes = GetNodesByKindFromSpecificView( $root, ExceptionKind);
  for my $node ( @exceptionNodes)
  {
    Lib::Node::ForEachDirectChild($node, \&_callbackExceptionStatements, \@context);
  }
  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



