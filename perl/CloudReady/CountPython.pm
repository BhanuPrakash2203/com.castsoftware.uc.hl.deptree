package CloudReady::CountPython;

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

sub checkDBMSMySQL
{
	my $code = shift;
	my $nb_DBMSMySQL = 0;

	if ($$code =~ /\b(?:mysql\.connector\b|MySQLConnection\s*\(|MySQLdb\.connect\b)/) {
        $nb_DBMSMySQL = 1;
	}
        
	return $nb_DBMSMySQL;

}

sub checkMongoDB
{
	my $code = shift;
	my $nb_DBMSMongoDB = 0;

	if ($$code =~ /\b(?:pymongo\b|MongoClient)\b/) {
        $nb_DBMSMongoDB = 1;
	}
        
	return $nb_DBMSMongoDB;

}

sub checkCosmosDB
{
	my $code = shift;
	my $nb_DBMSCosmosDB = 0;

	if ($$code =~ /\bpydocumentdb\b/) {
        $nb_DBMSCosmosDB = 1;
	}
        
	return $nb_DBMSCosmosDB;

}

sub checkDynamoDB
{
	my $code = shift;
	my $HString = shift;
	my $nb_DBMSDynamoDB = 0;
        
    for my $stringId (keys %$HString) {
        if ($HString->{$stringId} =~ /^["']dynamodb["']/im) {
            
            while ($$code =~ /^(.*)\b$stringId\b/mg)
            {
                my $BeginLine = $1;
                if ($BeginLine =~ /\bboto3\.(?:client|resource)\b/i)
                {
                    $nb_DBMSDynamoDB = 1;
                }
                
            }
        }
    }    

	return $nb_DBMSDynamoDB;

}

sub checkPostgreSQL
{
	my $code = shift;
	my $nb_DBMSPostgreSQL = 0;

	if ($$code =~ /\b(?:psycopg2|pg8000)\b/) {
        $nb_DBMSPostgreSQL = 1;
	}
        
	return $nb_DBMSPostgreSQL;

}

sub checkAzureCloudEncryption
{
	my $code = shift;
	my $nb_AzureCloudEncryption = 0;

    if ($$code =~ /\b(?:KeyWrapper|KeyResolver)\s*\(/) {
        $nb_AzureCloudEncryption = 1;
    }
        
	return $nb_AzureCloudEncryption;

}

sub checkAmazonCloudEncryption
{
	my $code = shift;
	my $nb_AmazonCloudEncryption = 0;

    if ($$code =~ /\b(?:Crypto\.Cipher|import\s+AES|import\s+aws_encryption_sdk)\b/) {
        $nb_AmazonCloudEncryption = 1;
    }
        
	return $nb_AmazonCloudEncryption;

}

sub checkAzureKeyVault($) 
{

	my $code = shift;
	my $nb_AzureKeyVault = 0;

	if ($$code =~ /\b(?:azure\.keyvault|KeyVaultClient|KeyVaultId)\b/) {
        $nb_AzureKeyVault = 1;
	}
        
	return $nb_AzureKeyVault;

}

sub checkAzureBlobStorage($) 
{

	my $code = shift;
	my $nb_AzureBlobStorage = 0;

	if ($$code =~ /\b(?:azure\.storage|BlobService)\b/) {
        $nb_AzureBlobStorage = 1;
	}
        
	return $nb_AzureBlobStorage;

}

sub checkAmazonawsS3Storage($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_AmazonawsS3Storage = 0;
    
    for my $stringId (keys %$HString) {
        if ($HString->{$stringId} =~ /^["']s3["']/im) {
            
            while ($$code =~ /^(.*)\b$stringId\b/mg)
            {
                my $BeginLine = $1;
                if ($BeginLine =~ /\bboto3\.(?:client|resource)\b/i)
                {
                    $nb_AmazonawsS3Storage = 1;
                }
                
            }
        }
    }
    
	return $nb_AmazonawsS3Storage;

}

sub checkInMemoryRedisAzure($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_InMemoryRedisAzure = 0;
    pos($$code) = undef;

    if ($$code =~ /\bimport\s+redis\b/g) 
    {
        $nb_InMemoryRedisAzure = 1;
    }
    
    my $regexpr = qr/\bredis\.cache\.windows\.net\b/i;
	
    for my $stringId (keys %$HString) {
		if ($HString->{$stringId} =~ /$regexpr/) {
            $nb_InMemoryRedisAzure = 1;
            last;
		}
	}
    
	return $nb_InMemoryRedisAzure;

}

sub checkInMemoryRedisAws($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_InMemoryRedisAws = 0;
    pos($$code) = undef;

    for my $stringId (keys %$HString) 
    {
        if ($HString->{$stringId} =~ /^["']elasticache["']/m) 
        {
            while ($$code =~ /^(.*)\b$stringId\b/mg)
            {
                my $BeginLine = $1;

                if ($BeginLine =~ /\bboto3\.client\b/i)
                {
                    $nb_InMemoryRedisAws = 1;
                    last;
                }
                
            }
        }

        if ($HString->{$stringId} =~ /\bcache\.amazonaws\.com\b/) 
        {
            $nb_InMemoryRedisAws = 1;
            last;
        }
    }
    
	return $nb_InMemoryRedisAws;

}


sub checkAzureDirectoryService($) 
{
	my $code = shift;
	# my $HString = shift;
	my $nb_AzureDirectoryService = 0;
    pos($$code) = undef;

    if ($$code =~ /\badal\b/g) 
    {
        $nb_AzureDirectoryService = 1;
    }
        
	return $nb_AzureDirectoryService;

}

sub checkAwsDirectoryService($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_AwsDirectoryService = 0;
    pos($$code) = undef;

    for my $stringId (keys %$HString) 
    {
        if ($HString->{$stringId} =~ /^["']ds["']/m) 
        {
            while ($$code =~ /^(.*)\b$stringId\b/mg)
            {
                my $BeginLine = $1;

                if ($BeginLine =~ /\bboto3\.client\b/i)
                {
                    $nb_AwsDirectoryService = 1;
                    last;
                }
                
            }
        }

    }
    
	return $nb_AwsDirectoryService;

}

sub checkAmazonawsBatch($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_AmazonawsBatch = 0;
    pos($$code) = undef;

    for my $stringId (keys %$HString) 
    {
        if ($HString->{$stringId} =~ /^["']batch["']/m) 
        {
            while ($$code =~ /^(.*)\b$stringId\b/mg)
            {
                my $BeginLine = $1;

                if ($BeginLine =~ /\bboto3\.client\b/i)
                {
                    $nb_AmazonawsBatch = 1;
                    last;
                }
                
            }
        }

    }
    
	return $nb_AmazonawsBatch;

}

sub checkAzureBatch($) 
{
	my $code = shift;
	# my $HString = shift;
	my $nb_AzureBatch = 0;
    pos($$code) = undef;

    if ($$code =~ /\bimport\s+azure\.batch\b/g) 
    {
        $nb_AzureBatch = 1;
    }
        
	return $nb_AzureBatch;

}

sub checkAzureServiceBusMessaging($) 
{
	my $code = shift;
	# my $HString = shift;
	my $nb_AzureServiceBusMessaging = 0;
    pos($$code) = undef;

    if ($$code =~ /\bazure\.servicebus\b|\bServiceBusService\b/g) 
    {
        $nb_AzureServiceBusMessaging = 1;
    }
        
	return $nb_AzureServiceBusMessaging;

}

sub checkAzureAccessManagement($) 
{
	my $code = shift;
	# my $HString = shift;
	my $nb_AzureAccessManagement = 0;

    if ($$code =~ /\bazure\.mgmt\.authorization\b|\bAuthorizationManagementClient\b|\bazure\.common\.credentials\b|\bUserPassCredentials\b/g) 
    {
        $nb_AzureAccessManagement = 1;
    }
        
	return $nb_AzureAccessManagement;

}

sub checkAmazonAwsAccessManagement($$) 
{
	my $code = shift;
	my $HString = shift;
	my $nb_AmazonAwsAccessManagement = 0;
    pos($$code) = undef;

    for my $stringId (keys %$HString) 
    {
        if ($HString->{$stringId} =~ /^["']iam["']/m) 
        {
            while ($$code =~ /^(.*)\b$stringId\b/mg)
            {
                my $BeginLine = $1;

                if ($BeginLine =~ /\bboto3\.client\b/i)
                {
                    $nb_AmazonAwsAccessManagement = 1;
                    last;
                }
                
            }
        }

    }
        
	return $nb_AmazonAwsAccessManagement;
}

sub checkPatternInCodeAndString{
	my $code = shift;
	my $HString = shift;	
	my $PatternInCode= shift;
	my $PatternInString= shift;
	my $nb_detection =0;

    if (defined $PatternInCode)
    {
        while ($$code =~ /$PatternInCode(CHAINE_[0-9]+)/g)
        { 
            if ($HString->{$1} =~ /["']$PatternInString["']/)
            {
                $nb_detection++;
            }
        }
    }
	return $nb_detection;
}


sub CountPython($$$) {
	my ($fichier, $vue, $compteurs, $techno) = @_ ;
	my $ret = 0;
	
	my $code;
	my $HString;
    my $text;
    $text = \$vue->{'text'};
    my $MixBloc;
	my $checkPattern = \&checkPatternSensitive;
	
	$code = \$vue->{'code_with_prepro'};
	$HString = $vue->{'HString'};
    $MixBloc = \$vue->{'MixBloc'};
    
	if ((! defined $code ) || (!defined $$code)) {
		#$ret |= Couples::counter_add($compteurs, $MissingJSPComment__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedIP(), CloudReady::lib::HardCodedIP::checkHardCodedIP($HString, $code, $techno, $text));
	# HL-575 Launching subprocess
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_LaunchSubProcess(), $checkPattern->(qr/\bos\.(?:system|popen)\b|\bsubprocess\.(?:call|run|Popen)\b|\bshell\s*\=\s*True\b/, $code));
	# HL-578 Perform Directory Manipulation 
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCreateDirectory(), $checkPattern->(qr/\bos\.(?:mkdir|makedirs)\b/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryMove(), $checkPattern->(qr/\bos\.rename\b|\bshutil\.move\b/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryDelete(), $checkPattern->(qr/\bos\.(?:remove|removedirs|rmdir)\b|\bshutil\.rmtree\b/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryExists(), $checkPattern->(qr/\bos\.(?:listdir|is_dir|path\.isdir|path\.dirname|path\.exists)\b/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCurrent(), $checkPattern->(qr/\bos\.(?:getcwd|getcwdb|fchdir|chdir)\b/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryChange(), $checkPattern->(qr/\bos\.chdir\b/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryAccess(), $checkPattern->(qr/\bos\.(?:access|chmod|chown)\b/, $code));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCopy(), $checkPattern->(qr/\bshutil\.copytree\b/, $code));
    # HL-582 Perform File Manipulation Python
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Open(), $checkPattern->(qr/\bopen\s*\(/, $code));    
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Write(), $checkPattern->(qr/\bwrite\s*\(|\bwin32file\.WriteFile\b/, $code));    
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCreate(), $checkPattern->(qr/\bos\.mknod\b|\bwin32file\.CreateFile\b/, $code));    
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileMove(), $checkPattern->(qr/\bos\.rename\b|\bshutil\.move\b/, $code));    
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileDelete(), $checkPattern->(qr/\bos\.(?:remove|unlink)\b/, $code));    
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCopy(), $checkPattern->(qr/\bshutil\.(?:copy(?:file|2|fileobj)?)\b/, $code));  
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_FileInputStream(), $checkPattern->(qr/\bimport\s+(?:fileinput|tempfile)\b/, $code));  
    # HL-585 Access to environment variable from Python
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_EnvironmentVariable(), $checkPattern->(qr/\bos\.(?:environ|putenv|unsetenv|getenv)\b/, $code));    
	# HL-593 PHP & Python (HardCodedPath)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedPath(), CloudReady::lib::HardCodedPath::checkHardCodedPath($HString, $techno, $code, $text));
    # HL-597 MySQL PHP & Python
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MySQL, checkDBMSMySQL($code));
    # HL-598 MongoDB PHP & Python
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MongoDB, checkMongoDB($code));
    # HL-599 NoSQL CosmosDB Azure Python
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_CosmosDB, checkCosmosDB($code));
    # HL-600 NoSQL DynamoDB AWS PHP & Python
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_DynamoDB, checkDynamoDB($code, $HString));
    # HL-601 NoSQL PostgreSQL PHP & Python
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_PostgreSQL, checkPostgreSQL($code));
    # HL-605 Azure encryption Python
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureCloudEncryption, checkAzureCloudEncryption($code));
    # HL-606 AWS encryption Python
#    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonCloudEncryption, checkAmazonCloudEncryption($code));
    #HL-608 BUG Fix HL-247 unsecured URL without XML namespace context
	#HL-870 21/05/2019 Split FTP/HTTP CloudReady pattern in 2 separate patterns
	CloudReady::lib::URINotSecured::checkURINotSecured($fichier, $code, $HString, $techno, $text);
    #HL-629 KMS service encryption Azure PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureKeyVault(), checkAzureKeyVault($code)); 
    #HL-630 KMS service encryption AWS PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComAmazonawsServicesKms(), $checkPattern->(qr/\bimport\s+boto3\b/, $code));
    #HL-634 Azure blob storage Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage(), checkAzureBlobStorage($code)); 
    #HL-636 AWS S3 storage PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsS3Storage(), checkAmazonawsS3Storage($code, $HString)); 
    #HL-640 Azure elasticache PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_InMemoryRedisAzure(), checkInMemoryRedisAzure($code, $HString)); 
    #HL-641 AWS elasticache PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_InMemoryRedisAws(), checkInMemoryRedisAws($code, $HString)); 
    #HL-646 Azure Active Directory access permission PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureDirectoryService(), checkAzureDirectoryService($code)); 
    #HL-647 AWS Active Directory access permission PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsDirectoryService(), checkAwsDirectoryService($code, $HString)); 
    #HL-651 Detect Usage of AWS Batch PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsBatch(), checkAmazonawsBatch($code, $HString)); 
    #HL-652 Detect Usage of Azure Batch PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureBatch(), checkAzureBatch($code)); 
    #HL-654 Azure service bus messaging PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureServiceBusMessaging(), checkAzureServiceBusMessaging($code)); 
    #HL-658 Azure Cloud Identity and Access Management
#	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureAccessManagement(), checkAzureAccessManagement($code)); 
    #HL-659 AWS Cloud Identity and Access Management PHP & Python
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonAwsAccessManagement(), checkAmazonAwsAccessManagement($code, $HString)); 
	#HL-952 17/09/2019 [GCP Boosters] Using Kubernetes
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingKubernetes(), $checkPattern->(qr/\b(?:import|from)\s+kubernetes\b/, $code));
	# HL-953 07/10/2019 [GCP Boosters] Using BigQuery
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigQuery(), $checkPattern->(qr/\b(?:import|from)\s+bigquery\b|\bbigquery\.Client\b/, $code));
	# HL-957 10/10/2019 [GCP Boosters] Using a Cloud-Based Storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudDataStore(), $checkPattern->(qr/\bfrom\s+google\.cloud\s+import\s+datastore\b|\bdatastore\.Client\b/, $code));
	# HL-958 11/10/2019 [GCP Boosters] Using BigTable
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigTable(), $checkPattern->(qr/\bfrom\s+google\.cloud\s+import\s+bigtable\b|\bbigtable\.Client\b/, $code));
	# HL-959 15/10/2019 [GCP Boosters] Using Cloud Spanner
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudSpanner(), $checkPattern->(qr/\bfrom\s+google\.cloud\s+import\s+spanner\b|\bspanner\.Client\b/, $code));
	# HL-960 16/10/2019 [GCP Boosters] Using Cloud in-memory database (redis)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Using_InMemoryRedisGCP(), $checkPattern->(qr/\bimport\s+redis\b|\bredis\.StrictRedis\b/, $code));
	# HL-961 17/10/2019 [GCP Boosters] Using Cloud IAM (Identity and Access Management)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudIAM(), checkPatternInCodeAndString($code, $HString, '\bgoogleapiclient\.discovery\.build\s*\(\s*', '(?i)iam'));
	# HL-962 18/10/2019 [GCP Boosters] Using Firebase
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingFireBase(), $checkPattern->(qr/\bfrom\s+firebase(?:_admin)?\s+import\s+\b(?:auth|firebase)\b/, $code));
	# HL-963 28/10/2019 [GCP Boosters] Using Cloud IAP (Identity Aware Proxy)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudIAP(), $checkPattern->(qr/\bdef\s+make_iap_request\b/, $code));
	# HL-964 28/10/2019 [GCP Boosters] Using a Cloud-based Key storage (KMS)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPServicesKms(), checkPatternInCodeAndString($code, $HString, '\bgoogleapiclient\.discovery\.build\s*\(\s*', 'cloudkms'));
	# HL-965 28/10/2019 [GCP Boosters] Using a Cloud-Based Storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPStorage(), $checkPattern->(qr/\bfrom\s+google\.cloud\s+import\s+storage\b|\bstorage\.Client\b/, $code));
	# HL-966 29/10/2019 [GCP Boosters] Using a Cloud-based task scheduling service
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPScheduler(), checkPatternInCodeAndString($code, $HString, '\bdiscovery\.build\s*\(\s*', 'cloudscheduler'));
	# HL-967 29/10/2019 [GCP Boosters] Using a Cloud-based Stream and Batch data processing
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudDataflow(),  $checkPattern->(qr/\bimport\s+apache_beam\b/, $code));
	# HL-968 30/10/2019 [GCP Boosters] Using a Cloud-based middleware application
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudPubSub(),  $checkPattern->(qr/\bfrom\s+google\.cloud\s+import\s+pubsub_v[0-9]+\b/, $code));
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
