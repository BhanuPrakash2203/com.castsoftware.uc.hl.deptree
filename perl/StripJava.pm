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

# Ce paquetage fournit une separation du code et des commentaires d'un source
# Java


package StripJava;
use strict;
use warnings ;
use Carp::Assert; # traces_filter_line
use Timing ; # timing_filter_line
use StripUtils;

# prototypes publics
sub StripJava($$$$);

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                  dumpVueStrings
                 );

StripUtils::init('StripJava', 0);

# automate de tri du contenu du fichier en trois parties:
# 1/ code
# 2/ commentaires
# 3/ chaines
sub separer_code_commentaire_chaine($$)
{
    my ($source, $options) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);
    my %hContext=();
    my $context=\%hContext;


    my $stripJavaTiming = new Timing ('StripJava:separer_code_commentaire_chaine', Timing->isSelectedTiming ('Strip'));
    my $c = $$source;
    my $code = "";
    my $comment = "";
    my $Mix = "";
    my $state = 'INCODE' ;
    my $next_state = $state ;
    my $expected_closing_pattern = '';  #........................... Caractere attendu en fin de pattern string/comment/code
    my $string_buffer = '';


    my %strings_values = () ;
    my %strings_counts = () ;
    my %hash_strings_context = (
      'nb_distinct_strings' => 0,
      'strings_values' => \%strings_values,
      'strings_counts' => \%strings_counts  ) ;
    my $string_context = \%hash_strings_context;

    $stripJavaTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    my @parts = split (  "([/*]+|\"|\'|\n)" , $c );
    $stripJavaTiming->markTimeAndPrint('--split--') if ($b_timing_strip); # timing_filter_line
    my $stripJavaTimingLoop = new Timing ('StripJava internal Loop', Timing->isSelectedTiming ('Strip'));


    # definition du pattern recherche, en fonction de l'etat courant.
    my %states_patterns = (
      # Le code peut s'arreter sur debut de commentaire.
      # ou implicitement sur guillemets ou retour a la ligne
      'INCODE' =>  qr{\G(/[*]|//|/|[*]|#|[^/*#]*)}sm ,
      # Le commentaire peut s'arreter sur fin de commentaire.
      # ou implicitement sur guillemets ou retour a la ligne
      'INCOMMENT' => qr{\G([*]/|/|[*]|[^/*]*)}sm ,
      # La chaine peut s'arreter
      # implicitement sur guillemets ou retour a la ligne
      'INSTRING' => qr{\G(.*)\z}sm ,
      # VTL code ends end of line
      'INVTL' => qr{\G(.*)\z}sm ,
    );

  # Etat initial.
  $context->{'code_a'} = [];
  $context->{'mix_a'} = [];

  $context->{'code'} = $code;
  $context->{'comment'} = $comment;
  $context->{'mix'} = $Mix;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
  $context->{'string_context'} = $string_context;
  my $espaces;

    my $nb_iter = $#parts ;
    #for (my $part = 0; $part<= $nb_iter; $part++)
    for my $partie ( @parts )
    {
      localTrace (undef, "Utilisation du buffer:                           " . $partie . "\n" ); # traces_filter_line
      #$stripJavaTiming->markTimeAndPrint('--iter in split: ' . $part . '/' . $#parts  . '  --'); # timing_filter_line

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
        #$stripJavaTimingLoop->markTimeAndPrint('--iter in split internal--'); # timing_filter_line
        $espaces = garde_newlines($espaces) ;
        #$espaces = '';
        #$espaces =~ s/\S/ /gsm ;
        #localTrace "debug_chaines",  "state: $state: working with  !!$element!! \n"; # traces_filter_line

        $context->{'element'} = $element;
        $context->{'blanked_element'} = $espaces;


        # Application du traitement associe a l'etat courant
        if ( $state eq 'INCODE' )
        {
          separer_code_commentaire_chaine_INCODE($context, 0);
        }
        elsif ( $state eq 'INCOMMENT' )
        {
          separer_code_commentaire_chaine_INCOMMENT($context, 0);
        }
        elsif ( $state eq 'INSTRING' )
        {
          separer_code_commentaire_chaine_INSTRING($context, 0);
        }
        elsif ( $state eq 'INVTL' )
        {
          separer_code_commentaire_chaine_INVTL($context, 0);
        }

        # Trace des changements d'etat de l'automate
        if ( defined $options->{'--debug-strip-states'} )
        {
			if ($state ne $context->{'next_state'}) {
				print "\n$state => $context->{'next_state'} << $element >>\n";
			}
			else {
				print "$element";
			}
        }

        # Passage de l'etat courant a l'etat suivant
        $state = $context->{'next_state'};
      }
    }
  $next_state = $context->{'next_state'};
  $espaces = $context->{'blanked_element'};
  #my $element = $context->{'element'};
  $expected_closing_pattern = $context->{'expected_closing_pattern'};
  $comment = $context->{'comment'};

  #$code = $context->{'code'};
  #$Mix = $context->{'mix'};

  # Consolidation de la vue code.
  $code = join ( '', @{$context->{'code_a'}} );
  $Mix = join ( '', @{$context->{'mix_a'}} );

    $stripJavaTiming->markTimeAndPrint('--done--') if ($b_timing_strip); # timing_filter_line
    my @return_array ;
    if (not $state eq 'INCODE')
    {
        if (not ($expected_closing_pattern eq "\n")) # tolerance pour les fin
        # de ligne manquante en fin de fichier dans un commentaire '//'
        {
            warningTrace (undef,  "warning: fin de fichier en l'etat $state \n"); # traces_filter_line
            if ($state eq 'INSTRING')
            {
                warningTrace (undef,  "chaine non termine:\n" . $string_buffer ."\n" ); # traces_filter_line
            }
            @return_array =  ( \$code, \$comment, \%strings_values, \$Mix , 1);
            return \@return_array ;
        }
    }
    @return_array =  ( \$code, \$comment, \%strings_values, \$Mix , 0);
    return \@return_array ;
}

# traitement associe a l'etat INCODE
sub separer_code_commentaire_chaine_INCODE($$)
{
  my ($context, $unused)=@_;

  my $next_state = $context->{'next_state'};
  my $espaces = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $code = $context->{'code'};
  my $comment = $context->{'comment'};
  my $Mix = $context->{'mix'};
  my $string_buffer = $context->{'string_buffer'};

            if ( $element eq '/*' )
            {
                $next_state = 'INCOMMENT'; $expected_closing_pattern = '*/' ;
                #$code .= ' ';    # Au moins un blanc a la place d'un commentaire ...
                #$code .= $espaces ;
                $comment .= $element ;
                push @{$context->{'code_a'}}, ' '.$espaces;
                push @{$context->{'mix_a'}}, $element;
                #$Mix .= $element;
            }
            elsif ( $element eq '//' )
            {
                $next_state = 'INCOMMENT'; $expected_closing_pattern = "\n" ;
                #$code .= $espaces ;
                push @{$context->{'code_a'}}, $espaces;
                push @{$context->{'mix_a'}}, '/*';
                $comment .= $element ;
                #$Mix .= '/*';
            }
            elsif ( $element eq '"' )
            {
                $next_state = 'INSTRING'; $expected_closing_pattern = '"' ;
                $string_buffer = $element ; $comment .= $espaces ;
            }
            elsif ( $element eq '\'' )
            {
                $next_state = 'INSTRING'; $expected_closing_pattern = '\'' ;
                $string_buffer = $element ; $comment .= $espaces ;
            }
            elsif ( $element eq '#' )
            {
                $next_state = 'INVTL'; $expected_closing_pattern = "\n" ;
                $comment .= $espaces ;
            }
            else {
                #$code .= $element ;
                push @{$context->{'code_a'}}, $element;
                push @{$context->{'mix_a'}}, $element;
                $comment .= $espaces ;
                #$Mix .= $element;
            }
  $context->{'string_buffer'} = $string_buffer;
  $context->{'code'} = $code;
  $context->{'comment'} = $comment;
  $context->{'mix'} = $Mix;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

# traitement associe a l'etat INVTLL
sub separer_code_commentaire_chaine_INVTL($$)
{
  my ($context, $unused)=@_;

  my $next_state = $context->{'next_state'};
  my $espaces = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $code = $context->{'code'};
  my $comment = $context->{'comment'};
  my $Mix = $context->{'mix'};
  my $string_buffer = $context->{'string_buffer'};

	if ( $element eq "\n" )
	{
		$next_state = 'INCODE'; $expected_closing_pattern = '' ;
		print STDERR "WARNING: VTL (Velocity Template Language) code removed !\n";
	}
  
  $context->{'string_buffer'} = $string_buffer;
  $context->{'code'} = $code;
  $context->{'comment'} = $comment;
  $context->{'mix'} = $Mix;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

# traitement associe a l'etat INCOMMENT
sub separer_code_commentaire_chaine_INCOMMENT($$)
{
  my ($context, $unused)=@_;

  my $next_state = $context->{'next_state'};
  my $espaces = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $code = $context->{'code'};
  my $comment = $context->{'comment'};
  my $Mix = $context->{'mix'};
            # RQ: dans la vue Mix, tous les commentaires multilignes sont mis au format
            # monoligne, et les commentaires "//" sont transformes en "/* ... */".
            # Pour cette raison, les eventuelles sequences "/*" ou "*/" qui traineraient dans
            # un commentaire "//" sont supprimes ...

            #localTrace undef "receive: <$element>, waiting <$expected_closing_pattern> \n"; # traces_filter_line
            if ( $element eq $expected_closing_pattern )
            {
              if ($expected_closing_pattern eq "\n")
              {
                  #$Mix .= "*/\n";
                  push @{$context->{'mix_a'}}, "*/\n";
              }
              else
              {
                  #$Mix .= $element;
                  push @{$context->{'mix_a'}}, $element;
              };
                $next_state = 'INCODE'; $expected_closing_pattern = '' ;
                #$code .= $espaces ;
                push @{$context->{'code_a'}}, $espaces;
              $comment .= $element ;
            }
            else
            {
                # Suppression des "/*" et  "*/"  qui pourraient trainer ...

                push @{$context->{'code_a'}}, $espaces;
                #$code .= $espaces ;
                $comment .= $element ;
                if ($element eq "\n")
                {
                  $Mix .= "*/\n/*";
                  push @{$context->{'mix_a'}}, "*/\n/*";
                }
                else {
                  #if ( $element =~ m{\A[/*]+\z} )
                  my %aSupprimer =  (  '/' =>1,  '*'=>1,  '*/'=>1   );
                  #if ( ( $element eq '/'  ) || ( $element eq '*' ) || ( $element eq '*/' ) )
                  if ( exists $aSupprimer{$element} )
                  {
                    push @{$context->{'mix_a'}}, ' ';
                    #$Mix .= ' ';
                  }
                  else
                  {
                    push @{$context->{'mix_a'}}, $element;
                    #$Mix .= $element;
                  }

                  #$element =~ s/(\/\*|\*\/)/ /g ; # FIXME: consomme entre 2 et 3 secondes sur 20.
                  #$Mix .= $element;
                }
            }
  $context->{'code'} = $code;
  $context->{'comment'} = $comment;
  $context->{'mix'} = $Mix;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}

# traitement associe a l'etat INSTRING
sub separer_code_commentaire_chaine_INSTRING($$)
{
  my ($context, $unused)=@_;

  my $next_state = $context->{'next_state'};
  my $espaces = $context->{'blanked_element'};
  my $element = $context->{'element'};
  my $expected_closing_pattern = $context->{'expected_closing_pattern'};
  my $code = $context->{'code'};
  my $comment = $context->{'comment'};
  my $Mix = $context->{'mix'};
  my $string_buffer = $context->{'string_buffer'};
  my $string_context = $context->{'string_context'};
            # car en C, les chaine speuvent etre multi lignes.
            my $sla  ; # Un nombre pair d'antislash
            my $sla2  ;# Un antislash, si impair

if (1)
{
            $string_buffer =~ m{(\\\\)*(\\?)\z}sm ; #autant d'antislash consecutifs que possible.
            $sla = $1 ; # Un nombre pair d'antislash
            $sla2 = $2 ;# Un antislash, si impair
}
else

{
  my $offset = length ( $string_buffer );
  my $nb_antislash=0;
  while  (  substr ( $string_buffer, $offset, 1) eq '\\' )
  {
    $offset -= 1;
    $nb_antislash ++;
  }
  if ( $nb_antislash %2 ==0)
  {
    $sla2 = '' ;
    $sla = 'xxx' ; # '\\' x ($nb_antislash/2);
  }
  else
  {
    $sla2 = '\\' ;
    $sla = '\\' x ($nb_antislash/2);
  }

}

            $sla2 = '' if not defined $sla2 ;
            $sla = '' if not defined $sla ;
            #localTrace 'debug_chaines' ,  "sla:$sla:$sla2\n"; # traces_filter_line
            #si la fin de chaine est precedee d'un nombre pair d'antislash:
            #il s'agit bien d'une fin de chaine.
            if ( ( $element eq $expected_closing_pattern ) && ( $sla2 eq '' ))
            {
                $next_state = 'INCODE'; $expected_closing_pattern = '' ;
              $string_buffer .= $element ;
                #$code .= $espaces;
                $comment .= $espaces ;

              my $string_id = StringStore( $string_context, $string_buffer );

                # Dans la vue "code", la chaine est remplace par CHAINE_<id>_<occurence> ...
                #$code .= $string_id . '_' . $nb ;
                # Finalement on ne concatene pas le numero d'occurence.
              push @{$context->{'code_a'}}, $string_id ;
              push @{$context->{'mix_a'}}, $string_id ;

                #$code .= $string_id ;
                #$Mix .= $string_id ;
              $string_buffer = '' ;
            }
            else
            {
                #localTrace 'debug_chaines', "string_buffer:<- $string_buffer\n"; # traces_filter_line
                $string_buffer .= $element ;
                # Dans ce cas, on ne repercute pas les blancs dans la vue code.
                #$code .= $espaces;
                $comment .= $espaces ;
                #localTrace 'debug_chaines', "string_buffer:-> $string_buffer\n"; # traces_filter_line
            }

  $context->{'string_context'} = $string_context;
  $context->{'string_buffer'} = $string_buffer;
  $context->{'code'} = $code;
  $context->{'comment'} = $comment;
  $context->{'mix'} = $Mix;
  $context->{'next_state'} = $next_state;
  $context->{'expected_closing_pattern'} = $expected_closing_pattern;
}


sub supprime_annotation($$$);

# analyse du fichier
sub StripJava($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = ((defined Timing->isSelectedTiming ('Strip'))? 1 : 0);
#print STDERR join ( "\n", keys ( %{$options} ) );
    configureLocalTraces('StripJava', $options); # traces_filter_line
    my $stripJavaTiming = new Timing ('StripJava', Timing->isSelectedTiming ('Strip'));

    localTrace ('verbose',  "working with  $filename \n"); # traces_filter_line
    my $text = $vue->{'text'};
    $stripJavaTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line

    my $ref_sep = separer_code_commentaire_chaine(\$text, $options);
    $stripJavaTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

    my($c, $comments, $rt_strings, $MixBloc, $err) = @{$ref_sep} ;
    $vue->{'comment'} = $$comments;
    $vue->{'HString'} = $rt_strings;
    $vue->{'code_with_prepro'} = $$c;  # Contains the annotations.
    $vue->{'MixBloc'} = $$MixBloc;
    $vue->{'agglo'} = "";
    StripUtils::agglomerate_C_Comments($MixBloc, \$vue->{'agglo'});
    $vue->{'MixBloc_LinesIndex'} = StripUtils::createLinesIndex($MixBloc);
    $vue->{'agglo_LinesIndex'} = StripUtils::createLinesIndex(\$vue->{'agglo'});

    if ( $err gt 0) {
      my $message = 'Erreur fatale dans la separation des chaines et des commentaires';
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', $message);
      return Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    }

    my ($code_sans_annotation, $err_anno) = supprime_annotation($filename, $$c, $options);

    $stripJavaTiming->markTimeAndPrint('supprime_annotation') if ($b_timing_strip); # timing_filter_line

    if ($err_anno gt 0) {
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'SRIP // COMPTEUR_STATUS_PB_STRIP', 'attention : probleme rencontre dans la suppression des annotations. La vue code est potentiellement alteree.');
      return ErrStripError();
    }
    #
    $vue->{'code'} = $code_sans_annotation;
    if ( defined $options->{'--dumpstrings'})
    {
      dumpVueStrings(  $rt_strings , $STDERR );
    }
    $stripJavaTiming->dump('StripJava') if ($b_timing_strip); # timing_filter_line
    return 0;
}

sub supprime_annotation($$$)
{
    my ($fichier, $code, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0); # traces_filter_line
    my $b_TraceIn = ((exists $options->{'--TraceIn'})? 1 : 0); # traces_filter_line
    #
    my $debug = 0; # traces_filter_line
    my $erreur = 0;
    my $step = 0;
    #
    my $code_sans_annotation = $code;
    my $b_anno_longue = 0; # avec parentheses, accolades
    my $start_pos_annotation = 0;
    my @stk_match_pos_start;
    # suppression des annotations longues de java 1.5 (qui peuvent etre recursives !)
    # ex : @toto.tata({@titi()})
    if (!($code =~ /@\w/))
    {      # optimisation fichiers sans annotation (java 1.4)
      return ($code_sans_annotation, $erreur);
    }
    my $fic_out = $fichier . ".strip_java" . $step if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    TraceDetect::TraceOutToFile($fic_out, $code_sans_annotation) if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    $step++;
    while ($code =~    m{
                      (@[\w\.]+\()        #1
                      | ([(){}])          #2
                      | (.[^@(){}]*)      #3
                }gxms
        )
    {
      my $match_anno_start = $1;
      my $match_anno_parenthese_accolade = $2;
      my $match_anno_skip = $3;
      my $pos =  pos($code) -1;
      if ($b_anno_longue == 1)
      {
          if (defined $match_anno_skip)
        {
            next;
        }
          elsif (defined $match_anno_parenthese_accolade)
          {   # traitement de detection des parentheses/accolades multi-niveau puis suppression
            print STDERR "match_anno_parenthese_accolade:$match_anno_parenthese_accolade\n" if ($debug); # traces_filter_line;
            if ($match_anno_parenthese_accolade eq '(')
            {
                push(@stk_match_pos_start, $match_anno_parenthese_accolade);
            }
            elsif ($match_anno_parenthese_accolade eq '{')
            {
                push(@stk_match_pos_start, $match_anno_parenthese_accolade);
            }
            elsif ($match_anno_parenthese_accolade eq ')')
            {
                my $val = pop(@stk_match_pos_start);
                if ($val ne '(')
                {
                  $erreur = 1;
                  print STDERR "pb A : $val ne '('\n"  if ($b_TraceInconsistent); # traces_filter_line;
                }
                assert($val eq '(') if ($b_assert); # traces_filter_line;
            }
            elsif ($match_anno_parenthese_accolade eq '}')
            {
                my $val = pop(@stk_match_pos_start);
                if ($val ne '{')
                {
                  $erreur = 1;
                  print STDERR "pb B : $val ne '{' \n"  if ($b_TraceInconsistent); # traces_filter_line;
                }
                assert($val eq '{') if ($b_assert); # traces_filter_line;
            }
            my $level = @stk_match_pos_start;
            if ($level == 0)
            {   # c'est la fin de l'annotation, effacement
                print STDERR "end annotation\n" if ($debug); # traces_filter_line;
                my $len = $pos -$start_pos_annotation +1;
                substr($code_sans_annotation, $start_pos_annotation, $len) =~ s/[^\n\s]/ /sg;
                # RAZ
                $b_anno_longue = 0;
                $start_pos_annotation = 0;
            }
          }
          elsif (defined($match_anno_start))
          {      # annotation dans annotation
            push(@stk_match_pos_start, '(');
          }
      }
      elsif (defined($match_anno_start))
      {
          # debut de l'annotation
          print STDERR "start annotation\n"  if ($debug); # traces_filter_line;;
          $b_anno_longue = 1;
          my $len = length($match_anno_start);
          my $start_B0 = $pos -$len +1;
          $start_pos_annotation = $start_B0;
          push(@stk_match_pos_start, '(');
      }
    }
    # effacer les mots clefs default dans les annotations
    my @arr_match_pos_start2;
    $code = $code_sans_annotation;
    while ($code =~ m{
                    (\@interface.*?\{)   #1
                    | (\{|\})            #2
                }gxms)
    {
        my $match_annotation_start = $1;
        my $match_symb_accolade = $2;
        my $pos_c = pos($code)-1;
        my $b_stack_size_error = 0;
        if (defined $match_annotation_start)
        {
            my $value = "annotation_start:$pos_c";
            #print STDERR "push value:$value\n";
            push(@arr_match_pos_start2, $value);
        }
        elsif (defined $match_symb_accolade)
        {
            print STDERR "match_symb_accolade =  $match_symb_accolade at $pos_c\n" if ($debug); # traces_filter_line
            if ($match_symb_accolade eq '{')
            {
                push(@arr_match_pos_start2, $pos_c);
            }
            elsif ($match_symb_accolade eq '}')
            {
              my $nb = @arr_match_pos_start2;
              if ($nb <= 0)
              {
                  $b_stack_size_error = 1; # FIXME: non pris en compte: $erreur = 1; manquant ???
                  print STDERR "pile vide 3\n" if ($b_TraceInconsistent); # traces_filter_line
                  assert($nb>0, 'pile vide 3') if ($b_assert); # traces_filter_line
                  next; # continue sans assert
              }
              my $value = pop(@arr_match_pos_start2);

              if ($value =~ /annotation_start:(\d+)/)
              {
                my $match_pos_first = $1;
                my $pos_c_last = pos($code) - 1;
                my $nb = $pos_c_last - $match_pos_first + 1;
                print STDERR "ERASE $match_pos_first-$pos_c_last : from $match_pos_first, nb = $nb\n" if ($debug); # traces_filter_line
                substr($code_sans_annotation, $match_pos_first, $nb) =~ s/\sdefault\s/  /sg;
                #push(@arr_erased,[$pos_c_first,$pos_c_first+$nb-1]);
              }
            }
        }
    }
    $code = $code_sans_annotation;
    # suppression des annotations courtes de java 1.5 sauf @interface ex: @toto.titi
    $code_sans_annotation =~ s/\@interface/interface/g;
    $code_sans_annotation =~ s/@[\w\.]+\s//g;
    #
    $fic_out = $fichier . ".strip_java" . $step if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    TraceDetect::TraceOutToFile($fic_out, $code_sans_annotation) if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    $step++;
    return ($code_sans_annotation, $erreur);
}

1; # Le chargement du module est okay.

