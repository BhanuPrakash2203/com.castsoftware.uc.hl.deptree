
package Python::PythonNode ;

use strict;
use warnings;

use Lib::NodeUtil;

use Erreurs;


use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( RootKind IndentKind
		ClassKind FunctionKind MethodKind WhileKind ForKind TryKind ExceptKind FinallyKind IfKind ThenKind ElifKind ElseKind ConditionKind WithKind DecorationKind AsyncKind
		BreakKind ContinueKind ReturnKind RaiseKind YieldKind ImportKind FromKind PassKind
		setPythonKindData getPythonKindData
	 );

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom ObjCNode:
our @EXPORT_OK = (@kinds);  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds);

sub setPythonKindData($$$) {
	my $node = shift;
	my $kindName = shift;
	my $kindData = shift;
	
	$node->[7]->{$kindName} = $kindData;
}

sub getPythonKindData($$) {
	my $node =shift;
	my $kindName = shift;

	return $node->[7]->{$kindName};
}

use constant RootKind		=> 'root';
use constant ClassKind		=> 'class';
use constant FunctionKind	=> 'func';
use constant MethodKind		=> 'meth';
use constant TryKind		=> 'try';
use constant ExceptKind		=> 'except';
use constant FinallyKind	=> 'finally';
use constant IfKind			=> 'if';
use constant WhileKind		=> 'while';
use constant ForKind		=> 'for';
use constant ThenKind		=> 'then';
use constant ElifKind		=> 'elif';
use constant ElseKind		=> 'else';
use constant IndentKind		=> 'indent';
use constant WithKind		=> 'with';
use constant ConditionKind	=> 'cond';
use constant DecorationKind	=> 'decor';
use constant AsyncKind		=> 'async';
use constant BreakKind		=> 'break';
use constant ContinueKind	=> 'cont';
use constant ReturnKind		=> 'ret';
use constant RaiseKind		=> 'raise';
use constant YieldKind		=> 'yield';
use constant ImportKind		=> 'import';
use constant FromKind		=> 'from';
use constant PassKind		=> 'pass';

1;

