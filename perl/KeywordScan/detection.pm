package KeywordScan::detection;

use strict;
use warnings;
use AnalyseOptions;
use AnalyseUtil;

use KeywordScan::config;
use KeywordScan::parseKeywordDescription;
use KeywordScan::detector;
use KeywordScan::projectFiles;
use KeywordScan::Count;

my $KeywordsDescriptors = {};


my $INITIALIZED = 0;
my %H_DETECTORS = ();
my $DAT_ABORT_CAUSE = "";

my $tabSourceDir = undef;

my $KeywordScanDetectionActivated = 0;

my %TAB_PROJECT_FILES;
my $CURRENT_FILE_NAME = "";
my $CURRENT_FILE_IDX = 0;

my $CURRENT_TECHNO = "";
my %APPLI_DATA = ();

my $OUTPUT_FILE_NAME = undef;
my $OUTPUT_FILE_HANDLER = undef;

my $META_DATA = undef;
my $XML_version;

# TEST getter ...
#sub getCurrentFileCounter($) {
#	my $mnemo = shift;
#	return $FILE_DATA{$mnemo};
#}

#sub getCurrentAppliCounter($) {
#	my $mnemo = shift;
#	return $APPLI_DATA{$mnemo};
#}

sub getKeywordDescriptor($) {
	my $name = shift;
	
	return $KeywordsDescriptors->{$name};
}

sub getKeywordDetectors() {
	return \%H_DETECTORS;
}


sub printTechnoHeader($) {
	my $techno = shift;
	print $OUTPUT_FILE_HANDLER "section=$techno\n";
	print $OUTPUT_FILE_HANDLER "Dat_FileName;";
	print $OUTPUT_FILE_HANDLER "Dat_AbortCause;";
	for my $mnemo (@{KeywordScan::config::getFileMnemoList($techno)}) {
		print $OUTPUT_FILE_HANDLER "$mnemo;";
	}
	print $OUTPUT_FILE_HANDLER "\n";
}

sub setCurrentTechno($) {
	$CURRENT_TECHNO = shift;
}

# call for each techno analysis.
sub init($$) {
	my $options = shift;
	my $techno = shift;
	
	return if $INITIALIZED;
	
	$INITIALIZED = 1;
	
	# treat options
	my $KeywordScan = $options->{'--KeywordScan'};
	if (defined $KeywordScan) {
		my @files = split ",", $KeywordScan;
		$KeywordsDescriptors = KeywordScan::parseKeywordDescription::parse(\@files);
		
		# create detectors
		for my $detectorName (keys %$KeywordsDescriptors) {
			print "[KeywordScan] Detecting keywordGroup: $detectorName\n";
			$H_DETECTORS{$detectorName} = KeywordScan::detector->new($detectorName, $KeywordsDescriptors->{$detectorName});
		}
	}
		
	#framework::Logs::init($options);
	$KeywordScanDetectionActivated = 1;
	
	setCurrentTechno($techno);
}

# Declare a new file being processed
# - init data for new current file.

# sub setCurrentFile($) {
	# $CURRENT_FILE_NAME = shift;
	# push @TAB_FILES, $CURRENT_FILE_NAME;
	# $DAT_ABORT_CAUSE = "";
	# return $CURRENT_FILE_IDX++;
# }


sub setCurrentFileNew($$) {
	my $scanName = shift;
	$CURRENT_FILE_NAME = shift;
	
	if (not exists $TAB_PROJECT_FILES{$scanName}{$CURRENT_FILE_NAME})
	{	
		$CURRENT_FILE_IDX++;
		$TAB_PROJECT_FILES{$scanName}{$CURRENT_FILE_NAME} = $CURRENT_FILE_IDX;
	}
	$DAT_ABORT_CAUSE = "";
	return $CURRENT_FILE_IDX;
}


sub setAbortCause($) {
	$DAT_ABORT_CAUSE = shift;
}

sub setTabSourceDir($) {
	$tabSourceDir = shift;
}

sub setOutputFileName($) {
	my $outfile = shift;
	print "[KeywordScan] output file set to $outfile.\n";
	$OUTPUT_FILE_NAME = $outfile;
}

sub setMetaData($) {
	$META_DATA = shift;
}

sub setXmlVersion($) {
	$XML_version = shift;
}

sub addAppliDetection($$) {
	my $detectorName = shift;
	my $patternID = shift;

	if (!exists $APPLI_DATA{$detectorName}{$patternID}) {
		$APPLI_DATA{$detectorName}{$patternID} = 0;
	}

	$APPLI_DATA{$detectorName}{$patternID}++;

	return \%APPLI_DATA;
}

########################### DUMP ###########################

sub dumpKeywordProperties($) {
	my $scanName = shift;

	my $keywordsDescr = getKeywordDescriptor($scanName);

	print $OUTPUT_FILE_HANDLER "\nFORMULA SECTION\n";

	if ($XML_version->{$scanName} eq "keywordGroup") {
		print $OUTPUT_FILE_HANDLER "name;weight;sensitive;full_word;syntax;scope\n";
	}
	else {
		print $OUTPUT_FILE_HANDLER "name;weight;sensitive;full_word;syntax\n";
	}

	for my $description (@$keywordsDescr) {
		print $OUTPUT_FILE_HANDLER "$description->[0];";
		print $OUTPUT_FILE_HANDLER "$description->[1]->{'weight'};";
		print $OUTPUT_FILE_HANDLER "$description->[1]->{'sensitive'};";
		print $OUTPUT_FILE_HANDLER "$description->[1]->{'full_word'};";
		my $formula = $description->[1]->{'formula'};

		if (lc($formula) eq "invalid") {
			print $OUTPUT_FILE_HANDLER "invalid;";
		}
		elsif (lc($formula) eq "") {
			print $OUTPUT_FILE_HANDLER "\-;"; # keywordGroup version
		}
		else {
			print $OUTPUT_FILE_HANDLER "valid;";
		}

		if ($XML_version->{$scanName} eq "keywordGroup") {
			defined $description->[1]->{'scope'}
				? print $OUTPUT_FILE_HANDLER "$description->[1]->{'scope'};"
				: print $OUTPUT_FILE_HANDLER "-;";

		}

		print $OUTPUT_FILE_HANDLER "\n";
	}
	print $OUTPUT_FILE_HANDLER "\n";
}

sub dumpKeywordScanDetectionResults() {
	if (!$KeywordScanDetectionActivated) {
		print "[KeywordScan::detection] INFO: no KeywordScan detection results to dump...\n";
	}
	else {

		for my $detectorName (keys %H_DETECTORS) {

			my $file = $OUTPUT_FILE_NAME;
			$file =~ s/\.([^\.]*)$/\.$detectorName\.$1/m;
			my $ret = open($OUTPUT_FILE_HANDLER, ">$file");
			if (!defined $ret) {
				print "[KeywordScan::detection::init] ERROR : unable to open output file name $file...\n";
			}

			# print metadat header
			if (defined $META_DATA) {
				print $OUTPUT_FILE_HANDLER("#KeywordScan; $detectorName\n");
				if (exists $XML_version->{$detectorName}) {
					print $OUTPUT_FILE_HANDLER("#Type; $XML_version->{$detectorName}\n");
				}
				else {
					print $OUTPUT_FILE_HANDLER("#Type; unknown version\n");
				}
				print $OUTPUT_FILE_HANDLER("#uuid;" . $META_DATA->{"uuid"} . "\n");
				print $OUTPUT_FILE_HANDLER("#start_date;" . $META_DATA->{"start_date"} . "\n");
				print $OUTPUT_FILE_HANDLER("#version_highlight;" . $META_DATA->{"version_highlight"} . "\n");
			}

			# print mnemo list
			# cleanFilesDetections($detectorName);
			dumpKeywordProperties($detectorName);
			dumpFilesDetections($detectorName);
			dumpFormulaResult($detectorName);
			close $OUTPUT_FILE_HANDLER;
		}
	}
}

sub dumpFilesDetections($) {
	my $scanName = shift;
	print "[KeywordScan] report: CSV [$scanName]\n";
	my $detector = $H_DETECTORS{$scanName};

	# get detected keywords list
	my $TAB_DETECTED_KEYWORDS = $detector->getTabKeywords();

	# print the header
	print $OUTPUT_FILE_HANDLER "\nFILE SECTION\n";
	print $OUTPUT_FILE_HANDLER "Dat_FileName;Dat_AbortCause;";

	for my $keyword (sort @{$TAB_DETECTED_KEYWORDS}) {
		print $OUTPUT_FILE_HANDLER "$keyword;";
	}
	print $OUTPUT_FILE_HANDLER "\n";

	# print data
	for my $key (sort keys %{$TAB_PROJECT_FILES{$scanName}}) {
		my $file_idx = $TAB_PROJECT_FILES{$scanName}{$key};
		my $file = $key;

		if (defined $file_idx and $file) {
			my $values = $detector->getFileValues($file_idx);

			# print the file name ...
			print $OUTPUT_FILE_HANDLER "$file;";
			# print $OUTPUT_FILE_HANDLER "$DAT_ABORT_CAUSE;";
			print $OUTPUT_FILE_HANDLER "None;";
			# print associate keywords values
			for my $keyword (sort @{$TAB_DETECTED_KEYWORDS}) {
				print $OUTPUT_FILE_HANDLER "$values->{$keyword};";
			}
			print $OUTPUT_FILE_HANDLER "\n";

		}
	}
}

sub dumpFormulaResult {
	my $scanName = shift;

	my $keywordsDescr = getKeywordDescriptor($scanName);

	print $OUTPUT_FILE_HANDLER "\n";
	# print the header
	print $OUTPUT_FILE_HANDLER "\nFORMULA RESULT\n";
	print $OUTPUT_FILE_HANDLER "name;logic;\n";

	for my $description (@$keywordsDescr) {
		print $OUTPUT_FILE_HANDLER "$description->[0];";

		my $formula = $description->[1]->{'formula'};

		if (lc($formula) eq "ko") {
			print $OUTPUT_FILE_HANDLER "KO;";
		}
		elsif (lc($formula) eq ""
			or lc($formula) eq "invalid") {
			print $OUTPUT_FILE_HANDLER "\-;";
		}
		else {
			print $OUTPUT_FILE_HANDLER "OK;";
		}
		print $OUTPUT_FILE_HANDLER "\n";
	}
}

1;

