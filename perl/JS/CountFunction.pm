package JS::CountFunction;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use JS::JSNode;
use JS::Identifiers;
use JS::JSConfig;

my $IDENTIFIER = JS::Identifiers::getIdentifiersPattern();
my $IDENT_CHAR = JS::Identifiers::getIdentifiersCharacters();

my $WithinBlocksFunctionsDecl__mnemo = Ident::Alias_WithinBlocksFunctionsDecl();
my $MisplacedFunctionDecl__mnemo = Ident::Alias_MisplacedFunctionDecl();
my $MisplacedInnerFuncDecl__mnemo = Ident::Alias_MisplacedInnerFuncDecl();
my $BadSpacingInFuncDecl__mnemo = Ident::Alias_BadSpacingInFuncDecl();
my $MissingImmediateFuncCallWrapping__mnemo = Ident::Alias_MissingImmediateFuncCallWrapping();
my $TooDepthArtifact__mnemo = Ident::Alias_TooDepthArtifact();
my $MisplacedVarStatement__mnemo = Ident::Alias_MisplacedVarStatement();
my $FunctionDeclarations__mnemo = Ident::Alias_FunctionDeclarations();
my $FunctionExpressions__mnemo = Ident::Alias_FunctionExpressions();
my $ComplexArtifact__mnemo = Ident::Alias_ComplexArtifact();

my $nb_WithinBlocksFunctionsDecl = 0;
my $nb_MisplacedFunctionDecl = 0;
my $nb_MisplacedInnerFuncDecl = 0;
my $nb_BadSpacingInFuncDecl = 0;
my $nb_MissingImmediateFuncCallWrapping = 0;
my $nb_TooDepthArtifact = 0;
my $nb_MisplacedVarStatement = 0;
my $nb_FunctionDeclarations = 0;
my $nb_FunctionExpressions = 0;
my $nb_ComplexArtifact = 0;


sub countBadSpacingInFuncDecl($) {
  my $func = shift;
#print "STATEMENT = ".${GetStatement($func)}."\n";
  ${GetStatement($func)} =~ /\b(?:function|get|set)(\s+$IDENTIFIER)?(\s*)\(?/;

  if ((defined $1) && ($2 ne '')) {
    # if there is one or more space between the name and the openning parenthesis, raise a violation.
#print "---> BadSpacing violation\n";
    return 1;
  }
  elsif ( (! defined $1) && ($2 eq '')) {
    # if it is an anonymous function and there is no space after the 'function' keyword, raise an violation.
#print "---> BadSpacing violation\n";
    return 1;
  }

  return 0;
}

sub countMisplacedInnerFuncDecl($$) {
  my $func = shift;
  my $artifactView = shift;

  #my @nodes = GetNodesByKindList_StopAtBlockingNode($func, [VarKind, FunctionDeclarationKind], [FunctionDeclarationKind, FunctionExpressionKind, ]);

  my $line = GetLine($func);
  my $name = GetName($func);
  my $artiKey = buildArtifactKeyByData($name, $line);
  my $funcArtifact = $artifactView->{$artiKey};

  my $nbFunc = 0;
  my $misplacedFunc = 0;
  while ( $funcArtifact =~ /((?:\A|[^=\(\[,:\s\|\&])\s*\bfunction\b)|(\bvar\b)/sg ) {
#  while ( $funcArtifact =~ /((?:\A|[^=\(\[,:\s\|\&])\s*\bfunction\b)|(\bvar\b)\s*([\w]+)?/sg ) {
    if (defined $2) {
      $misplacedFunc += $nbFunc;
#print "--> $nbFunc Misplaced inner functions brefore var $3\n";
      $nbFunc = 0;
    }
    else {
      $nbFunc++;
    }
  }
  return $misplacedFunc;
}

sub getNodeDepth($) ;

sub getNodeDepth($) 
{
  my $node = shift;
  my $ret = 0;

  my $Children = Lib::NodeUtil::GetChildren($node);

  my $depth = 0;
  for my $child (@{$Children}) {
    my $kind = GetKind($child);
    if (($kind ne FunctionDeclarationKind) && ($kind ne FunctionExpressionKind)) {
      my $d = getNodeDepth($child);

      if ( $d > $depth ) {
        $depth = $d;
      }
    }
  }

  my $kind = GetKind($node);
  if ( (  ($kind eq IfKind) && (! IsKind(GetParent($node), ElseKind)) ) ||
       ($kind eq DoKind) || ($kind eq ForKind) || ($kind eq WhileKind) || ($kind eq CaseKind)
	  # "else" is a child of "if" in the tree representation. So it don't introduce an
	  #  additional depth level, because they should be considered as same level than the "if" (or the then !).
	  #   || ($kind eq ElseKind)
      ) {
    $depth++;
#print "$kind ==> $depth\n";
  }
#print "NODE ".(GetKind($node))." : depth = $depth\n";
  return $depth;
}

sub hasMisplacedVar($) {
  my $node = shift;

  my $children = Lib::NodeUtil::GetChildren($node);

  my $varZone = 1;
  my $nbViol = 0;

  for my $child (@$children) {
    if (IsKind($child, VarKind)) {
#print "Var at line ".GetLine($child)."\n";
      if (!$varZone) {
        $nbViol++;
#print "---> Misplaced var\n";
	$varZone = 1;
      }
    }
    else {
      $varZone = 0;

      if ( (!IsKind($child, FunctionDeclarationKind)) &&
           (!IsKind($child, FunctionExpressionKind)) ) {
        # If the non-var statement contains block with var declared inside,
        # then all theses var are violations ...
        my @VarInSubnodes = GetNodesByKindList_StopAtBlockingNode($child, [VarKind, ForInitKind], [FunctionDeclarationKind, FunctionExpressionKind], 1);
	for my $n (@VarInSubnodes) {
	  if (IsKind($n, VarKind)) {
#print "Var at line ".GetLine($n)."\n";
            $nbViol ++;
#print "---> Misplaced var\n";
          }
	  else {
            my $stmt = GetStatement($n);
#print "COND : $$stmt\n";
	    if ($$stmt =~ /(?:\A|[^\.])\s*\bvar\b/s) {
#print "++> violation in subnodes $n->[0]\n"; 
            $nbViol ++;
	    }
	  }
        }
      }
    }
  }

  return $nbViol;
}

sub isTooDepthArtifact($) {
  my $func = shift;

  if (getNodeDepth($func) > $JS::JSConfig::ARTIFACT_MAX_DEPTH ) {
#print "TO DEPTH !!!\n";
      return 1;
  }
  return 0;
}

sub isComplexArtifact($$;$) {
  my $func = shift;
  my $ArtifactsView = shift;
  my $THRESHOLD = shift;

  if (! defined $THRESHOLD) {
    $THRESHOLD = $JS::JSConfig::ComplexArtifact__THRESHOLD;
  }

  my $ret = 0;
  my $name = GetName($func) ;

  my $content;
  if ($name eq 'root') {
    $content = $ArtifactsView->{'root'};
  }
  else {
    my $line = GetLine($func) ;
    my $artiKey = buildArtifactKeyByData($name, $line);
    $content = $ArtifactsView->{$artiKey};
  }

  if (! defined $content) {
    print "WARNING : no content for artifact $name\n";
    return 0;
  }
  # General formula is 
  #   V(g) = e-n+2
  # where e : number of transition (branches)
  #       n : number of nodes (group of instructions)
  #
  # Mc Cabe demonstrated that this can be reduced (in a single program) to :
  #   V(g) is P+1, where p is the number of decisions ...
  #
  # RQ : 
  #  1 the return instructions removes one node (n) and one transition (e) to
  #    the graph (the "return" node is merged with the final node, and its 
  #    output transition is removrd). So, it has no incidence on the complexity. 
  #  2 the goto instruction add one node (n) and one transition (e) to the graph
  #    So, it has no incidence on the complexity.

  my $p = () = $content =~ /\b(if|while|for|catch|case|\?)\b/isg;
#print "$name ==> COMPLEXITY : p = $p\n";
  if ( ($p+1) > $THRESHOLD) {
#print "    ==> TOO COMPLEX !\n";
    return 1;
  }
  else {
    return 0;
  }
}

sub CountFunction($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  sub firstChild($) {
    return Lib::NodeUtil::GetChildren(shift)->[0];
  }

  my $ret = 0;
  $nb_WithinBlocksFunctionsDecl = 0;
  $nb_MisplacedInnerFuncDecl = 0;
  $nb_BadSpacingInFuncDecl = 0;
  $nb_TooDepthArtifact = 0;
  $nb_MisplacedVarStatement = 0;
  $nb_FunctionDeclarations = 0;
  $nb_FunctionExpressions = 0;
  $nb_ComplexArtifact = 0;
  my $nb_ComplexArtifact2 = 0;
  my $nb_ComplexArtifact3 = 0;
  my $nb_ComplexArtifact4 = 0;

  my $root =  $vue->{'structured_code'} ;
  my $artifactView = $vue->{'artifact'};

  if ( ( ! defined $root ) || ( ! defined $artifactView ) )
  {
    $ret |= Couples::counter_add($compteurs, $WithinBlocksFunctionsDecl__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $MisplacedInnerFuncDecl__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $BadSpacingInFuncDecl__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $TooDepthArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $MisplacedVarStatement__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $FunctionDeclarations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $FunctionExpressions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ComplexArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  # For memo : there is two kinds of functions :
  #   - Function declaration : function that can be invoked by is name.
  #   - Function expression : function that are affected to a variable.
  
  # FUNCTION DECLARTION
  # -----------------------------------------------------------------------
  my @funcs = @{$vue->{'KindsLists'}->{'FunctionDeclaration'}};

  $nb_FunctionDeclarations += scalar @funcs;

  for my $func (@funcs) {
#print "FUNCTION : ".GetName($func)."\n";
    $nb_ComplexArtifact += isComplexArtifact($func,$artifactView);
#    $nb_ComplexArtifact2 += isComplexArtifact($func,$artifactView, 2);
#    $nb_ComplexArtifact3 += isComplexArtifact($func,$artifactView, 3);
#    $nb_ComplexArtifact4 += isComplexArtifact($func,$artifactView, 4);

    my $parent = GetParent($func);
    my $parentKind = GetKind($parent);
#print "PARENT = ".GetKind($parent)."\n";
    if ($parentKind ne RootKind) {
      if ($parentKind eq AccoKind) {
        my $granParent = GetParent($parent);
        my $granParentKind = GetKind($granParent);
#print "--> GRAN-PARENT = ".$granParentKind."\n";
        if ( ! (($granParentKind eq FunctionDeclarationKind) || ($granParentKind eq FunctionExpressionKind)) ) {
#print " -----> Violation !!!\n";
	# if the parent not root nor an accolade, then the grand-parent cannot be a function (because a function as always an accolade block as first child), then raise a violation (because it is then a non-function block))
          $nb_WithinBlocksFunctionsDecl++;
        }
      }
      else {
	# if the parent is not an accolade (so the grand-parent cannot be a function) , then raise a violation.
#print " -----> Violation !!!\n";
        $nb_WithinBlocksFunctionsDecl++;
      }
    }

    $nb_MisplacedInnerFuncDecl += countMisplacedInnerFuncDecl($func, $artifactView);
    $nb_BadSpacingInFuncDecl += countBadSpacingInFuncDecl($func);
    $nb_TooDepthArtifact += isTooDepthArtifact($func);

    # function have an "acco" level as first child, instructions of the function
    # are childs of the acco node.
    $nb_MisplacedVarStatement+= hasMisplacedVar(firstChild($func));
  }

  # FUNCTION EXPRESSION 
  # -----------------------------------------------------------------------
  @funcs = @{$vue->{'KindsLists'}->{'FunctionExpression'}};

  $nb_FunctionExpressions += scalar @funcs;

  for my $func (@funcs) {
#print "Function expression at line : ".GetLine($func)."\n";
    $nb_ComplexArtifact += isComplexArtifact($func,$artifactView);
#    $nb_ComplexArtifact2 += isComplexArtifact($func,$artifactView, 2);
#    $nb_ComplexArtifact3 += isComplexArtifact($func,$artifactView, 3);
#    $nb_ComplexArtifact4 += isComplexArtifact($func,$artifactView, 4);

    $nb_MisplacedInnerFuncDecl += countMisplacedInnerFuncDecl($func, $artifactView);

    $nb_BadSpacingInFuncDecl += countBadSpacingInFuncDecl($func);
    $nb_TooDepthArtifact += isTooDepthArtifact($func);

    # function have an "acco" level as first child, instructions of the function
    # are childs of the acco node.
    $nb_MisplacedVarStatement+= hasMisplacedVar(firstChild($func));
  }

  # ROOT ARTIFACT
  # -----------------------------------------------------------------------

  # Check if the name is 'root'. Indeed, some RootKind node are not named
  # "root" because they are virtual root node added for "unit" mode, to contain
  # the top-level functions that are the analysis unit.
  if (GetName($root) eq 'root') {
    $nb_TooDepthArtifact += isTooDepthArtifact($root);
    $nb_MisplacedVarStatement+= hasMisplacedVar($root);
    $nb_ComplexArtifact += isComplexArtifact($root,$artifactView);
#    $nb_ComplexArtifact2 += isComplexArtifact($root,$artifactView, 2);
#    $nb_ComplexArtifact3 += isComplexArtifact($root,$artifactView, 3);
#    $nb_ComplexArtifact4 += isComplexArtifact($root,$artifactView, 4);
  }


  $ret |= Couples::counter_add($compteurs, $WithinBlocksFunctionsDecl__mnemo, $nb_WithinBlocksFunctionsDecl );
  $ret |= Couples::counter_add($compteurs, $MisplacedInnerFuncDecl__mnemo, $nb_MisplacedInnerFuncDecl );
  $ret |= Couples::counter_add($compteurs, $BadSpacingInFuncDecl__mnemo, $nb_BadSpacingInFuncDecl );
  $ret |= Couples::counter_add($compteurs, $TooDepthArtifact__mnemo, $nb_TooDepthArtifact );
  $ret |= Couples::counter_add($compteurs, $MisplacedVarStatement__mnemo, $nb_MisplacedVarStatement );
  $ret |= Couples::counter_add($compteurs, $FunctionDeclarations__mnemo, $nb_FunctionDeclarations );
  $ret |= Couples::counter_add($compteurs, $FunctionExpressions__mnemo, $nb_FunctionExpressions );
  $ret |= Couples::counter_add($compteurs, $ComplexArtifact__mnemo, $nb_ComplexArtifact );
#  $ret |= Couples::counter_add($compteurs, 'Thres_2', $nb_ComplexArtifact2 );
#  $ret |= Couples::counter_add($compteurs, 'Thres_3', $nb_ComplexArtifact3 );
#  $ret |= Couples::counter_add($compteurs, 'Thres_4', $nb_ComplexArtifact4 );

  return $ret;
}

sub CountMisplacedFunctionDecl($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_MisplacedFunctionDecl = 0;

  my $root =  $vue->{'structured_code'} ;
  my $artifactView = $vue->{'artifact'};

  if ( ( ! defined $root ) || ( ! defined $artifactView ) )
  {
    $ret |= Couples::counter_add($compteurs, $WithinBlocksFunctionsDecl__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  # For memo : there is two kinds of functions :
  #   - Function declaration : function that can be invoked by is name.
  #   - Function expression : function that are affected to a variable.



  # FUNCTION DECLARED IN NAMESPACE
  my @funcs = @{$vue->{'KindsLists'}->{'FunctionDeclaration'}};

  for my $func (@funcs) {
    my $funcName = undef;

    if (${GetStatement($func)} =~ /\bfunction\s+[^(]/ ) {
      $funcName = GetName($func);
    }

    # If it is an anonymous function, then it can not be called later, so get next function.
    if (defined $funcName) {
#print "Function $funcName\n";
      my $parent = GetParent($func);
      my $parentKind = GetKind($parent);

      while ( ($parentKind ne RootKind) &&
	      ($parentKind ne FunctionDeclarationKind) &&
	      ($parentKind ne FunctionExpressionKind) ){
        $parent = GetParent($parent);
        $parentKind = GetKind($parent);
      }

      my $funcArtifact = undef;
      if ($parentKind eq RootKind) {
        $funcArtifact = \$artifactView->{'root'};
      }
      else {
        my $line = GetLine($parent);
	my $parentName = GetName($parent);
        my $artiKey = buildArtifactKeyByData($parentName, $line);
        $funcArtifact = \$artifactView->{$artiKey};
      }

      $funcName = quotemeta $funcName;
      while ($$funcArtifact =~ /([=\(,:]\s*)?(\bfunction)?\s*$funcName\s*\(/sg) {
        if (! defined $2) {
	  # if 'function' keyword is not present, then it is a call to the function.
	  $nb_MisplacedFunctionDecl++;
#print "----> Misplaced function declaration\n";
	  last;
	}
	elsif ( ! defined $1) {
          # function keyword is present ans it is not in an expression context ==> no violation.
	  last;
	}
      }
    }
  }

  $ret |= Couples::counter_add($compteurs, $MisplacedFunctionDecl__mnemo, $nb_MisplacedFunctionDecl );

  return $ret;
}


sub CountMissingImmediateFuncCallWrapping($$$) {
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_MissingImmediateFuncCallWrapping = 0;

  my $root =  $vue->{'structured_code'} ;
  my $artifactView = $vue->{'artifact'};

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $MissingImmediateFuncCallWrapping__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @calls = GetNodesByKind($root, FunctionCallKind);

  # if the function call is wrapped with parenthesis, then the call node has a parenthesis node :
  #  - as immediate parent
  #  - as immediate sibling
  #  depending on the following case :
  #     ( function () { return 0;} (call_param) ) ==> immediate parent
  #     ( function () { return 0;} ) (call_param) ==> immediate sibling
  #
  for my $call (@calls) {
#print "CALL !!!\n";
    # Get the parent node ...
    my $parent = GetParent($call);
   
    # Get the previous sibling.
    my $siblings = Lib::NodeUtil::GetChildren($parent);

    my $nb_sibling = scalar @$siblings;
    my $previous = undef;
    my $call_found = 0;

    for (my $i=0; $i<$nb_sibling; $i++) {
      if ($siblings->[$i] == $call) {
        $call_found = 1;
        last;
      }
      $previous = $siblings->[$i];
    }
    

    if ((defined $previous) && (IsKind($previous, FunctionExpressionKind))) {
      if ((IsKind($parent, ParenthesisKind)) || (IsKind($parent, FunctionCallKind))) {
	# the call concerns a function expression that is inside parenthesises ...
        my $stmt = GetStatement($parent);
#print "--->stmt = $$stmt \n";
        # ... check if the function expression is at beginning of the parenthesis ...
	my $tag = JS::JSNode::nodeTag($previous);
	if ($$stmt !~ /\A\s*$tag/) {
          $nb_MissingImmediateFuncCallWrapping++;
#print " -----> Violation\n";
	}
      }
      else {
	# the call concerns a function expression that is not inside parenthesises : violation !!
        $nb_MissingImmediateFuncCallWrapping++;
#print " -----> Violation\n";
      }
    }
  }

  $ret |= Couples::counter_add($compteurs, $MissingImmediateFuncCallWrapping__mnemo, $nb_MissingImmediateFuncCallWrapping );

  return $ret;
}



1;
