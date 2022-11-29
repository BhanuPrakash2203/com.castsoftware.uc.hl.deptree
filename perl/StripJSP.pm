package StripJSP ;

use strict;
use warnings;
use Carp::Assert;                                                               # traces_filter_line
use Timing;                                                                     # timing_filter_line
use StripUtils;

use StripUtils qw(
                  garde_newlines
                  warningTrace
                  configureLocalTraces
                  StringStore
		  dumpVueStrings
                 );
use Prepro;
use AnaUtils;
use Vues;

use Lib::ParseUtil;
use JSP::JSPScriptNode;

# JSP openning and closing tags.

my $STD_JSP_DIRECTIVE = '<%\@';
my $STD_JSP_TAG = '<%[=!]?';
my $STD_JSP_EXPR = '<%=';
my $XML_JSP_TAG = '<jsp:\w+';
my $JSP_TAG_LIB = '<\w+:\w+';
my $HTML_COMMENT = '<!--';
my $JSP_COMMENT = '<%--';
my $JAVA_COMMENT = '\/\/|\/\*';
my $CDATA = '<!\[CDATA\[';
my $closing_STD_JSP_TAG = '%>';
my $closing_JSP_TAG_LIB = '<\/\w+:\w+\s*>';
my $closing_XML_JSP_TAG = '<\/jsp:\w+\s*>';
my $closing_HTML_COMMENT = '-->';
my $closing_JSP_COMMENT = '--%>';
my $closing_JAVA_COMMENT = '\n|\*\/';
my $closing_CDATA = '\]\]>';


my $string = '\\\\?(?:"|\')';
#my $string = '"|\'';
my $esc_string = '\\\\"|\\\\\'';

# esc_escape aims to match \\ in a string. 
# So it should be \\\\ in the regular expression !!
# so it should be \\\\\\\\ in the string ($esc_escape) expanded in the regular expression !!!!
my $esc_escape = '\\\\\\\\';

my $openServerTags = "$JSP_COMMENT|$STD_JSP_DIRECTIVE|$STD_JSP_TAG|$XML_JSP_TAG|$JSP_TAG_LIB";
my $closeServerTags = "$closing_JSP_COMMENT|$closing_STD_JSP_TAG|$closing_JSP_TAG_LIB";#'%>|\/>|<\/\w+:\w+>';

sub appendAsJavaComment($$;$) {
	my ($context, $vues, $updateMixBloc) = @_ ;
	
	my $element = $context->{'element'};
	my $blanked_element = $context->{'blanked_element'};
	
	$vues->append( 'comment_a'	, $element );

	# Sometime, comment items written in MixBloc view are not the same than in comment view.
	# In this case do not update MixBloc, it is the responsibiity of the calling routine.
	if ((! defined $updateMixBloc) || ($updateMixBloc == 1)) {
		$vues->append( 'MixBloc_a'	, $element );
	}

	# 'script' view contains the java comments just as java code .
	$vues->append( 'script_a'	,  $element );
	$vues->append( 'script_html_a'	,  $element );
	
	# other views related to jsp script do not contain java comments.
	#Lib::ParseUtil::appendAsBlanked($context, $vues);
	$vues->append( 'tag_comment_a'	,  $blanked_element );
    $vues->append( 'html_a'		,  $blanked_element );
    
	
	$context->{'blanked_comment'} .= $context->{'blanked_element'};
}

sub appendItemToJavaComment($$) {
	my ($item, $vues) = @_ ;
	
	$vues->append( 'comment_a'	, $item );
}

sub appendItemToMixBloc($$) {
	my ($item, $vues) = @_ ;
	
	$vues->append( 'MixBloc_a'	, $item );
}

# additional callback to be called each time a element will be considered as Script item.
sub cb_appendAsScript($$) {
	my ($context, $vues) = @_ ;
	
	$vues->append( 'MixBloc_a'	, $context->{'element'} );
}

# additional callback to be called each time a element will be considered as html item.
sub cb_appendAsHtml($$) {
	my ($context, $vues) = @_ ;
	
	$vues->append( 'MixBloc_a'	, $context->{'blanked_element'} );
}

#---------------------- HTML_COMMENT ---------------------------------------
sub trigger_HTML_COMMENT($$) {
	my ($context, $vues)=@_;

	my $element = $context->{'element'};
    
    Lib::ParseUtil::enterState($context, 'HTML_COMMENT');
    Lib::ParseUtil::appendAsHTML($context, $vues);
}

sub cb_HTML_COMMENT($$) {
	my ($context, $vues)=@_;

	my $element = $context->{'element'};
    
    if (Lib::ParseUtil::checkRegexpTriggeringToken($context, $vues)) {
	}
	else {
		Lib::ParseUtil::appendAsHTML($context, $vues);
	}
}

sub closing_HTML_COMMENT($$) {
	my ($context, $vues)=@_;

	my $element = $context->{'element'};
	
	Lib::ParseUtil::appendAsHTML($context, $vues);    
    Lib::ParseUtil::leaveCurrentState($context);
}

#---------------------- STRING ---------------------------------------
sub trigger_JSP_STRING($$) {
	my ($context, $vues)=@_;

	my $element = $context->{'element'};

	$context->{'string_buffer'} = $element ;
    
    # Option 0 will prevent to add a JSP_STRING node to the tree ...
    Lib::ParseUtil::enterState($context, 'JSP_STRING');
    
    # the triggering pattern " or ' will be the expected closing pattern !
    Lib::ParseUtil::setStateClosingPattern($context, $element);

}

sub cb_STRING($$$$) {
	my ($context, $vues, $STRING_VIEW_NAME, $TAG_NAME)=@_;
	
	my $element = $context->{'element'};
	
	if (Lib::ParseUtil::checkRegexpTriggeringToken($context, $vues)) {
	}
	elsif (Lib::ParseUtil::isStateClosingPattern($context, $element)) {
		# this is the end of the string
		my $string_buffer = $context->{'string_buffer'};
		$string_buffer .= $element ;
		
		# store in the string view and get the key
		my $string_id = StringStore( $context->{$STRING_VIEW_NAME}, $string_buffer, $TAG_NAME );
		
		# keep the number of line for a multiline string...
		my $nb = () = $string_buffer =~ /\n/g ;
		my $newlines = "\n" x $nb ;
		
		Lib::ParseUtil::appendAsScriptEndString($context, $vues, $string_id . $newlines);
		# Back to the state containing the string.
		Lib::ParseUtil::leaveCurrentState($context);
		
		# append to the statement of the node containing te string.
		my $str_replace = ' '.$string_id . $newlines.' ';
		Lib::ParseUtil::appendNodeStatement($context, \$str_replace);
	}
	else {
		# it's any element of the string. Record it ...
		$context->{'string_buffer'} .= $element ;
		Lib::ParseUtil::appendAsScriptString($context, $vues);
	}
}

sub cb_JSP_STRING($$) {
	my ($context, $vues)=@_;
	cb_STRING($context, $vues, "JSP_string_context", "JSP_CHAINE_");
}

sub cb_JAVA_STRING($$) {
	my ($context, $vues)=@_;
	# tag for java strings is "CHAINE_" in compliance with java analyzer.
	cb_STRING($context, $vues, "JAVA_string_context", "CHAINE_");
}

sub trigger_JAVA_STRING($$) {
	my ($context, $vues)=@_;

	my $element = $context->{'element'};

	$context->{'string_buffer'} = $element ;
    
    # Option 0 will prevent to add a JAVA_STRING node to the tree ...
    Lib::ParseUtil::enterState($context, 'JAVA_STRING');
    
    # the triggering pattern " or ' will be the expected closing pattern !
    Lib::ParseUtil::setStateClosingPattern($context, $element);
}

#---------------------- STD directives ---------------------------------------
sub trigger_STD_JSP_DIRECTIVE($$) {
	my ($context, $vues)=@_;

    my $element = $context->{'element'};
    
    Lib::ParseUtil::enterState($context, 'STD_JSP_DIRECTIVE');
    
    Lib::ParseUtil::appendAsScript($context, $vues);
}

#---------------------- STD tags ---------------------------------------
sub trigger_STD_JSP_TAG($$) {
	my ($context, $vues)=@_;

    my $element = $context->{'element'};
    
    Lib::ParseUtil::enterState($context, 'STD_JSP_TAG');
    
    Lib::ParseUtil::appendAsScript($context, $vues);
}

sub cb_STD_JSP_TAG($$) {
	my ($context, $vues)=@_;
	
	my $element = $context->{'element'};
	
	# an end of tag ?
	if ( $element eq '%>') {
		Lib::ParseUtil::appendAsScript($context, $vues);
		Lib::ParseUtil::leaveCurrentState($context);
	}
	# a string ... ?
	elsif (Lib::ParseUtil::checkRegexpTriggeringToken($context, $vues)) {
	}
	# a scriptlet content !
	else {
		Lib::ParseUtil::appendAsScript($context, $vues);
		#$context->{'appendScriptlet'}->($context, $vues);
	}
}
#---------------------- tags lib ---------------------------------------
sub trigger_JSP_TAG_LIB($$) {
	my ($context, $vues)=@_;
    
    Lib::ParseUtil::enterState($context, 'JSP_TAG_LIB');

	Lib::ParseUtil::appendAsScript($context, $vues);
	
    my $tagName = $context->{'element'};
	$tagName =~ s/<//s;
    Lib::ParseUtil::setStateClosingPattern($context, "</$tagName>"); 
}

sub cb_JSP_TAG_LIB($$) {
	my ($context, $vues)=@_;
	
	my $element = $context->{'element'};
	
	if ( $element eq '/>') {
		Lib::ParseUtil::appendAsScript($context, $vues);
		# The tag is closed, back to HTML.
		Lib::ParseUtil::leaveCurrentState($context);
	}
	elsif ( $element eq '>') {
		Lib::ParseUtil::appendAsScript($context, $vues);
		# Back to the HTML state, but the tag is not closed. 
		Lib::ParseUtil::enterState($context, 'HTML');
	}
	elsif (Lib::ParseUtil::checkRegexpTriggeringToken($context, $vues)) {
	}
	else {
		# its anything else inside the tag
		Lib::ParseUtil::appendAsScript($context, $vues);
	}
}

sub leaving_JSP_TAG_LIB($$) {
	my ($context, $vues)=@_;
	
	if (Lib::ParseUtil::restoreOpenningTagState($context, $context->{'element'})) {
		# if a matching openning tag has been found then consider the closing pattern as JSP code
		Lib::ParseUtil::appendAsScript($context, $vues);
		# leave the state.
		Lib::ParseUtil::leaveCurrentState($context);
	}
	else {
		# before openning and closing tag lib, we are in HTML zone.
		# if the encountered "closing tag lib" has no corresponding opening tag lib,
		# then it is ignore:
		# - consider the closing tag lib as an HTML element.
		# - stay in HTML state.
		Lib::ParseUtil::appendAsHTML($context, $vues);
	}
}
#---------------------- XML tags ---------------------------------------
sub trigger_XML_JSP_TAG($$) {
	my ($context, $vues)=@_;

    Lib::ParseUtil::enterState($context, 'XML_JSP_TAG');
    
    Lib::ParseUtil::appendAsScript($context, $vues);
    
    my $tagName = $context->{'element'};
	$tagName =~ s/<//s;
    Lib::ParseUtil::setStateClosingPattern($context, "</$tagName>");
}

sub cb_XML_JSP_TAG($$) {
	my ($context, $vues)=@_;

	my $element = $context->{'element'};
	
	if ( $element eq '/>') {
		Lib::ParseUtil::appendAsScript($context, $vues);
		# The tag is closed, back to HTML.
		Lib::ParseUtil::leaveCurrentState($context);
	}
	elsif ( $element eq '>') {
		Lib::ParseUtil::appendAsScript($context, $vues);
		
		if (Lib::NodeUtil::GetName($context->{'state'}->[$Lib::ParseUtil::STATE_NODE]) =~ /jsp:(?:scriptlet|declaration|expression)\b/) {
			Lib::ParseUtil::enterState($context, 'XML_JSP_TEXT');
		}
		else {
			Lib::ParseUtil::enterState($context, 'HTML');
		}
		
		
	}
	elsif (Lib::ParseUtil::checkRegexpTriggeringToken($context, $vues)) {
	}
	else {
		# its anything else inside the tag
		Lib::ParseUtil::appendAsScript($context, $vues);
	}
}
#---------------------- XML tag text ---------------------------------------
sub cb_XML_JSP_TEXT($$) {
	my ($context, $vues)=@_;
	
	my $element = $context->{'element'};
	
	# FIXME : may not work in every case, its not the entire tag !!
	if ( $element =~ /<\//) {
		# an end tag is encountered. Try to retrieves the corresponding
		# openning tag and leaves the corresponding state.
		Lib::ParseUtil::restoreOpenningTagState($context, $element);
		Lib::ParseUtil::appendAsScript($context, $vues);
		Lib::ParseUtil::leaveCurrentState($context);
	}
	elsif (Lib::ParseUtil::checkRegexpTriggeringToken($context, $vues)) {
	}
	else {
		Lib::ParseUtil::appendAsScript($context, $vues);
	}
}

#---------------------- CDATA ---------------------------------------

sub trigger_CDATA($$) {
	my ($context, $vues)=@_;

    Lib::ParseUtil::enterState($context, 'CDATA');
    
    Lib::ParseUtil::appendAsScript($context, $vues);
}

sub cb_CDATA($$) {
	my ($context, $vues)=@_;
	
	my $element = $context->{'element'};
	
	if ( $element =~ /\]\]>/) {
		Lib::ParseUtil::appendAsScript($context, $vues);
		Lib::ParseUtil::leaveCurrentState($context);
	}
	elsif (Lib::ParseUtil::checkRegexpTriggeringToken($context, $vues)) {
	}
	else {
		Lib::ParseUtil::appendAsScript($context, $vues);
	}
}

#---------------------- JSP COMMENT ---------------------------------------

my $NB_OPENNED_JSP_TAGS = 0;

sub trigger_JSP_COMMENT($$) {
	my ($context, $vues)=@_;
    
    $NB_OPENNED_JSP_TAGS = 0;
    
    Lib::ParseUtil::enterState($context, 'JSP_COMMENT');
    
    Lib::ParseUtil::appendAsComment($context, $vues);
}

sub cb_JSP_COMMENT($$) {
	my ($context, $vues)=@_;
	
	my $element = $context->{'element'};
	
	if ( $element eq $closing_JSP_COMMENT) {
		Lib::ParseUtil::appendAsComment($context, $vues);
		Lib::ParseUtil::leaveCurrentState($context);
	}
	else {
		# check presence of JSP TAG inside a JSP comment !
		if ($element =~ /$STD_JSP_TAG|$STD_JSP_DIRECTIVE|$STD_JSP_EXPR/) {
			$NB_OPENNED_JSP_TAGS++;
		}
		
		# end of embedded JSP TAG ? 
		if ($element eq $closing_STD_JSP_TAG) {
			if ($NB_OPENNED_JSP_TAGS > 0) {
				# YES ... it's ok
				$NB_OPENNED_JSP_TAGS--;
			}
			else {
				# NO ... arf ! it's a confusing syntax !!!!
				print "[WARNING] %> assumed to be the end of a JSP comment at ".$context->{'line'}."\n";
				# Memorize 1 additional violation.
				$context->{'AmbigousClosing'}++;
				Lib::ParseUtil::appendAsComment($context, $vues);
				Lib::ParseUtil::leaveCurrentState($context);
			}
		}
		Lib::ParseUtil::appendAsCommentContent($context, $vues);
	}
}

#---------------------- JAVA COMMENT ---------------------------------------
sub trigger_JAVA_COMMENT($$) {
	my ($context, $vues)=@_;

	my $element = $context->{'element'};

	$context->{'blanked_comment'} = '';
    
    # Option 0 will prevent to add a JAVA_STRING node to the tree ...
    Lib::ParseUtil::enterState($context, 'JAVA_COMMENT', 0);
    
    if ($element eq '//') {
		Lib::ParseUtil::setStateClosingPattern($context, "\n");
		appendAsJavaComment($context, $vues, 0); # 0 means do not update MixBloc
		appendItemToMixBloc("/*", $vues);
		
	}
	else {
		Lib::ParseUtil::setStateClosingPattern($context, '*/');
		appendAsJavaComment($context, $vues);
	}
}


sub leave_JAVA_COMMENT($) {
	my $context = shift;
	# Back to the state containing the java comment.
	Lib::ParseUtil::leaveCurrentState($context);
		
	# append the blanked comment in the code statement in ordre to conserve the lines return.
	# (code items that are not in the same line should not be concatenated on the same line !)
	Lib::ParseUtil::appendNodeStatement($context, \$context->{'blanked_comment'});
}

sub cb_JAVA_COMMENT($$) {
	my ($context, $vues)=@_;
	
	my $element = $context->{'element'};
	
	if (Lib::ParseUtil::isStateClosingPattern($context, $element)) {
		# append as blank element for all "script" views ...
		if ($element ne "\n") {
			appendAsJavaComment($context, $vues);
		}
		else {
			appendAsJavaComment($context, $vues, 0); # 0 means do not update MixBloc
			appendItemToMixBloc("*/\n", $vues);
		}
		
		leave_JAVA_COMMENT($context);
	}
	
	# if we are in a // comment (ie. closing pattern is '\n') and a end scriptlet is encountered, then leave the java comment state
	elsif (($element eq '%>') && (Lib::ParseUtil::getStateClosingPattern($context) eq "\n")) {
		my $previous = Lib::ParseUtil::getPreviousState(1);
		
		# check if the %> is really closing a scriptlet ...
		if ($previous->[$Lib::ParseUtil::STATE_ID] eq 'STD_JSP_TAG') {
			
			# close the MixBloc comment with */
			appendItemToMixBloc("*/", $vues);
			
			# Cannot close the comment int he view 'comment', because for that we should go to line, whereas this is not the case in real code.
			#appendItemToJavaComment("\n", $vues);
			
			
			# Back to the STD_JSP_TAG state containing the java comment.
			leave_JAVA_COMMENT($context);
			
			# treat the %> with the appropriate callback.
			cb_STD_JSP_TAG($context, $vues);
		}
		else {
			# OK, the %> was not closing a scriptlet !
			appendAsJavaComment($context, $vues);
		}	
	}
	# if an end of line is encountered that is not the end of the comment, 
	# then replace the "\n" with "*/\n/*" in the MixBloc view
	elsif ($element eq "\n") {
		appendAsJavaComment($context, $vues, 0); # 0 means do not update MixBloc
		appendItemToMixBloc("*/\n/*", $vues);
	}
	else {
		appendAsJavaComment($context, $vues);
	}
}



# NOTE : if a state is not associated with anay triggering token, this
#		 means the callback of the state implements all treatments.

# STRUCTURE for each state: 
#         <STATE> => [ 	<callback>,
#						<token extractor regexpr>, 
#						<triggers>
#					 ]

my %STATES = (
	'HTML'	=> 
		[	undef,			# use default treatment for HTML
			qr/\G($JSP_COMMENT|$STD_JSP_DIRECTIVE|$STD_JSP_TAG|$XML_JSP_TAG|$JSP_TAG_LIB|$closing_JSP_TAG_LIB|$HTML_COMMENT|<|[^<]*)/sm,
			#triggers
			[	[$JSP_COMMENT, 			\&trigger_JSP_COMMENT],
				[$STD_JSP_DIRECTIVE, 	\&trigger_STD_JSP_DIRECTIVE],
				[$STD_JSP_TAG, 			\&trigger_STD_JSP_TAG],
				[$XML_JSP_TAG, 			\&trigger_XML_JSP_TAG],
				[$JSP_TAG_LIB, 			\&trigger_JSP_TAG_LIB],
				[$closing_JSP_TAG_LIB,	\&leaving_JSP_TAG_LIB],
				[$HTML_COMMENT, 		\&trigger_HTML_COMMENT],
			],
		],
	# inside an html comment
	'HTML_COMMENT'	=>
		[	\&cb_HTML_COMMENT,
			qr/\G($JSP_COMMENT|$STD_JSP_DIRECTIVE|$STD_JSP_TAG|$XML_JSP_TAG|$JSP_TAG_LIB|$closing_JSP_TAG_LIB|$closing_HTML_COMMENT|<|-|[^<\-]*)/sm,
			# triggers
			[	[$JSP_COMMENT, 			\&trigger_JSP_COMMENT],
				[$STD_JSP_DIRECTIVE, 	\&trigger_STD_JSP_DIRECTIVE],
				[$STD_JSP_TAG, 			\&trigger_STD_JSP_TAG],
				[$XML_JSP_TAG, 			\&trigger_XML_JSP_TAG],
				[$JSP_TAG_LIB, 			\&trigger_JSP_TAG_LIB],
				[$closing_JSP_TAG_LIB, 	\&leaving_JSP_TAG_LIB],
				[$closing_HTML_COMMENT,	\&closing_HTML_COMMENT],
			],
		],
		
	# inside a standard tag <%@ ... %>
	'STD_JSP_DIRECTIVE'	=>
		# NOTE : it's not an error, callback is the same than for state STD_JSP_TAG
		[	\&cb_STD_JSP_TAG,
			qr/\G(\%>|\%|$string|"|'|\\|>|[^\%>"'\\]*)/sm,
			#triggers
			[	[$string, 			\&trigger_JSP_STRING],],
		],
	# inside a standard tag <% ... %>
	'STD_JSP_TAG'	=>
		[	\&cb_STD_JSP_TAG,
			# Addd \\ in the list, because $string can begin by \\ sometimes ...
			qr/\G(\%>|\%|$JAVA_COMMENT|\/|$string|"|'|\\|>|[^\%>"'\/\\]*)/sm,
			#triggers
			# NOTE : all strings in this state are assumed to be java strings !
			[	[$string, 			\&trigger_JAVA_STRING],
				[$JAVA_COMMENT,		\&trigger_JAVA_COMMENT],],
		],
	# inside an XML tag <jsp:xxx ... > or <jsp:xxx ... />
	'XML_JSP_TAG'	=>
		[	\&cb_XML_JSP_TAG,
			qr/\G(\/>|$string|"|'|\\|>|\/|[^\/>"'\\]*)/sm,
			#triggers
			[	[$string, 			\&trigger_JSP_STRING],],
		],
	# inside a tag lib <xxx:yyy ... > or <xxx:yyy ... />
	'JSP_TAG_LIB'	=>
		[	\&cb_JSP_TAG_LIB,
			qr/\G(\/>|$string|"|'|\\|>|\/|[^\/>"'\\]*)/sm,
			#triggers
			[	[$string, 			\&trigger_JSP_STRING],	],
		],
	# between openning and closing xml tag : <jsp:xxx ...> jsp text </jsp:xxx>
	#      (only for xxx = scriptlet|declaration|expression) !!!!!!
	'XML_JSP_TEXT'	=>
		[	\&cb_XML_JSP_TEXT,
			qr/\G($closing_XML_JSP_TAG|$CDATA|$JAVA_COMMENT|\/|$string|"|'|\\|<|[^<"'\/\\]*)/sm,
			#triggers
			[	[$string, 			\&trigger_JAVA_STRING],
				[$JAVA_COMMENT,		\&trigger_JAVA_COMMENT],
				[$CDATA, 			\&trigger_CDATA],	],
		],
	# inside a CDATA
	'CDATA'	=>
		[	\&cb_CDATA,
			qr/\G($closing_CDATA|$JAVA_COMMENT|\/|$string|"|'|\\|\]|[^\]"'\/\\]*)/sm,
			#triggers
			[	[$string, 			\&trigger_JAVA_STRING],
				[$JAVA_COMMENT,		\&trigger_JAVA_COMMENT],],
		],
	# inside a string
	'JSP_STRING'	=>
		[	\&cb_JSP_STRING,
			qr/\G($esc_escape|$esc_string|$string|"|'|\\|$STD_JSP_EXPR|<|[^"'\\<]*)/sm,
			#triggers
			[	[$STD_JSP_EXPR, 			\&trigger_STD_JSP_TAG],	],
		],
	# inside a string
	'JAVA_STRING'	=>
		[	\&cb_JAVA_STRING,
			qr/\G($esc_escape|$esc_string|$string|"|'|\\|[^"'\\]*)/sm,
			undef						# No triggering tokens
		],
	# inside a comment 
	'JSP_COMMENT'	=>
		[	\&cb_JSP_COMMENT,
			qr/\G($closing_JSP_COMMENT|-|$STD_JSP_TAG|$STD_JSP_DIRECTIVE|$STD_JSP_EXPR|<|$closing_STD_JSP_TAG|%|[^\-<%]*)/sm,
			undef						# No triggering tokens
		],
	# inside a Java comment 
	'JAVA_COMMENT'	=>
		[	\&cb_JAVA_COMMENT,
			qr/\G($closing_JAVA_COMMENT|\*|\n|$closing_STD_JSP_TAG|\%|[^*\n\%]*)/sm,
			undef						# No triggering tokens
		],
);

sub extractFromTagText($) {
	my $node = shift;
	
	my $children = Lib::NodeUtil::GetChildren($node);
	
	if (scalar @$children > 0) {
		# the first child of the node shoud be an XML_JSP_TEXT
		my $child = $children->[0];
		
		if (Lib::NodeUtil::GetKind($child) eq 'XML_JSP_TEXT') {
			# FIXME case of a CDATA
			return Lib::NodeUtil::GetStatement($child);
		}
		else {
			print "[WARNING] missing XML_JSP_TEXT in a XML_JSP_TAG\n";
		}
	}
	return Lib::NodeUtil::createEmptyStringRef();
}

sub cb_extractDeclaration($$$) {
	my ($node, $context, $level) = @_;
	my $type = Lib::NodeUtil::GetName($node);
	if ($type eq '<%!') {
		${Lib::NodeUtil::GetStatement($node)} =~ /\A<\%!(.*)\%>/sg;
		if (defined $1) {
			${$context->[0]} .= $1."\n";
		}
	}
	elsif ($type eq '<jsp:declaration') {
		${$context->[0]} .= ${extractFromTagText($node)}."\n";
		return 0; # do not pursue the iteration inside the node.
	}
	return undef; 
}

sub cb_extractCode($$$) {
	my ($node, $context, $level) = @_;
	my $kind = Lib::NodeUtil::GetKind($node);
	my $type = Lib::NodeUtil::GetName($node);
	
	if (($kind eq "STD_JSP_TAG") || ($kind eq "STD_JSP_DIRECTIVE")) {
		# regexp match the tags <% and <%=, but not <%@ ! (directives will not be in the java code)
		${Lib::NodeUtil::GetStatement($node)} =~ /\A<\%[=]?([^@].*)\%>/sg;
		if (defined $1) {
			${$context->[0]} .= $1."\n";
		}
	}
	elsif ($kind eq "XML_JSP_TAG") {
		if ($type =~ /<jsp:(?:expression|scriptlet)\b/) {
			${$context->[0]} .= ${extractFromTagText($node)}."\n";
		}
	}
	return undef; 
}

sub buildScriptletCode($) {
	my $views = shift;
	my $code = "class Scriptlet {\n";
	
	# extract declarations :
	Lib::Node::Iterate($views->{'tag_tree'}, 0, \&cb_extractDeclaration, [\$code]);
	# Extract code :
	Lib::Node::Iterate($views->{'tag_tree'}, 0, \&cb_extractCode, [\$code]);
	$code .= "\n}\n";

	# Some java code in scriptlet have missing closing braces because (JSP parser add implicit closing braces at end of file !!)
	# Detect missing braces ...
	my $openning = () = $code =~ /\{/g;
	my $closing = () = $code =~ /}/g;
	
	# ... and if any, add them !!
	if ($closing < $openning) {
		my $nb = $openning - $closing;
		$code .= "}"x($nb);
		StripUtils::storeStripInfo($views, "ImplicitClosing", $nb);
		print STDERR "[WARNING] found $nb implicit closing braces.\n";
	}

	return \$code;
}

sub _cb_PreSearchKind($$) {
	my ($node, $context) = @_;

	my $kind = Lib::NodeUtil::GetKind($node);
	
	# check if $kind if in the list of searched kinds
	if (exists $context->[1]->{$kind}) {
		# if yes, record the node in the corresponding list.
		if (! exists $context->[0]->{$kind}) {
			$context->[0]->{$kind} = [$node];
		}
		else {
			push @{$context->[0]->{$kind}}, $node;
		}
	}
	return undef;
}

# XML_JSP_TAG allways have a XML_JSP_TEXT tag node that contains the JSP code between openning and closing tag.
# If this JSP code is empty (no statement and no child), then the node should be removed.
sub cb_excludeEmptyTags($$) {
	my $childNode = shift;
	my $context = shift;
	
	if (defined $childNode) {
		if (Lib::NodeUtil::GetKind($childNode) eq XML_JSP_TEXT) {
			my $stmt = Lib::NodeUtil::GetStatement($childNode);
			my $children = Lib::Node::GetChildren($childNode);

			# if it's an xml JSP tag node without children and whose statement is empty...
			if (($$stmt !~ /\S/s) && (scalar @$children == 0)) {
			#	... then remove it.
				Lib::Node::Detach($childNode);
			}
		}
	}
}

#-------------------------------------------------------------------------------
# DESCRIPTION: provide following views:
#
# tag_comment	: BUFFER, 	containing JSP tags comment (excluding HTML & java comments )
# script_string : HASH,		containing strings found in JSP tags
# script		: BUFFER, 	containing non HTML code + emptied comments + encoded strings.
# html			: BUFFER, 	containing HTML code.
# script_html	: BUFFER, 	containing TEXT + emptied JSP comments + encoded JSP & Java strings (same as "script" but with HTML elements in addition !)
# tag_tree		: TREE, 	containing JSP tree.
#
# NOTE: for java, views names are those used in the java analyzer !!!
# comment		: BUFFER, 	containing Java comments
# code			: BUFFER,	containing Java code (packaged in a analyzable class for the Highlight java analyzer!!)
# HString		: HASH,		containing strings found in embedded java code.
# MixBloc		: BUFFER,	contains script tags, java code and java comments. Java comments are normalized to /* ... */ and not multiline !
#
# kinds         : HASH,		containing lists of pre-searched 'kind' nodes.
#-------------------------------------------------------------------------------
sub StripJSP($$$$)
{
  my ($filename, $vue, $options, $couples) = @_;
  my $status = 0;

  my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0);   # traces_filter_line
  my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);                    # traces_filter_line

  {
    my $message = 'Launching de StripJSP::StripJSP';
    Erreurs::LogInternalTraces ('verbose', undef, undef, 'StripJSP', $message);
  }

  my $b_timing_strip = ((defined   Timing->isSelectedTiming ('Strip'))? 1 : 0);
  #print STDERR join ( "\n", keys ( %{$options} ) );                            # traces_filter_line
  configureLocalTraces('StripJSP', $options);                                   # traces_filter_line
  my $stripJSPTiming = new Timing ('SteripJSP', Timing->isSelectedTiming ('Strip'));
  $stripJSPTiming->markTimeAndPrint ('--init--') if ($b_timing_strip);          # timing_filter_line

  localTrace ('verbose',  "working with  $filename \n");                        # traces_filter_line
  
  # Init parsing context
	my %hContext=();
	my $context=\%hContext;
  
  # Data for string management
	my %strings_values = () ;
	my %strings_counts = () ;
	my %JAVA_strings_context = (
      'nb_distinct_strings' => 0,
      'strings_values' => \%strings_values,
      'strings_counts' => \%strings_counts  ) ;
      
    # will be use by states callbacks to acces datas about JAVA strings
	$context->{'JAVA_string_context'} = \%JAVA_strings_context;


	# View to memorize data produced by strip phase ... if needed ...
	$context->{'AmbigousClosing'} = 0;

  #my $ref_sep = separer_code_commentaire_chaine(\$vue->{'text'}, $options);
  my $err = Lib::ParseUtil::parseMarkup(	\$vue->{'text'},				# input text view
											$vue,							# views output set
											$options,						# command line options 
											\%STATES, 						# state definition with associated callbacks
											['comment', 'MixBloc'],			# additional buffered views (to the default sripts views) to be declared by parseMarkup(). 
											[\&cb_appendAsScript, undef, \&cb_appendAsHtml],	
																			# addiditional treatments for respectively "appendAsScript" and "appendAsComment"
											\&cb_excludeEmptyTags,			# additional empty tag excluding treatments.
											$openServerTags, 				# for preliminary split
											$closeServerTags,				# for preliminary split
											$context);


	
	# View to memorize data produced by strip phase ... if needed ...
	$vue->{'strip_info'} = {};
	StripUtils::storeStripInfo($vue, 'AmbigousClosing', $context->{'AmbigousClosing'});

  # record the java strings (in compliance with the java analyzer !!)
  $vue->{'HString'} = \%strings_values;

  $stripJSPTiming->markTimeAndPrint ('separer_code_commentaire_chaine') if ($b_timing_strip); # timing_filter_line

  $vue->{'agglo'} = "";
  #StripUtils::agglomerate_C_Comments($MixBloc, \$vue->{'agglo'});

  # build the 'code' view corresponding to the java code inside scriptlet, declaration and expressions.
  $vue->{'code'} = ${buildScriptletCode($vue)};

  # PRE-SEARCH BUILDING
  #----------------------
  # build pre-searched kinds lists.
  my %kinds;
  my @context = (\%kinds, {'XML_JSP_TEXT' => 1});
  Lib::Node::Iterate($vue->{'tag_tree'}, 0, \&_cb_PreSearchKind, \@context);
  $vue->{'kinds'} = \%kinds;
  
  if (defined $options->{"--JSP-tree"}) {
	#print STDERR ${Lib::Node::dumpTree($root_HTML, "ARCHI")} ;
	Lib::Node::Dump($vue->{'tag_tree'}, *STDOUT, "ALL");
  }

  if ( $err gt 0) {
    my $message = 'Fatal error in code/comment/string separation';
    Erreurs::LogInternalTraces ('erreur', undef, undef, 'STRIP // ABORT_CAUSE_SYNTAX_ERROR', 'Erreur fatale dans la separation des chaines et des commentaires');
    #return $status | ErrStripError(1, Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples)  if ( $err gt 0);
    $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
    return $status;
  }

  my $debug = 0;                                                                # traces_filter_line

  if ( defined $options->{'--dumpstrings'})
  {
    dumpVueStrings( $vue->{'HString'} , $STDERR );
    dumpVueStrings( $vue->{'script_string'} , $STDERR );
  }

  $stripJSPTiming->dump('StripJSP') if ($b_timing_strip);                  # timing_filter_line

  print STDERR "StripJSP end:$status\n"  if ($b_TraceInconsistent);             # traces_filter_line
  $stripJSPTiming->finish() ;                                                   # timing_filter_line
  return $status;
}

1;
