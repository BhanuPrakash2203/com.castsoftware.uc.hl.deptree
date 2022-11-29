package CS::CheckCS;

use strict;
use warnings;

sub CheckCodeAvailability($$) {
	my $file = shift;
	my $views = shift;
	
	my $status;
	
	my $code = \$views->{'code'};
	
	if ($$code =~ /\[(Test|TestFixture|TestCase|TestCaseSource)\]/) {
		$status = 1 # test file
	}
	
	if (((! defined $status) || ($status != 1)) && ($file =~ /(Tests?\.cs)$/m))  {
		print STDERR "[INFO] file $file ends with $1, but contains no test !!!\n";
	}
	
	return $status;
}


1;
