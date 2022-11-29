package JSP::Scope;

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;

use constant SCOPE_DATA_VALUE => 0;
use constant SCOPE_DATA_SCOPE => 1;

use constant ScopeKind => 'scope';


my $emptyData = undef;

sub enterNewScope($) {
	my $parent = shift;
	my $node = Node(ScopeKind, Lib::Node::createEmptyStringRef());
	Append($parent, $node);
	# [idents, conds]
	Lib::NodeUtil::SetKindData($node, []);
	return $node;
}

sub leaveScope($) {
	my $scope = shift;
	my $parent = GetParent($scope);
	return $parent;
}

sub addScopeData($$$) {
	my $scope = shift;
	my $data  = shift;
	my $kind  = shift;
	
	# add data with a link to the parent ...
	my $element = [$data, $scope];
	my $scopeData = Lib::NodeUtil::GetKindData($scope);
	
	if (! defined $scopeData->[$kind]) {
		$scopeData->[$kind] = [];
	}
	push @{$scopeData->[$kind]}, $element;
	return $element;
}

sub getData($$) {
	my $scope = shift;
	my $kind = shift;
	return Lib::NodeUtil::GetKindData($scope)->[$kind];
}

sub getDataScope($) {
	my $data = shift;
	return $data->[SCOPE_DATA_SCOPE];
}

sub getDataValue($) {
	my $data = shift;
	return $data->[SCOPE_DATA_VALUE];
}

1;
