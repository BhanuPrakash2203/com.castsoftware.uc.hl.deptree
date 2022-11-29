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
# Description: Composant de comptages sur code source COBOL

package Cobol::metriques;

use Cobol::violation;

use Cobol::CobolCommon;

my $IDENTIFIER = Cobol::CobolCommon::get_IDENTIFER_PATTERN();

#FLAGS
#asup my $DansSD = 0;
my %VarTab ;
my $FICHIER = "";
my $Zone = "No";
my $dansSQL = 0;
my $DansPerform = 0;
my $BesoinThru = 0;
my $LoopFound = 0;
#asup my $ClauseWhere = 0;
# asup my $NbAndOrSQL = 0;
#asup my $BlockContains = 2;
#asup my $previousToOffset = -1;
#asup my $CurrentLevelMove = 0;
#asup my $PrevLevelMove = 0;
####FLOFLO a commente
#my @previousLevelOffset;
#my $PreviousInstLevel  = -1;
#my $PreviousInstOffset = -1;
####FLOFLO a commente
# comptage globaux
my $CptComment = 0;
my $CptLine = 0;
my $CptCopy = 0;
#asup my $TestSQL = 0;
#asup my $TestSQLLine = 0;
#asup my $multaffectpOSSIBLE = 0;
#asup my $multcomputepossible = 0;
#asup my $countOpCompute = 0;
#Comptage en File control
# Nombre de fichier 
    my $Fc_NbFile = 0;
    my $Fc_CptCopy = 0;

#Comptage en File section
# Nombre de fichier 
    my $Fs_NbFile = 0;

    my $Fs_CptCopy = 0;
# Flag en File section
#asup    my $Fs_PrevFDLine = 0;
#asup    my $Fs_DescrStatus = 0;

#Comptage en Working storage
#Nombre de variable de niveau 1
    my $Ws_NbData01= 0;
#Nombre de variable de niveau 77
    my $Ws_NbData77= 0;
#Nombre de copy
    my $Ws_CptCopy = 0;

#Comptage en Linkage
#Nombre de variable de niveau 1 en Linkage
    my $Ls_NbLink01= 0;

#Comptage en Procedure division
#Nombre de paragraphe
    my $Pd_NbPara = 0;
#Nombre de ligne d instruction
    my $Pd_CptInst = 0;
#Nombre de ligne de commentaire
    my $Pd_CptComment = 0;
    my $Pd_PrevCptComment = 0;
#Nombre de perform
    my $Pd_NbPerform = 0;
    my $Pd_BoucleFor = 0;
#Nombre de if
#nombre de evaluate 
    my $Pd_NbIF = 0;
    my $Pd_NbEvaluate = 0;
    my $Pd_NbCase = 0;

    my $Pd_CptMissIF = 0;
    my $Pd_CptMissEVA = 0;
    my $Pd_CptMissPERFORM = 0;
    my $Pd_Nbr_ParaNameWithoutDot = 0;
    my $Pd_Nbr_DuplicatedParaName = 0;
#Nombre de lignes blanches
    my $Pd_NbLgBl = 0;
#Nombre de goto
    my $Pd_NbGOTO = 0;
#Estimateur de VG
    my $Pd_NbVG = 0;
#Nombre de niveau
my $Pd_CptNivMax = 0;
#Nombre de ligne SQL
    my $Pd_NB_LigneSQL = 0;

#Nombre de copy
    my $Pd_CptCopy = 0;
    my $Pd_PrevCptCopy = 0;

################################  
############# Niveau Paragraphe  
################################  
#Estimateur de VG dans un paragraphe
    my $Para_NbVG = 0;
    my $Para_NbWhen = 0;
#Nombre de ligne d'instruction dans un paragraphe
    my $Para_CptInst = 0;

    my $Para_CptNiv = 0;
    my $Para_NbPerform = 0;
    my $Para_CptNivMax = 0;
    my $Para_NbGOTO = 0;
    my $Para_OPAll = 0;
    my $Para_OPDiff = 0;
    my $Para_Exit = 0;
    my $Para_CptIF = 0;
    my $Para_CptEVA = 0;
    my $Para_CptPERFORM = 0;



#######################
# SEUILS
#######################
# comptage globaux
my $S_CptComment = 0;
my $S_CptLine = 0;
my $S_CptCopy = 0;
#Comptage en File control
# Nombre de fichier 
    my $S_Fc_NbFile = 10;

#Comptage en File section
# Nombre de fichier 
    my $S_Fs_NbFile = 10;
#Comptage en Working
#Nombre de variable de niveau 1
    my $S_Ws_NbData01= 0;
#Nombre de variable de niveau 77
    my $S_Ws_NbData77= 0;
#Comptage en Linkage
#Nombre de variable de niveau 1 en Linkage
    my $S_Ls_NbLink01= 0;
#Comptage en Procedure division
#Nombre de paragraphe
    my $S_Pd_NbPara = 0;
#Nombre de ligne d instruction
    my $S_Pd_CptInst = 1000;
#Nombre de ligne de commentaire
    my $S_Pd_CptComment = 0;
# Taux de commentaire
    my $S_Pd_Tx_com = 0.2;
#Nombre de perform
    my $S_Pd_NbPerform = 0;
    my $S_Pd_BoucleFor = 0;
#Nombre de lignes blanches
#    my $S_Pd_NbLgBl = 0;
#Nombre de goto
    my $S_Pd_NbGOTO = 0;
#Estimateur de VG
    my $S_Pd_NbVG = 250;

#Dans SQL
# Seuil compléxité clause where de select
#asup my $S_Where_Cplx = 4;

# Indentation minimum 1 caractère
#asupavoir my $S_ident = 2;
########## Niveau paragraphe##########
#Estimateur de VG dans un paragraphe
    my $S_Para_NbVG = 15;
#Nombre de ligne d'instruction dans un paragraphe
    my $S_Para_CptInst = 70;
#Estimateur de NBNIV dans un paragraphe
    my $S_Para_CptNivMax = 4;

######### variable de travail globales
#asup   my $NivEva =0;
#asup   my @EvaluaCur;
   my %TabPara;
   my $PrevPara = "";
   my $CurrentPara = "";
#asup   my $programId = "";
#asup   my $PrevOpen = "";
#asup   my $PrevClose = "";
   my %TabOPop;
   my $NBOPTot = 0;
   my $NBOPdiff = 0;
   my %Pd_TabOPop;
   my $Pd_NBOPTot = 0;
   my $Pd_PrevNBOPTot = 0;
   my $Pd_NBOPdiff = 0;
   my $cptParaVide = 0;

sub initcompteur {
    $Zone = "No";
    $dansSQL = 0;
    $DansPerform = 0;
    $BesoinThru = 0;
#asup    $TestSQL = 0;
#asup    $TestSQLLine = 0;
#asup    $DansSD = 0;
#asup    $programId = "";
#asup    $PrevOpen = "";
#asup    $PrevClose = "";

    $PrevPara = "";
    $CurrentPara = "";
#asup   $multaffectpOSSIBLE = 0;
#asup    $multcomputepossible = 0;
#asup    $countOpCompute = 0;
#Comptage généraux
    $CptComment = 0;
    $CptLine = 0;
    $CptCopy = 0;
    $NBOPTot = 0;
    $NBOPdiff = 0;
    $Pd_NBOPTot = 0;
    $Pd_PrevNBOPTot = 0;
    $Pd_NBOPdiff = 0;
#Comptage en File control
    $Fc_NbFile = 0;
    $Fc_CptCopy = 0;

#Comptage en File section
    $Fs_NbFile = 0;
    $Fs_CptCopy = 0;
#asup    $Fs_PrevFDLine = 0;
#asup    $Fs_DescrStatus = 0;
#Comptage en Working
    $Ws_NbData01= 0;
    $Ws_NbData77= 0;
    $Ws_CptCopy = 0;

#Comptage en Linkage
    $Ls_NbLink01= 0;


#Comptage en Procedure division
    $Pd_NbPara = 0;
    $Pd_CptInst = 0;
    $Pd_CptComment = 0;
    $Pd_PrevCptComment = 0;
    $Pd_NbPerform = 0;
    $Pd_BoucleFor = 0;
    $Pd_NbIF = 0;
    $Pd_NbEvaluate = 0;
    $Pd_NbCase = 0;
    $Pd_NbLgBl = 0;
    $Pd_NbGOTO = 0;
    $Pd_NbVG = 0;
    $Pd_NB_LigneSQL = 0;
    $Pd_CptCopy = 0;
    $Pd_PrevCptCopy = 0;
    $Pd_CptNivMax = 0;
#Compteurs de END manquant
    $Pd_CptMissIF = 0;
    $Pd_CptMissEVA = 0;
    $Pd_CptMissPERFORM = 0;
    $Pd_Nbr_ParaNameWithoutDot = 0;
    $Pd_Nbr_DuplicatedParaName = 0;

# Comptage dans un paragraphe
    $Para_NbVG = 0;
    $Para_NbWhen = 0;
    $Para_CptInst = 0;
    $Para_CptNiv = 1;
    $Para_NbPerform = 0;
    $Para_CptNivMax = 1;
    $Para_NbGOTO = 0;
    $Para_OPAll = 0;
    $Para_OPDiff = 0;
    $Para_Exit = 0;
    $Para_CptIF = 0;
    $Para_CptEVA = 0;
    $Para_CptPERFORM = 0;

#asup    @EvaluaCur = ();
    %TabPara = ();
    %TabOPop = ();
    %Pd_TabOPop = ();
    %VarTab = ();
#    @previousLevelOffset = ();
####FLOFLO a commente
#    $PreviousInstOffset = -1;
#    $PreviousInstLevel  = -1;

    $cptParaVide = 0;
}

sub PrintResMetriques ($)
{
    my ($StructFichier) = @_;

# traitement du dernier paragraphe
    traitepara($PrevPara);

#Le taux de commantaire pris en compte est celui de la procédure division
# Nombre lignes commentaire / Nombre lignes d'instruction
    my $Pd_Tx_com;
    if ( $Pd_CptInst == 0) {
	$Pd_Tx_com = $Pd_CptComment / 1;
    } else {
	$Pd_Tx_com = $Pd_CptComment / $Pd_CptInst;
    }
# Ce taux de commentaire est le général sur le fichier
# Nombre lignes commentaire / Nombre lignes total

    my $Tx_com = $CptComment / $CptLine;
#le VG total est égal à celui calculé plus 1 par paragraphe
    my $Pd_NbVGtot = $Pd_NbVG + $Pd_NbPara;

    my $VGMoyen;
    if ($Pd_NbPara == 0) {
      $Pd_NbPara = 1;
      $Pd_CptInst = 1  if ( $Pd_CptInst == 0);
      $Pd_NBOPdiff = 2 if ( $Pd_NBOPdiff == 0);
      $Pd_NBOPTot = 2 if ( $Pd_NBOPTot == 0);
      $VGMoyen = $Pd_NbVGtot / $Pd_NbPara;
#      print STDERR "PARSE warning : no pragraph found ! $Pd_CptInst:$Pd_NBOPdiff:$Pd_NBOPTot \n";
      print STDERR "PARSE warning : no pragraph found !\n";
    } else {
	$VGMoyen = $Pd_NbVGtot / $Pd_NbPara;
    }
    my $VGMoyen2 = $VGMoyen;
#Pour Excel, on remplace les caractère . par ,
    my $tcomAffichage = "$Pd_Tx_com";
    $tcomAffichage =~ s{\.}{,};
    $VGMoyen =~ s{\.}{,};

#MI = 171 - 5.2 * ln(aveV) - 0.23 * aveV(g') - 16.2 * ln(aveLOC) + 50 * sin (sqrt(2.4 * perCM))
# V = N * log2(n)
#log2(x)= ln(x)/ln(2)
#V = ($Pd_NBOPTot * (ln($Pd_NBOPdiff)/ln(2)))
#-    aveV       = moyenne du Volume (V d'Halstead ) par module
#-    aveV(g') = moyenne du V(G) par module
#-    aveLOC = moyenne du (LOC) par module
#-    perCM   = % moyen du taux de commentaires par module 
#		my $MI = 171 - (5.2 * log(($Pd_NBOPTot * (log($Pd_NBOPdiff)/log(2)))/$Pd_NbPara)) - (0.23 * $VGMoyen2) - 16.2 * log(($Pd_CptInst/$Pd_NbPara));

#print "METRIQUES:$FICHIER:$CptLine:$CptComment:$CptCopy:$Tx_com:$Fc_NbFile:$Fs_NbFile:$Ws_NbData01:$Ws_NbData77:$Ls_NbLink01:$Pd_NbPara:$Pd_CptInst:$Pd_CptComment:$Pd_NbPerform:$Pd_NbGOTO:$Pd_NbVG:$Pd_Tx_com\n";
		#Cobol::violation::violation("metrique",$FICHIER,$CptLine,"Ws_NbData01:Ws_NbData77:Pd_CptInst:tcomAffichage:Pd_NbVGtot:VGMoyen:Para_CptNivMax:NBOPTot:NBOPdiff:Pd_NBOPTot:Pd_NBOPdiff:MI");
		#Cobol::violation::violation("metrique",$FICHIER,$CptLine,"$Ws_NbData01:$Ws_NbData77:$Pd_CptInst:$tcomAffichage:$Pd_NbVGtot:$VGMoyen:$Para_CptNivMax:$NBOPTot:$NBOPdiff:$Pd_NBOPTot:$Pd_NBOPdiff:MI");
#print "$FICHIER:$CptLine:$Ws_NbData01:$Ws_NbData77:$Pd_CptInst:$tcomAffichage:$Pd_NbVGtot:$VGMoyen\n";

Couples::counter_add($StructFichier,Ident::Alias_Lines(),$CptLine);
Couples::counter_add($StructFichier,Ident::Alias_CommentLine(),$CptComment);
Couples::counter_add($StructFichier,Ident::Alias_VG(),$Pd_NbVGtot);

Couples::counter_add($StructFichier,Ident::Alias_Fc_NbFile(),$Fc_NbFile);
Couples::counter_add($StructFichier,Ident::Alias_Fc_CptCopy(),$Fc_CptCopy);
Couples::counter_add($StructFichier,Ident::Alias_Fs_NbFile(),$Fs_NbFile );
Couples::counter_add($StructFichier,Ident::Alias_Fs_CptCopy(),$Fs_CptCopy);
Couples::counter_add($StructFichier,Ident::Alias_Ws_NbData01(),$Ws_NbData01);
Couples::counter_add($StructFichier,Ident::Alias_Ws_NbData77(),$Ws_NbData77);
Couples::counter_add($StructFichier,Ident::Alias_Ws_CptCopy(),$Ws_CptCopy);
Couples::counter_add($StructFichier,Ident::Alias_Ls_NbLink01(),$Ls_NbLink01);
Couples::counter_add($StructFichier,Ident::Alias_Para(),$Pd_NbPara);
Couples::counter_add($StructFichier,Ident::Alias_Pd_CptInst(),$Pd_CptInst);
Couples::counter_add($StructFichier,Ident::Alias_Pd_CptComment(),$Pd_CptComment);
Couples::counter_add($StructFichier,Ident::Alias_Pd_NbPerform(),$Pd_NbPerform);
Couples::counter_add($StructFichier,Ident::Alias_Pd_BoucleFor(),$Pd_BoucleFor);
Couples::counter_add($StructFichier,Ident::Alias_Pd_NbLgBl(),$Pd_NbLgBl);
Couples::counter_add($StructFichier,Ident::Alias_Pd_NbGOTO(),$Pd_NbGOTO);
Couples::counter_add($StructFichier,Ident::Alias_Pd_CptNivMax(),$Pd_CptNivMax);
Couples::counter_add($StructFichier,Ident::Alias_Pd_NB_LigneSQL(),$Pd_NB_LigneSQL);
Couples::counter_add($StructFichier,Ident::Alias_Pd_CptCopy(),$Pd_CptCopy);
Couples::counter_add($StructFichier,Ident::Alias_NBOPTot(),$NBOPTot);
Couples::counter_add($StructFichier,Ident::Alias_NBOPdiff(),$NBOPdiff);
Couples::counter_add($StructFichier,Ident::Alias_Pd_NBOPTot(),$Pd_NBOPTot);
Couples::counter_add($StructFichier,Ident::Alias_Pd_NBOPdiff(),$Pd_NBOPdiff);
Couples::counter_add($StructFichier,Ident::Alias_IF(),$Pd_NbIF);
Couples::counter_add($StructFichier,Ident::Alias_Evaluate(),$Pd_NbEvaluate);
Couples::counter_add($StructFichier,Ident::Alias_Case(),$Pd_NbCase);




Couples::counter_add($StructFichier,Ident::Alias_VGmoyen(),$VGMoyen);
Couples::counter_add($StructFichier,Ident::Alias_MissingEndIf(),$Pd_CptMissIF);
Couples::counter_add($StructFichier,Ident::Alias_MissingEndEVA(),$Pd_CptMissEVA);
Couples::counter_add($StructFichier,Ident::Alias_MissingEndPERFORM(),$Pd_CptMissPERFORM);
Couples::counter_add($StructFichier,Ident::Alias_ParaNameWithoutDot(),$Pd_Nbr_ParaNameWithoutDot);
Couples::counter_add($StructFichier,Ident::Alias_DuplicatedParaName(),$Pd_Nbr_DuplicatedParaName);
Couples::counter_add($StructFichier,Ident::Alias_ParaVide(),$cptParaVide);
}



sub PrintViogen ($)
{
my ($StructFichier) = @_;


# Violation sur le taux de commentaire
    my $Pd_Tx_com = $Pd_CptComment / $Pd_CptInst;

    if ( $Pd_Tx_com < $S_Pd_Tx_com ) {
        # @Code: TC_COM
        # @Type: PRESENTATION COMMENT
        # @Description: Taux de commentaire > seuil
        # @Caractéristiques: 
        #   - Maintenabilité 
        # @RULENUMBER: R13
	Cobol::violation::violation("ATD_TCOM",$StructFichier->{Dat_FileName},$StructFichier->{Dat_ProcDivLine},"Taux de Commentaires trop faible en Procedure Division= $Pd_Tx_com < $S_Pd_Tx_com");
    } 
#else {
#	print "TAUX DE COM BON = $Pd_Tx_com \n";
#    }


}


sub traitepara ($)
{
  my($prevpara)=(@_);
#  print "Dans traitepara pour $prevpara :::: $Para_CptInst \n";
#  print "$FICHIER:$TabPara{$prevpara}:ASUPPRIMER:$prevpara:Pd_CptNivMax<<$Pd_CptNivMax>>:Para_CptNivMax<<$Para_CptNivMax>>\n";

  if ( ($Para_NbVG + 1) > $S_Para_NbVG) {
      my $VGtemp = $Para_NbVG + 1;
      my $VGsansWhen = $Para_NbVG - $Para_NbWhen + 1;
              # @Type: FLOW METRIQUE
	      # @RULENUMBER: R16
	      Cobol::violation::violation("CF_VG_MAX", $FICHIER,$TabPara{$prevpara},"Violation, $prevpara, Nombre cyclomatique($VGtemp,$Para_NbWhen,$VGsansWhen) superieur a $S_Para_NbVG");
  } 
  if ( $Para_CptInst > $S_Para_CptInst) {
              # @Type: FLOW METRIQUE
	      # @RULENUMBER: R20
	      Cobol::violation::violation("CF_NBINS_MAX", $FICHIER,$TabPara{$prevpara},"Violation, $prevpara, Nombre instruction($Para_CptInst) superieur a $S_Para_CptInst");
  } 
  if ( $Para_CptInst == 0) {
              # @Type: FLOW
	      # @RULENUMBER: R21
	      Cobol::violation::violation("CF_PARAVIDE", $FICHIER,$TabPara{$prevpara},"Violation, $prevpara, Pas de paragraphe vide");
      $cptParaVide++;
  } 

#  if ( $Para_CptNivMax > $S_Para_CptNivMax) {
  if ( $Para_CptNivMax > $S_Para_CptNivMax) {
              # @Type: FLOW METRIQUE
	      # @RULENUMBER: R27
	      Cobol::violation::violation("CF_NBNIV_MAX", $FICHIER,$TabPara{$prevpara},"Violation, $prevpara, Nombre de niveau($Para_CptNivMax) superieur a $S_Para_CptNivMax");
  } 

  my $VGt = $Para_NbVG + 1;
  my $NBcom = $Pd_CptComment - $Pd_PrevCptComment;

  my $N = $Pd_NBOPTot - $Pd_PrevNBOPTot;

  my $Tmoy = 0;
  if ($Para_CptInst != 0) {
      $Tmoy =   ($Pd_NBOPTot - $Pd_PrevNBOPTot)/ $Para_CptInst;
  }
  my $ctcopy = $Pd_CptCopy - $Pd_PrevCptCopy;
#      metrique("metrique",$FICHIER,$TabPara{$prevpara},"prevpara:VGt:Para_CptInst:Para_CptNivMax:Para_NbPerform:Para_NbGOTO:NBcom:N:Tmoy:Para_Exit:ctcopy");
  if ($Para_CptInst == 0 || ($prevpara eq "MAIN") || (($Para_CptInst - $ctcopy)== 1 && ($Para_Exit == 1) )) {
      #metrique("metriqueasupprimer",$FICHIER,$TabPara{$prevpara},"$prevpara:$VGt:$Para_CptInst:$Para_CptNivMax:$Para_NbPerform:$Para_NbGOTO:$NBcom:$N:$Tmoy:$Para_Exit:$ctcopy");
  } else {
      #metrique("metrique",$FICHIER,$TabPara{$prevpara},"$prevpara:$VGt:$Para_CptInst:$Para_CptNivMax:$Para_NbPerform:$Para_NbGOTO:$NBcom:$N:$Tmoy:$Para_Exit:$ctcopy");
  }
  $Pd_PrevNBOPTot = $Pd_NBOPTot;
  $Pd_PrevCptComment = $Pd_CptComment;
  $Pd_CptCopy = $Pd_PrevCptCopy;

  if ( $Para_CptIF > 0) {
              # @Type: PRESENTATION
	      # @RULENUMBER: R28
	      Cobol::violation::violation("RC_MISSINGEND", $FICHIER,$TabPara{$prevpara},"Violation, $prevpara, Il manque au moins un end-if quelque part");
  }
   if ( $Para_CptEVA > 0) {
              # @Type: PRESENTATION
	      # @RULENUMBER: R28
	      Cobol::violation::violation("RC_MISSINGEND", $FICHIER,$TabPara{$prevpara},"Violation, $prevpara, Il manque un end-evaluated quelque part");
  } 
   if ( $Para_CptPERFORM > 0) {
              # @Type: PRESENTATION
	      # @RULENUMBER: R28
	      Cobol::violation::violation("RC_MISSINGEND", $FICHIER,$TabPara{$prevpara},"Violation, $prevpara, Il manque un end-perform quelque part $Para_CptPERFORM");
  } 
# on ne compte plus les read ici a faire ailleurs
#    if ( $Para_CptREAD > 0) {
#               # @Type: PRESENTATION
# 	      # @RULENUMBER: R28
#       Cobol::violation::violation("RC_MISSINGEND", $FICHIER,$TabPara{$prevpara},"Violation, $prevpara, Il manque un end-read quelque part");
#   } 

$Pd_CptMissIF = $Pd_CptMissIF + $Para_CptIF;
$Pd_CptMissEVA = $Pd_CptMissEVA + $Para_CptEVA;
$Pd_CptMissPERFORM = $Pd_CptMissPERFORM + $Para_CptPERFORM;

#  Reinitialisation
  $Para_NbVG = 0;
  $Para_NbWhen = 0;
  $Para_CptInst = 0;
  $Para_CptNiv = 0;
  $Para_CptNivMax = 0;
  $Para_NbPerform = 0;
  $Para_NbGOTO = 0;
  $Para_OPAll = 0;
  $Para_OPDiff = 0;
  $Para_Exit = 0;
  $Para_CptIF = 0;
  $Para_CptEVA = 0;;
  $Para_CptPERFORM = 0;


}

sub isParagraph($) {
  my $r_line = shift;
  if ($$r_line =~ m{^ {1,4}($IDENTIFIER)\s*\.}i) {
#print "FOUND A PARAGRAPH : $$r_line\n";
    return $1;
  }
  return undef;
}

sub parseParagraph($$$) {
                my $line = shift;
                my $paraname = uc(shift);
		my $dot = shift;

 		$Pd_NbPara++;

                if (!defined $dot) {
		    # @Code: NOM_PARA_SANS_POINT
		    # @Type: PRESENTATION
		    # @Description: Paragraphe sans "."
		    # @Caractéristiques: 
		    # @Commentaires: 
		    # @Restriction:
		    # @RULENUMBER: Rxx
		    Cobol::violation::violation("PRES_NOM_PARA_SANS_POINT",$FICHIER,$CptLine,"Violation, Attention le nom de paragraphe $paraname n'est pas suivi d'un \".\" " );
		    $Pd_Nbr_ParaNameWithoutDot++;
		} 
                $CurrentPara = $paraname;

		if (exists $TabPara{$CurrentPara}) {
print "DUPLICATE PARA: $CurrentPara\n";
		    # @Code: DUP_NOM_PARA
		    # @Type: FLOW
		    # @Description: Paragraphe de même nom
		    # @Caractéristiques: 
		    # @Commentaires: 
		    # @Restriction:
		    # @RULENUMBER: Rxx
		    Cobol::violation::violation("RC_DUP_NOM_PARA",$FICHIER,$CptLine,"Violation, Paragraphe de même nom $CurrentPara ligne $TabPara{$CurrentPara} " );
		    $Pd_Nbr_DuplicatedParaName++;
		} else {
#TRACE		    print "FLOFLO " . $CurrentPara . "\n";
		    $TabPara{$CurrentPara} = $CptLine;
		}
                if ($PrevPara eq "MAIN") {
		    #metrique("metrique",FICHIER,ligne,"paragraphe:VG:CptInst:CptNivMax:NbPerform:NbGOTO:NBcom:N:Tmoy:Exit");
		    traitepara($PrevPara); #A voir
                } else {
                    $Para_CptInst--;
		    traitepara($PrevPara);
                }
		$PrevPara = $CurrentPara;
		if ($line =~ m{^( ){1,4}(\S+)\s*\.\s*\w}i) {
		    $Para_CptInst++;
#asupprimer		    Cobol::violation::violation("RC_PARA_PLUS_INST",$FICHIER,$CptLine," Il y a quelquechose sur la même ligne que le paragraphe $CurrentPara,  $Para_CptInst instruction" );
		} 
}

sub parseProcedureLine($) {
  my $line = shift;
#print "PARSING : $line\n";
	    #Niveau du paragraphe
	    if ($Para_CptNiv >= $Para_CptNivMax) {
		$Para_CptNivMax = $Para_CptNiv;
	    }
	    if ($Para_CptNiv >= $Pd_CptNivMax) {
		$Pd_CptNivMax = $Para_CptNiv;
	    }
#print "Procedure div" . $Pd_CptInst . $CptLine . "\n";
	    if ($line =~ m{\A\S}) {
		$Pd_CptComment++;
                return;
	    } else {
		if ($line =~ m{\A\s*\Z}) {
		    $Pd_NbLgBl++;
                    return;
#		    print "$FICHIER:$CptLine:COUCOU \n";
		} else {
		    $Pd_CptInst++;
		    $Para_CptInst++;

		}
            } 
# il faut oublier les sections
	    if ($line =~ m{^( ){1,4}(\S+)\s+SECTION\.\s*\Z}i) {
			# @Code: RULE_SECTION
			# @Type:  STATEMENT_INTERDIT
			# @Description: Eviter l'utisation de section
			# @Caractéristiques: 
			# @Restriction: 
		        # @RULENUMBER: Rxx
# @Commentaire: Fait dans MotInterdit
#               Cobol::violation::violation("CF_NOKEY_SECTION", $FICHIER,$CptLine,"Violation, Attention utlisation de section $2"); 
               # Attention return pour le moment
	       return;
	    }
# il faut oublier le SQL
#
# Attention FLO, il va faloir trier les EXEC SQL ET CICS pour le traitement d'erreur
	    if ($line =~ m{\A\s+EXEC\s+SQL.*END-EXEC\s*\.}i){
                $Pd_NB_LigneSQL++;
#		print "$FICHIER:$CptLine:SQLFLOFLO  " . $line;
		TraitementPoint();
                return;
	    }
	    if ($line =~ m{\A\s+EXEC\s+SQL.*END-EXEC}i){
                $Pd_NB_LigneSQL++;
#		print "$FICHIER:$CptLine:SQLFLOFLO  " . $line;
                return;
	    }
	    if ($line =~ m{\A\s+EXEC\s+SQL.*\.}i){
                $Pd_NB_LigneSQL++;
#		print "$FICHIER:$CptLine:SQLFLOFLO  " . $line;
		TraitementPoint();
                return;
	    }
	    if ($line =~ m{\A\s+EXEC\s+CICS.*\.}i){
#                $Pd_NB_LigneSQL++;
#		print $line;
#                $TestSQL = 1;
		TraitementPoint();
                return;
	    }
	    if ($line =~ m{\A\s+EXEC\s+SQL}i){
                $Pd_NB_LigneSQL++;
#		print "$FICHIER:$CptLine:SQLFLOFLO  CAS 2" . $line;
		$dansSQL = 1;
                return;
	    }
	    if (($line =~ m{\A\s+END-EXEC\.}i) || ($line =~ m{\S\s*\bEND-EXEC\s*\.}i)) {
#SI QUELQUECHOSE DEVANT END-EXEC 
                $Pd_NB_LigneSQL++;
		$dansSQL = 0;
#		print "$FICHIER:$CptLine:SQLFLOFLO JE SORT  CAS 1" . $line;
#                $line =~ s{.*}{\.};
                TraitementPoint();
                return;
	    }  
	    if (($line =~ m{\A\s+END-EXEC\b}i) || ($line =~ m{\S\s*\bEND-EXEC\b}i)){
                $Pd_NB_LigneSQL++;
		$dansSQL = 0;
#		print "$FICHIER:$CptLine:SQLFLOFLO JE SORT  CAS 2" . $line;
                return;
	    }

            if ($dansSQL == 1) {
#########################
# Nous sommes dans du SQL
#########################
                $Pd_NB_LigneSQL++;
		return;
	    }



            # Normalement c'est un paragraphe  
            # le caractère . peut être sur la ligne suivante. C'est pas beau
#	if ($line =~ m{^( ){1,4}(\S+)[ \t]*\.[ \t]*\Z}) {
	    #print STDERR "NORMAL PARA <$1><$2>::::" . $line . "\n";
#	} else {
#            if ($line =~ m{^( ){1,4}(\S+)[ \t]*\Z}) {
#print STDERR "ffff  ........... $line\n ";
#	    }
#	}
            # END PROGRAM can be indented in columns 8-12 but is not a paragraph ...
	    if ($line !~ m{^\s*END\s*PROGRAM}i) {
	      if ($line =~ m{^ {1,4}($IDENTIFIER)\s*(\.)?}i) {
	        parseParagraph($line, $1, $2);
	      }
            }

#####################################
# PERFORM
####################################
	    if ($line =~ m{\sPERFORM\s.*}i) {
		$Pd_NbPerform++;
                $Para_NbPerform++;
                $DansPerform = 1;
	    }

	    if ($DansPerform == 1) {

                my $LigneCourante = $line;
                CheckPerform($filename,$LigneCourante);

	    }

#####################################
# IF
####################################
	    if ($line =~ m{\s+IF\s}i) {
                $Pd_NbIF = $Pd_NbIF +1;
		$Pd_NbVG = $Pd_NbVG + 1;
		$Para_NbVG = $Para_NbVG + 1;
                $Para_CptNiv++;
		if ($Para_CptNiv >= $Para_CptNivMax) {
		    $Para_CptNivMax = $Para_CptNiv;
		}
		$Para_CptIF++;
		Cobol::violation::violationdebug("DEBUG",$FICHIER,$CptLine,"Para_CptNiv = $Para_CptNiv ($Para_CptNivMax)");
	    }

	    if ($line =~ m{\s+END-IF\b}i) {
                $Para_CptNiv--;
		if ($Para_CptNiv >= $Para_CptNivMax) {
		    $Para_CptNivMax = $Para_CptNiv;
		}
		$Para_CptIF--;
		Cobol::violation::violationdebug("DEBUG",$FICHIER,$CptLine,"Para_CptNiv = $Para_CptNiv (END-IF)");
	    }

	    if ($line =~ m{(\s+WHEN\s|^\s+EVALUATE\s+.*\sWHEN\s)}i) {
		$Pd_NbCase = $Pd_NbCase + 1;
		$Pd_NbVG = $Pd_NbVG + 1;
		$Para_NbVG = $Para_NbVG + 1;
		$Para_NbWhen = $Para_NbWhen + 1;
	    }

#on peut eventuellement prendre en compte les read (AT) END???
#	    if ($line =~ m{(\s+READ\s+.*AT\s+END\b|\s+READ\s+.*NEXT\s+END\b)}i) {
#		$Pd_NbVG = $Pd_NbVG + 1;
#		$Para_NbVG = $Para_NbVG + 1;
#	    }
###########################################################################
# La vérification des règles dans la procédure division commence ici
###########################################################################
	    if ($line =~ m{(\sGO\s|\sGO\s*TO\s)\s*(.*)}i) {
		$Pd_NbGOTO++;
                $Para_NbGOTO++;
	    }

###############################################################################
#  EVALUATE
#  
##############################################################################
	    if ($line =~ m{(^\s+EVALUATE\s)}i) {
		$Pd_NbEvaluate = $Pd_NbEvaluate + 1;
                $Para_CptNiv++;
		if ($Para_CptNiv >= $Para_CptNivMax) {
		    $Para_CptNivMax = $Para_CptNiv;
		}
		$Para_CptEVA++;
		Cobol::violation::violationdebug("DEBUG",$FICHIER,$CptLine,"Para_CptNiv = $Para_CptNiv (dans EVALUATE $Pd_NbEvaluate)");
	    }
	    if ($line =~ m{(^\s+END-EVALUATE\b)}i) {
               $Para_CptNiv--;
		if ($Para_CptNiv >= $Para_CptNivMax) {
		    $Para_CptNivMax = $Para_CptNiv;
		}
	       $Para_CptEVA--;
	       Cobol::violation::violationdebug("DEBUG",$FICHIER,$CptLine,"Para_CptNiv = $Para_CptNiv (dans END-EVALUATE)");
	    }
##############################################################################

           # Traitement des copy
	    if ($line =~ m{^\s+COPY\s+(.*)}i) {
		$Pd_CptCopy++;

	    }
	    if ($line =~ m{^\s+EXIT(\s*\.|\s)}i) {
		$Para_Exit++;

	    }


	  if ($line =~ m{\(\s*\d+\s*:\s*\d+\s*\)}) {
	      # @Code: MODIF_REF
	      # @Type: RISQ DATA
	      # @Description: La modification de reference intriduite en COBOL ANS 85 est à proscrire
	      # @Caractéristiques: 
	      #   - Maintenabilité, Fiabilité
	      # @Commentaires: Il devient très difficile de s'y retrouver dans les données
	      # @Restriction: 
	      # @RULENUMBER: Rxxx
 
		  Cobol::violation::violationavoir("RC_MODIF_REF", $FICHIER,$CptLine,"Violation,La modification de reference introduite en COBOL ANS 85 est à proscrire");
 
	  }		







#########################
#il y a un . sur la ligne
#########################
	    if ($line =~ m{\.\s*\Z}i) {
		TraitementPoint();
	    }
#TRACE		print "$FICHIER:$CptLine:PARA $CurrentPara ..... $Para_CptNiv \n";
}

sub ParseFile ($$$)
 {
    my ($bufferText2,$filename,$StructFichier) = @_;

    $FICHIER= $filename;
    $buffer=$bufferText2;
#   $/ = "\n"; 

#    while ($buffer =~ /(.*\n)/g ) {
#        my $line = $1;

      my @LINES = split /\n/, $buffer;
      for my $line (@LINES) {
	 $line .= "\n";
	 Cobol::violation::violationdebug("DEBUG_LIGNE_COURANTE",$FICHIER,$CptLine,"Debug, Ligne courante (dansSQL=$dansSQL)::: ");
        # comptage des lignes
	$CptLine++;
        if ($line =~ m{\A\s*\Z}) {
         #ligne blanche
	}
        if ($line =~ m{\AD\s+DISPLAY.*\Z}i) {
         #ligne DEBUG DISPLAY ne compte pas pour commentaire
         #FLO pour le moment rien
	    next;
	}
        if ($line =~ m{\AD.*\Z}i) {
         #ligne DEBUG ne compte pas pour commentaire
         #FLO pour le moment rien
	    next;
	}
        #ligne de commentaire vide, on passe
        if ($line =~ m{\A\S\s*\Z}) {
	    next;
	}
        #ligne de commentaire type *******
        # 3 lignes à adapter éventuellement ou dédoubler
        if ($line =~ m{\A\S\s*\*+\s*\Z}) {

	    next;
	}
        # probablement de vrai lignes de commentaire
        if ($line =~ m{\A\S}) {
	    $CptComment++;

	} else {
#Essai de comptage des operandes et operateurs
	    my $line2 = $line;
	    $line2 =~ s{\n}{}; # suppression \n
	    #traitement des chaines
	    $line2 =~ s{\".*\"}{CHAINE}g;
	    if ($line =~ m{\'.*\'}) {
		my $debline = $line2;
		my $finline = $line2;
		my $chaine = $line2;
		$debline =~ s{(.*)\'.*\'.*}{$1};
		$chaine =~ s{.*\'(.*)\'.*}{$1};
#	    print "dddd $chaine \n";
		$chaine =~ s{ |-}{_}g;
		$finline =~ s{.*\'.*\'(.*)}{$1};
		$line2 = $debline .  $chaine . $finline;
	    }
	    #traitement des - 
	    $line2 =~ s{(\w)-(\w)}{$1_$2};
	    $line2 =~ s{\s+}{ }g;
	    $line2 =~ s{\A\s+}{};
	    $line2 =~ s{:}{ }g; #traitement du :
	    $line2 =~ s{\(}{ \( }g; #traitement de (
	    $line2 =~ s{\.}{ \.}; #traitement du .

	    $line2 =~ s{\)}{}g; #traitement de la )
#	print $_;
	    my $mot;
	    foreach $mot (split / /, $line2) {
#		print "DD" .  $mot  . "FF";
                my $m = uc($mot);
                if (exists $TabOPop{$m}) {
		    $TabOPop{$m}++;
                    $NBOPTot++;
                } else {
		    $TabOPop{$m} = 1;
                    $NBOPTot++;
                    $NBOPdiff++;
		}
		if ($Zone eq "Procedure") {
		    if (exists $Pd_TabOPop{$m}) {
			$Pd_TabOPop{$m}++;
			$Pd_NBOPTot++;
		    } else {
			$Pd_TabOPop{$m} = 1;
			$Pd_NBOPTot++;
			$Pd_NBOPdiff++;
		    }
		}
	    }
#	    print "\nCOUCOU_ " . $line2 . "    NBOPTot=$NBOPTot   <=> NBOPdiff=$NBOPdiff\n";
          
	}
#Fin essai comptage des operandes et operateurs
        # Comptage des clause copy au cas ou
	if ($line =~ m{^\s+COPY\s+.*\Z}i) {
	    $CptCopy++;
	}
        # détermination des zones d'un programme Cobol
	if ($line =~ m{^( ){1,4}IDENTIFICATION\s+DIVISION.*\Z}i) {
	    $Zone = "Ident";
            next;
	}
	if ($line =~ m{^( ){1,4}ENVIRONMENT\s+DIVISION.*\Z}i) {
	    $Zone = "Envir";
            next;
	}
	if ($line =~ m{^( ){1,4}FILE-CONTROL.*\Z}i) {
	    $Zone = "FileControl";
            next;
	}
	if ($line =~ m{^( ){1,4}DATA\s+DIVISION.*\Z}i) {
	    $Zone = "Data";
            next;
	}
	if ($line =~ m{^( ){1,4}FILE\s+SECTION.*\Z}i) {
	    $Zone = "Filesection";
            next;
	}
	if ($line =~ m{^( ){1,4}WORKING-STORAGE\s+SECTION.*\Z}i) {
	    $Zone = "Working";
            next;

	}
	if ($line =~ m{^( ){1,4}LINKAGE\s+SECTION.*\Z}i) {
	    $Zone = "Linkage";
            next;
	}
	if ($line =~ m{^( ){1,4}PROCEDURE\s+DIVISION.*\Z}i) {
	    $Zone = "Procedure";
            $CurrentPara = "<IMPLICIT MAIN>";
            $PrevPara = "<IMPLICIT MAIN>";
	    $TabPara{$CurrentPara} = $CptLine;
            next;
	}

        #Suivant le type de Zone on peux compter des objets differents
        # Nous sommes en Identification-division
	if ($Zone eq "Ident") {
	}
        # Nous sommes en FILE-CONTROL
	if ($Zone eq "FileControl") {
	    # on saute les lignes de commentaire
	    if ($line =~ m{\A\S}) {
		next;
	    } 
           # Traitement des copy
	    if ($line =~ m{^\s+COPY\s+(.*)}i) {
		$Fc_CptCopy++;
	    }

	    if ($line =~ m{^\s+SELECT\s.*}i) {
		$Fc_NbFile++;
	    }

	}
        #############################
        # Nous sommes en File section
        #############################
	if ($Zone eq "Filesection") {
	    if ($line =~ m{\As*\Z}) { # ligne blanche
                next;
	    }
	    # on saute les lignes de commentaire
	    if ($line =~ m{\A\S}) {
		next;
	    } 
	    if ($line =~ m{^\s+FD\s.*}i) {
		$Fs_NbFile++;
	    }

	    if ($line =~ m{^\s+COPY\s+(.*)}i) {
		$Fs_CptCopy++;
	    }

	}

        # Nous sommes en working-storage
	if ($Zone eq "Working") {

	    if ($line =~ m{^\s+(01|1)\s.*}i) {
		$Ws_NbData01++;
	    }
	    if ($line =~ m{^\s+(66|77|88)\s+(\w[\w-]*)\s(.*)}i) {
		$Ws_NbData77++;
	    }
	    if ($line =~ m{^\s+COPY\s+(.*)}i) {
		$Ws_CptCopy++;
	    }


	} #Fin working-storage

        # Nous sommes en Linkage
	if ($Zone eq "Linkage") {
	    # on saute les lignes de commentaire
	    if ($line =~ m{\A\S}) {
		next;
	    } 
	    if ($line =~ m{^\s+\d+\s.*}i) {
		$Ls_NbLink01++;
	    }
	} # fin Linkage


        # Nous sommes en procedure division
	if ($Zone eq "Procedure") {
          parseProcedureLine($line);
	}

	# If no zone has been recognized, then try to recognize implicit
	# zone with particular pattern. Indeed, in copybook, zone (division,
	# section, paragraph) are not necessariliy declared.
	if ($Zone eq 'No') {
          my $paraName = isParagraph(\$line);
  	  if (defined $paraName) {
	    $Zone = "Procedure";
	    parseParagraph($line, $paraName, 1);
          }
	}






    } # fin boucle
	
    close(FILE2);
}


#Cobol::violation::violation("metrique",FICHIER,NBLINE,"NBDATA01:NBDATA77:LOC:TCOM:VGtot:VGMoyen");
#print "FICHIER:NBLINE:NBDATA01:NBDATA77:LOC:TCOM:VGtot:VGMoyen\n";

# sub getNextInstrLine() {
#     #print "getNextInstrLine()\n";
#     $_=<FILE>;
# #    $_=substr($_, $firstCol, $lineSize);
#     while ((!eof(FILE)) && ((/^\S/) || (/^\s*$/))) {
# 	$_=<FILE>;
#     }
#     $CptLine++; # il faut incrémenter le compteur de ligne

#     return $_;
# }

# sub getNextLine() {
#     #print "getNextInstrLine()\n";
#     $_=<FILE>;
# #    $_=substr($_, $firstCol, $lineSize);
# #    while ((!eof(FILE)) && ((/^\S/) || (/^\s*$/))) {
# #	$_=<FILE>;
# #    }
#     $CptLine++; # il faut incrémenter le compteur de ligne
# #    print "DANS getNextLine $CptLine >>" . $_;
#     return $_;
# }


sub CheckPerform() {
    my($filename,$line)=(@_);

    if ($line =~ m{\bPERFORM\b}i) {
        $LoopFound=0;
    }
    if ( (! $LoopFound ) && ($line =~ m{\b(VARYING|UNTIL|TIMES)\b}i)) {
        $LoopFound=1;
        $Pd_BoucleFor = $Pd_BoucleFor + 1;
	$Pd_NbVG = $Pd_NbVG + 1;
	$Para_NbVG = $Para_NbVG + 1;

	# Nombre d'imbrication des structures de controle.
	$Para_CptNiv++;

	# Comptabilisation du niveau max atteind ...
	if ($Para_CptNiv >= $Para_CptNivMax) {
	    $Para_CptNivMax = $Para_CptNiv;
	}
	# Nombre d'imbrication de boucles.
	$Para_CptPERFORM++;
    }

    if ($line =~ m{\sPERFORM\s+(VARYING|UNTIL)}i) {
#        $Pd_BoucleFor = $Pd_BoucleFor + 1;
#	$Pd_NbVG = $Pd_NbVG + 1;
#	$Para_NbVG = $Para_NbVG + 1;
#	$Para_CptNiv++;
#	if ($Para_CptNiv >= $Para_CptNivMax) {
#	    $Para_CptNivMax = $Para_CptNiv;
#	}
#	$Para_CptPERFORM++;
	    Cobol::violation::violationdebug("DEBUG1",$FICHIER,$CptLine,"Para_CptNiv = $Para_CptNiv (dans PERFORM)");
#	print $1 . ":DEBUG1:OK: $line \n";
	return;
    }
    if ($line =~ m{\sPERFORM\s+(\S+)\s+(VARYING|UNTIL)}i) {
#        $Pd_BoucleFor = $Pd_BoucleFor + 1;
#	$Pd_NbVG = $Pd_NbVG + 1;
#	$Para_NbVG = $Para_NbVG + 1;
#	$Para_CptNiv++;
#	if ($Para_CptNiv >= $Para_CptNivMax) {
#	    $Para_CptNivMax = $Para_CptNiv;
#	}
#	$Para_CptPERFORM++;
	# @Code: NOTHRU
	# @Type: FLOW
	# @Description: Les instructions PERFORM doivent être écrites avec la clause THRU
	# @Caractéristiques: 
	#   - maintenabilité
	# @Commentaires: 
	# @RULENUMBER: Rxx
	# @Restriction: 
	Cobol::violation::violation("CF_NOTHRU1",$FICHIER,($CptLine),"Violation, Les instructions PERFORM doivent être écrites avec la clause THRU " );
#	print $1 . ":CF_NOTHRU1:KOKO: $line \n";
	return;
    }
    if ($line =~ m{\sPERFORM\s+(\S+)\s+(THRU|THROUGH)\s+(\S+)\s+(VARYING|UNTIL)}i) {
#        $Pd_BoucleFor = $Pd_BoucleFor + 1;
#	$Pd_NbVG = $Pd_NbVG + 1;
#	$Para_NbVG = $Para_NbVG + 1;
#	$Para_CptNiv++;
#	if ($Para_CptNiv >= $Para_CptNivMax) {
#	    $Para_CptNivMax = $Para_CptNiv;
#	}
#	$Para_CptPERFORM++;
	    Cobol::violation::violationdebug("DEBUG2",$FICHIER,$CptLine,"Para_CptNiv = $Para_CptNiv (dans PERFORM)");
#	print $1 . ":DEBUG2:OK: $line \n";
$BesoinThru = 0;
	return;
    }

    if ($line =~ m{\sPERFORM\s+(\S+)\s+(THRU|THROUGH)\s}i) {
#Tous va bien
$BesoinThru = 0;
#	print $1 . ":DEBUG3:OK: $line \n";
	return;
    }
    if ($line =~ m{\sPERFORM\s+(\S+)\s+(\S+)\s*\Z}i) {
	    Cobol::violation::violation("CF_NOTHRU2",$FICHIER,($CptLine),"Violation, Les instructions PERFORM doivent être écrites avec la clause THRU " );
$BesoinThru = 0;

#	print $1 . ":CF_NOTHRU2:KOKO: $2 " . "::: $line \n";
	return;
    }
    if ($line =~ m{\sPERFORM\s+(\S+)\s*\Z}i) {
#	Cobol::violation::violation("CF_NOTHRU",$FICHIER,($CptLine),"Violation, Les instructions PERFORM doivent être écrites avec la clause THRU " );        
	$BesoinThru = 1;

#	print $1 . ":DEBUG4__ICIICI:POTENTIEL: $line \n";
	return;
    }
    if ($line =~ m{\sPERFORM\s*\Z}i) {
#	Cobol::violation::violation("CF_NOTHRU",$FICHIER,($CptLine),"Violation, Les instructions PERFORM doivent être écrites avec la clause THRU " );        
	$BesoinThru = 1;

#	print  ":DEBUG5:POTENTIEL: $line \n";
	return;
    }
    if ($line =~ m{\sPERFORM}i) {
	    Cobol::violation::violation("CF_NOTHRU",$FICHIER,($CptLine),"Violation, Les instructions PERFORM doivent être écrites avec la clause THRU " );        
	$BesoinThru = 0;
#	print  ":DEBUG5BIS:POTENTIELPOTENTIELPOTENTIEL  SUR: $line \n";
	return;
    }

    if ($line =~ m{\A\s+\S+\s+(THRU|THROUGH)}i) {
$BesoinThru = 0;
#	print  ":DEBUG6:OK: $line \n";
	return;
    }
    if ($line =~ m{\A\s+(THRU|THROUGH)}i) {
$BesoinThru = 0;
#	print  ":DEBUG6bis:OK: $line \n";
	return;
    }

    if ($line =~ m{\A\s+\S+\s+(VARYING|UNTIL)}i) {
#        $Pd_BoucleFor = $Pd_BoucleFor + 1;
#	$Pd_NbVG = $Pd_NbVG + 1;
#	$Para_NbVG = $Para_NbVG + 1;
#	$Para_CptNiv++;
#	if ($Para_CptNiv >= $Para_CptNivMax) {
#	    $Para_CptNivMax = $Para_CptNiv;
#	}
#	$Para_CptPERFORM++;
	    Cobol::violation::violationdebug("DEBUG7",$FICHIER,$CptLine,"Para_CptNiv = $Para_CptNiv (dans PERFORM)");
	# @Code: NOTHRU
	# @Type: FLOW
	# @Description: Les instructions PERFORM doivent être écrites avec la clause THRU
	# @Caractéristiques: 
	#   - maintenabilité
	# @Commentaires: 
	# @RULENUMBER: Rxx
	# @Restriction: 
       if ($BesoinThru == 1) {
	       Cobol::violation::violation("CF_NOTHRU3",$FICHIER,($CptLine),"Violation, Les instructions PERFORM doivent être écrites avec la clause THRU " );
#	print  ":CF_NOTHRU3:KOKO: $line \n";
       }

	$BesoinThru = 0;
	return;
    }
    if ($line =~ m{(VARYING|UNTIL)}i) {
#        $Pd_BoucleFor = $Pd_BoucleFor + 1;
#	$Pd_NbVG = $Pd_NbVG + 1;
#	$Para_NbVG = $Para_NbVG + 1;
#	$Para_CptNiv++;
#	if ($Para_CptNiv >= $Para_CptNivMax) {
#	    $Para_CptNivMax = $Para_CptNiv;
#	}
#	$Para_CptPERFORM++;
	    Cobol::violation::violationdebug("DEBUG8",$FICHIER,$CptLine,"Para_CptNiv = $Para_CptNiv (dans PERFORM)");
        if ($BesoinThru == 1) {
		Cobol::violation::violation("CF_NOTHRU4",$FICHIER,($CptLine),"Violation, Les instructions PERFORM doivent être écrites avec la clause THRU " );  
# print  ":CF_NOTHRU4:KOKO: $line \n";
	}
	$BesoinThru = 0;
#	print  ":DEBUG8:???: $line \n";
	return;
    }

    if ($line =~ m{\s+END-PERFORM\b}i) {
	$Para_CptNiv--;
	if ($Para_CptNiv >= $Para_CptNivMax) {
	    $Para_CptNivMax = $Para_CptNiv;
	}
        if ($BesoinThru == 1) {
		Cobol::violation::violation("CF_NOTHRU5",$FICHIER,($CptLine),"Violation, Les instructions PERFORM doivent être écrites avec la clause THRU " );   
# print  ":CF_NOTHRU5:KOKO: $line \n";
	}
	$BesoinThru = 0;
	$Para_CptPERFORM--;
	$DansPerform = 0;
	Cobol::violation::violationdebug("DEBUG",$FICHIER,$CptLine,"Para_CptNiv = $Para_CptNiv (dans END-PERFORM)");
	Cobol::violation::violationdebug("DEBUG",$FICHIER,$CptLine,"Para_CptPERFORM = $Para_CptPERFORM (END-PERFORM)");
	return;
    }
    if ($line =~ m{\A\s+\S+\s*\Z}i) {
	$BesoinThru = 1;
#	print  ":DEBUG9:POTENTIEL: $line \n";
	return;
    }
 
    if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
	$DansPerform = 0;
        if ($BesoinThru == 1) {
		Cobol::violation::violation("CF_NOTHRU6",$FICHIER,($CptLine),"Violation, Les instructions PERFORM doivent être écrites avec la clause THRU " );  
 
# print  ":CF_NOTHRU6:KOKO: $line \n"; 
	}
	$BesoinThru = 0;
	return;
    }
}

sub TraitementPoint() {
    if ($Para_CptNiv > 0) {
#		    $Para_CptNiv--;
	if ($Para_CptNiv >= $Para_CptNivMax) {
	    $Para_CptNivMax = $Para_CptNiv;
	}
#quand il y a un ., ca clot les structures de controle.
	$Para_CptNiv = 0;
	Cobol::violation::violationdebug("DEBUG",$FICHIER,$CptLine,"Para_CptNiv = $Para_CptNiv (dans .),$Para_CptNivMax ");
    }
}


sub GetMetriques($$$)
{
    my($bufferText2,$filename,$StructFichier)=(@_);
      initcompteur();
      ParseFile($bufferText2,$filename,$StructFichier);

      PrintResMetriques($StructFichier);

     PrintViogen($StructFichier);
}

1;
