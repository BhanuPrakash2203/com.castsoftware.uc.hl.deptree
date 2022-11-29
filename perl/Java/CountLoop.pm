package Java::CountLoop;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Java::JavaNode;

my $UnconditionalJump__mnemo = Ident::Alias_UnconditionalJump();
my $EqualityInLoopCondition__mnemo = Ident::Alias_EqualityInLoopCondition();
my $FunctionCallInLoopTest__mnemo = Ident::Alias_FunctionCallInLoopTest();
my $LoopCounterModification__mnemo = Ident::Alias_LoopCounterModification();


my $nb_UnconditionalJump = 0;
my $nb_EqualityInLoopCondition = 0;
my $nb_FunctionCallInLoopTest = 0;
my $nb_LoopCounterModification = 0;


sub checkLoopCounterModification($$) {
	my $condNode = shift;
	my $codeBody = shift;
	
	if ( GetKind ($condNode) eq ConditionKind )
	{          
        my $inc = Lib::NodeUtil::GetKindData($condNode)->{'inc'};
        if ($inc =~ /(\w+)\s*(?:\+|=[^=])|\+\+(\w+)/) {
			my $loopCounter = $1 || $2;
			
			# check if the loop counter is modified inside the body :
			if ($$codeBody =~ /(?:$loopCounter\s*(?:=[^=]|\+=|\+\+)|\+\+$loopCounter)/) {
				$nb_LoopCounterModification++;
				Erreurs::VIOLATION($LoopCounterModification__mnemo, "Loop counter $loopCounter is modified inside the body of the loop declared at line".GetLine($condNode));
			}
		}
	}
}

sub checkLoopBody($) {
	my $thenBody = shift;

	if ( GetKind($thenBody) eq ThenKind )
	{
#print '1++++++' . GetKind ($thenBody)."\n";
		my $ref_children_niv2 = GetChildren($thenBody);
		foreach my $child_niv2 (@{$ref_children_niv2})
		{   
			my $kind = GetKind ($child_niv2);
			if ( $kind eq ReturnKind 
				or $kind eq BreakKind 
				or $kind eq ContinueKind 
				or $kind eq ThrowKind )
			{
# print '2++++++' . GetKind ($child_niv2)."\n";
				$nb_UnconditionalJump++;
				Erreurs::VIOLATION($UnconditionalJump__mnemo, "Unconditional jump at line ".GetLine($child_niv2));
			}
		}
	}
}

sub checkLoopTermination($) {
	# 15/01/2018 HL-411 Avoid equality in loop termination condition
    my $condNode = shift;

	if ( GetKind ($condNode) eq ConditionKind )
	{          
        my $cond = Lib::NodeUtil::GetKindData($condNode)->{'cond'};

        # more than one condition
        while ( $cond =~ /(\S+)\s*[!=]=\s*(\S+)/g ) 
        {
            if ( ($1 ne "null" ) && ($2 ne "null" ))
            {
                # print '++++++++violation <' . $cond  .">\n";
                $nb_EqualityInLoopCondition++;
                Erreurs::VIOLATION($EqualityInLoopCondition__mnemo, "Equality in loop termination operator at line ".GetLine($condNode));
            }
        }
    }
}

sub checkLoopTerminationFunction($) {
	# 16/01/2018 HL-413 Avoid function call in loop stop condition
	my $condNode = shift;
	
	#my $ref_children_niv1 = GetChildren($loop);
  	if ( GetKind ($condNode) eq ConditionKind )
	{            
        my $cond = Lib::NodeUtil::GetKindData($condNode)->{'cond'};
        # print '++++++++first check <' . $cond . "> \n";
        
        # detect a function call
        while ( $cond =~ /(\w+)\s*\(/g ) 
        {
            # print '+++++second check <' . $1 . "> \n";
            $nb_FunctionCallInLoopTest++;
            Erreurs::VIOLATION($FunctionCallInLoopTest__mnemo, "Function call in loop termination at line ".GetLine($condNode));
        }
    }
}


sub CountLoop($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
    
	my $ret = 0;
    $nb_UnconditionalJump = 0;
    $nb_EqualityInLoopCondition = 0;
    $nb_FunctionCallInLoopTest = 0;
    $nb_LoopCounterModification = 0;
    
	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $UnconditionalJump__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $EqualityInLoopCondition__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $FunctionCallInLoopTest__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $LoopCounterModification__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $forLoop = $KindsLists->{&ForKind};
    # 08/01/2018 HL-405 Avoid unconditional jump statement
	for my $for (@{$forLoop}) 
    {
		my ($cond, $thenBody) = @{GetChildren($for)};
		my $codeBody = Lib::NodeUtil::GetKindData($for)->{'codeBody'};
		
        checkLoopBody($thenBody);
        checkLoopTermination($cond);  
        checkLoopTerminationFunction($cond);
        checkLoopCounterModification($cond, $codeBody); 
	}
    
    my $whileLoop = $KindsLists->{&WhileKind};
	for my $while (@{$whileLoop}) 
    {
		
		my ($cond, $thenBody) = @{GetChildren($while)};
		
		checkLoopBody($thenBody);
        checkLoopTermination($cond);  
        checkLoopTerminationFunction($cond);
	}
	
	my $EForLoop = $KindsLists->{&EForKind};
	for my $efor (@{$EForLoop}) {
		checkLoopBody($efor);
	}
    
    $ret |= Couples::counter_update($compteurs, $UnconditionalJump__mnemo, $nb_UnconditionalJump );
    $ret |= Couples::counter_add($compteurs, $EqualityInLoopCondition__mnemo, $nb_EqualityInLoopCondition );
    $ret |= Couples::counter_add($compteurs, $FunctionCallInLoopTest__mnemo, $nb_FunctionCallInLoopTest );
    $ret |= Couples::counter_add($compteurs, $LoopCounterModification__mnemo, $nb_LoopCounterModification );
    
    return $ret;
}


1;
