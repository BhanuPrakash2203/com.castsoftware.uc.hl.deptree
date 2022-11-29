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

my $Zone1 = "No";



sub CopyInclude {
    my $filename=shift;
    $FICHIER= $filename;
    my $CptLine =0;
    my $CurrentLine ="";
#    print "Analyse de $filename\n";
    open (FILEX, "<$filename") || die "CopyInclude Unable to read  \"$filename\"\n";
    while (<FILEX>) {
	s/\r//g;
        # comptage des lignes
	$CptLine++;
        if (m{\A\s*\Z}) {
         #ligne blanche
	    next;
	}
        #  lignes de commentaire ou debug
        if (m{\A\S}) {
	    next;
	}
	if (m{^( ){2,4}(COPY|IF|AND|SET|MOVE|DIVIDE|READ|ADD|WRITE|MULTIPLY|PERFORM|OPEN|CLOSE|WHEN|EVALUATE|EXEC|INITIALIZE|GO\s*TO)\s}i || m{^( ){2,4}(END-)}i) {
	    # on decale les instructions pour ne pas perturber la suite
	    $_ =~ s{^ }{    };
		
	}

        # détermination des zones d'un programme Cobol
	if (m{^( ){1,4}IDENTIFICATION\s+DIVISION.*\Z}i) {
	    $Zone1 = "Ident";
            next;
	}
	if (m{^( ){1,4}ENVIRONMENT\s+DIVISION.*\Z}i) {
	    $Zone1 = "Envir";
            next;
	}
	if (m{^( ){1,4}FILE-CONTROL.*\Z}i) {
	    $Zone1 = "FileControl";
            next;
	}
	if (m{^( ){1,4}I-O-CONTROL.*\Z}i) {
	    $Zone1 = "IOControl";
            next;
	}
	if (m{^( ){1,4}DATA\s+DIVISION.*\Z}i) {
	    $Zone1 = "Data";
            next;
	}
	if (m{^( ){1,4}FILE\s+SECTION.*\Z}i) {
	    $Zone1 = "Filesection";
            next;
	}
	if (m{^( ){1,4}WORKING-STORAGE\s+SECTION.*\Z}i) {
	    $Zone1 = "Working";
            next;

	}
	if (m{^( ){1,4}LINKAGE\s+SECTION.*\Z}i) {
	    $Zone1 = "Linkage";
            next;
	}
	if (m{^( ){1,4}PROCEDURE\s+DIVISION.*\Z}i) {
	    $Zone1 = "Procedure";
            next;
	}
	$CurrentLine = $_;
        #Suivant le type de Zone on peux compter des objets differents
        # Nous sommes en Identification-division
	if ($Zone1 eq "Ident") {
	}
	if ($Zone1 eq "Envir") {
	}
	if ($Zone1 eq "IOControl") {
	}
        # Nous sommes en FILE-CONTROL
	if ($Zone1 eq "FileControl") {
	    if ($CurrentLine =~ m{^\s+COPY\s+(.*)}i) {
                my $copyname = $1;
                $copyname =~ s{ .*}{};
                $copyname =~ s{\.}{};
                $copyname =~ s{\s}{}g;
#		print "FFF  $copyname\n";
		CheckCopy($copyname,$filename,$CptLine,"D");
		if (!( $copyname=~/^CP-SELECT-/ ) ) {
		    # @Code: SG_COPY_NAME
		    # @Type: NAMING DATA
		    # @Description: Nommage des clauses COPY

		    # @RULENUMBER: R23
	       Cobol::violation::violationavoir("NAMING_FC_COPYNAME", $FICHIER,$CptLine,"Violation, Nommage errone d une clause copy $copyname en File control. ");
		}
	    }
	    if ($CurrentLine =~ m{^\s+EXEC\s+SQL\s+INCLUDE\s+(\S+)\s+END-}i) {
                my $includename = $1;
                $includename =~ s{ .*}{};
                $includename =~ s{\.}{};
                $includename =~ s{\s}{}g;
		Checkinclude($includename,$filename,$CptLine);
	    }
	}

        # Nous sommes en File section
	if ($Zone1 eq "Filesection") {
	    if ($CurrentLine =~ m{^\s+COPY\s+(.*)}i) {
                my $copyname = $1;
                $copyname =~ s{ .*}{};
                $copyname =~ s{\.}{};
                $copyname =~ s{\s}{}g;
#                print $copyname . " gfgfdgf $filename, $CptLine\n";
		CheckCopy($copyname,$filename,$CptLine,"D");
		if (!( $copyname=~/^CP-ENR-/ ) ) {
		    # @Code: FS_COPY_NAME
		    # @Type: NAMING DATA
		    # @Description: Nommage des clauses COPY

		    # @RULENUMBER: R23
	       Cobol::violation::violationavoir("NAMING_FS_COPYNAME", $FICHIER,$CptLine,"Violation, Nommage errone d une clause copy $copyname en File Section");
		}

	    }

 	    if ($CurrentLine =~ m{^\s+EXEC\s+SQL\s+INCLUDE\s+(\S+)\s+END-}i) {
		my $includename = $1;
#		$includename =~ s{.*}{};
		$includename =~ s{\.}{};
                $includename =~ s{\s}{}g;
		Checkinclude($includename,$filename,$CptLine);
 	    }
	}

        # Nous sommes en working-storage
	if ($Zone1 eq "Working") {
	    if ($CurrentLine =~ m{^\s+COPY\s+(.*)}i) {
                my $copyname = $1;
                $copyname =~ s{ .*}{};
                $copyname =~ s{\.}{};
                $copyname =~ s{\s}{}g;
#		print "FFF  $copyname\n";
		CheckCopy($copyname,$filename,$CptLine,"D");

		if (!(( $copyname=~/^CP-WSS-/ ) || ( $copyname=~/^CP-TAB-/ ) )) {
		    # @Code: SG_COPY_NAME
		    # @Type: DATA
		    # @Description: Nommage des clauses COPY

		    # @RULENUMBER: R23
	       Cobol::violation::violationavoir("NAMING_WS_COPYNAME", $FICHIER,$CptLine,"Violation, Nommage errone d une clause copy $copyname en Working Storage. ");
		}
	    }
	    if ($CurrentLine =~ m{^\s+EXEC\s+SQL\s+INCLUDE\s+(\S+)\s+END-}i) {
                my $includename = $1;
                $includename =~ s{ .*}{};
                $includename =~ s{\.}{};
                $includename =~ s{\s}{}g;
		Checkinclude($includename,$filename,$CptLine);
	    }
	} #Fin working-storage

        # Nous sommes en Linkage
	if ($Zone1 eq "Linkage") {

	} # fin Linkage


        # Nous sommes en procedure division
	if ($Zone1 eq "Procedure") {
#	    print "$filename:$CptLine:DANSPRO" . $CurrentLine;
	    if ($CurrentLine =~ m{^\s+COPY\s+(.*)}i) {
		$Pd_CptCopy++;
                my $copyname = $1;
                $copyname =~ s{ .*}{};
                $copyname =~ s{\.}{};
                $copyname =~ s{\s}{}g;
		CheckCopy($copyname,$filename,$CptLine,"P");

		if (!( $copyname=~/^CP-PRO-/ ) ) {
		    # @Code: SG_COPY_NAME
		    # @Type: DATA
		    # @Description: Nommage des clauses COPY

		    # @RULENUMBER: R23
	       Cobol::violation::violationavoir("NAMING_PD_COPYNAME", $FICHIER,$CptLine,"Violation, Nommage errone d une clause copy $copyname en Procedure division. ");
		}
	    }
	    if ($CurrentLine =~ m{^\s+EXEC\s+SQL\s+INCLUDE\s+(\S+)\s+END-}i) {
                my $includename = $1;
                $includename =~ s{ .*}{};
                $includename =~ s{\.}{};
                $includename =~ s{\s}{}g;
		Checkinclude($includename,$filename,$CptLine);
	    }
	} # Fin procedure division

    } # fin boucle
	
    close(FILEX);

	
}






sub CheckCopy {
     my($filename, $Callingfilename, $CallingLine, $Type)=(@_);
    $FICHIER= "COPALL/". $filename;
    my $CptLineCopy = 0;    
#    print "Analyse du COPY $FICHIER\n";
    if (-e "$FICHIER"){
#    print "$FICHIER File exists \n";
	open (FILE2, "<$FICHIER") || die "ATTENTION::: Fichier \"$FICHIER\" n existe pas\n";
	while (<FILE2>) {
	    s/\r//g;
	    # comptage des lignes
	    $CptLineCopy++;
	    if (m{\A\s*\Z}) {
		#ligne blanche
		next;
	    }
	    #  lignes de commentaire ou debug
	    if (m{\A\S}) {
		next;
	    } 
	    if (m{^\s+COPY\s+(.*)}i) {
		Cobol::violation::violation("PORT_COPY_IMBRIC", $Callingfilename,$CallingLine,"Violation, $FICHIER,$CptLineCopy, clause copy $copyname imbriquée. ");
	    }
	    
	} # fin boucle
	
	close(FILE2);
#print "COPY:$FICHIER\n";
	if ($Type eq "D"){ 
	    &PictureIndent($FICHIER,0,72);
	    &ValueIndent($FICHIER,0,72);
	    &ContigusLevel($FICHIER,0,72);
	    &MotInterdit($FICHIER,"COP","DATA");
	    &Obsolete($FICHIER,"COP","DATA");
	    &Working($FICHIER,"COP","DATA");
# FileSection.pm, Ident.pm  sans interet
	} else {
	    &MotInterdit($FICHIER,"COP","PROC");
	    &PresClause($FICHIER,"COP","PROC");
	    &AlignVerb($FICHIER,"COP","PROC");
	    &CmplxCond($FICHIER);
	    &Compute($FICHIER,"COP","PROC");
#	    print "====================================ConstantLi:$FICHIER\n";
	    &ConstantLit($FICHIER,"COP","PROC");
	    &Obsolete($FICHIER,"COP","PROC");
#	    print "====================================MOVE:$FICHIER\n";
      &Move($FICHIER,"COP","PROC");
#	    print "====================================MOVE:$FICHIER\n";
      &MultInst($FICHIER,"COP","PROC");
#	    print "====================================MOVE:$FICHIER\n";
      &Evaluate($FICHIER,"COP","PROC");
##	    print "====================================GOTO:$FICHIER\n";
      &Goto($FICHIER,"COP","PROC");
#	    print "====================================CHECKSQL:$FICHIER\n";
      &CheckSQL($FICHIER,"COP","PROC");
#	    print "====================================FIN DES COPY:$FICHIER\n";
# Pour fonctionIntegree.pm, faut voir
	}
	
	&CodeComment($FICHIER,0,72);
#L'appel de fichier.pm, Var.pm, ThruParaExit et CodeMort n'a pas de sens pour les COPY.
#	    print "====================================FIN DES COPY:$FICHIER\n";
    } else {
	Cobol::violation::violation2("RC_NOCOPYFILE", $Callingfilename,$CallingLine,"Violation, Fichier copy <<$FICHIER>> inexistant. ");
    }

	
}

sub Checkinclude {
    my($filename, $Callingfilename, $CallingLine)=(@_);

    $FICHIER= "COP/" . $filename;
    my $CptLineCopy = 0;    
#    print "Analyse de $filename\n";
    if (-e "$FICHIER"){
#    print "$FICHIER File exists \n";
    open (FILE3, "<$FICHIER") || die "ATTENTION::: Fichier \"$FICHIER\" n existe pas\n";
    while (<FILE3>) {
	s/\r//g;
        # comptage des lignes
	$CptLineCopy++;
        if (m{\A\s*\Z}) {
         #ligne blanche
	    next;
	}
        #  lignes de commentaire ou debug
        if (m{\A\S}) {
	    next;
	} 
	if (m{^\s+COPY\s+(.*)}i) {
	    Cobol::violation::violation("PORT_COPY_IMBRIC", $Callingfilename,$CallingLine,"Violation, $FICHIER,$CptLineCopy clause copy $copyname imbriquée. ");
	}

    } # fin boucle
	
    close(FILE3);

    } else {
	Cobol::violation::violation2("RC_NOINCLUDEFILE", $Callingfilename,$CallingLine,"Violation, Fichier inclus $FICHIER inexistant. ");

    }

	
}




1;
