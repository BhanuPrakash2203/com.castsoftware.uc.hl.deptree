package PHP::ParsePHP;

use strict;
use warnings;

use Lib::Node qw( Leaf Node Append UnknowKind);

use PHP::PHPNode ;
use PHP::PHPNode qw( SetName SetStatement SetLine GetLine IsKind); 

use PHP::ParseUtil;

my $DEBUG=0;

my @sectionContent = ( \&parseCurlyCodeBloc, \&parseIf, \&parseWhile, \&parseDo, \&parseFor, \&parseForeach, \&parseSwitch, \&parseBreak, \&parseFunction, \&parseHTML, \&parseReturn, \&parseThrow, \&parseTry, \&parseCatch, \&parseClass, \&parseInterface
	             ); 

my @ClassContent = ( \&parseFunction, \&parseHTML, \&parseClass
	             ); 

my @rootContent = ( \&parseSection
                    );

my $NullString = '';

my $KEEP_CLOSING = 1;
my $TRASH_CLOSING = 0;

my $shortOpenTag = '<(?:%|\?(?:php)?)';
my $shortCloseTag = '(?:\?|%)>';
my $scriptOpenTag = '<\s*script\s+[^>]*\bphp\b[^>]*>';
my $scriptCloseTag = '<\s*\/\s*script\b[^>]*>';

sub isNextClosingCurlyBrace() {
  if ( ${nextStatement()} eq '}' ) {
     return 1;
   }
   return 0;
}



##################################################################
#              COLON CODE BLOC
#              ---------------
#  Description : old style of control struct bloc content : begins with a colon (':')
#  and ends with a specific keyword (endif, endwhile ...)
#
#  ex : 
#     if ( cond ) :
#          statement1 ;
#          statement2 ;
#     else : 
#          statement1 ;
#          statement2 ;
#     endif;
##################################################################
sub isNextColonCodeBloc() {
   if ( ${nextStatement()} =~ /^\s*:/ism ) {
     return 1;
   }
   return 0;
}  

sub parseColonCodeBloc($$;$) {
  # Callback routine that can recognize the closing instruction of the bloc
  my $r_EndBranchKeyword = shift;
  my $r_FinalStructKeyword = shift;
  my $r_content = shift;

  if (! defined $r_EndBranchKeyword) {
    print "[parseColonCodeBloc] ERROR : bad calling context, callback must be specified\n";
  } 

  if (isNextColonCodeBloc() ) {
      PHP::ParseUtil::splitNextStatementOnPattern('\s*:\s*', 1);
  
    # consums the ":"
    getNextStatement();

    if (!defined $r_content) {
      $r_content = \@sectionContent;
    }

    my $CodeBlocNode=PHP::ParseUtil::parseCodeBloc(ColonBlocKind, $r_EndBranchKeyword, $r_content, $KEEP_CLOSING);

    # Add an explicit empty node if the bloc is empty ...
    if (scalar @{PHP::PHPNode::GetChildren($CodeBlocNode)} == 0) {
      Append($CodeBlocNode, Node(EmptyKind, \$NullString));
    }

    # check if the end of the control struct has been reached ...
    # Trash the keyword if it is the case.
    if (defined nextStatement()) {
      for my $cb (@{$r_FinalStructKeyword}) {
        if ( $cb->() ) { 
  	  # trash the final keyword.
          getNextStatement();
	  last;
        }
      }
    }

    # if the closing delimiter is followed by a (or several) semicolon, trash it.
    trashSemiColon();
    return $CodeBlocNode;
  }
  else {
    return undef;
  }
}

##################################################################
#              CURLY CODE BLOC
#              ---------------
#  Description : control struct bloc content : begins with a curly bracket ('{'),
#  and ends with an ending curly bracket ('}').
##################################################################
sub isNextCurlyCodeBloc() {
   if ( ${nextStatement()} eq '{' ) {
     return 1;
   }
   return 0;
}  

sub parseCurlyCodeBloc(;$) {
  my $content = shift;
  if (isNextCurlyCodeBloc() ) {
    # Trash the begin bloc delimiter statement.
    getNextStatement();

    if (!defined $content) {
      $content = \@sectionContent;
    }

    my $CodeBlocNode=PHP::ParseUtil::parseCodeBloc(CurlyBlocKind,[\&isNextClosingCurlyBrace], $content, $TRASH_CLOSING);
    # if the closing delimiter is followed by a (or several) semicolon, trash it.
    trashSemiColon();

    # Add an explicit empty node if the bloc is empty ...
    if (scalar @{PHP::PHPNode::GetChildren($CodeBlocNode)} == 0) {
      Append($CodeBlocNode, Node(EmptyKind, \$NullString));
    }

    return $CodeBlocNode;
  }
  else {
    return undef;
  }
}

##############################################################################
#          BRANCH of CONTROL STRUCT
##############################################################################

sub parseControlStructBranch($$;$) {
  my $r_EndBranchKeywords = shift;
  my $r_FinalStructKeywords = shift;
  my $r_content = shift;

  if (! defined $r_content) {
    $r_content = \@sectionContent;
  }

  my $node = parseCurlyCodeBloc($r_content);

  # if the block is not a curly delimited bloc ...
  if (! $node ) {
    # ... then try if it is an old style of bloc (delimited with colon and specific keyword (the aim of the callback is to recognize this keyword)...
    $node = parseColonCodeBloc($r_EndBranchKeywords, $r_FinalStructKeywords, $r_content);

    # ... and finally try to recognize a single instruction .
    if (! defined $node) {
      $node = PHP::ParseUtil::tryParse_OrUnknow($r_content);
    }
  }

  return $node;
}

sub trashSemiColon() {
  if (defined nextStatement()) {
    if (${nextStatement()} eq ';') {
      getNextStatement();
    }
  }
}

##############################################################################
#          UNKNOW
##############################################################################

# All unrecognized statement are intended to be semicolon terminated instruction.
# SO, all statement are concatened to re-compose the instruction.
sub parseUnknow() {
  my $stmt = "";

  if (! defined nextStatement() ) { return undef;}

  while (defined nextStatement()&&
         (${nextStatement()} ne';')) {

    $stmt .= ${getNextStatement()};
  }

  my $node;
  if ( $stmt !~ /\S/sm ) {
    $node = Node(EmptyKind, \$stmt); 
  }
  else {
    $node = Node(UnknowKind, \$stmt);
  }

  if ( ! defined nextStatement()) {
    print "syntax ERROR : missing \";\" for instruction at line ".getStatementLine()."\n";
  }  
  else {
    trashSemiColon();
  }
  return $node;
}

##################################################################
#              BREAK
##################################################################

sub isNextBreak() {
   if ( ${nextStatement()} =~ /^break$/ism ) {
     return 1;
   }
   return 0;
}  

sub parseBreak() {
  if ( isNextBreak() ) {
    my $BreakNode = Node(BreakKind, getNextStatement());
    SetLine($BreakNode, getStatementLine());
    trashSemiColon();
    return $BreakNode;
  }
  else {
    return undef;
  }


}

##################################################################
#              SWITCH/CASE
##################################################################

sub isNextSwitch() {
   if ( ${nextStatement()} =~ /^switch$/ism ) {
     return 1;
   }
   return 0;
}  

sub isNextCase() {
   if ( ${nextStatement()} =~ /^case$/ism ) {
     return 1;
   }
   return 0;
}  

sub isNextDefault() {
   if ( ${nextStatement()} =~ /^default$/ism ) {
     return 1;
   }
   return 0;
}  


sub isNextEndswitch() {
   if ( ${nextStatement()} =~ /^endswitch$/ism ) {
     return 1;
   }
   return 0;
}

sub parseCaseDefault() {
  my $kind = ""; 
  if ( isNextCase() ) {
    $kind = CaseKind;	  
  }
  elsif (isNextDefault()) {
    $kind = DefaultKind;	  
  }
  else {
    return undef;
  }

  my $stmt = ${getNextStatement()};

  my $CaseNode = Node($kind, \$stmt);
  SetLine($CaseNode, getStatementLine());

  # Search the next statement with a single ":"
#  while ( (defined nextStatement()) && (${nextStatement()} !~ /(?:[^:]|\A):(?:[^:]|\Z)/) ) {
#    $stmt .= ${getNextStatement()};
#  }
 
#  if ( ! defined nextStatement()) {
#    print "parse ERROR : unterminated SWITCH !\n";
#    return $CaseNode;
#  }

  # split on "::" or ":"
  # then concat all statement that are not a ":"
  PHP::ParseUtil::splitNextStatementOnPattern('\s*::\s*|\s*:\s*', 1);
  while ( (defined nextStatement()) && (${nextStatement()} !~ /^\s*:(?:[^:]|\Z)/) ) {
    if ( ${nextStatement()} =~ /::/) {
      $stmt .= ${getNextStatement()};
    }
    else{
      PHP::ParseUtil::splitNextStatementOnPattern('\s*::\s*|\s*:\s*', 1);
      $stmt .= ${getNextStatement()};
    }
  }

  if (! isNextColonCodeBloc() ) {
    $stmt .= ${getNextStatement()};
  }

  my @EndBranchKeywords = (\&isNextEndswitch, \&isNextClosingCurlyBrace, \&isNextCase, \&isNextDefault, \&isNextBreak);
  my @FinalStructKeywords = ();
  my $BranchNode = parseControlStructBranch(\@EndBranchKeywords, \@FinalStructKeywords);

  my $BreakNode = parseBreak();
  if ( defined $BreakNode) {
    Append($BranchNode, $BreakNode);
  }

  Append($CaseNode, $BranchNode);

  return $CaseNode;

}

sub parseSwitch($$$$) {

  if ( isNextSwitch() ) {
    my $SwitchNode = Node(SwitchKind, \$NullString);
    SetStatement($SwitchNode, getNextStatement());
    SetLine($SwitchNode, getStatementLine());
    my $ID = PHP::ParseUtil::getUniqID();
    SetName($SwitchNode, "SWITCH_".$ID);
print "+++ SWITCH ...(line ".GetLine($SwitchNode).")\n" if ($DEBUG);

    # CONDITION
    my $CondNode = parseCondition();
    if ( defined $CondNode ) {
      # For a switch, it is not a real "condition". Concat the statement to 
      # the switch statement, and trashes the condition node.
      ${GetStatement($SwitchNode)} .= ' '. ${GetStatement($CondNode)};
    }
    else {
      print "parse ERROR : missing tested item for SWITCH ...\n";
    }

    my @EndBranchKeywords = (\&isNextEndswitch, \&isNextClosingCurlyBrace);
    my @FinalStructKeywords = (\&isNextEndswitch);
    my @content = (\&parseCaseDefault);
    my $BranchNode = parseControlStructBranch(\@EndBranchKeywords, \@FinalStructKeywords, \@content);
    Append($SwitchNode, $BranchNode);

    return $SwitchNode;
  }
  else {
    return undef;
  }
}


##################################################################
#              CONDITION
##################################################################

sub parseCondition() {
  if (${nextStatement()} =~ /^\s*\(/ism ) {
    my $r_cond = PHP::ParseUtil::parseUntilPeer('(', ')');
    return Node(CondKind, $r_cond);
  }
  else {
    print "parse ERROR : no parenthesized condition found\n";
    return undef;
  }
}


##################################################################
#              GENERIC LOOP
##################################################################

sub parseLoop($$$$) {
  my $tag = shift;
  my $kind = shift;
  my $r_isNext = shift;
  my $r_isNextEnd = shift;

  if ($r_isNext->() ) {
    my $LoopNode = Node($kind, \$NullString);
    SetStatement($LoopNode, getNextStatement());
    SetLine($LoopNode, getStatementLine());
    my $ID = PHP::ParseUtil::getUniqID();
    SetName($LoopNode, "${tag}_".$ID);
print "+++ ${tag} ...(line ".GetLine($LoopNode).")\n" if ($DEBUG);

    # CONDITION
    my $CondNode = parseCondition();
    if ( defined $CondNode ) {
      Append($LoopNode, $CondNode)
    }
    else {
      print "parse ERROR : missing condition for ${tag} ...\n";
    }

    my @EndBranchKeywords = ($r_isNextEnd);
    my @FinalStructKeywords = ($r_isNextEnd);
    my $BranchNode = parseControlStructBranch(\@EndBranchKeywords, \@FinalStructKeywords);

    Append($LoopNode, $BranchNode);

    return $LoopNode;
  }
  else {
    return undef;
  }
}

##################################################################
#              FOREACH
##################################################################

sub isNextForeach() {
   if ( ${nextStatement()} =~ /^foreach$/ism ) {
     return 1;
   }
   return 0;
}  

sub isNextEndforeach() {
   if ( ${nextStatement()} =~ /^endforeach$/ism ) {
     return 1;
   }
   return 0;
}

sub parseForeach() {
  my $node = parseLoop("FOREACH", ForeachKind, \&isNextForeach, \&isNextEndforeach);
  if (defined $node) {
    # Change kind of condition.
    # It is not a regular conditional expression...
    PHP::PHPNode::GetChildren($node)->[0]->[0] = ForeachCondKind;
  }
  return $node;
}

##################################################################
#              FOR
##################################################################

sub isNextFor() {
   if ( ${nextStatement()} =~ /^for$/ism ) {
     return 1;
   }
   return 0;
}  

sub isNextEndfor() {
   if ( ${nextStatement()} =~ /^endfor$/ism ) {
     return 1;
   }
   return 0;
}

sub parseFor() {
  return parseLoop("FOR", ForKind, \&isNextFor, \&isNextEndfor);
}

##################################################################
#              WHILE
##################################################################

sub isNextWhile() {
   if ( ${nextStatement()} =~ /^while$/ism ) {
     return 1;
   }
   return 0;
}  

sub isNextEndwhile() {
   if ( ${nextStatement()} =~ /^endwhile$/ism ) {
     return 1;
   }
   return 0;
}

sub parseWhile() {
  return parseLoop("WHILE", WhileKind, \&isNextWhile, \&isNextEndwhile);
}

##################################################################
#              DO-WHILE
##################################################################

sub isNextDo() {
   if ( ${nextStatement()} =~ /^do$/ism ) {
     return 1;
   }
   return 0;
}

sub isEndDoWhile($) {
  my $node = shift;

  my $children = PHP::PHPNode::GetChildren($node);

  # Check following patter : "while (...);"
  # A while is a end-do compliant while if :
  if ( scalar @{$children} < 2 ) {
    # its node contains only the "condition" chhild,
    return 1;
  }
  elsif (IsKind($children->[1], EmptyKind)) {
    # or if the second child (after the condition), is an empty statement ...
    return 1;
  }
  else {
    return 0;
  }
}

sub makeEndDoWhile($) {
  my $node = shift;

  # change kind of the node
  $node->[0] = EndDoWhileKind;

  # Keep only the "condition" child (the first one ...)
  $node->[2] = [ $node->[2]->[0] ];
  return $node;
}

sub parseDo() {
  if (isNextDo() ) {
    my $DoNode = Node(DoKind, \$NullString);
    SetStatement($DoNode, getNextStatement());
    SetLine($DoNode, getStatementLine());
    my $ID = PHP::ParseUtil::getUniqID();
    SetName($DoNode, "DO_".$ID);
print "+++ DO ...(line ".GetLine($DoNode).")\n" if ($DEBUG);

    # try to parse un Curly braced bloc or a single instruction.
    my $BranchNode = PHP::ParseUtil::tryParse_OrUnknow(\@sectionContent);
    my $WhileNode;

    if (defined $BranchNode) {
      if (IsKind($BranchNode, WhileKind) && (isEndDoWhile($BranchNode))) {
	# If the branch is a end-do compliant while, it is the end of the loop.
	# The content of the loop will be empty.
        $WhileNode = $BranchNode;
	Append($DoNode, Node(EmptyKind, \$NullString));
      }
      else {
	# Else add the statement to the loop content.
        Append($DoNode, $BranchNode);
        $WhileNode = parseWhile();
      }
    }
    else {
      # parse and add statements until the end do while is found.
      while ( defined nextStatement() ) {
        my $node = parseWhile();
	if (defined $node) {
	  # End do while found.
	  if (isEndDoWhile($node) ) {
	    $WhileNode = $node;
	    last;
          }
	  else {
            Append($DoNode, $node);
	  }
	}
	else {
	  # parse loop content and add statements.
          $node = PHP::ParseUtil::tryParse_OrUnknow(\@sectionContent);
          Append($DoNode, $node);
        }
      }
    }

    if (defined $WhileNode) {
      $WhileNode = makeEndDoWhile ($WhileNode);
      Append($DoNode, $WhileNode);
    }
    else {
      print "parse ERROR : unterminated DO-WHILE ...\n";
    }

    return $DoNode;
  }
  else {
    return undef;
  }
}

##################################################################
#              IF
##################################################################

sub isNextIf() {
   if ( ${nextStatement()} =~ /^if$/ism ) {
     return 1;
   }
   return 0;
}  

sub isNextElse() {
   if ( ${nextStatement()} =~ /^else$/ism ) {
     return 1;
   }
   return 0;
}  

sub isNextElseif() {
   if ( ${nextStatement()} =~ /^else\s*if$/ism ) {
     return 1;
   }
   return 0;
}

sub isNextEndif() {
   if ( ${nextStatement()} =~ /^endif$/ism ) {
     return 1;
   }
   return 0;
}

sub parseIf() {
  if (isNextIf() ) {
    my $IfNode = Node(IfKind, \$NullString);
    SetStatement($IfNode, getNextStatement());
    SetLine($IfNode, getStatementLine());
    my $ID = PHP::ParseUtil::getUniqID();
    SetName($IfNode, "IF_".$ID);
print "+++ IF ...(line ".GetLine($IfNode).")\n" if ($DEBUG);

    # CONDITION
    my $CondNode = parseCondition();
    if ( defined $CondNode ) {
      Append($IfNode, $CondNode)
    }
    else {
      print "parse ERROR : missing condition for IF ...\n";
    }

    # THEN (create an implicit 'then'
    my $ThenNode = Node(ThenKind, \$NullString);
    Append($IfNode, $ThenNode);

    if (! (isNextElse() || isNextElseif())) {
      my @EndBranchKeywords = (\&isNextElseif, \&isNextElse, \&isNextEndif);
      my @FinalStructKeywords = (\&isNextEndif);
      my $BranchNode = parseControlStructBranch(\@EndBranchKeywords, \@FinalStructKeywords);

      Append($ThenNode, $BranchNode);

    }

    my $else_encountered = 0;
    while ( (! $else_encountered) &&
	    ( defined nextStatement()) &&
            ( (isNextElse() || isNextElseif())) ) {

      # ELSEIF
      if (isNextElseif()) {
print "+++ ELSEIF ...\n" if ($DEBUG);
        my $ElseifNode = Node(ElsifKind, \$NullString);
        SetStatement($ElseifNode, getNextStatement());
        SetLine($ElseifNode, getStatementLine());
        my $ID = PHP::ParseUtil::getUniqID();
        SetName($ElseifNode, "ELSEIF_".$ID);
	Append($IfNode, $ElseifNode);
        # CONDITION
        my $CondNode = parseCondition();
        if ( defined $CondNode ) {
          Append($ElseifNode, $CondNode)
        }
        else {
          print "parse ERROR : missing condition for ELSEIF ...\n";
        }

	# parse the branch, unless the next statement is a elseif or a else, .
	# If the branch is a semicolon-bloc, then it will end with the statements
	# "endif", "elseif" or "else"
	if (! (isNextElse() || isNextElseif())) {
          my @EndBranchKeywords = (\&isNextElseif, \&isNextElse, \&isNextEndif);
          my @FinalStructKeywords = (\&isNextEndif);
          my $BranchNode = parseControlStructBranch(\@EndBranchKeywords, \@FinalStructKeywords);
          Append($ElseifNode, $BranchNode);
        }
      }
      # ELSE
      elsif (isNextElse()) {
print "+++ ELSE ...\n" if ($DEBUG);
        my $ElseNode = Node(ElseKind, \$NullString);
        SetStatement($ElseNode, getNextStatement());
        SetLine($ElseNode, getStatementLine());
        my $ID = PHP::ParseUtil::getUniqID();
        SetName($ElseNode, "ELSE_".$ID);
	Append($IfNode, $ElseNode);

	# Parse the branch. If it is a semicolon-bloc, then the branch will end
	# with the statement "endif".
        my @EndBranchKeywords = (\&isNextEndif);
        my @FinalStructKeywords = (\&isNextEndif);
        my $BranchNode = parseControlStructBranch(\@EndBranchKeywords, \@FinalStructKeywords);
        Append($ElseNode, $BranchNode);

        $else_encountered = 1;
      }

    }

    return $IfNode;
  }
  else {
    return undef;
  }
}

##################################################################
#              RETURN
##################################################################
sub isNextReturn() {
   if ( ${nextStatement()} =~ /[^\$]\breturn\b/si ) {
     return 1;
   }
   return 0;
} 

sub parseReturn() {
  if ( isNextReturn() ) {
    my $stmt = ${getNextStatement()};
    my $ReturnNode = Node(ReturnKind, \$stmt);
    SetLine($ReturnNode, getStatementLine());
    while ( (defined nextStatement()) && (${nextStatement()} ne ";")) {
      $stmt .= ${getNextStatement()};
    }

    if ( ! defined nextStatement()) {
      print "parse ERROR : missing semi-colon for return at line : ".getStatementLine()."\n";
    }
    else {
      trashSemiColon();
    }
    return $ReturnNode;
  }
  else {
    return undef;
  }


}


##################################################################
#              THROW
##################################################################
sub isNextThrow() {
   if ( ${nextStatement()} =~ /[^\$]\bthrow\b/si ) {
     return 1;
   }
   return 0;
} 

sub parseThrow() {
  if ( isNextThrow() ) {
    my $ThrowNode = Node(ThrowKind, getNextStatement());
    SetLine($ThrowNode, getStatementLine());
    trashSemiColon();
    return $ThrowNode;
  }
  else {
    return undef;
  }


}


##################################################################
#              TRY/CATCH
##################################################################
sub isNextTry() {
   if ( ${nextStatement()} =~ /[^\$]\btry\b/si ) {
     return 1;
   }
   return 0;
} 

sub isNextCatch() {
   if ( ${nextStatement()} =~ /[^\$]\bcatch\b/si ) {
     return 1;
   }
   return 0;
} 

sub parseTryCatch($$) {
    my $kind = shift;
    my $tag = shift;

    my $stmt = ${getNextStatement()};
    my $Node = Node($kind, \$stmt);
    my $line = getStatementLine();
    SetLine($Node, $line);

    while ((defined nextStatement()) && (${nextStatement()} ne '{') ) {
      $stmt .= ${getNextStatement()};
    }
    
    my $name = "${tag}_".PHP::ParseUtil::getUniqID();

    SetName($Node, $name);
print "+++ $tag ...\n" if ($DEBUG);

    if ( ! defined nextStatement() ) {
      print "parse ERROR : unterminated $tag !!\n";
      return $Node;
    }

    my $BodyNode = parseCurlyCodeBloc();

    if (!defined $BodyNode) {
      print "parse ERROR in $tag body\n";
    }
    else {
      Append ($Node, $BodyNode);
    }

    SetEndline($Node, getStatementLine());

    return $Node;
}

sub parseTry() {
  if (isNextTry()) {
    return parseTryCatch(TryKind, "TRY");
  }
  else {
    return undef;
  }
}

sub parseCatch() {
  if (isNextCatch()) {
    return parseTryCatch(CatchKind, "CATCH");
  }
  else {
    return undef;
  }
}

##################################################################
#              FUNCTION
##################################################################
sub isNextFunction() {
   if ( ${nextStatement()} =~ /[^\$:]\bfunction\b/si ) {
     return 1;
   }
   return 0;
} 

sub parseFunction() {
  if (isNextFunction() ) {
    my $stmt = ${getNextStatement()};
    my $FunctionNode = Node(FunctionKind, \$stmt);
    my $line = getStatementLine();
    SetLine($FunctionNode, $line);

    while ((defined nextStatement()) &&
	   ( (${nextStatement()} ne '{') && 
	     (${nextStatement()} ne ';') ) ) {
      $stmt .= ${getNextStatement()};
    }
    
    if (${nextStatement()} eq ';') {
      $FunctionNode->[0] = PrototypeKind;
      # trashes the ';'
      getNextStatement();
    }

    if ( IsKind($FunctionNode, FunctionKind) ) {
      my ($name) = $stmt =~ /\bfunction\b\s+([^\s\(]+)/is;
      if (! defined $name) {
        $name = "FUNCTION_".PHP::ParseUtil::getUniqID();
        # NOT an error, just a anonymous function
        #print "parse ERROR : function prototype error; name not found! \n";
      }

      SetName($FunctionNode, $name);
print "+++ FUNCTION ($name)...\n" if ($DEBUG);

      if ( ! defined nextStatement() ) {
        print "parse ERROR : unterminated function !!\n";
        return $FunctionNode;
      }

      my $artiKey = PHP::ParseUtil::buildArtifactKeyByData($name,$line);
      PHP::ParseUtil::newArtifact($artiKey);
#
    #$Node = parseBlock($Node, \@rootContent, $type, $endcallback) ;
      my $BodyNode = parseCurlyCodeBloc();

      if (!defined $BodyNode) {
        print "parse ERROR in body for function $name\n";
      }
      else {
        Append ($FunctionNode, $BodyNode);
      }

      PHP::ParseUtil::endArtifact($artiKey);
    }

    SetEndline($FunctionNode, getStatementLine());

    return $FunctionNode;
  }
  else {
    return undef;
  }
}

##################################################################
#              INTERFACE
##################################################################
sub isNextInterface() {
   if ( ${nextStatement()} =~ /[^\$]\binterface\b/si ) {
     return 1;
   }
   return 0;
} 

sub parseInterface() {
  if (isNextInterface() ) {
    my $stmt = ${getNextStatement()};

    my $InterfNode = Node(InterfaceKind, \$stmt);
    my $line = getStatementLine();
    SetLine($InterfNode, $line);
    
    while ((defined nextStatement()) && (${nextStatement()} ne '{') ) {
      $stmt .= ${getNextStatement()};
    }

    my ($name) = $stmt =~ /\binterface\b\s+([^\s]+)/is;
    if (! defined $name) {
      $name = "INTERFACE_".PHP::ParseUtil::getUniqID();
      print "parse ERROR : class prototype error; name not found! \n";
    }

    SetName($InterfNode, $name);
print "+++ INTERFACE ($name)...\n" if ($DEBUG);

    if ( ! defined nextStatement() ) {
      print "parse ERROR : unterminated interface !!\n";
      return $InterfNode;
    }

#    my $artiKey = PHP::ParseUtil::buildArtifactKeyByData($name,$line);
#    PHP::ParseUtil::newArtifact($artiKey);

    my $BodyNode = parseCurlyCodeBloc(\@ClassContent);

    if (!defined $BodyNode) {
      print "parse ERROR in body for interface $name\n";
    }
    else {
      Append ($InterfNode, $BodyNode);
    }

#    PHP::ParseUtil::endArtifact($artiKey);

    SetEndline($InterfNode, getStatementLine());

    return $InterfNode;
  }
  else {
    return undef;
  }
}


##################################################################
#              CLASS
##################################################################
sub isNextClass() {
   
   # Do not detect class in case :
   # - class is used as identifier like in : $class
   # - class is used as type name like in  : getRepository(Product::class)->find($arrayHit['product']['id'])
   if ( ${nextStatement()} =~ /[^\$:]\bclass\b/si ) {
     return 1;
   }
   return 0;
} 

sub parseClass() {
  if (isNextClass() ) {
    my $stmt = ${getNextStatement()};

    my $ClassNode = Node(ClassKind, \$stmt);
    my $line = getStatementLine();
    SetLine($ClassNode, $line);
    
    while ((defined nextStatement()) && (${nextStatement()} ne '{') ) {
      $stmt .= ${getNextStatement()};
    }

    my ($name) = $stmt =~ /\bclass\b\s+([^\s]+)/is;
    if (! defined $name) {
      $name = "CLASS_".PHP::ParseUtil::getUniqID();
      print "parse ERROR : class prototype error; name not found! \n";
    }

    SetName($ClassNode, $name);
print "+++ CLASS ($name)...\n" if ($DEBUG);

    if ( ! defined nextStatement() ) {
      print "parse ERROR : unterminated class !!\n";
      return $ClassNode;
    }

#    my $artiKey = PHP::ParseUtil::buildArtifactKeyByData($name,$line);
#    PHP::ParseUtil::newArtifact($artiKey);

    my $BodyNode = parseCurlyCodeBloc(\@ClassContent);

    if (!defined $BodyNode) {
      print "parse ERROR in body for class $name\n";
    }
    else {
      Append ($ClassNode, $BodyNode);
    }

#    PHP::ParseUtil::endArtifact($artiKey);

    SetEndline($ClassNode, getStatementLine());

    return $ClassNode;
  }
  else {
    return undef;
  }
}

##################################################################
#             HTML 
#  A PHP section can end in the middle of a control structure, and
#  this structure can ends in the next section. The  HTML (web content)
#  delimited between, the en PHP (?>) and the begin PHP (<?php), is
#  considered as "embedded HTML". The most often, this technic is used
#  to make HTML or web content "conditional".
##################################################################
sub isNextHTML() {
	#if ( (${nextStatement()} eq '?>') || (${nextStatement()} eq '%>') ) {
   if (${nextStatement()} =~ /$shortCloseTag/i ) {
     return 1;
   }
   return 0;
}

sub parseHTML() {
  if (isNextHTML()) {

    my $stmt =  ${getNextStatement()};

    my $HtmlNode = Node(HTMLKind, \$stmt);
    my $line = getStatementLine();
    SetLine($HtmlNode, $line);

    while ((defined nextStatement()) && (! isNextSection()) ) {
      $stmt .= ${getNextStatement()};
    }

    if (defined nextStatement()) {
      $stmt .= ${getNextStatement();}
    }
    else {
      print "parse ERROR : unterminated HTML started at line $line...\n";
    }

    return $HtmlNode; 
  }
  else {
    return undef;
  }
}

##################################################################
#              SECTION
##################################################################
sub isNextSection() {
	#if ( ${nextStatement()} =~ /<(?:%|\?(?:php)?)/si ) {
   if ( ${nextStatement()} =~ /$shortOpenTag|$scriptOpenTag/si ) {
     return 1;
   }
   return 0;
} 

sub parseSection() {
  if (isNextSection() ) {
     my $SectionNode = Node(SectionKind, getNextStatement());
     my $line = getStatementLine();
     SetLine($SectionNode, $line);
     my $ID = PHP::ParseUtil::getUniqID();
     SetName($SectionNode, "SECTION_".$ID);
print "+++ SECTION ...\n" if ($DEBUG);
     
     while ( defined nextStatement() ) {
       if ( isNextEndSection()) {
         my $EndSectionNode = parseEndSection();
         SetName($EndSectionNode, "ENDSECTION_".$ID);
         Append($SectionNode, $EndSectionNode);
	 return $SectionNode;
       }
       else {
#print "SECTION CONTENT !!!\n";
	 # Add the next instruction to the section ...
         Append($SectionNode, PHP::ParseUtil::tryParse_OrUnknow(\@sectionContent))
       }
     }
     # At this step, the last statement has been encountered, whereas end of
     # the SECTION is still expected ...
     print "PARSE error : unterminated PHP section started at line $line !!! \n";
     return $SectionNode;
  }
  else {
    return undef;
  }
}

sub isNextEndSection() {
	#if ( (${nextStatement()} eq '?>') || (${nextStatement()} eq '%>') ) {
   if  (${nextStatement()} =~ /$shortCloseTag|$scriptCloseTag/i ) {
     return 1;
   }
   return 0;
} 

sub parseEndSection() {
  if (isNextEndSection() ) {
    my $EndSectionNode = Node(EndSectionKind, getNextStatement());
    SetLine($EndSectionNode, getStatementLine());
    return $EndSectionNode;
  }
  else {
    return undef;
  }
}
##################################################################
#              ROOT
##################################################################
sub parseRoot() {

  my $root = Node(RootKind, \&NullString);

  while ( defined nextStatement() ) {
     my $subNode = PHP::ParseUtil::tryParse(\@rootContent);
     if (defined $subNode) {
        Append($root, $subNode);
     }
     else {
       # trashes the next statement.
       getNextStatement();
       print "PARSE error : found statement outside PHP section";
     }
  }
  return $root;
}

sub ParsePHP ($) {
  my $r_view = shift;

  #my @statements = split /(<(?:%|\?(?:php)?)|(?:\?|%)>|;|{|}|\b(?:if|else|else\s*if|do|while|for|foreach|switch|case|default|break|endif|endwhile|endfor|endforeach|endswitch)\b)/smi, $$r_view;
  
  # if a keyword is preceded with a "$", then include the $ in the split.
  # When the parser will evaluate the "$<keyword>" (ex: the variable $class)
  # pattern, then it will not recognize it as a keyword bug as a variable.
  my @statements = split /($shortOpenTag|$shortCloseTag|$scriptOpenTag|$scriptCloseTag|;|\{|}|\$?\b(?:if|else|else\s*if|do|while|for|foreach|switch|case|default|break|endif|endwhile|endfor|endforeach|endswitch)\b)/smi, $$r_view;

  if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }

  # Register a "unknow instruction" parser callback that manage semicolon end
  # terminated instruction, potentially split on several statements.
  PHP::ParseUtil::registerParseUnknow(\&parseUnknow);

  PHP::ParseUtil::InitParser(\@statements);

  my $root = parseRoot();
  my $Artifacts = PHP::ParseUtil::getArtifacts();
  return ($root, $Artifacts);
}

1;
