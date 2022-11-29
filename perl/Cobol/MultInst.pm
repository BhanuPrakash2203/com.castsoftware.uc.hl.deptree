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

my $cptMultInstOnLine =0;
my $CptLine = 0;
my $CurrentPara = "";

# Var for init parameters
my $StructFichier;
my $filename;

sub initMultInst ($$$) {
    ($StructFichier,$filename)=(@_);

    $cptMultInstOnLine =0;

    $CurrentPara = "";
}

sub MultInst ($$$) {
        my $line = shift;
	my $CptLine=shift;
	my $NewPara=shift;

        if (defined $NewPara) {
          $CurrentPara = $NewPara;
	}
######################################################################
# Instruction sur la même ligne
######################################################################
	#on se debarasse des chaines de caractère
	$line =~ s{\".*\"}{};
	$line =~ s{\'.*\'}{};
	
        if ($line =~ m{^( ){1,4}(\S+)\s*\.\s*\w}i) {
          Cobol::violation::violation2("RC_PARA_PLUS_INST",$filename,$CptLine,"Attention, Il y a quelquechose sur la même ligne que le paragraphe $CurrentPara" );
          $cptMultInstOnLine++;
          return;
        }
	elsif ($line =~ m{\S+\s*\s(COPY|CLOSE|OPEN|IF|WHEN|ELSE|MOVE|PERFORM|CALL|EVALUATE|READ|DISPLAY|WRITE|REWRITE|END-|GO|GOTO|EXEC|ADD|DIVIDE|COMPUTE|INITIALIZE|ACCEPT|EXIT)[^-\w]}i) {
	    return if ($line =~ m{ELSE\s+IF}i);
	    if ($line =~ m{\A\s+END-\w+\b\s*\.*\s*\Z}i) {
	    } else {
		# @Code: RULE_MULT_INST
		# @Type: PRESENTATION
		# @Description: Une seule instruction par ligne
		# @Caractéristiques: 
		#   - Facilité d'analyse
		# @Commentaires:
		# @Restriction: 
		# @RULENUMBER: R30
		Cobol::violation::violation2("PRES_MULT_INST", $filename,$CptLine,"Violation, Instructions sur la même ligne"); 
		$cptMultInstOnLine++;
	    }
	    
	} # Fin procedure division

    } # fin boucleligne

sub endMultInst() {
    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_MultInstOnLine(),$cptMultInstOnLine);
}




1;
