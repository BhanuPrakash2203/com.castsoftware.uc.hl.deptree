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

package CountCComments;
# les modules importes
use strict;
use warnings;
use Erreurs;
use Couples;

# prototypes publics
sub CountCComments($$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des commentaires type C (/* ... */).
#
# LANGAGES: C++, C#, Java
#-------------------------------------------------------------------------------
sub CountCComments($$$$)
{
  my ($fichier, $vue, $compteurs, $options) = @_ ;
  my $status = 0;

  my $nbr_CComments = 0;
  my $mnemo_CComments = Ident::Alias_CComments();

  if (!defined $vue->{'comment'})
  {
    $status |= Couples::counter_add($compteurs, $mnemo_CComments, Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    return $status;
  }

  my @TLines = split(/\n/, $vue->{'comment'});

  foreach my $line (@TLines)
  {
    # reperage des marqueurs de fin de commentaire type C
    if ( $line =~ /\*\// )
    {
      $nbr_CComments++;
    }
  }

  $status |= Couples::counter_add($compteurs, $mnemo_CComments, $nbr_CComments);

  return $status;
}

1;
