package framework::detections;

use strict;
use warnings;

use framework::dataType;
use framework::Logs;
use framework::version;
use framework::frameworksDescr;

my %H_detections = ();
my %H_insensitiveDetection = ();
my %H_itemsDetected = ();

my $outputFileName = undef;
my $options = {};

# ******************* TODO / FIXME ****************** 
# - Create  callback that do not merge if previous or new min/max version is not comparable (because of his format, undefined , ...)
#
# - For Store function, create a function that merge a list of version inside an existing list of version, with the following property :
#         - if there are several new version (associated to several detection), do not merge each other ... (useless)
#         - if a new version cannot be merged (incompatible format or produce a conflict) then simply push it on the list.

sub mergeList($$) {
	my $previousList = shift;
	my $newList = shift;
	my @newUnmerged = ();
		
	for my $new (@$newList) {
		my $merged = 0;
		my $newmodule = $new->{$framework::dataType::MODULE};
		
		for my $prev (@$previousList) {
			
			if (defined $newmodule) {
				my $prevmodule = $prev->{$framework::dataType::MODULE};
				if ((defined $prevmodule) && ($prevmodule ne $newmodule)) {
					# stop checking => since modules are different, framework are differents and do not need to be merged ...
					last;
				}
			}
			
			if (	framework::version::isComparable($new->{$framework::dataType::MIN_VERSION}) &&
					framework::version::isComparable($new->{$framework::dataType::MAX_VERSION}) &&
					framework::version::isComparable($prev->{$framework::dataType::MIN_VERSION}) &&
					framework::version::isComparable($prev->{$framework::dataType::MAX_VERSION}) ) {
				my $err = default_merge_callback($prev, $new);
				if ( ! defined $err) {
					# merge has succeded
					$merged = 1;
					last;
				}
				else {
					framework::Logs::Warning("$prev->{$framework::dataType::ITEM} / $new->{$framework::dataType::ITEM} : $err\n");
				}
			}
		}
		if (! $merged) {
			# The detection has not been merged, add it to the unmerged list ...
			push @newUnmerged, $new;
		}
	}
	# add unmerged detections ...
	push @$previousList, @newUnmerged;
}


sub default_merge_callback($$) {
	my $previousResult = shift;
	my $newResult = shift;
	
	#input results are expected to be in the following format :
	my $prevmin_text = $previousResult->{$framework::dataType::MIN_VERSION} || '';
	my $prevmax_text = $previousResult->{$framework::dataType::MAX_VERSION} || '';
	my $newmin_text = $newResult->{$framework::dataType::MIN_VERSION} || '';
	my $newmax_text = $newResult->{$framework::dataType::MAX_VERSION} || '';
	
	my $prevmin = framework::version::makeComparable($prevmin_text);
	my $prevmax = framework::version::makeComparable($prevmax_text);
	my $newmin = framework::version::makeComparable($newmin_text);
	my $newmax = framework::version::makeComparable($newmax_text);

	# merge MIN version
	if (scalar @$prevmin > 0) {
		my ($compare, $finest) = framework::version::compareVersion($prevmin, $newmin);
		if ($compare == 1) {
			# newmin > prevmin
			if (scalar @$prevmax) {
				my ($compare1, $finest1) = framework::version::compareVersion($prevmax, $newmin);
				if ( ! ( $compare1 == 1) ) {
					# !(newmin > prevmax) <=> (newmin <= prevmax)
					$previousResult->{$framework::dataType::MIN_VERSION} = $newmin_text;
				}
				else {
					return "Conflict version detected : min version ($newmin_text) is greater than max version ($prevmax_text).";
				}
			}
			else {
				# previous max is undefined, so no conflict is possible.
				$previousResult->{$framework::dataType::MIN_VERSION} = $newmin_text;
			}
		}
		elsif ((defined $finest) && ($finest == 1)) {
			# the previous min and the newmin are identical but newmin is the more accurate representation.
			$previousResult->{$framework::dataType::MIN_VERSION} = $newmin_text;
		}
	}
	else {
		# previous min is undefined, so new value is automatically valid !
		$previousResult->{$framework::dataType::MIN_VERSION} = $newmin_text;
	}
	
	# merge MAX version
	if (scalar @$prevmax > 0) {
		my ($compare, $finest) = framework::version::compareVersion($prevmax, $newmax);
		if ( $compare == -1) {
			# newmax < prevmax
			if (scalar @$prevmin) {
				my ($compare1, $finest1) = framework::version::compareVersion($newmax, $prevmin);
				if ( ! ( $compare1 == 1) ) {
					# !(newmax < prevmin) <=> (newmax >= prevmin)
					$previousResult->{$framework::dataType::MAX_VERSION} = $newmax_text;
				}
				else {
					if (scalar @$newmax > 0) {
						# not an error if newmax is not defined !!
						return "Conflict version detected : new max version ($newmax_text) is less than previous min version ($prevmin_text).";
					}
				}
			}
			else {
				# previous min is undefined, so no conflict is possible : newmax is valid.
				$previousResult->{$framework::dataType::MAX_VERSION} = $newmax_text;
			}
		}
		elsif ((defined $finest) && ($finest == 1)) {
			# the previous max and the newmax are identical but newmax is the more accurate representation.
			$previousResult->{$framework::dataType::MAX_VERSION} = $newmax_text;
		}
	}
	else {
		# previous max is empty ( not existing) : new max is valid.
		$previousResult->{$framework::dataType::MAX_VERSION} = $newmax_text;
	}
	
	$previousResult->{$framework::dataType::TYPE} = $newResult->{$framework::dataType::TYPE};
	$previousResult->{$framework::dataType::DESCRIPTION} = $newResult->{$framework::dataType::DESCRIPTION};
	
	if ($newResult->{$framework::dataType::STATUS} eq $framework::dataType::STATUS_DISCOVERED) {
		$previousResult->{$framework::dataType::STATUS} = $framework::dataType::STATUS_DISCOVERED;
	}
	
	my $newEnv = $newResult->{$framework::dataType::ENVIRONMENT};
	if ($previousResult->{$framework::dataType::ENVIRONMENT} !~ /$newEnv/) {
		$previousResult->{$framework::dataType::ENVIRONMENT} .= ",$newEnv";
	}

	return undef;
}

sub referenceDetectedItem($) {
	my $item = shift;
	$H_itemsDetected{lc($item)} = 1;
}

sub isDetected($) {
	my $item = shift;

	if (exists $H_itemsDetected{lc($item)}) {
		return 1;
	}
	return 0;
}

sub isExportableDetection($) {
	my $itemDetect = shift;
	
	return $itemDetect->{'data'}->{$framework::dataType::EXPORTABLE};
}

sub addItemDetection($$) {
	my $H_detect = shift;
	my $itemDetect = shift;
	
#	if (! isDetected($itemDetect->{'data'}->{$framework::dataType::ITEM})) {
		# Export detected item in outputed results
		if (isExportableDetection($itemDetect)) {
#print "      --> $itemDetect->{'framework_name'} is EXPORTED\n";
			framework::Logs::Debug("    --> $itemDetect->{'framework_name'} is EXPORTED\n");
			my $frameworkName = $itemDetect->{'framework_name'};
			if (! defined $H_detect->{$frameworkName}) {
				$H_detect->{$frameworkName} = [];
				push @{$H_detect->{$frameworkName}}, $itemDetect->{'data'};
				
			}
			else {
				mergeList($H_detect->{$frameworkName}, [$itemDetect->{'data'}] );
			}
		}
	
		# Reference the item as detected, even if not exported in results. This is needed
		# for combination detection environment that works with all detections.
		referenceDetectedItem($itemDetect->{'data'}->{$framework::dataType::ITEM});
#	}
#	else {
#print "      /!\\ $itemDetect->{'framework_name'} is ALREADY DETECTED\n";
#	}
}




sub createItemDetection($$$$$;$) {
	my $searchItem = shift;
	my $pattern = shift;
	my $version = shift;
	my $env = shift;
	my $status = shift;
	my $artifact = shift;

	# FIXME : remove characters that will conflict with csv format.
	$pattern =~ s/[\n;]//sg;
	# FIXME : remove useless spaces (beginning and trailing spaces).
	$pattern =~ s/^\s*//sg;
	$pattern =~ s/\s*$//sg;

	my ($mintext, $mintag)  = framework::version::getCanonicalVersion($searchItem->[$framework::dataType::IDX_MIN]);
	my ($maxtext, $maxtag) = framework::version::getCanonicalVersion($searchItem->[$framework::dataType::IDX_MAX]);
	
	if (defined $version) {
		my $ver = framework::version::makeComparable($version);
		my $min = framework::version::makeComparable($mintext);
		my $max = framework::version::makeComparable($maxtext);
		
		# compare to min.
		if (defined $mintext) {
			my ($compare, $finest) = framework::version::compareVersion($min, $ver);
			if ($compare == 1 ) {
				$mintext = $version;
			}
			elsif ($compare == 0) {
				if ($finest == 1) {
					# the new version is equal to the min, but have the more accurate representation
					$mintext = $version;
				}
			}
			else {
				my $searchID = $searchItem->[$framework::dataType::IDX_NAME].":".$env;
				framework::Logs::Warning("In project file context ($searchID), new version ($version) is less than previous min ($mintext).\n");
				$mintext = $version;
			}
		}
		else {
			$mintext = $version;
		}
		
		#compare to max.
		if (defined $maxtext) {
			my ($compare, $finest) = framework::version::compareVersion($max, $ver);
			if ($compare == -1 ) {
				# new version is less than previous max.
				$maxtext = $version;
			}
			elsif ($compare == 0) {
				if ($finest == 1) {
					# the new version is equal to the previous max, but have the more accurate representation
					$maxtext = $version;
				}
			}
			else {
				my $searchID = $searchItem->[$framework::dataType::IDX_NAME].":".$env;
				framework::Logs::Warning("In project file context ($searchID), new version ($version) is greatest than previous max ($maxtext).");
				$maxtext = $version;
			}
		}
		else {
			$maxtext = $version;
		}
	}
	my $itemResult = {};
	$itemResult->{'framework_name'} = $searchItem->[$framework::dataType::IDX_NAME];
	$itemResult->{'data'}->{$framework::dataType::ITEM} = $searchItem->[$framework::dataType::IDX_ITEM];
	$itemResult->{'data'}->{$framework::dataType::MIN_VERSION} = $mintext;
	$itemResult->{'data'}->{$framework::dataType::MAX_VERSION} = $maxtext;
	$itemResult->{'data'}->{$framework::dataType::MATCHED_PATTERN} = $pattern;
	$itemResult->{'data'}->{$framework::dataType::ENVIRONMENT} = $env;
	$itemResult->{'data'}->{$framework::dataType::EXPORTABLE} = $searchItem->[$framework::dataType::IDX_EXPORTABLE];
	$itemResult->{'data'}->{$framework::dataType::STATUS} = $status;
	$itemResult->{'data'}->{$framework::dataType::ARTIFACT} = $artifact;
	framework::Logs::Debug("--> detection of framework ".$searchItem->[$framework::dataType::IDX_NAME]."\n");
	
	return $itemResult;
}

# Use this function to create a detection that has no description in the framework database.
# This is the case for some detections coming from project dependencies.
sub createItemDetectionWithoutDescription($$$$$;$) {
	my $officialName = shift;
	my $userProjectName = shift;
	my $version = shift;
	my $status = shift;
	my $artifact = shift;
	my $env = shift;
	my $stringVersion = $version || 'undefined';
	
	my $itemResult = {};
	$itemResult->{'framework_name'} = $officialName;
	$itemResult->{'data'}->{$framework::dataType::ITEM} = $officialName.'#'.$stringVersion; ## $searchItem->[$framework::dataType::IDX_ITEM];
	
	# Make range ...
	my ($mintext, $maxtext) = framework::version::makeRange($version);
	
	# canonization ...
	my ($min, $mintag)  = framework::version::getCanonicalVersion($mintext);
	my ($max, $maxtag) = framework::version::getCanonicalVersion($maxtext);
	
	$itemResult->{'data'}->{$framework::dataType::MIN_VERSION} = $min;
	$itemResult->{'data'}->{$framework::dataType::MAX_VERSION} = $max;
	
	if ($status eq $framework::dataType::STATUS_DISCOVERED) {
		# the framework has been detected with the json project file analysis, but has been
		# discovered, whereas it's un it was unknow in json environment, because it was known in another environnement.
		$itemResult->{'data'}->{$framework::dataType::ENVIRONMENT} = "$env-extended";
	}
	else {
		$itemResult->{'data'}->{$framework::dataType::ENVIRONMENT} = $env;
	}
	# "exportable" means can appear in the results (not an intermediate detection).
	$itemResult->{'data'}->{$framework::dataType::EXPORTABLE} = 1;
	$itemResult->{'data'}->{$framework::dataType::STATUS} = $status;
	$itemResult->{'data'}->{$framework::dataType::ARTIFACT} = $artifact;

	$itemResult->{'data'}->{$framework::dataType::MATCHED_PATTERN} = $userProjectName;
	
	$version = $version || "";
	framework::Logs::Debug("--> detection of framework $officialName $version (without environment)\n");
	
	return $itemResult;
}


#***********************************************************************
#     DETECTION PROCESSUS INITIATED BY getEnvItem()
#-----------------------------------------------------------------------
#
# 1 - getEnvItem()
#
#     a) check against the selectors available in the corresponding env.
#         If a selector is matched, then return the framework :
#         - name : framework name corresponding to the matched selector in the DB
#         - version : version found in the project file
#         - item : the name of the framework
#         - status : discovered
# 
#   If none selectors where matched in a), then :
# 
#     b) check against known frameworks names in the corresponding techno.
#         If a framework name is matched (INSENSITIVE MODE), then return the framework :
#         - name : framework name matched in the DB
#         - version : version found in the project file
#         - item : the name#version
#         - status : discovered
#   Else 
# 
#     c) return the framework :
#         - name : framework name found in project file
#         - version : version found in the project file
#         - item : the name#version
#         - status : TBC
#
# 2 - addItemDetection() : use to add each item to the detection list of its corresponding framework (inside a local detection result)
#
#     a) filters existing ITEMs (insensitive). If an item a alrerady been discovered, do not merge it in step b)
#           NOTE : an item is identified by  :  name#version
#
#     b) if not filtered, merge the item in the apropriate list, using version merging mechanism
#
# 3 - store_result() : 
#
#     merge a list of local detections inside the global detection results.



#-----------------------------------------------------------------------
# retrieve the item describing the framework whose name is given in parameter.
# - First, search in the specified environment and return the full description if found.
# - If any, search in all environments, with case insensitive mode.
#      - if found mark as DISCOVERED in 'extended' environment
#      - if not found, mark as TBC
sub getEnvItem($$$$;$$) {
	my $fwName = shift; 
	my $fwVersion = shift;
	my $envDB = shift;
	my $envName = shift;
	my $projectFileName = shift;
	my $H_DatabaseName = shift;
	
	my $status = $framework::dataType::STATUS_TBC;
	
	my $NameInHighlight;
			
	if (defined $options->{'--framework-allow-mapping'}) {
	
		if (defined $envDB) {
			# For each items declared in the reqTxt environement ...
			for my $item (keys %{$envDB->{'PATTERNS'}}) {
				my $searchItem = $envDB->{'PATTERNS'}->{$item};
				my $selectorsList = $searchItem->[$framework::dataType::IDX_SELECTORS];
	
				# options could be: exact matching, case insensitive, extract version.
				my $options = $searchItem->[$framework::dataType::IDX_OPTIONS];
				my $mod = $options->{'regmod'};
				if (!defined $mod) {
					$mod = "";
				}

				# for each framework pattern, try to match the dependency ...
				for my $fwPattern (@$selectorsList) {
					if ($fwName =~ /(?$mod)^$fwPattern$/) {
						$status = $framework::dataType::STATUS_DISCOVERED;
						my $detection = framework::detections::createItemDetection($searchItem, $fwName, $fwVersion, $envName, $status, $projectFileName);
						return $detection;
					}
				}
			}
		}
	
		# The framework is not declared in "$envName" description environment.
		# So, try to match from other environments (check if it is a known framework's name) ...
		if (defined $H_DatabaseName) {
			$NameInHighlight = $H_DatabaseName->{lc($fwName)};
		}
	}
	
	my $officialName;
	my $projectName;
	if (defined $NameInHighlight) {
		$officialName = $NameInHighlight;
		$projectName = $fwName;
		$status = $framework::dataType::STATUS_DISCOVERED;
	}
	else {
		$officialName = $fwName;
		$projectName = undef;
		$status = $framework::dataType::STATUS_TBC;
	}
	my $detection =  framework::detections::createItemDetectionWithoutDescription($officialName, $projectName, $fwVersion, $status, $projectFileName, $envName);
	return $detection;
}

sub getDetectionsStatus($) {
	my $detections = shift;
	
	for my $detect (@$detections) {
		if ($detect->{$framework::dataType::STATUS} eq $framework::dataType::STATUS_DISCOVERED ) {
			return $framework::dataType::STATUS_DISCOVERED;
		}
	}
	return $framework::dataType::STATUS_TBC;
}

#************* STORE RESULTS OBTAINED on a file ************************

# data are merged in the $H_detections structure, the global framework detection result.
sub store_result($$$) {
	my $techno = shift;
	my $H_FileDetections = shift;
	my $merge_callback = shift;
	
	if (!defined $merge_callback) {
		$merge_callback = \&default_merge_callback;
	}
	
	if (! exists $H_detections{$techno}) {
		$H_detections{$techno} = {};
	}


	#------------------------------------------------------------------------------------------------------------------------
	# Determine the name of the framework, taking into accound previous detections with equivalent names in mode insensitive.
	#
	# When checking insensitively previous name of detected framework:
	# if a name maches a previous detected name :
	# 1 - if the status of this previous detection is "discovered", then the previous detected name is the "official" name of the framework.
	# 2 - if the status of this previous detection is "TBC", but the new detection is "discovered", then the new detection has the "officail" name.
	# 3 - if both detections (previous and new) have a TBC status, then keep the first discovered.
	#------------------------------------------------------------------------------------------------------------------------
	
	my $previousFrameworkDetections = $H_detections{$techno};
	
	# store each detected framework
	for my $frameworkName (keys %$H_FileDetections) {
		
		my $store_name = $frameworkName;
		my $mergeName = ($options->{'--framework-insensitive-merge'} ? lc($frameworkName) : $frameworkName );
#print "STORE Framework : $frameworkName\n";
		# Check for previous detection of the framework
		my $previousDetection = $H_insensitiveDetection{$mergeName};
		if (defined $previousDetection) {
			# check if previous detection is with same name case.
			my $previousName = $previousDetection->[0];
#print "->previous name : $previousName\n";
			if ($previousName ne $frameworkName) {
				# yes, already detected with another name case, so check status ...
				if ($previousDetection->[1] eq $framework::dataType::STATUS_DISCOVERED) {
					# previous status is 'discovered' so keep previous name : store_name is set to previous detected name.
#print "->previous name has been DISCOVERED\n";
					$store_name = $H_insensitiveDetection{$mergeName}->[0];
				}
				elsif (getDetectionsStatus($H_FileDetections->{$frameworkName}) eq $framework::dataType::STATUS_DISCOVERED) {
#print "->previous name has NOT been DISCOVERED\n";
					# status of previous detection is NOT 'discovered' ...
					# ... but new detection's status is discovered, so keep new detected name.
					# -> by default $store_result is initialized to new detection name, so do not modify

					# replace previous name with new name in insensitive detection ...
					$H_insensitiveDetection{$mergeName} = [$frameworkName, $framework::dataType::STATUS_DISCOVERED];
					
					# replace previous name with new in results
					my $previous_data = $previousFrameworkDetections->{$previousName};
					delete $previousFrameworkDetections->{$previousName};
					$previousFrameworkDetections->{$frameworkName} = $previous_data;
				}
				else {
					# status of new and previous detection are both TBC => keep the first detection's name.
#print "-> status of new and previous detection are both TBC\n";
					$store_name = $H_insensitiveDetection{$mergeName}->[0];
				}
			}
		}
		else {
#print "--> record insensitive ...$frameworkName (".getDetectionsStatus($H_FileDetections->{$frameworkName}).")\n";
			$H_insensitiveDetection{$mergeName} = [$frameworkName, getDetectionsStatus($H_FileDetections->{$frameworkName}) ];
		}

		#---------------------------------------------------------------
		# get the data of the new detection
		#---------------------------------------------------------------
		my $detections = $H_FileDetections->{$frameworkName};
		
		#---------------------------------------------------------------
		# Store the new detection data with the rectified (if any) name 
		#---------------------------------------------------------------
		if (! exists $previousFrameworkDetections->{$store_name}) {
			# first time the framework is detected ...
			$previousFrameworkDetections->{$store_name} = [];
		}
		
		# For the current detected framework, merge all detections inside previous detection.
		mergeList($previousFrameworkDetections->{$store_name}, $detections);
	}
	
	
}

#************ DUMP ****************************************************

sub setOutputFileName($;$) {
	$outputFileName = shift;
	$options = shift || {};
}

# Dump datas in a CSV file 

sub dump() {
	
	#my @datas_columns = ('name', 'min_version', 'max_version', 'type', 'description');
	
	if (! defined $outputFileName) {
		framework::Logs::Warning("output file name is undefined, cannot dump framework detection results !\n");
		return;
	}
	
	my $ret = open OUTFILE, ">$outputFileName";
	
	if (! $ret) {
		framework::Logs::Error("[framework] unable to open file $outputFileName.\n");
		return;
	}
	
	print OUTFILE "name;techno;".join(";",@framework::dataType::RESULTS_FIELDS)."\n";
	
	for my $techno( keys %H_detections) {
		my $technoDetections = $H_detections{$techno};
		my $technoDescriptions = framework::frameworksDescr::getDB($techno);
		for my $frameworkName ( keys %{$technoDetections}) {
			my $itemDetections = $technoDetections->{$frameworkName};
			# The description search through the name is case-insensitive.
			my $frameworkDescription = $technoDescriptions->{lc($frameworkName)};
			# if frameworkName begins with ':' (corresponds to an empty group name)
			# i.e. in gradle file : compile file ('./xxx/y.jar')
			$frameworkName =~ s/^\://m;
			for my $detect (@$itemDetections) {
				print OUTFILE "$frameworkName;$techno;";
				for my $key (@framework::dataType::RESULTS_FIELDS) {
					if (defined $detect->{$key}) {
						
						# remove \n from detected pattern, to prevent csv corruption
						if ($key eq $framework::dataType::MATCHED_PATTERN) {
							$detect->{$key} =~ s/\n//g;
						}
						
						print OUTFILE $detect->{$key};
						#print "OUT : $key ==> $itemDetections->{$key}\n";
					}
					else {
						# If value is undefined in the detected item, it's maybe becasue it is a description field ... 
						my $IDX = $framework::dataType::DESCRIPTION_FIELD_INDEX{$key};
						if (defined $IDX) {
							if (defined $frameworkDescription->[$IDX]) {
								print OUTFILE $frameworkDescription->[$IDX];
							}
						}
					}
					print OUTFILE ";";

				}
				print OUTFILE "\n";
			}
			#print "\n";
		}
	}
	close OUTFILE;
}

1;
