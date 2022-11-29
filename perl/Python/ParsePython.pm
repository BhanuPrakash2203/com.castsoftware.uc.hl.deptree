package Python::ParsePython;
# les modules importes
use strict;
use warnings;

use Erreurs;

use CountUtil;

use Lib::Node; # qw( Leaf Node Append );
use Lib::NodeUtil ;
use Lib::NodeUtil qw( SetName SetStatement SetLine GetLine SetEndline GetEndline); 
use Lib::ParseUtil;
use Python::CountVariable;

use Python::PythonNode;
use CountUtil;

my $DEBUG = 1;

my @rootContent = ( 
			\&parseSimple_Stmt,
			\&parseCompound_Stmt,
);

my @StmtContent = (\&parseSimple_Stmt, \&parseCompound_Stmt);

my @Simple_StmtContent = ();

my @Compound_StmtContent = (
			\&parseFunction,
			\&parseIf,
			\&parseWhile,
			\&parseFor,
			\&parseTry,
			\&parseWith,
			\&parseClass,
			\&parseDecoration,
			\&parseAsync,
			\&parseBreak,
			\&parseContinue,
			\&parseReturn,
			\&parseImport,
			\&parseFrom,
			\&parseRaise,
			\&parseYield,
			\&parsePass,
);

my @AsyncContent = (\&parseFunction, \&parseFor, \&parseWith);

my $NullString = '';

my $StringsView = undef;

########################## CONTEXT ###################

use constant MULTILINE_BLOC => 0;
use constant LINE_BLOC => 1;

my @context = ({'indent_mode' => MULTILINE_BLOC, 'indent' => ''});

sub initContext() {
	@context = ({'indent_mode' => MULTILINE_BLOC, 'indent' => ''});
}

sub popContext() {
	if (scalar @context) {
		pop @context;
	}
	else {
		print "PARSE ERROR : context underflow !\n";
	}
}

sub sendContextEvent($;$) {
	my $event = shift;
	my $data = shift;

	if ($event eq 'new indent') {
		push @context, {'indent_mode' => MULTILINE_BLOC, 'indent' => $data};
	}
	elsif ($event eq "same line") {
		if ($context[-1]->{'indent_mode'} != LINE_BLOC) {
			push @context, {'indent_mode' => LINE_BLOC, 'indent' => $context[-1]->{'indent'}};
		}
	}
	elsif ($event eq "\n") {
		if ($context[-1]->{'indent_mode'} == LINE_BLOC) {
			#pop @context;
			popContext();
		}
	}
	elsif ($event eq "leave indent") {
		#pop @context;
		popContext();
	}
}

sub getContext() {
	if (scalar @context) {
		return $context[-1];
	}
	else {
		print "PARSE ERROR: empty context !";
		return undef;
	}
}

sub parseParenthesis($) {
	my $open = shift;
	my $close;
	my $reg;
	
	my $parenthLine = getStatementLine();
	
	if ($open eq "{") {
		$close = "}";
		$reg = qr/([\{\}])/;
	}
	elsif ($open eq "[") {
		$close = "]";
		$reg = qr/([\[\]])/;
	}
	else {
		$open = "(";
		$close = ")";
		$reg = qr/([()])/;
	}

	# get the openning
	my $statement = ${getNextStatement()};
	my $opened = 1;
	
	while ($opened) {
		if (defined nextStatement()) {
			my $next = ${nextStatement()};
			my @items = grep {$_ ne ''} split /$reg/, $next;
			my $nb_used=0;
			for my $item (@items) {
				$nb_used++;
				if ($item eq $open) { $opened++};
				if ($item eq $close) { $opened--};
				
				$statement .= $item;
				
				if (! $opened) {
					last;
				}
			}
			
			if ($nb_used < scalar @items) {
				# closing has been found and there are remaining statement parts ...
				# so insert them in current position in the statement list.
				#splice @items, 0, $nb;
				#Lib::ParseUtil::insertStatements(undef, \@items);
				
				# closing has been found and there are remaining statement after it ...
				# So replace the statement with the corresponding split ...
				Lib::ParseUtil::replaceCurrentStatementWithList(\@items);
				# ... and trash the items used.
				for (my $i=0; $i<$nb_used; $i++) {
					getNextStatement();
				}
			}
			else {
				# trash the statement that has been used.
				getNextStatement();
			}
		}
		else {
			print "PARSE ERROR : missing \"$close\", openned at line $parenthLine\n";
			last;
		}
	}
	return $statement;
}



sub purgeLineReturn() {
	while ((defined nextStatement()) && (${nextStatement()} eq "\n")) {
		# trash all "\n" statements (because they do not follow an instruction)
		getNextStatement();
		sendContextEvent("\n");
	}
}

sub getExpressionStatement() {
	my $stmt;
	my $statement = '';
	
	while ((defined ($stmt = nextStatement())) && ($$stmt ne "\n") && ($$stmt ne ";")) {
		$statement .= ${Lib::ParseUtil::getSkippedBlanks()};

		if ($$stmt eq "(") {
			$statement .= parseParenthesis('(');
		}
		elsif ($$stmt eq "[") {
			$statement .= parseParenthesis('[');
		}
		elsif ($$stmt eq "{") {
			$statement .= parseParenthesis('{');
		}
		else { 
			$statement .= ${getNextStatement()};
		}
	}
	
	if (defined $stmt) {
		# purge the last item identified in the loop ...
		$stmt = getNextStatement();

		# check the last item :
		if ($$stmt eq ";") {
			# same line separator
			sendContextEvent("same line");
		}
		elsif ($$stmt eq "\n") {
			sendContextEvent("\n");
		}

		# purge all lines returns to focus on the next statement
		purgeLineReturn();
	}
	
	return \$statement;
}

# test cases :
# - statement followed by \n
# - statement followed by :
# - statement followed by \\\n
# - statement with multiline (), [] or {}
sub parseUnknow() {
	my $node = Node(UnknowKind, createEmptyStringRef());
	SetLine($node, getStatementLine());

	my $statement = getExpressionStatement();
	
	SetStatement($node, $statement);

	return $node;
}

##################### INDENTATION ############

#-----------------------------------------------------------------------------------
# Check the indentation given in parameter against the current indentation context.
#-----------------------------------------------------------------------------------
sub isSameIndentation($) {
	my $indent = shift;
	
	my $context = getContext();

	if ($context->{'indent_mode'} == MULTILINE_BLOC) {
		if ($context->{'indent'} eq $indent) {
			return 1;
		}
		else {
			return 0;
		}
	}
	elsif ($context->{'indent_mode'} == LINE_BLOC) {
		# In same line context, all indentation are OK (indentation make sense only from the begining of the line, not after a ";")
		return 1;
	}
	return 1;
}

#-----------------------------------------------------------------------------------
# Check if the next instruction indentation is compliant with the current indentation context.
# The aim is to say if the next instruction belongs to the same instruction bloc than the previous one.
#-----------------------------------------------------------------------------------
sub isNextIndentationDifferent() {
	my $indent = Lib::ParseUtil::getNextIndentation();
	
	if (!defined $indent) {
		return 1;
	}

	if (isSameIndentation($indent) != 1) {
		return 1;
	}
	return 0;
}

sub isEndLineBloc() {
	if (getContext()->{'indent_mode'} != LINE_BLOC) {
		return 1;
	}
	return 0;
}

# Compare the indentation given in parameter to the current indentation and return,
#   -1 : negative indentation
#    0 : same indentation
#    1 : positive indentation
sub compareIndentation($) {
	my $indent = shift;
	
	if (isSameIndentation($indent)) {
		return 0;
	}
	else {
		my $context = getContext();
		my $currentIndent=$context->{'indent'};
		if ((defined $currentIndent) && ($indent =~ /^$currentIndent/)) {
			# positive indentation
			return 1;
		}
		else {
			# negative indentation
			return -1;
		}
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
my $integer = $Python::CountVariable::integer;
my $decimal  = $Python::CountVariable::decimal;
my $real = $Python::CountVariable::real;

sub getVariables($) {
	my $artifactNode = shift;
	
	# get the arguments list.
	my $args = getPythonKindData($artifactNode, 'arguments');
	
	my %varList = ();
	my %constList = ();
	my @unks = GetNodesByKindList_StopAtBlockingNode($artifactNode, [UnknowKind], [ClassKind, FunctionKind, MethodKind]);
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

my %peer = ('(' => ')', '{' => '}', '[' => '\]');

sub getUntilPeer($$) {
	my $stmt = shift;
	my $open = shift;
	my $close = $peer{$open};
	if (!defined $close) {
		print "[ParsePython] ERROR : no closing peer for $open !!!";
		return "";
	}
	
	my $openned = 1;
	my $expr = "";
	
	while ($$stmt =~ /\G([^$open$close]*)([$open$close])/sg) {
		$expr .= $1.$2;
		if ($2 eq $open) {
			$openned++;
		}
		else {
			$openned--;
			if (! $openned) {
				last;
			}
		}
	}
	return $expr;
}

sub getDefaultValue($) {
	my $stmt = shift;
	my $default = "";
	#my $lastPos = pos($$stmt);
	while ($$stmt =~ /\G([^,()\[\{]*)(.)/sg) {
		$default .= $1;
		if (($2 eq '(') || ($2 eq '{') || ($2 eq '[')) {
			$default .= $2;
			$default .= getUntilPeer($stmt, $2);
			if (! defined pos($$stmt)) {
				# end of function proto has been encountered before the end of the default value expression.
				return $default;
			}
		}
		else {
			# a character ',' or ')' has been encountered, this is the end of the default value expression.
			pos($$stmt)--;
			return $default;
		}
		#$lastPos = pos($$stmt);
	}
	# after the while has ended whithout matching regexpr, the pos is set to undef by the perl regexp motor.
	# so me have to restaure the last valid value in order to pursue matching later.
	#pos($$stmt) = $lastPos;
	return $default;
}

sub getArguments($) {
	my $artifactNode = shift;
	my %argList = ();
	
	my $stmt = GetStatement($artifactNode);
	my $line = 0;
	# stop after the first "(" or the last "\n" before the first non blank!
	$$stmt =~ /\A[^(]*\(([ \t]*\n)?/sg;
	if (defined $1) {
		# new line encountered, count them ...
		$line += () = $1 =~ /\n/g;
	}
	my $indent = $1;
	my $name = $2;
	my $argLine = $line;
	my $default = undef;
	while ($$stmt =~ /\G(?:(\s*)(\w+)|(\s*=\s*)|(\s*(,|\))([ \t]*\n)?))/sg) {
		# parse argument name + indentation
		if (defined $2) {
			$indent = $1;
			$name = $2;
			
			$line += () = $indent =~ /\n/g;
			$indent =~ s/.*\n//sg;
			$argLine = $line;
			$default = undef;
#print "ARGUMENT : $name, indent = >$indent<, line = $argLine\n";
		}
		# parse default value
		elsif (defined $3) {
			$line += () = $3 =~ /\n/g;
			$default = getDefaultValue($stmt);
			$line += () = $default =~ /\n/g;
			# remove trailing blanks
			$default =~ s/\s*$//m;
#print "-->default value = $default\n";
			if (! defined pos($$stmt)) {
				print STDERR "[ParsePython] Syntax error in argument default value parsing : $default\n";
				$argList{$name} = [$argLine, $indent, $default];
				last;
			}
		}
		# next argument or 
		else {
			if (defined $name) {
				$argList{$name} = [$argLine, $indent, $default];
			}
			if ($5 eq ",") {
				$line += () = $4 =~ /\n/g;
			}
			else {
				last;
			}
		}
	}
	
	return \%argList;
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
	
	SetStatement($node, getExpressionStatement());
	
	return $node;
}

##################################################################
#              PASS
##################################################################

sub isNextPass() {
	if ( ${nextStatement()} eq 'pass' ) {
		return 1;
	}  
	return 0;
}

sub parsePass() {
	if (isNextPass()) {
		return ParseGeneric(PassKind);
	}
	return undef;
}

##################################################################
#              YIELD
##################################################################

sub isNextYield() {
	if ( ${nextStatement()} eq 'yield' ) {
		return 1;
	}  
	return 0;
}

sub parseYield() {
	if (isNextYield()) {
		return ParseGeneric(YieldKind);
	}
	return undef;
}


##################################################################
#              RAISE
##################################################################

sub isNextRaise() {
	if ( ${nextStatement()} eq 'raise' ) {
		return 1;
	}  
	return 0;
}

sub parseRaise() {
	if (isNextRaise()) {
		return ParseGeneric(RaiseKind);
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
#              FROM
##################################################################

sub isNextFrom() {
	if ( ${nextStatement()} eq 'from' ) {
		return 1;
	}  
	return 0;
}

sub parseFrom() {
	if (isNextFrom()) {
		return ParseGeneric(FromKind);
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
#              ASYNC
##################################################################
sub isNextAsync() {
	if ( ${nextStatement()} eq 'async' ) {
	return 1;
	}  
	return 0;
}

sub parseAsync() {
	if (isNextAsync()) {
		my $asyncNode = Node(AsyncKind, createEmptyStringRef());
		my $proto = '';
		
		# consumes the "async"
		getNextStatement();
		
		SetLine($asyncNode, getStatementLine());
		
		my $stmtNode = Lib::ParseUtil::tryParse_OrUnknow(\@AsyncContent);

		setPythonKindData($stmtNode, 'async', 1);
		
		return $stmtNode;
	}
	return undef;
}

##################################################################
#              DECORATION
##################################################################
sub isNextDecoration() {
	if ( ${nextStatement()} eq '@' ) {
	return 1;
	}  
	return 0;
}

sub parseDecoration() {
	if (isNextDecoration()) {
		my $decorNode = Node(DecorationKind, createEmptyStringRef());
		my $proto = '';
		
		# consumes the "@"
		getNextStatement();
		
		SetLine($decorNode, getStatementLine());
		SetStatement($decorNode, \$proto);
		
		while ((defined nextStatement()) && (${nextStatement()} ne "\n") ) {
			$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}

		if ((defined nextStatement()) && (${nextStatement()} eq "\n") ) {
			# consumes the ":"
			getNextStatement();
		}
		return $decorNode;
	}
	return undef;
}

##################################################################
#              WITH
##################################################################
sub isNextWith() {
	if ( ${nextStatement()} eq 'with' ) {
		return 1;
	}  
	return 0;
}

sub parseWith() {
	if (isNextWith()) {
		return parseControlBloc(WithKind, 1);
	}
	return undef;
}
##################################################################
#              TRY
##################################################################

sub isNextExcept() {
		if ( ${nextStatement()} eq 'except' ) {
		return 1;
	}  
	return 0;
}

sub parseExcept() {
	if (isNextExcept()) {
		return parseControlBloc(ExceptKind, 1);
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
		return parseControlBloc(FinallyKind, 0);
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
		return parseControle(TryKind, [[\&isNextExcept, \&parseExcept, 'except'], [\&isNextElse, \&parseElse, 'else'], [\&isNextFinally, \&parseFinally, 'finally']], 0);
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
	
	# get all statement before the first ':' encountered that is not a ':' involved in an expression.
	my $stmt;
	while ((defined ($stmt = nextStatement())) && ($$stmt ne ":")) {
		$condition .= ${Lib::ParseUtil::getSkippedBlanks()};

		if ($$stmt eq "(") {
			$condition .= parseParenthesis('(');
		}
		elsif ($$stmt eq "[") {
			$condition .= parseParenthesis('[');
		}
		elsif ($$stmt eq "{") {
			$condition .= parseParenthesis('{');
		}
		else { 
			$condition .= ${getNextStatement()};
		}
	}
#print "CONDITION : $condition\n";

	if ((defined nextStatement()) && (${nextStatement()} eq ':') ) {
		# consumes the ":"
		getNextStatement();
		
		expectNewLineAfterControle();
	}
	else {
		print "[ParsePython::parseCondition] ERROR : missing ':' for statement at line ".getStatementLine()."\n"; 
	}
	
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
		return parseControlBloc(ElseKind, 0);
	}
	return undef;
}

sub isNextElif() {
	if ( ${nextStatement()} eq 'elif' ) {
		return 1;
	}  
	return 0;
}

sub parseElif() {
	if (isNextElif()) {
		return parseControlBloc(ElifKind, 1);
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
		return parseControle(IfKind, [[\&isNextElif, \&parseElif, 'elif'], [\&isNextElse, \&parseElse, 'else']]);
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
		return parseControle(WhileKind, [[\&isNextElse, \&parseElse, 'else']]);
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
		return parseControle(ForKind, [[\&isNextElse, \&parseElse, 'else']]);
	}
	return undef;
}

sub getEndBlocLine() {
	# return the (line-1) of the next instruction if any.
	# If the end of the program is encountered (no next instruction),
	# then the next statement line corresponds to the end of the program, and so the end of the bloc.
	if (defined nextStatement()) {
		return getNextStatementLine()-1;
	}
	return getNextStatementLine();
}

sub parseControlBloc($;$) {
	my $kind = shift;
	my $parseCond = shift;
	
	if (!defined $parseCond) {
		# by default, parse a condition
		$parseCond = 1;
	}
		
	my $blocNode = Node($kind, createEmptyStringRef());
	#trash the bloc introducing keyword
	getNextStatement();
	SetLine($blocNode, getStatementLine());
	setPythonKindData($blocNode, 'indentation', Lib::ParseUtil::getIndentation());

	if ($parseCond) {
		#### PARSE A CONDITION ...
		my $condNode = parseCondition();
		if (defined $condNode) {
			Append($blocNode, $condNode);
		}
		else {
			# no cond node means no more statement... useless to pursue
			SetEndline($blocNode, getEndBlocLine());
			return undef;
		}
	}
	else {
		#### ... OR consumes the ":"
		if ((defined nextStatement()) && (${nextStatement()} eq ':') ) {
			getNextStatement();

			expectNewLineAfterControle();
		}
		else {
			print "[ParsePython::parseControlBloc] ERROR : missing ':' at line ".getStatementLine()."\n"; 
		}
	}
	
	if (parse_suite($blocNode) == 0) {
		print "[ParsePython::parseControlBloc] WARNING : $kind structure at line ".GetLine($blocNode)." contains no instruction!!\n";
	}
	
	SetEndline($blocNode, getEndBlocLine());
	return $blocNode;
}

sub parseControle($$;$) {
		my $kind = shift;
		my $optStmtCbs = shift;
		my $parseCond = shift;
		
		if (!defined $parseCond) {
			# by default, parse a condition
			$parseCond = 1;
		}
		
		my $controlNode = Node($kind, createEmptyStringRef());

		#trash 'if, while, for ...' keyword
		getNextStatement();

		SetLine($controlNode, getStatementLine());

		if ( $parseCond ) {
			#### PARSE A CONDITION ...
			my $condNode = parseCondition();
			if (defined $condNode) {
				Append($controlNode, $condNode);
			}
			else {
				# no cond node means no more statement... useless to pursue
				return undef;
			}
		}
		else {
			#### ... OR consumes the ":"
			if ((defined nextStatement()) && (${nextStatement()} eq ':') ) {
				getNextStatement();
			}
			else {
				print "[ParsePython::parseControle] ERROR : missing ':' at line ".getStatementLine()."\n"; 
			}
		}

		my $thenNode = Node(ThenKind, createEmptyStringRef());
		Append($controlNode, $thenNode);
		SetLine($thenNode, getStatementLine());
		
		if (parse_suite($thenNode) == 0) {;
			print "[ParsePython::parseControle] WARNING : 'true' branch contains no instruction at line ".GetLine($thenNode)."!!\n";
		}

		# check for optional related statements
		while (defined nextStatement()) {
			
			# check the next optional statement
			my $nextOptCallbacks;
			for my $optCbs (@$optStmtCbs) {
				if ($optCbs->[0]->()) {
					$nextOptCallbacks = $optCbs;
					last;
				}
			}

			# If a valid optional statement has been found, then the corresponding parsing callback are not undefined.
			if (! defined $nextOptCallbacks) {
				# stop searching optional statement for this control !
				last;
			}
			else {
				my $indent = Lib::ParseUtil::getNextIndentation();
				my $indendChecking = compareIndentation($indent);
				# Check if the else indentation correspond to the current if indentation.
				# FIXME : message for negatitive indentation and parent not being an 'if' statement
				# NOTE : a not compliant indentation (blank convention not respected) will be considered as negative by compareIndentation().
				if ( $indendChecking >= 0) {
					# same indentation than previous (or greater, but not less).
					if ($indendChecking == 1 ) {
						my $controlName = $nextOptCallbacks->[2];
						if (! defined $controlName) {
							$controlName = 'control';
						}
						print "[ParsePython::parseIf] WARNING : positive indentation for '$controlName' at line ".getStatementLine()."!!\n";
					}
					# parse the optional node
					my $optionalNode = $nextOptCallbacks->[1]->();
					Append($controlNode, $optionalNode);
				}
				else {
					# optional node is not associated to the current control. So leave if parsing.
					last;
				}
			}
		}
		
		SetEndline($controlNode, getEndBlocLine());
		return $controlNode; 
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
		my $classNode = Node(ClassKind, createEmptyStringRef());

		Lib::ParseUtil::setArtifactUpdateState(0);

		#trash 'class' keyword
		getNextStatement();
		
		my $statementLine = getStatementLine();
		SetLine($classNode, $statementLine);
		
		setPythonKindData($classNode, 'indentation', Lib::ParseUtil::getIndentation());
		
		my $proto = '';
		while ((defined nextStatement()) && (${nextStatement()} ne ':') ) {
			$proto .= ${Lib::ParseUtil::getSkippedBlanks()}.${getNextStatement()};
		}
		
		# consumes the ":"
		if (defined nextStatement()) {
			getNextStatement();
		}
		my ($name) = $proto =~ /^\s*(\w+)/sm;
		
		SetStatement($classNode, \$proto);
		SetName($classNode, $name);
		my $lines_in_proto = () = $proto =~ /\n/g;
		setPythonKindData($classNode, 'lines_in_proto', $lines_in_proto);
		
		Lib::ParseUtil::setArtifactUpdateState(1);
		my $artiKey = Lib::ParseUtil::newArtifact('class_'.$name, $statementLine);
		setPythonKindData($classNode, 'artifact_key', $artiKey);
		
		if (parse_suite($classNode) == 0) {
			print "[ParsePython::parseClass] WARNING : class $name contains no instruction at ".GetLine($classNode)."!!\n";
		}

		Lib::ParseUtil::endArtifact($artiKey);

		my $variables = getVariables($classNode);
		setPythonKindData($classNode, 'local_variables', $variables->[0]);
		setPythonKindData($classNode, 'local_constants', $variables->[1]);
		return $classNode;
	}
	return undef;
}

##################################################################
#              FUNCTION
##################################################################


sub isNextFunction() {
	if ( ${nextStatement()} eq 'def' ) {
		return 1;
	}  
	return 0;
}

sub parseFunction() {
	if (isNextFunction()) {
		my $functionNode = Node(FunctionKind, createEmptyStringRef());

		# temporary desactive artifact updating: the prototype of the function should not appears in the encompassing (parent) artifact.
		# This to prevent some argument with default values (xxx = ) to be considered as  parent's variable while greping variable in parent's body.
		Lib::ParseUtil::setArtifactUpdateState(0);

		#trash 'function' keyword
		getNextStatement();

		my $statementLine = getStatementLine();
		SetLine($functionNode, $statementLine);
		setPythonKindData($functionNode, 'indentation', Lib::ParseUtil::getIndentation());

		my $proto = '';
		my $stmt;
		while ((defined ($stmt = nextStatement())) && ($$stmt ne ':') ) {
			$proto .= ${Lib::ParseUtil::getSkippedBlanks()};
			if ($$stmt eq '(') {
				$proto .= parseParenthesis('(');
			}
			else {
				$proto .= ${getNextStatement()};
			}
		}
		
		# consumes the ":"
		if (defined nextStatement()) {
			getNextStatement();
		}
		my ($name) = $proto =~ /^\s*(\w+)/sm;
		
		SetStatement($functionNode, \$proto);
		SetName($functionNode, $name);
		my $lines_in_proto = () = $proto =~ /\n/g;
		setPythonKindData($functionNode, 'lines_in_proto', $lines_in_proto);
		
		Lib::ParseUtil::setArtifactUpdateState(1);
		my $artiKey = Lib::ParseUtil::newArtifact('func_'.$name, $statementLine);
		setPythonKindData($functionNode, 'artifact_key', $artiKey);
		
		if (parse_suite($functionNode) == 0) {
			print "[ParsePython::parseFunction] WARNING : function $name contains no instruction at line ".GetLine($functionNode)."!!\n";
		}
		
		Lib::ParseUtil::endArtifact($artiKey);
		
		setPythonKindData($functionNode, 'arguments', getArguments($functionNode));
		
		my $variables = getVariables($functionNode);
		setPythonKindData($functionNode, 'local_variables', $variables->[0]);
		setPythonKindData($functionNode, 'local_constants', $variables->[1]);
		return $functionNode;
	}
	return undef;
}

##################################################################
#              STATEMENT
##################################################################

sub parseSimple_Stmt($) {
	return Lib::ParseUtil::tryParse(\@Simple_StmtContent);
}

sub parseCompound_Stmt($) {
	return Lib::ParseUtil::tryParse(\@Compound_StmtContent);
}

sub parseSeveralInstrOnSameline($) {
	my $parent = shift;
	
	################# WILL NOT WORK BECAUSE THE parseUnknow eat the "\n"
	if ((defined nextStatement()) && (${nextStatement()} ne "\n")) {
		my $node = Lib::ParseUtil::tryParseOrUnknow(\@Simple_StmtContent);
		Append($parent, $node);
	}
}

sub parse_suite($) {
	my $parent = shift;
	
	# suite: simple_stmt | NEWLINE INDENT stmt+ DEDENT
	if ((defined nextStatement()) && (${nextStatement()} eq "\n")) {
#		my $suiteLine = getStatementLine();
		# consumes all \n
		while ((defined nextStatement()) && (${nextStatement()} eq "\n")){
			sendContextEvent("\n");
			getNextStatement();
		}
#print "DEBUG : \@context = @context (".(scalar @context).")\n";
		my $indent = Lib::ParseUtil::getNextIndentation();
		# Check if the next indentation belongs to the current bloc.
		if ( (defined $indent) && (compareIndentation($indent) == 1)) {
			sendContextEvent('new indent', $indent);
			#parse statements with the same indentation.
			my $nbChildren = Lib::ParseUtil::parseStatementsBloc($parent, [\&isNextIndentationDifferent], \@StmtContent, 1, 0, 1); # keepClosing=1, noUnknowNode=0, dontWarnUnterminated = 0
			sendContextEvent('leave indent');
			if (!$nbChildren) {
				# should not occur, because if there is no instruction, then the compareIndentation should have returned -1 or 0
				print "[ParsePython::parse_suite] ERROR : no instruction in statement bloc\n";
			}
			SetEndline($parent, getEndBlocLine());
			return $nbChildren;
		}
# Useless because the parse_suite() will return 0 in the current situation. So it is the caller's responsibility to issue a message.
#		else {
#			print "[ParsePython::parse_suite] WARNING : empty bloc at line $suiteLine\n";
#		}
	}
	else {
		# the instruction is expected on the same line.
		sendContextEvent('same line');
		my $nbChildren = Lib::ParseUtil::parseStatementsBloc($parent, [\&isEndLineBloc], \@StmtContent, 1, 0, 1); # keepClosing=1, noUnknowNode=0, dontWarnUnterminated = 0
		if (! $nbChildren) {
			# should not occur ... should provide at lest an "unknow node"
			print "[ParsePython::parse_suite] ERROR : no instruction nor line return behin comma !!\n";
		}
		SetEndline($parent, getEndBlocLine());
		return $nbChildren;
	}
	
	return 0;
}

##################################################################
#              ROOT
##################################################################
sub parseRoot() {
	my $root = Node(RootKind, \$NullString);

	SetName($root, 'root');

	my $artiKey=Lib::ParseUtil::newArtifact('root');
	setPythonKindData($root, 'artifact_key', $artiKey);

	while ( defined nextStatement() ) {
		my $subNode = Lib::ParseUtil::tryParse_OrUnknow(\@rootContent);
		if (defined $subNode) {
			Append($root, $subNode);
		}
	}
	
	Lib::ParseUtil::endArtifact('root');

	my $variables = getVariables($root);
	setPythonKindData($root, 'local_variables', $variables->[0]);
	setPythonKindData($root, 'local_constants', $variables->[1]);
	return $root;
}

#
# Split a JS buffer into statement separated by structural token
# 

sub splitPython($) {
   my $r_view = shift;

   my  @statements = split /(\\\n|\n|:|;|\(|\{|\[|@|\b(?:class|def|if|else|elif|while|for|try|except|finally|with|async|lambda|break|continue|return|raise|yield|import|from|pass)\b)/sm, $$r_view;
   
   if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }
   return \@statements;
}


sub ParsePython($) {
  my $r_view = shift;
  
  my $r_statements = splitPython($r_view);

  # only spaces and tabs will be considered as blanks in a statement (\n are considered as SEPARATORS)
  Lib::ParseUtil::setBlankRegex('[ \t]');

  Lib::ParseUtil::InitParser($r_statements);
  
  # pass all beginning empty lines
  while (${nextStatement()} eq "\n") {
	getNextStatement();
  }
  #$ExpressionLevel = 0;
  initContext();
  
  # init to the indentation of the first instruction
  sendContextEvent("new indent", Lib::ParseUtil::getNextIndentation());

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

# description: Python parse module Entry point.
sub Parse($$$$)
{
	my ($fichier, $vue, $couples, $options) = @_;
	my $status = 0;

	initMagicNumbers($vue);
	initMissingNewLineAfterControle($vue);

	$StringsView = $vue->{'HString'};

	Lib::ParseUtil::registerParseUnknow(\&parseUnknow);

#    my $statements =  $vue->{'statements_with_blanks'} ;

	# launch first parsing pass : strutural parse.
	my ($PythonNode, $Artifacts) = ParsePython(\$vue->{'code'});

	# Set MethodKind type to functions are classes methods
	Lib::Node::Iterate ($PythonNode, 0, sub {
										my $node = shift;
										# For each class ...
										if (IsKind($node, ClassKind)) {
											for my $child (@{Lib::NodeUtil::GetChildren($node)}) {
												# ... for each function child ...
												if (IsKind($child, FunctionKind)) {
													# ... set to method !!
													SetKind($child, MethodKind);
												}
											}
										}
										return undef; # walk in the whole tree
									}, []);

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

	if (defined $options->{'--print-tree'}) {
		Lib::Node::Dump($PythonNode, *STDERR, "ARCHI") if ($DEBUG);
	}
	if (defined $options->{'--print-test-tree'}) {
		print STDERR ${Lib::Node::dumpTree($PythonNode, "ARCHI")} ;
	}

	$vue->{'structured_code'} = $PythonNode;
	$vue->{'artifact'} = $Artifacts;

	# pre-compute some list of kinds :
	preComputeListOfKinds($PythonNode, $vue, [FunctionKind, MethodKind, ClassKind, FromKind, ImportKind, ConditionKind, WhileKind, ForKind, IfKind]);

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


