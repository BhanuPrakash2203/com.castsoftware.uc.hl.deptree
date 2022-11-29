package Python::CountString;

use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Python::PythonNode;
use Python::PythonConf;

my $PercentStringFormat__mnemo = Ident::Alias_PercentStringFormat();
my $AutomaticNumberingInStringsFields__mnemo = Ident::Alias_AutomaticNumberingInStringsFields();
my $ConcatInLoop__mnemo = Ident::Alias_ConcatInLoop();
my $MixedStringsStyle__mnemo = Ident::Alias_MixedStringsStyle();
my $SpacesInStringReplacementFields__mnemo = Ident::Alias_SpacesInStringReplacementFields();
my $LoopWithElseWithoutBreak__mnemo = Ident::Alias_LoopWithElseWithoutBreak();
my $String__mnemo = Ident::Alias_String();
my $Loop__mnemo = Ident::Alias_Loop();

my $nb_PercentStringFormat = 0;
my $nb_AutomaticNumberingInStringsFields = 0;
my $nb_ConcatInLoop = 0;
my $nb_MixedStringsStyle = 0;
my $nb_SpacesInStringReplacementFields = 0;
my $nb_LoopWithElseWithoutBreak = 0;
my $nb_String = 0;
my $nb_Loop = 0;


## FIXME : do not apply to the "cond" node of the loop ...
sub _cbGetAllNodesExcept($$)
{
	my ($node, $context) = @_;
	my $ref_list = $context->[0];
	my $H_exceptKinds = $context->[1];
	my $treatmentCallbacks = $context->[2];

	my $Kind = GetKind($node);

	if (! exists $H_exceptKinds->{$Kind} ) {
		for my $cb (@$treatmentCallbacks) {
			$cb->($node);
		}
	}
	else {
		return 0;
	}

	return undef;
}

sub isConcatenation($) {
	my $node = shift;
	if (${GetStatement($node)} =~ /((?:\+|\+=)\s*CHAINE_\d+\b)|(\bCHAINE_\d+\s*(?:\+|\+=))/) {
		if ((defined $1) || (defined $2)) {
			my $line = GetLine($node) || "??";
			$nb_ConcatInLoop++;
			Erreurs::VIOLATION($ConcatInLoop__mnemo, "String concatenation with operator + inside loop at line : $line");
		}
	}
	return 0;
}

sub checkLoop($$) {
	my $loop = shift;
	my $context = shift;
	my $children = Lib::NodeUtil::GetChildren($loop);
	
	my $elseNode;
	# Iterate on others childs than conds
	for my $child (@$children) {
		if (IsKind($child, ConditionKind)) {
			next;
		}
		elsif(IsKind($child, ElseKind)) {
			$elseNode = $child;
		}
		Lib::Node::Iterate ($child, 0, \&_cbGetAllNodesExcept, $context);
	}
	
	if (defined $elseNode) {
			my $thenNode = $children->[1];
			my @BreakLoop = GetNodesByKindList_StopAtBlockingNode($thenNode, [BreakKind], [WhileKind, ForKind]);
			if (scalar @BreakLoop == 0) {
				if ( ! Lib::NodeUtil::IsContainingKind($thenNode, ReturnKind)) {
					$nb_LoopWithElseWithoutBreak++;
					Erreurs::VIOLATION($LoopWithElseWithoutBreak__mnemo, "Loop with else statement whithout a break at line : ".GetLine($loop));
				}
			}
	}
}

sub CountStrings($$$) {
	my ($file, $views, $compteurs) = @_ ;
	my $ret =0;

	$nb_PercentStringFormat = 0;
	$nb_AutomaticNumberingInStringsFields = 0;
	$nb_ConcatInLoop = 0;
	$nb_MixedStringsStyle = 0;
	$nb_SpacesInStringReplacementFields = 0;
	$nb_LoopWithElseWithoutBreak = 0;
	$nb_String = 0;
	$nb_Loop = 0;
	
	
	my $HString = $views->{'HString'};
	#my $root = $views->{'structured_code'};
	my $kindLists = $views->{'KindsLists'};
	my $code = \$views->{'code'};
	
	if (( ! defined $HString ) || (!defined $kindLists) || (!defined $code)) {
		$ret |= Couples::counter_add($compteurs, $PercentStringFormat__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $AutomaticNumberingInStringsFields__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ConcatInLoop__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MixedStringsStyle__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $SpacesInStringReplacementFields__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $LoopWithElseWithoutBreak__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $String__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $Loop__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	$nb_String = scalar keys %$HString;

	my @TLoopKinds = (WhileKind, ForKind);
	my %HLoopKinds = (&WhileKind => 1, &ForKind => 1);

	#my @loops = GetNodesByKindList($root, \@TLoopKinds);
	my @loops = (@{$kindLists->{&WhileKind}}, @{$kindLists->{&ForKind}}) ;
	
	my $nb_Loop = scalar @loops;
	
	my @context = ([], \%HLoopKinds, [\&isConcatenation]);
	for my $loop (@loops) {
		checkLoop($loop, \@context);
	}

	my $nb_quote = 0;
	my $nb_doubleQuote = 0;
	while ($$code =~ /\b(CHAINE_\d+)\b\s*(?:(\%)|(\.)\s*format\()?/g) {
		my $id = $1;
		my $percent = defined $2 ? 1 : 0;
		my $format = defined $3 ? 1 : 0;
		my $value = $HString->{$id};

		if ($percent) {
			$nb_PercentStringFormat++;
			Erreurs::VIOLATION($PercentStringFormat__mnemo, "Use of % operator in string : ".$value);
		}
		elsif ($format) {
			if ($HString->{$id} =~ /\{\s*\}/) {
				$nb_AutomaticNumberingInStringsFields++;
				Erreurs::VIOLATION($AutomaticNumberingInStringsFields__mnemo, "Automatic numbering in format replacement fields in string : ".$value);
			}
		}
		
		if (($percent) || ($format)) {
			while ($value =~ /\{[^}]*\s[^}]*}/sg) {
				$nb_SpacesInStringReplacementFields++;
				Erreurs::VIOLATION($SpacesInStringReplacementFields__mnemo, "Space in format replacement fields in string : ".$value);
			}
		}
		
		if ($value =~ /^'[^']/) {
			$nb_quote++;
		}
		elsif ($value =~ /^"[^"]/) {
			$nb_doubleQuote++;
		}
	}

	if ($nb_quote + $nb_doubleQuote) {
		if ($nb_quote > $nb_doubleQuote) {
			$nb_MixedStringsStyle = int( ($nb_doubleQuote / ($nb_quote + $nb_doubleQuote) * 100));
		}
		else {
			$nb_MixedStringsStyle = int( ($nb_quote / ($nb_quote + $nb_doubleQuote) * 100));
		}
	}
	Erreurs::VIOLATION($MixedStringsStyle__mnemo, "String style homogeneity : $nb_MixedStringsStyle ($nb_quote ' vs $nb_doubleQuote \")");

	$ret |= Couples::counter_update($compteurs, $PercentStringFormat__mnemo, $nb_PercentStringFormat );
	$ret |= Couples::counter_update($compteurs, $AutomaticNumberingInStringsFields__mnemo, $nb_AutomaticNumberingInStringsFields );
	$ret |= Couples::counter_update($compteurs, $ConcatInLoop__mnemo, $nb_ConcatInLoop );
	$ret |= Couples::counter_update($compteurs, $MixedStringsStyle__mnemo, $nb_MixedStringsStyle );
	$ret |= Couples::counter_update($compteurs, $SpacesInStringReplacementFields__mnemo, $nb_SpacesInStringReplacementFields );
	$ret |= Couples::counter_update($compteurs, $LoopWithElseWithoutBreak__mnemo, $nb_LoopWithElseWithoutBreak );
	$ret |= Couples::counter_update($compteurs, $String__mnemo, $nb_String );
	$ret |= Couples::counter_update($compteurs, $Loop__mnemo, $nb_Loop );

	return $ret;
}

1;


