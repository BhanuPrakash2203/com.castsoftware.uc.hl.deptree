package CS::Prepro;

use strict;
use warnings;

use constant KIND => 0;
use constant START => 1;
use constant STOP1 => 2;
use constant STOP2 => 3;
use constant CHILDREN => 4;
use constant PARENT => 5;
use constant LINE => 6;
use constant LENGTH => 7;
use constant CONDITION => 8;
use constant DEFINE_LIST => 9;

my $LEVEL_PADDING_UNIT = "";

my $ROOT = ['root', 0, 0, -1, [], undef, 1];
my @CURRENT = ($ROOT);

my %DEFINED = ("true" => 1);
my $FALSE_ALTERNATIVE = {};
my $TRUE_ALTERNATIVE = {};

my @SECONDARY_CONDPATH = ();

my %OP_EVAL = (
	"||" => \&eval_OR,
	"&&" => \&eval_AND,
	"!" => \&eval_NOT,
	"ID" => \&eval_ID,
);

use constant COND_OP => 0;
use constant COND_PARAM => 1;

#-----------------------------------------------------------------------
#                       CODE PREPROCESSING
#-----------------------------------------------------------------------

my $SIMULATION_MODE = 0;
my $REMOVED_LOC = 0;

sub preprocessNodeContent($$);

sub preproTrue($$) {
	my $node = shift;
	my $preproCode = shift;
	
	my $startDirective = $node->[START];
	my $stopDirective = $node->[STOP1];
	
	# remove the directive
#print STDERR "-------- REMOVE --------------\n";
#print STDERR substr($$preproCode, $startDirective, ($stopDirective - $startDirective))."\n";
#print STDERR "------------------------------\n";
	if (! $SIMULATION_MODE ) {
		substr($$preproCode, $startDirective, ($stopDirective - $startDirective)) =~ s/[^\n]/ /g;
	}
	
	# The content of the alternative is not removed.
	# It can contain of course code, but compilation directive too ==> must be preprocessed  !!
	preprocessNodeContent($node, $preproCode);
}

sub preproFalse($$) {
	my $node = shift;
	my $preproCode = shift;
	
	my $startDirective = $node->[START];
	my $stopCode = $node->[STOP2];
	
	# remove the directive and the whole code it contain
#print STDERR "-------- REMOVE --------------\n";
#print STDERR substr($$preproCode, $startDirective, ($stopCode - $startDirective))."\n";
#print STDERR "------------------------------\n";
	if (! $SIMULATION_MODE ) {
		substr($$preproCode, $startDirective, ($stopCode - $startDirective)) =~ s/[^\n]/ /g;
	}
	
	$REMOVED_LOC += $node->[LENGTH];
print STDERR "REMOVING ".$node->[LENGTH]." lines of code\n";
}

my $LEVEL=0;
sub preprocessNodeContent($$) {
	my $node = shift;
	my $preproCode = shift;
#$LEVEL++;
#print STDERR ("  "x$LEVEL)."PREPROCESSING content of line $node->[LINE] ($node->[KIND])\n";
	my $children = $node->[CHILDREN];
	
	my $idx = 0;
	my $expectingTrue = 1;
	
	for my $child (@$children) {
#print STDERR ("  "x$LEVEL)."CHILD at line $child->[LINE] ($child->[KIND])\n";
		# end of a "if" sequence => expecting true for the next if sequence 
		if ($child->[KIND] eq "endif") {
			preproTrue($child, $preproCode);
			$expectingTrue = 1;
			next;
		}
		# do that while true alternative of a "if" chain is not encountered
		elsif ($expectingTrue) {
			# while expecting true alternative, else statement is always true !
			if ($child->[KIND] eq "else") {
				preproTrue($child, $preproCode);
			}
			# True only if the expression is true
			else {
				my $cond = getCondition($child, $preproCode);
				my $nodeCond = parseCondition(\$cond, {});
				
				my $eval = 0;
				if (defined $nodeCond) {
					$eval = evaluateNode($nodeCond); 
				}
				else {
					print STDERR "condition syntax error at line $child->[LINE], assume false\n";
				}
		
				if ($eval) {
					preproTrue($child, $preproCode);
					$expectingTrue = 0;
				}
				else {
					preproFalse($child, $preproCode);
				}
			}
		}
		# not expecting true alternative in an "if" sequence ...
		else {
			preproFalse($child, $preproCode);
		}
	}
#print STDERR "****** END PREPROCESSING content of line $node->[LINE] ******\n";
#$LEVEL--;
}

sub preprocesseCode($) {
	my $code = shift;
	
	my $prepro = $$code;
	
	preprocessNodeContent($ROOT, \$prepro);
	
	return \$prepro;
}

#-----------------------------------------------------------------------
#                       CONDITION EVALUATION
#-----------------------------------------------------------------------

sub evaluateNode($);

sub eval_OR($) {
	my $params = shift;
	
	for my $param (@$params) {
		if (evaluateNode($param)) {
			return 1;
		}
	}
	return 0;
}

sub eval_AND($) {
	my $params = shift;
	
	for my $param (@$params) {
		if (! evaluateNode($param)) {
			return 0;
		}
	}
	return 1;
}

sub eval_NOT($) {
	my $params = shift;
	
	my $param = $params->[0];
	
	if (evaluateNode($param)) {
		return 0;
	}
	else {
		return 1;
	}
}

sub eval_ID($) {
	my $params = shift;
	
	my $symb = $params->[0];

	my $val;

	if ($symb eq "false") {
		return 0;
	}
	elsif ( (defined ($val = $DEFINED{$symb})) && ($val == 1)) {
		return 1;
	}
	else {
		return 0;
	}
	
	return 0;
}

sub evaluateNode($) {
	my $node = shift;
	
	my $op = $node->[0];

if (! defined $op) {
	print STDERR "zarbi !!!\n";
}

	if (exists $OP_EVAL{$op}) {
		return $OP_EVAL{$op}->($node->[1]);
	}
	else {
		print STDERR "Unknow operator $op ! \n";
	}
	return 0;
}

#-----------------------------------------------------------------------
#                       CONDITION PARSING
#-----------------------------------------------------------------------
sub printConditionFlat($);
sub printConditionFlat($) {
	my $node = shift;
	
	
	if ($node->[0] eq "ID") {
		print STDERR "$node->[1]->[0] ";
	}
	else {
		print STDERR "($node->[0] ";
		for my $param (@{$node->[1]}) {
			printConditionFlat($param);
		}
		print STDERR ")";
	}
}

sub parseCondition($$);

sub parseBinary($$$$) {
	my $op = shift;
	my $leftValue = shift;
	my $expression = shift;
	my $defineList = shift;
	
	my $rightValue = parseCondition($expression, $defineList);
	
	return [$op, [$leftValue, $rightValue]];
}

sub parseUnary($$$) {
	my $op = shift;
	my $expression = shift;
	my $defineList = shift;
	
	my $rightValue;
	
	if ($$expression =~ /\G\s*(\w+)/gc) {
		$rightValue = ["ID", [$1]];
		$defineList->{$1} = 1;
	}
	else {
		$rightValue = parseCondition($expression, $defineList);
	}
	
	return [$op, [$rightValue]];
}

sub parseParenthese($$) {
	my $expression = shift;
	my $defineList = shift;
	return parseCondition($expression, $defineList);
}

sub parseCondition($$) {
	my $expression = shift;
	my $defineList = shift || {};
	
	my $leftValue;
	while ($$expression =~ /\G\s*(?:(\(|\)|(\w+)|!|[<>=&|]+)|([^\(!\w<>=&|\)]+))\s*/gc) {
		if (defined $3) {
			print STDERR "ERROR : unknow pattern inside directive condition : '$3' in '$$expression' at line\n";
			return undef;
		}
		else {
			if ( $1 eq "(") {
				$leftValue = parseParenthese($expression, $defineList)
			}
			elsif ($1 eq ")") {
				return $leftValue;
			}
			elsif ($1 eq "!") {
				$leftValue = parseUnary($1, $expression, $defineList);
			}
			elsif (defined $2) {
				$leftValue = ["ID", [$2]];
				$defineList->{$2} = 1;
			}
			else {
				if (! defined $leftValue) {
					print STDERR "ERROR : ununderstood left value for operator $1 in $expression\n";
					$leftValue = ["ID", ["undef"]];
				}
				$leftValue = parseBinary($1, $leftValue, $expression, $defineList);
			}
		}
	}
	
	return $leftValue
}

sub getCondition($$) {
	my $node = shift;
	my $code = shift;
	
	my $condition = substr($$code, $node->[START], $node->[STOP1]-$node->[START]);
	$condition =~ s/\s*#(\w+)\s*//;
	$condition =~ s/\s*$//m;
	return $condition;
}

sub makeTrueCondition($;$);
sub makeFalseCondition($;$);

sub tryAlternative($$);
sub tryAlternative($$) {
	my $define = shift;
	my $value = shift;
	
	my $ret = 0;
	
	my $H_tab = $TRUE_ALTERNATIVE;
	
	if ($value == 1) {
		# Want to set the define to 1, but already set to 0 : so search a replacement to 0 (false)
		$H_tab = $FALSE_ALTERNATIVE;
	}
	
	for my $alt (@{$H_tab->{$define}}) {
		my $altName = $alt->[0];
		my $altValue = $alt->[1];
		
		# is the alternative already defined ? 
		my $alt_defined_value = $DEFINED{$altName};
		if (! defined $alt_defined_value) {
			# not already defined.
			# 1 - set alternative is possible
#print STDERR "  SET $altName to $altValue as an alternative to $define\n";
#			$DEFINED{$altName} = $altValue;
			setDefine($altName, $altValue);
			
			# 2 - set define
#print STDERR "  RE-SET $define to $value\n";
#			$DEFINED{$define} = $value;
			redefine($define, $value);
			$ret = 1;
			last;
		}
		
		elsif ($alt_defined_value == $altValue) {
			# great : alternative already defined to the wanted value !!!
			
			# set define
#print STDERR "  RE-SET $define to $value\n";
#			$DEFINED{$define} = $value;
			redefine($define, $value);
			$ret = 1;
			last;
		}
		else {
			# alternative already defined to the opposite value we want.
			# No more an alternative
			$alt = undef;
			last;
		}
	}
	
	@{$H_tab->{$define}} = grep defined, @{$H_tab->{$define}};
	
	return $ret;
}

sub addAlternatives($$$) {
	#my $H_Alt = shift;
	my $condNode = shift;
	my $value = shift;
	my $alternatives = shift;
	
	my $valueDefine = $value;
	if ($condNode->[COND_OP] eq '!') {
		if ($condNode->[COND_PARAM]->[0]->[COND_OP] eq 'ID') {
			$condNode = $condNode->[COND_PARAM]->[0];
			$valueDefine = ($value?0:1);
		}
	}
	# name of the symbol
	my $define = $condNode->[COND_PARAM]->[0];
	
	my $H_Alt;
	
	if ($valueDefine == 1) {
		$H_Alt = $TRUE_ALTERNATIVE;
	}
	else {
		$H_Alt = $FALSE_ALTERNATIVE;
	}
	
	if (exists $H_Alt->{$define}) {
		# cannot add alternatives from several conditions, this would be conflicting
		# for example :
		# 	(toto||titi) --> titi alternative to toto
		# but if we encounter later :
		#   (toto || tutu) --> tutu alternative to toto ... but ...
		return 0;
	}
	
	for my $alternat (@$alternatives) {
	
		my $value_of_alternat = $value;
		if ($alternat->[0] eq "!") {
			$value_of_alternat = 0;
			$alternat = $alternat->[1]->[0];
		}
	
		next if ($alternat->[0] ne "ID");
	
print STDERR "Add $alternat->[1]->[0]=$value_of_alternat as an alternative to $define=$valueDefine\n";
	
		# $alternate is a condNode : [ <op>, [ <params> ] ]
		# $alternate->[1]->[0] is the name of the define 
		push @{$H_Alt->{$define}}, [$alternat->[1]->[0], $value_of_alternat];
	}
}


sub setDefine($$) {
	my $ident = shift;
	my $value = shift;
	
	if (! exists $DEFINED{$ident}) {
print STDERR "  SET $ident to $value\n";
		$DEFINED{$ident} = $value;
	}
	elsif ($DEFINED{$ident} == $value) {
print STDERR "  $ident already set to $value\n";
	}
}

sub redefine($$) {
	my $ident = shift;
	my $value = shift;
	
print STDERR "  RE-SET $ident to $value\n";
	$DEFINED{$ident} = $value;
	
	# remove all alternative to the forced define
	delete $FALSE_ALTERNATIVE->{$ident};
	delete $TRUE_ALTERNATIVE->{$ident};
}

# take a condition node that is a "!" or a "ID" applied to a define symbol
#       [ID, [<symbol>]] or [ !, [ID, [<symbol>]]]
# take the value to assign to the symbol
# take a flag indicating if this symbol definition can be redefined later or not.
# 
# 1 - check if the symbol is already defined. If yes, 
#      - if same value, nothing to do.
#      - if different value, check if there is an alternative : if an alternative can be found, re-set the symbol to the new value.
#
# 2 - If the flag allowAlternative is false, all alternatives attched to this symbol are removed.
sub setDefineValue($$$) {
	my $condNode = shift;
	my $value = shift;
	my $allowAlternative = shift || 0;
	
	my $current_val = $DEFINED{$condNode->[1]->[0]};
	
	# get identifier name ...
	my $define = $condNode->[COND_PARAM]->[0];
	# already defined to the opposite ?  ?
	if ((defined $current_val) && ($current_val == ($value?0:1))) {
		# Yes ! cannot define to wanted value, so try an alternative !
		if (tryAlternative($define, $value)) {
			return 1;
		}
		# cannot set to $value because already set to !$value
print STDERR " --> need to define $condNode->[1]->[0] to $value but already defined to ".($value?0:1)."\n";
		return 0;
	}
	elsif (defined $current_val)  {
		# already defined to the wanted value. Should just remove alternative, in case they are not compatible with new context.
		delete $FALSE_ALTERNATIVE->{$define};
		delete $TRUE_ALTERNATIVE->{$define};
		
	}
	else {
		setDefine($condNode->[COND_PARAM]->[0], $value);
		
		if (! $allowAlternative) {
			# remove all alternatives that could have been registered earlier
			delete $FALSE_ALTERNATIVE->{$define};
			delete $TRUE_ALTERNATIVE->{$define};
		}
	}
	return 1;
}


sub makeFalseCondition($;$) {
	my $condNode = shift;
	my $allowAlternative = shift || 0;
	my $val;
	
	# is the condition an identifier ?
	if ($condNode->[0] eq 'ID') {
		setDefineValue($condNode, 0, $allowAlternative);
	}
	elsif ($condNode->[COND_OP] eq '&&') {
		# Try to make first operand false ... 
		#if (makeFalseCondition($condNode->[COND_PARAM]->[0]), 1) {
			## OK. Accept this first solution by default, but register the alternate solution as another possibility.
			
			## if parameters are IDENTIFIERS, create alternative
			#my $AND_params = $condNode->[1];
			#if (($AND_params->[0]->[COND_OP] eq 'ID') && ($AND_params->[1]->[COND_OP] eq 'ID')) {
				## FIXME : there could be several alternatif if the && has more than two operand ...
				##addAlternatives($FALSE_ALTERNATIVE, $AND_params->[0]->[COND_PARAM]->[0], $AND_params->[1]);
				#addAlternatives($AND_params->[0], 0, $AND_params->[1]);
			#}
		#}
		#else {
			## or try second id any ...
			#return 0 if (! makeFalseCondition($condNode->[COND_PARAM]->[1]));
		#}
		
		# find the first operand that can be false
		my $falseOperand = undef;
		my @alternatives = ();
		
		# search false operand in "ID" operand
		# consider $operand that is either [ID, [<symbol>]] or [ !, [ID, [<symbol>]]]
		for my $operand (@{$condNode->[COND_PARAM]}) {
			
			if (! defined $falseOperand) {
				# Do the following until true operand is found ..
				if ($operand->[COND_OP] eq 'ID') {
					# make symbol true with 
					if (makeFalseCondition($operand, 1)) {
						$falseOperand = $operand;
					}
				}
				elsif (($operand->[COND_OP] eq '!') && ($operand->[COND_PARAM]->[0]->[COND_OP] eq 'ID')) {
					if (makeTrueCondition($operand->[COND_PARAM]->[0], 1)) {
						$falseOperand = $operand;
					}
				}
				else {
					push @alternatives, $operand;
				}
			}
			else {
				push @alternatives, $operand;
			}
		}
		
		# search false operand in non-"ID" operand not found in "ID"
		# Note : consider no alternative to compound operands !
		if (! defined $falseOperand) {
			for my $operand (@{$condNode->[COND_PARAM]}) {
				if (($operand->[COND_OP] ne 'ID') && (makeFalseCondition($operand, 1)) ) {
					$falseOperand = $operand;
				}
			}
		}
		
		if (! defined $falseOperand) {
			# fail to find a true operand !!
			return 0;
		}
		elsif (scalar @alternatives) {
			# true operand found ... record alternatives if any ...
			#addAlternatives($TRUE_ALTERNATIVE, $trueOperand->[COND_PARAM]->[0], \@alternatives);
			addAlternatives($falseOperand, 0, \@alternatives);
		}
		
		
	}
	elsif ($condNode->[0] eq '||') {
		# want both operands to be false
		return 0 if (! makeFalseCondition($condNode->[1]->[0]));
		return 0 if (! makeFalseCondition($condNode->[1]->[1]));
	}
	elsif ($condNode->[0] eq '!') {
		# want first operand to be true
		return 0 if (! makeTrueCondition($condNode->[1]->[0]));
	}
	return 1;
}

sub makeTrueCondition($;$) {
	my $condNode = shift;
	my $allowAlternative = shift || 0;
	my $val;
	
	# is the condition an identifier ?
	if ($condNode->[0] eq 'ID') {
		return 0 if (!setDefineValue($condNode, 1, $allowAlternative));
	}
	elsif ($condNode->[0] eq '&&') {
		# want both operand to be true
		return 0 if (! makeTrueCondition($condNode->[1]->[0]));
		return 0 if (! makeTrueCondition($condNode->[1]->[1]));
		
	}
	elsif ($condNode->[0] eq '||') {
		# find the first operand that can be true
		my $trueOperand = undef;
		my @alternatives = ();
		
		# search true operand in "ID" operand
		# consider $operand that is either [ID, [<symbol>]] or [ !, [ID, [<symbol>]]]
		for my $operand (@{$condNode->[COND_PARAM]}) {
			
			if (! defined $trueOperand) {
				# Do the following until true operand is found ..
				if ($operand->[COND_OP] eq 'ID') {
					# make symbol true with 
					if (makeTrueCondition($operand, 1)) {
						$trueOperand = $operand;
					}
				}
				elsif (($operand->[COND_OP] eq '!') && ($operand->[COND_PARAM]->[0]->[COND_OP] eq 'ID')) {
					if (makeFalseCondition($operand->[COND_PARAM]->[0], 1)) {
						$trueOperand = $operand;
					}
				}
				else {
					push @alternatives, $operand;
				}
			}
			else {
				push @alternatives, $operand;
			}
		}
		
		# search true operand in non-"ID" operand not found in "ID"
		# Note : consider no alternative to compound operands !
		if (! defined $trueOperand) {
			for my $operand (@{$condNode->[COND_PARAM]}) {
				if (($operand->[COND_OP] ne 'ID') && (makeTrueCondition($operand, 1)) ) {
					$trueOperand = $operand;
				}
			}
		}
		
		if (! defined $trueOperand) {
			# fail to find a true operand !!
			return 0;
		}
		elsif (scalar @alternatives) {
			# true operand found ... record alternatives if any ...
			#addAlternatives($TRUE_ALTERNATIVE, $trueOperand->[COND_PARAM]->[0], \@alternatives);
			addAlternatives($trueOperand, 1, \@alternatives);
		}
	}
	elsif ($condNode->[0] eq '!') {
		# want first operand to be true
		return 0 if (! makeFalseCondition($condNode->[1]->[0]));
	}
	return 1;
}

sub tryMakeTrueCondition($) {
	my $condNode = shift;
	my %SAVE = %DEFINED;
	if (! makeTrueCondition($condNode)) {
		# does not work, restore ...
		%DEFINED = %SAVE;
	}
}

#-----------------------------------------------------------------------
#                       CODE PARSING
#-----------------------------------------------------------------------

sub printTree($$);
sub printTree($$) {
	my $node = shift;
	my $level = shift;
	
	print STDERR (" " x ($level*4)) . "$node->[KIND].($node->[LINE]) [$node->[START] - $node->[STOP1] - $node->[STOP2]]\n";
	for my $child (@{$node->[CHILDREN]}) {
		printTree($child, $level+1);
	}
}

sub incCurrentNodeLOC() {
	$CURRENT[-1]->[LENGTH]++;
}

sub addNode($$$$$$) {
	my $kind = shift;
	my $begin = shift;
	my $end = shift;
	my $line = shift;
	my $condition = shift;
	my $defineList = shift;
	
	# by default, parent is current node level !
	my $node = [$kind, $begin, $end, $end, [], $CURRENT[-1], $line, 0, $condition, $defineList];
	
	if (($kind eq "if")) {
		
		# index of end level
		$CURRENT[-1]->[STOP2] = $begin;
		
		# add to current level
		push @{$CURRENT[-1]->[CHILDREN]}, $node;
		
		# create new level
		push @CURRENT, $node;
	}
	elsif (($kind eq "elif") || ($kind eq "else")) {
		
		# index of end level
		$CURRENT[-1]->[STOP2] = $begin;
		
		if ($CURRENT[-1]->[KIND] ne "root") {
			# add to previous level
			push @{$CURRENT[-1]->[PARENT]->[CHILDREN]}, $node;
			$node->[PARENT] = $CURRENT[-1]->[PARENT];
		}
		else {
			print STDERR "[Prepro::check] ERROR : #$kind encountered in root level !\n";
		}
		
		# create new level
		pop @CURRENT;
		push @CURRENT, $node;
	}
	elsif ($kind eq "endif") {
		
		# index of end level
		$CURRENT[-1]->[STOP2] = $begin;
		
		if ($CURRENT[-1]->[KIND] ne "root") {
			# add to previous level
			push @{$CURRENT[-1]->[PARENT]->[CHILDREN]}, $node;
			$node->[PARENT] = $CURRENT[-1]->[PARENT];
			
			# restore previous level
			pop @CURRENT;
			#$CURRENT = $CURRENT->[PARENT];
		}
		else {
			print STDERR "[Prepro::check] ERROR : #endif encountered in root level !\n";
		}
	}
	else {
		# add to current level
		push @{$CURRENT[-1]->[CHILDREN]}, $node;
	}
}

sub checkOpenCloseConsistency($$$$$$$) {
	my $code = shift;
	my $context = shift;
	my $beginIndex = shift;
	my $endIndex = shift;
	my $beginLine = shift;
	my $endLine = shift;
	my $level = shift;
	
	my $str = substr $$code, $beginIndex, ($endIndex-$beginIndex);
	my $OpeningAcco = () = $str =~ /(\{)/g;
	my $ClosingAcco = () = $str =~ /(\})/g;
	
my $levelPadding = $LEVEL_PADDING_UNIT x $level;
my $padding = " "x(10 - length $context->{'name'});
my $localDelta = $OpeningAcco - $ClosingAcco;

$context->{'{'} += $OpeningAcco;
$context->{'}'} += $ClosingAcco;

#if ($localDelta) {
#print STDERR "${levelPadding}$context->{'name'}$padding [$beginLine-$endLine] OPEN = $OpeningAcco, CLOSE = $ClosingAcco local delta = $localDelta => TOTAL DELTA = ".($context->{'{'}-$context->{'}'}+$context->{'+{-}'})."\n";
#}



}

sub checkNode($$$);

sub checkNode($$$) {
	my $node = shift;
	my $code = shift;
	my $level = shift;
	
	# +{-} is update of accolade delta
	my $context = {'{' => 0, '}' => 0, '+{-}' => 0};
	$context->{'{'} = 0;
	$context->{'}'} = 0;
	$context->{'name'} = $node->[KIND]."_".$node->[LINE];
	
	my $children = $node->[CHILDREN];
	
	my $begin = $node->[STOP1];
	my $end = $node->[STOP2];
	
	my $beginLine = $node->[LINE]+1;
	my $endLine = "??";
	
	if (scalar @{$children}) {
		$end = $children->[0]->[START];
		$endLine = $children->[0]->[LINE]-1;
	}
	
	checkOpenCloseConsistency($code, $context, $begin, $end, $beginLine, $endLine, $level);
	
	# check inside nested conditional
	if (scalar @{$children}) {
		my $idx = 0;
		
		# while encountering #if
		while ((defined $children->[$idx]) && ($children->[$idx]->[KIND] eq "if")) {
			
			# CHECK ALL ALTERNATIVES
			#
			# check #if -> #elif -> #else -> #endif
			my $childAccoDelta = undef;
			my $childAccoInheritedDelta;
			my $cumulatedDelta = 0;
			my @alternatives = ();
			while (($children->[$idx]->[KIND] ne "endif") && (defined $children->[$idx+1])) {
				
				push @alternatives, $children->[$idx];
				
				my $childContext = checkNode($children->[$idx], $code, $level+1);
				
#if ( $childContext->{'+{-}'} != 0 ) {
#print STDERR "WARNING : child has inherited delta different from zero !!\n";
#}
				
				# check consistency between alternatives
				if (defined $childAccoDelta) {
					if ($childAccoDelta != $childContext->{'{-}'} + $childContext->{'+{-}'}) {
						print STDERR "[Prepro] ERROR : alternative have not the same accolade impact for conditional branch at line $children->[$idx]->[LINE]!!!!\n";
					}
				}
				else {
					$childAccoDelta = $childContext->{'{-}'} + $childContext->{'+{-}'};
				}
				
				$cumulatedDelta += $childAccoDelta;
				
				#if ($childAccoDelta && ($children->[$idx]->[KIND] eq "if")) {
				#	print STDERR "--> EXPRESSION to deal : ".getCondition($children->[$idx], $code)."\n";
				#}
				
				$idx++;
			}
			
			if (($cumulatedDelta > 1) || ($cumulatedDelta < -1)) {
				my $condition = getCondition($alternatives[0], $code);
				print STDERR "--> EXPRESSION to deal : ".getCondition($alternatives[0], $code)."\n";
				my $node = parseCondition(\$condition, {});
				print STDERR "----> FLAT = ";
				if (defined $node) {
					printConditionFlat($node);
				}
				print STDERR "\n";
			}
			
			# add inherited delta of the alternative
			$context->{'+{-}'} += $childAccoDelta;
			
			# print impact of the #if ... #else ... #endif
# if child delta is not null ...
#if ($childAccoDelta) {			
#			my $intrinsicDelta = $context->{'{'}-$context->{'}'};
#			my $TOTAL_DELTA = $intrinsicDelta + $context->{'+{-}'};
#			my $padding = $LEVEL_PADDING_UNIT x $level;
#			print STDERR "${padding}update $context->{'name'} : intrinsic delta = $intrinsicDelta, inherited delta = $context->{'+{-}'}, TOTAL DELTA = $TOTAL_DELTA\n";
#}
			
			# back to the node ... check another part.
			if ($children->[$idx]->[KIND] eq "endif") {
				$begin = $children->[$idx]->[STOP1];
				
				$beginLine = $children->[$idx]->[LINE]+1;
				$endLine = "??";
				
				if (defined $children->[$idx+1]) {
					# end of bloc is the beginning of the next subbloc
					$end = $children->[$idx+1]->[START];
					$endLine = $children->[$idx+1]->[LINE]-1;
				}
				else {
					# end of bloc is the end of the node
					$end = $node->[STOP2];
				}
				
				checkOpenCloseConsistency($code, $context, $begin, $end, $beginLine, $endLine, $level);
				#my $intrinsicDelta = $context->{'{'}-$context->{'}'};
				#my $DELTA = $intrinsicDelta + $context->{'+{-}'};
				#my $padding = $LEVEL_PADDING_UNIT x $level;
				#print STDERR "${padding}update $context->{'name'} : intrinsic delta = $intrinsicDelta, update delta = $context->{'+{-}'}, TOTAL DELTA = $DELTA\n";
				$idx++;
			}
		}
		
		# end of alternatives
		if (defined $children->[$idx]) {
			print STDERR "[Prepro] ERROR unexpected #".$children->[$idx]->[KIND]." at line ".$children->[$idx]->[LINE]."\n";
		}
	}
	
	my $intrinsicDeltaAcco = $context->{'{'} - $context->{'}'};
	my $inheritedDeltaAcco = $context->{'+{-}'};
	$context->{'{-}'} = $intrinsicDeltaAcco;
	
	if (($intrinsicDeltaAcco + $inheritedDeltaAcco) != 0) {
		#print STDERR "$node->[KIND] at line $node->[LINE] contains ".$context->{'{'}." { versus ".$context->{'}'}." } !!!!\n";
		print STDERR "$node->[KIND] at line $node->[LINE] has accolade inconsistency between alternatives (delta = $intrinsicDeltaAcco+$inheritedDeltaAcco = ".($intrinsicDeltaAcco+$inheritedDeltaAcco).")\n"; 
	}
	return $context;
}

sub maxLength($;$);
sub maxLength($;$) {
	my $node = shift;
	my $level = shift || 0;
	
	my $max = $node->[LENGTH];
	
	my $maxMaxChild = 0;
	my $neededConditions = [$node->[CONDITION]];
	my $maxLOC_ConditionalPath = [];
	
#print STDERR ("   "x$level)."$node->[KIND] $node->[CONDITION] ($node->[LENGTH]) at line $node->[LINE]\n";
	
	# keep the inverted condition of previous node.
	# So, in case we encounter a "else", we know it is associated to this inverted condition.
	my $invertedPreviousCondition;
	
	my @T_ElsifChainList = ();
	my $rT_CurrentElsifChain = [];
	my $winnerElsifChain = 0;
	my $elsifChain_idx = 0;
	
	for my $child (@{$node->[CHILDREN]}) {
		
		
		# #endif contain nothing but ends "elsif chain"...
		if ($child->[KIND] eq "endif") {
			push @T_ElsifChainList, $rT_CurrentElsifChain;
			$rT_CurrentElsifChain = [];
			$elsifChain_idx++;
			next;
		}
		
		if ($child->[KIND] eq "else") {
			# condition of else is the inverse of condition of previous "if" or "elsif"
			$child->[CONDITION] = $invertedPreviousCondition;
		}
		
		# get the Conditional path that provide the more lines of code
		my ($nbLOC, $conditionalPath) = maxLength($child, $level+1);
		
		push @$rT_CurrentElsifChain, [$nbLOC, $conditionalPath];
		
		if ($nbLOC > $maxMaxChild) {
			$maxMaxChild = $nbLOC;
			$maxLOC_ConditionalPath = $conditionalPath;
			
			#memorize the index of the "elsif chain"
			$winnerElsifChain = $elsifChain_idx;
		}
		
		$invertedPreviousCondition = "!($child->[CONDITION])";
	}
	
	# built the optimal conditional of the node ...
	push @$neededConditions, @$maxLOC_ConditionalPath;
	
	# remove all conditional path of the elsif chain that wins !
	# (indeed, in an "elsif chain", if an alternative is true all others are false !)
	$T_ElsifChainList[$winnerElsifChain] = undef;
	
	# Add remaining elsif chain as secondary path ...
	# (all alternatives of an "elsif chain" are possible ...
	for my $elsifChain (@T_ElsifChainList) {
		for my $condPath (@$elsifChain) {
			push @SECONDARY_CONDPATH, $condPath;
		}
	}
	
#print STDERR ("   "x$level)."  --> MAX=".($max + $maxMaxChild)."\n";
	return ($max + $maxMaxChild, $neededConditions);
}

sub analyze($) {
	my $code = shift;
	
	# init DATA
	$ROOT = ['root', 0, 0, length($$code), [], undef, 1, 0, "", {}];
	%DEFINED = ("true" => 1);
	@CURRENT = ($ROOT);
	
	my $line = 1;

	while ($$code =~ /(\n)|([^\n]*#(\w+)[^\n]*)|([^\n]*)/g) {
		if (defined $1) {
			$line++;
		}
		else {
			my $begin = $-[2];
			my $end = $+[2];
			
			if (defined $3) {
			if (($3 eq 'if') || ($3 eq 'else') || ($3 eq 'elif') || ($3 eq 'endif')) {
				#addNode($3, $begin, $end, $line);
			
			
				my $nodeTmp = [$3, $begin, $end];
				my $condition = getCondition($nodeTmp, $code);
				my $defineList = {};
				
				addNode($3, $begin, $end, $line, $condition, $defineList);
				
				if ($condition ne "") {
					print STDERR "--> CONDITION : ".getCondition($nodeTmp, $code)."\n";
					my $nodeCond = parseCondition(\$condition, $defineList);
					print STDERR "----> FLAT = ";
					if (defined $nodeCond) {
						printConditionFlat($nodeCond);
					}
					print STDERR ", EVAL : ".evaluateNode($nodeCond); 
					print STDERR "\n";
				}
			}
			}
			else {
				# it's a line of code.
				if ($4 =~ /\S/) {
					incCurrentNodeLOC();
				}
			}
		}
	}
	
#printTree($ROOT, 0);
	
	if ($CURRENT[-1]->[KIND] ne "root") {
		print STDERR "[Prepro::check] ERROR : not finishing at root level !\n";
	}
	
	checkNode($ROOT, $code, 0);
}

sub preprocesse($) {
	my $views = shift;
	
	my $code = \$views->{'code'};
	
	analyze($code);
	
	#consolideLOC($ROOT);
	
	my ($max, $conditions) = maxLength($ROOT);
	
	if (scalar @$conditions > 1) {
print STDERR "-------------- MANAGE OPTIMAL PATH ----------------\n";
		print "LOC = $max, with CONDITIONS = ".(join("/", @$conditions))."\n";
	
		for my $cond (@$conditions) {
			my $condNode = parseCondition(\$cond, {});
		
			next if (! defined $condNode);
print STDERR "*** MAKE ( $cond ) TRUE\n";
			makeTrueCondition($condNode);
		}
	
		# sort on decreasing LOC
		@SECONDARY_CONDPATH = reverse sort {$a->[0] <=> $b->[0]} @SECONDARY_CONDPATH;
	
		# Manage secondary path:
print STDERR "-------------- MANAGE SECONDARY PATHS ----------------\n";
		for my $condPath (@SECONDARY_CONDPATH) {
print STDERR "SECONDARY CONDITIONAL PATH : LOC = $condPath->[0], PATH = ".join("/", @{$condPath->[1]})."\n";
			for my $pathElement (@{$condPath->[1]}) {
				my $condNode = parseCondition(\$pathElement, {});
				makeTrueCondition($condNode);
			}
		}
	
		#findOptimalDefineValues($ROOT, $code);

print STDERR "-------------- PREPROCESSING ----------------\n";	
print STDERR "PREPROCESS with: ".join(", ", keys %DEFINED)."\n";
	}
	
	my $prepro = preprocesseCode($code);
	
	$$prepro =~ s/^[ \t]*#\w+[^\n]*//mg;
	
	# FIXME :
	# 	1 - should check accolade/parentheses consistency and take decision if any ...
	#  	2 - preprocess view mix/code ? 

	$views->{'prepro'} = $$prepro;
}


1;
