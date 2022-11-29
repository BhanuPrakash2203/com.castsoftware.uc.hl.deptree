package Java_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_AndOr(), 'CountAndOr', 'CountAndOr', \&CountAndOr::CountAndOr, 'APPEL', 1 ],
     [ Ident::Alias_AssignmentsInConditionalExpr(), 'CountAssignmentsInConditionalExpr', 'CountAssignmentsInConditionalExpr', \&CountAssignmentsInConditionalExpr::CountAssignmentsInConditionalExpr, 'APPEL', 1 ],
     [ Ident::Alias_BadSpacing(), 'CountBadSpacing', 'CountBadSpacing', \&CountBadSpacing::CountBadSpacing, 'APPEL', 1 ],
     [ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
     [ Ident::Alias_Break(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
     [ Ident::Alias_MultipleBreakLoops(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
     [ Ident::Alias_MissingBreakInSwitch(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
     [ Ident::Alias_CommentedOutCode(), 'CountCommentedOutCode', 'CountCommentedOutCode', \&CountCommentedOutCode::CountCommentedOutCode, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     [ Ident::Alias_BlankLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_CommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_AlphaNumCommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode', 'CountCommun', \&CountCommun::CountLinesOfCode, 'APPEL', 1 ],
     [ Ident::Alias_ComplexConditions(), 'CountComplexConditions', 'CountComplexConditions', \&CountComplexConditions::CountComplexConditions, 'APPEL', 1 ],
     [ Ident::Alias_ComplexOperands(), 'CountComplexOperands', 'Groovy::CountInstruction', \&Groovy::CountInstruction::CountComplexOperands, 'APPEL', 1 ],
     [ Ident::Alias_EmptyCatches(), 'CountEmptyCatches', 'CountEmptyCatches', \&CountEmptyCatches::CountEmptyCatches, 'APPEL', 1 ],
     [ Ident::Alias_OverloadEquals(), 'CountMethods', 'Java::CountMethods', \&Java::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_Import(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Else(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_While(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_For(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Continue(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Switch(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Default(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Try(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Catch(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Exit(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Instanceof(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_ParamTags(), 'CountAutodocTags', 'Java::CountJava', \&Java::CountJava::CountAutodocTags, 'APPEL', 1 ],
     [ Ident::Alias_SeeTags(), 'CountAutodocTags', 'Java::CountJava', \&Java::CountJava::CountAutodocTags, 'APPEL', 1 ],
     [ Ident::Alias_ReturnTags(), 'CountAutodocTags', 'Java::CountJava', \&Java::CountJava::CountAutodocTags, 'APPEL', 1 ],
     [ Ident::Alias_BugPatterns(), 'CountBugPatterns', 'Java::CountJava', \&Java::CountJava::CountBugPatterns, 'APPEL', 1 ],
     [ Ident::Alias_RiskyFunctionCalls(), 'CountRiskyFunctionCalls', 'Java::CountJava', \&Java::CountJava::CountRiskyFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_StarImport(), 'CountStarImport', 'Java::CountJava', \&Java::CountJava::CountStarImport, 'APPEL', 1 ],
     [ Ident::Alias_IllegalThrows(), 'CountIllegalThrows', 'Java::CountJava', \&Java::CountJava::CountIllegalThrows, 'APPEL', 1 ],
     [ Ident::Alias_OutOfFinallyJumps(), 'CountOutOfFinallyJumps', 'Java::CountJava', \&Java::CountJava::CountOutOfFinallyJumps, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines100(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines132(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_MissingBraces(), 'CountMissingBraces', 'CountMissingBraces', \&CountMissingBraces::CountMissingBraces, 'APPEL', 1 ],
     [ Ident::Alias_MissingBreakInCasePath(), 'CountMissingBreakInCasePath', 'CountMissingBreakInCasePath', \&CountMissingBreakInCasePath::CountMissingBreakInCasePath, 'APPEL', 1 ],
     [ Ident::Alias_MultipleStatementsOnSameLine(), 'CountMultInst', 'CountMultInst', \&CountMultInst::CountMultInst, 'APPEL', 1 ],
     [ Ident::Alias_RiskyCatches(), 'CountRiskyCatches', 'CountRiskyCatches', \&CountRiskyCatches::CountRiskyCatches, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     [ Ident::Alias_TernaryOperators(), 'CountTernaryOp', 'CountTernaryOp', \&CountTernaryOp::CountTernaryOp, 'APPEL', 1 ],
     [ Ident::Alias_WeakStringFunctionCalls(), 'CountWeakStringFunctionCalls', 'CountVulnerabilite', \&CountVulnerabilite::CountWeakStringFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_ShellLauncherFunctionCalls(), 'CountShellLauncherFunctionCalls', 'CountVulnerabilite', \&CountVulnerabilite::CountShellLauncherFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_FixedSizeArrays(), 'CountDefArrayFixedSize', 'CountVulnerabilite', \&CountVulnerabilite::CountDefArrayFixedSize, 'APPEL', 1 ],
     [ Ident::Alias_ClassesComparisons(), 'CountClassComparaison', 'CountVulnerabilite', \&CountVulnerabilite::CountClassComparaison, 'APPEL', 1 ],
     [ Ident::Alias_Words(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 1 ],
     [ Ident::Alias_DistinctWords(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 1 ],
     [ Ident::Alias_UnconditionalCondition(), 'CountUnconditionalCondition', 'Java::CountCondition', \&Java::CountCondition::CountUnconditionalCondition, 'APPEL', 1 ],
     [ Ident::Alias_DateUtilsTruncate(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_EqualsNotTestingParameter(), 'CountMethods', 'Java::CountMethods', \&Java::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_NestedTryCatches(), 'CountException', 'Java::CountException', \&Java::CountException::CountException, 'APPEL', 1 ],
     [ Ident::Alias_OnlyRethrowingCatches(), 'CountException', 'Java::CountException', \&Java::CountException::CountException, 'APPEL', 1 ],
     [ Ident::Alias_EmptyMethods(), 'CountMethods', 'Java::CountMethods', \&Java::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_CodeCommentLine(), 'CountComments', 'Java::CountComments', \&Java::CountComments::CountComments, 'APPEL', 1 ],
     [ Ident::Alias_CaseLengthAverage(), 'CountInstruction', 'Java::CountInstruction', \&Java::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [ Ident::Alias_SmallSwitchCase(), 'CountInstruction', 'Java::CountInstruction', \&Java::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [ Ident::Alias_UnconditionalJump(), 'CountLoop', 'Java::CountLoop', \&Java::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_UnconditionalJump(), 'CountMethods', 'Java::CountMethods', \&Java::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_UnconditionalJump(), 'CountInstruction', 'Java::CountInstruction', \&Java::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [ Ident::Alias_WithTooMuchParametersMethods(), 'CountMethods', 'Java::CountMethods', \&Java::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_TotalParameters(), 'CountMethods', 'Java::CountMethods', \&Java::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_EqualityInLoopCondition(), 'CountLoop', 'Java::CountLoop', \&Java::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_ShortMethodNamesLT(), 'CountMethods', 'Java::CountMethods', \&Java::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_BadMethodNames(), 'CountMethods', 'Java::CountMethods', \&Java::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_ShortClassNamesLT(), 'CountClass', 'Java::CountClass', \&Java::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_BadClassNames(), 'CountClass', 'Java::CountClass', \&Java::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_ShortAttributeNamesLT(), 'CountAttribute', 'Java::CountClass', \&Java::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_BadAttributeNames(), 'CountAttribute', 'Java::CountClass', \&Java::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_FunctionCallInLoopTest(), 'CountLoop', 'Java::CountLoop', \&Java::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_FunctionsUsingEllipsis(), 'CountMethods', 'Java::CountMethods', \&Java::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodDeclarations(), 'CountMethods', 'Java::CountMethods', \&Java::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodImplementations(), 'CountMethods', 'Java::CountMethods', \&Java::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_ClassDefinitions(), 'CountClass', 'Java::CountClass', \&Java::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_ClassImplementations(), 'CountClass', 'Java::CountClass', \&Java::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_UnusedParameters(), 'CountMethods', 'Java::CountMethods', \&Java::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_PrivateProtectedAttributes(), 'CountAttribute', 'Java::CountClass', \&Java::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_PublicAttributes(), 'CountAttribute', 'Java::CountClass', \&Java::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_InterfaceDefinitions(), 'CountInterface', 'Java::CountClass', \&Java::CountClass::CountInterface, 'APPEL', 1 ],
     [ Ident::Alias_TotalAttributes(), 'CountAttribute', 'Java::CountClass', \&Java::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_PrimitiveTypeWrapperInstanciation(), 'CountPrimitiveClassConstructor', 'Java::CountJava', \&Java::CountJava::CountPrimitiveClassConstructor, 'APPEL', 1 ],
     [ Ident::Alias_EmptyClasses(), 'CountClass', 'Java::CountClass', \&Java::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_UnexpectedAbstractClass(), 'CountClass', 'Java::CountClass', \&Java::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_ProtectedMemberInFinalClass(), 'CountClass', 'Java::CountClass', \&Java::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_PublicConstructorInUtilityClass(), 'CountClass', 'Java::CountClass', \&Java::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_LoopCounterModification(), 'CountLoop', 'Java::CountLoop', \&Java::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_MagicNumbers(), 'CountAttribute', 'Java::CountClass', \&Java::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_OctalLiteralValues(), 'CountAttribute', 'Java::CountClass', \&Java::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_LCLiteralSuffixes(), 'CountAttribute', 'Java::CountClass', \&Java::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_BadDeclarationOrder(), 'CountClass', 'Java::CountClass', \&Java::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_MissingHashcode(), 'CountClass', 'Java::CountClass', \&Java::CountClass::CountClass, 'APPEL', 1 ],

     # diags to be re-implemented in new parser :
     #[ Ident::Alias_ShortAttributeNamesHT(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
     #[ Ident::Alias_ShortClassNamesHT(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
     #[ Ident::Alias_ShortMethodNamesHT(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
     #[ Ident::Alias_ParentClasses(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
     #[ Ident::Alias_ParentInterfaces(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
     #[ Ident::Alias_PublicAttributes(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
    
);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
     [ Ident::Alias_VG(), 'CountVG', 'Java::CountJava', \&Java::CountJava::CountVG, 'APPEL', 1 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
