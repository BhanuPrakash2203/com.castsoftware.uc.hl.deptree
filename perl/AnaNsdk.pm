#----------------------------------------------------------------------#
#                         @ISOSCOPE 2008                               #
#----------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                  #
#               Adresse : TERSUD - Bat A                               #
#                         5, AVENUE MARCEL DASSAULT                    #
#                         31500  TOULOUSE                              #
#               SIRET   : 410 630 164 00037                            #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Plugin
# Description: Ce paquetage permet d'effectuer des comptages pour le langage C#.

package AnaNsdk;

use strict;
use warnings;

use StripNsdk;
use Vues;
use CountNsdk ; #  comptages Nsdk
#use CountCommentedOutCode;
#use CountBreakLoop;
#use CountComplexConditions;
#use CountAssignmentsInConditionalExpr;
#use CountMissingBraces;
#use CountMagicNumbers;
use CountSuspiciousComments;
#use CountAndOr;
#use CountWords;
#use CountComplexOperands;
use CountCommentsBlocs;
use CountLongLines;
use AnaUtils;

sub Strip($$$$)
{
  my ($fichier, $vue, $options, $couples) =@_ ;

  my $status = 0;

  $status = StripNsdk::StripNsdk($fichier, $vue, $options, $couples) ;

  if (($fichier ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'}) # dumpvues_filter_line
  {                                                                            # dumpvues_filter_line
    Vues::dump_vues( $fichier, $vue, $options);                                # dumpvues_filter_line
  }                                                                            # dumpvues_filter_line

  return $status;
}


my @TableCounters =
(
  [ \&CountBinaryFile::CountBinaryFile , "CountBinaryFile::CountBinaryFile" ],
#  [ \&CountCommun::CountCommun , "CountCommun::CountCommun" ],
  #[ \&CountBreakLoop::CountBreakLoop , "\&CountBreakLoop::CountBreakLoop" ],
  [ \&CountNsdk::CountKeywords , "CountNsdk::CountKeywords" ],
  [ \&CountNsdk::CountContext , "CountNsdk::CountContext" ],
  [ \&CountNsdk::CountCommentedOutCode , "CountNsdk::CountCommentedOutCode" ],
  [ \&CountNsdk::CountKeywordCase , "CountNsdk::CountKeywordCase" ],
  #[ \&CountComplexConditions::CountComplexConditions , "\&CountComplexConditions::CountComplexConditions" ],
  [ \&CountNsdk::CountMagicNumbers , "CountNsdk::CountMagicNumbers" ],
  [ \&CountSuspiciousComments::CountSuspiciousComments , "CountSuspiciousComments::CountSuspiciousComments" ],
#  [ \&CountAndOr::CountAndOr , "CountAndOr::CountAndOr" ],
#  [ \&CountWords::CountWords , "CountWords::CountWords" ],
#  [ \&CountBadSpacing::CountBadSpacing , "\&CountBadSpacing::CountBadSpacing" ],
#  [ \&CountComplexOperands::CountComplexOperands , "\&CountComplexOperands::CountComplexOperands" ],
  [ \&CountNsdk::CountCommentsBlocs , "CountNsdk::CountCommentsBlocs" ],
  [ \&CountNsdk::CountCodeLines , "CountNsdk::CountCodeLines" ],
  [ \&CountNsdk::CountBadSpacing , "CountNsdk::CountBadSpacing" ],
  [ \&CountNsdk::CountWords , "CountNsdk::CountWords" ],
  [ \&CountNsdk::CheckIndent , "CountNsdk::CheckIndent" ],
  [ \&CountLongLines::CountLongLines , "CountLongLines::CountLongLines" ],
  [ \&CountNsdk::CountVG , "CountNsdk::CountVG" ],
#    \&CountNode::CountNode,
);

# Obsolete ? (cf. detection automatique par AnaUtils::file_type_register)
my @TableMnemos = (
    Ident::Alias_AndOr(),
    "Nbr_BadLineContinuation",
    Ident::Alias_BadLogicIndents(),
    Ident::Alias_BadSpacing(),
#    Ident::Alias_BlankLines(),
    Ident::Alias_Break(),
#    Ident::Alias_BugPatterns(),
    Ident::Alias_Case(),
    Ident::Alias_AlphaNumCommentLines(),
    Ident::Alias_CommentedOutCode(),
    Ident::Alias_CommentLines(),
    Ident::Alias_CommentBlocs(),
    Ident::Alias_ComplexConditions(),
#    Ident::Alias_ComplexOperands(),
    Ident::Alias_ConstantDefinitions(),
    Ident::Alias_Continue(),
    "Nbr_ContinuationChar",
    Ident::Alias_Default(),
    Ident::Alias_Delete(),
    Ident::Alias_DiffUpdate(),
    Ident::Alias_DistinctWords(),
    Ident::Alias_Dynamic(),
    Ident::Alias_Else(),
    Ident::Alias_Elsif(),
    Ident::Alias_Exit(),
    Ident::Alias_WithExitFunctions(),
    Ident::Alias_Fill(),
    Ident::Alias_For(),
    Ident::Alias_FunctionMethodImplementations(),
    Ident::Alias_ApplicationGlobalVariables(),
    Ident::Alias_Halt(),
    Ident::Alias_HeterogeneousEncoding(),
    Ident::Alias_If(),
    Ident::Alias_IndentedLines(),
    Ident::Alias_Keywords(),
    "Nbr_Lines",
    Ident::Alias_LinesOfCode(),
    Ident::Alias_LoadDLL(),
    Ident::Alias_LongLines100(),
    Ident::Alias_LongLines132(),
    Ident::Alias_LongLines80(),
    Ident::Alias_Loop(),
    Ident::Alias_MagicNumbers(),
    Ident::Alias_MaxParameters(),
    Ident::Alias_WithTooMuchParametersMethods(),
    Ident::Alias_MissingDefaults(),
    Ident::Alias_Mov(),
    Ident::Alias_MultipleDeclarationsInSameStatement(),
    Ident::Alias_New(),
    Ident::Alias_BadCaseKeyword(),
    Ident::Alias_OddSetptr(),
    Ident::Alias_Repeat(),
#    Ident::Alias_ReturnTags(),
    Ident::Alias_Segments(),
    Ident::Alias_ShortConstNamesLT(),
    Ident::Alias_ShortGlobalNamesLT(),
    Ident::Alias_ShortMethodNamesLT(),
    Ident::Alias_ShortSegmentNamesLT(),
    Ident::Alias_SuspiciousComments(),
    Ident::Alias_Switch(),
    Ident::Alias_TotalLogicIndents(),
    Ident::Alias_TotalParameters(),
    Ident::Alias_UnloadDLL(),
    Ident::Alias_While(),
    Ident::Alias_Words(),
#    Ident::Alias_BadClassNames(),
#    Ident::Alias_BadDeclarationOrder(),
#    Ident::Alias_BadMethodNames(),
#    Ident::Alias_ShortAttributeNamesHT(),
#    Ident::Alias_ShortAttributeNamesLT(),
#    Ident::Alias_ShortClassNamesHT(),
#    Ident::Alias_ShortClassNamesLT(),
#    Ident::Alias_ShortMethodNamesHT(),
);


sub Count($$$$)
{
    my (  $fichier, $vue, $options, $couples) = @_;
    my $status = 0;
    $status |= AnaUtils::Count( $fichier, $vue, $options, $couples, \@TableCounters);
    return $status;
}


sub FileTypeRegister ($)
{
  my ($options) = @_;
  my $type = "Nsdk";
  
  AnaUtils::file_type_register($type, $options, \&Strip, \&Count);
}


sub Analyse($$$$)
{
    my ( $fichier, $vue, $options, $couples) = @_;
    my $status = 0;

  FileTypeRegister($options);
    $status = Strip( $fichier, $vue, $options, $couples);

    if (defined $options->{'--nocount'})
    {
      return $status;
    }

    if ($status == 0)
    {
        $status |= Count($fichier, $vue, $options, $couples);
    }
    else
    {
        print STDERR "$fichier : Echec de pre-traitement\n";
    }
    return $status ;

}

# Un alias
sub AnaNsdk($$$$)
{
    my ( $fichier, $vues, $options, $couples) = @_;
    return Analyse ( $fichier, $vues, $options, $couples);
}

1;

