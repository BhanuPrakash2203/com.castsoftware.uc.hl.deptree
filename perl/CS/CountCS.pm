package CS::CountCS;

use strict;
use warnings;

use Erreurs;
use Lib::NodeUtil;
use CS::CSNode;
use CS::CountNaming;
use CS::CSConfig;

my $If_mnemo = Ident::Alias_If();
my $While_mnemo = Ident::Alias_While();
my $For_mnemo = Ident::Alias_For();
my $Foreach_mnemo = Ident::Alias_Foreach();
my $Case_mnemo = Ident::Alias_Case();
my $Default_mnemo = Ident::Alias_Default();
my $RiskyFunctionCalls_mnemo = Ident::Alias_RiskyFunctionCalls();
my $IllegalThrows_mnemo = Ident::Alias_IllegalThrows();
my $Switch_mnemo = Ident::Alias_Switch();
my $MissingDefaults_mnemo = Ident::Alias_MissingDefaults();
my $BreakCase_mnemo = Ident::Alias_BreakCase();
my $MagicNumbers_mnemo = Ident::Alias_MagicNumbers();
my $MissingBreakInCasePath_mnemo = Ident::Alias_MissingBreakInCasePath();
my $SwitchDefaultMisplaced_mnemo = Ident::Alias_SwitchDefaultMisplaced();
my $SwitchLengthAverage_mnemo = Ident::Alias_SwitchLengthAverage();
my $LargeSwitches_mnemo = Ident::Alias_LargeSwitches();
my $SwitchNested_mnemo = Ident::Alias_SwitchNested();
my $SmallSwitchCase_mnemo = Ident::Alias_SmallSwitchCase();
my $TooDepthArtifact_mnemo = Ident::Alias_TooDepthArtifact();
my $OverDepthAverage_mnemo = Ident::Alias_OverDepthAverage();
my $ArtifactDepthAverage_mnemo = Ident::Alias_ArtifactDepthAverage();


my $nb_If = 0;
my $nb_While = 0;
my $nb_For = 0;
my $nb_Foreach = 0;
my $nb_Case = 0;
my $nb_Default = 0;
my $nb_RiskyFunctionCalls = 0;
my $nb_IllegalThrows = 0;
my $nb_Switch = 0;
my $nb_MissingDefaults = 0;
my $nb_BreakCase = 0;
my $nb_MagicNumbers = 0;
my $nb_MissingBreakInCasePath = 0;
my $nb_SwitchDefaultMisplaced = 0;
my $nb_SwitchLengthAverage = 0;
my $nb_LargeSwitches = 0;
my $nb_SwitchNested = 0;
my $nb_SmallSwitchCase = 0;
my $nb_TooDepthArtifact = 0;
my $nb_OverDepthAverage = 0;
my $nb_ArtifactDepthAverage = 0;

sub CountCS($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
	my $status = 0;
	
	$nb_If = 0;
	$nb_While = 0;
	$nb_For = 0;
	$nb_Foreach = 0;
	$nb_Case = 0;
	$nb_Default = 0;


	my $KindsLists = $views->{'KindsLists'};

	if ( ! defined $KindsLists ) {
		$status |= Couples::counter_add($compteurs, $If_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $While_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $For_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $Foreach_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $Case_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $Default_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my  $ifs = $KindsLists->{&IfKind};
	my  $nb_If = scalar @$ifs;
	Erreurs::VIOLATION($If_mnemo, "METRIC : number of 'if' statements : $nb_If");
	
	my  $whiles = $KindsLists->{&WhileKind};
	my  $nb_While = scalar @$whiles;
	Erreurs::VIOLATION($While_mnemo, "METRIC : number of 'while' statements : $nb_While");
	
	my  $fors = $KindsLists->{&ForKind};
	my  $nb_For = scalar @$fors;
	Erreurs::VIOLATION($For_mnemo, "METRIC : number of 'for' statements : $nb_For");
	
	my  $foreachs = $KindsLists->{&ForeachKind};
	my  $nb_Foreach = scalar @$foreachs;
	Erreurs::VIOLATION($Foreach_mnemo, "METRIC : number of 'foreach' statements : $nb_Foreach");
	
	my  $cases = $KindsLists->{&CaseKind};
	my  $nb_Case = scalar @$cases;
	Erreurs::VIOLATION($Case_mnemo, "METRIC : number of 'case' statements : $nb_Case");
	
	my  $defaults = $KindsLists->{&DefaultKind};
	my  $nb_Default = scalar @$defaults;
	Erreurs::VIOLATION($Default_mnemo, "METRIC : number of 'default' statements : $nb_Default");
	
	$status |= Couples::counter_add($compteurs, $If_mnemo, $nb_If);
	$status |= Couples::counter_add($compteurs, $While_mnemo, $nb_While);
	$status |= Couples::counter_add($compteurs, $For_mnemo, $nb_For);
	$status |= Couples::counter_add($compteurs, $Foreach_mnemo, $nb_Foreach);
	$status |= Couples::counter_add($compteurs, $Case_mnemo, $nb_Case);
	$status |= Couples::counter_add($compteurs, $Default_mnemo, $nb_Default);
	
	return $status;
} 


# ------------------------ S W I T C H  --------------------------

sub countBreakCase($) {
	my $node = shift;
	
	my @breakCase = GetNodesByKindList_StopAtBlockingNode($node, [BreakKind], [WhileKind, ForKind, ForeachKind, SwitchKind]);
	
	my $nb_detections = scalar @breakCase;
	
	# remove one detection if the last instruction is a break
	if ((scalar @{GetChildren($node)}) && IsKind(GetChildren($node)->[-1], BreakKind)) {
		$nb_detections--;
	}
	
	return $nb_detections;
}

sub checkFinalBreak($) {
	my $case = shift;
	my $children = GetChildren($case);
	if (scalar @$children) {
		if (IsKind($children->[-1], BreakKind)) {
			return 1;
		}
	}
	else {
		# not a violation if the case is empty
		return 1;
	}
	return 0;
}

sub CountSwitch($$$) {
	my ($file, $views, $compteurs) = @_ ;

	my $status = 0;
	$nb_Switch = 0;
	$nb_MissingDefaults = 0;
	$nb_BreakCase = 0;
	$nb_MissingBreakInCasePath = 0;
	$nb_SwitchDefaultMisplaced = 0;
	$nb_SwitchLengthAverage = 0;
	$nb_LargeSwitches = 0;
	$nb_SwitchNested = 0;
	$nb_SmallSwitchCase = 0;

	my $KindsLists = $views->{'KindsLists'};

	if ( ! defined $KindsLists ) {
		$status |= Couples::counter_add($compteurs, $Switch_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $MissingDefaults_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $BreakCase_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $MissingBreakInCasePath_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $SwitchDefaultMisplaced_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $SwitchLengthAverage_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $LargeSwitches_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $SwitchNested_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $SmallSwitchCase_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $switches = $KindsLists->{&SwitchKind};
	
	for my $switch (@$switches) {
		$nb_Switch++;
		my $lineSwitch = GetLine($switch);
		my $missingDefault = 1;
		my $nb_Case = 0;
		my $children = GetChildren(GetChildren($switch)->[1]);
		
		my $indexOfDefault = 0;
		my $index = 0;
		# CASE & DEFAULT treatment ...
		for my $child (@$children) {
			$index++;
			my $kind = GetKind($child);

			if ($kind eq DefaultKind) {
				$indexOfDefault = $index;
				$missingDefault = 0;
			}
			else {
				$nb_SwitchLengthAverage++;
				$nb_Case++;
			}
			$nb_BreakCase += countBreakCase($child);
			
			if (($kind eq CaseKind) || ($child != $children->[-1])) {
				if (! checkFinalBreak($child)) {
					$nb_MissingBreakInCasePath++;
					Erreurs::VIOLATION($MissingBreakInCasePath_mnemo, "Missing break in case/default at line ".GetLine($child));
				}
			}
		}
		
		# CHECK nested switches
		my @NestedSwitches = GetNodesByKindList_StopAtBlockingNode($switch, [SwitchKind], [SwitchKind]);
		if (scalar @NestedSwitches > 0) {
			for my $nested (@NestedSwitches) {
				$nb_SwitchNested++;
				Erreurs::VIOLATION($SwitchNested_mnemo, "Nested switch at line ".GetLine($nested));
			}
		}
		
		if (($indexOfDefault > 1) && ($indexOfDefault != $index)) {
			$nb_SwitchDefaultMisplaced++;
			Erreurs::VIOLATION($SwitchDefaultMisplaced_mnemo, "default not in first or last position in switch at line $lineSwitch");
		}
		
		if ($missingDefault) {
			$nb_MissingDefaults++;
			Erreurs::VIOLATION($MissingDefaults_mnemo, "Missing default for switch at line $lineSwitch");
		}
		
		if ($nb_Case > CS::CSConfig::MAX_SWITCH_LENGTH) {
			$nb_LargeSwitches++;
			Erreurs::VIOLATION($LargeSwitches_mnemo, "Switch at line $lineSwitch has more than ".CS::CSConfig::MAX_SWITCH_LENGTH." cases");
		}
	
		if ($nb_Case < 3) {
			$nb_SmallSwitchCase++;
			Erreurs::VIOLATION($SmallSwitchCase_mnemo, "Switch has less than 3 cases at line $lineSwitch ");
		}
	}
	
	if ($nb_Switch) {
		$nb_SwitchLengthAverage = int ($nb_SwitchLengthAverage / $nb_Switch);
	}
	
	Erreurs::VIOLATION($Default_mnemo, "METRIC : number of 'default' statements : $nb_Default");
	Erreurs::VIOLATION($Default_mnemo, "METRIC : number of 'break' in case statements : $nb_BreakCase");
	Erreurs::VIOLATION($Default_mnemo, "METRIC : Switch length average : $nb_SwitchLengthAverage");

	$status |= Couples::counter_add($compteurs, $Switch_mnemo, $nb_Switch);
	$status |= Couples::counter_add($compteurs, $MissingDefaults_mnemo, $nb_MissingDefaults);
	$status |= Couples::counter_add($compteurs, $BreakCase_mnemo, $nb_BreakCase);
	$status |= Couples::counter_add($compteurs, $MissingBreakInCasePath_mnemo, $nb_MissingBreakInCasePath);
	$status |= Couples::counter_add($compteurs, $SwitchDefaultMisplaced_mnemo, $nb_SwitchDefaultMisplaced);
	$status |= Couples::counter_add($compteurs, $SwitchLengthAverage_mnemo, $nb_SwitchLengthAverage);
	$status |= Couples::counter_add($compteurs, $LargeSwitches_mnemo, $nb_LargeSwitches);
	$status |= Couples::counter_add($compteurs, $SwitchNested_mnemo, $nb_SwitchNested);
	$status |= Couples::counter_add($compteurs, $SmallSwitchCase_mnemo, $nb_SmallSwitchCase);

	return $status;
}

sub CountRiskyFunctionCalls($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $status = 0;
  $nb_RiskyFunctionCalls = 0;

  if ( ! defined $vue->{'code'} ) {
    $status |= Couples::counter_add($compteurs, $RiskyFunctionCalls_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  $nb_RiskyFunctionCalls = () = $vue->{'code'} =~ /\bGC\.Collect\s*\(/sg;

  $status |= Couples::counter_add($compteurs, $RiskyFunctionCalls_mnemo, $nb_RiskyFunctionCalls);

  return $status;
}

sub CountIllegalThrows {
	my ($fichier, $vue, $compteurs) = @_ ;
	my $status = 0;

	$nb_IllegalThrows = 0;

	if ( ! defined $vue->{'code'} ) {
		$status |= Couples::counter_add($compteurs, $IllegalThrows_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	while ($vue->{'code'} =~ /\bnew\s+(Exception|SystemException|NullReferenceException|IndexOutOfRangeException)\b/sg ) {
		Erreurs::VIOLATION($Default_mnemo, "Illegal intantiation of exception class : $1");
		$nb_IllegalThrows++;
	}

	$status |= Couples::counter_add($compteurs, $IllegalThrows_mnemo, $nb_IllegalThrows);

	return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountItem($$$$) {
  my ($item, $id, $vue, $compteurs) = @_ ;
  my $status = 0;
  
  my $nb = () = $$vue =~ /\b${item}\b/sg ;
  $status |= Couples::counter_add($compteurs, $id, $nb);

  return $status;
}

#-------------------------------------------------------------------------------
# Module de comptage des mots cles
#-------------------------------------------------------------------------------
sub CountKeywords($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $status = 0;

  my $sansprepro = \$vue->{'code'};

  #$status |= CountItem('using', Ident::Alias_Using(), $sansprepro, $compteurs);
  #$status |= CountItem('if', Ident::Alias_If(), $sansprepro, $compteurs);
  $status |= CountItem('else', Ident::Alias_Else(), $sansprepro, $compteurs);
  #$status |= CountItem('while', Ident::Alias_While(), $sansprepro, $compteurs);
  #$status |= CountItem('for', Ident::Alias_For(), $sansprepro, $compteurs);
  #$status |= CountItem('foreach', Ident::Alias_Foreach(), $sansprepro, $compteurs);
  $status |= CountItem('continue', Ident::Alias_Continue(), $sansprepro, $compteurs);
  #$status |= CountItem('switch', Ident::Alias_Switch(), $sansprepro, $compteurs);
  #$status |= CountItem('default', Ident::Alias_Default(), $sansprepro, $compteurs);
  #$status |= CountItem('try', Ident::Alias_Try(), $sansprepro, $compteurs);
  #$status |= CountItem('catch', Ident::Alias_Catch(), $sansprepro, $compteurs);
  #$status |= CountItem('exit', Ident::Alias_Exit(), $sansprepro, $compteurs);
  $status |= CountItem('is', Ident::Alias_Instanceof(), $sansprepro, $compteurs);
  #$status |= CountItem('new', Ident::Alias_New(), $sansprepro, $compteurs);
  #$status |= CountItem('case', Ident::Alias_Case(), $sansprepro, $compteurs);

  return $status;
}

sub CountMagicNumbers($$$) {
	my ($fichier, $view, $compteurs) = @_ ;

	my $code = \$view->{'code'};
	my $status = 0;

	if ( ! defined $code ) {
		$status |= Couples::counter_add($compteurs, $MagicNumbers_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $nb_MagicNumbers = 0;

	# reconnaissance des magic numbers :
	# 1) identifiants commencant forcement par un chiffre decimal.
	# 2) peut contenir des '.' (flottants)
	# 3) peut contenir des 'E' ou 'e' suivis eventuellement de '+/-' pour les flottants
	# peut se terminer par D, d, F, f pour un decimal qui n'aurait pas le point.
  
	# LITERAL REGEXP:
	#   [^\w] ( \d+ | \d*\.\d+ ) ( [Ee][\+\-]?\d+ ) \w* 
  
	my $line = 1;
	while ( $$code =~ /(\n)|(\bconst\b)|[^\w]((?:\d*\.\d+|\d+)(?:[Ee][\+\-]?\d+)?\w*)/sgc ) {
		if (defined $1) {
			$line++;
		}
		elsif (defined $2) {
			# get the constant statement
			if ($$code =~ /\G([^=]*=[^;]*;)/gc) {
				$line += () = $1 =~ /\n/g;
			}
		}
		else {
			my $number = $3;
			if ($number !~ /\A(?:1|0|[01]?\.0)\z/m ) {
				$nb_MagicNumbers++;
				Erreurs::VIOLATION($MagicNumbers_mnemo, "Magic number $number at line $line");
			}
		}
	};

	$status |= Couples::counter_add($compteurs, $MagicNumbers_mnemo, $nb_MagicNumbers);

	return $status;

}

sub CountDeepPath {
    my ($fichier, $vue, $couples, $options) = @_;
    my $status = 0;
    $nb_TooDepthArtifact = 0;
    $nb_OverDepthAverage = 0;
    $nb_ArtifactDepthAverage = 0;

    if ( ! defined $vue->{'code'} ) {
        $status |= Couples::counter_add($nb_TooDepthArtifact, $TooDepthArtifact_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $status |= Couples::counter_add($nb_OverDepthAverage, $OverDepthAverage_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $status |= Couples::counter_add($nb_ArtifactDepthAverage, $ArtifactDepthAverage_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my $root =  $vue->{'structured_code'} ;
    
    # remove ElseKind because the "else" node is always under the "if" node in the nodetree. So remove it to not add a unexpected depth level, because "it" and "else" are at the same level in the analyzed code source.
    #my $kindNodes =[IfKind, ElseKind, WhileKind, ForKind, CaseKind, TryKind];
    my $kindNodes =[IfKind, WhileKind, ForKind, CaseKind, DefaultKind, TryKind, DoKind, ForeachKind];
    
    my @OverDepthAverage;
    my $totalOverDepth = 0;
    my $nb_paths = 0;
	#if (my @childrenNodes = GetNodesByKindList($root, $kindNodes, 1)) {
        
        #for my $child (@childrenNodes) {
#print STDERR "CHILD at line ".GetLine($child)."\n";
			my $depth = 0;
			my $result = [];
            #calculate_depth($child, $kindNodes, $depth, $result);
            calculate_depth($root, $kindNodes, $depth, $result);
            
            # treat results over threshold. If there is no too deep path from the child, result is an empty array.
            for my $result (@{$result}) {
                # $result->[0] = kind
                # $result->[1] = line
                # $result->[2] = depth
                
                if ($result->[2] > CS::CSConfig::MAX_DEPTH_THRESHOLD) {
					# increase number of artifact over the threshold
					$nb_TooDepthArtifact++;
					Erreurs::VIOLATION($TooDepthArtifact_mnemo, "Deep code (depth=$result->[2]/threshold=".CS::CSConfig::MAX_DEPTH_THRESHOLD." exceeded) for $result->[0] statement at line $result->[1]");

					$totalOverDepth += $result->[2] - CS::CSConfig::MAX_DEPTH_THRESHOLD;
				}
#print STDERR "DEPTH of statement at line $result->[1] is $result->[2]\n";
				$nb_ArtifactDepthAverage += $result->[2];
				$nb_paths++;
            }
        #}
    #}

    if ($totalOverDepth) {
		$nb_OverDepthAverage = sprintf "%.0f", ($totalOverDepth / $nb_TooDepthArtifact);
#print STDERR "OVER DEPTH = $totalOverDepth / $nb_TooDepthArtifact = $nb_OverDepthAverage\n";
	}
	
	if ($nb_paths) {
		$nb_ArtifactDepthAverage = sprintf "%.0f", ($nb_ArtifactDepthAverage / $nb_paths);
#print STDERR "PATH DEPTH AVERAGE (nb paths = $nb_paths) = $nb_ArtifactDepthAverage\n";
	}
	
	#else {
	#	print STDERR "AVERAGE OVER DEPTH = 0\n";
	#}

    $status |= Couples::counter_add($couples, $TooDepthArtifact_mnemo ,$nb_TooDepthArtifact );
    $status |= Couples::counter_add($couples, $OverDepthAverage_mnemo ,$nb_OverDepthAverage );
    $status |= Couples::counter_add($couples, $ArtifactDepthAverage_mnemo ,$nb_ArtifactDepthAverage );

    return $status;
}

sub calculate_depth($$$$);
sub calculate_depth($$$$) {
    my $currentChild = shift;
    my $kindNodes = shift;
    my $depth = shift;
    my $result = shift;

    my @childrenSubNodes = GetNodesByKindList($currentChild, $kindNodes, 1);
    # for loop of children which type is equals to $kindNodes
    # (i.e. if, else, while, for, case, try...)
    my $level_node = $depth;
    for my $childrenSubNode (@childrenSubNodes) {
#print STDERR "SUB CHILD at line ".GetLine($childrenSubNode)."\n";
        # level down
        $depth++;
        # if at least kind of a child is equals to $kindNodes
        if (GetNodesByKindList($childrenSubNode, $kindNodes, 1)) {
            calculate_depth($childrenSubNode,$kindNodes, $depth, $result);
        }
        # if no kind of child is equals to $kindNodes and depth > CS::CSConfig::DEPTH_THRESHOLD
        #elsif ($depth > CS::CSConfig::MAX_DEPTH_THRESHOLD) {
        else {
            # push depth of the path...
            if (! defined GetLine($childrenSubNode)) {
print STDERR "UNDEFINED LINE for $childrenSubNode->[0]\n";
			}
            push(@{$result}, [GetKind($childrenSubNode), GetLine($childrenSubNode), $depth] );
        }

        # continue for loop with origin level
        $depth = $level_node;
    }
}

1;
