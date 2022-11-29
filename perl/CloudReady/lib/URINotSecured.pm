package CloudReady::lib::URINotSecured;

use strict;
use warnings;
use CloudReady::detection;
use CloudReady::lib::HardCodedURL;

# exceptions for all technos
my $domain_exclusion = qr/\b(?:www\.w3\.org)\b/;
my $exceptionPatternsInURL = [ qr/\b(?:xml)?ns\b/i ];
my $exceptionPatterns = [ qr/(?:\bQName\b|\b\w*namespaces?\b|\b(?:xml)?ns\b)/i];

sub checkURINotSecured($$$$$) {
	my $fichier = shift;
	my $code = shift;
	my $HString = shift;
	my $techno = shift;
	my $text = shift;
	# my $nb_hardcoded_URI = 0;
	my $nb_hardcoded_URI_HTTP = 0;
	my $nb_hardcoded_URI_FTP = 0;
	my $regexpr_uri;

	my $rulesDescription = CloudReady::lib::ElaborateLog::keepPortalData();

	# exceptions for specific technos
	push(@$exceptionPatterns, qr/\b(?:Action|ReplyAction)\b\s*\=\s*/i) if (defined $techno && $techno eq "CS");

	if (defined $techno and $techno eq "VB") {
		$regexpr_uri = qr/^((http|ftp)\:(\/\/))(?!$domain_exclusion)/im;
	}
	else {
		$regexpr_uri = qr/^["']((http|ftp)\:(\/\/))(?!$domain_exclusion)/im;
	}

	for my $stringId (keys %$HString) {
		if ($HString->{$stringId} =~ /$regexpr_uri/) {
			my $prefixURI = $2;
			($nb_hardcoded_URI_HTTP, $nb_hardcoded_URI_FTP) = checkContextDetectionURI($code, $text, $exceptionPatterns, $HString, $stringId, $prefixURI, $nb_hardcoded_URI_HTTP, $nb_hardcoded_URI_FTP, $rulesDescription);
		}
	}

	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_URINotSecuredHTTP(), $nb_hardcoded_URI_HTTP);
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_URINotSecuredFTP(), $nb_hardcoded_URI_FTP);

	# Counter not necessary for analyzer, mnemonic is splitted in 2 patterns HTTP & FTP
	# return $nb_hardcoded_URI;
}

sub checkContextDetectionURI ($$$$$$$$$) {
	my $code = shift;
	my $text = shift;
	my $exceptionPatterns = shift;
	my $HString = shift;
	my $stringId = shift;
	my $prefixURI = shift;
	my $nb_hardcoded_URI_HTTP = shift;
	my $nb_hardcoded_URI_FTP = shift;
	my $rulesDescription = shift;

	my $string = quotemeta($HString->{$stringId});
	my $regex = qr/$string/;
	while ($$code =~ /^(.*)\b$stringId\b/mg) {
		if (defined $1) {
			my $previousPattern = $1;
			my $result = checkExceptionsUri($previousPattern, $exceptionPatterns);
			if ($result == 0) {
				if (defined($prefixURI) and lc($prefixURI) eq "http") {
					my $res = CloudReady::lib::HardCodedURL::checkExceptionsURL($string, $exceptionPatternsInURL);
					if ($res == 0) {
						$nb_hardcoded_URI_HTTP++;
						# display Alias_URINotSecured in log
						CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, CloudReady::Ident::Alias_URINotSecured, $rulesDescription);
					}
				}
				else {
					$nb_hardcoded_URI_FTP++;
					# display Alias_URINotSecured in log
					CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, CloudReady::Ident::Alias_URINotSecured, $rulesDescription);
				}
				# print 'detection of unsecured URI ' . $HString->{$stringId} ."\n";
			}
		}
	}
	return ($nb_hardcoded_URI_HTTP, $nb_hardcoded_URI_FTP);
}

sub checkExceptionsUri($$) {
	my $previousPattern = shift;
	my $exceptionPatterns = shift;

	foreach my $exceptionPattern (@$exceptionPatterns) {
		if ($previousPattern =~ /$exceptionPattern/m) {
			return 1;
		}
	}

	return 0;
}

1;
