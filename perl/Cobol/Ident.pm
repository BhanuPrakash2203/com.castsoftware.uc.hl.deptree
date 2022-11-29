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

sub Ident ($$$$$)
 {

    my($buffer,$StructFichier,$filename, $Type1,$Type2)=(@_);

    my $FICHIER= $filename;
    my $CptLine = 0;

    if (! defined $StructFichier->{"Dat_IdentDivLine"}) {
      # In case of copybook, IDENTIFICATION DIVISION is not present. So do
      # not check it !
      return;
    }
    $CptLine = $StructFichier->{"Dat_IdentDivLine"} - 1 ;

    my $programId = "";

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

        #Suivant le type de Zone on peux compter des objets differents
        # Nous sommes en Identification-division

	    if ($line =~ m{^( ){1,4}PROGRAM-ID\s*\.\s*(.*)\Z}i) {
                $programId = uc($2);
                $programId =~ s{\.}{}g;
                $programId =~ s{ }{}g;
                $programId =~ s{\s}{}g;
                my $ProgName;
                $ProgName = uc($FICHIER);
                $ProgName =~ s{\..*}{};
                $ProgName =~ s{.*/}{};
		#$ProgName =~ tr/az/AZ/ ;
                if ($programId eq $ProgName) {
#SUP		    print "Tout va bien $programId eq $ProgName\n";
		} else {
		# @Code: PROGID
		# @Type: PRESENTATION STRUCT
		# @Description: Absence et conformité du paragraphe PROGRAM-ID
		# @Caractéristiques: 
		#   - Maintenabilité 
		# @Commentaires: Requis par 1985 and 2002 ANSI/ISO COBOL Standards
		# @Restriction: 
		# @RULENUMBER: R22
	         Cobol::violation::violation2("NAMING_PROGID",$FICHIER,1,"Clause PROGRAM-ID erronee ($programId/$ProgName)");
                 #pas de comptage
		}
               
	    }


    } # fin boucle

    if ( $programId eq "" ) {
	# @Code: PROG_ID
	# @Type: ORGANISATION STRUCT
	# @Description: Absence et conformité du paragraphe PROGRAM-ID
	# @Caractéristiques: 
	#   - Maintenabilité 
	# @Commentaires: Requis par 1985 and 2002 ANSI/ISO COBOL Standards
	# @Restriction: 
	# @RULENUMBER: R22
	Cobol::violation::violation2("ORGA_NOPROGID",$FICHIER,1,"Pas de clause PROGRAM-ID pour ce fichier");
        #pas de comptage
    }
	
}




1;
