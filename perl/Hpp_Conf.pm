package Hpp_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_BasicTypeUses(), 'Count_Cpp_BasicTypeUses', 'CountBasicTypeUses', \&CountBasicTypeUses::Count_Cpp_BasicTypeUses, 'APPEL', 1 ],
     [ Ident::Alias_StructuredTypedefs(), 'Count_Cpp_BasicTypeUses', 'CountBasicTypeUses', \&CountBasicTypeUses::Count_Cpp_BasicTypeUses, 'APPEL', 1 ],
     [ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
     [ Ident::Alias_CComments(), 'CountCComments', 'CountCComments', \&CountCComments::CountCComments, 'APPEL', 1 ],
     [ Ident::Alias_WithTooMuchParametersMethods(), 'Count_Parameters', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Parameters, 'APPEL', 1 ],
     [ Ident::Alias_TotalParameters(), 'Count_Parameters', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Parameters, 'APPEL', 1 ],
     [ Ident::Alias_ApplicationGlobalVariables(), 'Count_AppGlobalVar', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AppGlobalVar, 'APPEL', 1 ],
     [ Ident::Alias_FileGlobalVariables(), 'Count_FileGlobalVar', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_FileGlobalVar, 'APPEL', 1 ],
     [ Ident::Alias_MultipleDeclarationsInSameStatement(), 'Count_MultipleDeclarationSameLine', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MultipleDeclarationSameLine, 'APPEL', 1 ],
     [ Ident::Alias_ShortAttributeNamesLT(), 'Count_AttributeNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AttributeNaming, 'APPEL', 1 ],
     [ Ident::Alias_ShortAttributeNamesHT(), 'Count_AttributeNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AttributeNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadAttributeNames(), 'Count_AttributeNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_AttributeNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadDeclarationOrder(), 'Count_BadDeclarationOrder', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_BadDeclarationOrder, 'APPEL', 1 ],
     [ Ident::Alias_ShortClassNamesLT(), 'Count_ClassNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ClassNaming, 'APPEL', 1 ],
     [ Ident::Alias_ShortClassNamesHT(), 'Count_ClassNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ClassNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadClassNames(), 'Count_ClassNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ClassNaming, 'APPEL', 1 ],
     [ Ident::Alias_ClassDefinitions(), 'Count_ClassesStructs', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ClassesStructs, 'APPEL', 1 ],
     [ Ident::Alias_GlobalDefinitions(), 'Count_GlobalDefinition', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_GlobalDefinition, 'APPEL', 1 ],
     [ Ident::Alias_ShortMethodNamesLT(), 'Count_MethodNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MethodNaming, 'APPEL', 1 ],
     [ Ident::Alias_ShortMethodNamesHT(), 'Count_MethodNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MethodNaming, 'APPEL', 1 ],
     [ Ident::Alias_BadMethodNames(), 'Count_MethodNaming', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MethodNaming, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodImplementations(), 'Count_Cpp_Methods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Cpp_Methods, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodDeclarations(), 'Count_Cpp_Methods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Cpp_Methods, 'APPEL', 1 ],
     [ Ident::Alias_ClassImplementations(), 'Count_Cpp_Methods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Cpp_Methods, 'APPEL', 1 ],
     [ Ident::Alias_PublicAttributes(), 'Count_Attributes', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Attributes, 'APPEL', 1 ],
     [ Ident::Alias_ProtectedAttributes(), 'Count_Attributes', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Attributes, 'APPEL', 1 ],
     [ Ident::Alias_PrivateProtectedAttributes(), 'Count_Attributes', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Attributes, 'APPEL', 1 ],
     [ Ident::Alias_BadDynamicClassDefinitions(), 'Count_BadDynamicClassDef', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_BadDynamicClassDef, 'APPEL', 1 ],
     [ Ident::Alias_ForbiddenOverloadedOperators(), 'Count_ForbiddenOverloadedOperators', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_ForbiddenOverloadedOperators, 'APPEL', 1 ],
     [ Ident::Alias_Friends(), 'Count_Friends', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Friends, 'APPEL', 1 ],
     [ Ident::Alias_FriendMethods(), 'Count_Friends', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Friends, 'APPEL', 1 ],
     [ Ident::Alias_FriendClasses(), 'Count_Friends', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Friends, 'APPEL', 1 ],
     [ Ident::Alias_MultipleInheritances(), 'Count_Inheritances', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Inheritances, 'APPEL', 1 ],
     [ Ident::Alias_PrivateInheritances(), 'Count_Inheritances', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_Inheritances, 'APPEL', 1 ],
     [ Ident::Alias_InlineMethods(), 'Count_InlineMethods', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_InlineMethods, 'APPEL', 1 ],
     [ Ident::Alias_MissingClassDestructor(), 'Count_MissingDtor', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MissingDtor, 'APPEL', 1 ],
     [ Ident::Alias_MissingClassConstructor(), 'Count_MissingCtor', 'CountC_CPP_FunctionsMethodsAttributes', \&CountC_CPP_FunctionsMethodsAttributes::Count_MissingCtor, 'APPEL', 1 ],
     [ Ident::Alias_CommentedOutCode(), 'CountCommentedOutCode', 'CountCommentedOutCode', \&CountCommentedOutCode::CountCommentedOutCode, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     [ Ident::Alias_BlankLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_CommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_AlphaNumCommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode_SansPrepro', 'CountCommun', \&CountCommun::CountLinesOfCode_SansPrepro, 'APPEL', 1 ],
     [ Ident::Alias_Include(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_While(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_For(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Continue(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Switch(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Default(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Goto(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Catch(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_New(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Delete(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_ReinterpretCasts(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Union(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_StructDefinitions(), 'CountKeywordsHpp', 'CountCpp', \&CountCpp::CountKeywordsHpp, 'APPEL', 1 ],
     [ Ident::Alias_Exit(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Malloc(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Calloc(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Realloc(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Strdup(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Free(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_Else(), 'CountKeywords', 'CountCpp', \&CountCpp::CountKeywords, 'APPEL', 1 ],
     [ Ident::Alias_MacroDefinitions(), 'CountConstantMacroDefinitions', 'CountCpp', \&CountCpp::CountConstantMacroDefinitions, 'APPEL', 1 ],
     [ Ident::Alias_ConstantMacroDefinitions(), 'CountConstantMacroDefinitions', 'CountCpp', \&CountCpp::CountConstantMacroDefinitions, 'APPEL', 1 ],
     [ Ident::Alias_AnonymousNamespaces(), 'CountAnonymousNamespaces', 'CountCpp', \&CountCpp::CountAnonymousNamespaces, 'APPEL', 1 ],
     [ Ident::Alias_HardCodedPaths(), 'CountHardCodedPaths', 'CountHardCodedPaths', \&CountHardCodedPaths::CountHardCodedPaths, 'APPEL', 1 ],
     [ Ident::Alias_IfPrepro(), 'CountIfPrepro', 'CountIfPrepro', \&CountIfPrepro::CountIfPrepro, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines100(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines132(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_MissingIncludeProtections(), 'CountMissingIncludeProtections', 'CountMissingIncludeProtections', \&CountMissingIncludeProtections::CountMissingIncludeProtections, 'APPEL', 1 ],
     [ Ident::Alias_Pragmas(), 'CountPragmas', 'CountPragmas', \&CountPragmas::CountPragmas, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
     [ Ident::Alias_Words(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 1 ],
     [ Ident::Alias_DistinctWords(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 1 ],

);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
     [ Ident::Alias_VG(), 'CountVG', 'CountCpp', \&CountCpp::CountVG, 'APPEL', 1 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
