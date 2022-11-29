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
# dedie a l'outil de comptage.
#----------------------------------------------------------------------#


package AnalyseOptions;

# les modules importes
use strict;
use warnings;

use Options;

sub GetFileList($)
{
  my ($options) = @_;
  #if (exists($options->{'--file-list'}))
   my $FilelistOption = $options->{'--file-list'};
  return $FilelistOption;
}

sub GetChangeDirectory($)
{
  my ($options) = @_;
  my $ChangeDirectoryOption = $options->{'--change-directory'};
  return $ChangeDirectoryOption;
}

#bt_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: recuperation du nom du fichier de resultat
#-------------------------------------------------------------------------------
sub GetOutputFile($$)
{
  my ($options, $option_name) = @_;
  my $outputFile  = undef;
  my $value = $options->{$option_name} ;

  if (defined $value and  $value ne '')
  {
    $outputFile = $value ;
  }
  return $outputFile;
}

#bt_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: recuperation du repertoire sommet
# d'arborescence de fichiers de resultats
#-------------------------------------------------------------------------------
sub GetOutputDirectory($$)
{
  my ($options, $option_name) = @_;
  my $output_dir  = undef;
  my $v = $options->{$option_name} ;

  if (defined $v and  $v ne '')
  {
    $output_dir = $v . '/' ;
  }

  return $output_dir;
}


# Recuperation du repertoire dialogue avec l'IHM
sub GetDialogDirectory($)
{
  my ($options) = @_;
  return GetOutputDirectory($options, '--dir-dialog') ||
    'dialog/';
}

# Recuperation du repertoire contenant le code source fournit par l'IHM
sub GetSourceDirectory($)
{
  my ($options) = @_;
  return GetOutputDirectory($options, '--dir-source') ||
    '';
}

sub GetProgression($)
{
  my ($self) = @_;
  return $self->{'.progression'};
}

sub SetProgression($$)
{
  my ($self, $object) = @_;
  $self->{'.progression'} = $object;
}

sub GetTimingFilename($)
{
  my ($options) = @_;
  my $timing_output_dir  = GetOutputDirectory ( $options, '--timing-dir' ) ||
                           GetOutputDirectory ( $options, '--dir-debug' ) || # pour l'IHM
                           GetOutputDirectory ( $options, '--dir' ) ||
                            'output/met/' ;
  my $TimingFile = $timing_output_dir . 'timing.txt' ;
  return $TimingFile;
}


# Recuperation du chemin ou ce logiciel est installe
sub GetSoftwarePath()
{
  my $base_name = $0; # $PROGRAM_NAME
  $base_name =~ m/(.*[\\\/])/;
  my $base_rep =$1;
  return $base_rep;
}

# Recuperation du chemin ou le repertoire de configuration est installe
sub GetConfigDirectory()
{
  my $base_rep = GetSoftwarePath();
  return $base_rep . '/config/' ;
}

# DESCRIPTION: Charge les options definie dans un fichier.
#              Le format du fichier est :
#	<option>=<valeur>
sub load_ConfigFile($$)
{
  my ($options, $NomFichier) = @_;

  my $status = open (FILE_OPT, $NomFichier);

  if ( ! $status ) {
    print STDERR "Erreur d'ouverture du fichier de configuration $NomFichier\n";
    Traces::LogInternalTraces('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'chargement configuration', ''); # traces_filter_line
    die "Erreur d'ouverture du fichier de configuration $NomFichier";
  }

  local $/ = "\n";

  while (<FILE_OPT>) {
    my $line = $_ ;
    $line = ~s/[\r\n]  //sg;
    my ($key, $value) = m/^(\w+)=(.*)/m;
    if ( (defined $key) && (defined $value)) {
      print STDERR $options->{$key} . " = " . $value; # traces_filter_line
      $options->{$key} = $value;
    }
  }

  close FILE_OPT;
}

# DESCRIPTION: Renvoi un identifiant unique a la minute pres.
# L'unicite est garantie par le fait que le script n'est
# pas lance plus de deux fois, en moins d'une minute.
sub get_date_as_amj_hm()
{
 # recuperation de la date et de l'heure par localtime
 my ($S, $Mi, $H, $J, $Mo, $A) = (localtime) [0,1,2,3,4,5];
 return  sprintf('%04d%02d%02d_%02d%02d',
        eval($A+1900), eval( $Mo +1) , $J, $H, $Mi);
}


1;
