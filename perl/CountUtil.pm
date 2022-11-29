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

# Composant: Framework

package CountUtil;

use warnings;
use strict;


#-------------------------------------------------------------------------------
# DESCRIPTION: Module interne separe un buffer en deux partie :
#    - la partie gauche contiendra le debut du buffer jusqu'au premier 'ouvrant',
#      ainsi que tout le code entre le premier ouvrant et le 'fermant' correspondant
#      inclus.
#    - la parie droite contiendra le reste du buffer.
#-------------------------------------------------------------------------------

sub splitAtPeer($$$;$)
{
  my ($r_prog, $open, $close, $max_depth) = @_ ;

  my $left = '';
  my $right = '';
  my $opened = 0;
  my $before_split = 1;

  while ($$r_prog =~ /(.)/sg)
  {
    my $c = $1;
    if ($before_split == 1)
    {
      if ($c eq $open)
      {
        $opened += 1;
      }
      elsif ($c eq $close)
      {
        if ( $opened == 0)
        {
          print STDERR "[SplitAtPeer] Defaut d'appariement des $open et $close..\n";
          #print "$$r_prog\n";
          return (undef, undef);
        }
        $opened -=1 ;
        if ($opened == 0)
        {
          $before_split = 0;
        }
      }
      if ( (! defined $max_depth) ||
	   (($c ne ')' ) && ($opened <= $max_depth)) || 
	   ($opened < $max_depth) ) {
        $left .= $c;
      }
    }
    else
    {
        $right .= $c;
    }
  }

  if ($opened > 0)
  {
    print STDERR "[SplitAtPeer] Defaut d'appariement des $open et $close : un caractere $open n'a pas de correspondance dans $$r_prog\n";
    return (undef, undef) ;
  }

  return (\$left, \$right);
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module interne separe un buffer en deux partie :
#    - la partie gauche contiendra le debut du buffer jusqu'au premier 'ouvrant',
#      ainsi que tout le code entre le premier ouvrant et le 'fermant' correspondant
#      inclus.
#    - la parie droite contiendra le reste du buffer.
#-------------------------------------------------------------------------------

sub backsplitAtPeer($$$;$)
{
  #  "close" and "open" are intentionnally inversed.
  my ($r_prog, $close, $open) = @_ ;

  my $left = '';
  my $right = '';
  my $opened = 0;
  my $before_split = 1;

  my $nmax = (length $$r_prog) - 1;
  my $n = $nmax;

  while ($n > 0)
  {
    my $c = substr ($$r_prog, $n, 1);

    if ($before_split == 1)
    {
      if ($c eq $open)
      {
        $opened += 1;
      }
      elsif ($c eq $close)
      {
        if ( $opened == 0)
        {
          print STDERR "[backsplitAtPeer] $close without $open...\n";
          #print "$$r_prog\n";
          return (undef, undef);
        }
        $opened -=1 ;
        if ($opened == 0)
        {
	   #$before_split = 0;
	   last;
        }
      }
    }
    $n--;
  }

  if ($opened > 0)
  {
    print STDERR "[backsplitAtPeer] $open without $close in $$r_prog\n";
    return (undef, undef) ;
  }

#  print "nmax = $nmax\n";
#  print "n = $n\n";

  $left = substr ($$r_prog, 0, $n);
  $right = substr ($$r_prog, $n, $nmax-$n+1);

#  print "left = $left \n";
#  print "right = $right \n";

  return (\$left, \$right);
}

#-----------------------------------------------------------
#    Split (back & forward) at char with parents matching.
#
#    use a list of chars where the search is stopped once parents
#    have been matched.
#-----------------------------------------------------------

sub splitAtCharWithParenthesisMatching($$) {
  my $stmt = shift;
  my $CharTab = shift;

  my $left = "";
  my $right = undef ;

  my $nbParenthesisOpenned = 0;
  my $nbBracketOpenned = 0;

  my $chars = join('', @$CharTab);
  my $regStop = '['.$chars.']';

  while ( $$stmt =~ /(.)/sg) {
    my $char = $1;
    if (!defined $right) {
      if ($char eq "[") {
        $nbBracketOpenned++;
      }
      elsif ($char eq "(") {
        $nbParenthesisOpenned++;
      }
      elsif ($char eq "]") {
        $nbBracketOpenned--;
      }
      elsif ($char eq ")") {
        $nbParenthesisOpenned--;
      }

      if (($nbBracketOpenned<=0) && ($nbParenthesisOpenned<=0)) {
            if ( $char =~ /$regStop/s) {
	      $right = "";
	    }
      }
    }

    if ( ! defined $right) {
      $left .= $char;
    }
    else {
      $right .= $char;
    }
  }

  if (!defined $right) {
    $right = "";
  }

  return (\$left, \$right);
}

sub backsplitAtCharWithParenthesisMatching($$$;$) {
  my $stmt = shift;
  my $CharTab = shift;
  my $includeStopping = shift;
  my $offset = shift;

  if (!defined $offset) {
    $offset = 0;
  }

  my $regStop;
  if (! scalar @$CharTab) {
    # Stop on any character.
    $regStop = '.';
  }
  else {
    $regStop = "[".join('', @$CharTab)."]";
  }

  my $left = undef;
  my $right = "" ;

  my $nbParenthesisOpenned = 0;
  my $nbBracketOpenned = 0;

  my $nmax = (length $$stmt);

  my $n = $nmax-$offset;

  my $peer = 0;
  my $foundStoping = 0;
  while ( $n >= 0 ) {
    my $char = substr($$stmt, $n, 1);
    $peer = 0;

    if ($char eq "]") {
      $nbBracketOpenned++;
    }
    elsif ($char eq ")") {
      $nbParenthesisOpenned++;
    }
    elsif ($char eq "[") {
      $nbBracketOpenned--;
      $peer = 1;
    }
    elsif ($char eq "(") {
      $nbParenthesisOpenned--;
      $peer = 1;
    }

    if (!$peer) {
      if (($char =~ /$regStop/) && ($nbBracketOpenned<=0) && ($nbParenthesisOpenned<=0))
      {
	  $foundStoping=1;
    	  last;   
      }
    }
    $n--;
  }

#  print "offset = $offset\n";
#  print "nmax = $nmax\n";
#  print "n = $n\n";

  # $includeClosing signifies that the stopping char is affected to the right !
  if ($foundStoping && $includeStopping){
    $left = substr($$stmt, 0, $n);
    $right = substr($$stmt, $n, $nmax-$n+1+$offset);
  }
  else {
    $left = substr($$stmt, 0, $n+1);
    $right = substr($$stmt, $n+1, $nmax-$n+$offset);
  }

#  print "left = $left \n";
#  print "right = $right \n";

  return (\$left, \$right);
}


#-----------------------------------------------------------


# Return lines comprised between Begin & end (included).
sub getBufferLines($$$) {
  my $r_buffer = shift;
  my $BeginLine = shift;
  my $EndLine = shift;

  my $number = $EndLine - $BeginLine + 1;
  $BeginLine--;
  # The ($BeginLine-1) first lines will be skipped ...
  # The ($number) following will be keeped ...
#  if ( $$r_buffer =~ /\A(?:.*\n?){$BeginLine}((?:.*\n?){$number})/) {
#    return $1;
#  }
#  else {
#    return "";
#  }

  # Important to reset the regex serach position !
  pos($$r_buffer) = 0;
  my $idx = 0;
  while ( ($idx < $BeginLine) && ( $$r_buffer =~ /.*?\n/g ) ) {
    $idx++;
  }

  if ( $idx < $BeginLine) {
    return "";
  }
  else {
    if ( $$r_buffer =~ /\G((?:.*\n?){$number})/) {
      return $1;
    }
    else {
      return "";
    }
  }
}



sub IsCommentBefore($) {
  my $agglo = shift;

   if ( $$agglo =~ /(?:\A|\n)C\n*$/s) {
#print " ----> YEEESSSSSSSSSS bravo !!!\n";
     return 1;
   }
   else {
#print " ----> UnCommented (line $line)!!!\n";
     return 0;
   }
}




sub IsCommentBeforeAndAt($) {
  my $agglo = shift;

    # The agglo zone is considered well commented if :
    # - the last line contains a C (signifying comment)
    #     OR
    # - the lines before contain only a comment or are empty lines.
   if ( $$agglo =~ /(?:C[^\n]*|(?:\A|\n)C\n+[^\n]*)\n?$/s) {
#print " ----> YEEESSSSSSSSSS bravo !!!\n";
     return 1;
   }
   else {
#print " ----> UnCommented (line $line)!!!\n";
     return 0;
   }
}

sub UpdateAndTriggers($$$;$) {
    my $r_CompBlocs = shift;    # set of comparison blocs.
    my $CurrentLine = shift;    # the current line number in the indexed view.
    my $updateData = shift;     # the current line data in the indexed view.
    my $forceTrigger = shift;   # 1 : force triggering of callback, regardless to the current line number

    if (!defined $forceTrigger) {
      $forceTrigger = 0;
    }

    for ( my $idx1=0; $idx1 < scalar @{$r_CompBlocs};) {
      my $CompBloc = $r_CompBlocs->[$idx1];
      # Append the updateData to the Agglo bloc ...
      ${$CompBloc->[0]} .= $updateData;

      # For each artifact entry ...
      for  (my $idx2=0; $idx2 < scalar @{$CompBloc->[1]}; ) {
	
	# get data associated to the current artifact.
	my $data = @{$CompBloc->[1]}[$idx2];

        # check if the end-line has been reached ...
        if (( $data->[1] == $CurrentLine) || ($forceTrigger)) {
#print "End of bloc at line $nbline\n";

          # Call the callback and give in parameter ...
	  #    - the agglo bloc
	  #    - the parameters of the callback given by the user.
	  $data->[2]->($CompBloc->[0], $data->[3]);

          # Remove the data set of artifact whose comment comparison has been achieved
#print "removing ARTIFACT data set\n";
	  splice (@{$CompBloc->[1]}, $idx2, 1);

	} 
	else {
          $idx2++;
	}
      }
      # If there remains no more artifact data set to treat, then remove the comparaison bloc.
      if (scalar @{$CompBloc->[1]} == 0 ) {
#print "removing COMPARAISON bloc\n";
        splice (@{$r_CompBlocs}, $idx1, 1);
      } 
      else {
        $idx1++;
      }
    }  # Enf of loop idx1 on @CompBlocs
}




sub checkComment($$) {
  my $r_agglo = shift;
  my $r_T_Data = shift;
  my $nbline =1;
  my $line = "";
  my $idxdata = 0;
  # Sort data ...
  my @sorted = sort { $a->[0] <=> $b->[0] } @{$r_T_Data};
  my @CompBlocs = ();

  my $nb_elements = scalar @sorted;

#print "CheckComment for ".scalar @sorted." data\n";

  pos($$r_agglo) = 0;
  while ($$r_agglo =~ /(.*\n)/g) {
    my $line = $1;

#print "//$nbline//\n";
    # Check if a comparaison bloc should begin at this line, and record it.
    # ------------------------------------------------------
    if ( ($idxdata < $nb_elements) && ( $nbline >= $sorted[$idxdata]->[0]) ) {
#print "ADD a Comp bloc to line $nbline\n";
      # select data that should have comments from this line
      my @admissibleData = ();
      while ( ($idxdata < $nb_elements) && ( $nbline >= $sorted[$idxdata]->[0] ) ) {
#print "    Addind element ...\n";
        push (@admissibleData, $sorted[$idxdata]);
	$idxdata++
      }

      # record a new comparaison bloc beginning at line $nbline
      my $emptyString = "";
      my $agglobloc = [ \$emptyString, \@admissibleData ];
      push @CompBlocs, $agglobloc ;
    }

    # Concat $line to all active comparaison blocs & check if some blocs
    # end at this line.
    # -------------------------------------------------------
    # Description of data :
    #
    # @CompBlocs is a TAB of CompBloc
    # @CompBloc is a RECORD : [ REF($agglobloc) , REF(TAB(@data)) ]
    # @data is a     RECORD : [ $BeginLine, $EndLine, __callback, $params]
    UpdateAndTriggers(\@CompBlocs, $nbline, $line);

    $nbline++;
  }
#print "End checking !! \n";  

  UpdateAndTriggers(\@CompBlocs, -1, "");


}

#---------------------------------------------------------------------
#          Buffer views mapping and extraction
#---------------------------------------------------------------------

my %H_ViewIndexes;

sub initViewIndexes() {
  %H_ViewIndexes = ();
}

sub getViewIndexes() {
  return \%H_ViewIndexes;
}

sub buildViewsIndexes($$$) {
  my $buffer = shift;        # the buffer corresponding to the view we want to
                             # index.
  my $sortedLineTab = shift; # tab of line number for which we want an index.
  my $viewName = shift;      # Name of the view.

  if (scalar @$sortedLineTab == 0) {
    # No line to index...
    return;
  }

  my %H_indexes = ();
  $H_ViewIndexes{$viewName} = \%H_indexes;

  my $idx =0;
  my $currentLine = $sortedLineTab->[$idx];
  my $previousLine = 1;
  my $deltaLine = $currentLine -$previousLine;
  
  while ($idx < scalar @$sortedLineTab) {

    # line number for which we want to retrieves the index in this iteration.
    $currentLine = $sortedLineTab->[$idx];
    $deltaLine = $currentLine - $previousLine;

	while ($deltaLine > 32765) {
		$$buffer =~ /\G(?:[^\n]*\n){32765}/g;
		$deltaLine -= 32765;
	}

    if ($deltaLine) {
      if ( $$buffer =~ /\G(?:[^\n]*\n){$deltaLine}/g ) {                   
#print "[$viewName] Index for line $currentLine is : ".pos($$buffer)."\n";

        $H_indexes{$currentLine} = pos($$buffer);
      }
      else {
#print "[$viewName] Lines $previousLine to $currentLine do not exist !!!\n ";
        last;
      }
    }
    elsif ($currentLine == 1) {
      # if current line is 1 (deltaLine is then always 0), assume that the index
      # of this line in the buffer is 0 !
#print "[$viewName] Index for line $currentLine is 0\n";
      $H_indexes{$currentLine} = 0;
    }
#else {
#print " No index for line $currentLine\n";
#}

    # update lines values for next iteration.
    $previousLine = $currentLine;
    $idx++;
  }
}

sub extractView($$$$) {
  my $buffer = shift;
  my $beginLine = shift;
  my $endLine = shift;
  my $H_indexes = shift;

  my $beginIdx = $H_indexes->{$beginLine};
  my $endIdx = $H_indexes->{$endLine};
#print "extracting from line $beginLine to $endLine  (index $beginIdx to $endIdx)\n";
  return substr $$buffer, $beginIdx, ($endIdx-$beginIdx); 
}

sub extractRoot($$$) {
  my $buffer = shift;
  my $sortedLineTab = shift;
  my $H_indexes = shift;

  my $root_buffer = "";
  my $currentPos = 0;
  my $idx = 0;

  # FIXME : loop is not robust against odd number of indexed lines ...
  while ($idx < scalar @$sortedLineTab) {

    # The root code is the code that is outside the units, that is not inside
    # the intervals of lines defined with begin and end units lines.

    my $beginLine = $sortedLineTab->[$idx    ];
    my $endLine   = $sortedLineTab->[$idx + 1];

    my $beginLinePos = $H_indexes->{$beginLine};
    my $endLinePos = $H_indexes->{$endLine};
    
    # Root code is from current position until begin line of the next unit.
    my $rootCode = substr $$buffer, $currentPos, ($beginLinePos - $currentPos);
    # Note : the endLinePos is the last line of the previous unit. This line
    # should be removed from the root code !!
    #$rootCode =~ s/\A[^\n*]//;
    $root_buffer .= $rootCode;

    # Add a number of blank lines corresponding to the unit.
    $root_buffer .= "\n" x ($endLine - $beginLine);

    $currentPos = $endLinePos;

    $idx+=2; 
  }

  # retrieves what is after the last unit !!!
  my $rootCode = substr $$buffer, $currentPos, -1;
  #$rootCode =~ s/\A[^\n*]//;
  $root_buffer .= $rootCode;

  return $root_buffer;
}

1;

