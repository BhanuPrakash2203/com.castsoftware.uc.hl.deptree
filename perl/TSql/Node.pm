
package TSql::Node ;

use strict;
use warnings;

use Exporter 'import'; # gives you Exporter’s import() method directly

our @EXPORT_OK = qw( Leaf Node Append );  # symbols to export on request

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
# [5] --> line
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

#sub Create()
#{
  #my @bloc = ( );
  #return \@bloc;
#}

sub DuplicateNode($)
{
  my ($Node) = @_;
  my @Double = @{$Node};
  return \@Double;
}


sub Append($$)
{
  my ($node, $subnode) = @_;
  my $bloc = $node->[2];
  $subnode->[3] = $node ;   # for a back walk ...
  push @{$bloc}, $subnode;
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
    my $ne_pas_descendre = $callback->( $node, $context, $level );

    if (not defined $ne_pas_descendre)
    {
      Iterate($node, $level+1, $callback, $context);
    }
  }
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

sub _DumpNode($$;$)
{
  my ($node, $context, $level) = @_;
  my $stream = $context->[0];
  my $mode = $context->[1];
    my ($kind, $stmt, undef) = @{$node} ;

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
    $stmt =~ s/\s*\n\s*/ /smg ;
    print $stream  '  ' x $level . '`' . $nodeSign . ' ' . $kind." ( $name )";
    if ( $mode eq "ALL" ) {
      print $stream  '    ' . $$stmt;
    }
    print $stream "\n" ;
  return undef;
}

sub Dump($$$)
{
  my ($node, $stream, $mode) = @_;
  my @context = ($stream, $mode);
  Iterate($node, 0, \&_DumpNode, \@context);
}

1;


