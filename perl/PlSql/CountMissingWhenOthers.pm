

package PlSql::CountMissingWhenOthers ;
# Module des whn others manquant dans les blocs case.

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountMissingWhenOthers($$$);


# Comptage de chaque instruction jusqu'au premier begin.
sub _callbackCaseStatements($$)
{
  my ( $node, $context )= @_;
#  my $stmt = PlSql::PlSqlNode::GetStatement($node);
#  if ( $stmt =~ /\bwhen\s\s*others\b/smi )
  if (IsKind($node, CaseElseKind) )
  {
    $context->[1] = 0;
  }
}


# Routine point d'entree du module.
sub CountMissingWhenOthers($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_MissingWhenOthers();
  my $Default__mnemo = Ident::Alias_Default();

  my $nb_Default = 0;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Default__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0, undef );
  
  my @caseNodes = GetNodesByKindFromSpecificView( $root, CaseKind);
  for my $node ( @caseNodes)
  {
    $context[1] = 1;
    Lib::Node::ForEachDirectChild($node, \&_callbackCaseStatements, \@context);
    # Default case has been found ? 
    if ( $context[1] == 1)
    {
      # No => inc MissingWhenOthers
      $context[0] ++;
    }
    else {
      # Yes => inc Default number.
      $nb_Default++; 
    }
  }

  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);
  $ret |= Couples::counter_add($compteurs, $Default__mnemo, $nb_Default);

  return $ret;
}

1;



