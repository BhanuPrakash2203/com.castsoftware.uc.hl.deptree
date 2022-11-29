

package PlSql::CountSqlLines ;
# Module de comptage G154: Nombre de ligne non vides de code SQL statique.

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

sub CountSqlLines($$$);



# Routine point d'entree du module.
sub CountSqlLines($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code_by_kind' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_SqlLines();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my $nb = 0;
  my @statementNodes = GetNodesByKindFromSpecificView( $root, StatementKind);
  my @cursorNodes = GetNodesByKindFromSpecificView( $root, CursorKind);
  my @nodes = ( @statementNodes, @cursorNodes);
  for my $node ( @nodes)
  {
    my $statement = GetStatement ( $node);
    # Cette routine reagit sur les mots clefs SQL-DML (insert|update|delete)
    # Elle eagit egalement sur le mot clef select
    # La reaction s'arrete en fin d'instruction.
    if ($statement =~ m{\b(?:select|insert|update|delete)\b}smi )
    {
      my $buffer = $statement . "\n"; # On s'assure de bien compter la dernere ligne
      $buffer =~ s/\n\s*/\n/g ; # On ne compte pas le slignes blanches.
      my $delta = 0 + ( $buffer =~ tr{\n}{\n} ) ;
      $nb += $delta;
      Erreurs::LogInternalTraces('trace', undef, undef, $mnemo, $statement, $delta);
    }
  }

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



