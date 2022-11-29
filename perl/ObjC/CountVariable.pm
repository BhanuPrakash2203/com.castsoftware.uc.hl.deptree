
package ObjC::CountVariable ;

use strict;
use warnings;

use Erreurs;
use ObjC::ObjCNode;
use Lib::Node;


my $SCALAR_TYPES = 'void|char|short|int|long|float|double|bool|SW_INT8|SW_UINT8|SW_INT16|SW_UINT16|SW_INT32|SW_UINT32|SW_INT64|SW_UINT64|SW_FLOAT|SW_DOUBLE|SW_BOOLEAN';

my $mnemo_ObjCUninitializedLocalVariables = Ident::Alias_ObjCUninitializedLocalVariables();

my $nb_ObjCUninitializedLocalVariables = 0;

my $SCOPE_GLOBAL = 0;
my $SCOPE_LOCAL = 1;

sub checkVarDecl($$) {
  my $stmt = shift;
  my $scope = shift;

  # a variable declaration is intended to be, in the following order :
  # 1 - a modifiers list (unsigned, static ...)
  # 2 - a type
  # 3 - a pointer or reference symbol.
  # 4 - a name
  # 5 - one of the following :
  #          - assignment operator
  #          - array opeening symbol ([)
  #          - the end of the statement
  #
  if ($$stmt =~ /^\s*(?:\w*\b\s*)*(\w+)\b\s*[&*]?\s*(\w+)\b\s*(=|\[|$)/sm) {
      my $type = $1;
      my $name = $2;
      my $init = $3;
#print "LOCAL VARIABLE : $name, of type $type (init = $init)\n"; 
      if (($init ne "=") && ($type =~ /^(?:$SCALAR_TYPES)$/sm)) {
        $nb_ObjCUninitializedLocalVariables++;
#print "-----> not initialized !!!\n";
      }
    }
}


sub CountVariable($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $status = 0;
  $nb_ObjCUninitializedLocalVariables = 0;

  if (not defined $vue->{'structured_code'})
  {
      $status |= Couples::counter_add ($compteurs, $mnemo_ObjCUninitializedLocalVariables , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
  }

  my $root = $vue->{'structured_code'};

  my @meths = GetNodesByKind($root, ObjCMethodImplKind);

  for my $meth (@meths) {
    my @unks = GetNodesByKind($meth, UnknowKind);

    for my $unk (@unks) {
      my $stmt = GetStatement($unk);
      checkVarDecl($stmt, $SCOPE_LOCAL );
    }
  }

  $status |= Couples::counter_add ($compteurs, $mnemo_ObjCUninitializedLocalVariables, $nb_ObjCUninitializedLocalVariables);
  return $status;
}

1;
