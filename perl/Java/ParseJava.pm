package Java::ParseJava;
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

use Java::JavaNode;
use Groovy::ParseGroovy;

my $DEBUG = 0;

my @rootContent = ( 
			\&parseClass,
			\&parseEnum,
			\&parseInterface,
			\&parseImport,
			\&parseModifiers,
			\&parseAnnotation,
			\&parsePackage,
);

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

my $re_MODIFIERS = '(?:public|protected|private|static|abstract|final|native|synchronized|transient|volatile|strictfp)';
my $IDENTIFIER = '\w+';

my $StringsView = undef;

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

sub parseUnknow() {
	my $line = getNextStatementLine();
	
    if (${nextStatement()} eq '}') {
        getNextStatement();
        print STDERR "WARNING : unexpected closing brace at line ".getStatementLine()."\n"; 
        return undef;
    }

	# check for variable declaration
	return Java::ParseCommon::Parse_VariableOrUnknow();
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
	my $args = getJavaKindData($artifactNode, 'arguments');
	
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
	my $proto = '';
	
	# consumes the keyword
	getNextStatement();
	
	SetLine($node, getStatementLine());
	
	my ($statement, $subNodes) = Lib::ParseUtil::parse_Instruction();
	
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
		print "[ParseJava::parseCase] ERROR : missing semi-colon after case at end of file !!\n";
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
		print "[ParseJava::parseCase] ERROR : cannot find beginning '('\n";
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
		print "[ParseJava::parseCondition] ERROR : cannot find beginning '('\n";
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

	setJavaKindData($condNode, 'init', $init);
	setJavaKindData($condNode, 'cond', $cond);
	setJavaKindData($condNode, 'inc', $inc);
	
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
		if (! defined getJavaKindData(GetChildren($forNode)->[0], 'init') ) {
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
		print "[ParseJava::parse_block] WARNING : missing '{' at line ".getStatementLine()."\n" if $DEBUG;
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
			print "[ParseJava::parseControlBloc] SYNTAX ERROR  : missing condition !\n";
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
		setJavaKindData($controlNode, 'artifact_key', $artiKey);
	}
	
	parse_block($parentNode);
	
	if ($artiKey) {
		Lib::ParseUtil::endUnmodalArtifact($artiKey);
		setJavaKindData($controlNode, 'codeBody', Lib::ParseUtil::getArtifact($artiKey));
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
		
		setJavaKindData($artifactNode, 'modifiers', $modifiers);
		setJavaKindData($artifactNode, 'H_modifiers', \%H_mod);
		
		# case of several vars declared in the same instruction ... and so several node ...
		my $addnode = getJavaKindData($artifactNode, "addnode");
		if (defined $addnode) {
			for my $node (@$addnode) {
				setJavaKindData($node, 'modifiers', $modifiers);
				setJavaKindData($node, 'H_modifiers', \%H_mod);
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
				print STDERR "[ParseJava::parseAnnotation] WARNING : missing definition bloc for \@interface at line $line\n";
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
print "--> $kindName found...\n" if $DEBUG;
		sendContextEvent(CTX_CLASS);
		#Lib::ParseUtil::setArtifactUpdateState(0);

		#trash 'class' keyword
		#getNextStatement();
		
		my $statementLine = getStatementLine();
		SetLine($classNode, $statementLine);
		
#		setJavaKindData($classNode, 'indentation', Lib::ParseUtil::getIndentation());
		
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
		#setJavaKindData($classNode, 'artifact_key', $artiKey);

		while (nextStatement() && (${nextStatement()} ne '}')) {
			my $memberNode = Lib::ParseUtil::tryParse_OrUnknow(\@classContent);
			if (defined $memberNode) {
				Append($classNode, $memberNode);
			}
		}
		
		if (defined nextStatement()) {
			# trashes the '}'
			getNextStatement();
		}
		else {
			print STDERR "[PARSE] Error : missing closing '}' for class $name\n";
		}

		#Lib::ParseUtil::endArtifact($artiKey);
		
		sendContextEvent(CTX_LEAVE);
		
		SetEndline($classNode, getStatementLine());
		
#		my $variables = getVariables($classNode);
#		setJavaKindData($classNode, 'local_variables', $variables->[0]);
#		setJavaKindData($classNode, 'local_constants', $variables->[1]);
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
		
#		setJavaKindData($classNode, 'indentation', Lib::ParseUtil::getIndentation());
		
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
	setJavaKindData($node, 'type', $data->{'type'});
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
			setJavaKindData($addVarNode, 'type', $data->{'type'});
			if (defined $data->{'default'}) {
				Append($addVarNode, Node(InitKind, \$data->{'default'}));
			}
			SetLine($addVarNode, $line);
			push @add_vars, $addVarNode;
			# record info in the node : the var is declared inside same statement than previous.
			setJavaKindData($addVarNode, 'multi_var_decl', 1);
		}
		setJavaKindData($node, 'addnode', \@add_vars);
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

sub parseMember() {
	my $proto = '';
	my $stmt;

	my $line = undef;
	
	my $flag_init = 0;

	while ((defined ($stmt = nextStatement())) && ($$stmt ne ';') ) {
		if ($$stmt =~ /=/) {
			$flag_init = 1;
		}
		elsif ( $$stmt eq '(' ) {
			if ($flag_init == 0) {
				# opennenig parenth before encountering "=" means it's a method !
				last;
			}
		}
		
		if ($$stmt eq "{") {
			my $expr = Lib::ParseUtil::parseUntilPeer("{", "}");
			if (defined $expr) {
				$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.$$expr;
			}
		}
		else {
			$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}

		if (!defined $line) {
			$line = getStatementLine();
		}
	}

	if (!defined $stmt ) {
		print STDERR "[PARSE] Error : missing closing '}' for class\n";
	}
	elsif ($$stmt eq '(') {
		my ($name) = $proto =~ /(\w+)\s*(?:<.*>)?\s*$/sm;

		my $node = parse_Method($name, $line);
		return $node;
	}
	elsif ($$stmt eq ';') {
		print "FOUND attribute\n" if $DEBUG;
		# trashes the ";"
		Lib::ParseUtil::purgeSemicolon();
		my $varData = Lib::ParseArguments::parseVariableDeclaration(\$proto, $line);
		
		my $node = createVariablesNodes($proto, $varData, AttributeKind, $line);

		return $node;
	}
	else {
		print STDERR "[ParseJava::parseMember] ERROR : inconsistency encountered when parsing class member ()!!\n";
	}
	
	return undef;
}

##################################################################
#              METHOD
##################################################################

sub parse_Method($) {
		my $name = shift;
		my $line = shift;
		
		if (!defined $name) {
			print "[ParseJava::parse_Method] ERROR : undefined name for method\n";
			$name = "unknow_at_$line";
		}
		my $methodNode = Node(MethodKind, createEmptyStringRef());
print "--> METHOD $name found...\n" if $DEBUG;

		SetLine($methodNode, $line);

		sendContextEvent(CTX_METHOD);
		
		# temporary desactive artifact updating: the prototype of the function should not appears in the encompassing (parent) artifact.
		# This to prevent some argument with default values (xxx = ) to be considered as  parent's variable while greping variable in parent's body.
		#Lib::ParseUtil::setArtifactUpdateState(0);

#		setJavaKindData($methodNode, 'indentation', Lib::ParseUtil::getIndentation());

		my $proto = '';
		my $stmt;
		while ((defined ($stmt = nextStatement())) && ($$stmt ne '{') && ($$stmt ne ';')) {
			$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}

		SetStatement($methodNode, \$proto);
		SetName($methodNode, $name);
		
		if (! defined nextStatement()) {
			print STDERR "[PARSE] Error : missing openning '{' for method $name\n";
		}
		else {
			# trashes the '{' or ';'
			getNextStatement();
		}
		
		setJavaKindData($methodNode, 'arguments', Lib::ParseArguments::parseArguments($methodNode));

		if ($$stmt eq '{') {
			# **** presence of a body (not an abstract - virtual pure - method).

			# declare a new artifact
			my $artiKey = Lib::ParseUtil::newArtifact('func_'.$name, $line);
			setJavaKindData($methodNode, 'artifact_key', $artiKey);
		

			#		my $lines_in_proto = () = $proto =~ /\n/g;
			#		setJavaKindData($methodNode, 'lines_in_proto', $lines_in_proto);
		
			#		Lib::ParseUtil::setArtifactUpdateState(1);
		
			while (nextStatement() && (${nextStatement()} ne '}')) {
				my $node = Lib::ParseUtil::tryParse_OrUnknow(\@methodContent);
				if (defined $node) {
					Append($methodNode, $node);
				}
			}
		
			#end of artifact
			Lib::ParseUtil::endArtifact($artiKey);
			setJavaKindData($methodNode, 'codeBody', Lib::ParseUtil::getArtifact($artiKey));
		
			if (defined nextStatement()) {
				# trashes the '}'
				getNextStatement();
			}
			else {
				print STDERR "[PARSE] Error : missing closing '}' for method $name\n";
			}
		
			#		my $variables = getVariables($methodNode);
			#		setJavaKindData($methodNode, 'local_variables', $variables->[0]);
			#		setJavaKindData($methodNode, 'local_constants', $variables->[1]);
		}
		
		sendContextEvent(CTX_LEAVE);
		SetEndline($methodNode, getStatementLine());
		#my $varLst = parseVariableDeclaration($methodNode);
		#setJavaKindData($methodNode, 'localVar', $varLst);
		
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
			my $anoClass = parseClassContext(AnonymousClassKind, 'anonymous');
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
	#setJavaKindData($root, 'artifact_key', $artiKey);

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

sub splitJava($) {
   my $r_view = shift;

   my  @statements = split /(\n|;|:|\(|\{|\}|=|\@|\b(?:package|class|enum|interface|if|else|else\s+if|while|for|do|switch|case|default|try|catch|finally|break|continue|new|return|throw|import)\b|(?:(?:$re_MODIFIERS\b\s*)+))/sm, $$r_view;
   
   if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }
   return \@statements;
}


sub ParseJava($) {
  my $r_view = shift;
  
  my $r_statements = splitJava($r_view);

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

# description: Java parse module Entry point.
sub Parse($$$$)
{
	my ($fichier, $vue, $couples, $options) = @_;
	
	return Groovy::ParseGroovy::Parse($fichier, $vue, $couples, $options, "Java");
	
	my $status = 0;

	initMagicNumbers($vue);

	$StringsView = $vue->{'HString'};

	Lib::ParseUtil::registerParseUnknow(\&parseUnknow);

#    my $statements =  $vue->{'statements_with_blanks'} ;

	# launch first parsing pass : strutural parse.
	my ($JavaNode, $Artifacts) = ParseJava(\$vue->{'code_with_prepro'});

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

	# flatten the blocks
	Java::ParseCommon::flattenBlocks($JavaNode);

	if (defined $options->{'--print-tree'}) {
		Lib::Node::Dump($JavaNode, *STDERR, "ARCHI");
	}
	if (defined $options->{'--print-test-tree'}) {
		print STDERR ${Lib::Node::dumpTree($JavaNode, "ARCHI")} ;
	}

	$vue->{'structured_code'} = $JavaNode;
	$vue->{'artifact'} = $Artifacts;

	# pre-compute some list of kinds :
	preComputeListOfKinds($JavaNode, $vue, [MethodKind, ClassKind, ImportKind, ConditionKind, WhileKind, ForKind, EForKind, IfKind, CatchKind, TryKind, CaseKind, SwitchKind, AttributeKind, InterfaceKind, EnumKind]);

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

