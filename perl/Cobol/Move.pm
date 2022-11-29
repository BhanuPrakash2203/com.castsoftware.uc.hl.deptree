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

use Cobol::violation;

my $multaffectpOSSIBLE = 0;
my $DansMove = 0;
my $previousToOffset = -1;
my $CurrentLevelMove = 0;
my $PrevLevelMove = 0;
my $Para_CptNiv = 0;
my $CurrentPara = "";

#Compteur
my $cptBadInitMove = 0;
my $cptMultAffect = 0;
my $cptBadToAlign = 0;

# Var for init parameters
my $StructFichier;
my $filename;

sub initMove($$) {
    ($StructFichier,$filename)=(@_);

    $multaffectpOSSIBLE = 0;
    $DansMove = 0;
    $previousToOffset = -1;
    $CurrentLevelMove = 0;
    $PrevLevelMove = 0;
    $Para_CptNiv = 0;

    $cptBadInitMove = 0;
    $cptMultAffect = 0;
    $cptBadToAlign = 0;
}

sub Move  ($$$) {
	# One line of ProcDiv
        my $line = shift;
	my $CptLine=shift;
	my $NewPara=shift;

	if (defined $NewPara) {
          $CurrentPara=$NewPara;
	  reinitpara();
        }

	    if ($line =~ m{(PERFORM\s+VARYING|PERFORM\s+UNTIL)}i) {
		$Para_CptNiv++;
	    }
	    if ($line =~ m{\s+END-PERFORM\b}i) {
                $Para_CptNiv--;
	    }
	    if ($line =~ m{\s+IF\s}i) {
		$Para_CptNiv++;
	    }
	    if ($line =~ m{\s+END-IF\b}i) {
                $Para_CptNiv--;
	    }
	    if ($line =~ m{ (^\s+EVALUATE\s)}i) {
		$Para_CptNiv++
	    }
	    if ($line =~ m{(^\s+END-EVALUATE\b)}i) {
		$Para_CptNiv--;
	    }
########################################
# Tentative de verification d'alignement
########################################
# Alignement des TO
########################################
	if ($line =~ m{(.*)MOVE\s(.*)\sTO\s+}i) {
#	      print "$filename:$CptLine: MOVE previousToOffset <$previousToOffset> CurrentLevelMove <$CurrentLevelMove> PrevLevelMove <$PrevLevelMove> Para_CptNiv <$Para_CptNiv>  " . $_;
	    if ($previousToOffset == -1) {
		$CurrentLevelMove = $Para_CptNiv;
		$PrevLevelMove =  $Para_CptNiv;
		$previousToOffset = length($1) + 5 + length($2) + 1;
	    } else {
		$CurrentLevelMove = $Para_CptNiv;
		my $offset = length($1) + 5 + length($2) + 1;
		if ($CurrentLevelMove == $PrevLevelMove
		    && $previousToOffset != $offset) {
		    # @Code: TO_ALIGN
		    # @Type: PRESENTATION
		    # @Description: Clause TO non alignée
		    # @Caractéristiques: 
		    #   - Facilité d'analyse
		    # @Commentaires:
		    # @Restriction: 
		    # @RULENUMBER: Rxxx
		    Cobol::violation::violation2("PRES_MOVE_TO_ALIGN", $filename,$CptLine,"Violation,  Les mots clés TO doivent être alignés dans les instructions MOVE");
		    $cptBadToAlign++;
		    $previousToOffset = $offset;
		}
	    }
	    
	} else {
	    # si pas de move previousToOffset reinitialisé
	    $previousToOffset = -1;
	}
	if ($line =~ m{(\sMOVE\s+)}i) {
	    $DansMove = 1;
	}
##############################################################################
	if ($DansMove == 1) {
#	    if ($line =~ m{(\sMOVE\s+(0|\+0)\s+TO)}i)
	    if ($line =~ m{(\sMOVE\s+(0|\+0)\s)}i) {
		   # @Code: MOVE_ZERO_SPACE
		   # @Type: DATA
		   # @Description: Utiliser ZERO OU SPACE pour initialiser des zones par MOVE
		   # @Caractéristiques: Maint
		   # @Commentaires: 
		   # @Restriction: 
		   # @RULENUMBER: Rxx
		   Cobol::violation::violation2("RC_MOVE_ZERO_SPACE", $filename,$CptLine,"Violation, Utiliser ZERO pour initialiser des zones par MOVE");
		   $cptBadInitMove++;
	    }
#	    if ($line =~ m{(\sMOVE\s+'\s+'\s+TO)}i) 
	    if ($line =~ m{(\sMOVE\s+'\s+'\s)}i) {
		   # @Code: MOVE_ZERO_SPACE
		   # @Type: DATA
		   # @Description: Utiliser ZERO OU SPACE pour initialiser des zones par MOVE
		   # @Caractéristiques: Maint
		   # @Commentaires: 
		   # @Restriction: 
		   # @RULENUMBER: Rxx
		   Cobol::violation::violation2("RC_MOVE_ZERO_SPACE", $filename,$CptLine,"Violation, Utiliser SPACE pour initialiser des zones par MOVE");
		   $cptBadInitMove++;
	    }
	}
#######################################################################
# Plusieurs affectations
#######################################################################
	if ($DansMove == 1) {
	    Cobol::violation::violationdebug("DEBUG", $filename,$CptLine,"DEBUG, $line");
	    if ($line =~ m{\sTO\s+[\w-]+\s+[\w-]+}i) {
	        # @Code: RULE_MULT_AFFECT
	        # @Type: PRESENTATION
	        # @Description: Pas d affectation mutiple
	        # @Caractéristiques: 
	        #   - Facilité d'analyse
	        # @Commentaires:
	        # @Restriction: 
	        # @RULENUMBER: R31
		if (!($line =~ m{\sTO\s+[\w-]+\s+OF\s+}i)) {
		    if (!($line =~ m{\sTO\s+[\w-]+\s+GO\s*TO\s+}i)) {
			Cobol::violation::violation("RU_MULT_AFFECT2", $filename,$CptLine,"Violation, Affectation multiple simple $line"); 
			$cptMultAffect++;
		    }
		}
		if ($line =~ m{\.\s*\Z}i) {
		    if ($Para_CptNiv > 0) {
# si sortie de structure previousToOffset reinitialisé
			$previousToOffset = -1
			}
		    $Para_CptNiv = 0;
		    $DansMove = 0 ;
		    Cobol::violation::violationdebug("DEBUGDEBUGPOINT", $filename,$CptLine,"POINT, $line");
                    return;
		}
	    }
            if ($multaffectpOSSIBLE == 1) {
		if ($line =~ m{^\s*(INSPECT\s|UNSTRING\s|EXIT\s|SUBTRACT\s|SET\s|CLOSE\s|OPEN\s|IF\s|WHEN\s|ELSE\s|MOVE\s|PERFORM\s|THRU\s|VARYING\s|CALL\s|EVALUATE\s|RELEASE\s|AT\s|READ\s|DISPLAY\s|WRITE\s|REWRITE\s|END-|GO\s|GO\s*TO\s|EXEC\s|ADD\s|DIVIDE\s|COMPUTE\s|INITIALIZE\s|GIVING\s|MULTIPLY\s|STRING\s|ACCEPT\s|NOT\s|\.|\()}i) { 
                    if (!($line =~ m{(\sMOVE\s+)}i)) {
			$DansMove = 0;
			Cobol::violation::violationdebug("DEBUG___IF MOVE______", $filename,$CptLine,"NEWINST $1, $line");
		    } else {
			Cobol::violation::violationdebug("DEBUG___ELSE______", $filename,$CptLine,"NEWINST $1, $line");
		    }
		} else { 
                    if (!($line =~ m{^\*})) {
			Cobol::violation::violation("RU_MULT_AFFECT", $filename,$CptLine,"Violation, Affectation multiple sur plusieurs lignes"); 
			$cptMultAffect++;
		    }
		}
		$multaffectpOSSIBLE = 0;
	    }
	    if ($line =~ m{\sTO\s+[\w-]+\s*\Z}i) {
		if ($line =~ m{\sTO\s+[\w-]+\s*\.\s*\Z}i) {
		} else {
#		    print "$filename,$CptLine:TOTOTO:" . $_;
# FLOFLO on pourrai ne pas prendre en compte les initialisation manifeste
# comme MOVE SPACE SPACES ZEROES ZERO 0 1 ou ZEROS 
		    if ($line =~ m{\sGO\s*TO\s}i) {
		    } else {
			$multaffectpOSSIBLE = 1;
			#violation3("les autres to", $filename,$CptLine,"Violation, Les autres to $_"); 
		    }
		}
	    }
	} else {
 	    Cobol::violation::violationdebug("DEBUG", $filename,$CptLine,"ELSE, $line");
	}


#########################
#il y a un . sur la ligne
#########################
	    if ($line =~ m{\.\s*\Z}i) {
                if ($Para_CptNiv > 0) {
# si sortie de structure previousToOffset reinitialisé
		    $previousToOffset = -1
		}
		$Para_CptNiv = 0;
#		TraitementPoint();
                $DansMove = 0 ;
	    Cobol::violation::violationdebug("DEBUGFIN", $filename,$CptLine,"POINT, $line");
	    }

    }

sub endMove() {
    Couples::counter_add($StructFichier,Ident::Alias_BadInitMove(),$cptBadInitMove);
    Couples::counter_add($StructFichier,Ident::Alias_MultAffect(),$cptMultAffect);
    Couples::counter_add($StructFichier,Ident::Alias_BadToAlign(),$cptBadToAlign);
    reinitMove();
}

sub reinitMove {

 $multaffectpOSSIBLE = 0;
 $previousToOffset = -1;
 $CurrentLevelMove = 0;
 $PrevLevelMove = 0;

#Compteur
 $cptBadInitMove = 0;
 $cptMultAffect = 0;
 $cptBadToAlign = 0;
}

sub reinitpara {
  $multaffectpOSSIBLE = 0;
  $Para_CptNiv = 0;
}


1;
