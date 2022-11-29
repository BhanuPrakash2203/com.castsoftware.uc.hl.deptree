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

package Cobol::FonctionIntegree;

use Cobol::violation;

sub FonctionIntegree ($$$)
{
    my($buffer,$StructFichier,$filename)=(@_);
    my $FICHIER= $filename;
    my $CptLine = 0;
    $CptLine = $StructFichier->{"Dat_ProcDivLine"} - 1 ;

    my $FIDate = 0;
    my $FIChaine = 0;
    my $FIFin = 0;
    my $FINum = 0;
#    print "Analyse de $filename\n";
    while ($buffer =~ /(.*\n)/g ) {
        my $line = $1;
        # comptage des lignes
	$CptLine++;
        if ($line =~ m{\A\s*\Z}) {
         #ligne blanche
	    next;
	}
        #  lignes de commentaire ou debug
        if ($line =~ m{\A\S}) {
	    next;
	} 

        # Nous sommes en procedure division
#FLOFLO a voir si le mot clé function avant car obligatoire
            #Les manip de dates
	    if ($line =~ m{\s(CURRENT-DATE|WHEN-COMPILED|INTEGER-OF-DAY\s*\(|INTERGER-OF-DATE\s*\(|DATE-OF-INTEGER\s*\(|DAY-OF-INTEGER\s*\()\b}i) {
		# @Code: FONC_INTEG_DATE
		# @Type: PERF
		# @Description: Utilisation des fonctions integrées de date
		# @Caractéristiques: 
		#   - Performance
		# @Commentaires: 
		# @RULENUMBER: R 
                $FIDate++;
                next;
	    }
            #Les manip de chaines de caractères
	    if ($line =~ m{\s(CHAR\s*\(|ORD\s*\(|UPPER-CASE\s*\(|LOWER-CASE\s*\(|LENGTH\s*\(|NUMVAL\s*\(|NUMVAL-C\s*\(|REVERSE\s*\()\b}i) {
		# @Code: FONC_INTEG_CHAINE
		# @Type: PERF
		# @Description: Utilisation des fonctions integrées de manipulation de chaine
		# @Caractéristiques: 
		#   - Performance
		# @Commentaires: 
		# @RULENUMBER: R 
                $FIChaine++;
                next;
	    }
            #Les manip de financières
	    if ($line =~ m{\s(ANNUITY\s*\(|PRESENT-VALUE\s*\()\b}i) {
		# @Code: FONC_INTEG_FIN
		# @Type: PERF
		# @Description: Utilisation des fonctions integrées financières
		# @Caractéristiques: 
		#   - Performance
		# @Commentaires: 
		# @RULENUMBER: R 
                $FIFin++;
                next;
	    }
            #Les manip numérique
	    if ($line =~ m{\s(INTEGER\s*\(|INTEGER-PART\s*\(|MAX\s*\(|MIN\s*\(|MIDRANGE\s*\(|ORD-MAX\s*\(|ORD-MIN\s*\(|RANDOM\s*\(|RANGE\s*\(|REM\s*\(|SUM\s*\()\b}i) {
		# @Code: FONC_INTEG_NUM
		# @Type: PERF
		# @Description: Utilisation des fonctions integrées numériques
		# @Caractéristiques: 
		#   - Performance
		# @Commentaires: 
		# @RULENUMBER: R 
                $FINum++;
                next;
	    }

    } # fin boucle
	
#test de la suite
    if ($FIDate == 0) {
	Cobol::violation::violation("PERF_FONC_INTEG_DATE", $FICHIER,1,"Attention, Il n\'y a pas d\'utilisation des fonctions intégrées de manipulation de date");
    } else {
	Cobol::violation::violation("PERF_FONC_INTEG_DATE", $FICHIER,1,"Information, Il y a $FIDate utilisations des fonctions intégrées de manipulation de date");
    }
    if ($FIChaine == 0) {
	Cobol::violation::violation("PERF_FONC_INTEG_CHAINE", $FICHIER,1,"Attention, Il n\'y a pas d\'utilisation des fonctions intégrées de manipulation de chaine");
    } else {
	Cobol::violation::violation("PERF_FONC_INTEG_CHAINE", $FICHIER,1,"Information, Il y a $FIChaine utilisations des fonctions intégrées de manipulation de chaine");
    }
    if ($FIFin == 0) {
	Cobol::violation::violation("PERF_FONC_INTEG_FIN", $FICHIER,1,"Attention, Il n\'y a pas d\'utilisation des fonctions intégrées financières");
    } else {
	Cobol::violation::violation("PERF_FONC_INTEG_FIN", $FICHIER,1,"Information, Il y a $FIFin utilisations des fonctions intégrées  financières");
    }
    if ($FINum == 0) {
	Cobol::violation::violation("PERF_FONC_INTEG_NUM", $FICHIER,1,"Attention, Il n\'y a pas d\'utilisation des fonctions intégrées numériques");
    } else {
	Cobol::violation::violation("PERF_FONC_INTEG_NUM", $FICHIER,1,"Information, Il y a $FINum utilisations des fonctions intégrées numériques");
    }	
}

1;
