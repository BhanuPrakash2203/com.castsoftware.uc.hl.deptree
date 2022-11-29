package framework::maven;

use strict;
use warnings;
 
#use XML::Twig;
use Lib::XML;
use framework::dataType;
use framework::detections;

my $PROPERTIES;

my %CALLBACKS = (
	'groupid' => \&matchGroupId,
	'artifactid' => \&matchArtifactId,
);

my $DEFAULT_SCANNING_CALLBACK = 'groupid';

#my $NotJsonFramework;
my $H_DatabaseName = {};

sub matchGroupId($) {
	my $pattern = shift;
	my $depend = shift;
	
	# $depend->[0] is the group id ...
	if ($depend->[0] =~ /$pattern/) {
		return 1;
	}
	return 0;
}

sub matchArtifactId($) {
	my $pattern = shift;
	my $depend = shift;
	
	# $depend->[1] is the artifact id ...
	if ($depend->[1] =~ /$pattern/) {
		return 1;
	}
	return 0;
}

sub getScanningCallback($) {
	my $target = shift;
	
	my $scanning_callback;
	if (defined $target) {
		$scanning_callback = $CALLBACKS{$target};
	}

	if (! defined $scanning_callback) {
		$scanning_callback = $CALLBACKS{$DEFAULT_SCANNING_CALLBACK}
	}
	
	return $scanning_callback;
}

sub evalText($) {
	my $text = shift;
	my $result = $text;
	
	return undef if (! defined $result);
	
	$result =~ s/^\s*//gm;
	$result =~ s/\s*$//gm;
	$result =~ s/\s+/ /gm;
#print "EVAL TEXT = $text -> ";
	while ($text =~ /\$\{([\w\.]*)\}/g) {
		if (defined $PROPERTIES) {
			my $propertyName = $1;
			my $propertyValue = $PROPERTIES->{$propertyName};
			if (defined $propertyValue) {
				$propertyName = quotemeta $propertyName;
				$result =~ s/\$\{$propertyName\}/$propertyValue/;
			}
			#else {
			#	$result =~ s/\$\{$propertyName\}//;
			#}
		}
	}
#print "$result\n";
	return $result;
}

sub evalText2($$) {
	my $text = shift;
	my $projectPropertiesList = shift;
	
	return $text if (!defined $text);
	
	my $result = $text;
	$result =~ s/^\s*//gm;
	$result =~ s/\s*$//gm;
	$result =~ s/\s+/ /gm;
	while ($text =~ /\$\{([^\}]*)\}/g) {
		my $propertyName = $1;
		for my $projectProperties (@$projectPropertiesList) {
			my $propertyValue = $projectProperties->{$propertyName};
			if (defined $propertyValue) {
				$propertyName = quotemeta $propertyName;
				$result =~ s/\$\{$propertyName\}/$propertyValue/;
				last;
			}
			else {
				$result =~ s/\$\{$propertyName\}//;
			}
		}
	}
#print "$result\n";
	return $result;
	
}

sub getElementFirstChild($$) {
	my $elt = shift;
	my $item = shift;
	
	#my $firstChild = $elt->first_child($item);
	my $firstChild = $elt->getChildrenByLocalName($item)->[0];
	if (defined $firstChild) {
		#return evalText($firstChild->textContent);
		return $firstChild->textContent;
	}
	return undef;
}

sub getProjectProperties($) {
	my $project = shift;
	
	#my $propertiesElt = $project->first_elt('properties');
	my @propertiesEltList = Lib::XML::findnodes($project, '//project/properties');
	
	my $properties = {};
	for my $propertiesElt(@propertiesEltList) {
		
		#my @propertyList = $propertiesElt->children('*');
		my @propertyList = Lib::XML::getChildren($propertiesElt);
		
		for my $prop (@propertyList) {
			$properties->{$prop->nodeName} = $prop->textContent;
#print "PROPERTY : ".$prop->nodeName." = ".$prop->textContent."\n";
		}
	}

	return $properties;
}

sub getProjectParent($) {
	my $project = shift;
	
	#my $parentElt = $project->first_elt('parent');
	my $parentElt = Lib::XML::findnodes($project, '//parent')->[0];
	
	if (defined $parentElt) {
		my $parent = {};
		$parent->{'groupId'} = evalText(getElementFirstChild($parentElt, 'groupId'));
		$parent->{'artifactId'} = evalText(getElementFirstChild($parentElt, 'artifactId'));
		
		# $version will be evaluated later in resolveProperties(), when projects hierarchy tree will be established !
		$parent->{'version'} = getElementFirstChild($parentElt, 'version');
		
		return $parent;
	}
	return undef;
}

# Get first direct child text
sub getTwigFirstChildText($$) {
	my $project = shift;
	my $item = shift;
	
	#my @children = $project->findnodes($item);
	my @children = Lib::XML::findnodes($project, "./$item");
	
	if (defined $children[0]) {
		#return evalText($children[0]->textContent);
		return $children[0]->textContent;
	}

	return undef;
}

# get the list of dependencies of a <dependencies>...</dependencies> node.
# format of a dependency is (grouId, ArtifactId, Version)
sub getDependencyList($) {
	my $dependenciesNode = shift;

	#my @dependencyList = $dependenciesNode->findnodes('dependency');
	my @dependencyList = Lib::XML::findnodes($dependenciesNode, './/dependency');
	
	my @dependsList = ();
	
	for my $dep (@dependencyList) {
		my $groupId = evalText(getTwigFirstChildText($dep, 'groupId'));
		my $artifactId = evalText(getTwigFirstChildText($dep, 'artifactId'));
		my $scope = evalText(getTwigFirstChildText($dep, 'scope'));
		
		if ((defined $scope) && ($scope eq "test")) {
#print STDERR "${groupId}::$artifactId is a TEST !!\n";
			next;
		}
		
		# $version will be evaluated later in resolveProperties(), when projects hierarchy tree will be established !
		my $version = getTwigFirstChildText($dep, 'version');
		
		my @depend = ($groupId, $artifactId, $version);
		push @dependsList, \@depend;
#print STDERR "DEPEND = ".join(":", map { $_ // "undef" } @depend)."\n";
	}
	
	return \@dependsList;
}

sub getDependencies($) {
	my $node = shift;

	my @depends = ();
	
	# search <dependencies> node in the whole document
	my @dependenciesNodeList = Lib::XML::findnodes($node, '//dependencies');

	for my $dependenciesNode (@dependenciesNodeList) {
		push @depends, @{getDependencyList($dependenciesNode)};
	}
	
	return \@depends;
}

sub getManagedDependencies($) {
	my $node = shift;
	
	my @depends = ();

	#my @dependencyManagementNodeList = $node->findnodes('dependencyManagement');
	my @dependencyManagementNodeList = Lib::XML::findnodes($node, '//dependencyManagement');

	for my $dependencyManagementNode (@dependencyManagementNodeList) {
		push @depends, @{getDependencies($dependencyManagementNode)};
	}
	
	return \@depends;
}

sub parsePOM($) {
	my $pomFile = shift;
	
	# WARNING: should not be forgotten !!
	$PROPERTIES = undef;
	
	print "analyzing pom file : $pomFile\n";
	my $project = {};

	print "Loading $pomFile\n";
	
	# USE THIS to parse without option.
	my $projectRoot = Lib::XML::load_xml($pomFile);
	
	# USE THIS to activate LINE NUMBER management (actually desactivated for performence considerations).
	#my $parser = XML::LibXML->new({ line_numbers => 1 });
	#my $projectRoot = $parser->load_xml(location => $pomFile);
	
	if (!defined $projectRoot) {
		return undef;
	}

	$project->{'properties'} = getProjectProperties($projectRoot);
	$PROPERTIES = $project->{'properties'};

	$project->{'pomFile'} = $pomFile;
	$project->{'groupId'} = evalText(getTwigFirstChildText($projectRoot, 'project/groupId'));
	$project->{'artifactId'} = evalText(getTwigFirstChildText($projectRoot, 'project/artifactId'));
	$project->{'packaging'} = evalText(getTwigFirstChildText($projectRoot, 'project/packaging'));
	
	# $version will be evaluated later in resolveProperties(), when projects hierarchy tree will be established !
	$project->{'version'} = getTwigFirstChildText($projectRoot, 'project/version');
	
	$project->{'children'} = [];
	$project->{'dependencies'} = getDependencies($projectRoot);
	
	# REMOVE becauses all <dependencies> tags containes inside <managedDependencies> are altready taken into accound by "getDependencies(...)"
	# So there is no distinction between managed and unmanaged dependencies ...
	# If we would need to, we would have to modify the function "getDependencies(...)" to ignore <dependencies> tags inside <managedDependencies>.
	#
	#$project->{'managedDependencies'} = getManagedDependencies($projectRoot);

#for my $depList (@{$project->{'dependencies'}}) {
#print "DEPENDENCIES = ".join(":", map { $_ // "undef" } @$depList)."\n";
#}

#for my $depList (@{$project->{'managedDependencies'}}) {
#print "M_DEPENDENCIES = ".join(":", map { $_ // "undef" } @$depList)."\n";
#}
	$project->{'parent'} = getProjectParent($projectRoot);
	
	if (! defined $project->{'groupId'}) {
		$project->{'groupId'} = $project->{'parent'}->{'groupId'};
	}
	
	if (! defined $project->{'version'}) {
		$project->{'version'} = $project->{'parent'}->{'version'};
	}
	
	return $project;
}

sub addChildProject($$) {
	my $parent = shift;
	my $child = shift;
	
	if (!exists $parent->{'children'}) {
		$parent->{'children'} = [];
	}

	push @{$parent->{'children'}}, $child;
}

# Associate parents and child project in a tree view.
sub organizeProject($) {
	my $projects = shift;
	
	my @toRemove = ();
	# for each project discovered ...
	for my $project (@$projects) {
#print "SEARCH parent of ".($project->{'artifactId'}||"<no artifactId>")."\@".($project->{'groupId'}||"<no groupId>")."\n";
		# if the project has no parent, do nothing.
		if (! defined $project->{'parent'}) {
			next;
		}
		
		# try to find the parent project ...
		for my $otherProject (@$projects) {
			
			if (!defined $otherProject) {
				next;
			}
			
			if ($otherProject == $project) {
				# project can not be parent of itself !!!
				next;
			}
			
			# check if groupId are identical ...
			if (defined $otherProject->{'groupId'} and ($otherProject->{'groupId'} eq $project->{'parent'}->{'groupId'})) {
#print "********************* FOUND PARENT !!!!!!\n";
				# check if artifactId are identical ...
				if (defined $otherProject->{'artifactId'} and ($otherProject->{'artifactId'} eq $project->{'parent'}->{'artifactId'})) {
					
					# if the child project has a specified version ...
					if (defined $project->{'version'}) {
						
						# ... check if version is identical to potential parent...
						if (defined $otherProject->{'version'} and ($otherProject->{'version'} eq $project->{'parent'}->{'version'})) {
							# YES : found parent !!!
							addChildProject($otherProject, $project);
							push @toRemove, $project;
							last;
						}
					}
					else {
						# no version conflict (child has no version), so the other project is considered the parent.
						addChildProject($otherProject, $project);
						# ends the loop used to search the parent.
						push @toRemove, $project;
						last;
					}
				}
			}
		}
		
		#remove undefined project (those that hav been added to parent !!)
		for my $projtoremove (@toRemove) {
			for my $proj (@$projects) {
				if ($proj == $projtoremove) {
					$proj = undef;
				}
			}
		}
		@$projects = grep defined, @$projects;
	}
}

sub printProj($$);

sub printProj($$) {
	my $proj = shift;
	my $level = shift;
	
	print '  ' x $level;
	print "PROJECT ".$proj->{'pomFile'}."\n";
	
	for my $child (@{$proj->{'children'}}) {
		printProj($child, $level+1);
	}
}

sub resolveProperties($$);
	
sub resolveProperties($$) {
	my $project = shift;
	my $properties = shift;
	
	# add properties of this project ...
	push @$properties, $project->{'properties'};
	
	for my $depend (@{$project->{'dependencies'}}) {
		# depend is a list [ artifactId, groupId, version ]
		$depend->[2] = evalText2($depend->[2], $properties);
	}
	for my $depend (@{$project->{'managedDependencies'}}) {
		$depend->[2] = evalText2($depend->[2], $properties);
	}
	
	if (defined $project->{'children'}) {
		for my $subproj(@{$project->{'children'}}) {
			resolveProperties($subproj, $properties);
		}
	}
	
	# remove properties of this project.
	pop @$properties;
}

sub analysePomList($) {
	my $poms = shift;
	
	my @projects = ();
	
	# for each pom filename ...
	for my $pom (@$poms) {
		# get data ...
		my $project = parsePOM($pom);
		
		if (defined $project) {
			# add the project to the list ...
			push @projects, $project;
		}
	}

	# build a tree view organization of project.
	# projects inheriting from another are attached to their parent.
	organizeProject(\@projects);
	
	for my $project (@projects) {
		resolveProperties($project, []);
	}
	
	for my $proj (@projects) {
		printProj($proj, 0);
	}

	return \@projects;
}

sub dumpProjectDependencies($$;$$);
sub dumpProjectDependencies($$;$$) {
	my $proj = shift;
	my $out = shift;
	my $num =shift;
	my $pathlevel = shift;
	
	if (! defined $num) {
		$num = 1;
	}
	
	if (! defined $pathlevel) {
		$pathlevel = $num;
	}
	else {
		$pathlevel .= ".".$num;
	}
	
	print $out "POM FILE : ".$proj->{'pomFile'}."\n";
	
	for my $depend (@{$proj->{'dependencies'}}) {
		print $out "$pathlevel;".join(";", map { $_ // "undef" } @$depend).";normal\n";
	}
	
	for my $depend (@{$proj->{'managedDependencies'}}) {
		print $out "$pathlevel;".join(";", map { $_ // "undef" } @$depend).";managed\n";
	}

	
	for my $subproj (@{$proj->{'children'}}) {
		dumpProjectDependencies($subproj, $out, $num, $pathlevel);
		$num++;
	}
}

sub dumpMavenDependencies($) {
	my $projList = shift;
	
	if (! framework::Logs::isDebugOn()) {
		return;
	}
	
	my $out = framework::Logs::getOutputDirectory();
	$out .= "/maven_dependencies.csv";
	
	open my $fdout, "> $out";
	
	if (! defined $fdout) {
		framework::Logs::Error("[dumpMavenDependencies] unable to open $out for writing.");
		return;
	}
	
	my $num=1;
	for my $proj (@$projList) {
		dumpProjectDependencies($proj, $fdout, $num);
	}
	close $fdout;
}

sub createItemDetection($$$$;$) {
	my $depend = shift;
	my $searchItem = shift;
	my $pattern = shift;
	my $status = shift;
	my $artifact = shift;
	 
	my $itemResult = {};
	$itemResult->{'framework_name'} = $searchItem->[$framework::dataType::IDX_NAME];
	$itemResult->{'data'}->{$framework::dataType::ITEM} = $searchItem->[$framework::dataType::IDX_ITEM];
	$itemResult->{'data'}->{$framework::dataType::MIN_VERSION} = $searchItem->[$framework::dataType::IDX_MIN];
	$itemResult->{'data'}->{$framework::dataType::MAX_VERSION} = $searchItem->[$framework::dataType::IDX_MAX];
	$itemResult->{'data'}->{$framework::dataType::ENVIRONMENT} = 'maven';
	$itemResult->{'data'}->{$framework::dataType::EXPORTABLE} = $searchItem->[$framework::dataType::IDX_EXPORTABLE];
	$itemResult->{'data'}->{$framework::dataType::STATUS} = $status;
	$itemResult->{'data'}->{$framework::dataType::ARTIFACT} = $artifact;
	
	$itemResult->{'data'}->{$framework::dataType::MODULE} = $depend->[1];
	$itemResult->{'data'}->{$framework::dataType::VERSION_MODULE} = $depend->[2];
	$itemResult->{'data'}->{$framework::dataType::MATCHED_PATTERN} = $pattern;
	
	return $itemResult;
}

sub createItemDetectionWithoutDescription($$$$;$) {
	my $depend = shift;			# id coming from the pom.xml : [groupId, artifactId]
	my $officialName = shift;	# normalized name for publication (the name present in the highlight database if the framework is known)
	my $projectName = shift;	# project name : the name of the framework as found in the pom.xml. 
								#               (undef if the framework is unknown in highlight; indeed, no "official highlight name" means no "project name", so $officialName is project Name, and $projectName is undef)
	my $status = shift;
	my $artifact = shift;
	 
	my $itemResult = {};
	$itemResult->{'framework_name'} = $officialName;
	$itemResult->{'data'}->{$framework::dataType::ITEM} = $depend->[0]."/".$depend->[1]; ## $searchItem->[$framework::dataType::IDX_ITEM];
	$itemResult->{'data'}->{$framework::dataType::MIN_VERSION} = undef;
	$itemResult->{'data'}->{$framework::dataType::MAX_VERSION} = undef;
	
	if ($status eq $framework::dataType::STATUS_DISCOVERED) {
		# the framework has been detected with the maven project file analysis, but has been
		# discovered, whereas it's un it was unknow in maven environment, because it was known in another environnement.
		$itemResult->{'data'}->{$framework::dataType::ENVIRONMENT} = 'maven-extended';
	}
	else {
		$itemResult->{'data'}->{$framework::dataType::ENVIRONMENT} = 'maven';
	}
	# "exportable" means can appear in the results.
	$itemResult->{'data'}->{$framework::dataType::EXPORTABLE} = 1;
	$itemResult->{'data'}->{$framework::dataType::STATUS} = $status;
	$itemResult->{'data'}->{$framework::dataType::ARTIFACT} = $artifact;

	$itemResult->{'data'}->{$framework::dataType::MODULE} = $depend->[1];
	$itemResult->{'data'}->{$framework::dataType::VERSION_MODULE} = $depend->[2];
	$itemResult->{'data'}->{$framework::dataType::MATCHED_PATTERN} = $projectName;
	return $itemResult;
}

#sub addItemDetection($$) {
#	my $H_detect = shift;
#	my $itemDetect = shift;
#	
#	my $frameworkName = $itemDetect->{'framework_name'};
#	if (! defined $H_detect->{$frameworkName}) {
#		$H_detect->{$frameworkName} = [];
#	}
#	
#	push @{$H_detect->{$frameworkName}}, $itemDetect->{'data'};
#	framework::detections::referenceDetectedItem($itemDetect->{'data'}->{$framework::dataType::ITEM});
#}

sub getManagedVersion($$) {
	my $id = shift;
	my $managedVersions = shift;
	
	for my $v (@{$managedVersions}) {
		if (defined $v->{$id}) {
			return $v->{$id};
		}
	}
	return undef;
}

sub getMavenVersion($$) {
	my $depList = shift;
	my $inheritedManagedVersions = shift;
	
	my $version = $depList->[2];
	if (! defined $version) {
		 # search in the input managed dependencies.
		 if ((defined $depList->[0]) && (defined $depList->[1])) {
			 $version = getManagedVersion($depList->[0].":".$depList->[1], $inheritedManagedVersions);
		 }
	}
	
	return $version;
}

#sub isKnownFramework($) {
#	my $dependency = shift;
#	my $dependName = $dependency->[0];
#	
#	if (!defined $dependName) {
#		return 0;
#	}
#
#	for my $name (@$NotJsonFramework) {
#		
#		if ($dependency->[0] =~ /\b$name\b/i) {
#			framework::Logs::Debug("  --> in json dependencies, $dependency->[0] is a known framework name ...\n");
#			return 1;
#		}
#	}
#	
#	return 0;
#}

sub tryMatchDependency($$$$$$) {
	my $depList = shift;
	my $H_detections = shift;
	my $patterns = shift;
	my $inheritedManagedVersions = shift;
	my $H_Found = shift;
	my $projectFileName = shift;
	
	#my $framework = $depList->[0];
	my $depend = join(":", map { $_ // "undef" } @$depList);
	
	# prevent from doubloons
	if (exists $H_Found->{$depend}) {
		return;
	}
	else {
		$H_Found->{$depend} = 1;
	}
	
	# get the dependency version
	my $version = getMavenVersion($depList, $inheritedManagedVersions);
framework::Logs::Debug("DEPEND $depend\n");
	# try to match the dependency with expected patterns.
	my $target = undef;  # value is string "groupId" or "artifactId", but will be treated as "groupId" by default ...
	
	# desactivate DB matching, because the name of the framework will be the generic official name of the DB. The consequence is the
	# not detection of several sub-framework. For example :
	# 	<dependency>
	#		<groupId>org.springframework.boot</groupId>
	#		<artifactId>spring-boot-devtools</artifactId>
	#	</dependency>
	#	<dependency>
	#		<groupId>org.springframework.boot</groupId>
	#		<artifactId>spring-boot-starter-security</artifactId>
	#	</dependency>
	#	==> both will be detected as "spring" framework, and anly one will be recorded, the other will be considered as doublon.
	
	my $TRY_MATCHING_WITH_DB = 0;
	
	if ($TRY_MATCHING_WITH_DB) {
	
		for my $searchItem (keys %{$patterns->{'PATTERNS'}}) {
			my $itemDesc = $patterns->{'PATTERNS'}->{$searchItem};
			my $scanning_callback = getScanningCallback($target);

			for my $pattern (@{$itemDesc->[$framework::dataType::IDX_SELECTORS]}) {
				#framework::Logs::Debug("scanning pattern $pattern on $depend\n");
				my $status = $framework::dataType::STATUS_TBC;
				if ($scanning_callback->($pattern, $depList)) {
					framework::Logs::Debug("---> found $pattern in dependency $depend\n");
					my $itemDetection = createItemDetection($depList, $itemDesc, $pattern, $framework::dataType::STATUS_DISCOVERED, $projectFileName);
					framework::detections::addItemDetection($H_detections, $itemDetection);
					return;
				}
			}
		}
	}

	my $status;
	# The framework is not declared in maven description environment.
	# So, try to match from other environments (check if it is a known framework's name) ...
	
	my $officialName;
	my $projectName;
	
	# work with groupId or artifactId ??
	if ((!defined $target) or ($target eq 'groupid')) {
		$projectName = $depList->[0]; # groupId
	}
	else {
		$projectName = $depList->[1]; # artifactId
	}
	
	my $NameInHighlight = $H_DatabaseName->{lc($projectName)};
	
	if (defined $NameInHighlight) {
		$officialName = $NameInHighlight;
		$status = $framework::dataType::STATUS_DISCOVERED;
	}
	else {
		$officialName = $projectName;
		$projectName = undef;
		$status = $framework::dataType::STATUS_TBC;
	}
	
	my $itemDetection = createItemDetectionWithoutDescription($depList, $officialName, $projectName, $status, $projectFileName);
	
	framework::Logs::Debug("---> found with no description. $depend --> ".($projectName||"??")." ($officialName)\n");
	framework::detections::addItemDetection($H_detections, $itemDetection);
}

sub searchInDependencies($$$;$);
sub searchInDependencies($$$;$) {
	my $proj = shift;
	my $H_detections = shift;
	my $patterns = shift;
	my $inheritedManagedVersions = shift;
	my %H_Found = ();
	
	framework::Logs::Debug("\nSCANNING DEPENDENCIES  IN POM : ".$proj->{'pomFile'}."\n");
	
	my $localManagedVersions = {};
	
	if (! defined $inheritedManagedVersions) {
		$inheritedManagedVersions = [];
	}
	
	for my $depList (@{$proj->{'dependencies'}}) {
		tryMatchDependency($depList, $H_detections, $patterns, $inheritedManagedVersions, \%H_Found, $proj->{'pomFile'});
	}

	for my $depList (@{$proj->{'managedDependencies'}}) {
		my $version = $depList->[2];
		if (defined $version) {
			$localManagedVersions->{$depList->[0].":".$depList->[1]} = $version;
		}
		tryMatchDependency($depList, $H_detections, $patterns, $inheritedManagedVersions, \%H_Found, $proj->{'pomFile'});
	}
	
	for my $subProj (@{$proj->{'children'}}) {
		searchInDependencies($subProj, $H_detections, $patterns, [$localManagedVersions, @$inheritedManagedVersions]);
	}
}

# Try to determine the version of a framework by examining the version of each modules.
# If all modules of the framework have the same version, then consider it is the version of the framework.
sub mergeProjectDetections($) {
	my $H_detections = shift;
	
	my $several_VersionModule;
	my $several_Version;
	
	return;
	
	# DESACTIVATED
	
	# COMPUTE $detection->[$framework::dataType::VERSION], BUT IS NEVER USED.
	for my $framework (keys %{$H_detections}) {
		my $detections = $H_detections->{$framework};
		my $version;
		my $versionModule;
		for my $detection (@$detections) {
			my $nextVersion = $detection->{'module_version'};
			
			if (!defined $nextVersion) {
				# do not take into account undefined version !!
				next;
			}

			if (defined $nextVersion) {
				if (! defined $version) {
					$version = $nextVersion;
				}
				else {
					if ($version ne $nextVersion) {
						# several version of the same framework ??
						$several_VersionModule = 1;
						last;
					}
				}
			}
		}
		if (! $several_VersionModule) {
			# all module are with the same version : assume this version is the version of the framework
			# FIXME : should take into account the existing value of the VERSION field
			for my $detection (@$detections) {
				#$detection->[$framework::dataType::VERSION] = $version;
				$detection->{'version'} = $version;
			}
		}
	}
}

# Add detections from a project into global maven results.
sub addProjectDetections($$) {
	my $H_mavenDetections = shift;
	my $H_projectDetections = shift;
	
	for my $framework (keys %{$H_projectDetections}) {
		my $previous = $H_mavenDetections->{$framework};
		my $new = $H_projectDetections->{$framework};
		
		if (!defined $previous) {
			# first detection of the framework
			$H_mavenDetections->{$framework} = $new;
		}
		else {
			#NOTE : there should be no doubloons because filtered in searchInDependencies : do not record identical groupId:artifactId:version.
			push @{$H_mavenDetections->{$framework}}, @$new;
		}
	}
}

sub detect($$) {
	my $tabdir = shift;
	my $DB = shift;
	
	my $mavenPatterns = $DB->{'maven'};
	
	# built the list of framework names OTHER THAN maven ! 
	#$NotJsonFramework = framework::importExternal::BuiltFrameworkNamesListExceptEnv($DB, 'maven');
	
	$H_DatabaseName = framework::importExternal::getHashLowercaseNames($DB);
	
	my %H_MavenDetections = ();
	
	my @pomList = ();
	
	for my $dir (@$tabdir) {
		#if ($dir !~ /[\\\/]$/m) {
		#	$dir .= "/";
		#}
		my $poms = Lib::Sources::findFiles($dir, 'pom.xml');
		push @pomList, @$poms;
	}

	my $projects = analysePomList(\@pomList);
	
	dumpMavenDependencies($projects);
	
	# synthesizes dependencies ...
	for my $proj (@$projects) {
		my %H_projectDetections = ();
		# search detection ...
		searchInDependencies($proj, \%H_projectDetections, $mavenPatterns);
		
		# merge detections (global treatment for framewoks detections of same projet)
		mergeProjectDetections(\%H_projectDetections);
		
		# add in maven global detections
		addProjectDetections(\%H_MavenDetections, \%H_projectDetections);
	}

	return \%H_MavenDetections;
}

1;
