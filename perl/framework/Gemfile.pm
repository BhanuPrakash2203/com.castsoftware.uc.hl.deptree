package framework::Gemfile;

######################################################################################
#
# UNDERSTANDING Gemfile.lock
#
# https://stackoverflow.com/questions/7517524/understanding-the-gemfile-lock-file
#
######################################################################################

use strict;
use warnings;
 
use framework::dataType;
use framework::detections;
use framework::Logs;
use Lib::Sources;

my $DEBUG = 0;

my @dependencies = ();
my %H_names = ();

my @DEPENDENCIES_section = ();

use constant RECORD_DEFAULT => 0;
use constant RECORD_DEPENDENCIES => 1;

sub init() {
	@dependencies = ();
}

my %action = ('specs' => \&parseSpecs);

sub parseSpecs($$) {
	my $param = shift;
	my $mode = shift || RECORD_DEFAULT;

	if ($param =~ /^(\s+)([\w\-]+)\s*(?:(\([^\)]+\))|(!)|(.*))?/m) {
		my $indentation = $1;
		my $name = $2;
		my $version = $3;
		my $slash = $4; # The exclamation mark appears when the gem was installed using a source other than "https://rubygems.org".
		my $other = $5; # not a VERSION nor EXCLAMATION MARK syntax
		
		if ($mode == RECORD_DEFAULT) {
			push @dependencies, {'name' => $name, 'version' => $version};
			$H_names{$name} = 1;
		}
		elsif ($mode == RECORD_DEPENDENCIES) {
#print "ADD dependencie : $name !!!\n";
			push @DEPENDENCIES_section, {'name' => $name, 'version' => $version};
		}
	}
	else {
		framework::Logs::Warning("Unknow dependency format : $param\n");
	}
}

sub applyAction($$$) {
	my $item = shift;
	my $param = shift;
	my $mode = shift;
	
	if (defined $action{$item}) {
		$action{$item}->($param, $mode);
	}
}

sub parseSection($;$) {
	my $content = shift;
	my $mode = shift;
	
	my $item = "specs";

	if (ref $content ne 'SCALAR') {
		return;
	}

	my $line;
	# matches only line beginning with a space
	while ($$content =~ /\G([ \t]+[^\s].*)\n/gc) {
		$line = $1;
		#if ($line !~ /\S/) {
			#print "==============> WHITE LINE !!!\n";
		#}
		#else {
			#print "::::::::::$line\n";
		#}
		if ($line =~ /^\s*(\w+)\s*:(.*)$/m) {
			$item = $1;
			my $param = $2;
			if ($param =~ /\S/) {
				applyAction($item, $param, $mode);
			}
		}
		else {
			# use previous action item.
			applyAction($item, $line, $mode);
		}
	}
}

sub parseGIT($) {
	return parseSection(shift);
}

sub parseGEM($) {
	return parseSection(shift);
}

sub parsePATH($) {
	return parseSection(shift);
}

sub parseDEPENDENCIES($) {
	# SUMMARY OF DEPENDENCIES PLANNED BY THE DEVELOPPER.
	return parseSection(shift, RECORD_DEPENDENCIES);
}

sub parseGemfile($) {
	my $content = shift;
	
	while ($$content =~ /\G(.*)\n/gc) {
		my $line = $1;
		if ($line =~ /^(\w+)/) {
print "SECTION = $1\n";
			if ($1 eq 'GEM') {
				parseGEM($content);
			}
			elsif ($1 eq 'PATH') {
				parsePATH($content);
			}
			elsif ($1 eq 'GIT') {
				parsePATH($content);
			}
			elsif ($1 eq 'DEPENDENCIES') {
				parseDEPENDENCIES($content);
			}
		}
	}
}

sub gemfile($$$) {
	my $filename = shift;
	my $gemfile_DB = shift;
	my $H_DatabaseName = shift;
	
	init();
	
	framework::Logs::printOut("******************** GEMFILE : $filename*************************\n");
	my $content = Lib::Sources::getFileContent($filename);
	if (! defined $content) {
		framework::Logs::Warning("Unable to read $filename for gemfile inspection purpose.\n");
		return undef;
	}
print "************ PARSING gemfile.lock ******************\n";
	parseGemfile($content);

	for my $dep (@DEPENDENCIES_section) {
		if (defined $H_names{$dep->{'name'}}) {
			#print "DEPENDENCY $dep->{'name'} OK\n";
		}
		else {
			print "DEPENDENCY $dep->{'name'} is missing !!!\n";
		}
	}

	my @itemDetections = ();
print "******************* Checking dependencies *******************\n";
	for my $dep (@dependencies) {
		# For Memory : $H_DatabaseName is a HASH of all framework name in ower case, available for the technology concerned (here java).
		my $gemfileItem = framework::detections::getEnvItem($dep->{'name'}, $dep->{'version'}, $gemfile_DB, 'gemfile', $filename, $H_DatabaseName);
	
		if (defined $gemfileItem) {
			
			push @itemDetections, $gemfileItem;
		}
	}
	
	framework::Logs::Debug("-- End GEMFILE detection-- \n");
	return \@itemDetections;
}

1;
