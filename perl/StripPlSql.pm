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
# PLSQL


package StripPlSql;
use strict;
use warnings;

use Timing; # timing_filter_line
use StripUtils;
use Vues;


sub StripPLSQL($$$$);


use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
                 );

#StripUtils::init('StripPlSql', 1);

# automate de tri du contenu du fichier en trois parties:
# 1/ code
# 2/ commentaires ( de type -- ... et  /* ... */)
# 3/ chaines (de type ' ... ' )
sub separer_code_commentaire_chaine($$$)
{
    my ($source, $options, $couples) = @_;
    my $b_timing_strip = Timing->isSelectedTiming ('Strip')   ;                 # timing_filter_line
    my %hContext=();
    my $context=\%hContext;


    my $stripPlSqlTiming = new Timing ('StripPlSql:separer_code_commentaire_chaine', Timing->isSelectedTiming ('Strip'));
    my $c = $$source;
    my $state = 'INCODE' ;
    my $f = $state ;
    my $w = '';  #........................... Caractere attendu en fin de pattern string/comment/code
    my $string_buffer = '';

    my %strings_values = () ;
    my %strings_counts = () ;
    my %hash_strings_context = (
      'nb_distinct_strings' => 0,
      'strings_values' => \%strings_values,
      'strings_counts' => \%strings_counts  ) ;
    my $string_context = \%hash_strings_context;

    my %extendedidentifiers_values = () ;
    my %extendedidentifiers_counts = () ;
    my %hash_extendedidentifiers_context = (
      'nb_distinct_extendedidentifiers' => 0,
      'extendedidentifiers_values' => \%extendedidentifiers_values,
      'extendedidentifiers_counts' => \%extendedidentifiers_counts  ) ;
    my $extendedidentifier_context = \%hash_extendedidentifiers_context;

    $stripPlSqlTiming->markTimeAndPrint('--init--') if ($b_timing_strip); # timing_filter_line
    my @parts = split (  "([/*]+|\"|\n)" , $c );
    $stripPlSqlTiming->markTimeAndPrint('--split--') if ($b_timing_strip); # timing_filter_line
    my $stripPlSqlTimingLoop = new Timing ('StripPlSql internal Loop', Timing->isSelectedTiming ('Strip'));

    my %states_patterns = (
      # Recherche de debut de chaine ou de debut de commentaire
      'INCODE' =>  qr{\G(/[*]|--|-|q['].|\'|/|[*]|q|[^/*'q-]*)}sm ,

      'INCOMMENT' => qr{\G([*]/|/|[*]|[^/*]*)}sm ,
      'INSTRING' => undef , # defini dynamiquement
      'INEXTENDEDIDENTIFIER' => qr{\G(\"|[^\"]*)}sm , # defini dynamiquement
      #'INSTRING' => qr{\G(\'\'|\'|[^']*)}sm ,
    );

  my $vues = new Vues( 'plsql' ); # creation des nouvelles vues a partir de la vue plsql
  $vues->unsetOptionPosition();
  my $position = 0;
  $vues->declare('code_a');
  $vues->declare('comment_a');
  $vues->declare('mix_a');

  # FIXME: a implementer
  $vues->declare('directive_a');

    $context->{'next_state'} = $f;
    $context->{'expected_closing_pattern'} = $w;
    $context->{'string_context'} = $string_context;
    $context->{'extendedidentifier_context'} = $extendedidentifier_context;
    my $espaces;

    my $nb_iter = $#parts ;
    #for (my $part = 0; $part<= $nb_iter; $part++)
    for my $partie ( @parts )
    {
      my $debug_msg1 = 'Utilisation du buffer:                           ' ;    # traces_filter_line
      localTrace (undef, $debug_msg1 . $partie . "\n" );                        # traces_filter_line
        #$stripPlSqlTiming->markTimeAndPrint('--iter in split: ' . $part . '/' . $#parts  . '  --'); # timing_filter_line

        my $reg ;
pos ($partie) = 0;

        while  (
          # Mettre a jour l'expression rationnelle en fonction du pattern,
          # a chaque iteration.
          $reg =  $states_patterns{$state} ,
          $partie  =~ m/$reg/g )
        {
            my $element = $1;  # un morceau de fichier petit
#print STDERR 'debug: ' . $element . "\n" ;
#print STDERR 'debug: ' . $element . "avec " . $reg . " sur " . $partie . "\n" ;
            next if ( $element eq '') ;
            $espaces = $element ; # les retours a la ligne correspondant.
            #$stripPlSqlTimingLoop->markTimeAndPrint('--iter in split internal--'); # timing_filter_line
            $espaces = garde_newlines($espaces) ;
            #localTrace "debug_chaines",  "state: $state: working with  !!$e!! \n"; # traces_filter_line
        
            $context->{'element'} = $element;
            $context->{'blanked_element'} = $espaces;
        
            if ( $state eq 'INCODE' )
            {
              my $boutDeCode = $context->{'element'};
              if ( $boutDeCode =~ /\bwrapped\b/ism )
              {
                my $message = 'Fichier obfuscate';
                my $status = Erreurs::FatalError( Erreurs::ABORT_CAUSE_WRAPPED, $couples, $message);
                # FIXME...
                my @return_array =  ( \undef, \undef, [], \undef, $status);
                #@return_array =  ( \$code, \$comment, \%strings_values, \$Mix , 1);
                return \@return_array ;
              }
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
            elsif ( $state eq 'INEXTENDEDIDENTIFIER' )
            {
              separer_code_commentaire_chaine_INEXTENDEDIDENTIFIER($context, $vues);
            }
          $vues->commit ( $position);
          $position += length( $element) ;
        
            if (defined $options->{'--debug_stript_states'} )                   # traces_filter_line
            #: gain de 5 secondes sur 18 en commentant la trace suivante.       # traces_filter_line
            {                                                                   # traces_filter_line
              localTrace ('debug_stript_states', ' separer_code_commentaire_chaine, passage de ' . $state . ' vers ' . $context->{'next_state'} . ' sur !<<'  . $context->{'element'} . '>>!' . "\n") ;                                                                                                # traces_filter_line
            }                                                                   # traces_filter_line
            #localTraceTab ('debug_stript_states',                              # traces_filter_line
              #[ ' separer_code_commentaire_chaine, passage de ' , $state , ' vers ' , $f , ' sur !<<'  , $e , '>>!' , "\n" ]) ; # traces_filter_line
            $state = $context->{'next_state'};

            if (defined $context->{'set_pattern_instring'} )
            {
              $states_patterns{'INSTRING'} = $context->{'set_pattern_instring'} ;
#print STDERR "Pattern positionne a  " . $states_patterns{'INSTRING'}  . "\n" ;
              $context->{'set_pattern_instring'} = undef;
            }
        }
    }
    $f = $context->{'next_state'};
    $espaces = $context->{'blanked_element'};
    $w = $context->{'expected_closing_pattern'};


  my $comment = $vues->consolidate('comment_a');
  my $code = $vues->consolidate('code_a');
  my $Mix = $vues->consolidate('mix_a');

    $stripPlSqlTiming->markTimeAndPrint('--done--') if ($b_timing_strip); # timing_filter_line
    my @return_array ;
    if (not $state eq 'INCODE')
    {
        if (not ($w eq "\n")) # tolerance pour les fin
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

my %hash_mated_delimiters = (
    '(' => ')',
    '{' => '}',
    '[' => ']',
);


sub separer_code_commentaire_chaine_INCODE($$)
{
    my ($context, $vues)=@_;

    my $f = $context->{'next_state'};
    my $espaces = $context->{'blanked_element'};
    my $e = $context->{'element'};
    my $w = $context->{'expected_closing_pattern'};
    my $string_buffer = $context->{'string_buffer'};

    if ( $e eq '/*' )
    {
        $f = 'INCOMMENT'; $w = '*/' ;
                          # Au moins un blanc a la place d'un commentaire ...
      $vues->append( 'comment_a',  $e );
      $vues->append( 'code_a',  ' '.$espaces );
      $vues->append( 'mix_a',  $e);
    }
    elsif ( $e eq '--' )
    {
        $f = 'INCOMMENT'; $w = "\n" ;
      $vues->append( 'code_a',  $espaces );
      $vues->append( 'mix_a',  '/*'  );
      $vues->append( 'comment_a',  $e );
    }
    elsif ( $e eq "'" ) # literal (default delimiter)
    {
        $f = 'INSTRING'; $w = "'" ; 
      $context->{'set_pattern_instring'} = qr{\G(\'\'|\'|[^']*)}sm ;
        $string_buffer = $e ; 
      $vues->append( 'comment_a',  $espaces );
    }
    elsif ( $e eq '"' ) # extended identifier
    {
      $f = 'INEXTENDEDIDENTIFIER'; $w = '"' ; 
      #$context->{'set_pattern_instring'} = qr{\G(\'\'|\'|[^']*)}sm ;
      $context->{'extendedidentifier_buffer'} = $e ; 
      $vues->append( 'comment_a',  $espaces );
    }
    elsif ( $e =~ /\Aq['](.)\Z/ ) # literal (user defined delimiter)
    {
      my $delimiter = $1;
      $f = 'INSTRING'; 
      if ( $delimiter =~ /\A[!|]\z/ )
      {
        $w = $delimiter ; 
      }
      else
      {
        $w = $hash_mated_delimiters{$delimiter} ;
        if (not defined $w)
        {
          die "unknown literal delimiter";
        }
      }
#print STDERR "On va attendre: $w\n" ;
      # Un caractere autre que l'un des deux delimiteurs attendus.
      my $wRe = quotemeta ( $w );

      #my $otherRe = "[^'" .  $w  . "]" ;
      # NB: Cette sequence est clairement mauvaise, car si w est un
      # crochet fermant, il ferme le crochet ouvrant.
     
      my $otherRe = "[^" .  $w  . "']" ; # w peut etre un crochet fermant, et doit donc venir en premier

#print STDERR  qr{\G($wRe\'|\'|$wRe|$otherRe*)}sm ;

      $context->{'set_pattern_instring'} = qr{\G($wRe\'|\'|$wRe|$otherRe*)}sm ;
      $w .= "'" ;
#print STDERR "On va attendre, en fait: $w\n" ;
        $string_buffer = $e ; 
      $vues->append( 'comment_a',  $espaces );
    }
    else
    {
      $vues->append( 'code_a',  $e);
      $vues->append( 'mix_a',  $e);
      $vues->append( 'comment_a',  $espaces );
    }
    $context->{'string_buffer'} = $string_buffer;
    $context->{'next_state'} = $f;
    $context->{'expected_closing_pattern'} = $w;
}

sub separer_code_commentaire_chaine_INCOMMENT($$)
{
    my ($context, $vues)=@_;

    my $f = $context->{'next_state'};
    my $espaces = $context->{'blanked_element'};
    my $e = $context->{'element'};
    my $w = $context->{'expected_closing_pattern'};
    # RQ: dans la vue Mix, tous les commentaires multilignes sont mis au format
    # monoligne, et les commentaires "//" sont transformes en "/* ... */".
    # Pour cette raison, les eventuelles sequences "/*" ou "*/" qui traineraient dans
    # un commentaire "//" sont supprimes ...

    #localTrace undef "receive: <$e>, waiting <$w> \n"; # traces_filter_line
    if ( $e eq $w )
    {
        if ($w eq "\n")
        {
          $vues->append( 'mix_a',  "*/\n" );
        }
        else
        {
          $vues->append( 'mix_a',  $e );
        };
        $f = 'INCODE'; $w = '' ;
      $vues->append( 'code_a',  $espaces );
      $vues->append( 'comment_a',  $e );
    }
    else
    {
        # Suppression des "/*" et  "*/"  qui pourraient trainer ...

      $vues->append( 'code_a',  $espaces );
      $vues->append( 'comment_a',  $e );
        if ($e eq "\n")
        {
          $vues->append( 'mix_a',  "*/\n/*" );
        }
        else
        {
            #if ( $e =~ m{\A[/*]+\z} )
            my %aSupprimer =  (  '/' =>1,  '*'=>1,  '*/'=>1   );
            #if ( ( $e eq '/'  ) || ( $e eq '*' ) || ( $e eq '*/' ) )
            if ( exists $aSupprimer{$e} )
            {
              $vues->append( 'mix_a',  ' ');
            }
            else
            {
              $vues->append( 'mix_a',  $e);
            }
            #$e =~ s/(\/\*|\*\/)/ /g ; # FIXME: consomme entre 2 et 3 secondes sur 20.
            #$Mix .= $e;
        }
    }
    $context->{'next_state'} = $f;
    $context->{'expected_closing_pattern'} = $w;
}

#  Fonction de gestion des identificateurs etendus dans des codes sources
sub IdentifierStore($$)
{
  my ($context, $ExtendedIdentifier_buffer)=@_;
  #localTrace undef , join ( ',' , keys ( %{$context} ) ) . "\n" ; # traces_filter_line
  my ($id, $nb) = ($context->{'nb_distinct_extendedidentifiers'}, 1);
  if (defined $context->{'extendedidentifiers_counts'}->{$ExtendedIdentifier_buffer} )
  {
    # Si la chaine a deja ete rencontree, on recupere son id et
    # on incremente son nombre d'occurence.
    ($id, $nb) = @{$context->{'extendedidentifiers_counts'}->{$ExtendedIdentifier_buffer}};
    $nb ++;
  }
  else
  {
    # Si il s'agit de la premiere occurence de la chaine, on
    # incremente de nombre total de chaines distinctes, et l'id
    # de la chaine prend cette valeur.
    $context->{'nb_distinct_extendedidentifiers'}++;
    $id = $context->{'nb_distinct_extendedidentifiers'};
  }

  # memorisation des infos relatives a la chaine.
  $context->{'extendedidentifiers_counts'}->{$ExtendedIdentifier_buffer} = [ $id, $nb ];

  # On construit la cle d'acces a la valeur de la chaine.
  my $ExtendedIdentifier_id = 'EXTENDEDIDENT_'.$id;
  if ( ! defined $context->{'extendedidentifiers_values'}->{$ExtendedIdentifier_id})
  {
    $context->{'extendedidentifiers_values'}->{$ExtendedIdentifier_id} = $ExtendedIdentifier_buffer ;
  }
  return $ExtendedIdentifier_id ;
}

sub separer_code_commentaire_chaine_INSTRING($$)
{
    my ($context, $vues)=@_;

    my $f = $context->{'next_state'};
    my $espaces = $context->{'blanked_element'};
    my $e = $context->{'element'};
    my $w = $context->{'expected_closing_pattern'};
    my $string_buffer = $context->{'string_buffer'};
    my $string_context = $context->{'string_context'};
    # car en C, les chaine speuvent etre multi lignes.

    if ( $e eq $w )   #il s'agit bien d'une fin de chaine.
    {
        $f = 'INCODE'; $w = '' ;
        $string_buffer .= $e ;
      $vues->append( 'comment_a',  $espaces );

        my $string_id = StringStore( $string_context, $string_buffer );

        # Dans la vue "code", la chaine est remplace par CHAINE_<id>_<occurence> ...
        #$code .= $string_id . '_' . $nb ;
        # Finalement on ne concatene pas le numero d'occurence.
      $vues->append( 'code_a',  ' '. $string_id .' ');
      $vues->append( 'mix_a',  ' '. $string_id .' ');
      #erreur? $vues->append( 'code_a',  ' '.$string_id );
        # ? ? ? ? ? ?push @{$context->{'code_a'}}, $string_id ;

        $string_buffer = '' ;
    }
    else
    {
        #localTrace 'debug_chaines', "string_buffer:<- $string_buffer\n"; # traces_filter_line
        $string_buffer .= $e ;
        # Dans ce cas, on ne repercute pas les blancs dans la vue code.
        #$code .= $espaces;
      $vues->append( 'comment_a',  $espaces );
        #localTrace 'debug_chaines', "string_buffer:-> $string_buffer\n"; # traces_filter_line
    }

  $context->{'string_context'} = $string_context;
  $context->{'string_buffer'} = $string_buffer;
  $context->{'next_state'} = $f;
  $context->{'expected_closing_pattern'} = $w;
}

sub separer_code_commentaire_chaine_INEXTENDEDIDENTIFIER($$)
{
  my ($context, $vues)=@_;

  my $NextState = $context->{'next_state'};
  my $espaces = $context->{'blanked_element'};
  my $Element = $context->{'element'};
  my $ExpectedPattern = $context->{'expected_closing_pattern'};

  my $extendedidentifier_buffer = $context->{'extendedidentifier_buffer'};
  my $extendedidentifier_context = $context->{'extendedidentifier_context'};
  # en supposant qu'en PL/SQL, les identificateur etendus peuvent etre multi lignes.

  if ( $Element eq $ExpectedPattern )   #il s'agit bien d'une fin d'identificateur
  {
    $NextState = 'INCODE'; $ExpectedPattern = '' ;
    $extendedidentifier_buffer .= $Element ;
    $vues->append( 'comment_a',  $espaces );

    my $extendedidentifier_id = IdentifierStore( $extendedidentifier_context, $extendedidentifier_buffer );

    # Dans la vue "code", la chaine est remplace par CHAINE_<id>_<occurence> ...
    # Finalement on ne concatene pas le numero d'occurence.
    $vues->append( 'code_a',  ' '. $extendedidentifier_id .' ');
    $vues->append( 'mix_a',  ' '. $extendedidentifier_id .' ');

    $extendedidentifier_buffer = '' ;
  }
  else
  {
    #localTrace 'debug_chaines', "extendedidentifier_buffer:<- $extendedidentifier_buffer\n"; # traces_filter_line
    $extendedidentifier_buffer .= $Element ;
    # Dans ce cas, on ne repercute pas les blancs dans la vue code.
    $vues->append( 'comment_a',  $espaces );
    #localTrace 'debug_chaines', "extendedidentifier_buffer:-> $extendedidentifier_buffer\n"; # traces_filter_line
  }

  $context->{'extendedidentifier_context'} = $extendedidentifier_context;
  $context->{'extendedidentifier_buffer'} = $extendedidentifier_buffer;
  $context->{'next_state'} = $NextState;
  $context->{'expected_closing_pattern'} = $ExpectedPattern;
}


# FIXME: Cette fonction ne semble pas satisfaisante dans le cas suivant:
# FIXME: ELSE
# FIXME:   $ERROR
# FIXME:     'list_to_collection INCOMPLETE!
# FIXME:     Finish extraction of next item from list.
# FIXME:     Go to ' || $$PLSQL_UNIT || ' at line ' || $$PLSQL_LINE
# FIXME:   $END
# FIXME: END IF;
sub separer_code_directive($$)
{
  my ($source, $options) = @_;

  my $tampon_d_entree = $$source;
  my @parts = split (  "(\n)" , $tampon_d_entree );

  my $vues = new Vues( 'code_and_directives' ); # creation des nouvelles vues a partir de la vue plsql
  $vues->unsetOptionPosition();
  my $position = 0;
  $vues->declare('without');
  $vues->declare('directive');

  for my $partie ( @parts )
  {
    my $espaces = $partie ; # les retours a la ligne correspondant.
    $espaces = garde_newlines($espaces) ;
    
    if ( $partie =~ /\A\s*[\$]/ )
    {
      $vues->append( 'directive',  $partie );
      $vues->append( 'without',  $espaces );
    }
    else
    {
      $vues->append( 'directive',  $espaces );
      $vues->append( 'without',  $partie );
    }
    
    $vues->commit ( $position);
    $position += length( $partie) ;
  }

  my $directive = $vues->consolidate('directive');
  my $code_without_directive = $vues->consolidate('without');

  my @return_array =  ( 0, \$directive, \$code_without_directive);
  return \@return_array ;

}

# Cette routine reagit sur les mots clefs SQL-DML (insert|update|delete)
# Elle eagit egalement sur le mot clef select
# La reaction s'arrete en fin d'instruction.
sub recuperer_sql($$$)
{
    my ($filename, $vue, $options) = @_;
    my $c = $vue->{'code'};
    my $debug = 0;
    my @arr_to_erase;
    my $previous_pos = 0;
    while ($c =~ m{
                    (                                                   #1
                        \s((select|insert|update|delete)\s.*?;)         #2 #3
                    )
            }gxmsi)
    {
        my $match_all = $1;
        my $match_requete_sql = $2;
        
        my $pos_c = pos($c) - 1; # sur dernier caractere
        my $len = length($match_requete_sql);
        my $pos_start = $pos_c - $len + 1;
        push(@arr_to_erase, [$previous_pos, $pos_start-1]);
        $previous_pos = $pos_c + 1;
    }
    # le dernier segment
    my $len_buffer = length($c);
    push(@arr_to_erase, [$previous_pos, $len_buffer-1]);
    
    foreach my $zone(@arr_to_erase)
    {
        my $start = $zone->[0];
        my $end   = $zone->[1];
        my $nb = $end - $start + 1;
        print STDERR "ERASE $start-$end : from $start, nb = $nb\n" if ($debug); # traces_filter_line
        substr($c, $start, $nb) =~ s/[^\n\s]/ /sg;
    }
    
    $vue->{'sql'} = $c;
    
    return 0;
}

sub StripConditions($)
{
  my ($vue) = @_;

  my $input = $vue->{'statements_lc'};
  my @conditions = ();
  for my $statement_lc ( @{$input} )
  {
    if ( $statement_lc =~ /\b(?:elsif|if|when)\b\s*([^;]*)\bthen\b/sm )
    {
      my $condition = $1;
      push @conditions, $condition;
    }
    elsif ( $statement_lc =~ /\b(?:while)\b\s*([^;]*)\bloop\b/sm )
    {
      my $condition = $1;
      push @conditions, $condition;
    }
    elsif ( $statement_lc =~ /\b(?:exit\s*when)\b\s*([^;]*)/sm )
    {
      my $condition = $1;
      push @conditions, $condition;
    }
  }
  return \@conditions;
}

sub _DumpList($$)
{
  my ($bloc, $stream) = @_;
  for my $item  ( @{$bloc}  )
  {
    print $stream $item ."\n    -*-\n" ;
  }
}

sub _IsCompleteStatement($)
{
  my ($statement) = @_;

  my $buffer = $statement;

  if ( $statement =~ /\A\s*(?:\bend\b)?\s*\bcase\b/smi )
  {
    return 1;
  }

# On consider qu'un instruction est compete, lorsque chaque expression case 
# se temine par le token end.

  
  $buffer =~ s/[\{}]//smig ;
  $buffer =~ s/\bcase\b/\{/smig ;
  $buffer =~ s/\bend\b/}/smig ;
  $buffer =~ s/[^\{}]//smig ;
  while ( $buffer =~ /\{}/smi )
  {
    $buffer =~ s/\{}//smig ;
  }
 
  if  ( $buffer =~ /[\{]/smi )
  {
    return 0;
  }
  return 1;

# ancienne implementation ne prenant pas en compte les case imbriques...
  if ( $statement !~ /\bcase\b/smig ) # un cas particulier
  {
    return 1;
  }
  my @parts = split ( /(\bcase\b.*\bend\b)/smi , $statement );
  # le cas general
  my $last = $parts[-1];
  if ( $last !~ /\bcase\b/smig ) 
  {
    return 1;
  }
  return 0;
}

sub StripStatements($)
{
  my ($vue) = @_;

  Erreurs::LogInternalTraces('trace', undef, undef, 'Strip', '', 'Creation de la vue statements');
  my @statements =  split ( /;/sm , $vue->{'code_without_directive'} ) ;

  my @statements_recompose = ();
  for my $statement1 ( @statements)
  {
    next if not defined $statement1;
    push @statements_recompose, $statement1;
  }
  $vue->{'statements'} = \@statements_recompose;

  # (?=\S)(?<!\S)|(?!\S)(?<=\S
  my $PlSqlWordBoundary = qr/(?:(?=\S)(?<!\S)|(?!\S)(?<=\S))/;

  # FIXME: le decoupage ne s'effectue pas correctement sur as, is, etc, car correspond aussi au tout sauf accolade...
  #my @statements_with_blanks =  split ( /([^;]*(?:\bas\b|\bis\b|;|\bbegin\b|\bthen\b|\A)\s*)/smi , $vue->{'code_without_directive'} ) ;
  my @statements_with_blanks =  split ( 
    /(?:(\b[0-9]*)((?:self\s\s*as\s\s*result\b|as\b|is\b|begin\b|end\b|then\b|case\b|else\b|declare\b|loop\b|when\b|exception\b)\s*)|((?:;|<<(?:[^>]|[>][^>])*>>|\A)\s*))/smi , 
    $vue->{'code_without_directive'} ) ;

  my @statements_with_blanks_recompose = ( );
  my $recomp = '';
  my $BreakOn_Is_As =0;
  my $BreakOn_Is    =0;
  my $BreakBeforeBeginOrDeclare         =0;
  my $BreakAfterCompleteStatement                    =1;
  # NB: ce decoupage doit etre adapte pour le module Parse.
  for my $statement ( @statements_with_blanks )
  {
    next if not defined $statement;
    #next if $statement eq '';
    my $ne_rien_faire = undef;

    if ( $recomp =~ /\A\s*\b(?:create\s*(or\s*replace\s*)?)?\b(?:(?:constructor\s*|static\s*|(?:order\s*|map\s*|overriding\s*)?member\s*)?(?:function|procedure))\b/ism )
    {
      $BreakOn_Is_As = 1;
      $BreakOn_Is = 0;
      $BreakBeforeBeginOrDeclare      = 0;
      $BreakAfterCompleteStatement      = 1;
    }
    # package est suivi d'un bloc is/as
    elsif ( $recomp =~ /\A\s*\b(?:create\s*(or\s*replace\s*)?)?\b(?:package\s\s*(?:body\s*)?)\b/ism )
    {
      $BreakOn_Is_As = 1;
      $BreakOn_Is = 0;
      $BreakBeforeBeginOrDeclare      = 0;
      $BreakAfterCompleteStatement      = 1;
    }
    # trigger est suivi d'un bloc
    elsif ( $recomp =~ /\A\s*\b(?:create\s*(or\s*replace\s*)?)?\b(?:trigger\s\s*)/ism )
    {
      $BreakOn_Is_As = 0;
      $BreakOn_Is = 0;
      $BreakBeforeBeginOrDeclare      = 1;
      $BreakAfterCompleteStatement      = 1;
    }
    # type body est suivi d'un bloc is/as
    elsif ( $recomp =~ /\A\s*\b(?:create\s*(or\s*replace\s*)?)?\b(?:type\s\s*(?:body\s*))\b/ism )
    {
      $BreakOn_Is_As = 1;
      $BreakOn_Is = 0;
      $BreakBeforeBeginOrDeclare      = 0;
      $BreakAfterCompleteStatement      = 1;
    }
    elsif ( not _IsCompleteStatement( $recomp ) )
    {
      $BreakOn_Is_As = 0;
      $BreakOn_Is = 0;
      $BreakBeforeBeginOrDeclare      = 0;
      $BreakAfterCompleteStatement      = 0;
    }
    else # instruction complete
    {
      $BreakOn_Is_As = 0;
      $BreakOn_Is = 0;
      $BreakBeforeBeginOrDeclare      = 0;
      $BreakAfterCompleteStatement      = 1;
    }
    if (($BreakBeforeBeginOrDeclare and  $statement  =~ m/\A\s*((?:\bbegin\b)\s*)/smi ) ||
       (                                 $statement  =~ m/\A\s*((\bbegin\b|\bdeclare\b)\s*)/smi ) ||
       (  $BreakAfterCompleteStatement           and  $statement  =~ m/\A\s*((\bend\b)\s*)/smi ) )
    {
      if ( $recomp ne '' )
      {
#print STDERR "STMT(1):" . $statement . '  ---> ' . $recomp . "\n" ;
        push @statements_with_blanks_recompose, $recomp;
        $recomp = '';
      #$ne_rien_faire = 1 ;
      }
    }
    if ( $recomp eq '' and $statement  =~ m/\A\s*((?:\bcase\b|\bfor\b\b)\s*)/smi )
    {
      #print STDERR "DEBUG:RECOMP:" . $recomp . "/\n";
      $ne_rien_faire = 1 ;
      # Ne rien faire
    }
    $recomp .= $statement;

    if ( not _IsCompleteStatement( $recomp ) )
    {
      $ne_rien_faire = 1 ;
    }

#print STDERR 'debug: ' . $statement . '-> ' . $recomp ."\n" ;
    if (   ( not defined $ne_rien_faire ) and
         ( ( $recomp =~ m/\A((?:\bexception\b|\bcase\b|\belse\b|<<)\s*)/smi )
        || ( ( $BreakAfterCompleteStatement ==1 ) and ( $statement =~ m/\A((?:\bthen\b)\s*)/smi ) )
        || ( ( $BreakOn_Is ==1 ) and ( $statement =~ m/\A((?:\bis\b)\s*)/smi ) )
        || ( ( $BreakOn_Is_As ==1 ) and ( $statement =~ m/\A((?:\bas\b|\bis\b)\s*)/smi ) )
        || ( $statement =~ m/\A((?:;)\s*)/smi ) 
        || ( $statement =~ m/\A((?:\bbegin\b|\bdeclare\b|\bloop\b)\s*)/smi ) ) 
       )
    {
#print STDERR 'debug: ready for commit' .$BreakOn_Is . ' ' . $BreakOn_Is_As . "\n" ;

#print STDERR 'debug: _IsCompleteStatement (recomp) ' ._IsCompleteStatement($recomp) . '  -> ' .  "\n" ;

#print STDERR "STMT(2):" . $statement .'  ---> ' . $recomp .  "\n" ;
        push @statements_with_blanks_recompose, $recomp;
        $recomp = '';
    }
    else
    {
      ; # Ne rien faire
    }
  }
  push @statements_with_blanks_recompose, $recomp;

  $vue->{'statements_with_blanks'} = \@statements_with_blanks_recompose;
  $vue->{'dump_functions'}->{'statements_with_blanks'} = \&_DumpList;

  #$vue->{'statements_lc'} = \  map(lc, @{$vue->{'statements_with_blanks'}} ) ;
  my @Slc =  map(lc, @{$vue->{'statements_with_blanks'}} );
  $vue->{'statements_lc'} = \@Slc;
#print STDERR 'statements_lc: ' . $vue->{'statements_lc'} . "\n" ;
  $vue->{'dump_functions'}->{'statements_lc'} = \&_DumpList;


}

# analyse du fichier
sub StripPlSql($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = Timing->isSelectedTiming ('Strip')   ;                 # timing_filter_line
#print STDERR join ( "\n", keys ( %{$options} ) );
    configureLocalTraces('StripPlSql', $options);                               # traces_filter_line
    my $stripPlSqlTiming = new Timing ('StripPlSql', $b_timing_strip);          # timing_filter_line

    localTrace ('verbose',  "working with  $filename \n");                      # traces_filter_line
    my $text = $vue->{'plsql'};

    $stripPlSqlTiming->markTimeAndPrint('--init--') if ($b_timing_strip);       # timing_filter_line

    my $ref_sep = separer_code_commentaire_chaine(\$text, $options, $couples);
    $stripPlSqlTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

    my($c, $comments, $rt_strings, $MixBloc, $err) = @{$ref_sep} ;
    $vue->{'comment'} = $$comments;
    $vue->{'HString'} = $rt_strings;
    $vue->{'code_and_directives'} = $$c;
    $vue->{'MixBloc'} = $$MixBloc;

#    return ErrStripError()  if ($err gt 0);

    # vues crees pour compatibilite avec d'autres langages
    $vue->{'code_with_prepro'} = $vue->{'code_and_directives'};
    $vue->{'code'} = $vue->{'code_and_directives'};

    if ( defined $options->{'--dumpstrings'})
    {
        dumpVueStrings(  $rt_strings , $STDERR );
    }

    if ( not Erreurs::isAborted($err) )
    {
      $ref_sep = separer_code_directive($c, $options);

      $stripPlSqlTiming->markTimeAndPrint('separer_code_directive');              # timing_filter_line
      $stripPlSqlTiming->dump('StripPlSql') if ($b_timing_strip);                 # timing_filter_line

      my (  $directives, $code_without_directive);
      ($err, $directives, $code_without_directive) = @{$ref_sep} ;
      $vue->{'code_without_directive'} = $$code_without_directive ;
      $vue->{'code_lc_without_directive'} = lc ( $$code_without_directive ) ;
      $vue->{'directives'} = $$directives;

      StripStatements($vue);

      sub _DumpConditionnalExpressions($$)
      {
        my ($refArray, $stream) = @_;
        for my $item ( @{$refArray} )
        {
          if ( $item !~ /^ *$/ )
          {
            print $stream  $item . "\n";
            print $stream " - - - -\n" ;
          }
        }
      }

      $vue->{'conditionnal_expressions'} = StripConditions( $vue );
      $vue->{'dump_functions'}->{'conditionnal_expressions'} = \&_DumpConditionnalExpressions;

      my $status = 0;
      #PlSql::ParseBody::ParseBody ($filename, $vue, $options, $couples) ;
    }


  if ($err gt 0)
  {
    if ( Erreurs::isAborted($err) )
    {
      return $err;
    }
    else
    {
      my $message = 'Erreur lors de la separation du code et des directives de compilation';
      return Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    }
  }
    
    my $err2 = recuperer_sql($filename, $vue, $options);
    return ErrStripError()  if ($err2 gt 0);
    
    return 0;
}

1; # Le chargement du module est okay.

