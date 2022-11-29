package Lib::SHA;

use strict;
use warnings;

use Digest::SHA;

sub SHA256($) {
	my ($input) = @_;
	
	#my $sha1 = Digest::SHA::sha1_hex($$input);
	my $sha256;
	eval {
		$sha256 = Digest::SHA::sha256_hex($$input);
	};
	
	if ($@) {
		print "[SHA] WARNING : $@";
		$sha256 = "";
	}
	
#print "---> SHA256 = $sha256\n";
	
	return $sha256;
}

1;
