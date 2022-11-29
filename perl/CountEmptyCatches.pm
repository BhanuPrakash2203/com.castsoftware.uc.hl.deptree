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

package CountEmptyCatches;

use strict;
use warnings;
use Erreurs;

# prototypes publiques
sub CountEmptyCatches($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des instructions Catch vide.
#-------------------------------------------------------------------------------
sub CountEmptyCatches($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $mnemo_EmptyCatches = Ident::Alias_EmptyCatches();
  my $status = 0;
  my $code;

  if ( ! defined $vue->{'code'} ) {
    $status |= Couples::counter_add($compteurs, $mnemo_EmptyCatches, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  $code = $vue->{'code'};

  # FIXME: optimisation possible pour attraper plus de catches vides:
  # FIXME: Suppression des imbrications d'accolades vides:
  # FIXME: - { { } } est remplace par { }
  # FIXME: - { } { } est remplace par { }
  # FIXME: - { ; } est remplace par { }
  # FIXME: while ( $code =~ s/\{[\s\n]*\{[\s\n]*\}[\s\n]*\}|\{[\s\n]*\}[\s\n]*\{[\s\n]*\}|\{[\s\n]*;+[\s\n]*\}/\{\}/sg ) { }

  my $nbr_EmptyCatches = () = $code =~ /\bcatch\b[^\{]*\{(\s|\n)*\}/sg ;

  $status |= Couples::counter_add($compteurs, $mnemo_EmptyCatches, $nbr_EmptyCatches);

  return $status;

}


1;

