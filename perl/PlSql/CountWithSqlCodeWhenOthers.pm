

package PlSql::CountWithSqlCodeWhenOthers ;
# Module de comptage P19 des clauses WHEN OTHERS contenant des tokens SQLCODE

use strict;
use warnings;

use Lib::Node;

use Erreurs;

sub CountWithSqlCodeWhenOthers($$$);

sub _CallbackSearchForSqlCode($$)
{
  my ( $node, $context )= @_;
  my $stmt = PlSql::PlSqlNode::GetStatement($node);
  return undef if not defined $stmt;
  if ( $stmt =~ /\bsqlcode\b/smi)
  {
    $context->[0] += 1;
  }
  return undef;
}

sub _CallbackSearchForWhenOther($$)
{
  my ( $node, $context )= @_;
  my $stmt = PlSql::PlSqlNode::GetStatement($node);
  return undef if not defined $stmt;
  if ( $stmt =~ /\bwhen\s*others\b/smi)
  {
    Lib::Node::Iterate ($node, 0, \& _CallbackSearchForSqlCode, $context) ;
  }
  return undef;
}


# point d'entree
sub CountWithSqlCodeWhenOthers($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_WithSqlCode_WhenOthers();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0 );
  
  Lib::Node::Iterate ($root, 0, \& _CallbackSearchForWhenOther, \@context) ;
  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



