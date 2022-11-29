# Composant: Plugin

# Ce paquetage fournit une separation du code et des commentaires d'un source
# Python


package StripPython;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

# prototypes publics
sub StripPython($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                 );

use technos::check;

#-------------------------------------------------------------------------------
# DESCRIPTION: Automate de tri du contenu du fichier en trois parties:
# 1/ code
# 2/ commentaires
# 3/ chaines
#-------------------------------------------------------------------------------

my $StrPadding = "";

sub separer_code_commentaire_chaine($$$)
{
    my ($source, $options, $filename) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);
    my %hContext=();
    my $context=\%hContext;


    # This var is concatened before each string or regex indentifier.
    # This can be set to one blank space in cas of analysing minified code,
    # because minification remove all spaces. So 
    #   case"string"   become caseCHAINE_XXX after Highlight stripping.
    # If StrPadding is set to ' ', the expression become case CHAINE_XXX   !!!
    if (defined $options->{'--allow-minified'}) {
      $StrPadding = ' ';
    }

    my $stripPythonTiming = new Timing ('StripPython:separer_code_commentaire_chaine', Timing->isSelectedTiming ('Strip'));
    my $c = $$source;
    my $code = "";
    my $comment = "";
    my $Mix = "";
    my $state = 'INCODE' ;
    my $next_state = $state ;
    my $expected_closing_pattern = '';  #........................... Caractere attendu en fin de pattern string/comment/code
    my $string_buffer = '';
    my $line_in_string = 0;

    # a regexp ends with a slash but can be followed by some option (g, i, m, y)
    # The flag bellow indicates to the INCODE context that if these options are
    # encountered, they belong to the regexp !
    my $expectingRegexpOption = 0;

    # Structures for recording strings
    # --------------------------------
    my %strings_values = () ;
    my %strings_counts = () ;
    my %hash_strings_context = (
      'nb_distinct_strings' => 0,
      'strings_values' => \%strings_values,
      'strings_counts' => \%strings_counts  ) ;
    my $string_context = \%hash_strings_context;

    # Structures for recording regexp
    # --------------------------------
    my %RE_values = () ;
    my %RE_counts = () ;
    my %hash_RE_context = (
      'nb_distinct_strings' => 0,
      'strings_values' => \%RE_values,
      'strings_counts' => \%RE_counts  ) ;
    my $RE_context = \%hash_RE_context;


    $stripPythonTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    my @parts = split (  "([\n#]+)" , $c );

    $stripPythonTiming->markTimeAndPrint('--split--') if ($b_timing_strip); # timing_filter_line
    my $stripPythonTimingLoop = new Timing ('StripPython internal Loop', Timing->isSelectedTiming ('Strip'));


    # definition du pattern recherche, en fonction de l'etat courant.
    my %states_patterns = (
      #'INCODE' =>  qr{\G([rRuU]"""|[rRuU]'''|[rRuU]["']|[rRuU]|#|"""|"|'''|'|\n|[^#"'rRuU\n]*)}sm ,
      'INCODE' =>  qr{\G([rRuU]"""|[rRuU]'''|[rRuU]["']|\w+|#|"""|"|'''|'|\n|[^#"'\w\n]*)}sm ,
      'INCOMMENT' => qr{\G("""|"|\\"|\\|\n|[^\n"\\]*)}sm ,
      'INSTRING' => qr{\G(\n|\\\\|\\"|\\'|\\|"""|"|'''|'|[^\n"'\\]*)}sm ,
    );

  # Initial state
  # -------------
  my $position=0;

  # Create new view from the initial text view.
  my $vues = new Vues( 'text' ); 

  $vues->declare('code_a');
  $vues->declare('comment_a');
  $vues->declare('mix_a');

  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
  $context->{'string_context'} = $string_context;
  $context->{'RE_context'} = $RE_context;
  $context->{'expectingRegexpOption'} = $expectingRegexpOption;
  $context->{'lines_from_previous_string'} = 0;

  # memorize the last element that is not a COMMENT nor a BLANK.
  $context->{'previous_non_comment'} = '';
  my $espaces;

  # Global loop for cutting code into elements.
  # -------------------------------------------
    my $nb_iter = $#parts ;
    #for (my $part = 0; $part<= $nb_iter; $part++)
    for my $partie ( @parts )
    {
      localTrace (undef, "Utilisation du buffer:                           " . $partie . "\n" ); # traces_filter_line
      #$stripPythonTiming->markTimeAndPrint('--iter in split: ' . $part . '/' . $#parts  . '  --'); # timing_filter_line
      my $reg ;

      while  (
        # Mettre a jour l'expression rationnelle en fonction du pattern,
        # a chaque iteration.
        $reg =  $states_patterns{$state} ,
        $partie  =~ m/$reg/g )
      {
        my $element = $1;  # un morceau de fichier petit
        next if ( $element eq '') ;
#print "ELEMENT = $element\n";
        $espaces = $element ; # les retours a la ligne correspondant.
        #$stripPythonTimingLoop->markTimeAndPrint('--iter in split internal--'); # timing_filter_line
        $espaces = garde_newlines($espaces) ;
        #$espaces = '';
        #$espaces =~ s/\S/ /gsm ;
        #localTrace "debug_chaines",  "state: $state: working with  !!$element!! \n"; # traces_filter_line

        $context->{'element'} = $element;
        $context->{'blanked_element'} = $espaces;


        # Application du traitement associe a l'etat courant
        if ( $state eq 'INCODE' )
        {
          separer_code_commentaire_chaine_INCODE($context, $vues);
        }
        elsif ( $state eq 'INCOMMENT' )
        {
          separer_code_commentaire_chaine_INCOMMENT($context, $vues);
        }
        elsif ( $state eq 'INSTRING' )
        {
          separer_code_commentaire_chaine_INSTRING($context, $vues);
        }

        $vues->commit ( $position);
        $position += length( $element) ;

        if (defined $options->{'--strip-states'}) {
			if ($state ne $context->{'next_state'}) {
				print "____________________\n$element\n    ==> $context->{'next_state'}\n";
			}
			else {
				print "$element\n";
			}
		}
        $state = $context->{'next_state'};
      }
    }
  $next_state = $context->{'next_state'};
  $espaces = $context->{'blanked_element'};
  #my $element = $context->{'element'};
  $expected_closing_pattern = $context->{'expected_closing_pattern'};

  # Consolidation of views.
  $comment = $vues->consolidate('comment_a');
  $code = $vues->consolidate('code_a');
  $Mix = $vues->consolidate('mix_a');

    $stripPythonTiming->markTimeAndPrint('--done--') if ($b_timing_strip); # timing_filter_line
    my @return_array ;
    if (not $state eq 'INCODE')
    {
        if (not ($expected_closing_pattern eq "\n")) # tolerance pour les fin
        # de ligne manquante en fin de fichier dans un commentaire '//'
        {
            warningTrace (undef,  "warning: end of file in state $state \n"); # traces_filter_line
            if ($state eq 'INSTRING')
            {
                warningTrace (undef,  "string not terminated:\n" . $string_buffer ."\n" ); # traces_filter_line
            }
            elsif ($state eq 'INSREGEXP')
            {
                warningTrace (undef,  "regular expression not terminated:\n" . $string_buffer ."\n" ); # traces_filter_line
            }
            @return_array =  ( \$code, \$comment, \%strings_values, \$Mix , 1);
            return \@return_array ;
        }
    }
    @return_array =  ( \$code, \$comment, \%strings_values, \$Mix , 0);
    return \@return_array ;
}

# traitement associe a l'etat INCODE
sub separer_code_commentaire_chaine_INCODE($$) {
	my ($context, $vues)=@_;

	my $next_state = $context->{'next_state'};
	my $espaces = $context->{'blanked_element'};
	my $element = $context->{'element'};
	my $expected_closing_pattern = $context->{'expected_closing_pattern'};
	my $string_buffer = $context->{'string_buffer'};
	my $previous_non_comment = $context->{'previous_non_comment'};
 
	my $nb_lines_in_string = $context->{'line_in_string'};
	$context->{'back'} = 'INCODE' ;

	# nominal treatment.
	# -------------------
	if ( $element eq '#' ) {
		
		# strings are replaced by a CHAINE_XX item, and multilines string too. In this last case, we should add the line contained inside the
		# string in addition in the code to keep a line corresponding between 'code' and 'text' view !!!
		if ($context->{'lines_from_previous_string'}) {
			my $nb_lines_in_string = $context->{'lines_from_previous_string'};
			$vues->append( 'code_a' , "\n"x$nb_lines_in_string);
			$vues->append( 'mix_a'  , "\n"x$nb_lines_in_string);
			#$vues->append( 'mix_a'  , "__CODE_PADDING_FOR_PREVIOUS_MULTILINE_STRING__\n"x$nb_lines_in_string);
			$context->{'lines_from_previous_string'} = 0;
		}
		
		$next_state = 'INCOMMENT'; $expected_closing_pattern = "\n" ;
		$vues->append( 'comment_a',  $element);
		$vues->append( 'code_a' , ' '.$espaces);
		$vues->append( 'mix_a' , $element);
	}
	elsif ( $element eq '"""' ) {
		# check if the previous code element is identifying that the """ is the beginning of a string
		# belonging to an expression...
		if ($previous_non_comment !~ /(?:[\(,+=\{]|in|return|yield|print)\s*$/) {
			# if not, it is a doc string ...
			$next_state = 'INCOMMENT'; $expected_closing_pattern = '"""' ;
			$vues->append( 'code_a' , $espaces);
			# In the MixBloc vue, docstring are special comment identified by a line beginning with #%
			$vues->append( 'mix_a' , "#%\"\"\"");
			$vues->append( 'comment_a',  $element);
		}
		else {
			# it's a multiline string.
			$next_state = 'INSTRING'; $expected_closing_pattern = '"""' ;
			$string_buffer = $element ; $vues->append( 'comment_a', $espaces);
			$nb_lines_in_string = 0;
		}
	}
	elsif ( $element eq "'''" ) {
		$next_state = 'INSTRING'; $expected_closing_pattern = "'''" ;
		$string_buffer = $element ; $vues->append( 'comment_a', $espaces);
		$nb_lines_in_string = 0;
	}
	elsif ( $element eq '"' ) {
		$next_state = 'INSTRING'; $expected_closing_pattern = '"' ;
		$string_buffer = $element ; $vues->append( 'comment_a', $espaces);
		$nb_lines_in_string = 0;
	}
	elsif ( $element eq "'" ) {
		$next_state = 'INSTRING'; $expected_closing_pattern = "'" ;
		$string_buffer = $element ; $vues->append( 'comment_a', $espaces);
		$nb_lines_in_string = 0;
	}
	elsif ( $element =~ /([rRuU])(['"]+)/) {
		$next_state = 'INSTRING'; $expected_closing_pattern = $2 ;
		$string_buffer = $element ; $vues->append( 'comment_a', $espaces);
		$nb_lines_in_string = 0;
	}
	elsif ( $element eq "\n" ) {
		$vues->append( 'code_a' , $element);
		$vues->append( 'mix_a' , $element);
		$vues->append( 'comment_a', $espaces);
		
		# strings are replaced by a CHAINE_XX item, and multilines string too. In this last case, we should add the line contained inside the
		# string in addition in the code to keep a line corresponding between 'code' and 'text' view !!!
		if ($context->{'lines_from_previous_string'}) {
			my $nb_lines_in_string = $context->{'lines_from_previous_string'};
			$vues->append( 'code_a' , "\n"x$nb_lines_in_string);
			$vues->append( 'mix_a'  , "\n"x$nb_lines_in_string);
			#$vues->append( 'mix_a'  , "__CODE_PADDING_FOR_PREVIOUS_MULTILINE_STRING__\n"x$nb_lines_in_string);
			$context->{'lines_from_previous_string'} = 0;
		}
	}
	else {
		$vues->append( 'code_a' , $element);
		$vues->append( 'mix_a' , $element);
		$vues->append( 'comment_a', $espaces);
	}

	# keep the element if it is not the beginning of a comment (and is not a blank !)
	if (($element =~ /\S/s) && ($next_state ne 'INCOMMENT')) {
		$context->{'previous_non_comment'} = $element;
	}

	$context->{'line_in_string'} = $nb_lines_in_string;
	$context->{'string_buffer'} = $string_buffer;
	$context->{'next_state'} = $next_state;
	$context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

# traitement associe a l'etat INCOMMENT
sub separer_code_commentaire_chaine_INCOMMENT($$) {
	my ($context, $vues)=@_;

	my $next_state = $context->{'next_state'};
	my $espaces = $context->{'blanked_element'};
	my $element = $context->{'element'};
	my $expected_closing_pattern = $context->{'expected_closing_pattern'};

	if ( $element eq $expected_closing_pattern ) {
		$next_state = 'INCODE'; $expected_closing_pattern = '' ;
		$vues->append( 'code_a' , $espaces);
		$vues->append( 'comment_a', $element);
		
		#if ( $element ne '"""') {
			$vues->append( 'mix_a' , $element);
		#}
	}
	else {
		$vues->append( 'code_a' , $espaces);
		$vues->append( 'comment_a', $element);
		if ($element eq "\n") {
			# \n is not the end of the comment, means it is a multiline comment (docstring).
			# In the MixBloc vue, docstring are special comment identified by a line beginning with #%
			$vues->append( 'mix_a' , "\n#%");
		}
		else {
			$vues->append( 'mix_a' , $element);
		}
	}
	
	$context->{'next_state'} = $next_state;
	$context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

# traitement associe a l'etat INSTRING
sub separer_code_commentaire_chaine_INSTRING($$) {
	my ($context, $vues)=@_;

	my $next_state = $context->{'next_state'};
	my $espaces = $context->{'blanked_element'};
	my $element = $context->{'element'};
	my $expected_closing_pattern = $context->{'expected_closing_pattern'};
	my $string_buffer = $context->{'string_buffer'};
	my $nb_lines_in_string = $context->{'line_in_string'};
	my $string_context = $context->{'string_context'};
  
	# car en C, les chaine speuvent etre multi lignes.
	my $slaPeer  ; # Un nombre pair d'antislash
	my $slaEven  ;# Un antislash, si impair

#if (1)
#{
	$string_buffer =~ m{(\\\\)*(\\?)\z}sm ; #autant d'antislash consecutifs que possible.
	$slaPeer = $1 ; # Un nombre pair d'antislash
	$slaEven = $2 ;# Un antislash, si impair
#}
#else
#{
#  my $offset = length ( $string_buffer );
#  my $nb_antislash=0;
#  while  (  substr ( $string_buffer, $offset, 1) eq '\\' )
#  {
#    $offset -= 1;
#    $nb_antislash ++;
#  }
#  if ( $nb_antislash %2 ==0)
#  {
#    $slaEven = '' ;
#    $slaPeer = 'xxx' ; # '\\' x ($nb_antislash/2);
#  }
#  else
#  {
#    $slaEven = '\\' ;
#    $slaPeer = '\\' x ($nb_antislash/2);
#  }
	    #
#}

	$slaEven = '' if not defined $slaEven ;
	$slaPeer = '' if not defined $slaPeer ;

	#---- FIN DE CHAINE

	my $closing_encountered = 0;
	if ($element eq $expected_closing_pattern ) {
		$closing_encountered = 1;
	}
	elsif (($element eq '"""') && ($expected_closing_pattern eq '"')) {
		$closing_encountered = 1;
	}
	elsif (($element eq "'''") && ($expected_closing_pattern eq "'")) {
		$closing_encountered = 1;
	}

	#si la fin de chaine est precedee d'un nombre pair d'antislash:
	#il s'agit bien d'une fin de chaine.
	if ( ( $closing_encountered ) && ( $slaEven eq '' )) {
		$next_state = 'INCODE'; $expected_closing_pattern = '' ;
		$string_buffer .= $element ;
		$vues->append( 'comment_a', $espaces);

		my $string_id = StringStore( $string_context, $string_buffer );

		# Dans la vue "code", la chaine est remplace par CHAINE_<id>_<occurence> ...HIGHLIGHT-1614
		# Finalement on ne concatene pas le numero d'occurence.
		$vues->append( 'code_a' , $StrPadding.$string_id.$StrPadding);
		$vues->append( 'mix_a' , $string_id);

#		if ($nb_lines_in_string > 0) {
#			$vues->append( 'code_a' , "\n"x$nb_lines_in_string);
#			$vues->append( 'mix_a'  , "\n"x$nb_lines_in_string);
#		}

		$context->{'lines_from_previous_string'} += $nb_lines_in_string;
		$string_buffer = '' ;
	}

	#---- RECORD STRING CONTENT

	else {
		if ( $element eq "\n") {
			$nb_lines_in_string++;
		}
		$string_buffer .= $element ;
		# update only comment view. Mix and code view will be updated when the string will be terminated,
		# because we need the ID of the string ...
		$vues->append( 'comment_a', $espaces);
	}

	if ($element =~ /\S/s) {
		$context->{'previous_non_comment'} = $element;
	}
	$context->{'string_context'} = $string_context;
	$context->{'string_buffer'} = $string_buffer;
	$context->{'line_in_string'} = $nb_lines_in_string;
	$context->{'next_state'} = $next_state;
	$context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

sub createAggloView($) {
	my $vues = shift;
	my $mix = \$vues->{'MixBloc'};
	my @agglo = ();
	my $lineProfil = "";
	my $context = "P";
#	my $lengthMatched  = 0;
	 
	my %patterns = (
		'P' => qr{\G([^\n#"\@]*)(#%"""|[\n#\@]|"""|\z)}sm,
		'@' => qr{\G([^\n#"]*)([\n#]|"""|\z)}sm,
		'#' => qr{\G([^\n]*)(\n|\z)}sm,
		'"' => qr{\G((?:\\"|\\|"[^"]|""[^"]|[^"\\])*)("""|\z)}sm,
		#'"' => qr{\G([^"]*)("""|\z)}sm,
	);
	
	my $reg;
	while ($reg = $patterns{$context}, $$mix =~ /$reg/g) {
		my $data = $1;
		my $ending = $2;
		if (! defined $2) {
			print "hooo!\n";
		}
#$lengthMatched += length($data) + length($ending);
#print "LENGTH DATA = ".length($data)."\n";
#print "LENGTH ENDING = ".length($ending)."\n";
#print "LENGTH MATCHED = $lengthMatched, pos = ".pos($$mix)."\n";
#print "CONTEXT: $context, DATA: <<$data>>, ENDING: <<$ending>>\n";
#print "FOLLOWING : <<".substr ($$mix, pos($$mix), 50).">>>\n";

		if ($context eq 'P') {
			
			# case of a decorator
			if (($ending eq '@') && ($lineProfil eq '')) {
				$lineProfil = '@';
				$context = '@';
				next;
			}
			elsif ($data =~ /\S/) {
				# mark a "P" to indicate the present of Program code in the line if non blank characters are encountered.
				$lineProfil .= "P";
			}
		}

		if (($context eq 'P') || ($context eq '@')) {
			if ($ending eq "#") {
				# the change of the line context is due to a comment, so mark the line profil with "#" indicatng a comment.
				$lineProfil .= "#";
				# and switch into comment context.
				$context = "#";
			}
			elsif ($ending eq '#%"""') {
				# the change of the line context is due to a comment, so mark the line profil with "#" indicatng a comment.
				$lineProfil .= '"';
				# and switch into program context.

				$context = '"';
			}
			else {
				# the end of the line context is due to line return or end of file, so push the actual current line profil
				push @agglo, $lineProfil; $lineProfil= "";
				# The new line signifies the end of the "P" or "@" context. But in both cases, the next line will be in context "P" 
				$context="P";
			}
		}
		elsif ($context eq '#') {
			push @agglo, $lineProfil; $lineProfil= "";
			$context = "P";
		}
		elsif ($context eq '"') {

			my $n = () = $1 =~ /(\n)/g;
			if ($n) {
				push @agglo, $lineProfil; $lineProfil= "";
				for (my $i=0; $i<$n-1; $i++) {
					push @agglo, '"';
				}
				$lineProfil = '"';
			}
			$context = "P";
		}
	}
	return \@agglo;
}

# analyse du fichier
sub StripPython($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);
#print STDERR join ( "\n", keys ( %{$options} ) );
    configureLocalTraces('StripPython', $options); # traces_filter_line
    my $stripPythonTiming = new Timing ('StripPython', Timing->isSelectedTiming ('Strip'));

    localTrace ('verbose',  "working with  $filename \n"); # traces_filter_line
    my $text = \$vue->{'text'};
    $stripPythonTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line

    my $ref_sep = separer_code_commentaire_chaine($text, $options, $filename);

    $stripPythonTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

    my($c, $comments, $rt_strings, $MixBloc, $err) = @{$ref_sep} ;

    $vue->{'comment'} = $$comments;
    $vue->{'HString'} = $rt_strings;
    $vue->{'code_with_prepro'} = $$c;
    $vue->{'MixBloc'} = $$MixBloc;
    $vue->{'tabagglo'} = createAggloView($vue);
    $vue->{'agglo'} = join("\n", @{$vue->{'tabagglo'}});
    $vue->{'MixBloc_LinesIndex'} = StripUtils::createLinesIndex($MixBloc);
    $vue->{'agglo_LinesIndex'} = StripUtils::createLinesIndex(\$vue->{'agglo'});

    if ( $err gt 0) {
      my $message = 'Erreur fatale dans la separation des chaines et des commentaires';
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', $message);
      return Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    }

    if ($$c !~ /\S/s ) {
      return Erreurs::FatalError( Erreurs::ABORT_CAUSE_NOT_ENOUGH_CODE, $couples, "No python found");
    }

    $vue->{'code'} = $$c;
    if ( defined $options->{'--dumpstrings'})
    {
      dumpVueStrings(  $rt_strings , $STDERR );
    }
    $stripPythonTiming->dump('StripPython') if ($b_timing_strip); # timing_filter_line
    return 0;
}

1; # Le chargement du module est okay.

