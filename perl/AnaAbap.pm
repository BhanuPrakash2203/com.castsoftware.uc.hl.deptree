
use Ident;
package AnaAbap;

use strict;
use warnings;
use Erreurs;

use StripAbap;
#use StripSqlPlus;
use Abap::Parse;
use Abap::CheckAbap;
#use PlSql::ParseBody;
#use PlSql::ParseByOffset;
use AnaUtils;
use Vues;
use Timeout;
#use PlSql::Parse;
use IsoscopeDataFile;

use Ident;

# Comptages communs
#use CountCommun;
#use CountLongLines;
#use CountSuspiciousComments;
#use CountCommentsBlocs;

sub Strip ($$$$)
{
  my ($fichier, $vue, $options, $couples) =@_ ;
  my $status = 0;

#  $status = StripSqlPlus::StripSqlPlus ($fichier, $vue, $options, $couples);
  $status |= StripAbap::StripAbap ($fichier, $vue, $options, $couples);

  if ($@ ) #FIXME: cette ligne a t-elle encore un sens, sans le eval?
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Erreur dans la phase Strip: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }
  return  $status;
}


sub Parse ($$$$)
{
  my ($fichier, $vue, $options, $couples) =@_ ;
  my $status = 0;
  eval
  {
	$status |= Abap::Parse::Parse ($fichier, $vue, $couples, $options);
    #$status |= PlSql::ParseByOffset::ParseByOffset ($fichier, $vue, $couples, $options);

    # attention a l'ordre des parametres
#    $status |= PlSql::ParseBody::ParseBody ($fichier, $vue, $options, $couples);
  };

  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Erreur dans la phase Parsing: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }

#  if (not defined $options->{'--analyse-short-files'})
#  {
#    my $erreur_checkAbap = Abap::CheckAbap::CheckCodeAvailability( $fichier );
#    if ( defined $erreur_checkAbap )
#    {
#       return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_NOT_ENOUGH_CODE, $couples, $erreur_checkAbap);
#     }
#  }

  return  $status;
}

sub Count ($$$$$)
{
    my ($fichier, $vue, $options, $couples, $r_TableFonctions) = @_;
    my $status = AnaUtils::Count ($fichier, $vue, $options, $couples, $r_TableFonctions);

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

        my $ConfigModul='Abap_Conf';
        if (defined $options->{'--conf'}) {
          $ConfigModul=$options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'})
        {
            IsoscopeDataFile::csv_file_type_register("Abap", $r_TableMnemos);
        }
  }
}

sub Analyse ($$$$)
{
  my ($fichier, $vue, $options, $couples) = @_;
  my $status =0;

  FileTypeRegister($options);
  $status |= $confStatus;

  # Discard file that should not been analyzed according to their name.
  my $erreur_checkAbap = Abap::CheckAbap::FilterFile( $fichier );
  if ( defined $erreur_checkAbap )
  {
    return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_NOT_ENOUGH_CODE, $couples, $erreur_checkAbap);
  }

  # Launch analysis ...
  my $analyseur_callbacks = [ \&Strip, \&Parse, \&Count, $r_TableFonctions ];
  $status |= AnaUtils::Analyse($fichier, $vue, $options, $couples, $analyseur_callbacks) ;

  return $status ;
}


1;


