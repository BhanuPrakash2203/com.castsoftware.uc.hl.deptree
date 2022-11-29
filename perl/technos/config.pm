package technos::config;

# CONF MODIFICATION HISTORY 
# 20/02/2015
#   CCpp resolutiuon is allow directly from extension except for .inc (conflict with PHP) and for .h (conflict with ObjCCpp)
# 23/02/2015
#   Create the ultimate default resolution at end of context resolution, and allow .h extension that have the potential techno CCpp
#   to be resolved to CCpp techno. So in last resort, .h will always been resolved to CCpp by default. .h file should in finel never
#   stay unresolved.

use strict;
use warnings;
use technos::check;
use AutoDecode;

use constant TECHNOS			=> 0;
use constant ANALYZER			=> 0;

use constant DIRECT_RESOLUTION 		=> 1;
use constant DEFAULT_RESOLUTION 	=> 2;
use constant CONTEXT_RESOLUTION 	=> 3;
use constant STAT_FROM_POTENTIAL	=> 4;
use constant STAT_CORRECTION 		=> 5;
use constant CONTENT_CHECKING_REQUIRED	=> 6;
use constant NAME_CHECKING_CALLBACK	=> 7;
use constant STAT_RESOLUTION 		=> 8;

my $FILE_TOO_BIG_SIZE = 10000*1024;

# DIRECT resolution means that the file is resolved to the associated techno (if there is only one) without checking its content.
#
# DEFAULT resolution means that the file is resolved to the associated techno if there is no other choice possible, and even if its
# content can not have been checked. Set this option to false to say the content MUST be validated for the techno. WARNING : note
# that in this case, if the validation callback is missing, the techno would never be resolved, and if it is not 100% reliable,
# some file may not be resolved !!!!
#
# CONTEXT resolution means that at the end of the process, files that have not been resolved by another mean, will be resolved
# to the techno of the files that have the same extension in the same directory (if 100% of these files with same extension have 
# the same techno). This option is practical for techno whose file can have any extension (like ksh, cobol, ...), and the checking callback are
# "poorly" reliable !!! 
#
# STATISTIC FROM POTENTIAL -- when a extension is associated with several potential techno, then after content checking, for all files in a same directory,
# try to determine if a uniq common techno is shared by all files.
#
# STATISTIC RESOLUTION -- not yet implemented, but intended to provide a mean to resolve the unresolved file by taking into account the statistics
# of files already resolved.
#
# STATISTIC CORRECTION --  not yet implemented, but the idea is to reconsider the resolution of file : if a directory contains 90% of file of 
# a given techno, what about the 10% remaining ? These files could be checked against the major techno, in particular if they have
# been resolved directly from extension or by default (that is, whithout their content was checked) ! 

my %EXTENSIONS = (
#				0				1			2			3			4						5					6					7
# extension 	Technos			Direct		Default		Context		(Stat from potential)	(Stat correction) 	(Content checking) (stat resolution)
'java'	=> [ 	['Java'],		undef,		undef,		undef,		undef,		undef,		undef ],
'jav' 	=> [	['Java'],		undef,		undef,		undef,		undef,		undef,		undef ],
'jsp'	=> [	['JSP'],		undef,		undef,		undef,		undef,		undef,		undef ],
'jspf'	=> [	['JSP'],		undef,		undef,		undef,		undef,		undef,		undef ],
'tld'	=> [	['JSP'],		undef,		undef,		undef,		undef,		undef,		undef ],
'js' 	=> [	['JS'], 		undef,		undef,		undef,		undef,		undef,		undef ],
'htm' 	=> [	['JS_EMBEDDED'],	undef,		undef,		undef,		undef,		undef,		undef ],
'html'	=> [	['JS_EMBEDDED'],	undef,		undef,		undef,		undef,		undef,		undef ],
'xhtml'	=> [	['JS_EMBEDDED'],	undef,		undef,		undef,		undef,		undef,		undef ],
'php' 	=> [	['JS_EMBEDDED', 'PHP'],	undef,		undef,		undef,		undef,		undef,		undef ],
'php4'	=> [	['JS_EMBEDDED', 'PHP'],	undef,		undef,		undef,		undef,		undef,		undef ],
'php5' 	=> [	['JS_EMBEDDED', 'PHP'],	undef,		undef,		undef,		undef,		undef,		undef ],
'php6' 	=> [	['JS_EMBEDDED', 'PHP'],	undef,		undef,		undef,		undef,		undef,		undef ],
'inc' 	=> [	['CCpp', 'PHP'],	undef,		undef,		undef,		undef,		undef,		1     ],
'c' 	=> [	['CCpp'],			1,		undef,		undef,		undef,		undef,		undef ],
'c++' 	=> [	['CCpp'],			1,		undef,		undef,		undef,		undef,		undef ],
'cpp' 	=> [	['CCpp'],			1,		undef,		undef,		undef,		undef,		undef ],
'pc' 	=> [	['CCpp'],			1,		undef,		undef,		undef,		undef,		undef ],
'ppc' 	=> [	['CCpp'],			1,		undef,		undef,		undef,		undef,		undef ],
'cc' 	=> [	['CCpp'],			1,		undef,		undef,		undef,		undef,		undef ],
'cxx' 	=> [	['CCpp'],			1,		undef,		undef,		undef,		undef,		undef ],
'icc' 	=> [	['CCpp'],			1,		undef,		undef,		undef,		undef,		undef ],
'h' 	=> [	['CCpp', 'ObjCCpp'],	undef,		undef,		undef,		undef,		undef,		undef ],
'hh' 	=> [	['CCpp'],			1,		undef,		undef,		undef,		undef,		undef ],
'hpp' 	=> [	['CCpp'],			1,		undef,		undef,		undef,		undef,		undef ],
'h++' 	=> [	['CCpp'],			1,		undef,		undef,		undef,		undef,		undef ],
'm' 	=> [	['ObjCCpp', 'Matlab'],		undef,		undef,		undef,		undef,		undef,		undef ],
'mm' 	=> [	['ObjCCpp'],		undef,		undef,		undef,		undef,		undef,		undef ],
'cs' 	=> [	['CS'], 		undef,		undef,		undef,		undef,		undef,		undef ],
'ksh' 	=> [	['Ksh'],		undef,		undef,		undef,		undef,		undef,		undef ],
'vb' 	=> [	['VbDotNet'],		undef,		undef,		undef,		undef,		undef,		undef ],
'vbs' 	=> [	['VbDotNet'],		undef,		undef,		undef,		undef,		undef,		undef ],
'bas' 	=> [	['VbDotNet'],		undef,		undef,		undef,		undef,		undef,		undef ],
'frm' 	=> [	['VbDotNet'],		0,		0,		undef,		undef,		undef,		undef ],
'cls' 	=> [	['VbDotNet', 'Apex'],		undef,		undef,		undef,		undef,		undef,		undef ],
'ncl' 	=> [	['Nsdk'],		undef,		undef,		undef,		undef,		undef,		undef ],
'sql' 	=> [	['PlSql',
				'TSql',
				'Sybase',
				'MySQL',
				'PostgreSQL',
				'MariaDB',
				'DB2'],			undef,		undef,		undef,		1,		undef,		undef ],
'psql' 	=> [	['PlSql'],		1,		undef,		undef,		undef,		undef,		undef ],
'tsql' 	=> [	['TSql'],		1,		undef,		undef,		undef,		undef,		undef ],
'pks' 	=> [	['PlSql'],		1,		undef,		undef,		undef,		undef,		undef ],
'pkb' 	=> [	['PlSql'],		1,		undef,		undef,		undef,		undef,		undef ],
'plb' 	=> [	['PlSql'],		1,		undef,		undef,		undef,		undef,		undef ],
'mariadb' => [	['MariaDB'],	1,		undef,		undef,		undef,		undef,		undef ],
'mysql' => [	['MySQL'],		1,		undef,		undef,		undef,		undef,		undef ],
'postgresql' => [	['PostgreSQL'],		1,		undef,		undef,		undef,		undef,		undef ],
'db2' => [	['DB2'],		1,		undef,		undef,		undef,		undef,		undef ],
'pli' 	=> [	['PL1'],		undef,		undef,		undef,		undef,		undef,		undef ],
'plc' 	=> [	['PL1'],		undef,		undef,		undef,		undef,		undef,		undef ],
'cbl' 	=> [	['Cobol'],		1,		undef,		undef,		undef,		undef,		undef ],
'ccp' 	=> [	['Cobol'],		undef,		undef,		undef,		undef,		undef,		undef ],
'cb2' 	=> [	['Cobol'],		undef,		undef,		undef,		undef,		undef,		undef ],
'c85' 	=> [	['Cobol'],		undef,		undef,		undef,		undef,		undef,		undef ],
'c74' 	=> [	['Cobol'],		undef,		undef,		undef,		undef,		undef,		undef ],
'cob' 	=> [	['Cobol'],		1,		undef,		undef,		undef,		undef,		undef ],
'cop' 	=> [	['Cobol'],		undef,		undef,		undef,		undef,		undef,		undef ],
'cpb' 	=> [	['Cobol'],		undef,		undef,		undef,		undef,		undef,		undef ],
'cpy' 	=> [	['Cobol'],		undef,		undef,		undef,		undef,		undef,		undef ],
'pco' 	=> [	['Cobol'],		undef,		undef,		undef,		undef,		undef,		undef ],
'sqb' 	=> [	['Cobol'],		undef,		undef,		undef,		undef,		undef,		undef ],
'abap' 	=> [	['Abap'],		undef,		undef,		undef,		undef,		undef,		undef ],
'py' 	=> [	['Python'],			1,		undef,		undef,		undef,		undef,		undef ],
'pyw' 	=> [	['Python'],			1,		undef,		undef,		undef,		undef,		undef ],
# xml can contain abap file, but only if the file name matches a particular pattern. There is no potential techno that may be discovered by "default resolution",
# content checking or other mean ...
'xml' 	=> [	undef,			undef,		undef,		undef,		undef,		undef,		undef	, \&technos::check::check_Name ],
# tld can contain informations usefull for JSP analysis, of its full name (directory name)
'coffee'=> [	['CoffeeScript'],		undef,		undef,		undef,		undef,		undef,		undef ],
'litcoffee'=> [	['CoffeeScript'],		undef,		undef,		undef,		undef,		undef,		undef ],
'ts'=> [	['TypeScript'],		undef,		undef,		undef,		undef,		undef,		undef ],
'scala'=> [	['Scala'],		undef,		undef,		undef,		undef,		undef,		undef ],
'sc'=> [	['Scala'],		undef,		undef,		undef,		undef,		undef,		undef ],
#'pl'=> [	['Perl'],		undef,		undef,		undef,		undef,		undef,		undef ],
#'pm'=> [	['Perl'],		undef,		undef,		undef,		undef,		undef,		undef ],
'go'=> [	['Go'],		undef,		undef,		undef,		undef,		undef,		undef ],
'rb'=> [	['Ruby'],		undef,		undef,		undef,		undef,		undef,		undef ],
'lua'=> [	['Lua'],		undef,		undef,		undef,		undef,		undef,		undef ],
'pas'=> [	['Delphi'],		undef,		undef,		undef,		undef,		undef,		undef ],
'rs'=> [	['Rust'],		undef,		undef,		undef,		undef,		undef,		undef ],
'cfm'=> [	['Coldfusion'],		undef,		undef,		undef,		undef,		undef,		undef ],
'cfc'=> [	['Coldfusion'],		undef,		undef,		undef,		undef,		undef,		undef ],
'erl'=> [	['Erlang'],		undef,		undef,		undef,		undef,		undef,		undef ],
'rex'=> [	['Rexx'],		undef,		undef,		undef,		undef,		undef,		undef ],
'rexx'=> [	['Rexx'],		undef,		undef,		undef,		undef,		undef,		undef ],
'fs'=> [	['FS'],		undef,		undef,		undef,		undef,		undef,		undef ],
'fsx'=> [	['FS'],		undef,		undef,		undef,		undef,		undef,		undef ],
'lisp'=> [	['Lisp'],		undef,		undef,		undef,		undef,		undef,		undef ],
'lsp'=> [	['Lisp'],		undef,		undef,		undef,		undef,		undef,		undef ],
'adb'=> [	['Ada'],		undef,		undef,		undef,		undef,		undef,		undef ],
'ads'=> [	['Ada'],		undef,		undef,		undef,		undef,		undef,		undef ],
'st'=> [	['Smalltalk'],		undef,		undef,		undef,		undef,		undef,		undef ],
'mlx'=> [	['Matlab'],		undef,		undef,		undef,		undef,		undef,		undef ],
'r'=> [	['R'],		undef,		undef,		undef,		undef,		undef,		undef ],
'asm'=> [	['Assembly'],		undef,		undef,		undef,		undef,		undef,		undef ],
'groovy'=> [	['Groovy'],		undef,		undef,		undef,		undef,		undef,		undef ],
'trigger' => [	['Apex'],		undef,		undef,		undef,		undef,		undef,		undef ],
'swift'=> [	['Swift'],		undef,		undef,		undef,		undef,		undef,		undef ],
'kt'=> [	['Kotlin'],		undef,		undef,		undef,		undef,		undef,		undef ],
'nsp'=> [	['Natural'],		undef,		undef,		undef,		undef,		undef,		undef ],
'nsb'=> [	['Natural'],		undef,		undef,		undef,		undef,		undef,		undef ],
'nsn'=> [	['Natural'],		undef,		undef,		undef,		undef,		undef,		undef ],
'nsl'=> [	['Natural'],		undef,		undef,		undef,		undef,		undef,		undef ],
'nsg'=> [	['Natural'],		undef,		undef,		undef,		undef,		undef,		undef ],
'nsa'=> [	['Natural'],		undef,		undef,		undef,		undef,		undef,		undef ],
'nsm'=> [	['Natural'],		undef,		undef,		undef,		undef,		undef,		undef ],
'nsc'=> [	['Natural'],		undef,		undef,		undef,		undef,		undef,		undef ],
'nsh'=> [	['Natural'],		undef,		undef,		undef,		undef,		undef,		undef ],
'nss'=> [	['Natural'],		undef,		undef,		undef,		undef,		undef,		undef ],
'nsd'=> [	['Natural'],		undef,		undef,		undef,		undef,		undef,		undef ],
'f'  => [	['Fortran'],		undef,		undef,		undef,		undef,		undef,		undef ],
'f77'=> [	['Fortran'],		undef,		undef,		undef,		undef,		undef,		undef ],
'f90'=> [	['Fortran'],		undef,		undef,		undef,		undef,		undef,		undef ],
'f03'=> [	['Fortran'],		undef,		undef,		undef,		undef,		undef,		undef ],
'for'=> [	['Fortran'],		undef,		undef,		undef,		undef,		undef,		undef ],
'clj'=> [   ['Clojure'],		undef,		undef,		undef,		undef,		undef,		undef ],
'inc'=> [   ['JCL'],		    1,		undef,		undef,		undef,		undef,		undef ],
'jcl'=> [   ['JCL'],		    1,		undef,		undef,		undef,		undef,		undef ],
'mbr'=> [   ['JCL'],		    1,		undef,		undef,		undef,		undef,		undef ],
'prc'=> [   ['JCL'],		    1,		undef,		undef,		undef,		undef,		undef ],
'dbd'=> [   ['IMSDB'],		    1,		undef,		undef,		undef,		undef,		undef ],
'psb'=> [   ['IMSDB'],		    1,		undef,		undef,		undef,		undef,		undef ],
'tra'=> [   ['IMSDC'],		    1,		undef,		undef,		undef,		undef,		undef ],
'mfs'=> [   ['IMSDC'],		    1,		undef,		undef,		undef,		undef,		undef ],
'bms'=> [   ['CICS'],		    1,		undef,		undef,		undef,		undef,		undef ],
'cics'=> [   ['CICS'],		    1,		undef,		undef,		undef,		undef,		undef ],
'csd'=> [   ['CICS'],		    1,		undef,		undef,		undef,		undef,		undef ],

);

my %TECHNOS = (
# techno 	Analyzer			Direct		Default		Context		Stat resolution	Stat correction Content checking
'CCpp'	  => [ 	"AnaCCpp",		undef,		1,			1,			undef,	undef,		undef ],
'ObjCCpp' => [ 	"AnaObjCCpp",	undef,		1,			1,			undef,	undef,		undef ],
'Java'	  => [ 	"AnaJava",		1,			1,			1,			undef,	undef,		undef ],
'JSP'	  => [ 	"AnaJSP",		1,			1,			1,			undef,	undef,		undef ],
'PHP'	  => [ 	"AnaPHP",		undef,		undef,		1,			undef,	undef,		undef ],
'JS'	  => [ 	"AnaJS",		1,			1,			undef,		undef,	undef,		undef ],
'CS'	  => [ 	"AnaCS",		1,			1,			1,			undef,	undef,		undef ],
'Cobol'	  => [ 	"AnaCobol",		undef,		undef,		1,			undef,	undef,		undef ],
'Ksh'	  => [ 	"AnaKsh",		undef,		undef,		1,			undef,	undef,		undef ],
'VbDotNet'=> [ 	"AnaVbDotNet",		undef,		1,			1,			undef,	undef,		undef ],
'PL1'	  => [ 	"AnaPL1",		undef,		undef,		1,			undef,	undef,		undef ],
'Abap'	  => [ 	"AnaAbap",		1,			1,			1,			undef,	undef,		undef ],
'Nsdk'	  => [ 	"AnaNsdk",		1,			1,			1,			undef,	undef,		undef ],
'Python'  => [ 	"AnaPython",		1,			1,			1,			undef,	undef,		undef ],
# TSql && PlSql are exclusive
'TSql'	  => [ 	"AnaTSql",		undef,		1,			1,			undef,	undef,		undef ],
'PlSql'	  => [ 	"AnaPlSql",		undef,		1,			1,			undef,	undef,		undef ],
'DB2'	  => [ 	"AnaDB2",		undef,		1,			1,			undef,	undef,		undef ],
'PostgreSQL'	  => [ 	"AnaPostgreSQL",		undef,		1,			1,			undef,	undef,		undef ],
'MariaDB'	  => [ 	"AnaMariaDB",		undef,		1,			1,			undef,	undef,		undef ],
'MySQL'	  => [ 	"AnaMySQL",		undef,		1,			1,			undef,	undef,		undef ],
'CoffeeScript'  => [ 	"AnaCoffeescript",			1,			undef,		undef,		undef,	undef,		undef ],
'TypeScript'	=> [ 	"AnaTypescript",			1,			undef,		undef,		undef,	undef,		undef ],
'Scala'   => [ 	"AnaScala",			1,			undef,		undef,		undef,	undef,		undef ],
#'Perl'    => [ 	"AnaPerl",			1,			undef,		undef,		undef,	undef,		undef ],
'Go'      => [ 	"AnaGo",			1,			undef,		undef,		undef,	undef,		undef ],
'Ruby'    => [ 	"AnaRuby",			1,			undef,		undef,		undef,	undef,		undef ],
'Lua'     => [ 	"AnaLua",			1,			undef,		undef,		undef,	undef,		undef ],
'Delphi'  => [ 	"AnaDelphi",			1,			undef,		undef,		undef,	undef,		undef ],
'Rust'    => [ 	"AnaRust",			1,			undef,		undef,		undef,	undef,		undef ],
'Coldfusion'  => [ 	"AnaColdfusion",			1,			undef,		undef,		undef,	undef,		undef ],
'Erlang'  => [ 	"AnaErlang",			1,			undef,		undef,		undef,	undef,		undef ],
'Rexx'    => [ 	"AnaRexx",			1,			undef,		undef,		undef,	undef,		undef ],
'FS'      => [ 	"AnaFS",			1,			undef,		undef,		undef,	undef,		undef ],
'Lisp'    => [ 	"AnaLisp",			1,			undef,		undef,		undef,	undef,		undef ],
'Ada'     => [ 	"AnaAda",			1,			undef,		undef,		undef,	undef,		undef ],
'Smalltalk' => [ 	"AnaSmalltalk",			1,			undef,		undef,		undef,	undef,		undef ],
'Matlab'  => [ 	"AnaMatlab",			undef,			undef,		undef,		undef,	undef,		undef ],
'R'       => [ 	"AnaR",			1,			undef,		undef,		undef,	undef,		undef ],
'Assembly' => [ 	"AnaAssembly",			1,			undef,		undef,		undef,	undef,		undef ],
'Groovy'  => [ 	"AnaGroovy",			1,			undef,		undef,		undef,	undef,		undef ],
'Apex'  => [ 	"AnaApex",			undef,			undef,		undef,		undef,	undef,		undef ],
'Swift'	  => [ 	"AnaSwift",			1,			undef,		undef,		undef,	undef,		undef ],
'Kotlin'	  => [ 	"AnaKotlin",			1,			undef,		undef,		undef,	undef,		undef ],
'Natural'  => [ 	"AnaNatural",			1,			undef,		undef,		undef,	undef,		undef ],
'Fortran' => [ 	"AnaFortran",			1,			undef,		undef,		undef,	undef,		undef ],
'Clojure' => [ 	"AnaClojure",			1,			undef,		undef,		undef,	undef,		undef ],
'JCL' => [ 	"AnaJCL",			1,			undef,		undef,		undef,	undef,		undef ],
'IMSDB' => [ 	"AnaIMSDB",			1,			undef,		undef,		undef,	undef,		undef ],
'IMSDC' => [ 	"AnaIMSDC",			1,			undef,		undef,		undef,	undef,		undef ],
'CICS' => [ 	"AnaCICS",			1,			undef,		undef,		undef,	undef,		undef ],
);

my %BINARY_LIB_EXTENSIONS = (
'jar' => 1,
'dll' => 1,
#'exe' => 1,
'a' => 1,
'lib' => 1,
'so' => 1,
);

# RULES FOR SPECIFIC EXTENSIONS
#--------------------------------
# at context resolution phase, if a file has potential techno, a default methodology will
# resolve to the potential techno who has already been discovered in the directory. If
# several potential techno are discovered, the result will be undefined.
# With the following informations, we can deliver a priority resolution order with the
# techno that have already been discovered in the directory.
my %CONTEXT_POTENTIAL_PRIORITY = (
#extension		resolution priority
'h'			=>	['CCpp', 'ObjCCpp'],
'inc'		=>	['PHP', 'CCpp'],
);

# After all, if context resolution has failed, if an extension is associated with a default techno
# that is set as a potential techno for the file, then resolve to it.
my %CONTEXT_POTENTIAL_DEFAULT = (
'h'			=>	'CCpp',
);

my %ASSOCIATED_EXTENSIONS = (
'frm'		=>	{ 	'frx'	=> 'VbDotNet',
					'vbp'	=> 'VbDotNet'}
);

my %REAL_TECHNOS = (
'JS_EMBEDDED'	  => "JS"
);

my %EXCLUDED_EXTENSIONS = ('tar' => 1);

my %SEARCHED_TECHNOS = ();

# Precompiled pattern for hard coded ignored directories
my $R_IGNORED_DIRS_BUILTIN = qr/^(\.\.?|\.svn|\.casthighlight)$/;

# Precompiled pattern for list of ignored files or directories
# Set in buildIgnoreRE
my $R_IGNORED = undef;
# Precompiled re for ignored paths
my $R_IGNORED_PATH = undef;
##################  options ##################

my %options = ();

sub buildSearchedTechnosList() {
  if (defined $options{'technos'}) {
    for my $techno (split /,/,$options{'technos'} ) {
      $SEARCHED_TECHNOS{$techno} = 1;
    }
  }
  else {
    for my $techno (keys %TECHNOS) {
      $SEARCHED_TECHNOS{$techno} = 1;
    }
  }
}

sub buildExcludedTechnosList() {
  if (defined $options{'exclude-technos'}) {
    for my $techno (split /,/,$options{'exclude-technos'} ) {
      delete $SEARCHED_TECHNOS{$techno};
    }
  }
}

sub buildExcludedExtensionList() {
  if (defined $options{'exclude-ext'}) {
    for my $ext (split /,/,$options{'exclude-ext'} ) {
      $EXCLUDED_EXTENSIONS{$ext} = 1;
    }
  }
}

# Dynamically associate techno to extension :
# Only one techno with direct resoltion for an extension is allowed.
#
# Other cases woul require checking to prevent from bord effect. Exemple, if we associate to an extension a techno with direct resolution and a techno with
# content checking, the techno with content checking will never be discovered, and if we desactivate the direct resolution, the concerned techno could not 
# be discovered if it has no content checking callback ...

sub buildOwnExtension() {
  if (defined $options{'extensions'}) {
    my $extFile = $options{'extensions'};
    my $ret = open EXT,"<$extFile";
    if ($ret) {
      while (<EXT>) {
	chomp $_;
        my ($tech, $ext) = split /\s*=>\s*/, $_;
	my @exts = split /,/,$ext;
        for my $e (@exts) {
         setDirectExtension($e, $tech); 
	}
      }
    }
  }
}
# The ignore pattern can also ignore files, but is not documented
# It is document for dirs but one can set --ignore=.*.xml
# to ignore xml files
sub buildIgnoreRE() {
  if (defined $options{'ignore'}) {
    my $ignore = $options{'ignore'};
    my $orig = $ignore;
    $ignore =~ s/,/|/g;
    $ignore &&= '^('.$ignore.')$';
    if ($ignore) {
	  eval {
		$R_IGNORED = qr($ignore);
	  };
      if (defined $@) {
		print STDERR "[technos::config] ERROR : Bad regexp for file exclusion pattern : $orig\n";
	  }
    }
  }
}

sub buildIgnorePathRE() {
  if (defined $options{'ignorePath'}) {
    my $ignorePath = $options{'ignorePath'};
    my $orig = $ignorePath;
    $ignorePath &&= '^('.$ignorePath.')$';
    if ($ignorePath) {
	  eval {
        $R_IGNORED_PATH = qr($ignorePath);
	  };
      if (defined $@) {
		print STDERR "[technos::config] ERROR : Bad regexp for path exclusion pattern : $orig\n";
	  }
    }
  }
}


#------------ Command line options -----------------

sub setCommandLineOptions($) {
  my $opt = shift;
  %options = %$opt;
  buildSearchedTechnosList();
  buildExcludedExtensionList();
  buildExcludedExtensionList();
  buildOwnExtension();
  buildIgnoreRE();
  buildIgnorePathRE();
}

##################  Setter routines ##################

# The specified techno will be directly associated with the specified techno.
sub setDirectExtension($$) {
  my $ext = shift;
  my $techno = shift;

  # the extension $ext is associated to the techno $techno
  $EXTENSIONS{$ext}->[TECHNOS] = [$techno];
  # set direct resolution to $techno for the extension.
  $EXTENSIONS{$ext}->[DIRECT_RESOLUTION] = 1;  
}

##################  Getter routines ##################

sub isBinaryLib($) {
	my $ext = shift;
	if (defined $BINARY_LIB_EXTENSIONS{lc($ext)}) {
		return 1;
	}
	return 0;
}

sub getAvailableTechnos() {
	my @technos = ();
	for my $tech (keys %TECHNOS) {
		if (defined $TECHNOS{$tech}->[ANALYZER]) {
			push @technos, $tech;
		}
	}
	return \@technos;
}

sub hasPotentialContextPriority($) {
	my $extension = shift;
	return exists $CONTEXT_POTENTIAL_PRIORITY{$extension};
}

sub resolvePotentialwithContextPriority($$$) {
	my $filePotechs = shift;
	my $dirTechs = shift;
	my $ext = shift;

	my %potechFoundInDir = ();

	# search potential techno detected in the directory.
	for my $potech (keys %{$filePotechs}) {
			if ($dirTechs->{$potech}) {
					$potechFoundInDir{$potech}=1;
			}
	}

	# search the most prioritary potential techno found in the directory.
	for my $priotech (@{$CONTEXT_POTENTIAL_PRIORITY{$ext}}) {
		if (exists $potechFoundInDir{$priotech}) {
			return $priotech;
		}
	}

	return undef;
}

sub getAssociatedExtensions($) {
	my $ext = shift;

	return $ASSOCIATED_EXTENSIONS{$ext};
}

sub getUltimateDefaut($) {
	my $ext = shift;

	return $CONTEXT_POTENTIAL_DEFAULT{$ext};
}

sub isExcludedExtension($) {
  my $ext = shift;
  my $ret =  exists $EXCLUDED_EXTENSIONS{$ext};
  return $ret;
}

sub isIgnoredFile($) {
    my $name = shift;
    $name =~ $R_IGNORED_DIRS_BUILTIN ||
        $R_IGNORED && $name =~ $R_IGNORED;
}

sub isIgnoredPath($) {
    my $path = shift;
    $R_IGNORED_PATH && $path =~ $R_IGNORED_PATH;
}

sub isOutOfContext($) {
  my $technos = shift;

  for my $tech (@$technos) {
    if (exists $SEARCHED_TECHNOS{getRealTechno($tech)}) {
      return 0;
    }
  }

  return 1;
}

sub getContextualTechnos($) {
  my $techs = shift;
  my @contextTechs = ();

  for my $tech (@$techs) {
    if (exists $SEARCHED_TECHNOS{$tech}) {
      push @contextTechs, $tech;
    }
  }

  return \@contextTechs;
}

sub getNameCheckingCallback($) {
  my $ext = shift;

  return $EXTENSIONS{lc($ext)}[NAME_CHECKING_CALLBACK];
}

sub getRealTechno($) {
  my $techno = shift;

  if (exists $REAL_TECHNOS{$techno}) {
    return $REAL_TECHNOS{$techno};
 } 

  return $techno;
}

sub getTechnoAnalyzer($) {
  my $tech = shift;

  return $TECHNOS{$tech}[ANALYZER];
}

sub getAnalyzableTechnos($) {
	my $technos =  shift;
	my @analyzableTechnos = ();

	for my $tech (@$technos) {
		my $real = getRealTechno($tech);
		if (defined getTechnoAnalyzer($real)) {
			push @analyzableTechnos, $real;
		}
	}
	return \@analyzableTechnos;
}

sub getPotentialTechnosFromExtension($) {
  my $ext = shift;

  my @none = ();

  if (! defined $ext) {
    return \@none;
  }

  my $technos = $EXTENSIONS{lc($ext)}[TECHNOS];

  if (! defined $technos) {
    return \@none;
  }

  return $technos;
}

sub askExtension($$;$) {
  my $request = shift;
  my $ext = shift;
  my $techno = shift;

  my $answer = $EXTENSIONS{lc($ext)}[$request];

  if (! defined $answer) {

    if (defined $techno) {

      $answer = $TECHNOS{$techno}[$request];
    }

    if (! defined $answer) {
      $answer = 0;
    }
  }
  return $answer;
}

sub isDirectResolutionAllowed($$) {
  my $ext = shift;
  my $techno = shift;

  my $answer = 0;

  if ( ! defined $options{'no-direct-resolution'}) {
    $answer = askExtension(DIRECT_RESOLUTION, $ext, $techno);
  }
  
  return $answer;
}

sub isDefaultResolutionAllowed($$) {
  my $ext = shift;
  my $techno = shift;

  my $answer = 0;

  $answer = askExtension(DEFAULT_RESOLUTION, $ext, $techno);
  
  return $answer;
}

sub isContextResolutionAllowed($;$) {
  my $ext = shift;
  my $techno = shift;

  my $answer = 0;

  $answer = askExtension(CONTEXT_RESOLUTION, $ext, $techno);
  
  return $answer;
}

sub isContentCheckingRequired($;$) {
  my $ext = shift;
  my $techno = shift;

  my $answer = 0;

  $answer = askExtension(CONTENT_CHECKING_REQUIRED, $ext, $techno);

  return $answer;
}

sub isStatResolution_FromPotential_Allowed_For_Extension($) {
	my $ext = shift;
	return $EXTENSIONS{$ext}->[STAT_FROM_POTENTIAL];
}

sub isTooBig($) {
  my $r_complete_path = shift;
  if (-f $$r_complete_path) { 
    my $filesize = (stat($$r_complete_path))[7];
    if ($filesize >= $FILE_TOO_BIG_SIZE) {
      return $filesize;
    }
  }
  else {
    print "ERROR when checking size: $$r_complete_path do not exists\n";
  }
  return 0;
}

sub isBinary($) {
  my $buffer = shift;

  my ($bufBegin) = $$buffer =~ /^(.{0,70})/sm;

  my $bf = AutoDecode::BytesFrequencies(\$bufBegin);

  my $freq = AutoDecode::detect_binary_file($bf, \$bufBegin);

  if ( $freq > 0.5) {
    return 1;
  }

  return 0;
}

1;
