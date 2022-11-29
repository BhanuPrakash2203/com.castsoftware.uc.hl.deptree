
package CS::CSNode;

use strict;
use warnings;

use Lib::NodeUtil;

use Erreurs;


use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( NamespaceKind PropertyKind EventKind DelegateKind
		RootKind PackageKind UsingKind ImportKind
		InterfaceKind ClassKind InterfaceKind StructKind AnonymousClassKind EnumKind MethodKind LambdaKind AnonymousMethodKind LocalFunctionKind ConstructorKind DestructorKind
		AttributeKind DestructuringKind WhileKind ForKind ForeachKind EForKind DoKind TryKind CatchKind FinallyKind ThrowKind BlockKind
		IfKind ThenKind ElseKind SwitchKind SwitchExpressionKind CaseKind DefaultKind ConditionKind BreakKind ContinueKind NewKind
		ReturnKind YieldKind ImportKind MetadataKind InitKind VariableKind LockKind
		setCSKindData getCSKindData
		UncheckedKind CheckedKind UnsafeKind FixedKind LabelKind TernaryKind
	 );

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom ObjCNode:
our @EXPORT_OK = (@kinds);  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds);

sub setCSKindData($$$) {
	my $node = shift;
	my $kindName = shift;
	my $kindData = shift;
	
	$node->[7]->{$kindName} = $kindData;
}

sub getCSKindData($$) {
	my $node =shift;
	my $kindName = shift;

	return $node->[7]->{$kindName};
}

use constant RootKind		=> 'root';
use constant NamespaceKind	=> 'ns';
use constant PropertyKind	=> 'prop';
use constant EventKind	=> 'event';
use constant DelegateKind	=> 'delegate';
use constant ClassKind		=> 'class';
use constant InterfaceKind	=> 'interface';
use constant StructKind		=> 'struct';
use constant MethodKind		=> 'meth';
use constant LambdaKind		=> 'lamb';
use constant LocalFunctionKind		=> 'loc_func';
use constant AnonymousMethodKind => 'AMeth';
use constant ConstructorKind=> 'Ctor';
use constant DestructorKind	=> 'Dtor';
use constant AttributeKind	=> 'attr';
use constant DestructuringKind		=> 'destr';
use constant UsingKind		=> 'using';
use constant ImportKind		=> 'import';
use constant LockKind		=> 'lock';
use constant UncheckedKind	=> 'unchkd';
use constant CheckedKind	=> 'chkd';
use constant UnsafeKind		=> 'unsafe';
use constant FixedKind		=> 'fixed';
use constant TernaryKind	=> 'ter';

use constant PackageKind	=> 'pack';
use constant AnonymousClassKind		=> 'Aclass';
use constant EnumKind		=> 'enum';
use constant TryKind		=> 'try';
use constant CatchKind		=> 'catch';
use constant FinallyKind	=> 'finally';
use constant ThrowKind		=> 'throw';
use constant IfKind			=> 'if';
use constant WhileKind		=> 'while';
use constant ForKind		=> 'for';
use constant ForeachKind	=> 'foreach';
use constant EForKind		=> 'efor';
use constant DoKind			=> 'do';
use constant ThenKind		=> 'then';
use constant ElseKind		=> 'else';
use constant SwitchKind		=> 'switch';
use constant SwitchExpressionKind => 'SwitchExpr';
use constant CaseKind		=> 'case';
use constant DefaultKind	=> 'default';
use constant ConditionKind	=> 'cond';
use constant BreakKind		=> 'break';
use constant ContinueKind	=> 'cont';
use constant NewKind		=> 'new';
use constant ReturnKind		=> 'ret';
use constant YieldKind		=> 'yield';
use constant ImportKind		=> 'import';
use constant MetadataKind	=> 'meta';
use constant InitKind		=> 'init';
use constant VariableKind	=> 'var';
use constant BlockKind		=> 'block';
use constant LabelKind		=> 'label';


# return a string that can identify the related node.
sub nodeLink($) {
  my $node = shift;

  if (IsKind($node, SwitchExpressionKind)) {
      return "__switch_expression__";
  }
  elsif (IsKind($node, NewKind)) {
      return "__New__";
  }

  return "";
}

1;
