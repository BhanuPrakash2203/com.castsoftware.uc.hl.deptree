

package PlSql::CountCaseWhen ;
# Module de comptage des and et or dans des conditions;

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountCaseWhen($$$);


# Comptage de chaque instruction jusqu'au premier begin.
sub _callbackCaseStatements($$)
{
  my ( $node, $context )= @_;
  my $stmt = PlSql::PlSqlNode::GetStatement($node);
  if ( $stmt =~ /\bwhen\b/smi )
  {
    $context->[0] += 1;
  }
}



# Routine point d'entree du module.
sub CountCaseWhen($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_CaseWhen();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0 );
  
  my @caseNodes = GetNodesByKindFromSpecificView( $root, CaseKind);
  for my $node ( @caseNodes)
  {
   Erreurs::LogInternalTraces('debug', undef, undef, $mnemo, PlSql::PlSqlNode::GetStatement($node) );

    Lib::Node::ForEachDirectChild($node, \&_callbackCaseStatements, \@context);
  }

  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



