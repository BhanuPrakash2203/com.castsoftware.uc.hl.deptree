package framework::msproj;

use strict;
use warnings;
 
#use XML::Twig;
use Lib::XML;
use framework::dataType;
use framework::detections;

sub parse_dotnetproj($$) {
	my $projfile = shift;
	my $csprojDB = shift;
	
	my %proj = ( 'dependencies' => [], 'filename' => $projfile, 'projectReference' => []);
	
	## Parsing façon DOM, tout en mémoire
	##my $twig = XML::Twig->new( twig_roots => { project => 1});
	#my $twig = XML::Twig->new();
	

	## Création d'un objet twig
	#my $csprojContent;
	#eval {
		#$csprojContent = $twig->parsefile($projfile);
	#};
	#if ( $@ ) {
		#my $msg = $@;
		#$msg =~ s/\n$//m;
		#print "[framework::msproj:".__LINE__."] framework detection : skipping file $projfile ($msg)\n";
		#return \%proj;
	#}

print "Loading $projfile\n";
	my $csprojContent = Lib::XML::load_xml($projfile);

	#  REFERENCES : <Reference Include="<name>, Version=<version>, ...." >
	# (managed references)
	
	# count elsewhere in the document all "Reference" nodes having having an attribute "include"
	#my @References  = $csprojContent->findnodes('//Reference[@Include]');
	my @References = Lib::XML::findnodes($csprojContent, '//Reference[@Include]');
	
	for my $ref (@References) {
		#my $include = $ref->{'att'}->{'Include'};
		my $include = $ref->findvalue('./@Include');
		if (defined $include) {
			if ($include =~ /^([^,]*)/) {
				my $name = $1;
				my $version = "";
				if ($include =~ /\bVersion\s*=\s*([^,]*)/) {
					$version = $1;
				}
				$name =~ s/\s*$//m;
				push @{$proj{'dependencies'}}, [$name, $version];
#print "ADDING xproj reference : $name ($version)\n";
			}
		}
	}
	
	#  COM REFERENCES : <COMReference Include="<name>, Version=<version>, ...." >
	# (unmanaged references)
	
	# count elsewhere in the document all "COMReference" nodes having having an attribute "include"
	#my @COMReferences  = $csprojContent->findnodes('//COMReference[@Include]');
	my @COMReferences = Lib::XML::findnodes($csprojContent, '//COMReference[@Include]');
	for my $ref (@COMReferences) {
		#my $include = $ref->{'att'}->{'Include'};
		my $include = $ref->findvalue('./@Include');
		if (defined $include) {
			if ($include =~ /^([^,]*)/) {
				my $name = $1;
				my $version = "";

				#my $nodeMajorVersion = $ref->first_child('VersionMajor');
				my $nodeMajorVersion = $ref->getChildrenByLocalName('VersionMajor')->[0];
				
				if (defined $nodeMajorVersion) {
					$version = $nodeMajorVersion->textContent;
				}
				#my $nodeMinorVersion = $ref->first_child('VersionMinor');  # FIXME
				my $nodeMinorVersion = $ref->getChildrenByLocalName('VersionMinor')->[0];
				if (defined $nodeMinorVersion) {
					$version .= ".".$nodeMinorVersion->textContent;
				}
				push @{$proj{'dependencies'}}, [$name, $version];
#print "ADDING xproj COM reference : $name ($version)\n";
			}
		}
	}
	
	#  PACKAGE REFERENCES : <PackageReference Include="<name>" Version="<version>" .... >
	
	# count elsewhere in the document all "PackageReference" nodes having having an attribute "Include"
	#my @PackageReferences  = $csprojContent->findnodes('//PackageReference[@Include]');
	my @PackageReferences  = Lib::XML::findnodes($csprojContent, '//PackageReference[@Include]');

	for my $ref (@PackageReferences) {
		#my $name = $ref->{'att'}->{'Include'} || "";
		my $name = $ref->findvalue('./@Include') || "";
		#my $version = $ref->{'att'}->{'Version'} || "";
		my $version = $ref->findvalue('./@Version') || "";
		
		push @{$proj{'dependencies'}}, [$name, $version];
#print "ADDING xproj package reference : $name ($version)\n";
	}

	#my @ProjectReferences  = $csprojContent->findnodes('//ProjectReference[@Include]');
	my @ProjectReferences  = Lib::XML::findnodes($csprojContent, '//ProjectReference[@Include]');
	for my $ref (@ProjectReferences) {
		#my $file = $ref->{'att'}->{'Include'};
		my $file = $ref->findvalue('./@Include');
		#my $nameTag = $ref->first_child('Name');   # FIXME
		my $nameTag = $ref->getChildrenByLocalName('Name')->[0];
		my $name;
		if (defined $nameTag) {
			$name = $nameTag->textContent;
		}
		else {
			($name) = $file =~ /([^\\\/\.]+)\.\w+$/m;
		}
		if (defined $name) {
			push @{$proj{'projectReference'}}, [$file, $name];
#print "******** $projfile ~~~~~~~~> $file ($name)\n";
		}
	}

	return \%proj;
}

# ************ .net : callback for xxx.csproj **************
sub analyse_csproj($$;$) {
	my $filelist = shift;
	my $csprojDB = shift;
	my $H_DatabaseName = shift;
	
	my @projects = ();
	
	for my $file (@$filelist) {
		my $proj = parse_dotnetproj($file, $csprojDB);
		push @projects, $proj;
	}

	my @itemDetections = ();
	
	# For each project ...
	for my $proj (@projects) {
		
		# ... try to recognize each dependency and create a item detection...
		for my $dep (@{$proj->{'dependencies'}}) {
			my $item = framework::detections::getEnvItem(	$dep->[0], # name
															$dep->[1], # version
															$csprojDB, 'csproj',
															$proj->{'filename'},
															$H_DatabaseName);
			if (defined $item) {
				push @itemDetections, $item;
			}
		}
	}
	
	return \@itemDetections;
}

1;
