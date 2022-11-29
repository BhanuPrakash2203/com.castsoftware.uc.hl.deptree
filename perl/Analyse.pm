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
# DESCRIPTION: Module d'analyse independant du langage
#----------------------------------------------------------------------#

package Analyse;

use strict;
use warnings;

use Options;
use Couples;
use Erreurs ; # pour les traces.                                                # traces_filter_line
use AnaUtils;
use Timeout;
use Progression;
use FileLines; # Pour compter les lignes.
use Lib::IsoscopeVersion;
use File::Find;
use Time::HiRes qw( gettimeofday tv_interval );

use SourceUnit;

use KeywordScan::detection;

# prototypes publics
sub process_file($$$$$);
sub setDefaultLanguage($$$);

# prototypes prives
sub require_module ($);
sub chargement_dynamique_analyseur($);
sub AnaLangage($$$$$$);

# taille max d'un fichier analysable: 3 mega (octets), au dela de cette taille, le fichier n'est pas analyse par defaut
use constant FILEMAXSIZE => 3072000;  # 3000 * 1024
my $filter_node_modules = 'OFF';

#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction de chargement dynamique d'un module.
#-------------------------------------------------------------------------------
sub require_module ($)
{
  my ($module_name)=@_;

  eval
  # ce mecanisme permet de recuperer les defauts de require, mais pas de use
  {
    require $module_name; # Nom du module .pm
    return undef;
  };
  if ($@)
  {
    print STDERR "Unable to load module: $module_name\n" ;
    return $@;
  }
  return undef; # Le module a deja ete charge.
}

my %DisponibiliteParModule;

#-------------------------------------------------------------------------------
# DESCRIPTION: Exemple de lancement d'un analyseur avec chargement dynamique
#-------------------------------------------------------------------------------
sub chargement_dynamique_analyseur($)
{
  my ( $analyseur) = @_ ;
  # Chargement de l'analyseur
  my $module =  $analyseur .  '.pm' ;

  if (defined $DisponibiliteParModule{$module} )
  {
    return $DisponibiliteParModule{$module} ? undef : 'Module deja signale en erreur precedement.';
  }

  my $erreur_chargement = require_module ( $module);
  if ( not defined $erreur_chargement ) # Si analyseur disponible
  {
    $DisponibiliteParModule{$module} = 1;
    return  undef;
  }
  
  
  
  $DisponibiliteParModule{$module} = 0;
  #print STDERR $erreur_chargement;
  warn $erreur_chargement;

  return $erreur_chargement;
}

sub ChronoStart()
{
  my $StartTime = [gettimeofday];
  return $StartTime;
}

sub ChronoStop($)
{
  my ( $StartTime ) = @_;
  my $StopTime = [gettimeofday];
  my $Elapsed = tv_interval ( $StartTime, $StopTime);
  return $Elapsed;
}

# DESCRIPTION: Liste des analyseurs disponibles

# Permet d'obtenir la casse correcte pour un analyseur.
my %analyseur_name_canonisation = (
  'abap' =>  'Abap',
  'cobol' =>  'Cobol',
  'ksh' =>  'Ksh',
  'cs' =>   'CS',
  'c' =>   'C',
  'h' =>   'H',
  'cpp' =>   'Cpp',
  'hpp' =>   'Hpp',
  'ccpp' =>   'CCpp',
  'objc' =>   'ObjC',
  'objcpp' =>   'ObjCpp',
  'objccpp' =>   'ObjCCpp',
  'java' => 'Java',
  'js' => 'JS',
  'jsp' => 'JSP',
  'jspscript' => 'JSPScript',
  'vbdotnet' => 'VbDotNet',
  'nsdk' => 'Nsdk',
  'pl1' => 'PL1',
  'plsql' => 'PlSql',
  'tsql' => 'TSql',
  'php' => 'PHP',
  'python' => 'Python',
  'typescript' => 'Typescript',
  'scala' => 'Scala',
  'go' => 'Go',
  'rust' => 'Rust',
  'coldfusion' => 'Coldfusion',
  'coffeescript' => 'Coffeescript',
  'ruby' => 'Ruby',
  'delphi' => 'Delphi',
  'erlang' => 'Erlang',
  'lua' => 'Lua',
  'rexx' => 'Rexx',
  'fs' => 'FS',
  'lisp' => 'Lisp',
  'ada' => 'Ada',
  'smalltalk' => 'Smalltalk',
  'matlab' => 'Matlab',
  'r' => 'R',
  'assembly' => 'Assembly',
  'apex' => 'Apex',
  'swift' => 'Swift',
  'kotlin' => 'Kotlin',
  'natural' => 'Natural',
  'groovy' => 'Groovy',
  'fortran' => 'Fortran',
  'db2' => 'DB2',
  'postgresql' => 'PostgreSQL',
  'mysql' => 'MySQL',
  'clojure' => 'Clojure',
  'mariadb' => 'MariaDB',
  'jcl' => 'JCL',
  'imsdb' => 'IMSDB',
  'imsdc' => 'IMSDC',
  'cics' => 'CICS'
);

# DESCRIPTION: Selection de l'analyseur en fonction du type et du langage du fichier
#-------------------------------------------------------------------------------
sub CanoniseAnalyseurName($)
{
  my ($laxist_analyseur_name) = @_;

  my $correct_analyseur_name = $analyseur_name_canonisation{ lc($laxist_analyseur_name) };
  if (not defined $correct_analyseur_name)
  {
    print STDERR 'Available analyzers are : ' .
      join ( ' ', values(%analyseur_name_canonisation) ) . "\n" ;
    #FIXME?
  }
  return $correct_analyseur_name;
}

# Choix de l'analyseur (recuperation d'un nom complet).
sub GetAnaFullName($)
{
  my ($analyseur_option) = shift;
  
  my $analyseur_name;

  if ( defined $analyseur_option)
  { 
    if ( $analyseur_option =~ /^Ana/ )
    {
      $analyseur_name = $analyseur_option;
    }
    else
    {
      $analyseur_name = CanoniseAnalyseurName($analyseur_option);
      if (defined $analyseur_name)
      {
        $analyseur_name = 'Ana' . $analyseur_name;
        print STDERR "Analyzer: $analyseur_option -> $analyseur_name\n" ;
      }
      else
      {
        print STDERR "Unknow analyzer : $analyseur_option\n" ;
      }
    }
  }
  else
  {
	print "ERROR : no technology specified !!\n";
  }
  return $analyseur_name;
}


# Traitement d'un fichier pour un langage donne
#sub AnaLangageGetCallBack($$$$$$)


# Traitement d'un fichier pour un langage donne
sub AnaLangageAnalyse($$$$;$)
{
  my ( $analyseur_name, $vue, $options, $couples, $fichier) = @_;
  my $status = 0;
  print STDERR "Launching analyzer $analyseur_name\n";
  my $analyseur_analyse =  \&{"${analyseur_name}::Analyse"} ;
  $status |= $analyseur_analyse->( $fichier, $vue, $options, $couples);
  return $status;
}

# traces_filter_start

# FIXME: a mettre dans le module gerant le format du fichier CSV?
# DESCRIPTION: Renvoi un identifiant unique a la seconde pres.
# L'unicite est garantie par le fait que le script n'est
# pas lance plus de deux fois, en moins d'une seconde.
sub get_date_as_numerical_string ()
{
   # recuperation de la date et de l'heure par localtime
   my ($S, $Mi, $H, $J, $Mo, $A) = (localtime) [0,1,2,3,4,5];
   return  sprintf('%04d%02d%02d%02d%02d%02d',
        eval($A+1900), eval( $Mo +1) , $J, $H, $Mi, $S);
}

sub RemoveNonPrintableCharacters($)
{
  my ($buffer) = @_;

  my $x2028 = pack("U0C*", 0xe2, 0x80, 0xa8); # U+2028 LINE SEPARATOR
  my $x2029 = pack("U0C*", 0xe2, 0x80, 0xa9); # U+2029 PARAGRAPH SEPARATOR
  my $x0085 = pack("U0C*", 0xc2, 0x85);       # U+0085 <control>
  my $x000a = pack("U0C*", 0x0a);             # U+000A <control>
  my $x000b = pack("U0C*", 0x0b);             # U+000B <control>
  my $x000c = pack("U0C*", 0x0c);             # U+000C <control>
  my $x000d = pack("U0C*", 0x0d);             # U+000D <control>
  $buffer =~ s#(?:$x000a|$x000b|$x000c|$x000d|$x0085|$x2028|$x2029)|$x000d$x000a|##g;
  return $buffer;
}

# traces_filter_end

my $nb_perl_warnings; # traces_filter_line

#-------------------------------------------------------------------------------
# DESCRIPTION: Point d'entree du module
#-------------------------------------------------------------------------------
sub process_file($$$$$)
{
  my ($analyseur_name, $fichier, $vue, $options, $couples) = @_;
  # Le fichier retourne un code d'erreur forme par la combinaison des valeurs

  my $compteurs = $couples;
  my $status =0 ;
  $fichier = RemoveNonPrintableCharacters($fichier);

# traces_filter_start
  Erreurs::SetCurrentFilenameTrace($fichier);

  $nb_perl_warnings = 0;

  my $previous_warn_handler = $SIG{'__WARN__'} ;
  $SIG{'__WARN__'} = sub
  {
    my $message = $_[0];
    $nb_perl_warnings += 1;
    
    warn $_[0] ;
    
    if ($_[0] =~ /^Unescaped left brace in regex is illegal/m) {
		print STDERR "---- PERL VERSION DOES NOT SUPPORT DEPRECATED REGEXP !!! ----\n";
		exit (Erreurs::PROCESS_UNSUPPORTED_REGEXP);
	}
    
    if ( defined $previous_warn_handler and $previous_warn_handler ne '' )
    {
      $previous_warn_handler->($message);
    }
  };

# traces_filter_end
  my $sourceFilename;
 
  if (SourceUnit::get_AnalysisMode() == $SourceUnit::REDEFINE_ON ) {
    # If source have been redefined into analysis unit, all files are copied in
    # the tmp dir, including those that are in normal mode. 
    # So in this case, $fichier is allready relative to the execution
    # directory...
    $sourceFilename = $fichier;
  }
  else {
    $sourceFilename = AnalyseOptions::GetSourceDirectory($options) . $fichier;
  }
  

  my $filesize = (stat($sourceFilename))[7];

if (! defined $filesize) {

  if ( ! -f $sourceFilename) {
print "File not found : $sourceFilename\n";
  }
  else {
print "File exists : $sourceFilename\n";
  my @tt = stat($sourceFilename);
print STDERR join ",", @tt;
}
}

  print STDERR "File = $fichier ; size = $filesize\n";                     # traces_filter_line
  my $b_force_analyse_big_files = ((defined $options->{'--analyse-big-files'})? 1 : 0);

  $status |= FileLines::CountFileLines(undef,  $vue, $compteurs);

  AnalyseOptions::GetProgression($options)->ProgressLineNumberFile(
    $compteurs->counter_get_values()->{'Dat_Lines'} );
    
  #AnaLangageGetCallBack($$$$$$)
{
  #my ($detected_language, $mode_analyse, $fichier, $vue, $options, $compteurs) = @_;
  my $status ; # Le fichier retourne un code d'erreur forme par la combinaison des valeurs
  my $mnemo_Dat_Language = 'Dat_Language' ;

  if (defined $analyseur_name)
  {
    my $erreur_chargement_analyseur = chargement_dynamique_analyseur($analyseur_name) ;

    if ( (not defined $erreur_chargement_analyseur) && defined $analyseur_name)
    {
      my $analyseur_short_name = $analyseur_name;
      $analyseur_short_name =~ s/^Ana//g ;
      
      KeywordScan::detection::init($options, $analyseur_short_name);
      
      $status |= Couples::counter_add($couples, 'Dat_AnaModel', Lib::IsoscopeVersion::GetDataModelVersion($analyseur_short_name) ) ;
      $status |= Couples::counter_add($couples, $mnemo_Dat_Language, $analyseur_short_name ) ;
    }
    else
    {
      my $message = "Analyzer $analyseur_name not available\n" ;
      print STDERR $message . "\n";
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'Analyseur non pris en charge', $analyseur_name); # traces_filter_line
      $status = Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS; # cas d'erreur
      $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_MISSING_ANALYSER, $couples, $message);
      Erreurs::addExitStatus(Erreurs::PROCESS_UNAVAILABLE_TECHNO);
      return $status;
    }
  }
  else
  {
    print STDERR "Bad analyzer\n" ;
    Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'suffixe non associe', ''); # traces_filter_line
    $status = Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS; # cas d'erreur
    $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_MISSING_ANALYSER, $couples, 'analyseur inconnu');
    Erreurs::addExitStatus(Erreurs::PROCESS_UNAVAILABLE_TECHNO);
    return $status;
  }
}

  if (($filesize <  FILEMAXSIZE) || $b_force_analyse_big_files)
  { # on lance l'analyse

	print STDERR "Force analyze of file up to 3MB ($filesize octets) !!!!\n" if (($b_force_analyse_big_files) && ($filesize >  FILEMAXSIZE));

    # On se fixe un timeout de 20 minutes par fichier,
    my $timeout = 20 * 60;
    if ( Erreurs::isDebugModeActive() )
    {
      $timeout = 0;
    }
    if ( defined $options->{'--timeout'} )
    {
      $timeout = $options->{'--timeout'};
    }
    
    # NOMINAL CASE:
    # If the "eval" of the execution of the routine \&AnaLangageAnalyse produce no
    # exception, then $status1 contain the status of the call to this function.
    #
    # EXCEPTION CASE:
    # if the execution produce an exception, "the callback error" routine will
    # be called:
    # - if it is an timeout exception, $status2 will result of a fatal error with the
    #   cause : ABORT_CAUSE_TIMEOUT.
    # - if it is another exception, it will be propogated (see TryCatchTimeout) (and so 
    #   we will not continue to execute this code).
    my ($status1, $status2) = Timeout::TryCatchTimeout(
      \&AnaLangageAnalyse,
      [$analyseur_name, $vue, $options, $couples, $fichier],
      # [$detected_language, $mode_analyse, $fichier, $vue, $options, $compteurs] , #ancienne interface

      sub ($$)
      {
        my ( $couples, undef, $value ) = @_;
        my $status = 0;
        $status |= Erreurs::FatalError ($value, $couples, 'Timeout:' .$timeout. ' seconds');
        return $status;
      },
      [$compteurs, Erreurs::MNEMO_ABORT_CAUSE, Erreurs::ABORT_CAUSE_TIMEOUT] ,


      $timeout
    );
    $status |= (defined $status1 ) ? $status1 : $status2;


    # l'analyse est terminee
    if (not exists $compteurs->{Erreurs::MNEMO_ABORT_CAUSE})
    {   # par defaut il n'y a pas eu de cause d'arret
      $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_NONE, $compteurs, undef);
    }
  }
  else
  { # on ne lance pas l'analyse
    # this is just to register/load mnemonics for the corresponding analyzer.
    print STDERR "File too big: $fichier\n";
    $status |= Erreurs::COMPTEUR_STATUS_FICHIER_ENTREE;
    $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_FILE_TOO_BIG, $compteurs, "Taille du fichier: " . $filesize . ' octets');
        my $callback_verrue =  \&{"${analyseur_name}::FileTypeRegister"} ;
	my $prot = prototype  $callback_verrue;

	if ( $prot eq '$') {
	   # this is the former version of the register routine, available
	   # for analyseurs dedicated to one language.
           $status |= $callback_verrue->( $options);
        }
	else {
	  # this the new routine, implemented by analyser that groups several
	  # languages. 
	    $callback_verrue =  \&{"${analyseur_name}::FileTypeRegister_notAnalysed"} ;
	  $status |= $callback_verrue->(  $fichier, $compteurs, $options)
	}
  }

# traces_filter_start

  print STDERR "Number of perl warnings: $nb_perl_warnings\n" if ($nb_perl_warnings > 0);
  $status |= Couples::counter_add($compteurs, 'debug_Dat_nb_compiler_warning', $nb_perl_warnings );
  $SIG{'__WARN__'} = $previous_warn_handler;

# traces_filter_end

  return $status;
}

# HL-2006 13/06/2022
sub compute_filter_node_modules($) {
  my $dir = shift;
  # For analysis and framework discovery: check if node_modules filter may be ON or OFF
  # if a package.json or package-lock.json file is found outside the node_modules directory
  # => filter_node_modules is ON and otherwise is OFF by default
  find({ wanted  => sub {
    if ($File::Find::name =~ /\b(?:package(\-lock)?\.json)$/m
        && $File::Find::name !~ /\bnode\_modules\b/) {
      $filter_node_modules = 'ON';
      return $filter_node_modules;
    }}, no_chdir => 1 # no_chdir option for allowing long path scan file
  }, @{$dir});

  return $filter_node_modules;
}

sub get_node_modules_filter {
  return $filter_node_modules;
}

1;
