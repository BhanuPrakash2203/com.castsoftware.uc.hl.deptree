package technos::check;

use warnings;
use strict;

use PHP::CheckPHP;
#use CheckKsh;
use Cobol::Vue;

use technos::id;

sub isMarkupFormat($) {
  my $buf = shift;

  if ($$buf =~ m/\A\s*</sm) {
      return 1;
  }
}

#---------- Embedded Javascript delimiters ---------------------
my $JS_OpenTag = '<\s*script(?:\s+[^>]*\bjavascript\b[^>]*)?>';
my $JS_CloseTag = '<\s*\/\s*script\s*>?';

my $PHP_OpenTag          = '<\?php';
my $PHP_scriptOpenTag    = '<\s*script\s+[^>]*\bphp\b[^>]*>';
my $PHP_PotentialOpenTag = '<(?:\%|\?)';

sub get_JS_OpenningDelimiters() {
  return $JS_OpenTag;
}

sub get_JS_ClosingDelimiters() {
  return $JS_CloseTag;
}

sub checkWebContent($$) {
  my $content = shift;
  my $ext = shift;

  my @TechnosPresent = ();
  my @TechnosAbsent = ();

  # Check PHP
  if ($ext =~ /^php\d?$/) {
	  push @TechnosPresent, PHP;
  }
  elsif ($$content =~ m/($PHP_OpenTag|$PHP_scriptOpenTag)/sgmi) {
	  push @TechnosPresent, PHP;
  }
  elsif ($$content !~ m/$PHP_PotentialOpenTag/sgmi) {
	  push @TechnosAbsent, PHP;
  }

  # Check Embedded Javascrip
  if ( $$content =~ /$JS_OpenTag/si ) {
    push @TechnosPresent, JS_EMBEDDED;
  }
  else {
    push @TechnosAbsent, JS_EMBEDDED;
  }

  return (\@TechnosPresent, \@TechnosAbsent);
}

################################################################################
#                          SQL detection
################################################################################

# The value is the number of the column associated to the language int the
# tabs TAB_SQL_PATTERN & TAB_SQL_PATTERN_2
use constant SYBASE_ID   => 0;
use constant TSQL_ID     => 1;
use constant PLSQL_ID    => 2;
use constant MYSQL_ID    => 3;
use constant POSTGRES_ID => 4;
use constant DB2_ID      => 5;
use constant MARIADB_ID  => 6;

use constant STATUS_NO_MATCH   => 0;
use constant STATUS_SOME_MATCH => 1;
use constant STATUS_END_CHECK  => -1;

my %TECH = (
  SYBASE_ID()   => Sybase,
  TSQL_ID()     => TSql,
  PLSQL_ID()    => PlSql,
  MYSQL_ID()    => MySQL,
  POSTGRES_ID() => PostgreSQL,
  DB2_ID()      => DB2,
  MARIADB_ID()  => MariaDB
);

my @SQL_TECHNO_LIST = (SYBASE_ID, TSQL_ID, PLSQL_ID, MYSQL_ID, POSTGRES_ID, DB2_ID, MARIADB_ID);

# Sybase has the same syntax than TSql. So it is quite impossible to distinguish them, and technos can never be fully
# resolved to a single techno. The consequence is we can never resolve from context.
# the following option prevent from sybase detection.
my $DESACTIVATE_SYBASE = 1;

my @TAB_SQL_PATTERN = (
  # PATTERN			SYBASE	TSQL	PLSQL	MYSQL	POSTG.	DB2 MARIADB
[ '^\s*package\b',		[undef,	undef, 	1, 	undef,	undef,	undef]	],
[ '\bLANGUAGE\s+[\']?(?:internal|plpgsql|pltcl|plperl|plpythonu)\b',
				[undef,	undef, 	undef, 	undef,	1,	undef,	undef]	],
[ '\belsif\b',			[undef,	undef, 	1, 	undef,	1,	undef,	undef]	],
[ '^\s*go\b',			[1,	1, 	undef, 	1,	undef,	undef,	undef]	],
[ '^\s*CREATE\s+PROCEDURE\b',	[1,	1, 	1, 	1,	undef,	1,	undef    ]	],
[ '\bSAVEPOINT\b',		[undef,	undef, 	1, 	1,	1,	1,	undef    ]	],
[ '\bSAVE\s+TRANSACTION\b',	[1,	1, 	undef, 	undef,	undef,	undef,	undef]	],
[ '\bBEGIN\s+TRANSACTION\b',	[1,	1, 	undef, 	undef,	undef,	undef,	undef]	],
[ '\bCOMMIT\s+TRANSACTION\b',	[1,	1, 	undef, 	undef,	1,	undef,	undef]	],
[ '\bSTART\s+TRANSACTION\b',	[undef,	undef, 	undef, 	1,	1,	1,	undef    ]	],
[ '\bSET\s+TRANSACTION\b',	[undef,	undef, 	1, 	1,	1,	undef,	undef]	],
[ '\bDECLARE\s+@',	[1,	1, 	undef, 	undef,	undef,	undef,	undef]	],
[ '^\s*/\s*$',			[undef,	undef, 	1, 	undef,	1,	undef,	undef]	],
[ '\bSYS(?:IBM|CAT)\b',			[undef,	undef, 	undef, 	undef,	undef,	1,	undef]	],
[ '\bFULL\s+OUTER\s+JOIN\b',			[undef,	1, 	1, 	undef,	1,	1,	undef]	],
[ '\bCREATE\s+DISTINCT\s+TYPE\b',			[undef,	undef, 	1, 	undef,	undef,	1,	undef]	],
# MariaDB-specific functions
# source: https://mariadb.com/kb/en/function-differences-between-mariadb-107-and-mysql-80/
[ '\bCOLUMN_ADD\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bCOLUMN_CHECK\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bCOLUMN_CREATE\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bCOLUMN_DELETE\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bCOLUMN_EXISTS\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bCOLUMN_GET\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bCOLUMN_JSON\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bCOLUMN_LIST\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bWSREP_LAST_SEEN_GTID\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bWSREP_LAST_WRITTEN_GTID\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bWSREP_SYNC_WAIT_UPTO_GTID\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bADD_MONTHS\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bCHR\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bDECODE_ORACLE\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bLENGTHB\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bNVL\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bNVL2\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bSYS_GUID\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bTO_CHAR\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bTRIM_ORACLE\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bVALUE\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bJSON_COMPACT\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bJSON_DETAILED\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bJSON_EQUALS\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bJSON_EXISTS\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bJSON_LOOSE\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bJSON_NORMALIZE\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bJSON_QUERY\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bLASTVAL\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bNEXTVAL\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bSETVAL\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bMEDIAN\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bPERCENTILE_CONT\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bPERCENTILE_DISC\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bNATURAL_SORT_KEY\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bSFORMAT\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
# MariaDB-specific variables
# source: https://mariadb.com/kb/en/system-variable-differences-between-mariadb-107-and-mysql-80/
[ '\balter_algorithm\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\banalyze_sample_percentage\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\baria_',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bbinlog-annotate-row-events\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bbinlog_commit_wait_count\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bbinlog_commit_wait_usec\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bbinlog_file_cache_size\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bbinlog_optimize_thread_scheduling\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bcheck_constraint_checks\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bcolumn_compression_threshold\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bcolumn_compression_zlib_level\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bcolumn_compression_zlib_strategy\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bcolumn_compression_zlib_wrap\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bdate_format\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bdatetime_format\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bdeadlock_search_depth_long\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bdeadlock_search_depth_short\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bdeadlock_timeout_long\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bdeadlock_timeout_short\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bdebug_no_thread_alarm\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bdefault_master_connection\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bdefault_regex_flags\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bencrypt_binlog\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bencrypt_tmp_files\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bencrypt_tmp_disk_tables\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bexpensive_subquery_limit\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bextra_max_connections\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bextra_port\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bgtid_binlog_pos\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bgtid_binlog_state\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bgtid_cleanup_batch_size\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bgtid_current_pos\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bgtid_domain_id\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bgtid_ignore_duplicates\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bgtid_pos_auto_engines\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bgtid_seq_no\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bgtid_slave_pos\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bgtid_strict_mode\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bhave_crypt\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bhave_query_cache\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bhistogram_size\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bhistogram_type\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bidle_readonly_transaction_timeout\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bidle_transaction_timeout\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bidle_write_transaction_timeout\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bignore_builtin_innodb\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bin_predicate_conversion_threshold\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bin_transaction\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_checksums\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_compression_',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_deadlock_report\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_default_encryption_key_id\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_defragment\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_disallow_writes\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_encrypt_',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_fatal_semaphore_wait_threshold\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_force_primary_key\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_idle_flush_pct\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_immediate_scrub_data_uncompressed\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_instant_alter_column_allowed\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_locks_unsafe_for_binlog\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_prefix_index_cluster_optimization\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_read_only_compressed\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_stats_modified_counter\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_stats_sample_pages\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_stats_traditional\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\binnodb_use_atomic_writes\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bjoin_buffer_space_limit\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bjoin_cache_level\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bkey_cache_file_hash_size\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bkey_cache_segments\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\blog_bin_compress\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\blog_bin_compress_min_len\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\blog_disabled_statements\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\blog_slow_disabled_statements\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\blog_slow_filter\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\blog_slow_rate_limit\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\blog_slow_verbosity\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\blog_syslog*\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\blog_tc_size\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\blog_warnings\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bmax_long_data_size\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bmax_password_errors\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bmax_recursive_iterations\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bmax_session_mem_used\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bmax_statement_time\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bmax_tmp_tables\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bmrr_buffer_size\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bmyisam_block_size\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bold_mode\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bold_passwords\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\boptimizer_selectivity_sampling_limit\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\boptimizer_use_condition_selectivity\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bplugin_maturity\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bprogress_report_time\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bproxy_protocol_networks\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bquery_cache_',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bread_binlog_speed_limit\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\breplicate_annotate_row_events\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\breplicate_do_db\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\breplicate_do_table\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\breplicate_events_marked_for_skip\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\breplicate_ignore_db\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\breplicate_ignore_table\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\breplicate_wild_do_table\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\breplicate_wild_ignore_table\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\browid_merge_buff_size\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\brpl_semi_sync_',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bs3_',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bsecure_auth\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bsecure_timestamp\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bskip_parallel_replication\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bskip_replication\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bslave_ddl_exec_mode\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bslave_domain_parallel_threads\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bslave_parallel_max_queued\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bslave_parallel_mode\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bslave_parallel_threads\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bslave_transaction_retry_errors\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bslave_transaction_retry_interval\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bsql_if_exists\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bstandard_compliant_cte\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bstorage_engine\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bstrict_password_validation\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bsync_frm\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bsystem_versioning_alter_history\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bsystem_versioning_asof\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\btcp_keepalive_interval\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\btcp_keepalive_probes\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\btcp_keepalive_time\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\btcp_nodelay\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bthread_concurrency\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bthread_pool_dedicated_listener\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bthread_pool_exact_stats\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bthread_pool_idle_timeout\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bthread_pool_max_threads\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bthread_pool_min_threads\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bthread_pool_oversubscribe\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bthread_pool_prio_kickup\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bthread_pool_priority\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\btime_format\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\btimed_mutexes\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\btmp_disk_table_size\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\btmp_memory_table_size\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\btx_isolation\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\btx_read_only\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\buse_stat_tables\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\buserstat\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bversion_malloc_library\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bversion_source_revision\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bversion_ssl_library\b',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	],
[ '\bwsrep_',			[undef,	undef, 	undef, 	undef,	undef,	undef,	1]	]
);
# AT THIS STADE, COMMENTS SHOULD BE PREPROCESSED.

# Pattern detection list that will be done without comment
my @TAB_SQL_PATTERN_2 = (
  # PATTERN			SYBASE	TSQL	PLSQL	MYSQL	POSTG.	DB2 MARIADB
  # banish ":" to filter TSQL labels
[ '^\s*loop\b\s*[^:]',			[undef,	undef, 	1, 	1,	1,	1,	undef    ]	],
[ '\bvarchar2\b',		[undef,	undef, 	1, 	undef,	undef,	undef,	undef]	],
[ ':=',				[undef,	undef, 	1, 	1,	1,	undef,	undef]	],
[ '\bLANGUAGE\b',		[undef,	undef, 	undef, 	undef,	1,	1,	undef    ]	],
[ '\bDB2\b',			[undef,	undef, 	undef, 	undef,	undef,	1,	undef]	],
[ '\s+\$\w*\$\s+',			[undef,	undef, 	undef, 	undef,	1,	undef,	undef]	], # dollar quoted string
[ '\bpg\_\w+\b',			[undef,	undef, 	undef, 	undef,	1,	undef,	undef]	],
[ '\b(?:int4|int8|num|ts|tstz|date)range\b',			[undef,	undef, 	undef, 	undef,	1,	undef,	undef]	],
[ '\b(?:mysql|InnoDB|MyISAM)\b',			[undef,	undef, 	undef, 	1,	undef,	undef,	undef]	],
[ '\bDELIMITER\b',			[undef,	undef, 	undef, 	1,	undef,	undef,	undef]	],
[ '\bCURDATE\b',			[undef,	undef, 	undef, 	1,	undef,	1,	undef]	],
[ '\bSTR_TO_DATE\b',			[undef,	undef, 	undef, 	1,	undef,	undef,	undef]	],
[ '\bWITH\s+RECURSIVE\b',			[undef,	undef, 	undef, 	1,	1,	undef,	undef]	],

);

my @SQL_pattern;
my @SQL_pattern2;


sub removeComments($) {
  my $buffer = shift;

  #$$buffer =~ s/\/\*(?:[^*]|\*[^\/])*\*\/|"(?:\\"|[^"])*"|'(?:\\'|[^'])*'//sg;
  #$$buffer =~ s/\/\*(?:[^*]|\*[^\/])*\*\///sg;
  $$buffer =~ s/\/\*.*?\*\///gs;

  $$buffer =~ s/--[^\n]*//sg; # sql classic comment syntax
  $$buffer =~ s/\#[^\n]*//sg; # another mysql comment sytax
}

sub applyPatterns($$$$) {
	my $patterns = shift;
	my $buffer = shift;
	my $r_potential = shift;
	my $status = shift;

	for my $pattern (@$patterns) {
		# if the pattern is found ...
		if ($$buffer =~ /$pattern->[0]/ism) {
#print STDERR "MATCHED : $pattern->[0] !!!\n";
			# if it is the first pattern that matches
			if ($status == STATUS_NO_MATCH) {
				$status = STATUS_SOME_MATCH;
				# All associated technos are considered possible.
				for my $techno_id (@{$pattern->[1]}) {
#print STDERR "--> SET POTENTIAL TECHNO : $TECH{$techno_id}\n";
					$r_potential->{$techno_id} = 1;
				}
			}
			# if some pattern have already matched ...
			else {
				my %new_list = ();

				# For each technos associated with the matched pattern ...
				for my $techno_id (@{$pattern->[1]}) {
					# check if it was previousy detected ...
					if (defined $r_potential->{$techno_id}) {
#print STDERR "--> CONFIRM POTENTIAL TECHNO : $TECH{$techno_id}\n";
						# The technology previously detected is confirmed.
						$new_list{$techno_id} = 1;
					}
					else {
						# The potential technology is not compatible with previous matched patterns.
#print STDERR "--> techno ".$TECH{$techno_id}." is not compatible with previous matched pattern\n";
					}
				}

				# if some technologies have been confirmed, then substitute the new list to the
				# old. Indeed, if %new_list is empty, this signifies that no pattern has matched
				# or that old matched patterns were not compliant with previoulsly detected technos.
				if ((scalar keys %new_list > 0)) {
					my @potechs = keys %$r_potential;
					for my $tech_id (@potechs) {
						if (! defined $new_list{$tech_id}) {
							delete $r_potential->{$tech_id};
						}
					}
				}
			}
		}

		if ((scalar keys %$r_potential) == 1) {
			# If it remains only one potential techno, then stop checking ...
			# Theoretically, the following patterns in the list should not be incompliant
			# with this last potential techno unles two cases :
			# - we are in presence of an unknow SQL techno, then the pattern combination
			#   is no more compliant with its syntax.
			# - there is an inconsistency in the pattern for identifying the known techno
			# ==> we ignore these case !!

			# says that the check is aborted.
			$status = STATUS_END_CHECK;
			last;
		}
	}

	# status is :
	#   STATUS_SOME_MATCH if a first pattern has already matched at this time.
	#   STATUS_NO_MATCH if a first pattern has never matched at this time.
	#   STATUS_END_CHECK if the check process is to be stopped
	return $status;
}


sub ExtractSQL($) {
  my $buffer = shift;

  my %H_empty = ();
  my $r_potential = \%H_empty;
  my $status = STATUS_NO_MATCH;

  # check patterns applying to whole code
  $status = applyPatterns(\@SQL_pattern, $buffer, $r_potential, $status);

  # Check additional patterns after removing string and comments.
  # unless techno is already found.
  #if ((scalar keys %$r_potential) != 1 ) {
  if ( $status != STATUS_END_CHECK) {
    removeComments($buffer);
    $status = applyPatterns(\@SQL_pattern2, $buffer, $r_potential, $status);
  }

  my @Present = ();
  my @Absent = ();

  # Check if some potential sql technos have matched.
  # If none technos have been detected, this signifies that none pattern has matched.
  # So none techno can be declared present or absent.
  if ((scalar keys %$r_potential) > 0) {

    # TECHNO PRESENT
    # if there is only one potential techno, then we consider it is the techno.
    # indeed, if several techno are present, then none sould be resolved because
    # it could not be several technos in the same file.
    if ((scalar keys %$r_potential) == 1 ) {
      my $sqltech_id = (keys %$r_potential)[0];
      push @Present, $TECH{$sqltech_id};;
    }

    # TECHNO ABSENT
    # For each SQL techno, check if they have been recognized as potentially present
    # in the source file.
    for my $sqltech_id ( @SQL_TECHNO_LIST) {

      if (! defined $r_potential->{$sqltech_id} ) {
	# techno not recognized are declared absent, then they will be removed from
	# potential techno later.
        push @Absent, $TECH{$sqltech_id};
      }
    }
  }
  return (\@Present, \@Absent);
}

# PRELIMINARY : the buffer is assumed to correspond to a PlSql or T Sql file
# sub checkPlSql($) {
  # my $buffer = shift;

  # if ($$buffer =~ /\b(?:elsif|package|loop|varchar2)\b|:=|\bnumber\(/i) {
    # return 1;
  # }
  # if ($$buffer =~ /^\s*\/\s*$/im) {
    # return 1;
  # }
  # return undef;
# }

# PRELIMINARY : the buffer is assumed to correspond to a PlSql or T Sql file
# sub checkTSql($) {
  # my $buffer = shift;

  # if ($$buffer =~ /\b(?:declare|set|if)\s+\@|\b(?:nvarchar)\b|\bnumeric\(/i) {
    # return 1;
  # }
  # if ($$buffer =~ /^\s*go\s*$/im) {
    # return 1;
  # }
  # return undef;
# }

sub checkKsh($;$) {
  my $buffer = shift;

  if (isMarkupFormat($buffer)) {
	  return -1;
  }

  if ($$buffer =~  /\A^#!\s*\/[\w\/]+\/(?:ksh|sh|bash)\W/)
  {
    return 1;
  }
# HL-1753 .yml files incorrectly associated to Ksh analyzer
#  if ($$buffer =~ /^\s*#?\s*if\s*\[/m)
#  {
#    return 1;
#  }

  return undef;
}

sub checkCobol($;$) {
  my $buffer = shift;

  if (isMarkupFormat($buffer)) {
	  return -1;
  }

  my $cobol_control_detected = 0;
  my $cobol_division_detected = 0;
  my $cobol_data_detected = 0;

  # If the code has less than 20 lines, prevent to check fixformat because
  # the probability of erroneous detection is too high.
#  my $nblines = () = $$buffer =~ /\n/g;
#  if ($nblines > 20) {
    my $fixForm = Cobol::Vue::PrepareBuffer ($buffer);

#    if ($fixForm eq 1) {
      # if the fix format has anything else than a space char in its 7th
      # column, then valid it is a cobol fix format.
      # NOTE : the first 6 columns have been removed by Cobol::Vue::PrepareBuffer,
      #        so we shold check the first column !!!
#      if ($$buffer =~ /^([^ ])/) {
#        return 1;
#      }
#      # else there is a doubt it is really a cobol file ...
#    }
#  }

  if ($$buffer =~ m/^\s+(PROCEDURE|IDENTIFICATION)\s+DIVISION\s*\./sm) {
    $cobol_division_detected = 1;
    return 1;
  }

  if ($$buffer =~ /^[^*]\s*end-(?:if|exec|evaluate)\s*\./im) {
    $cobol_control_detected = 1;
    return 1;
  }

  # FIXME : strongest check could be :
  #   A line beggining with 01 and ending with a dot and :
  #      - containing "PIC"
  #      or
  #      - followed by another line beginning with a number different of 01
  #        and containing PIC and ending with a dot.
  #
  #  ^ 01\s+[\w\-]\s+*.*(?:\bPIC\b.*\.\s*$|^\s+\d[023456789]\s+.*\bPIC\b.*\.$)

  if ($$buffer =~ m/^ 01\s+[\w\-]+\s+.*\.\s*$/im) {
    $cobol_data_detected = 1;
    return 1;
  }

  if ($$buffer =~ m/^(|......)\s*\d+\s+[\w\-]+\s+pic\b.*\.\s*$/im) {
    $cobol_data_detected = 1;
    return 1;
  }

  return undef;
}

sub checkPL1($;$) {
  my $buffer = shift;
  my $strong_verif = shift;

  if (isMarkupFormat($buffer)) {
	  return -1;
  }

  if (!defined $strong_verif) {
    $strong_verif = 0;
  }

  my $proc_detected = 0;
  my $decl_detected = 0;

  # check presence of procedure
  # <label> : proc (
  # <label> : proc <name> (
  # <label> : proc ... ;
  my $name_parenth = '(?:[^\s(]+\s*)\(';  # a NON BLANK followed by PARENTHESIS
  my $anything_until_semicolon = '[^\n;]*;';
  #if ( $$buffer =~ /^.\s*\w+\s*:\s*proc(edure)?\b\s*(?:(?:[^\s(]+\s*)?\(|[^\n;]*;)/sim) {
  if ( $$buffer =~ /^.\s*\w+\s*:\s*proc(edure)?\b\s*(?:$name_parenth|$anything_until_semicolon)/sim) {
    $proc_detected = 1;
  }

  if ( $strong_verif ) {
    # STRONG CHECKING : need both proc AND declaration.
    # -> used to check from unknow extension extension)
    if ( $$buffer =~ /^.\s*(?:dcl|declare)\b/sim) {
		$decl_detected = 1;
    }

    if ($proc_detected && $decl_detected) {
      return 1;
    }
  }
  else {
	# LIGHT CHECKING : need proc OR strong declaration.
	# -> used to check from potential techno (due to extension)
	if ($proc_detected) {
		return 1;
	}

	my $needJavaScriptSyntaxCheck = 0;
	my $needCobolEndExecCheck = 0;
	# search a line beginning with "dcl/declare", and :
	# - ending with "," or ";"
	# OR
	# - having the patterns "char(xxx)" or "fixed(xxx)"
	#
	# WARNING :
	#       1) PL1 vs Typescript
	#              the keyword "declare" of PL1 program could be mingled with TypeScript "declare" syntax
	#              declare (function|module|type|let|var|const)  => pattern for a Type Script File.
	#              https://www.typescriptlang.org/docs/handbook/modules.html
	#          ==> add aditional check to discrmine TypeSript and PL1.
	#
	#       2) PL1 vs COBOL
	# 			both have the the "EXEC SQL DECLARE" pattern at a line beginning.
	#			but for Cobol, the statement ends with END-EXEC, whereas it ends with ";" for PL1.

	#                        <...$1...>
	my $SQL_DECLARE = '^.\s*(EXEC\s+SQL)\s+(?:DECLARE\b)?';
	#                          <....$2....>    <....................$3.........<-$4->....>
	my $OTHERS_DECLARE = '^.\s*(dcl|declare)\s+(\w+[^\n]*(?:(?:char|fixed)\s*\(|([;,])\s*$))';
	while ( $$buffer =~ /(?:$SQL_DECLARE)|$OTHERS_DECLARE/img) {
		if (defined $1) {
			$needCobolEndExecCheck = 1;
		}
		else {
			if ($2 eq 'declare') {
				if (defined $3) {
					# "declare" keyword detected and line ending with ";" or ","
					# 		--> possible confusion with TypeScript ...
					my $arg = $3;
					# check for specific TypeScript syntax in the "declare" argument ...
					if ($arg =~ /^(?:\w+\s+)?(?:function|module|class|type|let|var|const|enum|import)\s+[\w"'\$]+\s*[(\{<,;:=]/m) {
						# TypeScript syntax detected, it's not PL1
						$decl_detected = 0;
						$needJavaScriptSyntaxCheck = 0;
						last;
					}
					else {
						# unrecognized "declare" syntax :
						#  ==> assume PL1 by default, continue to check other "declare" instructions and if any, check if the whole code contains Javascript syntax.
						$decl_detected = 1;
						$needJavaScriptSyntaxCheck = 1;
					}
				}
				else {
					# PL1 syntax detected
					$needJavaScriptSyntaxCheck = 0;
					last;
				}
			}
			else {
				# "dcl" keyword means it's PL1
				$decl_detected = 1;
				$needJavaScriptSyntaxCheck = 0;
				last;
			}
		}
	}

	if ($needCobolEndExecCheck) {
		if ( $$buffer =~ /^.\s*END-EXEC\b/im ) {
			# not a PL1 program
			return undef;
		}
	}

	if ($needJavaScriptSyntaxCheck) {
		# check for Javascript (so TypeScript) syntax elements in whole code...
		if ( $$buffer =~ /[\w\)]\s*\{|>\s*[\)\{]|^\s*var\s+\w+\s*[;=,]/sim ) {
			# it can not be a PL1 file because PL1 do not have syntax using braces, nor ">" for other usage than comparator.
			# Keyword 'declare' + use of '{' could be a TypeScript detection ...
			# NOTE : 'function' is another javascript keyword absant from PL1 grammar, if needed ...
			$decl_detected = 0;
		}
	}

	# search a line beginning with a number, and :
	# - ending with "," or ";"
	# AND
	# - having the patterns "char(xxx)" or "fixed(xxx)"

	elsif ( $$buffer =~ /^.\s*\d+\s+\w+[^\n]*\b(?:char|fixed)\s*\([^\n]*[;,]\s*$/im ) {
		$decl_detected = 1;
	}

	if ($decl_detected) {
		return 1;
	}
  }
  return undef;
}

sub check_ObjC($) {
  my $buf = shift;

  if (isMarkupFormat($buf)) {
	  return -1;
  }

  if ($$buf =~ m/^\s*(?:\/\/|\#|\@(?:interface|implementation|protocol|def|class)\b)/sgm) {
      return 1;
  }
  else {
    # Can belong to an Objective C application,
    # but can not say by analysing content.
    # returning undef keep ObjC as potential techno
    return undef;
  }
}

sub checkMatlab($) {
  my $buf = shift;

  if (isMarkupFormat($buf)) {
	  return -1;
  }

  if ($$buf =~ m/^\s*(?:\%|function\b)/sgm) {
      return 1;
  }
  else {
    # Can belong to a Matlab application,
    # but can not say by analysing content.
    # returning undef keep Matlab as potential techno
    return undef;
  }
}

sub check_Apex($) {
  my $buf = shift;

  if (isMarkupFormat($buf)) {
	  return -1;
  }

# detect comment syntax:
# single or multiline
# // or /*...*/
# or
# annotation
  if (($$buf =~ m/\/\*/sg and $$buf =~ m/\*\//sg)
	or ($$buf =~ m/^\s*(?:\@\w+|\/\/)/smg))
  {
      return 1;
  }
  else {
    # Can belong to a Apex application,
    # but can not say by analysing content.
    # returning undef keep Apex as potential techno
    return undef;
  }
}

sub check_CCpp($) {
  my $buf = shift;

  if (isMarkupFormat($buf)) {
	  # obviously not CCpp !
	  return -1;
  }

  # returning undef keep CCpp as potential techno
  return undef;
}

sub check_VbDotNet($) {
  my $buf = shift;

  # Assuming that a file beginning with the two following lines is a VbDotNet (VB6) file:
  # VERSION xxxxx
  # Begin VB.Form ....
  if ($$buf =~ /\AVERSION\b[^\n]*\nBegin\s+VB.Form\b/) {
	  return 1;
  }

  # returning undef keep CCpp as potential techno
  return undef;
}

sub check_Name($) {
  my $filenode = shift;

  my $name = $filenode->[FILE_NAME];

  if ($name =~ /^SAP_R3WDYN_/) {
    return Abap;
  }
  elsif ($name =~ /^web\.xml$/i) {
		if ($filenode->[FILE_DIR]->[DIR_NAME] =~ /\bWEB-INF[\\\/]?$/) {
			return JSP;
		}
  }
  # TLD are recognized directly from extension
  #elsif ($name =~ /\.tld$/i) {
  #		if ($filenode->[FILE_DIR]->[DIR_NAME] =~ /(?:[\\\/]|\A)WEB-INF(?:[\\\/]|\z)/) {
  #			return JSP;
  #		}
  #}

  return undef;
}

sub init_check()
{
  if ($DESACTIVATE_SYBASE) {
	  for my $pattern (@TAB_SQL_PATTERN) {
		  $pattern->[1]->[SYBASE_ID] = undef;
	  }
  }

  # for each pattern
  for my $pattern (@TAB_SQL_PATTERN) {
    # list of sql technos associated with a pattern
    my @technos = ();

    # build the list of technos.
    my $techno_id = 0;
    for my $tech (@{$pattern->[1]}) {

      if ($tech) {
        push @technos, $techno_id;
      }
      $techno_id++;
    }

    # Associate each pattern with its list of technos
    push @SQL_pattern, [$pattern->[0], \@technos];
  }

  # for each pattern
  for my $pattern (@TAB_SQL_PATTERN_2) {
    # list of sql technos associated with a pattern
    my @technos = ();

    # build the list of technos.
    my $techno_id = 0;
    for my $tech (@{$pattern->[1]}) {

      if ($tech) {
        push @technos, $techno_id;
      }
      $techno_id++;
    }

    # Associate each pattern with its list of technos
    push @SQL_pattern2, [$pattern->[0], \@technos];
  }
}

1;
