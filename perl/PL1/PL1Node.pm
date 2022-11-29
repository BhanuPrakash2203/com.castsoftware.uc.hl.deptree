
package PL1::PL1Node ;

use strict;
use warnings;

use Erreurs;

use Lib::Node;
use Lib::NodeUtil;


use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( RootKind PackageKind ProcedureKind BeginKind DoKind DoloopKind
             EndKind DeclareKind DefaultKind IfKind ThenKind ElseKind
	     SelectKind WhenKind OtherwiseKind GotoKind EntryKind CallKind FetchKind
	     IterateKind LeaveKind GotoKind SQLKind
             NulKind OnKind UnexpectedKind );

my @gettersFunctions = qw( GetCondition
                           GetFirstNodesByKind
                           GetConditionalNodes
			   getFollowingSiblings
			   CountNodesByKind );

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom PlSqlNode:
our @EXPORT_OK = (@kinds, @gettersFunctions, 'Append', 'SetName', 'SetCondition' );  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds, @gettersFunctions);

# declaration des differents KIND utilises en PLSQL

use constant RootKind       => 'root'; 

#use constant PragmaKind     => 'prag'; 
#use constant StatementKind  => 'stmt'; 
#use constant CursorKind     => 'curs'; 
#use constant TypeKind       => 'type'; 

#use constant LabelKind      => 'labl'; 
use constant SelectKind     => 'select'; 
use constant WhenKind       => 'when'; 
use constant OtherwiseKind  => 'other'; 
#use constant LoopKind       => 'loop'; 
use constant IfKind         => 'if  '; 
use constant ElsifKind      => 'elif';  
use constant ThenKind       => 'then';  
use constant ElseKind       => 'else';  # pour if et case

use constant ProcedureKind  => 'proc';  
#use constant FunctionKind   => 'func';  
use constant NulKind        => 'nul';  
use constant OnKind         => 'on';  
use constant PackageKind    => 'pack';  
#use constant TriggerKind    => 'trig';  
#use constant TypeBodyKind   => 'Type';  
#use constant PrototypeSpecKind  => 'prot';  
#use constant AlterKind  => 'alte';  

use constant DeclareKind    => 'decl';  
use constant DefaultKind    => 'default';  
#use constant ExecutiveKind  => 'exec';  
#use constant ExceptionKind  => 'exce';  
use constant BeginKind      => 'begin';
use constant DoKind         => 'do';
use constant DoloopKind     => 'loop';
use constant IterateKind    => 'iterate';
use constant LeaveKind      => 'leave';
use constant GotoKind       => 'goto';
use constant EntryKind      => 'entry';
use constant CallKind       => 'call';
use constant FetchKind      => 'fetch';
use constant SQLKind        => 'sql';

#use constant VariableDeclarationKind   => 'var ';  

use constant EndKind        => 'end ';  

use constant UnexpectedKind => 'unex';   # cas d'erreur de parse

# surcharge de la methode Append du package Node.
#sub Append($$)
#{
#  my ($parent, $child) = @_;
#  PlSql::Node::Append($parent, $child);
#  $child->[3] = $parent;
#}

sub GetChildren($)
{
  my ($node) =@_;
  my $children = $node->[2] ;
  return $children;
}
sub SetName($$)
{
  my ($node, $name) =@_;
  $node->[4] = $name ;
}

sub SetCondition($$)
{
  my ($node, $condition) =@_;
  $node->[5] = $condition ;
}

sub GetCondition($)
{
  my ($node) =@_;
  my $condition = $node->[5] ;
  return $condition;
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


sub _cbGetFirstNodesByKind($$)
{
  my ($node, $context) = @_;
  my $ref_list = $context->[0];
  my $expectedKind = $context->[1];
  if ( IsKind ( $node,  $expectedKind))
  {
    push @{$ref_list}, $node;
    return 0;  # to say to the iterator not analysing subnodes.
  }
  return undef;
}

sub GetFirstNodesByKind($$)
{
  my ($node, $expectedKind) = @_;
  my @list = ();
  my @context = ( \@list, $expectedKind);
  Lib::Node::Iterate ($node, 0, \&_cbGetFirstNodesByKind, \@context);
  return @list;
}

sub _cbGetConditionalNodes($$)
{
  my ($node, $context) = @_;
  my $ref_list = $context->[0];
  if ( defined GetCondition ( $node))
  {
    push @{$ref_list}, $node;
  }
  return undef;
}

sub GetConditionalNodes($)
{
  my ($node) = @_;
  my @list = ();
  my @context = ( \@list);
  Lib::Node::Iterate ($node, 0, \&_cbGetConditionalNodes, \@context);
  return @list;
}

############ Family routine #############


sub getFollowingSiblings($) {
  my ($node) = @_;

  my $r_siblings = GetChildren(GetParent($node));

  my @Following = @$r_siblings ;

  # $node belongs to the list of sibling. We want to remove all siblings
  # before it, and itself too
 
  # Remove all siblings before $node.
  while ($Following[0] != $node) {
    shift @Following;
  }

  # Remove $node
  shift @Following;

  return \@Following;
}



############ Count routine #############
sub _cbCountNodesByKind($$)
{
  my ($node, $context) = @_;
  my $expectedKind = $context->[1];
  if ( IsKind ( $node,  $expectedKind))
  {
    $context->[0]++;
  }
  return undef;
}

sub CountNodesByKind($$)
{
  my ($node, $expectedKind) = @_;
  my @list = ();
  my @context = ( 0, $expectedKind);
  Lib::Node::Iterate ($node, 0, \&_cbCountNodesByKind, \@context);
  return $context[0];
}

1;
