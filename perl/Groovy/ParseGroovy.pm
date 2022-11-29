package Groovy::ParseGroovy;
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

use Java::ParseCommon;

use Groovy::GroovyNode;

my $DEBUG = 0;

my @rootContentJava = ( 
			\&parseClass,
			\&parseEnum,
			\&parseInterface,
			\&parseImport,
			\&parseModifiers,
			\&parseAnnotation,
			\&parsePackage,
);

my @rootContentGroovy = ( 
			\&parseClass,
			\&parseEnum,
			\&parseInterface,
			\&parseImport,
			\&parseModifiers,
			\&parseAnnotation,
			\&parsePackage,
			
			# methods content
			\&parseIf,
			\&parseWhile,
			\&parseFor,
			\&parseDo,
			\&parseTry,
			\&parseReturn,
			\&parseSwitch,
			\&parseThrow,
			\&parseBreak,
			\&parseContinue,
			
			# function declararion
			\&parseFunction
);

my @rootContent = @rootContentGroovy;

my @classContent = ( 
			\&parseModifiers,
			\&parseClass,
			\&parseEnum,
			\&parseInterface,
			\&parseAnnotation,
			\&parseBlock,
			\&parseMember,
);

my @methodContent = ( 
			\&parseClass,
			\&parseEnum,
			\&parseInterface,
			\&parseModifiers,
			\&parseIf,
			\&parseWhile,
			\&parseFor,
			\&parseDo,
			\&parseTry,
			\&parseReturn,
			\&parseSwitch,
			\&parseThrow,
			\&parseBreak,
			\&parseContinue,
			\&parseBlock,
			\&parseAnnotation
);

my @switchContent = ( 
			\&parseCase,
			\&parseDefault,
);

my $NullString = '';

my $re_MODIFIERS_Groovy = '(?:def|public|protected|private|static|abstract|final|native|synchronized|transient|volatile|strictfp)';
my $re_MODIFIERS_Java   = '(?:public|protected|private|static|abstract|final|native|synchronized|transient|volatile|strictfp)';
my $re_MODIFIERS;

my $IDENTIFIER = '\w+';

my $NEVER_ENDING_INSTR_PATTERN    = '(:?[^\+]\+|[^\-]\-|\/|\*|\%|=|\&|\|)';
my $NEVER_BEGINNING_INSTR_PATTERN = '(:?\/|\*|\%|=|\&|\|)';

my $StringsView = undef;

my $TECHNO = "Groovy";

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
	"{" => \&parseClosure,
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




sub nextItemIsEndingInstruction($) {
	my $expr = shift;
	if (${Lib::ParseUtil::getSkippedBlanks()} =~ /\n/) {
		
		if (Lib::ParseUtil::getEnclosing() ne '') {
			# inside enclosing
			return 0;
		}
		
		if ($$expr =~ /$NEVER_ENDING_INSTR_PATTERN\s*\z/m) {
			# previous is not ending 
			return 0;
		}
		
		if ((defined nextStatement())&& (${nextStatement()} =~ /^\s*$NEVER_BEGINNING_INSTR_PATTERN/m)) {
			# next is not beginning
			return 0;
		}
		#default = end of expression due to end of line
		return 1;
		
	}
	return 0;
}

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


# variable declaration and function call without parenthese syntax are ambiguous.
# ex :        ident1 ident2
# ==> variable with type "ident1" and name "ident2" ? 
#     or function "ident1" with parameter "ident2e ? 
sub checkVariable($) {
	my $var = shift;
	
	# check for impossible variable name.
	if (GetName($var) =~ /^(\d|CHAINE_\d+)$/m) {
		SetKind($var, UnknowKind);
		SetName($var, undef);
	}

	# if multivariable declaration, others variables cannot be variable too !!!
	# ex :    fct 1, b
	#      ==> "1" is not a variable with type "fct", and "b" too ..
	my $addnode = getGroovyKindData($var, 'addnode');
	if ((defined $addnode) && (scalar @$addnode)) {
		for my $node (@$addnode) {
			SetKind($node, UnknowKind);
			SetName($node, undef);
		}
	}
}


sub parseUnknow() {
	my $line = getNextStatementLine();
	
    if (${nextStatement()} eq '}') {
        getNextStatement();
        print STDERR "WARNING : unexpected closing brace at line ".getStatementLine()."\n"; 
        return undef;
    }

	# check for variable declaration
	my $node = Java::ParseCommon::Parse_VariableOrUnknow();
	
# ------------ GROOVY --------------
	if ($TECHNO eq "Groovy") {
		if ((IsKind($node, VariableKind) && (getGroovyKindData($node, 'type') eq 'def'))) {
			SetKind($node, VariableDefKind);
		}
	
		if (GetKind($node) ne UnknowKind) {
			checkVariable($node);
		}
	}
# -----------------------------------	
	return $node;
}

sub isNextClosingBrace() {
	if ( ${nextStatement()} eq '}' ) {
		return 1;
	}  
	return 0;
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
     declareMagic($magic);
  }
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

# magic numbers
my $integer = $Java::CountVariable::integer;
my $decimal  = $Java::CountVariable::decimal;
my $real = $Java::CountVariable::real;

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#!!!!!!!!!!!!!!!! FIXME : TO BE ADAPTED FOR JAVA !!!!!!!!!!!!!!!!!
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
sub getVariables($) {
	my $artifactNode = shift;
	
	# get the arguments list.
	my $args = getGroovyKindData($artifactNode, 'arguments');
	
	my %varList = ();
	my %constList = ();
	my @unks = GetNodesByKindList_StopAtBlockingNode($artifactNode, [UnknowKind], [ClassKind, MethodKind]);
	for my $child (@unks) {
		if (${GetStatement($child)} =~ /^\s*([\w\.]+)\s*=\s*(?:(?:(CHAINE_\d+)|($real|$decimal|$integer)|(\[))|(.|$))/m) {
			
			# An argument ??
			if ( ! exists $args->{$1}) {
				# no, it's a local var.
				
				# Already found ? 
				if (! exists $varList{$1}) {
					# no, first time encountered
					$varList{$1} = 1;
				
					if (defined $2) {
						$constList{$1} = ['string', $2]; ;
					}
					elsif (defined $3) {
						$constList{$1} = ['number', $3]; ;
					}
					elsif (defined $4) {
						$constList{$4} = ['list', ""]; ;
					}
				}
				else {
					# Yes, already found. Several assignments means it's not a constant.
					delete $constList{$1};
				}
			}
		}
	}
	return [\%varList, \%constList];
}

##################################################################
#              GENERIC
##################################################################

sub ParseGeneric($) {
	my $kind = shift;

	my $node = Node($kind, createEmptyStringRef());
	
	# consumes the keyword
	my $proto = getNextStatement();
	
	SetLine($node, getStatementLine());
	
	my $statement = createEmptyStringRef();
	my $subNodes;
	if (! nextItemIsEndingInstruction($proto)) {
		($statement, $subNodes) = Lib::ParseUtil::parse_Instruction();
	}

	SetStatement($node, $statement);
	
	for my $subNode (@$subNodes) {
		Append($node, $subNode);
	}
		
	return $node;
}

##################################################################
#              PACKAGE
##################################################################

sub isNextPackage() {
	if ( ${nextStatement()} eq 'package' ) {
		return 1;
	}  
	return 0;
}

sub parsePackage() {
	if (isNextPackage()) {
		return ParseGeneric(PackageKind);
	}
	return undef;
}

##################################################################
#              IMPORT
##################################################################

sub isNextImport() {
	if ( ${nextStatement()} eq 'import' ) {
		return 1;
	}  
	return 0;
}

sub parseImport() {
	if (isNextImport()) {
		return ParseGeneric(ImportKind);
	}
	return undef;
}

##################################################################
#              RETURN
##################################################################

sub isNextReturn() {
	if ( ${nextStatement()} eq 'return' ) {
		return 1;
	}  
	return 0;
}

sub parseReturn() {
	if (isNextReturn()) {
		return ParseGeneric(ReturnKind);
	}
	return undef;
}

##################################################################
#              THROW
##################################################################

sub isNextThrow() {
	if ( ${nextStatement()} eq 'throw' ) {
		return 1;
	}  
	return 0;
}

sub parseThrow() {
	if (isNextThrow()) {
		return ParseGeneric(ThrowKind);
	}
	return undef;
}

##################################################################
#              CONTINUE
##################################################################

sub isNextContinue() {
	if ( ${nextStatement()} eq 'continue' ) {
		return 1;
	}  
	return 0;
}

sub parseContinue() {
	if (isNextContinue()) {
		return ParseGeneric(ContinueKind);
	}
	return undef;
}

##################################################################
#              BREAK
##################################################################

sub isNextBreak() {
	if ( ${nextStatement()} eq 'break' ) {
		return 1;
	}  
	return 0;
}

sub parseBreak() {
	if (isNextBreak()) {
		return ParseGeneric(BreakKind);
	}
	return undef;
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
	while (($next=${nextStatement()}) && ($next ne ":")) {
		$cond .= getNextStatement();
	}
		
	if ($next && ($next eq ':')) {
		getNextStatement();
	}
	else {
		print "[ParseGroovy::parseCase] ERROR : missing semi-colon after case at end of file !!\n";
	}
		
	SetStatement($caseNode, \$cond);
		
	# content of a "case" is the same as a method ... (full instruction set ...)
	sendContextEvent(CTX_METHOD);
	while (($next=${nextStatement()}) && ($next ne 'case') && ($next ne 'default') && ($next ne '}')) {
		my $node = Lib::ParseUtil::tryParse_OrUnknow(getCurrentContextContent());
		if (defined $node) {
			Append($caseNode, $node);
		}
	}
	SetEndline($caseNode, getStatementLine());
	
	sendContextEvent(CTX_LEAVE);
	
	if (! defined $next) {
		print "[ParseGroovy::parseCase] ERROR : cannot find beginning '('\n";
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
		return parseControle(CatchKind, [], 1);
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
		
		Lib::ParseUtil::updateGenericParse(\$condition, $condNode, Lib::ParseUtil::parseParenthesis('(', $TRIGGERS_parseParenthesis));
	}
	else {
		print "[ParseGroovy::parseCondition] ERROR : cannot find beginning '('\n";
		return undef;
	}

#print "CONDITION : $condition\n";

	my $cond = $condition;
	$cond =~ s/\A\(\s*//;
	$cond =~ s/\s*\)\z//;
	
	my $init;
	my $inc;
	if ($cond =~ /\A([^;]*);([^;]*);([^;]*)/) {
		$init = $1;
		$cond = $2;
		$inc = $3;
	}	

	setGroovyKindData($condNode, 'init', $init);
	setGroovyKindData($condNode, 'cond', $cond);
	setGroovyKindData($condNode, 'inc', $inc);
	
	SetStatement($condNode, \$condition);
	
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
		# Note : first child is the condition node !!
		if (! defined getGroovyKindData(GetChildren($forNode)->[0], 'init') ) {
			# if there is no 'init' clause in the condition node, then it is an enhanced for loop.
			SetKind($forNode, EForKind);
		}
		return $forNode
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
	
	my $parseSeveral = 1;
	# check presence of '{'
	if ((defined nextStatement()) && (${nextStatement()} eq '{') ) {
		getNextStatement();
	}
	else {
		print "[ParseGroovy::parse_block] WARNING : missing '{' at line ".getStatementLine()."\n" if $DEBUG;
		$parseSeveral = 0;
	}
	
	# SetLine($blocNode, getNextStatementLine());
	
	if ($parseSeveral) {
		Lib::ParseUtil::parseStatementsBloc($blocNode, [\&isNextClosingBrace], $context, 0);
	}
	else {
		my $node = Lib::ParseUtil::tryParse_OrUnknow(getCurrentContextContent());
		if (defined $node) {
			Append($blocNode, $node);
		}
	}
}

sub parseControle($$;$$) {
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
			print "[ParseGroovy::parseControlBloc] SYNTAX ERROR  : missing condition !\n";
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
		setGroovyKindData($controlNode, 'artifact_key', $artiKey);
	}
	
	parse_block($parentNode);
	
	if ($artiKey) {
		Lib::ParseUtil::endUnmodalArtifact($artiKey);
		setGroovyKindData($controlNode, 'codeBody', Lib::ParseUtil::getArtifact($artiKey));
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

	SetEndline($controlNode, getStatementLine());
	return $controlNode; 
}

##################################################################
#              DEF
##################################################################

sub parseDef(;$) {
	my $context = shift;
	
	my $node;
	# CLASS : parse as a member
	
	my $routineKind = FunctionKind;
	my $variableKind = VariableDefKind;
	
	if ( getCurrentContext() == CTX_CLASS) {
		$routineKind = MethodKind;
		$variableKind = AttributeDefKind;
		# consumes the 'def' keyword.
	#	getNextStatement();
		
	#	$node = parseMember();
	#	if (IsKind($node, AttributeKind)) {
	#		SetKind($node, AttributeDefKind);
	#	}
	}
	# ROOT ...
	#else {
		# try function declaration
		$node = parseFunction($context, $routineKind, 1);
		if (! defined $node) {
			# not a function => try variable ...
			
			my $line = getStatementLine();
			
			my $data = Lib::ParseArguments::initVarData($line);
			
			if (${nextStatement()} eq '(') {
				# destructuring
				getNextStatement();

				my $destrNode = Node(DestructuringKind, createEmptyStringRef());
				SetLine($destrNode, $line);

				my $next = nextStatement();
				while ((defined $next) && ($$next ne ")")) {

					my ($statement, $varnode, undef, $subNodes) = Java::ParseCommon::Parse_Variable(undef, undef, $variableKind,	1,	# 1 means type is optional
																																	1); # 1 descative multivar
					if (defined $varnode) {
						# add subnodes.
						Lib::ParseUtil::updateGenericParse($statement, $varnode, [createEmptyStringRef(), $subNodes] );
						Append($destrNode, $varnode);
					}
					else {
						Lib::Log::ERROR("def syntax (destructuring) not recognized at line $line !!");
					}
					
					$next = nextStatement();
					if ($$next eq ',') {
						getNextStatement();
					}
				}
				
				if (${nextStatement()} eq ')') {
					getNextStatement();
				}
				else {
					Lib::Log::ERROR("missing closing parenthese for destructuring declaration at line ".$line)
				}
				
				if ((defined nextStatement()) && (${nextStatement()} eq "=")) {
					# trashes the "="
					getNextStatement();
		
					my $initStmt = "";
					my $initNode = Node(InitKind, \$initStmt);
					SetLine($initNode, getNextStatementLine());
		
					my @expUpdateInfos = Lib::ParseUtil::parse_Expression();
		
					Lib::ParseUtil::updateGenericParse(\$initStmt, $initNode, \@expUpdateInfos);

					Append($destrNode, $initNode);
				}
				
				$node = $destrNode;
			}
			else {
				# PARSE THE TYPE OF THE VARIABLE DECLARATION
				#if (defined Lib::ParseArguments::parseType($stmt, $data)) {
					# check if it is really a type : should be followed by name
				#	if ($$stmt !~ /\G\s*\w+/g) {
						# not followed by a name => declaration without type, so reset statement
				#		pos($$stmt) = 0;
				#	}
				#}
				
				#parseVariablesList($stmt, $data, VariableDefKind);
				my $statement = createEmptyStringRef();
				my $subNodes;
				($statement, $node, undef, $subNodes) = Java::ParseCommon::Parse_Variable(undef, undef, $variableKind, 1);  # 1 means type is optional.
				if (defined $node) {
					# add subnodes.
					Lib::ParseUtil::updateGenericParse($statement, $node, [createEmptyStringRef(), $subNodes] );
				}
				else {
					Lib::Log::ERROR("def syntax not recognized at line $line : $$statement");
					$node = Node(UnknowKind, $statement);
					SetLine($node, $line);
				}
			}
			
			
			#if (defined $node) {
			#	SetKind($node, VariableDefKind);
			#}
			#else {
			#	# not a function nor error => what's the fuck ? 
			#	Lib::Log::ERROR("Unknow def syntax at line ".$line)
			#}
		}
	#}
	
	Lib::ParseUtil::purgeSemicolon();
	
	return $node;
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



sub parseModifiers(;$) {
	my $parentContext = shift;
	
	if (isNextModifiers()) {
		my $def = 0;
		
		my $modifiers = ${getNextStatement()};
		
		# Groovy : keyword 'def' place can be mixed with modifiers, but is not a modifier itself !!!
		if ($modifiers =~ /\bdef\b/) {
			$def = 1;
			$modifiers =~ s/\bdef\b//;
		#	# replace all modifiers by def in the next statement
		#	${nextStatement()} = 'def';
		}
		#else {
		#	# consumes modifiers statement
	    # 	getNextStatement();
		#}

		my $H_modifiers = {};
		
		while ($modifiers =~ /(\w+)/g) {
			$H_modifiers->{$1} = 1;
		}
		
		my $artifactNode;
		
		my $context = ( defined $parentContext ? $parentContext : {});
		$context = {'modifiers' => $H_modifiers};
		
		if (($TECHNO eq "Groovy") && ($def == 1)) {
			$artifactNode = parseDef($context);
		}
		else {
			$artifactNode = Lib::ParseUtil::tryParse_OrUnknow(getCurrentContextContent(), $context);
		}
		
		# restaure inherited context by removing added infos
		delete $context->{'modifiers'};
		
		setGroovyKindData($artifactNode, 'modifiers', \$modifiers);
		setGroovyKindData($artifactNode, 'H_modifiers', $H_modifiers);
		
		if ($def) {
			if (IsKind($artifactNode, AttributeKind)) {
				SetKind($artifactNode, AttributeDefKind);
			}
		}
		
		# case of several vars declared in the same instruction ... and so several node ...
		my $addnode = getGroovyKindData($artifactNode, "addnode");
		if (defined $addnode) {
			for my $node (@$addnode) {
				setGroovyKindData($node, 'modifiers', \$modifiers);
				setGroovyKindData($node, 'H_modifiers', $H_modifiers);
				
				if ($def) {
					if (IsKind($artifactNode, AttributeKind)) {
						SetKind($artifactNode, AttributeDefKind);
					}	
				}
			}
		}
		
		return $artifactNode;
	}
	
	return undef;
}

##################################################################
#              ANNOTATION
##################################################################
sub isNextAnnotation() {
	if ( ${nextStatement()} eq '@' ) {
		return 1;
	}  
	return 0;
}

sub parseAnnotation() {
	if (isNextAnnotation()) {
		
		my $AnnoNode = Node(AnnotationKind, createEmptyStringRef());
		
		# get the "@"
		my $statement = ${getNextStatement()};
		
		# my $name = ${getNextStatement()};
		my $name ="";
		my $line = getStatementLine();
		
		if (${nextStatement()} =~ /\G\s*([\w\.]+)\s*/gc) {
			$name = $1;
			Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		}
		else {
			print "parse ERROR : bad annotation syntax at line $line\n";
		}
		
		SetName($AnnoNode, $name);
		SetLine($AnnoNode, $line);
		
		$statement .= $name;
		
		my $next = ${nextStatement()};
		if ($next eq '(') {
			#$statement .= Lib::ParseUtil::parseParenthesis('(');
			Lib::ParseUtil::updateGenericParse(\$statement, $AnnoNode, Lib::ParseUtil::parseParenthesis('(', $TRIGGERS_parseParenthesis));
		}
		elsif ($name eq 'interface') {
			
			my $statement .= ${getNextStatement()};
			
			if (${nextStatement()} eq '{') {
				#$statement .= Lib::ParseUtil::parseParenthesis('{');
				Lib::ParseUtil::updateGenericParse(\$statement, $AnnoNode, Lib::ParseUtil::parseParenthesis('{', $TRIGGERS_parseParenthesis));
			}
			else {
				print STDERR "[ParseGroovy::parseAnnotation] WARNING : missing definition bloc for \@interface at line $line\n";
			}
		}
		
		return $AnnoNode;
	}
	return undef;
}

sub parseClassContext($$) {
	my $kind = shift;
	my $kindName = shift;

		my $classNode = Node($kind, createEmptyStringRef());
#print "--> $kindName found...\n" if $DEBUG;
		sendContextEvent(CTX_CLASS);
		#Lib::ParseUtil::setArtifactUpdateState(0);

		#trash 'class' keyword
		#getNextStatement();
		
		my $statementLine = getStatementLine();
		SetLine($classNode, $statementLine);
		setGroovyKindData($classNode, 'static_fields_names', {});
		
#		setGroovyKindData($classNode, 'indentation', Lib::ParseUtil::getIndentation());
		
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
		
		#Lib::ParseUtil::setArtifactUpdateState(1);
		#my $artiKey = Lib::ParseUtil::newArtifact('class_'.$name, $statementLine);
		#setGroovyKindData($classNode, 'artifact_key', $artiKey);
	
		my $context = { 'className' => $name };
		my $nb_Constructors = 0;
		while (nextStatement() && (${nextStatement()} ne '}')) {
			my $memberNode = Lib::ParseUtil::tryParse_OrUnknow(\@classContent, $context);
			if (defined $memberNode) {
				Append($classNode, $memberNode);
				
				if (IsKind($memberNode, MethodKind) && (GetName($memberNode) eq $name)) {
					$nb_Constructors++;
				}
				
				my $H_modifiers = getGroovyKindData($memberNode, 'H_modifiers');
				if (defined $H_modifiers) {
					if (defined $H_modifiers->{'static'}) {
						my $kind = GetKind($memberNode);
						if (($kind eq AttributeKind) || ($kind eq AttributeDefKind)) {
							getGroovyKindData($classNode, 'static_fields_names')->{&GetName($memberNode)} = 1;
						}
					}
				}
			}
		}
		
		if (defined nextStatement()) {
			# trashes the '}'
			getNextStatement();
		}
		else {
			print STDERR "[PARSE] Error : missing closing '}' for class $name\n";
		}

		setGroovyKindData($classNode, 'nb_constructors', $nb_Constructors);
		#Lib::ParseUtil::endArtifact($artiKey);
#print STDERR "CLASS $name has $nb_Constructors constructors\n";	
		sendContextEvent(CTX_LEAVE);
		
		SetEndline($classNode, getStatementLine());
		
#		my $variables = getVariables($classNode);
#		setGroovyKindData($classNode, 'local_variables', $variables->[0]);
#		setGroovyKindData($classNode, 'local_constants', $variables->[1]);
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
		
#		setGroovyKindData($classNode, 'indentation', Lib::ParseUtil::getIndentation());
		
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
		my $context = { 'className' => $name };
		
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
					my $memberNode = Lib::ParseUtil::tryParse_OrUnknow(\@classContent, $context);
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
#              VARIABLE DECLARATION
##################################################################

sub createVariablesNodes($$$$) {
	my $proto = shift;
	my $varData = shift;
	my $kind = shift;
	my $line = shift;

	# get the first var
	my $node = Node($kind, \$proto);
	my $data = shift @$varData;
	SetName($node, $data->{'name'});
	setGroovyKindData($node, 'type', $data->{'type'});
	if (defined $data->{'default'}) {
		Append($node, Node(InitKind, \$data->{'default'}));
	}
	SetLine($node, $line);
		
	# get additional vars ...
	if (scalar @$varData) {
		my @add_vars = ();
		for	my $data (@$varData) {
			my $addVarNode = Node($kind, \$proto);
			SetName($addVarNode, $data->{'name'});
			setGroovyKindData($addVarNode, 'type', $data->{'type'});
			if (defined $data->{'default'}) {
				Append($addVarNode, Node(InitKind, \$data->{'default'}));
			}
			SetLine($addVarNode, $line);
			push @add_vars, $addVarNode;
			# record info in the node : the var is declared inside same statement than previous.
			setGroovyKindData($addVarNode, 'multi_var_decl', 1);
		}
		setGroovyKindData($node, 'addnode', \@add_vars);
	}
	
	return $node;
}

# consider that the following statements are belonging to an variable initialization expression.
# Create and return an "init" node.
sub parse_Init() {
	
	my $line_init = getNextStatementLine();
	
	my $stopPatterns = { "," => 1};
	my ($statement, $subNodes) = Lib::ParseUtil::parse_Expression();

	my $initNode = Node(InitKind, $statement);
	SetLine($initNode, $line_init);
	
	for my $subNode (@$subNodes) {
		Append($initNode, $subNode);
	}
	
	return $initNode;
}


##################################################################
#              MEMBER
##################################################################

sub parseMember(;$) {
	my $context = shift;
	
	my $proto = '';
	my $stmt;

	my $line = getNextStatementLine();
	
	my $flag_init = 0;
	
	my $optional_type = 0;
	if (defined $context) {
		my $modifiers = $context->{'modifiers'};
		if (defined $modifiers) {
			# if a modifier is present, then type is not required !!!
			$optional_type = scalar keys %{$modifiers} > 0;
		}
	}
	
	my $node = parseFunction($context, MethodKind, $optional_type);
	
	if (! defined $node) {

		my $statement = createEmptyStringRef();
		my $subNodes;
		($statement, $node, undef, $subNodes) = Java::ParseCommon::Parse_Variable(undef, undef, AttributeKind, 1);  # 1 means type is optional.
		if (defined $node) {
			# add subnodes.
			Lib::ParseUtil::updateGenericParse($statement, $node, [createEmptyStringRef(), $subNodes] );
			
			Lib::ParseUtil::purgeSemicolon();
		}
		else {
			Lib::Log::ERROR("attribute syntax not recognized at line $line : $$statement");
		}
	}
	#else {
	#	print STDERR "[ParseGroovy::parseMember] ERROR : inconsistency encountered when parsing class member ()!!\n";
	#}
	
	return $node;
}

##################################################################
#              ROOT DECLARATIONS
#
#           --- GROOVY Specific ---
##################################################################

sub parseRootDeclarations() {
	my $proto = '';
	my $stmt;

	my $line = undef;
	
	my $flag_init = 0;

	#while ((defined ($stmt = nextStatement())) && ($$stmt ne ';') && (!nextItemIsEndingInstruction(\$proto))) {
	while ((defined ($stmt = nextStatement())) && ($$stmt ne ';')) {
		if ($$stmt =~ /=/) {
			$flag_init = 1;
		}
		elsif ( $$stmt eq '(' ) {
			if ($flag_init == 0) {
				# opennenig parenth before encountering "=" means it could be a method !
				my $idx = Lib::ParseUtil::getIndexAfterPeer();
				if (${nextStatement($idx)} eq '{') {
					# it's a method, because parentheses are followed by openning accolade
					my $parenthese_stmt = nextStatement($idx); 
					while (nextStatement() != $parenthese_stmt) {
						$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
					}
					
					last;
				}
			}
		}
		
		#if ($$stmt eq "{") {
		#	my $expr = Lib::ParseUtil::parseUntilPeer("{", "}");
		#	if (defined $expr) {
		#		$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.$$expr;
		#	}
		#}
		#else {
			#$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		#}

		if (!defined $line) {
			$line = getNextStatementLine();
		}
		
		if ($proto eq "") {
			Lib::Log::WARNING("parse error suspicion at line $line : \$proto is empty at end of first iteration !!")
		}
		elsif (nextItemIsEndingInstruction(\$proto)) {
			last;
		}
	}

	if (!defined $stmt ) {
		print STDERR "[PARSE] Error : missing closing '}' for class\n";
	}
	elsif ($$stmt eq '(') {
		my ($type, $name) = $proto =~ /^(.*)\b(\w+)\s*(?:<.*>)?\s*$/sm;
		$type =~ s/^\s*//m;
		$type =~ s/\s*$//m;
#print STDERR "PROTO : $proto\n";
#print STDERR "  -> type = $type\n";
		my $node = parse_Method($name, $line, FunctionKind);
		setGroovyKindData($node, 'return_type', $type);
		return $node;
	}
	#elsif ($$stmt eq ';') {
	else {
		# instruction will be treated by parseUnknow
		return undef;
	}
	#else {
	#	print STDERR "[ParseGroovy::parseMember] ERROR : inconsistency encountered when parsing class member ()!!\n";
	#}
	
	return undef;
}

sub parseFunction(;$$) {
	my $context = shift;
	my $kind = shift || FunctionKind;
	my $optional_type = shift || 0;
		
	my $modifiers = (defined $context ? $context->{'modifiers'} : {});
		
	my $proto = '';
	my $stmt;

	my $line = undef;
	
	my $flag_init = 0;
	my $idx = 0;

	my $functionFound = 0;
	my $body_expected = 1;
	#while ((defined ($stmt = nextStatement())) && ($$stmt ne ';') && (!nextItemIsEndingInstruction(\$proto))) {
	while ((defined ($stmt = nextStatement($idx))) && ($$stmt ne ';') && ($$stmt ne "=")) {
		if (($TECHNO eq "Groovy") && ($$stmt eq "\n")) {
			# \n is ending the loop in groovy context (means function proto cannot be on several lines)
			last;
		}
		#if ($$stmt =~ /=/) {
		#	$flag_init = 1;
		#}
		#elsif ( $$stmt eq '(' ) {
		if ( $$stmt eq '(' ) {
			#if ($flag_init == 0) {
			
				# function name is preceded by a modifier OR a type like :   TYPE, TYPE[...] or TYPE<...>
				my $className;
				if (	(defined ($className=$context->{'className'}) && ($proto =~ /$className\s*$/m)) ||
						(($optional_type) && ($proto =~ /\w\s*$/m)) ||
						($proto =~ /[\w\]>]\s+\w+\s*$/m)) {
#print STDERR "PROTO : $proto\n";
					# opennenig parenth while no "=" encountered means it could be a method !
					$idx = Lib::ParseUtil::getIndexAfterPeer($idx);
					
					# for a method, the closing parenthese will be followed by
					# - in Java,  '{' or ';'
					# - in Groovy, '{' or \n
					my $blank;
					
					# step over blanks
					my $contain_newline = 0;
					while ((defined ($blank = nextStatement($idx))) && ($$blank =~ /\A\s*\Z/)) {
						if ($$blank =~ /\n/) {
							$contain_newline = 1;
							# FIXME : check Groovy language and class context ...
							#if ($TECHNO eq "Groovy") {
							#	# parenthese followed by end of line, means end of statement for Groovy.
							#	last;
							#}
						}
						$idx++;
					}
					
					# check what is after the closing parenthese...
					my $next = nextStatement($idx);
					if (($$next eq '{') || ($$next eq ';') || ($$next eq '}') || (($contain_newline)&&($TECHNO eq "Groovy")) || ($$next =~ /^\s*throws\b/m)) {
						# it's a method ...
						my $parenthese_stmt = $stmt; 
						while (nextStatement() != $parenthese_stmt) {
							#$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
							getNextStatement();
						}
						$functionFound = 1;
						
						if ($contain_newline && ${nextStatement()} ne '{') {
							$body_expected = 0;
						}
						
					}
				}
			#}
			
			last;
		}
		
		$proto .= $$stmt;
		
		#if ($$stmt eq "{") {
		#	my $expr = Lib::ParseUtil::parseUntilPeer("{", "}");
		#	if (defined $expr) {
		#		$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.$$expr;
		#	}
		#}
		#else {
			#$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		#}

		if (!defined $line) {
			$line = getNextStatementLine();
		}
		
		#if ($proto eq "") {
		#	Lib::Log::WARNING("parse error suspicion at line $line : \$proto is empty at end of first iteration !!")
		#}
		
		#elsif (nextItemIsEndingInstruction(\$proto)) {
		#if (nextItemIsEndingInstruction(\$proto)) {
		#	last;
		#}
		$idx++;
	}

	#if (!defined $stmt ) {
	#	print STDERR "[PARSE] Error : missing closing '}' for class\n";
	#}
	#elsif ($$stmt eq '(') {
	#if ($proto ne "") {
	if ($functionFound) {
		# FIXME : What about the <...> ???
		my ($type, $name) = $proto =~ /^(.*)\b(\w+)\s*(?:<.*>)?\s*$/sm;
		$type =~ s/^\s*//m;
		$type =~ s/\s*$//m;
#print STDERR "PROTO : $proto\n";
#print STDERR "  -> type = $type\n";
		my $node = parse_Method($name, $line, $kind, $body_expected);
		setGroovyKindData($node, 'return_type', $type);
		return $node;
	}
	#elsif ($$stmt eq ';') {
	#else {
		# instruction will be treated by parseUnknow
	#	return undef;
	#}
	#else {
	#	print STDERR "[ParseGroovy::parseMember] ERROR : inconsistency encountered when parsing class member ()!!\n";
	#}
	
	return undef;
}

##################################################################
#              METHOD
##################################################################

sub parse_Method($$$;) {
		my $name = shift;
		my $line = shift;
		my $kind = shift;
		my $body_expected = shift;
		
		if (!defined $name) {
			print "[ParseGroovy::parse_Method] ERROR : undefined name for method\n";
			$name = "unknow_at_$line";
		}
		my $methodNode = Node($kind, createEmptyStringRef());
#print STDERR "--> METHOD $name found...\n";

		SetLine($methodNode, $line);

		sendContextEvent(CTX_METHOD);
		
		# temporary desactive artifact updating: the prototype of the function should not appears in the encompassing (parent) artifact.
		# This to prevent some argument with default values (xxx = ) to be considered as  parent's variable while greping variable in parent's body.
		#Lib::ParseUtil::setArtifactUpdateState(0);

#		setGroovyKindData($methodNode, 'indentation', Lib::ParseUtil::getIndentation());

		my $proto = '';
		my $stmt;
		# FIXME : should be robust against parameter with defaut closure containing '(' and ';'
		# -> should use a rawParsePeer ....
		while ((defined ($stmt = nextStatement())) && ($$stmt ne '{') && ($$stmt ne ';') ) {
			my $blanks = ${Lib::ParseUtil::getSkippedBlanks()};
			if ($TECHNO eq "Groovy") {
				last if ( (! $body_expected) and ($blanks =~ /\n/));
			}
			$proto .= $blanks.${getNextStatement()};
		}

		SetStatement($methodNode, \$proto);
		SetName($methodNode, $name);
		
		if (! defined nextStatement()) {
			print STDERR "[PARSE] Error : missing openning '{' for method $name\n";
		}
		else {
			if ($$stmt eq ";" or $$stmt eq "{") {
				getNextStatement();
			}
		}
		
		setGroovyKindData($methodNode, 'arguments', Lib::ParseArguments::parseArguments($methodNode, 1)); # 1 means "allow mising type"

		if ($$stmt eq '{') {
			# **** presence of a body (not an abstract - virtual pure - method).

			# declare a new artifact
			my $artiKey = Lib::ParseUtil::newArtifact('func_'.$name, $line);
			setGroovyKindData($methodNode, 'artifact_key', $artiKey);
		

			#		my $lines_in_proto = () = $proto =~ /\n/g;
			#		setGroovyKindData($methodNode, 'lines_in_proto', $lines_in_proto);
		
			#		Lib::ParseUtil::setArtifactUpdateState(1);
		
			while (nextStatement() && (${nextStatement()} ne '}')) {
				my $node = Lib::ParseUtil::tryParse_OrUnknow(\@methodContent);
				if (defined $node) {
					Append($methodNode, $node);
				}
			}
		
			#end of artifact
			Lib::ParseUtil::endArtifact($artiKey);
			setGroovyKindData($methodNode, 'codeBody', Lib::ParseUtil::getArtifact($artiKey));
		
			if (defined nextStatement()) {
				# trashes the '}'
				getNextStatement();
			}
			else {
				print STDERR "[PARSE] Error : missing closing '}' for method $name\n";
			}
		
			#		my $variables = getVariables($methodNode);
			#		setGroovyKindData($methodNode, 'local_variables', $variables->[0]);
			#		setGroovyKindData($methodNode, 'local_constants', $variables->[1]);
		}
		
		sendContextEvent(CTX_LEAVE);
		SetEndline($methodNode, getStatementLine());
		#my $varLst = parseVariableDeclaration($methodNode);
		#setGroovyKindData($methodNode, 'localVar', $varLst);
		
		Lib::ParseUtil::purgeSemicolon();
		
		return $methodNode;
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
#              CLOSURE
##################################################################

sub parseClosure(;$$) {
	# trashes '{'
	getNextStatement();
	my $stmt = "";
	
	my $closureNode = Node(ClosureKind, createEmptyStringRef());
	my $line = getStatementLine();
	SetLine($closureNode, $line);
	
	#-----------------------------------------------------------------------------------------------------------------------------
	# try parse parameters if any
	#
	# => parse args until encountering:
	# -   "->"
	# -   an End Of Line not following or preceding a ","
	my $previous;
	my $idx = 0;
	my $next = nextStatement($idx++);
	my @errors = ();
	
	my @args = ();
	while ((defined $next) && ($$next ne "->")) {

		$stmt = "";
	
		# try to parse one parameter.
		while ((defined $next) && ($$next ne ",") && ($$next ne "->")) {
			$stmt .= $$next;
			$previous = $next if ($$next =~ /\S/);
			$next = nextStatement($idx++);
		
			# if end of line, we are parsing args only if 
			# - there is a ','         before the \n
			# - there is a ',' or '->' after the \n
			if ((defined $next) && ($$next eq "\n")) {
				if ($$previous ne ',') {
					# previous is not coma, so check next ...
					$stmt .= $$next;
					
					# get all blanks
					while ((defined ($next = nextStatement($idx))) && ($$next !~ /\S/)) {
						$stmt .= $$next;
						$idx++;
					}
					if (defined nextStatement($idx)) {
						if ((${nextStatement($idx)} ne '->') && (${nextStatement($idx)} ne ',')) {
							# no args to parse
							$stmt = undef;
							last;
						}
					}
					else {
						# no more statement => stop parsing args
						$stmt = undef;
						last;
					}
				}
			}
		}
		
		last if (! defined $stmt);
		
		# parse one parameter
		my $name;
		my $type;
		if ($stmt =~ /(\w+)\s*$/m) {
			$name = $1;
			$type = $stmt;
			$type =~ s/$name//;
			$name =~ s/\s*//g;
			$type =~ s/\s*//g;
			push @args, {'name' => $name, 'type' => $type};
		}
		else {
			push @errors, "unknow closure argument syntax : $stmt";
		}
		
		if ((defined $next) && ($$next eq ',')) {
			$next = nextStatement($idx++);
		}
	}
	
	setGroovyKindData($closureNode, 'arguments', \@args);
	
	if ((defined $next) && ($$next eq "->")) {
		# we have encountered the args delimitor.
		my $arrow = $next;
		
		# Valid arguments parsing ...
		#$next = getNextStatement() while ($next != $arrow);
		while ($next != $arrow) {
			$next = getNextStatement();
		}
		
		# and log errors if any....
		if (scalar @errors) {
			for my $error (@errors) {
				Lib::Log::ERROR($error);
			}
		}
	}
	
	#-----------------------------------------------------------------------------------------------------------------------------
	
	# indicate in parent statement that a closure has been parser and is contained inside a subnode.
	$stmt = "{ HL_CLOSURE }";
	
	sendContextEvent(CTX_METHOD);

	Lib::ParseUtil::parseStatementsBloc($closureNode, [\&isNextClosingBrace], \@methodContent, 0);

	SetEndline($closureNode, getStatementLine());

	sendContextEvent(CTX_LEAVE);

	Lib::ParseUtil::purgeSemicolon();
	
	return [ \$stmt, [$closureNode]];
}

##################################################################
#              Function Call
##################################################################

sub parse_FunctionCall() {
	
}

##################################################################
#              NEW
##################################################################

sub isNextNew() {
	if ( ${nextStatement()} eq 'new' ) {
		return 1;
	}  
	return 0;
}

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
			my $artiKey = Lib::ParseUtil::newArtifact('AnonymousClass_at_line', getNextStatementLine());
			
			my $anoClass = parseClassContext(AnonymousClassKind, 'anonymous');
			
			Lib::ParseUtil::endArtifact($artiKey, "{__${artiKey}__}");
			Append($newNode, $anoClass);
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
	#setGroovyKindData($root, 'artifact_key', $artiKey);

	while ( defined nextStatement() ) {
		my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);
		if (defined $subNode) {
			Append($root, $subNode);
		}
	}
	
	#Lib::ParseUtil::endArtifact('root');

	#my $variables = getVariables($root);
	#setjavaKindData($root, 'local_variables', $variables->[0]);
	#setjavaKindData($root, 'local_constants', $variables->[1]);
	return $root;
}

#
# Split a JS buffer into statement separated by structural token
# 

sub splitGroovy($) {
   my $r_view = shift;

   my  @statements = split /(\n|;|:|\(|\)|\{|\}|\[|\]|=|\@|->|\b(?:package|class|enum|interface|if|else|else\s+if|while|for|do|switch|case|default|try|catch|finally|break|continue|new|return|throw|import)\b|\b(?:(?:$re_MODIFIERS\b(?:\s+$re_MODIFIERS\b)*)))/sm, $$r_view;
   
   if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }
   return \@statements;
}


sub ParseGroovy($) {
  my $r_view = shift;
  
  my $r_statements = splitGroovy($r_view);

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

sub removeTemplating($) {
	my $code = shift;
	my $templating = 0;
	
	if ($$code =~ s/\$\{([\s\w+\.]+)\}/$1/g) {
		$templating = 1;
	}
	
	if ($$code =~ s/<\%(?:\%[^>]|[^%])*\%>//g) {
		$templating = 1;
	}
	
	if ($templating) {
		Lib::Log::INFO("templating has been removed for syntax compliance ...");
	}
}

# description: Groovy parse module Entry point.
sub Parse($$$$;$)
{
	my ($fichier, $vue, $couples, $options, $techno) = @_;
	my $status = 0;
	
	if (! defined $techno) {
		$TECHNO = "Groovy";
	}
	else {
		$TECHNO = $techno;
	}

	initMagicNumbers($vue);

	$StringsView = $vue->{'HString'};

	Lib::ParseUtil::registerParseUnknow(\&parseUnknow);

#    my $statements =  $vue->{'statements_with_blanks'} ;

	if ($TECHNO eq "Groovy") {
		Lib::ParseUtil::setEndingInstructionsCriteria(\&nextItemIsEndingInstruction);
		Lib::ParseUtil::setParseAccolade(\&parseClosure);
		@rootContent = @rootContentGroovy;
		$TRIGGERS_parseParenthesis = { "new" => \&triggerParseNew, "{" => \&parseClosure };
		$re_MODIFIERS = $re_MODIFIERS_Groovy;
	}
	elsif ($TECHNO eq "Java") {
		@rootContent = @rootContentJava;
		$TRIGGERS_parseParenthesis = { "new" => \&triggerParseNew };
		$re_MODIFIERS = $re_MODIFIERS_Java;
	}
	
	removeTemplating(\$vue->{'code_with_prepro'});

	# launch first parsing pass : strutural parse.
	#my ($GroovyNode, $Artifacts) = ParseGroovy(\$vue->{'code'});
	my ($GroovyNode, $Artifacts) = ParseGroovy(\$vue->{'code_with_prepro'});

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

	# flatten the blocks
	Java::ParseCommon::flattenBlocks($GroovyNode);

	if (defined $options->{'--print-tree'}) {
		Lib::Node::Dump($GroovyNode, *STDERR, "ARCHI");
	}
	if (defined $options->{'--print-test-tree'}) {
		print STDERR ${Lib::Node::dumpTree($GroovyNode, "ARCHI")} ;
	}

	$vue->{'structured_code'} = $GroovyNode;
	$vue->{'artifact'} = $Artifacts;

	# pre-compute some list of kinds :
	preComputeListOfKinds($GroovyNode, $vue, [MethodKind, FunctionKind, ClosureKind, ClassKind, ImportKind, ConditionKind, WhileKind, ForKind, EForKind, IfKind, ElseKind, FinallyKind, CatchKind, TryKind, CaseKind, SwitchKind, AttributeKind, AttributeDefKind, VariableDefKind, InterfaceKind, EnumKind]);

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

