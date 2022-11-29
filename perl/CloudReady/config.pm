package CloudReady::config;

use strict;
use warnings;

use CloudReady::Ident;

my @TYPE_LIST = ('.Net', 'Java', 'TSql', 'Python', 'PHP', 'Typescript', 'JS', 'Cobol', 'Swift', 'Kotlin',
    'Clojure', 'CCpp', 'Scala');

our %FILE_MNEMOS = ('.Net' => [], 'Java' => [], 'TSql' => [], 'Python' => [], 'PHP' => [], 'Typescript' => [],
    'JS' => [], 'Cobol' => [], 'Swift' => [], 'Kotlin' => [], 'Clojure' => [], 'CCpp' => [], 'Scala' => []);

my @MNEMO_FILE_DB = (
    #    .Net Java
    [CloudReady::Ident::Alias_UsingSystemIO(),    [ 1,  0  ]],
    [CloudReady::Ident::Alias_FileEncrypt(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_FileDecrypt(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_GetTempPath(),   [ 1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1  ]],
    [CloudReady::Ident::Alias_UsingSystem(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_TempVarReading(),   [ 1,  1  ]],
    [CloudReady::Ident::Alias_TempVarExpanding(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_UsingSystemConfiguration(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_ConfigurationManagerAppSettings(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_UsingMicrosoftWin32(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_RegistryGetValue(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_RegistrySetValue(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_UsingMicrosoftWindowsAzureStorageTable(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_UsingStackExchangeRedis(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_UsingSystemDiagnostics(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_TraceWriteLine(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_TraceTraceError(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_TraceTraceInformation(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_TraceTraceWarning(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_UsingMicrosoftAzureKeyVault(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_IntanciatingKeyVaultClient(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_EncryptAsync(),   [ 1,  1  ]],
    [CloudReady::Ident::Alias_DecryptAsync(),   [ 1,  1  ]],
    [CloudReady::Ident::Alias_ConfigurationManagerConnectionStrings(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_UsingMicrosoftWindowsAzureJobs(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_UsingMicrosoftServiceBusMessaging(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_ImpersonationOption(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_DllImport(),   [ 1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1  ]],
    [CloudReady::Ident::Alias_UsingSystemMessaging(),   [ 1,  1  ]],
    [CloudReady::Ident::Alias_UsingRabbitMQClient(),   [ 1,  1  ]],
    [CloudReady::Ident::Alias_UsingTIBCOEMS(),   [ 1,  1  ]],
    [CloudReady::Ident::Alias_UsingIBMWMQ(),   [ 1,  1  ]],
    [CloudReady::Ident::Alias_ComImport(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_FileGetAccessControl(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_FileSetAccessControl(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_UsingSystemSecurityAccessControl(),   [ 1,  0  ]],
    # JLE 10/10/2017
    [CloudReady::Ident::Alias_Import_JavaxServletHttpHttpSession(),    [ 0,  1  ]],
    [CloudReady::Ident::Alias_HttpSession_setAttribute(),    [ 0,  1  ]],
    # JLE 18/10/2017
    [CloudReady::Ident::Alias_Spring_SessionAttribute(),   [ 0,  1  ]],
    [CloudReady::Ident::Alias_Spring_AnnotationForStatefulCompliantScopes(),   [ 0,  1  ]],
    # JLE 27/10/2017
    [CloudReady::Ident::Alias_Import_ComMicrosoftAzureBatch(),  [ 0,  1  ]],
    [CloudReady::Ident::Alias_Using_MicrosoftAzureManagementBatch(),  [ 1,  0  ]],
    [CloudReady::Ident::Alias_HardCodedConnectionString(),  [ 1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1  ]],
    [CloudReady::Ident::Alias_SQLDatabaseUnsecureAuthentication(),  [ 1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1  ]],

    [CloudReady::Ident::Alias_Import_JavaNioFileAttribute(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Implements_AclFileAtributeView(),  [ 0, 1  ]],
    # [CloudReady::Ident::Alias_Import_Tomcat(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_Jetty(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_Weblogic(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_Websphere(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_OrgApacheCommonIoFileUtils(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_DirectoryDelete_1(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_JavaIoFile(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_JavaIo(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_FileRename(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_DirectoryCreate(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_IsDirectory(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_New_File(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_ComMicrosoftAzureKeyvault(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_ComMicrosoftWindowsazureServicesServicebus(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_ComMicrosoftAzureStorageTable(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_RedisClientsJedisJedis(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_WaffleWindowsAuth(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_ComMicrosoftAzureDocumentdb(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Using_MicrosoftAzureDocuments(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_Using_SystemDataSqlClient(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_Import_ComMicrosoftAzureManagementSql(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Using_MicrosoftPracticesTransientFaultHandling(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_AzureContainerRegistry(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_AzureFunctions(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_AzureFiles(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AzureArchiveStorage(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AzureDataFactory(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AzureLoadBalancer(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AzureDeploymentManager(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AzureStreamAnalytics(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AzureEventHub(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AzureEventGrid(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AzureMonitor(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],

    [CloudReady::Ident::Alias_Import_ComAmazonawsServicesS3Model(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Using_AmazonS3Model(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_New_S3AccessControlList(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_Import_ComAmazonawsServicesSqs(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Using_AmazonDynamoDBV2(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_Using_AmazonSimpleDB(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_Using_AmazonRDS(),  [ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_Using_AmazonRedshift(),  [ 1, 0  , 0  , 0  , 0  , 0  , 0  , 0  , 0  , 1, 1  ]],
    [CloudReady::Ident::Alias_Import_ComAmazonawsServicesDynamodbv2(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_ComAmazonawsServicesSimpledb(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_ComAmazonawsServicesRds(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_ComAmazonawsServicesRedshift(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Using_AmazonKeyManagementService(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_Using_AmazonElastiCache(),  [ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_Import_ComAmazonawsServicesElasticache(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Using_AmazonCloudDirectory(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_Using_AmazonDirectoryService(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_Import_ComAmazonawsServicesCloudDirectory(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_ComAmazonawsServicesDirectory(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Using_AmazonBatch(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_Import_ComAmazonawsServicesBatch(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Import_SoftwareAmazonAwssdkServicesBatch(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Log4Net(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_AwsCloudIAM(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_AwsDataPipeline(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_AzurePipeline(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_AwsEMRBigData(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_AwsAthena(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_Elasticsearch(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_AwsLambda(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_AwsElasticContainer(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_AmazonEFS(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AWSBackup(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AmazonS3Glacier(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AwsAppflow(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AwsGlue(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AwsElasticLoadBalancing(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AwsCloudFormation(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AwsCodeBuild(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AwsCodePipeline(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AwsKinesis(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_AwsEventBridge(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AwsCloudWatch(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_AwsContainerRegistry(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_GCPCloudContainer(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1  ]],

    # TSql
    [CloudReady::Ident::Alias_fn_my_permissions(),  [ 0, 0, 1  ]],
    [CloudReady::Ident::Alias_sp_addmessage(),  [ 0, 0, 1  ]],
    [CloudReady::Ident::Alias_fn_get_sql(),  [ 0, 0, 1  ]],
    #[CloudReady::Ident::Alias_fn_virtualfilestats(),  [ 0, 0, 1  ]],
    [CloudReady::Ident::Alias_fn_virtualservernodes(),  [ 0, 0, 1  ]],
    [CloudReady::Ident::Alias_SEMANTICKEYPHRASETABLE(),  [ 0, 0, 1  ]],
    [CloudReady::Ident::Alias_OPENQUERY(),  [ 0, 0, 1  ]],
    [CloudReady::Ident::Alias_OPENROWSET(),  [ 0, 0, 1  ]],
    [CloudReady::Ident::Alias_OPENDATASOURCE(),  [ 0, 0, 1  ]],
    [CloudReady::Ident::Alias_USE_statement(),  [ 0, 0, 1  ]],
    [CloudReady::Ident::Alias_CreateCredential(),  [ 0, 0, 1  ]],
    [CloudReady::Ident::Alias_AlterDatabase(),  [ 0, 0, 1  ]],
    [CloudReady::Ident::Alias_Import_Jboss(),  [ 0, 1, 0  ]],
    [CloudReady::Ident::Alias_New_EventLog(),  [ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_New_EventLogTraceListener(),  [ 1, 0, 0  ]],
    [CloudReady::Ident::Alias_Using_SystemServiceProcess(),  [ 1, 0, 0  ]],

    [CloudReady::Ident::Alias_DirectoryCreateDirectory(),  [ 1, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_DirectoryMove(),  [ 1, 1, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_DirectoryDelete(),  [ 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_DirectoryAccess(),  [ 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_DirectoryCopy(),  [ 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_Write(),  [ 0, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_FileCreate(),  [ 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_FileDelete(),  [ 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_FileExists(),  [ 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_DBMS_DynamoDB(),  [ 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_AzureCloudEncryption(),  [ 0, 0, 0, 1, 0  ]],
    [CloudReady::Ident::Alias_Import_ComAmazonawsServicesKms(),  [ 0, 1, 0, 1, 0  ]],
    [CloudReady::Ident::Alias_Import_InMemoryRedisAzure(),  [ 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_Import_InMemoryRedisAws(),  [ 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_AzureDirectoryService(),  [ 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_AmazonawsDirectoryService(),  [ 0, 0, 0, 1, 1, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_AmazonawsBatch(),  [ 0, 0, 0, 1, 1, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_AzureBatch(),  [ 0, 0, 0, 1, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_AmazonAwsAccessManagement(),  [ 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_LaunchSubProcess(),  [ 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_DBAccessMySQL(),  [ 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_ServletPHP(),  [ 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_DbDriverDbLib(),  [ 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_SendMail(),  [ 0, 0, 0, 0, 1  ]],

    [CloudReady::Ident::Alias_New_AccessControlList(),  [ 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_UsingSystemSecurityCryptography(),  [ 1, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_DirectoryCurrent(),  [ 0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_DirectoryChange(),  [ 0, 0, 0, 1, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_Path(),  [ 0, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_DirectoryExists(),  [ 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_New_FileInputStream(),  [ 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_Open(),  [ 1, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_FileCopy(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1   ]],
    [CloudReady::Ident::Alias_FileMove(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_EnvironmentVariable(),  [ 0, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_New_Process(),  [ 1, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_CodeSkipped(),  [ 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_AmazonawsS3Storage(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_MicrosoftAzureBlobStorage(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_DBMS_MySQL(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_DBMS_PostgreSQL(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_DBMS_MongoDB(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_DBMS_CosmosDB(),  [ 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_AmazonawsServicesKms(),  [ 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_MicrosoftAzureKeyVault(),  [ 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_AwsScheduler(),  [ 0, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_AzureScheduler(),  [ 0, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_CloudActiveDirectory(),  [ 0, 0, 0, 0, 0, 1, 1, 0, 0  ]],
    [CloudReady::Ident::Alias_AzureServiceBusMessaging(),  [ 0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_Using_AmazonSQS(),  [ 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1  ]],

    # GCP
    [CloudReady::Ident::Alias_UsingKubernetes(),  [ 1, 1, 0, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_UsingBigQuery(),  [ 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_UsingCloudDataStore(),  [ 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_UsingBigTable(),  [ 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_UsingCloudSpanner(),  [ 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_Using_InMemoryRedisGCP(),  [ 1, 0, 0, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_UsingCloudIAM(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_UsingFireBase(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_UsingCloudIAP(),  [ 1, 1, 0, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_GCPServicesKms(),  [ 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_GCPStorage(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_GCPScheduler(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_UsingCloudDataflow(),  [ 1, 1, 0, 1, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_UsingCloudPubSub(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_GCPFunctions(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1   ]],
    [CloudReady::Ident::Alias_GCPFilestore(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_GCPCloudDataFusion(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_GCPLoadBalancing(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_GCPDeploymentManager(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_GCPCloudBuild(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_GCPCloudComposer(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_GCPCloudMonitoring(),  [ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0  ]],
    [CloudReady::Ident::Alias_GCPDataproc(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1  ]],

    # Mainframe COBOL
    [CloudReady::Ident::Alias_HexaConstants(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_DISPLAY_statement(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_CodeSkipped(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_ALTER_statement(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_PackedDecimal(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_Binary(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_CAPanvaletCommand(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_DLICalls(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_DoubleByteCharacter(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_GOTO_statement(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_DecimalPointComma(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_CurrencySign(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_OccurClause(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_RedefinesClause(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_DummyTable(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_JSONParsing(),  [ 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_XMLParsing(),  [ 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_JSONGenerate(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_UROption(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_SubsetRow(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_CICSWebservice(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_MQCallBatch(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_MQCall(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_DB2Connect(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_CASE_statement(),  [ 0, 0, 0, 0, 0, 0, 0, 1 ]],

    # Common idents
    [CloudReady::Ident::Alias_URINotSecuredHTTP(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_URINotSecuredFTP(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_HardCodedIP(),  [ 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_HardCodedPath(),  [ 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_HTTPProtocol(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_FTPProtocol(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_LDAPProtocol(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_InMemoryRedis(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_InMemoryMemcached(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_Kubernetes(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1   ]],
    [CloudReady::Ident::Alias_Docker(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1  ]],
    [CloudReady::Ident::Alias_Blockchain(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_DirectoryOpen(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1  ]],
    [CloudReady::Ident::Alias_DBMS_Oracle(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1   ]],
    [CloudReady::Ident::Alias_DBMS_SQLServer(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_Hadoop(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_Spark(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_Kafka(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1  ]],
    [CloudReady::Ident::Alias_FileRead(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_ApiUnsecured(),  [ 1, 0  ]],
    [CloudReady::Ident::Alias_SensitiveDataString(),  [ 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1  ]],
    [CloudReady::Ident::Alias_IdentityImpersonateTrue(),  [ 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1  ]],
    [CloudReady::Ident::Alias_ActiveDirectoryLDAP(),  [ 1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0  ]],
);


our %APPLI_MNEMOS = (".Net" => [], "Java" => [], 'TSql' => [], 'Python' => [], 'PHP' => [], 'Typescript' => [],
    'JS' => [], 'Cobol' => [], 'Swift' => [], 'Kotlin' => [], 'Clojure' => [], 'CCpp' => [], 'Scala' => []);

my @MNEMO_APPLI_DB = (
    #    .Net Java
    [CloudReady::Ident::Alias_ExtraConfFile(),   [ 1,  0  ]],
    [CloudReady::Ident::Alias_WebConfFile(),  [ 1,  0  ]],
    [CloudReady::Ident::Alias_WebConfContainsConnectionStrings(),  [ 1,  0  ]],
    [CloudReady::Ident::Alias_WebConfigAuthenticationForm(),  [ 1,  0  ]],
    [CloudReady::Ident::Alias_WebConfigAuthenticationWindows(),  [ 1,  0  ]],
    [CloudReady::Ident::Alias_WebConfigAzureWebJobs(),  [ 1,  0  ]],
    [CloudReady::Ident::Alias_WebConfigActiveDirectory(),  [ 1,  0  ]],
    [CloudReady::Ident::Alias_WebConfigIdentityImpersonateTrue(),  [ 1,  0  ]],
    [CloudReady::Ident::Alias_CsprojCOMReferenceInclude(),  [ 1,  0  ]],
    [CloudReady::Ident::Alias_WebXml(),  [ 1,  1  ]],
    [CloudReady::Ident::Alias_ExtraXmlFile(),  [ 1,  1  ]],
    [CloudReady::Ident::Alias_PomXmlAdal4jDependency(),  [ 1,  1  ]],
    [CloudReady::Ident::Alias_Spring_XmlConfForStatefulCompliantScopes(),  [ 0,  1  ]],
    [CloudReady::Ident::Alias_WeblogicConfiguration(),  [ 0,  1  ]],
    [CloudReady::Ident::Alias_WebsphereConfiguration(),  [ 0,  1  ]],
    [CloudReady::Ident::Alias_JBossConfiguration(),  [ 0,  1  ]],
    [CloudReady::Ident::Alias_JEEConfiguration(),  [ 0,  1  ]],
    [CloudReady::Ident::Alias_CDIBeansConfiguration(),  [ 0, 1, 0  ]],
    [CloudReady::Ident::Alias_Config_EventLogTraceListener(),  [ 1, 0, 0  ]],
    [CloudReady::Ident::Alias_MachineKey_ValidationKey_AutoGenerate(),  [ 1, 0, 0  ]],
    [CloudReady::Ident::Alias_Log4NetConfig(),  [ 1, 0, 0  ]],
    [CloudReady::Ident::Alias_UsingBigQuery(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_DBMS_MySQL(),  [ 0, 1, 0, 1, 1, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_DBMS_PostgreSQL(),  [ 0, 1, 0, 1, 1, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_UsingCloudDataStore(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_UsingBigTable(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_UsingCloudSpanner(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_Using_InMemoryRedisGCP(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_UsingCloudIAM(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_UsingFireBase(),  [ 1, 1  ]],
    [CloudReady::Ident::Alias_UsingCloudIAP(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_GCPServicesKms(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_UsingCloudPubSub(),  [ 0, 1  ]],
    [CloudReady::Ident::Alias_HardCodedIP(),  [ 1, 1  ]],
    [CloudReady::Ident::Alias_HardCodedPath(),  [ 1, 1  ]],
    [CloudReady::Ident::Alias_HTTPProtocol(),  [ 1, 1  ]],
    [CloudReady::Ident::Alias_FTPProtocol(),  [ 1, 1  ]],
    [CloudReady::Ident::Alias_LDAPProtocol(),  [ 1, 1  ]],
    [CloudReady::Ident::Alias_AmazonawsS3Storage(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_GCPStorage(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_DBMS_DynamoDB(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_DBMS_MongoDB(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_InMemoryRedis(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_InMemoryMemcached(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_AwsCloudIAM(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_AzureDirectoryService(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_Kubernetes(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_Docker(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_Blockchain(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_LaunchSubProcess(),  [ 0, 0, 0, 0, 0, 0, 0, 0, 1 ]],
    [CloudReady::Ident::Alias_WCFServiceWebConf(),  [ 1, 0, 0  ]],
    [CloudReady::Ident::Alias_WCFServiceAppConf(),  [ 1, 0, 0  ]],
    [CloudReady::Ident::Alias_GCPFunctions(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_AzureArchiveStorage(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_GCPFilestore(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_AzureDataFactory(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_GCPCloudDataFusion(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_AzureDeploymentManager(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_GCPDeploymentManager(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_GCPCloudBuild(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_GCPCloudComposer(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_AzureStreamAnalytics(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_AzureEventHub(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_AzureEventGrid(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_GCPCloudMonitoring(),  [ 0, 1, 0, 0, 0, 0, 0, 0, 0 ]],
    [CloudReady::Ident::Alias_DllImport(),   [ 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1  ]],
);


my %H_Techno2MnemoListID = (
    'CS'  => '.Net',
    'VbDotNet'  => '.Net',
    'Java'  => 'Java',
    'TSql'  => 'TSql',
    'Python'  => 'Python',
    'PHP'      => 'PHP',
    'Typescript' => 'Typescript',
    'JS'         => 'JS',
    'Cobol'      => 'Cobol',
    'Swift'      => 'Swift',
    'Kotlin'     => 'Kotlin',
    'Clojure'    => 'Clojure',
    'CCpp'       => 'CCpp',
    'Scala'       => 'Scala',
);

sub getFileMnemoList($) {
    my $techno = shift;

    my $MnemoListID = $H_Techno2MnemoListID{$techno};

    if (defined $MnemoListID) {
        return $FILE_MNEMOS{$MnemoListID};
    }
    else {
        print "[CloudReady::config::getFileMnemoMList] ERROR : no mnemo list for technology $techno !\n";
    }
    return [];
}

sub getAppliMnemoList($) {
    my $techno = shift;

    my $MnemoListID = $H_Techno2MnemoListID{$techno};

    if (defined $MnemoListID) {
        return $APPLI_MNEMOS{$MnemoListID};
    }
    else {
        print "[CloudReady::config::getAppliMnemoMList] ERROR : no mnemo list for technology $techno !\n";
    }
    return [];
}

# build the list of FILE mnemonics for each techno ...
#  ==> build %FILE_MNEMOS
for my $mnemoItem (@MNEMO_FILE_DB) {
    # item is a line of @MNEMO_FILE_DB
    my $mnemo = $mnemoItem->[0];
    my $technos = $mnemoItem->[1];
    for (my $i = 0; $i < scalar @$technos; $i++) {
        # if the flag is 1, then add the mnemo to the associated techno ...
        if ($technos->[$i]) {
            push @{$FILE_MNEMOS{$TYPE_LIST[$i]}}, $mnemo;
        }
    }
}

# build the list of APPLI mnemonics for each techno ...
#  ==> build %APPLI_MNEMOS
for my $mnemoItem (@MNEMO_APPLI_DB) {
    # item is a line of @MNEMO_FILE_DB
    my $mnemo = $mnemoItem->[0];
    my $technos = $mnemoItem->[1];
    for (my $i = 0; $i < scalar @$technos; $i++) {
        # if the flag is 1, then add the mnemo to the associated techno ...
        if ($technos->[$i]) {
            push @{$APPLI_MNEMOS{$TYPE_LIST[$i]}}, $mnemo;
        }
    }
}

1;
