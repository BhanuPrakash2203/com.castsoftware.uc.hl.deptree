package Go_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode', 'CountCommun', \&CountCommun::CountLinesOfCode, 'APPEL', 1 ],
     [ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     [ Ident::Alias_BlankLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_CommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_AlphaNumCommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_VariableDeclarations(), 'CountVariable', 'Go::CountVariable', \&Go::CountVariable::CountVariable, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountKeywords', 'Go::CountGo', \&Go::CountGo::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Break(), 'CountKeywords', 'Go::CountGo', \&Go::CountGo::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Continue(), 'CountKeywords', 'Go::CountGo', \&Go::CountGo::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_For(), 'CountKeywords', 'Go::CountGo', \&Go::CountGo::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CountKeywords', 'Go::CountGo', \&Go::CountGo::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Return(), 'CountKeywords', 'Go::CountGo', \&Go::CountGo::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_DuplicatedString(), 'CountString', 'Go::CountString', \&Go::CountString::CountString, 'APPEL', 1 ],
     [ Ident::Alias_EmptyMethods(), 'CountFunction', 'Go::CountFunction', \&Go::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_TotalParameters(), 'CountFunction', 'Go::CountFunction', \&Go::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodImplementations(), 'CountFunction', 'Go::CountFunction', \&Go::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_FunctionImplementations(), 'CountFunction', 'Go::CountFunction', \&Go::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousOperator(), 'CountGo', 'Go::CountGo', \&Go::CountGo::CountGo, 'APPEL', 1 ],
     [ Ident::Alias_DuplicatedCondition(), 'CountCondition', 'Go::CountCondition', \&Go::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_BadValuesOperator(), 'CountGo', 'Go::CountGo', \&Go::CountGo::CountGo, 'APPEL', 1 ],
     [ Ident::Alias_DeadCode(), 'CountFunction', 'Go::CountFunction', \&Go::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_SelfAssigned(), 'CountVariable', 'Go::CountVariable', \&Go::CountVariable::CountVariable, 'APPEL', 1 ],
     [ Ident::Alias_SwitchLengthAverage(), 'CountCondition', 'Go::CountCondition', \&Go::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_LargeSwitches(), 'CountCondition', 'Go::CountCondition', \&Go::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     [ Ident::Alias_EmptyStatementBloc(), 'CountGo', 'Go::CountGo', \&Go::CountGo::CountGo, 'APPEL', 1 ],
     [ Ident::Alias_WithTooMuchParametersMethods(), 'CountFunction', 'Go::CountFunction', \&Go::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_InvertedLogic(), 'CountGo', 'Go::CountGo', \&Go::CountGo::CountGo, 'APPEL', 1 ],
     [ Ident::Alias_BadVariableNames(), 'CountNaming', 'Go::CountNaming', \&Go::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadFunctionNames(), 'CountNaming', 'Go::CountNaming', \&Go::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadMethodNames(), 'CountNaming', 'Go::CountNaming', \&Go::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadParameterNames(), 'CountNaming', 'Go::CountNaming', \&Go::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_SwitchNested(), 'CountCondition', 'Go::CountCondition', \&Go::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_MissingDefaults(), 'CountCondition', 'Go::CountCondition', \&Go::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_ComplexConditions(), 'CountCondition', 'Go::CountCondition', \&Go::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_MissingFinalElses(), 'CountCondition', 'Go::CountCondition', \&Go::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_UnconditionalCondition(), 'CountCondition', 'Go::CountCondition', \&Go::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_TooDepthArtifact(), 'CountFunction', 'Go::CountFunction', \&Go::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_OverDepthAverage(), 'CountFunction', 'Go::CountFunction', \&Go::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_MultipleStatementsOnSameLine(), 'CountGo', 'Go::CountGo', \&Go::CountGo::CountGo, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_CaseLengthAverage(), 'CountGo', 'Go::CountGo', \&Go::CountGo::CountGo, 'APPEL', 1 ],
     [ Ident::Alias_UnusedParameters(), 'CountFunction', 'Go::CountFunction', \&Go::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_EqualityInLoopCondition(), 'CountCondition', 'Go::CountCondition', \&Go::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_MultipleBreakLoops(), 'CountGo', 'Go::CountGo', \&Go::CountGo::CountGo, 'APPEL', 1 ],
     [ Ident::Alias_LongElsif(), 'CountCondition', 'Go::CountCondition', \&Go::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_GlobalVariables(), 'CountVariable', 'Go::CountVariable', \&Go::CountVariable::CountVariable, 'APPEL', 1 ],
     [ Ident::Alias_CollapsibleIf(), 'CountCondition', 'Go::CountCondition', \&Go::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_InstanciationWithNew(), 'CountGo', 'Go::CountGo', \&Go::CountGo::CountGo, 'APPEL', 1 ],
     [ Ident::Alias_MissingShortVariableDeclaration(), 'CountVariable', 'Go::CountVariable', \&Go::CountVariable::CountVariable, 'APPEL', 1 ],
     [ Ident::Alias_MagicNumbers(), 'CountMagicNumbers', 'CountMagicNumbers', \&CountMagicNumbers::CountMagicNumbers, 'APPEL', 1 ],
     [ Ident::Alias_UnnamedData(), 'CountVariable', 'Go::CountVariable', \&Go::CountVariable::CountVariable, 'APPEL', 1 ],
     [ Ident::Alias_UnnamedData(), 'CountFunction', 'Go::CountFunction', \&Go::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_UnusedNamedReceiver(), 'CountFunction', 'Go::CountFunction', \&Go::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_ShortVarName(), 'CountNaming', 'Go::CountNaming', \&Go::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_ShortFunctionNamesLT(), 'CountNaming', 'Go::CountNaming', \&Go::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_ShortParameterNamesLT(), 'CountNaming', 'Go::CountNaming', \&Go::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_VariableNameLengthAverage(), 'CountNaming', 'Go::CountNaming', \&Go::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_FunctionNameLengthAverage(), 'CountNaming', 'Go::CountNaming', \&Go::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_ParameterNameLengthAverage(), 'CountNaming', 'Go::CountNaming', \&Go::CountNaming::CountNaming, 'APPEL', 1 ],


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
