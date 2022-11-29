package AnaJavaSP;
# les modules importes
use strict;
use warnings;

use Erreurs;
use StripJSP;
use StripJava;
use AnaJSP;
use AnaJava;
use AnaUtils;
use Vues; # dumpvues_filter_line
use Timeout;
use IsoscopeDataFile;

# prototypes publics
sub Strip ($$$$);
sub Count ($$$$$);
sub Analyse ($$$$);
sub FileTypeRegister ($$$);

# prototypes prives
my $DETECTED_LANGUAGE = 'JSP';

#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement du strip
#-------------------------------------------------------------------------------

sub getStrip($) {
	my $detectedLang = shift;

	if ($detectedLang eq 'JSP') {
		return \&AnaJSP::Strip;
	}
	elsif ($detectedLang eq 'Java') {
		return \&AnaJava::Strip;
	}
	return undef;
}


sub Parse($$$$)
{
  my ($fichier, $vue, $options, $compteurs) =@_ ;

  my $status = 0;

  if ($DETECTED_LANGUAGE eq 'JSP') {
    $status |= AnaJSP::Parse($fichier, $vue, $options, $compteurs);
  }
  elsif ($DETECTED_LANGUAGE eq 'Java') {
    $status |= AnaJava::Parse($fichier, $vue, $options, $compteurs);
  }

  return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement des comptages
#-------------------------------------------------------------------------------
sub Count ($$$$$)
{
  my ($fichier, $vue, $options, $compteurs, $r_TableFonctions) = @_;
  my $status = 0;

  if ($DETECTED_LANGUAGE eq 'JSP') {
    AnaJSP::Count($fichier, $vue, $options, $compteurs, $r_TableFonctions);
  }
  elsif ($DETECTED_LANGUAGE eq 'Java') {
    AnaJava::Count($fichier, $vue, $options, $compteurs, $r_TableFonctions);
  }
  else {
    print "[AnaJavaSP] ERROR : unknow detected language $DETECTED_LANGUAGE !!\n";
    # FIXME : should raise an error !!!
  }

  return $status;
}

# Ces variables doivent etre globales dans le cas nominal (dit nocrashprevent)
my %firstFile = ();
my %H_Mnemos = ();
my %H_Functions = ();
my %H_Status = ();

my ($r_TableMnemos, $r_TableFonctions );
my $confStatus = 0;

sub FileTypeRegister_notAnalysed($$$) {
  my ($fichier, $counters, $options) = @_;

  $DETECTED_LANGUAGE = get_JSP_SubTechno($fichier);
  return FileTypeRegister($DETECTED_LANGUAGE, $counters, $options);
}

# Module d'enregistrement des compteurs pour la sortie .csv
sub FileTypeRegister ($$$)
{
  my ($detectedLanguage, $counters, $options) = @_;

  # Update of CSV data depending on the detected language. (by default, data would be
  # related to the master techno analyseur, but it would lead to an alarm generation error, because
  # there is no model related to it) .
  my $ret = Couples::counter_modify($counters, 'Dat_AnaModel', Lib::IsoscopeVersion::GetDataModelVersion($detectedLanguage) ) ;
  $ret = Couples::counter_modify($counters, 'Dat_Language', $detectedLanguage ) ;
print "Dat_Language set to : $detectedLanguage\n";

  # Load mnemonics for the corresponding language.
  if (! exists $H_Mnemos{$detectedLanguage})
  {
        #------------------ Chargement des comptages a effectuer -----------------------

        my $ConfigModul="$detectedLanguage"."_Conf";
        if (defined $options->{'--conf'}) {
          $ConfigModul=$options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'})
        {
            IsoscopeDataFile::csv_file_type_register($detectedLanguage, $r_TableMnemos);
        }

	$H_Mnemos{$detectedLanguage} = $r_TableMnemos;
	$H_Functions{$detectedLanguage} = $r_TableFonctions;
        $H_Status{$detectedLanguage} = $confStatus;
  }
  else {
    $r_TableMnemos = $H_Mnemos{$detectedLanguage};
    $r_TableFonctions = $H_Functions{$detectedLanguage};
    $confStatus = $H_Status{$detectedLanguage};
  }
}

sub get_JSP_SubTechno($$) {
  my $fichier = shift;
  my $vues = shift;

  if ( $fichier =~ /\.java$/i) {
    return 'Java';
  }

  return 'JSP';
}

#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement de l'analyse
#-------------------------------------------------------------------------------
sub Analyse ($$$$)
{
  my ($fichier, $vues, $options, $couples) = @_;
  my $status = 0;

  # Detect if language is JSP or Java.
  $DETECTED_LANGUAGE = get_JSP_SubTechno($fichier, $vues);
print "sub-techno is : ".$DETECTED_LANGUAGE."\n";

  # load 
  FileTypeRegister ($DETECTED_LANGUAGE, $couples, $options);

  $status |= $confStatus;

  my $Strip = getStrip($DETECTED_LANGUAGE);

  my $analyseur_callbacks = [ $Strip, \&Parse, \&Count, $r_TableFonctions, undef ];
  $status |= AnaUtils::Analyse($fichier, $vues, $options, $couples, $analyseur_callbacks) ;

  if (($status & ~Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES))
  {
    # continue si Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES seul
    my $message = 'syntax inconsistency encountered (parentheses, curly brackets, ... )';
    Erreurs::LogInternalTraces ('verbose', undef, undef, 'AnaJavaSP', $message);
  }

  return $status;
}

1;
