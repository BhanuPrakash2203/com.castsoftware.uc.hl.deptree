

package PlSql::CountReturnRoutines ;
# Module de comptage de l'utilisation des return dans les routines.

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountReturnRoutines($$$);


# Comptage de chaque instruction jusqu'au premier begin.
sub _callbackFunction($$)
{
  my ( $node, $context )= @_;
  return 0 if ( IsKind ($node, ProcedureKind)); # deja compte par ailleurs
  return 0 if ( IsKind ($node, FunctionKind)); # deja compte par ailleurs
  return 0 if ( IsKind ($node, ExceptionKind)); # on ne descend pas

  my $statement = PlSql::PlSqlNode::GetStatement($node);
  return undef if not defined ($statement);
  
  if ( $statement =~ m/\breturn\b/sim )
  {
    $context->[2] += 1;
  }
  
  return undef;
}


sub _BlocTerminatesWithReturn ($)
{
  my ($node) = @_;
  my $bloc = PlSql::PlSqlNode::GetSubBloc($node);
  my $len = scalar ( @{$bloc} );
  if ( ( scalar ( @{$bloc} ) > 2 ) and ( $bloc->[-2] =~ /m\breturn\b/sim ) )
  {
    return 1;
  }
  else
  {
    return 0;
  }

}


sub _callbackProcedure($$)
{
  my ( $node, $context )= @_;
  return 0 if ( IsKind ($node, ProcedureKind)); # deja compte par ailleurs
  return 0 if ( IsKind ($node, FunctionKind)); # deja compte par ailleurs
  return 0 if ( IsKind ($node, ExceptionKind)); # on ne descend pas

  my $statement = PlSql::PlSqlNode::GetStatement($node);
  return undef if not defined ($statement);

  if ( $statement =~ m/\breturn\b/sim )
  {
    $context->[1] += 1;
  }
  
  return undef;
}

# Reperage de chaque fonction/procedure/package, 
# pour rechercher leurs variables locales.
sub _callbackExecutiveNode($$)
{
  my ( $node, $context )= @_;

  my $parent = PlSql::PlSqlNode::GetParent($node);
  if ( IsKind ( $parent, ProcedureKind ) )
  {
    Lib::Node::Iterate ($node, 0, \& _callbackProcedure, $context) ;
  }
  elsif ( IsKind ( $parent, FunctionKind ) )
  {
    Lib::Node::Iterate ($node, 0, \& _callbackFunction, $context) ;
    my $returnFinal = _BlocTerminatesWithReturn ($node) ;
    $context->[0] += $returnFinal;
    $context->[2] -= $returnFinal;
  }
}


# Routine point d'entree du module.
sub CountReturnRoutines($$$) 
{
  my (undef, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my @mnemos =  ( Ident::Alias_WithoutFinalReturn_Functions(),
                 Ident::Alias_WithReturnOutsideExceptionHandler_Procedure(),
                 Ident::Alias_WithReturnOutsideExceptionHandler_Function() );

  if ( ! defined $root )
  {
    for my $mnemo ( @mnemos )
    {
      $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    }
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0,  # Comptage P27: Nbr_WithoutFinalReturn_Functions
                  0,  # Comptage P30: Nbr_WithReturnOutsideExceptionHandler_Procedure
                  0 );# comptage P33: Nbr_WithReturnOutsideExceptionHandler_Function
  
  my @executiveNodes = GetNodesByKindFromSpecificView( $root, ExecutiveKind);
  for my $node ( @executiveNodes )
  {
    #Lib::Node::ForEachDirectChild($node, \&_callbackDeclarativeNode, \@context);
    _callbackExecutiveNode ($node,\@context);
  }
  my $nb = $context[0];

  #Lib::Node::Iterate ($root, 0, \& _callbackNode, \@context) ;
  #my $nb = $context[0];

  for ( my $i =0; $i < scalar( @mnemos ) ; $i++ )
  {
    $ret |= Couples::counter_add($compteurs, $mnemos[$i], $context[$i]);
  }

  return $ret;
}

1;



