package TestWrapper;

use strict;
use warnings;

use StripAbap;
use Abap::CountAbap;
use Abap::CountSelect;
use Abap::CountRoutines;
use Cpp::CountClass;
use Cpp::CountRoutine;
use Cpp::CountVariable;
use Python::CountException;

# get the directory from where the TestWrapper is executing:
my $BASE_DIR = __FILE__;
$BASE_DIR =~ s/[\\\/]?TestWrapper.pm$//m;
my $BASE_DIR_pattern = quotemeta $BASE_DIR;


my %Wrapper = (
	#-------------------- GENERAL -----------------------------
	'Lib::Node::dumpTree' => \&Lib::Node::dumpTree,
	'StripPHP::separer_code_commentaire_chaine' => \&StripPHP::separer_code_commentaire_chaine,
	'StripJS::removeHTMLComment' => \&StripJS::removeHTMLComment,

	#-------------------- ABAP -----------------------------
	'StripAbap::StripAbap' => \&StripAbap::StripAbap,
	'Abap::Parse::Parse'   => \&Abap::Parse::Parse,
	'Abap::CountAbap::CountKeywords' => \&Abap::CountAbap::CountKeywords,
	'Abap::CountAbap::CountReadTable' => \&Abap::CountAbap::CountReadTable,
	'Abap::CountSelect::CountSelect' => \&Abap::CountSelect::CountSelect,
	'Abap::CountSelect::CountDynamicQueries' => \&Abap::CountSelect::CountDynamicQueries,
	'Abap::CountSelect::CountNestedSelect' => \&Abap::CountSelect::CountNestedSelect,
	'Abap::CountSelect::CountSubqueries' => \&Abap::CountSelect::CountSubqueries,
	'Abap::CountSelect::CountStandardTableModifications' => \&Abap::CountSelect::CountStandardTableModifications,
	'Abap::CountAbap::CountCodeCheckDisabling' => \&Abap::CountAbap::CountCodeCheckDisabling,
	'Abap::CountAbap::CountBadProgramNames' => \&Abap::CountAbap::CountBadProgramNames,
	'Abap::CountAbap::CountMissingDefaults' => \&Abap::CountAbap::CountMissingDefaults,
	'Abap::CountAbap::CountEmptyCatches' => \&Abap::CountAbap::CountEmptyCatches,
	'Abap::CountAbap::CountToManyNestedLoop' => \&Abap::CountAbap::CountToManyNestedLoop,
	'Abap::CountAbap::CountUncheckedReturn' => \&Abap::CountAbap::CountUncheckedReturn,
	'Abap::CountAbap::CountTestUnameAgainstSpecificValue' => \&Abap::CountAbap::CountTestUnameAgainstSpecificValue,
	'Abap::CountAbap::CountAtInLoopAtWhere' => \&Abap::CountAbap::CountAtInLoopAtWhere,
	'Abap::CountAbap::CountHardCodedValues' => \&Abap::CountAbap::CountHardCodedValues,
	'Abap::CountAbap::CountHardCodedPaths' => \&Abap::CountAbap::CountHardCodedPaths,
	'Abap::CountRoutines::CountRoutines' => \&Abap::CountRoutines::CountRoutines,
	'CountCommentsBlocs::CountCommentsBlocs_agglo' => \&CountCommentsBlocs::CountCommentsBlocs_agglo,
        'Abap::CountComments::CountUnCommentedRoutines' => \&Abap::CountComments::CountUnCommentedRoutines,

	#-------------------- PHP -----------------------------
	'StripPHP::StripPHP' => \&StripPHP::StripPHP,
        'PHP::Parse::Parse' => \&PHP::Parse::Parse,
        'PHP::CountLoop::CountLoop' => \&PHP::CountLoop::CountLoop,
        'PHP::CountLoop::CountIncrementerJumblingInLoop' => \&PHP::CountLoop::CountIncrementerJumblingInLoop,
        'PHP::CountCondition::CountCondition' => \&PHP::CountCondition::CountCondition,
        'PHP::CountCondition::CountUnconditionalCondition' => \&PHP::CountCondition::CountUnconditionalCondition,
        'PHP::CountExpression::CountExpression' => \&PHP::CountExpression::CountExpression,
        'PHP::CountPHP::CountEmptyStatementBloc' => \&PHP::CountPHP::CountEmptyStatementBloc,
        'PHP::CountPHP::CountUpperCaseKeywords' => \&PHP::CountPHP::CountUpperCaseKeywords,
        'PHP::CountPHP::CountUnnecessaryConcat' => \&PHP::CountPHP::CountUnnecessaryConcat,
        'PHP::CountPHP::CountBadFileNames' => \&PHP::CountPHP::CountBadFileNames,
        'PHP::CountPHP::CountRequiredParamsBeforeOptional' => \&PHP::CountPHP::CountRequiredParamsBeforeOptional,
        'PHP::CountPHP::CountToManyNestedLoop' => \&PHP::CountPHP::CountToManyNestedLoop,
        'PHP::CountClass::CountClass' => \&PHP::CountClass::CountClass,
        'PHP::CountClass::CountUnassignedObjectInstanciation' => \&PHP::CountClass::CountUnassignedObjectInstanciation,
        'PHP::CountComments::CountMissingEndComment' => \&PHP::CountComments::CountMissingEndComment,
        'PHP::CountComments::CountEmptyCatches' => \&PHP::CountComments::CountEmptyCatches,
        'PHP::CountComments::CountArtifacts' => \&PHP::CountComments::CountArtifacts,
        'PHP::CountComments::CountRootComment' => \&PHP::CountComments::CountRootComment,
        'PHP::CountFunctions::CountFunctions' => \&PHP::CountFunctions::CountFunctions,
        'PHP::CountSQL::CountSQL' => \&PHP::CountSQL::CountSQL,
        'CountLongLines::CountLongLines_CodeComment' => \&CountLongLines::CountLongLines_CodeComment,
	#-------------------- Cpp -----------------------------
	'StripCpp::StripCpp' => \&StripCpp::StripCpp,
#'CountC_CPP_FunctionsMethodsAttributes::Parse' => \&CountC_CPP_FunctionsMethodsAttributes::Parse,
        'AnaCpp::Parse' => \&AnaCpp::Parse,
        'Cpp::CountClass::CountWithoutVirtualDestructorAbstractClass' => \&Cpp::CountClass::CountWithoutVirtualDestructorAbstractClass,
        'Cpp::CountClass::CountAttributes' => \&Cpp::CountClass::CountAttributes,
        'AnaCpp::isCopyConstructor' => \&AnaCpp::isCopyConstructor,
        'AnaCpp::isCopyAssignmentOperator' => \&AnaCpp::isCopyAssignmentOperator,
        # 'Cpp::CountClass::CountRuleOf3' => \&Cpp::CountClass::CountRuleOf3,
        # 'Cpp::CountClass::CountWhithoutPrivateDefaultConstructorUtilityClass' => \&Cpp::CountClass::CountWhithoutPrivateDefaultConstructorUtilityClass,
       # 'Cpp::CountClass::CountStaticGlobalVariableInHeader' => \&Cpp::CountClass::CountStaticGlobalVariableInHeader,
        'Cpp::CountClass::CountIllegalOperatorOverload' => \&Cpp::CountClass::CountIllegalOperatorOverload,
        'Cpp::CountClass::CountCopyAssignableAbstractClass' => \&Cpp::CountClass::CountCopyAssignableAbstractClass,
        'Cpp::CountFile::CountWithoutInterfaceImplementation' => \&Cpp::CountFile::CountWithoutInterfaceImplementation,
        'Cpp::CountFile::CountCallToBlockingFunction' => \&Cpp::CountFile::CountCallToBlockingFunction,
        'Cpp::CountVariable::CountGlobalVariable' => \&Cpp::CountVariable::CountGlobalVariable,
        'CountCpp::CountKeywords' => \&CountCpp::CountKeywords,
        'Cpp::CountNaming::CountAttributeName' => \&Cpp::CountNaming::CountAttributeName,
        'Cpp::CountNaming::CountMethodName' => \&Cpp::CountNaming::CountMethodName,
        'Cpp::CountNaming::CountClassName' => \&Cpp::CountNaming::CountClassName,
        'Cpp::CountClass::CountClass' => \&Cpp::CountClass::CountClass,
        'Cpp::CountRoutine::CountRoutine' => \&Cpp::CountRoutine::CountRoutine,
        'Cpp::CountComment::CountComment' => \&Cpp::CountComment::CountComment,
	#-------------------- ObjC -----------------------------
        'ObjC::ParseObjC::Parse' => \&ObjC::ParseObjC::Parse,
        'ObjC::CountInterface::CountUnexpectedIvar' => \&ObjC::CountInterface::CountUnexpectedIvar,
        'ObjC::CountInterface::CountInterface' => \&ObjC::CountInterface::CountInterface,
        'ObjC::CountCondition::CountCondition' => \&ObjC::CountCondition::CountCondition,
        'ObjC::CountFunction::CountFunction' => \&ObjC::CountFunction::CountFunction,
        'ObjC::CountFunctionCall::CountFunctionCall' => \&ObjC::CountFunctionCall::CountFunctionCall,
        'ObjC::CountBlock::CountBlock' => \&ObjC::CountBlock::CountBlock,
        'ObjC::CountObjC::CountKeywords' => \&ObjC::CountObjC::CountKeywords,
        'ObjC::CountObjC::CountMissingBoxedOrLiteral' => \&ObjC::CountObjC::CountMissingBoxedOrLiteral,
        'ObjC::CountObjC::CountWithoutInterfaceImplementation' => \&ObjC::CountObjC::CountWithoutInterfaceImplementation,
        'ObjC::CountNaming::CountNaming' => \&ObjC::CountNaming::CountNaming,
	#-------------------- TSQL -----------------------------
        'TSql::CountSQL::is_CanonicalObjectIdent' => \&TSql::CountSQL::is_CanonicalObjectIdent,
	#-------------------- JS -----------------------------
        'StripJS::StripJS' => \&StripJS::StripJS,
        'JS::ParseJS::Parse' => \&JS::ParseJS::Parse,
        'JS::CountLoop::CountLoop' => \&JS::CountLoop::CountLoop,
        'JS::CountJS::CountExpression' => \&JS::CountJS::CountExpression,
        'JS::CountComment::CountIEConditionalComments' => \&JS::CountComment::CountIEConditionalComments,
        'JS::CountCondition::CountCondition' => \&JS::CountCondition::CountCondition,
        'JS::CountFunction::CountFunction' => \&JS::CountFunction::CountFunction,
        'JS::CountFunction::CountMisplacedFunctionDecl' => \&JS::CountFunction::CountMisplacedFunctionDecl,
        'JS::CountFunction::CountMissingImmediateFuncCallWrapping' => \&JS::CountFunction::CountMissingImmediateFuncCallWrapping,
        'JS::CountJS::CountKeywords' => \&JS::CountJS::CountKeywords,
        'JS::CountJS::CountMultilineReturn' => \&JS::CountJS::CountMultilineReturn,
        'JS::CountJS::CountSwitch' => \&JS::CountJS::CountSwitch,
        'JS::CountJS::CountUnauthorizedPrototypeModification' => \&JS::CountJS::CountUnauthorizedPrototypeModification,
        'JS::CountJS::CountMagicNumbers' => \&JS::CountJS::CountMagicNumbers,
        'JS::CountString::CountString' => \&JS::CountString::CountString,
        'JS::CountNaming::CountNaming' => \&JS::CountNaming::CountNaming,
        'JS::CountVariable::CountVariable' => \&JS::CountVariable::CountVariable,
        'JS::CountVariable::CountMultipleDeclarations' => \&JS::CountVariable::CountMultipleDeclarations,
        'JS::CountJS::CountMissingInstructionSeparator' => \&JS::CountJS::CountMissingInstructionSeparator,
        'JS::CountJS::CountBadSpacing' => \&JS::CountJS::CountBadSpacing,
        'JS::CountJS::CountArtifact' => \&JS::CountJS::CountArtifact,
	#-------------------- Cobol -----------------------------
	'Cobol::CobolCommon::ParseParagraphs' => \&Cobol::CobolCommon::ParseParagraphs,
	'Cobol::Vue::PrepareBuffer' => \&Cobol::Vue::PrepareBuffer,
	'CheckCobol::CheckCodeAvailability' => \&CheckCobol::CheckCodeAvailability,
	'StripCobol::StripCobol' => \&StripCobol::StripCobol,
	'AnaCobol::CountCobol' => \&AnaCobol::CountCobol,
		#-------------------- JSP -----------------------------
        'StripJSP::StripJSP' => \&StripJSP::StripJSP,
        'JSP::CountJSP::CountMissingErrorPage' => \&JSP::CountJSP::CountMissingErrorPage,
        'JSP::CountJSP::CountUnsecuredWebsite' => \&JSP::CountJSP::CountUnsecuredWebsite,
        'JSP::CountJSP::CountJSP' => \&JSP::CountJSP::CountJSP,
        'JSP::CountJSP::CountFragment' => \&JSP::CountJSP::CountFragment,
        'JSP::CountJSP::CountTld' => \&JSP::CountJSP::CountTld,
        'JSP::CountJSP::CountHtmlLOC' => \&JSP::CountJSP::CountHtmlLOC,
        'JSP::CountJSP::CountMissingCDATA' => \&JSP::CountJSP::CountMissingCDATA,
        'JSP::CountJSP::CountBadSequenceOrder' => \&JSP::CountJSP::CountBadSequenceOrder,
        'JSP::CountJSP::CountIndentation' => \&JSP::CountJSP::CountIndentation,
        'JSP::CountJSP::CountTags' => \&JSP::CountJSP::CountTags,
        'JSP::CountJSP::CountString' => \&JSP::CountJSP::CountString,
        'JSP::GlobalMetrics::checkTldContent' => \&JSP::GlobalMetrics::checkTldContent,
        'JSP::GlobalMetrics::checkTldLocation' => \&JSP::GlobalMetrics::checkTldLocation,
        'JSP::CountDirective::CountDirective' => \&JSP::CountDirective::CountDirective,
        'JSP::CountComment::CountMissingJSPComment' => \&JSP::CountComment::CountMissingJSPComment,
        'JSP::CountComment::CountMultipleComments' => \&JSP::CountComment::CountMultipleComments,
        'JSP::CountComment::CountUncommentedProperty' => \&JSP::CountComment::CountUncommentedProperty,
        'CountLongLines::CountLongLines' => \&CountLongLines::CountLongLines,
        'JSP::GlobalMetrics::checkSecured' => \&JSP::GlobalMetrics::checkSecured,
        'JSP::CountJSP::CountUntrustedInputData' => \&JSP::CountJSP::CountUntrustedInputData,
        'JSP::CountJSP::CountMissingCatch' => \&JSP::CountJSP::CountMissingCatch,
        'JSP::CountJSP::CountImplicitClosing' => \&JSP::CountJSP::CountImplicitClosing,
        
        
        #-------------------- Pl/Sql -----------------------------
        'StripPlSql::StripPlSql' => \&StripPlSql::StripPlSql,
        'PlSql::Parse::Parse' => \&PlSql::Parse::Parse,
        'PlSql::CountReturnRoutines::CountReturnRoutines' => \&PlSql::CountReturnRoutines::CountReturnRoutines,
        'AnaPlSql::Strip' => \&AnaPlSql::Strip,
        
        #-------------------- Python -----------------------------
        'StripPython::StripPython' => \&StripPython::StripPython,
        'Python::ParsePython::Parse' => \&Python::ParsePython::Parse,
        'Python::CountComment::CountUnCommentedArtifact' => \&Python::CountComment::CountUnCommentedArtifact,
        'Python::CountComment::CountComments' => \&Python::CountComment::CountComments,
        'Python::CountException::CountExceptions' => \&Python::CountException::CountExceptions,
        'Python::CountException::CountRaise' => \&Python::CountException::CountRaise,
        'Python::CountException::CountTry' => \&Python::CountException::CountTry,
        'Python::CountVariable::CountVariables' => \&Python::CountVariable::CountVariables,
        'Python::CountVariable::CountVariablesHidding' => \&Python::CountVariable::CountVariablesHidding,
        'Python::CountFunction::CountFunctions' => \&Python::CountFunction::CountFunctions,
        'Python::CountVariable::CountVariablesHidding' => \&Python::CountVariable::CountVariablesHidding,
        'Python::CountClass::CountClasses' => \&Python::CountClass::CountClasses,
        'Python::CountImport::CountImports' => \&Python::CountImport::CountImports,
        'Python::CountCondition::CountConditions' => \&Python::CountCondition::CountConditions,
        'Python::CountCode::CountCode' => \&Python::CountCode::CountCode,
        'Python::CountString::CountStrings' => \&Python::CountString::CountStrings,
        
        #-------------------- CS -----------------------------
        'StripCS::StripCS' => \&StripCS::StripCS,
        'CountCS::CountMetrics' => \&CountCS::CountMetrics,
        
        #-------------------- framework -----------------------------
        'framework::version::makeComparable' => \&framework::version::makeComparable,
        'framework::version::compareVersion' => \&framework::version::compareVersion,
        
        #-------------------- Java -----------------------------
        'StripJava::StripJava' => \&StripJava::StripJava,

        #-------------------- VbDotNet -----------------------------
        'StripVbDotNet::StripVbDotNet' => \&StripVbDotNet::StripVbDotNet,

        #-------------------- TSql -----------------------------
        'StripTSql::StripTSql' => \&StripTSql::StripTSql,
        
        #-------------------- Typescript -----------------------------
        'StripTypescript::StripTypescript' => \&StripTypescript::StripTypescript,
        'TypeScript::ParseTypeScript::Parse' => \&TypeScript::ParseTypeScript::Parse,
        'TypeScript::CountCondition::CountCondition' => \&TypeScript::CountCondition::CountCondition,
        'TypeScript::CountTypeScript::CountSwitch' => \&TypeScript::CountTypeScript::CountSwitch,
        'TypeScript::CountVariable::CountMultipleDeclarations' => \&TypeScript::CountVariable::CountMultipleDeclarations,
        'TypeScript::CountTypeScript::CountOperator' => \&TypeScript::CountTypeScript::CountOperator,
        'TypeScript::CountParameter::CountParameter' => \&TypeScript::CountParameter::CountParameter,
        'TypeScript::CountTypeScript::CountError' => \&TypeScript::CountTypeScript::CountError,
        'TypeScript::CountClass::CountInterface' => \&TypeScript::CountClass::CountInterface,
        'TypeScript::CountString::CountString' => \&TypeScript::CountString::CountString,
        'TypeScript::CountException::CountException' => \&TypeScript::CountException::CountException,
        'TypeScript::CountFunction::CountFunction' => \&TypeScript::CountFunction::CountFunction,
        'TypeScript::CountTypeScript::CountKeywords' => \&TypeScript::CountTypeScript::CountKeywords,
        'TypeScript::CountClass::CountAttribute' => \&TypeScript::CountClass::CountAttribute,
        'TypeScript::CountLoop::CountLoop' => \&TypeScript::CountLoop::CountLoop,
        'TypeScript::CountTypeScript::CountArtifact' => \&TypeScript::CountTypeScript::CountArtifact,
        'TypeScript::CountComment::CountIEConditionalComments' => \&TypeScript::CountComment::CountIEConditionalComments,
        'TypeScript::CountFunction::CountMisplacedFunctionDecl' => \&TypeScript::CountFunction::CountMisplacedFunctionDecl,
        'TypeScript::CountNaming::CountNaming' => \&TypeScript::CountNaming::CountNaming,
        'TypeScript::CountClass::CountClass' => \&TypeScript::CountClass::CountClass,
        'TypeScript::CountVariable::CountVariable' => \&TypeScript::CountVariable::CountVariable,
        'TypeScript::CountTypeScript::CountMultilineReturn' => \&TypeScript::CountTypeScript::CountMultilineReturn,
        'TypeScript::CountTypeScript::CountMissingInstructionSeparator' => \&TypeScript::CountTypeScript::CountMissingInstructionSeparator,
        'TypeScript::CountFunction::CountMissingImmediateFuncCallWrapping' => \&TypeScript::CountFunction::CountMissingImmediateFuncCallWrapping,
        'TypeScript::CountTypeScript::CountBreakInLoop' => \&TypeScript::CountTypeScript::CountBreakInLoop,
        'CountCommun::CountLinesOfCode_agglo' => \&CountCommun::CountLinesOfCode_agglo,
        'TypeScript::CountTypeScript::CountUnauthorizedPrototypeModification' => \&TypeScript::CountTypeScript::CountUnauthorizedPrototypeModification,
        
        #-------------------- Groovy -----------------------------
        'StripGroovy::StripGroovy' => \&StripGroovy::StripGroovy,
        'Groovy::ParseGroovy::Parse' => \&Groovy::ParseGroovy::Parse,

        #-------------------- Swift -----------------------------
        'StripSwift::StripSwift' => \&StripSwift::StripSwift,

        #-------------------- Kotlin -----------------------------
        'StripKotlin::StripKotlin' => \&StripKotlin::StripKotlin,
        
        #-------------------- Clojure -----------------------------
        'StripClojure::StripClojure' => \&StripClojure::StripClojure,
        
        #-------------------- Scala -----------------------------
        'StripScala::StripScala' => \&StripScala::StripScala,

        );

sub wrapper_call($;$$$$) {
  my @args = @_ ;
  my $func = shift @args;

	# CHECK if the function is passed as a function pointer.
	# If yes, no need to wrap, call it directly (if it belongs to the Highlight source code only !!)
	if (ref $func eq 'CODE') {
		
		# call the function
		return $func->(@args);

		# Following code is useless but keep it inactive as an example of introspection usage ...
if (0) {
		# call to the introspector, thanks to "Perl Hacks: Tips & Tools for Programming, Debugging, and Surviving" at the O'REILLY editions
		# https://books.google.fr/books?id=CLKbAgAAQBAJ&pg=PA199&lpg=PA199&dq=perl+use+B+svref_2object&source=bl&ots=0RaqlIwtKB&sig=k6MnRTX4ee4Atzf-zK94keiId5M&hl=fr&sa=X&ved=0ahUKEwjj2ouQ5tvWAhXqKcAKHW6CByoQ6AEIRjAE#v=onepage&q=perl%20use%20B%20svref_2object&f=false
		use B qw(svref_2object);
		my $cv = svref_2object ( $func );
		
		# 1 - The STASH() method of the B::CV object returns the typeglob representing the package's namespace.
		#      -> calling NAME() on this returns the package name.
		# 2 - The FILE() method returns the name of the file containing the function
		# 3 - The GV() method returns the particular symbol table entry for this function, in which the LINE() method returns the line of the file
		#     corresponding to the start of the function.
		
		# Remove the Analyzer base dir from the path of the file in which the function is declared :
		my $fullFilePath = $cv->FILE();
		$fullFilePath =~ s/[\\\/]?[^\\\/]*$//m;
		my $relativeFilePath = "";
		if ( $fullFilePath =~ /^$BASE_DIR_pattern(.*)/m) {
			$relativeFilePath = $1;
			# remove all trailing "\" or "/"
			$relativeFilePath =~ s/[\\\/]*$//m;
		}
		else {
			print STDERR "WARNING : the file ". $cv->FILE() ." do not belong to Highlight, cannot be called by the wrapper !!!!\n";
			return
		}
		
		# Build module name:
		my $packageName = $cv->STASH->NAME();
		my $module = $relativeFilePath;
		$module =~ s/[\\\/]/::/g;
		if ($module eq "") {
			$module = $packageName;
		}
		else {
			$module .= "::" . $packageName;
		}

		my $functionName = $cv->GV->NAME();
		
		# load the module :
		print STDERR "LOADING $module ...\n";

		eval {require "$module.pm";};
		if ($@)	{
			print STDERR "[WARNING] TestWrapper is unable to load module: $module, so cannot call ${module}::${functionName}() ($@)\n" ;
			return ;
		}
} # end of desctivated code ...
	}
	else {
		if (exists $Wrapper{$func}) {
			return $Wrapper{$func}->(@args);
		}
		else {
			print "[WRAPPER v1.0] ERROR : unknow function : $func\n";
		}
	}
}

1;


