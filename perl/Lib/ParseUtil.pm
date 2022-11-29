package Lib::ParseUtil;
# les modules importes
use strict;
use warnings;
#use diagnostics; #FIXME: est-ce compatible Strawberry?
#no warnings 'recursion'; 

use Erreurs;

use CountUtil;

use Lib::Node;
use Lib::NodeUtil;
use StripUtils qw(
                  garde_newlines
                  );
use Lib::Log;

use Exporter 'import';
our @EXPORT_OK = ( 'getNextStatement', 'nextStatement', 'isNextClosingCurlyBrace',
				);
our @EXPORT = ( 'getNextStatement', 'nextStatement', 'getStatementLine', 'getNextStatementLine', 'isNextClosingCurlyBrace',
              );

# prototypes publics
sub Parse($$$$);
sub parseForm();
sub parseEndForm();
sub parseFunction();
sub parseEndFunction();
sub parseMethod();
sub parseEndMethod();

sub isNextForm();
sub isNextEndForm();
sub isNextFunction();
sub isNextEndFunction();
sub isNextMethod();
sub isNextEndMethod();
sub isNextElse();


my $DEBUG=0;

##################################################################
#              UNIQ DEFAULT DATA
##################################################################

my $UNIQ_ID = 0;

sub getUniqID() {
  return $UNIQ_ID++;
}

##################################################################
#               ARTIFACT BUFFER Management
##################################################################

my %H_ARTIFACTS_BUFFER = ();
my %CURRENT_ARTIFACTS = ();
my @ARTIFACT_LIST = ();
my $ARTIFACT_MODE = 0; # 0 ==> DEEP mode
                       # 1 ==> LAST (only the last artifact is updated)
my $ARTIFACT_UPDATE_STATE = 1;

# for UNMODAL ...
my %CURRENT_UNMODAL_ARTIFACTS = ();
my @UNMODAL_ARTIFACT_LIST = ();

sub getCurrentArtifactKey() {
  return $ARTIFACT_LIST[-1];
}

sub setArtifactMode($) {
  $ARTIFACT_MODE = shift;
}

sub setArtifactUpdateState($) {
	$ARTIFACT_UPDATE_STATE = shift;
}


sub getArtifacts() {
  return \%H_ARTIFACTS_BUFFER;
}

sub getArtifact($) {
	my $artiKey = shift;
	return \$H_ARTIFACTS_BUFFER{$artiKey};
}


#-----------------------------------------------------------------------
#                        MODAL ARTIFACTS
#-----------------------------------------------------------------------
# Artifacts that are AFFECTED by $ARTIFACT_MODE
#-----------------------------------------------------------------------

sub newArtifact($;$) {  
  my $name = shift;
  my $line = shift;
  my $key = buildArtifactKeyByData($name,$line);
  $H_ARTIFACTS_BUFFER{$key} = "";

  # reference the buffer of the artifact in the list of openned artifact
  $CURRENT_ARTIFACTS{$key} = \$H_ARTIFACTS_BUFFER{$key};

  # add the artifact to the end of the list of openned artifact.
  push @ARTIFACT_LIST, $key;
  
  return $key;
}

sub beginArtifact($) {
  my $key = shift;
  $CURRENT_ARTIFACTS{$key} = \$H_ARTIFACTS_BUFFER{$key};

  # add the artifact to the end of the list of openned artifact.
  push @ARTIFACT_LIST, $key;
}

sub endArtifact($;$) {
  my $name = shift;
  my $link = shift;
  
  if (exists $CURRENT_ARTIFACTS{$name}) {
    $CURRENT_ARTIFACTS{$name} = undef;
    delete $CURRENT_ARTIFACTS{$name};

    if ($ARTIFACT_LIST[-1] eq $name) {
      pop @ARTIFACT_LIST;
    }
    else {
      Lib::Log::ERROR("artifact $name is not the last of the list.");
      for (my $i; $i < scalar @ARTIFACT_LIST; $i++) {
        if ($ARTIFACT_LIST[$i] eq $name) {
          splice @ARTIFACT_LIST, $i,1;
	}
	else {
          Lib::Log::ERROR("can not find artifact $name in the artifact list.");
	}
      }
    }
    
    # link with encompassing artifact if any ...
    if ((defined $link) && ($ARTIFACT_UPDATE_STATE == 1)) {
		my $key = $ARTIFACT_LIST[-1];
		${$CURRENT_ARTIFACTS{$key}} .= $link;
	}
  }
  else {
    Lib::Log::ERROR("no $name artifact.\n");
  }
}

#-----------------------------------------------------------------------
#                        UNMODAL ARTIFACTS
#-----------------------------------------------------------------------
# Artifacts that are NOT AFFECTED by $ARTIFACT_MODE
#-----------------------------------------------------------------------

sub newUnmodalArtifact($$) {
  my $name = shift;
  my $line = shift;
  my $key = buildArtifactKeyByData($name,$line);
  $H_ARTIFACTS_BUFFER{$key} = "";

  # reference the buffer of the artifact in the list of openned artifact
  $CURRENT_UNMODAL_ARTIFACTS{$key} = \$H_ARTIFACTS_BUFFER{$key};

  # add the artifact to the end of the list of openned artifact.
  push @UNMODAL_ARTIFACT_LIST, $key;
  
  return $key;
}

sub endUnmodalArtifact($) {
  my $name = shift;
  if (exists $CURRENT_UNMODAL_ARTIFACTS{$name}) {
    $CURRENT_UNMODAL_ARTIFACTS{$name} = undef;
    delete $CURRENT_UNMODAL_ARTIFACTS{$name};

    if ($UNMODAL_ARTIFACT_LIST[-1] eq $name) {
      pop @UNMODAL_ARTIFACT_LIST;
    }
    else {
      Lib::Log::ERROR("unmodal artifact $name is not the last of the list.");
      for (my $i; $i < scalar @UNMODAL_ARTIFACT_LIST; $i++) {
        if ($UNMODAL_ARTIFACT_LIST[$i] eq $name) {
          splice @UNMODAL_ARTIFACT_LIST, $i,1;
	}
	else {
          Lib::Log::ERROR("can not find unmodal artifact $name in the artifact list.");
	}
      }
    }
  }
  else {
    Lib::Log::ERROR("no $name artifact.");
  }
}

#-----------------------------------------------------------------------
#                        UPDATE artifacts
#-----------------------------------------------------------------------

sub updateArtifacts($$) {
  my $r_stmt = shift;
  my $r_skippedBlanks = shift;

  if ($ARTIFACT_UPDATE_STATE == 0) {
		return;
  }

  # update UNMODAL
  for my $key (keys %CURRENT_UNMODAL_ARTIFACTS) {
		${$CURRENT_UNMODAL_ARTIFACTS{$key}} .= $$r_stmt . $$r_skippedBlanks; 
  }
    
  # update UNMODAL
  if ($ARTIFACT_MODE == 0) {
    # update all artifacts
    for my $key (keys %CURRENT_ARTIFACTS) {
      #${$CURRENT_ARTIFACTS{$key}} .= ' ' . $$r_stmt . $$r_skippedBlanks; 
      ${$CURRENT_ARTIFACTS{$key}} .= $$r_stmt . $$r_skippedBlanks; 
    }
  }
  elsif (scalar @ARTIFACT_LIST > 0) {
    # update only the last artifact
    my $key = $ARTIFACT_LIST[-1];
    #${$CURRENT_ARTIFACTS{$key}} .= ' ' . $$r_stmt . $$r_skippedBlanks; 
    ${$CURRENT_ARTIFACTS{$key}} .= $$r_stmt . $$r_skippedBlanks; 
  }
}

#--------------------------------------------------------------------------------------
# WARNING:
# Since newArtifact needs a "line" parameter, its call in the following function can not
# be adapted whithout redesigning the whole function (the $line info is not avalaible
# in it).
#--------------------------------------------------------------------------------------

#sub pushArtifact($$) {
#  my $r_tab = shift;
#  my $artifact = shift;
#
#  if (scalar @{$r_tab} > 0) {
#    # Deactivate bufferisation of the previous artifact (the last of the list)
#    endArtifact($r_tab->[-1]);
#  }
#  # The new select artifact becomes the new buffered active one.
#  push(@{$r_tab}, $artifact);
#  newArtifact($artifact);
##print "activate $artifact\n";
#}


# This function is unused, and could not be because pushArtifact is no more available ...

sub popArtifact($$) {
  my $r_tab = shift;
  my $key = shift;

  endArtifact($key);
#print "end of ".$r_tab->[-1]."\n";
  # remove the select from the list.
  pop @{$r_tab};
  if (scalar @{$r_tab} > 0) {
    # re-activate the previous select (the last of the list)
#print "reactivate ".$r_tab->[-1]."\n";
    beginArtifact($r_tab->[-1]);
  }
}

my $SQL_ID = 0;
my @CURRENT_SQL_ARTIFACT = ();
my $UNNAMED_ROUTINE_ID = 0;



##################################################
#                  ENCLOSINGNESS                 #
##################################################

my @ContextEnclosing = ('');

sub enterEnclosing($) {
  my $context = shift;
  push @ContextEnclosing, $context;
#print "**** ENTER ENCLOSING $context\n";
}

sub leaveEnclosing($) {
  my $context = shift;
  if (scalar @ContextEnclosing > 1) {
     my $context = pop @ContextEnclosing;
#print "**** LEAVE ENCLOSING $context\n";
  }
  else {
    Lib::Log::ERROR("enclosing stack error !!");
  }
}

sub getEnclosing() {
  if (scalar @ContextEnclosing > 0) {
    return $ContextEnclosing[-1];
  }
  else {
    Lib::Log::ERROR("current enclosing access error !!");
    return "";
  }
}

sub initEnclosing() {
	@ContextEnclosing = ('');
}



##################################################################
#              STATEMENTS MANAGEMENT
##################################################################
my $r_statements = ();
my $idx_statement = 0;
my $last_idx_statement = 0;
my $moreStatements = 1;
my $lastInstrLine = 1; # line of the last statement returned
my $nextInstrLine = 1;
my $blankedStatement = "";
my $blankedIndentation = "";

my $blanksBeforeStatement = "";
my $r_nextSkippedBlanks = createEmptyStringRef();
my $r_skippedBlanks = createEmptyStringRef();

sub get_idx_statement() {
	return $idx_statement;
}

sub set_idx_statement($) {
	$idx_statement = shift;
}

my $CODE_POS = 0;

sub getCodePos() {
	return $CODE_POS;
}

sub getBlankedIndentation(;$) {
	my $stmt = shift;
	
	if (!defined $stmt) {
		return \$blankedIndentation;
	}
	else {
		my $indent  = "";
		my ($stmtIndent) = $$stmt =~ /^(\s*)/m;
		$indent = $stmtIndent.$blankedIndentation;
		return \$indent;
	}
}


sub getNextBlankedIndentation() {
	
	# $blankedIndentation	--> blanked indentation until the last blanked statement
	# $$r_nextSkippedBlanks --> skipped blanks between last statement et next statement
	# $blankedStatement		--> last statement blanked
	# $nextIndent 			--> blanks at the beginning of the next statement
	
	my ($nextIndent) = ${nextStatement()} =~ /^(\s*)/m;
	# if the blanks preceding the statement contain a new line, then reset the indentation from the new line
	if ($$r_nextSkippedBlanks =~ /\n/) {
		my $blankedIndent = $$r_nextSkippedBlanks.$nextIndent;
		$blankedIndent =~ s/^\s*\n//;
		return \$blankedIndent;
	}
	else {
		my $indent = $blankedIndentation.$$r_nextSkippedBlanks.$blankedStatement.$nextIndent;
		return \$indent;
	}
}

sub setStatementLine($) {
  $lastInstrLine = shift; 
  $nextInstrLine = $lastInstrLine;
}

sub getStatementLine() {
  return $lastInstrLine ;
}

sub getIndentation() {
  return $$r_skippedBlanks.$blanksBeforeStatement ;
}

sub getNextIndentation() {
	if (nextStatement()) {
		${nextStatement()} =~ /^(\s*)/;
		my $indent = ${getSkippedBlanks()}.$1;
		#if ($indent ne $nextIndentation) {
		#	print "INDENTATION FAILURE !!!\n";
		#}
		return $indent;
	}
	else {
		Lib::Log::WARNING("no more statement");
	}
	return undef;
}

#sub getNextIndentation_NEW() {
#	return $nextIndentation;
#}

# Return the line of the next statement. 
sub getNextStatementLine() {
  return $nextInstrLine ;
}

# FIXME : should be renamed : getNextSkippedBlank()
sub getSkippedBlanks() {
  return $r_nextSkippedBlanks;
}

my $BLANK_REGEX = qr/^[\n\s]*$/;

sub setBlankRegex($) {
	my $pattern = shift;
	$BLANK_REGEX = qr/\A${pattern}*\z/;
}

sub skipBlanks() {
	# should be an new ref at each time !!
	# If not, a big side effect will appear on the following expression :
	# 	${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
	# Because getSkippedBlanks() and getNextStatement() are both using $r_nextSkippedBlanks, but
	# getNextStatement() is modifying the content.
	$r_nextSkippedBlanks = createEmptyStringRef();
	while (	($idx_statement < scalar @{$r_statements}) &&
			( $r_statements->[$idx_statement] =~ $BLANK_REGEX ) ){
		$$r_nextSkippedBlanks .= $r_statements->[$idx_statement] ;
		$idx_statement++;
	}
}

sub getIndexOfNextNonBlank($$) {
  my $offset = shift;
  my $idx_nb = shift;

  my $idx = $idx_statement + $offset;

  while ( ($idx < scalar @{$r_statements}) && 
          ( $idx_nb >= 0 ) ) {
    if  ( $r_statements->[$idx] =~ /\S/sm ) {
      $idx_nb--;
    }
    $idx++;
  }
  return $idx - $idx_statement - $offset - 1 ;
}

sub nextNonBlank() {
	return nextStatement(getIndexOfNextNonBlank(0,1));
}

#------------------------- SPLIT PATTERN -------------------------
my @SPLIT_PATTERN = ();

sub register_SplitPattern($) {
	my $SplitPattern = shift;
	push @SPLIT_PATTERN, $SplitPattern;
	Lib::ParseUtil::splitNextStatementOnPattern($SplitPattern);
}

sub release_SplitPattern() {
	pop @SPLIT_PATTERN;
}

#------------------------- INITIALISATION -------------------------
sub initStatementManager($) {

  $r_statements = shift;
  if (scalar @{$r_statements} > 0) {
    $moreStatements = 1;
  }
  else {
    $moreStatements = 1;
  }

  # Initial values ...
  $idx_statement = 0;
  $moreStatements = 1;
  $lastInstrLine = 1; # line of the last statement returned
  $nextInstrLine = 1;
  $CODE_POS = 0;
  $blankedStatement = "";
  $blankedIndentation = "";

  $r_skippedBlanks = createEmptyStringRef();
  # Seek to next statement non blank ...
  skipBlanks();
  if ( $idx_statement == scalar @$r_statements ) {
    $moreStatements = 0;
  }
  
  # init blank indentation 
  $blankedIndentation = $$r_nextSkippedBlanks;
  $blankedIndentation =~ s/^\s*\n//;
  
  $nextInstrLine += () = $$r_nextSkippedBlanks =~ /\n/sg ;
  
  @SPLIT_PATTERN = ();
  $CODE_POS += length($$r_nextSkippedBlanks);
}


# Consume the next statement in the list and return a reference on it.
sub getNextStatement() {
if (! $moreStatements) {
  Lib::Log::ERROR("ERRONEOUS call to getNextSatement() !!!");
  return \"";
}

  # if the blanks preceding the statement contain a new line, then reset the indentation from the new line
  if ($$r_nextSkippedBlanks =~ /\n/) {
	  $blankedIndentation = $$r_nextSkippedBlanks;
	  $blankedIndentation =~ s/^\s*\n//;
  }
  else {
	  $blankedIndentation .= $$r_nextSkippedBlanks.$blankedStatement;
  }

#my $INDENT = $blankedIndentation;
#$INDENT =~ s/ /\./g;
#print STDERR "NEXT = ".${nextStatement()}."\t\tINDENT = $INDENT\n";

  # get the next statement
  my $statement = $r_statements->[$idx_statement++];
  # get the blank statement that follow, so that the 'nextStatement()' function will not point to a blank statement
  $$r_skippedBlanks = $$r_nextSkippedBlanks;
  skipBlanks();
  if ( $idx_statement == scalar @$r_statements ) {
    $moreStatements = 0;
  }
	
  $CODE_POS += length($statement) + length($$r_nextSkippedBlanks);

print STDERR "-----------------------------------------\n" if ( $DEBUG);
print STDERR "[l.".getStatementLine()."] USING : $statement\n" if ( $DEBUG);

  # If the code belong to an artifact, then the statement is concatened to
  # the corresponding buffer. %CURRENT_ARTIFACTS contains the list of buffer associated to
  # each artifact actualy being parsed and registered to record statements ...
  updateArtifacts(\$statement, $r_nextSkippedBlanks);

  $lastInstrLine = $nextInstrLine;
  # Add blanks that are before the statements ...
  ($blanksBeforeStatement) = $statement =~ /^([\n\s]*)/sg ;
  
  # compute blanked statement
  $blankedStatement = $statement;
  $blankedStatement =~ s/\S/ /g;
  
  # Compute statement lines.
  $lastInstrLine += () = $blanksBeforeStatement =~ /\n/sg ;
  $nextInstrLine += () = $statement =~ /\n/sg ;
  
  $nextInstrLine += () = $$r_nextSkippedBlanks =~ /\n/sg ;
  
  # Split next statement with contextual pattern (if any)
  if ((defined $SPLIT_PATTERN[-1]) && (defined nextStatement())) {
	  Lib::ParseUtil::splitNextStatementOnPattern($SPLIT_PATTERN[-1]);
  }
  
  $last_idx_statement = \$statement;
  
  return \$statement;
}

# return the a reference to the next statement without consuming it from the list.
sub nextStatement(;$) {
  my ( $idx ) = @_ ;
  if (!defined $idx) { $idx = 0;}
  $idx += $idx_statement;
   if ( $idx < scalar @$r_statements) {
     return \$r_statements->[$idx];
   }
   else {
     return undef;
   }
}

sub getLastNonBlankStatement() {
	return $last_idx_statement;
}

# insert elements at the specified position (current position by default).
sub insertStatements($$) {
  my ($idx, $elements) = @_;

  if (!defined $idx) {
    $idx = $idx_statement;
  }

  splice (@$r_statements, $idx, 0, @$elements);
  if (scalar @$elements) {
	# if a non nul number of element is inserted, then there remain necessarily statements to process
	$moreStatements=1;
  }
  return;
}

# Replace the specified element with a given list of new elements.
sub replaceSplitStatement($$$) {
  my ($idx, $r_split1, $r_split2) = @_;

  splice (@$r_statements, $idx, 1, $$r_split1, $$r_split2);
  return;
}

# Replace the current element with a given list of new elements.
sub replaceCurrentStatement($$) {
  my ($r_split1, $r_split2) = @_;

  splice (@$r_statements, $idx_statement, 1, $$r_split1, $$r_split2);
  return;
}

# Replace the current element with a given list of new elements.
sub replaceCurrentStatementWithList($) {
  my $list = shift;
  
  splice (@$r_statements, $idx_statement, 1, @$list);
  return;
}

sub splitAndFocusNextStatementOnPos() {
	my $next = \$r_statements->[$idx_statement];
	
	if ( (! defined pos($$next)) or (pos($$next) == 0) ) {
		# we are at the beginning of the statement and we want to focus on : so don't change anything.
		return;
	}
	if (pos($$next) == length $$next) {
		# we are at the end of the statement and we want to focus on, that is to focus on the beginning of the next statement.
		# ==> Consumes this statement ...
		
		#$idx_statement++;
		getNextStatement(); # getNextStatement() consumes the current and focus on the next non-blank statement ...
	}
	else {
		# split current statement at the position 
		splice @$r_statements, $idx_statement, 1, (substr($$next, 0, pos($$next)), substr($$next, pos($$next)));
		# and focus on the second part ...
		#$idx_statement++;
		getNextStatement(); # getNextStatement() consumes the current and focus on the next non-blank statement ...
	}
}

sub splitNextStatementBeforePattern($) {
	my $pattern = shift;
	my $next = nextStatement();
	if ($$next =~ /$pattern/) {
		if ($-[0]) {
			my $posMatched = $-[0];
			pos($$next) = $posMatched;
			if ($posMatched) {
				splice @$r_statements, $idx_statement, 1, (substr($$next, 0, pos($$next)), substr($$next, pos($$next)));
			}
			return $posMatched;
		}
	}
	else {
		return undef;
	}
}

# Use a given pattern to split the next statement in two parts, with
# the pattern between them.
sub splitNextStatementOnPattern($;$) {
  my ($pattern, $KeepPattern) = @_ ;

  if (! defined $KeepPattern) {
    $KeepPattern = 1;
  }

if (! defined nextStatement()) {
	Lib::Log::ERROR("next undefined !!!!");
}
else {
	if (${nextStatement()} =~ /(.*?)(${pattern})(.*)/smi) {
		
		my $left_or_right = 0;
		
		if (defined $2) {

			my @list = ();
			if ( $1 ne '') {
				$left_or_right = 1;
				push @list, $1;
			}

			if ($KeepPattern) { push @list, $2; }

			if ( $3 ne '' ) { 
				$left_or_right = 1;
				push @list, $3;
			}

			splice (@$r_statements, $idx_statement, 1, @list) if ($left_or_right);
		}
	}
}
}

# Use a given pattern to split the next statement after a given pattern.
sub splitNextStatementAfterPattern($) {
  my ($pattern) = @_ ;

  if (${nextStatement()} =~ /^(${pattern})(.*)/smi) {
  #if (defined $1) {
    my @list = ();

    push @list, $1;

    if ( $2 ne '' ) { 
      push @list, $2;
    }

    splice (@$r_statements, $idx_statement, 1, @list);
    return 1;
  }

  return 0;
}

sub splitNextStatementOnExtraClosingParenthesis($) {
  my $solde = shift;
  my $before = "";
  my $after = "";
  my $current = \$before;

#print "[splitNextStatementOnExtraClosingParenthesis] ENTREE...\n";
  if ( ${nextStatement()} =~ /\)/ ) {
    my $s = ${nextStatement()};
    while ($s =~ /([^\(\)]*)([\(\)]|$)/sg ) {

      if ($current == \$after) {
        $$current .= $1.$2;
      } 
      elsif ( $2 eq '(' ) {
        $solde++;Enter
        $$current .= $1.$2;
      }
      elsif ( $2 eq ')' ) {
        $$current .= $1; 
        if ( $solde > 0) {
          $$current .= $2; 
        }
        else {
          $current = \$after;
          $$current .= $2;
        }
        $solde--;
      }
      else {
        $$current.= $1.$2;
      }
    }
#    if (( $before !~ /^[\s\n]*$/ ) && ($after !~ /^[\s\n]*$/ )) {
#print "Part__ 1 : $before\n";
#print "Part__ 2 : $after\n";
#      splice (@$r_statements, $idx_statement, 1, $before, $after);
#    }

    #if $after is empty, then no closing parenthesis has been found, then no need to spleet ...
    if ($after ne "") {
      my $offset = 0;
      $after =~ s/^\)//;
      my $parenthesis = ')';

      # once ')' has been removed from after, if $before is empty and $after is empty, there is no
      # need to split.
      if (( $before !~ /^[\s\n]*$/ ) || ($after !~ /^[\s\n]*$/ )) {

      if ($before =~ /^[\s\n]*$/) {
        $parenthesis = $before.$parenthesis;
	$before = "";
      }

      if ($after =~ /^[\s\n]*$/) {
        $parenthesis = $parenthesis.$after;
	$after = "";
      }

      if ( $before ne "" ) {
	# insert statement at current index whithout removing current statement at this index.
#print "Part 1 : $before\n"; 
        splice (@$r_statements, $idx_statement, 0, $before);
        $offset++;
      }

      # replace current statement with the parenthesis pattern.
      splice (@$r_statements, $idx_statement+$offset, 1, $parenthesis);
#print "Part ". (1+$offset)." : $parenthesis\n"; 
      $offset++;

      if ( $after ne "" ) {
	# insert statement after current index.
        splice (@$r_statements, $idx_statement+$offset, 0, $after);
#print "Part ". (1+$offset)." : $after\n"; 
      }
      }
    }
  }
}


sub isNextClosingCurlyBrace() {
  if ( ${nextStatement()} eq '}' ) {
     return 1;
   }
   return 0;
}



#-----------------------------------------------------------------
# Description : Automatise a try sequence of parse routines.
#
#  - If one routines matches, return the node resulting from the parsing.
#  - If none routine matche, a UnknowKind node is returned
#    parameter) the undef value is returned.
#-----------------------------------------------------------------

sub tryParse_OrUnknow($;$) {
  my $r_try_list = shift ;
  my $callback_param = shift ;

  return tryParse($r_try_list, $callback_param, 1);
}

# By default, a node with kind set to "unknow" and attached to the next
# statement (or statement given in parameter) will be returned
sub parseUnknow_DEFAULT($) {
  my $r_stmt = shift;

  if (defined $r_stmt) {
    # consumes the next statement that is the instruction separator.
    getNextStatement();
    
    return Node(UnknowKind, $r_stmt);
  }

  if (! defined nextStatement() ) {
    return undef;
  }

  return Node(UnknowKind, getNextStatement());
}

my $PARSE_UNKNOW = \&parseUnknow_DEFAULT;

sub registerParseUnknow($) {
  my $callback = shift;
  if (defined $callback) {
    $PARSE_UNKNOW = $callback;
  }
}	

#-----------------------------------------------------------------
# Description : Automatise a try sequence of parse routines.
#
#  - If one routines matches, return the node resulting from the parsing.
#  - If none routine matche, undef is returned.
#-----------------------------------------------------------------
sub tryParse($;$$) {
  my $r_try_list =shift;
  my $callback_param = shift;
  my $mode = shift ;


    if ( ! $moreStatements ) {
Lib::Log::ERROR("tryParse called while no more statement");
    }

  my $node;
  for my $callback ( @$r_try_list ) {
 
    # If a previous parse callback returns undef while the end of the statement
    # list has been encountered, the iteration must end. A unknow node will
    # then be returned. 
    if ( ! $moreStatements ) {
      last;
    }

    # Call the parse function, and retrieves resulting node.
    if (defined $callback_param) {
      $node = $callback->($callback_param);
    }
    else {
      $node = $callback->();
    }

    # if a statement has been parsed, return it.
    if ( defined $node ) {
      return $node;
    }

    # else try again with another parsing callback.
  }

  # MODE 1 :
  # The statement is considered unknow => an unknow node is returned
  if (defined $mode && ($mode==1)) {
    #$node = Node(UnknowKind, getNextStatement());
    $node = $PARSE_UNKNOW->($callback_param);
print STDERR "+++ UNRECOGNIZED ...\n" if ($DEBUG);
    return $node ;
  }

  # by default, undef is returned.
  return undef;
}


sub InitParser($) {

  my $r_stmt = shift;

  %H_ARTIFACTS_BUFFER = ();
  %CURRENT_ARTIFACTS = ();

  $UNIQ_ID = 0;

  $SQL_ID = 0;
  @CURRENT_SQL_ARTIFACT = ();
  $UNNAMED_ROUTINE_ID = 0;

  initStatementManager($r_stmt);

}

my %REG_PEER = (
	'(' => qr /([^\(\)]*)(\(|\)|\Z)/,
	'{' => qr /([^{}]*)(\{|\}|\Z)/,
	'<' => qr /([^<>]*)(<|>|\Z)/,
);

sub parseUntilPeer($$) {
  my $begin = shift;
  my $end = shift;
  my $level =0;
  my $continue = 1;
  my $output = "";
  my $stmt1 = "";
  my $stmt2 = "";
  my $dest = \$stmt1;

  while ( defined nextStatement() && $continue ) {
     $stmt1 = "";
     my $stmt = ${nextStatement()};
    
     my $reg = $REG_PEER{$begin};
    
     if (!defined $reg) {
		 Lib::Log::ERROR("no regexp associated to openning $begin");
	 }
	#while ( ${nextStatement()} =~ /\G([^${begin}${end}]*)(${begin}|${end}|\Z)/simg) {
    #while ( $stmt =~ /([^\(\)]*)(\(|\)|\Z)/simg) {
	 while ( $stmt =~ /$reg/simg) {
      my $code=$1;
      my $sep=$2;
      # begin delimiter
      if ($sep eq $begin) {
        $level++;
	$$dest .= $code.$sep;
      }
      # end delimiter
      elsif ($sep eq $end) {
	$$dest .= $code.$sep;

	if ($level != 0) {
          $level--;
	  if ($level == 0) {
            $continue = 0;
	    $dest = \$stmt2;
	  }
        }
	else {
	  Lib::Log::ERROR("no corresponding '$begin' for '$end'");
	  $continue = 0;
	  $dest = \$stmt2;
	}
      }
      # end of statement
      else {
        $$dest .= $code;
      }
    }
    $output .= $stmt1;
    if ( $level == 0) {
      if ($stmt2 =~ /\S/) {
      # replace current statement by the two stmt1 & $stmt2 (unless stmt2 empty)
        replaceCurrentStatement(\$stmt1, \$stmt2);
      }
      # consumn the current statement (i.e stmt1).
      getNextStatement(); 
      return \$output;
    }
    else {
      # consumn the current statement.
      getNextStatement();
    }
  }
  # unless an algorithmic programing error, we should never execute this line :
  Lib::Log::ERROR("unexpected algorithmic case encountered!");
  return undef;
}


sub purgeSemicolon() {
	while ((defined nextStatement()) && (${nextStatement()} eq ";")) {
		# trash all ";"
		getNextStatement();
	}
}

my $TRIGGERS_parseParenthesis = {};

sub register_TRIGGERS_parseParenthesis($) {
	$TRIGGERS_parseParenthesis = shift;
}

sub parseParenthesis($;$) {
	my $open = shift;
	my $triggers = shift || {};
	my $close;
	my $reg;
	
	my $parenthLine = getStatementLine();
	
	if ($open eq "{") {
		$close = "}";
		$reg = qr/[\{\}]/;
	}
	elsif ($open eq "[") {
		$close = "]";
		$reg = qr/[\[\]]/;
	}
	else {
		$open = "(";
		$close = ")";
		$reg = qr/[()]/;
	}

	# get the openning
	my $statement = ${getNextStatement()};
	my @subNodes = ();
	my $opened = 1;
	my $next;
	while ($opened && defined nextStatement()) {
		
		splitNextStatementOnPattern($reg);
		
		$next = nextStatement();
		
		if (defined $next) {
			
			if ($$next eq $open) { 
				$opened++;
				# consumes the pattern of this iteration
				$statement .= ${getNextStatement()};
			}
			elsif ($$next eq $close) {
				$opened--;
				# consumes the pattern of this iteration
				$statement .= ${getNextStatement()};
			}
			else {
				my $trig;
				if (defined ($trig = $triggers->{$$next})) {
					my ($stmt_update, $nodes_update) = @{$trig->()};
					$statement .= $$stmt_update;
					push @subNodes, @$nodes_update;
				}
                else 
                {
                    $statement .= ${getNextStatement()};
                }
			}	
		}
		else {
			Lib::Log::ERROR("missing \"$close\", openned at line $parenthLine");
			last;
		}
	}
	return [\$statement, \@subNodes];
}


# parse in RAW mode (don't interpret items) until the closing item corresponding to the openning found in next statement when calling the function.
my %H_CLOSING = ( '(' => ')', '{' => '}', '[' => ']', '<' => '>' );

sub parseRawOpenClose() {
	my $stmt = "";
	## get openning
	my $open = ${getNextStatement()};
	$stmt .= $open;
	my $line = getStatementLine();
	## get content
	my $close = $H_CLOSING{$open};
		
	if (! defined $close) {
		Lib::Log::ERROR("no closing for $open at line $line");
		return;
	}
	
	my $nested = 1;
	my $item;
	while (defined ($item=nextStatement()) ) {
		if ($$item eq $open) { $nested++;}
		elsif ($$item eq $close) {$nested--;}
		$stmt .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		last if (!$nested);
	}
			
	if (! defined $item) {
		Lib::Log::ERROR("unterminated open/close opened at line $line");
	}
	return \$stmt;
}

sub parseRawOpenCloseUntil($) {
	my $pattern = shift;
	my $statement = "";
	while (${nextStatement()} !~ /\A$pattern/) {
		splitNextStatementBeforePattern($pattern);
		if (${nextStatement()} =~ /^[\(\[\{]$/m) {
			$statement .= parseRawOpenClose();
		}
		else {
			$statement .= ${getNextStatement()};
		}
	}
	return \$statement;
}

sub getIndexAfterBlank(;$) {
	my $idx = shift || 0;
	while (${nextStatement($idx)} !~ /\S/) {
		$idx++;
		if (! defined nextStatement($idx)) {
			$idx--;
			last;
		}
	}
	return $idx;
}

# Return the relative index (to the current position) of the next item after de closing peer of the current item.
# If not found until end of the statement, return undef.
sub getIndexAfterPeer(;$) {
	my $idx = shift || 0;
	my $openning = ${nextStatement($idx)};
	my $closing = $H_CLOSING{$openning};

	my $nested = 1;
	
	my $stmt;
	$idx++;
	while ($nested && defined ($stmt = nextStatement($idx))) {
		if ($$stmt eq $openning) { $nested++; }
		elsif ($$stmt eq $closing) { $nested--; }
		$idx++;
	}
	
	if ($nested) {
		Lib::Log::ERROR("Unterminated peer !!!") ;
		$idx--; # point to previous item, because item at actual position is undefined.
	}
	
	return $idx; 
}


my $Expression_TriggeringItems = {};

sub register_Expression_TriggeringItems($) {
	$Expression_TriggeringItems = shift;
}

# ending instruction criteria
sub false() {
	return 0;
}
my $nextTokenIsEndingInstruction = \&false;
sub setEndingInstructionsCriteria($) {
	$nextTokenIsEndingInstruction = shift;
}

#------- Accolade setup -----------
my $parseAccolade = \&parseParenthesis;
sub setParseAccolade($) {
	$parseAccolade = shift;
}

sub parse_Expression(;$) {
	my $stopPatterns = shift || {};
	
	my $expression = '';
	my @subNodes = ();

	# get all statement before the first ';' or '}'.
	my $stmt;
	my $trigger;
	my $END_INSTRUCTION = 0;
	my $skippedStatements = ${Lib::ParseUtil::getSkippedBlanks()};
	while ( (defined ($stmt = nextStatement())) && ($$stmt ne ";") && ($$stmt ne "}") &&
			(!defined $stopPatterns || !defined $stopPatterns->{$$stmt}) &&
			(! $END_INSTRUCTION )) {
				
		$expression .= $skippedStatements;

		if ($$stmt eq "(") {
			my (undef, $newSubNodes) = @{Lib::ParseUtil::updateGenericParse(\$expression, undef, Lib::ParseUtil::parseParenthesis('(', $TRIGGERS_parseParenthesis))};
			push @subNodes, @$newSubNodes;
		}
		elsif ($$stmt eq "[") {
			my (undef, $newSubNodes) = @{Lib::ParseUtil::updateGenericParse(\$expression, undef, Lib::ParseUtil::parseParenthesis('[', $TRIGGERS_parseParenthesis))};
			push @subNodes, @$newSubNodes;
		}
		elsif ($$stmt eq "{") {
			# use a function pointer because treatment for "{" is not the same for Java & Groovy
			my (undef, $newSubNodes) = @{Lib::ParseUtil::updateGenericParse(\$expression, undef, $parseAccolade->('{', $TRIGGERS_parseParenthesis))};
			push @subNodes, @$newSubNodes;
		}
		elsif (defined ($trigger = $Expression_TriggeringItems->{$$stmt}) ) {
			my (undef, $newSubNodes) = @{Lib::ParseUtil::updateGenericParse(\$expression, undef, $trigger->())};
			push @subNodes, @$newSubNodes;
		}
		else {
			if (defined ${nextStatement()}) {
				$expression .= ${getNextStatement()};
			}
		}
		
		$skippedStatements = ${Lib::ParseUtil::getSkippedBlanks()};
		if ($nextTokenIsEndingInstruction->(\$expression)) {
			$END_INSTRUCTION = 1;
		}
	}
	
	return (\$expression, \@subNodes, $END_INSTRUCTION);
}

sub parse_Instruction() {
	my ($instruction, $subNodes) = parse_Expression();

	if (defined nextStatement() ) {
		if (${nextStatement()} eq ';') {
			# consumes the ";"
			purgeSemicolon();
		}
	}
	#else {
	#	Lib::Log::ERROR("missing ; after instruction line ".getStatementLine()); 
	#}
	
	return ($instruction, $subNodes);
}

##################################################################
#              Generic bloc of code
#              --------------------
#  Parse a suite af statements and append them to the node given in parameters
#  Parse all statements until the one is recongnized as the end statement.
#  All nodes build are attached to the "CodeBloc" node created.
#
#  parameters :
#  	- kind : kind of the resulting bloc
#  	- isEnd_callback : a ref. array of callback for testing closing statements.
#  	- r_tab_StatementContent : a ref. array of callback for parsing
#  	  authorized instruction in the bloc.
#  	- keepClosing : a flag indicating if the closing statement should be keeped (not consummed) or trashed.
#  	- keepClosing : a flag indicating if the closing statement should be keeped or trashed.
#
# The end token is parsed or not, depending on keepClosing.
# The end criteria is a routine returning 1 if the next token is the end, 0 else.
#
#################################################################
sub parseStatementsBloc($$$$;$$) {
  my ($parent, $isEnd_callback, $r_tab_StatementContent, $keepClosing, $noUnknowNode, $dontWarnUnterminated) = @_;
  my $nbChildFound = 0;
  if (!defined $noUnknowNode) {
    # By default, an unknow statement will produce an unknow node.
    $noUnknowNode = 0;
  }
  
  my $warnUnterminated = 1;
  if ((defined $dontWarnUnterminated) && ($dontWarnUnterminated == 1)) {
      $warnUnterminated = 0;
  }

print "+++ BEGIN CodeBloc\n" if ($DEBUG);
  while ($moreStatements) {

    my $endfound=0;
    for my $cb (@{$isEnd_callback}) {
      if ($cb->()) {
        $endfound = 1;
	last;
      }
    }

    if ( $endfound ) {
      if (! $keepClosing) {
        # Trash the end bloc delimiter statement.
        getNextStatement();
      }
print "+++ END CodeBloc\n" if ($DEBUG);
      return $nbChildFound;
    }
    else {
        if ((defined $noUnknowNode) && ($noUnknowNode==1))
        {
            # Unknow statement does not create an Unknow Kind node.
            my $node = tryParse($r_tab_StatementContent);
            if (defined $node) 
            {
                Append($parent, $node);
                $nbChildFound++;
            }
            else 
            {
               ${$parent->[1]} .= ${getNextStatement()};
            }
        }
        else 
        {
            # Unknow statement creates an Unknow Kind node.
            my $node = tryParse_OrUnknow($r_tab_StatementContent);
            Append($parent, $node);
            $nbChildFound++;
        }
    }
  }
  if ($warnUnterminated) {
	my $line = GetLine($parent);
	if (! defined $line) {
		$line = "???";
	}
	Lib::Log::ERROR("unterminated bloc of code [".GetKind($parent)."], openned at line $line");
  }
  
  return $nbChildFound;
}

sub parseCodeBloc($$$$;$) {
  my ($kind, $isEnd_callback, $r_tab_StatementContent, $keepClosing, $noUnknowNode) = @_;

  my $BlocNode = Node($kind, createEmptyStringRef());
  SetLine($BlocNode,getStatementLine());

  parseStatementsBloc($BlocNode, $isEnd_callback, $r_tab_StatementContent, $keepClosing, $noUnknowNode);
  SetEndline($BlocNode,getStatementLine());
  return $BlocNode;
}

##################################################################
#              Generic end-terminated artifact
#              -------------------------------
#  Parse all statements until one is recongnized as the end statement.
#  All nodes build are attached to the parent node given in parameter.
#
#  The end statement is parsed and added to the parent.
#################################################################
sub __parseStatementBloc__($$$$;$$) {
  my ($parent, $r_tab_StatementContent, $typeBegin, $parseEnd_callback, $keepClosing, $noUnknowNode) = @_;
  my $node;

  if (!defined $keepClosing) {
    # By default, the ending statement is parsed.
    $keepClosing = 0;
  }

  if (!defined $noUnknowNode) {
    # By default, an unknow statement will produce an unknow node.
    $noUnknowNode = 0;
  }

print "+++ Debut de bloc $typeBegin\n" if ($DEBUG);
  while ($moreStatements) {

    if ( defined ($node = $parseEnd_callback->())) {
      Append($parent, $node);
print "+++ FIN block $typeBegin  : ".GetName($parent)."\n" if ($DEBUG);
      return $parent;
    }
    else {
      if ((defined $noUnknowNode) && ($noUnknowNode==1)) {
	# Unknow statement does not create an Unknow Kind node.
        $node = tryParse($r_tab_StatementContent);
	if (defined $node) {
          Append($parent, $node);
	}
	else {
	   ${$parent->[1]} .= ${getNextStatement()};
	}
      }
      else {
	# Unknow statement creates an Unknow Kind node.
	$node = tryParse_OrUnknow($r_tab_StatementContent);
        Append($parent, $node);
      }
    }
  }
  Lib::Log::ERROR("unterminated ".$parent->[0]." block $typeBegin!!!");
  #exit;
  return $parent;
}

# update a parsing infos. A parsing info is a set (statement, node)
# -> update this set of data with additional data.
#    updateInfos has the format : [ \$newStatement, \@newSubNodes ]

sub updateGenericParse($$$) {
	my $statement = shift;
	my $node = shift;
	my $updateInfos = shift;

	# update statement
	$$statement .= ${$updateInfos->[0]};
	
	# update sub nodes.
	if (defined $node) {
		Lib::Node::AddSubNodes($node, $updateInfos->[1]);
	}

	return $updateInfos;
}

##################################################################
#              CONTEXT
#################################################################



##################################################################
#              Parse MarkUp languages
#################################################################

our $STATE_ID = 0;
our $STATE_NODE = 1;
our $STATE_CLOSING_PATTERN = 2;

my @StatesStack = ();

my $cb_appendAsScript = undef;
my $cb_appendAsComment = undef;
my $cb_appendAsHtml = undef;
my $cb_excludeEmptyTags = undef;

sub getNodeSignature($) {
	my $node = shift;
	
	return "__HL__".($node->[0]);
}

sub enterState($$;$) {
	my $context = shift;
	my $newState = shift;
	my $createNode = shift;
	
	if (!defined $createNode) {
		$createNode = 1;
	}
	
	my $oldStateData = $context->{'state'};
	my $newStateData = [];
	my $newNode = undef;
	
	if ($createNode) {
		# Append new Node to node of the parent state.
		$newNode = Node($newState, createEmptyStringRef());
		SetLine($newNode, $context->{'line'});
		# index 7 is free for each analyzer. For JSP, we choose to affect it to the indentation of the tag.
		$newNode->[7] = $context->{'indentation'};
		Lib::NodeUtil::SetName($newNode, $context->{'element'});
		Append($oldStateData->[$STATE_NODE], $newNode);
	}
	
	# Update de state datas:
	$newStateData->[$STATE_ID]   = $newState;
	$newStateData->[$STATE_NODE] = $newNode;
	
print "    --> Entering state ".$newState."\n" if ($DEBUG);
	push @StatesStack, $newStateData;
	$context->{'state'} = $newStateData;
}

sub leaveCurrentState($) {
	my $context = shift; 
###print "[leaveCurrentState]".$StatesStack[-1]->[$STATE_ID]."(${$StatesStack[-1]->[$STATE_NODE]->[1]})"."\n";
	# memorize the node corresponding to the state we are leaving !
	my $childNode = $context->{'state'}->[$STATE_NODE];

	if (scalar @StatesStack > 1) {
		pop @StatesStack;
print "    --> back to state ".$StatesStack[-1]->[$STATE_ID]."(${$StatesStack[-1]->[$STATE_NODE]->[1]})"."\n" if ($DEBUG);
		$context->{'state'} = $StatesStack[-1];
	}
	else {
		Lib::Log::ERROR("can not retrieve missing context !");
	}
	
	# HTML if the default state. Inside an openning/closing tag, there is always at least an HTML content, containing itself (eventually other jsp tags).
	# By default an HTML node is then created. But if this node is empty (contain no statement or no other JSP tags) then this node should be removed.
	# for example :  
	# 	<tag:xx> 
	#		blabla 
	#		<tag:yy/>
	#		patati
	#	</tag:xx>
	#					will produce the following nodes imbrication : TAG_XXX / HTML / TAG_YY
	# and the following 
	# 	<tag:xx>
	#		<tag:yy/>
	#	</tag:xx>
	#					will produce the following nodes imbrication : TAG_XXX / HTML / TAG_YY (the HTML has an empty statement but contain one child)
	# and the following
	# 	<tag:xx>
	#	</tag:xx>
	#					will produce the following nodes imbrication : TAG_XXX / HTML  (unless we remove the useless HTML, because empty and having no child)
	
	if (defined $childNode) {
		
		# EXCLUDE empty HTML node ...
		if (GetKind($childNode) eq 'HTML') {
			my $stmt = Lib::NodeUtil::GetStatement($childNode);
			my $children = Lib::Node::GetChildren($childNode);
		
			# if it's an HTML node without children and whose statement is empty...
			if (($$stmt !~ /\S/s) && (scalar @$children == 0)) {
			#	... then remove it.
				Lib::Node::Detach($childNode);
			}
		}
		# do additional EXCLUDING operation if any.
		elsif (defined $cb_excludeEmptyTags) {
			$cb_excludeEmptyTags->($childNode, $context);
		}
	}
		
	#my $child_signature = getNodeSignature($childNode);
	#appendNodeStatement($context, \$child_signature);
}

sub setStateClosingPattern($$) {
	my $context = shift;
	my $closingPattern = shift;
	
	# record the pattern that will end the tag state.
	$context->{'state'}->[$STATE_CLOSING_PATTERN] = $closingPattern;
}

sub isClosing($$) {
	my $expected = shift;
	my $closing = shift;
	
	# remove blanks because they are not significant
	$closing =~ s/\s*//g;
	
	if ($expected eq $closing) {
		return 1;
	}
	return 0;
}

sub isStateClosingPattern($$) {
	my $context = shift;
	my $element = shift;

	if ($context->{'state'}->[$STATE_CLOSING_PATTERN] eq $element) {
		return 1;
	}
	return 0;
}

sub getStateClosingPattern($) {
	my $context = shift;

	return $context->{'state'}->[$STATE_CLOSING_PATTERN];
}

sub getPreviousState($) {
	my $index = shift; 
	
	# -1 is the current state and the previous state is -2
	# Add 1 : for the user 1 should correspond to the first previous.
	$index++;
	
	# multiply with -1 to have an index from the end of the tab :
	return $StatesStack[-1 * $index];
	
}

sub restoreOpenningTagState($$) {
	my $context = shift;
	my $closing = shift;
#print "[restoreOpenningTagState] restore state of opeening tag corresponding to $closing\n";

	# search the corresponding openning tag state
	my $maxIndex=scalar @StatesStack - 1;
	my $matchedIndex = $maxIndex;
	while ($matchedIndex > 0) {
		my $expecting_closing = $StatesStack[$matchedIndex]->[$STATE_CLOSING_PATTERN];
		if (defined $expecting_closing) {
			if (isClosing($expecting_closing, $closing)) {
#print "--> matched index $matchedIndex !!\n";
				last;
			}
		}
		$matchedIndex--;
	}

	# if $matchedIndex > 0, then $matchedIndex is the index of the state/openning tag corresponding to the closing tag given in parameter.
	if ($matchedIndex > 0) {
		my $i = $maxIndex;
		
		# close (remove from end of stack) all tags until reaching the tag corresponding to the closing tag given in parameter.
#print "will close/remove ".($maxIndex-$matchedIndex)." states !!!\n";
		while ($i > $matchedIndex) {
			if ($StatesStack[-1]->[$STATE_CLOSING_PATTERN]) {
				# the last state in the stack will be removed whereas it is not the openning corresponding tag for the considered closing tag.
				# So, if the state is expecting a closing tag, then there is an error : the tag will be closed without encountering the expected closing tag.
				my $node = $StatesStack[$matchedIndex]->[$STATE_NODE];
				Lib::Log::WARNING("unterminated state : ".Lib::NodeUtil::GetName($node)." at line ".Lib::NodeUtil::GetLine($node));
			}
			leaveCurrentState($context);
			$i--;
		}
#print "    --> back to state ".$context->{'state'}->[$STATE_ID]." for closing it\n"; 
	}
	else {
		Lib::Log::ERROR("no corresponding tag found for $closing");
		return 0;
	}
	return 1;
}

sub appendNodeStatement($$) {
	my $context = shift;
	my $stmt = shift;
	
	# append the contextual JSP element to the contextual node statement.
	my $currentNode = $context->{'state'}->[$STATE_NODE];
	if (defined $currentNode) {
		Lib::NodeUtil::AppendStatement($currentNode, $stmt);
	}
} 

# Append script

sub appendAsScript($$) {
	my ($context, $vues) = @_ ;
	my $blanked_element 	= $context->{'blanked_element'};
	my $element = $context->{'element'};
	$vues->append( 'tag_comment_a'	,  $blanked_element );
    $vues->append( 'html_a'		,  $blanked_element );
    $vues->append( 'script_a'	,  $element );
    $vues->append( 'script_html_a'	,  $element );
    appendNodeStatement($context, \$element);
    
    if (defined $cb_appendAsScript) {
		$cb_appendAsScript->($context, $vues);
	}
}

# Append comment

sub appendAsComment($$) {
	my ($context, $vues) = @_ ;
	my $blanked_element 	= $context->{'blanked_element'};
	my $element = $context->{'element'};
	$vues->append( 'tag_comment_a'	,  $element );
    $vues->append( 'html_a'		,  $blanked_element );
	$vues->append( 'script_a'	,  $element );
	$vues->append( 'script_html_a'	,  $element );
	appendNodeStatement($context, \$element);
	
	if (defined $cb_appendAsComment) {
		$cb_appendAsComment->($context, $vues);
	}
}

sub appendAsCommentContent($$) {
	my ($context, $vues) = @_ ;
	my $blanked_element 	= $context->{'blanked_element'};
	my $element = $context->{'element'};
	$vues->append( 'tag_comment_a'	,  $element );
    $vues->append( 'html_a'		,  $blanked_element );
	$vues->append( 'script_a'	,  $blanked_element );
	$vues->append( 'script_html_a'	,  $blanked_element );
	appendNodeStatement($context, \$element);
	
	if (defined $cb_appendAsComment) {
		$cb_appendAsComment->($context, $vues);
	}
}

# Append HTML

sub appendAsHTML($$) {
	my ($context, $vues) = @_ ;
	my $blanked_element 	= $context->{'blanked_element'};
	my $element 			= $context->{'element'};
	$vues->append( 'tag_comment_a'	,  $blanked_element );
    $vues->append( 'html_a'		,  $element );
    $vues->append( 'script_a'	,  $blanked_element );
    $vues->append( 'script_html_a'	,  $element );
    appendNodeStatement($context, \$element);
    
    if (defined $cb_appendAsHtml) {
		$cb_appendAsHtml->($context, $vues);
	}
}

# Append STRING

sub appendAsScriptString($$) {
	my ($context, $vues) = @_ ;
	my $blanked_element 	= $context->{'blanked_element'};
	# A string content is not appended to the 'code' and 'mix' view
	$vues->append( 'tag_comment_a'	,  $blanked_element );
    $vues->append( 'html_a'		,  $blanked_element );
}

sub appendAsScriptEndString($$$) {
	my ($context, $vues, $str_replace) = @_ ;
	my $blanked_element 	= $context->{'blanked_element'};
	# the string is replace by an encoding ...
    $vues->append( 'script_a'	,  ' '.$str_replace.' ' );
    $vues->append( 'script_html_a'	,  ' '.$str_replace.' ' );
    # the string is blaked ...
	$vues->append( 'tag_comment_a'	,  $blanked_element );
    $vues->append( 'html_a'		,  $blanked_element );
}

# Append BLANKED

sub appendAsBlanked($$) {
	my ($context, $vues) = @_ ;
	my $blanked_element 	= $context->{'blanked_element'};
	my $element 			= $context->{'element'};
	$vues->append( 'tag_comment_a'	,  $blanked_element );
    $vues->append( 'html_a'		,  $blanked_element );
    $vues->append( 'script_a'	,  $blanked_element );
    $vues->append( 'script_html_a'	,  $blanked_element );
}

sub addRegularTriggeringToken($$$) {
	my $context = shift;
	my $token = shift;
	my $callback = shift;
	
	push @{$context->{'reg_trigger_token'}}, [$token, $callback];
}


sub checkTriggeringToken($$) {
	my $context = shift;
	my $vues = shift;
	
	my $element = $context->{'element'};
	my $triggers = $context->{'tokens'};

	my $pattern_matched = 0;
	
	if (defined $triggers) {
		my $callback = $triggers->{$element};
		if (defined $callback) {
			$callback->($context, $vues);
			$pattern_matched = 1;
		}
		else {
			Lib::Log::ERROR("missing callback for token $element !!");
		}
	}
	
	return $pattern_matched;
}

sub checkRegexpTriggeringToken($$) {
	my $context = shift;
	my $vues = shift;
	
	my $element = $context->{'element'};
	my $triggers = $context->{'triggers'};

	my $pattern_matched = 0;
	# TRIGGERING TOKEN ==> LAUNCH ASSOCIATED CALLBACK.
	# Try to match a triggering token to the current element.
	# If one token matches , then call the corresponding callback.
	for my $regular_token (@{$triggers}) {
		if ($element =~  /$regular_token->[0]/m) {
			if (defined $regular_token->[1]) {
				$regular_token->[1]->($context, $vues);
				$pattern_matched = 1;
			}
			else {
				Lib::Log::ERROR("missing callback for triggering token $element !!");
			}
			last;
		}
	}
	
	return $pattern_matched;
}

# Treat all tokens coming in the HTML context.
# Current token is available in  $context->{'element'}
sub cb_HTML($$)
{
	my ($context, $vues)=@_;

	# if the pattern does not trigger anything, then is is a peacefull html element !!
	if ( ! checkRegexpTriggeringToken($context, $vues)) {
		# token is appended as HTML element in the views unless already treated with a dedicated callback triggered by the token ...
		appendAsHTML($context, $vues)
	}
}

sub parseMarkup($$$$$$$;$$$) {
	my $source = shift;
	my $views = shift;
	my $options = shift;
	my $STATES = shift;
	my $additional_views = shift;
	my $appendViewsCallback = shift;
	# note : cb_excludeEmptyTags is not a local variable (do not use "my")!!!
	$cb_excludeEmptyTags = shift;
	my $openServerTags = shift;
	my $closeServerTags = shift;
	my $context = shift;
	
	$DEBUG=1 if (exists $options->{'--debug-strip'});
	
	@StatesStack = ();
	
	# Some datas
	my $position=0;
	my $blanked_element = undef;
	
	# Parsing context
	if (!defined $context) {
		$context={};
    }
	$context->{'trigger'} = [];
	
	# callback
	my $treat_HTML = \&cb_HTML;
	
	# Views.
	my $vues = new Vues( 'text' ); # creation des nouvelles vues a partir de la vue text
	#$vues->setOptionIsoSize(); # config pour (certaines) vues de meme taille

	$vues->declare('tag_comment_a');
	$vues->declare('html_a');
	$vues->declare('script_a');
	$vues->declare('script_html_a');
	
	if (defined $additional_views) {
		for my $view (@$additional_views) {
			$vues->declare($view.'_a');
		}
	}
	
	# init callback for capturing append event.
	($cb_appendAsScript, $cb_appendAsComment, $cb_appendAsHtml) = @$appendViewsCallback;
	
	# Data for string management
	my %strings_values = () ;
	my %strings_counts = () ;
	my %JSP_strings_context = (
      'nb_distinct_strings' => 0,
      'strings_values' => \%strings_values,
      'strings_counts' => \%strings_counts  ) ;
      
    # will be use by states callbacks to acces datas about JSP strings
	$context->{'JSP_string_context'} = \%JSP_strings_context;
	
	my %defaultStatesTreatment = (
		'HTML' 			=>  $treat_HTML,
		'HTML_COMMENT'	=>  $treat_HTML,
	);
	
	# First split
	my @parts = ();
	# if server tags are defined, then pre-split on these tokens
	if (defined $openServerTags) {
		@parts = split ( /(\n|[ \t]+|$openServerTags|$closeServerTags)/i , $$source );
	}
	else {
	# do not split.
		push @parts, $$source;
	}
	
	my $status_strip = 0;
	
	
	my $root_HTML = Node('root', createEmptyStringRef());
	$context->{'state'}=[];
	$context->{'state'}->[$STATE_ID] = 'NOSTATE';
	$context->{'state'}->[$STATE_NODE] = $root_HTML;

	# create and set an HTML state ($state is "HTML") with an associated node.
	my $state = 'HTML' ;
	enterState($context, $state);
	Lib::NodeUtil::SetName($context->{'state'}->[$STATE_NODE], 'HTML_root');
	
	$context->{'line'} = 1;
	$context->{'indentation'} = '';
	my $last_element_is_indentation = 1;
	
	mainloop: for my $partie ( @parts ) {
		# $stripJSPTiming->markTimeAndPrint ('--iter in split: ' . $part . '/' . $#parts  . '  --'); # timing_filter_line
		my $reg ;
		while  (
			# At each iteration, update the split regexpr according to 
			# the current state.
			$reg =  $STATES->{$state}->[1] ,
			$partie  =~ m/$reg/g ) {			
			my $element = $1;  # un morceau de fichier petit
			next if ( $element eq '');

			# manage line number + indentation
			if ($element eq "\n") {
				$context->{'line'}++;
				$context->{'indentation'} = '';
				$last_element_is_indentation = 1;
			}
			elsif (($last_element_is_indentation) && ($element =~ /\A[ \t]+\Z/m)) {
				$context->{'indentation'} .= $element;
			}
			else {
				# if element is not an indentation and the previous was not too,
				# then current element has no indentation, because it is inside a text line.
				if ( ! $last_element_is_indentation) {
					$context->{'indentation'} = undef;
				}
				$last_element_is_indentation = 0;
			}
			
print "ELEMENT = $element\n" if ($DEBUG);
			my $blanked_element = $element ; # les retours a la ligne correspondant.
			# $stripJSPTimingLoop->markTimeAndPrint ('--iter in split internal--');   # timing_filter_line

			$blanked_element =~ s/\S/ /g;
			
			$context->{'element'} = $element;
			$context->{'blanked_element'} = $blanked_element;
			
			# Load triggering token for the current state. 
			$context->{'triggers'} = $STATES->{$state}->[2];
			
			# Call the contextual callback for processing the token.
			# (initialize to default treatment if needed.)
			if (! defined $STATES->{$state}->[0]) {
				$STATES->{$state}->[0] = $defaultStatesTreatment{$state};
			}
			
			if ( defined $STATES->{$state}->[0]) {
				$STATES->{$state}->[0]->($context, $vues);
			}
			else {
				Lib::Log::ERROR("Missing treatment callback for state : $state");
			}
			
			$vues->commit ( $position );
			$position += length( $element);
			$state = $context->{'state'}->[$STATE_ID];
			if (! exists $STATES->{$state}) {
				Lib::Log::ERROR("unknow context : $state");
				$status_strip = 1;
				last mainloop;
			}
		}
	}
	

	# Error status management
	my @return_array ;
	if ($state ne 'HTML') 
	{
		if ($state eq 'HTML_COMMENT') {
			Lib::Log::WARNING("end file in state $state");
		}
		elsif ($state eq 'INCODE') {
			Lib::Log::WARNING("end file in state $state");
		}
		else {
			Lib::Log::ERROR("end file in state $state");
			$status_strip = 1;
		}
	}
	
	$views->{'tag_comment'} = $vues->consolidate('tag_comment_a');
	$views->{'script_string'} = \%JSP_strings_context;
	$views->{'script'} = $vues->consolidate('script_a');
	$views->{'html'} = $vues->consolidate('html_a');
	$views->{'script_html'} = $vues->consolidate('script_html_a');
	$views->{'tag_tree'} = $root_HTML;
	
	if (defined $additional_views) {
		for my $view (@$additional_views) {
			$views->{$view} = $vues->consolidate($view.'_a');
		}
	}
	
	return $status_strip;
}

1;
