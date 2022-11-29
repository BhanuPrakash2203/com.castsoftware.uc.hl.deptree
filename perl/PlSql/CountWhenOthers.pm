

package PlSql::CountWhenOthers ;
# Module de comptage G39 des clauses WHEN OTHERS

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;

use Erreurs;

sub CountWhenOthers($$$);


sub _callback($$)
{
  my ( $node, $context )= @_;
  my $stmt = Lib::NodeUtil::GetStatement($node);
  return undef if not defined $stmt;
  if ( $stmt =~ /\bwhen\s*others\b/smi)
  {
    $context->[0] += 1;
  }
  return undef;
}


# point d'entree
sub CountWhenOthers($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_WhenOthers();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0 );
  
  Lib::Node::Iterate ($root, 0, \& _callback, \@context) ;
  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



