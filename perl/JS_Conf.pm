package JS_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 2 ],
     [ Ident::Alias_FunctionCallInLoopTest(), 'CountLoop', 'JS::CountLoop', \&JS::CountLoop::CountLoop, 'APPEL', 2 ],
     [ Ident::Alias_ForinLoop(), 'CountLoop', 'JS::CountLoop', \&JS::CountLoop::CountLoop, 'APPEL', 2 ],
     [ Ident::Alias_While(), 'CountLoop', 'JS::CountLoop', \&JS::CountLoop::CountLoop, 'APPEL', 2 ],
     [ Ident::Alias_Do(), 'CountLoop', 'JS::CountLoop', \&JS::CountLoop::CountLoop, 'APPEL', 2 ],
     [ Ident::Alias_For(), 'CountLoop', 'JS::CountLoop', \&JS::CountLoop::CountLoop, 'APPEL', 2 ],
     [ Ident::Alias_UnecessaryNestedObjectResolution(), 'CountArtifact', 'JS::CountJS', \&JS::CountJS::CountArtifact, 'APPEL', 2 ],
     [ Ident::Alias_MissingIdenticalOperator(), 'CountCondition', 'JS::CountCondition', \&JS::CountCondition::CountCondition, 'APPEL', 2 ],
     [ Ident::Alias_ComplexConditions(), 'CountCondition', 'JS::CountCondition', \&JS::CountCondition::CountCondition, 'APPEL', 2 ],
     [ Ident::Alias_AssignmentsInConditionalExpr(), 'CountCondition', 'JS::CountCondition', \&JS::CountCondition::CountCondition, 'APPEL', 2 ],
     [ Ident::Alias_Conditions(), 'CountCondition', 'JS::CountCondition', \&JS::CountCondition::CountCondition, 'APPEL', 2 ],
     [ Ident::Alias_IEConditionalComments(), 'CountIEConditionalComments', 'JS::CountComment', \&JS::CountComment::CountIEConditionalComments, 'APPEL', 1 ],
     [ Ident::Alias_WithinBlocksFunctionsDecl(), 'CountFunction', 'JS::CountFunction', \&JS::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_MisplacedInnerFuncDecl(), 'CountFunction', 'JS::CountFunction', \&JS::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_BadSpacingInFuncDecl(), 'CountFunction', 'JS::CountFunction', \&JS::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_MisplacedFunctionDecl(), 'CountMisplacedFunctionDecl', 'JS::CountFunction', \&JS::CountFunction::CountMisplacedFunctionDecl, 'APPEL', 2 ],
     [ Ident::Alias_MissingImmediateFuncCallWrapping(), 'CountMissingImmediateFuncCallWrapping', 'JS::CountFunction', \&JS::CountFunction::CountMissingImmediateFuncCallWrapping, 'APPEL', 2 ],
     [ Ident::Alias_TooDepthArtifact(), 'CountFunction', 'JS::CountFunction', \&JS::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_MisplacedVarStatement(), 'CountFunction', 'JS::CountFunction', \&JS::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_FunctionDeclarations(), 'CountFunction', 'JS::CountFunction', \&JS::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_FunctionExpressions(), 'CountFunction', 'JS::CountFunction', \&JS::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_ComplexArtifact(), 'CountFunction', 'JS::CountFunction', \&JS::CountFunction::CountFunction, 'APPEL', 2 ],
#     [ 'Thres_2', 'CountFunction', 'JS::CountFunction', \&JS::CountFunction::CountFunction, 'APPEL', 2 ],
#     [ 'Thres_3', 'CountFunction', 'JS::CountFunction', \&JS::CountFunction::CountFunction, 'APPEL', 2 ],
#     [ 'Thres_4', 'CountFunction', 'JS::CountFunction', \&JS::CountFunction::CountFunction, 'APPEL', 2 ],
     [ Ident::Alias_MultilineString(), 'CountString', 'JS::CountString', \&JS::CountString::CountString, 'APPEL', 2 ],
     [ Ident::Alias_UnexpectedDoubleQuoteStr(), 'CountString', 'JS::CountString', \&JS::CountString::CountString, 'APPEL', 2 ],
     [ Ident::Alias_String(), 'CountString', 'JS::CountString', \&JS::CountString::CountString, 'APPEL', 2 ],
     [ Ident::Alias_ShortFunctionNamesLT(), 'CountNaming', 'JS::CountNaming', \&JS::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_BadFunctionNames(), 'CountNaming', 'JS::CountNaming', \&JS::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_ShortAttributeNamesLT(), 'CountNaming', 'JS::CountNaming', \&JS::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_BadAttributeNames(), 'CountNaming', 'JS::CountNaming', \&JS::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_ShortParameterNamesLT(), 'CountNaming', 'JS::CountNaming', \&JS::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_PublicAttributes(), 'CountNaming', 'JS::CountNaming', \&JS::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_TotalParameters(), 'CountNaming', 'JS::CountNaming', \&JS::CountNaming::CountNaming, 'APPEL', 2 ],
     [ Ident::Alias_ShortGlobalNamesLT(), 'CountVariable', 'JS::CountVariable', \&JS::CountVariable::CountVariable, 'APPEL', 2 ],
     [ Ident::Alias_BadVariableNames(), 'CountVariable', 'JS::CountVariable', \&JS::CountVariable::CountVariable, 'APPEL', 2 ],
     [ Ident::Alias_BadSelectorCaching(), 'CountVariable', 'JS::CountVariable', \&JS::CountVariable::CountVariable, 'APPEL', 2 ],
     [ Ident::Alias_ImpliedGlobalVar(), 'CountVariable', 'JS::CountVariable', \&JS::CountVariable::CountVariable, 'APPEL', 2 ],
     [ Ident::Alias_MultipleDeclarationsInSameStatement(), 'CountMultipleDeclarations', 'JS::CountVariable', \&JS::CountVariable::CountMultipleDeclarations, 'APPEL', 2 ],
#     [ Ident::Alias_VariableDeclarations(), 'CountMultipleDeclarations', 'JS::CountVariable', \&JS::CountVariable::CountMultipleDeclarations, 'APPEL', 2 ],
     [ Ident::Alias_BadConstructorNames(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_BadArrayDeclaration(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_BadObjectDeclaration(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_ObjectDeclaration(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_MultilineReturn(), 'CountMultilineReturn', 'JS::CountJS', \&JS::CountJS::CountMultilineReturn, 'APPEL', 2 ],
     [ Ident::Alias_MissingScalarType(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_ArgumentCallee(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_UnexpectedThis(), 'CountArtifact', 'JS::CountJS', \&JS::CountJS::CountArtifact, 'APPEL', 2 ],
     [ Ident::Alias_With(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Break(), 'CountBreakInLoop', 'JS::CountJS', \&JS::CountJS::CountBreakInLoop, 'APPEL', 2 ],
     [ Ident::Alias_Continue(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Evaluate(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_BadSetTimeout(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_BadSetInterval(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Eval(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_If(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Else(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Case(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_Return(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_TernaryOperators(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_AndOr(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_VariableDeclarations(), 'CountKeywords', 'JS::CountJS', \&JS::CountJS::CountKeywords, 'APPEL', 2 ],
     [ Ident::Alias_MissingBreakInCasePath(), 'CountSwitch', 'JS::CountJS', \&JS::CountJS::CountSwitch, 'APPEL', 2 ],
     [ Ident::Alias_MagicNumbers(), 'CountMissingInstructionSeparator', 'JS::CountJS', \&JS::CountJS::CountMissingInstructionSeparator, 'APPEL', 2 ],
     [ Ident::Alias_MissingBraces(), 'CountMissingInstructionSeparator', 'JS::CountJS', \&JS::CountJS::CountMissingInstructionSeparator, 'APPEL', 2 ],
     [ Ident::Alias_MissingSemicolon(), 'CountMissingInstructionSeparator', 'JS::CountJS', \&JS::CountJS::CountMissingInstructionSeparator, 'APPEL', 2 ],
     [ Ident::Alias_BadSpacing(), 'CountBadSpacing', 'JS::CountJS', \&JS::CountJS::CountBadSpacing, 'APPEL', 2 ],
     [ Ident::Alias_UnauthorizedPrototypeModification(), 'CountUnauthorizedPrototypeModification', 'JS::CountJS', \&JS::CountJS::CountUnauthorizedPrototypeModification, 'APPEL', 2 ],
     [ Ident::Alias_Words(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 2 ],
     [ Ident::Alias_DistinctWords(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 2 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 2 ],
     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode_agglo', 'CountCommun', \&CountCommun::CountLinesOfCode_agglo, 'APPEL', 2 ],
     [ Ident::Alias_CommentLines(), 'CountLinesOfCode_agglo', 'CountCommun', \&CountCommun::CountLinesOfCode_agglo, 'APPEL', 2 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs_agglo', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs_agglo, 'APPEL', 2 ],
);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
#     [ Ident::Alias_VG(), 'CountVG', 'CountJS', \&CountJS::CountVG, 'APPEL', 2 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
