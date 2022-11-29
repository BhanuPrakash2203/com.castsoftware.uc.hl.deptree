package Swift::ParseSwift;
# les modules importes
use strict;
use warnings;
#use diagnostics; #FIXME: est-ce compatible Strawberry?
#no warnings 'recursion'; 

use Erreurs;

use CountUtil;

use Lib::Node; # qw( Leaf Node Append );
use Lib::NodeUtil ;
use Lib::NodeUtil qw( SetName SetStatement AppendStatement SetLine GetLine SetEndline GetEndline SetXKindData);
use Lib::ParseUtil;

use Swift::SwiftNode;
use Swift::Identifiers;
use CountUtil;

my $DEBUG = 0;

# statelents separator
# --------------------
# ;
# { }
# \n

my $SWIFT_SEPARATOR = '(?:->|^\s*\@|<<|[;,:{}\n()\[\]<>\?=])';

# statements
# ----------	
# variable 	var name [ = expr] [ ,... ]
#  	let name [ = expr] [ ,... ]
#  	static let name [ = expr] [ ,... ]
#  	typealias name = existing type
#
# for/in 	for (var in collection) statement
# while 	while (expression) statement 
# repeat-while 	repeat statement while (expression)  
# defer 	defer statement
# do-try-catch 	do try (expression) catch (pattern) where (expression); 
# break 	break [label];
# continue 	continue [label];
# return 	return [expression];
# throw 	throw expression;
# switch 	switch expression { statements }
# guard 	guard condition else statement
# if/else 	if condition statement1 [else statement2]
# try	try(?!) expression { statements }
# attributes 	@attribute name(attribute arguments)
# enum 	enum enumName { statements }
# fallthrough 	fallthrough 
# case 	case condition: statement
# case 	case keyword[ ,... ]


# TODO
# compiler statement


# the searching pattern include a look-behind matching to prevent from
# recognize keywords preceded from a $.
my $STRUCTURAL_STATEMENTS = '(?<!\$)\b(?:func|class\s+func|class|struct|extension|protocol|init|enum|closure)\b';

# statement that cannot belong to expression, and then break all statement.
# The javascript parser systematically insert a semicolon before them if the
# previous token was not a closing accolade.
my $CONTROL_FLOW_STATEMENTS = '(?<!\$)(?:\b(?:break|case|continue|default|repeat|while|do|for|if|else|return|switch|fallthrough|throw|throws|try|catch|where|defer|var|let|typealias|const|import|export|with|guard|type|in|get|set)\b)';

my $SIMPLE_KEYWORDS = '(?<!\$)(?:\b(?:new|as)\b)';

# Line beginning with these patterns expect a left operand, and so cannot be
# preceded with a semicolon. Javascript parser never insert a semicolon BEFORE them.
my $NEVER_A_STATEMENT_BEGINNING_PATTERNS = '(?:\*=|/=|%=|\+=|-=|&=|\^=|\|=|<<=|>>=|>>>=|-|\+|\*|\/|\%|<<|>>>|>>|<=|>=|<|>|===|==|!==|!=|=|&&|\||&|\^|\|\||\?|,|:|\.)';

# Line ending with these patterns expect a right operand, and so cannot be
# preceded with a semicolon. Javascript parser never insert a semicolon AFTER them.
my $NEVER_A_STATEMENT_ENDING_PATTERNS = '(?:\*=|/=|%=|\+=|-=|&=|\^=|\|=|<<=|>>=|>>>=|-|\+|\*|\/|\%|<<|>>>|>>|<=|>=|<|>|===|==|!==|!=|=|\|\||&&|\||&|\^|\?|:|,|~|\.)';

# Line beginning with these patterns are always beginning a new instruction.
# Once possible, the javascript parser systematically insert a semicolon before them.
my $STATEMENT_BEGINNING_PATTERNS = '(?:\+\+|--|\@)';

my $IDENTIFIER = Swift::Identifiers::getIdentifiersPattern();

my $re_MODIFIERS = '(?:open|mutating|override|public|private|fileprivate|internal|static|final|lazy)';

my %H_CLOSING = ( '{' => '}', '[' => ']', '<' => '>', '(' => ')' );

my @rootContent = (
				\&parseVar,
				\&parseLet,
				\&parseTypeAlias,
		        \&parseConst, # parseConst must be before parseModifiers
				\&parseFunction,
				\&parseClass,
				\&parseProtocol,
				\&parseModifiers,
				\&parseIf,
				\&parseFor,
				\&parseWhile,
				\&parseRepeatWhile,
				\&parseSwitch,
				\&parseBreak,
				\&parseImport,
		        \&parseReturn,
				\&parseContinue,
		        \&parseThrow,
		        \&parseGuard,
		        \&parseEnum,
		        \&parseDefer,
		        \&parseTry,
				\&parseDo,
				\&parseAttributeLabel,
				\&parseParenthesis,
				\&parseFallthrough,

                );

my @modifierContent = (
		\&parseEnum,
		\&parseVar,
		\&parseLet,
		\&parseTypeAlias,
		\&parseConst,
		\&parseFunction,
		\&parseClass,
		\&parseProtocol,
        \&parseMethod,
);

my @enumContent = (
		\&parseCase,
		\&parseFunction,
		\&parseAttributeLabel,
		\&parseEnum,
		\&parseModifiers,
		\&parseFallthrough,

);

my @classContent = (
			\&parseVar,
			\&parseLet,
			\&parseTypeAlias,
			\&parseClass,
		    \&parseConst, # parseModifiers must be after scanning of artifact that are concerned
            \&parseMethod,
            \&parseModifiers,
			\&parseAttributeLabel,
			\&parseChevronExpression,
			#\&parseFunction,
			\&parseEnum,
			\&parseFallthrough,

);


my @expressionContent = ( 
			\&parseParenthesis,
			\&parsePairing,
			\&parseChevronExpression,
			\&parseTry,
			\&parseReturn,
			\&parseBracket,
		);

my $NullString = '';

my $StringsView = undef;

# This flag indicate to other function that we are inside a "then" expression of the ternary operator.
# Usefull to help interpretation of ":" when encountered.
my @FLAG_InsideTernaryThen = ();

sub getTypeName() {
 
	if (${nextStatement()} =~ /\G(\s*$IDENTIFIER\s*)/gc) {
		my $name = "";
		if (defined $1) {
			$name = $1;
            getNextStatement();
            if (defined nextStatement() && ${nextStatement()} =~ /\G(\:)/gc) {
                $name .= $1;
                getNextStatement();
                if (${nextStatement()} =~ /\G(\s*$IDENTIFIER\s*)/gc) {
                    $name .= $1;
                    getNextStatement();
                }
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

sub resetContext() {
	if (scalar @Context > 1 || (defined $Context[0] && $Context[0] == EXPRESSION)) {
		print STDERR "WARNING: Bad analyzing of previous file (side effect in context management)\n";
	}
	@Context = (STATEMENT);
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

# ##################### ENCLOSINGNESS ############

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

# ################# MAGIC NUMBERS #########################

my %H_MagicNumbers;

sub initMagicNumbers($) {
  my $view = shift;

  %H_MagicNumbers = ();
  $view->{HMagic} = \%H_MagicNumbers;
}

sub declareUnexpectedMagic($) {
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
# print "---> MAGIC = $magic\n";
}

sub getMagicNumbers($$) {
	my $r_expr = shift;
	my $isConstNodeContext = shift;

	# reconnaissance des magic numbers :
	# 1) identifiants commencant forcement par un chiffre decimal.
	# 2) peut contenir des '.' (flottants)
	# 3) peut contenir des 'E' ou 'e' suivis eventuellement de '+/-' pour les flottants
	while ( $$r_expr =~ /(?:^|[^\w])((?:\d|\.\d)(?:[EePp][+-]?|[\d\w\.])*)/sg )
	{
		my $magic = $1;

		if ($isConstNodeContext) {
			my $quotedMagic = quotemeta $magic;
			if ( $$r_expr =~ /^\s*$quotedMagic\s*$/sm) {
				return;
			}
			else {
				# do not make this test if the expression contains other magics.
				$isConstNodeContext = 0;
			}
		}

#    if (! exists $H_MagicNumbers{$magic}) {
#      $H_MagicNumbers{$magic} = 0;
#    }
#    $H_MagicNumbers{$magic}++;

		declareUnexpectedMagic($magic);
	}
}

# ################# MISSING ACCOLADE #########################

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
    if ((${nextStatement()} eq ';') || (${nextStatement()} eq '}')  || (${nextStatement()} eq ')')) {
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

sub isNextWhere() {
    if ( ${nextStatement()} eq 'where' ) {
        return 1;
    }

    return 0;
}

sub isNextAt() {
    if ( ${nextStatement()} =~ /\s*\@/ ) {
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
		
	}
	
	# NOT A FUNCTION EXPRESSION
     # print "nstmt=".${nextStatement()}."\n" if (defined nextStatement());
     # if ((defined nextStatement()) && (${nextStatement()} eq '(')) {
     #   # Consumes the '(' token.
     #   getNextStatement();
     #   enterEnclosing('(');
    #}
 		getNextStatement();

    # parse the parenthesis content
    my $parentNode = Node(ParenthesisKind, createEmptyStringRef());

    SetLine($parentNode, getStatementLine());

    # The content of the parenthesis will be parsed as an expression that end
    # with the matching closing parenthesis.
    enterEnclosing('(');
    parseExpression($parentNode, [\&isNextClosingParenthesis]);
	leaveEnclosing('(');

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
    enterEnclosing('[');
    parseExpression($parentNode, [\&isNextClosingBracket]);
    leaveEnclosing('[');
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

            # If "<" not preceded with identifier, number , closing parenthesis, operator, ellipsis or colon.
            # Expression is not a generic type or operator, so parse <...>
			if ( $lastNonBlank !~ /[\w\)\]!\+\-\.\:\(\,]\s*$/m) {
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
				my ($status, $stmt) = simulateParsePairing(qr/^>$/, qr/^[\{\}\)\];:]$/, $LEVEL_SPECIFIC_KO_REGEXP, 1);
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
sub simulateParsePairing($$;$;$) {
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
	if (${nextStatement()} =~ /^([\{\(])$/m) {
		my $opening = $1;
		# consumes opening
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
			print STDERR "[parsePairing] ERROR : missing closing $closing, openned at line $line\n";
		}
		elsif ($$next eq $closing) {
			$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}
		
		return \$statement;
	}
	return undef;
}

sub simulateParsingClosure($$;$;$) {
    my $ok_reg = shift;
    my $ko_reg = shift;
    my $levelSpecific_KO_regexp = shift || {};
    my $consume_on_succes = shift || 0;

    my $idx = 0;
    my $status = 0; # unsuccess by default
    my $nested = -1; # first count unneeded for the opening {
    my @nestedStack = ();
    my $statement = "";

    my $next;
    while (defined ($next=nextStatement($idx))) {
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

        if ($$next =~ /^[\{\(]$/m) {
            $nested++;
            push @nestedStack, $$next;
        }
        elsif ($$next =~ /^[\}\)]$/m) {
            $nested--;
            pop @nestedStack;
        }

        $statement .= $$next;
        $idx++;
    }

    return $status;
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
#              TERNARY FORM
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

  Swift::SwiftNode::reaffectNodes($cond, $condNode, $node);

  my $flatCond = Swift::SwiftNode::getFlatExpression($condNode);
#print "COND : $$flatCond\n";
  Lib::NodeUtil::SetXKindData($condNode, 'flatexpr', $flatCond);

  my $nodeThen = Node(ThenKind, createEmptyStringRef());
  push @FLAG_InsideTernaryThen, 1;
  Swift::ParseSwift::parseExpression($nodeThen, [\&Swift::ParseSwift::isNextColon]);
  pop @FLAG_InsideTernaryThen;
  
#print "THEN : ".${$nodeThen->[1]}."\n";
  Append($nodeTernary, $nodeThen);
  

  # Consumes the ":".
  getNextStatement();

  my $nodeElse = Node(ElseKind, createEmptyStringRef());
  Swift::ParseSwift::parseExpression($nodeElse, 
	                       [
				\&Swift::ParseSwift::isNextClosingParenthesis, 
			  	\&Swift::ParseSwift::isNextClosingBracket,
				\&Swift::ParseSwift::isNextComma,
				\&Swift::ParseSwift::isNextColon,
				\&Swift::ParseSwift::isNextClosingAcco,
				\&Swift::ParseSwift::isNextSemiColon      # inside a for loop condition for example !!!
				
			       ] );
#print "ELSE : ".${$nodeElse->[1]}."\n";
  Append($nodeTernary, $nodeElse);

  return $nodeTernary;
}


##################################################################
#        RETURN  BREAK  CONTINUE  TYPEALIAS
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
	if (isNextReturn()) {
		# consumes 'return' keyword
		getNextStatement();

		my $prototype = "";

		my $returnNode = Node(ReturnKind, \$prototype);
		SetLine($returnNode, getStatementLine());
		
		# checking body presence
		if (${nextStatement()} eq "{") {
			
			my $stmt;
			while ((defined ($stmt = nextStatement())) && ($$stmt ne "}")) {

				my $artifactNode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);

				Append($returnNode, $artifactNode);

			}
		}
		else {
			parseExpression($returnNode, [\&isNextClosingAcco]);
		}
		return $returnNode;
	}
	return undef;
}


sub isNextThrow() {
    if ( ${nextStatement()} eq 'throw' ) {
    return 1;
  }
  return 0;
}

sub isNextThrows() {
    if ( defined nextStatement() && ${nextStatement()} =~ /(\s*(?:re)?throws)\b\s*/ ) {
    return $1;
  }
  return 0;
}

sub parseThrow() {
  return parseMonoLineInstr(ThrowKind, \&isNextThrow);
}

sub parseThrows($) {
	my $node = shift;
	if (my $pattern = isNextThrows()) {
		my $stmt = ${Lib::ParseUtil::getSkippedBlanks()}.$pattern;
		AppendStatement($node, \$stmt) if (defined $stmt);
		# consumes throws keyword
		getNextStatement();
	}
}

sub isNextNilCoalescingOperator() {
    if ( defined nextStatement() && ${nextStatement()} eq '?' 
		&& defined nextStatement(2) && ${nextStatement(2)} eq '?' ) {
        return 1;
    }
    return 0;
}

sub parseOperator($) {
	my $node = shift;
	my $stmt;
	if (isNextNilCoalescingOperator()) {
		$stmt = '??';
	}
	else{
		# ? or ! suffix
		if (defined nextStatement && ${nextStatement()} =~ /([?!])/) {
			$stmt = $1;
		}
	}
	if (defined $stmt) {
		getNextStatement();
		getNextStatement() if ($stmt eq '??');

		AppendStatement($node, \$stmt);
	}
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

# sub parseFatArrowFunctionExpressionWithoutParenthesedParam() {
	# if ( ${nextStatement()} =~ /\w+\s*$/m) {
		
	# }
# }

sub parseExpression($;$$) {
	my $parent =shift;
	my $cb_end = shift;
	my $isConstNode = shift; # indicates whether the expression being parsed is
                         # a var declaration initialisation.
                        
    # true if the keyword 'new' is encountered.
    # In this case, when encountering a "<" it is certainely a template openning, and not a comparison operator.
   # my $new_context = 0;

	if (! defined $isConstNode) {
        $isConstNode = 0;
	}

	enterContext(EXPRESSION);

	my $endOfStatement = 0;
	my $r_statement = GetStatement($parent);
	my @previousStatement;
	my $currentStatement;
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

        if (defined nextStatement()){
            push(@previousStatement, ${nextStatement()});
            shift @previousStatement if (scalar @previousStatement > 2); # cleaning memory

            if (defined $previousStatement[-2]){
                $currentStatement = $previousStatement[-2];
            }
            else{
                $currentStatement = $previousStatement[-1];
            }
        }

		if (! $endOfStatement) {

			my $subNode;
            if (defined nextStatement() && ${nextStatement()} eq '{') {
                my $status = simulateParsingClosure(qr/^(\}|\-\>|in)$/, qr/^\s*(get|willSet|set|didSet)\s*$/, $LEVEL_SPECIFIC_KO_REGEXP);
                if ($status == 1) {
                    $subNode = parseClosure();
                }
                else {
                    # properties
                    getNextStatement();
                    my $kind;
                    while (defined nextStatement() && ${nextStatement()} =~ /^\s*(get|willSet|set|didSet|return)\b/sm) {
                        if ($1 eq 'get') {$kind = GetterKind;}
                        elsif ($1 eq 'willSet') {$kind = WillSetKind;}
                        elsif ($1 eq 'set') {$kind = SetterKind;}
                        elsif ($1 eq 'didSet') {$kind = DidSetKind;}
                        Append($parent, parseProperties($kind));
                    }
                }
            }
            # nil coalescing operator ??
            elsif (defined $currentStatement && $currentStatement eq '?' && ${nextStatement()} eq '?')
            {
                $subNode = undef;
            }
            # statement is a '?' exactly
            elsif (defined $currentStatement && $currentStatement =~ /\s$/m && ${nextStatement()} eq '?' && ${nextStatement(1)} =~ /^\s/m){
                $subNode=parseTernaryOp($r_statement, $parent);
            }
            # elsif (defined nextStatement() && ${nextStatement()} eq "#"){
                # # preprocessor flags detected (end of expression)
                # last;
            # }
            else {
                # Next token belongs to the expression. Parse it.
                $subNode = Lib::ParseUtil::tryParse(\@expressionContent);
            }

			if (defined $subNode) {
				# *** SYNTAX has been recognized by CALLBACK
				if (ref $subNode eq "ARRAY") {
					Append($parent, $subNode);
					refineNode($subNode, $r_statement) if ($$r_statement ne 'where');
					
					$$r_statement .= ${Lib::ParseUtil::getSkippedBlanks()} . Swift::SwiftNode::nodeLink($subNode);
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
				# elsif (${nextStatement()} eq "=>") {
					# if ( $$stmt =~ /^(.*?)(\w+\s*)$/m) {
						# # first part ($1) that do not belong to the function expression
						# $$r_statement .= $skippedBlanks . $1;
						
						# # second part ($2) that is the parameter of the function expression
						# my $funcNode = parseRoutine(FunctionExpressionKind, $2);
						# Append($parent, $funcNode);
						# refineNode($funcNode, $r_statement);
						# $$r_statement .= Swift::SwiftNode::nodeLink($funcNode);
					# }
				# }
				else {
					# final DEFAULT treatment
					$$r_statement .= $skippedBlanks . $$stmt;
				}
			}

        }

		if ( nextTokenIsEndingInstruction($r_statement)) {
			last;
		}
	}
	
	getMagicNumbers($r_statement, $isConstNode);

	SetStatement($parent, $r_statement);

# print "EXPRESSION : <$$r_statement>\n";

	leaveContext();
    expectSemiColon();

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

sub parseTypeExpression() {
	my $type = "";
	my $stmt;

    $stmt = ${nextStatement()};

    # Searching type before <...>
    # i.e: Array <...>, Optional <...>, Dictionary <...>, Set <...>
    if ($stmt =~ /\w+/ && ((defined nextStatement(1) && ${nextStatement(1)} eq '<')
        || (defined nextStatement(2) && ${nextStatement(2)} eq '<'))) {
        # consumes keyword
        $type .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};

        # Searching chevron expression <...> after type
        if (defined nextStatement() && ${nextStatement()} eq '<'){
            $type .= ${parseChevronExpression()};
        }
    }
    # parse parentheses
    elsif (defined nextStatement() && ${nextStatement()} =~ /[\(]/gc) {
        $type .= ${parsePairing()};
    }
    # parse parentheses
    elsif (defined nextStatement() && ${nextStatement()} =~ /[\[]/gc) {
        parseBracket();
    }
    # Searching simple type (i.e. Int, String, ...)
    else {
        my $name = getTypeName();
        if (defined $name) {
            $type .= $name;
        }
    }

    # print "TYPE = $type\n";
	return $type;
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

sub isNextTypeAlias() {
  if ( ${nextStatement()} eq 'typealias' ) {
    return 1;
  }
  
  return 0;
}

sub isNextConst() {
  if ( ${nextStatement()} eq 'static' &&  ${nextStatement(2)} eq 'let') {
    return 1;
  }
  
  return 0;
}

sub parseVarInit(;$) {
    my $isConstNode = shift;

    my $initNode = Node(InitKind, createEmptyStringRef());
    enterEnclosing('');
    # "1" signifies we are in var init at declaration.
    # isNextElse is used for terminating <guard let> condition
    parseExpression($initNode, [ \&isNextClosingBracket, \&isNextElse, \&isNextComma, ], $isConstNode);
    leaveEnclosing('');

    return $initNode;
}

sub parseOneVar(;$) {
    my $isConstNode = shift;

	if (${nextStatement()} =~ /\s*($IDENTIFIER)/) {
		my $name = $1;
		my $singleVarNode = Node(VarDeclKind, \$NullString);
		SetName($singleVarNode, $name);
		SetStatement($singleVarNode, getNextStatement());
		SetLine($singleVarNode, getStatementLine());
		
		my $type;
		# check and parse type
		if (${nextStatement()} eq ":") {
			getNextStatement();
			$type = parseTypeExpression();
			Lib::NodeUtil::SetXKindData($singleVarNode, "type", $type);
		}

		# managing nil coalescing operator or optional ?! operator
		parseOperator($singleVarNode);

		# Check presence of initialization
		# initialization can be done with equal or an opening acco when var type is used
        if (defined nextStatement() && ${nextStatement()} =~ /\=|\{/) {
            my $kind;
            if (${nextStatement()} eq '=') {
                # consumes equal
                getNextStatement();
                my $varInitNode = parseVarInit($isConstNode);
                if (defined $varInitNode) {
                    Append($singleVarNode, $varInitNode);
                }
            }
            # Properties
            elsif (defined nextStatement() && ${nextStatement()} eq '{') {
                my $idx_nextNonBlank = Lib::ParseUtil::getIndexOfNextNonBlank(0, 1);
                #properties
                if (${nextStatement($idx_nextNonBlank)} =~ /^\s*(get|willSet|set|didSet)\b/sm) {
                    # consumes {
                    getNextStatement() if (defined nextStatement() && ${nextStatement()} eq '{');
                    while (defined nextStatement() && ${nextStatement()} =~ /^\s*(get|willSet|set|didSet|return)\b/sm) {
                        if ($1 eq 'get') {$kind = GetterKind;}
                        elsif ($1 eq 'willSet') {$kind = WillSetKind;}
                        elsif ($1 eq 'set') {$kind = SetterKind;}
                        elsif ($1 eq 'didSet') {$kind = DidSetKind;}
                        Append($singleVarNode, parseProperties($kind));
                        if (defined nextStatement() && ${nextStatement()} eq '}') {
                            # consumes }
                            getNextStatement();
                        }
                    }
                }
                # getter implicit
                elsif (defined nextStatement($idx_nextNonBlank) && ${nextStatement($idx_nextNonBlank)} ne '}') {
                    #Append($singleVarNode, parseClosure());
                    $kind = GetterKind;
                    Append($singleVarNode, parseProperties($kind, 1));
                }
            }
		}
		return $singleVarNode;
	}
	# Lib::ParseUtil::log("Missing identifier for var declaration at line ".getStatementLine().", not a identifier : ".${nextStatement()}."\n");
	return undef;
}	

sub parseVarStatement($) {
	my $kind = shift;

    my $varNode = Node($kind, \$NullString);

    # consumes var or let keyword
    getNextStatement();

    SetLine($varNode, getStatementLine());
    my $isConstNode;
    if ($kind eq ConstKind) {
        $isConstNode = 1;
    }
	my $endVar = 0;

    while (! $endVar && defined nextStatement()) {
        # parse each variable declaration of the var statement
        my $singleVarNode = parseOneVar();
        if (defined $singleVarNode) {
            Append($varNode, $singleVarNode);

            if (defined nextStatement()) {
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

sub parseVar() {
	if (isNextVar()) {
		return parseVarStatement(VarKind);
	}
	return undef;
}

sub parseLet() {
	if (isNextLet()) {
		return parseVarStatement(ConstKind);
	}
	return undef;
}

sub parseTypeAlias() {
	return parseMonoLineInstr(TypeAliasKind, \&isNextTypeAlias);
}

sub parseConst() {
	if (isNextConst()) {
		my $idx = 1;
		while (${nextStatement($idx)} !~ /\S/) {
			$idx++;
		}
		# consumes static modifier
		getNextStatement();

		# if (${nextStatement($idx)} eq "enum") {
			# getNextStatement(); # get const keyword
			# my $enumNode = parseEnum();
			# Lib::NodeUtil::SetXKindData($enumNode, 'const', 1);
			# return $enumNode;
		# }
		# else {
			return parseVarStatement(ConstKind);
		# }
	}
	return undef;
}

##################################################################
#              CONDITION
##################################################################

sub parseCondition(;$) {
    my $kind = shift;
    my $condNode = Node(CondKind, createEmptyStringRef);

  # Consumes the opening parenthesis of the condition.
    if (defined ${nextStatement()} && ${nextStatement()} eq '('){
        getNextStatement();
    }
    enterEnclosing('');
    # isNextColon is used for terminating where condition in case statements
    # isNextClosingAcco is used for terminating while condition in repeat-while
    if (defined $kind eq 'case') {
        parseExpression($condNode, [ \&isNextColon, \&isNextClosingAcco ]);
    }
    else{
        parseExpression($condNode, [\&isNextOpenningAcco, \&isNextClosingAcco]);
    }
    leaveEnclosing('');

    # Consumes the closing parenthesis of the condition.
    if (defined nextStatement() && ${nextStatement()} eq ')'){
        getNextStatement();
    }
    Lib::NodeUtil::SetXKindData($condNode, 'flatexpr', Swift::SwiftNode::getFlatExpression($condNode));

    return $condNode;
}

##################################################################
#              SWITCH
##################################################################

sub parseCase() {
	if (isNextCase()) {
		# consumes the 'case' token
		getNextStatement();

		my $caseNode = Node(CaseKind, createEmptyStringRef);
		SetLine($caseNode, getStatementLine());

		# parse the condition of the case, that ends with a colon.
		my $caseExprNode = Node(CaseExprKind, createEmptyStringRef);
		parseExpression($caseExprNode, [\&isNextColon, \&isNextAt]);

		Append($caseNode, $caseExprNode);

        if (${nextStatement()} eq 'where') {
            my $condNode = parseCondition('case');
            Append($caseNode, $condNode);
        }
		if (${nextStatement()} eq ':') {
			getNextStatement();

			# parse case statement
			Lib::ParseUtil::parseStatementsBloc($caseNode, [\&isNextCase, \&isNextDefault, \&isNextClosingAcco], \@rootContent, 1, 0 ); # keepClosing:1, noUnknowNode:0
		}

        SetEndline($caseNode, getStatementLine());
        return $caseNode;
	}
	return undef;
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

sub parseFallthrough() {
  return parseMonoLineInstr(FallthroughKind, \&isNextFallthrough);
}

sub isNextSwitch() {
    if ( ${nextStatement()} eq 'switch' ) {
    return 1;
  }

  return 0;
}

sub isNextFallthrough() {
    if ( ${nextStatement()} eq 'fallthrough' ) {
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

    if (defined nextStatement()) {
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

sub isNextRepeat() {
    if ( ${nextStatement()} eq 'repeat' ) {
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
    # if (${nextStatement()} eq '(') {
      Append($loopNode, parseCondition());

      # parse body
      if (${nextStatement()} eq '{') {
       	Append($loopNode, parseAccoBloc());
      }
      else {
	declareMissingAcco();
        Append($loopNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
      }
    # }

    return $loopNode;
  }

  return undef;
}

sub parseFor() {
  if (isNextFor()) {
    my $ForNode = Node(ForKind, createEmptyStringRef());
    my $ForCondNode = Node(CondKind, createEmptyStringRef());

    SetLine($ForNode, getStatementLine());

    # Consumes the 'for' keyword
    getNextStatement();

	# CONDITION CLAUSE
	# ----------------
	parseExpression($ForCondNode, [\&isNextOpenningAcco]);

	Lib::NodeUtil::SetXKindData($ForCondNode, 'flatexpr',
						 Swift::SwiftNode::getFlatExpression($ForCondNode));

	# managing in collection (e.g.) for condition in collection {statement}
	my $stmt;
	if (defined nextStatement() && ${nextStatement()} eq 'in') {
		$stmt .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		while (defined nextStatement() && ${nextStatement()} ne '{'){
			$stmt .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}
	}
	AppendStatement($ForCondNode, \$stmt) if (defined $stmt);
    Append($ForNode, $ForCondNode);
      # parse body
    if (defined nextStatement() && ${nextStatement()} eq '{') {
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

sub parseRepeatWhile() {

  if (isNextRepeat()) {
    my $repeatNode = Node(RepeatKind, \$NullString);

    # Consumes the 'repeat' keyword
    getNextStatement();

    SetLine($repeatNode, getStatementLine());

    # parse body
    if (${nextStatement()} eq '{') {
      Append($repeatNode, parseAccoBloc());
    }
    else {
      declareMissingAcco();
      Append($repeatNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
    }

    # get the while condition
    if ((defined nextStatement()) && (${nextStatement()} eq 'while')) {

      my $whileNode=Node(WhileKind, \$NullString);

      # consumes the 'while' keyword.
      getNextStatement();

      Append($whileNode, parseCondition());

      Append($repeatNode, $whileNode);
    }

    expectSemiColon();

    return $repeatNode;
  }

  return undef;
}

sub isNextDo() {
    if ( ${nextStatement()} eq 'do' ) {
    return 1;
  }

  return 0;
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

    # get the catch conditions
    while ((defined nextStatement()) && (${nextStatement()} eq 'catch')) {

		my $catchNode=Node(CatchKind, \$NullString);

		# consumes the 'catch' keyword.
		getNextStatement();

		my $stmt;
        while (defined nextStatement() && ${nextStatement()} ne '{' && ${nextStatement()} ne 'where') {
			$stmt .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}
		AppendStatement($catchNode, \$stmt) if (defined $stmt);

		#parse condition
		if (defined nextStatement() && ${nextStatement()} eq 'where') {
			Append($catchNode, parseCondition());
		}

        # parse body
        if (defined nextStatement() && ${nextStatement()} eq '{') {
            Append($catchNode, parseAccoBloc());
        }

		Append($doNode, $catchNode);
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

    return $ifNode;
  }

  return undef;
}

##################################################################
#              GUARD
##################################################################

sub isNextGuard() {
    if ( ${nextStatement()} eq 'guard' ) {
    return 1;
  }

  return 0;
}

sub isNextElse() {
    if ( ${nextStatement()} eq 'else' ) {
        return 1;
    }

    return 0;
}

sub parseGuard() {

  if (isNextGuard()) {
    my $guardNode = Node(GuardKind, \$NullString);

    # Consumes the 'guard' keyword
    getNextStatement();

    SetLine($guardNode, getStatementLine());
    if (${nextStatement()} eq 'let'){
        Append($guardNode, parseLet());
    }
    else {
        # get the condition
        Append($guardNode, parseCondition());
    }
    # parse else branch
    if ((defined nextStatement()) && (${nextStatement()} eq 'else')) {
        my $elseNode = Node(ElseKind, createEmptyStringRef);
        Append($guardNode, $elseNode);
        # consumes the "else" token.
        getNextStatement();
        if (${nextStatement()} eq '{') {
            Append($elseNode, parseAccoBloc());
        }
        else {
            #if (${nextStatement()} ne 'guard') {
            #    declareMissingAcco();
            #}
            Append($elseNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
        }
    }

    return $guardNode;
  }

  return undef;
}

##################################################################
#              DEFER
##################################################################

sub isNextDefer() {
    if ( ${nextStatement()} eq 'defer' ) {
    return 1;
  }

  return 0;
}

sub parseDefer() {

  if (isNextDefer()) {
    my $deferNode = Node(DeferKind, \$NullString);

    # Consumes the 'guard' keyword
    getNextStatement();

    SetLine($deferNode, getStatementLine());

	if (${nextStatement()} eq '{') {
	  Append($deferNode, parseAccoBloc());
	}
	else {
	  if (${nextStatement()} ne 'defer') {
		declareMissingAcco();
	  }
	  Append($deferNode, Lib::ParseUtil::tryParse_OrUnknow(\@rootContent));
	}

    return $deferNode;
  }

  return undef;
}

##################################################################
#              TRY
##################################################################

sub isNextTry() {
    if ( ${nextStatement()} eq 'try' ) {
    return 1;
  }

  return 0;
}

sub parseTry() {
    if (isNextTry()) {

        # consumes 'try' keyword
        my $prototype = ${getNextStatement()};

        # consumes forced unwrap operator "!" or optional operator "?"
        if (${nextStatement()} eq "!" || ${nextStatement()} eq "?") {
            $prototype .= ${getNextStatement()};
        }

        my $tryNode = Node(TryKind, \$prototype);
        SetLine($tryNode, getStatementLine());
        enterEnclosing('');
        # isNextColon (i.e ternary form with try in then statement)
        parseExpression($tryNode, [ \&isNextOpenningAcco, \&isNextColon ]);
        leaveEnclosing('');
        #getEnclosing();

        return $tryNode;
    }
    return undef;
}

##################################################################
#              FUNCTION
##################################################################

sub isNextFunction() {
    if ( ${nextStatement()} =~ /static\s+func/ || ${nextStatement()} eq 'func' || ${nextStatement()} eq 'init') {
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

	# PARSE UNTIL PARAMETER or {
	while ((defined nextStatement()) && (${nextStatement()} ne "(") && (${nextStatement()} ne "{")) {
		$prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
	}

    if ($prototype =~ /\<(.*?)\>/) {
        parseGenericParameter($funcNode, $1);
    }

	my $line = getNextStatementLine();
    SetLine($funcNode, $line);

	# PARSE THE PARAMETERS ...
	my $parameters = "";
	my $stmt;
	my $nested = -1;

	if (!defined nextStatement()) {
		print "[ParseSwift::parseRoutine] ERROR : unterminated function declaration !!!\n";
		leaveContext();
		# restore prvious enclosing
		leaveEnclosing('');
		return $funcNode;
	}

	if (${nextStatement()} eq '(') {
		# get the "("
		$prototype .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};

        $nested++;
        while ((defined($stmt = nextStatement())) && (($nested) || ($$stmt ne ")"))) {
            if ($$stmt eq "(") {$nested++;}
            elsif ($$stmt eq ")") {$nested--;}

			# supporting closure as parameter
            # TODO manage closure's parameters
            if ($$stmt eq '->') {
                # print "Closure as parameter at line ".getStatementLine()."\n";
                my $closureNode = Node(ClosureAsParamKind, "");
                SetLine($closureNode, getStatementLine());
                Append($funcNode, $closureNode);
                $parameters =~ s/\(\)//;
                $parameters =~ s/\:/\:\[closure\]/;
            }

            $parameters .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};

        }

        $prototype .= $parameters if (defined $parameters);

        if ((defined nextStatement()) && (${nextStatement()} eq ")")) {
            $prototype .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
        }
        else {
            print "[ParseSwift::parseRoutine] ERROR : missing ending parenthese for method parameters at line " . GetLine($funcNode) . "\n";
        }
	}

    # Extract parameters and record them as attached data.
    my @paramList = ();
    if (defined $parameters) {
        my $textParams = splitParameters($parameters);

        for my $p (@{$textParams}) {
            # regex for matching <argumentLabel argumentName: typeArgumen>t
            # TODO: argumentLabel is not yet captured
            my ($name, $type) = $p =~ /([\w\_\-]+)\s*:(.*)/;
            my $option = 0;
            if (defined $name) {
                $name =~ s/\s*//gsm;
                if ($name =~ /\?$/m) {
                    $name =~ s/\?$//m;
                    $option = 1;
                }
            }
            push @paramList, [$name, $type, $option, undef , $name];
        }
    }

    Lib::NodeUtil::SetXKindData($funcNode, 'parameters', \@paramList);

    # managing throws exception (if function contains a return type)
	parseThrows($funcNode);

	# PARSE RETURN TYPE if any.
	# -------------------------
	# support function syntax
	# func funcname (parameters) -> ([name:]returnType1, [name:]returnType2...) [-> ([name:]returnType3)]
    # where condition { statements }

	my $returnType = "";
	if ((defined nextStatement()) && (${nextStatement()} eq "->")) {
		$returnType = parseReturnType();

		Lib::NodeUtil::SetXKindData($funcNode, "returnType", $returnType);
	}
	# Generic Where Clauses
	if ((defined nextStatement()) && (${nextStatement()} eq "where")) {
        Append($funcNode, parseWhere());
	}
    # extract name
    $prototype =~ /^\s*(?:func\b)?\s*($IDENTIFIER)?/sm;

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

		# managing throws exception (if function not contains a return type)
		parseThrows($funcNode);

		# managing nil coalescing operator or optional ?! operator
		parseOperator($funcNode);

		# PARSE ACCOLADE BODY
		if ((defined nextStatement()) && (${nextStatement()} eq '{') ) {

            # declare a new artifact
            my $artiKey = Lib::ParseUtil::newArtifact('func_'.$name, $line);
            SetXKindData($funcNode, 'artifact_key', $artiKey);

            # param value 1 signifies not removing trainling semicolo ...
			Append($funcNode, parseAccoBloc(1));

            #end of artifact
            Lib::ParseUtil::endArtifact($artiKey);
            SetXKindData($funcNode, 'code_body', Lib::ParseUtil::getArtifact($artiKey));
		}
		else {
			# print "WARNING : missing body for function/method ".GetName($funcNode)." at line ".GetLine($funcNode)."\n";
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

	# retore previous enclosing
	leaveEnclosing('');
    return $funcNode;
}

sub _parseFunction($) {
    my $kind = shift;

    # get the prototype
    my $prototype = "";

	# Consumes the func keyword
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
			print STDERR "WARNING: not in STATEMENT mode routine at line ". getStatementLine()."\n";
		}
	}
  return undef;
}

sub parseReturnType() {
	my $returnType = "";

	# trashes the ->
    getNextStatement();

	my $returnTypeNode = Node(TypeKind, createEmptyStringRef());

	parseExpression($returnTypeNode, [ \&isNextOpenningAcco, \&isNextWhere ]);

    $returnType = Swift::SwiftNode::getFlatExpression($returnTypeNode);

	$returnTypeNode = undef;

#    print "returnType = $$returnType\n";
	return \$returnType;
}

sub splitParameters($) {
    my $parameters = shift;
    my $contextParenthesis = 0;
    my @index;

    while ($parameters =~ /(\,|\(|\))/mg) {
        if (defined $1 && $1 eq "," && $contextParenthesis == 0) {
            # print "comma without parenthesis context at position ".pos($parameters)."\n";
            push (@index, pos($parameters));
        }
        elsif (defined $1 && $1 eq "(") {
            $contextParenthesis = 1;
        }
        elsif (defined $1 && $1 eq ")") {
            $contextParenthesis = 0;
        }
    }
    pos($parameters) = undef;

    my $offset = 0;
    my @textParams;
    my $lengthReplacement;
    for my $index (@index) {
        $lengthReplacement = $index - $offset;
        $lengthReplacement--; # no catching the comma

        push(@textParams, substr($parameters, $offset, $lengthReplacement));
        $offset = $index;
    }
    $lengthReplacement = length($parameters) - $offset;
    push(@textParams, substr($parameters, $offset, $lengthReplacement));

    return \@textParams;
}

sub parseWhere(){
	my $stmt;

	# trashes the where
	$stmt = ${nextStatement()};

	my $whereCondNode = Node(CondKind, createEmptyStringRef());

	parseExpression($whereCondNode, [ \&isNextOpenningAcco, \&isNextClosingAcco ]);

	return $whereCondNode;
}

sub isNextProperties() {
    if ( ${nextStatement()} =~ /^\s*(get|willSet|set|didSet|return)\b/sm) {
        return 1;
    }

    return 0;
}

sub parseProperties($;$) {

    my $kind = shift;
    my $boolImplicit = shift; # 1 for getter implicit

    if (isNextProperties() || $boolImplicit == 1) {

        if (isNextProperties()) {
            if ($1 eq 'get') {$kind = GetterKind;}
            elsif ($1 eq 'willSet') {$kind = WillSetKind;}
            elsif ($1 eq 'set') {$kind = SetterKind;}
            elsif ($1 eq 'didSet') {$kind = DidSetKind;}
            # trashes the get|willSet|set|didSet
            getNextStatement();
        }

        my $node;

		$node = Node($kind, createEmptyStringRef());

		# PARSE (...) IF ANY BEFORE {
		my $nameAttribute;
		if (defined nextStatement() && ${nextStatement()} eq "(") {
			getNextStatement();
			while ((defined nextStatement()) && (${nextStatement()} ne ")")) {
				$nameAttribute .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
			}
		}
		SetName($node, $nameAttribute) if (defined $nameAttribute);

		# trashes the )
		getNextStatement() if (${nextStatement()} eq ')');
		# body
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			getNextStatement() if (${nextStatement()} eq '{');
			enterEnclosing('');
			while ((defined nextStatement()) && (${nextStatement()} ne '}')) {
				my $subnode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);
				if (defined $subnode) {
					Append($node, $subnode);
				}
			}
			leaveEnclosing('');
			# trashes the }
			getNextStatement() if (${nextStatement()} eq '}');
		}
        
        return $node;
    }

    return undef;
}

sub isNextClosure() {
    if ( ${nextStatement()} =~ /\{|\(/ ) {
        return 1;
    }

    return 0;
}
 

sub parseClosure() {
    # general form closure:
    # * { (parameters_with_or_without_parenthesis) (-> return type)* in
    # *		statements
    # * }
    #
    # trailing closure:
    # * someFunctionThatTakesAClosure(<closureName>: {
    # *     // closure's body goes here
    # * })
    # * someFunctionThatTakesAClosure() {
    # *     // trailing closure's body goes here
    # * }
    #
    # closure as function's parameter in a function declaration:
    # func somefuntionTakesAclosure(<closureName>:()->Void) {
    #    // function's body
    # }
    #
    # escaping closure:
    # * func someFunctionWithEscapingClosure(completionHandler: @escaping () -> Void) {
    # *     completionHandlers.append(completionHandler)
    # * }
    #
    # autoclosure:
    # * func serve(customer customerProvider: @autoclosure () -> String) {
    # *     print("Now serving \(customerProvider())!")
    # * }
    # -------------------
    # NOT YET IMPLEMENTED
    #
    # closure in TypeAlias:
    # public typealias ClosureType = (x: Int, y: Int) -> Int
    #

	if (isNextClosure()) {

        my $prototype;
        my $closureNode = Node(ClosureKind, \$prototype);
        SetLine($closureNode, getStatementLine());

        if (defined nextStatement() && ${nextStatement()} eq '{') {
            getNextStatement();
        }

        my $parameters;
        my $bool_param = 0;
		if (defined nextStatement() && ${nextStatement()} eq '(') {
            # get the "("
            $prototype .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
            $bool_param = 1;
        }

        # checking parameters
        while ( defined nextStatement(1) && ( ${nextStatement(1)} eq 'in'
            || ${nextStatement(1)} eq ',' || ${nextStatement(1)} eq ':' || ${nextStatement(1)} eq '->' )
            || $bool_param == 1) {
            $parameters .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};

            if (defined nextStatement() && ${nextStatement()} eq ':') {
                #consumes the :
                $parameters .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
                $parameters .= parseTypeExpression();
            }

            if (defined nextStatement() && ${nextStatement()} eq ',') {
                $parameters .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
            }
            else {
                last;
            }
        }

        $prototype .= ${Lib::ParseUtil::getSkippedBlanks()} . $parameters if (defined $parameters);

        if (defined nextStatement() && ${nextStatement()} eq ')') {
            # get the ")"
            $prototype .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
        }

        # managing throws exception (if closure contains a return type)
        parseThrows($closureNode);

        if (defined nextStatement() && ${nextStatement()} eq '->') {
			$prototype .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
			my $returnType .= parseTypeExpression();
			Lib::NodeUtil::SetXKindData($closureNode, "type", $returnType);
			$prototype .= $returnType;
        }

        if (defined nextStatement() && ${nextStatement()} ne ')') {
            # CLOSURE STATEMENT
            if (defined nextStatement() && (${nextStatement()} eq 'in' || ${nextStatement()} eq '{')) {
                $prototype .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
            }
            enterEnclosing('');
            while ((defined nextStatement()) && (${nextStatement()} ne '}')) {
                my $subnode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);
                if (defined $subnode) {
                    Append($closureNode, $subnode);
                }
            }
            leaveEnclosing('');
        }
        my @paramList = ();
        # if parameters contains ($0, $1...) it's a Shorthand Argument Names and should not be analyzed like parameters
        if (defined $parameters && $parameters ne ")" && $parameters !~ /\$[0-9]+/) {

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
                push @paramList, [$name, $type, $option, undef, $name];
            }
        }

        Lib::NodeUtil::SetXKindData($closureNode, 'parameters', \@paramList) if (scalar @paramList > 0);

        # consumes the '}'
        if (defined nextStatement() && ${nextStatement()} eq '}') {
            getNextStatement();
        }
        # consumes the pair of parenthesis in case of call of closure
        if (defined nextStatement() && ${nextStatement()} eq '(') {
            $prototype .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
            if (defined nextStatement() && ${nextStatement()} eq ')') {
                $prototype .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
            }
            else {
                print STDERR "WARNING: unexpected statement for call closure\n";
            }
        }

        SetEndline($closureNode, getStatementLine());

        return $closureNode;
	}
	return undef;
}

##################################################################
#              Class
##################################################################

sub isNextClass() {
    if ( ${nextStatement()} =~ /^(class|struct|extension)$/m ) {
        return $1;
    }

    return 0;
}

sub isNextMethod() {
    if ( ${nextStatement()} =~ /class\s+func/ || ${nextStatement()} eq 'func' || ${nextStatement()} eq 'init') {
        return 1;
    }

    return 0;
}

sub parseMethod($) {

    if (isNextMethod()) {

        # get the prototype
        my $prototype = "";

        # Consumes the func keyword
        $prototype .= ${getNextStatement()};

        my $methodNode = parseRoutine(MethodKind, $prototype);

        return $methodNode;
    }
    return undef;
}

sub parseGenericParameter($$) {
	my $funcNode = shift;
	my $prototype = shift;

    # Extract parameters and record them as attached data.
    my @paramList = ();
    if (defined $prototype) {
        my @textParams = split (/\,/, $prototype);

        for my $p (@textParams) {
            my $where;
            if ($p =~ /where\s+(.*)/) {
                $where = $1;
                $p =~ s/where\s+$where// if (defined $where);
            }
            my ($name, $type) = $p =~ /\A([^:]+):?(.*)/;
            my $option = 0;
            if (defined $name) {
                $name =~ s/\s*//gsm;
                if ($name =~ /\?$/m) {
                    $name =~ s/\?$//m;
                    $option = 1;
                }
            }
            push @paramList, [$name, $type, $option, $where];
        }
    }

    Lib::NodeUtil::SetXKindData($funcNode, 'generic_param', \@paramList);
}

sub _parseClass($) {
	my $kind = shift;

	my $kindName = ($kind eq ProtocolKind ? "protocol" : "class");
	# my $cb_parseMember = ($kind eq ProtocolKind ? \&parseProtocolMember : \&parseClassMember);

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

    if ($prototype =~ /\<(.*?)\>/) {
        parseGenericParameter($classNode, $1);
    }

    my $line = getStatementLine();
    SetLine($classNode, $line);

    # extract name
    $prototype =~ /^\s*(?:class|struct|protocol|extension)\b\s*($IDENTIFIER)/sm;

    my $name = "";

    # if ((defined $1) and ($1 ne "extends")) {
    if (defined $1) {
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
			my $subnode = Lib::ParseUtil::tryParse_OrUnknow(\@classContent);
			if (defined $subnode){
				Append($classNode, $subnode);
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
		print "[Swift/parseClass] ERROR : missing closing acco for class ".GetName($classNode)." at line $line\n";
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

  if (my $keyword = isNextClass()) {

	my $kindDecl;
	my $kindExpr;

	if ($keyword eq 'class') {
		$kindDecl = ClassDeclarationKind;
		$kindExpr = ClassExpressionKind;
	}
	elsif ($keyword eq 'extension'){
		$kindDecl = ExtensionDeclarationKind;
		$kindExpr = ExtensionExpressionKind;
	}
	elsif ($keyword eq 'struct') {
		$kindDecl = StructDeclarationKind;
		$kindExpr = StructExpressionKind;
	}
	else {
		print "[ParseSwift::parseClass] ERROR : unknown class structure type : $keyword!!\n";
	}

    if (getContext() == STATEMENT) {
      my $node = _parseClass($kindDecl);

      if ((defined nextStatement()) && (isNextSemiColon())) {
	  # trash semicolon
	  getNextStatement();
      }
      return $node;
    }
    else {
      return _parseClass($kindExpr);
    }

  }
  return undef;
}


sub isNextModifiers() {
	if ( ${nextStatement()} =~ /\A\s*$re_MODIFIERS\b/ ) {
		return 1;
	}
	return 0;
}

sub parseModifiers() {
	if (isNextModifiers()) {
		my $modifiers;
		my $modifier1 = getNextStatement();
		my $modifier2;

		if (isNextModifiers() == 1){
			$modifier2 = getNextStatement();
		}

		my %H_mod;
		if (defined $modifier2){
			$modifiers = $$modifier1 ." ". $$modifier2;
			$H_mod{$$modifier2} = 1;
			$H_mod{$$modifier1} = 1;
		}
		else{
			$modifiers = $$modifier1;
			$H_mod{$$modifier1} = 1;
		}

		my $artifactNode = Lib::ParseUtil::tryParse_OrUnknow(\@modifierContent);

		setSwiftKindData($artifactNode, 'modifiers', $modifiers);
        setSwiftKindData($artifactNode, 'H_modifiers', \%H_mod);

		return $artifactNode;

	}
	return undef;
}

##################################################################
#              ATTRIBUTE LABEL
##################################################################

sub isNextAttributeLabel() {
	if ( ${nextStatement()} =~ /\s*\@/ && ${nextStatement(1)} =~ /\b(\w+)\b/m) {
		return $1;
	}

	return 0;
}

sub parseAttributeLabel{
	if (isNextAttributeLabel()) {

		# consumes '@'
		getNextStatement();
		# get the name
		my $attributeName = ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		my $stmt;
		# parsing attribute arguments
		if (defined nextStatement() && ${nextStatement()} eq '('){
			$stmt .= ${parsePairing()}
		}

		my $attributeLabelNode = Node(AttributeLabelKind, createEmptyStringRef());
		SetName($attributeLabelNode, $attributeName);
		SetLine($attributeLabelNode, getStatementLine());
		SetStatement($attributeLabelNode, \$stmt);

		return $attributeLabelNode;

	}
	return undef;
}

##################################################################
#              Interface
##################################################################

sub parseProtocol() {

  if (${nextStatement()} eq 'protocol') {

      my $node = _parseClass(ProtocolKind);

      if ((defined nextStatement()) && (isNextSemiColon())) {
		# trash semicolon
		getNextStatement();
      }
      return $node;
  }
  return undef;
}

##################################################################
#              ENUM
##################################################################

sub parseEnum() {
	if (${nextStatement()} eq "enum") {
		# consumes 'enum' keyword
		getNextStatement();

		my $prototype = "";

		my $enumNode = Node(EnumKind, \$prototype);
		SetLine($enumNode, getStatementLine());

        # get name ...
        my $enumName;
        while (defined nextStatement() && ${nextStatement()} ne ":" && ${nextStatement()} ne "{"){
            $enumName .= ${getNextStatement()};
        }
        if ($enumName =~ /^\s*($IDENTIFIER)\s*/m) {
            SetName($enumNode, $1);
        }

		# check and parse type
		if (${nextStatement()} eq ":") {
			getNextStatement();
			my $type;
			my $stmt;
			while ((defined ($stmt = nextStatement())) && ($$stmt ne "{")) {
				$type .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
			}
		}

		if (${nextStatement()} eq "{") {
			# consumes the {
            getNextStatement();
		    my $stmt;
            while ((defined ($stmt = nextStatement())) && ($$stmt ne "}")) {

				my $artifactNode = Lib::ParseUtil::tryParse_OrUnknow(\@enumContent);

				Append($enumNode, $artifactNode);

            }
            if (defined ($stmt = nextStatement()) && ($$stmt eq "}")){
				# consumes the }
				getNextStatement();
            }

		}
		else {
			print "[ParseSwift::parseEnum] missing openning { after enum !\n";
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

sub splitSwift($) {
   my $r_view = shift;

   my  @statements = split /($STRUCTURAL_STATEMENTS|$CONTROL_FLOW_STATEMENTS|$SWIFT_SEPARATOR|$SIMPLE_KEYWORDS|(?:(?:$re_MODIFIERS\b)+))/smi, $$r_view;
   
   if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }
   return \@statements;
}


sub ParseSwift($) {
  my $r_view = shift;
  
  my $r_statements = splitSwift($r_view);

  resetContext();

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
  my @ClassDeclarationList = GetNodesByKind($node, ClassDeclarationKind );
  my @StructDeclarationList = GetNodesByKind($node, StructDeclarationKind );
  my @FunctionDeclarationList = GetNodesByKind($node, FunctionDeclarationKind );
  my @FunctionExpressionList = GetNodesByKind($node, FunctionExpressionKind);
  my @MethodList = GetNodesByKind($node, MethodKind);
  my @ClosureList = GetNodesByKind($node, ClosureKind);
  my @IfConditionList = GetNodesByKind($node, IfKind);
  my @TryExceptionList = GetNodesByKind($node, TryKind);
  my @BreakList = GetNodesByKind($node, BreakKind);
  my @TernaryOperatorList = GetNodesByKind($node, TernaryKind);
  my @SwitchConditionList = GetNodesByKind($node, SwitchKind);
  my @VariableDeclarationList = GetNodesByKind($node, VarDeclKind);
  my @EnumList = GetNodesByKind($node, EnumKind);
  my @ProtocolList = GetNodesByKind($node, ProtocolKind);
  my @ConstantList = GetNodesByKind($node, ConstKind);
  my @CatchList = GetNodesByKind($node, CatchKind);
  my @ForList = GetNodesByKind($node, ForKind);
  my @WhileList = GetNodesByKind($node, WhileKind);
  my @RepeatWhileList = GetNodesByKind($node, RepeatKind);
  my @ReturnList = GetNodesByKind($node, ReturnKind);
  my @ContinueList = GetNodesByKind($node, ContinueKind);
  my @FallthroughList = GetNodesByKind($node, FallthroughKind);

  my %H_KindsLists = ();
  $H_KindsLists{'ClassDeclaration'}=\@ClassDeclarationList;
  $H_KindsLists{'StructDeclaration'}=\@StructDeclarationList;
  $H_KindsLists{'FunctionDeclaration'}=\@FunctionDeclarationList;
  $H_KindsLists{'FunctionExpression'}=\@FunctionExpressionList;
  $H_KindsLists{'Method'}=\@MethodList;
  $H_KindsLists{'Closure'}=\@ClosureList;
  $H_KindsLists{'If'}=\@IfConditionList;
  $H_KindsLists{'Try'}=\@TryExceptionList;
  $H_KindsLists{'Break'}=\@BreakList;
  $H_KindsLists{'Ternary'}=\@TernaryOperatorList;
  $H_KindsLists{'Switch'}=\@SwitchConditionList;
  $H_KindsLists{'VarDecl'}=\@VariableDeclarationList;
  $H_KindsLists{'Enum'}=\@EnumList;
  $H_KindsLists{'Protocol'}=\@ProtocolList;
  $H_KindsLists{'Constant'}=\@ConstantList;
  $H_KindsLists{'Catch'}=\@CatchList;
  $H_KindsLists{'For'}=\@ForList;
  $H_KindsLists{'While'}=\@WhileList;
  $H_KindsLists{'RepeatWhile'}=\@RepeatWhileList;
  $H_KindsLists{'Return'}=\@ReturnList;
  $H_KindsLists{'Continue'}=\@ContinueList;
  $H_KindsLists{'Fallthrough'}=\@FallthroughList;
  $vue->{'KindsLists'} = \%H_KindsLists;
}


# description: Swift parse module Entry point.
sub Parse($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $status = 0;

    initMagicNumbers($vue);
    initMissingAcco($vue);
    initMissingSemicolon($vue);

    $StringsView = $vue->{'HString'};
	Lib::ParseUtil::registerParseUnknow(\&parseUnknow);

     # Minified files are known to remove as more spaces as possible.
     # So, after striping phase, en string encoding, the following code :
     #      case"toto":
     # will become :
     #      caseCHAINE_XXX:
     # The following treatment consist in adding missing space before analysis.
     $vue->{'code'} =~ s/\bcase(CHAINE_\d+)/case $1/sg;

     # launch first parsing pass : strutural parse.
     my ($SwiftNode, $Artifacts) = ParseSwift(\$vue->{'code'});


     if (defined $options->{'--print-tree'}) {
       Lib::Node::Dump($SwiftNode, *STDERR, "ARCHI");
     }
     if (defined $options->{'--print-test-tree'}) {
       print STDERR ${Lib::Node::dumpTree($SwiftNode, "ARCHI")} ;
     }
      
     if (defined $options->{'--print-statement'}) {
		 my @kinds = split(',', $options->{'--print-statement'});
		 for my $kind (@kinds) {
			 my @nodes = GetNodesByKind($SwiftNode, $kind);
			 for my $node (@nodes) {
				 my $stmt = GetStatement($node);
				 if (defined $stmt) {
					 print "STATEMENT $kind = $$stmt\n";
				 }
			 }
		 }
	 }
      
      $vue->{'structured_code'} = $SwiftNode;
      $vue->{'artifact'} = $Artifacts;

      # # pre-compute some list of kinds :
      preComputeListOfKinds($SwiftNode, $vue);

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


