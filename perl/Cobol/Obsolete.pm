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

my $StructFichier = ();
my $filename = "";

#Compteur
my $cptObsoleteKeywordID = 0;
my $cptObsoleteKeywordED = 0;
my $cptObsoleteKeywordIOS = 0;
my $cptObsoleteKeywordFS = 0;
my $cptObsoleteKeywordWS = 0;
my $cptObsoleteKeywordPD = 0;

sub MotObsoleteID ($$$) {
    my $line = shift;
    my $CptLine=shift;


#    print "$FICHIER   --" . $StructFichier->{"Dat_IdentDivLine"} . " -- $CptLine --\n";

	if ($line =~ m{^( ){1,4}(AUTHOR|INSTALLATION|DATE-WRITTEN|DATE-COMPILED|SECURITY)\s*\.}i) {
	    my $name = $2; 
	    # @Type: STATEMENT_OBSOLETE
	    # @Description: Paragraphe AUTHOR... obsol�te en DATA DIVISION
	    # @Caract�ristiques: 
	    #   - Portabilit�
	    # @Commentaires: Ces paragraphes sont destin�s � disparaitre dans le Norme COBOL 1995
	    # @RULENUMBER: Rx
	    # @Restriction: 
	    Cobol::violation::violation("OBSKEY_AUTHOR", $filename,$CptLine,"Violation, Paragraphe $name obsol�te en DATA DIVISION ");
	    $cptObsoleteKeywordID++;
	    return;
	}
}

sub MotObsoleteED ($$) {
    my $line = shift;
    my $CptLine=shift;
    $CptLine = $StructFichier->{"Dat_EnvDivLine"} - 1 ;

	if ($line =~ m{\bMEMORY\s+SIZE\b}i) {
	    # @Type: STATEMENT_OBSOLETE
	    # @Description: Clause MEMORY SIZE du paragraphe OBJECT-COMPUTER obsol�te
	    # @Caract�ristiques: 
	    #   - Portabilit�
	    # @Commentaires: Cette clause est destin�e � disparaitre dans le Norme COBOL 1995
	    # @RULENUMBER: Rx
	    # @Restriction: 
	    Cobol::violation::violation("OBSKEY_MEMSIZE", $filename,$CptLine,"Violation, Clause MEMORY SIZE du paragraphe OBJECT-COMPUTER obsol�te");
	    $cptObsoleteKeywordED++;
	    return;
	}
}

sub MotObsoleteIOS ($$) {
    my $line = shift;
    my $CptLine=shift;


	if ($line =~ m{\bRERUN\b}i) {
	    # @Type: STATEMENT_OBSOLETE
	    # @Description: Clause RERUN du paragraphe I-O-CONTROL obsol�te
	    # @Caract�ristiques: 
	    #   - Portabilit�
	    # @Commentaires: Cette clause est destin�e � disparaitre dans le Norme COBOL 1995
	    # @RULENUMBER: Rx
	    # @Restriction: 
	    Cobol::violation::violation("OBSKEY_RERUN", $filename,$CptLine,"Violation, Clause RERUN du paragraphe I-O-CONTROL obsol�te");
	    $cptObsoleteKeywordIOS++;
	    return;
	}
	if ($line =~ m{\bMULTIPLE\s+FILE\s+TAPE\b}i) {
	    # @Type: STATEMENT_OBSOLETE
	    # @Description: Clause MUTIPLE FILE TAPE du paragraphe I-O-CONTROL obsol�te
	    # @Caract�ristiques: 
	    #   - Portabilit�
	    # @Commentaires: Cette clause est destin�e � disparaitre dans le Norme COBOL 1995
	    # @RULENUMBER: Rx
	    # @Restriction: 
	    Cobol::violation::violation("OBSKEY_MULTFILETAPE", $filename,$CptLine,"Violation, Clause MUTIPLE FILE TAPE du paragraphe I-O-CONTROL obsol�te");
	    $cptObsoleteKeywordIOS++;
	    return;
	}
}




sub MotObsoleteFS ($$) {
    my $line = shift;
    my $CptLine=shift;


	if ($line =~ m{\bLABEL\s+RECORD\b}i) {
	    # @Type: STATEMENT_OBSOLETE
	    # @Description: Clause LABEL RECORD de la FILE SECTION obsol�te
	    # @Caract�ristiques: 
	    #   - Portabilit�
	    # @Commentaires: Cette clause est destin�e � disparaitre dans le Norme COBOL 1995
	    # @RULENUMBER: Rx
	    # @Restriction: 
	    Cobol::violation::violation("OBSKEY_LABEL_RECORD", $filename,$CptLine,"Violation, Clause LABEL RECORD de la FILE SECTION obsol�te");
	    $cptObsoleteKeywordFS++;
	    return;
	}
	if ($line =~ m{\bVALUE\s+OF\b}i) {
	    # @Type: STATEMENT_OBSOLETE
	    # @Description: Clause VALUE OF de la FILE SECTION obsol�te
	    # @Caract�ristiques: 
	    #   - Portabilit�
	    # @Commentaires: Cette clause est destin�e � disparaitre dans le Norme COBOL 1995
	    # @RULENUMBER: Rx
	    # @Restriction: 
	    Cobol::violation::violation("OBSKEY_VALUE_OF", $filename,$CptLine,"Violation, Clause VALUE OF de la FILE SECTION obsol�te");
	    $cptObsoleteKeywordFS++;
	    return;
	}
	if ($line =~ m{\bDATA\s+RECORD\b}i) {
	    # @Type: STATEMENT_OBSOLETE
	    # @Description: Clause DATA RECORD de la FILE SECTION obsol�te
	    # @Caract�ristiques: 
	    #   - Portabilit�
	    # @Commentaires: Cette clause est destin�e � disparaitre dans le Norme COBOL 1995
	    # @RULENUMBER: Rx
	    # @Restriction: 
	    Cobol::violation::violation("OBSKEY_DATA_RECORD", $filename,$CptLine,"Violation, Clause DATA RECORD de la FILE SECTION obsol�te");
	    $cptObsoleteKeywordFS++;
	    return;
	}
}

sub MotObsoleteWS($$) {
        my $line = shift;
	my $CptLine=shift;

	if ($line =~ m{\sALL\s+\'\d+\'}i) {
	    # @Code: ALL_LITNUM
	    # @Type: STATEMENT_OBSOLETE
	    # @Description: La clause ALL litt�ral num�rique est obsol�te
	    # @Caract�ristiques: 
	    #   - Portabilit�
	    # @Commentaires: Cette instruction est destin�e � disparaitre dans le Norme COBOL 1995
	    # @RULENUMBER: Rxxx 
	    # @Restriction: 
	    Cobol::violation::violation("OBSKEY_ALL_LITNUM", $filename,$CptLine,"Violation � v�rifier, L instruction ALL litt�ral pour une donn�e num�rique est obsol�te");
	    $cptObsoleteKeywordWS++;
	    return;
	}
}


sub MotObsoletePD ($$$) {
    # One line of ProcDiv
    my $line = shift;
    my $CptLine=shift;
    my $NewPara=shift;

        # Nous sommes en procedure division
	    if ($line =~ m{\sALTER\b}i) {
		# @Code: ALTER
		# @Type: STATEMENT_OBSOLETE
		# @Description: L'instruction ALTER est obsol�te
		# @Caract�ristiques: 
		#   - Fiabilit�, Facilit� d'analyse
		# @Commentaires: Construction � risque. Cette instruction permet de modifier dynamiquement la destination d'un GOTO. Cette clause est destin�e � disparaitre dans le Norme COBOL 1995.
		# @RULENUMBER: R4 
		Cobol::violation::violation("OBSKEY_ALTER", $filename,$CptLine,"Violation, L instruction ALTER est obsol�te");
		$cptObsoleteKeywordPD++;
                return;
	    }
	    if ($line =~ m{\sRESERVED\b}i) {
		# @Code: RESERVED
		# @Type: STATEMENT_OBSOLETE
		# @Description: La clause RESERVED de l'instruction OPEN est obsol�te
		# @Caract�ristiques: 
		#   - Portabilit�
		# @Commentaires: Cette clause est destin�e � disparaitre dans le Norme COBOL 1995.
		# @RULENUMBER: R4 
		Cobol::violation::violation("OBSKEY_RESERVED", $filename,$CptLine,"Violation, La clause RESERVED de l instruction OPEN est obsol�te");
		$cptObsoleteKeywordPD++;
                return;
	    }
	    if ($line =~ m{\sSTOP\s+(\w|\d)}i) {
		# @Code: STOP_LIT
		# @Type: STATEMENT_OBSOLETE
		# @Description: L'instruction STOP litt�ral est obsol�te
		# @Caract�ristiques: 
		#   - Portabilit�
		# @Commentaires: Cette instruction est destin�e � disparaitre dans le Norme COBOL 1995
		# @RULENUMBER: R4 
		# @Restriction: 
                return if ($line =~ m{\sSTOP\s+RUN}i);
		Cobol::violation::violation("OBSKEY_STOP_LIT", $filename,$CptLine,"Violation, L instruction STOP litt�ral est obsol�te");
		$cptObsoleteKeywordPD++;
                return;
	    }


	  if ($line =~ m{\sAFTER\s+POSITIONING\b}i) {
	      # @Code: AFTER_POSITIONING
	      # @Type: STATEMENT_OBSOLETE
	      # @Description: Option AFTER POSITIONNING de l'instruction WRITE interdite
	      # @Caract�ristiques: 
	      #   - Portabilit�
	      # @Commentaires: Cette clause semble avoir �t� remplac�e par AFTER ADVANCING
	      # @RULENUMBER: R3
	      # @Restriction: 
	      Cobol::violation::violation("OBSKEY2_AFTER_POSITIONING", $filename,$CptLine,"Violation, Utilisation de after positioning de l instruction WRITE");
	      $cptObsoleteKeywordPD++;
              return;
	  }

	  if ($line =~ m{\sENTER\b}i) {
	      # @Code: ENTER
	      # @Type: STATEMENT_OBSOLETE
	      # @Description: L'instruction ENTER est obsol�te
	      # @Caract�ristiques: 
	      #   - Fiabilit�, Facilit� d'analyse
	      # @Commentaires: Construction � risque. 
	      # @RULENUMBER: Rxxx 
	      # @Restriction: A priori obsol�te
	      Cobol::violation::violation("OBSKEY2_ENTER", $filename,$CptLine,"Violation, Utilisation de enter");
	      $cptObsoleteKeywordPD++;
              return;
	  }

	  if ($line =~ m{\sTRANSFORM\b}i) {
	      # @Code: TRANSFORM
	      # @Type: STATEMENT_OBSOLETE
	      # @Description: L'instruction TRANSFORM est interdite
	      # @Caract�ristiques: 
	      #   - Fiabilit�, Facilit� d'analyse
	      # @Commentaires: Construction � risque. 
	      # @RULENUMBER: Rxxx 
	      # @Restriction: A priori obsol�te
	      Cobol::violation::violation("OBSKEY2_TRANSFORM", $filename,$CptLine,"Violation, Utilisation de tranform");

	      $cptObsoleteKeywordPD++;
              return;
	  }

	  if ($line =~ m{\bWITH\s+(DISP|POSITIONNING)\b}i) {
	      # @Code: DISP
	      # @Type: STATEMENT_OBSOLETE
	      # @Description: Options DISP de l'instruction CLOSE interdite
	      # @Caract�ristiques: 
	      #   - Portabilit�
	      # @Commentaires: Portabilit� 
              # @RULENUMBER: R6
	      # @Restriction: 
	      Cobol::violation::violation("OBSKEY2_DISP_POSITIONNING", $filename,$CptLine,"Violation, Utilisation de la clause WITH DISP/POSITIONNING de l instruction CLOSE");

	      $cptObsoleteKeywordPD++;
              return;
	  }
	  if ($line =~ m{\sALL\s+\'\d+\'}i) {
		# @Code: ALL_LITNUM
		# @Type: STATEMENT_OBSOLETE
		# @Description: La clause ALL litt�ral num�rique est obsol�te
		# @Caract�ristiques: 
		#   - Portabilit�
		# @Commentaires: Cette instruction est destin�e � disparaitre dans le Norme COBOL 1995
		# @RULENUMBER: Rxxx 
		# @Restriction: 
		Cobol::violation::violation("OBSKEY_ALL_LITNUM", $filename,$CptLine,"Violation � v�rifier, L instruction ALL litt�ral pour une donn�e num�rique est obsol�te");

		$cptObsoleteKeywordPD++;
                return;
	    }
}


sub endMotObsolete() {

    Couples::counter_add($StructFichier,Ident::Alias_ObsoleteKeywordID(),$cptObsoleteKeywordID);
    Couples::counter_add($StructFichier,Ident::Alias_ObsoleteKeywordED(),$cptObsoleteKeywordED);
    Couples::counter_add($StructFichier,Ident::Alias_ObsoleteKeywordIOS(),$cptObsoleteKeywordIOS);
    Couples::counter_add($StructFichier,Ident::Alias_ObsoleteKeywordFS(),$cptObsoleteKeywordFS);
    Couples::counter_add($StructFichier,Ident::Alias_ObsoleteKeywordWS(),$cptObsoleteKeywordWS);
    Couples::counter_add($StructFichier,Ident::Alias_ObsoleteKeywordPD(),$cptObsoleteKeywordPD);
    reinitObsolete();
}

sub reinitObsolete()
{
#Compteur
 $cptObsoleteKeywordID = 0;
 $cptObsoleteKeywordED = 0;
 $cptObsoleteKeywordIOS = 0;
 $cptObsoleteKeywordFS = 0;
 $cptObsoleteKeywordWS = 0;
 $cptObsoleteKeywordPD = 0;
}

sub initObsolete($$) {
 $StructFichier=shift;
 $filename=shift;
 reinitObsolete();
}

1;
