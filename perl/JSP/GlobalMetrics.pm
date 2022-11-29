package JSP::GlobalMetrics;

use strict;
use warnings;
use AnalyseOptions;

sub getAppli($$) {
	my $fichier = shift;
	my $global_context = shift;
#print "ASKING APPLI for file : $fichier\n";
    $fichier =~ s/\A\.[\\\/]//;
	if (defined $global_context) {
#print "OK, global context is defined !!!!!!!\n";
		for my $appli (@$global_context) {
			my $appli_path = quotemeta $appli->[0];
#print "AVAILABLE APPLI PATH : $appli_path\n";
			if ($fichier =~ /\A$appli_path/) {
#print "--> APPLI FOUND for this path!!!!\n";
				return $appli;
			}
		}
	}
	return undef;
}

sub checkSecured($) {
	my $buf = shift;
	my $isSecured = 0;
	while ($$buf =~ /<security-constraint>(.*)<\/security-constraint>/sg) {
		my $SecurityConstraint = $1;
		
		if ($SecurityConstraint =~ /<auth-constraint>/) {
			if ($SecurityConstraint =~ /<web-resource-collection>(.*)<\/web-resource-collection>/s) {
				my $WebResourceCollection = $1;
				if ($WebResourceCollection =~ /<url-pattern>/) {
					return 1;
				}
			}
		}
	}
	return 0;
}

sub analyseWebXml($$$) {
	my $file = shift;
	my $srcDir = shift;
	my $counters = shift;
	
	# $srcDir contains the option --dir-source if any !!!
	my $filename = $file;
	if ((defined $srcDir) && ($srcDir ne "")) {
		$filename = "$srcDir/$file";
	}
	
	my $ret = open WEBXML, "<$filename";
	
	if (!$ret) {
		print STDERR "[WARNING] unable to open file $filename ($!). Web application counters will not be available.\n";
		#FIXME : manage status (and use an ERROR lib !!)
		return 1;
	}

	local $/ = undef;
	my $buf = <WEBXML>;
	close WEBXML;
	
	if ($buf =~ /<error-page>/s) {
		$counters->{'WebXmlErrorPage'} = 1;
	}
	else {
		$counters->{'WebXmlErrorPage'} = 0;
	}
	
	# check if web appli is secured
	$counters->{'WebXmlIsSecured'} = checkSecured(\$buf);
	
}

sub checkTldLocation($$) {
	my $file = shift;
	my $appli = shift;
	
	$appli->[1]->{'BadTldLocation'} = 0;
#print "CHECKING TLD LOCATION for $file\n";
	if ($file !~ /[\\\/]WEB-INF[\\\/]/m ) {
#print "===> Bad location !!!\n";
		$appli->[1]->{'BadTldLocation'} = 1;
	}
}

sub checkTldContent($$) {
	my $buf = shift;
	my $appli = shift;
	
	$appli->[1]->{'BadTldContent'} = 0;
	
	if ($$buf =~/<\?xml\b([^>]+)\?>/i) {
		my $xmlTag = $1;
		if (($xmlTag !~ /\bversion\s*=/) || ($xmlTag !~ /\bencoding\s*=/)) {
			$appli->[1]->{'BadTldContent'} = 1;
#print "===> Bad content (missing version or encoding) !!!\n";
		}
	}
	else {
		$appli->[1]->{'BadTldContent'} = 1;
#print "===> Bad content (missing <?xml> tag) !!!\n";
	}
	if ($$buf =~ /<!DOCTYPE\b([^>]+)>/) {
		my $DOCTYPE_tag = $1;
		if ($DOCTYPE_tag !~ /\bDTD\b/) {
			$appli->[1]->{'BadTldContent'} = 1;
#print "===> Bad content (missing DTD in DOCTYPE) !!!\n";
		}
	}
	else {
		$appli->[1]->{'BadTldContent'} = 1;
#print "===> Bad content (missing DOCTYPE tag) !!!\n";
	}
}

sub analyseTld($$$) {
	my $file = shift;
	my $srcDir = shift;
	my $applis = shift;
	
	my $appli = getAppli($file, $applis);
		
	if (defined $appli) {

		# $srcDir contains the option --dir-source if any !!!
		my $filename = $file;
		if ((defined $srcDir) && ($srcDir ne "")) {
			$filename = "$srcDir/$file";
		}
		checkTldLocation($file, $appli);
	
		my $ret = open TLD, "<$filename";
	
		if (!$ret) {
			print STDERR "[WARNING] unable to open file $filename. Counters related to tld will not be available.\n";
			#FIXME : manage status (and use an ERROR lib !!)
			return 1;
		}
			
		local $/ = undef;
		my $buf = <TLD>;
		close TLD;
	
		checkTldContent(\$buf, $appli);
	}
}

sub compute($$) {
	my $fileList = shift;
	my $options = shift;
	
	my $srcDir = AnalyseOptions::GetSourceDirectory($options);
	
	my $status = 0;
	my @applis = ();
	my @tld = ();

	for my $file (@$fileList) {
		if ($file =~ /\bweb\.xml$/im) {
			if ($file =~ /(.*)\bWEB-INF[\\\/]web\.xml$/im) {
#print "Found a JSP appli in $1\n";
				my %metaCounters = ();
				my $path = $1;
				$path =~ s/\A\.[\\\/]//;
				push @applis, [$path, \%metaCounters ];
				$status |= analyseWebXml($file, $srcDir, \%metaCounters);
		
				# remove the web.xml (it should not be analyzed with JSP Analyzer) !!!
				$file = undef;
			}
			else {
				print "[WARING] file $file is not recognized as a JSP configuration file (not situated in a WEB-INF subdirectory)";
				$file = undef;
			}
		}
		elsif ($file =~ /\.tld$/im){
			# the file will be treated later
			push @tld, $file;
			# remove *.tld files (they should not be analyzed with JSP Analyzer) !!!
		    $file = undef;
		}
	}
	
	for my $file (@tld) {
		analyseTld($file, $srcDir, \@applis);
	}
	
	@$fileList = grep defined, @$fileList;
	#FIXME : manage status
	return \@applis;
}

1;
