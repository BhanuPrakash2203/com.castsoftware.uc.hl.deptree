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

# Composant: Plugin
#----------------------------------------------------------------------#
# DESCRIPTION: Module d'analyse pour les fichiers .hpp du langage CPP
#----------------------------------------------------------------------#

package AnaHpp;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use CheckHpp;
use StripCpp;
use AnaUtils;
use AnaConfiguration_H_C_HPP_CPP;
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
    $erreur_checkHppClass = CheckHpp::CheckCodeAvailability( $vue->{'code'} );
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
  my $couples = $compteurs;
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

  if (not defined $options->{'--analyse-short-files'})
  {
    my $erreur_checkHppClass;
    $erreur_checkHppClass = CheckHpp::CheckCodeAvailability( $vue->{'code'} );
    if ( defined $erreur_checkHppClass )
    {
      return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_NOT_ENOUGH_CODE, $couples, $erreur_checkHppClass);
    }
  }

  if ($status != 0)
  {
    # si le strip genere une erreur, on ne continue pas
    return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $compteurs, 'statut StripCpp non nul');
  }

  if ($status & Erreurs::COMPTEUR_STATUS_FICHIER_NON_COMPILABLE)
  {
    if (($fichier ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'}) # dumpvues_filter_line
    {                                                                            # dumpvues_filter_line
      Vues::dump_vues ($fichier, $vue, $options);                                # dumpvues_filter_line
    }                                                                            # dumpvues_filter_line

    return $status;
  }
  return $status;

}

sub Parse ($$$$)
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
  #my @LocalTableCountersAndNames = AnaConfiguration_H_C_HPP_CPP::ExtractTablesCountersAndNames (AnaConfiguration_H_C_HPP_CPP::TABLE_COUNTERS_ANA_HPP, $options);
  #my $status = AnaUtils::Count ($fichier, $vue, $options, $compteurs, \@LocalTableCountersAndNames );
  my $status = AnaUtils::Count ($fichier, $vue, $options, $compteurs, $r_TableFonctions );

  return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement de l'analyse
#-------------------------------------------------------------------------------

# Ces variables doivent etre globales dnas le cas nominal (dit nocrashprevent)
my $firstFile = 1;
my ($r_TableMnemos, $r_TableFonctions );
my $confStatus = 0;



# DESCRIPTION: module d'enregistrement des compteurs pour la sortie .csv
sub FileTypeRegister ($)
{
  my ($options) = @_;

  if ($firstFile != 0)
  {
        $firstFile = 0;

        #------------------ Chargement des comptages a effectuer -----------------------

        my $ConfigModul='Hpp_Conf';
        if (defined $options->{'--conf'}) {
          $ConfigModul=$options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'})
        {
            IsoscopeDataFile::csv_file_type_register("Hpp", $r_TableMnemos);
        }
  }
}



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
    print STDERR "$fichier : Echec de pre-traitement\n";
  }

  return $status;
}

1;
