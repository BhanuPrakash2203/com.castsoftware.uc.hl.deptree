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

package CountLongLines;

use strict;
use warnings;
use Erreurs;

# Description =
#         Module de comptage des lignes longues
#         WORK ON THE 'text' VIEW
#
# Langages = 
#         C, C++, C#, Java
sub CountLongLines($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  return __CountLongLines(@_, ['text']);
}

# Description =
#         Module de comptage des lignes longues
#         WORK ON THE 'code' & 'comment' VIEWS
#
# Langages = 
#         C, C++, C#, Java
sub CountLongLines_CodeComment($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  return __CountLongLines(@_, ['code', 'comment'] );
}

sub __CountLongLines($$$$) {
  my ($fichier, $vue, $compteurs, $viewslist) = @_ ;

  my $retour = 0;

  my $Nbr_LongLines80= 0;
  my $Nbr_LongLines100= 0;
  my $Nbr_LongLines120= 0;
  my $Nbr_LongLines132= 0;

  for my $view (@{$viewslist}) {
  my $code = $vue->{$view};

  if ( ! defined $code ) {
    $retour |= Couples::counter_add($compteurs, Ident::Alias_LongLines80(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $retour |= Couples::counter_add($compteurs, Ident::Alias_LongLines100(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $retour |= Couples::counter_add($compteurs, Ident::Alias_LongLines120(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $retour |= Couples::counter_add($compteurs, Ident::Alias_LongLines132(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $retour |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $line = 0;
  while ( $code =~ /^(?:([^\n]{81})(?:([^\n]{20})(?:([^\n]{20})([^\n]{12})?)?)?|[^\n]*)/mg ) {
	$line++;
    if (defined $1) 
    {
      $Nbr_LongLines80++;
      Erreurs::VIOLATION(Ident::Alias_LongLines80(), "Line $line exceeds 80 characters");
    }
    if (defined $2) 
    {
	  Erreurs::VIOLATION(Ident::Alias_LongLines100(), "Line $line exceeds 100 characters");
      $Nbr_LongLines100++;
    }
    if (defined $3) 
    {
	  Erreurs::VIOLATION(Ident::Alias_LongLines120(), "Line $line exceeds 120 characters");
      $Nbr_LongLines120++;
    }
    if (defined $4) 
    {
	  Erreurs::VIOLATION(Ident::Alias_LongLines132(), "Line $line exceeds 132 characters");
      $Nbr_LongLines132++;
    }
  }
  }

  $retour |= Couples::counter_add($compteurs, Ident::Alias_LongLines80(), $Nbr_LongLines80);
  $retour |= Couples::counter_add($compteurs, Ident::Alias_LongLines100(), $Nbr_LongLines100);
  $retour |= Couples::counter_add($compteurs, Ident::Alias_LongLines120(), $Nbr_LongLines120);
  $retour |= Couples::counter_add($compteurs, Ident::Alias_LongLines132(), $Nbr_LongLines132);

  return $retour;
}


1;
