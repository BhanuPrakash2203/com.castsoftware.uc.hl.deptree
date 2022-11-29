package Kotlin::ParseKotlin;

use strict;
use warnings;

use Lib::ParseUtil;
use Lib::Node;
use Lib::NodeUtil ;
use Lib::NodeUtil qw( SetName SetStatement SetLine GetLine SetEndline GetEndline );
use Kotlin::KotlinNode;

my @rootContent = ( 
			\&parseRoutine,
			\&parseRootModifier,
			\&parseGlobal,
			\&parseGetSet,
			\&parseClass,
			\&parseObject,
			\&parseRootAnnotation,
			\&parseRootGenericStatement,
			);

my @statementContent = ( 
			\&parseRoutine,
			\&parseStatementModifier,
			\&parseClass,
			\&parseObject,
			\&parseReturn,
			\&parseBreak,
			\&parseContinue,
			\&parseThrow,
			\&parseIf,
			\&parseTry,
			\&parseWhen,
			\&parseLoop,
			\&parseVariable,
			\&parseStatementAnnotation,
			\&parseLabel,
			);
			
my @expressionContent = (
			\&parseIf,
			\&parseTry,
			\&parseWhen,
			\&parseParenthesis,
			\&parseLambda,
			\&parseRoutine,
			#\&parseAnnotationExpression,
			\&parseBracket,
);

my @classContent = (
			\&parseClassModifier,
			\&parseAttribute,
			\&parseRoutine,
			\&parseGetSet,
			\&parseClassInit,
			\&parseConstructor,
			\&parseClass,
			\&parseClassAnnotation,
			\&parseObject,
);

my $StringsView = undef;

my $IDENTIFIER = '[\w]+';

my $KOTLIN_SEPARATOR = '(?:::|[;{}\n()=:,\[\]]|->|<|>)';

my $MODIFIER_VISIBILITY = qr/(?:private|protected|internal|public)\b/;
my $MODIFIER_STATEMENT = qr/(?:enum|sealed|annotation|data|inner|tailrec|operator|infix|inline|external|suspend|const)\b/;
my $MODIFIER_INHERITANCE = qr/(?:abstract|final|open)\b/;
my $MODIFIER_MEMBER = qr/(?:override|lateinit)\b/;
my $MODIFIER_PLATFORM = qr/(?:expect|actual)\b/;

# statement that return a value, so that belong to expression : corresponding keywords should be split.
my $EXPRESSION_STATEMENT = qr/\b(?:if|else|try)\b/;

# patterns that instroduce automatically a new statement (when encountered in an expression)
my $NEW_STATEMENT = qr/\b(?:(?:class|interface|while|for|var|val|const)\b|$MODIFIER_VISIBILITY|$MODIFIER_STATEMENT|$MODIFIER_INHERITANCE|$MODIFIER_MEMBER|$MODIFIER_PLATFORM)\s*(?:[^.\}\)\s]|$)/m;

# Begin a new statement, so is ending expression when encountered.
my $STATEMENT_BEGINNING = qr/\b(?:else|catch|finally)\b/;

my $NEVER_ENDING_STATEMENT_PATTERN = qr/(?:\.|::|&|\||\+|\-|\*|\/|\%|=|,|\bin|\bor|\bto|\?:)\s*$/m;
# character * can be an ending pattern for "import statement", but only for it !!!!
my $import_NEVER_ENDING_STATEMENT_PATTERN = qr/(?:\.|::|&|\||\+|\-|\/|\%|=|,|\bin|\bor|\bto|\?:)\s*$/m;

my $NEVER_BEGINNING_STATEMENT_PATTERN = qr/^\s*(?:\.|::|&|\||\+|\-|\*|\/|\%|=|,|\?)/m;

use constant VARIABLE_STATEMENT => 1;	# statement bloc scope
use constant VARIABLE_MEMBER => 2;    	# class scope
use constant VARIABLE_PARAM => 3;  
use constant VARIABLE_GLOBAL => 4; 		# package scope

use constant NO_INIT => 0;

sub isNextSemiColon() {
    if ( ${nextStatement()} eq ';' ) {
    return 1;
  }
  
  return 0;
}

sub isNextComa() {
    if ( ${nextStatement()} eq ',' ) {
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

sub isNextOpenningAcco() {
    if ( ${nextStatement()} eq '{' ) {
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

sub isNextArrow() {
    if ( ${nextStatement()} eq '->' ) {
    return 1;
  }
  
  return 0;
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
    Lib::Log::ERROR("context stack error !!");
  }
}

sub getContext() {
  if (scalar @Context > 0) {
    return $Context[-1];
  }
  else {
    Lib::Log::ERROR("current context access error !!");
    return STATEMENT;
  }
}

sub getContextEnclosiness() {
  if (scalar @Context > 0) {
    return $Context[-1];
  }
  else {
    Lib::Log::ERROR("current context access error !!");
    return STATEMENT;
  }
}

sub nextContext() {
  if (scalar @Context > 1) {
    return $Context[-2];
  }
  else {
    Lib::Log::ERROR("previous context access error !!");
    return STATEMENT;
  }
}

sub initContext() {
	@Context = (STATEMENT);
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
	
	#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	# FIXME : shoud be adapted to kotlin (actually it's the TypeScript version !!!!!!!!
	#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	
	while ( $$r_expr =~ /(?:^|[^\w])((?:\d|\.\d)(?:[e][+-]?|[\d\w\.])*)/sg ) {
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


########################## TOOLKIT ######################################

sub splitOnKeyword() {
	
	# ASSUME the pos on the next statement is placed after un keyword pattern.
	# AND check if it is followed by a pattern that reveal the keyword is a new instruction or belongs to an expression ...
	
	my $next = nextStatement();
	# check if the current pos on next statement is . ) or }
	if ( $$next =~ /\G\s*[\.\})]/gmc ) {
		return 0;
	}
	elsif ($$next =~ /\G\s*$/gmc ) {
		$next = nextStatement() while (!defined $next);
		# check if the next statement begins with . ) or }
		if ( $$next =~ /^\s*[\.\})]/m ) {
			return 0;
		}
	}
	Lib::ParseUtil::splitAndFocusNextStatementOnPos();
	return 1;
}

########################## UNKNOW ######################################

my $lastStatement = 0;

sub AppendKotlin($$) {
	my $parent =shift;
	my $child = shift;
	Append($parent, $child);
	if (IsKind($parent, RootKind) && IsKind($child, UnknowKind)) {
		my $stmt = ${GetStatement($child)};
		$stmt =~ s/\s+/ /g;
		Lib::Log::WARNING("appending UNKNOW node (".$stmt.") to ROOT (at line ".(GetLine($child)||"??").")!!!");
	}
}

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
		Lib::Log::ERROR("encountered unexpected statement : ".$$stmt." at line ".getStatementLine());

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

######################### PARENTHESE ###########################

sub parseParenthesis() {

	if (${nextStatement()} eq '(') {

		my $stmt;
		my $level = 1;
		my $openline = getNextStatementLine();
		
		# Consumes the opening token.
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

######################### EXPRESSION ###########################

# re define a more appropriate kind of a node according to the context
# represented by the statement expression into which the node is included ...
sub refineNode($$)  {
	my $node = shift;
	my $stmtContext = shift;

	# CHECK IF A '(' ... ')' IS A FUNCTION CALL
	# if a openning parenthesis follows a closing parenthesis, accolade or
	# identifier, then it is a function call.
	if ( IsKind($node, ParenthesisKind)) {
		if ($$stmtContext =~ /(?:[)}]|($IDENTIFIER)|<\s*[\w\.]+\s*>)\s*\z/sm ) {
#print "FUNCTION CALL after <<<$$stmtContext>>> !!!\n";
			SetKind($node, FunctionCallKind);
			my $fctName = $1 || 'CALL';
			my $name = GetName($node);
			$name =~ s/PARENT/${fctName}_/;
			SetName($node, $name);
		}
	}
}

sub expressionIsOnTheSameLine() {
	if (${Lib::ParseUtil::getSkippedBlanks()} =~ /\n/) {
		return 0;
	}
	return 1;
}

sub nextTokenIsEndingInstruction($;$) {
	my $r_previousToken = shift;
	my $nextIsNewStatement = shift;
	
	my $r_previousBlanks = Lib::ParseUtil::getSkippedBlanks();

	# a enclosing <> '' means the expression is enclosed => do not terminate.
	if (getEnclosing() ne '') {
		#if (defined $nextIsNewStatement) {
		#	Lib::Log::WARNING("unexpected statement beginning (".${nextStatement()}.") when parsing expression expression !");
		#}
		return 0 
	}

	if (defined nextStatement()) {

		# INSTRUCTIONS SEPARATOR
		# ----------------------
		# a ';' or '}' always ends a statement expression.
		my $next = nextStatement();
		if (($$next eq ';') || ($$next eq '}') || ($$next eq ')')) {
			return 1;
		}
		
		# NEVER_ENDING_STATEMENT_PATTERN
		#-------------------------------
		if ($$r_previousToken =~ /$NEVER_ENDING_STATEMENT_PATTERN/m) {
			return 0;
		}
		
		# NEW STATEMENT
		# ----------------------
		
		# check if we already know that next statement is a new instruction 
		return 1 if $nextIsNewStatement;
		
		# STATEMENT BEGINNING PATTERN
		if ($$next =~ /$STATEMENT_BEGINNING/) {
			return 1;
		}

		# NEVER STATEMENT BEGINNING PATTERN
		if ($$next =~ /$NEVER_BEGINNING_STATEMENT_PATTERN/) {
			return 0;
		}

		# DOT (de-referencement)
		# ----------------------
		#if ($$next =~ /^\s*\./m) {
		#	return 0;
		#}

		# NEW LINE
		# --------
		# if there was a new line before the token ...
		if ($$r_previousBlanks =~ /\n/s) {
			return 1;
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

		my $splitOnNewStatement = undef;

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

			my $skippedBlanks = ${Lib::ParseUtil::getSkippedBlanks()}; 

			my $subNode;
			#if ($$r_statement =~ /\.\s*\Z/) {
			#	# If the current statement is ending with a dot, then an object member
			#	# is expected. Languages keyword (ex: function, class) are valid field name, and should not be parsed as a language instruction.
			#	# So, use a context that do not parse language keyword.
			#	$subNode = Lib::ParseUtil::tryParse(\@DotRightValueExpressionContent);
			#}
			#else {
				# Next token belongs to the expression. Parse it.
				$subNode = Lib::ParseUtil::tryParse(\@expressionContent);
			#}

			if (defined $subNode) {
				# *** SYNTAX has been recognized by CALLBACK
				if (ref $subNode eq "ARRAY") {
					AppendKotlin($parent, $subNode);
					refineNode($subNode, $r_statement);
					$$r_statement .= $skippedBlanks . Kotlin::KotlinNode::nodeLink($subNode);
				}
				else {
					$$r_statement .= $$subNode;
				}
			}
			else {
				# *** SYNTAX UNRECOGNIZED with callbacks
				# 
				## WARNING : this parts should absolutely consume the next pattern, else we can run into an infinite loop !!!
				#
				
				# CHECK if it contains à keyword identifying a new instruction
				# indeed : those keywords are not used in global split, so they can be concatened with other patterns.
				# ex: "companion class toto". => class is not a split pattern, and "companion" not too. "companion" before "class" is not a valid syntax at first glance,
				#      but we should be as must robust as possible, because we don't master all subtilities of the kotlin language.
				#      So we have to split on 'class', so that is not be consumed yet !(only companion, that is an unrecognized syntax here, should be).
				
				# DESACTIVATED !!! $splitOnNewStatement = Lib::ParseUtil::splitNextStatementBeforePattern($NEW_STATEMENT);
				$splitOnNewStatement = undef;
				
				# ABOUT $splitOnNewStatement
				# undef : next pattern contains NO new statement
				# 0     : next pattern IS a new statement !! this should not happen (at first glance) !
				# > 0   : next pattern contains A new statement (and is then split on it)
				
				if (defined $splitOnNewStatement && $splitOnNewStatement==0) {
					Lib::Log::WARNING("new statement '".${nextStatement()}."' inside expression at line ".getNextStatementLine()."!!! ");
				}
				
				
				# now, get the next statement, as planed ...
				my $stmt = getNextStatement();
				$$r_statement .= $skippedBlanks . $$stmt;
			}
		}
#print "PRINT NEXT CONTEXT = ".nextContext()."\n";	
	# If not in a subexpression, check if next token is a new statement	
	# (we are in a subexpression if the next context after leaving the expression
	# is STATEMENT )
	#if ((nextContext() == STATEMENT) && (nextTokenIsEndingInstruction($r_statement))) {
		if ( nextTokenIsEndingInstruction($r_statement, (defined $splitOnNewStatement && $splitOnNewStatement >0 )) ) {
#print "--> CHECK END EXPRESSION\n";
			last;
		}
		
		# reset flag
		$splitOnNewStatement=undef; 
	}

	getMagicNumbers($r_statement, $isVarInit);

	SetStatement($parent, $r_statement);

#print "EXPRESSION : $$r_statement\n";

	leaveContext();
}

######################### GENERIC STATEMENT ####################

my %KIND = (
	'package' => PackageKind,
	'import' => ImportKind,
);

sub parseGenericStatement($) {
	my $REG = shift;
	
	if (${nextStatement()} =~ /^($REG)/mgc) {
		
		my $kind = $KIND{$1};
		
		my $_NEVER_ENDING_STATEMENT_PATTERN = $NEVER_ENDING_STATEMENT_PATTERN;
		$NEVER_ENDING_STATEMENT_PATTERN = $import_NEVER_ENDING_STATEMENT_PATTERN;
		
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		my $node = Node($kind, createEmptyStringRef());
		SetLine($node, getStatementLine());
		
		if (expressionIsOnTheSameLine()) {
			parseExpression($node);
		}
		
		expectSemiColon();
		
		$NEVER_ENDING_STATEMENT_PATTERN = $_NEVER_ENDING_STATEMENT_PATTERN;
		
		return $node;
	}
	return undef;
}

sub parseRootGenericStatement() {
	return parseGenericStatement(qr/\b(?:package|import)\b/);
}

######################### GENERIC INSTRUCTION ###############################

sub parseGenericInstruction($$) {
	my $kind = shift;
	my $reg =  shift;
	if (${nextStatement()} =~ /$reg/mgc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		my $node = Node($kind, createEmptyStringRef());
		SetLine($node, getStatementLine());
		
		if ((expressionIsOnTheSameLine()) &&
			(${nextStatement()} !~ /[};]/)) # prevent from "return;" or "return }"
		{
			parseExpression($node);
		}
		
		expectSemiColon();
		
		return $node;
	}
	return undef;
}

######################### RETURN ###############################

sub parseReturn() {
	return parseGenericInstruction(ReturnKind, qr/^\s*return\b/);
}

######################### BREAK ###############################

sub parseBreak() {
	return parseGenericInstruction(BreakKind, qr/^\s*break\b/);
}

######################### CONTINUE ###############################

sub parseContinue() {
	return parseGenericInstruction(ContinueKind, qr/^\s*continue\b/);
}

######################### THROW ###############################

sub parseThrow() {
	return parseGenericInstruction(ThrowKind, qr/^\s*throw\b/);
}

######################### INIT ###############################

sub parseInit() {
	my $initNode = Node(InitKind, createEmptyStringRef());
	SetLine($initNode, getStatementLine());
	parseExpression($initNode, [\&isNextComa]);
	return $initNode;
}

######################### Bracket ###############################

sub parseBracket() {
	if (${nextStatement()} eq '[') {
		return Lib::ParseUtil::parseRawOpenClose();
	}
	return undef;
}

######################### TYPE ###############################

sub parseGenericType() {
	if (${nextStatement()} eq '<') {
		return Lib::ParseUtil::parseRawOpenClose();
	}
	return undef;
}

sub parseFunctionType() {
	my $params = parseParameters();
	
	my $type = "";
	
	#------ particular case ---------
	if (${nextStatement()} eq '.') {
		# assuming we encounter the following syntax : (<receiver>).(<params>)-><type>
		# EXAMPLE :  fun toto(init: (@tata receiver).() -> unit) { return }
		$type .= ${getNextStatement()};
		if (${nextStatement()} eq '(') {
			$params = parseParameters();
		}
		else {
			Lib::Log::ERROR("unknow syntax while expecting function type with parenthesed receiver at line ".getStatementLine()." !!");
		}
	}
	
	#------ common treatment ---------
	$type = "(".(join ",", keys %$params).")->";
	
	if (${nextStatement()} =~ /^\s*->/mgc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		$type .= parseType();
	}
	else {
		Lib::Log::ERROR("missing -> after function type parameters $type!!");
	}
	
	return $type;
}

sub parseType() {
	my $next;
	my $type = "";
	my $line = getNextStatementLine();
	
	my $SPLIT_PATTERN = qr/\b(?:where|by)\b/;
	Lib::ParseUtil::splitNextStatementOnPattern($SPLIT_PATTERN);
	
	# parse annotations if any ...
	my ($anno, $value);
	while ( (($anno, $value) = _parseAnnotation()) && (defined $anno)) {};
	
	# parse "suspend" if any ...
	if (${nextStatement()} =~ /^\s*(suspend\b\s+)/gmc) {
		$type .= $1;
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
	}
	
	# loop until "->" or "where" or "by" or one of [,=\n\{\)]
	my $nb_iter = 0;
	while ((defined ($next=nextStatement())) && ($$next =~ /[^,=\n\{\)\}]/) && ($$next ne '->') && ($$next ne 'where') && ($$next ne 'by')) {
		if ($$next eq '(') {
			if (	($nb_iter == 0) ||      # function type begins with "("
					($type =~ /\.\s*$/m)	# or is like "T.() -> Unit" (T is a receiver)
				){

				$type = parseFunctionType();
			}
			else {
				# opening parenthese that do not correspond to a function type ... => end of type !
				last;
			}
		}
		elsif ($$next eq '<') {
			# generic syntax
			$type .= Lib::ParseUtil::parseRawOpenClose();
		}
		else {
			$type .= ${getNextStatement()};
		}
		Lib::ParseUtil::splitNextStatementOnPattern($SPLIT_PATTERN) if (defined nextStatement());
		$nb_iter++;
		if (${Lib::ParseUtil::getSkippedBlanks()} =~ /\n/) {
			# if a EOL is encountered ... => end of type
			last;
		}
	}
	
	return $type;
}

######################### ANNOTATION ########################

sub _parseAnnotation() {
	
	if (${nextStatement()} =~ /^\s*\@([\w\.]+)/gmc) {

		my $annotation = $1;
		my $value;
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		
		if (${nextStatement()} eq ':') {
			getNextStatement();
			if (${nextStatement()} eq '[') {
				$value = ":" . ${Lib::ParseUtil::parseRawOpenClose()};
			}
			elsif (${nextStatement()} =~ /^([\w+\.]+)/gmc) {
				Lib::ParseUtil::splitAndFocusNextStatementOnPos();
				$value = ":$1";
			}
		}

		if (${nextStatement()} eq '(') {
			$value = Lib::ParseUtil::parseRawOpenClose();
		}

		return ($annotation, $value);
	}
	return (undef, undef);
}

sub parseAnnotationExpression() {
	my ($annotation, $value) = _parseAnnotation();
	
	if (defined $annotation) {
print STDERR "ANNOTATION EXPRESSION : $annotation\n";
		my $ret = "$annotation".($value||"");
		return \$ret;
	}
	return undef;
}

sub parseAnnotedStatement($) {
	my $context = shift;
	
	my ($annotation, $value) = _parseAnnotation();
		
	if (defined $annotation) {
		
		## prevent from an empty statement ...
		#if (${nextStatement()} eq "}") {
		#	return undef;
		#}
		
		my $node = Lib::ParseUtil::tryParse($context);
		if (defined $node) {
			my $nodeAnnos = Lib::NodeUtil::GetXKindData($node, 'annotations') || {};
			$nodeAnnos->{$annotation} = $value;
			Lib::NodeUtil::SetXKindData($node, 'annotations', $nodeAnnos);
		}
		return $node;
	}
	return undef;
}

sub parseClassAnnotation() {
	return parseAnnotedStatement(\@classContent);
}

sub parseStatementAnnotation() {
	return parseAnnotedStatement(\@statementContent);
}

sub parseRootAnnotation() {
	return parseAnnotedStatement(\@rootContent);
}

######################### LABEL ########################

sub parseLabel() {
	if (${nextStatement()} =~ /^\s*\w+\@(?:(\s)|$)/gmc) {
		if (defined $1) {
			pos(${nextStatement()})-- ;
		}
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		return Lib::ParseUtil::tryParse_OrUnknow(\@statementContent);
	}
	return undef;
}

######################### MODIFIERS ########################

sub _parseModifier($$) {
	my $regexp = shift;
	my $context = shift;
	
	if (${nextStatement()} =~ /$regexp/gmc) {
		my $modifier = $1 || "???";
		
		if (splitOnKeyword()) {
		
			my $node;
		
			if (($modifier eq "enum") and (${nextStatement()} =~ /^\s*class\b/m)) {
				$node = parseClass(1); # 1 means it's an enum class !!!
			}
			else {
				$node = Lib::ParseUtil::tryParse($context);
			}
		
			if (! $node) {
				if (defined nextStatement()) {
					Lib::Log::WARNING("Unknow statement \"".${nextStatement()}."\" after modifier \"$modifier\" at line ".getStatementLine().". Assume \"$modifier\" is not used as modifier !!");
					# a statement has been consumed (in $modifier), so should return a node !!
					return Node(UnknowKind, \$modifier);
				}
				else {
					Lib::Log::WARNING("no statement after modifier at line ".getStatementLine());
				}
			}
			else {
				my $nodeModifiers = Lib::NodeUtil::GetXKindData($node, 'H_modifiers') || {};
				$nodeModifiers->{$modifier} = 1;
#print STDERR "MODIFIER : $modifier\n";
				Lib::NodeUtil::SetXKindData($node, 'H_modifiers', $nodeModifiers);
				return $node;
			}
		}
	}
	return undef;
}

sub parseClassModifier() {
	return _parseModifier(qr/^\s*($MODIFIER_VISIBILITY|$MODIFIER_INHERITANCE|$MODIFIER_MEMBER|$MODIFIER_STATEMENT|$MODIFIER_PLATFORM)/, \@classContent);
}

sub parseStatementModifier() {
	return _parseModifier(qr/^\s*($MODIFIER_MEMBER|$MODIFIER_STATEMENT|$MODIFIER_PLATFORM)/, \@statementContent);
}

sub parseRootModifier() {
	return _parseModifier(qr/^\s*($MODIFIER_VISIBILITY|$MODIFIER_INHERITANCE|$MODIFIER_MEMBER|$MODIFIER_STATEMENT|$MODIFIER_PLATFORM)/, \@rootContent);
}

######################### VARIABLES ##########################

sub _parseVariable($) {
	my $varKind = shift;
	
	if ( ${nextStatement()} =~ /^\s*(var|val)\b/gmc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		
		my $kind = {'val' => &ValKind, 'var' => &VarKind}->{$1};
	
		my $variableNode;
		my $init;
		my $line = getStatementLine();
		
		# parse destructuring ...
		if (${nextStatement()} eq '(') {
			
			# trash '('
			getNextStatement();
			
			$variableNode =  Node(DestructuringKind, createEmptyStringRef());
			SetLine($variableNode, $line);
			
			while (${nextStatement()} ne ')') {
				
				#my ($name, $params) = parseOneParameter($varKind);
				my $name = ${getNextStatement()};
				if ( $name !~ /^\s*[\w\.]+\s*$/) {
					Lib::Log::ERROR("bad variable name ($name) in destructuring assignment at line ".getStatementLine().".");
				}
				
				$name =~ s/^\s*//m;
#print STDERR "DESTRUCTURING VAR = $name\n";

				$line = getStatementLine();
				my $varNode = Node($kind, createEmptyStringRef());
				SetLine($varNode, $line);
				SetName($varNode, $name);
				Append($variableNode, $varNode);

				if (${nextStatement()} eq ':') {
					my $type = parseType();
#print STDERR "DESTRUCTURING TYPE = $type\n";
				}

				if (${nextStatement()} eq ',') {
					getNextStatement();
				}
			}
			
			# trash ')'
			getNextStatement();
			
			# parse init
			if (${nextStatement()} eq "=") {
				getNextStatement();
				$init = parseInit();
			}
		}
		else {
			
			$variableNode =  Node($kind, createEmptyStringRef());
			SetLine($variableNode, $line);
			
			my ($name, $params) = parseOneParameter($varKind);
			
			if ((defined nextStatement()) && (${nextStatement()} eq 'by')) {
				parseExpression($variableNode);
			}
			
			$init = $params->{$name}->{'init'};
			Lib::NodeUtil::SetXKindData($variableNode, 'type', $params->{$name}->{'type'});
			SetName($variableNode, $name);
		}
		
		# Append init if any ...
		if ((defined $init) && (ref $init eq "ARRAY")) {
			AppendKotlin($variableNode, $init);
		}
		
		expectSemiColon();
		
		return $variableNode;
	}
	return undef;
}

sub parseAttribute() {
	return _parseVariable(VARIABLE_MEMBER);
}

sub parseVariable() {
	return _parseVariable(VARIABLE_STATEMENT);
}

sub parseGlobal() {
	return _parseVariable(VARIABLE_GLOBAL);
}

######################### ROUTINES ###########################
# minimal proto is : 
# 	fun <name> (<params>)
#
# full proto is
# 	[[ <modifier> ]] fun [[ <T> ]] <name>() [[ :type ]]
#
# params :
#  	( <type> : <name> = <init expr> , ... )

sub parseAttributeName() {
	# parse the name
	# - parenthesed args end with ':' ',' ')'
	# - lambda      args end with ':' ',' '->'
	my $next;
	my $name;
	my $indent;
	
	my $SPLIT_PATTERN = qr/\b(?:get|set|by)\b/;
	Lib::ParseUtil::splitNextStatementOnPattern($SPLIT_PATTERN);
	
	# allow "get" and "set" as variable name.
	$name .= ${getNextStatement()} while (${nextStatement()} !~ /\S/);
	$next = nextStatement();
	$name .= ${getNextStatement()} if ( $$next eq 'get' || $$next eq 'set');
	
	while ( ($next = nextStatement()) && ($$next ne ':') && ($$next ne '=') && ($$next ne ')') && ($$next ne '->') && ($$next ne 'get') && ($$next ne 'set') && ($$next ne 'by')){
		# end of attribute declaration if next statement is on another line ...
		last if ((defined $name) && (${Lib::ParseUtil::getSkippedBlanks()} =~ /\n/));
		
		$name .= ${getNextStatement()};
		Lib::ParseUtil::splitNextStatementOnPattern($SPLIT_PATTERN);
	}
	($indent, $name) = $name =~ /^(\s*)([^\s]+)/;

	return ($indent, $name);
}

sub parseVariableName() {
	# parse the name
	# - parenthesed args end with ':' ',' ')'
	# - lambda      args end with ':' ',' '->'
	my $next;
	my $name;
	my $indent;
	
	my $SPLIT_PATTERN = qr/\b(?:get|set|by)\b/;
	Lib::ParseUtil::splitNextStatementOnPattern($SPLIT_PATTERN);
	
	while ( ($next = nextStatement()) && ($$next ne ':') && ($$next ne ',') && ($$next ne '=') && ($$next ne ')') && ($$next ne '->') && ($$next ne 'by')){
		# end of variable declaration if next statement is on another line ...
		last if ((defined $name) && (${Lib::ParseUtil::getSkippedBlanks()} =~ /\n/));
		
		$name .= ${getNextStatement()};
		Lib::ParseUtil::splitNextStatementOnPattern($SPLIT_PATTERN);
	}
	
	if (defined $name) {
		($indent, $name) = $name =~ /^(\s*)([^\s]+)/;
	}
	else {
		Lib::Log::ERROR("unknow name for variable at line ".getStatementLine());
	}
	
	return ($indent, $name);
}

sub parseOneParameter($;$$) {
	my $varKind = shift;
	my $params = shift || {};
	my $initAllowed = shift;
	$initAllowed //= 1;
	
	my $type = "";
	my $name = "";
	my $indent = "";
	my $init = undef;

	# parse annotations if any ...
	my ($annotation, $value) = _parseAnnotation();
	
	if ($varKind eq VARIABLE_STATEMENT) {
		($indent, $name) = parseVariableName();
	}
	elsif ($varKind eq VARIABLE_MEMBER) {
		($indent, $name) = parseAttributeName();
	}
	elsif ($varKind eq VARIABLE_PARAM) {
		# remove parameters modifiers
		while (${nextStatement()} =~ /^\s*(?:noinline|crossinline|vararg)\b/mgc) {
			Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		}
		
		($indent, $name) = parseVariableName();
	}
	elsif ($varKind eq VARIABLE_GLOBAL) {
		# use function for variable statement ...
		($indent, $name) = parseVariableName();
	}
	else {
		Lib::Log::ERROR("unknow kind of variable");
	}
	
	# parse type
	if ((defined nextStatement()) && (${nextStatement()} eq ":")) {
		getNextStatement();
		$type = parseType();
	}
	
	# parse init
	if ($initAllowed && (defined nextStatement()) && (${nextStatement()} eq "=") ) {
		getNextStatement();
		$init = parseInit();
		$params->{$name} = $init;
	}
	
	#my $byNode;
	#if ((defined nextStatement()) && (${nextStatement()} eq 'by')) {
		# create a fake node for the type:
	#	my $byNode = Node(UnknowKind, \$type);
		#parseExpression($node, [\&isNextOpenningAcco, \&isNextComa]);
	#	parseExpression($byNode);
	#}
	
	if (! defined $name) {
		print "UNDEFINED name, NEXT is ".${nextStatement()}." at line ".getNextStatementLine()."\n";
	}
	
	$params->{$name} = {'type' => $type, 'indent' => $indent, 'init' => $init};
	if (defined $annotation) {
		$params->{$name}->{'annotation'} = [$annotation, $value];
	}
	
	return ($name, $params);
}

sub parseParameters() {
	my %params = ();
	
	if ((defined nextStatement()) && (${nextStatement()} eq "(")) {
		# get '('
		getNextStatement();
		my $line = getStatementLine();
	
		while ((defined nextStatement()) && (${nextStatement()} ne ')')) {
		
			my ($name) = parseOneParameter(VARIABLE_PARAM, \%params);

			last if (!defined $name);

			getNextStatement() if (${nextStatement()} eq ",");

my $init = $params{$name}->{'init'};
#print STDERR "PARAM $name\n";
#print STDERR "\tTYPE:$params{$name}->{'type'}\n" if defined $params{$name}->{'type'};
#print STDERR "\tINIT:".${GetStatement($init)}."\n" if ((defined $init) && (ref $init ne "ARRAY"));
		}
	
		if (! defined nextStatement()) {
			Lib::Log::ERROR("missing closing ) for parameter list at line $line");
		}
		else {
			# get ')'
			getNextStatement();
		}
	}
	return \%params;
}

sub _parseRoutine($$$) {
	my $kind = shift;
	my $name = shift;
	my $protoPos = shift;
	
	my $generic;
	my $type;
	my $params;
	my $line;

	enterEnclosing('');
	
	my $funNode = Node($kind, createEmptyStringRef());
	$line = getStatementLine();
	SetLine($funNode, $line);
		
	SetName($funNode, $name);

	return $funNode if (${nextStatement()} ne '(');
	
	# check if the parentheses are parameters or not (it could be parenthesed receiver).
	my $idx = Lib::ParseUtil::getIndexAfterPeer();
	$idx = Lib::ParseUtil::getIndexAfterBlank($idx);
	if (defined $idx && ${nextStatement($idx)} =~ /^\s*\./m) {
		# get the parenthesed expression
		my $stmt = nextStatement($idx);
		while ($stmt != nextStatement()) { $type .= ${getNextStatement()}; }
		# get until the next openning parenthese.
		while ((defined ($stmt = nextStatement())) && ($$stmt ne '(')) {
			$type .= ${getNextStatement()};
		}
	}
	
	return $funNode if (${nextStatement()} ne '(');
	
	$params = parseParameters();
	
	Lib::NodeUtil::SetXKindData($funNode, "parameters", $params);

	return $funNode if (! defined nextStatement());
		
	if (${nextStatement()} eq ":") {
		getNextStatement();
		$type = parseType();
#print STDERR "FUNCTION TYPE = $type\n";
	}
		
	# parse generic constraints
	if ((defined nextStatement()) && (${nextStatement()} =~ /\s*where\b/gmc)) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		my $params = {};
		
		parseOneParameter(VARIABLE_PARAM, $params, NO_INIT);
		#while (${nextStatement()} !~ /[={]/) {
		while (${nextStatement()} eq ',') {
			getNextStatement();
			parseOneParameter(VARIABLE_PARAM, $params, NO_INIT);
			#getNextStatement() if (${nextStatement()} eq ',');
		}
	}
	
	my $implementation = "none";
	
	my $next = nextStatement();
	if (defined $next) {
		my $beginPos = Lib::ParseUtil::getCodePos();
		my $endPos;
		
		if ($$next eq "=") {
			
			$implementation = "expression";
			getNextStatement();
			Lib::NodeUtil::SetXKindData($funNode, "first_instruction_line", getNextStatementLine());
			my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@statementContent);
			AppendKotlin($funNode, $subNode);
			$endPos = Lib::ParseUtil::getCodePos();
			Lib::NodeUtil::SetXKindData($funNode, "last_instruction_line", getStatementLine());
		}
		elsif ($$next eq '{') {
			
			$implementation = "body";
			getNextStatement();
			Lib::NodeUtil::SetXKindData($funNode, "first_instruction_line", getNextStatementLine());
			while ((nextStatement()) && (${nextStatement()} ne '}')) {
				my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@statementContent);
				AppendKotlin($funNode, $subNode)
			}
		
			Lib::NodeUtil::SetXKindData($funNode, "last_instruction_line", getStatementLine());
		
			if (! defined nextStatement()) {
				Lib::Log::ERROR("unterminated routine \"$name\" at line $line");
			}
			elsif (${nextStatement()} eq '}') {
				getNextStatement();
			}
			$endPos = Lib::ParseUtil::getCodePos();
		}
		
		Lib::NodeUtil::SetXKindData($funNode, "implementation", $implementation);
		
		if ( ! defined $endPos) {
			$endPos = $beginPos;
		}
			
		Lib::NodeUtil::SetXKindData($funNode, "position", {"protoPos" => $protoPos, "begin" => $beginPos, "end" => $endPos, "length" => $endPos-$beginPos});
	}

	SetEndline($funNode, getStatementLine());

	leaveEnclosing('');
		
	return $funNode;
}

sub parseGetSet() {
	if (${nextStatement()} =~ /^\s*([gs]et)\b/gmc) {
		my $name = $1;
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		my $kind;
		
		my $protoPos = Lib::ParseUtil::getCodePos();
		
		if ($name eq "get") {
			$kind = GetterKind;
		}
		else {
			$kind = SetterKind;
		}
		if ((defined nextStatement()) && (${nextStatement()} eq '(')) {
			return _parseRoutine($kind, $name, $protoPos);
		}
		else {
			my $node = Node($kind, createEmptyStringRef());
			SetName($node, $name);
			SetLine($node, getStatementLine());
			return $node;
		}
	}
	return undef;
}

sub parseRoutine() {
	my $name;
	my $generic;
	
	if (${nextStatement()} eq "fun") {
		getNextStatement();
	
		my $protoPos = Lib::ParseUtil::getCodePos();
	
		if (${nextStatement()} eq "<") {
			# FIXME : parseGeneric();
		}
		
		my $stmt = "";
		
		# run until next item is '(' or is on the next line ...
		while ((${nextStatement()} ne '(') && (expressionIsOnTheSameLine())) {
			$stmt .= ${getNextStatement()};
		}
		($generic, $name) = $stmt =~ /^(.*?)(\w+)\s*$/m;
		
		if (! defined $name) {
			return _parseRoutine(FunctionExpressionKind, $name, $protoPos);
		}
		else {
			return _parseRoutine(FunctionKind, $name, $protoPos);
		}
	}
	return undef;
}

######################### LAMBDA ###########################

sub parseLambdaParameters() {
	my %params = ();
	
	my $line = getStatementLine();
	my $next;
	while ((defined ($next=nextStatement())) && ($$next ne '->')) {
		
		if ($$next eq '(') {
			# destructuring syntax ...
			getNextStatement();
			while ((defined ($next=nextStatement())) && ($$next ne ')')) {
				my ($name) = parseOneParameter(VARIABLE_PARAM, \%params);
				getNextStatement() if (${nextStatement()} eq ",");
			}
			if (! defined nextStatement()) {
				Lib::Log::ERROR("missing closing ) after destructuring parameter list at line $line");
			}
			elsif (${nextStatement()} eq ')') {
				getNextStatement()
			}
			else {
				Lib::Log::ERROR("missing closing ) after destructuring parameter list at line $line");
			}
		}
		else { 
			# normal syntax
			my ($name) = parseOneParameter(VARIABLE_PARAM, \%params);
		}
		
		if (defined nextStatement) {
			getNextStatement() if ((defined nextStatement) && (${nextStatement()} eq ","));
		
			# protection against infinite loop !!!
			if ($next == nextStatement()) {
				Lib::Log::ERROR("aborting because pattern \"".${nextStatement()}."\" is blocking at line ".getNextStatementLine()."!!!");
				getNextStatement(); # trash the pattern !!!
				last;
			}
		}
	}
	
	if (! defined nextStatement()) {
		Lib::Log::ERROR("missing -> after lambda parameters list at line $line");
	}
	elsif (${nextStatement()} eq '->') {
		# get '->'
		getNextStatement();
	}
	else {
		Lib::Log::ERROR("missing -> after lambda parameters at line $line");
	}
	return \%params;
}

sub _parseLambda() {
	# parse parameters if any ...
	if (${nextStatement()} =~ /^\s*(\w*)\s*$/m) {
		
		# WARNING: "object : \w+" does not mean it's a parameter !! 
		if ($1 ne 'object') {
			my $idx = 1;

			my $next = nextStatement($idx++);;
			while ($$next !~ /\S/) {
				$next = nextStatement($idx++);
			}
			if (($$next eq ":") || ($$next eq ",") || ($$next =~ /^\s*->/m)) {
				my $params = parseLambdaParameters();
			}
		}
	}

	enterEnclosing('');

	# parse Body
	my $lambdaNode = Node(LambdaKind, createEmptyStringRef());
	SetLine($lambdaNode, getStatementLine());
	Lib::ParseUtil::parseStatementsBloc($lambdaNode, [\&isNextClosingAcco], \@statementContent, 0, 0); # consumes closing, use unknow nodes
	
	leaveEnclosing('');
	
	return $lambdaNode;
}

sub parseLambda() {
	if (${nextStatement()} eq '{') {
		# get '{'
		getNextStatement();
		return _parseLambda();
	}
	return undef;
}

######################### CONDITION ###########################

sub parseCondition() {
	my $condNode = Node(ConditionKind, createEmptyStringRef());
	SetLine($condNode, getNextStatementLine());
	SetStatement($condNode, Lib::ParseUtil::parseRawOpenClose());
	
	return $condNode;
}

######################### FOR ###########################

sub _parseLoop($) {
	my $kind =shift;
	my $loopNode = Node($kind, createEmptyStringRef());
	my $line = getStatementLine();
	SetLine($loopNode, $line);
		
	if (${nextStatement()} eq '(') {
		my $condNode = parseCondition();
		AppendKotlin($loopNode, $condNode);
	}
	
	if (${nextStatement()} eq '{') {
		# get '{'
		getNextStatement();
		Lib::ParseUtil::parseStatementsBloc($loopNode, [\&isNextClosingAcco], \@statementContent, 0, 0); # consumes closing, use unknow nodes
	}
	else {
		AppendKotlin($loopNode, Lib::ParseUtil::tryParse_OrUnknow(\@statementContent))
	}
	
	return $loopNode;
}

sub parseLoop() {
	if (${nextStatement()} =~ /^\s*(for|while)\b/gmc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		my $kind = {'for' => &ForKind, 'while' => &WhileKind }->{$1};
		return _parseLoop($kind);
	}
	return undef;	
}

######################### WHEN ###########################

sub parseWhenEntry() {
	my $kind = CaseKind;
	if (${nextStatement()} =~ /^\s*else\b/) {
		$kind = DefaultKind;
	}
	my $entryNode = Node($kind, createEmptyStringRef());
	my $line = getNextStatementLine();
	SetLine($entryNode, $line);
	
	my $cond = "";
	my $fakeNode = Node(UnknowKind, createEmptyStringRef());
	parseExpression($fakeNode, [\&isNextArrow]);
	
	#while ((defined nextStatement()) && (${nextStatement()} ne '->')) {
	#	$cond .= ${getNextStatement()};
	#}
	
	enterEnclosing('');
	
	if ((defined nextStatement()) && (${nextStatement()} eq '->')) {
		getNextStatement();
		
		if (${nextStatement()} eq "{") {
			getNextStatement();
			Lib::NodeUtil::SetXKindData($entryNode, "first_instruction_line", getNextStatementLine());
			Lib::ParseUtil::parseStatementsBloc($entryNode, [\&isNextClosingAcco], \@statementContent, 1, 0); # do not consume closing, use unknow nodes();
			Lib::NodeUtil::SetXKindData($entryNode, "last_instruction_line", getStatementLine());
			if ((defined nextStatement()) && (${nextStatement()} eq '}')) {
				getNextStatement();
			}
		}
		else {
			Lib::NodeUtil::SetXKindData($entryNode, "first_instruction_line", getNextStatementLine());
			Append($entryNode, Lib::ParseUtil::tryParse_OrUnknow(\@statementContent));
			Lib::NodeUtil::SetXKindData($entryNode, "last_instruction_line", getStatementLine());
		}
	}
	else {
		Lib::Log::ERROR("missing opening '->' for 'when entry' at line $line");
	} 
	
	leaveEnclosing('');
	
	return $entryNode;
}

sub parseWhen() {
	if (${nextStatement()} =~ /^\s*when\b/gmc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		
		my $whenNode = Node(WhenKind, createEmptyStringRef());
		my $line = getStatementLine();
		SetLine($whenNode, $line);
		
		my $subject = "";
		if ( ${nextStatement()} eq '(') {
			$subject = Lib::ParseUtil::parseRawOpenClose();
		}
		
		if (${nextStatement()} eq '{') {
			getNextStatement();
			while ((defined nextStatement()) && (${nextStatement()} ne '}')) {
				my $entryNode = parseWhenEntry();
				Append($whenNode, $entryNode);
			}
			
			if ((defined nextStatement()) && (${nextStatement()} eq '}')) {
				getNextStatement();
			}
			else {
				Lib::Log::ERROR("missing closing '}' for 'when' at line $line");
			}
		}
		else {
			Lib::Log::ERROR("missing opening '{' for 'when' at line $line");
		}
		
		return $whenNode;
	}
	return undef;
}

######################### IF ###########################

sub _parseIf() {
	my $ifNode = Node(IfKind, createEmptyStringRef());
	my $line = getStatementLine();
	SetLine($ifNode, $line);
		
	if (${nextStatement()} eq '(') {
		my $condNode = parseCondition();
		AppendKotlin($ifNode, $condNode);
	}
	
	enterEnclosing('');
	
	# THEN
	my $thenNode = Node(ThenKind, createEmptyStringRef());
	AppendKotlin($ifNode, $thenNode);
	if (${nextStatement()} eq '{') {
		getNextStatement();
		while ((defined nextStatement()) && ${nextStatement()} ne '}') {
			AppendKotlin($thenNode, Lib::ParseUtil::tryParse_OrUnknow(\@statementContent));
		}
		if (defined nextStatement()) {
			# it it necessarily a '}'. Trash it ...
			getNextStatement();
		}
		else {
			Lib::Log::ERROR("missing closing '}' for if 'then' at line $line");
		}
	}
	else {
		AppendKotlin($thenNode, Lib::ParseUtil::tryParse_OrUnknow(\@statementContent));
	}
	
	# ELSE
	if (defined nextStatement()) {
		if (	(${Lib::ParseUtil::nextNonBlank()} ne '->') &&   # do not confuse whith "else ->" of a "when" default clause !!
				(${nextStatement()} =~ /^\s*else\b/gmc)) {
			Lib::ParseUtil::splitAndFocusNextStatementOnPos();
			
			$line = getStatementLine();
			
			my $elseNode;
			if (defined nextStatement()) {
				$elseNode = parseIf();
				if (defined $elseNode) {
					# elsif
					SetKind($elseNode, ElsifKind);
					AppendKotlin($ifNode, $elseNode);
				}
				else {
					# else
					$elseNode = Node(ElseKind, createEmptyStringRef());
					SetLine($elseNode, $line);
								
					AppendKotlin($ifNode, $elseNode);
					if (${nextStatement()} eq '{') {
						getNextStatement();

						while (${nextStatement()} ne '}') {
							AppendKotlin($elseNode, Lib::ParseUtil::tryParse_OrUnknow(\@statementContent));
						}
						if (${nextStatement()} eq '}') {
							getNextStatement();
						}
						else {
							Lib::Log::ERROR("missing closing '}' for if 'else' at line $line");
						}
					}
					else {
						AppendKotlin($elseNode, Lib::ParseUtil::tryParse_OrUnknow(\@statementContent));
					}
				}
			}
		}
	}

	leaveEnclosing('');

	return $ifNode;
}

sub parseIf() {
	
	if (${nextStatement()} =~ /^\s*if\b/gmc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		return _parseIf();
	}
	return undef;	
}

######################### TRY ###########################

sub _parseTry() {
	my $tryNode = Node(TryKind, createEmptyStringRef());
	my $line = getStatementLine();
	SetLine($tryNode, $line);
	
	enterEnclosing('');
	
	# TRY
	my $thenNode = Node(ThenKind, createEmptyStringRef());
	Append($tryNode, $thenNode);
	if (${nextStatement()} eq '{') {
		getNextStatement();
		while ((defined nextStatement()) && ${nextStatement()} ne '}') {
			AppendKotlin($thenNode, Lib::ParseUtil::tryParse_OrUnknow(\@statementContent));
		}
		if (defined nextStatement()) {
			# it it necessarily a '}'. Trash it ...
			getNextStatement();
		}
		else {
			Lib::Log::ERROR("missing closing '}' for 'try' at line $line");
		}
	}
	else {
		AppendKotlin($thenNode, Lib::ParseUtil::tryParse_OrUnknow(\@statementContent));
	}
	
	# CATCH
	while ((defined nextStatement()) && (${nextStatement()} =~ /^\s*catch\b/gmc)) {
		
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		
		$line = getStatementLine();
			
		my $catchNode = Node(CatchKind, createEmptyStringRef());
		SetLine($catchNode, $line);
		
		if (${nextStatement()} eq '(') {
			my $condNode = parseCondition();
			SetStatement($catchNode, GetStatement($condNode));
		}
			
		if (defined nextStatement()) {
								
			AppendKotlin($tryNode, $catchNode);
			if (${nextStatement()} eq '{') {
				getNextStatement();

				while (${nextStatement()} ne '}') {
					AppendKotlin($catchNode, Lib::ParseUtil::tryParse_OrUnknow(\@statementContent));
				}
				if (${nextStatement()} eq '}') {
					getNextStatement();
				}
				else {
					Lib::Log::ERROR("missing closing '}' for 'catch' at line $line");
				}
			}
			else {
				AppendKotlin($catchNode, Lib::ParseUtil::tryParse_OrUnknow(\@statementContent));
			}	
		}
	}
	
	# FINALLY
	if (defined nextStatement()) {
		if (${nextStatement()} =~ /^\s*finally\b/gmc) {
			Lib::ParseUtil::splitAndFocusNextStatementOnPos();
			
			$line = getStatementLine();
			
			my $finallyNode;
			if (defined nextStatement()) {
				$finallyNode = Node(FinallyKind, createEmptyStringRef());
				SetLine($finallyNode, $line);
								
				AppendKotlin($tryNode, $finallyNode);
				if (${nextStatement()} eq '{') {
					getNextStatement();

					while (${nextStatement()} ne '}') {
						AppendKotlin($finallyNode, Lib::ParseUtil::tryParse_OrUnknow(\@statementContent));
					}
					if (${nextStatement()} eq '}') {
						getNextStatement();
					}
					else {
						Lib::Log::ERROR("missing closing '}' for 'finally' at line $line");
					}
				}
				else {
					AppendKotlin($finallyNode, Lib::ParseUtil::tryParse_OrUnknow(\@statementContent));
				}	
			}
		}
	}

	leaveEnclosing('');

	return $tryNode;
}

sub parseTry() {
	
	if (${nextStatement()} =~ /^\s*try\b/gmc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		return _parseTry();
	}
	return undef;	
}


########################## CLASS ################################

sub parseDelegation() {
	# parse type
	my $type;
	my $delegateToParse = 1;
	while ($delegateToParse) {
		$type = parseType();
	
		if (defined nextStatement()) {
			if (${nextStatement()} eq '(') {
				my $params = Lib::ParseUtil::parseRawOpenClose();
				$type .= $$params;
			}
			elsif (${nextStatement()} eq 'by') {
				# create a fake node for the type:
				my $node = Node(UnknowKind, \$type);
				parseExpression($node, [\&isNextOpenningAcco, \&isNextComa]);
			}
			if ((defined nextStatement()) && (${nextStatement()} eq ',')) {
				getNextStatement();
			}
			else {
				$delegateToParse = 0;
			}
		}
		else {
			$delegateToParse = 0;
		}
	}
#print "DELEGATION = $type\n";
	# don't know at this time what to do with the fake node !!
}

sub parseClassInit() {
	if ( ${nextStatement()} =~ /^\s*init\b/gmc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		my $classInitNode = Node(ClassInitNodeKind, createEmptyStringRef());
		SetLine($classInitNode, getStatementLine());
		if (${nextStatement()} eq "{") {
			getNextStatement();
			Lib::ParseUtil::parseStatementsBloc($classInitNode, [\&isNextClosingAcco], \@statementContent, 0, 0); # consumes closing, use unknow nodes();
		}
		else {
			Lib::Log::ERROR("missing bloc for class init at line ".GetLine($classInitNode));
		}
		return $classInitNode;
	}
	return undef;
}

sub parseConstructor() {
	if ( ${nextStatement()} =~ /^\s*constructor\b/gmc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		my $constructorNode = Node(ConstructorKind, createEmptyStringRef());
		SetLine($constructorNode, getStatementLine());
		
		# PARAMETERS
		my $params = parseParameters();
		Lib::NodeUtil::SetXKindData($constructorNode, 'params', $params);
		
		# parse "this" and "super"
		if (${nextStatement()} eq ":") {
			getNextStatement();
			if (${nextStatement()} =~ /^\s*(this|super)\b/gmc) {
				Lib::ParseUtil::splitAndFocusNextStatementOnPos();
				if (${nextStatement()} eq "(") {
					Lib::ParseUtil::parseRawOpenClose();
				}
				else {
					my $delegationCallStmt = Lib::Log::ERROR("missing missing value for constructor delegatin call ($1) at line ".getStatementLine());
					Lib::NodeUtil::SetXKindData($constructorNode, 'delegation_call', $delegationCallStmt);
				}
			}
		}
		
		# BODY
		if (${nextStatement()} eq "{") {
			getNextStatement();
			Lib::ParseUtil::parseStatementsBloc($constructorNode, [\&isNextClosingAcco], \@statementContent, 0, 0); # consumes closing, use unknow nodes();
		}
		#else {
		#	Lib::Log::WARNING("missing bloc for constructor init at line ".GetLine($constructorNode));
		#}
		return $constructorNode;
	}
	return undef;
}


sub parseClassBody($;$) {
	my $classNode = shift;
	my $enum = shift;

	if (${nextStatement()} eq '{') {
		
		my $beginPos = Lib::ParseUtil::getCodePos();
			
		getNextStatement();
		
		if ($enum) {
			my $enum = "";
			my $next;
			my $line = getNextStatementLine();
			while (($next=nextStatement()) && ($$next ne ";") and ($$next ne '}')) {
				$enum .= ${getNextStatement()};
			}
			
			if ($enum =~ /\S/) {
				my $enumNode = Node(EnumKind, \$enum);
				SetLine($enumNode, $line);
				AppendKotlin($classNode, $enumNode);
			}
			
			Lib::ParseUtil::purgeSemicolon();
		}
		
		while ((defined nextStatement()) && (${nextStatement()} ne "}")) {
			my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@classContent);
			if (defined $subNode) {
				AppendKotlin($classNode, $subNode);
			}
		}
		if (defined nextStatement()) {
			# trash the '}' ...
			getNextStatement();
		}
		else {
			Lib::Log::ERROR("missing '}' for class/object declared at line ".(GetLine($classNode)||"??"));
		}
		my $endPos = Lib::ParseUtil::getCodePos();
		
		Lib::NodeUtil::SetXKindData($classNode, "position", {"begin" => $beginPos, "end" => $endPos, "length" => $endPos-$beginPos});
	}
}

sub parseClass(;$) {
	my $enum = shift;
	
	if (${nextStatement()} =~ /^\s*(class|interface)\b/gmc) {
		my $kind = ClassKind;
		if ($1 eq "interface") {
			$kind = InterfaceKind;
		}
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
	
		my $classNode = Node($kind, createEmptyStringRef());
		my $line = getStatementLine();
		SetLine($classNode, $line);

		# NAME
		my $name;
		if (${nextStatement()} =~ /^\s*(\w+)/gmc) {
			$name =$1;
			Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		}
		else {
			Lib::Log::ERROR("missing name for class/interface at line $line");
		}
		SetName($classNode, $name);
		
		return $classNode if (! defined nextStatement());
		
		# parse GENERIC if any ...
		parseGenericType();
		
		return $classNode if (! defined nextStatement());
		
		# PRIMARY CONSTRUCTOR
		my $constructorVisibility; 
		# parse "<visibility> constructor" OR "constructor"
		if (${nextStatement()} =~ /^\s*(\w+)(?:\s+(\w+))?/gmc) {
			if (((defined $2) && ($2 eq "constructor")) || ($1 eq "constructor")){
				Lib::ParseUtil::splitAndFocusNextStatementOnPos();
			}
			else {
				pos(${nextStatement()}) = 0;
			}
		}
		
		if (${nextStatement()} eq '(') {
			my $constructNode = Node(ConstructorKind, createEmptyStringRef);
			SetLine($constructNode, getStatementLine());
			my $params = parseParameters();
			Lib::NodeUtil::SetXKindData($constructNode, 'params', $params);
			AppendKotlin($classNode, $constructNode);
		}
		
		if ((defined nextStatement()) && (${nextStatement()} eq ":" )) {
			getNextStatement();
			parseDelegation();
		}
		
		# BODY (if any ...)
		if (defined nextStatement()) {
			parseClassBody($classNode, $enum);
		}
		
		SetEndline($classNode, getStatementLine());
		
		return $classNode;
	}
	return undef;
}

########################## OBJECT ################################

sub parseObject() {
	if (${nextStatement()} =~ /^\s*(companion\s+)?object\b/gmc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		
		my $name;
		my $line = getStatementLine();
		my $proto = "";
		
		# NAME
		if (${nextStatement()} =~ /^\s*\w+\b/gmc) {
			$name = ${getNextStatement()};
		}
		
		my $objectKind;
		if (defined $name) {
			$objectKind = ObjectDeclarationKind;
		}
		else {
			$objectKind = ObjectExpressionKind;
		}
		
		my $objectNode = Node($objectKind, createEmptyStringRef());
		
		my $stmt;
		if (defined nextStatement() && ${nextStatement()} eq ':') {
			getNextStatement();
			
			parseDelegation();;
		}
		
		# BODY
		if ( (defined ($stmt = nextStatement())) && ($stmt ne '{')) {
			parseClassBody($objectNode);
		}
		else {
			Lib::Log::WARNING("missing object body at line $line");
		}
		return $objectNode;
	}
	return undef;
}

##################################################################
#              ROOT
##################################################################
sub parseRoot() {

  my $root = Node(RootKind, createEmptyStringRef());

  SetName($root, 'root');

  #my $artiKey = Lib::ParseUtil::buildArtifactKeyByData($name, $line);
  Lib::ParseUtil::newArtifact('root');

  while ( defined nextStatement() ) {
     my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);
     if (defined $subNode) {
        AppendKotlin($root, $subNode);
     }
  }

  Lib::ParseUtil::endArtifact('root');

  return $root;
}

#
# Split a JS buffer into statement separated by structural token
# 

sub splitKotlin($) {
   my $r_view = shift;

   my  @statements = split /(\b(?:fun)\b|$KOTLIN_SEPARATOR|$EXPRESSION_STATEMENT)/smi, $$r_view;
   
   if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }
   return \@statements;
}


sub ParseKotlin($) {
  my $r_view = shift;
  
  my $r_statements = splitKotlin($r_view);

  Lib::ParseUtil::InitParser($r_statements);
  initContext();
  initEnclosing();

  # Mode LAST (no inclusion) for artifact consolidation.
  Lib::ParseUtil::setArtifactMode(1);

  my $root = parseRoot();
  my $Artifacts = Lib::ParseUtil::getArtifacts();

  return ($root, $Artifacts);
}

###################################################################################
#              MAIN
###################################################################################

sub preComputeListOfKinds($$) {
  my $node = shift;
  my $vue = shift;
  my @FunctionList = GetNodesByKind($node, FunctionKind );
  my @FunctionExpressionList = GetNodesByKind($node, FunctionExpressionKind );
  my @LambdaList = GetNodesByKind($node, LambdaKind );
  my @ConditionList = GetNodesByKind($node, ConditionKind);
  my @IfList = GetNodesByKind($node, IfKind);
  my @WhenList = GetNodesByKind($node, WhenKind);
  my @ClassesList = GetNodesByKind($node, ClassKind);
  my @ReturnsList = GetNodesByKind($node, ReturnKind);
  my @VarsList = GetNodesByKind($node, VarKind);
  my @ValsList = GetNodesByKind($node, ValKind);
  
  my %H_KindsLists = ();
  $H_KindsLists{&FunctionKind}=\@FunctionList;
  $H_KindsLists{&FunctionExpressionKind}=\@FunctionExpressionList;
  $H_KindsLists{&LambdaKind}=\@LambdaList;
  $H_KindsLists{&ConditionKind}=\@ConditionList;
  $H_KindsLists{&IfKind}=\@IfList;
  $H_KindsLists{&WhenKind}=\@WhenList;
  $H_KindsLists{&ClassKind}=\@ClassesList;
  $H_KindsLists{&ReturnKind}=\@ReturnsList;
  $H_KindsLists{&VarKind}=\@VarsList;
  $H_KindsLists{&ValKind}=\@ValsList;

  $vue->{'KindsLists'} = \%H_KindsLists;
}

# description: Kotlin parse module Entry point.
sub Parse($$$$)
{
	my ($fichier, $vue, $options, $couples ) = @_;
    my $status = 0;

    initMagicNumbers($vue);

    $StringsView = $vue->{'HString'};

	Lib::ParseUtil::registerParseUnknow(\&parseUnknow);
	
	# launch first parsing pass : strutural parse.
	my ($KotlinNode, $Artifacts) = ParseKotlin(\$vue->{'code'});

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

	if (defined $options->{'--print-tree'}) {
		Lib::Node::Dump($KotlinNode, *STDERR, "ARCHI");
	}
	if (defined $options->{'--print-test-tree'}) {
		print STDERR ${Lib::Node::dumpTree($KotlinNode, "ARCHI")} ;
	}
      
	if (defined $options->{'--print-statement'}) {
		my @kinds = split(',', $options->{'--print-statement'});
		for my $kind (@kinds) {
			my @nodes = GetNodesByKind($KotlinNode, $kind);
			for my $node (@nodes) {
				my $stmt = GetStatement($node);
				if (defined $stmt) {
					print "STATEMENT $kind = $$stmt\n";
				}
			}
		}
	}
      
	$vue->{'structured_code'} = $KotlinNode;
	$vue->{'artifact'} = $Artifacts;

	# pre-compute some list of kinds :
	preComputeListOfKinds($KotlinNode, $vue);

	#TSql::ParseDetailed::ParseDetailed($vue);
	if (defined $options->{'--print-artifact'}) {
		for my $key ( keys %{$vue->{'artifact'}} ) {
			print "-------- $key -----------------------------------\n";
			print  $vue->{'artifact'}->{$key}."\n";
		}
	}

	return $status;
}

1;
