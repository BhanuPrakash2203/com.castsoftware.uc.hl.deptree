package AnaObjC;
# les modules importes
use strict;
use warnings;

use Erreurs;
use CheckC;
use StripCpp;
use AnaUtils;
use AnaConfiguration_H_C_HPP_CPP;
use ObjC::ParseObjC;
use CountC_CPP_FunctionsMethodsAttributes;
use Vues; # dumpvues_filter_line
use Timeout;
use IsoscopeDataFile;

# prototypes publics
sub Strip ($$$$);
sub Count ($$$$$);
sub Analyse ($$$$);
sub FileTypeRegister ($);

# prototypes prives

sub _GetSuffix($)
{
  my ($fichier) = @_ ;

  my $suf =  $fichier ;
  $suf =~ s/.*\.//g ;
  return $suf;
}
  
#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement du strip
#-------------------------------------------------------------------------------
sub Strip ($$$$)
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
    print STDERR "Erreur dans la phase Strip: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }

  if ( Erreurs::isAborted($status) )
  {
    # si le strip genere une erreur, on ne continue pas
    return $status;
  }

  my $file_type = _GetSuffix ( Erreurs::GetCurrentFilenameTrace() );
#print STDERR 'debug: file_type = >' . $file_type . "<\n" ;
  #if ( $file_type eq 'C'  or $file_type eq 'h')
  {
    my $erreur_checkC = CheckC::CheckLanguageCompatibility( $vue->{'code'} );
    if ( defined $erreur_checkC )
    {
      return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_BAD_ANALYZER, $compteurs, $erreur_checkC);
    }
  }
  return $status;
}

sub Parse($$$$)
{
  my ($fichier, $vue, $options, $compteurs) =@_ ;
  my $status = 0;

  # Parse C code with old algorithm ...
  eval
  {
    $status |= CountC_CPP_FunctionsMethodsAttributes::Parse ($fichier, $vue, $compteurs, $options);
  };
  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Error when parsing C syntax in the ObjC file : $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }

  else {
    # Parse ObjC code with new parser ...
    eval
    {
      $status |= ObjC::ParseObjC::Parse ($fichier, $vue, $compteurs, $options);
    };
    if ($@ )
    {
      Timeout::DontCatchTimeout();   # propagate timeout errors
      print STDERR "Error when parsing ObjC syntax : $@ \n" ;
      $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
    }
  }

  if (($fichier ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'}) # dumpvues_filter_line
  {                                                                            # dumpvues_filter_line
    Vues::dump_vues ($fichier, $vue, $options);                                # dumpvues_filter_line
  }                                                                            # dumpvues_filter_line

  return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement des comptages
#-------------------------------------------------------------------------------
sub Count ($$$$$)
{
  my ($fichier, $vue, $options, $compteurs, $r_TableFonctions) = @_;
  my $status = 0;
  $status |= AnaUtils::Count ($fichier, $vue, $options, $compteurs, $r_TableFonctions );
  return $status;
}

# Ces variables doivent etre globales dans le cas nominal (dit nocrashprevent)
my $firstFile = 1;
my ($r_TableMnemos, $r_TableFonctions );
my $confStatus = 0;


# Module d'enregistrement des compteurs pour la sortie .csv
sub FileTypeRegister ($)
{
  my ($options) = @_;

  if ($firstFile != 0)
  {
        $firstFile = 0;

        #------------------ Chargement des comptages a effectuer -----------------------

        my $ConfigModul='ObjC_Conf';
        if (defined $options->{'--conf'}) {
          $ConfigModul=$options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'})
        {
            IsoscopeDataFile::csv_file_type_register("ObjC", $r_TableMnemos);
        }
  }
}


#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement de l'analyse
#-------------------------------------------------------------------------------
sub Analyse ($$$$)
{
  my ($fichier, $vues, $options, $couples) = @_;
  my $status = 0;

  FileTypeRegister ($options);

  $status |= $confStatus;

  my $analyseur_callbacks = [ \&Strip, \&Parse, \&Count, $r_TableFonctions ];
  $status |= AnaUtils::Analyse($fichier, $vues, $options, $couples, $analyseur_callbacks) ;

  if (($status & ~Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES))
  {
    # continue si Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES seul
    my $message = 'Echec de pre-traitement';
    Erreurs::LogInternalTraces ('verbose', undef, undef, 'AnaObjC', $message);
  }

  return $status;
}

1;
