
package Swift::SwiftNode ;

use strict;
use warnings;
no warnings 'redefine';

use Lib::NodeUtil;

use Erreurs;

use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( RootKind EmptyKind AccoladeKind 
                 ImportKind ExportKind DeclareKind VarKind TypeAliasKind ConstKind VarDeclKind InitKind DestructuringAssignmentKind
		 ParenthesisKind AccoKind ClosureKind ClosureAsParamKind BracketKind PreprocessorKind
		 FunctionDeclarationKind FunctionExpressionKind ClassDeclarationKind ClassExpressionKind ExtensionDeclarationKind ExtensionExpressionKind
		StructDeclarationKind StructExpressionKind ProtocolKind NamespaceKind ModuleKind EnumKind
          GetterKind SetterKind WillSetKind DidSetKind
		 MethodKind MethodProtoKind AttributeKind AttributeLabelKind ObjectKind MemberKind LabelKind
		 IfKind GuardKind TernaryKind CondKind ThenKind ElseKind ForKind WhileKind DoKind RepeatKind ForInitKind ForIncKind
		 BreakKind ContinueKind ReturnKind ThrowKind
		 SwitchKind FallthroughKind CaseKind CaseExprKind DefaultKind
		 FunctionCallKind TabAccessKind
		 TryStructKind TryKind CatchKind DeferKind TypeKind NewKind ModifierKind
			setSwiftKindData getSwiftKindData
	 ); 

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom ObjCNode:
our @EXPORT_OK = (@kinds);  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds);

# declaration des differents KIND utilises en ObjC


use constant RootKind         => 'root'; 
use constant EmptyKind        => 'empty';
use constant ParenthesisKind  => 'parent';  
use constant BracketKind      => 'tab';  
use constant AccoKind         => 'acco';  
use constant ClosureKind         => 'closure';  
use constant ClosureAsParamKind         => 'closureAsParam';  
use constant ImplSemicoloKind => 'impl_semico';
use constant ImportKind    	=> 'imp';
use constant ExportKind    	=> 'exp';
use constant DeclareKind   	=> 'decl';
use constant VarKind        => 'var';
use constant TypeAliasKind   		=> 'typealias';
use constant ConstKind		=> 'const';
use constant DestructuringAssignmentKind => 'DestAss';
use constant VarDeclKind    => 'var_decl';  
use constant InitKind       => 'init';  
use constant PreprocessorKind       => 'preproc';  

use constant FunctionDeclarationKind   => 'func_decl';  
use constant FunctionExpressionKind    => 'func_expr';
use constant ClassDeclarationKind   => 'class_decl';  
use constant ClassExpressionKind    => 'class_expr';
use constant ExtensionDeclarationKind   => 'extens_decl';  
use constant ExtensionExpressionKind    => 'extens_expr';
use constant StructDeclarationKind   => 'struct_decl';  
use constant StructExpressionKind    => 'struct_expr';
use constant ProtocolKind 	=> 'protocol';
use constant NamespaceKind 	=> 'nmspc';
use constant ModuleKind 	=> 'mod';
use constant EnumKind 		=> 'enum';
use constant GetterKind 		=> 'get';
use constant SetterKind 		=> 'set';
use constant WillSetKind 	=> 'will_set_kind';
use constant DidSetKind		=> 'did_set_kind';
use constant MethodKind  	=> 'meth';
use constant MethodProtoKind=> 'Mproto';
use constant AttributeKind 	=> 'attr';
use constant AttributeLabelKind 	=> 'attr_label';
use constant ObjectKind     => 'obj';  
use constant MemberKind     => 'member';  
use constant LabelKind      => 'label';  
use constant IfKind         => 'if';
use constant GuardKind      => 'guard';
use constant TernaryKind    => 'ternary';
use constant ForInitKind    => 'for_init';
use constant CondKind       => 'cond';
use constant ForIncKind     => 'for_inc';
use constant ThenKind       => 'then';
use constant ElseKind       => 'else';
use constant ForKind        => 'for';
use constant WhileKind      => 'while';
use constant DoKind     	   => 'do';
use constant RepeatKind      => 'repeat';
use constant SwitchKind     => 'switch';
use constant FallthroughKind     => 'fallthrough';
use constant CaseKind       => 'case';
use constant CaseExprKind   => 'case_expr';
use constant DefaultKind    => 'default';
use constant TryStructKind  => 'try struct';
use constant TryKind        => 'try';
use constant CatchKind      => 'catch';
use constant DeferKind    => 'defer';
use constant TypeKind 	 	=> 'type';
use constant NewKind 	 	=> 'new';


use constant BreakKind      => 'break';
use constant ContinueKind   => 'continue';
use constant ReturnKind     => 'return';
use constant ThrowKind      => 'throw';

use constant FunctionCallKind => 'fct_call';
use constant TabAccessKind  => 'tab_access';

use constant ModifierKind		=> 'modifier';


sub setSwiftKindData($$$) {
	my $node = shift;
	my $kindName = shift;
	my $kindData = shift;
	
	$node->[7]->{$kindName} = $kindData;
}

sub getSwiftKindData($$) {
	my $node =shift;
	my $kindName = shift;

	return $node->[7]->{$kindName};
}

sub nodeTag($) {
  my $node = shift;
  my $name = GetName($node);

  if (IsKind($node, ParenthesisKind)) {
    if (defined $name) {
      return "__".$name."__";
      #return "(".${GetStatement($node)}.")";
    }
  }

  if (IsKind($node, FunctionExpressionKind)) {
    if (defined $name) {
      return "__function_$name"."__";
    }
  }

  if (IsKind($node, FunctionCallKind)) {
    if (defined $name) {
      return "__".$name."__";
    }
  }

  if (IsKind($node, ObjectKind)) {
    if (defined $name) {
      return "__".$name."__";
    }
  }

  if (IsKind($node, BracketKind)) {
    if (defined $name) {
      return "__".$name."__";
    }
  }
  if (IsKind($node, TabAccessKind)) {
    if (defined $name) {
      return "__".$name."__";
    }
  }

  return "";
}

# return a string that can identify the related node.
sub nodeLink($) {
  my $node = shift;
  my $name = GetName($node);

  if (IsKind($node, ParenthesisKind)) {
    if (defined $name) {
      return "(__".$name."__)";
      #return "(".${GetStatement($node)}.")";
    }
  }

  if (IsKind($node, FunctionExpressionKind)) {
    if (defined $name) {
      return "__function_$name"."__";
    }
  }

  if (IsKind($node, FunctionCallKind)) {
    if (defined $name) {
      return "(__".$name."__)";
    }
  }

  if (IsKind($node, ObjectKind)) {
    if (defined $name) {
      return "{__".$name."__}";
    }
  }

  if (IsKind($node, BracketKind)) {
    if (defined $name) {
      return "[__".$name."__]";
    }
  }
  if (IsKind($node, TabAccessKind)) {
    if (defined $name) {
      return "[__".$name."__]";
    }
  }
  if (IsKind($node, TernaryKind)) {
    if (defined $name) {
      return "__".$name."__";
    }
  }

  return "";
}


sub getFlatExpression($);

sub getFlatExpression($) {
  my $node = shift;
  my $children = Lib::NodeUtil::GetChildren($node);
  my $statement = ${GetStatement($node)};

  if (scalar @$children == 0) {
    return GetStatement($node);
  }
  else {
    for my $child (@$children) {
      my $link = quotemeta nodeTag($child);
      if ($link ne "") {
        my $childStmt = ${getFlatExpression($child)};
        $statement =~ s/$link/$childStmt/;
      }
    }
  }
  return \$statement;
}

sub reaffectNodes($$$) {
  my $stmt = shift;
  my $dest = shift;
  my $src = shift;

  my $children = Lib::NodeUtil::GetChildren($src);

  for my $child (@$children) {
    my $name = GetName($child);

    if (defined $name) {
      if ($$stmt =~ /$name/s) {
        Lib::Node::Adopt($dest, $child);
      }
    }
  }
}

1;
