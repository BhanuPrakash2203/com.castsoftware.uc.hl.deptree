#----------------------------------------------------------------------#
#                         @ISOSCOPE 2008                               #
#----------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                  #
#               Adresse : TERSUD - Bat A                               #
#                         5, AVENUE MARCEL DASSAULT                    #
#                         31500  TOULOUSE                              #
#               SIRET   : 410 630 164 00037                            #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Plugin
# Lancement de l'analyse d'un fichier source Cobol

package AnaCobol;

use strict;
use warnings;
use Erreurs;
use Options;
use CheckCobol;
use StripCobol; # parser Cobol
use Vues;
use Timeout;
use IsoscopeDataFile;
use Timing;
use AnaUtils;

require "Couples.pm";
use Cobol::violation;
use Cobol::Vue;
use Cobol::metriques;
 require "Cobol/AlignVerb.pm";
 require "Cobol/CmplxCond.pm";
 require "Cobol/CodeComment.pm";
 require "Cobol/Compute.pm";
 require "Cobol/ConstantLit.pm";
 require "Cobol/ContigusLevel.pm";
 require "Cobol/Fichier.pm";
 require "Cobol/MotInterdit.pm";
 require "Cobol/Obsolete.pm";
 require "Cobol/PictureIndent.pm";
 require "Cobol/PresClause.pm";
 require "Cobol/ThruParaExit.pm";
 require "Cobol/ValueIndent.pm";
 require "Cobol/Var.pm";
 require "Cobol/Copy.pm";
# require "EssaiCodeMort.pm";

require "Cobol/FonctionIntegree.pm";
 require "Cobol/Working.pm";
 require "Cobol/Ident.pm";
 require "Cobol/FileSection.pm";
 require "Cobol/Move.pm";
 require "Cobol/MultInst.pm";
 require "Cobol/Evaluate.pm";
 require "Cobol/Goto.pm";
use Cobol::CheckSQL;

use Cobol::CobolCommon;
use CloudReady::CountCobol;
use CloudReady::detection;

sub Strip($$$$)
{
  my ($fichier, $vue, $options, $couples) =@_ ;

  my $status = 0;

  $status = StripCobol::StripCobol ($fichier, $vue, $options, $couples) ;

  if (($fichier ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'}) # dumpvues_filter_line
  {                                                                            # dumpvues_filter_line
    Vues::dump_vues( $fichier, $vue, $options);                                # dumpvues_filter_line
  }                                                                            # dumpvues_filter_line

  return $status;
}

my @TableCounters =
(
);

sub CountLinePerLine ($$$$$$$$)
{
    my($r_ProcDiv, $r_IdentDiv,$r_EnvDiv, $r_InOutSect, $r_FileSect, $r_WorkSect, $StructFichier,$filename)=(@_);

    my $CptLine_WorkSect;
    if (defined $StructFichier->{"Dat_WorkingSectLine"}) {
      $CptLine_WorkSect = $StructFichier->{"Dat_WorkingSectLine"} - 1 ;
    }

    my $CptLine_ProcDiv = $StructFichier->{"Dat_ProcDivLine"} - 1 ;

    my $ParagraphLine = $StructFichier->{"ParaLine"};
    my $NewPara="";

    initMove($StructFichier,$filename);
    initMultInst($StructFichier,$filename);
    initEvaluate($StructFichier,$filename);
    initGoto($StructFichier,$filename);
    Cobol::CheckSQL::initCheckSQL($StructFichier,$filename);
    initAlignVerb($StructFichier,$filename);
    initThruParaExit($StructFichier,$filename);
    initCompute($StructFichier,$filename);
    initConstantLit($StructFichier,$filename);
    initVar($StructFichier,$filename);
    initObsolete($StructFichier, $filename);
    initMotInterdit($StructFichier, $filename);
    initFileSection($StructFichier, $filename);
    initFichier($StructFichier, $filename);
    initWorking($StructFichier, $filename);
    initContigusLevel($StructFichier, $filename);
    initPictureIndent($StructFichier, $filename);
    initValueIndent($StructFichier, $filename);

    ###################################################################
    #             IDENTIFICATION DIVISION buffer
    ###################################################################
    if (defined $StructFichier->{"Dat_IdentDivLine"}) {
      my $CptLine_IdentDiv = $StructFichier->{"Dat_IdentDivLine"} - 1 ;

      my @LINES = split /\n/, $$r_IdentDiv;
      for my $line (@LINES) {
	$line .= "\n";
          # comptage des lignes
#	print "$filename:$CptLine_ProcDiv:DEBUG:LIGNE  " . $line . "\n" ;

	  $CptLine_IdentDiv++;

          if ($line =~ m{\A\s*\Z}) {
           #ligne blanche
	    next;
	  }
          #  lignes de commentaire ou debug
          if ($line =~ m{\A\S}) {
	    next;
	  }
	  MotObsoleteID($line, $CptLine_IdentDiv);
        }
    }
    ###################################################################
    #             ENVIRONMENT DIVISION buffer
    ###################################################################
    if (defined $StructFichier->{"Dat_EnvDivLine"}) {
      my $CptLine_EnvDiv = $StructFichier->{"Dat_EnvDivLine"} - 1 ;

      my @LINES = split /\n/, $$r_EnvDiv;
      for my $line (@LINES) {
	$line .= "\n";
          # comptage des lignes
#	print "$filename:$CptLine_ProcDiv:DEBUG:LIGNE  " . $line . "\n" ;

	  $CptLine_EnvDiv++;

          if ($line =~ m{\A\s*\Z}) {
           #ligne blanche
	    next;
	  }
          #  lignes de commentaire ou debug
          if ($line =~ m{\A\S}) {
	    next;
	  }
	  MotObsoleteED($line, $CptLine_EnvDiv);
        }
    }
    ###################################################################
    #             INOUT SECTION buffer
    ###################################################################
    if (defined $StructFichier->{"Dat_InOutSectLine"}) {
      my $CptLine_InOutSect = $StructFichier->{"Dat_InOutSectLine"} - 1 ;

      if ($CptLine_InOutSect < 0) {
        declareMissingFileSection();
      }
      else {
      my @LINES = split /\n/, $$r_InOutSect;
      for my $line (@LINES) {
	$line .= "\n";

          # comptage des lignes
#	print "$filename:$CptLine_ProcDiv:DEBUG:LIGNE  " . $line . "\n" ;

	  $CptLine_InOutSect++;

          if ($line =~ m{\A\s*\Z}) {
           #ligne blanche
	    next;
	  }
          #  lignes de commentaire ou debug
          if ($line =~ m{\A\S}) {
	    next;
	  }

	  FichierIOS($line, $CptLine_InOutSect);
	  MotObsoleteIOS($line, $CptLine_InOutSect);
        }
      }
    }

    ###################################################################
    #             FILE SECTION buffer
    ###################################################################
    if (defined $StructFichier->{"Dat_FileSectLine"}) {

      my $CptLine_FileSect = $StructFichier->{"Dat_FileSectLine"} - 1 ;

      if ($CptLine_FileSect < 0) {
        declareMissingFileSection();
      }
      else {
      my @LINES = split /\n/, $$r_FileSect;
      for my $line (@LINES) {
	$line .= "\n";
        # comptage des lignes
#	print "$filename:$CptLine_ProcDiv:DEBUG:LIGNE  " . $line . "\n" ;

	  $CptLine_FileSect++;

          if ($line =~ m{\A\s*\Z}) {
          #ligne blanche
	    next;
	  }
          #  lignes de commentaire ou debug
          if ($line =~ m{\A\S}) {
	    next;
	  }

	  FileSection($line, $CptLine_FileSect);
	  MotObsoleteFS($line, $CptLine_FileSect);
	  MotInterditFS($line, $CptLine_FileSect);

	  # WARNING : FichierIOS must have been called before !!!
	  FichierFS($line, $CptLine_FileSect);
        }
      }
    }


    ###################################################################
    #             WORKING SECTION buffer
    ###################################################################
    if (defined $StructFichier->{"Dat_WorkingSectLine"}) {

    my @LINES = split /\n/, $$r_WorkSect;
    for my $line (@LINES) {
	$line .= "\n";

        # comptage des lignes
#	print "$filename:$CptLine_ProcDiv:DEBUG:LIGNE  " . $line . "\n" ;

	$CptLine_WorkSect++;

        if ($line =~ m{\A\s*\Z}) {
         #ligne blanche
	    next;
	}
        #  lignes de commentaire ou debug
        if ($line =~ m{\A\S}) {
	    next;
	}

        VarWS($line, $CptLine_WorkSect);
        MotObsoleteWS($line, $CptLine_WorkSect);
        MotInterditWS($line, $CptLine_WorkSect);
        Working($line, $CptLine_WorkSect);
        ContigusLevel($line, $CptLine_WorkSect);
        PictureIndent($line, $CptLine_WorkSect);
        ValueIndent($line, $CptLine_WorkSect);
      }
    }

    ###################################################################
    #             PROCEDURE DIVISION buffer
    ###################################################################
    my @LINES = split /\n/, $$r_ProcDiv;
    for my $line (@LINES) {
	$line .= "\n";
        # comptage des lignes
#	print "$filename:$CptLine_ProcDiv:DEBUG:LIGNE  " . $line . "\n" ;

	$CptLine_ProcDiv++;

	if (exists $ParagraphLine->{$CptLine_ProcDiv}) {
          $NewPara=$ParagraphLine->{$CptLine_ProcDiv};
        }
	else {
	  $NewPara=undef;
	}

        if ($line =~ m{\A\s*\Z}) {
         #ligne blanche
	    next;
	}
        #  lignes de commentaire ou debug
        if ($line =~ m{\A\S}) {
	    next;
	}

        Move($line, $CptLine_ProcDiv, $NewPara);
        MultInst($line, $CptLine_ProcDiv, $NewPara);
        Evaluate($line, $CptLine_ProcDiv, $NewPara);
        Goto($line, $CptLine_ProcDiv, $NewPara);
        Cobol::CheckSQL::CheckSQL($line, $CptLine_ProcDiv, $NewPara);
        AlignVerb($line, $CptLine_ProcDiv, $NewPara);
        ThruParaExit($line, $CptLine_ProcDiv, $NewPara);
        Compute($line, $CptLine_ProcDiv, $NewPara);
        ConstantLit($line, $CptLine_ProcDiv, $NewPara);
        VarPD($line, $CptLine_ProcDiv, $NewPara);
	MotObsoletePD($line, $CptLine_ProcDiv, $NewPara);
	MotInterditPD($line, $CptLine_ProcDiv, $NewPara);
	FichierPD($line, $CptLine_ProcDiv, $NewPara);
    }

    endMove();
    endMultInst();
    endEvaluate();
    endGoto();
    Cobol::CheckSQL::endCheckSQL();
    endAlignVerb();
    endThruParaExit();
    endCompute();
    endVar();
    endConstantLit();
    endMotInterdit();
    endFileSection();
    endFichier();
    endMotObsolete();
    endWorking();
    endContigusLevel();
    endPictureIndent();
    endValueIndent();
}

sub CountCobol
{
  my (  $fichier, $vue, $options, $couples) = @_;

  my $timing=(Timing->isSelectedTiming ('Count') ||  # timing_filter_line
	      Timing->isSelectedTiming ('All'));     # timing_filter_line

  local $/ = undef;
  my $filename = $fichier;

  my $StructFichier = $couples ;

  my $countersTiming = new Timing ("Temps des fonctions de comptage", $timing);
  my $index = 1;

  my $buffer = $vue->{'text'};
  Cobol::Vue::initViews();
  $countersTiming->markTimeAndPrint($index++.":Vue::initViews") if ( defined $timing); # timing_filter_line

  # REMOVE fix format marging if any :
  # - first 6 columns
  # - 73 and more columuns
  Cobol::Vue::PrepareBuffer(\$buffer);
  $countersTiming->markTimeAndPrint($index++.":Vue::PrepareBuffer") if ( defined $timing); # timing_filter_line
  
  # In case of copy book, we should separate the declarative part from the
  # procedure part, because the functions dedicated to extracting from
  # different zone will non work, because the structural instructions are
  # not present in copy books.$previousValueOffset = -1;

    if (Cobol::Vue::isCopybook(\$buffer)) {
      Cobol::Vue::createBufferCopybook(\$buffer);
      $countersTiming->markTimeAndPrint($index++.":Vue::createBufferCopybook") if ( defined $timing); # timing_filter_line
    }

    my $status = 0;

    # Create bufferText0, where instructions indented in Zone A are 
    # pushed in ZONE B
    my $bufferText0=$buffer;
    Cobol::Vue::BadZone(\$bufferText0, $StructFichier);
    $countersTiming->markTimeAndPrint($index++.":Vue::BadZone") if ( defined $timing); # timing_filter_line

    # Create bufferText1, where chaines are replaced with identifiers
    my $bufferText1=$bufferText0;
    Cobol::Vue::StripChaine(\$bufferText1, $StructFichier);
    $countersTiming->markTimeAndPrint($index++.":Vue::StripChaine") if ( defined $timing); # timing_filter_line

#-------------------------------------------------------------------------------
#Chaine et comment
# DESACTIVATED because :
# - $bufferText2 is not used
if (0) {
    my $bufferText2=$bufferText1;
    Cobol::Vue::StripComment(\$bufferText2, $StructFichier);
    $countersTiming->markTimeAndPrint($index++.":Vue::StripComment") if ( defined $timing); # timing_filter_line
}
#-------------------------------------------------------------------------------

    #comment seul
    my $bufferText3=$bufferText0;
    Cobol::Vue::StripComment(\$bufferText3, $StructFichier);
    $countersTiming->markTimeAndPrint($index++.":Vue::StripComment") if ( defined $timing); # timing_filter_line

    # bufferIdentDiv will contain the view Identification division
    my $bufferIdentDiv = $bufferText3;
    Cobol::Vue::IdentDiv(\$bufferIdentDiv, $StructFichier);
    $countersTiming->markTimeAndPrint($index++.":Vue::IdentDiv") if ( defined $timing); # timing_filter_line

    # bufferEnvDiv will contain the view Environement division
    my $bufferEnvDiv = $bufferText3;
    Cobol::Vue::EnvDiv(\$bufferEnvDiv, $StructFichier);
    $countersTiming->markTimeAndPrint($index++.":Vue::EnvDiv") if ( defined $timing); # timing_filter_line

    # bufferDataDiv will contain the view Data division
    my $bufferDataDiv = $bufferText3;
    Cobol::Vue::DataDiv(\$bufferDataDiv, $StructFichier);
    $countersTiming->markTimeAndPrint($index++.":Vue::DataDiv") if ( defined $timing); # timing_filter_line

    # bufferProcDiv will contain the view Prodecure division
    my $bufferProcDiv = $bufferText3;
    Cobol::Vue::ProcDiv(\$bufferProcDiv, $StructFichier);
    $countersTiming->markTimeAndPrint($index++.":Vue::ProcDiv") if ( defined $timing); # timing_filter_line

    my $proto;
    my $comptageName;
    my $display;

    my $r_bufferProcDiv = Cobol::CobolCommon::ParseParagraphs(\$bufferProcDiv, $StructFichier);
    $countersTiming->markTimeAndPrint($index++.":CobolCommon:ParseParagraphs") if ( defined $timing); # timing_filter_line

    # bufferInOutSect will contain the view InOut Section
    my $bufferInOutSect = $bufferText3;
    Cobol::Vue::InOutSect(\$bufferInOutSect, $StructFichier);
    $countersTiming->markTimeAndPrint($index++.":Vue::InOutSect") if ( defined $timing); # timing_filter_line

    # bufferWorkingSect will contain the view Working Section
    my $bufferWorkingSect = $bufferText3;
    Cobol::Vue::WorkingSect(\$bufferWorkingSect, $StructFichier);
    $countersTiming->markTimeAndPrint($index++.":Vue::WorkingSect") if ( defined $timing); # timing_filter_line

    # bufferFileSect will contain the view File Section
    my $bufferFileSect = $bufferText3;
    Cobol::Vue::FileSect(\$bufferFileSect, $StructFichier);
    $countersTiming->markTimeAndPrint($index++.":Vue::FileSect") if ( defined $timing); # timing_filter_line

    # Metrologie
    # FIXME: Fait mais traitement du perform a revoir
    Cobol::metriques::GetMetriques($bufferText1,$filename,$StructFichier);
    $countersTiming->markTimeAndPrint($index++.":metriques::GetMetriques") if ( defined $timing); # timing_filter_line
##     PrintViogen($StructFichier);

    Ident($bufferIdentDiv, $StructFichier, $filename,"","DATA");
    $countersTiming->markTimeAndPrint($index++.":Ident") if ( defined $timing); # timing_filter_line

    CountLinePerLine($r_bufferProcDiv, \$bufferIdentDiv, \$bufferEnvDiv, \$bufferInOutSect, \$bufferFileSect, \$bufferWorkingSect, $StructFichier, $filename);
    $countersTiming->markTimeAndPrint($index++.":CountLinePerLine") if ( defined $timing); # timing_filter_line

    CodeComment($bufferText0, $StructFichier, $filename);
    $countersTiming->markTimeAndPrint($index++.":CodeComment") if ( defined $timing); # timing_filter_line

    CmplxCond($bufferProcDiv,$StructFichier,$filename);
    $countersTiming->markTimeAndPrint($index++.":CmplxCond") if ( defined $timing); # timing_filter_line

    ####### A voir pour plus tard
  #     EssaiCodeMort($filename);
  #     CopyInclude($bufferProcDiv,$StructFichier,$filename);

    $countersTiming->dump('PerfParComptage') if ( defined $timing); # timing_filter_line
    #print STDERR  "\nL'analyse du fichier s'est termine avec le code " . $status . "   " . "0x". hex ($status) . "\n" ;
  return $status;
}

sub Count($$$$)
{
    my ($fichier, $vue, $options, $couples) = @_;
    my $status = 0;
    foreach my $counter ( @TableCounters )
    {
        eval
        {
            $status |= $counter->($fichier, $vue, $couples);
        };
        if ($@)
        {
            Timeout::DontCatchTimeout(); # propagate timeout errors
            #TBD: message d'erreur
            print STDERR "\n\n erreur dans un module de comptage : $@\n";
            $status |= Erreurs::COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE; # si un ou plusieurs comptages n'ont pas pu etre effectues
        }

    }
    $status |= CountCobol($fichier, $vue, $options, $couples);
    if (defined $options->{'--CloudReady'}) {
        CloudReady::detection::setCurrentFile($fichier);
        $status |= CloudReady::CountCobol::CountCobol($fichier, $vue, $options);
    }

    if (defined $options->{'--KeywordScan'}) {
        eval {
            # TODO: for adding scope support to searchItem (csv version)
            # modify this subroutine to allow parsing searchItem csv version
            KeywordScan::Count::Count($fichier, $vue, $couples);
        };

        if ($@) {
            Timeout::DontCatchTimeout(); # propagate timeout errors
            #die ($@) if $@ eq "alarm\n";   # propagate timeout errors
            print STDERR "\n\n ERROR when launching user scans : $@\n";
            $status |= Erreurs::COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE;
        }
    }
    return $status;
}

my @TableMnemos = (
    'Dat_AnalysisDate',
    'Dat_AnalysisStatus',
    'Dat_DataDivLine',
    'Dat_EnvDivLine',
    'Dat_FileName',
    'Dat_FileSectLine',
    'Dat_IdentDivLine',
    'Dat_InOutSectLine',
    'Dat_Language',
#    'Dat_LanguageDetected',
#    'Dat_LanguageType',
    'Dat_ProcDivLine',
    'Dat_WorkingSectLine',
    Ident::Alias_BackGoto(),
    Ident::Alias_BackPerform(),
    Ident::Alias_BadEndClauseAlign(),
    Ident::Alias_BadInit(),
    Ident::Alias_BadInitMove(),
    Ident::Alias_BadToAlign(),
    Ident::Alias_BadZoneDecl(),
    Ident::Alias_BadZoneInst(),
    Ident::Alias_Case(),
    Ident::Alias_CodeCommentLine(),
    Ident::Alias_CommentLine(),
    Ident::Alias_ComplexCond(),
    Ident::Alias_Compute(),
    Ident::Alias_ConstLit(),
    Ident::Alias_ContigusLevel(),
    Ident::Alias_CuriousFilePb(),
    Ident::Alias_DeclWithoutIdent(),
    Ident::Alias_DuplicatedParaName(),
    Ident::Alias_DynamicCall(),
    Ident::Alias_EmptyRenames(),
    Ident::Alias_Evaluate(),
    Ident::Alias_Fc_CptCopy(),
    Ident::Alias_Fc_NbFile(),
    Ident::Alias_Fs_CptCopy(),
    Ident::Alias_Fs_NbFile(),
    Ident::Alias_IF(),
    Ident::Alias_Lines(),
    Ident::Alias_Ls_NbLink01(),
    Ident::Alias_MissingDefaults(),
    Ident::Alias_MissingEndEVA(),
    Ident::Alias_MissingEndIf(),
    Ident::Alias_MissingEndPERFORM(),
    Ident::Alias_MissingInvalidKey(),
    Ident::Alias_MultAffect(),
    Ident::Alias_MultInstOnLine(),
    Ident::Alias_NBOPTot(),
    Ident::Alias_NBOPdiff(),
    Ident::Alias_NoCopyClause(),
    Ident::Alias_NoExitInParaRefByThru(),
    Ident::Alias_ObsoleteKeywordED(),
    Ident::Alias_ObsoleteKeywordFS(),
    Ident::Alias_ObsoleteKeywordID(),
    Ident::Alias_ObsoleteKeywordIOS(),
    Ident::Alias_ObsoleteKeywordPD(),
    Ident::Alias_ObsoleteKeywordWS(),
    Ident::Alias_PD_ProhibitedKeyword(),
    Ident::Alias_PICNotAlign(),
    Ident::Alias_Para(),
    Ident::Alias_ParaNameWithoutDot(),
    Ident::Alias_ParaVide(),
    Ident::Alias_Pd_BoucleFor(),
    Ident::Alias_Pd_CptComment(),
    Ident::Alias_Pd_CptCopy(),
    Ident::Alias_Pd_CptInst(),
    Ident::Alias_Pd_CptNivMax(),
    Ident::Alias_Pd_NBOPTot(),
    Ident::Alias_Pd_NBOPdiff(),
    Ident::Alias_Pd_NB_LigneSQL(),
    Ident::Alias_Pd_NbGOTO(),
    Ident::Alias_Pd_NbLgBl(),
    Ident::Alias_Pd_NbPerform(),
    Ident::Alias_PicTooLong(),
    Ident::Alias_SQLComplexWhereClause(),
    Ident::Alias_SQLDeclareTable(),
    Ident::Alias_SQLDistinctOrder(),
    Ident::Alias_SQLGroupby(),
    Ident::Alias_SQLMissingTest(),
    Ident::Alias_SQLOrderBy(),
    Ident::Alias_SQLSelectStar(),
    Ident::Alias_SeriousFilePb(),
    Ident::Alias_SimpleCompute(),
    Ident::Alias_SuspiciousComments(),
    Ident::Alias_Tab(),
    Ident::Alias_VG(),
    #Ident::Alias_VGmoyen(),
    Ident::Alias_ValueNotAlign(),
    Ident::Alias_VarNotUsed(),
    Ident::Alias_Ws_CptCopy(),
    Ident::Alias_Ws_NbData01(),
    Ident::Alias_Ws_NbData77(),
);

my $firstFile = 1;

sub FileTypeRegister ($)
{
  my ($options) = @_;

    if ($firstFile != 0)
    {
        $firstFile = 0;

	AnaUtils::load_ready();

        if (defined $options->{'--o'})
        {
            #print STDERR "AnaCobol : appel de csv_file_type_register\n";
            IsoscopeDataFile::csv_file_type_register("Cobol", \@TableMnemos);
        }
        #------------------ init CloudReady detections -----------------------
		if (defined $options->{'--CloudReady'}) {
			CloudReady::detection::init($options, 'Cobol');
		}
    }
}

sub Analyse($$$$)
{
    my ( $fichier, $vues, $options, $couples) = @_;
    my $status =0;

    FileTypeRegister($options);

    my $erreur_checkCobol = CheckCobol::CheckCodeAvailability( \$vues->{'text'} );
    if ( defined $erreur_checkCobol )
    {
      return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_NOT_ENOUGH_CODE, $couples, $erreur_checkCobol);
    }

    $status = Strip( $fichier, $vues, $options, $couples);

    if (defined $options->{'--nocount'})
    {
      return $status;
    }

    if ($status == 0)
    {
        $status |= Count($fichier, $vues, $options, $couples);
    }
    else
    {
        print STDERR "$fichier : Echec de pre-traitement\n";
    }
    return $status ;
}

1;

