package JSP::CountJSP;

use strict;
use warnings;

use Erreurs;

use Lib::NodeUtil;
use JSP::JSPScriptNode;
use JSP::Scope;
require JSP::GlobalMetrics;

my $MissingErrorPage__mnemo = Ident::Alias_MissingErrorPage();
my $JavaBean__mnemo = Ident::Alias_JavaBean();
my $BadFileExtension__mnemo = Ident::Alias_BadFileExtension();
my $BadFileLocation__mnemo = Ident::Alias_BadFileLocation();
my $BadTldLocation__mnemo = Ident::Alias_BadTldLocation();
my $BadTldContent__mnemo = Ident::Alias_BadTldContent();
my $HtmlLOC__mnemo = Ident::Alias_HtmlLOC();
my $MissingCDATA__mnemo = Ident::Alias_MissingCDATA();
my $BadSequenceOrder__mnemo = Ident::Alias_BadSequenceOrder();
my $UnnecessaryDeclarationTag__mnemo = Ident::Alias_UnnecessaryDeclarationTag();
my $TabIndentation__mnemo = Ident::Alias_TabIndentation();
my $MissingSpaceInTag__mnemo = Ident::Alias_MissingSpaceInTag();
my $MixedTagFormat__mnemo = Ident::Alias_MixedTagFormat();
my $UnexpectedSimpleQuoteStr__mnemo = Ident::Alias_UnexpectedSimpleQuoteStr();
my $MissingShortTag__mnemo = Ident::Alias_MissingShortTag();
my $HtmlComment__mnemo = Ident::Alias_HtmlComment();
my $StdScriptlet__mnemo = Ident::Alias_StdScriptlet();
my $XmlScriptlet__mnemo = Ident::Alias_XmlScriptlet();
my $TagLib__mnemo = Ident::Alias_TagLib();
my $StdDeclaration__mnemo = Ident::Alias_StdDeclaration();
my $XmlDeclaration__mnemo = Ident::Alias_XmlDeclaration();
my $StdExpression__mnemo = Ident::Alias_StdExpression();
my $XmlExpression__mnemo = Ident::Alias_XmlExpression();
my $StdDirective__mnemo = Ident::Alias_StdDirective();
my $XmlDirective__mnemo = Ident::Alias_XmlDirective();
my $JSPComment__mnemo = Ident::Alias_JSPComment();
my $BadJavaScriptInclude__mnemo = Ident::Alias_BadJavaScriptInclude();
my $UnsecuredWebsite__mnemo = Ident::Alias_UnsecuredWebsite();
my $LinesOfCode__mnemo = Ident::Alias_LinesOfCode();
my $ImplicitClosing__mnemo = Ident::Alias_ImplicitClosing();
my $UntrustedInputData__mnemo = Ident::Alias_UntrustedInputData();
my $MissingCatch__mnemo = Ident::Alias_MissingCatch();

my $nb_MissingErrorPage = 0;
my $nb_JavaBean = 0;
my $nb_BadFileExtension = 0;
my $nb_BadFileLocation = 0;
my $nb_BadTldLocation = 0;
my $nb_BadTldContent = 0;
my $nb_HtmlLOC = 0;
my $nb_MissingCDATA = 0;
my $nb_BadSequenceOrder = 0;
my $nb_UnnecessaryDeclarationTag = 0;
my $nb_TabIndentation = 0;
my $nb_MissingSpaceInTag = 0;
my $nb_MixedTagFormat = 0;
my $nb_UnexpectedSimpleQuoteStr = 0;
my $nb_MissingShortTag = 0;
my $nb_HtmlComment = 0;
my $nb_StdScriptlet = 0;
my $nb_XmlScriptlet = 0;
my $nb_TagLib = 0;
my $nb_StdDeclaration = 0;
my $nb_XmlDeclaration = 0;
my $nb_StdExpression = 0;
my $nb_XmlExpression = 0;
my $nb_StdDirective = 0;
my $nb_XmlDirective = 0;
my $nb_JSPComment = 0;
my $nb_BadJavaScriptInclude = 0;
my $nb_UnsecuredWebsite = 0;
my $nb_LinesOfCode = 0;
my $nb_ImplicitClosing = 0;
my $nb_UntrustedInputData = 0;
my $nb_MissingCatch = 0;

sub _cb_CountErrorPage($$) {
	my ($node, $context) = @_;

	my $stmt = Lib::NodeUtil::GetStatement($node);

	my $REG_STD_DIRECTIVE = qr /\A<\%\@\s*page\b/s;
	my $REG_XML_DIRECTIVE = qr /\A<jsp:directive.page\b/s;
	
	
	if (($$stmt =~ /$REG_STD_DIRECTIVE/) || ($$stmt =~ /$REG_XML_DIRECTIVE/)){
		if ($$stmt =~ /(?:(\berrorPage=)|\bisErrorPage\s*=\s*(\w+))/) {
			if (defined $1) {
				# found "errorPage="
				$context->[1] = 1;
			}
			else {
				# found "bisErrorPage="true"
				my $strings = $context->[2];
				if ($strings->{$2} =~ /["']true["']/) {
					$context->[0] = 1;
				}
			}
		}
	}
	return undef;
}

sub CountMissingErrorPage($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;
    
    my $nb_MissingErrorPage = 0;
    
    my $tags = $vue->{'tag_tree'};
    my $global_metrics = $vue->{'global_context'}->{'GlobalMetrics'};
    my $strings = $vue->{'script_string'}->{'strings_values'};
    
    if ((! defined $tags) || (! defined $strings)){
		$ret |= Couples::counter_add($compteurs, $MissingErrorPage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
    
    # Is the error page positionned by default in the web.xml ? 
    my $WebXmlErrorPage = 0;
    
    my $appli = JSP::GlobalMetrics::getAppli($fichier, $global_metrics);
    if (defined $appli) {
		$WebXmlErrorPage = $appli->[1]->{'WebXmlErrorPage'};
	}
	
	# If error page is not defined in web.xml ...
    if (! $WebXmlErrorPage) {
		my $isAnErrorPage = 0;
		my $referenceAnErrorPage = 0;

		my @context = (0, 0, $strings);
		Lib::Node::Iterate($tags, 0, \&_cb_CountErrorPage, \@context);
    
		if ((! $context[0]) && (! $context[1])) {
			$nb_MissingErrorPage++;
		}
	}
    
    $ret |= Couples::counter_add($compteurs, $MissingErrorPage__mnemo, $nb_MissingErrorPage );
    
    return $ret;
}

sub CountJSP($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;
    
    $nb_StdScriptlet = 0;
    $nb_XmlScriptlet = 0;
    $nb_TagLib = 0;
    $nb_JavaBean = 0;
    
    # "script" is the vue containing the jSP tags.
    my $script = $vue->{'script'};
    
    if ( ! defined $script ) {
		$ret |= Couples::counter_add($compteurs, $StdScriptlet__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $XmlScriptlet__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $TagLib__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $JavaBean__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
#print "SEARCHING TAGS :\n";
	while ($script =~ /<(?:(\%@)|(\%!)|(\%-)|(\%=)|(\%[^@!-=])|(\w+:\w+))/sg) {
		if (defined $5) {
			$nb_StdScriptlet++;
#print "--> FOUND <%\n";
		}
		elsif (defined $6) {
			my $tag = $6;
			if ($tag =~ /jsp:useBean/i) {
				$nb_JavaBean++;
			}
			elsif ($tag =~ /jsp:(?:scriptlet)/i) {
#print "--> FOUND jsp:scriptlet\n";
				$nb_XmlScriptlet++;
			}
			elsif ($tag =~ /jsp:/i) {
				# certainly jsp:setProperty or jsp:getProperty or jsp:(expression|declaration|directive)
			}
			else {
				# it's a tag lib ...
				$nb_TagLib++;
			}
		}
	}
	
	$ret |= Couples::counter_add($compteurs, $StdScriptlet__mnemo, $nb_StdScriptlet );
	$ret |= Couples::counter_add($compteurs, $XmlScriptlet__mnemo, $nb_XmlScriptlet );
	$ret |= Couples::counter_add($compteurs, $TagLib__mnemo, $nb_TagLib );
	$ret |= Couples::counter_add($compteurs, $JavaBean__mnemo, $nb_JavaBean );
}

sub isFragment($$) {
	my $filename = shift;
	my $buf = shift;
	
	if ($filename =~ /\.jspf$/) {
		return 1;
	}
	
	if ($$buf =~ /<html\b/i) {
		return 0;
	}
	
	return 1;
}

sub CountFragment($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;
    
    $nb_BadFileExtension = 0;
    $nb_BadFileLocation = 0;
    
    # "code" is the vue containing the jSP tags.
    my $html = \$vue->{'html'};
    my $global_metrics = $vue->{'global_context'}->{'GlobalMetrics'};
    
    if ( ! defined $$html ) {
		$ret |= Couples::counter_add($compteurs, $BadFileExtension__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadFileLocation__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	if (isFragment($fichier, $html)) {
		if ($fichier !~ /\.jspf$/m ) {
			$nb_BadFileExtension=1;
		}

# NOTE : The code into comment allow to count a violation only if the file belongs to an application
#		identified by the presence of a WEB-INF directory. If there is no WEB-INF directory (getAppli returning undef),
#		then we consider that the file do not belongs to an application, AND THEN we do not test if the file is situated
#		inside the WEB-INF directoruy or not.
#		This option is desactivated, that's why the code is commented out. We consider that if fragments are used, then
# 		a WEB-INF should be created !!
#my $appli = JSP::GlobalMetrics::getAppli($fichier, $global_metrics);
#if (defined $appli) {
		if ($fichier !~ /\bWEB-INF[\\\/]/m ) {
			$nb_BadFileLocation=1;
#print "==> Bad File Location !!!\n";
		}
#}
	}
	$ret |= Couples::counter_add($compteurs, $BadFileExtension__mnemo, $nb_BadFileExtension );
	$ret |= Couples::counter_add($compteurs, $BadFileLocation__mnemo, $nb_BadFileLocation );
}

sub CountTld($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;
    
    $nb_BadTldLocation = 0;
    $nb_BadTldContent = 0;
    
    # "code" is the vue containing the jSP tags.
    my $html = \$vue->{'html'};
    my $global_metrics = $vue->{'global_context'}->{'GlobalMetrics'};
    
    if ( ! defined $$html ) {
		$ret |= Couples::counter_add($compteurs, $BadTldLocation__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadTldContent__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	# like web.xml, tld file are not counted as analyzed files. The counters related to them
	# are reported to each file of the same application.	
	my $appli = JSP::GlobalMetrics::getAppli($fichier, $global_metrics);
	
	if (defined $appli) {
		$nb_BadTldLocation=$appli->[1]->{'BadTldLocation'};
		$nb_BadTldContent=$appli->[1]->{'BadTldContent'};
		if (! defined $nb_BadTldLocation) {
			$nb_BadTldLocation = 0;
		}
		if (! defined $nb_BadTldContent) {
			$nb_BadTldContent = 0;
		}
	}
	
	$ret |= Couples::counter_add($compteurs, $BadTldLocation__mnemo, $nb_BadTldLocation );
	$ret |= Couples::counter_add($compteurs, $BadTldContent__mnemo, $nb_BadTldContent );
}

sub CountHtmlLOC($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;
    
    $nb_HtmlLOC=0;
    
    if (! defined $vue->{'html'}) {
		$ret |= Couples::counter_add($compteurs, $HtmlLOC__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
    
    $nb_HtmlLOC = () = $vue->{'html'} =~ /\S[^\n]*\n/smgo;
    
    $ret |= Couples::counter_add($compteurs, $HtmlLOC__mnemo, $nb_HtmlLOC );
}

sub CountMissingCDATA($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;
    
    $nb_MissingCDATA=0;
    
    my $kinds = $vue->{'kinds'};
    
    if (! defined $kinds) {
		$ret |= Couples::counter_add($compteurs, $MissingCDATA__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
    
    # in the tree model, a XML_JSP_TEXT is created for each jsp:scriplet, jsp:declaration and jsp:expression.
    # This XML_JSP_TEXT node contains the content of jsp:scriplet, jsp:declaration and jsp:expression, that is "text" java code source.
    # If this code is embedded in a CDATA structure, then a CDATA node is created too. In strict XML format, the CDATA is required.
    
    # For each XML_JSP_TEXT node, search if the first node is a CDATA.
    for my $node (@{$kinds->{XML_JSP_TEXT}}) {
#print "Node XML_JSP_TEXT\n";
		my $children = Lib::NodeUtil::GetChildren($node);
		if (scalar @$children > 0) {
			if (! IsKind($children->[0], CDATA)) {
				$nb_MissingCDATA++;
#print "---> Missing CDATA (no CDATA children)\n";
			}
		}
		else {
			$nb_MissingCDATA++;
#print "---> Missing CDATA (no chidren)\n";
		}
	}
    
    $ret |= Couples::counter_add($compteurs, $MissingCDATA__mnemo, $nb_MissingCDATA );
} 


my $ORDER_COMMENT = 1;
my $ORDER_PAGE_DIRECTIVE = 2;
my $ORDER_LIB_DIRECTIVE = 3;
my $ORDER_DECLARATION = 4;
my $ORDER_OTHER = 5;

sub _cb_BadSequenceOrder() {
	my ($node, $context) = @_;
	
	my $currentOrder = $context->[0];
	
#print "CURRENT ORDER: $$currentOrder\n";
	my $kind = Lib::NodeUtil::GetKind($node);
#print "KIND: $kind\n";
	my $order = $ORDER_OTHER;
	
	if ($kind eq STD_JSP_DIRECTIVE) {
		my $stmt = Lib::NodeUtil::GetStatement($node);
		
		# check for standard "page" directive
		if ($$stmt =~ /<%\s*\@\s*page\b/) {
			$order = $ORDER_PAGE_DIRECTIVE;
		}
		# check for standard "taglib" directive
		elsif ($$stmt =~ /<%\s*\@\s*taglib\b/) {
			$order = $ORDER_LIB_DIRECTIVE;
		}
	}
	elsif ($kind eq STD_JSP_TAG) {
		my $stmt = Lib::NodeUtil::GetStatement($node);
		
		# check for standard declaration
		if ($$stmt =~ /<%\s*!/) {
			$order = $ORDER_DECLARATION;
			$nb_UnnecessaryDeclarationTag++;
		}
	}
	elsif ($kind eq XML_JSP_TAG) {
		my $stmt = Lib::NodeUtil::GetStatement($node);
		
		# check for standard "page" directive
		if ($$stmt =~ /<jsp:directive.page\b/) {
			$order = $ORDER_PAGE_DIRECTIVE;
		}
		# check for standard "taglib" directive
		elsif ($$stmt =~ /<jsp:directive.taglib\b/) {
			$order = $ORDER_LIB_DIRECTIVE;
		}
		# check for standard declaration
		elsif ($$stmt =~ /<jsp:declaration\b/) {
			$order = $ORDER_DECLARATION;
			$nb_UnnecessaryDeclarationTag++;
		}
		# check for standard "useBean" directive
		elsif ($$stmt =~ /<jsp:useBean\b/) {
			$order = $ORDER_LIB_DIRECTIVE;
		}
	}
	elsif (($kind eq HTML_COMMENT) || ($kind eq JSP_COMMENT)) {
		# Comments can be placed anywhere : there are always in phase with the current order !
		$order = $$currentOrder;
	}
	elsif ($kind eq HTML) {
		# HTML_root is the root node : its content must be analyzed !!!
		# All other HTML should not be encountered before JSP directives and declaration, 
		# so we affect them the "OTHER" order, like scriptlet, ...
		if (Lib::NodeUtil::GetName($node) eq 'HTML_root') {
			return undef; # Analyze subnode
		}
		else {
			$order = $ORDER_OTHER;
		}
	}
	else {
		# If the node is not a page directive, a taglib directive or a jsp declaration, then we consider the beginning part of the
		# jsp is ended, and we are in the HTML part. (containing HTML code, scriptlet, jsp expression, use of tag lib, ...)
#print "ENCOUTERED OTHER: $kind !!!\n";
		$order = $ORDER_OTHER;
	}

	if ($order >= $$currentOrder) {
#print "--> NEW ORDER: $order\n";
		$$currentOrder = $order;
	}
	else {
		# Add one violation
		$nb_BadSequenceOrder=1;
#print "---> BAD ORDER VIOLATION($order < $$currentOrder)\n";
		#return 1; # STOP
	}
	
	return 0; # do not step into child node.
}


# !!! Work with first level tags only  !!!
sub CountBadSequenceOrder($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;
	
	$nb_BadSequenceOrder = 0;
	$nb_UnnecessaryDeclarationTag = 0;
	
	my $tags = $vue->{'tag_tree'};
    
    if ( ! defined $tags ) {
		$ret |= Couples::counter_add($compteurs, $BadSequenceOrder__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnnecessaryDeclarationTag__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $order = 0;
	
	my @context = (\$order);
	Lib::Node::Iterate($tags, 0, \&_cb_BadSequenceOrder, \@context);
	
	# At this step, $nb_UnnecessaryDeclarationTag contains the number of declaration tags.
	# Decrease the number of declarations found to compute the number of supplementary (unnecessary) declarations.
	if ($nb_UnnecessaryDeclarationTag > 0) {
		$nb_UnnecessaryDeclarationTag--;
	}
	
	$ret |= Couples::counter_add($compteurs, $BadSequenceOrder__mnemo, $nb_BadSequenceOrder );
	$ret |= Couples::counter_add($compteurs, $UnnecessaryDeclarationTag__mnemo, $nb_UnnecessaryDeclarationTag );
}



sub countBadString($$) {
	my $stmt = shift;
	my $strings = shift;
	
	my $nb = 0;
	
	while ($$stmt =~ /(CHAINE_\d+)/g ) {
		if (isBadSimpleQuote(\$strings->{$1})) {
			$nb++;
		}
	}
	return $nb;
}

sub checkShortTag($$) {
	my $node = shift;
	my $stmt = shift;
	my $children = Lib::NodeUtil::GetChildren($node);

	# if not a short tag ( not in the form <...../> )
	if ($$stmt !~ /\/>\Z/) {
		my $should_be_short = 1;
		
		# if a child different from JSP_STRING can be found, then the tag is not considered empty
		# and so can not be written in short format.
		for my $child (@$children) {
			my $childKind = Lib::NodeUtil::GetKind($child);
			if ( $childKind ne JSP_STRING) {
				$should_be_short=0;
			}
		}
		
		if ($should_be_short) {
			$nb_MissingShortTag++;
#print "--> MISSING short tag : $$stmt !!!\n";
		}
	}
}

sub isBadJavascriptInclude($$) {
	my $stmt = shift;
	my $strings = shift;
	
	if ($$stmt =~ /(?:<%@\s*|<jsp:(?:directive.)?)include\b.*file\s*=\s*(\w+)/s) {
		if (defined $1) {
			my $value = $strings->{$1};
			if ((defined $value) && ($value =~ /["'].*\.js["']$/)) {
				return 1;
			}
		}
	}
	return 0;
}

sub _cb_Tags() {
	my ($node, $context) = @_;
	
	my $previousTag = $context->[2];
	
	my $kind = Lib::NodeUtil::GetKind($node);
	my $stmt = Lib::NodeUtil::GetStatement($node);

	if ($kind eq STD_JSP_DIRECTIVE) {
		# STD tags ++
		${$context->[0]} += 1;
		$nb_StdDirective++;
		
		$nb_BadJavaScriptInclude += isBadJavascriptInclude($stmt, $context->[3]);
	}
	elsif ($kind eq STD_JSP_TAG) {
		# STD tags ++
		${$context->[0]} += 1;
		my $name = Lib::NodeUtil::GetName($node);
		if ($name =~ /\A<%!/) {
			$nb_StdDeclaration++;
		}
		elsif ($name =~ /\A<%=/) {
			$nb_StdExpression++;
		}
	}
	elsif ($kind eq XML_JSP_TAG) {
		# XML tags ++
		${$context->[1]} += 1;
		# XML tags can have a short format. Check it ...
		checkShortTag($node, $stmt);
		my $name = Lib::NodeUtil::GetName($node);
		if ($name =~ /\A<jsp:expression/) {
			$nb_XmlExpression++;
		}
		elsif ($name =~ /\A<jsp:declaration/) {
			$nb_XmlDeclaration++;
		}
		elsif ($name =~ /\A<jsp:directive/) {
			$nb_XmlDirective++;
		}
		
		$nb_BadJavaScriptInclude += isBadJavascriptInclude($stmt, $context->[3]);
	}
	elsif ($kind eq JSP_TAG_LIB) {
		# JSP tags can have a short format. Check it ...
		checkShortTag($node, $stmt);
		$nb_TagLib++;
	}
	elsif ($kind eq HTML_COMMENT) {
		# JSP tags can have a short format. Check it ...
		$nb_HtmlComment++;
	}
	elsif ($kind eq JSP_COMMENT) {
		# JSP tags can have a short format. Check it ...
		$nb_JSPComment++;
	}

	$$previousTag = $kind;

	# Do not check space in JSP comments.
	if (($kind ne HTML) && ($kind ne JSP_COMMENT)) {
		# Search patterns:
		#     <%xxx  OR <%[@=!]xxx  OR  xxx%>  OR  "xxx"%>
		# NOTE: for the last pattern, "CHAINE_\d+ %>" is searched because strings are encoded and a space is added after them !!
		if ($$stmt =~ /(\A<\%[^\@=!\s]|\A<\%[\@=!]\S|\S\%>|CHAINE_\d+ %>)/) {
			$nb_MissingSpaceInTag++;
#print "MISSING SPACE in $kind : $$stmt -> ($1)\n";
		}
	}

	return undef;
}


# !!! Work all tags !!!
sub CountTags($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;
	
	$nb_MissingSpaceInTag = 0;
	$nb_MixedTagFormat = 0;
	$nb_MissingShortTag = 0;
	$nb_HtmlComment = 0;
	$nb_StdDeclaration = 0;
	$nb_XmlDeclaration = 0;
	$nb_StdExpression = 0;
	$nb_XmlExpression = 0;
	$nb_StdDirective = 0;
	$nb_XmlDirective = 0;
	$nb_JSPComment = 0;
	$nb_BadJavaScriptInclude = 0;
	
	my $tags = $vue->{'tag_tree'};
	my $strings = $vue->{'script_string'};
    
    if ( ! defined $tags ) {
		$ret |= Couples::counter_add($compteurs, $MissingSpaceInTag__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MixedTagFormat__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MissingShortTag__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $HtmlComment__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $StdDeclaration__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $XmlDeclaration__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $StdExpression__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $XmlExpression__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $StdDirective__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $XmlDirective__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $JSPComment__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadJavaScriptInclude__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $order = 0;
	
	my $nbStdTags = 0;
	my $nbXmlTags = 0;
	my $previousTag = "";
	my @context = (\$nbStdTags, \$nbXmlTags, \$previousTag, $strings->{'strings_values'});
	Lib::Node::Iterate($tags, 0, \&_cb_Tags, \@context);
	
	if (($nbStdTags > 0) && ($nbXmlTags)) {
		$nb_MixedTagFormat = 1;
	}
	
	$ret |= Couples::counter_add($compteurs, $MissingSpaceInTag__mnemo, $nb_MissingSpaceInTag );
	$ret |= Couples::counter_add($compteurs, $MixedTagFormat__mnemo, $nb_MixedTagFormat );
	$ret |= Couples::counter_add($compteurs, $MissingShortTag__mnemo, $nb_MissingShortTag );
	$ret |= Couples::counter_add($compteurs, $HtmlComment__mnemo, $nb_HtmlComment );
	$ret |= Couples::counter_add($compteurs, $StdDeclaration__mnemo, $nb_StdDeclaration );
	$ret |= Couples::counter_add($compteurs, $XmlDeclaration__mnemo, $nb_XmlDeclaration );
	$ret |= Couples::counter_add($compteurs, $StdExpression__mnemo, $nb_StdExpression );
	$ret |= Couples::counter_add($compteurs, $XmlExpression__mnemo, $nb_XmlExpression );
	$ret |= Couples::counter_add($compteurs, $StdDirective__mnemo, $nb_StdDirective );
	$ret |= Couples::counter_add($compteurs, $XmlDirective__mnemo, $nb_XmlDirective );
	$ret |= Couples::counter_add($compteurs, $JSPComment__mnemo, $nb_JSPComment );
	$ret |= Couples::counter_add($compteurs, $BadJavaScriptInclude__mnemo, $nb_BadJavaScriptInclude );
	return $ret;
}

sub CountIndentation($$$) {
	my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;
	
	$nb_TabIndentation = 0;
	my $line = 1;
	while ($vue->{'script'} =~ /^ *(\t)?[\s ]*\S/mg) {
		if (defined $1) {
			$nb_TabIndentation++;
		}
		$line++;
	}

	$ret |= Couples::counter_add($compteurs, $TabIndentation__mnemo, $nb_TabIndentation );
	return $ret;
}

sub isBadSimpleQuote($) {
  my $value = shift;
  if ( $$value =~ /\A'(.*)'\z/s ) {
    if ( $1 !~ /"/s ) {
      return 1;
    }
  }
  return 0;
}

sub CountString($$$) {
	my ($fichier, $view, $compteurs) = @_ ;
    my $ret = 0;
	
	$nb_UnexpectedSimpleQuoteStr = 0;
	
	my $strings = $view->{'script_string'};
	if ( ! defined $strings ) {
		$ret |= Couples::counter_add($compteurs, $UnexpectedSimpleQuoteStr__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	for my $strkey (keys %{$strings->{'strings_values'}}) {
#print "STRING KEY : $strkey\n";
		my $strvalue = $strings->{'strings_values'}->{$strkey};
		if (isBadSimpleQuote(\$strvalue)) {
			my $nb_violations = $strings->{'strings_counts'}->{$strvalue}->[1];
			# only for robustness but should not occur !!!
			if (! defined $nb_violations) {
				$nb_violations = 1;
				print STDERR "WARNING: strings_counts datas not available !!!\n";
			}
			$nb_UnexpectedSimpleQuoteStr += $nb_violations;
#print "---> BAD STRING : $strkey\n";
		}
	}
	$ret |= Couples::counter_add($compteurs, $UnexpectedSimpleQuoteStr__mnemo, $nb_UnexpectedSimpleQuoteStr );
	return $ret;
}

sub CountUnsecuredWebsite($$$) {
	my ($fichier, $view, $compteurs) = @_ ;
	my $ret = 0;
	
	$nb_UnsecuredWebsite = 0;
	
	my $global_metrics = $view->{'global_context'}->{'GlobalMetrics'};
	
	if ( ! defined $global_metrics ) {
		$ret |= Couples::counter_add($compteurs, $UnsecuredWebsite__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
 
	for my $appli (@$global_metrics) {
		my $appli_path = quotemeta $appli->[0];
		if ($fichier =~ /\A$appli_path/) {
			if (! $appli->[1]->{'WebXmlIsSecured'}) {
				$nb_UnsecuredWebsite = 1;
				last;
			}
		}
	}

	$ret |= Couples::counter_add($compteurs, $UnsecuredWebsite__mnemo, $nb_UnsecuredWebsite );
	return $ret;
}

sub CountLinesOfCode($$$) {
	my ($fichier, $view, $compteurs) = @_ ;
	my $ret = 0;
	
	$nb_LinesOfCode = 0;

	if ( ! defined $view->{'code'} ) {
		$ret |= Couples::counter_add($compteurs, $LinesOfCode__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

    $nb_LinesOfCode = () = $view->{'code'} =~ /\S[^\n]*\n/smgo;
    
    # Remove the two lines added by the parser to simulate a sctiplet class !
	$nb_LinesOfCode -= 2;
	
	$ret |= Couples::counter_add($compteurs, $LinesOfCode__mnemo, $nb_LinesOfCode );
	return $ret;
}

sub CountImplicitClosing($$$) {
	my ($fichier, $view, $compteurs) = @_ ;
	my $ret = 0;

	$nb_ImplicitClosing = 0;

	if ( ! defined $view->{'strip_info'} ) {
		$ret |= Couples::counter_add($compteurs, $ImplicitClosing__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	if (defined $view->{'strip_info'}->{'ImplicitClosing'}) {

		$nb_ImplicitClosing += $view->{'strip_info'}->{'ImplicitClosing'};
	}
	
	# Ambigous closing are counted as ImplicitClosing.
	if (defined $view->{'strip_info'}->{'AmbigousClosing'}) {

		$nb_ImplicitClosing += $view->{'strip_info'}->{'AmbigousClosing'};
	}
	
	$ret |= Couples::counter_add($compteurs, $ImplicitClosing__mnemo, $nb_ImplicitClosing );
	return $ret;
}






sub CountUntrustedInputData($$$) {
	my ($fichier, $view, $compteurs) = @_ ;
	my $ret = 0;
	
	$nb_UntrustedInputData = 0;

	if (( ! defined $view->{'script'} ) || ( ! defined $view->{'code'} )) {
		$ret |= Couples::counter_add($compteurs, $UntrustedInputData__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $script = \$view->{'script'};
	my $code = \$view->{'code'};
	
	my $DataGetter = '(?:getParameter)\b';
	
	# VIOLATION:	<%= Ident2.getParameter(
	$nb_UntrustedInputData += () = $$script =~ /<\%=\s*\w+\.$DataGetter\s*\(/g;
	
	# VIOLATION:	[+-*/] Ident2.getParameter(
	$nb_UntrustedInputData += () = $$script =~ /[+\-*\/]\s*\w+\.$DataGetter\s*\(/g;
	
	# VIOLATION: 	fct(Ident2.getParameter(          
	# 	=> passing to function parameter, potentially without being checked ...
	while ($$script =~ /(\w+)\s*\(\s*\w+\.$DataGetter\s*\(/g) {
		 if ($1 ne 'if') {
			$nb_UntrustedInputData ++
		}
	}
	
	# VIOLATION:	,Ident2.getParameter(
	#	=> passing to function parameter, potentially without being checked ...
	$nb_UntrustedInputData += () = $$script =~ /,\s*\w+\.$DataGetter\s*\(/g;
	
	# VIOLATION:	Ident1 = (cast)? Ident2.getParameter(  
	#	=> ident1 should be used in a "if" …
	my @idents = ();
	my $getterPattern = '(\w+)\s*=\s*(?:\(\s*\w+\s*\))?\s*\w+\.'.$DataGetter.'\s*\(';
	my $scopeOpenning = '{';
	my $scopeClosing = '}';
	my $ifCond = '\bif\s*\(';
	
	# data are:
	# 	- a list of ident declared in the scope
	#	- a list of "if "conditions used in the scope.
	use constant SCOPE_IDENTS => 0;
	use constant SCOPE_CONDS => 1;
	
	my $scope = JSP::Scope::enterNewScope(undef);

	# CAPTURE identifiers associed with input data AND  "if" conditions, with their respective scope.
	# The aim is to check if an input data is tested in a if present in its scope !
	#
	# (in the following regexpr, no capture parenthesises around $getterPattern because it encloses its own capture parenthesis in itself.)
	while ($$code =~ /($scopeOpenning)|($scopeClosing)|$getterPattern|($ifCond)/sg) {
		# SCOPE OPENNING
		if (defined $1) {
			$scope = JSP::Scope::enterNewScope($scope);
		}
		# SCOPE CLOSING
		elsif (defined $2) {
			$scope = JSP::Scope::leaveScope($scope);
			if (!defined $scope) {
				print "[ERROR] undefined scope !!\n";
				last;
			}
		}
		# PARAMETER GETTER 
		elsif (defined $3) {
			my $ident = $3;
			# store the ident.
			push @idents, JSP::Scope::addScopeData($scope, $ident, SCOPE_IDENTS);
		}
		# IF
		elsif (defined $4) {
			my $cond = "";
			my $parentLevel = 1;
			while ($$code =~ /(.)/sg) {
				if ($1 eq '(') {
					$parentLevel++;
				}
				elsif ($1 eq ')') {
					$parentLevel--;
				}
				
				if ($parentLevel == 0) {
					JSP::Scope::addScopeData($scope, $cond, SCOPE_CONDS);
					if (( ! defined $view->{'script'} ) || ( ! defined $view->{'code'} )) {
		$ret |= Couples::counter_add($compteurs, $UntrustedInputData__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}	last;
				}
				else {
					$cond .= $1;
				}
			}
		}
	}
	
	#while ($$script =~ /(\w+)\s*=\s*(?:\(\s*\w+\s*\))?\s*\w+\.$DataGetter\s*\(/g) {
	#	push @idents, $1;
	#}
	for my $ident (@idents) {
		my $identValue = JSP::Scope::getDataValue($ident);
		my $identScope = JSP::Scope::getDataScope($ident);
		my $identTested = 0;
		# for the scope and all subscope ...
		my @subscopes = Lib::NodeUtil::GetNodesByKind($identScope, JSP::Scope::ScopeKind);
		SCOPE_SCANNING : for my $scp ( ($identScope, @subscopes) ) {
			# ... get the list of conditions.
			my $conds = JSP::Scope::getData($scp, SCOPE_CONDS);
			# For each condition :
			for my $cond (@$conds) {
				my $condValue = JSP::Scope::getDataValue($cond);
				# if the condition contains the ident, then consider the ident is tested ...
				if ($condValue =~ /\b$identValue\b/) {
					$identTested = 1;
					last SCOPE_SCANNING;
				}
			}
		}
		if (! $identTested) {
			$nb_UntrustedInputData++;
		}
	}
	
	$ret |= Couples::counter_add($compteurs, $UntrustedInputData__mnemo, $nb_UntrustedInputData );
	return $ret;
}

sub CountMissingCatch($$$) {
	my ($fichier, $view, $compteurs) = @_ ;
	my $ret = 0;
	
	$nb_MissingCatch = 0;

	if ( ! defined $view->{'code'} ) {
		$ret |= Couples::counter_add($compteurs, $UntrustedInputData__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my $code = \$view->{'code'};
	
	my %TabAccess = ();
	while ($$code =~ /(\w+)\s*\[\s*([a-zA-Z_]\w*)/sg) {
		$TabAccess{$1."[".$2."]"} = 1;
#print "Found tab acces : $1\[$2\]\n";
	}
	my $nb_TabAccess = scalar keys %TabAccess;
	my $nb_ParseInt = () = $$code =~ /\.parse(?:Int|Float|Double)\s*\(/sg;
	my $nb_While = () = $$code =~ /\bwhile\b/sg;
	my $nb_Catch = () = $$code =~ /\bcatch\b/sg;

#print "TabAcess : $nb_TabAccess\n";
#print "ParseInt : $nb_ParseInt\n";
#print "While : $nb_While\n";
#print "Catch : $nb_Catch\n";

	if (! $nb_Catch){
		$nb_MissingCatch+= 2*$nb_ParseInt + 2*$nb_TabAccess + $nb_While + $nb_While * $nb_TabAccess; 
	}
#print "MISSING CATCH = $nb_MissingCatch\n";
	$ret |= Couples::counter_add($compteurs, $MissingCatch__mnemo, $nb_MissingCatch );
	return $ret;
}

1;

