package Groovy_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode', 'CountCommun', \&CountCommun::CountLinesOfCode, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     [ Ident::Alias_BlankLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_CommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_AlphaNumCommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_UnexpectedAbstractClass(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_ShortClassNamesLT(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_BadClassNames(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_ProtectedMemberInFinalClass(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_EmptyClasses(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_BadAttributeNames(), 'CountAttribute', 'Groovy::CountClass', \&Groovy::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_ShortAttributeNamesLT(), 'CountAttribute', 'Groovy::CountClass', \&Groovy::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_PublicAttributes(), 'CountAttribute', 'Groovy::CountClass', \&Groovy::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_LCLiteralSuffixes(), 'CountAttribute', 'Groovy::CountClass', \&Groovy::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_ClassImplementations(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_PrivateProtectedAttributes(), 'CountAttribute', 'Groovy::CountClass', \&Groovy::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_InterfaceDefinitions(), 'CountInterface', 'Groovy::CountClass', \&Groovy::CountClass::CountInterface, 'APPEL', 1 ],
     [ Ident::Alias_PublicConstructorInUtilityClass(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_TotalParameters(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_MagicNumbers(), 'CountAttribute', 'Groovy::CountClass', \&Groovy::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_OctalLiteralValues(), 'CountAttribute', 'Groovy::CountClass', \&Groovy::CountClass::CountAttribute, 'APPEL', 1 ],
     [ Ident::Alias_MissingHashcode(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_CodeCommentLine(), 'CountComments', 'Groovy::CountComments', \&Groovy::CountComments::CountComments, 'APPEL', 1 ],
     [ Ident::Alias_OnlyRethrowingCatches(), 'CountException', 'Groovy::CountException', \&Groovy::CountException::CountException, 'APPEL', 1 ],
     [ Ident::Alias_NestedTryCatches(), 'CountTry', 'Groovy::CountException', \&Groovy::CountException::CountTry, 'APPEL', 1 ],
     [ Ident::Alias_OutOfFinallyJumps(), 'CountTry', 'Groovy::CountException', \&Groovy::CountException::CountTry, 'APPEL', 1 ],
     [ Ident::Alias_EmptyCatches(), 'CountException', 'Groovy::CountException', \&Groovy::CountException::CountException, 'APPEL', 1 ],
     [ Ident::Alias_IllegalThrows(), 'CountIllegalThrows', 'Groovy::CountException', \&Groovy::CountException::CountIllegalThrows, 'APPEL', 1 ],
     [ Ident::Alias_RiskyCatches(), 'CountRiskyCatches', 'Groovy::CountException', \&Groovy::CountException::CountRiskyCatches, 'APPEL', 1 ],
     [ Ident::Alias_CaseLengthAverage(), 'CountInstruction', 'Groovy::CountInstruction', \&Groovy::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [ Ident::Alias_LongCase(), 'CountInstruction', 'Groovy::CountInstruction', \&Groovy::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [ Ident::Alias_SmallSwitchCase(), 'CountInstruction', 'Groovy::CountInstruction', \&Groovy::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [ Ident::Alias_UnconditionalJump(), 'CountLoop', 'Groovy::CountLoop', \&Groovy::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_EqualityInLoopCondition(), 'CountLoop', 'Groovy::CountLoop', \&Groovy::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_FunctionCallInLoopTest(), 'CountLoop', 'Groovy::CountLoop', \&Groovy::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_LoopCounterModification(), 'CountLoop', 'Groovy::CountLoop', \&Groovy::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_UnconditionalJump(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_UnconditionalJump(), 'CountInstruction', 'Groovy::CountInstruction', \&Groovy::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [ Ident::Alias_EmptyMethods(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_ShortMethodNamesLT(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_BadMethodNames(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_FunctionsUsingEllipsis(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_EqualsNotTestingParameter(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_OverloadEquals(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_UnusedParameters(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodDeclarations(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodImplementations(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_MethodImplementations(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_FunctionImplementations(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_AndOr(), 'CountAndOr', 'CountAndOr', \&CountAndOr::CountAndOr, 'APPEL', 1 ],
     [ Ident::Alias_ComplexConditions(), 'CountCondition', 'Groovy::CountCondition', \&Groovy::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_ConditionComplexityAverage(), 'CountCondition', 'Groovy::CountCondition', \&Groovy::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_StarImport(), 'CountStarImport', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountStarImport, 'APPEL', 1 ],
     [ Ident::Alias_AssignmentsInConditionalExpr(), 'CountCondition', 'Groovy::CountCondition', \&Groovy::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_MissingBreakInCasePath(), 'CountSwitch', 'Groovy::CountCondition', \&Groovy::CountCondition::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_UnconditionalJump(), 'CountLoop', 'Groovy::CountLoop', \&Groovy::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_UnconditionalJump(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_UnconditionalJump(), 'CountInstruction', 'Groovy::CountInstruction', \&Groovy::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [ Ident::Alias_ClassDefinitions(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_AbstractClassWithPublicConstructor(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_PublicFinalizeMethod(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_EmptyStatementBloc(), 'CountInstruction', 'Groovy::CountInstruction', \&Groovy::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [ Ident::Alias_LongElsif(), 'CountElsif', 'Groovy::CountCondition', \&Groovy::CountCondition::CountElsif, 'APPEL', 1 ],
     [ Ident::Alias_NestedForLoop(), 'CountLoop', 'Groovy::CountLoop', \&Groovy::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_UselessForLoop(), 'CountLoop', 'Groovy::CountLoop', \&Groovy::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_DynamicType(), 'CountDynamicType', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountDynamicType, 'APPEL', 1 ],
     [ Ident::Alias_ClosureAsLastMethodParameter(), 'CountInlineClosureAsParameter', 'Groovy::CountMethods', \&Groovy::CountMethods::CountInlineClosureAsParameter, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousDestructuringAssignment(), 'CountSuspiciousDestructuringAssignment', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountSuspiciousDestructuringAssignment, 'APPEL', 1 ],
     [ Ident::Alias_CouldBeElvis(), 'CountPatternReplacedByElvis', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountPatternReplacedByElvis, 'APPEL', 1 ],
     [ Ident::Alias_ParameterUpdate(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_ParameterUpdate(), 'CountClosures', 'Groovy::CountClosures', \&Groovy::CountClosures::CountClosures, 'APPEL', 1 ],
     [ Ident::Alias_AssignmentToStaticFieldFromInstanceMethod(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_CollapsibleIf(), 'CountCondition', 'Groovy::CountCondition', \&Groovy::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_TooDepthArtifact(), 'CountTooDepthArtifact', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountTooDepthArtifact, 'APPEL', 1 ],
     [ Ident::Alias_OverDepthAverage(), 'CountTooDepthArtifact', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountTooDepthArtifact, 'APPEL', 1 ],








	 # JAVA 
     [ Ident::Alias_BadSpacing(), 'CountBadSpacing', 'CountBadSpacing', \&CountBadSpacing::CountBadSpacing, 'APPEL', 1 ],
     [ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
     [ Ident::Alias_Break(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
     [ Ident::Alias_MultipleBreakLoops(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
     [ Ident::Alias_CommentedOutCode(), 'CountCommentedOutCode', 'CountCommentedOutCode', \&CountCommentedOutCode::CountCommentedOutCode, 'APPEL', 1 ],
     [ Ident::Alias_ComplexOperands(), 'CountComplexOperands', 'Groovy::CountInstruction', \&Groovy::CountInstruction::CountComplexOperands, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Else(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_While(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_For(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Continue(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Switch(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Default(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Try(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Catch(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Instanceof(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_ParamTags(), 'CountAutodocTags', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountAutodocTags, 'APPEL', 1 ],
     [ Ident::Alias_RiskyFunctionCalls(), 'CountRiskyFunctionCalls', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountRiskyFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines100(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines132(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_MissingBraces(), 'CountMissingBraces', 'CountMissingBraces', \&CountMissingBraces::CountMissingBraces, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     [ Ident::Alias_TernaryOperators(), 'CountTernaryOp', 'CountTernaryOp', \&CountTernaryOp::CountTernaryOp, 'APPEL', 1 ],
     [ Ident::Alias_ClassesComparisons(), 'CountClassComparaison', 'CountVulnerabilite', \&CountVulnerabilite::CountClassComparaison, 'APPEL', 1 ],
     [ Ident::Alias_PrimitiveTypeWrapperInstanciation(), 'CountPrimitiveClassConstructor', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountPrimitiveClassConstructor, 'APPEL', 1 ],
     
     # Need adaptation
     [ Ident::Alias_BugPatterns(), 'CountJavaBugPatterns', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountJavaBugPatterns, 'APPEL', 1 ],
     [ Ident::Alias_MultipleStatementsOnSameLine(), 'CountMultInst', 'CountMultInst', \&CountMultInst::CountMultInst, 'APPEL', 1 ],
     [ Ident::Alias_BadDeclarationOrder(), 'CountClass', 'Groovy::CountClass', \&Groovy::CountClass::CountClass, 'APPEL', 1 ],
     
     # Unused
     [ Ident::Alias_Import(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Exit(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_WeakStringFunctionCalls(), 'CountWeakStringFunctionCalls', 'CountVulnerabilite', \&CountVulnerabilite::CountWeakStringFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_ShellLauncherFunctionCalls(), 'CountShellLauncherFunctionCalls', 'CountVulnerabilite', \&CountVulnerabilite::CountShellLauncherFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_FixedSizeArrays(), 'CountDefArrayFixedSize', 'CountVulnerabilite', \&CountVulnerabilite::CountDefArrayFixedSize, 'APPEL', 1 ],
     [ Ident::Alias_DateUtilsTruncate(), 'CountKeywords', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_TotalAttributes(), 'CountAttribute', 'Groovy::CountClass', \&Groovy::CountClass::CountAttribute, 'APPEL', 1 ],
     
     # Used in alert MissingAutomatedDoc that do not belong to an alarm
     #~ [ Ident::Alias_SeeTags(), 'CountAutodocTags', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountAutodocTags, 'APPEL', 1 ],
     [ Ident::Alias_ReturnTags(), 'CountAutodocTags', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountAutodocTags, 'APPEL', 1 ],
     
     # Deprecated
     [ Ident::Alias_Words(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 1 ],
     [ Ident::Alias_DistinctWords(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 1 ],
     
     
     [ Ident::Alias_WithTooMuchParametersMethods(), 'CountMethods', 'Groovy::CountMethods', \&Groovy::CountMethods::CountMethods, 'APPEL', 1 ],
     
     
     
     
     
     
);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
     # [ Ident::Alias_VG(), 'CountVG', 'Groovy::CountGroovy', \&Groovy::CountGroovy::CountVG, 'APPEL', 1 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
