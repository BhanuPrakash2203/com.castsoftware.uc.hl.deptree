package CloudReady::detection;

use strict;
use warnings;
use AnalyseOptions;
use AnalyseUtil;
use File::Spec;

use CloudReady::config;

#use framework::Logs;

my %H_Detector = ();
my $tabSourceDir = undef;

my $CloudReadyDetectionActivated = 0;

my %H_AVAILABLE_FILE_MNEMOS = ();

my $CURRENT_FILE_NAME = "";
my $CURRENT_TECHNO = "";
my %FILE_DATA = ();
my %APPLI_DATA = ();

my $OUTPUT_FILE_NAME = undef;
my $OUTPUT_FILE_HANDLER = undef;

my $META_DATA = undef;

# TEST getter ...
sub getCurrentFileCounter($) {
	my $mnemo = shift;
	return $FILE_DATA{$mnemo};
}
sub getCurrentAppliCounter($) {
	my $mnemo = shift;
	return $APPLI_DATA{$mnemo};
}

sub loadAvailableFileMnemo($) {
	my $techno = shift;
	for my $mnemo (@{CloudReady::config::getFileMnemoList($techno)}) {
		$H_AVAILABLE_FILE_MNEMOS{$mnemo} = 1;
	}
}

sub printTechnoHeader($) {
	my $techno = shift;
	print $OUTPUT_FILE_HANDLER "section=$techno\n";
	print $OUTPUT_FILE_HANDLER "Dat_FileName;";
	print $OUTPUT_FILE_HANDLER "Dat_AbortCause;";
	for my $mnemo (@{CloudReady::config::getFileMnemoList($techno)}) {
		print $OUTPUT_FILE_HANDLER "$mnemo;";
	}
	print $OUTPUT_FILE_HANDLER "\n";
}

sub setCurrentTechno($) {
	$CURRENT_TECHNO = shift;
	%H_AVAILABLE_FILE_MNEMOS = ();
	loadAvailableFileMnemo($CURRENT_TECHNO);
	printTechnoHeader($CURRENT_TECHNO);
}

# call for each techno analysis.
sub init($$) {
	my $options = shift;
	my $techno = shift;
	#framework::Logs::init($options);
	$CloudReadyDetectionActivated = 1;

	if (! defined $OUTPUT_FILE_HANDLER) {
		if (defined $OUTPUT_FILE_NAME) {
			my $ret = open($OUTPUT_FILE_HANDLER, ">$OUTPUT_FILE_NAME");
			if (! defined $ret) {
				print "[CloudReady::detection::init] ERROR : unable to open output file name $OUTPUT_FILE_NAME...\n";
			}

			# print metadat header
			if (defined $META_DATA) {
				print $OUTPUT_FILE_HANDLER("#CloudReady\n");
				print $OUTPUT_FILE_HANDLER("#uuid;".$META_DATA->{"uuid"}."\n");
				print $OUTPUT_FILE_HANDLER("#start_date;".$META_DATA->{"start_date"}."\n");
				print $OUTPUT_FILE_HANDLER("#version_highlight;".$META_DATA->{"version_highlight"}."\n");
			}

			# print mnemo list
			print $OUTPUT_FILE_HANDLER "FILE SECTION\n\n";
		}
		else {
			print "[CloudReady::detection::init] ERROR : output file name is undefined ...\n";
		}
	}

	setCurrentTechno($techno);
}

# Declare a new file being processed
# - commit data of previous file
# - init data for new current file.
sub setCurrentFile($) {
	if ((defined $CURRENT_FILE_NAME) && ($CURRENT_FILE_NAME ne "")) {
		commitCurrentFile();
	}
	$CURRENT_FILE_NAME = shift;
	%FILE_DATA = ();
}

sub setAbortCause($) {
	$FILE_DATA{'Dat_AbortCause'} = shift;
}

sub commitCurrentFile() {
	print $OUTPUT_FILE_HANDLER "$CURRENT_FILE_NAME;";
	print $OUTPUT_FILE_HANDLER $FILE_DATA{'Dat_AbortCause'}.";";
	for my $mnemo (@{CloudReady::config::getFileMnemoList($CURRENT_TECHNO)}) {
		if (defined $FILE_DATA{$mnemo}) {
			print $OUTPUT_FILE_HANDLER $FILE_DATA{$mnemo}.";";
		}
		else {
			print "[CloudReady::detection] WARNING : file $CURRENT_FILE_NAME has no value for mnemmo $mnemo. Assuming 0 ...\n";
			print $OUTPUT_FILE_HANDLER "0;";
		}
	}
	print $OUTPUT_FILE_HANDLER "\n";
}

sub addFileDetection($$$) {
	my $file = shift;
	my $mnemo = shift;
	my $value = shift;

	if (! exists $H_AVAILABLE_FILE_MNEMOS{$mnemo}) {
		print "[CloudReady::detection::addFileDetection] ERROR : unknow detection mnemo : $mnemo ...\n";
	}
	else {
		# store data
		$FILE_DATA{$mnemo} = $value;
	}
}

sub addAppliDetection($$) {
	my $mnemo = shift;
	my $data = shift;

	if (!exists $APPLI_DATA{$mnemo}) {
		$APPLI_DATA{$mnemo} = [];
	}

	if (ref $data eq "SCALAR") {
		push @{$APPLI_DATA{$mnemo}}, $data;
	}
	else {
		push @{$APPLI_DATA{$mnemo}}, @$data;
	}
}

sub setTabSourceDir($) {
	$tabSourceDir = shift;
}

sub setOutputFileName($) {
	my $outfile = shift;
	print "[CloudReady] output file set to $outfile.\n";
	$OUTPUT_FILE_NAME = $outfile;
	my $outputDir = $outfile;
	$outputDir =~ s/[^\\\/]*$//;
}

sub setMetaData($) {
	$META_DATA = shift;
}

sub dumpAppliDetections() {
	print $OUTPUT_FILE_HANDLER "\nAPPLI SECTION\n";
	for my $mnemo (@{CloudReady::config::getAppliMnemoList($CURRENT_TECHNO)}) {
		# print mnemo in column 0
		print $OUTPUT_FILE_HANDLER "$mnemo;";
		
		if (exists $APPLI_DATA{$mnemo}) {
			my $numberOfFiles = scalar @{$APPLI_DATA{$mnemo}};
			print $OUTPUT_FILE_HANDLER "$numberOfFiles;";
		}
		else {
			print $OUTPUT_FILE_HANDLER "0;";
		}

		# print data related to detections
		my $lastElmt = $APPLI_DATA{$mnemo}->[-1];
		for my $data (@{$APPLI_DATA{$mnemo}}) {
			if ($data ne $lastElmt) {
				print $OUTPUT_FILE_HANDLER "$data\,";
			}
			else {
				print $OUTPUT_FILE_HANDLER "$data";
			}
		}
		print $OUTPUT_FILE_HANDLER "\n";
	}
}

sub dumpCloudReadyDetectionResults() {
	if (! $CloudReadyDetectionActivated) {
		print "[CloudReady::detection] INFO: no CloudReady detection results to dump...\n";
	}
	else {
		commitCurrentFile();
		dumpAppliDetections();
		close $OUTPUT_FILE_HANDLER;
	}
}

sub dumpScanLog($$$$) {
	my $techno = shift;
	my $SCAN_LOG = shift;
	my $srcDir = shift; # from --dir-source CLI parameter

	#my $parameters = AnalyseUtil::recuperer_options();
	#my $outdir = $parameters->[0]->{'--dir'};
	my $outdir = shift;
	
	if (defined $outdir) {
		my $logfile = File::Spec->catfile($outdir, "cloudDetail_$techno.csv");
		open(LOG, ">$logfile");
		print LOG "[$techno] Scan " . localtime() . "\n";
		print LOG "[dir project] " . File::Spec->catfile($srcDir) . "\n";
		print LOG "\nAlert;Path;LineNumberPos;Url_doc\n";
		# 1st sort by alerts
		foreach my $alert (sort keys %{$SCAN_LOG}) {
			# 2nd sort by filenames
			foreach my $filename (sort keys %{$SCAN_LOG->{$alert}}) {
				foreach my $path (keys %{$SCAN_LOG->{$alert}->{$filename}}) {
					my $pathLabel = File::Spec->catfile($path);
					my $numLinePos = $SCAN_LOG->{$alert}->{$filename}->{$path}->[0];
					# 3rd sort by numline & positions
					my @numLinePos = split(/\|/, $numLinePos);
					$numLinePos = "";
					foreach my $elt (sort {(split(/\[/,$a))[0] <=> (split(/\[/,$b))[0]} @numLinePos) {
						$numLinePos .= $elt."\|";
					}
					chop $numLinePos;
					print LOG "\"$alert\";$pathLabel;$numLinePos;$SCAN_LOG->{$alert}->{$filename}->{$path}->[1]";
					print LOG "\n";
				}
			}
		}
		close LOG;
	}
}


1;

