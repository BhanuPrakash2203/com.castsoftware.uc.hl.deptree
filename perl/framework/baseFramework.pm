package framework::baseFramework;

use strict;
use warnings;
use framework::detections;
use framework::importExternal;
use framework::dataType;
use framework::Logs;
use framework::projectFiles;
use framework::combinations;

my %H_detections = ();

sub reset_detections() {
	%H_detections = ();
}

sub getDetections() {
	return \%H_detections;
}

sub default_scanning_callback($$) {
	my $pattern = shift;
	my $buffer = shift;
	my $output_data = shift;
	
	if ( $$buffer =~ /($pattern)/s) {
		#found and stop.
		return (1, $1);
	}
	# not found
	return 0;
}

sub store_result($;$) {
	my $self = shift;
	my $H_FileDetection = shift;
	my $merge_callback = shift;

	framework::detections::store_result($self->{'techno'}, $H_FileDetection, $merge_callback);
}

sub new ($$$$) {
	my $class = shift;
	my $techno = shift;
	my $DB = shift;
	my $tabSourceDir = shift;

	if (!defined $DB) {
		$DB = {};
	}
	
	my $self = {
		'techno' 		=> $techno,
		'tabSourceDir'	=> $tabSourceDir,
		'DB'	=> $DB,
	};
	
	framework::importExternal::loadExternalFromPackage($techno, $self->{'DB'});
	
	bless ($self, $class);
	return $self;
}

sub loadUserDefinedFramework($$) {
	my $self = shift;
	my $file = shift;
	
	my ($DB, $errorcode) =  framework::importExternal::loadExternalfromCsv($file);

	# errorcode :
	#	1 : framework version inconsistency
	#	2 : framework file I/O error (not found , ...)

	if ($errorcode) {
		framework::Logs::Error("Unable to import from $file due to data inconsitencies. Please fix and retry.\n");
		return;
	}
	
	framework::Logs::printOut("Frameworks from $file successfully imported.\n");
	
	# merge the part of the DB correspon,ding to the expected techno, into the detector's DB ...
	framework::importExternal::mergeExternal($self->{'DB'}, $DB->{$self->{'techno'}});
}

sub mergeInsideSourceDetection($$) {
	my $self= shift;
	my $H_FileDetections = shift;
	my $merge_callback = shift;
	
	if (!defined $merge_callback) {
		$merge_callback = \&default_merge_callback;
	}
	
	for my $frameworkName (keys %$H_FileDetections) {
		my $detections = $H_FileDetections->{$frameworkName};
		
		if (! exists $H_detections{$frameworkName}) {
			$H_detections{$frameworkName} = [];
		}
		
		my $mergedFrameworkDetection = $H_detections{$frameworkName};
		
		for my $detect (@$detections) {
			# First detection of the framework ? 
			if (scalar @{$mergedFrameworkDetection} == 0) {
				# yes, first recording, store as is !!
				push @{$mergedFrameworkDetection}, $detect;
			}
			else {
				# it's an additional recording, should merge & update !!
				# NOTE : mergedFrameworkDetection contain only one detection (the merged !!) but
				#        its type is array (by compatibility with detection structure). So, we work
				#        directly with the first element of the detection array ($mergedFrameworkDetection->[0])
				my $errorMessage = $merge_callback->($mergedFrameworkDetection->[0], $detect);
				if ( defined $errorMessage) {
					framework::Logs::printOut "ERROR when merging data for <$frameworkName>. $errorMessage\n";
				}
			}
		}
	}
}



sub preAnalysisDetection($) {
	my $self = shift;
	my $fileList = shift;
}

# Manage searching of ITEMS in a file source, whose views are given in parameters
# OUTPUT : a structure of all detections discovered in the file.
sub insideSourceDetection($$$;$) {
	my $self = shift;
	my $views = shift;
	my $filename = shift;
	my $merge_result = shift;
	
	if (! defined $merge_result) {
		$merge_result = 1;
	}
	
	my %H_FileDetection = ();
	
	# the default patterns environment is the source code. This is the environment we should use here.
	my $PatternsEnv = $self->{'DB'}->{$framework::dataType::DEFAULT_ENVIRONMENT};
	
	# for each item to seach
	for my $item (keys %{$PatternsEnv->{'PATTERNS'}}) {
		framework::Logs::Debug("scanning source code for $item ...\n");
		
		# get the item fields description
		my $item_def  = $PatternsEnv->{'PATTERNS'}->{$item};
		my $patterns  = $item_def->[$framework::dataType::IDX_PATTERNS];
		my $view;
		if (defined $item_def->[$framework::dataType::IDX_SELECTORS]) {
			$view = $item_def->[$framework::dataType::IDX_SELECTORS]->[0];
		}
		
		# init callback to use ...
		my $callback;
		if (! defined $callback) {
			$callback = \&default_scanning_callback;
		}
		# search if a view is defined ...
		if (! defined $view) {
			$view = 'code';
		}

		# get the view ...
		my $view_buffer;
		if (defined $views->{$view}) {
			$view_buffer = \$views->{$view};
		}
		else {
			framework::Logs::Error("Unable to find view $view\n");
			return undef;
		}
		
		# try to find all pattern describing the item ...
		my $return_value;
		my $matched_pattern;
		my $found = 0;
		for my $pattern (@$patterns) {

			# call the scanning callback.
			($return_value, $matched_pattern) = $callback->($pattern, $view_buffer);
			
			# expected return code:
			# 0: not found.
			# 1: found and stop scanning
			# 2: found and continue scanning
			if ($return_value == 0) {
				# not found : continue ...
				next;
			}
			elsif ($return_value == 1) {
				# found, and useless to scan other patterns ...
				framework::Logs::Debug("--> found pattern $matched_pattern.\n");
				$found = 1;
				last;
			}
			elsif ($return_value == 2) {
				# found, but continue scanning other patterns ...
				$found = 1;
			}
		}
		
		# Current item has been found (with detection of current pattern)?
		if ($found == 1) {
			# yes ==> build associated results
			# So the item is considered found : associate it with the datas resulting of each pattern tested.
			
			my $itemResult = {};
			$itemResult->{'framework_name'} = $item_def->[$framework::dataType::IDX_NAME];
			$itemResult->{'data'}->{$framework::dataType::ITEM} = $item_def->[$framework::dataType::IDX_ITEM];
			$itemResult->{'data'}->{$framework::dataType::MIN_VERSION} = $item_def->[$framework::dataType::IDX_MIN];
			$itemResult->{'data'}->{$framework::dataType::MAX_VERSION} = $item_def->[$framework::dataType::IDX_MAX];
			$itemResult->{'data'}->{$framework::dataType::MATCHED_PATTERN} = $matched_pattern;
			$itemResult->{'data'}->{$framework::dataType::EXPORTABLE} = $item_def->[$framework::dataType::IDX_EXPORTABLE];
			$itemResult->{'data'}->{$framework::dataType::ENVIRONMENT} = 'code';
			$itemResult->{'data'}->{$framework::dataType::STATUS} = $framework::dataType::STATUS_DISCOVERED;
			$itemResult->{'data'}->{$framework::dataType::ARTIFACT} = $filename;
			

			
			# FIXME : should add data in @result_datas
			#         if some fields are redefining above keys (like version ...) then use them in priority !
			
			# FIXME : if there are associated item to search (i.e $item_def->[$IDX_RELATED] defined), then add them to the item list.
			#         it will the be insideSourceDetection routine responsibility to associate the detections and refine datas like version for example ...
			
			# REPLACED ...
			#if (!exists $H_FileDetection{$itemResult->{'framework_name'}}) {
			#	$H_FileDetection{$itemResult->{'framework_name'}} = [];
			#}
			#push @{$H_FileDetection{$itemResult->{'framework_name'}}}, $itemResult->{'data'};
			#framework::detections::referenceDetectedItem($itemResult->{'data'}->{$framework::dataType::ITEM});
			
			# ... WITH :
			framework::detections::addItemDetection(\%H_FileDetection, $itemResult);
		}
	}

	# check if the detections of the current file should be merged in global data.
	# $merge_result is OK by default. 
	# It is KO if it has been defined false in a customized Framework module www_FW.pm. In this case it is the responsibility of this module to call mergeInsideSourceDetection().
	if ($merge_result) {
		$self->mergeInsideSourceDetection(\%H_FileDetection, \&framework::detections::default_merge_callback);	
	}
	
	# return a hash whose keys are the item found !
	return \%H_FileDetection;
}

sub postAnalysisDetection($) {
	my $self = shift;

	# store detections found inside the code of all sources files.
	$self->store_result(\%H_detections);
	
	#scan project file
	my $H_ProjectFilesDetection = framework::projectFiles::detect($self->{'tabSourceDir'}, $self->{'DB'}, $self->{'techno'});
	# store the results.
	$self->store_result($H_ProjectFilesDetection);
	
	# detect framework from combinations
	my $H_CombinationsDetection = framework::combinations::detect($self->{'tabSourceDir'}, $self->{'DB'});
	# store the results.
	$self->store_result($H_CombinationsDetection);
	
}

1;
