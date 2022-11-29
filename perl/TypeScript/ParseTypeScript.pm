package TypeScript::ParseTypeScript;
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

use TypeScript::TypeScriptNode;
use TypeScript::Identifiers;
use CountUtil;

my $DEBUG = 0;

# statelents separator
# --------------------
# ;
# { }
# \n

my $JS_SEPARATOR = '(?:=>|[;,:{}\n()\[\]<>\?=])';

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
my $STRUCTURAL_STATEMENTS = '(?<!\$)\b(?:function|class|interface|namespace|module|enum)\b';

# statement that cannot belong to expression, and then break all statement.
# The javascript parser systematically insert a semicolon before them if the
# previous token was not a closing accolade.
my $CONTROL_FLOW_STATEMENTS = '(?<!\$)(?:\b(?:break|case|continue|default|do|while|for|if|else|return|switch|throw|try|catch|finally|var|let|const|import|export|declare|with|debugger|abstract|type)\b)';

my $SIMPLE_KEYWORDS = '(?<!\$)(?:\b(?:new|as)\b)';

# Line beginning with these patterns expect a left operand, and so cannot be
# preceded with a semicolon. Javascript parser never insert a semicolon BEFORE them.
my $NEVER_A_STATEMENT_BEGINNING_PATTERNS = '(?:\*=|/=|%=|\+=|-=|&=|\^=|\|=|<<=|>>=|>>>=|-|\+|\*|\/|\%|<<|>>>|>>|<=|>=|<|>|===|==|!==|!=|=|&&|\||&|\^|\|\||\?|,|:|\.)';

# Line ending with these patterns expect a right operand, and so cannot be
# preceded with a semicolon. Javascript parser never insert a semicolon AFTER them.
my $NEVER_A_STATEMENT_ENDING_PATTERNS = '(?:\*=|/=|%=|\+=|-=|&=|\^=|\|=|<<=|>>=|>>>=|-|\+|\*|\/|\%|<<|>>>|>>|<=|>=|<|>|===|==|!==|!=|=|&&|\||&|\^|\|\||\?|:|,|~|!|\.)';

# Line beginning with these patterns are always beginning a new instruction.
# Once possible, the javascript parser systematically insert a semicolon before them.
my $STATEMENT_BEGINNING_PATTERNS = '(?:\+\+|--)';

my $IDENTIFIER = TypeScript::Identifiers::getIdentifiersPattern();

my %H_CLOSING = ( '{' => '}', '[' => ']', '<' => '>', '(' => ')' );

my @rootContent = ( 
			\&parseVar,
			\&parseLet,
		      	\&parseFunction,
		      	\&parseClass,
		      	\&parseInterface,
                        \&parseIf,
		#\&parseParenthesis,
			\&parseFor,
			\&parseWhile,
			\&parseImport,
			\&parseExport,
			\&parseDeclare,
			\&parseDo,
			\&parseSwitch,
			\&parseBreak,
			\&parseContinue,
		        \&parseAcco, 
		        \&parseReturn,
		        \&parseThrow,
		        \&parseTry,
		        \&parseNamespace,
		        \&parseModule,
		        \&parseEnum,
		        \&parseConst,
		        \&parseType,
		        \&parseLabel,
		        \&parseAbstract,
		        \&parseDestructuringAssignment,
                    );

my @ExportContent = ( 
			\&parseVar,
			\&parseLet,
		    \&parseFunction,
		    \&parseClass,
		    \&parseInterface,
	        \&parseNamespace,
	        \&parseModule,
	        \&parseEnum,
	        \&parseConst,
	        \&parseType,
);

my @expressionContent = ( 
	                \&parseParenthesis,
			\&parseObject,
                      	\&parseFunction,
                      	\&parseBracket,
                      	\&parseAcco,
                      	\&parseClass,
                      	\&parseNew,
                      	\&parseChevronExpression,
                      	\&parseAsExpression   # return a string ref !!
                    );

my @DotRightValueExpressionContent = ( 
	                \&parseParenthesis,
			\&parseObject,
                      	\&parseBracket,
                      	\&parseAcco,
                    );

my $NullString = '';

my $StringsView = undef;

# This flag indicate to other function that we are inside a "then" expression of the ternary operator.
# Usefull to help interpretation of ":" when encountered.
my @FLAG_InsideTernaryThen = ();

# parse name using "." and whome some parts could be language keyword (like function, type, ...)
#sub getCompoundName() {

	#if (${nextStatement()} =~ /^(\s+)?($IDENTIFIER)/) {
		#my $name = "";
		#if (defined $1) {
			## remove parasitic blank at beginning !
			#Lib::ParseUtil::splitNextStatementOnPattern('[ ]');
			#Lib::ParseUtil::skipBlanks();
		#}
			
		#Lib::ParseUtil::splitNextStatementOnPattern('[|& ]');
		#$name .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
			
		## A type beginning with an identifier can be split, so we are using a loop to concat the different parts !
		## for example "BundleFileSectionKind.Type" => "type" is a split pattern (because a keyword) so the pattern is split
		## into 2 pattern : "BundleFileSectionKind." and "Type" ...
		#while ( (${nextStatement()} =~ /^\s*\./m) ||   	# next item begin with a dot...
		        #($name =~ /\.\s*$/m)     				# ... or is following a dot ! 
		       #)  {
			#Lib::ParseUtil::splitNextStatementOnPattern('[|& ]');
			#$name .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		#}
		#return $name;
	#}
	#return undef;
#}

sub getCompoundName() {

	if (${nextStatement()} =~ /\G(\s*$IDENTIFIER)/gc) {
		my $name = "";
		if (defined $1) {
			$name = $1;
			Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		}
			
		# A type beginning with an identifier can be split, so we are using a loop to concat the different parts !
		# for example "BundleFileSectionKind.Type" => "type" is a split pattern (because a keyword) so the pattern is split
		# into 2 pattern : "BundleFileSectionKind." and "Type" ...
		my $insideCompound = 1;
		while ($insideCompound) {
			if ($name =~ /\.\s*$/m) {     				# ... or is following a dot ! 
				if (${nextStatement()} =~ /\G(\s*$IDENTIFIER)/gc) {
					$name .= $1;
					Lib::ParseUtil::splitAndFocusNextStatementOnPos();
				}
				else {
					print "[ParseTypeScript::getCompoundName] dot not followed by valid identifier : ".${nextStatement()}."\n";
					$insideCompound = 0;
				}
			}
			elsif (${nextStatement()} =~ /\G(\s*\.)/gc) {
				$name .= $1;
				Lib::ParseUtil::splitAndFocusNextStatementOnPos();
			}
			else {
				$insideCompound = 0;
			}
		}
		return $name;
	}
	return undef;
}
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

sub getContextEnclosiness() {
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

##################### ENCLOSINGNESS ############

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
    print "[PARSE ERROR] enclosing stack error !!\n";
  }
}

sub getEnclosing() {
  if (scalar @ContextEnclosing > 0) {
    return $ContextEnclosing[-1];
  }
  else {
    print "[PARSE ERROR] current enclosing access error !!\n";
    return "";
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

# If the expression being parsed is enclosed in an open/close pattern (parenthese ...),
# the variable contain the level of enclosing ...
my $ENCLOSED_EXPRESSION = 0;

sub nextTokenIsEndingInstruction($) {
  my $r_previousToken = shift;
  my $r_previousBlanks = Lib::ParseUtil::getSkippedBlanks();

  # a enclosing <> '' means the expression is enclosed => do not terminate.
  return 0 if (getEnclosing() ne '');

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
	if (! defined nextStatement()) {
		print "ouch !!!\n";
	}
    if ( ${nextStatement()} eq ',' ) {
    return 1;
  }
  
  return 0;
}

sub isNextClosing() {
    if ( ${nextStatement()} =~ /^[\}\)\]]$/m ) {
    return 1;
  }
  
  return 0;
}

my $lastStatement = 0;

sub parseUnknow($) {
  my $r_stmt = shift;

  if (defined $r_stmt) {
	my $node = Node(UnknowKind, $r_stmt);
	SetLine($node, getStatementLine());
    # consumes the next statement that is the instruction separator.
    getNextStatement();
    
    return $node;
  }

  my $next = ${nextStatement()};

  # INFINITE LOOP PREVENTION MECHANISM
  # ----------------------------------
  if (nextStatement() == $lastStatement) {
    # if it is the second time we try to parse this statement. Remove it
    # unless entering in a infinite loop.
    my $stmt = getNextStatement();
    print "[parseUnknow] ERROR : encountered unexpected statement : ".$$stmt." at line ".getStatementLine()."\n";

	my $node = Node(UnknowKind, $stmt);
	SetLine($node, getStatementLine());
    return $node;
  }

  # memorize the statement being treated.
  $lastStatement=nextStatement();

  # Prevent from empty statement (like "else ;" or "else }" )...
  # ---------------------------------------------------------------
  if (($next eq ';') || ($next eq '}')) {
    my $node = Node(EmptyKind, createEmptyStringRef());
	SetLine($node, getNextStatementLine());
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
  SetLine($unknowNode, getNextStatementLine());
  # An unknow statement is parsed as an expression.
  parseExpression($unknowNode);

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

	# TEST ANONYMOUS FUNCTION SUGAR SYNTAX
	my $idx = 1; # seek after the "(" that is at idx 0 !!
	my $stmt;
	my $level = 1;
	my $openline = getNextStatementLine();
	while (defined ($stmt=nextStatement($idx))) {
		if ($$stmt eq '(') {
			$level++;
		}
		elsif ($$stmt eq ')') {
			$level--;
			if (!$level) {
				last;
			}
		}
		$idx++;
	}
	
	if (! defined $stmt) {
		print STDERR "[parseParenthesis] missing closing parenthese (opened at line $openline)\n";
		return undef;
	}

	# CHECK FOR FUNCTION EXPRESSION
	if ( ${nextStatement($idx)} eq ')' ) {
		$idx++;
		my $s;
		$idx++ while ( (defined ($s = nextStatement($idx)) ) && ($$s !~ /\S/ )); # pass over blank statements
		
		if (defined $s) {
			if (${nextStatement($idx)} eq ':') {
				if (! ((scalar @FLAG_InsideTernaryThen) && ($FLAG_InsideTernaryThen[-1])) ) {
					# not inside a ternary op, there is 99% of chance it was a return type of function!
					my $proto = "";
					return parseRoutine(FunctionExpressionKind, $proto);
				}
				else {
					# inside a ternary then so we expect the ":" of the ternary, and we assume it ias that !
					print STDERR "[parseParenthesis] WARNING : ambigous syntax : ')' followed by ':' inside then expression of a ternary operator. -- parenthese opened at line $openline\n";
				}
			}
		
			if ((${nextStatement($idx)} eq '=>') || (${nextStatement($idx)} eq '{')) {
				# no doubt, it's a fat arrow function.
				my $proto = "";
				return parseRoutine(FunctionExpressionKind, $proto);
			}
		}
	}
	
	# NOT A FUNCTION EXPRESSION
	
	# Consumes the '(' token.
    getNextStatement();

	enterEnclosing('(');

    # parse the parenthesis content
    my $parentNode = Node(ParenthesisKind, createEmptyStringRef());

    SetLine($parentNode, getStatementLine());

    # The content of the parenthesis will be parsed as an expression that end
    # with the matching closing parenthesis.
    parseExpression($parentNode, [\&isNextClosingParenthesis]);

    if ((defined nextStatement()) && (${nextStatement()} eq ')')) {
      # consumes the closing bracket ')'
      getNextStatement();
      
      leaveEnclosing(')');
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
    
    return $parentNode;
  }
  
  return undef;
}

sub isNextClosingChevron() {
	return 1 if (${nextStatement()} eq '>');
	return 0;
}

sub parseMatchedChevron() {
	# Consumes the '<' token.
	my $statement = ${getNextStatement()};

	# FIXME : do not manage nested chevrons ..
	$statement .= ${parseRawExpression([\&isNextClosingChevron])};

	if ((defined nextStatement()) && (${nextStatement()} eq '>')) {
		# consumes the closing bracket '>'
		$statement .= ${getNextStatement()};
	}
		
	return \$statement;
}

# there is an ambiguity when encountering a chevron. Is it a generic type ? or an operator ? 
#
# GENERIC TYPES can be preceded with :
#    -  \w  (ex function identity<T>(arg: T))
#    - :    (ex let myIdentity: <T>(arg: T) => T = identity;)
#    - {    (ex let myIdentity: {<T>(arg: T): T} = identity;
# and can be followed :
#    - mostly by (
#    - sometime by =   (ex let myIdentity: GenericIdentityFn<number> = identity;)
# 
# OPERATORS are : <, <=, << They are preceded with
# - \w
# - ) ] and }
# - + or -  (ex i++ < 10)
# - ! (used after a variable)

my $LEVEL_SPECIFIC_KO_REGEXP = {"<" => qr/[;:]/}; # "<" level can not contain semicolon ...

sub parseChevronExpression(;$) {
	my $force = shift;
	
	if (${nextStatement()} eq "<") {
		
		if ($force) {
			return parseMatchedChevron();
		}
		else {
			my $lastNonBlank = ${Lib::ParseUtil::getLastNonBlankStatement()};
		
			if ( $lastNonBlank !~ /[\w\)\]!\+\-]\s*$/m) {
				# "<" not preceded with identifier, number or closing parent ==> not an operator. So parse <...		
				return parseMatchedChevron();
			}
			else {
				# check if the chevron is an operator ...
				my $idx=1;
				my $next_next = ${nextStatement($idx++)}; 
				$next_next = ${nextStatement($idx++)} if ($next_next eq '');
				if (($next_next eq "<") || ($next_next eq "=")) {
					# it's an operator return it
					my $op = "";
					while ($idx--) {
						$op .= ${getNextStatement()};
					}
					return \$op;
				}
				
				# get the "<"
				my $statement .= ${getNextStatement()};
				
				# assume that
				# a Template chevron expression cannot contain ";". This restriction is necessary to exclude the following syntax to be recognized as template :
				# 		for (i = 0; i < aLength && i < bLength; i++) {..}
				# indeed, in the second "<" level, no check on main ko regexp will be done, so ";" cannot be used to invalidate the chevron template context.
				#
				# A Template cannot contain too a ":" . This restriction is necessary for the following case :
				#		for (j = 1, ref = len; 1 <= ref ? j < ref : j > ref; 1 <= ref ? j++ : j--)
				# if ":" is not a ko pattern for a template, the function will return < ref : j > !!!
				
				# search an expression closing with the pairing ">" and not containing semicolon nor colon nor closing item at level 0, nor semicolon nor colon in < levels.
				my ($status, $stmt) = simulateParsePairing(qr/^>$/, qr/^[\}\)\];:]$/, $LEVEL_SPECIFIC_KO_REGEXP,1);
				if ($status) {
					# concat successfully parsed expression
					$statement .= $$stmt;
					# concat closing item
					$statement .= ${getNextStatement()};
				}

				return \$statement;
			}
		}
	}
	
	return undef;
}

# return a string reference
sub simulateParsePairing($$;$) {
	my $ok_reg = shift;
	my $ko_reg = shift;
	my $levelSpecific_KO_regexp = shift || {};
	my $consume_on_succes = shift || 0;
	
	my $idx = 0;
	my $status = 0; # non succes by default
	my $nested=0;
	my @nestedStack = ();
	my $statement = "";
		
	my $next;
	while (defined ($next=nextStatement($idx))) {
		#if ($$next eq ";") {
		#	last;
		#}
		
		if ($nested > 0) {
			# check if in the current kind of level, there is a ko regexp to invalidate the simulation ...
			my $level_KO_regexp = $levelSpecific_KO_regexp->{$nestedStack[-1]};
			if ((defined $level_KO_regexp) && ($$next =~ /$level_KO_regexp/m)) {
				last;
			}
		}
		
		if ($nested == 0) {	
			if ((defined $ok_reg) && ($$next =~ /$ok_reg/m)) {
				# an item validating the simulation has been encountered.
					
				if ($consume_on_succes) {
					my $idx_stmt = nextStatement($idx);
					while (nextStatement() != $idx_stmt) {
						getNextStatement();
					}
				}
					
				$status = 1;
				last;
			}
			elsif ((defined $ko_reg) && ($$next =~ /$ko_reg/m)) {
				# an item that invalide the simulation has been encountered.
				last;
			}
		}
		
		if ($$next =~ /^([\{\[\(<])$/m) {
			$nested++;
			push @nestedStack, $$next;
		}
		elsif ($$next =~ /^([\}\]\)>])$/m) {
			$nested--;
			pop @nestedStack;
		}
		
		$statement .= $$next;
		$idx++;
	}
	
	return ($status, \$statement);
}

# Consumes statement between mactching opening and closing items.
# All nested peer {} [] and () are matched too ...
# Do not interprete any pattern, so do not create any node.
# Simply return a string reference of concatenated statements.

# FIXME : could be replaced by #Lib::ParseUtil::parseRawOpenClose() !!!

sub parsePairing() {
	if (${nextStatement()} =~ /^([\{\[\(])$/m) {
		my $opening = $1;
		# consumes openning
		my $statement = ${getNextStatement()};
		
		my $line = getStatementLine();

		my $closing = $H_CLOSING{$opening};

		my $nested=1;
		my $next;
		while (defined ($next=nextStatement())) {
			if ($$next eq $opening) {$nested++;}
			elsif ($$next eq $closing) {
				$nested--;
				if ($nested == 0) {
					last;
				}
			}
			$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}
		
		if (!defined $next) {
			print STDERR "[parseDestructuringAssignment] ERROR : missing closing $closing, openned at line $line\n";
		}
		elsif ($$next eq $closing) {
			$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}
		
		return \$statement;
	}
	return undef;
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

  enterContext(STATEMENT);
  enterEnclosing('');

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

  leaveEnclosing('');
  leaveContext();

  return $accoNode;
}

sub parseAcco() {

  if (isNextOpenningAcco()) {

#    if (isNextObject()) {
      # The object will be parsed as an unknow statement containing it.
#      my $node = parseUnknow(undef);

#      return $node;
#    }
#    else {
      # Return bloc of code.
      my $node = parseAccoBloc();

      return $node;
#    }
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
#              IMPORT
##################################################################
sub parseImport() {
	if (${nextStatement()} eq 'import') {
		getNextStatement();
		my $statement = "";
		
		my $importNode = Node(ImportKind, \$statement);
		SetLine($importNode, getStatementLine());
		
		#my $stmt;
		#while ((defined ($stmt=nextStatement())) && ($$stmt ne ";") && ($$stmt ne "\n")) {
		#	$statement .= Lib::ParseUtil::getSkippedBlanks() . ${getNextStatement()};
		#}
		
		$statement .= ${parseRawExpression()};
		
		expectSemiColon();

		return $importNode;
	}
	return undef;
}

##################################################################
#              EXPORT
##################################################################
sub parseExport() {
	if (${nextStatement()} eq 'export') {
		getNextStatement();
		my $statement = "";
		
		my $exportNode = Node(ExportKind, \$statement);
		SetLine($exportNode, getStatementLine());
		
		# check if the first following item id "default" or "declare"
		while (${nextStatement()} =~ /^(default|declare)/) {
			Lib::NodeUtil::SetXKindData($exportNode, $1, 1);
			$statement.= Lib::ParseUtil::getSkippedBlanks().${getNextStatement()};
		}
		
		my $subNode = Lib::ParseUtil::tryParse(\@ExportContent);
		
		if (defined $subNode) {
			Append($exportNode, $subNode);
		}
		else {
			TypeScript::ParseTypeScript::parseExpression($exportNode);
		}
		return $exportNode;
	}
	return undef;
}

##################################################################
#              DECLARE
##################################################################
sub parseDeclare() {
	if (${nextStatement()} eq 'declare') {
		getNextStatement();
		my $statement = "";
		
		my $declareNode = Node(DeclareKind, \$statement);
		SetLine($declareNode, getStatementLine());
		
		my $subNode = Lib::ParseUtil::tryParse(\@ExportContent);
		
		if (defined $subNode) {
			Append($declareNode, $subNode);
		}
		else {
			TypeScript::ParseTypeScript::parseExpression($declareNode);
		}
		return $declareNode;
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
  SetLine($nodeTernary, getStatementLine());

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

  TypeScript::TypeScriptNode::reaffectNodes($cond, $condNode, $node);

  my $flatCond = TypeScript::TypeScriptNode::getFlatExpression($condNode);
#print "COND : $$flatCond\n";
  Lib::NodeUtil::SetXKindData($condNode, 'flatexpr', $flatCond);

  my $nodeThen = Node(ThenKind, createEmptyStringRef());
  push @FLAG_InsideTernaryThen, 1;
  TypeScript::ParseTypeScript::parseExpression($nodeThen, [\&TypeScript::ParseTypeScript::isNextColon]);
  pop @FLAG_InsideTernaryThen;
  
#print "THEN : ".${$nodeThen->[1]}."\n";
  Append($nodeTernary, $nodeThen);
  

  # Consumes the ":".
  getNextStatement();

  my $nodeElse = Node(ElseKind, createEmptyStringRef());
  TypeScript::ParseTypeScript::parseExpression($nodeElse, 
	                       [
				\&TypeScript::ParseTypeScript::isNextClosingParenthesis, 
			  	\&TypeScript::ParseTypeScript::isNextClosingBracket,
				\&TypeScript::ParseTypeScript::isNextComma,
				\&TypeScript::ParseTypeScript::isNextColon,
				\&TypeScript::ParseTypeScript::isNextClosingAcco,
				\&TypeScript::ParseTypeScript::isNextSemiColon      # inside a for loop condition for example !!!
				
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
  return parseMonoLineInstr(ThrowKind, \&isNextThrow);
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
      my $stmt = ${nextStatement($idx + $idx_nextNonBlank)};
      if (($stmt eq ':') || ($stmt eq ',') || ($stmt eq '}') || ($stmt eq '(')) {
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
  elsif (${nextStatement($idx)} =~ /^\s*\.\.\./sm) {
	  # check for "spread operator"
	  return 1;
  }
  elsif (${nextStatement($idx)} eq "[") {
		# isNextMember() is called by isNextObject() to check if the items following a { can be the signature of an object member.
		# The way a [ can follow a { are :
		# - a destructuring assignemnt (in STATEMENT context), ie a instruction beginning with [ ... ] = ...
		# - an object member (in EXPRESIION context)
		if (getContext() == EXPRESSION) {
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

	# NEW CHECKING METHOD
	#
	# Do no work because of "return" that can be followed by an object !!
	#
	#if (getContext() == EXPRESSION) {
		#if (${Lib::ParseUtil::getLastNonBlankStatement()} =~ /[\(,:=\{\[]\s*$/m) {
			#return 1;
		#}
		#return 0;
	#}
	#else {
		#return 0;
	#}

    # OLD CHECKING METHOD
    
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
  my $statement = "";
  my $memberNode  = Node(MemberKind, \$statement);

  if (${nextStatement()} =~ /^\s*(get|set)\s+($IDENTIFIER)/sm) {
	# parse getter member
	#--------------------
	$name = $2;
    Append($memberNode, parseGetSet());
  }
  else {
    # my $r_stmt = getNextStatement();

	if (${nextStatement()} =~ /^\s*\.\.\./m) {
		# parse spread operator member ...
		#---------------------------------

		# FIXME : trash but maybe should keep as kindData in the node ? 
		getNextStatement();
		
		parseExpression($memberNode, [\&isNextComma, \&isNextClosingAcco]);
	}
	elsif (${nextStatement()} eq '[') {
			$statement .= ${parsePairing()};
	}
	else {
		my $r_stmt = getNextStatement();
		
		if (${nextStatement()} eq '(') {
			Append($memberNode, parseRoutine(FunctionDeclarationKind, $r_stmt));
		}
		else {
			# parse default member
			#---------------------
			
			($name) = $$r_stmt =~ /^\s*($IDENTIFIER)/sm;
			if (! defined $name) {
				$name = "";
			}
			
			# if the name of the property is in a string, decode it ...
			if (exists $StringsView->{$name}) {
				$name = $StringsView->{$name};
				$name =~ s/^["']//m;
				$name =~ s/["']$//m;
			}
			
			if (${nextStatement()} eq '?') {
				# it'a an optional member
				getNextStatement();
				Lib::NodeUtil::SetXKindData($memberNode, 'optional', 1);
			}
		}
	}
			
	# parse member value if any ...
	if (${nextStatement()} eq ":") { 
		# consumes the ":" token
		getNextStatement();

		# the 1 in third argument signifies the expression is in data initialisation
		# context (this is used for magic numbers cathegorization).
		parseExpression($memberNode, [\&isNextComma, \&isNextClosingAcco], 1);
	}
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

    # while (isNextMember()) {
    while (!isNextClosingAcco()) {
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


# re define a more appropriate kind of a node according to the context
# represented by the statement expression into which the node is included ...
sub refineNode($$)  {
  my $node = shift;
  my $stmtContext = shift;

  # CHECK IF A '(' ... ')' IS A FUNCTION CALL
  # if a openning parenthesis follows a closing parenthesis, accolade or
  # identifier, then it is a function call.
  if ( IsKind($node, ParenthesisKind)) {
    if ($$stmtContext =~ /(?:[)}]|($IDENTIFIER))\s*\z/sm ) {
#print "FUNCTION CALL after <<<$$stmtContext>>> !!!\n";
      SetKind($node, FunctionCallKind);
      my $fctName = $1 || 'CALL';
      my $name = GetName($node);
      $name =~ s/PARENT/${fctName}_/;
      SetName($node, $name);
    }
  }

  # CHECK IF A '[' ... ']' IS A TAB ACCESS
  # if a openning parenthesis follows a closing parenthesis, accolade or
  # identifier, then it is a function call.
  if ( IsKind($node, BracketKind)) {
    if ($$stmtContext =~ /(?:[)\]]|$IDENTIFIER)\s*\z/sm ) {
#print "FUNCTION CALL after $$r_statement !!!\n";
      SetKind($node, TabAccessKind);
      my $name = GetName($node);
      $name =~ s/TAB/ACCESS/;
      SetName($node, $name);
    }
  }
}

sub parseFatArrowFunctionExpressionWithoutParenthesedParam() {
	if ( ${nextStatement()} =~ /\w+\s*$/m) {
		
	}
}

sub parseExpression($;$$) {
	my $parent =shift;
	my $cb_end = shift;
	my $isVarInit = shift; # indicates whether the expression being parsed is
                         # a var declaration initialisation.
                        
    # true if the keyword 'new' is encountered.
    # In this case, when encountering a "<" it is certainely a template openning, and not a comparison operator.
    my $new_context = 0;

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
				# is expected. Languages keyword (ex: function, class) are valid field name, and should not be parsed as a language instruction.
				# So, use a context that do not parse language keyword.
				$subNode = Lib::ParseUtil::tryParse(\@DotRightValueExpressionContent);
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
				# *** SYNTAX has been recognized by CALLBACK
				if (ref $subNode eq "ARRAY") {
					Append($parent, $subNode);
					refineNode($subNode, $r_statement);
					$$r_statement .= ${Lib::ParseUtil::getSkippedBlanks()} . TypeScript::TypeScriptNode::nodeLink($subNode);
				}
				else {
					$$r_statement .= $$subNode;
				}
			}
			else {
				# ***  SYNTAX UNRECOGNIZED with callbacks
				
				my $skippedBlanks = ${Lib::ParseUtil::getSkippedBlanks()};
				my $stmt = getNextStatement();
				
				if (! defined nextStatement()) {
					# It's the last statement : nothing to check !!
					$$r_statement .= $skippedBlanks . $$stmt;
				}
				
				# try checking fat arrow function expression without parenthese ...
				# ex :    err => { ... }    ( same than   (err) => { ... }  )
				elsif (${nextStatement()} eq "=>") {
					if ( $$stmt =~ /^(.*?)(\w+\s*)$/m) {
						# first part ($1) that do not belong to the function expression
						$$r_statement .= $skippedBlanks . $1;
						
						# second part ($2) that is the parameter of the function expression
						my $funcNode = parseRoutine(FunctionExpressionKind, $2);
						Append($parent, $funcNode);
						refineNode($funcNode, $r_statement);
						$$r_statement .= TypeScript::TypeScriptNode::nodeLink($funcNode);
					}
				}
				else {
					if ($$stmt eq ":") {
						print STDERR "[PARSE WARNING] colon inside expression at line ".getNextStatementLine().". Colons are a structural language item, and shoulkd be recognized inside structural pattern, not inside expression !!\n";
						
					}
					# final DEFAULT treatment
					$$r_statement .= $skippedBlanks . $$stmt;
				}
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

# parse expression without creating sub nodes ...
sub parseRawExpression(;$$) {
	my $cb_end = shift;
	my $isVarInit = shift; # indicates whether the expression being parsed is
                         # a var declaration initialisation.

	if (! defined $isVarInit) {
		$isVarInit = 0;
	}

	enterContext(EXPRESSION);

	my $endOfStatement = 0;
	my $statement = "";
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

			my $next = parsePairing(); # the only callback available at this times ...
			
			if (defined $next) {
				$statement .= $$next;
			}
			else {
				# concat next statement 
				$statement .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
			}
		}

#print "PRINT NEXT CONTEXT = ".nextContext()."\n";	
	# If not in a subexpression, check if next token is a new statement	
	# (we are in a subexpression if the next context after leaving the expression
	# is STATEMENT )
	#if ((nextContext() == STATEMENT) && (nextTokenIsEndingInstruction(\$statement))) {
		if ( nextTokenIsEndingInstruction(\$statement)) {
#print "--> CHECK END EXPRESSION\n";
			last;
		}
	}

	getMagicNumbers(\$statement, $isVarInit);

	#SetStatement($parent, \$statement);

#print "EXPRESSION : $statement\n";

	leaveContext();
	
	return \$statement;
}

##################################################################
#              TYPE
##################################################################

sub parseTab() {
	my $stmt = ${getNextStatement()}; # get "["
	
	while ((defined ($stmt=nextStatement())) && ($$stmt ne ']')) {
		$stmt .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
	}
	return $stmt;
}

sub parseTypeExpression();

# FIXME : could be reimplemented using services that manage nested structures !!
sub parseTypeExpression() {
	my $type = "";
	my $stmt;

	# parse parenthese. It can be a function like below (or not) :
	# type function : (<param list>) => <type>
	if (${nextStatement()} eq '(') {
		## get openning
		#$type .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		
		## get content
		## !! WARNING TO NESTED PARENTHESES
		#while ((defined nextStatement()) and (${nextStatement()} ne ')') ) {
			#$type .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		#}
		## get closing
		#$type .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		
		$type .= ${parsePairing()};
		
		if (${nextStatement()} eq ":") {
			$type .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()}; # get ":"
			$type .= parseTypeExpression();
			#while ((defined ($stmt=nextStatement())) and ($$stmt ne ";") and ($$stmt ne "=>") and ($$stmt ne "\n")) {
			#	$type .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
			#}
		}
		
		# check operator =>
		if (${nextStatement()} eq '=>') {
			$type .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
			$type .= parseTypeExpression();
		}
		#else {
		#	print "[ParseTypeScript::parseTypeExpression] ERROR : missing => operator at line ".getStatementLine()."\n";
		#}
	}
	# Support strange number type, like in following examples :
	#  export interface SynthesizedComment extends CommentRange {
    #    text: string;
    #    pos: -1;
    #  }
    #  let max: Rank | -1 = -1;
	elsif (${nextStatement()} =~ /^\s*-?\d+/) {
		$type .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
	}
	# other types \w, \w?[...], \w<...>,  {...}
	else {
		my $REG_open = '^[\[<]';
		my $name = getCompoundName();
		
		if (defined $name) {
			# name with following syntax : \w+[(.\w+)*]
			$type .= $name;
			
			if ($name =~ /\breadonly\b/) {
				$type .= parseTypeExpression();
			}
		}
		else {
			# no identitfier =>  could be structured type (with accolade).
			$REG_open = '^[\[<\{]';
		}
	
		if (${nextStatement()} =~ /$REG_open/m) {
			$type .= ${Lib::ParseUtil::parseRawOpenClose()};
		}		
	}

	# parse TABs if any...
	while (${nextStatement()} eq "[") {
		$type .= ${Lib::ParseUtil::parseRawOpenClose()};
	}
	
	# COMPOUND types combined with |, & and "is"
	if (Lib::ParseUtil::splitNextStatementAfterPattern('\s*(?:[\|\&]|\bis\b)')) {
		$type .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		$type .= parseTypeExpression();
	}
# print "TYPE = $type\n";
	return $type;
}

# "type" statement is not parsed using standard mecanism, because "object literal type" will be confused with "object literal data". The difference between the two, 
# is that the members are separated with respectively ";" and ","
# type toto = { m1 : string; m2: number }
# var titi = { m1 : 1,  m2: 2 }

sub parseType() {
	if (${nextStatement()} eq 'type') {
		my $statement = ${getNextStatement()};
		my $typeNode = Node(TypeKind, \$statement);
		
		$statement .= ${parseRawExpression()};
		
		expectSemiColon();
		
		return $typeNode;
	}
	return undef;
}

sub parseAsExpression() {
	if (${nextStatement()} eq 'as') {
		my $stmt = ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		$stmt .= parseTypeExpression();
		return \$stmt;
	}
	return undef;
}

##################################################################
#              NEW
##################################################################

sub parseNew() {
	if (${nextStatement()} eq 'new') {
		getNextStatement();
		
		my $line = getStatementLine();
		
		my $statement = "";
		my $newNode = Node(NewKind, \$statement);
		
		SetLine($newNode, $line);
		
		# COMMON PATTERN : 
		#   new class ...
		#   new xxx()
		#   new xxx<...> ()
		if (isNextClass()) {
			Append($newNode, parseClass());
		}
		else {
			my $stmt;
			# but be careful : parenthesis are not required.
			while ( (defined ($stmt = nextStatement()))
					# stop conditions ...
					&& ($$stmt ne ')') 				# FOR EXAMPLE : destination.error(new EmptyError);
					&& ($$stmt ne '}') 				# FOR EXAMPLE : {dataTransfer:new DataTransfer}
					&& ($$stmt ne ';')) { 			# FOR EXAMPLE : new EmptyError;
															
				if ($$stmt eq '<') {
					$statement .= ${parseChevronExpression(1)};
				}
				elsif ($$stmt eq '(') {
					# get the openning parenthese
					$statement .= ${getNextStatement()};
			
					# parse the parenthese content.
					parseExpression($newNode, [\&isNextClosingParenthesis]);
			
					if (${nextStatement()} ne ')') {
						print STDERR "[parseNew] missing closing parenthese for new instruction at line $line\n";
					}
					else {
						$statement .= ${getNextStatement()};
					}
					# leave the loop, because it should be nothing after the instanciation parameters.
					last;
				}
				else {
					$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
				}
			}
		}
		return $newNode;
	}
	return undef;
}

##################################################################
#              VAR
##################################################################

sub isNextVar() {
  if ( ${nextStatement()} eq 'var' ) {
    return 1;
  }
  
  return 0;
}

sub isNextLet() {
  if ( ${nextStatement()} eq 'let' ) {
    return 1;
  }
  
  return 0;
}

sub isNextConst() {
  if ( ${nextStatement()} eq 'const' ) {
    return 1;
  }
  
  return 0;
}

sub parseVarInit() {

    my $initNode = Node(InitKind, createEmptyStringRef());

    # "1" signifies we are in var init at declaration.
    parseExpression($initNode, [\&isNextComma], 1);

#print "[DEBUG] var initialisation with : ".GetStatement($initNode)."\n";
  return $initNode;
}

sub parseOneVar() {
	
	if (${nextStatement()} =~ /\s*($IDENTIFIER)/) {
		my $name = $1;
		my $singleVarNode = Node(VarDeclKind, \$NullString);
		SetName($singleVarNode, $name);
		SetStatement($singleVarNode, getNextStatement());
		SetLine($singleVarNode, getStatementLine());

		# check and parse type
		if (${nextStatement()} eq ":") {
			getNextStatement();
			my $type = parseTypeExpression();
		}

		# Check presence of initialization
		if (${nextStatement()} eq "=") {
			getNextStatement();
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

sub parseVarStatement($) {
	my $kind = shift;

    my $varNode = Node($kind, \$NullString);

    # consummes the var or let keywork 
    getNextStatement();

    SetLine($varNode, getStatementLine());
    my $endVar = 0;

	# Check if it as an array destructuring assignment
	#my $DestAss = parseArrayDestructuringAssignment($kind);
	#if (defined $DestAss) {
		## return destructuring assignment if any ...
		#return $DestAss;
	#}
	
	my $DestAss = parseDestructuringAssignment($kind);
	if (defined $DestAss) {
		# return destructuring assignment if any ...
		return $DestAss;
	}

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
;
}

sub parseVar() {
	if (isNextVar()) {
		return parseVarStatement(VarKind);
	}
	return undef;
}

sub parseLet() {
	if (isNextLet()) {
		return parseVarStatement(LetKind);
	}
	return undef;
}

sub parseConst() {
	if (isNextConst()) {
		my $idx = 1;
		while (${nextStatement($idx)} !~ /\S/) {
			$idx++;
		}
		if (${nextStatement($idx)} eq "enum") {
			getNextStatement(); # get const keyword
			my $enumNode = parseEnum();
			Lib::NodeUtil::SetXKindData($enumNode, 'const', 1);
			return $enumNode;
		}
		else {
			return parseVarStatement(ConstKind);
		}
	}
	return undef;
}

##################################################################
#         Parse DESTRUCTURING ASSIGNMENT 
##################################################################

# https://basarat.gitbooks.io/typescript/docs/destructuring.html
sub parseDestructuringAssignment(;$) {
	my $kind = shift;
	
	if (${nextStatement()} =~  /([\{\[])/) {
		my $openning = $1;
		my $closing = $H_CLOSING{$openning};
		
		# line of what is before the { (var, let or const ...)
		my $line = getStatementLine();
		
		# ROBUSTNESS
		if (($openning eq '{') and (!defined $kind)) {
			print STDERR "[parseDestructuringAssignment] WARNING : object destructuring assignment without var, let or const at line $line\n";
		}
		
		my $DestAssNode = Node(DestructuringAssignmentKind, createEmptyStringRef());
		
		# working node : create a declaration level (var, let, const ?) or not ? 
		my $workingNode;
		if (defined $kind) {
			$workingNode = Node($kind, createEmptyStringRef());
			SetLine($workingNode, $line);
			Append($DestAssNode, $workingNode);
		}
		else {
			$workingNode = $DestAssNode;
		}
		
		# consumes openning
		getNextStatement();
		
		$line = getStatementLine();
		my $item;
		my $stmt = "";
		# FIXME : manage nested ...
		
		my $nested=1;

		while (defined ($item=nextStatement())) {
			if ($$item eq $openning) {$nested++;}
			elsif ($$item eq $closing) {
				$nested--;
				if ($nested == 0) {
					last;
				}
			}
			$stmt .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}
		
		#while (${nextStatement()} ne $closing) {
			#$stmt .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		#}
		
		if (${nextStatement()} eq $closing) {
			getNextStatement();
		}
		else {
			print STDERR "[parseDestructuringAssignment] ERROR : missing closing $closing, openned at line $line\n";
		}
		
		# split and retrieves variable
		$stmt =~ s/\s+|\.+//g;
		my @vars = split ",", $stmt;
		for my $var (@vars) {
			my $name;
			if ($var =~ /:\s*(\w+)/) {
				$name = $1;
			}
			else {
				$name = $var;
			}
			my $varNode = Node(VarDeclKind, createEmptyStringRef());
			SetName($varNode, $name);
			SetLine($varNode, $line);
			Append($workingNode, $varNode);
		}
		
		if (${nextStatement()} eq ':') {
			getNextStatement();
			if (${nextStatement()} eq '[') {
				# FIXME : parse destructuring type but trash ...
				parsePairing();
			}
			else {
				# FIXME : parse but trash ...
				parseTypeExpression();
			}
		}
		
		# parse init.
		if (${nextStatement()} eq '=') {
			getNextStatement(); # get "="
			Append($DestAssNode, parseVarInit());
		}
		
		expectSemiColon();
		
		return $DestAssNode;
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

  SetLine($condNode, getStatementLine());

  # enclosing mode say : do not break expression if a statement keyword is foud.
  # for example : if ('comment2' === type) ...
  #   ==> type is a keyword that will end the expression if outside "enclosing mode" !!!
  enterEnclosing("(");
  parseExpression($condNode, [\&isNextClosingParenthesis]);
  leaveEnclosing(")");

  # Consumes the closing parenthesis.
  getNextStatement();

  Lib::NodeUtil::SetXKindData($condNode, 'flatexpr', TypeScript::TypeScriptNode::getFlatExpression($condNode));

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
  #my $caseExprNode = Lib::ParseUtil::parseCodeBloc(CaseExprKind, [\&isNextColon], \@expressionContent, 0, 1 ); # keepClosing:0, noUnknowNode:1
  my $caseExprNode = Node(CaseExprKind, createEmptyStringRef);
  parseExpression($caseExprNode, [\&isNextColon]);

  Append($caseNode, $caseExprNode);

  if (${nextStatement()} eq ':') {
	  getNextStatement();
  }

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

      enterEnclosing('(');

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
        Lib::NodeUtil::SetXKindData($ForCondNode, 'flatexpr', 
	                         TypeScript::TypeScriptNode::getFlatExpression($ForCondNode));

        # INC CLAUSE
        # ----------
        parseExpression($ForIncNode, [\&isNextClosingParenthesis]); 

        # Consumes the closing parenthesis keyword
        getNextStatement();
		leaveEnclosing(')');
		
        Append($ForNode, $ForCondNode);
        Append($ForNode, $ForInitNode);
        Append($ForNode, $ForIncNode);
      }
      else {
		  # encountered a ')'  ...
		  leaveEnclosing(')');
	# It's a for-in ... 
	# The presumed "init" clause is in fact the condition itself ...
	SetKind($ForInitNode, CondKind); 
	Append($ForNode, $ForInitNode);
	Lib::NodeUtil::SetXKindData($ForInitNode, 'flatexpr', 
	                         TypeScript::TypeScriptNode::getFlatExpression($ForInitNode));
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
    if ( (defined nextStatement()) && (${nextStatement()} eq 'catch')) {
		my $catchNode = Node(CatchKind, createEmptyStringRef());
		Append($tryStructNode, $catchNode);
      
		# consumes the "catch" token.
		getNextStatement();
		SetLine($catchNode, getStatementLine());
      
		# get the condition
		if (${nextStatement()} eq '(') {
			Append($catchNode, parseCondition());
		}

		# get Body
		if (${nextStatement()} eq '{') {
			Append($catchNode, parseAccoBloc());
		}
		else {
			declareMissingAcco();
			# should never occur, because I think accolade is mandatory !
			Append($catchNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
		}
    }

    # parse finally branch
    if ( (defined nextStatement()) && (${nextStatement()} eq 'finally')) {
	  my $finallyNode = Node(FinallyKind, createEmptyStringRef());
      Append($tryStructNode, $finallyNode);
      
      # consumes the "finally" token.
      getNextStatement();
      SetLine($finallyNode, getStatementLine());
      
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

sub parseRoutine($$) {
    my $kind = shift;
    my $prototype = shift;

	# interrupt enclosing
	enterEnclosing('');
	
	my $accoladeBodyExpected = 1;

	my $funcNode = Node($kind, \$prototype);

    # a function can be nested in an expression, so it introduce until its end a
    # STATEMENT context. So, any expression encountered in the function will not
    # be a sub expression of the expression that contains the function !!!!
    enterContext(STATEMENT);

	# PARSE UNTIL PARAMETER or =>
	while ((defined nextStatement()) && (${nextStatement()} ne "(") && (${nextStatement()} ne "=>")) {
		$prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
	}

	my $line = getNextStatementLine();
    SetLine($funcNode, $line);
	
	# PARSE THE PARAMETERS ...
	my $parameters = "";
	my $stmt;
	my $nested = -1;
	
	if (!defined nextStatement()) {
		print "[ParseTypeScript::parseRoutine] ERROR : unterminated function declaration !!!\n";
		# restore prvious enclosing
		leaveEnclosing('');
		return $funcNode;
	}
	
	if (${nextStatement()} eq '(') {
		# get the "("
		$prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		$nested++;
#FIXME : COULD be re-written with parsePairing ??
		while ((defined ($stmt=nextStatement())) && (($nested) || ($$stmt ne ")"))) {
			if ($$stmt eq "(") {$nested++;}
			elsif ($$stmt eq ")") {$nested--;}
			$parameters .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}
	
		$prototype .= $parameters;

		if ((defined nextStatement()) && (${nextStatement()} eq ")")) {
			$prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}
		else {
			print "[ParseTypeScript::parseRoutine] ERROR : missing ending parenthese for method parameters\n";
		}
	}
		
	# PARSE RETURN TYPE if any.
	my $returnType = "";
	if ((defined nextStatement()) && (${nextStatement()} eq ":")) {
		# trashes the ":"
		$prototype .= ${getNextStatement()};
		
		# FIXME : add support to structured type ??
		#   greet(): { x: string } {
        #		return {x:"toto"}
		#	}
		#while ((defined nextStatement()) && (${nextStatement()} ne "{")) {
		#	$returnType .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		#}
		$returnType .= parseTypeExpression();
		$prototype .= $returnType;
	}
	
	# PARSE SUGER SYNTAX if any !!
	# FIXME : operator "=>" seems to be used for literal function type... not function or function expression...
	if ((defined nextStatement()) && (${nextStatement()} eq "=>")) {
		$prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		
		if ((defined nextStatement()) && (${nextStatement()} ne "{")) {
			# expect an expression body !!
			$accoladeBodyExpected = 0;
		}
	}
	
	# PARSE ACCOLADE BODY
    #while ((defined nextStatement()) && (${nextStatement()} ne '{') ) {
    #  $prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
    #}

    # extract name
    $prototype =~ /^\s*(?:function\b|set\b|get\b)?\s*($IDENTIFIER)?/sm;
                  
    my $name = "";
    if (defined $1) {
      $name = $1;
    }
    else {
      $name = 'anonymous_'.Lib::ParseUtil::getUniqID().'_at_line_'.$line;
    }
    SetName($funcNode, $name);

    my $artiKey = Lib::ParseUtil::buildArtifactKeyByData($name, $line);
    Lib::ParseUtil::newArtifact($artiKey);

	if ($accoladeBodyExpected) {
		# PARSE ACCOLADE BODY
		if ((defined nextStatement()) && (${nextStatement()} eq '{') ) {
			# param value 1 signifies not removing trainling semicolo ...
			Append($funcNode, parseAccoBloc(1));
		}
		else {
			#print "WARNING : missing body for function/method ".GetName($funcNode)."\n";
			SetKind($funcNode, MethodProtoKind);
			expectSemiColon();
			
		}
	}
	else {
		# PARSE EXPRESSION BODY ( body without accolade) 
		my $returnNode = Node(ReturnKind, createEmptyStringRef());
		SetLine($returnNode, getStatementLine());
		SetName($returnNode, "implicit");
		
		# the function expression can be enclosed inside a "then" statement of a ternary op. In this case,
		# it should stop on the ":" character.
		# It can even be in an object member, so followed on a ","
		parseExpression($returnNode, [\&isNextClosingParenthesis, \&isNextColon, \&isNextComma, \&isNextClosingBracket]);
		Append($funcNode, $returnNode);
#print "FUNC STATEMENT: ".${GetStatement($funcNode)}."\n";
#print "          -------------> ".${GetStatement($returnNode)}."\n";
	}

    SetEndline($funcNode, getStatementLine());

    Lib::ParseUtil::endArtifact($artiKey);

    my $artifactLink = "{__HLARTIFACT__".$artiKey."}";
    my $blanks = "";
    Lib::ParseUtil::updateArtifacts(\$artifactLink, \$blanks);

    leaveContext();

    # Extract parameters and record them as attached data.
    my @paramList = ();
    if (defined $parameters) {
		
	  # FIXME : for structured type that contain ',' the split will NOT work !!!
      my @textParams = split ',', $parameters;
      for my $p (@textParams) {
		my ($name, $type) = $p =~ /\A([^:]+):?(.*)/;
        $name =~ s/\s*//gsm;
        my $option = 0;
		if ($name =~ /\?$/m) {
			$name =~ s/\?$//m;
			$option = 1;
		}
        push @paramList, [$name, $type, $option];
	  }
    }
    
    Lib::NodeUtil::SetXKindData($funcNode, 'parameters', \@paramList);

	# retore previous enclosing
	leaveEnclosing('');
    return $funcNode;
}

sub _parseFunction($) {
    my $kind = shift;

    # get the prototype
    my $prototype = "";

	# Consumes the 'function' (or 'get' or 'set') keyword
	$prototype .= ${getNextStatement()};
	
	return parseRoutine($kind, $prototype);
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
#              Class
##################################################################

sub isNextClass() {
    if ( ${nextStatement()} eq 'class' ) {
    return 1;
  }
  
  return 0;
}

sub parseMethod($) {
	my $prototype = shift;
	$prototype =~ s/^\s+//m;
	$prototype =~ s/\s+$//m;
	$prototype =~ s/\s+</</g;

	my @modifiers = split /\s+/, $prototype;
	
	my $name = pop @modifiers;

	my $proto_without_modifiers = "";

	if ((scalar @modifiers) and (($modifiers[-1] eq 'set') or ($modifiers[-1] eq 'get'))) {
		$proto_without_modifiers .= pop @modifiers;
		$proto_without_modifiers .= ' '.$name;
	}
	else {
		$proto_without_modifiers .= ' '.$name;
	}

	my $methodNode = parseRoutine(MethodKind, $proto_without_modifiers);
	
	return $methodNode;
}

sub parseAttribute($) {
	my $prototype = shift;

	my ($wordsOnly) = $prototype =~ /^($IDENTIFIER|\s)+/m;
	
	my @modifiers = split /\s+/, $wordsOnly;
	
	my $name = pop @modifiers;
	
	my $attrNode = Node(AttributeKind, \$prototype);
	SetLine($attrNode, getStatementLine());
	SetName($attrNode, $name);
	
	if (${nextStatement()} eq ":") {
		getNextStatement(); # get ":"
		my $type = parseTypeExpression();
		Lib::NodeUtil::SetXKindData($attrNode, "type", $type);
	}
	
	if (${nextStatement()} eq "=") {
		getNextStatement(); # get "="
		Append($attrNode, parseVarInit());
	}

	## if last item consumed was a "}", then it is certainly a function's body closing. NO SEMICOLON is then expected !!
	## EXAMPLE : static create: Function = <T>(subscribe?: (subscriber: Subscriber<T>) => TeardownLogic) => {
	##             return new Observable<T>(subscribe);
	##           }
	#if (${Lib::ParseUtil::getLastNonBlankStatement()} ne "}") {
		## BUT IN OTHER CASE semicolon (or closing class "}") is expected.
		## ROBUSTNESS : an attribute (of class or interface) should be ended with a semicolon or a closing }
		## if it is not the case, then purge unexpected item and warn there is some unrecognized patterns in the code.
		#my $next = nextStatement();
		#if (($$next ne ';' ) and ($$next ne '}')) {
			#my $line = getStatementLine();
			#print "[parseAttribute] ERROR : expected end pattern ; or }, but encountered $$next at line $line\n";
			## purge until ; or }
			#parseRawExpression([\&isNextSemiColon, \&isNextClosingAcco]);
		#}
	#}
	
	##if (${nextStatement()} ne '}') {
		#Lib::ParseUtil::purgeSemicolon();
	##}
	
	if (${nextStatement()} ne '}') {
		if (${Lib::ParseUtil::getLastNonBlankStatement()} ne "}") {
			expectSemiColon();     			  	# ";" mandatory
		}
		else {
			Lib::ParseUtil::purgeSemicolon();	# ";" not mandatory after }	
		}
	}
	return $attrNode;
}

sub parseClassMember() {
	my $stmt;
	my $prototype = "";

	while ((defined ($stmt = nextStatement())) && ($$stmt ne "(") and ($$stmt ne ":") and ($$stmt ne "=") and ($$stmt ne ";") and ($$stmt ne "\n")) {
		if ($$stmt eq "<") {
			$prototype .= ${parseChevronExpression(1)};
		}
		else {
			$prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}
	}
	
	if (! defined $stmt) {
		print "[ParseTypeScript::parseMember] ERROR : unterminated class member prototype : $prototype !!!\n";
		return undef;
	}
	
	if ($$stmt eq "(") {
		return parseMethod($prototype);	
	}
	elsif (($$stmt eq ":") or ($$stmt eq "=")) {
		return parseAttribute($prototype);
	}
	elsif ($$stmt eq ";" or $$stmt eq "\n") {
		
		getNextStatement(); # consumes ending!!
		
		my $attrNode = Node(AttributeKind, \$prototype);
		if ($prototype =~ /^($IDENTIFIER)/m) {
			SetName($attrNode, $1);
		}
		SetLine($attrNode, getStatementLine());
		return $attrNode;
	}
	else {
		print "[ParseTypeScript::parseMember] ERROR : unknown member type !!\n";
	}
}

sub parseInterfaceMember();

sub _parseClass($) {
	my $kind = shift;
	
	my $kindName = ($kind eq InterfaceKind ? "interface" : "class");
	my $cb_parseMember = ($kind eq InterfaceKind ? \&parseInterfaceMember : \&parseClassMember);
	
	my $classNode = Node($kind, \$NullString);

    # a function can be nested in an expression, so it introduce until its end a
    # STATEMENT context. So, any expression encountered in the function will not
    # be a sub expression of the expression that contains the function !!!!
    enterContext(STATEMENT);
    
    
    enterEnclosing('');

    # get the prototype
    my $prototype = "";

    # Consumes the 'class' keyword
    $prototype .= ${getNextStatement()};

    while ((defined nextStatement()) && (${nextStatement()} ne '{') ) {
      $prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
    }
    SetStatement($classNode, \$prototype);

    my $line = getStatementLine();
    SetLine($classNode, $line);

    # extract name
    $prototype =~ /^\s*(?:class|interface)\b\s*($IDENTIFIER)/sm;
                  
    my $name = "";

    if ((defined $1) and ($1 ne "extends")) {
      $name = $1;
    }
    else {
      $name = "anonymous_$kindName".Lib::ParseUtil::getUniqID().'_at_line_'.$line;
    }
    SetName($classNode, $name);

    my $artiKey = Lib::ParseUtil::buildArtifactKeyByData($name, $line);
    Lib::ParseUtil::newArtifact($artiKey);

	# parse Class body
    if ((defined nextStatement()) && (${nextStatement()} eq '{') ) {
		getNextStatement();
		
		while ( (defined nextStatement()) && (${nextStatement()} ne '}')) {
			my $memberNode = $cb_parseMember->();
			if (defined $memberNode) {
#print "MEMBER STATEMENT : ".${GetStatement($memberNode)}."\n";
				Append($classNode, $memberNode);
			}
		}
    }
    else {
      print "PARSE ERROR : missing body for $kindName ".GetName($classNode)."\n";
    }
	
	if ((defined nextStatement()) && (${nextStatement()} eq '}') ) {
		getNextStatement();
	}
	else {
		print "[TypeScript/parseClass] ERROR : missing closing acco for class ".GetName($classNode)."\n";
	}
	
    SetEndline($classNode, getStatementLine());

    Lib::ParseUtil::endArtifact($artiKey);

    my $artifactLink = "{__HLARTIFACT__".$artiKey."}";
    my $blanks = "";
    Lib::ParseUtil::updateArtifacts(\$artifactLink, \$blanks);

	leaveEnclosing('');

    leaveContext();

    return $classNode;
}

sub parseClass() {

  if (isNextClass()) {
	  
    if (getContext() == STATEMENT) {
      my $node = _parseClass(ClassDeclarationKind);

      if ((defined nextStatement()) && (isNextSemiColon())) {
	  # trash semicolon
	  getNextStatement();
      }
      return $node;
    }
    else {
      return _parseClass(ClassExpressionKind);
    }

  }
  return undef;
}


sub parseAbstract() {
	if (${nextStatement()} eq 'abstract') {
		
		my $idx = 1;
		while (${nextStatement($idx)} !~ /\S/) {
			$idx++;
		}
		if (${nextStatement($idx)} eq "class") {
			
			# get "bastract keyword
			getNextStatement();
		
			# parse class
			my $classNode = parseClass();
		
			if (defined $classNode) {
				Lib::NodeUtil::SetXKindData($classNode, "abstract", 1);
				return $classNode;
			}
		}
	}
	return undef;
}

##################################################################
#              Interface
##################################################################

# PATTERN :     ( ... ) : <type>
sub parseCallSignature() {
	my $statement = "";
	my $stmt;
	my $nested = -1;

	while ((defined ($stmt=nextStatement())) && (($nested) || ($$stmt ne ")"))) {

		if ($$stmt eq "(") {$nested++;}
		elsif ($$stmt eq ")") {$nested--;}
		$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
	}

	if ((defined nextStatement()) && (${nextStatement()} eq ")")) {
		$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
	}
	else {
		my $line = getNextStatementLine();
		print "[ParseTypeScript::parseCallSignature] ERROR : missing ending parenthese for call signature argument at line $line\n";
		return $statement;
	}
	
	if ((defined nextStatement()) && (${nextStatement()} eq ":")) {
		$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
	}
	else {
		my $line = getNextStatementLine();
		print "[ParseTypeScript::parseCallSignature] ERROR : missing ':' after  call signature argument at line".getStatementLine()."\n";
		return $statement;
	}
	
	$statement .= parseTypeExpression();
	
}

sub parseInterfaceMember() {
	my $stmt;
	my $prototype = "";
	my $attrNode = Node(AttributeKind, \$prototype);
	
	# NAMED PROPERTY
	if (${nextStatement()} =~ /^\s*(?:$IDENTIFIER|<)/) {
		
		$prototype .= "";
		
		while ((defined ($stmt = nextStatement())) && ($$stmt ne "(") and ($$stmt ne ":") and ($$stmt ne ";") and ($$stmt ne "\n")) {
			if ($$stmt eq '<') {
				$prototype .= ${parseChevronExpression(1)};
			}
			elsif ($$stmt eq '[') {
				$prototype .= ${parsePairing()}
			}
			else {
				$prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
			}
		}
	
		if (! defined $stmt) {
			print "[ParseTypeScript::parseInterfaceMember] ERROR : unterminated interface member prototype : $prototype !!!\n";
			return undef;
		}
	
		if ($$stmt eq "(") {
			return parseMethod($prototype);
		}
		elsif ($$stmt eq ":") {
			return parseAttribute($prototype);
		}
		elsif ($$stmt eq ";" or $$stmt eq "\n") {
		
			getNextStatement(); # consumes ending!!

			if ($prototype =~ /^\s*($IDENTIFIER)/m) {
				SetName($attrNode, $1);
			}
			SetLine($attrNode, getStatementLine());
			return $attrNode;
		}
		else {
			print "[ParseTypeScript::parseInterfaceMember] ERROR : unknown interface member type : $prototype!!\n";
		}
	}
	
	# CALL SIGNATURE
	# FUNCTION TYPE property ? I don't think ....
	elsif (${nextStatement()} eq "(") {
		#$prototype .= parseTypeExpression();
		$prototype .= parseCallSignature();
		expectSemiColon();
		return $attrNode;
	}
	# UNDEFINED property
	# [ ... ] : any
	elsif (${nextStatement()} eq "[") {
		$prototype .= ${getNextStatement()}; # get the "["
		SetLine($attrNode, getStatementLine());
		while ((defined ($stmt = nextStatement())) && ($$stmt ne "]")) {
			$prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}
		$prototype .= ${getNextStatement()}; # get the "]"
		
		if (${nextStatement()} eq "?") { getNextStatement();}  # FIXME : trash "?" ! should'nt keep the information ? 
		
		if (${nextStatement()} eq ":") {
			$prototype .= ${getNextStatement()};
			my $type = parseTypeExpression();
			$prototype .= $type;
			expectSemiColon();
			return $attrNode;
		}
	}
	else {
		if (${nextStatement()} ne '}') {
			print "[ParseTypeScript::parseInterfaceMember] ERROR : unknown member syntax : ".${getNextStatement()}." at line ".getStatementLine()."!!\n";
		}
	}
	return undef;
}

sub parseInterface() {

  if (${nextStatement()} eq 'interface') {
	  
      my $node = _parseClass(InterfaceKind);

      if ((defined nextStatement()) && (isNextSemiColon())) {
		# trash semicolon
		getNextStatement();
      }
      return $node;
  }
  return undef;
}

##################################################################
#              NAMESPACE
##################################################################

sub parseNamespace() {
	if (${nextStatement()} eq "namespace") {
		getNextStatement();

		my $namespaceNode = Node(NamespaceKind, createEmptyStringRef());
		SetLine($namespaceNode, getStatementLine());
		
		#my $prototype = "";
		#while ((defined ($stmt = nextStatement())) && ($$stmt ne "{")) {
		#	$prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		#}
		
		# Assume prototype is : namespace <name> {
		# Assume prototype is : namespace <name1>.<name2>... {
		my $name = ${getNextStatement()};
		while (($name =~ /\.$/m) || (${nextStatement()} =~ /^\s*\./m)) {
			# if a component of the namespace is a language keyword, it will be split around the "." ... so concat all parts ...
			$name .= ${getNextStatement()};
		}
#print STDERR "NAMESPACE : $name\n";
		SetName($namespaceNode, $name);
		
		if (${nextStatement()} eq "{") {
			# param value 1 signifies not removing trainling semicolo ...
			Append($namespaceNode, parseAccoBloc());
		}
		else {
			print "[ParseTypeScript::parseNamespace] missing openning { after namespace !. (found ".${nextStatement()}." instead) \n";
		}
		
		return $namespaceNode;
	}
	return undef;
}

##################################################################
#              MODULE
##################################################################

sub parseModule() {
	if (${nextStatement()} eq "module") {
		getNextStatement();

		my $moduleNode = Node(ModuleKind, createEmptyStringRef());
		SetLine($moduleNode, getStatementLine());
		
		#my $prototype = "";
		#while ((defined ($stmt = nextStatement())) && ($$stmt ne "{")) {
		#	$prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		#}
		
		# Assume prototype is : namespace <name> {
		SetName($moduleNode, ${getNextStatement()}); # get name ...
		
		if (${nextStatement()} eq "{") {
			# param value 1 signifies not removing trainling semicolo ...
			Append($moduleNode, parseAccoBloc());
		}
		else {
			print "[ParseTypeScript::parseModule] missing openning { after module !\n";
		}
		
		return $moduleNode;
	}
	return undef;
}


##################################################################
#              ENUM
##################################################################

sub parseEnum() {
	if (${nextStatement()} eq "enum") {
		getNextStatement();
		
		my $stmt;
		my $prototype = "";
		
		my $enumNode = Node(EnumKind, \$prototype);
		SetLine($enumNode, getStatementLine());
		SetName($enumNode, ${getNextStatement()}); # get name ...
		
		if (${nextStatement()} eq "{") {
			# param value 1 signifies not removing trainling semicolo ...
			$prototype .= ${getNextStatement()};
		}
		else {
			print "[ParseTypeScript::parseEnum] missing openning { after enum !\n";
		}
		
		while ((defined ($stmt = nextStatement())) && ($$stmt ne "}")) {
			$prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}

		if (${nextStatement()} eq "}") {
			$prototype .= ${getNextStatement()};
		}
		else {
			print "[ParseTypeScript::parseNamespace] missing closing } after namespace !\n";
		}
		
		expectSemiColon();
		
		return $enumNode;
	}
	return undef;
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

sub splitTypeScript($) {
   my $r_view = shift;

   my  @statements = split /($STRUCTURAL_STATEMENTS|$CONTROL_FLOW_STATEMENTS|$JS_SEPARATOR|$SIMPLE_KEYWORDS)/smi, $$r_view;
   
   if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }
   return \@statements;
}


sub ParseTypeScript($) {
  my $r_view = shift;
  
  my $r_statements = splitTypeScript($r_view);

  Lib::ParseUtil::InitParser($r_statements);

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
  my @MethodList = GetNodesByKind($node, MethodKind);
  
  my %H_KindsLists = ();
  $H_KindsLists{'FunctionDeclaration'}=\@FunctionDeclarationList;
  $H_KindsLists{'FunctionExpression'}=\@FunctionExpressionList;
  $H_KindsLists{'Method'}=\@MethodList;
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

     #TypeScript::ParseTypeScriptPass2::init();
     Lib::ParseUtil::registerParseUnknow(\&parseUnknow);

     # Minified files are known to remove as more spaces as possible.
     # So, after striping phase, en string encoding, the following code :
     #      case"toto":
     # will become :
     #      caseCHAINE_XXX:
     # The following treatment consist in adding missing space before analysis.
     $vue->{'code'} =~ s/\bcase(CHAINE_\d+)/case $1/sg;

     # launch first parsing pass : strutural parse.
     my ($TypeScriptNode, $Artifacts) = ParseTypeScript(\$vue->{'code'});

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

     if (defined $options->{'--print-tree'}) {
       Lib::Node::Dump($TypeScriptNode, *STDERR, "ARCHI");
     }
     if (defined $options->{'--print-test-tree'}) {
       print STDERR ${Lib::Node::dumpTree($TypeScriptNode, "ARCHI")} ;
     }
      
     if (defined $options->{'--print-statement'}) {
		 my @kinds = split(',', $options->{'--print-statement'});
		 for my $kind (@kinds) {
			 my @nodes = GetNodesByKind($TypeScriptNode, $kind);
			 for my $node (@nodes) {
				 my $stmt = GetStatement($node);
				 if (defined $stmt) {
					 print "STATEMENT $kind = $$stmt\n";
				 }
			 }
		 }
	 }
      
      $vue->{'structured_code'} = $TypeScriptNode;
      $vue->{'artifact'} = $Artifacts;

      # pre-compute some list of kinds :
      preComputeListOfKinds($TypeScriptNode, $vue);

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


