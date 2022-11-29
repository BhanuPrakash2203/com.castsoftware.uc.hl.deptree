
package PlSql::PlSqlNode ;

use strict;
use warnings;

use Erreurs;


use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( RootKind PragmaKind
             StatementKind CursorKind TypeKind
             LabelKind $LabelKind CaseKind ElseKind WhenKind CaseElseKind LoopKind IfKind ElsifKind  ThenKind
             ProcedureKind FunctionKind AnonymousKind PackageKind TriggerKind TypeBodyKind
             DeclarativeKind ExecutiveKind ExceptionKind BeginKind EndKind
             PrototypeSpecKind AlterKind
             VariableDeclarationKind
             UnexpectedKind );

my @gettersFunctions = qw( GetCondition	GetConditionalNodes );

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom PlSqlNode:
our @EXPORT_OK = (@kinds, @gettersFunctions, 'SetCondition' );  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds, @gettersFunctions);

# declaration des differents KIND utilises en PLSQL

use constant RootKind       => 'root'; 

use constant PragmaKind     => 'prag'; 
use constant StatementKind  => 'stmt'; 
use constant CursorKind     => 'curs'; 
use constant TypeKind       => 'type'; 

use constant LabelKind      => 'labl'; 
use constant CaseKind       => 'case'; 
use constant ElseKind       => 'else';  # pour if et case
use constant WhenKind       => 'when'; 
use constant CaseElseKind   => 'else'; 
use constant LoopKind       => 'loop'; 
use constant IfKind         => 'if  '; 
use constant ElsifKind      => 'elif';  
use constant ThenKind       => 'then';  

use constant ProcedureKind  => 'proc';  
use constant FunctionKind   => 'func';  
use constant AnonymousKind  => 'anon';  
use constant PackageKind    => 'pack';  
use constant TriggerKind    => 'trig';  
use constant TypeBodyKind   => 'Type';  
use constant PrototypeSpecKind  => 'prot';  
use constant AlterKind  => 'alte';  

use constant DeclarativeKind=> 'decl';  
use constant ExecutiveKind  => 'exec';  
use constant ExceptionKind  => 'exce';  
use constant BeginKind      => ExecutiveKind;

use constant VariableDeclarationKind   => 'var ';  

use constant EndKind        => 'end ';  

use constant UnexpectedKind => 'unex';   # cas d'erreur de parse

use Lib::Node;
use Lib::NodeUtil;

sub SetCondition($$)
{
  my ($node, $condition) =@_;
  $node->[7] = $condition ;
}

sub GetCondition($)
{
  my ($node) =@_;
  my $condition = $node->[7] ;
  return $condition;
}


sub _cbGetNodesByKind($$)
{
  my ($node, $context) = @_;
  my $ref_list = $context->[0];
  my $expectedKind = $context->[1];
  if ( IsKind ( $node,  $expectedKind))
  {
    push @{$ref_list}, $node;
  }
  return undef;
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

1;
