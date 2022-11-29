package Cpp::CppClassDef;

use strict;
use warnings;

use CountUtil;
use Erreurs;
use Cpp::ParserIdents;

my %H_ClassDescr = ();

sub resetClassDescr() {
   %H_ClassDescr = ();
}

sub getClassDescr($) {
  my $class = shift;

  if (! exists $H_ClassDescr{$class}) {
    my %emptyH = ();
    $emptyH{'nb_methods'} = 0;
    $emptyH{'nb_static_methods'} = 0;
    $emptyH{'nb_members'} = 0;
    $emptyH{'nb_static_members'} = 0;
    $H_ClassDescr{$class} = \%emptyH;
    
  }
  return  $H_ClassDescr{$class};
}

sub isCopyConstructor($$) {
  my $data = shift;
  my $class_name = shift;

  if ($data->{'b_ctor'}) {

    if (defined $data->{'item'}) {
      if ($data->{'item'} =~ /\b$class_name\s*\(\s*(?:const)?\s*&?\s*$class_name\s*&?\s*\w+\s*\)/s ) {
	 return 1;
      }
    }
    else {
      print "ERROR: prototype does not exist for function/method !!?\n";
    }
  }
  return 0;
}

sub isDefaultConstructor($$) {
  my $data = shift;
  my $class_name = shift;

  if ($data->{'b_ctor'}) {

    if (defined $data->{'item'}) {
      if ($data->{'item'} =~ /\b$class_name\s*\(\s*\)/s ) {
	 return 1;
      }
    }
    else {
      print "ERROR: prototype does not exist for function/method !!?\n";
    }
  }
  return 0;
}

sub isCopyAssignmentOperator($$) {
  my $data = shift;
  my $class_name = shift;

  if (defined $data->{'item'}) {
    if ($data->{'item'} =~ /\boperator=\s*\(\s*(?:const|volatile)?\s*(?:\bconst|\bvolatile)?\s*\b$class_name\s*[&*]?\s*\w*\)/s ) {
      return 1;
    }
  }
  else {
    print "ERROR: prototype does not exist for function/method !!?\n";
  }
  return 0;
}

sub consolidateInfoByClass($) {
  my $views = shift;

  resetClassDescr();

  if (defined $views->{'parsed_code'}) {
      my $root = $views->{'parsed_code'};

      # record all informations class per class.
      for my $item (@$root)
      {
	  my $data = $item->[1];
          # consider only items that are inside a class interface definition.
          if ( defined ($data->{'b_item_inside_class'}) && ($data->{'b_item_inside_class'} == 1) ) { 
	      my $class_scope = $data->{'scope_class'};

	      if (defined $class_scope) {
   	          my $classDescr = getClassDescr($class_scope);

		  if ( ($item->[0] == Cpp::ParserIdents::PARSER_CPP_DECLARATION_FONCTION_OU_METHODE) ||
		      ($item->[0] == Cpp::ParserIdents::PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE) )  {

                     # inc number of methods other than constructor or destructor.
		     if (($data->{'b_ctor'} == 0) && ($data->{'b_dtor'} == 0)) {
                         $classDescr->{'nb_methods'}++;
		         if ($data->{'item'} =~ /\bstatic\b/s ) {
                             $classDescr->{'nb_static_methods'}++;
		         }
		     }

		     # class is Abstract
                     if ( $data->{'b_pure_virtual'}) {
		         $classDescr->{'abstract'} = 1;
		     }

		     # class has at leat one virtual method
		     if ( ! (($data->{'b_ctor'}) && ($data->{'b_dtor'})) &&
			     ($data->{'b_virtual'})) {
                         $classDescr->{'virtual_meth'} = 1;
		     }

		     # Class has a virtual destructor.
                     if (($data->{'b_dtor'}) && ($data->{'b_virtual'})) {
		         $classDescr->{'virtual_dtor'} = 1;
		     }

		     # class defines a copy constructor
		     if ( isCopyConstructor($data, $class_scope)) {
		         $classDescr->{'user_copy_ctor'} = $item;
		     }

		     # class defines a copy constructor
		     elsif ( isDefaultConstructor($data, $class_scope)) {
		         $classDescr->{'user_default_ctor'} = $item;
		     }

		     # class defines a copy assignment operator.
		     elsif ( isCopyAssignmentOperator($data, $class_scope)) {
		         $classDescr->{'copy_assign_op'} = $item;
		     }

		     # class defines an ampersand operator.
		     elsif ( $data->{'item'} =~ /\boperator&\s*\(\s*\)/s) {
		         $classDescr->{'ampersand_op'} = $item;
		     }

		     # class defines an comma operator.
		     elsif ( $data->{'item'} =~ /\boperator,/s) {
		         $classDescr->{'comma_op'} = $item;
		     }

		     # class defines an logical AND operator.
		     elsif ( $data->{'item'} =~ /\boperator&&/s) {
		         $classDescr->{'logical_and_op'} = $item;
		     }

		     # class defines an logical OR operator.
		     elsif ( $data->{'item'} =~ /\boperator\|\|/s) {
		         $classDescr->{'logical_or_op'} = $item;
		     }

		     # class defines a destructor
		     elsif ($data->{'b_dtor'}) {
		         $classDescr->{'user_dtor'} = $item;
		     }
                 }

                 elsif ( ($item->[0] == Cpp::ParserIdents::PARSER_CPP_DECLARATION_VARIABLE ) ||
		         ($item->[0] == Cpp::ParserIdents::PARSER_CPP_DECLARATION_STRUCT ) ||
		         ($item->[0] == Cpp::ParserIdents::PARSER_CPP_DECLARATION_VARIABLE_PTR_SUR_FONCTION ) ) {
	             $classDescr->{'nb_members'}++;
	             if ($data->{'item'} =~ /\bstatic\b/) {
	                 $classDescr->{'nb_static_members'}++;
	             }
	         }
                 elsif ($item->[0] == Cpp::ParserIdents::PARSER_CPP_DECLARATION_CLASS ) {
		     if ($data->{'item'} =~ /:/) {
		         $classDescr->{'derived'} = 1;
		     }
		 }
             }
         }
      }
  }

  $views->{'class_def'} = \%H_ClassDescr;
  return 0;
}

1;

