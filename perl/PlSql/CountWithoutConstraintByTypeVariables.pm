

package PlSql::CountWithoutConstraintByTypeVariables ;
# Module de comptage des variables sans contrainte/precision par Type
# pour les comptages suivants:
# P10, P11, P12, P13, P14

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountWithoutConstraintByTypeVariables($$$);


# Comptage de chaque variable par type.
sub _callbackCountWithoutConstraintByTypeVariables($$)
{
  my ( $node, $context )= @_;
  my $statement = GetStatement($node);

  if  ( $statement =~ m/\bchar\b\s*(?:[^(]|\z)/smi )
  {
    $context->[0] += 1;
  }
  if  ( $statement =~ m/\bnchar\b\s*(?:[^(]|\z)/smi )
  {
    $context->[1] += 1;
  }
  if  ( $statement =~ m/\bvarchar\b\s*(?:[^(]|\z)/smi )
  {
    $context->[2] += 1;
  }
  if  ( $statement =~ m/\bvarchar2\b\s*(?:[^(]|\z)/smi )
  {
    $context->[3] += 1;
  }
  if  ( $statement =~ m/\bnvarchar2\b\s*(?:[^(]|\z)/smi )
  {
    $context->[4] += 1;
  }
}



# Routine point d'entree du module.
sub CountWithoutConstraintByTypeVariables($$$) 
{
  my (undef, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;

  my @mnemos =   ( Ident::Alias_WithoutPrecision_CharVariable(),
                  Ident::Alias_WithoutPrecision_NcharVariable(),
                  Ident::Alias_WithoutPrecision_VarcharVariable(),
                  Ident::Alias_WithoutPrecision_Varchar2Variable(),
                  Ident::Alias_WithoutPrecision_Nvarchar2Variable(),
                );

  if ( ! defined $root )
  {
    foreach my $i (  0 , 1, 2, 3,  4)
    {
      $ret |= Couples::counter_add($compteurs, $mnemos[$i],  Erreurs::COMPTEUR_ERREUR_VALUE );
    }
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0, 0, 0, 0, 0 );
  
  my @variablesNodes = GetNodesByKindFromSpecificView( $root, VariableDeclarationKind);
  for my $node ( @variablesNodes )
  {
    _callbackCountWithoutConstraintByTypeVariables( $node, \@context);
  }

  foreach my $i (  0 , 1, 2, 3,  4)
  {
    $ret |= Couples::counter_add($compteurs, $mnemos[$i], $context[$i]);
  }

  return $ret;
}

1;



