package Python_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

our @table_Comptages = (

	[ Ident::Alias_LinesOfCode(), 'CountComments', 'Python::CountComment', \&Python::CountComment::CountInlineComments, 'APPEL', 1 ],
	[ Ident::Alias_CommentBlocs(), 'CountComments', 'Python::CountComment', \&Python::CountComment::CountInlineComments, 'APPEL', 1 ],
	[ Ident::Alias_CommentLines(), 'CountComments', 'Python::CountComment', \&Python::CountComment::CountInlineComments, 'APPEL', 1 ],
	[ Ident::Alias_UnCommentedClasses(), 'CountUnCommentedArtifact', 'Python::CountComment', \&Python::CountComment::CountUnCommentedArtifact, 'APPEL', 1 ],
	[ Ident::Alias_UnCommentedRoutines(), 'CountUnCommentedArtifact', 'Python::CountComment', \&Python::CountComment::CountUnCommentedArtifact, 'APPEL', 1 ],
	[ Ident::Alias_InlineComments(), 'CountComments', 'Python::CountComment', \&Python::CountComment::CountComments, 'APPEL', 1 ],
	[ Ident::Alias_MissingBlankLines(), 'CountComments', 'Python::CountComment', \&Python::CountComment::CountComments, 'APPEL', 1 ],
	[ Ident::Alias_EmptyCatches(), 'CountExceptions', 'Python::CountException', \&Python::CountException::CountExceptions, 'APPEL', 1 ],
	[ Ident::Alias_RiskyCatches(), 'CountExceptions', 'Python::CountException', \&Python::CountException::CountExceptions, 'APPEL', 1 ],
	[ Ident::Alias_Catch(), 'CountExceptions', 'Python::CountException', \&Python::CountException::CountExceptions, 'APPEL', 1 ],
	[ Ident::Alias_GlobalVariableHidding(), 'CountVariablesHidding', 'Python::CountVariable', \&Python::CountVariable::CountVariablesHidding, 'APPEL', 1 ],
	[ Ident::Alias_OverridenBuiltInException(), 'CountVariables', 'Python::CountVariable', \&Python::CountVariable::CountVariables, 'APPEL', 1 ],
	[ Ident::Alias_LocalVarAverage(), 'CountVariables', 'Python::CountVariable', \&Python::CountVariable::CountVariables, 'APPEL', 1 ],
	[ Ident::Alias_BadVariableNames(), 'CountVariables', 'Python::CountVariable', \&Python::CountVariable::CountVariables, 'APPEL', 1 ],
	[ Ident::Alias_BadAttributeNames(), 'CountVariables', 'Python::CountVariable', \&Python::CountVariable::CountVariables, 'APPEL', 1 ],
	[ Ident::Alias_VarNotUsed(), 'CountVariablesHidding', 'Python::CountVariable', \&Python::CountVariable::CountVariablesHidding, 'APPEL', 1 ],
	[ Ident::Alias_OverridenBuiltInException(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_UnusedParameters(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_WithTooMuchParametersMethods(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_EmptyReturn(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_MultipleReturnFunctionsMethods(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_FunctionImplementations(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_ShortFunctionNamesLT(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_ShortMethodNamesLT(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_FunctionNameLengthAverage(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_MethodNameLengthAverage(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_BadFunctionNames(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_BadMethodNames(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_Para(), 'CountFunctions', 'Python::CountFunction', \&Python::CountFunction::CountFunctions, 'APPEL', 1 ],
	[ Ident::Alias_BadClassNames(), 'CountClasses', 'Python::CountClass', \&Python::CountClass::CountClasses, 'APPEL', 1 ],
	#[ "xxxx", 'CountLambda', 'Python::CountFunction', \&Python::CountFunction::CountLambda, 'APPEL', 1 ],
	[ Ident::Alias_IllegalException(), 'CountClasses', 'Python::CountClass', \&Python::CountClass::CountClasses, 'APPEL', 1 ],
	[ Ident::Alias_BadStaticOrClassMethods(), 'CountClasses', 'Python::CountClass', \&Python::CountClass::CountClasses, 'APPEL', 1 ],
	[ Ident::Alias_MethodsAverage(), 'CountClasses', 'Python::CountClass', \&Python::CountClass::CountClasses, 'APPEL', 1 ],
	[ Ident::Alias_ClassImplementations(), 'CountClasses', 'Python::CountClass', \&Python::CountClass::CountClasses, 'APPEL', 1 ],
	[ Ident::Alias_MethodImplementations(), 'CountClasses', 'Python::CountClass', \&Python::CountClass::CountClasses, 'APPEL', 1 ],
	[ Ident::Alias_ConflictingImports(), 'CountImports', 'Python::CountImport', \&Python::CountImport::CountImports, 'APPEL', 1 ],
	[ Ident::Alias_StarImport(), 'CountImports', 'Python::CountImport', \&Python::CountImport::CountImports, 'APPEL', 1 ],
	[ Ident::Alias_MultipleImports(), 'CountImports', 'Python::CountImport', \&Python::CountImport::CountImports, 'APPEL', 1 ],
	[ Ident::Alias_UnusedImports(), 'CountImports', 'Python::CountImport', \&Python::CountImport::CountImports, 'APPEL', 1 ],
	[ Ident::Alias_BadAliasAgreement(), 'CountImports', 'Python::CountImport', \&Python::CountImport::CountImports, 'APPEL', 1 ],
	[ Ident::Alias_ConstructorWithReturn(), 'CountClasses', 'Python::CountClass', \&Python::CountClass::CountClasses, 'APPEL', 1 ],
	[ Ident::Alias_MagicMethodsCalls(), 'CountClasses', 'Python::CountClass', \&Python::CountClass::CountClasses, 'APPEL', 1 ],
	[ Ident::Alias_BadGetterSetter(), 'CountClasses', 'Python::CountClass', \&Python::CountClass::CountClasses, 'APPEL', 1 ],
	[ Ident::Alias_MissingParentConstructor(), 'CountClasses', 'Python::CountClass', \&Python::CountClass::CountClasses, 'APPEL', 1 ],
	[ Ident::Alias_ExplicitComparisonToSingleton(), 'CountConditions', 'Python::CountCondition', \&Python::CountCondition::CountConditions, 'APPEL', 1 ],
	[ Ident::Alias_DeprecatedOperator(), 'CountConditions', 'Python::CountCondition', \&Python::CountCondition::CountConditions, 'APPEL', 1 ],
	[ Ident::Alias_InstanceOf(), 'CountConditions', 'Python::CountCondition', \&Python::CountCondition::CountConditions, 'APPEL', 1 ],
	[ Ident::Alias_BadIdenticalOperatorUse(), 'CountConditions', 'Python::CountCondition', \&Python::CountCondition::CountConditions, 'APPEL', 1 ],
	[ Ident::Alias_InvertedLogic(), 'CountConditions', 'Python::CountCondition', \&Python::CountCondition::CountConditions, 'APPEL', 1 ],
	[ Ident::Alias_RepetitionInComparison(), 'CountConditions', 'Python::CountCondition', \&Python::CountCondition::CountConditions, 'APPEL', 1 ],
	[ Ident::Alias_ComplexConditions(), 'CountConditions', 'Python::CountCondition', \&Python::CountCondition::CountConditions, 'APPEL', 1 ], 
	[ Ident::Alias_MultilineConditions(), 'CountConditions', 'Python::CountCondition', \&Python::CountCondition::CountConditions, 'APPEL', 1 ], 
	[ Ident::Alias_Conditions(), 'CountConditions', 'Python::CountCondition', \&Python::CountCondition::CountConditions, 'APPEL', 1 ], 
	[ Ident::Alias_IllegalThrows(), 'CountRaise', 'Python::CountException', \&Python::CountException::CountRaise, 'APPEL', 1 ],
	[ Ident::Alias_TrySizeAverage, 'CountTry', 'Python::CountException', \&Python::CountException::CountTry, 'APPEL', 1 ],
	[ Ident::Alias_ExtraneousSpaces(), 'CountCode', 'Python::CountCode', \&Python::CountCode::CountCode, 'APPEL', 1 ],
	[ Ident::Alias_MissingSpaces(), 'CountCode', 'Python::CountCode', \&Python::CountCode::CountCode, 'APPEL', 1 ],
	[ Ident::Alias_TrailingSpaces(), 'CountCode', 'Python::CountCode', \&Python::CountCode::CountCode, 'APPEL', 1 ],
	[ Ident::Alias_TabIndentation(), 'CountCode', 'Python::CountCode', \&Python::CountCode::CountCode, 'APPEL', 1 ],
	[ Ident::Alias_MultipleStatementsOnSameLine(), 'CountCode', 'Python::CountCode', \&Python::CountCode::CountCode, 'APPEL', 1 ],
	[ Ident::Alias_ContinuationLines(), 'CountCode', 'Python::CountCode', \&Python::CountCode::CountCode, 'APPEL', 1 ],
	[ Ident::Alias_BadBoundary(), 'CountCode', 'Python::CountCode', \&Python::CountCode::CountCode, 'APPEL', 1 ],
	[ Ident::Alias_UnnecessaryConcat(), 'CountCode', 'Python::CountCode', \&Python::CountCode::CountCode, 'APPEL', 1 ],
	[ Ident::Alias_VG(), 'CountCode', 'Python::CountCode', \&Python::CountCode::CountCode, 'APPEL', 1 ],
	[ Ident::Alias_UnexpectedSemicolon(), 'CountCode', 'Python::CountCode', \&Python::CountCode::CountCode, 'APPEL', 1 ],
	[ Ident::Alias_MagicNumbers(), 'CountVariablesHidding', 'Python::CountVariable', \&Python::CountVariable::CountVariablesHidding, 'APPEL', 1 ],
	[ Ident::Alias_LongLines80(), 'CountLongLines', 'Python::CountCode', \&Python::CountCode::CountLongLines, 'APPEL', 1 ],
	[ Ident::Alias_PercentStringFormat(), 'CountStrings', 'Python::CountString', \&Python::CountString::CountStrings, 'APPEL', 1 ],
	[ Ident::Alias_AutomaticNumberingInStringsFields(), 'CountStrings', 'Python::CountString', \&Python::CountString::CountStrings, 'APPEL', 1 ],
	[ Ident::Alias_ConcatInLoop(), 'CountStrings', 'Python::CountString', \&Python::CountString::CountStrings, 'APPEL', 1 ],
	[ Ident::Alias_MixedStringsStyle(), 'CountStrings', 'Python::CountString', \&Python::CountString::CountStrings, 'APPEL', 1 ],
	[ Ident::Alias_SpacesInStringReplacementFields(), 'CountStrings', 'Python::CountString', \&Python::CountString::CountStrings, 'APPEL', 1 ],
	[ Ident::Alias_GlobalVariables(), 'CountStrings', 'Python::CountString', \&Python::CountString::CountStrings, 'APPEL', 1 ],
	[ Ident::Alias_LoopWithElseWithoutBreak(), 'CountStrings', 'Python::CountString', \&Python::CountString::CountStrings, 'APPEL', 1 ],
	[ Ident::Alias_String(), 'CountStrings', 'Python::CountString', \&Python::CountString::CountStrings, 'APPEL', 1 ],
	[ Ident::Alias_Loop(), 'CountStrings', 'Python::CountString', \&Python::CountString::CountStrings, 'APPEL', 1 ],
	[ Ident::Alias_SuspiciousComments(), 'CountSuspiciousCommentsInternational', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousCommentsInternational, 'APPEL', 1 ],
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

