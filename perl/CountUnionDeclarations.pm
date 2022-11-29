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

package CountUnionDeclarations;
# les modules importes
use strict;
use warnings;
use Erreurs;
use Couples;

# prototypes publics
sub CountUnionDeclarations($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des declarations d'union.
#
# LANGAGES: C, C++
#-------------------------------------------------------------------------------
sub CountUnionDeclarations($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $status = 0;
  my $mnemo_Union = Ident::Alias_Union();

  if ( ! defined $vue->{'code'} ) {
    $status |= Couples::counter_add($compteurs, $mnemo_Union, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  # on ne compte pas les utilisations. En effet, il peut y avoir utilisation d'une union a cause d'une union importee d'un include systeme par exemple.
  my $nbr_Union = () = $vue->{'code'} =~ /\bunion\b\s+(\w+)\s*[;|\{]/sg ;

  $status |= Couples::counter_add($compteurs, $mnemo_Union, $nbr_Union);

  return $status;
}


1;
