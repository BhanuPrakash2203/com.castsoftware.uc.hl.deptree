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

my $StructFichier;
my $filename="";

#Compteur
my $cptPD_ProhibitedKeyword = 0;
my $cptDynamicCall = 0;
my $cptTab = 0;
my $cptEntry = 0;
my $cptNextSentence = 0;


sub MotInterditFS($$) {
    my $line = shift;
    my $CptLine=shift;


	###############################
	# Mots interdit en File Section
	###############################
	if ($line =~ m{\sEXTERNAL\b}i) {
	    # @Code: EXTERNAL
	    # @Type: STATEMENT_INTERDIT
	    # @Description: Eviter la clause external pour les fichiers ou données
	    # @Caractéristiques: 
	    #   - Maintenabilité - Fiabilité
	    # @Commentaires: 
	    # @Restriction: 
	    # @RULENUMBER: R35
	    Cobol::violation::violation2("RU_NOKEY_EXTERNAL", $filename,$CptLine,"Violation, Eviter d utiliser la clause EXTERNAL");
	    
	}
	#on se debarasse des chaines de caractère
	$line =~ s{\".*\"}{};
	$line =~ s{\'.*\'}{};
	if ($line =~ m{\t}i) {
	    # @Code: PORT_NOTAB
	    # @Type: CHAR_INTERDIT
	    # @Description: Eviter les tabulation
	    # @Caractéristiques: 
	    #   - Maintenabilité
	    # @Commentaires: 
	    # @Restriction: 
	    # @RULENUMBER: Rxx
	    Cobol::violation::violation2("PORT_NOCHAR_NOTAB", $filename,$CptLine,"Violation, Eviter les tabulations");
	    $cptTab++;
	}

return;
}

sub MotInterditWS ($$$) {
    my $line = shift;
    my $CptLine=shift;


# Following code is desactivated because it produce no counter.
if (0) {
        # Nous sommes en working-storage
	###############################
	# Mots interdit en Working Section
	###############################
	if ($line =~ m{\sPOINTER\b}i) {
	    # @Code: POINTER
	    # @Type:  STATEMENT_INTERDIT DATA
	    # @Description: Eviter d utiliser POINTER
	    # @Caractéristiques: 
	    #   - Maintenabilité - Fiabilité
	    # @Commentaires: 
	    # @Restriction: 
	    # @RULENUMBER: Rxx
	    Cobol::violation::violation2("RU_NOKEY_POINTER", $filename,$CptLine,"Violation, Eviter d utiliser la clause POINTER");
	    
	}
	if ($line =~ m{\sGLOBAL\b}i) {
	    # @Code: GLOBAL
	    # @Type: STATEMENT_INTERDIT DATA
	    # @Description: Eviter la clause global pour les FLOFLO a voir fichiers ou données
	    # @Caractéristiques: 
	    #   - Maintenabilité - Fiabilité
	    # @Commentaires: 
	    # @Restriction: 
	    # @RULENUMBER: Rxx
	    Cobol::violation::violation2("RU_NOKEY_GLOBAL", $filename,$CptLine,"Violation, Eviter d utiliser la clause GLOBAL");
	    
	}
	if ($line =~ m{\s(SYNCHRONIZED|SYNC)\b}i) {
	    # @Code: SYNCHRONIZED
	    # @Type: STATEMENT_INTERDIT DATA
	    # @Description: Eviter la clause SYNCHRONIZED pour les  données
	    # @Caractéristiques: 
	    #   - Facilité d'adaptation
	    # @Commentaires: 
	    # @Restriction: 
	    # @RULENUMBER: Rxx
	    Cobol::violation::violation2("OBSKEY_SYNCHRONIZED", $filename,$CptLine,"Violation, Eviter d utiliser la clause SYNCHRONIZED");
	}
}	
	#on se debarasse des chaines de caractère
	$line =~ s{\".*\"}{};
	$line =~ s{\'.*\'}{};
	if ($line =~ m{\t}i) {
	    # @Code: PORT_NOTAB
	    # @Type: CHAR_INTERDIT
	    # @Description: Eviter les tabulation
	    # @Caractéristiques: 
	    #   - Maintenabilité
	    # @Commentaires: 
	    # @Restriction: 
	    # @RULENUMBER: Rxx
	    Cobol::violation::violation2("PORT_NOCHAR_NOTAB", $filename,$CptLine,"Violation, Eviter les tabulations");
	    $cptTab++;
	}
return;
}


sub MotInterditPD ($$$) {
    # One line of ProcDiv
    my $line = shift;
    my $CptLine=shift;
    my $NewPara=shift;

        # Nous sommes en procedure division

	    if ($line =~ m{^( ){1,4}(\S+)\s+SECTION\.\s*\Z}i) {
		# @Code: RULE_SECTION
		# @Type:  STATEMENT_INTERDIT
		# @Description: Eviter l'utisation de section
		# @Caractéristiques: 
		# @Restriction: 
		# @RULENUMBER: Rxx
		Cobol::violation::violation2("CF_NOKEY_SECTION", $filename,$CptLine,"Violation, Attention utilisation de section $2");
		$cptPD_ProhibitedKeyword++;
		return;
	    }
	    if ( ($line =~ m{\sACCEPT\s}) && !($line =~ m{FROM\s+(DAY|TIME|DATE)}i) )  {
		# @Code: ACCEPT
		# @Type: STATEMENT_INTERDIT
		# @Contexte: Client
		# @Description: L'instruction ACCEPT est interdite 
		# @Caractéristiques: 
		#   - Fiabilité
		# @Commentaires: Instruction de saisie clavier. 
		#                Peut provoquer une interruption de la chaine.
		#
		# @RULENUMBER: R2
		# @Restriction: 
		Cobol::violation::violation2("RC_NOKEY_ACCEPT", $filename,$CptLine,"Violation, Utilisation de accept");
		$cptPD_ProhibitedKeyword++;
		return;
	    }

	    if ($line =~ m{\sCORRESPONDING\b|\sCORR\b}i) {
		# @Code: CORRESPONDING
		# @Type:STATEMENT_INTERDIT
		# @Description: Option CORRESPONDING interdite dans les instructions
		# @Caractéristiques: 
		#   - Facilité d'analyse
		# @Commentaires: L'utilisation de cette clause impose des déclarations de
		#                variables homonyme pour pouvoir l'utiliser et alourdit ensuite
		#                la manipulation de ces variables avec les autres instructions.
		# @RULENUMBER: R5 
		# @Restriction: 
		Cobol::violation::violation2("RC_NOKEY_CORRESPONDING", $filename,$CptLine,"Violation, Utilisation de la clause corresponding");
		$cptPD_ProhibitedKeyword++;
		return;
	    }

	    
	    if ($line =~ m{\sNOTE\b}i) {
		# @Code: NOTE
		# @Type: STATEMENT_INTERDIT
		# @Description: instruction NOTE interdite
		# @Caractéristiques: 
		#   - Maintenabilité
		# @Commentaires: Introduit un commentaire pour l ensemble du paragraphe
		# @Commentaires: si c est la premiere instruction ou jusqu au prochain .
		# @Restriction: 
		# @RULENUMBER: R7
		Cobol::violation::violation2("NOKEY_NOTE", $filename,$CptLine,"Violation, Utilisation de l instruction NOTE");
		$cptPD_ProhibitedKeyword++;
		return;
	    }
	    if ($line =~ m{\sENTRY\s}i) {
		# @Code: ENTRY
		# @Type: STATEMENT_INTERDIT
		# @Description: instruction ENTRY interdite
		# @Caractéristiques: 
		#   - Maintenabilité
		# @Commentaires: Introduit un point d entree alternatif dans un programme
		# @Restriction: 
		# @RULENUMBER: R8
		Cobol::violation::violation2("CF_NOKEY_ENTRY", $filename,$CptLine,"Violation, Utilisation de l instruction entry");
		$cptPD_ProhibitedKeyword++;
		return;
	    }
	    if ($line =~ m{\sNEXT\s+SENTENCE\b}i) {
		# @Code: NEXT_SENTENCE
		# @Type: STATEMENT_INTERDIT
		# @Description: instruction NEXT SENTENCE interdite
		# @Caractéristiques: 
		#   - Maintenabilité
		# @Commentaires: The NEXT SENTENCE statement transfers control to the next COBOL sentence, that is, following the next period. 
		# @Commentaires: It does not transfer control to the logically next COBOL verb as occurs with the CONTINUE verb.
		# @Restriction: 
		# @RULENUMBER: R9
		Cobol::violation::violation2("CF_NOKEY_NEXT_SENTENCE", $filename,$CptLine,"Violation, Utilisation de l instruction next sentence");
		$cptPD_ProhibitedKeyword++;
		return;
	    }
	    if ($line =~ m{\sDISPLAY\s+.*\sUPON\s+CONSOLE\s}i) {
		# @Code: DISPLAY_UPON_CONSOLE
		# @Type: STATEMENT_INTERDIT
		# @Description: Eviter le DISPLAY UPON CONSOLE
		# @Caractéristiques: 
		#   - Maintenabilité
		# @Commentaires: 
		# @Restriction: 
		# @RULENUMBER: R10
		Cobol::violation::violation2("NOKEY_DISPLAY_UPON_CONSOLE", $filename,$CptLine,"Violation, Eviter le DISPLAY UPON CONSOLE");
		$cptPD_ProhibitedKeyword++;
		return;
	    }
	    if ($line =~ m{\sDISPLAY\s}i) {
		# @Code: DISPLAY
		# @Type: STATEMENT_INTERDIT
		# @Description: Eviter le DISPLAY
		# @Caractéristiques: 
		#   - Maintenabilité
		# @Commentaires: 
		# @Restriction: 
		# @RULENUMBER: Rxx
		###violation("RU_NOKEY_DISPLAY", $filename,$CptLine,"Violation, Eviter l'utilisation de DISPLAY ");
		return;
	    }
	    if ($line =~ m{\sINITIALIZE\s}i) {
		# @Code: INITIALIZE
		# @Type: STATEMENT_INTERDIT
		# @Description: L'instruction INITIALIZE est interdite
		# @Caractéristiques: 
		# @Commentaires: 
		# @RULENUMBER: Rxxx 
		# @Restriction: 
		Cobol::violation::violation2("PERF_NOKEY_INITIALIZE", $filename,$CptLine,"Violation, Eviter l instruction INITIALIZE");
		$cptPD_ProhibitedKeyword++;
		return;
	    }
	    if ($line =~ m{\sMERGE\s}i) {
		# @Code: MERGE
		# @Type: STATEMENT_INTERDIT
		# @Description: Eviter l instruction MERGE
		# @Caractéristiques: 
		#   - Maintenabilité
		# @Commentaires: 
		# @Restriction: 
		# @RULENUMBER: R11
		Cobol::violation::violation2("RC_NOKEY_MERGE", $filename,$CptLine,"Violation, Eviter l instruction merge");
		$cptPD_ProhibitedKeyword++;
		return;
	    }

	    if ($line =~ m{\sCALL\s+\w}i) {
		# @Code: PERF_NOKEY_CALL_DYN
		# @Type: STATEMENT_INTERDIT
		# @Description: Eviter l instruction CALL dynamique
		# @Caractéristiques: 
		#   - Maintenabilité
		# @Commentaires: 
		# @Restriction: 
		# @RULENUMBER: R11
		Cobol::violation::violation2("PERF_NOKEY_CALL_DYN", $filename,$CptLine,"Violation, Eviter l utilisation du call dynamique");
		$cptDynamicCall++;
		return;
	    }

	#on se debarasse des chaines de caractère
	$line =~ s{\".*\"}{};
	$line =~ s{\'.*\'}{};
	if ($line =~ m{\t}i) {
	    # @Code: PORT_NOTAB
	    # @Type: CHAR_INTERDIT
	    # @Description: Eviter les tabulation
	    # @Caractéristiques: 
	    #   - Maintenabilité
	    # @Commentaires: 
	    # @Restriction: 
	    # @RULENUMBER: Rxx
	    Cobol::violation::violation2("PORT_NOCHAR_NOTAB", $filename,$CptLine,"Violation, Eviter les tabulations");
	    $cptTab++;
	}
	

    return;
	
}

sub endMotInterdit() {
    Couples::counter_add($StructFichier,Ident::Alias_PD_ProhibitedKeyword(),$cptPD_ProhibitedKeyword);
    Couples::counter_add($StructFichier,Ident::Alias_DynamicCall(),$cptDynamicCall);
    Couples::counter_add($StructFichier,Ident::Alias_Tab(),$cptTab);
    reinitMotInterdit();
    return;
}

sub reinitMotInterdit {
 $cptPD_ProhibitedKeyword = 0;
 $cptDynamicCall = 0;
 $cptTab = 0;
 $cptEntry = 0;
 $cptNextSentence = 0;
}

sub initMotInterdit($$) {
  $StructFichier=shift;
  $filename=shift;
  reinitMotInterdit();
}

1;
