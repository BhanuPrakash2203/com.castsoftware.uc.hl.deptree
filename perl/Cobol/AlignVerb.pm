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
#
# Description: Composant de comptages sur code source COBOL
#
#
#  Historique:
#
# Liste des Violations:
# Cobol::violation::violation("PRES_ALIGN_VERB",$filename,$CptLine,"Violation, Alignement de verbe incorrect END-SQL $OffsetSQL[$NivSql] $Offset " . $line);
# Cobol::violation::violation("PRES_ALIGN_VERB",$filename,$CptLine,"Violation, Alignement de verbe incorrect END-SEARCH $OffsetSEARCH[$NivSEARCH] $Offset " . $line);
# Cobol::violation::violation("PRES_ALIGN_VERB",$filename,$CptLine,"Violation, Alignement de verbe incorrect END-EVALUATE NIVEVA=$NivEVA  $OffsetEVA[$NivEVA] $CurOffset " . $line);
# Cobol::violation::violation("PRES_ALIGN_VERB",$filename,$CptLine,"Violation,Alignement de verbe incorrect ELSE NIVELSE=$NivIF  $OffsetIF[$NivIF] $CurOffset " . $line);
# Cobol::violation::violation("PRES_ALIGN_VERB",$filename,$CptLine,"Violation,Alignement de verbe incorrect END-IF NIVIF=$NivIF $OffsetIF[$NivIF] $CurOffset " . $line);
# Cobol::violation::violation("PRES_ALIGN_VERB",$filename,$CptLine,"Violation, Alignement de verbe incorrect END-PERFORM NIVPERF=$NivPERF  $OffsetPERF[$NivPERF] $CurOffset " . $line);

# Cobol::violation::violation("RC_MISSINGEND",$filename,$CptLine,"Curieux, il doit manquer un end-SEARCH\n");

use Cobol::violation;

use Cobol::CobolCommon;

my $IDENTIFIER = Cobol::CobolCommon::get_IDENTIFER_PATTERN();

    my $filename = "";
    my $StructFichier;

    my $NivSql = 0;
    my @OffsetSQL = ();

    my $NivEVA = 0;
    my @OffsetEVA = ();
    my $NivIF = 0;
    my @OffsetIF = ();
    my $NivPERF = 0;
    my @OffsetPERF = ();

    my $NivSEARCH = 0;
    my @OffsetSEARCH = ();

    my $CurrentPara = 0;
    my $DansPerf = 1;
    my $PrevLinePerfoffset= 0;

    my $CptLine = 0;

#Compteur
    my $cptBadEndClauseAlign = 0;

sub initAlignVerb($$) {
    ($StructFichier,$filename)=(@_);
    $CurrentPara = "";
}

sub AlignVerb($$$) {
	# One line of ProcDiv
        my $line = shift;
	my $CptLine=shift;
	my $NewPara=shift;

	if (defined $NewPara) {

           $CurrentPara = $NewPara;

	   $DansPerf = 0;
	   $PrevLinePerfoffset = 0;
	   $NivSql = 0;
	   $NivEVA = 0;
	   $NivIF = 0;
	   $NivPERF = 0;
	   $NivSEARCH = 0;
	   @OffsetSQL = ();
	   @OffsetEVA = ();
	   @OffsetIF = ();
	   @OffsetPERF = ();
	   @OffsetSEARCH = ();
        }

	    if ($DansPerf == 1) {
		if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
		   $DansPerf = 0;
		}
		if ($line =~ m{(\s+VARYING|\s+UNTIL)\b}i){
		    $NivPERF++;
#		    $OffsetPERF[$NivPERF] = $PrevLinePerfoffset;
		    Cobol::violation::violationdebug2("RC_MISSINGEND2_DEBUG0",$filename,$CptLine,"PERFORM $CurrentPara :::: $line");
		    $DansPerf = 0;
		}
	    }

	    if ($line =~ m{\A\s+EXEC\s+(SQL|CICS|ADABAS).*END-EXEC}i){
		# ORDRE SQL sur une ligne, on passe
		if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
		    CheckNiv($filename,$line);
		}
                return;
	    }
	    if ($line =~ m{\A(\s+)EXEC\s+(SQL|CICS|ADABAS)}i){
                $NivSql++;
		$OffsetSQL[$NivSql] = length($1);
                return;
	    }
#AFAIRE: si les END sont précédés de quelque chose.
	    if ($line =~ m{\A(\s+)END-EXEC}i){
		if ($NivSql <= 0) {
		    $line =~ s{\n}{};
		    Cobol::violation::violation("PRES_ALIGN_VERB_COMPIL",$filename,$CptLine,"Violation, END-EXEC sans EXEC????  " . $line);
		} else {
		    my $Offset =  length($1);
		    if ($OffsetSQL[$NivSql] != $Offset) {
			$line =~ s{\n}{};
			Cobol::violation::violation("PRES_ALIGN_VERB",$filename,$CptLine,"Violation, Alignement de verbe incorrect END-EXEC SQL $OffsetSQL[$NivSql] $Offset " . $line);
			$cptBadEndClauseAlign++;
		    } else {
			Cobol::violation::violationdebug("PRES_ALIGN_VERB",$filename,$CptLine,"Bon a priori, Alignement de verbe correct END-SAQL $OffsetSQL[$NivSql] $Offset " . $line); 
		    }
		    $OffsetSQL[$NivSql] = -1;
		    $NivSql--;
		    if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
			CheckNiv($filename,$line);
		    }
		}
		return;
	    }

	    if ($line =~ m{\A(\s+)SEARCH}i){
                $NivSEARCH++;
		$OffsetSEARCH[$NivSEARCH] = length($1);
                return;
	    }
	    if ($line =~ m{\A(\s+)END-SEARCH}i){
                my $Offset =  length($1);
                if ($OffsetSEARCH[$NivSEARCH] != $Offset) {
                    $line =~ s{\n}{};
		    Cobol::violation::violation("PRES_ALIGN_VERB",$filename,$CptLine,"Violation, Alignement de verbe incorrect END-SEARCH $OffsetSEARCH[$NivSEARCH] $Offset " . $line);
		    $cptBadEndClauseAlign++;
		} else {
                    $line =~ s{\n}{};
		    Cobol::violation::violationdebug("PRES_ALIGN_VERB",$filename,$CptLine,"Bon a priori, Alignement de verbe correct END-SEARCH $OffsetSEARCH[$NivSEARCH] $Offset " . $line); 
		}
		$OffsetSEARCH[$NivSEARCH] = -1;
                $NivSEARCH--;
		if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
		   CheckNiv($filename,$line);
		}
		return;
	    }


	    if ($line =~ m{\A(\s+)EVALUATE\b}i){
                
                $NivEVA++;
		$OffsetEVA[$NivEVA] = length($1);
                return;
	    }
	    if ($line =~ m{\A(\s+)END-EVALUATE\b}i){
                my $CurOffset =  length($1);
                if ($OffsetEVA[$NivEVA] != $CurOffset) {
                    $line =~ s{\n}{};
		    Cobol::violation::violation("PRES_ALIGN_VERB",$filename,$CptLine,"Violation, Alignement de verbe incorrect END-EVALUATE NIVEVA=$NivEVA  $OffsetEVA[$NivEVA] $CurOffset " . $line);
		    $cptBadEndClauseAlign++;
		} else {
 Cobol::violation::violationdebug("PRES_ALIGN_VERB",$filename,$CptLine,"Bon a priori, Alignement de verbe correct END-EVA $NivEVA OK $OffsetEVA[$NivEVA] $CurOffset " . $line); 
		}
		$OffsetEVA[$NivEVA] = -1;
                $NivEVA--;
		if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
		    CheckNiv($filename,$line);
		}
		return;
	    }

	    if ($line =~ m{\A(\s+)IF\b}i){
                $NivIF++;
#print "$filename:$CptLine:DEBUG:CAS 1:$NivIF" . $line;
		$OffsetIF[$NivIF] = length($1);
                return;
	    }
	    if ($line =~ m{\A(\s+)ELSE(\s+)IF\b}i){
                $NivIF++;
#print "$filename:$CptLine:DEBUG:CAS 2: $NivIF" . $line;
		$OffsetIF[$NivIF] = length($1) + 4 + length($2);
                return;
	    }
	    

	    if ($line =~ m{\A(\s+)ELSE\b[^\-]}i){
		my $CurOffset =  length($1);
                if ($NivIF == 0) {
		    print "Error:unexpected ELSE in $filename at line $CptLine (NivIF = $NivIF)\n";
	        }
                else {
		    if ($OffsetIF[$NivIF] != $CurOffset) {
			$line =~ s{\n}{};
			Cobol::violation::violation("PRES_ALIGN_VERB",$filename,$CptLine,"Violation,Alignement de verbe incorrect ELSE NIVELSE=$NivIF  $OffsetIF[$NivIF] $CurOffset " . $line);
			$cptBadEndClauseAlign++;
		    } else {
			Cobol::violation::violationdebug("PRES_ALIGN_VERB",$filename,$CptLine,"Bon a priori, Alignement de verbe correct END-IF $NivIF OK $OffsetIF[$NivIF] $CurOffset " . $line); 
		    }
		}
		if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
		    CheckNiv($filename,$line);
		}
		return;
	    }

	    if ($line =~ m{\A(\s+)END-IF\b}i){
                my $CurOffset =  length($1);
		#print STDERR  "$CptLine,$line";
		if ($NivIF == 0) {
		    print "Error: unexpected END-IF in $filename at line $CptLine (NivIF = $NivIF)\n";
	        }
                else {
                  if ($OffsetIF[$NivIF] != $CurOffset) {
                    $line =~ s{\n}{};
		    Cobol::violation::violation("PRES_ALIGN_VERB",$filename,$CptLine,"Violation,Alignement de verbe incorrect END-IF NIVIF=$NivIF $OffsetIF[$NivIF] $CurOffset " . $line);
		    $cptBadEndClauseAlign++;
		  } else {
		    Cobol::violation::violationdebug("PRES_ALIGN_VERB",$filename,$CptLine,"Bon a priori, Alignement de verbe correct END-IF $NivIF OK $OffsetIF[$NivIF] $CurOffset " . $line); 
		  }
	        }
		$OffsetIF[$NivIF] = -1;
                $NivIF--;
#print "$filename:$CptLine:DEBUG:CAS 4 - :$NivIF" . $line;
		if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
		    CheckNiv($filename,$line);
		}
		return;
	    }

            if ($line =~ m{\A(.*)\bIF\b}i){
# A FAIRE? Le cas precedent pourrait être traité ici aussi. 
#Cas            NOT INVALID IF LGASS = 97 OR 182
#Cas            WRITE ENR-LIGNE.IF KFEDBI-STATUS NOT = '00'
                $NivIF++;
#print "$filename:$CptLine:DEBUG:CAS 3: $NivIF" . $line;
		$OffsetIF[$NivIF] = length($1) ;
                return;
	    }

	    if ($line =~ m{\A(\s+)(PERFORM\s+VARYING|PERFORM\s+UNTIL)\b}i){
                $NivPERF++;
#		$OffsetPERF[$NivPERF] = length($1);
		$PrevLinePerfoffset = length($1);
		Cobol::violation::violationdebug2("RC_MISSINGEND2_DEBUG1",$filename,$CptLine,"PERFORM $CurrentPara :::: $line");
                return;
	    }
	    if ($line =~ m{\A(\s+)(PERFORM\s+\S+\s+VARYING|PERFORM\s+\S+\s+UNTIL)\b}i){
                $NivPERF++;
#		$OffsetPERF[$NivPERF] = length($1);
		$PrevLinePerfoffset = length($1);
		Cobol::violation::violationdebug2("RC_MISSINGEND2_DEBUG2",$filename,$CptLine,"PERFORM $CurrentPara :::: $line");
                return;
	    }
	    if ($line =~ m{\A(\s+)(PERFORM\s*\Z|PERFORM\s+\S+\s*\Z)}i){
#		print "$filename:$CptLine:CAS SPECIAL" . $line;
                $DansPerf = 1;

		$PrevLinePerfoffset = length($1);
		Cobol::violation::violationdebug2("RC_MISSINGEND2_DEBUG3",$filename,$CptLine,"PERFORM $CurrentPara :::: $line");
		if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
		    CheckNiv($filename,$line);
		}
                return;
	    }


	    if ($line =~ m{\A(\s+)END-PERFORM\b}i){
                my $CurOffset =  length($1);

                if ($PrevLinePerfoffset != $CurOffset) {
                    $line =~ s{\n}{};
		    Cobol::violation::violation("PRES_ALIGN_VERB",$filename,$CptLine,"Violation, Alignement de verbe incorrect END-PERFORM NIVPERF=$NivPERF  $PrevLinePerfoffset $CurOffset " . $line);
		    $cptBadEndClauseAlign++;
		} else {
		}
#		$OffsetPERF[$NivPERF] = -1;
                $NivPERF--;
		if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
		    CheckNiv($filename,$line);
		}
		return;
	    }

		if ($line =~ m{\A(\s+)(CLOSE|OPEN|MOVE|CALL|READ|DISPLAY|WRITE|REWRITE|GO|GOTO|ADD|DIVIDE|COMPUTE|INITIALIZE|MULTIPLY|STRING|ACCEPT)\b}i) { 
		    if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
			CheckNiv($filename,$line);
		    }
		    return;
		}

		if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
		    CheckNiv($filename,$line);
		}
		return;

    } # fin boucle ligne

sub endAlignVerb() {
    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_BadEndClauseAlign(),$cptBadEndClauseAlign);
    reinitAlignVerb();
}


sub CheckNiv {
   my($filename,$line)=(@_);
    if ($NivEVA != 0) {
#Violation	print "\n$filename:$CptLine:Curieux, il doit manquer un end-evaluate\n";
	Cobol::violation::violationdebug2("RC_MISSINGEND2",$filename,$CptLine,"Curieux, il doit manquer un END-EVALUATE dans le paragraphe $CurrentPara");
	$NivEVA = 0;
    }
    if ($NivIF != 0) {

	Cobol::violation::violationdebug2("RC_MISSINGEND2",$filename,$CptLine,"Curieux, il doit manquer un END-IF dans le paragraphe $CurrentPara");
	$NivIF = 0;
#print "\n$filename:$CptLine:DEBUG:CAS 4 :$NivIF:Curieux, il doit manquer un end-if\n";
    }
    if ($NivPERF != 0) {
#Violation	print "\n$filename:$CptLine:Curieux, il doit manquer un end-PERFORM\n";
	$NivPERF = 0;

	Cobol::violation::violationdebug2("RC_MISSINGEND2",$filename,$CptLine,"Curieux, il doit manquer un END-PERFORM dans le paragraphe $CurrentPara,  $line");
    }
    if ($NivSEARCH != 0) {
	Cobol::violation::violationdebug2("RC_MISSINGEND2",$filename,$CptLine,"Curieux, il doit manquer un END-SEARCH dans le paragraphe $CurrentPara");
	$NivSEARCH= 0;
    }
   @OffsetSQL = ();
   @OffsetSEARCH = ();
   @OffsetEVA = ();
   @OffsetIF = ();
   @OffsetPERF = ();
   $DansPerf = 0;
   $PrevLinePerfoffset= 0;
}

sub reinitAlignVerb
{
 $NivSql = 0;
 @OffsetSQL = ();

 $NivEVA = 0;
 @OffsetEVA = ();
 $NivIF = 0;
 @OffsetIF = ();
 $NivPERF = 0;

 @OffsetPERF = ();

 $NivSEARCH = 0;
 @OffsetSEARCH = ();

 $CurrentPara = 0;
 $CptLine = 0; 
 $DansPerf = 1;
 $PrevLinePerfoffset= 0;

 $CptLine = 0;

#Compteur
 $cptBadEndClauseAlign = 0;
}

1;
