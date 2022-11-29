package Clojure::CountClojure;

use strict;
use warnings;

use Erreurs;

use Clojure::ClojureNode;
use Lib::NodeUtil;

my $ParenthesesSpacing__mnemo = Ident::Alias_ParenthesesSpacing();
my $TrailingParentheses__mnemo = Ident::Alias_TrailingParentheses();
my $OperatorCouldBeFunction__mnemo = Ident::Alias_OperatorCouldBeFunction();
my $UselessFullSyntaxMetadata__mnemo = Ident::Alias_UselessFullSyntaxMetadata();
my $BadStringAsHaskKey__mnemo = Ident::Alias_BadStringAsHaskKey();

my $nb_ParenthesesSpacing = 0;
my $nb_TrailingParentheses = 0;
my $nb_OperatorCouldBeFunction = 0;
my $nb_UselessFullSyntaxMetadata = 0;
my $nb_BadStringAsHaskKey = 0;

my $PIVOT = qr/[\[\{\(\)\}\]\n]/;
my $ANTI_PIVOT = qr/[^\[\{\(\)\}\]\n]/;
my $OP_PIVOT = qr/[\{\(\[]/;
my $CL_PIVOT = qr/[\)\]\}]/;

# COUNT one violation each time one of the following rule is not respected:
# - openning
#    - always preceded by a blank (EXCEPTION if preceded with #\@`^~\ taht are attached to the openning, or another openning)
#    - never followed by a blank
#
# - closing
#    - never preceded by a blank (EXCEPTION if preceded by only blanks from the beginning of the line)
#    - always followed by a blank (EXCEPTION for , that is a separator)
#
# - EXCEPTION : qouted forms '( are ignored because not evaluated and can lead to false positive.

my %CLOSING = ( "(" => ")",
                "{" => "}",
                "[" => "]" );

sub swallowOpenClose($$) {
	my $code = shift;
	my $open = shift;
	my $close = $CLOSING{$open};
	
	my $line = 0;
	my $level = 1;
	while ($$code =~ /\G([^\[\{\(\]\}\)\n]*)([\[\{\(\]\}\)\n])/g) {
		if ($2 eq $open) {
			$level++;
		}
		elsif ($2 eq $close) {
			$level--;
			if (! $level) {
				return $line;
			}
		}
		elsif ($2 eq "\n") {
			$line++;
		}
	}
	
print STDERR "RETURN WITHOUT END !!!\n";
	return $line;
}

sub CountParenthesesSpacing($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_ParenthesesSpacing = 0;
    
    my $code =  \$vue->{'code'} ;

    if ( ! defined $code )
    {
        $ret |= Couples::counter_add($compteurs, $ParenthesesSpacing__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
 
	# openning should be précéded by space or another openning.
	#($$code = /[^\s\[\(\{][\[\(\{]/g;
	my $line = 1;
	my $previousPivot = "\n";
	my $pivot;
	my ($left) = $$code =~ /^(${ANTI_PIVOT})*/gm;
	my $right;
	while ($$code =~ /\G(?:($OP_PIVOT)|($CL_PIVOT)|(\n))((${ANTI_PIVOT})?(${ANTI_PIVOT})*)/g) {
#print STDERR "PIVOT=".($1||$2||$3).", LEFT=".($left||"undef").", RIGHT=".($4||"undef").", LINE : $line \n";

		my $op_pivot = $1;
		my $cl_pivot = $2;
		my $nl_pivot = $3;
		$pivot = $1 || $2 || $3;
		
		my $interPivot = $4;
		$right = $5;
		my $next_left = $6;

		# quoted forms are skipped
		if ((defined $op_pivot) && (defined $left) && ($left eq "'")) {
			$line += swallowOpenClose($code, $pivot);
			($left) = $$code =~ /\G(${ANTI_PIVOT})*/gc;
			$previousPivot = $CLOSING{$op_pivot};
			next;
		}

		# OPENING PIVOT
		if (defined $op_pivot) {
			if (defined $left) {
#print STDERR "LEFT = <$left> at line $line\n";
				if ($left !~ /[ \t]/) {
					if ($left !~ /[#\@`^~\\]/) {
						$nb_ParenthesesSpacing++;
						Erreurs::VIOLATION($ParenthesesSpacing__mnemo, "missing space before $pivot at line $line");
					}
				}
			}
			else {
				# $left is undefined means pivot is immediately following previous pivot. OK if two OPENNING are following each other
				if ($previousPivot !~ /[\{\[\(\n]/) {
					$nb_ParenthesesSpacing++;
					Erreurs::VIOLATION($ParenthesesSpacing__mnemo, "missing space between $previousPivot and $pivot at line $line");
				}
			}
			
			if (defined $right) {
				if ($right =~ /[ \t]/) {
					$nb_ParenthesesSpacing++;
					Erreurs::VIOLATION($ParenthesesSpacing__mnemo, "unexpected space after $pivot at line $line");
				}
			}
		}
		# CLOSING PIVOT
		elsif (defined $cl_pivot) {
			if (defined $left) {
				# left is a blank
				if ($left =~ /[ \t]/) {
					# OK if left is blank from the beginning of the line ...
					if (($previousPivot ne "\n") || ($interPivot =~ /\S/)) {
						$nb_ParenthesesSpacing++;
						Erreurs::VIOLATION($ParenthesesSpacing__mnemo, "unexpected space before $pivot at line $line");
					}
				}
			}
			else {
				# WE CONSIDER that any closing pivot can be preceded by any other kind of pivot. ]]  or [] for examples are both OK.
				
				# $left is undefined means pivot is immediately following previous pivot. OK if two CLOSING are following each other
				#if ($previousPivot !~ /[\}\]\)\n]/) {
				#	$nb_ParenthesesSpacing++;
				#	Erreurs::VIOLATION($ParenthesesSpacing__mnemo, "unexpected $previousPivot before $2 at line $line");
				#}
			}
			
			if (defined $right) {
				if ($right !~ /[ \t]/) {
					# coma is OK because it's a separator.
					if ($right ne ",") {
						$nb_ParenthesesSpacing++;
						Erreurs::VIOLATION($ParenthesesSpacing__mnemo, "missing space after $pivot at line $line");
					}
				}
			}
		}
		# PIVOT IS NEW LINE
		elsif (defined $nl_pivot) {
			$line++;
		}
		
		$previousPivot = $pivot;
		
		# left for next iteration.
		if (defined $next_left) {
			$left = $next_left;
		}
		else {
			# if there is no "left", then the next pivot is immediately following the "right" of preceding pivot.
			$left = $right;
		}
	}	
 
	
	$ret |= Couples::counter_add($compteurs, $ParenthesesSpacing__mnemo, $nb_ParenthesesSpacing );
  
	return $ret;
}

sub CountTrailingParentheses($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_TrailingParentheses = 0;
    
    my $code =  \$vue->{'text'} ;

    if ( ! defined $code )
    {
        $ret |= Couples::counter_add($compteurs, $TrailingParentheses__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

	my $line = 1;

	while ($$code =~ /^([ \t\)\}\]]*).*$/gm) {
		if (defined $1) {
			if ($1 =~ /\S/) {
				$nb_TrailingParentheses++;
				Erreurs::VIOLATION($TrailingParentheses__mnemo, "Trailing closing at line $line");
			}
		}
		$line++;
	}

	$ret |= Couples::counter_add($compteurs, $TrailingParentheses__mnemo, $nb_TrailingParentheses );
  
	return $ret;
}

sub checkPlus($) {
	my $list = shift;
	
	my $children = GetChildren($list);
	
	return if (scalar @$children > 2);
	
	for my $child (@{$children}) {
		if (${GetStatement($child)} eq "1") {
			$nb_OperatorCouldBeFunction++;
			Erreurs::VIOLATION($OperatorCouldBeFunction__mnemo,"'+' could be 'inc' at line ".GetLine($list));;
			last;
		}
	}
}

sub checkMinus($) {
	my $list = shift;
	
	for my $child (@{GetChildren($list)}) {
		if (${GetStatement($child)} eq "1") {
			$nb_OperatorCouldBeFunction++;
			Erreurs::VIOLATION($OperatorCouldBeFunction__mnemo,"'-' could be 'dec' at line ".GetLine($list));;
			last;
		}
	}
}

sub checkGreater($) {
	my $list = shift;
	
	my $child2 = GetChildren($list)->[1];
	if (${GetStatement($child2)} eq "0") {
		$nb_OperatorCouldBeFunction++;
		Erreurs::VIOLATION($OperatorCouldBeFunction__mnemo,"'>' could be 'pos?' at line ".GetLine($list));;
	}
}

sub checkLess($) {
	my $list = shift;
	
	my $child2 = GetChildren($list)->[1];
	if (${GetStatement($child2)} eq "0") {
		$nb_OperatorCouldBeFunction++;
		Erreurs::VIOLATION($OperatorCouldBeFunction__mnemo,"'>' could be 'neg?' at line ".GetLine($list));;
	}
}

sub checkEqual($) {
	my $list = shift;
	
	for my $child (@{GetChildren($list)}) {
		if (${GetStatement($child)} eq "0") {
			$nb_OperatorCouldBeFunction++;
			Erreurs::VIOLATION($OperatorCouldBeFunction__mnemo,"'=' could be 'zero?' at line ".GetLine($list));;
			last;
		}
	}
}

sub CountList($$$) {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_OperatorCouldBeFunction = 0;
    
    my $root = $vue->{'structured_code'} ;

    if ( ! defined $root )
    {
        $ret |= Couples::counter_add($compteurs, $OperatorCouldBeFunction__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

	my @lists = GetNodesByKind($root, ListKind);
	
	for my $list (@lists) {
		my $command = GetName($list);
		
		next if (!defined $command);
		
		if ($command eq "+") {
			checkPlus($list);
		}
		elsif ($command eq "-") {
			checkMinus($list);
		}
		elsif ($command eq ">") {
			checkGreater($list);
		}
		elsif ($command eq "<") {
			checkLess($list);
		}
		elsif ($command eq "=") {
			checkEqual($list);
		}
	}
	
	$ret |= Couples::counter_add($compteurs, $OperatorCouldBeFunction__mnemo, $nb_OperatorCouldBeFunction );
  
	return $ret;
}

sub CountUselessFullSyntaxMetadata() {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_UselessFullSyntaxMetadata = 0;
    
    my $code =  \$vue->{'code'} ;

    if ( ! defined $code )
    {
        $ret |= Couples::counter_add($compteurs, $UselessFullSyntaxMetadata__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
    
    my $line = 1;
    while ($$code =~ /(?:\^\{\s*(\S+)\s+true\b|(\n))/g) {
		if (defined $1) {
			$nb_UselessFullSyntaxMetadata++;
			Erreurs::VIOLATION($UselessFullSyntaxMetadata__mnemo,"Metadata $1 could be set by compact syntax at line $line");
		}
		else {
			$line++;
		}
	}
    
    $ret |= Couples::counter_add($compteurs, $UselessFullSyntaxMetadata__mnemo, $nb_UselessFullSyntaxMetadata );
  
	return $ret;
}

sub CountMap() {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_BadStringAsHaskKey = 0;
    
    my $KindsLists = $vue->{'KindsLists'};

    if ( ! defined $KindsLists )
    {
        $ret |= Couples::counter_add($compteurs, $BadStringAsHaskKey__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
    
    my $maps = $KindsLists->{&MapKind};
    
    my $idx_value = 0;
    for my $map (@$maps) {
		my $children = GetChildren($map);
		
		for my $child (@$children) {
#print STDERR "CHILD : $child->[0]\n";		
			if ($idx_value) {
				$idx_value = 0;
				next;
			}
			
			my $stmt = GetStatement($child);
#print STDERR "KEY : $$stmt\n";
			if ($$stmt =~ /(CHAINE_\d+)/ ) {
				my $HString = $vue->{'HString'};
				my $string = $HString->{$1} || "??";
#print STDERR " ---> STRING = $string\n";				
				if ($string =~ /^"[a-zA-Z_]\w+"$/m) {
					$nb_BadStringAsHaskKey++;
					Erreurs::VIOLATION($BadStringAsHaskKey__mnemo,"Use of string ($string) as map key at line ".GetLine($child));
				}
			}
			
			$idx_value = 1;
		}
	}
    
    $ret |= Couples::counter_add($compteurs, $BadStringAsHaskKey__mnemo, $nb_BadStringAsHaskKey );
  
	return $ret;

}

# SPEC VG : count function and decisions
# - function : do not count anonymous, because clojure is a massive functional language, and decomposition of the code in function is a normal practice.
#   So assume that complexity due to functions is relevant from the number of high level named functions. Indeed, named function are usable anywhere in the code, 
#   and by this way create a entry points, callable or not (like an implicit decision)
#   FunctionsKind + FunctionArityKind
# - decision : forms if + while + loop + case + default

1;
