package Lib::ThirdParties;

use strict;
use warnings;

my $OutputCsvName = "ThirdParties.csv";

my $OutputHandler = undef;

my $META_DATA = undef;

sub setMetaData($) {
	$META_DATA = shift;
}

sub setOutputFileName($) {
	$OutputCsvName = shift;
}

sub openOutputFile() {
	my $ret = open(THIRDPARTIES, ">$OutputCsvName");
	
	$OutputHandler = *THIRDPARTIES;
	
	if (! defined $ret) {
		print STDERR "Unable to open Third Parties CSV file $OutputCsvName !!!\n";
	}
	else {
		# print metadat header
		if (defined $META_DATA) {
			print $OutputHandler "#ThirdParties\n";
			print $OutputHandler "#uuid;".$META_DATA->{"uuid"}."\n";
			print $OutputHandler "#start_date;".$META_DATA->{"start_date"}."\n";
			print $OutputHandler "#version_highlight;".$META_DATA->{"version_highlight"}."\n";
			print $OutputHandler "\nFILE SECTION\n";
			print $OutputHandler "File;abort cause;SHA\n";
		}
	}
}

sub closeOutput() {
	close($OutputHandler);
}

sub addFile($$$) {
	my $filename = shift;
	my $abortCause = shift;
	my $SHA = shift;
	
	if (defined $OutputHandler) {
		print $OutputHandler "$filename;$abortCause;$SHA\n";
		print "ADDING $filename as an external source\n";
	}
}

1;
