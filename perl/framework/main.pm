package framework::main;

use strict;
use warnings;
use AnalyseOptions;
use framework::detections;
use framework::baseFramework;
use framework::Logs;

my %H_Detector = ();
my $tabSourceDir = undef;

my $frameworkDetectionActivated = 0;

sub init($) {
	my $options = shift;
	framework::Logs::init($options);
	$frameworkDetectionActivated = 1;
}

sub setTabSourceDir($) {
	$tabSourceDir = shift;
}

sub setOutputFileName($;$) {
	my $outfile = shift;
	my $options = shift;
	
	print "[framework] output file set to $outfile.\n";
	framework::detections::setOutputFileName($outfile, $options);
	my $outputDir = $outfile;
	$outputDir =~ s/[^\\\/]*$//;
	framework::Logs::setOutputDirectory($outputDir);
}

sub dumpFrameworkDetectionResults() {
	framework::detections::dump();
}

sub load($$;$) {
	my $techno = shift;
	my $tabSourceDir = shift;
	my $options = shift;
	
	my $detector = undef;
	
	print "\n***** FrameWorkDetection *****\n";
	
	my $plugin_name = $techno."_FW";
	
	my $module = "framework/$plugin_name.pm";

	my $toolpath = $0;
	$toolpath =~ s/[^\\\/]*$//;
	$toolpath =~ s/[\\\/]$//;
	
	# modification in case the modules is instancied from test environnement, that would change the value of $0
	$toolpath =~ s/\bAnalyzersTests[\\\/]framework\b/Analyzers/;

	if (! -f $toolpath."/".$module) {
		#print "[framework] no framework detection plugin found for $techno.\n";
		
		# return a default framework detector.
		$detector = framework::baseFramework->new($techno, {}, $tabSourceDir);
	}
	else {
		eval {
			require $module;
		};
		if ($@)	{
			print STDERR "[framework] unable to load module: $module. ($@)\n" ;
			return undef;
		}
	
		print "[framework] plugin loaded successfully.\n";
	
		my $frameworkDetector_class = "framework::$plugin_name";
		my $frameworkDetector = $frameworkDetector_class->new($techno, $tabSourceDir);

		print "\n";

		$detector = $frameworkDetector;
	}

	if ((defined $options) && (exists $options->{'--user-frameworks'})) {
		$detector->loadUserDefinedFramework($options->{'--user-frameworks'});
	}

	return $detector;
}

sub getDetector($$) {
	my $techno = shift;
	my $options = shift;
	
	if (! $frameworkDetectionActivated) {
		print "[framework] warning : detection is not activated because framework::main::init() has not been called !!\n";
		return undef;
	}
	
	# if $techno is initialized with the name of the analyseur, retrieves the name of the techno by removing the suffix "Ana" !! 
	$techno =~ s/\AAna//;
	
	my $technoUsed = $techno;
	if ($technoUsed eq "TypeScript") {
		$technoUsed = 'JS';
	}
	
	if (exists $H_Detector{$technoUsed}) {
		return $H_Detector{$technoUsed};
	}
	
	my $detector = framework::main::load($technoUsed, $tabSourceDir, $options);

	$H_Detector{$techno} = $detector;

	return $H_Detector{$techno};
}

1;
