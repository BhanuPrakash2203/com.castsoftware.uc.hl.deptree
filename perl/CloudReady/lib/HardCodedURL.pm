package CloudReady::lib::HardCodedURL;

use strict;
use warnings;
use CloudReady::detection;


sub checkHardCodedURL($$$$$) {
	my $fichier = shift;
	my $code = shift;
	my $HString = shift;
	my $techno = shift;
	my $text = shift;
	my $nb_hardcoded_HTTP = 0;
	my $regexpr_url;

	my $rulesDescription = CloudReady::lib::ElaborateLog::keepPortalData();

	# for all technos
	my $exceptionPatterns = [ qr/(?:\bQName\b|\b\w*namespaces?\b|\b(xml)?ns\b)/i ];

	if (defined $techno && $techno eq "VB") {
		$regexpr_url = qr/^https?\:\/\//im;
	}
	else {
		$regexpr_url = qr/^["']https?\:\/\//im;
	}

	for my $stringId (keys %$HString) {
		if ($HString->{$stringId} =~ /$regexpr_url/) {
			my $res = checkExceptionsURL($HString->{$stringId}, $exceptionPatterns);
			if ($res == 0) {
				$nb_hardcoded_HTTP++;
				my $urlPattern = $HString->{$stringId};
				$urlPattern = quotemeta($urlPattern);
				CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $urlPattern, CloudReady::Ident::Alias_HTTPProtocol, $rulesDescription);
			}
		}
	}

	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HTTPProtocol(), $nb_hardcoded_HTTP);
}

sub checkExceptionsURL($$) {
	my $url = shift;
	my $exceptionPatterns = shift;

	foreach my $exceptionPattern (@$exceptionPatterns) {
		if ($url =~ /$exceptionPattern/m) {
			return 1;
		}
	}

	return 0;
}

sub checkHardCodedURLProtocol($$$$$) {
	my $fichier = shift;
	my $code = shift;
	my $HString = shift;
	my $kindProto = shift;
	my $text = shift;
	my $nb_URL_Protocol = 0;
	my $regexpr_url;
	if ($kindProto eq 'FTP') {
		$regexpr_url = qr/\bs?ftps?\:(?:\/\/)\b/i;
	}
	elsif ($kindProto eq 'LDAP') {
		$regexpr_url = qr/\bldaps?\:(?:\/\/)\b/i;
	}

	my $rulesDescription = CloudReady::lib::ElaborateLog::keepPortalData();

	for my $stringId (keys %$HString) {
		if ($HString->{$stringId} =~ /$regexpr_url/) {
			$nb_URL_Protocol++;
			my $urlPattern = $HString->{$stringId};
			$urlPattern = quotemeta($urlPattern);
			if ($kindProto eq 'FTP') {
				CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $urlPattern, CloudReady::Ident::Alias_FTPProtocol, $rulesDescription);
			}
			elsif ($kindProto eq 'LDAP') {
				CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $urlPattern, CloudReady::Ident::Alias_LDAPProtocol, $rulesDescription);
			}
		}
	}

	if ($kindProto eq 'FTP') {
		CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FTPProtocol(), $nb_URL_Protocol);
	}
	elsif ($kindProto eq 'LDAP') {
		CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_LDAPProtocol(), $nb_URL_Protocol);
	}
}

1;
