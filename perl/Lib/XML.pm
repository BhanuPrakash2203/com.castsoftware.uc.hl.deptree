package Lib::XML;

use strict;
use warnings;

use XML::LibXML;

sub load_xml($) {
	my $file = shift;
	
	my $XmlContent;
	eval {
		$XmlContent = XML::LibXML->load_xml(location => $file);
	};
	if ( $@ ) {
		my $msg = $@;
		$msg =~ s/\n$//m;
		my ($package, $filename, $line) = caller;
		print "[Lib::XML:".__LINE__."] cannot load $file ($msg) from $package:$filename:$line\n";
		 
		return undef;
	}
	
	return $XmlContent;
}


sub parsePredicat($) {
	my $xpath = shift;
	my $predicat = "";
	
	while ($$xpath =~ /\G(\]|[^\]]+)/gc) {
		$predicat .= $1;
		
		if ($1 eq "]") {
			return $predicat;
		}
	}
}

sub parseNodeName($) {
	my $xpath = shift;
	if ($$xpath =~ /\G([^\/\[]*)/gc) {
		return $1;
	}
	
	return "";
}

sub findnodes($$) {
	my $dom = shift;
	my $xpath = shift;
	my $new_xpath = "";
	
	if (! defined $dom) {
		return ();
	}
	
	while ($xpath =~ /\G(\/\/|\/|\[|[^\/\[]+)/gc) {
		if ($1 eq "//") {
			my $nodeName = parseNodeName(\$xpath);
			$new_xpath .= qq{//*[local-name()="$nodeName"]};
		
		}
		elsif ($1 eq "/") {
			my $nodeName = parseNodeName(\$xpath);
			$new_xpath .= qq{/*[local-name()="$nodeName"]};
		}
		elsif ($1 eq "[") {
			
			$new_xpath .= "[" . parsePredicat(\$xpath);
		}
		else {
			$new_xpath .= $1;
		}
	}
#print "$xpath ------> $new_xpath\n";
	return $dom->findnodes($new_xpath);
}

sub getChildren($) {
	my $node = shift;

	# Don't care about namespace (search based on local name)
	return $node->getChildrenByLocalName('*');
}

sub getAttribute($$) {
	my $node = shift;
	my $attr = shift;

	# Don't care about namespace (search based on local name)
	return $node->findvalue("./\@$attr");
}

# match regexp on the value of the given attribute of a node.
sub findnodes_AttrMatch($$$$) {
	my $dom = shift;
	my $xpath = shift;
	my $attr = shift;
	my $reg = shift;
	
	my @results = ();
	
	foreach my $node (findnodes($dom, $xpath)) {
		my $attrValue = $node->findvalue("./\@".$attr);
		if ($attrValue =~ $reg) {
			push @results, $node;
		}
	}
	return @results;
}

1;
