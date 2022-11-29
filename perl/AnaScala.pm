package AnaScala;
use strict;
use warnings;
use Erreurs;
use StripScala;
use AnaUtils;
use Vues;
use Timeout;
use IsoscopeDataFile;
use CloudReady::CountScala;
use CloudReady::detection;
use Scala::ParseScala;

sub Strip($$$$)
{
    my ($fichier, $vue, $options, $couples) = @_;

    my $status = 0;

    eval
    {
        $status = StripScala::StripScala($fichier, $vue, $options, $couples);
    };
    if ($@) {
        Timeout::DontCatchTimeout(); # propagate timeout errors
        print STDERR "Erreur dans la phase Strip: $@ \n";
        $status = Erreurs::COMPTEUR_STATUS_PB_STRIP;
    }

    if (($fichier ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'}) # dumpvues_filter_line
    {                                                                            # dumpvues_filter_line
        Vues::dump_vues($fichier, $vue, $options);                               # dumpvues_filter_line
    }                                                                            # dumpvues_filter_line

    return $status;
}

sub Parse($$$$) {
	my ($fichier, $vue, $options, $compteurs) =@_ ;
	my $status = 0;
	eval {
		$status |= Scala::ParseScala::Parse($fichier, $vue, $compteurs, $options);
	};
	if ($@ ) {
		Timeout::DontCatchTimeout();   # propagate timeout errors
		print STDERR "Error encountered when parsing: $@ \n" ;
		$status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;  #   FIXME : should indicate a problem in the parse
	}
	return $status;
}

 sub Count($$$$$) {
     my ($fichier, $vue, $options, $compteurs, $r_TableFonctions) = @_;
     my $status = AnaUtils::Count($fichier, $vue, $options, $compteurs, $r_TableFonctions);

	 if (defined $options->{'--CloudReady'}) {
		 CloudReady::detection::setCurrentFile($fichier);
		 $status |= CloudReady::CountScala::CountScala( $fichier, $vue, $options);
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

    if ($firstFile != 0) {
        $firstFile = 0;

        #------------------ Chargement des comptages a effectuer -----------------------

        my $ConfigModul = 'Scala_Conf';
        if (defined $options->{'--conf'}) {
            $ConfigModul = $options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'}) {
            IsoscopeDataFile::csv_file_type_register("Scala", $r_TableMnemos);
        }

        #------------------ init CloudReady detections -----------------------
        if (defined $options->{'--CloudReady'}) {
            CloudReady::detection::init($options, 'Scala');
        }
    }
}


sub Analyse($$$$)
{
    my ($fichier, $vue, $options, $couples) = @_;
    my $status = 0;

    FileTypeRegister($options);

    $status |= $confStatus;

    my $analyseur_callbacks = [ \&Strip, \&Parse, \&Count, $r_TableFonctions ];
    $status |= AnaUtils::Analyse($fichier, $vue, $options, $couples, $analyseur_callbacks);

    if ($vue->{'code'} !~ /\S/) {
        # reinitialize code vue because not workable
        my $message = 'Fatal error not enough code to analyze';
        Erreurs::LogInternalTraces('erreur', undef, undef, 'STRIP // ABORT_CAUSE_NOT_ENOUGH_CODE', $message);
        return Erreurs::FatalError(Erreurs::ABORT_CAUSE_NOT_ENOUGH_CODE, $couples, $message);
    }

    if (($status & ~Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES)) {
        # continue si Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES seul
        print STDERR "$fichier : Echec de pre-traitement\n";
    }

    if (Erreurs::isAborted($status)) {
        # si le strip genere une erreur fatale,
        # on ne fera pas de comptages
        return $status;
    }

    return $status;
}

1;


