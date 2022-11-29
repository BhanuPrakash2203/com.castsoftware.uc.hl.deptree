package JSP::JSPLib;

use strict;
use warnings;


sub getTagAttribute($$$) {
	my $tagStmt = shift;
	my $attribute = shift;
	my $strings = shift;
	
	my $attributeValue = undef;
	 
	if ($$tagStmt =~ /$attribute\s*=\s*(\w+)/) {
		
		$attributeValue = $1;
		
		if ((exists $strings->{$1}) && ($strings->{$1} =~ /\A["'](.*)["']\z/)) {
			return $1;
		}
		else  {
			return $attributeValue;
		}	
	}
	return undef;
}

1;
