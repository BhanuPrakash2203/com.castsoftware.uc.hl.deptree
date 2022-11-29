package framework::yarnFile;

######################################################################################
#
# PARSER for yarn.lock file
#
######################################################################################

use strict;
use warnings;

use framework::dataType;
use framework::detections;
use framework::Logs;
use Lib::Sources;

# my $DEBUG = 0;

my @dependencies = ();

use constant RECORD_DEFAULT => 0;
use constant RECORD_DEPENDENCIES => 1;

sub init() {
	@dependencies = ();
}

sub parseVERSION($$$$) {
	my $filename = shift;
	my $content = shift;
	my $componentName = shift;
	my $H_detections = shift;

	my $item;

	# check if content is a line or a line block
	if (ref($content) eq "SCALAR") {
		my $pos = pos($$content);
		$content = ${$content};
		pos($content) = $pos;
	}

	while ($content =~ /^(\s+([\w\-]+)\s*\"[\~\^]?(.*)\"\s*$)|[^\n]/gm) {
		# empty line => end of the section
		if (!defined $2 && !defined $3) {
			return;
		}
		else {
			my $param = $1;
			$item = $2;
			my $numVersion = $3;
			# /!\ dependency must be in H_detections from package-lock.json or package.json file scan
			if ($numVersion =~ /\S/ && exists $H_detections->{$componentName}) {
				if ($item eq 'version') {
					# TODO: may be a future step: compare version
					# my ($compare, $finest) = framework::version::compareVersion($min, $ver);
					
					# for instance:
					# replace version value by component version present in yarn.lock file
					# we keep version of yarn file which is closer than application root
					$H_detections->{$componentName}->[0]->{'min'} = $numVersion;
					$H_detections->{$componentName}->[0]->{'max'} = $numVersion;
					$H_detections->{$componentName}->[0]->{'artifact'} = File::Spec->catfile($filename);
					$H_detections->{$componentName}->[0]->{'environment'} = 'yarn';
				}
			}
		}
	}
}

sub parseYarnFile($$$) {
	my $filename = shift;
	my $content = shift;
	my $H_detections = shift;

	my $componentName;
	while ($$content =~ /\G(.*)\n/gc) {
		my $line = $1;
		if ($line =~ /^\"?(\@?[\/\w\-\.]+)/m) {
			# print "\nRootDependency = $1\n";
			$componentName = $1
		}
		elsif ($line =~ /^\s+(\w+)/) {
			if ($1 eq 'version') {
				# print "version!!!!\n";
				parseVERSION($filename, $line, $componentName, $H_detections);
			}
		}
	}
}

sub yarnFile($$$$) {
	my $filename = shift;
	my $yarnfile_DB = shift;
	my $H_DatabaseName = shift;
	my $H_detections = shift;

	init();

	framework::Logs::printOut("yarn.lock : $filename\n");
	my $content = Lib::Sources::getFileContent($filename);
	if (!defined $content) {
		framework::Logs::Warning("Unable to read $filename for yarn.lock inspection purpose.\n");
		return undef;
	}
	print "\n* Parsing ".File::Spec->catfile($filename)."\n";
	parseYarnFile($filename, $content, $H_detections);

	# for my $dep (@DEPENDENCIES_section) {
	# 	if (!defined $H_names{$dep->{'name'}}) {
	# 		framework::Logs::Warning("DEPENDENCY $dep->{'name'} is missing\n");
	# 	}
	# }

	# my @itemDetections = ();
	# print "* Checking dependencies\n*************\n";
	# for my $dep (@dependencies) {
	# 	# For Memory : $H_DatabaseName is a HASH of all framework name in ower case, available for the technology concerned (here java).
	# 	my $yarnFileItem = framework::detections::getEnvItem($dep->{'name'}, $dep->{'version'}, $yarnfile_DB, 'yarn.lock', $filename, $H_DatabaseName);
	#
	# 	if (defined $yarnFileItem) {
	# 		push @itemDetections, $yarnFileItem;
	# 	}
	# }

	framework::Logs::Debug("-- End yarn.lock detection-- \n");
	#return \@itemDetections;
}

1;
