package StripScala;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

# prototypes publics
sub StripScala($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                  dumpVueStrings
                 );

StripUtils::init('StripScala', 0);

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
		if ($1 eq "\n") {
			$CODE .= $blank->($1);
			$COMMENT .= $1;
			$MIX .= "*/\n";
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

sub parseMultilineLineComment($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$CODE .= $newLines;
	$COMMENT .= $el;
	$MIX .= $el;
	my $embeddedComment = 0;
	while ( $$TEXT =~ /\G(\*\/|\/\*|\*|\/|[^*\/]*)/gc) {
		$newLines = $blank->($1);
		if ($1 eq '*/') {
			$CODE .= $blank->($1);
			$COMMENT .= $1;
			$MIX .= $1;
			return 0 if $embeddedComment == 0;
			$embeddedComment--;
		}
		elsif ($1 eq '/*') {
			$CODE .= $blank->($1);
			$COMMENT .= $1;
			$MIX .= $1;
			$embeddedComment++;
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

# STRINGS FEATURES
#-----------------
# kinds: 
#  -  Double quote string  ""
#  -  Template string      """
#
# Escape :
#     respectively \' \" \"""
#
# Line Continuation :
#     allowed for all

# DOUBLE QUOTE
sub parseDblString($$) {
	my $id = shift;
	my $el = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";

	while ($$TEXT =~ /\G(\\"|\"\"|"|\$\{|\$|\\\\|\\|\\\n|[^\\"\$]*)/gc) {
		$newLines = $blank->($1);
		$CODE_padding .= $newLines;
		$COMMENT .= $newLines;

		if ($1 eq '"') {
			$string_buffer .= $1;
			if ($string_buffer ne '"') {
				my $string_id = StringStore($STRING_CONTEXT, $string_buffer);
				$CODE .= " $string_id " . $CODE_padding;
				$MIX .= " $string_id " . $CODE_padding;
			}

			#print "DBL STRING = $string_buffer\n";
			return 0;
		}
		elsif (($1 eq '${') && (($id eq "s") || ($id eq "f") || ($id eq "raw"))) {
			$CODE .= $CODE_padding;
			$MIX .= $CODE_padding;
			$string_buffer .= '${...}';
			my $string_id = StringStore($STRING_CONTEXT, $string_buffer);
			$CODE .= " $string_id " . $CODE_padding;
			$MIX .= " $string_id " . $CODE_padding;
			parseCode($TEXT, {}, 1);
			$CODE_padding = '';
			$string_buffer = '';
		}
		elsif ($1 ne "\n") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}
	}

	print STDERR "Unterminated string !!!\n";
	print "==> " . substr($string_buffer, 0, 20) . "...\n";
	return 1;
}

# LITERAL SYMBOL | LITERAL CHAR
sub parseLiteralSymbol($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";


	#if ( $$TEXT =~ /\G(\w+)/gc) {
	if ($$TEXT =~ /\G([^\\][\s']*)/gc) {

		# literal symbol (or literal char that matches \w)

		$newLines = $blank->($1);
		$CODE_padding .= $newLines;
		$COMMENT .= $newLines;

		$string_buffer .= $1;
		my $string_id = StringStore($STRING_CONTEXT, $string_buffer);
		$CODE .= "$string_id " . $CODE_padding;
		$MIX .= "$string_id " . $CODE_padding;

		# consumes the ' if any.
		# needed for example for a literal char like 'a'
		$$TEXT =~ /\G'/gc;
		#print "LITERAL SYMBOL = $string_buffer\n";
		return 0;

	}
	else {
		# literal char
		# following particular cases are to be managed : '\'' and '\\'
		# Below, capture \\\\ to consumme \\.
		#        capture \\' to consume \'
		while ($$TEXT =~ /\G(\\\\|\\'|'|\\|\s|[^\s'\\]+)/gc) {
			$newLines = $blank->($1);
			$CODE_padding .= $newLines;
			$COMMENT .= $newLines;

			$string_buffer .= $1;

			if (($1 eq "'") || ($1 =~ /^\s$/m)) {
				my $string_id = StringStore($STRING_CONTEXT, $string_buffer);
				$CODE .= "$string_id " . $CODE_padding;
				$MIX .= "$string_id " . $CODE_padding;
				#print "LITERAL CHAR = $string_buffer\n";
				return 0;
			}
		}
	}

	print STDERR "malformed literal string : simple quote not followe by a word\n";
	print "--> $string_buffer\n";
	return 1;
}

# TEMPLATE
sub parseTplString($$) {
	my $id = shift;
	my $el = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";

	while ($$TEXT =~ /\G("""(?=[^"])|"|\\\n|\\|\$\{|\$|[^\\"\$]*)/gc) {
		$newLines = $blank->($1);
		$COMMENT .= $newLines;
		$CODE_padding .= $newLines;

		if ($1 eq '"""') {
			$string_buffer .= $1;
			my $string_id = StringStore($STRING_CONTEXT, $string_buffer);
			$CODE .= " $string_id " . $CODE_padding;
			$MIX .= " $string_id " . $CODE_padding;
			#print "TPL STRING = $string_buffer\n";
			return 0;
		}
		elsif (($1 eq '${') && (($id eq "s") || ($id eq "f") || ($id eq "raw"))) {
			$CODE .= $CODE_padding;
			$MIX .= $CODE_padding;
			$string_buffer .= '${...}';
			parseCode($TEXT, {}, 1);
			$CODE_padding = '';
		}
		elsif ($1 ne "\n") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}
	}

	print STDERR "Unterminated string !!!\n";
	print "==> " . substr($string_buffer, 0, 20) . "...\n";
	return 1;
}

sub parseCode($$;$) {
	$TEXT = shift;
	my $options = shift;
	my $stopOnClosingAcco = shift || 0;

	my $err = 0;

	my $level = 1;
	while ($$TEXT =~ /\G(\/\/|\/\*|\/|(\w*)(""")|(\w*)(")|'|\w+|\{|\}|[^"'\/\w\{\}]*)/gc) {

		my $newLines = $blank->($1);

		if (defined $3) {
			$err = parseTplString($2, $3);
		}
		elsif (defined $5) {
			$err = parseDblString($4, $5);
		}
		elsif ($1 eq '//') {
			$err = parseLineComment($1);
		}
		elsif ($1 eq '/*') {
			$err = parseMultilineLineComment($1);
		}
		elsif ($1 eq "'") {
			$err = parseLiteralSymbol($1);
		}
		else {
			$CODE .= $1;
			$COMMENT .= $newLines;
			$MIX .= $1;

			if ($stopOnClosingAcco) {
				if ($1 eq '{') {
					$level++;
				}
				elsif ($1 eq '}') {
					$level--;
					if ($level == 0) {
						# delete last } of ${...} in views
						chop $CODE;
						chop $MIX;
						last;
					}
				}
			}
		}

		if ($err gt 0) {
			return 1;
		}
	}

	return 0;
}

# analyse du fichier
sub StripScala($$$$)
{
	my ($filename, $vue, $options, $couples) = @_;
	my $b_timing_strip = ((defined Timing->isSelectedTiming('Strip')) ? 1 : 0);

	configureLocalTraces('StripScala', $options); # traces_filter_line
	my $StripScalaTiming = new Timing('StripScala', Timing->isSelectedTiming('Strip'));
	$StripScalaTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line


	# Init data
	$CODE = "";
	$COMMENT = "";
	$MIX = "";
	$STRING_CONTEXT = {
		'nb_distinct_strings' => 0,
		'strings_values'      => {},
		'strings_counts'      => {}
	};
	$RT_STRINGS = $STRING_CONTEXT->{'strings_values'};

	# Start stripping ...
	my $err = parseCode(\$vue->{'text'}, $options);

	$StripScalaTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

	$vue->{'comment'} = $COMMENT;
	$vue->{'HString'} = $RT_STRINGS;
	$vue->{'code_with_prepro'} = "";
	$vue->{'MixBloc'} = $MIX;
	$vue->{'agglo'} = "";
	StripUtils::agglomerate_C_Comments(\$MIX, \$vue->{'agglo'});
	$vue->{'MixBloc_LinesIndex'} = StripUtils::createLinesIndex(\$MIX);
	$vue->{'agglo_LinesIndex'} = StripUtils::createLinesIndex(\$vue->{'agglo'});
	$vue->{'MixBloc_NumLinesComment'} = StripUtils::createNumLinesComment(\$MIX);

	if ($err gt 0) {
		my $message = 'Fatal error when separating code/comments/strings';
		Erreurs::LogInternalTraces('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', $message);
		return Erreurs::FatalError(Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
	}

	$vue->{'code'} = $CODE;
	if (defined $options->{'--dumpstrings'}) {
		dumpVueStrings($RT_STRINGS, $STDERR);
	}
	$StripScalaTiming->dump('StripScala') if ($b_timing_strip); # timing_filter_line
	return 0;
}

1; # Le chargement du module est okay.

