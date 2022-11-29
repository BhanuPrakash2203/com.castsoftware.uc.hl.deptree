package StripSwift;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

# prototypes publics
sub StripSwift($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                  dumpVueStrings
                 );

StripUtils::init('StripSwift', 0);

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
	print STDERR "Unterminated comment !! !\n";
	
	return 1;
}

sub parseMultilineLineComment($);
	
sub parseMultilineLineComment($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$CODE .= $newLines;
	$COMMENT .= $el;
	$MIX .= $el;
	my $err;

	while ( $$TEXT =~ /\G(\/\*|\*\/|\*|\/|\n|[^*\/\n]*)/gc) {
		$newLines = $blank->($1);
		if ($1 eq "*/") {
			$CODE .= $blank->($1);
			$COMMENT .= $1;
			$MIX .= $1;
			return 0;
		}
		elsif ($1 eq "/*") {
			$err = parseMultilineLineComment($1);
			if ($err) {
				return 1;
			}
		}
		elsif ($1 eq "\n") {
			$CODE .= $blank->($1);
			$COMMENT .= $1;
			$MIX .= "*/\n/*";
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
#     respectively  \" \"""
#
# Line Continuation :
#     allowed for all

# DOUBLE QUOTE

my %STRING_CLOSING = ('"' => '"', '"""' => '"""', '#"' => '"#', '#"""' => '"""#');

sub parseDblString($;$) {
	my $el = shift;
	my $countExtendedDelimiter = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";
	my $expected_closing = $STRING_CLOSING{$el};

	if (defined $countExtendedDelimiter){
		$expected_closing.= "#" x $countExtendedDelimiter;
	}

	while ( $$TEXT =~ /\G(\\"|""|"#+|"|\\\\|\\\(|\\|\\\n|[^\\"]*)/gc) {
		$newLines = $blank->($1);
		$CODE_padding .= $newLines;
		$COMMENT .= $newLines;
		# $MIX .= $newLines;
		
		if ($1 eq $expected_closing) {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
			return 0;
		}
		elsif ($1 eq '\(')
        {
            # parse_interpolation
            $string_buffer .= parseInterpolation($TEXT);
		}
		elsif ($1 ne "\\\n") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}
	}
	print STDERR "Unterminated string !!!\n";
	return 1;
}

# TEMPLATE
sub parseTplString($;$) {
	my $el = shift;
	my $countExtendedDelimiter = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";
	my $expected_closing = $STRING_CLOSING{$el};

	if (defined $countExtendedDelimiter){
		$expected_closing.= "#" x $countExtendedDelimiter;
	}

	while ( $$TEXT =~ /\G(\\"|"""#+|"""|"|\\\\|\\|\\\n|[^\\"]*)/gc) {
		$newLines = $blank->($1);
		$COMMENT .= $newLines;
		$CODE_padding .= $newLines;
		
		if ($1 eq $expected_closing) {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
			return 0;
		}
		elsif ($1 ne "\\\n") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}
		else {
			# $string_buffer note updated
		}
	}
	print STDERR "Unterminated string !!!\n";
	return 1;
}

# consumes interpolation block into string_buffer
sub parseInterpolation
{
	my $textInput = shift;
    
    my $buff = '${';
    while ($$textInput =~ /\G(\\\(|\)|[^\\\)]+)/gc)
    {
        if ($1 eq ')')
        {
            $buff .= $1;
            return $buff;
        }
        elsif ($1 eq '\(')
        {
            $buff .= parseInterpolation($textInput);
        }
        else
        {
            $buff .= $1;
        }
    }
    
    print STDERR "[parseInterpolation] Missing closing )\n";
    return $buff;
}

sub parseCode($$) {
	$TEXT = shift;
	my $options = shift;
	
	my $err = 0;
	my $countExtendedDelimiter;

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
	
	# while ( $$TEXT =~ /\G(\/[^\/*]|\/\/|\/\*|\/|#"""|"""|"|#"|#+(?!")|#|[^"\/#]*)/gc) {
	while ( $$TEXT =~ /\G(\/[^\/*]|\/\/|\/\*|\/|#"""|"""|"|#"|#(?:if|elseif|else|endif).*|#|[^"\/#]*)/gc) {
		my $pattern = $1;
	    my $newLines = $blank->($pattern);
		if ($pattern eq '//') {
			$err = parseLineComment($pattern);
		}
		elsif ($pattern eq '/*') {
			$err = parseMultilineLineComment($pattern);
		}
		elsif ($pattern eq '"') {
			$err = parseDblString($pattern);
		}
		elsif ($pattern eq '#"') {
			$err = parseDblString($pattern, $countExtendedDelimiter);
		}
		# Directive compilation 
		elsif ($pattern =~ /#(?:if|elseif|else|endif).*/) {
			# count number of delimiters
			$countExtendedDelimiter = () = $pattern =~ /\#/g;
		}
		elsif ($pattern eq '"""') {
			$err = parseTplString($pattern);
		}
		elsif ($pattern eq '#"""') {
			$err = parseTplString($pattern, $countExtendedDelimiter);
		}
		else {
			$CODE .= $pattern;
			$COMMENT .= $newLines;
            $MIX .= $pattern;
		}
		
		if ($err gt 0) {
			return 1;
		}
	}
	
	return  0;
}

# analyse du fichier
sub StripSwift($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);

    configureLocalTraces('StripSwift', $options); # traces_filter_line
    my $StripSwiftTiming = new Timing ('StripSwift', Timing->isSelectedTiming ('Strip'));
    $StripSwiftTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    
    my $err = parseCode(\$vue->{'text'}, $options);
    
    $StripSwiftTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

    $vue->{'comment'} = $COMMENT;
    $vue->{'HString'} = $RT_STRINGS;
    $vue->{'code_with_prepro'} = "";
    $vue->{'MixBloc'} = $MIX;
    $vue->{'agglo'} = "";                       
    StripUtils::agglomerate_C_Comments(\$MIX, \$vue->{'agglo'});
    $vue->{'MixBloc_LinesIndex'} = StripUtils::createLinesIndex(\$MIX);
    $vue->{'MixBloc_NumLinesComment'} = StripUtils::createNumLinesComment(\$MIX);
    $vue->{'agglo_LinesIndex'} = StripUtils::createLinesIndex(\$vue->{'agglo'});

    if ( $err gt 0) {
      my $message = 'Fatal error when separating code/comments/strings';
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', $message);
      return Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    }
    
    $vue->{'code'} = $CODE;
    if ( defined $options->{'--dumpstrings'})
    {
      dumpVueStrings(  $RT_STRINGS , $STDERR );
    }
    $StripSwiftTiming->dump('StripSwift') if ($b_timing_strip); # timing_filter_line
    return 0;
}

1; # Le chargement du module est okay.

