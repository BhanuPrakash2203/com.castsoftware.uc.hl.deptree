package CloudReady::projectFiles;

use strict;
use warnings;
use Lib::XML;
use Lib::SHA;

use CloudReady::Ident;
use CloudReady::detection;

my $MASTER_TECHNO = undef;
my %boolConfigXML;

sub setMasterTechno($) {
	$MASTER_TECHNO = shift;
	# if $techno is initialized with the name of the analyseur, retrieves the name of the techno by removing the suffix "Ana" !! 
	$MASTER_TECHNO =~ s/\AAna//;
}

sub checkWebConfig($$) {
	my $webconf = shift;
	my $webconfContent = shift;
    # print "CloudReady : checking web.config\n";

	# Loading xml content
	# my $webconfContent = Lib::XML::load_xml($webconf);
	# my $webconfContentWithNoComment = $webconfContent;

	return if (! defined $webconfContent);

    # .NET 3.5 (and above)
	#if (defined $webconfContent->first_elt('connectionStrings')) {
	if (scalar $webconfContent->getElementsByLocalName('connectionStrings')->get_nodelist() ) {
        # print "web.config contains connectionStrings !!\n";
		CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_WebConfContainsConnectionStrings, []);
	}
    
    # 15/02/18 HL-365 Connection String defined inside project files
    # .Net 2.0 
	#if (scalar $webconfContentWithNoComment->findnodes("//appSettings") ) {
	if (scalar $webconfContent->getElementsByLocalName('appSettings')->get_nodelist() ) {
                
        my $cpt_SQLDatabaseUnsecureAuthentication = 0;
        my $regexp_ConnectionString = qr/
        \b(?:
        Persist\s+Security\s+Info\s*\= 
        | Integrated\s+Security\s*\=
        | Data\s+Source\s*\= 
        | User\s+ID\s*\= 
        | uid\s*\= 
        | Password\s*\= 
        | Initial\s+Catalog\s*\= 
        | Provider\s*\=
        )\b/xi;
        
        #foreach ($webconfContentWithNoComment->findnodes('//appSettings/add[@value =~ /'.$regexp_ConnectionString.'/]')) 
        foreach (Lib::XML::findnodes_AttrMatch($webconfContent, q{//appSettings/add}, "value", $regexp_ConnectionString) )
        {
            # get the node content
            my $ConnectionString = $_->toString;
                        
            my $count_StringPattern = 0;
            # my $bool_MicrosoftAuthenticate;
            
            while ($ConnectionString =~ /$regexp_ConnectionString/g)
            {
				$count_StringPattern++;

                ###############
                # TO BE FIXED:#
				###############
				# 19/02/18 HL-474 Microsoft authentication
                # my $regexp_MicrosoftAuthenticate = qr/\b(?:Integrated\s+Security | Trusted_Connection\s*\=)\b/xi;
               
                # if ($ConnectionString =~ /$regexp_MicrosoftAuthenticate/)
                # {
                    # $bool_MicrosoftAuthenticate = 1;
                    
                    #if ($ConnectionString =~ /\bIntegrated\s+Security\s*\=\s*(?!true|yes|SSPI)|\bTrusted_Connection\s*\=\s*(?!true|yes)/i)
                    #{
                    #    # print '++++ Violation detection Microsoft authentication in string '."\n";
                    #    $cpt_SQLDatabaseUnsecureAuthentication++;
                    #}
                # }              
            }
            
            if ($count_StringPattern >= 3)
            {
                # print '++++ Connection string detected in web.config file'."\n";
                CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_WebConfContainsConnectionStrings, []);           
            
                #if ($cpt_SQLDatabaseUnsecureAuthentication > 0)
                #{
                #    # print '++++ Violation detection Microsoft authentication in web.config file'."\n";
                #    CloudReady::detection::addFileDetection($webconf, CloudReady::Ident::Alias_SQLDatabaseUnsecureAuthentication(), 1);
                #    
                #}     
            }
        }
    }

	
	# count elsewhere in the document all "authentication" nodes :
	#	* having a parent "system.web"
	#	* having an attribute "mode" whose value is "Forms"
	#if (scalar $webconfContent->findnodes('//system.web/authentication[@mode="Forms"]') ) {
	if (scalar Lib::XML::findnodes($webconfContent, '//system.web/authentication[@mode="Forms"]')) {
		CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_WebConfigAuthenticationForm, []);
	}
	
	# count elsewhere in the document all "authentication" nodes :
	#	* having a parent "system.web"
	#	* having an attribute "mode" whose value is "Forms"
	#if (scalar $webconfContent->findnodes('//system.web/authentication[@mode="Windows"]') ) {
	if (scalar Lib::XML::findnodes($webconfContent, '//system.web/authentication[@mode="Windows"]') ) {
		CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_WebConfigAuthenticationWindows, []);
	}
	
	# count elsewhere in the document all "add" nodes :
	#	* having a parent "appSettings"
	#	* having an attribute "key" whose value matches /^ida:.*/
	#if (scalar $webconfContent->findnodes('//appSettings/add[@key =~ /^ida:.*/]') ) {
	if (scalar Lib::XML::findnodes_AttrMatch($webconfContent, '//appSettings/add', "key", qr/^ida:.*/) ) {
		CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_WebConfigActiveDirectory, []);
	}
	
	# count elsewhere in the document all "add" nodes :
	#	* having a parent "connectionStrings"
	#	* having an attribute "name" whose value matches /^AzureWebJobs.*/
	#if (scalar $webconfContent->findnodes('//connectionStrings/add[@name =~ /AzureWebJobs\w*/]') ) {
	if (scalar Lib::XML::findnodes_AttrMatch($webconfContent, '//connectionStrings/add', "name", qr/AzureWebJobs\w*/) ) {
		CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_WebConfigAzureWebJobs, []);
	}
	
	# count elsewhere in the document all "identity" nodes :
	#	* having an attribute "impersonate" to "true"
	#if (scalar $webconfContent->findnodes('//identity[@impersonate="true"]') ) {
	if (scalar Lib::XML::findnodes($webconfContent, '//identity[@impersonate="true"]') ) {
		CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_WebConfigIdentityImpersonateTrue, []);
	}
}

# Common sub for web & app.config files
sub checkWebAppConfig($$)
{
	my $fileNameConf = shift;
	my $WebAppContent = shift;

	# Loading xml content
	return if (! defined $WebAppContent);

	# HL-940 28/06/2019 Detect usage of Log4Net
	# configSections
	if (scalar Lib::XML::findnodes_AttrMatch($WebAppContent, '//configSections/section', "name", qr/\blog4net\b/)
		or scalar Lib::XML::findnodes_AttrMatch($WebAppContent, '//configSections/section', "type", qr/\blog4net\b/) 
	) 
	{
		CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_Log4NetConfig, [$fileNameConf]);
	}
	# log4net
	elsif (scalar Lib::XML::findnodes($WebAppContent, '//log4net'))	
	{
		CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_Log4NetConfig, [$fileNameConf]);		
	}
	# HL-939 24/06/2019 Detect WCF services
	if (scalar Lib::XML::findnodes($WebAppContent, '//system.serviceModel'))
	{
		if ($fileNameConf =~ /\bweb\.config\b$/im) {
			# print "[Web.config] WCF service found \n";
			CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_WCFServiceWebConf, []);
		}
		if ($fileNameConf =~ /\bapp\.config\b$/im) {
			CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_WCFServiceAppConf, []);
		}
	}
}

sub checkCsVbProj($$) {
	my $csVbproj =shift;
	my $webconfContent =shift;
	
	return if (!defined $webconfContent);
	
	# count elsewhere in the document all "COMReference" nodes :
	#	* having an attribute "include"
	#if (scalar $webconfContent->findnodes('//COMReference[@Include]') ) {
	if (scalar Lib::XML::findnodes($webconfContent, '//COMReference[@Include]') ) {
		CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_CsprojCOMReferenceInclude, [$csVbproj]);
	}
	# HL-962
	if ($MASTER_TECHNO eq "CS" 
		&& scalar Lib::XML::findnodes($webconfContent, '//ItemGroup/PackageReference[@Include]')) {
		my $nodes = Lib::XML::findnodes($webconfContent, '//ItemGroup/PackageReference');
		for my $node (@{$nodes}){
			if ($node->getAttribute("Include") eq "FirebaseAdmin"){
				CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_UsingFireBase, [$csVbproj]);
			}
		}
	}
}

sub checkPomXml($$$$$) {
	my $pom = shift;
	my $pomContent = shift;
	my $groupId = shift;
	my $artifactId = shift;
	my $aliasMnemo = shift;

	# Loading xml content
	# my $pomContent = Lib::XML::load_xml($pom);

	return 0 if (! defined $pomContent);
	
	# Detect ADAL4J dependency ...
	# <dependency>
	#	<groupId>com.microsoft.azure</groupId>
	#	<artifactId>adal4j</artifactId>
	#		[ <version>1.1.1</version> ]
	# </dependency>"
	
	my @nodes = Lib::XML::findnodes($pomContent, '//dependencies/dependency');

	for my $node (@nodes) {
		my @artifactId = Lib::XML::findnodes($node, './artifactId');

		if ((scalar @artifactId) && ($artifactId[0]->textContent =~ /^${artifactId}$/mi)) {
			#my @groupId = $node->findnodes('groupId');
			my @groupId = Lib::XML::findnodes($node, './groupId');
			if ((scalar @groupId) && ($groupId[0]->textContent eq $groupId)) {
				# print "PATTERN <$artifactId> FOUND IN POM.XML !!!!!!!!!!\n";
				CloudReady::detection::addAppliDetection(&$aliasMnemo, [$pom]);
				return 1;
			}
		}
	}
	return 0;
}

sub checkContentConfig($$$$){
	my $fileConfig = shift;
	my $buff = shift;
	my $patternMatching = shift;
	my $aliasMnemo = shift;

	if ($buff =~ /(${patternMatching})/g){
		if (defined $1) {
			# print "PATTERN <$patternMatching> FOUND IN $fileConfig\n";
			CloudReady::detection::addAppliDetection(&$aliasMnemo, [$fileConfig]);
		}
	}
}

sub checkFileProjectElaborateLog($$$$){
	my $fileConfig = shift;
	my $buff = shift;
	my $patternMatching = shift;
	my $aliasMnemo = shift;

	if ($buff =~ /(${patternMatching})/g){
		if (defined $1) {
			# print "PATTERN <$patternMatching> FOUND IN $fileConfig\n";
			my $rulesDescription = CloudReady::lib::ElaborateLog::keepPortalData();
			CloudReady::lib::ElaborateLog::ElaborateLogPartOne(\$buff, $patternMatching, $aliasMnemo, $rulesDescription);
			CloudReady::detection::addAppliDetection(\&{$aliasMnemo}, [$fileConfig]);
		}
	}
}

sub checkSpringScopes($$) {
	my $webconf = shift;
	my $webconfContent = shift;

	# Loading xml content
	# my $webconfContent = Lib::XML::load_xml($webconf);

	return if (! defined $webconfContent);
	
	# count elsewhere in the document all "bean" nodes :
	#	* having a parent "beans"
	#	* having an attribute "scope" whose value matches /^(session|globalSession)$/
	#if (scalar $webconfContent->findnodes('//beans/bean[@scope =~ /^(session|globalSession)$/]') ) {
	if (scalar Lib::XML::findnodes_AttrMatch($webconfContent, '//beans/bean', "scope", qr/^(session|globalSession)$/) ) {
		CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_Spring_XmlConfForStatefulCompliantScopes, [$webconf]);
	}
}


sub checkConfigXMLExists($$) {
	my $NameFileXML = shift;
	my $ConfigName = shift;
    
    # print 'name of file xml=<'.$NameFileXML."> config $ConfigName\n";
    
    my @ConfigXMLFilesDetect = ();
    if ($ConfigName eq 'Weblogic')
    {
        @ConfigXMLFilesDetect =
        qw (
            weblogic.xml
            weblogic-cmp-rdbms-jar.xml
            weblogic-ejb-jar.xml
            weblogic-ra.xml
            persistence-configuration.xml
            weblogic-webservices.xml
            weblogic-wsee-clientHandlerChain.xml
            webservice-policy-ref.xml
            weblogic-wsee-standaloneclient.xml
            weblogic-application.xml
        );
    }
    elsif ($ConfigName eq 'Websphere')
    {
        @ConfigXMLFilesDetect =
        qw (
            client-resource.xmi
            ibm-application-bnd.xmi
            ibm-application-bnd.xml
            ibm-application-client-bnd.xmi
            ibm-application-client-bnd.xml
            ibm-application-client-ext.xmi
            ibm-application-client-ext.xml
            ibm-application-ext.xmi
            ibm-application-ext.xml
            ibm-ejb-access-bean.xml
            ibm-ejb-jar-bnd.xmi
            ibm-ejb-jar-bnd.xml
            ibm-ejb-jar-ext.xmi
            ibm-ejb-jar-ext.xml
            ibm-ejb-jar-ext-pme.xmi
            ibm-ejb-jar-ext-pme.xml
            ibm-webservices-bnd.xmi
            ibm-webservices-ext.xml
            ibm-web-bnd.xmi
            ibm-web-bnd.xml
            ibm-web-ext.xmi
            ibm-web-ext.xml
            ibm-web-ext-pme.xmi
            ibm-web-ext-pme.xml
            j2c_plugin.xml
        );    
    }    
    elsif ($ConfigName eq 'JBoss')
    {
        @ConfigXMLFilesDetect =
        qw (
            jaws.xml
            jboss.xml
            jbosscmp-jdbc.xml
            jboss-service.xml
            jboss-web.xml
        );    
    }
    elsif ($ConfigName eq 'JEE')
    {
        @ConfigXMLFilesDetect =
        qw (
            application.xml
            application-client.xml
            ejb-jar.xml
            ra.xml
            webservices.xml
        );    
    }
    
    
    foreach my $NameFileConfig (@ConfigXMLFilesDetect)
    {
        if ( $NameFileXML eq $NameFileConfig )
        {
            # print $NameFileXML ." detected\n";
            return 1;
        }
    }
    
    return 0;
}

sub checkXpathAttributeValues($$$$$$) {
	my $File = shift;
	my $xmlContent = shift;
	my $XpathOrigin = shift;
	my $AttributeName = shift;
	my $Ref_HashValues = shift;
	my $Alias = shift;
  
   # my $xmlContent = Lib::XML::load_xml($File);
    
    return if (! defined $xmlContent);
    
    foreach my $key (keys %{$Ref_HashValues})
    {                        
        
        if (scalar Lib::XML::findnodes_AttrMatch($xmlContent, $XpathOrigin, $AttributeName, qr/\b$key\b/) )
        {
            # print '+++++++'. $AttributeName ." found with value containing $key\n";
            CloudReady::detection::addAppliDetection(&$Alias, [$File]);
        }
    }
 
}

# Returns a hybrid view with string and values of tags
sub stripStringsWithTagsXML($$$) {
	my $buf =  shift;
	my $HStrings = shift;
	my $HStringsTagValue = shift;
	my %HShaString;
	my %HShaTagValue;

	my $closing = undef;
	my $tag = 0;
	my $string ="";
	my $tagTextValue ="";
	my $count = 0;
	my $bufout = "";
	my $bool_string = 0;
	my $bool_tagTextValue = 0;
	my $countBis = 0;

	my $closingChar;
	while ($$buf =~ /\G([^"<>']*|["'<>])/sg) {
		my $catch = $1;
		my $stringID;
		if (defined $1 && $1 ne '') {
			if ($catch =~ /^(['"])$/ && $bool_string == 0 && $bool_tagTextValue == 0) {
				$bool_string = 1;
				$closingChar = $1;
			}
			elsif ($catch =~ /^['"]$/ && $bool_string == 1
				&& $bool_tagTextValue == 0 && $catch eq $closingChar) {
				my $SHA = Lib::SHA::SHA256(\$string);
				if (exists $HShaString{$SHA}) {
					$bufout .= $HShaString{$SHA};
				}
				else {
					$stringID = "CHAINE_" . $count++;
					$bufout .= $stringID;
					$HStrings->{$stringID} = '"'.$string.'"';
					$HShaString{$SHA} = $stringID;
				}
				$bool_string = 0;
				$string = "";
				$closingChar = "";
			}
			elsif ($catch eq '>') {
				$bufout .= $catch;
				$bool_tagTextValue = 1;
			}
			elsif ($catch eq '<') {
				if ($tagTextValue ne '' && $tagTextValue =~ /\S/) {
					my $SHA = Lib::SHA::SHA256(\$tagTextValue);
					if (exists $HShaTagValue{$SHA}) {
						$bufout .= $HShaTagValue{$SHA};
					}
					else {
						$stringID = "XML_" . $countBis++;
						$bufout .= $stringID;
						$HStringsTagValue->{$stringID} = '"'.$tagTextValue.'"';
						$HShaTagValue{$SHA} = $stringID;
					}
					while ($tagTextValue =~ /\n/g) {
						$bufout .= "\n";
					}
				}
				$bool_tagTextValue = 0;
				$tagTextValue = "";
				$bufout .= $catch;
			}
			elsif ($bool_string == 1) {
				# content of string
				$string .= $catch;
			}
			elsif ($bool_tagTextValue == 1) {
				if ($catch =~ /\S/) {
					# content of string
					$tagTextValue .= $catch;
				}
				else {
					$bufout .= $catch;
				}
			}
			else {
				$bufout .= $catch;
			}
		}
	}

	return \$bufout;
}

sub checkHardCodedIPPath($$$$$) {

	# Use algo CloudReady::lib::HardCodedIP::checkHardCodedIP
	# Use algo CloudReady::lib::HardCodedPath::checkHardCodedPath

	my $fileConfig = shift;
	my $buff = shift;
	my $aliasMnemo = shift;
	my $alias = shift;
	my $techno = shift;

	my %HStrings = ();
	my %HStringsTagValue = ();

	# Do a simple code view and a hash string...
	my $codeXML;

	if (defined $buff) {
		$codeXML = ${stripStringsWithTagsXML(\$buff, \%HStrings, \%HStringsTagValue)};
		# merge hashes
		%HStrings = (%HStrings, %HStringsTagValue);

		# 07/03/2022 deactivate HardCodedIP
		# if ($alias eq 'Alias_HardCodedIP') {
		# 	# if checkHardCodedIP result > 0
		# 	if (CloudReady::lib::HardCodedIP::checkHardCodedIP(\%HStrings, \$codeXML, $techno, \$buff)) {
		# 		CloudReady::detection::addAppliDetection($aliasMnemo, [ $fileConfig ]);
		# 	}
		# }
		if ($alias eq 'Alias_HardCodedPath') {
			# if checkHardCodedPath result > 0
			if (CloudReady::lib::HardCodedPath::checkHardCodedPath(\%HStrings, $techno, \$codeXML, \$buff)) {
				CloudReady::detection::addAppliDetection($aliasMnemo, [ $fileConfig ]);
			}
		}
		# replacing SHA by filenames in log
		CloudReady::lib::ElaborateLog::ElaborateLogPartTwo(\$codeXML, \$buff, $fileConfig);
	}
}

sub detect($) {
	my $file = shift;
    
	if ($file =~ /(.*[\\\/])?([^\\\/]+)$/) {
		my $path = $1||"";
		my $basename = $2;
		
		if ($basename =~ /(.+)\.([^\.]*)$/) {
			my $name = lc($1);
			my $ext = lc($2);
			if (($MASTER_TECHNO eq "CS") || ($MASTER_TECHNO eq "VbDotNet")) {
				if ($ext eq 'config') {

					print "Analyzing $file ...\n";
					my $buff;
					my $status = open (FILE, "<", $file);
					if ($status) {
						local $/ = undef;
						$buff = <FILE>;
						close FILE;
					}
					my $bufferXML = Lib::XML::load_xml($file);
					if (!defined $bufferXML) {
						print STDERR "ERROR: malformed XML for file $file\n";
					}
					# 09/06/2020 HardCodedIP
					# 13/07/2021 HardCodedIP disabled for config files
					# checkHardCodedIPPath($file, $buff, CloudReady::Ident::Alias_HardCodedIP, 'Alias_HardCodedIP');
					# 10/06/2020 HardCodedPath
					# 13/07/2021 HardCodedPath disabled for config files
					# checkHardCodedIPPath($file, $buff, CloudReady::Ident::Alias_HardCodedPath, 'Alias_HardCodedPath');
					# HL-1628 07/03/2022 deactivate HTTP, FTP, LDAP
					# 11/06/2020 HTTPProtocol
					# checkContentConfig($file, $buff, "(?i)\\bhttps?\:\/\/", \&{'CloudReady::Ident::Alias_HTTPProtocol'});
					# 11/06/2020 FTPProtocol
					# checkContentConfig($file, $buff, "(?i)\\bs?ftps?\:\/\/", \&{'CloudReady::Ident::Alias_FTPProtocol'});
					# 11/06/2020 LDAPProtocol
					# checkContentConfig($file, $buff, "(?i)\\bldaps?\:\/\/", \&{'CloudReady::Ident::Alias_LDAPProtocol'});

					if ($name eq 'web') {
						CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_WebConfFile, [$file]);
						checkWebConfig($file, $bufferXML);
						checkWebAppConfig($file, $bufferXML);
					}
					elsif ($name eq 'app') {
						checkWebAppConfig($file, $bufferXML);
					}
					# HL-940 28/06/2019 Detect usage of Log4Net
					elsif ($name eq 'log4net') {
						CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_Log4NetConfig, [$file]);
					}
					elsif ($name !~ /\b(?:nuget|packages)\b|\bweb\b.*/) {
						CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_ExtraConfFile, [$file]);
						#print "Id_ExtraConfFile => $file\n";
					}
                    
                    # 28/02/2018 HL-489 .Net EventLog   
                    my $Ref_HashValues = {
                        "System.Diagnostics.EventLogTraceListener" => 1
                    };
                    my $Alias = \&{'CloudReady::Ident::Alias_Config_EventLogTraceListener'};

                    checkXpathAttributeValues($file, $bufferXML, '//system.diagnostics/trace/listeners/add', 'type', $Ref_HashValues, $Alias);
                        
                    # 01/03/2018 HL-497 Machine Key use
                    $Ref_HashValues = {
                        "AutoGenerate" => 1
                    };
                    $Alias = \&{'CloudReady::Ident::Alias_MachineKey_ValidationKey_AutoGenerate'};

                    checkXpathAttributeValues($file, $bufferXML, '//machineKey', 'validationKey', $Ref_HashValues, $Alias);
                             # //machineKey[@validationKey="... AutoGenerate ...]
				}
				# HL-1708
				elsif (($MASTER_TECHNO eq "CS" && $ext eq 'csproj') 
						|| ($MASTER_TECHNO eq "VbDotNet" && $ext eq 'vbproj')) {
					print "Analyzing $file ...\n";
					my $bufferXML = Lib::XML::load_xml($file);
					if (!defined $bufferXML) {
						print STDERR "ERROR: malformed XML for file $file\n";
					}
					checkCsVbProj($file, $bufferXML);
				}
				elsif ($ext eq "xml") {
					print "Analyzing $file ...\n";
					my $buff;
					my $status = open (FILE, "<", $file);
					if ($status) {
						local $/ = undef;
						$buff = <FILE>;
						close FILE;
					}

					# 09/06/2020 HardCodedIP
					# 07/03/2022 deactivate HardCodedIP for xml
					# checkHardCodedIPPath($file, $buff, CloudReady::Ident::Alias_HardCodedIP, 'Alias_HardCodedIP', $MASTER_TECHNO);
					# 10/06/2020 HardCodedPath
					checkHardCodedIPPath($file, $buff, CloudReady::Ident::Alias_HardCodedPath, 'Alias_HardCodedPath', $MASTER_TECHNO);
					# HL-1628
					# HTTPProtocol 20/12/2021 deactivate rule for xml
					# checkContentConfig($file, $buff, "(?i)\\bhttps?\:\/\/", \&{'CloudReady::Ident::Alias_HTTPProtocol'});
					# FTPProtocol 20/12/2021 deactivate rule for xml
					# checkContentConfig($file, $buff, "(?i)\\bs?ftps?\:\/\/", \&{'CloudReady::Ident::Alias_FTPProtocol'});
					# LDAPProtocol 20/12/2021 deactivate rule for xml
					# checkContentConfig($file, $buff, "(?i)\\bldaps?\:\/\/", \&{'CloudReady::Ident::Alias_LDAPProtocol'});
				}
			}
			elsif ($MASTER_TECHNO eq "Python" or $MASTER_TECHNO eq "PHP") {
				if ($ext eq "yaml"){
					if ($name eq 'app')
					{
						print "Analyzing $file ...\n";
						my $buff;
						my $status = open (FILE, "<", $file);
						if ($status) {
							local $/ = undef;
							$buff = <FILE>;
							close FILE;
						}

						# HL-954 08/10/2019 [GCP Boosters] Using MySQL database
						checkContentConfig($file, $buff, "\\bmysql(?:[+]pymysql)?\\b", \&{'CloudReady::Ident::Alias_DBMS_MySQL'});
						# HL-955 09/10/2019 [GCP Boosters] Using PostgreSQL database
						checkContentConfig($file, $buff, "\\bpostgresql|pgsql\\b", \&{'CloudReady::Ident::Alias_DBMS_PostgreSQL'});
					}
				}
			}
			elsif ($MASTER_TECHNO eq "Java") {
				if ($ext eq "xml") 
                {
					print "Analyzing $file ...\n";
					my $buff;
					my $status = open (FILE, "<", $file);
					if ($status) {
						local $/ = undef;
						$buff = <FILE>;
						close FILE;
					}
					my $bufferXML = Lib::XML::load_xml($file);
					if (!defined $bufferXML) {
						print STDERR "ERROR: malformed XML for file $file\n";
					}
					# 09/06/2020 HardCodedIP
					# 07/03/2022 deactivate HardCodedIP for xml
					# checkHardCodedIPPath($file, $buff, CloudReady::Ident::Alias_HardCodedIP, 'Alias_HardCodedIP', $MASTER_TECHNO);
					# 10/06/2020 HardCodedPath
					checkHardCodedIPPath($file, $buff, CloudReady::Ident::Alias_HardCodedPath, 'Alias_HardCodedPath', $MASTER_TECHNO);
					# HL-1628
					# HTTPProtocol 20/12/2021 deactivate rule for xml
					# checkContentConfig($file, $buff, "(?i)\\bhttps?\:\/\/", \&{'CloudReady::Ident::Alias_HTTPProtocol'});
					# FTPProtocol 20/12/2021 deactivate rule for xml
					# checkContentConfig($file, $buff, "(?i)\\bs?ftps?\:\/\/", \&{'CloudReady::Ident::Alias_FTPProtocol'});
					# LDAPProtocol 20/12/2021 deactivate rule for xml
					# checkContentConfig($file, $buff, "(?i)\\bldaps?\:\/\/", \&{'CloudReady::Ident::Alias_LDAPProtocol'});

					if ($name eq "web")  {
						CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_WebXml, [$file]);
					}
					elsif ($name eq "pom") {
						checkPomXml($file, $bufferXML, "com.microsoft.azure", "adal4j", \&{'CloudReady::Ident::Alias_PomXmlAdal4jDependency'});
						# HL-953 04/10/2019 [GCP Boosters] Using BigQuery
						checkPomXml($file, $bufferXML, "com.google.cloud", "google\-cloud\-bigquery", \&{'CloudReady::Ident::Alias_UsingBigQuery'});
						# HL-954 08/10/2019 [GCP Boosters] Using MySQL database
						my $status = checkPomXml($file, $bufferXML, "mysql", "mysql\-connector\-java", \&{'CloudReady::Ident::Alias_DBMS_MySQL'});
						if (! $status){
							checkPomXml($file, $bufferXML, "com.google.cloud.sql", "mysql\-socket\-factory\-connector\-j\-[0-9]+", \&{'CloudReady::Ident::Alias_DBMS_MySQL'});
						}
						# HL-955 09/10/2019 [GCP Boosters] Using PostgreSQL database
						$status = checkPomXml($file, $bufferXML, "org.postgresql", "postgresql", \&{'CloudReady::Ident::Alias_DBMS_PostgreSQL'});
						if (! $status){
							checkPomXml($file, $bufferXML, "com.google.cloud.sql", "postgres\-socket\-factory", \&{'CloudReady::Ident::Alias_DBMS_PostgreSQL'});
						}
						# HL-957 10/10/2019 [GCP Boosters] Using a Cloud-Based Storage
						checkPomXml($file, $bufferXML, "com.google.cloud", "google\-cloud\-datastore", \&{'CloudReady::Ident::Alias_UsingCloudDataStore'});
						# HL-958 11/10/2019 [GCP Boosters] Using BigTable
						checkPomXml($file, $bufferXML, "com.google.cloud", "google\-cloud\-bigtable", \&{'CloudReady::Ident::Alias_UsingBigTable'});
						# HL-959 15/10/2019 [GCP Boosters] Using Cloud Spanner
						checkPomXml($file, $bufferXML, "com.google.cloud", "google\-cloud\-spanner", \&{'CloudReady::Ident::Alias_UsingCloudSpanner'});
						# HL-960 16/10/2019 [GCP Boosters] Using Cloud in-memory database (redis)
						checkPomXml($file, $bufferXML, "com.google.cloud", "google\-cloud\-redis", \&{'CloudReady::Ident::Alias_Using_InMemoryRedisGCP'});
						# HL-961 17/10/2019 [GCP Boosters] Using Cloud IAM (Identity and Access Management)
						checkPomXml($file, $bufferXML, "com.google.apis", "google\-api\-services\-iam", \&{'CloudReady::Ident::Alias_UsingCloudIAM'});
						# HL-962 18/10/2019 [GCP Boosters] Using Firebase
						checkPomXml($file, $bufferXML, "com.google.firebase", "firebase\-admin", \&{'CloudReady::Ident::Alias_UsingFireBase'});
						# HL-963 28/10/2019 [GCP Boosters] Using Cloud IAP (Identity Aware Proxy)
						checkPomXml($file, $bufferXML, "com.google.apis", "google\-api\-services\-iap", \&{'CloudReady::Ident::Alias_UsingCloudIAP'});
						# HL-964 28/10/2019 [GCP Boosters] Using a Cloud-based Key storage (KMS)
						checkPomXml($file, $bufferXML, "com.google.cloud", "google\-cloud\-kms", \&{'CloudReady::Ident::Alias_GCPServicesKms'});
						# HL-968 30/10/2019 [GCP Boosters] Using a Cloud-based middleware application
						checkPomXml($file, $bufferXML, "com.google.cloud", "google\-cloud\-pubsub", \&{'CloudReady::Ident::Alias_UsingCloudPubSub'});
						# HL-1724 10/05/2021
						checkPomXml($file, $bufferXML, "com.google.apis", "google\-api\-services\-cloudfunctions", \&{'CloudReady::Ident::Alias_GCPFunctions'});
						# HL-1723 10/05/2021
						checkPomXml($file, $bufferXML, "com.azure.resourcemanager", "azure\-resourcemanager\-recoveryservices", \&{'CloudReady::Ident::Alias_AzureArchiveStorage'});
						checkPomXml($file, $bufferXML, "com.google.apis", "google\-api\-services\-file", \&{'CloudReady::Ident::Alias_GCPFilestore'});
						# HL-1725 11/05/2021
						checkPomXml($file, $bufferXML, "com.azure.resourcemanager", "azure\-resourcemanager\-datafactory", \&{'CloudReady::Ident::Alias_AzureDataFactory'});
						checkPomXml($file, $bufferXML, "com.google.apis", "google\-api\-services\-datafusion", \&{'CloudReady::Ident::Alias_GCPCloudDataFusion'});
						# HL-1726 17/05/2021
						checkPomXml($file, $bufferXML, "com.azure.resourcemanager", "azure\-resourcemanager\-deploymentmanager", \&{'CloudReady::Ident::Alias_AzureDeploymentManager'});
						checkPomXml($file, $bufferXML, "com.google.apis", "google\-api\-services\-deploymentmanager", \&{'CloudReady::Ident::Alias_GCPDeploymentManager'});
						checkPomXml($file, $bufferXML, "com.google.cloud", "google\-cloud\-build", \&{'CloudReady::Ident::Alias_GCPCloudBuild'});
						checkPomXml($file, $bufferXML, "com.google.apis", "google\-api\-services\-composer", \&{'CloudReady::Ident::Alias_GCPCloudComposer'});
						# HL-1727 18/05/2021
						checkPomXml($file, $bufferXML, "com.azure.resourcemanager", "azure\-resourcemanager\-streamanalytics", \&{'CloudReady::Ident::Alias_AzureStreamAnalytics'});
						checkPomXml($file, $bufferXML, "com.azure", "azure\-messaging\-eventhubs", \&{'CloudReady::Ident::Alias_AzureEventHub'});
						checkPomXml($file, $bufferXML, "com.microsoft.azure", "azure\-eventgrid", \&{'CloudReady::Ident::Alias_AzureEventGrid'});
						# HL-1730 18/05/2021
						checkPomXml($file, $bufferXML, "com.google.cloud", "google\-cloud\-monitoring", \&{'CloudReady::Ident::Alias_GCPCloudMonitoring'});

					}
                    # 13/02/2018 HL-472 CDI Beans
                    elsif ($name eq "beans") {

                        my $Ref_HashValues = {
                            "http://java.sun.com/xml/ns/javaee" => 1,
                            "http://xmlns.jcp.org/xml/ns/javaee" => 1
                        };
                        my $Alias = \&{'CloudReady::Ident::Alias_CDIBeansConfiguration'};

                        checkXpathAttributeValues($file, $bufferXML, '//beans', 'xmlns', $Ref_HashValues, $Alias);
                    }
					else {
						# HL-251
						if ($path =~ /WEB-INF[\\\/]$/m) {
							checkSpringScopes($file, $bufferXML);
						}
						CloudReady::detection::addAppliDetection(CloudReady::Ident::Alias_ExtraXmlFile, [$file]);
					}
				}
				elsif ($ext eq 'gradle') {
					if ($name eq 'build') {
						print "Analyzing $file ...\n";
						my $buff;
						my $status = open (FILE, "<", $file);
						if ($status) {
							local $/ = undef;
							$buff = <FILE>;
							close FILE;
						}

						# HL-953 04/10/2019 [GCP Boosters] Using BigQuery
						checkContentConfig($file, $buff, "[\"'].*?com.google.cloud:google-cloud-bigquery.*?[\"']", \&{'CloudReady::Ident::Alias_UsingBigQuery'});
						# HL-954 08/10/2019 [GCP Boosters] Using MySQL database
						checkContentConfig($file, $buff, "[\"'].*?com.google.cloud.sql:mysql-socket-factory-connector-j.*?[\"']", \&{'CloudReady::Ident::Alias_DBMS_MySQL'});
						# HL-957 10/10/2019 [GCP Boosters] Using a Cloud-Based Storage
						checkContentConfig($file, $buff, "[\"'].*?com.google.cloud:google-cloud-datastore.*?[\"']", \&{'CloudReady::Ident::Alias_UsingCloudDataStore'});
						# HL-958 11/10/2019 [GCP Boosters] Using BigTable
						checkContentConfig($file, $buff, "[\"'].*?com.google.cloud:google-cloud-bigtable.*?[\"']", \&{'CloudReady::Ident::Alias_UsingBigTable'});
						# HL-959 15/10/2019 [GCP Boosters] Using Cloud Spanner
						checkContentConfig($file, $buff, "[\"'].*?com.google.cloud:google-cloud-spanner.*?[\"']", \&{'CloudReady::Ident::Alias_UsingCloudSpanner'});
						# HL-960 16/10/2019 [GCP Boosters] Using Cloud in-memory database (redis)
						checkContentConfig($file, $buff, "[\"'].*?com.google.cloud:google-cloud-redis.*?[\"']", \&{'CloudReady::Ident::Alias_Using_InMemoryRedisGCP'});
						# HL-962 18/10/2019 [GCP Boosters] Using Firebase
						checkContentConfig($file, $buff, "[\"'].*?com.google.firebase:firebase-admin.*?[\"']", \&{'CloudReady::Ident::Alias_UsingFireBase'});
						# HL-963 28/10/2019 [GCP Boosters] Using Cloud IAP (Identity Aware Proxy)
						checkContentConfig($file, $buff, "[\"'].*?com.google.apis:google-api-services-iap.*?[\"']", \&{'CloudReady::Ident::Alias_UsingCloudIAP'});
						# HL-964 28/10/2019 [GCP Boosters] Using a Cloud-based Key storage (KMS)
						checkContentConfig($file, $buff, "[\"'].*?com.google.cloud:google-cloud-kms.*?[\"']", \&{'CloudReady::Ident::Alias_GCPServicesKms'});
						# HL-968 30/10/2019 [GCP Boosters] Using a Cloud-based middleware application
						checkContentConfig($file, $buff, "[\"'].*?com.google.cloud:google-cloud-pubsub.*?[\"']", \&{'CloudReady::Ident::Alias_UsingCloudPubSub'});
						# HL-1724 10/05/2021
						checkContentConfig($file, $buff, "[\"'].*?com.google.apis:google-api-services-cloudfunctions.*?[\"']", \&{'CloudReady::Ident::Alias_GCPFunctions'});
						# HL-1723 10/05/2021
						checkContentConfig($file, $buff, "[\"'].*?com.google.apis:google-api-services-file.*?[\"']", \&{'CloudReady::Ident::Alias_GCPFilestore'});
						# HL-1725 11/05/2021
						checkContentConfig($file, $buff, "[\"'].*?com.google.apis:google-api-services-datafusion.*?[\"']", \&{'CloudReady::Ident::Alias_GCPCloudDataFusion'});
						# HL-1726 17/05/2021
						checkContentConfig($file, $buff, "[\"'].*?com.google.apis:google-api-services-deploymentmanager.*?[\"']", \&{'CloudReady::Ident::Alias_GCPDeploymentManager'});
						checkContentConfig($file, $buff, "[\"'].*?com.google.cloud:google-cloud-build.*?[\"']", \&{'CloudReady::Ident::Alias_GCPCloudBuild'});
						checkContentConfig($file, $buff, "[\"'].*?com.google.apis:google-api-services-composer.*?[\"']", \&{'CloudReady::Ident::Alias_GCPCloudComposer'});
						# HL-1730 18/05/2021
						checkContentConfig($file, $buff, "[\"'].*?com.google.cloud:google-cloud-monitoring.*?[\"']", \&{'CloudReady::Ident::Alias_GCPCloudMonitoring'});

					}
				}
				elsif ($ext eq "yaml") 
				{
					if ($name eq 'app'){
						print "Analyzing $file ...\n";
						my $buff;
						my $status = open (FILE, "<", $file);
						if ($status) {
							local $/ = undef;
							$buff = <FILE>;
							close FILE;
						}

						# HL-954 08/10/2019 [GCP Boosters] Using MySQL database
						checkContentConfig($file, $buff, "\\bmysql(?:[+]pymysql)?\\b", \&{'CloudReady::Ident::Alias_DBMS_MySQL'});
					}
				}
				elsif ($ext eq "properties") {
					print "Analyzing $file ...\n";
					my $buff;
					my $status = open (FILE, "<", $file);
					if ($status) {
						local $/ = undef;
						$buff = <FILE>;
						close FILE;
					}

					# 09/06/2020 HardCodedIP
					# 07/03/2022 deactivate HardCodedIP for properties
					# checkHardCodedIPPath($file, $buff, CloudReady::Ident::Alias_HardCodedIP, 'Alias_HardCodedIP', $MASTER_TECHNO);
					# 10/06/2020 HardCodedPath
					checkHardCodedIPPath($file, $buff, CloudReady::Ident::Alias_HardCodedPath, 'Alias_HardCodedPath', $MASTER_TECHNO);
					# HL-1628 07/03/2022 deactivate HTTP, FTP, LDAP for properties
					# 11/06/2020 HTTPProtocol
					# checkContentConfig($file, $buff, "(?i)\\bhttps?\:\/\/", \&{'CloudReady::Ident::Alias_HTTPProtocol'});
					# 11/06/2020 FTPProtocol
					# checkContentConfig($file, $buff, "(?i)\\bs?ftps?\:\/\/", \&{'CloudReady::Ident::Alias_FTPProtocol'});
					# 11/06/2020 LDAPProtocol
					# checkContentConfig($file, $buff, "(?i)\\bldaps?\:\/\/", \&{'CloudReady::Ident::Alias_LDAPProtocol'});
				}
				if($ext eq "xml" or $ext eq "xmi")
                {
                    # 07/02/2018 HL-460 Weblogic configuration
                    # 08/02/2018 HL-462 Websphere configuration               
                    # 08/02/2018 HL-463 JBoss configuration               
                    # 09/02/2018 HL-464 JEE configuration    
                    my %checkConfig = (
                         'Weblogic' => \&checkConfigXMLExists("$name.$ext",'Weblogic'),
                         'Websphere' => \&checkConfigXMLExists("$name.$ext",'Websphere'),
                         'JBoss' => \&checkConfigXMLExists("$name.$ext",'JBoss'),
                         'JEE' => \&checkConfigXMLExists("$name.$ext",'JEE'),
                    );

                    foreach my $ConfigKind (keys %checkConfig)
                    {
                        if (not exists $boolConfigXML{$ConfigKind} and ${$checkConfig{$ConfigKind}} == 1)
                        {
                            # print '+++++++ ' . $ConfigKind.' config detected!!!!'."\n";
                            $boolConfigXML{$ConfigKind} = 1;
                            
                            my $Alias = \&{'CloudReady::Ident::Alias_'.$ConfigKind.'Configuration'};
                            CloudReady::detection::addAppliDetection(&$Alias, [$file]);
                        }
                    }
                }
			}
			elsif ($MASTER_TECHNO eq "Swift") {
				if ($name eq "package" && $ext eq "swift") {
					print "Analyzing $file ...\n";
					my $buff;
					my $status = open (FILE, "<", $file);
					if ($status) {
						local $/ = undef;
						$buff = <FILE>;
						close FILE;
					}

					# HL-1337 Detect the usage of a cloud-based Data Warehouse
					checkContentConfig($file, $buff, qr/(?i)url\:\s*\"https\:\/\/github\.com\/swift\-aws\/S3\.git\"/, \&{'CloudReady::Ident::Alias_AmazonawsS3Storage'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/vapor\-community\/google\-cloud\.git\"/, \&{'CloudReady::Ident::Alias_GCPStorage'});
					# HL-1340 Detect the usage of a cloud-based NoSQL database storage
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/swift\-aws\/DynamoDB\.git\"/, \&{'CloudReady::Ident::Alias_DBMS_DynamoDB'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https:\/\/github\.com\/mongodb\/mongo\-swift\-driver\.git\"/, \&{'CloudReady::Ident::Alias_DBMS_MongoDB'});
					# HL-1342 08/09/2020 Detect the usage of cloud-based relational database storage
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/PerfectlySoft\/Perfect\-PostgreSQL\.git\"/, \&{'CloudReady::Ident::Alias_DBMS_PostgreSQL'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/stepanhruda\/PostgreSQL\-Swift\.git\"/, \&{'CloudReady::Ident::Alias_DBMS_PostgreSQL'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/IBM\-Swift\/Swift\-Kuery\-PostgreSQL\.git\"/, \&{'CloudReady::Ident::Alias_DBMS_PostgreSQL'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/PerfectlySoft\/Perfect\-MySQL\.git\"/, \&{'CloudReady::Ident::Alias_DBMS_MySQL'});
					# HL-1343 09/09/2020 Detect the usage of cloud-based cache in-memory database
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/Zewo\/Redis\"/, \&{'CloudReady::Ident::Alias_InMemoryRedis'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/IBM\-Swift\/Kitura\-redis\.git\"/, \&{'CloudReady::Ident::Alias_InMemoryRedis'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https:\/\/github\.com\/orungrau\/SwiftMemcached\.git\"/, \&{'CloudReady::Ident::Alias_InMemoryMemcached'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github.com\/orungrau\/libMemcachedSwift\.git\"/, \&{'CloudReady::Ident::Alias_InMemoryMemcached'});
					# HL-1344 09/09/2020 Detect the usage of a cloud-based Identity and Access Management (IAM)
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/swift\-aws\/IAM\.git\"/, \&{'CloudReady::Ident::Alias_AwsCloudIAM'});
					# HL-1345 09/09/2020 Detect the usage of a cloud-based Active Directory service
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/Azure\-Samples\/active\-directory\-ios\.git\"/, \&{'CloudReady::Ident::Alias_AzureDirectoryService'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/Azure\-Samples\/ms\-identity\-mobile\-apple\-swift\-objc\.git\"/, \&{'CloudReady::Ident::Alias_AzureDirectoryService'});
					# HL-1348 10/09/2020 Detect the usage of a cloud Container Registry
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/spprichard\/K8s\.git\"/, \&{'CloudReady::Ident::Alias_Kubernetes'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/iainsmith\/swift\-docker\.git\"/, \&{'CloudReady::Ident::Alias_Docker'});
					# HL-1352 10/09/2020 Detect the usage of a cloud-based blockchain technology
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/shu223\/BlockchainSwift\.git\"/, \&{'CloudReady::Ident::Alias_Blockchain'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/appcoda\/BlockchainDemo\.git\"/, \&{'CloudReady::Ident::Alias_Blockchain'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/hyperledger\/sawtooth\-sdk\-swift\.git\"/, \&{'CloudReady::Ident::Alias_Blockchain'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/matter\-labs\/web3swift\.git\"/, \&{'CloudReady::Ident::Alias_Blockchain'});
					# HL-1360 11/09/2020 Detect the usage of system calls or processes management
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/jamf\/Subprocess\.git\"/, \&{'CloudReady::Ident::Alias_LaunchSubProcess'});
					checkContentConfig($file, $buff, qr/(?i)url:\s*\"https\:\/\/github\.com\/marcoconti83\/morione\.git\"/, \&{'CloudReady::Ident::Alias_LaunchSubProcess'});

				}
			}
			elsif ($MASTER_TECHNO eq "CCpp") {
				if ($ext eq 'h') {
					print "Analyzing $file ...\n";
					my $buff;
					my $status = open (FILE, "<", $file);
					if ($status) {
						local $/ = undef;
						$buff = <FILE>;
						close FILE;
					}

					# HL-1923 10/01/2022 Using dynamic libraries (dll, so...)
					checkFileProjectElaborateLog($file, $buff, qr/\_\_declspec\s*\(\s*dll(?:imp|exp)ort\s*\)/, CloudReady::Ident::Alias_DllImport);
					# replacing SHA by filenames in log
					CloudReady::lib::ElaborateLog::ElaborateLogPartTwo(\$buff, \$buff, $file);
				}
			}
		}
	}
}

1;
