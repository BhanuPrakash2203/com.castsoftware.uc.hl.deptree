package framework::gradle;

use strict;
use warnings;

use framework::dataType;
use framework::detections;
use framework::Logs;
use Lib::Sources;
use StripJava;
use File::Basename;
use File::Spec;

my $DEBUG = 0;
#my $gradleDepList = ();

# "Project" object is the class instance whi is associated to a build.gradle file. So, the following guide is
# a usefull entry point for understanding build.gradle files content.
# https://docs.gradle.org/current/dsl/org.gradle.api.Project.html

my %JAVA_CTRL_KEYWORDS = (
	'class' => 0,
	'enum' => 0,
	'interface' => 0,
	'catch' => 1,
	'do' => 0,
	'else' => 0,
	'finally' => 0,
	'for' => 1,
	'if' => 1,
	'switch' => 1,
	'try' => 0,
	'while' => 1,
);


my $NB_OPENNED_BLOCS = 0;
my $NB_OPENNED_PARENTH = 0;

#### context flag modifying the behaviour of some functions :
# Allow to detect dependencies inside dedicated instructions, like 'compile', ...
my $DEPENDENCIES_CONTEXT = 0;
# We are parsing an Extra Property Extension closure
my $EXTRA_PROPERTY_CONTEXT = 0;

my %views = ();
my %VERSIONPACKAGES = ();
my @dependencies = ();


sub init() {
	$NB_OPENNED_BLOCS = 0;
	$NB_OPENNED_PARENTH = 0;
	$DEPENDENCIES_CONTEXT = 0;
	$EXTRA_PROPERTY_CONTEXT = 0;
	%views = ();
	@dependencies = ();
}


sub parseBloc($;$);
sub parseClosure($);
sub parseParenth($);


#-----------------------------------------------------------------------
#                       DEPENDENCIES ROUTINES 
#-----------------------------------------------------------------------

sub addDependency($) {
	my $dep = shift;
	if (ref $dep eq "HASH") {
		for my $key (keys %$dep) {
			if ($dep->{$key}) {
				$dep->{$key} =~ s/["']//g;
			}
		}
		push @dependencies, $dep;
		framework::Logs::Debug("  --> FOUND DEPENDENCY : ".($dep->{'group'}||"").":".($dep->{'name'}||"").":".($dep->{'version'}||"")."\n");
	}
	elsif (ref \$dep eq "SCALAR") {
		$dep =~ s/["']//g;
		framework::Logs::Debug("  --> FOUND DEPENDENCY : $dep\n");
		my @data = split ":", $dep;
		push @dependencies, {'group' => $data[0], 'name' => $data[1], 'version' => $data[2]};
	}
	else {
		framework::Logs::Warning("Unknow version format !!\n");
	}
}

sub expandDependencies($) {
	my $fileGradle = shift;
	framework::Logs::Debug("DEPENDENCIES SUMMARY :\n");
	for my $dep (@dependencies) {
		for my $key( keys %$dep) {

			if (!defined $dep->{$key}) {next;}

			# check when $dep{version} is defined by a variable
			# variable $xxx or variable ${xxx} or array variable xxx[yyy]
			if ($key eq 'version') {
				while ($dep->{$key} =~ /^(?:\$\{?([\w]+)\}?||([\w\-]+\[[\w\'\-]+\]))$/mg) {
					if (defined $1 || defined $2) {
						my $var = $1 || $2;
						# var has value
						if (defined $VERSIONPACKAGES{$var}) {
							my $version = $VERSIONPACKAGES{$var};
							$var = quotemeta $var;
							$dep->{$key} =~ s/$var/$version/ ;
						}
						else {
							print STDERR "[framework::gradle] WARNING $var unknown version\n";
							# remove $xxx if value is unknown
							$dep->{$key} =~ s/\$$var//;
						}
					}
				}
			}
		}
		framework::Logs::Debug("  --> FOUND DEPENDENCY : ".($dep->{'group'}||"").", ".($dep->{'name'}||"").", ".($dep->{'version'}||"")."\n");
	}
}

#-----------------------------------------------------------------------
#                         PARSING ROUTINES 
#-----------------------------------------------------------------------

# parse until end of intruction is encountered (\n or ; or } )
sub consumeUntilEOIinst($) {
	my $buf = shift;
	while ($$buf =~ /\G(\(|\{|[^\n(\{};]+)/gc) {
		if ($1 eq '(') {
			parseParenth($buf);
		}
		elsif ($1 eq '{') {
			parseClosure($buf);
		}
	}
}

sub consumeBlanks($) {
	my $buf = shift;
	while ($$buf =~ /\G\s*/gc) {
	}
}

# optional coma ...
my $OPT_COMA = '(?:\s*,)?';

# Parse a compile instruction (and retrieves dependencies if any ...)
sub parseCompile($) {
	my $buffer = shift;

	if (!$DEPENDENCIES_CONTEXT) {
		return;
	}

	### compile "..."
	### compile "group:name:version", "group:name:version", ...
	if ($$buffer =~ /\G\s*(CHAINE_\d+)/gc) {
		my @data = ();
		if (defined $1) {
			if ($views{'HString'}->{$1} =~ /(.*)\:(.*)\:(.*)/) {
				$data[0] = $1;
				$data[1] = $2;
				$data[2] = $3;
				addDependency({ 'group' => $data[0], 'name' => $data[1], 'version' => $data[2] });
			}
			else {
				addDependency($views{'HString'}->{$1});
			}
			while ($$buffer =~ /\G\s*[,\)]\s*(CHAINE_\d+)/gc) {
				if ($views{'HString'}->{$1} =~ /(.*)\:(.*)\:(.*)/) {
					$data[0] = $1;
					$data[1] = $2;
					$data[2] = $3;
					addDependency({ 'group' => $data[0], 'name' => $data[1], 'version' => $data[2] });
				}
			}
		}
	}
	### compile [(]? group: 'xxx', name: 'xxx', version: 'xxx'
	elsif ($$buffer =~ /\G\s*[(]?\s*group\s*:\s*(CHAINE_\d+)$OPT_COMA/gc) {
		my %data = ();
		$data{'group'} = $views{'HString'}->{$1};
		while ($$buffer =~ /\G\s*(name)\s*:\s*(CHAINE_\d+)$OPT_COMA/gc
			|| $$buffer =~ /\G\s*(version)\s*:\s*([\$\{\}\w\'\-\[\]]+)$OPT_COMA/gc) {
			my $type = $1;
			my $match = $2;
			my $decodestring = $views{'HString'}->{$match};
			if (defined $views{'HString'}->{$match}) {
				$data{$type} = $views{'HString'}->{$match};
			}
			else {
				$match =~ s/(CHAINE_\d+)/$views{'HString'}->{$1}/;
				$data{$type} = $match;
			}
		}
		#addDependency($data{'group'}.":".$data{'name'}.":".$data{'version'});
		addDependency(\%data);
	}
	### compile ("...")
	elsif ($$buffer =~ /\G\s*\(\s*(CHAINE_\d+)\s*\)/gc) {
		if (defined $1) {
			addDependency($views{'HString'}->{$1});
		}
	}
	### 02/12/21 desactivated because only internal name of project (not group, name, version)
	### compile ( project("...")
	### compile   project("...")
	#elsif ($$buffer =~ /\G\s*\(?\s*project\s*\(\s*(CHAINE_\d+)\s*\)/gc) {
	#	addDependency($views{'HString'}->{$1});
	#}
	### compile ( files("...")
	### compile   files("...")
	elsif ($$buffer =~ /\G\s*\(?\s*files\s*\(/gc) {
		while ($$buffer =~ /\G\s*(CHAINE_\d+)\s*[,\)]/gc) {
			my $filename = $views{'HString'}->{$1};
			my ($dirname, $basefile) = $filename =~ /(.*?)([^\\\/]*)$/;
			my $fw_name = framework::version::detectFrameworkNameInFileName($basefile);
			if (defined $fw_name) {
				my ($version, $tag) = framework::version::detectVersionInFileName($basefile, undef);
				addDependency(":$fw_name:" . ($version || ""));
			}
		}
	}
	### compile ("group:name:version", "group:name:version", ...)
	### compile ("group", "name", "version")
	elsif ($$buffer =~ /\G\s*\(/gc) {
		my @data = ();
		my $pos = pos($$buffer);
		while ($$buffer =~ /\G\s*(CHAINE_\d+)?\s*[,)]/gc) {
			my $stringID = $1;
			if (defined $stringID) {
				if ($views{'HString'}->{$stringID} =~ /(.*)\:(.*)\:(.*)/) {
					$data[0] = $1;
					$data[1] = $2;
					$data[2] = $3;
					addDependency({ 'group' => $data[0], 'name' => $data[1], 'version' => $data[2] });
				}
				else {
					push @data, $views{'HString'}->{$1};
				}
			}
			else {
				push @data, "";
			}
		}
		if ((!defined $data[0] || $data[0] eq "") && (!defined $data[0] || $data[0] eq "")) {
			my $unknow = substr($$buffer, $pos, 30);
			$unknow =~ s/\n.*//s;
			framework::Logs::Warning("Unknow dependency definition : $unknow ...\n");
		}
		else {
			addDependency({ 'group' => $data[0], 'name' => $data[1], 'version' => $data[2] });
		}
		# parse remaining items until closing parenth ...
		parseParenth($buffer);
	}
	else {
		my $pattern = substr($$buffer, pos($$buffer), 35);
		my $origin_pos = pos($$buffer);
		framework::Logs::Warning("Unknown syntax in compile statement at line " . return_line_number($buffer, $pattern) . "\n");
		pos($$buffer) = $origin_pos;
	}

	# Go until end of the instruction ...
	consumeUntilEOIinst($buffer);
	return;
}

# Parse the content of parentheses
#    (assume that the openning parent has been consummed, then expect the closing : consummes everything until closing)
sub parseParenth($) {
	my $buf = shift;
	while ($$buf =~ /\G(\(|\)|\{|[^()\{]+)/gc) {
		if ($1 eq '(') {
			parseParenth($buf);
		}
		elsif ($1 eq ')') {
			return;
		}
		elsif ($1 eq '{') {
			parseClosure($buf);
		}
	}
}

sub parseJavaControle($$) {
	my $buf = shift;
	my $keyword = shift;

	framework::Logs::Debug("   "x$NB_OPENNED_BLOCS . "|_$keyword\n");

	my $parents = $JAVA_CTRL_KEYWORDS{$1};

	if ($parents) {
		# parse the expected parentheses
		while ($$buf =~ /\G(\(|[^(]+)/gc) {
			if ($1 eq '(') {
				parseParenth($buf);
				last;
			}
		}
	}

	consumeBlanks($buf);

	# parse the content of the bloc of code (if any)...
	if ( $$buf =~ /\G\{/gc) {
		parseBloc($buf);
	}
	else {
		parseInstruction($buf);
	}
}


sub parseParam($) {
	my $buf = shift;

	# NOTE : groovy sugar syntax allow following possible parameterisation for a function call:
	#   myFct param1, ... , {closure}
	#   myFct (param1, ... , {closure})
	#   myFct (param1, ... ) {closure}
	#   myFct ( {closure} )
	#   myFct {closure}
	#   ... and so on ...

	# parse parentheses if any ...
	if ($$buf =~ /\G\s*\(/gc) {
		parseParenth($buf);
	}

	# parse a following closure if any ...
	if ($$buf =~ /\G\s*\{/gc) {
		parseClosure($buf);
	}
}

sub parseDependencies($) {
	my $buf = shift;
	$DEPENDENCIES_CONTEXT = 1;
	parseParam($buf);
	$DEPENDENCIES_CONTEXT = 0;
}

# https://docs.gradle.org/current/dsl/org.gradle.api.plugins.ExtraPropertiesExtension.html
sub parseExtraPropertiesExtension($) {
	my $buf = shift;
	$EXTRA_PROPERTY_CONTEXT = 1;
	parseParam($buf);
	$EXTRA_PROPERTY_CONTEXT = 0;
}

sub parsePropertyInit($$) {
	my $buf = shift;
	my $nameVar = shift;

	framework::Logs::Debug("   "x$NB_OPENNED_BLOCS . "|_$nameVar = \n");

	if ($$buf =~ /\G\s*(CHAINE_\d+)/gc) {
		my $val = $views{'HString'}->{$1};
		$val =~ s/^['"]*//m;
		$val =~ s/['"]*$//m;
		framework::Logs::Debug(" ------> VARIABLE $nameVar HAS THE VALUE <$val>\n");
		# print " ------> VARIABLE $nameVar HAS THE VALUE <$val>\n";
		$VERSIONPACKAGES{$nameVar} = $val;
	}
}

sub parseArrayPropertyInit($$) {
	my $buf = shift;
	my $nameArray = shift;

	while ($$buf =~ /\G\s*(CHAINE_\d+)\s*\:\s*(CHAINE_\d+)\s*\,?/gc) {
		my $nameVar = $views{'HString'}->{$1};
		my $val = $views{'HString'}->{$2};
		$nameVar =~ s/^['"]*//m;
		$nameVar =~ s/['"]*$//m;
		$val =~ s/^['"]*//m;
		$val =~ s/['"]*$//m;
		framework::Logs::Debug(" ------> VARIABLE $nameArray [$nameVar] HAS THE VALUE <$val>\n");
		# print " ------> VARIABLE $nameVar HAS THE VALUE <$val>\n";
		$VERSIONPACKAGES{$nameArray."[".$nameVar."]"} = $val;
	}
}

sub parseInstructionExt($) {
	my $buf = shift;

	# never consume \n nor ; nor } because they are the end instruction marke : they should be consumed by parseBloc
	# NOTE : (?! ...) mean "negative look ahead"
	if ($$buf =~ /\G(\w+)\s*\=\s*\[/gc) {
		if (defined $1) {
			parseArrayPropertyInit($buf, $1);
		}
	}
	elsif ($$buf =~ /\G(\w+)\s*=(?!=)/gc) {
		if (defined $1) {
			parsePropertyInit($buf, $1);
		}
	}
}

sub parseInstructionDependencies($) {
	my $buf = shift;
	if ($$buf =~ /\G(\w+)/gc) {
		framework::Logs::Debug("   " x $NB_OPENNED_BLOCS . "|_$1\n");
		if (($1 eq 'compile') || ($1 eq 'provided') || ($1 eq 'apt')) {
			parseCompile($buf);
		}
		elsif (($1 eq 'implementation') || ($1 eq 'api')) {
			# compile, provided, ... are deprecated and replaced with "implementation" and "api" ...
			# Syntax remain the same, so still calling parseCompile() ...
			parseCompile($buf);
		}
		elsif ($1 eq 'kapt') {
			# kapt is supplied by invoking "apply plugin: 'kotlin-kapt'" at the beginning of the script.
			parseCompile($buf);
		}
	}
}

sub parseInstructionDefault($) {
	my $buf = shift;

	# direct initialization of property :
	# ext.xxx = "..."
	if ($$buf =~ /\Gext\.(\w+)\s*=(?!=)/gc) {
		parsePropertyInit($buf, $1);
	}

	# function keyword :
	elsif ($$buf =~ /\G([\w\.]+)/gc) {
		framework::Logs::Debug("   "x$NB_OPENNED_BLOCS . "|_$1\n");
		if (($1 eq 'dependencies') || ($1 eq 'project.dependencies')){
			parseDependencies($buf);
		}
		elsif (($1 eq 'ext') || ($1 eq 'project.ext')){
			parseExtraPropertiesExtension($buf);
		}
		elsif (exists $JAVA_CTRL_KEYWORDS{$1}) {
			parseJavaControle($buf, $1);
		}
	}
}

sub parseInstruction($) {
	my $buf = shift;

	consumeBlanks($buf);

	### PARSE SPECIFIC PATTERNS (context dependent)
	if ($EXTRA_PROPERTY_CONTEXT) {
		parseInstructionExt($buf);
	}
	elsif ($DEPENDENCIES_CONTEXT) {
		parseInstructionDependencies($buf);
	}
	else {
		parseInstructionDefault($buf);
	}

	### PARSE COMMON PATTERNS
	### --> specific parsing does not necessarily take the whole instruction. So, this unsignificant part corresponding
	###     to the end of the instruction is parsed here after.

	# never consume \n nor ; nor } because they are the end instruction marke : they should be consumed by parseBloc
	while ($$buf =~ /\G(\{|\(|[^\n;(\{}]+)/gc) {
		if ($1 eq '(') {
			# the instruction contains a parenthesed expression ...
			parseParenth($buf);
		}
		elsif ($1 eq '{') {
			# the instruction contains a closure ...
			parseClosure($buf);
		}
	}
}

# Parse the content of accolade
#    (assume that the openning parent has been consummed, then expect the closing : consummes everything until closing)
sub parseBloc($;$) {
	my $buf = shift;
	my $closure = shift;

	my $type = (defined $closure ? "CLOSURE" : "BLOC");
	framework::Logs::Debug("   "x$NB_OPENNED_BLOCS . "|______${type}______\n");

	$NB_OPENNED_BLOCS++;

	consumeBlanks($buf);

	# assume the first item is an instruction
	parseInstruction($buf);

	# then iterate over others instructions
	# NOTE : all item are consumed by parseInstruction, except \n ; or } that are consumed by parseBloc
	while ($$buf =~ /\G(\n|;|\}|[^\n;}]+)/gc) {
		if ($1 eq '}') {
			$NB_OPENNED_BLOCS--;
			return;
		}
		elsif (($1 eq "\n") || ($1 eq ';')) {
			parseInstruction($buf);
		}
	}
}

sub parseClosure($) {
	parseBloc(shift, 1);
}

# HL-1746 Add dependencies.gradle to framework discovery
sub parseBlocDependenciesGradle($) {
	my $buf = shift;

	# print "Scan dependencies.gradle\n";

	my $libNamePersist;
	# search dependencies
	while ($$buf =~ /
					(\w+)\s*\=\s*\[ # libName
					|(\w+)\s*\:\s*["'](.*?\:.*?\:.*?)["'] # packageName: "group:name:version"
					|(\w+)\s*\:\s*\[\s*group\:\s*["'](.*?)["'] # packageName1: [group: xx, name: xx, version: xx ]
	/xg) {
		my $libName = $1;
		my $packageNameForm1 = $2;
		my $dependencyStr = $3;
		my $packageNameForm2 = $4;
		my $groupValue = $5;
		my $dependency;

		# update libname
		if (defined $libName) {
			if ($libName !~ /^test|test$/) {
				$libNamePersist = $libName;
			}
			else {
				$libNamePersist = undef;
			}
		}
		if (defined $libNamePersist) {
			# packageName: "group:name:version"
			if (defined $packageNameForm1) {
				if ($dependencyStr =~ /.*\:.*\:(.*)/) {
					my $versionStr = $1;
					my $versionVal = versionInterpolation($buf, $versionStr);
					my $patternToReplace = quotemeta($versionStr); # avoid \$ sign issue in regex
					$dependencyStr =~ s/$patternToReplace/$versionVal/;
					addDependency($dependencyStr);
				}
			}
			# packageName1: [group: xx, name: xx, version: xx ]
			elsif (defined $packageNameForm2) {
				$dependency .= "$groupValue\:";
				if ($$buf =~ /name\:\s*["'](.*?)["']\s*\,\s*/g) {
					$dependency .= "$1\:";
				}
				if ($$buf =~ /version\:\s*(.*?)\]/g) {
					my $versionVal = versionInterpolation($buf, $1);
					$dependency .= $versionVal;
				}
				addDependency($dependency);
			}
		}
	}
}

sub versionInterpolation($$) {
	my $buf = shift;
	my $version = shift;
	my $unchangedVersion = $version;
	$version =~ s/[\${}"']//g;
	$version =~ s/\w+\.//;

	if ($$buf =~ /\b$version\s*[=:]\s*["'](.*)["']/) {
		$version = $1;
	}
	else {
		return $unchangedVersion;
	}

	return $version;
}

#sub parseApplyFrom($$) {
#	my $fileBuildGradle = shift;
#	my $text = shift;
#	my %gradleDepList;
#	# syntax examples
#	#   apply from: 'foo.gradle'
#	#   apply from: "$projectDir/gradlebuild/dependencies.gradle"
#	#   apply from: rootProject.file('liteloader.gradle')
#
#	# create parent key for build.gradle
#	$gradleDepList{$fileBuildGradle}{$fileBuildGradle} = 1;
#
#	while ($$text =~ /apply\s+from\s*\:.*["'](?:\$\w+)?[\/\\]?(.*\.gradle)["'].*$/mg) {
#		if (defined $1) {
#			my $nestedGradle = File::Spec->catfile($1);
#			$gradleDepList{$fileBuildGradle}{$nestedGradle} = 1;
#		}
#	}
#	return \%gradleDepList;
#}

sub gradle($$$) {
	my $files_gradle = shift;
	my $gradle_DB = shift;
	my $H_DatabaseName = shift;
	my @itemDetections = ();

	# Scan all gradle files of project to list version values into ext {...}
	# Gradle inheritance is not supported here because not really exists, we are listing all dependencies found in build & dependencies.gradle files
	# https://stackoverflow.com/questions/48087131/how-many-gradle-files-can-inherit-from-one-another-how-deep-can-subprojects-b

	foreach my $file_gradle (@$files_gradle) {
		init();
		framework::Logs::printOut("GRADLE : $file_gradle\n");
		my $content = Lib::Sources::getFileContent($file_gradle);
		if (!defined $content) {
			framework::Logs::Warning("Unable to read $file_gradle for gradle inspection purpose.\n");
			return undef;
		}

		%views = ('text' => $$content);
		my %options = ();
		my %couples = ();
		my $status = StripJava::StripJava($file_gradle, \%views, \%options, \%couples);

		if ($status) {
			framework::Logs::Error "Error when parsing $file_gradle !\n";
			return undef;
		}
		my $code = \$views{'code'};
		# searching root (or project!) "dependencies" call ...
		if (basename($file_gradle) eq 'build.gradle') {
			# $gradleDepList = parseApplyFrom($file_gradle, \$views{'text'});
			parseBloc(\$views{'code'});
		}
		elsif (basename($file_gradle) eq 'dependencies.gradle') {
			# Gradle's Groovy DSL syntax (closures)
			if ($$code =~ /\bdependencies\s*\{/) {
				parseBloc(\$views{'code'});
			}
			# Gradle's Groovy DSL syntax (collections of librairies)
			# libName = [ packageName: "group:name:version" ]
			# or
			# libName = [ packageName1: [group: xx, name: xx, version: xx ], packageName2: xxx]
			elsif ($$code =~ /\w+\s*\=\s*\[/) {
				parseBlocDependenciesGradle(\$views{'text'});
			}
			else {
				print STDERR "[framework::gradle] error unknown syntax for $file_gradle\n";
			}
		}
		elsif (basename($file_gradle) eq 'build.gradle.kts') {
			# Gradle's Kotlin DSL syntax (closures)
			if ($$code =~ /\bdependencies\s*\{/) {
				parseBloc(\$views{'code'});
			}
		}

		# $NB_OPENNED_BLOC should be 1 (the main bloc, that is not closed by a "}" item.
		if ($NB_OPENNED_BLOCS > 1) {
			framework::Logs::Warning("Bloc of code not closed !!");
		}
		# update versions values in @dependencies
		expandDependencies($file_gradle);
		for my $dep (@dependencies) {
			# For Memory : $H_DatabaseName is a HASH of all framework name in ower case, available for the technology concerned (here java).
			my $gradleItem = framework::detections::getEnvItem($dep->{'name'}, $dep->{'version'}, $gradle_DB, 'gradle', $file_gradle, $H_DatabaseName);

			if (defined $gradleItem) {

				# if groupId has been captured, then re-build the framework name as this : <groupId>:<artifactId>
				if (defined $dep->{'group'}) {
					$gradleItem->{'framework_name'} = $dep->{'group'} . ":" . $gradleItem->{'framework_name'};
				}

				push @itemDetections, $gradleItem;
			}
		}
		framework::Logs::Debug("-- End GRADDLE detection-- \n");
	}
	return \@itemDetections;
}

sub return_line_number($$) {
	my $buffer = shift;
	my $pattern = shift;

	$pattern = quotemeta $pattern;

	open my $handle, '<', $buffer;
	my $linenum;

	while (<$handle>) {
		$linenum = $., last if /$pattern/;
	}

	close $handle;
	return $linenum;
}

#sub getRelationGradle{
#	return $gradleDepList;
#}
1;
