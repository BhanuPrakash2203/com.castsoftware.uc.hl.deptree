package CS_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_AndOr(), 'CountAndOr', 'CountAndOr', \&CountAndOr::CountAndOr, 'APPEL', 1 ],
     [ Ident::Alias_AssignmentsInConditionalExpr(), 'CountConditions', 'CS::CountCondition', \&CS::CountCondition::CountConditions, 'APPEL', 1 ],
     [ Ident::Alias_MissingFinalElses(), 'CountIfs', 'CS::CountCondition', \&CS::CountCondition::CountIfs, 'APPEL', 1 ],
     [ Ident::Alias_CollapsibleIf(), 'CountIfs', 'CS::CountCondition', \&CS::CountCondition::CountIfs, 'APPEL', 1 ],
     [ Ident::Alias_NestedTernary(), 'CountTernary', 'CS::CountCondition', \&CS::CountCondition::CountTernary, 'APPEL', 1 ],
     
     
     [ Ident::Alias_BadSpacing(), 'CountBadSpacing', 'CountBadSpacing', \&CountBadSpacing::CountBadSpacing, 'APPEL', 1 ],
     [ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
     [ Ident::Alias_Break(), 'CountLoop', 'CS::CountLoop', \&CS::CountLoop::CountLoop, 'APPEL', 1 ],
     #[ Ident::Alias_MultipleBreakLoops(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
     [ Ident::Alias_MissingBreakInCasePath(), 'CountSwitch', 'CS::CountCS', \&CS::CountCS::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_CommentedOutCode(), 'CountCommentedOutCode', 'CS::CountComment', \&CS::CountComment::CountCommentedOutCode, 'APPEL', 1 ],
     [ Ident::Alias_InlineComments(), 'CountInlineComments', 'CS::CountComment', \&CS::CountComment::CountInlineComments, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     [ Ident::Alias_BlankLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_CommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_AlphaNumCommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode', 'CountCommun', \&CountCommun::CountLinesOfCode, 'APPEL', 1 ],
     [ Ident::Alias_ComplexConditions(), 'CountConditions', 'CS::CountCondition', \&CS::CountCondition::CountConditions, 'APPEL', 1 ],
     [ Ident::Alias_ConditionComplexityAverage(), 'CountConditions', 'CS::CountCondition', \&CS::CountCondition::CountConditions, 'APPEL', 1 ],
     #[ Ident::Alias_ComplexOperands(), 'CountComplexOperands', 'CountComplexOperands', \&CountComplexOperands::CountComplexOperands, 'APPEL', 1 ],
     #[ Ident::Alias_Using(), 'CountKeywords', 'CountCS', \&CountCS::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountCS', 'CS::CountCS', \&CS::CountCS::CountCS, 'APPEL', 1 ],
     [ Ident::Alias_Else(), 'CountKeywords', 'CS::CountCS', \&CS::CountCS::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_While(), 'CountCS', 'CS::CountCS', \&CS::CountCS::CountCS, 'APPEL', 1 ],
     [ Ident::Alias_For(), 'CountCS', 'CS::CountCS', \&CS::CountCS::CountCS, 'APPEL', 1 ],
     [ Ident::Alias_Foreach(), 'CountCS', 'CS::CountCS', \&CS::CountCS::CountCS, 'APPEL', 1 ],
     [ Ident::Alias_Continue(), 'CountKeywords', 'CS::CountCS', \&CS::CountCS::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Switch(), 'CountSwitch', 'CS::CountCS', \&CS::CountCS::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_BreakCase(), 'CountSwitch', 'CS::CountCS', \&CS::CountCS::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_Default(), 'CountCS', 'CS::CountCS', \&CS::CountCS::CountCS, 'APPEL', 1 ],
     [ Ident::Alias_MissingDefaults(), 'CountSwitch', 'CS::CountCS', \&CS::CountCS::CountSwitch, 'APPEL', 1 ],
     #[ Ident::Alias_Try(), 'CountKeywords', 'CountCS', \&CountCS::CountKeywords, 'APPEL', 1 ],
     #[ Ident::Alias_Catch(), 'CountKeywords', 'CountCS', \&CountCS::CountKeywords, 'APPEL', 1 ],
     #[ Ident::Alias_Exit(), 'CountKeywords', 'CountCS', \&CountCS::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Instanceof(), 'CountKeywords', 'CS::CountCS', \&CS::CountCS::CountKeywords, 'APPEL', 1 ],
     #[ Ident::Alias_New(), 'CountKeywords', 'CountCS', \&CountCS::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CountCS', 'CS::CountCS', \&CS::CountCS::CountCS, 'APPEL', 1 ],
     [ Ident::Alias_IllegalThrows(), 'CountIllegalThrows', 'CS::CountCS', \&CS::CountCS::CountIllegalThrows, 'APPEL', 1 ],
     [ Ident::Alias_ParamTags(), 'CountAutodocTags', 'CS::CountComment', \&CS::CountComment::CountAutodocTags, 'APPEL', 1 ],
     [ Ident::Alias_SeeTags(), 'CountAutodocTags', 'CS::CountComment', \&CS::CountComment::CountAutodocTags, 'APPEL', 1 ],
     [ Ident::Alias_ReturnTags(), 'CountAutodocTags', 'CS::CountComment', \&CS::CountComment::CountAutodocTags, 'APPEL', 1 ],
     [ Ident::Alias_BugPatterns(), 'CountBugPatterns', 'CountCS', \&CountCS::CountBugPatterns, 'APPEL', 1 ],
     [ Ident::Alias_RiskyFunctionCalls(), 'CountRiskyFunctionCalls', 'CS::CountCS', \&CS::CountCS::CountRiskyFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodImplementations(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethods::CountMethod, 'APPEL', 1 ],
     [ Ident::Alias_FunctionOutParameters(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethods::CountMethod, 'APPEL', 1 ],
     #[ Ident::Alias_Constructors(), 'CountMetrics', 'CountCS', \&CountCS::CountMetrics, 'APPEL', 1 ],
     #[ Ident::Alias_Properties(), 'CountMetrics', 'CountCS', \&CountCS::CountMetrics, 'APPEL', 1 ],
     [ Ident::Alias_PublicAttributes(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_PrivateProtectedAttributes(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_Properties(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_ClassImplementations(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_TopLevelClasses(), 'CountTopLevelClasses', 'CS::CountClass', \&CS::CountClass::CountTopLevelClasses, 'APPEL', 1 ],
     [ Ident::Alias_TotalParameters(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethod::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_WithTooMuchParametersMethods(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethod::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_ParametersAverage(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethod::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_UnusedParameters(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethod::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_UnusedLocalVariables(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethod::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_Finalize(), 'CountFinalyzer', 'CS::CountMethod', \&CS::CountMethod::CountFinalyzer, 'APPEL', 1 ],
     [ Ident::Alias_EmptyMethods(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethod::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_LostInitialization(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethod::CountMethods, 'APPEL', 1 ],
     
     [ Ident::Alias_BadClassNames(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_BadMethodNames(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethod::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_BadAttributeNames(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_ShortClassNamesLT(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_ShortMethodNamesLT(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethod::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_ShortAttributeNamesLT(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_AbstractClassWithPublicConstructor(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_UnusedAttributes(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_FieldShadow(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_AttributeNameLengthAverage(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_ClassNameLengthAverage(), 'CountClasses', 'CS::CountClass', \&CS::CountClass::CountClasses, 'APPEL', 1 ],
     
     #[ Ident::Alias_ParentClasses(), 'CountMetrics', 'CountCS', \&CountCS::CountMetrics, 'APPEL', 1 ],
     #[ Ident::Alias_ParentInterfaces(), 'CountMetrics', 'CountCS', \&CountCS::CountMetrics, 'APPEL', 1 ],
     #[ Ident::Alias_BadDeclarationOrder(), 'CountMetrics', 'CountCS', \&CountCS::CountMetrics, 'APPEL', 1 ],
     [ Ident::Alias_Finalize(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethod::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_WithTooMuchParametersMethods(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethod::CountMethods, 'APPEL', 1 ],
     [ Ident::Alias_MethodNameLengthAverage(), 'CountMethods', 'CS::CountMethod', \&CS::CountMethod::CountMethods, 'APPEL', 1 ],
     #[ "EMPTY DESTRUCTOR", 'CountDestructors', 'CS::CountMethod', \&CS::CountMethod::CountDestructors, 'APPEL', 1 ],
     [ Ident::Alias_LongArtifact(), 'CountDestructors', 'CS::CountMethod', \&CS::CountMethod::CountDestructors, 'APPEL', 1 ],
     [ Ident::Alias_MethodsLengthAverage(), 'CountDestructors', 'CS::CountMethod', \&CS::CountMethod::CountDestructors, 'APPEL', 1 ],
     
     [ Ident::Alias_EmptyCatches(), 'CountCatch', 'CS::CountException', \&CS::CountException::CountCatch, 'APPEL', 1 ],
     [ Ident::Alias_OnlyRethrowingCatches(), 'CountCatch', 'CS::CountException', \&CS::CountException::CountCatch, 'APPEL', 1 ],
     [ Ident::Alias_ThrowInFinally(), 'CountThrowInFinalizers', 'CS::CountException', \&CS::CountException::CountThrowInFinalizers, 'APPEL', 1 ],
     [ Ident::Alias_ThrowInDestructor(), 'CountThrowInFinalizers', 'CS::CountException', \&CS::CountException::CountThrowInFinalizers, 'APPEL', 1 ],
     #[ Ident::Alias_IfPrepro(), 'CountIfPrepro', 'CountIfPrepro', \&CountIfPrepro::CountIfPrepro, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines100(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines132(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_MagicNumbers(), 'CountMagicNumbers', 'CS::CountCS', \&CS::CountCS::CountMagicNumbers, 'APPEL', 1 ],
     [ Ident::Alias_SwitchDefaultMisplaced(), 'CountSwitch', 'CS::CountCS', \&CS::CountCS::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_LargeSwitches(), 'CountSwitch', 'CS::CountCS', \&CS::CountCS::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_SmallSwitchCase(), 'CountSwitch', 'CS::CountCS', \&CS::CountCS::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_SwitchNested(), 'CountSwitch', 'CS::CountCS', \&CS::CountCS::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_SwitchLengthAverage(), 'CountSwitch', 'CS::CountCS', \&CS::CountCS::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_TooDepthArtifact(), 'CountDeepPath', 'CS::CountCS', \&CS::CountCS::CountDeepPath, 'APPEL', 1 ],
     [ Ident::Alias_OverDepthAverage(), 'CountDeepPath', 'CS::CountCS', \&CS::CountCS::CountDeepPath, 'APPEL', 1 ],
     [ Ident::Alias_ArtifactDepthAverage(), 'CountDeepPath', 'CS::CountCS', \&CS::CountCS::CountDeepPath, 'APPEL', 1 ],

     [ Ident::Alias_MissingBraces(), 'CountMissingBraces2', 'CountMissingBraces', \&CountMissingBraces::CountMissingBraces2, 'APPEL', 1 ],
     [ Ident::Alias_MultipleStatementsOnSameLine(), 'CountMultInst', 'CountMultInst', \&CountMultInst::CountMultInst, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousCommentsInternational', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousCommentsInternational, 'APPEL', 1 ],
     
);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
     #[ Ident::Alias_VG(), 'CountVG', 'CountCS', \&CountCS::CountVG, 'APPEL', 1 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
