package framework::Java_FW;

use warnings;
use strict;
use framework::baseFramework;
use framework::maven;
use framework::projectFiles;

our @ISA = ("framework::baseFramework");

my $TECHNO = 'Java';

# API implementation type(=open source/commercial)

# Il faut spécifier aussi la vue dans laquelle doit être faite la recherce de pattern. (code ar défaut).

#******************** ITEMS DEFINITION *******************
my $importHibernate = 'ImportHibernate';
my $importJPA = 'importJPA';
my $importCorba = 'importCorba';
my $importRMI = 'importRMI';
my $importJAXR = 'importJAXR';
my $tags = "tags";

#******************** MAIN LIST **************************

my %DB = (
	'code' => {
		'PATTERNS' => {}
	}
);


sub new($$) {
	my $class = shift;
	my $techno = shift;
	my $tabTabSource = shift;
	
	my $self = $class->SUPER::new($techno, \%DB, $tabTabSource);

	bless ($self, $class);
	
	print "[framework] Java framework detection plugin loaded ...\n";
	
	return $self;
}

sub preAnalysisDetection() {
	my $self = shift;
}

sub insideSourceDetection($$) {
	my $self = shift;
	my $views = shift;
	my $filename = shift;

	# tell the parent to not merge the result. This will be done in this overriding function.
	my $merge_result_in_parent = 0;
	
	# scan the code source 
	my $H_FileDetection = $self->SUPER::insideSourceDetection($views, $filename, $merge_result_in_parent);
	
	# Put here the code for analyzing correlation between detections and eventually modify some data (like version !)
	# ...

	# merge into SUPER::H_detmergeInsideSourceDetectionections. (that will be stored when calling potAnalysisDetection)
	$self->mergeInsideSourceDetection($H_FileDetection, \&framework::detections::default_merge_callback);
}

sub postAnalysisDetection() {
	my $self = shift; 
	
	# scan the maven project
	my $H_MavenDetection = framework::maven::detect($self->{'tabSourceDir'}, $self->{'DB'});
	# store the results.
	$self->store_result($H_MavenDetection);
	
	# scan project file : !!! this is assumed by SUPER::postAnalysisDetection  !!! 
	#my $H_ProjectFilesDetection = framework::projectFiles::detect($self->{'tabSourceDir'}, $self->{'DB'}, "Java");
	# store the results.
	#$self->store_result($H_ProjectFilesDetection);
	
	$self->SUPER::postAnalysisDetection();
}

1;
