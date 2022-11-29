package Scala::ScalaNode;

use strict;
use warnings;

use Lib::NodeUtil;

use Erreurs;

use Exporter 'import';    # gives you Exporter’s import() method directly

my @kinds = qw( RootKind EmptyKind PackageKind ImportKind ClassKind ObjectKind MethodKind VarKind WhileKind
    DoWhileKind IfKind ConditionKind ThenKind ElseKind ForKind ForeachKind NewKind AnonymousClassKind AccoKind
    FunctionDeclarationKind AnnotationKind ReturnKind YieldKind CollectionKind StructKind TryKind CatchKind MapKind
    FinallyKind TraitKind CaseKind MatchKind LocallyKind AnonymousFuncKind UnknownKind ParamKind MultiVarKind
    WithKind MethodCallKind ReturnTypeKind AssertKind RequireKind setScalaKindData getScalaKindData
);

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom ObjCNode:
our @EXPORT_OK = (@kinds);    # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds);

sub setScalaKindData($$$) {
    my $node     = shift;
    my $kindName = shift;
    my $kindData = shift;

    $node->[7]->{$kindName} = $kindData;
}

sub getScalaKindData($$) {
    my $node     = shift;
    my $kindName = shift;

    return $node->[7]->{$kindName};
}

use constant RootKind                => 'root';
use constant EmptyKind               => 'empty';
use constant PackageKind             => 'package';
use constant ImportKind              => 'import';
use constant ClassKind               => 'class';
use constant AnonymousClassKind      => 'anonymClass';
use constant ObjectKind              => 'object';
use constant MethodKind              => 'method';
use constant NewKind                 => 'new';
use constant VarKind                 => 'var';
use constant IfKind                  => 'if';
use constant ConditionKind           => 'cond';
use constant ThenKind                => 'then';
use constant AccoKind                => 'acco';
use constant ElseKind                => 'else';
use constant ForKind                 => 'for';
use constant ForeachKind             => 'foreach';
use constant FunctionDeclarationKind => 'func_decl';
use constant WhileKind               => 'while';
use constant TraitKind               => 'trait';
use constant DoWhileKind             => 'do_while';
use constant AnnotationKind          => 'annot';
use constant ReturnKind              => 'return';
use constant YieldKind               => 'yield';
use constant CollectionKind          => 'collection';
use constant StructKind              => 'struct';
use constant TryKind                 => 'try';
use constant CatchKind               => 'catch';
use constant FinallyKind             => 'finally';
use constant CaseKind                => 'case';
use constant MatchKind               => 'match';
use constant MapKind                 => 'map';
use constant UnknownKind             => 'unk';
use constant LocallyKind             => 'locally';
use constant AnonymousFuncKind       => 'anonymFunc';
use constant WithKind                => 'with';
use constant MethodCallKind	         => 'methodCall';
use constant ParamKind               => 'parameter';
use constant MultiVarKind            => 'multiVar';
use constant ReturnTypeKind          => 'returnType';
use constant AssertKind              => 'assert';
use constant RequireKind             => 'require';

1;

