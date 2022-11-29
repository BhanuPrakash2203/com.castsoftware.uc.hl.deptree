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

my $filename="";
my $StructFichier;

my $cptCompute = 0;
my $cptSimpleCompute = 0;

my $countOpCompute = 0;
my $DansCompute = 0;

sub initCompute ($$) {
    ($StructFichier, $filename)=(@_);
    #Compteur
    $cptCompute = 0;
    $cptSimpleCompute = 0;
    
    $countOpCompute = 0;
    $DansCompute = 0;
}

sub Compute ($$$) {
      	# One line of ProcDiv
        my $line = shift;
	my $CptLine=shift;
	my $NewPara=shift;
	
	Cobol::violation::violationdebug("DEBUG", $filename,$CptLine,"Compute Step 1 $line" );

        # Nous sommes en procedure division
	#print "$filename:$CptLine:COMPUTE1:$line\n";
	if ( $line =~ m{\sCOMPUTE\s+.*\.}i) {
#print "$line\n";
	    $cptCompute++;
	    # @Code: COMPUTE
	    # @Type:  PERFORMANCE EXPRESSION COMPLEXE
	    # @Description: Eviter l'instruction COMPUTE dans le cas d'opération simple
	    # @Caractéristiques: 
	    #   - Performance
	    # @Commentaires: 
	    # @Restriction: Si le compute est sur plusieurs ligne, il est detecte
	    # @RULENUMBER: R37
	    Cobol::violation::violationdebug("DEBUG", $filename,$CptLine,"Compute trouvé Type 1");
	    if (! ($line =~ m{\s(FUNCTION|ROUNDED)\s}i)) {
# 		my $match = $_;
# 		$match =~ s{\w-\w}{}g;
		$countOpCompute = 0;
		$countOpCompute = () = $line =~ /\+|\*|\s-\s/g;
#print "--> countOpCompute = $countOpCompute\n";
#		my $multcomputepossible = $CptLine;
		if ($countOpCompute == 1) {
		    Cobol::violation::violation("RU_CPLX_COMPUTE", $filename,$CptLine,"Violation, Eviter l'instruction COMPUTE dans le cas d'opération simple cas1, $countOpCompute");
		  $cptSimpleCompute++;
#print "      ==> VIOLATION\n";
		}
	    }
	    $countOpCompute = 0;
	    return;
	}
	

	if ( $DansCompute == 1) {

#print "$line\n";
	   Cobol::violation::violationdebug("DEBUG", $filename,$CptLine, "Dans compute $line");
          if ($line =~ m{[^\w-](FUNCTION|ROUNDED)[^\w-]}i) {
	      $DansCompute = 0;
	      $countOpCompute = 0;
	      #en cas de function ou rounded on sort
#	    print "LIGNE ROUNDED $CptLine: $line";
              return;
	  }
	  if ( $line =~ m{^\s*(CLOSE\s|OPEN\s|IF\s|WHEN\s|ELSE\s|MOVE\s|PERFORM\s|CALL\s|EVALUATE\s|READ\s|DISPLAY\s|WRITE\s|REWRITE\s|END-|GO\s|GOTO\s|EXEC\s|ADD\s|DIVIDE\s|INITIALIZE\s|GIVING\s|MULTIPLY\s|STRING\s|ACCEPT\s|NOT\s|\.|\()}i) {
              #Dans le cas de nouvelle instruction , le compute est fini on sort.
	      $DansCompute = 0;
#print "--> countOpCompute = $countOpCompute\n";
	      if ($countOpCompute == 1) {
		  Cobol::violation::violation("RU_CPLX_COMPUTE", $filename,$CptLine,"Violation, Eviter l'instruction COMPUTE dans le cas d'opération simple cas2, $countOpCompute");
		  $cptSimpleCompute++;
#print "      ==> VIOLATION\n";
	      }
	      $countOpCompute = 0;
	      return;
	  }

	  if ($line =~ m{\.\s*\Z}i) {
              #Dans le cas de . en fin de ligne , le compute est fini.
	      $DansCompute = 0;
	      $countOpCompute += () = $line =~ /\+|\*|\s-\s/g;
#print "--> countOpCompute = $countOpCompute\n";
	      if ($countOpCompute == 1) {
		  Cobol::violation::violation("RU_CPLX_COMPUTE", $filename,$CptLine,"Violation, Eviter l'instruction COMPUTE dans le cas d'opération simple cas3, $countOpCompute");
		  $cptSimpleCompute++;
#print "      ==> VIOLATION\n";
	      }
	      $countOpCompute = 0;
	      return;
	  }
	  if ( $line =~ m{\sCOMPUTE\s+}i) {
#print "--> countOpCompute = $countOpCompute\n";
	      if ($countOpCompute == 1) {
		  Cobol::violation::violation("RU_CPLX_COMPUTE", $filename,$CptLine,"Violation, Eviter l'instruction COMPUTE dans le cas d'opération simple cas4, $countOpCompute");
		  $cptSimpleCompute++;
#print "      ==> VIOLATION\n";
	      }
	      $DansCompute = 0;
	  } else {
	      $countOpCompute += () = $line =~ /\+|\*|\s-\s/g;
#print "--> Computing DEFAULT line (= $countOpCompute).\n";
	  }

	}
	if ( $line =~ m{\sCOMPUTE\s+}i) {
#print "$line\n";
	    $cptCompute++;
	    Cobol::violation::violationdebug("DEBUG", $filename,$CptLine,"Compute trouvé type 2");
	    if ($line =~ m{[^\w-](FUNCTION|ROUNDED)[^\w-]}i) {
		$DansCompute = 0;
		$countOpCompute = 0;
		#en cas de function ou rounded on sort
#		print "LIGNE ROUNDED $CptLine: $line";
		return;
	    }
	    $DansCompute = 1;
	    $countOpCompute = 0;
	    $countOpCompute = () = $line =~ /\+|\*|\s-\s/g;
	}


    } # fin boucle ligne

sub endCompute() {
    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_Compute(),$cptCompute);
    Couples::counter_add($StructFichier,Ident::Alias_SimpleCompute(),$cptSimpleCompute);

}




1;
