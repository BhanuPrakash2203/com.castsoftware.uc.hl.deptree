package CloudReady::Ident;
use strict;
use warnings;

# Azure idents
sub Alias_UsingSystemIO { return 'Id_001'; }
sub Alias_FileMove { return 'Id_002'; }
sub Alias_FileCreate { return 'Id_003'; }
sub Alias_FileDelete { return 'Id_004'; }
sub Alias_FileCopy { return 'Id_005'; }
sub Alias_FileExists { return 'Id_006'; }
sub Alias_FileEncrypt { return 'Id_007'; }
sub Alias_FileDecrypt { return 'Id_008'; }
sub Alias_Open { return 'Id_009'; }
sub Alias_GetTempPath { return 'Id_010'; }
sub Alias_DirectoryCreateDirectory { return 'Id_011'; }
sub Alias_DirectoryMove { return 'Id_012'; }
sub Alias_DirectoryDelete { return 'Id_013'; }
sub Alias_DirectoryExists { return 'Id_014'; }
sub Alias_UsingSystem { return 'Id_015'; }
sub Alias_TempVarReading { return 'Id_016'; }
sub Alias_TempVarExpanding { return 'Id_017'; }
sub Alias_UsingSystemConfiguration { return 'Id_018'; }
sub Alias_ConfigurationManagerAppSettings { return 'Id_019'; }
sub Alias_UsingMicrosoftWin32 { return 'Id_020'; }
sub Alias_RegistryGetValue { return 'Id_021'; }
sub Alias_RegistrySetValue { return 'Id_022'; }
sub Alias_UsingMicrosoftWindowsAzureStorageTable { return 'Id_023'; }
sub Alias_UsingStackExchangeRedis { return 'Id_024'; }
sub Alias_UsingSystemDiagnostics { return 'Id_025'; }
sub Alias_TraceWriteLine { return 'Id_026'; }
sub Alias_TraceTraceError { return 'Id_027'; }
sub Alias_TraceTraceInformation { return 'Id_028'; }
sub Alias_TraceTraceWarning { return 'Id_029'; }
sub Alias_UsingMicrosoftAzureKeyVault { return 'Id_030'; }
sub Alias_IntanciatingKeyVaultClient { return 'Id_031'; }
sub Alias_EncryptAsync { return 'Id_032'; }
sub Alias_DecryptAsync { return 'Id_033'; }
sub Alias_ConfigurationManagerConnectionStrings { return 'Id_034'; }
sub Alias_UsingMicrosoftWindowsAzureJobs { return 'Id_035'; }
sub Alias_UsingMicrosoftServiceBusMessaging { return 'Id_036'; }
sub Alias_ImpersonationOption { return 'Id_037'; }
sub Alias_DllImport { return 'Id_038'; }
sub Alias_UsingSystemSecurityAccessControl { return 'Id_039'; }
sub Alias_FileGetAccessControl { return 'Id_040'; }
sub Alias_FileSetAccessControl { return 'Id_041'; }
sub Alias_UsingSystemMessaging { return 'Id_042'; }
sub Alias_UsingRabbitMQClient { return 'Id_043'; }
sub Alias_UsingTIBCOEMS { return 'Id_044'; }
sub Alias_UsingIBMWMQ { return 'Id_045'; }
sub Alias_ComImport { return 'Id_046'; }
sub Alias_Import_OrgApacheCommonIoFileUtils { return 'Id_048'; }
sub Alias_DirectoryDelete_1 { return 'Id_049'; }
sub Alias_DirectoryCopy { return 'Id_050'; }
sub Alias_Write { return 'Id_051'; }
sub Alias_Import_JavaIoFile { return 'Id_052'; }
sub Alias_Exists { return 'Id_053'; }
sub Alias_FileRename { return 'Id_054'; }
sub Alias_DirectoryCreate { return 'Id_055'; }
sub Alias_IsDirectory { return 'Id_056'; }
sub Alias_Import_JavaNioFileAttribute { return 'Id_058'; }
sub Alias_Implements_AclFileAtributeView { return 'Id_059'; }
sub Alias_Import_Tomcat { return 'Id_060'; }
sub Alias_Import_Jetty { return 'Id_061'; }
sub Alias_Import_Weblogic { return 'Id_062'; }
sub Alias_Import_Websphere { return 'Id_063'; }
sub Alias_UsingSystemSecurityCryptography { return 'Id_064'; }
sub Alias_Import_ComMicrosoftAzureKeyvault { return 'Id_065'; }
sub Alias_Import_ComMicrosoftWindowsazureServicesServicebus { return 'Id_066'; }
sub Alias_Import_ComMicrosoftAzureStorageTable { return 'Id_067'; }
sub Alias_Import_RedisClientsJedisJedis { return 'Id_068'; }
sub Alias_Import_WaffleWindowsAuth { return 'Id_069'; }
sub Alias_Import_ComMicrosoftAzureDocumentdb { return 'Id_107'; }
sub Alias_Using_MicrosoftAzureDocuments { return 'Id_108'; }
sub Alias_Using_MicrosoftAzureManagementBatch { return 'Id_110'; }
sub Alias_Using_SystemDataSqlClient { return 'Id_114'; }
sub Alias_Import_ComMicrosoftAzureManagementSql { return 'Id_115'; }
sub Alias_Using_MicrosoftPracticesTransientFaultHandling { return 'Id_129'; }
sub Alias_ApiUnsecured { return 'Id_258'; }
sub Alias_AzureContainerRegistry { return 'Id_214'; }
sub Alias_AzureFunctions { return 'Id_221'; }
sub Alias_AzureFiles { return 'Id_233'; }
sub Alias_AzureArchiveStorage { return 'Id_234'; }
sub Alias_AzureDataFactory { return 'Id_238'; }
sub Alias_AzureDeploymentManager { return 'Id_246'; }
sub Alias_AzurePipeline { return 'Id_211'; }
sub Alias_AzureStreamAnalytics { return 'Id_252'; }
sub Alias_AzureEventHub { return 'Id_253'; }
sub Alias_AzureEventGrid { return 'Id_254'; }
sub Alias_AzureMonitor { return 'Id_256'; }

# Amazon idents
sub Alias_Import_ComAmazonawsServicesS3Model{ return 'Id_070'; }
sub Alias_New_AccessControlList { return 'Id_071'; }
sub Alias_Using_AmazonS3Model { return 'Id_072'; }
sub Alias_New_S3AccessControlList { return 'Id_073'; }
sub Alias_Using_AmazonSQS { return 'Id_074'; }
sub Alias_Import_ComAmazonawsServicesSqs { return 'Id_075'; }
sub Alias_Using_AmazonDynamoDBV2 { return 'Id_076'; }
sub Alias_Using_AmazonSimpleDB { return 'Id_077'; }
sub Alias_Using_AmazonRDS { return 'Id_078'; }
sub Alias_Using_AmazonRedshift { return 'Id_079'; }
sub Alias_Import_ComAmazonawsServicesDynamodbv2 { return 'Id_080'; }
sub Alias_Import_ComAmazonawsServicesSimpledb { return 'Id_081'; }
sub Alias_Import_ComAmazonawsServicesRds { return 'Id_082'; }
sub Alias_Import_ComAmazonawsServicesRedshift { return 'Id_083'; }
sub Alias_Using_AmazonKeyManagementService { return 'Id_084'; }
sub Alias_Import_ComAmazonawsServicesKms { return 'Id_085'; }
sub Alias_Using_AmazonElastiCache { return 'Id_086'; }
sub Alias_Import_ComAmazonawsServicesElasticache { return 'Id_087'; }
sub Alias_Using_AmazonCloudDirectory { return 'Id_088'; }
sub Alias_Using_AmazonDirectoryService { return 'Id_089'; }
sub Alias_Import_ComAmazonawsServicesCloudDirectory { return 'Id_090'; }
sub Alias_Import_ComAmazonawsServicesDirectory { return 'Id_091'; }
sub Alias_Using_AmazonBatch { return 'Id_111'; }
sub Alias_Import_ComAmazonawsServicesBatch { return 'Id_112'; }
sub Alias_Import_SoftwareAmazonAwssdkServicesBatch { return 'Id_113'; }
sub Alias_AwsCloudIAM { return 'Id_209'; }
sub Alias_AwsDataPipeline { return 'Id_210'; }
sub Alias_AwsEMRBigData { return 'Id_215'; }
sub Alias_AwsAthena { return 'Id_218'; }
sub Alias_Elasticsearch { return 'Id_219'; }
sub Alias_AwsLambda { return 'Id_220'; }
sub Alias_AwsElasticContainer { return 'Id_225'; }
sub Alias_AmazonEFS { return 'Id_230'; }
sub Alias_AWSBackup { return 'Id_231'; }
sub Alias_AmazonS3Glacier { return 'Id_232'; }
sub Alias_AwsAppflow { return 'Id_236'; }
sub Alias_AwsGlue { return 'Id_237'; }
sub Alias_AwsElasticLoadBalancing { return 'Id_240'; }
sub Alias_AzureLoadBalancer { return 'Id_241'; }
sub Alias_AwsCloudFormation { return 'Id_243'; }
sub Alias_AwsCodeBuild { return 'Id_244'; }
sub Alias_AwsCodePipeline { return 'Id_245'; }
sub Alias_AwsKinesis { return 'Id_250'; }
sub Alias_AwsEventBridge { return 'Id_251'; }
sub Alias_AwsCloudWatch { return 'Id_255'; }
sub Alias_AwsContainerRegistry { return 'Id_262'; }
sub Alias_GCPCloudContainer { return 'Id_263'; }



# Java idents
sub Alias_Import_JavaIo { return 'Id_092'; }
sub Alias_New_File { return 'Id_093'; }
sub Alias_New_FileInputStream { return 'Id_094'; }
sub Alias_Import_JavaxServletHttpHttpSession { return 'Id_097'; }
sub Alias_HttpSession_setAttribute { return 'Id_098'; }
sub Alias_ImportJavaxEjb { return 'Id_099'; }
sub Alias_Spring_SessionAttribute { return 'Id_100'; }
sub Alias_Import_Struts2InterceptorSessionAware { return 'Id_101'; }
sub Alias_Struts2StatefulSession_SessionAware { return 'Id_102'; }
sub Alias_Import_Struts2ActionContext { return 'Id_103'; }
sub Alias_Struts2StatefulSession_ActionContext { return 'Id_104'; }
sub Alias_Spring_AnnotationForStatefulCompliantScopes { return 'Id_105'; }
sub Alias_JEE_StatefulScope { return 'Id_106'; }
sub Alias_Import_ComMicrosoftAzureBatch { return 'Id_109'; }

# .Net idents
sub Alias_HardCodedConnectionString { return 'Id_155'; }
sub Alias_SQLDatabaseUnsecureAuthentication { return 'Id_164'; }
sub Alias_Log4Net { return 'Id_120'; }

# Pivotal idents
sub Alias_Import_Jboss { return 'Id_149'; }
sub Alias_New_Process { return 'Id_166'; }
sub Alias_New_EventLog { return 'Id_167'; }
sub Alias_New_EventLogTraceListener { return 'Id_168'; }
sub Alias_Using_SystemServiceProcess { return 'Id_169'; }


# TSql idents
sub Alias_fn_my_permissions { return 'Id_130'; }
sub Alias_sp_addmessage { return 'Id_131'; }
sub Alias_fn_get_sql { return 'Id_132'; }
sub Alias_fn_virtualservernodes { return 'Id_134'; }
sub Alias_SEMANTICKEYPHRASETABLE { return 'Id_135'; }
sub Alias_OPENQUERY { return 'Id_136'; }
sub Alias_OPENROWSET { return 'Id_137'; }
sub Alias_OPENDATASOURCE { return 'Id_138'; }
sub Alias_USE_statement { return 'Id_139'; }
sub Alias_CreateCredential { return 'Id_140'; }
sub Alias_AlterDatabase { return 'Id_141'; }

#Python / PHP / Swift
sub Alias_DirectoryCurrent { return 'Id_171'; }
sub Alias_DirectoryAccess { return 'Id_172'; }
sub Alias_DirectoryChange { return 'Id_173'; }
sub Alias_EnvironmentVariable { return 'Id_174'; }
sub Alias_DBMS_CosmosDB { return 'Id_175'; }
sub Alias_DBMS_DynamoDB { return 'Id_176'; }
sub Alias_AzureCloudEncryption { return 'Id_177'; }
sub Alias_MicrosoftAzureKeyVault { return 'Id_180'; }
sub Alias_AmazonawsServicesKms { return 'Id_181'; }
sub Alias_MicrosoftAzureBlobStorage { return 'Id_182'; }
sub Alias_AmazonawsS3Storage { return 'Id_183'; }
sub Alias_AzureDirectoryService { return 'Id_184'; }
sub Alias_AmazonawsDirectoryService { return 'Id_185'; }
sub Alias_AmazonawsBatch { return 'Id_186'; }
sub Alias_AzureBatch { return 'Id_187'; }
sub Alias_AzureServiceBusMessaging { return 'Id_188'; }
sub Alias_AmazonAwsAccessManagement { return 'Id_190'; }
sub Alias_Import_InMemoryRedisAzure  { return 'Id_122'; }
sub Alias_Import_InMemoryRedisAws { return 'Id_123'; }
sub Alias_LaunchSubProcess { return 'Id_170'; }
sub Alias_DBAccessMySQL { return 'Id_179'; }
sub Alias_ServletPHP { return 'Id_261'; }
sub Alias_DbDriverDbLib { return 'Id_266'; }
sub Alias_SendMail { return 'Id_267'; }

# GCP
sub Alias_UsingKubernetes { return 'Id_259'; }
sub Alias_UsingBigQuery { return 'Id_119'; }
sub Alias_UsingCloudDataStore { return 'Id_121'; }
sub Alias_UsingBigTable { return 'Id_133'; }
sub Alias_UsingCloudSpanner { return 'Id_142'; }
sub Alias_Using_InMemoryRedisGCP { return 'Id_143'; }
sub Alias_UsingCloudIAM { return 'Id_144'; }
sub Alias_UsingFireBase { return 'Id_145'; }
sub Alias_UsingCloudIAP { return 'Id_146'; }
sub Alias_GCPServicesKms { return 'Id_147'; }
sub Alias_GCPStorage { return 'Id_148'; }
sub Alias_GCPScheduler { return 'Id_150'; }
sub Alias_UsingCloudDataflow { return 'Id_151'; }
sub Alias_UsingCloudPubSub { return 'Id_152'; }
sub Alias_GCPFunctions { return 'Id_222'; }
sub Alias_GCPFilestore { return 'Id_235'; }
sub Alias_GCPCloudDataFusion { return 'Id_239'; }
sub Alias_GCPLoadBalancing { return 'Id_242'; }
sub Alias_GCPDeploymentManager { return 'Id_247'; }
sub Alias_GCPCloudBuild { return 'Id_248'; }
sub Alias_GCPCloudComposer { return 'Id_249'; }
sub Alias_GCPCloudMonitoring { return 'Id_257'; }

# Typescript / NodeJS
sub Alias_Path { return 'Id_124'; }
sub Alias_CodeSkipped { return 'Id_125'; }
sub Alias_AwsScheduler { return 'Id_191'; }
sub Alias_AzureScheduler { return 'Id_192'; }
sub Alias_CloudActiveDirectory { return 'Id_116'; }

# mainframe COBOL
sub Alias_HexaConstants { return 'Id_153'; }
sub Alias_DISPLAY_statement { return 'Id_154'; }
sub Alias_ALTER_statement { return 'Id_156'; }
sub Alias_PackedDecimal { return 'Id_157'; }
sub Alias_Binary { return 'Id_158'; }
sub Alias_CAPanvaletCommand { return 'Id_159'; }
sub Alias_DLICalls { return 'Id_160'; }
sub Alias_DoubleByteCharacter { return 'Id_161'; }
sub Alias_GOTO_statement { return 'Id_162'; }
sub Alias_DecimalPointComma { return 'Id_163'; }
sub Alias_CurrencySign { return 'Id_165'; }
sub Alias_OccurClause { return 'Id_178'; }
sub Alias_RedefinesClause { return 'Id_193'; }
sub Alias_DummyTable { return 'Id_194'; }
sub Alias_JSONParsing { return 'Id_195'; }
sub Alias_XMLParsing { return 'Id_196'; }
sub Alias_JSONGenerate { return 'Id_197'; }
sub Alias_UROption { return 'Id_198'; }
sub Alias_SubsetRow { return 'Id_199'; }
sub Alias_CICSWebservice { return 'Id_200'; }
sub Alias_MQCallBatch { return 'Id_201'; }
sub Alias_MQCall { return 'Id_202'; }
sub Alias_DB2Connect { return 'Id_203'; }
sub Alias_CASE_statement { return 'Id_204'; }

# Common idents
sub Alias_HTTPProtocol { return 'Id_189'; }
sub Alias_FTPProtocol { return 'Id_205'; }
sub Alias_LDAPProtocol { return 'Id_206'; }
sub Alias_URINotSecured { return 'Id_095'; } # mnemo splitted: ID reserved for portal
sub Alias_URINotSecuredHTTP { return 'Id_117'; }
sub Alias_URINotSecuredFTP { return 'Id_118'; }
sub Alias_HardCodedIP { return 'Id_096'; }
sub Alias_HardCodedPath { return 'Id_057'; }
sub Alias_InMemoryRedis { return 'Id_207'; }
sub Alias_InMemoryMemcached { return 'Id_208'; }
sub Alias_Kubernetes { return 'Id_212'; }
sub Alias_Docker { return 'Id_213'; }
sub Alias_Blockchain { return 'Id_216'; }
sub Alias_DirectoryOpen { return 'Id_217'; }
sub Alias_DBMS_MySQL { return 'Id_126'; }
sub Alias_DBMS_PostgreSQL { return 'Id_127'; }
sub Alias_DBMS_MongoDB { return 'Id_128'; }
sub Alias_DBMS_Oracle { return 'Id_223'; }
sub Alias_DBMS_SQLServer { return 'Id_224'; }
sub Alias_Hadoop { return 'Id_226'; }
sub Alias_Spark { return 'Id_227'; }
sub Alias_Kafka { return 'Id_228'; }
sub Alias_FileRead { return 'Id_229'; }
sub Alias_SensitiveDataString { return 'Id_260'; }
sub Alias_GCPDataproc  { return 'Id_264'; }
sub Alias_IdentityImpersonateTrue { return 'Id_265'; }
sub Alias_ActiveDirectoryLDAP { return 'Id_268'; }

sub Alias_ExtraConfFile { return 'Id_1000'; }
sub Alias_WebConfFile { return 'Id_1001'; }
sub Alias_WebConfContainsConnectionStrings { return 'Id_1002'; }
sub Alias_WebConfigAuthenticationForm { return 'Id_1003'; }
sub Alias_WebConfigAuthenticationWindows { return 'Id_1004'; }
sub Alias_WebConfigActiveDirectory { return 'Id_1005'; }
sub Alias_WebConfigAzureWebJobs { return 'Id_1006'; }
sub Alias_WebConfigIdentityImpersonateTrue { return 'Id_1007'; }
sub Alias_CsprojCOMReferenceInclude { return 'Id_1008'; }
sub Alias_WebXml { return 'Id_1009'; }
sub Alias_ExtraXmlFile { return 'Id_1010'; }
sub Alias_PomXmlAdal4jDependency { return 'Id_1011'; }
sub Alias_Spring_XmlConfForStatefulCompliantScopes { return 'Id_1012'; }
sub Alias_Log4NetConfig  { return 'Id_1013'; }
sub Alias_WCFService { return 'Id_1014'; } # mnemo splitted: ID reserved for portal
sub Alias_WeblogicConfiguration { return 'Id_1015'; }
sub Alias_WebsphereConfiguration { return 'Id_1016'; }
sub Alias_JBossConfiguration { return 'Id_1017'; }
sub Alias_JEEConfiguration { return 'Id_1018'; }
sub Alias_CDIBeansConfiguration { return 'Id_1019'; }
sub Alias_Config_EventLogTraceListener { return 'Id_1020'; }
sub Alias_MachineKey_ValidationKey_AutoGenerate { return 'Id_1021'; }
sub Alias_WCFServiceWebConf { return 'Id_1022'; }
sub Alias_WCFServiceAppConf { return 'Id_1023'; }


1;
