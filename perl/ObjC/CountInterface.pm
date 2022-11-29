
package ObjC::CountInterface ;

use strict;
use warnings;

use Erreurs;
use ObjC::ObjCNode;

my $mnemo_UnexpectedIvar = Ident::Alias_UnexpectedIvar();
my $mnemo_ProtectedAttributes = Ident::Alias_ProtectedAttributes();
my $mnemo_PublicAttributes = Ident::Alias_PublicAttributes();
my $mnemo_PackageAttributes = Ident::Alias_PackageAttributes();
my $mnemo_PrivateAttributes = Ident::Alias_PrivateAttributes();
my $mnemo_NewMethodDeclaration = Ident::Alias_NewMethodDeclaration();
my $mnemo_BadObjCAttributeNames = Ident::Alias_BadObjCAttributeNames();
my $mnemo_Interface = Ident::Alias_Interface();
my $mnemo_ShortObjcAttributName = Ident::Alias_ShortObjcAttributName();

my $nb_UnexpectedIvar = 0;
my $nb_ProtectedAttributes = 0;
my $nb_PublicAttributes = 0;
my $nb_PackageAttributes = 0;
my $nb_PrivateAttributes = 0;
my $nb_NewMethodDeclaration = 0;
my $nb_BadObjCAttributeNames = 0;
my $nb_Interface = 0;
my $nb_ShortObjcAttributName = 0;

sub getIvars($) {
  my $interf = shift;

  my @ivars = ();

  my $visibilities=ObjC::ObjCNode::GetChildren(ObjC::ObjCNode::GetChildren($interf)->[0]);

  for my $visib (@$visibilities) {
    my $attributes=ObjC::ObjCNode::GetChildren($visib);

    for my $attr (@$attributes) {
      my $stmt = GetStatement($attr);
      my @vars = split ',', $$stmt;
      for my $var (@vars) {
        if ($var =~ /(.*)\b(\w+)\s*$/ms) {
  	  my $type = $1;
          my $name = $2;
	  push @ivars, [$name, $type];
        }   
      }
    }

  }
  return \@ivars;
}

sub CountUnexpectedIvar($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $status = 0;
  $nb_UnexpectedIvar = 0;

  if (not defined $vue->{'structured_code'})
  {
      $status |= Couples::counter_add ($compteurs, $mnemo_UnexpectedIvar , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
  }

  my $root = $vue->{'structured_code'};
  my @interfaces = GetNodesByKind($root, InterfaceKind, 1);

  for my $interf (@interfaces) {

    # IVARS
    #------
    my $r_ivars = getIvars($interf);
    my %H_vars = ();
    for my $var (@$r_ivars) {
      $H_vars{$var->[0]} = $var->[1];
    }

    # Get properties
    my @props = GetNodesByKind($interf, PropertyKind, 1);
    for my $prop (@props) {
      my $name = GetName($prop);
      if ( (defined $name) && (exists $H_vars{$name})) {
        $nb_UnexpectedIvar++;
#print "Unexpected ivar : ".GetName($prop)."\n";
      } 
    }
  }

  $status |= Couples::counter_add ($compteurs, $mnemo_UnexpectedIvar, $nb_UnexpectedIvar);
  return $status;
}


sub CountMethods($) {
    my $interf = shift;

    my @meths = GetNodesByKind($interf, ObjCMethodDeclKind, 1);

    for my $meth (@meths) {

      my $name = GetName($meth);

      if ($name eq 'new') {
        $nb_NewMethodDeclaration++;
#print "new method declaration !!\n";
      }
    }
}


sub checkAttributeVisibility($) {
    my $parentKind = shift;

    if ( $parentKind eq PublicKind ) {
      $nb_PublicAttributes++;
#print "Found PUBLIC ivar !!".${$attr->[1]}."\n";
    }
    elsif ( $parentKind eq PackageKind ) {
      $nb_PackageAttributes++;
#print "Found PACKAGE ivar !!".${$attr->[1]}."\n";
    }
    elsif ( $parentKind eq PrivateKind ) {
      $nb_PrivateAttributes++;
#print "Found PRIVATE ivar !!".${$attr->[1]}."\n";
    }
    else {
      $nb_ProtectedAttributes++;
#print "Found PROTECTED ivar !!".${$attr->[1]}."\n";
    }

  return 0;
}

sub checkAttributeName($) {
    my $name = shift;

    if (defined $name) {
      if (! ObjC::CountNaming::checkAttributeName(\$name)) {
        $nb_BadObjCAttributeNames++;
#print "Bad attribute name for $name !!!\n";
      }
      if (ObjC::CountNaming::isAttributeNameTooShort(\$name)) {
        $nb_ShortObjcAttributName++;
      }
    }
    else {
       print "[CountAttributes] ERROR : unable to get name of attribute\n";
    }

  return 0;
}

sub CountAttributes($) {
    my $interf = shift;

    my @attribBlocs = GetNodesByKind($interf, AttribBlocKind, 1);

    my @singleAttrs = (); 
    my @multiAttrs = ();

    for my $attrBloc (@attribBlocs) {
      # Single declarations
      push @singleAttrs, GetNodesByKindList($attrBloc, [ObjCAttribKind, BlockDeclKind], 1);
      # Multi declaration
      push @multiAttrs, GetNodesByKind($attrBloc, ObjCMultAttribKind, 1);
    }

    # Single Declaration
    for my $attr (@singleAttrs) {
      my $parentKind = GetKind(GetParent($attr));


      checkAttributeVisibility($parentKind);

      my ($name);
      if (IsKind($attr, ObjCAttribKind)) {
        # Note : the name can be followed by [..] (case of an array)
        ($name) = ${GetStatement($attr)} =~ /(\w+)\s*(?:\[[^\[\]]*\])?\s*$/sm;
      }
      else {
	$name = GetName($attr);
      }
      checkAttributeName($name);
    }

    # Multiple declarations
    for my $attr (@multiAttrs) {
      my $parentKind = GetKind(GetParent($attr));

      # get the name list and do not capture the type if it is a struct definition.
      # because struct definitions can contain ','
      my ($stmt) = ${GetStatement($attr)} =~ /([^}]*)$/s;
      my @decl = split ',', $stmt;

      for my $var (@decl) {
        my ($name) = $var =~ /(\w+)\s*$/s;
        checkAttributeVisibility($parentKind);
        checkAttributeName($name);
      }
    }

  return 0;
}

sub CountInterface($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $status = 0;
  $nb_PrivateAttributes = 0;
  $nb_PublicAttributes = 0;
  $nb_PackageAttributes = 0;
  $nb_ProtectedAttributes = 0;
  $nb_NewMethodDeclaration = 0;
  $nb_BadObjCAttributeNames = 0;
  $nb_Interface = 0;
  $nb_ShortObjcAttributName = 0;

  if (not defined $vue->{'structured_code'})
  {
      $status |= Couples::counter_add ($compteurs, $mnemo_PrivateAttributes , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_PublicAttributes , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_PackageAttributes , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_ProtectedAttributes , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_NewMethodDeclaration , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BadObjCAttributeNames , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_Interface , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_ShortObjcAttributName , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
  }

  my $root = $vue->{'structured_code'};
  my @interfaces = GetNodesByKind($root, InterfaceKind, 1);

  $nb_Interface = scalar @interfaces;

  for my $interf (@interfaces) {

    my $name = GetName($interf);

    CountAttributes($interf);

    CountMethods($interf);

  }

  # perform some count on implementation's attributes
  my $r_implementation = $vue->{'KindsLists'}->{'Implementation'};

  for my $impl (@{$r_implementation}) {
    CountAttributes($impl);
  }

  $status |= Couples::counter_add ($compteurs, $mnemo_PrivateAttributes, $nb_PrivateAttributes);
  $status |= Couples::counter_add ($compteurs, $mnemo_PublicAttributes, $nb_PublicAttributes);
  $status |= Couples::counter_add ($compteurs, $mnemo_PackageAttributes, $nb_PackageAttributes);
  $status |= Couples::counter_add ($compteurs, $mnemo_ProtectedAttributes, $nb_ProtectedAttributes);
  $status |= Couples::counter_add ($compteurs, $mnemo_NewMethodDeclaration, $nb_NewMethodDeclaration);
  $status |= Couples::counter_add ($compteurs, $mnemo_BadObjCAttributeNames, $nb_BadObjCAttributeNames);
  $status |= Couples::counter_add ($compteurs, $mnemo_Interface, $nb_Interface);
  $status |= Couples::counter_add ($compteurs, $mnemo_ShortObjcAttributName, $nb_ShortObjcAttributName);
  return $status;
}

1;
