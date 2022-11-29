package Swift_Conf;

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
     [ Ident::Alias_AndOr(), 'CountKeywords', 'Swift::CountSwift', \&Swift::CountSwift::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountKeywords', 'Swift::CountSwift', \&Swift::CountSwift::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_While(), 'CountKeywords', 'Swift::CountSwift', \&Swift::CountSwift::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_For(), 'CountKeywords', 'Swift::CountSwift', \&Swift::CountSwift::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CountKeywords', 'Swift::CountSwift', \&Swift::CountSwift::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Default(), 'CountKeywords', 'Swift::CountSwift', \&Swift::CountSwift::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Switch(), 'CountKeywords', 'Swift::CountSwift', \&Swift::CountSwift::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Catch(), 'CountKeywords', 'Swift::CountSwift', \&Swift::CountSwift::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     [ Ident::Alias_FunctionImplementations(), 'CountFunction', 'Swift::CountFunction', \&Swift::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_FunctionExpressions(), 'CountFunction', 'Swift::CountFunction', \&Swift::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_MethodImplementations(), 'CountFunction', 'Swift::CountFunction', \&Swift::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_EmptyMethods(), 'CountFunction', 'Swift::CountFunction', \&Swift::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_EmptyClasses(), 'CountClass', 'Swift::CountClass', \&Swift::CountClass::CountClass, 'APPEL', 1 ],
     [ Ident::Alias_MissingFinalElses(), 'CountCondition', 'Swift::CountCondition', \&Swift::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_DangerousTry(), 'CountException', 'Swift::CountException', \&Swift::CountException::CountException, 'APPEL', 1 ],
     [ Ident::Alias_DuplicatedString(), 'CountString', 'Swift::CountString', \&Swift::CountString::CountString, 'APPEL', 1 ],
     [ Ident::Alias_BadIncDecUse(), 'CountSwift', 'Swift::CountSwift', \&Swift::CountSwift::CountSwift, 'APPEL', 1 ],
     [ Ident::Alias_UnexpectedCast(), 'CountSwift', 'Swift::CountSwift', \&Swift::CountSwift::CountSwift, 'APPEL', 1 ],
     [ Ident::Alias_MultipleReturnFunctionsMethods(), 'CountFunction', 'Swift::CountFunction', \&Swift::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_WithTooMuchParametersMethods(), 'CountFunction', 'Swift::CountFunction', \&Swift::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_UnexpectedBreakStatement(), 'CountCondition', 'Swift::CountCondition', \&Swift::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_NestedTernary(), 'CountCondition', 'Swift::CountCondition', \&Swift::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_SmallSwitchCase(), 'CountCondition', 'Swift::CountCondition', \&Swift::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_BadClassNames(), 'CountNaming', 'Swift::CountNaming', \&Swift::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadAttributeNames(), 'CountNaming', 'Swift::CountNaming', \&Swift::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_MultipleDeclarationsInSameStatement(), 'CountVariable', 'Swift::CountVariable', \&Swift::CountVariable::CountVariable, 'APPEL', 1 ],
     [ Ident::Alias_BadEnumNames(), 'CountNaming', 'Swift::CountNaming', \&Swift::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadProtocolNames(), 'CountNaming', 'Swift::CountNaming', \&Swift::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadConstantNames(), 'CountNaming', 'Swift::CountNaming', \&Swift::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_FieldNameIsClassName(), 'CountNaming', 'Swift::CountNaming', \&Swift::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_ClassNameLengthAverage(), 'CountNaming', 'Swift::CountNaming', \&Swift::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_ParameterNameLengthAverage(), 'CountNaming', 'Swift::CountNaming', \&Swift::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_AttributeNameLengthAverage(), 'CountNaming', 'Swift::CountNaming', \&Swift::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_RoutineNameLengthAverage(), 'CountNaming', 'Swift::CountNaming', \&Swift::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_OnlyRethrowingCatches(), 'CountException', 'Swift::CountException', \&Swift::CountException::CountException, 'APPEL', 1 ],
     [ Ident::Alias_BadReturnStatement(), 'CountFunction', 'Swift::CountFunction', \&Swift::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_UnusedParameters(), 'CountFunction', 'Swift::CountFunction', \&Swift::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_ImplicitReturn(), 'CountFunction', 'Swift::CountFunction', \&Swift::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_NestedClosure(), 'CountFunction', 'Swift::CountFunction', \&Swift::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_ToManyNestedControlFlow(), 'CountSwift', 'Swift::CountSwift', \&Swift::CountSwift::CountSwift, 'APPEL', 1 ],
     [ Ident::Alias_DeadCode(), 'CountSwift', 'Swift::CountSwift', \&Swift::CountSwift::CountSwift, 'APPEL', 1 ],
     [ Ident::Alias_MisplacedParam(), 'CountFunction', 'Swift::CountFunction', \&Swift::CountFunction::CountFunction, 'APPEL', 1 ],
     [ Ident::Alias_HardCodedPaths(), 'CountString', 'Swift::CountString', \&Swift::CountString::CountString, 'APPEL', 1 ],
     [ Ident::Alias_HardCodedUrl(), 'CountString', 'Swift::CountString', \&Swift::CountString::CountString, 'APPEL', 1 ],
     [ Ident::Alias_BadParameterNames(), 'CountNaming', 'Swift::CountNaming', \&Swift::CountNaming::CountNaming, 'APPEL', 1 ],
     [ Ident::Alias_SwitchLengthAverage(), 'CountCondition', 'Swift::CountCondition', \&Swift::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_CaseLengthAverage(), 'CountCondition', 'Swift::CountCondition', \&Swift::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_ComplexConditions(), 'CountCondition', 'Swift::CountCondition', \&Swift::CountCondition::CountCondition, 'APPEL', 1 ],
     [ Ident::Alias_TernaryOperators(), 'CountCondition', 'Swift::CountCondition', \&Swift::CountCondition::CountCondition, 'APPEL', 1 ],

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
