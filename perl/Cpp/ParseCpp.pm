package Cpp::ParseCpp;
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
use Lib::Log;
use Java::ParseCommon;
use Java::ParseJava;

use Cpp::CppNode;

my $DEBUG = 0;

my @rootContent = ( 
            \&parseClass,
            \&parseStruct,
            \&parseUnion,
            \&parseTypedef,
            \&parseTemplate,
			## \&parseEnum,
            \&parseNamespace,
			# \&parseImport,
			\&parseModifiers,
			## \&parseAnnotation,
			## \&parsePackage,
			\&parseUsing,
			\&parseBlock,
			\&parseExtern,
			\&parseRootInstruction
            
);

my @erroneousRootContent = (
			\&parseIf,
			\&parseReturn,
			\&parseWhile,
			\&parseFor,
			\&parseDo,
			\&parseTry,
			\&parseThrow,
			\&parseSwitch,
			\&parseBreak,
			\&parseContinue,
			\&parseUsing,
);

my @classContent = (
			\&parseModifiers,
			\&parseClass,
            \&parseStruct,
            \&parseUnion,
            \&parseTypedef,
            \&parseTemplate,
			## \&parseEnum,
			## \&parseAnnotation,
			# \&parseBlock,
			#\&parseClassMember,
			\&parseClassInstruction,
);

my @routineContent = ( 
			\&parseClass,
            \&parseStruct,
            \&parseUnion,
            \&parseTypedef,
			## \&parseEnum,
			\&parseModifiers,
			\&parseIf,
			\&parseReturn,
			\&parseWhile,
			\&parseFor,
			\&parseDo,
			\&parseTry,
			\&parseThrow,
			\&parseSwitch,
			\&parseBreak,
			\&parseContinue,
			\&parseUsing,
			\&parseBlock,
			# \&parseTemplate,
			# \&parseBlock,
			## \&parseAnnotation
);

my @switchContent = ( 
			\&parseCase,
			\&parseDefault,
);

my $NullString = '';

my $re_MODIFIERS = '(?:public|protected|private|virtual|friend|static|final|const|native|synchronized|transient|volatile|strictfp|constexpr|inline|ref|value)';
my $IDENTIFIER = '\w+';

my $StringsView = undef;

########################## TRIGGERS ##################

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

# callback used to read the name of an operator overload method. Indeed, such names can contain
# item like <, >, .. that are used to specific syntax detection if not part of an operator overload name !!
sub parse_SN_OperatorOverload() {
	my $expression = "";
	
	# Consumes the "operator"
	$expression .= ${getNextStatement()};
	
	# swallow everything until "("
	my $stmt;
	while ( (defined ($stmt = nextStatement())) && ($$stmt ne "(") ) {
		$expression .= ${getNextStatement()};
	}
	
	return [ \$expression, [] ];
}

my $Expression_TriggeringItems = {
	"<" => \&parse_SN_ExpressionLessThan,
	"operator" => \&parse_SN_OperatorOverload,
};


########################## CONTEXT ###################

use constant CTX_LEAVE => -1;
use constant CTX_ROOT => 0;
use constant CTX_CLASS => 1;
use constant CTX_ROUTINE => 2;
use constant CTX_ENUM => 3;
use constant CTX_INTERFACE => 4;
use constant CTX_SWITCH => 5;

my $DEFAULT_CONTEXT = CTX_ROOT;

my @context = (CTX_ROOT);

my %ContextContent = (
	&CTX_ROOT() => \@rootContent,    
	&CTX_CLASS() => \@classContent,
	&CTX_ROUTINE() => \@routineContent,
	# &CTX_ENUM() => \@classContent,
	# &CTX_INTERFACE() => \@classContent,
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
		Lib::Log::ERROR("context underflow !");
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
		Lib::Log::ERROR("empty context !");
		return $DEFAULT_CONTEXT;
	}
}

sub parseUnknow() {
	my $line = getNextStatementLine();

    if (${nextStatement()} eq '}') {
        getNextStatement();
        Lib::Log::WARNING("unexpected closing brace at line ".getStatementLine()); 
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

################# END INSTRUCTION CRITERIA ##############

sub nextTokenIsEndingInstruction($) {
	my $stmt = shift;
	my $skippedBlanks = ${Lib::ParseUtil::getSkippedBlanks()};
	if ($skippedBlanks =~ /\n/) {
		if ($$stmt =~ /\)\s*$/) {
			# closing prenthese at end of line ... mmmh ...
			my $next = ${nextStatement()};
			if (($next ne ";") and ($next !~ /^\s*[+\-*\/^%&|=!<>.\[]/)) {
				# not followed by ; or an operator => certainly a macro call so end the instruction
				return 1;
			}
		}
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

   if (! exists $H_MagicNumbers{$magic}) {
     $H_MagicNumbers{$magic}=1;
   }
   else {
     $H_MagicNumbers{$magic}++;
   }
#print "---> MAGIC = $magic\n";
}

sub getMagicNumbers($) {
	my $r_expr = shift;

	# reconnaissance des magic numbers :
	# 1) identifiants commencant forcement par un chiffre decimal.
	# 2) peut contenir des '.' (flottants)
	# 3) peut contenir des 'E' ou 'e' suivis eventuellement de '+/-' pour les flottants
	# 4) peut se terminer par un suffixe u, l ou f.
	#while ( $$r_expr =~ /(?:^|[^\w])((?:\d|\.\d)(?:[e][+-]?|[\d\w\.])*)/sg )
	while ( $$r_expr =~ /\b(\d+\w*\.?\w*[+-]?\w*)/sg )
	{
		my $magic = $1;

		declareMagic($magic);
	}
}

################# Missing New Line after controle #########################

my %H_MissingNewLineAfterControle;

sub initMissingNewLineAfterControle($) {
  my $view = shift;

  %H_MissingNewLineAfterControle = ();
  $view->{'HMissingNewLineAfterControle'} = \%H_MissingNewLineAfterControle;
}

sub declareMissingNewLineAfterControle() {
#print "--> MISSING new line continuation at line ".getStatementLine()."\n";
	$H_MissingNewLineAfterControle{getStatementLine()} = 1;
}

sub expectNewLineAfterControle() {
	if (defined nextStatement()) {
		my $next = ${nextStatement()};
		if ($next !~ /^\\?\s*\n/) {
			declareMissingNewLineAfterControle();
		}
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

# FIX ME : sub unchanged ready for implement into library
sub ParseGeneric($) {
	my $kind = shift;

	my $node = Node($kind, createEmptyStringRef());
	my $proto = '';
	
	# consumes the keyword
	getNextStatement();
	
	SetLine($node, getStatementLine());
	
	my ($stmt) = Lib::ParseUtil::parse_Instruction();
	SetStatement($node, $stmt);
	
	return $node;
}

##################################################################
#              ROOT OR CLASS INSTRUCTION
##################################################################

sub parseInitializationList() {
	my $init = "";
	my $stmt;
	if (Lib::ParseUtil::splitNextStatementAfterPattern(':')) {
		getNextStatement(); # trash colon.

		while (defined ($stmt=nextStatement()) && ($$stmt ne '{') && ($$stmt ne ';') && ($$stmt ne '}')) {
			# assume an initialization list is compliant with the pattern
			# <attr name1> (...)|{...} ,  <attr name2> (...)|{...} , ....,
			while (defined ($stmt=nextStatement()) && ($$stmt ne '(') && ($$stmt ne '{')) {
				$init .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};;
			}
			$init.= ${Lib::ParseUtil::parseRawOpenClose()};
			if (Lib::ParseUtil::splitNextStatementAfterPattern(',')) {
				getNextStatement(); # trash coma.
			}
		}
	}
#print STDERR "INITIALISATION LIST = $init\n";
	return \$init;
}

sub parseRootOrClassInstruction($) {
	my $artifact = shift;
	
	my $node;
#print STDERR "ROOT INSTR : ".${nextStatement()}."\n";
	my $line = getNextStatementLine();
	
    my $resultParseParenthesis;
    my $contentParenthesis;

	# for robustness, check presence of unexpected keywords
	my $erroneousNode = Lib::ParseUtil::tryParse(\@erroneousRootContent);
	if (defined $erroneousNode) {
		Lib::Log::WARNING("Unexpected node (".GetKind($erroneousNode).") in $artifact context !");
		return $erroneousNode;
	}

    # we want stop parsing the expression on particular items :
    # "("  ->  potential function
    # "=" or ","  -> potential variable assignement or multivariable declaration
    my $STOP_ITEMS = {"=" => 1, "," => 1, "(" => 1};
    
    # we need to split on :
    #      "=" and "," because it is stop item for parse_Expression()
    #      "<" because there is a "trigger expression" for this item
	Lib::ParseUtil::register_SplitPattern(qr/[=,<]/);

		my ($statement, $subNodes) = Lib::ParseUtil::parse_Expression($STOP_ITEMS);
	
	Lib::ParseUtil::release_SplitPattern();

    # Maybe a method declaration ??
    # -----------------------------
    # 1) A routine prototype contains at least a type and a name that is at least two identifier separated by &, * or SPACE
    #		<type> [*&]* <name>
    # 2) constructor
    #		<className>::<className>
    # 3) destructor
    #		<className>::~<className>
    #
    # NOTE :	no problem in class context => do not check complience  of $$statement.
    # 			root context is the default context if the parser has not recognized a "routine" context. 
    #			So routine instruction may be encountered in root context, and we should filter tem.
    

   
	if ( (defined nextStatement()) && (${nextStatement()} eq '(' )) {
		
		# maybe a function or method proto.		
		
		my $isRoutine = 0;
		if ($artifact eq 'class') {
			# in class context ==> it's a method proto
			$isRoutine = 1;
		}
		else {
			# in root context it could be a function proto or a function call.
			
			# create a tempo statement with no template syntax ...
			my $tmp_stmt = $$statement;
			#$regex = qr/<(?:[^<>]*|\R)>/;
			$tmp_stmt =~ s/(<(?:[^<>]|(?1))*>)//g;
			
			if (($tmp_stmt =~ /\w+[&\*\s]+\w/) ||            # two words separated by * or &, cannot be a function call
				($tmp_stmt =~ /(\w+)\s*::\s*(~\s*)?\1\b/)) { # constructor or destructor
				$isRoutine = 1;
			}
		}
   
		if ($isRoutine) {
			my $routineKind = (getContext() == CTX_CLASS ? MethodKind : FunctionKind);
			my $routinePrototypeKind = (getContext() == CTX_CLASS ? MethodPrototypeKind : FunctionPrototypeKind);
		
			# parse content of the parentheses
			$resultParseParenthesis = Lib::ParseUtil::parseParenthesis('(');
			$contentParenthesis = $resultParseParenthesis->[0];

			if (defined nextStatement()) {
				# consumes the "const" and "noexcept" keywords, if any …
				while (${nextStatement()} =~ /^\s*(?:const|noexcept)\b/mg) {
					Lib::ParseUtil::splitAndFocusNextStatementOnPos();
				}

				# it is a method ...
				if (${nextStatement()} eq '{') 
				{	
					return parseRoutine($statement, $contentParenthesis, $line, $routineKind);
				}
				# it is a method without body
				elsif (${nextStatement()} =~ /;/) 
				{
					return parseRoutine($statement, $contentParenthesis, $line, $routinePrototypeKind);
				}
		
				elsif (${nextStatement()} eq 'try') 
				{
					my $funcNode = parseRoutine($statement, $contentParenthesis, $line, FunctionKind);
					setCppKindData($funcNode, 'function-try-block', 1);
					return $funcNode;
				}
				elsif (${nextStatement()} eq 'throw') 
				{
					my $throw_stmt = ${getNextStatement()};
					# parse content of the parentheses
					my $resultParseParenthesis = Lib::ParseUtil::parseParenthesis('(');
					$throw_stmt .= ${$resultParseParenthesis->[0]};
			
					my $funcNode = parseRoutine($statement, $contentParenthesis, $line, FunctionKind);
					setCppKindData($funcNode, 'throw', \$throw_stmt);
					return $funcNode;
				}
				# it is a pure virtual method
				elsif ( (getContext() == CTX_CLASS) && (${nextStatement()} =~ /\A\s*=\s*(0|delete)\b/))
				{
					my $value = $1;
					# trash the "=..." statement
					getNextStatement();
			
					my $node = parseRoutine($statement, $contentParenthesis, $line, MethodPrototypeKind);
					if ($value eq "0") {
						setCppKindData($node, 'PureVirtual', 1);
					}
					elsif ($value eq "delete") {
						setCppKindData($node, 'delete', 1);
					}
					return $node;
				}
				# it is a constructor with its initialization list ...
				elsif (${nextStatement()} =~ /:/) {
					# Note : parse_expression will not stop on { that are enclosed inside parentheses ( :attr({1, 2} )
					#my ($stmt, $subNodes) = Lib::ParseUtil::parse_Expression({"{" =>1});
					# FIXME : $statement and subnodes are not taken into account  !!! should be used to initialize a data field of the routine node ???
				
					parseInitializationList();
					return parseRoutine($statement, $contentParenthesis, $line, $routineKind);
				}
		
		
				# ROBUSTNESS AGAINST #DEFINE and CONDITIONAL COMPILATION
				elsif (${nextStatement()} =~ /^\s*\w/m) {
					my $makeUnknowNode = 0;
					# MACRO Call
					if (	($$statement =~ /^\s*\w+\s*$/m)&&
							(${Lib::ParseUtil::getSkippedBlanks()} =~ /\n/) ){
						# the closing parenthese is not followed by a ";"
						# so, if the parentheses are preceded by a single word, and are followed on the next line by another word, there is a lot's of chances it is a macro call.
						$makeUnknowNode = 1;
					}
					# BAD SYNTAX, but could be issued from conditional compilation.
					elsif ($$statement =~ /\w+\s*$/m) {
						$makeUnknowNode = 1;
					}
				
					if ($makeUnknowNode) {
					
						$$statement .= $$contentParenthesis;

						my $node = Node(UnknowKind, $statement);
						my $line = getStatementLine();
						SetLine($node, $line);
						Lib::Log::INFO("encountered macro usage : $$statement at line $line") if ($DEBUG);
						return $node;
					}
				}
		
				# it is not function, just update the statement
				else 
				{
					$$statement .= $$contentParenthesis;
				}
			}
			else {
				$$statement .= $$contentParenthesis;
			}
		}
	}
#print STDERR "==> Not parsed as a routine ($$statement)\n";

	# OK, not a method/function. Maybe an attribute declaration ??
	
	return Java::ParseCommon::Parse_VariableOrUnknow($statement, $line, (getContext()==CTX_CLASS ? AttributeKind : VariableKind) );
	
	
	#if (! defined $node) {   
		#$node = Node(UnknowKind, $statement);
		## parse the statement until the end of the instruction
		#my @expUpdateInfos = Lib::ParseUtil::parse_Instruction();
		#Lib::ParseUtil::updateGenericParse($statement, $node, \@expUpdateInfos);
    #}
    
    #Lib::ParseUtil::purgeSemicolon(); # consumes one or more ;
    
    #return $node;
}

sub parseRootInstruction() {
	return parseRootOrClassInstruction('root');
}

sub parseClassInstruction() {
	return parseRootOrClassInstruction('class');
}

##################################################################
#              EXTERN
##################################################################

sub parseExtern() {
	if ( ${nextStatement()} =~ /\A\s*extern\b/gc ) {
		# trashes extern keyword.
		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		
		# trashes string if any ...
		if ( ${nextStatement()} =~ /\A\s*CHAINE_\d+\b/gc ) {
			Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		}
		
		my $statement = "";
		
		my $externNode = Node(ExternKind, \$statement);
		
		my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);
		
		if (defined $subNode) {
			Append($externNode, $subNode);
		}

		return $externNode;
	}
	return undef; 
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
		
		#sendContextEvent(CTX_METHOD);
		
		my $blocNode = Node(BlockKind, createEmptyStringRef());
		SetLine($blocNode, getNextStatementLine());

		Lib::ParseUtil::parseStatementsBloc($blocNode, [\&isNextClosingBrace], getCurrentContextContent(), 0);

		SetEndline($blocNode, getStatementLine());

		#sendContextEvent(CTX_LEAVE);

		Lib::ParseUtil::purgeSemicolon();
	
		return $blocNode;
	}

	return undef;
}

##################################################################
#              ROUTINE
##################################################################

sub parsePrototypeRoutine($$)
{
	my $proto = shift;
	my $line = shift;

	# Init data for type parsing ...
	my $data = Lib::ParseArguments::initVarData($line);
	
	# operatorXXX function are very disturbing, because XXX can be any operator item. So, analysis functions
	# based on word matching can not be used. So here after is dedicated treatment :
	if ($$proto =~ /(.*)(\boperator\b.*)/) {
		$data->{'type'} = $1;
		$data->{'name'} = $2;
		
		$data->{'type'} =~ s/\s*$//m;
	}
	else {
		# PARSE THE RETURN TYPE
		# -> make this type the function's name if there is nothing behiond it !!!
		if ( (defined Lib::ParseArguments::parseType($proto, $data)) &&
			($$proto =~ /\G\s*\z/gc))  {
			# No name following the type => the type is en reality the name (in a contructor, there is no type) !!
			$data->{'name'} = $data->{'type'}
		}
		else {
			if (! defined $data->{'type'}) {
				pos ($$proto)=0;
			}
			# the type has been parsed (and available in $data->{type}, so  parse the name, using full namespace parsing.
			my $nameParts = parseFullname($proto);
#print STDERR "TYPE = $data->{'type'}\n" if defined $data->{'type'};
#print STDERR "NAME = ".join('::', @$nameParts)." at line $line\n";
			my $name = pop @$nameParts;
			if (! defined $name) {
				Lib::Log::WARNING("cannot parse name for proto : $$proto");
			}
			else {
				($name) = $name =~ /\A((?:~\s*)?[\w]+)/;
				$data->{'name'} = $name;
				$data->{'namespace'} = \@$nameParts;
			}
		}
	}
	
	if (defined $data->{'type'}) {
		$data->{'type'} =~ s/\s//g;
	}
	return $data;
}

sub parseRoutine($$$$) {
		my $proto = shift;
		my $args = shift;
		my $line = shift;
		my $kind = shift;
        
#print "ROUTINE PROTO : $$proto\n";

        my $name;

		my $data = parsePrototypeRoutine($proto, $line);
		
		if ( (!defined $data) || (! defined $data->{'name'})) {
			Lib::Log::INFO("try to retrieve routine name with alternate solution ...");
			# standard case -- name immediately followed by (
			if ($$proto =~ /(~?\w+)\s*$/m) {
				$name = $1;
			}
		
			# template specialization ? 
			# ex : template <> void myfunc<type>( ... )
			else {
				my $proto1 = $$proto;
				# remove nested template
				while ($proto1 =~ s/<[^<]*<[^<>]*>/</s){};
#print "---> Simplified proto = $proto1\n";
				if ($proto1 =~ /(~?\w+)\s*<[^>]*>\s*\z/s) {
					$name = $1;
				}
				else {
					Lib::Log::WARNING("cannot find routine name in prototype : $$proto !!");
					$name = "";
				}
			}
		}
		else { 
			$name = $data->{'name'};
		}

		my $routineNode = Node($kind, $args);
#print STDERR "--> ROUTINE ($kind) $name found at line $line...\n";

		SetLine($routineNode, $line);
		SetName($routineNode, $name);

		sendContextEvent(CTX_ROUTINE);
		
		# temporary desactive artifact updating: the prototype of the function should not appears in the encompassing (parent) artifact.
		# This to prevent some argument with default values (xxx = ) to be considered as  parent's variable while greping variable in parent's body.
		#Lib::ParseUtil::setArtifactUpdateState(0);

#		setJavaKindData($routineNode, 'indentation', Lib::ParseUtil::getIndentation());

		setCppKindData($routineNode, 'type', $data->{'type'});

		setCppKindData($routineNode, 'arguments', Lib::ParseArguments::parseArguments($routineNode));

		if (nextStatement()) {
			if (${nextStatement()} eq '{') {
				# **** presence of a body (not an abstract - virtual pure - method).
				
				# consumes the opening '{'
				getNextStatement();

				# declare a new artifact
				my $artiKey = Lib::ParseUtil::newArtifact('func_'.$name, $line);
				setCppKindData($routineNode, 'artifact_key', $artiKey);
		

				#		my $lines_in_proto = () = $proto =~ /\n/g;
				#		setJavaKindData($routineNode, 'lines_in_proto', $lines_in_proto);
		
				#		Lib::ParseUtil::setArtifactUpdateState(1);
		
				while (nextStatement() && (${nextStatement()} ne '}')) {
					my $node = Lib::ParseUtil::tryParse_OrUnknow(\@routineContent);
					if (defined $node) {
						Append($routineNode, $node);
					}
					# consumes the ';'
					Lib::ParseUtil::purgeSemicolon();
				}
		
				#end of artifact
				Lib::ParseUtil::endArtifact($artiKey);
				setCppKindData($routineNode, 'codeBody', Lib::ParseUtil::getArtifact($artiKey));
		
				if (defined nextStatement()) {
					# trashes the '}'
					getNextStatement();
				}
				else {
					Lib::Log::ERROR("missing closing '}' for routine $name");
				}
		
				#		my $variables = getVariables($routineNode);
				#		setJavaKindData($routineNode, 'local_variables', $variables->[0]);
				#		setJavaKindData($routineNode, 'local_constants', $variables->[1]);
			}
			elsif (${nextStatement()} eq 'try') {
				# declare a new artifact
				my $artiKey = Lib::ParseUtil::newArtifact('func_'.$name, $line);
				setCppKindData($routineNode, 'artifact_key', $artiKey);
				
				Append($routineNode, parseTry());
				
				#end of artifact
				Lib::ParseUtil::endArtifact($artiKey);
				setCppKindData($routineNode, 'codeBody', Lib::ParseUtil::getArtifact($artiKey));
			}
		
			# method without body
			else {
				#getNextStatement();
			}
		}

		sendContextEvent(CTX_LEAVE);
		SetEndline($routineNode, getStatementLine());
		#my $varLst = parseVariableDeclaration($routineNode);
		#setJavaKindData($routineNode, 'localVar', $varLst);
		
        Lib::ParseUtil::purgeSemicolon();
		print "--> End of ROUTINE $name...\n" if $DEBUG;

		return $routineNode;
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
#              USING
##################################################################

sub isNextUsing() {
	if ( ${nextStatement()} =~ /^using\b/ ) {
		return 1;
	}  
	return 0;
}

sub parseUsing() {
	if (isNextUsing()) {
		return ParseGeneric(UsingKind);
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

# FIX ME : sub unchanged ready for implement into library
sub isNextReturn() {
	if ( ${nextStatement()} eq 'return' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
sub parseReturn() {
	if (isNextReturn()) {
		return ParseGeneric(ReturnKind);
	}
	return undef;
}

##################################################################
#              THROW
##################################################################

# FIX ME : sub unchanged ready for implement into library
sub isNextThrow() {
	if ( ${nextStatement()} eq 'throw' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
sub parseThrow() {
	if (isNextThrow()) {
		return ParseGeneric(ThrowKind);
	}
	return undef;
}

##################################################################
#              CONTINUE
##################################################################

# FIX ME : sub unchanged ready for implement into library
sub isNextContinue() {
	if ( ${nextStatement()} eq 'continue' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
sub parseContinue() {
	if (isNextContinue()) {
		return ParseGeneric(ContinueKind);
	}
	return undef;
}

##################################################################
#              BREAK
##################################################################

# FIX ME : sub unchanged ready for implement into library
sub isNextBreak() {
	if ( ${nextStatement()} eq 'break' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
sub parseBreak() {
	if (isNextBreak()) {
		return ParseGeneric(BreakKind);
	}
	return undef;
}

##################################################################
#              SWITCH
##################################################################

# FIX ME : sub unchanged ready for implement into library
sub isNextSwitch() {
		if ( ${nextStatement()} eq 'switch' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
sub parseSwitch() {
	if (isNextSwitch()) {
		sendContextEvent(CTX_SWITCH);
		my $ret = parseControle(SwitchKind, [], 1, 0); # COND and no THEN level
		sendContextEvent(CTX_LEAVE);
		return $ret;
	}
	return undef;
}

# FIX ME : sub unchanged ready for implement into library
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
		Lib::Log::ERROR("missing semi-colon after case at end of file !!");
	}
		
	SetStatement($caseNode, \$cond);
		
	# content of a "case" is the same as a method ... (full instruction set ...)
	sendContextEvent(CTX_ROUTINE);
	while (($next=${nextStatement()}) && ($next ne 'case') && ($next ne 'default') && ($next ne '}')) {
		my $node = Lib::ParseUtil::tryParse_OrUnknow(getCurrentContextContent());
		if (defined $node) {
			Append($caseNode, $node);
		}
	}
	SetEndline($caseNode, getStatementLine());
	
	sendContextEvent(CTX_LEAVE);
	
	if (! defined $next) {
		Lib::Log::ERROR("cannot find beginning '('");
	}
		
	return $caseNode;
}

# FIX ME : sub unchanged ready for implement into library
sub isNextCase() {
		if ( ${nextStatement()} eq 'case' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
sub parseCase() {
	if (isNextCase()) {
		return parseCaseDefault(CaseKind);
	}
	return undef;
}

# FIX ME : sub unchanged ready for implement into library
sub isNextDefault() {
		if ( ${nextStatement()} eq 'default' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
sub parseDefault() {
	if (isNextDefault()) {
		return parseCaseDefault(DefaultKind);
	}
	return undef;
}

##################################################################
#              TRY
##################################################################

# FIX ME : sub unchanged ready for implement into library
sub isNextCatch() {
		if ( ${nextStatement()} eq 'catch' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
sub parseCatch() {
	if (isNextCatch()) {
		return parseControle(CatchKind, [], 1);
	}
	return undef;
}

# Finally instruction doesn't exist in C++ parseFinally to deactivate
sub isNextFinally() {
		if ( ${nextStatement()} eq 'finally' ) {
		return 1;
	}  
	return 0;
}
# Finally instruction doesn't exist in C++ parseFinally to deactivate
sub parseFinally() {
	if (isNextFinally()) {
		
		return parseControle(FinallyKind, [], 0, 0);
	}
	return undef;
}

# FIX ME : sub unchanged ready for implement into library
sub isNextTry() {
		if ( ${nextStatement()} eq 'try' ) {
		return 1;
	}  
	return 0;
}

# Finally instruction doesn't exists in c++
sub parseTry() {

	if (isNextTry()) {
		# return parseControle(TryKind, [\&parseCatch, \&parseFinally], 0);
		return parseControle(TryKind, [\&parseCatch], 0);
	}
	return undef;
}

##################################################################
#              CONDITION (IF / WHILE / FOR ...)
##################################################################
# FIX ME : sub unchanged ready for implement into library
sub parseCondition() {
	my $condNode = Node(ConditionKind, createEmptyStringRef());
	my $condition = '';
	
	SetLine($condNode, getStatementLine());
	
	my $stmt;
    my $resultParseParenthesis;

	# consumes each (i.e for each)
	getNextStatement() if ((defined ($stmt = nextStatement())) && ($$stmt eq " each "));

	if ((defined ($stmt = nextStatement())) && ($$stmt eq "(")) {
		# $condition .= parseParenthesis('(');
        $resultParseParenthesis = Lib::ParseUtil::parseParenthesis('(');
        $condition = $resultParseParenthesis->[0];
        # $condition .= Lib::ParseUtil::parseParenthesis('(');
	}
	else {
		Lib::Log::ERROR("cannot find beginning '('");
		return undef;
	}

# print "CONDITION : $$condition\n";

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

	setCppKindData($condNode, 'init', $init);
	setCppKindData($condNode, 'cond', $cond);
	setCppKindData($condNode, 'inc', $inc);
	
	SetStatement($condNode, $condition);
	
	return $condNode;
}

##################################################################
#              IF
##################################################################

# FIX ME : sub unchanged ready for implement into library
sub isNextElse() {
	if ( ${nextStatement()} eq 'else' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
sub parseElse() {
	if (isNextElse()) {
		my $ret = parseControle(ElseKind, [], 0, 0); # no cond, no then level.
		return $ret;
	}
	return undef;
}

# FIX ME : sub unchanged ready for implement into library
sub isNextIf() {
	if ( ${nextStatement()} eq 'if' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
sub parseIf() {
	if (isNextIf()) {
		return parseControle(IfKind, [\&parseElse]);
	}
	return undef;
}

# FIX ME : sub unchanged ready for implement into library
sub isNextWhile() {
	if ( ${nextStatement()} eq 'while' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
sub parseWhile() {
	if (isNextWhile()) {
		return parseControle(WhileKind, []);
	}
	return undef;
}

# FIX ME : sub unchanged ready for implement into library
sub isNextFor() {
	if ( ${nextStatement()} eq 'for' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
sub parseFor() {
	if (isNextFor()) {
		my $forNode = parseControle(ForKind, [], 1, 1, 1); # cond + then level + record body
		# Note : first child is the condition node !!
		if (! defined getCppKindData(GetChildren($forNode)->[0], 'init') ) {
			# if there is no 'init' clause in the condition node, then it is an enhanced for loop.
			SetKind($forNode, EForKind);
		}
		return $forNode
	}
	return undef;
}

# FIX ME : sub unchanged ready for implement into library
sub isNextDo() {
	if ( ${nextStatement()} eq 'do' ) {
		return 1;
	}  
	return 0;
}

# FIX ME : sub unchanged ready for implement into library
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
		Lib::Log::WARNING("missing '{' at line ".getStatementLine()) if $DEBUG;
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

# FIX ME : sub unchanged ready for implement into library
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
			Lib::Log::ERROR("missing condition !");
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
		setCppKindData($controlNode, 'artifact_key', $artiKey);
	}
	
	parse_block($parentNode);
	
	if ($artiKey) {
		Lib::ParseUtil::endUnmodalArtifact($artiKey);
		setCppKindData($controlNode, 'codeBody', Lib::ParseUtil::getArtifact($artiKey));
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


my %ModifierKind = (
    'public' => PublicKind, 
    'protected' => ProtectedKind, 
    'private' => PrivateKind
);

sub parseModifiers() {
	if (isNextModifiers()) {
		my $modifiers = getNextStatement();
		my %H_mod;
		
		# VISIBILITY modifiers ...
        if (${nextStatement()} eq ':') {
            # consumes the :
            getNextStatement();

            $$modifiers =~ s/\s*$//m;
            
            # modifiers group
            my $kind = $ModifierKind{$$modifiers};

			if (! defined $kind) {
				Lib::Log::WARNING("unknow group modifier <$$modifiers> (public kind is assumed instead) !");
				$kind = PublicKind;
			}
				
            my $modifierGroupNode = Node($kind, createEmptyStringRef());
            my $stmt;
            
            while (defined ($stmt = nextStatement()) and $$stmt !~ /\b(?:public|private|protected)/ and $$stmt ne '}')
            {
                my $childNode = Lib::ParseUtil::tryParse_OrUnknow(getCurrentContextContent());
                Append($modifierGroupNode, $childNode);
            }

            return $modifierGroupNode;
        }
        
        # ANY OTHER modifiers ...
		while ($$modifiers =~ /(\w+)/g) {
			print '++++ modifier '.$1.' found'."\n" if ($DEBUG);
            $H_mod{$1} = 1;
		}	
		my $artifactNode = Lib::ParseUtil::tryParse_OrUnknow(getCurrentContextContent());
		
		setCppKindData($artifactNode, 'modifiers', $modifiers);        
        setCppKindData($artifactNode, 'H_modifiers', \%H_mod);
		
		# case of several vars declared in the same instruction ... and so several node ...
		my $addnode = getCppKindData($artifactNode, "addnode");
		if (defined $addnode) {
			for my $node (@$addnode) {
				setCppKindData($node, 'modifiers', $modifiers);
				setCppKindData($node, 'H_modifiers', \%H_mod);
			}
		}
		return $artifactNode;
	}
	return undef;
}

##################################################################
#              TEMPLATE
##################################################################

sub isNextTemplate() {
	if ( ${nextStatement()} =~ /\A\s*template\b/ ) {
		return 1;
	}  
	return 0;
}


sub updateNextStatement() {
	my $next = nextStatement();
	
	# if the next statement has been treated until end ...
	if ( (defined pos($$next)) and (length $$next eq pos($$next)) ) {
		# consumes it
		getNextStatement();
		# and seek to the next one ...
		$next = nextStatement();
	}
	return $next;
}

sub regOnNextStatement($) {
	my $reg = shift;
	my $next = updateNextStatement();
	
	return $$next =~ /$reg/gc;
}

sub parseTemplate() {
	if (isNextTemplate()) {
		
		my $statement = "";
		
		# Consumes the template
		my $next = nextStatement();
		$$next =~ /\A(\s*template\s*)/gc;
		
		$next = updateNextStatement();
		
		# Check present of the "<"
		if ($$next =~ /\G</gc) {
			$statement = "<";
			my $level = 1;
			
			# Consumes the content of the '< ... '
			# NOTE : assume that < or > cannot be followed by \d or =
			#       => this is to manage following exemple : template <typename =char, int=3<7  , char > class Decl91;
			
			while ($next = updateNextStatement()) {
				if ($$next =~ /\G	(?:(<)|(>))(?:\s*(\d|=)?)|
									(;)|
									([^<>;]+)/gcx) {
				
					# <
					if (defined $1) {
						$level++ if (!defined $3);
						$statement .= '<';
					}
					# >
					elsif (defined $2) {
						$level-- if (!defined $3);
						$statement .= '>';
						if ($level == 0) {
							last;
						}
					}
					# ;
					elsif (defined $4) {
						# template parameters can't contain ;
						Lib::Log::WARNING("semicolon encountered while parsing template parameters at line ".getStatementLine());
						pos($$next)--;
						last;
					}
					else {
						if (! defined $5) {
							print STDERR "NEXT = $$next\n";
						}
						else {
							$statement .= $5;
						}
					}
				}
				else {
					last;
				}
			}
		}

# print "TEMPLATE STATEMENT : $statement\n";

		Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		
        my $childNode = Lib::ParseUtil::tryParse_OrUnknow(getCurrentContextContent());
        
        setCppKindData($childNode, 'template', \$statement);
        
		return $childNode;
	}
	return undef;
}


sub parseTemplateParam($);
sub parseTemplateParam($) {
	my $proto = shift;
	my $stmt = "";
	
	while ($$proto =~ /\G(<|>|[^<>]+)/gc) {
		if ($1 eq '<') {
			$stmt .= '<'.parseTemplateParam($proto);
		}
		elsif ($1 eq '>') {
			$stmt .= ">";
			last;
		}
		else {
			$stmt .= $1;
		}
	}
	
	return $stmt;
}

sub parseFullname($) {
	my $proto = shift;
	my $current = "";
	my @namespace = ();
	my $previousIsName = 0;
	# while ($$proto =~ /\G(?:(~?\w+)|(::)|(<)|(\s+))/gc) {
	while ($$proto =~ /\G(?:((?:~\s*)?\w+)|(::)|(<)|(\s+))/gc) {

		my $pos = pos($$proto);
		if (defined $2) {
			# ::
			push @namespace, $current;
			$current = "";
			$previousIsName = 0;
		}
		elsif (defined $3) {
			# <
			$current .= '<'.parseTemplateParam($proto);
			$previousIsName = 0;
		}
		elsif (defined $4) {
			# \s+
			$current .= $4
		}
		else {
			# \w+
			if ($previousIsName) {
				# do not continue when encountering a second name following another
				# restore position of previous name ...
				 pos($$proto) = $previousIsName;
				
				last;
			}
			else {
				# pos($$proto) is true, because > 0 !!!!
				$previousIsName = pos($$proto);
				$current = $1;
			}
		}
	}
	
	if ($current =~ /\S/) {
		push @namespace, $current;
	}
	
	return \@namespace;
}

sub AppendMemberToClass($$) {
	my $classNode = shift;
	my $memberNode = shift;

	# Appending visibility for parent node and child nodes
	my @nodes = ($memberNode, @{ ExtractAddnode($memberNode) });

	foreach my $node (@nodes) {
		if (IsKind($node, MethodKind) && getCppKindData($node, 'PureVirtual')) {
			setCppKindData($classNode, "abstract", 1);
		}

		my $H_modifiers = getCppKindData($node, 'H_modifiers');

		my $visibility = "private"; # by default for classes
		if (IsKind($classNode, StructKind)) {
			$visibility = "public"; # by default for structs
		}
		if (defined $H_modifiers->{'public'}) {
			$visibility = "public";
		}
		elsif (defined $H_modifiers->{'protected'}) {
			$visibility = "protected";
		}

		setCppKindData($node, "visibility", $visibility);

		Append($classNode, $node);
	}
}


sub parseClassContext($$) {
	my $kind = shift;
	my $kindName = shift;

		my $classNode = Node($kind, createEmptyStringRef());
print "--> $kindName found...\n" if $DEBUG;
		sendContextEvent(CTX_CLASS);
		#Lib::ParseUtil::setArtifactUpdateState(0);

		# memorise this positin in case we need to re-parse later ...
		my $idx_StructOrClass = Lib::ParseUtil::get_idx_statement();

		#trash 'class' keyword
		my $keyword = ${getNextStatement()};
        
		my $statementLine = getStatementLine();
		SetLine($classNode, $statementLine);
		
#		setCppKindData($classNode, 'indentation', Lib::ParseUtil::getIndentation());
		
		my $proto = '';
        # class/struct without body is a declaration
		while ((defined nextStatement()) && (${nextStatement()} ne '{') && (${nextStatement()} ne ';') ) 
        {
			$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}
		
		#my ($name, $name2) = $proto =~ /^\s*(\w+)(?:\s+(\w+))?/sm;
		my $nameParts = parseFullname(\$proto);
		# the name is the last part of the fullname = namespace + name.
		my $name = pop @$nameParts;
		if (defined $name) {
			($name) = $name =~ /\A(\w+)/;
		}
		else {
			if ($keyword eq 'class') {
				# keyword is not required for structs ...
				Lib::Log::ERROR("class name not found in proto : $proto at line $statementLine");
			}
			$name = "?";
		}

		# Check special keywords behind class name
		# "sealed" is associated to "ref" modifier in C++/CLI
		if ($proto =~ /\G\s*sealed\b/gc) {
			Lib::ParseUtil::splitAndFocusNextStatementOnPos();
		}

		# TODO CHECK if name is followed by '*', '&' or second name => variable declaration.
		if ($proto =~ /\G\s*(\*|\&|\w+)/gc) {
		
		# CASE OF A STRUCT VARIABLE DECLARATION ...
		# if the proto is "struct <name1> <name2> ...." it's a variable declaration. 
		#if ( ($keyword eq 'struct') and (defined $name2) ) {
			
			# re-parse from "struct" keyword position ...
			Lib::ParseUtil::set_idx_statement($idx_StructOrClass);
			
			# leave class context ...
			sendContextEvent(CTX_LEAVE);
			
			return undef;
			#return Java::ParseCommon::Parse_VariableOrUnknow();
		}
		
		# CASE OF A STRUCT OR CLASS DEFINITION
		SetStatement($classNode, \$proto);
		SetName($classNode, $name);
		
		if (! defined nextStatement()) {
			Lib::Log::ERROR("missing openning '{' for $kindName $name");
		}
        elsif (${nextStatement()} eq ';')
        {
			# prototype class
            SetKind($classNode, ClassPrototypeKind);
            $proto = $keyword.$proto;
            sendContextEvent(CTX_LEAVE);
            return $classNode;
        }
		else 
        {
			# trashes the '{'
			getNextStatement();
		}
		
		#Lib::ParseUtil::setArtifactUpdateState(1);
		#my $artiKey = Lib::ParseUtil::newArtifact('class_'.$name, $statementLine);
		#setCppKindData($classNode, 'artifact_key', $artiKey);

		while (nextStatement() && (${nextStatement()} ne '}') ) {
			my $memberNode = Lib::ParseUtil::tryParse_OrUnknow(\@classContent);
			if (defined $memberNode) {
				
				# Visibility node ? 
				my $visibility;
				if (IsKind($memberNode, PrivateKind)) {
					$visibility = 'private';
				}
				elsif (IsKind($memberNode, ProtectedKind)) {
					$visibility = 'protected';
				}
				elsif (IsKind($memberNode, PublicKind)) {
					$visibility = 'public';
				}

				# remove visibility node level !
				# --> remove corresponding node and addnodes !
				if ($visibility) {
					for my $logicalMemberNode ( ($memberNode, @{getCppKindData($memberNode, 'addnode') || []})) {
						setCppKindData($logicalMemberNode, 'addnode', undef);

						for my $memberChild (@{GetChildren($logicalMemberNode)}) {
							# attach each visibility node child directly to the class and tag it with the visibility
							my $H_modifiers = getCppKindData($memberChild, 'H_modifiers');
							if (! defined $H_modifiers) {
								$H_modifiers = {};
								setCppKindData($memberChild, 'H_modifiers', $H_modifiers);
							}
							
							if (IsKind($logicalMemberNode, PrivateKind)) {
								$H_modifiers->{'private'} = 1;
							}
							elsif (IsKind($logicalMemberNode, ProtectedKind)) {
								$H_modifiers->{'protected'} = 1;
							}
							elsif (IsKind($logicalMemberNode, PublicKind)) {
								$H_modifiers->{'public'} = 1;
							}
							
							AppendMemberToClass($classNode, $memberChild);
						}
					}
				}
				else {
					AppendMemberToClass($classNode, $memberNode);
				}
			}
		}
		
		if (defined nextStatement()) {
			# trashes the '}'
			getNextStatement();
		}
		else {
			Lib::Log::ERROR("missing closing '}' for class $name");
		}

		#Lib::ParseUtil::endArtifact($artiKey);
		
		sendContextEvent(CTX_LEAVE);
		SetEndline($classNode, getStatementLine());
		
#		my $variables = getVariables($classNode);
#		setCppKindData($classNode, 'local_variables', $variables->[0]);
#		setCppKindData($classNode, 'local_constants', $variables->[1]);
		return $classNode;	
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

sub parseNamespace() 
{
	if (isNextNamespace()) {
        getNextStatement();  
        my $line = getStatementLine();
        my $stmt = '';
        my $next;
        my $node = Node(NamespaceKind, \$stmt);

        while ((defined ($next = nextStatement())) && ($$next ne "{") && ($$next ne ";")) 
        {
            $stmt .= $$next;
            getNextStatement();              
        }
        
        if ($$next eq '{')
        {
            if ($stmt =~ /\A\s*(\S+)/)
            {
                SetName($node, $1);
            }
            getNextStatement();              
            SetLine($node, getStatementLine());
            while ((defined ($next = nextStatement())) && ($$next ne "}")) 
            {
                my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);
                if (defined $subNode) {
                    Append($node, $subNode);
                }
            }
            if (defined $next and $$next eq '}')
            {
                getNextStatement();
                SetEndline($node ,getStatementLine());
                Lib::ParseUtil::purgeSemicolon();                
            }
            else
            {
                Lib::Log::ERROR("missing closing '}' for namespace at line $line"); 
            }
        }
        
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

sub isNextUnion() {
	if ( ${nextStatement()} eq 'union' ) {
		return 1;
	}  
	return 0;
}

sub parseStructOrUnion($) {
	my $kind = shift;
		
	my $kindName = ($kind eq StructKind ? 'struct' : 'union');
		
	my $structNode = parseClassContext($kind, $kindName);
		
	if (defined $structNode) {
		if ( (IsKind($structNode, StructKind)) ||
			 (IsKind($structNode, UnionKind)) ) {
			my $name = GetName($structNode);
			if ((! defined $name) || ($name eq '') || ($name eq '?')) {
				$name = "line_".GetLine($structNode);
			}
			my $typeName = "$kindName $name";
			
			# the struct syntax has been parsed. What is following is the name of the item (variable or typedef) declared with the struct...
			# parse as it were a variable
			my ($statement, $varNode) = Java::ParseCommon::Parse_Variable(\$typeName);
			if (defined $varNode) {
				# if there is several declarations, $varNode will contain the first one, and the property 'addnode' the others ...
				my $addnode = Java::ParseJava::getJavaKindData($varNode, 'addnode');
				unshift @$addnode, $varNode;
				Java::ParseJava::setJavaKindData($structNode, 'addnode', $addnode);
			}
			else {
				# no declaration following struct ...
			}
		}
		else {
			# not a StructKind : maybe a Cproto (forward declaration) ? 
		}

		Lib::ParseUtil::purgeSemicolon();
		
		return $structNode;
	}
	else {
		return undef;
	}
}

sub parseStruct() {
	if (isNextStruct()) {
		return parseStructOrUnion(StructKind);;
	}
	return undef;
}

sub parseUnion() {
	if (isNextUnion()) {
		return parseStructOrUnion(UnionKind);;
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

sub parseEnum() {
	if (isNextEnum()) {
		my $enumNode = Node(EnumKind, createEmptyStringRef());
print "--> ENUM found...\n" if $DEBUG;

		#trash 'enum' keyword
		getNextStatement();
		
		my $statementLine = getStatementLine();
		SetLine($enumNode, $statementLine);
		
#		setCppKindData($classNode, 'indentation', Lib::ParseUtil::getIndentation());
		
		my $proto = '';
		while ((defined nextStatement()) && (${nextStatement()} ne '{') ) {
			$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}

		my ($name) = $proto =~ /^\s*(\w+)/sm;
		
		SetStatement($enumNode, \$proto);
		SetName($enumNode, $name);
		
		if (! defined nextStatement()) {
			Lib::Log::ERROR("missing openning '{' for enum $name");
		}
		else {
			getNextStatement();
		}

		my $enumContent = "";
		while (nextStatement() && (${nextStatement()} ne '}')) {
			$enumContent .= ${getNextStatement()};
		}
		
		if (defined nextStatement()) {
			# trashes the '}'
			getNextStatement();
		}
		else {
			Lib::Log::ERROR("missing closing '}' for enum $name");
		}
	
		SetStatement($enumNode, \$enumContent);

		Lib::ParseUtil::purgeSemicolon();

		return $enumNode;
	}
	return undef;
}

##################################################################
#              TYPEDEF
##################################################################

sub isNextTypedef() {
	if ( ${nextStatement()} eq 'typedef' ) {
		return 1;
	}  
	return 0;
}

sub parseTypedef() {
	if (isNextTypedef()) {
		my $typedefNode = Node(TypedefKind, createEmptyStringRef());
		
		getNextStatement();
		SetLine($typedefNode, getStatementLine());
		
		# STRUCT case
		my $node;
		if ( ($node = parseStruct()) || ($node = parseUnion()) ) {
	
			if (IsKind($node, VariableKind)) {
				SetKind($node, TypedefKind);
			}

			$typedefNode = $node;

			# check for several declarations
			my $addnodes = Java::JavaNode::getJavaKindData($typedefNode, 'addnode') || [];
			for my $addnode (@{$addnodes} ) {
				if (IsKind($addnode, VariableKind)) {
					# each additional variable declaration is requalified with TypedefKind
					SetKind($addnode, TypedefKind);
				}
			}
			
		}
		# ANY case
		else {
			# parse as it would be a variable declaration
			my ($statement, $node) = Java::ParseCommon::Parse_Variable(undef, undef, TypedefKind);
			
			if (defined $node) {
				$typedefNode = $node;
			}
			
			SetStatement($typedefNode, $statement);
			
			Lib::ParseUtil::purgeSemicolon();
		}
		
		return $typedefNode;
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
	my $node = Node($kind, $proto);
	my $data = shift @$varData;
	SetName($node, $data->{'name'});
	setCppKindData($node, 'type', $data->{'type'});
	if (defined $data->{'default'}) {
		Append($node, Node(InitKind, \$data->{'default'}));
	}
	SetLine($node, $line);
		
	# get additional vars ...
	if (scalar @$varData) {
		my @add_vars = ();
		for	my $data (@$varData) {
			my $addVarNode = Node($kind, $proto);
			SetName($addVarNode, $data->{'name'});
			setCppKindData($addVarNode, 'type', $data->{'type'});
			if (defined $data->{'default'}) {
				Append($addVarNode, Node(InitKind, \$data->{'default'}));
			}
			SetLine($addVarNode, $line);
			push @add_vars, $addVarNode;
			# record info in the node : the var is declared inside same statement than previous.
			setCppKindData($addVarNode, 'multi_var_decl', 1);
		}
		setCppKindData($node, 'addnode', \@add_vars);
	}
	
	return $node;
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
		Lib::Log::ERROR("missing closing '}' for class");
	}
	elsif ($$stmt eq '(') {
		my ($name) = $proto =~ /(\w+)\s*(?:<.*>)?\s*$/sm;
		my $node = parse_Method($name, $line);
		return $node;
	}
	elsif ($$stmt eq ';') {
		print "FOUND attribute\n" if $DEBUG;
		# trashes the ";"
		getNextStatement();
		my $varData = Lib::ParseArguments::parseVariableDeclaration(\$proto, $line);
		
		my $node = createVariablesNodes($proto, $varData, AttributeKind, $line);

		return $node;
	}
	else {
		Lib::Log::ERROR("inconsistency encountered when parsing class member ()!!");
	}
	
	return undef;
}

##################################################################
#              ANONYMOUS BLOCK
##################################################################

# sub isNextBlock() {
	# if ( ${nextStatement()} eq '{' ) {
		# return 1;
	# }  
	# return 0;
# }

# sub parseBlock() {
	# if (isNextBlock()) {

		# getNextStatement();
		
		# sendContextEvent(CTX_ROUTINE);
		
		# my $blocNode = Node(BlockKind, createEmptyStringRef());
		# SetLine($blocNode, getNextStatementLine());

		# Lib::ParseUtil::parseStatementsBloc($blocNode, [\&isNextClosingBrace], \@routineContent, 0);

		# SetEndline($blocNode, getStatementLine());

		# sendContextEvent(CTX_LEAVE);

		# Lib::ParseUtil::purgeSemicolon();
	
		# return $blocNode;
	# }

	# return undef;
# }

##################################################################
#              ROOT
##################################################################
sub parseRoot() {
	my $root = Node(RootKind, \$NullString);

	SetName($root, 'root');

	#my $artiKey=Lib::ParseUtil::newArtifact('root');
	#setCppKindData($root, 'artifact_key', $artiKey);

	my $previousStatementIdx = Lib::ParseUtil::get_idx_statement();
	my $statementIdx = Lib::ParseUtil::get_idx_statement();
	while ( defined nextStatement() ) {
		my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);
		if (defined $subNode) {
			Append($root, $subNode);
			
			if (IsKind($subNode, UnknowKind)) {
				my $item = ${GetStatement($subNode)};
				$item =~ s/^\s*//m;
				Lib::Log::WARNING("Unknow node added to root : $item");
			}
		}
		
		# SECURITY against infinite loop, if the next Statement is not consumed ...
		$statementIdx = Lib::ParseUtil::get_idx_statement();
		# print STDERR "$previousStatementIdx / $statementIdx\n";
		if ($statementIdx == $previousStatementIdx) {
			my $item = ${getNextStatement()};
			$item =~ s/^\s*//m;
			Lib::Log::ERROR("Unexpected item:  $item , at line".getStatementLine());
		}
		
		$previousStatementIdx = $statementIdx;
	}

	#Lib::ParseUtil::endArtifact('root');

	#my $variables = getVariables($root);
	#setCppKindData($root, 'local_variables', $variables->[0]);
	#setCppKindData($root, 'local_constants', $variables->[1]);
	
	return $root;
}

#
# Split a JS buffer into statement separated by structural token
# 

sub splitCpp($) {
   my $r_view = shift;

   my  @statements = split /(\n|;|::|:|\(|\)|\{|\}|\@|\b(?:class|struct|union|typedef|namespace|if|else|else\s+if|while|for|do|switch|case|default|try|catch|break|continue|return|throw|import|operator)\b|(?:(?:$re_MODIFIERS\b\s*)+))/sm, $$r_view;   
  
  if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }
   return \@statements;
}


sub ParseCpp($) {
  my $r_view = shift;
  
  # remove attributes (all patterns [[ ... ]]
  $$r_view =~ s/\[\[.*?\]\]//g;
  
  my $r_statements = splitCpp($r_view);

	my ($package, $filename, $line, $subr)= caller(1);

  # only spaces and tabs will be considered as blanks in a statement (\n are considered as SEPARATORS)
  #Lib::ParseUtil::setBlankRegex('[ \t]');

  Lib::ParseUtil::InitParser($r_statements);
  # trigger for parse_Expression
  Lib::ParseUtil::register_Expression_TriggeringItems($Expression_TriggeringItems);
  
  Lib::ParseUtil::setEndingInstructionsCriteria(\&nextTokenIsEndingInstruction);
  
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

# description: CPP parse module Entry point.
sub Parse($$$$)
{
	my ($fichier, $vue, $couples, $options) = @_;
	my $status = 0;
    
    # prepro is the preprocessed view, while 'sansprepro' is just the whole code whom compilation directives have been removed.
	my $code = Vues::getView($vue, 'prepro', 'sansprepro');

	if (defined $options->{'--expandMacro'}) {
		Prepro::manageIncludes($vue);

		my $Macros = $vue->{'global_context'}->{'Macros'};
		my $lineShift = Prepro::expandMacros($Macros, $code);

		Prepro::removeSystemCompilerFeature($Macros, $code);
	}

	initMagicNumbers($vue);
	initMissingNewLineAfterControle($vue);

	$StringsView = $vue->{'HString'};

	Lib::ParseUtil::registerParseUnknow(\&parseUnknow);

   my $statements =  $vue->{'statements_with_blanks'} ;

	# launch first parsing pass : strutural parse.
	my ($CppNode, $Artifacts) = ParseCpp($code);

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

	# flatten the blocks
	Java::ParseCommon::flattenBlocks($CppNode);

	if (defined $options->{'--print-tree'}) {
		Lib::Node::Dump($CppNode, *STDERR, "ARCHI");
	}
	if (defined $options->{'--print-test-tree'}) {
		print STDERR ${Lib::Node::dumpTree($CppNode, "ARCHI")} ;
	}

	$vue->{'structured_code'} = $CppNode;
	$vue->{'artifact'} = $Artifacts;

	# # pre-compute some list of kinds :
	preComputeListOfKinds($CppNode, $vue, [MethodKind, FunctionKind, ClassKind, StructKind, ImportKind, ConditionKind, WhileKind, ForKind, EForKind, IfKind, CatchKind, TryKind, CaseKind, SwitchKind, AttributeKind, InterfaceKind, EnumKind, MethodPrototypeKind, ThrowKind]);

	getMagicNumbers(\$vue->{'sansprepro'});

	if (defined $options->{'--print-artifact'}) {
		for my $key ( keys %{$vue->{'artifact'}} ) {
			print "-------- $key -----------------------------------\n";
			print  $vue->{'artifact'}->{$key}."\n";
		}
	}
	return $status;
    
    # print STDERR 'FIN DU PARSE';
    
}

1;


