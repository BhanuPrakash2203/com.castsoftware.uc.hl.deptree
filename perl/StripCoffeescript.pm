package StripCoffeescript;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

# prototypes publics
sub StripCoffeescript($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                  dumpVueStrings
                 );

StripUtils::init('StripCoffeescript', 0);

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
#   - Simple line : # ..... \n
#   - Multiline   : /* ..... */
#   - Multiline   : ### ..... ###
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

sub parseMultilineLineComment($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$CODE .= $newLines;
	$COMMENT .= $el;
	$MIX .= $el;
    
	while ( $$TEXT =~ /\G(\*\/|\*|###|#|[^*#]*)/gc) {
    $newLines = $blank->($1);
		if ($1 eq "*/") 
        {
			$CODE .= $blank->($1);
			$COMMENT .= $1;
			$MIX .= $1;
			return 0;
		}
        elsif ($1 eq "###") 
        {
			$CODE .= $blank->($1);
			$COMMENT .= $1;
			$MIX .= $1;
			return 0;
		}
		else 
        {
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
#  -  Simple quote string  ''
#  -  Double quote string  ""
#  -  Template string      ``
#                  or  """ """
#                  or  ''' '''
#
# Escape :
#     respectively \' \" \`
#
# Line Continuation :
#     allowed for all

# DOUBLE QUOTE
sub parseDblString($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";
	
    while ( $$TEXT =~ /\G(\\"|\"\"|"|\\\\|\\|#\{|#|\\\n|[^\\"#]*)/gc) {
		$newLines = $blank->($1);
		$CODE_padding .= $newLines;
		$COMMENT .= $newLines;
		# $MIX .= $newLines;
		
		if ($1 eq '"') {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
			return 0;
		}
        elsif ($1 eq '#{')
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

# SIMPLE QUOTE
sub parseSplString($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";
	
	while ( $$TEXT =~ /\G(\\'|\'\'|'|\\\\|\\|\\\n|[^\\']*)/gc) {
		$newLines = $blank->($1);
		$CODE_padding .= $newLines;
		$COMMENT .= $newLines;
		# $MIX .= $newLines;
		
		if ($1 eq "'") {
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
	}
	print STDERR "Unterminated string !!!\n";
	return 1;
}

# TEMPLATE
sub parseTplString($) {
	my $openingSymbol = shift;
	my $newLines = $blank->($openingSymbol);
	$COMMENT .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";

	while ( $$TEXT =~ /\G(\\`|\`\`|`|'''|'|"""|"|#\{|#|\\|\\\n|\\n|[^\\`"'#]*)/gc) {
		$newLines = $blank->($1);
		$COMMENT .= $newLines;
		$CODE_padding .= $newLines;
		
		if ($1 eq "`") {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
			return 0;
		}
        elsif ($1 eq '#{')
        {
            # parse_interpolation
            $string_buffer .= parseInterpolation($TEXT);
        }
        elsif ($1 eq '"""' and $openingSymbol ne "'''") {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
			return 0;
		}        
        elsif ($1 eq "'''" and $openingSymbol ne '"""') {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
			return 0;
		}
		elsif ($1 eq "\n") {
			$string_buffer .= $1;
		}
		elsif ($1 ne "\\\n") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}
	}
	print STDERR "Unterminated string !!!\n";
	return 1;
}

sub parseCode($$;$) {
	$TEXT = shift;
	my $options = shift;
	my $fileExtension = shift;
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
    
    # consumes comment if needed
    if ($fileExtension eq '.litcoffee')
    {
        parseLitCoffee($TEXT);
        $MIX .= "\n";
        $COMMENT .= "\n";
    }    

    my $prefixRegex =  qr /\,|\!|\=|\(|\+|\s*eq\s*|\s*replace\s*|\s*split\s*|\s*when\s*|\s*if\s*|\s*match\s*|\s*compile\s*\'\s*|\s*ok\s*/;
    
	while ( $$TEXT =~ 
        /\G
        (
            (($prefixRegex)\s*\/\/\/)
            |(($prefixRegex)\s*\/)
            |\/\/\/
            |\/
            |\,
            |\!
            |\=
            |\(
            |\+
            |eq
            |replace
            |split
            |when
            |if
            |match
            |compile
            |ok
            |e
            |r
            |s
            |w
            |i
            |m
            |c
            |o
            |\#\#\#
            |\#
            |"""
            |"
            |'''
            |'
            |`
            |\n
            |[^"'`\#\/\n\,\!\=\(\+erswimco]+
        )
        /xgc) 
    {
        my $newLines = $blank->($1);
        
        my $code_fragment = $1;
        my $multilineRegexBegin = $2;
        my $prefixMultilineRegex = $3;
        my $simpleRegexBegin = $4;
        my $prefixLineRegex = $5;
        
        # print "code_fragment: <" . $code_fragment.">\n";
        # print "multilineRegexBegin: " . $multilineRegexBegin."\n";
        # print "prefixMultilineRegex: " . $prefixMultilineRegex."\n";
        # print "simpleRegexBegin: " . $simpleRegexBegin."\n";
        # print "prefixLineRegex: " . $prefixLineRegex."\n";
        
		if ($1 eq '#') {
			$err = parseLineComment($1);
		}
		elsif ($1 eq '/*') {
			$err = parseMultilineLineComment($1);
		}		
        elsif ($1 eq '###') {
			$err = parseMultilineLineComment($1);
		}
        elsif (defined $prefixMultilineRegex or defined $prefixLineRegex)
        {
            if (defined $multilineRegexBegin) # regex multiline /// ...///
            {
                $CODE .= $multilineRegexBegin;
                $MIX .= $multilineRegexBegin;

                $err = parseRegExp('///',$TEXT);
            }
            else # regex simple line /.../
            {
                $CODE .= $simpleRegexBegin;
                $MIX .= $simpleRegexBegin;

                $err = parseRegExp('/',$TEXT) if defined $simpleRegexBegin;
            }
		}          
		elsif ($1 eq '"') {
			$err = parseDblString($1);
		}
		elsif ($1 eq "'") {
			$err = parseSplString($1);
		}
		elsif ($1 eq "`") {
			$err = parseTplString($1);
		}		
        elsif ($1 eq '"""') {
			$err = parseTplString($1);
		}        
        elsif ($1 eq "'''") {
			$err = parseTplString($1);
		}
        elsif ($1 eq "\n") {

            # step $MIX .= $1 must be placed before parseLitCoffee !!
            $MIX .= $1;
            
            # consumes comment if needed
			if ($fileExtension eq '.litcoffee')
            {
                parseLitCoffee($TEXT);
            }
            
            $CODE .= $1;
			$COMMENT .= $1;
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

# consumes interpolation block into string_buffer
sub parseInterpolation
{
	my $textInput = shift;
    
    my $buff = '${';
    while ($$textInput =~ /\G(\}|#\{|#|[^}#]+)/gc)
    {
        if ($1 eq '}')
        {
            $buff .= $1;
            return $buff;
        }
        elsif ($1 eq '#{')
        {
            $buff .= parseInterpolation($textInput);
        }
        else
        {
            $buff .= $1;
        }
    }
    
    print STDERR "[parseInterpolation] Missing closing }\n";
    return $buff;
}

sub parseRegExp($$) 
{
    my $open = shift;
    my $textInput = shift;
    my $regexp = $open;
    $CODE .= $open;
    $MIX .= $open;
    
    #my $position = pos ($$textInput);

    while ($$textInput =~ /\G(\/\/\/|\/|\n|[^\/\n]+)/gc)
    {
        if 
        (
            ($open eq '/' and $1 eq '/') 
            or ($open eq '///' and $1 eq '///')
        )
        {
            $CODE .= $1;
            $MIX .= $1;
            $regexp .= $1;
            # print 'Regexp detected <'.$regexp.">\n";
            return 0;
        }
        
        else
        {
            $CODE .= $1;
            $MIX .= $1;
            $regexp .= $1;
       }
    }
    
    print STDERR "[parseRegExp] Missing closing \/ or \/\/\/\n";
    return 1;
}

# analyse du fichier
sub StripCoffeescript($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);

    configureLocalTraces('StripCoffeescript', $options); # traces_filter_line
    my $stripCoffeescriptTiming = new Timing ('StripCoffeescript', Timing->isSelectedTiming ('Strip'));
    $stripCoffeescriptTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    
    my $fileExtension;
    if ($filename =~ /(\.[0-9a-z]+)$/mi)
    {
        $fileExtension = lc($1);
    }
    
    my $err = parseCode(\$vue->{'text'}, $options, $fileExtension);
    
    $stripCoffeescriptTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

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
    
    $vue->{'code'} = $CODE;
    if ( defined $options->{'--dumpstrings'})
    {
      dumpVueStrings(  $RT_STRINGS , $STDERR );
    }
    $stripCoffeescriptTiming->dump('StripCoffeescript') if ($b_timing_strip); # timing_filter_line
    return 0;
}


sub parseLitCoffee($)
{
    my $textInput = shift;
    
    if ($$textInput =~ /\G([^\s\t][^\n]*)/gc)
    {
        $MIX .= '/*';
        $MIX .= $1;
        $MIX .= '*/';
        $COMMENT .= $1;
    }
    
}

1; # Le chargement du module est okay.

