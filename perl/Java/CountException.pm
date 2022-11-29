package Java::CountException;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Java::JavaNode;

my $OnlyRethrowingCatches__mnemo = Ident::Alias_OnlyRethrowingCatches();
my $NestedTryCatches__mnemo = Ident::Alias_NestedTryCatches();

my $nb_OnlyRethrowingCatches = 0;
my $nb_NestedTryCatches = 0;

sub CountException($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
    
	my $ret = 0;
    $nb_OnlyRethrowingCatches = 0;
    $nb_NestedTryCatches = 0;
    
	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $OnlyRethrowingCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $catchInstr = $KindsLists->{&CatchKind};
    
	for my $catch (@$catchInstr) {
		
        my $ref_children = GetChildren($catch);
        my $NameException;
       
        # 21/11/2017 HL-305 avoid catches that only rethrow       
        # $ref_children->[0] is the condition node
		if (${GetStatement($ref_children->[0])} =~ /\(\s*\w+\s+(\w+)\s*\)/)
		{
			$NameException = $1;
			# print 'nom exception detecte=' . $NameException."\n";
			
			if ($NameException) {
				# $ref_children->[1] is the "then" node, that contains the instructions of the catch.
				my $firstInstruction = GetChildren($ref_children->[1])->[0];
				if (defined $firstInstruction)
				{	
					# si le premier enfant du noeud catch.cond.then 
					# est <throw $NameException> => VIOLATION
					if (GetKind($firstInstruction) eq ThrowKind
						and ${GetStatement($firstInstruction)} =~ /^\s*$NameException\s*$/m)
					{
						$nb_OnlyRethrowingCatches++;
						# print 'violation detectee=' . $NameException."\n";
						Erreurs::VIOLATION($OnlyRethrowingCatches__mnemo, "Catch clause using only rethrowing at line " .GetLine($firstInstruction));
					}
				}
			}
        }
	}
    
    # 04/12/2017 HL-331 Avoid nested try-catch blocks
    my $tryInstr = $KindsLists->{&TryKind};
    countTry ($tryInstr);

    $ret |= Couples::counter_add($compteurs, $OnlyRethrowingCatches__mnemo, $nb_OnlyRethrowingCatches );
    $ret |= Couples::counter_add($compteurs, $NestedTryCatches__mnemo, $nb_NestedTryCatches );

    return $ret;
}

sub containOtherTry($) {

    my ($nodeTry) = @_;
    my ($ref_listNodesTry) = GetNodesByKind($nodeTry,TryKind,1);  
    
    if ($ref_listNodesTry)
    {
        return 1;
    }
      
    return 0;
}

sub countTry($) {
    
    my ($tryInstr) = @_;
        
    for my $try (@{$tryInstr})
    {
        
        if ( containOtherTry($try) == 1)
        {
            # print '++++ Nested try detected into try-catch block between line ' .GetLine($try). " and ".GetEndline($try)."\n";
            $nb_NestedTryCatches++;
            Erreurs::VIOLATION($NestedTryCatches__mnemo, "Nested try detected into try-catch block between line " .GetLine($try). " and ".GetEndline($try));
        }

        # futur code
        # if (isTooLong($try)) {
            # $nb_TooLongTry++
        # }
    
    }
    
} 


1;
