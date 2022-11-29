package Kotlin::CountClasses;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Kotlin::KotlinNode;

my $BadClassNames__mnemo = Ident::Alias_BadClassNames();

my $nb_BadClassNames = 0;

sub CountClasses($$$) 
{
	my ($file, $views, $compteurs) = @_ ;
    
	my $ret = 0;
	$nb_BadClassNames = 0;
	
    my $KindsLists = $views->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $BadClassNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	$ret |= Couples::counter_update($compteurs, $BadClassNames__mnemo, 0 );
  
	my $Classes = $KindsLists->{&ClassKind};

	for my $class (@$Classes) {
		$ret |= Kotlin::CountNaming::checkClassNaming($class, $compteurs);
	}
    
    return $ret;
}

1;


