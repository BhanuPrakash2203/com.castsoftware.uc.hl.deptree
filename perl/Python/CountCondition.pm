package Python::CountCondition;

use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Python::PythonNode;
use Python::PythonConf;

my $ExplicitComparisonToSingleton__mnemo = Ident::Alias_ExplicitComparisonToSingleton();
my $DeprecatedOperator__mnemo = Ident::Alias_DeprecatedOperator();
my $InstanceOf__mnemo = Ident::Alias_InstanceOf();
my $BadIdenticalOperatorUse__mnemo = Ident::Alias_BadIdenticalOperatorUse();
my $InvertedLogic__mnemo = Ident::Alias_InvertedLogic();
my $RepetitionInComparison__mnemo = Ident::Alias_RepetitionInComparison();
my $ComplexConditions__mnemo = Ident::Alias_ComplexConditions();
my $MultilineConditions__mnemo = Ident::Alias_MultilineConditions();
my $Conditions__mnemo = Ident::Alias_Conditions();

my $nb_ExplicitComparisonToSingleton = 0;
my $nb_DeprecatedOperator = 0;
my $nb_InstanceOf = 0;
my $nb_BadIdenticalOperatorUse = 0;
my $nb_InvertedLogic = 0;
my $nb_RepetitionInComparison = 0;
my $nb_ComplexConditions = 0;
my $nb_MultilineConditions = 0;
my $nb_Conditions = 0;

my $nbOr = 0;
my $nbAnd = 0;

my $COMPARISON_OPERATORS = '(<=|>=|<>|>|<|==|!=|\b(?:not\s+in|in|is\s+not|is)\b)';

use constant NODE_CONDITION_TYPE => 0;
use constant NODE_OPERATOR => 1;
use constant NODE_MEMBERS_LIST => 2;

use constant LEFT_MEMBER => 0;
use constant RIGHT_MEMBER => 1;

my @EqualityConditions = ();
my @IdentityConditions = ();
my @NotConditions = ();
my @OrConditions = ();
my @AndConditions = ();


my @ELEMENTS = ();
my $IDX = 0;

sub nextElement() {
	return $ELEMENTS[$IDX];
}

sub getNextElement() {
	my $element = undef;
	if ($IDX < scalar @ELEMENTS) {
		$element = $ELEMENTS[$IDX];
		$IDX++;
		while (($IDX < scalar @ELEMENTS) && ($ELEMENTS[$IDX] =~/^\s*$/m)) {
			$IDX++;
		}
	}
#print "USING : $element\n";
	return $element;
}

sub init() {
	@EqualityConditions = ();
	@IdentityConditions = ();
	@NotConditions = ();
	@OrConditions = ();
	@AndConditions = ();
	
	# init
	$IDX = 0;
	while (($IDX < scalar @ELEMENTS) && ($ELEMENTS[$IDX] =~/^\s*$/m)) {
		$IDX++;
	}
}

sub printNode($$);
sub printNode($$) {
	my $node = shift;
	my $indent = shift;
	
	my $type = $node->[NODE_CONDITION_TYPE];
	my $ops  = $node->[NODE_OPERATOR];
	
	if (! defined $type) {
		print "++$indent<undef>\n";
		return;
	}
	
	print "++$indent<$type>";
	
	$indent .= "  ";
	if ($type eq "expr") {
		print "\n";
		print "++$indent$node->[1]\n";
	}
	elsif ($type eq "comp") {
		print " $node->[NODE_OPERATOR]->[0]\n";
		my $members = $node->[NODE_MEMBERS_LIST];
		for my $node (@$members) {
			printNode($node, $indent);
		}
	}
	elsif ($type eq "compList") {
		print " ".join(',', @$ops)."\n";
		my $members = $node->[NODE_MEMBERS_LIST];
		for my $node (@$members) {
			printNode($node, $indent);
		}
	}
	elsif ($type eq "not") {
		print "\n";
		printNode($node->[NODE_MEMBERS_LIST], $indent);
	}
	elsif ($type eq "logic") {
		print " $ops\n";
		my $condList = $node->[NODE_MEMBERS_LIST];
		for my $node (@$condList) {
			printNode($node, $indent);
		}
	}
}

sub parseCondition();
sub parseComparison();

sub parseExpression() {
#print ">> parseExpression();\n";
	my $expr = "";
	my $level = 0;
	my $next;
	while ( (defined ($next=nextElement())) && ($next !~ /^(?:&&|\|\||and|or|${COMPARISON_OPERATORS})$/m)) {
		if ($next eq '(') {
			$level++;
		}
		elsif ($next eq ')') {
			$level--;
			if ($level < 0) {
				last;
			}
		}
		$expr .= getNextElement();
	}
	my $node = ["expr", $expr];
#printNode($node, "");
	return $node;
}

sub parseComparison() {
#print ">> parseComparison();\n";
	my $expr = parseExpression();
	
	my @members = ($expr);
	my @ops = ();
	my $node = [undef, \@ops, \@members];
	my $next;
	while (($next=nextElement()) && (defined $next) && ($next =~ /^${COMPARISON_OPERATORS}$/m)) {
		push @ops, getNextElement();
		
		if (nextElement() eq '(') {
			getNextElement();
			my $comp = parseComparison();
			push @members, $comp;
			if (nextElement() eq ')') {
				getNextElement();
			}
			else {
				print "What's this !!? where's the matching end parenth !??!\n";
			}
		}
		else {
			$expr = parseExpression();
			push @members, $expr;
		}
	}
	if (scalar @ops) {
		if (scalar @ops == 1) {
			$node->[0] = "comp";
			if ($ops[0] =~ /[!=]=/) {
				# reference in the EQUALITY condition list ...
				push @EqualityConditions, $node;
			}
			elsif ($ops[0] =~ /\bis\b/) {
				# reference in the IDENTITY condition list ...
				push @IdentityConditions, $node;
			}
		}
		else {
			$node->[0] = "compList";
			Erreurs::VIOLATION("TBD", "Avoid chained comparison ...");
		}
		$node->[1] = \@ops;
	}
	else {
		# no comparison operators detectd => return the simple expression ...
		return $expr;
	}
	
	return $node;
}

sub parseCondition() {
#print ">> parseCondition();\n";
	my $next = nextElement();
	
	if (defined $next) {
		if (($next eq "not") || ($next eq '!')) {
			getNextElement();
			my $cond = parseCondition();
			my $node = ["not", $next, $cond];
			push @NotConditions, $node;
			return $node;;
		}
		elsif ($next eq '(') {
			getNextElement();
			my $cond = parseOr();
			if (nextElement() eq ')') {
				getNextElement();
			}
			else {
				print "What's this !!? where's the matching end parenth !??!\n";
			}
			return $cond;
		}
		else {
			return parseComparison();
		}
	}
	return undef;
}

sub parseAnd() {
#print ">> parseAnd();\n";
	my $cond = parseCondition();
	
	my @condList = ($cond);
	
	my $node = ["logic", "and", \@condList];
	my $next;
	while (($next=nextElement()) && (defined $next) && ($next =~ /^(and|&&)$/m)) {
		$nbAnd++;
		getNextElement();
		my $cond = parseCondition();
		push @condList, $cond;
	}

	if (scalar @condList == 1) {
		$node = $cond;
	}
	else {
		push @AndConditions, $node;
	}
#printNode($node, "");
	return $node;
}

sub parseOr();
sub parseOr() {
#print ">> parseOr();\n";
	my $cond = parseAnd();

	my @condList = ($cond);

	my $node = ["logic", "or", \@condList];
	my $next;
	while (($next=nextElement()) && (defined $next) && ($next =~ /^(or|\|\|)$/m)) {
		$nbOr++;
		getNextElement();
		my $cond = parseAnd();
		push @condList, $cond;
	}
	
	if (scalar @condList == 1) {
		$node = $cond;
	}
	else {
		push @OrConditions, $node;
	}
#printNode($node, "");
	return $node;
}

sub parse($) {
	my $condtext = shift;
#print "============= PARSING $condtext\n";
	@ELEMENTS = split /(\s+|!=|!|&&|\|\||\b(?:not\s+in|not|and|or|in|is\s+not|is)\b|\(|\)|<=|>=|<>|>|<|==)/, $condtext;
	
	init();
	
	my $condsTree = parseOr();

#printNode($condsTree, "");
	return $condsTree;
}

sub isFalseNoneSingleton($) {
	my $node = shift;
	if ($node->[0] eq 'expr') {
		if ($node->[1] =~ /^(?:False|None)$/) {
			return 1;
		}
	}
	return 0;
}

sub isTrueSingleton($) {
	my $node = shift;
	if ($node->[0] eq 'expr') {
		if ($node->[1] eq 'True') {
			return 1;
		}
	}
	return 0;
}

sub isSingleton($) {
	my $node = shift;
	if ($node->[0] eq 'expr') {
		if ($node->[1] =~ /^(?:False|None|True)$/) {
			return 1;
		}
	}
	return 0;
}

sub checkOrLogics($) {
		my $line = shift;
		# For each "OR" node
		for my $orNode (@OrConditions) {
			my $item;
			my $unnecessaryRepetition = 1;
			my $checkingIsinstance = 0;
			my $nbRepete = 0;
			# for each sub node ....
			for my $cond (@{$orNode->[NODE_MEMBERS_LIST]}) {

				# if previously entered in checkingIsinstaence mode ...
				if ($checkingIsinstance) {
					if ($cond->[NODE_CONDITION_TYPE] eq "expr") {
						if ($cond->[1] =~ /\bisinstance\s*\(\s*([\w\.]+)/) {
							if ($item eq $1) {
#print "AGAIN : checking isinstance\n";
								$nbRepete++;
								next;
							}
						}
					}
				}
				# if sub node is a COMPARISON expression using operator "==" ...
				elsif (($cond->[NODE_CONDITION_TYPE] eq "comp") && ($cond->[NODE_OPERATOR]->[0] eq "==")) {
					
					# get the left member of the comparison expression ...
					my $member = $cond->[NODE_MEMBERS_LIST]->[LEFT_MEMBER];
					
					# if the left member is an expression ...
					if ($member->[0] eq "expr") {
						
						# at first time, memorize the expression value ...
						if (! defined $item) {
							$item = $member->[1];
#print "ITEM OR : $item\n";
							next;
						}
						# ... and the next times check if expression value is equal to previous.
						elsif ($item eq $member->[1]){
#print "AGAIN: $item\n";
							$nbRepete++;
							next;
						}
					}
				}
				elsif ($cond->[NODE_CONDITION_TYPE] eq "expr") {
					if ($cond->[1] =~ /\bisinstance\s*\(\s*([\w\.]+)/) {
						$checkingIsinstance = 1;
						$item = $1;
#print "ITEM OR  : checking isinstance\n";
						next;
					}
				}
				
				# Invalidation of all violation pattern ==> stop evaluating this logical expression.
				$unnecessaryRepetition = 0;
				last;
			}
			
			if ($unnecessaryRepetition) {
				$nb_RepetitionInComparison++;
				if ($checkingIsinstance) {
					Erreurs::VIOLATION("$RepetitionInComparison__mnemo", "unnecessary 'isinstance' repetition (x$nbRepete) in OR expression at line $line");
				}
				else {
					Erreurs::VIOLATION("$RepetitionInComparison__mnemo", "unnecessary repetition (x$nbRepete) for checking $item in OR expression at line $line");
				}
			}
		}
}

sub checkAndLogics($) {
		my $line = shift;
		# For each "AND" node
		for my $andNode (@AndConditions) {
			my $item;
			my $unnecessaryRepetition = 1;
			my $checkingIsinstance = 0;
			my $nbRepete=0;
			# for each sub node ....
			for my $cond (@{$andNode->[NODE_MEMBERS_LIST]}) {
				
				# if previously entered in checkingIsinstaence mode ...
				if ($checkingIsinstance) {
					if ($cond->[NODE_CONDITION_TYPE] eq "not") {
						$cond = $cond->[NODE_MEMBERS_LIST]; 
						if ($cond->[NODE_CONDITION_TYPE] eq "expr") {
							if ($cond->[1] =~ /\bisinstance\s*\(\s*([\w\.]+)/) {
								if ($item eq $1) {
#print "AGAIN : checking isinstance\n";
									$nbRepete++;
									next;
								}
							}
						}
					}
				}
				# if sub node is a comparison expression using operator "!=" ...
				elsif (($cond->[NODE_CONDITION_TYPE] eq "comp") && (($cond->[NODE_OPERATOR]->[0] eq "!=") || ($cond->[NODE_OPERATOR]->[0] eq "<>"))) {
					
					# get the left member of the comparison expression ...
					my $member = $cond->[NODE_MEMBERS_LIST]->[LEFT_MEMBER];
					
					# if the left member is an expression ...
					if ($member->[0] eq "expr") {
						
						# at first time, memorize the expression value ...
						if (! defined $item) {
							$item = $member->[1];
							next;
#print "ITEM AND: $item\n";
						}
						# ... else check if expression value is equal to previous.
						elsif ($item eq $member->[1]){
							$nbRepete++;
							next;
#print "AGAIN: $item\n";
						}
					}
				}
				elsif(($cond->[NODE_CONDITION_TYPE] eq "not")) {
					$cond = $cond->[NODE_MEMBERS_LIST];
					if ($cond->[NODE_CONDITION_TYPE] eq "expr") {
						if ($cond->[1] =~ /\bisinstance\s*\(\s*([\w\.]+)/) {
							$checkingIsinstance = 1;
							$item = $1;
#print "ITEM AND  : checking isinstance\n";
							next;
						}
					}
				}
				$unnecessaryRepetition = 0;
				last;
			}
			if ($unnecessaryRepetition) {
				$nb_RepetitionInComparison++;
				if ($checkingIsinstance) {
					Erreurs::VIOLATION("$RepetitionInComparison__mnemo", "unnecessary 'isinstance' repetition (x$nbRepete) in AND expression at line $line");
				}
				else {
					Erreurs::VIOLATION("$RepetitionInComparison__mnemo", "unnecessary repetition (x$nbRepete) for checking $item in AND expression at line $line");
				}
			}
		}
}



sub CountConditions($$$) {
	my ($file, $views, $compteurs) = @_ ;
	my $ret =0;
	
	$nb_ExplicitComparisonToSingleton = 0;
	$nb_DeprecatedOperator = 0;
	$nb_InstanceOf = 0;
	$nb_BadIdenticalOperatorUse = 0;
	$nb_InvertedLogic = 0;
	$nb_RepetitionInComparison = 0;
	$nb_ComplexConditions = 0;
	$nb_MultilineConditions = 0;
	$nb_Conditions = 0;
	
	my $nbDecisions = 0;
	my $nbLogics = 0;
	my $nbComplexLogics = 0;
	
	my $kindLists = $views->{'KindsLists'};

	if ( ! defined $kindLists ) {
		$ret |= Couples::counter_add($compteurs, $ExplicitComparisonToSingleton__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $DeprecatedOperator__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $InstanceOf__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadIdenticalOperatorUse__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $InvertedLogic__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $RepetitionInComparison__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ComplexConditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MultilineConditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $Conditions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );

		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $conditions = $kindLists->{&ConditionKind};

	$nb_Conditions = scalar @$conditions;

	for my $cond (@$conditions) {
		my $condtext = ${GetStatement($cond)};
		my $line = GetLine($cond);
		
		$nbOr = 0;
		$nbAnd = 0;

#print "************ $condtext\n";
		my $condsTree = parse($condtext);
		
		$nbDecisions++;
		
		# ==== CHECK IF MULTILINE
		
		if ($condtext =~ /\n/) {
			$nb_MultilineConditions++;
			Erreurs::VIOLATION($MultilineConditions__mnemo, "Multiline condition at line $line");
		}
		
		# ==== CHECK EQUALITIES TO SINGLETONS ====
		
		#if ($condtext =~ /[\!=]=\s*(False|None)\b/) {
		for my $cond (@EqualityConditions) {
			# reverse members order to check second one at first ...
			my @members = ($cond->[NODE_MEMBERS_LIST]->[RIGHT_MEMBER], $cond->[NODE_MEMBERS_LIST]->[LEFT_MEMBER]);
			
			for my $member (@members) {
				if (isFalseNoneSingleton($member)) {
					Erreurs::VIOLATION($ExplicitComparisonToSingleton__mnemo, "Explicit comparison to $member->[1] at line $line");
					$nb_ExplicitComparisonToSingleton++;
				}
				elsif (isTrueSingleton($member)) {
					Erreurs::VIOLATION($ExplicitComparisonToSingleton__mnemo, "Explicit comparison to True at line $line");
					$nb_ExplicitComparisonToSingleton++;
				}
			}
		}
		
		#if ($condtext =~ /[\!=]=\s*True\b/) {
		
		#	Erreurs::VIOLATION($ExplicitComparisonToSingleton__mnemo, "Explicit comparison to True at line $line");
		#	$nb_ExplicitComparisonToSingleton++;
		#}
		
		# ==== CHECK IDENTITIES ====
		
		#if ($condtext =~ /\b(is(?:\s+not)?)\s+([\w\.]+)/) {
		#	if (($2 ne 'True') && ($2 ne 'False') && ($2 ne 'None')) {
		#		Erreurs::VIOLATION($BadIdenticalOperatorUse__mnemo, "right operand of '$1' is $2 (not a singleton) at line $line");
		#		$nb_BadIdenticalOperatorUse++;
		#	}
		#}
		for my $cond (@IdentityConditions) {
			if (! isSingleton($cond->[NODE_MEMBERS_LIST]->[RIGHT_MEMBER])) {
				Erreurs::VIOLATION($BadIdenticalOperatorUse__mnemo, "right operand of '".$cond->[1]->[0]."' is '".$cond->[NODE_MEMBERS_LIST]->[RIGHT_MEMBER]->[1]."' (not a singleton) at line $line");
				$nb_BadIdenticalOperatorUse++;
			}
		}
		
		if ($condtext =~ /<>/) {
			Erreurs::VIOLATION($DeprecatedOperator__mnemo, "Use of deprecated operator <> at line $line");
			$nb_DeprecatedOperator++;
		}
		
		if ($condtext =~ /\btype\s*\(/) {
			Erreurs::VIOLATION($InstanceOf__mnemo, "Use of type() inside condition at line $line");
			$nb_InstanceOf++;
		}

		#-----------------------------------------------
		#if ($condtext =~ /\bnot\b.*?\b(and|or|&&|\|\||is)\b/) {
		#	if ($1 eq 'is') {
		#		Erreurs::VIOLATION($InvertedLogic__mnemo, "Prefer 'is not' at line $line");
		#		$nb_InvertedLogic++;
		#	}
		#}
		for my $cond (@NotConditions) {
			my $member = $cond->[NODE_MEMBERS_LIST];
			# if the member of the not operator is a 'comparison' expression using the operator "is" ...
			if (($member->[0] eq 'comp') and ($member->[1]->[0] eq 'is')) {
				Erreurs::VIOLATION($InvertedLogic__mnemo, "Prefer 'is not' at line $line");
				$nb_InvertedLogic++;
			}
			#elsif (($member->[0] eq 'comp') and ($member->[1]->[0] eq '==')) {
			#	Erreurs::VIOLATION("TBD", "Prefer '!=' at line $line");
			#	$nb_InvertedLogic++;
			#}
		}
		
		checkOrLogics($line);
		checkAndLogics($line);

		$nbLogics += $nbOr + $nbAnd;

		if ($nbOr && $nbAnd) {
			if ($nbOr + $nbAnd > 2) {
				Erreurs::VIOLATION($ComplexConditions__mnemo, "Complex condition (".($nbOr + $nbAnd)." logical operators) at line $line");
				$nb_ComplexConditions++;
				$nbComplexLogics += $nbOr + $nbAnd;
			}
		}
		
	}

	$ret |= Couples::counter_update($compteurs, $ExplicitComparisonToSingleton__mnemo, $nb_ExplicitComparisonToSingleton );
	$ret |= Couples::counter_update($compteurs, $DeprecatedOperator__mnemo, $nb_DeprecatedOperator );
	$ret |= Couples::counter_update($compteurs, $InstanceOf__mnemo, $nb_InstanceOf );
	$ret |= Couples::counter_update($compteurs, $BadIdenticalOperatorUse__mnemo, $nb_BadIdenticalOperatorUse );
	$ret |= Couples::counter_update($compteurs, $InvertedLogic__mnemo, $nb_InvertedLogic );
	$ret |= Couples::counter_update($compteurs, $RepetitionInComparison__mnemo, $nb_RepetitionInComparison );
	$ret |= Couples::counter_update($compteurs, $ComplexConditions__mnemo, $nb_ComplexConditions );
	$ret |= Couples::counter_update($compteurs, $MultilineConditions__mnemo, $nb_MultilineConditions );
	$ret |= Couples::counter_update($compteurs, $Conditions__mnemo, $nb_Conditions );
	
	return $ret;
}

1;


