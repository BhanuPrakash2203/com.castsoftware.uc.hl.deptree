package JSP_Conf;

use strict;
use warnings;
use Ident;

our @table_Comptages = (
    # Diags for embedded java
	[ Ident::Alias_LinesOfCode(), 'CountLinesOfCode', 'JSP::CountJSP', \&JSP::CountJSP::CountLinesOfCode, 'APPEL', 1 ],
	[ Ident::Alias_ClassDefinitions(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
	[ Ident::Alias_FunctionMethodImplementations(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
	[ Ident::Alias_PrivateProtectedAttributes(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
	[ Ident::Alias_InterfaceDefinitions(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
	
	[ Ident::Alias_HeterogeneousEncoding(), 'CountBinaryFile', 'CountBinaryFile', \&CountBinaryFile::CountBinaryFile, 'APPEL', 1 ],
	[ Ident::Alias_RiskyCatches(), 'CountRiskyCatches', 'CountRiskyCatches', \&CountRiskyCatches::CountRiskyCatches, 'APPEL', 1 ],
	[ Ident::Alias_Instanceof(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
	[ Ident::Alias_EmptyCatches(), 'CountEmptyCatches', 'CountEmptyCatches', \&CountEmptyCatches::CountEmptyCatches, 'APPEL', 1 ],
	[ Ident::Alias_MagicNumbers(), 'CountMagicNumbers', 'CountMagicNumbers', \&CountMagicNumbers::CountMagicNumbers, 'APPEL', 1 ],
	[ Ident::Alias_PublicAttributes(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
	[ Ident::Alias_Continue(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
	[ Ident::Alias_Break(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
	[ Ident::Alias_BadSpacing(), 'CountBadSpacing', 'CountBadSpacing', \&CountBadSpacing::CountBadSpacing, 'APPEL', 1 ],
	[ Ident::Alias_BadAttributeNames(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
	[ Ident::Alias_BadClassNames(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
	[ Ident::Alias_BadMethodNames(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
	[ Ident::Alias_TernaryOperators(), 'CountTernaryOp', 'CountTernaryOp', \&CountTernaryOp::CountTernaryOp, 'APPEL', 1 ],
	[ Ident::Alias_MultipleStatementsOnSameLine(), 'CountMultInst', 'CountMultInst', \&CountMultInst::CountMultInst, 'APPEL', 1 ],
	[ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
	[ Ident::Alias_SuspiciousComments(), 'CountSuspiciousComments', 'CountSuspiciousComments', \&CountSuspiciousComments::CountSuspiciousComments, 'APPEL', 1 ],
	[ Ident::Alias_ShortAttributeNamesLT(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
	[ Ident::Alias_ShortClassNamesLT(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
	[ Ident::Alias_ShortMethodNamesLT(), 'CountFunctionsMethodsAttributes', 'CountJava_FunctionsMethodsAttributes', \&CountJava_FunctionsMethodsAttributes::CountFunctionsMethodsAttributes, 'APPEL', 1 ],
	[ Ident::Alias_CommentedOutCode(), 'CountCommentedOutCode', 'CountCommentedOutCode', \&CountCommentedOutCode::CountCommentedOutCode, 'APPEL', 1 ],
	[ Ident::Alias_If(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
	[ Ident::Alias_Else(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
	[ Ident::Alias_While(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
	[ Ident::Alias_For(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
	[ Ident::Alias_Switch(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
	[ Ident::Alias_Case(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
	[ Ident::Alias_Default(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
	[ Ident::Alias_Catch(), 'CountKeywords', 'Java::CountJava', \&Java::CountJava::CountKeywords, 'APPEL', 1 ],
	[ Ident::Alias_ComplexConditions(), 'CountComplexConditions', 'CountComplexConditions', \&CountComplexConditions::CountComplexConditions, 'APPEL', 1 ],
	[ Ident::Alias_AndOr(), 'CountAndOr', 'CountAndOr', \&CountAndOr::CountAndOr, 'APPEL', 1 ],
	[ Ident::Alias_Words(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 1 ],
	[ Ident::Alias_DistinctWords(), 'CountWords', 'CountWords', \&CountWords::CountWords, 'APPEL', 1 ],
	[ Ident::Alias_AssignmentsInConditionalExpr(), 'CountAssignmentsInConditionalExpr', 'CountAssignmentsInConditionalExpr', \&CountAssignmentsInConditionalExpr::CountAssignmentsInConditionalExpr, 'APPEL', 1 ],
	[ Ident::Alias_MissingBreakInSwitch(), 'CountBreakLoop', 'CountBreakLoop', \&CountBreakLoop::CountBreakLoop, 'APPEL', 1 ],
	[ Ident::Alias_BugPatterns(), 'CountBugPatterns', 'Java::CountJava', \&Java::CountJava::CountBugPatterns, 'APPEL', 1 ],
	[ Ident::Alias_RiskyFunctionCalls(), 'CountRiskyFunctionCalls', 'Java::CountJava', \&Java::CountJava::CountRiskyFunctionCalls, 'APPEL', 1 ],
	[ Ident::Alias_IllegalThrows(), 'CountIllegalThrows', 'Java::CountJava', \&Java::CountJava::CountIllegalThrows, 'APPEL', 1 ],
	[ Ident::Alias_MissingBraces(), 'CountMissingBraces', 'CountMissingBraces', \&CountMissingBraces::CountMissingBraces, 'APPEL', 1 ],
	[ Ident::Alias_ClassesComparisons(), 'CountClassComparaison', 'CountVulnerabilite', \&CountVulnerabilite::CountClassComparaison, 'APPEL', 1 ],
	[ Ident::Alias_OutOfFinallyJumps(), 'CountOutOfFinallyJumps', 'Java::CountJava', \&Java::CountJava::CountOutOfFinallyJumps, 'APPEL', 1 ],
	
	# diags for JSP:
	[ Ident::Alias_MissingErrorPage(), 'CountMissingErrorPage', 'JSP::CountJSP', \&JSP::CountJSP::CountMissingErrorPage, 'APPEL', 1 ],
	[ Ident::Alias_UnsecuredWebsite(), 'CountUnsecuredWebsite', 'JSP::CountJSP', \&JSP::CountJSP::CountUnsecuredWebsite, 'APPEL', 1 ],
	[ Ident::Alias_StdScriptlet(), 'CountJSP', 'JSP::CountJSP', \&JSP::CountJSP::CountJSP, 'APPEL', 1 ],
	[ Ident::Alias_XmlScriptlet(), 'CountJSP', 'JSP::CountJSP', \&JSP::CountJSP::CountJSP, 'APPEL', 1 ],
	[ Ident::Alias_StdDeclaration(), 'CountJSP', 'JSP::CountJSP', \&JSP::CountJSP::CountJSP, 'APPEL', 1 ],
	[ Ident::Alias_XmlDeclaration(), 'CountJSP', 'JSP::CountJSP', \&JSP::CountJSP::CountJSP, 'APPEL', 1 ],
	[ Ident::Alias_StdExpression(), 'CountJSP', 'JSP::CountJSP', \&JSP::CountJSP::CountJSP, 'APPEL', 1 ],
	[ Ident::Alias_XmlExpression(), 'CountJSP', 'JSP::CountJSP', \&JSP::CountJSP::CountJSP, 'APPEL', 1 ],
	[ Ident::Alias_StdDirective(), 'CountJSP', 'JSP::CountJSP', \&JSP::CountJSP::CountJSP, 'APPEL', 1 ],
	[ Ident::Alias_XmlDirective(), 'CountJSP', 'JSP::CountJSP', \&JSP::CountJSP::CountJSP, 'APPEL', 1 ],
	[ Ident::Alias_JSPComment(), 'CountJSP', 'JSP::CountJSP', \&JSP::CountJSP::CountJSP, 'APPEL', 1 ],
	[ Ident::Alias_JavaBean(), 'CountJSP', 'JSP::CountJSP', \&JSP::CountJSP::CountJSP, 'APPEL', 1 ],
	[ Ident::Alias_TagLib(), 'CountJSP', 'JSP::CountJSP', \&JSP::CountJSP::CountJSP, 'APPEL', 1 ],
	[ Ident::Alias_MissingCatch(), 'CountMissingCatch', 'JSP::CountJSP', \&JSP::CountJSP::CountMissingCatch, 'APPEL', 1 ],
	[ Ident::Alias_ImplicitClosing(), 'CountImplicitClosing', 'JSP::CountJSP', \&JSP::CountJSP::CountImplicitClosing, 'APPEL', 1 ],
	[ Ident::Alias_UntrustedInputData(), 'CountUntrustedInputData', 'JSP::CountJSP', \&JSP::CountJSP::CountUntrustedInputData, 'APPEL', 1 ],
	[ Ident::Alias_UnexpectedSimpleQuoteStr(), 'CountString', 'JSP::CountJSP', \&JSP::CountJSP::CountString, 'APPEL', 1 ],
	[ Ident::Alias_UnnecessaryDeclarationTag(), 'CountBadSequenceOrder', 'JSP::CountJSP', \&JSP::CountJSP::CountBadSequenceOrder, 'APPEL', 1 ],
	[ Ident::Alias_MissingSpaceInTag(), 'CountTags', 'JSP::CountJSP', \&JSP::CountJSP::CountTags, 'APPEL', 1 ],
	[ Ident::Alias_MixedTagFormat(), 'CountTags', 'JSP::CountJSP', \&JSP::CountJSP::CountTags, 'APPEL', 1 ],
	[ Ident::Alias_BadSequenceOrder(), 'CountBadSequenceOrder', 'JSP::CountJSP', \&JSP::CountJSP::CountBadSequenceOrder, 'APPEL', 1 ],
	[ Ident::Alias_TabIndentation(), 'CountIndentation', 'JSP::CountJSP', \&JSP::CountJSP::CountIndentation, 'APPEL', 1 ],
	[ Ident::Alias_MissingShortTag(), 'CountTags', 'JSP::CountJSP', \&JSP::CountJSP::CountTags, 'APPEL', 1 ],
	[ Ident::Alias_BadJavaScriptInclude(), 'CountTags', 'JSP::CountJSP', \&JSP::CountJSP::CountTags, 'APPEL', 1 ],
	[ Ident::Alias_HtmlComment(), 'CountTags', 'JSP::CountJSP', \&JSP::CountJSP::CountTags, 'APPEL', 1 ],
	[ Ident::Alias_MissingCDATA(), 'CountMissingCDATA', 'JSP::CountJSP', \&JSP::CountJSP::CountMissingCDATA, 'APPEL', 1 ],
	[ Ident::Alias_HtmlLOC(), 'CountHtmlLOC', 'JSP::CountJSP', \&JSP::CountJSP::CountHtmlLOC, 'APPEL', 1 ],
	[ Ident::Alias_BadFileExtension(), 'CountFragment', 'JSP::CountJSP', \&JSP::CountJSP::CountFragment, 'APPEL', 1 ],
	[ Ident::Alias_BadFileLocation(), 'CountFragment', 'JSP::CountJSP', \&JSP::CountJSP::CountFragment, 'APPEL', 1 ],
	[ Ident::Alias_BadTldLocation(), 'CountTld', 'JSP::CountJSP', \&JSP::CountJSP::CountTld, 'APPEL', 1 ],
	[ Ident::Alias_BadTldContent(), 'CountTld', 'JSP::CountJSP', \&JSP::CountJSP::CountTld, 'APPEL', 1 ],
	[ Ident::Alias_UselessTaglib(), 'CountDirective', 'JSP::CountDirective', \&JSP::CountDirective::CountDirective, 'APPEL', 1 ],
	[ Ident::Alias_StarImport(), 'CountDirective', 'JSP::CountDirective', \&JSP::CountDirective::CountDirective, 'APPEL', 1 ],
	[ Ident::Alias_StdSQLuse(), 'CountDirective', 'JSP::CountDirective', \&JSP::CountDirective::CountDirective, 'APPEL', 1 ],
	[ Ident::Alias_LongLines80(), 'CountLongLines', 'CountLongLines', \&CountLongLines::CountLongLines, 'APPEL', 1 ],
	[ Ident::Alias_MissingJSPComment(), 'CountMissingJSPComment', 'JSP::CountComment', \&JSP::CountComment::CountMissingJSPComment, 'APPEL', 1 ],
	[ Ident::Alias_UncommentedProperty(), 'CountUncommentedProperty', 'JSP::CountComment', \&JSP::CountComment::CountUncommentedProperty, 'APPEL', 1 ],
	[ Ident::Alias_MultipleComments(), 'CountMultipleComments', 'JSP::CountComment', \&JSP::CountComment::CountMultipleComments, 'APPEL', 1 ],
	[ Ident::Alias_LinesOfText(), 'CountLinesOfText', 'CountCommun', \&CountCommun::CountLinesOfText, 'APPEL', 1 ],
	[ Ident::Alias_LinesOfScript(), 'CountLinesOfScript', 'CountCommun', \&CountCommun::CountLinesOfScript, 'APPEL', 1 ],
);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
