
package JS::JSNode ;

use strict;
use warnings;

use Lib::NodeUtil;

use Erreurs;


use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( RootKind EmptyKind AccoladeKind 
                 VarKind VarDeclKind InitKind
		 ParenthesisKind AccoKind BracketKind
		 FunctionDeclarationKind FunctionExpressionKind ObjectKind MemberKind LabelKind
		 IfKind TernaryKind CondKind ThenKind ElseKind ForKind WhileKind DoKind ForInitKind ForIncKind
		 BreakKind ContinueKind ReturnKind
		 SwitchKind CaseKind CaseExprKind DefaultKind
		 FunctionCallKind TabAccessKind
		 TryStructKind TryKind CatchKind FinallyKind
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
use constant ImplSemicoloKind => 'impl_semico';  

use constant VarKind        => 'var';  
use constant VarDeclKind    => 'var_decl';  
use constant InitKind       => 'init';  

use constant FunctionDeclarationKind   => 'func_decl';  
use constant FunctionExpressionKind    => 'func_expr';  
use constant ObjectKind     => 'obj';  
use constant MemberKind     => 'member';  
use constant LabelKind      => 'label';  
use constant IfKind         => 'if';
use constant TernaryKind    => 'ternary';
use constant ForInitKind    => 'for_init';
use constant CondKind       => 'cond';
use constant ForIncKind     => 'for_inc';
use constant ThenKind       => 'then';
use constant ElseKind       => 'else';
use constant ForKind        => 'for';
use constant WhileKind      => 'while';
use constant DoKind         => 'do';
use constant SwitchKind     => 'switch';
use constant CaseKind       => 'case';
use constant CaseExprKind   => 'case_expr';
use constant DefaultKind    => 'default';
use constant TryStructKind  => 'try struct';
use constant TryKind        => 'try';
use constant CatchKind      => 'catch';
use constant FinallyKind    => 'finally';


use constant BreakKind      => 'break';
use constant ContinueKind   => 'continue';
use constant ReturnKind     => 'return';

use constant FunctionCallKind => 'fct_call';
use constant TabAccessKind  => 'tab_access';

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
