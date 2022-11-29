
package Kotlin::KotlinNode ;

use strict;
use warnings;

use Lib::NodeUtil;

use Erreurs;

use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( RootKind EmptyKind
                 InitKind FunctionKind FunctionExpressionKind LambdaKind GetterKind SetterKind ConstructorKind FunctionCallKind
                 IfKind ThenKind ElseKind ElsifKind WhenKind CaseKind DefaultKind ConditionKind ForKind WhileKind ReturnKind BreakKind ContinueKind ThrowKind
                 nodeLink ParenthesisKind TryKind CatchKind FinallyKind
                 VarKind ValKind DestructuringKind
                 ClassKind EnumKind InterfaceKind ObjectDeclarationKind ObjectExpressionKind ClassInitNodeKind
                 PackageKind ImportKind
	 ); 

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom ObjCNode:
our @EXPORT_OK = (@kinds);  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds);

# declaration des differents KIND utilises en Kotlin


use constant RootKind       => 'root'; 
use constant EmptyKind      => 'empty';
use constant InitKind       => 'init';  

use constant FunctionKind	=> 'func';
use constant FunctionExpressionKind	=> 'Fexpr';
use constant LambdaKind		=> 'lambda';
use constant GetterKind		=> 'get';
use constant SetterKind		=> 'set';
use constant ConstructorKind=> 'constr';
use constant ReturnKind		=> 'return';
use constant BreakKind		=> 'break';
use constant ContinueKind	=> 'continue';
use constant ThrowKind		=> 'throw';
use constant IfKind  	   	=> 'if';
use constant ThenKind  	  	=> 'then';
use constant ElseKind     	=> 'else';
use constant ElsifKind     	=> 'elsif';
use constant WhenKind     	=> 'when';
use constant CaseKind     	=> 'case';
use constant DefaultKind  	=> 'default';
use constant ConditionKind	=> 'cond';
use constant ForKind		=> 'for';
use constant WhileKind		=> 'while';
use constant ParenthesisKind=> 'parenth';
use constant VarKind		=> 'var';
use constant ValKind		=> 'val';
use constant DestructuringKind		=> 'destr';
use constant InterfaceKind		=> 'interf';
use constant ClassInitNodeKind		=> 'Cinit';
use constant ObjectDeclarationKind	=> 'ObjDecl';
use constant ObjectExpressionKind	=> 'ObjExpr';
use constant TryKind		=> 'try';
use constant CatchKind		=> 'catch';
use constant FinallyKind	=> 'finally';

use constant ClassKind	=> 'class';
use constant EnumKind	=> 'enum';

use constant FunctionCallKind => 'fct_call';

use constant PackageKind => 'pkg';
use constant ImportKind => 'imp';


sub nodeTag($) {
  my $node = shift;
  my $name = GetName($node);

#  if (IsKind($node, ParenthesisKind)) {
#    if (defined $name) {
#      return "__".$name."__";
#      #return "(".${GetStatement($node)}.")";
#    }
#  }

  if (IsKind($node, FunctionKind)) {
    if (defined $name) {
      return "__function_$name"."__";
    }
  }

  if (IsKind($node, FunctionCallKind)) {
    if (defined $name) {
      return "__".$name."__";
    }
  }

#  if (IsKind($node, ObjectKind)) {
#    if (defined $name) {
#      return "__".$name."__";
#    }
#  }

#  if (IsKind($node, BracketKind)) {
#    if (defined $name) {
#      return "__".$name."__";
#    }
#  }
#  if (IsKind($node, TabAccessKind)) {
#    if (defined $name) {
#      return "__".$name."__";
#    }
#  }

  return "";
}

# return a string that can identify the related node.
sub nodeLink($) {
  my $node = shift;
  my $name = GetName($node);

#  if (IsKind($node, ParenthesisKind)) {
#    if (defined $name) {
#      return "(__".$name."__)";
#      #return "(".${GetStatement($node)}.")";
#    }
#  }

#  if (IsKind($node, FunctionKind)) {
#    if (defined $name) {
#      return "__function_$name"."__";
#    }
#  }

  if (IsKind($node, FunctionCallKind)) {
    if (defined $name) {
      return "(__".$name."__)";
    }
  }
  
  if (IsKind($node, IfKind)) {
	  return " __if__ ";
  }

  if (IsKind($node, LambdaKind)) {
      return "{__lambda__}";
  }

#  if (IsKind($node, BracketKind)) {
#    if (defined $name) {
#      return "[__".$name."__]";
#    }
#  }
#  if (IsKind($node, TabAccessKind)) {
#    if (defined $name) {
#      return "[__".$name."__]";
#    }
#  }
#  if (IsKind($node, TernaryKind)) {
#    if (defined $name) {
#      return "__".$name."__";
#    }
#  }

  return "";
}

1;
