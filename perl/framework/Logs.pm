package framework::Logs;

my $DEBUG =0;
my $outputDirectory = "./";

sub init($) {
	my $options = shift;
	if (defined $options->{'--framework-debug'}) {
		$DEBUG = 1;
	}
}

sub setOutputDirectory($) {
	$outputDirectory = shift;
}

sub getOutputDirectory() {
	return $outputDirectory;
}

sub isDebugOn() {
	return $DEBUG;
}

sub Error($) {
	my $msg = shift;
	
	print STDERR "[framework] ERROR : $msg";
}

sub Warning($) {
	my $msg = shift;
	
	print STDERR "[framework] WARNING : $msg";
}

sub printErr($) {
	my $msg = shift;
	
	print STDERR "[framework] $msg";
}

sub Debug($) {
	my $msg = shift;
	
	print STDERR "[framework] $msg" if ($DEBUG);
}

sub printOut($) {
	my $msg = shift;
	
	print "[framework] $msg";
}

1;
