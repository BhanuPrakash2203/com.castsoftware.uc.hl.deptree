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

package CountComplexUsesOfIncrDecrOperator;

# les modules importes
use strict;
use warnings;
use Erreurs;
use TraceDetect;

# prototypes publics
sub CountComplexUsesOfIncrDecrOperator($$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des utilisations des operateurs '++' et '--' dans des instructions complexes
#
# LANGAGES: C, CPP
#-------------------------------------------------------------------------------
sub CountComplexUsesOfIncrDecrOperator ($$$$) {

  my ($fichier, $vue, $compteurs, $options) = @_ ;
  my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
  my $trace_detect = '' if ($b_TraceDetect);                         # traces_filter_line
  my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
  $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
  my $status = 0;

  my $mnemo_IncrDecrOperatorComplexUses = Ident::Alias_IncrDecrOperatorComplexUses();

  my $code = $vue->{'code'};

  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, $mnemo_IncrDecrOperatorComplexUses, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  # remplacement des '++' par des '--' pour simplifer les expressions regulieres
  $code =~ s/\+\+/--/g ;

  # Suppression des directives de compilation, sinon probleme avec '# ... \n i--;'
  $code =~ s/(#\s*)(if|ifdef|ifndef|else|elif|elifdef|elifndef|endif)[^\n]*/ /sg ;

  # suppression des 'operator' '--'
  $code =~ s/\b(operator\s*)--/$1decrement/g ;

  # remplacement des '::' par '->' pour eviter la confusion avec le ':' du case ou etiquette
  $code =~ s/::/->/g ;

  # Suppression de la partie incrementation du 'for'
  $code =~ s/ \b ( for \s* \( (?: [^;]* ; )? (?: [^;]* ; )? ) [^;]* \)/$1 decrement\)/sxg ;

  my $assign    = qr/ [\+\-\*\/]? = /sxo ;                              #  [+-*\/] = ]
  my $avant     = qr/ (?: \G | ; | \: | \{ | \} | \) | $assign ) /sxo ; # [ ; | : | { | } | ) | [+-*\/] = ]q
  my $apres     = qr/ (?: ; | $assign \s* ) /sxo ;                      # [ ; | [+-*\/] = ... ]
  my $index     = qr/ (?: \w+ \s* (?: -> | \. | \: ) \s* )* \w+ /sxo ;  # [ a-> ]* i
  my $tab       = $index ;                                              # juste pour la comprehension
  my $indexFige = qr/ (?: $index | \d+ ) /sxo;                          # [ a-> ]* i | 10

  # Suppression des [ debuts d' | fins d' ] instructions simples '[a->]*i--'
  # exemple: a.i -- ;
  $code =~ s/ ( $avant \s* )
              $index \s*
              -- ( \s*
              $apres )
            /$1decrement$2/sxg ;

  # Suppression des [ debuts d' | fins d' ] instructions simples '--[a->]+i;'
  # exemple: -- a->i ;
  $code =~ s/ ( $avant \s* )
              -- \s*
              $index ( \s*
              $apres )
            /$1decrement$2/sxg ;

  # Suppression des [ debuts d' | fins d' ] instructions simples '( * [a->]*i ) --'
  # exemple: ( * a.i ) -- ;
  $code =~ s/ ( $avant \s* )
              \( \s*
                 \* \s*
                 $index \s*
              \) \s*
              -- ( \s*
              $apres )
            /$1decrement$2/sxg ;

  # Suppression des [ debuts d' | fins d' ] instructions simples '* ( [a->]*i -- )'
  # exemple: ( * a.i ) -- ;
  $code =~ s/ ( $avant \s* )
              \* \s*
              \( \s*
                 $index \s*
                 -- \s*
              \) ( \s*
              $apres )
            /$1decrement$2/sxg ;

  # Suppression les [ debuts d' | fins d' ] instructions simples '[a->]*tab [ [a->]*i | 10 ] --'
  # exemple: a->tab [i] -- ;
  # exemple: a->tab [2] -- ;
  # exemple: a->tab [i] -- += ...
  $code =~ s/ ( $avant \s* )
              $tab \s*
              \[ \s*
                 $indexFige \s*
              \] \s*
              -- ( \s*
              $apres )
            /$1tab_decrement$2/sxg ;

  # Suppression les [ debuts d' | fins d' ] instructions simples '-- [a->]*tab [ [a->]*i | 10 ]'
  # exemple: -- a->tab [i] ;
  # exemple: -- a->tab [i] += ...
  $code =~ s/ ( $avant \s* )
              -- \s*
              $tab \s*
              \[ \s*
                 $indexFige \s*
              \] ( \s*
              $apres )
            /$1tab_decrement$2/sxg ;

  # Suppression les [ debuts d' | fins d' ] instructions simples '[a->]*tab [ [a->]*i -- ]'
  # exemple: a->tab [i--] ;
  # exemple: a->tab [i--] += ...
  $code =~ s/ ( $avant \s* )
              $tab \s*
              \[ \s*
                 $index \s*
                 -- \s*
              \] ( \s*
              $apres )
            /$1tab_decrement$2/sxg ;

  # Suppression les [ debuts d' | fins d' ] instructions simples '[a->]*tab [ -- [a->]*i ]'
  # exemple: a->tab [--i] ;
  # exemple: a->tab [--i] += ...
  $code =~ s/ ( $avant \s* )
              $tab \s*
              \[ \s*
                 -- \s*
                 $index \s*
              \] ( \s*
              $apres )
            /$1tab_decrement$2/sxg ;

  $trace_detect .= "$base_filename:1:\n--- code source ---\n$code\n--- fin code source ---\n" if ($b_TraceDetect); # traces_filter_line

  my $nbr_IncrDecrOperatorComplexUses = () = $code =~ m/--/sg ;

  while ($code =~ m/^(?:[\ \t]*)(.*--.*)(?:[\ \t]*)$/mg ) {                                                                  # traces_filter_line
    my $line_number = TraceDetect::CalcLineMatch($code, pos($code)) if ($b_TraceDetect);                                        # traces_filter_line
    Erreurs::LogInternalTraces('TRACE', $fichier, $line_number, $mnemo_IncrDecrOperatorComplexUses, "pattern trouve: $1"); # traces_filter_line
    $trace_detect .= "$base_filename:$line_number:$1\n" if ($b_TraceDetect);                                                 # traces_filter_line
  }                                                                                                                          # traces_filter_line

  TraceDetect::DumpTraceDetect($fichier, $mnemo_IncrDecrOperatorComplexUses, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
  $status |= Couples::counter_add($compteurs, $mnemo_IncrDecrOperatorComplexUses, $nbr_IncrDecrOperatorComplexUses);

  return $status;
}


1;
