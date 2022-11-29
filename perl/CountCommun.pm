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
# DESCRIPTION: Composant de comptages de compteurs commum 
#----------------------------------------------------------------------#

package CountCommun;
# les modules importes
use strict;
use warnings;
use Erreurs;
use Couples;
use CountLongLines;                                 # bt_filter_line
use Timeout;

use Ident;

# prototypes publics
sub CountCommun($$$);

# prototypes prives
sub count_re_i($$);                                 # bt_filter_line
sub count_nonempty_lines($);
sub count_blank_lines($);                           # bt_filter_line
sub count_alphanum_lines($);                        # bt_filter_line
sub count_literaux_numeriques_sans_symbole($);      # bt_filter_line
sub count_literaux_deux_chiffres($);                # bt_filter_line
sub count_bad_comments($);                          # bt_filter_line
sub try_count_measure($$$$);

# bt_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage du nombre d'expressions regulieres
# en etant insensitif a la casse
#-------------------------------------------------------------------------------
sub count_re_i($$)
{
    my ($sca, $re) = @_;
    my $n = 0;
    $n = () = $sca =~ /$re/smgi;
    return $n;
}

# bt_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage du nombre de lignes non vide du buffer
#-------------------------------------------------------------------------------
sub count_nonempty_lines($)
{
    my ($sca) = @_;
    my @x = $sca =~ /\S[^\n]*\n/smgo;
    my $n = @x;
    return $n;
}


# bt_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage du nombre de lignes blanches du buffer
#-------------------------------------------------------------------------------
sub count_blank_lines($)
{
    my ($sca) = @_;
    my $n = () = $sca =~ /^\s*?\n/smgo;
    return $n;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage du nombre de lignes avec caractere alphanum du buffer
#-------------------------------------------------------------------------------
sub count_alphanum_lines($)
{
    my ($sca) = @_ ;
# FIXME: Malformed UTF-8 character (unexpected continuation byte 0x8f, with 
# FIXME: no preceding start byte) in pattern match (m//) at
# FIXME: /cygdrive/c/PRESTATIONS/SAUVE/Outils_spec/src/Alarmes/Compteurs//CountCommun.pm line 69.

#    my $n = () = $sca =~ /\p{IsAlnum}[^\n]*\n/smgo; # ne ft pas : arrete le debugger Komodo
    my $n = () = $sca =~ /[A-Za-z0-9][^\n]*\n/smgo;  # pareil mais no pb dans Komodo
    return $n;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage du nombre de literaux numeriques ne correspondant pas a des symboles
#-------------------------------------------------------------------------------
sub count_literaux_numeriques_sans_symbole($)
{
    my ($sca) = @_;
    my $buffer_sans_symbole = $sca;
    $buffer_sans_symbole =~ s/^[^\n]*\bconst\b[^\n]*//smgio;
    my $n = () = $buffer_sans_symbole =~ /'^\p{IsAlpha}[0-9.e+-]+/smgio;
    return $n;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage du nombre de literaux numeriques composes d'au moins deux chiffres
#-------------------------------------------------------------------------------
sub count_literaux_deux_chiffres($)
{
    my ($sca) = @_;
    my $n = () = $sca =~ /^\p{IsAlpha}[0-9.e+-][0-9.e+-]+/smgio;
    return $n;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage du nombre de de mauvais commentaires
#-------------------------------------------------------------------------------
sub count_bad_comments($)
{
    my ($sca) = @_ ;

#  U+00E0 LATIN SMALL LETTER A WITH GRAVE
#  UTF-8: c3 a0  UTF-16BE: 00e0  Decimal: &#224;

#  U+00E9 LATIN SMALL LETTER E WITH ACUTE
#  UTF-8: c3 a9  UTF-16BE: 00e9  Decimal: &#233;
    my $x00e0 = pack("U0C*", 0xc3, 0xa0); # U+00E0 LATIN SMALL LETTER A WITH GRAVE
    my $x00e9 = pack("U0C*", 0xc3 , 0xa9); # U+00E9 LATIN SMALL LETTER E WITH ACUTE

    my $n =  count_re_i($sca, '(?:\!\!\!|\?\?\?|(?:A|$x00e0|a)\s+(?:v(?:$x00e9|e)rifier|faire|voir|revoir)|\b(?:TODO|FIXME|TBC|TBD|Attention)\b)' );
    return $n;
}

# bt_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: Foncttion de recuperation en cas d'erreur sur un comptage
#-------------------------------------------------------------------------------
sub try_count_measure($$$$)
{
    my ($desc, $proc, $arg, $ref_status) = @_;
    my $c;

    if (not defined ($arg))
    { 
        $c = Erreurs::COMPTEUR_ERREUR_VALUE;
        $$ref_status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE; # si une vue necessaire a l'algorithme de comptage n'est pas disponible
    }
    else
    {
        eval
        {
            $c = $proc->($arg);
        };
        if ($@)
        {
            Timeout::DontCatchTimeout();   # propagate timeout errors
            print STDERR "\n\n erreur dans $desc, avec $proc : $@ : $!\n avec le buffer \n" . substr($arg,0,400) . "\n...\n\n";
            $c = Erreurs::COMPTEUR_ERREUR_VALUE;
            $$ref_status |= Erreurs::COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE; # si un ou plusieurs comptages n'ont pas pu etre effectues
        }
    }
    return $c;
}

# Table des comptages communs
my @comptages = (
    [Ident::Alias_BlankLines(), \&count_blank_lines, "text"],			# bt_filter_line
    [Ident::Alias_CommentLines(), \&count_nonempty_lines, "comment"],			
    [Ident::Alias_AlphaNumCommentLines(), \&count_alphanum_lines, "comment"],	# bt_filter_line
    #[Ident::Alias_LinesOfCode(), \&count_nonempty_lines, "code_with_prepro"],
);

sub __countLinesOfView($$$$)
{
    my ($viewName, $vue, $compteurs, $mnemo) = @_;
    my $status = 0;

    # Default view.
    my $code = $viewName ;

    # Check if another view is forced by parameter
    if ( exists $vue->{'CountConfParam'} ) {
      my $CountParam = $vue->{'CountConfParam'};
      if (defined $vue->{$$CountParam}) {
        $code = $$CountParam;
      }  
    }

    my $c = [$mnemo, \&count_nonempty_lines, $code];
        my $m = try_count_measure ( $c->[0], $c->[1], $vue->{ $c->[2] }, \$status );
        eval
        {
          Couples::counter_add($compteurs, $c->[0], $m );
        };
        if ($@)
        {
          Timeout::DontCatchTimeout();   # propagate timeout errors
          print STDERR "[CountLinesOfText] computing error for $mnemo: $@\n" ;
        }
    return $status;
}

sub CountLinesOfText($$$)
{
    my ($unused, $vue, $compteurs) = @_;
    
    return __countLinesOfView('text', $vue, $compteurs, Ident::Alias_LinesOfText());
}

sub CountLinesOfScript($$$)
{
    my ($unused, $vue, $compteurs) = @_;
    
    return __countLinesOfView('script', $vue, $compteurs, Ident::Alias_LinesOfScript());
}

sub CountLinesOfCode($$$)
{
    my ($unused, $vue, $compteurs) = @_;
    my $status = 0;

    # Default view.
    my $code = 'code' ;

    # Check if another view is forced by parameter
    if ( exists $vue->{'CountConfParam'} ) {
      my $CountParam = $vue->{'CountConfParam'};
      if (defined $vue->{$$CountParam}) {
        $code = $$CountParam;
      }  
    }

    my $c = [Ident::Alias_LinesOfCode(), \&count_nonempty_lines, $code];
        my $m = try_count_measure ( $c->[0], $c->[1], $vue->{ $c->[2] }, \$status );
        eval
        {
          Couples::counter_add($compteurs, $c->[0], $m );
        };
        if ($@)
        {
          Timeout::DontCatchTimeout();   # propagate timeout errors
          print STDERR "Mesure non prise en compte: $@\n" ;
        }
    return $status;

}

sub CountLinesOfPrepro($$$)
{
    my ($unused, $vue, $compteurs) = @_;
    my $status = 0;

    # Default view.
    my $code = 'prepro_directives' ;

    # Check if another view is forced by parameter
    if ( exists $vue->{'CountConfParam'} ) {
      my $CountParam = $vue->{'CountConfParam'};
      if (defined $vue->{$$CountParam}) {
        $code = $$CountParam;
      }  
    }

    my $c = [Ident::Alias_LinesOfPrepro(), \&count_nonempty_lines, $code];
        my $m = try_count_measure ( $c->[0], $c->[1], $vue->{ $c->[2] }, \$status );
        eval
        {
          Couples::counter_add($compteurs, $c->[0], $m );
        };
        if ($@)
        {
          Timeout::DontCatchTimeout();   # propagate timeout errors
          print STDERR "Mesure non prise en compte: $@\n" ;
        }
    return $status;

} 

sub CountLinesOfCode_SansPrepro($$$)
{
    my ($unused, $vue, $compteurs) = @_;
    my $status = 0;
    my $c = [Ident::Alias_LinesOfCode(), \&count_nonempty_lines, 'sansprepro'];
        my $m = try_count_measure ( $c->[0], $c->[1], $vue->{ $c->[2] }, \$status );
        eval
        {
          Couples::counter_add($compteurs, $c->[0], $m );
        };
        if ($@)
        {
          Timeout::DontCatchTimeout();   # propagate timeout errors
          print STDERR "Mesure non prise en compte: $@\n" ;
        }
    return $status;

}

sub CountLinesOfCode_TextWithoutComment($$$)
{
    my ($unused, $vue, $compteurs) = @_;
    my $status = 0;

    my $cText = ['Nbr_LinesOfText', \&count_nonempty_lines, 'text'];
    my $mText = try_count_measure ( $cText->[0], $cText->[1], $vue->{ $cText->[2] }, \$status );

    my $cComment = ['Nbr_LinesOfComment', \&count_nonempty_lines, 'comment'];
    my $mComment = try_count_measure ( $cComment->[0], $cComment->[1], $vue->{ $cComment->[2] }, \$status );
    eval
    {
          Couples::counter_add($compteurs, Ident::Alias_LinesOfCode(), $mText-$mComment );
    };
    if ($@)
    {
          Timeout::DontCatchTimeout();   # propagate timeout errors
          print STDERR "Mesure non prise en compte: $@\n" ;
    }
    return $status;

}

sub CountLinesOfCode_agglo($$$)
{
    my ($unused, $vue, $compteurs) = @_;
    my $status = 0;
    my $LOC = 0;
    my $nb_CommentLines = 0;
 
    if (not defined ($vue->{'agglo'}))
    { 
        $LOC = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_CommentLines = Erreurs::COMPTEUR_ERREUR_VALUE;
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE; # si une vue necessaire a l'algorithme de comptage n'est pas disponible
    }
    else {
      $LOC = () = $vue->{'agglo'} =~ /P/g;
      $nb_CommentLines = () = $vue->{'agglo'} =~ /C/g;
    }
    eval
    {
          Couples::counter_add($compteurs, Ident::Alias_LinesOfCode(), $LOC );
          Couples::counter_add($compteurs, Ident::Alias_CommentLines(), $nb_CommentLines );
    };
    if ($@)
    {
          Timeout::DontCatchTimeout();   # propagate timeout errors
          print STDERR "Mesure non prise en compte: $@\n" ;
    }
    return $status;

}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des compteurs commun
# Point d'entree du module de comptage
#-------------------------------------------------------------------------------
sub CountCommun($$$)
{
    my ($fichier, $vue, $compteurs) = @_;
    my $status = 0;

    foreach  my $c ( @comptages )
    {
        my $m = try_count_measure ( $c->[0], $c->[1], $vue->{ $c->[2] }, \$status );
        eval
        {
          Couples::counter_add($compteurs, $c->[0], $m );
        };
        if ($@)
        {
          Timeout::DontCatchTimeout();   # propagate timeout errors
          print STDERR "Mesure non prise en compte: $@\n" ;
        }
    }
#     $status |= CountLongLines::CountLongLines($fichier, $vue, $compteurs); # bt_filter_line
    return $status;
}



1;

