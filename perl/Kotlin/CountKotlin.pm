package Kotlin::CountKotlin;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::Node;
use Lib::NodeUtil;
use Lib::CountUtils;

use Kotlin::KotlinNode;
use Kotlin::CountNaming;


my $MultipleStatementsOnSameLine__mnemo = Ident::Alias_MultipleStatementsOnSameLine();
my $TooDepthArtifact__mnemo = Ident::Alias_TooDepthArtifact();
my $ClassNameIsNotFileName__mnemo = Ident::Alias_ClassNameIsNotFileName();
my $UselessTypeSpecification__mnemo = Ident::Alias_UselessTypeSpecification();
my $BadSpacing__mnemo = Ident::Alias_BadSpacing();
my $BadVariableNames__mnemo = Ident::Alias_BadVariableNames();
my $BadConstantNames__mnemo = Ident::Alias_BadConstantNames();
my $BadAttributeNames__mnemo = Ident::Alias_BadAttributeNames();
my $DeadCode__mnemo = Ident::Alias_DeadCode();
my $EmptyCatches__mnemo = Ident::Alias_EmptyCatches();
my $Catch__mnemo = Ident::Alias_Catch();
my $NestedTryCatches__mnemo = Ident::Alias_NestedTryCatches();
my $GenericCatches__mnemo = Ident::Alias_GenericCatches();


my $nb_MultipleStatementsOnSameLine = 0;
my $nb_TooDepthArtifact = 0;
my $nb_ClassNameIsNotFileName = 0;
my $nb_UselessTypeSpecification = 0;
my $nb_BadSpacing = 0;
my $nb_DeadCode = 0;
my $nb_EmptyCatches = 0;
my $nb_Catch = 0;
my $nb_NestedTryCatches = 0;
my $nb_GenericCatches = 0;

#-------------------------------------------------------------------------------
# DESCRIPTION: fonction de comptage d'item
#-------------------------------------------------------------------------------
sub CountItem($$$$$)
{
    my ($item, $mnemo_Item, $code, $compteurs, $msg) = @_ ;
    my $status = 0;

    if (!defined $$code )
    {
        $status |= Couples::counter_add($compteurs, $mnemo_Item, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $nbr_Item = () = $$code =~ /${item}/sg;

	Erreurs::VIOLATION($mnemo_Item, $msg."($nbr_Item violations)");

#if ($mnemo_Item eq Ident::Alias_MissingScalarType()) {
#print "Applying pattern : $item\n";
#	pos $$code =0;
#   
#	while ($$code =~ /(${item})/sg) {
#	    print $1."\n";
#	}
#}

    $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);

    return $status;
}

sub CountItemByLine($$$$$)
{
    my ($item, $mnemo_Item, $code, $compteurs, $msg) = @_ ;
    my $status = 0;

    if (!defined $$code )
    {
        $status |= Couples::counter_add($compteurs, $mnemo_Item, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $nbr_Item = 0;;
    my $line = 1;
	while ($$code =~ /(\n)|(${item})/sg) {
		if (defined $1) {
			$line++;
		}
		else {
			$nbr_Item++;
			Erreurs::VIOLATION($mnemo_Item, $msg." at line $line");
		}
	}

    $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des mots cles
#-------------------------------------------------------------------------------
sub CountKeywords($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $code = \$vue->{'code'};

    $status |= CountItemByLine('\?:\s*(?:true|false)',		Ident::Alias_BadNullableCheck(),		$code, $compteurs, "Bad nullable Boolean check");
    return $status;
}



sub CountLine($) {
	my $code = shift;
	
	my $nbline = 1;
	while ($$code =~ /^(.*)$/mg) {
		my $line = $1;

		while ( $line =~ /;\s*([^};\s]+)/sg) {
			$nb_MultipleStatementsOnSameLine++;
			Erreurs::VIOLATION($MultipleStatementsOnSameLine__mnemo, "instruction ($1) should be on another line, at line $nbline");
		}
		$nbline++;
	}
}

sub CountKotlin($$$) {
	my ($file, $views, $compteurs) = @_ ;
    
	my $ret = 0;
	$nb_MultipleStatementsOnSameLine = 0;
	$nb_ClassNameIsNotFileName = 0;
  
	my $code = \$views->{'code'};
	my $tree = $views->{'structured_code'};
  
	if (( ! defined $code ) || ( ! defined $tree ))
	{
		$ret |= Couples::counter_add($compteurs, $MultipleStatementsOnSameLine__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ClassNameIsNotFileName__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );	
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	CountLine($code);
	
	my $nb_classes = 0;
	my $nb_interfaces = 0;
	my $className;
	my $interfaceName;
	my $nb_functions = 0;
	my $ClassOrInterfaceNameIsFileName = 0;
	my ($filename) = $file =~ /(?:^|[\/\/])([^\\\/]*)\.kt$/m;
	for my $node (@{GetChildren($tree)}) {
#print STDERR "NODE : $node->[0]\n";
		if (IsKind($node, ClassKind)) {
			$nb_classes++;
			$className = GetName($node);
			if ((! $ClassOrInterfaceNameIsFileName) && ($className eq $filename)) {
				$ClassOrInterfaceNameIsFileName = 1;
			}
		}
		elsif (IsKind($node, InterfaceKind)) {
			$nb_interfaces++;
			$interfaceName = GetName($node);
			if ((! $ClassOrInterfaceNameIsFileName) && ($interfaceName eq $filename)) {
				$ClassOrInterfaceNameIsFileName = 1;
			}
		}
		elsif (IsKind($node, FunctionKind)) {
			$nb_functions++;
		}
	}
	
	if ( (! $nb_functions) && (! $ClassOrInterfaceNameIsFileName)) {
	#if (! $ClassOrInterfaceNameIsFileName) {
		
		if (($nb_interfaces == 1) && ($nb_classes == 1)) {
			$nb_ClassNameIsNotFileName++;
			Erreurs::VIOLATION($ClassNameIsNotFileName__mnemo, "(with $nb_functions top level fct) both class '$className' and interface '$interfaceName' do not comply with file name '$filename'");
		}
		elsif ($nb_interfaces == 1) {
			$nb_ClassNameIsNotFileName++;
			Erreurs::VIOLATION($ClassNameIsNotFileName__mnemo, "(with $nb_functions top level fct) interface '$interfaceName' has not the same name than the file '$filename'");
		}
		elsif ($nb_classes == 1) {
			$nb_ClassNameIsNotFileName++;
			Erreurs::VIOLATION($ClassNameIsNotFileName__mnemo, "(with $nb_functions top level fct) class '$className' has not the same name than the file '$filename'");
		}
	}

    $ret |= Couples::counter_add($compteurs, $MultipleStatementsOnSameLine__mnemo, $nb_MultipleStatementsOnSameLine );
    $ret |= Couples::counter_add($compteurs, $ClassNameIsNotFileName__mnemo, $nb_ClassNameIsNotFileName );
    
    return $ret;
}


sub checkTry($);
sub checkTry($) {
	my $try = shift;

	my @subTry = GetNodesByKindList_StopAtBlockingNode($try, [TryKind], [TryKind, FunctionKind, FunctionExpressionKind, ClassKind, CatchKind, FinallyKind], 1);
	
	for my $subtry (@subTry) {
		$nb_NestedTryCatches++;
		Erreurs::VIOLATION($NestedTryCatches__mnemo, "Nested try at line ".GetLine($subtry));
		checkTry($subtry);
	}
}

sub CountTryCatches($$$) {
	my ($file, $views, $compteurs) = @_ ;
    
	my $ret = 0;
	$nb_EmptyCatches = 0;
	$nb_Catch = 0;
	$nb_NestedTryCatches = 0;
	$nb_GenericCatches = 0;
  
	my $tree = $views->{'structured_code'};
  
	if ( ! defined $tree )
	{
		$ret |= Couples::counter_add($compteurs, $EmptyCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $Catch__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $NestedTryCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $GenericCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my @catches = GetNodesByKind($tree, CatchKind);
	
	$nb_Catch = scalar @catches;
	
	for my $catch (@catches) {
		my $children = GetChildren($catch);
		if (scalar @$children == 0) {
			$nb_EmptyCatches++;
			Erreurs::VIOLATION($EmptyCatches__mnemo, "Empty catch at line ".GetLine($catch));
		}
		if (${GetStatement($catch)} =~ /\b(Throwable|Exception)\b/) {
			$nb_GenericCatches++;
			Erreurs::VIOLATION($GenericCatches__mnemo, "Generic catch (on $1 type) at line ".GetLine($catch));
		}
	}
	
	my @Try = GetNodesByKindList_StopAtBlockingNode($tree, [TryKind], [TryKind], 1);
	
	for my $try (@Try) {
		checkTry($try);
	}
	
	$ret |= Couples::counter_add($compteurs, $EmptyCatches__mnemo, $nb_EmptyCatches );
	$ret |= Couples::counter_add($compteurs, $Catch__mnemo, $nb_Catch );
	$ret |= Couples::counter_add($compteurs, $NestedTryCatches__mnemo, $nb_NestedTryCatches );
	$ret |= Couples::counter_add($compteurs, $GenericCatches__mnemo, $nb_GenericCatches );
	
}
sub getElsifChain($);
sub getElsifChain($) {
	my $if = shift;
	
	my @elses;
	my $else = GetChildren($if)->[2];
	if (defined $else) {
		if (IsKind($else, ElsifKind)) {
			return [$else, @{getElsifChain($else)}];
		}
		else {
			return [$else];
		}
	}
	else {
		return [];
	}
	
}
my $level = 0;
sub getkArtifactDepth($$);
sub getkArtifactDepth($$) {
	my $artifact = shift;
	my $kinds = shift;
	$level++;
#print "ENTER getkArtifactDepth !!\n";
	my $depth = 0;
	my $id =1;
	my @subArtifacts = GetNodesByKindList_StopAtBlockingNode($artifact, $kinds, [ElsifKind, ElseKind], 1);
	for my $subArtifact (@subArtifacts) {
		if (IsKind($subArtifact, IfKind)) {
			my $elses = getElsifChain($subArtifact);
			if (scalar @$elses) {
				splice @subArtifacts, $id, scalar @$elses, @$elses;
			}
		}
#print "   "x$level ."KIND : $subArtifact->[0], at line ".(GetLine($subArtifact)||"??")."\n";
		my $artiDepth = getkArtifactDepth($subArtifact, $kinds);
#print "   "x$level ."DEPTH = $artiDepth\n";
#print "KIND : $subArtifact->[0], at line ".(GetLine($subArtifact)||"??").", DEPTH = $artiDepth\n";
		if ( $artiDepth > $depth) {
			$depth = $artiDepth;
#print  "   "x$level ."---> the deeper !!!\n";
		}
		$id++;
	}
#print "LEAVE getkArtifactDepth !!\n";
	$level--;
	return $depth+1;
}

sub CountDeepArtifact($$$) {
	my ($file, $views, $compteurs) = @_ ;
    
	my $ret = 0;
	$nb_TooDepthArtifact = 0;
  
	my $tree = $views->{'structured_code'};
	my $KindsLists = $views->{'KindsLists'};
  
	if ( ! defined $tree )
	{
		$ret |= Couples::counter_add($compteurs, $TooDepthArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $artiKinds = [IfKind, WhileKind, ForKind, WhenKind];
	
	my @artifacts = GetNodesByKindList_StopAtBlockingNode($tree, $artiKinds, [ElsifKind, ElseKind], 1);
	my $id = 1;
	my $totalDepth = 0;
	my $max = 0;
	my @depths = ();
#print "NB ARTIFACTS = ".(scalar @artifacts)."\n";
	for my $artifact (@artifacts) {
		if (IsKind($artifact, IfKind)) {
			my $elses = getElsifChain($artifact);
			if (scalar @$elses) {
				splice @artifacts, $id, 0, @$elses;
			}
		}
#print "KIND : $artifact->[0], at line ".(GetLine($artifact)||"??")."\n";
		my $depth = getkArtifactDepth($artifact, $artiKinds);
#print "DEPTH = $depth\n";
		#print "KIND : $artifact->[0], at line ".(GetLine($artifact)||"??").", DEPTH = $depth\n";
		$id++;
		
		$max = $depth if ($depth > $max);

		push @depths, $depth;
	}
	
	my ($moy, $average, $median) = Lib::CountUtils::getStatistic(\@depths);
	
	$id--;
	#if ($id) {
	#	$nb_TooDepthArtifact = int($totalDepth /$id);
	#}
	
	$nb_TooDepthArtifact = int($moy+$average+$median);
	
	Erreurs::VIOLATION($TooDepthArtifact__mnemo, "METRIC : Average artifacts depth indicator is $nb_TooDepthArtifact (max $max, average~".int($average).", median~".int($median).") for $id artifacts");
	
    $ret |= Couples::counter_add($compteurs, $TooDepthArtifact__mnemo, $nb_TooDepthArtifact );
    
    return $ret;
}

sub _cb_jumps($) {
	my $node = shift;
	my $kind = GetKind($node);
	
	if (( $kind eq ReturnKind) || ( $kind eq BreakKind) ||( $kind eq ContinueKind)) {
		if ( defined Lib::Node::GetNextSibling($node) ) {
			$nb_DeadCode++;
			Erreurs::VIOLATION($DeadCode__mnemo, "dead code after $kind at line ".GetLine($node));
		}
	}
	return undef;
}

# DESACTIVATED because does not trigger and very responsive to ...
sub CountJumps($$$) {
	my ($file, $views, $compteurs) = @_ ;
    
	my $ret = 0;
	$nb_DeadCode = 0;
  
	my $tree = $views->{'structured_code'};
  
	if ( ! defined $tree )
	{
		$ret |= Couples::counter_add($compteurs, $DeadCode__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	Lib::Node::Iterate ($tree, 0, \&_cb_jumps, undef);
	
    $ret |= Couples::counter_add($compteurs, $DeadCode__mnemo, $nb_DeadCode );
    
    return $ret;
}

sub CountVar($$$) {
	my ($file, $views, $compteurs) = @_ ;
    
    $nb_UselessTypeSpecification = 0;
    
	my $ret = 0;
  
	my $KindsLists = $views->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $UselessTypeSpecification__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadVariableNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	# init "nb_BadVariableNames" by default, but violation are updated in CountNaming ...
	$ret |= Couples::counter_add($compteurs, $BadVariableNames__mnemo, 0 );
	$ret |= Couples::counter_add($compteurs, $BadConstantNames__mnemo, 0 );
	$ret |= Couples::counter_add($compteurs, $BadAttributeNames__mnemo, 0 );
	
	my $vars = $KindsLists->{&VarKind};
	my $vals = $KindsLists->{&ValKind};
	
	my @variables = (@$vars, @$vals);
	
	for my $var (@variables) {
		
		$ret |= Kotlin::CountNaming::checkVarNaming( $var, $compteurs );
		
		my $firstChild = GetChildren($var)->[0];
		if (defined $firstChild) {
			if (IsKind($firstChild, InitKind)) {
				my $type = Lib::NodeUtil::GetXKindData($var, 'type');
				if ((defined $type) && ($type ne '')) {
					if (${GetStatement($firstChild)} =~ /^\s*(?:CHAINE_\d+|\d|[\.\+\-]\d|false\b|true\b)/m) {
						$nb_UselessTypeSpecification++;
						Erreurs::VIOLATION($UselessTypeSpecification__mnemo, "useless type specification for var at line ".GetLine($var));
					}
				}
			}
		}
	}

	$ret |= Couples::counter_add($compteurs, $UselessTypeSpecification__mnemo, $nb_UselessTypeSpecification );
}

sub CountBadSpacing($$$) {
	my ($file, $views, $compteurs) = @_ ;
    
    my $nb_BadSpacing = 0;
	my $ret = 0;
	
	my $code = \$views->{'code'};
	
	if ( ! defined $code )
	{
		$ret |= Couples::counter_add($compteurs, $BadSpacing__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	my $line = 1;
	
	# SPACE NEEDED:
	# 1) Separating any reserved word, such as if, for, or catch from an open parenthesis (() that follows it on that line
	#			(?:if|when|for|while|catch)\()
	# 2) Separating any reserved word, such as else or catch, from a closing curly brace (}) that precedes it on that line.
	#			\}\w
	# 3) Before any open curly brace ({)	
	#			[^\s]\{
	# 4) After a comma (,) or colon (:).
	#			[^:][,:][^\s:]
	# 5) Around binary operators
	#			[\w\)\]][\+\-\*\/\%]
	my $LBINOP = '[\+\*\/\%\-]';
	my $RBINOP = '[\+\*\/\%]';   # '-' removed because can be unary op for right operand.
	my $L_M_BINOP = qr/[\w\)\]]$LBINOP[ \t]*[\w\(\[]/;
	my $R_M_BINOP = qr/[\w\)\]][ \t]*$RBINOP[\w\(]/;
	# BUT NOT EXPECTED around :
	# 5) the two colons (::) of a member reference
	# 			[[:space:]]::|::[[:space:]]
	# 6) the dot separator (.) or (?.), the range operator (..)  (unless separated items are not on the same line)
	#			[[:space:]]\??\.\.?|\??\.\.?[[:space:]]
	
	# DO NOT CONSIDER binary operators because there are many case with false positive ...
	
	#while ($$code =~ /(\b(?:if|when|for|while|catch)\()|([^\s] +\??\.\.?)|(\??\.\.? +[^\s])|(\}\w)|([^\s]\{)|([^:][,:][^\s:])|( ::|:: )|($L_M_BINOP)|($R_M_BINOP)|(\n)/g) {
	while ($$code =~ /(\b(?:if|when|for|while|catch)\()|([^\s] +\??\.\.?)|(\??\.\.? +[^\s])|(\}\w)|([^\s]\{)|([^:][,:][^\s:])|( ::|:: )|(\n)/g) {
		my $msg = undef;
		if (defined $1) {
			$msg = "missing space before parenthese '$1' at line $line";
		}
		elsif ((defined $2) || (defined $3)) {
			$msg = "unexpected space around . or ?. '".($2||$3)."' at line $line";
		}
		elsif (defined $4) {
			$msg = "missing space after } '$4' at line $line";
		}
		elsif (defined $5) {
			$msg = "missing space before { '$5' at line $line";
		}
		elsif (defined $6) {
			$msg = "missing space after , or : '$6' at line $line";
		}
		elsif (defined $7) {
			$msg = "unexpected space around :: '$7' at line $line";
		}
		#elsif ((defined $8) || (defined $9)) {
		#	$msg = "unexpected space around binary operator '".($8||$9)."' at line $line";
		#}
		elsif (defined $8) {
			$line++;
		}
		$nb_BadSpacing++;
		Erreurs::VIOLATION($BadSpacing__mnemo, "Bad spacing : $msg") if defined $msg;
	}
	
	$ret |= Couples::counter_add($compteurs, $BadSpacing__mnemo, $nb_BadSpacing );
}

#sub CountDeadCode($$$){
	#my ($file, $views, $compteurs) = @_ ;
    
	#my $ret = 0;
  
	#my $KindsLists = $views->{'KindsLists'};
  
	#if ( ! defined $KindsLists )
	#{
		##$ret |= Couples::counter_add($compteurs, $UselessTypeSpecification__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		#return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	#}

	#my $returns = $KindsLists->{&ReturnKind};
	#my $continues = $KindsLists->{&ContinueKind};
	#my $breaks = $KindsLists->{&BreakKind};
	
	#my @keywords = (@$returns, @$continues, @$breaks);
	
	#for my $keyword (@keywords) {
		#my $nextSibling = Lib::Node::GetNextSibling($keyword);
		#if (defined $nextSibling) {
			#Erreurs::VIOLATION("DEAD_CODE", "dead code after line ".GetLine($keyword));
		#}
	#}

	##$ret |= Couples::counter_add($compteurs, $BadSpacing__mnemo, $nb_BadSpacing );
#}

1;




