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

package CountTernaryOp;
# les modules importes
use strict;
use warnings;
use Erreurs;

# prototypes publics
sub CountTernaryOp($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des operateurs ternaires ( ? : )
#-------------------------------------------------------------------------------

sub CountTernaryOp($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $mnemo_TernaryOperators = Ident::Alias_TernaryOperators();
  my $nbr_TernaryOperators = 0 ;
  my $status = 0;
  
#  my $mnemo_compatibilite_TernaryOp = Ident::Alias_TernaryOperators() ; # compatibilite pour module calcul #bt_filter_line  # Obsolete

  my $code = ${Vues::getView($vue, 'code')};

  if (!defined $code) {
    # Traitement si la vue n'est pas disponible (undef).
    # RQ : si la vue est vide (fichier vide !), alors on ne passe pas ici ...
    $status |= Couples::counter_add($compteurs, $mnemo_TernaryOperators, Erreurs::COMPTEUR_ERREUR_VALUE );
#    $status |= Couples::counter_add($compteurs, $mnemo_compatibilite_TernaryOp, Erreurs::COMPTEUR_ERREUR_VALUE ); # compatibilite pour module calcul #bt_filter_line  # Obsolete
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  if (! Erreurs::isDumpViolationRequired($mnemo_TernaryOperators)) {
	# Suppression des types parametres : <?>
	$code =~ s/<\s*\?\s*>//g;

	# Simplification pour des raisons de performance
	$nbr_TernaryOperators = () = $code =~ /\?/g ;
  }
  else {
	my $line =1;
	while ($code =~ /(\n)|<\s*\?|(\?)/g) {
		if (defined $1) { $line++;}
		if (defined $2) {
			Erreurs::VIOLATION($mnemo_TernaryOperators, "Ternary operator", undef, $line);
		}
	}
  }

  $status |= Couples::counter_add($compteurs, $mnemo_TernaryOperators, $nbr_TernaryOperators);
#  $status |= Couples::counter_add($compteurs, $mnemo_compatibilite_TernaryOp, $nbr_TernaryOperators); # compatibilite pour module calcul #bt_filter_line  # Obsolete

  return $status;
}


1;
