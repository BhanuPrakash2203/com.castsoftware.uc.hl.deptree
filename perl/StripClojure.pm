package StripClojure;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

# prototypes publics
sub StripClojure($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                  dumpVueStrings
                 );

StripUtils::init('StripClojure', 0);

#-----------------------------------------------------------------------

my $blank = \&garde_newlines;

my $TEXT;
my $CODE="";
my $COMMENT = "";
my $MIX = "";
my $LINE = 1;
my $LEVEL = 0;

my $STRING_CONTEXT = { 
	'nb_distinct_strings' => 0,
	'strings_values' => {},
	'strings_counts' => {}
} ;
my $RT_STRINGS = $STRING_CONTEXT->{'strings_values'};



sub parseLineComment($) {
	my $el = shift;
	my $spaces = $blank->($el);
	$CODE .= $spaces;
	$COMMENT .= $el;
	$MIX .= '/*';
	
	while ( $$TEXT =~ /\G(\n|[^\n]*)/gc) {
		$spaces = $blank->($1);
		if ($1 eq "\n") {
			$LINE++;
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

sub _parseDblString($$) {
	my $r_string = shift;
	my $r_blanks = shift;
	
	my $opening_line = $LINE;
	
	while ( $$TEXT =~ /\G(\\"|\"\"|"|\\\\|\\|\\\n|[^\\"]*)/gc) {
		$$r_string .= $1;
		
		if ($1 eq '"') {
			my $nb_lines = $$r_string =~ tr/\n/\n/;
			$$r_blanks .= "\n" x $nb_lines;
			$LINE += $nb_lines;
#print STDERR "$$r_string\n";
			return 0;
		}
	}
	print STDERR "Unterminated string openned at line $opening_line !!!\n";
	return 1;
}

# DOUBLE QUOTE
sub parseDblString($) {
	my $el = shift;
	my $spaces = $blank->($el);
	$COMMENT .= $spaces;
	$MIX .= $spaces;
	my $string_buffer = $1;
	my $blanks = "";
	my $opening_line = $LINE;
	
	my $err = _parseDblString(\$string_buffer, \$blanks);
	
	my $string_id = StringStore( $STRING_CONTEXT, $string_buffer );
	$CODE .= "$string_id".$blanks;
	$COMMENT .= $blanks;
	$MIX .= "$string_id".$blanks;
	
	return $err;
}

sub parseDblStringComment($) {
	my $el = shift;
	my $spaces = $blank->($el);
	$CODE .= $spaces;
	$COMMENT .= $el;
	$MIX .= "/*";
	my $opening_line = $LINE;
	
	while ( $$TEXT =~ /\G(\\"|\"\"|"|\\\\|\\|\\\n|[^\\"]*)/gc) {
		$CODE .= $blank->($1);
		$COMMENT .= $1;
		
		
		if ($1 eq '"') {
			$MIX .= "*/";
			return 0;
		}
		else {
			$MIX .= $1;
			$LINE += $1 =~ tr/\n/\n/;
		}
	}
	print STDERR "Unterminated string openned at line $opening_line !!!\n";
	return 1;
}
 
sub parseRichComment($$) {
	my $el =  shift;
	my $r_isComment = shift;
	
	
	if ($$TEXT =~ /\G(\s*)"/gc) {
		# COMMENT view
		$$r_isComment = 1;
		$CODE .= $blank->($el).$1;
		$COMMENT .= $el . $1;
		$MIX .= "/*";
		my $string = '"';
		my $blanks = "";
		my $err = _parseDblString(\$string, \$blanks);
		$CODE .= $blanks;
		$COMMENT .= $string;

		# MixBloc view tranformation
		$string =~ s/^"//;
		$string =~ s/"$//;
		$string =~ s/\n/\*\/\n\/\*/g;
		$MIX .= $string;
		return $err;
	}
	else {
		# CODE view
		$CODE .= $el;
		$COMMENT .= $blank->($el);
		$MIX .= $el;
		return parseCode();
	}
}

my %CLOSING = ("(" => ")", "[" => "]", "{" => "}");

sub parseStructure($) {
	my $el = shift;
	my $open = $el;
	my $close = $CLOSING{$open};
	my $spaces = $blank->($el);
	my $openingLine = $LINE;
	my $err = 0;
	$LEVEL++;
	
	my $blanks = "";
	my $isComment = 0;

	$COMMENT .= $spaces;
	$MIX .= $el;
	$CODE .= $el;
	$err = parseCode();
	
	if ($$TEXT =~ /\G(\s*$close)/gc) {
		# closing accolade found
		$blanks .= $blank->($1);
		
		$CODE .= $1;
		$COMMENT .= $blanks;
		$MIX .= $1;
		
		$LINE += $1 =~ tr/\n/\n/;
		$LEVEL--;
		if ($LEVEL < 0) {
			print STDERR "unexpected closing $close at line $LINE\n";
		}
#print STDERR "line $LINE ~~~> line $openingLine\n";
	}
	else {
		print STDERR "[parseStructure] Missing closing $close for opening at line $openingLine !!\n";
		return 1;
	}
	
	return $err;
}

sub parseParenthesis($) {
	my $el = shift;
	my $spaces = $blank->($el);
	my $openingLine = $LINE;
	my $err = 0;
	$LEVEL++;
	
	my $blanks = "";
	my $isComment = 0;
	
	if ($$TEXT =~ /\G(\s*comment\b)/gc) {
		$LINE += $1 =~ tr/\n/\n/;
		$err = parseRichComment($el.$1, \$isComment);
	}
	else {
		$COMMENT .= $spaces;
		$MIX .= $el;
		$CODE .= $el;
		$err = parseCode();
	}
	
	if ($$TEXT =~ /\G(\s*\))/gc) {
		# closing parenthese found
		$blanks .= $blank->($1);
		
		if ($isComment) {
			$CODE .= $blanks;
			$COMMENT .= $1;
			$MIX .= "*/";
		}
		else {
			$CODE .= $1;
			$COMMENT .= $blanks;
			$MIX .= $1;
		}
		
		$LINE += $1 =~ tr/\n/\n/;
		$LEVEL--;
		if ($LEVEL < 0) {
			print STDERR "unexpected closing parenthese at line $LINE\n";
		}
#print STDERR "line $LINE ~~~> line $openingLine\n";
	}
	else {
		print STDERR "[parseParenthesis] Missing closing parenthese for opening at line $openingLine !!\n";
		return 1;
	}
	
	return $err;
}

sub parseDiscardComment($);
sub parseDiscardComment($) {
	my $el = shift;
	
	my $err = 0;
	
	$CODE .= $blank->($el);
	$COMMENT .= $el;
	
	if ($$TEXT =~ /\G(\s*)((\(|\[)|"|#_|(\w))/gc) {
		$CODE .= $1.$blank->($2);
		$COMMENT .= $1.$2;
		if ($2 ne "#_") {
			$MIX .= "/*".$1.$2;
		}
		else {
			$MIX .= $1;
		}
		$LINE += $1 =~ tr/\n/\n/;
		
		#if ($2 eq "(") {
		if (defined $3) {
			# parenthesed form ( or [
			my $LEVEL = 1;
			my $openingLine = $LINE;
			my $opening = $3;
			my $closing = $CLOSING{$3};
			while ($$TEXT =~ /\G(\(|\)|\[|\]|\n|[^\(\)\n\[\]])/gc) {
				$CODE .= $blank->($1);
				$COMMENT .= $1;
				#$MIX .= $1;
				
				if ($1 eq $opening) {
					$LEVEL++;
					$MIX .= $1;
				}
				elsif ($1 eq $closing) {
					$LEVEL--;
					$MIX .= $1;
					if ($LEVEL == 0) {
						$MIX .= "*/";
						return 0;
					}
				}
				elsif ($1 eq "\n") {
					$MIX .= "*/\n/*";
					$LINE++;
				}
				else {
					$MIX .= $1;
				}
			}
			
			print STDERR "[parseDiscardComment] unterminated discarded form at line $openingLine\n";
			$err = 1;
		}
		elsif ($2 eq '"') {
			# string
			my $string = '';
			my $blanks = "";
			my $err = _parseDblString(\$string, \$blanks);
			$CODE .= $blanks;
			$COMMENT .= $string;
			
			# MixBloc view transformation
			$string =~ s/\n/\*\/\n\/\*/;
			$MIX .= $string."*/";
			return $err;	
		}
		elsif ($2 eq '#_') {
			$err = parseDiscardComment("");
			if (!$err) {
				# $err == 0 means embedded discard comment has been correctly parsed. So, parse the encompassing one.
				return parseDiscardComment("");
			}
		}
		elsif (defined $4) {
			if ($$TEXT =~ /\G(\w+)/gc) {
				$CODE .= $blank->($1);
				$COMMENT .= $1;
				$MIX .= $1."*/";
			}
		}
	}
	else {
		print STDERR "[parseDiscardComment] unknow discard object : ".substr($$TEXT, pos($$TEXT), 10)." ...\n";
	}
	return $err;
}

sub parseCode() {
	
	my $err = 0;
	
	# Swallow escaped char (regex \\.). Match for example : (.append w \")
	while ( $$TEXT =~ /\G("|;|\(|\{|\[|\n|#_|#|\\.|[^";\(\)\{\}\[\]\n#\\]*)/gc) {
    
    my $spaces = $blank->($1);
		if ($1 eq ';') {
			$err = parseLineComment($1);
		}
		elsif ($1 eq '(') {
			$err = parseParenthesis($1);
		}
		elsif ($1 eq '{') {
			$err = parseStructure($1);
		}
		elsif ($1 eq '[') {
			$err = parseStructure($1);
		}
		elsif ($1 eq '"') {
			if ($LEVEL == 0) {
				$err = parseDblStringComment($1);
			}
			else {
				$err = parseDblString($1);
			}
		}
		elsif ($1 eq "#_") {
			$err = parseDiscardComment($1);
		}
		else {
			if ($1 eq "\n") {
				$LINE++;
			}
			$CODE .= $1;
			$COMMENT .= $spaces;
			$MIX .= $1;
		}
		
		if ($err gt 0) {
			return 1;
		}
	}
	
	return  0;
}

sub parseRoot($$) {
	$TEXT = shift;
	my $options = shift;
	
	# Init data
	$CODE = "";
    $COMMENT = "";
    $MIX = "";
    $LINE = 1;
    $STRING_CONTEXT = { 
		'nb_distinct_strings' => 0,
		'strings_values' => {},
		'strings_counts' => {}
	};
	$RT_STRINGS = $STRING_CONTEXT->{'strings_values'};
	
	my $err = parseCode();

	return $err
}

# analyse du fichier
sub StripClojure($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);

    configureLocalTraces('StripClojure', $options); # traces_filter_line
    my $stripClojureTiming = new Timing ('StripClojure', Timing->isSelectedTiming ('Strip'));
    $stripClojureTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    
    my $err = parseRoot(\$vue->{'text'}, $options);
    
    pos($vue->{'text'}) = undef;
    
    $stripClojureTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

	$vue->{'code'} = $CODE;
    $vue->{'comment'} = $COMMENT;
    $vue->{'HString'} = $RT_STRINGS;
    $vue->{'code_with_prepro'} = "";
    $vue->{'MixBloc'} = $MIX;
    $vue->{'agglo'} = "";                       
    StripUtils::agglomerate_C_Comments(\$MIX, \$vue->{'agglo'});
    $vue->{'MixBloc_LinesIndex'} = StripUtils::createLinesIndex(\$MIX);
    $vue->{'agglo_LinesIndex'} = StripUtils::createLinesIndex(\$vue->{'agglo'});

	if ( defined $options->{'--dumpstrings'})
    {
      dumpVueStrings(  $RT_STRINGS , $STDERR );
    }

    if ( $err gt 0) {
      my $message = 'Fatal error when separating code/comments/strings';
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', $message);
      return Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    }
    
    $stripClojureTiming->dump('StripClojure') if ($b_timing_strip); # timing_filter_line
    return 0;
}

1; # Le chargement du module est okay.

