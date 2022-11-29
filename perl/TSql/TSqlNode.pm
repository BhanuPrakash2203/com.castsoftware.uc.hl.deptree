
package TSql::TSqlNode ;

use strict;
use warnings;

use Erreurs;


use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( RootKind PragmaKind
             StatementKind CursorKind FetchKind TypeKind
             LabelKind $LabelKind CaseKind ElseKind WhenKind LoopKind IfKind ElsifKind  ConditionKind ReturnKind ThenKind
             ProcedureKind FunctionKind AnonymousKind PackageKind TriggerKind TypeBodyKind
             DeclarativeKind ExecutiveKind ExceptionKind BeginKind BeginTryKind BeginCatchKind BeginTranKind CommitTranKind RollbackTranKind EndKind EndTryKind EndCatchKind GoKind
             PrototypeSpecKind 
             VariableDeclarationKind CursorDeclarationKind
	     InsertKind DeclareKind CreateTableKind SelectKind CreateKind DropKind AlterKind SQLKind QueryOpKind
             SeparatorKind LabelKind ParenthesisKind UnknowKind );

my @gettersFunctions = qw( GetKind IsKind GetStatement GetSubBloc GetParent 
                           GetName 
                           GetNodesByKind
                           GetNodesByKindFromSpecificView
			   SetLine GetLine );

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom PlSqlNode:
our @EXPORT_OK = (@kinds, @gettersFunctions, 'Append', 'SetName', 'SetStatement' );  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds, @gettersFunctions);

# declaration des differents KIND utilises en PLSQL

use constant RootKind       => 'root'; 

use constant PragmaKind     => 'prag'; 
use constant StatementKind  => 'stmt'; 
use constant CursorKind     => 'curs'; 
use constant FetchKind      => 'fetch'; 
use constant TypeKind       => 'type'; 

use constant CaseKind       => 'case'; 
use constant ElseKind       => 'else';  # pour if et case
use constant WhenKind       => 'when'; 
use constant LoopKind       => 'loop'; 
use constant IfKind         => 'if  '; 
use constant ElsifKind      => 'elif';  
use constant ThenKind       => 'then';  
use constant ConditionKind  => 'cond';  
use constant ReturnKind     => 'return';  

use constant ProcedureKind  => 'proc';  
use constant FunctionKind   => 'func';  
use constant AnonymousKind  => 'anon';  
use constant PackageKind    => 'pack';  
use constant TriggerKind    => 'trig';  
use constant TypeBodyKind   => 'Type';  
use constant PrototypeSpecKind  => 'prot';  

use constant DeclarativeKind=> 'decl';  
use constant ExecutiveKind  => 'exec';  
use constant ExceptionKind  => 'exce';  
#use constant BeginKind      => ExecutiveKind;

use constant VariableDeclarationKind   => 'var ';  

use constant EndKind        => 'end ';  
use constant EndTryKind     => 'end try';  
use constant EndCatchKind   => 'end catch';  

use constant SeparatorKind   => ';';      
use constant LabelKind       => 'lab:';      
use constant ParenthesisKind   => '()';      
use constant UnknowKind => 'unk';   # cas d'erreur de parse

# TSQL specific
use constant BeginKind      => 'begin';
use constant BeginTryKind     => 'begin try';
use constant BeginCatchKind   => 'begin catch';
use constant BeginTranKind    => 'begin tran';
use constant CommitTranKind   => 'commit tran';
use constant RollbackTranKind => 'rollback tran';
use constant GoKind         => 'go ';  
use constant InsertKind     => 'insert ';  
use constant CursorDeclarationKind   => 'curs ';  
use constant CreateTableKind   => 'create table ';  
use constant CreateKind   => 'create ';  
use constant AlterKind    => 'alter ';  
use constant SQLKind    => 'sql ';  
use constant DropKind   => 'drop ';  
use constant SelectKind   => 'Select ';  
use constant QueryOpKind   => 'queryOp ';  

use TSql::Node;

# surcharge de la methode Append du package Node.
sub Append($$)
{
  my ($parent, $child) = @_;
  TSql::Node::Append($parent, $child);
  $child->[3] = $parent;
}

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

sub GetKind($)
{
  my ($item) =@_;
  my ($kind, $stmt, $sub_bloc) = @{$item} ;
  return $kind;
}

sub IsKind($$)
{
  my ($node, $expectedKind) =@_;
  my $kind = $node->[0] ;

  if (not defined $kind)
  {
    Erreurs::LogInternalTraces('warn', undef, undef, 'lib', "Aucun noeud ne peut pas etre de type " .  $expectedKind );
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
  TSql::Node::Iterate ($node, 0, \&_cbBuildListByKind, \@context);
  return \%hash;
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

sub GetNodesByKind($$)
{
  my ($node, $expectedKind) = @_;
  my @list = ();
  my @context = ( \@list, $expectedKind);
  TSql::Node::Iterate ($node, 0, \&_cbGetNodesByKind, \@context);
  return @list;
}


sub _cbIsContainingKind($$)
{
  my ($node, $context) = @_;
  my $expectedKind = $context->[1];
  if ( IsKind ( $node,  $expectedKind))
  {
    $context->[0] = 1;
    return 0;  # to say to the iterator not analysing subnodes.
  }
  return undef;
}

sub IsContainingKind($$)
{
  my ($node, $expectedKind) = @_;
  my @context = ( 0, $expectedKind);
  TSql::Node::Iterate ($node, 0, \&_cbIsContainingKind, \@context);
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
  return TSql::Node::GetSubBloc($parent);
}


1;
