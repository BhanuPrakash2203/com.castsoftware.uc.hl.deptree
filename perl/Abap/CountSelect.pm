

package Abap::CountSelect;

use strict;
use warnings;

use Lib::Node;
use Abap::AbapNode;
use SourceUnit;

use Erreurs;

use Ident;

my $NB_MAX_COLUMNS = 9 ;
my $NB_MAX_TABLES = 4 ;

my $TAB_PATTERN ='[\w\-~\/]+';

my $END_WHERE_PATTERN = '(?:\Z|\bFROM\b|\bINTO\b|\bGROUP\s+BY\b|\bORDER\s+BY\b)';
my $END_FROM_PATTERN = '(?:\Z|\bINTO\b|\bWHERE\b|\bUP\s+TO\b|\bBYPASSING\s+BUFFER\b|\bCLIENT\s+SPECIFIED\b|\bGROUP\s+BY\b|\bORDER\s+BY\b)';
my $END_COLUMNS_PATTERN = '(?:\Z|\bFROM\b|\bINTO\b|\bWHERE\b|\bGROUP\s+BY\b|\bORDER\s+BY\b)';

my $SelectBypassingBuffer__mnemo = Ident::Alias_SelectBypassingBuffer();
my $IsNullInWhereClause__mnemo = Ident::Alias_IsNullInWhereClause();
my $NotOpInWhereClause__mnemo = Ident::Alias_NotOpInWhereClause();
my $MissingWhereClause__mnemo = Ident::Alias_MissingWhereClause();
my $SelectForUpdate__mnemo = Ident::Alias_SelectForUpdate();
my $DynamicQueries__mnemo = Ident::Alias_DynamicQueries();
my $ComplexQueries__mnemo = Ident::Alias_ComplexQueries();
#my $SubQueries__mnemo = Ident::Alias_SubQueries();
my $OnToManyTablesQueries__mnemo = Ident::Alias_OnToManyTablesQueries();
my $Select__mnemo = Ident::Alias_Select();

my $nb_SelectBypassingBuffer = 0;
my $nb_IsNullInWhereClause = 0;
my $nb_NotOpInWhereClause = 0;
my $nb_MissingWhereClause = 0;
my $nb_SelectForUpdate = 0;
my $nb_DynamicQueries = 0;
my $nb_ComplexQueries = 0;
#my $nb_SubQueries = 0;
my $nb_OnToManyTablesQueries = 0;
my $nb_Select = 0;


sub CountSelect($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  $nb_SelectBypassingBuffer = 0;
  $nb_IsNullInWhereClause = 0;
  $nb_NotOpInWhereClause = 0;
  $nb_MissingWhereClause = 0;
  $nb_SelectForUpdate = 0;
  $nb_ComplexQueries = 0;
  $nb_OnToManyTablesQueries = 0;
  $nb_Select = 0;

  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $SelectBypassingBuffer__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $IsNullInWhereClause__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $NotOpInWhereClause__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $MissingWhereClause__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $SelectForUpdate__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ComplexQueries__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $OnToManyTablesQueries__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Select__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @Selects = GetNodesByKind( $root, SelectKind);
  my @Deletes = GetNodesByKind( $root, DeleteKind);
  my @Updates = GetNodesByKind( $root, UpdateKind);

  my @Sqls = (@Selects, @Deletes, @Updates);

  $nb_Select = scalar @Selects;

  for my $sql ( @Sqls) {

    my $stmt = GetStatement($sql);

    # Rules for SELECT only
    # -----------------------------------

    if (IsKind($sql, SelectKind)) {
       # Check for BYPASSING BUFFER use ...
       $nb_SelectBypassingBuffer += () = $$stmt =~ /(\bBYPASSING\s+BUFFER\b)/sig ;
   
       my @tables=();

       # FROM clause CHECK
       # ------------------
       my ($FromClause) = $$stmt =~ /\bfrom\b(.*?)$END_FROM_PATTERN/si;
if (defined $FromClause) {   
       my $nb_table = 0;
   
       #if ( $FromClause =~ /\bjoin\b/is ) {
       #  $nb_table = () = $FromClause =~ /(\bjoin\b)/isg;
       #  $nb_table ++;
       #}
       #else {
       #  $nb_table = () = $FromClause =~ /(\b$TAB_PATTERN\s*(?:\bas\s+\w+\b\s*)?)/isg;
       #}
       if ( $FromClause =~ /\bjoin\b/is ) {
	 @tables = split /\bjoin\b/i, $FromClause;

	 for my $t (@tables) {
           $t =~ /[^\w*]($TAB_PATTERN)/is;
	   $t=$1;
         }
         $nb_table = scalar @tables;
       }
       else {

	 while ($FromClause =~ /\b($TAB_PATTERN)\s*(?:\bas\s+\w+\b\s*)?/isg) {
	   push @tables, $1;
           $nb_table ++;
	 }
       }

       if ($nb_table > $NB_MAX_TABLES) {
         $nb_OnToManyTablesQueries++;
       }
   
       if ( $$stmt =~ /\bfor\s+update\b/i ) {
         $nb_SelectForUpdate++;
       }
}

       # COLUMNS CHECK ...
       # ------------------
       my ($type, $columns) = $$stmt =~ /\bselect\s+((?:(?:single|for\s+update|distinct)\b\s+)*)(.*?)$END_COLUMNS_PATTERN/si;

       #Test if filtered :
       my $filters_query = 1;
       for my $t (@tables) {
         if ( $t !~ /\A(?:but100|but000|usr02|t\w+)\b/i ) {
	   # If at lest one tables doesn't match, then don't filters the query...
           $filters_query = 0;
	 }
       }

       if (! $filters_query) {
         my $nb_columns = scalar split '\s+', $columns ;
   
         if (defined $columns) {
	       #  ( $column !~ /(?:\A|,)\s+(?:but100|but000|usr02|t\w+)\b/i) ) {
           if  ($columns =~ /\*/) {
#print "VIOLATION :\n    $$stmt\n";
             $nb_ComplexQueries++;
           }
           else {
             my $nb_columns = scalar split '\s+', $columns ;
             if ( $nb_columns > $NB_MAX_COLUMNS) {
#print "VIOLATION : $$stmt ( $nb_columns columns !!!)\n";
               $nb_ComplexQueries++;
             }
           }
         }
         else {
           print "WARNING : no columns found in select ...in $$stmt\n";
         }
       }
    }

    # Rules for SELECT, DELETE and UPDATE
    # -----------------------------------

    # WHERE clause
    my ($WhereClause) = $$stmt =~ /\bwhere\b(.*?)$END_WHERE_PATTERN/si;

    if ( !defined $WhereClause ) {
      $WhereClause = "";
      $nb_MissingWhereClause++;
    }

    my $nb_isnull =    () =  $WhereClause =~ /(\bis\s+null\b)/ig ;
    my $nb_isnotnull = () =  $WhereClause =~ /(\bis\s+not\s+null\b)/ig ;
    my $nb_not_like =  () =  $WhereClause =~ /(\bnot\s+like\b)/ig ;

    $nb_IsNullInWhereClause += $nb_isnull + $nb_isnotnull;
    $nb_NotOpInWhereClause  += $nb_not_like;
  }

  $ret |= Couples::counter_add($compteurs, $SelectBypassingBuffer__mnemo, $nb_SelectBypassingBuffer );
  $ret |= Couples::counter_add($compteurs, $IsNullInWhereClause__mnemo, $nb_IsNullInWhereClause );
  $ret |= Couples::counter_add($compteurs, $NotOpInWhereClause__mnemo, $nb_NotOpInWhereClause );
  $ret |= Couples::counter_add($compteurs, $MissingWhereClause__mnemo, $nb_MissingWhereClause );
  $ret |= Couples::counter_add($compteurs, $SelectForUpdate__mnemo, $nb_SelectForUpdate );
  $ret |= Couples::counter_add($compteurs, $ComplexQueries__mnemo, $nb_ComplexQueries );
  $ret |= Couples::counter_add($compteurs, $OnToManyTablesQueries__mnemo, $nb_OnToManyTablesQueries );
  $ret |= Couples::counter_add($compteurs, $Select__mnemo, $nb_Select );

  return $ret;
}

sub CountDynamicQueries($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  $nb_DynamicQueries = 0;

  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $DynamicQueries__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @KindList = (SelectKind, InsertKind, DeleteKind, UpdateKind, ModifyKind);

  my @TabInstr = GetNodesByKindList($root, \@KindList, 0); # flag 0 signifies all nodes...

  for my $instr ( @TabInstr ) {

    my $stmt = GetStatement($instr);

    my $_nb_DynamicQueries = () = $$stmt =~ /\b((?:select|from|where|and|insert|update|delete|modify)\s*\($TAB_PATTERN\))/ig;

#    if (  $_nb_DynamicQueries > 0 ) {
#print "($_nb_DynamicQueries) DYNAMIC QUERY = -->$$stmt<--\n";
#    }

    $nb_DynamicQueries += $_nb_DynamicQueries;

  }
  $ret |= Couples::counter_add($compteurs, $DynamicQueries__mnemo, $nb_DynamicQueries );
  return $ret;
}


sub CountNestedSelect($$$) {
    my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

    my $NestedSelect__mnemo = Ident::Alias_NestedSelect();
    my $nb_NestedSelect=0;

    # When state is 1, encountering endselect is normal.
    my $state = 1;
    while ( $vue->{'code'} =~ /\G.*?\b(?:(select)|(endselect))\b/isg ) {
      if (defined $2) {
        if ( $state == 0 ) { # previous was allready a endselect ==> nested select !
          $nb_NestedSelect++;
	}
        $state = 0; # endselect found ...
      }
      elsif (defined $1) {
        $state = 1; # select found ...
      }
    }

#    my $NomVueCode = 'structured_code' ; 
#    my $root =  $vue->{$NomVueCode} ;
#
#    if ( ! defined $root )
#    {
#      $ret |= Couples::counter_add($compteurs, $NestedSelect__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
#      return $ret;
#    }
#
#    my @EndSelects = GetNodesByKind($root, EndSelectKind);
#    for my $endSelect (@EndSelects) {
#
#    my @KindList = (EndSelectKind, SelectKind);
#    my @LoopTab = GetNodesByKindList($root, \@KindList, 1);
#
#    for my $loop (@LoopTab) {
#      if ( (Abap::AbapNode::IsContainingKind($loop, LoopKind)) ||
#           (Abap::AbapNode::IsContainingKind($loop, DoKind)) ||
#           (Abap::AbapNode::IsContainingKind($loop, WhileKind)) ||
#           (Abap::AbapNode::IsContainingKind($loop, ProvideKind)) ) {
#        $nb_NestedSelect++;
#      }
#    }

    $ret |= Couples::counter_add($compteurs, $NestedSelect__mnemo, $nb_NestedSelect );
}

sub CountStandardTableModifications($$$) {
    my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

    my $StandardTableModifications__mnemo = Ident::Alias_StandardTableModifications();
    my $nb_StandardTableModifications=0;

    my $NomVueCode = 'structured_code' ; 
    my $root =  $vue->{$NomVueCode} ;
	my $code = $vue->{'code'};

    if ( ! defined $root or ! defined $code )
    {
      $ret |= Couples::counter_add($compteurs, $StandardTableModifications__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
      return $ret;
    }

    if ( ( !defined SourceUnit::get_UnitInfo($fichier, 'PROGRAM_STATUS') ) ||
         ( ( defined SourceUnit::get_UnitInfo($fichier, 'PROGRAM_STATUS') ) &&
	   ( SourceUnit::get_UnitInfo($fichier, 'PROGRAM_STATUS') eq "CUSTOM" ) ) ) {

		my @KindList = (InsertKind, DeleteKind, UpdateKind, ModifyKind);
		my @InstrTab = GetNodesByKindList($root, \@KindList, 1); # flag 1 signifies we want only the first loop encountered on each path ...
		for my $instr (@InstrTab) {
			my  $ModifiedTable = undef;
			if (IsKind($instr, InsertKind)) {
				if ( ${GetStatement($instr)} =~/insert\s+(?:INTO\s+($TAB_PATTERN)|($TAB_PATTERN)\s+(?:CLIENT\s+SPECIFIED|USING\s+CLIENT\s+\'.*\')?\s*FROM)/i ) {
					$ModifiedTable = $1;
					# print "TABLE :  $ModifiedTable\n";
				}
				else {
					my $instrSQL = ${GetStatement($instr)};
					$instrSQL =~ s/\n//g;
					$instrSQL =~ s/^\s+//g;
					# print "WARNING : insert instruction not complying with open SQL: <".$instrSQL.">\n";
				}
			}
			elsif (IsKind($instr, UpdateKind)) {
				if ( ${GetStatement($instr)} =~/update\s+($TAB_PATTERN)\s+(?:FROM|SET)/i ) {
					$ModifiedTable = $1;
					# print "TABLE :  $ModifiedTable\n";
				}
				else {
					my $instrSQL = ${GetStatement($instr)};
					$instrSQL =~ s/\n//g;
					$instrSQL =~ s/^\s+//g;
					# print "WARNING : update instruction not complying with open SQL: <".$instrSQL.">\n";
				}
			}
			elsif (IsKind($instr, ModifyKind)) {
				if ( ${GetStatement($instr)} =~/modify\s+($TAB_PATTERN)\s+(?:FROM|USING|CLIENT)/i ) {
					$ModifiedTable = $1;
					# print "TABLE :  $ModifiedTable\n";
				}
				else {
					my $instrSQL = ${GetStatement($instr)};
					$instrSQL =~ s/\n//g;
					$instrSQL =~ s/^\s+//g;
					# print "WARNING : modify instruction not complying with open SQL: <".$instrSQL.">\n";
				}
			}
			elsif (IsKind($instr, DeleteKind)) {
				my $stmt = ${GetStatement($instr)};
				if ( $stmt =~/delete\s+($TAB_PATTERN)?\s*FROM\s+($TAB_PATTERN)?/i ) {
					if (defined $1)
					{
						$ModifiedTable = $1;
					}
					elsif (defined $2)
					{
						$ModifiedTable = $2;
					}
				}
				else {
					my $instrSQL = ${GetStatement($instr)};
					$instrSQL =~ s/\n//g;
					$instrSQL =~ s/^\s+//g;
					# print "WARNING : delete instruction not complying with open SQL: <".$instrSQL.">\n";
				}
			}

			if (defined $ModifiedTable) {
				if  ($ModifiedTable !~ /\A[YZ\/]/i) {
					$nb_StandardTableModifications++;
					# print "VIOLATION = $ModifiedTable\n";
				}
			}
		}   
	}

    $ret |= Couples::counter_add($compteurs, $StandardTableModifications__mnemo, $nb_StandardTableModifications );
}



#sub CountSubqueries($$$) {
#  my ($fichier, $vue, $compteurs) = @_ ;
#
#  $nb_SubQueries = 0;
#
#  my $ret = 0;
#
#  my $NomVueCode = 'structured_code' ; 
#  my $root =  $vue->{$NomVueCode} ;
#
#  if ( ! defined $root )
#  {
#    $ret |= Couples::counter_add($compteurs, $SubQueries__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
#    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
#  }
#
#  $nb_SubQueries = () = GetNodesByKind($root, SubqueryKind);
# 
#  $ret |= Couples::counter_add($compteurs, $SubQueries__mnemo, $nb_SubQueries );
#}

1;



