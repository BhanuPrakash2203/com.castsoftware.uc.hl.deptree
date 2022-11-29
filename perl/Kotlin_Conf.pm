package Kotlin_Conf;

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
     [ Ident::Alias_LongLines120(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     
     [ Ident::Alias_EmptyArtifact(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_UnusedParameters(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_UnusedPrivateMethods(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_UnusedLocalVariables(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_WithUnexpectedBodyFunctions(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],   
     [ Ident::Alias_FunctionImplementations(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],   
     [ Ident::Alias_FunctionExpressions(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],   
     [ Ident::Alias_RoutinesLengthIndicator(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],   
     [ Ident::Alias_LabeledReturnsInLambda(), 'CountLambdaReturn', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountLambdaReturn, 'APPEL', 1 ],
     [ Ident::Alias_LabeledReturnEndingLambda(), 'CountLambdaReturn', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountLambdaReturn, 'APPEL', 1 ],
     
     [ Ident::Alias_UnconditionalCondition(), 'CountConditions', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountConditions, 'APPEL', 1 ],
     [ Ident::Alias_ConditionComplexityAverage(), 'CountConditions', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountConditions, 'APPEL', 1 ],
     [ Ident::Alias_MissingFinalElses(), 'CountIf', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountIf, 'APPEL', 1 ],
     [ Ident::Alias_CollapsibleIf(), 'CountIf', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountIf, 'APPEL', 1 ],
     [ Ident::Alias_LongElsif(), 'CountIf', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountIf, 'APPEL', 1 ],
     [ Ident::Alias_SwitchLengthAverage(), 'CountWhen', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountWhen, 'APPEL', 1 ],
     [ Ident::Alias_MissingDefaults(), 'CountWhen', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountWhen, 'APPEL', 1 ],
     [ Ident::Alias_SmallSwitchCase(), 'CountWhen', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountWhen, 'APPEL', 1 ],
     [ Ident::Alias_SwitchNested(), 'CountWhen', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountWhen, 'APPEL', 1 ],
     [ Ident::Alias_CaseLengthIndicator(), 'CountWhen', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountWhen, 'APPEL', 1 ],
     [ Ident::Alias_BooleanPitfall(), 'CountBadConditionNegation', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountBadConditionNegation, 'APPEL', 1 ],
     [ Ident::Alias_MissingExpressionForm(), 'CountIf', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountIf, 'APPEL', 1 ],
     [ Ident::Alias_MissingExpressionForm(), 'CountWhen', 'Kotlin::CountConditions', \&Kotlin::CountConditions::CountWhen, 'APPEL', 1 ],
     
     [ Ident::Alias_MultipleStatementsOnSameLine(), 'CountKotlin', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountKotlin, 'APPEL', 1 ],
     [ Ident::Alias_ClassNameIsNotFileName(), 'CountKotlin', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountKotlin, 'APPEL', 1 ],
     [ Ident::Alias_DeadCode(), 'CountJumps', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountJumps, 'APPEL', 1 ],
     [ Ident::Alias_TooDepthArtifact(), 'CountDeepArtifact', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountDeepArtifact, 'APPEL', 1 ],
     [ Ident::Alias_UselessTypeSpecification(), 'CountVar', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountVar, 'APPEL', 1 ],
     [ Ident::Alias_BadSpacing(), 'CountBadSpacing', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountBadSpacing, 'APPEL', 1 ],
     [ Ident::Alias_EmptyCatches(), 'CountTryCatches', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountTryCatches, 'APPEL', 1 ],
     [ Ident::Alias_Catch(), 'CountTryCatches', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountTryCatches, 'APPEL', 1 ],
     [ Ident::Alias_NestedTryCatches(), 'CountTryCatches', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountTryCatches, 'APPEL', 1 ],
     [ Ident::Alias_GenericCatches(), 'CountTryCatches', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountTryCatches, 'APPEL', 1 ],
     
     [ Ident::Alias_BadNullableCheck(), 'CountKeywords', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountKeywords, 'APPEL', 1 ],
     
     [ Ident::Alias_BadClassNames(), 'CountClasses', 'Kotlin::CountClasses', \&Kotlin::CountClasses::CountClasses, 'APPEL', 1 ],
     
     [ Ident::Alias_BadConstantNames(), 'CountVar', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountVar, 'APPEL', 1 ],
     [ Ident::Alias_BadVariableNames(), 'CountVar', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountVar, 'APPEL', 1 ],
     [ Ident::Alias_BadAttributeNames(), 'CountVar', 'Kotlin::CountKotlin', \&Kotlin::CountKotlin::CountVar, 'APPEL', 1 ],
     [ Ident::Alias_BadClassNames(), 'CountClasses', 'Kotlin::CountClasses', \&Kotlin::CountClasses::CountClasses, 'APPEL', 1 ],
     [ Ident::Alias_BadFunctionNames(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_BadMethodNames(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_RoutineNameLengthAverage(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_ParametersAverage(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],
     [ Ident::Alias_VgAverage(), 'CountRoutines', 'Kotlin::CountRoutines', \&Kotlin::CountRoutines::CountRoutines, 'APPEL', 1 ],
     
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
