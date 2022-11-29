package framework::projectFiles;

use strict;
use warnings;

use AutoDecode;
use framework::dataType;
use framework::importExternal;
use Lib::Sources;
use framework::Logs;
use framework::version;
use framework::detections;
use JSON;
use framework::msproj;
use framework::gradle;
use framework::ant;
use framework::Gemfile;
use framework::yarnFile;
use framework::composer;
use File::Find;
use File::Spec;
use File::Basename;

my %H_detections = ();

#my $NotJsonFramework;
my $H_DatabaseName = {};

my %FileContent_CACHE  = ();

my $TECHNO = "";

my %FINAL_CALLBACKS = ();
my %cb_module_params = ();
my $filter_node_modules = 'OFF';

sub getFileContentFromCache($) {
	my $filename = shift;
	my $ret = undef;;
	if (exists $FileContent_CACHE{$filename}) {
		$ret = $FileContent_CACHE{$filename};
		if (! defined $ret) {
			return -1;
		}
	}
	return $ret;
} 

sub setFileContentInCache($$) {
	my $filename = shift;
	my $buffer = shift;
	$FileContent_CACHE{$filename} = $buffer;
}

my @fullJsonDetections = ();
my @fullReqTXtDetections = ();

sub dumpJsonDependencies() {
	if (! framework::Logs::isDebugOn()) {
		return;
	}

	my $out = framework::Logs::getOutputDirectory();
	$out .= "/json_dependencies.csv";
	
	open my $fdout, "> $out";
	
	if (! defined $fdout) {
		framework::Logs::Error("[dumpJsonDependencies] unable to open $out for writing.");
		return;
	}
	
	my $num=1;
	for my $package (@fullJsonDetections) {
		print $fdout "$package->{'filename'}\n";
		my $fwname    = $package->{'framework'}->{'name'} || '';
		my $fwversion = $package->{'framework'}->{'version'} || '';
		print $fdout "FRAMEWORK;$fwname;$fwversion\n";
		for my $depend (@{$package->{'framework'}->{'dependencies'}}) {
			print $fdout "DEPENDENCY;$depend->{'name'};";
			if (defined $depend->{'version'}) {
				print $fdout "$depend->{'version'}\n";
			}
			else {
				print $fdout "\n";
			}
		}
		
	}
	close $fdout;
}

#sub isKnownFramework($) {
#	my $fwName = shift;
#	
#	for my $name (@$NotJsonFramework) {
#		
#		if ($fwName =~ /\b$name\b/i) {
#			framework::Logs::Debug("  --> in json dependencies, $fwName is a known framework name ...\n");
#			return 1;
#		}
#	}
#	return 0;
#}

# ************ CS : callback for *.csproj **************

# Following data are to be filled before calling the callback !!!
my %cb_csproj_params = ('DB' => undef, 'filelist' => []);

sub cb_csproj() {
	my $itemDetections = framework::msproj::analyse_csproj($cb_csproj_params{'filelist'}, $cb_csproj_params{'DB'}, $H_DatabaseName);
	
	for my $itemDetection (@$itemDetections) {
		if (defined $itemDetection) {
			framework::detections::addItemDetection(\%H_detections, $itemDetection);
		}
	}
}

sub cb_gradle($$) {
	my $filenames = shift;
	my $gradle_DB = shift;
	return framework::gradle::gradle($filenames, $gradle_DB, $H_DatabaseName);
}

sub cb_ant($$) {
	my $filename = shift;
	my $gradle_DB = shift;
	return framework::ant::analyse_ant($filename, $gradle_DB, $H_DatabaseName);
}

sub cb_gemfile($$) {
	my $filename = shift;
	my $gemfile_DB = shift;
	return framework::Gemfile::gemfile($filename, $gemfile_DB, $H_DatabaseName);
}

sub cb_yarnfile($$$) {
	my $filename = shift;
	my $yarnfile_DB = shift;
	my $H_detections = shift;
	return framework::yarnFile::yarnFile($filename, $yarnfile_DB, $H_DatabaseName, $H_detections);
}


# ************ Python : callback for setup.py **************
sub cb_setupy($$) {
	my $filename = shift;
	my $setupy_DB = shift;

	my %fullDetections = ();
	push @fullReqTXtDetections, \%fullDetections;
	
	$fullDetections{'filename'} = $filename;
	
	framework::Logs::Debug("  Checking content of $filename as a python setup file ...\n");

	my $content = Lib::Sources::getFileContent($filename);
	if (! defined $content) {
		framework::Logs::Warning("Unable to read $filename for python dependencies inspection purpose.\n");
		return undef;
	}
	
	my @itemDetections = ();

	if ($$content =~ /^(?:([ \t]*import\s+setuptools\b)|(from\s+setuptools\s+import\s+.*\bsetup\b))/m) {
		my $setup_call = 'setup';
		if (defined $1) {
			$setup_call = 'setuptools\.setup';
		}

		#if ($$content =~ /$setup_call\s*\(\s*/g) {
			#$$content = substr $$content, pos($$content);
		if ($$content =~ /^[ \t]*$setup_call\s*\(\s*/m) {
			
			
			#remove docstring
			$$content =~ s/"""("[^"]|""[^"]|[^"])*"""//sg;
			
			my @items = split /(\w+\s*=|\\"|\\'|"|'|,|[()\[\]])/, $$content;

			use constant CODE   => 0;
			use constant DQUOTE => 1;
			use constant SQUOTE => 2;
			
			my $preproCode = "";
			my $string_buffer = "";
			my $state = CODE;
			my %strings = ();
			my $id = 0;
			my $level = 1; # inside the first level paranthesis that correspond to the parameter list.
			for my $item (@items) {

				if ($state == CODE) {
					if ($item eq '"') {
						$state = DQUOTE;
						$string_buffer .= $item;
					}
					elsif ($item eq "'") {
						$state = SQUOTE;
						$string_buffer .= $item;
					}
					elsif ($item eq "(") {
						$preproCode .= $item;
						$level++;
					}
					elsif ($item eq ")") {
						$level--;
						if ($level == 0) {
							# the parenthesis that finishes the parameter list is encountered.
							last;
						}
						$preproCode .= $item;
					}
					else {
						$preproCode .= $item;
					}
				}

				elsif ($state == DQUOTE) {
					if ($item eq '"') {
						$string_buffer .= $item;
						$strings{"CHAINE_$id"} = $string_buffer;
						$preproCode .= " CHAINE_$id";
						$id++;
						$string_buffer = "";
						$state = CODE;
					}
					else {
						$string_buffer .= $item;
					}
				}
				elsif ($state == SQUOTE) {
					if ($item eq "'") {
						$string_buffer .= $item;
						$strings{"CHAINE_$id"} = $string_buffer;
						$preproCode .= " CHAINE_$id";
						$id++;
						$string_buffer = "";
						$state = CODE;
					}
					else {
						$string_buffer .= $item;
					}
				}

			}

			my ($beginning, $call) = split /^[ \t]*$setup_call\s*\(\s*/m, $preproCode;
			
			# get setup_requires parameter ...
			if ($call =~ /(?:^|,)\s*install_requires\s*=\s*(?:(\[[^\]]*)|(\w+))/m) {
				my $depends_list = "";
				if (defined $1) {
					# setuptools.setup( ... install_requires = [ <depends_list> ] ...)
					$depends_list = $1;
				}
				elsif (defined $2) {
					my $ident = $2;
					if ($beginning =~ /\b$ident\s*=\s*(\[[^\]]*)/) {
						# <ident> = [ <depends_list> ]
						# setuptools.setup( ... install_requires = <ident>)
						$depends_list = $1
					}
				}
					
			#if (defined $depends_list) {
				my @depends = ();
				while ($depends_list =~ /\b(CHAINE_\d+\b)/g) {
					my $depend = $strings{$1};
					$depend =~ s/["']//g;
					my ($name, $version) = $depend =~ /\s*([^><=!]*)\s*([><=]+.*)?/;
					$name =~ s/\[[^\]]*\]//;  # remove extra if any ...
					$name =~ s/\s*$//m;  # remove trailing whitespaces if any ...
					
					if (defined $version) {
						$version =~ s/^\s*//m;  # remove beginning whitespaces if any ...
					}
					else {
						$version = '-';
					}
					my $setupItem = framework::detections::getEnvItem($name, $version, $setupy_DB, 'setupy', $filename, $H_DatabaseName);
					if (defined $setupItem) {
						push @itemDetections, $setupItem;
					}
					#push @depends, [$name, $version];
					#print "DEPEND : $name ($version)\n";
				}
			}
		}
	}
	else {
		framework::Logs::Debug("    no dependencies found ...\n");
	}

	return \@itemDetections;
}

# ************ Python : callback for requirements.txt **************
sub cb_reqTxt($$) {
	my $filename = shift;
	my $reqTxt_DB = shift;

	my %fullDetections = ();
	push @fullReqTXtDetections, \%fullDetections;
	
	$fullDetections{'filename'} = $filename;
	
	framework::Logs::Debug("  Checking content of $filename as a python dependencies file ...\n");

	my $content = Lib::Sources::getFileContent($filename);
	if (! defined $content) {
		framework::Logs::Warning("Unable to read $filename for python dependencies inspection purpose.\n");
		return undef;
	}
	
	my @itemDetections = ();
	
	my $detectedEncoding;
	my $coded_content = $$content;
	my $decoded_content = AutoDecode::BinaryBufferToTextBuffer ( $filename, \$coded_content, 0, \$detectedEncoding );
	framework::Logs::Debug("DETECTED ENCODING for $filename : $detectedEncoding\n");
	
	if (defined $decoded_content) {
		$$content = $decoded_content if ($decoded_content);
	}
	else {
		framework::Logs::Warning("Unable to recognize encoding of $filename\n");
	}
	
	while ($$content =~ /^(.*)$/mg) {
		my $line = $1;
		next if ($line =~ /^\s*#/m); # comment line
		next if ($line =~ /^\s*\-r\s+/m); # -r command
		my ($name, $op, $version) = split /(===|[=<>~!]=|<|>|=)/, $line;

		# component name with ';'
		# ex: json-stream; python_version >= '3.6'
		if ($name =~ /;/) {
			$name =~ s/\s*\;.*$//m;
			$version = "";
		}
		
		if (!defined $op) {
			$op = "";
			$version = "";
			framework::Logs::Warning("no version found (or invalid format) for framework $name\n");
		}

		my $reqTxtItem = framework::detections::getEnvItem($name, $op . $version, $reqTxt_DB, 'reqTxt', $filename, $H_DatabaseName);
		if (defined $reqTxtItem) {
			push @itemDetections, $reqTxtItem;
		}
	}
	
	return \@itemDetections;
}

sub cb_pyproject($$) {
	my $filename = shift;
	my $poetry_DB = shift;

	my %fullDetections = ();
	push @fullReqTXtDetections, \%fullDetections;

	$fullDetections{'filename'} = $filename;

	framework::Logs::Debug("  Checking content of $filename as a python dependencies file ...\n");

	my $content = Lib::Sources::getFileContent($filename);
	if (! defined $content) {
		framework::Logs::Warning("Unable to read $filename for python dependencies inspection purpose.\n");
		return undef;
	}

	my @itemDetections = ();

	my $detectedEncoding;
	my $coded_content = $$content;
	my $decoded_content = AutoDecode::BinaryBufferToTextBuffer ( $filename, \$coded_content, 0, \$detectedEncoding );
	framework::Logs::Debug("DETECTED ENCODING for $filename : $detectedEncoding\n");

	if (defined $decoded_content) {
		$$content = $decoded_content if ($decoded_content);
	}
	else {
		framework::Logs::Warning("Unable to recognize encoding of $filename\n");
	}

	# check presence of [tool.poetry.dependencies] in .toml file
	if ($$content =~ /^\s*\[\s*tool\.poetry\.dependencies\s*\]\s*$/mg) {
		while ($$content =~ /
			(^(?:.*)\s*\=\s*\"(?:.*)\"$) # packageName = "xxx"
			|(^(?:.*)\s*\=\s*\{\s*version\s*\=\s*\"(?:.+?)\") # packageName = { version = "xxx"...}
			|(^(?:.*)\s*\=\s*\[) # packageName = [ { version = "xxx" ...}, { version = "yyy" ...} ]
			|(^\s*\[) # end of tool.poetry.dependencies
			/xmg) {
			my ($name, $op, $version) = "";
			if (defined $1) {
				($name, $op, $version) = split /(===|[=<>~!]=|<|>|=)/, $1;
			}
			elsif (defined $2) {
				my $pattern = $2;
				if ($pattern =~ /^(.*)\s*\=\s*\{\s*version\s*\=\s*\"(.+?)\"/m) {
					$name = $1;
					$op = "=";
					$version = $2;
				}
			}
			elsif (defined $3) {
				my $pattern = $3;
				if ($pattern =~ /^(.*)\s*\=\s*\[/m) {
					$name = $1;
					$op = "=";

					while ($$content =~ /version\s*\=\s*\"(.+?)\"|(\])/g) {
						if (defined $1) {
							$version = $1;
							my $depPythonItem = framework::detections::getEnvItem($name, $op . $version, $poetry_DB, 'pyproject', $filename, $H_DatabaseName);
							if (defined $depPythonItem) {
								push @itemDetections, $depPythonItem;
							}
						}
						# end of collection
						last if defined $2;
					}
				}
			}
			elsif (defined $4) {
				# end of tool.poetry.dependencies list
				last;
			}

			if (!defined $op) {
				$op = "";
				$version = "";
				framework::Logs::Warning("no version found (or invalid format) for framework $name\n");
			}
			my $depPythonItem = framework::detections::getEnvItem($name, $op . $version, $poetry_DB, 'poetry', $filename, $H_DatabaseName);
			if (defined $depPythonItem) {
				push @itemDetections, $depPythonItem;
			}
		}
	}

	return \@itemDetections;
}

sub cb_poetryLock($$) {
	my $filename = shift;
	my $poetry_DB = shift;

	my %fullDetections = ();
	push @fullReqTXtDetections, \%fullDetections;

	$fullDetections{'filename'} = $filename;

	framework::Logs::Debug("  Checking content of $filename as a python dependencies file ...\n");

	my $content = Lib::Sources::getFileContent($filename);
	if (! defined $content) {
		framework::Logs::Warning("Unable to read $filename for python dependencies inspection purpose.\n");
		return undef;
	}

	my @itemDetections = ();

	my $detectedEncoding;
	my $coded_content = $$content;
	my $decoded_content = AutoDecode::BinaryBufferToTextBuffer ( $filename, \$coded_content, 0, \$detectedEncoding );
	framework::Logs::Debug("DETECTED ENCODING for $filename : $detectedEncoding\n");

	if (defined $decoded_content) {
		$$content = $decoded_content if ($decoded_content);
	}
	else {
		framework::Logs::Warning("Unable to recognize encoding of $filename\n");
	}
	# supported syntax
	# [[package]]
	# name = xxx
	# version = yyy
	while ($$content =~ /^\[\[package\]\]\s*name\s*\=\s*(.*)\s*version\s*\=\s*\"(.+?)\"$/mg) {
		my $name = $1;
		my $version = $2;
		my $op = "=";
		if ($$content =~ /^category\s*\=\s*\"(.+?)\"$/mgc) {
			my $category = $1;
			# category = "dev" are excluded
			if ($category ne "dev") {
				my $depPythonItem = framework::detections::getEnvItem($name, $op . $version, $poetry_DB, 'poetry', $filename, $H_DatabaseName);
				if (defined $depPythonItem) {
					push @itemDetections, $depPythonItem;
				}
			}
		}
	}

	return \@itemDetections;
}

# ************ Javascript : callback for package.json **************
# Following data are to be filled before calling the callback !!!
my %cb_json_params = ('DB' => undef, 'directories' => {});
# ************ Python
my %cb_python_params = ('DB' => undef, 'directories' => {});

sub parseJsonDependencies($$);
sub parseJsonDependencies($$) {
	my $json = shift;
	my $context = shift;

	my $dependencies;
	if (basename($context->{'jsonPath'}) eq 'composer.json') {
		$dependencies = $json->{'require'};
	}
	else {
		$dependencies = $json->{'dependencies'};
	}
	return if (!defined $dependencies);

	if (ref $dependencies eq 'HASH') {
		# package-lock.json (JS) \ package.json (JS)
		if (basename($context->{'jsonPath'}) =~ /(package(\-lock)?\.json)$/m) {
			for my $dependName (keys %$dependencies) {
				my $dependVersion;
				my $depDef = $dependencies->{$dependName};
				if (ref $depDef eq "HASH") {
					# in package-lock.json, a dependency entry is not associated with a scalar version number, but with a json object => version number is a field of this object !!
					my $dev = 0;
					eval {
						if ((defined $depDef->{'dev'}) && ($depDef->{'dev'} == 1)) {
							$dev = 1;
						}
					};
					if ($@) {
						print STDERR "ERROR when parsing $context->{'jsonPath'}: $dependName will be ignored because 'dev' field has caused an error.\n";
						next;
					}
					elsif ($dev == 1) {
						next;
					}

					$dependVersion = $depDef->{'version'};
					# search for possible sub dependencies
					parseJsonDependencies($depDef, $context);
				}
				else {
					$dependVersion = $depDef;
				}

				push @{$context->{'$depList'}}, { 'name' => $dependName, 'version' => $dependVersion };

				my $jsonItem = framework::detections::getEnvItem($dependName, $dependVersion, $context->{'jsonDB'}, 'json', $context->{'jsonPath'}, $H_DatabaseName);
				if (defined $jsonItem) {
					push @{$context->{'itemDetection'}}, $jsonItem;
				}
			}
		}
		# composer.json (PHP)
		elsif (basename($context->{'jsonPath'}) eq 'composer.json') {
			my $H_dependencies_lock;
			# composer.lock
			if (-e 'composer.lock') {
				$H_dependencies_lock = framework::composer::parseComposerLock();
			}

			# composer.json
			# replace version if exists in composer.lock
			$context = framework::composer::parseComposerJson($dependencies, $H_dependencies_lock, $context, $H_DatabaseName);

		}
	}
	else {
		framework::Logs::Warning("dependencies data structure of " . basename($context->{'jsonPath'}) . " is not recognized\n");
	}
}

sub _cb_json($$) {
	my $jsonPath = shift;
	my $jsonDB = shift;

	my %fullDetections = ();
	$jsonPath = File::Spec->catfile($jsonPath);
	$fullDetections{'filename'} = $jsonPath;
	
	framework::Logs::Debug("  Checking content of $jsonPath for as a JSON project file ...\n");

	my $content = Lib::Sources::getFileContent($jsonPath);
	if (! defined $content) {
		framework::Logs::Warning("Unable to read $jsonPath for json inspection purpose.\n");
		return undef;
	}
	
	my @itemDetections = ();
	my $decoded = eval{ decode_json($$content) };
	
	if ($@) {
		print STDERR "ERROR detected when decoding json file $jsonPath. $@\n";
		return \@itemDetections;
	}
	
	# get the name of the package
	my $packageName = $decoded->{'name'};
	my $packageVersion = $decoded->{'version'};
	
	# Try to match package name.
	if (defined $packageName) {
		push @fullJsonDetections, \%fullDetections;
		
		my $jsonItem = framework::detections::getEnvItem($packageName, $packageVersion, $jsonDB, 'json', $jsonPath, $H_DatabaseName);
		
		if (defined $jsonItem) {
			push @itemDetections, $jsonItem;
		}
	
		$fullDetections{'framework'}->{'name'} = $packageName;
		$fullDetections{'framework'}->{'version'} = $packageVersion;
	}
	
	# get package dependencies
	# NOTE : some other dependencies can be found in $decoded->{'devDependencies'} but will be ignored here !!!
	#my $dependencies = $decoded->{'dependencies'};
	my @depList = ();
	$fullDetections{'framework'}->{'dependencies'} = \@depList;
	
	parseJsonDependencies($decoded, { 'jsonPath' => $jsonPath, 'jsonDB' => $jsonDB, 'itemDetection' => \@itemDetections, 'depList' => \@depList});
	
	return \@itemDetections;
}

sub parseMod($$$) {
	# Supported syntax
		# require module...
		# replace module...
		# require (moduleA
		#		  moduleB...)
		# replace (moduleA => moduleB
		#		  moduleC => moduleD...)
	my $contentFile = shift;
	my $moduleDB = shift;
	my $modulePath = shift;
	my $itemDetections =();
	my $countComment = 0;
	if ($$contentFile =~ /(.*?)^\s*(require|replace)\s*[\(]?/smg) {
		my $previousBloc = $1;
		my $stmt = $2;
		if (defined $stmt) {
			# detect multi line comment
			# use of syntax: /* ... */
			$countComment = isDetectedComment($previousBloc, $countComment);
			my $regexMod = qr/^(.*?)\s*((?:[\w._-]+\/)+[\w._-]+)\s*v([\w._]+)/m;

			while ($$contentFile =~ /$regexMod/mg) {
				$previousBloc = $1;
				my $moduleName = $2;
				my $version = $3;
				my $moduleItem;
				# detect multi line comment
				if (defined $previousBloc && $previousBloc ne '') {
					$countComment = isDetectedComment($previousBloc, $countComment);
				}
				# if we are not in a comment: begin or continue listing modules
				if ($countComment == 0) {
					if (defined $previousBloc && $previousBloc !~ /^\s*\/\//m) {
						# 'replace' statement is taken into account
						# i.e. replace (moduleA => moduleB)
						# moduleB is memorized
						my $env;
						# list environment
						if ($moduleName =~ /([\w._-]+)\/(.*)/) {
							$env = $1;
							$moduleName = $2;
						}
						$moduleItem = framework::detections::getEnvItem($moduleName, $version, $moduleDB, $env, $modulePath, $H_DatabaseName);
					}
					if (defined $moduleItem) {
						push @{$itemDetections}, $moduleItem;
					}
				}
			}
		}
	}
	return $itemDetections;
}

sub parseSum($$$) {
	# Supported syntax
		# modulePath vx.x.x-timestamp-commitHash
	my $contentFile = shift;
	my $moduleDB = shift;
	my $modulePath = shift;
	my $itemDetections = ();
	my $regexMod = qr/^\s*((?:[\w._-]+\/)+[\w._-]+)\s*v([\w._]+)/m;

	while ($$contentFile =~ /$regexMod/mg) {
		my $moduleName = $1;
		my $version = $2;
		my $moduleItem;
		my $env;
		# list environment
		if ($moduleName =~ /([\w._-]+)\/(.*)/) {
			$env = $1;
			$moduleName = $2;
		}

		$moduleItem = framework::detections::getEnvItem($moduleName, $version, $moduleDB, $env, $modulePath, $H_DatabaseName);

		if (defined $moduleItem) {
			push @{$itemDetections}, $moduleItem;
		}
	}
	# use of "minimal version selection" algorithm
	# keep only higher version for same package of same major version
	my %exportedModule = ();
	foreach my $currentItem (@{$itemDetections}) {
		if (exists $exportedModule{$currentItem->{'framework_name'}}) {
			my @split_itemVersion = split(/\./, $currentItem->{'data'}->{max});
			my @split_itemVersionMax = split(/\./, $exportedModule{$currentItem->{'framework_name'}}->{'maxVersion'});
			for my $indice  (0 .. $#split_itemVersion) {
				if (defined $split_itemVersionMax[$indice]) {
					if ($split_itemVersion[$indice] > $split_itemVersionMax[$indice]) {
						# Max version may be replaced
						$exportedModule{$currentItem->{'framework_name'}}->{'maxVersion'} = $currentItem->{'data'}->{max};
					}
				}
			}
		}
		else {
			$exportedModule{$currentItem->{'framework_name'}}->{'maxVersion'} = $currentItem->{'data'}->{max};
		}
	}

	my @itemDetectionFiltered = ();
	my %seen;
	foreach my $elt (@{$itemDetections}) {
		if ($elt->{'data'}->{max} eq $exportedModule{$elt->{'framework_name'}}->{'maxVersion'}) {
			# go.sum can declare twice same package/version
			# check to avoid duplicates
			if (! exists $seen{$elt->{'framework_name'}}) {
				push(@itemDetectionFiltered, $elt);
				$seen{$elt->{'framework_name'}} = 1;
			}
		}
	}
	return \@itemDetectionFiltered;
}

sub isDetectedComment($$) {
	my $bloc = shift;
	my $countEmbeddedComment = shift;

	while ($bloc =~ /\/\*/g) {
		$countEmbeddedComment++;
	}
	while ($bloc =~ /\*\//g) {
		$countEmbeddedComment--;
	}

	return $countEmbeddedComment;
}

sub _cb_module($$$) {
	my $modulePath = shift;
	my $moduleDB = shift;
	my $kindFile = shift;

	framework::Logs::Debug("  Checking content of $modulePath for as a go module project file ...\n");

	my $contentFile = Lib::Sources::getFileContent($modulePath);
	if (!defined $contentFile) {
		framework::Logs::Warning("Unable to read $modulePath for go module inspection purpose.\n");
		return undef;
	}
	my $itemDetections = ();
	if ($kindFile eq 'mod') {
		$itemDetections = parseMod($contentFile, $moduleDB, $modulePath);
	}
	elsif ($kindFile eq 'sum') {
		$itemDetections = parseSum($contentFile, $moduleDB, $modulePath);
	}
	return $itemDetections;
}

sub cb_json() {
	my $itemDetections;
	for my $dir (keys %{$cb_json_params{'directories'}}) {
		## JS / Typescript
		# .bower.json
		if (exists $cb_json_params{'directories'}->{$dir}->{'.bower.json'}) {
			$itemDetections = _cb_json("$dir/.bower.json", $cb_json_params{'DB'});
		}
		# bower.json
		if (exists $cb_json_params{'directories'}->{$dir}->{'bower.json'}) {
			$itemDetections = _cb_json("$dir/bower.json", $cb_json_params{'DB'});
		}

		# priority for package-lock
		if (exists $cb_json_params{'directories'}->{$dir}->{'package-lock.json'}) {
			$itemDetections = _cb_json("$dir/package-lock.json", $cb_json_params{'DB'});
		}
		elsif (exists $cb_json_params{'directories'}->{$dir}->{'package.json'}) {
			$itemDetections = _cb_json("$dir/package.json", $cb_json_params{'DB'});
		}
		## PHP
		elsif (exists $cb_json_params{'directories'}->{$dir}->{'composer.json'}) {
			$itemDetections = _cb_json("$dir/composer.json", $cb_json_params{'DB'});
		}

		for my $itemDetection (@$itemDetections) {
			if (defined $itemDetection) {
				framework::detections::addItemDetection(\%H_detections, $itemDetection);
			}
		}
	}
}

sub cb_python() {
	my $itemDetections;
	for my $dir (keys %{$cb_python_params{'directories'}}) {
		## Python
		# for each directory priority on poetry.lock file
		if (exists $cb_python_params{'directories'}->{$dir}->{'poetry.lock'}) {
			$itemDetections = cb_poetryLock("$dir\/poetry.lock", $cb_python_params{'DB'});
		}
		else {
			if (exists $cb_python_params{'directories'}->{$dir}->{'pyproject.toml'}) {
				push @{$itemDetections}, @{cb_pyproject("$dir\/pyproject.toml", $cb_python_params{'DB'})};
			}
			foreach my $file (keys %{$cb_python_params{'directories'}->{$dir}}) {
				if ($file =~ /^requirements(?:\-(.*))?\.txt$/m) {
					push @{$itemDetections}, @{cb_reqTxt("$dir\/$file", $cb_python_params{'DB'})};
				}
			}
			if (exists $cb_python_params{'directories'}->{$dir}->{'setup.py'}) {
				push @{$itemDetections}, @{cb_setupy("$dir\/setup.py", $cb_python_params{'DB'})};
			}
		}

		for my $itemDetection (@$itemDetections) {
			if (defined $itemDetection) {
				framework::detections::addItemDetection(\%H_detections, $itemDetection);
			}
		}
	}
}

sub cb_module() {
	my $itemDetections;
	for my $dir (keys %{$cb_module_params{'directories'}}) {
		# go.sum priority
		if (exists $cb_module_params{'directories'}->{$dir}->{'go.sum'}) {
			$itemDetections = _cb_module("$dir/go.sum", $cb_module_params{'DB'}, 'sum');
		}
		elsif (exists $cb_module_params{'directories'}->{$dir}->{'go.mod'}) {
			$itemDetections = _cb_module("$dir/go.mod", $cb_module_params{'DB'}, 'mod');
		}

		for my $itemDetection (@$itemDetections) {
			if (defined $itemDetection) {
				framework::detections::addItemDetection(\%H_detections, $itemDetection);
			}
		}
	}
}

sub cb_filename($$$) {
	my $searchItem = shift;
	my $filename = shift;
	my $filePattern = shift;

	# compute the base filename of the current discovered file
	my $dirname;
	my $basefile = $filename;
	#$basefile =~ s/^.*[\\\/]//;
	($dirname, $basefile) = $filename =~ /(.*?)([^\\\/]*)$/;

	# check eligibility of the file... 
	if ($basefile =~ /^$filePattern$/) {

		# get patterns ...
		my $patterns = $searchItem->[$framework::dataType::IDX_PATTERNS];

		# options could be: exact matching, case insensitive, extract version.
		my $options = $searchItem->[$framework::dataType::IDX_OPTIONS];

		my $mod = $options->{'regmod'};
		if (!defined $mod) {
			$mod = "";
		}

		if (defined $patterns) {
			for my $pattern (@$patterns) {
				# additional check on the filename
				if ($basefile =~ /(?$mod)$pattern/) {
					# FIXME : should be activated by option only. (getversion:yes)
					my ($version) = framework::version::detectVersionInFileName($basefile, $options);
					return [ framework::detections::createItemDetection($searchItem, $basefile, $version, 'filename', $framework::dataType::STATUS_DISCOVERED, $dirname) ];
				}
			}
		}
		else {
			# NO additional check on the filename, framework  is detected !
			return [ framework::detections::createItemDetection($searchItem, $basefile, undef, 'filename', $framework::dataType::STATUS_DISCOVERED, $dirname) ];
		}
	}
	return undef;
}

sub cb_filecontent($$$) {
	my $searchItem = shift;
	my $filename = shift;
	my $filePattern = shift;

	# compute the base filename of the current discovered file
	my $basefile = $filename;
	$basefile =~ s/^.*[\\\/]//;

	# check eligibility of the file... 
	if ($basefile =~ /^$filePattern$/m) {
		framework::Logs::Debug("  Checking content of $filename for as a project file ...\n");

		my $content = getFileContentFromCache($filename);

		if (!defined $content) {
			# first reading trying ...
			$content = Lib::Sources::getFileContent($filename);
			if (!defined $content) {
				framework::Logs::Warning("Unable to read $filename for project file inspection purpose.\n");
				return undef;
			}
			setFileContentInCache($filename, $content);
		}
		elsif ($content == -1) {
			# the file has already been tried to read, and it has failed ...
			return undef;
		}

		# get patterns ...
		my $patterns = $searchItem->[$framework::dataType::IDX_PATTERNS];
		# options could be: exact matching, case insensitive, extract version.
		my $options = $searchItem->[$framework::dataType::IDX_OPTIONS];
		my $mod = $options->{'regmod'};
		if (!defined $mod) {
			$mod = "";
		}

		if (defined $patterns) {
			for my $pattern (@$patterns) {
				if ($$content =~ /(?$mod)($pattern)/) {
					# check if the pattern contain a version number.
					my ($version) = framework::version::detectVersionInFileName($1, $options);
					return [ framework::detections::createItemDetection($searchItem, $1, $version, 'filecontent', $framework::dataType::STATUS_DISCOVERED, $filename) ];
				}
			}
		}
	}
	return undef;
}

my %env_Callback = ( 'filename' => \&cb_filename, 'filecontent' => \&cb_filecontent );
my %env_DB = ();
my %envPublished_DB = ();

sub registerEnv($$) {
	my $envName = shift;
	my $DB = shift;

	$env_DB{$envName} = $DB->{$envName};

	if (!exists $env_Callback{$envName}) {
		framework::Logs::warning("no callback for environment $envName\n");
	}
}

sub publishEnv($$) {
	my $envName = shift;
	my $DB = shift;

	$envPublished_DB{$envName} = $DB->{$envName};
}

#sub addItemDetection($$) {
#	my $H_detect = shift;
#	my $itemDetect = shift;
#	
#	my $frameworkName = $itemDetect->{'framework_name'};
#	if (! defined $H_detect->{$frameworkName}) {
#		$H_detect->{$frameworkName} = [];
#		push @{$H_detect->{$frameworkName}}, $itemDetect->{'data'};
#	}
#	else {
#		# FIXME : manage version
#		# 	- check version conflicts.
#		#	- merge version with previous detections (in other environments or not)
#		
#		# add the item to the list
#		push @{$H_detect->{$frameworkName}}, $itemDetect->{'data'};
#	}
#	framework::detections::referenceDetectedItem($itemDetect->{'data'}->{$framework::dataType::ITEM});
#}

sub DosJoker2regexp($) {
	my $regexp = shift;
	$regexp =~ s/\*/\.\*/g;
	$regexp =~ s/\?/\./g;
	return $regexp;
}

# all project files are input
sub mainFileTrigger($) {
	my $projectFiles = shift;

	for my $filePath (@{$projectFiles}) {

		framework::Logs::Debug("Checking project file $filePath ...\n");

		if ($TECHNO eq "JS" || $TECHNO eq "Typescript") {
			# package.json, package-lock.json & bower.json
			my $filename_json = basename($filePath);
			my $jsonDB = $envPublished_DB{'json'};
			if ($filename_json eq 'package.json' || $filename_json eq 'package-lock.json'
				|| $filename_json eq '.bower.json' || $filename_json eq 'bower.json') {
				my $path = dirname($filePath);
				if ($filter_node_modules eq 'OFF') {
					$FINAL_CALLBACKS{'json'} = \&cb_json;
					$cb_json_params{'DB'} = $envPublished_DB{'json'};
					$cb_json_params{'directories'}->{$path}->{$filename_json} = 1;
				}
				# $filter_node_modules is ON
				elsif ($path !~ /\bnode\_modules\b/) {
					$FINAL_CALLBACKS{'json'} = \&cb_json;
					$cb_json_params{'DB'} = $envPublished_DB{'json'};
					$cb_json_params{'directories'}->{$path}->{$filename_json} = 1;
				}
			}
		}
		elsif ($TECHNO eq "Python") {
			my $filename_python = basename($filePath);
			# requirements file, pyproject.toml, poetry.lock
			my $path = dirname($filePath);
			if ($filename_python =~ /^requirements(?:\-(.*))?\.txt$/m) {
				my $bool_check = 1;
				if (defined $1) {
					my $suffix = $1;
					# requirements-dev.txt & requirements-test.txt & requirements-tests.txt are excluded
					if ($suffix eq "dev" || $suffix =~ /^tests?$/m) {
						$bool_check = 0;
					}
				}
				if ($bool_check == 1) {
					$FINAL_CALLBACKS{'reqTxt'} = \&cb_python;
					$cb_python_params{'DB'} = $envPublished_DB{'reqTxt'};
					$cb_python_params{'directories'}->{$path}->{$filename_python} = 1;
				}
			}
			elsif ($filename_python eq "poetry.lock" || $filename_python eq "pyproject.toml") {
				$FINAL_CALLBACKS{'poetry'} = \&cb_python;
				$cb_python_params{'DB'} = $envPublished_DB{'poetry'};
				$cb_python_params{'directories'}->{$path}->{$filename_python} = 1;
			}
			# files "setup.py" are hardly associated to setupy env.
			elsif ($filename_python eq "setup.py") {
				$FINAL_CALLBACKS{'setupy'} = \&cb_python;
				$cb_python_params{'DB'} = $envPublished_DB{'setupy'};
				$cb_python_params{'directories'}->{$path}->{$filename_python} = 1;
			}
		}
		elsif ($TECHNO eq "CS") {
			if ($filePath =~ /\.csproj$/m) {
				# register for delayed execution (wait all .csproj file have been discovered)...
				$FINAL_CALLBACKS{'csproj'} = \&cb_csproj;
				$cb_csproj_params{'DB'} = $envPublished_DB{'csproj'};
				push @{$cb_csproj_params{'filelist'}}, $filePath;
			}
		}
		elsif ($TECHNO eq "Java") {
			# part of code disabled to adopt version sharing between build & dependencies.gradle
			#	if ($filename =~ /(?:^|[\\\/])(?:build|dependencies)\.gradle$/im) {
			#		my $gradle_DB = $envPublished_DB{'gradle'};
			#		my $itemDetections = cb_gradle($filename, $gradle_DB);
			#		# Add detections
			#		for my $itemDetection (@$itemDetections) {
			#			if (defined $itemDetection) {
			#				framework::detections::addItemDetection(\%H_detections, $itemDetection);
			#			}
			#		}
			#	}
			if ($filePath =~ /(?:^|[\\\/])build.xml$/m) {
				my $ant_DB = $envPublished_DB{'ant'};
				my $itemDetections = cb_ant([ $filePath ], $ant_DB);
				# Add detections
				for my $itemDetection (@$itemDetections) {
					if (defined $itemDetection) {
						framework::detections::addItemDetection(\%H_detections, $itemDetection);
					}
				}
			}
		}
		elsif ($TECHNO eq "Ruby") {
			if ($filePath =~ /(?:^|[\\\/])Gemfile.lock$/m) {
				my $gemfile_DB = $envPublished_DB{'gemfile'};
				my $itemDetections = cb_gemfile($filePath, $gemfile_DB);
				# Add detections
				for my $itemDetection (@$itemDetections) {
					if (defined $itemDetection) {
						framework::detections::addItemDetection(\%H_detections, $itemDetection);
					}
				}
			}
		}
		elsif ($TECHNO eq "PHP") {
			my $jsonDB = $envPublished_DB{'json'};
			if ($filePath =~ /(^|.*)[\\\/]?(composer\.json)$/) {
				my $path = dirname($filePath);
				$FINAL_CALLBACKS{'json'} = \&cb_json;
				$cb_json_params{'DB'} = $envPublished_DB{'json'};
				$cb_json_params{'directories'}->{$path}->{$2} = 1;
			}
		}
		elsif ($TECHNO eq "Go") {
			my $moduleDB = $envPublished_DB{'module'};
			if ($filePath =~ /(^|.*)[\\\/]?(go\.(?:mod|sum))$/) {
				my $path = dirname($filePath);
				$FINAL_CALLBACKS{'module'} = \&cb_module;
				$cb_module_params{'DB'} = $envPublished_DB{'module'};
				$cb_module_params{'directories'}->{$path}->{$2} = 1;
			}
		}

		# File content will be initialized by the first callback that need it,
		my $FileContent = undef;

		# for each environment registered in this projectFiles module:
		for my $searchEnv (keys %env_DB) {

			# get corresponding data
			my $searchEnvDB = $env_DB{$searchEnv};

			# If there are data corresponding to this environment :
			if (defined $searchEnvDB) {

				# Get the selectors
				for my $item (keys %{$searchEnvDB->{'PATTERNS'}}) {
					my $searchItem = $searchEnvDB->{'PATTERNS'}->{$item};
					my $selectorsList = $searchItem->[$framework::dataType::IDX_SELECTORS];
					my $callback = $env_Callback{$searchEnv};

					# for each pattern
					for my $filePattern (@$selectorsList) {

						my $regexpFilePattern = DosJoker2regexp($filePattern);

						# call the callback
						my $itemDetections = $callback->($searchItem, $filePath, $regexpFilePattern, $FileContent);
						for my $itemDetection (@$itemDetections) {
							if (defined $itemDetection) {
								framework::detections::addItemDetection(\%H_detections, $itemDetection);
							}
						}
					}
				}
			}
		}
	}
}

sub fileTriggerYarn($) {
	my $files_yarn = shift;
	for my $yarnFile (@{$files_yarn}) {
		framework::Logs::Debug("Checking project file $yarnFile ...\n");
		# HL-738 09/07/2019 Support framework discovery for yarn.lock files
		# HL-2006 04/04/2022 Deduce level-1 dependencies by merging data from yarn.lock and package.json
		my $yarnfile_DB = $envPublished_DB{'yarnfile'};
		cb_yarnfile($yarnFile, $yarnfile_DB, \%H_detections);
	}
}

sub fileTriggerGradle($) {
	my $files_gradle = shift;

	framework::Logs::Debug("Checking gradle files ...\n");

	my $gradle_DB = $envPublished_DB{'gradle'};
	my $itemDetections = cb_gradle($files_gradle, $gradle_DB);
	# Add detections
	for my $itemDetection (@$itemDetections) {
		if (defined $itemDetection) {
			framework::detections::addItemDetection(\%H_detections, $itemDetection);
		}
	}
}

sub detect($$$) {
	my $tabdir = shift;
	my $DB = shift;
	$TECHNO = shift;

	%H_detections = ();

	# Environment that will automatically be invoked FOR EACH files
	registerEnv('filename', $DB);
	registerEnv('filecontent', $DB);

	# Environemnent available in this module but NOT AUTOMATICALLY invoked
	publishEnv('json', $DB);
	publishEnv('reqTxt', $DB);
	publishEnv('poetry', $DB);
	publishEnv('setupy', $DB);
	publishEnv('csproj', $DB);
	publishEnv('gradle', $DB);
	publishEnv('ant', $DB);
	publishEnv('module', $DB);

	# built the list of framework names OTHER THAN json ! 
	#$NotJsonFramework = framework::importExternal::BuiltFrameworkNamesListExceptEnv($DB, 'json');
	# build HASH for all framework (in lower case) of all environment.
	$H_DatabaseName = framework::importExternal::getHashLowercaseNames($DB);
	my @dirpath = (File::Spec->catfile($tabdir->[0]));

	# HL-2006 13/06/2022
	# check if node_modules filter may be on or off
	# if a package.json or package-lock.json file is found outside the node_modules directory
	# => filter_node_modules is ON and otherwise is OFF by default
	# node_modules scan can be forced by --includeAllDependencies option
	my $parametres = AnalyseUtil::recuperer_options();
	my $options = $parametres->[0];
	if (!defined $options->{'--includeAllDependencies'}) {
		$filter_node_modules = Analyse::get_node_modules_filter;
	}

	# scan all project files
	my @projectFiles;
	my @files_gradle;
	my @yarnFiles;
	find({ wanted => sub {
		# list all project files
		push @projectFiles, File::Spec->catfile($File::Find::name);
		## GRADLE
		# HL-2139 27/07/2022 Support build.gradle.kts for dependency/version extraction
		if (($TECHNO eq "Java" || $TECHNO eq "Kotlin" || $TECHNO eq "Groovy" || $TECHNO eq "Scala")
			&& $File::Find::name =~ /\b(?:build|dependencies)\.gradle(?:\.kts)?$/m) {
			push @files_gradle, File::Spec->catfile($File::Find::name);
		}
		## YARN
		elsif (($TECHNO eq "JS" || $TECHNO eq "Typescript")
			&& $File::Find::name =~ /\byarn\.lock$/m) {
			if ($filter_node_modules eq 'OFF') {
				push @yarnFiles, File::Spec->catfile($File::Find::name);
			}
			# $filter_node_modules is ON
			elsif ($File::Find::name !~ /\bnode\_modules\b/) {
				push @yarnFiles, File::Spec->catfile($File::Find::name);
			}
		}
	}, no_chdir => 1 # no_chdir option for allowing long path scan file
	}, @dirpath);

	## PROJECT FILES
	# JS/TS: package.json, package-lock.json & bower.json
	# Python: requirements file, setup.py, pyproject.toml, poetry.lock
	# C# csproj
	# Java: ant
	# Ruby: Gemfile
	# PHP: composer.php
	# Go: go.mod, go.sum
	mainFileTrigger(\@projectFiles);

	# original recursive scan used before refactoring
	# Lib::Sources::findFiles($tabdir->[0], '.*', [ \&fileTrigger ]);

	## Java/Kotlin/Groovy/Scala: gradle
	if ($TECHNO eq "Java" || $TECHNO eq "Kotlin" || $TECHNO eq "Groovy" || $TECHNO eq "Scala") {
		fileTriggerGradle(\@files_gradle);
	}
	## JS/TS: yarn
	elsif ($TECHNO eq "JS" || $TECHNO eq "Typescript") {
		# first, list deps in package-lock.json & package.json
		for my $key (keys %FINAL_CALLBACKS) {
			if ($key eq 'json') {
				$FINAL_CALLBACKS{$key}->();
			}
		}

		# yarn.lock (keep only deps in package-lock.json & package.json files)
		# yarn.lock files path are sorted by descending depth order for keeping inheritance component version
		# yarn.lock in the root is considered as reference
		@yarnFiles = sort {
			my $depthA = $a =~ s/(\\)/$1/g;
			my $depthB = $b =~ s/(\\)/$1/g;
			$depthB <=> $depthA} @yarnFiles;

		fileTriggerYarn(\@yarnFiles);
		# json callbacks are not necessary now
		delete $FINAL_CALLBACKS{'json'};
	}

	for my $key (keys %FINAL_CALLBACKS) {
		$FINAL_CALLBACKS{$key}->();
	}

	#dumpJsonDependencies();

	return \%H_detections;
}

1;

