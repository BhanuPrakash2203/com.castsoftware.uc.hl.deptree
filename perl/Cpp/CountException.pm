
package Cpp::CountException;

use strict;
use warnings;

use Erreurs;
use Cpp::ParserIdents;
use Lib::Node;
use Lib::NodeUtil;
use Cpp::CppNode;

my $DEBUG = 0;

my $mnemo_IllegalThrows = Ident::Alias_IllegalThrows();
my $mnemo_NonTerminalCatchAll = Ident::Alias_NonTerminalCatchAll();

my $nb_IllegalThrows = 0;
my $nb_NonTerminalCatchAll = 0;

# HL-760 31/01/2019 C++ DIAG : Avoid throwing NULL
# HL-762 05/02/2019 C++ DIAG : Avoid non terminal catch-all 
sub CountException($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_IllegalThrows = 0;
    $nb_NonTerminalCatchAll = 0;

    my $KindsLists = $vue->{'KindsLists'}||[];
    
  	if ( ! defined $KindsLists )
	{
		$status |= Couples::counter_add($compteurs, $mnemo_IllegalThrows, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_NonTerminalCatchAll, Erreurs::COMPTEUR_ERREUR_VALUE );
    } 
 
    my $ThrowNodes = $KindsLists->{&ThrowKind};
    my $TryNodes = $KindsLists->{&TryKind};
    
	for my $Throw (@$ThrowNodes) 
    {    
        my $statement = ${GetStatement($Throw)};
        
        if ($statement =~ /^\s*\(?\s*(?:\bNULL\b|0+)\s*\)?\s*$/m)
        {
            Erreurs::VIOLATION($mnemo_IllegalThrows, "Throwing null value at line ".GetLine($Throw));
            print "Throwing null value at line ".GetLine($Throw)."\n" if ($DEBUG);
            $nb_IllegalThrows++;
        }
    }
    
    for my $Try (@$TryNodes) 
    {    
        my $children = GetChildren ($Try);
        my $count_child = 0;
        for my $child (@$children)
        {
            if ( GetKind ($child) eq CatchKind and $count_child != scalar @$children -1)
            {
                my ($condNode) = @{GetChildren($child)};
                
                if ( GetKind ($condNode) eq ConditionKind )
                {
                    my $statement = ${GetStatement($condNode)};

                    # ellipsis
                    if ($statement =~ /^\s*\(\s*\.\.\.\s*\)\s*$/m)
                    {
                        Erreurs::VIOLATION($mnemo_NonTerminalCatchAll, "Non terminal catch-all at line ".GetLine($condNode));
                        print "Non terminal catch-all at line ".GetLine($condNode)."\n" if ($DEBUG);
                        $nb_NonTerminalCatchAll++;
                    }
                }
            }
            $count_child++;
        }
    }
    
    $status |= Couples::counter_add ($compteurs, $mnemo_IllegalThrows, $nb_IllegalThrows);
    $status |= Couples::counter_add ($compteurs, $mnemo_NonTerminalCatchAll, $nb_NonTerminalCatchAll);
    return $status;
}

1;
