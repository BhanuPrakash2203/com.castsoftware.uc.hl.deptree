package AnaCCpp;
# les modules importes
use strict;
use warnings;

use Erreurs;
use StripCpp;
use AnaUtils;
use AnaConfiguration_H_C_HPP_CPP;
use CountC_CPP_FunctionsMethodsAttributes;
use Vues; # dumpvues_filter_line
use Timeout;
use IsoscopeDataFile;
use AnaCpp;
use AnaHpp;
use AnaC;
use CloudReady::CountCCpp;
use CloudReady::detection;

# prototypes publics
sub Strip ($$$$);
sub Count ($$$$$);
sub Analyse ($$$$);
sub FileTypeRegister ($$$);

# prototypes prives

my $DETECTED_LANGUAGE = 'Cpp';

#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement du strip
#-------------------------------------------------------------------------------
sub StripMaster ($$$$)
{
  my ($fichier, $vue, $options, $compteurs) =@_ ;
  my $status = 0;

  eval
  {
    $status = StripCpp::StripCpp ($fichier, $vue, $options, $compteurs);
  };

  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Error while striping at master level : $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }

  if ( Erreurs::isAborted($status) )
  {
    # si le strip genere une erreur, on ne continue pas
    return $status;
  }

  return $status;
}


# For Master technologies that groups severals primary technologies, the strip step is
# a generic process. If some primary technologies have a specific treatment, then it
# should be writen in a dedicated strip routine, provided by the corresponding analyzer.

sub getStripPrimary($) {
  my $detectedLang = shift;

  if ($detectedLang eq 'Hpp') {
    return \&AnaHpp::StripPrimary;
  }
  return undef;
}


sub Parse($$$$)
{
  my ($fichier, $vue, $options, $compteurs) =@_ ;

  my $status = 0;

  if ($DETECTED_LANGUAGE eq 'Cpp') {
    $status |= AnaCpp::Parse($fichier, $vue, $options, $compteurs);
  }
  elsif ($DETECTED_LANGUAGE eq 'Hpp') {
    $status |= AnaHpp::Parse($fichier, $vue, $options, $compteurs);
  }
  elsif ($DETECTED_LANGUAGE eq 'C') {
    $status |= AnaC::Parse($fichier, $vue, $options, $compteurs);
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

  if ($DETECTED_LANGUAGE eq 'Cpp') {
    AnaCpp::Count($fichier, $vue, $options, $compteurs, $r_TableFonctions);
  }
  elsif ($DETECTED_LANGUAGE eq 'Hpp') {
    AnaHpp::Count($fichier, $vue, $options, $compteurs, $r_TableFonctions);
  }
  elsif ($DETECTED_LANGUAGE eq 'C') {
    AnaC::Count($fichier, $vue, $options, $compteurs, $r_TableFonctions);
  }
  else {
    print "[AnaCCpp] ERROR : unknow language $DETECTED_LANGUAGE !!\n";
    # FIXME : should raise an error !!!
  }

  if (defined $options->{'--CloudReady'}) {
    CloudReady::detection::setCurrentFile($fichier);
    $status |= CloudReady::CountCCpp::CountCCpp( $fichier, $vue, $options);
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

  $DETECTED_LANGUAGE = get_CCPP_SubTechno_From_Extension($fichier);
  return FileTypeRegister($DETECTED_LANGUAGE, $counters, $options);
}

# Module d'enregistrement des compteurs pour la sortie .csv
sub FileTypeRegister ($$$)
{
  my ($detectedLanguage, $counters, $options) = @_;

  # Update of CSV data depending on the detected language. (by default, data would be
  # related to CCpp analyseur, but it would lead to an alarm generation error, because
  # ther is no model for "CCpp".). 
  my $ret = Couples::counter_modify($counters, 'Dat_AnaModel', Lib::IsoscopeVersion::GetDataModelVersion($detectedLanguage) ) ;
  $ret = Couples::counter_modify($counters, 'Dat_Language', $detectedLanguage ) ;
print "Dat_Language set to : $detectedLanguage\n";

  # Load mnemonics for the corresponding language.
  if (! exists $H_Mnemos{$detectedLanguage})
  {
    #------------------ Chargement des comptages a effectuer -----------------------

    my $ConfigModul = "$detectedLanguage" . "_Conf";
    if (defined $options->{'--conf'}) {
      $ConfigModul = $options->{'--conf'};
    }

    $ConfigModul =~ s/\.p[ml]$//m;

    ($r_TableMnemos, $r_TableFonctions, $confStatus) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

    AnaUtils::load_ready();

    #------------------ Enregistrement des comptages a effectuer -----------------------
    if (defined $options->{'--o'}) {
      IsoscopeDataFile::csv_file_type_register($detectedLanguage, $r_TableMnemos);
    }

    #------------------ init CloudReady detections -----------------------
    if (defined $options->{'--CloudReady'}) {
      CloudReady::detection::init($options, 'CCpp');
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

sub get_CCPP_SubTechno_From_Extension($) {
  my $fichier = shift;

  if ( $fichier =~ /\.h[\w\+]*$/i) {
    return 'Hpp';
  }

  if ( $fichier =~ /\.[p]?c*$/i) {
    return 'C';
  }

  return 'Cpp';
}

sub get_CCPP_SubTechno($$) {
  my $fichier = shift;
  my $vues = shift;

  if ( $fichier =~ /\.h[\w\+]*$/i) {
    return 'Hpp';
  }

  my $NB_MIN = 3;

  my $nb = 0;

  my $r_code = \$vues->{'code_with_prepro'};
 
  if ($$r_code =~ /::/sg ) {
	  # none C syntax is using :: (as I know ...)
	  return 'Cpp';
  }
 
  if ($$r_code =~ /\bclass\s+\w+/sg ) {
    $nb++;
  }
  if (($nb<$NB_MIN) && ($$r_code =~ /\bpublic\s*:/sg )) {
    $nb++;
  }
  if (($nb<$NB_MIN) && ($$r_code =~ /\bprivate\s*:/sg )) {
    $nb++;
  }
  if (($nb<$NB_MIN) && ($$r_code =~ /\bprotected\s*:/sg )) {
    $nb++;
  }
  if  (($nb<$NB_MIN) && ($$r_code =~ /\bnamespace\b/sg )) {
    $nb++;
  }
  if  (($nb<$NB_MIN) && ($$r_code =~ /\btemplate\s*</sg )) {
    $nb++;
  }
  if  (($nb<$NB_MIN) && ($$r_code =~ /\bdelete\b/sg )) {
    $nb++;
  }
  if  (($nb<$NB_MIN) && ($$r_code =~ /\busing\b/sg )) {
    $nb++;
  }

  if ($nb<$NB_MIN) {
    if ($$r_code !~ /::\*?|\.\*|->\*/s) {
      if ($$r_code !~ /#include\s+["<](?:vector|list|map|iostream|string)[">]/si) {
	return "C";
      }
    }
  }

  return 'Cpp';
}

#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement de l'analyse
#-------------------------------------------------------------------------------
sub Analyse ($$$$)
{
  my ($fichier, $vues, $options, $couples) = @_;
  my $status = 0;

  
  # Strip the code (suppress chains, comments and create views).
  my $StripStatus = StripMaster($fichier, $vues, $options, $couples);

  if ( Erreurs::isAborted($StripStatus) )
  {
    Erreurs::LogInternalTraces ('warning', undef, undef, 'abandon', 'Echec de pre-traitement Strip', '');
  }

  # Detect if language is Cpp, Hpp or C.
  $DETECTED_LANGUAGE = get_CCPP_SubTechno($fichier, $vues);
print "sub-techno is : ".$DETECTED_LANGUAGE."\n";


  # load 
  FileTypeRegister ($DETECTED_LANGUAGE, $couples, $options);

  $status |= $confStatus;

  my $Strip = getStripPrimary($DETECTED_LANGUAGE);

  my $analyseur_callbacks = [ $Strip, \&Parse, \&Count, $r_TableFonctions, $StripStatus ];
  $status |= AnaUtils::Analyse($fichier, $vues, $options, $couples, $analyseur_callbacks) ;

  if (($status & ~Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES))
  {
    # continue si Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES seul
    my $message = 'Echec de pre-traitement dans un comptage';
    Erreurs::LogInternalTraces ('verbose', undef, undef, 'AnaCpp', $message);
  }

  return $status;
}

1;
