#----------------------------------------------------------------------#
#                 @ISOSCOPE 2008                                       #
#----------------------------------------------------------------------#
#       Auteur  : ISOSCOPE SA                                          #
#       Adresse : TERSUD - Bat A                                       #
#                 5, AVENUE MARCEL DASSAULT                            #
#                 31500  TOULOUSE                                      #
#       SIRET   : 410 630 164 00037                                    #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Plugin
#----------------------------------------------------------------------#
# DESCRIPTION: Configuration des analyseurs C, H, CPP, HPP
#----------------------------------------------------------------------#

package AnaConfiguration_H_C_HPP_CPP;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Timing; # timing_filter_line
use Memory; # memory_filter_line
use AnaUtils;
use CountCommun;
use CountLongLines; # bt_filter_line
use CountC;
use CountCpp;
use CountVulnerabilite;
use CountCommentedOutCode;
use CountMissingBreakInCasePath;    # bt_filter_line
use CountEmptyCatches;
use CountRiskyCatches;              # bt_filter_line
use CountBreakLoop;
use CountComplexConditions;
use CountAssignmentsInConditionalExpr;
use CountMissingBraces;
use CountMagicNumbers;
use CountHardCodedPaths;            # bt_filter_line
use CountSuspiciousComments;        # bt_filter_line
use CountAndOr;                     # bt_filter_line
use CountWords;                     # bt_filter_line
use CountIfPrepro;
use CountBadSpacing;
use CountComplexOperands;
use CountMissingIncludeProtections;
use CountCommentsBlocs;
use CountMultInst;
use CountC_CPP_FunctionsMethodsAttributes;
use CountTernaryOp;
use CountSql;                       # bt_filter_line
use CountAsm;                       # bt_filter_line
use CountBinaryFile;
use CountCComments;
use CountPragmas;
use CountBasicTypeUses;
use CountMissingFinalElses;
use CountUncommentedEmptyStmts;
use CountMissingDefaults;
use CountComplexUsesOfIncrDecrOperator;

# prototypes publics
sub ExtractTablesCountersAndNames($$);

# prototypes prives


#-------------------------------------------------------------------------------
# configuration des compteurs pour les analyseurs c, h, cpp, hpp
# 0 : on ne lance pas le comptage pour l'analyseur x
# 1 : on lance le comptage pour l'analyseur x
#-------------------------------------------------------------------------------
use constant TABLE_COUNTERS_ANA_C    => 0;
use constant TABLE_COUNTERS_ANA_H    => 1;
use constant TABLE_COUNTERS_ANA_CPP  => 2;
use constant TABLE_COUNTERS_ANA_HPP  => 3;
use constant TABLE_COUNTERS_COUNTER_FT  => 4;
use constant TABLE_COUNTERS_COUNTER_FT_NAME  => 5;

my @LanguagesTableCountersAndNames =
(
# c, h, cpp, hpp
  [1, 1, 1, 1, \&CountBinaryFile::CountBinaryFile, 'CountBinaryFile::CountBinaryFile'], # Nbr_HeterogeneousEncoding # bt_filter_line
  [1, 1, 1, 1, \&CountCommun::CountCommun, 'CountCommun::CountCommun'], # Nbr_Lines 
  [1, 1, 1, 1, \&CountCommun::CountLinesOfCode_SansPrepro, 'CountCommun::CountLinesOfCode_SansPrepro'], # Nbr_LinesOfCode
  [1, 1, 1, 1, \&CountLongLines::CountLongLines, 'CountLongLines::CountLongLines'], # Nbr_LongLineXXX  # bt_filter_line
  [1, 0, 1, 0, \&CountBreakLoop::CountBreakLoop, 'CountBreakLoop::CountBreakLoop'],  # Nbr_Break, Nbr_MultipleBreakLoops, Nbr_MultipleBreakLoops, Nbr_MissingBreakInSwitch
  [0, 0, 1, 1, \&CountCpp::CountKeywords, 'CountCpp::CountKeywords'], # Nbr_ReinterpretCasts
  [1, 0, 0, 0, \&CountC::CountKeywords , 'CountC::CountKeywords' ],
  [1, 1, 0, 0, \&CountC::CountUnionStruct , 'CountC::CountUnionStruct' ], # Nbr_Union, Nbr_StructDefinitions
  [0, 0, 1, 0, \&CountCpp::CountBugPatterns, 'CountCpp::CountBugPatterns'], # cpp only # bt_filter_line
  [1, 0, 0, 0, \&CountC::CountBugPatterns , 'CountC::CountBugPatterns' ],   # c only   # bt_filter_line
  [0, 0, 1, 0, \&CountCpp::CountRiskyFunctionCalls, 'CountCpp::CountRiskyFunctionCalls'], # cpp only Nbr_RiskyFunctionCalls # bt_filter_line
  [1, 0, 0, 0, \&CountC::CountRiskyFunctionCalls , 'CountC::CountRiskyFunctionCalls' ],   # c only Nbr_RiskyFunctionCalls # bt_filter_line
  [1, 1, 1, 1, \&CountCommentedOutCode::CountCommentedOutCode, 'CountCommentedOutCode::CountCommentedOutCode'], # Nbr_CommentedOutCode
# c, h, cpp, hpp
  [1, 0, 1, 0, \&CountMissingBreakInCasePath::CountMissingBreakInCasePath, 'CountMissingBreakInCasePath::CountMissingBreakInCasePath'], # Nbr_MissingBreakInCasePath # bt_filter_line
  [0, 0, 1, 0, \&CountEmptyCatches::CountEmptyCatches, 'CountEmptyCatches::CountEmptyCatches'], # Nbr_EmptyCatches
  [0, 0, 1, 0, \&CountRiskyCatches::CountRiskyCatches, 'CountRiskyCatches::CountRiskyCatches'], # Nbr_RiskyCatches # bt_filter_line
  [1, 0, 1, 0, \&CountComplexConditions::CountComplexConditions, 'CountComplexConditions::CountComplexConditions'], # Nbr_ComplexConditions
  [1, 0, 1, 0, \&CountMissingBraces::CountMissingBraces, 'CountMissingBraces::CountMissingBraces'],  # Nbr_MissingBraces
  [1, 0, 1, 0, \&CountAssignmentsInConditionalExpr::CountAssignmentsInConditionalExpr, 'CountAssignmentsInConditionalExpr::CountAssignmentsInConditionalExpr'], #Nbr_AssignmentsInConditionalExpr
  [1, 0, 1, 0, \&CountMagicNumbers::CountMagicNumbers, 'CountMagicNumbers::CountMagicNumbers'],  # Nbr_MagicNumbers
  [1, 0, 1, 1, \&CountHardCodedPaths::CountHardCodedPaths, 'CountHardCodedPaths::CountHardCodedPaths'], # Nbr_HardCodedPaths # bt_filter_line
  [1, 1, 1, 1, \&CountSuspiciousComments::CountSuspiciousComments, 'CountSuspiciousComments::CountSuspiciousComments'], # Nbr_SuspiciousComments # bt_filter_line
  [1, 0, 1, 0, \&CountAndOr::CountAndOr, 'CountAndOr::CountAndOr'], # Nbr_AndOr # bt_filter_line
# c, h, cpp, hpp
  [1, 1, 1, 1, \&CountWords::CountWords, 'CountWords::CountWords'], # Nbr_Words Nbr_DistinctWords # bt_filter_line
  [1, 1, 1, 1, \&CountIfPrepro::CountIfPrepro, 'CountIfPrepro::CountIfPrepro'], # Nbr_IfPrepro
  [1, 0, 1, 0, \&CountBadSpacing::CountBadSpacing, 'CountBadSpacing::CountBadSpacing'], # Nbr_BadSpacing
  [1, 0, 1, 0, \&CountComplexOperands::CountComplexOperands, 'CountComplexOperands::CountComplexOperands'], # Nbr_ComplexOperands
  [1, 1, 1, 1, \&CountCommentsBlocs::CountCommentsBlocs, 'CountCommentsBlocs::CountCommentsBlocs'], # Nbr_CommentBlocs
  [1, 0, 1, 0, \&CountMultInst::CountMultInst, 'CountMultInst::CountMultInst'], # Nbr_MultipleStatementsOnSameLine
  [1, 0, 1, 0, \&CountTernaryOp::CountTernaryOp, 'CountTernaryOp::CountTernaryOp'], # Nbr_TernaryOperators
  [1, 0, 1, 0, \&CountSql::CountSql, 'CountSql::CountSql'], # Nbr_SqlLines # bt_filter_line
  [1, 0, 1, 0, \&CountAsm::CountAsm, 'CountAsm::CountAsm'], # Nbr_AsmLines # bt_filter_line
  [0, 0, 1, 0, \&CountVulnerabilite::CountWeakStringFunctionCalls, 'CountVulnerabilite::CountWeakStringFunctionCalls'], # Nbr_WeakStringFunctionCalls
# c, h, cpp, hpp
  [0, 0, 1, 0, \&CountVulnerabilite::CountShellLauncherFunctionCalls, 'CountVulnerabilite::CountShellLauncherFunctionCalls'], # Nbr_ShellLauncherFunctionCalls
  [0, 0, 0, 0, \&CountVulnerabilite::CountFormat, 'CountVulnerabilite::CountFormat'], # Nbr_BadEffectiveParameter
  [0, 0, 1, 0, \&CountVulnerabilite::CountDefArrayFixedSize, 'CountVulnerabilite::CountDefArrayFixedSize'], # Nbr_FixedSizeArrays
  [0, 1, 0, 1, \&CountMissingIncludeProtections::CountMissingIncludeProtections, 'CountMissingIncludeProtections::CountMissingIncludeProtections'], # Nbr_MissingIncludeProtections
  [0, 0, 1, 1, \&CountCpp::CountConstantMacroDefinitions, 'CountCpp::CountConstantMacroDefinitions'], # Nbr_ConstantMacroDefinitions # bt_filter_hereendline Nbr_MacroDefinitions
  [1, 1, 0, 0, \&CountC::CountMacroNaming, 'CountC::CountMacroNaming'], # c only Nbr_BadMacroNames # bt_filter_line
  [1, 1, 0, 0, \&CountC::CountMacrosParamSansParenthese, 'CountC::CountMacrosParamSansParenthese'], # c only Nbr_UnparenthesedParamMacros
  [0, 0, 1, 1, \&CountCpp::CountAnonymousNamespaces, 'CountCpp::CountAnonymousNamespaces'], # Nbr_AnonymousNamespaces
  [0, 0, 1, 0, \&CountCpp::CountStdioFunctionCalls, 'CountCpp::CountStdioFunctionCalls'],  # Nbr_StdioFunctionCalls
# c, h, cpp, hpp
  [0, 0, 1, 0, \&CountCpp::CountWithoutSizeCins, 'CountCpp::CountWithoutSizeCins'], # Nbr_WithoutSizeCins
  [0, 0, 1, 1, \&CountCComments::CountCComments, 'CountCComments::CountCComments'], # Nbr_CComments
  [1, 1, 1, 1, \&CountPragmas::CountPragmas, 'CountPragmas::CountPragmas'], # Nbr_Pragmas
  [1, 1, 1, 1, \&CountBasicTypeUses::CountBasicTypeUses, 'CountBasicTypeUses::CountBasicTypeUses'], # Nbr_BasicTypeUses, Nbr_StructuredTypedefs
  [1, 0, 1, 0, \&CountMissingFinalElses::CountMissingFinalElses, 'CountMissingFinalElses::CountMissingFinalElses'], # Nbr_MissingFinalElses
  [0, 0, 0, 0, \&CountUncommentedEmptyStmts::CountUncommentedEmptyStmts, 'CountUncommentedEmptyStmts::CountUncommentedEmptyStmts'], # Nbr_UncommentedEmptyStmts
  [0, 0, 0, 0, \&CountMissingDefaults::CountMissingDefaults, 'CountMissingDefaults::CountMissingDefaults'], # Nbr_MissingDefaults
  [1, 0, 0, 0, \&CountC::CountBadPtrAccess, 'CountC::CountBadPtrAccess'],  # Nbr_BadPtrAccess
  [1, 1, 0, 0, \&CountC::CountCPPKeyWords, 'CountC::CountCPPKeyWords'], # Nbr_CPPKeywords
# c, h, cpp, hpp
  [1, 0, 0, 0, \&CountC::CountMultipleAssignments, 'CountC::CountMultipleAssignments'], # Nbr_MultipleAssignments
  [0, 0, 1, 0, \&CountC_CPP_FunctionsMethodsAttributes::Count_OperatorsParamNotAsConstRef, 'CountC_CPP_FunctionsMethodsAttributes::Count_OperatorsParamNotAsConstRef'], # Nbr_WithNotConstRefParametersOperators
  [0, 0, 1, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_OverloadedOperators, 'CountC_CPP_FunctionsMethodsAttributes::Count_OverloadedOperators'], # Nbr_ForbiddenOverloadedOperators Nbr_ForbiddenReferenceReturningOperators
  [1, 1, 1, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_Parameters, 'CountC_CPP_FunctionsMethodsAttributes::Count_Parameters'], # Nbr_WithTooMuchParametersMethods Nbr_TotalParameters # bt_filter_line
  [1, 0, 1, 0, \&CountC_CPP_FunctionsMethodsAttributes::Count_VarArg, 'CountC_CPP_FunctionsMethodsAttributes::Count_VarArg'], # Nbr_VariableArgumentMethods
  [0, 0, 1, 0, \&CountC_CPP_FunctionsMethodsAttributes::Count_ParametersObjects, 'CountC_CPP_FunctionsMethodsAttributes::Count_ParametersObjects'], # Nbr_PointerObjectParameters Nbr_ObjectParameters
  [0, 0, 0, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_Attributes, 'CountC_CPP_FunctionsMethodsAttributes::Count_Attributes'], # Nbr_PublicAttributes # bt_filter_hereendline Nbr_PrivateProtectedAttributes
  [1, 1, 1, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_AppGlobalVar, 'CountC_CPP_FunctionsMethodsAttributes::Count_AppGlobalVar'], # Nbr_ApplicationGlobalVariables
  [1, 1, 1, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_FileGlobalVar, 'CountC_CPP_FunctionsMethodsAttributes::Count_FileGlobalVar'], # Nbr_FileGlobalVariables # bt_filter_line
  [1, 1, 1, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_MultipleDeclarationSameLine, 'CountC_CPP_FunctionsMethodsAttributes::Count_MultipleDeclarationSameLine'], # Nbr_MultipleDeclarationsInSameStatement Nbr_UninitializedLocalVariables
  [1, 0, 1, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_Methods, 'CountC_CPP_FunctionsMethodsAttributes::Count_Methods'], # Nbr_FunctionMethodImplementations Nbr_FunctionMethodDeclarations Nbr_ClassImplementations
  [0, 0, 0, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_InlineMethods, 'CountC_CPP_FunctionsMethodsAttributes::Count_InlineMethods'], # Nbr_InlineMethods
  [0, 0, 1, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_AttributeNaming, 'CountC_CPP_FunctionsMethodsAttributes::Count_AttributeNaming'], # Nbr_ShortAttributeNamesLT Nbr_ShortAttributeNamesHT Nbr_BadAttributeNames # bt_filter_line
  [0, 0, 1, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_MethodNaming, 'CountC_CPP_FunctionsMethodsAttributes::Count_MethodNaming'], # Nbr_ShortMethodNamesLT Nbr_ShortMethodNamesHT Nbr_BadMethodNames # bt_filter_line
# c, h, cpp, hpp
  [0, 0, 1, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_ClassNaming, 'CountC_CPP_FunctionsMethodsAttributes::Count_ClassNaming'], # Nbr_ShortClassNamesLT Nbr_ShortClassNamesHT Nbr_BadClassNames # bt_filter_line
  [0, 0, 1, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_BadDeclarationOrder, 'CountC_CPP_FunctionsMethodsAttributes::Count_BadDeclarationOrder'], # Nbr_BadDeclarationOrder # bt_filter_line
  [0, 0, 0, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_Inheritances, 'CountC_CPP_FunctionsMethodsAttributes::Count_Inheritances'], # Nbr_MultipleInheritances Nbr_PrivateInheritances
  [0, 0, 1, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_ClassesStructs, 'CountC_CPP_FunctionsMethodsAttributes::Count_ClassesStructs'], # Nbr_ClassDefinitions
  [0, 0, 0, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_Friends, 'CountC_CPP_FunctionsMethodsAttributes::Count_Friends'], # Nbr_FriendMethods Nbr_FriendClasses
  [0, 0, 0, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_MissingDtor, 'CountC_CPP_FunctionsMethodsAttributes::Count_MissingDtor'], # Nbr_MissingClassDestructor
  [0, 0, 0, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_MissingCtor, 'CountC_CPP_FunctionsMethodsAttributes::Count_MissingCtor'], # Nbr_MissingClassConstructor
  [1, 1, 0, 0, \&CountC_CPP_FunctionsMethodsAttributes::Count_FunctionNaming, 'CountC_CPP_FunctionsMethodsAttributes::Count_FunctionNaming'], # Nbr_ShortFunctionNamesLT Nbr_ShortFunctionNamesHT # bt_filter_line
  [1, 0, 1, 0, \&CountC_CPP_FunctionsMethodsAttributes::Count_ComplexMethods, 'CountC_CPP_FunctionsMethodsAttributes::Count_ComplexMethods'], # Nbr_ComplexMethodsLT Nbr_ComplexMethodsHT Avg_ComplexMethodsVg Max_ComplexMethodsVg
  [1, 0, 1, 0, \&CountC_CPP_FunctionsMethodsAttributes::Count_MultipleReturnFunctionsMethods, 'CountC_CPP_FunctionsMethodsAttributes::Count_MultipleReturnFunctionsMethods'], # Nbr_MultipleReturnFunctionsMethods
# c, h, cpp, hpp
  [1, 0, 1, 0, \&CountC_CPP_FunctionsMethodsAttributes::Count_AssignmentsInFunctionCall, 'CountC_CPP_FunctionsMethodsAttributes::Count_AssignmentsInFunctionCall'], # Nbr_AssignmentsInFunctionCall
  [0, 0, 1, 0, \&CountC_CPP_FunctionsMethodsAttributes::Count_DestructorsWithThrow, 'CountC_CPP_FunctionsMethodsAttributes::Count_DestructorsWithThrow'], # Nbr_WithThrowDestructors
  [0, 0, 1, 0, \&CountC_CPP_FunctionsMethodsAttributes::Count_AssignmentOperatorsWithoutAutoAssignmentTest, 'CountC_CPP_FunctionsMethodsAttributes::Count_AssignmentOperatorsWithoutAutoAssignmentTest'], # Nbr_WithoutAutoAssignmentTestAssignmentOperators
  [0, 0, 1, 0, \&CountC_CPP_FunctionsMethodsAttributes::Count_AssignmentOperatorsWithoutReturningStarThis, 'CountC_CPP_FunctionsMethodsAttributes::Count_AssignmentOperatorsWithoutReturningStarThis'],   # Nbr_WithoutReturningStarThisAssignmentOperators
  [0, 0, 0, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_BadDynamicClassDef, 'CountC_CPP_FunctionsMethodsAttributes::Count_BadDynamicClassDef'], # Nbr_BadDynamicClassDefinitions
  [0, 0, 1, 1, \&CountC_CPP_FunctionsMethodsAttributes::Count_GlobalDefinition, 'CountC_CPP_FunctionsMethodsAttributes::Count_GlobalDefinition'], # Nbr_GlobalDefinitions
  [0, 1, 0, 0, \&CountC_CPP_FunctionsMethodsAttributes::Count_DefinitionsInH, 'CountC_CPP_FunctionsMethodsAttributes::Count_DefinitionsInH'], # Nbr_DefinitionsInH
  [1, 0, 1, 0, \&CountComplexUsesOfIncrDecrOperator::CountComplexUsesOfIncrDecrOperator, 'CountComplexUsesOfIncrDecrOperator::CountComplexUsesOfIncrDecrOperator'], # Nbr_IncrDecrOperatorComplexUses
  [0, 0, 1, 0, \&CountCpp::CountCCastUses, 'CountCpp::CountCCastUses'], # Nbr_CCastUses
  [0, 0, 1, 0, \&CountCpp::CountWithoutFormatSizeScanfs, 'CountCpp::CountWithoutFormatSizeScanfs'], # Nbr_WithoutFormatSizeScanfs
  [1, 0, 1, 0, \&CountC_CPP_FunctionsMethodsAttributes::Count_PoorlyCommentedMethods, 'CountC_CPP_FunctionsMethodsAttributes::Count_PoorlyCommentedMethods'], # Nbr_PoorlyCommentedMethods
  # mettre les nouveaux compteurs ci-dessous
);

#-------------------------------------------------------------------------------
# DESCRIPTION: extrait les compteurs associes a l'analyseur
# option --allcounters permet de lancer les compteurs .h sur des .c
# et les compteurs .hpp sur des .cpp
#-------------------------------------------------------------------------------
sub ExtractTablesCountersAndNames($$)
{
  my ($colonne_analyseur, $options) =@_ ;

  my $ouputAllCounters = ((exists $options->{'--allcounters'})? 1 : 0);

  my @tables_of_counteurs;
  if (($colonne_analyseur < 0) || ($colonne_analyseur >= TABLE_COUNTERS_COUNTER_FT))
  {
    return @tables_of_counteurs;
  }

  my $b_ana_c_ou_h = 0;
  if ($colonne_analyseur == TABLE_COUNTERS_ANA_C)
  {
    $b_ana_c_ou_h = $ouputAllCounters;
  }
  my $b_ana_cpp_ou_hpp = 0;
  if ($colonne_analyseur == TABLE_COUNTERS_ANA_CPP)
  {
    $b_ana_cpp_ou_hpp = $ouputAllCounters;
  }
  foreach my $compteur_line(@LanguagesTableCountersAndNames)
  {
    if (($compteur_line->[$colonne_analyseur] == 1) ||
        ($b_ana_c_ou_h &&     ($compteur_line->[TABLE_COUNTERS_ANA_H] == 1)) ||
        ($b_ana_cpp_ou_hpp && ($compteur_line->[TABLE_COUNTERS_ANA_HPP] == 1)))
    {
      my $cpt_ft = $compteur_line->[TABLE_COUNTERS_COUNTER_FT];
      my $cpt_ft_name = $compteur_line->[TABLE_COUNTERS_COUNTER_FT_NAME];
      my $selected_item = [$cpt_ft, $cpt_ft_name];
      push(@tables_of_counteurs, $selected_item);
    }
  }

  return @tables_of_counteurs;
}


1;
