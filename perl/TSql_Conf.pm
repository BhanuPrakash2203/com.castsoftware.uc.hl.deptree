package TSql_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode', 'CountCommun', \&CountCommun::CountLinesOfCode, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines100(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines132(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     [ Ident::Alias_ProcedureImplementations(), 'CountRoutine', 'TSql::CountRoutine', \&TSql::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [ Ident::Alias_FunctionImplementations(), 'CountRoutine', 'TSql::CountRoutine', \&TSql::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [ Ident::Alias_TriggerImplementations(), 'CountRoutine', 'TSql::CountRoutine', \&TSql::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [ Ident::Alias_UnmanagedSQLRoutine(), 'CountRoutine', 'TSql::CountRoutine', \&TSql::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [ Ident::Alias_UnsecureSQLRoutine(), 'CountRoutine', 'TSql::CountRoutine', \&TSql::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [ Ident::Alias_ComplexArtifact(), 'CountRoutine', 'TSql::CountRoutine', \&TSql::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [ Ident::Alias_LongArtifact(), 'CountRoutine', 'TSql::CountRoutine', \&TSql::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [ Ident::Alias_WithoutFinalReturn_Functions(), 'CountRoutine', 'TSql::CountRoutine', \&TSql::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [ Ident::Alias_WithTooMuchParametersMethods(), 'CountRoutine', 'TSql::CountRoutine', \&TSql::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [ Ident::Alias_ShortFunctionNamesLT(), 'CountRoutine', 'TSql::CountRoutine', \&TSql::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [ Ident::Alias_NotANSI_Joins(), 'CountSelect', 'TSql::CountSelect', \&TSql::CountSelect::CountSelect, 'APPEL', 1 ],
     [ Ident::Alias_SubQueries(), 'CountSelect', 'TSql::CountSelect', \&TSql::CountSelect::CountSelect, 'APPEL', 1 ],
     [ Ident::Alias_ComplexQueries(), 'CountSelect', 'TSql::CountSelect', \&TSql::CountSelect::CountSelect, 'APPEL', 1 ],
     [ Ident::Alias_MissingTableAlias(), 'CountSelect', 'TSql::CountSelect', \&TSql::CountSelect::CountSelect, 'APPEL', 1 ],
     [ Ident::Alias_InsertWithoutColumnsList(), 'CountSQL', 'TSql::CountSQL', \&TSql::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_WithMultiExprPerLine_Where(), 'CountSQL', 'TSql::CountSQL', \&TSql::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_BadQualifiedDatabaseObject(), 'CountSQL', 'TSql::CountSQL', \&TSql::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_DBObjectUsingRef(), 'CountSQL', 'TSql::CountSQL', \&TSql::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_NumericalOrderBy(), 'CountSQL', 'TSql::CountSQL', \&TSql::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_WithTooManyColumnsTables(), 'CountSQL', 'TSql::CountSQL', \&TSql::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_WithoutPrimaryKeyTables(), 'CountSQL', 'TSql::CountSQL', \&TSql::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_OnToManyTablesQueries(), 'CountSQL', 'TSql::CountSQL', \&TSql::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_UnCommentedColumns(), 'CountSQL', 'TSql::CountSQL', \&TSql::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_TotalColumns(), 'CountSQL', 'TSql::CountSQL', \&TSql::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_UnCommentedViews(), 'CountViewComment', 'TSql::CountComment', \&TSql::CountComment::CountViewComment, 'APPEL', 1 ],
     [ Ident::Alias_UnCommentedRoutines(), 'CountRoutineComment', 'TSql::CountComment', \&TSql::CountComment::CountRoutineComment, 'APPEL', 1 ],
     [ Ident::Alias_UnCommentedParameters(), 'CountRoutineComment', 'TSql::CountComment', \&TSql::CountComment::CountRoutineComment, 'APPEL', 1 ],
     [ Ident::Alias_TotalParameters(), 'CountRoutineComment', 'TSql::CountComment', \&TSql::CountComment::CountRoutineComment, 'APPEL', 1 ],
     [ Ident::Alias_Goto(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_TruncateTable(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_SQLOrderBy(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_SQLWhere(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_While(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Break(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Continue(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Sql_Insert(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_SQLDeclareTable(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_SQLDeclareView(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_From(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_SQLGroupby(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Try(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Catch(), 'CountKeywords', 'TSql::CountTSQL', \&TSql::CountTSQL::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_FetchInLoop(), 'CountFetchInLoop', 'TSql::CountTSQL', \&TSql::CountTSQL::CountFetchInLoop, 'APPEL', 1 ],
     [ Ident::Alias_Bad_DDL_DML_Interleaving(), 'CountSQL_DDL_DML', 'TSql::CountSQL_DDL_DML', \&TSql::CountSQL_DDL_DML::CountSQL_DDL_DML, 'APPEL', 1 ],
     [ Ident::Alias_DBUsedObjects(), 'CountSQL_DDL_DML', 'TSql::CountSQL_DDL_DML', \&TSql::CountSQL_DDL_DML::CountSQL_DDL_DML, 'APPEL', 1 ],

);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
     [ Ident::Alias_VG(), 'CountVG', 'TSql::CountTSQL', \&TSql::CountTSQL::CountVG, 'APPEL', 1 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
