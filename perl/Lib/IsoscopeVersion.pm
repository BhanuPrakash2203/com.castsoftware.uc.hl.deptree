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
# DESCRIPTION: Composant recuperation de la version de l'application compteurs
#----------------------------------------------------------------------#

package Lib::IsoscopeVersion;

# les modules importes
use strict;
use warnings;

my $HighlightVersion = "5.4.47-RELEASE";
my $HighlightSvnVersion = "SVNversion";

# prototypes publics
sub version();
sub getHighlightVersion();

# prototypes prives

# Recuperation du chemin ou ce logiciel est installe
sub getSoftwarePath()
{
  my $base_name = $0; # $PROGRAM_NAME
  $base_name =~ m/(.*[\\\/])/;
  my $base_rep =$1;
  return $base_rep;
}

sub getHighlightVersion() {
 return $HighlightVersion;
}

# recuperation de la verison du data model, pour un analyseur (au sens plugin) donne.
sub getVersionFromFile($$)
{
  my ($filename, $default_value) = @_;
  my $version = 'unspecified';

  my $base_rep =getSoftwarePath();

  my $is_opened = open (C, '<:raw', ($base_rep || '') . $filename);

  if (not defined $is_opened)
  {
    # Le fichier texte de version ne peut etre lu
    $version = $default_value;
  }
  else
  {
    local $/ = undef;
    $version = <C>;
    $version =~ s/[\r\n]*//g ;
    close(C);
  }

  my $ver = $version ;

  return $ver;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction de recuperation de la version de l'application compteurs
#-------------------------------------------------------------------------------
sub version()
{
  my $perl_version = '';
  $perl_version = sprintf  "%vd", $^V;
  my $perl_provider = $^O;

  if ( $^O eq 'MSWin32' )
  {
    eval
    {
      require 'ActivePerl.pm';
      $perl_provider .= ' ActivePerl';
    };
  }

  #my $tool_version = 'unspecified';

  my $tool_version = getVersionFromFile( 'version.txt', 'unspecified' );

  my $ver = $tool_version . ' ( perl ' . $perl_version . ' ' . $perl_provider . ' )';

  return $ver;
}


# recuperation de la verison du data model, pour un analyseur (au sens plugin) donne.
sub GetDataModelVersion($)
{
  #my ($datamodelversion_filename) = @_;
  my ($datamodelversion_name) = @_;
  #my $datamodel_version = 'unspecified';

  my $ver = getVersionFromFile( 'version_' . $datamodelversion_name . '.txt' , 'unspecified' );

  return $ver;
}

1;
