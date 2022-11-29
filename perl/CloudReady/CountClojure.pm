package CloudReady::CountClojure;

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

sub checkUseAndString($$$$$$) {
	my $regexUse = shift;
	my $regexString = shift;
	my $code = shift;
	my $text = shift;
	my $HString = shift;
	my $mnemo = shift;

	my $nb_use = 0;
	my $nb_ContentString = 0;
	my $pos;
	# my $regexPrefix = qr/\b(?:ns|require|use|import)\s*/;
	my $code_bis = $$code;
	if (defined $regexUse) {
		while ($$code =~ /^(.*?)([\(\[\s]+$regexUse)/mg) {
			$nb_use++;
			CloudReady::lib::ElaborateLog::ElaborateLogPartOne(\$code_bis, $regexUse, $mnemo, $rulesDescription);
		}
	}
	if (defined $regexString) {
		for my $stringId (keys %$HString) {
			if ($HString->{$stringId} =~ /$regexString/) {
				$nb_ContentString++;
				my $string = quotemeta($HString->{$stringId});
				my $regex = qr/$string/;
				CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, $mnemo, $rulesDescription);
			}
		}
	}

	return $nb_use + $nb_ContentString;
}

sub CountClojure($$$) {
	my ($fichier, $vue, $compteurs, $techno) = @_ ;
	my $ret = 0;
	
	my $code;
	my $HString;
    my $MixBloc;
	my $text;
	$text = \$vue->{'text'};
	$aggloView = $vue->{'agglo'};
	$binaryView = $vue->{'bin'};

	my $checkPattern = \&checkPatternSensitive;
	
	$code = \$vue->{'code'};
	$HString = $vue->{'HString'};
    $MixBloc = \$vue->{'MixBloc'};

	$rulesDescription = CloudReady::lib::ElaborateLog::keepPortalData();

	if ((! defined $code ) || (!defined $$code)) {
		#$ret |= Couples::counter_add($compteurs, $MissingJSPComment__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	# HL-1885 25/11/2021 Detect the usage of local files manipulation
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Open(), $checkPattern->(qr/\bwith\-open\b/, $code, CloudReady::Ident::Alias_Open));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileRead(), $checkPattern->(qr/(?<!\-)\b(?:slurp|line\-seq|make\-reader|reader)\b|\.read\b/, $code, CloudReady::Ident::Alias_FileRead));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Write(), $checkPattern->(qr/(?<!\-)\b(?:spit|writer|make\-writer)\b|\.write\b/, $code, CloudReady::Ident::Alias_Write));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileExists(), $checkPattern->(qr/\.exists\b/, $code, CloudReady::Ident::Alias_FileExists));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCopy(), $checkPattern->(qr/\bcopy\-file\b/, $code, CloudReady::Ident::Alias_FileCopy));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_FileInputStream(), $checkPattern->(qr/(?<!\-)\b(?:make\-input\-stream|input\-stream)\b/, $code, CloudReady::Ident::Alias_New_FileInputStream));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileDelete(), $checkPattern->(qr/\bdelete\-file\b/, $code, CloudReady::Ident::Alias_FileDelete));
	# HL-1886 25/11/2021 Detect the usage of local directory manipulation
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCurrent(), $checkPattern->(qr/\*cwd\*/, $code, CloudReady::Ident::Alias_DirectoryCurrent));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCopy(), $checkPattern->(qr/\bcopy\-dir\b/, $code, CloudReady::Ident::Alias_DirectoryCopy));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryDelete(), $checkPattern->(qr/\bdelete\-directory\b/, $code, CloudReady::Ident::Alias_DirectoryDelete));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCreate(), $checkPattern->(qr/\bmkdir\b/, $code, CloudReady::Ident::Alias_DirectoryCreate));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryExists(), $checkPattern->(qr/\.isDirectory\b/, $code, CloudReady::Ident::Alias_DirectoryExists));
	# HL-1887 25/11/2021 Detect the usage of environment variables
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_EnvironmentVariable(), $checkPattern->(qr/\bSystem\/getenv\b/, $code, CloudReady::Ident::Alias_EnvironmentVariable));
	# HL-1888 25/11/2021 Detect the usage of hardcoded path
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedPath(), CloudReady::lib::HardCodedPath::checkHardCodedPath($HString, $techno, $code, $text));
	# HL-1889 25/11/2021 Detect the usage of hardcoded IP
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedIP(), CloudReady::lib::HardCodedIP::checkHardCodedIP($HString, $code, $techno, $text));
	# HL-1890 25/11/2021 Detect the usage of system calls or processes management
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_LaunchSubProcess(), $checkPattern->(qr/\b(?:ProcessBuilder|with\-sh\-env)\b/, $code, CloudReady::Ident::Alias_LaunchSubProcess));
	# HL-1891 25/11/2021 Detect the usage of unsecured URI
	CloudReady::lib::URINotSecured::checkURINotSecured($fichier, $code, $HString, $techno, $text);
	#  HL-1870 26/11/2021 Detect the usage of a cloud-based Data Warehouse
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Using_AmazonRedshift(), checkUseAndString(qr/\b(?:amazonica\.aws\.redshift|portkey\.aws\.redshift)\b/, qr/\b(?:redshift|com\.amazon\.redshift)\b/, $code, $text, $HString, CloudReady::Ident::Alias_Using_AmazonRedshift));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsAthena(), checkUseAndString(qr/\b(?:portkey\.aws\.athena|athena\.core|loki\.core|com\.amazonaws\.services\.athena)\b/, qr/\b(?:athena)\b/, $code, $text, $HString, CloudReady::Ident::Alias_AwsAthena));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigQuery(), checkUseAndString(qr/\b(?:googlecloud\.bigquery|gclouj\.bigquery|com\.google\.api\.services\.bigquery|com\.google\.cloud\.bigquery)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_UsingBigQuery));
	#  HL-1871 29/11/2021 Detect the usage of a cloud-based storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsS3Storage(), checkUseAndString(qr/\b(?:aws\.sdk\.s3|portkey\.aws\.s3|boot\-hedge\.aws\.s3|amazonica\.aws\.s3|com\.amazonaws\.services\.s3)\b/, qr/\b(?:s3)\b/, $code, $text, $HString, CloudReady::Ident::Alias_AmazonawsS3Storage));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage(), checkUseAndString(qr/\b(?:clj4azure\.storage\.blob|com\.microsoft\.azure\.storage)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPStorage(), checkUseAndString(qr/\b(?:clj\-gcloud\.storage|com\.google\.cloud\.storage)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_GCPStorage));
	#  HL-1872 29/11/2021 Detect the usage of a cloud-based search engine
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Elasticsearch(), checkUseAndString(qr/\b(?:clojurewerkz\.elastisch|org\.elasticsearch\.client|amazonica\.aws\.elasticsearch|com\.amazonaws\.services\.elasticsearch)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_Elasticsearch));
	#  HL-1873 29/11/2021 Detect the usage of a cloud-based function as a service (serverless)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsLambda(), checkUseAndString(qr/\b(?:portkey\.aws\.lambda|boot\-hedge\.aws\.lambda|amazonica\.aws\.lambda|com\.amazonaws\.services\.lambda)\b/, qr/\b(?:lambda)\b/, $code, $text, $HString, CloudReady::Ident::Alias_AwsLambda));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureFunctions(), checkUseAndString(qr/\b(?:com\.github\.hindol\.clj\-fn|com\.microsoft\.azure\.functions)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_AzureFunctions));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPFunctions(), checkUseAndString(qr/\b(?:cloud\-function|clj\.new\.cljs\-cloud\-function|cloud\-fn)\b/, qr/\b(?:firebase\-functions)\b/, $code, $text, $HString, CloudReady::Ident::Alias_GCPFunctions));
	#  HL-1874 29/11/2021 Detect the usage of a cloud-based NoSQL database storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_DynamoDB(), checkUseAndString(qr/\b(?:portkey\.aws\.dynamodb|amazonica\.aws\.dynamodbv2|com\.amazonaws\.services\.dynamodbv2)\b/, qr/\b(?:dynamodb)\b/, $code, $text, $HString, CloudReady::Ident::Alias_DBMS_DynamoDB));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MongoDB(), checkUseAndString(qr/\b(?:somnium\.congomongo|mongo\-driver|monger\.core|com\.mongodb)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_DBMS_MongoDB));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_CosmosDB(), checkUseAndString(qr/\b(?:cljcosmosdb|com\.microsoft\.azure\.documentdb)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_DBMS_CosmosDB));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingFireBase(), checkUseAndString(qr/\b(?:com\.google\.cloud\.firestore)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_UsingFireBase));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigTable(), checkUseAndString(qr/\b(?:com\.google\.cloud\.bigtable)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_UsingBigTable));
	#  HL-1875 29/11/2021 Detect the usage of cloud-based relational database storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_PostgreSQL(), checkUseAndString(undef, qr/\b(?:org\.postgresql\.Driver|com\.impossibl\.postgres\.jdbc\.PGDriver)\b/, $code, $text, $HString, CloudReady::Ident::Alias_DBMS_PostgreSQL));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MySQL(), checkUseAndString(undef, qr/\b(?:com\.mysql\.cj\.jdbc\.Driver|com\.mysql\.jdbc\.Driver)\b/, $code, $text, $HString, CloudReady::Ident::Alias_DBMS_MySQL));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_Oracle(), checkUseAndString(undef, qr/\b(?:oracle\.jdbc\.OracleDriver)\b/, $code, $text, $HString, CloudReady::Ident::Alias_DBMS_Oracle));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_SQLServer(), checkUseAndString(undef, qr/\b(?:com\.microsoft\.sqlserver\.jdbc\.SQLServerDriver)\b/, $code, $text, $HString, CloudReady::Ident::Alias_DBMS_SQLServer));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Using_AmazonRDS(), checkUseAndString(qr/\b(?:portkey\.aws\.rds|com\.amazonaws\.services\.rds)\b/, qr/\b(?:rds)\b/, $code, $text, $HString, CloudReady::Ident::Alias_Using_AmazonRDS));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudSpanner(), checkUseAndString(qr/\b(?:com\.google\.cloud\.spanner)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_UsingCloudSpanner));
	#  HL-1876 01/12/2021 Detect the usage of in-memory database storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_InMemoryRedis(), checkUseAndString(qr/\b(?:redis|com\.google\.cloud\.redis)\b/, qr/\b(?:com\.google\.cloud\.redis)\b/, $code, $text, $HString, CloudReady::Ident::Alias_InMemoryRedis));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Using_AmazonElastiCache(), checkUseAndString(qr/\b(?:amazonica\.aws\.elasticache|com.amazonaws\.services\.elasticache)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_Using_AmazonElastiCache));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_InMemoryMemcached(), checkUseAndString(qr/\b(?:net\.spy\.memcached|clojure\.memcached|clojurewerkz\.spyglass\.client)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_InMemoryMemcached));
	#  HL-1877 01/12/2021 Detect the usage of a cloud-based Identity and Access Management (IAM)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsCloudIAM(), checkUseAndString(qr/\b(?:portkey\.aws\.iam|amazonica\.aws\.identitymanagement)\b/, qr/\b(?:iam)\b/, $code, $text, $HString, CloudReady::Ident::Alias_AwsCloudIAM));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureDirectoryService(), checkUseAndString(qr/\b(?:clj\-ldap\.client)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_AzureDirectoryService));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudIAM(), checkUseAndString(qr/\b(?:com\.google\.cloud\.iam)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_UsingCloudIAM));
	#  HL-1878 01/12/2021 Detect the usage of a cloud-based key service encryption
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsServicesKms(), checkUseAndString(qr/\b(?:portkey\.aws\.kms|amazonica\.aws\.kms)\b/, qr/\b(?:kms)\b/, $code, $text, $HString, CloudReady::Ident::Alias_AmazonawsServicesKms));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPServicesKms(), checkUseAndString(qr/\b(?:com\.google\.cloud\.kms)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_GCPServicesKms));
	#  HL-1879 01/12/2021 Detect the usage of a cloud-based container service
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsContainerRegistry(), checkUseAndString(qr/\b(?:portkey\.aws\.ecr|amazonica\.aws\.ecr)\b/, qr/\b(?:ecr)\b/, $code, $text, $HString, CloudReady::Ident::Alias_AwsContainerRegistry));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsElasticContainer(), checkUseAndString(qr/\b(?:portkey.aws.ec(?:2|s)|amazonica.aws.ec(?:2|s))\b/, qr/\b(?:ec(?:2|s))\b/, $code, $text, $HString, CloudReady::Ident::Alias_AwsElasticContainer));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPCloudContainer(), checkUseAndString(qr/\b(?:com\.google\.cloud\.container)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_GCPCloudContainer));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Docker(), checkUseAndString(qr/\b(?:clj\-docker\-client)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_Docker));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Kubernetes(), checkUseAndString(qr/\b(?:lambdakube|kubernetes\-api)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_Kubernetes));
	# HL-1880 02/12/2021 Detect the usage of a cloud-based middleware application
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Using_AmazonSQS(), checkUseAndString(qr/\b(?:portkey\.aws\.sqs|amazonica\.aws\.sqs)\b/, qr/\b(?:sqs)\b/, $code, $text, $HString, CloudReady::Ident::Alias_Using_AmazonSQS));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsKinesis(), checkUseAndString(qr/\b(?:portkey\.aws\.kinesis|amazonica\.aws\.kinesis)\b/, qr/\b(?:kinesis)\b/, $code, $text, $HString, CloudReady::Ident::Alias_AwsKinesis));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudPubSub(), checkUseAndString(qr/\b(?:com\.google\.cloud\.pubsub)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_UsingCloudPubSub));
	# HL-1881 03/12/2021 Detect the usage of a cloud-based Big Data technology
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsEMRBigData(), checkUseAndString(qr/\b(?:clj\-emr\.core|com\.amazonaws\.services\.elasticmapreduce)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_AwsEMRBigData));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Hadoop(), checkUseAndString(qr/\b(?:clojure\-hadoop|org\.apache\.hadoop\.util)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_Hadoop));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Spark(), checkUseAndString(qr/\b(?:sparkling|org\.apache\.spark|flambo)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_Spark));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Kafka(), checkUseAndString(qr/\b(?:com\.amazonaws\.services\.kafka)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_Kafka));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPDataproc(), checkUseAndString(qr/\b(?:com\.google\.cloud\.dataproc)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_GCPDataproc));
	# HL-1882 03/12/2021 Detect the usage of JSON to facilitate interactions with cloud services
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_JSONParsing(), checkUseAndString(qr/\b(?:clojure\.data\.json|cheshire)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_JSONParsing));
	# HL-1883 03/12/2021 Detect the usage of XML to facilitate interactions with cloud services
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_XMLParsing(), checkUseAndString(qr/\b(?:clojure(?:\.data)?\.xml)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_XMLParsing));
	# HL-1884 06/12/2021 Detect the usage of a cloud-based blockchain technology
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Blockchain(), checkUseAndString(qr/\b(?:nuid\.ethereum|clojurescript\-ethereum|clojure\-fabric|org\.hyperledger\.fabric|com\.amazonaws\.services\.managedblockchain)\b/, undef, $code, $text, $HString, CloudReady::Ident::Alias_Blockchain));
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
