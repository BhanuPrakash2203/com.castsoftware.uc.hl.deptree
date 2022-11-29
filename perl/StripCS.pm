package StripCS;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;
use CS::Prepro;
# prototypes publics
sub StripCS($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                  dumpVueStrings
                 );

StripUtils::init('StripCS', 0);

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
	my $spaces = $blank->($el);
	$CODE .= $spaces;
	$COMMENT .= $el;
	$MIX .= '/*';
	
	while ( $$TEXT =~ /\G(\n|[^\n]*)/gc) {
		$spaces = $blank->($1);
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


sub parseCompilDir($) {
	my $el = shift;
	my $spaces = $blank->($el);
	$CODE .= $spaces;
	$COMMENT .= $el;
	$MIX .= "";
	
	while ( $$TEXT =~ /\G(\n|[^\n]*)/gc) {
		$spaces = $blank->($1);
		if ($1 eq "\n") {
			$CODE .= "\n";
			$COMMENT .= "\n";
			$MIX .= "\n";
			return 0;
		}
		else {
			my $blanked = $blank->($1);
			$CODE .= $1;
			$COMMENT .= $blanked;
			$MIX .= $1;
		}
	}
	print STDERR "Unterminated compil directive !! !\n";
	
	return 1;
}

sub parseMultilineLineComment($) {
	my $el = shift;
	my $spaces = $blank->($el);
	$CODE .= $spaces;
	$COMMENT .= $el;
	$MIX .= $el;
	
	while ( $$TEXT =~ /\G(\n|\*\/|\*|[^*\n]*)/gc) {
		$spaces = $blank->($1);
		if ($1 eq '*/') {
			$CODE .= $blank->($1);
			$COMMENT .= $1;
			$MIX .= $1;
			return 0;
		}
		elsif ($1 eq "\n") {
			$CODE .= "\n";
			$COMMENT .= "\n";
			$MIX .= "*/\n";
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

# DOUBLE QUOTE
sub parseDblString($) {
	my $el = shift;
	my $spaces = $blank->($el);
	$COMMENT .= $spaces;
	$MIX .= $spaces;
	my $string_buffer = $1;
	my $CODE_padding = "";
	
	while ( $$TEXT =~ /\G(\\"|\"\"|"|\\\\|\\|\\\n|[^\\"]*)/gc) {
		$spaces = $blank->($1);
		$CODE_padding .= $spaces;
		$COMMENT .= $spaces;
		# $MIX .= $spaces;
		
		if ($1 eq '"') {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= "$string_id".$CODE_padding;
			$MIX .= "$string_id".$CODE_padding;
			return 0;
		}
		else {
			$string_buffer .= $1;
		}
	}
	print STDERR "Unterminated double string !!!\n";
#print STDERR "$string_buffer\n";
	return 1;
}

# SIMPLE QUOTE
sub parseLiteralChar() {
	my $spaces = " ";
	$COMMENT .= $spaces;
	$MIX .= $spaces;
	my $string_buffer = "'";
	my $CODE_padding = "";
	
	while ( $$TEXT =~ /\G((?:\\\\)+|\\'|\\|'|[^\\']*)/gc) {
		$spaces = $blank->($1);
		$CODE_padding .= $spaces;
		$COMMENT .= $spaces;
		# $MIX .= $spaces;
		
		if ($1 eq "'") {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= "$string_id".$CODE_padding;
			$MIX .= "$string_id".$CODE_padding;
#print STDERR "SIMPLE STRING : $string_buffer\n";
			return 0;
		}
		else {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}
	}
	print STDERR "Unterminated simple string !!!\n";
#print STDERR "$string_buffer\n";
	return 1;
}

# verbatim string (multiline) @" ... "    ( "" is the only special pattern )
# interpolated string $" ... "            ( {{ , }} and \[^{}] are the only special pattern )
#                 both  @$" .... "        ( {{ , }} and "" are the only special pattern )
sub parseTplString($) {
	my $openning = shift;
	
	my $verbatim = 0;
	my $interpolated = 0;
	
	if ($openning =~ /\@/) {
		$verbatim = 1;
	}
	if ($openning =~ /\$/) {
		$interpolated = 1;
	}
	
	# flags : verbatim, interpolated
	# special patterns :
	#     " => end of string
	#    "" => do nothing in both cases
	#    \" => end of string if verbatim ON
	#    <new line> => consider a neaw line in padding
	
	my $spaces = $blank->($openning);
	$COMMENT .= $spaces;
	my $string_buffer = $openning;
	my $CODE_padding = "";
    
	while ( $$TEXT =~ /\G(\\"|""|"|\\\\|\\|\n|[^"\n\\]+)/gc) {

		$spaces = $blank->($1);
		$COMMENT .= $spaces;
		
		if (($1 eq '"' ) || ($verbatim && (($1 eq '\"' )))){
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= "$string_id".$CODE_padding;
			$MIX .= "$string_id".$CODE_padding;
#print STDERR "TEMPLATE STRING $string_buffer\n";
			return 0;
		}
		elsif ($1 eq "\n") {
			$string_buffer .= $1;
			$CODE_padding .= "\n";
		}
		else {
			$string_buffer .= $1;
		}
	}
	print STDERR "Unterminated template string !!!\n";
#print STDERR $string_buffer."\n";
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
	
    while ( $$TEXT =~ 
        /\G
        (   
            \/\/
            |\/\*
            |\/
            |"
            |'
            |([\@\$]+")
            |\$
            |\@
            #|\n[ \t]*(\#)
            |\n
            |[^"'\$\@\n\/]*
         )/xgc
     ) {
        my $spaces = $blank->($1);
    
        my $code_fragment = $1;

		if ($1 eq '//') {
			$err = parseLineComment($1);
		}
		elsif ($1 eq '/*') {
			$err = parseMultilineLineComment($1);
		}
		elsif ($1 eq '"') {
			$err = parseDblString($1);
		}
		elsif ($1 eq "'") {
			$err = parseLiteralChar();
		}
        elsif (defined $2) {
			$err = parseTplString($2);
		}
		#elsif (defined $3) {
		#	$err = parseCompilDir($1);
		#}
		else {
			$CODE .= $1;
			$COMMENT .= $spaces;
            $MIX .= $1;
		}
		
		if ($err gt 0) {
#print "PARSE CODE KO !!!\n";
#print $CODE."\n";
			return 1;
		}
	}

	return  0;
}

# analyse du fichier
sub StripCS($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);

    configureLocalTraces('StripCS', $options); # traces_filter_line
    my $stripCSTiming = new Timing ('StripCS', Timing->isSelectedTiming ('Strip'));
    $stripCSTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    
    my $err = parseCode(\$vue->{'text'}, $options);
    
    $stripCSTiming->markTimeAndPrint('StripCS') if ($b_timing_strip); # timing_filter_line

    $vue->{'comment'} = $COMMENT;
    $vue->{'HString'} = $RT_STRINGS;
    $vue->{'code_with_prepro'} = "";
    $vue->{'MixBloc'} = $MIX;
    $vue->{'agglo'} = "";                       
    StripUtils::agglomerate_C_Comments(\$MIX, \$vue->{'agglo'});
    $vue->{'MixBloc_LinesIndex'} = StripUtils::createLinesIndex(\$MIX);
    $vue->{'agglo_LinesIndex'} = StripUtils::createLinesIndex(\$vue->{'agglo'});

    if ( $err gt 0) {
      my $message = 'Fatal error when separating code/comments/strings';
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', $message);
      return Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    }
    $vue->{'code_with_prepro'} = $CODE;
    $vue->{'code'} = $CODE;
    if ( defined $options->{'--dumpstrings'})
    {
      dumpVueStrings(  $RT_STRINGS , $STDERR );
    }
    
    # create the preprocessed view.
    CS::Prepro::preprocesse($vue);
    
    # FIXME : view code forced to preprocessed view !!!
    $vue->{'code'} = $vue->{'prepro'};
    
    $stripCSTiming->dump('StripCS') if ($b_timing_strip); # timing_filter_line
    return 0;
}

1; # Le chargement du module est okay.

