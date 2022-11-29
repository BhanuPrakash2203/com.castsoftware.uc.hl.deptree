
package PlSql::CountKeywords ;
# Module de comptage des instructions continue, goto, exit.

use strict;
use warnings;

use Erreurs;

sub CountKeywords($$$);


my @keyord_table = (
  #["id", "keyword", "Mnémonique", "Idée"],
  ["K2", "alter", Ident::Alias_Sql_Alter(), "Compter le nombre d'occurences du mot clé ALTER"],
  ["K3", "and", Ident::Alias_Basex_And(), "Compter le nombre d'occurences du mot clé AND"],
  ["K13", "binary_integer", Ident::Alias_Type_Binary_Integer(), "Compter le nombre d'occurences du mot clé BINARY_INTEGER"],
  ["K15", "boolean", Ident::Alias_Type_Boolean(), "Compter le nombre d'occurences du mot clé BOOLEAN"],
  ["K19", "char", Ident::Alias_Type_Char(), "Compter le nombre d'occurences du mot clé CHAR"],
  ["K20", "char_base", Ident::Alias_Type_Char_Base(), "Compter le nombre d'occurences du mot clé CHAR_BASE"],
  ["K22", "close", Ident::Alias_Sql_Close(), "Compter le nombre d'occurences du mot clé CLOSE"],
  ["K27", "commit", Ident::Alias_Sql_Commit(), "Compter le nombre d'occurences du mot clé COMMIT"],
  ["K29", "connect", Ident::Alias_Sql_Connect(), "Compter le nombre d'occurences du mot clé CONNECT"],
  ["K31", "create", Ident::Alias_Sql_Create(), "Compter le nombre d'occurences du mot clé CREATE"],
  ["K34", "cursor", Ident::Alias_Sql_Cursor(), "Compter le nombre d'occurences du mot clé CURSOR"],
  ["K37", "declare", Ident::Alias_Sql_Declare(), "Compter le nombre d'occurences du mot clé DECLARE"],
  ["K40", "delete", Ident::Alias_Sql_Delete(), "Compter le nombre d'occurences du mot clé DELETE"],
  ["K43", "do", Ident::Alias_Base_Do(), "Compter le nombre d'occurences du mot clé DO"],
  ["K44", "drop", Ident::Alias_Sql_Drop(), "Compter le nombre d'occurences du mot clé DROP"],
  ["K45", "else", Ident::Alias_Base_Else(), "Compter le nombre d'occurences du mot clé ELSE"],
  ["K46", "elsif", Ident::Alias_Base_Elsif(), "Compter le nombre d'occurences du mot clé ELSIF"],
  ["K48", "exception", Ident::Alias_Base_Exception(), "Compter le nombre d'occurences du mot clé EXCEPTION"],
  ["K50", "execute", Ident::Alias_Sql_Execute(), "Compter le nombre d'occurences du mot clé EXECUTE"],
  ["K52", "exit", Ident::Alias_Base_Exit(), "Compter le nombre d'occurences du mot clé EXIT"],
  ["K56", "fetch", Ident::Alias_Sql_Fetch(), "Compter le nombre d'occurences du mot clé FETCH"],
  ["K57", "float", Ident::Alias_Type_Float(), "Compter le nombre d'occurences du mot clé FLOAT"],
  ["K58", "for", Ident::Alias_Base_For(), "Compter le nombre d'occurences du mot clé FOR"],
  ["K59", "forall", Ident::Alias_Base_Forall(), "Compter le nombre d'occurences du mot clé FORALL"],
  ["K61", "function", Ident::Alias_Basex_Function(), "Compter le nombre d'occurences du mot clé FUNCTION"],
  ["K62", "goto", Ident::Alias_Base_Goto(), "Compter le nombre d'occurences du mot clé GOTO"],
  ["K67", "if", Ident::Alias_Base_If(), "Compter le nombre d'occurences du mot clé IF"],
  ["K72", "insert", Ident::Alias_Sql_Insert(), "Compter le nombre d'occurences du mot clé INSERT"],
  ["K73", "integer", Ident::Alias_Type_Integer(), "Compter le nombre d'occurences du mot clé INTEGER"],
  ["K85", "long", Ident::Alias_Type_Long(), "Compter le nombre d'occurences du mot clé LONG"],
  ["K86", "loop", Ident::Alias_Base_Loop(), "Compter le nombre d'occurences du mot clé LOOP"],
  ["K95", "natural", Ident::Alias_Type_Natural(), "Compter le nombre d'occurences du mot clé NATURAL"],
  ["K96", "naturaln", Ident::Alias_Type_Naturaln(), "Compter le nombre d'occurences du mot clé NATURALN"],
  ["K104", "number", Ident::Alias_Type_Number(), "Compter le nombre d'occurences du mot clé NUMBER"],
  ["K110", "open", Ident::Alias_Sql_Open(), "Compter le nombre d'occurences du mot clé OPEN"],
  ["K113", "or", Ident::Alias_Basex_Or(), "Compter le nombre d'occurences du mot clé OR"],
  ["K116", "others", Ident::Alias_Base_Others(), "Compter le nombre d'occurences du mot clé OTHERS"],
  ["K118", "package", Ident::Alias_Basex_Package(), "Compter le nombre d'occurences du mot clé PACKAGE"],
  ["K121", "pls_integer", Ident::Alias_Type_Pls_Integer(), "Compter le nombre d'occurences du mot clé PLS_INTEGER"],
  ["K122", "positive", Ident::Alias_Type_Positive(), "Compter le nombre d'occurences du mot clé POSITIVE"],
  ["K123", "positiven", Ident::Alias_Type_Positiven(), "Compter le nombre d'occurences du mot clé POSITIVEN"],
  ["K126", "private", Ident::Alias_Basex_Private(), "Compter le nombre d'occurences du mot clé PRIVATE"],
  ["K127", "procedure", Ident::Alias_Basex_Procedure(), "Compter le nombre d'occurences du mot clé PROCEDURE"],
  ["K128", "public", Ident::Alias_Basex_Public(), "Compter le nombre d'occurences du mot clé PUBLIC"],
  ["K129", "raise", Ident::Alias_Base_Raise(), "Compter le nombre d'occurences du mot clé RAISE"],
  ["K132", "real", Ident::Alias_Type_Real(), "Compter le nombre d'occurences du mot clé REAL"],
  ["K136", "return", Ident::Alias_Base_Return(), "Compter le nombre d'occurences du mot clé RETURN"],
  ["K138", "rollback", Ident::Alias_Sql_Rollback(), "Compter le nombre d'occurences du mot clé ROLLBACK"],
  ["K139", "row", Ident::Alias_Type_Row(), "Compter le nombre d'occurences du mot clé ROW"],
  ["K140", "rowid", Ident::Alias_Type_Rowid(), "Compter le nombre d'occurences du mot clé ROWID"],
  ["K145", "select", Ident::Alias_Sql_Select(), "Compter le nombre d'occurences du mot clé SELECT"],
  ["K149", "smallint", Ident::Alias_Type_Smallint(), "Compter le nombre d'occurences du mot clé SMALLINT"],
  ["K156", "subtype", Ident::Alias_Basex_Subtype(), "Compter le nombre d'occurences du mot clé SUBTYPE"],
  ["K162", "then", Ident::Alias_Basex_Then(), "Compter le nombre d'occurences du mot clé THEN"],
  ["K170", "trigger", Ident::Alias_Sql_Trigger(), "Compter le nombre d'occurences du mot clé TRIGGER"],
  ["K176", "update", Ident::Alias_Sql_Update(), "Compter le nombre d'occurences du mot clé UPDATE"],
  ["K181", "varchar", Ident::Alias_Type_Varchar(), "Compter le nombre d'occurences du mot clé VARCHAR"],
  ["K182", "varchar2", Ident::Alias_Type_Varchar2(), "Compter le nombre d'occurences du mot clé VARCHAR2"],
  ["K188", "while", Ident::Alias_Base_While(), "Compter le nombre d'occurences du mot clé WHILE"],
  ["K194", "clob", Ident::Alias_Type_Clob(), "Compter le nombre d'occurences du mot clé CLOB"],
  ["K195", "lob", Ident::Alias_Type_Lob(), "Compter le nombre d'occurences du mot clé LOB"],
  ["P20", "exception_init", Ident::Alias_Base_Exception_Init(), "Compter le nombre d'occurrences du mot clé EXCEPTION_INIT"],
  ["P40", "decode", Ident::Alias_Base_Decode(), "Compter le nombre d'occurrences du mot clé decode."],

  ["undefined", "begin", Ident::Alias_Base_Begin(), "Compter le nombre d'occurrences du mot clé begin."],
  ["undefined", "end", Ident::Alias_Base_End(), "Compter le nombre d'occurrences du mot clé end."],
);


# FIXME: Il s'agit d'une fonction utilitaire.
# Le nom de la routine ne devrait donc pas commencer par Count
sub _CountItem($$$$) 
{
  my ($item, $id, $buffer, $compteurs) = @_ ;
  my $ret = 0;

  if ( ! defined $buffer) {
    $ret |= Couples::counter_add($compteurs, $id, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nb = () = $buffer  =~ /\b${item}\b/sg ;
  $ret |= Couples::counter_add($compteurs, $id, $nb);

  return $ret;
}


sub CountKeywords($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  my $NomVueCode = 'code_and_directives'; 
  my $buffer = undef;

  # Astuce pour se parer de l'absence d'harmonie de casse dans les vues.
  if ( defined $vue->{$NomVueCode} ) 
  {
    $buffer = lc (  $vue->{$NomVueCode} ) ;
  }

  for my $comptage ( @keyord_table )
  {
    $ret |= _CountItem($comptage->[1], $comptage->[2], $buffer, $compteurs);
  }

  return $ret;
}

1;



