package VbDotNet_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     [ Ident::Alias_BlankLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_CommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_AlphaNumCommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode_SansPrepro', 'CountCommun', \&CountCommun::CountLinesOfCode_SansPrepro, 'APPEL', 1 ],
     [ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines100(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_LongLines132(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
     [ Ident::Alias_CommentedOutCode(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousComments(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_WithoutSymbolNumerics(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_MagicNumbers(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_If(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_Else(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_Elsif(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_Next(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_UnparametrizedNext(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_While(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_Loop(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_Select(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_Default(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_Continue(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_Goto(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_Gosub(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_Exit(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_LogicalLinesOfCode(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_Try(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_Catch(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_EmptyCatches(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_OnError(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_BugPatterns(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_BugPatternsTrace(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_InstanceOf(), 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ 'Using_OptionStrictOn', 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ 'Using_OptionExplicitOn', 'CountVbDotNet', 'CountVbDotNet', \&CountVbDotNet::CountVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_ParamTags(), 'CountParam_Tags', 'CountVbDotNet', \&CountVbDotNet::CountParam_Tags, 'APPEL', 1 ],
     [ Ident::Alias_MultipleStatementsOnSameLine(), 'CountMultInst', 'CountVbDotNet', \&CountVbDotNet::CountMultInst, 'APPEL', 1 ],
     [ Ident::Alias_RiskyFunctionCalls(), 'CountRiskyFunctionCalls', 'CountVbDotNet', \&CountVbDotNet::CountRiskyFunctionCalls, 'APPEL', 1 ],
     [ Ident::Alias_IllegalStatements(), 'CountIllegalStatements', 'CountVbDotNet', \&CountVbDotNet::CountIllegalStatements, 'APPEL', 1 ],
     [ Ident::Alias_IllegalThrows(), 'CountIllegalThrows', 'CountVbDotNet', \&CountVbDotNet::CountIllegalThrows, 'APPEL', 1 ],
     [ Ident::Alias_Statements(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_NullStringComparisons(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_PrivateProtectedAttributes(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_PublicAttributes(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_BadDeclareUse(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_ImportAlias(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_ClassImplementations(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_ComplexConditions(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_For(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_ForEach(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodImplementations(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodDeclarations(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_PublicAttributes(), 'CountVbInstructionPatterns', 'CountVbInstructionPatterns', \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'APPEL', 1 ],
     [ Ident::Alias_Words(), 'CountWordsVbDotNet', 'CountWordsVbDotNet', \&CountWordsVbDotNet::CountWordsVbDotNet, 'APPEL', 1 ],
     [ Ident::Alias_DistinctWords(), 'CountWordsVbDotNet', 'CountWordsVbDotNet', \&CountWordsVbDotNet::CountWordsVbDotNet, 'APPEL', 1 ],

);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
     [ Ident::Alias_VG(), 'CountVG', 'CountVbDotNet', \&CountVbDotNet::CountVG, 'APPEL', 1 ],
     [ Ident::Alias_AndOr(), 'CountAndOr', 'CountWordsVbDotNet', \&CountWordsVbDotNet::CountAndOr, 'APPEL', 1 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
