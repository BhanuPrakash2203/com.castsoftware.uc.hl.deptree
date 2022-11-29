package Groovy::CountClosures;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Groovy::GroovyNode;
use Groovy::CountMethods;

my $ParameterUpdate__mnemo = Ident::Alias_ParameterUpdate();

my $nb_ParameterUpdate = 0;


sub CountClosures($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
    
	my $ret = 0;
    $nb_ParameterUpdate = 0;

    my $KindsLists = $vue->{'KindsLists'};

    if ( ! defined $KindsLists ) {
        $ret |= Couples::counter_add($compteurs, $ParameterUpdate__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
    }

    # 25/11/2020 HL-1562 Avoid parameters reassignment
    my $closures = $KindsLists->{&ClosureKind};

    for my $closure (@{$closures}) {
        my $args = Lib::NodeUtil::GetKindData($closure)->{'arguments'};

        for my $arg (@$args) {
            # my $type = $arg->{'type'};
            my $name = $arg->{'name'};

            # parse body of the closure
            $nb_ParameterUpdate = Groovy::CountMethods::CountParamaterUpdate($vue->{'code'}, $closure, $name, $nb_ParameterUpdate);
        }
    }

    $ret |= Couples::counter_update($compteurs, $ParameterUpdate__mnemo, $nb_ParameterUpdate );
    return $ret;
}

1;