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
my $filename;

    #compteur
my $cptBadZoneDecl = 0;
my $cptBadInit = 0;
my $cptEmptyRenames = 0;
my $cptDeclWithoutIdent = 0;
my $cptPicTooLong = 0;

sub initWorking ($$) {
    ($StructFichier,$filename)=(@_);
    #compteur
    $cptBadZoneDecl = 0;
    $cptBadInit = 0;
    $cptEmptyRenames = 0;
    $cptDeclWithoutIdent = 0;
    $cptPicTooLong = 0;
}

sub Working ($$) {
	# One line of ProcDiv
        my $line = shift;
	my $CptLine=shift;

  ########################
  # VALUE
  ########################
  #
  #         ***********  Nbr_BadInit *********
  #
  	    if ($line =~ m{(\sVALUE\s+(0|\+0)\b)}i) {
  		   # @Code: INIT_ZERO_SPACE
  		   # @Type: DATA
  		   # @Description: Utiliser ZERO OU SPACE pour initialiser des zones par VALUE
  		   # @Caractéristiques: Maint
  		   # @Commentaires: 
  		   # @Restriction: 
  		   # @RULENUMBER: Rxx
  		   Cobol::violation::violation("RC_INIT_ZERO_SPACE", $filename,$CptLine,"Violation, Utiliser ZERO pour initialiser des zones par VALUE $cptBadInit");
  		   $cptBadInit++;
  	    }
  	    elsif ($line =~ m{(\sVALUE\s+'\s+')}i) {
  		   # @Code: INIT_ZERO_SPACE
  		   # @Type: DATA
  		   # @Description: Utiliser ZERO OU SPACE pour initialiser des zones par VALUE
  		   # @Caractéristiques: Maint
  		   # @Commentaires: 
  		   # @Restriction: 
  		   # @RULENUMBER: Rxx
  		   Cobol::violation::violation("RC_INIT_ZERO_SPACE", $filename,$CptLine,"Violation, Utiliser SPACE pour initialiser des zones par VALUE  $cptBadInit");
  		   $cptBadInit++;
  	    }
  	    elsif ($line =~ m{^(\s*)\d+\s+(\w[\w-]*)\s+PIC\s+X\((\d+)\)\s+VALUE\s+\'(.*)\'}i) {
                  my $lg = length($4);
                  if ( $3 == $lg) {
  		    #Cobol::violation::violation("RC_ESSAI_GOOD", $filename,$CptLine,"Violation, <<$2>><<$3>><<$4>>,$lg");
  		} else {
  		    Cobol::violation::violation("RC_INIT_NON_CONFORME", $filename,$CptLine,"Violation, Initialisation par value non conforme <<$2>><<$3>><<$4>>,$lg");
  		    $cptBadInit++;
  #### FLO CELUI LA EST PLUS GRAVE
  		}
  	    }

  #         ***********  Nbr_BadZoneDecl *********
  
  	    if ($line =~ m{^(\s){4}\s*(01|1)\s.*}i) {
  		Cobol::violation::violation("RC_01_BADZONE", $filename,$CptLine,"Violation, Donnée en 01 mal colonnée");
  		$cptBadZoneDecl++;
  	    }
  # Question et le colonnage de 77?
  	    elsif ($line =~ m{^\s{1,3}88\s+\w[\w-]*\s.*}i) {
  		Cobol::violation::violation("RC_88_BADZONE", $filename,$CptLine,"Violation, Donnée en 88 mal colonnée");
  		$cptBadZoneDecl++;
  	    }

  	    if ($line =~ m{^\s+(?:66|77|88)\s+(\w[\w-]*)\s.*}i) {
                  my $variable = $1;
  #		print "FFF <<$2>>______<<$3>>\n";
  
  		if (!(($variable=~/^W-/) || ($variable=~/^WSS-/)  )&& !($variable=~/^FILLER$/)) {
  		    # @Code: SG_WS_PREFIX
  		    # @Type: NAMING DATA
  		    # @Description: Une variable déclarée dans la WORKING doit être préfixée par W- ou WSS-
  
  		    # @RULENUMBER: R18
  	       Cobol::violation::violation("NAMING_WSPREFIX", $filename,$CptLine,"Violation, Une variable ($variable) déclarée dans la WORKING doit être préfixée par W- ou WSS-. ");
  #Pas de comptage
  		}
  		if (($variable=~/[a-z]/)) {
  		    # @Code: SG_MAJ_NAME
  		    # @Type: DATA
  		    # @RULENUMBER: R17
  		    # @Description: Une variable déclarée dans la WORKING ne contient que des majucules
  
  
  	       Cobol::violation::violation("NAMING_WSMAJ", $filename,$CptLine,"Violation, Une variable ($variable) déclarée dans la WORKING ne contient que des majucules");
  #Pas de comptage
  		}
  	    }
              if ($line =~ m{^\s+(\d|\d\d)\s+RENAMES\s}i) {
  	      # @Code: RENAMES
  	      # @Type: DATA
  	      # @Description: Eviter le renames vide
  	      # @Caractéristiques: 
  	      #   - Maintenabilité - Fiabilité
  	      # @Commentaires: 
  	      # @Restriction: 
  	      # @RULENUMBER: R14
  	       Cobol::violation::violation("RC_EMPTY_RENAMES", $filename,$CptLine,"Violation, Declaration renames sans identificateur ");
  	       $cptEmptyRenames++;
              }
              if ($line =~ m{^\s+(\d|\d\d)\s+PIC\s}i) {
  	      # @Code: NO_IDENT_DECL
  	      # @Type: DATA
  	      # @Description:  Declaration sans identificateur
  	      # @Caractéristiques: 
  	      #   - Maintenabilité - Fiabilité
  	      # @Commentaires: FILLER peut être absent en IBM
  	      # @Restriction:  Pascale voudrait voir un cas de violation. Quelle curieuse!!!
  	      # @RULENUMBER: Rxx
  	       Cobol::violation::violation("RC_NO_IDENT_DECL", $filename,$CptLine,"Violation, Declaration sans identificateur ");
  	       $cptDeclWithoutIdent++;
              }
  	    if ($line =~ m{\s(PIC|PICTURE)\s+(\w+)}i) {
  
                  my $a = $2;
                  my $b = $2;
                  my $z = ( $a =~ s/Z//g);
  # On ne se preoccupe pas des picture d edition
                  if ( $z == 0 ) {
  		    my $x = 0;
  		    my $y = 0;
  		    $a =~ s/S//g;
  		    my $virg = ( $a =~ s/V/V/g);
  		    if ($virg == 1 ) {
  			my $pe = $a;
  			my $pd = $a;
  			$pe =~  s/V.*//;
  			$pd =~  s/.*V//i;
  
  			$x = ( $pe =~ s/\w/ /g);
  			$y = ( $pd =~ s/\w/ /g);
  		    } else {
  			$x = ( $a =~ s/\w/ /g);
  		    }
  		    if ( $x > 3 || $y > 3) {
  			# @Code: RU_PIC_LG
  			# @Type: PRESENTATION
  			# @Description: Une clause PICTURE ne doit pas contenir une sequence de plus de 3 caractères identiques
  			# @Caractéristiques: 
  			# - Facilité d'analyse
  			# - Facilité de modification
  			# @Commentaires:
  			# @Restriction: Attention encore aux autres pic d edition +-$...
  
  		        # @RULENUMBER: R26
  			Cobol::violation::violation("RU_PIC_LG",$filename,$CptLine,"Violation, Une clause PICTURE ne doit pas contenir une sequence de plus de 3 caractères identiques: $b");  
  			$cptPicTooLong++;         
  		    }
  		}
                  
  	    }
  	    if ($line =~ m{\s(PIC|PICTURE)\s+9}i) {
  			# @Code: RULE_PIC_S
  			# @Type: PERFORMANCE
  			# @Description: Utilisation du signe pour un numerique
  			# @Caractéristiques: 
  			# - Performance
  			# @Commentaires: Le symbole S designe un nombre signe. Il n'est pas obligatoire. 
  		        # Toutefois, il y a interet à le mettre car sinon COBOL supprime systématiquement 
                          # le signe après chaque calcul ce qui freine la vitesse de traitement.
  			# @Restriction: 
  
  		        # @RULENUMBER: Rxx
  			Cobol::violation::violationavoir("PERF_SIGNE",$filename,$CptLine,"Violation, Utilisation du signe pour un numerique");
  #Pas de comptage
  	    }
  
  ###############################################
  # Traitement des COMP ...
  ###############################################
  	    if ($line =~ m{\s(COMP|COMPUTATIONAL)-(2|4|5)}i) {
  			# @Code: RULE_COMP
  			# @Type: PERFORMANCE
  			# @Description: Eviter l'utisation de données numériques qui ne sont pas COMP ou COMP-3
  			# @Caractéristiques: 
  			# - Performance
  			# @Commentaires: CAST Eviter l'utisation de données numériques qui ne sont pas COMP ou COMP-3
  			# @Restriction: 
  		        # @RULENUMBER: Rxx
  			Cobol::violation::violationavoir("NUMCOMP",$filename,$CptLine,"Violation, Eviter l'utisation de données numériques qui ne sont pas COMP ou COMP-3");
  #Pas de comptage
  	    }
  
  # il faut traiter les numériques sans COMP du tout.
  	    if ($line =~ m{\s(PIC|PICTURE)\s+s*9(.*)}i) {
  		my $comp = $2;
                  if ($line =~ m{\s(COMP|COMPUTATIONAL)}) {
                    # violation3("numcomp",$filename,$CptLine,"Violation, PAs une violation"); 
                  } else {
  			Cobol::violation::violationavoir("NUMCOMP",$filename,$CptLine,"Violation, Eviter l'utisation de données numériques qui ne sont pas COMP ou COMP-3");  
  #Pas de comptage
                  }
  	    }
  
  
  
} # fin boucle ligne

sub endWorking() {
    #Ecriture des compteurs	
    Couples::counter_add($StructFichier,Ident::Alias_BadZoneDecl(),$cptBadZoneDecl);
    Couples::counter_add($StructFichier,Ident::Alias_BadInit(),$cptBadInit);
    Couples::counter_add($StructFichier,Ident::Alias_EmptyRenames(),$cptEmptyRenames);
    Couples::counter_add($StructFichier,Ident::Alias_DeclWithoutIdent(),$cptDeclWithoutIdent);
    Couples::counter_add($StructFichier,Ident::Alias_PicTooLong(),$cptPicTooLong);
	
}




1;
