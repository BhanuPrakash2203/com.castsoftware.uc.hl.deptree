package Clojure::ParseClojure;
# les modules importes
use strict;
use warnings;

use Erreurs;

use CountUtil;

use Lib::Node; # qw( Leaf Node Append );
use Lib::NodeUtil ;
use Lib::NodeUtil qw( SetName SetStatement SetLine GetLine SetEndline GetEndline);
use Lib::ParseUtil;
use Lib::ParseArguments;

use Clojure::ClojureNode;

my $DEBUG = 0;

my @rootContent = ( 
			\&parseEnclosed,
);

my @formContent = (
			\&parseEnclosed,
			\&parseQuote,
			\&parseDispatch,
			#\&parseOpArith,
			#\&parseSymbol,
);

my $NullString = '';

my $SYMBOL_CHARS = qr/[\w\.\?\/\-:]/;
my $NOT_SYMBOL_CHARS = qr/[^\w\.\?\/\-:]/;

#my $SYMBOL = qr/[A-Za-z_](?:$SYMBOL_CHARS)*(?=$NOT_SYMBOL_CHARS|\z)/;
my $BASE_SYMB = '\s,\[\(\{\)\}\]';
my $SYMBOL = qr/[^\d${BASE_SYMB}][^${BASE_SYMB}]*/;
my $SEPARATOR = '(?:[,])';
my $NOT_SEPARATOR = '(?:[^,])';
my $ITEM = qr/[^\s,]/;
my $OP_ARITH = qr/(?:\+|\-|\*|\/|\b(?:inc|dec|rem|min|max)(?=$NOT_SYMBOL_CHARS|\z))/;


my $StringsView = undef;

my %KIND = (
	"import"	=> ImportKind,
	"def" 		=> DefKind,
	"defn" 		=> FunctionKind,
	"defn-" 	=> FunctionKind,
	"fn"		=> AnonymousKind,
	"if" 		=> IfKind,
	"if-let" 	=> IfKind,
	"if-some"	=> IfKind,
	"if-not" 	=> IfKind,
	"cond" 		=> SwitchKind,
	"condp"		=> SwitchpKind,
	"cond->"	=> SwitchArrowKind,
	"cond->>"	=> SwitchArrowKind,
	"case"		=> SwitchCaseKind,
	"->"		=> PipeKind,
	"->>"		=> PipeKind,
	"when"		=> WhenKind,
	"when-let"	=> WhenKind,
	"when-some"	=> WhenKind,
	"when-first"=> WhenKind,
	"while"		=> WhileKind,
	"loop"		=> LoopKind,
	"ns"		=> NamespaceKind,
	"let"		=> LetKind,
);

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
	);

sub getCurrentContext() {
	return $context[-1];
}

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

################### DIVERS  #################

sub stepOverComment() {
	if (${nextStatement()} =~ /^\s*CHAINE_\d+/gc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
	}
}

##################################################################
#              EXPRESSION
##################################################################
sub parseRawExpression() {
	my $expression = "";
	
	my $stmt;
	while ((defined ($stmt=nextStatement()))) {
		# parse enclosed sunexpression if any
		my $enclosed = parseRawEnclosed();
		if (! defined $enclosed) {
			# get the next statement until encountering separator
			if ($$stmt =~ /^\s*(${ITEM}+((?:\s|${SEPARATOR})*))/g) {
				$expression .= $1;
				Lib::ParseUtil::splitAndFocusNextStatementOnPos();
				
				# 
				if ($2 ne "") {
					last;
				}
				
				# we point now on the next non-blank following our pattern.
				# So check if our pattern and the following were separated by a separator.
				##my $skippedBlanks = Lib::ParseUtil::getSkippedBlanks();
				##if (($$skippedBlanks =~ /$SEPARATOR/) || (${nextStatement()} =~ /$SEPARATOR/)) {
				##	last;
				##}
				##else {
				##	$expression .= $$skippedBlanks;
				##}
			}
		}
		else {
			# sub expression in enclosed
			$expression .= $$enclosed;
			
			# Assume that two adjacent enclosed patterns cannot belong to the same expression
			last;
		}
	}
	
	return \$expression;
}

sub removeSeparator() {
	if ((defined nextStatement()) && (${nextStatement()} =~ /^(?:\s*${SEPARATOR})+/gc)) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		return 1;
	}
	return 0;
}

##################################################################
#              NEXT ITEM
##################################################################

# IMPORTANT : assume the next statement is not a split element that introduced a particular parsing process (like parenthese, ...)

sub getNextItem() {
	
	if ((defined nextStatement()) && (${nextStatement()} =~ /^(?:\s*${SEPARATOR})+/gc)) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		Lib::Log::ERROR("Removing unmanaged separator at line ".getStatementLine);
	}
	
	# The end of next item is the end of the next statement OR the first blank or separator encountered
	# separtors are trashed if any.
	if (${nextStatement()} =~ /^(\s*)(${ITEM}+)(?:\s|${SEPARATOR})*/mgc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		return ($1, # blank indent
		        $2  # non blank item
		        ) 
	}
	Lib::Log::ERROR("Next item (".${nextStatement()}.") is empty at line ".getNextStatementLine());
	
	return (undef, undef);
}

##################################################################
#              NEXT ELEMENT
##################################################################
sub getNextElement() {
	
	my $quote = "";
	my $indent = "";
	if (${nextStatement()} =~ /^(\s*)(['`~]+)/gc) {
		$indent = $1;
		$quote .= $2;
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
	}
	
	# no elsif because the dispatch can follow a quote, it is not exclusive. EX: '#{__meta __hash __hasheq __extmap)
	if (${nextStatement()} =~ /^(\s*)(#)$/mgc) {
		# recognize dispatch only if it is the last (and the fisrt) character of the statement, meaning it is probably followed by ( or {
		$indent = $1;
		$quote .= $2;
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
	}
	
	my $next = parseRawEnclosed();
	
	if (defined $next) {
		my $element = $quote . $$next;
#print STDERR "ELEMENT : $element\n";
		return \$element;
	}
	
	my $item;
	($indent, $item) = getNextItem();
	
	my $element = $quote . $item;
#print STDERR "ELEMENT : $element\n";
	return \$element;
}

##################################################################
#              APPEND NEXT CHILD
##################################################################
sub appendNextChild($) {
	my $parent = shift;
	
	my $subNode = Lib::ParseUtil::tryParse(\@formContent);
			
	if (defined $subNode) {
		Append($parent, $subNode);
		#$$statement .= Clojure::ClojureNode::nodeLink($subNode);
	}
	else {
		my $item = getNextElement();
		if (defined $item ) {
			my $stmt = GetStatement($parent);
			$$stmt .= $$item;
		}
		else {
			Lib::Log::ERROR("Unknow syntax (".${nextStatement()}.") for form element at line ".GetStatementLine());
			last;
		}
	}
}

##################################################################
#              UNKNOW
##################################################################
sub parseUnknow() {
	
	my ($indent, $item) = getNextItem();
	#my $statement = getNextStatement();
	
	my $unknowNode = Node(UnknowKind, \$item);
	SetLine($unknowNode, getStatementLine());
	my $indentation = ${Lib::ParseUtil::getBlankedIndentation()}.$indent;
	Clojure::ClojureNode::setClojureKindData($unknowNode, 'indentation', $indentation);
	return $unknowNode;
}

##################################################################
#              CONDITION
##################################################################
sub parseCondition() {
	my $condNode = Node(ConditionKind, createEmptyStringRef());
	SetLine($condNode, getNextStatementLine());
	my $indentation = ${Lib::ParseUtil::getNextBlankedIndentation()};
	Clojure::ClojureNode::setClojureKindData($condNode, 'indentation', $indentation);
	
	appendNextChild($condNode);
	return $condNode;
}

##################################################################
#              OPERATOR ARITH
##################################################################

sub parseOpArith() {
	if (${nextStatement()} =~ /^\s*($OP_ARITH)/gc) {
		my $oparith = $1;
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		my $stmt = "";
		my $oparithNode = Node(OpArithKind, \$stmt);
		SetLine($oparithNode, getStatementLine());
		SetName($oparithNode, $oparith);
		
		return $oparithNode;
	}
	return undef
}

##################################################################
#              NAME
##################################################################
sub parseSymbol() {
	if (${nextStatement()} =~ /^\s*($SYMBOL)/gc) {
		my $symbol = $1;
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		my $stmt = "";
		my $symbolNode = Node(SymbolKind, \$stmt);
		SetLine($symbolNode, getStatementLine());
		SetName($symbolNode, $symbol);
		
		return $symbolNode;
	}
	return undef
}

##################################################################
#              Quote
##################################################################
sub parseQuote() {
	# ' -> quote
	# ` -> syntax quote
	# ~ -> unquote
	if (${nextStatement()} =~ /^(\s*)(['`~])/gc) {
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		my $stmt = "";
		my $quoteNode = Node(QuoteKind, \$stmt);
		SetLine($quoteNode, getStatementLine());
		SetName($quoteNode, $2);
		my $indentation = ${Lib::ParseUtil::getBlankedIndentation()}.$1;
		Clojure::ClojureNode::setClojureKindData($quoteNode, 'indentation', $indentation);
		
		# parse quoted object
		my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@formContent);
		Append($quoteNode, $subNode);
		
		return $quoteNode;
	}
	return undef
}

##################################################################
#              DEF
##################################################################
sub parseDefChildren($$) {
	my $defNode = shift;
	my $closing = shift;
	
	my $statement = GetStatement($defNode);
	my $stmt;
	
	my $metadata = parseMetaData();
	
	Clojure::ClojureNode::setClojureKindData($defNode, 'metadata', $metadata);
	
	#if (defined ($stmt = nextStatement()) && ($$stmt ne $closing) && ($$stmt =~ /\G\s*($SYMBOL)/gc)) {
	if (defined nextStatement()) {
		SetName($defNode, ${getNextElement()});
		#Lib::ParseUtil::splitAndFocusNextStatementOnPos();
	}
	else {
		Lib::Log::ERROR("missing name for def at line ". GetLine($defNode)." !!");
	}
	
	# trash comment doc if any
	stepOverComment();
	
	while (defined ($stmt = nextStatement()) && $$stmt ne $closing) {
		my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@formContent);
		#if (defined $subNode) {
			Append($defNode, $subNode);
		#	$$statement .= Clojure::ClojureNode::nodeLink($subNode);
		#}
		#else {
		#	$$statement .= ${getNextStatement()};
		#}
	}
}

##################################################################
#              META DATA
##################################################################

my $REG_META_WITHOUT_MAPPING = qr/^(\s*)(\^)/;
my $REG_META_WITH_MAPPING = qr/^(\s*)(\{|\^)/;

sub parseMetaData(;$) {
	my $allowMapping = shift;
	
	my %H_data = ();
	my $statement = "";
	
	my $regexp = $REG_META_WITHOUT_MAPPING;
	
	# { ... }
	if ($allowMapping) {
		$regexp = $REG_META_WITH_MAPPING;
	}
	
	# ^{ ... }
	# ^:<ident>
	# ^<ident>
	#while (${nextStatement()} =~ /^(\s*)(\{|\^)/) {
	while (${nextStatement()} =~ /$regexp/m) {
		$statement .= ${Lib::ParseUtil::getSkippedBlanks()};
		$statement .= $1.${parseRawExpression()};
	}
	return \$statement;
}

##################################################################
#              LET
##################################################################

sub parseVarMap($) {
	my $H_vars = shift;
	
	#
	# Parse a map of variable, followed by a variable or a map of data.
	#
	# EXAMPLE 1: {ao1 :a {ai1 :a} :b} sample-map
    # EXAMPLE 2: {ao2 :a {ai2 :a :as m1} :b :as m2} {:a 1 :b {:a 2}
    # EXAMPLE 3: {ao3 :a {ai3 :a :as m} :b :as m} sample-map
    # EXAMPLE 4: {{ai4 :a :as m} :b ao4 :a :as m} sample-map
	#
	
	# trash '{'
	getNextStatement();
	
	my $beginLine = getStatementLine();
	
	# parse VARIABLES DECLARATION ( a serie of couple var/init
	#----------------------------
	my $stmt;
	my $line;
	while ((defined ($stmt=nextStatement())) && ($$stmt ne "}")) {
		
		# VAR
		
		my $var;
		if (${nextStatement()} eq '{') {
			# Variables are declared with a map ...
			$line = getNextStatementLine();
			my $varMap = getNextElement();
#print "VAR MAP = $$varMap\n";
			Lib::Log::WARNING("Too complex variable declaration (map inside map) : $$varMap at line $line");
		}
		else {
			# single variable 
			$var = getNextElement();
#print "VAR = $$var\n";
			$H_vars->{$$var} = undef;
		}
		
		# INIT
		
		if (${nextStatement()} eq '{') {
			# destructuring initialisation
			$line = getNextStatementLine();
			my $dataMap = getNextElement();
#print "--> INIT MAP = $$dataMap\n";
			Lib::Log::WARNING("Too complex destructuring init : $$dataMap at line $line");
		}
		else {
			# single vlaue
			my $value = getNextElement();
#print "---> INIT = $$value\n";
			if (defined $var) {
				$H_vars->{$$var} = $$value;
			}
		}		
	}

	if (${nextStatement()} eq '}') {
		getNextStatement();
	}
	else {
		Lib::Log::ERROR("Missing closing '}' for variable map inside let at line $beginLine");
	}		
		
	# parse DATA INITIALISATION 
	#---------------------------
	# NOTE : value cannot be assigned to variable. We should for that parse the data structure.
	if (${nextStatement()} eq '{') {
		# destructuring initialisation
		my $dataMap = getNextElement();
#print "--> DATA MAP = $$dataMap\n";
	}
	else {
		# single vlaue
		my $value = getNextElement();
#print "---> DATA = $$value\n";
	}
}

sub parseVarVector($) {
	my $H_vars = shift;
	
	# trash '['
	getNextStatement();
	
	my $beginLine = getStatementLine();
	
	# VAR
	
	my $stmt;
	my $line;
	while ((defined ($stmt=nextStatement())) && ($$stmt ne "]")) {
		my $var;
		if (${nextStatement()} eq '[') {
			# Variables are declared with a vector ...
			$line = getNextStatementLine();
			my $varVector = getNextElement();
#print "VAR MAP = $$varVector\n";
			Lib::Log::WARNING("Too complex variable declaration (vector inside vector) : $$varVector at line $line");
		}
		else {
			# single variable 
			$var = getNextElement();
#print "VAR = $$var\n";
			$H_vars->{$$var} = undef;
		}
	}
	
	if (${nextStatement()} eq ']') {
		getNextStatement();
	}
	else {
		Lib::Log::ERROR("Missing closing '}' for variable map inside let at line $beginLine");
	}
	
	# DATA
	
	if (${nextStatement()} eq '[') {
		# data are declared with a vector ...
		$line = getNextStatementLine();
		my $dataVector = getNextElement();
#print "VAR MAP = $$dataVector\n";
	}
	else {
		# single variable
		my $var = getNextElement();
#print "VAR = $$var\n";
	}
}

sub parseLetChildren($) {
	my $letNode = shift;
	
	my $statement = GetStatement($letNode);
	my $stmt;
	
	if (${nextStatement()} eq "[") {
		# trash [
		getNextStatement();

		# PARSE VARIABLES LIST
		my %H_var = ();
		while ((defined ($stmt=nextStatement())) && $$stmt ne "]") {
			
			# If any, trash metadata ...
			parseMetaData();
			last if (${nextStatement()} eq "]");
			
			if ($$stmt eq '{' ) {
				my $mapVar = parseVarMap(\%H_var);
#print STDERR "MAP VAR = $$mapVar\n";
			}
			elsif ($$stmt eq '[' ) {
				my $vectorVar = parseVarVector(\%H_var);
#print STDERR "MAP VAR = $$vectorVar\n";
			}
			else {
				my $varName = ${getNextElement()};
#print STDERR "LET VAR = $varName\n";
if (! defined nextStatement()) {
	print STDERR "PROBLEM AT LINE ".GetLine($letNode)."\n";
}
				if (${nextStatement()} eq "]") {
					Lib::Log::ERROR("missing init value for variable $varName in let at line ".GetLine($letNode));
					last;
				}
			
				# If any, trash metadata ...
				parseMetaData();
				last if (${nextStatement()} eq "]");
			
				my $value = getNextElement();
				$H_var{$varName} = $value;
#print STDERR "   ===> INIT = $$value\n"
			}
			
			#if ((defined nextStatement()) && (${nextStatement()} =~ /^\s*${SEPARATOR}+/gc)) {
			#	Lib::ParseUtil::splitAndFocusNextStatementOnPos();
			#}
			removeSeparator();
		}
	
		if ((defined ($stmt=nextStatement())) && $$stmt eq "]") {
			getNextStatement();
		}
		else {
			Lib::Log::ERROR("missing closing bracket for let line ".GetLine($letNode));
		}
	
		Clojure::ClojureNode::setClojureKindData($letNode, 'variables', \%H_var);
	}
	else {
		my $varList = getNextElement();
		Lib::Log::WARNING("missing var list in let at line ".GetLine($letNode)." Assume it is provided by $$varList");
	}
	
	# PARSE BODY
	while (defined ($stmt = nextStatement()) && $$stmt ne ")") {
		my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@formContent);
		#if (defined $subNode) {
		Append($letNode, $subNode);
	} 
#print STDERR "NAMESPACE = $$statement\n";
}

##################################################################
#              NAMESPACE
##################################################################

sub parseBracketModuleDefinition() {
	# trash '['
	getNextStatement();
	
	my %moduleDef = ();
	my $moduleName = getNextElement();
	my $definition = "";
	
	my $stmt;
	while ( (defined ($stmt = nextStatement())) && ($$stmt ne ']')) {
		$definition .= " ".${getNextElement()};
	}
	
	$moduleDef{'name'} = $$moduleName;
	$moduleDef{'definition'} = $definition;
	
	# trash ']'
	if (${nextStatement()} eq ']') {
		getNextStatement();
	}
	
	return \%moduleDef;
}

sub parseParenthesesModuleDefinition() {
	# trash '('
	getNextStatement();
	
	my $stmt;
	my @modules;
	my $base;
	while ( (defined ($stmt = nextStatement())) && ($$stmt ne ')')) {
		if (! defined $base) {
			$base = ${getNextElement()};
		}
		else {
			push @modules, "$base.".${getNextElement()};
		}
		
		#print STDERR "WARNING : Got a module reference ($module) inside parentheses, but don't know how to consider it !!\n";
	}
	
	# trash ']'
	if (${nextStatement()} eq ')') {
		getNextStatement();
	}
	
	return \@modules;
}

sub parseReferences() {
	my @refs = ();
	my $stmt;
	while ( (defined ($stmt = nextStatement())) && ($$stmt ne ')')) {
		
		my $moduleDef;
		my $moduleName;
		
		if ($$stmt eq '[') {
			$moduleDef = parseBracketModuleDefinition();
			push @refs, $moduleDef;
		}
		elsif ($$stmt eq '(') {
			my $modules = parseParenthesesModuleDefinition();
			for my $mod (@$modules) {
				$moduleDef = {};
				$moduleDef->{'definition'} = "";
				$moduleDef->{'name'} = $mod;
				push @refs, $moduleDef;
			}
		}
		else {
			my $name = ${getNextElement()};
			if ($name !~ /^:/m) {
				$moduleDef = {};
				$moduleDef->{'definition'} = "";
				$moduleDef->{'name'} = $name;
				push @refs, $moduleDef;
			}
		}
	}
	return \@refs;
}

sub parseNamespaceChildren($) {
	my $nsNode = shift;
	
	my $statement = GetStatement($nsNode);
	my $stmt;
	my $references = {};
	Clojure::ClojureNode::setClojureKindData($nsNode, 'references', $references);
	my $metadata = parseMetaData();
	
	my ($indent, $name) = getNextItem();
	SetName($nsNode, $name);
	my $line;
	
	while (defined ($stmt = nextStatement()) && $$stmt ne ")") {
		$line = getNextStatementLine();
		
		if (	(${nextStatement()} eq '(') && 
				(${Lib::ParseUtil::nextNonBlank()} =~ /^\s*(:(?:refer-clojure|require|use|import|load|gen-class))(?:[\s+]|$)/mgc)) {
					
			# trash '('
			getNextStatement();
			
			my $importKeyword = $1;
			
			# remove keyword from statement following the '('
			Lib::ParseUtil::splitAndFocusNextStatementOnPos();
			
			$references->{$1} = parseReferences();
			
			if ((defined nextStatement()) && (${nextStatement()} eq ')')) {
				getNextStatement();
			}
		}
		else {
			my $element = getNextElement();
			#if ($$element =~ /^\(\s*(:(?:refer-clojure|require|use|import|load|gen-class))\s+/m) {
			#	$references->{$1} = $element;
			#}
			#else {
			#	print STDERR "Unknow reference option ($$element) in namespace\n";
			#}
			$$statement .= $$element;
		}
	} 
#print STDERR "NAMESPACE = $$statement\n";
}

##################################################################
#              DEFN
##################################################################

sub parseParameters() {
	# trash [
	getNextStatement();
	
	my $line = getStatementLine();
	
	my $stmt;
	my @params = ();
	while ((defined ($stmt=nextStatement())) && $$stmt ne "]") {
		push @params, ${getNextElement()};
	}
	
	if ((defined ($stmt=nextStatement())) && $$stmt eq "]") {
		getNextStatement();
	}
	else {
		Lib::Log::ERROR("missing closing bracket for parameters list at line $line");
	}
	
	return \@params;
}

sub parseArityContent($) {
	my $arityNode = shift;

	my $stmt;
	
	# Check parameters
	if (${nextStatement()} =~ /^\s*\[/) {
		
		my $indentation = ${Lib::ParseUtil::getNextBlankedIndentation()};
#print STDERR "PARAM INDENTATION = <$indentation>\n";
		Clojure::ClojureNode::setClojureKindData($arityNode, 'params_indentation', $indentation);
		
		my $params = parseParameters();
		Clojure::ClojureNode::setClojureKindData($arityNode, 'params', $params);
		Clojure::ClojureNode::setClojureKindData($arityNode, 'params_end_line', getStatementLine());
	}
	
	# Check prepost map
	if (${nextStatement()} eq "{") {
		my $prepost = parseRawEnclosed();
		Clojure::ClojureNode::setClojureKindData($arityNode, 'prepost', $prepost);
#print STDERR "PRE / POST = $$prepost\n";
	}
	
	Clojure::ClojureNode::setClojureKindData($arityNode, 'lineBodyBegin', getNextStatementLine());

    # Parse the BODY
	my $indentation = ${Lib::ParseUtil::getNextBlankedIndentation()};
#print STDERR "BODY INDENTATION  = <$indentation>\n";
	Clojure::ClojureNode::setClojureKindData($arityNode, 'body_indentation', $indentation);

	while (defined ($stmt = nextStatement()) && $$stmt ne ")") {
		my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@formContent);
		#if (defined $subNode) {
			Append($arityNode, $subNode);
		#	$$statement .= Clojure::ClojureNode::nodeLink($subNode);
		#}
		#else {
		#	$$statement .= ${getNextStatement()};
		#}
	}
	
	Clojure::ClojureNode::setClojureKindData($arityNode, 'lineBodyEnd', getStatementLine());
}

sub parseDefnChildren($$) {
	my $defnNode = shift;
	my $closing = shift;
	my $kind = GetKind($defnNode);
	
	my $statement = GetStatement($defnNode);
	my $stmt;
	
	# parse meta-data if any ...
	my $metadata = parseMetaData(1);
	
	# *************  NAME ***********************
	if ((defined ($stmt = nextStatement())) && ($$stmt ne "[")) {
		SetName($defnNode, ${getNextElement()});
		
		# NOTE : even with a name, the function remain anonymous, because the name is not visible (not callable).
		#if ($kind eq AnonymousKind) {
		#	# because it has a name, the function is no more anonymous
		#	SetKind($defnNode, FunctionKind);
		#}
	}
	else {
		if ($kind eq FunctionKind) {
			Lib::Log::ERROR("missing name for defn at line ". GetLine($defnNode)." !!");
		}
	}
	
	# trash comment doc if any
	stepOverComment();
	
	# Check meta-data
	$metadata = parseMetaData(1);
#	if (defined $metadata) {
#		print STDERR "METADATA = $$metadata\n";
#	}
	
	if (${nextStatement()} eq "[") {
		parseArityContent($defnNode);
	}
	else {
		my $PolyKind = FunctionPolymorphicKind;
		my $ArityKind = FunctionArityKind;
		
		if ($kind eq AnonymousKind) {
			$PolyKind = AnonymousPolymorphicKind;
			$ArityKind = AnonymousArityKind;
		}
		
		SetKind($defnNode, $PolyKind);
		while (defined ($stmt = nextStatement()) && ($$stmt ne ")")) {
			if (${nextStatement()} eq "(") {
				getNextStatement();
				
				my $ArityNode=Node($ArityKind, createEmptyStringRef());
				SetLine($ArityNode, getStatementLine());
				SetName($ArityNode, GetName($defnNode));
				my $indentation = ${Lib::ParseUtil::getBlankedIndentation()};
				Clojure::ClojureNode::setClojureKindData($ArityNode, 'indentation', $indentation);
				Append($defnNode, $ArityNode);
				
				parseArityContent($ArityNode);
				
				if (defined nextStatement()) {
					if (${nextStatement()} eq ")") {
						getNextStatement();
					}
				}
				else {
					print STDERR "Missing closing parenthese for arity !\n";
				}
			}
			else {
				Append($defnNode, Lib::ParseUtil::tryParse_OrUnknow(\@formContent));
			}
		}
	}
}

##################################################################
#              IF
##################################################################
sub parseIfChildren($$) {
	my $ifNode = shift;
	my $closing = shift;
	
	my $statement = GetStatement($ifNode);
	my $stmt;
	
	# Condition
	my $condNode = parseCondition();
	Append($ifNode, $condNode);
	
	# then
	my $thenNode = Node(ThenKind, createEmptyStringRef());
	Append($ifNode, $thenNode);
	SetLine($thenNode, getNextStatementLine());
	
	#$subNode = Lib::ParseUtil::tryParse(\@formContent);
			
	#if (defined $subNode) {
	#	Append($thenNode, $subNode);
		#$$statement .= Clojure::ClojureNode::nodeLink($subNode);
	#}
	#else {
	#	my $item = getNextElement();
	#	if (defined $item ) {
	#		SetStatement($thenNode, $item);
	#	}
	#	else {
	#		Lib::Log::ERROR("Expecting 'then' branch at line ".GetStatementLine());
	#		last;
	#	}
	#}
	
	##appendNextChild($thenNode);
	Append($thenNode, Lib::ParseUtil::tryParse_OrUnknow(\@formContent));
	
	# else
	if (${nextStatement()} ne ')') {
		my $elseNode = Node(ElseKind, createEmptyStringRef());
		Append($ifNode, $elseNode);
		SetLine($elseNode, getNextStatementLine());
		
		#$subNode = Lib::ParseUtil::tryParse(\@formContent);
			
		#if (defined $subNode) {
		#	Append($elseNode, $subNode);
		#}
		#else {
		#	my $item = getNextElement();
		#	if (defined $item ) {
		#		SetStatement($elseNode, $item);
		#	}
		#	else {
		#		Lib::Log::ERROR("Expecting 'else' branch at line ".GetStatementLine());
		#		last;
		#	}
		#}
		
		##appendNextChild($elseNode);
		Append($elseNode, Lib::ParseUtil::tryParse_OrUnknow(\@formContent));
	}
}

##################################################################
#              WHEN
##################################################################
sub parseWhenChildren($$) {
	my $whenNode = shift;
	my $closing = shift;

	my $stmt;
	
	# Condition
	my $condNode = parseCondition();
	Append($whenNode, $condNode);
	
	# then
	my $thenNode = Node(ThenKind, createEmptyStringRef());
	Append($whenNode, $thenNode);
	SetLine($thenNode, getNextStatementLine());
	
	while ((defined ($stmt = nextStatement())) && ($$stmt ne ')')) {
		Append($thenNode, Lib::ParseUtil::tryParse_OrUnknow(\@formContent))
	}
	
	if (!defined $stmt) {
		Lib::Log::ERROR("Unterminated form at line ".GetLine($whenNode));
	}
	
}
##################################################################
#              COND
##################################################################
sub parseSwitchChildren($$) {
	my $switchNode = shift;
	my $closing = shift;
	
	my $kind = GetKind($switchNode);
	
	my $statement = GetStatement($switchNode);
	my $stmt;
	
	# If no condition expected for default statement, then default statement consists only in instruction statement (in place of condition followed by instruction)
	my $expectConditionForDefault = 1;
	# If null, means that there is no data expression the conditions will apply to. 
	my $expectTestedExpressionItems = 0;
	
	if (($kind eq SwitchCaseKind)) {
		$expectConditionForDefault = 0;
		$expectTestedExpressionItems = 1;
	}
	elsif ($kind eq SwitchArrowKind) {
		$expectConditionForDefault = 1;
		$expectTestedExpressionItems = 1;
	}
	elsif ($kind eq SwitchpKind) {
		$expectConditionForDefault = 0;
		$expectTestedExpressionItems = 2;
	}
	
	my @switchParameters = ();
	while ($expectTestedExpressionItems--) {
		# parse expression the tests should apply to ...
		my $item = getNextElement();
		push @switchParameters, $item;
	}
	Clojure::ClojureNode::setClojureKindData($switchNode, 'parameters', \@switchParameters);
	
	# Cases
	while (defined ($stmt = nextStatement()) && $$stmt ne $closing) {
		my $caseNode = Node(CaseKind, createEmptyStringRef());
	
		my $indentation = ${Lib::ParseUtil::getNextBlankedIndentation()};
		Clojure::ClojureNode::setClojureKindData($caseNode, 'indentation', $indentation);
		Append($switchNode, $caseNode);

		# parse condition expression
		#if (${nextStatement()} =~ /^\s*(:else\b)/mgc) {
		#	Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		#	SetKind($caseNode, DefaultKind);
		#}
		#else {
			my $condNode = Node(ConditionKind, createEmptyStringRef());
			SetLine($caseNode, getNextStatementLine());
			# FIXME : wonder if we should create a cond node or a raw statement instead ???
			my $subNode = Lib::ParseUtil::tryParse(\@formContent);
			
			if (defined $subNode) {
				Append($caseNode, $condNode);
				Append($condNode, $subNode);
				$$statement .= Clojure::ClojureNode::nodeLink($subNode);
			}
			else {
				my $item = getNextElement();
				if (defined $item ) {
					# NOTE : if expecting no condition for default, then :else has no particular meaning.
					#    for EX : (case 1N 1 :1 :else) ==> :else is the returned value, not the condition !!!!
					if ( ($expectConditionForDefault) && ($$item eq ":else")) {
						SetKind($caseNode, DefaultKind);
					}
					else {
						SetStatement($condNode, $item);
						Append($caseNode, $condNode);
					}
				}
				else {
					Lib::Log::ERROR("Expecting case condition at line ".GetLine($condNode).", but encountered ".${nextStatement()});
					last;
				}
			}
			SetLine($condNode, GetLine($caseNode));
		#}
		
		# parse then expression
		my $ThenNode = Node(ThenKind, createEmptyStringRef());
		
		if (${nextStatement()} eq $closing) {
			if (! $expectConditionForDefault) {
				# the previous condition expression was, in fact, the then instruction expression of a default srarement
				SetKind($caseNode, DefaultKind);
				$ThenNode = GetChildren($caseNode)->[0];
				if (defined $ThenNode) {
					SetKind($ThenNode, ThenKind);
				}
				else {
					# we encounter closing, whereas an "then" instruction was expected.
					Lib::Log::ERROR("missing then instruction for default statement at line ".GetLine($caseNode));
				}
			}
			else {
				# we expect a "then" instruction expression, so encountering a closing is an error !!
				Lib::Log::ERROR("Unexpected closing $closing at line ".getNextStatementLine());
			}
		}
		else {
			my $subNode = Lib::ParseUtil::tryParse(\@formContent);
			SetLine($ThenNode, getStatementLine());
			if (defined $subNode) {
				Append($ThenNode, $subNode);
				$$statement .= Clojure::ClojureNode::nodeLink($subNode);
			}
			else {
				#Lib::Log::ERROR("Expecting case instructions bloc at line ".GetLine($ThenNode).", but encountered ".${nextStatement()});
				#last;
				my $item = getNextElement();
				if (defined $item ) {
					SetStatement($ThenNode, $item);
				}
				else {
					Lib::Log::ERROR("Expecting case instruction at line ".GetLine($condNode).", but encountered ".${nextStatement()});
					last;
				}
			}
			Append($caseNode, $ThenNode);	
		}
	}
	#if (! defined $stmt) {
	#	Lib::Log::ERROR("Missing closing $closing at line GetLine($switchNode)");
	#}
	#else {
	#	getNextStatement();
	#}
}

##################################################################
#              FORM
##################################################################

sub parseFormChildren($$) {
	my $formNode = shift;
	my $closing = shift;
	
	my $statement = GetStatement($formNode);
	my $stmt;
	while (defined ($stmt = nextStatement()) && $$stmt ne $closing) {
		my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@formContent);
		#if (defined $subNode) {
			Append($formNode, $subNode);
			$$statement .= Clojure::ClojureNode::nodeLink($subNode);
		#}
		#else {
		#	$$statement .= ${getNextStatement()};
		#}
		#if ((defined nextStatement()) && (${nextStatement()} =~ /^\s*${SEPARATOR}+/gc)) {
		#	Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		#}
		removeSeparator();
	}
}

sub parseDispatch() {
	if (${nextStatement()} =~ /^\s*#$/m) {
		my $node;
		my $stmt;
		if (${nextStatement(1)} eq "(") {
			getNextStatement();  # trash #
			getNextStatement();  # trash (
			$node = Node(FunctionLiteralKind, createEmptyStringRef());
			my $line = getStatementLine();
			SetLine($node, $line);
			SetName($node, "function_literal_$line");
			my $indentation = ${Lib::ParseUtil::getBlankedIndentation()};
			Clojure::ClojureNode::setClojureKindData($node, 'indentation', $indentation);
			
			parseFormChildren($node, ")");
			
			if (defined ($stmt=nextStatement()) && ($$stmt eq ')')) {
				getNextStatement();
			}
		}
		elsif (${nextStatement(1)} eq "{") {
			getNextStatement();  # trash #
			getNextStatement();  # trash {
			$node = Node(SetStructKind, createEmptyStringRef());
			my $line = getStatementLine();
			SetLine($node, $line);
			#SetName($setNode, );
			my $indentation = ${Lib::ParseUtil::getBlankedIndentation()};
			Clojure::ClojureNode::setClojureKindData($node, 'indentation', $indentation);
			
			parseFormChildren($node, "}");
			
			if (defined ($stmt=nextStatement()) && ($$stmt eq '}')) {
				getNextStatement();
			}
		}
		if (defined $node) {
			#if ((defined nextStatement()) && (${nextStatement()} =~ /^\s*${SEPARATOR}+/gc)) {
			#	Lib::ParseUtil::splitAndFocusNextStatementOnPos();
			#}
			removeSeparator();
			return $node;
		}
	}
	return undef;
}

my %CLOSING = (
	'(' => ')',
	'[' => ']',
	'{' => '}',
);

my %KIND_ENCLOSED = (
	'(' => &ListKind,
	'[' => &VectorKind,
	'{' => &MapKind,
);

my %PARSE_CHILDREN = (
	'def' 			=> \&parseDefChildren,
	'defn' 			=> \&parseDefnChildren,
	'defn-' 		=> \&parseDefnChildren,
	'fn'			=> \&parseDefnChildren,
	'if'  			=> \&parseIfChildren,
	'if-let'  		=> \&parseIfChildren,
	'if-some' 		=> \&parseIfChildren,
	'if-not'  		=> \&parseIfChildren,
	'cond'  		=> \&parseSwitchChildren,
	'condp'  		=> \&parseSwitchChildren,
	'cond->'  		=> \&parseSwitchChildren,
	'cond->>'  		=> \&parseSwitchChildren,
	'case' 			=> \&parseSwitchChildren,
	'when'			=> \&parseWhenChildren,
	'when-let' 		=> \&parseWhenChildren,
	'when-some' 	=> \&parseWhenChildren,
	'when-first'	=> \&parseWhenChildren,
	'while'			=> \&parseWhenChildren,
	'ns'			=> \&parseNamespaceChildren,
	'let'			=> \&parseLetChildren,
);

sub parseEnclosed();
sub parseEnclosed() {
	if (${nextStatement()} =~ /^(#[\(\{]|[\(\[\{])$/m) {
		my $opening = $1;
		my $closing = $CLOSING{$opening};
		my $kind = $KIND_ENCLOSED{$opening};
		
		my $stmt = getNextStatement();
		my $line = getStatementLine();
		my $first = "";
		
		my $indentation = ${Lib::ParseUtil::getBlankedIndentation()};
	
#$indentation =~ s/ /./g;
#print STDERR "INDENTATION (enclosed) = <".length($indentation)."> (line $line)\n";

		my $formNode = Node($kind, createEmptyStringRef());
		SetLine($formNode, $line);
		
		Clojure::ClojureNode::setClojureKindData($formNode, 'indentation', $indentation);
		
		# INTERPRET first child ONLY for parenthesed forms (not vector nor maps)
		if ($opening eq "(") {
		
			# PARSE FIRST CHILD
			#------------------
			if (defined ($first = parseEnclosed())) {
				# first arg is a structure, and so cannot be a command or function call 
				Append($formNode, $first);
			}
			else {
				# check for knowned command ...
				$first = ""; # init first ...
				$stmt = nextStatement();
				if ($$stmt ne $closing) {
					#if ($$stmt =~ /^\s*(\S+)/gc) {
					if ($$stmt =~ /^\s*(${ITEM}+)(?:\s|${SEPARATOR})*/gc) {
						$first = $1;
						Lib::ParseUtil::splitAndFocusNextStatementOnPos();

						my $kind = $KIND{$first};
						if (defined $kind) {
							SetKind($formNode, $kind);
						}
					#else {
						SetName($formNode, $first);
					#}
					}
					else {
						Lib::Log::ERROR("invalid form syntax at line $line !!");
					}
				}
			}
		}
		
		# PARSE OTHERS CHILDS
		#--------------------
		my $_cb_ParseChildren = $PARSE_CHILDREN{$first};
		if (defined $_cb_ParseChildren) {
			# parameters of a KNOWN command
			$_cb_ParseChildren->($formNode, $closing);
		}
		else {
			# parameters of a UNKNOWN command
			parseFormChildren($formNode, $closing);
		}
		
		if (defined ($stmt=nextStatement()) && ($$stmt eq $closing)) {
			getNextStatement();
		}
		#if ((defined nextStatement()) && (${nextStatement()} =~ /^\s*${SEPARATOR}+/gc)) {
		#	Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		#}
		removeSeparator();
		return $formNode;
	}
	return undef;
}

# Get Items enclosed inside [ ( and {
# -> matched expression begins with openning and ends with matching closing.
sub parseRawEnclosed() {
	if (${nextStatement()} =~ /([\(\[\{])/) {
		my $opening = $1;
		my $closing = $CLOSING{$opening};
		
		my $statement = ${getNextStatement()};
		my $line = getStatementLine();
		
		my $level = 1;
		my $stmt;
		while (defined ($stmt = nextStatement())) {
			$statement .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
			if ($$stmt eq $opening) {
				$level++;
			}
			elsif ($$stmt eq $closing) {
				$level--;
				if ($level == 0) {
					last;
				}
			}
		}
		
		return \$statement;
	}
	return undef;
}

##################################################################
#              ROOT
##################################################################
sub parseRoot() {
	my $root = Node(RootKind, \$NullString);

	SetName($root, 'root');

	while ( defined nextStatement() ) {
		my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);
		if (defined $subNode) {
			Append($root, $subNode);
		}
	}
	
	return $root;
}

#
# Split a Clojure buffer into statement separated by structural token
# 

sub splitClojure($) {
   my $r_view = shift;

	# \\\[\(\{\[\]\}\)] is for spliting escaped delimiters
	# #( => literal function
	# #{ => set

   my  @statements = split /(\\[\(\{\[\]\}\)]|\n|\(|\)|\{|\}|\[|\])/sm, $$r_view;
   
   if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }
   return \@statements;
}


sub ParseClojure($) {
  my $r_view = shift;
  
  my $r_statements = splitClojure($r_view);

  # only spaces and tabs will be considered as blanks in a statement (\n are considered as SEPARATORS)
  #Lib::ParseUtil::setBlankRegex('[ \t]');

  Lib::ParseUtil::InitParser($r_statements);
  # triggers for parse_Parenthesis
  #Lib::ParseUtil::register_TRIGGERS_parseParenthesis($TRIGGERS_parseParenthesis);
  # trigger for parse_Expression
  #Lib::ParseUtil::register_Expression_TriggeringItems($Expression_TriggeringItems);
  
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
  #my $Artifacts = Lib::ParseUtil::getArtifacts();

  return $root;
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

# description: Clojure parse module Entry point.
sub Parse($$$$;$)
{
	my ($fichier, $vue, $couples, $options) = @_;
	my $status = 0;

	#initMagicNumbers($vue);

	$StringsView = $vue->{'HString'};

	Lib::ParseUtil::registerParseUnknow(\&parseUnknow);

	# launch first parsing pass : strutural parse.
	#my ($ClojureNode, $Artifacts) = ParseClojure(\$vue->{'code'});
	my $ClojureNode = ParseClojure(\$vue->{'code'});

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

	if (defined $options->{'--print-tree'}) {
		Lib::Node::Dump($ClojureNode, *STDERR, "ARCHI");
	}
	if (defined $options->{'--print-test-tree'}) {
		print STDERR ${Lib::Node::dumpTree($ClojureNode, "ARCHI")} ;
	}

	$vue->{'structured_code'} = $ClojureNode;
	#$vue->{'artifact'} = $Artifacts;

	# pre-compute some list of kinds :
	preComputeListOfKinds($ClojureNode, $vue, [	FunctionKind, FunctionArityKind, AnonymousKind, FunctionPolymorphicKind, DefKind, LetKind, IfKind,
												FunctionLiteralKind, SwitchKind, SwitchpKind, SwitchCaseKind, MapKind, WhileKind, NamespaceKind ]);

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


