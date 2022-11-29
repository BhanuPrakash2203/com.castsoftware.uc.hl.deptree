package CloudReady::CountJava;

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
use CloudReady::lib::ElaborateLog;
use Lib::SHA;

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
	#return () = ($$code =~ /$reg/gm);
}

sub checkVarTEMP($$$) {
	my $code = shift;
	my $HString = shift;
	my $mnemo = shift;

	my $nb_get = 0;
	my $nb_expand = 0;
	
	while ($$code =~ /\bSystem\.getenv\s*\(\s*(CHAINE_\d+)/sg) {
		my $string_value = $HString->{$1};

		if (($string_value eq '"TMP"') || ($string_value eq "'TMP'")) {
			$nb_get++;
			my $reg = qr/\bSystem\.getenv\s*\(\s*(CHAINE_\d+)/;
			CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $reg, $mnemo, $rulesDescription);
#print "--> GETTING TEMP VAR !!!\n"
		}
	}
	return $nb_get;
}


# JLE 11/10/2017 detection methode HTTP session setAttribute or putValue
sub checkHttpSession_setAttribute($$)
{
	my $code = shift;
	my $mnemoID = shift;

    my $objHttpSession;
    my $nb_HttpSession=0;
	my $numline = 0;
    while ($$code =~ /(\n)|([\w()]+)\s* \.\s* (?: setAttribute | putValue )\s*\( /xgm)
    {
		if (defined $1) {
			$numline++;
		}
		else {
			$objHttpSession = $2;

			if ($objHttpSession =~ /getSession/) {
				# print 'gs'."$objHttpSession\n";
				$nb_HttpSession++;
				# my $regexLabel = '(([\w()]+)\s*\.\s*(?:setAttribute|putValue)\s*\() AND ($1 =~ getSession)';
				CloudReady::lib::ElaborateLog::SimpleElaborateLog($code, $numline, $mnemoID, $rulesDescription, "Use_Stateful_Session");
			}
			else {
				if ($$code =~ /httpsession\s+$objHttpSession/ixm) {
					# print 'objet session '."$objHttpSession\n";
					$nb_HttpSession++;
					# my $regexLabel = '(([\w()]+)\s*\.\s*(?:setAttribute|putValue)\s*\() AND (httpsession\s+$1)';
					CloudReady::lib::ElaborateLog::SimpleElaborateLog($code, $numline, $mnemoID, $rulesDescription, "Use_Stateful_Session");
				}
			}
		}
    }

	return $nb_HttpSession;
}

sub catchContentInstruction
{
	my $code = shift;
    my $content;
    
    my $re = qr/ (           # groupe #1
               \{             # accolade ouvrante
                    (?:
                          (?> [^\{}]+ )    # groupe sans retour arrière
                      |
                          (?1)            # groupe avec accolade 
                    )*
                \}             # accolade fermante
            )
              /x;

    # capture le contenu de la classe entre accolades
   
    if ( $$code =~ /\G\s*$re/gc )
    {
        $content = $1;
        # print 'contenu capture'."\n";
    }    
    
    return \$content;
}

sub checkSpringScopes($$$$) {
	my $code = shift;
	my $HString = shift;
	my $text = shift;
	my $mnemo = shift;
	my $nb = 0;
	
	if ($$code =~ /\@(?:Global)?SessionScope\b/) {
		$nb++;
		my $reg = '\@(?:Global)?SessionScope\b';
		CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $reg, $mnemo, $rulesDescription);
	}
	# @Scope(CHAINE_xxx)
	# @Scope(value = <scope>, ...)
	# 	<scope> = "session", "GlobalSession", xxx.SCOPE_SESSION, xxx.SCOPE_GLOBAL_SESSION
	#	NOTE : the value attribute can by names "scopeName" : @Scope(scopeName = ...)
	elsif ($$code =~ /\@Scope\s*\(\s*/g) {
		if ($$code =~ /\G(CHAINE_\d+)/gc) {
			my $match = $1;
			if ($HString->{$match} =~ /["'](?:session|globalSession)["']/) {
				$nb++;
				my $string = quotemeta($HString->{$match});
				my $regex = qr/$string/;
				CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, $mnemo, $rulesDescription);
			}
		}
		elsif ($$code =~ /\G([^\)]+)/gc) {
			my $item = $1;
			if ($item =~ /(?:value|scopeName)\s*=\s*(?:(CHAINE_\d+)|[\w\.]*(\bSCOPE_(?:GLOBAL_)?SESSION\b))/) {
				if (defined $1) {
					my $match = $1;
					if ($HString->{$match} =~ /["'](?:session|globalSession)["']/) {
						$nb++;
						my $string = quotemeta($HString->{$match});
						my $regex = qr/$string/;
						CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, $mnemo, $rulesDescription);
					}
				}
				else {
					$nb++;
					# my $regexLabel = '(\G([^\)]+) AND ((?:value|scopeName)\s*=\s*(?:(CHAINE_\d+)|[\w\.]*(\bSCOPE_(?:GLOBAL_)?SESSION\b)))';
					CloudReady::lib::ElaborateLog::SimpleElaborateLog($code, 1, $mnemo, $rulesDescription, "Use_Stateful_Session_Spring");
				}
			}
		}
	}
	pos($$code)=undef;
	return $nb;
}

sub checkDBMSMySQL($$$) {
	my $code = shift;
	my $HString = shift;
	my $mnemo = shift;
	my $nb_DBMSMySQL = 0;

	if ($$code =~ /\bimport\s+java\.sql\b/) {
		if ($$code =~ /\bDriverManager\s*.\s*getConnection\s*\(/) {
			if (oneStringContains($HString, qr/\bjdbc:mysql\b/)) {
				#$nb_DBMSMySQL = 1;
				# my $regexLabel = '(\bimport\s+java\.sql\b) AND (\bDriverManager\s*.\s*getConnection\s*\() AND (\bjdbc:mysql\b)';
				my $regex = qr /\bimport\s+java\.sql\b/;
				$nb_DBMSMySQL = CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
			}
		}
	}

	return $nb_DBMSMySQL;

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

sub checkDBMSPostgreSQL($$$) {
	my $code = shift;
	my $HString = shift;
	my $mnemo = shift;
	my $nb_DBMSPostgreSQL = 0;

	if ($$code =~ /\bimport\s+java\.sql\b/) {
		if ($$code =~ /\bDriverManager\s*.\s*getConnection\s*\(/) {
			if (oneStringContains($HString, qr/\bjdbc:postgresql\b/)) {
				#$nb_DBMSPostgreSQL = 1;
				# my $regexLabel = '(\bimport\s+java\.sql\b) AND (\bDriverManager\s*.\s*getConnection\s*\() AND (\bjdbc:postgresql\b)';
				my $regex = qr /\bimport\s+java\.sql\b/;
				$nb_DBMSPostgreSQL = CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, $regex, $mnemo, $rulesDescription);
			}
		}
	}

	return $nb_DBMSPostgreSQL;
}

sub checkAzurePipelines($$) {
	my $code = shift;
	my $mnemo = shift;

	my $nb_AzurePipelines = 0;

	if ($$code =~ /\bimport\s+com\.azure\.resourcemanager\.datafactory\b/) {
		if ($$code =~ /\bPipelines\b/) {
			$nb_AzurePipelines++;
			CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, qr/\bimport\s+com\.azure\.resourcemanager\.datafactory\b/, $mnemo, $rulesDescription);
		}
	}

	return $nb_AzurePipelines;
}

sub checkGCPDataFlow($$) {
	my $code = shift;
	my $mnemo = shift;

	my $nb_GCPDataFlow = 0;

	if ($$code =~ /\bimport\s+org\.apache\.beam\.runners\.dataflow\b/) {
		if ($$code =~ /\bnew\s+DataflowClient\b/) {
			$nb_GCPDataFlow++;
			CloudReady::lib::ElaborateLog::ElaborateLogPartOne($code, qr/\bimport\s+org\.apache\.beam\.runners\.dataflow\b/, $mnemo, $rulesDescription);
		}
	}

	return $nb_GCPDataFlow;
}

sub CountJava($$$) {
	my ($fichier, $vue, $compteurs, $techno) = @_ ;
	my $ret = 0;
	
	my $code;
	my $HString;
	my $text;
    my $MixBloc;
	my $checkPattern = \&checkPatternSensitive;
	
	$code = \$vue->{'code_with_prepro'};
	$text = \$vue->{'text'};
	$HString = $vue->{'HString'};
    $MixBloc = \$vue->{'MixBloc'};
	$binaryView = $vue->{'bin'};
	$aggloView = $vue->{'agglo'};
	$binaryView = $vue->{'bin'};

	$rulesDescription = CloudReady::lib::ElaborateLog::keepPortalData();

	if ((! defined $code ) || (!defined $$code)) {
		#$ret |= Couples::counter_add($compteurs, $MissingJSPComment__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_JavaNioFileAttribute(), $checkPattern->(qr/\bimport\s+java\.nio\.file\.attribute\b/, $code, CloudReady::Ident::Alias_Import_JavaNioFileAttribute));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Implements_AclFileAtributeView(), $checkPattern->(qr/\bimplements\s+AclFileAtributeView\b/, $code, CloudReady::Ident::Alias_Implements_AclFileAtributeView));
	#CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_Tomcat(), $checkPattern->(qr/\bimport\s+Tomcat\./, $code));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_Jetty(), $checkPattern->(qr/\bimport\s+org\.eclipse\.jetty\./, $code, CloudReady::Ident::Alias_Import_Jetty));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_Weblogic(), $checkPattern->(qr/\bimport\s+weblogic\./, $code, CloudReady::Ident::Alias_Import_Weblogic));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_Websphere(), $checkPattern->(qr/\bimport\s+com\.ibm\.(?:websphere|ws|wsspi)\./, $code, CloudReady::Ident::Alias_Import_Websphere));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingSystemMessaging(), $checkPattern->(qr/\bimport\s+ionic\.Msmq\b/, $code, CloudReady::Ident::Alias_UsingSystemMessaging));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingRabbitMQClient(), $checkPattern->(qr/\bimport\s+com\.rabbitmq\b/, $code, CloudReady::Ident::Alias_UsingRabbitMQClient));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingTIBCOEMS(), $checkPattern->(qr/\bimport\s+com\.tibco\.tibjms\b/, $code, CloudReady::Ident::Alias_UsingTIBCOEMS));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingIBMWMQ(), $checkPattern->(qr/\bimport\s+com\.ibm\.mq\.jms\b/, $code, CloudReady::Ident::Alias_UsingIBMWMQ));
	
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_OrgApacheCommonIoFileUtils(), $checkPattern->(qr/\bimport\s+org\.apache\.commons\.io\.FileUtils\b/, $code, CloudReady::Ident::Alias_Import_OrgApacheCommonIoFileUtils));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileMove(), $checkPattern->(qr/\.(?:moveFile|moveFileToDirectory|moveToDirectory)\s*\(/, $code, CloudReady::Ident::Alias_FileMove));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryMove(), $checkPattern->(qr/\.(?:moveDirectory|moveDirectoryToDirectory)\s*\(/, $code, CloudReady::Ident::Alias_DirectoryMove));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileDelete(), $checkPattern->(qr/\.(?:forceDelete(?:OnExit)?|deleteQuietly)\s*\(/, $code, CloudReady::Ident::Alias_FileDelete));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryDelete_1(), $checkPattern->(qr/\.deleteDirectory\s*\(/, $code, CloudReady::Ident::Alias_DirectoryDelete_1));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCopy(), $checkPattern->(qr/\.(?:copyFile|copyFileToDirectory)\s*\(/, $code, CloudReady::Ident::Alias_FileCopy));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCopy(), $checkPattern->(qr/\.(?:copyDirectory|copyDirectoryToDirectory)\s*\(/, $code, CloudReady::Ident::Alias_DirectoryCopy));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Write(), $checkPattern->(qr/\.(?:write|writeByteArrayToFile|writeLines|writeStringToFile)\s*\(/, $code, CloudReady::Ident::Alias_Write));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_File(), $checkPattern->(qr/\bnew\s+File\s*\(/, $code, CloudReady::Ident::Alias_New_File));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_FileInputStream(), $checkPattern->(qr/\bnew\s+FileInputStream\s*\(/, $code, CloudReady::Ident::Alias_New_FileInputStream));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_JavaIoFile(), $checkPattern->(qr/\bimport\s+java\.io\.File\b/, $code, CloudReady::Ident::Alias_Import_JavaIoFile));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_JavaIo(), $checkPattern->(qr/\bimport\s+java\.io\.\*/, $code, CloudReady::Ident::Alias_Import_JavaIo));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileCreate(), $checkPattern->(qr/\.createNewFile\s*\(/, $code, CloudReady::Ident::Alias_FileCreate));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FileRename(), $checkPattern->(qr/\.renameTo\s*\(/, $code, CloudReady::Ident::Alias_FileRename));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryCreate(), $checkPattern->(qr/\.mkdirs?\s*\(/, $code, CloudReady::Ident::Alias_DirectoryCreate));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_IsDirectory(), $checkPattern->(qr/\.isDirectory\s*\(/, $code, CloudReady::Ident::Alias_IsDirectory));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DirectoryDelete(), $checkPattern->(qr/\.delete\s*\(/, $code, CloudReady::Ident::Alias_DirectoryDelete));
	
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComMicrosoftAzureKeyvault(), $checkPattern->(qr/\bimport\s+com\.microsoft\.azure\.keyvault\b/, $code, CloudReady::Ident::Alias_Import_ComMicrosoftAzureKeyvault));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DecryptAsync(), $checkPattern->(qr/\.decryptAsync\s*\(/, $code, CloudReady::Ident::Alias_DecryptAsync));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_EncryptAsync(), $checkPattern->(qr/\.encryptAsync\s*\(/, $code, CloudReady::Ident::Alias_EncryptAsync));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComMicrosoftWindowsazureServicesServicebus(), $checkPattern->(qr/\bimport\s+com\.microsoft\.windowsazure\.services\.servicebus\b/, $code, CloudReady::Ident::Alias_Import_ComMicrosoftWindowsazureServicesServicebus));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComMicrosoftAzureStorageTable(), $checkPattern->(qr/\bimport\s+com\.microsoft\.azure\.storage\.table\b/, $code, CloudReady::Ident::Alias_Import_ComMicrosoftAzureStorageTable));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_RedisClientsJedisJedis(), $checkPattern->(qr/\bimport\s+redis\.clients\.jedis\.Jedis\b/, $code, CloudReady::Ident::Alias_Import_RedisClientsJedisJedis));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_WaffleWindowsAuth(), $checkPattern->(qr/\bimport\s+waffle\.windows\.auth\b/, $code, CloudReady::Ident::Alias_Import_WaffleWindowsAuth));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComMicrosoftAzureDocumentdb(), $checkPattern->(qr/\bimport\s+com\.microsoft\.azure\.documentdb\b/, $code, CloudReady::Ident::Alias_Import_ComMicrosoftAzureDocumentdb));
	
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_TempVarReading(), checkVarTEMP($code, $HString, CloudReady::Ident::Alias_TempVarReading));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedPath(), CloudReady::lib::HardCodedPath::checkHardCodedPath($HString, $techno, $code, $text));
	#JLE 05/10/2017 ajout detection URI et IP HL-247 et HL-248
    #HL-608 BUG Fix HL-247 unsecured URL without XML namespace context
	#HL-870 21/05/2019 Split FTP/HTTP CloudReady pattern in 2 separate patterns
	CloudReady::lib::URINotSecured::checkURINotSecured($fichier, $code, $HString, $techno, $text);
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HardCodedIP(), CloudReady::lib::HardCodedIP::checkHardCodedIP($HString, $code, $techno, $text));
 	#JLE 10/10/2017 ajout detection servlet java httpsession HL-250
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_JavaxServletHttpHttpSession(), $checkPattern->(qr/import\s+javax\.servlet\.http\.(HttpSession|\*)\s*\;/ , $code, CloudReady::Ident::Alias_Import_JavaxServletHttpHttpSession) );
 	#JLE 11/10/2017 ajout detection java method httpsession HL-250
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HttpSession_setAttribute(), checkHttpSession_setAttribute($code, CloudReady::Ident::Alias_HttpSession_setAttribute) );
    #JLE 18/10/2017 ajout detection SPRING annotation SessionAttributes HL-251
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Spring_SessionAttribute(), $checkPattern->(qr/\@SessionAttributes\b/ , $code, CloudReady::Ident::Alias_Spring_SessionAttribute) );
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Spring_AnnotationForStatefulCompliantScopes(), checkSpringScopes($code, $HString, $text, CloudReady::Ident::Alias_Spring_AnnotationForStatefulCompliantScopes));
    #JLE 27/10/2017 detect usage of azure batch HL-273
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComMicrosoftAzureBatch(), $checkPattern->(qr/import\s+com\.microsoft\.azure\.batch\b/ , $code, CloudReady::Ident::Alias_Import_ComMicrosoftAzureBatch) );
    # JLE 30/10/2017 detect usage of AWS batch HL-274
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComAmazonawsServicesBatch(), $checkPattern->(qr/\bcom\.amazonaws\.services\.batch\b/ , $code, CloudReady::Ident::Alias_Import_ComAmazonawsServicesBatch) );
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_SoftwareAmazonAwssdkServicesBatch(), $checkPattern->(qr/\bsoftware\.amazon\.awssdk\.services\.batch\b/ , $code, CloudReady::Ident::Alias_Import_SoftwareAmazonAwssdkServicesBatch) );
    # JLE 30/10/2017 Detect Usage of Azure SQL Data Warehouse HL-277
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComMicrosoftAzureManagementSql(), $checkPattern->(qr/\bimport\s+com\.microsoft\.azure\.management\.sql\b/ , $code, CloudReady::Ident::Alias_Import_ComMicrosoftAzureManagementSql) );
    # 11/12/17 HL-372 Azure MySQL Cloud migration
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MySQL(), checkDBMSMySQL($code, $HString, CloudReady::Ident::Alias_DBMS_MySQL) );
    # 12/12/17 HL-371 Azure PostgreSQL Cloud migration
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_PostgreSQL(), checkDBMSPostgreSQL($code, $HString, CloudReady::Ident::Alias_DBMS_PostgreSQL) );
    # 14/12/17 HL-370 Azure MongoDB Cloud migration
    #CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MongoDB(), checkDBMSMongoDB($code) );
    CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_DBMS_MongoDB(), $checkPattern->(qr/import\s+com\.mongodb\b/ , $code, CloudReady::Ident::Alias_DBMS_MongoDB) );

	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComAmazonawsServicesS3Model(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.s3\.model\b/, $code, CloudReady::Ident::Alias_Import_ComAmazonawsServicesS3Model));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComAmazonawsServicesSqs(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.sqs\b/, $code, CloudReady::Ident::Alias_Import_ComAmazonawsServicesSqs));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComAmazonawsServicesDynamodbv2(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.dynamodbv2\b/, $code, CloudReady::Ident::Alias_Import_ComAmazonawsServicesDynamodbv2));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComAmazonawsServicesSimpledb(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.simpledb\b/, $code, CloudReady::Ident::Alias_Import_ComAmazonawsServicesSimpledb));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComAmazonawsServicesRds(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.rds\b/, $code, CloudReady::Ident::Alias_Import_ComAmazonawsServicesRds));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComAmazonawsServicesRedshift(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.redshift\b/, $code, CloudReady::Ident::Alias_Import_ComAmazonawsServicesRedshift));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComAmazonawsServicesKms(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.kms\b/, $code, CloudReady::Ident::Alias_Import_ComAmazonawsServicesKms));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComAmazonawsServicesElasticache(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.elasticache\b/, $code, CloudReady::Ident::Alias_Import_ComAmazonawsServicesElasticache));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComAmazonawsServicesCloudDirectory(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.clouddirectory\b/, $code, CloudReady::Ident::Alias_Import_ComAmazonawsServicesCloudDirectory));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_ComAmazonawsServicesDirectory(), $checkPattern->(qr/\bimport\s+com\.amazonaws\.services\.directory\b/, $code, CloudReady::Ident::Alias_Import_ComAmazonawsServicesDirectory));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_New_AccessControlList(), $checkPattern->(qr/\bnew\s+AccessControlList\(/, $code, CloudReady::Ident::Alias_New_AccessControlList));
    # 12/02/18 HL-466 local files system access
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_Import_Jboss(), $checkPattern->(qr/\bimport\s+org\.jboss\./, $code, CloudReady::Ident::Alias_Import_Jboss));
	# 17/09/2019 HL-952 [GCP Boosters] Using Kubernetes
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingKubernetes(), $checkPattern->(qr/\bimport\s+io\.kubernetes\.client\b/, $code, CloudReady::Ident::Alias_UsingKubernetes));
	# HL-961 17/10/2019 [GCP Boosters] Using Cloud IAM (Identity and Access Management)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudIAM(), $checkPattern->(qr/\bimport\s+com\.google\.api\.services\.iam\b|\bnew\s+Iam\.Builder\b/, $code, CloudReady::Ident::Alias_UsingCloudIAM));
	# HL-962 18/10/2019 [GCP Boosters] Using Firebase
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingFireBase(), $checkPattern->(qr/\bFirebaseApp\.initializeApp\b|\bnew\s+FirebaseOptions\.Builder\b|\b(?:FirebaseAuth|FirebaseDatabase)\.getInstance\b/, $code, CloudReady::Ident::Alias_UsingFireBase));
	# HL-963 28/10/2019 [GCP Boosters] Using Cloud IAP (Identity Aware Proxy)
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudIAP(), $checkPattern->(qr/\bclass\s+BuildIapRequest\b|\biapClientId\b/, $code, CloudReady::Ident::Alias_UsingCloudIAP));
	# HL-965 28/10/2019 [GCP Boosters] Using a Cloud-Based Storage
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPStorage(), $checkPattern->(qr/\bimport\s+com\.google\.cloud\.storage\b/, $code, CloudReady::Ident::Alias_GCPStorage));
	# HL-966 29/10/2019 [GCP Boosters] Using a Cloud-based task scheduling service
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPScheduler(), $checkPattern->(qr/\bimport\s+com\.google\.api\.services\.cloudscheduler\b/, $code, CloudReady::Ident::Alias_GCPScheduler));
	# HL-967 29/10/2019 [GCP Boosters] Using a Cloud-based Stream and Batch data processing
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudDataflow(), checkGCPDataFlow($code, CloudReady::Ident::Alias_UsingCloudDataflow) );
	# HL-968 30/10/2019 [GCP Boosters] Using a Cloud-based middleware application
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_UsingCloudPubSub(), $checkPattern->(qr/\bimport\s+com\.google(?:\.cloud)?\.pubsub\b/, $code, CloudReady::Ident::Alias_UsingCloudPubSub));
	# 09/06/2020 HTTPProtocol
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_HTTPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURL($fichier, $code, $HString, $techno, $text));
	# 09/06/2020 FTPProtocol
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_FTPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURLProtocol($fichier, $code, $HString, 'FTP', $text));
	# 09/06/2020 LDAPProtocol
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_LDAPProtocol(), CloudReady::lib::HardCodedURL::checkHardCodedURLProtocol($fichier, $code, $HString, 'LDAP', $text));
	# 10/05/2021 HL-1724
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsLambda(), $checkPattern->(qr/\bimport\s+(?:com\.amazonaws\.services\.lambda|software\.amazon\.awssdk\.services\.lambda)\b|\bnew\s+(?:AWSLambdaClient|AWSLambdaAsyncClient)\b|\bLambdaClient\b/, $code, CloudReady::Ident::Alias_AwsLambda));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureFunctions(), $checkPattern->(qr/\bimport\s+com\.microsoft\.azure\.functions\b/, $code, CloudReady::Ident::Alias_AzureFunctions));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPFunctions(), $checkPattern->(qr/\bimport\s+com\.google\.api\.services\.cloudfunctions\b/, $code, CloudReady::Ident::Alias_GCPFunctions));
	# 10/05/2021 HL-1723
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonEFS(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.efs\b|com\.amazonaws\.services\.elasticfilesystem\b)|\bnew\s+AmazonElasticFileSystemClientBuilder\b|\bEfsClient\b/, $code, CloudReady::Ident::Alias_AmazonEFS));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AWSBackup(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.backup\b|com\.amazonaws\.services\.backup\b)|\bnew\s+AWSBackupClient\b|\bBackupClient\b/, $code, CloudReady::Ident::Alias_AWSBackup));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonS3Glacier(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.glacier\b|com\.amazonaws\.services\.glacier\b)|\bnew\s+AmazonGlacierClient\b|\bGlacierClient\b/, $code, CloudReady::Ident::Alias_AmazonS3Glacier));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureFiles(), $checkPattern->(qr/\bimport\s+com\.azure\.storage\.file\b|\bnew\s+CloudFileClient\b|\bCreateCloudFileClient\b/i, $code, CloudReady::Ident::Alias_AzureFiles));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureArchiveStorage(), $checkPattern->(qr/\bimport\s+Microsoft\.Azure\.Management\.RecoveryServices\.Backup\b|\bnew\s+(?:RecoveryServicesBackupManagementClient|RecoveryServicesClient)\b/i, $code, CloudReady::Ident::Alias_AzureArchiveStorage));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPFilestore(), $checkPattern->(qr/\bimport\s+com\.google\.api\.services\.file\.[0-9\w*.-]+\.CloudFilestore\b|\bnew\s+(?:CloudFilestore|CloudFilestoreRequestInitializer)\b/, $code, CloudReady::Ident::Alias_GCPFilestore));
	# 11/05/2021 HL-1725
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsAppflow(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.appflow\b|com\.amazonaws\.services\.appflow\b)|\bAppflowClient\b/, $code, CloudReady::Ident::Alias_AwsAppflow));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsGlue(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.glue\b|com\.amazonaws\.services\.glue\b)|\bnew\s+AWSGlueClient(?:Builder)?\b|\bGlueClient\b/, $code, CloudReady::Ident::Alias_AwsGlue));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureDataFactory(), $checkPattern->(qr/\bimport\s+com\.azure\.resourcemanager\.datafactory\b|\bnew\s+DataFactoryManager\b/, $code, CloudReady::Ident::Alias_AzureDataFactory));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPCloudDataFusion(), $checkPattern->(qr/\bimport\s+com\.google\.api\.services\.datafusion\b|\bnew\s+DataFusion\b/, $code, CloudReady::Ident::Alias_GCPCloudDataFusion));
	# 11/05/2021 HL-1729
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsElasticLoadBalancing(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.elasticloadbalancing\b|com\.amazonaws\.services\.elasticloadbalancing\b)|\bnew\s+AmazonElasticLoadBalancingClient\b|\bElasticLoadBalancingClient\b/, $code, CloudReady::Ident::Alias_AwsElasticLoadBalancing));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureLoadBalancer(), $checkPattern->(qr/\bimport\s+com\.microsoft\.azure\.management\.network\.LoadBalancers\b|(?<!\.)\bLoadBalancers\b/, $code, CloudReady::Ident::Alias_AzureLoadBalancer));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPLoadBalancing(), $checkPattern->(qr/\bimport\s+com\.google\.api\.services\.compute\.model\.BackendService\b|\bnew\s+BackendService\b/, $code, CloudReady::Ident::Alias_GCPLoadBalancing));
	# 17/05/2021 HL-1726
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsCloudFormation(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.cloudformation\b|com\.amazonaws\.services\.cloudformation\b)|\bnew\s+AmazonCloudFormationClient\b|\b(?:CloudFormationClient|AmazonCloudFormation)\b/, $code, CloudReady::Ident::Alias_AwsCloudFormation));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsCodeBuild(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.codebuild\b|com\.amazonaws\.services\.codebuild\b)|\bnew\s+AWSCodeBuildClient\b|\b(?:CodeBuildClient|AWSCodeBuild)\b/, $code, CloudReady::Ident::Alias_AwsCodeBuild));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsCodePipeline(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.codepipeline\b|com\.amazonaws\.services\.codepipeline\b)|\bnew\s+AWSCodePipelineClient\b|\b(?:CodePipelineClient|AWSCodePipeline)\b/, $code, CloudReady::Ident::Alias_AwsCodePipeline));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsDataPipeline(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.datapipeline\b|com\.amazonaws\.services\.datapipeline\b)|\bnew\s+DataPipelineClient\b|\b(?:DataPipeline|DataPipelineClient)\b/, $code, CloudReady::Ident::Alias_AwsDataPipeline));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureDeploymentManager(), $checkPattern->(qr/\bimport\s+com\.azure\.resourcemanager\.deploymentmanager\b|\bAzureDeploymentManager\b/, $code, CloudReady::Ident::Alias_AzureDeploymentManager));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzurePipeline(), checkAzurePipelines($code, CloudReady::Ident::Alias_AzurePipeline) );
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPDeploymentManager(), $checkPattern->(qr/\bimport\s+com\.google\.api\.services\.deploymentmanager\b/, $code, CloudReady::Ident::Alias_GCPDeploymentManager));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPCloudBuild(), $checkPattern->(qr/\bimport\s+com\.google\.cloudbuild\b|\bnew\s+Cloudbuild\b/, $code, CloudReady::Ident::Alias_GCPCloudBuild));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPCloudComposer(), $checkPattern->(qr/\bimport\s+com\.google\.api\.services\.composer\b|\bnew\s+CloudComposer\b/, $code, CloudReady::Ident::Alias_GCPCloudComposer));
	# 18/05/2021 HL-1727
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsKinesis(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.kinesis\b|com\.amazonaws\.services\.kinesis\b)|\bnew\s+AmazonKinesisClient\b|\b(?:KinesisClient|AmazonKinesis)\b/, $code, CloudReady::Ident::Alias_AwsKinesis));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsEventBridge(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.eventbridge\b|com\.amazonaws\.services\.eventbridge\b)|\bnew\s+AmazonEventBridgeClient\b|\b(?:EventBridgeClient|AmazonEventBridge)\b/, $code, CloudReady::Ident::Alias_AwsEventBridge));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureStreamAnalytics(), $checkPattern->(qr/\bimport\s+com\.azure\.resourcemanager\.streamanalytics\b|\bnew\s+StreamAnalyticsManager\b/, $code, CloudReady::Ident::Alias_AzureStreamAnalytics));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureEventHub(), $checkPattern->(qr/\bimport\s+com\.azure\.messaging\.eventhubs\b|\bnew\s+EventHubClientBuilder\b/, $code, CloudReady::Ident::Alias_AzureEventHub));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureEventGrid(), $checkPattern->(qr/\bimport\s+com\.azure\.messaging\.eventgrid\b|\bnew\s+(?:EventGridClientImpl|EventGridEvent)\b/, $code, CloudReady::Ident::Alias_AzureEventGrid));
	# 18/05/2021 HL-1730
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AwsCloudWatch(), $checkPattern->(qr/\bimport\s+(?:software\.amazon\.awssdk\.services\.cloudwatch\b|com\.amazonaws\.services\.cloudwatch\b)|\bnew\s+AmazonCloudWatchClient\b|\b(?:AmazonCloudWatch|CloudWatchEventsClient)\b/, $code, CloudReady::Ident::Alias_AwsCloudWatch));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AzureMonitor(), $checkPattern->(qr/\bimport\s+com\.microsoft\.azure\.management\.network\.ConnectionMonitor\b|\bnew\s+ConnectionMonitorImpl\b|\bConnectionMonitor\b/, $code, CloudReady::Ident::Alias_AzureMonitor));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_GCPCloudMonitoring(), $checkPattern->(qr/\bimport\s+com\.google\.cloud\.monitoring\b|\bnew\s+MonitoredResource\b|\bMonitoredResource\.newBuilder\b/, $code, CloudReady::Ident::Alias_GCPCloudMonitoring));
	# HL-1751 22/06/2021
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_SensitiveDataString(), CloudReady::lib::SensitiveDataString::CountSensitiveDataString($code, $HString, $techno));
	# 28/04/2022 CloudReady improvements
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_AmazonawsS3Storage, $checkPattern->('\bAmazonS3ClientBuilder\b', $code, CloudReady::Ident::Alias_AmazonawsS3Storage));
	CloudReady::detection::addFileDetection($fichier, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage, $checkPattern->('\bimport\s+com\.azure\.storage\.blob\b|\bBlobServiceClient(?:Builder)?\b', $code, CloudReady::Ident::Alias_MicrosoftAzureBlobStorage));

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
