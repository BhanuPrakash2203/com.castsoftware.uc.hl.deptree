

package PlSql::CountTypeVariables ;
# Module de comptage des variables par Type
# pour les comptages suivants:
# P6: Nbr_NcharVariable
# P9: Nbr_Nvarchar2Variable

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;
use Erreurs;

sub CountTypeVariables($$$);


# Comptage de chaque variable par type.
sub _callbackCountTypeVariables($$)
{
  my ( $node, $context )= @_;
  my $statement = GetStatement($node);

  if  ( $statement =~ m/\bnchar\b/smi )
  {
    $context->[0] += 1;
  }
  if  ( $statement =~ m/\bnvarchar2\b/smi )
  {
    $context->[1] += 1;
  }
  if  ( $statement =~ m/\bexception\b/smi )
  {
    $context->[2] += 1;
  }
}



# Routine point d'entree du module.
sub CountTypeVariables($$$) 
{
  my (undef, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;

  my $mnemo1 = Ident::Alias_NcharVariable(); 
  my $mnemo2 = Ident::Alias_Nvarchar2Variable(); 
  my $mnemo3 = Ident::Alias_ExceptionVariables(); 

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo1, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $mnemo2, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $mnemo3, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0, 0, 0 );
  
  my @variablesNodes = GetNodesByKindFromSpecificView( $root, VariableDeclarationKind);
  for my $node ( @variablesNodes )
  {
    _callbackCountTypeVariables( $node, \@context);
  }
  my $nb1 = $context[0];
  my $nb2 = $context[1];
  my $nb3 = $context[2];

  $ret |= Couples::counter_add($compteurs, $mnemo1, $nb1);
  $ret |= Couples::counter_add($compteurs, $mnemo2, $nb2);
  $ret |= Couples::counter_add($compteurs, $mnemo3, $nb3);

  return $ret;
}

1;



