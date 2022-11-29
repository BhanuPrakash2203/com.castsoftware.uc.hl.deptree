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

# Composant: Plugin

package CountWordsVbDotNet;

use strict;
use warnings;
use Erreurs;

# Description: Module de comptage des mots (halstead)
#
# Compatibilite: VB.net

sub CountWordsVbDotNet($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $memory = new Memory('CountWordsVbDotNet'); # memory_filter_line

  my $ret = 0;
  my $code = $vue->{code_lc};

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
  if ( $nb = ( $code =~ s/(<<=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(>>=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}

  $memory->memusage('3 symboles'); # memory_filter_line

  # Remplacement des operateurs composes de 2 symboles.
  if ( $nb = ( $code =~ s/(!=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(%=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(&=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\*=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\+=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(-=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\/=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\^=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\|=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  #if ( $nb = ( $code =~ s/(&&)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  #if ( $nb = ( $code =~ s/(\|\|)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\+\+)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\-\-)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(->)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  #if ( $nb = ( $code =~ s/(::)/ /g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(<<)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(>>)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}

  # Comparaisons binaires Vb.net
  if ( $nb = ( $code =~ s/(><)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(<>)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(<=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(>=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  #if ( $nb = ( $code =~ s/(==)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}

  # Remplacement des operateurs composes de 1 symbole.
  if ( $nb = ( $code =~ s/(!)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(%)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(&)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\*)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\+)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(,)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(-)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  #if ( $nb = ( $code =~ s/(\.)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\/)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(<)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(>)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\?)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\^)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\|)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\{)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(;)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}

  $memory->memusage('operateurs'); # memory_filter_line

 # Ci-dessous = methode moins performente.

 # while ( $code =~ /(\.\.\.|<<=|>>=|!=|%=|&=|\*=|\+=|-=|\/=|\^=|\|=|&&|\|\||\+\+|\-\-|->|<<|<=|==|>=|>>|!|%|&|\*|\+|,|-|\.|\/|<|=|>|\?|\^|\||{|;)/g ) {
 #   $nb_Words++;
 #   if (! defined $Hop{$1} ) {
 #     $nb_DistinctWords++;
 #     $Hop{$1} = 1;
 #   }
 #   else {
 #     $Hop{$1} += 1;
 #   }
 # }

  # Suppression des # ...
  $code =~ s/^\s*#[^\n]*$//mg;

  # Les parentheses ouvrantes seront comptees avec le mot qui les precede ...
  $code =~ s/(\w+)\s*[\(]/$1 /g;

  # Maintenant on s'occupe des ":" qui restent ...
  if ( $nb = ( $code =~ s/(:)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb;}

  $memory->memusage('derniers operateurs'); # memory_filter_line

  # Compter le nombre de mot distinct (il reste les identificateurs et les chaines)
  my $item;
  my %H =();

  my @words = split  (  /((?:[.]\s*)?(?:\w+[\(\[]?))/  , $code ) ;
  foreach my $word ( @words )
  {
    next if not defined $word;
    if ( $word =~ /\A(?:([.])\s*)?(\w+[\(\[]?)\z/sm )
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


sub CountAndOr($$$)
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  if ( ! exists $vue->{words} ) {
    $ret |= Couples::counter_add($compteurs, Ident::Alias_AndOr(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my $words = $vue->{words};
  my $nb_AndOr = 0;
  for my $keyword ( 'and', 'or', 'andalso', 'orelse')
  {
    my $value = $words->{$keyword};
    if (defined $value)
    {
      $nb_AndOr += $value;
    }
  }
  $ret |= Couples::counter_add($compteurs, Ident::Alias_AndOr(), $nb_AndOr);
  return $ret;
}


1;

