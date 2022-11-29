package CloudReady::CountDotnet;

use strict;
use warnings;

use Erreurs;
use CloudReady::detection;
use CloudReady::Ident;
use CloudReady::config;
use CloudReady::lib::HardCodedIP;
use CloudReady::lib::HardCodedPath;
use CloudReady::lib::HardCodedURL;
use CloudReady::lib::URINotSecured;
use CloudReady::lib::SensitiveDataString;
use CloudReady::lib::ElaborateLog;
use Lib::SHA;

use constant BEGINNING_MATCH => 0;
use constant FULL_MATCH => 1;

my %H_RegsCS;
my %H_RegsVB;
my $rulesDescription;
my $aggloView;
my $binaryView;

$rulesDescription = CloudReady::lib::ElaborateLog::keepPortalData();

sub checkPatternSensitive($$$) {
	my $reg = shift;
	my $code = shift;
	my $mnemo = shift;

	return CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $reg, $mnemo, $rulesDescription);
	#return () = ($$code =~ /$reg/gm);
}

sub checkUsingCS($$$$) {
	my $mnemo = shift;
	my $pattern = shift;
	my $mode = shift;
	my $code = shift;

	my $reg = $H_RegsCS{$mnemo};
	my $ENDING = '';
	
	if (! $reg) {
		if ($mode == FULL_MATCH) {
			$ENDING = '\s*;';
		}
		else {
			$ENDING = '\b';
		}
		$reg = qr/^\s*\busing\s+$pattern$ENDING/m;
		$H_RegsCS{$mnemo} = $reg;
	}

	return CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $reg, $mnemo, $rulesDescription);
	#return () = ($$code =~ /$reg/g);
}

sub checkImportVB($$$$$) {
	my $mnemo = shift;
	my $pattern = shift;
	my $mode = shift;
	my $code = shift;
	my $techno = shift;

	my $reg = $H_RegsVB{$mnemo};
	my $ENDING;
	
	if (! $reg) {
		if ($mode == FULL_MATCH) {
			$ENDING = "\\s*\n";
		}
		else {
			$ENDING = '\b';
		}
		$reg = qr/^\s*\bimports\s+(?:[\w\.]*\s*=\s*)?$pattern$ENDING/mi;
		$H_RegsVB{$mnemo} = $reg;
	}

	return CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $reg, $mnemo, $rulesDescription);
	#return () = $$code =~ /$reg/g;
}

sub addFileDetectionUsing($$$$$$) {
	my $mnemo = shift;
	my $pattern = shift;
	my $mode = shift;
	my $code = shift;
	my $checkUsing = shift;
	my $fichier = shift;

	CloudReady::detection::addFileDetection($fichier, $mnemo, $checkUsing->($mnemo, $pattern, $mode, $code));
}

sub checkVarTEMP($$) {
	my $code = shift;
	my $HString = shift;
	my $nb_get = 0;
	my $nb_expand = 0;
	
	while ($$code =~ /Environment\.(?:(GetEnvironmentVariable)|(ExpandEnvironmentVariables))\s*\(\s*(?:(CHAINE_\d+)|"(ch\d+)")/sg) {
		my $string_value;
		if (defined $3) {
			# C#
			$string_value = $HString->{$3};
		}
		else {
			# VB
			$string_value = "\"$HString->{$4}\"";
		}
		if (defined $1) {
			if (($string_value eq '"TEMP"') || ($string_value eq "'TEMP'") ||
				($string_value eq '"TMP"') || ($string_value eq "'TMP'")) {
				$nb_get++;
#print "--> GETTING TEMP VAR !!!\n"
			}
		}
		else {
			if ($string_value =~ /%(?:TEMP|TMP)%/) {
				$nb_expand++;
#print "--> EXPANDING TEMP VAR in $string_value !!!\n"
			}
		}
	}
	return ($nb_get, $nb_expand);
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

sub checkDBMSMySQL($$$$) {

	my $code = shift;
	my $HString = shift;
	my $techno = shift;
	my $mnemo = shift;
	my $nb_DBMSMySQL = 0;
    
    if ($techno eq "VB") 
    {
    # VB
		if ($$code =~ /\bImports\s+MySql\.Data\b/i) {
			if ($$code =~ /\bNew\s+(?:MySql\.Data\.MySqlClient\.)?MySqlConnection\b/i) {
				#$nb_DBMSMySQL = 1;
				my $regex = qr /\bNew\s+(?:MySql\.Data\.MySqlClient\.)?MySqlConnection\b/i;
				$nb_DBMSMySQL = CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
			}
		}
		elsif ($$code =~ /\bImports\s+System\.Data\.Odbc\b/i) {
			if (oneStringContains($HString, qr/^\bDRIVER\s*\=\s*\{\s*MySQL\b/im)) {
				#$nb_DBMSMySQL = 1;
				my $regex = qr /\bImports\s+System\.Data\.Odbc\b/i;
				$nb_DBMSMySQL = CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
			}
		}
    }
    else 
    {
    # CS
		if ($$code =~ /\busing\s+MySql\.Data\b/) {
			if ($$code =~ /\bnew\s+(?:MySql\.Data\.MySqlClient\.)?MySqlConnection\b/) {
				#$nb_DBMSMySQL = 1;
				my $regex = qr /\busing\s+MySql\.Data\b/;
				$nb_DBMSMySQL = CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
			}
		}
		elsif ($$code =~ /\busing\s+System\.Data\.Odbc\b/) {
			if (oneStringContains($HString, qr/^["']DRIVER\s*\=\s*\{\s*MySQL\b/im)) {
				#$nb_DBMSMySQL = 1;
				my $regex = qr /\busing\s+System\.Data\.Odbc\b/;
				$nb_DBMSMySQL = CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
			}
		}
		# HL-954
		#while ($$code =~ /\bnew\s+(?:MySqlConnection(?:StringBuilder)?)\b/g) {
		#	$nb_DBMSMySQL++;
		#}
		my $regex = qr /\bnew\s+(?:MySqlConnection(?:StringBuilder)?)\b/;
		$nb_DBMSMySQL += CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
	}
	return $nb_DBMSMySQL;
}

sub checkDBMSPostgreSQL($$$$) {

	my $code = shift;
	my $HString = shift;
	my $techno = shift;
	my $mnemo = shift;
	my $nb_DBMSPostgresSQL = 0;
    
    if ($techno eq "VB") 
    {
    # VB
        if ($$code =~ /(?:\bImports\s+Npgsql\b)/i) {
			#$nb_DBMSPostgresSQL = 1;
			my $regex = qr/(?:\bImports\s+Npgsql\b)/i;
			$nb_DBMSPostgresSQL = CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
		}
		elsif ($$code =~ /(?:\bImports\s+System\.Data\.Odbc\b)/i) {
			if (oneStringContains($HString, qr/^\bDRIVER\s*\=\s*\{\s*PostgreSQL\b/im)) {
				#$nb_DBMSPostgresSQL = 1;
				my $regex = qr/(?:\bImports\s+System\.Data\.Odbc\b)/i;
				$nb_DBMSPostgresSQL = CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
			}
		}
    }
    else 
    {
    # CS
        if ($$code =~ /\busing\s+Npgsql\b/) {
			#$nb_DBMSPostgresSQL = 1;
			my $regex = qr/\busing\s+Npgsql\b/;
			$nb_DBMSPostgresSQL = CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
		}
		elsif ($$code =~ /(?:\busing\s+System\.Data\.Odbc\b)/) {
			if (oneStringContains($HString, qr/^\bDRIVER\s*\=\s*\{\s*PostgreSQL\b/im)) {
				#$nb_DBMSPostgresSQL = 1;
				my $regex = qr/(?:\busing\s+System\.Data\.Odbc\b)/;
				$nb_DBMSPostgresSQL = CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
			}
		}
		# HL-955
		#while ($$code =~ /\bnew\s+(?:NpgsqlConnection(?:StringBuilder)?)\b/g) {
		#	$nb_DBMSPostgresSQL++;
		#}
		my $regex = qr/\bnew\s+(?:NpgsqlConnection(?:StringBuilder)?)\b/;
		$nb_DBMSPostgresSQL += CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
	}
	
	return $nb_DBMSPostgresSQL;
}

sub checkAzureTransientFaultHandling($$$) {

	my $code = shift;
	my $techno = shift;
	my $mnemo = shift;
	my $nb_TransientFaultHandling = 0;
    my $regexp_mysql;
        
    if ($techno eq "VB") 
    {
    # VB
        $regexp_mysql = qr/(?:\bImports\s+Microsoft\.Practices(?:\.EnterpriseLibrary\b|\.EnterpriseLibrary\.WindowsAzure)?\.TransientFaultHandling\b)/ix;
    }
    else 
    {
    # CS
        $regexp_mysql = qr/(?:\busing\s+Microsoft\.Practices(?:\.EnterpriseLibrary\b|\.EnterpriseLibrary\.WindowsAzure)?\.TransientFaultHandling\s*\;)/ix;
    }                                                                               
    
    #if ($$code =~ /$regexp_mysql/)
    #{
        # print 'detection DBMS MySQL into code view '."<$1>\n";
    #    $nb_TransientFaultHandling = 1;
    #}

	$nb_TransientFaultHandling += CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regexp_mysql, $mnemo, $rulesDescription);

	return $nb_TransientFaultHandling;
}

sub checkHardCodedConnectionString($$$$$$) {

	my $View_code = shift;
	my $View_string = shift;
	my $View_text = shift;
	my $mnemo = shift;
	my $techno = shift;
	my $fichier = shift;

	# Connection string criteria: contains at least two patterns of list below
	# Data Source=
	# User ID=
	# Password=
	# Initial Catalog=
	# Provider=
	# Dsn=
	# Dbq=
	# Uid=
	# Integrated Security=
	# Trusted_Connection=
	# Persist Security Info=
	# TrustServerCertificate=

	# VB and CS
	# Code view
	my $regexp_ConnectionStringBuilder = qr/\b(?:N|n)ew\s+(Sql|OleDb|Odbc|Oracle)Connection(?:StringBuilder)?\b/;

	my %HardCodedConnectionStrings;
	my $nb_HardCodedConnectionString = 0;
	$nb_HardCodedConnectionString = CloudReady::lib::ElaborateLog::ElaborateLogPartOne($View_code, $regexp_ConnectionStringBuilder, $mnemo, $rulesDescription);

	# String view
	my $regexp_ConnectionStringParams = qr/\b(?:Dsn|Dbq|Uid|Data\s+Source|User\s+ID|Password|pwd|Initial\s+Catalog|Provider|Integrated\s+Security|Trusted_Connection|Persist\s+Security\s+Info|TrustServerCertificate)\b\s*\=?/i;

	for my $stringId (keys %$View_string) {
		my $nb_patterns = () = ($View_string->{$stringId} =~ /$regexp_ConnectionStringParams/g);
		if ($nb_patterns >= 2) {
			$HardCodedConnectionStrings{$View_string->{$stringId}} = 1;
		}
	}

	#HL-474 19/02/18 Microsoft authentication
	my $nb_SQLDatabaseUnsecureAuthentication = 0;
	if (defined $nb_HardCodedConnectionString && $nb_HardCodedConnectionString > 0) {
		$nb_SQLDatabaseUnsecureAuthentication = checkSQLDatabaseUnsecureAuthentication(\%HardCodedConnectionStrings, $View_text);
	}
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_SQLDatabaseUnsecureAuthentication(), $nb_SQLDatabaseUnsecureAuthentication);

	return $nb_HardCodedConnectionString;
}

sub checkSQLDatabaseUnsecureAuthentication($$) {
	my $HardCodedConnectionString = shift;
	my $View_text = shift;

	my $nb_SQLDatabaseUnsecureAuthentication = 0;

	# do a detection if no pattern of list below is found
	# Trusted_Connection = yes
	# Persist Security Info = False
	# Integrated Security = true | yes | SSPI
	# TrustServerCertificate = true

	my $regexp_ConnectionStringParams = qr/\b(?:Trusted_Connection\s*\=\s*yes|Persist\s+Security\s+Info\s*\=\s*false|Integrated\s+Security\s*\=\s*(?:true|yes|SSPI)|TrustServerCertificate\s*\=\s*true)\b/i;

	for my $string (keys %$HardCodedConnectionString) {
		if ($string !~ /$regexp_ConnectionStringParams/) {
			# a connection string is unsecured in the current file
			my $string = quotemeta($string);
			my $regex = qr/$string/;
			CloudReady::lib::ElaborateLog::ElaborateLogPartOne($View_text, $regex, CloudReady::Ident::Alias_SQLDatabaseUnsecureAuthentication, $rulesDescription);
			# print "unsecured connection string $string\n";
			$nb_SQLDatabaseUnsecureAuthentication++;
		}
	}
	return $nb_SQLDatabaseUnsecureAuthentication;
}

sub checkAzurePipelines
{
	my $code = shift;
	my $nb_AzurePipelines = 0;

	if ($$code =~ /\busing\s+Microsoft\.Azure\.Management\.DataFactory\b/) {
		if ($$code =~ /\bnew\s+PipelineResource\b/) {
			$nb_AzurePipelines++;
		}
	}

	return $nb_AzurePipelines;
}

sub checkActiveDirectoryLDAP($) {
	my $code = shift;
	my $nb_ActiveDirectoryLDAP = 0;

	my $mnemo = CloudReady::Ident::Alias_ActiveDirectoryLDAP;

	if ($$code =~ /\busing\s+System\.DirectoryServices\b/) {
		my $reg = qr/\[\s*Authorize\b|\bAuthorizeAttribute\b|\bIsInRole\b/;
		if ($$code =~ /\[\s*Authorize\b|\bAuthorizeAttribute\b|\bIsInRole\b/) {
			my $code_bis = $$code;
			$nb_ActiveDirectoryLDAP += CloudReady::lib::ElaborateLog::ElaborateLogPartOne(\$code_bis, $reg, $mnemo, $rulesDescription);
		}
	}
	if ($$code =~ /\bnew\s+PrincipalContext\b/) {
		my $code_bis = $$code;
		my $reg = qr/\bnew\s+PrincipalContext\b/;
		$nb_ActiveDirectoryLDAP += CloudReady::lib::ElaborateLog::ElaborateLogPartOne(\$code_bis, $reg, $mnemo, $rulesDescription);
	}

	return $nb_ActiveDirectoryLDAP;
}

sub CountDotnet($$$$) {
	my ($fichier, $vue, $compteurs, $techno) = @_ ;
	my $ret = 0;
	
	if ($techno eq "VbDotNet") {
		$techno = "VB";
	}
	
	my $code;
	my $HString;
	my $text;
	$binaryView = $vue->{'bin'};
	$text = \$vue->{'text'};
	$aggloView = $vue->{'agglo'};
	$binaryView = $vue->{'bin'};

	my $checkPattern = \&checkPatternSensitive;
	my $checkUsing = \&checkUsingCS;

	if ($techno eq "CS") {
		if ( (exists $vue->{'prepro'}) && ( defined $vue->{'prepro'} ) ) {
			$code = \$vue->{'prepro'};
		}
		else {
			$code = \$vue->{'sansprepro'};
		}
		$HString = $vue->{'HString'};
	}
	elsif ($techno eq "VB") {
		$code = \$vue->{'sansprepro'};
		$HString = $vue->{'string'};
		$checkPattern = \&checkPatternSensitive;
		$checkUsing = \&checkImportVB;
	}
	if ((! defined $code ) || (!defined $$code)) {
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	# USING detections
	# * Azure
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingSystemIO, 							'System\.IO', 								FULL_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingSystem, 							'System', 									FULL_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingSystemConfiguration, 				'System\.Configuration', 					FULL_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingMicrosoftWin32, 					'Microsoft\.Win32', 						FULL_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingMicrosoftWindowsAzureStorageTable,	'Microsoft\.WindowsAzure\.Storage\.Table', 	FULL_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingStackExchangeRedis, 				'StackExchange\.Redis', 					FULL_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingSystemDiagnostics, 				'System\.Diagnostics', 						FULL_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingMicrosoftAzureKeyVault,			'Microsoft\.Azure\.KeyVault', 				BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingMicrosoftWindowsAzureJobs, 		'Microsoft\.WindowsAzure\.Jobs', 			FULL_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingMicrosoftServiceBusMessaging,		'Microsoft\.ServiceBus\.Messaging', 		FULL_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingSystemMessaging,					'System\.Messaging',						BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingRabbitMQClient,					'RabbitMQ\.Client', 						BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingTIBCOEMS,							'TIBCO\.EMS', 								BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingIBMWMQ,							'IBM\.WMQ', 								BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingSystemSecurityAccessControl,		'System\.Security\.AccessControl', 			FULL_MATCH, $code, $checkUsing, $fichier);
	
	# HL-926 : do not count UsingSystemRuntimeInteropServices when source file name is AssemblyInfo.cs.
	# HL-1657 CloudReady False Positive on COM Component detection
	# Disable rule
	# if ($fichier !~ /\bAssemblyInfo.cs/m) {
		# addFileDetectionUsing(CloudReady::Ident::Alias_UsingSystemRuntimeInteropServices,		'System\.Runtime\.InteropServices', 		FULL_MATCH, $code, $checkUsing, $fichier);
	# }
	# else {
		# CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingSystemRuntimeInteropServices, 0);
	# }
	
	addFileDetectionUsing(CloudReady::Ident::Alias_UsingSystemSecurityCryptography,		'System\.Security\.Cryptography', 		BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_MicrosoftAzureDocuments,		'Microsoft\.Azure\.Documents', 		BEGINNING_MATCH, $code, $checkUsing, $fichier);
	#HL-273 27/10/2017 detect usage of azure batch 
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_MicrosoftAzureManagementBatch,'Microsoft\.Azure\.Management\.Batch', BEGINNING_MATCH, $code, $checkUsing, $fichier);
	# HL-277 30/10/2017 Detect Usage of Azure SQL Data Warehouse 
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_SystemDataSqlClient,'System\.Data\.SqlClient', BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_DBMS_MongoDB(),'MongoDB', BEGINNING_MATCH, $code, $checkUsing, $fichier);
	
	
	# * Amazon
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_AmazonS3Model,			'Amazon\.S3\.Model', 		BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_AmazonSQS,				'Amazon\.SQS', 				BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_AmazonDynamoDBV2,		'Amazon\.DynamoDBv2', 		BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_AmazonSimpleDB,		'Amazon\.SimpleDB', 		BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_AmazonRDS,				'Amazon\.RDS', 				BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_AmazonRedshift,		'Amazon\.Redshift', 		BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_AmazonKeyManagementService,'Amazon\.KeyManagementService', BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_AmazonElastiCache,		'Amazon\.ElastiCache', 		BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_AmazonCloudDirectory,	'Amazon\.CloudDirectory', 	BEGINNING_MATCH, $code, $checkUsing, $fichier);
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_AmazonDirectoryService,'Amazon\.DirectoryService', BEGINNING_MATCH, $code, $checkUsing, $fichier);
	#HL-274 30/10/2017 Detect usage of AWS batch 
	addFileDetectionUsing(CloudReady::Ident::Alias_Using_AmazonBatch,'Amazon\.Batch', BEGINNING_MATCH, $code, $checkUsing, $fichier);

	# OTHER detections
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileMove, $checkPattern->('\bFile\.Move\b', $code, CloudReady::Ident::Alias_FileMove));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCreate, $checkPattern->('\bFile\.Create\b', $code, CloudReady::Ident::Alias_FileCreate));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileDelete, $checkPattern->('\bFile\.Delete\b', $code, CloudReady::Ident::Alias_FileDelete));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCopy, $checkPattern->('\bFile\.Copy\b', $code, CloudReady::Ident::Alias_FileCopy));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileExists, $checkPattern->('\bFile\.Exists\b', $code, CloudReady::Ident::Alias_FileExists));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileEncrypt, $checkPattern->('\bFile\.Encrypt\b', $code, CloudReady::Ident::Alias_FileEncrypt));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileDecrypt, $checkPattern->('\bFile\.Decrypt\b', $code, CloudReady::Ident::Alias_FileDecrypt));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Open, $checkPattern->('\bFile\.Open\b', $code, CloudReady::Ident::Alias_Open));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GetTempPath, $checkPattern->('\bPath\.GetTempPath\b', $code, CloudReady::Ident::Alias_GetTempPath));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCreateDirectory, $checkPattern->('\bDirectory\.CreateDirectory\b', $code, CloudReady::Ident::Alias_DirectoryCreateDirectory));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryMove, $checkPattern->('\bDirectory\.Move\b', $code, CloudReady::Ident::Alias_DirectoryMove));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryDelete, $checkPattern->('\bDirectory\.Delete\b', $code, CloudReady::Ident::Alias_DirectoryDelete));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryExists, $checkPattern->('\bDirectory\.Exists\b', $code, CloudReady::Ident::Alias_DirectoryExists));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_ConfigurationManagerAppSettings, $checkPattern->('\bConfigurationManager\.AppSettings\b', $code, CloudReady::Ident::Alias_ConfigurationManagerAppSettings));
	# HL-930 19/06/2019 Authorization patterns
	# 14/10/2022 Alias_ApiUnsecured unactivated and replaced by checkActiveDirectoryLDAP (a new version of Use of LDAP/AD authentication)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_ApiUnsecured, 0);
	# HL-940 28/06/2019 Detect usage of Log4Net
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Log4Net, $checkPattern->('\blog4net\b', $code, CloudReady::Ident::Alias_Log4Net));

    # Pivotal
    # 27/02/2018 HL-485 .Net - launching sub processes
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_Process, $checkPattern->('\b(?:N|n)ew\s+Process\s*\(', $code, CloudReady::Ident::Alias_New_Process));
    # 27/02/2018 HL-489 .Net EventLog
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_EventLog, $checkPattern->('\b(?:N|n)ew\s+EventLog\s*\(', $code, CloudReady::Ident::Alias_New_EventLog));
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_EventLogTraceListener, $checkPattern->('\b(?:N|n)ew\s+EventLogTraceListener\s*\(', $code, CloudReady::Ident::Alias_New_EventLogTraceListener));
    # 28/02/2018 HL-492 .Net System.ServiceProcess
    addFileDetectionUsing(CloudReady::Ident::Alias_Using_SystemServiceProcess,'System\.ServiceProcess', BEGINNING_MATCH, $code, $checkUsing, $fichier);  

	my ($nb_getTEMP, $nb_expandTEMP) = checkVarTEMP($code, $HString);
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_TempVarReading, $nb_getTEMP);
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_TempVarExpanding, $nb_expandTEMP);
	
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_RegistryGetValue, $checkPattern->('\bRegistry\.GetValue\s*\(', $code, CloudReady::Ident::Alias_RegistryGetValue));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_RegistrySetValue, $checkPattern->('\bRegistry\.SetValue\s*\(', $code, CloudReady::Ident::Alias_RegistrySetValue));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_TraceWriteLine, $checkPattern->('\bTrace\.WriteLine\s*\(', $code, CloudReady::Ident::Alias_TraceWriteLine));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_TraceTraceError, $checkPattern->('\bTrace\.TraceError\s*\(', $code, CloudReady::Ident::Alias_TraceTraceError));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_TraceTraceInformation, $checkPattern->('\bTrace\.TraceInformation\s*\(', $code, CloudReady::Ident::Alias_TraceTraceInformation));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_TraceTraceWarning, $checkPattern->('\bTrace\.TraceWarning\s*\(', $code, CloudReady::Ident::Alias_TraceTraceWarning));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_ConfigurationManagerConnectionStrings, $checkPattern->('\bConfigurationManager\.ConnectionStrings\b', $code, CloudReady::Ident::Alias_ConfigurationManagerConnectionStrings));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_IntanciatingKeyVaultClient, $checkPattern->('\bnew\s+KeyVaultClient\b', $code, CloudReady::Ident::Alias_IntanciatingKeyVaultClient));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_EncryptAsync, $checkPattern->('\bEncryptAsync\s*\(', $code, CloudReady::Ident::Alias_EncryptAsync));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DecryptAsync, $checkPattern->('\bDecryptAsync\s*\(', $code, CloudReady::Ident::Alias_DecryptAsync));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_ImpersonationOption, $checkPattern->('\bImpersonationOption\b', $code, CloudReady::Ident::Alias_ImpersonationOption));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DllImport, $checkPattern->('[\[<]\s*DllImport\s*\(', $code, CloudReady::Ident::Alias_DllImport));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_ComImport, $checkPattern->('^\s*[\[<]\s*ComImport\s*[\(,\]>]', $code, CloudReady::Ident::Alias_ComImport));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileGetAccessControl, $checkPattern->('\bFile\.GetAccessControl\s*\(', $code, CloudReady::Ident::Alias_FileGetAccessControl));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileSetAccessControl, $checkPattern->('\bFile\.SetAccessControl\s*\(', $code, CloudReady::Ident::Alias_FileSetAccessControl));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedPath(), CloudReady::lib::HardCodedPath::checkHardCodedPath($HString, $techno, $code, $text));
	#HL-247 et HL-248 05/10/2017 ajout detection URI et IP
    #HL-608 BUG Fix HL-247 unsecured URL without XML namespace context
	#HL-870 21/05/2019 Split FTP/HTTP CloudReady pattern in 2 separate patterns
	CloudReady::lib::URINotSecured::checkURINotSecured($fichier, $code, $HString, $techno, $text);
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedIP(), CloudReady::lib::HardCodedIP::checkHardCodedIP($HString, $code, $techno, $text));
    #HL-372 11/12/17 Azure MySQL Cloud migration
	#HL-954 08/10/2019 [GCP Boosters] Using MySQL database
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MySQL(), checkDBMSMySQL($code, $HString, $techno, CloudReady::Ident::Alias_DBMS_MySQL) );
	#HL-371 12/12/17 Azure PostgreSQL Cloud migration
	#HL-955 10/10/2019 [GCP Boosters] Using PostgreSQL database	
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_PostgreSQL(), checkDBMSPostgreSQL($code, $HString, $techno, CloudReady::Ident::Alias_DBMS_MySQL) );
    #HL-375 15/12/17 Azure Booster Retry Pattern
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Using_MicrosoftPracticesTransientFaultHandling(), checkAzureTransientFaultHandling($code, $techno, CloudReady::Ident::Alias_Using_MicrosoftPracticesTransientFaultHandling) );

	#HL-366 14/02/18 Connection String hardcoded in source code
    my $HardCodedConnectionString = checkHardCodedConnectionString($code, $HString, $text, CloudReady::Ident::Alias_HardCodedConnectionString, $techno, $fichier);
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedConnectionString(), $HardCodedConnectionString);

	# Amazon
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_S3AccessControlList, $checkPattern->('\bnew\s+S3AccessControlList\s*\(', $code, CloudReady::Ident::Alias_New_S3AccessControlList));

	# HL-952 17/09/2019 [GCP Boosters] Using Kubernetes
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingKubernetes, $checkPattern->('\bKubernetesClientConfiguration\b|\bnew\s+Kubernetes\b', $code, CloudReady::Ident::Alias_UsingKubernetes));
	# HL-953 07/10/2019 [GCP Boosters] Using BigQuery
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigQuery, $checkPattern->('\busing\s+Google.Cloud.BigQuery\b', $code, CloudReady::Ident::Alias_UsingBigQuery));
	# HL-957 10/10/2019 [GCP Boosters] Using a Cloud-Based Storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudDataStore, $checkPattern->('\busing\s+Google.Cloud.Datastore\b', $code, CloudReady::Ident::Alias_UsingCloudDataStore));
	# HL-958 11/10/2019 [GCP Boosters] Using BigTable
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingBigTable, $checkPattern->('\busing\s+Google.Cloud.Bigtable\b', $code, CloudReady::Ident::Alias_UsingBigTable));
	# HL-959 15/10/2019 [GCP Boosters] Using Cloud Spanner
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudSpanner, $checkPattern->('\busing\s+Google.Cloud.Spanner\b', $code, CloudReady::Ident::Alias_UsingCloudSpanner));
	# HL-960 16/10/2019 [GCP Boosters] Using Cloud in-memory database (redis)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Using_InMemoryRedisGCP, $checkPattern->('\busing\s+Google.Cloud.Redis\b|\bCloudRedisClient.Create\b', $code, CloudReady::Ident::Alias_Using_InMemoryRedisGCP));
	# HL-961 17/10/2019 [GCP Boosters] Using Cloud IAM (Identity and Access Management)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudIAM, $checkPattern->('\busing\s+Google.Apis.Iam\b|\bnew\s+IamService\b', $code, CloudReady::Ident::Alias_UsingCloudIAM));
	# HL-962 18/10/2019 [GCP Boosters] Using Firebase
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingFireBase, $checkPattern->('\bFirebaseApp\.Create\b|\bFirebaseAuth\.\b(?:GetAuth|DefaultInstance)\b', $code, CloudReady::Ident::Alias_UsingFireBase));
	# HL-963 28/10/2019 [GCP Boosters] Using Cloud IAP (Identity Aware Proxy)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudIAP, $checkPattern->('\bclass\s+IAPClient\b|\biapClientId\b', $code, CloudReady::Ident::Alias_UsingCloudIAP));
	# HL-964 28/10/2019 [GCP Boosters] Using a Cloud-based Key storage (KMS)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPServicesKms, $checkPattern->('\busing\s+Google.Apis.CloudKMS\b', $code, CloudReady::Ident::Alias_GCPServicesKms));
	# HL-965 28/10/2019 [GCP Boosters] Using a Cloud-Based Storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPStorage, $checkPattern->('\busing\s+Google.Cloud.Storage\b', $code, CloudReady::Ident::Alias_GCPStorage));
	# HL-966 29/10/2019 [GCP Boosters] Using a Cloud-based task scheduling service
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPScheduler, $checkPattern->('\busing\s+Google.Apis.CloudScheduler\b|\bnew\s+CloudSchedulerService\b', $code, CloudReady::Ident::Alias_GCPScheduler));
	# HL-968 30/10/2019 [GCP Boosters] Using a Cloud-based middleware application
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudPubSub, $checkPattern->('\busing\s+Google.Cloud.PubSub\b', $code, CloudReady::Ident::Alias_UsingCloudPubSub));
	# 09/06/2020 HTTPProtocol
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HTTPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURL($fichier, $code, $HString, $techno, $text));
	# 09/06/2020 FTPProtocol
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FTPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURLProtocol($fichier, $code, $HString, 'FTP', $text));
	# 09/06/2020 LDAPProtocol
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_LDAPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURLProtocol($fichier, $code, $HString, 'LDAP', $text));
	# 10/05/2021 HL-1724
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsLambda, $checkPattern->('\busing\s+Amazon.Lambda\b|\bnew\s+AmazonLambdaClient\b', $code, CloudReady::Ident::Alias_AwsLambda));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureFunctions, $checkPattern->('\busing\s+Microsoft.Azure.Functions\b', $code, CloudReady::Ident::Alias_AzureFunctions));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPFunctions, $checkPattern->('\busing\s+(?:Google.(?:Apis|Cloud).(?:Cloud)?Functions)\b', $code, CloudReady::Ident::Alias_GCPFunctions));
	# 10/05/2021 HL-1723
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonEFS, $checkPattern->('\busing\s+Amazon.ElasticFileSystem\b|\bnew\s+AmazonElasticFileSystemClient\b', $code, CloudReady::Ident::Alias_AmazonEFS));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AWSBackup, $checkPattern->('\busing\s+Amazon.Backup\b|\bnew\s+AmazonBackupClient\b', $code, CloudReady::Ident::Alias_AWSBackup));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonS3Glacier, $checkPattern->('\busing\s+Amazon.Glacier\b|\bnew\s+AmazonGlacierClient\b', $code, CloudReady::Ident::Alias_AmazonS3Glacier));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureFiles, $checkPattern->('\busing\s+Azure.Storage.Files\b|\bnew\s+ShareFileClient\b', $code, CloudReady::Ident::Alias_AzureFiles));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureArchiveStorage, $checkPattern->('\busing\s+Microsoft.Azure.Management.RecoveryServices.Backup\b|\bnew\s+RecoveryServicesBackupManagementClient\b', $code, CloudReady::Ident::Alias_AzureArchiveStorage));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPFilestore, $checkPattern->('\busing\s+Google.Apis.CloudFilestore\b|\bnew\s+CloudFilestoreService\b', $code, CloudReady::Ident::Alias_GCPFilestore));
	# 11/05/2021 HL-1725
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsAppflow, $checkPattern->('\busing\s+Amazon.Appflow\b|\bnew\s+AmazonAppflowClient\b', $code, CloudReady::Ident::Alias_AwsAppflow));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsGlue, $checkPattern->('\busing\s+Amazon.Glue\b|\bnew\s+AmazonGlueClient\b', $code, CloudReady::Ident::Alias_AwsGlue));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureDataFactory, $checkPattern->('\busing\s+Microsoft.Azure.Management.DataFactory\b|\bnew\s+DataFactoryManagementClient\b', $code, CloudReady::Ident::Alias_AzureDataFactory));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPCloudDataFusion, $checkPattern->('\busing\s+Google.Apis.DataFusion\b|\bnew\s+DataFusionService\b', $code, CloudReady::Ident::Alias_GCPCloudDataFusion));
	# 11/05/2021 HL-1729
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsElasticLoadBalancing, $checkPattern->('\busing\s+Amazon.ElasticLoadBalancing\b|\bnew\s+AmazonElasticLoadBalancingClient\b', $code, CloudReady::Ident::Alias_AwsElasticLoadBalancing));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureLoadBalancer, $checkPattern->('\busing\s+Microsoft.Azure.Management.Network.Fluent.LoadBalancer\b|\.LoadBalancers\b', $code, CloudReady::Ident::Alias_AzureLoadBalancer));
	# 17/05/2021 HL-1726
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsCloudFormation, $checkPattern->('\busing\s+Amazon.CloudFormation\b|\bnew\s+(?:AmazonCloudFormationClient|CloudFormation)\b', $code, CloudReady::Ident::Alias_AwsCloudFormation));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsCodeBuild, $checkPattern->('\busing\s+Amazon.CodeBuild\b|\bnew\s+AmazonCodeBuildClient\b', $code, CloudReady::Ident::Alias_AwsCodeBuild));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsCodePipeline, $checkPattern->('\busing\s+Amazon.CodePipeline\b|\bnew\s+AmazonCodePipelineClient\b', $code, CloudReady::Ident::Alias_AwsCodePipeline));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsDataPipeline, $checkPattern->('\busing\s+Amazon.DataPipeline\b|\bnew\s+AmazonDataPipelineClient\b', $code, CloudReady::Ident::Alias_AwsDataPipeline));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureDeploymentManager, $checkPattern->('\busing\s+Microsoft.Azure.Management.DeploymentManager\b|\bnew\s+AzureDeploymentManagerClient\b', $code, CloudReady::Ident::Alias_AzureDeploymentManager));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzurePipeline, checkAzurePipelines($code) );
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPDeploymentManager, $checkPattern->('\busing\s+Google.Apis.DeploymentManager\b|\bnew\s+DeploymentsResource\b', $code, CloudReady::Ident::Alias_GCPDeploymentManager));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPCloudBuild, $checkPattern->('\busing\s+Google.Apis.CloudBuild\b|\bnew\s+CloudBuildService\b', $code, CloudReady::Ident::Alias_GCPCloudBuild));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPCloudComposer, $checkPattern->('\busing\s+Google.Apis.CloudComposer\b|\bnew\s+CloudComposerService\b', $code, CloudReady::Ident::Alias_GCPCloudComposer));
	# 18/05/2021 HL-1727
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsKinesis, $checkPattern->('\busing\s+Amazon.Kinesis\b|\bnew\s+AmazonKinesisClient\b', $code, CloudReady::Ident::Alias_AwsKinesis));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsEventBridge, $checkPattern->('\busing\s+Amazon.EventBridge\b|\bnew\s+AmazonEventBridgeClient\b', $code, CloudReady::Ident::Alias_AwsEventBridge));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureStreamAnalytics, $checkPattern->('\busing\s+Microsoft.Azure.Management.StreamAnalytics\b|\bnew\s+StreamAnalyticsManagementClient\b', $code, CloudReady::Ident::Alias_AzureStreamAnalytics));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureEventHub, $checkPattern->('\busing\s+Azure.Messaging.EventHubs\b|\bnew\s+EventHubProducerClient\b', $code, CloudReady::Ident::Alias_AzureEventHub));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureEventGrid, $checkPattern->('\busing\s+Microsoft.Azure.Management.EventGrid\b|\bnew\s+EventGridClient\b', $code, CloudReady::Ident::Alias_AzureEventGrid));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudDataflow, $checkPattern->('\busing\s+Google.Apis.Dataflow\b|\bnew\s+DataflowService\b', $code, CloudReady::Ident::Alias_UsingCloudDataflow));
	# 18/05/2021 HL-1730
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsCloudWatch, $checkPattern->('\busing\s+Amazon.CloudWatch\b|\bnew\s+AmazonCloudWatchClient\b', $code, CloudReady::Ident::Alias_AwsCloudWatch));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureMonitor, $checkPattern->('\busing\s+Microsoft.Azure.Management.(?:Monitor|Network.Fluent.ConnectionMonitor)\b|\bnew\s+ConnectionMonitorImpl\b', $code, CloudReady::Ident::Alias_AzureMonitor));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPCloudMonitoring, $checkPattern->('\busing\s+Google.Cloud.Monitoring\b|\bnew\s+MonitoredResource\b', $code, CloudReady::Ident::Alias_GCPCloudMonitoring));
	# HL-1751 22/06/2021
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_SensitiveDataString(), CloudReady::lib::SensitiveDataString::CountSensitiveDataString($code, $HString, $techno));
	# 28/04/2022 CloudReady improvements
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsS3Storage, $checkPattern->('\b(?:using|Imports)\s+Amazon\.S3\b|\b(?:AmazonS3Client|AmazonS3Config)\b', $code, CloudReady::Ident::Alias_AmazonawsS3Storage));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage, $checkPattern->('\busing\s+Azure.Storage(\.Blobs)?\b|\b(?:BlobClient|BlobContainerClient|GetBlobClient)\b', $code, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage));
	# 03/10/2022 Use of LDAP/AD authentication
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_ActiveDirectoryLDAP, checkActiveDirectoryLDAP($code));

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
