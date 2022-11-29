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
# Liste des violations
#violation("RU_CONTIGUS_LEVEL", $filename, $lineNumber, "Les num�ros de niveaux dans les d�clarations ne doivent pas �tre contigus");

use Cobol::violation;

my $StructFichier;
my $filename;

#Compteur
my $cptContigusLevel = 0;

my $ok = 0;
my $previousLevel = -1;
my $lineNumber = 0;


sub initContigusLevel ($$) {
    ($StructFichier,$filename)=(@_);
    #Compteur
    $cptContigusLevel = 0;

    $ok = 0;
    $previousLevel = -1;
    $lineNumber = 0;
}  
#  print STDERR "Parsing $filename for RULE_CONTIGUS_LEVEL ...\n";
  

sub ContigusLevel ($$) {
        my $line = shift;
	my $CptLine=shift;

#	last if ($line =~ m{\A\s+PROCEDURE\s+DIVISION\s*\.}i);
	if ($line =~ m{\A\s+(\d+)\s}) {
            if ($1 == ($previousLevel + 1)) {
	        # @Code: CONTIGUS_LEVEL
	        # @Type: PRESENTATION
	        # @Description: Les num�ros de niveaux dans les d�clarations ne doivent pas �tre contigus
	        # @Caract�ristiques: 
	        #   - Facilit� de modification
	        # @Commentaires:
	        # @Restriction: 
	        # @RULENUMBER: 
	        Cobol::violation::violation2("RU_CONTIGUS_LEVEL", $filename, $CptLine, "Les num�ros de niveaux dans les d�clarations ne doivent pas �tre contigus");
		$cptContigusLevel++;
	    }
            $previousLevel = $1;
	} #else  { $previouslLevel = -1; }
    }

sub endContigusLevel() {
    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_ContigusLevel(),$cptContigusLevel);
}

1;

