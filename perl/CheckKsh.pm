
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

package CheckKsh;



sub CheckLanguageCompatibility($)
{
  my ($buffer) = @_;

  # Following criteria are too restrictive. Content is checked externally by the Highlight discoverer.
  return undef;

  #if ($$buffer =~  /\A^#!\s*\/[\w\/]+\/(?:ksh|sh|bash)\W/)
  #{
  #  return undef;
  #}
  #if ($$buffer =~ /\bif\s*\[/)
  #{
  #  return undef;
  #}
  #return 'Does not seam to be Ksh';
}

1;

