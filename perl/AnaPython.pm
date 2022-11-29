# Composant: Plugin
#----------------------------------------------------------------------#
# Description: Module d'analyse pour le langage Python
#----------------------------------------------------------------------#

package AnaPython;
use strict;
use warnings;
use Erreurs;
use StripPython;
use Python::ParsePython;
use AnaUtils;
use Vues;
use Timeout;
use IsoscopeDataFile;

use CloudReady::CountPython;
use CloudReady::detection;

sub Strip($$$$)
{
  my ($fichier, $vue, $options, $couples) =@_ ;

  my $status = 0;

  eval
  {
    $status = StripPython::StripPython($fichier, $vue, $options, $couples);
  };
  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Error during strip: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }

  if (($fichier ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'}) # dumpvues_filter_line
  {                                                                            # dumpvues_filter_line
    Vues::dump_vues( $fichier, $vue, $options);                                # dumpvues_filter_line
  }                                                                            # dumpvues_filter_line

  return $status;
}

sub Parse($$$$) {
	my ($fichier, $vue, $options, $compteurs) =@_ ;
	my $status = 0;
	eval {
		$status |= Python::ParsePython::Parse ($fichier, $vue, $compteurs, $options);
	};
	if ($@ ) {
		Timeout::DontCatchTimeout();   # propagate timeout errors
		print STDERR "Erreur dans la phase Parsing: $@ \n" ;
		$status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
	}
	return $status;
}

sub Count($$$$$)
{
    my (  $fichier, $vue, $options, $compteurs, $r_TableFonctions) = @_;
    my $status = AnaUtils::Count ($fichier, $vue, $options, $compteurs, $r_TableFonctions );
    
    if (defined $options->{'--CloudReady'}) {
        CloudReady::detection::setCurrentFile($fichier);
        $status |= CloudReady::CountPython::CountPython( $fichier, $vue, $options);
    }
    return $status;
}


# Ces variables doivent etre globales dnas le cas nominal (dit nocrashprevent)
my $firstFile = 1;
my ($r_TableMnemos, $r_TableFonctions );
my $confStatus = 0;

sub FileTypeRegister ($)
{
  my ($options) = @_;

  if ($firstFile != 0)
  {
        $firstFile = 0;

        #------------------ Chargement des comptages a effectuer -----------------------

        my $ConfigModul='Python_Conf';
        if (defined $options->{'--conf'}) {
          $ConfigModul=$options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'})
        {
            IsoscopeDataFile::csv_file_type_register("Python", $r_TableMnemos);
        }
        
        #------------------ init CloudReady detections -----------------------
		if (defined $options->{'--CloudReady'}) {
			CloudReady::detection::init($options, 'Python');
		}
  }
}


sub Analyse($$$$)
{
  my ( $fichier, $vue, $options, $couples) = @_;
  my $status = 0;

  FileTypeRegister ($options);

  $status |= $confStatus;

  my $analyseur_callbacks = [ \&Strip, \&Parse, \&Count, $r_TableFonctions ];
  $status |= AnaUtils::Analyse($fichier, $vue, $options, $couples, $analyseur_callbacks) ;

  if (($status & ~Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES))
  {
    # continue si Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES seul
    print STDERR "$fichier : Error when preprocessing\n";
  }

  if ( Erreurs::isAborted($status) )
  {
    # si le strip genere une erreur fatale,
    # on ne fera pas de comptages
    return $status;
  }

  return $status ;
}

1;


