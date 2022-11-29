

package TSql::CountSQL;
# Module du comptage TDB: Nombre de procedures internes non referencees.

use strict;
use warnings;

use TSql::Node;
use TSql::TSqlNode;
use TSql::Identifier;

use Erreurs;

use Ident;

use CountUtil;

my $DEBUG=1;

sub analyze_Transaction_SQL($;$$$);
sub countUnsafeSQL($$);
sub checkFinalReturn($);
sub CountRoutine($$$);
sub CheckComplexArtifact($$);

my $Nbr_InsertWithoutColumnsList__mnemo = Ident::Alias_InsertWithoutColumnsList();
my $Nbr_WithMultiExprPerLine_Where__mnemo = Ident::Alias_WithMultiExprPerLine_Where();
my $Nbr_BadQualifiedDatabaseObject__mnemo = Ident::Alias_BadQualifiedDatabaseObject();
my $Nbr_DBObjectUsingRef__mnemo = Ident::Alias_DBObjectUsingRef();
my $Nbr_NumericalOrderBy__mnemo = Ident::Alias_NumericalOrderBy();
my $Nbr_WithTooManyColumnsTables__mnemo = Ident::Alias_WithTooManyColumnsTables();
my $Nbr_OnToManyTablesQueries__mnemo = Ident::Alias_OnToManyTablesQueries();
my $Nbr_WithoutPrimaryKeyTables__mnemo = Ident::Alias_WithoutPrimaryKeyTables();
my $Nbr_UnCommentedColumns__mnemo = Ident::Alias_UnCommentedColumns();
my $Nbr_TotalColumns__mnemo = Ident::Alias_TotalColumns();

my $nb_InsertWithoutColumnsList = 0;
my $nb_WithMultiExprPerLine_Where = 0;
my $nb_BadQualifiedDatabaseObject = 0;
my $nb_DBObjectUsingRef = 0;
my $nb_NumericalOrderBy = 0;
my $nb_WithTooManyColumnsTables = 0;
my $nb_OnToManyTablesQueries = 0;
my $nb_WithoutPrimaryKeyTables = 0;
my $nb_UnCommentedColumns = 0;
my $nb_TotalColumns = 0;

my $THRESHOLD_MAX_COLUMN = 20;

# Number of line before a "column" in "create table" in which a comment line should be found.
my $COMMENT_ZONE_BEFORE_COLUMN = 2;

# Pattern for the from list :<table> [[AS] <alias>], ... n
 my $FROM_LIST = '[\w\.\#]+\s*(?:(?:AS\s+)?(?:\w+\s*))?(?:,\s*[\w\.\#]+\s*(?:(?:AS\s+)?(?:\w+\s*))?)*';


sub ptr_checkUnCommentedColumns($) {
  my $agglo = shift;
#print "Here's the callback (ptr_checkUnCommentedColumns) !!!!\n";
  if (! CountUtil::IsCommentBeforeAndAt($agglo)) {
    $nb_UnCommentedColumns++;
#print "=======> FOUND a violement !!!\n";
  }
}


sub countCreateTable($$$) {
  my $r_buf = shift;
  my $r_artifact = shift;
  my $r_TabToCheck = shift;

  if ( $$r_buf =~ /\A\s*create\s+table\b/i ) {

    my $artifactLine=undef;

    if ( $$r_artifact =~ /-LINE-(\d+)-/ ) {
      $artifactLine = $1;
    }

    my ($r_columns, $r_rest) = CountUtil::splitAtPeer($r_buf, "(", ")", 1);
    my $nb_columns = 0;
    my $nb_primary = 0;

    # Suppress beginning of the artifact to keep only the columns between parenthesis,
    # and count the corresponding lines deleted.
    my $CutPattern='\A[^(]*\(';
    my $nb_ln = () = $$r_columns =~ /${CutPattern}/s ;
    my $currentLine = $artifactLine + $nb_ln;
    $$r_columns =~ s/${CutPattern}//s ;
    $$r_columns =~ s/,?\s*\).*//s ;

    my @Columns = split (',', $$r_columns);

    # ANALYZE EACH COLUMN ...
    for my $column (@Columns) {

      # Is a primary key defined ?
      if ( $column =~ /\bprimary\s+key\b/si) {
        $nb_primary++;
      }
#print "COLUMN = $column\n";
      # Is it a column (or a table constraint) ? 
      if ( $column !~ /\A\s*constraint\b/si) {
        $nb_columns++;
        $nb_TotalColumns++;
        # Check if commented...
        if ( $nb_UnCommentedColumns != Erreurs::COMPTEUR_ERREUR_VALUE) {
          my ($BeginningPadding) = $column =~ /\A(\s*)\S/s ;
          my $currentColLine = $currentLine;
          $currentColLine += () = $BeginningPadding =~ /(\n)/g ;


          my $beginLine = $currentColLine-$COMMENT_ZONE_BEFORE_COLUMN;
          if ($beginLine < $artifactLine) {
            $beginLine = $artifactLine;
          }

          push @{$r_TabToCheck}, [$beginLine, $currentColLine,  \&ptr_checkUnCommentedColumns ];

        }
      }

      $currentLine += () = $column =~ /(\n)/g ;
    }

    if ( $nb_primary == 0) {
      $nb_WithoutPrimaryKeyTables ++;
    }

    if ($nb_columns > $THRESHOLD_MAX_COLUMN) {
      $nb_WithTooManyColumnsTables ++;
    }
  }

}


sub CountNumericalOrderBy($) {
  my $r_buf = shift;

  if ( $$r_buf =~ /\border\s+by\b(.*?)(?:\bwhere\b|\bgroup\s+by\b|\bhaving\b)?$/sig) {
#print "ITEM : $1\n";
    my @items = split ',', $1;

    for my $item (@items) {
      if ( $item =~ /\A\s*\d+\s*$/s ) {
#print "---> violement\n";
        return 1;
      }
    }
  }
  return 0;
}

sub is_CanonicalObjectIdent($) {
  my $r_item = shift;

  if ( $$r_item =~ /\A\s*#/s ) {
    # rule doesn't apply to temporary objects => return no violation
    return 1;
  }

  my $element = '[^\.]+';
  if ( $$r_item =~ /\[/ ) {
    $element = '\[[^\]]+\]'
  }

  if ( $$r_item =~ /\A\s*$element\s*\.\s*$element/s ) {
    return 1;
  }
  else {
    return 0;
  }
}

sub hasToManyTable($) {
  my $artifact = shift;

  if (TSql::ParseDetailed::get_NbObjects($artifact) > 4) { 
    return 1;
  }
  else {
    return 0;
  }
}

sub count_FROM_NonCanonicalObjectIdent($) {
  my $r_buf = shift;
  my $nb_nonCanonical = 0;

  my @tab_clause = split /\b(from|join)\b/i, $$r_buf ;
  my $i = 0;
  my $imax = scalar @tab_clause - 2;
  while ($i <= $imax) {
    if ( $tab_clause[$i] =~ /\b(?:from|join)\b/i) {
      $i++;
      if (defined $tab_clause[$i] && ($tab_clause[$i] =~ /\s+(${FROM_LIST})/isg)) {
	my @items=split ",", $1;
	for my $item (@items) {
          $nb_DBObjectUsingRef++;
          if (! is_CanonicalObjectIdent(\$item)) {
            $nb_nonCanonical++;
          }
        }
      }
    }
    $i++;
  }
  return $nb_nonCanonical;
}

sub count_TSQL_NonCanonicalObjectIdent($) {
  my $r_buf = shift ;
  my $nb_nonCanonical = 0;

  my $modifiable_buffer = $$r_buf ;

  # Replace grant instructions because they can contain pattern of searched intructions, but 
  # we don't want to recognize it because they belong to the grant instruction.
  $modifiable_buffer =~ s/\bgrant\b.*?\bto\b/GRANT_REPLACED /sig;

  #while ( $$r_buf =~ /\b(?:into|(?:create|drop|truncate)\s+(?:table|view|trigger|procedure|proc|function))\b\s+((?:\.\.|[#\w]+)?\w+\b[^\.])/isg ) {
  while ( $modifiable_buffer =~ /\b(?:into|(?:create|drop|truncate)\s+(?:table|view|trigger|procedure|proc|function))\b\s+($ROUTINE_NAME_PATTERN)/isg ) {
    my $item = $1 ;
    $nb_DBObjectUsingRef++;
#print "OBJECT REF = $item\n";
    if (! is_CanonicalObjectIdent(\$item)) { 
#print " ---> non canonical\n";
      $nb_nonCanonical++;
    }
  }
  return $nb_nonCanonical;
}


sub has_WHERE_MultiExpressionPerLine($) {
  my $r_WhereClause = shift;

  while ( $$r_WhereClause =~ /^(.*)$/mg ) {
    my $line = $1;
    # Search for
    #   1 - two or more operators on same line
    #   2 - one operator with both right and left expression on the same line.
    if ( ( scalar ( () = $line =~  /\b(and|or)\b/ig ) > 1 ) ||
	 ($line =~  /[^\n\t ][ \t]*\b(and|or)\b[ \t]*[^\n\t ]/ig ) ) {
      return 1;
    }
  }
  return 0;
}




#-----------------------  CountSQL ---------------------#
sub CountSQL($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_InsertWithoutColumnsList = 0;
  $nb_WithMultiExprPerLine_Where = 0;
  $nb_BadQualifiedDatabaseObject = 0;
  $nb_DBObjectUsingRef = 0;
  $nb_WithTooManyColumnsTables = 0;
  $nb_OnToManyTablesQueries = 0;
  $nb_WithoutPrimaryKeyTables = 0;
  $nb_UnCommentedColumns = 0;
  $nb_TotalColumns = 0;
  $nb_NumericalOrderBy = 0;

  if ( ! defined $vue->{'code_without_directive'} ) {
    $ret |= Couples::counter_add($compteurs, $Nbr_BadQualifiedDatabaseObject__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    # Nbr_NonCanonicalObjectIdent can not be completely computed without this view. So if it is
    # no available, the counter will not be computed.
    $nb_BadQualifiedDatabaseObject = Erreurs::COMPTEUR_ERREUR_VALUE;
    $nb_DBObjectUsingRef = Erreurs::COMPTEUR_ERREUR_VALUE;
  }

  if ( ! defined $vue->{'agglo'} ) {
    $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedColumns__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    # Counters can not be completely computed without this view. So if it is
    # no available, the counter will not be computed.
    $nb_UnCommentedColumns = Erreurs::COMPTEUR_ERREUR_VALUE;
  }


  my $NomVueCode = 'routines' ; 
  my $ArtifactsView =  $vue->{$NomVueCode} ;
  if ( ! defined $ArtifactsView )
  {
    $ret |= Couples::counter_add($compteurs, $Nbr_InsertWithoutColumnsList__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_WithMultiExprPerLine_Where__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_BadQualifiedDatabaseObject__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_DBObjectUsingRef__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_NumericalOrderBy__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_WithTooManyColumnsTables__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_WithoutPrimaryKeyTables__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_OnToManyTablesQueries__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedColumns__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_TotalColumns__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    return $ret;
  }

  my @TabToCheck = ();

  for my $artifact (keys %{$ArtifactsView}) {
    #**************** Artifact_SqlWithSelect *************
    
    # Artifact_SqlWithSelect is the category of SQL artifact that can contain a select.
    # The Insert instruction belongs to this category.
    if ( $artifact =~ /Artifact_SQL_/) {
      if ($ArtifactsView->{$artifact} =~ /\binsert\s+(.*?)\b(?:select|values|exec|execute|default\s+values)\b/is) {
	my $tmp_stat = $1;
	# Removing of Parenthesis imbrication
        while ( $tmp_stat =~ s/\([^\)]*\([^\(\)]*\)/\(/ ) {} ;
	  
	# Removing of parasitic patterns ("top" and "with") !!
        $tmp_stat =~ s/top\s*\([^()]*\)\s*percent\b|with\s*\([^()]*\)//i;

	# check if the remaining expression ends with (...), that are necessarily columns list :
	if ($tmp_stat !~ /\)\s*$/) {
          $nb_InsertWithoutColumnsList++;
	}
      }

      if ($ArtifactsView->{$artifact} =~ /\bwhere\s+(.*?)(?:\border\s+by\b|\bgroup\s+by\b|\bhaving\b)?$/is) {
        my $where_clause = $1;
        if ( has_WHERE_MultiExpressionPerLine(\$where_clause) ) {
          $nb_WithMultiExprPerLine_Where++;
        }
      }

      if ( $nb_BadQualifiedDatabaseObject != -1 ) {
        $nb_BadQualifiedDatabaseObject += count_FROM_NonCanonicalObjectIdent(\$ArtifactsView->{$artifact});
      }

      #countCreateTable(\$ArtifactsView->{$artifact}, \$artifact, \$vue->{'agglo'});
      countCreateTable(\$ArtifactsView->{$artifact}, \$artifact, \@TabToCheck);

    }

    #**************** Artifact_Select *************
    if ( $artifact =~ /Artifact_select_/)   {
      if ($ArtifactsView->{$artifact} =~ /\bwhere\s+(.*?)(?:\border\s+by\b|\bgroup\s+by\b|\bhaving\b)?$/is) {
        my $where_clause = $1;
        if ( has_WHERE_MultiExpressionPerLine(\$where_clause) ) {
          $nb_WithMultiExprPerLine_Where++;
        }
      }

      $nb_NumericalOrderBy += CountNumericalOrderBy(\$ArtifactsView->{$artifact});

      $nb_OnToManyTablesQueries += hasToManyTable($artifact);

      if ( $nb_BadQualifiedDatabaseObject != -1 ) {
        $nb_BadQualifiedDatabaseObject += count_FROM_NonCanonicalObjectIdent(\$ArtifactsView->{$artifact});
      }
    }
  }

  # Check comments in the pre-defined zones ...
  CountUtil::checkComment(\$vue->{'agglo'}, \@TabToCheck);

  if ( $nb_BadQualifiedDatabaseObject != -1 ) {
    $nb_BadQualifiedDatabaseObject += count_TSQL_NonCanonicalObjectIdent(\$vue->{'code_without_directive'});
  }
  $ret |= Couples::counter_add($compteurs, $Nbr_InsertWithoutColumnsList__mnemo, $nb_InsertWithoutColumnsList );
  $ret |= Couples::counter_add($compteurs, $Nbr_WithMultiExprPerLine_Where__mnemo, $nb_WithMultiExprPerLine_Where );
  $ret |= Couples::counter_add($compteurs, $Nbr_BadQualifiedDatabaseObject__mnemo, $nb_BadQualifiedDatabaseObject );
  $ret |= Couples::counter_add($compteurs, $Nbr_DBObjectUsingRef__mnemo, $nb_DBObjectUsingRef );
  $ret |= Couples::counter_add($compteurs, $Nbr_NumericalOrderBy__mnemo, $nb_NumericalOrderBy );
  $ret |= Couples::counter_add($compteurs, $Nbr_WithTooManyColumnsTables__mnemo, $nb_WithTooManyColumnsTables );
  $ret |= Couples::counter_add($compteurs, $Nbr_WithoutPrimaryKeyTables__mnemo, $nb_WithoutPrimaryKeyTables );
  $ret |= Couples::counter_add($compteurs, $Nbr_OnToManyTablesQueries__mnemo, $nb_OnToManyTablesQueries );
  $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedColumns__mnemo, $nb_UnCommentedColumns );
  $ret |= Couples::counter_add($compteurs, $Nbr_TotalColumns__mnemo, $nb_TotalColumns );

  return $ret;
}

1;



