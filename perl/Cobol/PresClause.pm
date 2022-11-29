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
# Cobol::violation::violation("PRES_CLAUSE_BEGIN_LINE", $FICHIER,$CptLine,"Violation, Une clause $clause doit être écrite en début de ligne");

use Cobol::violation;

sub PresClause  ($$$)
{
    my($buffer,$StructFichier,$filename)=(@_);
    my $FICHIER= $filename;
    my $CptLine = 0;
    $CptLine = $StructFichier->{"Dat_ProcDivLine"} - 1 ;
    

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
	if ($line =~ m{\S+\s*\b(WHEN\s|AT\s+END|NOT\s+AT\s+END|INVALID\s+KEY|NOT\s+INVALID\s+KEY)}i) {
	    my $clause = $1;
	    # @Code: CLAUSE_BEGIN_LINE
	    # @Type: PRESENTATION
	    # @Description: Une clause xxx doit être écrite en début de ligne
	    # @Caractéristiques: 
	    #   - Facilité d'analyse
	    # @Commentaires:
	    # @Restriction: 
	    # @RULENUMBER: Rxxx
	    Cobol::violation::violation("PRES_CLAUSE_BEGIN_LINE", $FICHIER,$CptLine,"Violation, Une clause $clause doit être écrite en début de ligne"); 
	    #Pas de comptage
	}
	
    } # fin boucle
	
}




1;
