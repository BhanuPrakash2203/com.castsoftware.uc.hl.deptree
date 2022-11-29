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

my $CurrentPara;
my $NivEva =0;
my @EvaluaCur;

my $cptMissingDefault = 0;

# Var for init parameters
my $StructFichier;
my $filename;

sub initEvaluate ($$) {

    ($StructFichier,$filename)=(@_);
    #Compteur
    $cptMissingDefault = 0;

    $CurrentPara = "";
    $NivEva = 0;
    @EvaluaCur = ();
}

sub Evaluate ($$$) {
        my $line = shift;
	my $CptLine=shift;
	my $NewPara=shift;

###############################################################################
#  EVALUATE
#  
##############################################################################
	    if ($line =~ m{(^\s+EVALUATE\s)}i) {
                $NivEva++;
		$EvaluaCur[$NivEva] = 0;
#                print "FFF $NivEva \n";
	    }
	    if ($line =~ m{(^\s+END-EVALUATE\b)}i) {
	       if ($EvaluaCur[$NivEva] == 0 ) {
#                   violationdebug("DEBUG",$filename:"$CptLine:PAS BON WHEN OTHER:$NivEva");
		   # @Code: WHEN_OTHER
		   # @Type: CODE
		   # @Description: Les structures EVALUATE doivent avoir un traitement du cas par défaut
		   # @Caractéristiques: 
		   #   - Tolérance aux fautes
		   # @Commentaires: 
		   # @Restriction: 
		   # @RULENUMBER: R15
		   Cobol::violation::violation2("RC_WHEN_OTHER", $filename,$CptLine,"Violation,  Les structures EVALUATE doivent avoir un traitement du cas par défaut WHEN OTHERS");
                   $cptMissingDefault++;
	       } else {
#                   violationdebug("DEBUG",$filename,$CptLine,"OK OK  WHEN OTHER:$NivEva");
	       }
               $NivEva--;
	    }
	    if ($line =~ m{(^\s+WHEN\s+OTHER\s)}i) {
		$EvaluaCur[$NivEva] = 1;
	    }

#########################
#il y a un . sur la ligne
#########################
	    if ($line =~ m{\.\s*\Z}i) {
		
	    }

    } # fin boucle ligne

sub endEvaluate() {
    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_MissingDefaults(),$cptMissingDefault);	
}

1;
