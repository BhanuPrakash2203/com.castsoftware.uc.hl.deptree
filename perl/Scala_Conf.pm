package Scala_Conf;

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
    [ Ident::Alias_DuplicatedString(), 'CountString', 'Scala::CountString', \&Scala::CountString::CountString, 'APPEL', 1 ],
    [ Ident::Alias_EmptyMethods(), 'CountFunction', 'Scala::CountFunction', \&Scala::CountFunction::CountFunction, 'APPEL', 1 ],
    [ Ident::Alias_DuplicatedCondition(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_DeadCode(), 'CountFunction', 'Scala::CountFunction', \&Scala::CountFunction::CountFunction, 'APPEL', 1 ],
    [ Ident::Alias_BadClassNames(), 'CountNaming', 'Scala::CountNaming', \&Scala::CountNaming::CountNaming, 'APPEL', 1 ],
    [ Ident::Alias_BadMethodNames(), 'CountNaming', 'Scala::CountNaming', \&Scala::CountNaming::CountNaming, 'APPEL', 1 ],
    [ Ident::Alias_BadAttributeNames(), 'CountNaming', 'Scala::CountNaming', \&Scala::CountNaming::CountNaming, 'APPEL', 1 ],
    [ Ident::Alias_WithTooMuchParametersMethods(), 'CountFunction', 'Scala::CountFunction', \&Scala::CountFunction::CountFunction, 'APPEL', 1 ],
    [ Ident::Alias_UnusedParameters(), 'CountFunction', 'Scala::CountFunction', \&Scala::CountFunction::CountFunction, 'APPEL', 1 ],
    [ Ident::Alias_ToManyNestedControlFlow(), 'CountScala', 'Scala::CountScala', \&Scala::CountScala::CountScala, 'APPEL', 1 ],
    [ Ident::Alias_MissingFinalElses(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_SwitchNested(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_MultipleStatementsOnSameLine(), 'CountScala', 'Scala::CountScala', \&Scala::CountScala::CountScala, 'APPEL', 1 ],
    [ Ident::Alias_LargeSwitches(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_BadReturnStatement(), 'CountScala', 'Scala::CountScala', \&Scala::CountScala::CountScala, 'APPEL', 1 ],
    [ Ident::Alias_MissingBraces(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_TotalParameters(), 'CountFunction', 'Scala::CountFunction', \&Scala::CountFunction::CountFunction, 'APPEL', 1 ],
    [ Ident::Alias_ClassImplementations(), 'CountClass', 'Scala::CountClass', \&Scala::CountClass::CountClass, 'APPEL', 1 ],
    [ Ident::Alias_ObjectDeclaration(), 'CountClass', 'Scala::CountClass', \&Scala::CountClass::CountClass, 'APPEL', 1 ],
    [ Ident::Alias_Interface(), 'CountClass', 'Scala::CountClass', \&Scala::CountClass::CountClass, 'APPEL', 1 ],
    [ Ident::Alias_If(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_For(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_While(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_Do(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_Case(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_MethodImplementations(), 'CountFunction', 'Scala::CountFunction', \&Scala::CountFunction::CountFunction, 'APPEL', 1 ],
    [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
    [ Ident::Alias_PublicAttributes(), 'CountVariable', 'Scala::CountVariable', \&Scala::CountVariable::CountVariable, 'APPEL', 1 ],
    [ Ident::Alias_LongElsif(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_InvertedLogic(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_CollapsibleIf(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_CompareToNull(), 'CountScala', 'Scala::CountScala', \&Scala::CountScala::CountScala, 'APPEL', 1 ],
    [ Ident::Alias_BadAttributeNames(), 'CountNaming', 'Scala::CountNaming', \&Scala::CountNaming::CountNaming, 'APPEL', 1 ],
    [ Ident::Alias_ShortClassNamesLT(), 'CountNaming', 'Scala::CountNaming', \&Scala::CountNaming::CountNaming, 'APPEL', 1 ],
    [ Ident::Alias_ShortMethodNamesLT(), 'CountNaming', 'Scala::CountNaming', \&Scala::CountNaming::CountNaming, 'APPEL', 1 ],
    [ Ident::Alias_ShortAttributeNamesLT(), 'CountNaming', 'Scala::CountNaming', \&Scala::CountNaming::CountNaming, 'APPEL', 1 ],
    [ Ident::Alias_ShortParameterNamesLT(), 'CountNaming', 'Scala::CountNaming', \&Scala::CountNaming::CountNaming, 'APPEL', 1 ],
    [ Ident::Alias_ClassNameLengthAverage(), 'CountNaming', 'Scala::CountNaming', \&Scala::CountNaming::CountNaming, 'APPEL', 1 ],
    [ Ident::Alias_MethodNameLengthAverage(), 'CountNaming', 'Scala::CountNaming', \&Scala::CountNaming::CountNaming, 'APPEL', 1 ],
    [ Ident::Alias_AttributeNameLengthAverage(), 'CountNaming', 'Scala::CountNaming', \&Scala::CountNaming::CountNaming, 'APPEL', 1 ],
    [ Ident::Alias_ParameterNameLengthAverage(), 'CountNaming', 'Scala::CountNaming', \&Scala::CountNaming::CountNaming, 'APPEL', 1 ],
    [ Ident::Alias_TotalAttributes(), 'CountClass', 'Scala::CountClass', \&Scala::CountClass::CountClass, 'APPEL', 1 ],
    [ Ident::Alias_Default(), 'CountScala', 'Scala::CountScala', \&Scala::CountScala::CountScala, 'APPEL', 1 ],
    [ Ident::Alias_ComplexConditions(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_ConditionComplexityAverage(), 'CountCondition', 'Scala::CountCondition', \&Scala::CountCondition::CountCondition, 'APPEL', 1 ],
    [ Ident::Alias_Instanceof(), 'CountScala', 'Scala::CountScala', \&Scala::CountScala::CountScala, 'APPEL', 1 ],
    [ Ident::Alias_MagicNumbers(), 'CountScala', 'Scala::CountScala', \&Scala::CountScala::CountScala, 'APPEL', 1 ],
    [ Ident::Alias_MissingDefaults(), 'CountScala', 'Scala::CountScala', \&Scala::CountScala::CountScala, 'APPEL', 1 ],
    [ Ident::Alias_EmptyCatches(), 'CountScala', 'Scala::CountScala', \&Scala::CountScala::CountScala, 'APPEL', 1 ],
    [ Ident::Alias_GenericCatches(), 'CountScala', 'Scala::CountScala', \&Scala::CountScala::CountScala, 'APPEL', 1 ],

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
