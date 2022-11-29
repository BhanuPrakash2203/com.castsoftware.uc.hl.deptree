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
# DESCRIPTION: Composant definissant les codes d'erreurs.
#----------------------------------------------------------------------#

package Erreurs;

# les modules importes

use strict;
use warnings;
use IO::Handle;   # traces_filter_line
use Encode;
use Traces;

# Erreurs pour les comptages

# Valeur attribuee par un module de comptage,
# lorsque le decompte de la valeur echoue
#use constant COMPTEUR_ERREUR_VALUE      => -1; 
sub COMPTEUR_ERREUR_VALUE {return -1;}

# Valeur attribuee par le module Csvfile,
# lorsque la valeur d'un comptage n'est pas disponible
#use constant COMPTEUR_EMPTY_VALUE => ''; 
sub COMPTEUR_EMPTY_VALUE {return -1;}

##use constant COMPTEUR_UNAVAILABLE_VALUE => -2; 

# Erreurs pour les statuts retournes par les compteurs
#use constant COMPTEUR_STATUS_SUCCES                              =>   0;
sub COMPTEUR_STATUS_SUCCES {return 0;}
#use constant COMPTEUR_STATUS_PB_STRIP                            =>   1;
sub COMPTEUR_STATUS_PB_STRIP {return 1;}
#use constant COMPTEUR_STATUS_VUE_ABSENTE                         =>   2;
sub COMPTEUR_STATUS_VUE_ABSENTE {return 2;}
#use constant COMPTEUR_STATUS_INTERFACE_COMPTEUR                  =>   4;
sub COMPTEUR_STATUS_INTERFACE_COMPTEUR {return 4;}
#use constant COMPTEUR_STATUS_ERREUR_ETENDUE                      =>   8;  # s'il y a des codes d'erreur superieur a 255
sub COMPTEUR_STATUS_ERREUR_ETENDUE {return 8;}
#use constant COMPTEUR_STATUS_FICHIER_ENTREE                      =>  16;
sub COMPTEUR_STATUS_FICHIER_ENTREE {return 16;}
#use constant COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES =>  32;
sub COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES {return 32;}
#use constant COMPTEUR_STATUS_AUTRES_ERREURS                      =>  64;
sub COMPTEUR_STATUS_AUTRES_ERREURS {return 64;}

#use constant COMPTEUR_STATUS_CRASH_ANALYSEUR                     => 128; # traces_filter_line
sub COMPTEUR_STATUS_CRASH_ANALYSEUR {return 128;}
#use constant COMPTEUR_STATUS_FICHIER_NON_COMPILABLE              => 256;
sub COMPTEUR_STATUS_FICHIER_NON_COMPILABLE {return 256;}
#use constant COMPTEUR_STATUS_ABORTED                             => 512;
sub COMPTEUR_STATUS_ABORTED {return 512;}
#use constant COMPTEUR_STATUS_INCOHERENCE_PARSE                   =>1024;
sub COMPTEUR_STATUS_INCOHERENCE_PARSE {return 1024;}
#use constant COMPTEUR_STATUS_WARNING				 =>2048;
sub COMPTEUR_STATUS_WARNING {return 2048;}
#use constant COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE     =>0x1000;
sub COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE {return 0x1000;}

# Chaines pour erreur fatale de Dat_AbortCause
#use constant MNEMO_ABORT_CAUSE => 'Dat_AbortCause';
sub MNEMO_ABORT_CAUSE {return 'Dat_AbortCause';}
#use constant MNEMO_ABORT_CAUSE_NUMBER => 'Dat_AbortCauseNumber';
sub MNEMO_ABORT_CAUSE_NUMBER {return 'Dat_AbortCauseNumber';}
#use constant MNEMO_ABORT_CAUSE_CLASS => 'Dat_AbortCauseClass';
sub MNEMO_ABORT_CAUSE_CLASS {return 'Dat_AbortCauseClass';}
#use constant MNEMO_ABORT_CAUSE_NOT_ENOUGH_CODE => 'Dat_AbortCauseNoCode';
sub MNEMO_ABORT_CAUSE_NOT_ENOUGH_CODE {return 'Dat_AbortCauseNoCode';}



# Les raisons d'abandon d'analyse se caracterisent par 
# une constante numerique (permettant de definir le besoin de gestion d'erreur)
# une constante literale (inscrite dans le fichier CSV)
# et se decoupent en trois classes,
# conformement au document 
# Spec/Specification_fichier_progression_IHM_analyseur.doc:
# Classe  Description          Sortie CSV/XML
# F1      Ok                   Le fichier a été correctement analysé
# F2      Analyse interrompue  Le fichier est présent sous forme d'erreur dans les résultats
# F3      Non analysable       Le fichier n'est pas présent dans le CSV.


# Absence de cause d'abandon
#use constant ABORT_CAUSE_NONE         => [ 0, 'None', 1];
sub ABORT_CAUSE_NONE {return [ 0, 'None', 1];}

# Analyse abandonnee en raison de la taille du fichier
#use constant ABORT_CAUSE_FILE_TOO_BIG => [ 1, 'FileTooBig', 2];
sub ABORT_CAUSE_FILE_TOO_BIG {return [ 1, 'FileTooBig', 2];}

# Non reconnu comme fichier texte
#use constant ABORT_CAUSE_BINARY       => [ 2, 'Binary', 3];
sub ABORT_CAUSE_BINARY {return [ 2, 'Binary', 3];}

# Fichier illisible
#use constant ABORT_CAUSE_NOT_READABLE => [ 3, 'NotReadable', 3];
sub ABORT_CAUSE_NOT_READABLE {return [ 3, 'NotReadable', 3];}

# Fichier non trouve
#use constant ABORT_CAUSE_NOT_FOUND    => [ 4, 'NotFound', 3];
sub ABORT_CAUSE_NOT_FOUND {return [ 4, 'NotFound', 3];}

# 
#use constant ABORT_CAUSE_SYNTAX_ERROR => [ 5, 'SyntaxError', 2];
sub ABORT_CAUSE_SYNTAX_ERROR {return [ 5, 'SyntaxError', 2];}

# Fichier obfuscate
#use constant ABORT_CAUSE_WRAPPED      => [ 6, 'Wrapped', 3];
sub ABORT_CAUSE_WRAPPED {return [ 6, 'Wrapped', 3];}

# Interruption de l'analyse sur Time-out
#use constant ABORT_CAUSE_TIMEOUT      => [ 7, 'Timeout', 2];
sub ABORT_CAUSE_TIMEOUT {return [ 7, 'Timeout', 2];}

# Incompatibilite entre le langage et l'analyseur:
#use constant ABORT_CAUSE_BAD_ANALYZER => [ 8, 'LanguageAnalyserMismatch', 3];
sub ABORT_CAUSE_BAD_ANALYZER {return [ 8, 'LanguageAnalyserMismatch', 3];}

# Code insuffisant pour l'utilisation des modeles:
#use constant ABORT_CAUSE_NOT_ENOUGH_CODE => [ 9, 'NonsignificantForRiskAnalysis', 3];
sub ABORT_CAUSE_NOT_ENOUGH_CODE {return [ 9, 'NonsignificantForRiskAnalysis', 3];}

# Code insuffisant pour l'utilisation des modeles:
#use constant ABORT_CAUSE_MISSING_ANALYSER => [ 10, 'AnalyserNotAvailable', 2];
sub ABORT_CAUSE_MISSING_ANALYSER {return [ 10, 'AnalyserNotAvailable', 2];}

# About AnalysisUnitMode :
# Le fichier soumis a analyse a �t� recompose en plusieurs fichier contenant des unite
# d'analyse. Il n'a pas ete luiu-m�me analyse en tant que fichier. Les erreurs concretes
# sont celles qui sont associees a l'analyze des fichiers d'unite d'analyse.
#
# RQ : the abort class is not significant and is initialized to 1. It may be modified by the
# analyzer accoording to the context.
sub ABORT_CAUSE_ANALYSIS_UNIT_MODE {return [ 11, 'AnalysisUnitMode', 1];}

sub ABORT_CAUSE_GENERATED_FILE {return [ 12, 'Generated', 3];}
sub ABORT_CAUSE_EXTERNAL_LIB {return [ 13, 'External library', 3];}


sub PrintExplicitStatus($) {
  my ($status) = @_;
  my $stream = *STDERR;
  if (($status & COMPTEUR_STATUS_SUCCES) != 0) {
    print $stream "    STATUT : l'analyse s'est deroulee avec SUCCES.\n";
    $status -= COMPTEUR_STATUS_SUCCES;
  }
  if (($status & COMPTEUR_STATUS_PB_STRIP) != 0) {
    print $stream "    STATUT : probleme dans le STRIP.\n";
    $status -= COMPTEUR_STATUS_PB_STRIP;
  }
  if (($status & COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE) != 0) {
    print $stream "    STATUT : Un ou plusieurs COMPTAGES NON EFFECTUES.\n";
    $status -= COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE;
  }
  if (($status & COMPTEUR_STATUS_VUE_ABSENTE) != 0) {
    print $stream "    STATUT : Il y a une VUE ABSENTE\n";
    $status -= COMPTEUR_STATUS_VUE_ABSENTE;
  }
  if (($status & COMPTEUR_STATUS_INTERFACE_COMPTEUR) != 0) {
    print $stream "    STATUT : Probleme d'enregistrement des COUPLES.\n";
    $status -= COMPTEUR_STATUS_INTERFACE_COMPTEUR;
  }
  if (($status & COMPTEUR_STATUS_FICHIER_ENTREE) != 0) {
    print $stream "    STATUT : COMPTEUR_STATUS_FICHIER_ENTREE\n";
    $status -= COMPTEUR_STATUS_FICHIER_ENTREE;
  }
  if (($status & COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES) != 0) {
    print $stream "    STATUT : Il y des problemes d'association ACCOLADES / PARENTHESE.\n";
    $status -= COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES;
  }
  if (($status & COMPTEUR_STATUS_AUTRES_ERREURS) != 0) {
    print $stream "    STATUT : Erreurs NON CARACTERISEES.\n";
    $status -= COMPTEUR_STATUS_AUTRES_ERREURS;
  }
  if (($status & COMPTEUR_STATUS_CRASH_ANALYSEUR) != 0) {
    print $stream "    STATUT : L'analyseur s'est CRASHE.\n";
    $status -= COMPTEUR_STATUS_CRASH_ANALYSEUR;
  }
  if (($status & COMPTEUR_STATUS_FICHIER_NON_COMPILABLE) != 0) {
    print $stream "    STATUT : Le code est NON COMPILABLE.\n";
    $status -= COMPTEUR_STATUS_FICHIER_NON_COMPILABLE;
  }
  if (($status & COMPTEUR_STATUS_ABORTED) != 0) {
    print $stream "    STATUT : ANALYSE INTERROMPUE.\n";
    $status -= COMPTEUR_STATUS_ABORTED;
  }
  if (($status & COMPTEUR_STATUS_INCOHERENCE_PARSE) != 0) {
    print $stream "    STATUT : Incoherence detectee lors de l'analyse du fichier..\n";
    $status -= COMPTEUR_STATUS_INCOHERENCE_PARSE;
  }
  if ( $status != 0 )
  {
    printf $stream "autres flags positionnes: 0x%x \n",$status;
  }
}


sub isDebugModeActive()
{
  #my () = @_;
  return ($^P);
}

sub isAborted($)
{
  my ($status) = @_;
  return (($status & COMPTEUR_STATUS_ABORTED) != 0)
}

sub isUnitMode($)
{
  my ($value) = @_;
  return ($value == ABORT_CAUSE_ANALYSIS_UNIT_MODE->[0]);
}

# Contournement d'un bug dans l'outil stunnix:
# la comparaison de deux references sur un meme tableau n'est pas fiable.
sub IsAbortCauseDefined($)
{
  my ($value) = @_;
  return ($value->[0] != ABORT_CAUSE_NONE->[0]);
}

sub setAbortCause($$;$)
{
  my ($value, $couples, $abortClass) = @_;
  my $status = 0;
  $status |= Couples::counter_add ($couples, Erreurs::MNEMO_ABORT_CAUSE_NUMBER, $value->[0]);
  $status |= Couples::counter_add ($couples, Erreurs::MNEMO_ABORT_CAUSE, $value->[1]);
  if (defined $abortClass) {
    $status |= Couples::counter_add ($couples, Erreurs::MNEMO_ABORT_CAUSE_CLASS, $abortClass);
  }
  else {
    $status |= Couples::counter_add ($couples, Erreurs::MNEMO_ABORT_CAUSE_CLASS, $value->[2]);
  }
  return $status;
}

sub FatalError($$$)
{
  my ($value, $couples, $message) = @_;
  my $status = setAbortCause($value, $couples);
  #if ( $value != ABORT_CAUSE_NONE )
  if ( IsAbortCauseDefined($value) )
  {
    LogInternalTraces ('erreur', undef, undef, 'Abort', join ('.',@{$value}), $message) ;
    $status |= Erreurs::COMPTEUR_STATUS_ABORTED;
    print STDERR 'Abort : ' . $value->[1] . ': ' . $message . "\n" ;
  }
  return $status;
}

# traces_filter_start

#=======================================================================
#                      traces / logs 
#=======================================================================

# prototypes

sub OpenInternalTrace ($$$$);
sub LogInternalTraces ($$$$$;$);
sub CloseInternalTrace ();

sub OpenCompilerWarnings ($$);
sub PrintCompilerWarnings ($);
sub ResetCompilerWarnings ();

# variables privees

my $TraceFileName = undef;
my $FD_Log ;
my %TraceFilter = ();
my $current_filename = '';
my $violations_to_dump = undef;

sub init($) {
	my $options = shift;
	my $violdump = $options->{'--dump-violations'};
	
	if (defined $violdump ) {
		$violations_to_dump = {};
		if ($violdump ne '') {
			for my $mnemo (split ',', $violdump) {
				$violations_to_dump->{$mnemo} = 1;
			}
		}
		else {
			$violations_to_dump->{'*'} = 1;
		}
	}
}

# Ce module est capable de gerer deux formats d'encodages:
# Le mode utf-8, lorsque $trace_stores_monobyte_characters=0
# permet de représenter tous les caracteres.
# Le mode 'iso-8859-1' ne represente pas tous les caracteres, mais est 
# compatible avec d'anciens editeurs de texte.
my $trace_stores_monobyte_characters=1;
my $trace_encoding = "iso-8859-1" ;

my $fic_warning = 'warning_compilateurs.txt';

# Pour ne pas avoir le fichier warning_compilateurs.txt
# dans le repertoire courant, il faut bien definir son
# repertoire de creation.
sub OpenCompilerWarnings ($$)
{
  my ($ouputDir, $filename, $mode) = @_ ;
  $fic_warning = $ouputDir . $filename;
}


sub ResetCompilerWarnings ()
{
  unlink ($fic_warning);
}

#use constant COULEUR_RED_BOLD_ON_BLUE => "\e[31;44;1m";
sub COULEUR_RED_BOLD_ON_BLUE {return "\e[31;44;1m";}
#use constant COULEUR_RED_BOLD_ON_BLACK => "\e[31;40;1m";
sub COULEUR_RED_BOLD_ON_BLACK {return "\e[31;40;1m";}
#use constant COULEUR_NORMAL => "\e[0m";
sub COULEUR_NORMAL {return "\e[0m";}
my %compilateur_warning_dejavue = ();
sub LogCompilerWarnings ($)
{
  my ($msg) = @_;
  # format UNIX
  my $local_normal = Erreurs::COULEUR_NORMAL;
  my $local_red_bold_on_blue = Erreurs::COULEUR_RED_BOLD_ON_BLUE;

  if ($msg eq '')
  {
    return;
  }

  # Ce filtrage montre les messages de warning hors contexte!
  if (not exists $compilateur_warning_dejavue{$msg})
  {
    $compilateur_warning_dejavue{$msg}++;
    open my $FIC_WARN, '>>:raw', $fic_warning or die "cannot write to $fic_warning $!";
    #my $str = $local_red_bold_on_blue . $msg . $local_normal;
    my $str =  $msg ;
    print { $FIC_WARN } "$str";
    close $FIC_WARN;
  }
}


sub OpenInternalTrace ($$$$)
{
  my ($ouputDir, $filename, $mode, $paramTraceFilter) = @_ ;


  if ( ${^UTF8LOCALE} gt 0 )
  {
    $trace_stores_monobyte_characters = 0;
  } 

  for my $type ( @{$paramTraceFilter} )
  {
    $TraceFilter{$type} = 1;
    $TraceFilter{lc($type)} = 1;
    $TraceFilter{uc($type)} = 1;
  }

  if ( $filename eq 'STDERR' ) {
    $FD_Log = *STDERR;
  }
  elsif ( $filename eq 'STDOUT' ) {
    $FD_Log = *STDOUT;
  }
  else {
    $TraceFileName = $ouputDir . $filename;

    if ( $trace_stores_monobyte_characters == 1)
    {
      $mode .= 'encoding(' . $trace_encoding .')';
    }
    else
    {
      $mode .= ':utf8';
    }

    # FIXME: apres cet appel a open, le fork ne marche plus sur une machine windows!
    if (not open (my $TRACE, $mode, "$TraceFileName")) {
      $FD_Log = undef;
      print STDERR "[OpenInternalTrace] Impossible d'ouvrir le  fichier $TraceFileName.\n";
      return -1;
    }
    else {
      $FD_Log = $TRACE ;
      print STDERR "[OpenInternalTrace] Ouverture du fichier $TraceFileName.\n";
      $TRACE->autoflush (1);
    }
  }

  #my $layer = ":encoding(iso-8859-1,Encode::FB_PERLQQ)" ; 
  #binmode($FD_Log, $layer);

  # Ajout d'un handler pour recuperer les avertissements
  # du compilateur, dans les traces.
  # wipe out *all* compile-time warnings
  $SIG{'__WARN__'} = sub {
    my $message = $_[0];
    LogInternalTraces ('warning', undef, undef, 'perl', $message, '') ;
    my $msg = $current_filename . ' : ' . $message ;
    print STDERR $msg . "\n";
    #warn $_[0] if $DOWARN
    LogCompilerWarnings ($msg);
  } ;

  Traces::SetCallback( \&LogInternalTraces);
  return 0;
}


sub PrintCompilerWarnings ($)
{
  my ($options) = @_ ;
  my $local_normal = Erreurs::COULEUR_NORMAL;
  my $local_color = Erreurs::COULEUR_RED_BOLD_ON_BLACK;

  if (not -f "$fic_warning")
  {
    return;
  }
  # sinon, il y a des erreurs

  LogCompilerWarnings (' - - - - - - - - - - - - - - - ' . "\n"); #On marque la separation entre deux processus d'analyse...

  # FIXME: pourquoi STDOUT, plutot que STDERR?
  my $stream = *STDOUT ; 
  if (open (my $stream_input_warnings, '<' . $fic_warning)) 
  {
    print { $stream } $local_color ;
    for my $ligne (<$stream_input_warnings>)
    {
      print {  $stream }  $ligne ;
    }
    # pas de commande unix sous windows
    #my $cmd = "cat $fic_warning\n";
    #system ($cmd);
    print {  $stream } $local_normal . "\n" ;
  }
}


sub SetCurrentFilenameTrace ($)
{
  my ($filename) = @_ ;
  $current_filename = $filename;
}

sub GetCurrentFilenameTrace ()
{
  return $current_filename ;
}

sub isDumpViolationRequired($) {
	my $mnemo =	shift;
	
	return ( 	(exists $violations_to_dump->{'*'}) ||
				( (defined $mnemo) && ( exists $violations_to_dump->{$mnemo}))
				);
}

sub VIOLATION($$;$$) {
	my ($mnemo, $libelle, $pattern, $line) = @_ ;
	my $msg = "";
	
	return if (! isDumpViolationRequired($mnemo) );
	
	if (defined $mnemo) {
		$msg .= "[$mnemo] ";
	}
	
	$msg .= "$libelle ";
	if (defined $line) {
		$msg .= " [line $line]";
	}
	
	print STDOUT "$msg\n";
}

# D'apres l'incident Bugzilla 56, (reunion du 7 avril 2008)
#  Les messages doivent être caractérisés en tant que messages de:
#    - erreur
#    - warning: code isoscope
#    - info: code client
#    - debug
sub LogInternalTraces ($$$$$;$)
{
  my ($type, $filename, $line, $comptage, $pattern_brut, $free) = @_ ;

  my $pattern = $pattern_brut;
  if ( (defined $FD_Log) and ( not defined $TraceFilter{$type} ) )
  {
    if (not defined $free) {
      $free = '';
    }

    if (not defined $filename) {
      $filename = $current_filename;
    }

    if (not defined $line) {
      $line = 1;
    }
    
    if (not defined $type) {
		$type = 'unknow';
	}

    # Suppression des blancs de fin de ligne dans la pattern.
    $pattern =~ s/\s*\n\s*/  /smg;
    $pattern =~ s/\s*\n?\z//sm;

    my $data = "$filename:$line:[$comptage]:**** $type ****: $pattern : $free\n"; 
    if ( $trace_stores_monobyte_characters == 1)
    {
      # FB_PERLQQ pour eviter le warning: "Wide character in print"
      print { $FD_Log } encode( $trace_encoding, $data, Encode::FB_PERLQQ);
    }
    else
    {
      print { $FD_Log } $data;
    }
  }
} 

sub CloseInternalTrace () {
  if (defined $FD_Log) {
#    if (( $TraceFileName ne "STDERR") && ( $TraceFileName ne "STDOUT" )) {
    if ( defined $TraceFileName ) {
      print STDERR "[CloseInternalTrace] Fermeture du fichier $TraceFileName.\n";
      close $FD_Log;
    }
  }
}

# PROCESS ERRORS :
use constant PROCESS_OK => 0;
use constant PROCESS_UNAVAILABLE_TECHNO => 1;
use constant PROCESS_STOP_ON_SIGNAL => 2;
use constant PROCESS_COMMAND_LINE => 3;
use constant PROCESS_UNSUPPORTED_REGEXP => 4;

my $ExitStatus = PROCESS_OK;

sub addExitStatus($) {
	$ExitStatus = shift;
}

sub getExitStatus() {
	return $ExitStatus;
}

# traces_filter_end

#print "Attention utilisation de Erreurs.pm V1\n";
1;
