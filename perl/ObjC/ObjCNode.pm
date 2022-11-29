
package ObjC::ObjCNode ;

use strict;
use warnings;

use Erreurs;


use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( RootKind EmptyKind AccoladeKind FixmeKind
                 InterfaceKind ImplementationKind PublicKind PrivateKind ProtectedKind PackageKind
		 AttribBlocKind PropertyKind SynthesizeKind
		 ObjCAttribKind ObjCMultAttribKind ObjCMethodDeclKind ObjCMethodImplKind BlockKind BlockDeclKind CallKind LocalVarKind
	         IfKind CondKind TernaryKind TernaryThenElseKind ThenKind ElsifKind ElseKind WhileKind ForKind ForeachKind DoKind EnumKind
	 );

my @gettersFunctions = qw( GetKind IsKind GetStatement GetSubBloc GetParent 
                           GetName 
                           GetNodesByKind
			   GetNodesByKindList
			   GetNodesByKindList_StopAtBlockingNode
                           GetChildrenByKind
                           GetNodesByKindFromSpecificView
			   SetLine GetLine SetEndline GetEndline
			   buildArtifactKeyByNode buildArtifactKeyByData );

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom ObjCNode:
our @EXPORT_OK = (@kinds, @gettersFunctions, 'SetName', 'SetStatement' );  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds, @gettersFunctions);

# declaration des differents KIND utilises en ObjC


use constant RootKind       => 'root'; 
use constant EmptyKind      => 'empty';
use constant AccoladeKind   => 'acco';  
# this kind is an intermediate node type. It should not appears in the output
# parsed result.
use constant FixmeKind      => 'tofix';  

use constant InterfaceKind  => 'interf';  
use constant ImplementationKind => 'impl';  
use constant AttribBlocKind => 'attr_bloc';  
use constant PropertyKind   => 'prop';  
use constant SynthesizeKind => 'synth';  
use constant PublicKind     => 'pub';  
use constant PrivateKind    => 'priv';  
use constant ProtectedKind  => 'prot';  
use constant PackageKind    => 'pack';  

use constant ObjCAttribKind => 'attr_o';  
use constant ObjCMultAttribKind => 'multi_attr_o';  
use constant ObjCMethodDeclKind => 'd_meth_o';  
use constant ObjCMethodImplKind => 'i_meth_o';  
use constant BlockKind      => 'block';  
use constant BlockDeclKind      => 'block_decl';  
use constant CallKind       => 'call';  
use constant LocalVarKind   => 'locvar';  

use constant IfKind         => 'if'; 
use constant ElsifKind      => 'elif';  
use constant ThenKind       => 'then';  
use constant ElseKind       => 'else';
use constant CondKind       => 'cond';
use constant TernaryKind    => 'ternary';
use constant TernaryThenElseKind    => 'ternary_branches';
use constant WhileKind      => 'while';
use constant ForKind        => 'for';
use constant ForeachKind    => 'foreach';
use constant DoKind         => 'do';
use constant EnumKind       => 'enum';

# PHP KINDS
#use constant SectionKind    => 'section'; 
#use constant EndSectionKind => 'end section'; 
#use constant HTMLKind       => 'html'; 
#use constant FunctionKind   => 'func';  
#use constant PrototypeKind  => 'proto';  
#use constant ClassKind      => 'class';  
#use constant InterfaceKind  => 'interf';  
#use constant MethodKind     => 'meth';  
#use constant CurlyBlocKind  => 'curly bloc';  
#use constant ColonBlocKind  => 'colon bloc';  
#
#use constant SwitchKind     => 'switch';
#use constant CaseKind       => 'case'; 
#use constant DefaultKind    => 'default'; 
#use constant BreakKind      => 'break'; 
#use constant TryKind        => 'try'; 
#use constant CatchKind      => 'catch'; 
#use constant ThrowKind      => 'throw';  
#use constant ReturnKind     => 'return';  
#
#
###########################################""
#
#use constant PragmaKind     => 'prag'; 
#use constant StatementKind  => 'stmt'; 
#use constant CursorKind     => 'curs'; 
#use constant FetchKind      => 'fetch'; 
#use constant TypeKind       => 'type'; 
#
#use constant CheckKind      => 'check'; 
#use constant CleanupKind    => 'cleanup'; 
#use constant WhenKind       => 'when'; 
#use constant WhenOtherKind  => 'other'; 
#use constant LoopKind       => 'loop'; 
#use constant AtKind         => 'at'; 
#use constant ProvideKind    => 'provide'; 
#use constant ConditionKind  => 'cond';  
#use constant ExitKind       => 'exit';  
#
#use constant FormKind       => 'form';  
#use constant ModuleKind     => 'mod';  
#use constant ExecSqlKind    => 'exec sql';  
#
#
#use constant AnonymousKind  => 'anon';  
#use constant PackageKind    => 'pack';  
#use constant TriggerKind    => 'trig';  
#use constant TypeBodyKind   => 'Type';  
#use constant PrototypeSpecKind  => 'prot';  
#
#use constant DeclarativeKind=> 'decl';  
#use constant ExecutiveKind  => 'exec';  
#use constant ExceptionKind  => 'exce';  
##use constant BeginKind      => ExecutiveKind;
#
#use constant VariableDeclarationKind   => 'var ';  
#
#use constant EndKind        => 'end ';  
#use constant EndTryKind     => 'end try';  
#use constant EndCatchKind   => 'end catch';  
#use constant EndFormKind    => 'end form';  
#use constant EndFunctionKind=> 'end func';  
#use constant EndMethodKind  => 'end meth';  
#use constant EndModuleKind  => 'end mod';  
#use constant EndClassKind   => 'end class';  
#use constant EndExecKind    => 'end exec';  
#use constant EndDoKind      => 'end do';  
#use constant EndLoopKind    => 'end loop';  
#use constant EndAtKind      => 'end at';  
#use constant EndWhileKind   => 'end while';  
#use constant EndProvideKind => 'end provide';  
#use constant EndIfKind      => 'end if';  
#use constant EndCaseKind    => 'end case';  
#use constant EndSelectKind  => 'end select';  
#
#use constant SeparatorKind   => ';';      
#use constant LabelKind       => 'lab:';      
#use constant ParenthesisKind   => '()';      
#
## Abap specific
#use constant BeginKind      => 'begin';
#use constant GoKind         => 'go ';  
#use constant InsertKind     => 'insert ';  
#use constant CursorDeclarationKind   => 'curs ';  
#use constant CreateTableKind   => 'create table ';  
#use constant CreateKind   => 'create ';  
#use constant AlterKind    => 'alter ';  
#use constant SQLKind      => 'sql ';  
#use constant SelectKind   => 'select ';  
#use constant DeleteKind   => 'delete ';  
#use constant UpdateKind   => 'update ';  
#use constant ModifyKind   => 'Modify ';  
#use constant SubqueryKind   => 'subquery ';  
#use constant QueryOpKind   => 'queryOp ';
#use constant AuthorityCheckKind => 'auth_chk';
#use constant ReadKind         => 'read';
#use constant ReadDatasetKind  => 'read dataset';
#use constant OpenDatasetKind  => 'open dataset';
#use constant OpenCursorKind  => 'open cursor';
#use constant FetchNextCursorKind => 'fetch next cursor';

use Lib::Node;

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

sub SetEndline($$) {
  my ($node, $line) =@_;
  $node->[6] = $line ;
}

sub GetEndline($)
{
  my ($node) =@_;
  return $node->[6] ;
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
  Lib::Node::Iterate ($node, 0, \&_cbBuildListByKind, \@context);
  return \%hash;
}

sub _cbGetChildrenByKind($$$)
{
  my ($node, $context, $level) = @_;

  if ($level > 0) {
    return 1; # Do not step into next level.
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

  for my $expectedKind (@{$KindList}) {
    if ( IsKind ( $node,  $expectedKind))
    {
      push @{$ref_list}, $node;

      # should go into subnode of searched node ? 
      if ( $context->[2] == 1 ) {
        return 0;  # to say to the iterator not analysing subnodes.
                 # Stop to the first node encountered with the expected kind.
      }
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
