
package PlSql::CountSignType ;
# Module de comptage 
# pour le comptage P51, correspondant au mot cle SignType

use strict;
use warnings;

use Erreurs;

sub CountSignType($$$);

# point d'entree du module CountSignType
sub CountSignType($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  my $mnemo = Ident::Alias_SignType();

  my $NomVueCode = 'plsql' ; #FIXME, en attendant une etude sur le nom des vues a produire par le Strip.

  if ( ! defined $vue->{$NomVueCode} ) {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  # Astuce pour se parer de l'absence d'harmonie de casse dans les vues.
  my $buffer = lc (  $vue->{$NomVueCode} ) ;

  my $nb = () = $buffer  =~ /\bsigntype\b/sg ;
  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}


1;

