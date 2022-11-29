package CloudReady::CountPHP;

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


sub oneStringContains($$) {
	my $HString = shift;
	my $REG = shift;
	
	for my $stringId (keys %$HString) 
    {
		if ($HString->{$stringId} =~ /$REG/) 
        {
            return 1;
		}
	}
	return 0;
}

sub checkPatternInStrings($$) {
	my $HString = shift;
	my $REG = shift;
	my $detect = 0;
	for my $stringId (keys %$HString)
	{
		if ($HString->{$stringId} =~ /$REG/)
		{
			$detect++;
		}
	}
	return $detect;
}

sub checkDBMSMySQL($$){
	my $code = shift;
	my $HString = shift;
	my $nb_DBMSMySQL = 0;

	# HL-597
	if ($$code =~ /\b(?:mysql_connect|mysqli|mysqli_connect)\s*\(/) {
        $nb_DBMSMySQL = 1;
	}
    
    if (oneStringContains($HString, qr/\bmysql:host\b/)) {
        $nb_DBMSMySQL = 1;
    }
	# HL-954
	while($$code =~ /\bgetenv\s*\(\s*(CHAINE_\d+)/g)
	{ 
		if ($HString->{$1} =~ /["'](?:MYSQL_DSN|MYSQL_USER|MYSQL_PASSWORD)["']/g)
		{
			$nb_DBMSMySQL++;
		}
	}
    
	return $nb_DBMSMySQL;

}

sub checkMongoDB
{
	my $code = shift;
	my $nb_DBMSMongoDB = 0;

	if ($$code =~ /\bnew\s+MongoClient\s*\(/) {
        $nb_DBMSMongoDB = 1;
	}
        
	return $nb_DBMSMongoDB;

}


sub checkCosmosDB
{
	my $code = shift;
	my $HString = shift;
	my $nb_DBMSCosmosDB = 0;

	if ($$code =~ /\bnew\s+DocumentDB\b/) {

        if (oneStringContains($HString, qr/\bphpdocumentdb\.php\b/)) {
            $nb_DBMSCosmosDB = 1;
        }
    }
    
	return $nb_DBMSCosmosDB;
}

sub checkDynamoDB
{
	my $code = shift;
	my $nb_DBMSDynamoDB = 0;

	if ($$code =~ /\bDynamoDbClient\b/) {
        $nb_DBMSDynamoDB = 1;
	}
        
	return $nb_DBMSDynamoDB;

}

sub checkPostgreSQL($$)
{
	my $code = shift;
	my $HString = shift;
	my $nb_DBMSPostgreSQL = 0;

	if ($$code =~ /\bpg_connect\s*\(/) {
        $nb_DBMSPostgreSQL = 1;
	}

	# HL-955
	while($$code =~ /\bgetenv\s*\(\s*(CHAINE_\d+)/g)
	{ 
		if ($HString->{$1} =~ /["'](?:POSTGRES_DSN|POSTGRES_USER|POSTGRES_PASSWORD)["']/g)
		{
			$nb_DBMSPostgreSQL = 1;
		}
	}

	return $nb_DBMSPostgreSQL;

}

sub checkAmazonawsServicesKms
{
	my $code = shift;
	my $nb_AmazonawsServicesKms = 0;

	if ($$code =~ /\bKmsClient\b/) {
        $nb_AmazonawsServicesKms = 1;
	}
        
	return $nb_AmazonawsServicesKms;

}

sub checkAzureBlobStorage($) 
{

	my $code = shift;
	my $nb_AzureBlobStorage = 0;

	if ($$code =~ /\buse\s+MicrosoftAzure(?:\\|\/)Storage\b/) {
        $nb_AzureBlobStorage = 1;
	}
        
	return $nb_AzureBlobStorage;

}

sub checkAmazonawsS3Storage($) 
{

	my $code = shift;
	my $nb_AmazonawsS3Storage = 0;

	if ($$code =~ /\b(?:use\s+Aws(?:\\|\/)S3|S3Client)\b/) {
        $nb_AmazonawsS3Storage = 1;
	}
        
	return $nb_AmazonawsS3Storage;

}

sub checkInMemoryRedisAzure($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_InMemoryRedisAzure = 0;
        
    if ($$code =~ /\bnew\s+Redis\b/g) 
    {
        $nb_InMemoryRedisAzure = 1;
    }
    
    
	return $nb_InMemoryRedisAzure;

}

sub checkInMemoryRedisAws($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_InMemoryRedisAws = 0;
    pos($$code) = undef;

    if ($$code =~ /\bElastiCacheClient\b/g) {
        $nb_InMemoryRedisAws = 1;
	}    

    
	return $nb_InMemoryRedisAws;

}

sub checkAzureDirectoryService($) 
{
	my $code = shift;
	# my $HString = shift;
	my $nb_AzureDirectoryService = 0;
    pos($$code) = undef;

    if ($$code =~ /\bGraphServiceAccessHelper\b/g) 
    {
        $nb_AzureDirectoryService = 1;
    }
    
	return $nb_AzureDirectoryService;

}

sub checkAwsDirectoryService($) 
{
	my $code = shift;
	# my $HString = shift;
	my $nb_AwsDirectoryService = 0;
    pos($$code) = undef;

    if ($$code =~ /\bconnectDirectory\b/g) {
        $nb_AwsDirectoryService = 1;
	}    
    
	return $nb_AwsDirectoryService;

}

sub checkAmazonawsBatch($) 
{
	my $code = shift;
	# my $HString = shift;
	my $nb_AwsDirectoryService = 0;
    pos($$code) = undef;

    if ($$code =~ /\bBatchClient|namespace\s+Aws\\Batch\b/g) {
        $nb_AwsDirectoryService = 1;
	}    
    
	return $nb_AwsDirectoryService;

}

sub checkAzureServiceBusMessaging($) 
{
	my $code = shift;
	# my $HString = shift;
	my $nb_AzureServiceBusMessaging = 0;
    pos($$code) = undef;

    if ($$code =~ /\bnamespace\s+WindowsAzure\\ServiceBus\b|\bServicesBuilder\b/g) 
    {
        $nb_AzureServiceBusMessaging = 1;
    }
        
	return $nb_AzureServiceBusMessaging;

}

sub checkAmazonAwsAccessManagement($) 
{
	my $code = shift;
	# my $HString = shift;
	my $nb_AmazonAwsAccessManagement = 0;
    pos($$code) = undef;

    if ($$code =~ /\bIamClient\b/g) 
    {
        $nb_AmazonAwsAccessManagement = 1;
    }
        
	return $nb_AmazonAwsAccessManagement;

}


sub CountPHP($$$) {
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

	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedIP(), CloudReady::lib::HardCodedIP::checkHardCodedIP($HString, $code, $techno, $text));
    # HL-576 Launching subprocess
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_LaunchSubProcess(), $checkPattern->(qr/\bproc_open\s*\(|\bpopen\s*\(|\bsystem\s*\(|\bexec\s*\(/, $code));
	# HL-579 Perform Directory Manipulation 
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCreateDirectory(), $checkPattern->(qr/\bmkdir\s*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryMove(), $checkPattern->(qr/\brename\s*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryDelete(), $checkPattern->(qr/\brmdir\s*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryExists(), $checkPattern->(qr/\b(?:scandir|readdir|is_dir)\s*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCurrent(), $checkPattern->(qr/\bgetcwd\s*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryChange(), $checkPattern->(qr/\bchdir\s*\(/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryAccess(), $checkPattern->(qr/\b(?:chmod|chown)\s*\(/, $code));
    # HL-583 Perform File Manipulation PHP
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Open(), $checkPattern->(qr/\b(?:fopen|file)\s*\(/, $code));    
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Write(), $checkPattern->(qr/\b(?:fwrite|fputs)\s*\(/, $code));    
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileExists(), $checkPattern->(qr/\bfile_exists\s*\(/, $code));    
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileMove(), $checkPattern->(qr/\brename\s*\(/, $code));    
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileDelete(), $checkPattern->(qr/\bunlink\s*\(/, $code));    
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCopy(), $checkPattern->(qr/\bcopy\s*\(/, $code));  
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_FileInputStream(), $checkPattern->(qr/\b(?:fgetc|fgets|fgetss|fgetcsv|readfile|tempnam|tmpfile)\s*\(/, $code));  
    # HL-586 Access to environment variable from PHP
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_EnvironmentVariable(), $checkPattern->(qr/(?:\$_ENV\b|\$HTTP_ENV_VARS\b|\bgetenv\s*\()/, $code));    
	# HL-593 PHP & Python (HardCodedPath)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedPath(), CloudReady::lib::HardCodedPath::checkHardCodedPath($HString, $techno, $code, $text));
    # HL-597 MySQL PHP & Python
	# HL-954 08/10/2019 [GCP Boosters] Using MySQL database
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MySQL, checkDBMSMySQL($code, $HString));
    # HL-598 MongoDB PHP & Python
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MongoDB, checkMongoDB($code));
    # HL-599 NoSQL CosmosDB Azure Python
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_CosmosDB, checkCosmosDB($code, $HString));
    # HL-600 NoSQL DynamoDB AWS PHP & Python
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_DynamoDB, checkDynamoDB($code));
    # HL-601 NoSQL PostgreSQL PHP & Python
	# HL-955 10/10/2019 [GCP Boosters] Using PostgreSQL database	
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_PostgreSQL, checkPostgreSQL($code, $HString));
    #HL-608 BUG Fix HL-247 unsecured URL without XML namespace context
	#HL-870 21/05/2019 Split FTP/HTTP CloudReady pattern in 2 separate patterns
	CloudReady::lib::URINotSecured::checkURINotSecured($fichier, $code, $HString, $techno, $text);
    #HL-615 MySQL database access deprecated PHP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBAccessMySQL(), $checkPattern->(qr/\b(?:mysql_connect|mysql_select_db|mysql_close)\s*\(/, $code)); 
    #HL-630 KMS service encryption AWS PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsServicesKms(), checkAmazonawsServicesKms($code));
    #HL-634 Azure blob storage PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage(), checkAzureBlobStorage($code)); 
    #HL-636 AWS S3 storage PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsS3Storage(), checkAmazonawsS3Storage($code)); 
    #HL-640 Azure elasticache PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_InMemoryRedisAzure(), checkInMemoryRedisAzure($code, $HString)); 
    #HL-641 AWS elasticache PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_InMemoryRedisAws(), checkInMemoryRedisAws($code, $HString)); 
    #HL-646 Azure Active Directory access permission PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureDirectoryService(), checkAzureDirectoryService($code)); 
    #HL-647 AWS Active Directory access permission PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsDirectoryService(), checkAwsDirectoryService($code)); 
    #HL-651 Detect Usage of AWS Batch PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsBatch(), checkAmazonawsBatch($code)); 
    #HL-654 Azure service bus messaging PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureServiceBusMessaging(), checkAzureServiceBusMessaging($code)); 
    #HL-659 AWS Cloud Identity and Access Management PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonAwsAccessManagement(), checkAmazonAwsAccessManagement($code)); 
	# HL-952 17/09/2019 [GCP Boosters] Using Kubernetes
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingKubernetes(), $checkPattern->(qr/\bnew\s+KubernetesClient\b|\buse\s+(?:[\w\\]+)?\bKubernetes(?:Runtime)?\b/, $code)); 
	# HL-953 07/10/2019 [GCP Boosters] Using BigQuery
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigQuery(), $checkPattern->(qr/\bnew\s+BigQueryClient\b|\buse\s+(?:[\w\\]+)?\bGoogle[\\]Cloud[\\]BigQuery\b/, $code)); 
	# HL-957 10/10/2019 [GCP Boosters] Using a Cloud-Based Storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudDataStore(), $checkPattern->(qr/\buse\s+(?:[\w\\]+)?\bGoogle[\\]Cloud[\\]Datastore\b/, $code)); 
	# HL-958 11/10/2019 [GCP Boosters] Using BigTable
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigTable(), $checkPattern->(qr/\buse\s+(?:[\w\\]+)?\bGoogle[\\]Cloud[\\]Bigtable\b/, $code)); 
	# HL-959 15/10/2019 [GCP Boosters] Using Cloud Spanner
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudSpanner(), $checkPattern->(qr/\buse\s+(?:[\w\\]+)?\bGoogle[\\]Cloud[\\]Spanner\b/, $code)); 
	# HL-960 16/10/2019 [GCP Boosters] Using Cloud in-memory database (redis)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Using_InMemoryRedisGCP(), $checkPattern->(qr/\bnew\s+CloudRedisClient\b|\buse\s+(?:[\w\\]+)?\bGoogle[\\]Cloud[\\]Redis\b/, $code)); 
	# HL-961 17/10/2019 [GCP Boosters] Using Cloud IAM (Identity and Access Management)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudIAM(), $checkPattern->(qr/\bnew\s+Iam\b|\buse\s+(?:[\w\\]+)?\bGoogle[\\]Cloud[\\]Core[\\]Iam\b/, $code)); 
	# HL-962 18/10/2019 [GCP Boosters] Using Firebase
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingFireBase(), $checkPattern->(qr/\buse\s+(?:[\w\\]+)?\bKreait[\\]Firebase\b/, $code)); 
	# HL-963 28/10/2019 [GCP Boosters] Using Cloud IAP (Identity Aware Proxy)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudIAP(), $checkPattern->(qr/\bnamespace\s+Google[\\]Cloud[\\]Samples[\\]Iap\b|\bfunction\s+make_iap_request\b/, $code)); 
	# HL-964 28/10/2019 [GCP Boosters] Using a Cloud-based Key storage (KMS)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPServicesKms(), $checkPattern->(qr/\bnew\s+Google_Service_CloudKMS\b/, $code)); 
	# HL-965 28/10/2019 [GCP Boosters] Using a Cloud-Based Storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPStorage(), $checkPattern->(qr/\bnew\s+StorageClient\b|\buse\s+(?:[\w\\]+)?\bGoogle[\\]Cloud[\\]Storage\b/, $code)); 
	# HL-966 29/10/2019 [GCP Boosters] Using a Cloud-based task scheduling service
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPScheduler(), $checkPattern->(qr/\bnew\s+Google_Service_CloudScheduler\b/, $code)); 
	# HL-968 30/10/2019 [GCP Boosters] Using a Cloud-based middleware application
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudPubSub(), $checkPattern->(qr/\buse\s+(?:[\w\\]+)?\bGoogle[\\]Cloud[\\]PubSub\b|\bnew\s+PubSubClient\b/, $code)); 
	# 25/11/2021 [Blocker] servlet PHP (like java blocker HttpSession_setAttribute)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_ServletPHP(), $checkPattern->(qr/\bsession_start\s*\(\)/, $code));
	# 14/01/2022 [Blocker] Azure Database Driver incompatibility PDO_DBLIB
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DbDriverDbLib(), checkPatternInStrings($HString, qr/\bdblib\s*\:/));
	# 14/01/2022 [Blocker] can't use sendmail utility on Paas
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_SendMail(), $checkPattern->(qr/\bmail\s*\(/, $code));
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
