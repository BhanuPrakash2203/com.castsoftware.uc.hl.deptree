package Lib::Log;

use strict;
use warnings;

sub ERROR($) {
	my $message = shift;
	
	my ($package, $filename, $line, $subr)= caller(1);

	print STDERR "[$subr\:$line] ERROR $message\n";
}

sub WARNING($) {
	my $message = shift;
	
	my ($package, $filename, $line, $subr)= caller(1);
	
	print STDERR "[$subr:$line] WARNING $message\n";
}

sub INFO($) {
	my $message = shift;
	
	my ($package, $filename, $line, $subr)= caller(1);
	
	print STDERR "[$subr:$line] INFO $message\n";
}

1;
