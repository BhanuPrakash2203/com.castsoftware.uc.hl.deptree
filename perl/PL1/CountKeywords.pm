
package PL1::CountKeywords ;
# Module de comptage des instructions continue, goto, exit.

use strict;
use warnings;

use Erreurs;

sub CountKeywords($$$);


my @keyword_table = (
  #["id", "keyword", "Mnémonique", "Idée"],
  [ "blksize", Ident::Alias_BlkSize() ],
  [ "recsize", Ident::Alias_RecSize() ],
  [ "string", Ident::Alias_String() ],
#  [ "do", Ident::Alias_Base_Do() ],
#  [ "while", Ident::Alias_Base_While() ],
#  [ "until", Ident::Alias_Base_Until() ],
#  [ "to", Ident::Alias_Base_To() ],
#  [ "by", Ident::Alias_Base_By() ],
#  [ "repeat", Ident::Alias_Base_Repeat() ],
#  [ "if", Ident::Alias_Base_If() ],
#  [ "then", Ident::Alias_Basex_Then() ],
#  [ "else", Ident::Alias_Base_Else() ],
#  [ "exit", Ident::Alias_Base_Exit() ],
#  [ "return", Ident::Alias_Base_Return() ],
#  [ "goto", Ident::Alias_Base_Goto() ],
#  [ "entry", Ident::Alias_Base_Entry() ],
#  [ "select", Ident::Alias_Base_Select() ],
#  [ "when", Ident::Alias_Base_When() ],
#  [ "other|otherwise", Ident::Alias_Base_Others() ],
#  [ "preocedure|proc", Ident::Alias_Base_Procedure() ],
#  [ "begin", Ident::Alias_Base_Begin() ],
#  [ "end", Ident::Alias_Base_End() ],
#  [ "leave", Ident::Alias_Base_Leave() ],
#  [ "iterate", Ident::Alias_Base_Iterate() ],
#  [ "call", Ident::Alias_Base_CAll() ],
);


# FIXME: Il s'agit d'une fonction utilitaire.
# Le nom de la routine ne devrait donc pas commencer par Count
sub _CountItem($$$$) 
{
  my ($item, $id, $buffer, $compteurs) = @_ ;
  my $ret = 0;

  if ( ! defined $buffer) {
    $ret |= Couples::counter_add($compteurs, $id, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nb = () = $buffer  =~ /\b${item}\b/sg ;
  $ret |= Couples::counter_add($compteurs, $id, $nb);

  return $ret;
}


sub CountKeywords($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  my $NomVueCode = 'sansprepro'; 
  my $buffer = undef;

  # Astuce pour se parer de l'absence d'harmonie de casse dans les vues.
  if ( defined $vue->{$NomVueCode} ) 
  {
    $buffer = lc (  $vue->{$NomVueCode} ) ;
  }

  for my $comptage ( @keyword_table )
  {
    $ret |= _CountItem($comptage->[0], $comptage->[1], $buffer, $compteurs);
  }

  return $ret;
}

1;



