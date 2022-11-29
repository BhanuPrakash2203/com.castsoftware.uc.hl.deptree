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

# Composant: Framework
#----------------------------------------------------------------------#
# DESCRIPTION: Fonctions utiles a Analyse.pl et a Sequenceur.pl
#----------------------------------------------------------------------#

package AnalyseUtil;

# les modules importes
use strict;
use warnings;
use POSIX ":sys_wait_h";
use POSIX;
use Erreurs;
use Options;
use IsoscopeDataFile;
use CsvFile;
use Couples;
use Lfc;

# prototypes publics
sub choisir_fichier_trace($$);
sub trier_fichier_sortie($);
sub recuperer_options();
sub memoriser_resultat_fichier_appli($$);
sub memoriser_resultat_fichier_test($$$$); # dumpvues_filter_line
sub creer_compteur($$);
sub AnalyseFile($$$$$$;$$);

# prototypes prives
sub Get_System_Error_Value($);
sub AnalyseFileWithFork($$$$$;$$);
sub PropageCodeErreurEtendu($);

# traces_filter_start

my $debug = 1;


#-------------------------------------------------------------------------------
# DESCRIPTION: choix du fichier trace
#-------------------------------------------------------------------------------
sub choisir_fichier_trace($$)
{
  my ($options, $callbackTemporaryFilenames) = @_;
  
  if (defined $options->{'--trace'})
  {
    my $trace_output_dir  = AnalyseOptions::GetOutputDirectory ( $options, '--strip_dir' ) ||
                            AnalyseOptions::GetOutputDirectory ( $options, '--dir-debug' ) || # pour l'IHM
                            AnalyseOptions::GetOutputDirectory ( $options, '--dir' ) ||
                            'output/met/' ;

    my $trace_file_name = '';

    if ($options->{'--trace'} ne '') {
      # Choix d'un fichier de traces.
      $trace_file_name = $options->{'--trace'};
    }
    else {
      $trace_file_name = 'TRACES.txt';
    }

    Options::rec_mkdir($trace_output_dir);

    my @filters = ();
    my $filterOption = $options->{'--filtertrace'} ;
    if (defined $filterOption)
    {
      @filters = split ( ',', $filterOption);
    }
 
    $callbackTemporaryFilenames->($trace_output_dir .'/'. $trace_file_name );
    if ( defined $options->{'--raztrace'} ) {
      Erreurs::OpenInternalTrace($trace_output_dir, $trace_file_name, '>', \@filters);
    }
    else {
      Erreurs::OpenInternalTrace($trace_output_dir, $trace_file_name, '>>', \@filters);
    }

    # Ecriture du caractere U+042F CYRILLIC CAPITAL LETTER YA pour test.
    my $x042f = pack("U0C*", 0xD0, 0xaf);       # U+042F CYRILLIC CAPITAL LETTER YA
    Erreurs::LogInternalTraces ('info', undef, undef, 'trace file', 'test message', $x042f); # traces_filter_line

    $callbackTemporaryFilenames->($trace_output_dir .'/'. 'warnings' );
    Erreurs::OpenCompilerWarnings($trace_output_dir, 'warnings');
  }
}

# traces_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: Check for missing mnemonics in the output counters.
#-------------------------------------------------------------------------------

sub checkMissingMnemonics($) {
  my $counters = shift;
  my $status = 0;

  my $listMissings = IsoscopeDataFile::find_missing_columns( $counters);
  my $missings = 0;
  for my $mnemo ( @{$listMissings} ) {
    if ( $mnemo =~ /\A(?:Nbr_|Id_)/ ) {
      $missings ++ ;
      print STDERR "WARNING : missing mnemo : $mnemo.\n";
    }
  }
  if ($missings gt 0) {
    $status |= Erreurs::COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE;
  }
  return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Record results in the csv.
#-------------------------------------------------------------------------------

sub recordResults($$$) {
  my $counters = shift;
  my $status = shift;
  my $options = shift;

  # record the status
  my $mnemo_Dat_AnalysisStatus = 'Dat_AnalysisStatus';
  $status |= Couples::counter_add($counters, $mnemo_Dat_AnalysisStatus, $status );

  my $errorClass = $counters->counter_get_values()->{Erreurs::MNEMO_ABORT_CAUSE_CLASS};
  if ( ( $errorClass == 1 ) or ( $errorClass == 2 ) ) {
    AnalyseUtil::memoriser_resultat_fichier_appli($options, $counters);
  }
  
  # Decode and display the status if different from 0.
  if ($status != 0)
  {
     printf STDERR "ERROR: Analysis has ended with the code 0x%x\n", $status ;
     Erreurs::PrintExplicitStatus($status);
     print STDERR "\n" ;
  }
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Trie les infos du fichier csv
#-------------------------------------------------------------------------------
sub trier_fichier_sortie($)
{
  my ($resultsOutput) = @_;
  return if not defined $resultsOutput;
  IsoscopeDataFile::csv_file_close();

  # tri du fichier de sortie en utilisant la classe CsvFile
  my $status = 0;

  CsvFile::SetEmptyAndFlag( Erreurs::COMPTEUR_EMPTY_VALUE,
                            Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS);
  my $csv_brut = new CsvFile ($resultsOutput);

  if (defined $csv_brut)
  {
    $status |= $csv_brut->dump ($resultsOutput . ".sorted");

    if ($status == 0)
    {

# traces_filter_start

      if (not rename ($resultsOutput, $resultsOutput . ".unsorted"))
      {
	print STDERR "Probleme de renommage de $resultsOutput non trie en unsorted\n" if ($debug != 0);
        Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'renommage fichier resultat', ''); # traces_filter_line
	$status = Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
      }
      else

# traces_filter_end

      {
	if (not rename ($resultsOutput . ".sorted", $resultsOutput))
        {
	  print STDERR "Probleme de renommage de $resultsOutput trie en $resultsOutput\n" if ($debug != 0); # traces_filter_line
          Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'renommage fichier resultat', ''); # traces_filter_line
	  $status = Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
        }
        unlink( $resultsOutput . '.unsorted' );
      }
    }
    else
    {
      print STDERR "Probleme de creation de $resultsOutput trie\n" if ($debug != 0); # traces_filter_line
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'creation fichier resultat', ''); # traces_filter_line
      $status = Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
    }
  }
  else
  {
    print STDERR "Erreur de lecture de $resultsOutput\n" if ($debug != 0);      # traces_filter_line
    Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'lecture fichier resultat', ''); # traces_filter_line
    $status = Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
  }

  print STDERR "Probleme de tri de $resultsOutput\n" if ($status != 0);

  return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Recupere les options
# pour rajouter des options de debug dans des environnements de test qui         # traces_filter_line
# encapsulent l'executable, sans permettre l'ajout d'options.                    # traces_filter_line
#-------------------------------------------------------------------------------
sub recuperer_options()
{
  my ( $command_line_options, $fichiers ) = Options::traite_options(\@ARGV);

  my $options = $command_line_options;

# traces_filter_start

  my $str_environment_options = $ENV{'ANALYZE_OPTIONS'} || '' ;
  my @arr_environment_options = split (' ', $str_environment_options);

  my ( $environment_options, $environment_fichiers ) = Options::traite_options(\@arr_environment_options);

  # ajoute les options d'environnement aux options de la ligne de commande
  for my $key ( keys ( %{$environment_options} ))
  {
    $options->{$key} = $environment_options->{$key};
    print STDERR 'ANALYZE_OPTIONS positionne ' .  $key . ' a la valeur ' . $environment_options->{$key} ."\n";
  }
  $fichiers = Lfc::traite_options( $fichiers, $options);

# traces_filter_end

  return [$options, $fichiers];
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Memorise les comptages dans un fichier csv
#-------------------------------------------------------------------------------

sub memoriser_resultat_fichier_appli($$)
{
  my ($options, $compteurs) = @_;

  if (defined $options->{'--o'})
  {
    IsoscopeDataFile::csv_file_append($compteurs);
  }
}

# dumpvues_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: Memorise les comptages dans un fichier csv pour le test
#-------------------------------------------------------------------------------

sub memoriser_resultat_fichier_test($$$$)
{
  my ($options,  $compteurs, $output_dir, $output_filename) = @_;

  if (defined $options->{'--comptages'})
  {
      print  STDERR "Repertoire de sortie de comptages: " . $output_dir . "\n" ;
      Couples::counter_write_csv($compteurs, $output_filename, $options);
  }
}

# dumpvues_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: Cree les attributs de l'analyse
#-------------------------------------------------------------------------------

sub creer_compteur($$)
{
  my ($fichier, $date ) = @_;
  my $status = 0;

  Couples::ClassSetErrorNumber(Erreurs::COMPTEUR_STATUS_INTERFACE_COMPTEUR);
  my $compteurs =  new Couples();
  $status |= Couples::counter_add($compteurs, "Dat_FileName", $fichier );
  $status |= Couples::counter_add($compteurs, "Dat_AnalysisDate", $date );

  my @retour = ( $compteurs, $status);

  return \@retour;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Recupere le code d'erreur
#-------------------------------------------------------------------------------

sub Get_System_Error_Value($)
{
  my ($errorCode)=@_;

  my $message = $errorCode >> 8;

  return $message;
}


#-------------------------------------------------------------------------------
# DESCRIPTION:
# Lancement de l'analyse sur un fichier source avec un processus 'fork'
#-------------------------------------------------------------------------------

sub AnalyseFileWithFork($$$$$;$$)
{
    my ($fichier, $options, $file_type, $globalContext, $AnalyseFileCallback, $param1, $param2) = @_ ;
    my $debug = exists($options->{'--debugfork'});                              # traces_filter_line
    my $status = 0;

    my $pid_enfant = POSIX::fork();

    if (not defined $pid_enfant )
    # D'apres man perlfunc, retourne  "undef" if the fork is unsuccessful
    {
      $status |= Erreurs::COMPTEUR_STATUS_CRASH_ANALYSEUR;
      Erreurs::LogInternalTraces ('erreur', undef, undef, '', '', 'fork impossible'); # traces_filter_line
      # FIXME: a mettre en conformite avec l'eventuelle strategie de gestion des erreurs.
    }
    elsif ($pid_enfant != 0)
    {
        # processus parent
        print STDERR "pid_enfant:$pid_enfant\n" if ($debug);                    # traces_filter_line
        print STDERR "Ici c'est le processus parent.\n" if ($debug);            # traces_filter_line

        my $waitpidSatus = 0;

        do
        {
            my $localStatus;
            if ($^O eq 'MSWin32')
            {
                $waitpidSatus = POSIX::waitpid($pid_enfant, &POSIX::WNOHANG);

                if (($waitpidSatus != 0) && ($waitpidSatus != -1))  # ok pour activestate
                {
                    print STDERR "waitpidSatus:$waitpidSatus\n" if ($debug);                           # traces_filter_line
                    $localStatus = Get_System_Error_Value($?);
                    print STDERR "localStatus:$localStatus\n" if ($debug);                             # traces_filter_line
                    $status |= $localStatus;

                    if ($status == Erreurs::COMPTEUR_STATUS_CRASH_ANALYSEUR)                           # traces_filter_line
                    {                                                                                  # traces_filter_line
                      Erreurs::LogInternalTraces ('erreur', undef, undef, '', '', 'Crash analyseur!'); # traces_filter_line
                      print STDERR "$fichier:1:Crash analyseur !\n" if ($debug);                       # traces_filter_line
                    }                                                                                  # traces_filter_line
                }
            }
            else
            {
                # autres cas std : unix et clones
                $waitpidSatus = waitpid($pid_enfant, 0);

                if ($waitpidSatus > 0)
                {
                    print STDERR "waitpidSatus:$waitpidSatus\n" if ($debug);                           # traces_filter_line

                    $localStatus = Get_System_Error_Value($?);

                    print STDERR "localStatus:$localStatus\n" if ($debug);                             # traces_filter_line

                    $status |= $localStatus;

                    if ($status == Erreurs::COMPTEUR_STATUS_CRASH_ANALYSEUR)                           # traces_filter_line
                    {                                                                                  # traces_filter_line
                      Erreurs::LogInternalTraces ('erreur', undef, undef, '', '', 'Crash analyseur!'); # traces_filter_line
                      print STDERR "$fichier:1:Crash analyseur !\n" if ($debug);                       # traces_filter_line
                    }                                                                                  # traces_filter_line
                }
            }
        } until ($waitpidSatus == -1);

        print STDERR "Le processus parent est termine.\n" if ($debug);          # traces_filter_line
    }
    else
    {
      # processus enfant
      print STDERR "Ici c'est le processus enfant.\n" if ($debug);              # traces_filter_line

      Timing->superTimerRestart ($fichier, Timing->isSelectedTiming ('Super')); # timing_filter_line

      $status |= $AnalyseFileCallback->($fichier, $options, $file_type, $globalContext, $param1, $param2);

      print STDERR "Ici fin du processus enfant.\n" if ($debug);                # traces_filter_line

      $status |= PropageCodeErreurEtendu ($status);

      Timing->superTimerDump ();                                                # timing_filter_line

      exit ($status);
    }

    $status |= PropageCodeErreurEtendu($status);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Lancement de l'analyse sur un fichier source
# avec detection de crash de l'analyseur sur option
#-------------------------------------------------------------------------------

sub AnalyseFile($$$$$$;$$)
{
  my ($fichier, $options, $file_type, $globalContext, $filter_node_modules, $AnalyseFileCallback, $param1, $param2) = @_ ;

  my $status = 0;


  if ( (exists ($options->{'--crashprevent'})) && (! Erreurs::isDebugModeActive()) ) 
  {
    $status |= AnalyseFileWithFork($fichier, $options, $file_type, $globalContext, $AnalyseFileCallback, $param1, $param2);
  }
  else
  {
    # analyse normale
    $status |= $AnalyseFileCallback->($fichier, $options, $file_type, $globalContext, $filter_node_modules, $param1, $param2);
    return $status;
  }

  return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: gestion des codes d'erreurs etendus
#-------------------------------------------------------------------------------

sub PropageCodeErreurEtendu($)
{
  my ($status) = @_;
  if (($status & 0xFFFFFF00) != 0)
  {
    $status |= Erreurs::COMPTEUR_STATUS_ERREUR_ETENDUE;
    print STDERR "status etendu\n" if ($debug);                                 # traces_filter_line
  }

  return $status;
}

1;
