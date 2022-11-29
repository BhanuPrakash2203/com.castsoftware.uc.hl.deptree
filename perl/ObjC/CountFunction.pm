
package ObjC::CountFunction ;

use strict;
use warnings;

use Erreurs;
use ObjC::ObjCNode;

use ObjC::CountNaming;

my $mnemo_UntaggedParameters = Ident::Alias_UntaggedParameters();
my $mnemo_NewMethodImplementation = Ident::Alias_NewMethodImplementation();
my $mnemo_BadParameterNames = Ident::Alias_BadParameterNames();
my $mnemo_TotalObjCParameters = Ident::Alias_TotalObjCParameters();
my $mnemo_Implementation = Ident::Alias_Implementation();
my $mnemo_ShortObjcClassName = Ident::Alias_ShortObjcClassName();
my $mnemo_ShortObjcMethodName = Ident::Alias_ShortObjcMethodName();
my $mnemo_ObjCMethodsImplementation = Ident::Alias_ObjCMethodsImplementation();
my $mnemo_ObjCMethodsDeclaration = Ident::Alias_ObjCMethodsDeclaration();
my $mnemo_WithTooMuchParametersMethods = Ident::Alias_WithTooMuchParametersMethods();
my $mnemo_BadLayout = Ident::Alias_BadLayout();

my $nb_UntaggedParameters = 0;
my $nb_NewMethodImplementation = 0;
my $nb_BadParameterNames = 0;
my $nb_TotalObjCParameters = 0;
my $nb_Implementation = 0;
my $nb_ShortObjcClassName = 0;
my $nb_ShortObjcMethodName = 0;
my $nb_ObjCMethodsImplementation = 0;
my $nb_ObjCMethodsDeclaration = 0;
my $nb_WithTooMuchParametersMethods = 0;
my $nb_BadLayout = 0;

use constant MAX_METHOD_PARAM => 4;
my $PARAM_NAME_EXCEPTIONS = 'x|y';

sub CountBadLayout($) {
    my $impl = shift;

    my $layoutState = 0;

      my @meths = GetNodesByKind($impl, ObjCMethodImplKind, 1);

      for my $meth (@meths) {
	my $name = GetName($meth);

	if ($name =~ /\binit\w*?\b/) {
          if ($layoutState > 0) {
	    return 1;
	  }
	}
	elsif ($name =~ /\bcopy(?:WithZone)?\b/) {
          if ($layoutState > 1) {
	    return 1;
	  }
	  else {
	    $layoutState = 1;
	  }
	}
	elsif ($name =~ /\bmutableCopy(?:WithZone)?\b/) {
          if ($layoutState > 2) {
	    return 1;
	  }
	  else {
	    $layoutState = 2;
	  }
	}
	elsif ($name =~ /\bdealloc\b/) {
          if ($layoutState > 3) {
	    return 1;
	  }
	  else {
	    $layoutState = 3;
	  }
	}
	else {
	  $layoutState = 4;
	}
      }

    return 0;
}


sub checkMethod($) {
  my $meth = shift;

      my $name = GetName($meth);

      # check name
      if (ObjC::CountNaming::isMethodNameTooShort(\$name)) {
        $nb_ShortObjcMethodName++;
      }

      if ($name eq 'new') {
        $nb_NewMethodImplementation++;
#print "new method implementation !!\n";
      }

      # -(void) insertObject:(id)anObject atIndex:(unsigned int)index
      my @params = split ":", ${GetStatement($meth)};
      
      if (@params > 0) {
	# The number of parameter is the number of ":", that is the number of elements
	# less one !
	my $nbParam = scalar @params-1;
        $nb_TotalObjCParameters += scalar @params-1;
	if ($nbParam > MAX_METHOD_PARAM) {
	  $nb_WithTooMuchParametersMethods++;
	}
      }

      my $tagNotFound = 0;
      # WARNING : index begoins to 1 because the first element of the split contains no
      # argument, but the name of the function !!
      for (my $i=1; $i < (scalar @params); $i++) {
#print "param :".$params[$i]."\n";
        if ($tagNotFound == 1) {
          $nb_UntaggedParameters++;
#print "    --> parameter is Untaggued !!!\n";
	  $tagNotFound = 0;
        }
        if ($params[$i] !~ /\)\s*\w+[^\w]+\w+\s*$/sm ) {
	  $tagNotFound=1;
        }

	my ($paramName) = $params[$i] =~ /(\w+)\s*\w*\s*$/ ;


	if (defined $paramName) {
	   if ($paramName !~ /^$PARAM_NAME_EXCEPTIONS$/) {
              if (! ObjC::CountNaming::checkParameterName(\$paramName)) {
                 $nb_BadParameterNames++;
#print "Bad parameter Name for $paramName !!!\n";
              }
           }
	}
      }
}

sub CountFunction($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $status = 0;
  $nb_UntaggedParameters = 0;
  $nb_NewMethodImplementation = 0;
  $nb_BadParameterNames = 0;
  $nb_TotalObjCParameters = 0;
  $nb_Implementation = 0;
  $nb_ShortObjcClassName = 0;
  $nb_ShortObjcMethodName = 0;
  $nb_ObjCMethodsImplementation = 0;
  $nb_ObjCMethodsDeclaration = 0;
  $nb_WithTooMuchParametersMethods = 0;
  $nb_BadLayout = 0;

  if (not defined $vue->{'structured_code'})
  {
      $status |= Couples::counter_add ($compteurs, $mnemo_UntaggedParameters , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_NewMethodImplementation , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BadParameterNames , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_TotalObjCParameters , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_Implementation , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_ShortObjcClassName , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_ShortObjcMethodName , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_ObjCMethodsImplementation , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_ObjCMethodsDeclaration , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_WithTooMuchParametersMethods , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BadLayout , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
  }

  my $root = $vue->{'structured_code'};

  my %H_METH = ();
  my %H_CLASS = ();

  # Treating class INTERFACE
  # -----------------------------
  my @interfs = GetNodesByKind($root, InterfaceKind, 1);

  for my $interf (@interfs) {
    my $className = GetName($interf);
    $H_CLASS{$className} = 1;

    # check class name
    if (ObjC::CountNaming::isClassNameTooShort(\$className)) {
      $nb_ShortObjcClassName++;
    }

    my @meths = GetNodesByKind($interf, ObjCMethodDeclKind, 1);

    $nb_ObjCMethodsDeclaration++;

    for my $meth (@meths) {
      my $name =GetName($meth);
      $H_METH{$className."::".$name} = 1;
      checkMethod($meth);
    }
  }

  # Treating class IMPLEMENTATION
  # -----------------------------
  my @impls = GetNodesByKind($root, ImplementationKind, 1);

  $nb_Implementation = scalar  @impls;

  for my $impl (@impls) {
    my $className = GetName($impl);

    $nb_BadLayout += CountBadLayout($impl);
#print "nb bad layout is : $nb_BadLayout\n";

    my @meths = GetNodesByKind($impl, ObjCMethodImplKind, 1);

    $nb_ObjCMethodsImplementation += scalar @meths;

    for my $meth (@meths) {
      my $name =GetName($meth);

      # Check the method only if it has not already been checked in the interface, in
      # case where interface and implementation where in the same file.
      if (! exists $H_METH{$className."::".$name}) {
        checkMethod($meth);
      }

      # Check the class name only if it has not already been checked in the interface, in
      # case where interface and implementation where in the same file.
      if (! exists $H_CLASS{$className}) {
          if (ObjC::CountNaming::isClassNameTooShort(\$className)) {
            $nb_ShortObjcClassName++;
          }
      }
    }
  }

  $status |= Couples::counter_add ($compteurs, $mnemo_UntaggedParameters, $nb_UntaggedParameters);
  $status |= Couples::counter_add ($compteurs, $mnemo_NewMethodImplementation, $nb_NewMethodImplementation);
  $status |= Couples::counter_add ($compteurs, $mnemo_BadParameterNames, $nb_BadParameterNames);
  $status |= Couples::counter_add ($compteurs, $mnemo_TotalObjCParameters, $nb_TotalObjCParameters);
  $status |= Couples::counter_add ($compteurs, $mnemo_Implementation, $nb_Implementation);
  $status |= Couples::counter_add ($compteurs, $mnemo_ShortObjcClassName, $nb_ShortObjcClassName);
  $status |= Couples::counter_add ($compteurs, $mnemo_ShortObjcMethodName, $nb_ShortObjcMethodName);
  $status |= Couples::counter_add ($compteurs, $mnemo_ObjCMethodsImplementation, $nb_ObjCMethodsImplementation);
  $status |= Couples::counter_add ($compteurs, $mnemo_ObjCMethodsDeclaration, $nb_ObjCMethodsDeclaration);
  $status |= Couples::counter_add ($compteurs, $mnemo_WithTooMuchParametersMethods, $nb_WithTooMuchParametersMethods);
  $status |= Couples::counter_add ($compteurs, $mnemo_BadLayout, $nb_BadLayout);
  return $status;
}

1;
