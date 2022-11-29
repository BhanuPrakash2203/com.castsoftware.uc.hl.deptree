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

my $Fs_PrevFDLine = 0;
my $Fs_DescrStatus = 0;
my $DansSD = 0;
my $BlockContains = 2;


sub initFileSection ($$) {
    ($StructFichier,$filename)=(@_);
    #Compteur
    $Nbr_NoCopyClause = 0;

    $Fs_PrevFDLine = 0;
    $Fs_DescrStatus = 0;
    $DansSD = 0;
    $BlockContains = 2;
}

sub FileSection ($$) {
    my $line = shift;
    my $CptLine=shift;

	    ###############################
	    if ($line =~ m{^\s+SD\s.*}i) {
		$DansSD = 1;
	    } 
            if ($DansSD != 1) {
		if ($line =~ m{^\s+FD\s.*}i) {
		    $Fs_NbFile++;
		    
		    $Fs_PrevFDLine = $CptLine;
		    $Fs_DescrStatus = 0;
		    $BlockContains = 0;
		}
#TRACE	    print "$_\n";
		if ($line =~ m{^\s+BLOCK\s+CONTAINS\s+(\d+)\s+(RECORDS|CHARACTERS)\s*}i) {
		    $BlockContains = 1;
		    my $BlockValue = $1;
#TRACE	    print "BlockContains = $BlockContains $CptLine  $_";
		    if ( $BlockValue != 0 ) {
			# @Code: BLOCK_CONTAINS_ZERO
			# @Type: ????
			# @Description: BLOCK CONTAINS avec une valeur différente de 0
			# @Restriction:
			# @RULENUMBER: Rxx
			Cobol::violation::violation2("RC_BLOCK_CONTAINS_ZERO", $filename,$Fs_PrevFDLine,"Violation, BLOCK CONTAINS avec une valeur différente de 0 ($BlockValue) ");
#pas de comptage
		    }
		}
#TRACE	    print "Affiche $BlockContains $CptLine\n";
		if ($line =~ m{\.} && ($BlockContains == 0)) {
		    # @Code: NO_BLOCK_CONTAINS
		    # @Type: ????
		    # @Description: Pas de BLOCK CONTAINS
		    # @Restriction:
		    # @RULENUMBER: Rxx
		    Cobol::violation::violation2("RC_NO_BLOCK_CONTAINS", $filename,$Fs_PrevFDLine,"Violation, clause BLOCK CONTAINS absente ");
		    $BlockContains = 2;
#pas de comptage
		}
		if ($line =~ m{^\s+(\d+)\s.*}i) {
		    $Fs_DescrStatus++;
		    if ($Fs_DescrStatus > 1) {
			if ($Fs_PrevFDLine != 0) {
			    # @Code: RULE_NO_CLAUSE_COPY
			    # @Type: ORGANISATION DATA
			    # @Description: Enregistrement de fichier non decrit par l'intermédiaire d'une clause COPY
			    # @Restriction:Ne porte que sur les descriptions non décomposées.
			    # @RULENUMBER: R32
			    Cobol::violation::violation2("ORGA_FDCOPY", $filename,$Fs_PrevFDLine,"Violation, Enregistrement de fichier non decrit dans une clause copy ");
			    $Nbr_NoCopyClause++;
			    $Fs_PrevFDLine = 0;
#pas de comptage
			}
		    }
		    
		}
		
	    }
} # fin boucle ligne

sub endFileSection() {
    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_NoCopyClause(),$Nbr_NoCopyClause);	
	
}




1;
