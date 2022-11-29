

package PlSql::CountCaseLikeElse ;
# Module de comptage des sequences if elsif else if pouvant vraisemblablement 
# etre remplacees par des case.

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;
use Erreurs;

sub CountCaseLikeElse($$$);


sub _callbackIfBranchNode($$)
{
  my ( $node, $contextConditions )= @_;
  my $stmt = Lib::NodeUtil::GetStatement($node);
  my $condition = PlSql::PlSqlNode::GetCondition($node);

  if ( IsKind ($node, ElseKind) )
  {
    my $subBloc = Lib::NodeUtil::GetSubBloc($node);
    my $firstNode = $subBloc->[0];
    if ( defined $firstNode )
    {
      if (  IsKind ($firstNode,  IfKind ) )
      {
        _AnalyseBlocIf($firstNode, $contextConditions);
      }
    }

  }
  elsif ( IsKind ($node, ElsifKind) )
  {
    push @{$contextConditions}, $condition;
  }
  elsif ( IsKind ($node, ThenKind) )
  {
    # Ne rien faire, la condition a deja ete traitee dans le noeud de type ifKind.
  }
  else
  {
    # par exemple, aucun traitement n'est associe au end.
  }
}

sub _AnalyseBlocIf($$)
{
  my ($node, $contextConditions) =@_;
  my $condition = PlSql::PlSqlNode::GetCondition($node);
  push @{$contextConditions}, $condition;
  Lib::Node::ForEachDirectChild($node, \&_callbackIfBranchNode, $contextConditions);
}

sub _countBlocIf($$)
{
  my ($node, $contextCount)=@_;

  my $parent = PlSql::PlSqlNode::GetParent($node);
  if ( IsKind ( $parent, ElseKind ) )
  {
    my $parentParent =  PlSql::PlSqlNode::GetParent($parent);
    if ( IsKind ( $parentParent, IfKind) )
    {
      # deja vu par ailleurs.
      return ;
    }
  }

  my @contextConditions = ( );
  _AnalyseBlocIf($node, \@contextConditions);
  if ( scalar ( @contextConditions ) gt 2 )
  {
    # il faut a minima deux conditions pour qu'un cas eeait de l'interet.
    my $n = 0;
    for my $condition ( @contextConditions )
    {
      if ( $condition =~ /<|>|=/sm )
      {
        # Comptage de la structrue sur condition numerique.
        $n = 1;
      }
    }
    $contextCount->[0] += $n;

  }

}


# Routine point d'entree du module.
sub CountCaseLikeElse($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_CaseLike_Else();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0 );
  
  my @ifNodes = GetNodesByKindFromSpecificView( $root, IfKind);
  for my $node ( @ifNodes)
  {
    #Erreurs::LogInternalTraces('debug', undef, undef, $mnemo, Lib::NodeUtil::GetStatement($node) );
    _countBlocIf($node, \@context);

  }

  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



