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
# DESCRIPTION: Module d'analyse pour Vb.net
#----------------------------------------------------------------------#

package AnaVbDotNet;

use strict;
use warnings;

use StripVbDotNet ; # parser vb
use AnaUtils;
use Vues;
use IsoscopeDataFile;

use CountVbDotNet ; #  comptages vb
use CountBinaryFile ; #  comptages vb
use CountCommun  ; #  comptages communs
use CountLongLines  ; #  comptages communs
use CountWordsVbDotNet  ; #  comptages mots pour le Vb.net
use CountVbInstructionPatterns;
use CountCommentsBlocs;

use CloudReady::CountDotnet;
use CloudReady::detection;


my @TableCounters =
(
  [ \&CountBinaryFile::CountBinaryFile, "\&CountBinaryFile::CountBinaryFile" ],

  #Comptage fait en premier, pour creer la vue words.
  [ \&CountWordsVbDotNet::CountWordsVbDotNet, "CountWordsVbDotNet::CountWordsVbDotNet" ],

  [ \&CountVbDotNet::CountVbDotNet, "CountVbDotNet::CountVbDotNet" ],
  [ \&CountVbDotNet::CountParam_Tags, "CountVbDotNet::CountParam_Tags" ],
  [ \&CountCommun::CountCommun, "CountCommun::CountCommun" ],
  [ \&CountCommun::CountLinesOfCode, "CountCommun::CountLinesOfCode" ],
  [ \&CountLongLines::CountLongLines, "CountLongLines::CountLongLines" ],
  #[ \&CountVbDotNet::CountCase, "CountVbDotNet::CountCase" ],
  [ \&CountWordsVbDotNet::CountAndOr, "CountWordsVbDotNet::CountAndOr" ],
  [ \&CountVbDotNet::CountMultInst, "CountVbDotNet::CountMultInst" ],
  #[ \&CountVbDotNet::CountClassImplementations, "CountVbDotNet::CountClassImplementations" ],
  #[ \&CountVbDotNet::CountComplexConditions, "CountVbDotNet::CountComplexConditions" ],
  [ \&CountVbDotNet::CountRiskyFunctionCalls, "CountVbDotNet::CountRiskyFunctionCalls" ],
  #[ \&CountVbDotNet::CountFor, "CountVbDotNet::CountFor" ],
  #[ \&CountVbDotNet::CountProcedures, "CountVbDotNet::CountProcedures" ],
  [ \&CountVbInstructionPatterns::CountVbInstructionPatterns, 'CountVbInstructionPatterns::CountVbInstructionPatterns' ],
  [ \&CountVbDotNet::CountIllegalStatements, 'CountVbDotNet::CountIllegalStatements' ],
  [ \&CountVbDotNet::CountIllegalThrows, 'CountVbDotNet::CountIllegalThrows' ],
  [ \&CountCommentsBlocs::CountCommentsBlocs, "CountCommentsBlocs::CountCommentsBlocs" ],
);


# calcul de l'ensemble des comptages adaptes Au VbDotNet
sub Count($$$$$)
{
    my ($fichier, $vue, $options, $couples, $r_TableFonctions) = @_;
    my $status = AnaUtils::Count( $fichier, $vue, $options, $couples, $r_TableFonctions);

	if (defined $options->{'--CloudReady'}) {
		CloudReady::detection::setCurrentFile($fichier);
		$status |= CloudReady::CountDotnet::CountDotnet( $fichier, $vue, $options, "VB");
	}

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: module de lancement du strip
#-------------------------------------------------------------------------------
sub Strip($$$$)
{
  my ($fichier, $vue, $options, $couples) =@_ ;

  my $status = 0;

  $status = StripVbDotNet::StripVbDotNet ($fichier, $vue, $options);

  if (($fichier ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'}) # dumpvues_filter_line
  {                                                                            # dumpvues_filter_line
    Vues::dump_vues( $fichier, $vue, $options);                                # dumpvues_filter_line
  }                                                                            # dumpvues_filter_line

  return $status;
}

# Ces variables doivent etre globales dnas le cas nominal (dit nocrashprevent)
my $firstFile = 1;
my ($r_TableMnemos, $r_TableFonctions );
my $confStatus = 0;

sub FileTypeRegister ($)
{
  my ($options) = @_;

  if ($firstFile != 0)
  {
        $firstFile = 0;


        #------------------ Chargement des comptages a effectuer -----------------------

        my $ConfigModul='VbDotNet_Conf';
        if (defined $options->{'--conf'}) {
          $ConfigModul=$options->{'--conf'};
        }

        $ConfigModul =~ s/\.p[ml]$//m;

        ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

        AnaUtils::load_ready();

        #_setAllKnownMnemonics ();

        #------------------ Enregistrement des comptages a effectuer -----------------------
        if (defined $options->{'--o'})
        {
            IsoscopeDataFile::csv_file_type_register("VbDotNet", $r_TableMnemos);
        }
        
		#------------------ init CloudReady detections -----------------------

		if (defined $options->{'--CloudReady'}) {
			CloudReady::detection::init($options, 'VbDotNet');
		}
  }
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Lancement d'une alalyse sur un fichier Vb.Net
#-------------------------------------------------------------------------------
sub Analyse($$$$)
{
    my ( $fichier, $vue, $options, $couples) = @_;
    my $status = 0;

    FileTypeRegister($options);

    $status |= $confStatus;

    my $analyseur_callbacks = [ \&Strip, undef, \&Count, $r_TableFonctions ];
    $status |= AnaUtils::Analyse($fichier, $vue, $options, $couples, $analyseur_callbacks) ;

    return $status;
}

1;


