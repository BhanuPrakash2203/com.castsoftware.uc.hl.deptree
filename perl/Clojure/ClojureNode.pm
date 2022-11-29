
package Clojure::ClojureNode ;

use strict;
use warnings;

use Lib::NodeUtil;

use Erreurs;


use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( RootKind ImportKind ListKind VectorKind SetStructKind QuoteKind SymbolKind OpArithKind DefKind
				FunctionKind FunctionArityKind FunctionPolymorphicKind AnonymousKind FunctionLiteralKind AnonymousPolymorphicKind AnonymousArityKind
				IfKind ConditionKind SwitchKind SwitchpKind SwitchArrowKind CaseKind DefaultKind ThenKind ElseKind
				PipeKind MapKind SwitchCaseKind WhenKind WhileKind LoopKind NamespaceKind LetKind
	 ); 

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom ObjCNode:
our @EXPORT_OK = (@kinds);  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds);

sub setClojureKindData($$$) {
	my $node = shift;
	my $kindName = shift;
	my $kindData = shift;
	
	$node->[7]->{$kindName} = $kindData;
}

sub getClojureKindData($$) {
	my $node =shift;
	my $kindName = shift;

	return $node->[7]->{$kindName};
}

use constant RootKind		=> 'root';
use constant ImportKind		=> 'import';
use constant ListKind		=> 'list';
use constant VectorKind		=> 'vect';
use constant SetStructKind		=> 'set';
use constant MapKind		=> 'map';
use constant QuoteKind		=> 'quote';
use constant SymbolKind		=> 'sym';
use constant OpArithKind	=> 'arith';
use constant DefKind		=> 'def';
use constant FunctionKind				=> 'func';
use constant FunctionLiteralKind		=> 'funcLit';
use constant FunctionArityKind			=> 'funcArity';
use constant FunctionPolymorphicKind	=> 'funcPoly';
use constant AnonymousKind				=> 'ano';
use constant AnonymousPolymorphicKind	=> 'anoPoly';
use constant AnonymousArityKind			=> 'anoArity';
use constant IfKind			=> 'if';
use constant ThenKind		=> 'then';
use constant ElseKind		=> 'else';
use constant ConditionKind	=> 'cond';
use constant SwitchKind		=> 'switch';
use constant SwitchpKind	=> 'switchp';
use constant SwitchCaseKind	=> 'switchCase';
use constant SwitchArrowKind=> 'switch->';
use constant WhenKind		=> 'when';
use constant CaseKind		=> 'case';
use constant DefaultKind	=> 'default';
use constant PipeKind		=> '->';
use constant WhileKind		=> 'while';
use constant LoopKind		=> 'loop';
use constant NamespaceKind	=> 'ns';
use constant LetKind		=> 'let';


#use constant PackageKind	=> 'pack';
#use constant ClassKind		=> 'class';
#use constant AnonymousClassKind		=> 'Aclass';
#use constant EnumKind		=> 'enum';
#use constant MethodKind		=> 'meth';

#use constant AttributeKind	=> 'attr';
#use constant AttributeDefKind => 'adef';
#use constant TryKind		=> 'try';
#use constant CatchKind		=> 'catch';
#use constant FinallyKind	=> 'finally';
#use constant ThrowKind		=> 'throw';
#use constant WhileKind		=> 'while';
#use constant ForKind		=> 'for';
#use constant EForKind		=> 'efor';
#use constant DoKind			=> 'do';
#use constant ElseKind		=> 'else';
#use constant BreakKind		=> 'break';
#use constant ContinueKind	=> 'cont';
#use constant NewKind		=> 'new';
#use constant ReturnKind		=> 'ret';

#use constant AnnotationKind	=> 'anno';
#use constant InitKind		=> 'init';
#use constant InterfaceKind	=> 'interf';
#use constant VariableKind	=> 'var';
#use constant VariableDefKind=> 'vdef';
#use constant DestructuringKind		=> 'destr';
#use constant BlockKind		=> 'block';
#use constant ClosureKind		=> 'clos';

# return a string that can identify the related node.
sub nodeLink($) {
  my $node = shift;
  my $name = GetName($node);

  if (IsKind($node, ListKind)) {
    if (defined $name) {
      return "(__".$name."__)";
    }
  }
  
  if (IsKind($node, VectorKind)) {
    if (defined $name) {
      return "[__".$name."__]";
    }
  }

  return "";
}

1;

