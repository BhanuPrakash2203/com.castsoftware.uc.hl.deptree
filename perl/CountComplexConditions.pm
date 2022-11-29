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

package CountComplexConditions;
# les modules importes
use strict;
use warnings;
use Erreurs;

# prototypes publics
sub CountComplexConditions($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des conditions complexes
#-------------------------------------------------------------------------------

sub CountComplexConditions($$$) {

  my ($fichier, $vue, $compteurs) = @_ ;

  my $mnemo_ComplexConditions = Ident::Alias_ComplexConditions();
  my $seuil = 4;
  my $nbr_ComplexConditions = 0;
  my $status = 0;
  my $fatalerror = 0;

  # If exists get 'prepro' view, else work with 'code', unless another view
  # is forced by parameter stored in the $vue Hash table.
  my $code = ${Vues::getView($vue, 'prepro', 'code')};

#  my $code = '';
#
#  if ( (exists $vue->{'prepro'}) && ( defined $vue->{'prepro'} ) ) {
#    $code = $vue->{'prepro'};
#    Erreurs::LogInternalTraces('DEBUG', $fichier, 1, $mnemo_ComplexConditions, "utilisation de la vue prepro.\n");
#  }
#  else {
#    $code = $vue->{'code'};
#  }


  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, $mnemo_ComplexConditions, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  # Neutralisation des mots cles de directive de compilation, en les faisant preceder de '_'
  $code =~ s/(#\s*)(if|ifdef|ifndef|else|elif|elifdef|elifndef|endif)/$1_$2/sg;

  # Suppression des 1ere et 3eme clauses d'un "for" pour le rendre syntaxiquement identique a un "if" ou un "while".

  #   a) Suppression de la premiere clause
  $code =~ s/\b(for\b\s*\()[^;]*;/$1/sg ;

  #   b) Applatissement des eventuelles imbrications de parentheses de la 3ieme clause.
  while ($code =~ s/\b(for\b\s*\([^;]*;)[^\(\)]*\([^\(\)]*\)/$1/sg) {};

  #   c) Suppression de la troisieme clause.
  $code =~ s/\b(for\b\s*\([^;]*);[^\)]*/$1/sg ;
  my $x001 = pack("U0C*", 0x01);             # U+0001 <control>

  $code =~ s/\b((if|while|for)\b\s*\()/$x001$1/sg ;
  $code .= chr(1);

  while ( $code =~ /\b((if|while|for)\b\s*\(([^\x01]*))$x001/sg ) {

    my $buf = $1;

    # Suppression de toutes les parentheses internes au niveau de la premiere structure d'imbrication de parentheses rencontree,
    # c'est a dire les parentheses qui renferment la condition de la structure 'if', 'for' ou 'while'.
    while ($buf =~ /\A[^\(]*\([^\(\)]*\(([^\)]*\))?/s ) {
      if ( defined $1 ) {
        $buf =~ s/\(([^\(\)]*)\)/$1/s ;
      }
      else {
	Erreurs::LogInternalTraces('ERROR', $fichier, 1, $mnemo_ComplexConditions, "Erreur d'appariement des parentheses dans $fichier.\n"); # Erreurs::LogInternalTraces
        $fatalerror = 1;
        last;
      }
    }

    if ( $fatalerror == 1 ) {
      $status |= Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'comptage!!!!', ''); # traces_filter_line
      $nbr_ComplexConditions = -1;
      last;
    }
    # capture de la condition debarrassee des sous-niveaux de parenthese
    my ($cond) = $buf =~ /\(([^\)]*)\)/ ;

    if (defined $cond) {

      # Calcul du nombre de && et de ||
      my $nb_ET = () = $cond =~ /\&\&/sg ;
      my $nb_OU = () = $cond =~ /\|\|/sg ;

      if ( ($nb_ET > 0) && ($nb_OU > 0) ) {
        if ( $nb_ET + $nb_OU >= $seuil) {
          Erreurs::LogInternalTraces('TRACE', $fichier, 1, $mnemo_ComplexConditions, $cond); # Erreurs::LogInternalTraces
          $nbr_ComplexConditions++;
        }
      }
    }
  }

  $status |= Couples::counter_add($compteurs, $mnemo_ComplexConditions, $nbr_ComplexConditions);

  return $status;
}


1;
