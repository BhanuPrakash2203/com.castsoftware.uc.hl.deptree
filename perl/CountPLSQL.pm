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

# Description: Composant de mesure de source PL/SQL, pour creation d'alertes

package CountPLSQL;
use strict;
use warnings;

use Carp::Assert; # Erreurs::LogInternalTraces
use Erreurs;
use Couples;
#use TraceDetect;


# prototypes
sub CountStarImport($$$$);
sub CountOutOfFinallyJumps($$$$);
sub CountIllegalThrows($$$$);

# compte le nombre d'expressions regulieres
# en etant sensitif a la casse.
sub count_re($$)
{
    my ($sca, $re) = @_ ;
    my $n;
    $n = () = $sca =~ /$re/smg ;
    return $n;
}


# Comptage generique d'expressions rationnelles
sub GenericReCount($$$$)
{
    my ($buffer, $re, $couples, $mnemo) = @_;
    my $status = 0;
    my $n = count_re ($buffer, $re); # comptage des lettres ASCII
    $status |= Couples::counter_add($couples, $mnemo, $n );
    return $status;
}

1;

