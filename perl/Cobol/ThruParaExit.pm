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

# Cobol::violation::violation("RC_THRU_PARA_MISSING",$filename,1,"Violation, Le paragraphe $k reference par une clause THRU n\'existe pas");
# Cobol::violation::violation("RC_NO_THRU_EXIT",$filename,$t->{$k}->{'ligne'},"Violation, Le paragraphe $k reference par une clause THRU ne contient pas de exit");

use Cobol::violation;

my $IDENTIFIER = Cobol::CobolCommon::get_IDENTIFER_PATTERN();

my $StructFichier;
my $filename="";

my $CurrentPara = "";
my $TabPara = $StructFichier->{"TabPara"};
my $TabPara2 = $StructFichier->{"TabPara2"};

my $waitlignesuivante = 0;


#Compteur
my $cptNoExitInParaRefByThru = 0;
my $cptBackPerform = 0;

sub initThruParaExit ($$) {
    ($StructFichier,$filename)=(@_);

    $CurrentPara = "";
    $TabPara = $StructFichier->{"TabPara"};
    $TabPara2 = $StructFichier->{"TabPara2"};
}

sub ThruParaExit ($$$) {
	# One line of ProcDiv
        my $line = shift;
	my $CptLine=shift;
	my $NewPara=shift;

	if (defined $NewPara) {
           $CurrentPara = $NewPara;
        }

        if ($line =~ m{\A\s*\Z}) {
         #ligne blanche
	    return;
	}
        #  lignes de commentaire ou debug
        if ($line =~ m{\A\S}) {
	    return;
	} 

	# trhu seul sur la ligne.
	if ($waitlignesuivante == 1 ) {
	    my $NewLine = $line;
	    $NewLine =~ s{\n}{ };
	    if ($NewLine =~ m{\s+($IDENTIFIER)\s}i) {
		my $Cible = uc($1);
#		print $line . "#####<$Cible>########\n";
		checkNameThru($Cible,$CptLine);
		$TabPara2->{$Cible}->{'thru'} = 1;
		Cobol::violation::violationdebug("THRU",$filename,$CptLine,"Violation, $CurrentPara ,$TabPara2->{$Cible}->{'thru'} il y a un thru vers $Cible " . $line);
		
	    }
	    $waitlignesuivante = 0;
	}
	if ($line =~ m{\s+(THRU|THROUGH)\s*\Z}i) {
	    $waitlignesuivante = 1;
	    return;
	}
	# trhu pas seul sur la ligne.
	if ($line =~ m{\s+(THRU|THROUGH)\s+($IDENTIFIER)}i) {
	    my $paraname = uc($2);
	    checkNameThru($paraname,$CptLine);
	    
	    $TabPara2->{$paraname}->{'thru'} = 1;
	    Cobol::violation::violationdebug("THRU",$filename,$CptLine,"Violation, $CurrentPara ,$TabPara2->{$paraname}->{'thru'} il y a un thru vers $paraname " . $line);
	}
	
	if ($line =~ m{\s+EXIT\b\.*}i) {
	    $TabPara2->{$CurrentPara}->{'exit'} = 1;
	    Cobol::violation::violationdebug("EXIT",$filename,$CptLine,"Violation, $CurrentPara ,$TabPara2->{$CurrentPara}->{'exit'} il y a un exit " . $line);
	}
	
	
	if ($line =~ m{\A(\s+)(PERFORM\s+VARYING|PERFORM\s+UNTIL)\b}i){
	    return;
	}
	if ($line =~ m{\A(\s+)END-PERFORM\b}i){
	    return;
	}
	if ($line =~ m{\sPERFORM\s+($IDENTIFIER)\s*}i) {
	    my $cible = uc($1); 
	    if (exists $TabPara->{$cible}) {
	      if ($TabPara->{$cible} < $CptLine) {
		# @Code: BACK_PERFORM
		# @Type: FLOW
		# @Description: Référence en arrière par PERFORM à un paragraphe défini plus haut dans le code
		# @Caractéristiques: 
		#   - maintenabilité
		# @Commentaires: Instruction destructurante. 
		#
		# @RULENUMBER: Rxx
		# @Restriction: 
		Cobol::violation::violation("CF_BACK_PERFORM",$filename,$CptLine,"Violation, Référence en arrière par PERFORM à un paragraphe défini plus haut dans le code ($cible ligne $TabPara->{$cible}) " );
                $cptBackPerform++;
	      }	
	    }  else {
#		    violationbid("PERFORMPASBACK",$filename,$CptLine,"Violation, PERFORMvers $cible " );
	    }
	}
	
	if ($line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
	}
	return;
	
	
    } # fin boucleligne

sub endThruParaExit() {
    CheckPara(\%TabPara2,$filename);
    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_BackPerform(),$cptBackPerform);
    Couples::counter_add($StructFichier,Ident::Alias_NoExitInParaRefByThru(),$cptNoExitInParaRefByThru);
    reinitThruParaExit();
}

sub reinitThruParaExit {

$waitlignesuivante = 0;
#Compteur
$cptNoExitInParaRefByThru = 0;
$cptBackPerform = 0;
}

sub checkNameThru($$) {
    my($name, $line)=(@_);
#print "checkNameThru(). $name\n";
	if (!( $name =~ /\bFIN\b|\bF\b/ ) ) {
		    # @Code: THRU_NAME
		    # @Type: NAMING DATA
		    # @Description: Nommage des clauses THRU

		    # @RULENUMBER: R23
	       Cobol::violation::violation("NAMING_THRU_NAME", $filename,$line,"Violation, Nommage errone d'un paragraphe THRU $name. ");
#pas de comptage
		}
    
}


sub CheckPara($$) { 
    my ($t, $filename) = @_;
    for my $k (keys(%{$t})) {
        if ( !defined($t->{$k}->{'ligne'})) {
#DOCAFAIRE
	    Cobol::violation::violation("RC_THRU_PARA_MISSING",$filename,1,"Violation a verifier, Le paragraphe $k reference par une clause THRU n\'existe pas");
#Pas de comptage
	} else {

	    if ( $t->{$k}->{'thru'} == 1) {
		if ($t->{$k}->{'exit'} != 1) {
#DOCAFAIRE
		    Cobol::violation::violation("RC_NO_THRU_EXIT",$filename,$t->{$k}->{'ligne'},"Violation, Le paragraphe $k reference par une clause THRU ne contient pas de exit");
                    $cptNoExitInParaRefByThru++;
		} else {
#TRACE		print "TRHU_EXIT_OK:$t->{$k}->{'thru'}           " . $k . ":" . $t->{$k}->{'ligne'} . " " . $t->{$k}->{'exit'} . "\n";
		    
		}
	    } else {
#TRACE	    print $k . ":" .  "PAS DE TRHU\n";
	    }
	}
    }
}


1;
