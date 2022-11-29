package Clojure::CountLoop;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Clojure::ClojureNode;
use Clojure::Config;

my $While__mnemo = Ident::Alias_While();
my $Loop__mnemo = Ident::Alias_Loop();

my $nb_While = 0;
my $nb_Loop = 0;


sub CountWhile($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_While = 0;

	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $While__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $whiles = $KindsLists->{&WhileKind};
	
	for my $while (@$whiles) {
		$nb_While++;
	}
	
	Erreurs::VIOLATION($While__mnemo, "[METRIC] number of 'while' is $nb_While");
	
	$ret |= Couples::counter_update($compteurs, $While__mnemo, $nb_While );
	
    return $ret;
}

sub CountLoop($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_Loop = 0;

	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $Loop__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $loops = $KindsLists->{&LoopKind};
	
	for my $loop (@$loops) {
		$nb_Loop++;
	}
	
	Erreurs::VIOLATION($Loop__mnemo, "[METRIC] number of 'loop' is $nb_Loop");
	
	$ret |= Couples::counter_update($compteurs, $Loop__mnemo, $nb_Loop );
	
    return $ret;
}

1;
