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


package Options;

# les modules importes
use strict;
use warnings;

use Traces;

# prototypes publics

# Pour le traitement generique des options
sub traite_options($);

# autres prototypes publics
sub rec_mkdir_forfile($);
sub rec_mkdir($);

# prototypes prives

#-------------------------------------------------------------------------------
# DESCRIPTION: Traitement des options de la ligne de commande.
#-------------------------------------------------------------------------------
sub traite_options($)
{
  my ($r_args) = @_;
  my @args = @{$r_args};
  my %h_options =();
  my $options = \%h_options ;
  my @fichiers = ();

  while ( $#args > -1)
  {
    my $opt =  $args[0] ;
    if ($opt =~ /^--?([^=]*)(?:=(.*))?/)
    {
      my $key = '--' . $1;
      my $val = $2;
      if (not defined $val)
      {
        # option booleenne
        $val = '' ;
      }
      $options->{$key}=$val;
    }
    else
    {
      # l'argument n'est pas une option donc un nom de fichier a traiter
        # on a directement le nom du fichier a analyse
        push @fichiers, $opt;
    }
    shift (@args);
  }

  return ($options, \@fichiers);
}

# DESCRIPTION: Fonction de creation d'un repertoire a partir d'un nom de fichier
sub rec_mkdir_forfile($)
{
  my ($output_filename) = @_;

  if ( $output_filename =~ m{(.*/).*} )
  {
    my $output_dir = $output_filename;
    #print STDERR "Creation de $output_dir\n";
    $output_dir =~ s{(.*/).*}{$1}smg ;
    rec_mkdir ($output_dir);
  }
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction recursive: declaration prealable.
#-------------------------------------------------------------------------------
sub rec_mkdir($);

#-------------------------------------------------------------------------------
# DESCRIPTION: Fait en perl, pour portabilite windows
# equivalent de la commande unix suivante: system ( "mkdir -p ". $dir);
#-------------------------------------------------------------------------------
sub rec_mkdir($)
{
  my ($p_dir) = @_;

  if ( not -d $p_dir )
  {
    #print STDERR "Demande de creation de $p_dir\n" ; # traces_filter_line

    my $dir = $p_dir ;

    if ( $dir =~ s{(.*)/.*}{$1}smg )
    {
      {
        rec_mkdir($dir);
      }
    }
    mkdir ( $p_dir);
  }
}

1;
