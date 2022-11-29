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
# Description: Module d'analyse pour le langage Java
#----------------------------------------------------------------------#

package AnaJava;
use strict;
use warnings;
use Erreurs;
use StripJava;
use AnaUtils;
use Vues;
use Timeout;
use IsoscopeDataFile;

use CloudReady::CountJava;
use CloudReady::detection;
use Java::ParseJava;

sub Strip($$$$)
{
  my ($fichier, $vue, $options, $couples) =@_ ;

  my $status = 0;

  eval
  {
    $status = StripJava::StripJava($fichier, $vue, $options, $couples);
  };
  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Erreur dans la phase Strip: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }

  if (($fichier ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'}) # dumpvues_filter_line
  {                                                                            # dumpvues_filter_line
    Vues::dump_vues( $fichier, $vue, $options);                                # dumpvues_filter_line
  }                                                                            # dumpvues_filter_line

  # FIXME: pour bientot
  #
  #if ($status & Erreurs::COMPTEUR_STATUS_FICHIER_NON_COMPILABLE)
  #{
  #  return $status;
  #}
  #
  #eval
  #{
  #  $status |= CountC_CPP_FunctionsMethodsAttributes::Parse($fichier, $vue, $couples, $options);
  #};
  #if ($@ )
  #{
  #  print STDERR "Erreur dans la phase Parsing: $@ \n" ;
  #  $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  #}
  #
  return $status;
}

sub Parse($$$$) {
	my ($fichier, $vue, $options, $compteurs) =@_ ;
	my $status = 0;
	eval {
		$status |= Java::ParseJava::Parse($fichier, $vue, $compteurs, $options);
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
		$status |= CloudReady::CountJava::CountJava( $fichier, $vue, $options);
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

        my $ConfigModul='Java_Conf';
        if (defined $options->{'--conf'}) {
          $ConfigModul=$options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'})
        {
            IsoscopeDataFile::csv_file_type_register("Java", $r_TableMnemos);
        }
        
        #------------------ init CloudReady detections -----------------------
		if (defined $options->{'--CloudReady'}) {
			CloudReady::detection::init($options, 'Java');
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


