
# Composant: Plugin
#----------------------------------------------------------------------#
# Description: Module d'analyse pour le langage JS
#----------------------------------------------------------------------#

package AnaJS;
use strict;
use warnings;
use Erreurs;
use StripJS;
use AnaUtils;
use Vues;
use Timeout;
use IsoscopeDataFile;
use JS::ParseJS;
use JS::CheckJS;
use CloudReady::CountNodeJS;

sub Strip($$$$)
{
  my ($fichier, $vue, $options, $couples) =@_ ;

  my $status = 0;

  eval
  {
    $status = StripJS::StripJS($fichier, $vue, $options, $couples);
  };
  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Erreur dans la phase Strip: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }

  if (($fichier ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'}) # dumpvues_filter_line
  {                                                                            # dumpvues_filter_line
    Vues::dump_vues( $fichier, $vue, $options);                                # dumpvues_filter_line
  }                                                                            # dumpvues_filter_line

  return $status;
}

sub Parse($$$$)
{
  my ($fichier, $vue, $options, $compteurs) =@_ ;
  my $status = 0;
  eval
  {
    $status |= JS::ParseJS::Parse ($fichier, $vue, $compteurs, $options);
  };
  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Erreur dans la phase Parsing: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }


  return $status;
}

sub Count($$$$$)
{
    my (  $fichier, $vue, $options, $compteurs, $r_Tab_Fonctions) = @_;
    #my $status = AnaUtils::Count( $fichier, $vue, $options, $couples, \@TableCounters);
    my $status = 0;

    if (defined $options->{'--no-unit'}) {
      # Use standard mode, where the analysis unit is the "file"
      $status = AnaUtils::Count ($fichier, $vue, $options, $compteurs, $r_Tab_Fonctions );
    }
    else {
      $status = AnaUtils::CountForSeveralUnits ($fichier, $vue, $options, $compteurs, $r_Tab_Fonctions, \&JS::ParseJS::getNextUnit);
    }
    # For CloudReady, use standard file mode or unit mode
    if (defined $options->{'--CloudReady'}) {
        CloudReady::detection::setCurrentFile($fichier);
        $status |= CloudReady::CountNodeJS::CountNodeJS( $fichier, $vue, $options, "JS");
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

        my $ConfigModul='JS_Conf';
        if (defined $options->{'--conf'}) {
          $ConfigModul=$options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'})
        {
            IsoscopeDataFile::csv_file_type_register("JS", $r_TableMnemos);
        }
        
        #------------------ init CloudReady detections -----------------------
		if (defined $options->{'--CloudReady'}) {
			CloudReady::detection::init($options, 'JS');
		}
  }
}


sub Analyse($$$$)
{
  my ( $fichier, $vue, $options, $couples) = @_;
  my $status = 0;

  FileTypeRegister ($options);

  my ($erreur_checkJS, $abort_cause) = JS::CheckJS::CheckCodeAvailability( \$fichier, \$vue->{'text'}, $options );
  if ( defined $erreur_checkJS )
  {
    return $status | Erreurs::FatalError( $abort_cause, $couples, $erreur_checkJS);
  }

  $status |= $confStatus;

  my $analyseur_callbacks = [ \&Strip, \&Parse, \&Count, $r_TableFonctions ];
  $status |= AnaUtils::Analyse($fichier, $vue, $options, $couples, $analyseur_callbacks) ;

  if (($status & ~Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES))
  {
    # continue si Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES seul
    print STDERR "$fichier : Echec de pre-traitement\n";
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


