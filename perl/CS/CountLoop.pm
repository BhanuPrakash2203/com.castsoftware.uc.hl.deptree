package CS::CountLoop;

use strict;
use warnings;

use Erreurs;
use Lib::NodeUtil;
use CS::CSNode;
use CS::CSConfig;

my $Break_mnemo = Ident::Alias_Break();

my $nb_Break = 0;

sub CountLoop($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
	my $status = 0;
	
	$nb_Break = 0;
		
	my $KindsLists = $views->{'KindsLists'};

	if ( ! defined $KindsLists ) {
		$status |= Couples::counter_add($compteurs, $Break_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
	
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $whiles = $KindsLists->{&WhileKind};
	my $Fors = $KindsLists->{&ForKind};
	my $Foreachs = $KindsLists->{&ForeachKind};
	
	my @loops = ( @$whiles, @$Fors, @$Foreachs );
	
	for my $loop (@loops) {
		
		my $line = GetLine($loop);
		
		my @breaks = GetNodesByKindList_StopAtBlockingNode($loop, [BreakKind], [SwitchKind, WhileKind, ForKind, ForeachKind]);
		
		$nb_Break += scalar @breaks;
	}

	$status |= Couples::counter_add($compteurs, $Break_mnemo, $nb_Break);
	
	return $status;
} 

1;
