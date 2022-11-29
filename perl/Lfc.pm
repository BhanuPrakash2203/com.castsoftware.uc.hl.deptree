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
#----------------------------------------------------------------------#
# DESCRIPTION: utilitaires de traitement d'options de la ligne de commande
#----------------------------------------------------------------------#


package Lfc;

# les modules importes
use strict;
use warnings;

use Traces;

# prototypes publics

# Pour le traitement generique des options
sub traite_options($$);

# autres prototypes publics

# prototypes prives
sub LoadLFC($);                                                                 # dumpvues_filter_line
sub get_date_as_a_m_j_h_m_s();                                                  # dumpvues_filter_line

#-------------------------------------------------------------------------------
# DESCRIPTION: Traitement des options de la ligne de commande.
#-------------------------------------------------------------------------------
sub traite_options($$)
{
  my ($inputFiles, $options) = @_;
  my @fichiers = ();

  for my $opt ( @{$inputFiles} )
  {

# dumpvues_filter_start

      # l'argument n'est pas une option donc un nom de fichier a traiter
      if ($opt=~ '\.lfc$')
      {
        # le fichier contient la liste des fichiers a analyser
        my @arr = LoadLFC($opt);
        push @fichiers, @arr;
        my $date = get_date_as_a_m_j_h_m_s();
        $options->{'--concatene-tous-les-comptages'} = $opt . '.COMPTAGES.' . $date .'.cptx';
      }
      else
      {
        push @fichiers, $opt;
      }
  }
  return \@fichiers;


}

#bt_filter_start


#-------------------------------------------------------------------------------
# DESCRIPTION: chargement d'une liste depuis un fichier.
# Les lements de la liste sont separes par $/
#-------------------------------------------------------------------------------
sub LoadLFC($)
{
  my ($lfc_name) = @_;

  my @arr_lfc;
  open STUFF_FIC_IN, "$lfc_name" or die "Cannot open $lfc_name for read :$!";
  while (<STUFF_FIC_IN>)
  {
    my $li = $_;
    $li =~ s/\r//;
    $li =~ s/\n//;
    my $line = $li;
    push(@arr_lfc, $line);
  }
  close STUFF_FIC_IN;
  my $nb_fic_lfc = @arr_lfc;
  print "# Liste des $nb_fic_lfc fichiers a analyser : \n";
  foreach my $fic (@arr_lfc)
  {
    print  "$fic\n";
  }
  print  "#######################\n";
  return @arr_lfc;
}


sub get_date_as_a_m_j_h_m_s()
{
 # recuperation de la date et de l'heure par localtime
 my ($S, $Mi, $H, $J, $Mo, $A) = (localtime) [0,1,2,3,4,5];
 return  sprintf('%04d_%02d_%02d_%02d_%02d_%02d',
        eval($A+1900), eval( $Mo +1) , $J, $H, $Mi, $S);
}

# dumpvues_filter_end


1;
