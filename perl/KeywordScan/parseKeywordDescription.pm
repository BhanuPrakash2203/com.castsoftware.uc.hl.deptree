package KeywordScan::parseKeywordDescription;

use strict;
use warnings;
use Lib::XML;
use KeywordScan::detection;
use KeywordScan::Count;

my %HScans = ();
my $formula;
my $DEBUG = 0;

sub defaultValue($$) {
	my $default = shift;
	my $obtained = shift;
	
	if (!defined $obtained or $obtained eq "") {
		return $default;
	}
	
	return $obtained;
}

sub parseFile($) {
	my $file = shift;
	
	print "[KeywordScan] Loading: $file\n";
	my $projectRoot = Lib::XML::load_xml($file);
	
	if (! defined $projectRoot) {
		print STDERR "[KeywordScan] WARNING: no keyword found in $file !\n";
		return undef;
	}
	
	##################
	# XSD validation #
	##################
	use File::Basename;
    my $dir = dirname($0);
    my $schema_file = dirname($0)."\\KeywordScan\\KeywordModel.xsd";

	if (-e $schema_file)
	{
		print "[KeywordScan] Validating with XSD: $schema_file\n\n";
		my $schema = XML::LibXML::Schema->new(location => $schema_file);
		my $parser = XML::LibXML->new;
		my $doc    = $parser->parse_file($file);
		eval { $schema->validate($doc) };
		if ($@)
		{
			print "[KeywordScan] ERROR XML: $@\n";
			print STDERR "[KeywordScan] ERROR XML: $@\n";
		}
	}
	else 
	{
		print STDERR "[KeywordScan] ERROR XML: XSD not found: file xml not validated $file !\n";
	}
	
	if (! $@)
	{
		
		my %XML_version;
		
		foreach (Lib::XML::findnodes($projectRoot, '//keywordScan')) {

			my $keywordScan = $_ ;
			my $ScanName = Lib::XML::getAttribute($keywordScan, 'name');
			
			if (!exists $HScans{$ScanName}) {
				# New scan context
				$HScans{$ScanName} = [];
			}
			
			# my $versionXML = "noversion";
			
			foreach (Lib::XML::getChildren($keywordScan)) 
			{
				my $groupElement = $_ ;

				if ($groupElement->nodeName() eq "keywordGroup" or $groupElement->nodeName() eq "patternGroup") 
				{
					$XML_version{$ScanName} = $groupElement->nodeName();
					
					# DEFAULT VALUES (GROUP LEVEL)
					my $weight 	= defaultValue( 2, $groupElement->findvalue('./@weight'));
					my $sensitive 	= defaultValue( 0, $groupElement->findvalue('./@sensitive'));
					my $full_word	= defaultValue( 1, $groupElement->findvalue('./@full_word'));
					my $keyword	= defaultValue( "no_named", $groupElement->findvalue('./@name'));
					my $scope	= defaultValue( "all", $groupElement->findvalue('./@scope')) if ($groupElement->nodeName() eq "keywordGroup");
					
					# search associated items
					my ($keywordItem, $searchItem) = searchElements($groupElement, $weight, $sensitive, $full_word, $scope );            

					# store the keyword description.
					push @{$HScans{$ScanName}}, [$keyword, { 'keywordItem' => $keywordItem, 
					'searchItem' => $searchItem,
					'weight' => $weight, 'sensitive' => $sensitive, 
					'full_word' => $full_word, 'formula' => $formula, 'scope' => $scope}];				
				}	
				else
				{
					print STDERR "[KeywordScan] ERROR XML: unanalyzed element ".$groupElement->nodeName()."\n";
				}
			}
		}
		
		# store the metadata xml version
		KeywordScan::detection::setXmlVersion(\%XML_version);
		KeywordScan::Count::setXmlVersion(\%XML_version);

	}
}

sub parse($) {
	my $fileList = shift;
	
	for my $file (@$fileList) {
		parseFile($file);
	}
	
	return \%HScans;
}

sub searchElements($$$$;$)
{
    my $nodeParent = shift;
    my $weightKeywordGroup = shift;
    my $sensitiveKeywordGroup = shift;
    my $full_wordKeywordGroup = shift; 
    my $scopeKeywordGroup = shift;
    
    # initialize variables
    my %keywordItem = ();
    my %searchItem = ();
    $formula ='';

    foreach (Lib::XML::getChildren($nodeParent)) 
    {
        my $nodeChild = $_;
        
        # values by default keywordGroup
        my $weight    = $weightKeywordGroup;
        my $sensitive = $sensitiveKeywordGroup;
        my $full_word = $full_wordKeywordGroup;
        my $scope     = $scopeKeywordGroup if (defined $scopeKeywordGroup);
	
		# initialization: if attributes are available for KeyWordGroup version
		$sensitive = $nodeChild->findvalue('./@sensitive') if (defined $nodeChild->findvalue('./@sensitive') and $nodeChild->findvalue('./@sensitive') ne "");
		$full_word = $nodeChild->findvalue('./@full_word') if (defined $nodeChild->findvalue('./@full_word') and $nodeChild->findvalue('./@full_word') ne "");
		$scope = $nodeChild->findvalue('./@scope')         if ($nodeChild->findvalue('./@scope'));
	
		print "weight=$weight\n" if (defined ($weight) and $DEBUG ==1);
		print "sensitive_L1=<$sensitive>\n" if (defined ($sensitive) and $DEBUG ==1);
		print "full_word_L1=<$full_word>\n" if (defined ($full_word) and $DEBUG ==1);
		print "scope_L1=$scope\n" if (defined ($scope) and $DEBUG ==1);
	
		my $identKey;
		my $value;
		
		# KeyWordGroup version (scope attribute available)
		if ($nodeParent->nodeName() eq "keywordGroup")
		{
			if ($nodeChild->nodeName() eq "keywordItem") 
			{
				if ($nodeChild->findvalue('./@id'))
				{
					$identKey = $nodeChild->findvalue('./@id');
					$value = defaultValue("", $nodeChild->textContent());
		
				}
				else
				{
					$identKey = $value = $nodeChild->textContent();
				}
				push @{$keywordItem{ $identKey }},[$value, {'weight' => $weight,
				'sensitive' => $sensitive, 'full_word' => $full_word, 'scope' => $scope}];
			} 
		}
		
		# patternGroup version
		if ($nodeParent->nodeName() eq "patternGroup")
		{
			my $nodeChild_L1 = $nodeChild;

			if ($nodeChild_L1->nodeName() eq "formula")
			{
				$formula = $nodeChild_L1->findvalue('./@value');
			}
			
			foreach (Lib::XML::getChildren($nodeChild_L1)) 
			{
				if ($nodeChild_L1->nodeName() eq "patterns")
				{
					my $nodeChild_L2 = $_;

					if ($nodeChild_L2->nodeName() eq "search")
					{
						my $filename;
						my $content;
						my $regexContent;

						# initializing properties with default value for each search element
						$sensitive = $sensitiveKeywordGroup;
						$full_word = $full_wordKeywordGroup;
						###

						my $searchID = $nodeChild_L2->findvalue('./@id') if ($nodeChild_L2->findvalue('./@id'));
						print "---\nsearchID=$searchID\n" if (defined ($searchID) and $DEBUG ==1);
						
						# initialization: if attributes are available for patternGroup version
						$sensitive = $nodeChild_L2->findvalue('./@sensitive') if (defined $nodeChild_L2->findvalue('./@sensitive') and $nodeChild_L2->findvalue('./@sensitive') ne "");
						$full_word = $nodeChild_L2->findvalue('./@full_word') if (defined $nodeChild_L2->findvalue('./@full_word') and $nodeChild_L2->findvalue('./@full_word') ne "");
						print "sensitive_L2=<$sensitive>\n" if (defined ($sensitive) and $DEBUG ==1);
						print "full_word_L2=<$full_word>\n" if (defined ($full_word) and $DEBUG ==1);
						
						foreach (Lib::XML::getChildren($nodeChild_L2)) 
						{
							my $nodeChild_L3 = $_;
						
							if ($nodeChild_L3->nodeName() eq "filename")
							{
								$filename = $nodeChild_L3->findvalue('.'); 
							}
							elsif ($nodeChild_L3->nodeName() eq "content")
							{
								$content = $nodeChild_L3->findvalue('.'); 
							}
							elsif ($nodeChild_L3->nodeName() eq "regexContent")
							{
								$full_word = 0; # Option not displayed in csv but force value to 0
								$regexContent = $nodeChild_L3->findvalue('.');
								if (defined $regexContent) {
									eval { qr /$regexContent/ } ;
									if ($@) {
										print STDERR "[KeywordScan] ERROR REGEX: $@\n";
										$regexContent = "INVALID_REGEX";
									}
								}
							}
						}
						
						push @{$searchItem{ $searchID }},{'filename' => $filename,
						'content' => $content, 'regexContent' => $regexContent, 'weight' => $weight,
						'sensitive' => $sensitive, 'full_word' => $full_word};
					}
				}
			}
        }

    }
    # valid syntax formula
    if ($formula)
    {
        my %items = (%keywordItem, %searchItem);
        $formula = validSyntaxFormula($formula, \%items);
    }  
    return (\%keywordItem, \%searchItem);
}

sub validSyntaxFormula($$)
{
    my $formula = shift;
    my $items = shift;

    my $bool_formula = 0;
    my $error = "[KeywordScan] ERROR XML:invalid formula: [$formula]\n";
    
    foreach my $keyword (keys %{$items})
    {    
        if ($formula !~ /\b$keyword\b/ )
        {
            $error .= "-> keyword <$keyword> is missing\n";
            $bool_formula = 1;
        }    
    }

    while ($formula =~ /(\w+)/g)
    {
        if (lc($1) ne 'and' and lc($1) ne 'or')
        {
            if(not exists $items->{$1}) 
            {
                $error .= "-> keyword <$1> is in excess (not present into keywordGroup)\n";
                $bool_formula = 1;
            }
        }
    }
    
    if ($formula =~ /[\+\-\*\/]+/ and $formula =~ /\band\b|\bor\b/i)
    {
        $error .= "-> logical and mathematic operator found\n";
        $bool_formula = 1;
    }
    
    if ($bool_formula == 1)
    {
        print STDERR "$error\n\n";
        return 'INVALID';
    }
    else
    {
        # replace by logical operator
        $formula =~ s/\band\b/&&/ig;
        $formula =~ s/\bor\b/||/ig;
        
        return $formula;
    }

}

1;
