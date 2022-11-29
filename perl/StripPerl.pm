package StripPerl;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

# prototypes publics
sub StripPerl($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                  dumpVueStrings
                 );

StripUtils::init('StripPerl', 0);

#-----------------------------------------------------------------------

my $blank = \&garde_newlines;

my $TEXT;
my $CODE="";
my $COMMENT = "";
my $MIX = "";

my $STRING_CONTEXT = { 
	'nb_distinct_strings' => 0,
	'strings_values' => {},
	'strings_counts' => {}
} ;
my $RT_STRINGS = $STRING_CONTEXT->{'strings_values'};


my %peer = (
	'(' => ')',
	'[' => ']',
	'{' => '}',
);

# COMMENTS FEATURE :
#-------------------
# kinds :
#   - Simple line : // ..... \n
#   - Multiline   : /* ..... */
sub parseLineComment($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$CODE .= $newLines;
	$COMMENT .= $el;
	$MIX .= '/*';
	
	while ( $$TEXT =~ /\G(\n|[^\n]*)/gc) {
		$newLines = $blank->($1);
		$CODE .= $blank->($1);
		$COMMENT .= $1;
		$MIX .= $1;
		
		if ($1 eq "\n") {
			return 0;
		}
	}
	
	return 0;
}

sub parseMultilineLineComment($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$CODE .= $newLines;
	$COMMENT .= $el;
	$MIX .= $el;
	
	while ( $$TEXT =~ /\G(\*\/|\*|[^*]*)/gc) {
		$newLines = $blank->($1);
		if ($1 eq "*/") {
			$CODE .= $blank->($1);
			$COMMENT .= $1;
			$MIX .= $1;
			return 0;
		}
		else {
			$CODE .= $blank->($1);
			$COMMENT .= $1;
			$MIX .= $1;
		}
	}
	print STDERR "Unterminated comment !!!\n";
	return 1;
}


# SIMPLE QUOTE STRING
sub parseSplString($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = $el;
	my $CODE_padding = "";
	
	# \\\\ is to capture escaped backslash. Needed for '\\' !!!
	while ( $$TEXT =~ /\G(\\\\|\\'|\\|'|[^\\']+)/gc) {
		$string_buffer .= $1;
		
		$newLines = $blank->($1);
		
		if ($1 eq "'") {
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;	
#print "SPL STRING : $string_buffer\n";
			return 0;
		}
		else {
			$CODE_padding .= $newLines;
			$COMMENT .= $newLines;
		}		
	}

	print STDERR "Unterminated simple quote string\n";
print STDERR "--> $string_buffer\n";
	return 1;
}

# DOUBLE QUOTE STRING
sub parseDblString($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = $el;
	my $CODE_padding = "";

	# \\\\ is to capture escaped backslash. Needed for "\\" !!!
	while ( $$TEXT =~ /\G(\\\\|\\"|\\|"|[^\\"]+)/gc) {
		$string_buffer .= $1;
		$newLines = $blank->($1);
		
		if ($1 eq '"') {
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;	
print "DBL STRING : $string_buffer\n";
			return 0;
		}
		else {
			$CODE_padding .= $newLines;
			$COMMENT .= $newLines;
		}		
	}

	print STDERR "Unterminated double quote string\n";
	print STDERR "--> $string_buffer\n";
	return 1;
}

sub parseRegexpExpression($$$$) {
	my $closing = shift;
	my $regexp = shift;
	my $REG = shift;
	my $CODE_padding = shift;
	my $newLines = "";
	
	my $accoLevel = 0;
	while ($$TEXT =~ /$regexp/gc) {
		$newLines = $blank->($1);
		$COMMENT .= $newLines;
		$$CODE_padding .= $newLines;
		$$REG .= $1;
		
		# ACCOLAD SYNTAX
		if ($closing eq '}') {
			if ($1 eq '{') {
				$accoLevel++;	
			}
			elsif ($1 eq '}') {
				if ($accoLevel == 0) {
					return 0;
				}
				else {
					$accoLevel--;
				}
			}
		}
		# OTHER SYNTAX
		else {
			if ($1 eq $closing) {
				return 0;
			}
		}
	}
	return 1;
}

sub parseRegexp() {
	my $verb;
	my $openning;
	
	my $state = keepState($TEXT, [\$CODE, \$COMMENT, \$MIX]);
	
	if ($$TEXT =~ /\G(\s*)(?:(m|s|tr|qr)?\s*([^\w\$])|(\w+|\$\w+))/gc ) {
		if (defined $3) {
			$verb = $2 || '';
			$openning = $3;
			
			$COMMENT .= $blank->($1.$verb.$openning);
		}
		else {
			$COMMENT .= $blank->($1.$4);
			$CODE .= $1.$4;
			$MIX .= $1.$4;
			
			return 0;
		}
	}
	
	my $newLines = $blank->($verb.$openning);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $REG = $verb.$openning;
	my $CODE_padding = "";

	my $closing = $peer{$openning} || $openning;
	my $esc_closing = "\\".$closing;
	# \\\\ is to capture escaped backslashes (ex. in s/\\/\\\\/g;)
	my $regexp = qr/\G(\\\\|\\$esc_closing|\\|$esc_closing|[^\\$esc_closing]+)/;
	
	if ($closing eq '}') {
		$regexp = qr/\G(\\\\|\\\{|\{|\\\}|\}|\\|[^\\{}]+)/;
	}
	
	my $err = parseRegexpExpression($closing, $regexp, \$REG, \$CODE_padding);
	
	if (!$err) {	
		# parse substitution
		if (($verb eq 's') or ($verb eq 'tr') ) {
			if ($openning eq '{') {
				$$TEXT =~ /\G(\s*{)/gc;
				$newLines = $blank->($1);
				$COMMENT .= $newLines;
				$CODE_padding .= $newLines;
				$REG .= $1;
			}
			$err = parseRegexpExpression($closing, $regexp, \$REG, \$CODE_padding);
		}
	}

	# MANAGE BAD TERMINATION : unterminated OR not a regexp ???
	if ($err) {
		if (($verb eq '') && ($openning eq '/')) {
			# It was not a regexp, RESUME  ...
			resumeState($state);
			# Consumes the "/"
			pos($$TEXT) += 1;
			$CODE .= "/";
			$MIX .= "/";
				
			# return without error.
			return 0;
		}
		print STDERR "Unterminated REGEXP !\n";
#print STDERR "--> $REG\n";
		return 1;
	}

	
	# parse modifiers
	$$TEXT =~ /\G([sgimoxe]*)/gc;
	my $modifiers = $1;
	$REG .= $1;
	
	# check if the a regexp enclosed between /.../ is really a regexp.
	if (($verb eq '') && ($openning eq '/')) {
		if ($REG =~ /\n/) {
			if ($modifiers !~ /x/) {
				# O fu.. ! it's not a regexp !!
				# retore context before the /
				resumeState($state);
				
				# Consumes the "/"
				pos($$TEXT) += 1;
				$CODE .= "/";
				$MIX .= "/";
				
				# return without error.
				return 0;
			}
		}
	}
	
#print "REGEXP : $REG\n";
	return 0;	
}

sub parsePOD($) {
	my $word = shift;
	
	my $POD = "=$word";
	my $newLines = "";
	
	while ($$TEXT =~ /\G(\n=cut\b|\n|[^\n]+)/gc) {
		$newLines = $blank->($1);
		$COMMENT .= $1;
		$CODE .= $newLines;
		$MIX .= $newLines;
		$POD .= $1;
		
		if ($1 eq "\n=cut") {
			last;
		}
	}
#print "POD = $POD\n";
	return 0;
}

sub parseQuote($$) {
	my $q = shift;
	my $openning = shift;
	
	my $closing = $peer{$openning} || $openning;
	my $esc_openning = "\\".$openning;
	my $esc_closing = "\\".$closing;

	# qq is similar to "...". So interpolation should be managed.
	# ex : 	qq{Unicode character name "${name}" is deprecated, use "$alias2{$name}" instead});
	#  		qq[Unicode character name "${name}" is deprecated, use "$alias2->[$name]" instead]);
	#my $mustManageInterpolation = (($q eq "qq") and (($openning eq "{") or ($openning eq "[")) );
	my $mustManageInterpolation = 0;
	
	my $mustManageLevel = ($openning eq $closing ? 0 : 1 );

	my $regexp;
	if ($mustManageInterpolation) {
		# this regexp is able to manage openning/closing nested levels !!!
		$regexp = qr/	\G(\\\\|\\$esc_closing|
						\\\$|                             # capture escaped $ (to prevent from erroneous interpolations ...)
						\\|$esc_closing|
						(\$(?:\w+(?:->)?)?$esc_openning)| # interpolation like ${toto}, $titi{...}, $tata->{...}
						\$|[^\\$esc_closing\$]+)/x;
	}
	else {
		$regexp = qr/\G(\\\\|                  # capture escaped backslashes
						\\$esc_closing|        # capture escaped backslashes preceding closing (ex: "\\")
						\\|
						$esc_closing|
						$esc_openning|
						[^\\${esc_closing}${esc_openning}]+)/x;
	}
	
	my $string_buffer = "$q$openning";
	my $CODE_padding = "";
	
	my $accoLevel = 0;
	while ($$TEXT =~ /$regexp/gc) {
		
#print "QUOTED ITEM = $1\n";
		
		if (($1 eq $openning) and ($mustManageLevel)) {
			$accoLevel++;
#print "--> level ++\n";
		} 
		elsif ($1 eq "$closing") {
			
			#if ( (! $mustManageInterpolation) || ($accoLevel == 0) ) {
			if ($accoLevel == 0) {
				$string_buffer .= $1;
				my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
				$CODE .= " $string_id ".$CODE_padding;
				$MIX .= " $string_id ".$CODE_padding;
#print "QUOTE STRING = $string_buffer\n";
				return 0;
			}
			
			$accoLevel--;
		}
		
		$string_buffer .= $1;
		my $newLines = $blank->($1);
		$CODE_padding .= $newLines;
		$COMMENT .= $newLines;
	}
	
	print STDERR "Unterminated quote string\n";
#print STDERR "--> $string_buffer\n";
	return 1;
}

sub parseAntiquote($) {
	my $string_buffer = shift;
	my $CODE_padding = "";
	
	while ($$TEXT =~ /\G(\\\\|\\`\`|\`|\\|[^\`\\]+)/gc ){
		if ($1 eq "\`") {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
#print "ANTI QUOTE STRING = $string_buffer\n";
			return 0;
		}
		
		$string_buffer .= $1;
		$CODE_padding .= $blank->($1);
		$COMMENT .= $blank->($1);
	}
		print STDERR "Unterminated anti quote string\n";
print STDERR "--> $string_buffer\n";
	return 1;
}

sub keepState($$) {
	my $input = shift;
	my $output = shift;
	
	my $data = {};
	
	$data->{'input'} = $input;
	$data->{'pos_input'} = pos($$input);
	
	$data->{'outputs'} = {};
	
	for my $item (@$output) {
		$data->{'outputs_lentghs'}->{$item} = length($$item);
		$data->{'outputs_buffers'}->{$item} = $item;
	}
	
	return $data;
}

sub resumeState($) {
	my $data = shift;
	my $input = $data->{'input'};
	pos($$input) = $data->{'pos_input'};
	
	
	for my $item (keys %{$data->{'outputs_buffers'}}) {
		my $previous_length = $data->{'outputs_lentghs'}->{$item};
		my $buffer = $data->{'outputs_buffers'}->{$item};
		pos($$buffer) = $previous_length;
		$$buffer =~ s/\G.*$//sgm;
		#substr($$item, $previous_length);
	}
}

sub parseHereDoc($$) {
	my $stmt = shift;
	my $word = shift;
	
	my $HEREDOC = '<<'.$stmt;
	
	my $pos = length $COMMENT;
	
	#my $state = keepState($TEXT, [\$CODE, \$COMMENT, \$MIX]);
	
	# go to the end of the line :
	$$TEXT =~ /\G([^\n]*\n)/gc;
	my $newLines = $blank->($1);
	$HEREDOC .= "\n";
	$CODE .= $1;
	$MIX .= $1;
	
	while ($$TEXT =~ /\G(\n($word)|\n|[^\n]+)/gc) {
		$newLines = $blank->($1);
		$HEREDOC .= $1;
		$COMMENT .= $newLines;
		$CODE .= $newLines;
		$MIX .= $newLines;
		if (defined $2) {
#print "HEREDOC : $HEREDOC\n";
			return 0;
		}
	}
	print STDERR "Unterminated HEREDOC\n";
	print STDERR "--> ". substr($HEREDOC, 0, 500)."../..\n";
	return 1;
}

sub parseOpenClose($) {
	my $openning = shift;
	
	$CODE .= $openning;
	$MIX .= $openning;
	
	my $closing = $peer{$openning};

	my $esc_openning = "\\".$openning;
	my $esc_closing = "\\".$closing;

	if (!defined $closing) {
		print STDERR "[StripPerl] unknow closing peer for $openning !\n";
		return 1;
	}
	
	my $level = 1;
	while ($$TEXT =~ /\G($esc_openning|$esc_closing|[^${esc_openning}${esc_closing}]+)/gc) {
		$CODE .= $1;
		$MIX .= $1;
		
		if ($1 eq $openning) {
			$level++;
		}
		elsif ($1 eq $closing) {
			$level--;
			if (!$level) {
				return 0;
			}
		}
	}
	return 1;
}

sub parseVariable($) {
	my $item=shift;
	
my $pos = length $CODE;

	$CODE .= $item;
	$MIX .= $item;

	if ($$TEXT =~ /\G([\$\@\%]+)/gc) {
		$CODE .= $1;
		$MIX .= $1;
	}

	if ($$TEXT =~ /\G(\{)/gc) {
		my $err = parseOpenClose($1);
		if ($err) {
			print STDERR "[StripPerl] error when parsing variable \${xxx}\n";
			return $err;
		}
	}
	elsif ($$TEXT =~ /\G([\w:]+)/gc) {
		$CODE .= $1;
		$MIX .= $1;
	}
	elsif ($$TEXT =~ /\G(["'\/])/gc) {
		# special var $" or $' or $/
		$CODE .= $1;
		$MIX .= $1;
	}
	else {
		#print STDERR "[StripPerl] unknow var syntax : ".substr($$TEXT, pos($$TEXT), 30)."\n";
		
		# unrecognized var syntax ... continue as if it were good ...
		return 0;
	}
	
	if ($$TEXT =~ /\G->/gc) {
		$CODE .= '->';
		$MIX .= '->';
	}
	
	if ($$TEXT =~ /\G([\{\[])/gc) {
		my $err = parseOpenClose($1);
		if ($err) {
			print STDERR "[StripPerl] error when parsing tab or hash access ... \n";
			print STDERR "--> ".substr($CODE, $pos, 50)."\n";
			return $err;
		}
	}
	
#print STDERR "VARIABLE : ".substr($CODE, $pos)."\n";
	return 0;
	
}

my $previousIsVariable = 0;
my $previousIsWord = 0;

sub parseCode($$) {
	$TEXT = shift;
	my $options = shift;
	
	my $err = 0;

	my @parentStack = ();
	
	while ( $$TEXT =~ /\G(	\#|                        # $1
							                  #\$\w+|\@\w+|                     # consumes all variable name because we need non-variable identifier preceding a regexp.
							                  #\$"|\$'|\$q|
							"|'|`|\$|
							\n=\w+|\n|
							[=!]~|=|!|
							__END__|__DATA__|_|
							<<|<|
							(?:\bqr\b.)|
							\b(?:qw|qq|qx|q)\b\s*.|
							\b\d+\s*\/|                # a literal number followed by a \/ ==> it's DIV, not a regexp !!!
							\)\s*\/|                   # a closing parent followed by a \/ ==> regexp or not ???
							(\b(?:s|m|tr)\s*[^\w]|\/)|      # $2
							((?:if|while|for|foreach)\s*\()|   # $3
							;|\(|\{|,|(\w+)|\@|\/|\(|\)| # $4
							[^\#"'`=\w!\n\$<\@\/()]+
						  )/gcx) {
#print "** ITEM = <$1>\n";
#print "** ITEM \$2 = <$2>\n" if defined $2;
#print "** ITEM \$3 = <$3>\n" if defined $3;
#print "** ITEM \$4 = <$4>\n" if defined $4;

		my $newLines = $blank->($1);
		
		if (($1 eq '$') or ($1 eq '@')) {
			$err = parseVariable($1);
			
			if (! $err) {
				# Consumes the DIV operator, if any (to not confuse later with a regexp delimiter).
				if ($$TEXT =~ /\G(\s*\/)/gc) {
					$CODE .= $1;
					$COMMENT .= $blank->($1);
					$MIX .= $1;
				}
				$previousIsVariable = 2;
			}
			
		}
		elsif ($1 eq '"') {
			$err = parseDblString($1);
		}
		elsif ($1 eq '#') {
			$err = parseLineComment($1);
		}
		elsif ($1 eq "'") {
			$err = parseSplString($1);
		}
		elsif ($1 eq "`") {
			$err = parseAntiquote($1);
		}
		elsif (($1 eq "=~") or ($1 eq "!~")) {
			$CODE .= $1;
			$COMMENT .= $blank->($1);
			$MIX .= $1;
			$err = parseRegexp();
		}
		elsif (defined $2) {
			pos($$TEXT) -= length($2);
			$err = parseRegexp();
		}
		elsif (defined $3) {
			push @parentStack, 1; # 1 means parenthese level corresponding to a condition ...
			$CODE .= $3;
			$COMMENT .= $blank->($3);
			$MIX .= $3;
		}
		elsif ($1 eq '(') {
			push @parentStack, 0; # 0 means parenthese level NOT corresponding to a condition ...
			$CODE .= $1;
			$MIX .= $1;
		}
		elsif ($1 eq ')') {
			pop @parentStack;      # remove parenthese level
			$CODE .= $1;
			$MIX .= $1;
		}
		# check regexp following a condition closing prenthese ...
		elsif ($1 =~ /^(\)\s*)\//m) {
			my $context = pop @parentStack;
			if ($context == 1) {
				$CODE .= $1;
				$COMMENT .= $blank->($1);
				$MIX .= $1;
				pos($$TEXT)--;        # seek to the /
				$err = parseRegexp();
			}
			else {
				$CODE .= $1."/";
				$COMMENT .= $blank->($1);
				$MIX .= $1."/";

			}
		}
		elsif ($1 =~ /^qr([^\w])$/m) {
			# seek to the regexp beginning.
			pos($$TEXT) -= 3;
			$err = parseRegexp();
		}
		elsif ($1 =~ /\n=(\w+)/) {
			$COMMENT .= "\n=$1";
			$CODE .= "\n";
			$MIX .= "\n";
			
			if ($1 ne 'cut') {
				$err = parsePOD($1);
			}
		}
		elsif ($1 =~ /\b(qw|qq|q)\b\s*(.)/) {
			$err = parseQuote($1, $2);
		}
		elsif ($1 eq "<<") {
			my $heredoc = 0;
			if (! $previousIsVariable) { 
				if (! $previousIsWord) {
					if ($$TEXT =~ /\G((?: *["'])?(\w+)["']?)/gc) {
						$heredoc = 1;
						$err = parseHereDoc($1, $2);
					}
				}
			}

			if (!$heredoc) {
				$CODE .= "<<";
				$MIX .= "<<";
			}
		}
		elsif (($1 eq '__END__') or ($1 eq '__DATA__')) {
			# End of code !
			# all is after is ignored
			last;
		}
		elsif (defined $4) {
			$previousIsWord = 2; 
			$CODE .= $4;
			$COMMENT .= $blank->($4);
			$MIX .= $4;
		}
		else {
			$CODE .= $1;
			$COMMENT .= $newLines;
            $MIX .= $1;
		}
		
		if ($err gt 0) {
			return 1;
		}
		
		$previousIsVariable-- if $previousIsVariable;
		$previousIsWord-- if $previousIsWord;
	}
	
	return  0;
}

# analyse du fichier
sub StripPerl($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);

    configureLocalTraces('StripPerl', $options); # traces_filter_line
    my $StripPerlTiming = new Timing ('StripPerl', Timing->isSelectedTiming ('Strip'));
    $StripPerlTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    
    
	# Init data
	$CODE = "";
    $COMMENT = "";
    $MIX = "";
    $STRING_CONTEXT = { 
		'nb_distinct_strings' => 0,
		'strings_values' => {},
		'strings_counts' => {}
	};
	$RT_STRINGS = $STRING_CONTEXT->{'strings_values'};
    
    # Start stripping ... 
    my $err = parseCode(\$vue->{'text'}, $options);
    
    $StripPerlTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

	$vue->{'code'} = $CODE;
    $vue->{'comment'} = $COMMENT;
    $vue->{'HString'} = $RT_STRINGS;
    $vue->{'MixBloc'} = $MIX;

    if ( $err gt 0) {
      my $message = 'Fatal error when separating code/comments/strings';
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', $message);
      return Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    }

    if ( defined $options->{'--dumpstrings'})
    {
      dumpVueStrings(  $RT_STRINGS , $STDERR );
    }
    $StripPerlTiming->dump('StripPErl') if ($b_timing_strip); # timing_filter_line
    return 0;
}

1; 


