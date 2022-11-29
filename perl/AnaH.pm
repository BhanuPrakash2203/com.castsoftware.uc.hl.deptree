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
# DESCRIPTION: Module d'analyse pour les fichiers .h du langage C
#----------------------------------------------------------------------#

package AnaH;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use StripCpp;
use AnaUtils;
use AnaConfiguration_H_C_HPP_CPP;
use CountC_CPP_FunctionsMethodsAttributes;
use Vues; # dumpvues_filter_line
use Timeout;

# prototypes publics
sub Strip ($$$$);
sub Count ($$$$);
sub Analyse ($$$$);
sub FileTypeRegister ($);

# prototypes prives

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

  if ($status != 0)
  {
    # si le strip genere une erreur, on ne continue pas
    #$status |= Couples::counter_add ($compteurs, Erreurs::MNEMO_ABORT_CAUSE, Erreurs::ABORT_CAUSE_SYNTAX_ERROR);
    return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $compteurs, 'statut StripCpp non nul');
    #return $status;
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
sub Count ($$$$)
{
  my ($fichier, $vue, $options, $compteurs) = @_;
  my @LocalTableCountersAndNames = AnaConfiguration_H_C_HPP_CPP::ExtractTablesCountersAndNames (AnaConfiguration_H_C_HPP_CPP::TABLE_COUNTERS_ANA_H, $options);
  my $status = AnaUtils::Count ($fichier, $vue, $options, $compteurs, \@LocalTableCountersAndNames );
  return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: module d'enregistrement des compteurs pour la sortie .csv
#-------------------------------------------------------------------------------
sub FileTypeRegister ($)
{
  my ($options) = @_;
  AnaUtils::file_type_register ('H', $options, \&Strip, \&Count);
}


#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement de l'analyse
#-------------------------------------------------------------------------------
sub Analyse ($$$$)
{
  my ($fichier, $vues, $options, $couples) = @_;

  my $status = 0;

  FileTypeRegister ($options);

  my $analyseur_callbacks = [ \&Strip, \&Parse, \&Count ];
  AnaUtils::Analyse($fichier, $vues, $options, $couples, $analyseur_callbacks) ;

if (0)
{
  $status |= Strip ($fichier, $vues, $options, $couples) ;

  if ($status != 0)
  { # si le strip genere une erreur, on ne fera pas de comptages
    return $status;
  }

  if (defined $options->{'--nocount'})
  {
    return $status;
  }

  if ($status & Erreurs::COMPTEUR_STATUS_FICHIER_NON_COMPILABLE)
  {
    return $status;
  }

  $status |= Count ($fichier, $vues, $options, $couples);
}


  if (($status & ~Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES))
  {
    # continue si Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES seul
    print STDERR "$fichier : Echec de pre-traitement\n";
  }

  return $status;
}

1;
