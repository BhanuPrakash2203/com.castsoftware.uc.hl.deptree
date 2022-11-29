package StripFS;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

# prototypes publics
sub StripFS($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                  dumpVueStrings
                 );

StripUtils::init('StripFS', 0);

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
#   - Multiline   : (* ..... *)

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
	
	while ( $$TEXT =~ /\G(\*\)|\*|[^*]*)/gc) {
		$newLines = $blank->($1);
		if ($1 eq '*)') {
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
#  -  Multiline string     @" " verbatim string
#                     or   """ """
#                     or   <@...@> code quotation
#                     or   <@@...@@> code quotation
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
	
	while ( $$TEXT =~ /\G(\"\"|"B?|\\\\|\\"|\\\n|\\|[^\\"]*)/gc) {
		$newLines = $blank->($1);
		$CODE_padding .= $newLines;
		$COMMENT .= $newLines;
		# $MIX .= $newLines;
		
		if (($1 eq '"') or ($1 eq '"B')){
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
#print "DOUBLE STRING : $string_buffer\n";
			return 0;
		}
		elsif ($1 ne "\\\n") {
			# not a continuing line => update $string_buffer
			$string_buffer .= $1;
		}
	}
	print STDERR "Unterminated string parseDblString!!!\n";
	print " --> ".substr($string_buffer, 0, 30)."\n";
	return 1;
}

# TEMPLATE
sub parseTplString($) {

	my $openingSymbol = shift;
	my $newLines = $blank->($openingSymbol);
	$COMMENT .= $newLines;
	my $string_buffer = $1;
	my $CODE_padding = "";
	
	# Note : """" is to managed like : xmlns="""" 
	while ( $$TEXT =~ /\G(""""|"""|""|"|\\\n|\\|(?:@)?@>|@|[^\\"@]*)/gc) {
		$newLines = $blank->($1);
		$COMMENT .= $newLines;
		$CODE_padding .= $newLines;
		
		if ($1 eq '"""' and $openingSymbol eq '"""') {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
#print "TEMPLATE DBL STRING : $string_buffer\n";
			return 0;
		}
		elsif (($1 eq '"' or $1 eq '\"') and $openingSymbol eq '@"') {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
#print "TEMPLATE SPL STRING : $string_buffer\n";
			return 0;
		}
		elsif (($1 eq '@>' or $1 eq '@@>') 
        and ($openingSymbol eq '<@' or $openingSymbol eq '<@@')) {
			$string_buffer .= $1;
			my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
			$CODE .= " $string_id ".$CODE_padding;
			$MIX .= " $string_id ".$CODE_padding;
#print "VERBATIM STRING : $string_buffer\n";
			return 0;
		}
		elsif ($1 eq "\n") {
			$string_buffer .= $1;
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
	print STDERR "-> $string_buffer\n";
	return 1;
}

sub parseLiteralChar($) {
	my $el = shift;
	my $newLines = $blank->($el);
	my $string_buffer = "";
	
	if ($$TEXT =~ /\G((?:\\[^']+|[^'])'B?)/gc) {
		$string_buffer = $el.$1;
		my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
		$CODE .= $string_id;
		$MIX .= $string_id;
#print "LITERAL : $string_buffer\n";
		return 0
	}
	else {
		$CODE .= $el;
		$COMMENT .= $newLines;
		$MIX .= $el;
		return 0;
	}
	print STDERR "Unterminated literal !!!\n";
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
	
    # particular function F# : 'T,'U
	while ( $$TEXT =~ /\G(\/[^\/*]|\/\/|\(\*\)|\(\*|\@\"|\@|<@(?:@)?|\(|\"\"\"|"|<|'|[^"\/(@<']*)/gc) {
    
    my $newLines = $blank->($1);
		if ($1 eq '//') {
			$err = parseLineComment($1);
		}
		elsif ($1 eq '(*') {
			$err = parseMultilineLineComment($1);
		}
		elsif ($1 eq '"') {
			$err = parseDblString($1);
		}
		elsif ($1 eq "'") {
			$err = parseLiteralChar($1);
		}
		elsif ($1 eq '@"') {
			$err = parseTplString($1);
		}
		elsif ($1 eq '"""') {
			$err = parseTplString($1);
		}
		elsif ($1 eq '<@' or $1 eq '<@@') {
			$err = parseTplString($1);
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

# analyse du fichier
sub StripFS($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);

    configureLocalTraces('StripFS', $options); # traces_filter_line
    my $stripFSTiming = new Timing ('StripFS', Timing->isSelectedTiming ('Strip'));
    $stripFSTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    
    my $err = parseCode(\$vue->{'text'}, $options);
    
    $stripFSTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

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
    $stripFSTiming->dump('StripFS') if ($b_timing_strip); # timing_filter_line
    return 0;
}

1; # Le chargement du module est okay.

