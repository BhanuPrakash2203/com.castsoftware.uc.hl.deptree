package CloudReady::CountNodeJS;

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

my $rulesDescription;
my $binaryView;
my $aggloView;

sub checkPatternSensitive($$$) {
	my $reg = shift;
	my $code = shift;
	my $mnemo = shift;

    return CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $reg, $mnemo, $rulesDescription);
    # return () = ($$code =~ /$reg/gm);
}

# HL-781 
sub checkPathManipulation($$$$) {
	my $code = shift;
	my $HString = shift;
	my $text = shift;
	my $mnemo = shift;
    my $nb_PathManipulation = 0;
    pos($$code) = undef;
   
    $nb_PathManipulation++ while ($$code =~ /\bOS\.(?:Constants\.)?Path\b/g);
    
    while ($$code =~ /\b(?:require\s*\(|from)\s*(CHAINE_\d+)/g)
    {
        my $match = $1;
        if ($HString->{$match} =~ /["'](?:.*\/)?\bpath["']/)
        {
			$nb_PathManipulation++;
            my $string = quotemeta($HString->{$match});
            my $regex = qr/$string/;
            CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, $mnemo, $rulesDescription);
        }
    }
    if ($$code =~ /\bnew\s+ActiveXObject\s*\(\s*(CHAINE_\d+)/g)
    {
        my $match = $1;
        if ($HString->{$match} =~ /["']Scripting\.FileSystemObject["']/)
        {
			$nb_PathManipulation++;
            my $string = quotemeta($HString->{$match});
            my $regex = qr/$string/;
            CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, $mnemo, $rulesDescription);
        }
    }
	return $nb_PathManipulation;
}

sub checkDBMS($$$$$){
	my $code = shift;
	my $HString = shift;
	my $patternString = shift;
	my $text = shift;
	my $mnemo = shift;

	my $nb_detection = 0;
    pos($$code) = undef;

	$nb_detection = checkDependencyAndPattern($code, $HString, ,$mnemo, $patternString, undef, undef, $text);
	
	if ($nb_detection == 0){
		while($$code =~ /\bclient\s*\:\s*(CHAINE_\d+)/g)
		{
            my $match = $1;
            if ($HString->{$match} =~ /["']${patternString}["']/g)
			{
				$nb_detection++;
                my $string = quotemeta($HString->{$match});
                my $regex = qr/$string/;
                CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, $mnemo, $rulesDescription);
            }
		}
	}	
	return $nb_detection;
}

sub checkDependencyAndPattern($$$;$;$;$;$) {
	my $code = shift;
	my $HString = shift;
    my $mnemo = shift;
    my $PatternDependency = shift;
    my $PatternInCode = shift;
    my $PatternInString = shift;
    my $text = shift;

    my $nb_detection = 0;
    pos($$code) = undef;
    
    if (defined $PatternDependency)
    {   
		# Complying with import forms:
		# 	* require '.*/$PatternDependency/.*'
		# 	* [...] from '.*/$PatternDependency/.*'
		# 	* import '.*/$PatternDependency/.*' 

        while ($$code =~ /\b(?:require\s*\(|from|import)\s*(CHAINE_\d+)/g)
        {
            my $match = $1;
            if ($HString->{$match} =~ /["'](?:.*[\/\\])?$PatternDependency(?:[\/\\].*)?["']/)
            {
                $nb_detection++;
                my $string = quotemeta($HString->{$match});
                my $regex = qr/$string/;
                CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, $mnemo, $rulesDescription);
            }
        }
    }
    
    if (defined $PatternInCode)
    {
        $nb_detection++ while ($$code =~ /$PatternInCode/g);
        my $regex = qr/$PatternInCode/;
        CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
    }
    
    if (defined $PatternInString)
    {
        for my $stringId (keys %$HString) 
        {
            if ($HString->{$stringId} =~ /$PatternInString/) 
            {
                $nb_detection++;
                my $string = quotemeta($HString->{$stringId});
                my $regex = qr/$string/;
                CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
            }
        }
    }

	return $nb_detection;
}

sub CountNodeJS($$$$) {
	my ($fichier, $vue, $compteurs, $techno) = @_ ;
	my $ret = 0;
	
	my $code;
	my $HString;
    my $text;
    $text = \$vue->{'text'};
    my $MixBloc;
	my $checkPattern = \&checkPatternSensitive;

    $rulesDescription = CloudReady::lib::ElaborateLog::keepPortalData();

    $code = \$vue->{'code'};
	$HString = $vue->{'HString'};
    $MixBloc = \$vue->{'MixBloc'};
    $binaryView = $vue->{'bin'};
    $aggloView = $vue->{'agglo'};

	if ((! defined $code ) || (!defined $$code)) {
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	# HL-777 Using Access Control Lists
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_AccessControlList(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_New_AccessControlList, "accesscontrol", qr/\bnew\s+AccessControl\b/,undef, $text));
	# HL-779 Data Encryption Key : Using Crypto API
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingSystemSecurityCryptography(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_UsingSystemSecurityCryptography, "(?:node\-webcrypto\-p11|node\-webcrypto\-ossl)", qr/\bwindow\.(?:crypto|msCrypto|mozCrypto|webkitCrypto)\b(\.getRandomValues\b)?|\bsubtle\.(?:decrypt|deriveBits|deriveKey|digest|encrypt|exportKey|generateKey|importKey|sign|verify|unwrapKey|wrapKey)\b/, undef, $text));
    # HL-780 28/02/2019 Using hardcoded network IP address (IPV4, IPV6)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedIP(), CloudReady::lib::HardCodedIP::checkHardCodedIP($HString, $code, $techno, $text));
	# HL-781 01/03/2019 Perform Directory Manipulation
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCurrent(), $checkPattern->(qr/\bprocess\.cwd\b/, $code, CloudReady::Ident::Alias_DirectoryCurrent));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryChange(), $checkPattern->(qr/\bprocess\.chdir\b/, $code, CloudReady::Ident::Alias_DirectoryChange));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Path(), checkPathManipulation($code, $HString, $text, CloudReady::Ident::Alias_Path));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryExists(), $checkPattern->(qr/\bOS\.File\.DirectoryIterator\b/, $code, CloudReady::Ident::Alias_DirectoryExists));
    # HL-782 01/03/2019 Perform File Manipulation
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_FileInputStream(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_New_FileInputStream, "fs", qr/\bFileUtils\b|\bOS\.File\.read\b/, undef, $text));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Open(), $checkPattern->(qr/\bOS\.File\.open\b/, $code, CloudReady::Ident::Alias_Open));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCopy(), $checkPattern->(qr/\bOS\.File\.copy\b/, $code, CloudReady::Ident::Alias_FileCopy));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileMove(), $checkPattern->(qr/\bOS\.File\.move\b/, $code, CloudReady::Ident::Alias_FileMove));
    # HL-783 01/03/2019 Access to Environment Variables
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_EnvironmentVariable(), $checkPattern->(qr/\bprocess\.env\b/, $code, CloudReady::Ident::Alias_EnvironmentVariable));
    # HL-784 04/03/2019 Using Process with Node.js process object
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_Process(), $checkPattern->(qr/\bprocess\.(?:setegid|seteuid|setgid|setgroups|setuid)\b/, $code, CloudReady::Ident::Alias_New_Process));
    # HL-785 04/03/2019 Avoid code that can accidentally get skipped
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_CodeSkipped(), $checkPattern->(qr/\bassert\b/, $code, CloudReady::Ident::Alias_CodeSkipped));
    # HL-786 05/03/2019 Using a Cloud-Based Storage
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsS3Storage(), $checkPattern->(qr/\bnew\s+(?i)AWS\.S3\b/, $code, CloudReady::Ident::Alias_AmazonawsS3Storage));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage, "azure\-storage", qr/\bcreateBlobService\b/, undef, $text));
	# HL-790 07/03/2019 Using MongoDB database
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MongoDB(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_DBMS_MongoDB, "(?:mongodb|mongoose)", undef, undef, $text));
    # HL-791 07/03/2019 Using NoSQL document storage (CosmosDB)
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_CosmosDB(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_DBMS_CosmosDB, "(?:documentdb|documentdb\-typescript)", qr/\bnew\s+CosmosClient\b/, undef, $text));
    # HL-792 07/03/2019 Using a Cloud-based Key storage
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsServicesKms(),  $checkPattern->(qr/\bnew\s+(?i)aws\.kms\b/, $code, CloudReady::Ident::Alias_AmazonawsServicesKms));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureKeyVault(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_MicrosoftAzureKeyVault, "azure\-arm\-keyvault", undef, undef, $text));
    # HL-793 08/03/2019 Using a Cloud-based task scheduling service
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsScheduler(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_AwsScheduler, "aws\-scheduler", qr/\bnew\s+AWS.Batch\b/, undef, $text));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureScheduler(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_AzureScheduler, "(?:azure\-asm\-scheduler|azure\-scheduler|azure\-batch)", undef, undef, $text));
    # HL-794 11/03/2019 Using a Cloud-based Active Directory
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_CloudActiveDirectory(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_CloudActiveDirectory, "(?:adal(?:[\.\-].*)?|activedirectory|react\-adal)", qr/\bnew\s+AdalConfig\b/, undef, $text));
    # HL-795 11/03/2019 Using a Cloud-based Service Bus
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureServiceBusMessaging(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_AzureServiceBusMessaging, "(?:azure\-arm\-sb|azure\-sb)", qr/\b(?:createServiceBusService|ServiceBusService)\b/, undef, $text));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Using_AmazonSQS(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_Using_AmazonSQS, undef, qr/\b(?:new\s+AWS\.SQS)\b/, undef, $text));
	# HL-870 25/05/2019 Split FTP/HTTP CloudReady pattern in 2 separate patterns
	CloudReady::lib::URINotSecured::checkURINotSecured($fichier, $code, $HString, $techno, $text);
	# HL-952 17/09/2019 [GCP Boosters] Using Kubernetes
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingKubernetes(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_UsingKubernetes, "\@kubernetes\/client\-node", qr/\bnew\s+[\w]+\.KubeConfig\b/, undef, $text));
	# HL-953 07/10/2019 [GCP Boosters] Using BigQuery
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigQuery(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_UsingBigQuery, "\@google\-cloud\/bigquery", undef, undef, $text));
    # HL-788 06/03/2019 Using MySQL database with Node.js
	# HL-954 08/10/2019 [GCP Boosters] Using MySQL database
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MySQL(), checkDBMS($code, $HString, "mysql", $text, CloudReady::Ident::Alias_DBMS_MySQL));
    # HL-789 06/03/2019 Using PostgreSQL database
	# HL-955 09/10/2019 [GCP Boosters] Using PostgreSQL database    
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_PostgreSQL(), checkDBMS($code, $HString, "pg", $text, CloudReady::Ident::Alias_DBMS_PostgreSQL));
	# HL-957 10/10/2019 [GCP Boosters] Using a Cloud-Based Storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudDataStore(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_UsingCloudDataStore, "\@google\-cloud\/datastore", undef, undef, $text));
	# HL-958 11/10/2019 [GCP Boosters] Using BigTable
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigTable(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_UsingBigTable, "\@google\-cloud\/bigtable", undef, undef, $text));
	# HL-959 15/10/2019 [GCP Boosters] Using Cloud Spanner
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudSpanner(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_UsingCloudSpanner, "\@google\-cloud\/spanner", qr/\bnew\s+Spanner\b/, undef, $text));
	# HL-960 16/10/2019 [GCP Boosters] Using Cloud in-memory database (redis)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Using_InMemoryRedisGCP(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_Using_InMemoryRedisGCP, "\@google\-cloud\/redis", qr/\bnew\s+CloudRedisClient\b/, undef, $text));
	# HL-961 17/10/2019 [GCP Boosters] Using Cloud IAM (Identity and Access Management)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudIAM(), $checkPattern->(qr/\biam\.getPolicy\b/, $code, CloudReady::Ident::Alias_UsingCloudIAM));
	# HL-962 18/10/2019 [GCP Boosters] Using Firebase
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingFireBase(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_UsingFireBase, "firebase", undef, undef, $text));
	# HL-963 28/10/2019 [GCP Boosters] Using Cloud IAP (Identity Aware Proxy)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudIAP(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_UsingCloudIAP, undef, qr/\bclass\s+Iap\b/, undef, $text));
	# HL-964 28/10/2019 [GCP Boosters] Using a Cloud-based Key storage (KMS)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPServicesKms(), $checkPattern->(qr/\.cloudkms\b/, $code, CloudReady::Ident::Alias_GCPServicesKms));
	# HL-965 28/10/2019 [GCP Boosters] Using a Cloud-Based Storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPStorage(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_GCPStorage, "\@google\-cloud\/storage", undef, undef, $text));
	# HL-966 29/10/2019 [GCP Boosters] Using a Cloud-based task scheduling service
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPScheduler(), $checkPattern->(qr/\bnew\s+(?:.*?)\.CloudSchedulerClient\b|\.cloudscheduler\b/, $code, CloudReady::Ident::Alias_GCPScheduler));
	# HL-968 30/10/2019 [GCP Boosters] Using a Cloud-based middleware application
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudPubSub(), checkDependencyAndPattern($code, $HString, CloudReady::Ident::Alias_UsingCloudPubSub, "\@google\-cloud\/pubsub", qr/\bnew\s+PubSub\b/, undef, $text));
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
