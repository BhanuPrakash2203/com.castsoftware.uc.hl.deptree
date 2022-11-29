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

package CountRiskyCatches;

use strict;
use warnings;
use Erreurs;

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des instructions Catch "risques" : catch (...) etc ....
#
# COMPATIBILITE: CPP, JAVA
#-------------------------------------------------------------------------------
sub CountRiskyCatches($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $mnemo_RiskyCatches = Ident::Alias_RiskyCatches();
  my $status = 0;

  if ( ! defined $vue->{code} ) {
    $status |= Couples::counter_add($compteurs, $mnemo_RiskyCatches, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nbr_RiskyCatches = () = $vue->{code} =~ /\bcatch\b\s*\(\s*(\.\.\.|\bException\b|\bThrowable\b|\bSystemException\b|\bRuntimeException\b|\bError\b)/sg ;

  $status |= Couples::counter_add($compteurs, $mnemo_RiskyCatches, $nbr_RiskyCatches);

  return $status;

}


1;

