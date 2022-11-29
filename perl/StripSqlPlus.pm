#----------------------------------------------------------------------#
#                 @ISOSCOPE 2008                                       #
#----------------------------------------------------------------------#
#       Auteur  : ISOSCOPE SA                                          #
#       Adresse : TERSUD - Bat A                                       #
#                 5, AVENUE MARCEL DASSAULT                            #
#                 31500  TOULOUSE                                      #
#       SIRET   : 410 630 164 00037                                    #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Plugin

#FIXME A en croire http://www.ss64.com/orasyntax/remark.html :
# A common mistake is to use /* but not followed by a space (or newline) this 
# will be interpreted as "/" and will execute the previous SQL command.
# Although the actual comment will be ignored this behaviour can have 
# significant unexpected results:
# even if there's no previous command to execute then Oracle will error with "
# Nothing in SQL buffer to run".
#
# Cela aurait donc du sens d'enlever les / depuis ce module.


package StripSqlPlus;
use strict;
use warnings;

use StripUtils qw(
		  garde_newlines
		  warningTrace
		  configureLocalTraces
		  StringStore
		 );
#StripUtils::init('StripSqlPlus', 1);

my %hashSqlPlusCommands = ();

sub initSqlPlusCommandLine()
{
  
    # FIXME: voir aussi http://www.orafaq.com/wiki/SQL*Plus_FAQ#What_are_the_basic_SQL.2APlus_commands.3F
    # Here is a list of some of the most frequently used SQL*Plus commands:
    #
    #    * ACCEPT - Get input from the user
    #    * DEFINE - Declare a variable (short: DEF)
    #    * DESCRIBE - Lists the attributes of tables and other objects (short: DESC)
    #    * EDIT - Places you in an editor so you can edit a SQL command (short: ED)
    #    * EXIT or QUIT - Disconnect from the database and terminate SQL*Plus
    #    * GET - Retrieves a SQL file and places it into the SQL buffer
    #    * HOST - Issue an operating system command (short: !)
    #    * LIST - Displays the last command executed/ command in the SQL buffer (short: L)
    #    * PROMPT - Display a text string on the screen. Eg prompt Hello World!!!
    #    * RUN - List and Run the command stored in the SQL buffer (short: /)
    #    * SAVE - Saves command in the SQL buffer to a file. Eg "save x" will create a script file called x.sql
    #    * SET - Modify the SQL*Plus environment eg. SET PAGESIZE 23
    #    * SHOW - Show environment settings (short: SHO). Eg SHOW ALL, SHO PAGESIZE etc.
    #    * SPOOL - Send output to a file. Eg "spool x" will save STDOUT to a file called x.lst
    #    * START - Run a SQL script file (short: @) 
  my @OrafaqSqlPlusCommands = ( 'ACCEPT', 'DEFINE', 'DESCRIBE', 'EDIT', 'EXIT', 'QUIT', 'GET', 'HOST', 'LIST',
    'PROMPT', 'RUN', 'SAVE', 'SET', 'SHOW', 'SPOOL', 'START' ,
    'DEF', 'DESC', 'ED', 'L', 'SHO', 
    '!', '/', '@' );



    #  Double Hyphen ( -- )
        #  -- comment_text
    #  At Sign (@)
    #  Double At Sign (@@)
        #  @@script_file [argument...]
    #  Forward Slash (/)
        #  /
    #      A forward slash executes the SQL statement or PL/SQL block that is currently in the buffer. For example:
    #  ACCEPT
    #      ACC[EPT] user_variable [NUM[BER] | CHAR | DATE] [FOR[MAT] format_specification] [DEF[AULT] default_value] [PROMPT prompt_text | NOPR[OMPT]] [HIDE]
    #  APPEND
    #      A[PPEND] text
    #  ARCHIVE LOG
    #      ARCHIVE LOG
    #  ATTRIBUTE
    #      ATTRIBUTE
    #  BREAK
    #      BRE[AK] [ON {column_name | ROW | REPORT} [SKI[P] {lines_to_skip | PAGE} | NODUP[LICATES] | DUP[LICATES]...]...]
    #  BTITLE
    #      BTI[TLE] [[OFF | ON] | COL x | S[KIP] x | TAB x | LE[FT] | CE[NTER] | R[IGHT] | BOLD | FOR[MAT] format_spec | text | variable...]
    #  CHANGE
    #      C[HANGE] /old_text[/[new_text[/]]
    #  CLEAR
    #      CL[EAR] {BRE[AKS] | BUFF[ER] | COL[UMNS] | COMP[UTES] | SCR[EEN] | SQL | TIMI[NG]}
    #  COLUMN
    #      COL[UMN] [column_name [ALI[AS] alias | CLE[AR] | ENTMAP {ON|OFF} | FOLD_A[FTER] | FOLD_B[EFORE] | FOR[MAT] format_spec | HEA[DING] heading_text | JUS[TIFY] {LEFT | CENTER | CENTRE | RIGHT} | LIKE source_column_name | NEWL[INE] | NEW_V[ALUE] user_variable | NOPRI[NT] | PRI[NT] | NUL[L] null_text | OLD_V[ALUE] user_variable | ON | OFF | TRU[NCATED] | WOR[D_WRAPPED] | WRA[PPED]...]]
    #  COMPUTE
    #      COMP[UTE] [{AVG | COU[NT] | MAX[IMUM] | MIN[IMUM] | NUM[BER] | STD | SUM | VAR[IANCE]}... [LABEL label_text] OF column_name... ON {group_column_name | ROW | REPORT}...]
    #  CONNECT
    #      CONN[ECT] [username[/password][@connect] | / ] [AS {SYSOPER | SYSDBA}] | [INTERNAL]
    #  COPY
    #      COPY {FROM connection | TO connection} {APPEND | CREATE | INSERT | REPLACE} destination_table [(column_list)] USING select_statement
    #  DEFINE
    #      DEF[INE] [variable_name [= text]]
    #  DEL
    #      DEL [{b | * | LAST}[ {e | * | LAST}]]
    #  DESCRIBE
    #      DESC[RIBE] [schema.]object_name[@database_link_name]
    #  DISCONNECT
    #      DISC[ONNECT]
    #  EDIT
    #      ED[IT] [filename]
    #  EXECUTE
    #      EXEC[UTE] statement
    #  EXIT
    #      EXIT [SUCCESS | FAILURE | WARNING | value | user_variable | :bind_variable] [COMMIT | ROLLBACK]
    #  GET
    #      GET filename [LIST | NOLIST]]
    #  HELP
    #      HELP [topic]
    #  HOST
    #      HO[ST] [os_command]
    #  INPUT
    #      I[NPUT] [text]
    #  LIST
    #      L[IST] [{b | * | LAST}[ {e | * | LAST}]]
    #  PASSWORD
    #      PASSW[ORD] [username]
    #  PAUSE
    #      PAU[SE] [pause_message]
    #  PRINT
    #      PRI[NT] [bind_variable_name]
    #  PROMPT
    #      PRO[MPT] text_to_be_displayed
    #  QUIT
    #      QUIT FAILURE ROLLBACK QUIT [SUCCESS | FAILURE | WARNING | value | user_variable | :bind_variable] | [COMMIT | ROLLBACK]
    #  RECOVER
    #      RECOVER {general | managed | END BACKUP}
    #  REMARK
    #      REM[ARK] comment_text
    #  REPFOOTER
    #      REPF[OOTER] [OFF | ON] | [COL x | S[KIP] x | TAB x | LE[FT] | CE[NTER] | R[IGHT] | BOLD | FOR[MAT] format_spec | text | variable...]
    #  REPHEADER
    #      REPH[EADER] [OFF | ON] | [COL x | S[KIP] x | TAB x | LE[FT] | CE[NTER] | R[IGHT] | BOLD | FOR[MAT] format_spec | text | variable...]
    #  RUN
    #      R[UN]
    #  SAVE
    #      SAV[E] filename [CRE[ATE] | REP[LACE] | APP[END]]
    #  SET
    #      SET parameter_setting
    #  SHOW
    #      SHO[W] [setting | ALL | BTI[TLE] | ERR[ORS] [{FUNCTION | PROCEDURE | PACKAGE | PACKAGE BODY | TRIGGER | TYPE | TYPE BODY | DIMENSION | JAVA CLASS} [owner.]object_name] | LNO | PARAMETER[S] [parameter_name] | PNO | REL[EASE] | REPF[OOTER] | REPH[EADER] | SGA | SPOO[L] | SQLCODE | TTI[TLE] | USER]
    #  SHUTDOWN
    #      SHUTDOWN [NORMAL | IMMEDIATE | TRANSACTIONAL [LOCAL] | ABORT]
    #  SPOOL
    #      SP[OOL] filename | OFF | OUT
    #  START
    #      STA[RT] script_file [argument...]
    #  STARTUP
    #      STARTUP [FORCE] [RESTRICT] [PFILE=filename] [QUIET] [ MOUNT [dbname] | OPEN [open_options] [dbname] | NOMOUNT] [EXCLUSIVE | {PARALLEL | SHARED}] open_options ::= READ {ONLY | WRITE [RECOVER]} | RECOVER Alternate form of STARTUP for migration::= STARTUP [PFILE=filename] MIGRATE [QUIET]
    #  STORE
    #      STORE SET filename [CRE[ATE] | REP[LACE] | APP[END]]
    #  TIMING
    #      TIMI[NG] [START [timer_name] | SHOW | STOP]
    #  TTITLE
    #      TTI[TLE] [OFF | ON] | [COL x | S[KIP] x | TAB x | LE[FT] | CE[NTER] | R[IGHT] | BOLD | FOR[MAT] format_spec | text | variable...]
    #  UNDEFINE
    #      UNDEF[INE] variable_name [variable_name...]
    #  VARIABLE
    #      VAR[IABLE] [variable_name [data_type]]
    #  WHENEVER
    #      WHENEVER {OSERROR | SQLERROR} {EXIT [SUCCESS | FAILURE | value | :bind_variable ] [COMMIT | ROLLBACK] | CONTINUE [COMMIT | ROLLBACK | NONE]}

  my @OreillySqlPlusCommands = ( 
    '--', '@', '@@', '/', 
    'ACC', 'ACCEPT', 'A', 'APPEND', 'ARCHIVE', 'ATTRIBUTE', 
    'BRE', 'BREAK', 'BTI', 'BTITLE', 
    'C', 'CHANGE', 'CL', 'CLEAR', 'COL', 'COLUMN', 'COMP', 'COMPUTE', 'CONN', 'CONNECT', 'COPY',
    'DEF', 'DEFINE', 'DEL', 'DESC', 'DESCRIBE', 'DISC', 'DISCONNECT',
    'ED', 'EDIT', 'EXEC', 'EXECUTE', 'EXIT', 
    'GET',
    'HELP', 'HO', 'HOST',
    'I', 'INPUT',
    'L', 'LIST', 
    'PASSW', 'PASSWORD', 'PAU', 'PAUSE', 'PRI', 'PRINT', 'PRO', 'PROMPT',
    'QUIT',
    'RECOVER', 'REM', 'REMARK', 'REPF', 'REPFOOTER', 'REPH', 'REPHEADER', 'R', 'RUN',
    'SAV', 'SAVE', 'SET', 'SHO', 'SHOW', 'SHUTDOWN', 'SP', 'SPOOL', 'STA', 'START', 'STARTUP', 'STORE', 
    'TIMI', 'TIMING', 'TTI', 'TTITLE', 
    'UNDEF', 'UNDEFINE',
    'VAR', 'VARIABLE', 
    'WHENEVER' );

  # La liste d'Orafaq apporte le !
  my @SqlPlusCommands = (@OreillySqlPlusCommands, @OrafaqSqlPlusCommands);

  %hashSqlPlusCommands = ();
  for my $word ( @SqlPlusCommands )
  {
    $hashSqlPlusCommands{$word} = 1;
  }
}

initSqlPlusCommandLine();

sub isSqlPlusCommandLine($)
{
  my ($line) = @_;
  my $uc_line = uc($line);
  # On considere qu'une commande Sql*Plus doit etre en debut de ligne.
  # List of SQLPLUS commands, recognized at the start of a line only.
  # The rest of the line is unchanged by casing and indentation functions.
  # http://209.85.129.132/search?q=cache:OEJ9IDsSKPAJ:https://svn.rizoma.cl/svn/emacswiki/sqled-mode.el+sqlplus+indentation&hl=fr&ct=clnk&cd=17&gl=fr
  if ( $uc_line  =~ m{^([/](?=\z|\s)|[@!]|[A-Z]*\b)} )
  {
    my $firstWord = $1;
    return ( exists $hashSqlPlusCommands{$firstWord} );
  }
  else 
  {
    return 0;
  }
}

# automate de tri du contenu du fichier en trois parties:
# 1/ Sql*Plus
# 2/ PlSql
sub separer_sqlplus($$)
{
  my ($source, $options) = @_;
  my $b_timing_strip = Timing->isSelectedTiming ('Strip')   ;                   # timing_filter_line
  my $buffer_d_entree = $$source;

  my $vues = new Vues( 'text' ); # creation des nouvelles vues a partir de la vue text
  $vues->unsetOptionPosition();
  $vues->declare('plsql');
  $vues->declare('sqlplus');
  my $position=0;

  my $state = 'INSQLPLUS' ;

  my @parts = split (  "(\n)" , $buffer_d_entree );
  # Traitement ligne par ligne.
  for my $partie ( @parts )
  {
    #localTrace (undef, "Utilisation du buffer:           " . $partie . "\n" );  # traces_filter_line
    if ( $partie =~ /^\n$/ )
    {
      $vues->append( 'sqlplus', $partie );
      $vues->append( 'plsql', $partie );
    }
    # NB: Acording to http://oreilly.com/catalog/9780596004415/toc.html
    # /* and */ might be SqlPlus comments.
    # However all documents looks like considering it as PlSql comments.


    elsif ( isSqlPlusCommandLine ( $partie) )
    {
      $vues->append( 'sqlplus',  $partie  );
      $vues->append( 'plsql',  ';'  );
      $state = 'INSQLPLUS' ;
    }
    else
    {
      $vues->append( 'plsql',  $partie  );
      $state = 'INPLSQL' ;
    }
    $vues->commit ( $position);
    $position += length( $partie) ;
  }

  # Consolidation des vues.
  my $sqlplus = $vues->consolidate('sqlplus');
  my $plsql = $vues->consolidate('plsql');

  my @return_array ;
  @return_array =  ( 0, \$plsql, \$sqlplus);
  return \@return_array ;
}

# analyse du fichier
sub StripSqlPlus($$$$)
{
  my ($filename, $vue, $options, $couples) = @_;
  my $b_timing_strip = Timing->isSelectedTiming ('Strip')   ;                   # timing_filter_line

  configureLocalTraces('StripSqlPlus', $options);                               # traces_filter_line
  my $stripSqlPlusTiming = new Timing ('StripSqlPlus', $b_timing_strip);        # timing_filter_line


  localTrace ('verbose',  "working with  $filename \n");                        # traces_filter_line
  my $text = $vue->{'text'};
  $stripSqlPlusTiming->markTimeAndPrint('--init--');                            # timing_filter_line

  my $ref_sep = separer_sqlplus(\$text, $options);
  $stripSqlPlusTiming->markTimeAndPrint('separer_sqlplus');                     # timing_filter_line

  my($err, $plsql, $sqlplus) = @{$ref_sep} ;
  $vue->{'plsql'} = $$plsql;
  $vue->{'sqlplus'} = $$sqlplus;

  $stripSqlPlusTiming->dump('StripSqlPlus') ;                                   # timing_filter_line
  if ($err gt 0)
  {
    return ErrStripError() ;
  }
  else
  {
    return 0;
  }
}

1; # Le chargement du module est okay.

