#!/usr/bin/perl -w
#----------------------------------------------------------------------#
#                         @ISOSCOPE 2008                               #
#----------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                  #
#               Adresse : TERSUD - Bat A                               #
#                         5, AVENUE MARCEL DASSAULT                    #
#                         31500  TOULOUSE                              #
#               SIRET   : 410 630 164 00037                            #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#
#
# Description: Outil de comptages Korn shell (programme principal)
#

use strict;
use warnings ;

my $VERSION = 'version interne';

BEGIN
{
    my $rep = $0;
    $rep =~ s{(.*)\/[^\/]+}{$1};
    push @INC, $rep;
}

use SourceLoader;
use Options;
use Couples;
use AnaPlSql;
use IsoscopeDataFile;

my @table_comptages = (
 # Keywords
  #["ID","Mnémonique","Idée","BP","CS","C","L","AD"],
  ["K2",Ident::Alias_Sql_Alter(),"Compter le nombre d'occurences du mot clé ALTER",,,,,],
  ["K3",Ident::Alias_Basex_And(),"Compter le nombre d'occurences du mot clé AND",,,,,],
  ["K13",Ident::Alias_Type_Binary_Integer(),"Compter le nombre d'occurences du mot clé BINARY_INTEGER","BP",,,,],
  ["K15",Ident::Alias_Type_Boolean(),"Compter le nombre d'occurences du mot clé BOOLEAN",,,,,],
  ["K19",Ident::Alias_Type_Char(),"Compter le nombre d'occurences du mot clé CHAR",,,,,],
  ["K20",Ident::Alias_Type_Char_Base(),"Compter le nombre d'occurences du mot clé CHAR_BASE",,,,,],
  ["K22",Ident::Alias_Sql_Close(),"Compter le nombre d'occurences du mot clé CLOSE",,,,,],
  ["K27",Ident::Alias_Sql_Commit(),"Compter le nombre d'occurences du mot clé COMMIT",,,,,],
  ["K29",Ident::Alias_Sql_Connect(),"Compter le nombre d'occurences du mot clé CONNECT",,,,,],
  ["K31",Ident::Alias_Sql_Create(),"Compter le nombre d'occurences du mot clé CREATE",,,,,],
  ["K34",Ident::Alias_Sql_Cursor(),"Compter le nombre d'occurences du mot clé CURSOR",,,,,],
  ["K37",Ident::Alias_Sql_Declare(),"Compter le nombre d'occurences du mot clé DECLARE",,,,,],
  ["K40",Ident::Alias_Sql_Delete(),"Compter le nombre d'occurences du mot clé DELETE",,,,,],
  ["K43",Ident::Alias_Base_Do(),"Compter le nombre d'occurences du mot clé DO",,,,,],
  ["K44",Ident::Alias_Sql_Drop(),"Compter le nombre d'occurences du mot clé DROP",,,,,],
  ["K45",Ident::Alias_Base_Else(),"Compter le nombre d'occurences du mot clé ELSE",,,,,],
  ["K46",Ident::Alias_Base_Elsif(),"Compter le nombre d'occurences du mot clé ELSIF",,,,,],
  ["K48",Ident::Alias_Base_Exception(),"Compter le nombre d'occurences du mot clé EXCEPTION",,,,,],
  ["K50",Ident::Alias_Sql_Execute(),"Compter le nombre d'occurences du mot clé EXECUTE",,,,,],
  ["K52",Ident::Alias_Base_Exit(),"Compter le nombre d'occurences du mot clé EXIT",,,,,],
  ["K56",Ident::Alias_Sql_Fetch(),"Compter le nombre d'occurences du mot clé FETCH",,,,,],
  ["K57",Ident::Alias_Type_Float(),"Compter le nombre d'occurences du mot clé FLOAT",,,,,],
  ["K58",Ident::Alias_Base_For(),"Compter le nombre d'occurences du mot clé FOR",,,,,],
  ["K59",Ident::Alias_Base_Forall(),"Compter le nombre d'occurences du mot clé FORALL",,,,,],
  ["K61",Ident::Alias_Basex_Function(),"Compter le nombre d'occurences du mot clé FUNCTION",,,,,],
  ["K62",Ident::Alias_Base_Goto(),"Compter le nombre d'occurences du mot clé GOTO",,,"C",,],
  ["K67",Ident::Alias_Base_If(),"Compter le nombre d'occurences du mot clé IF",,,,,],
  ["K72",Ident::Alias_Sql_Insert(),"Compter le nombre d'occurences du mot clé INSERT",,,,,],
  ["K73",Ident::Alias_Type_Integer(),"Compter le nombre d'occurences du mot clé INTEGER","BP",,,,],
  ["K85",Ident::Alias_Type_Long(),"Compter le nombre d'occurences du mot clé LONG",,,,,],
  ["K86",Ident::Alias_Base_Loop(),"Compter le nombre d'occurences du mot clé LOOP",,,,,],
  ["K95",Ident::Alias_Type_Natural(),"Compter le nombre d'occurences du mot clé NATURAL","BP",,,,],
  ["K96",Ident::Alias_Type_Naturaln(),"Compter le nombre d'occurences du mot clé NATURALN","BP",,,,],
  ["K104",Ident::Alias_Type_Number(),"Compter le nombre d'occurences du mot clé NUMBER","BP",,,,],
  ["K110",Ident::Alias_Sql_Open(),"Compter le nombre d'occurences du mot clé OPEN",,,,,],
  ["K113",Ident::Alias_Basex_Or(),"Compter le nombre d'occurences du mot clé OR",,,,,],
  ["K116",Ident::Alias_Base_Others(),"Compter le nombre d'occurences du mot clé OTHERS",,,,,],
  ["K118",Ident::Alias_Basex_Package(),"Compter le nombre d'occurences du mot clé PACKAGE",,,,,],
  ["K121",Ident::Alias_Type_Pls_Integer(),"Compter le nombre d'occurences du mot clé PLS_INTEGER",,,,,],
  ["K122",Ident::Alias_Type_Positive(),"Compter le nombre d'occurences du mot clé POSITIVE","BP",,,,],
  ["K123",Ident::Alias_Type_Positiven(),"Compter le nombre d'occurences du mot clé POSITIVEN","BP",,,,],
  ["K126",Ident::Alias_Basex_Private(),"Compter le nombre d'occurences du mot clé PRIVATE",,,,,],
  ["K127",Ident::Alias_Basex_Procedure(),"Compter le nombre d'occurences du mot clé PROCEDURE",,,,,],
  ["K128",Ident::Alias_Basex_Public(),"Compter le nombre d'occurences du mot clé PUBLIC",,,,,],
  ["K129",Ident::Alias_Base_Raise(),"Compter le nombre d'occurences du mot clé RAISE",,,,,],
  ["K132",Ident::Alias_Type_Real(),"Compter le nombre d'occurences du mot clé REAL",,,,,],
  ["K136",Ident::Alias_Base_Return(),"Compter le nombre d'occurences du mot clé RETURN",,,,,],
  ["K138",Ident::Alias_Sql_Rollback(),"Compter le nombre d'occurences du mot clé ROLLBACK",,,,,],
  ["K139",Ident::Alias_Type_Row(),"Compter le nombre d'occurences du mot clé ROW",,,,,],
  ["K140",Ident::Alias_Type_Rowid(),"Compter le nombre d'occurences du mot clé ROWID",,,,,],
  ["K145",Ident::Alias_Sql_Select(),"Compter le nombre d'occurences du mot clé SELECT",,,,,],
  ["K149",Ident::Alias_Type_Smallint(),"Compter le nombre d'occurences du mot clé SMALLINT",,,,,],
  ["K156",Ident::Alias_Basex_Subtype(),"Compter le nombre d'occurences du mot clé SUBTYPE",,,,,],
  ["K162",Ident::Alias_Basex_Then(),"Compter le nombre d'occurences du mot clé THEN",,,,,],
  ["K170",Ident::Alias_Sql_Trigger(),"Compter le nombre d'occurences du mot clé TRIGGER",,,,,],
  ["K176",Ident::Alias_Sql_Update(),"Compter le nombre d'occurences du mot clé UPDATE",,,,,],
  ["K181",Ident::Alias_Type_Varchar(),"Compter le nombre d'occurences du mot clé VARCHAR",,,,,],
  ["K182",Ident::Alias_Type_Varchar2(),"Compter le nombre d'occurences du mot clé VARCHAR2",,,,,],
  ["K188",Ident::Alias_Base_While(),"Compter le nombre d'occurences du mot clé WHILE",,,,,],
  ["K194",Ident::Alias_Type_Clob(),"Compter le nombre d'occurences du mot clé CLOB",,,,,],
  ["K195",Ident::Alias_Type_Lob(),"Compter le nombre d'occurences du mot clé LOB",,,,,],
  ["P20",Ident::Alias_Base_Exception_Init(),"Compter le nombre d'occurrences du mot clé EXCEPTION_INIT",,,,"L",],
  ["P40",Ident::Alias_Base_Decode(),"Compter le nombre d'occurrences du mot clé decode.",,,,"L",],
 # Generiques
  #["ID","Mnémonique","Idée","BP","CS","C","L","AD"],
  ["G2",Ident::Alias_AndOr(),"Nombre de AND et de OR présents dans des conditions du PL/SQL.",,,"C",,],
  ["G21",Ident::Alias_CaseWhen(),"Nombre de WHEN entre CASE et END CASE",,,"C",,],
  ["G22",Ident::Alias_ExceptionWhen(),"Nombre de WHEN après EXCEPTION",,,"C",,],
  ["G28",Ident::Alias_AlphaNumCommentLines(),"Nombre de lignes de commentaires contenant des caractères alphanumériques ",,,,,],
  ["G29",Ident::Alias_CommentedOutCode(),"Nombre de lignes de code en commentaire",,,,,"AD"],
  ["G30",Ident::Alias_CommentLines(),"Nombre de lignes de commentaires",,,,,"AD"],
  ["G31",Ident::Alias_CommentBlocs(),"Nombre de blocs de commentaire",,,,,"AD"],
  ["G32",Ident::Alias_ComplexConditions(),"Nombre de conditions de plus de 4 opérandes qui mélangent les opérateurs OR et AND",,,"C",,],
  ["G39",Ident::Alias_WhenOthers(),"Nombre de cas When others",,,"C",,],
  ["G42",Ident::Alias_DistinctWords(),"Nombre de mots distincts Attention aux chaînes et aux couples () [] …",,,"C",,],
  ["G53",Ident::Alias_FileGlobalVariables(),"Nombre de de variables globales à un package",,,,,],
  ["G66a","Nbr_FunctionDeclarations ","Nombre de déclarations de fonctions.",,,,,"AD"],
  ["G66b",Ident::Alias_ProcedureDeclarations(),"Nombre de déclarations de procdédures.",,,,,"AD"],
  ["G67a",Ident::Alias_FunctionImplementations(),"Nombre d'implémentation de fonctions.",,,,,],
  ["G67b",Ident::Alias_ProcedureImplementations(),"Nombre d'implémentation de procédures.",,,"C",,"AD"],
  ["G90a","Nbr_Lines","Nombre de lignes",,,"C","L","AD"],
  ["G90b",Ident::Alias_LinesInSpec(),"Nombre de lignes des blocs CREATE OR REPLACE PACKAGE (non BODY)",,,"C","L","AD"],
  ["G90c",Ident::Alias_LinesInBody(),"Nombre de lignes des blocs CREATE OR REPLACE PACKAGE BODY",,,"C","L","AD"],
  ["G91a",Ident::Alias_LinesOfCode(),"Nombre de lignes de code",,,"C","L","AD"],
  ["G91b",Ident::Alias_LinesOfCodeInSpec(),"Nombre de lignes de code des blocs CREATE OR REPLACE PACKAGE (non BODY)",,,"C","L","AD"],
  ["G91c",Ident::Alias_LinesOfCodeInBody(),"Nombre de lignes de code des blocs CREATE OR REPLACE PACKAGE BODY",,,"C","L","AD"],
  ["G93",Ident::Alias_LocalVariables(),"Nombre de variables locales.",,,"C",,],
  ["G95",Ident::Alias_LongLines100(),"Nombre de lignes de plus de 100 caractères",,,,"L",],
  ["G96",Ident::Alias_LongLines132(),"Nombre de lignes de plus de 132 caractères",,,,"L",],
  ["G97",Ident::Alias_LongLines80(),"Nombre de lignes de plus de 80 caractères",,,,"L",],
  ["G101",Ident::Alias_MagicNumbers(),"Nombre de littéraux numérique hors déclarations de constantes.","BP",,,,],
  ["G109",Ident::Alias_MissingWhenOthers(),"Nombre de blocs Case ne contenant pas de cas When others ","BP",,,,],
  ["G115",Ident::Alias_MultipleInstructions(),"Nombre de ligne contenant plusieurs instructions sur cette même ligne, si cela a du sens.",,,,"L",],
  ["G138",Ident::Alias_RiskyCatches(),"??? WHEN ne contenant que NULL?","BP",,,,],
  ["G154",Ident::Alias_SqlLines(),"Nombre de lignes non vides (sql?)",,,,,],
  ["G158",Ident::Alias_SuspiciousComments(),"Nombre de lignes de commentaires suspects",,,,,"AD"],
  ["G160",Ident::Alias_Case(),"Nombre de blocs CASE",,,,,],
  ["G174",Ident::Alias_Words(),"Nombre de mots Attention aux chaînes et aux couples () [] …",,,"C",,],
 # PlSql
  #["ID","Mnémonique","Idée","BP","CS","C","L","AD"],
  ["P6",Ident::Alias_NcharVariable(),"Compter le nombre de variables de type NCHAR","BP",,,,],
  ["P9",Ident::Alias_Nvarchar2Variable(),"Compter le nombre de variables de type NVARCHAR2","BP",,,,],
  ["P10",Ident::Alias_WithoutPrecision_CharVariable(),"Compter le nombre de variables de type CHAR sans précision","BP",,,,],
  ["P11",Ident::Alias_WithoutPrecision_NcharVariable(),"Compter le nombre de variables de type NCHAR sans précision","BP",,,,],
  ["P12",Ident::Alias_WithoutPrecision_VarcharVariable(),"Compter le nombre de variables de type VARCHAR sans précision","BP",,,,],
  ["P13",Ident::Alias_WithoutPrecision_Varchar2Variable(),"Compter le nombre de variables de type VARCHAR2 sans précision","BP",,,,],
  ["P14",Ident::Alias_WithoutPrecision_Nvarchar2Variable(),"Compter le nombre de variables de type NVARCHAR2 sans précision","BP",,,,],
  ["P15",Ident::Alias_CompareToNull(),"Dans les conditions, compter les séquences = NULL et «différent de» NULL",,"CS",,,],
  ["P16",Ident::Alias_CompareToEmptyString(),"Dans les conditions, compter les séquences = '' et «différent de» ''",,"CS",,,],
  ["P18",Ident::Alias_NotNullVariables(),"Compter les «NOT NULL» présents dans les déclarations de variables de procédures.","BP",,,,],
  ["P26","Nbr_LessThanFourCharacters_Identifiers","Compter le nombre d'identificateurs dont la longueur est de moins de 4 caractères, notamment pour les packages, variables globales et fonctions/procédures.",,,,"L",],
  ["P29",Ident::Alias_WithExit_ConditionalLoops(),"Compter les boucles FOR/WHILE, contenant des EXIT WHILE.","BP",,,,],
  ["P31",Ident::Alias_Dbms_Sql_Parse(),"Compter les appels à DBMS_SQL.PARSE","BP",,"C",,],
  ["P32",Ident::Alias_Dbms_Sql_Open(),"Compter les appels à DBMS_SQL.OPEN","BP",,"C",,],
  ["P34","Nbr_WithOutOrInOutParameters_Function","Compter les fonctions contenant des paramètres OUT ou IN OUT.",,"CS",,,],
  ["P35","Nbr_OutsideBody_GlobalVariables","Compter les variables globales définies en dehors des blocs BODY.",,,,,],
  ["P36","Nbr_WithoutInOutDeclaredParameters_Declarations","Compter les fonctions (et procédures?) dont certains paramètres ne sont marqués explicitement ni IN, ni OUT, ni IN OUT.",,,,"L",],
  ["P37",Ident::Alias_WithoutParameter_Procedures(),"Compter les procédures sans paramètre","BP",,,,],
  ["P38",Ident::Alias_IllegalException(),"Compter les exceptions homonymes des exceptions des packages STANDARD et DBMS_STANDARD.",,"CS",,,],
  ["P39","Nbr_WithoutSemiColumn_EndLoop","Compter les instructions END [LOOP] qui ne sont pas suivies d'un point virgule sur la même ligne, après l'éventuel label.",,"CS",,,],
  ["P41","Nbr_WithoutLabel_EndLoop","Compter le nombre d'occurrences de END [LOOP] non suivi d'un label.",,,,"L",],
  ["P42",Ident::Alias_WithSeveralExit_Loop(),"Compter les boucles contenant plus d'un EXIT.",,,"C",,],
  ["P51",Ident::Alias_SignType(),"Compter le nombre d'occurrences du mot clé SIGNTYPE","BP",,,,],
 # générique éventuels
  #["ID","Mnémonique","Idée","BP","CS","C","L","AD"],
  ["G12",Ident::Alias_BadMethodNames(),,,,,"L",],
  ["G16",Ident::Alias_BlankLines(),,,,,,],
  ["G87","Nbr_KeywordBadCase","idem nsdk",,,,"L",],
  ["G88",Ident::Alias_Keywords(),,,,,"L",],
  ["G149",Ident::Alias_ShortGlobalNamesLT(),"a faire sur ces objets : Compter la longueur des identificateurs de packages, variables globales et fonctions/procédures",,,,,"AD"],
  ["G151a",Ident::Alias_ShortFunctionNamesLT(),,,,,,"AD"],
  ["G151b","Nbr_ShortProcedureNamesLT","on sépare fonctions et procédures",,,,,"AD"],
 # PlSql éventuels
  #["ID","Mnémonique","Idée","BP","CS","C","L","AD"],
  ["P19","Nbr_withSqlCode_WhenOthers","Compter les token «SQLCODE», présents dans des blocs «WHEN OTHERS»","BP",,,"L",],
  ["P23",Ident::Alias_MagicString(),"Compter les littéraux chaîne, sauf dans les instructions «CONSTANT».",,,,"L",],
  ["P27",Ident::Alias_WithoutFinalReturn_Functions(),"Compter les fonctions (bloc FUNCTION) dont la dernière instruction n'est pas RETURN.",,,"C",,],
  ["P30",Ident::Alias_WithReturnOutsideExceptionHandler_Procedure(),"Compter les procédures contenant le mot clé RETURN en dehors d'un handler d'exception.","BP",,,,],
  ["P33",Ident::Alias_WithReturnOutsideExceptionHandler_Function(),"Compter les fonctions (bloc FUNCTION) dont une instruction RETURN est présente en dehors d'un handler d'exception et de la fin de fonction.","BP",,,,],
  ["P43",Ident::Alias_CaseLike_Else(),"Compter les ELSIF (ou ELSE IF) avec condition numérique sur variable.","BP",,,,],
);




# liste ordonnee des comptages a calculer et afficher dans le fichier de sortie
my @CompteursPlSql = (
    "Dat_Language",
    "Dat_AnalysisDate",
    "Dat_AnalysisStatus",

    #Ident::Alias_Words(),
    #Ident::Alias_DistinctWords(),
    #"Nbr_PlSqlFirstLine",
    #"Nbr_CommentBlocks",
    #Ident::Alias_CommentedOutCode(),
    #Ident::Alias_SuspiciousComments(),
    #Ident::Alias_HeterogeneousEncoding(),
    #Ident::Alias_IndentedLines(),
    #Ident::Alias_LinesOfCode(),
    #"Nbr_NotPurePlSql",
    #"Nbr_ContinuationChar",
    #Ident::Alias_ModifiedIFS(),
    #Ident::Alias_Getopt(),
    #Ident::Alias_CheckedArgs(),
    #Ident::Alias_WellDeclaredVariables(),
    #Ident::Alias_VariableDeclarations(),
    #Ident::Alias_WellNamedExportedVariables(),
    #Ident::Alias_ExportedVariables(),
    #Ident::Alias_WellNamedLocalVariables(),
    #Ident::Alias_ShortVarName(),
    #Ident::Alias_LocalVariables(),
    #Ident::Alias_Pipes(),
    #Ident::Alias_MaxChainedPipes(),
    #Ident::Alias_Background(),
    #Ident::Alias_Alias(),
    #Ident::Alias_FunctionMethodImplementations(),
    #Ident::Alias_Then(),
    #Ident::Alias_Do(),
    #Ident::Alias_Case(),
    #Ident::Alias_Switch(),
    #Ident::Alias_Default(),
    #Ident::Alias_SuspiciousLastCase(),
    #Ident::Alias_Exit(),
    #Ident::Alias_WithoutValueExit(),
    #Ident::Alias_WithoutFinalExit(),
    #Ident::Alias_Break(),
    #Ident::Alias_Continue(),
    #Ident::Alias_MultipleStatementsOnSameLine(),
    #Ident::Alias_BadTmpName()
);

sub _setAllKnownMnemonics ()
{
  for my $ligne ( @table_comptages )
  {
    push @CompteursPlSql, $ligne->[1] ;
  }
}


# Affichage d'une aide sommaire
sub usage ()
{
    print STDERR "\n" ;
    print STDERR "Usage:\n" ;
    print STDERR ' perl -S count_ksh.pl --o=<fichier_resultat> <nom_fichier_source> ...  ' . "\n" ;
    print STDERR "ou\n";
    print STDERR ' perl -S count_ksh.pl --o=<fichier_resultat> --file-list=<fichier_liste_des_sources>' . "\n" ;
    print STDERR 'exemple:' . "\n" ;
    print STDERR ' perl -S count_ksh.pl --o=cpt_appli.csv $(find appli/ -name "*.ksh")  ; echo $?' . "\n" ;
    print STDERR 'exemple:' . "\n" ;
    print STDERR ' perl -S count_ksh.pl --o=cpt_appli.csv --file-list=appli_src.lst  ; echo $?' . "\n" ;

    print STDERR "    \n" ;
    exit -1;
}


# Point d'entree, traitement de la ligne de commande
sub main()
{
    my $status = 0; # l'analyse d'un fichier retourne un code d'erreur forme
                    # par la combinaison par OU binaire
                    # des retours d'erreurs de ses creations de vues et comptages;
                    # la fonction retourne la combinaison par OU binaire
                    # du retour d'analyse de l'ensemble des fichiers

    my ( $options, $fichiers ) = Options::traite_options(\@ARGV);
    my @tabFiles = @{$fichiers};

    if ( scalar(@tabFiles) == 0)
    {
        # aucun nom de fichier source n'ayant ete passe en ligne de commande,
        # l'option --file-list devrait designer un fichier contenant
        # la liste des fichiers sources a analyser
        @tabFiles = Options::getFileList($options);
    }
    usage() if ( scalar(@tabFiles) == 0);

    my $outFile = Options::GetOutputFile($options, '--o');
    usage() if (! defined $outFile);

    # tentative d'initialisation du fichier de sortie :
    # creation de l'en-tete du fichier CSV
    usage() if (IsoscopeDataFile::csv_file_open($outFile, \@CompteursPlSql) != 0);
    
    for my $fichier (@tabFiles)
    {
        $status |= AnalyseFile ($fichier, $options);
    }

    IsoscopeDataFile::csv_file_close();

    return $status;
}


# Lancement de l'analyse sur un fichier source
sub AnalyseFile($$)
{
    my ($fichier, $options) = @_ ;
    my $compteurs ; 
    my $status = 0; # l'analyse d'un fichier retourne un code d'erreur forme
                    # par la combinaison par OU binaire
                    # des retours d'erreurs de ses creations de vues
                    # et comptages et de leur memorisation

    my $date = Options::get_date_as_numerical_string();

    $compteurs =  new Couples() ; 
    $status |= Couples::counter_add($compteurs, "Dat_AnalysisDate", $date);
    $status |= Couples::counter_add($compteurs, "Dat_FileName", $fichier);

    my $vues = SourceLoader::mainLoadFile($fichier, $options);

    if (defined $vues->{'text'})
    {
        # le fichier n'est pas detecte comme binaire; on va tenter les comptages
        $status |= Couples::counter_add($compteurs, "Dat_Language", "PlSql");
        if ($status == 0)
        {
            $status = AnaPlSql::Analyse($fichier, $vues, $options, $compteurs);
        }
    }
    else
    {
        # pour un fichier binaire ou inaccessible,
	# on cree une ligne de resultats minimale

	if (defined $vues->{'bin'})
	{
            $status |= Couples::counter_add($compteurs, "Dat_Language", "Binary");
            print STDERR "detect language: " . 'binary' . " " . $fichier . "\n";
	}
	else
	{
	    # nom de fichier errone ou fichier illisible
            $status |= Couples::counter_add($compteurs, "Dat_Language", "Unknown");
	}
        $status |= 16;
    }

    $status |= Couples::counter_add($compteurs, "Dat_AnalysisStatus", $status);
    IsoscopeDataFile::csv_file_append($compteurs);
    if ( $status != 0)
    {
        printf STDERR "\nError: L'analyse du fichier $fichier s'est terminee avec le code 0x%x\n", $status;
    }

    return $status;
}


_setAllKnownMnemonics();
print STDERR "Outil de comptages sur codes sources PlSql - " .
             $VERSION . "\n"; 
my $code_final_de_retour= main();

exit ( $code_final_de_retour);

