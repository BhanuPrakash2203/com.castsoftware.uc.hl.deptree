package Java::CountInstruction;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Java::JavaNode;

my $CaseLengthAverage__mnemo = Ident::Alias_CaseLengthAverage();
my $SmallSwitchCase__mnemo = Ident::Alias_SmallSwitchCase();
my $UnconditionalJump__mnemo = Ident::Alias_UnconditionalJump();

my $caseLenghtAverage = 0;
my $nb_caseLenghtAverage = 0;
my $nb_SmallSwitchCase = 0;
my $nb_UnconditionalJump = 0; 

sub CountInstruction($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
    
	my $ret = 0;
    $nb_caseLenghtAverage = 0;
    $nb_SmallSwitchCase = 0;
    $nb_UnconditionalJump = 0;
   
	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $CaseLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $SmallSwitchCase__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnconditionalJump__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $caseInstr = $KindsLists->{&CaseKind};
    my $countCases;
    my $TotalCaseLenght;
    
    # 18/12/2017 HL-332 Avoid long case statements    
	for my $case (@{$caseInstr}) 
    {
		    
        my $beginLineCase = GetLine ($case);
        my $endLineCase = GetEndline ($case);    
            
        my $lenghtCase = $endLineCase - $beginLineCase;
        $TotalCaseLenght+= $lenghtCase;
        $countCases++;
	}
    
    #print 'TotalCaseLenght='.$TotalCaseLenght."\n";
    #print 'countCases='.$countCases."\n";
    if ($countCases) {
		$nb_caseLenghtAverage = int($TotalCaseLenght/$countCases);
	}
	else {
		$nb_caseLenghtAverage = 0;
	}
    
    # print 'caseLenghtAverage='.$caseLenghtAverage."\n";
    Erreurs::VIOLATION($CaseLengthAverage__mnemo, "Case length average is $nb_caseLenghtAverage");
    
    # HL-404 Avoid small switch/Case
    # number of case or default instructions (CaseKind + DefaultKind)
    # if number < 3 => violation

    my $switchInstr = $KindsLists->{&SwitchKind};
    
	for my $switch (@{$switchInstr}) 
    {    
        my $ref_children_niv1 = GetChildren($switch);
		my $countCasePerSwitch = 0;
        
        foreach my $child_niv1 (@{$ref_children_niv1})
        {      
            
            # print "child=" . GetKind ($child) ."\n";
            my $ref_children_niv2 = GetChildren($child_niv1);
            
            foreach my $child_niv2 (@{$ref_children_niv2})
            {                 
                if ( GetKind ($child_niv2) eq CaseKind or GetKind ($child_niv2) eq DefaultKind )
                {
                    # print "child=" . GetKind ($child_niv2) ."\n";
                    $countCasePerSwitch++;
#print "CASE or DEFAULT\n";
                    
                    # 10/01/2018 HL-405 Avoid unconditional jump statement 
                    my $ref_children_niv2 = GetChildren($child_niv2);
                                   
                    foreach my $child_niv3 (@{$ref_children_niv2})
                    {        

                        if ( GetKind ($child_niv3) eq BreakKind )
                        {
                            # print '2++++++' . GetKind ($child)."\n";
                            my $nextSibling = Lib::Node::GetNextSibling($child_niv3);
                            
							if ($nextSibling) {
								$nb_UnconditionalJump++;
								Erreurs::VIOLATION($UnconditionalJump__mnemo, "Unconditional jump at line ".GetLine($child_niv3));
							}
                        }
                    }
                }
            }
        }
        
	    if ($countCasePerSwitch < 3) {
			$nb_SmallSwitchCase++;
			Erreurs::VIOLATION($SmallSwitchCase__mnemo, "Small switch/case at line ".GetLine($switch)."\n");
		}
    }
	
    $ret |= Couples::counter_add($compteurs, $CaseLengthAverage__mnemo, $nb_caseLenghtAverage );
    $ret |= Couples::counter_add($compteurs, $SmallSwitchCase__mnemo, $nb_SmallSwitchCase );
    $ret |= Couples::counter_update($compteurs, $UnconditionalJump__mnemo, $nb_UnconditionalJump );

    return $ret;
    
}

1;
