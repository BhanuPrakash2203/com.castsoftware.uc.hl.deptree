package CloudReady::CountCCpp;

use strict;
use warnings;

use Erreurs;
use CloudReady::detection;
use CloudReady::config;
use CloudReady::Ident;
use CloudReady::lib::HardCodedIP;
use CloudReady::lib::HardCodedPath;
use CloudReady::lib::HardCodedURL;
use CloudReady::lib::URINotSecured;
use CloudReady::lib::ElaborateLog;
use CloudReady::lib::SensitiveDataString;

use constant BEGINNING_MATCH => 0;
use constant FULL_MATCH => 1;

my $rulesDescription;
my $aggloView;
my $binaryView;

sub checkPatternSensitive($$$) {
	my $reg = shift;
	my $code = shift;
	my $mnemo = shift;

	return CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $reg, $mnemo, $rulesDescription);
	# return () = ($$code =~ /$reg/gm);
}

sub checkSQLDatabaseUnsecureAuthentication($$$$) {
	my $regexConnectionString = shift;
	my $text = shift;
	my $HString = shift;
	my $mnemo = shift;

	my $nb_SQLSQLDatabaseUnsecureAuthentication = 0;

	if (defined $regexConnectionString) {
		for my $stringId (keys %$HString) {
			if ($HString->{$stringId} =~ /$regexConnectionString/) {
				# if Trusted_Connection or Integrated Security have other value than yes, true or sspi => detection
				if ($HString->{$stringId} !~ /\b(?:Trusted_Connection|Integrated\s+Security)\b\s*\=\s*\'?(?:yes|true|sspi)\'?/i) {
					$nb_SQLSQLDatabaseUnsecureAuthentication++;
					my $string = quotemeta($HString->{$stringId});
					my $regex = qr/$string/;
					CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, $mnemo, $rulesDescription);
				}
			}
		}
	}

	return $nb_SQLSQLDatabaseUnsecureAuthentication;
}

sub CountCCpp($$$) {
	my ($fichier, $vue, $compteurs, $techno) = @_;
	my $ret = 0;

	my $code;
	my $HString;
	my $MixBloc;
	my $text;
	$text = \$vue->{'text'};
	$aggloView = $vue->{'agglo'};
	$binaryView = $vue->{'bin'};
	my $code_with_prepro = \$vue->{'code_with_prepro'};

	my $checkPattern = \&checkPatternSensitive;

	$code = \$vue->{'code'};
	$HString = $vue->{'HString'};
	$MixBloc = \$vue->{'MixBloc'};

	$rulesDescription = CloudReady::lib::ElaborateLog::keepPortalData();

	if ((!defined $code) || (!defined $$code)) {
		#$ret |= Couples::counter_add($compteurs, $MissingJSPComment__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	# HL-1912 05/01/2022 Detect the usage of environment variables
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_EnvironmentVariable(), $checkPattern->(qr/\b(?:secure\_)?getenv\b/, $code, CloudReady::Ident::Alias_EnvironmentVariable));
	# HL-1913 05/01/2022 Avoid using unsecured database connection strings
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_SQLDatabaseUnsecureAuthentication(), checkSQLDatabaseUnsecureAuthentication(qr/\b(?:Trusted_Connection|Integrated\s+Security)\b/, $text, $HString, CloudReady::Ident::Alias_SQLDatabaseUnsecureAuthentication));
	# HL-1914 05/01/2022 Detect the usage of local directory manipulation
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryDelete(), $checkPattern->(qr/\bremove(?:\_all)?\s*\(/, $code, CloudReady::Ident::Alias_DirectoryDelete));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryExists(), $checkPattern->(qr/\bis\_directory\s*\(/, $code, CloudReady::Ident::Alias_DirectoryExists));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCreate(), $checkPattern->(qr/\bcreate_director(?:y|ies)\s*\(/, $code, CloudReady::Ident::Alias_DirectoryCreate));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GetTempPath(), $checkPattern->(qr/\btemp\_directory\_path\s*\(/, $code, CloudReady::Ident::Alias_GetTempPath));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCurrent(), $checkPattern->(qr/\b(?:getcwd|current\_path|get\_current\_dir\_name|directory\_iterator)\s*\(/, $code, CloudReady::Ident::Alias_DirectoryCurrent));
	# HL-1915 06/01/2022 Detect the usage of local files manipulation
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Open(), $checkPattern->(qr/\bf?open\s*\(/, $code, CloudReady::Ident::Alias_Open));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileExists(), $checkPattern->(qr/\b(?:exists|is\_regular\_file)\s*\(/, $code, CloudReady::Ident::Alias_FileExists));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCopy(), $checkPattern->(qr/\bcopy\s*\(/, $code, CloudReady::Ident::Alias_FileCopy));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_FileInputStream(), $checkPattern->(qr/\b(?:getline|FileInputStream)\s*\(/, $code, CloudReady::Ident::Alias_New_FileInputStream));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileRead(), $checkPattern->(qr/\bread\s*\(/, $code, CloudReady::Ident::Alias_FileRead));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileDelete(), $checkPattern->(qr/\bremove\s*\(/, $code, CloudReady::Ident::Alias_FileDelete));
	# HL-1916 06/01/2022 Using Access Control List
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_AccessControlList(), $checkPattern->(qr/\b(?:SetNamedSecurityInfo|GetExplicitEntriesFromAcl)\s*\(/, $code, CloudReady::Ident::Alias_New_AccessControlList));
	# HL-1917 06/01/2022 Using EventLog
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_EventLog(), $checkPattern->(qr/\b(?:ReportEvent|RegisterEventSource)\s*\(|\bEventLog\b/, $code, CloudReady::Ident::Alias_New_EventLog));
	# HL-1918 07/01/2022 Detect the usage of hardcoded path
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedPath(), CloudReady::lib::HardCodedPath::checkHardCodedPath($HString, $techno, $code, $text));
	# HL-1919 07/01/2022 Detect the usage of hardcoded IP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedIP(), CloudReady::lib::HardCodedIP::checkHardCodedIP($HString, $code, $techno, $text));
	# HL-1920 07/01/2022 Using impersonate Identity
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_IdentityImpersonateTrue(), $checkPattern->(qr/\bImpersonateLoggedOnUser\b/, $code, CloudReady::Ident::Alias_IdentityImpersonateTrue));
	# HL-1921 07/01/2022 Detect the usage of unsecured URI
	CloudReady::lib::URINotSecured::checkURINotSecured($fichier, $code, $HString, $techno, $text);
	# HL-1922 10/01/2022 Using connection strings for database connection
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedConnectionString(), $checkPattern->(qr/\bConnectionString\b|\bSQLDriverConnect\w*\s*\(/, $code, CloudReady::Ident::Alias_HardCodedConnectionString));
	# HL-1923 10/01/2022 Using dynamic libraries (dll, so...)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DllImport(), $checkPattern->(qr/\b(?:\_\_declspec\s*\(\s*dll(?:imp|exp)ort\s*\)|LoadLibrary\s*\(|dlopen\s*\()/, $code_with_prepro, CloudReady::Ident::Alias_DllImport));
	# Use_Unsecured_Data_Strings
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_SensitiveDataString(), CloudReady::lib::SensitiveDataString::CountSensitiveDataString($code, $HString, $techno));
	# Use_SecuredProtocolsHTTP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HTTPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURL($fichier, $code, $HString, $techno, $text));
	# Use_SecuredProtocolsFTP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FTPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURLProtocol($fichier, $code, $HString, 'FTP', $text));
	# Use_LDAPProtocol
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_LDAPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURLProtocol($fichier, $code, $HString, 'LDAP', $text));

	my $parameters = AnalyseUtil::recuperer_options();
	my $dbgMatchPatternDetail = $parameters->[0]->{'--dbgMatchPatternDetail'};
	if (defined $dbgMatchPatternDetail) {
		# replacing SHA by filenames in log
		CloudReady::lib::ElaborateLog::ElaborateLogPartTwo($code, $text, $fichier);
	}
	return $ret;
}

sub getBinaryView {
	return \$binaryView;
}

sub getAggloView {
	return \$aggloView;
}
1;
