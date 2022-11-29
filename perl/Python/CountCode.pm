package Python::CountCode;

use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Python::PythonNode;
use Python::PythonConf;

my $ExtraneousSpaces__mnemo = Ident::Alias_ExtraneousSpaces();
my $MissingSpaces__mnemo = Ident::Alias_MissingSpaces();
my $TrailingSpaces__mnemo = Ident::Alias_TrailingSpaces();
my $TabIndentation__mnemo = Ident::Alias_TabIndentation();
my $MultipleStatementsOnSameLine__mnemo = Ident::Alias_MultipleStatementsOnSameLine();
my $ContinuationLines__mnemo = Ident::Alias_ContinuationLines();
my $LongLines80__mnemo = Ident::Alias_LongLines80();
my $VG__mnemo = Ident::Alias_VG();
my $BadBoundary__mnemo = Ident::Alias_BadBoundary();
my $UnnecessaryConcat__mnemo = Ident::Alias_UnnecessaryConcat();
my $UnexpectedSemicolon__mnemo = Ident::Alias_UnexpectedSemicolon();

my $nb_ExtraneousSpaces = 0;
my $nb_MissingSpaces = 0;
my $nb_TrailingSpaces = 0;
my $nb_TabIndentation = 0;
my $nb_MultipleStatementsOnSameLine = 0;
my $nb_ContinuationLines = 0;
my $nb_LongLines80 = 0;
my $nb_VG = 0;
my $nb_BadBoundary = 0;
my $nb_UnnecessaryConcat = 0;
my $nb_UnexpectedSemicolon = 0;

my $insideParent = 0;
my $insideBracket = 0;
my $leftBlankPunished = 0;
my @OpenningPunished = ();

my %PythonKeywords = ("or" => 1, "and" => 1, "if" => 1, "elif" => 1, "else" => 1, "for" => 1, "while" => 1, "in" => 1, "import" => 1, "from" => 1, "not" => 1, "return" => 1, "except" => 1, "witth" => 1, , "yield" => 1, "assert" => 1);

sub checkExtraneousBefore($$$$) {
	my $item = shift;
	my $leftItem = shift;
	my $leftBlank = shift;
	my $line = shift;
	my $punished = 0;
	
	if ($leftItem eq "\n") {
		# do nothing if $leftItem is \n because this means the item is at line beginning.
		return ;
	}
	
		if ((!$leftBlankPunished) && ($leftBlank ne '')) {
			# check equal
			if ($item eq "=") {
				if ($insideParent) {
					Erreurs::VIOLATION($ExtraneousSpaces__mnemo, "Unexpected spacing between $leftItem and *$item* at line : $line");
					$nb_ExtraneousSpaces++;
					$punished = 1;
					
				}
				else {
					# check if more than one blank
					if (($leftBlank ne " ") && ($leftBlank ne "\t")) {
						Erreurs::VIOLATION($ExtraneousSpaces__mnemo, "two many spacing between $leftItem and *$item* at line : $line");
						$nb_ExtraneousSpaces++;
						$punished = 1;
					}
				}
			}
			# check openning
			elsif (($item eq "(") || ($item eq "[")) {
				# check line begining or word ...
				if ($leftItem =~ /\w/) {
					# check language keyword
					if (! exists $PythonKeywords{$leftItem}) {
						Erreurs::VIOLATION($ExtraneousSpaces__mnemo, "Unexpected spacing between $leftItem and *$item* at line : $line");
						$nb_ExtraneousSpaces++;
						$punished = 1;
					}
				}
			}
			# check openning braces
			elsif ($item eq "{") {
				# no problem with spaces before openning braces.
			}
			# check closing
			elsif (($item eq ")") || ($item eq "]") || ($item eq "}")) {
				# do nothing if peer openning has been punished ...
				if (! $OpenningPunished[-1]) {
					if ($leftItem =~ /\w/) {
						Erreurs::VIOLATION($ExtraneousSpaces__mnemo, "Unexpected spacing between $leftItem and *$item* at line : $line");
						$nb_ExtraneousSpaces++;
						$punished = 1;
					}
				}
			}
			# check comma, colon ...
			else {
				# check line beginning or word
				if ($leftItem ne '') {
					if ($leftItem ne ',') {
						Erreurs::VIOLATION($ExtraneousSpaces__mnemo, "Unexpected spacing between $leftItem and *$item* at line : $line");
						$nb_ExtraneousSpaces++;
						$punished = 1;
					}
				}
			}
		}
	return $punished;
}

sub checkExtraneousAfter($$$$) {
	my $item = shift;
	my $rightBlank = shift;
	my $rightItem = shift;
	my $line = shift;

		if ($rightItem eq "\n") {
			return;
		}
#print "[checkExtraneousAfter] insideBracket : $insideBracket\n";
		# CHECK SPACE AFTER
		if ($rightBlank ne '') {
			# check equal
			if ($item eq "=") {
				if ($insideParent) {
#print "level : $insideParent\n";
					Erreurs::VIOLATION($ExtraneousSpaces__mnemo, "Unexpected spacing between *$item* and $rightItem at line : $line");
					$nb_ExtraneousSpaces++;
				}
				else {
					# check if more than one blank
					if (($rightBlank ne " ") && ($rightBlank ne "\t")) {
						Erreurs::VIOLATION($ExtraneousSpaces__mnemo, "two many spaces between *$item* and $rightItem at line : $line");
						$nb_ExtraneousSpaces++;
					}
				}
			}
			# check openning
			elsif (($item eq "(") || ($item eq "[") || ($item eq "{")) {
				# check line ending or something else
				#if ($rightItem ne "\n") {
					if ($rightItem  =~ /\w/) {
						$leftBlankPunished = 1;
						# mark this openning as punished (it is the last in the list)
						$OpenningPunished[-1] = 1;
						Erreurs::VIOLATION($ExtraneousSpaces__mnemo, "Unexpected spacing between *$item* and $rightItem at line : $line");
						$nb_ExtraneousSpaces++;
					}
				#}
			}
			elsif ($item eq ":") {
				if ($insideBracket) {
					Erreurs::VIOLATION($ExtraneousSpaces__mnemo, "Unexpected spacing between *$item* and $rightItem at line : $line");
					$nb_ExtraneousSpaces++;
				}
			}
		}
		# Right blank is empty ...
		elsif (		(($item eq ",") and ($rightItem ne ')'))
				or 	( $item eq ";")
				or 	(($item eq ":") and (!$insideBracket))	) {
			$nb_MissingSpaces++;
			Erreurs::VIOLATION($MissingSpaces__mnemo, "Missing space between *$item* and $rightItem at line : $line");
		}
}

sub checkMissingBefore($$$$) {
	my $item = shift;
	my $leftItem = shift;
	my $leftBlank = shift;
	my $line = shift;
	my $punished = 0;

	if ($leftItem eq "\n") {
		# do nothing if $leftItem is \n because this means the item is at line beginning.
		return 0;
	}
	
	if ($leftBlank eq '') {
		if ( not (($leftItem eq "=") && $insideParent)) {
			$punished = 1;
			$nb_MissingSpaces++;
			Erreurs::VIOLATION($MissingSpaces__mnemo, "Missing space between $leftItem and *$item* at line : $line");
		}
	}
	
	return $punished;
}

sub checkMissingAfter($$$$) {
	my $item = shift;
	my $rightBlank = shift;
	my $rightItem = shift;
	my $line = shift;
	
	if ($rightItem eq "\n") {
		# do nothing if $rightItem is \n because this means the item is at line ending.
		return ;
	}
	
	if ($rightBlank eq '') {
		$nb_MissingSpaces++;
		Erreurs::VIOLATION($MissingSpaces__mnemo, "Missing space between *$item* and $rightItem at line : $line");
	}
}

my $TYPE_COMPARISON = 0;
my $TYPE_OTHER = 1;

my @cb_checkAfter = (\&checkMissingAfter, \&checkExtraneousAfter);
my @cb_checkBefore = (\&checkMissingBefore, \&checkExtraneousBefore);

sub CountCode($$$) {
	my ($file, $views, $compteurs) = @_ ;
	my $ret =0;

	$nb_ExtraneousSpaces = 0;
	$nb_MissingSpaces = 0;
	$nb_TrailingSpaces = 0;
	$nb_TabIndentation = 0;
	$nb_MultipleStatementsOnSameLine = 0;
	$nb_ContinuationLines = 0;
	$nb_VG = 0;
	$nb_BadBoundary = 0;
	$nb_UnnecessaryConcat = 0;
	$nb_UnexpectedSemicolon = 0;
	
	my $code = \$views->{'code'};
	my $MixBloc = \$views->{'MixBloc'};
	my $HMissingNewLineAfterControle = $views->{'HMissingNewLineAfterControle'};
	my $kindLists = $views->{'KindsLists'};

	if ((! defined $code) || (! defined $MixBloc) || (! $kindLists)) {
		$ret |= Couples::counter_add($compteurs, $ExtraneousSpaces__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MissingSpaces__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $TrailingSpaces__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $TabIndentation__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MultipleStatementsOnSameLine__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ContinuationLines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $VG__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadBoundary__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnnecessaryConcat__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnexpectedSemicolon__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $line = 1;
	
	my $previousItem;
	my $previousType;
	my $previousItemPunished = 0;
	my $previousBlank = '';
	my $leftItem = '';
	my $leftItemIsWord = 0;
	my $leftBlank = '';
	
	my $item;
	my $rightBlank;
	my $rightItem;
	
	$insideParent = 0;
	$leftBlankPunished = 0;
	@OpenningPunished = ();

	my $parentLevel = 0;
	my $bracketLevel = 0;
	my $braceLevel = 0;
	my $endingBackslash = 0;
	my $continuation = 0;
	my $badIndent = undef;
	my $badIndentLength = 0;

	# Compute VG
	
	my $nb_VG =	1 +
				scalar @{$kindLists->{&FunctionKind}} +
				scalar @{$kindLists->{&MethodKind}} +
				scalar @{$kindLists->{&WhileKind}} + 
				scalar @{$kindLists->{&ForKind}} + 
				scalar @{$kindLists->{&IfKind}};
	
	Erreurs::VIOLATION($VG__mnemo, "Cyclomatic complexity is : $nb_VG");
	
	# Multiple instruction, continuation lines ...
	
	while ($$code =~ /^(.*)$/mg) {
		my $linecode = $1;
		if (exists $HMissingNewLineAfterControle->{$line}) {
			$nb_MultipleStatementsOnSameLine++;
			Erreurs::VIOLATION($MultipleStatementsOnSameLine__mnemo, "Several instructions (condition + instruction(s)) at line : $line");
		}
		elsif ($linecode =~ /;[ \t]*[^ \t\\]/) {
			# semicolon is followed by an instruction
			Erreurs::VIOLATION($MultipleStatementsOnSameLine__mnemo, "Several instructions at line : $line");
			$nb_MultipleStatementsOnSameLine++;
		}
		
		if ($linecode =~ /;[ \t]*\\?$/m) {
			# semicolon is followed by EOL or backslash continuation line
			$nb_UnexpectedSemicolon++;
			Erreurs::VIOLATION($UnexpectedSemicolon__mnemo, "Unexpected ; at line : $line");
		}

		if ($linecode =~ /\\[ \t]*$/) {
			$nb_ContinuationLines++;
			Erreurs::VIOLATION($ContinuationLines__mnemo, "Continuation line at line : $line");
		}
		$line++;
	}
	
	#while ($$code =~ /^(?:([^;\n\\]*)|[^;\n\\]*(;)[ \t]*([^ \t\n\\])?[^\\\n]*)([^ \t;\n])?[ \t]*$/mg) {
	#	if (defined $2) {
	#		if (defined $3) {
	#			Erreurs::VIOLATION("TBD", "Several instruction at line : $line");
	#			$nb_MultipleStatementsOnSameLine++;
	#		}
	#		else {
	#			Erreurs::VIOLATION("TBD", "Unexpected ; at line : $line");
	#		}
	#	}
	#	if ((defined $4) && ($4 eq "\\")) {
	#		$nb_ContinuationLines++;
	#		Erreurs::VIOLATION("TBD", "Continuation line at line : $line");
	#	}
	#	$line++;
	#}

	$line =1;
	while ($$code =~ /^([ \t]*)([^\n]*?)(\\)?$/mg) {
		my $endLine = $2;
		my $indentLength = length($1);
		$endingBackslash = defined $3;

		# $parentLevel > 0 means we are in continuation line ...
		if ((! $parentLevel) && (! $bracketLevel) && (! $braceLevel) && (! $continuation) && ($2 ne '')) {
			
			if ((defined $badIndent) && ($indentLength < $badIndentLength)) {
				$badIndent = undef;
			}
			
			if (! defined $badIndent) {
				if ($indentLength % 4 ) {
					$badIndent = $1;
					$badIndentLength = $indentLength;
					$nb_TabIndentation++;
					Erreurs::VIOLATION($TabIndentation__mnemo, "indentation length is not a multiple of 4 at line $line");
				}
				elsif ($1 =~ /\t/) {
					$badIndent = $1;
					$badIndentLength = $indentLength;
					$nb_TabIndentation++;
					Erreurs::VIOLATION($TabIndentation__mnemo, "indentation contains tabs at line $line");
				}
			}
		}
		
		$parentLevel += () = $endLine =~ /\(/g;
		$parentLevel -= () = $endLine =~ /\)/g;
		$bracketLevel += () = $endLine =~ /\[/g;
		$bracketLevel -= () = $endLine =~ /\]/g;
		$braceLevel += () = $endLine =~ /\{/g;
		$braceLevel -= () = $endLine =~ /\}/g;
		
		$line++;
		$continuation = $endingBackslash;
	}
	
	$line = 1;
	# search trailing spaces
	# --> search in MixBloc view all non-blank lines terminated with one or more spaces that are not inside a comment.
	while ($$MixBloc =~ /^(?:([^#\n]*[^# \t\n][ \t]+)?|.*)$/mg) {
		if (defined $1) {
			$nb_TrailingSpaces++;
			Erreurs::VIOLATION($TrailingSpaces__mnemo, "Trailing whitespace at line : $line");
		}
		$line++;
	}
	
	$line = 1;
	# --------------- search missing & extraneous spaces ---------------------
	while ($$code =~ /\G(.*?)(([=!<>+-]=|<>|<|>|\b(?:or|and|not|is|in)\b)|[\(\[\{\)\]\},;:=])/smg) {
		my $heap = $1;
		my $item = $2;
		my $comparison = $3;
		my $itemType = $TYPE_OTHER;

		#if (($item eq "==") {
		if (defined $comparison) {
			$itemType = $TYPE_COMPARISON;
			# this item does not interest us ...
			#$previousItem = undef;
			#$line += () = $heap =~ /\n/g;
			#next;
		}
#print "----------- ITEM : $item TYPE = $itemType--------------\n";
		# check after previous item
		if ((defined $previousItem) && (!$previousItemPunished)) {
			if ($heap =~ /\A([ \t]*)(\w+|\S|\n)?/s) {
				$cb_checkAfter[$previousType]->($previousItem, $1, defined $2?$2:$item, $line);
			}
		}

		# update context data related to new item ...
		$line += () = $heap =~ /\n/g;
		
		if ($item eq "(") {
			push @OpenningPunished, 0;
			$insideParent++;
		}
		elsif ($item eq ")") {
			$insideParent--;
		}
		elsif ($item eq "[") {
			push @OpenningPunished, 0;
			$insideBracket++;
		}
		elsif ($item eq "]") {
			$insideBracket--;
		}
		elsif ($item eq "{") {
			push @OpenningPunished, 0;
		}

		# check before new item
		if ($heap =~ /(\w+|\S|\n)?([ \t]*)\z/s) {
			# if left item IS NOT previous item if $1 is defined (it's a new item).
			# if left item IS NOT previous item, then space before item (left blank) cannot have been treated (becasue following previous item), so cannot have been punished.
			if (defined $1) {
				# left blank is not the same that was following previous item.
				$leftBlankPunished = 0;
			}
			$previousItemPunished = $cb_checkBefore[$itemType]->($item, defined $1?$1:$previousItem, $2, $line);
		}
		else {
			$previousItemPunished = 0;
		}

		# if item is a closing, the remove the peer openning entry in the tab of punished openning items.
		if (($item eq ")") || ($item eq "]") || ($item eq "}")) {
			if (scalar @OpenningPunished == 0) {
				print "[CountCode] error in openning/closing matching\n";
			}
			else {
				pop @OpenningPunished;
			}
		}

		$previousItem = $item;
		$previousType = $itemType;
	}
	
	#----------------- Bad Boundary + UnnecessaryConcat ----------
	my @bracketStack = ();
	my $bracketContent = undef;
	my $containColon = 0;
	my $listHasEnded = 0;
	my $plusAlreadyBlamed = 0;
	$line =1;
	$previousItem = "";
	
	my $type;
	my $TYPE_LIST = 0;
	my $TYPE_ARRAY = 1;
	
	# Split code on items  [, ], : and \n
	while ($$code =~ /([^\+\[\]:\n]*)(.)/sg) {

		if ($2 eq "\n") {
			$line++;
			next;
		}
		
		if ($2 eq '[') {
			
			# SAVE PREVIOUS BRACKET DATA
			# if a first bracket level exists, then push it on the stack
			if (defined $bracketContent) {
				$bracketContent .= $1;
				push @bracketStack, [$bracketContent, $containColon, $type];
			}
			
			# COMPUTE NEW BRACKET DATA
			# Check whether the bracket is for a list or an array indexing.
			if ($previousItem eq '+') {
				if ($1 !~ /\S/) {
					$type = $TYPE_LIST;
				
					if ( ! $plusAlreadyBlamed) {
						# detection of list concatenation using "+"
						$nb_UnnecessaryConcat++;
						Erreurs::VIOLATION($UnnecessaryConcat__mnemo, "List concatenation using '+' (right operand) at line : $line");
					}
				}
				else {
					$type = $TYPE_ARRAY;
				}
			}
			else {
				# if the '[' is preceded with \w, ] or ), then the bracket is for a array indexing...
				if (($1 =~ /\w\s*$/m) ||
					(($1 !~ /\S/) && ($previousItem =~ /[\]\)]/))){
					$type = $TYPE_ARRAY;
				}
				else {
					# ... else it's for a list
					$type = $TYPE_LIST;
				}
			}

			# init data for current bracket content.
			$bracketContent = "";
			$containColon = 0;
		}


		$plusAlreadyBlamed = 0;

		if ($2 eq '+') {
			$bracketContent .= $1 if defined $bracketContent;
			
			if ($listHasEnded) {
				if ($1 !~ /\S/) {
					# detection of list concatenation using "+"
					$plusAlreadyBlamed = 1;
					$nb_UnnecessaryConcat++;
					Erreurs::VIOLATION($UnnecessaryConcat__mnemo, "List concatenation using '+' (left operand) at line : $line");
				}
			}
		}
		
		# The indication that a list has just ended is to be correlated with a "+" detection. 
		# Has "+" has been checked above, we can reset $listHasEnded.
		$listHasEnded = 0;
		
		# Continue only if inside bracket context
		# do not treat data outside bracket ...
		# ($bracketContent is not defined if we are not in an expression enclosed inside brackets).
		if (defined $bracketContent) {	

			if ($2 eq ':') {
				$bracketContent .= $1;
				$containColon = 1;
				# check lower boundary of the range.
				if ($bracketContent =~ /\blen\(/) {
					$nb_BadBoundary++;
					Erreurs::VIOLATION($BadBoundary__mnemo, "Lower boundary contain len() at line : $line");
				}
				$bracketContent = "";
			}
		
			elsif ($2 eq ']') {
				$bracketContent .= $1;
				# If a colon has been found, then check upper boundary (no colon means the bracket do not enclose a range)
				if ($containColon) {
					if ($bracketContent =~ /\blen\(/) {
						$nb_BadBoundary++;
						Erreurs::VIOLATION($BadBoundary__mnemo, "Upper boundary contain len() at line : $line");
					}
				}
			
				if ($type == $TYPE_LIST) {
					$listHasEnded = 1;
				}
			
				# get upper level bracket expression
				if (scalar @bracketStack) {
					my $current = pop (@bracketStack);
					$bracketContent = $current->[0];
					$containColon = $current->[1];
					$type = $current->[2];
				}
				else {
					$bracketContent = undef;
				}
			}
		}
		$previousItem = $2;
	}
	
	$ret |= Couples::counter_update($compteurs, $ExtraneousSpaces__mnemo, $nb_ExtraneousSpaces );
	$ret |= Couples::counter_update($compteurs, $MissingSpaces__mnemo, $nb_MissingSpaces );
	$ret |= Couples::counter_update($compteurs, $TrailingSpaces__mnemo, $nb_TrailingSpaces );
	$ret |= Couples::counter_update($compteurs, $TabIndentation__mnemo, $nb_TabIndentation );
	$ret |= Couples::counter_update($compteurs, $MultipleStatementsOnSameLine__mnemo, $nb_MultipleStatementsOnSameLine );
	$ret |= Couples::counter_update($compteurs, $ContinuationLines__mnemo, $nb_ContinuationLines );
	$ret |= Couples::counter_update($compteurs, $VG__mnemo, $nb_VG );
	$ret |= Couples::counter_update($compteurs, $BadBoundary__mnemo, $nb_BadBoundary );
	$ret |= Couples::counter_update($compteurs, $UnnecessaryConcat__mnemo, $nb_UnnecessaryConcat );
	$ret |= Couples::counter_update($compteurs, $UnexpectedSemicolon__mnemo, $nb_UnexpectedSemicolon );

	return $ret;
}

sub CountLongLines($$$) {
	my ($file, $views, $compteurs) = @_ ;
	my $ret =0;
    $nb_LongLines80 = 0;
    
	my $text = \$views->{'text'};
	
	my $line = 1;
	while ($$text =~ /^(.*)$/mg) {
		if (length($1) > 80) {
			$nb_LongLines80++;
			Erreurs::VIOLATION($LongLines80__mnemo, "Line $line exceeds 80 characters");
		}
		$line++;
	}

	$ret |= Couples::counter_update($compteurs, $LongLines80__mnemo, $nb_LongLines80 );

	return $ret;
}
1;

