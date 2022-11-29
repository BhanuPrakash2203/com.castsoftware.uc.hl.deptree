package framework::combinations;

use strict;
use warnings;

use framework::detections;
use framework::dataType;
use Lib::Sources;
use framework::Logs;
use framework::version;

my %H_detections = ();

sub createItemDetection($$$$) {
	my $searchItem = shift;
	my $pattern = shift;
	my $version = shift;
	my $env = shift;

	# FIXME : remove characters that will conflict with csv format.
	$pattern =~ s/[\n;]//sg;
	# FIXME : remove useless spaces (beginning and trailing spaces).
	$pattern =~ s/^\s*//sg;
	$pattern =~ s/\s*$//sg;

	my $mintext = $searchItem->[$framework::dataType::IDX_MIN];
	my $maxtext = $searchItem->[$framework::dataType::IDX_MAX];

	#
	# Put here code to merge version detected with the pattern and version coming from the item description.
	#

	my $itemResult = {};
	$itemResult->{'framework_name'} = $searchItem->[$framework::dataType::IDX_NAME];
	$itemResult->{'data'}->{$framework::dataType::ITEM} = $searchItem->[$framework::dataType::IDX_ITEM];
	$itemResult->{'data'}->{$framework::dataType::MIN_VERSION} = $mintext;
	$itemResult->{'data'}->{$framework::dataType::MAX_VERSION} = $maxtext;
	$itemResult->{'data'}->{$framework::dataType::MATCHED_PATTERN} = $pattern;
	$itemResult->{'data'}->{$framework::dataType::ENVIRONMENT} = $env;
	$itemResult->{'data'}->{$framework::dataType::EXPORTABLE} = $searchItem->[$framework::dataType::IDX_EXPORTABLE];
	$itemResult->{'data'}->{$framework::dataType::STATUS} = $framework::dataType::STATUS_DISCOVERED;
	
	framework::Logs::Debug("--> detection of framework ".$searchItem->[$framework::dataType::IDX_NAME]."\n");
	
	return $itemResult;
}

sub detect($$) {
	my $globalDetections = shift;
	my $DB = shift;
	
	%H_detections = ();
	
	my $combinationsItems = $DB->{'combination'}->{'PATTERNS'};
	
	for my $item (keys %{$combinationsItems}) {
		my $searchItem = $combinationsItems->{$item};
		my $expression = $searchItem->[$framework::dataType::IDX_PATTERNS]->[0];
		
		my %expr_items = ();
		while ($expression =~ /([\w#]+)/g) {
			$expr_items{$1} = framework::detections::isDetected($1);
		}
		
		my $expandedExpression = $expression;
		for my $exprItem (keys %expr_items) {
			$expandedExpression =~ s/$exprItem/$expr_items{$exprItem}/g;
		}
		
		my $detected = eval($expandedExpression);
		
		if ($@) {
			framework::Logs::Warning("problem when evaluating combination expression : \n\t$expression\n\texpanded to : $expandedExpression\n\teval message : ($@)\n");
		}
		
		if ($detected) {
			framework::Logs::Debug("combination $expression is ok : $item detected ...\n");
			my $itemDetection = createItemDetection($searchItem, $expression, undef, 'combination');
			framework::detections::addItemDetection(\%H_detections, $itemDetection);
		}
	}
	
	return \%H_detections;
}

1;
