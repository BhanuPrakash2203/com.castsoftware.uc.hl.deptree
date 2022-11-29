package Java::CountNaming;
use warnings;

use Erreurs;
use Lib::NodeUtil;

use constant MIN_METHOD_NAME_LENGTH => 8;
use constant MIN_CLASS_NAME_LENGTH => 10;
use constant MIN_ATTRIBUTE_NAME_LENGTH => 6;

my %METHODS_EXCEPTIONS = (
	'main' => 1,
	'equals' => 1,
);

sub isExceptionMethod($) {
	my $name = shift;
	
	if (exists $METHODS_EXCEPTIONS{$name}) {
		return 1;
	}
	
	if ($name =~ /^(?:get|set)/m) {
		return 1;
	}
	
	return 0;
}

sub checkCamelCase($) {
  my $name = shift;

  # leading underscore possible.
  # camel notation.
  if ($name =~ /^[a-z_][a-z0-9_]*(?:[A-Z][a-z0-9_]*)*/m) {
    return 0;
  }
#print "  --> not camel case : $$name !!\n";
  return 1;
}

sub isNameTooShort($$) {
  my $name = shift;
  my $limit = shift;

  if ( length $name < $limit ) {
#print "  --> too short (length < $limit): $name !!\n";
    return 1;
  }
  return 0;
}

#-------------- METHODS ------------------------------------------------

sub checkMethodName($) {
	my $name = shift;
	
	if ($name =~ /^[a-z]+([A-Z][a-z]+)*$/m) {
		return 1;
	}
	return 0;
}

sub checkMethodNameLength($) {
	my $name = shift;

	return ! isNameTooShort($name, MIN_METHOD_NAME_LENGTH);
}

#-------------- CLASSES ------------------------------------------------

sub checkClassName($) {
	my $name = shift;
	
	if ($name =~ /^([A-Z][a-z]+)+$/m) {
		return 1;
	}
	return 0;
}

sub checkClassNameLength($) {
	my $name = shift;

	return ! isNameTooShort($name, MIN_CLASS_NAME_LENGTH);
}

#-------------- ATTRIBUTES ---------------------------------------------

sub checkFinalStaticAttributeName($) {
	my $name = shift;
	
	if ($name =~ /^[A-Z0-9_]*$/m) {
		# do not comply ...
		return 1;
	}
	return 0;
}

sub checkAttributeName($) {
	my $name = shift;
	
	if ($name =~ /^[a-z]+([A-Z][a-z]+)*$/m) {
		# do not comply ...
		return 1;
	}
	return 0;
}

sub checkAttributeNameLength($) {
	my $name = shift;

	return ! isNameTooShort($name, MIN_ATTRIBUTE_NAME_LENGTH);
}

1;

