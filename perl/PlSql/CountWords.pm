#------------------------------------------------------------------------------#
#                         @ISOSCOPE 2008                                       #
#------------------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                          #
#               Adresse : TERSUD - Bat A                                       #
#                         5, AVENUE MARCEL DASSAULT                            #
#                         31500  TOULOUSE                                      #
#               SIRET   : 410 630 164 00037                                    #
#------------------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                                #
# l'Institut National de la Propriete Industrielle (lettre Soleau)             #
#------------------------------------------------------------------------------#

package PlSql::CountWords;

use strict;
use warnings;
use Erreurs;

# Description: Module de comptage des mots (halstead)
#
# Compatibilite: PL-SQL

sub CountWords($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;
  my $memory = new Memory('CountWords'); # memory_filter_line

  my $ret = 0;
  my $code = $vue->{'code_lc_without_directive'};

  if ( ! defined $code ) {
    $ret |= Couples::counter_add($compteurs, Ident::Alias_Words(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_DistinctWords(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nb_DistinctWords = 0;
  my $nb_Words = 0;

  # supression des elements fermants (ils vont de pair avec des ouvrants comptabilises).
  $code =~ s/}|\)|\]|::/ /g;

  my %Hop = ();
  my $nb = 0;

  $memory->memusage('init'); # memory_filter_line

  # Remplacement des operateurs composes de 3 symboles.
  if (0)
  {
  # FIXME: faut-il garder ces operateurs herites du VB?
    if ( $nb = ( $code =~ s/(<<=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(>>=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  }

  $memory->memusage('3 symboles'); # memory_filter_line

  # Remplacement des operateurs composes de 2 symboles.
  if ( $nb = ( $code =~ s/(:=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # affectation PL/SQL

  if ( $nb = ( $code =~ s/(!=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # comparaison PL/SQL
  if ( $nb = ( $code =~ s/(\^=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}    # comparaison PL/SQL (not equal)
  if ( $nb = ( $code =~ s/(\~=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}    # comparaison PL/SQL (not equal)
  if ( $nb = ( $code =~ s/(\|\|)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}   # operateur PL/SQL (concatenation)
  if ( $nb = ( $code =~ s/(\*\*)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}   # operateur PL/SQL (exponentiation)
  if ( $nb = ( $code =~ s/(\.\.)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}   # operateur PL/SQL (range)
  if ( $nb = ( $code =~ s/(<<)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # operateur PL/SQL (label delimiter)
  if ( $nb = ( $code =~ s/(>>)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # operateur PL/SQL (label delimiter)

  # Comparaisons binaires PlSql
  if ( $nb = ( $code =~ s/(<>)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # operateur PL/SQL
  if ( $nb = ( $code =~ s/(<=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # comparaison PL/SQL
  if ( $nb = ( $code =~ s/(>=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # comparaison PL/SQL
  if ( $nb = ( $code =~ s/(=>)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # operateur PL/SQL (association)

  if ( $nb = ( $code =~ s/\b(is)\b/§/gi )) { $nb_DistinctWords++; $Hop{'is'}=$nb;}
  if ( $nb = ( $code =~ s/\b(in)\b/§/gi )) { $nb_DistinctWords++; $Hop{'in'}=$nb;}
  if ( $nb = ( $code =~ s/\b(not)\b/§/gi )) { $nb_DistinctWords++; $Hop{'not'}=$nb;}

  if ( 0 )
  {
  # FIXME: faut-il garder ces operateurs herites du VB?
    #if ( $nb = ( $code =~ s/(==)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(%=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(&=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(\*=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(\+=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(-=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(\/=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(\|=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    #if ( $nb = ( $code =~ s/(&&)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(\+\+)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(\-\-)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(->)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    #if ( $nb = ( $code =~ s/(::)/ /g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(><)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  }

  # Remplacement des operateurs composes de 1 symbole.
  if ( $nb = ( $code =~ s/([~])/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}    # symbole PL-SQL
  if ( $nb = ( $code =~ s/(!)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}      # symbole PL-SQL
  if ( $nb = ( $code =~ s/(@)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}      # symbole PL-SQL
  if ( $nb = ( $code =~ s/(%)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}      # symbole PL-SQL
  if ( $nb = ( $code =~ s/(\*)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # symbole PL-SQL
  if ( $nb = ( $code =~ s/(\+)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # symbole PL-SQL
  if ( $nb = ( $code =~ s/(,)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}      # symbole PL-SQL
  if ( $nb = ( $code =~ s/(-)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}      # symbole PL-SQL
  if ( $nb = ( $code =~ s/(\/)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # symbole PL-SQL
  if ( $nb = ( $code =~ s/(<)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}      # symbole PL-SQL
  if ( $nb = ( $code =~ s/(=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}      # symbole PL-SQL
  if ( $nb = ( $code =~ s/(>)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}      # symbole PL-SQL
  if ( $nb = ( $code =~ s/(\?)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # symbole PL-SQL
  if ( $nb = ( $code =~ s/(\^)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # symbole PL-SQL
  if ( $nb = ( $code =~ s/(\|)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}     # symbole PL-SQL
  if ( $nb = ( $code =~ s/(;)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}      # symbole PL-SQL
  if ( $nb = ( $code =~ s/(:)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}      # symbole PL-SQL

  # Autres operateurs
  if (0)
  {
    # FIXME: faut-il garder ces operateurs herites du VB?
    #if ( $nb = ( $code =~ s/(\.)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(&)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
    if ( $nb = ( $code =~ s/(\{)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  }

  $memory->memusage('operateurs'); # memory_filter_line


  # Les parentheses ouvrantes seront comptees avec le mot qui les precede ...
  $code =~ s/(\w+)\s*[\(]/$1 /g;

  # Maintenant on s'occupe des ":" qui restent ...
  if ( $nb = ( $code =~ s/(:)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}

  $memory->memusage('derniers operateurs'); # memory_filter_line

  # Compter le nombre de mot distinct (il reste les identificateurs et les chaines)
  my $item;
  my %H =();

  my @words = split  (  /((?:[.]\s*)?(?:(?:\w|[\$_#])+[\(\[]?))/  , $code ) ;
  foreach my $word ( @words )
  {
    next if not defined $word;
    if ( $word =~ /\A(?:([.])\s*)?((?:\w|[\$_#])+[\(\[]?)\z/sm )
    {

    if (defined $1)
    {
      $item = $1.$2;
    }
    else
    {
      $item = $2;
    }
    $nb_Words++;
    if (! defined $H{$item} ) {
      $nb_DistinctWords++;
      $H{$item} = 1;
    }
    else {
      $H{$item} += 1;
    }
    }
    else
    {
      next ;
    }
  }

  $memory->memusage('boucle'); # memory_filter_line

  # Suppression des mots suivis de "(" ou "["
  #$code =~ s/\w\s*[\(\]]/ /g;

  # Compatge des "(" et "[" qui restent.
  if ( $nb = ( $code =~ s/(\()/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\[)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}

  $memory->memusage('divers'); # memory_filter_line


  # Finalisation des resultats.
  # Ajout de tout ce qui a ete trouve precedemment (et remplace par des §).
  $nb_Words += () = $code =~ /§/g ;

  $ret |= Couples::counter_add($compteurs, Ident::Alias_Words(), $nb_Words);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_DistinctWords(), $nb_DistinctWords);

  $memory->memusage('fin'); # memory_filter_line

  $vue->{'words'} = \%H;

  return $ret;
}




1;

