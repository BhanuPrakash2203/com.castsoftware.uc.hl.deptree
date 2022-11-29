package CloudReady::CountSwift;

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
use CloudReady::lib::SensitiveDataString;

use constant BEGINNING_MATCH => 0;
use constant FULL_MATCH => 1;

sub checkPatternSensitive($$) {
	my $reg = shift;
	my $code = shift;
	
	return () = ($$code =~ /$reg/gm);
}

sub checkGCPStorage
{
	my $code = shift;
	my $nb_GCPStorage = 0;
    pos($$code) = undef;

	if ($$code =~ /\bimport\s+(?:Vapor|GoogleCloud)\b/) {
        if ($$code =~ /\bimport\s+(?:CloudStorage|Storage)\b/) {
			$nb_GCPStorage++;
		}
	}
	while ($$code =~ /\bstruct\s+GoogleCloudStorageAPI\b|\bGoogleCloudStorageAPI\b[\w.\s]*\(|\bGoogleCloudStorageClient\b/g) {
			$nb_GCPStorage++;
	}

	return $nb_GCPStorage;
}

sub checkMicrosoftAzureKeyVault($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_MicrosoftAzureKeyVault = 0;
    pos($$code) = undef;

    for my $stringId (keys %$HString) {
        if ($HString->{$stringId} =~ /\bMicrosoft\.Keyvault\b/im) {
			$nb_MicrosoftAzureKeyVault++;
        }
    }

	while ($$code =~ /\bstruct\s+Vaults\b|\bVaults\b[\w.\s]*\(/g) {
		$nb_MicrosoftAzureKeyVault++;
	}

	return $nb_MicrosoftAzureKeyVault;
}

sub checkAzureServiceBusMessaging($) 
{
	my $HString = shift;
	my $nb_AzureServiceBusMessaging = 0;

    for my $stringId (keys %$HString) {
        if ($HString->{$stringId} =~ /\bMicrosoft\.ServiceBus\b/im) {
			$nb_AzureServiceBusMessaging++;
        }
    }

	return $nb_AzureServiceBusMessaging;
}

sub checkAzureContainerRegistry($) 
{
	my $HString = shift;
	my $nb_AzureContainerRegistry = 0;

    for my $stringId (keys %$HString) {
        if ($HString->{$stringId} =~ /\bMicrosoft\.ContainerRegistry\b/im) {
			$nb_AzureContainerRegistry++;
        }
    }

	return $nb_AzureContainerRegistry;
}

sub checkAmazonawsBatch($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_AmazonawsBatch = 0;
    pos($$code) = undef;

	while ($$code =~ /AWSServiceConfig\b[\w.\s]*\((.*)\)/sg) {
		if (defined $1) {
			my $descriptor = $1;
			while ($descriptor =~ /(CHAINE_[0-9]+)/g)
			{
				if (defined $1) {
					my $stringId = $1;
					if (exists $HString->{$stringId} && lc($HString->{$stringId}) eq "\"batch\"") {
						$nb_AmazonawsBatch++;
					}
				}
			}
		}
	}
    while ($$code =~ /\bstruct\s+Batch\s*:\s*AWSService\b/ig) {
        $nb_AmazonawsBatch++;
    }

	return $nb_AmazonawsBatch;
}

sub checkAzureBatch($) 
{
	my $code = shift;
	# my $HString = shift;
	my $nb_AzureBatch = 0;
    pos($$code) = undef;

    while ($$code =~ /\bprotocol\s+BatchAccountProtocol\b|\bBatchAccountProtocol\b[\w.\s]*[\{\?]|\bstruct\s+JobSchedule\b|\bJobSchedule\b[\w.\s]*[\(\{]/g) 
    {
        $nb_AzureBatch++;
    }
        
	return $nb_AzureBatch;

}

sub CountSwift($$$) {
	my ($fichier, $vue, $compteurs, $techno) = @_ ;
	my $ret = 0;
	
	my $code;
	my $HString;
	my $text;
	$text = \$vue->{'text'};
    my $MixBloc;
	my $checkPattern = \&checkPatternSensitive;
	
	$code = \$vue->{'code'};
	$HString = $vue->{'HString'};
    $MixBloc = \$vue->{'MixBloc'};
    
	if ((! defined $code ) || (!defined $$code)) {
		#$ret |= Couples::counter_add($compteurs, $MissingJSPComment__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	# HL-1337 07/09/2020 Detect the usage of a cloud-based Data Warehouse
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsS3Storage(), $checkPattern->(qr/(?i)\b(?:struct|extension)\s+\bS3\b|\bS3\b[\w.\s]*\(/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage(), $checkPattern->(qr/(?i)\b(?:import\s+AzureStorageBlob\b|class\s+StorageBlobClient\b|StorageBlobClient\b[\w.\s]*\()/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPStorage(), checkGCPStorage($code));
	# HL-1339 08/09/2020 Detect the usage of a cloud-based Batch Job Orchestration
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsBatch(), checkAmazonawsBatch($code, $HString)); 
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureBatch(), checkAzureBatch($code)); 
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPScheduler(), $checkPattern->(qr/\bSwiftGoogleCloudTasksClient\b/, $code));
	# HL-1340 08/09/2020 Detect the usage of a cloud-based NoSQL database storage
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_DynamoDB, $checkPattern->(qr/\bimport\s+(?:DynamoDBClient|DynamoDBModel)\b|\bextension\s+DynamoDB\b|\bAWSDynamoDBClient\b[\w.\s]*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MongoDB, $checkPattern->(qr/\bimport\s+MongoSwift(?:Sync)?\b|\bMongoClient\b/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingFireBase, $checkPattern->(qr/\bimport\s+Firebase\b|\bFirebaseApp\b/, $code));
	# HL-1342 08/09/2020 Detect the usage of cloud-based relational database storage
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_PostgreSQL, $checkPattern->(qr/\bimport\s+(PerfectPostgreSQL|PostgreSQL|SwiftKueryPostgreSQL)\b|\bPostgreSQLConnection\b[\w.\s]*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MySQL, $checkPattern->(qr/\bimport\s+(PerfectMySQL|mysqlclient)\b|\bMySQL\b[\w.\s]*\(/, $code));
	# HL-1343 09/09/2020 Detect the usage of cloud-based cache in-memory database
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_InMemoryRedis, $checkPattern->(qr/\bimport\s+SwiftRedis\b|\bstruct\s+Redis\b|\bRedis\b[\w.\s]*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_InMemoryMemcached, $checkPattern->(qr/\bimport\s+(MemcachedSwift|libMemcachedLinux|libMemcachedMac)\b|\bMemcached\b[\w.\s]*\(|\bmemcached_create\b[\w.\s]*\(/, $code));
	# HL-1344 09/09/2020 Detect the usage of a cloud-based Identity and Access Management (IAM)
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsCloudIAM, $checkPattern->(qr/\bextension\s+IAM\b|\bIAM\b[\w.\s]*\(/, $code));
	# HL-1345 09/09/2020 Detect the usage of a cloud-based Active Directory service
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureDirectoryService, $checkPattern->(qr/\bimport\s+(?:ADAL|MSAL)\b/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsDirectoryService, $checkPattern->(qr/\b(?:struct|extension)\s+(?:DirectoryService|CloudDirectory)\b|\bDirectoryService\b[\w.\s]*\(|\bCloudDirectory\b[\w.\s]*\(/, $code));
	# HL-1346 09/09/2020 Detect the usage of a cloud-based key service encryption
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureKeyVault, checkMicrosoftAzureKeyVault($code, $HString)); 
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsServicesKms, $checkPattern->(qr/\bextension\s+KMS\b|\bKMS\b[\w.\s]*\(/, $code));
	# HL-1347 09/09/2020 Detect the usage of a cloud-based middleware application
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsDataPipeline, $checkPattern->(qr/\b(?:struct|extension)\s+(?:DataPipeline|CodePipeline)\b|\b(?:DataPipeline|CodePipeline)\b[\w.\s]*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzurePipeline, $checkPattern->(qr/\bclass\s+(?:Pipeline|PipelineClient)\b|\b(?:Pipeline|PipelineClient|PipelineRequest|PipelineResponse)\b[\w.\s]*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureServiceBusMessaging, checkAzureServiceBusMessaging($HString)); 
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudPubSub, $checkPattern->(qr/\bimport\s+GoogleCloudPubSub\b|\bGoogleCloudPubSub\b[\w.\s]*\(/, $code));
	# HL-1348 10/09/2020 Detect the usage of a cloud Container Registry
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Kubernetes, $checkPattern->(qr/\b(?:import|struct)\s+K8s\b|\bK8s\b[\w.\s]*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Docker, $checkPattern->(qr/\bimport\s+SwiftDockerLib\b|\b(?:protocol|extension)\s+(?:DockerCommand|DockerLabel)\b|\b(?:DockerCommand|DockerLabel)\b[\w.\s]*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureContainerRegistry, checkAzureContainerRegistry($HString)); 
	# HL-1349 10/09/2020 Detect the usage of a cloud-based Big Data technology
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsEMRBigData, $checkPattern->(qr/\bextension\s+EMR\b|\bEMR\b[\w.\s]*\(/, $code));
	# HL-1350 10/09/2020 Detect the usage of JSON to facilitate interactions with cloud services
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_JSONParsing, $checkPattern->(qr/\bclass\s+(?:JSONSerialization|JSONEncoder|JSONDecoder)\b|\b(?:JSONSerialization|JSONEncoder|JSONDecoder)\b[\w.\s]*\(/, $code));
	# HL-1351 10/09/2020 Detect the usage of XML to facilitate interactions with cloud services
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_XMLParsing, $checkPattern->(qr/\bclass\s+XMLParser\b|\bXMLParser\b[\w.\s]*\(/, $code));
	# HL-1352 10/09/2020 Detect the usage of a cloud-based blockchain technology
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Blockchain, $checkPattern->(qr/\bimport\s+SawtoothSigning\b|\bclass\s+Blockchain\b|\bBlockchain\b[\w.\s]*\(|\bstruct\s+Ethereum|\bEthereum[\w.\s]*\(/, $code));
	# HL-1353 11/09/2020 Detect the usage of local files manipulation
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Open, $checkPattern->(qr/\b(?:open|openFile|selectFile)\b[\w.\s]*\(|\bcontentsOfFile\b/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Write, $checkPattern->(qr/\bwrite\b[\w.\s]*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCopy, $checkPattern->(qr/\bcopyItemAtPath\s*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileExists, $checkPattern->(qr/\bfileExists\s*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCreate, $checkPattern->(qr/\bcreateFile\s*\(/, $code));
	# HL-1355 11/09/2020 Detect the usage of local directory manipulation
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCurrent, $checkPattern->(qr/\bcurrentDirectoryPath\b/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryOpen, $checkPattern->(qr/\b(?:contentsOfDirectory|subpathsOfDirectory)\s*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryChange, $checkPattern->(qr/\bchangeCurrentDirectoryPath\s*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCreate, $checkPattern->(qr/\bcreateDirectory\s*\(/, $code));
	# HL-1356 11/09/2020 Detect the usage of environment variables
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_EnvironmentVariable, $checkPattern->(qr/\b(NS)?ProcessInfo\.processInfo\(\)\.environment\b/, $code));
	# HL-1357 11/09/2020 Detect the usage of hardcoded IP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedIP(), CloudReady::lib::HardCodedIP::checkHardCodedIP($HString, $code, $techno, $text));
	# HL-1358 11/09/2020 Detect the usage of hardcoded path
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedPath(), CloudReady::lib::HardCodedPath::checkHardCodedPath($HString, $techno, $code, $text));
	# HL-1360 11/09/2020 Detect the usage of system calls or processes management
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_LaunchSubProcess, $checkPattern->(qr/\bimport\s+Subprocess\b|\b(Subprocess|Process|NSTask)\b[\w.\s]*\(/, $code));
	# HL-1361 11/09/2020 Detect the usage of unsecured URI
	CloudReady::lib::URINotSecured::checkURINotSecured($fichier, $code, $HString, $techno, $text);
	# Use_Unsecured_Data_Strings
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_SensitiveDataString(), CloudReady::lib::SensitiveDataString::CountSensitiveDataString($code, $HString, $techno));
	# Use_SecuredProtocolsHTTP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HTTPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURL($fichier, $code, $HString, $techno, $text));
	# Use_SecuredProtocolsFTP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FTPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURLProtocol($fichier, $code, $HString, 'FTP', $text));
	# Use_LDAPProtocol
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_LDAPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURLProtocol($fichier, $code, $HString, 'LDAP', $text));

	return $ret;
}

1;
