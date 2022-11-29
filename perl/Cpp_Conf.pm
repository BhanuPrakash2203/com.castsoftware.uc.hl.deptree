package Cpp_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

# FIXME : 
# Following mnemo are to be removed (because module CountC_CPP_FunctionsMethodsAttributes is to be removed)
#	WithTooMuchParametersMethods
#	FileGlobalVariables
#	MultipleDeclarationsInSameStatement
#	ShortAttributeNamesHT
#	BadDeclarationOrder
#	ShortClassNamesHT
#	GlobalDefinitions
#	ShortMethodNamesHT
#	FunctionMethodDeclarations
#	AssignmentsInFunctionCall
#	ComplexMethodsLT
#	ComplexMethodsHT
#	Max_ComplexMethodsVg
#	UninitializedLocalVariables
#	MultipleReturnFunctionsMethods
#	VariableArgumentMethods
#	WithoutAutoAssignmentTestAssignmentOperators
#	WithoutReturningStarThisAssignmentOperators
#	WithThrowDestructors
#	ForbiddenReferenceReturningOperators
#	WithNotConstRefParametersOperators
#	PointerObjectParameters
#	ObjectParameters
#
# Following mnemo should be implemented with new parser, because needed in the model.
#
#	ClassImplementations

our @table_Comptages = (

     [ Ident::Alias_AndOr(), 'CountAndOr', 'CountAndOr', \&CountAndOr::CountAndOr, 'APPEL', 1 ],
     [ Ident::Alias_AsmLines(), 'CountAsm', 'CountAsm', \&CountAsm::CountAsm, 'APPEL', 1 ],
     [ Ident::Alias_AssignmentsInConditionalExpr(), 'CountAssignmentsInConditionalExpr', 'CountAssignmentsInConditionalExpr', \&CountAssignmentsInConditionalExpr::CountAssignmentsInConditionalExpr, 'APPEL', 1 ],
     [ Ident::Alias_BadSpacing(), 'CountBadSpacing', 'CountBadSpacing', \&CountBadSpacing::CountBadSpacing, 'APPEL', 1 ],
     [ Ident::Alias_BasicTypeUses(), 'Count_Cpp_BasicTypeUses', 'CountBasicTypeUses', \&CountBasicTypeUses::Count_Cpp_BasicTypeUses, 'APPEL', 1 ],
     [ Ident::Alias_StructuredTypedefs(), 'Count_Cpp_BasicTypeUses', 'CountBasicTypeUses', \&CountBasicTypeUses::Count_Cpp_BasicTypeUses, 'APPEL', 1 ],
     [ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
     [ Ident::Alias_Break(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
     [ Ident::Alias_MultipleBreakLoops(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
     [ Ident::Alias_MissingBreakInSwitch(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
     [ Ident::Alias_CComments(), 'CountCComments', 'CountCComments', \&CountCComments::CountCComments, 'APPEL', 1 ],
     #[ Ident::Alias_WithTooMuchParametersMethods(), 'Count_Parameters', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Parameters, 'APPEL', 1 ],
     # [ Ident::Alias_TotalParameters(), 'Count_Parameters', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Parameters, 'APPEL', 1 ],
     # [ Ident::Alias_ApplicationGlobalVariables(), 'Count_AppGlobalVar', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AppGlobalVar, 'APPEL', 1 ],
     #[ Ident::Alias_FileGlobalVariables(), 'Count_FileGlobalVar', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_FileGlobalVar, 'APPEL', 1 ],
     #[ Ident::Alias_MultipleDeclarationsInSameStatement(), 'Count_MultipleDeclarationSameLine', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MultipleDeclarationSameLine, 'APPEL', 1 ],
     # [ Ident::Alias_ShortAttributeNamesLT(), 'Count_AttributeNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AttributeNaming, 'APPEL', 1 ],
     #[ Ident::Alias_ShortAttributeNamesHT(), 'Count_AttributeNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AttributeNaming, 'APPEL', 1 ],
     # [ Ident::Alias_BadAttributeNames(), 'Count_AttributeNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AttributeNaming, 'APPEL', 1 ],
     #[ Ident::Alias_BadDeclarationOrder(), 'Count_BadDeclarationOrder', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_BadDeclarationOrder, 'APPEL', 1 ],
     # [ Ident::Alias_ShortClassNamesLT(), 'Count_ClassNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ClassNaming, 'APPEL', 1 ],
     #[ Ident::Alias_ShortClassNamesHT(), 'Count_ClassNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ClassNaming, 'APPEL', 1 ],
     # [ Ident::Alias_BadClassNames(), 'Count_ClassNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ClassNaming, 'APPEL', 1 ],
     # [ Ident::Alias_ClassDefinitions(), 'Count_ClassesStructs', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ClassesStructs, 'APPEL', 1 ],
     #[ Ident::Alias_GlobalDefinitions(), 'Count_GlobalDefinition', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_GlobalDefinition, 'APPEL', 1 ],
     # [ Ident::Alias_ShortMethodNamesLT(), 'Count_MethodNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MethodNaming, 'APPEL', 1 ],
     #[ Ident::Alias_ShortMethodNamesHT(), 'Count_MethodNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MethodNaming, 'APPEL', 1 ],
     # [ Ident::Alias_BadMethodNames(), 'Count_MethodNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MethodNaming, 'APPEL', 1 ],
     #[ Ident::Alias_FunctionMethodImplementations(), 'Count_Cpp_Methods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Cpp_Methods, 'APPEL', 1 ],
     #[ Ident::Alias_FunctionMethodDeclarations(), 'Count_Cpp_Methods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Cpp_Methods, 'APPEL', 1 ],
     #[ Ident::Alias_ClassImplementations(), 'Count_Cpp_Methods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Cpp_Methods, 'APPEL', 1 ],
     #[ Ident::Alias_AssignmentsInFunctionCall(), 'Count_AssignmentsInFunctionCall', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AssignmentsInFunctionCall, 'APPEL', 1 ],
     #[ Ident::Alias_ComplexMethodsLT(), 'Count_ComplexMethods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ComplexMethods, 'APPEL', 1 ],
     #[ Ident::Alias_ComplexMethodsHT(), 'Count_ComplexMethods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ComplexMethods, 'APPEL', 1 ],
     #[ Ident::Alias_Max_Compl#exMethodsVg(), 'Count_ComplexMethods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ComplexMethods, 'APPEL', 1 ],
     #[ Ident::Alias_UninitializedLocalVariables(), 'Count_MultipleDeclarationSameLine', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MultipleDeclarationSameLine, 'APPEL', 1 ],
     #[ Ident::Alias_MultipleReturnFunctionsMethods(), 'Count_MultipleReturnFunctionsMethods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MultipleReturnFunctionsMethods, 'APPEL', 1 ],
     #[ Ident::Alias_VariableArgumentMethods(), 'Count_VarArg', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_VarArg, 'APPEL', 1 ],
     #[ Ident::Alias_WithoutAutoAssignmentTestAssignmentOperators(), 'Count_AssignmentOperatorsWithoutAutoAssignmentTest', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AssignmentOperatorsWithoutAutoAssignmentTest, 'APPEL', 1 ],
     #[ Ident::Alias_WithoutReturningStarThisAssignmentOperators(), 'Count_AssignmentOperatorsWithoutReturningStarThis', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AssignmentOperatorsWithoutReturningStarThis, 'APPEL', 1 ],
     #[ Ident::Alias_WithThrowDestructors(), 'Count_DestructorsWithThrow', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_DestructorsWithThrow, 'APPEL', 1 ],
     #[ Ident::Alias_ForbiddenReferenceReturningOperators(), 'Count_ForbiddenReferenceReturningOperators', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ForbiddenReferenceReturningOperators, 'APPEL', 1 ],
     #[ Ident::Alias_WithNotConstRefParametersOperators(), 'Count_OperatorsParamNotAsConstRef', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_OperatorsParamNotAsConstRef, 'APPEL', 1 ],
     #[ Ident::Alias_PointerObjectParameters(), 'Count_ParametersObjects', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ParametersObjects, 'APPEL', 1 ],
     #[ Ident::Alias_ObjectParameters(), 'Count_ParametersObjects', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ParametersObjects, 'APPEL', 1 ],
     [ Ident::Alias_CommentedOutCode(), 'CountCommentedOutCode', 'CountCommentedOutCode', \&CountCommentedOutCode::CountCommentedOutCode, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     [ Ident::Alias_BlankLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_CommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_AlphaNumCommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode_SansPrepro', 'CountCommun', \&CountCommun::CountLinesOfCode_SansPrepro, 'APPEL', 1 ],
     [ Ident::Alias_ComplexConditions(), 'CountComplexConditions', 'CountComplexConditions', \&CountComplexConditions::CountComplexConditions, 'APPEL', 1 ],
     [ Ident::Alias_ComplexOperands(), 'CountComplexOperands', 'CountComplexOperands', \&CountComplexOperands::CountComplexOperands, 'APPEL', 1 ],
     [ Ident::Alias_IncrDecrOperatorComplexUses(), 'CountComplexUsesOfIncrDecrOperator', 'CountComplexUsesOfIncrDecrOperator', \&CountComplexUsesOfIncrDecrOperator::CountComplexUsesOfIncrDecrOperator, 'APPEL', 1 ],
     [ Ident::Alias_Return(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Include(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_While(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_For(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Continue(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Switch(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Default(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Goto(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Try(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Catch(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_New(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Delete(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_ReinterpretCasts(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Union(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Exit(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Malloc(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Calloc(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Realloc(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Strdup(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Free(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Else(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Gets(), 'CountRiskyKeywords', 'CountCpp', \&CountCpp::CountRiskyKeywords, 'ObjC', 1 ],
     [ Ident::Alias_find_first_of(), 'CountRiskyKeywords', 'CountCpp', \&CountCpp::CountRiskyKeywords, 'ObjC', 1 ],
     [ Ident::Alias_Strtrns(), 'CountRiskyKeywords', 'CountCpp', \&CountCpp::CountRiskyKeywords, 'ObjC', 1 ],
     [ Ident::Alias_Strlen(), 'CountRiskyKeywords', 'CountCpp', \&CountCpp::CountRiskyKeywords, 'ObjC', 1 ],
     [ Ident::Alias_Strecpy(), 'CountRiskyKeywords', 'CountCpp', \&CountCpp::CountRiskyKeywords, 'ObjC', 1 ],
     [ Ident::Alias_Streadd(), 'CountRiskyKeywords', 'CountCpp', \&CountCpp::CountRiskyKeywords, 'ObjC', 1 ],
     [ Ident::Alias_Snprintf(), 'CountRiskyKeywords', 'CountCpp', \&CountCpp::CountRiskyKeywords, 'ObjC', 1 ],
     [ Ident::Alias_Realpath(), 'CountRiskyKeywords', 'CountCpp', \&CountCpp::CountRiskyKeywords, 'ObjC', 1 ],
     [ Ident::Alias_Getpass(), 'CountRiskyKeywords', 'CountCpp', \&CountCpp::CountRiskyKeywords, 'ObjC', 1 ],
     [ Ident::Alias_Getopt(), 'CountRiskyKeywords', 'CountCpp', \&CountCpp::CountRiskyKeywords, 'ObjC', 1 ],
     [ Ident::Alias_DeleteThis(), 'CountRiskyKeywords', 'CountCpp', \&CountCpp::CountRiskyKeywords, 'ObjC', 1 ],
     [ Ident::Alias_Using(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'ObjC', 1 ],
     [ Ident::Alias_NewArray(), 'CountRiskyKeywords', 'CountCpp', \&CountCpp::CountRiskyKeywords, 'ObjC', 1 ],
     [ Ident::Alias_MacroDefinitions(), 'CountConstantMacroDefinitions', 'CountCpp', \&CountCpp::CountConstantMacroDefinitions, 'APPEL', 1 ],
     [ Ident::Alias_ConstantMacroDefinitions(), 'CountConstantMacroDefinitions', 'CountCpp', \&CountCpp::CountConstantMacroDefinitions, 'APPEL', 1 ],
     [ Ident::Alias_AnonymousNamespaces(), 'CountAnonymousNamespaces', 'CountCpp', \&CountCpp::CountAnonymousNamespaces, 'APPEL', 1 ],
     [ Ident::Alias_BugPatterns(), 'CountBugPatterns', 'CountCpp', \&CountCpp::CountBugPatterns, 'APPEL', 1 ],
     [ Ident::Alias_CCastUses(), 'CountCCastUses', 'CountCpp', \&CountCpp::CountCCastUses, 'APPEL', 1 ],
     [ Ident::Alias_RiskyFunctionCalls(), 'CountRiskyFunctionCalls', 'CountCpp', \&CountCpp::CountRiskyFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_StdioFunctionCalls(), 'CountStdioFunctionCalls', 'CountCpp', \&CountCpp::CountStdioFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_WithoutFormatSizeScanfs(), 'CountWithoutFormatSizeScanfs', 'CountCpp', \&CountCpp::CountWithoutFormatSizeScanfs, 'APPEL', 1 ],
     [ Ident::Alias_WithoutSizeCins(), 'CountWithoutSizeCins', 'CountCpp', \&CountCpp::CountWithoutSizeCins, 'APPEL', 1 ],
     [ Ident::Alias_EmptyCatches(), 'CountEmptyCatches', 'CountEmptyCatches', \&CountEmptyCatches::CountEmptyCatches, 'APPEL', 1 ],
     [ Ident::Alias_HardCodedPaths(), 'CountHardCodedPaths', 'CountHardCodedPaths', \&CountHardCodedPaths::CountHardCodedPaths, 'APPEL', 1 ],
     [ Ident::Alias_IfPrepro(), 'CountIfPrepro', 'CountIfPrepro', \&CountIfPrepro::CountIfPrepro, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines100(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines132(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_MagicNumbers(), 'CountMagicNumbers', 'CountMagicNumbers', \&CountMagicNumbers::CountMagicNumbers, 'APPEL', 1 ],
     [ Ident::Alias_MissingBraces(), 'CountMissingBraces', 'CountMissingBraces', \&CountMissingBraces::CountMissingBraces, 'APPEL', 1 ],
     [ Ident::Alias_MissingBreakInCasePath(), 'CountMissingBreakInCasePath', 'CountMissingBreakInCasePath', \&CountMissingBreakInCasePath::CountMissingBreakInCasePath, 'APPEL', 1 ],
     
     # Nbr_MissingDefaults is a useless counter.
     # moreover it is computed from Nbr_switch and Nbr_Default. And because we cannot ensure these counters will be computed before Nbr_MissingDefaults, this one can
     # be badly computed, leading to the following error : "missing counter Id_364".
     #[ Ident::Alias_MissingDefaults(), 'CountMissingDefaults', 'CountMissingDefaults', \&CountMissingDefaults::CountMissingDefaults, 'APPEL', 0 ],
     
     [ Ident::Alias_MissingFinalElses(), 'CountMissingFinalElses', 'CountMissingFinalElses', \&CountMissingFinalElses::CountMissingFinalElses, 'APPEL', 1 ],
     [ Ident::Alias_MultipleStatementsOnSameLine(), 'CountMultInst', 'CountMultInst', \&CountMultInst::CountMultInst, 'APPEL', 1 ],
     [ Ident::Alias_Pragmas(), 'CountPragmas', 'CountPragmas', \&CountPragmas::CountPragmas, 'APPEL', 1 ],
     [ Ident::Alias_RiskyCatches(), 'CountRiskyCatches', 'CountRiskyCatches', \&CountRiskyCatches::CountRiskyCatches, 'APPEL', 1 ],
     [ Ident::Alias_SqlLines(), 'CountSql', 'CountSql', \&CountSql::CountSql, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     [ Ident::Alias_TernaryOperators(), 'CountTernaryOp', 'CountTernaryOp', \&CountTernaryOp::CountTernaryOp, 'APPEL', 1 ],
     [ Ident::Alias_UncommentedEmptyStmts(), 'CountUncommentedEmptyStmts', 'CountUncommentedEmptyStmts', \&CountUncommentedEmptyStmts::CountUncommentedEmptyStmts, 'APPEL', 0 ],
     [ Ident::Alias_BadEffectiveParameter(), 'CountFormat', 'CountVulnerabilite', \&CountVulnerabilite::CountFormat, 'APPEL', 0 ],
     [ Ident::Alias_BadEffectiveFirstParameter(), 'CountFormat', 'CountVulnerabilite', \&CountVulnerabilite::CountFormat, 'APPEL', 0 ],
     [ Ident::Alias_BadEffectiveSecondParameter(), 'CountFormat', 'CountVulnerabilite', \&CountVulnerabilite::CountFormat, 'APPEL', 0 ],
     [ Ident::Alias_BadEffectiveThirdParameter(), 'CountFormat', 'CountVulnerabilite', \&CountVulnerabilite::CountFormat, 'APPEL', 0 ],
     [ Ident::Alias_WeakStringFunctionCalls(), 'CountWeakStringFunctionCalls', 'CountVulnerabilite', \&CountVulnerabilite::CountWeakStringFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_ShellLauncherFunctionCalls(), 'CountShellLauncherFunctionCalls', 'CountVulnerabilite', \&CountVulnerabilite::CountShellLauncherFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_FixedSizeArrays(), 'CountDefArrayFixedSize', 'CountVulnerabilite', \&CountVulnerabilite::CountDefArrayFixedSize, 'APPEL', 1 ],
     [ Ident::Alias_Words(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 1 ],
     [ Ident::Alias_DistinctWords(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 1 ],
     # [Ident::Alias_WithoutVirtualDestructorAbstractClass(), 'CountWithoutVirtualDestructorAbstractClass', 'Cpp::CountClass', \&Cpp::CountClass::CountWithoutVirtualDestructorAbstractClass, 'APPEL', 1 ],
     [Ident::Alias_NonPrivateDataMember(), 'CountAttributes', 'Cpp::CountClass', \&Cpp::CountClass::CountAttributes, 'APPEL', 1 ],
     [Ident::Alias_PublicAttributes(), 'CountAttributes', 'Cpp::CountClass', \&Cpp::CountClass::CountAttributes, 'APPEL', 1 ],
     [Ident::Alias_ProtectedAttributes(), 'CountAttributes', 'Cpp::CountClass', \&Cpp::CountClass::CountAttributes, 'APPEL', 1 ],
     [Ident::Alias_PrivateAttributes(), 'CountAttributes', 'Cpp::CountClass', \&Cpp::CountClass::CountAttributes, 'APPEL', 1 ],
     [Ident::Alias_WithoutInterfaceImplementation(), 'CountWithoutInterfaceImplementation', 'Cpp::CountFile', \&Cpp::CountFile::CountWithoutInterfaceImplementation, 'APPEL', 1 ],
     [Ident::Alias_CallToBlockingFunction(), 'CountCallToBlockingFunction', 'Cpp::CountFile', \&Cpp::CountFile::CountCallToBlockingFunction, 'APPEL', 1 ],
     # [Ident::Alias_RuleOf3_WithCopyAssignator(), 'CountRuleOf3', 'Cpp::CountClass', \&Cpp::CountClass::CountRuleOf3, 'APPEL', 1 ],
     # [Ident::Alias_RuleOf3_WithCopyConstructor(), 'CountRuleOf3', 'Cpp::CountClass', \&Cpp::CountClass::CountRuleOf3, 'APPEL', 1 ],
     # [Ident::Alias_RuleOf3_WithDestructor(), 'CountRuleOf3', 'Cpp::CountClass', \&Cpp::CountClass::CountRuleOf3, 'APPEL', 1 ],
     # [Ident::Alias_WhithoutPrivateDefaultConstructorUtilityClass(), 'CountWhithoutPrivateDefaultConstructorUtilityClass', 'Cpp::CountClass', \&Cpp::CountClass::CountWhithoutPrivateDefaultConstructorUtilityClass, 'APPEL', 1 ],
    # [Ident::Alias_StaticGlobalVariableInHeader(), 'CountStaticGlobalVariableInHeader', 'Cpp::CountClass', \&Cpp::CountClass::CountStaticGlobalVariableInHeader, 'APPEL', 1 ],
     # [Ident::Alias_IllegalOperatorOverload(), 'CountIllegalOperatorOverload', 'Cpp::CountClass', \&Cpp::CountClass::CountIllegalOperatorOverload, 'APPEL', 1 ],
     # [Ident::Alias_CopyAssignableAbstractClass(), 'CountCopyAssignableAbstractClass', 'Cpp::CountClass', \&Cpp::CountClass::CountCopyAssignableAbstractClass, 'APPEL', 1 ],
     [Ident::Alias_TotalParameters(), 'CountRoutine', 'Cpp::CountRoutine', \&Cpp::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [Ident::Alias_ApplicationGlobalVariables(), 'CountVariable', 'Cpp::CountVariable', \&Cpp::CountVariable::CountVariable, 'APPEL', 1 ],
     [Ident::Alias_ShortAttributeNamesLT(), 'CountAttributeName', 'Cpp::CountNaming', \&Cpp::CountNaming::CountAttributeName, 'APPEL', 1 ],
     [Ident::Alias_ShortClassNamesLT(), 'CountClassName', 'Cpp::CountNaming', \&Cpp::CountNaming::CountClassName, 'APPEL', 1 ],
     [Ident::Alias_ShortMethodNamesLT(), 'CountMethodName', 'Cpp::CountNaming', \&Cpp::CountNaming::CountMethodName, 'APPEL', 1 ],
     [Ident::Alias_BadAttributeNames(), 'CountAttributeName', 'Cpp::CountNaming', \&Cpp::CountNaming::CountAttributeName, 'APPEL', 1 ],
     [Ident::Alias_BadClassNames(), 'CountClassName', 'Cpp::CountNaming', \&Cpp::CountNaming::CountClassName, 'APPEL', 1 ],
     [Ident::Alias_BadMethodNames(), 'CountMethodName', 'Cpp::CountNaming', \&Cpp::CountNaming::CountMethodName, 'APPEL', 1 ],
     [Ident::Alias_ClassDefinitions(), 'CountClass', 'Cpp::CountClass', \&Cpp::CountClass::CountClass, 'APPEL', 1 ],
     [Ident::Alias_StructDefinitions(), 'CountClass', 'Cpp::CountClass', \&Cpp::CountClass::CountClass, 'APPEL', 1 ],
     [Ident::Alias_FunctionMethodImplementations(), 'CountRoutine', 'Cpp::CountRoutine', \&Cpp::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [Ident::Alias_StaticGlobalVariableInHeader(), 'CountVariable', 'Cpp::CountVariable', \&Cpp::CountVariable::CountVariable, 'APPEL', 1 ],
     [Ident::Alias_WithoutVirtualDestructorAbstractClass(), 'CountClass', 'Cpp::CountClass', \&Cpp::CountClass::CountClass, 'APPEL', 1 ],
     [Ident::Alias_CopyAssignableAbstractClass(), 'CountClass', 'Cpp::CountClass', \&Cpp::CountClass::CountClass, 'APPEL', 1 ],
     [Ident::Alias_RuleOf3_WithCopyAssignator(), 'CountClass', 'Cpp::CountClass', \&Cpp::CountClass::CountClass, 'APPEL', 1 ],
     [Ident::Alias_RuleOf3_WithCopyConstructor(), 'CountClass', 'Cpp::CountClass', \&Cpp::CountClass::CountClass, 'APPEL', 1 ],
     [Ident::Alias_RuleOf3_WithDestructor(), 'CountClass', 'Cpp::CountClass', \&Cpp::CountClass::CountClass, 'APPEL', 1 ],
     [Ident::Alias_WhithoutPrivateDefaultConstructorUtilityClass(), 'CountClass', 'Cpp::CountClass', \&Cpp::CountClass::CountClass, 'APPEL', 1 ],
     [Ident::Alias_IllegalOperatorOverload(), 'CountClass', 'Cpp::CountClass', \&Cpp::CountClass::CountClass, 'APPEL', 1 ],
     [Ident::Alias_SuspiciousCommentSyntax(), 'CountComment', 'Cpp::CountComment', \&Cpp::CountComment::CountComment, 'APPEL', 1 ],
     [Ident::Alias_BadLiteralConstant(), 'CountBadLiteralConstant', 'Cpp::CountVariable', \&Cpp::CountVariable::CountBadLiteralConstant, 'APPEL', 1 ],
     [Ident::Alias_MissingTabSize(), 'CountVariable', 'Cpp::CountVariable', \&Cpp::CountVariable::CountVariable, 'APPEL', 1 ],
     [Ident::Alias_WithoutCaseSwitch(), 'CountSwitchWithoutCaseStatement', 'Cpp::CountCondition', \&Cpp::CountCondition::CountSwitchWithoutCaseStatement, 'APPEL', 1 ],
     [Ident::Alias_OverFlowingLoopCounter(), 'CountLoop', 'Cpp::CountLoop', \&Cpp::CountLoop::CountLoop, 'APPEL', 1 ],
     [Ident::Alias_WithoutFinalExit(), 'CountRoutine', 'Cpp::CountRoutine', \&Cpp::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [Ident::Alias_FunctionsUsingEllipsis(), 'CountRoutine', 'Cpp::CountRoutine', \&Cpp::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [Ident::Alias_EmptyReturn(), 'CountRoutine', 'Cpp::CountRoutine', \&Cpp::CountRoutine::CountRoutine, 'APPEL', 1 ],
     [Ident::Alias_IllegalThrows(), 'CountException', 'Cpp::CountException', \&Cpp::CountException::CountException, 'APPEL', 1 ],
     [Ident::Alias_NonTerminalCatchAll(), 'CountException', 'Cpp::CountException', \&Cpp::CountException::CountException, 'APPEL', 1 ],
     [Ident::Alias_MisplacedInclude(), 'CountInstruction', 'Cpp::CountInstruction', \&Cpp::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [Ident::Alias_MisplacedDefine(), 'CountInstruction', 'Cpp::CountInstruction', \&Cpp::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [Ident::Alias_Undef(), 'CountInstruction', 'Cpp::CountInstruction', \&Cpp::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [Ident::Alias_ImplementationDefinedLibraryUse(), 'CountInstruction', 'Cpp::CountInstruction', \&Cpp::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [Ident::Alias_OnError(), 'CountInstruction', 'Cpp::CountInstruction', \&Cpp::CountInstruction::CountInstruction, 'APPEL', 1 ],
     [Ident::Alias_GlobalVariableHidding(), 'CountVariableHidding', 'Cpp::CountVariable', \&Cpp::CountVariable::CountVariableHidding, 'APPEL', 1 ],

);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
     [ Ident::Alias_VG(), 'CountVG', 'CountCpp', \&CountCpp::CountVG, 'APPEL', 1 ],
     [ Ident::Alias_MissingDefaults(), 'CountMissingDefaults', 'CountMissingDefaults', \&CountMissingDefaults::CountMissingDefaults, 'APPEL', 0 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
