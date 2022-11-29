package CloudReady::CountScala;

use strict;
use warnings;

use Erreurs;
use CloudReady::detection;
use CloudReady::config;
use CloudReady::Ident;
use CloudReady::lib::HardCodedIP;
use CloudReady::lib::HardCodedPath;
use CloudReady::lib::URINotSecured;
use CloudReady::lib::SensitiveDataString;
use CloudReady::lib::ElaborateLog;

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

sub checkStringContent($$$$) {
	my $HString = shift;
	my $pattern = shift;
	my $text = shift;
	my $mnemo = shift;

	my $nb_string_content = 0;

	for my $stringId (keys %$HString) {
		if ($HString->{$stringId} =~ /$pattern/) {
			$nb_string_content++;
			my $string = quotemeta($HString->{$stringId});
			my $regex = qr/$string/;
			CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, $mnemo, $rulesDescription);
		}
	}
	return $nb_string_content;
}

sub CountScala($$$) {
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

	# HL-2060 08/06/2022 Access_To_Environment_Variable
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_EnvironmentVariable(), $checkPattern->(qr/\b(?:System\.getenv\s*\(|sys\.env\b|System\.getProperties\s*\()/, $code, CloudReady::Ident::Alias_EnvironmentVariable));
	# HL-2081 08/06/2022 Avoid_Code_Skipped
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_CodeSkipped(), $checkPattern->(qr/\bassert\b/, $code, CloudReady::Ident::Alias_CodeSkipped));
	# HL-2059 08/06/2022 Directory_Manipulation_Practice
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCopy(), $checkPattern->(qr/\.copyDirectory\b/, $code, CloudReady::Ident::Alias_DirectoryCopy));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_IsDirectory(), $checkPattern->(qr/\.isDirectory\b/, $code, CloudReady::Ident::Alias_IsDirectory));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCreate(), $checkPattern->(qr/\bmkdirs?\b/, $code, CloudReady::Ident::Alias_DirectoryCreate));
	# HL-2058 09/06/2022 File_Manipulation_Practice
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileRead(), $checkPattern->(qr/\b(?:Source\.fromFile\s*\(|\.getLines\b)/, $code, CloudReady::Ident::Alias_FileRead));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Write(), $checkPattern->(qr/\b(?:PrintWriter|BufferedWriter|FileWriter)\s*\(/, $code, CloudReady::Ident::Alias_Write));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileMove(), $checkPattern->(qr/\bFiles\.move\s*\(|\bStandardCopyOption\b/, $code, CloudReady::Ident::Alias_FileMove));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_FileInputStream(), $checkPattern->(qr/\b(?:FileInputStream|FileOutputStream)\b/, $code, CloudReady::Ident::Alias_New_FileInputStream));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCreate(), $checkPattern->(qr/\bFile\s*\(/, $code, CloudReady::Ident::Alias_FileCreate));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileExists(), $checkPattern->(qr/\b(?:\.isFile|listFiles)\b/, $code, CloudReady::Ident::Alias_FileExists));
	# HL-2057 09/06/2022 Launch_Sub_Processes
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_LaunchSubProcess(), $checkPattern->(qr/\b(?:import\s+scala\.sys\.process\.Process\b|Process\s*\()/, $code, CloudReady::Ident::Alias_LaunchSubProcess));
	# HL-2082 09/06/2022 Use_Access_Control
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_AccessControlList(), $checkPattern->(qr/\bimport\s+de\.ceow\.security\.acl\b/, $code, CloudReady::Ident::Alias_New_AccessControlList));
	# HL-2062 09/06/2022 Use_File_System
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedPath(), CloudReady::lib::HardCodedPath::checkHardCodedPath($HString, $techno, $code, $text));
	# HL-2083 09/06/2022 Use_FTPProtocol
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FTPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURLProtocol($fichier, $code, $HString, 'FTP', $text));
	# HL-2064 09/06/2022 Use_GetTempPath
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GetTempPath(), $checkPattern->(qr/\.(?:createTempDirectory|createTempFile)\b/, $code, CloudReady::Ident::Alias_GetTempPath));
	# HL-2061 09/06/2022 Use_Hardcoded_IP_Address
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedIP(), CloudReady::lib::HardCodedIP::checkHardCodedIP($HString, $code, $techno, $text));
	# HL-2084 09/06/2022 Use_HTTPProtocol
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HTTPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURL($fichier, $code, $HString, $techno, $text));
	# HL-2085 16/06/2022 Use_LDAPProtocol
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_LDAPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURLProtocol($fichier, $code, $HString, 'LDAP', $text));
	# HL-2063 16/06/2022 Use_SecuredProtocols
	CloudReady::lib::URINotSecured::checkURINotSecured($fichier, $code, $HString, $techno, $text);
	# HL-2086 16/06/2022 Use_Unsecured_Data_Strings
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_SensitiveDataString(), CloudReady::lib::SensitiveDataString::CountSensitiveDataString($code, $HString, $techno));
	# HL-2087 16/06/2022 Use_BigQuery_GCP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigQuery(), $checkPattern->(qr/\bimport\s+com\.google\.cloud\.spark\.bigquery\b|\bspark\.read\.bigquery\s*\(/, $code, CloudReady::Ident::Alias_UsingBigQuery));
	# HL-2072 16/06/2022 Use_BigTable_GCP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigTable(), $checkPattern->(qr/\bimport\s+com\.google\.cloud\.bigtable\b|\bBigtableDataClient\b/, $code, CloudReady::Ident::Alias_UsingBigTable));
	# HL-2088 16/06/2022 Use_CloudIAM
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudIAM, $checkPattern->('\bimport\s+software\.amazon\.awssdk\.services\.iam\b|\bIamClient\b', $code, CloudReady::Ident::Alias_UsingCloudIAM));
	# HL-2089 17/06/2022 Use_CloudDataStore_GCP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudDataStore, $checkPattern->('\bimport\s+io\.applicative\.datastore\b|\bDatastoreService\b', $code, CloudReady::Ident::Alias_UsingCloudDataStore));
	# HL-2090 17/06/2022 Use_CloudSpanner_GCP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudSpanner, $checkPattern->('\bimport\s+com\.google\.cloud\.spanner\b|\bSpanner\b', $code, CloudReady::Ident::Alias_UsingCloudSpanner));
	# HL-2073 17/06/2022 Use_FireBase_GCP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingFireBase, $checkPattern->('\b(?:import\s+(?:com\.google\.firebase|com\.firebase4s)|FirebaseApp\.initializeApp|new\s+FirebaseOptions\.Builder\b|(?:FirebaseAuth|FirebaseDatabase)\.getInstance)\b', $code, CloudReady::Ident::Alias_UsingFireBase));
	# HL-2068 17/06/2022 Use_GCPScheduler_GCP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPScheduler, $checkPattern->('\bimport\s+(?:com\.google\.cloud\.scheduler|com\.google\.api.services\.cloudscheduler)\b', $code, CloudReady::Ident::Alias_GCPScheduler));
	# HL-2067 17/06/2022 Use_GCPStorage_GCP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPStorage, $checkPattern->('\bimport\s+com\.google\.cloud\.storage\b', $code, CloudReady::Ident::Alias_GCPStorage));
	# HL-2091 17/06/2022 Use_InMemoryRedis
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_InMemoryRedis, $checkPattern->('\b(?:import\s+(?:com\.redis|dev\.profunktor\.redis4cats|scredis)|RedisClient|Redis)\b', $code, CloudReady::Ident::Alias_InMemoryRedis));
	# HL-2092 17/06/2022 Use_Kubernetes
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Kubernetes, $checkPattern->('\b(?:import\s+(?:skuber|com\.goyeau\.kubernetes)|k8sInit|KubernetesClient)\b', $code, CloudReady::Ident::Alias_Kubernetes));
	# HL-2093 17/06/2022 Use_UsingCloudPubSub_GCP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudPubSub, $checkPattern->('\b(?:GooglePubSub|PubSubConfig)\b', $code, CloudReady::Ident::Alias_UsingCloudPubSub));
	# HL-2094 17/06/2022 Use_Cloud_KeyVault
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureKeyVault, $checkPattern->('\b(?:import\s+com\.microsoft\.azure\.keyvault|KeyVaultClient)\b', $code, CloudReady::Ident::Alias_MicrosoftAzureKeyVault));
	# HL-2095 17/06/2022 Use_Cloud_Service_Bus
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureServiceBusMessaging, $checkPattern->('\b(?:import\s+bluebus\.client\.ServiceBusClient|ServiceBusClient|SBusConfig)\b', $code, CloudReady::Ident::Alias_AzureServiceBusMessaging));
	# HL-2066 17/06/2022 Use_Cloud_Storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsS3Storage, $checkPattern->('(?:\bimport\s+(?:com.amazonaws\.services\.s3|awscala\.s3)\b|\bAmazonS3Client\b|\bS3\s*\(|\.createBucket\s*\()', $code, CloudReady::Ident::Alias_AmazonawsS3Storage));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage, $checkPattern->('\bimport\s+com\.microsoft\.azure\.storage\b|\bBlob\s*\(|\bBlobServiceClientBuilder\b|\bAzureContainerClient\b|\bAzureBlobClient\b|\.storeBlob\b', $code, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage));
	# HL-2071 20/06/2022 Use_MongoDB_Database
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MongoDB, $checkPattern->('\bimport\s+(?:com|org)\.mongodb\b|\bMongoClient\b', $code, CloudReady::Ident::Alias_DBMS_MongoDB));
	# HL-2078 20/06/2022 Use_MySQL_Database
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MySQL, checkStringContent($HString, '\bcom\.mysql\.jdbc\.Driver\b|\bjdbc\:mysql\b', $text, CloudReady::Ident::Alias_DBMS_MySQL));
	# HL-2077 20/06/2022 Use_PostgreSQL_Database
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_PostgreSQL, checkStringContent($HString, '\borg\.postgresql\.Driver\b|\bjdbc\:postgresql\b', $text, CloudReady::Ident::Alias_DBMS_PostgreSQL));
	# HL-2096 20/06/2022 Use_FaaS
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsLambda, $checkPattern->('\bimport\s+com\.amazonaws\.services\.lambda\b', $code, CloudReady::Ident::Alias_AwsLambda));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureFunctions, $checkPattern->('\bimport\s+com\.microsoft\.azure\.functions\b', $code, CloudReady::Ident::Alias_AzureFunctions));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPFunctions, $checkPattern->('\bimport\s+com\.google\.cloud\.functions\b', $code, CloudReady::Ident::Alias_GCPFunctions));
	# HL-2070 20/06/2022 Use_NoSQL_Storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_DynamoDB, $checkPattern->('\bimport\s+(?:com\.amazonaws\.services\.dynamodbv2|awscala\.dynamodbv2)\b|\bAmazonDynamoDBClient\b|\bDynamoDB\s*\(|\bLocalDynamoDB\.client\b', $code, CloudReady::Ident::Alias_DBMS_DynamoDB));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_CosmosDB, $checkPattern->('\bimport\s+com\.microsoft\.azure\.documentdb\b', $code, CloudReady::Ident::Alias_DBMS_CosmosDB));
	# HL-2097 21/06/2022 Use_Docker
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Docker, $checkPattern->('\bimport\s+(?:com\.spotify\.docker|com\.whisk\.docker)\b|\bDockerClient\b', $code, CloudReady::Ident::Alias_Docker));

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
