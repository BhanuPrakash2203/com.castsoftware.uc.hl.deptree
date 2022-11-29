#------------------------------------------------------------------------------#
#                         @ISOSCOPE 2008                                       #
#------------------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                          #
#               Adresse : TERSUD - Bat A                                       #
#                         5, AVENUE MARCEL DASSAULT                            #
#                         31500  TOULOUSE                                      #
#               SIRET   : 410 630 164 00037                                    #
#------------------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                                #
# l'Institut National de la Propriete Industrielle (lettre Soleau)             #
#------------------------------------------------------------------------------#

# Composant: Plugin

package CountVbUtils;
use strict;
use warnings;


# compte le nombre d'expressions regulieres
# en etant insensitif a la casse.
sub count_re_i_1($$)
{
    my ($sca, $re) = @_ ;
    my $n = 0;
    while ( $sca =~ m/$re/smgi )
    {
        $n ++;
    }
    return $n;
}

sub count_re_i($$)
{
    my ($sca, $re) = @_ ;
    my $n ;
    $n = () = $sca =~ /$re/smgi ;
    return $n;
}

sub count_re($$)
{
    my ($sca, $re) = @_ ;
    my $n ;
    $n = () = $sca =~ /$re/smg ;
    return $n;
}

# $callback_level sur une expression ou ont etet subisttues les niveaux inferieurs de parentheses
# $callback_part sur chaque bouts situÃ©s entre tokens de parentheses.
sub analyse_parentheses ($$$;$$); # prototype car fonction recursive
sub analyse_parentheses ($$$;$$)
{
  my ( $buf , $profondeur, $vue, $callback_level, $callback_part) = @_ ;

  my $reste = $buf ;
  my $buffer = '';

  while ( $reste =~ /([^)(]*)([)(]?)(.*)/smg ) 
  {
    my $expr_part = $1;
    my $parent = $2;
    $reste = $3;

    #analyse_expr_part($profondeur, $expr_part,  $vue);
    if (defined $callback_part )
    {
      $callback_part->( $profondeur, $expr_part, $vue);
    }

    if ($parent eq '(') 
    {
  Erreurs::LogInternalTraces('debug', undef, undef, 'analyse_parentheses', '<'.$expr_part.'>', 'avant');
      $reste = analyse_parentheses( $reste, $profondeur + 1, $vue, $callback_level, $callback_part);
  Erreurs::LogInternalTraces('debug', undef, undef, 'analyse_parentheses', '<'.$expr_part.'>', 'apres');
      $buffer .= $expr_part ;
      $buffer .= '()' ;
  #Erreurs::LogInternalTraces('debug', undef, undef, 'expr_part->open->reste', '<'.$reste.'>', $profondeur);
    }
    elsif ($parent eq ')') 
    {
  #Erreurs::LogInternalTraces('debug', undef, undef, 'expr_part->close->reste', '<'.$reste.'>', $profondeur);
      $buffer .= $expr_part ;
      if (defined $callback_level )
      {
  Erreurs::LogInternalTraces('debug', undef, undef, 'analyse_parentheses', '<'.$buffer.'>', 'cb1');
        $callback_level->( $profondeur, $buffer, $vue);
      }
      return $reste;
    }
    else
    {
      $buffer .= $expr_part ;
      if (defined $callback_level )
      {
  Erreurs::LogInternalTraces('debug', undef, undef, 'analyse_parentheses', '<'.$buffer.'>', 'cb2');
        $callback_level->( $profondeur, $buffer, $vue);
      }
      return '' ;
    }
  }
  if (defined $callback_level )
  {
  Erreurs::LogInternalTraces('debug', undef, undef, 'analyse_parentheses', '<'.$buffer.'>', 'cb3');
    $callback_level->( $profondeur, $buffer, $vue);
  }
  return '';
}

1;
