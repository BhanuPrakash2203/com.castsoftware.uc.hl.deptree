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
# Abap


package StripAbap;
use strict;
use warnings;

use Timing; # timing_filter_line
use StripUtils;
use Vues;


sub StripAbap($$$$);


use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
		  dumpVueStrings
                 );

my $firstpattern = 1;

# automate de tri du contenu du fichier en trois parties:
# 1/ code
# 2/ commentaires ( de type * et ""
# 3/ chaines (de type '...' et `...` )
sub separer_code_commentaire_chaine($$$)
{
    my ($source, $options, $couples) = @_;
    my $b_timing_strip = Timing->isSelectedTiming ('Strip')   ;                 # timing_filter_line
    my %hContext=();
    my $context=\%hContext;


    my $stripPlSqlTiming = new Timing ('StripAbap:separer_code_commentaire_chaine', Timing->isSelectedTiming ('Strip'));
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
    #my @parts = split (  "([/*]+|\"|\n)" , $c );
    my @parts = split (  "(\n[*]|\n)" , $c );
    $stripPlSqlTiming->markTimeAndPrint('--split--') if ($b_timing_strip); # timing_filter_line
    my $stripPlSqlTimingLoop = new Timing ('StripAbap internal Loop', Timing->isSelectedTiming ('Strip'));

    my %states_patterns = (
      # comment beginning is : "*" at beginning of line, or " ...
      # string beginning is ' or `
      'INCODE' =>  qr{\G(\n[*]|\"|\'|\`|[*]|\n|[^'`"*\n]*)}sm ,

      # End comment is end of line.
      # The pattern "\n[*]" should be recognized because the \n it contains is not the end of the comment ...
      'INCOMMENT' => qr{\G(\n[*]|\n|[*]|[^\n*]*)}sm ,

      # escaped ' or ` are respectively '' and ``
      # end of string is ' or `
      'INSTRING' => qr{\G(\'\'|\`\`|\'|\`|[^'`]*)}sm ,
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

    $firstpattern = 1;

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
            next if ( $element eq '') ;
            $espaces = $element ; # les retours a la ligne correspondant.
            #$stripPlSqlTimingLoop->markTimeAndPrint('--iter in split internal--'); # timing_filter_line
            $espaces = garde_newlines($espaces) ;
            #localTrace "debug_chaines",  "state: $state: working with  !!$e!! \n"; # traces_filter_line
        
            $context->{'element'} = $element;
            $context->{'blanked_element'} = $espaces;
        
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
        
            if (defined $options->{'--debug_stript_states'} )                   # traces_filter_line
            #: gain de 5 secondes sur 18 en commentant la trace suivante.       # traces_filter_line
            {                                                                   # traces_filter_line
              localTrace ('debug_stript_states', ' separer_code_commentaire_chaine, passage de ' . $state . ' vers ' . $context->{'next_state'} . ' sur !<<'  . $context->{'element'} . '>>!' . "\n") ;                                                                                                # traces_filter_line
            }                                                                   # traces_filter_line
            #localTraceTab ('debug_stript_states',                              # traces_filter_line
              #[ ' separer_code_commentaire_chaine, passage de ' , $state , ' vers ' , $f , ' sur !<<'  , $e , '>>!' , "\n" ]) ; # traces_filter_line
            $state = $context->{'next_state'};

	    $firstpattern = 0;
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
            @return_array =  ( \$code, \$comment, \%hash_strings_context, \$Mix , 1);
            return \@return_array ;
        }
    }
    @return_array =  ( \$code, \$comment, \%hash_strings_context, \$Mix , 0);
    return \@return_array ;
}

sub separer_code_commentaire_chaine_INCODE($$)
{
    my ($context, $vues)=@_;

    my $f = $context->{'next_state'};
    my $espaces = $context->{'blanked_element'};
    my $e = $context->{'element'};
    my $w = $context->{'expected_closing_pattern'};
    my $string_buffer = $context->{'string_buffer'};

    if (   ( $e eq "\n*" ) ||
         ( ( $e eq "*" )   && ($firstpattern) ) )

    {
        $f = 'INCOMMENT'; $w = "\n" ;
                          # Au moins un blanc a la place d'un commentaire ...
      $vues->append( 'comment_a',  $e );
      $vues->append( 'code_a',  ' '.$espaces );
      #$vues->append( 'mix_a',  '/*');
      $vues->append( 'mix_a',  $e);
    }
    elsif ( $e eq '"' )
    {
      $f = 'INCOMMENT'; $w = "\n" ;
      $vues->append( 'code_a',  $espaces );
      #$vues->append( 'mix_a',  '/*' );
      $vues->append( 'mix_a',  $e );
      $vues->append( 'comment_a',  $e );
    }
    elsif ( $e eq "'" ) # literal char
    {
        $f = 'INSTRING'; $w = "'" ; 
        $string_buffer = $e ; 
      $vues->append( 'comment_a',  $espaces );
    }
    elsif ( $e eq '`' ) # extended chain
    {
      $f = 'INSTRING'; $w = '`' ; 
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

    #localTrace undef "receive: <$e>, waiting <$w> \n"; # traces_filter_line
    if ( $e eq $w )
    {
      #$vues->append( 'mix_a',  "*/\n" );
      $vues->append( 'mix_a',  $e );
      $f = 'INCODE'; $w = '' ;
      $vues->append( 'code_a',  $espaces );
      $vues->append( 'comment_a',  $e );
    }
    else
    {
      $vues->append( 'code_a',  $espaces );
      $vues->append( 'comment_a',  $e );
      $vues->append( 'mix_a',  $e);
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
    
    #if ( $partie =~ /\A\s*[\$]/ )
    if ( 0 ) # Do not extract directives ...
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
sub remove_native_sql_content($$$)
{
    my ($filename, $vue, $options) = @_;
    my $c = \$vue->{'code'};
    my $debug = 0;
    my @arr_to_erase;
    my $previous_pos = 0;
    while ($$c =~ m{
                    \bexec\s+sql\.(?:[^\n]*\n)?(.*?)\bendexec\b       
            }gxmsi)
    {
        my $native = $1;
        my $nativeLength = length($native);
	my $pos_native = pos($$c)-7-$nativeLength;

        push(@arr_to_erase, [$pos_native, $nativeLength]);
    }
    
    foreach my $zone(@arr_to_erase)
    {
        my $start = $zone->[0];
        my $nb   = $zone->[1];
        substr($$c, $start, $nb) =~ s/[^\n\s]/ /sg;
    }
    
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
  
# FIXME: le decoupage ne s'effectue pas correctement sur as, is, etc, car correspond aussi au tout sauf accolade...
  
  my @statements_with_blanks =  split ( 
    /(\.)/smi, 
    $vue->{'code'} ) ;

#print join("\n-------------------------------\n",  @statements_with_blanks);

  # Filtering of "blank" statements ...
#  my $idx=0;
#
#  while ( $idx < scalar  @statements_with_blanks) {
#    if ( $statements_with_blanks[$idx] !~ /\S/sg ) {
#      splice (@statements_with_blanks, $idx, 1) ;
#    }
#    else {
#      $idx++;
#    }
#  }

  $vue->{'statements_with_blanks'} = \@statements_with_blanks;
  #$vue->{'dump_functions'}->{'statements_with_blanks'} = \&_DumpList;

  my @Slc =  map(lc, @{$vue->{'statements_with_blanks'}} );
  $vue->{'statements_lc'} = \@Slc;
#print STDERR 'statements_lc: ' . $vue->{'statements_lc'} . "\n" ;
#  $vue->{'dump_functions'}->{'statements_lc'} = \&_DumpList;

  


}

sub agglomerate($$) {
  my $Mix = shift;
  my $agglo = shift;

  #while ( $$Mix =~ /(\/\*(?:[\*][^\/]|[^\*])*\*\/)|((?:[\/]([^\*]|\Z)|[^\/])*)/sg ) {
  #
  #while ( $$Mix =~ /((?:(?:\A|\G)[*]|\")(?:[^\n]|\n[*])*(?:[\n]|\Z))|((?:\n[^*]|[^\"\*])*)/sg ) {
  #
  
  # Capture the code & comments, line after line.
  #
  # A comment begins with '*' or " at beginning of the pattern and ends at new line.
  # code ends at " or new line.
  while ( $$Mix =~ /((?:(?:\A|\G)[*]|\")[^\n]*(?:\n|\Z))|([^\"\n]*\n?)/sg ) {
    # $1 capture: /* ... */, then it is replaced by a "C" for Comment ...
    if (defined $1) {
      $$agglo .= "C\n";
    }
    elsif (defined $2) {
      my $code = $2;
      # if code contain something not blank, mark it as code (P).
      if ( $code =~ /[^ \t\n]/s ) {
        $$agglo .= "P";
	# if code contains a \n, then add it ...
	if ( $code =~ /\n/ ) {
          $$agglo .= "\n";
	}
      }
      else {
	# Code contains only blanks. If one is a '\n', then mark it as a blank line, else nothing.
	if ( $code =~ /\n/ ) {
          $$agglo .= "\n";
	}
      }
    }
  }
}


# analyse du fichier
sub StripAbap($$$$)
{
    my ($filename, $vue, $options, $couples) = @_;
    my $b_timing_strip = Timing->isSelectedTiming ('Strip')   ;                 # timing_filter_line
#print STDERR join ( "\n", keys ( %{$options} ) );
    configureLocalTraces('StripAbap', $options);                               # traces_filter_line
    my $stripPlSqlTiming = new Timing ('StripAbap', $b_timing_strip);          # timing_filter_line

    localTrace ('verbose',  "working with  $filename \n");                      # traces_filter_line
    my $text = $vue->{'text'};

    $stripPlSqlTiming->markTimeAndPrint('--init--') if ($b_timing_strip);       # timing_filter_line

    my $ref_sep = separer_code_commentaire_chaine(\$text, $options, $couples);
    $stripPlSqlTiming->markTimeAndPrint('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

    my($c, $comments, $rt_strings, $MixBloc, $err) = @{$ref_sep} ;
    $vue->{'comment'} = $$comments;
    $vue->{'HString'} = $rt_strings;
    $vue->{'code_and_directives'} = $$c;
    $vue->{'MixBloc'} = $$MixBloc;
    $vue->{'agglo'} = "";
    agglomerate($MixBloc, \$vue->{'agglo'});

#    return ErrStripError()  if ($err gt 0);

    # vues crees pour compatibilite avec d'autres langages
    $vue->{'code_with_prepro'} = $vue->{'code_and_directives'};
    $vue->{'code'} = $vue->{'code_and_directives'};

    if ( defined $options->{'--dumpstrings'})
    {
        dumpVueStrings(  $rt_strings->{'strings_values'} , $STDERR );
    }

    if ( not Erreurs::isAborted($err) )
    {
      $ref_sep = separer_code_directive($c, $options);

      $stripPlSqlTiming->markTimeAndPrint('separer_code_directive');              # timing_filter_line
      $stripPlSqlTiming->dump('StripAbap') if ($b_timing_strip);                 # timing_filter_line

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
    
    my $err2 = remove_native_sql_content($filename, $vue, $options);
    return ErrStripError()  if ($err2 gt 0);
    
    return 0;
}

1; # Le chargement du module est okay.

