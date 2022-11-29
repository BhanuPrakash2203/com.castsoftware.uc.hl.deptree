package Typescript_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 2 ],
     [ Ident::Alias_FunctionCallInLoopTest(), 'CountLoop', 'TypeScript::CountLoop', \&TypeScript::CountLoop::CountLoop, 'APPEL', 2 ],
     [ Ident::Alias_ForinLoop(), 'CountLoop', 'TypeScript::CountLoop', \&TypeScript::CountLoop::CountLoop, 'APPEL', 2 ],
     [ Ident::Alias_While(), 'CountLoop', 'TypeScript::CountLoop', \&TypeScript::CountLoop::CountLoop, 'APPEL', 2 ],
     [ Ident::Alias_Do(), 'CountLoop', 'TypeScript::CountLoop', \&TypeScript::CountLoop::CountLoop, 'APPEL', 2 ],
     [ Ident::Alias_For(), 'CountLoop', 'TypeScript::CountLoop', \&TypeScript::CountLoop::CountLoop, 'APPEL', 2 ],
     [ Ident::Alias_UnecessaryNestedObjectResolution(), 'CountArtifact', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountArtifact, 'APPEL', 2 ],
     [ Ident::Alias_MissingIdenticalOperator(), 'CountCondition', 'TypeScript::CountCondition', \&TypeScript::CountCondition::CountCondition, 'APPEL', 2 ],
     [ Ident::Alias_ComplexConditions(), 'CountCondition', 'TypeScript::CountCondition', \&TypeScript::CountCondition::CountCondition, 'APPEL', 2 ],
     [ Ident::Alias_AssignmentsInConditionalExpr(), 'CountCondition', 'TypeScript::CountCondition', \&TypeScript::CountCondition::CountCondition, 'APPEL', 2 ],
     [ Ident::Alias_Conditions(), 'CountCondition', 'TypeScript::CountCondition', \&TypeScript::CountCondition::CountCondition, 'APPEL', 2 ],
     [ Ident::Alias_IEConditionalComments(), 'CountIEConditionalComments', 'TypeScript::CountComment', \&TypeScript::CountComment::CountIEConditionalComments, 'APPEL', 1 ],
     [ Ident::Alias_WithinBlocksFunctionsDecl(), 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_MisplacedInnerFuncDecl(), 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_BadSpacingInFuncDecl(), 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_MisplacedFunctionDecl(), 'CountMisplacedFunctionDecl', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountMisplacedFunctionDecl, 'APPEL', 2 ],
     [ Ident::Alias_MissingImmediateFuncCallWrapping(), 'CountMissingImmediateFuncCallWrapping', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountMissingImmediateFuncCallWrapping, 'APPEL', 2 ],
     [ Ident::Alias_TooDepthArtifact(), 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_MisplacedVarStatement(), 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_FunctionDeclarations(), 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_FunctionExpressions(), 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_MethodImplementations(), 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_ComplexArtifact(), 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
#     [ 'Thres_2', 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
#     [ 'Thres_3', 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
#     [ 'Thres_4', 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_MultilineString(), 'CountString', 'TypeScript::CountString', \&TypeScript::CountString::CountString, 'APPEL', 2 ],
     [ Ident::Alias_UnexpectedDoubleQuoteStr(), 'CountString', 'TypeScript::CountString', \&TypeScript::CountString::CountString, 'APPEL', 2 ],
     [ Ident::Alias_String(), 'CountString', 'TypeScript::CountString', \&TypeScript::CountString::CountString, 'APPEL', 2 ],
     [ Ident::Alias_ShortFunctionNamesLT(), 'CountNaming', 'TypeScript::CountNaming', \&TypeScript::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_BadFunctionNames(), 'CountNaming', 'TypeScript::CountNaming', \&TypeScript::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_ShortClassNamesLT(), 'CountClass', 'TypeScript::CountClass', \&TypeScript::CountClass::CountClass, 'APPEL', 2 ],
     [ Ident::Alias_BadClassNames(), 'CountClass', 'TypeScript::CountClass', \&TypeScript::CountClass::CountClass, 'APPEL', 2 ],
     [ Ident::Alias_ShortAttributeNamesLT(), 'CountNaming', 'TypeScript::CountNaming', \&TypeScript::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_BadAttributeNames(), 'CountNaming', 'TypeScript::CountNaming', \&TypeScript::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_ShortParameterNamesLT(), 'CountNaming', 'TypeScript::CountNaming', \&TypeScript::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_PublicAttributes(), 'CountNaming', 'TypeScript::CountNaming', \&TypeScript::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_TotalParameters(), 'CountNaming', 'TypeScript::CountNaming', \&TypeScript::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_ShortGlobalNamesLT(), 'CountVariable', 'TypeScript::CountVariable', \&TypeScript::CountVariable::CountVariable, 'APPEL', 2 ],
     [ Ident::Alias_BadVariableNames(), 'CountVariable', 'TypeScript::CountVariable', \&TypeScript::CountVariable::CountVariable, 'APPEL', 2 ],
     [ Ident::Alias_BadSelectorCaching(), 'CountVariable', 'TypeScript::CountVariable', \&TypeScript::CountVariable::CountVariable, 'APPEL', 2 ],
     [ Ident::Alias_ImpliedGlobalVar(), 'CountVariable', 'TypeScript::CountVariable', \&TypeScript::CountVariable::CountVariable, 'APPEL', 2 ],
     [ Ident::Alias_MultipleDeclarationsInSameStatement(), 'CountMultipleDeclarations', 'TypeScript::CountVariable', \&TypeScript::CountVariable::CountMultipleDeclarations, 'APPEL', 2 ],
     [ Ident::Alias_BadArrayDeclaration(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_BadObjectDeclaration(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_ObjectDeclaration(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_MultilineReturn(), 'CountMultilineReturn', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountMultilineReturn, 'APPEL', 2 ],
     [ Ident::Alias_MissingScalarType(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_ArgumentCallee(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_UnexpectedThis(), 'CountArtifact', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountArtifact, 'APPEL', 2 ],
     [ Ident::Alias_With(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Break(), 'CountBreakInLoop', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountBreakInLoop, 'APPEL', 2 ],
     [ Ident::Alias_Continue(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_BadSetTimeout(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_BadSetInterval(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Eval(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_If(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Else(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Case(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Switch(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Return(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_TernaryOperators(), 'CountCondition', 'TypeScript::CountCondition', \&TypeScript::CountCondition::CountCondition, 'APPEL', 2 ],
     [ Ident::Alias_AndOr(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Var(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_MissingBreakInCasePath(), 'CountSwitch', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountSwitch, 'APPEL', 2 ],
     [ Ident::Alias_MagicNumbers(), 'CountMissingInstructionSeparator', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountMissingInstructionSeparator, 'APPEL', 2 ],
     [ Ident::Alias_MissingBraces(), 'CountMissingInstructionSeparator', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountMissingInstructionSeparator, 'APPEL', 2 ],
     [ Ident::Alias_MissingSemicolon(), 'CountMissingInstructionSeparator', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountMissingInstructionSeparator, 'APPEL', 2 ],
     [ Ident::Alias_BadSpacing(), 'CountBadSpacing', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountBadSpacing, 'APPEL', 2 ],
     [ Ident::Alias_UnauthorizedPrototypeModification(), 'CountUnauthorizedPrototypeModification', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountUnauthorizedPrototypeModification, 'APPEL', 2 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 2 ],
     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode_agglo', 'CountCommun', \&CountCommun::CountLinesOfCode_agglo, 'APPEL', 2 ],
     [ Ident::Alias_CommentLines(), 'CountLinesOfCode_agglo', 'CountCommun', \&CountCommun::CountLinesOfCode_agglo, 'APPEL', 2 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs_agglo', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs_agglo, 'APPEL', 2 ],
     [ Ident::Alias_OnlyRethrowingCatches(), 'CountCondition', 'TypeScript::CountCondition', \&TypeScript::CountCondition::CountCondition, 'APPEL', 2 ],
     [ Ident::Alias_SwitchNested(), 'CountSwitch', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountSwitch, 'APPEL', 2 ],
     [ Ident::Alias_VariableShadow(), 'CountMultipleDeclarations', 'TypeScript::CountVariable', \&TypeScript::CountVariable::CountMultipleDeclarations, 'APPEL', 2 ],
     [ Ident::Alias_BadIncDecUse(), 'CountStatement', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountStatement, 'APPEL', 2 ],
     [ Ident::Alias_MaxParameters(), 'CountParameter', 'TypeScript::CountParameter', \&TypeScript::CountParameter::CountParameter, 'APPEL', 2 ],
     [ Ident::Alias_ParametersAverage(), 'CountParameter', 'TypeScript::CountParameter', \&TypeScript::CountParameter::CountParameter, 'APPEL', 2 ],
     [ Ident::Alias_OutOfFinallyJumps(), 'CountCondition', 'TypeScript::CountCondition', \&TypeScript::CountCondition::CountCondition, 'APPEL', 2 ],
     [ Ident::Alias_SwitchDefaultMisplaced(), 'CountSwitch', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountSwitch, 'APPEL', 2 ],
     [ Ident::Alias_ErrorWithoutThrow(), 'CountError', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountError, 'APPEL', 2 ],
     [ Ident::Alias_BadCaseLogical(), 'CountSwitch', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountSwitch, 'APPEL', 2 ],
     [ Ident::Alias_BadInterfaceConstructor(), 'CountInterface', 'TypeScript::CountClass', \&TypeScript::CountClass::CountInterface, 'APPEL', 2 ],
     [ Ident::Alias_MultilineBreak(), 'CountString', 'TypeScript::CountString', \&TypeScript::CountString::CountString, 'APPEL', 2 ],
     [ Ident::Alias_IllegalThrows(), 'CountException', 'TypeScript::CountException', \&TypeScript::CountException::CountException, 'APPEL', 2 ],
     [ Ident::Alias_ParameterShadow(), 'CountVariable', 'TypeScript::CountVariable', \&TypeScript::CountVariable::CountVariable, 'APPEL', 2 ],
     [ Ident::Alias_BadReturnStatement(), 'CountFunction', 'TypeScript::CountFunction', \&TypeScript::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_SmallSwitchCase(), 'CountSwitch', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountSwitch, 'APPEL', 2 ],
     [ Ident::Alias_OptionalProperty(), 'CountAttribute', 'TypeScript::CountClass', \&TypeScript::CountClass::CountAttribute, 'APPEL', 2 ],
     [ Ident::Alias_TotalAttributes(), 'CountAttribute', 'TypeScript::CountClass', \&TypeScript::CountClass::CountAttribute, 'APPEL', 2 ],
     [ Ident::Alias_Throw(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Let(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Const(), 'CountKeywords', 'TypeScript::CountTypeScript', \&TypeScript::CountTypeScript::CountKeywords, 'APPEL', 2 ],

);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
     # [ Ident::Alias_VG(), 'CountVG', 'Java::CountJava', \&Java::CountJava::CountVG, 'APPEL', 1 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
