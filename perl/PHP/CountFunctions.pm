package PHP::CountFunctions;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use PHP::PHPNode;

use PHP::PHPConfig;

my $UnusedParameters__mnemo = Ident::Alias_UnusedParameters();
my $ComplexArtifact__mnemo = Ident::Alias_ComplexArtifact();
my $BadFunctionNames__mnemo = Ident::Alias_BadFunctionNames();
my $TooDepthArtifact__mnemo = Ident::Alias_TooDepthArtifact();

my $nb_UnusedParameters = 0;
my $nb_ComplexArtifact = 0;
my $nb_BadFunctionNames = 0;
my $nb_TooDepthArtifact = 0;

sub IsComplexArtifact($$) 
{
  my $artifact = shift;
  my $ArtifactsView = shift ;
  my $ret = 0;
  my $name = GetName($artifact) ;

  my $artiKey = buildArtifactKeyByNode($artifact);

  my $content = $ArtifactsView->{$artiKey};

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

  my $p = () = $content =~ /\b(if|elseif|while|for|foreach|catch|case)\b/isg;
#print "COMPLEXITY : p = $p\n";
  if ( ($p+1) > $PHP::PHPConfig::ComplexArtifact__THRESHOLD) {
    return 1;
  }
  else {
    return 0;
  }
} 

sub countUnusedParameters($$) {
  my $func = shift ;
  my $vue = shift ; 

  my $nb_Violations = 0;

  my $line = GetLine($func);
  my $name = GetName($func);
  my $artiKey = buildArtifactKeyByData($name, $line);

  my $artifactView = $vue->{'artifact'};
  my $HStrings = $vue->{HString};

#print "-------------\n";
#print "ARTIKEY = $artiKey\n";
#print "BODY = ".$artifactView->{$artiKey}."\n";

#print "ARTIFACT : \n".$artifactView->{$artiKey}."\n";

  #my $funcContent = PHP::PHPNode::GetChildren(PHP::PHPNode::GetChildren($func)->[0]); 
  #if ( scalar @{$funcContent} == 0) {
  #  return 0;
  #}

  # check if the first instruction is a throw or a return :
  # get the list of instructions in the function :
  # PHP::PHPNode::GetChildren($func)->[0] is the bloc node that contains the children of
  # the function.
  my $firstInstr = PHP::PHPNode::GetChildren(PHP::PHPNode::GetChildren($func)->[0])->[0];

  # If the function's body is empty, then no violation.
  if (IsKind($firstInstr, EmptyKind)) {
    return 0;
  }

  # If the first instruction is a "throw", then it is not a violation
  if (IsKind($firstInstr, ThrowKind)) {
    return 0;
  }
  
  # If the first instruction is a "return", then it is not a violation (except for the limitation below)
  if (IsKind($firstInstr, ReturnKind)) {
    my $stmt = GetStatement($firstInstr);

    # Test is to take into account a limitation of the exception in CodeSniffer
    if ( $$stmt =~ /\breturn \$?\w+\s*$/) {
      return 0;
    }
  }

  my @parameters = ();

  if (${GetStatement($func)} =~ /^[^\(\)]*\((.*)\)[^\(\)]*$/sm ) {
     @parameters = split ",", $1;
  }

  for my $param (@parameters) {
    my ($pname) = $param =~ /^\s*\$(\w+).*/s;

    if (defined $pname) {
      if ( $artifactView->{$artiKey} !~ /\b${pname}\b/s ) {

        # Search in the strings
	my $found = 0;

	# For each string contained in the body of the functions :
	while ($artifactView->{$artiKey} =~ /\b(CHAINE_\d+)/sg) {
          my $str = $HStrings->{$1};
	  if ($str =~ /\$\{?$pname/s) {
            $found++;
	  }
	}

        if (!$found) {
          $nb_Violations++;
#print "FUNCTION $name --> UNUSED PARAM : $pname\n";
        }
      }
    }
  }
  return $nb_Violations;
}


sub getNodeDepth($) ;

sub getNodeDepth($) 
{
  my $node = shift;
  my $ret = 0;

  my $Children = PHP::PHPNode::GetChildren($node);

  my $depth = 0;
  for my $child (@{$Children}) {
    my $d = getNodeDepth($child);
    if ( $d > $depth ) {
      $depth = $d;
    }
  }

  my $kind = PHP::PHPNode::GetKind($node);
  if ( ($kind eq IfKind) || ($kind eq DoKind) || ($kind eq ForKind) || ($kind eq WhileKind) || ($kind eq ForeachKind) || ($kind eq CaseKind)
	  # "elsif" & "else" are child of "if" in the tree representation. So they don't introduce an
	  #  additional depth level, because they should be considered as same level than the "if".
	  #  || ($kind eq ElsifKind) || ($kind eq ElseKind)
      ) {
    $depth++;
  }

  return $depth;
}


sub CountFunctions($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_UnusedParameters = 0;
  $nb_ComplexArtifact = 0;
  $nb_BadFunctionNames = 0;
  $nb_TooDepthArtifact = 0;


  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ComplexArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $BadFunctionNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $TooDepthArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my $artifactView = $vue->{'artifact'};

  my @Funcs = GetNodesByKind( $root, FunctionKind);
  my $nb_FunctionDeclarations = scalar @Funcs;

  for my $func (@Funcs) {

    $nb_UnusedParameters += countUnusedParameters($func, $vue);

    $nb_ComplexArtifact += IsComplexArtifact($func, $artifactView);

    my $name = GetName($func);

    if ( $name =~ /\A[A-Z].*_/ ) {
      $nb_BadFunctionNames++;
    }

    if (getNodeDepth($func) > $PHP::PHPConfig::ARTIFACT_MAX_DEPTH ) {
        $nb_TooDepthArtifact ++;
    }

  }



  $ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, $nb_UnusedParameters );
  $ret |= Couples::counter_add($compteurs, $ComplexArtifact__mnemo, $nb_ComplexArtifact );
  $ret |= Couples::counter_add($compteurs, $BadFunctionNames__mnemo, $nb_BadFunctionNames );
  $ret |= Couples::counter_add($compteurs, $TooDepthArtifact__mnemo, $nb_TooDepthArtifact );
  $ret |= Couples::counter_add($compteurs, Ident::Alias_FunctionImplementations(), $nb_FunctionDeclarations );

  return $ret;
}


1;
