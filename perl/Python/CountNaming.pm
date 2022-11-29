package Python::CountNaming;

use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Python::PythonNode;
use Python::PythonConf;

my $MIN_FUNCTION_NAME_LENGTH = 5;
my $MIN_METHOD_NAME_LENGTH = 8;

sub isShortFunctionName($) {
	my $name = shift;
	if (length($name) < $MIN_FUNCTION_NAME_LENGTH) {
		return 1;
	}
	return 0;
}

sub isShortMethodName($) {
	my $name = shift;
	if (length($name) < $MIN_METHOD_NAME_LENGTH) {
		return 1;
	}
	return 0;
}

sub isValidFunctionName($) {
	my $name = shift;
	
	if ($name =~ /^[a-z_][a-z0-9_]*$/m) {
		return 1;
	}
	return 0;
}

sub isValidMethodName($) {
	my $name = shift;
	
	if ($name =~ /^[a-z_][a-z0-9_]*$/m) {
		return 1;
	}
	return 0;
}

sub isValidClassName($) {
	my $name = shift;
	
	if ($name =~ /^[A-Z_][a-zA-Z0-9]*$/m) {
		return 1;
	}
	return 0;
}

sub isValidConstantName($) {
	my $name = shift;
	
	if ($name =~ /^(([A-Z_][A-Z0-9_]*)|(__.*__))$/m) {
		return 1;
	}
	return 0;
}

sub isValidVariableName($) {
	my $name = shift;
	
	if ($name =~ /^[a-z_][a-z0-9_]*$/m) {
		return 1;
	}
	return 0;
}

sub isValidAttributeName($) {
	return isValidVariableName(shift);
}

1;


