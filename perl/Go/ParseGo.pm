package Go::ParseGo;
# les modules importes
use strict;
use warnings;

use Erreurs;

use CountUtil;

use Lib::Node; # qw( Leaf Node Append );
use Lib::NodeUtil ;
use Lib::NodeUtil qw( SetName SetStatement SetLine GetLine SetEndline GetEndline);
use Lib::ParseUtil;

use Go::GoNode;
use CountUtil;

my $DEBUG = 1;

my @rootContent = (
	\&parsePackage,
	\&parseImport,
	\&parseVar,      # VAR, TYPE, CONST
	\&parseFunction,
	\&parseStruct,
	\&parseInterface,
);

my @routineContent = (
	\&parseLabel,
	\&parseVar,      # VAR, TYPE, CONST
	\&parseIf,
	\&parseFor,
	\&parseReturn,
	\&parseContinue,
	\&parseBreak,
	\&parseSwitchOrSelect,
	\&parseDefer,
	\&parseGo,
	\&parsePanic,
	\&parseGoto,
	\&parseFallthrough,
);

my @expressionContent = (
	\&parseParenthesis,
	\&parsePairing,
	\&parseIf,
	\&parseFor,
	\&parseReturn,
	\&parseContinue,
	\&parseBreak,
	\&parseSwitchOrSelect,
	\&parseDefer,
	\&parseGo,
	\&parsePanic,
	\&parseGoto,
	\&parseFallthrough,
	\&parseFunction, # for var or type declaration
	\&parseStruct, # for var or type declaration
	\&parseInterface, # for var or type declaration
	\&parseMap, # for var or type declaration
	\&parseMake, # for var or type declaration
);

my $GO_SEPARATOR = '(?:[;\n\(\)\{\}])';

my $NEVER_A_STATEMENT_BEGINNING_PATTERNS = '(?:\&\&|\&\=|\&|\+\=|\+|\=\=|\!\=|\-\=|\-\-|\-|\|\=|\|\||\||\<\=|\<|\[|\]|\*\=|\*|\^\=|\^|\<\-|\>|\>\=|\/|\<\<|\/\=|\<\<\=|\=|\:\=|\,|\%|\>\>|\%\=|\>\>\=|\!|\.\.\.|\.|\:|\&\^|\&\^\=)';
my $NEVER_A_STATEMENT_ENDING_PATTERNS = '(?:\+\=|\+\+|\+|\&\=|\&\^\=|\&\^|\&\&|\&|\=\=|\=|\!\=|\-\=|\-\-|\-|\|\=|\|\||\||\<|\<\=|\[|\*|\^|\*\=|\^\=|\<\-|\>\=|\>|\<\<|\/\=|\/|\<\<\=|\:\=|\,|\%|\>\>|\%\=|\>\>\=|\!|\.\.\.|\.|\:)';
my $STRUCTURAL_STATEMENTS = '(?<!\$)\b(?:func|struct|interface)\b';
my $CONTROL_FLOW_STATEMENTS = '(?<!\$)(?:\b(?:break|case|const|continue|default|defer|else|fallthrough|for|go|goto|if|import|map|make|package|panic|range|return|select|switch|type|var|const)\b)';
my $STATEMENT_BEGINNING_PATTERNS = '(?:\+\+|\-\-)';
my %H_CLOSING = ( '{' => '}', '[' => ']', '<' => '>', '(' => ')' );

my $NullString = '';

my $StringsView = undef;

sub isNextNewLine() {
	if ( defined nextStatement() && ${nextStatement()} eq "\n") {
		return 1;
	}

	return 0;
}

sub isNextOpenningParenthesis() {
	if ( defined nextStatement() && ${nextStatement()} eq '(' ) {
		return 1;
	}

	return 0;
}

sub isNextClosingParenthesis() {
    if ( defined nextStatement() && ${nextStatement()} eq ')' ) {
    return 1;
  }

  return 0;
}

sub parseParenthesis() {

  if (isNextOpenningParenthesis()) {

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

	getNextStatement();

    # parse the parenthesis content
    my $parentNode = Node(ParenthesisKind, createEmptyStringRef());

    SetLine($parentNode, getStatementLine());

    parseExpression($parentNode, [\&isNextClosingParenthesis]);

    if ((defined nextStatement()) && (${nextStatement()} eq ')')) {
      # consumes the closing ')'
      getNextStatement();
    }

    SetEndline($parentNode, getStatementLine());

    SetName($parentNode, "PARENT".Lib::ParseUtil::getUniqID());

    return $parentNode;
  }

  return undef;
}

sub isNextPairing {
	if (defined nextStatement() && ${nextStatement()} =~ /^([\{\(\[])$/m) {
		my $pattern = $1;
		return $pattern;
	}

	return 0;
}

sub parsePairing() {
	if (my $opening = isNextPairing) {

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

sub isNextOpenningAcco() {
	if ( defined nextStatement() && ${nextStatement()} eq '{' ) {
		return 1;
	}

	return 0;
}

sub isNextClosingAcco() {
	if ( defined nextStatement() && ${nextStatement()} eq '}' ) {
		return 1;
	}

	return 0;
}

sub parseAccoBloc() {

	my $accoNode = undef;

	if (isNextOpenningAcco()) {

		# Consumes the '{' token.
		getNextStatement();
		purgeLineReturn();
		# parse the braces content
		$accoNode = Lib::ParseUtil::parseCodeBloc(AccoKind, [\&isNextClosingAcco], \@routineContent, 0, 0 ); # keepClosing:0, noUnknowNode:0
	}

	purgeLineReturn();
	return $accoNode;
}

##################################################################
#              PACKAGE
##################################################################

sub isNextPackage() {
	if ( defined nextStatement() && ${nextStatement()} eq 'package' ) {
		return 1;
	}
	return 0;
}

sub parsePackage() {
	if (isNextPackage()) {
		# consumes package
		getNextStatement();

		my $statement = "";
		my $packageNode = Node(PackageKind, \$statement);

		SetLine($packageNode, getStatementLine());

		my $stmt;
		while ((defined ($stmt=nextStatement())) && ($$stmt ne "\n")) {
			$statement .= ${getNextStatement()};
		}

		purgeLineReturn();
		return $packageNode;
	}
	return undef;
}

##################################################################
#              IMPORT
##################################################################

sub isNextImport() {
	if ( defined nextStatement() && ${nextStatement()} eq 'import' ) {
		return 1;
	}
	return 0;
}

sub parseImport() {
	if (isNextImport()) {
		# consumes import
		getNextStatement();

		my $statement = "";
		my $endingParse = "\n";
		my $importNode = Node(ImportKind, \$statement);

		SetLine($importNode, getStatementLine());

		if (defined nextStatement() && ${nextStatement()} eq '(') {
			$statement .= ${getNextStatement()};
			$endingParse = ')';
		}
		my $stmt;
		while ((defined ($stmt=nextStatement())) && ($$stmt ne $endingParse)) {
			$statement .= ${getNextStatement()};
		}
		if (defined nextStatement() && ${nextStatement()} eq ')') {
			$statement .= ${getNextStatement()};
		}

		purgeLineReturn();
		return $importNode;
	}
	return undef;
}

##################################################################
#              RETURN
##################################################################

sub isNextReturn() {
    if ( defined nextStatement() && ${nextStatement()} eq 'return' ) {
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

		parseExpression($returnNode, [\&isNextClosingAcco]);

		purgeLineReturn();
		return $returnNode;
	}
	return undef;
}

##################################################################
#              FOR
##################################################################

sub isNextFor() {
	if ( defined nextStatement() && ${nextStatement()} eq 'for' ) {
		return 1;
	}
	return 0;
}

sub parseFor() {
	if (isNextFor()) {
		my $ForNode = Node(ForKind, createEmptyStringRef());
		my $stmt;
		my $ForCondNode = Node(ConditionKind, \$stmt);

		SetLine($ForNode, getStatementLine());

		# Consumes the 'for' keyword
		getNextStatement();

		# CONDITION CLAUSE
		# ----------------
		while (defined nextStatement() && ${nextStatement()} ne '{') {
			if (defined nextStatement() && ${nextStatement()} eq "\n") {
				$stmt .= ${getNextStatement()};
				# exit if condition is not ending with a digit, ';', '&' or '|'
				last if $stmt !~ /[0-9;&|]\s*$/m;
			}
			else {
				$stmt .= ${getNextStatement()};
			}
		}
		Append($ForNode, $ForCondNode);

		# parse body
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			Append($ForNode, parseAccoBloc());
		}
		else {
			print STDERR "[parseFor] ERROR : missing accolades opened at line ".getStatementLine()."\n";
			# Append($ForNode, Lib::ParseUtil::tryParse_OrUnknow(\@routineContent));
		}

		return $ForNode;
	}
	return undef;
}

##################################################################
#              CONTINUE
##################################################################

sub isNextContinue() {
	if (defined nextStatement() && ${nextStatement()} eq 'continue') {
		return 1;
	}
	return 0;
}

sub parseContinue() {
	if (isNextContinue()) {
		# consumes 'continue' keyword
		getNextStatement();

		my $prototype;
		# label
		if (defined nextStatement() && ${nextStatement()} ne "\n") {
			$prototype = ${getNextStatement()};
		}

		my $continueNode = Node(ContinueKind, \$prototype);
		SetLine($continueNode, getStatementLine());

		purgeLineReturn();
		return $continueNode;
	}
	return undef;
}

##################################################################
#              BREAK
##################################################################

sub isNextBreak() {
	if (defined nextStatement() && ${nextStatement()} eq 'break') {
		return 1;
	}
	return 0;
}

sub parseBreak() {
	if (isNextBreak()) {
		# consumes 'break' keyword
		getNextStatement();

		my $prototype;
		# label
		if (defined nextStatement() && ${nextStatement()} ne "\n") {
			$prototype = ${getNextStatement()};
		}

		my $breakNode = Node(BreakKind, \$prototype);
		SetLine($breakNode, getStatementLine());

		purgeLineReturn();
		return $breakNode;
	}
	return undef;
}

##################################################################
#              SWITCH / SELECT
##################################################################

sub isNextSwitch() {
	if (defined nextStatement() &&  ${nextStatement()} eq 'switch') {
		return 1;
	}
	return 0;
}

sub isNextSelect() {
	if (defined nextStatement() &&  ${nextStatement()} eq 'select') {
		return 1;
	}
	return 0;
}

sub parseSwitchOrSelect($) {
	if (isNextSwitch() || isNextSelect) {

		my $switchOrSelectNode;

		$switchOrSelectNode = Node(SwitchKind, createEmptyStringRef) if isNextSwitch();
		$switchOrSelectNode = Node(SelectKind, createEmptyStringRef) if isNextSelect();

		# consumes the 'switch' statement
		getNextStatement();
		purgeLineReturn();

		SetLine($switchOrSelectNode, getStatementLine());

		if (defined nextStatement() && ${nextStatement()} ne '{') {
			Append($switchOrSelectNode, parseCondition());
		}

		if (defined nextStatement() && ${nextStatement()} eq '{') {

			# consumes the '{'
			getNextStatement();
			purgeLineReturn();

			while (defined nextStatement() && ${nextStatement()} ne '}') {
				if (isNextCase()) {
					Append($switchOrSelectNode, parseCaseOrDefault());
				}
				elsif (isNextDefault()) {
					Append($switchOrSelectNode, parseCaseOrDefault());
				}
				else {
					print STDERR "[parseSwitchOrSelect] unexpected statement at line ".GetLine($switchOrSelectNode)."\n";
					last;
				}
			}
			# consumes the '}'
			if (defined nextStatement() && ${nextStatement()} eq '}') {
				getNextStatement();
				purgeLineReturn();
			}
		}
		else {
			print STDERR "[parseSwitchOrSelect] missing accolades opened at line ".GetLine($switchOrSelectNode)."\n";
		}

		return $switchOrSelectNode;
	}

	return undef;
}

##################################################################
#              CASE / DEFAULT
##################################################################

sub isNextCase() {
	if ( defined nextStatement() && ${nextStatement()} eq 'case' ) {
		return 1;
	}

	return 0;
}

sub isNextDefault() {
	if ( defined nextStatement() && ${nextStatement()} eq 'default' ) {
		return 1;
	}

	return 0;
}

sub isNextDoubleEqual() {
	if ( defined nextStatement() && ${nextStatement()} eq '==' ) {
		return 1;
	}

	return 0;
}

sub isNextSemicolon() {
	if ( defined nextStatement() && ${nextStatement()} eq ':' ) {
		return 1;
	}

	return 0;
}

sub isNextComma() {
	if ( defined nextStatement() && ${nextStatement()} eq ',' ) {
		return 1;
	}

	return 0;
}

sub parseCaseOrDefault() {
	if (isNextCase() || isNextDefault()) {

		my $caseOrDefaultNode;
		$caseOrDefaultNode= Node(CaseKind, createEmptyStringRef) if isNextCase();
		$caseOrDefaultNode= Node(DefaultKind, createEmptyStringRef) if isNextDefault();

		# consumes the 'case' keyword
		getNextStatement();
		SetLine($caseOrDefaultNode, getStatementLine());

		# parse the condition of the case
		my $stmt;
		my $caseCondition = Node(ConditionKind, \$stmt);
		my $enclosedParenthesis = 0;
		if (defined nextStatement() && ${nextStatement()} ne ':') {
			while (defined nextStatement()
				&& (${nextStatement()} ne ':'
					|| (${nextStatement()} eq ':' && $enclosedParenthesis > 0)
					|| $enclosedParenthesis == 1)) {
				last if (defined nextStatement() && ${nextStatement()} eq ';');
				if (defined nextStatement() && ${nextStatement()} =~ /\(|\{|\[/) {
					$enclosedParenthesis++;
				}
				elsif (defined nextStatement() && ${nextStatement()} =~ /\)|\}|\]/) {
					$enclosedParenthesis--;
				}
				$stmt .= ${getNextStatement()};
			}
			Append($caseOrDefaultNode, $caseCondition);
		}

		if (defined nextStatement() && ${nextStatement()} eq ':') {
			# consumes :
			getNextStatement();
			purgeLineReturn();
			while (defined nextStatement()
				&& ${nextStatement()} ne 'case'
				&& ${nextStatement()} ne 'default'
				&& ${nextStatement()} ne '}') {

				my $nodeExpression = Lib::ParseUtil::tryParse_OrUnknow(\@routineContent);
				if (defined $nodeExpression) {
					Append($caseOrDefaultNode, $nodeExpression);
				}
			}
		}
		else {
			print STDERR "[parseCaseOrDefault] Missing condition for case statement at line ".GetLine($caseOrDefaultNode)."\n";
		}

		SetEndline($caseOrDefaultNode, getStatementLine());
		purgeLineReturn();
		return $caseOrDefaultNode;
	}
	return undef;
}

##################################################################
#              FALLTHROUGH
##################################################################

sub isNextFallthrough() {
	if (defined nextStatement() && ${nextStatement()} eq 'fallthrough') {
		return 1;
	}
	return 0;
}

sub parseFallthrough() {
	if (isNextFallthrough()) {

		# consumes 'break' keyword
		my $prototype = ${getNextStatement()};

		my $fallthroughNode = Node(FallthroughKind, \$prototype);
		SetLine($fallthroughNode, getStatementLine());

		purgeLineReturn();
		return $fallthroughNode;
	}
	return undef;
}

##################################################################
#              DEFER
##################################################################

sub isNextDefer() {
	if (defined nextStatement() && ${nextStatement()} eq 'defer') {
		return 1;
	}
	return 0;
}

sub parseDefer() {
	if (isNextDefer()) {

		# consumes 'defer' keyword
		my $prototype = ${getNextStatement()};

		my $deferNode = Node(DeferKind, \$prototype);
		SetLine($deferNode, getStatementLine());

		my $nodeExpression = Lib::ParseUtil::tryParse_OrUnknow(\@expressionContent);
		Append($deferNode, $nodeExpression);

		purgeLineReturn();
		return $deferNode;
	}
	return undef;
}

##################################################################
#              PANIC
##################################################################

sub isNextPanic() {
	if (defined nextStatement() && ${nextStatement()} eq 'panic') {
		return 1;
	}
	return 0;
}

sub parsePanic() {
	if (isNextPanic()) {

		# consumes 'panic' keyword
		my $prototype = ${getNextStatement()};

		my $panicNode = Node(PanicKind, \$prototype);
		SetLine($panicNode, getStatementLine());

		parseExpression($panicNode, [\&isNextClosingParenthesis]);

		purgeLineReturn();
		return $panicNode;
	}
	return undef;
}

##################################################################
#              GO
##################################################################

sub isNextGo() {
	if (defined nextStatement() && ${nextStatement()} eq 'go') {
		return 1;
	}
	return 0;
}

sub parseGo() {
	if (isNextGo()) {

		# consumes 'go' keyword
		my $prototype = ${getNextStatement()};

		my $goNode = Node(GoKind, \$prototype);
		SetLine($goNode, getStatementLine());

		my $nodeExpression = Lib::ParseUtil::tryParse_OrUnknow(\@expressionContent);
		Append($goNode, $nodeExpression);

		purgeLineReturn();
		return $goNode;
	}
	return undef;
}

##################################################################
#              GOTO
##################################################################

sub isNextLabel() {
	if (defined nextStatement() && ${nextStatement()} =~ /\w+/
		&& defined nextStatement(1) && ${nextStatement(1)} eq ':') {
		return 1;
	}
	return 0;
}

sub isNextGoto() {
	if (defined nextStatement() && ${nextStatement()} eq 'goto') {
		return 1;
	}
	return 0;
}

sub parseLabel() {
	if (isNextLabel()) {

		# consumes 'label' keyword
		my $prototype = ${getNextStatement()};

		my $labelNode = Node(LabelKind, \$prototype);
		SetLine($labelNode, getStatementLine());

		purgeLineReturn();
		# consumes :
		getNextStatement();
		purgeLineReturn();

		return $labelNode;
	}
	return undef;
}

sub parseGoto() {
	if (isNextGoto()) {

		# consumes 'goto' keyword
		my $prototype;
		# label
		if (defined nextStatement() && ${nextStatement()} ne "\n") {
			$prototype = ${getNextStatement()};
		}

		my $gotoNode = Node(GotoKind, \$prototype);
		SetLine($gotoNode, getStatementLine());

		SetStatement($gotoNode, ${getNextStatement()});

		purgeLineReturn();
		return $gotoNode;
	}
	return undef;
}

##################################################################
#              CONDITION
##################################################################

sub parseCondition() {
	my $stmt;
    my $condNode = Node(ConditionKind, \$stmt);
	my $bool_parenthesis = 0;

 	# Consumes the opening parenthesis of the condition.
    if (defined ${nextStatement()} && ${nextStatement()} eq '('){
        getNextStatement();
		$bool_parenthesis = 1;
    }

	# Different behavior according if or switch nodes
	my $idxOpeningAcco = simulateParseCondition();

	my $idx_nonBlank = 0;
	while (defined nextStatement() && defined $idxOpeningAcco && defined $idx_nonBlank
			&& $idx_nonBlank < $idxOpeningAcco) {

		# Fix a tolerance < 5
		last if (${nextStatement()} eq '{' && $idxOpeningAcco - $idx_nonBlank < 5);
		$stmt .= ${getNextStatement()};

		# detect char non blank
		while (${nextStatement()} =~ /^[\s]+$/m) {
			$stmt .= ${getNextStatement()};
		}

		$idx_nonBlank++;
	}

	# Consumes the closing parenthesis of the condition.
	if ($bool_parenthesis == 1) {
		$stmt =~ s/\)$//;
	}

	purgeLineReturn();
    return $condNode;
}

sub simulateParseCondition() {
	my $idx = 0;
	my $idx_nonblank = 0;
	my $idxOpeningAcco = 0;
	my $previousStmt;
	my $enclosedParenthesis = 0;
	# fix limit to avoid infinite loop issue
	my $threshold = 500;

	my $endingPattern = qr /^\n+$/m;

	while ((defined nextStatement($idx) && ((${nextStatement($idx)} !~ $endingPattern
			&& $idxOpeningAcco <= $threshold) || $enclosedParenthesis > 0))) {

		# detect char non blank
		if (defined nextStatement($idx) && ${nextStatement($idx)} !~ /^[\s]+$/m
			&& ${nextStatement($idx)} ne "") {
			$idx_nonblank++;
			$previousStmt = ${nextStatement($idx)};
		}

		if (defined nextStatement($idx) && ${nextStatement($idx)} eq '{') {
			$idxOpeningAcco = $idx_nonblank;
		}
		elsif (defined nextStatement($idx) && ${nextStatement($idx)} eq '(') {
			$enclosedParenthesis++;
		}
		elsif (defined nextStatement($idx) && ${nextStatement($idx)} eq ')') {
			$enclosedParenthesis--;
		}

		# operators [&& || + , == !=] can concatenate conditions
		# or if previous statement is ending by digit => following \n is allowed
		if (defined $previousStmt && $previousStmt =~ /&&|\|\||\+|\,|\=\=|\!\=|CHAINE_[0-9]+$/m) {
			my $idx_next = $idx + 1;
			while (${nextStatement($idx_next)} =~ /^[\t ]+$/m || ${nextStatement($idx_next)} eq "") {
				$idx_next++;
			}

			if (defined nextStatement($idx_next) && ${nextStatement($idx_next)} eq "\n") {
				$idx = $idx_next;
			}
		}
		$idx++;
	}

	# Fix limit to avoid infinite condition
	if ($idxOpeningAcco > 0) {
		return $idxOpeningAcco;
	}
	return undef;
}

##################################################################
#              IF
##################################################################

sub isNextIf() {
	if ( defined nextStatement() && ${nextStatement()} eq 'if' ) {
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
		SetLine($thenNode, getStatementLine());

		Append($ifNode, $thenNode);

		if ((defined nextStatement()) && (${nextStatement()} ne 'else')) {
			if (${nextStatement()} eq '{') {
				Append($thenNode, parseAccoBloc());
			}
			else {
				print STDERR "[parseIf] ERROR : missing opening { at line ".getStatementLine()."\n";
			}
		}
		SetEndline($thenNode, getStatementLine());

		# parse else branch
		if (defined nextStatement() && ${nextStatement()} eq 'else') {
			my $elseNode = Node(ElseKind, createEmptyStringRef);
			SetLine($elseNode, getStatementLine());

			Append($ifNode, $elseNode);

			# consumes the "else" token.
			getNextStatement();

			if (defined nextStatement() && ${nextStatement()} eq '{') {
				Append($elseNode, parseAccoBloc());
			}
			else {
				if (defined nextStatement() && ${nextStatement()} ne 'if') {
					print STDERR "[parseIf] ERROR : missing opening { at line ".getStatementLine()."\n";
				}
				Append($elseNode, Lib::ParseUtil::tryParse_OrUnknow(\@routineContent));
			}
		}

    	return $ifNode;
  	}

  	return undef;
}

##################################################################
#              TYPE VAR
##################################################################

#sub isNextTypeVariable() {
#	if ( defined nextStatement() && defined nextStatement(1) && defined nextStatement(2)
#		&& ((${nextStatement()} eq '*' || ${nextStatement()} eq '&')
#		&& (
#			(${nextStatement(1)} eq '[' || ${nextStatement(2)} eq '[')
#			|| (${nextStatement(1)} =~ /^\b(u?int[0-9]*|float[0-9]*|byte|rune|bool|string)\b$/
#			|| ${nextStatement(2)} =~ /^\b(u?int[0-9]*|float[0-9]*|byte|rune|bool|string)\b$/)
#			)
#		|| ${nextStatement()} eq '['
#		|| ${nextStatement()} =~ /^\b(u?int[0-9]*|float[0-9]*|byte|rune|bool|string)\b$/)) {
#		return 1;
#	}
#
#	return 0;
#}

# TODO: parseTypeVariable not used for parsing but may be used for future diags?
#sub parseTypeVariable {
#
#	if (isNextTypeVariable()) {
#
#		my $type;
#		while (defined nextStatement() && ${nextStatement()} =~ /(\&|\*)|(\[|\])|\b(u?int[0-9]*|float[0-9]*|byte|rune|bool|string)\b/g) {
#			if (defined $1) {
#				$type = "[ptr]" if ($1 eq '*');
#				$type = "[addr]" if ($1 eq '&');
#				getNextStatement();
#			}
#			elsif (defined $2) {
#				$type .= "[array]";
#				getNextStatement();
#				getNextStatement();
#			}
#			elsif (defined $3) {
#				$type .= $3;
#				getNextStatement();
#			}
#		}
#		return $type;
#	}
#	return undef;
#}

##################################################################
#              VARIABLES
##################################################################

sub isNextVariable() {
	if ( defined nextStatement() && defined nextStatement(1)
		&& (${nextStatement()} eq 'var'
		|| ${nextStatement()} eq 'type'
		|| ${nextStatement()} eq 'const'
		|| ${nextStatement(1)} eq ':=')) {
		return 1;
	}
	# multi var declaration on one line (limit to 10 statements)
	elsif (defined nextStatement(1) && ${nextStatement(1)} eq ',') {
		my $idx = 0;
		while (defined nextStatement($idx) && $idx <= 10) {
			if (${nextStatement($idx)} eq ':=') {
				return 2;
			}
			$idx++;
		}
	}

	return 0;
}

sub parseVar() {
	if (my $resultNextVar = isNextVariable()) {
		my $statement = "";
		my $varNode;
		my $kindVar;

		# consumes var / type / constant
		if (defined nextStatement() && ${nextStatement()} eq 'type') {
			getNextStatement();
			$varNode = Node(TypeKind, \$statement);
			if (defined nextStatement() && ${nextStatement()} ne '(') {
				my $name = ${getNextStatement()};
				$name =~ s/\s+//g;
				SetName($varNode, $name);
			}
			$kindVar = TypeKind;
		}
		elsif (defined nextStatement() && ${nextStatement()} eq 'var') {
			getNextStatement();
			$varNode = Node(VarKind, \$statement);
			if (defined nextStatement() && ${nextStatement()} ne '(') {
				my ($name, $type);
				if (defined nextStatement() && ${nextStatement()} =~ /(\w+)\s+(\w+)/) {
					$name = $1;
					$type = $2;
					Lib::NodeUtil::SetXKindData($varNode, "type", $type);
					getNextStatement();
				}
				else {
					$name = ${getNextStatement()};
				}
				$name =~ s/\s+//g;
				SetName($varNode, $name);
			}
		}
		elsif (defined nextStatement() && ${nextStatement()} eq 'const') {
			getNextStatement();
			$varNode = Node(ConstantKind, \$statement);
			if (defined nextStatement() && ${nextStatement()} ne '(') {
				my $name = ${getNextStatement()};
				$name =~ s/\s+//g;
				SetName($varNode, $name);
			}
			$kindVar = ConstantKind;
		}
		elsif ($resultNextVar == 2) {
			$varNode = Node(VarKind, \$statement);
			my $name = ${getNextStatement()};
			$name =~ s/\s+//g;
			SetName($varNode, $name);
		}
		# var keyword is not defined
		elsif (defined nextStatement(1) && ${nextStatement(1)} eq ':=') {
			$varNode = Node(VarKind, \$statement);
		}

		SetLine($varNode, getStatementLine());

		if (defined nextStatement() && ${nextStatement()} eq '(') {
			# consumes (
			getNextStatement() if ${nextStatement()} eq '(';
			#print "multivar at line ".getStatementLine()."\n";
			purgeLineReturn();
			parseMultiSetVar($varNode);
		}
		elsif (defined nextStatement() && ${nextStatement()} eq ',') {
			#print "multivar list at line ".getStatementLine()."\n";
			parseMultiVarList($varNode);
		}
		else  {
			#print "simple var at line ".getStatementLine()."\n";
			my $nameVar = GetName($varNode);
			my $typeVar = Lib::NodeUtil::GetXKindData($varNode, 'type') || "";
			$varNode = parseSimpleVar($nameVar, $typeVar);
			if (defined $kindVar) {
				SetKind($varNode, $kindVar);
			}
		}

		purgeLineReturn();
		return $varNode;

	}
	return undef;
}

sub parseSimpleVar(;$;$) {
	my $nameVar = shift;
	my $typeVar = shift;
	my $stmt = "";
	my $varSimpleNode = Node(VarKind, \$stmt);
	my $currentLine = getStatementLine();
	my $type = "";
	my $flagInit = 0;

	SetName ($varSimpleNode, $nameVar) if defined $nameVar;
	SetLine ($varSimpleNode, $currentLine);

	if (defined $typeVar && $typeVar ne "") {
		Lib::NodeUtil::SetXKindData($varSimpleNode, "type", $typeVar);
	}

	my $name;
	while (defined nextStatement() && ${nextStatement()} ne "\n"
		&& ${nextStatement()} ne ';' && ${nextStatement()} ne '}') {
		if (defined nextStatement() && ${nextStatement()} =~ /(\w+)\s+(\w+)/) {
			$name = $1;
			$name =~ s/\s+//g;
			SetName($varSimpleNode, $name);
			SetLine($varSimpleNode, $currentLine);
			my $oldType = Lib::NodeUtil::GetXKindData($varSimpleNode, 'type') || "";
			Lib::NodeUtil::SetXKindData($varSimpleNode, "type", $oldType.$2);
			getNextStatement();
		}
		elsif (defined nextStatement(1) && ${nextStatement(1)} =~ /^:?\=$/m) {
			$name = ${getNextStatement()};
			$name =~ s/\s+//g;
			SetName($varSimpleNode, $name);
			SetLine($varSimpleNode, $currentLine);
		}
		elsif (defined nextStatement() && ${nextStatement()} =~ /^(:?\=)$/m) {
			Append($varSimpleNode, Node(InitKind, $1));
			getNextStatement();
			$flagInit = 1;
		}
		elsif (defined nextStatement() && ${nextStatement()} =~ /(\*|\&)/) {
			if (${nextStatement()} eq '*') {
				$type = '[ptr]';
			}
			elsif (${nextStatement()} eq '&') {
				$type = '[addr]';
			}
			getNextStatement();
		}
		elsif (isNextFunction() || isNextStruct() || isNextInterface() || isNextMap() || isNextMake()) {
			my $nodeExpression = Lib::ParseUtil::tryParse_OrUnknow(\@expressionContent);
			Lib::NodeUtil::SetXKindData($nodeExpression, "type", $type) if ($type);
			$type = "";
			Append($varSimpleNode, $nodeExpression);
			last;
		}
		elsif (defined nextStatement(1) && ${nextStatement(1)} eq '{') {
			parseExpression($varSimpleNode, [\&isNextClosingAcco]);
			last;
		}
		elsif (defined nextStatement() && ${nextStatement()} eq '[') {
			$type .= '[array]';
			my ($type_array, $indice_values, $stmt_values, $routineNode) = parseArray();
			$type .= $type_array if (defined $type_array);

			# if return routine node
			if (defined $routineNode) {
				Append($varSimpleNode, $routineNode);
			}

			Lib::NodeUtil::SetXKindData($varSimpleNode, "indice_values", $indice_values) if (defined $indice_values);
			Lib::NodeUtil::SetXKindData($varSimpleNode, "array_values", $stmt_values) if (defined $stmt_values);
		}
		elsif (defined $name && $flagInit == 0) {
			$type .= ${getNextStatement()};
		}
		else {
			parseExpression($varSimpleNode, [\&isNextSemicolon, \&isNextNewLine]);
		}
	}

	if (defined $type && $type ne "") {
		Lib::NodeUtil::SetXKindData($varSimpleNode, "type", $type);
	}

	if (defined $stmt) {
		SetStatement($varSimpleNode, $stmt);
	}

	return $varSimpleNode;
}

sub parseMultiVarList($) {
	my $varNodeList = shift;
	my %vars;
	my $index = sprintf("%03d", 0);
	my $currentLine = getStatementLine();
	my @subNode;
	my $operatorInit;
	my $flagComma = 0;
	my $typeRoot;

	# initialize first var
	my $nameVarRoot = GetName($varNodeList);
	$vars{$index++}{$nameVarRoot} = 1;

	# create hash of var names list with order
	while (defined nextStatement() && ${nextStatement()} eq ',') {
		getNextStatement();
		if (defined nextStatement() && ${nextStatement()} =~ /(\w+)\s+(\w+)/) {
			$vars{$index++}{$1} = $2;

			foreach my $id (sort keys %vars) {
				foreach my $varName (keys %{$vars{$id}}) {
					$vars{$id}{$varName} = $2;
				}
			}
			getNextStatement();
		}
		else {
			$vars{$index++}{${getNextStatement()}} = 1;
		}
	}

	if (defined nextStatement() && ${nextStatement()} =~ /^(:?\=)$/m) {
		$operatorInit = $1;
		getNextStatement();
		purgeLineReturn();
	}

	if (defined $operatorInit) {

		# create subnode for each values of %vars
		# add list of values between , after the equal
		foreach my $id (sort keys %vars) {
			foreach my $varName (keys %{$vars{$id}}) {
				my $stmt_subNode;
				my $subNode = Node(GetKind($varNodeList), \$stmt_subNode);
				$varName =~ s/\s+//g;
				if ($id eq '000') {
					SetName($varNodeList, $varName);
					SetLine($varNodeList, $currentLine);
				}
				else {
					SetName($subNode, $varName);
					SetLine($subNode, $currentLine);
				}

				if (defined nextStatement() && ${nextStatement()} eq '[') {
					my $typeSubnode .= '[array]';
					my ($type_array, $indice_values, $stmt_values) = parseArray();
					$typeSubnode .= $type_array if (defined $type_array);
					if ($id eq '000') {
						Lib::NodeUtil::SetXKindData($varNodeList, "array_values", $stmt_values) if (defined $stmt_values);
						Lib::NodeUtil::SetXKindData($varNodeList, "type", $typeSubnode) if (defined $typeSubnode);
						Lib::NodeUtil::SetXKindData($varNodeList, "indice_values", $indice_values) if (defined $indice_values);
					}
					else {
						Lib::NodeUtil::SetXKindData($subNode, "array_values", $stmt_values) if (defined $stmt_values);
						Lib::NodeUtil::SetXKindData($subNode, "type", $typeSubnode) if (defined $typeSubnode);
						Lib::NodeUtil::SetXKindData($subNode, "indice_values", $indice_values) if (defined $indice_values);
					}
				}
				else {
					if ($id eq '000') {
						parseExpression($varNodeList, [\&isNextComma, \&isNextNewLine]);
					}
					elsif ($flagComma == 1) {
						parseExpression($subNode, [\&isNextComma, \&isNextNewLine]);
					}
				}

				if ($id eq '000') {
					Append($varNodeList, Node(InitKind, $operatorInit));
				}
				else {
					Append($subNode, Node(InitKind, $operatorInit));
					push(@subNode, $subNode);
				}

				if (defined nextStatement() && ${nextStatement()} eq ',') {
					getNextStatement();
					$flagComma = 1;
				}
			}
		}
	}
	# the equal is not present
	else {
		if (defined nextStatement() && ${nextStatement()} eq '[') {
			$typeRoot .= '[array]';
			my ($type_array, $indice_values, $stmt_values) = parseArray();
			$typeRoot .= $type_array if (defined $type_array);
			Lib::NodeUtil::SetXKindData($varNodeList, "array_values", $stmt_values) if (defined $stmt_values);
			Lib::NodeUtil::SetXKindData($varNodeList, "type", $typeRoot);
			Lib::NodeUtil::SetXKindData($varNodeList, "indice_values", $indice_values) if (defined $indice_values);
		}

		# create subnode for each values of %vars
		foreach my $id (sort keys %vars) {
			foreach my $varName (keys %{$vars{$id}}) {
				my $subNode = Node(GetKind($varNodeList), "");
				$varName =~ s/\s+//g;
				SetName($subNode, $varName);
				SetLine($subNode, $currentLine);

				Append($subNode, Node(InitKind, $operatorInit)) if (defined $operatorInit);

				if (defined $typeRoot) {
					Lib::NodeUtil::SetXKindData($subNode, "type", $typeRoot);
				}
				elsif (exists $vars{$id}{$varName} && $vars{$id}{$varName} eq '1') {
					Lib::NodeUtil::SetXKindData($subNode, "type", $vars{$id}{$varName});
				}

				push(@subNode, $subNode) if ($id ne '000');
			}
		}
	}

	# allow adding subnodes at same level
	setGoKindData($varNodeList, 'addnode', \@subNode);

	return $varNodeList;
}

sub parseMultiSetVar($) {
	my $varMultiNode = shift;
	my $name;
	my $type;
	my $stmt_subNode;
	my $subNode = Node(VarKind, \$stmt_subNode);

	while (defined nextStatement() && ${nextStatement()} ne ')') {
		if (defined nextStatement()
			&& (${nextStatement()} =~ /(\w+)\s+(\w+)/ || ${nextStatement(1)} =~ /^:?\=$/m )) {
			$subNode = parseSimpleVar();
		}
		elsif (defined nextStatement()	&& ${nextStatement()} eq ',') {
			SetName($subNode, $name);
			parseMultiVarList($subNode);
		}
		elsif (defined nextStatement() && (${nextStatement()} eq '*' || ${nextStatement()} eq '&')) {
			if (defined nextStatement() && ${nextStatement()} eq '*') {
				$type .= '[ptr]';
				getNextStatement();
			}
			elsif (defined nextStatement() && ${nextStatement()} eq '&') {
				$type .= '[addr]';
				getNextStatement();
			}
		}
		elsif (defined nextStatement()
				&& (${nextStatement()} eq 'func'
					|| ${nextStatement()} eq 'struct'
					|| ${nextStatement()} eq 'interface')) {

			#SetName($subNode, $name);
			#SetLine($subNode, getStatementLine());

			my $nodeExpression = Lib::ParseUtil::tryParse_OrUnknow(\@expressionContent);
			if (defined $name && $name ne '*' && $name ne '&') {
				$name =~ s/\s+//g;
				SetName($nodeExpression, $name);
			}
			my $oldType = Lib::NodeUtil::GetXKindData($nodeExpression, 'type') || "";
			Lib::NodeUtil::SetXKindData($nodeExpression, "type", $type . $oldType) if (defined $type);
			$subNode = $nodeExpression;

		}
		elsif (defined nextStatement() && ${nextStatement()} eq '[') {
			$type .= '[array]';
			my ($type_array, $indice_values, $stmt_values) = parseArray();
			$type .= $type_array if (defined $type_array);
			Lib::NodeUtil::SetXKindData($subNode, "type", $type) if (defined $type);
			Lib::NodeUtil::SetXKindData($subNode, "array_values", $stmt_values) if (defined $stmt_values);
			Lib::NodeUtil::SetXKindData($subNode, "indice_values", $indice_values) if (defined $indice_values);
		}
		elsif (defined $name && $name ne '') {
			SetName($subNode, $name);
			SetLine($subNode, getStatementLine());
			$type .= ${getNextStatement()};
		}
		else {
			$name = ${getNextStatement()};
			$name =~ s/\s+//g;
			SetName($subNode, $name);
			SetLine($subNode, getStatementLine());
		}

		if (defined $subNode && defined nextStatement() && ${nextStatement()} eq "\n") {
			Append($varMultiNode, $subNode);
			getNextStatement();

			# initializing
			$stmt_subNode = undef;
			$subNode = Node(VarKind, \$stmt_subNode);
			$name = undef;
			$type = undef;
		}
	}

	# consumes )
	getNextStatement() if (defined nextStatement() && ${nextStatement()} eq ')');

	return $varMultiNode;
}

##################################################################
#              ARRAY
##################################################################

sub isNextArray() {
	if (defined nextStatement() && ${nextStatement()} eq '[') {
		return 1;
	}
	return 0;
}

sub parseArray() {
	my $typeArray;
	my $indice_values;
	my $stmt_values;
	my $subnode;

	if (isNextArray()) {
		# consumes ([ ... ])+
		while (defined nextStatement() && ${nextStatement()} eq '[') {
			while (defined nextStatement() && ${nextStatement()} ne ']') {
				$indice_values .= ${getNextStatement()};
			}
			if (defined nextStatement() && ${nextStatement()} eq ']') {
				$indice_values .= ${getNextStatement()};
			}
		}

		if (defined nextStatement() && ${nextStatement()} =~ /(\*|\&)/) {
			$typeArray = $1;
			if (${nextStatement()} eq '*') {
				$typeArray = '[ptr]';
			}
			elsif (${nextStatement()} eq '&') {
				$typeArray = '[addr]';
			}
			getNextStatement();
		}

		#consumes '.(' if necessary e.g. a[0].(interface {...})
		while (defined nextStatement() && ${nextStatement()} =~ /[\.\(]/) {
			getNextStatement();
		}

		# struct array
		if (isNextStruct()) {
			$subnode = parseStruct();
			if (defined $subnode) {
				$typeArray = 'struct';

				if (defined nextStatement() && ${nextStatement()} eq ')') {
					getNextStatement();
				}
			}
			else {
				print STDERR "[parseArray] Unexpected result of parseStruct at line ".getStatementLine()."\n";
			}
		}
		# func array
		elsif (isNextFunction()) {
			$subnode = parseFunction();
			if (defined $subnode) {
				$typeArray = 'func';
				if (defined nextStatement() && ${nextStatement()} eq ')') {
					getNextStatement();
				}
			}
			else {
				print STDERR "[parseArray] Unexpected result of parseFunc at line ".getStatementLine()."\n";
			}
		}
		# interface array
		elsif (isNextInterface()) {
			$subnode = parseInterface();
			if (defined $subnode) {
				$typeArray = 'interf';
				if (defined nextStatement() && ${nextStatement()} eq ')') {
					getNextStatement();
				}
			}
			else {
				print STDERR "[parseArray] Unexpected result of parseInterface at line ".getStatementLine()."\n";
			}
		}
		else {
			$typeArray = ${getNextStatement()};
		}

		$stmt_values .= ${parsePairing()} if isNextPairing;

		# consumes ([ ... ])+ after statement values
		if (defined nextStatement() && ${nextStatement()} eq '[') {
			$indice_values .= '...';
			while (defined nextStatement() && ${nextStatement()} eq '[') {
				while (defined nextStatement() && ${nextStatement()} ne ']') {
					$indice_values .= ${getNextStatement()};
				}
				if (defined nextStatement() && ${nextStatement()} eq ']') {
					$indice_values .= ${getNextStatement()};
				}
			}
		}

		if (defined $subnode) {
			return ($typeArray, undef, undef, $subnode);
		}
		else {
			return ($typeArray, $indice_values, $stmt_values);
		}
	}

	return undef;
}

##################################################################
#              MAP
##################################################################

sub isNextMap() {
	if (defined nextStatement() && ${nextStatement()} eq 'map') {
		return 1;
	}
	return 0;
}

sub parseMap() {

	if (isNextMap()) {
		my $stmt;
		my $type;
		my $mapNode = Node(MapKind, \$stmt);
		SetLine($mapNode, getStatementLine());

		# consumes map keyword
		getNextStatement();

		# KeyType
		$stmt .= ${parsePairing()};

		# ElementType
		parseExpression($mapNode, [\&isNextNewLine, \&isNextClosingParenthesis, \&isNextOpenningAcco, \&isNextComma]);
		Lib::NodeUtil::SetXKindData($mapNode, 'type', $type);

		if (defined nextStatement() && ${nextStatement()} eq '{') {
			my $stmt_values = parsePairing();
			Lib::NodeUtil::SetXKindData($mapNode, "hash_elts", $stmt_values) if defined $stmt_values;
		}

		return $mapNode;
	}
	return undef;
}

##################################################################
#              MAKE
##################################################################

sub isNextMake() {
	if (defined nextStatement() && ${nextStatement()} eq 'make') {
		return 1;
	}
	return 0;
}

sub parseMake() {

	if (isNextMake()) {
		my $type;
		my $makeNode = Node(MakeKind, createEmptyStringRef);
		SetLine($makeNode, getStatementLine());

		# consumes map keyword
		getNextStatement();

		Append($makeNode,parseParenthesis());

		return $makeNode;
	}
	return undef;
}

##################################################################
#              EXPRESSION
##################################################################

sub parseExpression($;$) {
	my $node =shift;
	my $cb_end = shift;

	my $endOfStatement = 0;
	my $r_statement = GetStatement($node);

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

			# Next token belongs to the expression. Parse it.
			$subNode = Lib::ParseUtil::tryParse(\@expressionContent);

			if (defined $subNode) {
				# *** SYNTAX has been recognized by CALLBACK

				if (ref $subNode eq "ARRAY") {
					Append($node, $subNode);
					refineNode($subNode, $r_statement);
					$$r_statement .= ${Lib::ParseUtil::getSkippedBlanks()} . Go::GoNode::nodeLink($subNode);
				}
				else {
					$$r_statement .= $$subNode;
				}
			}
			else {
				# ***  SYNTAX UNRECOGNIZED with callbacks

				my $skippedBlanks = ${Lib::ParseUtil::getSkippedBlanks()};

				if (! defined nextStatement()) {
					# It's the last statement : nothing to check !!
					$$r_statement .= $skippedBlanks;
				}

				else {
					my $stmt = getNextStatement();
					# final DEFAULT treatment
					$$r_statement .= $skippedBlanks . $$stmt;
				}
			}

		}

		if ( stopParsingInstruction($r_statement)) {
			last;
		}
	}

	SetStatement($node, $r_statement);

	# print "EXPRESSION : <$$r_statement>\n";

}

# replace parent node by a function call if necessary
sub refineNode($$)  {
	my $node = shift;
	my $r_statement = shift;
	# CHECK IF A '(' ... ')' IS A FUNCTION CALL
	# if a opening parenthesis follows a closing parenthesis, accolade or
	# identifier, then it is a function call.
	if ( IsKind($node, ParenthesisKind)) {
		if (defined $$r_statement && $$r_statement =~ /(?:[)}]|([\w]+)|<\s*[\w\.]+\s*>)\s*\z/sm ) {
			# print "FUNCTION CALL after <$$r_statement>\n";
			if ($$r_statement ne 'panic') {
				SetKind($node, FunctionCallKind);
				my $fctName = $1 || 'CALL';
				my $name = GetName($node);
				$name =~ s/PARENT/${fctName}_/;
				SetName($node, $name);
			}
		}
	}
}

##################################################################
#              FUNCTION
##################################################################

sub isNextFunction() {
	if ( defined nextStatement() && ${nextStatement()} eq 'func' ) {
		return 1;
	}
	return 0;
}

sub parseFunction() {
	if (isNextFunction()) {
		my $functionNode = Node(FunctionDeclarationKind, createEmptyStringRef());

		#trash 'function' keyword
		getNextStatement();

		my $proto = '';
		SetStatement($functionNode, \$proto);

		my $statementLine = getStatementLine();
		SetLine($functionNode, $statementLine);
		if (defined nextStatement() && ${nextStatement()} ne '(') {
			my $name = ${getNextStatement()};
			$name =~ s/\s+//g;
			SetName($functionNode, $name);
		}
		if (defined nextStatement() && ${nextStatement()} eq '(') {

			#consumes (
			getNextStatement();
			if (defined nextStatement() && ${nextStatement()} ne ')') {
				parseArguments($functionNode);
			}
			else {
				getNextStatement();
			}
		}

		if (defined nextStatement() && ${nextStatement()} ne '{') {
			if (isNextMethod()) {
				Append($functionNode, parseMethod());
			}
		}

		# search function signature (return type)
		if (defined nextStatement() && ${nextStatement()} ne '{') {
			my $returnType;
			while (defined nextStatement() && ${nextStatement()} ne "\n" && ${nextStatement()} ne '{') {
				if (isNextInterface() || isNextStruct()) {
					$returnType .= ${getNextStatement()}; # consumes keyword
					$returnType .= ${getNextStatement()}; # consumes {
					while (defined nextStatement() && ${nextStatement()} ne '}') {
						$returnType .= ${getNextStatement()};
					}
					$returnType .= ${getNextStatement()}; # consumes }
				}
				else {
					$returnType .= ${getNextStatement()};
				}
			}
			Lib::NodeUtil::SetXKindData($functionNode, "returnType", $returnType);
		}

		# body function
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			# parse body
			# declare a new artifact
			my $lineStatement = getStatementLine();
			my $artiKey = Lib::ParseUtil::newArtifact("func_line_$lineStatement", $lineStatement);
			SetXKindData($functionNode, 'artifact_key', $artiKey);

			# param value 1 signifies not removing semicolon ...
			Append($functionNode, parseAccoBloc());

			#end of artifact
			Lib::ParseUtil::endArtifact($artiKey);
			SetXKindData($functionNode, 'codeBody', Lib::ParseUtil::getArtifact($artiKey));
		}
		else {
			SetKind($functionNode, FunctionCallKind);
		}

		#purgeLineReturn();

		return $functionNode;
	}
	return undef;
}

sub parseArguments($) {

	my $routineNode = shift;

	# Extract parameters and record them as attached data.
	my $index = sprintf("%03d", 0);
	my %args;
	my @paramList;

	while (defined nextStatement() && ${nextStatement()} ne ')') {
		my $nameArg = '_';
		my $typeArg;

		# ignore chan = channel
		if (defined nextStatement() && ${nextStatement()} =~ /(\w+)\s+(?:chan\s+)?(\w+)/) {
			$nameArg = $1;
			$typeArg = $2;
			$nameArg =~ s/\s+//g;
			getNextStatement();

			while (defined nextStatement() && ${nextStatement()} !~ /^[\,\)]$/m) {
				$typeArg .= ${getNextStatement()};
			}
		}
		elsif (defined nextStatement(1) &&
			(${nextStatement(1)} eq 'struct'
				|| ${nextStatement(1)} eq 'interface'
				|| ${nextStatement(1)} eq 'map')) {
			$nameArg = ${getNextStatement()};
			if (isNextStruct()) {
				parseStruct();
				$typeArg .= 'struct';
			}
			elsif (isNextInterface()) {
				parseInterface();
				$typeArg .= 'interface';
			}
			elsif (isNextMap()) {
				parseMap();
				$typeArg .= 'map';
			}
			else {
				$typeArg .= ${getNextStatement()};
			}
		}
		elsif (defined nextStatement(1) && ${nextStatement(1)} =~ /(\*|\&|\[)/) {
			$nameArg = ${getNextStatement()};
			if (${nextStatement()} eq '*') {
				$typeArg .= '[ptr]';
			}
			elsif (${nextStatement()} eq '&') {
				$typeArg .= '[addr]';
			}
			elsif (${nextStatement()} eq '[') {
				$typeArg .= '[';
			}
			getNextStatement();
			if (isNextStruct()) {
				parseStruct();
				$typeArg .= 'struct';
			}
			elsif (isNextInterface()) {
				parseInterface();
				$typeArg .= 'interface';
			}
			elsif (isNextMap()) {
				parseMap();
				$typeArg .= 'map';
			}
			else {
				while (defined nextStatement() && ${nextStatement()} !~ /^[\,\)]$/m) {
					$typeArg .= ${getNextStatement()};
				}
			}
		}
		# arg without name
		else {
			$typeArg = ${getNextStatement()};
			$typeArg =~ s/\s+//g;
		}

		# Add to hash
		$args{$index++}{$nameArg} = $typeArg;

		if (defined nextStatement() && ${nextStatement()} eq ',') {
			# consumes ,
			getNextStatement();
		}
	}

	foreach my $id (sort keys %args) {
		foreach my $arg (keys %{$args{$id}}) {
			push @paramList, [ $arg, $args{$id}{$arg}, undef, undef, $arg ];
		}
	}

	if (defined nextStatement() && ${nextStatement()} eq ')') {
		getNextStatement();
	}

	Lib::NodeUtil::SetXKindData($routineNode, 'parameters', \@paramList);
}

##################################################################
#              METHOD
##################################################################

sub isNextMethod() {
	if ( defined nextStatement() && ${nextStatement()} ne "\n" && defined nextStatement(1) && ${nextStatement(1)} eq '(' ) {
		return 1;
	}
	return 0;
}

sub parseMethod() {
	if (isNextMethod()) {
		my $methodNode = Node(MethodKind, createEmptyStringRef());
		my $name = ${getNextStatement()};
		$name =~ s/\s+//g;
		SetName($methodNode, $name);
		SetLine($methodNode, getStatementLine());

		my $proto;
		SetStatement($methodNode, \$proto);
		if (defined nextStatement() && ${nextStatement()} eq '(') {

			#consumes (
			getNextStatement();
			if (defined nextStatement() && ${nextStatement()} ne ')') {
				parseArguments($methodNode);
			}
			else {
				getNextStatement();
			}
		}

		return $methodNode;
	}
	return undef;
}

##################################################################
#              STRUCT
##################################################################

sub isNextStruct() {
	if ( defined nextStatement() && ${nextStatement()} eq 'struct'
		|| (${nextStatement()} eq '*' && defined nextStatement(1) && ${nextStatement(1)} eq 'struct')
		|| (${nextStatement()} eq '&' && defined nextStatement(1) &&  ${nextStatement(1)} eq 'struct')
		|| (${nextStatement()} eq '*' && defined nextStatement(2) &&  ${nextStatement(2)} eq 'struct')
		|| (${nextStatement()} eq '&' && defined nextStatement(2) &&  ${nextStatement(2)} eq 'struct')) {
		return 1;
	}
	return 0;
}

my $name_struct;
sub parseStruct();
sub parseStruct() {
	if (isNextStruct()) {

		my $structNode = Node(StructKind, createEmptyStringRef());

		if (${nextStatement()} eq '*') {
			Lib::NodeUtil::SetXKindData($structNode, "type", "[ptr]");
			getNextStatement();
		}
		elsif (${nextStatement()} eq '&') {
			Lib::NodeUtil::SetXKindData($structNode, "type", "[addr]");
			getNextStatement();
		}

		# consumes struct keyword
		getNextStatement();

		$name_struct =~ s/\t//g if (defined $name_struct);
		SetName($structNode, $name_struct) if (defined $name_struct);
		SetLine($structNode, getStatementLine());

		my $proto;
		SetStatement($structNode, \$proto);
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			# consumes {
			getNextStatement();
			purgeLineReturn();

			while (defined nextStatement() && ${nextStatement()} ne '}') {
				my $attributeNode = Node(AttributeKind, createEmptyStringRef());

				if (defined nextStatement(1) && ${nextStatement(1)} eq ',') {
					$attributeNode = parseMultiAttributeOneLine();
					Append($structNode, $attributeNode);
				}
				else {
					$attributeNode = parseSimpleAttribute();
					Append($structNode, $attributeNode);
				}
				purgeLineReturn();
			}
		}

		if (defined nextStatement() && ${nextStatement()} eq '}') {
			# consumes }
			getNextStatement();
		}
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			my $stmt = parsePairing();
			Lib::NodeUtil::SetXKindData($structNode, "array_values", $stmt) if defined $stmt;
		}

		return $structNode;
	}
	return undef;
}

sub parseSimpleAttribute($) {
	my $stmt = "";
	my $attrSimpleNode = Node(AttributeKind, \$stmt);
	my $currentLine = getStatementLine();
	my $type;
	my $tag;
	my $name;

	while (defined nextStatement() && ${nextStatement()} ne "\n" && ${nextStatement()} ne '}') {
		if (defined nextStatement() && ${nextStatement()} =~ /(\w+)\s+(\w+)\s*(.*)/) {
			$name = $1;
			$name =~ s/\s+//g;
			$type = $2;
			$tag = $3;

			SetName($attrSimpleNode, $name);
			SetLine($attrSimpleNode, $currentLine);

			my $oldType = Lib::NodeUtil::GetXKindData($attrSimpleNode, 'type') || "";
			Lib::NodeUtil::SetXKindData($attrSimpleNode, "type", $oldType.$type);
			Lib::NodeUtil::SetXKindData($attrSimpleNode, "tag", $tag) if defined $tag;
			getNextStatement();
		}
		elsif (defined nextStatement() && ${nextStatement()} =~ /(\*|\&)/) {
			my $type = $1;
			if (${nextStatement()} eq '*') {
				$type = '[ptr]';
			}
			elsif (${nextStatement()} eq '&') {
				$type = '[addr]';
			}
			Lib::NodeUtil::SetXKindData($attrSimpleNode, "type", $type) if defined $type;
			getNextStatement();

			if (defined nextStatement() && ${nextStatement()} =~ /(\w+)\s*(.*)/) {
				$type .= $1;
				$tag = $2;
				if ($type =~ /\bstruct\b/) {
					Append($attrSimpleNode, parseStruct());
				}
				my $oldType = Lib::NodeUtil::GetXKindData($attrSimpleNode, 'type') || "";
				Lib::NodeUtil::SetXKindData($attrSimpleNode, "type", $oldType . $type);
				Lib::NodeUtil::SetXKindData($attrSimpleNode, "tag", $tag) if defined $tag;
				getNextStatement() if ($type ne 'struct');
				# if type interface{}
				if (defined nextStatement() && ${nextStatement()} eq '{') {
					$type .= ${getNextStatement()};
					$type .= ${getNextStatement()} if (defined nextStatement() && ${nextStatement()} eq '}');
				}
			}
		}
		elsif (defined nextStatement() && ${nextStatement()} eq '[') {
			$type .= '[array]';
			my ($type_array, $indice_values, $stmt_values) = parseArray();
			$type .= $type_array if (defined $type_array);
			if ($type =~ /(.*)(CHAINE_[0-9]+)$/m) {
				Lib::NodeUtil::SetXKindData($attrSimpleNode, "type", $1);
				Lib::NodeUtil::SetXKindData($attrSimpleNode, "tag", $2);
			}
			else {
				Lib::NodeUtil::SetXKindData($attrSimpleNode, "type", $type);
			}
			Lib::NodeUtil::SetXKindData($attrSimpleNode, "indice_values", $indice_values) if (defined $indice_values);
			Lib::NodeUtil::SetXKindData($attrSimpleNode, "array_values", $stmt_values) if (defined $stmt_values);
		}
		elsif (defined nextStatement() && ${nextStatement()} =~ /^\s*CHAINE_/m) {
			Lib::NodeUtil::SetXKindData($attrSimpleNode, "tag", ${getNextStatement()});
		}
		elsif (defined $name && $name ne "") {
			if (isNextStruct()) {
				Append($attrSimpleNode, parseStruct());
				$type .= 'struct';
			}
			elsif (isNextInterface()) {
				Append($attrSimpleNode, parseInterface());
				$type .= 'interface';
			}
			elsif (isNextMap()) {
				Append($attrSimpleNode, parseMap());
				$type .= 'map';
			}
			else {
				$type .= ${getNextStatement()};
			}
			Lib::NodeUtil::SetXKindData($attrSimpleNode, "type", $type);
		}
		else {
			$name = ${getNextStatement()};
			$name =~ s/\s+//g;
			SetName($attrSimpleNode, $name);
			SetLine($attrSimpleNode, $currentLine);
		}
	}

	return $attrSimpleNode;
}

sub parseMultiAttributeOneLine() {

	my $attrMultiNodeOneLine = Node(AttributeKind, "");
	my %attributes;
	my $index = sprintf("%03d", 0);
	my $currentLine = getStatementLine();
	my @subNode;
	my $typeRoot;

	# initialize first attribute
	my $nameAttributeRoot = ${getNextStatement()};
	$nameAttributeRoot =~ s/\s+//g;
	$attributes{$index++}{$nameAttributeRoot} = 1;

	# create hash of var names list with order
	my $type;
	while (defined nextStatement() && ${nextStatement()} eq ',') {
		# consumes ,
		getNextStatement();

		my $nextStmt = ${nextStatement()};
		if (defined $nextStmt) {
			# ignore chan = channel
			$nextStmt =~ s/\bchan\b//;
			if ($nextStmt =~ /(\w+)\s+(\w+)\s*(.*)/) {
				my $attrName = $1;
				$attrName =~ s/\s+//g;
				$type = $2;
				my $tag = $3;

				$attributes{$index++}{$attrName} = $type;

				foreach my $id (sort keys %attributes) {
					foreach $attrName (keys %{$attributes{$id}}) {
						$attributes{$id}{$attrName} = $type;
						$attributes{$id}{$attrName} = $type . "|" . $tag if defined $tag && $tag ne '';
					}
				}
				getNextStatement();
			}
			else {
				my $attrName = ${getNextStatement()};
				$attrName =~ s/\s+//g;
				$attributes{$index++}{$attrName} = 1;
			}
		}
	}
	my $nodeExpression;
	if (defined nextStatement() && ${nextStatement()} eq '[') {
		$typeRoot .= '[array]';
		my ($type_array, $indice_values, $stmt_values) = parseArray();
		$typeRoot .= $type_array if (defined $type_array);
		Lib::NodeUtil::SetXKindData($attrMultiNodeOneLine, "array_values", $stmt_values) if (defined $stmt_values);
		Lib::NodeUtil::SetXKindData($attrMultiNodeOneLine, "indice_values", $indice_values) if (defined $indice_values);
		Lib::NodeUtil::SetXKindData($attrMultiNodeOneLine, "type", $typeRoot);
	}
	elsif (! defined $type) {
		if (isNextFunction() || isNextStruct() || isNextInterface() || isNextMap() || isNextMake()) {
			$nodeExpression = Lib::ParseUtil::tryParse_OrUnknow(\@expressionContent);
			Lib::NodeUtil::SetXKindData($nodeExpression, "type", $type) if ($type);
		}
		else {
			$typeRoot = ${getNextStatement()};
		}
	}

	# create subnode for each values of %vars
	foreach my $id (sort keys %attributes) {
		foreach my $attrName (keys %{$attributes{$id}}) {

			my $subNode = Node(AttributeKind, "");
			$attrName =~ s/\s+//g;

			my @typeOrTag = split(/\|/, $attributes{$id}{$attrName});

			if ($id eq '000') {
				SetName($attrMultiNodeOneLine, $attrName);
				SetLine($attrMultiNodeOneLine, $currentLine);
			}
			else {
				SetName($subNode, $attrName);
				SetLine($subNode, $currentLine);
			}

			if (defined $nodeExpression) {
				if ($id eq '000') {
					Append($attrMultiNodeOneLine, $nodeExpression);
				}
				else {
					Append($subNode, $nodeExpression);
				}
			}
			elsif (defined $typeRoot) {
				if ($id eq '000') {
					Lib::NodeUtil::SetXKindData($attrMultiNodeOneLine, "type", $typeRoot);
				}
				else {
					Lib::NodeUtil::SetXKindData($subNode, "type", $typeRoot);
				}
			}
			elsif (exists $attributes{$id}{$attrName} && $attributes{$id}{$attrName} ne '1') {
				if ($id eq '000') {
					Lib::NodeUtil::SetXKindData($attrMultiNodeOneLine, "type", $typeOrTag[0]) if $typeOrTag[0];
					Lib::NodeUtil::SetXKindData($attrMultiNodeOneLine, "tag", $typeOrTag[1]) if $typeOrTag[1];
				}
				else {
					Lib::NodeUtil::SetXKindData($subNode, "type", $typeOrTag[0]) if $typeOrTag[0];
					Lib::NodeUtil::SetXKindData($subNode, "tag", $typeOrTag[1]) if $typeOrTag[1];
				}
			}

			push(@subNode, $subNode) if ($id ne '000');
		}
	}

	# allow adding subnodes at same level
	setGoKindData($attrMultiNodeOneLine, 'addnode', \@subNode);

	return $attrMultiNodeOneLine;
}

##################################################################
#              INTERFACE
##################################################################

sub isNextInterface() {
	if ( defined nextStatement() && ${nextStatement()} eq 'interface') {
		return 1;
	}
	return 0;
}

sub parseInterface();
sub parseInterface() {
	if (isNextInterface()) {

		my $interfaceNode = Node(InterfaceKind, createEmptyStringRef());

		# consumes interface keyword
		getNextStatement();

		SetLine($interfaceNode, getStatementLine());

		my $proto;
		SetStatement($interfaceNode, \$proto);
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			# consumes {
			getNextStatement();
			purgeLineReturn();

			while (defined nextStatement() && ${nextStatement()} ne '}') {
				while (defined nextStatement() && ${nextStatement()} ne "\n" && ${nextStatement()} ne '}') {
					# new method
					my $method_stmt = ${getNextStatement()};
					my $attributeNode = Node(AttributeKind, \$method_stmt);
					$method_stmt =~ s/\s+//g;
					SetName($attributeNode, $method_stmt);
					SetLine($attributeNode, getStatementLine());

					if (defined nextStatement() && ${nextStatement()} eq '(') {
						$method_stmt .= ${getNextStatement()};
						while (defined nextStatement() && ${nextStatement()} ne ')') {
							$method_stmt .= ${getNextStatement()};
						}
					}
					if (defined nextStatement() && ${nextStatement()} eq ')') {
						$method_stmt .= ${getNextStatement()};
					}

					Append($interfaceNode, $attributeNode);
					my $returnType;
					while (defined nextStatement() && ${nextStatement()} ne "\n" && ${nextStatement()} ne '}') {
						if (isNextInterface || isNextStruct) {
							$returnType .= ${getNextStatement()}; # consumes keyword
							$returnType .= ${getNextStatement()}; # consumes {
							while (defined nextStatement() && ${nextStatement()} ne '}') {
								$returnType .= ${getNextStatement()};
							}
							$returnType .= ${getNextStatement()}; # consumes }
						}
						else {
							$returnType .= ${getNextStatement()};
						}
					}
					Lib::NodeUtil::SetXKindData($attributeNode, "returnType", $returnType);
				}

				if (defined nextStatement() && ${nextStatement()} eq "\n") {
					getNextStatement();
				}
			}
		}
		if (defined nextStatement() && ${nextStatement()} eq '}') {
			# consumes }
			getNextStatement();
		}
		return $interfaceNode;
	}
	return undef;
}

##################################################################
#              ROOT
##################################################################

sub parseRoot() {
	my $root = Node(RootKind, \$NullString);

	SetName($root, 'root');

	my $artiKey=Lib::ParseUtil::newArtifact('root');
	setGoKindData($root, 'artifact_key', $artiKey);

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
# Split a Go buffer into statement separated by structural token
#

sub splitGo($) {
   my $r_view = shift;

   my @statements = split /($GO_SEPARATOR|$STRUCTURAL_STATEMENTS|$STATEMENT_BEGINNING_PATTERNS|$NEVER_A_STATEMENT_BEGINNING_PATTERNS|$CONTROL_FLOW_STATEMENTS)/sm, $$r_view;

   if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }
   return \@statements;
}


sub ParseGo($) {
  my $r_view = shift;

  my $r_statements = splitGo($r_view);

  # only spaces and tabs will be considered as blanks in a statement (\n are considered as SEPARATORS)
  Lib::ParseUtil::setBlankRegex('[ \t]');

  Lib::ParseUtil::InitParser($r_statements);

  # pass all beginning empty lines
  while (${nextStatement()} eq "\n") {
	getNextStatement();
  }

  # Mode LAST (no inclusion) for artifact consolidation.
  Lib::ParseUtil::setArtifactMode(0);

  my $root = parseRoot();
  my $Artifacts = Lib::ParseUtil::getArtifacts();

  return ($root, $Artifacts);
}

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

##################################################################
#              MAIN
##################################################################

# description: Go parse module Entry point.
sub Parse($$$$)
{
	my ($fichier, $vue, $couples, $options) = @_;
	my $status = 0;

	$StringsView = $vue->{'HString'};

	Lib::ParseUtil::registerParseUnknow(\&parseUnknow);

#    my $statements =  $vue->{'statements_with_blanks'} ;

	# launch first parsing pass : strutural parse.
	my ($GoNode, $Artifacts) = ParseGo(\$vue->{'code'});

	# Set MethodKind type to functions are classes methods
	# Lib::Node::Iterate ($GoNode, 0, sub {
										# my $node = shift;
										# # For each class ...
										# if (IsKind($node, StructKind)) {
											# for my $child (@{Lib::NodeUtil::GetChildren($node)}) {
												# # ... for each function child ...
												# if (IsKind($child, FunctionKind)) {
													# # ... set to method !!
													# SetKind($child, MethodKind);
												# }
											# }
										# }
										# return undef; # walk in the whole tree
									# }, []);

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

	if (defined $options->{'--print-tree'}) {
		Lib::Node::Dump($GoNode, *STDERR, "ARCHI") if ($DEBUG);
	}
	if (defined $options->{'--print-test-tree'}) {
		print STDERR ${Lib::Node::dumpTree($GoNode, "ARCHI")} ;
	}

	$vue->{'structured_code'} = $GoNode;
	$vue->{'artifact'} = $Artifacts;

	# pre-compute some list of kinds :
	preComputeListOfKinds($GoNode, $vue, [FunctionDeclarationKind, FunctionCallKind, MethodKind, StructKind, IfKind, ElseKind, ForKind, SwitchKind, CaseKind, VarKind]);

	#TSql::ParseDetailed::ParseDetailed($vue);
	if (defined $options->{'--print-artifact'}) {
		for my $key ( keys %{$vue->{'artifact'}} ) {
			print "-------- $key -----------------------------------\n";
			print  $vue->{'artifact'}->{$key}."\n";
		}
	}

	return $status;
}

sub stopParsingInstruction($) {
	# return
	# * 0 don't stop parsing
	# * 1 stop parsing

	my $r_previousToken = shift;
	my $r_previousBlanks = Lib::ParseUtil::getSkippedBlanks();

	# a enclosing <> '' means the expression is enclosed => do not terminate.
	# return 0 if (getEnclosing() ne '');

	if (defined nextStatement()) {

		# INSTRUCTIONS SEPARATOR
		# ----------------------
		# a '}' or ';' always ends a statement expression.
		if (${nextStatement()} eq '}' || ${nextStatement()} eq ';') {
			return 1;
		}

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
		}
		elsif (${nextStatement()} eq "\n") {
			return 1;
		}
		else {
			# return 0 by default because next token is on the same line than previous one.
		}

		}
	else {
		# if next token is NOT DEFINED, then return true because another try to
		# retrieve the next token will not provide a new statement.
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
      purgeLineReturn();
    }

    return $node;
  }

  # Creation of the unknow node.
  # ----------------------------
  my $unknowNode = Node(UnknowKind, createEmptyStringRef());
  SetLine($unknowNode, getNextStatementLine());
  # An unknow statement is parsed as an expression.
  parseExpression($unknowNode);

   purgeLineReturn();

#print "[DEBUG] Unknow statement : ".${GetStatement($unknowNode)}."\n";

  return $unknowNode;
}

sub purgeLineReturn() {
	while ((defined nextStatement()) && (${nextStatement()} eq "\n" || ${nextStatement()} eq "\;")) {
		getNextStatement();
	}
}

1;


