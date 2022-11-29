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

my($buffer,$StructFichier,$filename)=(@_);

#Compteur
my $cptConstLit = 0;

sub initConstantLit($$$) {
    ($StructFichier,$filename)=(@_);
    #Compteur
    $cptConstLit = 0;
}

sub ConstantLit($$$) {
	# One line of ProcDiv
        my $line = shift;
	my $CptLine=shift;
	my $NewPara=shift;

        # Nous sommes en procedure division
	
	#traitement des chaines
	$line =~ s{\".*\"}{}g;
	$line =~ s{\'.*\'}{}g;
	#traitement des - 
	$line =~ s{-|\+|_}{}g;
	$line =~ s{\b[a-zA-Z]+[a-zA-Z0-9]*}{}g;
	$line =~ s{[a-zA-Z0-9]+[a-zA-Z][a-zA-Z0-9]*}{}g;
	$line =~ s{\(\d*:\d*\)}{}g; #traitement du :
	$line =~ s{\(\s*\d+\s*\)}{}g; #traitement du (3)
	$line =~ s{\.\s*}{}g; #traitement du .
	$line =~ s{\b0+}{}g; #traitement des 0003
	$line =~ s{\b[0-1]\b}{}g; #traitement du 0 et 1
	if ( $line =~ m((\d+)) ) {
	    my $Literal = $1;
	    if ($Literal =~ m(\d\d+)) {
		Cobol::violation::violation2("RU_NO_LITERAL", $filename,$CptLine,"Violation, Utilisation d'un litéral(Plus 2 digits) $Literal:" . $line);
		$cptConstLit++;
	    } else {
		Cobol::violation::violation2("RU_NO_LITERAL", $filename,$CptLine,"Violation, Utilisation d'un litéral(1 digits) $Literal:" . $line);
		$cptConstLit++;
	    }
	}
	
	if ( $line =~ m{\.\s*\Z}) {  # Il y a un point en fin de ligne
	}
	return;
	
    } # fin boucleligne

sub endConstantLit() {
    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_ConstLit(),$cptConstLit);
}




1;
