package StripPHP ;

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
		  dumpVueStrings
                 );
use Prepro;
use AnaUtils;
use Vues;

# prototypes publics
sub StripPHP($$$$);

# prototypes prives
sub separer_code_commentaire_chaine($$);
sub separer_code_commentaire_chaine_INCODE($$);
sub separer_code_commentaire_chaine_INCOMMENT($$);
sub separer_code_commentaire_chaine_INSTRING($$);
sub separer_code_commentaire_chaine_INPREPRO($$);
sub splitAtPeer ($$$$);


my $x00a3 = pack("U0C*", 0xc2, 0xa3);       # U+00A3 POUND SIGN

# Initialisation du module StripUtils # traces_filter_line
# avec traces desactivees.            # traces_filter_line
StripUtils::init('StripPHP', 0);      # traces_filter_line

#-------------------------------------------------------------------------------
# DESCRIPTION: Automate de tri du contenu du fichier en trois parties:
# 1/ code
# 2/ commentaires
# 3/ chaines
#-------------------------------------------------------------------------------
#
my $shortOpenTag = '<(?:%|\?(?:php)?)';
my $shortCloseTag = '(?:\?|%)>';
my $scriptOpenTag = '<\s*script\s+[^>]*\bphp\b[^>]*>';
my $scriptCloseTag = '<\s*\/\s*script\b[^>]*>';

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

  my $stripPHPTiming = new Timing ('StripPHP:separer_code_commentaire_chaine', Timing->isSelectedTiming ('Strip')); 
  my $buffer_d_entree = $$source;
  my $blanked_element = undef;
  my $code = '';
  my $comment = '';
  my $Mix = '';
  my $html = '';
  my $state = 'OUTPHP' ;
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

  $stripPHPTiming->markTimeAndPrint ('--init--') if ($b_timing_strip);                    # timing_filter_line

  # first level of split : search for HTML/PHP frontiers ...
  #my @parts = split (  '(<(?:%|\?(?:php)?)|(?:\?|%)>|<\s*script\s+[^>]\bphp\b)' , $buffer_d_entree );
  my @parts = split (  /(${shortOpenTag}|${shortCloseTag}|${scriptOpenTag}|${scriptCloseTag})/i , $buffer_d_entree );
  $stripPHPTiming->markTimeAndPrint ('--split HTML/PHP--') if ($b_timing_strip);          # timing_filter_line

  my $stripPHPTimingLoop = new Timing ('StripPHP internal Loop', Timing->isSelectedTiming ('Strip'));

  # definition du pattern recherche, en fonction de l'etat courant.
  my %states_patterns = (
    'OUTPHP' =>  qr{\G(.*)}sm ,
    # Le code peut s'arreter sur debut de commentaire.
    # ou implicitement sur guillemets ou retour a la ligne
    # RQ: $scriptCloseTag begins with a '<', that is a 'cut' pattern. If we don't want
    # that $scriptCloseTag is cut, we should recognize it entirely before ...
    'INCODE' =>  qr{\G(/[*]|//|\#|/|"|'|<<<'?\w+'?|$scriptCloseTag|<|[^/#"'<]*)}sm ,
    # Le commentaire peut s'arreter sur fin de commentaire.
    # ou implicitement sur guillemets ou retour a la ligne
    'INCOMMENT' => qr{\G([*]/|[*]|\n|[^*\n]*)}sm ,
    # La chaine peut s'arreter
    # implicitement sur guillemets ou retour a la ligne, ou antislash
    'INSTRING' => qr{\G(\\\\|\\"|\\'|\\|"|'|\n\w*|[^"'\n\\]*)}sm ,
  );

  # Etat initial.
  my $vues = new Vues( 'text' ); # creation des nouvelles vues a partir de la vue text
  #$vues->setOptionIsoSize(); # config pour (certaines) vues de meme taille

  $vues->declare('code_a');
  $vues->declare('comment_a');
  $vues->declare('mix_a');
  $vues->declare('html_a');

  $context->{'code'} = $code;
  $context->{'comment'} = $comment;
  $context->{'mix'} = $Mix;
  $context->{'html'} = $html;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
  $context->{'heredoc_endtag'} = '';

  # Cette donnee sert a revenir a l'etat code ou inprocess, suite a la fin 
  # d'une chaine de caracteres.
  # Vu l'anomalie 225, on peut se demander s'il est judicieux d'extraire les 
  # chaines de caracteres des directives de compilation des cette premiere 
  # passe.
  $context->{'back'} = 'OUTPHP';

  $context->{'string_context'} = $string_context;
  my $position=0;

  my $nb_iter = $#parts ;

  for my $partie ( @parts )
  {

    localTrace (undef, "Utilisation du buffer:                           " . $partie . "\n" ); # traces_filter_line
    # $stripPHPTiming->markTimeAndPrint ('--iter in split: ' . $part . '/' . $#parts  . '  --'); # timing_filter_line
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
      # $stripPHPTimingLoop->markTimeAndPrint ('--iter in split internal--');   # timing_filter_line
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
      if ( $state eq 'OUTPHP' )
      {
        treat_HTML($context, $vues);
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

  # Consolidation de la vue mix.
  $Mix = $vues->consolidate('mix_a');

  # Consolidation de la vue html.
  $html = $vues->consolidate('html_a');

  my $status_strip = 0;

  $stripPHPTiming->markTimeAndPrint ('--done--') if ($b_timing_strip);          # timing_filter_line

  # Gestion du statut d'erreur
  my @return_array ;
  if  (($state ne 'OUTPHP') && ($state ne 'INCODE')) 
  {
    if (not ($expected_closing_pattern eq "\n") )
    {
      # tolerance pour les fins de ligne manquante en fin de fichier dans un commentaire '//'
      warningTrace (undef,  "warning: end file in state $state \n");     # traces_filter_line
      if ($state eq 'INSTRING')
      {
        warningTrace (undef,  "Unterminated string:\n" . $string_buffer ."\n" ); # traces_filter_line
      }
      $status_strip = 1;
    }
  }
  @return_array =  ( \$code, \$comment, \%strings_values, \$Mix, \$html, undef, $status_strip);
  return \@return_array ;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Traitement associe a l'etat OUTPUP
#-------------------------------------------------------------------------------
sub treat_HTML($$)
{
  my ($context, $vues)=@_;

  my $next_state = $context->{'next_state'};
  my $blanked_element = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $string_buffer = $context->{'string_buffer'};

  $context->{'back'} = 'OUTPHP' ;

  if ( $element =~  /$shortOpenTag|$scriptOpenTag/m )
  {
    $next_state = 'INCODE';

    # FIXME : $expected_closing_pattern is useless for INCODE ...
    if ($element eq '<%') {
      $expected_closing_pattern = '%>' ;
    }
    else {
      $expected_closing_pattern = '?>' ;
    }
    $vues->append( 'comment_a',  $blanked_element );
    $vues->append( 'code_a',  $element );
    $vues->append( 'mix_a',  $element );
    $vues->append( 'html_a',  $blanked_element );
  }
  else {
    $vues->append( 'code_a',  $blanked_element );
    $vues->append( 'mix_a',  $blanked_element );
    $vues->append( 'comment_a',  $blanked_element );
    $vues->append( 'html_a',  $element );
  }

  $context->{'string_buffer'} = $string_buffer;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
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
  my $string_buffer = $context->{'string_buffer'};
  $context->{'back'} = 'INCODE' ;

  #if (( $element eq '?>' ) || ( $element eq '%>' ) )
  if ( $element =~ /$shortCloseTag|$scriptCloseTag/i )
  {
    $next_state = 'OUTPHP';
    $vues->append( 'code_a',  $element );
    $vues->append( 'mix_a',  $element );
    #localTrace ( 'debug_prepro' ,  "prepro begin:$element\n" );                # traces_filter_line
    $vues->append( 'comment_a',  $blanked_element );
    $vues->append( 'html_a',  $blanked_element );
  }
  elsif ( $element eq '/*' )
  {
    $next_state = 'INCOMMENT'; $expected_closing_pattern = '*/' ;
    $vues->append( 'comment_a',  $element );
    # Au moins un blanc a la place d'un commentaire ...
    $vues->append( 'code_a',  ' '.$blanked_element );
    $vues->append( 'mix_a',  $element );
    $vues->append( 'html_a',  $blanked_element );
  }
  elsif ( ( $element eq '//' ) || ( $element eq '#' ) ) 
  {
    $next_state = 'INCOMMENT'; $expected_closing_pattern = "\n" ;
    $vues->append( 'code_a',  $blanked_element );
    $vues->append( 'mix_a',  '/*' );
    $vues->append( 'comment_a',  $element );
    $vues->append( 'html_a',  $blanked_element );
  }
  elsif ( $element =~ /^<<</sm )   
  {
    my ($endtag) = $element =~ /<<<'?(\w+)/sm;
    $next_state = 'INSTRING'; $expected_closing_pattern = '' ;
    $vues->append( 'comment_a',  $blanked_element );
    $context->{'heredoc_endtag'} = $endtag ;
    $string_buffer = $element ;
    $vues->append( 'html_a',  $blanked_element );
  }
  elsif ( $element eq '"' )
  {
    $next_state = 'INSTRING'; $expected_closing_pattern = '"' ;
    $string_buffer = $element ;
    $vues->append( 'comment_a',  $blanked_element );
    $vues->append( 'html_a',  $blanked_element );
  }
  elsif ( $element eq "'" )
  {
    $next_state = 'INSTRING'; $expected_closing_pattern = "'" ;
    $string_buffer = $element ;
    $vues->append( 'comment_a',  $blanked_element );
    $vues->append( 'html_a',  $blanked_element );
  }
  else
  {
    $vues->append( 'code_a',  $element );
    $vues->append( 'mix_a',  $element );
    $vues->append( 'comment_a',  $blanked_element );
    $vues->append( 'html_a',  $blanked_element );
  }
  $context->{'string_buffer'} = $string_buffer;
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
  
  # check end of a /*, // or # comment.
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
    $vues->append( 'code_a',  $context->{'blanked_element2'} );
    $vues->append( 'comment_a',  $element );
    $vues->append( 'html_a',  $blanked_element );
  }
  else
  {
    $vues->append( 'code_a',  $context->{'blanked_element2'} );
    $vues->append( 'comment_a',  $element );
    $vues->append( 'html_a',  $blanked_element );

    # case of the MIX view :
    # All mono line comment are changed into multi-line comment format in the Mix view ..
    if ($element eq "\n")
    {
                  $Mix .= "*/\n/*";
                  $vues->append( 'mix_a',  "*/\n/*" );
    }
    else
    {
      # suppressing /* and  */ (if any) inside a line comment ....
      my %aSupprimer =  (  '/' =>1,  '*'=>1,  '*/'=>1   );
      if ( exists $aSupprimer{$element} )
      {
                    $vues->append( 'mix_a',  ' ' );
      }
      else
      {
                    $vues->append( 'mix_a',  $element );
      }
      # Suppression des "/*" et  "*/"  qui pourraient trainer ...
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
  my $string_buffer = $context->{'string_buffer'};
  my $string_context = $context->{'string_context'};

  my $heredoc_endtag = $context->{'heredoc_endtag'};

  # detecting end of string
  if ( ($element eq $expected_closing_pattern )   ||
       (($heredoc_endtag ne '') &&($element =~ /\A\n$heredoc_endtag\Z/s)) )
  {
    $next_state = $context->{'back'}; 
    $expected_closing_pattern = '' ;

    # do not record string termination of a heredoc ...
    if ($heredoc_endtag eq '') {
      $string_buffer .= $element ;
    }
    else {
      $string_buffer .= "\n";
    }
#    $code .= $blanked_element;                                                 # traces_filter_line
    $vues->append( 'comment_a',  $blanked_element  );
    $vues->append( 'html_a',  $blanked_element );

    my $string_id = StringStore( $string_context, $string_buffer );

    my $nb = () = $string_buffer =~ /\n/g ;
    my $newlines = "\n" x $nb ;

    $vues->append( 'code_a',  $string_id . $newlines  );
    $vues->append( 'mix_a',  $string_id . $newlines );
    $string_buffer = '' ;
    $context->{'heredoc_endtag'} = '';
  }
  else
  {
    #localTrace 'debug_chaines', "string_buffer:<- $string_buffer\n";           # traces_filter_line
    $string_buffer .= $element ;
    # Dans ce cas, on ne repercute pas les blancs dans la vue code.
    #                $code .= $blanked_element;                                 # traces_filter_line
    $vues->append( 'comment_a',  $blanked_element  );
    $vues->append( 'html_a',  $blanked_element );
    #localTrace 'debug_chaines', "string_buffer:-> $string_buffer\n";           # traces_filter_line
  }

  $context->{'string_context'} = $string_context;
  $context->{'string_buffer'} = $string_buffer;
  $context->{'code'} = $code;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
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
# DESCRIPTION: Analyse du fichier
#-------------------------------------------------------------------------------
sub StripPHP($$$$)
{
  my ($filename, $vue, $options, $couples) = @_;
  my $status = 0;
  my $compteurs = $couples;

  my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0);   # traces_filter_line
  my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);                    # traces_filter_line

  {
    my $message = 'Lancement de StripPHP::StripPHP';
    Erreurs::LogInternalTraces ('verbose', undef, undef, 'StripPHP', $message);
  }

  my $b_timing_strip = ((defined   Timing->isSelectedTiming ('Strip'))? 1 : 0);
  #print STDERR join ( "\n", keys ( %{$options} ) );                            # traces_filter_line
  configureLocalTraces('StripPHP', $options);                                   # traces_filter_line
  my $stripPHPTiming = new Timing ('StripPHP', Timing->isSelectedTiming ('Strip'));
  $stripPHPTiming->markTimeAndPrint ('--init--') if ($b_timing_strip);          # timing_filter_line

  localTrace ('verbose',  "working with  $filename \n");                        # traces_filter_line

  my $ref_sep = separer_code_commentaire_chaine(\$vue->{'text'}, $options);
  $stripPHPTiming->markTimeAndPrint ('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

  my($code, $comments, $rt_strings, $MixBloc, undef, undef, $err) = @{$ref_sep} ;
  
  #$$code =~ s/<%/ /g;
  #$$code =~ s/%>/ /g;
  #$$code =~ s/<\?php/ /g;
  #$$code =~ s/\?>/ /g;
  $$code =~ s/<\?=/<\?php echo/g;
  
  $vue->{'comment'} = $$comments;
  $vue->{'HString'} = $rt_strings;
  $vue->{'code'} = $$code;
  $vue->{'MixBloc'} = $$MixBloc;
  $vue->{'agglo'} = "";
  StripUtils::agglomerate_C_Comments($MixBloc, \$vue->{'agglo'});

  if ( $err gt 0) {
    my $message = 'Erreur fatale dans la separation des chaines et des commentaires';
    Erreurs::LogInternalTraces ('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', 'Erreur fatale dans la separation des chaines et des commentaires');
    #return $status | ErrStripError(1, Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples)  if ( $err gt 0);
    $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    return $status;
  }

  my $debug = 0;                                                                # traces_filter_line

  if ( defined $options->{'--dumpstrings'})
  {
    dumpVueStrings( $rt_strings , $STDERR );
  }

  $stripPHPTiming->dump('StripPHP') if ($b_timing_strip);                       # timing_filter_line
#  my $size_code = length($vue->{'code'});                                       # traces_filter_line
#  my $size_comment = length($vue->{'comment'});                                 # traces_filter_line
#  assert($size_code == $size_comment,                                           # traces_filter_line
#    'Vues code et comment ne sont pas de la meme taille') if ($b_assert);       # traces_filter_line

  print STDERR "StripPHP end:$status\n"  if ($b_TraceInconsistent);             # traces_filter_line
  $stripPHPTiming->finish() ;                                                   # timing_filter_line
  return $status;
}


1; # Le chargement du module est okay.
