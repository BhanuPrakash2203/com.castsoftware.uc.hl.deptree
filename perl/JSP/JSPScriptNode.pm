package JSP::JSPScriptNode;

use strict;
use warnings;

use Exporter 'import'; # gives you Exporter’s import() method directly

my @kinds =  qw( HTML HTML_COMMENT STD_JSP_DIRECTIVE STD_JSP_TAG XML_JSP_TAG JSP_TAG_LIB
				XML_JSP_TEXT CDATA JSP_STRING JAVA_STRING JSP_COMMENT JAVA_COMMENT
	 );

# Symboles pour lesquels l'utilisateur n'aura pas a specifier l'espace de nom ObjCNode:
our @EXPORT_OK = (@kinds);  # symbols to export on request

# Importe automatiquement sans intervention du package utilisateur.
our @EXPORT = (@kinds);

# declaration des differents KIND utilises en JSP

use constant HTML			=> 'HTML';
use constant HTML_COMMENT 	=> 'HTML_COMMENT';
use constant STD_JSP_DIRECTIVE	=> 'STD_JSP_DIRECTIVE';
use constant STD_JSP_TAG	=> 'STD_JSP_TAG';
use constant XML_JSP_TAG	=> 'XML_JSP_TAG';
use constant JSP_TAG_LIB	=> 'JSP_TAG_LIB';
use constant XML_JSP_TEXT	=> 'XML_JSP_TEXT';
use constant CDATA			=> 'CDATA';
use constant JSP_STRING		=> 'JSP_STRING';
use constant JAVA_STRING	=> 'JAVA_STRING';
use constant JSP_COMMENT	=> 'JSP_COMMENT';
use constant JAVA_COMMENT	=> 'JAVA_COMMENT';

1;
