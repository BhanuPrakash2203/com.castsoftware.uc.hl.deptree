
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

# Composant: Framework
# Module de comptages de lignes

# Ce package ne commence pas par Count car il 
# fait partie du composant framework
# et non d'un analyseur
package FileLines;

# les modules importes
use strict;
use warnings;


# Routine de comptage du nombre de lignes du buffer
sub _CountLines($)
{
  my ($sca) = @_;
  my $n = () = $sca =~ /\n/smgo;
  return $n;
}

sub CountFileLines($$$)
{
  my ($force, $vue, $compteurs) = @_;
  my $status = 0;
  my $NbrLines = _CountLines ( $vue->{ 'text' } );

  if (defined $force) {
    Couples::counter_modify($compteurs, 'Nbr_Lines', $NbrLines);
    Couples::counter_modify($compteurs, 'Dat_Lines', $NbrLines);
  }
  else {
    Couples::counter_add($compteurs, 'Nbr_Lines', $NbrLines);
    Couples::counter_add($compteurs, 'Dat_Lines', $NbrLines);
  }
  return $status;
}


1;
