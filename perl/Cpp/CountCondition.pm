
package Cpp::CountCondition;

use strict;
use warnings;

use Erreurs;
use Cpp::ParserIdents;
use Lib::NodeUtil;
use Cpp::CppNode;
use Cpp::ParseCpp;

my $DEBUG = 0;

my $mnemo_WithoutCaseSwitch = Ident::Alias_WithoutCaseSwitch();

my $nb_WithoutCaseSwitch = 0;

# HL-746 18/01/2019 C++ DIAG : Avoid switch without case statement
sub CountSwitchWithoutCaseStatement
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_WithoutCaseSwitch = 0;

    my $KindsLists = $vue->{'KindsLists'}||[];

    if ( ! defined $KindsLists )
	{
		$status |= Couples::counter_add($compteurs, $mnemo_WithoutCaseSwitch, Erreurs::COMPTEUR_ERREUR_VALUE );
    }
    
    my $Switches = $KindsLists->{&SwitchKind};

 	for my $Switch (@$Switches) 
    {  
        my $ThenStatement = GetChildren($Switch)->[1];
     	
        if (scalar GetChildrenByKind($ThenStatement, CaseKind) == 0 ) 
        {
            print "+++++ Switch definition without case statement found\n" if $DEBUG;
            Erreurs::VIOLATION($mnemo_WithoutCaseSwitch, "Switch definition without case statement found");
            $nb_WithoutCaseSwitch++;   
        }
        
    }   
    
    $status |= Couples::counter_add ($compteurs, $mnemo_WithoutCaseSwitch, $nb_WithoutCaseSwitch);
    return $status;
}

1;
