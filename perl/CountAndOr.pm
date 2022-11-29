#----------------------------------------------------------------------#
#                 @ISOSCOPE 2008                                       #
#----------------------------------------------------------------------#
#       Auteur  : ISOSCOPE SA                                          #
#       Adresse : TERSUD - Bat A                                       #
#                 5, AVENUE MARCEL DASSAULT                            #
#                 31500  TOULOUSE                                      #
#       SIRET   : 410 630 164 00037                                    #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Plugin


package CountAndOr;
# les modules importes
use strict;
use warnings;
use Erreurs;

# prototypes publics
sub CountAndOr($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des opérateur || et &&
#-------------------------------------------------------------------------------

sub CountAndOr($$$)
{
  my ($fichier, $vue, $compteurs) = @_ ;
  my $status = 0;

  my $mnemo_AndOr = Ident::Alias_AndOr();
  my $nbr_AndOr = 0;

  #my $code = $vue->{'code'};
  my $r_code = Vues::getView($vue, 'code');

  if (!defined $r_code)
  {
    $status |= Couples::counter_add($compteurs, $mnemo_AndOr, Erreurs::COMPTEUR_ERREUR_VALUE);
    $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    return $status
  }
  # On ne tient pas compte des mots-cles C++89: and, and_eq, or, or_eq, xor, xor_eq
  $nbr_AndOr = () = $$r_code =~ /(\|\||\&\&)/sg ;
  $status |= Couples::counter_add($compteurs, $mnemo_AndOr, $nbr_AndOr);

  return $status;
}


1;
