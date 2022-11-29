package Lib::NodeUtil;

use strict;
use warnings;

use Exporter 'import';

use Lib::Node;

my @gettersFunctions = qw( SetKind GetKind IsKind GetStatement GetSubBloc GetParent 
                           GetName 
                           GetNodesByKind
                           ref_GetNodesByKind
			   GetFirstNodeByKindList
			   GetNodesByKindList
			   GetNodesByKindList_StopAtBlockingNode
			   GetChildren
                           GetChildrenByKind
                           GetNodesByKindFromSpecificView
			   SetLine GetLine SetEndline GetEndline
			   buildArtifactKeyByNode buildArtifactKeyByData GetChildren SetChildren SetXKindData);

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom ObjCNode:
our @EXPORT_OK = (@gettersFunctions, 'SetName', 'SetStatement', 'AppendStatement' );  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@gettersFunctions);

sub GetParent($)
{
  my ($node) =@_;
  my $parent = $node->[3] ;
  return $parent;
}

sub GetChildren($)
{
  my ($node) =@_;
  my $children = $node->[2] ;
  return $children;
}

sub SetChildren($$)
{
  $_[0]->[2] = $_[1];
}

sub SetName($$)
{
  my ($node, $name) =@_;
  $node->[4] = $name ;
}

sub SetStatement($$)
{
  my ($node, $stmt) =@_;
  $node->[1] = $stmt ;
}

sub AppendStatement($$)
{
  my ($node, $stmt) =@_;
  ${$node->[1]} .= $$stmt ;
}

sub GetName($)
{
  my ($node) =@_;
  my $name = $node->[4] ;
  return $name;
}

sub SetLine($$) {
  my ($node, $line) =@_;
  $node->[5] = $line ;
}

sub GetLine($)
{
  my ($node) =@_;
  return $node->[5] ;
}

sub SetEndline($$) {
  my ($node, $line) =@_;
  $node->[6] = $line ;
}

sub GetEndline($)
{
  my ($node) =@_;
  return $node->[6] ;
}

sub SetKind($$)
{
  my ($node, $kind) =@_;
  $node->[0] = $kind;
}

sub GetKind($)
{
  my ($item) =@_;
  my ($kind, $stmt, $sub_bloc) = @{$item} ;
  return $kind;
}

sub SetKindData($$) {
  $_[0]->[7] = $_[1];
}

sub GetKindData($) {
  return $_[0]->[7];
}

sub SetXKindData($$$) {
	my $node = shift;
	my $kindName = shift;
	my $kindData = shift;
	
	$node->[7]->{$kindName} = $kindData;
}

sub GetXKindData($$) {
	my $node =shift;
	my $kindName = shift;

	return $node->[7]->{$kindName};
}

sub IsKind($$)
{
  my ($node, $expectedKind) =@_;
  my $kind = $node->[0] ;

  if (not defined $kind)
  {
    #Erreurs::LogInternalTraces('warn', undef, undef, 'lib', "Aucun noeud ne peut pas etre de type " .  $expectedKind );
    print STDERR "[Lib::NodeUtil::IsKind] undefined kind when checking '$expectedKind', called from ";
    my ($package, $filename, $line) = caller;
    print STDERR "$filename:$line\n";
    return 0;
  }

  return ( $kind eq $expectedKind );
}


sub GetStatement($)
{
  my ($item) =@_;
  my ($kind, $stmt, $sub_bloc) = @{$item} ;
  return $stmt;
}

sub _cbBuildListByKind($$)
{
  my ($node, $context) = @_;
  my $ref_hash = $context->[0];
  my $kind =  GetKind($node);
  if (defined $ref_hash->{$kind})
  {
    push @{$ref_hash->{$kind}}, $node;
  }
  else
  {
    $ref_hash->{$kind} = [$node];
  }
  return undef;
}

sub BuildListByKind($)
{
  my ($node) = @_;
  my %hash = ();
  my @context = ( \%hash);
  Lib::Node::Iterate ($node, 0, \&_cbBuildListByKind, \@context);
  return \%hash;
}

sub _cbGetChildrenByKind($$$)
{
  my ($node, $context, $level) = @_;

  if ($level > 0) {
    return 0; # Do not step into next level.
  }

  my $ref_list = $context->[0];
  my $expectedKind = $context->[1];
  if ( IsKind ( $node,  $expectedKind))
  {
    push @{$ref_list}, $node;
  }
  return undef;
}

sub GetChildrenByKind($$)
{
  my ($node, $expectedKind) = @_;
  my @list = ();
  my @context = ( \@list, $expectedKind);
  Lib::Node::Iterate ($node, 0, \&_cbGetChildrenByKind, \@context);
  return @list;
}

sub _cbGetNodesByKindList($$)
{
  my ($node, $context) = @_;
  my $ref_list = $context->[0];
  my $KindList = $context->[1];
  # $context->[2] : option => 0: analyze all subnodes. 1: do not analyze subnodes of searched nodes.
  # $context->[3] : kind of blocking node : analysis will not step into blocking nodes.

  my $nodeWasExpected = 0;

  for my $expectedKind (@{$KindList}) {
    if ( IsKind ( $node,  $expectedKind))
    {
      push @{$ref_list}, $node;

      $nodeWasExpected = 1;
      
    }
  }

  if ( defined $context->[3]) {
    my $kind = GetKind($node);
    my @foundBlocking = grep{ /\b$kind\b/ } @{$context->[3]};
    #if (IsKind ($node, $context->[3])) {
    if (scalar @foundBlocking > 0) {
      # do not record the node
      # do not analyze subnodes.
      return 0;  # to say to the iterator not analysing subnodes.
    }
  }

  # If this is an expected node, check if we should search into it ...
  if ($nodeWasExpected) {
    if ( $context->[2] == 1 ) {
      return 0;  # to say to the iterator not analysing subnodes.
                 # Stop to the first node encountered with the expected kind.
    }
  }

  return undef;
}

sub GetNodesByKindList_StopAtBlockingNode($$$;$)
{
  my ($rootnode, $KindList, $blockingnodeList, $opt) = @_;
  my @list = ();
  if (!defined $opt) { $opt = 0; }
  my @context = ( \@list, $KindList, $opt, $blockingnodeList);
  Lib::Node::Iterate ($rootnode, 0, \&_cbGetNodesByKindList, \@context);
  return @list;
}

sub GetNodesByKindList($$;$)
{
  my ($node, $KindList, $opt) = @_;
  my @list = ();
  if (!defined $opt) { $opt = 0; }
  my @context = ( \@list, $KindList, $opt);
  Lib::Node::Iterate ($node, 0, \&_cbGetNodesByKindList, \@context);
  return @list;
}


sub _cbGetNodesByKind($$)
{
  my ($node, $context) = @_;
  my $ref_list = $context->[0];
  my $expectedKind = $context->[1];
  if ( IsKind ( $node,  $expectedKind))
  {
    push @{$ref_list}, $node;
    if ( $context->[2] == 1 ) {
      return 0;  # to say to the iterator not analysing subnodes.
                 # Stop to the first node encountered with the expected kind.
    }
  }
  return undef;
}

sub GetNodesByKind($$;$)
{
  my ($node, $expectedKind, $opt) = @_;
  my @list = ();
  if (!defined $opt) { $opt = 0; }
  my @context = ( \@list, $expectedKind, $opt);
  Lib::Node::Iterate ($node, 0, \&_cbGetNodesByKind, \@context);
  return @list;
}

sub ref_GetNodesByKind($$;$)
{
  my ($node, $expectedKind, $opt) = @_;
  my $list = [];
  if (!defined $opt) { $opt = 0; }
  my @context = ( $list, $expectedKind, $opt);
  Lib::Node::Iterate ($node, 0, \&_cbGetNodesByKind, \@context);
  return $list;
}


#sub _cbGetFirstNodeByKindList($$)
#{
#  my ($node, $context) = @_;
#  my $ref_list = $context->[0];
#  my $expectedKindList = $context->[1];
#
#  # No treatments for blocking nodes ...
#  if ( defined $context->[2]) {
#    my $kind = GetKind($node);
#    my @foundBlocking = grep{ /\b$kind\b/ } @{$context->[2]};
#    if (scalar @foundBlocking > 0) {
#      return 0;  # to say to the iterator not analysing subnodes.
#    }
#  }
#
#  for my $kind (@$expectedKindList) {
#    if ($node->[0] eq $kind))
#    {
#      push @{$ref_list}, $node;
#      return 1;  # to say to the iterator stoping research.
#    }
#  }
#  return undef;
#}
#
#sub GetFirstNodeByKindList($$;$)
#{
#  my ($node, $expectedKindList, $blockingnodeList) = @_;
#  if (! defined $blockingnodeList) {
#    $blockingnodeList = [];
#  }
#  my @list = ();
#  my @context = ( \@list, $expectedKindList, $blockingnodeList);
#  Lib::Node::Iterate ($node, 0, \&_cbGetFirstNodesByKind, \@context);
#  return @list;
#}



sub _cbIsContainingKind($$)
{
  my ($node, $context) = @_;
  my $expectedKind = $context->[1];
  if ( IsKind ( $node,  $expectedKind))
  {
    $context->[0] = 1;
    return 1;  # to say to the iterator stop searching.
  }
  return undef;
}

sub IsContainingKind($$)
{
  my ($node, $expectedKind) = @_;
  my @context = ( 0, $expectedKind);
  Lib::Node::Iterate ($node, 0, \&_cbIsContainingKind, \@context);
  return $context[0];
}

sub GetNodesByKindFromSpecificView($$)
{
  my ($root, $expectedKind) = @_;
  my @list = ();
  if ( defined $root->{$expectedKind} )
  {
    return @{$root->{$expectedKind}};
  }
  return @list;
}

sub GetSubBloc($)
{
  my ($parent) = @_;
  return Lib::Node::GetSubBloc($parent);
}


sub grepNode($$;$);

sub grepNode($$;$) {
  my $node = shift;
  my $expr = shift;
  my $stmt = shift;

  my $count = 0;

  if (!defined $stmt) {
    $stmt = ${GetStatement($node)};
  }
  my $children = Lib::NodeUtil::GetChildren($node);

  $count += () = $$stmt =~ /$$expr/s;

  for my $child (@$children) {
    my $name = GetName($child);
    # if the subnode is linked to the statement search in it.
    if ($$stmt =~ /$name/s) {
      $count += grepNode($child, $expr);
    }
  }

  return $count;
}

sub getArtifactLinesOfCode($$) {
	my $node = shift;
	my $views = shift;
	
	my $BeginningLine = GetXKindData($node, 'first_instruction_line');
	my $EndLine = GetXKindData($node, 'last_instruction_line');
	
	my $index1;
    my $index2;
	
	if ((defined $BeginningLine) && (defined $EndLine)) {
		$index1 = $views->{'agglo_LinesIndex'}->[$BeginningLine];
		$index2 = $views->{'agglo_LinesIndex'}->[$EndLine+1]-1;
	}
    # print "index $index1 a index $index2 \n";
	
	my $nb_LOC;
	
	if ((defined $index1) && (defined $index2)) {
#print "BLOC ". substr ($views->{'agglo'}, $index1, ($index2-$index1)) ."\n";
		$nb_LOC = () = substr ($views->{'agglo'}, $index1, ($index2-$index1)) =~ /^[^\n]*(P)[^\n]*$/gm;
	}
	
    return $nb_LOC;
}

##############################################
#    Artifact identification
##############################################

sub buildArtifactKeyByData($$) {
  my $name = shift;
  my $line = shift;
  my $_line = "";

  if (defined $line) {
    $_line = "_$line";
  }

  return $name.$_line;
}

sub buildArtifactKeyByNode($) {
  my $artiNode = shift;
  my $name = GetName($artiNode);
  my $line = GetLine($artiNode);

  return buildArtifactKeyByData($name, $line);
}

1;
