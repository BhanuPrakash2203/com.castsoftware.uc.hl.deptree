package Scala::ParseScala;
# les modules importes
use strict;
use warnings;

use Erreurs;

use CountUtil;

use Lib::Node; # qw( Leaf Node Append );
use Lib::NodeUtil ;
use Lib::NodeUtil qw( SetName SetStatement SetLine GetLine SetEndline GetEndline);
use Lib::ParseUtil;

use Scala::ScalaNode;
use CountUtil;

my $DEBUG = 0;

my @rootContent = (
	\&parseModifiers,
	\&parsePackage,
	\&parseImport,
	\&parseObject,
	\&parseAnnotation,
);

my @classContent = (
	\&parseModifiers,
	\&parseImport,
	\&parseMethod, # may be placed before parseVar
	\&parseLocallyBlock,
	\&parseVar,
	\&parseObject,
	\&parseAnnotation,
	\&parseCase,
	\&parseAssert,
	\&parseRequire,

);

my @methodContent = (
	\&parseModifiers,
	\&parseImport,
	\&parseMethod, # may be placed before parseVar
	\&parseVar,
	\&parseIf,
	\&parseFor,
	\&parseWhile,
	\&parseDoWhile,
	\&parseAnnotation,
	\&parseReturn,
	\&parseCase, # may be placed before parseMethodCallOrCollection
	\&parseMethodCallOrCollection,
	\&parseTryCatch,
	#\&parseMap,
	\&parseMatch,
	\&parseNew,
	\&parseAssert,
	\&parseRequire,

);

my @varContent = (
	\&parseNew,
	\&parseIf,
	#\&parseCase, # may be placed before parseMethodCallOrCollection
	\&parseMethodCallOrCollection,
	\&parseFunction,
	\&parseMatch,
	\&parseMap,
	\&parseAssert,
	\&parseRequire,

);

my @collectionContent = (
	\&parseModifiers,
	\&parseMethodCallOrCollection,
	\&parseVar,
	\&parseIf,
	\&parseFor,
	\&parseWhile,
	\&parseDoWhile,
	\&parseMethod,
	\&parseReturn,
	\&parseMap,

);

my @packageContent = (
	\&parsePackage,
	\&parseModifiers,
	\&parseObject,
	\&parseVar,
	\&parseAnnotation,
);

my @expressionContent = (
	\&parseVar,
	\&parseIf,
	\&parseFor,
	\&parseWhile,
	\&parseDoWhile,
	\&parseTryCatch,
	\&parseMatch,
	\&parseCase, # may be placed before parseMethodCallOrCollection
	\&parseMap,
	\&parseMethodCallOrCollection,
	\&parseNew,

);


########################## CONTEXT ###################
use constant CTX_LEAVE => -1;
use constant CTX_ROOT => 0;
use constant CTX_OBJECT => 1;
use constant CTX_PACKAGE => 2;
use constant CTX_METHOD => 3;
use constant CTX_COLLECTION => 4;
use constant CTX_RETURN_TYPE => 5;
use constant CTX_CONSTRUCTOR => 6;
use constant CTX_FUNCTION => 7;
#use constant CTX_SWITCH => 5;

my $DEFAULT_CONTEXT = CTX_ROOT;
my $count_artifact=0;

my @context = (CTX_ROOT);

my %ContextContent = (
	&CTX_ROOT() => \@rootContent,
	&CTX_OBJECT() => \@classContent,
	&CTX_PACKAGE() => \@packageContent,
	&CTX_METHOD() => \@methodContent,
	&CTX_COLLECTION() => \@collectionContent,
	&CTX_RETURN_TYPE() => undef,
	&CTX_CONSTRUCTOR() => undef,
	&CTX_FUNCTION() => undef,
	#&CTX_SWITCH() => \@switchContent
);

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

sub getCurrentContextContent() {
	return $ContextContent{ $context[-1] };
}

sub getCurrentContextName() {

	# CTX_LEAVE => -1;
	# CTX_ROOT => 0;
	# CTX_OBJECT => 1;
	# CTX_PACKAGE => 2;
	# CTX_METHOD => 3;
	# CTX_COLLECTION => 4;
	# CTX_RETURN_TYPE => 5;
	# CTX_CONSTRUCTOR => 6;
	# CTX_FUNCTION => 7;

	if ($context[-1] == 0) {
		return "CTX_ROOT";
	}
	elsif ($context[-1] == 1) {
		return "CTX_OBJECT";
	}
	elsif ($context[-1] == 2) {
		return "CTX_PACKAGE";
	}
	elsif ($context[-1] == 3) {
		return "CTX_METHOD";
	}
	elsif ($context[-1] == 4) {
		return "CTX_COLLECTION";
	}
	elsif ($context[-1] == 5) {
		return "CTX_RETURN_TYPE";
	}
	elsif ($context[-1] == 6) {
		return "CTX_CONSTRUCTOR";
	}
	elsif ($context[-1] == 7) {
		return "CTX_FUNCTION";
	}
	}

sub initContext() {
	@context = (CTX_ROOT);
	$DEFAULT_CONTEXT = CTX_ROOT;
}

my $TRIGGERS_parseParenthesis = {
	"new" => \&triggerParseNew,
};

my $Scala_SEPARATOR = '(?:[;\n\(\)\{\}])';

my $NEVER_A_STATEMENT_BEGINNING_PATTERNS = '(?:\&\&|\&\=|\&\^\=|\&\^|\&|\+\=|\+|\/\>|\-\>|\=\>|\=\=|\!\=|\-\=|\-\-|\-|\|\|\||\||\<\=|\<|\[|\]|\*\=|\*|\^\=|\^|\<\-|\>\=|\/|\<\<|\/\=|\<\<\=|\:\:\:|\:\=|\,|\>\>|\%\=|\>\>\=|\!|\.\.\.|\:|\=|\>|\%)';
# for NEVER_A_STATEMENT_ENDING_PATTERNS: we only want to catch '+' not '++' which is a concatenation operator (regex used for that [^\+]\+ )
my $NEVER_A_STATEMENT_ENDING_PATTERNS = '(?:\+\=|[^\+]\+|\&\=|\&\^\=|\&\^|\&\&|\&|\=\=|\!\=|\-\=|\-\-|\-|\|\=|\|\||\||\<|\<\=|\[|\*|\^|\*\=|\^\=|\<\-|\>\=|\<\<|\/\=|\/|\<\<\=|\:\=|\,|\>\>|\%\=|\>\>\=|\!|\.\.\.|\:\,|\=|\>|\%)';
my $STRUCTURAL_STATEMENTS = '(?<!\$)\b(?:class|def|new|object|package|trait)\b';
my $CONTROL_FLOW_STATEMENTS = '(?<!\$)(?:\b(?:assert|case|catch|do|else|extends|finally|for|foreach|if|import|locally|require|return|try|val|var|while|with|yield)\b)';
my $METHODS_STATEMENTS = '(?<!\$)(?:\b(?:match|map)\b)';
my $COLLECTION_STATEMENTS = '(?:\b(?:ArrayBuffer|ArraySeq|ArrayStack|BitSet|Buffer|DoubleLinkedList|HashMap|HashSet|ImmutableMapAdaptor|ImmutableSetAdaptor|IndexedSeq|Iterable|LinearSeq|LinkedHashMap|LinkedHashSet|LinkedList|List|ListBuffer|ListMap|Map|MultiMap|MutableList|ObservableBuffer|ObservableMap|ObservableSet|OpenHashMap|PriorityQueue|Queue|Seq|Set|SortedSet|Stack|StringBuilder|SynchronizedBuffer|SynchronizedMap|SynchronizedPriorityQueue|SynchronizedQueue|SynchronizedSet|SynchronizedStack|Traversable|TreeMap|WeakHashMap)\b)';
my $STATEMENT_BEGINNING_PATTERNS = '(?:\+\+|\-\-|\@)';
my %H_CLOSING = ( '{' => '}', '[' => ']', '<' => '>', '(' => ')' );

my $NullString = '';
# case modifier is for class or object
# public modifier does not exists in Scala
my $re_MODIFIERS = '\b(?:abstract|case|final|implicit|lazy|override|private|protected|sealed)\b';
my $StringsView = undef;

sub isNextNewLine() {
	if ( defined nextStatement() && ${nextStatement()} eq "\n") {
		return 1;
	}
	return undef;
}

sub isNextComma() {
	if ( defined nextStatement() && ${nextStatement()} eq ",") {
		return 1;
	}
	return undef;
}

sub isNextOpeningParenthesis() {
	if ( defined nextStatement() && ${nextStatement()} eq '(' ) {
		return 1;
	}
	return undef;
}

sub isNextClosingParenthesis() {
	if (defined nextStatement() && ${nextStatement()} eq ')') {
		return 1;
	}
	return undef;
}

sub isNextClosingBracket() {
	if (defined nextStatement() && ${nextStatement()} eq ']') {
		return 1;
	}
	return undef;
}

sub isNextOpeningAcco() {
	if ( defined nextStatement() && ${nextStatement()} eq '{' ) {
		return 1;
	}
	return undef;
}

sub isNextClosingAcco() {
	if ( defined nextStatement() && ${nextStatement()} eq '}' ) {
		return 1;
	}
	return undef;
}

sub isNextEqual() {
	if ( defined nextStatement() && ${nextStatement()} eq '=') {
		return 1;
	}
	return undef;
}

##################################################################
#              ROOT
##################################################################
sub parseRoot() {
	my $root = Node(RootKind, \$NullString);

	SetName($root, 'root');

	my $artiKey = Lib::ParseUtil::newArtifact('root');
	Scala::ScalaNode::setScalaKindData($root, 'artifact_key', $artiKey);

	while (defined nextStatement()) {
		my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);
		if (defined $subNode) {
			Append($root, $subNode);
		}
		purgeLineReturn();
	}

	Lib::ParseUtil::endArtifact('root');

	return $root;
}

##################################################################
#              EXPRESSION
##################################################################
sub parseExpression($;$) {
	my $node = shift;
	my $cb_end = shift;

	my $endOfStatement = 0;
	my $r_statement = GetStatement($node);

	# parse the statement until the end is encountered.
	while ((defined nextStatement()) && (!$endOfStatement)) {

		# check if the next statement correspond to a token that ends the expression.
		if (defined $cb_end) {
			for my $cb (@{$cb_end}) {
				if ($cb->()) {
					$endOfStatement = 1;
					last;
				}
			}
		}

		if (!$endOfStatement) {
			# Lambda expression = Anonymous function
			if (${nextStatement()} eq '{') {
				my $subNode = Node(AnonymousFuncKind, \$NullString);
				Append($subNode, parseAccoBloc());
				Append($node, $subNode);
			}
			# function
			elsif (isNextFunction()) {
				my $subNode = parseFunction();
				Append($node, $subNode);
			}
			elsif (isNextHTMLSample()) {
				purgeLineReturn();
				while (defined nextStatement() && ${nextStatement()} eq '<') {
					my $res = skipHTMLSample();
					last if !defined $res;
				}
			}
			# expression concat operator
			# (xxx) ++ (yyy)
			# (xxx) ++ {yyy}
			elsif (${nextStatement()} eq '++') {
				# consumes ++
				getNextStatement();
				purgeLineReturn();
				if (defined nextStatement() && (${nextStatement()} eq '{' || ${nextStatement()} eq '(')) {
					my $endingPattern = '}';
					if (${nextStatement()} eq '(') {
						$endingPattern = ')';
					}
					getNextStatement();
					my $subNode = Lib::ParseUtil::tryParse(\@expressionContent);
					# condition to avoid undef nodes
					if (defined $subNode) {
						Append($node, $subNode);
					}
					purgeLineReturn();
					if (defined nextStatement() && ${nextStatement()} eq $endingPattern) {
						getNextStatement();
					}
				}
			}
			else {
				my $subNode;
				# Next token belongs to the expression. Parse it.
				$subNode = Lib::ParseUtil::tryParse(\@expressionContent);

				if (defined $subNode) {
					# *** SYNTAX has been recognized by CALLBACK

					if (ref $subNode eq "ARRAY") {
						Append($node, $subNode);
						#refineNode($subNode, $r_statement);
						#$$r_statement .= ${Lib::ParseUtil::getSkippedBlanks()} . Scala::ScalaNode::nodeLink($subNode);
					}
					else {
						$$r_statement .= $$subNode;
					}
				}
				else {
					# ***  SYNTAX UNRECOGNIZED with callbacks

					my $skippedBlanks = ${Lib::ParseUtil::getSkippedBlanks()};

					if (!defined nextStatement()) {
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
		}

		if (stopParsingInstruction($r_statement)) {
			last;
		}
	}

	SetStatement($node, $r_statement);

	# print "EXPRESSION : <$$r_statement>\n";

}

##################################################################
#              PACKAGE
##################################################################
sub isNextPackage() {
	if ( defined nextStatement() && ${nextStatement()} eq 'package' ) {
		return 1;
	}
	return undef;
}

sub parsePackage() {
	if (isNextPackage()) {
		sendContextEvent(CTX_PACKAGE);

		# consumes package
		getNextStatement();

		my $statement = "";
		my $packageNode = Node(PackageKind, \$statement);

		SetLine($packageNode, getStatementLine());

		while (defined nextStatement() && ${nextStatement()} ne '{' && ${nextStatement()} ne "\n") {
			$statement .= ${getNextStatement()};
		}

		if (defined nextStatement() && ${nextStatement()} eq '{') {
			getNextStatement();
			purgeLineReturn();
			while (defined nextStatement() && ${nextStatement()} ne '}') {
				my $subnode = Lib::ParseUtil::tryParse_OrUnknow(\@packageContent);
				if (defined $subnode) {
					Append($packageNode, $subnode);
				}
				purgeLineReturn();
			}
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '}') {
				getNextStatement();
			}
			else {
				print STDERR "[parsePackage] ERROR : missing closing '}' at line ".getStatementLine()."\n";
			}
		}
		
		sendContextEvent(CTX_LEAVE);
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
	return undef;
}

sub parseImport() {
	if (isNextImport()) {
		# consumes import
		getNextStatement();

		my $statement = "";
		my $endingParse = "\n";
		my $importNode = Node(ImportKind, \$statement);

		SetLine($importNode, getStatementLine());
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '(') {
			$statement .= ${getNextStatement()};
			$endingParse = ')';
		}
		elsif (defined nextStatement() && ${nextStatement()} eq '{') {
			$statement .= ${getNextStatement()};
			$endingParse = '}';
		}
		while (defined nextStatement() && ${nextStatement()} ne $endingParse) {
			$statement .= ${getNextStatement()};
			if (defined nextStatement() && (${nextStatement()} eq '{' || ${nextStatement()} eq '(')) {
				$statement .= ${parsePairing()};
			}
		}
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq $endingParse) {
			$statement .= ${getNextStatement()};
		}

		purgeLineReturn();
		return $importNode;
	}
	return undef;
}

##################################################################
#              MODIFIERS
##################################################################
sub isNextModifiers() {
	if (defined nextStatement() && ${nextStatement()} =~ /\A\s*$re_MODIFIERS\b/) {
		if ((${nextStatement()} eq 'case' && ${nextStatement(1)} ne 'class')
			&& (${nextStatement()} eq 'case' && ${nextStatement(1)} ne 'object')
			&& (${nextStatement()} eq 'case' && ${nextStatement(2)} ne 'class')
			&& (${nextStatement()} eq 'case' && ${nextStatement(2)} ne 'object')) {
			# it's a simple case statement, not a case class or case object
			return undef;
		}
		else {
			return 1;
		}
	}
	return undef;
}

sub parseModifiers() {
	if (isNextModifiers()) {
		my $context = getCurrentContextName();

		my $modifiers;

		# list all modifiers if several
		# modifier1 modifier2[...]
		while (isNextModifiers()) {
			$modifiers .= ${getNextStatement()};
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} =~ /\(|\[/) {
				$modifiers .= ${parsePairing()};
			}
			$modifiers .= '|';
		}

		my %H_mod;

		while ($modifiers =~ /\s*(.*?)\s*\|/g) {
			$H_mod{$1} = 1;
		}
		chop $modifiers;
		purgeLineReturn();
		if ($context eq 'CTX_CONSTRUCTOR') {
			return \%H_mod;
		}
		else {
			my $context = getCurrentContextContent();
			my $artifactNode;
			if (defined $context) {
				$artifactNode = Lib::ParseUtil::tryParse_OrUnknow($context);
			}
			else {
				# if context is empty: attribute method context by default
				$artifactNode = Lib::ParseUtil::tryParse_OrUnknow(\@methodContent);
			}
			setScalaKindData($artifactNode, 'modifiers', $modifiers);
			setScalaKindData($artifactNode, 'H_modifiers', \%H_mod);
			return $artifactNode;
		}
	}
	return undef;
}

##################################################################
#              NEW
##################################################################
sub isNextNew() {
	if ( ${nextStatement()} eq 'new' ) {
		return 1;
	}
	return undef;
}

sub parseNew() {
	if (isNextNew()) {
		# trash "new" keyword
		getNextStatement();
		my $name;
		my $parameters;
		my $line = getStatementLine();
		my $proto = "";
		my $newNode = Node(NewKind, \$proto);
		SetLine($newNode, $line);

		# anonymous class
		purgeLineReturn();
		if (defined nextStatement() and ${nextStatement()} eq "{") {
			my $anoClass = parseObjectContext(AnonymousClassKind, 'anonymous');
			if (defined $anoClass) {
				Append($newNode, $anoClass);
			}
		}
		else {
			# get the name of the class being instanciated
			$name = ${getNextStatement()};
			SetName($newNode, $name);

			# get the parameters of the constructor
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '(') {
				$parameters = ${parsePairing()};
			}
			# anonymous class
			purgeLineReturn();
			if (defined nextStatement() and ${nextStatement()} eq "{") {
				my $anoClass = parseObjectContext(AnonymousClassKind, 'anonymous');
				if (defined $anoClass) {
					Append($newNode, $anoClass);
				}
			}
		}

		purgeLineReturn();
		return $newNode;
	}

	return undef;
}

##################################################################
#              CLASS / OBJECT
##################################################################
sub isNextObject() {
	if (${nextStatement()} eq 'class') {
		return 1;
	}
	elsif (${nextStatement()} eq 'object') {
		return 2;
	}
	elsif (${nextStatement()} eq 'trait') {
		return 3;
	}
	return undef;
}

sub parseObject() {
	if (isNextObject() && isNextObject() == 1) {
		# trash class
		getNextStatement();

		my $classNode = parseObjectContext(ClassKind);
		return $classNode;
	}
	elsif (isNextObject() && isNextObject() == 2) {
		# trash object
		getNextStatement();

		my $objectNode = parseObjectContext(ObjectKind);
		return $objectNode;
	}
	elsif (isNextObject() && isNextObject() == 3) {
		my $traitNode = parseTrait();
		return $traitNode;
	}
	return undef;
}

sub parseObjectContext($) {
	# supported syntax
		# class MyClass[param] modifier[](param1: Int,...)
		# object MyObject

	my $kind = shift;

	my $objectNode = Node($kind, createEmptyStringRef());
	print "--> $kind found...\n" if $DEBUG;

	sendContextEvent(CTX_OBJECT);
	my $statementLine = getStatementLine();
	SetLine($objectNode, $statementLine);

	my $name;
	if ($kind eq AnonymousClassKind) {
		$name = 'AnonymousClass:' . $statementLine;
	}
	else {
		$name = ${getNextStatement()};
	}

	my $proto = $name;
	my $resultPairing;
	my $paramConstructor;

	purgeLineReturn();
	if (defined nextStatement() && (${nextStatement()} eq '[')) {
		$resultPairing = ${parsePairing()};
		$name .= $resultPairing;
		$proto .= $resultPairing;
	}
	# get modifier if any
	sendContextEvent(CTX_CONSTRUCTOR);
	my $H_mod = parseModifiers();
	if (defined $H_mod) {
		setScalaKindData($objectNode, 'H_modifiers_constructor', $H_mod);
	}

	# get constructor parameters
	purgeLineReturn();
	if (defined nextStatement() && ${nextStatement()} eq '(') {
		$resultPairing = ${parsePairing()};
		$paramConstructor = $resultPairing;
	}
	if (defined $paramConstructor) {
		$paramConstructor =~ s/\s{2,}/ /g;
		Lib::NodeUtil::SetXKindData($objectNode, 'paramConstructor', $paramConstructor);
	}
	sendContextEvent(CTX_LEAVE);

	# parse object inheritance
	purgeLineReturn();
	if (defined nextStatement() && ${nextStatement()} =~ /(extends|with)/) {
		$objectNode = parseObjectInheritance($objectNode);
	}

	# object has a body
	if (defined nextStatement() && ${nextStatement()} eq '{') {
		# consumes {
		getNextStatement();
		purgeLineReturn();

		# self/this block
		$objectNode = parseSelfBlock($objectNode);

		purgeLineReturn();
		while (defined nextStatement() && ${nextStatement()} ne '}') {
			my $memberNode = Lib::ParseUtil::tryParse_OrUnknow(\@classContent);
			if (defined $memberNode) {
				Append($objectNode, $memberNode);
			}
		}
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '}') {
			getNextStatement();
		}
		else {
			print STDERR "[parseObject] Missing ending accolade at line ".getStatementLine()."\n";
		}
	}

	# with block after object body
	# object xxx {body} with {withBlock}
	purgeLineReturn();
	my $withNode = parseWith();
	if (defined $withNode) {
		Append($objectNode, $withNode);
	}
	
	sendContextEvent(CTX_LEAVE);
	# affect values to node
	SetName($objectNode, $name);
	$proto =~ s/\s{2,}/ /g;
	SetStatement($objectNode, \$proto);
	SetEndline($objectNode, getStatementLine());

	purgeLineReturn();
	return $objectNode;
}

sub parseObjectInheritance($) {
	my $objectNode = shift;
	my $extends;
	my $with;
	while (defined nextStatement() && ${nextStatement()} =~ /(extends|with)/) {
		# consumes extends or with
		getNextStatement();

		# get super class name
		# extends clause may be without name such as
		# object xxx extends myClass {object body}
		# object xxx extends myClass    (with no object body)
		my $proto;
		purgeLineReturn();
		while (defined nextStatement() && ${nextStatement()} ne '{' && ${nextStatement()} ne '.'
			&& ${nextStatement()} ne '}' && ${nextStatement()} ne "\n"
			&& ${nextStatement()} ne 'extends' && ${nextStatement()} ne 'with') {
			$proto .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
			purgeLineReturn();
			if (defined nextStatement() && (${nextStatement()} =~ /\[|\(/)) {
				$proto .= ${parsePairing()};
			}
		}
		if (defined $proto) {
			if ($1 eq 'extends') {
				$extends .= $proto . ' |';
			}
			else {
				$with .= $proto . ' |';
			}
		}
		purgeLineReturn();
	}
	if (defined $extends) {
		chop $extends;
		Lib::NodeUtil::SetXKindData($objectNode, 'extends', $extends);
	}
	if (defined $with) {
		chop $with;
		Lib::NodeUtil::SetXKindData($objectNode, 'with', $with);
	}
	return $objectNode;
}

##################################################################
#              LOCALLY BLOCK
##################################################################
sub isNextLocally() {
	if (defined nextStatement() && ${nextStatement()} eq 'locally') {
		return 1;
	}
	return undef;
}

sub parseLocallyBlock() {
	if (isNextLocally()) {
		my $locallyNode = Node(LocallyKind, \$NullString);

		# consumes locally
		getNextStatement();
		SetLine($locallyNode, getStatementLine());

		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			Append($locallyNode, parseAccoBloc());
		}

		SetEndline($locallyNode, getStatementLine());

		purgeLineReturn();
		return $locallyNode;
	}
	return undef;
}

##################################################################
#              TRAIT
##################################################################
sub isNextTrait() {
	if (${nextStatement()} eq 'trait') {
		return 1;
	}
	return undef;
}

sub parseTrait() {
	# supported syntax
	# trait MyTrait extends xxx with yyy
	# trait MyTrait {
	# 	this: xxx =>
	#  		// more code here ...
	# }
	if (isNextTrait()) {
		# trash trait
		getNextStatement();

		my $traitNode = Node(TraitKind, createEmptyStringRef());
		print "--> trait found...\n" if $DEBUG;

		sendContextEvent(CTX_OBJECT);
		my $statementLine = getStatementLine();
		SetLine($traitNode, $statementLine);

		my $name = ${getNextStatement()};
		purgeLineReturn();
		if (defined nextStatement() && (${nextStatement()} eq '[')) {
			my $resultPairing = ${parsePairing()};
			$name .= $resultPairing;
		}

		# parse object inheritance
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} =~ /(extends|with)/) {
			$traitNode = parseObjectInheritance($traitNode);
		}

		# trait has a body
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			# consumes {
			getNextStatement();
			purgeLineReturn();

			# self/this block
			$traitNode = parseSelfBlock($traitNode);

			purgeLineReturn();
			while (defined nextStatement() && ${nextStatement()} ne '}') {
				my $memberNode = Lib::ParseUtil::tryParse_OrUnknow(\@classContent);
				if (defined $memberNode) {
					Append($traitNode, $memberNode);
				}
			}
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '}') {
				getNextStatement();
			}
			else {
				print STDERR "[parseTrait] Missing ending accolade at line ".getStatementLine()."\n";
			}
		}

		sendContextEvent(CTX_LEAVE);
		# affect values to node
		SetName($traitNode, $name);
		#$proto =~ s/\s{2,}/ /g;
		#SetStatement($traitNode, \$proto);
		SetEndline($traitNode, getStatementLine());

		purgeLineReturn();
		return $traitNode;
	}
	return undef;
}

sub parseSelfBlock($) {
	my $node = shift;
	if (defined nextStatement(1) && ${nextStatement(1)} eq '=>'
		|| (defined nextStatement(1) && ${nextStatement(1)} =~ /^\s*$/m
		&& defined nextStatement(2) && ${nextStatement(2)} eq '=>')
		|| (defined nextStatement(1) && ${nextStatement(1)} eq ':'
		&& defined nextStatement(3) && ${nextStatement(3)} eq '=>')) {
		my $subClassType = ${getNextStatement()};
		if (defined nextStatement() && ${nextStatement()} eq ':') {
			#consumes :
			$subClassType .= ${getNextStatement()};
			# consumes subclass type name
			$subClassType .= ${getNextStatement()};
		}
		Lib::NodeUtil::SetXKindData($node, 'self-type', $subClassType);
		if (defined nextStatement() && ${nextStatement()} eq '=>') {
			#consumes =>
			getNextStatement();
		}
		else {
			print STDERR "[parseSelfBlock] ERROR : missing '=>' at line " . getStatementLine() . "\n";
		}
	}
	return $node;
}

##################################################################
#              METHODS
##################################################################
sub isNextMethod() {
	if (${nextStatement()} eq 'def') {
		return 1;
	}
	return undef;
}

sub parseMethod() {
	if (isNextMethod()) {
		# consumes method
		getNextStatement();
		my $name = ${getNextStatement()};

		my $proto = '';
		my $methodNode = Node(MethodKind, \$proto);
		print "--> Method $name found...\n" if $DEBUG;

		SetLine($methodNode, getStatementLine());

		sendContextEvent(CTX_METHOD);

		my $resultPairing;

		purgeLineReturn();
		if (defined nextStatement() && (${nextStatement()} eq '[')) {
			$resultPairing = ${parsePairing()};
			$proto .= $resultPairing;
		}
		# arguments
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '(') {
			# consumes (
			getNextStatement();
			parseArguments(\$methodNode, $proto);
		}
		# return type
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq ':') {
			# consumes :
			getNextStatement();
			Append ($methodNode, parseReturnType());
		}

		# method implementation
		purgeLineReturn();
		if (defined nextStatement() && (${nextStatement()} eq '=' || ${nextStatement()} eq '{')) {
			# consumes =
			getNextStatement() if ${nextStatement()} eq '=';
			# parse method element between parenthesis
			# def myMethod = (...).methodA.methodB... {...}
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '(') {
				parseExpression($methodNode, [ \&isNextClosingParenthesis ]);
				purgeLineReturn();
				if (defined nextStatement() && ${nextStatement()} eq ')') {
					getNextStatement();
				}
			}
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} =~ /^\./m) {
				my $subNode = parseMethodCallOrCollection();
				if (defined $subNode) {
					Append($methodNode, $subNode);
				}
			}

			# parse body
			purgeLineReturn();
			my $bool_body = 0;
			if (defined nextStatement() && ${nextStatement()} eq '{') {
				# consumes {
				getNextStatement();

				my $artiKey = Lib::ParseUtil::newArtifact("method_".$name, getStatementLine());
				SetXKindData($methodNode, 'artifact_key', $artiKey);

				# def xxx = { <html>...</html> }
				purgeLineReturn();
				while (defined nextStatement() && ${nextStatement()} eq '<') {
					my $res = skipHTMLSample();
					last if !defined $res;
				}
				$bool_body = 1;
				purgeLineReturn();
				while (nextStatement() && ${nextStatement()} ne '}') {
					my $node = Lib::ParseUtil::tryParse_OrUnknow(\@methodContent);
					if (defined $node) {
						Append($methodNode, $node);
					}
				}
				Lib::ParseUtil::endArtifact($artiKey);
				SetXKindData($methodNode, 'codeBody', Lib::ParseUtil::getArtifact($artiKey));
			}
			elsif (defined nextStatement() && ${nextStatement()} ne '}') {
				#parseExpression($subroutinesNode);
				Append($methodNode, Lib::ParseUtil::tryParse_OrUnknow(\@methodContent));
			}

			if ($bool_body == 1) {
				if (defined nextStatement() && ${nextStatement()} eq '}') {
					getNextStatement();
				}
				else {
					print STDERR "[parseMethod] Missing ending accolade at line " . getStatementLine() . "\n";
				}
			}
			# method without body with match expression
			# def method = xxx match {...}
			elsif (defined nextStatement() && ${nextStatement()} eq 'match') {
				Append($methodNode, parseMatch());
			}
		}

		sendContextEvent(CTX_LEAVE);
		# add values to node
		SetStatement($methodNode, \$proto);
		SetName($methodNode, $name);
		SetEndline($methodNode, getStatementLine());

		purgeLineReturn();
		return $methodNode;
	}
}

sub parseArguments($$) {
	my $ref_node = shift;
	my $proto = shift;
	my $nameParam;
	my $node = $$ref_node;
	my $endingPattern = ')';
	my $context = getCurrentContextName();
	if ($context eq 'CTX_FUNCTION') {
		$endingPattern = '=>';
	}
	# get the list of parameters
	purgeLineReturn();
	while (defined nextStatement() && ${nextStatement()} ne $endingPattern) {
		my $protoParam = "";
		my $paramNode = Node(ParamKind, \$protoParam);

		# get argument name if exists
		if (defined nextStatement(1) && ${nextStatement(1)} eq ':'
			|| (defined nextStatement(1) && ${nextStatement(1)} =~ /^\s*$/m
			&& defined nextStatement(2) && ${nextStatement(2)} eq ':')) {
			$nameParam = ${getNextStatement()};
			SetName($paramNode, $nameParam);
		}
		purgeLineReturn();
		# get argument type
		if (defined nextStatement() && ${nextStatement()} eq ':') {
			# consumes :
			getNextStatement();
		}
		my $typeParam;
		purgeLineReturn();
		if (isNextFunction() && $context ne 'CTX_FUNCTION') {
			# /!\ argument type is a function => callback
			my $subNode = parseFunction();
			Append($paramNode, $subNode);
			Lib::NodeUtil::SetXKindData($paramNode, 'type', 'callback');
		}
		else {
			while (defined nextStatement() && ${nextStatement()} ne '='
				&& ${nextStatement()} ne ',' && ${nextStatement()} ne $endingPattern) {
				$typeParam .= ${getNextStatement()};
			}
			Lib::NodeUtil::SetXKindData($paramNode, 'type', $typeParam);
		}
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '=') {
			# consumes =
			getNextStatement();
			parseExpression($paramNode, [ \&isNextComma, \&isNextClosingParenthesis ]);
			purgeLineReturn();
			my $countEnclosed = countEnclosed($proto);
			while (defined nextStatement() && ${nextStatement()} eq ')' && $countEnclosed > 0) {
				$protoParam .= ${getNextStatement()};
				$countEnclosed--;
			}
		}
		Append($node, $paramNode);
		purgeLineReturn();
		if (defined nextStatement() && (${nextStatement()} eq ',')) {
			# consumes ,
			getNextStatement();
		}
		purgeLineReturn();
	}
	purgeLineReturn();
	if (defined nextStatement() && ${nextStatement()} eq ')') {
		# consumes )
		getNextStatement();
	}

	purgeLineReturn();
	return $node;
}

##################################################################
#              FUNCTION
##################################################################
sub isNextFunction() {
	if (defined nextStatement(1) && ${nextStatement(1)} eq '=>') {
		return 1;
	}
	elsif (defined nextStatement() && ${nextStatement()} eq '(' && simulateParseFunction()) {
		return 2;
	}
	return undef;
}

sub parseFunction() {
	if (isNextFunction()) {
		my $res = isNextFunction();

		sendContextEvent(CTX_FUNCTION);

		my $proto = "";
		my $functionNode = Node(FunctionDeclarationKind, \$proto);

		SetLine($functionNode, getStatementLine());

		# x => ...
		# x => { ... }
		# (xxx) => yyy
		purgeLineReturn();
		# get the function parameters
		if (defined nextStatement() && ${nextStatement()} eq '(') {
			# consumes (
			getNextStatement();
		}

		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} ne ')') {
			parseArguments(\$functionNode, $proto);
		}
		else {
			# consumes )
			getNextStatement();
		}
		if (defined nextStatement() && ${nextStatement()} eq '=>') {
			# consumes =>
			getNextStatement();

			my $artiKey = Lib::ParseUtil::newArtifact("func_" . $count_artifact++, getStatementLine());
			SetXKindData($functionNode, 'artifact_key', $artiKey);

			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '{') {
				Append($functionNode, parseAccoBloc());
			}
			else {
				# isNextComma for following case : myCollection(func = () => ... , param2)
				parseExpression($functionNode, [ \&isNextClosingCurlyBrace, \&isNextClosingParenthesis, \&isNextComma ]);
			}
			SetEndline($functionNode, getStatementLine());
			Lib::ParseUtil::endArtifact($artiKey);
			SetXKindData($functionNode, 'codeBody', Lib::ParseUtil::getArtifact($artiKey));

			sendContextEvent(CTX_LEAVE);
			purgeLineReturn();
			return $functionNode;
		}
		else {
			print STDERR "[parseFunction] ERROR : missing '=>' at line " . getStatementLine() . "\n";
		}
	}
	return undef;
}

sub simulateParseFunction() {
	my $idx = 0;
	my $idx_nonblank = 0;
	my $enclosedParenthesis = 0;
	# fix limit to avoid infinite loop issue
	my $threshold = 500;
	if (defined nextStatement($idx) && ${nextStatement($idx)} eq '(') {
		$idx++;
	}
	while (defined nextStatement($idx) && ((${nextStatement($idx)} ne ')'
		|| $enclosedParenthesis > 0 || $idx_nonblank >= $threshold))) {

		# detect char non blank
		if (defined nextStatement($idx) && ${nextStatement($idx)} !~ /^[\s]+$/m
			&& ${nextStatement($idx)} ne "") {
			$idx_nonblank++;
		}

		if (defined nextStatement($idx) && ${nextStatement($idx)} eq '(') {
			$enclosedParenthesis++;
		}
		elsif (defined nextStatement($idx) && ${nextStatement($idx)} eq ')') {
			$enclosedParenthesis--;
		}
		$idx++;
	}
	if (defined nextStatement($idx) && ${nextStatement($idx)} eq ')') {
		$idx++;
		# detect blank char
		while (defined nextStatement($idx) && (${nextStatement($idx)} =~ /^[\s]+$/m
			|| ${nextStatement($idx)} eq "")) {
			$idx++;
		}
		if (defined nextStatement($idx) && ${nextStatement($idx)} eq '=>') {
			return 1;
		}
	}
	return undef;
}

##################################################################
#              VARIABLES
##################################################################
sub isNextVar {
	my $context = getCurrentContextName();
	# to avoid confusion with a false positive var node in parseExpression()
	# we want to stop at the equal in this example
	# val x: Int = ...
	if ($context ne 'CTX_RETURN_TYPE') {
		if (defined nextStatement() && ${nextStatement()} =~ /\b(va(?:l|r))\b/) {
			return $1;
		}
		elsif ((defined nextStatement(1) && ${nextStatement(1)} =~ /^\:?\=$/m)
			|| (defined nextStatement(1) && ${nextStatement(1)} =~ /^\s*$/m
			&& defined nextStatement(2) && ${nextStatement(2)} =~ /^\:?\=$/m)) {
			return 1;
		}
	}
	return undef;
}

sub parseVar() {
	if (isNextVar()) {
		my $typeVar = isNextVar();

		if ($typeVar eq 'val') {
			$typeVar = 'immutable';
			# consumes val
			getNextStatement();
		}
		# var
		elsif ($typeVar eq 'var') {
			$typeVar = 'mutable';
			# consumes var
			getNextStatement();
		}
		else {
			$typeVar = 'decl';
		}

		my $context = getCurrentContextName();

		my $proto = "";
		my $returnType;

		purgeLineReturn();
		my $name;
		# multivar
		if (defined nextStatement() && ${nextStatement()} eq '(') {
			# consumes (
			getNextStatement();
			while (defined nextStatement() && ${nextStatement()} ne ')') {
				$name .= ${getNextStatement()};
			}
			# consumes )
			getNextStatement();
		}
		else {
			$name = ${getNextStatement()};
		}

		my $varNode = Node(VarKind, \$proto);
		Lib::NodeUtil::SetXKindData($varNode, 'type', $typeVar);
		SetLine($varNode, getStatementLine());

		# return type
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq ':') {
			# consumes :
			getNextStatement();
			Append ($varNode, parseReturnType());
		}
		# equal
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} =~ /(\:?\=)/) {
			# consumes := or =
			my $operator = ${getNextStatement()};
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '{') {
				my $subNode;
				if ($operator eq ':=') {
					$subNode = Node(StructKind, createEmptyStringRef());
					Append($subNode, parseAccoBloc());
					Append($varNode, $subNode);
				}
				else {
					Append($varNode, parseAccoBloc());
				}
			}
			else {
				if ($context eq 'CTX_COLLECTION') {
					parseExpression($varNode, [ \&isNextComma, \&isNextClosingParenthesis ]);
					purgeLineReturn();
					my $countEnclosed = countEnclosed($proto);
					while (defined nextStatement() && ${nextStatement()} eq ')' && $countEnclosed > 0) {
						$proto .= ${getNextStatement()};
						$countEnclosed--;
					}
				}
				elsif ($context eq 'CTX_FUNCTION') {
					parseExpression($varNode, [ \&isNextClosingParenthesis, \&isNextNewLine ]);
				}
				else {
					my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@varContent);
					Append($varNode, $subNode);
				}
			}
		}
		# parse method expression
		# var x = {...}.methodA.methodB...
		purgeLineReturn();
		while (defined nextStatement() && ${nextStatement()} =~ /^\./m) {
			if ($context eq 'CTX_COLLECTION') {
				parseExpression($varNode, [ \&isNextComma, \&isNextClosingParenthesis ]);
			}
			else {
				parseExpression($varNode, [ \&isNextNewLine ]);
			}
			purgeLineReturn();
			my $countEnclosed = countEnclosed($proto);
			while (defined nextStatement() && ${nextStatement()} eq ')' && $countEnclosed > 0) {
				$proto .= ${getNextStatement()};
				$countEnclosed--;
			}
		}
		
		# add values to node
		SetEndline($varNode, getStatementLine());

		# if name contains , it's a multi var declaration
		if ($name =~ /\,/) {
			my @names = split(/\,/, $name);
			my $multiVarNode = Node(MultiVarKind, \$NullString);
			foreach my $name (@names) {
				my $subNode = Node(VarKind, \$NullString);
				# $subNode = $varNode;
				ReplaceNodeContent($subNode, $varNode);
				SetName($subNode, $name);
				Append($multiVarNode, $subNode);
			}
			$varNode = $multiVarNode;
		}
		else {
			SetName($varNode, $name);
		}

		purgeLineReturn();
		return $varNode;
	}
	return undef;
}

##################################################################
#              RETURN TYPE
##################################################################
sub parseReturnType() {
	my $proto = '';
	sendContextEvent(CTX_RETURN_TYPE);

	my $returnTypeNode = Node(ReturnTypeKind, \$proto);

	purgeLineReturn();
	parseExpression($returnTypeNode, [ \&isNextEqual, \&isNextNewLine, \&isNextOpeningAcco, \&isNextMethod ]);

	sendContextEvent(CTX_LEAVE);

	purgeLineReturn();
	return $returnTypeNode;
}

##################################################################
#              IF
##################################################################
sub isNextIf() {
	if (defined nextStatement() && ${nextStatement()} eq 'if') {
		return 1;
	}
	return undef;
}

sub isNextElse() {
	if (defined nextStatement() && ${nextStatement()} eq 'else') {
		return 1;
	}
	return undef;
}

sub parseIf() {
	if (isNextIf()) {
		my $proto = '';
		my $ifNode = Node(IfKind, \$proto);

		# consumes if
		getNextStatement();
		SetLine($ifNode, getStatementLine());

		# get the condition
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '(') {
			Append($ifNode, parseCondition());
		}
		else {
			my $stmt;
			my $condNode = Node(ConditionKind, \$stmt);
			parseExpression($condNode, [ \&isNextNewLine ]);
			Append($ifNode, $condNode);
		}

		# parse then branch
		my $thenNode = Node(ThenKind, createEmptyStringRef);
		SetLine($thenNode, getStatementLine());

		Append($ifNode, $thenNode);

		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			Append($thenNode, parseAccoBloc());
		}
		elsif (defined nextStatement() && ${nextStatement()} ne '}') {
			parseExpression($thenNode, [ \&isNextElse, \&isNextClosingParenthesis ]);
		}

		SetEndline($thenNode, getStatementLine());

		# parse else branch
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq 'else') {
			my $elseNode = Node(ElseKind, createEmptyStringRef);
			SetLine($elseNode, getStatementLine());

			Append($ifNode, $elseNode);

			# consumes else
			getNextStatement();
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '{') {
				Append($elseNode, parseAccoBloc());
			}
			else {
				parseExpression($elseNode, [ \&isNextClosingParenthesis ]);
			}
		}
		purgeLineReturn();
		return $ifNode;
	}
	return undef;
}

sub parseCondition() {
	my $stmt;
	my $condNode = Node(ConditionKind, \$stmt);

	$stmt = ${parsePairing()};
	$stmt =~ s/^\s*\(//m;
	$stmt =~ s/\s*\)$//m;

	return $condNode;
}

sub parseAccoBloc() {
	my $accoNode = undef;

	if (isNextOpeningAcco()) {
		# consumes '{'
		getNextStatement();
		purgeLineReturn();
		# parse the braces content
		$accoNode = Lib::ParseUtil::parseCodeBloc(AccoKind, [\&isNextClosingAcco], \@methodContent, 0, 0 ); # keepClosing:0, noUnknowNode:0
	}

	purgeLineReturn();
	return $accoNode;
}

##################################################################
#              FOR
##################################################################
sub isNextFor() {
	if (defined nextStatement() && ${nextStatement()} eq 'for') {
		return 1;
	}
	elsif (defined nextStatement() && ${nextStatement()} eq 'foreach') {
		return 2;
	}
	return undef;
}

sub parseFor() {
	if (isNextFor()) {
		my $forNode;
		if (isNextFor() == 1) {
			$forNode = Node(ForKind, \$NullString);
			# consumes for
			getNextStatement();
			SetLine($forNode, getStatementLine());

			# get the condition
			purgeLineReturn();
			if (defined nextStatement() && (${nextStatement()} eq '(' || ${nextStatement()} eq '{')) {
				if (${nextStatement()} eq '(') {
					Append($forNode, parseCondition());
				}
				elsif (${nextStatement()} eq '{') {
					my $condNode = Node(ConditionKind, \$NullString);
					Append($condNode, parseAccoBloc());
					Append($forNode, $condNode);
				}
			}
			# parse body
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '{') {
				Append($forNode, parseAccoBloc());
			}
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq 'yield') {
				# consumes yield
				getNextStatement();
				my $yieldNode = Node(YieldKind, \$NullString);
				purgeLineReturn();
				if (defined nextStatement() && ${nextStatement()} eq '{') {
					Append($yieldNode, parseAccoBloc());
				}
				else {
					parseExpression($yieldNode, [ \&isNextClosingParenthesis ]);
				}
				Append($forNode, $yieldNode);
			}
			elsif (defined nextStatement() && ${nextStatement()} ne '}') {
				Append($forNode, Lib::ParseUtil::tryParse_OrUnknow(\@expressionContent));
			}
		}
		elsif (isNextFor() == 2) {
			$forNode = Node(ForeachKind, \$NullString);
			# consumes foreach
			getNextStatement();
			SetLine($forNode, getStatementLine());

			# get the condition
			purgeLineReturn();
			if (defined nextStatement() && (${nextStatement()} eq '(' || ${nextStatement()} eq '{')) {
				# consumes (
				getNextStatement() if ${nextStatement()} eq '(';
				if (${nextStatement()} eq '{') {
					Append($forNode, parseAccoBloc());
				}
				elsif (${nextStatement()} eq '(') {
					my $node = Lib::ParseUtil::tryParse_OrUnknow(\@methodContent);
					if (defined $node) {
						Append($forNode, $node);
					}
					purgeLineReturn();
					if (defined nextStatement() && ${nextStatement()} eq ')') {
						getNextStatement();
					}
				}
			}
		}

		SetEndline($forNode, getStatementLine());

		purgeLineReturn();
		return $forNode;
	}
	return undef;
}

##################################################################
#              DO WHILE
##################################################################
sub isNextDoWhile() {
	if ( ${nextStatement()} eq 'do' ) {
		return 1;
	}
	return undef;
}

sub parseDoWhile() {
	if (isNextDoWhile()) {
		#consumes do
		getNextStatement();

		my $doWhileNode = Node(DoWhileKind, \$NullString);
		SetLine($doWhileNode, getStatementLine());

		# parse do body
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			Append($doWhileNode, parseAccoBloc());
		}
		else {
			Append($doWhileNode, Lib::ParseUtil::tryParse_OrUnknow(\@expressionContent));
		}

		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq 'while') {
			my $whileNode = Node(WhileKind, \$NullString);

			# consumes while
			getNextStatement();
			SetLine($whileNode, getStatementLine());

			# get the condition
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '(') {
				Append($whileNode, parseCondition());
			}
			else {
				print STDERR "[parseWhile] ERROR : missing opening '(' at line ".getStatementLine()."\n";
			}
			Append($doWhileNode, $whileNode);
		}
		# add values to node
		SetEndline($doWhileNode, getStatementLine());

		purgeLineReturn();
		return $doWhileNode;
	}
	return undef;
}

##################################################################
#              WHILE
##################################################################
sub isNextWhile() {
	if (defined nextStatement() && ${nextStatement()} eq 'while') {
		return 1;
	}
	return undef;
}

sub parseWhile() {
	if (isNextWhile()) {
		my $whileNode = Node(WhileKind, \$NullString);

		# consumes while
		getNextStatement();
		SetLine($whileNode, getStatementLine());

		# get the condition
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '(') {
			Append($whileNode, parseCondition());
		}
		else {
			print STDERR "[parseWhile] ERROR : missing opening '(' at line ".getStatementLine()."\n";
		}

		# parse body
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			Append($whileNode, parseAccoBloc());
		}
		else {
			Append($whileNode, Lib::ParseUtil::tryParse_OrUnknow(\@expressionContent));
		}

		SetEndline($whileNode, getStatementLine());

		purgeLineReturn();
		return $whileNode;
	}
	return undef;
}

##################################################################
#              ANNOTATION
##################################################################
sub isNextAnnotation() {
	if (defined nextStatement() && ${nextStatement()} eq '@') {
		return 1;
	}
	return undef;
}

sub parseAnnotation() {
	if (isNextAnnotation()) {
		my $annotNode = Node(AnnotationKind, \$NullString);
		my $proto;
		# consumes @
		getNextStatement();
		SetLine($annotNode, getStatementLine());

		my $name = ${getNextStatement()};

		# get the arguments
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '(') {
			$proto = ${parsePairing()};
		}

		# add values to node
		SetName($annotNode, $name);
		SetStatement($annotNode, \$proto);
		SetEndline($annotNode, getStatementLine());

		purgeLineReturn();
		return $annotNode;
	}
	return undef;
}

##################################################################
#              HTML SAMPLE
##################################################################
sub isNextHTMLSample() {
	if (defined nextStatement() && ${nextStatement()} eq '<'
		&& defined nextStatement(1) && ${nextStatement(1)} =~ /^\w+/m) {
		return 1;
	}
	return undef;
}

sub skipHTMLSample() {
	if (isNextHTMLSample()) {
		my $html_stmt;
		# consumes <
		$html_stmt .= ${getNextStatement()};
		my $tagName = ${getNextStatement()};
		$html_stmt .= $tagName;
		if ($tagName =~ /(\w+)/) {
			$tagName = $1;
		}
		my $enclosed = 0;
		# supported syntax
		# <xxx   ...   />
		# <xxx> ...  </xxx>
		while (defined nextStatement() && $enclosed >= 0 && ${nextStatement()} !~ /\b$tagName\b/) {
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '/>') {
				# continue parsing if <br/>
				if ($html_stmt =~ /\<\s*br\s*$/m) {
					$html_stmt .= ${getNextStatement()};
					purgeLineReturn();
					# ending by:
					# <br/> }
					if (defined nextStatement() && ${nextStatement()} eq '}') {
						last;
					}
				}
				# stop parsing sequence
				else {
					last;
				}
			}
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '{') {
				$html_stmt .= ${parsePairing()};
			}
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '<') {
				# consumes <
				$html_stmt .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
				if (defined nextStatement() && ${nextStatement()} =~ /\b$tagName\b/) {
					$enclosed++;
				}
				elsif (defined nextStatement() && ${nextStatement()} eq '/') {
					# consumes /
					$html_stmt .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
					if (defined nextStatement() && ${nextStatement()} =~ /\b$tagName\b/) {
						$enclosed--;
					}
				}
			}
			$html_stmt .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
		}
		# consumes /> or >
		if (defined nextStatement() && (${nextStatement()} eq '/>' || ${nextStatement()} eq '>')) {
			$html_stmt .= ${getNextStatement()};
		}
		purgeLineReturn();
		while (defined nextStatement() && (${nextStatement()} eq '++' || ${nextStatement()} eq '{')) {
			if (defined nextStatement() && ${nextStatement()} eq '{') {
				$html_stmt .= ${parsePairing()};
			}
			else {
				$html_stmt .= ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
			}
			purgeLineReturn();
		}
		# print 'html_stmt=' . $html_stmt . "\n";
		purgeLineReturn();
		return $html_stmt;
	}
	return undef;
}

##################################################################
#              RETURN
##################################################################
sub isNextReturn() {
	if (defined nextStatement() && ${nextStatement()} eq 'return') {
		return 1;
	}
	return undef;
}

# TODO: add implicit return support
sub parseReturn() {
	if (isNextReturn()) {
		# consumes return
		getNextStatement();

		my $prototype = "";

		my $returnNode = Node(ReturnKind, \$prototype);
		SetLine($returnNode, getStatementLine());

		parseExpression($returnNode, [ \&isNextNewLine, \&isNextClosingCurlyBrace ]);

		purgeLineReturn();
		return $returnNode;
	}
	return undef;
}

##################################################################
#              COLLECTION + METHODCALL
##################################################################
sub isNextMethodCallOrCollection() {
	# collection node
	if (defined nextStatement() && (${nextStatement()} =~ /$COLLECTION_STATEMENTS/)) {
		return 1;
	}
	# node kind will be defined more later
	elsif (defined nextStatement && ${nextStatement()} =~ /\w+/
		&&
		((defined nextStatement(1) && ${nextStatement(1)} eq '(')
			|| (defined nextStatement(1) && ${nextStatement(1)} =~ /^\s*$/m
			&& defined nextStatement(2) && ${nextStatement(2)} eq '('))) {
		return 2;
	}
	return undef;
}

sub parseMethodCallOrCollection() {
	if (isNextMethodCallOrCollection()) {
		my $result = isNextMethodCallOrCollection();
		my $context = getCurrentContextName();
		# potential collection: check number of elements
		if ($result == 2) {
			my $nb_element = simulateParseCollection();
			if (defined $nb_element && $nb_element == 0) {
				return undef;
			}
		}
		my $name;
		# myColl() or myColl[] => name ending by ( or [
		# .xxx(myColl)  => name ending by )
		# xxx[myColl]   => name ending by ]
		# myColl.xxx }  => name ending by }
		while (defined nextStatement() && ${nextStatement()} ne '(' && ${nextStatement()} ne '['
			&& ${nextStatement()} ne ')' && ${nextStatement()} ne ']' && ${nextStatement()} ne '}'
			&& ${nextStatement()} ne "\n" && ${nextStatement()} ne '=') {
			$name .= ${getNextStatement()};
		}

		my $proto = "";
		my $collectionNode = Node(CollectionKind, \$proto);
		sendContextEvent(CTX_COLLECTION);
		SetLine($collectionNode, getStatementLine());

		# get the type of the sequence
		purgeLineReturn();
		my $typeCollection;
		if (defined nextStatement() && ${nextStatement()} eq '[') {
			# consumes [
			getNextStatement();
			while (defined nextStatement() && ${nextStatement()} ne ']') {
				$typeCollection .= ${getNextStatement()};
			}
			# consumes ]
			getNextStatement();
			Lib::NodeUtil::SetXKindData($collectionNode, 'typeCollection', $typeCollection);
		}

		# get the sequence
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '(') {
			# consumes (
			getNextStatement();
			purgeLineReturn();
			while (defined nextStatement() && ${nextStatement()} ne ')') {
				# Seq ((xxx, xxx1), ...)
				if (defined nextStatement() && ${nextStatement()} eq '(') {
					my $paramStmt = ${parsePairing()};
					my $paramNode = Node(ParamKind, \$paramStmt);
					Append($collectionNode, $paramNode);
				}
				# Seq (elementA, elementB, elementC...)
				else {
					my $protoElt = '';
					my $paramNode = Node(ParamKind, \$protoElt);
					parseExpression($paramNode, [ \&isNextComma, \&isNextClosingParenthesis ]);
					Append($collectionNode, $paramNode);
				}
				purgeLineReturn();
				if (defined nextStatement() && (${nextStatement()} eq ',')) {
					$proto .= ${getNextStatement()};
				}
				purgeLineReturn();
			}
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq ')') {
				# consumes )
				getNextStatement();
			}
		}
		# get map method
		purgeLineReturn();
		my $isMapped = 0;
		# if map method we have a collection node
		while ((defined nextStatement() && ${nextStatement()} eq 'map')
			|| defined nextStatement(1) && ${nextStatement(1)} eq 'map') {
			$isMapped = 1;
			my $mapNode = parseMap();
			if (defined $mapNode) {
				Append($collectionNode, $mapNode);
			}
			else {
				# exit to avoid infinite loop
				last;
			}
			purgeLineReturn();
		}
		# collection not fully complyant with criteria,
		# .map() method is not present
		if ($result == 2 && $isMapped == 0) {
			if (defined $name && $name =~ /\./) {
				SetKind($collectionNode, MethodCallKind);
			}
			else {
				# companion object "instanciation" or function call
				# => reach parser comparison limit
				SetKind($collectionNode, UnknowKind);
			}
		}
		# parse expression after an equal sign value such as
		# myColl(x, y, z) = ...
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '=' && $context ne 'CTX_RETURN_TYPE') {
			# consumes =
			getNextStatement();
			if (defined nextStatement() && ${nextStatement()} eq '{') {
				Append($collectionNode, parseAccoBloc());
			}
			else {
				parseExpression($collectionNode, [ \&isNextClosingParenthesis, \&isNextNewLine, \&isNextMatch ])
			}
		}
		# we assume that sub-methods without parameters are not parsed
		# for example: subMethodA & subMethodB are not parsed
		# myMethod().subMethodA.subMethodB
		elsif (defined nextStatement() && ${nextStatement()} =~ /^\./m
			&& $context ne 'CTX_RETURN_TYPE' && !isNextMethodCallOrCollection()) {
			my $stmtElt = ${nextStatement()};
			my $unknownNode = Node(UnknowKind, \$stmtElt);
			Append($collectionNode, $unknownNode);
			getNextStatement();
		}

		# list concat
		# list ++ {xxx} ++ list2
		# list ::: list2
		purgeLineReturn();
		while (defined nextStatement()
			&& (${nextStatement()} eq '++' || ${nextStatement()} eq ':::' || ${nextStatement()} eq '{')) {
			if (defined nextStatement() && ${nextStatement()} eq '{') {
				$proto .= ${parsePairing()};
			}
			else {
				$proto .= ${getNextStatement()};
			}
			purgeLineReturn();
		}

		SetName($collectionNode, $name);
		SetEndline($collectionNode, getStatementLine());
		sendContextEvent(CTX_LEAVE);

		purgeLineReturn();
		return $collectionNode;
	}
	return undef;
}

sub simulateParseCollection() {
	my $idx = 0;
	my $idx_nonblank = 0;
	my $nb_element = 0;
	my $enclosedParenthesis = 0;
	# fix limit to avoid infinite loop issue
	my $threshold = 500;
	my $name;
	while (defined nextStatement($idx) && ${nextStatement($idx)} ne '(') {
		$name .= ${nextStatement($idx)};
		$idx++;
	}
	if (defined $name && ($name =~ /$CONTROL_FLOW_STATEMENTS/ || $name =~ /$STRUCTURAL_STATEMENTS/)) {
		return 0;
	}
	if (defined nextStatement($idx) && ${nextStatement($idx)} eq '(') {
		$idx++;
		# first element
		$nb_element++ if ($nb_element == 0);
	}
	while (defined nextStatement($idx) && ((${nextStatement($idx)} ne ')'
		|| $enclosedParenthesis > 0 || $idx_nonblank >= $threshold))) {

		# detect char non blank
		if (defined nextStatement($idx) && ${nextStatement($idx)} !~ /^[\s]+$/m
			&& ${nextStatement($idx)} ne "") {
			$idx_nonblank++;
		}

		if (defined nextStatement($idx) && ${nextStatement($idx)} eq '(') {
			$enclosedParenthesis++;
		}
		elsif (defined nextStatement($idx) && ${nextStatement($idx)} eq ')') {
			$enclosedParenthesis--;
		}
		elsif (defined nextStatement($idx) && ${nextStatement($idx)} eq ',') {
			$nb_element++;
		}
		$idx++;
	}

	return $nb_element;
}

##################################################################
#              MAP
##################################################################
sub isNextMap() {
	if ((defined nextStatement() && ${nextStatement()} eq 'map')
		|| defined nextStatement(1) && ${nextStatement(1)} eq 'map') {
		return 1;
	}
	elsif ((defined nextStatement(1) && ${nextStatement(1)} eq '->')
		|| (defined nextStatement(1) && ${nextStatement(1)} =~ /^\s*$/m
		&& defined nextStatement(2) && ${nextStatement(2)} eq '->')) {
		return 2;
	}
	return undef;
}

sub parseMap() {
	if (isNextMap()) {
		my $result = isNextMap();

		my $proto = "";
		my $mapNode = Node(MapKind, \$proto);
		my $endingPattern = ')';

		SetLine($mapNode, getStatementLine());
		# .map() method
		if ($result == 1) {
			# consumes map
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq 'map') {
				getNextStatement();
			}
			elsif (defined nextStatement(1) && ${nextStatement(1)} eq 'map') {
				$proto = ${getNextStatement()};
				getNextStatement();
			}
			purgeLineReturn();
			# .map {...}
			if (defined nextStatement() && ${nextStatement()} eq '{') {
				Append($mapNode, parseAccoBloc());
			}
			elsif (defined nextStatement() && ${nextStatement()} eq '(') {
				# .map(...)
				# consumes (
				getNextStatement();
				parseExpression($mapNode, [ \&isNextComma, \&isNextClosingParenthesis ]);
				purgeLineReturn();
				# consumes )
				getNextStatement();
			}
			else {
				# map xxx
				# map }
				parseExpression($mapNode, [ \&isNextNewLine, \&isNextClosingParenthesis, \&isNextClosingAcco ]);
			}

			# .map(...).method
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} =~ /^\.\w+/) {
				my $name = ${getNextStatement()};
				my $stmt;
				my $node = Node(MethodCallKind, \$stmt);
				SetName($node, $name);
				Append($mapNode, $node);
				purgeLineReturn();
				if (defined nextStatement() && ${nextStatement()} eq '(') {
					$stmt = ${parsePairing()};
				}
			}
		}
		else {
			# key -> value
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '(') {
				# consumes (
				getNextStatement();
			}
			elsif (defined nextStatement() && ${nextStatement()} eq '{') {
				$endingPattern = '}';
				# consumes {
				getNextStatement();
			}

			# get the key
			while (defined nextStatement() && ${nextStatement()} !~ /\-\>/) {
				$proto .= ${getNextStatement()};
			}

			# get the value
			if ($endingPattern eq '}') {
				parseExpression($mapNode, [ \&isNextComma, \&isNextClosingCurlyBrace ]);
			}
			else {
				parseExpression($mapNode, [ \&isNextComma, \&isNextClosingParenthesis ]);
			}
		}

		SetEndline($mapNode, getStatementLine());
		purgeLineReturn();
		return $mapNode;
	}
	return undef;
}

##################################################################
#              TRY CATCH FINALLY
##################################################################
sub isNextTryCatch() {
	if (defined nextStatement() && ${nextStatement()} eq 'try') {
		return 1;
	}
	return undef;
}

sub parseTryCatch() {
	if (isNextTryCatch()) {
		# consumes try
		getNextStatement();

		my $tryNode = Node(TryKind, \$NullString);

		SetLine($tryNode, getStatementLine());

		# get try expression
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			Append($tryNode, parseAccoBloc());
		}
		else {
			parseExpression($tryNode);
		}

		# get catch expression
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq 'catch') {
			# consumes catch
			getNextStatement();
			my $catchNode = Node(CatchKind, \$NullString);
			SetLine($catchNode, getStatementLine());
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '{') {
				Append($catchNode, parseAccoBloc());
			}
			else {
				parseExpression($catchNode);
			}
			Append($tryNode, $catchNode);
		}

		# get finally expression
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq 'finally') {
			# consumes finally
			getNextStatement();
			my $finallyNode = Node(FinallyKind, \$NullString);
			SetLine($finallyNode, getStatementLine());
			purgeLineReturn();
			if (defined nextStatement() && ${nextStatement()} eq '{') {
				Append($finallyNode, parseAccoBloc());
			}
			else {
				parseExpression($finallyNode);
			}
			Append($tryNode, $finallyNode);
		}

		SetEndline($tryNode, getStatementLine());

		purgeLineReturn();
		return $tryNode;
	}
	return undef;
}

##################################################################
#              CASE
##################################################################
sub isNextCase() {
	if (defined nextStatement() && ${nextStatement()} eq 'case') {
		return 1;
	}
	return undef;
}

sub parseCase() {
	if (isNextCase()) {
		# consumes case
		getNextStatement();
		my $proto = "";
		my $caseNode = Node(CaseKind, \$proto);

		SetLine($caseNode, getStatementLine());

		# get condition
		my $condStmt;
		my $condition = Node(ConditionKind, \$condStmt);
		while (defined nextStatement() && ${nextStatement()} ne '=>') {
			$condStmt .= ${getNextStatement()};
		}

		Append($caseNode, $condition);

		# consumes =>
		getNextStatement();

		# get case expression
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			Append($caseNode, parseAccoBloc());
		}
		# case e => <html>...</html>
		elsif (defined nextStatement() && ${nextStatement()} eq '<') {
			while (defined nextStatement() && ${nextStatement()} eq '<') {
				my $res = skipHTMLSample();
				last if !defined $res;
			}
		}
		# empty case expression
		elsif (defined nextStatement() && ${nextStatement()} ne '}') {
			while (defined nextStatement() && ${nextStatement()} ne '}' && ${nextStatement()} ne 'case') {
				Append($caseNode, Lib::ParseUtil::tryParse_OrUnknow(\@expressionContent));
				#parseExpression($caseNode, [ \&isNextCase, \&isNextClosingParenthesis ]);
			}
		}

		SetEndline($caseNode, getStatementLine());

		purgeLineReturn();
		return $caseNode;
	}
	return undef;
}

##################################################################
#              MATCH
##################################################################
sub isNextMatch() {
	if (defined nextStatement() && ${nextStatement()} eq 'match') {
		return 1;
	}
	return undef;
}

sub parseMatch() {
	if (isNextMatch()) {
		# consumes match
		getNextStatement();

		my $matchNode = Node(MatchKind, \$NullString);
		SetLine($matchNode, getStatementLine());

		# get match expression
		purgeLineReturn();
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			Append($matchNode, parseAccoBloc());
		}
		else {
			print STDERR "[parseMatch] ERROR : missing opening {, opened at line " . getStatementLine() . "\n";
		}

		SetEndline($matchNode, getStatementLine());

		purgeLineReturn();
		return $matchNode;
	}
	return undef;
}

##################################################################
#              WITH
##################################################################
sub isNextWith() {
	if (defined nextStatement() && ${nextStatement()} eq 'with') {
		return 1;
	}
	return undef;
}

sub parseWith() {
	if (isNextWith()) {
		# consumes with
		getNextStatement();
		my $proto;
		my $withNode = Node(WithKind, \$proto);
		SetLine($withNode, getStatementLine());

		# get with name
		my $name = ${Lib::ParseUtil::getSkippedBlanks()} . ${getNextStatement()};
		purgeLineReturn();
		while (defined nextStatement() && (${nextStatement()} =~ /\[|\(/)) {
			$name .= ${parsePairing()};
			purgeLineReturn();
		}
		SetName($withNode, $name);
		purgeLineReturn();
		# get with expression
		if (defined nextStatement() && ${nextStatement()} eq '{') {
			Append($withNode, parseAccoBloc());
		}

		SetEndline($withNode, getStatementLine());

		purgeLineReturn();
		return $withNode;
	}
	return undef;
}

##################################################################
#              ASSERT
##################################################################
sub isNextAssert() {
	if (defined nextStatement() && ${nextStatement()} eq 'assert') {
		return 1;
	}
	return undef;
}

sub parseAssert() {
	if (isNextAssert()) {
		# consumes assert
		getNextStatement();
		my $proto;
		my $assertNode = Node(AssertKind, \$proto);
		SetLine($assertNode, getStatementLine());

		purgeLineReturn();
		# get assert expression
		if (defined nextStatement() && ${nextStatement()} eq '(') {
			my $resultPairing = ${parsePairing()};
			Lib::NodeUtil::SetXKindData($assertNode, 'parameter', $resultPairing);
		}

		SetEndline($assertNode, getStatementLine());

		purgeLineReturn();
		return $assertNode;
	}
	return undef;
}

##################################################################
#              REQUIRE
##################################################################
sub isNextRequire() {
	if (defined nextStatement() && ${nextStatement()} eq 'require') {
		return 1;
	}
	return undef;
}

sub parseRequire() {
	if (isNextRequire()) {
		# consumes require
		getNextStatement();
		my $proto;
		my $requireNode = Node(RequireKind, \$proto);
		SetLine($requireNode, getStatementLine());

		purgeLineReturn();
		# get require expression
		if (defined nextStatement() && ${nextStatement()} eq '(') {
			my $resultPairing = ${parsePairing()};
			Lib::NodeUtil::SetXKindData($requireNode, 'parameter', $resultPairing);
		}

		SetEndline($requireNode, getStatementLine());

		purgeLineReturn();
		return $requireNode;
	}
	return undef;
}

##################################################################
#              PAIRING
##################################################################
sub isNextPairing {
	if (defined nextStatement() && ${nextStatement()} =~ /^([\{\(\[])$/m) {
		my $pattern = $1;
		return $pattern;
	}
	return undef;
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
			print STDERR "[parsePairing] ERROR : missing closing $closing, opened at line $line\n";
		}
		elsif ($$next eq $closing) {
			$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}

		return \$statement;
	}
	return undef;
}

# count into statement how opening parenthesis are present
sub countEnclosed($) {
	my $proto = shift;
	my $enclosed = 0;
	while ($proto =~ /\(|\[/g) {
		$enclosed++;
	}
	while ($proto =~ /\)|\]/g) {
		$enclosed--;
	}
	return $enclosed;
}

sub splitScala($) {
	my $r_view = shift;
	# first member of regex  \`[^\`]*\` is to avoid literal identifier issues
	my @statements = split /(\`[^\`]*\`|$Scala_SEPARATOR|$STRUCTURAL_STATEMENTS|$METHODS_STATEMENTS|$STATEMENT_BEGINNING_PATTERNS|$NEVER_A_STATEMENT_BEGINNING_PATTERNS|$CONTROL_FLOW_STATEMENTS|$COLLECTION_STATEMENTS|$re_MODIFIERS)/sm, $$r_view;

	if (scalar @statements > 0) {
		# if the last statement is a Null statement, it should be removed
		# because it is not significant.
		if ($statements[-1] !~ /\S/) {
			pop @statements;
		}
	}
	return \@statements;
}

sub ParseScala($) {
	my $r_view = shift;

	my $r_statements = splitScala($r_view);

	# only spaces and tabs will be considered as blanks in a statement (\n are considered as SEPARATORS)
	Lib::ParseUtil::setBlankRegex('[ \t]');

	Lib::ParseUtil::InitParser($r_statements);

	initContext();

	# pass all beginning empty lines
	while (defined nextStatement() && ${nextStatement()} eq "\n") {
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
		my @NodesList = GetNodesByKind($node, $kind);
		$H_KindsLists{$kind} = \@NodesList;
	}

	$views->{'KindsLists'} = \%H_KindsLists;
}

##################################################################
#              MAIN
##################################################################

# description: Scala parse module Entry point.
sub Parse($$$$)
{
	my ($fichier, $vue, $couples, $options) = @_;
	my $status = 0;

	$StringsView = $vue->{'HString'};

	Lib::ParseUtil::registerParseUnknow(\&parseUnknow);

	#    my $statements =  $vue->{'statements_with_blanks'} ;

	# launch first parsing pass : strutural parse.
	my ($ScalaNode, $Artifacts) = ParseScala(\$vue->{'code'});

	if (defined $options->{'--print-tree'}) {
		Lib::Node::Dump($ScalaNode, *STDERR, "ARCHI");
	}
	if (defined $options->{'--print-test-tree'}) {
		print STDERR ${Lib::Node::dumpTree($ScalaNode, "ARCHI")};
	}

	$vue->{'structured_code'} = $ScalaNode;
	$vue->{'artifact'} = $Artifacts;

	# pre-compute some list of kinds :
	preComputeListOfKinds($ScalaNode, $vue, [ MethodKind, IfKind, ElseKind, CaseKind, FunctionDeclarationKind, ClassKind, ObjectKind, TraitKind, ForKind, WhileKind, DoWhileKind, MatchKind, TryKind, ReturnKind, VarKind ]);

	#TSql::ParseDetailed::ParseDetailed($vue);
	if (defined $options->{'--print-artifact'}) {
		for my $key (keys %{$vue->{'artifact'}}) {
			print "-------- $key -----------------------------------\n";
			print $vue->{'artifact'}->{$key} . "\n";
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

		if ($$r_previousToken =~ /$NEVER_A_STATEMENT_ENDING_PATTERNS\s*\Z/sm) {
			return 0;
		}

		# if the next token can syntactically not begin a new statement, return false.
		if (${nextStatement()} =~ /^\s*$NEVER_A_STATEMENT_BEGINNING_PATTERNS/sm) {
			return 0;
		}

		# CONTROL FLOW STATEMENT
		# ----------------------
		if (${nextStatement()} =~ /$CONTROL_FLOW_STATEMENTS/) {
			return 1;
		}

		# STRUCTURAL STATEMENTS
		# ----------------------
		if (${nextStatement()} =~ /$STRUCTURAL_STATEMENTS/) {
			return 1;
		}

		# MODIFIERS
		# ----------------------
		if (${nextStatement()} =~ /$re_MODIFIERS/) {
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
		print "[parseUnknow] ERROR : encountered unexpected statement : " . $$stmt . " at line " . getStatementLine() . "\n";

		my $node = Node(UnknowKind, $stmt);
		SetLine($node, getStatementLine());
		return $node;
	}

	# memorize the statement being treated.
	$lastStatement = nextStatement();

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


