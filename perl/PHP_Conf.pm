package PHP_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
     #[ Ident::Alias_CComments(), 'CountCComments', 'CountCComments', \&CountCComments::CountCComments, 'APPEL', 1 ],
     #[ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     #[ Ident::Alias_BlankLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     #[ Ident::Alias_CommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode', 'CountCommun', \&CountCommun::CountLinesOfCode, 'APPEL', 1 ],
     [ Ident::Alias_LongLines120(), 'CountLongLines_CodeComment', 'CountLongLines', \&CountLongLines::CountLongLines_CodeComment, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     [ Ident::Alias_While(), 'CountLoop', 'PHP::CountLoop', \&PHP::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_Do(), 'CountLoop', 'PHP::CountLoop', \&PHP::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_For(), 'CountLoop', 'PHP::CountLoop', \&PHP::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_Foreach(), 'CountLoop', 'PHP::CountLoop', \&PHP::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_UselessForLoop(), 'CountLoop', 'PHP::CountLoop', \&PHP::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_FunctionCallInForLoopTest(), 'CountLoop', 'PHP::CountLoop', \&PHP::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_IncrementerJumblingInLoop(), 'CountIncrementerJumblingInLoop', 'PHP::CountLoop', \&PHP::CountLoop::CountIncrementerJumblingInLoop, 'APPEL', 1 ],
     [ Ident::Alias_MissingIdenticalOperator(), 'CountCondition', 'PHP::CountCondition', \&PHP::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_ComplexConditions(), 'CountCondition', 'PHP::CountCondition', \&PHP::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_BadVariableDefinitionCheck(), 'CountCondition', 'PHP::CountCondition', \&PHP::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_BadIncDecUse(), 'CountExpression', 'PHP::CountExpression', \&PHP::CountExpression::CountExpression, 'APPEL', 1 ],
     [ Ident::Alias_AssignmentToThis(), 'CountKeywords', 'PHP::CountPHP', \&PHP::CountPHP::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Catch(), 'CountKeywords', 'PHP::CountPHP', \&PHP::CountPHP::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountKeywords', 'PHP::CountPHP', \&PHP::CountPHP::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Elsif(), 'CountKeywords', 'PHP::CountPHP', \&PHP::CountPHP::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Else(), 'CountKeywords', 'PHP::CountPHP', \&PHP::CountPHP::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_phpinfo(), 'CountKeywords', 'PHP::CountPHP', \&PHP::CountPHP::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_InterfaceDefinitions(), 'CountKeywords', 'PHP::CountPHP', \&PHP::CountPHP::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_EmptyStatementBloc(), 'CountEmptyStatementBloc', 'PHP::CountPHP', \&PHP::CountPHP::CountEmptyStatementBloc, 'APPEL', 1 ],
     [ Ident::Alias_UpperCaseKeywords(), 'CountUpperCaseKeywords', 'PHP::CountPHP', \&PHP::CountPHP::CountUpperCaseKeywords, 'APPEL', 1 ],
     [ Ident::Alias_UnnecessaryConcat(), 'CountUnnecessaryConcat', 'PHP::CountPHP', \&PHP::CountPHP::CountUnnecessaryConcat, 'APPEL', 1 ],
     [ Ident::Alias_LonelyVariableInString(), 'CountLonelyVariableInString', 'PHP::CountPHP', \&PHP::CountPHP::CountLonelyVariableInString, 'APPEL', 1 ],
     [ Ident::Alias_BadFileNames(), 'CountBadFileNames', 'PHP::CountPHP', \&PHP::CountPHP::CountBadFileNames, 'APPEL', 1 ],
     [ Ident::Alias_RequiredParamsBeforeOptional(), 'CountRequiredParamsBeforeOptional', 'PHP::CountPHP', \&PHP::CountPHP::CountRequiredParamsBeforeOptional, 'APPEL', 1 ],
     [ Ident::Alias_ToManyNestedLoop(), 'CountToManyNestedLoop', 'PHP::CountPHP', \&PHP::CountPHP::CountToManyNestedLoop, 'APPEL', 1 ],
     [ Ident::Alias_MissingBreakInCasePath(), 'CountMissingBreakInCasePath', 'PHP::CountPHP', \&PHP::CountPHP::CountMissingBreakInCasePath, 'APPEL', 1 ],
     [ Ident::Alias_Switch(), 'CountMissingBreakInCasePath', 'PHP::CountPHP', \&PHP::CountPHP::CountMissingBreakInCasePath, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CountMissingBreakInCasePath', 'PHP::CountPHP', \&PHP::CountPHP::CountMissingBreakInCasePath, 'APPEL', 1 ],
     [ Ident::Alias_Default(), 'CountMissingBreakInCasePath', 'PHP::CountPHP', \&PHP::CountPHP::CountMissingBreakInCasePath, 'APPEL', 1 ],
     [ Ident::Alias_UnconditionalCondition(), 'CountUnconditionalCondition', 'PHP::CountCondition', \&PHP::CountCondition::CountUnconditionalCondition, 'APPEL', 1 ],
     [ Ident::Alias_UnnecessaryFinalModifier(), 'CountClass', 'PHP::CountClass', \&PHP::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_UselessOverridingMethod(), 'CountClass', 'PHP::CountClass', \&PHP::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_BadClassNames(), 'CountClass', 'PHP::CountClass', \&PHP::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_MethodImplementations(), 'CountClass', 'PHP::CountClass', \&PHP::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_ClassImplementations(), 'CountClass', 'PHP::CountClass', \&PHP::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_ClassNameIsNotFileName(), 'CountClass', 'PHP::CountClass', \&PHP::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_BadConstructorNames(), 'CountClass', 'PHP::CountClass', \&PHP::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_ConstructorWithReturn(), 'CountClass', 'PHP::CountClass', \&PHP::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_MissingSetter(), 'CountClass', 'PHP::CountClass', \&PHP::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_UnassignedObjectInstanciation(), 'CountUnassignedObjectInstanciation', 'PHP::CountClass', \&PHP::CountClass::CountUnassignedObjectInstanciation, 'APPEL', 1 ],
     [ Ident::Alias_MissingEndComment(), 'CountMissingEndComment', 'PHP::CountComments', \&PHP::CountComments::CountMissingEndComment, 'APPEL', 1 ],
     [ Ident::Alias_EmptyCatches(), 'CountEmptyCatches', 'PHP::CountComments', \&PHP::CountComments::CountEmptyCatches, 'APPEL', 1 ],
     [ Ident::Alias_MissingThrowsTags(), 'CountFunctions', 'PHP::CountComments', \&PHP::CountComments::CountArtifacts, 'APPEL', 1 ],
     [ Ident::Alias_UnusedThrowsTags(), 'CountFunctions', 'PHP::CountComments', \&PHP::CountComments::CountArtifacts, 'APPEL', 1 ],
     [ Ident::Alias_LowCommentedRoutines(), 'CountFunctions', 'PHP::CountComments', \&PHP::CountComments::CountArtifacts, 'APPEL', 1 ],
     [ Ident::Alias_UnCommentedRoutines(), 'CountFunctions', 'PHP::CountComments', \&PHP::CountComments::CountArtifacts, 'APPEL', 1 ],
     [ Ident::Alias_UnCommentedClasses(), 'CountFunctions', 'PHP::CountComments', \&PHP::CountComments::CountArtifacts, 'APPEL', 1 ],
     [ Ident::Alias_LowCommentedRootCode(), 'CountRootComment', 'PHP::CountComments', \&PHP::CountComments::CountRootComment, 'APPEL', 1 ],
     [ Ident::Alias_ComplexRootCode(), 'CountRootComment', 'PHP::CountComments', \&PHP::CountComments::CountRootComment, 'APPEL', 1 ],
     [ Ident::Alias_UnusedParameters(), 'CountFunctions', 'PHP::CountFunctions', \&PHP::CountFunctions::CountFunctions, 'APPEL', 1 ],
     [ Ident::Alias_BadFunctionNames(), 'CountFunctions', 'PHP::CountFunctions', \&PHP::CountFunctions::CountFunctions, 'APPEL', 1 ],
     [ Ident::Alias_FunctionImplementations(), 'CountFunctions', 'PHP::CountFunctions', \&PHP::CountFunctions::CountFunctions, 'APPEL', 1 ],
     [ Ident::Alias_ComplexArtifact(), 'CountFunctions', 'PHP::CountFunctions', \&PHP::CountFunctions::CountFunctions, 'APPEL', 1 ],
     [ Ident::Alias_TooDepthArtifact(), 'CountFunctions', 'PHP::CountFunctions', \&PHP::CountFunctions::CountFunctions, 'APPEL', 1 ],
     [ Ident::Alias_GroupBy(), 'CountSQL', 'PHP::CountSQL', \&PHP::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_OnToManyTablesQueries(), 'CountSQL', 'PHP::CountSQL', \&PHP::CountSQL::CountSQL, 'APPEL', 1 ],
     [ Ident::Alias_Queries(), 'CountSQL', 'PHP::CountSQL', \&PHP::CountSQL::CountSQL, 'APPEL', 1 ],
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
