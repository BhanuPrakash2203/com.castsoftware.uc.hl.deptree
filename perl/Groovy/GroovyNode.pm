
package Groovy::GroovyNode ;

use strict;
use warnings;

use Lib::NodeUtil;

use Erreurs;


use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( RootKind PackageKind
		InterfaceKind ClassKind AnonymousClassKind EnumKind MethodKind FunctionKind AttributeKind WhileKind ForKind EForKind DoKind TryKind CatchKind FinallyKind ThrowKind BlockKind
		IfKind ThenKind ElseKind SwitchKind CaseKind DefaultKind ConditionKind BreakKind ContinueKind NewKind ReturnKind ImportKind AnnotationKind InitKind VariableKind
		VariableDefKind AttributeDefKind DestructuringKind setGroovyKindData getGroovyKindData ClosureKind
	 );

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom ObjCNode:
our @EXPORT_OK = (@kinds);  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds);

sub setGroovyKindData($$$) {
	my $node = shift;
	my $kindName = shift;
	my $kindData = shift;
	
	$node->[7]->{$kindName} = $kindData;
}

sub getGroovyKindData($$) {
	my $node =shift;
	my $kindName = shift;

	return $node->[7]->{$kindName};
}

use constant RootKind		=> 'root';
use constant PackageKind	=> 'pack';
use constant ClassKind		=> 'class';
use constant AnonymousClassKind		=> 'Aclass';
use constant EnumKind		=> 'enum';
use constant MethodKind		=> 'meth';
use constant FunctionKind	=> 'func';
use constant AttributeKind	=> 'attr';
use constant AttributeDefKind => 'adef';
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
use constant NewKind		=> 'new';
use constant ReturnKind		=> 'ret';
use constant ImportKind		=> 'import';
use constant AnnotationKind	=> 'anno';
use constant InitKind		=> 'init';
use constant InterfaceKind	=> 'interf';
use constant VariableKind	=> 'var';
use constant VariableDefKind=> 'vdef';
use constant DestructuringKind		=> 'destr';
use constant BlockKind		=> 'block';
use constant ClosureKind		=> 'clos';

1;

