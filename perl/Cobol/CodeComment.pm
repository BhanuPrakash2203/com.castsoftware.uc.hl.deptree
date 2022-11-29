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

#violation(ATD_COMMENT_COBOL, $filename, $., "Code en commentaire :" . $_);

#AFAIRE : case sensitivité

use Cobol::violation;

my @cobolInstruction=
  (
   '\WPIC\W',
   '^\W*FD\W',
   '^\W*DISPLAY\W',
   '^\W*IF\W.*\W', 
   '^\W*ELSE\W.*',
   '^\W*MOVE\W.*',
   '^\W*PERFORM\W.*',
   '^\W*CALL\W.*',
   '^\W*DECLARE\W.*',
   '^\W*EVALUATE\W.*',
   '^\W*READ\W.*',
   '^\W*DISPLAY\W.*',
   '^\W*WRITE\W.*',
   '^\W*VARYING\W.*',
   '^\W*UNTIL\W.*',
   '^\W*REWRITE\W.*',
   '^\W*RECORDING\W.*',
   '^\W*USING\W.*',
   '^\W*END-\w*\W.*',
   '^\W*SELECT\W.*',
   '^\W*FROM\W.*',
   '^\W*GO\W.*',
   '^\W*GOTO\W.*',
   '^\W*WHERE\W.*',
   '^\W*CLOSE\W.*',
   '^\W*OPEN\W.*',
   '^\W*EXEC\W.*',
   '^\W*SOURCE-COMPUTER\W.*', 
   '^\W*COPY\W.*',
   '^\W*ADD\W.*',
   '^\W*INTO\W.*',
   '^\W*TO\W.*',
   '^\W*AND\W.*',
   '^\W*OR\W.*',
   '^\W*THRU\W.*',
   '^\W*UNTIL\W.*',
   '^\W*INITIALIZE\W.*',
   '^\W*FETCH\W.*',
   '^\W*PROCEDURE\W.*',
   '^\W*STRING\W.*',
   '^\W*SET\W.*',
   '^\W*DELETE\W.*',
   '^\W*TRANSFORM\W.*',
   '^\W*WHEN\W.*',
   '^\W*BLOCK\W.*',
#   '^\W*:[\w_-]+\W.*',      # :identificateur (SQL)
#   '^\W*[\w_-]+\s*=\s*\w*', # identificateur =   
   '^\s*0\d\W+\w+.*\.\s*$'  # Declarations '
 );


my @CommentSuspect=
  (
   '\?\s*\?.*',
   '!\s*!.*',
   '\bA\s*V[\x{00e9}e]RIFIER.*',
   '\bA\s*VOIR.*',
   '\bA\s*REVOIR.*',
   '\x{00e0}\s*V[\x{00e9}e]RIFIER.*',
   '\x{00e0}\s*VOIR.*',
   '\x{00e0}\s*REVOIR.*',
   '\bTO\s*DO\b.*',
   '\bFIXME.*',
   '\bTBC.*',
   '\bTBD.*',
   '\bATTENTION.*',
   '\bA\s*FAIRE.*',
   '\x{00e0}\s*FAIRE.*'  
 );

sub searchInList {
  my ($line,@list)=@_;
# print "line <<<<<<$line>>>>>\n";
  my $word;
  foreach $word (@list) {
#    print STDERR "$line ..... $word\n";
#Cobol::violation::violation4("DEBUG", $filename, $CptLine, "$line :::: $word" );
      if ($line =~ m/$word/i) {
#Cobol::violation::violation4("DEBUG", $filename, $CptLine, "$line :::: $word" );

	  return 1;
      }
#modif à faire : ajouter i
  }
  #print "-----------> NOT FOUND\n";
  return 0;
}




sub CodeComment ($$$)
{
    my($buffer,$StructFichier,$filename)=(@_);
    #Compteur
    my $cptCodeCommentLine = 0;
    my $cptSuspiciousComment = 0;

    my $FICHIER= $filename;
    my $CptLine = 0;


    my $LastLine = -2;

# print "Parsing ATD_CODE $filename ...\n";
#  while ($buffer =~ /(.*\n)/g ) {
#        my $line = $1;
   my @LINES = split /\n/, $buffer;
   for my $line (@LINES) {
	$line .= "\n";
        # comptage des lignes
	$CptLine++;
	if ($line =~ m{\A\*}) {
	    # On ne s'interesse qu'au commentaire avec '*'
	    # Les commentaires avec 'D' sont destinés au DEBUG
#	    print $line;
#print "FFF $LastLine $. ffff $CptLine <<<<$line>>>>  \n";
	    if (searchInList($line,@CommentSuspect)) {
#		print "COBOL COMMENT" . $line;
		$cptSuspiciousComment++;
			Cobol::violation::violation4("ATD_COMMENT_COBOL", $filename, $CptLine, "Code suspect : $line" );
	    }
	    if ($LastLine == ($CptLine - 1)) {
#                  && (/^[\s\*]*$/ || /^\*+\s*\d+/) )
		# 2 blocs de code en commentaires séparés par des lignes
		# de commentaires sont considérés que comme 1 seul bloc
		# de code en commentaire
		$LastLine=$CptLine;
	    } elsif (searchInList($line,@cobolInstruction)) {
#		print "dans elseif $line";
		if ($LastLine!=($CptLine - 1 )) {
		    # @Code: ATD_COMMENT_COBOL
		    # @Type: PRESENTATION
		    # @Description: Instruction COBOL en commentaire
		    # @Caractéristiques: 
		    #   - Facilité d'analyse
		    # @Commentaires: Nuit à la lisibilité du programme et peut induire
		    #                le lecteur en erreur
		    # @Restriction: 
		    $line =~ s/[\n\r]//g;
		    my $match = $line;
		    if ( $match =~ m/\b(POUR|DES|ET)\b/i ) {
#			  violationbid(COMMENT_COBOL, $filename, $., $_);
		    } else {
			Cobol::violation::violation2("ATD_COMMENT_COBOL", $filename, $CptLine, "Code en commentaire : $line" );
			$cptCodeCommentLine++;
		    }
		}
		$LastLine=$CptLine;
	    } else {
#		print "dans else $line";
	    }
	}
    } # fin boucle ligne

    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_CodeCommentLine(),$cptCodeCommentLine);
    Couples::counter_add($StructFichier,Ident::Alias_SuspiciousComments(),$cptSuspiciousComment);
}

1;
