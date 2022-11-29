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

package Cobol::Vue;

use Erreurs;

require Cobol::violation;

my $Copybook_DeclarationBuffer = undef;
my $CopyBook_ProcedureBuffer = undef;

sub initViews() {
  $Copybook_DeclarationBuffer = undef;
  $CopyBook_ProcedureBuffer = undef;
}

#-----------------------------------------------------------
#            COPYBOOKS management.
#-----------------------------------------------------------

sub isCopybook($) {
  my $r_buffer = shift;

  # regex used is checkCobol !!
  if ($$r_buffer =~ /^[ \t]+(PROCEDURE|IDENTIFICATION)\s+DIVISION/img) {
    return 0;
  }
  return 1;
}

sub isParagraph($) {
  my $r_line = shift;
  if ($$r_line =~ m{^( ){1,4}(\S+)\s*\.}i) {
#print "FOUND A PARAGRAPH : $$r_line\n";
    return 1;
  }
  return 0;
}

sub isCodeSection($) {
  my $r_line = shift;

  if ($$r_line =~ m{^( ){1,4}(\S+)\s+SECTION\.\s*\Z}i) {
    if ( ($1 ne 'FILE') &&
         ($1 ne 'WORKING-STORAGE') &&
	 ($1 ne 'LINKAGE') &&
	 ($1 ne 'COMMUNICATION') &&
	 ($1 ne 'SCREEN') &&
	 ($1 ne 'CONFIGURATION') &&
	 ($1 ne 'INPUT-OUTPUT') ) {

      # say yes if it is not a declarative reserved section.
      return 1;
    }
  }
  return 0;
}

sub isProcedureDivisionBegining($) {
  my $r_line = shift;

  if (isParagraph($r_line)) {
    return 1;
  }
  
  if (isCodeSection($r_line)) {
    return 1;
  }

  return 0;
}

# Copybook can not be separated into explicit zones :
#   ENVIRONMENT DIVISION
#   INPUT-OUTPUT SECTION
#   FILE-SECTION
#   WORKING-SECTION
#   PROCEDURE DIVISION
#
# Two zones will be identified :
#   - declarative (environment, datas ...)
#   - code (executable sections and paragraphs)
#   
# For declaratives data, all algos that initially worked on their
# dedicated buffer will work for copybook on a global declarative buffer.
#
# For PROCEDURE DIVISION, there is no difference, except the mean to detect
# the PROCEDURE DIVISION, base on section and paragraph discovering.




sub createBufferCopybook($) {
  my $r_buffer = shift;

  $Copybook_DeclarationBuffer = "";
  $CopyBook_ProcedureBuffer = "";
  my $PD =0;

#  while ($$r_buffer =~ /(.*\n)/g ) {
#    my $line = $1;
  my @LINES = split /\n/, $r_buffer;
  for my $line (@LINES) {
    $line .= "\n";
    if ($PD == 0) {
      if (isProcedureDivisionBegining(\$line)) {
        $PD = 1;
        $CopyBook_ProcedureBuffer.= $line;
      }
      else {
        $Copybook_DeclarationBuffer .= $line;
      }
    }
    else {
      $CopyBook_ProcedureBuffer.= $line;
    }
  }

}

#-----------------------------------------------------------
#           ALL COBOL FILE management. 
#-----------------------------------------------------------
sub PrepareBuffer ($)
{
  my ($RefBuf) =@_;
  $$RefBuf =~ s/\r//mg;
  #suppression des blancs de fin de ligne
  $$RefBuf =~ s/[ \t]*\n/ \n/mg;

  $$RefBuf =~ s/ID\s+DIVISION/IDENTIFICATION DIVISION/img;


  my $remove6Cols = 0;

  # suppression des 6 premiers
  # caracteres si PROCEDURE|IDENTIFICATION)\s+DIVISION est en colonne 7
  if ($$RefBuf =~ /^[^\*].....[ \t]+(PROCEDURE|IDENTIFICATION)\s+DIVISION/im)
  {
    #       $$RefBuf =~ s/^.?.?.?.?.?.?\n/       \n/mg;
    #$$RefBuf =~ s/^.?.?.?.?.?.?//mg;
    #       $$RefBuf =~ s/\r//mg;
    #       print $$RefBuf ;
    $remove6Cols = 1;
  }
  elsif ( ($$RefBuf =~ /^......./im) &&
	  ($$RefBuf !~ /^......[^\*\$\- D]/im) ) {
    # 7th column does not contains anything else than '*', '$', '-', ' ' or 'D'
    $remove6Cols = 1;
  }
  #elsif ($$RefBuf =~ /^[^\*\$\- D]/img) {
  #  # First column contains anything else than '*', '$', '-', ' ' or 'D'
  #  $remove6Cols = 1;
  #}
  else
  {
    my @message = ("This file seems not be in fix form.",
    "First columns are not removed.");
    for my $item ( @message)
    {
      Erreurs::LogInternalTraces ('warning', undef, undef, 'CheckCobol', 'input file', $item);
    }
  }

  if ($remove6Cols) {

     # This is a Fix Form program.
     # ---------------------------  
     # remove the first six columns
     # remove all what is behind the column 72.
     # ---> Keep only columns 7 to 72
     $$RefBuf =~ s/^.{0,6}([^\n]{0,66})[^\n]*\n/$1\n/mg;

     # in place of :
     #$$RefBuf =~ s/^.?.?.?.?.?.?//mg;
  }

  $$RefBuf =~ s/\r//mg;

  #suppression des 8 digits de fin de ligne
  $$RefBuf =~ s/\d{8}\s*\n/\n/mg;
  
  # ESSAI suppression ligne continuation
  $$RefBuf =~ s/\n\-\s*([^\n]*)\n/$1\n\n/img;

  return $remove6Cols;
}



sub BadZone {
    my($RefBuf,$StructFichier)=(@_);
    my $buflocal = $$RefBuf;
#  print $$RefBuf . "\n\n BADZONE entree  \n";
    my $cpt=0;

    my $INSTR = '(?:COPY|IF|AND|SET|MOVE|DIVIDE|READ|ADD|WRITE|MULTIPLY|PERFORM|OPEN|CLOSE|WHEN|EVALUATE|EXEC|INITIALIZE|GO[ \t]*TO)\b';
    my $END_STUCT = 'END-(?:ADD|CALL|COMPUTE|DELETE|DIVIDE|EVALUATE|EXEC|IF|MULTIPLY|OF-PAGE|PERFORM|READ|RECEIVE|RETURN|REWRITE|SEARCH|START|STRING|SUBTRACT|UNSTRING|WRITE)\b';

    while ($buflocal =~ /(^\s{2,4})(?:$INSTR|$END_STUCT)/gim) {
#        my $match = $2;
#        my $line = $1 . $2;
#        $line =~ s{\n}{}g;
	
	# @Code: BAD_ZONE
	# @Type: PRESENTATION
	# @Description: Instruction en ZONE A (MicroFocus)
	# @Caractéristiques: 
	#   - Portabilité
	# @Commentaires: Pour le moment seul un sous ensemble des instructions est traité.
	# @Restriction: 
	# @RULENUMBER: R34
	$cpt++;
        my $lineNo = (substr($buflocal, 0, pos($buflocal)) =~ tr{\n}{\n}) + 1;
	Cobol::violation::violation("RC_BAD_ZONE2", $StructFichier->{Dat_FileName},$lineNo,"Violation, Pas d instruction en ZONE A");
    }

# on decale les instructions pour ne pas perturber la suite
    $$RefBuf =~ s/^\s{2,4}($END_STUCT)/     $1/img;
    $$RefBuf =~ s/^\s{2,4}($INSTR)/     $1 /img;
    Couples::counter_add($StructFichier,Ident::Alias_BadZoneInst(),$cpt);
}


sub StripComment {
    my($RefBuf,$StructFichier)=(@_);

# ESSAI supression Commentaire
    $$RefBuf =~ s/^[\*D\\][^\n]*\n/\n/img;
    $$RefBuf =~ s/\*>[^\n]*\n/\n/img;

#  print $$RefBuf . "\n StripComment \n";
}

sub StripChaine {
    my($RefBuf,$StructFichier)=(@_);
# ESSAI suppression chaine ""
    $$RefBuf =~ s/"[^"\n]*"/ CHAINEISO /img;
# ESSAI suppression chaine ''
    $$RefBuf =~ s/\'[^\'\n]*\'/ CHAINEISO2 /img;
}


sub IdentDiv {
    my($RefBuf,$StructFichier)=(@_);
    my $buflocal = $$RefBuf;
    while ($buflocal =~ m{
	(
	 IDENTIFICATION\s+DIVISION
	 )
     }gxim) {
        my $lineNo = (substr($buflocal, 0, pos($buflocal)) =~ tr{\n}{\n}) + 1;
	#print "PROCLINE = $lineNo\n";
    Couples::counter_add($StructFichier,"Dat_IdentDivLine",$lineNo);
    }
#    $c =~ s/(\/\*[^*]*\*+([^\/*][^*]*\*+)*\/|\/\/[^\n]*\n)|(\"(\\.|[^\"\\])*\"|\'(\\.|[^\'\\])*\')/defined $1 ? SubstSpace($1) : SubstSpace($3) /gse;
    $$RefBuf =~ s/\G(.*)( IDENTIFICATION\s+DIVISION)/$2/ise;
    $$RefBuf =~ s/\G(.*)( ENVIRONMENT\s+DIVISION.*)/$1/ise;
#   print $$RefBuf;

}


sub EnvDiv {
    my($RefBuf,$StructFichier)=(@_);

    if (defined $Copybook_DeclarationBuffer) {
      $RefBuf = $Copybook_DeclarationBuffer;
      Couples::counter_add($StructFichier,"Dat_EnvDivLine",1);
    }
    else {

    my $buflocal = $$RefBuf;
    while ($buflocal =~ m{
	(
	 ENVIRONMENT\s+DIVISION
	 )
     }gxim) {
        my $lineNo = (substr($buflocal, 0, pos($buflocal)) =~ tr{\n}{\n}) + 1;
	#print "PROCLINE = $lineNo\n";
    Couples::counter_add($StructFichier,"Dat_EnvDivLine",$lineNo);
    }
#    $c =~ s/(\/\*[^*]*\*+([^\/*][^*]*\*+)*\/|\/\/[^\n]*\n)|(\"(\\.|[^\"\\])*\"|\'(\\.|[^\'\\])*\')/defined $1 ? SubstSpace($1) : SubstSpace($3) /gse;
    $$RefBuf =~ s/\G(.*)( ENVIRONMENT\s+DIVISION)/$2/ise;
    $$RefBuf =~ s/\G(.*)( DATA\s+DIVISION.*)/$1/ise;
#   print $$RefBuf;
    }

}

sub DataDiv {
    my($RefBuf,$StructFichier)=(@_);

    if (defined $Copybook_DeclarationBuffer) {
      $RefBuf = $Copybook_DeclarationBuffer;
      Couples::counter_add($StructFichier,"Dat_DataDivLine",1);
    }
    else {

    my $buflocal = $$RefBuf;
    while ($buflocal =~ m{
	(
	 DATA\s+DIVISION
	 )
     }gxim) {
        my $lineNo = (substr($buflocal, 0, pos($buflocal)) =~ tr{\n}{\n}) + 1;
	#print "PROCLINE = $lineNo\n";
    Couples::counter_add($StructFichier,"Dat_DataDivLine",$lineNo);
    }
#    $c =~ s/(\/\*[^*]*\*+([^\/*][^*]*\*+)*\/|\/\/[^\n]*\n)|(\"(\\.|[^\"\\])*\"|\'(\\.|[^\'\\])*\')/defined $1 ? SubstSpace($1) : SubstSpace($3) /gse;
    $$RefBuf =~ s/\G(.*)( DATA\s+DIVISION)/$2/ise;
    $$RefBuf =~ s/\G(.*)( PROCEDURE\s+DIVISION.*)/$1/ise;
#   print $$RefBuf;
    }

}


sub ProcDiv {
    my($RefBuf,$StructFichier)=(@_);

    if (defined $CopyBook_ProcedureBuffer) {
      $RefBuf = $CopyBook_ProcedureBuffer;
      Couples::counter_add($StructFichier,"Dat_ProcDivLine",1);
    }
    else {

    my $buflocal = $$RefBuf;
#   print $$RefBuf . "\n\n gfdskklfd  \n";
#temporaire en attendant la vue sans commentaire
    $buflocal =~ s/\n\*[^\n]*PROCEDURE\s+DIVISION/\n\*TOTO/i;
    while ($buflocal =~ m{
	(
	 PROCEDURE\s+DIVISION
	 )
     }gxim) {
        my $lineNo = (substr($buflocal, 0, pos($buflocal)) =~ tr{\n}{\n}) + 1;
	#print "PROCLINE = $lineNo\n";
    Couples::counter_add($StructFichier,"Dat_ProcDivLine",$lineNo);
    }
#    $c =~ s/(\/\*[^*]*\*+([^\/*][^*]*\*+)*\/|\/\/[^\n]*\n)|(\"(\\.|[^\"\\])*\"|\'(\\.|[^\'\\])*\')/defined $1 ? SubstSpace($1) : SubstSpace($3) /gse;

    $$RefBuf =~ s/\G(.*)( PROCEDURE\s+DIVISION)/$2/ise;
 #  print $$RefBuf;
    }
}


sub InOutSect {
    my($RefBuf,$StructFichier)=(@_);

    if (defined $Copybook_DeclarationBuffer) {
      $RefBuf = $Copybook_DeclarationBuffer;
      Couples::counter_add($StructFichier,"Dat_InOutSectLine",1);
    }
    else {

    my $buflocal = $$RefBuf;
    my $lineNo = -1;
    while ($buflocal =~ m{
	(
	 INPUT-OUTPUT\s+SECTION
	 )
     }gxim) {
        $lineNo = (substr($buflocal, 0, pos($buflocal)) =~ tr{\n}{\n}) + 1;
	#print "PROCLINE = $lineNo\n";
#        Couples::counter_add($StructFichier,"Dat_InOutSectLine",$lineNo);
    }
#    print "PROCLINE = $lineNo\n";
    if ( $lineNo == -1 ) {
	$$RefBuf = "VIDE\n";
    } else {
	
	$$RefBuf =~ s/\G(.*)( INPUT-OUTPUT\s+SECTION)/$2/ise;
	$$RefBuf =~ s/\G(.*)( DATA\s+DIVISION.*)/$1/ise;
    }
    Couples::counter_add($StructFichier,"Dat_InOutSectLine",$lineNo);
#    print $$RefBuf;
    }
}

sub FileSect {
    my($RefBuf,$StructFichier)=(@_);

    if (defined $Copybook_DeclarationBuffer) {
      $RefBuf = $Copybook_DeclarationBuffer;
      Couples::counter_add($StructFichier,"Dat_FileSectLine",1);
    }
    else {

    my $buflocal = $$RefBuf;
    my $lineNo = -1;
    while ($buflocal =~ m{
	(
	 FILE\s+SECTION
	 )
     }gxim) {
        $lineNo = (substr($buflocal, 0, pos($buflocal)) =~ tr{\n}{\n}) + 1;
	#print "PROCLINE = $lineNo\n";
#	Couples::counter_add($StructFichier,"Dat_FileSectLine",$lineNo);
    }
    if ( $lineNo == -1 ) {
	$$RefBuf = "VIDE\n";
    } else {
	
	$$RefBuf =~ s/\G(.*)( FILE\s+SECTION)/$2/ise;
	$$RefBuf =~ s/\G(.*)( WORKING-STORAGE\s+SECTION.*)/$1/ise;
	#la suivante au cas ou
	$$RefBuf =~ s/\G(.*)( PROCEDURE\s+DIVISION.*)/$1/ise;
	#    print $$RefBuf;
    }
	Couples::counter_add($StructFichier,"Dat_FileSectLine",$lineNo);
 
    }

}


sub WorkingSect {
    my($RefBuf,$StructFichier)=(@_);

    my $lineNo;

    if (defined $Copybook_DeclarationBuffer) {
      $RefBuf = $Copybook_DeclarationBuffer;
      Couples::counter_add($StructFichier,"Dat_WorkingSectLine",1);
    }
    else {

    my $buflocal = $$RefBuf;
    while ($buflocal =~ m{
	(
	 WORKING-STORAGE\s+SECTION
	 )
     }gxim) {
        $lineNo = (substr($buflocal, 0, pos($buflocal)) =~ tr{\n}{\n}) + 1;
	#print "PROCLINE = $lineNo\n";
    Couples::counter_add($StructFichier,"Dat_WorkingSectLine",$lineNo);
    }

    # Capture the Working-Storage section, unless this section does'nt exist !
    if ( defined $lineNo) {
#    $c =~ s/(\/\*[^*]*\*+([^\/*][^*]*\*+)*\/|\/\/[^\n]*\n)|(\"(\\.|[^\"\\])*\"|\'(\\.|[^\'\\])*\')/defined $1 ? SubstSpace($1) : SubstSpace($3) /gse;
     #$$RefBuf =~ s/\G(.*)( WORKING-STORAGE\s+SECTION)/$2/ise;
     #$$RefBuf =~ s/\G(.*)( PROCEDURE\s+DIVISION.*)/$1/ise;
     $$RefBuf =~ s/\A.*( WORKING-STORAGE\s+SECTION)/$1/is;
     $$RefBuf =~ s/ PROCEDURE\s+DIVISION.*//is;
    }
    else {
      # There's no Working Section.
      $$RefBuf = "";
    }
#    print $$RefBuf;

    }
}

1;
