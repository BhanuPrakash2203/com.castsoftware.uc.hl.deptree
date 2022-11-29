
package Go::GoNode;

use strict;
use warnings;

use Lib::NodeUtil;

use Erreurs;

use Exporter 'import';    # gives you Exporter’s import() method directly

my @kinds = qw( RootKind EmptyKind
  StructKind InterfaceKind AttributeKind FunctionCallKind FunctionDeclarationKind ImportKind 
  PackageKind VarKind ParenthesisKind AccoKind InitKind MethodKind ReturnKind TypeKind ConstantKind 
  ForKind IfKind ThenKind ElseKind ConditionKind ContinueKind BreakKind SwitchKind CaseKind 
  DefaultKind FallthroughKind DeferKind PanicKind SelectKind GoKind LabelKind GotoKind MapKind MakeKind
  setGoKindData getGoKindData
);

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom ObjCNode:
our @EXPORT_OK = (@kinds);    # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds);

sub setGoKindData($$$) {
    my $node     = shift;
    my $kindName = shift;
    my $kindData = shift;

    $node->[7]->{$kindName} = $kindData;
}

sub getGoKindData($$) {
    my $node     = shift;
    my $kindName = shift;

    return $node->[7]->{$kindName};
}

use constant RootKind                => 'root';
use constant EmptyKind               => 'empty';
use constant StructKind              => 'struct';
use constant InterfaceKind           => 'interf';
use constant ImportKind              => 'import';
use constant FunctionCallKind        => 'fct_call';
use constant FunctionDeclarationKind => 'func_decl';
use constant PackageKind             => 'package';
use constant VarKind                 => 'var';
use constant TypeKind                => 'type';
use constant ConstantKind            => 'const';
use constant ParenthesisKind         => 'parent';  
use constant AccoKind                => 'acco';  
use constant IfKind                  => 'if';
use constant ConditionKind           => 'cond';
use constant ThenKind                => 'then';
use constant InitKind                => 'init';
use constant MethodKind              => 'meth';
use constant ReturnKind              => 'return';
use constant AttributeKind           => 'attr';
use constant ForKind                 => 'for';
use constant ContinueKind            => 'cont';
use constant BreakKind               => 'break';
use constant SwitchKind              => 'switch';
use constant CaseKind                => 'case';
use constant DefaultKind             => 'default';
use constant FallthroughKind         => 'fallthrough';
use constant DeferKind               => 'defer';
use constant PanicKind               => 'panic';
use constant SelectKind              => 'select';
use constant ElseKind                => 'else';
use constant GoKind                  => 'go';
use constant LabelKind               => 'label';
use constant GotoKind                => 'goto';
use constant MapKind                 => 'map';
use constant MakeKind                => 'make';


sub nodeLink($) {
  my $node = shift;
  my $name = GetName($node);

  if (IsKind($node, FunctionCallKind)) {
    if (defined $name) {
      return "(__".$name."__)";
    }
  }

  return "";
}

1;

