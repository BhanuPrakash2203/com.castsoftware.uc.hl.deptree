package CloudReady::lib::HardCodedPath;

use strict;
use warnings;
use CloudReady::lib::ElaborateLog;
use Lib::SHA;

sub checkHardCodedPath($$$$) {

	my $HString = shift;
	my $techno = shift;
	my $code = shift;
	my $text = shift;

	my $rulesDescription = CloudReady::lib::ElaborateLog::keepPortalData();

	my $nb_hardcoded_path = 0;
	my $regexpr_path;

	my $exceptionPatterns = undef;

	$exceptionPatterns = [ qr/\bnew\s+Regex\b/ ] if (defined $techno && $techno eq "CS");

	# searching absolute path not relative

	# Path format supported
	# WINDOWS
	#   c:/Users/jm/AppData/bar-foo.json
	#   Z:\Documents and Settings\frenzi\
	#   \\Server2\Share\Test\Foo.txt
	# ---
	# LINUX
	#   ref: http://www.linux-france.org/article/sys/fichiers/fichiers-2.html
	#   /bin | /boot | /dev | /etc | /home | /lib | /lib64 | /mnt | /opt | /proc | /root | /run | /bin | /srv | /sys | /tmp | /usr | /var
	#   /home/olivier_test/scripts
	#   /var/mysql/mysql.db

	$regexpr_path = qr/	# Windows OS
		(([a-z]\:|[\\])([\\\/]+[\w \.\-]+)+
		# Linux OS
		|[\/]
		(bin|boot|dev|etc|home|lib|lib64|mnt|opt|proc|root|run|bin|srv|sys|tmp|usr|var)\b
		# path ending for both OS
		([\\\/]+[\w \.\-]+)*)[\\\/]*
	/xim;

	if (defined $techno && $techno eq "VB") {
		$regexpr_path = qr/^$regexpr_path$/xim;
	}
	else {
		$regexpr_path = qr/^["']$regexpr_path["']$/xim;
	}

	for my $stringId (keys %$HString) {

		# managing file path format prefix : file:///
		$HString->{$stringId} =~ s/file\:[\/\\]+(?=[a-z]\:)//i; # windows format
		$HString->{$stringId} =~ s/file\:[\/\\]+/\//i;          # linux format
		if ($HString->{$stringId} =~ /($regexpr_path)/) {
			my $pattern = $1;
			if (defined $pattern && $pattern =~ /[a-z]{3,}/i && $pattern !~ /[*]/) {
				$nb_hardcoded_path = checkContextDetectionPath($code, $text, $exceptionPatterns, $HString, $stringId, $nb_hardcoded_path, $rulesDescription);
			}
		}
	}

	return $nb_hardcoded_path;
}

sub checkContextDetectionPath ($$$$$$$) {
	my $code = shift;
	my $text = shift;
	my $exceptionPatterns = shift;
	my $HString = shift;
	my $stringId = shift;
	my $nb_hardcoded_path = shift;
	my $rulesDescription = shift;

	my $string = quotemeta($HString->{$stringId});
	# strings quotes replaced by quotes & <> to combine search inside xml tag values
	$string =~ s/^\\["']/\["'<\]/m;
	$string =~ s/\\["']$/\["'>\]/m;
	my $regex = qr/$string/m;
	while ($$code =~ /^(.*)\b$stringId\b/mg) {
		if (defined $1) {
			my $previousPattern = $1;
			my $result = checkExceptionsPath($previousPattern, $exceptionPatterns, $stringId);
			if ($result == 0) {
				# to avoid duplicates counter must be computed in parallel of ElaborateLogPartOne
				$nb_hardcoded_path++;
				CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, CloudReady::Ident::Alias_HardCodedPath, $rulesDescription);
				# print 'PATH: ' . $HString->{$stringId} ."\n";
			}
		}
	}
	return $nb_hardcoded_path;
}

sub checkExceptionsPath($$$) {
	my $previousPattern = shift;
	my $exceptionPatterns = shift;
	my $stringId = shift;

	foreach my $exceptionPattern (@$exceptionPatterns) {
		if ($previousPattern =~ /$exceptionPattern/m) {
			return 1;
}
	}

	return 0;
}

1;
