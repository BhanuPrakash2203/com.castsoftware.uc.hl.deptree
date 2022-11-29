package AnaObjCCpp;
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
use AnaObjC;
use AnaObjCpp;
use AnaObjHpp;

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

  # Initially, ObCCpp analyzer has been designed to allow C, Cpp & Hpp language.
  # This is desactivated at this time, since get_OBJCCPP_SubTechno() have been
  # modified to not detecting C, Cpp & Hpp...
  if ($detectedLang eq 'Hpp') {
    return \&AnaHpp::StripPrimary;
  }

  # ObjHpp
  if ($detectedLang eq 'ObjHpp') {
    return \&AnaObjHpp::StripPrimary;
  }

  return undef;
}


sub Parse($$$$)
{
  my ($fichier, $vue, $options, $compteurs) =@_ ;

  my $status = 0;

  # Initially, ObCCpp analyzer has been designed to allow C, Cpp & Hpp language.
  # This is desactivated at this time, since get_OBJCCPP_SubTechno() have been
  # modified to not detecting C, Cpp & Hpp...
  if ($DETECTED_LANGUAGE eq 'Cpp') {
    $status |= AnaCpp::Parse($fichier, $vue, $options, $compteurs);
  }
  elsif ($DETECTED_LANGUAGE eq 'Hpp') {
    $status |= AnaHpp::Parse($fichier, $vue, $options, $compteurs);
  }
  elsif ($DETECTED_LANGUAGE eq 'C') {
    $status |= AnaC::Parse($fichier, $vue, $options, $compteurs);
  }

  # ObjC, ObjCpp & ObjHpp
  elsif ($DETECTED_LANGUAGE eq 'ObjC') {
    $status |= AnaObjC::Parse($fichier, $vue, $options, $compteurs);
  }
  elsif ($DETECTED_LANGUAGE eq 'ObjCpp') {
    $status |= AnaObjCpp::Parse($fichier, $vue, $options, $compteurs);
  }
  elsif ($DETECTED_LANGUAGE eq 'ObjHpp') {
    $status |= AnaObjHpp::Parse($fichier, $vue, $options, $compteurs);
  }
  else {
    print "[AnaObjCCpp] ERROR : Cannot parse. Unknow language $DETECTED_LANGUAGE !!\n";
    # FIXME : should raise an error !!!
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

  # Initially, ObCCpp analyzer has been designed to allow C, Cpp & Hpp language.
  # This is desactivated at this time, since get_OBJCCPP_SubTechno() have been
  # modified to not detecting C, Cpp & Hpp...
  if ($DETECTED_LANGUAGE eq 'Cpp') {
    AnaCpp::Count($fichier, $vue, $options, $compteurs, $r_TableFonctions);
  }
  elsif ($DETECTED_LANGUAGE eq 'Hpp') {
    AnaHpp::Count($fichier, $vue, $options, $compteurs, $r_TableFonctions);
  }
  elsif ($DETECTED_LANGUAGE eq 'C') {
    AnaC::Count($fichier, $vue, $options, $compteurs, $r_TableFonctions);
  }

  # ObjC, ObjCpp & ObjHpp
  elsif ($DETECTED_LANGUAGE eq 'ObjC') {
    $status |= AnaObjC::Count($fichier, $vue, $options, $compteurs, $r_TableFonctions);
  }
  elsif ($DETECTED_LANGUAGE eq 'ObjCpp') {
    $status |= AnaObjCpp::Count($fichier, $vue, $options, $compteurs, $r_TableFonctions);
  }
  elsif ($DETECTED_LANGUAGE eq 'ObjHpp') {
    $status |= AnaObjHpp::Count($fichier, $vue, $options, $compteurs, $r_TableFonctions);
  }
  else {
    print "[AnaObjCCpp] ERROR : Cannot count. unknow language $DETECTED_LANGUAGE !!\n";
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

  $DETECTED_LANGUAGE = get_OBJCCPP_SubTechno_From_Extension($fichier);
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
  if (! exists $firstFile{$detectedLanguage})
  {
        $firstFile{$detectedLanguage} = 1;

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

# This callback is used when the file can not be classified by analyzing its
# content, that is, when it is rejected from the analysis before the Strip step.
# (This occurs typically when the file is too big).
sub get_OBJCCPP_SubTechno_From_Extension($) {
  my $fichier = shift;

  if ( $fichier =~ /\.h[\w\+]*$/i) {
    return 'ObjHpp';
  }

  if ( $fichier =~ /\.[p]?c*$/i) {
    return 'C';
  }

  if ( $fichier =~ /\.m$/i) {
    return 'ObjC';
  }

  if ( $fichier =~ /\.mm$/i) {
    return 'ObjCpp';
  }

  return 'Cpp';
}

sub get_OBJCCPP_SubTechno($$) {
  my $fichier = shift;
  my $vues = shift;

  my $r_code = \$vues->{'code_with_prepro'};

  if (defined $vues->{'ObjC'}) {
    $r_code = \$vues->{'ObjC'};
  }

  my $detectedLang = undef;

  if ( $fichier =~ /\.h[\w\+]*$/i) {
    $detectedLang = 'Hpp';
  }

  if (! defined $detectedLang) {
    my $NB_MIN = 3;

    my $nb = 0;
 
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
    if  (($nb<$NB_MIN) && ($$r_code =~ /\bauto\b/sg )) {
      $nb++;
    }
    if  (($nb<$NB_MIN) && ($$r_code =~ /\busing\b/sg )) {
      $nb++;
    }

    if ($nb<3) {
      if ($$r_code !~ /::\*?|\.\*|->\*/s) {
        if ($$r_code !~ /#include\s+["<](?:vector|list|map|iostream|string)[">]/si) {  
    	  $detectedLang="C";
        }
      }
    }
  }

  if (! defined $detectedLang) {
    $detectedLang='Cpp';
  }


  # As only .m, .mm & .h file should have been selected for being analyzed,
  # all files will be considered as containing ObjC code... even if they don't contain
  # Objective C classes !
  #
  #if ($$r_code =~ /^\s*\@(?:interface|implementation)\b/sm) {
    $detectedLang = 'Obj'.$detectedLang;
  #} 

  return $detectedLang;
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
  $DETECTED_LANGUAGE = get_OBJCCPP_SubTechno($fichier, $vues);
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
