package Cobol::CobolCommon;

my $IDENTIFER_PATTERN = '[\w-]+';

sub get_IDENTIFER_PATTERN() {
  return $IDENTIFER_PATTERN;
}

sub ParseParagraphs($$) {
    my($r_buffer,$StructFichier)=(@_);

    my $CptLine = 0;
    $CptLine = $StructFichier->{"Dat_ProcDivLine"} - 1 ;
    $CurrentPara = "";
    my %TabPara = ();
    my $PrevPara= " ";
    my %TabPara2 = ();

    my $tmpBuf  = "";
    my $realBuf = "";
    my $r_outputBuffer=\$realBuf;
    my $potentialParaLine;
    my $dotExpected = 0;

    my %ParagraphLine = ();
    $StructFichier->{'ParaLine'}=\%ParagraphLine;

    my $recordPara = sub ($) {
            my $para = shift;

            $ParagraphLine{$CptLine}=$para;

            if (! exists $TabPara{$para}) {
              my %DonneesPara = ();
	      $TabPara{$para} = $CptLine;
              if (exists $TabPara2{$para}) {
	        $TabPara2{$para}->{'ligne'} = $CptLine;
	      }
	      else {
	        $TabPara2{$para} = \%DonneesPara;
	        $TabPara2{$para}->{'ligne'} = $CptLine;
	        $TabPara2{$para}->{'exit'} = 0;
	        $TabPara2{$para}->{'thru'} = 0;
	      }
	    }
         };

    # Iterate on the input buffer
#    while ($$r_buffer =~ /(.*\n)/g ) {
#        my $line = $1;
     my @LINES = split /\n/, $$r_buffer;
     for my $line (@LINES) {
	$line.="\n";
	# Count line.
	$CptLine++;

	# forget blank lines
        if ($line =~ m{\A\s*\Z}) {
	    $$r_outputBuffer .= $line;
	    next;
	}

        #  forget comment or debug lines
        if ($line =~ m{\A\S}) {
	    $$r_outputBuffer .= $line;
	    next;
	} 

        #  forget comment or debug lines
        if ($line =~ m{\A\s*(?:END\s+PROGRAM|PROCEDURE\s+DIVISION)}) {
	    $$r_outputBuffer .= $line;
	    next;
 	} 

	if ( $dotExpected ) {
          if ($line !~ /\A\s*\./) {
            # Not a paragraph, so remove from area A...
            $potentialParaLine =~ s/\A/       /;
            Cobol::violation::violation("RC_BAD_ZONE3", $filename,$CptLine,"Violation, PARA ou pas PARA :Pas d instruction en ZONE A");
	  }
	  else {
            &$recordPara($CurrentPara);
	  }

	  ## Leave dot expecting context
	  #-----------------------------
	  $dotExpected = 0;

	  # commit data in the real buffer.
	  $realBuf.= $potentialParaLine.$tmpBuf;
	  # switch to real buffer.
	  $r_outputBuffer = \$realBuf;
	}

	# an identifier beginning in area A and followed by a dot is a paragraph.
	if ($line =~ m{^ {1,4}($IDENTIFER_PATTERN)[ \t]*(?:(\.)|\s*\Z)}) {

	$CurrentPara = uc($1);

	  if (! defined $2) {
	    $potentialParaLine = $line;

	    ## Enter dot expecting context
	    #-----------------------------
	    $dotExpected = 1;
            # switch to tmp buffer.
	    $r_outputBuffer = \$tmpBuf;
            $tmpBuf = "";
	  }
	  else {
	    $$r_outputBuffer .= $line;

            &$recordPara($CurrentPara);
          }
	}
	else {
	  $$r_outputBuffer .= $line;
	}
    }

    if ($dotExpected) {
          # Not a paragraph, so remove from area A...
          $potentialParaLine =~ s/\A/       /;

	  ## Leave dot expecting context
	  $dotExpected = 0;

	  # commit data in the real buffer.
	  $realBuf.= $potentialParaLine.$tmpBuf.$line;
	  # switch to real buffer.
	  $r_outputBuffer = \$realBuf;
    }

    $StructFichier->{'TabPara'}=\%TabPara;
    $StructFichier->{'TabPara2'}=\%TabPara2;

    return $r_outputBuffer;
}

1;
