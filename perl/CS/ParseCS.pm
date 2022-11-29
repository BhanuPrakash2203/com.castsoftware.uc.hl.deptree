package CS::ParseCS;
# les modules importes
use strict;
use warnings;

use Erreurs;

use CountUtil;

use Lib::Node; # qw( Leaf Node Append );
use Lib::NodeUtil ;
use Lib::NodeUtil qw( SetName SetStatement SetLine GetLine SetEndline GetEndline);
use Lib::ParseUtil;
use CS::ParseVariables;

use CS::CSNode;
use Groovy::ParseGroovy;

my $DEBUG = 0;

my @rootContent = (
			\&parseNamespace,
			\&parseClass,
			\&parseStruct,
			#\&parseEnum,
			\&parseInterface,
			\&parseModifiers,
			\&parseUsing,
			\&parseKeyword,
			\&parseMetadata,
			# as a last resort, parse an unknow statement based on braces enclosing ... 
			\&parseUnknowRoot,
);

my @classContent = ( 
			\&parseModifiers,
			\&parseClass,
			\&parseStruct,
			#\&parseEnum,
			#\&parseInterface,
			\&parseMetadata,
			#\&parseBlock,
			\&parseConst,
			\&parseEvent,
			\&parseDelegate,
			\&parseMember,
);

my @methodContent = (
			#\&parseClass,
			#\&parseEnum,
			#\&parseInterface,
			#\&parseModifiers,
			\&parseIf,
			\&parseWhile,
			\&parseFor,
			\&parseForeach,
			\&parseDo,
			\&parseTry,
			#\&parseReturn,
			\&parseSwitch,
			#\&parseThrow,
			#\&parseBreak,
			\&parseUsing,
			\&parseKeyword,
			\&parseLock,
			\&parseCheckedUnchecked,
			\&parseUnsafe,
			\&parseFixed,
			\&parseBlock,
			\&parseLabel,
			#\&parseAnnotation
);

my @expressionContent = (
			\&parseSwitchExpression,
			\&parseNew,
);

my @switchContent = ( 
			\&parseCase,
			\&parseDefault,
);

my $NullString = '';

my $re_MODIFIERS = '(?:new|public|protected|internal|private|abstract|sealed|static|readonly|volatile|partial|fixed|unsafe)';
    
my $IDENTIFIER = '\w+';

my $StringsView = undef;

my %KEYWORDS = (
	'return' => ReturnKind(),
	'yield' => YieldKind(),
	'throw' => ThrowKind(),
	'break' => BreakKind(),
);

########################## TRIGGERS ###################

#-----------------------------------------------------------------------
# CALLBACK for parseParenthesis.
#-----------------------------------------------------------------------

# parse Statement/Node for "new" expression :
# -> parse the "new" statement, create a corresponding Node and a Corresponding statement representation !
sub triggerParseNew() {
	my $newNode = parseNew();

	if (! defined $newNode) {
		# No node to return. But return the next statement expression element, to prevent from infinite loop (something should be consummed)
		return [ getNextStatement(), [] ];
	}
	
	my $statement = "__new_".GetName($newNode)."__";
	return [ \$statement, [$newNode] ];
}

my $TRIGGERS_parseParenthesis = {
	"new" => \&triggerParseNew,
};

#-----------------------------------------------------------------------
# CALLBACK used when parsing expression
#-----------------------------------------------------------------------

# this function is needed because we should distinguish between "<" in a template type and the "less than" operator.  
sub parse_SN_ExpressionLessThan() {
	my $expression = "";
	
	# Consumes the <
	$expression .= ${getNextStatement()};
	
	# parse until closing > or ; or }
	Lib::ParseUtil::register_SplitPattern(qr/[>]/);
	
	my ($statement, $subNodes) = Lib::ParseUtil::parse_Expression({">" =>1});
	
	Lib::ParseUtil::release_SplitPattern();
	
	$expression .= $$statement;
	
	if (${nextStatement()} eq '>') {
		$expression .= ${getNextStatement()};
	} 
	
	return [ \$expression, $subNodes ];
}

my $Expression_TriggeringItems = {
	"new" => \&triggerParseNew,
	"<" => \&parse_SN_ExpressionLessThan,
};

########################## CONTEXT ###################

use constant CTX_LEAVE => -1;
use constant CTX_ROOT => 0;
use constant CTX_CLASS => 1;
use constant CTX_METHOD => 2;
use constant CTX_ENUM => 3;
use constant CTX_INTERFACE => 4;
use constant CTX_SWITCH => 5;

my $DEFAULT_CONTEXT = CTX_ROOT;

my @context = (CTX_ROOT);

my %ContextContent = (
	&CTX_ROOT() => \@rootContent,
	&CTX_CLASS() => \@classContent,
	&CTX_METHOD() => \@methodContent,
	&CTX_ENUM() => \@classContent,
	&CTX_INTERFACE() => \@classContent,
	&CTX_SWITCH() => \@switchContent
	);

sub getCurrentContextContent() {
	return $ContextContent{ $context[-1] };
}

sub initContext() {
	@context = (CTX_ROOT);
	$DEFAULT_CONTEXT = CTX_ROOT;
}

sub popContext() {
	if (scalar @context > 1) {
		pop @context;
	}
	else {
		print "PARSE ERROR : context underflow !\n";
	}
}

sub sendContextEvent($;$) {
	my $event = shift;

	if ($event == CTX_LEAVE) {
		popContext();
	}
	else {
		push @context, $event;
	}
}

sub getContext() {
	if (scalar @context) {
		return $context[-1];
	}
	else {
		print "PARSE ERROR: empty context !";
		return $DEFAULT_CONTEXT;
	}
}


my $previousUnknow = undef;

sub isNextOpenningBrace() {
	if ( ${nextStatement()} eq '{' ) {
		return 1;
	}  
	return 0;
}

sub isNextClosingBrace() {
	if ( ${nextStatement()} eq '}' ) {
		return 1;
	}  
	return 0;
}

sub isNextClosingParenthese() {
	if ( ${nextStatement()} eq ')' ) {
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

######################### EXPRESSIONS ##################################

#sub parseEnclosedExpression() {
#	my $next;
#	if ((defined ($next = nextStatement())) && (($$next eq '(') || ($$next eq '{') || ($$next eq '['))) {
#		return Lib::ParseUtil::parseRawOpenClose();
#	}
#	return undef;
#}

sub nextTokenIsEndingInstruction($) {
	my $r_previousToken = shift;
	
	my $r_previousBlanks = Lib::ParseUtil::getSkippedBlanks();

#	# a enclosing <> '' means the expression is enclosed => do not terminate.
#	if (getEnclosing() ne '') {
#		#if (defined $nextIsNewStatement) {
#		#	Lib::Log::WARNING("unexpected statement beginning (".${nextStatement()}.") when parsing expression expression !");
#		#}
#		return 0 
#	}

	if (defined nextStatement()) {

		# INSTRUCTIONS SEPARATOR
		# ----------------------
		# a ';' or '}' always ends a statement expression.
		my $next = nextStatement();
		if (($$next eq ';') || ($$next eq '}') || ($$next eq ')') || ($$next eq ']')) {
			return 1;
		}
		
		elsif ( $$r_previousToken =~ /__lambda__\s*$/m ) {
			# a lambda is closing an expression (or sub expression)
			return 1;
		}
		
		# NEVER_ENDING_STATEMENT_PATTERN
		#-------------------------------
#		if ($$r_previousToken =~ /$NEVER_ENDING_STATEMENT_PATTERN/m) {
#			return 0;
#		}
		
		# NEW STATEMENT
		# ----------------------
		
		# check if we already know that next statement is a new instruction 
#		return 1 if $nextIsNewStatement;
		
		# STATEMENT BEGINNING PATTERN
#		if ($$next =~ /$STATEMENT_BEGINNING/) {
#			return 1;
#		}

		# NEVER STATEMENT BEGINNING PATTERN
#		if ($$next =~ /$NEVER_BEGINNING_STATEMENT_PATTERN/) {
#			return 0;
#		}

		# DOT (de-referencement)
		# ----------------------
		#if ($$next =~ /^\s*\./m) {
		#	return 0;
		#}

		# NEW LINE
		# --------
		# if there was a new line before the token ...
#		if ($$r_previousBlanks =~ /\n/s) {
#			return 1;
#		}
#		else {
			# return 0 by default becasue next token is an the same line than previous one.
#		}
	}
	else {
		# if next token is NOT DEFINED, then return true because another try to
		# retrieve the next token will not provide a new statement.
		return 1;
	}

	return 0;
}

my $END_EXPRESSION_CALLBACK = [];

sub set_EndExpression_cbs($) {
	$END_EXPRESSION_CALLBACK = shift;
}

sub clear_EndExpression_cbs() {
	$END_EXPRESSION_CALLBACK = [];
}

my %H_CLOSING_CB = (
	'(' => \&isNextClosingParenthese,
	'{' => \&isNextClosingBrace,
	'[' => \&isNextClosingBracket,
);

my %H_CLOSING = (
	'(' => ')',
	'{' => '}',
	'[' => ']',
);

sub isNextQuestionMark() {
	if (${nextStatement()} eq "?") {
		return 1;
	}
	else {
		Lib::ParseUtil::splitNextStatementOnPattern(qr/\?/);		
		if (${nextStatement()} eq "?") {
			return 1;
		}
	}
	return 0;
}

sub isNextColon() {
	if (${nextStatement()} eq ":") {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		return 1;
	}
	return 0;
}

sub parseEnclosedExpression($) {
	my $parent = shift;;
	
	#my $enclosedNode = Node(UnknowKind, createEmptyStringRef());
	
	my $r_statement = GetStatement($parent);
	
	# get opening
	my $opening = ${getNextStatement()};
	my $openingLine = getStatementLine();

	$$r_statement .= $opening;
	
	#my $callbacks = [ $H_CLOSING_CB{$opening}, \&isNextQuestionMark, \&isNextColon ];
	my $callbacks = [ $H_CLOSING_CB{$opening} ];
	
	parseExpression($parent, $callbacks );
	
	# do several calls to parseExpression, because only closing pattern can stop.
	while ((defined nextStatement()) && (${nextStatement()} ne $H_CLOSING{$opening})) {
		
		#if (${nextStatement()} eq "?") {
		#	$bool_Ternary = 1;
		#}
		#elsif (${nextStatement()} eq ":") {
			
		#}
		# get item (certainly ";") that ended unexpectedly the expression in the previous parseExpression() call.
		$$r_statement .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
		parseExpression($parent, $callbacks);
	}
					
	# get closing
	if (defined nextStatement()) {
		$$r_statement .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
	}
	else {
		Lib::Log::ERROR("Missing closing for $opening opened at line $openingLine");
	}
	
	#my $parentStatement = GetStatement($parent);
	#$$parentStatement .= $$r_statement;
}

sub parseExpression($;$);
sub parseExpression($;$) {
	my $parent = shift;
	my $cb_end = shift;

    # true if the keyword 'new' is encountered.
    # In this case, when encountering a "<" it is certainely a template openning, and not a comparison operator.
    my $new_context = 0;

	#enterContext(EXPRESSION);

	my $endOfStatement = 0;
	
	my $r_statement = createEmptyStringRef();
	my $parentStatement = GetStatement($parent);
	# during treatment, parent will have a local statement, that will be added to previous statement at end of function.
	SetStatement($parent, $r_statement);
	
	my $bool_Ternary = "";
	
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
			for my $cb (@$END_EXPRESSION_CALLBACK) {
				if ($cb->()) {
					$endOfStatement = 1;
					last;
				}
			}
		}

		if (! $endOfStatement) {

			my $skippedBlanks = ${Lib::ParseUtil::getSkippedBlanks()};

			my $subNode;

			if (${nextStatement()} eq "=>") {
				getNextStatement();
				$subNode = parse_lambda($r_statement);
			}
			else {
				# Next token belongs to the expression. Parse it.
				$subNode = Lib::ParseUtil::tryParse(\@expressionContent);
			}

			if (defined $subNode) {
				# *** SYNTAX has been recognized by CALLBACK
				if (ref $subNode eq "ARRAY") {
					
					if (IsKind($subNode, SwitchExpressionKind)) {
						if ($$r_statement =~ /\b(\w+)\s*$/m) {
							my $switchExpr = $1;
							SetStatement($subNode, \$switchExpr);
							$$r_statement =~ s/\b(\w+)\s*$//m;
						}
					}
					
					Append($parent, $subNode);
					$$r_statement .= $skippedBlanks . CS::CSNode::nodeLink($subNode);
				}
				else {
					$$r_statement .= $$subNode;
				}
			}
			else {
				my $next = nextStatement();
				#if (($$next eq "(") && ($$r_statement =~ /\bdelegate\s*$/m)) {
				if (($$next =~ /\A\s*\bdelegate\s*$/m)) {
					# OLD ANONYMOUS function syntax ...
					getNextStatement();
					my $line = getNextStatementLine();
					my $subNode = parse_Method("Anonymous_".$line, $line);
					SetKind($subNode, AnonymousMethodKind);
					$$r_statement .= " __ANONYMOUS_METHOD__ ";
					Append($parent, $subNode);
				}
				elsif (($$next eq "(") || ($$next eq "{") || ($$next eq "[")) {
					$$r_statement .= $skippedBlanks;
					parseEnclosedExpression($parent);
				}
				elsif (${nextStatement()} eq "=") {
					# begin a new expression after an assignment ... some patterns like ternary needs to have a separate statement ternary
					$$r_statement .= $skippedBlanks . ${getNextStatement()};
					parseExpression($parent);
				}
				elsif (${nextStatement()} eq "?") {
					$$r_statement .= $skippedBlanks . ${getNextStatement()};
					my $fakeNode = Node(UnknowKind, $r_statement);
					SetLine($fakeNode, getStatementLine());
					
					if ( nextTokenIsEndingInstruction($r_statement)) {
						last;
					}
					
					# parse TRUE expression
					parseExpression($fakeNode, [\&isNextColon]);
					if (${nextStatement()} eq ":") {
						# yeah, it's a ternary !!!
						SetKind($fakeNode, TernaryKind);
						$$r_statement .= $skippedBlanks . ${getNextStatement()};
						
						# parse FALSE expression
						parseExpression($fakeNode);
#print STDERR "TERNARY : ".${GetStatement($fakeNode)}."\n";

						Append($parent, $fakeNode);
						
						# create dedicated statement for ternary to allow modification of current statement  (that contain the ternary).
						my $TernaryStatement = ${GetStatement($fakeNode)};
						SetStatement($fakeNode, \$TernaryStatement);
						$$r_statement = "__TERNARY__";						
					}
					else {
						# it is not a ternary ...
						# retrieve subnodes if any ...
						for my $child (@{GetChildren($fakeNode)}) {
							Append($parent, $child);
						}
					}
				}
				else {
					#if (${nextStatement()} eq "?") {
					#	$bool_Ternary = "?";
					#}
					#elsif (${nextStatement()} eq ":") {
					#	$bool_Ternary = ":" if ($bool_Ternary eq "?");
					#}
					
					# get the next statement, as planed ...
					$$r_statement .= $skippedBlanks . ${getNextStatement()};
				}
			}
		}

		if ( nextTokenIsEndingInstruction($r_statement)) {
#print "--> CHECK END EXPRESSION\n";
			last;
		}
	}

	$$parentStatement .= $$r_statement;
	SetStatement($parent, $parentStatement);

#print "EXPRESSION : $$parentStatement\n";

	#leaveContext();
	return $r_statement;
}

######################### UNKNOW ##################################

sub isNextFatArrow() {
	if ( ${nextStatement()} eq '=>' ) {
		return 1;
	}  
	return 0;
}

sub parseUnknow() {
	my $line = getNextStatementLine();
	
	
#    if (${nextStatement()} eq '}') {
#		if (defined $previousUnknow && (nextStatement() == $previousUnknow)) {
#			getNextStatement();
#			print STDERR "[parseUnknow] ERROR : trashing unmanaged closing brace at line $line\n";
#		}
#		else {
#			$previousUnknow = nextStatement();
#			print STDERR "[parseUnknow] WARNING : unexpected closing brace at line $line\n";
#		}
#    }
#    else {
#		my $stmt;
#		while ((defined ($stmt = nextStatement())) && ($$stmt ne ";") && ($$stmt ne "}") && ($$stmt ne ")")) {
#						
#			if ($$stmt eq "{") {
#				my $expr = Lib::ParseUtil::parseUntilPeer("{", "}");
#				if (defined $expr) {
#					$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.$$expr;
#				}
#			}
#			elsif ($$stmt eq "(") {
#				my $expr = Lib::ParseUtil::parseUntilPeer("(", ")");
#				if (defined $expr) {
#					$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.$$expr;
#				}
#			}
#			else {
#				$statement .= ${getNextStatement()};
#			}
#		}	
#	}

	
	my $unkNode = Node(UnknowKind, createEmptyStringRef());
	my $statement = GetStatement($unkNode);
	SetLine($unkNode, $line);
	
	# parse expression, but stop on => or { to detect local functions if any )
	parseExpression($unkNode, [\&isNextOpenningBrace, \&isNextFatArrow]);
	
	if (defined nextStatement()) {
		if ((${nextStatement()} eq "=>") || (${nextStatement()} eq "{")) {
			# we have a local function if 
			# - the { or => is preceded by "<name> (...)"
			# - no = op befaore <name> (in such case, it would be a variable initialisation)
			if ($$statement =~ /\A[^=]*(\w+)\s*\([^\(\)]*\)\s*$/m){
				# local function detected
#print STDERR "LOCAL FUNCTION ($1) : ".${GetStatement($unkNode)}."\n";
				my $functionNode = Node(LocalFunctionKind, $statement);
				SetName($functionNode, $1);
				SetLine($functionNode, $line);
				parse_MethodBody($functionNode);
				return $functionNode;
			}
			else {
			# resume expression parsing (it has been interrupted to check for presence of local function ...)
				parseExpression($unkNode);
			}
		}
	}
	else {
		Lib::Log::ERROR("EOF encountered when checking unknow statement against local function : $$statement!!!\n");
	}

	my $var = CS::ParseVariables::parseVariableStatement($statement, $line, VariableKind);
	
	if (defined $var) {
		# The unknow instruction has been recognized as a variable declaration
		my $subNodes = GetChildren($unkNode);
		my $init = GetChildren($var)->[0];
		
		if (scalar @$subNodes) {
			if (defined $init) {
				# if the variabla has an init statement, assume that the subnodes of the unknow expresison 
				# belong to the init expression (the declarative part never create subnodes)
				for my $child (@$subNodes) {
					Append($init, $child);
				}
			}
			else {
				# there is subnodes, but no init !!?? 
				my $unexpectedInit = GetStatement($subNodes->[0]);
				Lib::Log::ERROR("Expression node not corresponding to a variable initialisation ($$unexpectedInit) ... at line ".GetLine($var)."\n");
			}
		}

		$unkNode = $var;
	}
	
	Lib::ParseUtil::purgeSemicolon();
	return $unkNode;
}

sub parseUnknowRoot() {
	my $line = getNextStatementLine();
	my $unkNode = Node(UnknowKind, createEmptyStringRef());
	my $statement = GetStatement($unkNode);
	SetLine($unkNode, $line);
	
	#my $stmt;
	#while ((defined ($stmt = nextStatement())) && ($$stmt ne "}") && ($$stmt ne '{')) {
	#	$$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
	#}
	#
	#if (!defined $stmt) {
	#	Lib::Log::ERROR("EOF encountered while parsing unknow statement in root context : $$statement\n");
	#}
	#elsif ($$stmt eq "{") {
	#	# parse accolade content
	#	$$statement .= ${Lib::ParseUtil::getSkippedBlanks()};
	#	parseEnclosedExpression($unkNode);
	#}
	
	if (${nextStatement()} eq "{") {
		# parse accolade content because it correspond to a unknow structure
		$$statement .= ${Lib::ParseUtil::getSkippedBlanks()};
		parseEnclosedExpression($unkNode);
	}
	else {
		# jusr get the next item, hopping the following will be recognized in another iteration.
		$$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
	}
	
	return $unkNode;
}

################# KEYWORD #########################
sub parseKeyword() {
	if (${nextStatement()} =~ /\A\s*(\w+)/gc ) {

		if (exists $KEYWORDS{$1}) {
			Lib::ParseUtil::splitAndFocusNextStatementOnPos();
			
			my $kind = $KEYWORDS{$1};
			
			my $node = Node($kind, createEmptyStringRef());
			SetLine($node, getStatementLine());
			
			if (${nextStatement()} ne ';') {
				parseExpression($node);
			}
			
			Lib::ParseUtil::purgeSemicolon();
			
			return $node;
		}
	}
	
	return undef;
}

################# USING #########################
sub parseUsing() {
	if (${nextStatement()} =~ /\A\s*(using)/gc ) {

		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
			
		my $kind = UsingKind;
			
		my $node = Node($kind, createEmptyStringRef());
		SetLine($node, getStatementLine());
			
		parseExpression($node, [\&isNextOpenningBrace]);
		
		my $bloc = parseBlock();
		
		if (defined $bloc) {
			# the using expression is fillowed by an instructions bloc.
			# => it's a using statement.
			Append($node, $bloc);
		}
		else {
			# if using keyword is followed by a namespace
			# OR contains no subnodes (meaning no "new" expression)
			# => it is a using directive
			# NOTE : namespace is identifiers concatened with dots, followed by = (renaming case) or ;
			#      ex : using toto.titi;
			#           using Project = PC.MyCompany.Project;
			if ( (${GetStatement($node)} =~ /\A\s*[\w\.]+\s*(?:=|\z)/) ||
			     ( scalar @{GetChildren($node)} == 0) ) {
				
				SetKind($node, ImportKind);
			}
		}
			
		Lib::ParseUtil::purgeSemicolon();
			
		return $node;
	}
	
	return undef;
}

##################################################################
#                   GETTERS
##################################################################

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#!!!!!!!!!!!!!!!! FIXME : TO BE ADAPTED FOR JAVA !!!!!!!!!!!!!!!!!
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
sub isConstant($$) {
	my $var = shift;
	my $code = shift;
#print "CONST $var ???\n";
	my $nbFound = 0;
	# Count number of assignment. 
	# if assigned more than on time, then it's not a constant.
	while ($$code =~ /(?:^|[^\.,\(])\s*$var\s*=\s*(?:(?:CHAINE_\d+|\d|\[)|(.))/smg) {
		$nbFound++;
		if (	($nbFound > 1) ||   # more than one assignment
				(defined $1)) {     # assignment of a non literal
			# ==> not a constant
			pos($$code) = undef;
#print "--> NO !!\n";
			return 0;
		}
	}
#print "--> YES !\n";
	return 1;
}

##################################################################
#              SWITCH
##################################################################

sub isNextSwitch() {
		if ( ${nextStatement()} eq 'switch' ) {
		return 1;
	}  
	return 0;
}

sub parseSwitch() {
	if (isNextSwitch()) {
		sendContextEvent(CTX_SWITCH);
		my $ret = parseControle(SwitchKind, [], 1, 0); # COND and no THEN level
		sendContextEvent(CTX_LEAVE);
		return $ret;
	}
	return undef;
}

sub parseCaseDefault($) {
	my $kind = shift;
	
	my $caseNode = Node($kind, createEmptyStringRef());
		
	# trashes the "case" or "default" keyword
	getNextStatement();
	SetLine($caseNode, getStatementLine());
		
	my $cond = "";
	my $next;
	while (defined ($next=${nextStatement()}) && ($next ne ":")) {
		$cond .= getNextStatement();
	}
		
	if (defined $next && ($next eq ':')) {
		getNextStatement();
	}
	else {
		print "[ParseCS::parseCase] ERROR : missing semi-colon after case (line ".GetLine($caseNode).") at end of file !!\n";
	}
		
	SetStatement($caseNode, \$cond);
		
	# content of a "case" is the same as a method ... (full instruction set ...)
	sendContextEvent(CTX_METHOD);
	
	my $currentContext = getCurrentContextContent();
	while (defined ($next=${nextStatement()}) && ($next ne 'case') && ($next ne 'default') && ($next ne '}')) {
		
		if (${nextStatement()} eq "{") {
			getNextStatement();
			Lib::ParseUtil::parseStatementsBloc($caseNode, [\&isNextClosingBrace], $currentContext, 0);
		}
		else {
			my $node = Lib::ParseUtil::tryParse_OrUnknow($currentContext);
			if (defined $node) {
				Append($caseNode, $node);
			}
		}
	}
	SetEndline($caseNode, getStatementLine());
	
	sendContextEvent(CTX_LEAVE);
	
	if (! defined $next) {
		print "[ParseCS::parseCase] ERROR : cannot find beginning '('\n";
	}
		
	return $caseNode;
}

sub isNextCase() {
		if ( ${nextStatement()} eq 'case' ) {
		return 1;
	}  
	return 0;
}

sub parseCase() {
	if (isNextCase()) {
		return parseCaseDefault(CaseKind);
	}
	return undef;
}

sub isNextDefault() {
		if ( ${nextStatement()} eq 'default' ) {
		return 1;
	}  
	return 0;
}

sub parseDefault() {
	if (isNextDefault()) {
		return parseCaseDefault(DefaultKind);
	}
	return undef;
}

sub _cb_endWithComa() {
	Lib::ParseUtil::splitNextStatementOnPattern(qr/,/);
	
	if (${nextStatement()} eq ",") {
		return 1;
	}
	
	return 0;
}

sub parseSwitchExpression() {
	if (isNextSwitch()) {
		sendContextEvent(CTX_SWITCH);
		
		my $SwitchNode = Node(SwitchExpressionKind, createEmptyStringRef());
		
		if (${Lib::ParseUtil::nextNonBlank()} eq "(") {
			Lib::Log::ERROR("switch statement encountered while expecting switch expression at line ".getNextStatementLine()."\n");
			return parseSwitch();
		}
		
		# trash "switch"
		getNextStatement();
		SetLine($SwitchNode, getStatementLine());
		
		# trash "{"
		getNextStatement();
		
		my $next;
		while ((defined ($next = nextStatement())) && ($$next ne "}")) {
			
			# parse pattern
			my $pattern = "";
			my $caseNode = Node(CaseKind, \$pattern);
			SetLine($caseNode, getNextStatementLine());
			while ((defined ($next = nextStatement())) && ($$next ne "=>")) {
				$pattern .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
			}

			# trash =>
			getNextStatement();
			
			# parse instruction
			set_EndExpression_cbs([\&_cb_endWithComa]);
			my $instructionNode = Lib::ParseUtil::tryParse_OrUnknow(\@methodContent);
			clear_EndExpression_cbs();
			
			Append($caseNode, $instructionNode);
			Append($SwitchNode, $caseNode);
			
			if (! defined nextStatement()) {
				Lib::Log::ERROR("Unexpected EOF while parsing switch expression at line ".GetLine($SwitchNode)."\n");
			}
			elsif (${nextStatement()} eq ",") {
				getNextStatement();
			}
		}
		
		if (defined $next && $$next ne '}') {
			Lib::Log::ERROR("Missing closing accolade at end of 'switch expression' at line ".getNextStatementLine()."\n");
		}
		else {
			# trash }
			getNextStatement();
		}
		
		#my $ret = parseControle(SwitchKind, [], 1, 0); # COND and no THEN level
		sendContextEvent(CTX_LEAVE);
		return $SwitchNode;
	}
	return undef;
}

##################################################################
#              TRY
##################################################################

sub isNextCatch() {
		if ( ${nextStatement()} eq 'catch' ) {
		return 1;
	}  
	return 0;
}

sub parseCatch() {
	if (isNextCatch()) {
		my $statement = "";
		my $catchNode = Node(CatchKind, \$statement);
		
		#trash catch keyword
		getNextStatement();

		SetLine($catchNode, getStatementLine());

		if (${nextStatement()} eq '(') {
			$statement .= ${Lib::ParseUtil::parseRawOpenClose()};
		}

		# parse 'when' clause if any ...
		if (${nextStatement()} =~ /^(\s*when\b\s*)/gc) {
			$statement .= $1;
			Lib::ParseUtil::splitAndFocusNextStatementOnPos();
			if (${nextStatement()} eq '(') {
				$statement .= ${Lib::ParseUtil::parseRawOpenClose()};
			}
		}

		parse_block($catchNode);

		SetEndline($catchNode, getStatementLine());

		return $catchNode;
	}
	return undef;
}

sub isNextFinally() {
		if ( ${nextStatement()} eq 'finally' ) {
		return 1;
	}  
	return 0;
}

sub parseFinally() {
	if (isNextFinally()) {
		
		return parseControle(FinallyKind, [], 0, 0);
	}
	return undef;
}

sub isNextTry() {
		if ( ${nextStatement()} eq 'try' ) {
		return 1;
	}  
	return 0;
}

sub parseTry() {
	if (isNextTry()) {
		return parseControle(TryKind, [\&parseCatch, \&parseFinally], 0);
	}
	return undef;
}

##################################################################
#              CONDITION (IF / WHILE / FOR ...)
##################################################################
sub parseCondition() {
	my $condNode = Node(ConditionKind, createEmptyStringRef());
	my $condition = '';
	
	SetLine($condNode, getStatementLine());
	
	my $stmt;
	if ((defined ($stmt = nextStatement())) && ($$stmt eq "(")) {
		
		#my ($stmt, $subNodes) = Lib::ParseUtil::parseParenthesis('(');
		#$condition .= $$stmt;
		#Lib::Node::AddSubNodes($condNode, $subNodes);
		
		#Lib::ParseUtil::updateGenericParse(\$condition, $condNode, Lib::ParseUtil::parseParenthesis('(', $TRIGGERS_parseParenthesis));
		$condition = Lib::ParseUtil::parseRawOpenClose();
	}
	else {
		print "[ParseCS::parseCondition] ERROR : cannot find beginning '('\n";
		return undef;
	}

#print "CONDITION : $condition\n";

	my $cond = $$condition;
	$cond =~ s/\A\(\s*//;
	$cond =~ s/\s*\)\z//;
	
	my $init;
	my $inc;
	if ($cond =~ /\A([^;]*);([^;]*);([^;]*)/) {
		$init = $1;
		$cond = $2;
		$inc = $3;
	}	

	setCSKindData($condNode, 'init', $init);
	setCSKindData($condNode, 'cond', $cond);
	setCSKindData($condNode, 'inc', $inc);
	
	SetStatement($condNode, $condition);
	
	return $condNode;
}

##################################################################
#              IF
##################################################################

sub isNextElse() {
	if ( ${nextStatement()} eq 'else' ) {
		return 1;
	}  
	return 0;
}

sub parseElse() {
	if (isNextElse()) {
		my $ret = parseControle(ElseKind, [], 0, 0); # no cond, no then level.
		return $ret;
	}
	return undef;
}

sub isNextIf() {
	if ( ${nextStatement()} eq 'if' ) {
		return 1;
	}  
	return 0;
}

sub parseIf() {
	if (isNextIf()) {
		return parseControle(IfKind, [\&parseElse]);
	}
	return undef;
}

sub isNextWhile() {
	if ( ${nextStatement()} eq 'while' ) {
		return 1;
	}  
	return 0;
}

sub parseWhile() {
	if (isNextWhile()) {
		return parseControle(WhileKind, []);
	}
	return undef;
}

sub isNextFor() {
	if ( ${nextStatement()} eq 'for' ) {
		return 1;
	}  
	return 0;
}

sub parseFor() {
	if (isNextFor()) {
		my $forNode = parseControle(ForKind, [], 1, 1, 1); # cond + then level + record body
		return $forNode
	}
	return undef;
}

sub isNextForeach() {
	if ( ${nextStatement()} eq 'foreach' ) {
		return 1;
	}  
	return 0;
}

sub parseForeach() {
	if (isNextForeach()) {
		return parseControle(ForeachKind, []);
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
		my $doNode = parseControle(DoKind, [], 0);
		
		my $stmt;
		if ((defined ($stmt = nextStatement())) && ($$stmt eq 'while')) {
			getNextStatement();
			
			my $condNode = parseCondition();
			
			Append($doNode, $condNode);
			
			if ((defined ($stmt = nextStatement())) && ($$stmt eq ';')) {
				getNextStatement();
			}
		}
		return $doNode;
	}
	return undef;
}

sub parse_block($;$) {
	my $blocNode = shift;
	my $context = shift;
	
	$context //= getCurrentContextContent(); # current context by default
	
	my $line = getNextStatementLine();
	
	# check presence of '{'
	if ((defined nextStatement()) && (${nextStatement()} eq '{') ) {
		getNextStatement();

		# parse SEVERAL instructions until closing '}'
		Lib::ParseUtil::parseStatementsBloc($blocNode, [\&isNextClosingBrace], $context, 0);
		
		#if ((defined nextStatement()) && (${nextStatement()} eq '}') ) {
		#	getNextStatement();
		#}
		#else {
		#	Lib::Log::ERROR("Missing closing accolade for opening at line $line\n");
		#}
	}
	else {
		# parse a SINGLE instruction
		my $node = Lib::ParseUtil::tryParse_OrUnknow(getCurrentContextContent());
		if (defined $node) {
			Append($blocNode, $node);
		}
	}
}

sub parseControle($$;$$$) {
	my $kind = shift;
	my $optionalStmtCbs = shift;
	# Is there a condition to parse ?
	my $parseCond = shift;
	my $thenLevel = shift;
	my $recordBody = shift;
	
	$parseCond //= 1; # by default, parse a condition
	$thenLevel //= 1;
	$recordBody //= 0;
	
	if ($parseCond) {
		# Force "then" level if the condition is required.
		$thenLevel = 1;
	}
	
	my $controlNode = Node($kind, createEmptyStringRef());

	#trash the keyword associated to the controle : 'if, while, for ...' keyword
	getNextStatement();

	my $controlLine = getStatementLine();
	SetLine($controlNode, $controlLine);

	if ($parseCond) {
		#### PARSE A CONDITION ...
		my $condNode = parseCondition();
		if (defined $condNode) {
			Append($controlNode, $condNode);
		}
		else {
			# no cond node means no more statement... useless to pursue
			print "[ParseCS::parseControlBloc] SYNTAX ERROR  : missing condition !\n";
			SetEndline($controlNode, getStatementLine());
			return undef;
		}
	}

	my $parentNode = $controlNode;
	if ($thenLevel) {
		# THEN branch (or main bloc if unconditional control like try, switch, ...)
		my $thenNode = Node(ThenKind, createEmptyStringRef());
		$parentNode = $thenNode;
		Append($controlNode, $thenNode);
	}
	
	my $artiKey;
	if ($recordBody) {
		# USE non modal (nested control do not interrupt capture for upper levels) code capture for controls ...
		$artiKey = Lib::ParseUtil::newUnmodalArtifact($kind, $controlLine);
		setCSKindData($controlNode, 'artifact_key', $artiKey);
	}
	
	if (${nextStatement()} ne ";") {
		parse_block($parentNode);
	}
	
	if ($artiKey) {
		Lib::ParseUtil::endUnmodalArtifact($artiKey);
		setCSKindData($controlNode, 'codeBody', Lib::ParseUtil::getArtifact($artiKey));
	}

	my $continue = 1;
	# OPTIONAL related statements (like else, catch, ...)
	while ($continue &&(defined nextStatement())) {
		$continue = 0;
		for my $optCbs (@$optionalStmtCbs) {
			my $node = $optCbs->();

			if (defined $node) {

				Append($controlNode, $node);
				# Continue on the main loop
				$continue = 1;
				last;
			}
		}

		# all callback tried without success => stop !
		if (! $continue) {
			last;
		}
	}

	Lib::ParseUtil::purgeSemicolon();

	SetEndline($controlNode, getStatementLine());
	return $controlNode; 
}

##################################################################
#              LOCK
##################################################################

sub isNextLock() {
		if ( ${nextStatement()} eq 'lock' ) {
		return 1;
	}  
	return 0;
}

sub parseLock() {
	if (isNextLock()) {
		
		getNextStatement();
		
		my $lockNode = Node(LockKind, createEmptyStringRef());
		SetLine($lockNode, getStatementLine());
		
		my $statement = "";
		
		if (${nextStatement()} eq '(') {
			$statement = Lib::ParseUtil::parseRawOpenClose();
		}
		
		SetStatement($lockNode, \$statement);
		
		parse_block($lockNode);
		
		return $lockNode;
	}
	return undef;
}

##################################################################
#              LABEL
##################################################################
sub parseLabel() {
	if ((${nextStatement()} =~ /\A\s*(\w+)\s*$/m) && (${Lib::ParseUtil::nextNonBlank()} eq ":")){
		
		my $name = $1;
		
		# remove the label ... 
		
		# trash label name
		getNextStatement();
		# trash ":"
		getNextStatement();
		
		# ... and return the instruction associated.
		return Lib::ParseUtil::tryParse_OrUnknow(getCurrentContextContent());
	}
	return undef;
}


##################################################################
#              CHECKED / UNCHECKED
##################################################################

sub parseCheckedUnchecked() {
	if ( ${nextStatement()} =~ /\A\s*(checked|unchecked)\s*$/m ) {
		
		my $kind;
		
		if ($1 eq 'checked') {
			$kind = CheckedKind;
		}
		else {
			$kind = UncheckedKind;
		}
		
		if (${Lib::ParseUtil::nextNonBlank()} eq "{") { 
			
			getNextStatement();
			
			my $chkNode = Node($kind, createEmptyStringRef());
			SetLine($chkNode, getStatementLine());
		
			parse_block($chkNode);
		
			return $chkNode;
		}
	}
	return undef;
}

##################################################################
#              UNSAFE
##################################################################

sub parseUnsafe() {
	if ( ${nextStatement()} =~ /\A\s*unsafe\s*$/m ) {
		
		if (${Lib::ParseUtil::nextNonBlank()} eq "{") { 
			
			getNextStatement();
			
			my $unsafeNode = Node(UnsafeKind, createEmptyStringRef());
			SetLine($unsafeNode, getStatementLine());
		
			parse_block($unsafeNode);
		
			return $unsafeNode;
		}
	}
	return undef;
}

##################################################################
#              FIXED
##################################################################

sub parseFixed() {
	if ( ${nextStatement()} =~ /\A\s*fixed\s*$/m ) {
		
		getNextStatement();
		
		my $statement = "";
		
		if ( ${nextStatement()} eq "(") {
			$statement .= ${Lib::ParseUtil::parseRawOpenClose()};
		}

			
		my $fixedNode = Node(FixedKind, \$statement);
		SetLine($fixedNode, getStatementLine());
		
		parse_block($fixedNode);
		
		return $fixedNode;
	}
	return undef;
}

##################################################################
#              MODIFIERS
##################################################################

sub isNextModifiers() {
	if ( ${nextStatement()} =~ /\A\s*$re_MODIFIERS\b/ ) {
		return 1;
	}  
	return 0;
}

sub parseModifiers() {
	if (isNextModifiers()) {
		my $modifiers = getNextStatement();

		my %H_mod;
		
		while ($$modifiers =~ /(\w+)/g) {
			$H_mod{$1} = 1;
		}	
		my $artifactNode = Lib::ParseUtil::tryParse_OrUnknow(getCurrentContextContent());
		
		setCSKindData($artifactNode, 'modifiers', $modifiers);
		setCSKindData($artifactNode, 'H_modifiers', \%H_mod);
		
		# case of several vars declared in the same instruction ... and so several node ...
		my $addnode = getCSKindData($artifactNode, "addnode");
		if (defined $addnode) {
			for my $node (@$addnode) {
				setCSKindData($node, 'modifiers', $modifiers);
				setCSKindData($node, 'H_modifiers', \%H_mod);
			}
		}
		
		return $artifactNode;
	}
	return undef;
}

##################################################################
#              META DATA
##################################################################
sub isNextMetadata() {
	if ( ${nextStatement()} eq '[' ) {
		return 1;
	}  
	return 0;
}

sub parseMetadata() {
	if (isNextMetadata()) {
		my $line = getNextStatementLine();
		
		my $statement = Lib::ParseUtil::parseRawOpenClose();
		
		my $MetaNode = Node(MetadataKind, $statement);
		
		my ($name) = $$statement =~ /\[\s*([\w\.]+)/;
		
		SetName($MetaNode, $name);
		SetLine($MetaNode, $line);
		
		return $MetaNode;
	}
	return undef;
}

sub parseClassContext($$) {
	my $kind = shift;
	my $kindName = shift;

		my $classNode = Node($kind, createEmptyStringRef());
print "--> $kindName found...\n" if $DEBUG;
		sendContextEvent(CTX_CLASS);
		#Lib::ParseUtil::setArtifactUpdateState(0);

		#trash 'class' keyword
		#getNextStatement();
		
		my $statementLine = getStatementLine();
		SetLine($classNode, $statementLine);
		
#		setCSKindData($classNode, 'indentation', Lib::ParseUtil::getIndentation());
		
		my $name = "";
		
		if ($kind ne AnonymousClassKind) {
			my $proto = '';
			while ((defined nextStatement()) && (${nextStatement()} ne '{') ) {
				$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
			}
			($name) = $proto =~ /^\s*(\w+)/sm;
		
			SetStatement($classNode, \$proto);
		}
		else {
			$name = 'AnonymousClass:'.$statementLine;
		}
		
		SetName($classNode, $name);
		
		if (! defined nextStatement()) {
			print STDERR "[PARSE] Error : missing openning '{' for $kindName $name\n";
		}
		else {
			getNextStatement();
		}
		
		Lib::ParseUtil::setArtifactUpdateState(1);
if (! defined $name) {
print STDERR "NO NAME for class at line $statementLine\n";
}
		my $artiKey = Lib::ParseUtil::newArtifact('class_'.$name, $statementLine);
		setCSKindData($classNode, 'artifact_key', $artiKey);

		while (nextStatement() && (${nextStatement()} ne '}')) {
			my $memberNode = Lib::ParseUtil::tryParse_OrUnknow(\@classContent);
			if (defined $memberNode) {
				Append($classNode, $memberNode);
				# check for Ctor/Dtor
				if (IsKind($memberNode, MethodKind)) {
					my $methName = GetName($memberNode);
					if ($methName =~ /\A~/) {
						SetKind($memberNode, DestructorKind);
					}
					elsif ($methName eq $name) {
						SetKind($memberNode, ConstructorKind);
					}
				}
			}
			Lib::ParseUtil::purgeSemicolon();
		}
		
		if (defined nextStatement()) {
			# trashes the '}'
			getNextStatement();
		}
		else {
			print STDERR "[PARSE] Error : missing closing '}' for class $name\n";
		}

		Lib::ParseUtil::endArtifact($artiKey);
		
		sendContextEvent(CTX_LEAVE);
		
		SetEndline($classNode, getStatementLine());
		
#		my $variables = getVariables($classNode);
#		setCSKindData($classNode, 'local_variables', $variables->[0]);
#		setCSKindData($classNode, 'local_constants', $variables->[1]);
		return $classNode;	
}

##################################################################
#              INTERFACE
##################################################################

sub isNextInterface() {
	if ( ${nextStatement()} eq 'interface' ) {
		return 1;
	}  
	return 0;
}

sub parseInterface() {
	if (isNextInterface()) {
		# trash the interface keyword.
		getNextStatement();
		my $node = parseClassContext(InterfaceKind, 'interface');
		Lib::ParseUtil::purgeSemicolon();
		return $node;
	}
	return undef;
}


##################################################################
#              NAMESPACE
##################################################################

sub isNextNamespace() {
	if ( ${nextStatement()} eq 'namespace' ) {
		return 1;
	}  
	return 0;
}

sub parseNamespace() {
	if (isNextNamespace()) {
		# trash the namespace keyword.
		getNextStatement();
		
		my $namespaceNode = Node(NamespaceKind, createEmptyStringRef());
		
		my $stmt;
		my $name = "";
		while ((defined ($stmt = nextStatement())) && ($$stmt ne '{') && ($$stmt ne ";")) {
			$name .= ${getNextStatement()};
		}
		
		SetName($namespaceNode, $name);
		
		if ($$stmt eq "{") {
			# trash ;
			getNextStatement();
			
			Lib::ParseUtil::parseStatementsBloc($namespaceNode, [\&isNextClosingBrace], \@rootContent, 0); # 0: do notr keep closing
			
			#while (nextStatement() && (${nextStatement()} ne '}')) {
			#	my $memberNode = Lib::ParseUtil::tryParse_OrUnknow(\@classContent);
			#	if (defined $memberNode) {
			#		Append($classNode, $memberNode);
			#	}
			#}
		}
		
		Lib::ParseUtil::purgeSemicolon();
		
		return $namespaceNode;
	}
	return undef;
}

##################################################################
#              CLASS
##################################################################

sub isNextClass() {
	if ( ${nextStatement()} eq 'class' ) {
		return 1;
	}  
	return 0;
}

sub parseClass() {
	if (isNextClass()) {
		# trash the class keyword.
		getNextStatement();
		
		my $node = parseClassContext(ClassKind, 'class');
		Lib::ParseUtil::purgeSemicolon();
		return $node;
	}
	return undef;
}

##################################################################
#              STRUCT
##################################################################

sub isNextStruct() {
	if ( ${nextStatement()} eq 'struct' ) {
		return 1;
	}  
	return 0;
}

sub parseStruct() {
	if (isNextStruct()) {
		# trash the struct keyword.
		getNextStatement();
		
		my $node = parseClassContext(StructKind, 'struct');
		Lib::ParseUtil::purgeSemicolon();
		return $node;
	}
	return undef;
}

##################################################################
#              ENUM
##################################################################

sub isNextEnum() {
	if ( ${nextStatement()} eq 'enum' ) {
		return 1;
	}  
	return 0;
}




# <name> enum {
#      AAA(x, y, z, ...) { <nanonymous class > },
#      ...
#      ZZZ(x, y, z, ...) { <nanonymous class> };
#
#      <standard class content>
#
# }
sub parseEnum() {
	if (isNextEnum()) {
		my $enumNode = Node(EnumKind, createEmptyStringRef());
print "--> ENUM found...\n" if $DEBUG;

		#trash 'enum' keyword
		getNextStatement();
		
		my $statementLine = getStatementLine();
		SetLine($enumNode, $statementLine);
		
#		setCSKindData($classNode, 'indentation', Lib::ParseUtil::getIndentation());
		
		my $proto = '';
		my $item;
		while ((defined ($item = nextStatement())) && ($$item ne '{') ) {
			$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}

		my ($name) = $proto =~ /^\s*(\w+)/sm;
		
		SetStatement($enumNode, \$proto);
		SetName($enumNode, $name);
		
		if (! defined nextStatement()) {
			print STDERR "[PARSE] Error : missing openning '{' for enum $name\n";
		}
		else {
			getNextStatement();
		}

		my $enumContent = "";
		while ((defined ($item=nextStatement())) && ($$item ne ';') && ($$item ne '}')) {
			if ($$item eq "(") {
				Lib::ParseUtil::updateGenericParse(\$enumContent, $enumNode, Lib::ParseUtil::parseParenthesis('(', $TRIGGERS_parseParenthesis));
			}
			elsif ($$item eq "{") {
				#Lib::ParseUtil::updateGenericParse(\$enumContent, $enumNode, Lib::ParseUtil::parseParenthesis('{', $TRIGGERS_parseParenthesis));
				# get the anonymous class ...
				my $anoClass = parseClassContext(AnonymousClassKind, 'anonymous');
				Append($enumNode, $anoClass);
			}
			else {
				$enumContent .= ${getNextStatement()};
			}
		}
		
		if (defined nextStatement()) {
			my $item = ${getNextStatement()};
			
			if ($item eq ";") {
				# parse class content
				
				sendContextEvent(CTX_CLASS);
		
				while (nextStatement() && (${nextStatement()} ne '}')) {
					my $memberNode = Lib::ParseUtil::tryParse_OrUnknow(\@classContent);
					if (defined $memberNode) {
						Append($enumNode, $memberNode);
					}
				}
		
				if (defined nextStatement()) {
					# trashes the '}'
					getNextStatement();
				}
				else {
					print STDERR "[PARSE] Error : missing closing '}' for class $name\n";
				}
				
				sendContextEvent(CTX_LEAVE);
			}
			else {
				# item is '}' => means end of the enum ...
			}
		}
		else {
			print STDERR "[PARSE] Error : unterminated enum $name\n";
		}
	
		SetStatement($enumNode, \$enumContent);

		Lib::ParseUtil::purgeSemicolon();

		return $enumNode;
	}
	return undef;
}

##################################################################
#              MEMBER
##################################################################

sub parseMember() {
	my $proto = '';
	my $stmt;

	my $line = getNextStatementLine();
	
	my $flag_init = 0;

if (${nextStatement()} eq ";") {
	print STDERR "NO MEMBER !!!\n";
}

	my $initNode;

	while ((defined ($stmt = nextStatement())) && ($$stmt ne ';') ) {
		if ($$stmt eq '=') {
			# presence of "=" modify the signification of some item like (, { or =>
			# so, memorize it to change the treatment for these items.
			
			
		#$flag_init = 1;
		#$proto .= ${getNextStatement()};
			getNextStatement();
			$initNode = Node(InitKind, createEmptyStringRef());
			parseExpression($initNode);
			# init expression is ending member statement.
			last;	
		}
		elsif ($$stmt eq '=>') {
			if ($flag_init == 0) {
				last;
			}
			else {
				$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
			}
		}
		elsif ( $$stmt eq '(' ) {
			if (($flag_init == 0) && ($proto ne "")){
				# To have a method, we need :
				# - no "=" encountered before opennenig parenth
				# - a prototype should exist !!
				last;
			}
			else {
				#$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
				$proto .= ${Lib::ParseUtil::parseRawOpenClose()};
			}
		}
		elsif ( $$stmt eq '<' ) {
			my $expr = Lib::ParseUtil::parseUntilPeer("<", ">");
			if (defined $expr) {
				$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.$$expr;
			}
		}
		elsif ( $$stmt eq '[' ) {
			my $expr = Lib::ParseUtil::parseRawOpenClose();
			if (defined $expr) {
				$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.$$expr;
			}
		}	
		elsif ($$stmt eq "{") {
			if ($flag_init == 0) {
				# not a property if "=" has been encountered before
				last;
			}
			else {
				$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
			}
		}
		elsif ( $$stmt eq 'operator' ) {
			# capture operators belonging to the name of the method (>, >=, ...) without interpreting them as syntaxic symbol ..
			while (${nextStatement()} ne '(') {
				$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
			}
		}
		else {
			$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}

		if (! defined $line) {
			$line = getStatementLine();
		}
	}

	if (!defined $stmt ) {
		print STDERR "[PARSE] Error : missing closing '}' for class\n";
	}
	elsif ($$stmt eq '(') {
		my ($name) = $proto =~ /(?:(~?\w+)\s*(?:<[^<>]*>)?\s*$|operator\s*([^\(]+))\s*$/sm;
		
		if (! defined $name) {
			($name) = $proto =~ /\boperator\s*([^\(]+)\s*$/sm;
			
			if (! defined $name) {
				Lib::Log::ERROR("no name inside method proto : $proto\n");
			}
		}

		my $node = parse_Method($name, $line);
		return $node;
	}
	elsif ($$stmt eq '{') {
		# Example of protos for properties :
		# 		public int roro
		#     	public TValue[] this[DateTime time]
		my ($name) = $proto =~ /(\w+)\s*(?:\[[^\[\]]*\])?\s*$/m;
		$line = getStatementLine();
		my $expr = Lib::ParseUtil::parseUntilPeer("{", "}");
		if (defined $expr) {
			$proto = $$expr;
		}
		else {
			$proto = "";
		}
		my $node = Node(PropertyKind, \$proto);
		SetName($node, $name);
		SetLine($node, $line);
		return $node;
	}
	elsif ($$stmt eq '=>') {
		# Example of protos for properties using lambads :
		#		public int Count => memory.Count;
		# 		public T this[int i] => memory[i];
		my ($name) = $proto =~ /(\w+)\s*(?:\[[^\[\]]*\])?\s*$/sm;
#print STDERR "PROTO LAMBDA = $proto\n";
		# trash =>
		getNextStatement();

		my $node = Node(PropertyKind, \$proto);
		SetName($node, $name);
		SetLine($node, $line);
		my $lambda = parse_lambda();
		Append($node, $lambda);
		return $node;
	}
	elsif (($$stmt eq ';') || ($$stmt eq '=')) {
		print "FOUND attribute\n" if $DEBUG;
		# trashes the ";"
		Lib::ParseUtil::purgeSemicolon();
		my $node = CS::ParseVariables::parseVariableDeclaration(\$proto, $line, AttributeKind);
		
		if (! defined $node) {
			$node = Node(UnknowKind, \$proto);
			SetLine($node, $line);
		}
		
		if (defined $initNode) {
			Append($node, $initNode);
		}

		return $node;
	}
	else {
		print STDERR "[ParseCS::parseMember] ERROR : inconsistency encountered when parsing class member ()!!\n";
	}
	
	return undef;
}

sub parseConst() {
	if (${nextStatement()} =~ /\A\s*(const)\b/gc ) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		return parseMember();	
	}
	return undef; 
}

sub parseEvent() {
	if (${nextStatement()} =~ /\A\s*(event)\b/gc ) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		my $eventNode = parseMember();
		SetKind($eventNode, EventKind);
		return $eventNode;
	}
	return undef; 
}

sub parseDelegate() {
	if (${nextStatement()} =~ /\A\s*(delegate)\b/gc ) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		my $delegateNode = parseMember();
		SetKind($delegateNode, DelegateKind);
		return $delegateNode;
	}
	return undef; 
}

##################################################################
#              METHOD
##################################################################

sub parse_MethodBody($) {
	my $methodNode = shift;
	
	my $name = GetName($methodNode);
	my $line = GetLine($methodNode);
	
	my $stmt = nextStatement();
	if (! defined $stmt) {
			print STDERR "[PARSE] Error : missing openning '{' for method $name\n";
	}
	else {
		# trashes the '{', '=>' or ';'
		getNextStatement();
	}
	
	my $args = CS::ParseVariables::parseArguments($methodNode);
	setCSKindData($methodNode, 'arguments', $args);
	my %H_args = ();
	setCSKindData($methodNode, 'H_args', \%H_args);
	for my $arg (@$args) {
		if (! defined $arg->{'name'}) {
			Lib::Log::ERROR("No name for argument at line $arg->{'line'}\n");
		}
		else {
			$H_args{$arg->{'name'}} = $arg;
		}
	}

	sendContextEvent(CTX_METHOD);

	# THERE IS A BODY ONLY AFTER { or =>
	if (($$stmt eq '{') || ($$stmt eq '=>')) {
		# **** presence of a body (not an abstract - virtual pure - method).

		my $beginPos = Lib::ParseUtil::getCodePos();
		my $endPos;
		my $bodyLineBegin = getNextStatementLine();
		setCSKindData($methodNode, 'body_line_begin', $bodyLineBegin);
		
		
		# declare a new artifact
		my $artiKey = Lib::ParseUtil::newArtifact('func_'.$name, $line);
		setCSKindData($methodNode, 'artifact_key', $artiKey);
		

		#		my $lines_in_proto = () = $proto =~ /\n/g;
		#		setCSKindData($methodNode, 'lines_in_proto', $lines_in_proto);
		
		#		Lib::ParseUtil::setArtifactUpdateState(1);
	
		if ($$stmt eq '{') {
			while (nextStatement() && (${nextStatement()} ne '}')) {
				my $node = Lib::ParseUtil::tryParse_OrUnknow(\@methodContent);
				if (defined $node) {
					Append($methodNode, $node);
				}
			}
	
			if (defined nextStatement()) {
				
				# -- END OF ARTIFACT
				Lib::ParseUtil::endArtifact($artiKey);
				# record the end position before the }
				$endPos = Lib::ParseUtil::getCodePos();
		
				# trashes the '}'
				getNextStatement();
			}
			else {
				# -- END OF ARTIFACT
				$endPos = Lib::ParseUtil::getCodePos();
				Lib::ParseUtil::endArtifact($artiKey);
				
				print STDERR "[PARSE] Error : missing closing '}' for method $name\n";
			}
		}
		else {
			my $bodyNode = Lib::ParseUtil::tryParse_OrUnknow(\@methodContent);
			Append($methodNode, $bodyNode);
			
			# -- END OF ARTIFACT
			Lib::ParseUtil::endArtifact($artiKey);
			# record the ending position
			$endPos = Lib::ParseUtil::getCodePos();
		}
		
		setCSKindData($methodNode, 'codeBody', Lib::ParseUtil::getArtifact($artiKey));
		#		my $variables = getVariables($methodNode);
		#		setCSKindData($methodNode, 'local_variables', $variables->[0]);
		#		setCSKindData($methodNode, 'local_constants', $variables->[1]);
		
		Lib::NodeUtil::SetXKindData($methodNode, "position", {"begin" => $beginPos, "end" => $endPos, "length" => $endPos-$beginPos});
	}
	
	my @T_vars = GetNodesByKind($methodNode, VariableKind);
	my %H_vars = ();
	for my $var (@T_vars) {
		$H_vars{GetName($var)} = $var;
	}
	setCSKindData($methodNode, "H_vars", \%H_vars);
		
	sendContextEvent(CTX_LEAVE);
	SetEndline($methodNode, getStatementLine());
	#my $varLst = parseVariableDeclaration($methodNode);
	#setCSKindData($methodNode, 'localVar', $varLst);
	
	#Lib::ParseUtil::purgeSemicolon();
}


sub parse_Method($) {
		my $name = shift;
		my $line = shift;
		
		if (!defined $name) {
			print "[ParseCS::parse_Method] ERROR : undefined name for method at line $line\n";
			$name = "unknow_at_$line";
		}
		my $methodNode = Node(MethodKind, createEmptyStringRef());
print "--> METHOD $name found...\n" if $DEBUG;

		SetLine($methodNode, $line);
		
		# temporary desactive artifact updating: the prototype of the function should not appears in the encompassing (parent) artifact.
		# This to prevent some argument with default values (xxx = ) to be considered as  parent's variable while greping variable in parent's body.
		#Lib::ParseUtil::setArtifactUpdateState(0);

#		setCSKindData($methodNode, 'indentation', Lib::ParseUtil::getIndentation());

		my $proto = '';
		my $stmt;
		while ((defined ($stmt = nextStatement())) && ($$stmt ne '{') && ($$stmt ne '=>') && ($$stmt ne ';')) {
			if ($$stmt eq '(') {
				$proto .= ${Lib::ParseUtil::parseRawOpenClose()};
			}
			else {
				$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
			}
		}

		SetStatement($methodNode, \$proto);
		SetName($methodNode, $name);
		
		# parse body if any ...
		parse_MethodBody($methodNode);
		
		return $methodNode;
}

##################################################################
#              LAMBDA
##################################################################

sub parse_lambda($) {
	my $parentStatement = shift;
	
	if (! defined $parentStatement) {
		$parentStatement = createEmptyStringRef();
	}

	# get parameters of the lambda
	my $parameters = "";
	if ($$parentStatement =~ /(\w+|\([^\(\)]*\))\s*\z/) {
		$parameters = quotemeta $1;

		$$parentStatement =~ s/$parameters\s*$/__lambda__/m;
	}
	
	my $lambdaNode = Node(LambdaKind, createEmptyStringRef());
	SetLine($lambdaNode, getStatementLine());
	
	setCSKindData($lambdaNode, 'parameters', $parameters);
	
	sendContextEvent(CTX_METHOD);
	
	if (${nextStatement()} eq "{") {
		getNextStatement();
		Lib::ParseUtil::parseStatementsBloc($lambdaNode, [\&isNextClosingBrace], \@methodContent, 0); # keepClosing=0
	}
	else {
		my $bodyNode = Lib::ParseUtil::tryParse_OrUnknow(\@methodContent);
		if (defined $bodyNode) {
			Append($lambdaNode, $bodyNode);
		}
		else {
			Lib::Log::ERROR("missing body for lambda at lkine ".getStatementLine);
		}
	}
	
	sendContextEvent(CTX_LEAVE);
	
	return $lambdaNode;
}

##################################################################
#              ANONYMOUS BLOCK
##################################################################

sub isNextBlock() {
	if ( ${nextStatement()} eq '{' ) {
		return 1;
	}  
	return 0;
}

sub parseBlock() {
	if (isNextBlock()) {

		getNextStatement();
		
		sendContextEvent(CTX_METHOD);
		
		my $blocNode = Node(BlockKind, createEmptyStringRef());
		SetLine($blocNode, getNextStatementLine());

		Lib::ParseUtil::parseStatementsBloc($blocNode, [\&isNextClosingBrace], \@methodContent, 0);

		SetEndline($blocNode, getStatementLine());

		sendContextEvent(CTX_LEAVE);

		Lib::ParseUtil::purgeSemicolon();
	
		return $blocNode;
	}

	return undef;
}

##################################################################
#              Fixed
##################################################################

#sub parseFixed() {
#	if (${nextStatement()} =~ /\A\s*fixed\s*\b/) {
#		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
#		
#		my $statement = "";
#		my $fixedNode = Node(FixedKind, \$statement);
#		SetLine($fixedNode, getStatementLine());
#		
#		if (${nextStatement()} eq '(') {
#			$statement .= ${Lib::ParseUtil::parseRawOpenClose()};
#		}
#		
#		my $currentContext = getCurrentContextContent();
#		if (${nextStatement()} eq "{") {
#			getNextStatement();
#			Lib::ParseUtil::parseStatementsBloc($fixedNode, [\&isNextClosingBrace], $currentContext, 0);
#		}
#		else {
#			my $node = Lib::ParseUtil::tryParse_OrUnknow($currentContext);
#			if (defined $node) {
#				Append($fixedNode, $node);
#			}
#		}
#		
#		SetEndline($fixedNode, getStatementLine());
#		
#		return $fixedNode;
#	}
#	return undef;
#}

##################################################################
#              NEW
##################################################################

sub isNextNew() {
	if ( ${nextStatement()} eq 'new' ) {
		return 1;
	}  
	return 0;
}


# new syntax should support :
#	- new typename(...)
#	- new typename<...>(...)			with generic
#	- new typename<...>(...) { ... }	with object or collection initializer
#
#  target-typed 
#	- new (...)
#	- new (...) { ... }	with object or collection initializer
#
#  Array creation 
#	- new type[ ... ]
#	- new type[ ... ] { ... }	with array initialization syntax
#
#  Instanciation of anonymous types
#	- var example = new { Greeting = "Hello", Name = "World" };


sub parseNew() {
	if (isNextNew()) {
		
		my $idx_statement = Lib::ParseUtil::get_idx_statement();
		
		# trash "new" keyword
		getNextStatement();
		
		# check if "new" is used in an class instanciation context.
		# if yes, the new keyword should be followed by a 
		# - class name or 
		# - a type parameter (that is <...>)
		if (${nextStatement()} !~ /^\s*[\w<]/) {
			# not a class instanciation context
			# restore consummed statement ...
			Lib::ParseUtil::set_idx_statement($idx_statement);
			
			# ... and exit
			return undef;
		}
		
		my $name = "";
		my $stmt = "";
		my $expression = "";
		my $line = getStatementLine();
		
		# the statement is unknow ...
		my $newNode = Node(NewKind, createEmptyStringRef());
		SetLine($newNode, $line);

		Lib::ParseUtil::register_SplitPattern(qr/\[/);

		# get the name of the class being instanciated
		while ((defined ($stmt = nextStatement())) && ($$stmt ne "(") &&($$stmt ne ";") && ($$stmt ne "{") && ($$stmt ne "[") && ($$stmt ne "}")) {
			$expression .= ${Lib::ParseUtil::getSkippedBlanks()};
			$expression .= ${getNextStatement()}; 
		}	

		Lib::ParseUtil::release_SplitPattern();

		# get the parameters of the constructor
		if (defined $stmt) {
			
			if ($expression =~ /^\s*([\w:]+)/) {
				$name = $1;
			}
			else {
				$name = "Unknow_new_L$line";
			}
			
			if ($$stmt eq '(') {
				#$expression .= Lib::ParseUtil::parseParenthesis('(');
				Lib::ParseUtil::updateGenericParse(\$expression, $newNode, Lib::ParseUtil::parseParenthesis('(', $TRIGGERS_parseParenthesis));
			}
			elsif ($$stmt eq "[") {
				##########################################     IMPLEMENTER ICI !!!!!!!!!!!!!!!!!!!!!!!!
			}
		}
		
		#else {
		#	print "[parseNew] missing end of new statement started at line $line\n";
		#}

		SetName($newNode, $name);
		
		# if any, get the anonymous class ...
		if (defined nextStatement() and ${nextStatement()} eq "{") {
			$expression .= ${Lib::ParseUtil::parseRawOpenClose()};
			#my $anoClass = parseClassContext(AnonymousClassKind, 'anonymous');
			#Append($newNode, $anoClass);
		}

		# parse the rest of the New instruction.
		#my ($expr, $subNodes) = Lib::ParseUtil::parse_Expression();
		#$expression .= $$expr;

		SetStatement($newNode, \$expression);

		# if the expression parsing has created some nodes, then append them ...
		#for my $subNode (@$subNodes) {
		#	Append($newNode, $subNode);
		#}

		return $newNode;
	}

	return undef;
}

##################################################################
#              ROOT
##################################################################
sub parseRoot() {
	my $root = Node(RootKind, \$NullString);

	SetName($root, 'root');

	#my $artiKey=Lib::ParseUtil::newArtifact('root');
	#setCSKindData($root, 'artifact_key', $artiKey);

	while ( defined nextStatement() ) {
		my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);
		if (defined $subNode) {
			Append($root, $subNode);
		}
	}

	return $root;
}

#
# Split a JS buffer into statement separated by structural token
# 

sub splitCS($) {
   my $r_view = shift;

   my  @statements = split /(\n|;|\?|:|\(|\)|\{|\}|\[|\]|=>|=|<<|>>|<|>|\b(?:namespace|class|interface|struct|enum|interface|if|else|else\s+if|while|for|foreach|do|switch|case|default|try|catch|finally|break|continue|new|throw|lock|operator)\b|(?:(?:$re_MODIFIERS\b\s*)+))/sm, $$r_view;
   
   if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }
   return \@statements;
}


sub ParseCS($) {
  my $r_view = shift;
  
  my $r_statements = splitCS($r_view);

  # only spaces and tabs will be considered as blanks in a statement (\n are considered as SEPARATORS)
  #Lib::ParseUtil::setBlankRegex('[ \t]');

  Lib::ParseUtil::InitParser($r_statements);
  # triggers for parse_Parenthesis
  Lib::ParseUtil::register_TRIGGERS_parseParenthesis($TRIGGERS_parseParenthesis);
  # trigger for parse_Expression
  Lib::ParseUtil::register_Expression_TriggeringItems($Expression_TriggeringItems);
  
  # pass all beginning empty lines
# while (${nextStatement()} eq "\n") {
#	getNextStatement();
#  }

  #$ExpressionLevel = 0;
  initContext();
  
  # init to the indentation of the first instruction
  #sendContextEvent("new indent", Lib::ParseUtil::getNextIndentation());

  # Mode LAST (no inclusion) for artifact consolidation.
  Lib::ParseUtil::setArtifactMode(1);
  
  my $root = parseRoot();
  my $Artifacts = Lib::ParseUtil::getArtifacts();

  return ($root, $Artifacts);
}



###################################################################################
#              MAIN
###################################################################################

sub preComputeListOfKinds($$$) {
	my $node = shift;
	my $views = shift;
	my $kinds = shift;
  
	my %H_KindsLists = ();
  
	for my $kind (@$kinds) {
		my @NodesList = GetNodesByKind($node, $kind );
		$H_KindsLists{$kind}=\@NodesList;
	}

	$views->{'KindsLists'} = \%H_KindsLists;
}

# description: CS parse module Entry point.
sub Parse($$$$)
{
	my ($fichier, $vue, $couples, $options) = @_;
	
	my $status = 0;

	$StringsView = $vue->{'HString'};

	Lib::ParseUtil::registerParseUnknow(\&parseUnknow);

#    my $statements =  $vue->{'statements_with_blanks'} ;

	#$vue->{'code'} =~ s/^\s*\#.*$//mg;

	# launch first parsing pass : strutural parse.
	
	#/!\ CHANGING THE VIEW NEED TO CHANGE THE VIEW IN ALL ALGO THAT USE THE INDEXING POSITION !!!!!
	my ($CSNode, $Artifacts) = ParseCS(\$vue->{'code'});

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";


	if (defined $options->{'--print-tree'}) {
		Lib::Node::Dump($CSNode, *STDERR, "ARCHI");
	}
	if (defined $options->{'--print-test-tree'}) {
		print STDERR ${Lib::Node::dumpTree($CSNode, "ARCHI")} ;
	}

	$vue->{'structured_code'} = $CSNode;
	$vue->{'artifact'} = $Artifacts;

	# pre-compute some list of kinds :
	preComputeListOfKinds($CSNode, $vue, [MethodKind, ConstructorKind, DestructorKind, ClassKind, ImportKind, ConditionKind, WhileKind, ForKind, ForeachKind, IfKind, CatchKind, TryKind, FinallyKind, CaseKind, DefaultKind, SwitchKind, AttributeKind, VariableKind, InterfaceKind, EnumKind, TernaryKind]);

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

