
package PlSql::CountWithoutParameterProcedures ;
# Module de comptage des procedures ne prenant pas de parametres
# Comptage P37.

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountWithoutParameterProcedures($$$);


# FIXME: ce genre de fonctionnalites serait mieux placee 
# dans un module commun au PLSQL.
my $_ReIdentifier = qr/[a-z][a-z\$\%_#0-9]*/i ;

# Pour rechercher leurs variables locales ayant une contrainte not null
sub _callbackProcedureNode($$)
{
  my ( $node, $context )= @_;
  {
    my $statement = GetStatement($node);
    return if not defined $statement;
    if ( $statement =~ /\A\s*(?:\bcreate\s*(?:or\s*replace\s*)?)?(?:constructor\s*|(?:order\s*|map\s*|overriding\s*)?member\s*)?\b(?:procedure\b\s*)(?:$_ReIdentifier)\s*(?:([(])|\b(is|as))\b/ism )

    {
      if ( defined $2 or not defined $1)
      {
        $context->[0] += 1;
      }
    }
  }
}


# Routine point d'entree du module.
sub CountWithoutParameterProcedures($$$) 
{
  my (undef, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_WithoutParameter_Procedures();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0 );
  
  my @proceduresNodes = GetNodesByKindFromSpecificView( $root, ProcedureKind);
  for my $node ( @proceduresNodes )
  {
    _callbackProcedureNode($node, \@context);
    #Lib::Node::ForEachDirectChild($node, \&_callbackProcedureNode, \@context);
  }
  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



