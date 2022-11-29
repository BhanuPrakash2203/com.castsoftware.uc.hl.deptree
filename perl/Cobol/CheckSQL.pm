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
#
# Description: Composant de comptages sur code source COBOL

package Cobol::CheckSQL;

use Cobol::violation;


my $TestSQL = 0;
my $TestSQLLine = 0;
my $dansSQL = 0;
my $ClauseWhere = 0;
my $NbAndOrSQL = 0;

#Dans SQL
# Seuil compléxité clause where de select
my $S_Where_Cplx = 4;

my $filename = "";
my $StructFichier;


#Compteur
my $cptSQLDeclareTable = 0;
my $cptSQLComplexWhereClause = 0;
my $cptSQLDistinctOrder = 0;
my $cptSQLSelectStar = 0;
my $cptSQLGroupby = 0;
my $cptSQLOrderBy = 0;
my $cptSQLMissingTest = 0;

sub initCheckSQL  ($$)
{
    ($StructFichier,$filename)=(@_);

   $TestSQL = 0;
   $TestSQLLine = 0;
   $dansSQL = 0;
   $ClauseWhere = 0;
   $NbAndOrSQL = 0;

#Compteur
   $cptSQLDeclareTable = 0;
   $cptSQLComplexWhereClause = 0;
   $cptSQLDistinctOrder = 0;
   $cptSQLSelectStar = 0;
   $cptSQLGroupby = 0;
   $cptSQLOrderBy = 0;
   $cptSQLMissingTest = 0;
}

sub CheckSQL($$$) {
	# One line of ProcDiv
        my $line = shift;
	my $CptLine=shift;
	my $NewPara=shift;

##############################################################################
# il faut oublier le SQL
#
# Attention FLO, il va faloir trier les EXEC SQL ET CICS pour le traitement d'erreur
	    if ($line =~ m{\A\s+EXEC\s+SQL.*\.}i){

#		print "$filename:$CptLine:SQLFLOFLO  " . $line;
                $TestSQL = 1;
		if ($TestSQL == 1) {$TestSQLLine = $CptLine; }
#		TraitementPoint();
                return;
	    }
	    if ($line =~ m{\A\s+EXEC\s+CICS.*\.}i){
#                $Pd_NB_LigneSQL++;
#		print $line;
#                $TestSQL = 1;
#		TraitementPoint();
                return;
	    }
	    if ($line =~ m{\A\s+EXEC\s+SQL}i){

#		print "$filename:$CptLine:SQLFLOFLO  CAS 2" . $line;
		$dansSQL = 1;
                $TestSQL = 1;
	        if ($line =~ m{\A\s+EXEC\s+SQL\s+DECLARE\s+.*\s+TABLE\b}i){
			# @Code: NO_DECLARE_TABLE
			# @Type: SQL
			# @Description: Pas de declare table SQL dans les programmes
			# @Caractéristiques: 
			# @Commentaires: 
			# @RULENUMBER: Rxxx
			Cobol::violation::violation2("SQL_NO_DECLARE_TABLE", $filename,$CptLine,"Violation, Pas de DECLARE TABLE SQL dans les programmes");
			$cptSQLDeclareTable++;
		}          
                return;
	    }
	    if (($line =~ m{\A\s+END-EXEC\.}i) || ($line =~ m{\S\s*\bEND-EXEC\s*\.}i)) {
#SI QUELQUECHOSE DEVANT END-EXEC 

		$dansSQL = 0;
#		print "$filename:$CptLine:SQLFLOFLO JE SORT  CAS 1" . $line;
		if ($ClauseWhere == 1) {
		    if ( $NbAndOrSQL > $S_Where_Cplx) {
			# @Code: SQL_SELECT_CPLX
			# @Type: SQL
			# @Description: Compléxité d'une clause WHERE d'un SELECT d'une opération SQL"
			# @Caractéristiques: 
			# @Commentaires: 
			# @RULENUMBER: Rxxx
			Cobol::violation::violation2("SQL_CPLX_WHERE", $filename,$CptLine,"Violation, clause WHERE d'un Ordre SQL complexe,  superieur a $S_Where_Cplx opérateurs logiques ($NbAndOrSQL)");
			$cptSQLComplexWhereClause++;
		    } 
		}
                $ClauseWhere = 0;
		$NbAndOrSQL = 0;
#                $line =~ s{.*}{\.};
#                TraitementPoint();

		if ($TestSQL == 1) {$TestSQLLine = $CptLine; }
                return;
	    }  
	    if (($line =~ m{\A\s+END-EXEC\b}i) || ($line =~ m{\S\s*\bEND-EXEC\b}i)){

		$dansSQL = 0;
#		print "$filename:$CptLine:SQLFLOFLO JE SORT  CAS 2" . $line;
		if ($ClauseWhere == 1) {
		    if ( $NbAndOrSQL > $S_Where_Cplx) {
			# @Code: SQL_SELECT_CPLX
			# @Type: SQL
			# @Description: Compléxité d'une clause WHERE d'un SELECT d'une opération SQL"
			# @Caractéristiques: 
			# @Commentaires: 
			# @RULENUMBER: Rxxx

			Cobol::violation::violation2("SQL_CPLX_WHERE", $filename,$CptLine,"Violation, clause WHERE d'un Ordre SQL complexe,  superieur a $S_Where_Cplx opérateurs logiques ($NbAndOrSQL)");
			$cptSQLComplexWhereClause++;
		    } 
		}
                $ClauseWhere = 0;
		$NbAndOrSQL = 0;
		if ($TestSQL == 1) {$TestSQLLine = $CptLine; }
                return;
	    }

            if ($dansSQL == 1) {
#########################
# Nous sommes dans du SQL
#########################

	        if ($line =~ m{\bDECLARE\s+.*\s+TABLE\b}i){
			# @Code: NO_DECLARE_TABLE
			# @Type: SQL
			# @Description: Pas de declare table SQL dans les programmes
			# @Caractéristiques: 
			# @Commentaires: 
			# @RULENUMBER: Rxxx
			Cobol::violation::violation2("SQL_NO_DECLARE_TABLE", $filename,$CptLine,"Violation, Pas de DECLARE TABLE SQL dans les programmes");
			$cptSQLDeclareTable++;
		} 
		if ($line =~ m{(\sDISTINCT\s)}i) {
		    # @Code: SQL_ORDRE_DISTINCT
		    # @Type: SQL
		    # @Description: Pas d'ordre DISTINCT dans une opération SELECT SQL"
		    # @Caractéristiques: 
		    # @Commentaires: 
		    # @RULENUMBER: Rxxx
		    Cobol::violation::violation2("SQL_DISTINCT",$filename,$CptLine,"Violation, Pas d'ordre DISTINCT dans une opération SELECT SQL" );
		    $cptSQLDistinctOrder++;
		}
		if ($line =~ m{(\sSELECT\s+\*)}i) {
		    # @Code: SQL_SELECT_STAR
		    # @Type: SQL
		    # @Description: Pas d'ordre SELECT * dans une opération SQL"
		    # @Caractéristiques: 
		    # @Commentaires: 
		    # @RULENUMBER: Rxxx
		    Cobol::violation::violation2("SQL_SELECT_STAR",$filename,$CptLine,"Violation, Pas d'ordre SELECT * dans une opération SQL" );
		    $cptSQLSelectStar++;
		}
		if ($line =~ m{(\sGROUP\s+BY\b)}i) {
		    # @Code: SQL_GROUP_BY
		    # @Type: SQL
		    # @Description: Pas d'ordre SELECT * dans une opération SQL"
		    # @Caractéristiques: 
		    # @Commentaires: 
		    # @RULENUMBER: Rxxx
		    Cobol::violation::violation2("SQL_GROUP_BY",$filename,$CptLine,"Violation, Pas d'ordre GROUP BY dans une opération SQL" );
		    $cptSQLGroupby++;
		}
		if ($line =~ m{(\sORDER\s+BY\b)}i) {
		    # @Code: SQL_ORDER_BY
		    # @Type: SQL
		    # @Description: Pas d'ordre SELECT * dans une opération SQL"
		    # @Caractéristiques: 
		    # @Commentaires: 
		    # @RULENUMBER: Rxxx
		    Cobol::violation::violation2("SQL_ORDER_BY",$filename,$CptLine,"Violation, Pas d'ordre ORDER BY dans une opération SQL" );
		    $cptSQLOrderBy++;
		}
		if ($line =~ m{(\sWHERE\s)}i) {
                    $ClauseWhere = 1;
		}
                if ($ClauseWhere == 1) {
		    my $match = $line;
                    $match =~ s{\bAND\b}{@}g;
                    $match =~ s{\bOR\b}{@}g;
                    my $nbAndOr = $match =~ tr{@}{@};
                    $NbAndOrSQL = $NbAndOrSQL + $nbAndOr;
#TRACE                   print " NB AND " . $nbAndOr . "   " . $NbAndOrSQL . " $CptLine\n";
		}
		return;
	    }

            if ($TestSQL == 1) {
#		print "$filename:$CptLine:DansTestSQLFLOFLO  entree\n" ;
#                if (! m{\.}) {
		    $TestSQL = 0;
#		print "$filename:$CptLine:DansTestSQLFLOFLO  point 2" . $line;
                if ($line =~ m{\s+(IF|EVALUATE)\s+SQLCODE}i) {
		    # il y a un if, on peut penser que c'est un test pour le SQL
#                    print $line;
#		print "$filename:$CptLine:DansTestSQLFLOFLO  point 3" . $line;
		} else {
#                    print "FLOFLO :" . $line . "FLOFLO : LA LIGNE $CptLine\n";
		    # il n'y a pas if
		    # @Code: SQL_STATUS
		    # @Type: ALGO
		    # @Description: Pas de traitement immédiat du code retour après une opération SQL"
		    # @Caractéristiques: 
		    #   - Tolérance aux fautes
		    # @Commentaires: 
		    # @Restriction: Vérification manuelle après!!!
		    # @RULENUMBER: R29
                    Cobol::violation::violation2("SQL_STATUS",$filename,$TestSQLLine,"Violation, Pas de traitement immédiat du code retour après une opération SQL:$line" );
		    $cptSQLMissingTest++;
		}
#		}
	    }

#########################
#il y a un . sur la ligne
#########################
	    if ($line =~ m{\.\s*\Z}i) {

	    }

    } # fin boucle ligne

sub endCheckSQL() {

    #Ecriture des compteurs
    Couples::counter_add($StructFichier,Ident::Alias_SQLDeclareTable(),$cptSQLDeclareTable);
    Couples::counter_add($StructFichier,Ident::Alias_SQLComplexWhereClause(),$cptSQLComplexWhereClause);
    Couples::counter_add($StructFichier,Ident::Alias_SQLDistinctOrder(),$cptSQLDistinctOrder);
    Couples::counter_add($StructFichier,Ident::Alias_SQLSelectStar(),$cptSQLSelectStar);
    Couples::counter_add($StructFichier,Ident::Alias_SQLGroupby(),$cptSQLGroupby);
    Couples::counter_add($StructFichier,Ident::Alias_SQLOrderBy(),$cptSQLOrderBy);
    Couples::counter_add($StructFichier,Ident::Alias_SQLMissingTest(),$cptSQLMissingTest);	
    reinitSQL();
	
}

sub reinitSQL {
 $TestSQL = 0;
 $TestSQLLine = 0;
 $dansSQL = 0;
 $ClauseWhere = 0;
 $NbAndOrSQL = 0;

#Compteur
 $cptSQLDeclareTable = 0;
 $cptSQLComplexWhereClause = 0;
 $cptSQLDistinctOrder = 0;
 $cptSQLSelectStar = 0;
 $cptSQLGroupby = 0;
 $cptSQLOrderBy = 0;
 $cptSQLMissingTest = 0;
}

1;
