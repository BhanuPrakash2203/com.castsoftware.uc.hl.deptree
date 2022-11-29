
package ObjC::CountNaming ;

use strict;
use warnings;

use Erreurs;
use ObjC::ObjCNode;

use Ident;

my $mnemo_BadObjCMethodNames = Ident::Alias_BadObjCMethodNames();
my $mnemo_BadObjCClassNames = Ident::Alias_BadObjCClassNames();
my $mnemo_BadFileNames = Ident::Alias_BadFileNames();

my $nb_BadObjCMethodNames = 0;
my $nb_BadObjCClassNames = 0;
my $nb_BadFileNames = 0;

use constant LIMIT_SHORT_ATTRIBUTE_NAMES => 8;
use constant LIMIT_SHORT_CLASS_NAMES => 12;
use constant LIMIT_SHORT_METHOD_NAMES => 10;

sub isAttributeNameTooShort($) {
  my $r_name = shift;

  if ( length $$r_name < LIMIT_SHORT_ATTRIBUTE_NAMES ) {
    return 1;
  }
  return 0;
}

sub isClassNameTooShort($) {
  my $r_name = shift;

  if ( length $$r_name < LIMIT_SHORT_CLASS_NAMES ) {
    return 1;
  }
  return 0;
}

sub isMethodNameTooShort($) {
  my $r_name = shift;

  if ( length $$r_name < LIMIT_SHORT_METHOD_NAMES ) {
    return 1;
  }
  return 0;
}

sub checkAttributeName($) {
  my $name = shift;

  # no leading underscore.
  # camel notation.
  if ($$name !~ /^_/m) {
    
    return 0;
  }

  return 1;
}

sub checkParameterName($) {
  my $name = shift;

  # no leading underscore.
  # camel notation.
  if ( ($$name !~ /^[a-z][a-z0-9_]*(?:[A-Z][a-z0-9_]*)*/m) ||
       (length $$name <3)) {
    return 0;
  }

  return 1;
}

sub checkMethodName($) {
  my $name = shift;

  # no leading underscore.
  # camel notation.
  if ($$name !~ /^[a-z][a-z0-9_]*(?:[A-Z][a-z0-9_]*)*/m) {
    return 0;
  }

  return 1;
}

sub checkClassName($) {
  my $name = shift;

  # no leading underscore.
  # camel notation.
  if ($$name !~ /^[A-Z]{3}(?:[A-Z][a-z0-9_]*)*/m) {
    return 0;
  }

  return 1;
}


sub CountNaming($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;
  my $status = 0;
  $nb_BadObjCMethodNames = 0;
  $nb_BadObjCClassNames = 0;
  $nb_BadFileNames = 0;

  my $headerFile = 0;

  if ($fichier =~ /\.h$/s ) {
      $headerFile = 1;
  }

  if (not defined $vue->{'structured_code'})
  {
      $status |= Couples::counter_add ($compteurs, $mnemo_BadObjCMethodNames , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BadObjCClassNames , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BadFileNames , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
  }

  my $root = $vue->{'structured_code'};

  my $fileName = $fichier;
  my $fileCategory = "";
  # remove extension.
  $fileName =~ s/\.[^\.]*$//sm;
  # remove path.
  $fileName =~ s/^.*[\\\/]//sm;
  # extract categoty 
  if ($fileName =~ /(\w+)\s*\+\s*(\w+)/) {
    $fileName = $1;
    $fileCategory = $2;
  }

  my $expectedClassFound = 0;
  my $expectedCategoryFound = 0;

  my %H_CLASS = ();
  my %H_METH = ();

  # INTERFACES
  # ==========
  my @interfaces = GetNodesByKind($root, InterfaceKind, 1);

  for my $interf (@interfaces) {

    # Check if it is a category
    my ($category) = ${GetStatement($interf)} =~ /\(\s*(\w*)\s*\)/ ;

    if (! defined $category) {
      $category = "";
    }
    elsif ($category eq "") {
      $category = "private";
    }

    my $className = GetName($interf);

    $H_CLASS{$className} = 1;

    if ($className eq $fileName) {
      $expectedClassFound = 1;

      if ($category eq $fileCategory) {
        $expectedCategoryFound = 1;
      }
    }

    if (! ObjC::CountNaming::checkClassName(\$className)) {
      $nb_BadObjCClassNames++;
#print "Bad Class name : $className !!!\n";
    } 

    # METHODS DECLARATION.
    my @meths = GetNodesByKind($interf, ObjCMethodDeclKind, 1);

    for my $meth (@meths) {

      my $name = GetName($meth);

      $H_METH{$className."::".$name} = 1;

      if (! ObjC::CountNaming::checkMethodName(\$name)) {
        $nb_BadObjCMethodNames++;
#print "Bad method name : $name !!!\n";
      } 
    }
  }

  if (( $headerFile) && (scalar @interfaces > 0)) {
    if ( (! $expectedClassFound) || ( ! $expectedCategoryFound )) {
      $nb_BadFileNames++;
#print "Bad file name : $fichier !!!\n";
    }
  }

  $expectedClassFound = 0;
  $expectedCategoryFound = 0;

  # IMPLEMENTATION
  # ================
  my @implementations = GetNodesByKind($root, ImplementationKind, 1);

  for my $impl (@implementations) {

    # Check if it is a category
    my ($category) = ${GetStatement($impl)} =~ /\(\s*(\w*)\s*\)/ ;

    if (! defined $category) {
      $category = "";
    }
    elsif ($category eq "") {
      $category = "private";
    }

    my $className = GetName($impl);

    if ($className eq $fileName) {
      $expectedClassFound = 1;

      if ( $category eq $fileCategory) {
        $expectedCategoryFound = 1;
      }
    }

    # check class only if it has not allready been in the interface.
    if (! exists $H_CLASS{$className}) {
      if (! ObjC::CountNaming::checkClassName(\$className)) {
        $nb_BadObjCClassNames++;
#print "Bad Class name : $className !!!\n";
      }
    }

    # METHODS IMPLEMENTATION.
    my @meths = GetNodesByKind($impl, ObjCMethodImplKind, 1);

    for my $meth (@meths) {

      my $name = GetName($meth);

      # check method only if it has not allready been in the interface.
      if (! exists $H_METH{$className."::".$name}) {
        if (! ObjC::CountNaming::checkMethodName(\$name)) {
          $nb_BadObjCMethodNames++;
#print "Bad method name : $name !!!\n";
        }
      }	
    }
  }

  if (( ! $headerFile) && (scalar @implementations > 0)) {
    if ( (! $expectedClassFound) || ( ! $expectedCategoryFound )) {
      $nb_BadFileNames++;
#print "Bad file name : $fichier !!!\n";
    }
  }

  $status |= Couples::counter_add ($compteurs, $mnemo_BadObjCMethodNames, $nb_BadObjCMethodNames);
  $status |= Couples::counter_add ($compteurs, $mnemo_BadObjCClassNames, $nb_BadObjCClassNames);
  $status |= Couples::counter_add ($compteurs, $mnemo_BadFileNames, $nb_BadFileNames);
  return $status;
}

1;
