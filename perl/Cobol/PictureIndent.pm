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

# violation("PRES_PICTURE_INDENT", $filename, $.,"Alignement des clauses PICTURE");

use Cobol::violation;

my $StructFichier;
my $filename;

#Compteur
my $cptPICNotAlign = 0;

my $ok = 0;
my $previousLevel = -1;
my $previousValueOffset = -1;


sub initPictureIndent($$) {
    ($StructFichier, $filename)=(@_);
    #Compteur
    $cptPICNotAlign = 0;

    $ok = 0;
    $previousLevel = -1;
    $previousValueOffset = -1;
}
#   print STDERR "Parsing $filename for RULE_PICTURE_INDENT ...\n";
  
sub PictureIndent($$) {
        my $line = shift;
	my $CptLine=shift;
        #chaine
        return if ($line =~ m{\A\s*\'.*\'});
	
	if ($line =~ m{\A\s+(77|01|1)\s}) {
            # réinit de l'offset de référence sur une déclaration de niveau 1
	    $previousValueOffset = -1;
	}
        # test du niveau
	if ($line =~ m{\A\s+(\d+)\s}) {
            if ($1 == $previousLevel) {
                $ok = 1;
            } else {
                $ok = 0;
                $previousLevel = $1;
	        $previousValueOffset = -1;
            }       
	}
	if ($line =~ m{\A(.*)\bPIC\b}i) {
#TRACE	    print " LIGNE = $lineNumber " . $_;
	    my $deb = $1;
	    if (! ($deb =~ /\bREDEFINES\b/) ) {
		my $offset = length($1);
		if ($previousValueOffset != -1 
		    && $ok == 1                 # niveau identique au précédent
		    && $offset != $previousValueOffset) {
		    # @Code: RULE_PICTURE_INDENT
		    # @Type: PRESENTATION
		    # @Description: Alignement des clauses PICTURE
		    # @Caractéristiques: 
		    #   - Facilité d'analyse
		    # @Commentaires:
		    # @Restriction: 
		    # @TBD: ?
#TRACE	        print STDERR "fichier=" . $filename . "ligne=" . $. . "\n";
		    Cobol::violation::violation2("PRES_PICTURE_INDENT", $filename, $CptLine,"Alignement des clauses PICTURE");
		    $cptPICNotAlign++;
		}
		$previousValueOffset = $offset;
	    }
	}
    }

sub endPictureIndent() {
    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_PICNotAlign(),$cptPICNotAlign);

}


1;
