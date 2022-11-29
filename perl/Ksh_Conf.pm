package Ksh_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_Words(), 'CountWords', 'CountKsh', \&CountKsh::CountWords, 'APPEL', 1 ],
     [ Ident::Alias_DistinctWords(), 'CountWords', 'CountKsh', \&CountKsh::CountWords, 'APPEL', 1 ],
     [ Ident::Alias_WithoutKshFirstLine(), 'Line1Ctrl', 'CountKsh', \&CountKsh::Line1Ctrl, 'APPEL', 1 ],
     [ Ident::Alias_WithoutKshFirstLine(), 'Line1Ctrl', 'CountKsh', \&CountKsh::Line1Ctrl, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountComments', 'CountKsh', \&CountKsh::CountComments, 'APPEL', 1 ],
     [ Ident::Alias_CommentedOutCode(), 'CountComments', 'CountKsh', \&CountKsh::CountComments, 'APPEL', 1 ],
     [ Ident::Alias_ModifiedIFS(), 'isIFSModified', 'CountKsh', \&CountKsh::isIFSModified, 'APPEL', 1 ],
     [ Ident::Alias_ModifiedIFS(), 'isIFSModified', 'CountKsh', \&CountKsh::isIFSModified, 'APPEL', 1 ],
     [ Ident::Alias_Getopt(), 'isGetoptUsed', 'CountKsh', \&CountKsh::isGetoptUsed, 'APPEL', 1 ],
     [ Ident::Alias_CheckedArgs(), 'ArgsNbrChecked', 'CountKsh', \&CountKsh::ArgsNbrChecked, 'APPEL', 1 ],
     [ Ident::Alias_LocalVariables(), 'DetectVarsFuncAlias', 'CountKsh', \&CountKsh::DetectVarsFuncAlias, 'APPEL', 1 ],
     [ Ident::Alias_ExportedVariables(), 'DetectVarsFuncAlias', 'CountKsh', \&CountKsh::DetectVarsFuncAlias, 'APPEL', 1 ],
     [ Ident::Alias_WellNamedLocalVariables(), 'DetectVarsFuncAlias', 'CountKsh', \&CountKsh::DetectVarsFuncAlias, 'APPEL', 1 ],
     [ Ident::Alias_ShortVarName(), 'DetectVarsFuncAlias', 'CountKsh', \&CountKsh::DetectVarsFuncAlias, 'APPEL', 1 ],
     [ Ident::Alias_Alias(), 'DetectVarsFuncAlias', 'CountKsh', \&CountKsh::DetectVarsFuncAlias, 'APPEL', 1 ],
     [ Ident::Alias_WellNamedExportedVariables(), 'DetectVarsFuncAlias', 'CountKsh', \&CountKsh::DetectVarsFuncAlias, 'APPEL', 1 ],
     [ Ident::Alias_FunctionMethodImplementations(), 'DetectVarsFuncAlias', 'CountKsh', \&CountKsh::DetectVarsFuncAlias, 'APPEL', 1 ],
     [ Ident::Alias_VariableDeclarations(), 'DetectVarsFuncAlias', 'CountKsh', \&CountKsh::DetectVarsFuncAlias, 'APPEL', 1 ],
     [ Ident::Alias_WellDeclaredVariables(), 'DetectVarsFuncAlias', 'CountKsh', \&CountKsh::DetectVarsFuncAlias, 'APPEL', 1 ],
     [ 'Nbr_CommentedVarFunc', 'DetectVarsFuncAlias', 'CountKsh', \&CountKsh::DetectVarsFuncAlias, 'APPEL', 0 ],
     [ Ident::Alias_IndentedLines(), 'CheckIndent', 'CountKsh', \&CountKsh::CheckIndent, 'APPEL', 1 ],
     [ Ident::Alias_Then(), 'CheckIndent', 'CountKsh', \&CountKsh::CheckIndent, 'APPEL', 1 ],
     [ Ident::Alias_Do(), 'CheckIndent', 'CountKsh', \&CountKsh::CheckIndent, 'APPEL', 1 ],
     [ Ident::Alias_Case(), 'CheckIndent', 'CountKsh', \&CountKsh::CheckIndent, 'APPEL', 1 ],
     [ Ident::Alias_Switch(), 'CheckIndent', 'CountKsh', \&CountKsh::CheckIndent, 'APPEL', 1 ],
     [ Ident::Alias_Default(), 'CheckIndent', 'CountKsh', \&CountKsh::CheckIndent, 'APPEL', 1 ],
     [ Ident::Alias_SuspiciousLastCase(), 'CheckIndent', 'CountKsh', \&CountKsh::CheckIndent, 'APPEL', 1 ],
     [ Ident::Alias_NotPureKsh(), 'CountNotPureKsh', 'CountKsh', \&CountKsh::CountNotPureKsh, 'APPEL', 1 ],
     [ Ident::Alias_Pipes(), 'CountPipes', 'CountKsh', \&CountKsh::CountPipes, 'APPEL', 1 ],
     [ Ident::Alias_MaxChainedPipes(), 'CountPipes', 'CountKsh', \&CountKsh::CountPipes, 'APPEL', 1 ],
     [ Ident::Alias_Background(), 'DetectBackground', 'CountKsh', \&CountKsh::DetectBackground, 'APPEL', 1 ],
     [ Ident::Alias_Exit(), 'CountFlow', 'CountKsh', \&CountKsh::CountFlow, 'APPEL', 1 ],
     [ Ident::Alias_WithoutValueExit(), 'CountFlow', 'CountKsh', \&CountKsh::CountFlow, 'APPEL', 1 ],
     [ Ident::Alias_WithoutFinalExit(), 'CountFlow', 'CountKsh', \&CountKsh::CountFlow, 'APPEL', 1 ],
     [ Ident::Alias_Break(), 'CountFlow', 'CountKsh', \&CountKsh::CountFlow, 'APPEL', 1 ],
     [ Ident::Alias_Continue(), 'CountFlow', 'CountKsh', \&CountKsh::CountFlow, 'APPEL', 1 ],
     [ Ident::Alias_MultipleStatementsOnSameLine(), 'CountMultInst', 'CountKsh', \&CountKsh::CountMultInst, 'APPEL', 1 ],
     [ Ident::Alias_BadTmpName(), 'DetectTmpFile', 'CountKsh', \&CountKsh::DetectTmpFile, 'APPEL', 1 ],

);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
     [ Ident::Alias_VG(), 'CountVG', 'CountKsh', \&CountKsh::CountVG, 'APPEL', 1 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
