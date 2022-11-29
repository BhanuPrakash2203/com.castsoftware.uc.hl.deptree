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


package CountIfPrepro;

use strict;
use warnings;
use Erreurs;

# Prototypes publiques
sub CountIfPrepro($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des directives de compilations #if, #ifdef,
# #ifndef, #elsif, #elif, #elifdef, #elifndef
#-------------------------------------------------------------------------------

sub CountIfPrepro($$$) {

  my ($fichier, $vue, $compteurs) = @_ ;

  my $mnemo_IfPrepro = Ident::Alias_IfPrepro();
  my $status = 0;

  my $code = $vue->{'prepro_directives'};

  if ( ! defined $code ) {
    # FIXME: temporaire pour le C#
    $code = $vue->{'text'};
  }

  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, $mnemo_IfPrepro, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nbr_IfPrepro = () = $code =~ /#\s*(if|ifdef|ifndef|elsif|elif|elifdef|elifndef)\b/sg ;

  # Decompte de la protection du fichier si il y en a une.
  if ($vue->{'code_with_prepro'} =~ m{
                \A\s*
                \#\s*ifndef\s+(\w+)   #1
                \s*
                \#\s*define\s+(\w+)   #2
              }xms)
  {
    if ($nbr_IfPrepro > 0) {
      if ($1 eq $2) {
        $nbr_IfPrepro--;
      }
    }
  }

  $status |= Couples::counter_add($compteurs, $mnemo_IfPrepro, $nbr_IfPrepro);

  return $status;
}


1;
