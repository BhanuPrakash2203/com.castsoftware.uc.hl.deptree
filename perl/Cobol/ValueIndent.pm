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
# violation("PRES_VALUE_INDENT", $filename, $lineNumber,"Alignement des clauses VALUE");

use Cobol::violation;

my $StructFichier;
my $filename;

#compteur
my $cptValueNotAlign = 0;

my $ok = 0;
my $previousLevel = -1;
my $previousValueOffset = -1;

sub initValueIndent($$) {
    ($StructFichier,$filename)=(@_);
    #compteur
    $cptValueNotAlign = 0;

    $ok = 0;
    $previousLevel = -1;
    $previousValueOffset = -1;
}    
    
#  print STDERR "Parsing $filename for RULE_VALUE_INDENT ...\n";
    
sub ValueIndent($$) {
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
#		print "$filename:$lineNumber:PR024:Alignement des clauses VALUE\n";
	if ($line =~ m{\A(.*)\bVALUE\s}i) {
            return if ($line =~ m{\A\s+VALUE\s}i);
	    my $offset = length($1);
	    if ($previousValueOffset != -1
                && $ok == 1
		&& $offset != $previousValueOffset) {
#		print "$filename:$lineNumber:PR024:Alignement des clauses VALUE $offset ==prev =>  $previousValueOffset \n";
	        # @Code: RULE_VALUE_INDENT
	        # @Type: PRESENTATION
	        # @Description: Alignement des clauses VALUE
	        # @Caractéristiques: 
	        #   - Facilité d'analyse
	        # @Commentaires:
	        # @Restriction: 
	        # @RULENUMBER ?
	        Cobol::violation::violation2("PRES_VALUE_INDENT", $filename, $CptLine,"Alignement des clauses VALUE");
		$cptValueNotAlign++;
	    }
	    $previousValueOffset = $offset;
	}
    }

sub endValueIndent() {
    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_ValueNotAlign(),$cptValueNotAlign);
}

1;

