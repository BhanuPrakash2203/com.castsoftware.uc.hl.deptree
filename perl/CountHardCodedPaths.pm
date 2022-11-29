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

package CountHardCodedPaths;

use strict;
use warnings;
use Erreurs;

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des chemins d'include en dur dans le code.
#
# COMPATIBILITE: C, CPP
#-------------------------------------------------------------------------------
sub CountHardCodedPaths($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  my $debug = 0; # Erreurs::LogInternalTraces;

  #my $code = $vue->{code};
  my $r_code = Vues::getView($vue, "code");
  my $HStrings = $vue->{HString};
  my $nb_HardPaths = 0;

  if ( ( ! defined $r_code) || ( ! defined $vue->{HString} ) )
  {
    $ret |= Couples::counter_add($compteurs, Ident::Alias_HardCodedPaths(), Erreurs::COMPTEUR_ERREUR_VALUE);
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE; 
  }

  # traitement des include de la forme #include "...", ie #include CHAINE_X_Y dans le code preprocesse.
  # traitement des include de la forme #include <...>
  while ( $$r_code =~ /(#\s*(?:include|import)\s*((CHAINE_\d+)|(<\s*(\/|\w:\\))).*?\n)/sg )
  {
    my $match_all = $1;
    my $match_key = $3;
    my $match_inferieur = $4;
    if (defined $match_inferieur)
    {
      $nb_HardPaths++;
      print "match_all:$match_all\n" if ($debug);  # Erreurs::LogInternalTraces
    }
    if (defined $match_key)
    {
      my $chaine = $HStrings->{$match_key};
      if ( !defined $chaine )
      {
        print STDERR "[CountHardCodedPaths] cle de chaine non associee : $match_key\n";
      }
      elsif ( $chaine =~ /^"\s*(\/|\w:\\)/)
      {
        $nb_HardPaths++;
        print "match_all:$match_all\n" if ($debug);  # Erreurs::LogInternalTraces
        print "KEY ($match_key) ==> $chaine \n\n"  if ($debug);  # Erreurs::LogInternalTraces
      }
    }
  }

  $ret |= Couples::counter_add($compteurs, Ident::Alias_HardCodedPaths(), $nb_HardPaths);

  return $ret;

}


1;

