package AnaObjHpp;
# les modules importes
use strict;
use warnings;

use Erreurs;
use StripCpp;
use AnaUtils;
use AnaConfiguration_H_C_HPP_CPP;
use CountC_CPP_FunctionsMethodsAttributes;
use Cpp::CppClassDef;
use ObjC::ParseObjC;
use Vues; # dumpvues_filter_line
use Timeout;
use IsoscopeDataFile;
use CppKinds;
use CheckObjHpp;

# prototypes publics
sub Strip ($$$$);
sub Count ($$$$$);
sub Analyse ($$$$);
sub FileTypeRegister ($);

# prototypes prives


# This routine is called in place of the strip routine, when the Hpp techno
# is invoked in a context of Master techno, in addition to the generix strip
# defined in the master techno analyzer.
sub StripPrimary($$$$)
{
  my ($fichier, $vue, $options, $counters) =@_ ;
  my $status = 0;
  if (not defined $options->{'--analyse-short-files'})
  {
    my $erreur_checkHppClass;
    $erreur_checkHppClass = CheckObjHpp::CheckCodeAvailability( $vue->{'ObjC'} );
    if ( defined $erreur_checkHppClass )
    {
      return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_NOT_ENOUGH_CODE, $counters, $erreur_checkHppClass);
    }
  }

  return $status;
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

  return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement du parsing
#-------------------------------------------------------------------------------

sub Parse($$$$)
{
  my ($fichier, $vue, $options, $compteurs) =@_ ;
  my $status = 0;
  eval
  {
    $status |= CountC_CPP_FunctionsMethodsAttributes::Parse ($fichier, $vue, $compteurs, $options);
  };
  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Erreur dans la phase Parsing: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }

  else {
    # Make a synthesis overview for all files with some information of the
    # Cpp Parser.
    
    $status |= Cpp::CppClassDef::consolidateInfoByClass($vue);
    # Parse ObjC code with new parser ...
    eval
    {
      $status |= ObjC::ParseObjC::Parse ($fichier, $vue, $compteurs, $options);
    };
    if ($@ )
    {
      Timeout::DontCatchTimeout();   # propagate timeout errors
      print STDERR "Error when parsing ObjC syntax for ObjHpp file: $@ \n" ;
      $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
    }
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

        my $ConfigModul='ObjHpp_Conf';
        if (defined $options->{'--conf'}) {
          $ConfigModul=$options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'})
        {
            IsoscopeDataFile::csv_file_type_register("ObjHpp", $r_TableMnemos);
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
    my $message = 'Echec de pre-traitement dans un comptage';
    Erreurs::LogInternalTraces ('verbose', undef, undef, 'AnaObjHpp', $message);
  }

  return $status;
}

1;
