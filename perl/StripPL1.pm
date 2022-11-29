#----------------------------------------------------------------------#
    #                 @CAST 2011                                       #
#----------------------------------------------------------------------#
# DESCRIPTION: Ce paquetage fournit une separation du code et
# des commentaires d'un source pour le langage PL1
#----------------------------------------------------------------------#

package StripPL1 ;

use strict;
use warnings;
use Carp::Assert;                                                               # traces_filter_line
use Timing;                                                                     # timing_filter_line
use StripUtils;

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                 );
use Prepro;
use AnaUtils;
use Vues;

# prototypes publics
sub StripPL1($$$$);

# prototypes prives
sub separer_code_commentaire_chaine($$);
sub separer_code_commentaire_chaine_INCODE($$);
sub separer_code_commentaire_chaine_INCOMMENT($$);
sub separer_code_commentaire_chaine_INSTRING($$);
sub separer_code_commentaire_chaine_INPREPRO($$);
sub StripSQL($$);
sub splitAtPeer ($$$$);
sub StripAsm($$);


my $x00a3 = pack("U0C*", 0xc2, 0xa3);       # U+00A3 POUND SIGN

# Initialisation du module StripUtils # traces_filter_line
# avec traces desactivees.            # traces_filter_line
StripUtils::init('StripPL1', 0);      # traces_filter_line

#-------------------------------------------------------------------------------
# DESCRIPTION: Automate de tri du contenu du fichier en trois parties:
# 1/ code
# 2/ commentaires
# 3/ chaines
#-------------------------------------------------------------------------------
sub separer_code_commentaire_chaine($$)
{
  my ($source, $options) = @_;
  my %hContext=();

  # Le context contiendra differents attributs sur l'etat courant de l'analyse:
  #  $context->{'code_a'}                    # tableau  de morceaux de code
  #  $context->{'mix_a'}                     # tableau pour vue mixte
  #  $context->{'code'}                      # buffer de code
  #  $context->{'comment'}                   # buffer de commentaire
  #  $context->{'mix'}                       # buffer mixte
  #  $context->{'next_state'}                # prochain etat
  #  $context->{'expected_closing_pattern'}  # pattern attendu
  #  $context->{'element'}                   # variable: bout de source en cours d'analyse
  #  $context->{'blanked_element'}           # variable: blancs avec retours a la ligne.
  #  $context->{'string_context'}
  my $context=\%hContext;

  my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);

  my $stripPL1Timing = new Timing ('StripPL1:separer_code_commentaire_chaine', Timing->isSelectedTiming ('Strip')); 
  my $buffer_d_entree = $$source;
  my $blanked_element = undef;
  my $code = '';
  my $comment = '';
  my $Mix = '';
  my $state = 'INCODE' ;
  my $next_state = $state ;

  #.................... Caractere attendu en fin de pattern string/comment/code
  my $expected_closing_pattern = '';

  my $string_buffer = '';


  my %strings_values = () ;
  my %strings_counts = () ;
  my %hash_strings_context = (
      'nb_distinct_strings' => 0,
      'strings_values' => \%strings_values,
      'strings_counts' => \%strings_counts  ) ;
  my $string_context = \%hash_strings_context;

  $stripPL1Timing->markTimeAndPrint ('--init--') if ($b_timing_strip);                    # timing_filter_line
  # recherche des guillemets et retours a la ligne
  #
  #  (?:\(\w+\))?              => (\w)           : un nombre entre parenthèse (nb repetition) ou rien.
  #  (?:[\"]{1,2}|[\']{1,2})   => ", "", ' ou '' : un ou deux délimiteur de chaine.
  #  \w*                       => \w             : un alpha-numerique ou rien (i.e le format de la constante)
  my @parts = split (  /([\/*]+|(?:\(\w+\))?(?:[\"]{1,2}|[\']{1,2})\w*|%|;|\n)/ , $buffer_d_entree );
  #my @parts = split (  /([\/*]+|(?:\(\w+\))[\"\']|[\"\']\w*|\n)/ , $buffer_d_entree );

  $stripPL1Timing->markTimeAndPrint ('--split--') if ($b_timing_strip);                   # timing_filter_line
  my $stripPL1TimingLoop = new Timing ('StripPL1 internal Loop', Timing->isSelectedTiming ('Strip'));

  # definition du pattern recherche, en fonction de l'etat courant.
  my %states_patterns = (
    # Le code peut s'arreter sur debut de commentaire.
    # ou implicitement sur guillemets ou retour a la ligne
    #'INCODE' =>  qr{\G(/[*]|//|/|[*]|[^/*]*)}sm ,
    'INCODE' =>  qr{\G(/[*]|//|[*]/|/|[*]|[^/*]*)}sm ,
    # Le commentaire peut s'arreter sur fin de commentaire.
    # ou implicitement sur guillemets ou retour a la ligne
    'INCOMMENT' => qr{\G([*]/|/|[*]|[^/*]*)}sm ,
    # La chaine peut s'arreter
    # implicitement sur guillemets ou retour a la ligne
    'INSTRING' => qr{\G(.*)\z}sm ,
    # Le preprocessing peut s'arreter sur debut de commentaire
    # ou implicitement sur guillemets ou retour a la ligne
    'INPREPRO' =>  qr{\G(/[*]|//|/|[*]|[^/*]*)}sm ,
  );

  # Etat initial.
  my $vues = new Vues( 'text' ); # creation des nouvelles vues a partir de la vue text
  #$vues->setOptionIsoSize(); # config pour (certaines) vues de meme taille

  $vues->declare('code_a');
  $vues->declare('comment_a');
  $vues->declare('mix_a');
  $vues->declare('prepro_a');
  $vues->declare('sansprepro_a');

  $context->{'code'} = $code;
  $context->{'comment'} = $comment;
  $context->{'mix'} = $Mix;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;

  # Cette donnee sert a revenir a l'etat code ou inprocess, suite a la fin 
  # d'une chaine de caracteres.
  # Vu l'anomalie 225, on peut se demander s'il est judicieux d'extraire les 
  # chaines de caracteres des directives de compilation des cette premiere 
  # passe.
  $context->{'back'} = 'INCODE';

  $context->{'string_context'} = $string_context;
  my $position=0;

  my $nb_iter = $#parts ;

  for my $partie ( @parts )
  {
    localTrace (undef, "Utilisation du buffer:                           " . $partie . "\n" ); # traces_filter_line
    # $stripPL1Timing->markTimeAndPrint ('--iter in split: ' . $part . '/' . $#parts  . '  --'); # timing_filter_line
    my $reg ;
    while  (
        # Mettre a jour l'expression rationnelle en fonction du pattern,
        # a chaque iteration.
        $reg =  $states_patterns{$state} ,
        $partie  =~ m/$reg/g )
    {
      my $element = $1;  # un morceau de fichier petit
      next if ( $element eq '') ;
      my $blanked_element = $element ; # les retours a la ligne correspondant.
      # $stripPL1TimingLoop->markTimeAndPrint ('--iter in split internal--');   # timing_filter_line

      # Creation de la chaine debarassee des caracteres non blancs, pour suppression.
      $blanked_element = garde_newlines($blanked_element) ;
      #localTrace "debug_chaines",  "state: $state: working with  !!$element!! \n"; # traces_filter_line

      my $expected_closing_pattern = $context->{'expected_closing_pattern'} ;

      if ( ( $context->{'back'} eq 'INPREPRO' ) and ( $expected_closing_pattern ne "\n" ) )
      {
         # On choisit de maniere arbitraire,
         # de considerer que le preprocessing d'une maniere generale,
         # et les define en particulier contiennent du code C.
         # Ils peuvent contenir des commentaires multi-lignes;
         # on choisit de remplacer ces commentaires multi-lignes par \\ n
         my $blanked_element2 = $blanked_element;
         $blanked_element2 =~ s/\n/\\\n/gsm ;
         $context->{'blanked_element2'} = $blanked_element2;
      }
      else
      {
        $context->{'blanked_element2'} = $blanked_element;
      }

      $context->{'element'} = $element;
      $context->{'blanked_element'} = $blanked_element;

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
      elsif ( $state eq 'INPREPRO' )
      {
        separer_code_commentaire_chaine_INPREPRO($context, $vues);
      }
      $vues->commit ( $position);
      $position += length( $element) ;

# traces_filter_start

      # Trace des changements d'etat de l'automate
      if ( defined $options->{'--debug_stript_states'} )
      #: gain de 5 secondes sur 18 en commentant la trace suivante.
      {
        localTrace ('debug_stript_states', ' separer_code_commentaire_chaine, passage de ' . $state . ' vers ' . $context->{'next_state'} . ' sur !<<'  . $context->{'element'} . '>>!' . "\n") ;
      }
      #localTraceTab ('debug_stript_states',
      #[ ' separer_code_commentaire_chaine, passage de ' , $state ,
      #     ' vers ' , $next_state , ' sur !<<'  , $element , '>>!' , "\n" ]) ;

# traces_filter_end

      # Passage de l'etat courant a l'etat suivant
      $state = $context->{'next_state'};
    }
  }
  $next_state = $context->{'next_state'};
  $blanked_element = $context->{'blanked_element'};
  $expected_closing_pattern = $context->{'expected_closing_pattern'};

  # Consolidation de la vue comment.
  $comment = $vues->consolidate('comment_a');

  # Consolidation de la vue code.
  $code = $vues->consolidate('code_a');

  # pour supprimer les backslash <fin de ligne> ajoutes pour traiter les
  # commentaires dans les directives
  #while ( $code =~ s/\\([\ \t]*)\n([\ \t]*)([^\n]*\n)/ $1$2balise isoscope $x00a3$3/g ) {}
  #while ( $code =~ s/balise isoscope $x00a3(.*?\n)/$1\n/g ) {}

  # Consolidation de la vue prepro.
  my $prepro = $vues->consolidate('prepro_a');

  # pour supprimer les backslash <fin de ligne> ajoutes pour traiter les
  # commentaires dans les directives
  # while ( $prepro =~ s/\\([\ \t]*)\n([\ \t]*)([^\n]*\n)/ $1$2balise isoscope $x00a3$3/g ) {}
  #while ( $prepro =~ s/balise isoscope $x00a3(.*?\n)/$1\n/g ) {}

  # Consolidation de la vue sansprepro.
  my $sansprepro = $vues->consolidate('sansprepro_a');

  # Consolidation de la vue mix.
  $Mix = $vues->consolidate('mix_a');

  my $status_strip = 0;

  $stripPL1Timing->markTimeAndPrint ('--done--') if ($b_timing_strip);          # timing_filter_line

  # Gestion du statut d'erreur
  my @return_array ;
  if ( (not $state eq 'INCODE')
      and (not $state eq 'INPREPRO') )
  {
    if (not ($expected_closing_pattern eq "\n"))
    {
      # tolerance pour les fins de ligne manquante en fin de fichier dans un commentaire '//'
      warningTrace (undef,  "warning: fin de fichier en l'etat $state \n");     # traces_filter_line
      if ($state eq 'INSTRING')
      {
        warningTrace (undef,  "chaine non termine:\n" . $string_buffer ."\n" ); # traces_filter_line
      }
      $status_strip = 1;
    }
  }
  @return_array =  ( \$code, \$comment, \%strings_values, \$Mix, \$prepro, \$sansprepro, $status_strip);
  return \@return_array ;
}


sub finalyze_string($$$$) {
    my ($string_buffer, $context, $vues, $blanked_element) = @_ ;

    $vues->append( 'comment_a',  $blanked_element  );

    my $string_id = StringStore( $context->{'string_context'}, $string_buffer );

    # Dans la vue "code", la chaine est remplace par CHAINE_<id>_<occurence> .. # traces_filter_line
    #                $code .= $string_id . '_' . $nb ;                          # traces_filter_line
    # Finalement on ne concatene pas le numero d'occurrence.                    # traces_filter_line
    $vues->append( 'code_a',  $string_id  );
    if ( $context->{'back'} eq 'INPREPRO' )
    {
      $vues->append( 'prepro_a',  $string_id  );
      $vues->append( 'sansprepro_a',  $blanked_element  );
    }
    else
    {
      $vues->append( 'prepro_a',  $blanked_element  );
      $vues->append( 'sansprepro_a',  $string_id  );
    }
    $vues->append( 'mix_a',  $string_id  );
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Traitement associe a l'etat INCODE
#-------------------------------------------------------------------------------
sub separer_code_commentaire_chaine_INCODE($$)
{
  my ($context, $vues)=@_;

  my $next_state = $context->{'next_state'};
  my $blanked_element = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $Mix = $context->{'mix'};
  my $string_buffer = $context->{'string_buffer'};

  $context->{'back'} = 'INCODE' ;

  if ( $element eq '/*' )
  {
    $next_state = 'INCOMMENT'; $expected_closing_pattern = '*/' ;
    $vues->append( 'comment_a',  $element );
    # Au moins un blanc a la place d'un commentaire ...
    $vues->append( 'code_a',  ' '.$blanked_element );
    $vues->append( 'sansprepro_a',  $blanked_element );
    $vues->append( 'mix_a',  $element );
  }
  elsif ( $element eq '*/' )
  {
    # This is the closure of non-opened comment. This is an error that is
    # tolerated by the PL1 compilator. This pattern should be filtered (blanked)
    # in order not to incommode the analysis.
print "STRIP WARNING : found closure of non-opened comment\n";
    $vues->append( 'code_a',  $blanked_element );
    $vues->append( 'sansprepro_a',  $blanked_element );
    $vues->append( 'prepro_a',  $blanked_element );
    $vues->append( 'mix_a',  $blanked_element );
    $vues->append( 'comment_a',  $blanked_element );
  }
  elsif ( $element eq '//' )
  {
    $next_state = 'INCOMMENT'; $expected_closing_pattern = "\n" ;
    $vues->append( 'code_a',  $blanked_element );
    $vues->append( 'sansprepro_a',  $blanked_element );
    $vues->append( 'mix_a',  '/*' );
    $vues->append( 'comment_a',  $element );
  }
  elsif ( $element =~ /\"\"|\'\'/ )
  {
     finalyze_string($element, $context, $vues, $blanked_element);
  }
  elsif ( $element =~ /\"/ )
  {
    $next_state = 'INSTRING'; $expected_closing_pattern = '"' ;
    $string_buffer = $element ;
    $vues->append( 'comment_a',  $blanked_element );
  }
  elsif ( $element =~ /\'/ )
  {
    $next_state = 'INSTRING'; $expected_closing_pattern = '\'' ;
    $string_buffer = $element ; 
    $vues->append( 'comment_a',  $blanked_element );
  }
  elsif ( $element =~ '^\s*%' )
  {
    $next_state = 'INPREPRO';
    # CAST 05/09/11 $vues->append( 'code_a',  $blanked_element ); 
    $vues->append( 'code_a',  $element ); 
    $vues->append( 'sansprepro_a',  $blanked_element );
    $vues->append( 'prepro_a',  $element );
    $vues->append( 'mix_a',  $blanked_element );
    $vues->append( 'comment_a',  $blanked_element );
    $context->{'lastprepro'} = $element;

    # By default, a prepro directive ends with ";". If it is a bloc directive like %PROCEDURE,
    # it will be detected later and the correct pattern (%END) will then be positionned.
    #
    # IMPORTANT: INPREPRO has its own expected_closing_pattern, because it shoult be not
    # be lost by changing the value if it were shared with other context. Indeed, PREPRO
    # directives can contain comments and strings, and then switch to these contexts.
    # So the expected pattern can't be shared with those two contexts...
    $context->{'prepro_expected_closing_pattern'} = ';';
  }
  else
  {
    $vues->append( 'code_a',  $element );
    $vues->append( 'sansprepro_a',  $element );
    $vues->append( 'prepro_a',  $blanked_element );
    $vues->append( 'mix_a',  $element );
    $vues->append( 'comment_a',  $blanked_element );
  }
  $context->{'string_buffer'} = $string_buffer;
  $context->{'mix'} = $Mix;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Traitement associe a l'etat INCOMMENT
#-------------------------------------------------------------------------------
sub separer_code_commentaire_chaine_INCOMMENT($$)
{
  my ($context, $vues)=@_;

  my $next_state = $context->{'next_state'};
  my $blanked_element = $context->{'blanked_element'};
  my $element = $context->{'element'};

  # sequence de fin de commentaire attendue
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $code = $context->{'code'};
  my $Mix = $context->{'mix'};
  # RQ: dans la vue Mix, tous les commentaires multi-lignes sont mis au format
  # mono-ligne, et les commentaires "//" sont transformes en "/* ... */".
  # Pour cette raison, les eventuelles sequences "/*" ou "*/" qui traineraient
  # dans un commentaire "//" sont supprimes ...

  #localTrace undef "receive: <$element>, waiting <$expected_closing_pattern> \n"; # traces_filter_line
  if ( $element eq $expected_closing_pattern )
  {
    if ($expected_closing_pattern eq "\n")
    {
      $vues->append( 'mix_a',  "*/\n" );
    }
    else
    {
      $vues->append( 'mix_a',  $element );
    };
    $next_state = $context->{'back'} ; $expected_closing_pattern = '' ;
    if ( ( $context->{'back'} eq 'INPREPRO' ) and ( $expected_closing_pattern ne "\n" ) )
    {
      $vues->append( 'code_a',  $context->{'blanked_element2'} );
      $vues->append( 'prepro_a',  $context->{'blanked_element2'} );
      $vues->append( 'sansprepro_a',  $context->{'blanked_element'} );
    }
    else
    {
      $vues->append( 'code_a',  $context->{'blanked_element2'} );
      $vues->append( 'prepro_a',  $context->{'blanked_element'} );
      $vues->append( 'sansprepro_a',  $context->{'blanked_element'} );
    }
    $vues->append( 'comment_a',  $element );
  }
  else
  {
    # Suppression des "/*" et  "*/"  qui pourraient trainer ...
    $vues->append( 'code_a',  $context->{'blanked_element2'} );
    $vues->append( 'prepro_a',  $context->{'blanked_element2'} );
    $vues->append( 'sansprepro_a',  $context->{'blanked_element'} );
    $vues->append( 'comment_a',  $element );
    if ($element eq "\n")
    {
                  $Mix .= "*/\n/*";
                  $vues->append( 'mix_a',  "*/\n/*" );
    }
    else
    {
      my %aSupprimer =  (  '/' =>1,  '*'=>1,  '*/'=>1   );
      if ( exists $aSupprimer{$element} )
      {
                    $vues->append( 'mix_a',  ' ' );
      }
      else
      {
                    $vues->append( 'mix_a',  $element );
      }
      # FIXME: $element =~ s/(\/\*|\*\/)/ /g ;
      # FIXME: consomme entre 2 et 3 secondes sur 20.
    }
  }
  $context->{'code'} = $code;
  $context->{'mix'} = $Mix;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Traitement associe a l'etat INSTRING
#-------------------------------------------------------------------------------
sub separer_code_commentaire_chaine_INSTRING($$)
{
  my ($context, $vues)=@_;

  my $next_state = $context->{'next_state'};
  my $blanked_element = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $code = $context->{'code'};
  my $Mix = $context->{'mix'};
  my $string_buffer = $context->{'string_buffer'};
  my $string_context = $context->{'string_context'};
  # car en C, les chaine peuvent etre multi-lignes.
  my $sla  ; # Un nombre pair d'antislash
  my $sla2  ;# Un antislash, si impair



  #--------------------------------------------------------------------
  # ANTI_SLASH management.
  #--------------------------------------------------------------------
  my $slash_is_special = 0; # specify if "\" is a quoted special character.

  if ($slash_is_special) # traces_filter_line
  {      # traces_filter_line

    # Autant d'antislash consecutifs que possible.
    $string_buffer =~ m{(\\\\)*(\\?)\z}sm ;
    $sla = $1 ; # Un nombre pair d'antislash
    $sla2 = $2 ;# Un antislash, si impair
  }

  $sla2 = '' if not defined $sla2 ;
  $sla = '' if not defined $sla ;
  # localTrace 'debug_chaines' ,  "sla:$sla:$sla2\n";                           # traces_filter_line


  #--------------------------------------------------------------------
  # PREPRO context management.
  # 	=> detect the case where a string is in a prepro directive, and the prepro line ends (with \n) while
  # 	the string is still opened. 
  #--------------------------------------------------------------------
  my $b_newline_terminates_string_and_directive = undef;
  $b_newline_terminates_string_and_directive = ( $context->{'back'} eq 'INPREPRO' && 
     ( $element eq "\n"  ) && ( $sla2 eq '' ));


  #--------------------------------------------------------------------
  # The detected pattern $element can be the following if it is compliant with a end string pattern :
  # 	(R)Q  ou  QF  ou Q
  # where : R is the number of repetition of the string pattern
  #         Q is a quote character. It can be S for simple quoting (' or ") or D for double quoting ('' or "").
  #         F is the format. This is not involved in the determination.
  #
  # $element will be the end of the string, depending on the above combination and the value of sla2.
  # If sla2 is not empty, that signifies that the pattern is preceded by a "\" that is a special character
  # 
  #                  |------------|------------|-----------|-----------|
  #                  |    RS      |    RD      |   S       |   D       |
  #                  |    (R)'    |    (R)''   |   '       |   ''      |
  #   ---------------|------------|------------|-----------|-----------|
  #     sla2 ne ''   |   \(R)'    |   \(R)''   |   \'      |   \''     |
  #   .......\       |    END     |  Continue  |  Continue |   END     |
  #   ---------------|------------|------------|-----------|-----------|
  #     sla2 eq ''   |    (R)'    |   (R)''    |    '      |    ''     |
  #   .......        |    END     |  Continue  |   END     |  Continue |
  #   ---------------|------------|------------|-----------|-----------|

  my $R=0;
  my $S=0;
  my $D=0;

  my $end_of_string = 0;

  #--------------------------------------------------------------------
  # QUOTING management.
  #      If $element contains one or more quote, then it should be established
  #      if it is the end of the string or not.
  #--------------------------------------------------------------------

   if ($expected_closing_pattern =~ /[\"\']/ ) {

    if ($element =~ /$expected_closing_pattern/) {
      if ( $element =~ /${expected_closing_pattern}${expected_closing_pattern}/ ) {
        $D = 1;   # Double quoting
      }
      else {
        $S = 1    # Single quoting
      }
    
      if ( $element =~ /\)${expected_closing_pattern}/ ) {
        $D = 1;   # Presence of repetition pattern before the quote.
      }
    
      if ($R ) {
         if ($S) {
           # if repetition before simple quote, the quote is always the end of the string.
           $end_of_string = 1;
        }
        else  {
           # if repetition before double quote, the double quote is never the end of the string (the double quote is not signioficant in a string).
           $end_of_string = 1;
        }
      }
      else {
        if ( ( $S && ($sla2 eq '')) ||
    	 ( $D && ($sla2 ne '')) ) {
         # if simple quote NOT trivialized by "\" OR double quote whom the first IS trivialized by "\", then is like a unic quote that indicates the end of the string.
         $end_of_string = 1;
         }
         # else it is not the end of the string.
      }
    }
  }
  else {
    # Expected closing pattern is not a quote
    # FIXME-CAST : this case is not planned, it is an error.
    #  $end_of_string = 0;
  }

  if ( $end_of_string ||
  # si la fin de chaine est precedee d'un nombre pair d'antislash:
  # il s'agit bien d'une fin de chaine.
 
  #if ( ( ( $element =~ /$expected_closing_pattern/ ) && ( $sla2 eq '' )) ||

# ou si une ligne de directive de compilation contient une chaine qui ne se termine pas explicitement,
# on considere que la fin de ligne termine la chaine
       $b_newline_terminates_string_and_directive )
  {
    $next_state = $context->{'back'}; 
    if ($b_newline_terminates_string_and_directive)
    {
      # in case of a new line that ends a directive while a string is still opened in it, the next state is not PREPRO, but CODE !!!!
      $next_state = 'INCODE';
    }
    $expected_closing_pattern = '' ;
    $string_buffer .= $element ;
#    $code .= $blanked_element;                                                 # traces_filter_line

    # records the string in different vues.
    finalyze_string($string_buffer, $context, $vues, $blanked_element);

    $string_buffer = '' ;
  }
  else
  {
    #localTrace 'debug_chaines', "string_buffer:<- $string_buffer\n";           # traces_filter_line
    $string_buffer .= $element ;
    # Dans ce cas, on ne repercute pas les blancs dans la vue code.
    #                $code .= $blanked_element;                                 # traces_filter_line
    $vues->append( 'comment_a',  $blanked_element  );
    #localTrace 'debug_chaines', "string_buffer:-> $string_buffer\n";           # traces_filter_line
  }

  $context->{'string_context'} = $string_context;
  $context->{'string_buffer'} = $string_buffer;
  $context->{'code'} = $code;
  $context->{'mix'} = $Mix;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Traitement des tokens, dans un contexte directives de compilation.
#-------------------------------------------------------------------------------
sub separer_code_commentaire_chaine_INPREPRO($$)
{
  my ($context, $vues)=@_;

  my $next_state = $context->{'next_state'};
  my $blanked_element = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'prepro_expected_closing_pattern'};
  my $code = $context->{'code'};
  my $string_buffer = $context->{'string_buffer'};
  my $string_context = $context->{'string_context'};

  $context->{'back'} = 'INPREPRO' ;

  if ( $element eq '/*' )
  {
    # une directive de compilation peut contenir des commentaires multi-lignes
    $next_state = 'INCOMMENT'; $context->{'expected_closing_pattern'} = '*/' ;
    $vues->append( 'comment_a',  $element  );
    $vues->append( 'code_a',  ' '.$blanked_element  );  # Au moins un blanc a la place d'un commentaire ...
    $vues->append( 'prepro_a',  ' '.$blanked_element  );
    $vues->append( 'sansprepro_a',  ' '.$blanked_element  );
    $vues->append( 'mix_a',  $element );
  }
  # FIXME : This could be removed, because in PL1, "//" commentaries don't exist ...
  elsif ( $element eq '//' )
  {
    # une directive de compilation peut contenir des commentaires mono-lignes
    $next_state = 'INCOMMENT'; $context->{'expected_closing_pattern'} = "\n" ;
    $context->{'back'} = 'INCODE' ;
    $vues->append( 'code_a',  $blanked_element );
    $vues->append( 'prepro_a',  $blanked_element );
    $vues->append( 'sansprepro_a',  ' '.$blanked_element  );
    $vues->append( 'mix_a',  '/*' );
    $vues->append( 'comment_a',  $element  );
  }
  elsif ( $element =~ /\"\"|\'\'/ )
  {
     finalyze_string($element, $context, $vues, $blanked_element);
  }
  elsif ( $element =~ /\"/ )
  {
    $next_state = 'INSTRING'; 
    $string_buffer = $element ; $context->{'expected_closing_pattern'} = '"' ;
    $vues->append( 'comment_a',  $blanked_element );
  }
  elsif ( $element =~ /\'/ )
  {
    $next_state = 'INSTRING'; $context->{'expected_closing_pattern'} = '\'' ;
    $string_buffer = $element ; 
    $vues->append( 'comment_a',  $blanked_element );
  }
  else {
      # Matching a PREPRO INSTRUCTION
      if ( $context->{'lastprepro'} eq '%' )
      {
        if ($element =~ /\s*(?:\w*\s*:\s*)?(\w+)/) {
          my $keyword = $1;
    
          # Matching beginning of a PREPRO STRUCTURE
          if ($keyword =~ /\b(PROCEDURE|PROC|SELECT|DO)\b/i ) {
             $expected_closing_pattern = "%END";
          }
    
          # Matching an include instruction
          elsif ($keyword =~ /\binclude\b/i ) {
             $expected_closing_pattern = "\n";
          }

          # Matching end of a PREPRO STRUCTURE
          elsif ($keyword =~ /\bEND\b/i ) {
             if ( $expected_closing_pattern eq "%END" ){
                $next_state = 'INCODE';
    	     }
          }
	  else {
             $expected_closing_pattern = ";";
	  }
        }
      }
      # Matching end of a ";" and test if it is expected as end of PREPRO.
      elsif ( $expected_closing_pattern eq $element ){
           $next_state = 'INCODE';
        }
      

      # record prepro datas in differents vues
      $vues->append( 'comment_a',  $blanked_element  );
      $vues->append( 'code_a',  $element  );
      $vues->append( 'prepro_a',  $element  );
      $vues->append( 'sansprepro_a',  $blanked_element  );
      $vues->append( 'mix_a',  $blanked_element );
      $context->{'lastprepro'} = $element;
  }

  $context->{'string_context'} = $string_context;
  $context->{'string_buffer'} = $string_buffer;
  $context->{'code'} = $code;
  $context->{'next_state'} = $next_state;
  $context->{'prepro_expected_closing_pattern'} = $expected_closing_pattern;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Separation du code SQL, dans le cas du langage PRO-C
#-------------------------------------------------------------------------------
sub StripSQL($$)
{
  my ( $rcode, $options ) = @_;
  my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);
  my $verrueTiming = new Timing ('StripPL1:StripSQL', Timing->isSelectedTiming ('Strip'));
  my $code = $$rcode;
  my $buffer_sql ='';
  my $buffer_c ='';

  # END-EXEC point-virgule
  # EXEC SQL (tout sauf point virgule) point virgule
  # EXEC SQL EXECUTE
  my $proC_re = qr'(END[-]EXEC|EXEC *SQL *(?:EXECUTE|[^;]*;))' ;
  my @parts = split (  $proC_re , $code );
  my $index = 0;
  my $blanks = ' ';
  my $execute = 0;
  my $prev;                                      # traces_filter_line
  my $prev2;                                     # traces_filter_line

  foreach my $p ( @parts)
  {
    #print STDERR "Traitement de\n" . $p ."\n" ; # traces_filter_line
    #      $prev2 = $prev; # pour debug.         # traces_filter_line
    $prev = $p; # pour debug.                    # traces_filter_line
    $blanks=$p;
    $blanks =~ s/[^\n\t]/ /sg;
    if ( $index %2 != 0)
    {
      if ( $p =~ m/\AEXEC *SQL *EXECUTE/ )
      {
        $execute = 1;
      }
      elsif ( $p =~ m/\AEND[-]EXEC/ )
      {
        $execute = 0;
      }
      else
      {
        # ne rien faire
      }
      # un morceau de sql.
      $buffer_sql .= $p;
      $buffer_c .= $blanks;
    }
    elsif ( $execute == 1 )
    {
      # NB: il peut s'agir d'une instruction ou bien d'un bloc.
      if ( $p =~ m/\A\s*BEGIN/ )
      {
        # on considere qu'il s'agit d'un bloc de SQL.
        # on ne cherche pas le END, car on sait que l'on s'arretera sur le END-EXEC.
        # un morceau de sql.
        $buffer_sql .= $p;
        $buffer_c .= $blanks;
      }
      else
      {
        # on considere qu'il s'agit d'une instruction de SQL.
        $p =~ m/\A([^;]*;)(.*)/sm ;
        my $instruction_sql = $1;
        my $reste = $2;
        my $blanks_instruction_sql = $instruction_sql;
        my $blanks_reste = $reste;
        $execute = 0;

        #print STDERR "sql -------------->\n" . $instruction_sql ."\n" ;        # traces_filter_line
        #print STDERR "code ------------->\n" . $reste ."\n" ;                  # traces_filter_line

        $blanks_instruction_sql =~ s/[^\n\t]/ /sg;
        $blanks_reste =~ s/[^\n\t]/ /sg;
        # un morceau de sql.
        $buffer_sql .= $instruction_sql . $blanks_reste;
        $buffer_c .= $blanks_instruction_sql . $reste;
      }
    }
    else
    {
      # un morceau de code.
      $buffer_sql .= $blanks;
      $buffer_c .= $p;
    }
    $index += 1;
  }
  $verrueTiming->dump('') if ($b_timing_strip);                                 # timing_filter_line
  return ( \$buffer_c, \$buffer_sql);
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction utilitaire permetant de trouver la parenthese
# fermante correspondant a la parenthese ouvrante
#-------------------------------------------------------------------------------
sub splitAtPeer ($$$$)
{
  my ( $r_prog, $open, $close, $indexStart) = @_ ;

  my $left = ''; # traces_filter_line
  my $right = ''; # traces_filter_line
  my $opened = 0;
  my $BeforeSplit = 1;
  my $SplitPos = undef;
  pos($$r_prog) = $indexStart;
  while ($$r_prog =~ /(.)/sg)
  {
    my $caractere = $1;
    if ( $BeforeSplit == 1)
    {
      if ($caractere eq $open)
      {
        $opened += 1;
      }
      elsif ($caractere eq $close)
      {
        if ( $opened == 0)
        {
          print STDERR "[SplitAtPeer] Defaut d'appariement des $open et $close..\n";
          return (undef, undef);
        }
        $opened -=1 ;
        if ($opened == 0)
        {
          $BeforeSplit = 0;
          $SplitPos = pos ( $$r_prog );
        }
      }
#      $left .= $caractere;                                               # traces_filter_line
    }
    else {
#      $right .= $caractere;                                              # traces_filter_line
    }
  }

  if ($opened > 0) {
    print STDERR "[SplitAtPeer] Defaut d'appariement des $open et $close : un caractere $open n'a pas de correspondance...\n";
    return (undef, undef) ;
  }
  return ( substr ( $$r_prog, 0, $SplitPos ),  substr ( $$r_prog,  $SplitPos ) );

  return ($left, $right); # traces_filter_line
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Separation du code Assembleur
#-------------------------------------------------------------------------------
sub StripAsm($$)
{
  my ( $rcode, $options ) = @_;
  my $b_timing_strip = ((defined  Timing->isSelectedTiming ('Strip'))? 1 : 0);
  my $verrueTiming = new Timing ('StripPL1:StripAsm',  Timing->isSelectedTiming ('Strip'));
  my $code = $$rcode;
  my $buffer_asm ='';
  my $buffer_c ='';

  # asm tout sauf accolade ACCO_OUVRANT BLOC ACCO_FERMANT
  # [__]asm[__] tout sauf parenthese PARENT_OUVRANT BLOC PARENT_FERMANT
  # [_][_]asm tout non glouton (?non consomme: ACCO_FERMANT | POINT-VIRGULE | fin

  my $asm_re = qr'(\b_*asm_*\b(?:\s*\b_*volatile_*\b)?)' ;
  my @parts = split (  $asm_re , $code );
  my $index = 0;
  my $blanks = ' ';
  my $execute = 0;
  foreach my $p ( @parts)
  {
    $blanks=$p;
    $blanks =~ s/[^\n\t]/ /sg;
    if ( ( $index %2 != 0)  )
    {
      if ( $p =~ m/\A_*asm/ )
      {
        $execute = 1;
      }
      else
      {
        # ne rien faire
      }
      $buffer_asm .= $p;
#        $buffer_c .= 'ASM_ISOSCOPE' . $blanks;                                 # traces_filter_line
      $buffer_c .= '' . $blanks;
    }
    else
    {
      my ($delta_asm, $delta_c) ;
      $delta_asm = $blanks;
      $delta_c = $p;
      if ($execute == 1 )
      {
        $execute = 0;
        my ($left, $right);
        if ( $p =~ /\A\s*\(/smg )
        {
          # Assembleur type gcc intel.
          ($left, $right) = splitAtPeer(\$p, '(', ')', pos($p)-1 );
          if ( defined $left and defined $right)
          {
            my $blanks_left=$left;
            $blanks_left =~ s/[^\n\t]/ /sg;
            my $blanks_right=$right;
            $blanks_right =~ s/[^\n\t]/ /sg;
            $delta_asm = $left . $blanks_right;
            $delta_c = $blanks_left . $right ;
          }
        }
        elsif ( $p =~ /([};\{])/smg )
        {
          my $char = $1;
          if ( $char  =~ /[\{]/smg )
          {
            # Assembleur type SCO
            ($left, $right) = splitAtPeer(\$p, '{', '}', pos($p)-1 );
          }
          #elsif ( $p =~ /[};]/smg )                                            # traces_filter_line
          else
          # FIXME: optimiser et ameliorer, avec precedent... ?
          {
            my $SplitPos = pos($p)-1;
            ($left,$right)  =  ( substr ( $p, 0, $SplitPos ),  substr ( $p, $SplitPos ) );
          }
        }
        if ( not defined $left or not defined $right)
        {
          if ( $p =~ /[\n]/smg )
          {
            # Microsoft variante:
            # FIXME: on prend tout, mais il faudrait peut-etre s'arreter en fin de ligne
            my $SplitPos = pos($p)-1;
            ($left,$right)  =  ( substr ( $p, 0, $SplitPos ),  substr ( $p, $SplitPos ) );
          }
          else
          {
            # Microsoft variante:
            # FIXME: on prend tout, mais il faudrait peut-etre s'arreter en fin de ligne
            ($left,$right)  =  ( $p, '' );
          }
        }
        if ( defined $left and defined $right)
        {
          my $blanks_left=$left;
          $blanks_left =~ s/[^\n\t]/ /sg;
          my $blanks_right=$right;
          $blanks_right =~ s/[^\n\t]/ /sg;
          $delta_asm = $left . $blanks_right;
          $delta_c = $blanks_left . $right ;
        }
      }
      $buffer_asm .= $delta_asm;
      $buffer_c .= $delta_c;
    }
    $index += 1;
  }
  $verrueTiming->dump('') if ($b_timing_strip);                                 # timing_filter_line
  return ( \$buffer_c, \$buffer_asm);
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Analyse du fichier
#-------------------------------------------------------------------------------
sub StripPL1($$$$)
{
  my ($filename, $vue, $options, $couples) = @_;
  my $status = 0;
  my $compteurs = $couples;
  my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0);   # traces_filter_line
  my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);                    # traces_filter_line

  {
    my $message = 'Lancement de StripPL1::StripPL1';
    Erreurs::LogInternalTraces ('verbose', undef, undef, 'StripPL1', $message);
  }

  my $b_timing_strip = ((defined   Timing->isSelectedTiming ('Strip'))? 1 : 0);
  #print STDERR join ( "\n", keys ( %{$options} ) );                            # traces_filter_line
  configureLocalTraces('StripPL1', $options);                                   # traces_filter_line
  my $stripPL1Timing = new Timing ('StripPL1', Timing->isSelectedTiming ('Strip'));
  $stripPL1Timing->markTimeAndPrint ('--init--') if ($b_timing_strip);          # timing_filter_line

  # remove the first column
  $vue->{'text'} =~ s/^.//mg ;

  # replace ++include par %include ...
  $vue->{'text'} =~ s/\+\+include\b/%include/isg ;

  # replace some items a end of somes lines (ex pattern 00185*376) !!!
  $vue->{'text'} =~ s/[ \t]\d[\d\*]+$/ /mg ;

  # removing spaces between "/" and "*" in order comments to be correctly detected
#  $vue->{'text'} =~ s/\*(\s+)\//\*\/$1 /mg ;
#  $vue->{'text'} =~ s/\/(\s+)\*/$1\/\*/mg ;


  $stripPL1Timing->markTimeAndPrint ('--\r--') if ($b_timing_strip);            # timing_filter_line


  # FIXME-PL1 : Traitement des "\" de fin de ligne. Y en a-t-il en PL1 ????
  # -------------------------------------------------------------------------
  # pour supprimer les backslash <fin de ligne>
#  while ( $vue->{'text'} =~ s/\\([\ \t]*)\n([\ \t]?)([\ \t]*)([^\n]*\n)/$2balise isoscope $x00a3$4/g ) {}
  # passe les balises de 'avant commentaire' a 'apres commentaire'
#  while ( $vue->{'text'} =~ s/balise isoscope $x00a3([^\n]*?\/\*.*?\*\/)/$1balise isoscope $x00a3/sg ) {}
#  while ( $vue->{'text'} =~ s/balise isoscope $x00a3(.*?\n)/$1\n/g ) {}

  $stripPL1Timing->markTimeAndPrint ('--\--') if ($b_timing_strip);             # timing_filter_line

  localTrace ('verbose',  "working with  $filename \n");                        # traces_filter_line
  my $text = $vue->{'text'};
  $stripPL1Timing->markTimeAndPrint ('--init--') if ($b_timing_strip);          # timing_filter_line

  my $ref_sep = separer_code_commentaire_chaine(\$text, $options);
  $stripPL1Timing->markTimeAndPrint ('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

  my($code_with_prepro, $comments, $rt_strings, $MixBloc, $prepro, $sansprepro, $err) = @{$ref_sep} ;
  $vue->{'comment'} = $$comments;
  $vue->{'HString'} = $rt_strings;
  $vue->{'code_with_prepro'} = $$code_with_prepro;
  $vue->{'MixBloc'} = $$MixBloc;

  $vue->{'prepro_directives'} = $$prepro;
  $vue->{'sansprepro'} = $$sansprepro;

  if ( $err gt 0) {
    my $message = 'Erreur fatale dans la separation des chaines et des commentaires';
    Erreurs::LogInternalTraces ('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', 'Erreur fatale dans la separation des chaines et des commentaires');
    #return $status | ErrStripError(1, Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples)  if ( $err gt 0);
    $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    return $status;
  }

  # Suppression des directives #define, #pragma, #error
  #    $$code_with_prepro =~ s/#[ \t]*(define|pragma|error)\b[^\n]*//g;         # traces_filter_line
  my $buf_search = $$code_with_prepro;
  my $debug = 0;                                                                # traces_filter_line
  while ($buf_search =~ m{
                    (\#\s*(define|pragma|error)\b[^\n]*) #1
                }gxm)
  {
    my $match_direct_prepro = $1;
    print STDERR "Directive prepro : $match_direct_prepro\n" if ($debug);       # traces_filter_line
    my $pos_c_last = pos($buf_search) - 1;
    my $len = length($match_direct_prepro);
    my $pos_c_first = $pos_c_last - $len + 1;
    my $nb = $pos_c_last - $pos_c_first + 1;
    print STDERR "ERASE $pos_c_first-$pos_c_last : from $pos_c_first, nb = $nb\n" if ($debug); # traces_filter_line
    substr($$code_with_prepro, $pos_c_first, $nb) =~ s/[^\n\s]/ /sg;
  }

  $stripPL1Timing->markTimeAndPrint ('Supprime define pragma error') if ($b_timing_strip); # timing_filter_line

  # FIXME CAST : to check if PL1 can include SQL code ...
  #my ( $code_sans_sql, $sql ) = StripSQL( $code_with_prepro, $options);
  #$stripPL1Timing->markTimeAndPrint ('Strip SQL') if ($b_timing_strip);         # timing_filter_line

  # FIXME CAST : to check if PL1 can include ASM code ...
  #my ( $code_sans_asm, $asm ) = StripAsm( $code_sans_sql, $options);
  #$stripPL1Timing->markTimeAndPrint ('Strip ASM') if ($b_timing_strip);         # timing_filter_line

  #$vue->{'code'} = $$code_sans_asm;
  #$vue->{'debug_avant_strip_sql'} = $$code_with_prepro;                         # traces_filter_line
  #$vue->{'sql'} = $$sql;
  #$vue->{'asm'} = $$asm;

  # Unless existance of SQL or ASM code that has been removed, vue 'code' is identical to vue 'code_with_prepro'
  $vue->{'code'} = $$code_with_prepro;

  if ( defined $options->{'--dumpstrings'})
  {
	  StripUtils::dumpVueStrings( $rt_strings , $STDERR );
  }

  $stripPL1Timing->dump('StripPL1') if ($b_timing_strip);                       # timing_filter_line
#  my $size_code = length($vue->{'code'});                                       # traces_filter_line
#  my $size_comment = length($vue->{'comment'});                                 # traces_filter_line
#  assert($size_code == $size_comment,                                           # traces_filter_line
#    'Vues code et comment ne sont pas de la meme taille') if ($b_assert);       # traces_filter_line

  print STDERR "StripPL1 end:$status\n"  if ($b_TraceInconsistent);             # traces_filter_line
  $stripPL1Timing->finish() ;                                                   # timing_filter_line
  return $status;
}


1; # Le chargement du module est okay.
