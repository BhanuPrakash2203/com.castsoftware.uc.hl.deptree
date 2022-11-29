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


package CountPragmas;

# les modules importes
use strict;
use warnings;
use Erreurs;

# prototypes publics
sub CountPragmas ($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des directives de compilations #pragma
#
# LANGAGES: C, CPP, CS
#-------------------------------------------------------------------------------

sub CountPragmas ($$$) {

  my ($fichier, $vue, $compteurs) = @_ ;
  my $status = 0;
  my $mnemo_Pragmas = Ident::Alias_Pragmas();
  my $code = $vue->{'prepro_directives'};

  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, $mnemo_Pragmas, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nbr_Pragmas = () = $code =~ /#\s*(pragma)/sg ;

  $status |= Couples::counter_add($compteurs, $mnemo_Pragmas, $nbr_Pragmas);

  return $status;
}


1;
