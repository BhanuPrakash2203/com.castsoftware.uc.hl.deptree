package Kotlin::CountConditions;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;
use Lib::Node;
use Lib::CountUtils;
use Kotlin::KotlinNode;


my $UnconditionalCondition__mnemo = Ident::Alias_UnconditionalCondition();
my $MissingFinalElses__mnemo = Ident::Alias_MissingFinalElses();
my $SwitchLengthAverage__mnemo = Ident::Alias_SwitchLengthAverage();
my $MissingDefaults__mnemo = Ident::Alias_MissingDefaults();
my $SmallSwitchCase__mnemo = Ident::Alias_SmallSwitchCase();
my $SwitchNested__mnemo = Ident::Alias_SwitchNested();
my $CollapsibleIf__mnemo = Ident::Alias_CollapsibleIf();
my $ConditionComplexityAverage__mnemo = Ident::Alias_ConditionComplexityAverage();
my $CaseLengthIndicator__mnemo = Ident::Alias_CaseLengthIndicator();
my $BooleanPitfall__mnemo = Ident::Alias_BooleanPitfall();
my $MissingExpressionForm__mnemo = Ident::Alias_MissingExpressionForm();
my $LongElsif__mnemo = Ident::Alias_LongElsif();

my $nb_UnconditionalCondition = 0;
my $nb_MissingFinalElses = 0;
my $nb_SwitchLengthAverage = 0;
my $nb_MissingDefaults = 0;
my $nb_SmallSwitchCase = 0;
my $nb_SwitchNested = 0;
my $nb_CollapsibleIf = 0;
my $nb_ConditionComplexityAverage = 0;
my $nb_CaseLengthIndicator = 0;
my $nb_BooleanPitfall = 0;
my $nb_MissingExpressionForm = 0;
my $nb_LongElsif = 0;

# internal metrics
my $nb_CompoundConditions = 0;

my $THRESHOLD_COMPLEX = 4;
my $THRESHOLD_LONG_ELSIF = 2;

sub checkFinalElse($$$);
sub checkFinalElse($$$) {
	my $elseIf = shift;
	my $ifline = shift;
	my $nb_elseif = shift;
	
	if ($nb_elseif >= 3) {
		#Erreurs::VIOLATION("MISSING SWITCH", "'if ... else if' chain should rather be 'when' at line $ifline");
	}
	
	my $children = GetChildren($elseIf);
	my $else = $children->[2];
	if (defined $else) {
		if (IsKind($else, ElsifKind)) {
			checkFinalElse($else, $ifline, $nb_elseif+1 );
		}
		else {
			#print STDERR "MISSING_SWITCH : elsif chain lentgh is $nb_elseif at line $ifline\n";
			if ($nb_elseif >= $THRESHOLD_LONG_ELSIF) {
				$nb_LongElsif++;
				Erreurs::VIOLATION($LongElsif__mnemo, "Too long 'else if' chain : ".($nb_elseif+1)." options should be managed using 'when' at line $ifline.");
			}
		}
	}
	else {
		$nb_MissingFinalElses++;
		Erreurs::VIOLATION($MissingFinalElses__mnemo, "missing final else for if chain beginning at line at line $ifline");
		if ($nb_elseif >= $THRESHOLD_LONG_ELSIF) {
			$nb_LongElsif++;
			Erreurs::VIOLATION($LongElsif__mnemo, "Too long 'else if' chain : ".($nb_elseif+1)." options should be managed using 'when' at line $ifline.");
		}
	}
	
}
sub checkElsifChain($) {
	my $if = shift;
	my $children = GetChildren($if);
	my $else = $children->[2];
	if ((defined $else) && (IsKind($else, ElsifKind))) {
		checkFinalElse($else, GetLine($if), 1);
	}
}

sub checkComplexity($) {
  my $stmt = shift;
  
  # Calcul du nombre de && et de ||
  my $nb_ET = () = $$stmt =~ /\&\&/sg ;
  my $nb_OU = () = $$stmt =~ /\|\|/sg ;

  if ( ($nb_ET > 0) && ($nb_OU > 0) ) {
	$nb_ConditionComplexityAverage += $nb_ET + $nb_OU;
	$nb_CompoundConditions++;
  }
}

sub CountConditions($$$) 
{
	my ($file, $views, $compteurs) = @_ ;
    
	my $ret = 0;
	$nb_UnconditionalCondition = 0;
	$nb_ConditionComplexityAverage = 0;
	$nb_CompoundConditions = 0;

    my $KindsLists = $views->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $UnconditionalCondition__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ConditionComplexityAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $Conditions = $KindsLists->{&ConditionKind};
	
	for my $condition (@$Conditions) {
		my $cond = ${GetStatement($condition)};
#print "COND = $cond\n";
		my $kind = GetKind(GetParent($condition));
		if (($kind eq IfKind) || ($kind eq ElsifKind)) {
			# "if" condition
			if ($cond =~ /\(\s*(?:true|false)\s*\)/) {
				$nb_UnconditionalCondition++;
				Erreurs::VIOLATION($UnconditionalCondition__mnemo, "Unconditional condition at line ".(GetLine($condition)||"??"));
			}
		}

		checkComplexity(\$cond);
	}

	if ($nb_CompoundConditions) {
		$nb_ConditionComplexityAverage = int($nb_ConditionComplexityAverage/$nb_CompoundConditions);
	}
	
	Erreurs::VIOLATION($ConditionComplexityAverage__mnemo, "METRIC = Average complexity for compound conditions is $nb_ConditionComplexityAverage for $nb_CompoundConditions compound conditions");

    $ret |= Couples::counter_add($compteurs, $UnconditionalCondition__mnemo, $nb_UnconditionalCondition );
    $ret |= Couples::counter_add($compteurs, $ConditionComplexityAverage__mnemo, $nb_ConditionComplexityAverage );
    
    return $ret;
}

sub CountWhen($$$) 
{
	my ($file, $views, $compteurs) = @_ ;
    
	my $ret = 0;
	$nb_SwitchLengthAverage = 0;
	$nb_MissingDefaults = 0;
	$nb_SmallSwitchCase = 0;
	$nb_SwitchNested = 0;
	$nb_CaseLengthIndicator = 0;
	$nb_MissingExpressionForm = 0;

    my $KindsLists = $views->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $SwitchLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MissingDefaults__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $SmallSwitchCase__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $SwitchNested__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $CaseLengthIndicator__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_update($compteurs, $MissingExpressionForm__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $Whens = $KindsLists->{&WhenKind};
	
	my $nb_when = 0;
	my $nb_realWhen = 0;
	my $realWhenLengthAverage = 0;
	# When with a single case (that should rather be 'if') are counted as violation in the SmallSwitchCase rule. So, for real 'when', count only those having at least 2 case !!
	my $REAL_WHEN_THRESHOLD = 2;
	
	my @cases_LOC = ();
	
	for my $when (@$Whens) {
		my $line = GetLine($when);
		my $children = GetChildren($when);
		my $nb_case = 0;
		my $nb_default = 0;
		
		for my $case (@$children) {

			if (IsKind($case, CaseKind)) {
				$nb_case++;
				my $nb_LOC = Lib::NodeUtil::getArtifactLinesOfCode($case, $views);
		
				if (defined $nb_LOC) {
					push @cases_LOC, $nb_LOC;
				}
			}
			else {
				$nb_default++;
			}
		}

		#$nb_SwitchLengthAverage += scalar @$children;
		if (!$nb_default) {
			$nb_MissingDefaults++;
			Erreurs::VIOLATION($MissingDefaults__mnemo, "Missing default clause for 'when' at line $line.");
		}
		$nb_when++;
		if ($nb_case >= $REAL_WHEN_THRESHOLD) {
			$nb_realWhen++;
			$realWhenLengthAverage += $nb_case;
		}
		
		if ($nb_case == 1) {
			$nb_SmallSwitchCase++;
			Erreurs::VIOLATION($SmallSwitchCase__mnemo, "'when' should rather be 'if' statement at line $line.");
		}
		
		if (Lib::NodeUtil::IsContainingKind($when, WhenKind)) {
			$nb_SwitchNested++;
			Erreurs::VIOLATION($SwitchNested__mnemo, "Nested when at line $line.");
		}
		
		# check expression form
		my $parentKind = GetKind(GetParent($when));
		if (($parentKind ne UnknowKind) && ($parentKind ne FunctionCallKind)# &&
			#( defined Lib::Node::GetNextSibling($if)) 		# not the last instruction
			)   
		{
		
			my $children = GetChildren($when);
			my $refInstr;
			my $expressionFormImpossible = 0;
			
			for my $case (@$children) {
				my $caseChildren = GetChildren($case);
				
				next if (scalar @$caseChildren == 0);
				
				if (scalar @$caseChildren > 1) {
					$expressionFormImpossible = 1;
					last;
				}

				my $instr = getInstr($caseChildren->[0]); # get statement of first child
				if (! defined $instr) {
					$expressionFormImpossible = 1;
					last;
				}
				
				if (defined $refInstr) {
					if ($refInstr ne $instr) {
						$expressionFormImpossible = 1;
						last;
					}
				}
				else {
					$refInstr = $instr;
				}
			}
		
			if ( ! $expressionFormImpossible ) {
				# statement form encountered, while expecting expression form.
				$nb_MissingExpressionForm++;
				Erreurs::VIOLATION($MissingExpressionForm__mnemo, "Expression form expected for 'when' ($refInstr) at line ".(GetLine($when)||"??"));
			}
		}
	}
	
	# CASE LENGTH indicator
	my ($max, $average, $median) = Lib::CountUtils::getStatistic(\@cases_LOC);
	my $nb_CaseLengthIndicator = int($max + $average + $median);
	my $nb_casesUsed = scalar @cases_LOC;
	$average = int($average);
	$median = int($median);
	Erreurs::VIOLATION($CaseLengthIndicator__mnemo, "METRIC : 'case' lentgh indicator is $nb_CaseLengthIndicator (MAX=$max, AVERAGE=$average, MEDIAN=$median for a total of $nb_casesUsed cases used");
	
	# WHEN LENGTH average
	if ($nb_realWhen) {
		$realWhenLengthAverage /= $nb_realWhen;
		$nb_SwitchLengthAverage = int($realWhenLengthAverage);
		Erreurs::VIOLATION($SwitchLengthAverage__mnemo, "METRIC : 'when' length average is $nb_SwitchLengthAverage for a total of $nb_realWhen real when");
	}
	
	$ret |= Couples::counter_add($compteurs, $SwitchLengthAverage__mnemo, $nb_SwitchLengthAverage );
	$ret |= Couples::counter_add($compteurs, $MissingDefaults__mnemo, $nb_MissingDefaults );
	$ret |= Couples::counter_add($compteurs, $SmallSwitchCase__mnemo, $nb_SmallSwitchCase );
	$ret |= Couples::counter_add($compteurs, $SwitchNested__mnemo, $nb_SwitchNested );
	$ret |= Couples::counter_add($compteurs, $CaseLengthIndicator__mnemo, $nb_CaseLengthIndicator );
	$ret |= Couples::counter_update($compteurs, $MissingExpressionForm__mnemo, $nb_MissingExpressionForm );
    
    return $ret;
}

sub hasElse($) {
	my $if = shift;
	return (defined GetChildren($if)->[2]);
}

sub checkCollapsible($$);
sub checkCollapsible($$) {
	my $if_1 = shift;
	my $alreadyChecked = shift;
	
	my $children = GetChildren($if_1);
	
	my $thenChildren = GetChildren($children->[1]);
	if ((scalar @$thenChildren == 1) && (IsKind($thenChildren->[0], IfKind))) {
		# 'then' branch contains a single instruction that is a 'if'.
		my $if_2 = $thenChildren->[0];
		
		$alreadyChecked->{$if_1} = 1;
		$alreadyChecked->{$if_2} = 1;
		
		if (! hasElse($if_2)) {
			# Both if_1 is collapsible with if_2.
			return (1 + checkCollapsible($if_2, $alreadyChecked));
		}
	}
	return 0;
}

sub getInstr($) {
	my $node = shift;

	if (IsKind($node, ReturnKind)) {
		return "return";
	}
	else {
		if (${GetStatement($node)} =~ /\A\s*([\w\.]+\s*[=])/) {
			my $instr = $1;
			$instr =~ s/\s*//g;
			return $instr;
		}
	}
	return undef;
}

sub CountIf($$$) 
{
	my ($file, $views, $compteurs) = @_ ;
    
	my $ret = 0;
	$nb_MissingFinalElses = 0;
	$nb_CollapsibleIf = 0;
	$nb_MissingExpressionForm = 0;
	$nb_LongElsif = 0;
	

    my $KindsLists = $views->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $MissingFinalElses__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $CollapsibleIf__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MissingExpressionForm__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $LongElsif__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $Ifs = $KindsLists->{&IfKind};
	my %alreadyCollapsibleChecked = ();
	for my $if (@$Ifs) {
		checkElsifChain($if);
		
		if ((!hasElse($if)) && (!exists $alreadyCollapsibleChecked{$if})) {
			my $nb_collapsible = checkCollapsible($if, \%alreadyCollapsibleChecked) ;
			if ($nb_collapsible) {
				$nb_collapsible++;
				Erreurs::VIOLATION($CollapsibleIf__mnemo, "$nb_collapsible Collapsible 'if' at line ".GetLine($if));
				$nb_CollapsibleIf++;
			}
		}
		
		# check expression form
		my $parentKind = GetKind(GetParent($if));
		if (($parentKind ne UnknowKind) && ($parentKind ne FunctionCallKind)# &&
			#( defined Lib::Node::GetNextSibling($if)) 		# not the last instruction
			)   
		{
		
			my $then = GetChildren($if)->[1];
			my $else = GetChildren($if)->[2];
		
			my $thenStmt = GetChildren(GetChildren($if)->[1]);
			my $elseStmt = GetChildren(GetChildren($if)->[2]);
		
			if ((defined $thenStmt) && (defined $elseStmt) && (scalar @$thenStmt == 1) && (scalar @$elseStmt == 1)) {
				my $thenInstr = (scalar @$thenStmt > 0 ? getInstr($thenStmt->[0]) : undef);
				my $elseInstr = (scalar @$elseStmt > 0 ? getInstr($elseStmt->[0]) : undef);
				if ((defined $thenInstr) && (defined $elseInstr) && ($thenInstr eq $elseInstr)) {
					$nb_MissingExpressionForm++;
					Erreurs::VIOLATION($MissingExpressionForm__mnemo, "Expression form expected for 'if' ($thenInstr) at line ".(GetLine($if)||"??"));
				}
			}
		}
	}
	
	$ret |= Couples::counter_add($compteurs, $MissingFinalElses__mnemo, $nb_MissingFinalElses );
	$ret |= Couples::counter_add($compteurs, $CollapsibleIf__mnemo, $nb_CollapsibleIf );
	$ret |= Couples::counter_update($compteurs, $MissingExpressionForm__mnemo, $nb_MissingExpressionForm );
	$ret |= Couples::counter_update($compteurs, $LongElsif__mnemo, $nb_LongElsif );
    
    return $ret;
}

# pitfall si
# - ! appliqué à une expression comportant plusieurs operateurs, elle ne fait pas apparaitre plus d'operateur inversés (!..., !=, !is, ...) qu'il n'y envait avant.
#     appliqué à un operateur booleen dont toutes les opérandes sont inversables.
#     appliqué à un operateur de comparaison
# - une operande est inversable si :
#        - elle contient un operateur inversable.
#        - elle est déjà invesée avec un !
# - une operande n'est pas inversable si :
#        - elle ne contient pas d'operateur inversable
#        - elle ne forme pas avec son operande associée par un operateur un duo normal/inversé.

my $PRIORITY = {'||' => 1, 
				'&&' => 2, 
				'==' => 3, '!=='=> 3,
				'<'  => 4, '>' => 4, '<='  => 4, '>=' => 4,
				'in' => 5, '!in' => 5, 'is' => 5, '!is' => 5};
				
my $INVERTABLE = {
				'==' => 1, '!=='=> 1,
				'<'  => 1, '>' => 1, '<='  => 1, '>=' => 1,
				'in' => 1, '!in' => 1, 'is' => 1, '!is' => 1
};

use constant OP => 0;
use constant INVERSE => 1;
use constant LEFT => 2;
use constant RIGHT => 3;
use constant TEXT => 4;

sub printCond($$);
sub printCond($$) {
	my $cond = shift;
	my $level = shift;
	
	return if (!defined $cond);
	
	if (defined $cond->[OP]) {
		print "  "x$level;
		print "! " if ($cond->[INVERSE]);
		print $cond->[0]."\n";
	}
	else {
		if (defined $cond->[TEXT]) {
			print "  "x$level;
			print $cond->[TEXT]."\n";
		}
	}
	printCond($cond->[LEFT], $level+1);
	printCond($cond->[RIGHT], $level+1);
}

sub printCond1($);
sub printCond1($) {
	my $cond = shift;
	
	return if (!defined $cond);
	
	my $need_enclosing = defined $cond->[OP];
	
	print " ! " if ($cond->[INVERSE]);
	
	print "(" if $need_enclosing;
	printCond1($cond->[LEFT]);
	
	if (defined $cond->[OP]) {
		print $cond->[0];
	}
	else {
		if (defined $cond->[TEXT]) {
			my $text = $cond->[TEXT];
			$text =~ s/\n//g;
			$text =~ s/^\s*//gm;
			$text =~ s/\s*$//gm;
			print $text;
		}
	}
	
	printCond1($cond->[RIGHT]);
	print ")" if $need_enclosing;
}

sub cond2String($);
sub cond2String($) {
	my $cond = shift;
	my $s = "";
	
	return "" if (!defined $cond);
	
	my $need_enclosing = defined $cond->[OP];
	
	$s .= " !" if ($cond->[INVERSE]);
	
	$s .= "(" if $need_enclosing;
	$s .= cond2String($cond->[LEFT]);
	
	if (defined $cond->[OP]) {
		
		$s .= " ".$cond->[0]." ";
	}
	else {
		if (defined $cond->[TEXT]) {
			my $text = $cond->[TEXT];
			$text =~ s/\n//g;
			$text =~ s/^\s*//gm;
			$text =~ s/\s*$//gm;
			$s .= $text;
		}
	}
	
	$s .= cond2String($cond->[RIGHT]);
	$s .= ")" if $need_enclosing;
	
	return $s;
}


sub leaf($$) {
	my $stmt = shift;
	my $not_flag = shift;
	
	return [undef, $not_flag, undef, undef, $$stmt];
}

sub parseCondition($$$);
sub parseOperand($);
sub parseParenthesis($) {
	my $code = shift;
	
	my ($left, $op) = parseOperand($code);
	
	if (defined $op) {
		return parseCondition($code, $left, $op);
	}
	
	return $left;
}

sub parseCondition($$$) {
	my $code = shift;
	my $left = shift;
	my $op1 = shift;

	if ((!defined $left) && (! defined $op1)) {
		($left, $op1) = parseOperand($code);
	}

	if (defined $op1) {
		
		if ($op1 eq ')') {
			return $left;
		}
		
		my ($right, $op2) = parseOperand($code);
		if (! defined $op2){
			return [$op1, undef, $left, $right];
		}
		else {
			if ($PRIORITY->{$op1} > $PRIORITY->{$op2}) {
				return parseCondition($code, [$op1, undef, $left, $right], $op2);
			}
			else {
				return [$op1, undef, $left, parseCondition($code, $right, $op2)];
			}
		}
	}
	
	return $left; 
}

my $OPS = qr/&&|\|\||<|>|<=|>=|==|!==|\bin\b|\bis\b|!in\b|!is\b/;

sub parseOperand($) {
	my $code = shift;
	my $stmt = "";
	my $not_flag = 0;
	while ($$code =~ /\G(!!|($OPS)|&|\||\(|\)|!|i|=|[^&|()<>=!i]*)/gc) {
		if (defined $2) {
			return (leaf(\$stmt, $not_flag), $2);
		}
		elsif ($1 eq '(') {
			my $content = parseParenthesis($code);
			
			# check if le parentheses contain an operator
			if (defined $content->[OP]) {
				$content->[INVERSE] = $not_flag;
				# check if the closing parent is followed by an operator
				if ($$code =~ /\G\s*($OPS)/gc) {
					return ($content, $1);
				}
				elsif ($$code =~ /\G\s*(\)|\z)/gc) {
					# Robustness ... should not occur ...
					return ($content, undef);
				}
			}
			else {
				$stmt .= '('.$content->[TEXT].')';
			}
		}
		elsif ($1 eq ')') {
			return (leaf(\$stmt, $not_flag), undef);
		}
		elsif ($1 eq '!') {
			$not_flag = 1;
		}
		else {
			$stmt .= $1;
		}
	}
	return (leaf(\$stmt, $not_flag), undef);
}

sub invertCondition($);
sub invertCondition($) {
	my $cond = shift;
	my $nb_negation = 0;
	
	if (defined $cond->[OP]) {
		# operator
		if (($cond->[INVERSE]) || ($INVERTABLE->{$cond->[OP]})) {
			# the inversion is beneficial ...
#print " --> +1 for ".$cond->[OP]."\n";
			return 1;
		}
		else {
			$nb_negation += invertCondition($cond->[LEFT]);
			$nb_negation += invertCondition($cond->[RIGHT]);
			return $nb_negation;
		}
	}
	else {
		# leaf
		if ($cond->[INVERSE]) {
			# the inversion is beneficial ...
#print " --> +1 for ".$cond->[TEXT]."\n";
			return 1;
		}
		else {
			# should use an additional ! => not beneficial
#print " --> -1 for ".$cond->[TEXT]."\n";
			return -1;
		}
	}
	
	return $nb_negation;
}

sub checkPitfall($) {
	my $cond = shift;
	
	my $profit = invertCondition($cond);
	
	if ($profit >= 0) {
		$nb_BooleanPitfall++;
		Erreurs::VIOLATION($BooleanPitfall__mnemo, "removing negation should be beneficial (profit=$profit) for condition expression : !(".cond2String($cond).")");
	}
}

sub CountBadConditionNegation() {
	my ($file, $views, $compteurs) = @_ ;

	$nb_BooleanPitfall= 0;

	my $ret = 0;    
    my $code = \$views->{'code'};
    
    if ( ! defined $code )
	{
		$ret |= Couples::counter_add($compteurs, $BooleanPitfall__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
    while ($$code =~ /(?:(?:\bif|\bwhile)\s*\(|(?:\breturn|[^=]=))\s*!\s*\(/gc ) {
		my $cond = parseCondition($code, undef, undef);
		checkPitfall($cond);
	}

	$ret |= Couples::counter_add($compteurs, $BooleanPitfall__mnemo, $nb_BooleanPitfall );
		
	return $ret;
}

1;

