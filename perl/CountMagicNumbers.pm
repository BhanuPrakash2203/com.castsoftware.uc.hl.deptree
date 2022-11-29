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

package CountMagicNumbers;
# les modules importes
use strict;
use warnings;
use Erreurs;

# prototypes publics
sub CountMagicNumbers($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des Magic Number. 
#-------------------------------------------------------------------------------
sub CountMagicNumbers($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $mnemo_MagicNumbers = Ident::Alias_MagicNumbers();
#  my $code = $vue->{'code'};
  my $code = ${Vues::getView($vue, 'code')};
  my $status = 0;

  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, $mnemo_MagicNumbers, Erreurs::COMPTEUR_ERREUR_VALUE);
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  # Suppression des #define <id> <value>.
  $code =~ s/#\s*define\s+\w+\s+\d+//sg;

  # Suppression des declarations 'const' ou 'final' (en java, c et c++)
  $code =~ s/[\n;][ \t]*\b(const|final)\b[^=\{]*=[^;]*//sg;

  # Suppression des magic numbers toleres.
  $code =~ s/(\G|[^\w])[01]?\.0?([^\w])/$1---$2/sg; # 0.0, 1.0, 0. 1. .0

  my $nbr_MagicNumbers = 0;

  # reconnaissance des magic numbers :
  # 1) identifiants commencant forcement par un chiffre decimal.
  # 2) peut contenir des '.' (flottants)
  # 3) peut contenir des 'E' ou 'e' suivis eventuellement de '+/-' pour les flottants
  while ( $code =~ /[^\w]((\d|\.\d)([Ee][+-]?\d|[\w\.])*)/sg )
  {
    my $number = $1 ;
    my $match = $1 ; # traces_filter_line

    # suppression du 0 si le nombre commence par 0.
    $number =~ s/^0*(.)/$1/;
    # Si la donnee trouvee n'est pas un simple chiffre, alors ce n'est pas un magic number tolere ...
    if ($number !~ /^\d$/ ) {
      Erreurs::LogInternalTraces('DEBUG2', $fichier, 1, $mnemo_MagicNumbers, $match);
      $nbr_MagicNumbers++;
    }
  };

  $status |= Couples::counter_add($compteurs, $mnemo_MagicNumbers, $nbr_MagicNumbers);

  return $status;

}


1;

