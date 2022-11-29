package Abap_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs_agglo', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs_agglo, 'APPEL', 1 ],
     [ Ident::Alias_CommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode', 'CountCommun', \&CountCommun::CountLinesOfCode, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines100(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines132(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     [ Ident::Alias_ProcedureImplementations(), 'CountRoutines', 'Abap::CountRoutines', \&Abap::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_FunctionImplementations(), 'CountRoutines', 'Abap::CountRoutines', \&Abap::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_MethodImplementations(), 'CountRoutines', 'Abap::CountRoutines', \&Abap::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_ModuleImplementations(), 'CountRoutines', 'Abap::CountRoutines', \&Abap::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_LongArtifact(), 'CountRoutines', 'Abap::CountRoutines', \&Abap::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_BadFunctionNames(), 'CountRoutines', 'Abap::CountRoutines', \&Abap::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_ComplexArtifact(), 'CountRoutines', 'Abap::CountRoutines', \&Abap::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_EmptyArtifact(), 'CountRoutines', 'Abap::CountRoutines', \&Abap::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_TooDepthArtifact(), 'CountRoutines', 'Abap::CountRoutines', \&Abap::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_UsingByValuePassing_Forms(), 'CountRoutines', 'Abap::CountRoutines', \&Abap::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_OnChangeOf(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_BreakPoint(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_SelectAll(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_ReadTable(), 'CountReadTable', 'Abap::CountAbap', \&Abap::CountAbap::CountReadTable, 'APPEL', 1 ],
     [ Ident::Alias_IntoCorrespondingFieldsOf(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_SQLOrderBy(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_SelectDistinct(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_NativeSQL(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_LoopInto(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_SystemCall(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_RefToMe(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Include(), 'CountInclude', 'Abap::CountAbap', \&Abap::CountAbap::CountInclude, 'APPEL', 1 ],
     [ Ident::Alias_Exit(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_EndSelect(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_UpTo1Row(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_EmptyProgram(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_EmptyInclude(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_SubQueries(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Do(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_While(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Loop(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Provide(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Sql_Modify(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Sql_Delete(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Sql_Insert(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Sql_Update(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_AuthorityCheck(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Read(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_OpenDataset(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_FetchNextCursor(), 'CountKeywords', 'Abap::CountAbap', \&Abap::CountAbap::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_CodeCheckDisabling(), 'CountCodeCheckDisabling', 'Abap::CountAbap', \&Abap::CountAbap::CountCodeCheckDisabling, 'APPEL', 1 ],
     [ Ident::Alias_BadProgramNames(), 'CountBadProgramNames', 'Abap::CountAbap', \&Abap::CountAbap::CountBadProgramNames, 'APPEL', 1 ],
     [ Ident::Alias_BadIncludeNames(), 'CountBadProgramNames', 'Abap::CountAbap', \&Abap::CountAbap::CountBadProgramNames, 'APPEL', 1 ],
     [ Ident::Alias_MissingDefaults(), 'CountMissingDefaults', 'Abap::CountAbap', \&Abap::CountAbap::CountMissingDefaults, 'APPEL', 1 ],
     [ Ident::Alias_Switch(), 'CountMissingDefaults', 'Abap::CountAbap', \&Abap::CountAbap::CountMissingDefaults, 'APPEL', 1 ],
     [ Ident::Alias_EmptyCatches(), 'CountEmptyCatches', 'Abap::CountAbap', \&Abap::CountAbap::CountEmptyCatches, 'APPEL', 1 ],
     [ Ident::Alias_Catch(), 'CountEmptyCatches', 'Abap::CountAbap', \&Abap::CountAbap::CountEmptyCatches, 'APPEL', 1 ],
     [ Ident::Alias_ToManyNestedLoop(), 'CountToManyNestedLoop', 'Abap::CountAbap', \&Abap::CountAbap::CountToManyNestedLoop, 'APPEL', 1 ],
     [ Ident::Alias_UncheckedReturn(), 'CountUncheckedReturn', 'Abap::CountAbap', \&Abap::CountAbap::CountUncheckedReturn, 'APPEL', 1 ],
     [ Ident::Alias_AtInLoopAtWhere(), 'CountAtInLoopAtWhere', 'Abap::CountAbap', \&Abap::CountAbap::CountAtInLoopAtWhere, 'APPEL', 1 ],
     [ Ident::Alias_TestUnameAgainstSpecificValue(), 'CountTestUnameAgainstSpecificValue', 'Abap::CountAbap', \&Abap::CountAbap::CountTestUnameAgainstSpecificValue, 'APPEL', 1 ],
     [ Ident::Alias_HardCodedPaths(), 'CountHardCodedPaths', 'Abap::CountAbap', \&Abap::CountAbap::CountHardCodedPaths, 'APPEL', 1 ],
     [ Ident::Alias_HardCodedValues(), 'CountHardCodedValues', 'Abap::CountAbap', \&Abap::CountAbap::CountHardCodedValues, 'APPEL', 1 ],
     [ Ident::Alias_ExitInInclude(), 'CountExitInInclude', 'Abap::CountAbap', \&Abap::CountAbap::CountExitInInclude, 'APPEL', 1 ],
     [ Ident::Alias_SelectBypassingBuffer(), 'CountSelect', 'Abap::CountSelect', \&Abap::CountSelect::CountSelect, 'APPEL', 1 ],
     [ Ident::Alias_IsNullInWhereClause(), 'CountSelect', 'Abap::CountSelect', \&Abap::CountSelect::CountSelect, 'APPEL', 1 ],
     [ Ident::Alias_NotOpInWhereClause(), 'CountSelect', 'Abap::CountSelect', \&Abap::CountSelect::CountSelect, 'APPEL', 1 ],
     [ Ident::Alias_MissingWhereClause(), 'CountSelect', 'Abap::CountSelect', \&Abap::CountSelect::CountSelect, 'APPEL', 1 ],
     [ Ident::Alias_SelectForUpdate(), 'CountSelect', 'Abap::CountSelect', \&Abap::CountSelect::CountSelect, 'APPEL', 1 ],
     [ Ident::Alias_DynamicQueries(), 'CountDynamicQueries', 'Abap::CountSelect', \&Abap::CountSelect::CountDynamicQueries, 'APPEL', 1 ],
     [ Ident::Alias_ComplexQueries(), 'CountSelect', 'Abap::CountSelect', \&Abap::CountSelect::CountSelect, 'APPEL', 1 ],
     [ Ident::Alias_OnToManyTablesQueries(), 'CountSelect', 'Abap::CountSelect', \&Abap::CountSelect::CountSelect, 'APPEL', 1 ],
     [ Ident::Alias_Select(), 'CountSelect', 'Abap::CountSelect', \&Abap::CountSelect::CountSelect, 'APPEL', 1 ],
     [ Ident::Alias_NestedSelect(), 'CountNestedSelect', 'Abap::CountSelect', \&Abap::CountSelect::CountNestedSelect, 'APPEL', 1 ],
     [ Ident::Alias_StandardTableModifications(), 'CountStandardTableModifications', 'Abap::CountSelect', \&Abap::CountSelect::CountStandardTableModifications, 'APPEL', 1 ],
     [ Ident::Alias_UnCommentedRoutines(), 'CountUnCommentedRoutines', 'Abap::CountComments', \&Abap::CountComments::CountUnCommentedRoutines, 'APPEL', 1 ],
     [ Ident::Alias_LowCommentedRoutines(), 'CountUnCommentedRoutines', 'Abap::CountComments', \&Abap::CountComments::CountUnCommentedRoutines, 'APPEL', 1 ],

);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
