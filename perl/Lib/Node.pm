
package Lib::Node ;

use strict;
use warnings;

use Exporter 'import'; # gives you Exporter’s import() method directly

our @EXPORT_OK = qw( Leaf GetNextSibling );  # symbols to export on request

our @EXPORT = qw(Node Append UnknowKind createEmptyStringRef ExtractAddnode ReplaceNodeContent);  # symbols to export on request


# common kind to all languages.
use constant UnknowKind       => 'unk'; 

sub createEmptyStringRef() {
  my $s = "";
  return \$s;
}


sub Leaf($$)
{
  my ($kind, $stmt) = @_;
  my @node = ($kind, $stmt, undef );
  return \@node;
}

# Structure of a node :
# [0] --> kind
# [1] --> statement
# [2] --> list of sub blocs
# [3] --> parent
# [4] --> name
# [5] --> beginning line
# [6] --> end line
# [7] --> DATA : free for each analyzer.
sub Node($$;$)
{
  my ($kind, $stmt, $sub_bloc) = @_;
  if ( not defined $sub_bloc )
  {
    my @empty = ();
    $sub_bloc = \@empty ;
  }
  my @node = ($kind, $stmt, $sub_bloc );
  return \@node;
}


sub GetNextSibling($) {
  my $node = shift;

  if (defined $node->[3]) {
    my $parent = $node->[3];
    my $idx=0;
    for my $sibling ( @{$parent->[2]} ) {
      $idx++;
      if ($sibling == $node) {
        last;
      }
    }
    if (defined $parent->[2]->[$idx]) {
      return $parent->[2]->[$idx];
    }
  }
  return undef;
}

sub GetPreviousSibling($) {
  my $node = shift;

  if (defined $node->[3]) {
    my $parent = $node->[3];
    my $idx=0;
    for my $sibling ( @{$parent->[2]} ) {
      if ($sibling == $node) {
        last;
      }
      $idx++;  
    }
    
    if ($idx > 0) {
	  # the node is node the first child. So return his previous sibling.
      return $parent->[2]->[$idx-1];
    }
  }
  return undef;
}

sub DuplicateNode($)
{
  my ($Node) = @_;
  my @Double = @{$Node};
  return \@Double;
}

sub SetParent($$) {
  $_[0]->[3] = $_[1];
}

sub ExtractAddnode($) {
  my $node = shift;
  my $data = $node->[7];
  if ( (defined $data) and (ref $data eq "HASH") and (defined (my $subNodes = $data->{'addnode'})) ) {
    delete $data->{'addnode'};
    return $subNodes;
  }
  return [];
}

sub Append($$)
{
  my ($node, $subnode) = @_;
  my $bloc = $node->[2];
  
  $subnode->[3] = $node ;   # for a back walk ...
  push @{$bloc}, $subnode;
  
  # additionnal data
  my $data = $subnode->[7];
  
  if ( (defined $data) and (ref $data eq "HASH") and (defined ($data = $data->{'addnode'})) ) {
	  # Sometime the parser need to create several consecutives nodes when
	  # parsing a statement, but parse function cannot return a list of nodes.
	  # So the first node is return and the following are attached in the 'addnode' field.
	  # It's the Append() job to add them to the parent.
	  for my $addnode (@$data) {
		  push @{$bloc}, $addnode;
		  $addnode->[3] = $node ;  # attach parent !
	  }
	  delete $subnode->[7]->{'addnode'};
  }
}

sub AddSubNodes($$) {
	# $_[0] -> parent
	# $_[1] -> subNodes list
	for my $subNode (@{$_[1]}) {
		Append($_[0], $subNode);
	}
}

sub Detach($) {
  my $node = shift;

  my $i =  0;
  my $children_list = $node->[3]->[2];
  for my $ch (@{$children_list}) {
    if ($ch == $node) {
      last;
    }
    $i++;
  }
  if ($i < scalar @{$children_list}) {
    splice (@{$children_list}, $i, 1);
  }

}

sub Adopt($$) {
  my $parent = shift;
  my $child = shift;

  # remove from the children list of previous parents
  Detach($child);

  # append to new parent
  Append($parent, $child);
}

sub ReplaceNodeContent($$) {
  my $old = shift;
  my $new = shift;

  my $idx = 0;

  # parent of the old node is now the parent of the new node
  $new->[3] = $old->[3];

  # copy call node fields into old node. So all references to old node will
  # apply to the new node.
  for my $field (@{$new}) {
    $old->[$idx] = $new->[$idx];
    $idx++;
  }

  # As we copied the content of the block node in the current node,
  # the parent of the children of the bloc node are now the current node !!!
  for my $child (@{$old->[2]}) {
    $child->[3] = $old;
  }
}


sub RemoveChildren($)
{
  my ($node) = @_;
  if (defined $node->[2]) # S'il s'agit d'un noeud et non d'une feuille
  {
    my @empty = ();
    $node->[2] = \@empty;
  }
}

sub GetSubBloc($)
{	
  return $_[0]->[2]; # Version optimisee.

  # Version en clair:
  #my ($item) =@_;
  #my ($kind, $stmt, $sub_bloc) = @{$item} ;
  #return $sub_bloc;
}

sub GetChildren($)
{
  return $_[0]->[2];
}

sub ForEachDirectChild($$$)
{
  my ($baseNode, $callback, $userContext) = @_;
  my $bloc = GetSubBloc($baseNode);
  for my $node ( @{$bloc} )
  {
    $callback->( $node, $userContext );
  }
}

# Declaration prealable des fonctions recursives.
sub Iterate($$$$);

sub Iterate($$$$)
{
  my ($baseNode, $level, $callback, $context) = @_;
  my $bloc = GetSubBloc($baseNode);
  foreach my $node ( @{$bloc} )
  {
    my $order = $callback->( $node, $context, $level );

    # order is 
    # - undef  : no order, continue as usual.
    # - 0 : do not step into node.
    # - 1 : stop walking.

	if (not defined $order) {
		# no callback order, so iterate in the node.
		if (Iterate($node, $level+1, $callback, $context) == 1) {
			# lower level says stop searching, so repeat to upper level.
			return 1;
		}
	}
    elsif ($order == 1) {
      # callback says stop searching, so repeat to upper level.
      #last;
      return 1;
    }
  }
  return 0;
}

sub checkFiliation($$);
sub checkFiliation($$) {
  my $node = shift;
  my $option = shift;

  for my $child (@{$node->[2]}) {
    if ($child->[3]  != $node) {
      print "FILLIATION ERROR\n";
      print "parent = ".$node->[0]." <".${$node->[1]}.">\n";
      print "child = ".$child->[0]." <".${$child->[1]}.">\n";
      return 0;
    } 
  }
  
  if ($option == 1) {
    for my $child (@{$node->[2]}) {
      if (!checkFiliation($child, $option)) {
        return 0;
      }
    }
  }

  return 1;
}

sub _CloneNodeCallback($$;$)
{
  my ($Node, $Context, $Level) = @_;
  my $RefStackArray = $Context->[0];

  my $Double = DuplicateNode($Node);
  RemoveChildren($Double);
  Append( $RefStackArray->[$Level], $Double);
  $RefStackArray->[$Level+1] = $Double;

  return undef;
}

sub Clone($)
{
  my ($Node) = @_;

  my $DoubleRoot = DuplicateNode($Node);
  RemoveChildren($DoubleRoot);

  my @Stack = ( $DoubleRoot );
  my @Context = (\@Stack);
  Iterate($Node, 0, \&_CloneNodeCallback, \@Context);
  
  #return $DoubleRoot;
  return $Stack[0];
}

my $nodeID=0;

sub _DumpNode($$;$)
{
  my ($node, $context, $level) = @_;
  my $stream = $context->[0];
  my $mode = $context->[1];
    my ($kind, $stmt, undef) = @{$node} ;

    $nodeID++;

    my $name = $node->[4];
    if (!defined $name) {
      $name = "";
    }

    my $sub_node = GetSubBloc($node);
    my $nodeSign = ' ';
    if (defined $sub_node)
    {
      $nodeSign = '+' ;
    }
    if (not defined $stmt)
    {
      $stmt = '';
    }

    my $line = "";
    if (defined $node->[5]) {
      $line = "line:".$node->[5];
    }

    if (defined $node->[6]) {
      $line = " [$line-".$node->[6]."]";
    }

    $stmt =~ s/\s*\n\s*/ /smg ;
    print $stream  '  ' x $level . '`' . $nodeSign . ' ' . $kind." ( $name $line )";
    if ( $mode eq "ALL" ) {
      print $stream  '    ' . $$stmt if (defined $$stmt);
    }
    print $stream "\n" ;
  return undef;
}

sub Dump($$$)
{
  my ($node, $stream, $mode) = @_;
  my @context = ($stream, $mode);
  $nodeID = 0;
  Iterate($node, 0, \&_DumpNode, \@context);
}

#############################################################################
#              DUMP TREE
#############################################################################

sub _DumpTree($$;$)
{
  my ($node, $context, $level) = @_;
  my $r_output = $context->[0];
  my ($kind, $stmt, undef) = @{$node} ;

  my $sub_node = GetSubBloc($node);

  my $nodeSign = ' ';
  if (defined $sub_node) {
    $nodeSign = '+' ;
  }

  #$$r_output .= $level.'  ' x $level . $nodeSign . ' ' . $kind;
  #$$r_output .= $level.'  ' x $level . $kind;
  if ($level > 0) {
    $$r_output .= '| ' x ($level-1) . '|_' . $kind;
  }
  else {
    $$r_output .= $kind;
  }
  $$r_output .= "\n" ;
  return undef;
}

sub dumpTree($$) {
  my ($node, $mode) = @_;
  my $output = "";
  my @context = (\$output, $mode);
  Iterate($node, 0, \&_DumpTree, \@context);
  return $context[0];
}


1;


