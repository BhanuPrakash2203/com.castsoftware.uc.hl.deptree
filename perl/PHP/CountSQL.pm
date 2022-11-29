package PHP::CountSQL;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use PHP::PHPNode;

use CountUtil;

my $GroupBy__mnemo = Ident::Alias_GroupBy();
my $OnToManyTablesQueries__mnemo = Ident::Alias_OnToManyTablesQueries();
my $Queries__mnemo = Ident::Alias_Queries();

my $nb_GroupBy = 0;
my $nb_OnToManyTablesQueries = 0;
my $nb_Queries = 0;

my $MAX_NB_TABLE = 4;

#SELECT [STRAIGHT_JOIN]
#       [SQL_SMALL_RESULT] [SQL_BIG_RESULT] [SQL_BUFFER_RESULT]
#       [SQL_CACHE | SQL_NO_CACHE] [SQL_CALC_FOUND_ROWS] [HIGH_PRIORITY]
#       [DISTINCT | DISTINCTROW | ALL]
#    select_expression,...
#    [INTO {OUTFILE | DUMPFILE} 'nom_fichier' export_options]
#    [FROM table_references
#      [WHERE where_definition]
#      [GROUP BY {unsigned_integer | nom_de_colonne | formula} [ASC | DESC], ...
#      [HAVING where_definition]
#      [ORDER BY {unsigned_integer | nom_de_colonne | formula} [ASC | DESC] ,...]
#      [LIMIT [offset,] lignes]
#      [PROCEDURE procedure_name(argument_list)]
#      [FOR UPDATE | LOCK IN SHARE MODE]]


my $END_FROM_PATTERN = '(?:\Z|\bINTO\b|\bWHERE\b|\bGROUP\s+BY\b|\bHAVING\b|\bORDER\s+BY\b|\bLIMIT\b|\bPROCEDURE\b|\bFOR\s+UPDATE\b|\bLOCK\b)';


sub check_SQL($);
sub getParethesisedQueries($;$);

sub getParethesisedQueries($;$) {
  my $req = shift;
  my $list = shift;

  if (!defined $list) {
    my @empty = ();
    $list = \@empty;
  }

  if ($$req =~ /\A\s*\(/) {
    # split the expression at the closing parenthesis of the first query.
    my ($r_query, $r_right) = CountUtil::splitAtPeer($req, '(', ')');
    $$r_query =~ s/\A\(//;
    $$r_query =~ s/\)\Z//;
    push @{$list}, $r_query;

    # Unless the end of the SQL expression, the next pattern should be
    # an "union" syntax keyword like "union" or "order by". But only the 
    # "union" keyword is interesting because it is the only one that is followed
    # by a query.
    if ($$r_right =~ /\A\s*union\b/i) {
      $$r_right =~ s/\A\s*union\b(?:\s+(?:ALL|DISTINCT))?\s*//si;
      return getParethesisedQueries($r_right, $list)
    }
    else {
      if ($$r_right =~ /\S/ ) {
	      # print "PARSE INFO : unmatched part of the SQL expression query : $$r_right\n";
      }
    }
  }
  else {
    # not a prenthesised query. Push in the list then return.
    push @{$list}, $req;
  }

  return $list;
}

sub check_SQL($) {
  my $req = shift;

  my $ID = 0;
  my @SubQueries = ();

  # 1 - PROCESS parenthesised gathered queries (separated with UNION keyword)
  # ===========================================
  # EXAMPLE : (select1 ... ) UNION ((select2 ...) UNION (select3 ... )
  # --> will return a list of three queries : (select1..., select2..., select3...)
  # RQ : about union syntax; parenthesised queries are mandatory for use with ORDER BY clause to sort the result of the union :
  #   (SELECT ...)
  #   UNION [ALL | DISTINCT]
  #   (SELECT ...)
  #       :
  #      [UNION [ALL | DISTINCT]
  #      (SELECT ...)]
  #       :
  #   ORDER BY
  #
  my $Gathered_ParethesisQueries = getParethesisedQueries($req);

  # First query is affected to the current treatment, others queries (if any)
  #  will be analyzed later.
  $req = shift @{$Gathered_ParethesisQueries};

  # 2 - EXTRACT subqueries.
  # =======================
  # EXAMPLE : 
  #                       select column1, (select from toto) from tata
  # --> will return 
  #                       select column1, (SUBQUERY_x) from tata
  #      into $$req and 
  #                       select from toto
  #      in a list of subqueries.
  # Subqueries are always enclosed in parenthesis.
  while ( $$req =~ /(.*?)(\(\s*select\b.*)/is) {
    my $left = $1;
    my $rest = $2;
    my ($r_subquery, $r_right) = CountUtil::splitAtPeer(\$rest, '(', ')');

    $$req = "$left(SUBQUERY_$ID)$$r_right";

    $$r_subquery =~ s/\A\(//;
    $$r_subquery =~ s/\)\Z//;
    push @SubQueries, $r_subquery;
    $ID++;
  }

  # 3 - PROCESS un-parenthesised gathered queries (separated with UNION keyword)
  # =============================================
  # EXAMPLE : 
  #           select1 ...  UNION select2 ... UNION select3 ... 
  # --> will return a list of three queries : 
  #          (select1..., select2..., select3...)
  # RQ : about union syntax :
  #   SELECT ...
  #   UNION [ALL | DISTINCT]
  #   SELECT ...
  #   [UNION [ALL | DISTINCT]
  #      SELECT ...]
  
  my @Gathered_Queries = split /\bunion\b(?:\s+(?:ALL|DISTINCT))?\s*/i, $$req;

  # the first query is treated now, other will be treated later ...
  $$req = shift @Gathered_Queries;

  # 4 - TREATMENT of the SQL expression (or first query in case of query union)
  # ===========================================================

  # CASE of a SELECT query
  if ( $$req =~ /\A\s*SELECT\b/is ) {

    $nb_Queries++;

    if ( $$req =~ /\bgroup\s+by\b/sig) {
      $nb_GroupBy ++;
    }

    my ($FromClause) = $$req =~ /\bfrom\b(.*?)$END_FROM_PATTERN/si;
    if (defined $FromClause) {
#print "===> FROM = $FromClause\n";

      my $nb_tables = () = $FromClause =~ /(?:,|\bjoin\b)/ig ;
      $nb_tables ++;
#print "++++> NB TABLES = $nb_tables\n";
      if ($nb_tables > $MAX_NB_TABLE) {
#print "-----------> TOO MANY TABLES !!!!!\n";
       $nb_OnToManyTablesQueries++;
      }
    }
  }

  # 5 - TREATMENT of gathered parenthesised queries (case of union)
  # ===========================================================
#print "------------- GATHERED PARENTHESISED QUERIES--------------\n";
  # Treatment of gathered subqueries.
  for my $r_gatQ (@{$Gathered_ParethesisQueries}) {
    check_SQL($r_gatQ);
  }

  # 6 - TREATMENT of gathered un-parenthesised queries (case of union)
  # ===========================================================
#print "------------- GATHERED UN-PARENTHESISED  QUERIES--------------\n";
  # Treatment of gathered subqueries.
  for my $gatQ (@Gathered_Queries ) {
    check_SQL(\$gatQ);
  }

  # 7 - TREATMENT of sub-queries
  # ============================
#print "------------- SUB QUERIES --------------\n";
  # Treatment of subqueries.
  for my $r_subQ (@SubQueries) {
    check_SQL($r_subQ);
  }
#print "#####################################\n";
}


sub CountSQL($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_GroupBy = 0;
  $nb_OnToManyTablesQueries = 0;
  $nb_Queries = 0;

  if ( ( ! defined $vue->{'code'} ) || ( ! defined $vue->{HString} ) )
  {
    $ret |= Couples::counter_add($compteurs, $GroupBy__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $OnToManyTablesQueries__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $HStrings = $vue->{HString};
  my $code = $vue->{code};

  # Find requests ...
  # ==================
  my %Request_keys = ();
  # Search in all string if they are an SQL request beginning ...
  for my $key (keys %{$HStrings}) {
#print "$key\n";
    if ($HStrings->{$key} =~ /\A["']\s*(\(?\s*SELECT|UPDATE|INSERT|DELETE)\b/ism) {
#print "====> it's a request !!\n";
      $Request_keys{$key} = 1;
    }
  }

  # expand request ...
  # ==================
  while ($code =~ /([=\(])\s*(CHAINE_\d+)\b\s*(\.\s*[^;]+)?;/sg ) {
    if (exists $Request_keys{$2}) {
      my $request = $HStrings->{$2};
      my $endpart = $3;
      my $affect_op = $1;
      $request =~ s/\A["']// ;
      $request =~ s/["']\Z// ;

      if (defined $endpart) {

	if ($affect_op eq '(') {
          #search the closing parenthesis
	  # a - add the openning
	  my $tmp_expr = '('. $endpart;
	  # b - split at the closing
          my ($r_endpart, $r_dummy) = CountUtil::splitAtPeer(\$tmp_expr, '(', ')');
          # c - endpart become the content of the parenthesis.
          ($endpart) = $$r_endpart =~ /^\((.*)\)$/sm;
	}

        my @elements = split /\./, $endpart;

        # add all elements of the request ...
        for my $elem (@elements) {
          if ($elem =~ /\A\s*(CHAINE_\d+)\s*\Z/s) {
            my $part = $HStrings->{$1};
            $part =~ s/\A["']// ;
            $part =~ s/["']\Z// ;
	    $request .= $part;
  	  }
	  else {
	    if ( $elem =~ /\S/s ) {
	      $request .= '__COMPUTED__';
            }
  	  }
        }
      }
#print "FOUND A REQUEST : $request\n";
      check_SQL(\$request);
    }
  }



  $ret |= Couples::counter_add($compteurs, $GroupBy__mnemo, $nb_GroupBy );
  $ret |= Couples::counter_add($compteurs, $OnToManyTablesQueries__mnemo, $nb_OnToManyTablesQueries );
  $ret |= Couples::counter_add($compteurs, $Queries__mnemo, $nb_Queries );

  return $ret;
}


1;
