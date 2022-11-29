package C_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_AndOr(), 'CountAndOr', 'CountAndOr', \&CountAndOr::CountAndOr, 'APPEL', 1 ],
     [ Ident::Alias_AsmLines(), 'CountAsm', 'CountAsm', \&CountAsm::CountAsm, 'APPEL', 1 ],
     [ Ident::Alias_AssignmentsInConditionalExpr(), 'CountAssignmentsInConditionalExpr', 'CountAssignmentsInConditionalExpr', \&CountAssignmentsInConditionalExpr::CountAssignmentsInConditionalExpr, 'APPEL', 1 ],
     [ Ident::Alias_BadSpacing(), 'CountBadSpacing', 'CountBadSpacing', \&CountBadSpacing::CountBadSpacing, 'APPEL', 1 ],
     [ Ident::Alias_BasicTypeUses(), 'Count_C_BasicTypeUses', 'CountBasicTypeUses', \&CountBasicTypeUses::Count_C_BasicTypeUses, 'APPEL', 1 ],
     [ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
     [ Ident::Alias_Break(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
     [ Ident::Alias_MultipleBreakLoops(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
     [ Ident::Alias_MissingBreakInSwitch(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
     [ Ident::Alias_WithTooMuchParametersMethods(), 'Count_Parameters', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Parameters, 'APPEL', 1 ],
     [ Ident::Alias_TotalParameters(), 'Count_Parameters', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Parameters, 'APPEL', 1 ],
     [ Ident::Alias_ApplicationGlobalVariables(), 'Count_AppGlobalVar', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AppGlobalVar, 'APPEL', 1 ],
     [ Ident::Alias_FileGlobalVariables(), 'Count_FileGlobalVar', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_FileGlobalVar, 'APPEL', 1 ],
     [ Ident::Alias_MultipleDeclarationsInSameStatement(), 'Count_MultipleDeclarationSameLine', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MultipleDeclarationSameLine, 'APPEL', 1 ],
     [ Ident::Alias_AssignmentsInFunctionCall(), 'Count_AssignmentsInFunctionCall', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AssignmentsInFunctionCall, 'APPEL', 1 ],
     [ Ident::Alias_ComplexMethodsLT(), 'Count_ComplexMethods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ComplexMethods, 'APPEL', 1 ],
     [ Ident::Alias_ComplexMethodsHT(), 'Count_ComplexMethods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ComplexMethods, 'APPEL', 1 ],
     [ Ident::Alias_Max_ComplexMethodsVg(), 'Count_ComplexMethods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ComplexMethods, 'APPEL', 1 ],
     [ Ident::Alias_UninitializedLocalVariables(), 'Count_MultipleDeclarationSameLine', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MultipleDeclarationSameLine, 'APPEL', 1 ],
     [ Ident::Alias_MultipleReturnFunctionsMethods(), 'Count_MultipleReturnFunctionsMethods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MultipleReturnFunctionsMethods, 'APPEL', 1 ],
     [ Ident::Alias_VariableArgumentMethods(), 'Count_VarArg', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_VarArg, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodImplementations(), 'Count_C_Functions', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_C_Functions, 'APPEL', 1 ],
     [ Ident::Alias_ShortFunctionNamesLT(), 'Count_FunctionNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_FunctionNaming, 'APPEL', 1 ],
     [ Ident::Alias_ShortFunctionNamesHT(), 'Count_FunctionNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_FunctionNaming, 'APPEL', 1 ],
     [ Ident::Alias_CommentedOutCode(), 'CountCommentedOutCode', 'CountCommentedOutCode', \&CountCommentedOutCode::CountCommentedOutCode, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     [ Ident::Alias_BlankLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_CommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_AlphaNumCommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode_SansPrepro', 'CountCommun', \&CountCommun::CountLinesOfCode_SansPrepro, 'APPEL', 1 ],
     [ Ident::Alias_ComplexConditions(), 'CountComplexConditions', 'CountComplexConditions', \&CountComplexConditions::CountComplexConditions, 'APPEL', 1 ],
     [ Ident::Alias_ComplexOperands(), 'CountComplexOperands', 'CountComplexOperands', \&CountComplexOperands::CountComplexOperands, 'APPEL', 1 ],
     [ Ident::Alias_IncrDecrOperatorComplexUses(), 'CountComplexUsesOfIncrDecrOperator', 'CountComplexUsesOfIncrDecrOperator', \&CountComplexUsesOfIncrDecrOperator::CountComplexUsesOfIncrDecrOperator, 'APPEL', 1 ],
     [ Ident::Alias_Union(), 'CountUnionStruct', 'CountC', \&CountC::CountUnionStruct, 'APPEL', 1 ],
     [ Ident::Alias_StructDefinitions(), 'CountUnionStruct', 'CountC', \&CountC::CountUnionStruct, 'APPEL', 1 ],
     [ Ident::Alias_CPPKeywords(), 'CountCPPKeyWords', 'CountC', \&CountC::CountCPPKeyWords, 'APPEL', 1 ],
     [ Ident::Alias_UnparenthesedParamMacros(), 'CountMacrosParamSansParenthese', 'CountC', \&CountC::CountMacrosParamSansParenthese, 'APPEL', 1 ],
     [ Ident::Alias_BadMacroNames(), 'CountMacroNaming', 'CountC', \&CountC::CountMacroNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadPtrAccess(), 'CountBadPtrAccess', 'CountC', \&CountC::CountBadPtrAccess, 'APPEL', 1 ],
     [ Ident::Alias_BugPatterns(), 'CountBugPatterns', 'CountC', \&CountC::CountBugPatterns, 'APPEL', 1 ],
     [ Ident::Alias_Include(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_While(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_For(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Continue(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Switch(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Default(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Goto(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Exit(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Malloc(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Calloc(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Strdup(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Free(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Open(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Close(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Fopen(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Fclose(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Else(), 'CountKeywords', 'CountC', \&CountC::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_MultipleAssignments(), 'CountMultipleAssignments', 'CountC', \&CountC::CountMultipleAssignments, 'APPEL', 1 ],
     [ Ident::Alias_RiskyFunctionCalls(), 'CountRiskyFunctionCalls', 'CountC', \&CountC::CountRiskyFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_HardCodedPaths(), 'CountHardCodedPaths', 'CountHardCodedPaths', \&CountHardCodedPaths::CountHardCodedPaths, 'APPEL', 1 ],
     [ Ident::Alias_IfPrepro(), 'CountIfPrepro', 'CountIfPrepro', \&CountIfPrepro::CountIfPrepro, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines100(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines132(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_MagicNumbers(), 'CountMagicNumbers', 'CountMagicNumbers', \&CountMagicNumbers::CountMagicNumbers, 'APPEL', 1 ],
     [ Ident::Alias_MissingBraces(), 'CountMissingBraces', 'CountMissingBraces', \&CountMissingBraces::CountMissingBraces, 'APPEL', 1 ],
     [ Ident::Alias_MissingBreakInCasePath(), 'CountMissingBreakInCasePath', 'CountMissingBreakInCasePath', \&CountMissingBreakInCasePath::CountMissingBreakInCasePath, 'APPEL', 1 ],
     [ Ident::Alias_MissingDefaults(), 'CountMissingDefaults', 'CountMissingDefaults', \&CountMissingDefaults::CountMissingDefaults, 'APPEL', 0 ],
     [ Ident::Alias_MissingFinalElses(), 'CountMissingFinalElses', 'CountMissingFinalElses', \&CountMissingFinalElses::CountMissingFinalElses, 'APPEL', 1 ],
     [ Ident::Alias_MultipleStatementsOnSameLine(), 'CountMultInst', 'CountMultInst', \&CountMultInst::CountMultInst, 'APPEL', 1 ],
     [ Ident::Alias_Pragmas(), 'CountPragmas', 'CountPragmas', \&CountPragmas::CountPragmas, 'APPEL', 1 ],
     [ Ident::Alias_SqlLines(), 'CountSql', 'CountSql', \&CountSql::CountSql, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     [ Ident::Alias_TernaryOperators(), 'CountTernaryOp', 'CountTernaryOp', \&CountTernaryOp::CountTernaryOp, 'APPEL', 1 ],
     [ Ident::Alias_UncommentedEmptyStmts(), 'CountUncommentedEmptyStmts', 'CountUncommentedEmptyStmts', \&CountUncommentedEmptyStmts::CountUncommentedEmptyStmts, 'APPEL', 0 ],
     [ Ident::Alias_Words(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 1 ],
     [ Ident::Alias_DistinctWords(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 1 ],

);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
     [ Ident::Alias_VG(), 'CountVG', 'CountC', \&CountC::CountVG, 'APPEL', 1 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
