package StripRust;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

# prototypes publics
sub StripRust($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                  dumpVueStrings
                 );

StripUtils::init('StripRust', 0);

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

# STRINGS FEATURES
#-----------------
# kinds: 
#  -  Double quote string  ""
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
	
	while ( $$TEXT =~ /\G(\\"|\"\"|"|\\\\|\\|\\\n|[^\\"]*)/gc) {
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
		elsif ($1 ne "\\\n") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}
	}
	print STDERR "Unterminated string !!!\n";
	return 1;
}

# POINTERS - LOOP LABEL | LITERAL CHAR
sub parseLiteralSymbol($) {
	my $el = shift;
	my $newLines = $blank->($el);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";

	if ($$TEXT =~ /\G(\w+)/gc) {
		# if ( $$TEXT =~ /\G([^\\][\s']*)/gc) {

		# pointers &' or loop label

		$newLines = $blank->($1);
		$CODE_padding .= $newLines;
		$COMMENT .= $newLines;

		$string_buffer .= $1;
		my $string_id = StringStore($STRING_CONTEXT, $string_buffer);
		$CODE .= " $string_id " . $CODE_padding;
		$MIX .= " $string_id " . $CODE_padding;

		# consumes the ' if any.
		# needed for example for a literal char like 'a'
		$$TEXT =~ /\G'/gc;
		# print "Pointer or loop label = $string_buffer\n";
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
				$CODE .= " $string_id " . $CODE_padding;
				$MIX .= " $string_id " . $CODE_padding;
				# print "LITERAL CHAR = $string_buffer\n";
				return 0;
			}
		}
	}

	print STDERR "malformed literal string : simple quote not followe by a word\n";
	print "--> $string_buffer\n";
	return 1;
}

########
# Raw string literals : r RAW_STRING_CONTENT
# Byte literals : b' ( ASCII_FOR_CHAR | BYTE_ESCAPE ) ' 
# Byte string literals : b" ( ASCII_FOR_STRING | BYTE_ESCAPE | STRING_CONTINUE )* "
# Raw byte string literals : br RAW_BYTE_STRING_CONTENT
########
sub parseByteRawString($$) {
	my $openingSymbol = shift;
	my $SpecialCharacter = shift;
	my $newLines = $blank->($openingSymbol);
	$COMMENT .= $newLines;
	$MIX .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";
	my $closingPattern;
    
    # print 'openingSymbol='.$openingSymbol."\n";
    # print 'SpecialCharacter='.$SpecialCharacter."\n";
    my $firstCharClosingPattern;
    
    if ($SpecialCharacter =~ /#/)
    {
        $closingPattern = reverse($SpecialCharacter);
    }
    else
    {
        $closingPattern = $SpecialCharacter;
    }
    
    if ($closingPattern and $closingPattern =~ /^([#"'])/)
    {   
        $firstCharClosingPattern = $1;
    }
    # print 'closingPattern='.$closingPattern."\n";
    # print 'firstCharClosingPattern='.$firstCharClosingPattern."\n";
    
    my $regexp_literal;
    if ($openingSymbol =~ /b['"]/)
    {
        # b (escaped characters are processed)
        $regexp_literal = qr /\G(\\$firstCharClosingPattern|$closingPattern|$firstCharClosingPattern|\\\\|\\|\\\n|[^\\$firstCharClosingPattern]*)/;
    }
    else 
    { 
        # r or br (escaped characters are not processed)
        $regexp_literal = qr /\G($closingPattern|$firstCharClosingPattern|\\\\|\\\n|[^$firstCharClosingPattern]*)/;
    }
    
	while ( $$TEXT =~ /$regexp_literal/gc) {
		$newLines = $blank->($1);
		$CODE_padding .= $newLines;
		$COMMENT .= $newLines;
		# $MIX .= $newLines;

		if ($1 eq $closingPattern) {
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
	print STDERR "Unterminated raw string !!!\n";
	return 1;
}

# TEMPLATE
# sub parseTplString($) {
	# my $el = shift;
	# my $newLines = $blank->($el);
	# $COMMENT .= $newLines;
	# my $string_buffer = $1;
	# my $CODE_padding = "";
	
	# while ( $$TEXT =~ /\G(\\`|`|\n|\\\n|[^\\`\n]*)/gc) {
		# $newLines = $blank->($1);
		# $COMMENT .= $newLines;
		# $CODE_padding .= $newLines;
		
		# if ($1 eq "`") {
			# $string_buffer .= $1;
			# my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			# $CODE .= "$string_id".$CODE_padding;
			# $MIX .= "$string_id".$CODE_padding;
			# return 0;
		# }
		# elsif ($1 eq "\n") {
			# $string_buffer .= $1;
		# }
		# elsif ($1 ne "\\\n") {
			# # not a continuing line => update $string_buffer
			# $string_buffer .= $1;
		# }
		# else {
			# # $string_buffer note updated
		# }
	# }
	# print STDERR "Unterminated string !!!\n";
	# return 1;
# }

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
	
	while ( $$TEXT =~ /\G(\/[^\/*]|\/\/|\/\*|((?:r|b|br)(#*["']))|\/|&'|"|'|&|r|b|[^"'\/&rb]*)/gc) {
    
    my $newLines = $blank->($1);
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
			$err = parseLiteralSymbol($1);
		}		
        elsif ($1 eq "&'") {
			$err = parseLiteralSymbol($1);
		}       
        elsif (defined $2) {
			$err = parseByteRawString($2, $3);
		}
		# elsif ($1 eq "`") {
			# $err = parseTplString($1);
		# }
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

# analyse du fichier
sub StripRust($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);

    configureLocalTraces('StripRust', $options); # traces_filter_line
    my $stripRustTiming = new Timing ('StripRust', Timing->isSelectedTiming ('Strip'));
    $stripRustTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    
    my $err = parseCode(\$vue->{'text'}, $options);
    
    $stripRustTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

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
    $stripRustTiming->dump('StripRust') if ($b_timing_strip); # timing_filter_line
    return 0;
}

1; # Le chargement du module est okay.

