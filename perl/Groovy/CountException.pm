package Groovy::CountException;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::Node;
use Lib::NodeUtil;
use Lib::CountUtils;

use Groovy::GroovyNode;

my $OnlyRethrowingCatches__mnemo = Ident::Alias_OnlyRethrowingCatches();
my $NestedTryCatches__mnemo = Ident::Alias_NestedTryCatches();
my $EmptyCatches__mnemo = Ident::Alias_EmptyCatches();
my $OutOfFinallyJumps__mnemo = Ident::Alias_OutOfFinallyJumps();
my $RiskyCatches__mnemo = Ident::Alias_RiskyCatches();

my $nb_OnlyRethrowingCatches = 0;
my $nb_NestedTryCatches = 0;
my $nb_EmptyCatches = 0;
my $nb_OutOfFinallyJumps = 0;
my $nb_RiskyCatches = 0;

sub CountException($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
    
	my $ret = 0;
    $nb_OnlyRethrowingCatches = 0;
    $nb_EmptyCatches = 0;
    
	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $OnlyRethrowingCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $EmptyCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $catchInstr = $KindsLists->{&CatchKind};
    
	for my $catch (@$catchInstr) {
		
        my $ref_children = GetChildren($catch);
        my $NameException;
        my $line = GetLine($catch);
        
        # CHECK CATCH CONDITION
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
        
        # CHECK CATCH INSTRUCTIONS
        # $ref_children->[1] is the "THEN" node
        my $thenNode = $ref_children->[1];
        my $catchInstructions = GetChildren($thenNode);
        if (scalar @$catchInstructions == 0) {
			$nb_EmptyCatches++;
			Erreurs::VIOLATION($EmptyCatches__mnemo, "Empty catch at line $line");
		}

	}

    $ret |= Couples::counter_add($compteurs, $OnlyRethrowingCatches__mnemo, $nb_OnlyRethrowingCatches );
    $ret |= Couples::counter_add($compteurs, $EmptyCatches__mnemo, $nb_EmptyCatches );

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

		for my $tryStmt (@{GetChildren($try)}) {
			if (IsKind($tryStmt, FinallyKind)) {
#print STDERR "Finally line ".GetLine($tryStmt)."\n";

				my @jumps = GetNodesByKindList($tryStmt, [ReturnKind, ThrowKind]);
				for my $jump (@jumps) {
					$nb_OutOfFinallyJumps++;
					Erreurs::VIOLATION($OutOfFinallyJumps__mnemo, "Out of finnaly jump at line ".GetLine($jump));
				}
				
				@jumps = GetNodesByKindList_StopAtBlockingNode($tryStmt, [BreakKind, ContinueKind], [WhileKind, ForKind, SwitchKind]);
				for my $jump (@jumps) {
					$nb_OutOfFinallyJumps++;
					Erreurs::VIOLATION($OutOfFinallyJumps__mnemo, "Out of finnaly jump at line ".GetLine($jump));
				}
			} 
		}

        # futur code
        # if (isTooLong($try)) {
            # $nb_TooLongTry++
        # }
		    
    }
}

sub CountTry($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
    
	my $ret = 0;
	
    $nb_NestedTryCatches = 0;
    $nb_OutOfFinallyJumps = 0;
    
	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $OnlyRethrowingCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $OutOfFinallyJumps__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
    
    my $tryInstr = $KindsLists->{&TryKind};
    countTry($tryInstr);

    $ret |= Couples::counter_add($compteurs, $NestedTryCatches__mnemo, $nb_NestedTryCatches );
    $ret |= Couples::counter_add($compteurs, $OutOfFinallyJumps__mnemo, $nb_OutOfFinallyJumps );

    return $ret;
}


sub CountIllegalThrows($$$$) {
    my ($fichier, $vue, $couples, $options) = @_;
    my $status = 0;
    
    my $mnemo = Ident::Alias_IllegalThrows();
  
	my $reg = qr/\bthrow\s+new\s+(?:java\.lang\.)?(?:Error|Exception|Throwable|RuntimeException)\s*\(/;
  
	my $nb_IllegalThrows = Lib::CountUtils::CountGrepWithLine($reg, $mnemo, "Illegal throw", \$vue->{'code'});
    
    $status |= Couples::counter_add($couples, $mnemo ,$nb_IllegalThrows );
        
    return $status;
}

sub CountRiskyCatches($$$$) {
    my ($fichier, $vue, $couples, $options) = @_;
    my $status = 0;
 
	my $reg = qr/\bcatch\s*\((?:java\.lang\.)?(?:Error|Exception|Throwable)\b/;
  
	my $nb_RiskyCatches = Lib::CountUtils::CountGrepWithLine($reg, $RiskyCatches__mnemo, "Risky catch", \$vue->{'code'});
    
    $status |= Couples::counter_add($couples, $RiskyCatches__mnemo ,$nb_RiskyCatches );
        
    return $status;
}

1;
