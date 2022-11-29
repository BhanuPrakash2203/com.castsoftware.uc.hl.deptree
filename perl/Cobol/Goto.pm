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

my $IDENTIFIER = Cobol::CobolCommon::get_IDENTIFER_PATTERN();

my $CurrentPara = "";

my $CptLine = 0;
my $TabPara;
my $filename = "";
my $StructFichier;

my $cptBackGoto = 0;

sub initGoto($$) {
    ($StructFichier,$filename)=(@_);

    #Compteur
    $cptBackGoto = 0;
    $CurrentPara = "";

    $TabPara = $StructFichier->{"TabPara"};
}

sub Goto($$$) {
	# One line of ProcDiv
        my $line = shift;
	my $CptLine=shift;
	my $NewPara=shift;

	if (defined $NewPara) {
           $CurrentPara = $NewPara;
        }

	    if ($line =~ m{\bGO\b\s*(?:TO\b)?\s*($IDENTIFIER)}i) {
                my $cible = uc($1);
#TRACE                print $cible . " $CptLine \n";
                $cible =~ s{TO }{};
#TRACE                 print "-----------" . $cible . " $CptLine \n";
		if (exists $TabPara->{$cible}) {
		  if ($TabPara->{$cible} < $CptLine) {
		    # @Code: GOTOBACK
		    # @Type: FLOW
		    # @Description: L'instruction goto en arrière  est interdite 
		    # @Caractéristiques: 
		    #   - maintenabilité
		    # @Commentaires: Instruction destructurante. 
		    #
		    # @RULENUMBER: Rxx
		    # @Restriction: 
                    if ( $CurrentPara eq $cible ) {
			Cobol::violation::violation2("CF_GOTOBACK",$filename,$CptLine,"Violation, $CurrentPara, GOTO en arrière boucle vers $cible ligne $TabPara->{$cible} " );
			$cptBackGoto++;
		    } else {
			Cobol::violation::violation2("CF_GOTOBACK",$filename,$CptLine,"Violation, $CurrentPara, GOTO en arrière vers $cible ligne $TabPara->{$cible} " );
			$cptBackGoto++;
		    }
		  }
		}  else {
#		    violationbid("GOTOPASBACK",$filename,$CptLine,"Violation, GOTO vers $cible " );

		}
	      # @Code: GOTO
	      # @Type: FLOW
	      # @Description: L'instruction goto est interdite 
	      # @Caractéristiques: 
	      #   - maintenabilité
	      # @Commentaires: Instruction destructurante. 
	      #
	      # @RULENUMBER: R1
	      # @Restriction: 
                Cobol::violation::violation2("CF_GOTO",$filename,$CptLine,"Violation, Utilisation de goto" );
                #pas de comptage, fait ailleurs
#		$cptGoto2++;
	    }

	    if ($line =~ m{\.\s*\Z}i) {
#		TraitementPoint();
	    }

    } # fin boucle ligne

sub endGoto() {
    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_BackGoto(),$cptBackGoto);
}




1;
