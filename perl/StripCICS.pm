package StripCICS;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

# prototypes publics
sub StripCICS($$$$);

use StripUtils qw(
	garde_newlines
	warningTrace
	configureLocalTraces
	StringStore
	dumpVueStrings
);

StripUtils::init('StripCICS', 0);

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
#   - Simple line : * ..... \n

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

# STRINGS FEATURES
#-----------------
# kinds:
#  -  Simple quote string  ''
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

	while ( $$TEXT =~ /\G(\*|"|'|[^"'*]*)/gc) {

		my $newLines = $blank->($1);
		if ($1 eq '*') {
			$err = parseLineComment($1);
		}
		elsif ($1 eq '"') {
			$err = parseDblString($1);
		}
		elsif ($1 eq "'") {
			$err = parseSplString($1);
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
sub StripCICS($$$$)
{
	my ($filename, $vue, $options, $couples) = @_;
	my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);

	configureLocalTraces('StripCICS', $options); # traces_filter_line
	my $stripCICSTiming = new Timing ('StripCICS', Timing->isSelectedTiming ('Strip'));
	$stripCICSTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line

	my $err = parseCode(\$vue->{'text'}, $options);

	$stripCICSTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

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

	if ($CODE !~ /\S/s ) {
		return Erreurs::FatalError( Erreurs::ABORT_CAUSE_NOT_ENOUGH_CODE, $couples, "No CICS found");
	}

	$vue->{'code'} = $CODE;
	if ( defined $options->{'--dumpstrings'})
	{
		dumpVueStrings(  $RT_STRINGS , $STDERR );
	}
	$stripCICSTiming->dump('StripCICS') if ($b_timing_strip); # timing_filter_line
	return 0;
}

1; # Le chargement du module est okay.

