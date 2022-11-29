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
#
# Liste des violations:
# violation("FD_NOT_EXIST",$filename,$CptLine,"Violation,Le fichier $CurrentFichier n'est pas déclaré");
# violation("ORGA_OPENMULT",$filename,$CptLine,"Violation, $CurrentPara ,Fichier $mot ouvert plusieurs fois" . $_);
# violation("ORGA_CLOSEMULT",$filename,$CptLine,"Violation, $CurrentPara ,Fichier $mot fermé plusieurs fois" . $_);
# violation("NO_INVALID_KEY",$filename,$CptLine,"Violation,Pas de clause invalid key pour la lecture $CurrentReadLine du fichier $CurrentFichier qui est déclaré indexed ");    
# violation("RU_NO_CLOSEOPEN",$filename,$t->{$k}->{'ligne'},"Violation, Le fichier $k n\'est jamais ni ouvert ni fermé");
# violation("RU_NO_OPEN",$filename,$t->{$k}->{'ligne'},"Violation, Le fichier $k n\'est jamais ouvert mais est fermé");
# violation("RU_NO_CLOSE",$filename,$t->{$k}->{'ligne'},"Violation, Le fichier $k n\'est jamais fermé mais est ouvert");
# violation("RC_EQ_OPEN_CLOSE",$filename,$t->{$k}->{'ligne'},"Violation, Autant d'opération d'ouverture($t->{$k}->{'open'}) que de fermeture($t->{$k}->{'close'}) pour le fichier $k ");


# violationdebug("DUP_NOM_PARA",$FICHIER,$CptLine,"Violation, Paragraphe de même nom $CurrentPara ligne $TabPara{$CurrentPara} " );
# violationdebug("OPEN",$filename,$CptLine,"Debug, $CurrentPara ,$fichier" . $_);
# violationdebug("CLOSE",$filename,$CptLine,"Debug, $CurrentPara ,$fichier" . $_);
# violationdebug("FILE_INDEXED",$filename,$CptLine,"Information,Le fichier $CurrentFichier est déclaré indexed");
# violationdebug("FILE_INDEXED",$filename,$CptLine,"Information,Le fichier $CurrentFichier est déclaré pas indexed");
# violationdebug("FILE_NOT_EXIST",$filename,$CptLine,"Information,Le fichier $CurrentFichier n'est pas déclaré");
# violationdebug("DEBUG_OPEN_CLOSE",$filename,$t->{$k}->{'ligne'},"DEBUG, Autant d'opération d'ouverture($t->{$k}->{'open'}) que de fermeture($t->{$k}->{'close'}) pour le fichier $k ");

use Cobol::violation;

use Cobol::CobolCommon;

my $IDENTIFIER = Cobol::CobolCommon::get_IDENTIFER_PATTERN();

#Compteur
my $cptSeriousFilePb = 0;
my $cptMissingInvalidKey = 0;
my $cptCuriousFilePb = 0;

#FLOFLO A FAIRE
#Ordre WRITE, START DELETE
my %TabFichier2;
my $CptLine;
my $CurrentPara;
my $CurrentInst;
my $PrevOpen = "";
my $PrevClose = "";

my $WaitForNextLine = 0;
my $CurrentFichier;

sub initFichier($$) {
  ($StructFichier,$filename) = @_;
  #Compteur
  $cptSeriousFilePb = 0;
  $cptMissingInvalidKey = 0;
  $cptCuriousFilePb = 0;

  #FLOFLO A FAIRE
  #Ordre WRITE, START DELETE
  $CurrentPara = "";
  $CurrentInst = "";
  %TabFichier2 = ();
  $PrevOpen = "";
  $PrevClose = "";

  $WaitForNextLine = 0;
  $CurrentFichier = 0;
}

sub declareMissingInOutSection() {
  		Cobol::violation::violation("FD_NOIO",$filename,$StructFichier->{"Dat_EnvDivLine"},"Le fichier $filename ne contient pas de INPUT-OUTPUT SECTION.");
	    $cptSeriousFilePb++;
}

sub FichierIOS($$) {
    my $line = shift;
    my $CptLine=shift;

            if ($WaitForNextLine == 1) {
		if ($line =~ m{\s+ORGANIZATION\s+INDEXED}i) {
		    $TabFichier2{$CurrentFichier}->{'Organisation'} = "i";
#TRACE			       print "LIGNE orga ==== $CptLine " . $line ;
		    Cobol::violation::violationInfo("FD_INDEXED",$filename,$CptLine,"Information, Le fichier $CurrentFichier est sequentiel indexé");
#    print "Nb element1: " . (scalar keys %TabFichier2) . "\n";
		}
	    }

            if ($line =~ m{\s+SELECT\s+($IDENTIFIER)}i) {
                
                $CurrentFichier = uc($1);
#		print "filename = <<" . $CurrentFichier . ">>\n";
		my %DonneesFichier = ();
		$TabFichier2{$CurrentFichier} = \%DonneesFichier;
		$TabFichier2{$CurrentFichier}->{'ligne'} = $CptLine;
		$TabFichier2{$CurrentFichier}->{'open'} = 0;
		$TabFichier2{$CurrentFichier}->{'close'} = 0;
		$TabFichier2{$CurrentFichier}->{'read'} = 0;
		$TabFichier2{$CurrentFichier}->{'sort'} = 0;
		$TabFichier2{$CurrentFichier}->{'write'} = 0;
		$TabFichier2{$CurrentFichier}->{'Organisation'} = "";
		$TabFichier2{$CurrentFichier}->{'SDFD'} = "";
#                print $filename . "    HHHHHH\n";

                if ($line =~ m{\s+SELECT.*\.}i) { # pas de description complémentaire
		    $WaitForNextLine = 0;
                    return;
		} else {
                    $WaitForNextLine = 1;
                    return;
		}
	    }
}



sub declareMissingFileSection() {
  		Cobol::violation::violation("FD_NOFD",$filename,$StructFichier->{"Dat_DataDivLine"},"Le fichier $filename ne contient pas de FILE SECTION.");
	    $cptSeriousFilePb++;
}


###################################################################
# WARNING : function FichierIOS must have been called before !!!!
###################################################################

sub FichierFS($$) {
    my $line = shift;
    my $CptLine=shift;

	if ($line =~ m{^\s+FD\s+([\w-]+)}i) {
	    my $CurrentFichier = uc($1);
	    if (exists $TabFichier2{$CurrentFichier}) {
		
		$TabFichier2{$CurrentFichier}->{'SDFD'} = "FD";
	    } else {
		
		    Cobol::violation::violation("FD_NOT_EXIST",$filename,$CptLine,"Violation,Le fichier <<$CurrentFichier>> n'est pas déclaré");
		$cptSeriousFilePb++;
	    }
	}
	if ($line =~ m{^\s+SD\s+([\w-]+)}i) {
	    my $CurrentFichier = uc($1);
	    $CurrentFichier =~ s{\.}{};
	    if (exists $TabFichier2{$CurrentFichier}) {
 		$TabFichier2{$CurrentFichier}->{'SDFD'} = "SD";
	    } else {
		
		    Cobol::violation::violation("SD_NOT_EXIST",$filename,$CptLine,"Violation,Le fichier <<$CurrentFichier>> n'est pas déclaré");
		$cptSeriousFilePb++;
	    }
	}
}



sub FichierPD($$$) {
    # One line of ProcDiv
    my $line = shift;
    my $CptLine=shift;
    my $NewPara=shift;


    my $InvalidKey = 0;
    my $CheckIndexed = 0;
    my $CurrentFichier2 = "";
    my $CurrentReadLine;

	if (defined $newPara) {
          $CurrentPara = $newPara;
        }

	  if ($line =~ m{\sOPEN\s+(EXTEND|INPUT|OUTPUT|I-O)\s+([\w-]+)}i) {
	      # @Code: GRP_OPEN
	      # @Type: CODE
	      # @Description: Regrouper les OPEN dans un seul paragraphe
	      # @Caractéristiques: 
	      #   - Maintenabilité
	      # @Commentaires: 
	      # @Restriction: 
	      # @RULENUMBER: R24
              if ( ! ($PrevOpen eq "") && !($PrevOpen eq $CurrentPara) ) {
                
		      Cobol::violation::violation("ORGA_GRP_OPEN", $filename,$CptLine,"Violation,Regrouper les OPEN dans un seul paragraphe");
                  #Pas de comptage
	      }
              $PrevOpen = $CurrentPara;
	  }
	  if ($line =~ m{\sCLOSE\s+([\w-]+)}i) {
	      # @Code: GRP_CLOSE
	      # @Type: CODE
	      # @Description: Regrouper les CLOSE dans un seul paragraphe
	      # @Caractéristiques: 
	      #   - Maintenabilité
	      # @Commentaires: 
	      # @Restriction: 
	      # @RULENUMBER: R25
              if ( ! ($PrevClose eq "") && !($PrevClose eq $CurrentPara) ) {
                
		      Cobol::violation::violation("ORGA_GRP_CLOSE", $filename,$CptLine,"Violation,Regrouper les CLOSE dans un seul paragraphe");
                  #Pas de comptage
	      }
              $PrevClose = $CurrentPara;
	  }



	    if ($line =~ m{^\s+(SET|MOVE|DIVIDE|READ|ADD|WRITE|MULTIPLY|PERFORM|OPEN|CLOSE|WHEN|EVALUATE|EXEC|INITIALIZE|IF|GO|SORT|MERGE)\s}i) {
		$CurrentInst= uc($1);
	    }
	    if ($line =~ m{^\s+(END-\w+)}i) {
		$CurrentInst= uc($1);
	    }

            if ( $CurrentInst eq "OPEN") {
		my $line2 = uc($line);
#                print "$filename:$CptLine:JE SUIS DANS OPEN:$line2";
                $line2 =~ s{OPEN}{}i;
                $line2 =~ s{INPUT}{}i;
                $line2 =~ s{OUTPUT}{}i;
                $line2 =~ s{EXTEND}{}i;
#                print "$filename:$CptLine:JE SUIS DANS OPEN2:$line2";
                CheckOpen($line2,$filename);
	    }


            if ( $CurrentInst eq "CLOSE") {
		my $line2 = uc($line);
#                print "$filename:$CptLine:JE SUIS DANS CLOSE:$line2";
                $line2 =~ s{CLOSE}{}i;
                CheckClose($line2,$filename);
	    }

            if ( $CurrentInst eq "SORT") {
		my $line2 = uc($line);
#                print "$filename:$CptLine:JE SUIS DANS SORT:$line2";
                $line2 =~ s{SORT}{}i;
                CheckSort($line2,$filename);
	    }

#            if ( $CurrentInst eq "READ") {
#                print "$filename:$CptLine:JE SUIS DANS READ: $CurrentFichier2 :$line";
		if ($CheckIndexed == 1) {
		    if ($line =~ m{\s+INVALID\s+KEY}i) {
			$InvalidKey = 1;
#			print "LIGNE INVALID KEY ==== $CptLine " . $line ;
		    }
		}
#	    }



            if ($line =~ m{\s+READ\s+($IDENTIFIER)}i) {
               $CurrentFichier2 = uc($1);
               $CurrentReadLine = $CptLine;
                if (exists $TabFichier2{$CurrentFichier2}) {
		    
		    if ($TabFichier2{$CurrentFichier2}->{'Organisation'} eq "i") {
			    Cobol::violation::violationInfo("FILE_EXIST",$filename,$CptLine,"Information,Le fichier $CurrentFichier2 est déclaré indexed");
                        $CheckIndexed = 1;

		    } else {
			    Cobol::violation::violationInfo("FILE_EXIST",$filename,$CptLine,"Information,Le fichier $CurrentFichier n est pas déclaré indexed");
			$CheckIndexed = 0;
		    }

		} else {
		    Cobol::violation::violationdebug("FILE_NOT_EXIST",$filename,$CptLine,"Information,Le fichier $CurrentFichier2 n'est pas déclaré ou la déclaration est faite dans une clause copy");
		}

	    }

#WRITE ou REWRITE
# FLOFLO dur dur car il faut passer par les enregistrement
#WRITE ENR-SCRATCH FROM ZONE-SCRAVIDE.

           if ( $CurrentInst eq "END-READ") {
                    if ($CheckIndexed == 1) {
			if ($InvalidKey == 0) {
				Cobol::violation::violation("NO_INVALID_KEY",$filename,$CptLine,"Violation,Pas de clause invalid key pour la lecture $CurrentReadLine du fichier $CurrentFichier2 qui est déclaré indexed ");
			    $cptMissingInvalidKey++;	
			} else {
#			    print "Ligne courante $CptLine" . $line;
			}
			$InvalidKey = 0;
			$CheckIndexed = 0;
		    }
	   }

		if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
		    $CurrentInst= "";
                    if ($CheckIndexed == 1) {
			if ($InvalidKey == 0) {
				Cobol::violation::violation("NO_INVALID_KEY",$filename,$CptLine,"Violation,Pas de clause invalid key pour la lecture $CurrentReadLine du fichier $CurrentFichier2 qui est déclaré indexed ");	
			    $cptMissingInvalidKey++;
			} else {
#			    print "Ligne courante $CptLine" . $line;
			}
			$InvalidKey = 0;
			$CheckIndexed = 0;
		    }
		}
		return;
}

sub endFichier() {
#    print "Nb element: " . (scalar keys %TabFichier2) . "\n";
    CheckFichier(\%TabFichier2,$filename);
    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_CuriousFilePb(),$cptCuriousFilePb);
    Couples::counter_add($StructFichier,Ident::Alias_MissingInvalidKey(),$cptMissingInvalidKey);
    Couples::counter_add($StructFichier,Ident::Alias_SeriousFilePb(),$cptSeriousFilePb);
    reinitFichier();

}
sub reinitFichier {
    #Compteur
    $cptSeriousFilePb = 0;
    $cptMissingInvalidKey = 0;
    $cptCuriousFilePb = 0;

    $CptLine = 0;
    $CurrentPara = "";
    $CurrentInst = "";
    %TabFichier2 = ();
    $PrevOpen = "";
    $PrevClose = "";
}

sub CheckFichier { 
    my ($t, $filename) = @_;
    for my $k (keys(%{$t})) {
	Cobol::violation::violationdebug("DEBUG_OPEN_CLOSE",$filename,$t->{$k}->{'ligne'},"DEBUG, Autant d'opération d'ouverture($t->{$k}->{'open'}) que de fermeture($t->{$k}->{'close'}) pour le fichier $k ");
	
	if ( $t->{$k}->{'SDFD'} eq "SD") { 
#Traiter le sort
	    if ( $t->{$k}->{'sort'} == 0 ) {
		    Cobol::violation::violation("RU_NO_SORT",$filename,$t->{$k}->{'ligne'},"Violation, Le fichier de tri $k n\'est jamais trié");
		$cptCuriousFilePb++;
	    }
	    next;
	}
        if ( $t->{$k}->{'close'} == 0 && $t->{$k}->{'open'} == 0) {
#DOCAFAIRE
		Cobol::violation::violation("RU_NO_CLOSEOPEN",$filename,$t->{$k}->{'ligne'},"Violation, Le fichier $k n\'est jamais ni ouvert ni fermé");
	    $cptCuriousFilePb++;
	} else {
	    if ( $t->{$k}->{'open'} == 0 && $t->{$k}->{'close'} >= 1) {
#DOCAFAIRE
		    Cobol::violation::violation("RU_NO_OPEN",$filename,$t->{$k}->{'ligne'},"Violation, Le fichier $k n\'est jamais ouvert mais est fermé");
		$cptSeriousFilePb++;
	    } else {
		if ( $t->{$k}->{'open'} >= 1 && $t->{$k}->{'close'} == 0) {
#DOCAFAIRE
			Cobol::violation::violation("RU_NO_CLOSE",$filename,$t->{$k}->{'ligne'},"Violation, Le fichier $k n\'est jamais fermé mais est ouvert");
		    $cptSeriousFilePb++;
		} else {
		    if ($t->{$k}->{'open'} != $t->{$k}->{'close'}) {
			    Cobol::violation::violation("RC_EQ_OPEN_CLOSE",$filename,$t->{$k}->{'ligne'},"Violation, Autant d'opération d'ouverture($t->{$k}->{'open'}) que de fermeture($t->{$k}->{'close'}) pour le fichier $k");
		    $cptCuriousFilePb++;
		    } else {
		    }
		}
	    }
	}
    }
}


sub CheckSort {
    my ($fichier, $filename) = @_;
    $fichier =~ s{\.}{ };
    $fichier =~ s{\n}{ };
    $fichier =~ s{[ \t]+}{ }g;
    $fichier =~ s{\A[ \t]*}{}g;
    foreach $mot (split / /, $fichier) {
	if (exists $TabFichier2{$mot}) {
	    $TabFichier2{$mot}->{'sort'}++;
#	    if ($TabFichier2{$mot}->{'close'} > 1) {
#DOCAFAIRE
#		violation("ORGA_CLOSEMULT",$filename,$CptLine,"Violation, $CurrentPara ,Fichier $mot fermé plusieurs fois" . $_);
#	    }
	}
    }
}


sub CheckClose {
    my ($fichier, $filename) = @_;
    $fichier =~ s{\.}{ };
    $fichier =~ s{\n}{ };
    $fichier =~ s{[ \t]+}{ }g;
    $fichier =~ s{\A[ \t]*}{}g;
    foreach $mot (split / /, $fichier) {
	if (exists $TabFichier2{$mot}) {
	    $TabFichier2{$mot}->{'close'}++;
	    if ($TabFichier2{$mot}->{'close'} > 1) {
#DOCAFAIRE
		    Cobol::violation::violation("ORGA_CLOSEMULT",$filename,$CptLine,"Violation, $CurrentPara ,Fichier $mot fermé plusieurs fois");
		$cptCuriousFilePb++;
	    }
	}
    }
}





sub CheckOpen {
    my ($fichier, $filename) = @_;
    $fichier =~ s{\.}{ };
    $fichier =~ s{\n}{ };
    $fichier =~ s{[ \t]+}{ }g;
    $fichier =~ s{\A[ \t]*}{}g;
#print "$filename:$CptLine:JE SUIS DANS CheckOpen<<<<<<$fichier>>>>>>\n";
    foreach $mot (split / /, $fichier) {
	if (exists $TabFichier2{$mot}) {
	    $TabFichier2{$mot}->{'open'}++;
	    if ($TabFichier2{$mot}->{'open'} > 1) {
#DOCAFAIRE
		    Cobol::violation::violation("ORGA_OPENMULT",$filename,$CptLine,"Violation, $CurrentPara ,Fichier $mot ouvert plusieurs fois");
		$cptCuriousFilePb++;
	    }
	}
    }
}

1;
