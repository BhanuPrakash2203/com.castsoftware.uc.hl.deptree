package Kotlin::CountNaming;

use strict;
use warnings;
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Kotlin::KotlinNode;

my $BadVariableNames__mnemo = Ident::Alias_BadVariableNames();
my $BadConstantNames__mnemo = Ident::Alias_BadConstantNames();
my $BadAttributeNames__mnemo = Ident::Alias_BadAttributeNames();
my $BadClassNames__mnemo = Ident::Alias_BadClassNames();
my $BadFunctionNames__mnemo = Ident::Alias_BadFunctionNames();
my $BadMethodNames__mnemo = Ident::Alias_BadMethodNames();

my $nb_BadClassNames = 0;

sub isUpperCase($) {
	if (shift =~ /^[A-Z0-9_]+$/m) {
		return 1;
	}
	return 0;
}

sub isCamelCase($) {
	if (shift =~ /^[a-z0-9]+([A-Z]{1,3}[a-z0-9]*)*$/m) {
		return 1;
	}
	return 0;
}

sub isPascalCase($) {
	if (shift =~ /^([A-Z][a-z0-9]+)([A-Z][a-z0-9]+)*$/m) {
		return 1;
	}
	return 0;
}

sub checkVarNaming($$) {
	my $var = shift;
	my $counters = shift;
	my $ret = 0;
	
	my $name = GetName($var);
	
	$name =~ s/^.*\.//m;
	
	my $modifiers = Lib::NodeUtil::GetXKindData($var, 'H_modifiers') || {};
	
	#if (defined $modifiers->{'const'} || IsKind($var, ValKind)) {
	if (defined $modifiers->{'const'} ) {
		if ( ! isUpperCase($name)) {
			$ret |= Couples::counter_update($counters, $BadConstantNames__mnemo, 1 );
			Erreurs::VIOLATION($BadConstantNames__mnemo, "Bad constant name ($name) at line ". GetLine($var));
		}
	}
	elsif (! isCamelCase($name)) {
		my $parentKind = GetKind(GetParent($var));
		if (($parentKind eq ClassKind) || ($parentKind eq InterfaceKind)) {
			$ret |= Couples::counter_update($counters, $BadAttributeNames__mnemo, 1 );
			Erreurs::VIOLATION($BadAttributeNames__mnemo, "Bad attribute name ($name) at line ". GetLine($var));
		}
		else {
			$ret |= Couples::counter_update($counters, $BadVariableNames__mnemo, 1 );
			Erreurs::VIOLATION($BadVariableNames__mnemo, "Bad variable name ($name) at line ". GetLine($var));
		}
	}
	
	return $ret;
}

sub checkClassNaming($$) {
	my $class = shift;
	my $counters = shift;
	my $ret = 0;
	
	my $name = GetName($class);

	$name =~ s/^.*\.//m;
	
	if (! isPascalCase($name)) {
		$ret |= Couples::counter_update($counters, $BadClassNames__mnemo, 1 );
		Erreurs::VIOLATION($BadClassNames__mnemo, "Bad class name ($name) at line ". GetLine($class));
	}
	
	return $ret;
}

sub checkFunctionNaming($$) {
	my $func = shift;
	my $counters = shift;
	my $ret = 0;
	
	my $name = GetName($func);

	return $ret if (!defined $name);

	$name =~ s/^.*\.//m;
	
	if (! isCamelCase($name)) {
		my $parentKind = GetKind(GetParent($func));
		if (($parentKind eq ClassKind) || ($parentKind eq InterfaceKind)) {
			$ret |= Couples::counter_update($counters, $BadMethodNames__mnemo, 1 );
			Erreurs::VIOLATION($BadMethodNames__mnemo, "Bad method name ($name) at line ". GetLine($func));
		}
		else {
			$ret |= Couples::counter_update($counters, $BadMethodNames__mnemo, 1 );
			Erreurs::VIOLATION($BadFunctionNames__mnemo, "Bad function name ($name) at line ". GetLine($func));
		}
	}
	
	return $ret;
}

1;

