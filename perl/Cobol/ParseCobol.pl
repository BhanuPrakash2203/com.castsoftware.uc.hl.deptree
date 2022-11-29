#!/usr/bin/perl -w
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


use strict "vars";
use Timing;
#use strict;

require "Couples.pm";
require "violation.pm";
require "Cobol::Vue.pm";
require "metriques.pm";
 require "AlignVerb.pm";
 require "CmplxCond.pm";
 require "CodeComment.pm";
 require "Compute.pm";
 require "ConstantLit.pm";
 require "ContigusLevel.pm";
 require "Fichier.pm";
 require "MotInterdit.pm";
 require "Obsolete.pm";
 require "PictureIndent.pm";
 require "PresClause.pm";
 require "ThruParaExit.pm";
 require "ValueIndent.pm";
 require "Var.pm";
 require "Copy.pm";
# require "EssaiCodeMort.pm";

require "FonctionIntegree.pm";
 require "Working.pm";
 require "Ident.pm";
 require "FileSection.pm";
 require "Move.pm";
 require "MultInst.pm";
 require "Evaluate.pm";
 require "Goto.pm";
 require "CheckSQL.pm";

if (!defined($ARGV[0])) {
    print << "EOF";

Parse_Cobol.pl <fichier>


EOF

    exit(0);
}

# renvoi un identifiant unique.
# L'unicite est garantie par le fait que le script n'est
# pas lance plus de deux fois, en moins d'une seconde.
sub get_date_as_numerical_string ()
{
   # recuperation de la date et de l'heure par localtime
   my ($S, $Mi, $H, $J, $Mo, $A) = (localtime) [0,1,2,3,4,5];
   return  sprintf("%04d%02d%02d%02d%02d%02d",
        eval($A+1900), eval( $Mo +1) , $J, $H, $Mi, $S);
}

# Fonction de creation d'un repertoire
sub rec_mkdir_forfile($)
{
  my ($output_filename) = @_;
  my $output_dir = $output_filename;

  print "Creation de " . $output_dir . "\n";
  $output_dir =~ s{(.*/).*}{$1}smg ;

  rec_mkdir ( $output_dir);
}

# Fonction recursive: declaration prealable.
sub rec_mkdir($);

# Fait en perl, pour portabilite windows
#system ( "mkdir -p ". $dir);
sub rec_mkdir($)
{
  my ($p_dir) = @_;
  if ( not -d $p_dir )
  {
    print  "Demande de cration de " . $p_dir . "\n" ;
    my $dir = $p_dir ;
    if ( $dir =~ s{(.*)/.*}{$1}smg )
    {
      {
          rec_mkdir($dir);
      }
    }
    mkdir ( $p_dir);
  }
}



my $timing;

    $/ = undef;
foreach my $filename (@ARGV) {
    print "Analyse de $filename \n";
    my $StructFichier = Couples::counter_create();
    Couples::counter_add($StructFichier,"Dat_FileName",$filename);

    open (FILE, "<$filename") || die "Unable to read \"$filename\"\n";
    local $/ = undef;
    my $buffer = <FILE>;
    close(FILE); 
# Transformation fin de ligne MS Windows|VMS -> UNIX
 #   $buffer =~ s/\r?\n/\n/g;


    my $countersTiming = new Timing ("Temps des fonctions de comptage", 1 );
    my $proto = "Init";
    my $index = 1;
    my $comptageName = $proto;
    my $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing) ;

#preparation du buffer
    PrepareBuffer(\$buffer);
# bufferText contient le texte original en ayant supprimer le colonage 1..6
# et les eventuel 8 chiffres de fin de ligne

    $proto = "PrepareBuffer";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

#Detection d'un programme ou d'un copy
    my $detectedLanguage = undef;
    my $type = undef;
    if ($buffer =~ m/^\s+(PROCEDURE|IDENTIFICATION)\s+DIVISION\s*\./sgm) {
        $detectedLanguage = "Cobol";
    } else {
    }

    if (defined $detectedLanguage )
    {
	print  "detect language: " . $detectedLanguage . " " . $filename . "\n";
        $type = "Cobol";
    } else {
	print  $filename . ":attention, n\'est pas un programme Cobol\n";
	next;
    }

    my $status = 0;
#    $status |= Couples::counter_add($StructFichier, "Dat_FileName", $filename );
    my $date = get_date_as_numerical_string();
    $status |= Couples::counter_add($StructFichier, "Dat_AnalysisDate", $date );
    $status |= Couples::counter_add($StructFichier, "Dat_LanguageDetected", $detectedLanguage ) if (defined  $detectedLanguage );
    $status |= Couples::counter_add($StructFichier, "Dat_LanguageType", $type )              if (defined  $type);
    $status |= Couples::counter_add($StructFichier, "Dat_Language", $type )              if (defined  $type);


    $proto = "Fin Init";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);



# bufferText 0 contiendra la vue texte après décalage des instructions mal colonnées.
    my $bufferText0=$buffer;
#Verification des BadZone
    BadZone(\$bufferText0, $StructFichier);

#chaine seule
    my $bufferText1=$bufferText0;
    StripChaine(\$bufferText1, $StructFichier);

#Chaine et comment
    my $bufferText2=$bufferText1;
    StripComment(\$bufferText2, $StructFichier);

#comment seul
    my $bufferText3=$bufferText0;
    StripComment(\$bufferText3, $StructFichier);

    $proto = "StripAll";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
# bufferIdentDiv contiendra la vue Identification division
    my $bufferIdentDiv = $bufferText3;
    IdentDiv(\$bufferIdentDiv, $StructFichier);

    $proto = "IdentDiv";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
# bufferEnvDiv contiendra la vue Environement division
    my $bufferEnvDiv = $bufferText3;
    EnvDiv(\$bufferEnvDiv, $StructFichier);

    $proto = "EnvDiv";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
# bufferDataDiv contiendra la vue Data division
    my $bufferDataDiv = $bufferText3;
    DataDiv(\$bufferDataDiv, $StructFichier);

    $proto = "DataDiv";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
# bufferProcDiv contiendra la vue Prodecure division
    my $bufferProcDiv = $bufferText3;
    ProcDiv(\$bufferProcDiv, $StructFichier);

    $proto = "ProcDiv";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
# bufferInOutSect contiendra la vue InOut$ Section
    my $bufferInOutSect = $bufferText3;
    InOutSect(\$bufferInOutSect, $StructFichier);

    $proto = "InOutSect";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
# bufferWorkingSect contiendra la vue Working Section
    my $bufferWorkingSect = $bufferText3;
    WorkingSect(\$bufferWorkingSect, $StructFichier);

    $proto = "WorkingSect";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
# bufferFileSect contiendra la vue File Section
    my $bufferFileSect = $bufferText3;
    FileSect(\$bufferFileSect, $StructFichier);

    $proto = "FileSect";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);


# Metrologie
#Fait mais traitement du perform à revoir
    GetMetriques($bufferText1,$filename,$StructFichier);
##     PrintViogen($StructFichier);
    $proto = "GetMetriques";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

# fait

       Ident($bufferIdentDiv, $StructFichier, $filename,"","DATA");
    $proto = "Ident";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
       FileSection($bufferFileSect, $StructFichier, $filename,"","DATA");
    $proto = "FileSection";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

#Fait
       Working($bufferWorkingSect, $StructFichier, $filename,"","DATA");
    $proto = "Working";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
       Move($bufferProcDiv, $StructFichier, $filename);
    $proto = "Move";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
       MultInst($bufferProcDiv, $StructFichier, $filename,"","PROC");
    $proto = "MultInst";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
       Evaluate($bufferProcDiv, $StructFichier, $filename,"","PROC");
    $proto = "Evaluate";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
       Goto($bufferProcDiv, $StructFichier, $filename,"","PROC");
    $proto = "Goto";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);
       CheckSQL($bufferProcDiv, $StructFichier, $filename,"","PROC");
    $proto = "CheckSQL";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);


##SUP       MotInterditFS($bufferFileSect, $StructFichier, $filename,"","DATA");
##SUP       MotInterditWS($bufferWorkingSect, $StructFichier, $filename,"","DATA");
##SUP       MotInterditPD($bufferProcDiv, $StructFichier, $filename,"","PROC");
       MotInterdit($bufferFileSect, $bufferWorkingSect, $bufferProcDiv,$StructFichier, $filename);
    $proto = "MotInterdit";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

##SUP        Obsolete($filename,"","DATA");
##SUP        Obsolete($filename,"","PROC");
       MotObsolete($bufferIdentDiv, $bufferEnvDiv, $bufferInOutSect, $bufferFileSect, $bufferWorkingSect, $bufferProcDiv,$StructFichier, $filename);
    $proto = "MotObsolete";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

       CodeComment($bufferText0, $StructFichier, $filename);
    $proto = "CodeComment";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

       ContigusLevel($bufferWorkingSect, $StructFichier, $filename);
    $proto = "ContigusLevel";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

        PictureIndent($bufferWorkingSect, $StructFichier, $filename);
    $proto = "PictureIndent";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

        ValueIndent($bufferWorkingSect, $StructFichier, $filename);
    $proto = "ValueIndent";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

        AlignVerb($bufferProcDiv,$StructFichier, $filename);
    $proto = "AlignVerb";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

########        FonctionIntegree($bufferProcDiv,$StructFichier, $filename);
    $proto = "FonctionIntegree";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

       CmplxCond($bufferProcDiv,$StructFichier,$filename);
    $proto = "CmplxCond";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

        ThruParaExit($bufferProcDiv,$StructFichier,$filename);
    $proto = "ThruParaExit";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

        Fichier($bufferInOutSect, $bufferFileSect, $bufferProcDiv, $StructFichier, $filename);

        PresClause($bufferProcDiv,$StructFichier,$filename);

        Var($bufferWorkingSect,$bufferProcDiv,$StructFichier,$filename);

        ConstantLit($bufferProcDiv,$StructFichier,$filename);

     Compute($bufferProcDiv,$filename,$StructFichier);
    $proto = "Compute";
    $index ++;
    $comptageName = $proto;
    $display = $index . ':' . $comptageName . '(' . $proto .')'  ;
    $countersTiming->markTimeAndPrint($display) if ( defined $timing);

####### A voir pour plus tard
#     EssaiCodeMort($filename);
#     CopyInclude($bufferProcDiv,$StructFichier,$filename);
    my $output_dir  =  "output/met/" ;
    print   "Repertoire de sortie de comptages: " . $output_dir . "\n" ;
    my $output_filename = $output_dir . $filename  . '.comptages.txt' ;
    rec_mkdir_forfile ( $output_filename);
    Couples::counter_write_csv($StructFichier,$output_filename);
    $countersTiming->dump('PerfParComptage') if ( defined $timing);
    print  "\nL'analyse du fichier s'est termine avec le code " . $status . "   " . "0x". hex ($status) . "\n" ;
}



