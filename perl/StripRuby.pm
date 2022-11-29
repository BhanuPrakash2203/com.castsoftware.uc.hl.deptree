package StripRuby;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

# prototypes publics
sub StripRuby($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                  dumpVueStrings
                 );

StripUtils::init('StripRuby', 0);

#-----------------------------------------------------------------------

my $blank = \&garde_newlines;

my $TEXT;
my $CODE="";
my $COMMENT = "";
my $MIX = "";
my $DATA = "";

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
#   - Multiline   : =begin ..... =end

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
	
	while ( $$TEXT =~ /\G(=end|\=|[^=]*)/gc) {
		$newLines = $blank->($1);
		if ($1 eq '=end') {
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
#  -  Template string      %{  }
#                     or   '   '\   
#                     or   "   "\   
#                     or   <<-TEXT TEXT   
#                     or   `   ` 
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
	
	while ( $$TEXT =~ /\G(\\"|\"\"|"|\\#|#\{|#|\\\\|\\|\\\n|[^\\"#]*)/gc) {
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
	print STDERR "Unterminated string for sub parseDblString !!!\n";
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
	print STDERR "Unterminated string for sub parseSplString !!!\n";
	return 1;
}

# TEMPLATE
sub parseTplString($;$) {
	my $openingSymbol = shift;
    my $heredocsPattern = shift;

    my $newLines = $blank->($openingSymbol);
	$COMMENT .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";
    
    my $firstLetterHeredocsPattern;
    
    if ($heredocsPattern and $heredocsPattern =~ /^(\w)/)
    {   
        $string_buffer = $openingSymbol;
        $firstLetterHeredocsPattern = $1;
    }

    my $regexp_TplString;
    if ($heredocsPattern)
    {
        $regexp_TplString = qr /\G((<<(?:[\-'"]?)([a-zA-Z_]+))|<|\\\\|\\|\\#|#\{|#|(?<=\n|\s)$heredocsPattern\b|$firstLetterHeredocsPattern|\n|\\\n|[^$firstLetterHeredocsPattern\<#]*)/;
    }
    else 
    {
        $regexp_TplString = qr /\G(\\}|}|\\'|'|\\"|"|\\`|`|\\#|#\{|#|\n|\\\n|[^}\n'"`#]*)/;
    }
    
    my %hash_hereDocsPattern;
    
	while ( $$TEXT =~ /$regexp_TplString/gc) {
    
		$newLines = $blank->($1);
		$COMMENT .= $newLines;
		$CODE_padding .= $newLines;
             
		if ($1 eq '}' and $openingSymbol eq '%{') {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
			return 0;
		}
        elsif ($1 eq "'" and $openingSymbol eq "'") {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
			return 0;
		}
        elsif ($1 eq '"' and $openingSymbol eq '"') {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
			return 0;
		}        
        elsif ($1 eq '`' and $openingSymbol eq '`') {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
			return 0;
		}
        elsif (defined $2 and defined $3) {
			$string_buffer .= $2;
			$heredocsPattern = $3;
            if ($heredocsPattern and $heredocsPattern =~ /^(\w)/)
            {   
                $string_buffer = $openingSymbol;
                $firstLetterHeredocsPattern = $1;
            }
            
            # print 'discovering new pattern ' . $heredocsPattern."\n";
            $regexp_TplString = qr /\G((<<(?:[\-'"]?)([a-zA-Z_]+))|<|(?<=\n|\s)$heredocsPattern\b|$firstLetterHeredocsPattern|\n|\\\n|[^$firstLetterHeredocsPattern\<]*)/;

		}        
        elsif ($heredocsPattern and $1 eq $heredocsPattern) {
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
		elsif ($1 eq "\n") {
			$string_buffer .= $1;
		}
		elsif ($1 ne "\\\n") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}

	}
	print STDERR "Unterminated string for sub parseTplString !!!\n";
	return 1;
}

# INTERPOLATED STRING
sub parseInterpolatedString($) {

	my $openingSymbol = shift;
	my $newLines = $blank->($openingSymbol);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";
	
    my $closingSymbol;
    $closingSymbol = '/' if ($openingSymbol eq '/');
    $closingSymbol = '-' if ($openingSymbol eq '-');
    $closingSymbol = '}' if ($openingSymbol eq '{');
    $closingSymbol = ')' if ($openingSymbol eq '(');
    $closingSymbol = ']' if ($openingSymbol eq '[');
    $closingSymbol = '"' if ($openingSymbol eq '"');
    $closingSymbol = '>' if ($openingSymbol eq '<');

    my $matchClosingSymbol = "\\".$closingSymbol;
    my $matchOpeningSymbol = "\\".$openingSymbol;
    my $matchOpeningEscapedSymbol = "\\\\\\".$openingSymbol;
    my $matchClosingEscapedSymbol = "\\\\\\".$closingSymbol;
    # print 'openingSymbol=<'.$openingSymbol.">\n";
    # print 'closingSymbol=<'.$closingSymbol.">\n";
    # print 'matchOpeningSymbol='.$matchOpeningSymbol."\n";
    # print 'matchClosingSymbol='.$matchClosingSymbol."\n";
    # print 'matchOpeningEscapedSymbol='.$matchOpeningEscapedSymbol."\n";
    # print 'matchClosingEscapedSymbol='.$matchClosingEscapedSymbol."\n";
    
    my $countSymbol = 0;
    
	while ( $$TEXT =~ /
    \G
        (
        $matchOpeningEscapedSymbol
        |$matchClosingEscapedSymbol
        |$matchOpeningSymbol
        |$matchClosingSymbol
        |\\\\
        |\\
        |\\\n
        |[^\\$matchOpeningSymbol$matchClosingSymbol]*
    )/xgc) 
    {
		$newLines = $blank->($1);
		$CODE_padding .= $newLines;
		$COMMENT .= $newLines;
		# $MIX .= $newLines;
		
		if ($1 eq $closingSymbol and $countSymbol == 0) {
			$string_buffer .= $1;
            # print 'interpol_str =' .$string_buffer."\n";
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
			return 0;
		}
        elsif ($1 eq $openingSymbol)
        {
        # print '++countSymbol' ."\n";
            $CODE .= $1;
            $MIX .= $1;
            $countSymbol++;            
        }
        elsif ($1 eq $closingSymbol)
        {
        # print '--countSymbol' ."\n";
            $CODE .= $1;
            $MIX .= $1;
            $countSymbol--;            
        }
		elsif ($1 ne "\\\n") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}
	}
	print STDERR "Unterminated interpolated string !!!\n";
	return 1;
}

# consumes interpolation block into string_buffer
sub parseInterpolation
{
	my $textInput = shift;
    
    my $buff = '#{';
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

sub parseCode($$$) {
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
    
    my $keywordsRegex = 
    {
        'if' => 1,
        'elsif' => 1,
        'scan' => 1,
        'split' => 1,
        'unless' => 1,
        'until' => 1,
        'when' => 1,
        'while' => 1,
    };
    my $stringKeywords = '';
    foreach my $keyword (keys %{$keywordsRegex})
    {
        $stringKeywords .= '\s*'.$keyword.'\s*|';
    
    }
    chop $stringKeywords;
    my $prefixRegexKeyword =  qr /$stringKeywords(?:\()/;
    my $prefixRegexR =  qr /\%r/;
    my $prefixRegexOperators =  qr /=~|\~|\,|\!|\||\(|\=|\&|not|and|or|\[/;

	# special variable $", $', $`
	# special ?" and ?'...
    # method name notation  :name_method
    # symbol  :symbol
    # symbol  :"symbol"
    # symbol  :'symbol'
    # symbol unicode value  :"\u0000"
	while ( $$TEXT =~ /
            \G
            (
               ($prefixRegexKeyword\s*(\/))
                |($prefixRegexR\s*([\(\[\|\!\{']))
                |($prefixRegexOperators\s*(\/))
                #regex suffix .match 
                |(\/.*\/\.match)\b                  
                |\/
                |=begin
                |(<<(?:[\-'"]?)([a-zA-Z_]+))
                |=
                |\#
                |%\{
                |(%[qQiIwWxs]?([\[\/\-{\("<]))
                |__END__
                |\$"
                |\$'
                |\$`
                |\$
                |\?'
                |\?"
                |\?
                |\_
                |"
                |'
                |`
                |%
                |<
                |\=
                |\|
                |\,
                |\~
                |\!
                |\(
                |\{
                |\&
                |\[
                |:"
                |:'
                |\:(?:\w+|[[:punct:]]+)
                |\:
                |not
                |and
                |or
                |n
                |a
                |o
                |g
                |s
                |w
                |i
                |e
                |u
                |[^"'`=\#\%<\$\=\,\|\~naogswieu\!\{\(\?\_\&\/\[\:]+
            )
            /xgc) 
    {

        my $newLines = $blank->($1);

        my $pattern = $1;
        my $KeywordRegexBegin = $2;
        my $prefixKeywordRegex = $3;  
        my $RRegexBegin = $4;
        my $prefixRRegex = $5;  
        my $simpleRegexBegin = $6;
        my $prefixLineRegex = $7;
        
        # print "code_fragment: <" . $pattern.">\n" if (defined $pattern) ;
        # print "KeywordRegexBegin: <" . $KeywordRegexBegin.">\n" if (defined $KeywordRegexBegin) ;
        # print "prefixKeywordRegex: <" . $prefixKeywordRegex.">\n" if (defined $prefixKeywordRegex) ;
        # print "RRegexBegin: <" . $RRegexBegin.">\n" if (defined $RRegexBegin) ;
        # print "prefixRRegex: <" . $prefixRRegex.">\n" if (defined $prefixRRegex) ;
        # print "simpleRegexBegin: <" . $simpleRegexBegin.">\n" if (defined $simpleRegexBegin) ;
        # print "prefixLineRegex: <" . $prefixLineRegex.">\n" if (defined $prefixLineRegex) ;
       
        if ($pattern eq '#') {
			$err = parseLineComment($pattern);
		}
		elsif ($pattern eq '=begin') {
			$err = parseMultilineLineComment($pattern);
		}
        elsif (defined $prefixLineRegex 
        or defined $prefixKeywordRegex
        or defined $prefixRRegex)
        {
            if (defined $simpleRegexBegin) # regex
                                            # ... =~ /.../
                                            # or ... ~ /.../ 
                                            # or ... , /.../ 
                                            # or ... | /.../
                                            # or ... ( /.../
                                            # or ... ! /.../
                                            # or ... = /.../
            {
                $CODE .= $simpleRegexBegin;
                $MIX .= $simpleRegexBegin;

                $err = parseRegExp($prefixLineRegex,$TEXT);
            }
            elsif (defined $RRegexBegin) # regex %r({/!['|...|']!/})
            {
                $CODE .= $RRegexBegin;
                $MIX .= $RRegexBegin;

                $err = parseRegExp($prefixRRegex,$TEXT, $RRegexBegin);                
            
            }
            else # regex (g)sub(!)/.../ 
                    # or (g)sub(!)(%r{},...)
                    # or scan (/.../)
                    # or when /.../
                    # or if /.../
                    # or split (/.../)            
            {
                $CODE .= $KeywordRegexBegin;
                $MIX .= $KeywordRegexBegin;

                $err = parseRegExp($prefixKeywordRegex,$TEXT);            
            }
        }            
		elsif ($pattern eq '"' or $pattern eq ':"') {
            
            if ($pattern eq ':"')
            {
                $CODE .= ':';
                $COMMENT .= $newLines;
                $MIX .= ':';
            }
       
			$err = parseDblString($pattern);
            if ($err == 1) {
                $err = 0;
                $err = parseTplString($pattern);
            }
        }
		elsif ($pattern eq "'" or $pattern eq ":'") {
            if ($pattern eq ':"')
            {
                $CODE .= ':';
                $COMMENT .= $newLines;
                $MIX .= ':';
            }

            $err = parseSplString($pattern);
            if ($err == 1) {
                $err = 0;
                $err = parseTplString($pattern);
            }
		}		
        elsif ($pattern eq '`') {
            $err = parseTplString($pattern);
		}
		elsif ($pattern eq '%{') {
            $err = parseTplString($pattern);
		}
        elsif (defined $8) {
            my $position = pos ($$TEXT) - length($8) + 1;           
            pos ($$TEXT) = $position;
            $err = parseRegExp('/',$TEXT);
		}	          
        elsif (defined $9 and defined $10) {
            $pattern = $9;
            my $heredocsPattern = $10;
			$err = parseTplString($pattern, $heredocsPattern);
		}	
		elsif (defined $11 and defined $12) {
			# %q[ ] 	Non-interpolated String (except for \\ \[ and \])
            # %Q[ ] 	Interpolated String (default)
            # %r[ ] 	Interpolated Regexp (flags can appear after the closing delimiter)
            # %i[ ] 	Non-interpolated Array of symbols, separated by whitespace (after Ruby 2.0)
            # %I[ ] 	Interpolated Array of symbols, separated by whitespace (after Ruby 2.0)
            # %w[ ] 	Non-interpolated Array of words, separated by whitespace
            # %W[ ] 	Interpolated Array of words, separated by whitespace
            # %x[ ] 	Interpolated shell command
            # %s[ ] 	Non-interpolated symbol
            
            # print 'String interpolated discovered !!!! '."=<$pattern>\n";
            
            $err = parseInterpolatedString($12);
          
		}	   
        elsif ($1 eq '__END__') {
            $DATA = $CODE;
            $DATA =~ s/.*\n/\n/g;
            
            my ($data) = $$TEXT =~ /\G(.*)/sgc;
            $DATA .= $data;
            $CODE .= $pattern;
            $COMMENT .= $newLines;
            $MIX .= $pattern;
            return 0;
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

sub parseRegExp($$;$) 
{
    my $openingSymbol = shift;
    my $textInput = shift;
    my $RRegexBegin = shift;
    my $regexp = $openingSymbol;
    # $CODE .= $openingSymbol;
    # $MIX .= $openingSymbol;

    my $closingSymbol;
    $closingSymbol = ')' if ($openingSymbol eq '(');
    $closingSymbol = '/' if ($openingSymbol eq '/');
    $closingSymbol = ']' if ($openingSymbol eq '[');
    $closingSymbol = '|' if ($openingSymbol eq '|');
    $closingSymbol = '!' if ($openingSymbol eq '!');
    $closingSymbol = '}' if ($openingSymbol eq '{');
    $closingSymbol = "'" if ($openingSymbol eq "'");
    
    my $matchClosingSymbol = "\\".$closingSymbol;
    my $matchOpeningSymbol = "\\".$openingSymbol;
    my $matchOpeningEscapedSymbol = "\\\\\\".$openingSymbol;
    my $matchClosingEscapedSymbol = "\\\\\\".$closingSymbol;
    # print 'openingSymbol=<'.$openingSymbol.">\n";
    # print 'closingSymbol=<'.$closingSymbol.">\n";
    # print 'matchOpeningSymbol='.$matchOpeningSymbol."\n";
    # print 'matchClosingSymbol='.$matchClosingSymbol."\n";
    # print 'matchOpeningEscapedSymbol='.$matchOpeningEscapedSymbol."\n";
    # print 'matchClosingEscapedSymbol='.$matchClosingEscapedSymbol."\n";
    
    my $countSymbol = 0;
    
    while ($$textInput =~ /
    \G(
        $matchOpeningEscapedSymbol
        |$matchClosingEscapedSymbol
        |$matchOpeningSymbol
        |$matchClosingSymbol
        |\\\\
        |\\\/
        |\\
        |\/
        |[^\/$matchOpeningSymbol$matchClosingSymbol\\]+
    )/xgc)
    {
        if ($1 eq $closingSymbol and $countSymbol == 0) 
        {
            $CODE .= $1;
            $MIX .= $1;
            $regexp .= $1;
            # print 'Regexp detected <'.$regexp.">\n";
            return 0;
        }
        elsif ($RRegexBegin and $1 eq $openingSymbol)
        {
        # print '++countSymbol' ."\n";
            $CODE .= $1;
            $MIX .= $1;
            $regexp .= $1;
            $countSymbol++;            
        }
        elsif ($RRegexBegin and $1 eq $closingSymbol)
        {
        # print '--countSymbol' ."\n";
            $CODE .= $1;
            $MIX .= $1;
            $regexp .= $1;
            $countSymbol--;            
        }
        else
        {
            $CODE .= $1;
            $MIX .= $1;
            $regexp .= $1;
       }
    }
    
    print STDERR "[parseRegExp] Missing closing delimiter $closingSymbol \n";
    return 1;
}

# analyse du fichier
sub StripRuby($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);

    configureLocalTraces('StripRuby', $options); # traces_filter_line
    my $stripRubyTiming = new Timing ('StripRuby', Timing->isSelectedTiming ('Strip'));
    $stripRubyTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    
    my $err = parseCode(\$vue->{'text'}, $options, $vue);
    
    $stripRubyTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

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
    $vue->{'data'} = $DATA;
    if ( defined $options->{'--dumpstrings'})
    {
      dumpVueStrings(  $RT_STRINGS , $STDERR );
    }
    $stripRubyTiming->dump('StripRuby') if ($b_timing_strip); # timing_filter_line
    return 0;
}

1; # Le chargement du module est okay.

