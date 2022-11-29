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
# DESCRIPTION: Module d'analyse pour les fichiers .cpp du langage C++
#----------------------------------------------------------------------#

package AnaPHP;
# les modules importes
use strict;
use warnings;

use Erreurs;
use StripPHP;
use AnaUtils;
use PHP::Parse;
use PHP::CheckPHP;
use Vues; # dumpvues_filter_line
use Timeout;
use IsoscopeDataFile;

use CloudReady::CountPHP;
use CloudReady::detection;

# prototypes publics
sub Strip ($$$$);
sub Count ($$$$$);
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
    $status = StripPHP::StripPHP ($fichier, $vue, $options, $compteurs);
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

sub Parse($$$$)
{
  my ($fichier, $vue, $options, $compteurs) =@_ ;
  my $status = 0;
  eval
  {
    $status |= PHP::Parse::Parse ($fichier, $vue, $compteurs, $options);
  };
  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Erreur dans la phase Parsing: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
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

    if (defined $options->{'--CloudReady'}) {
        CloudReady::detection::setCurrentFile($fichier);
        $status |= CloudReady::CountPHP::CountPHP( $fichier, $vue, $options);
    }
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

        my $ConfigModul='PHP_Conf';
        if (defined $options->{'--conf'}) {
          $ConfigModul=$options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'})
        {
            IsoscopeDataFile::csv_file_type_register("PHP", $r_TableMnemos);
        }
        
        #------------------ init CloudReady detections -----------------------
		if (defined $options->{'--CloudReady'}) {
			CloudReady::detection::init($options, 'PHP');
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

  my $erreur_checkPHP = PHP::CheckPHP::CheckCodeAvailability( \$vues->{'text'} );
  if ( defined $erreur_checkPHP )
  {
    return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_NOT_ENOUGH_CODE, $couples, $erreur_checkPHP);
  }

  $status |= $confStatus;

  my $analyseur_callbacks = [ \&Strip, \&Parse, \&Count, $r_TableFonctions ];
  $status |= AnaUtils::Analyse($fichier, $vues, $options, $couples, $analyseur_callbacks) ;

  if (($status & ~Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES))
  {
    # continue si Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES seul
    my $message = 'Echec de pre-traitement dans un comptage';
    Erreurs::LogInternalTraces ('verbose', undef, undef, 'AnaPHP', $message);
  }

  return $status;
}

1;
