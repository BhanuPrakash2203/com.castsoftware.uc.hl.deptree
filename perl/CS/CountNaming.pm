package CS::CountNaming;

use strict;
use warnings;

use Erreurs;
use CS::CSNode;
use CS::CSConfig;

sub checkAttributeNameLength($) {
	my $name = shift;
	
	if (length($name) < CS::CSConfig::MIN_ATTRIBUTE_NAME_LENGTH) {
		return 1;
	}
	else {
		return 0;
	}
}

sub checkClassNameLength($) {
	my $name = shift;
	
	if (length($name) < CS::CSConfig::MIN_CLASS_NAME_LENGTH) {
		return 1;
	}
	else {
		return 0;
	}
}

sub checkMethodNameLength($) {
	my $name = shift;
	
	if (length($name) < CS::CSConfig::MIN_METHOD_NAME_LENGTH) {
		return 1;
	}
	else {
		return 0;
	}
}

#-------------------------------------------------------------------------------
# DESCRIPTION: check names
#-------------------------------------------------------------------------------

sub isPascalCase($) {
	if ( shift =~ /^(?:[A-Z][a-z\d]+)*$/m ) {
		return 1; 
	}
	return 0;
}

sub isCamelCase($) {
	if ( shift =~ /^[a-z][a-z\d]*(?:[A-Z][a-z\d]+)*$/m ) {
		return 1; 
	}
	return 0;
}

sub isUnderscorePrefixedCamelCase($) {
	if ( shift =~ /^_?[a-z][a-z\d]*(?:[A-Z][a-z\d]+)*$/m ) {
		return 1; 
	}
	return 0;
}

sub checkClassName {
  return isPascalCase(shift);
}

sub checkMethodName {
  return isPascalCase(shift);
}

sub checkAttributeName {
  my ($name, $private) = @_ ;

  if ( $private ) {
	  return isUnderscorePrefixedCamelCase($name);
  }
  else {
    return isPascalCase($name);
  }
}



1;
