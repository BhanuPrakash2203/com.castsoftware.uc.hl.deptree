package framework::ant;

use strict;
use warnings;
 
#use XML::Twig;
use Lib::XML;
use framework::dataType;
use framework::detections;

sub parse_antproj($$) {
	my $projfile = shift;
	my $antDB = shift;
	
	my %proj = ( 'dependencies' => [], 'filename' => $projfile, 'projectReference' => []);

print "Loading $projfile\n";
	my $antContent = Lib::XML::load_xml($projfile);
	
	# count elsewhere in the document all <file> nodes that are inside a <resources> node
	my @filesResources = Lib::XML::findnodes($antContent, '//resources/file');
	
	for my $ref (@filesResources) {
		my $file = $ref->findvalue('./@file');
		if (defined $file) {
#print "RESOURCE = $file\n";
			if ($file =~ /([\w+\.-]+)\.jar/) {
				my $fullname = $1;
				my @parts = split /(-[\d\.]+(?:-|$))/m, $fullname;
			
				if (scalar @parts) {
					my $version = $parts[1]||"";
					$version =~ s/^-//m;
					$version =~ s/-$//m;
					push @{$proj{'dependencies'}}, [$parts[0], $version];
#print "=====> $parts[0] ($version)\n";
				}
			}
		}
	}

	return \%proj;
}

# ************ ant : callback for build.xml **************
sub analyse_ant($$;$) {
	my $filelist = shift;
	my $antDB = shift;
	my $H_DatabaseName = shift;
	
	my @projects = ();
	
	for my $file (@$filelist) {
		my $proj = parse_antproj($file, $antDB);
		push @projects, $proj;
	}

	my @itemDetections = ();
	
	# For each project ...
	for my $proj (@projects) {
		
		# ... try to recognize each dependency and create a item detection...
		for my $dep (@{$proj->{'dependencies'}}) {
			my $item = framework::detections::getEnvItem(	$dep->[0], # name
															$dep->[1], # version
															$antDB, 'ant',
															$proj->{'filename'},
															$H_DatabaseName);
															
			# FIXME : if th ant framework discoverer is used we should enhance it by managing
			# module like in maven. Two ways possible:
			# - overloading the $item data retrived here:
			# 	$item->{'data'}->{$framework::dataType::MODULE} = $dep->[2] || "";
			#	$item->{'data'}->{$framework::dataType::VERSION_MODULE} = $depend->[3] || "";
			#	$item->{'data'}->{$framework::dataType::ITEM} .= "#".$dep->[2];
			#
			# - modify generic function like framework::detections::getEnvItem() in the way they manage modules !
															
			if (defined $item) {
				push @itemDetections, $item;
			}
		}
	}
	
	return \@itemDetections;
}

1;

