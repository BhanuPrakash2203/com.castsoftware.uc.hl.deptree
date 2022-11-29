package technos::id;

use warnings;
use strict;

use Exporter 'import'; # gives you Exporter’s import() method directly

our @EXPORT = qw(	Java JSP JavaScript PHP C_Cpp Objective_C MariaDB Matlab CSharp KornShell VB_DotNet Nsdk PlSql TSql PL1 Cobol Abap JS_EMBEDDED
					Apex Sybase MySQL PostgreSQL DB2 JCL IMSDB IMSDC CICS
					FILE_NAME FILE_POTENTIAL_TECHNOS FILE_TECHNOS FILE_DIR FILE_EXTENSION FILE_RESOLUTION_MODE FILE_ID FILE_EXCLUDED_TECHNOS
					DIR_NAME DIR_TECHNOS DIR_PARENT DIR_CHILDREN DIR_FILES DIR_RELATIVENAME
);

use constant Java 	=> 'Java';
use constant JSP 	=> 'JSP';
use constant JavaScript	=> 'JS';
use constant PHP	=> 'PHP';
use constant C_Cpp	=> 'CCpp';
use constant Objective_C	=> 'ObjCCpp';
use constant MariaDB => 'MariaDB';
use constant Matlab	=> 'Matlab';
use constant CSharp	=> 'CS';
use constant KornShell	=> 'Ksh';
use constant VB_DotNet	=> 'VbDotNet';
use constant Nsdk	=> 'Nsdk';
use constant PlSql	=> 'PlSql';
use constant TSql	=> 'TSql';
use constant PL1	=> 'PL1';
use constant Cobol	=> 'Cobol';
use constant Abap	=> 'Abap';
use constant JS_EMBEDDED	=> 'JS_EMBEDDED';
use constant Apex	=> 'Apex';
use constant MySQL	=> 'MySQL';
use constant PostgreSQL	=> 'PostgreSQL';
use constant DB2	=> 'DB2';
use constant JCL	=> 'JCL';
use constant IMSDB	=> 'IMSDB';
use constant IMSDC	=> 'IMSDC';
use constant CICS	=> 'CICS';

#unsupported technos :
use constant Sybase	=> 'Sybase';

use constant FILE_NAME => 0;
use constant FILE_POTENTIAL_TECHNOS => 1;
use constant FILE_TECHNOS => 2;
use constant FILE_DIR => 3;
use constant FILE_EXTENSION => 4;
use constant FILE_RESOLUTION_MODE => 5;
use constant FILE_ID => 6;
use constant FILE_EXCLUDED_TECHNOS => 7;

use constant DIR_NAME         => 0;
use constant DIR_TECHNOS      => 1;
use constant DIR_PARENT       => 2;
use constant DIR_CHILDREN     => 3;
use constant DIR_FILES        => 4;
use constant DIR_RELATIVENAME => 5;

1;
