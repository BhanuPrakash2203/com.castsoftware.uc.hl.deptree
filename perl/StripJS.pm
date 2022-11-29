# Composant: Plugin

# Ce paquetage fournit une separation du code et des commentaires d'un source
# JS


package StripJS;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

use StripPHP;

# prototypes publics
sub StripJS($$$$);

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
my $serverOpenTag = '<(?:%|\?)';
my $serverCloseTag = '(?:\?|%)>';
my $htmlOpenTag = technos::check::get_JS_OpenningDelimiters();
my $htmlCloseTag = technos::check::get_JS_ClosingDelimiters();

my $StrPadding = "";

sub separer_code_commentaire_chaine($$$;$)
{
    my ($source, $options, $filename, $forceHTML) = @_;
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

    my $stripJSTiming = new Timing ('StripJS:separer_code_commentaire_chaine', Timing->isSelectedTiming ('Strip'));
    my $c = $$source;
    my $code = "";
    my $comment = "";
    my $Mix = "";
    my $state = 'IN_HTML' ;
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


    $stripJSTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    #my @parts = split (  "([/*]+)" , $c );
    #my @parts = split (  /(${shortOpenTag}|${shortCloseTag}|${htmlOpenTag}|${htmlCloseTag})/i , $c );
    my @parts = split (  /(${htmlOpenTag}|${htmlCloseTag})/i , $c );

    $stripJSTiming->markTimeAndPrint('--split--') if ($b_timing_strip); # timing_filter_line
    my $stripJSTimingLoop = new Timing ('StripJS internal Loop', Timing->isSelectedTiming ('Strip'));


    # definition du pattern recherche, en fonction de l'etat courant.
    my %states_patterns = (
      # Context for code inside <? ... ?> and <% ... %> tags
      'IN_SERVER' =>  qr{\G($serverCloseTag|\?|%|[^\?%]*)}sm,
      # Context for HTML code.
      # NOTE: must be case insensitive for HTML tags
      'IN_HTML' =>  qr{\G($htmlOpenTag|<!--|<|[^<]*)}ism ,
      # Context for HTML comments
      'IN_COMMENT_HTML' =>  qr{\G(-->|-|[^-]*)}sm ,
      # Le code peut s'arreter sur debut de commentaire.
      # ou implicitement sur guillemets ou retour a la ligne
      # NOTE: must be case insensitive for HTML tags
      'INCODE' =>  qr{\G($htmlCloseTag|$serverOpenTag|/[*]|//|/|[*]|\n|\"|\'|<|\`|[^/*\n\"\'<\`]*)}ism ,
      # Le commentaire peut s'arreter sur fin de commentaire.
      # ou implicitement sur guillemets ou retour a la ligne
      'INCOMMENT' => qr{\G([*]/|/|[*]|\n|[^/*\n]*)}sm ,
      # La chaine peut s'arreter
      # implicitement sur guillemets ou retour a la ligne
      'INSTRING' => qr{\G(\n|\"|\'|[^\n\"\']*)}sm ,
      'INTEMPLATE' => qr{\G(\n|\`|\$\{|\{|\}|[^\n\`\$\{\}]*)}sm ,
      # the global split cut into [/*]* pattern.
      # In case of regexp, we want to detect signle /, even when there are
      # several concatened. So cut locally into "/"
      'INREGEXP' => qr{\G(/|\n|[^/\n]*)}sm ,
    );

  # Initial state
  # -------------

  if (($filename =~ /\.js$/im ) && ((! defined $forceHTML) || (! $forceHTML)) ) {
    # The code is considered as pure HTML
    $state = 'INCODE';
    $next_state = $state;
  }
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
  $context->{'nbServerTag'} = 0;

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
      #$stripJSTiming->markTimeAndPrint('--iter in split: ' . $part . '/' . $#parts  . '  --'); # timing_filter_line
      my $reg ;

      while  (
        # Mettre a jour l'expression rationnelle en fonction du pattern,
        # a chaque iteration.
        $reg =  $states_patterns{$state} ,
        $partie  =~ m/$reg/g )
      {
        my $element = $1;  # un morceau de fichier petit
        next if ( $element eq '') ;
        $espaces = $element ; # les retours a la ligne correspondant.
        #$stripJSTimingLoop->markTimeAndPrint('--iter in split internal--'); # timing_filter_line
        $espaces = garde_newlines($espaces) ;
        #$espaces = '';
        #$espaces =~ s/\S/ /gsm ;
        #localTrace "debug_chaines",  "state: $state: working with  !!$element!! \n"; # traces_filter_line

        $context->{'element'} = $element;
        $context->{'blanked_element'} = $espaces;


        # Application du traitement associe a l'etat courant
	if ( $state eq 'IN_HTML' )
	{
	  treat_HTML($context, $vues);
	}
        elsif ( $state eq 'IN_COMMENT_HTML' )
        {
          treat_COMMENT_HTML($context, $vues);
        }
        elsif ( $state eq 'IN_SERVER' )
        {
          treat_SERVER($context, $vues);
        }
        elsif ( $state eq 'INCODE' )
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
        elsif ( $state eq 'INTEMPLATE' )
        {
          separer_code_commentaire_chaine_INTEMPLATE($context, $vues);
        }
	elsif ( $state eq 'INREGEXP' )
        {
          separer_code_commentaire_chaine_INREGEXP($context, $vues);
        }

        $vues->commit ( $position);
        $position += length( $element) ;


        # Trace des changements d'etat de l'automate
        if ( defined $options->{'--debug_stript_states'} ) #: gain de 5 secondes sur 18 en commentant la trace suivante. # traces_filter_line
        {                                                                                                                # traces_filter_line
          localTrace ('debug_stript_states', ' separer_code_commentaire_chaine, passage de ' . $state . ' vers ' . $context->{'next_state'} . ' sur !<<'  . $context->{'element'} . '>>!' . "\n") ;                                                                                                # traces_filter_line
        }                                                                                                                # traces_filter_line
        #localTraceTab ('debug_stript_states', # traces_filter_line
          #[ ' separer_code_commentaire_chaine, passage de ' , $state , ' vers ' , $next_state , ' sur !<<'  , $element , '>>!' , "\n" ]) ; # traces_filter_line

        # Passage de l'etat courant a l'etat suivant
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

    $stripJSTiming->markTimeAndPrint('--done--') if ($b_timing_strip); # timing_filter_line
    my @return_array ;
    if (($state ne 'IN_HTML') && (not $state eq 'INCODE'))
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

#-------------------------------------------------------------------------------
# DESCRIPTION: Traitement associe a l'etat IN_HTML
#-------------------------------------------------------------------------------
sub treat_HTML($$)
{
  my ($context, $vues)=@_;

  my $next_state = $context->{'next_state'};
  my $blanked_element = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $string_buffer = $context->{'string_buffer'};

  $context->{'back'} = 'IN_HTML' ;

  if ( $element =~  /$htmlOpenTag/im )
  {
    $next_state = 'INCODE';

    $expected_closing_pattern = $htmlCloseTag ;
    $vues->append( 'comment_a',  $blanked_element );
    $vues->append( 'code_a',  $blanked_element );
    $vues->append( 'mix_a',  $blanked_element );
  }
  if ( $element eq '<!--' )
  {
    $next_state = 'IN_COMMENT_HTML';

    $expected_closing_pattern = '-->';
    $vues->append( 'comment_a',  $blanked_element );
    $vues->append( 'code_a',  $blanked_element );
    $vues->append( 'mix_a',  $blanked_element );
  }
  else {
    $vues->append( 'code_a',  $blanked_element );
    $vues->append( 'mix_a',  $blanked_element );
    $vues->append( 'comment_a',  $blanked_element );
  }

  $context->{'string_buffer'} = $string_buffer;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

sub treat_COMMENT_HTML($$)
{
  my ($context, $vues)=@_;

  my $next_state = $context->{'next_state'};
  my $blanked_element = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $string_buffer = $context->{'string_buffer'};

  $context->{'back'} = 'IN_HTML' ;

  if ( $element eq '-->' )
  {
    $next_state = 'IN_HTML';

    $expected_closing_pattern = '' ;
    $vues->append( 'comment_a',  $blanked_element );
    $vues->append( 'code_a',  $blanked_element );
    $vues->append( 'mix_a',  $blanked_element );
  }
  else {
    $vues->append( 'code_a',  $blanked_element );
    $vues->append( 'mix_a',  $blanked_element );
    $vues->append( 'comment_a',  $blanked_element );
  }

  $context->{'string_buffer'} = $string_buffer;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

sub treat_SERVER($$)
{
  my ($context, $vues)=@_;

  my $next_state = $context->{'next_state'};
  my $blanked_element = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $string_buffer = $context->{'string_buffer'};
  my $nb_lines_in_server = $context->{'nb_lines_in_server'};

  $context->{'back'} = 'IN_SERVER' ;

  if ( $element =~ /$serverCloseTag/s )
  {
    # Server tab are only parser when they are into javascript code.
    # So, each time a server balise ends, the next context is Javascript CODE.
    # !!! Be careful if the servers tags inside HTML should be treated later.
    $next_state = 'INCODE';

    $expected_closing_pattern = '' ;
    $vues->append( 'comment_a',  $blanked_element );
    $vues->append( 'mix_a',  $blanked_element );
    $vues->append( 'code_a',  ' SERVER_TAG_'.($context->{'nbServerTag'}).' ');
    $context->{'nbServerTag'}++;
    if ($nb_lines_in_server > 0) {
      $vues->append( 'code_a',  "\n"x $nb_lines_in_server);
    }
  }
  else {
	  #$vues->append( 'code_a',  $blanked_element );
    $vues->append( 'mix_a',  $blanked_element );
    $vues->append( 'comment_a',  $blanked_element );

    $nb_lines_in_server += () = $element =~ /\n/g;
  }

  $context->{'string_buffer'} = $string_buffer;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
  $context->{'nb_lines_in_server'} = $nb_lines_in_server;
}

# traitement associe a l'etat INCODE
sub separer_code_commentaire_chaine_INCODE($$)
{
  my ($context, $vues)=@_;

  my $next_state = $context->{'next_state'};
  my $espaces = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $string_buffer = $context->{'string_buffer'};
  my $expectingRegexpOption = $context->{'expectingRegexpOption'};
  my $previous_non_comment = $context->{'previous_non_comment'};
  my $RE_context = $context->{'RE_context'};
  my $nb_lines_in_string = $context->{'line_in_string'};
  $context->{'back'} = 'INCODE' ;

  # If the last context was INREGEXP, store the regexp
  # ---------------------------------------------------
  if ($expectingRegexpOption) {

    # g, i, m and y are option that can follow the end of a regexp.
    # When encountered after a REGEXP context, add them to the regexp.
    if ($element =~ /^([gimy]+)(.*)/) {

      # options of the regexpr are in $1
      $string_buffer .= $1;
      $vues->append( 'comment_a', garde_newlines($1));

      # character of the pattern that may not belong to the regexp are in $2
      # update the element and blanked element.
      $element = $2;
      $espaces = garde_newlines($2);
    }

    my $RE_id = StringStore( $RE_context, $string_buffer, 'REGEXP_' );

    $vues->append( 'code_a',  $StrPadding.$RE_id.$StrPadding) ;

    if ($nb_lines_in_string > 0) {
      $vues->append( 'code_a',  "\n"x$nb_lines_in_string);
      $vues->append( 'mix_a',  "\n"x$nb_lines_in_string);
    }

    $vues->append( 'mix_a', $RE_id) ;

    $string_buffer = '' ;
    $expectingRegexpOption = 0;
   }

   # nominal treatment.
   # -------------------
            if ( $element =~ /$htmlCloseTag/i )
            {
                $next_state = 'IN_HTML';
	        $vues->append( 'code_a',  $espaces );
	        $vues->append( 'mix_a',  $espaces );
	        $vues->append( 'comment_a',  $espaces );
            } 
	    elsif ( $element =~ /$serverOpenTag/i )
            {
                $next_state = 'IN_SERVER';
	        $vues->append( 'code_a',  $espaces );
	        $vues->append( 'mix_a',  $espaces );
	        $vues->append( 'comment_a',  $espaces );
		$context->{'nb_lines_in_server'} = 0;
            } 
	    elsif ( $element eq '/*' )
            {
                $next_state = 'INCOMMENT'; $expected_closing_pattern = '*/' ;
                $vues->append( 'comment_a',  $element);
                $vues->append( 'code_a' , ' '.$espaces);
                $vues->append( 'mix_a' , $element);
            }
            elsif ( $element eq '//' )
            {
                $next_state = 'INCOMMENT'; $expected_closing_pattern = "\n" ;
                $vues->append( 'code_a' , $espaces);
                $vues->append( 'mix_a' , '/*');
                $vues->append( 'comment_a',  $element);
            }
            elsif ( $element eq '"' )
            {
                $next_state = 'INSTRING'; $expected_closing_pattern = '"' ;
                $string_buffer = $element ; $vues->append( 'comment_a', $espaces);
		$nb_lines_in_string = 0;
            }
            elsif ( $element eq '\'' )
            {
                $next_state = 'INSTRING'; $expected_closing_pattern = '\'' ;
                $string_buffer = $element ; $vues->append( 'comment_a', $espaces);
		$nb_lines_in_string = 0;
            }
            
            # interpolated strings
            elsif ( $element eq '`' )
            {
                $next_state = 'INTEMPLATE'; $expected_closing_pattern = '`' ;
                $string_buffer = $element ; $vues->append( 'comment_a', $espaces);
		$nb_lines_in_string = 0;
            }
            
	    elsif (($element eq '/') && ($previous_non_comment =~ /(?:\breturn|[=(:\[,?!;])\s*$/m))
	    {
                $next_state = 'INREGEXP'; 
                $string_buffer = $element ; $vues->append( 'comment_a', $espaces);
		$nb_lines_in_string = 0;
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
  $context->{'RE_context'} = $RE_context;
  $context->{'expectingRegexpOption'} = $expectingRegexpOption;
  $context->{'string_buffer'} = $string_buffer;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

# traitement associe a l'etat INCOMMENT
sub separer_code_commentaire_chaine_INCOMMENT($$)
{
  my ($context, $vues)=@_;

  my $next_state = $context->{'next_state'};
  my $espaces = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
            # RQ: dans la vue Mix, tous les commentaires multilignes sont mis au format
            # monoligne, et les commentaires "//" sont transformes en "/* ... */".
            # Pour cette raison, les eventuelles sequences "/*" ou "*/" qui traineraient dans
            # un commentaire "//" sont supprimes ...

            #localTrace undef "receive: <$element>, waiting <$expected_closing_pattern> \n"; # traces_filter_line
            if ( $element eq $expected_closing_pattern )
            {
              if ($expected_closing_pattern eq "\n")
              {
                  $vues->append( 'mix_a' , "*/\n");
              }
              else
              {
                  $vues->append( 'mix_a' , $element);
              };
                $next_state = 'INCODE'; $expected_closing_pattern = '' ;
                $vues->append( 'code_a' , $espaces);
              $vues->append( 'comment_a', $element);
            }
            else
            {
                # Suppression des "/*" et  "*/"  qui pourraient trainer ...

                $vues->append( 'code_a' , $espaces);
                $vues->append( 'comment_a', $element);
                if ($element eq "\n")
                {
                  $vues->append( 'mix_a' , "*/\n/*");
                }
                else {
                  #if ( $element =~ m{\A[/*]+\z} )
                  my %aSupprimer =  (  '/' =>1,  '*'=>1,  '*/'=>1   );
                  #if ( ( $element eq '/'  ) || ( $element eq '*' ) || ( $element eq '*/' ) )
                  if ( exists $aSupprimer{$element} )
                  {
                    $vues->append( 'mix_a' , ' ');
                  }
                  else
                  {
                    $vues->append( 'mix_a' , $element);
                  }

                  #$element =~ s/(\/\*|\*\/)/ /g ; # FIXME: consomme entre 2 et 3 secondes sur 20.
                  #$Mix .= $element;
                }
            }
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

# traitement associe a l'etat INSTRING
sub separer_code_commentaire_chaine_INSTRING($$)
{
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

            #si la fin de chaine est precedee d'un nombre pair d'antislash:
            #il s'agit bien d'une fin de chaine.
            if ( ( $element eq $expected_closing_pattern ) && ( $slaEven eq '' ))
            {
                $next_state = 'INCODE'; $expected_closing_pattern = '' ;
              $string_buffer .= $element ;
                $vues->append( 'comment_a', $espaces);

              my $string_id = StringStore( $string_context, $string_buffer );

                # Dans la vue "code", la chaine est remplace par CHAINE_<id>_<occurence> ...HIGHLIGHT-1614
                # Finalement on ne concatene pas le numero d'occurence.
              $vues->append( 'code_a' , $StrPadding.$string_id.$StrPadding);
              $vues->append( 'mix_a' , $string_id);

	      if ($nb_lines_in_string > 0) {
                $vues->append( 'code_a' , "\n"x$nb_lines_in_string);
                $vues->append( 'mix_a'  , "\n"x$nb_lines_in_string);
	      }


              $string_buffer = '' ;
            }

	    #---- RECORD STRING CONTENT

            else
            {
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

sub separer_code_commentaire_chaine_INTEMPLATE($$)
{
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
            
	$string_buffer =~ m{(\\\\)*(\\?)\z}sm ; #autant d'antislash consecutifs que possible.
	$slaPeer = $1 ; # Un nombre pair d'antislash
	$slaEven = $2 ;# Un antislash, si impair

	$slaEven = '' if not defined $slaEven ;
	$slaPeer = '' if not defined $slaPeer ;

	#---- FIN DE CHAINE

	#si la fin de chaine est precedee d'un nombre pair d'antislash:
	#il s'agit bien d'une fin de chaine.
	if ( $element eq '`' ) {
		
		# nested template/code context !!!
		if (defined $context->{'interpolated_context'}) {
			if ($context->{'interpolated_context'}->[-1] eq 'code')  {
				# new nested template level
				push @{$context->{'interpolated_context'}}, 'template';
			}
			else {
				# leave nested template level
				pop @{$context->{'interpolated_context'}};
			}
		}

		# non escaped backtick ==> end of template string
		elsif  ( $slaEven eq '' ) {
			$next_state = 'INCODE'; $expected_closing_pattern = '' ;
			$string_buffer .= $element ;
			$vues->append( 'comment_a', $espaces);

			my $string_id = StringStore( $string_context, $string_buffer );
#print STDERR "TEMPLATE = $string_buffer\n";

			# Dans la vue "code", la chaine est remplace par CHAINE_<id>_<occurence> ...HIGHLIGHT-1614
			# Finalement on ne concatene pas le numero d'occurence.
			$vues->append( 'code_a' , $StrPadding.$string_id.$StrPadding);
			$vues->append( 'mix_a' , $string_id);

			if ($nb_lines_in_string > 0) {
				$vues->append( 'code_a' , "\n"x$nb_lines_in_string);
				$vues->append( 'mix_a'  , "\n"x$nb_lines_in_string);
			}

			$string_buffer = '' ;
		}
		
		# escaped backtick ...
		else {
			$string_buffer .= $element ;
			# update only comment view. Mix and code view will be updated when the string will be terminated,
			# because we need the ID of the string ...
			$vues->append( 'comment_a', $espaces);
		}
	}
	
	# nested code context
	elsif ($element eq '${') {
		if (defined $context->{'interpolated_context'}) {
			push @{$context->{'interpolated_context'}}, 'code';
		}
		else {
			$context->{'interpolated_context'} = ['code'];
		}
		$string_buffer .= $element;
	}
	elsif ($element eq '}') {
		if ((defined $context->{'interpolated_context'}) && ($context->{'interpolated_context'}->[-1] eq 'code'))  {
			pop @{$context->{'interpolated_context'}};
			if (scalar @{$context->{'interpolated_context'}} == 0) {
				$context->{'interpolated_context'} = undef;
			}
		}
		$string_buffer .= $element;
	}
	elsif ($element eq '{') {
		if ((defined $context->{'interpolated_context'}) && ($context->{'interpolated_context'}->[-1] eq 'code'))  {
			push @{$context->{'interpolated_context'}}, 'code';
		}
		$string_buffer .= $element;
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

# traitement associe a l'etat INREGEXP
sub separer_code_commentaire_chaine_INREGEXP($$)
{
  my ($context, $vues)=@_;

  my $next_state = $context->{'next_state'};
  my $espaces = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $string_buffer = $context->{'string_buffer'};
  my $nb_lines_in_string = $context->{'line_in_string'};
  my $RE_context = $context->{'RE_context'};
  my $expectingRegexpOption = $context->{'expectingRegexpOption'};

  my $slaPeer  ; # Un nombre pair d'antislash
  my $slaEven  ; # Un antislash, si impair

  $string_buffer =~ m{(\\\\)*(\\?)\z}sm ; #autant d'antislash consecutifs que possible.
  
  $slaPeer = $1 ; # Un nombre pair d'antislash
  $slaEven = $2 ; # Un antislash, si impair

  # for robustness ...
  $slaEven = '' if not defined $slaEven ;
  $slaPeer = '' if not defined $slaPeer ;

  # END OF THE REGEXP
  if  (($element eq '/') && ($slaEven eq ''))
  {
    $next_state = 'INCODE'; $expected_closing_pattern = '' ;

    $string_buffer .= $element ;
    $vues->append( 'comment_a', $espaces);

    $expectingRegexpOption = 1;
  }

  #---- RECORD STRING CONTENT

  else
  {
    if ( $element eq "\n") {
      $nb_lines_in_string++;
  }
  $string_buffer .= $element ;
  # Dans ce cas, on ne repercute pas les blancs dans la vue code.
    $vues->append( 'comment_a', $espaces);
  }

  if ($element =~ /\S/s) {
    $context->{'previous_non_comment'} = $element;
  }
  $context->{'expectingRegexpOption'} = $expectingRegexpOption;
  $context->{'RE_context'} = $RE_context;
  $context->{'string_buffer'} = $string_buffer;
  $context->{'line_in_string'} = $nb_lines_in_string;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

sub removeHTMLComment($) {
  my $r_buf = shift;
  my $new_buf = "";

  # Context value :
  # 0 : CODE
  # 1 : COMMENT
  # 2 : STRING
  my $context = 0;
  my $closing_pattern = "";
  my $item = "";
  while ($$r_buf =~ /\G(<!--|-->|\\"|\\'|\\|"|'|<|>|!|-|[^\\"'<>!-]*)/g) {
    $item = $1;

    # context CODE
    if ($context == 0) {
      if ($item eq '<!--') {
        $context = 1;
	$item =~ s/[^\n]//g;
	$new_buf .= $item;
      } 
      elsif (($item eq '"') || ($item eq "'")){
	$context = 2;
	$closing_pattern=$item;
        $new_buf .= $item;
      }
      else {
        $new_buf .= $item;
      }
    }

    # context COMMENT
    elsif ($context == 1) {
      if ($item eq '-->') {
        $context = 0;
      }
      $item =~ s/[^\n]//g;
      $new_buf .= $item;
    }

    # context STRING
    elsif ($context == 2) {
      if ($item eq $closing_pattern) {
        $context = 0;
	$closing_pattern="";
      }
      $new_buf .= $item;
    }
  }

  $$r_buf = $new_buf;
}

# analyse du fichier
sub StripJS($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);
#print STDERR join ( "\n", keys ( %{$options} ) );
    configureLocalTraces('StripJS', $options); # traces_filter_line
    my $stripJSTiming = new Timing ('StripJS', Timing->isSelectedTiming ('Strip'));

    localTrace ('verbose',  "working with  $filename \n"); # traces_filter_line
    my $text = \$vue->{'text'};
    $stripJSTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line

    # Remove 'use strict' because it cinflicts with MisplacedVarStatement when
    # placed before a "var" instruction : It produce a violation whereas it is
    # not an instruction.
    # Another way would be replacing it with a pseudo-instruction like
    # HIGHLIGHT_use_strict, and associate it to a dedicated node
    $vue->{'text'} =~ s/(?:"use strict"|'use strict')\s*;//g;

    #  PHP prepro for .php files
    #---------------------------
    if ($filename =~ /\.php\d*$/) {
      # pre-process PHP ...
      my $ref_sep = StripPHP::separer_code_commentaire_chaine(\$vue->{'text'}, $options);
      if ( $ref_sep->[6] gt 0) {
        return Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, "syntax error while trying to preprocess PHP layer ...");
    }
      $text = $ref_sep->[4];
    }

    # Robustness: if the file begins with a HTML tag, then assume it is an HTML
    #              Content
    # --------------------------------------------------------------------------
    my $html_content = 0;
    if ($$text =~ /\A\s*<[^\%\?]/s) {
       $html_content = 1;
    }

    my $ref_sep = separer_code_commentaire_chaine($text, $options, $filename, $html_content);

    # Robustness : if the file has not been detected as HTML but still contains
    #              a JS HTML tag, the re-preprocess it !!!
    #              (this can occurs if the first tag of an HTML file is <%, <?
    #              or <?php : in this case, the HTML detection a failed in the
    #              previous phase, because <? and <% are not characteric of a
    #              HTML content !!!
    # --------------------------------------------------------------------------
    if (${$ref_sep->[0]} =~ /<\s*script\b/i) {
      # If the code without code and comment has JS_openning tag, then re-strip
      # it with enforcing HTML content analysis.
      $ref_sep = separer_code_commentaire_chaine($text, $options, $filename, 1);
    }

    $stripJSTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

    my($c, $comments, $rt_strings, $MixBloc, $err) = @{$ref_sep} ;

    # If the file is not a pure .js, then do some specific treatments
    if ($filename !~ /\.js$/) {

      # check if the JS content is minified.
      my $res=JS::CheckJS::checkMinified($c, $options);
      if ( defined $res )
      {
        return Erreurs::FatalError( Erreurs::ABORT_CAUSE_WRAPPED, $couples, $res);
      }

      # remove HTML comments...
      if ($$text =~ /<!--/) {
        removeHTMLComment($text);
      }
    }

    $vue->{'comment'} = $$comments;
    $vue->{'HString'} = $rt_strings;
    $vue->{'code_with_prepro'} = $$c;
    $vue->{'MixBloc'} = $$MixBloc;
    StripUtils::agglomerate_C_Comments($MixBloc, \$vue->{'agglo'});

    if ( $err gt 0) {
      my $message = 'Erreur fatale dans la separation des chaines et des commentaires';
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', $message);
      return Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    }

    if ($$c !~ /\S/s ) {
      return Erreurs::FatalError( Erreurs::ABORT_CAUSE_NOT_ENOUGH_CODE, $couples, "No javascript found");
    }

    $vue->{'code'} = $$c;
    if ( defined $options->{'--dumpstrings'})
    {
      dumpVueStrings(  $rt_strings , $STDERR );
    }
    $stripJSTiming->dump('StripJS') if ($b_timing_strip); # timing_filter_line
    return 0;
}

1; # Le chargement du module est okay.

