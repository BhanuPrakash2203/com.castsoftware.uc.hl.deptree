package CS::CountVariable;

use strict;
use warnings;

use Erreurs;
use Lib::NodeUtil;
use CS::CSNode;
use CS::CSConfig;

my $Break_mnemo = Ident::Alias_Break();

my $nb_Break = 0;

sub CountVariables($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
	my $status = 0;
	
	$nb_Break = 0;
		
	my $KindsLists = $views->{'KindsLists'};

	if ( ! defined $KindsLists ) {
		$status |= Couples::counter_add($compteurs, $Break_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
	
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $whiles = $KindsLists->{&VariableKind};
	
	my @loops = ( @$whiles, @$Fors, @$Foreachs );
	
	

	$status |= Couples::counter_add($compteurs, $Break_mnemo, $nb_Break);
	
	return $status;
} 

1;
