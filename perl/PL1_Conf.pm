package PL1_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode_SansPrepro', 'CountCommun', \&CountCommun::CountLinesOfCode_SansPrepro, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines100(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines132(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     [ Ident::Alias_UnrefInternalProc(), 'CountProcedure', 'PL1::CountProcedure', \&PL1::CountProcedure::CountProcedure, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodImplementations(), 'CountProcedure', 'PL1::CountProcedure', \&PL1::CountProcedure::CountProcedure, 'APPEL', 1 ],
     [ Ident::Alias_ShortFunctionNamesLT(), 'CountProcedure', 'PL1::CountProcedure', \&PL1::CountProcedure::CountProcedure, 'APPEL', 1 ],
     [ Ident::Alias_ShortFunctionNamesHT(), 'CountProcedure', 'PL1::CountProcedure', \&PL1::CountProcedure::CountProcedure, 'APPEL', 1 ],
     [ Ident::Alias_BadMainProcedureName(), 'CountProcedure', 'PL1::CountProcedure', \&PL1::CountProcedure::CountProcedure, 'APPEL', 1 ],
     [ Ident::Alias_MissingOnError(), 'CountProcedure', 'PL1::CountProcedure', \&PL1::CountProcedure::CountProcedure, 'APPEL', 1 ],
     [ Ident::Alias_Fetch(), 'CountWithoutTitleFetch', 'PL1::CountProcedure', \&PL1::CountProcedure::CountWithoutTitleFetch, 'APPEL', 1 ],
     [ Ident::Alias_WithoutTitleFetch(), 'CountWithoutTitleFetch', 'PL1::CountProcedure', \&PL1::CountProcedure::CountWithoutTitleFetch, 'APPEL', 1 ],
     [ Ident::Alias_CommentedOutCode(), 'CountCommentedOutCode', 'PL1::CountCommentedOutCode', \&PL1::CountCommentedOutCode::CountCommentedOutCode, 'APPEL', 1 ],
     [ Ident::Alias_MultipleStatementsOnSameLine(), 'CountMultInst', 'PL1::CountMultInst', \&PL1::CountMultInst::CountMultInst, 'APPEL', 1 ],
     [ Ident::Alias_WhileLoop(), 'CountHeterogeneousLoop', 'PL1::CountLoop', \&PL1::CountLoop::CountHeterogeneousLoop, 'APPEL', 1 ],
     [ Ident::Alias_UntilLoop(), 'CountHeterogeneousLoop', 'PL1::CountLoop', \&PL1::CountLoop::CountHeterogeneousLoop, 'APPEL', 1 ],
     [ Ident::Alias_ToManyNestedLoop(), 'CountToManyNestedLoop', 'PL1::CountNested', \&PL1::CountNested::CountToManyNestedLoop, 'APPEL', 1 ],
     [ Ident::Alias_ToManyNestedIf(), 'CountToManyNestedIf', 'PL1::CountNested', \&PL1::CountNested::CountToManyNestedIf, 'APPEL', 1 ],
     [ Ident::Alias_End(), 'CountWithoutLabelEnd', 'PL1::CountEnd', \&PL1::CountEnd::CountWithoutLabelEnd, 'APPEL', 1 ],
     [ Ident::Alias_WithoutLabel_End(), 'CountWithoutLabelEnd', 'PL1::CountEnd', \&PL1::CountEnd::CountWithoutLabelEnd, 'APPEL', 1 ],
     [ Ident::Alias_ComplexWhen(), 'CountComplexWhen', 'PL1::CountWhen', \&PL1::CountWhen::CountComplexWhen, 'APPEL', 1 ],
     [ Ident::Alias_Switch(), 'CountMissingDefault', 'PL1::CountWhen', \&PL1::CountWhen::CountMissingDefault, 'APPEL', 1 ],
     [ Ident::Alias_MissingDefaults(), 'CountMissingDefault', 'PL1::CountWhen', \&PL1::CountWhen::CountMissingDefault, 'APPEL', 1 ],
     [ Ident::Alias_AndOr(), 'CountComplexConditions', 'PL1::CountCondition', \&PL1::CountCondition::CountComplexConditions, 'APPEL', 1 ],
     [ Ident::Alias_ComplexConditions(), 'CountComplexConditions', 'PL1::CountCondition', \&PL1::CountCondition::CountComplexConditions, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountVg', 'PL1::CountVg', \&PL1::CountVg::CountVg, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CountVg', 'PL1::CountVg', \&PL1::CountVg::CountVg, 'APPEL', 1 ],
     [ Ident::Alias_Default(), 'CountVg', 'PL1::CountVg', \&PL1::CountVg::CountVg, 'APPEL', 1 ],
     [ Ident::Alias_Loop(), 'CountVg', 'PL1::CountVg', \&PL1::CountVg::CountVg, 'APPEL', 1 ],
     [ Ident::Alias_Goto(), 'CountSpaghettiCode', 'PL1::CountVg', \&PL1::CountVg::CountSpaghettiCode, 'APPEL', 1 ],
     [ Ident::Alias_Continue(), 'CountSpaghettiCode', 'PL1::CountVg', \&PL1::CountVg::CountSpaghettiCode, 'APPEL', 1 ],
     [ Ident::Alias_Break(), 'CountSpaghettiCode', 'PL1::CountVg', \&PL1::CountVg::CountSpaghettiCode, 'APPEL', 1 ],
     [ Ident::Alias_Words(), 'CountWords', 'PL1::CountWords', \&PL1::CountWords::CountWords, 'APPEL', 1 ],
     [ Ident::Alias_DistinctWords(), 'CountWords', 'PL1::CountWords', \&PL1::CountWords::CountWords, 'APPEL', 1 ],
     [ Ident::Alias_ProcessStatement(), 'CountProcessStatement', 'PL1::CountPrepro', \&PL1::CountPrepro::CountProcessStatement, 'APPEL', 1 ],
     [ Ident::Alias_SQL(), 'CountSQL', 'PL1::CountSQL', \&PL1::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_GroupBy(), 'CountSQL', 'PL1::CountSQL', \&PL1::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_NotExists(), 'CountSQL', 'PL1::CountSQL', \&PL1::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_NotIn(), 'CountSQL', 'PL1::CountSQL', \&PL1::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_SelectAll(), 'CountSQL', 'PL1::CountSQL', \&PL1::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_NotTestedSQLCODE(), 'CountSQL', 'PL1::CountSQL', \&PL1::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_Declare(), 'CountDeclare', 'PL1::CountDeclare', \&PL1::CountDeclare::CountDeclare, 'APPEL', 1 ],
     [ Ident::Alias_ImpreciseNumericDeclaration(), 'CountDeclare', 'PL1::CountDeclare', \&PL1::CountDeclare::CountDeclare, 'APPEL', 1 ],
     [ Ident::Alias_RepeatInVarInit(), 'CountDeclare', 'PL1::CountDeclare', \&PL1::CountDeclare::CountDeclare, 'APPEL', 1 ],
     [ Ident::Alias_NullStatement(), 'CountAny', 'PL1::CountAny', \&PL1::CountAny::CountAny, 'APPEL', 1 ],
     [ Ident::Alias_BlkSize(), 'CountKeywords', 'PL1::CountKeywords', \&PL1::CountKeywords::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_RecSize(), 'CountKeywords', 'PL1::CountKeywords', \&PL1::CountKeywords::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_String(), 'CountKeywords', 'PL1::CountKeywords', \&PL1::CountKeywords::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_MissingFileClose(), 'CountResource', 'PL1::CountResource', \&PL1::CountResource::CountResource, 'APPEL', 1 ],
     [ Ident::Alias_MissingVarFree(), 'CountResource', 'PL1::CountResource', \&PL1::CountResource::CountResource, 'APPEL', 1 ],

);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
     [ Ident::Alias_VG(), 'CountVG', 'PL1::SynthCount', \&PL1::SynthCount::CountVG, 'APPEL', 1 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
