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
#
# Composant: Framework
#----------------------------------------------------------------------#
# DESCRIPTION: Outil de comptage pour les langages C et C++
#----------------------------------------------------------------------#

use strict;
use warnings;

# prototypes publics
#     Aucun, car il s'agit du script principal.

# prototypes prives
sub main();
sub AnalyseFile($$$$$);
sub CalculateOutputsComptageTxt($$);        # dumpvues_filter_line
sub AnalyseFileInternal($$$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Adaptation du chemin de recherche des modules au chemin utilise
# pour lancer le script principal
#-------------------------------------------------------------------------------
BEGIN
{
  my $rep = $0;
  # FIXME: ce repertoire devrait preceder le repertoire Cobol.
  # FIXME: peut etre faisable en chargeant les modules dynamiquement (incident 24)

  if ( $rep =~ m/[\/\\]/ )
  {
    $rep =~ s/(.*)[\/\\][^\/\\]+/$1/;
  }
  else
  {
    $rep = '.' ;
  }
  unshift @INC, $rep;
  unshift @INC, $rep.'/Lib';
  unshift @INC, $rep.'/../../../Config';
}

use Ident; ## pour eviter que le script de stunnix ne le rajoute avant le bloc begin...

use Erreurs;
use Analyse;
use AnalyseUtil;
use SourceLoader;
use Options;
use Lib::IsoscopeVersion;
#use WinMemoryUsage;                                             # memory_filter_line
use Timing;                                                     # timing_filter_line
use Timeout;
use Progression;
use FileList;
use AnalyseParam;
use IsoscopeDataFile;
use ProcessManager;
use UUID;
use Sys::Hostname;
use SourceUnit;
use File::Path;
use framework::main;
use CloudReady::detection;
use CloudReady::CountDotnet;
use CloudReady::projectFiles;
use KeywordScan::detection;
use KeywordScan::projectFiles;
use Lib::Data;
use Lib::Sources;
use Lib::Crc;
use Lib::SHA;
use Lib::ThirdParties;
use Lib::Log;
use Lib::GeneratedCodeException;
use Prepro;

  #my $missings = Lib::IsoscopeDataFile::count_missing_columns($couples);

#-------------------------------------------------------------------------------
# DESCRIPTION: Affichage d'une aide sommaire
#-------------------------------------------------------------------------------
sub usage ($)
{
  my ($message) = @_;
  print $message . "\n\n";
#  print "\n" . version() ;
  print "\nUsage: " ;
  print "perl [-S] Analyse.pl\n";
  print "       --language=<technology>                 # specify technology\n" ;
  print "        --o=<fichier resultats>                # result csv name\n" ;
  print "        <fichier1> [<fichier2> ... <fichierN>] # Sources files list in command line\n" ;
  print "           or\n" ;
  print "        --file-list=<fichier de noms>          # Sources files list in listing a file\n" ;
  print "       [--allcounters]                         # Sort tous les compteurs associes a un langage (pour le c ou cpp)\n" ;
  print "       [--allow-external]                      # Desactivate filtering of external libraries\n" ;
  print "       [--allow-minified]                      # Desactivate filtering of minified files\n" ;
  print "       [--analyse-big-files]                   # Force l'analyse des gros fichiers de plus d'un mega-octet\n" ;
  print "       [--analyse-short-files]                 # Force l'analyse de fichiers sans code significatif\n" ;
  print "       [--AutoDetectEncoding]\n" ;
  print "       [--comptages]                           # sort les fichiers de comptage de test\n";
  print "       [--concatene-tous-les-comptages]        # concatene tous les fichiers de comptage de test en un seul\n" ;
  print "       [--config=<fichier>]                    # Specifie un fichier de configuration qui permet de changer\n" ;
  print "                                                 les seuils de V(g) et taux de commentaire\n" ;
  print "       [--debugfork]\n" ;
  print "       [--debug-no-vide-analysis]              # pour debug uniquement\n" ;
  print "       [--dir=<repertoire>]                    # Fixe un repertoire de sortie pour les resultats\n" ;
  print "       [--dir-project=<repertoire>]            # Where to find project files\n" ;
  print "       [--directload]\n" ;
  print "       [--dumpstrings]                         # Cree un fichier dump pour la liste des chaines \n" ;
  print "       [--frameworks]                          # activate frameworks detection\n" ;
  print "       [--framework-allow-mapping]             # allow to map discovered frameworks with HIGHLIGH known frameworks DB\n" ;
  print "       [--framework-insensitive-merge]         # use insensitive names to merge several detections of a same framework\n" ;
  print "       [--guid]                                # Specify GUID" ;
  print "                                                 Les analyseurs disponibles sont:\n";
  print "                                                 Nsdk Ksh PlSql Java Hpp Cobol VbDotNet Perl C H Cpp CS\n";
  print "       [--ignore]                              # List of regular expressions to exclude files by their names\n" ;
  print "       [--FMAdebug]\n" ;
  print "       [--Mnemo]                               # permet de ne sortir le fichier .detect.txt que le mnemo donne\n" ;
  print "       [--no-date-in-csv-filename]             # permet de ne pas mettre de date dans dans le nom du fichier csv\n" ;
  print "       [--NoAutoDetectEncoding]                # Desactive la detection automatique de l'encodage des caracteres\n" ;
  print "       [--nocompilateurswarnings]\n" ;
  print "       [--nocount]                             # Permet de ne tester que le strip, sans lancer les comptages.\n" ;
  print "       [--expandMacro]\n                       # Activate macro expansion";
  print "       [--crashprevent]                        # Oblige a lancer un processus par fichier analyse, pour des raisons\n" ;
  print "                                                 de performance, et de mise a jour des variables globales\n" ;
  print "       [--filtertrace=<fonctionnalites>]       # Les fonctionnalites que l'on ne souhaite pas tracer.\n" ;
  print "                                                 Exemple: grep,debug,trace\n" ;
  print "       [--noversion]                           # N'affiche pas la version utilisee de l'outil\n" ;
  print "       [--raztrace]\n" ;
  print "       [--runonecounterfunction]\n" ;
  print "       [--strip=<vue>]                         # Cree un fichier dump pour chaque vue demandee.\n" ;
  print "       [--strip_dir=<repertoire>]\n" ;
  print "       [--timing=<fonctionnalites>]            # Les fonctionnalites dont on souhaite mesurer les performances\n" ;
  print "                                                 Exemples: Super,Strip,Count                                  \n" ;
  print "       [--trace [=<nom de fichier de traces> ]]# Activation des traces (fichier par defaut : TRACES.txt)\n" ;
  print "       [--TraceDetect]                         # sort les fichiers .detect.txt\n" ;
  print "       [--TraceIn]\n" ;
  print "       [--TraceInconsistent]\n" ;
  print "       [--user-frameworks=<file>]              # Allow the user to specify its own framework csv database file\n" ;
  print "       [--verbose]\n" ;
  print "       [--version]                             # Affiche la version de l'outil\n" ;
  print "       [--app_version]                         # Positionne la version de l'application analysee\n" ;
  print "       [--app_type]                            # Positionne le type de l'application analysee\n" ;
  print "       [--WinMemoryUsage]\n" ;

  print "\n" . $message . "\n\n";
  # OLD value : -1
  exit Erreurs::PROCESS_COMMAND_LINE;
}



my $refProgression = undef;
my @filesToRemoveOnStop = ( );
my @callbacksOnStop = ( );

sub QuitHandler {       # 1st argument is signal name
  my($sig) = @_;
  my $stream = *STDOUT;
  print $stream "Caught a SIG$sig--shutting down\n";
  print STDERR "STDERR is available\n";

  IsoscopeDataFile::csv_file_close();

  if (defined $refProgression)
  {
    $refProgression->ProgressStopAppli( 3 );
  }
  else
  {
    print $stream "\n\nProgression not available\n\n";  
  }
  print $stream "Browsing callbacks...\n";
  for my $callback ( @callbacksOnStop )
  {
    print $stream "Callback ...\n" ;
    $callback->();
  }
  print $stream "Browsing files to be deleted ...\n";
  for my $filename ( @filesToRemoveOnStop )
  {
    print $stream "Removing $filename\n" ;
    if ( -f $filename ) {
      print $stream "-- check file exists ... OK\n";
      my $ret=unlink ($filename);
      if ($ret) {
        print $stream "-- $ret file(s) deleted...\n";
      }
      else {
        print $stream "-- ERROR when deleting $filename : $!\n";
      }
    }
    else {
      print $stream "-- WARNING : $filename does not exist. Cannot remove !!!\n";
    }

  }
  print $stream "Exit \n" ;
  # OLD value : 0
  exit(Erreurs::PROCESS_STOP_ON_SIGNAL);
}

sub AppendFilesToRemoveOnStop($)
{
  my ($filename) = @_;
  push @filesToRemoveOnStop, $filename;
}

sub AppendCallbackOnStop($)
{
  my ($callback) = @_;
#print STDERR "Debut de AppendCallbackOnStop\n";
  push @callbacksOnStop, $callback;
#print STDERR "Fin de AppendCallbackOnStop\n";
}


sub ProcessAnalyseParamApplication($)
{
  my ($context) = @_;
  my $analyseParam = $context->{'analyseParam'};
  my $options = $context->{'options'};
  my $resultFilename = $context->{'resultFilename'};
  # L'IHM ne souhaite que le nom du fichier, sans son repertoire.
  my $resultBaseFilename = $resultFilename;
  $resultBaseFilename =~ s{.*/}{}g ;
  my $status = 0;

  my $numberExpected = $analyseParam->GetFilesNumber();

  $refProgression = AnalyseOptions::GetProgression($options);
  $SIG{'INT'}  = \&QuitHandler ;
  $SIG{'QUIT'} = \&QuitHandler ;
  $SIG{'HUP'} = \&QuitHandler ;

    AnalyseOptions::GetProgression($options)->ProgressBeginAppli( $numberExpected, $resultBaseFilename );
    my $cumul = 0;
    my $anaName = '--start--';
    while (defined $anaName)
    {
      $anaName = $analyseParam->GetCurrentAnaName();
      if (defined $anaName)
      {
		my $techno = $anaName;
		$techno =~ s/\AAna//;
		$options->{'--language'} = $techno;
        my $anaListObject = $analyseParam->GetCurrentAnaList();
        if ( defined $anaListObject )
        {
          my $anaTimeout = $analyseParam->GetCurrentAnaTimeout();
          $options->{'--timeout'}=$anaTimeout;
          my $anaList = SourceUnit::redefineSource($anaListObject->GetFileList(), $anaName, AnalyseOptions::GetSourceDirectory($options), $options);
          $cumul += scalar @{$anaList};
          $status |= ProcessFileList ( $anaList, $options, $anaName);
        }
        else
        {
          AnalyseOptions::GetProgression($options)->ProgressEndList( 1 );
        }
      }
      $analyseParam->NextAna();
    }
    $status |= AnalyseUtil::trier_fichier_sortie ($resultFilename);

    # L'IHM ne souhaite que le nom du fichier, sans son repertoire.
    $resultFilename =~ s{.*/}{}g ;

    AnalyseOptions::GetProgression($options)->ProgressEndAppli( 
      ( $cumul != $numberExpected ) ? 2 : 0,
      $resultFilename );
  return $status;
}




#-------------------------------------------------------------------------------
# DESCRIPTION: Programme principal, traitement de la ligne de commande
#-------------------------------------------------------------------------------
sub main()
{
  my $cmd_line = join(' ', @ARGV);                                              # traces_filter_line
  print STDERR  "cmd_line:$cmd_line\n";                                         # traces_filter_line


  if ( Erreurs::isDebugModeActive() )
  {
    print STDERR "Erreurs::isDebugModeActive:" . Erreurs::isDebugModeActive() . "\n" ;
  }

  my $stringTOTAL = "duree de traitement totale";                               # timing_filter_line
  # 1 pour dire de toujours activer l'affichage.                                # timing_filter_line
  my $mainSummaryTiming = new Timing ($stringTOTAL, 1);                         # timing_filter_line
                                                                                # timing_filter_line


  my $parametres = AnalyseUtil::recuperer_options();
  my $options = $parametres->[0];
  my $fichiers = $parametres->[1];

  Erreurs::init($options);

  my $changeDirectory = AnalyseOptions::GetChangeDirectory($options);
  if (defined $changeDirectory)
  {
    chdir ($changeDirectory) or die "Can not chdir to $changeDirectory";
  }

  my $analyse_params_filename = $options->{'--analyse.params'};

  my %context = (
    'options' => $options,
    'fichiers' => $fichiers,
  );
  #print STDERR "STDERR is available before main_suite\n";

  my $status;
  #$status = main_suite(\%context);
  $status = ProcessManager::ProcessCallbackWaitingStopFile(
        $options,
        # L'execution continuera dans la suite du main, 
        # c'est-a-dire main_suite.
        \&main_suite,  
        \%context, 
        # La creation d'un process n'a lieu que lors d'un appel en mode IHM,
        # et en l'absence du mode de debug du perl.
        ( ( not Erreurs::isDebugModeActive() ) and
        defined $analyse_params_filename ? 1 : 0) );

  $mainSummaryTiming->markTimeAndPrint('');                                        # timing_filter_line
  return $status;
}

# Calcul du nom de fichier 
sub computeResultFilename($$$$$)
{
  my ( $optionOutputIdentifier, $COMPTAGE_SUFFIX, $startDate, $boolAppendDate, $outDir)=@_;
  my $resultsOutput ; 

    my $resultsBasename; # Nom de l'application
#    my $suffixe;
    $resultsBasename = $optionOutputIdentifier; # en premiere approximation
    if ($optionOutputIdentifier =~ m/(\.$COMPTAGE_SUFFIX)$/ )
    {
#      $suffixe = $1;
      $resultsBasename =~ s/(\.$COMPTAGE_SUFFIX)$//;
    }
#    else
#    {
#      $suffixe = '.' . $COMPTAGE_SUFFIX;
#    }

    my $fileDate = '';
    if ($boolAppendDate)
    {
      $fileDate = '-' . $startDate ;
    }
    $resultsOutput = $outDir . '/' . $resultsBasename
                     . $fileDate
#                     . $suffixe;
                     . ".$COMPTAGE_SUFFIX";

    return ($resultsOutput, $resultsBasename);
}

sub main_suite ($)
{
  my ($context) = @_;
  my $options = $context->{'options'};
  my $fichiers = $context->{'fichiers'};

  #print STDERR "STDERR is available in main_suite\n";

  my $appVersion;
  my $appType;
  my $resultsOutput = undef;
  my $CLIENT_FORMAT = 0;                                                        # traces_filter_line
  my $DEBUG_FORMAT = 1;
  my $outFmt = $DEBUG_FORMAT;

  my $analyse_params_filename = $options->{'--analyse.params'};

  my $analyseParam;
  my $DialogDirectory = AnalyseOptions::GetDialogDirectory($options);
  if ( defined $analyse_params_filename)
  {
    $analyse_params_filename = $DialogDirectory . $analyse_params_filename;
    print STDERR "Chargement du fichier $analyse_params_filename \n";
    $analyseParam = new AnalyseParam( $analyse_params_filename, $options);
  }

  my $TimingFilename = AnalyseOptions::GetTimingFilename($options);
  AppendFilesToRemoveOnStop( $TimingFilename );
  Timing->classInit( $options->{'--timing'}, $TimingFilename);                  # timing_filter_line
  AppendCallbackOnStop( \&Timing::classDestroy );

  my $mainTiming = new Timing ('main', $options->{'--timing'});                 # timing_filter_line

  my $ProgressionFilename= $DialogDirectory . 'progression.txt';
  Options::rec_mkdir_forfile($ProgressionFilename);
  my $progression = new Progression ($ProgressionFilename);
  AnalyseOptions::SetProgression ( $options, $progression);

  rmtree("tmp", 0, 1);
#  if (-d "tmp") {
#    unlink glob "tmp/*";
#  }
  Options::rec_mkdir("tmp");

  if (defined $options->{'chrono'})
  {
    IsoscopeDataFile::SetOptionChronoColumn()
  }

  # Le statut de l'analyse pour l'ensemble de fichiers
  my $status = 0;

  my $analyseur = $options->{'--language'};
  # mapping d'alias internes vers les noms courts des analyseurs.
  # c++ => cpp
  # h++ => hpp
  if (defined $analyseur)
  {
    if ($analyseur eq 'c++')
    {
      $options->{'--language'} = 'Cpp';
      $analyseur = $options->{'--language'};
    }
    elsif ($analyseur eq 'h++')
    {
      $options->{'--language'} = 'Hpp';
      $analyseur = $options->{'--language'};
    }
  }
  else {
	# option --language mandatory unles HMI mode.
    usage("Option --language is mandatory") unless $analyseParam; 
  }

  if (defined $options->{'--config'})
  {
    AnalyseOptions::load_ConfigFile($options, $options->{'--config'});
  }

  if ( defined $options->{'--version'})
  {
    print Lib::IsoscopeVersion::version () . "\n"  ;
    # OLD Value : 0
    exit(Erreurs::PROCESS_COMMAND_LINE);
  }

  if ( defined $options->{'--app_version'})
  {
    $appVersion = $options->{'--app_version'};
  }

  if ( defined $options->{'--app_type'})
  {
    $appType = $options->{'--app_type'};
  }
  else
  {
	$appType = 'echantillon';
  }

  my @tabFiles = @{$fichiers};

  my $COMPTAGE_SUFFIX = 'csv'; 
  
  my $outDir;

  if (not defined $options->{'--o'})
  {
    if ( scalar(@tabFiles) == 1)
    {
      # Dans le cas particulier ou le fichier csv de sortie n'est pas designe
      # et ou un seul fichier est a analyser,
      # on choisit de creer un fichier csv du nom du fichier analyse,
      # sans le chemin complet du fichier analyse.
      my $outputfilename =  $tabFiles[0];
      $outputfilename =~ s{.*[/\\]}{} ;
      $options->{'--o'} = $outputfilename . '.' .  $COMPTAGE_SUFFIX;
      print  "Option --o manquante, on suppose --o=" . $options->{'--o'}  . "\n";
    }
  }

  if (defined $options->{'--o'})
  {
    my $optionOutputIdentifier = $options->{'--o'}; # Option fournie par l'utilisateur

    my $format = $CLIENT_FORMAT;             # traces_filter_line

    $outDir = AnalyseOptions::GetOutputDirectory ( $options, '--dir' ) ||
                 AnalyseOptions::GetOutputDirectory ( $options, '--dir-output' ) ||
                 'output/met/' .             # traces_filter_line
                 './' ;

    Options::rec_mkdir($outDir);

    my $startDate = AnalyseOptions::get_date_as_amj_hm();

    my $boolAppendDate = (not defined $options->{'--no-date-in-csv-filename'});
    
    # Compute name for alarms counters output file
    my $resultsBasename;
    ($resultsOutput, $resultsBasename) = computeResultFilename($optionOutputIdentifier, $COMPTAGE_SUFFIX, $startDate, $boolAppendDate, $outDir);

	# Compute name for framework detection file
	if (defined $options->{'--frameworks'}) {
		my $resultsFrameworkOutput = $resultsOutput;
		$resultsFrameworkOutput =~ s/\.$COMPTAGE_SUFFIX$/\.framework\.$COMPTAGE_SUFFIX/;
		framework::main::setOutputFileName($resultsFrameworkOutput, $options);
	}
	# Compute name for CloudReady detection file
	if (defined $options->{'--CloudReady'}) {
		my $resultsCloudReadyOutput = $resultsOutput;
		$resultsCloudReadyOutput =~ s/\.$COMPTAGE_SUFFIX$/\.CloudReady\.$COMPTAGE_SUFFIX/;
		CloudReady::detection::setOutputFileName($resultsCloudReadyOutput);
	}

	# Compute name for keywordScan detection file
	if (defined $options->{'--KeywordScan'}) {
		my $resultsCloudReadyOutput = $resultsOutput;
		$resultsCloudReadyOutput =~ s/\.$COMPTAGE_SUFFIX$/\.KeywordScan\.$COMPTAGE_SUFFIX/;
		KeywordScan::detection::setOutputFileName($resultsCloudReadyOutput);
	}
	
	# Third Parties
	my $ThirdPartiesOutput = $resultsOutput;
	$ThirdPartiesOutput =~ s/\.$COMPTAGE_SUFFIX$/\.ThirdParties\.$COMPTAGE_SUFFIX/;
	Lib::ThirdParties::setOutputFileName($ThirdPartiesOutput);

    my $analysisBasename = $resultsBasename; # Valeur pour le mode ligne de commande non-IHM.
                                             # ( Interface definie par Florent)
    if ( defined $analyseParam ) # Si on est en mode IHM.
    {
                                             # ( Interface definie par Guillaume)
      $analysisBasename = $analyseParam->GetAnalysisBasename() || $resultsBasename;
    }
    $analysisBasename =~ s/[.]csv$//g ;

    AppendFilesToRemoveOnStop( $resultsOutput );
    AppendCallbackOnStop( \&IsoscopeDataFile::classDestroy );
    if (IsoscopeDataFile::csv_file_open($resultsOutput) != 0)
    {
      usage("Cannot open result file: $resultsOutput");
    }
    my $uuid = new UUID( ($analysisBasename || '' ) . 
                         ($ENV{'USERNAME'} || $ENV{'USER'} || '') . 
                         ($ENV{'COMPUTERNAME'} || hostname() || '') );

    my $app_type = defined $analyseParam ? 
                                           $analyseParam->GetAppType() 
                                         : $appType ; 

	my $HighlightVersion = Lib::IsoscopeVersion::getHighlightVersion();
	
	print "HIGHLIGHT analyzer version : $HighlightVersion\n";

    my %metadata = ( 'version_count' => Lib::IsoscopeVersion::version(),
                     'version_highlight' => Lib::IsoscopeVersion::getHighlightVersion(),
                     'app_version' => $appVersion,
                     'start_date' => $startDate,
                     'csv_base_filename' => $resultsBasename,
                     'base_name' => $analysisBasename, # FIXME
                     'uuid' => $uuid->AsString(),
                     'guid' => (defined $options->{'--guid'} ? $options->{'--guid'} : 'undefined'),
                     #'app_version' => $appVersion,
                     #'username' => $ENV{'USERNAME'} || $ENV{'USER'} || 'utilisateur inconnu',             # bt_filter_line
                     'app_type' => $app_type );

    my $refMetadata = \%metadata ;                                                                      # bt_filter_line
    IsoscopeDataFile::csv_set_metadata($refMetadata) ;                                                           # bt_filter_line
    
    # CloudReady
    if (defined $options->{'--CloudReady'}) {
        CloudReady::detection::setMetaData(\%metadata);
    }
    
    #KeywordScan
    if (defined $options->{'--KeywordScan'}) {
        KeywordScan::detection::setMetaData(\%metadata);
    }
    
    # Third Parties
    Lib::ThirdParties::setMetaData(\%metadata);
    Lib::ThirdParties::openOutputFile();
  }
  else
  {
   
    # option -o obligatoire
    usage("Option --o is mandatory");
  }

#  print STDERR IsoscopeVersion::version () ."\n" if ( not defined $options->{'--noversion'}) ; # traces_filter_line

  if (not defined  $analyseParam)
  {
  if ( scalar(@tabFiles) == 0)
  {
    # Aucun nom de fichier source n'ayant ete passe en ligne de commande,
    # l'option --file-list devrait designer un fichier contenant
    # la liste des fichiers sources a analyser
    #@tabFiles = Options::getFileList($options);
    my $fileList = new FileList ( AnalyseOptions::GetFileList($options) );
    @tabFiles = @{$fileList->GetFileList()};
  }

    usage ("List of files for analysis is empty") if ( scalar(@tabFiles) == 0);
  }
  $mainTiming->markTimeAndPrint('--init--');                                    # timing_filter_line
#  print STDERR "Type : $file_type\n" if defined $type ;                        # traces_filter_line

  AnalyseUtil::choisir_fichier_trace($options, \&AppendFilesToRemoveOnStop);
  Erreurs::ResetCompilerWarnings();                                             # traces_filter_line

  my $nb_files = scalar @tabFiles;

  if (defined  $analyseParam) # mode IHM
  {
    my %context = ( 
                          'analyseParam' => $analyseParam ,
                          'options' => $options ,
                          'resultFilename' => $resultsOutput ,
                  );
    $status |= ProcessAnalyseParamApplication(\%context);
    $analyseur = $options->{'--language'};
  }
  elsif ($nb_files)
  {
# dumpvues_filter_start
    if (exists $options->{'--concatene-tous-les-comptages'})
    {
      my $filename_tous_comptages = $options->{'--concatene-tous-les-comptages'};
      unlink($filename_tous_comptages);
    }
# dumpvues_filter_end
    @tabFiles = @{SourceUnit::redefineSource(\@tabFiles, $analyseur, AnalyseOptions::GetSourceDirectory($options), $options)};
    # Mode d'origine
    #AnalyseOptions::GetProgression($options)->ProgressBeginAppli( scalar @tabFiles);
    $status |= ProcessFileList ( \@tabFiles, $options, $analyseur  );
    $status |= AnalyseUtil::trier_fichier_sortie ($resultsOutput);
    #AnalyseOptions::GetProgression($options)->ProgressEndAppli( 0 );
  }
  else
  {
	print "ERROR: missing source file on command line !!\n";
  }

	if (defined $options->{'--frameworks'}) {
		framework::main::dumpFrameworkDetectionResults();
	}
	
	if (defined $options->{'--CloudReady'}) {
      CloudReady::detection::dumpCloudReadyDetectionResults();
      my $srcDir = AnalyseOptions::GetSourceDirectory($options);
      if (defined $options->{'--dbgMatchPatternDetail'}) {
        my $SCAN_LOG = CloudReady::lib::ElaborateLog::getScanLog();
        CloudReady::detection::dumpScanLog($analyseur, $SCAN_LOG, $srcDir, $outDir);
        #CloudReady::lib::ElaborateLog::deleteScanLog();
      }
    }
	
	if (defined $options->{'--KeywordScan'}) {
		KeywordScan::detection::dumpKeywordScanDetectionResults();
	}

  printf STDERR "Error: L'analyse globale des fichiers s'est terminee avec le code 0x%x\n", $status if ($status != 0);


#  $mainTiming->markTime($display);                                                # timing_filter_line
  $mainTiming->dump('main');                                                       # timing_filter_line
  WinMemoryUsage::PrintWinMemoryInfo() if (exists $options->{'--WinMemoryUsage'}); # memory_filter_line

  Erreurs::CloseInternalTrace();                                                   # traces_filter_line

#  if (not exists $options->{'--nocompilateurswarnings'})                           # traces_filter_line
#  {                                                                                # traces_filter_line
#    Erreurs::PrintCompilerWarnings($options);                                      # traces_filter_line
#  }                                                                                # traces_filter_line
  Erreurs::PrintExplicitStatus($status);
  return $status;
}

sub getGlobalContext($$$;$) {
	my $ana = shift;
	my $fileList = shift;
	my $options = shift;
	my $TabSourceDir = shift;
	
	my %H_GlobalContext = ();
	
	if (! defined $ana)
	{
		print STDERR "[WARNING] analyseur is undefined. Can not load global context ($@)\n" ;
		#return empty hash
		return {};
	}
	
	# In GUI context, the techno name is preceded by Ana (ex JSP -> AnaJSP). This prefix should be removed.
	$ana =~ s/^Ana//;
	
	my $module = $ana."/GlobalMetrics.pm";

	my $toolpath = $0;
	$toolpath =~ s/[^\\\/]*$//;
	$toolpath =~ s/[\\\/]$//;
	
	# Mecanism based on the presence of a module in a specific analyzer.
	if ( -f $toolpath."/".$module) {
	
		eval {
			require $module;
		};
		if ($@)
		{
			print STDERR "[WARNING] Unable to load module: $module. Global metrics will not be available. ($@)\n" ;
			#return empty hash
		}
		else {
			my $service = \&{"${ana}::GlobalMetrics::compute"};
			$H_GlobalContext{'GlobalMetrics'} = $service->($fileList, $options);
		}
	}
	
	# Macro treatment for Cpp, CCpp and Hpp techos
	if ( (defined $options->{'--expandMacro'}) && (($ana eq 'Cpp') || ($ana eq 'CCpp') || ($ana eq 'Hpp')) ) {
		for my $file (@$fileList) {
			my %fileDescr = ( 'name' => \$file, 'content' => undef, 'handler' => undef);
			
			Prepro::searchMacro(\%fileDescr, $options);
			Prepro::addIncludeDir($file);

			if (defined $fileDescr{'handler'}) {
				close $fileDescr{'handler'};
			}
		}
		$H_GlobalContext{'Macros'} = Prepro::GetMacros();
		
	}
#Prepro::printDirectories();

	return \%H_GlobalContext;
}

sub ProcessFileList($$$) {
  my ($refTabFiles, $options, $analyseur,) = @_;
  my $compteur = 0;
  my $mainTiming = new Timing('list', $options->{'--timing'}); # timing_filter_line
  $mainTiming->markTimeAndPrint('--init--');                   # timing_filter_line
  my $status = 0;

  my @tabFiles = ();

  # built file list in unified format (simple file tab).
  for my $item (@{$refTabFiles}) {
    my $fichier;

    # Will be an ARRAY if used with the --file-list with context specification (see. FileList::Load)
    if (ref $item eq 'ARRAY') {
      # $context is unused at this time.
      my $context;
      ($context, $fichier) = @{$item};
      push @tabFiles, $fichier;
    }
    else {
      push @tabFiles, $item;
    }
  }

  # Detect project directory
  #-------------------------
  Lib::Sources::init($options);
  
  my $TabSourceDir;
  if (defined $options->{'--dir-project'}) {
    $TabSourceDir = [ $options->{'--dir-project'} ];
    print("Project directory assumed to be : $TabSourceDir->[0] (from option --dir-project)\n");
  }
  elsif (defined $options->{'--dir-source'}) {
    $TabSourceDir = [ $options->{'--dir-source'} ];
    print("Project directory assumed to be : $TabSourceDir->[0] (from option --dir-source)\n");
  }
  else {
    # detect project directory from list of files.
    $TabSourceDir = Lib::Sources::getSourceDir(\@tabFiles, $options);
    print("Project directory(ies) assumed to be : " . join(" and ", @$TabSourceDir) . "\n");
  }

  # -------------- NODE MODULES FILTER -------------------
  # check if node_modules filter may be on or off
  # if a package.json or package-lock.json file is found outside the node_modules directory
  # => filter_node_modules is ON and otherwise is OFF by default
  # node_modules scan can be forced by --includeAllDependencies option
  my $filter_node_modules = 'OFF';
  if (!defined $options->{'--includeAllDependencies'}) {
    $filter_node_modules = Analyse::compute_filter_node_modules($TabSourceDir);
  }
  # -------------- FRAMEWORK DETECTION -------------------
  my $FrameworkDetector = undef;
  if (defined $options->{'--frameworks'}) {

    # init
    framework::main::init($options);

    framework::main::setTabSourceDir($TabSourceDir);

    # if a framework detector has been loaded, then call the method dedicated to
    # search frameworks inside source code.
    $FrameworkDetector = framework::main::getDetector($analyseur, $options);
    if (defined $FrameworkDetector) {
      $FrameworkDetector->preAnalysisDetection();
    }
  }
  # -------------- CloudReady DETECTION -------------------
  if (defined $options->{'--CloudReady'}) {
    if (defined $analyseur) {
      CloudReady::projectFiles::setMasterTechno($analyseur);
    }
    
    CloudReady::lib::ElaborateLog::init($options);
    
    # CloudReady detection in project files will occur after sources files analysis.
    Lib::Sources::registerPostAnalysisProjectFilesTrigger(\&CloudReady::projectFiles::detect);
  }
  # -------------- KeywordScan DETECTION -------------------
  if (defined $options->{'--KeywordScan'}) {
    # if (defined $analyseur) {
    # CloudReady::projectFiles::setMasterTechno($analyseur);
    # }
    # keyword scan detection for project files and source code files
    # /!\ only for searchItem csv version scope search is not supported
    Lib::Sources::registerPostAnalysisProjectFilesTrigger(\&KeywordScan::projectFiles::detect);
  }
  # -------------- GLOBAL CONTEXT -------------------

  # GLOBAL DCONTEXT : get global context, i.e. data global to all files of the application.
  # These data are extracted from special files (that are removed - or not - from the tabFiles), from the directory name, ...
  my $globalContext = getGlobalContext($analyseur, \@tabFiles, $options, $TabSourceDir);

  # -------------- SOURCE FILES ANALYSIS -------------------

  AnalyseOptions::GetProgression($options)->ProgressBeginList(scalar @tabFiles, $analyseur);

  my $nb_files = scalar @tabFiles;
  ##-------------------------------------------------------------
  # HL-1818 05/11/2021
  # Scan not done for generated code file
  # scan is done only if option --allowGeneratedCode is activated
  ##-------------------------------------------------------------
  my $parameters = AnalyseUtil::recuperer_options();
  my $allowGeneratedCode = $parameters->[0]->{'--allowGeneratedCode'};
  if (!defined $allowGeneratedCode) {
    my $techno = $analyseur;
    $techno =~ s/\AAna//;
    @tabFiles = @{Lib::GeneratedCodeException::checkGeneratedCodeFile(\@tabFiles, $techno)};
  }

  # analyse l'ensemble des fichiers sources
  for my $fichier (@tabFiles) {
    $compteur++;

    Timing->superTimerRestart($fichier, Timing->isSelectedTiming('Super')); # timing_filter_line
    print STDOUT "Analyse de $fichier ($compteur/$nb_files)\n" if ($nb_files > 1);
    print STDERR "Analyse de $fichier ($compteur/$nb_files)\n" if ($nb_files > 1); # traces_filter_line

    my $localStatus = 0; # statut pour le fichier en cours d'analyse
    $localStatus |= AnalyseFile($fichier, $options, $analyseur, $globalContext, $filter_node_modules);

    $mainTiming->markTime($fichier); # timing_filter_line
    Timing->superTimerDump();        # timing_filter_line
    $status |= $localStatus;
  }


  # -------------- POST ANALYSIS TREATMENTS -------------------

  Lib::Sources::postAnalysisProjectFilesScanning($TabSourceDir);

  if (defined $options->{'--frameworks'}) {
    if (defined $FrameworkDetector) {
      $FrameworkDetector->postAnalysisDetection();
    }
  }
  if (defined $options->{'--KeywordScan'}) {
    KeywordScan::projectFiles::postAnalysisDetection();
  }

  Lib::ThirdParties::closeOutput();

  AnalyseOptions::GetProgression($options)->ProgressEndList(0);
  $mainTiming->dump('list');
  return $status;
}



#-------------------------------------------------------------------------------
# DESCRIPTION: Lancement de l'analyse sur un fichier source
# Analyse de fichier avec si besoin,
# detection de crash de l'analyseur
#-------------------------------------------------------------------------------
sub AnalyseFile($$$$$)
{
  my ($fichier, $options, $analyzer, $globalContext, $filter_node_modules ) = @_ ;
  Erreurs::SetCurrentFilenameTrace($fichier);
  AnalyseOptions::GetProgression($options)->ProgressBeginFile( $fichier);
  my $status = AnalyseUtil::AnalyseFile($fichier, $options, $analyzer, $globalContext, $filter_node_modules, \&AnalyseFileInternal);
  return $status;
}

# dumpvues_filter_start
#-------------------------------------------------------------------------------
# DESCRIPTION: Calcule le repertoire de sortie et le nom du fichier
# pour comptage.txt
#-------------------------------------------------------------------------------
sub CalculateOutputsComptageTxt($$)
{
  my ($fichier, $options) = @_ ;
    my $output_dir  = AnalyseOptions::GetOutputDirectory ( $options, '--dir' ) ||
                      'output/met/' .                                # traces_filter_line
                      './' ;

    my $base_filename = $fichier;
    $base_filename =~ s{.*/}{};

    my $outputFilename = $output_dir . $base_filename  . '.comptages.txt' ;
    return ($output_dir, $outputFilename);
}
# dumpvues_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: Analyse de fichier interne (sans detection de crash)
#-------------------------------------------------------------------------------
sub AnalyseFileInternal($$$$$)
{
  my ($originalFilename, $options, $analyseur, $globalContext, $filter_node_modules) = @_ ;
  my $couples ; 
  my $status  = 0; # Le fichier retourne un code d'erreur forme par la combinaison des valeurs

  my $chronoStart;
  if (defined $options->{'--chrono'} )
  {
    $chronoStart = Analyse::ChronoStart();
  }
  # Check existance of source file, taking into account several possible encodings for filename.
  my $needEncoding = Lib::Sources::needEncodingForExisting(AnalyseOptions::GetSourceDirectory($options), $originalFilename); 
  if (defined $needEncoding) {
	  if ($needEncoding ne "unknow") {
		  # encode file name with the detected encoding
		  $originalFilename = Encode::encode($needEncoding, $originalFilename);
		  print STDERR "/!\\ using encodage $needEncoding for file name : $originalFilename\n";
		  print STDERR "-->".Lib::Data::hexdump_String($originalFilename)."\n";
	  }
	  else {
		  print STDERR "WARNING : file $originalFilename seems to be not existing in default encoding\n";
		  print STDERR "--> ".Lib::Data::hexdump_String($originalFilename)."\n";
	  }
  }

  # Suppression des retours a la ligne dans les noms de fichiers
  # pour clarifier les traces de debug                                       # traces_filter_line
  my $fichier = $originalFilename;
  $fichier = Analyse::RemoveNonPrintableCharacters($fichier);

  if (not defined $analyseur)
  {
    print STDERR "ERROR : Analyzer not specified !\n" ;
    Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'unspecified analyzer'); # traces_filter_line
    return Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
  }

  my $analyseur_name = Analyse::GetAnaFullName($analyseur);

  my $date = Analyse::get_date_as_numerical_string();
  my $retour = AnalyseUtil::creer_compteur($fichier, $date );
  $couples = $retour->[0];
  my $compteurs = $couples;
  $status |= $retour->[1];

# dumpvues_filter_start
  my ($output_dir, $outputFilename);
  if (defined $options->{'--comptages'} )
  {
    # si les fichiers temporaires sont autorises
    # en mode test
    ($output_dir, $outputFilename) = CalculateOutputsComptageTxt($fichier, $options);
    Options::rec_mkdir_forfile ( $outputFilename);
    Couples::counter_write_csv_tag_crash($compteurs, $outputFilename, $options);
  }
# dumpvues_filter_end


  my $vue;

  my $sourceFilename;

  #if (SourceUnit::get_SourceMode() != $SourceUnit::MODE_NORMAL ) {
  if (SourceUnit::get_AnalysisMode() == $SourceUnit::REDEFINE_ON ) {
    # If source have been redefined into analysis unit, all files are copied in
    # the tmp dir, including those that are in normal mode. This could be a
    # future improvement to be driven ...
    # So in this case, $originalFilename is allready relative to the execution
    # directory...
    $sourceFilename = $originalFilename;
  } 
  else {
    $sourceFilename = AnalyseOptions::GetSourceDirectory($options) . $originalFilename;
  }

  if (not -f $sourceFilename)
  {
    print STDERR "ERROR : file $sourceFilename does not exists\n";
    Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'fichier inexistant', $sourceFilename);
    $status |= Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
    $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_NOT_FOUND, $couples, 'Fichier inexistant');
  }
  else
  {

    print "ORIGINAL FILE NAME = $originalFilename\n" if ($originalFilename ne $sourceFilename);
    my $ContextType = SourceUnit::get_UnitInfo($originalFilename, 'type');

    if (defined $ContextType) {
      $status |= Couples::counter_add($compteurs, 'Dat_ContextType', $ContextType);
    }

    $vue = SourceLoader::mainLoadFile($sourceFilename, $options);
    my %dumpFunctions = ();
    $vue->{'dump_functions'} = \%dumpFunctions;

    $vue->{'global_context'} = $globalContext;

    if (defined $vue->{'bin'}) {

      if (defined $vue->{'text'}) {

        my $CRC = Lib::Crc::crc32(\$vue->{'text'});
        $status |= Couples::counter_add($compteurs, 'Dat_CRC', $CRC);

        my $SHA;
        # HL-2006 13/06/2022 apply node_modules filter and add value 'excluded' to SHA
        if ($filter_node_modules eq 'ON' && $sourceFilename =~ /\bnode\_modules\b/) {
          $status |= Couples::counter_add($compteurs, 'Dat_SHA256', 'excluded');
        }
        else {
          $SHA = Lib::SHA::SHA256(\$vue->{'bin'});
          $status |= Couples::counter_add($compteurs, 'Dat_SHA256', $SHA);
        }

        eval {
          #print "ANA FULL NAME : $analyseur_name\n";
          $status |= Analyse::process_file($analyseur_name, $fichier, $vue, $options, $compteurs);
        };

        if (defined $options->{'--CloudReady'}) {
          CloudReady::detection::setAbortCause($compteurs->{'Dat_AbortCause'});
        }

        if (defined $options->{'--KeywordScan'}) {
          KeywordScan::detection::setAbortCause($compteurs->{'Dat_AbortCause'});
        }

        if ($@) {
          Timeout::DontCatchTimeout();                                                                                # propagate timeout errors
          print STDERR "ERROR: failure detected in Analyse::process_file: $@";                                        # FIXME: a garder dans le produit?
          Erreurs::LogInternalTraces('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'erreur interne', $@); # traces_filter_line
          $status = Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
        }
        else {
          if (defined $options->{'--frameworks'}) {
            # FRAMEWORK DETECTION: detection inside source code.
            # if a framework detector has been loaded, then call the method dedicated to
            # search frameworks inside source code.
            my $FrameworkDetector = framework::main::getDetector($analyseur_name, $options);

            if (defined $FrameworkDetector) {
              $FrameworkDetector->insideSourceDetection($vue, $fichier);
            }
          }
        }

        if (Erreurs::isAborted($status)) {
          my $abortCause = $compteurs->{'Dat_AbortCause'};
          if (($abortCause eq Erreurs::ABORT_CAUSE_WRAPPED->[1]) ||
              ($abortCause eq Erreurs::ABORT_CAUSE_GENERATED_FILE->[1]) ||
              ($abortCause eq Erreurs::ABORT_CAUSE_EXTERNAL_LIB->[1])) {
            Lib::ThirdParties::addFile($fichier, $abortCause, $SHA);
          }
        }
      }
      else {
        # le fichier est qualifie de 'Binary'
        print STDERR "ERROR: binary file detected $fichier\n";
        $status |= Erreurs::FatalError(Erreurs::ABORT_CAUSE_BINARY, $compteurs, 'Fichier binaire');
        $status |= Erreurs::COMPTEUR_STATUS_FICHIER_ENTREE;
      }
    }
    else {
      # le fichier n'est pas lisible
      print STDERR "ERROR: can nnot open file $fichier\n";
      $status |= Erreurs::FatalError(Erreurs::ABORT_CAUSE_NOT_READABLE, $compteurs, 'Ouverture impossible');
      $status |= Erreurs::COMPTEUR_STATUS_FICHIER_ENTREE;
    }
  }

  #my $sourceFilename = AnalyseOptions::GetSourceDirectory($options) . $fichier;
  my $filesize = (stat($sourceFilename))[7];

  my $progRef = AnalyseOptions::GetProgression($options);
  my $basename = $sourceFilename;
  $basename =~ s{.*[/\\]}{}g ;


  $progRef->ProgressEndFile( 
	  $basename,
	  $filesize,
          $couples->counter_get_values()->{Erreurs::MNEMO_ABORT_CAUSE_CLASS},
          $couples->counter_get_values()->{Erreurs::MNEMO_ABORT_CAUSE_NUMBER} );

  # Memorize the reason of the end of the analysis. 
  #my $endAnalysisReason = $couples->counter_get_values()->{Erreurs::MNEMO_ABORT_CAUSE_NUMBER};

  my $isUnitMode = $couples->counter_get_values()->{'Dat_UnitMode'};

  # Treat chrono mode if any ...
  if (defined $options->{'--chrono'} )
  {
    my $chronoElapsed = Analyse::ChronoStop($chronoStart);
    $status |= Couples::counter_add($compteurs, 'Dat_Chrono', $chronoElapsed );
  }

  # CHECK FOR MISSING COMMENTS ...
  # ... if the analysis has not ended with fatal error and if the analysis was not
  # in unit mode ...
  #
  # NOTE : For unit mode implemented with the module SourceUnit.pm, the status
  # ABORT_CAUSE_ANALYSIS_UNIT_MODE has not been set here. The files unit are
  # considered in this treatment as whole source files, beacause it is an
  # external splitting. The unit mode is only indicated in the data written
  # in the progression file for display purpose but it is transparent for here,
  # were the data contain the results of the analysis of the unit.
  #
  # In the cas of an internal spliting of the sources, one file will produce
  # several analysis, so the present treatment of result analysis is be done
  # after each unit in another module. So the data here are inconsistant because
  # they are related to the whole file that has not been analyzed (only the
  # units into which it has been split)

  #if ( (! Erreurs::isAborted($status)) && (! Erreurs::isUnitMode($endAnalysisReason)) ) {
  if ( (! Erreurs::isAborted($status)) && (! $isUnitMode) ) {
    $status |= AnalyseUtil::checkMissingMnemonics($couples);
  }

  # Record datas in the CSV, unless we are in internal unit splitting mode.
  # (in this last case, record has already been done after each unit analysis !)
  #if (! Erreurs::isUnitMode($endAnalysisReason)) {
  if (! $isUnitMode) {
    AnalyseUtil::recordResults($couples, $status, $options);
  }

  # FIXME : this option sould be removed. It consist in generating a dump of
  # counters in a file xxx.comptage.txt in a non-csv format. This was for the
  # obsolete method of test unit. the option --comptages should be removed from
  # the product.
  if (defined $options->{'--comptages'} )
  {
          # si les fichiers temporaires sont autorises
          AnalyseUtil::memoriser_resultat_fichier_test ($options, $compteurs, $output_dir, $outputFilename);
  }



  return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Point d'entree
#-------------------------------------------------------------------------------

my $mainStatus = main();

#printf STDERR "Le programme s'est termine avec le code 0x%x\n", $mainStatus; # traces_filter_line

exit (Erreurs::getExitStatus());
