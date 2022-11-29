
package PlSql::CountAttributesExceptionVariables;

use strict;
use warnings;

use Erreurs;
use PlSql::PlSqlNode ;
use Lib::NodeUtil;



# Comptage de la variable, si elle est de type exception.
sub _callbackCountTypeVariables($$)
{
  my ( $node, $context )= @_;
  my $statement = GetStatement($node);

  if  ( $statement =~ m/\bexception\b/smi )
  {
    $context->[0] += 1;
  }
}


# Lancement des comptages sur les variables du bloc.
# pour rechercher leurs variables locales.
sub _callbackAttributesContainer($$)
{
  my ( $node, $context )= @_;
  if ( IsKind ( $node, DeclarativeKind) )
  {
    Lib::Node::ForEachDirectChild($node, \& _callbackCountTypeVariables, $context);
  }
}


# Routine point d'entree du module.
sub CountAttributesExceptionVariables($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $root =  $vue->{'structured_code_by_kind'} ;
  my $ret=0;

  if ( ! defined $root)
  {
    $ret |= Couples::counter_add($compteurs, Ident::Alias_BodyExceptionVariables(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_SpecExceptionVariables(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @context = ( undef);
  my @packageNodes = GetNodesByKindFromSpecificView( $root, PackageKind);
  my @typeBodyNodes = GetNodesByKindFromSpecificView( $root, TypeBodyKind);

  $context [0] = 0;
  for my $node ( @typeBodyNodes)
  {
    Lib::Node::ForEachDirectChild($node, \&_callbackAttributesContainer, \@context);
  }
  for my $node ( @packageNodes)
  {
    my $statement_mixed_case = GetStatement($node);
    my $statement = lc ( $statement_mixed_case );
    if ( $statement =~ /\bbody\b/sm )
    {
      Lib::Node::ForEachDirectChild($node, \&_callbackAttributesContainer, \@context);
    }
  }
  my $nb_BodyExceptionVariables = $context[0];

  $context [0] = 0;
  for my $node ( @packageNodes)
  {
    my $statement_mixed_case = GetStatement($node);
    my $statement = lc ( $statement_mixed_case );
    if ( $statement !~ /\bbody\b/sm )
    {
      Lib::Node::ForEachDirectChild($node, \&_callbackAttributesContainer, \@context);
    }
  }
  my $nb_SpecExceptionVariables = $context[0];

  # Comptages definis en avril 2009
  $ret |= Couples::counter_add($compteurs, Ident::Alias_BodyExceptionVariables(), $nb_BodyExceptionVariables);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_SpecExceptionVariables(), $nb_SpecExceptionVariables);

  return $ret;
}


1;
