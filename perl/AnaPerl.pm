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
# Description: Module d'analyse pour le langage Perl

package AnaPerl;

use strict;
use warnings;
use Erreurs;

use AnaUtils;
use StripPerl;
use Vues;

use CountBinaryFile;
use CountCommun;
use CountLongLines;
use CountCommentedOutCode;
use CountComplexConditions;
use CountAssignmentsInConditionalExpr;
use CountMissingBraces;
use CountMagicNumbers;
use CountSuspiciousComments;
use CountAndOr;
use CountWords;
use CountBadSpacing;
use CountComplexOperands;
use CountCommentsBlocs;
use CountMultInst;

sub Strip($$$$)
{
  my ($fichier, $vue, $options, $couples) = @_;

  my $status = 0;

  $status = StripPerl::StripPerl ($fichier, $vue, $options, $couples);

  if (($fichier ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'}) # dumpvues_filter_line
  {                                                                            # dumpvues_filter_line
    Vues::dump_vues( $fichier, $vue, $options);                                # dumpvues_filter_line
  }                                                                            # dumpvues_filter_line

  return $status;
}

my @TableCounters =
(
#  [ \&CountBinaryFile::CountBinaryFile, "CountBinaryFile::CountBinaryFile" ],
  [ \&CountCommun::CountCommun, "CountCommun::CountCommun", "APPEL" ],
  [ \&CountCommun::CountLinesOfCode, "CountCommun::CountLinesOfCode", "APPEL" ],
#  [ \&CountLongLines::CountLongLines, "CountLongLines::CountLongLines" ],
#  [ \&CountBreakLoop::CountBreakLoop, "CountBreakLoop::CountBreakLoop" ],
#  [ \&CountCommentedOutCode::CountCommentedOutCode, "CountCommentedOutCode::CountCommentedOutCode" ],
  #[ \&CountComplexConditions::CountComplexConditions, "CountComplexConditions::CountComplexConditions" ],
  #[ \&CountAssignmentsInConditionalExpr::CountAssignmentsInConditionalExpr, "CountAssignmentsInConditionalExpr::CountAssignmentsInConditionalExpr" ],
  #[ \&CountMissingBraces::CountMissingBraces, "CountMissingBraces::CountMissingBraces" ],
  #[ \&CountMagicNumbers::CountMagicNumbers,, "CountMagicNumbers::CountMagicNumbers" ],
  #[ \&CountAndOr::CountAndOr, "CountAndOr::CountAndOr" ],
  #[ \&CountWords::CountWords, "CountWords::CountWords" ],
  #[ \&CountBadSpacing::CountBadSpacing, "CountBadSpacing::CountBadSpacing" ],
  #[ \&CountComplexOperands::CountComplexOperands, "CountComplexOperands::CountComplexOperands" ],
  [ \&CountCommentsBlocs::CountCommentsBlocs, "CountCommentsBlocs::CountCommentsBlocs", "APPEL" ],
  #[ \&CountMultInst::CountMultInst, "CountMultInst::CountMultInst" ],

);

sub Count($$$$)
{
    my (  $fichier, $vue, $options, $couples) = @_;
    my $status = AnaUtils::Count( $fichier, $vue, $options, $couples, \@TableCounters);
    return $status;
}


sub FileTypeRegister ($)
{
  my ($options) = @_;

    AnaUtils::file_type_register("Perl", $options, \&Strip, \&Count);

}


sub Analyse($$$$)
{
    my ( $fichier, $vue, $options, $couples) = @_;
    my $status = 0 ;
	AnaUtils::load_ready();
    # FIXME: a valider
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

1;


