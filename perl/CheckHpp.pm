#----------------------------------------------------------------------#
#                         @ISOSCOPE 2008                               #
#----------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                  #
#               Adresse : TERSUD - Bat A                               #
#                         5, AVENUE MARCEL DASSAULT                    #
#                         31500  TOULOUSE                              #
#               SIRET   : 410 630 164 00037                            #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Plugin
# Description: Module de verification de l'adequation de l'analyseur pour le fichier.

package CheckHpp;


sub _DetectClassKeywords($)
{
  my ($buffer) = @_;

  if ($buffer !~ m/\bclass\s\s*\w/sgm) {
      return 'does not contain C++ class keyword';
  }

  return undef; # Pas d'erreur, le code ressemble a un fichier declarant une classe.
}

sub CheckCodeAvailability($)
{
  my ($buffer) = @_;
  return ( _DetectClassKeywords($buffer)  )
}


1;
