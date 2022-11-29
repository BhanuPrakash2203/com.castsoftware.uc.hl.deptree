package JS::ParseJS;
# les modules importes
use strict;
use warnings;
#use diagnostics; #FIXME: est-ce compatible Strawberry?
#no warnings 'recursion'; 

use Erreurs;

use CountUtil;

use Lib::Node; # qw( Leaf Node Append );
use Lib::NodeUtil ;
use Lib::NodeUtil qw( SetName SetStatement SetLine GetLine SetEndline GetEndline); 
use Lib::ParseUtil;

use JS::JSNode;
use JS::Identifiers;
use CountUtil;

my $DEBUG = 0;

# statelents separator
# --------------------
# ;
# { }
# \n

my $JS_SEPARATOR = '[;,:{}\n()\[\]\?]';

# statements
# ----------	
# break 	break [label];
# case 		case expression: 
# continue 	continue [label];
# debugger 	debugger;
# default 	default: 
# do/while 	do statement while (expression); 
# empty 	; 
# for 		for(init; test; incr) statement 
# for/in 	for (var in object) statement
# function 	function name([param[,...]]) { body }
# if/else 	if (expr) statement1 [else statement2]
# label 	label:
# return 	return [expression];
# switch 	switch (expression) { statements }
# throw 	throw expression;
# try 		try { statements }
# 		[catch { handler statements }]
# 		[finally { cleanup statements }]
# use strict	 "use strict"; 
# var 		var name [ = expr] [ ,... ]; 
# while 	while (expression) statement 
# with 		with (object) statement

# the searching pattern include a look-behind matching to prevent from
# recognize keywords preceded from a $.
my $STRUCTURAL_STATEMENTS = '(?<!\$)\b(?:function)\b';

# statement that cannot belong to expression, and then break all statement.
# The javascript parser systematically insert a semicolon before them if the
# previous token was not a closing accolade.
my $CONTROL_FLOW_STATEMENTS = '(?<!\$)(?:\b(?:break|case|continue|default|do|while|for|if|else|return|switch|throw|try|catch|finally|var|with|debugger)\b)';

# Line beginning with these patterns expect a left operand, and so cannot be
# preceded with a semicolon. Javascript parser never insert a semicolon BEFORE them.
my $NEVER_A_STATEMENT_BEGINNING_PATTERNS = '(?:\*=|/=|%=|\+=|-=|&=|\^=|\|=|<<=|>>=|>>>=|-|\+|\*|\/|\%|<<|>>>|>>|<=|>=|<|>|===|==|!==|!=|&&|\||&|\^|\|\||\?|,|:|\.)';

# Line beginning with these patterns expect a right operand, and so cannot be
# preceded with a semicolon. Javascript parser never insert a semicolon AFTER them.
my $NEVER_A_STATEMENT_ENDING_PATTERNS = '(?:\*=|/=|%=|\+=|-=|&=|\^=|\|=|<<=|>>=|>>>=|-|\+|\*|\/|\%|<<|>>>|>>|<=|>=|<|>|===|==|!==|!=|&&|\||&|\^|\|\||\?|:|,|~|!|\.)';

# Line beginning with these patterns are always beginning a new instruction.
# Once possible, the javascript parser systematically insert a semicolon before them.
my $STATEMENT_BEGINNING_PATTERNS = '(?:\+\+|--)';

my $IDENTIFIER = JS::Identifiers::getIdentifiersPattern();

my @rootContent = ( 
			\&parseVarStatement,
		      	\&parseFunction,
                        \&parseIf,
		#\&parseParenthesis,
			\&parseFor,
			\&parseWhile,
			\&parseDo,
			\&parseSwitch,
			\&parseBreak,
			\&parseContinue,
		        \&parseAcco, 
		        \&parseReturn,
		        \&parseThrow,
		        \&parseTry,
		        \&parseLabel
                    );

my @expressionContent = ( 
	                \&parseParenthesis,
			\&parseObject,
                      	\&parseFunction,
                      	\&parseBracket,
                      	\&parseAcco,
                    );

my @withoutFunctionExpressionContent = ( 
	                \&parseParenthesis,
			\&parseObject,
                      	\&parseBracket,
                      	\&parseAcco,
                    );

my $NullString = '';

my $StringsView = undef;

##################### CONTEXT ############

use constant EXPRESSION => 0;
use constant STATEMENT => 1;

my @Context = (STATEMENT);

sub enterContext($) {
  my $context = shift;
  push @Context, $context;
#print "ENTER CONTEXT $context\n";
}

sub leaveContext() {
  if (scalar @Context > 1) {
     my $context = pop @Context;
#print "LEAVE CONTEXT $context\n";
  }
  else {
    print "[PARSE ERROR] context stack error !!\n";
  }
}

sub getContext() {
  if (scalar @Context > 0) {
    return $Context[-1];
  }
  else {
    print "[PARSE ERROR] current context access error !!\n";
    return STATEMENT;
  }
}

sub nextContext() {
  if (scalar @Context > 1) {
    return $Context[-2];
  }
  else {
    print "[PARSE ERROR] previous context access error !!\n";
    return STATEMENT;
  }
}

################# MAGIC NUMBERS #########################

my %H_MagicNumbers;

sub initMagicNumbers($) {
  my $view = shift;

  %H_MagicNumbers = ();
  $view->{HMagic} = \%H_MagicNumbers;
}

sub declareMagic($) {
   my $magic = shift;

   my $artiKey = Lib::ParseUtil::getCurrentArtifactKey();
   if (! exists $H_MagicNumbers{$artiKey}) {
     my %Hash = ();
     $H_MagicNumbers{$artiKey} = \%Hash;
   }

   if (! exists $H_MagicNumbers{$artiKey}->{$magic}) {
     $H_MagicNumbers{$artiKey}->{$magic}=1;
   }
   else {
     $H_MagicNumbers{$artiKey}->{$magic}++;
   }
#print "---> MAGIC = $magic\n";
}

sub getMagicNumbers($$) {
  my $r_expr = shift;
  my $isVarInitContext = shift;

  # reconnaissance des magic numbers :
  # 1) identifiants commencant forcement par un chiffre decimal.
  # 2) peut contenir des '.' (flottants)
  # 3) peut contenir des 'E' ou 'e' suivis eventuellement de '+/-' pour les flottants
  while ( $$r_expr =~ /(?:^|[^\w])((?:\d|\.\d)(?:[e][+-]?|[\d\w\.])*)/sg )
  {
    my $magic = $1;
    
    if ($isVarInitContext) {
      # if the expression is composed only with the magic number that is a 
      # variable initialisation at declaration, then consider as a "constant",
      # not a magic number...
      my $quotedMagic = quotemeta $magic;
      if ( $$r_expr =~ /^\s*$quotedMagic\s*$/sm) {
        return;
      }
      else {
	# do not make this test if the expression contains other magics.
        $isVarInitContext = 0;
      }
    }

#    if (! exists $H_MagicNumbers{$magic}) {
#      $H_MagicNumbers{$magic} = 0;
#    }
#    $H_MagicNumbers{$magic}++;

     declareMagic($magic);
  }
}

################# MISSING ACCOLADE #########################

my %H_MissingAcco;

sub initMissingAcco($) {
  my $view = shift;

  %H_MissingAcco = ();
  $view->{HMissingAcco} = \%H_MissingAcco;
}

sub declareMissingAcco() {
   if (! exists $H_MissingAcco{Lib::ParseUtil::getCurrentArtifactKey()}) {
     $H_MissingAcco{Lib::ParseUtil::getCurrentArtifactKey()} = 1; 
   }
   else {
     $H_MissingAcco{Lib::ParseUtil::getCurrentArtifactKey()}++; 
   }
}

################# SEMI COLON #########################

my %H_MissingSemicolon;

sub initMissingSemicolon($) {
  my $view = shift;

  %H_MissingSemicolon = ();
  $view->{HMissingSemicolon} = \%H_MissingSemicolon;
}

sub declareMissingSemicolon() {
#print "--> MISSING SEMICOLON at line ".getStatementLine()."\n";
   if (! exists $H_MissingSemicolon{Lib::ParseUtil::getCurrentArtifactKey()}) {
     $H_MissingSemicolon{Lib::ParseUtil::getCurrentArtifactKey()} = 1; 
   }
   else {
     $H_MissingSemicolon{Lib::ParseUtil::getCurrentArtifactKey()}++; 
   }
}

sub expectSemiColon() {
  if (defined nextStatement()) {
    # CHECK IF THE INSTRUCTION IS ENDING WITH A SEMICOLON
    if (! isNextSemiColon()) {
      declareMissingSemicolon();
      return 0;
    }
    else {
      # Consumes the semicolon.
      getNextStatement();
      return 1;
    }
  }
  else {
    declareMissingSemicolon();
    return 0;
  }
}

sub nextTokenIsEndingInstruction($) {
  my $r_previousToken = shift;
  my $r_previousBlanks = Lib::ParseUtil::getSkippedBlanks();

  if (defined nextStatement()) {

    # INSTRUCTIONS SEPARATOR
    # ----------------------
    # a ';' or '}' always ends a statement expression.
    if ((${nextStatement()} eq ';') || (${nextStatement()} eq '}')) {
      return 1;
    }

    # if the previous token can syntactically not be the end of a the statement, return false.
    if ($$r_previousToken =~ /$NEVER_A_STATEMENT_ENDING_PATTERNS\s*\Z/sm ) {
      return 0;
    }

    # if the next token can syntactically not begin a new statement, return false.
    if (${nextStatement()} =~ /^\s*$NEVER_A_STATEMENT_BEGINNING_PATTERNS/sm ) {
      return 0;
    }

    # CONTROL FLOW STATEMENT
    # ----------------------
    if (${nextStatement()} =~ /$CONTROL_FLOW_STATEMENTS/ ) {
      return 1;
    }

    # "}" FOLLOWED BY "{"
    if (($$r_previousToken =~ /\}\s*$/sm) && (${nextStatement()} eq '{')) {
      return 1;
    }

    # NEW LINE
    # --------
    # if there was a new line before the token ...
    if ($$r_previousBlanks =~ /\n/s) {
      # if next token is statement beginning pattern when placed at beginning of a line, return true.
      if (${nextStatement()} =~ /^\s*$STATEMENT_BEGINNING_PATTERNS/sm) {
        return 1; 
      }

      # at this time previous and next token don't end and begin with a terminating 
      # or beginning statement operator.
      if (${nextStatement()} =~ /^\s*\w/sm) {
	# next token is an alphanum on next line ==> its a new instruction
	# ) \w ==> syntax does not exists ...
	# ] \w ==> syntax does not exists ...
	# \w \w ==> syntax does not exists ...
        return 1; 
      } 

      #if ($$r_previousToken =~ /\)\s*$/sm ) {
      #  if (${nextStatement()} =~ /^\s*\(/sm) {
	  # a openning parent following a closing parent on the next line is not
	  # considered as a function call, but as a new statement.
	  # Brut strictly speaking, it coulod really be a function call. It is just
	  # undecidable.
      #   return 1; 
      #  }
      #} 
    }
    else {
      # return 0 by default becasue next token is an the same line than previous one.
    }
  }
  else {
    # if next token is NOT DEFINED, then return true because another try to
    # retrieve the next token will not provide a new statement.
    return 1;
  }

  return 0;
}

sub isNextSemiColon() {
    if ( ${nextStatement()} eq ';' ) {
    return 1;
  }
  
  return 0;
}

sub isNextColon() {
    if ( ${nextStatement()} eq ':' ) {
    return 1;
  }
  
  return 0;
}

sub isNextComma() {
    if ( ${nextStatement()} eq ',' ) {
    return 1;
  }
  
  return 0;
}

my $lastStatement = 0;

sub parseUnknow($) {
  my $r_stmt = shift;

  if (defined $r_stmt) {
    # consumes the next statement that is the instruction separator.
    getNextStatement();
    
    return Node(UnknowKind, $r_stmt);
  }

  my $next = ${nextStatement()};

  # INFINITE LOOP PREVENTION MECHANISM
  # ----------------------------------
  if (nextStatement() == $lastStatement) {
    # if it is the second time we try to parse this statement. Remove it
    # unless entering in a infinite loop.
    my $stmt = getNextStatement();
    print "[PARSE ERROR] encountered unexpected statement : ".$$stmt." at line ".getStatementLine()."\n";

    return Node(UnknowKind, $stmt);
  }

  # memorize the statement being treated.
  $lastStatement=nextStatement();

  # Prevent from empty statement (like "else ;" or "else }" )...
  # ---------------------------------------------------------------
  if (($next eq ';') || ($next eq '}')) {
    my $node = Node(EmptyKind, createEmptyStringRef());

    if ($next eq ';') {
      # consumes the ";"
      # RQ: "}" should not be consumed, it is certainly needed further to match
      # the end of an openned acco structure. If it is not the case it will be
      # removed by the above  infinite loop prevention mechanism.
      getNextStatement();
    }
    else {
      expectSemiColon();
    }

    return $node;
  }

  # Creation of the unknow node.
  # ----------------------------
  my $unknowNode = Node(UnknowKind, createEmptyStringRef());

  # An unknow statement is parsed as an expression.
  parseExpression($unknowNode);
#print "Expression : ".${GetStatement($unknowNode)}."\n";
  expectSemiColon();

#print "[DEBUG] Unknow statement : ".${GetStatement($unknowNode)}."\n";

  return $unknowNode;
}

sub isNextOpenningParenthesis() {
    if ( ${nextStatement()} eq '(' ) {
    return 1;
  }
  
  return 0;
}

sub isNextClosingParenthesis() {
    if ( ${nextStatement()} eq ')' ) {
    return 1;
  }
  
  return 0;
}

sub parseParenthesis() {

  if (isNextOpenningParenthesis()) {

    # Consumes the '(' token.
    getNextStatement();

    # parse the parenthesis content
    my $parentNode = Node(ParenthesisKind, createEmptyStringRef());

    SetLine($parentNode, getStatementLine());

    # The content of the parenthesis will be parsed as an expression that end
    # with the matching closing parenthesis.
    parseExpression($parentNode, [\&isNextClosingParenthesis]);

    if ((defined nextStatement()) && (${nextStatement()} eq ')')) {
      # consumes the closing bracket ')'
      getNextStatement();
    }

    SetEndline($parentNode, getStatementLine());

    SetName($parentNode, "PARENT".Lib::ParseUtil::getUniqID());

    return $parentNode;
  }

  return undef;
}

sub isNextOpenningBracket() {
    if ( ${nextStatement()} eq '[' ) {
    return 1;
  }
  
  return 0;
}

sub isNextClosingBracket() {
    if ( ${nextStatement()} eq ']' ) {
    return 1;
  }
  
  return 0;
}

sub parseBracket() {

  my $parentNode = undef;

  if (isNextOpenningBracket()) {

    # Consumes the '[' token.
    getNextStatement();

    # parse the parenthesis content
    $parentNode = Node(BracketKind, createEmptyStringRef());

    # The content of the parenthesis will be parsed as an expression that end
    # with the matching closing parenthesis.
    parseExpression($parentNode, [\&isNextClosingBracket]);

    if ((defined nextStatement()) && (${nextStatement()} eq ']')) {
      # consumes the closing bracket ']'
      getNextStatement();
    }

    SetName($parentNode, "TAB".Lib::ParseUtil::getUniqID());
  }

  return $parentNode;
}

##################################################################
#              Accolade
##################################################################

sub isNextOpenningAcco() {
  if ( ${nextStatement()} eq '{' ) {
    return 1;
  }

  return 0;
}

sub isNextClosingAcco() {
    if ( ${nextStatement()} eq '}' ) {
    return 1;
  }
  
  return 0;
}

sub parseAccoBloc(;$) {
  my $keepTrailingSemicolon = shift;
  if (! defined $keepTrailingSemicolon) {
    $keepTrailingSemicolon = 0;
  }

  my $accoNode = undef;

  if (isNextOpenningAcco()) {

    # Consumes the '{' token.
    getNextStatement();

    # parse the parenthesis content
    $accoNode = Lib::ParseUtil::parseCodeBloc(AccoKind, [\&isNextClosingAcco], \@rootContent, 0, 0 ); # keepClosing:0, noUnknowNode:0
    SetName($accoNode, "");

    #if ((getContext() == STATEMENT) && (defined nextStatement()) && (isNextSemiColon())) { 
    if ((! $keepTrailingSemicolon ) && (defined nextStatement()) && (isNextSemiColon())) { 
      # if any, consumes the following semicolon, bt only in STATEMENT context.
      # In EXPRTESSION context, the semi-colon is to be managed by the routine
      # that parses the statement that contain the expression.
      getNextStatement();
    }
  }

  return $accoNode;
}

sub parseAcco() {

  if (isNextOpenningAcco()) {

    if (isNextObject()) {
      # The object will be parsed as an unknow statement containing it.
      my $node = parseUnknow(undef);

      return $node;
    }
    else {
      # Return bloc of code.
      my $node = parseAccoBloc();

      return $node;
    }
  }

  return undef;
}

##################################################################
#              LABEL
##################################################################

sub isNextLabel(;$) {
  my $idx = shift;
  if (!defined $idx) {
    $idx = 0;
  }

  # Check potential member name :
  if (${nextStatement($idx)} =~ /^\s*$IDENTIFIER\s*$/sm) {

      # check if the following non blank is a colon
      my $idx_nextNonBlank = Lib::ParseUtil::getIndexOfNextNonBlank($idx, 1);
      if (${nextStatement($idx + $idx_nextNonBlank)} eq ':') {
        return 1;
      }
  }
  
  return 0;
}

sub parseLabel() {
  if (isNextLabel()) {
    my $name = ${getNextStatement()};
    my $labelNode = Node(LabelKind, createEmptyStringRef());
    SetName($labelNode, $name);
    SetLine($labelNode, getStatementLine());

    # Consumes the ":"
    getNextStatement();

    return $labelNode;
  }

  return undef;
}

##################################################################
#              RETURN  BREAK  CONTINUE
##################################################################

sub parseTernaryOp($$) {
  my $r_statement = shift;

  # One part of $r_statement will be transfered in the cond node.
  # Some children node could need being deplaced too ...
  my $node =shift;

  my $nodeTernary = Node(TernaryKind, createEmptyStringRef());
  SetName($nodeTernary, "ternary_".Lib::ParseUtil::getUniqID());

  # Consumes the "?".
  getNextStatement();

  # FIXME : the spaces should not be included ... the back split should stop
  # at a non-blank character, else it will modify the spacing in the expression
  # that contains the ternary.
  
  my $stmt = $$r_statement;

  # $r_statement is replaced with that is before the cond expression.
  # =================================================================
 

  # replace all "=" not involved in an assignment by a neutral char.
  # ------------------------------------------------------------------
  $stmt =~ s/===/\x01\x01\x01/sg;
  $stmt =~ s/==/\x01\x01/sg;
  # All '=' preceded with '=', '<' or '>' are neutralised, except if there is
  # one '<' or '>' before. (indeed, <<= and >>= and >>>= are assignment
  # operators and should not be neutralised.
  $stmt =~ s/(\A|[^<>][=><!])=/$1\x01/sg;

  my ($before, $cond)=CountUtil::backsplitAtCharWithParenthesisMatching(\$stmt, ['(', ':', ',', '?', "="], 0);

  # restore all masked '=' ...
  # --------------------------
  $$before =~ s/\x01/=/sg;
  $$cond =~ s/\x01/=/sg;


  $$r_statement = $$before;

#print "-------------------------------\n";
#print "BEFORE : $$r_statement\n";
#print "---> COND : $$cond\n";

  my $condNode = Node(CondKind, $cond);
  Append($nodeTernary, $condNode);
  
  # FIXME : move the subnode to the cond here !!!

  JS::JSNode::reaffectNodes($cond, $condNode, $node);

  my $flatCond = JS::JSNode::getFlatExpression($condNode);
#print "COND : $$flatCond\n";
  Lib::NodeUtil::SetKindData($condNode, $flatCond);

  my $nodeThen = Node(ThenKind, createEmptyStringRef());
  JS::ParseJS::parseExpression($nodeThen, [\&JS::ParseJS::isNextColon]);
#print "THEN : ".${$nodeThen->[1]}."\n";
  Append($nodeTernary, $nodeThen);

  # Consumes the ":".
  getNextStatement();

  my $nodeElse = Node(ElseKind, createEmptyStringRef());
  JS::ParseJS::parseExpression($nodeElse, 
	                       [
				\&JS::ParseJS::isNextClosingParenthesis, 
			  	\&JS::ParseJS::isNextClosingBracket,
				\&JS::ParseJS::isNextComma,
			        \&JS::ParseJS::isNextColon
			       ] );
#print "ELSE : ".${$nodeElse->[1]}."\n";
  Append($nodeTernary, $nodeElse);

  return $nodeTernary;
}


##################################################################
#              RETURN  BREAK  CONTINUE
##################################################################
	


sub parseMonoLineInstr($$) {
  my $kind = shift;
  my $isNext = shift;

  if ($isNext->()) {
    getNextStatement();
    my $node = Node($kind, createEmptyStringRef());
    SetLine($node, getStatementLine());

    # parse parameter if any:
    # if the next token does not end the statement ...
    if (${nextStatement()} !~ /[;\}]/) {
      # if the next token is on a following line, then it is not part of the return.
      if ( ${Lib::ParseUtil::getSkippedBlanks()} !~ /\n/sm ) {
        parseExpression($node);
      }
    }
    
    expectSemiColon();

    return $node;
  }
  return undef;
}

sub isNextReturn() {
    if ( ${nextStatement()} eq 'return' ) {
    return 1;
  }
  return 0;
}

sub parseReturn() {
  return parseMonoLineInstr(ReturnKind, \&isNextReturn);
}


sub isNextThrow() {
    if ( ${nextStatement()} eq 'throw' ) {
    return 1;
  }
  return 0;
}

sub parseThrow() {
  return parseMonoLineInstr(ReturnKind, \&isNextThrow);
}


sub isNextBreak() {
    if ( ${nextStatement()} eq 'break' ) {
    return 1;
  }
  return 0;
}

sub parseBreak() {
  return parseMonoLineInstr(BreakKind, \&isNextBreak);
}

sub isNextContinue() {
    if ( ${nextStatement()} eq 'continue' ) {
    return 1;
  }
  
  return 0;
}

sub parseContinue() {
  return parseMonoLineInstr(ContinueKind, \&isNextContinue);
}



##################################################################
#              OBJECT
##################################################################

sub isNextMember(;$) {
  my $idx = shift;
  if (!defined $idx) {
    $idx = 0;
  }

  # Check potential member name :
  if (${nextStatement($idx)} =~ /^\s*$IDENTIFIER\s*$/sm) {

      # check if the following non blank is a colon
      my $idx_nextNonBlank = Lib::ParseUtil::getIndexOfNextNonBlank($idx, 1);
      if (${nextStatement($idx + $idx_nextNonBlank)} eq ':') {
        return 1;
      }
  }
  elsif (${nextStatement($idx)} =~ /^\s*(?:get|set)\s+$IDENTIFIER\s*$/sm) {

      # check if the following non blank is a colon
      my $idx_nextNonBlank = Lib::ParseUtil::getIndexOfNextNonBlank($idx, 1);
      if (${nextStatement($idx + $idx_nextNonBlank)} eq '(') {
        return 1;
      }
  } 
  return 0;
}

sub isNextObject() {

  if (!defined nextStatement()) {
	return 0;
  }

  if ( ${nextStatement()} eq '{') {

    # check if the next non blank token is an object member...
    my $idx = Lib::ParseUtil::getIndexOfNextNonBlank(0, 1);

    if (${nextStatement($idx)} eq '}') {
      # it's an empty object ...
      return 1;
    } 

    if (isNextMember($idx)) {
      return 1;
    }
    # Next token can be blank because "{" and "\w\s*:" are both split pattern.
    # so "{  CHAINE_X :"will provide a blank pattern between "{" and "CHAINE_X :"
    #elsif ( (${nextStatement(1)} =~ /^\s*$/sm) &&
    #        (isNextMember(2)) ) {
    #  return 1;
    #}
  }
  
  return 0;
}

sub parseMember() {
  # consumes blanks.
  #while ((defined nextStatement()) && (nextStatement() =~ /^\s*$/sm)) {
  #  getStatement();
  #}

  
  my $name = "";

  my $memberNode  = Node(MemberKind, createEmptyStringRef());

  if (${nextStatement()} =~ /^\s*(get|set)\s+($IDENTIFIER)/sm) {
    $name = $2;
    Append($memberNode, parseGetSet());
  }
  else {
    my $r_stmt = getNextStatement();
    ($name) = $$r_stmt =~ /^\s*($IDENTIFIER)/sm;

    # if the name of the property is in a string, decode it ...
    if (exists $StringsView->{$name}) {
      $name = $StringsView->{$name};
      $name =~ s/^["']//m;
      $name =~ s/["']$//m;
    }

    # consumes the ":" token
    getNextStatement();

    # the 1 in third argument signifies the expression is in data initialisation
    # context (this is used for magic numbers cathegorization).
    parseExpression($memberNode, [\&isNextComma, \&isNextClosingAcco], 1);
  }

  SetName($memberNode, $name);

  if (isNextComma()) {
    getNextStatement();
  }
  return $memberNode;
}

sub parseObject() {

  my $objNode = undef;

  if (isNextObject()) {

    # Consumes the '{' token.
    getNextStatement();

    $objNode = Node(ObjectKind, createEmptyStringRef);

    while (isNextMember()) {
      Append($objNode, parseMember());
    }
    SetName($objNode, "OBJECT".Lib::ParseUtil::getUniqID());

    if ((defined nextStatement()) && (${nextStatement()} eq '}')) {
      # Consumes the closing '}'
      getNextStatement();
    }
    else {
      print "[PARSE ERROR] expecting object closing accolade, but found : ".${nextStatement()}." at line ".getNextStatementLine()."\n";;
    }
  }


  return $objNode;
}

##################################################################
#              Expression
##################################################################

my $ExpressionLevel = 0;



# re define a more appropriate kind of a node according to the context
# represented by the statement expression into which the node is included ...
sub refineNode($$)  {
  my $node = shift;
  my $stmtContext = shift;

  # CHECK IF A '(' ... ')' IS A FUNCTION CALL
  # if a openning parenthesis follows a closing parenthesis, accolade or
  # identifier, then it is a function call.
  if ( IsKind($node, ParenthesisKind)) {
    if ($$stmtContext =~ /(?:[)}]|$IDENTIFIER)\s*$/sm ) {
#print "FUNCTION CALL after $$r_statement !!!\n";
      SetKind($node, FunctionCallKind);
      my $name = GetName($node);
      $name =~ s/PARENT/CALL/;
      SetName($node, $name);
    }
  }

  # CHECK IF A '[' ... ']' IS A TAB ACCESS
  # if a openning parenthesis follows a closing parenthesis, accolade or
  # identifier, then it is a function call.
  if ( IsKind($node, BracketKind)) {
    if ($$stmtContext =~ /(?:[)]|$IDENTIFIER)\s*$/sm ) {
#print "FUNCTION CALL after $$r_statement !!!\n";
      SetKind($node, TabAccessKind);
      my $name = GetName($node);
      $name =~ s/TAB/ACCESS/;
      SetName($node, $name);
    }
  }
}

sub parseExpression($;$$) {
  my $parent =shift;
  my $cb_end = shift;
  my $isVarInit = shift; # indicates whether the expression being parsed is
                         # a var declaration initialisation.

  if (! defined $isVarInit) {
    $isVarInit = 0;
  }

  enterContext(EXPRESSION);

  my $endOfStatement = 0;
  my $r_statement = GetStatement($parent);
  # parse the statement until the end is encountered.
  while ((defined nextStatement()) && (! $endOfStatement)) {

    # check if the next statement correspond to a token that ends the expression.
    if (defined $cb_end) {
      for my $cb (@{$cb_end}) {
        if ($cb->()) {
	  $endOfStatement = 1;
	  last;
	}
      }
    }

    if (! $endOfStatement) {

      my $subNode;
      if ($$r_statement =~ /\.\s*\Z/) {
	 # If the current statement is ending with a dot, then an object member
	 # is expected. As 'function' is an authorized member identifier,
	 # we should not try to parse a function.
         $subNode = Lib::ParseUtil::tryParse(\@withoutFunctionExpressionContent);
      }
      else {

	if (${nextStatement()} eq '?') {
	  $subNode=parseTernaryOp($r_statement, $parent);
	}
	else {
          # Next token belongs to the expression. Parse it.
          $subNode = Lib::ParseUtil::tryParse(\@expressionContent);
        }
      }

      if (defined $subNode) {
        Append($parent, $subNode);
	refineNode($subNode, $r_statement);
        $$r_statement .= ${Lib::ParseUtil::getSkippedBlanks()} . JS::JSNode::nodeLink($subNode);
      }
      else {
        # get the next token.
        $$r_statement .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
      }
    }

#print "PRINT NEXT CONTEXT = ".nextContext()."\n";
    # If not in a subexpression, check if next token is a new statement
    # (we are in a subexpression if the next context after leaving the expression
    # is STATEMENT )
    #if ((nextContext() == STATEMENT) && (nextTokenIsEndingInstruction($r_statement))) {
    if ( nextTokenIsEndingInstruction($r_statement)) {
#print "--> CHECK END EXPRESSION\n";
      last;
    }
  }

  getMagicNumbers($r_statement, $isVarInit);

  SetStatement($parent, $r_statement);

#print "EXPRESSION : $$r_statement\n";

  leaveContext();
}

sub isNextVar() {
  if ( ${nextStatement()} eq 'var' ) {
    return 1;
  }
  
  return 0;
}

##################################################################
#              VAR
##################################################################

sub parseVarInit() {

    my $initNode = Node(InitKind, createEmptyStringRef());

    # "1" signifies we are in var init at declaration.
    parseExpression($initNode, [\&isNextComma], 1);

#print "[DEBUG] var initialisation with : ".GetStatement($initNode)."\n";
  return $initNode;
}

sub parseOneVar() {
  Lib::ParseUtil::splitNextStatementAfterPattern('\s*'.$IDENTIFIER.'\s*=?\s*');

  if (${nextStatement()} =~ /\s*($IDENTIFIER)\s*(=)?\s*/) {
      my $name = $1;
      my $singleVarNode = Node(VarDeclKind, \$NullString);
      SetName($singleVarNode, $name);
      SetStatement($singleVarNode, getNextStatement());

      # Check presence of initialization
      if (defined $2) {
        my $varInitNode = parseVarInit();
	if (defined $varInitNode) {
	  Append($singleVarNode, $varInitNode);
	}
      }
     
      return $singleVarNode;
  }
  Lib::ParseUtil::log("Missing identifier for var declaration at line ".getStatementLine().", not a identifier : ".${nextStatement()}."\n");
  return undef;
}	

sub parseVarStatement() {
  if (isNextVar()) {
    my $varNode = Node(VarKind, \$NullString);

    # consummes the var keywork 
    getNextStatement();

    SetLine($varNode, getStatementLine());
    my $endVar = 0;

    while (! $endVar && defined nextStatement()) {
      # parse each variable declaration of the var statement
      my $singleVarNode = parseOneVar();
      if (defined $singleVarNode) {
        Append($varNode, $singleVarNode);
	
	if (defined nextStatement()) {
		#splitNextStatementAfterPattern(',\s*');
		#if (${nextStatement()} !~ /\A,/) {
          if (${nextStatement()} eq ',') {
	    # consumes the ','
	    getNextStatement();
	  }
	  else {
  	     $endVar = 1;
          }
        }
      }
      else {
	# if none VarDecl node is returned, then stop parsing var statement,
	# because an error has been encountered.
        $endVar = 1;
      }
    }
    
    expectSemiColon();

    return $varNode;
  }
  
  return undef;
}


##################################################################
#              CONDITION
##################################################################

sub parseCondition() {
  my $condNode = Node(CondKind, createEmptyStringRef);

  my $statement = "";

  # Consumes the openning parenthsis of the condition.
  getNextStatement();

  parseExpression($condNode, [\&isNextClosingParenthesis]);

  # Consumes the closing parenthesis.
  getNextStatement();

  Lib::NodeUtil::SetKindData($condNode, JS::JSNode::getFlatExpression($condNode));

  return $condNode;
}

##################################################################
#              SWITCH
##################################################################

sub parseCase() {

  # consumes the 'case' token
  getNextStatement();

  my $caseNode = Node(CaseKind, createEmptyStringRef);
  SetLine($caseNode, getStatementLine());

  # parse the condition of the case, that ends with a colon.
  my $caseExprNode = Lib::ParseUtil::parseCodeBloc(CaseExprKind, [\&isNextColon], \@expressionContent, 0, 1 ); # keepClosing:0, noUnknowNode:1

  Append($caseNode, $caseExprNode);

  # parse the instructions of the code. 
  Lib::ParseUtil::parseStatementsBloc($caseNode, [\&isNextCase, \&isNextDefault, \&isNextClosingAcco], \@rootContent, 1, 0 ); # keepClosing:1, noUnknowNode:0

  return $caseNode;
}

sub parseDefault() {
  # consumes the 'default' token
  getNextStatement();

  # consumes the ':' token
  getNextStatement();

  my $defaultNode = Node(DefaultKind, createEmptyStringRef);
  SetLine($defaultNode, getStatementLine());

  # parse the instructions of the code. 
  Lib::ParseUtil::parseStatementsBloc($defaultNode, [\&isNextCase, \&isNextDefault, \&isNextClosingAcco], \@rootContent, 1, 0 ); # keepClosing:1, noUnknowNode:0

  return $defaultNode;
}

sub isNextSwitch() {
    if ( ${nextStatement()} eq 'switch' ) {
    return 1;
  }
  
  return 0;
}

sub isNextCase() {
    if ( ${nextStatement()} =~  /^case\b/s ) {
    return 1;
  }
  
  return 0;
}

sub isNextDefault() {
    if ( ${nextStatement()} =~  /^default\b/s ) {
    return 1;
  }
  
  return 0;
}

sub parseSwitch($) {
  if (isNextSwitch()) {
    my $switchNode = Node(SwitchKind, createEmptyStringRef);

    # consumes the 'switch' statement
    getNextStatement();

    SetLine($switchNode, getStatementLine());

    if ( (defined nextStatement()) && (${nextStatement()} eq '(')) {
      my $condNode = parseCondition();
      Append($switchNode, $condNode); 

      if ( (defined nextStatement()) && (${nextStatement()} eq '{')) {
         # consumes the '{'
        getNextStatement();

        my $moreCasesToParse = 1;
        while ($moreCasesToParse) {
	  if (isNextCase()) {
            Append($switchNode, parseCase());
	  }
	  elsif (isNextDefault()) {
	    Append($switchNode, parseDefault());
	  }
	  else {
            $moreCasesToParse = 0;
	  }
        }
	# consumes the '}' 
	if ( (defined nextStatement()) && (${nextStatement()} eq '}') ) {
	  getNextStatement();
	}
	# consumes the ';' if any
	if ( (defined nextStatement()) && (${nextStatement()} eq ';') ) {
	  getNextStatement();
	}
      }
    }
    else {
      print "[PARSE ERROR ] missing condition for switch at line ".GetLine($switchNode)."\n";
    }
    return $switchNode;
  }

  return undef;
}

##################################################################
#              LOOP
##################################################################

sub isNextFor() {
    if ( ${nextStatement()} eq 'for' ) {
    return 1;
  }
  
  return 0;
}

sub isNextWhile() {
    if ( ${nextStatement()} eq 'while' ) {
    return 1;
  }
  
  return 0;
}

sub isNextDo() {
    if ( ${nextStatement()} eq 'do' ) {
    return 1;
  }
  
  return 0;
}

sub parseLoop($$) {
  my $kind = shift;
  my $isNextLoop = shift;

  if ($isNextLoop->()) {
    my $loopNode = Node($kind, \$NullString);

    # Consumes the 'loop' keyword
    getNextStatement();    

    SetLine($loopNode, getStatementLine());
    
    # get the condition
    if (${nextStatement()} eq '(') {
      Append($loopNode, parseCondition());

      # parse body
      if (${nextStatement()} eq '{') {
       	Append($loopNode, parseAccoBloc());
      }
      else {
	declareMissingAcco();
        Append($loopNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
      }
    }

    return $loopNode;
  }

  return undef; 
}

sub parseFor() {
  if (isNextFor()) {
    my $ForNode = Node(ForKind, createEmptyStringRef());
    my $ForInitNode = Node(ForInitKind, createEmptyStringRef());
    my $ForCondNode = Node(CondKind, createEmptyStringRef());
    my $ForIncNode = Node(ForIncKind, createEmptyStringRef());

    # Consumes the 'loop' keyword
    getNextStatement();

    # get the condition
    if (${nextStatement()} eq '(') {

      # Consumes the opeening parenthesis keyword
      getNextStatement();

      # INIT CLAUSE
      # ------------
      parseExpression($ForInitNode, [\&isNextClosingParenthesis, \&isNextSemiColon]);
      my $separator = getNextStatement();
      if ($$separator eq ';') {

	# It's a classic for with pre-cond-update clauses... 

        # CONDITION CLAUSE
        # ----------------
        parseExpression($ForCondNode, [\&isNextSemiColon]); 
        getNextStatement(); # Consumes the ;
        Lib::NodeUtil::SetKindData($ForCondNode, 
	                         JS::JSNode::getFlatExpression($ForCondNode));

        # INC CLAUSE
        # ----------
        parseExpression($ForIncNode, [\&isNextClosingParenthesis]); 

        # Consumes the closing parenthesis keyword
        getNextStatement();

        Append($ForNode, $ForCondNode);
        Append($ForNode, $ForInitNode);
        Append($ForNode, $ForIncNode);
      }
      else {
	# It's a for-in ... 
	# The presumed "init" clause is in fact the condition itself ...
	SetKind($ForInitNode, CondKind); 
	Append($ForNode, $ForInitNode);
	Lib::NodeUtil::SetKindData($ForInitNode, 
	                         JS::JSNode::getFlatExpression($ForInitNode));
      }
    } 

    # parse body
    if (${nextStatement()} eq '{') {
      Append($ForNode, parseAccoBloc());
    }
    else {
      declareMissingAcco();
      Append($ForNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
    }
    return $ForNode;
  }
  return undef;
}

sub parseWhile() {
  return parseLoop(WhileKind, \&isNextWhile);
}

sub parseDo() {

  if (isNextDo()) {
    my $doNode = Node(DoKind, \$NullString);

    # Consumes the 'do' keyword
    getNextStatement();    

    SetLine($doNode, getStatementLine());

    # parse body
    if (${nextStatement()} eq '{') {
      Append($doNode, parseAccoBloc());
    }
    else {
      declareMissingAcco();
      Append($doNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
    }

    # get the while condition
    if ((defined nextStatement()) && (${nextStatement()} eq 'while')) {

      my $whileNode=Node(WhileKind, \$NullString);

      # consumes the 'while' keyword.
      getNextStatement();

      if (${nextStatement()} eq '(') {
        Append($whileNode, parseCondition());
      }

      Append($doNode, $whileNode);
    }

    expectSemiColon();

    return $doNode;
  }

  return undef; 
}

##################################################################
#              IF
##################################################################

sub isNextIf() {
    if ( ${nextStatement()} eq 'if' ) {
    return 1;
  }
  
  return 0;
}

sub parseIf() {

  if (isNextIf()) {
    my $ifNode = Node(IfKind, \$NullString);

    # Consumes the 'if' keyword
    getNextStatement();    

    SetLine($ifNode, getStatementLine());

    # get the condition
    if (${nextStatement()} eq '(') {
      Append($ifNode, parseCondition());

      # parse then branch
      my $thenNode = Node(ThenKind, createEmptyStringRef);
      Append($ifNode, $thenNode);

      if ((defined nextStatement()) && (${nextStatement()} ne 'else')) {

        if (${nextStatement()} eq '{') {
        	Append($thenNode, parseAccoBloc());
        }
        else {
	  declareMissingAcco();
          Append($thenNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
        }
      }

      # parse else branch
      if ((defined nextStatement()) && (${nextStatement()} eq 'else')) {
        my $elseNode = Node(ElseKind, createEmptyStringRef);
        Append($ifNode, $elseNode);
	# consumes the "else" token.
	getNextStatement();
        if (${nextStatement()} eq '{') {
          Append($elseNode, parseAccoBloc());
        }
        else {
          if (${nextStatement()} ne 'if') {
	    declareMissingAcco();
          }
          Append($elseNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
        }
      }
    }

    return $ifNode;
  }

  return undef; 
}

##################################################################
#              TRY / CATCH / FINALLY
##################################################################

sub isNextTry() {
    if ( ${nextStatement()} eq 'try' ) {
    return 1;
  }
  
  return 0;
}

sub parseTry() {

  if (isNextTry()) {
    my $tryStructNode = Node(TryStructKind, createEmptyStringRef());

    # Consumes the 'try' keyword
    getNextStatement();    

    SetLine($tryStructNode, getStatementLine());

    # parse try branch
    my $tryNode = Node(TryKind, createEmptyStringRef());
    Append($tryStructNode, $tryNode);

    if ((defined nextStatement()) && (${nextStatement()} ne 'catch') && (${nextStatement()} ne 'finally')) {

      if (${nextStatement()} eq '{') {
        Append($tryNode, parseAccoBloc());
      }
      else {
	declareMissingAcco();
        # should never occur, because I think accolade is mandatory !
        Append($tryNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
      }
    }

    # parse catch branch
    my $catchNode = Node(CatchKind, createEmptyStringRef());
    Append($tryStructNode, $catchNode);
    if ( (defined nextStatement()) && (${nextStatement()} eq 'catch')) {
      # consumes the "catch" token.
      getNextStatement();

      # get the condition
      if (${nextStatement()} eq '(') {
        Append($catchNode, parseCondition());

        if (${nextStatement()} eq '{') {
          Append($catchNode, parseAccoBloc());
        }
        else {
	  declareMissingAcco();
          # should never occur, because I think accolade is mandatory !
          Append($catchNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
        }
      }
    }

    # parse finally branch
    my $finallyNode = Node(FinallyKind, createEmptyStringRef());
    Append($tryStructNode, $finallyNode);
    if ( (defined nextStatement()) && (${nextStatement()} eq 'finally')) {
      # consumes the "finally" token.
      getNextStatement();
      if (${nextStatement()} eq '{') {
        Append($finallyNode, parseAccoBloc());
      }
      else {  
	declareMissingAcco();
        # should never occur, because I think accolade is mandatory !
        Append($finallyNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
      }
    }
    return $tryStructNode;
  }

  return undef; 
}




##################################################################
#              FUNCTION
##################################################################

sub isNextFunction() {
    if ( ${nextStatement()} eq 'function' ) {
    return 1;
  }
  
  return 0;
}

sub _parseFunction($) {
    my $kind = shift;

    my $funcNode = Node($kind, \$NullString);

    # a function can be nested in an expression, so it introduce until its end a
    # STATEMENT context. So, any expression encountered in the function will not
    # be a sub expression of the expression that contains the function !!!!
    enterContext(STATEMENT);

    # get the prototype
    my $prototype = "";

    # Consumes the 'function' (or 'get' or 'set') keyword
    $prototype .= ${getNextStatement()};

    while ((defined nextStatement()) && (${nextStatement()} ne '{') ) {
      $prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
    }
    SetStatement($funcNode, \$prototype);

    my $line = getStatementLine();
    SetLine($funcNode, $line);

    # extract name
    $prototype =~ /^\s*(?:function|set|get)\b\s*($IDENTIFIER)?\s*(?:\((.*)\)\s*$)/sm;
                  
    my $name = "";
    my $parameters = $2;

    if (defined $1) {
      $name = $1;
    }
    else {
      $name = 'anonymous_'.Lib::ParseUtil::getUniqID().'_at_line_'.$line;
    }
    SetName($funcNode, $name);

    my $artiKey = Lib::ParseUtil::buildArtifactKeyByData($name, $line);
    Lib::ParseUtil::newArtifact($artiKey);

    if ((defined nextStatement()) && (${nextStatement()} eq '{') ) {
      # param value 1 signifies not removing trainling semicolo ...
      Append($funcNode, parseAccoBloc(1));
    }
    else {
      print "PARSE ERROR : missing body for function ".GetName($funcNode)."\n";
    }

    SetEndline($funcNode, getStatementLine());

    Lib::ParseUtil::endArtifact($artiKey);

    my $artifactLink = "{__HLARTIFACT__".$artiKey."}";
    my $blanks = "";
    Lib::ParseUtil::updateArtifacts(\$artifactLink, \$blanks);

    leaveContext();

    # Extract parameters and record them as attached data.
    my @params = ();
    if (defined $parameters) {
      @params = split ',', $parameters;

      for my $param (@params) {
        $param =~ s/^\s*//sm;
        $param =~ s/\s*$//sm;
      }
    }
    Lib::NodeUtil::SetKindData($funcNode, \@params);

    return $funcNode;
}

sub parseFunction() {

  if (isNextFunction()) {
	  
    if (getContext() == STATEMENT) {
      my $node = _parseFunction(FunctionDeclarationKind);

      if ((defined nextStatement()) && (isNextSemiColon())) {
	  # trash semicolon
	  getNextStatement();
      }
      return $node;
    }
    else {
      return _parseFunction(FunctionExpressionKind);
    }

  }
  return undef;
}

sub parseGetSet() {
  return _parseFunction(FunctionExpressionKind);
}

##################################################################
#              ROOT
##################################################################
sub parseRoot() {

  my $root = Node(RootKind, \$NullString);

  SetName($root, 'root');

  #my $artiKey = Lib::ParseUtil::buildArtifactKeyByData($name, $line);
  Lib::ParseUtil::newArtifact('root');

  while ( defined nextStatement() ) {
     my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);
     if (defined $subNode) {
        Append($root, $subNode);
     }
  }

  Lib::ParseUtil::endArtifact('root');

  return $root;
}

#
# Split a JS buffer into statement separated by structural token
# 

sub splitJS($) {
   my $r_view = shift;

   my  @statements = split /($JS_SEPARATOR|$STRUCTURAL_STATEMENTS|$CONTROL_FLOW_STATEMENTS)/smi, $$r_view;
   
   if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }
   return \@statements;
}


sub ParseJS($) {
  my $r_view = shift;
  
  my $r_statements = splitJS($r_view);

  Lib::ParseUtil::InitParser($r_statements);
  $ExpressionLevel = 0;

  # Mode LAST (no inclusion) for artifact consolidation.
  Lib::ParseUtil::setArtifactMode(1);

  my $root = parseRoot();
  my $Artifacts = Lib::ParseUtil::getArtifacts();

  initUnitSplitter();

  return ($root, $Artifacts);
}

###################################################################################
#              MAIN
###################################################################################

sub preComputeListOfKinds($$) {
  my $node = shift;
  my $vue = shift;
  my @FunctionDeclarationList = GetNodesByKind($node, FunctionDeclarationKind );
  my @FunctionExpressionList = GetNodesByKind($node, FunctionExpressionKind);
  my %H_KindsLists = ();
  $H_KindsLists{'FunctionDeclaration'}=\@FunctionDeclarationList;
  $H_KindsLists{'FunctionExpression'}=\@FunctionExpressionList;
  $vue->{'KindsLists'} = \%H_KindsLists;
}


# description: JS parse module Entry point.
sub Parse($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $status = 0;

    initMagicNumbers($vue);
    initMissingAcco($vue);
    initMissingSemicolon($vue);

    $StringsView = $vue->{'HString'};

#    my $statements =  $vue->{'statements_with_blanks'} ;

     #JS::ParseJSPass2::init();
     Lib::ParseUtil::registerParseUnknow(\&parseUnknow);

     # Minified files are known to remove as more spaces as possible.
     # So, after striping phase, en string encoding, the following code :
     #      case"toto":
     # will become :
     #      caseCHAINE_XXX:
     # The following treatment consist in adding missing space before analysis.
     $vue->{'code'} =~ s/\bcase(CHAINE_\d+)/case $1/sg;

     # launch first parsing pass : strutural parse.
     my ($JSNode, $Artifacts) = ParseJS(\$vue->{'code'});

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

     if (defined $options->{'--print-tree'}) {
       Lib::Node::Dump($JSNode, *STDERR, "ARCHI");
     }
     if (defined $options->{'--print-test-tree'}) {
       print STDERR ${Lib::Node::dumpTree($JSNode, "ARCHI")} ;
     }
      
      $vue->{'structured_code'} = $JSNode;
      $vue->{'artifact'} = $Artifacts;

      # pre-compute some list of kinds :
      preComputeListOfKinds($JSNode, $vue);

      #TSql::ParseDetailed::ParseDetailed($vue);
      if (defined $options->{'--print-artifact'}) {
        for my $key ( keys %{$vue->{'artifact'}} ) {
          print "-------- $key -----------------------------------\n";
	  print  $vue->{'artifact'}->{$key}."\n";
        }
      }

    return $status;
}

#-------------------------------------------------------------------------
#   Routines for spliting into severall units.
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
# The view 'code' is available only for the whole file.
#
# It is not possible to build it as we do for the other views because the 
# begin / end of an artifact does not coincide necessarily with a the 
# begin / end of a line.
#
# So we build the view code by expanding all artifacts buffer.
#-------------------------------------------------------------------------
sub buildCodeView($$$) {
  my $artifactKey = shift;        # The key referencing the artifact we want 
                                  # to rebuild the view code.
  my $subArtifactsList = shift;   # The list of sub-artifacts it contains,
                                  # and which we want to expand the code.  
  my $artifactView = shift;       # The data structure that contains the
                                  # the buffer code of all artifacts.

  # get the buffer code of the artifact we want to rebuilt the view 'code'.
  my $code = $artifactView->{$artifactKey};

  # Each {__HLARTIFACT__xxxx} pattern correspond to an artifact whose key
  # is xxxx.
  while ($code =~ /\{__HLARTIFACT__(\w+)\}/) {
    my $artiKey = $1;
#print "FOUND $artiKey in the code.\n";
    # check if the key corresponds to a sub-artifact ...
    if (exists $subArtifactsList->{$artiKey}) {
      # check if there is a content to this artifact (if not it would be an error)...
      if (exists $artifactView->{$artiKey}) {
#print "--> replace content\n";
	# Expand the content of the artifact.
        my $content = \$artifactView->{$artiKey};
        $code =~s/\{__HLARTIFACT__(\w+)\}/$$content/;
      }
      else {
	# If the artifact can not be expanded, then modify the pattern to
	# prevent from infinite loop !!!
        $code =~s/\{__HLARTIFACT__(\w+)\}/\{__-HLARTIFACT-__$1\}/;
        print "ERROR : no content for artfact $artiKey\n";
      }
    }
    else {
	# If the artifact can not be expanded, then modify the pattern to
	# prevent from infinite loop !!!
        $code =~s/\{__HLARTIFACT__(\w+)\}/\{__-HLARTIFACT-__$1\}/;
#print "INFO : $artiKey is not a sub-artifact\n";
    }
  }

  # restore the patterns of artifacts that have not be expanded ... 
  $code =~s/\{__-HLARTIFACT-__(\w+)\}/\{__HLARTIFACT__$1\}/g;
  return \$code;
}

#-------------------------------------------------------------------------
# Artifacts are functions.
# The 'KindsLists' view contains the functions node that depend of the
# unit being analyzed. 
# The aim of this routine is to retrieve all the artifacts keys of all artifacts
# associated with these sub-functions.
#-------------------------------------------------------------------------
sub buildSubArtifactsList($) {
  my $views = shift;  #  The views set of the unit being analyzed.

  # H liste of key of arifacts corresponding to all sub-functions.
  my %HsubArtifacts = ();

  for my $func (@{$views->{'KindsLists'}->{'FunctionDeclaration'}}) {
    my $name = GetName($func);
#print "SUBFUNCTION : $name\n";
    my $line = GetLine($func) ;
    my $artiKey = buildArtifactKeyByData($name, $line);
#print "--> artifact : $artiKey\n";
    $HsubArtifacts{$artiKey} = 1;
  }

  for my $func (@{$views->{'KindsLists'}->{'FunctionExpression'}}) {
    my $name = GetName($func);
#print "SUBFUNCTION : $name\n";
    my $line = GetLine($func) ;
    my $artiKey = buildArtifactKeyByData($name, $line);
#print "--> artifact : $artiKey\n";
    $HsubArtifacts{$artiKey} = 1;
  }

  return \%HsubArtifacts;
}

#------------------------ UNIT datas ---------------------

my $idx_unit = undef;
my @TopLevelFunc = undef;
my @sortedLineTab = undef;

sub initUnitSplitter() {
  $idx_unit = undef;
  @TopLevelFunc = undef;
  @sortedLineTab = undef;
}

#------------------------ UNIT initialisation ---------------------

sub initUnits($) {
    my $fullViews = shift;
    $idx_unit = 0;
    my $root = $fullViews->{'structured_code'};

    @TopLevelFunc = ();
    @sortedLineTab = ();

    for my $node (@{Lib::NodeUtil::GetChildren($root)}) {
#print "KIND = ".GetKind($node)."\n";
      if (IsKind($node, FunctionDeclarationKind)) {
	      #print "FOUND function ".GetName($node)."\n";
        push @TopLevelFunc, $node;
      }
      elsif ((IsKind($node, UnknowKind)) &&
	     (${GetStatement($node)} =~ /\A\s*\(/s)) {
        my $firstChild = Lib::NodeUtil::GetChildren($node)->[0];
#print "KIND firstChild= ".GetKind($firstChild)."\n";
	if (IsKind($firstChild, ParenthesisKind)) {
	  my $firstGrandChild = Lib::NodeUtil::GetChildren($firstChild)->[0];
#print "KIND firstGrandChild= ".GetKind($firstGrandChild)."\n";
	  if ( (defined $firstGrandChild) &&
	       (IsKind($firstGrandChild, FunctionExpressionKind)) ) {
	    # It's an expression at root level that begin with a parenthesis
	    # that begins with a function expression.
	    # ==> we consider it is an immediate function call.
	    #     (if not, that make no importance, but it certainely the case)
            #  unk
            #  |_parent
            #  | |_func_expr
            #  | | |_acco
            #  | | | |_return
            #  |_fct_call
	    #  
	    # (function toto() {
    	    #   return 1:
            #  })();
            push @TopLevelFunc, $firstGrandChild;
	  }
	}
      }
    }

    my @separationLines = ();

    for my $func (@TopLevelFunc) {
#print "UNIT : ".GetName($func)."\n";
      # remove the node from the root tree
      # ----------------------------------
      Lib::Node::Detach($func);

      # add begin / end lines of unit in a separator list.
      # This is for extract the unit code from the whole file.
      # ------------------------------------------------------
      push @separationLines, GetLine($func);
      push @separationLines, (GetEndline($func)+1);
    }

    # The root code is considered as an unit. It corresponds to the code that is
    # outside the unit defined above.
    push @TopLevelFunc, $root;

    # init the variable that contain the association between line and
    # positions index in the whole buffer.
    CountUtil::initViewIndexes();

    # Sort lines
    @sortedLineTab = sort { $a <=> $b } @separationLines;

    # For each buffer view, built a indexation of all separator lines.
    CountUtil::buildViewsIndexes(\$fullViews->{'text'}, \@sortedLineTab, 'text');
    CountUtil::buildViewsIndexes(\$fullViews->{'comment'}, \@sortedLineTab, 'comment');
    CountUtil::buildViewsIndexes(\$fullViews->{'agglo'}, \@sortedLineTab, 'agglo');
}

#------------------------ UNIT getter ---------------------

sub getNextUnit($) {
  my $fullViews = shift;

  if (! defined $idx_unit) {
    initUnits($fullViews);
  }
  
  if ($idx_unit >= scalar @TopLevelFunc) {
    return undef, undef;
  }

  # The views needed by the DIAG functions to compute counters. These views
  # are to be generated for each unit.
  my %views = ();

  $views{'full_file'} = $fullViews;

  # Hash table that contains the indexes of line, required with buildViewsIndexes() ... 
  my $H_ViewIndexes = CountUtil::getViewIndexes();

  # Get unit's root node ...
  # ------------------------
  my $unit = $TopLevelFunc[$idx_unit];

  if (! IsKind($unit, RootKind)) {
    # create a virtual root code to contain the unit.
    # Indeed, some algorithms need a root node to work perfectly.
    my $virtualRoot =Node(RootKind, createEmptyStringRef());
    SetName($virtualRoot, 'virtualRoot');
    Append($virtualRoot, $unit);
    $unit = $virtualRoot;
  }

  $views{'structured_code'} = $unit;

  # Pre compute a list of some kind nodes
  # -------------------------------------
  preComputeListOfKinds($unit, \%views);
  
  # assign "artifact" view "as is" ... (all artifact will be present)
  # --------------------------------
  $views{'artifact'} = $fullViews->{'artifact'};

  # assign "strings" view "as is" ... (all artifact will be present)
  # --------------------------------
  $views{'HString'} = $fullViews->{'HString'};
  $views{'HMissingSemicolon'} = $fullViews->{'HMissingSemicolon'};
  $views{'HMissingAcco'} = $fullViews->{'HMissingAcco'};
  $views{'HMagic'} = $fullViews->{'HMagic'};

  

  # Get buffer views ...
  # ------------------------------
  #
  # IMPORTANT : the 'code' view must not be captured with line indexation
  # method, because the begin / end of an artifact does not coincide necessarily
  # with a the begin / end of a line.
  #
  # The Artifact view, yes.
  
  my $name = "";

  # A root node is added before non-root unit. If the name is virtualRoot,
  # then it contains an artifact, else it is the real root.
  if (GetName($unit) eq 'virtualRoot') {
#  if (IsKind($unit, FunctionDeclarationKind)) {
    my $artifactUnit = Lib::NodeUtil::GetChildren($unit)->[0];
    $name = GetName($artifactUnit);
    my $line = GetLine($artifactUnit) ;
    my $artiKey = buildArtifactKeyByData($name, $line);

    # rebuild "code" view using artifacts buffer view.
    # --------------------------------
    my $subArtifactsList = buildSubArtifactsList(\%views);
    $views{'code'} = ${buildCodeView($artiKey, $subArtifactsList, $fullViews->{'artifact'})};

  #  $views{'code'} = $fullViews->{'artifact'}->{$artiKey};

    $views{'text'} = CountUtil::extractView(\$fullViews->{'text'}, 
                                 $line,
				 GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'text'});

    $views{'comment'} = CountUtil::extractView(\$fullViews->{'comment'}, 
                                 $line,
				 GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'comment'});

    $views{'agglo'} = CountUtil::extractView(\$fullViews->{'agglo'}, 
                                 $line,
				 GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'agglo'});
#print ">>>".$views{'text'}."<<<\n";
  }
  else {
    $name = 'root';

    # rebuild "code" view using artifacts buffer view.
    # --------------------------------
    my $subArtifactsList = buildSubArtifactsList(\%views);
    $views{'code'} = ${buildCodeView('root', $subArtifactsList, $fullViews->{'artifact'})};
#    $views{'code'} = $fullViews->{'artifact'}->{'root'};

    $views{'text'} = CountUtil::extractRoot(\$fullViews->{'text'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'text'});

    $views{'comment'} = CountUtil::extractRoot(\$fullViews->{'comment'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'comment'});

    $views{'agglo'} = CountUtil::extractRoot(\$fullViews->{'agglo'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'agglo'});

#print ">>>".$views{'text'}."<<<\n";
  }

  $idx_unit++;
#print "UNIT : $name\n";
#print $views{'code'}."\n";
  return (\%views, $name);
}

1;
