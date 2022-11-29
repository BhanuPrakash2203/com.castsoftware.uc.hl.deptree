package Clojure_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode', 'CountCommun', \&CountCommun::CountLinesOfCode, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     [ Ident::Alias_BlankLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_CommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_AlphaNumCommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_TabInsideIndentation(), 'CountTabInsideIndentation', 'Clojure::CountIndentation', \&Clojure::CountIndentation::CountTabInsideIndentation, 'APPEL', 1 ],
     [ Ident::Alias_FormBodyIndentation(), 'CountFormIndentation', 'Clojure::CountIndentation', \&Clojure::CountIndentation::CountFormIndentation, 'APPEL', 1 ],
     [ Ident::Alias_ParameterIndentation(), 'CountFormIndentation', 'Clojure::CountIndentation', \&Clojure::CountIndentation::CountFormIndentation, 'APPEL', 1 ],
     [ Ident::Alias_ParenthesesSpacing(), 'CountParenthesesSpacing', 'Clojure::CountClojure', \&Clojure::CountClojure::CountParenthesesSpacing, 'APPEL', 1 ],
     [ Ident::Alias_TrailingParentheses(), 'CountTrailingParentheses', 'Clojure::CountClojure', \&Clojure::CountClojure::CountTrailingParentheses, 'APPEL', 1 ],
     [ Ident::Alias_OperatorCouldBeFunction(), 'CountList', 'Clojure::CountClojure', \&Clojure::CountClojure::CountList, 'APPEL', 1 ],
     [ Ident::Alias_UselessFullSyntaxMetadata(), 'CountUselessFullSyntaxMetadata', 'Clojure::CountClojure', \&Clojure::CountClojure::CountUselessFullSyntaxMetadata, 'APPEL', 1 ],
     [ Ident::Alias_BadStringAsHaskKey(), 'CountMap', 'Clojure::CountClojure', \&Clojure::CountClojure::CountMap, 'APPEL', 1 ],
     [ Ident::Alias_DeprecatedReferenceInNamespace(), 'CountNamespace', 'Clojure::CountNamespace', \&Clojure::CountNamespace::CountNamespace, 'APPEL', 1 ],
     [ Ident::Alias_BadDeclarationOrder(), 'CountNamespace', 'Clojure::CountNamespace', \&Clojure::CountNamespace::CountNamespace, 'APPEL', 1 ],
     [ Ident::Alias_MissingIdiomaticAliases(), 'CountNamespace', 'Clojure::CountNamespace', \&Clojure::CountNamespace::CountNamespace, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodImplementations(), 'CountFunction', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_MethodsLengthAverage(), 'CountFunction', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_LongArtifact(), 'CountFunction', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_WithTooMuchParametersMethods(), 'CountFunction', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_ParametersAverage(), 'CountFunction', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_GlobalDefInsideFunctions(), 'CountFunction', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_BadVariableUpdate(), 'CountVariable', 'Clojure::CountVariable', \&Clojure::CountVariable::CountVariable, 'APPEL', 1 ],
     [ Ident::Alias_UnexpectedConditionalLet(), 'CountVariable', 'Clojure::CountVariable', \&Clojure::CountVariable::CountVariable, 'APPEL', 1 ],
     [ Ident::Alias_ShortVarName(), 'CountVariable', 'Clojure::CountVariable', \&Clojure::CountVariable::CountVariable, 'APPEL', 1 ],
     [ Ident::Alias_VariableNameLengthAverage(), 'CountVariable', 'Clojure::CountVariable', \&Clojure::CountVariable::CountVariable, 'APPEL', 1 ],
     [ Ident::Alias_GlobalVariableHidding(), 'CountVariable', 'Clojure::CountVariable', \&Clojure::CountVariable::CountVariable, 'APPEL', 1 ],
     [ Ident::Alias_IfShouldBeWhen(), 'CountIf', 'Clojure::CountCondition', \&Clojure::CountCondition::CountIf, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountIf', 'Clojure::CountCondition', \&Clojure::CountCondition::CountIf, 'APPEL', 1 ],
     [ Ident::Alias_InvertedLogic(), 'CountIf', 'Clojure::CountCondition', \&Clojure::CountCondition::CountIf, 'APPEL', 1 ],
     [ Ident::Alias_ComplexConditions(), 'CountIf', 'Clojure::CountCondition', \&Clojure::CountCondition::CountIf, 'APPEL', 1 ],
     [ Ident::Alias_MissingDefaults(), 'CountSwitch', 'Clojure::CountCondition', \&Clojure::CountCondition::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_BadSwitchForm(), 'CountSwitch', 'Clojure::CountCondition', \&Clojure::CountCondition::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CountSwitch', 'Clojure::CountCondition', \&Clojure::CountCondition::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_Default(), 'CountSwitch', 'Clojure::CountCondition', \&Clojure::CountCondition::CountSwitch, 'APPEL', 1 ],
     [ Ident::Alias_LongFunctionLiteral(), 'CountFunctionLiteral', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunctionLiteral, 'APPEL', 1 ],
     [ Ident::Alias_BadArityIndentation(), 'CountFunction', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_BadMultiArityOrder(), 'CountFunction', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_ParameterShadow(), 'CountFunction', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_BodyBeginOnSameLineThanParams(), 'CountFunction', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunction, 'APPEL', 1 ],
     
     [ Ident::Alias_TooDepthArtifact(), 'CountFunction', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_ArtifactDepthAverage(), 'CountFunction', 'Clojure::CountFunction', \&Clojure::CountFunction::CountFunction, 'APPEL', 1 ],
     
     [ Ident::Alias_MissingSpaceAfterCommentDelimiter(), 'CountComment', 'Clojure::CountComment', \&Clojure::CountComment::CountComment, 'APPEL', 1 ],
     [ Ident::Alias_CommentedOutCode(), 'CountCommentedOutCode', 'Clojure::CountComment', \&Clojure::CountComment::CountCommentedOutCode, 'APPEL', 1 ],
     [ Ident::Alias_While(), 'CountWhile', 'Clojure::CountLoop', \&Clojure::CountLoop::CountWhile, 'APPEL', 1 ],
     [ Ident::Alias_Loop(), 'CountLoop', 'Clojure::CountLoop', \&Clojure::CountLoop::CountLoop, 'APPEL', 1 ],
     [ Ident::Alias_BadVariableNames(), 'CountNaming', 'Clojure::CountNaming', \&Clojure::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadFunctionNames(), 'CountNaming', 'Clojure::CountNaming', \&Clojure::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadProtocolNames(), 'CountNaming', 'Clojure::CountNaming', \&Clojure::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadTypeNames(), 'CountNaming', 'Clojure::CountNaming', \&Clojure::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadConversionFunctionNames(), 'CountNaming', 'Clojure::CountNaming', \&Clojure::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadDynamicVarNames(), 'CountNaming', 'Clojure::CountNaming', \&Clojure::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadDeclarationOrder(), 'CountNaming', 'Clojure::CountNaming', \&Clojure::CountNaming::CountNaming, 'APPEL', 1 ],
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
