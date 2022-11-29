package CS::CountException;

use strict;
use warnings;

use Erreurs;
use Lib::NodeUtil;
use CS::CSNode;
use CS::CSConfig;

my $EmptyCatches_mnemo = Ident::Alias_EmptyCatches();
my $OnlyRethrowingCatches_mnemo = Ident::Alias_OnlyRethrowingCatches();
my $ThrowInFinally_mnemo = Ident::Alias_ThrowInFinally();
my $ThrowInDestructor_mnemo = Ident::Alias_ThrowInDestructor();



my $nb_EmptyCatches = 0;
my $nb_OnlyRethrowingCatches = 0;
my $nb_ThrowInFinally = 0;
my $nb_ThrowInDestructor = 0;

sub CountCatch($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
	my $status = 0;
	
	$nb_EmptyCatches = 0;
	$nb_OnlyRethrowingCatches = 0;
		
	my $KindsLists = $views->{'KindsLists'};

	if ( ! defined $KindsLists ) {
		$status |= Couples::counter_add($compteurs, $EmptyCatches_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $OnlyRethrowingCatches_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
	
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $catches = $KindsLists->{&CatchKind};
	
	for my $catch (@$catches) {
		
		my $line = GetLine($catch);
		
		if (scalar @{GetChildren($catch)} == 0) {
			$nb_EmptyCatches++;
			Erreurs::VIOLATION($EmptyCatches_mnemo, "empty catch at line $line");
		}
		elsif (scalar @{GetChildren($catch)} == 1) {
			# get parameter exception
			my $paramCatch = GetStatement($catch);
			my $exception = "";
			if ($$paramCatch =~ /\w+\s+(\w+)/) {
				$exception = $1;
			}
			
			# get the lonely instruction
			my $instr = GetChildren($catch)->[0];
			if (IsKind($instr, ThrowKind)) {
				my $paramThrow = GetStatement($instr);
				# throw;    or   throw $exception ...
				if ($$paramThrow =~ /\A\s*(((?:$exception))?)\s*\z/) {
					#if ($1 ne "") {
#print STDERR "Id_XXX : Exceptions $1 should not be explicitly rethrown at line ".GetLine($instr)."\n";
					#}
					$nb_OnlyRethrowingCatches++;
					Erreurs::VIOLATION($OnlyRethrowingCatches_mnemo, "catch is only rethrowing exception at line ".GetLine($instr));
				}
			}
		}
		
	}

	$status |= Couples::counter_add($compteurs, $EmptyCatches_mnemo, $nb_EmptyCatches);
	$status |= Couples::counter_add($compteurs, $OnlyRethrowingCatches_mnemo, $nb_OnlyRethrowingCatches);
	
	
	return $status;
} 

sub CountThrowInFinalizers($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
	my $status = 0;
	
	$nb_ThrowInFinally = 0;
	$nb_ThrowInDestructor = 0;
		
	my $KindsLists = $views->{'KindsLists'};

	if ( ! defined $KindsLists ) {
		$status |= Couples::counter_add($compteurs, $ThrowInFinally_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $ThrowInDestructor_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
	
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $Finallys = $KindsLists->{&FinallyKind};
	my $Destructors = $KindsLists->{&DestructorKind};
	my @Finalyzers = (@$Finallys, @$Destructors);
	
	for my $finalyzer (@Finalyzers) {
		
		my $line = GetLine($finalyzer);
		
		my @throws = Lib::NodeUtil::GetNodesByKind($finalyzer, ThrowKind);
		
		if (scalar @throws) {
			if (IsKind($finalyzer, FinallyKind)) {
				$nb_ThrowInFinally++;
				Erreurs::VIOLATION($ThrowInFinally_mnemo, "Finally throws exception at line $line");
			}
			else {
				$nb_ThrowInDestructor++;
				Erreurs::VIOLATION($ThrowInDestructor_mnemo, "Destructor throws exception at line $line");
			}
		}
		
	}

	$status |= Couples::counter_add($compteurs, $ThrowInFinally_mnemo, $nb_ThrowInFinally);
	$status |= Couples::counter_add($compteurs, $ThrowInDestructor_mnemo, $nb_ThrowInDestructor);
	
	
	return $status;
}

1;
