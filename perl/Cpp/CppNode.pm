
package Cpp::CppNode ;

use strict;
use warnings;

use Lib::NodeUtil;

use Erreurs;


use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( RootKind PackageKind
		InterfaceKind ClassKind EnumKind MethodKind AttributeKind WhileKind ForKind EForKind DoKind TryKind CatchKind FinallyKind ThrowKind BlockKind
		IfKind ThenKind ElseKind SwitchKind CaseKind DefaultKind ConditionKind BreakKind ContinueKind ReturnKind ImportKind AnnotationKind InitKind VariableKind
		setCppKindData getCppKindData NamespaceKind StructKind PublicKind ProtectedKind PrivateKind UsingKind FunctionKind ClassPrototypeKind MethodPrototypeKind FunctionPrototypeKind
		TypedefKind ExternKind UnionKind
	 );

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom ObjCNode:
our @EXPORT_OK = (@kinds);  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds);

sub setCppKindData($$$) {
	my $node = shift;
	my $kindName = shift;
	my $kindData = shift;
	
	$node->[7]->{$kindName} = $kindData;
}

sub getCppKindData($$) {
	my $node =shift;
	my $kindName = shift;

	return $node->[7]->{$kindName};
}

use constant RootKind		=> 'root';
use constant PackageKind	=> 'pack';
use constant ClassKind		=> 'class';
use constant EnumKind		=> 'enum';
use constant MethodKind		=> 'meth';
use constant FunctionKind	=> 'func';
use constant ClassPrototypeKind	=> 'Cproto';
use constant MethodPrototypeKind	=> 'Mproto';
use constant FunctionPrototypeKind	=> 'Fproto';
use constant AttributeKind	=> 'attr';
use constant TryKind		=> 'try';
use constant CatchKind		=> 'catch';
use constant FinallyKind	=> 'finally';
use constant ThrowKind		=> 'throw';
use constant IfKind			=> 'if';
use constant WhileKind		=> 'while';
use constant ForKind		=> 'for';
use constant EForKind		=> 'efor';
use constant DoKind			=> 'do';
use constant ThenKind		=> 'then';
use constant ElseKind		=> 'else';
use constant SwitchKind		=> 'switch';
use constant CaseKind		=> 'case';
use constant DefaultKind	=> 'default';
use constant ConditionKind	=> 'cond';
use constant BreakKind		=> 'break';
use constant ContinueKind	=> 'cont';
use constant ReturnKind		=> 'ret';
use constant ImportKind		=> 'import';
use constant AnnotationKind	=> 'anno';
use constant InitKind		=> 'init';
use constant InterfaceKind	=> 'interf';
use constant VariableKind	=> 'var';
use constant BlockKind		=> 'block';
use constant NamespaceKind	=> 'nspc';
use constant StructKind		=> 'struct';
use constant UnionKind		=> 'union';
use constant PublicKind		=> 'public';
use constant ProtectedKind	=> 'protected';
use constant PrivateKind	=> 'private';
use constant UsingKind		=> 'using';
use constant TypedefKind	=> 'type';
use constant ExternKind		=> 'ext';

1;

