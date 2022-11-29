package Python::CountException;

use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Python::PythonNode;

my $EmptyCatches__mnemo = Ident::Alias_EmptyCatches();
my $RiskyCatches__mnemo = Ident::Alias_RiskyCatches();
my $IllegalThrows__mnemo = Ident::Alias_IllegalThrows();
my $TrySizeAverage__mnemo = Ident::Alias_TrySizeAverage();
my $Catch__mnemo = Ident::Alias_Catch();

my $nb_EmptyCatches = 0;
my $nb_RiskyCatches = 0;
my $nb_IllegalThrows = 0;
my $nb_TrySizeAverage = 0;
my $nb_Catch = 0;

sub isRiskyCatch($$) {
	my $except = shift;
	my $children = shift;
	
	# NOTE : the first child is the condition/expression statement node
	my $expression = $children->[0];
	
	if (${GetStatement($expression)} !~ /\w/) {
		# the except instruction do not specify any exception class name.
		Erreurs::VIOLATION($RiskyCatches__mnemo, "Empty except statement at line ".GetLine($expression));
		return 1;
	}
	elsif (${GetStatement($expression)} =~ /\bBaseException\b/) {
		# "except BaseException" is equivalent to "except:"
		Erreurs::VIOLATION($RiskyCatches__mnemo, "Except with BaseException at line ".GetLine($expression));
		return 1;
	}
	elsif (${GetStatement($expression)} =~ /\bException\b/) {
		# get all siblings
		my $siblings = Lib::NodeUtil::GetChildren(GetParent($except));
		
		my $sibling = $siblings->[0];
		my $idx = 0;
		while ($siblings->[$idx] != $except) {
			$idx++;
		}
		# check previous sibling
		if (($idx > 0) && (! IsKind($siblings->[$idx-1], ExceptKind))) {
			# Our 'except Exception' is in first place => it's a risky catch
			Erreurs::VIOLATION($RiskyCatches__mnemo, "Except Exception in first place at line ".GetLine($expression));
			return 1;
		}
		# check next sibling
		elsif (($idx < (scalar @$siblings)-1) && (IsKind($siblings->[$idx+1], ExceptKind))) {
			# Our 'except Exception' is not in last place => it's a risky catch
			Erreurs::VIOLATION($RiskyCatches__mnemo, "Except Exception not in last place at line ".GetLine($expression));
			return 1;
		}
	}
	
	return 0;
}

sub CountExceptions($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	my $ret =0;
	
	$nb_EmptyCatches = 0;
	$nb_RiskyCatches = 0;
	$nb_Catch = 0;
	
	my $root = $vue->{'structured_code'};
	my $tabagglo = $vue->{'tabagglo'};
	my $r_MixBloc = \$vue->{'MixBloc'};
	my $MixBloc_LinesIndex = $vue->{'MixBloc_LinesIndex'};
	
	if (( ! defined $root ) || (! defined $r_MixBloc) || (! defined $MixBloc_LinesIndex))  {
		$ret |= Couples::counter_add($compteurs, $EmptyCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $Catch__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my @excepts = GetNodesByKind($root, ExceptKind);
	
	$nb_Catch = scalar @excepts;
	
	my $isEmpty = 1;
	for my $except (@excepts) {
		my $children = Lib::NodeUtil::GetChildren($except);
		
		# Check for risky catches
		if (isRiskyCatch($except, $children)) {
			$nb_RiskyCatches++;
		}
		
		# skip the 'cond' children.
		shift @{$children};
		my $nbChildren = scalar @{$children};
		
		my $passLine;
		for my $child (@$children) {
			if (! IsKind($child, PassKind)) {
				$isEmpty = 0;
			}
			else {
				$passLine = GetLine($child);
			}
		}
		
		if ($isEmpty) {
			# empty means : pass instruction or no instruction
			
			my $commentFoundAtLine = 0;
			my $exceptLine = GetLine($except);
			
			#check presence of commentary on the same line than the expect
			#-------------------------------------------------------------
			if ($tabagglo->[$exceptLine-1] =~ /[#"]/) {
				$commentFoundAtLine = $exceptLine;
			}
			# Check comment in the 'except' bloc delimitation
			#------------------------------------------------
			else {
				my $lineIterate = $exceptLine+1;
				# check comment before the last 'pass' instruction.
				if ($passLine) {
					for (; $lineIterate <= $passLine; $lineIterate++) {
						if ($tabagglo->[$lineIterate-1] =~ /[#"]/) {
							$commentFoundAtLine = $lineIterate;
							last;
						}
					}
				}
				
				if (! $commentFoundAtLine) {
					# check comment after the last 'pass' instruction (or the whole except bloc if no 'pass').
					my $endExceptLine = GetEndline($except);
				
					# check each line of the 'except' bloc
					for (; $lineIterate <= $endExceptLine; $lineIterate++) {
						if ($tabagglo->[$lineIterate-1] =~ /[#"]/) {
							$commentFoundAtLine = $lineIterate;
							last;
						}
					}

					# if a line contains a comment, check the indentation of the comment:
					# - in case of positive indentation, the comment is considered belonging to the except bloc.
					# - in case of same or negative indentation, the comment is considered outside the except bloc.
					if ($commentFoundAtLine) {
						my $exceptIndent = getPythonKindData( $except, 'indentation');
						pos($$r_MixBloc) = $MixBloc_LinesIndex->[$commentFoundAtLine];
						if ($$r_MixBloc !~ /\G${exceptIndent}\s/g) {
							# Due to an negative or identical indentation, the comment is considered not belonging to the except structure.
							$commentFoundAtLine = 0;
						}
					}
				}
			}
			if (! $commentFoundAtLine) {
				Erreurs::VIOLATION($EmptyCatches__mnemo, "Empty catch (no instrunction nor comment) for except at line $exceptLine");
				$nb_EmptyCatches++;
			}
		}
	}
	
	$ret |= Couples::counter_add($compteurs, $EmptyCatches__mnemo, $nb_EmptyCatches );
	$ret |= Couples::counter_add($compteurs, $RiskyCatches__mnemo, $nb_RiskyCatches );
	$ret |= Couples::counter_add($compteurs, $Catch__mnemo, $nb_Catch );
	
	return $ret;
}

sub CountRaise($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	my $ret =0;
	
	my $nb_IllegalThrows = 0;
	
	my $code = \$vue->{'code'};

	if ( ! defined $code ) {
		$ret |= Couples::counter_add($compteurs, $IllegalThrows__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	while ($$code =~ /^\s*(raise[ \t]+(?:[\w\.]+\s*,|CHAINE_\d+)[^\n;]*)/mg ) {
			$nb_IllegalThrows++;
			Erreurs::VIOLATION($IllegalThrows__mnemo, "Deprecated raise => $1");
	}
	
	$ret |= Couples::counter_add($compteurs, $IllegalThrows__mnemo, $nb_IllegalThrows );
	
	return $ret;
}

sub CountTry($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	my $ret =0;
	
	my $nb_Try = 0;
	my $nb_TrySizeAverage = 0;
	
	my $agglo = \$vue->{'agglo'};
	my $root = $vue->{'structured_code'};
	my $agglo_LinesIndex = $vue->{'agglo_LinesIndex'};

	if (( ! defined $agglo ) || ( ! defined $root ) || (!defined $agglo_LinesIndex)) {
		$ret |= Couples::counter_add($compteurs, $TrySizeAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my @tries = GetNodesByKind($root, TryKind);
	
	for my $try (@tries) {
		my $children = Lib::NodeUtil::GetChildren($try);
		if (scalar @$children ) {
			# "then" node is the first chiild of the try ...)
			my $then = $children->[0];
			$nb_Try++;
			# begin line of the "try"
			my $beginLine = GetLine($try);
			# end line of the "then"
			my $endLine = Lib::NodeUtil::GetEndline($then);
			# compute position in the agglo view ...
			my $beginPos = $agglo_LinesIndex->[$beginLine+1];
			my $endPos = $agglo_LinesIndex->[$endLine];
			#my $subcode = substr ($$agglo, $beginPos, ($endPos-$beginPos+1));
			my $tryLength = () = substr ($$agglo, $beginPos, ($endPos-$beginPos+1)) =~ /(P)/g;
#print "Try length = $tryLength\n";
			$nb_TrySizeAverage += $tryLength;
		}
	}
	if ($nb_Try) {
		$nb_TrySizeAverage = int($nb_TrySizeAverage / $nb_Try);
		Erreurs::VIOLATION($TrySizeAverage__mnemo, "INFO : TRY sizes average is $nb_TrySizeAverage");
	}
	else {
		$nb_TrySizeAverage = 0;
	}
	
	$ret |= Couples::counter_add($compteurs, $TrySizeAverage__mnemo, $nb_TrySizeAverage );
	
	return $ret;
}

1;


