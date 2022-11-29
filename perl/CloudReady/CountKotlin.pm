package CloudReady::CountKotlin;

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

sub checkDBMSPostGreSQL($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_DBMS = 0;
    pos($$code) = undef;

    for my $stringId (keys %$HString) {
        if ($HString->{$stringId} =~ /\bjdbc\:(?:postgresql|pgsql)\b|\borg\.postgresql\.Driver\b/im) {
			$nb_DBMS++;
        }
    }

	while ($$code =~ /\bimport\s+(?:org\.jetbrains\.exposed\.sql\.vendors\.PostgreSQLDialect)\b.*|[^.]\b(?:PostgreSQLDialect)\b[\w.]*/g) {
		$nb_DBMS++;
	}

	return $nb_DBMS;
}

sub checkDBMSMySQL($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_DBMS = 0;
    pos($$code) = undef;

    for my $stringId (keys %$HString) {
        if ($HString->{$stringId} =~ /\bjdbc\:mysql\b|\bcom\.mysql\.cj\.jdbc\.Driver\b/im) {
			$nb_DBMS++;
        }
    }

	while ($$code =~ /\bimport\s+(?:org\.jetbrains\.exposed\.sql\.vendors\.(?i)MysqlDialect)\b.*|[^.]\b(?i)(?:MysqlDialect)\b[\w.]*/g) {
		$nb_DBMS++;
	}

	return $nb_DBMS;
}

sub checkDBMSOracle($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_DBMS = 0;
    pos($$code) = undef;

    for my $stringId (keys %$HString) {
        if ($HString->{$stringId} =~ /\bjdbc\:oracle\b|\boracle\.jdbc\.OracleDriver\b/im) {
			$nb_DBMS++;
        }
    }

	while ($$code =~ /\bimport\s+(?:org\.jetbrains\.exposed\.sql\.vendors\.OracleDialect)\b.*|[^.]\b(?:OracleDialect)\b[\w.]*/g) {
		$nb_DBMS++;
	}

	return $nb_DBMS;
}

sub checkDBMSSQLServer($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_DBMS = 0;
    pos($$code) = undef;

    for my $stringId (keys %$HString) {
        if ($HString->{$stringId} =~ /\bjdbc\:sqlserver\b|\bcom\.microsoft\.sqlserver\.jdbc\.SQLServerDriver\b/im) {
			$nb_DBMS++;
        }
    }

	while ($$code =~ /\bimport\s+(?:org\.jetbrains\.exposed\.sql\.vendors\.SQLServerDialect)\b.*|[^.]\b(?:SQLServerDialect)\b[\w.]*/g) {
		$nb_DBMS++;
	}

	return $nb_DBMS;
}

sub checkJDBCStringConnection($$) 
{
	my $HString = shift;
	my $patternJDBC = shift;
	my $nb_patternJDBC = 0;

    for my $stringId (keys %$HString) {
        if ($HString->{$stringId} =~ /\b$patternJDBC\b/i) {
			$nb_patternJDBC++;
        }
    }

	return $nb_patternJDBC;
}

sub CountKotlin($$$) {
	my ($fichier, $vue, $compteurs, $techno) = @_ ;
	my $ret = 0;
	
	my $code;
	my $HString;
    my $MixBloc;
	my $text;
	$text = \$vue->{'text'};
	my $checkPattern = \&checkPatternSensitive;
	
	$code = \$vue->{'code'};
	$HString = $vue->{'HString'};
    $MixBloc = \$vue->{'MixBloc'};
    
	if ((! defined $code ) || (!defined $$code)) {
		#$ret |= Couples::counter_add($compteurs, $MissingJSPComment__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	# HL-1463 16/10/2020 Detect the usage of a cloud-based Data Warehouse
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Using_AmazonRedshift(), checkJDBCStringConnection($HString, "jdbc\:redshift\:\/\/"));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsAthena(), $checkPattern->(qr/(?i)\bimport\s+com\.robinkanters\.athena\b.*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigQuery(), $checkPattern->(qr/\bimport\s+(?:com\.google\.api\.services\.bigquery|org\.apache\.beam\.sdk\.io\.gcp.)\b.*|(?i)\bBigqueryClient\b[\w.(]/, $code));
	# HL-1464 19/10/2020 Detect the usage of a cloud-based storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsS3Storage(), $checkPattern->(qr/\bimport\s+(?:com\.amazonaws\.services\.s3|software\.amazon\.awssdk\.services\.s3)\b.*|[^.]\b(?:AmazonS3|AmazonS3ClientBuilder|S3AsyncClient|S3AsyncClientBuilder|AmazonS3Client|initAmazonS3Client)\b[\w.]*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage(), $checkPattern->(qr/\bimport\s+com\.microsoft\.azure\.storage\b.*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPStorage(), $checkPattern->(qr/\bimport\s+com\.google\.cloud\.storage\b.*/, $code));
	# HL-1465 19/10/2020 Detect the usage of a cloud-based search engine
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Elasticsearch(), $checkPattern->(qr/\bimport\s+org\.elasticsearch\b.*/, $code));
	# HL-1467 19/10/2020 Detect the usage of a cloud-based function as a service (serverless)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsLambda(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.lambda\b.*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureFunctions(), $checkPattern->(qr/\bimport\s+com\.microsoft\.azure\.functions\b.*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPFunctions(), $checkPattern->(qr/\bimport\s+com\.google\.cloud\.functions\b.*/, $code));
	# HL-1468 19/10/2020 Detect the usage of a cloud-based NoSQL database storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_DynamoDB(), $checkPattern->(qr/\bimport\s+(?:com\.ximedes\.dynamodb|software\.amazon\.awssdk\.services\.dynamodb|com\.johnturkson\.awstools\.dynamodb)\b.*|[^.]\b(?:DynamoDbAsyncClient|DynamoDbAsyncClientBuilder)\b[\w.]*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MongoDB(), $checkPattern->(qr/\bimport\s+com\.mongodb\b.*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_CosmosDB(), $checkPattern->(qr/\bimport\s+com\.microsoft\.azure\.documentdb\b.*|[^.]\b(?:Cosmos|CosmosDatabase)\b[\w.]*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingFireBase(), $checkPattern->(qr/\bimport\s+(?:com\.microsoft\.azure\.documentdb|com.google.cloud.firestore|com.google.firebase)\b.*|[^.]\b(?:Cosmos|CosmosDatabase|FirestoreOptions|FirebaseStorage)\b[\w.]*/, $code));
	# HL-1469 19/10/2020 Detect the usage of cloud-based relational database storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_PostgreSQL(), checkDBMSPostGreSQL($code, $HString));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MySQL(), checkDBMSMySQL($code, $HString));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_Oracle(), checkDBMSOracle($code, $HString));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_SQLServer(), checkDBMSSQLServer($code, $HString));
	# HL-1470 19/10/2020 Detect the usage of in-memory database storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_InMemoryRedis(), $checkPattern->(qr/\bimport\s+(?:redis\.clients\.jedis|org\.springframework\.data\.redis)\b.*|[^.]\b(?:RedisTemplate|RedisObject)\b[\w.]*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_InMemoryMemcached(), $checkPattern->(qr/\bimport\s+io\.sixhours\.memcached\b.*/, $code));
	# HL-1471 19/10/2020 Detect the usage of a cloud-based Identity and Access Management (IAM)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsCloudIAM(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.identitymanagement\b.*|[^.]\bAmazonIdentityManagementClientBuilder\b[\w.]*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureDirectoryService(), $checkPattern->(qr/\bimport\s+com\.microsoft\.identity\b/, $code));
	# HL-1472 19/10/2020 Detect the usage of a cloud-based key service encryption
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsServicesKms(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.kms\b.*|[^.]\bAWSKMSClientBuilder\b[\w.]*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureKeyVault(), $checkPattern->(qr/\bimport\s+com\.microsoft\.azure\.keyvault\b.*|[^.]\bKeyVaultClient\b[\w.]*/, $code));
	# HL-1473 19/10/2020 Detect the usage of a cloud-based container service
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsElasticContainer(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.ec2\b.*|[^.]\b(?:AmazonEC2|AmazonEC2Async)\b[\w.]*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Docker(), $checkPattern->(qr/\bimport\s+.*\.docker\b[\w.]*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Kubernetes(), $checkPattern->(qr/\bimport\s+.*\.(?:kubernetes|k8s)\b[\w.]*/, $code));
	# HL-1474 20/10/2020 Detect the usage of a cloud-based middleware application
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Using_AmazonSQS(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.sqs\b[\w.]*|[^.]\bAmazonSQSClientBuilder\b[\w.]*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudPubSub(), $checkPattern->(qr/\bimport\s+com\.google(?:\.api\.services|\.cloud)?\.pubsub\b[\w.]*|[^.](?i)\bPubSubMessage\b[\w.\(]/, $code));
	# HL-1475 20/10/2020 Detect the usage of a cloud-based Big Data technology
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsEMRBigData(), $checkPattern->(qr/\bimport\s+software\.amazon\.awssdk\.services\.emr\b[\w.]*|[^.]\b(?:EmrClient|EmrAsyncClient)\b[\w.]*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Hadoop(), $checkPattern->(qr/\bimport\s+(?:org\.apache\.hadoop|com\.google\.cloud\.hadoop)\b[\w.]*|[^.]\bHadoopJarStepConfig\b[\w.]*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Spark(), $checkPattern->(qr/\bimport\s+(?:org\.apache|common)\.spark\b[\w.]*|[^.]\b(?:JavaSparkContext|SparkConf)\b[\w.]*/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Kafka(), $checkPattern->(qr/\bimport\s+org\.apache\.kafka\b[\w.]*|[^.]\b(?:KafkaConsumer|KafkaServer|KafkaConfig)\b[\w.]*/, $code));
	# HL-1476 20/10/2020 Detect the usage of JSON to facilitate interactions with cloud services
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_JSONParsing(), $checkPattern->(qr/\bimport\s+com\.fasterxml\.jackson\.(?:core|databind(?:\.node)?)\.Json[\w.]*|[^.]\b(?:JsonNode|JsonObject|JsonParser)\b[\w.]*/, $code));
	# HL-1476 20/10/2020 Detect the usage of XML to facilitate interactions with cloud services
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_XMLParsing(), $checkPattern->(qr/\bimport\s+(?:com\.fasterxml\.jackson\.dataformat\.xml|org\.xml|javax\.xml)\b[\w.]*|[^.]\b(?:XmlMapper|XmlPullParser)\b[\w.]*|\.parseXml\b/, $code));
	# HL-1478 20/10/2020 Detect the usage of a cloud-based blockchain technology
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Blockchain(), $checkPattern->(qr/\bimport\s+(?:net\.corda|org\.kethereum|pm\.gnosis\.ethereum|org\.hyperledger)\b[\w.]*|[^.]\b(?:CordaRPCClient|EthereumRPC|EthereumBlock)\b[\w.]*/, $code));
	# HL-1479 20/10/2020 Detect the usage of local files manipulation
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Open(), $checkPattern->(qr/\b(?:appendBytes|appendText)\b/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileRead(), $checkPattern->(qr/\b(?:bufferedReader|readLines|readText)\b/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Write(), $checkPattern->(qr/\b(?:bufferedWriter|writeText|writeBytes)\b/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCopy(), $checkPattern->(qr/\bcopyTo\b/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_FileInputStream(), $checkPattern->(qr/\b(?:inputStream|outputStream)\b/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCreate(), $checkPattern->(qr/\bcreateNewFile\b/, $code));
	# HL-1480 20/10/2020 Detect the usage of local directory manipulation
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCopy(), $checkPattern->(qr/\bcopyRecursively\b/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryDelete(), $checkPattern->(qr/\bdeleteRecursively\b/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryExists(), $checkPattern->(qr/\b(?:relativeTo|walk|walkBottomUp|walkTopDown)\b/, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCreate(), $checkPattern->(qr/\bmkdirs\b/, $code));
	# HL-1481 21/10/2020 Detect the usage of environment variables
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_EnvironmentVariable(), $checkPattern->(qr/\bSystem.getenv\b/, $code));
	# HL-1482 21/10/2020 Detect the usage of hardcoded IP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedIP(), CloudReady::lib::HardCodedIP::checkHardCodedIP($HString, $code, $techno, $text));
	# HL-1483 21/10/2020 Detect the usage of hardcoded path
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedPath(), CloudReady::lib::HardCodedPath::checkHardCodedPath($HString, $techno, $code, $text));
	# HL-1484 21/10/2020 Detect the usage of system calls or processes management
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_LaunchSubProcess(), $checkPattern->(qr/\bimport\s+java\.lang\.ProcessBuilder\b[\w.]*|[^.]\bProcessBuilder\b[\w.]*/, $code));
	# HL-1485 21/10/2020 Detect the usage of unsecured URI
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
