package ObjC::Ternary;

use strict;
use warnings;

use Lib::Node qw( Leaf Node Append );
use Lib::ParseUtil;

use ObjC::ObjCNode ;
use ObjC::ObjCNode qw( SetName SetStatement SetLine GetLine); 

my $NullString = '';

my $TernaryID = 0;
sub getTernaryID() {
  return $TernaryID++;
}

sub containsTernary($) {
  my $stmt = shift;

  # return true if the statement contains at least one "?"

  if ( $$stmt =~ /\?/) {
    return 1;
  }
  return 0;
}

sub splitAtCharWithParenthesisMatching($$) {
  my $stmt = shift;
  my $CharTab = shift;

  my $left = "";
  my $right = undef ;

  my $nbParenthesisOpenned = 0;
  my $nbBracketOpenned = 0;

  my $chars = join('', @$CharTab);
  my $regStop = '['.$chars.']';

  while ( $$stmt =~ /(.)/sg) {
    my $char = $1;
    if (!defined $right) {
      if ($char eq "[") {
        $nbBracketOpenned++;
      }
      elsif ($char eq "(") {
        $nbParenthesisOpenned++;
      }
      elsif ($char eq "]") {
        $nbBracketOpenned--;
      }
      elsif ($char eq ")") {
        $nbParenthesisOpenned--;
      }

      if (($nbBracketOpenned<=0) && ($nbParenthesisOpenned<=0)) {
            if ( $char =~ /$regStop/s) {
	      $right = "";
	    }
      }
    }

    if ( ! defined $right) {
      $left .= $char;
    }
    else {
      $right .= $char;
    }
  }

  if (!defined $right) {
    $right = "";
  }

  return (\$left, \$right);
}

sub backsplitAtCharWithParenthesisMatching($$$;$) {
  my $stmt = shift;
  my $CharTab = shift;
  my $includeStopping = shift;
  my $offset = shift;

  if (!defined $offset) {
    $offset = 0;
  }

  my $regStop;
  if (! scalar @$CharTab) {
    # Stop on any character.
    $regStop = '.';
  }
  else {
    $regStop = "[".join('', @$CharTab)."]";
  }

  my $left = undef;
  my $right = "" ;

  my $nbParenthesisOpenned = 0;
  my $nbBracketOpenned = 0;

  my $nmax = (length $$stmt) - 1;

  my $n = $nmax-$offset;

  while ( $n > 0 ) {
    my $char = substr($$stmt, $n, 1);

      if ($char eq "]") {
        $nbBracketOpenned++;
      }
      elsif ($char eq ")") {
        $nbParenthesisOpenned++;
      }
      elsif ($char eq "[") {
        $nbBracketOpenned--;
      }
      elsif ($char eq "(") {
        $nbParenthesisOpenned--;
      }

      if (($char =~ /$regStop/) && ($nbBracketOpenned<=0) && ($nbParenthesisOpenned<=0))
      {
      	  last;   
      }

    $n--;
  }

#  print "offset = $offset\n";
#  print "nmax = $nmax\n";
#  print "n = $n\n";

  # $includeClosing signifies that the stopping char is affected to the right !
  if ($includeStopping ){
    $left = substr($$stmt, 0, $n);
    $right = substr($$stmt, $n, $nmax-$n+1+$offset);
  }
  else {
    $left = substr($$stmt, 0, $n+1);
    $right = substr($$stmt, $n+1, $nmax-$n+$offset);
  }

#  print "left = $left \n";
#  print "right = $right \n";

  return (\$left, \$right);
}



sub splitAtBeginOfTernary($) {
  my $stmt = shift;

  #my ($cond, $then_else) = splitAtCharWithParenthesisMatching($stmt, ['?']);
  my ($cond, $then_else);
  ($$cond, $$then_else) = $$stmt =~ /\A([^?]*)(.*)/s;

  if ($$then_else eq "") {
    # "?" not found !
    return ( $stmt, undef);
  }
  
  my $before;

  if ($$cond =~ /\)(\s*)$/)
  {
    # because any character can be a stopping one, all blanks between the closing
    #  parenthesis and the end of the condition buffer should be ignored.
    #($before, $cond)=backsplitAtCharWithParenthesisMatching($cond, [], 0, length $1);
    ($before, $cond)=CountUtil::backsplitAtPeer($cond, '(', ')');
  }
  else
  {
    # We consider that a ternary begin after '(', ':', '?', '=' unless they
    # are enclosed in parenthesis
    # examples :
    #   a = b ? c ? d      ternary = b ? c ? d
    #   if (a <= b ? c ? d)  ternary = b ? c ? d
    #   if ((a == b) ? c ? d)  ternary = (a == b) ? c ? d
    #   if (a == b ? c ? d)  ternary =  b ? c ? d
    #   if (a < b ? c ? d)  ternary =  a < b ? c ? d
    #   a = [Obj param : b ? c : d]    ternary = b ? c ? d
    #   a = fc(0, b ? c : d)  ternary = b ? c ? d
    ($before, $cond)=backsplitAtCharWithParenthesisMatching($cond, ['(', ':', ',', '?', '='], 0);
  }

  # re build the entire ternary expression ...
  $$cond .= $$then_else;
  
  return ($before, $cond);
}

sub splitAtEndOfTernary($) {
  my $stmt = shift;

  my ($ternaryPart, $rest);
  ($$ternaryPart, $$rest) = $$stmt =~ /\A([^?]*)(.*)/s;

  if ($$rest eq "") {
    # "?" not found !
    return (undef, $stmt);
  }

  my $addToTernPart;
  ($addToTernPart, $rest) = splitAtCharWithParenthesisMatching($rest, [':']);
  $$ternaryPart .= $$addToTernPart;

  if ($$rest eq "") {
    # ":" not found !
    return (undef, $stmt);
  }

  # We consider that a ternary in an isolated instruction ends with the
  # following item, except if they are enclosed in parenthesis: ')', ']', ','
  ($addToTernPart, $rest) = splitAtCharWithParenthesisMatching($rest, [')', '\]', ',']);
  $$ternaryPart .= $$addToTernPart;

  return ($ternaryPart, $rest);
}


sub buildTernaryNode($$) {
  my $node = shift;
  my $content = shift;

  my ($cond, $thenElse) = $$content =~ /\A([^?]*)\?(.*)/s;

  Append($node, Node(CondKind, \$cond));
  Append($node, Node(TernaryThenElseKind, \$thenElse));
}

sub parseTernary($);

sub parseTernary($) {
  my $InStmt = shift;

  # A Ternary content can contain severall others ternaries. So, create a list to group
  # corresponding call nodes.
  my @TernaryNodes = ();
  my $s = "";
  my $OutputStmt = \$s;

  my $r_toAnalyse = $InStmt;

#  if (containsCall($InStmt)) {
#print "Input Statement ==> $$InStmt\n";
#    while ($$r_toAnalyse =~ /\[/s) {
    while (containsTernary($r_toAnalyse)) {
  
      # Create each ternary node of the input statement statement.
      my $node = Node(TernaryKind, \$NullString);
      my $name = "TERNARY".getTernaryID();
      SetName($node, $name);
  
      # Split the statement being parsed at the end of the ternary structure.
      #   The first part will be analysed in this iteration.
      #   The second part will be analysed in the next iteration. 
      my $r_ternary_part;
#print "PARSE TERNARY : $$r_toAnalyse\n";
      ($r_ternary_part, $r_toAnalyse) = splitAtEndOfTernary($r_toAnalyse);
  
      # Analyse the ternary: extract what is before the "ternary" ans what is "inside".
      my ($InstrStmt, $ternaryContent);
      if (defined $r_ternary_part) {
      #FIXME : $InstrStmt should be empty because removed earlier ...
        ($InstrStmt, $ternaryContent) = splitAtBeginOfTernary($r_ternary_part) ;
      }
      else {
        print "Parse ERROR : encountered while parsing ternaries ...\n";
	return ([], $OutputStmt);
      }
  
      #FIXME : $InstrStmt should be empty because removed earlier ...
      $$OutputStmt .= $$InstrStmt.$name;
  
      buildTernaryNode($node, $ternaryContent);

      push @TernaryNodes, $node;
    }
    # concat the rest (that has not been analysed because containing no call).
    $$OutputStmt .= $$r_toAnalyse;
#print "Output Statement ==> $$OutputStmt\n";
#  }
#  else {
#    $OutputStmt = $InStmt;
#  }
  
#print "NEW STATEMENT : $$OutputStmt\n";
  # return : 
  #   - the list of nodes corresponding to the ternaries contained in the instruction
  #   - the modified statement where each call is replaced by a uniq ident.
  return (\@TernaryNodes, $OutputStmt);
}


sub _cbparseTernaryOp($$)
{
  my ($node, $context) = @_;

  if (IsKind($node, TernaryKind)) {
    # do not analyze statement, and tell iterator do not analyzed subnodes ...
    return 0;
  }

  my $stmt = GetStatement($node); 

  if (defined $stmt) {
    if (containsTernary($stmt)) {
#print "\n***** NODE WITH TERNARY : $$stmt !!!\n";
      my ($r_callNode, $r_SimplifiedStatement) = parseTernary($stmt);

        for my $subNode (@{$r_callNode}) {
  	  Append($node, $subNode);
        }
        SetStatement($node, $r_SimplifiedStatement);
    }
  }

  # no order to not go inside children.
  return undef;
}


sub parseAllTernaryOp($) {
  my $root = shift;

  my @context = ();
  Lib::Node::Iterate($root, 0, \&_cbparseTernaryOp, \@context );
}

1;
