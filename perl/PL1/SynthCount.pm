package PL1::SynthCount;

use strict;
use warnings;
use Erreurs;

sub CountVG($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;
  my $status = 0;

  my @IdentList = (
	  #If
	  Ident::Alias_If(),

	  # Case / default
          Ident::Alias_Case(),
          Ident::Alias_Default(),

	  # Boucles
	  Ident::Alias_Loop(),

	  Ident::Alias_FunctionMethodImplementations(),
  );

    my $nb_VG = 0;
    my $VG__mnemo = Ident::Alias_VG();

    for my $ident (@IdentList) {
      if ( ! defined $compteurs->{$ident}) {
        $nb_VG = Erreurs::COMPTEUR_ERREUR_VALUE;
        print "Counter not available for VG synthesis : $ident\n";
	last;
      }
      else {
        $nb_VG += $compteurs->{$ident}
      }
    }

    $status |= Couples::counter_add($compteurs, $VG__mnemo, $nb_VG);

  return $status;
}




1;

