package StripKotlin;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;
use AnaUtils;

# prototypes publics
sub StripKotlin($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                  dumpVueStrings
                 );

StripUtils::init('StripKotlin', 0);

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


sub parseExclamationMarkBalise($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$CODE .= $newLines;
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	
	return 0 if $el eq "<!>";
	
	while ($$TEXT =~ /\G(!>|!|[^!]+)/sgc) {
		if ($1 eq "!>") {
			my $newLines = $blank->($1);
			$CODE .= $newLines;
			$COMMENT .= $newLines;
			$MIX .= $newLines;
			return 0;
		}
		else {
			my $newLines = $blank->($1);
			$CODE .= $newLines;
			$COMMENT .= $newLines;
			$MIX .= $newLines;
		}
	}
	return 1;
}


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
	Lib::Log::ERROR("Unterminated comment !! !");
	
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
	Lib::Log::ERROR("Unterminated multiline comment !!!");
	return 1;
}

sub parseCharacter($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";
	
	while ( $$TEXT =~ /\G(\\\\|\\[^\\]|'|[^\\']*)/gc) {
		$newLines = $blank->($1);
		$COMMENT .= $newLines;
		# $MIX .= $newLines;
		
		if ($1 eq "'") {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= "$string_id";
			$MIX .= "$string_id";
			return 0;
		}
		else {
			$string_buffer .= $1;
		}
	}

	Lib::Log::ERROR("Unterminated character !!");
	return 1;
}


sub parseInterpolateString() {
	my $content = "";
	my $newLines;
	my $level = 1;
	while ( $$TEXT =~ /\G(\}|\{|[^\{\}]*)/gc) {
		$newLines = $blank->($1);
		$COMMENT .= $newLines;
		$content .= $1;
		if ($1 eq "{") {
			$level++;
		}
		elsif ($1 eq "}") {
			$level--;
			last if ($level == 0);
		}
	}
	return $content;
}

my %STRING_CLOSING = ('"' => '"', '"""' => '"""', '#"' => '"#', '#"""' => '"""#');

sub parseDblString($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";
	my $expected_closing = $STRING_CLOSING{$el};
	
	while ( $$TEXT =~ /\G(\\"|""|"#|"|\\\\|\\|\\\n|\$\{|\$|[^\\"\$]*)/gc) {
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
		elsif ($1 eq "\$\{") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
			$string_buffer .= parseInterpolateString();
		}
		elsif ($1 ne "\\\n") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}
	}
	Lib::Log::ERROR("Unterminated string !!!");
	return 1;
}

# TEMPLATE
sub parseTplString($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";
	my $expected_closing = $STRING_CLOSING{$el};

	while ( $$TEXT =~ /\G(\\"|"""#|"""|"|\\\\|\\|\\\n|[^\\"]*)/gc) {
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
	Lib::Log::ERROR("Unterminated string !!!");
	return 1;
}

sub parseBackTick($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = "___";
	my $CODE_padding = "";
	
	while ( $$TEXT =~ /\G(`|[^`]*)/gc) {
		$newLines = $blank->($1);
		$COMMENT .= $newLines;
		# $MIX .= $newLines;
		
		if ($1 eq '`') {
			$string_buffer .= "___";
			$CODE .= "$string_buffer";
			$MIX .= "$string_buffer";
			return 0;
		}
		else {
			$string_buffer .= $1;
		}
	}
	Lib::Log::ERROR("Unterminated backtick !!!");
	return 1;
}

sub parseCode($$) {
	$TEXT = shift;
	my $options = shift;
	
	my $err = 0;
	
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
	
	while ( $$TEXT =~ /\G(\/[^\/*]|\/\/|\/\*|\/|"""|"|#"""|#"|#|'|`|<!>|<!|<|[^"'\/#`<]*)/gc) {

	    my $newLines = $blank->($1);
		if ($1 eq '//') {
			$err = parseLineComment($1);
		}
		elsif ($1 eq '/*') {
			$err = parseMultilineLineComment($1);
		}
		elsif ($1 eq "'") {
			$err = parseCharacter($1);
		}
		elsif ($1 eq '"') {
			$err = parseDblString($1);
		}
		elsif ($1 eq '#"') {
			$err = parseDblString($1);
		}
		elsif ($1 eq '"""') {
			$err = parseTplString($1);
		}
		elsif ($1 eq '#"""') {
			$err = parseTplString($1);
		}
		elsif ($1 eq '`') {
			$err = parseBackTick($1);
		}
		elsif ($1 eq '<!') {
			$err = parseExclamationMarkBalise($1);
		}
		elsif ($1 eq '<!>') {
			$err = parseExclamationMarkBalise($1);
		}
		else {
			$CODE .= $1;
			$COMMENT .= $newLines;
            $MIX .= $1;
		}
		
		if ($err gt 0) {
			return 1;
		}
	}
	
	return  0;
}

sub removeExclamationMarkBalises($) {
	my $code = shift;
	my $expect_ExclamationMarkBalises = 0;
	while ($$code =~ /\G(<!|<|[^<]+)/sgc) {
		if ($1 eq "<!") {
			my $begin_1 = pos($$code)-2;
			while ($$code =~ /\G(!>|!|[^!]+)/sgc) {
				if ($1 eq "!>") {
					
					$expect_ExclamationMarkBalises=1;
					
					my $end_1 = pos($$code)-2;
					while ($$code =~ /\G(<!>|<|[^<]+)/sgc) {
						if ($1 eq "<!>") {
							$expect_ExclamationMarkBalises=0;
							my $end_2 = pos($$code);
							my $length = $end_1 - $begin_1 + 2;  # +2 is to add the lentgh of "!>"
							substr($$code, $begin_1, $length) = " "x$length;
							substr($$code, $end_2-3, 3) = "   ";
							pos($$code) = $end_2;
							last;
						}
					}
					last;
				}
			}
		}
	}
	if ($expect_ExclamationMarkBalises) {
		Lib::Log::ERROR("ERROR when removing exclamation mark balises !!");
	}
#print "$$code\n";
#exit;
	pos($$code)=undef;
}

# analyse du fichier
sub StripKotlin($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);

    configureLocalTraces('StripKotlin', $options); # traces_filter_line
    my $StripKotlinTiming = new Timing ('StripKotlin', Timing->isSelectedTiming ('Strip'));
    $StripKotlinTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    
    #removeExclamationMarkBalises(\$vue->{'text'});
    
    my $err = parseCode(\$vue->{'text'}, $options);
    
    $StripKotlinTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

    $vue->{'comment'} = $COMMENT;
    $vue->{'code'} = $CODE;
    $vue->{'HString'} = $RT_STRINGS;
    $vue->{'code_with_prepro'} = "";
    $vue->{'MixBloc'} = $MIX;
    $vue->{'agglo'} = "";                       
    StripUtils::agglomerate_C_Comments(\$MIX, \$vue->{'agglo'});
    $vue->{'MixBloc_LinesIndex'} = StripUtils::createLinesIndex(\$MIX);
    $vue->{'agglo_LinesIndex'} = StripUtils::createLinesIndex(\$vue->{'agglo'});

	if (($filename ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'}) # dumpvues_filter_line
	{                                                                            # dumpvues_filter_line
		Vues::dump_vues( $filename, $vue, $options);                                # dumpvues_filter_line
	}

    if ( $err gt 0) {
      my $message = 'Fatal error when separating code/comments/strings';
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', $message);
      return Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    }
    
    if ( defined $options->{'--dumpstrings'})
    {
      dumpVueStrings(  $RT_STRINGS , $STDERR );
    }
    $StripKotlinTiming->dump('StripKotlin') if ($b_timing_strip); # timing_filter_line
    return 0;
}

1; # Le chargement du module est okay.

