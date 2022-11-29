#----------------------------------------------------------------------#
#                 @ISOSCOPE 2008                                       #
#----------------------------------------------------------------------#
#       Auteur  : ISOSCOPE SA                                          #
#       Adresse : TERSUD - Bat A                                       #
#                 5, AVENUE MARCEL DASSAULT                            #
#                 31500  TOULOUSE                                      #
#       SIRET   : 410 630 164 00037                                    #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Plugin
#----------------------------------------------------------------------#
# DESCRIPTION: Ce paquetage fournit une separation du code et
# des commentaires d'un source pour les langages C et C++
#----------------------------------------------------------------------#

package StripCpp ;

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
sub StripCpp($$$$);

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
StripUtils::init('StripCpp', 0);      # traces_filter_line

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

  my $stripCppTiming = new Timing ('StripCpp:separer_code_commentaire_chaine', Timing->isSelectedTiming ('Strip')); 
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

  $stripCppTiming->markTimeAndPrint ('--init--') if ($b_timing_strip);                    # timing_filter_line
  # recherche des guillemets et retours a la ligne
  #my @parts = split (  "((?:\@)\"|[/*]+|\"|\'|\n)" , $buffer_d_entree );
  
  my $RawstringBegin = '(?:R\"\w+\()';
  my $RawstringEnd = '\)\w+"';
  my $FormatstringBegin = '(?:\@|L|u8|u|U)\"';
  my @parts = split (  /($RawstringBegin|$FormatstringBegin|[\/*]+|'|\n)/ , $buffer_d_entree );
  $stripCppTiming->markTimeAndPrint ('--split--') if ($b_timing_strip);                   # timing_filter_line
  my $stripCppTimingLoop = new Timing ('StripCpp internal Loop', Timing->isSelectedTiming ('Strip'));

  # definition du pattern recherche, en fonction de l'etat courant.
  my %states_patterns = (
    # Le code peut s'arreter sur debut de commentaire.
    # ou implicitement sur guillemets ou retour a la ligne
    # INCODE wants to react on following patterns : 
    #       - @interface, @implementation, @", /* and  */    (produced by this regular expression)
    #       - '   (inherited from main split).
    'INCODE' =>  qr{\G([@](?:interface|implementation|end)\b|$RawstringBegin|$FormatstringBegin|[@]"|"|/[*]|//|/|[*]|[@]|[^/*\@"]*)}sm ,
    # Le commentaire peut s'arreter sur fin de commentaire.
    # ou implicitement sur guillemets ou retour a la ligne
    'INCOMMENT' => qr{\G([*]/|/|[*]|[^/*]*)}sm ,
    # La chaine peut s'arreter
    # implicitement sur guillemets ou retour a la ligne
    # Capture @ to split the sequence @" that can be produced by th main split. If we do not, the @" will mask
    # the " and then prevent the algo to recognize the end of the string.
    'INSTRING' => qr{\G([@]|"|[^"@]*)}sm ,
    'INRAWSTRING' => qr{\G($RawstringEnd|\)|"|[^\)"R]*)}sm ,
    # Le preprocessing peut s'arreter sur debut de commentaire
    # ou implicitement sur guillemets ou retour a la ligne
    'INPREPRO' =>  qr{\G(/[*]|//|/|[*]|"|[^/*"]*)}sm ,
  );

  # Etat initial.
  my $vues = new Vues( 'text' ); # creation des nouvelles vues a partir de la vue text
  #$vues->setOptionIsoSize(); # config pour (certaines) vues de meme taille

  $vues->declare('code_a');
  $vues->declare('comment_a');
  $vues->declare('mix_a');
  $vues->declare('prepro_a');
  $vues->declare('sansprepro_a');
  $vues->declare('objc_a');

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

  # by default, objc context is desactivated
  $context->{'objc'} = 0;

  $context->{'string_context'} = $string_context;
  my $position=0;

  my $nb_iter = $#parts ;

  for my $partie ( @parts )
  {
    localTrace (undef, "Utilisation du buffer:                           " . $partie . "\n" ); # traces_filter_line
    # $stripCppTiming->markTimeAndPrint ('--iter in split: ' . $part . '/' . $#parts  . '  --'); # timing_filter_line
#print "---PART--- => $partie\n";
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
      my $blanked_element = $element ; # les retours a la ligne correspondant.
      # $stripCppTimingLoop->markTimeAndPrint ('--iter in split internal--');   # timing_filter_line

      # Creation de la chaine debarassee des caracteres non blancs, pour suppression.
      $blanked_element = garde_newlines($blanked_element) ;
      #localTrace "debug_chaines",  "state: $state: working with  !!$element!! \n"; # traces_filter_line

      my $expected_closing_pattern = $context->{'expected_closing_pattern'} ;
#print "ELEMENT : $element\n";
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

      #if ($context->{'objc'} == 0) {
	# Context Cpp
        $context->{'element'} = $element;
#	$context->{'element_objc'} = $blanked_element;
#      }
#      else {
	# Context Objc
#	$context->{'element'} = $blanked_element;
#        $context->{'element_objc'} = $element;
#      }
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
      elsif ( $state eq 'INRAWSTRING' )
      {
        separer_code_commentaire_chaine_INRAWSTRING($context, $vues);
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
      if (defined $options->{'--strip-states'}) {
			if ($state ne $context->{'next_state'}) {
				print "____________________\nITEM = $element\n    ==> $context->{'next_state'}\n";
			}
			else {
				print "$element\n";
			}
		}
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
  while ( $code =~ s/\\([\ \t]*)\n([\ \t]*)([^\n]*\n)/ $1$2balise isoscope $x00a3$3/g ) {}
  while ( $code =~ s/balise isoscope $x00a3(.*?\n)/$1\n/g ) {}

  # Consolidation de la vue prepro.
  my $prepro = $vues->consolidate('prepro_a');

  # pour supprimer les backslash <fin de ligne> ajoutes pour traiter les
  # commentaires dans les directives
  while ( $prepro =~ s/\\([\ \t]*)\n([\ \t]*)([^\n]*\n)/ $1$2balise isoscope $x00a3$3/g ) {}
  while ( $prepro =~ s/balise isoscope $x00a3(.*?\n)/$1\n/g ) {}

  # Consolidation de la vue sansprepro.
  my $sansprepro = $vues->consolidate('sansprepro_a');

  # Consolidation de la vue mix.
  $Mix = $vues->consolidate('mix_a');

  # Consolidation de la vue mix.
  my $ObjC = $vues->consolidate('objc_a');

  my $status_strip = 0;

  $stripCppTiming->markTimeAndPrint ('--done--') if ($b_timing_strip);          # timing_filter_line

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
  @return_array =  ( \$code, \$comment, \%strings_values, \$Mix, \$prepro, \$sansprepro, \$ObjC, $status_strip);
  return \@return_array ;
}

sub append_code_element($$$$) {
    my $element = shift;
    my $blanked_element = shift;
    my $vue = shift;
    my $context = shift;

    if ($context->{'objc'} == 0 ) {
      # C/Cpp context
      $vue->append('code_a', $$element);
      #$vue->append('objc_a', $$blanked_element);
      
      # C/Cpp statements are present in ObjC view ...
      #$vue->append('objc_a', $$element);
    }
    else {
      # Objc C context
      $vue->append('code_a', $$blanked_element);
      #$vue->append('objc_a', $$element);
    }
}

sub append_code_blankedElement($$$) {
    my $blanked_element = shift;
    my $vue = shift;
    my $context = shift;

    $vue->append('code_a', $$blanked_element);
    #$vue->append('objc_a', $$blanked_element);
}

sub append_CodeSansPrepro_element($$$$) {
    my $element = shift;
    my $blanked_element = shift;
    my $vue = shift;
    my $context = shift;

    if ($context->{'objc'} == 0 ) {
      # C/Cpp context
      # -------------
      $vue->append('sansprepro_a', $$element);
      
      # C/Cpp statements are present in ObjC view ...
      $vue->append('objc_a', $$element);
    }
    else {
      # Objc C context
      # -------------
      # ObjC statements are NOT present in C/Cpp view ...
      $vue->append('sansprepro_a', $$blanked_element);
      $vue->append('objc_a', $$element);
    }
}

sub append_CodeSansPrepro_blankedElement($$$) {
    my $blanked_element = shift;
    my $vue = shift;
    my $context = shift;

    $vue->append('sansprepro_a', $$blanked_element);
    $vue->append('objc_a', $$blanked_element);
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
    #$vues->append( 'code_a',  ' '.$blanked_element );
    append_code_blankedElement(\$blanked_element, $vues, $context);
    #$vues->append( 'sansprepro_a',  $blanked_element );
    append_CodeSansPrepro_blankedElement(\$blanked_element, $vues, $context);
    $vues->append( 'mix_a',  $element );
    $vues->append( 'objc_a',  $blanked_element );
  }
  elsif ( $element eq '//' )
  {
    $next_state = 'INCOMMENT'; $expected_closing_pattern = "\n" ;
    #$vues->append( 'code_a',  $blanked_element );
    append_code_blankedElement(\$blanked_element, $vues, $context);
    #$vues->append( 'sansprepro_a',  $blanked_element );
    append_CodeSansPrepro_blankedElement(\$blanked_element, $vues, $context);
    $vues->append( 'mix_a',  '/*' );
    $vues->append( 'comment_a',  $element );
    $vues->append( 'objc_a',  $blanked_element );
  }
  #elsif ( ($element eq '"') || ($element eq '@"') )
  elsif ($element =~ /^(?:L|u8|u|U|\@)?"$/m)
  {
    $next_state = 'INSTRING'; $expected_closing_pattern = '"' ;
    $string_buffer = $element ;
    $vues->append( 'comment_a',  $blanked_element );
  }
  elsif ($element =~ /^R"(\w+)\($/m)
  {
    $next_state = 'INRAWSTRING'; $expected_closing_pattern = ")$1\"" ;
    $string_buffer = $element ;
    $vues->append( 'comment_a',  $blanked_element );
  }
  elsif ( $element eq '\'' )
  {
    $next_state = 'INSTRING'; $expected_closing_pattern = '\'' ;
    $string_buffer = $element ;
    $vues->append( 'comment_a',  $blanked_element );
  }
  elsif ( $element =~ '^\s*#' )
  {
    $next_state = 'INPREPRO';
    #$vues->append( 'code_a',  $element );
    append_code_element(\$element, \$blanked_element, $vues, $context);
    #$vues->append( 'sansprepro_a',  $blanked_element );
    append_CodeSansPrepro_blankedElement(\$blanked_element, $vues, $context);
    $vues->append( 'prepro_a',  $element );
    $vues->append( 'mix_a',  $element );
    $context->{'lastprepro'} = $element;
    #localTrace ( 'debug_prepro' ,  "prepro begin:$element\n" );                # traces_filter_line
    $vues->append( 'comment_a',  $blanked_element );
  }
  elsif ( $element =~ /\@(?:interface|implementation)\b/ )
  {
    $vues->append( 'comment_a',  $blanked_element );
    # Au moins un blanc a la place d'un commentaire ...
    $vues->append( 'mix_a',  $element );
    $context->{'objc'}=1;

    # This line must be AFTER objective-C context is turned to 1, because the code element belongs to objective C language.
    #$vues->append( 'sansprepro_a',  $blanked_element );
    append_CodeSansPrepro_element(\$element, \$blanked_element, $vues, $context);

    append_code_element(\$element, \$blanked_element, $vues, $context);
  }
  elsif ( $element =~ /\@end\b/ )
  {
    $vues->append( 'comment_a',  $blanked_element );
    # Au moins un blanc a la place d'un commentaire ...
    $vues->append( 'code_a',  ' '.$blanked_element );
    $vues->append( 'mix_a',  $element );

    # This line must be BEFORE objective-C context is turned to 0, because the code element belongs to objective C language. !!
    #$vues->append( 'sansprepro_a',  $blanked_element );
    append_CodeSansPrepro_element(\$element, \$blanked_element, $vues, $context);

    append_code_element(\$element, \$blanked_element, $vues, $context);
    $context->{'objc'}=0;
  }

  else
  {
    #$vues->append( 'code_a',  $element );
    append_code_element(\$element, \$blanked_element, $vues, $context);
    #$vues->append( 'sansprepro_a',  $element );
    append_CodeSansPrepro_element(\$element, \$blanked_element, $vues, $context);
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
      #$vues->append( 'code_a',  $context->{'blanked_element2'} );
      append_code_blankedElement(\$context->{'blanked_element2'}, $vues, $context);

      $vues->append( 'prepro_a',  $context->{'blanked_element2'} );
      #$vues->append( 'sansprepro_a',  $context->{'blanked_element'} );
      append_CodeSansPrepro_blankedElement(\$context->{'blanked_element'}, $vues, $context);
    }
    else
    {
      #$vues->append( 'code_a',  $context->{'blanked_element2'} );
      append_code_blankedElement(\$context->{'blanked_element2'}, $vues, $context);
      $vues->append( 'prepro_a',  $context->{'blanked_element'} );
      #$vues->append( 'sansprepro_a',  $context->{'blanked_element'} );
      append_CodeSansPrepro_blankedElement(\$context->{'blanked_element'}, $vues, $context);
    }
    $vues->append( 'comment_a',  $element );
  }
  else
  {
    # Suppression des "/*" et  "*/"  qui pourraient trainer ...
    #$vues->append( 'code_a',  $context->{'blanked_element2'} );
    append_code_blankedElement(\$context->{'blanked_element2'}, $vues, $context);
    $vues->append( 'prepro_a',  $context->{'blanked_element2'} );
    #$vues->append( 'sansprepro_a',  $context->{'blanked_element'} );
    append_CodeSansPrepro_blankedElement(\$context->{'blanked_element'}, $vues, $context);
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
  my $sla2  ;# Un antislash, si impair

  # Autant d'antislash consecutifs que possible.
  $string_buffer =~ m{(\\\\)*(\\?)\z}sm ;
  $sla2 = $2;# Un antislash, si impair
  $sla2 = '' if not defined $sla2 ;

  my $b_newline_terminates_string_and_directive = undef;
  $b_newline_terminates_string_and_directive = ( $context->{'back'} eq 'INPREPRO' && 
     ( $element eq "\n"  ) && ( $sla2 eq '' ));

  # si la fin de chaine est precedee d'un nombre pair d'antislash:
  # il s'agit bien d'une fin de chaine.
  if ( ( ( $element eq $expected_closing_pattern ) && ( $sla2 eq '' )) ||
# ou si une ligne de directive de compilation contient une chaine qui ne se termine pas explicitement,
# on considere que la fin de ligne termine la chaine
       $b_newline_terminates_string_and_directive )
  {
    $next_state = $context->{'back'}; 
    if ($b_newline_terminates_string_and_directive)
    {
      $next_state = 'INCODE';
    }
    $expected_closing_pattern = '' ;
    $string_buffer .= $element ;
#    $code .= $blanked_element;                                                 # traces_filter_line
    $vues->append( 'comment_a',  $blanked_element  );

    my $string_id = StringStore( $string_context, $string_buffer );

    # Dans la vue "code", la chaine est remplace par CHAINE_<id>_<occurence> .. # traces_filter_line
    #                $code .= $string_id . '_' . $nb ;                          # traces_filter_line
    # Finalement on ne concatene pas le numero d'occurrence.                    # traces_filter_line
    #$vues->append( 'code_a',  $string_id  );
    append_code_element(\$string_id, \$blanked_element, $vues, $context);

    if ( $context->{'back'} eq 'INPREPRO' )
    {
      $vues->append( 'prepro_a',  $string_id  );
      #$vues->append( 'sansprepro_a',  $blanked_element  );
      append_CodeSansPrepro_blankedElement(\$blanked_element, $vues, $context);
    }
    else
    {
      $vues->append( 'prepro_a',  $blanked_element  );
      #$vues->append( 'sansprepro_a',  $string_id  );
      append_CodeSansPrepro_blankedElement(\$string_id, $vues, $context);
    }
    $vues->append( 'mix_a',  $string_id  );
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
# DESCRIPTION: Traitement associe a l'etat INRAWSTRING
#-------------------------------------------------------------------------------
sub separer_code_commentaire_chaine_INRAWSTRING($$) {
	my ($context, $vues)=@_;

	my $next_state = $context->{'next_state'};
	my $blanked_element = $context->{'blanked_element'};
	my $element = $context->{'element'};
	my $expected_closing_pattern = $context->{'expected_closing_pattern'};
	my $code = $context->{'code'};
	my $Mix = $context->{'mix'};
	my $string_buffer = $context->{'string_buffer'};
	my $string_context = $context->{'string_context'};

	if ($element eq $expected_closing_pattern ){
		$next_state = $context->{'back'}; 
		$expected_closing_pattern = '' ;
		$string_buffer .= $element ;

		my $string_id = StringStore( $string_context, $string_buffer );
		
		# Append $string_id in view "code"
		append_code_element(\$string_id, \$blanked_element, $vues, $context);
		# Append blank element in view "prepro"
		$vues->append( 'prepro_a',  $blanked_element  );
		# Append $string_id in view "sans_prepro"
		append_CodeSansPrepro_blankedElement(\$string_id, $vues, $context);
		# Append $string_id in view "MixBloc"
		$vues->append( 'mix_a',  $string_id  );
		# Append blank element in view "comment"
		$vues->append( 'comment_a',  $blanked_element  );
		
		# Add as many empty lines as lines contained in the string
		my $nbLines = () = $string_buffer =~ /\n/g;
		my $emptyLines = "\n"x$nbLines;
		if ($nbLines) {
			append_code_element(\$emptyLines, \$emptyLines, $vues, $context);
			$vues->append( 'prepro_a',  $emptyLines  );
			append_CodeSansPrepro_blankedElement(\$emptyLines, $vues, $context);
			$vues->append( 'mix_a',  $emptyLines  );
		}

		$string_buffer = '' ;
	}
	else {
		$string_buffer .= $element ;
		$vues->append( 'comment_a',  $blanked_element  );
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
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $code = $context->{'code'};
  my $string_buffer = $context->{'string_buffer'};
  my $string_context = $context->{'string_context'};

  $context->{'back'} = 'INPREPRO' ;

  if ( $element eq '/*' )
  {
    # une directive de compilation peut contenir des commentaires multi-lignes
    $next_state = 'INCOMMENT'; $expected_closing_pattern = '*/' ;
    $vues->append( 'comment_a',  $element  );
    #$vues->append( 'code_a',  ' '.$blanked_element  );  # Au moins un blanc a la place d'un commentaire ...
    append_code_blankedElement(\$blanked_element, $vues, $context);
    $vues->append( 'prepro_a',  ' '.$blanked_element  );
    #$vues->append( 'sansprepro_a',  ' '.$blanked_element  );
    append_CodeSansPrepro_blankedElement(\$blanked_element, $vues, $context);
    $vues->append( 'mix_a',  $element );
  }
  elsif ( $element eq '//' )
  {
    # une directive de compilation peut contenir des commentaires mono-lignes
    $next_state = 'INCOMMENT'; $expected_closing_pattern = "\n" ;
    $context->{'back'} = 'INCODE' ;
    #$vues->append( 'code_a',  $blanked_element );
    append_code_blankedElement(\$blanked_element, $vues, $context);
    $vues->append( 'prepro_a',  $blanked_element );
    #$vues->append( 'sansprepro_a',  ' '.$blanked_element  );
    append_CodeSansPrepro_blankedElement(\$blanked_element, $vues, $context);
    $vues->append( 'mix_a',  '/*' );
    $vues->append( 'comment_a',  $element  );
  }
  elsif ( $element eq '"' )
  {
    # une directive de compilation peut contenir des chaines
    $next_state = 'INSTRING'; $expected_closing_pattern = '"' ;
    $string_buffer = $element ;
    $vues->append( 'comment_a',  $blanked_element  );
  }
  elsif ( $element eq '\'' )
  {
    # une directive de compilation peut contenir des chaines
    $next_state = 'INSTRING'; $expected_closing_pattern = '\'' ;
    $string_buffer = $element ;
    $vues->append( 'comment_a',  $blanked_element  );
  }
  else
  {
    # Sinon semble inclure en particulier la fin de ligne.

    #localTrace ( 'debug_prepro' ,  "prepro:$element\n" );                      # traces_filter_line
    my $continuation = 0;
    if  ( $element eq "\n" )
    {
      # car en C, le preprocessing peut etre multi-lignes.
      my $sla  ; # Un nombre pair d'antislash
      my $sla2  ;# Un antislash, si impair
      my $lasti_prepro_buffer = $context->{'lastprepro'} ;
      # autant d'antislash consecutifs que possible.
      $lasti_prepro_buffer =~ m{(\\\\)*(\\?)\z}sm ;
      $sla = $1 ; # Un nombre pair d'antislash
      $sla2 = $2 ;# Un antislash, si impair

      $sla2 = '' if not defined $sla2 ;
      $sla = '' if not defined $sla ;

      # localTrace ( 'debug_prepro' ,  "prepro_slash:$sla:$sla2\n" );            # traces_filter_line
      # si la fin de ligne est precedee d'un nombre pair d'antislash:
      # il s'agit bien d'une fin de ligne.
      # Le cas nominal est 0 antislash.
      # FIXME: A t'on deja vu 2 antislash en fin de ligne?
      if ( $sla2 eq '' )
      {
        $context->{'lastprepro'} = $element;
        # fin de la directive de precompilation
        $next_state = 'INCODE';
        #       $string_buffer .= $element ;                                     # traces_filter_line
        $vues->append( 'comment_a',  $blanked_element  );

	#$vues->append( 'code_a',  $element  );
        append_code_element(\$element, \$blanked_element, $vues, $context);
        $vues->append( 'prepro_a',  $element  );
	#$vues->append( 'sansprepro_a',  $blanked_element  );
        append_CodeSansPrepro_blankedElement(\$blanked_element, $vues, $context);
        $vues->append( 'mix_a',  $element );
        #       $vues->append( 'code_a',  $string_id  );                         # traces_filter_line
        #localTrace ( 'debug_prepro' ,  "prepro end:$element\n" );               # traces_filter_line
      }
      else
      {
        $continuation = 1;
      }
    }
    else
    {
      $continuation = 1;
    }
    if ( $continuation == 1 )
    {
      # sinon la directive de preprocessing continue sur la ligne suivante
      #localTrace 'debug_chaines', "string_buffer:<- $string_buffer\n";         # traces_filter_line
      # Dans ce cas, on ne repercute pas les blancs dans la vue code.
      $vues->append( 'comment_a',  $blanked_element  );
      #$vues->append( 'code_a',  $element  );
      append_code_element(\$element, \$blanked_element, $vues, $context);
      $vues->append( 'prepro_a',  $element  );
      #$vues->append( 'sansprepro_a',  $blanked_element  );
      append_CodeSansPrepro_blankedElement(\$blanked_element, $vues, $context);
      #localTrace 'debug_chaines', "string_buffer:-> $string_buffer\n";         # traces_filter_line
      $context->{'lastprepro'} = $element;
    }
  }

  $context->{'string_context'} = $string_context;
  $context->{'string_buffer'} = $string_buffer;
  $context->{'code'} = $code;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Separation du code SQL, dans le cas du langage PRO-C
#-------------------------------------------------------------------------------
sub StripSQL($$)
{
  my ( $rcode, $options ) = @_;
  my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);
  my $verrueTiming = new Timing ('StripCpp:StripSQL', Timing->isSelectedTiming ('Strip'));
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
    }
  }

  if ($opened > 0) {
    print STDERR "[SplitAtPeer] Defaut d'appariement des $open et $close : un caractere $open n'a pas de correspondance...\n";
    return (undef, undef) ;
  }
  return ( substr ( $$r_prog, 0, $SplitPos ),  substr ( $$r_prog,  $SplitPos ) );
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Separation du code Assembleur
#-------------------------------------------------------------------------------
sub StripAsm($$)
{
  my ( $rcode, $options ) = @_;
  my $b_timing_strip = ((defined  Timing->isSelectedTiming ('Strip'))? 1 : 0);
  my $verrueTiming = new Timing ('StripCpp:StripAsm',  Timing->isSelectedTiming ('Strip'));
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
sub StripCpp($$$$)
{
  my ($filename, $vue, $options, $couples) = @_;
  my $status = 0;
  my $compteurs = $couples;

  my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0);   # traces_filter_line
  my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);                    # traces_filter_line

  {
    my $message = 'Lancement de StripCpp::StripCpp';
    Erreurs::LogInternalTraces ('verbose', undef, undef, 'StripCpp', $message);
  }

  my $b_timing_strip = ((defined   Timing->isSelectedTiming ('Strip'))? 1 : 0);
  #print STDERR join ( "\n", keys ( %{$options} ) );                            # traces_filter_line
  configureLocalTraces('StripCpp', $options);                                   # traces_filter_line
  my $stripCppTiming = new Timing ('StripCpp', Timing->isSelectedTiming ('Strip'));
  $stripCppTiming->markTimeAndPrint ('--init--') if ($b_timing_strip);          # timing_filter_line

  $stripCppTiming->markTimeAndPrint ('--\r--') if ($b_timing_strip);            # timing_filter_line

  # pour supprimer les backslash <fin de ligne>
  while ( $vue->{'text'} =~ s/\\([\ \t]*)\n([\ \t]?)([\ \t]*)([^\n]*\n)/$2balise isoscope $x00a3$4/g ) {}
  # passe les balises de 'avant commentaire' a 'apres commentaire'
  while ( $vue->{'text'} =~ s/balise isoscope $x00a3([^\n]*?\/\*.*?\*\/)/$1balise isoscope $x00a3/sg ) {}
  while ( $vue->{'text'} =~ s/balise isoscope $x00a3(.*?\n)/$1\n/g ) {}

  $stripCppTiming->markTimeAndPrint ('--\--') if ($b_timing_strip);             # timing_filter_line

  localTrace ('verbose',  "working with  $filename \n");                        # traces_filter_line
  my $text = $vue->{'text'};
  $stripCppTiming->markTimeAndPrint ('--init--') if ($b_timing_strip);          # timing_filter_line

  my $ref_sep = separer_code_commentaire_chaine(\$text, $options);
  $stripCppTiming->markTimeAndPrint ('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

  my($code_with_prepro, $comments, $rt_strings, $MixBloc, $prepro, $sansprepro, $ObjC, $err) = @{$ref_sep} ;
  $vue->{'comment'} = $$comments;
  $vue->{'HString'} = $rt_strings;
  $vue->{'code_with_prepro'} = $$code_with_prepro;
  $vue->{'MixBloc'} = $$MixBloc;

  $vue->{'agglo'} = "";
  StripUtils::agglomerate_C_Comments($MixBloc, \$vue->{'agglo'});

  $vue->{'prepro_directives'} = $$prepro;
  $vue->{'sansprepro'} = $$sansprepro;
  $vue->{'ObjC'} = $$ObjC;

  if ( $err gt 0) {
    my $message = 'Erreur fatale dans la separation des chaines et des commentaires';
    Erreurs::LogInternalTraces ('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', 'Erreur fatale dans la separation des chaines et des commentaires');
    #return $status | ErrStripError(1, Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples)  if ( $err gt 0);
    $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    return $status;
  }

  # verification sommaire des accolades parentheses.
  my ($b_egalite_parenth_accolad, $b_directive_preprocessing) =
    AnaUtils::AnalyseAccoladesParenthesesRapide($filename, $compteurs, $options, $vue->{'code_with_prepro'});

  #--------------------------------------------
  # + probleme acco/parent
  # + pas de directives de compilation
  #       ==> code non compilable.
  #--------------------------------------------

  if ((not $b_egalite_parenth_accolad) && (not $b_directive_preprocessing))
  {
    # le fichier n'est pas compilable
    print STDERR "the file is not compilable\n"  if ($b_TraceInconsistent);# traces_filter_line

    # Dat_Abort_Cause est positionne dans l'appelant si pb de strip
    #$status |= Couples::counter_add($compteurs, Erreurs::MNEMO_ABORT_CAUSE, Erreurs::ABORT_CAUSE_SYNTAX_ERROR);
    $status |= Erreurs::COMPTEUR_STATUS_FICHIER_NON_COMPILABLE;
    $status |= Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES;
    $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, "Parentheses inconsistency.");
    return $status
  }

  #--------------------------------------------
  # + probleme acco/parent
  # + il y a des directives de compilation
  #       ==> code a preprocesser.
  #--------------------------------------------
  elsif ((not $b_egalite_parenth_accolad) && $b_directive_preprocessing)
  {
    # lancement traitement buffer prepro
    # Traitement des directives de compilation conditionnelles
    Prepro::Prepro($filename, $code_with_prepro, $vue);
    $stripCppTiming->markTimeAndPrint ('Prepro') if ($b_timing_strip);          # timing_filter_line
    if (defined $vue->{'prepro'})
    {
      # le buffer prepro a ete cree
      my $prepro = $vue->{'prepro'};
      # verifie de nouveau et positionne Dat_InconsistentBracesParenthesis
      my $nb_incoherences = AnaUtils::VerifieCoherenceAccoladesParenthesesDirectActiveBuffer($filename, $compteurs, $options, $prepro);
      if ($nb_incoherences > 0)
      {
        $status |= Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES;
        $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, "Parentheses inconsistency, possible consequence of conditional compilation.");
		return $status;
      }
    }
    else
    {
      # le buffer prepro n'a pas ete cree, donc on a une erreur
      # verifie avec $code et positionne Dat_InconsistentBracesParenthesis
      my $nb_incoherences = AnaUtils::VerifieCoherenceAccoladesParenthesesDirectActiveBuffer($filename, $compteurs, $options, $$code_with_prepro);
      if ($nb_incoherences > 0)
      {
        $status |= Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES;
        $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, "Parentheses inconsistency, possible consequence of conditional compilation.");
        return $status;
      }
    }
  }
  #--------------------------------------------
  # + pas de probleme acco/parent
  # + pas de  directives de compilation
  #       ==> code analysable.
  #--------------------------------------------
  elsif ($b_egalite_parenth_accolad && (not $b_directive_preprocessing))
  {
    # lance l'analyse : on continue normalement
  }
  #--------------------------------------------
  # + pas de probleme acco/prent
  # + il y a des directives de compilation
  #       ==> code qui necessite un controle plus pousse des associations accolades/parentheses.
  #--------------------------------------------
  elsif ($b_egalite_parenth_accolad && $b_directive_preprocessing)
  {
    # verif coherence longue
    my $nb_inconsistencies = AnaUtils::VerifieCoherenceAccoladesParenthesesDirectActiveBuffer($filename, $compteurs, $options, $$code_with_prepro);
    $stripCppTiming->markTimeAndPrint (                                         # timing_filter_line
      'AnaUtils::VerifieCoherenceAccoladesParenthesesDirectActiveBuffer')       # timing_filter_line
        if ($b_timing_strip);                                                   # timing_filter_line
    if ($nb_inconsistencies > 0)
    {
      # il y a des ncoherences
      # tente le traitement des directives de compilation conditionnelles
      Prepro::Prepro($filename, $code_with_prepro, $vue);
      $stripCppTiming->markTimeAndPrint ('Prepro') if ($b_timing_strip);        # timing_filter_line
      if (defined $vue->{'prepro'})
      {
	# le buffer prepro a ete cree
        my $prepro = $vue->{'prepro'};
        # verifie de nouveau et positionne Dat_InconsistentBracesParenthesis
        $nb_inconsistencies = AnaUtils::VerifieCoherenceAccoladesParenthesesDirectActiveBuffer($filename, $compteurs, $options, $prepro);
        $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, "Parentheses inconsistency, due to conditional compilation.");
        return $status;
      }
      else
      {
	# le buffer prepro n'a pas ete cree, donc on a une erreur
        $status |= Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES;
      }
    }
	
	# Analyzing macros for future expand
	# Prepro::Prepro($filename);
	print "analyzing macros $filename\n";
	sleep(1);

  }
  # Suppression des directives #define, #pragma, #error
  # ----------------------------------------------------
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

  $stripCppTiming->markTimeAndPrint ('Supprime define pragma error') if ($b_timing_strip); # timing_filter_line

  my ( $code_sans_sql, $sql ) = StripSQL( $code_with_prepro, $options);
  $stripCppTiming->markTimeAndPrint ('Strip SQL') if ($b_timing_strip);         # timing_filter_line

  my ( $code_sans_asm, $asm ) = StripAsm( $code_sans_sql, $options);
  $stripCppTiming->markTimeAndPrint ('Strip ASM') if ($b_timing_strip);         # timing_filter_line

  $vue->{'code'} = $$code_sans_asm;
  $vue->{'debug_avant_strip_sql'} = $$code_with_prepro;                         # traces_filter_line
  $vue->{'sql'} = $$sql;
  $vue->{'asm'} = $$asm;

  if ( defined $options->{'--dumpstrings'})
  {
    dumpVueStrings( $rt_strings , $STDERR );
  }

  $stripCppTiming->dump('StripCpp') if ($b_timing_strip);                       # timing_filter_line
#  my $size_code = length($vue->{'code'});                                       # traces_filter_line
#  my $size_comment = length($vue->{'comment'});                                 # traces_filter_line
#  assert($size_code == $size_comment,                                           # traces_filter_line
#    'Vues code et comment ne sont pas de la meme taille') if ($b_assert);       # traces_filter_line

  print STDERR "StripCpp end:$status\n"  if ($b_TraceInconsistent);             # traces_filter_line
  $stripCppTiming->finish() ;                                                   # timing_filter_line
  return $status;
}


1; # Le chargement du module est okay.
