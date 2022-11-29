package StripGroovy;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

# prototypes publics
sub StripGroovy($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                  dumpVueStrings
                 );

StripUtils::init('StripGroovy', 0);

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

sub parseMultilineLineComment($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$CODE .= $newLines;
	$COMMENT .= $el;
	$MIX .= $el;
	
	while ( $$TEXT =~ /\G(\*\/|\*|[^*]*)/gc) {
		$newLines = $blank->($1);
		if ($1 eq '*/') {
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

# STRINGS FEATURES
#-----------------
# kinds: 
#  -  Simple quote string  ''
#  -  Double quote string  ""
#  -  Template string      """ ... """
#                      or  ''' ... '''
#                      or   / ... ​/   Slashy string
#                      or  $/ ... ​/$  Dollar slashy string
#
# Escape :
#     respectively \' \" 
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
	
	while ( $$TEXT =~ /\G(\\"|\"\"|"|\\\$|\$\{|\$|\\\\|\\|\\\n|[^\\"\$]*)/gc) {
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
        elsif ($1 eq '${')
        {
            # parse_interpolation
            $string_buffer .= parseInterpolation($TEXT);
        }
		elsif ($1 ne "\\\n") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}
	}
	print STDERR "Unterminated double string !!!\n";
#print STDERR "$string_buffer\n";
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
#print STDERR "SIMPLE STRING : $string_buffer\n";
			return 0;
		}
		elsif ($1 ne "\\\n") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}
	}
	print STDERR "Unterminated simple string !!!\n";
#print STDERR "$string_buffer\n";
	return 1;
}

# TEMPLATE
sub parseTplString($;$) {
	my $openingSymbol = shift;
	my $prefixSlashy = shift;
	my $newLines = $blank->($openingSymbol);
	$COMMENT .= $newLines;
	my $string_buffer = $openingSymbol;
	my $CODE_padding = "";
	    
    if ($prefixSlashy)  # Slashy string
    {
        my $beginSlashy = $openingSymbol;
        if ($beginSlashy =~ /($prefixSlashy\s*)(\/)/)
        {
            $openingSymbol = '/';
            $string_buffer = $2;
            $CODE .= $1;
            $MIX .= $1;
        }
    
    }
    
    my $interpolationAllowed = 1;
    if ($openingSymbol eq "'''") {
		$interpolationAllowed = 0;
	}
    
	while ( $$TEXT =~ /\G(\\"|"""|"|\\'|'''|'|\\\$|\$\{||\/\$\$|\/\$|\/|\\\\|\\|\n|\\\n|[^"'\n\/\\]+)/gc) {

		$newLines = $blank->($1);
		$COMMENT .= $newLines;
		$CODE_padding .= $newLines;
		
		if ($1 eq '"""' and $openingSymbol eq '"""') {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
#print STDERR "TEMPLATE STRING $string_buffer\n";
			return 0;
		}		
        elsif ($1 eq "'''" and $openingSymbol eq "'''") {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
#print STDERR "TEMPLATE STRING $string_buffer\n";
			return 0;
		}        
        elsif ($1 eq '/$' and $openingSymbol eq '$/') {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
#print STDERR "TEMPLATE STRING $string_buffer\n";
			return 0;
		}        
        elsif ($1 eq '/' and $openingSymbol eq '/') {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
#print STDERR "TEMPLATE STRING $string_buffer\n";
            return 0;
		}
		elsif ($1 eq '${')
        {
            # parse_interpolation
            if ($interpolationAllowed) {
				$string_buffer .= parseInterpolation($TEXT);
			}
			else {
				$string_buffer .= $1;
			}
        }
		elsif ($1 eq "\n") {
			$string_buffer .= $1;
		}
		elsif ($1 ne "\\\n") {
			# not a continuing line => update $string_buffer
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
    
    my $prefixRegex =  qr /\s*\~|\s*\(|\s*:/;
    my $prefixSlashy =  qr /\=|\[|\,/;
	
    while ( $$TEXT =~ 
        /\G
        (   
            (($prefixRegex\s*)\/[^\/*])
            |\/\/
            |\/\*
            |($prefixSlashy\s*\/(?!\/))  #slashy strings
            |\/
            |"""
            |"
            |'''
            |'
            |`
            |\$\/
            |\$
            |=
            |~
            |\[
            |\,
            |\(
            |:
            |[^"'\/`\$=\[~\(\,:]*)/xgc
        ) 
    {

        my $newLines = $blank->($1);
    
        my $code_fragment = $1;
        my $simpleRegexBegin = $2;
        my $prefixLineRegex = $3;

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
        elsif ($1 eq '$/') {
			$err = parseTplString($1);
		}
        elsif (defined $prefixLineRegex)
        {
            if (defined $simpleRegexBegin) # regex /.../
            {
                $CODE .= $prefixLineRegex;
                $MIX .= $prefixLineRegex;

                $err = parseRegExp('/',$TEXT, $simpleRegexBegin);
            }
        }
        elsif (defined $4) {
			$err = parseTplString($1, $prefixSlashy);
		}
		else {
			$CODE .= $1;
			$COMMENT .= $newLines;
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

sub parseRegExp($$$) 
{
    my $open = shift;
    my $textInput = shift;
    my $begin = shift;
    
    my $regexp = $begin;

    #$CODE .= $open;
    #$MIX .= $open;
    
    #my $position = pos ($$textInput);
    
    my $lines_padding = "";

    while ($$textInput =~ /\G(\\\\|\\.|\/\/\/|\/|\n|[^\\\/\n]+)/gc)
    {
        if ( ($open eq '/') and ($1 eq '/') )
        {
            #$CODE .= $1;
            #$MIX .= $1;
            $regexp .= $1;
            # print 'Regexp detected <'.$regexp.">\n";
            
            $CODE .= "REGEXP".$lines_padding;
            $MIX .= "REGEXP".$lines_padding;
#print STDERR "REGEXP $regexp\n";
            return 0;
        }
        
        else
        {
            #$CODE .= $1;
            #$MIX .= $1;
            $regexp .= $1;
            if ($1 eq "\n") {
				$lines_padding .= " ";
			}
       }
    }
    
    print STDERR "[parseRegExp] Missing closing \/\n";
    return 1;
}

# consumes interpolation block into string_buffer
sub parseInterpolation
{
	my $textInput = shift;
    
    my $buff = '${';
    while ($$textInput =~ /\G(\}|\$\{|\$|[^}\$]+)/gc)
    {
        if ($1 eq '}')
        {
            $buff .= $1;
            return $buff;
        }
        elsif ($1 eq '${')
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

# analyse du fichier
sub StripGroovy($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);

    configureLocalTraces('StripGroovy', $options); # traces_filter_line
    my $stripGroovyTiming = new Timing ('StripGroovy', Timing->isSelectedTiming ('Strip'));
    $stripGroovyTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    
    my $err = parseCode(\$vue->{'text'}, $options);
    
    $stripGroovyTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

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
    $stripGroovyTiming->dump('StripGroovy') if ($b_timing_strip); # timing_filter_line
    return 0;
}

1; # Le chargement du module est okay.

