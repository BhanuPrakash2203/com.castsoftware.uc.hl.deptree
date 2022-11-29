
package Cpp::CountLoop;

use strict;
use warnings;

use Erreurs;
use Cpp::ParserIdents;
use Lib::NodeUtil;
use Cpp::CppNode;
use Cpp::ParseCpp;

my $DEBUG = 0;

my $mnemo_OverFlowingLoopCounter = Ident::Alias_OverFlowingLoopCounter();

my $nb_OverFlowingLoopCounter = 0;

# HL-747 18/01/2019 C++ DIAG : Avoid overflowing loop counter 
sub CountLoop
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_OverFlowingLoopCounter = 0;

    my $KindsLists = $vue->{'KindsLists'}||[];

    if ( ! defined $KindsLists )
	{
		$status |= Couples::counter_add($compteurs, $mnemo_OverFlowingLoopCounter, Erreurs::COMPTEUR_ERREUR_VALUE );
    }
    
    my $ForLoops = $KindsLists->{&ForKind};

 	for my $ForLoop (@$ForLoops) 
    {  
		my ($condNode) = @{GetChildren($ForLoop)};
        
        if ( GetKind ($condNode) eq ConditionKind )
        {          
            my $termCond = Lib::NodeUtil::GetKindData($condNode)->{'cond'};
            my $incrementCond = Lib::NodeUtil::GetKindData($condNode)->{'inc'};
            
            if ($incrementCond !~ /\+\+/ and $incrementCond !~ /\-\-/ 
                and ($termCond =~ /\=\=/ or $termCond =~ /\!\=/) )
            {
                print "+++++ Potential infinite loop risk found $incrementCond $termCond\n" if $DEBUG;
                Erreurs::VIOLATION($mnemo_OverFlowingLoopCounter, "Potential infinite loop risk found");
                $nb_OverFlowingLoopCounter++;              
            }
        }
    }   
    
    $status |= Couples::counter_add ($compteurs, $mnemo_OverFlowingLoopCounter, $nb_OverFlowingLoopCounter);
    return $status;
}

1;
