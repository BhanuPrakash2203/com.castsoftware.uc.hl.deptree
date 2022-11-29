package ObjC::ParseObjCPass2;
# les modules importes
use strict;
use warnings;

use Erreurs;

use CountUtil;
use ObjC::Ternary;

use Lib::Node qw( Leaf Node Append );
use Lib::ParseUtil;

use ObjC::ObjCNode ;
use ObjC::ObjCNode qw( SetName SetStatement SetLine GetLine); 
use ObjC::ParseObjC;

############################################################################
#    parse FUNCTION CALLS
############################################################################

my $CallID = 0;
sub getCallID() {
  return $CallID++;
}

sub containsCall($) {
  my $stmt = shift;

  # return true if AT LEAST ONE openning bracket :
  #    - is not preceded by an indentifier or a closing parenthesis
  #    - or is preceded by 'return' or 'exit'
  #
  #    ex : tab[0], (*ptr)[0] are not calls
  #         return tab[0] is not a call
  #         return [ obj meth] is a call.

  if ( $$stmt =~ /(?:\A|(?:[^\w\)\s]|\breturn\b|\bexit\b))\s*\[/) {
    return 1;
  }
  return 0;
}

sub isNextBacketCall($) {
  my $stmt = shift;

  # return true if THE NEXT openning bracket :
  #    - is preceded by nothing or blanks
  #    - is not preceded by an indentifier (last char matches \w) 
  #      or a closing parenthesis, or a opening/closing bracket.
  #    - or is preceded by 'return' or 'exit'
  
  if ( $$stmt =~ /(?:\A|\A[^\[]*(?:[^\w\)\s\]\[]|\breturn\b|\bexit\b))\s*\[/) {
    return 1;
  }
  return 0;
}

sub parseCall($);

sub parseCall($) {
  my $InStmt = shift;

  # A call content can contain severall others calls. So, create a list to group
  # corresponding call nodes.
  my @CallNodes = ();
  my $s = "";
  my $OutputStmt = \$s;

  my $r_toAnalyse = $InStmt;

#  if (containsCall($InStmt)) {
#print "Input Statement ==> $$InStmt\n";
#    while ($$r_toAnalyse =~ /\[/s) {
    while (containsCall($r_toAnalyse)) {
  
      # While the next [ is a tab index operator, consume it without doing anything ...
      while ( ($$r_toAnalyse =~ /\[/s) && (! isNextBacketCall($r_toAnalyse))) {
	# remove all tat is before the call from the buffer to analyze, and
	# concat it to the OutputStmt.
        $$r_toAnalyse =~ /^([^\[]*\[[^\[]*)(.*)/sm;
        $$OutputStmt .= $1;
        $$r_toAnalyse = $2;
      }

      # Create each call node of the input statement statement.
      my $node = Node(CallKind, \$Lib::ParseUtil::NullString);
      my $name = "CALL".getCallID();
      SetName($node, $name);
  
      # Split the statement being parsed after the first call closing bracket.
      # The first part will be analysed in this iteration.
      # The second part will be analysed in the next iteration. 
      my $r_call_part;
#print "PARSE CALL : $$r_toAnalyse\n";
      ($r_call_part, $r_toAnalyse) = CountUtil::splitAtPeer($r_toAnalyse, '[', ']');
  
      # Analyse the call: extract what is before the "call" ans what is "inside".
      my ($InstrStmt, $callContent);
      if (defined $r_call_part) {
      #FIXME : $InstrStmt should be empty because removed earlier ...
      #        This treatment could be reduced to removing brackets ...
        ($InstrStmt, $callContent) = $$r_call_part =~ /^([^\[]*)\[(.*)\]/sm ;
      }
      else {
        print "Parse ERROR : encountered while parsing calls ...\n";
	return ([], $OutputStmt);
      }
  
      # Consider what is inside the "call" brackets as a new statement to be parsed against
      # eventual sub-calls... and so on ...
      my ($r_callNode, $r_stmt) = parseCall(\$callContent);
      SetStatement($node, $r_stmt);
#print "CALL STATEMENT : $$r_stmt !!!\n";
  
      #FIXME : $InstrStmt should be empty because removed earlier ...
      $$OutputStmt .= $InstrStmt."[".$name."]";
  
      for my $subNode (@{$r_callNode}) {
        Append($node, $subNode);
      }
      push @CallNodes, $node;
    }
    # concat the rest (that has not been analysed because containing no call).
    $$OutputStmt .= $$r_toAnalyse;
#print "Output Statement ==> $$OutputStmt\n";
#  }
#  else {
#    $OutputStmt = $InStmt;
#  }
  
  # return : 
  #   - the list of nodes corresponding to the calls contained in the instruction
  #   - the modified statement where each call is replaced by a uniq ident.
  return (\@CallNodes, $OutputStmt);
}

sub _cbparseCall($$)
{
  my ($node, $context) = @_;

  if (IsKind($node, CallKind)) {
    # do not analyze statement, and tell iterator do not analyzed subnodes ...
    return 0;
  }

  my $stmt = GetStatement($node); 
#print "ANALYZING : $$stmt\n";
  if (defined $stmt) {
    if (containsCall($stmt)) {
#print "------> contains call !!!\n";
      my ($r_callNode, $r_SimplifiedStatement) = parseCall($stmt);

      # if the current node contains only the call statement, ...
      if ((scalar @{$r_callNode} == 1) && ($$r_SimplifiedStatement =~ /^\s*\[\w+\]\s*$/sm)) {

        # RQ : $r_callNode->[0] is the uniq call node found, that is a
	# prerequisite for this context.

        # replace current node by the call node.
	# ---------------------------------------
	Lib::Node::ReplaceNodeContent($node, $r_callNode->[0]);
      }
      # else append the call node to the current node.
      # ------------------------------------------------
      else {
        for my $subNode (@{$r_callNode}) {
  	  Append($node, $subNode);
        }
#print "SIMPLIFIED = $$r_SimplifiedStatement\n";
        SetStatement($node, $r_SimplifiedStatement);
      }
    }
  }


  # no order to not go inside children.
  return undef;
}

sub parseAllCall($) {
  my $root = shift;

  my @context = ();
  Lib::Node::Iterate($root, 0, \&_cbparseCall, \@context );
}

# Search the first node that uses a given pattern in its statement...
sub getNodeUsingPattern($$);
sub getNodeUsingPattern($$)
{
  my $root = shift;
  my $r_pattern = shift;

#print "SCANNING : ".${GetStatement($root)}."\n";
  if ( ${GetStatement($root)} =~ /$$r_pattern/ ) {
#print "---> found $$r_pattern\n";
     return $root;
  }
    
  my $children = Lib::Node::GetSubBloc($root);
  foreach my $node ( @{$children} )
  {
    my $foundNode = getNodeUsingPattern($node, $r_pattern);
    if (defined $foundNode) {
#print "---> Node found in child\n";
      return $foundNode;
    }
  }

  return undef;
}

# when an instruction caontains a call, the call is replaced in the statement by a tag, 
# and the node of the instruction has the node of the call as child.
#    ex :      a = [ myObj myMeth];
#    The statement of the node of the instruction is "a = [CALL0]", and a child node is
#    added, whose name is "CALL0", and whose statement is "myObj myMeth".
#
#    But Sometimes, due to block parsing in second pass, the call node is badly placed.
#    The aim of this function is then to search the instruction that uses a call, and
#    deplace the call if needed.
sub arrangeCalls($);
sub arrangeCalls($)
{
  my $node = shift;
  my $newParent = undef;

  if (IsKind($node, CallKind)) {
    my $name = GetName($node);
    my $parent = GetParent($node);

#print "TREATING CALL ($node) $name\n";
    # If the parent statement does not use the call statement, then find it in children...
    if ( ${GetStatement($parent)} !~ /\[$name\]/s ) {

      # for each child ...
      for my $child (@{Lib::Node::GetSubBloc($parent)}) {
	#if ($child != $node) {
	  my $pattern = '\['.$name.'\]';
	  # search the one that use the call pattern (it is the real parent of the $node)...
#print "SEARCHING FOR $pattern\n";
          $newParent = getNodeUsingPattern($child, \$pattern);
        #}
      }
    }
else {
#print "---> found in statement ($parent) : ".${GetStatement($parent)}."\n";
}
  }

  # Arrange calls in all children.
  my $children = Lib::Node::GetSubBloc($node);
  my @adoptList = ();
  foreach my $child ( @{$children} )
  {
    my $np = arrangeCalls($child);

    if (defined $np) {
      push @adoptList, [$np, $child];
    }
  }

  # If some calls are to be arranged, then do this ...
  for my $couple (@adoptList) {
      # if the "new parent" node is a pure call instruction ...
      if ((${GetStatement($couple->[0])} =~ /^\s*\[\w+\]\s*$/sm)) {
	# ... then the new parent node and the child (call) node are the same node...
	# first : detach the "child" node from its previous parents
	Lib::Node::Detach($couple->[1]);
	# second : replace "new parent" node with the content of the "child" ..
	Lib::Node::ReplaceNodeContent($couple->[0], $couple->[1]);
      }
      else {
	# ... the "new parent" node adopt the call node.
	Lib::Node::Adopt($couple->[0], $couple->[1]);
      }
  }

  # Return the real parent of the call (i.e. the node whose statement is using the
  # call !)
  return $newParent;
}

################################################################################
#              BLOCK
################################################################################

# Strategy elements :
#
# 1) Block definitions should be parsed in pass 1, because the "{" they contain are structural.



my $BlockID = 0;
sub getBlockID() {
  return $BlockID++;
}

sub parseBlockBody() {

  # trashes the '{' that begins the list of attributes.
  getNextStatement();

  ObjC::ParseObjC::pushScope(ObjC::ParseObjC::OBJC_FUNCTION_SCOPE());

  my $possibleContent = [ \&ObjC::ParseObjC::parseStatement ];
  my $attrib = Lib::ParseUtil::parseCodeBloc(AccoladeKind, [ \&Lib::ParseUtil::isNextClosingCurlyBrace ], $possibleContent, 0);

  ObjC::ParseObjC::popScope();

  return $attrib;
}

# This function is used in first pass for blocks that are not in between [] or () ...
# -------------------------------------------------------------------------------------
sub parseBlock(;$) {
   my $r_stmt = shift;

  # block prototype pattern :    ^type(param1, ... , paramN) {
  if ( (${nextStatement()} =~ /\{/) && ( defined $r_stmt ) &&
       ( $$r_stmt =~ /(.*)(\^\s*(?:\w+)?\s*(?:\([^()]*\))?\s*)$/sm) ) {

    # instruction containing the block.
    my $instr = $1."__BLOCK__".getBlockID();
    my $blockProto = $2;

    # create the Block node.
    my $node = Node(BlockKind, \$blockProto);
    Append($node, parseBlockBody());

    # a block is declared inside an instruction, then create the node corresponding
    # to this instruction.
    my $instrNode = Node(FixmeKind, \$instr);
    Append($instrNode, $node);
    return $instrNode;
  }
  return undef;
}


sub containsBlock($) {
  my $stmt = shift;

  # return true if the statement contains a block definition pattern :
  #
  #           ^type(param1, ... , paramN) {....}
  #
  #
  if ( $$stmt =~ /(.*)(\^\s*(?:\w+)?\s*(?:\([^()]*\))?\s*)(?:$|\{)/sm) {
#print "        --> contains a bloc definition.\n";
    return 1;
  }
  return 0;
}

sub parseBlocks($$) {
   my $stmt = shift;
   my $line = shift;

   my @blockNodes = ();
   my $toParse = $$stmt;
   my $simplified = "";

   while ($toParse =~ /(.*?)(\^\s*(?:\w+)?\s*(?:\([^()]*\))?\s*)(\{.*)/sm) {
     my $before = $1;
     my $blockProto = $2;
     my $blockBodyPart = $3;

     my ($body, $after) = CountUtil::splitAtPeer(\$blockBodyPart, '{', '}');

     # Tokenize the block body definition
     my $statements = ObjC::ParseObjC::splitObjC($body);
     Lib::ParseUtil::initStatementManager($statements);
     Lib::ParseUtil::setStatementLine($line);

     # create the block node
     my $blockNode = Node(BlockKind, \$blockProto);
     push @blockNodes, $blockNode;
     # Parse the block bosy statements 
     Append($blockNode, parseBlockBody());

     # Create the simplified statement
     $simplified .= $before."__BLOCK__".getBlockID();
     $toParse = $simplified.$$after;
   }

#print "SIMPLIFIED = $toParse\n";
   return (\@blockNodes, \$toParse)

}

sub _cbparseBlock($$)
{
  my ($node, $context) = @_;

  # Do not parse the statement if it is already recognized as a block.
  if ( !IsKind($node, BlockKind)) {

    my $stmt = GetStatement($node); 
    my $line = GetLine($node);

    if (defined $stmt) {
#print "STATEMENT = $$stmt\n";
      if (containsBlock($stmt)) {

        my ($r_blockNodes, $r_SimplifiedStatement) = parseBlocks($stmt, $line);

        # append the block node to the current node.
        # ------------------------------------------------
        for my $subNode (@{$r_blockNodes}) {
          Append($node, $subNode);
        }
        SetStatement($node, $r_SimplifiedStatement);
      }
    }
  }

  # no order to not go inside children.
  return undef;
}


sub parseAllBlocks($) {
  my $root = shift;

  my @context = ();
  Lib::Node::Iterate($root, 0, \&_cbparseBlock, \@context );

  arrangeCalls($root);

}

################################################################################
#              INITIALISATTION
################################################################################

sub init() {
  $CallID = 0;
  $BlockID = 0;
}

1;
