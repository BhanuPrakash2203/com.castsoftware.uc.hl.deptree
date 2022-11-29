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

package CountComplexOperands;

use strict;
use warnings;
use Erreurs;

# prototypes publics
sub CountComplexOperands ($$$$);

# prototypes prives
sub CountComplexDeref($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Fonction de comptage des dereferencements trop complexes dans les operandes.
#-------------------------------------------------------------------------------

my $ComplexitySeuil = 4;

sub CountComplexOperands ($$$$) {

  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $mnemo_ComplexOperands = Ident::Alias_ComplexOperands();
  my $status = 0;

  #my $code = $vue->{'code'} ;
  
  # The buffer is dupplicated because the algorithm modifies it in the function 
  # CountComplexDeref().
  my $code = ${Vues::getView($vue, 'code')};

  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, $mnemo_ComplexOperands, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nb_ComplexOperands = 0;

  $nb_ComplexOperands += CountComplexDeref (\$code, \$fichier, \$options);

  $status |= Couples::counter_add($compteurs, $mnemo_ComplexOperands, $nb_ComplexOperands);

  return $status;
}

#--------------------------------------------------------------------------------
# ALGO : on splitte le code selon les operateurs d'indirection '.', '->' et '['.
# Chaque token consécutif qui ne comporte que des caracteres ':alphanum:blanc:() ou ]'
# constitue un nouveau niveau d'indirection puisqu'il est forcement separe du precedent
# par un operateur d'indirection (compte tenu du split sur ces operateurs)
# La chaine d'indirection est rompue lorsqu'un token comporte un autre caractere que ceux listes
# plus haut. Ce token marque donc le dernier niveau d'indirection.
#--------------------------------------------------------------------------------

sub CountComplexDeref($$$) {

  my ($expr, $fichier, $options) = @_ ;

  my $mnemo_ComplexOperands = Ident::Alias_ComplexOperands();
  my $b_TraceDetect = ((exists $$options->{'--TraceDetect'})? 1 : 0); # Erreurs::LogInternalTraces
  my $trace_detect = '' if ($b_TraceDetect); # Erreurs::LogInternalTraces
  my $base_filename = $$fichier if ($b_TraceDetect); # Erreurs::LogInternalTraces
  $base_filename =~ s{.*/}{} if ($b_TraceDetect); # Erreurs::LogInternalTraces
  my $line_number = 1 if ($b_TraceDetect); # Erreurs::LogInternalTraces

  # Neutralisation des nombres decimaux :
  $$expr =~ s/\d+\.\d+/0/sg ;

  my @tokens = split(/\.|->|\[/, $$expr);

  my $lDeref = 0;
  my $nb_Deref = 0;

  if (scalar (@tokens) > $ComplexitySeuil ) {

    foreach my $token ( @tokens ) {

      my $match = $token; # Erreurs::LogInternalTraces
      # Si le token contient des caracteres autres que ceux autorises dans une expression de dereferencement, alors il s'agit
      # d'un debut de dereferencement (a comptabiliser), ou d'une fin de dereferencement (a ne pas comptabiliser).

      # neutralisation des operateur '*' de dereferencement
      #----------------------------------------------------
      # 1) neutralisation des '*' colles derriere un operateur d'indirection : . -> ou [. Ces operateur etant utilises pour splittes,
      #    les '*' en questions sont forcement en debut de token.
      $token =~ s/^\s*\*/ /;

      # 2) neutralisation des '*' suivant une '(', qui sont forcement des dereferencements.
      $token =~ s/\(\s*\*/\(/sg;

      # 3) neutralisation des '*' precedent une ')', qui sont forcement des dereferencements.
      $token =~ s/\*\s*\)/\)/sg;

      # 4) Les '*' qui restent sont des operateurs de calcul, ou bien des dereferencements colles a des operateurs de calcul.
      #    Dans tous ces cas, cela marque la fin d'une chaine d'indirections.

      if ( $token =~ /[^\w\]\s\(\)]/s ) {
        if ( $lDeref > 0) {
          # Dernier element d'un dereferencement.
          $lDeref++;
          if ( $lDeref > $ComplexitySeuil) {
            $nb_Deref++;
	    $trace_detect .= "$base_filename:$line_number:---$match---\n" if ($b_TraceDetect); # Erreurs::LogInternalTraces
          }
          $lDeref = 0;
        }
      }
      else {
        $lDeref++;
      }
    }
  }


  TraceDetect::DumpTraceDetect($$fichier, $mnemo_ComplexOperands, $trace_detect, $$options) if ($b_TraceDetect); # Erreurs::LogInternalTraces

  return $nb_Deref;
}


1;
