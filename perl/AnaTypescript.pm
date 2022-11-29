package AnaTypescript;
use strict;
use warnings;
use Erreurs;
use StripTypescript;
use AnaUtils;
use Vues;
use Timeout;
use IsoscopeDataFile;

use CloudReady::CountNodeJS;
use CloudReady::detection;
 use TypeScript::ParseTypeScript;

sub Strip($$$$)
{
  my ($fichier, $vue, $options, $couples) =@_ ;

  my $status = 0;

  eval
  {
    $status = StripTypescript::StripTypescript($fichier, $vue, $options, $couples);
  };
  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Erreur dans la phase Strip: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }                                                                            # dumpvues_filter_line

  return $status;
}

 sub Parse($$$$) {
	 my ($fichier, $vue, $options, $compteurs) =@_ ;
	 my $status = 0;
	 eval {
		 $status |= TypeScript::ParseTypeScript::Parse($fichier, $vue, $compteurs, $options);
	 };
	 if ($@ ) {
		 Timeout::DontCatchTimeout();   # propagate timeout errors
		 print STDERR "Error encountered when parsing: $@ \n" ;
		 $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;  #   FIXME : should indicate a problem in the parse
	 }
	 return $status;
 }

 sub Count($$$$$) {
	 my (  $fichier, $vue, $options, $compteurs, $r_TableFonctions) = @_;
	 my $status = AnaUtils::Count ($fichier, $vue, $options, $compteurs, $r_TableFonctions );

	 if (defined $options->{'--CloudReady'}) {
		 CloudReady::detection::setCurrentFile($fichier);
		 $status |= CloudReady::CountNodeJS::CountNodeJS( $fichier, $vue, $options, "Typescript");
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

        my $ConfigModul='Typescript_Conf';
        if (defined $options->{'--conf'}) {
          $ConfigModul=$options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'})
        {
            IsoscopeDataFile::csv_file_type_register("Typescript", $r_TableMnemos);
        }
        
        #------------------ init CloudReady detections -----------------------
		if (defined $options->{'--CloudReady'}) {
			CloudReady::detection::init($options, 'Typescript');
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


