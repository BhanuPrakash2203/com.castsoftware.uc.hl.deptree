#----------------------------------------------------------------------#
#                         @CAST 2011                                   #
#----------------------------------------------------------------------#

# Composant: Plugin
# Description: Ce paquetage permet d'effectuer des comptages pour le langage PL1 #.

package AnaPL1 ;

use strict;
use warnings;



use StripPL1;
use Vues;
use AnaUtils;
use Timeout;
use IsoscopeDataFile;

use PL1::Parse;

#use CountCS;
#use CountCommentedOutCode;
#use CountBreakLoop;
#use CountComplexConditions;
#use CountAssignmentsInConditionalExpr;
#use CountMissingBraces;
#use CountEmptyCatches;
#use CountMagicNumbers;
#use CountSuspiciousComments;
#use CountAndOr;
#use CountWords;
#use CountIfPrepro;
#use CountBadSpacing;
#use CountComplexOperands;
#use CountCommentsBlocs;
#use CountMultInst;
#use CountNode;

#sub Strip($$$;$)
#{
#  my ($fichier, $vue, $options) =@_ ;
#  #return  StripJava::StripJava ($fichier, $vue, $options) ;
#  return  StripCS::StripCS ($fichier, $vue, $options) ;
#}

#-------------------------------------------------------------------------------
# module de lancement du strip
#-------------------------------------------------------------------------------
sub Strip($$$$)
{
  my ($fichier, $vue, $options, $couples) =@_ ;
  my $status = 0;
  eval
  {
    $status = StripPL1::StripPL1($fichier, $vue, $options, $couples);
  };
  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Erreur dans la phase Strip: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }

  #if (($fichier ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'}) # dumpvues_filter_line
  if (defined $options->{'--strip'}) # dumpvues_filter_line
  {                                                                            # dumpvues_filter_line
    Vues::dump_vues( $fichier, $vue, $options);                                # dumpvues_filter_line
  }                                                                            # dumpvues_filter_line

  # FIXME: pour bientot :
  #if ($status & Erreurs::COMPTEUR_STATUS_FICHIER_NON_COMPILABLE)
  #{
  #  return $status;
  #}
  #
  #eval
  #{
  #  $status |= CountC_CPP_FunctionsMethodsAttributes::Parse($fichier, $vue, $couples, $options);
  #};
  #if ($@ )
  #{
  #  print STDERR "Erreur dans la phase Parsing: $@ \n" ;
  #  $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  #}
  #
  return $status;
}




sub Parse ($$$$)
{
  my ($fichier, $vue, $options, $couples) =@_ ;
  my $status = 0;
  eval
  {
    $status |= PL1::Parse::Parse ($fichier, $vue, $couples, $options);

    # attention a l'ordre des parametres
    #$status |= PlSql::ParseBody::ParseBody ($fichier, $vue, $options, $couples);
  };

  if ($@ )
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Error when parsing: $@ \n" ;
    $status = Erreurs::COMPTEUR_STATUS_PB_STRIP ;
  }

#  if (not defined $options->{'--analyse-short-files'})
#  {
#    my $erreur_checkplsql = PlSql::CheckPlSql::CheckCodeAvailability( $vue->{'structured_code'} );
#    if ( defined $erreur_checkplsql )
#    {
#      return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_NOT_ENOUGH_CODE, $couples, $erreur_checkplsql);
#    }
#  }

  return  $status;
}

#my @TableCounters =
#(
#  [ \&CountBinaryFile::CountBinaryFile , "\&CountBinaryFile::CountBinaryFile" ],
#  [ \&CountCommun::CountCommun , "\&CountCommun::CountCommun" ],
#  [ \&CountBreakLoop::CountBreakLoop , "\&CountBreakLoop::CountBreakLoop" ],
#  [ \&CountCS::CountKeywords , "\&CountCS::CountKeywords" ],
#  [ \&CountCS::CountBugPatterns , "\&CountCS::CountBugPatterns" ],
#  [ \&CountCS::CountAutodocTags , "\&CountCS::CountAutodocTags" ],
#  [ \&CountCS::CountRiskyFunctionCalls , "\&CountCS::CountRiskyFunctionCalls" ],
#  [ \&CountCS::CountMetrics , "\&CountCS::CountMetrics" ],
#  [ \&CountCS::CountIllegalThrows , "\&CountCS::CountIllegalThrows" ],
#  [ \&CountCommentedOutCode::CountCommentedOutCode , "\&CountCommentedOutCode::CountCommentedOutCode" ],
#  [ \&CountAssignmentsInConditionalExpr::CountAssignmentsInConditionalExpr , "\&CountAssignmentsInConditionalExpr::CountAssignmentsInConditionalExpr" ],
#  [ \&CountComplexConditions::CountComplexConditions , "\&CountComplexConditions::CountComplexConditions" ],
#  [ \&CountMissingBraces::CountMissingBraces , "\&CountMissingBraces::CountMissingBraces" ],
#  [ \&CountEmptyCatches::CountEmptyCatches , "\&CountEmptyCatches::CountEmptyCatches" ],
#  [ \&CountMagicNumbers::CountMagicNumbers , "\&CountMagicNumbers::CountMagicNumbers" ],
#  [ \&CountSuspiciousComments::CountSuspiciousComments , "\&CountSuspiciousComments::CountSuspiciousComments" ],
#  [ \&CountAndOr::CountAndOr , "\&CountAndOr::CountAndOr" ],
#  [ \&CountWords::CountWords , "\&CountWords::CountWords" ],
#  [ \&CountIfPrepro::CountIfPrepro , "\&CountIfPrepro::CountIfPrepro" ],
#  [ \&CountBadSpacing::CountBadSpacing , "\&CountBadSpacing::CountBadSpacing" ],
#  [ \&CountComplexOperands::CountComplexOperands , "\&CountComplexOperands::CountComplexOperands" ],
#  [ \&CountCommentsBlocs::CountCommentsBlocs , "\&CountCommentsBlocs::CountCommentsBlocs" ],
#  [ \&CountMultInst::CountMultInst , "\&CountMultInst::CountMultInst" ],
##    \&CountNode::CountNode,
#);



sub Count($$$$$)
{
    my (  $fichier, $vue, $options, $couples, $r_TableFonctions) = @_;
    my $status = 0;


    #$status = AnaUtils::Count( $fichier, $vue, $options, $couples, \@TableCounters);
    #$status = AnaUtils::Count( $fichier, $vue, $options, $couples, \@CS_Conf::table_Comptages);
    $status |= AnaUtils::Count( $fichier, $vue, $options, $couples, $r_TableFonctions);
    return $status;
}


# Ces variables doivent etre globales dans le cas nominal (dit nocrashprevent)
my $firstFile = 1;
my ($r_TableMnemos, $r_TableFonctions );
my $confStatus = 0;

sub FileTypeRegister ($)
{
  my ($options) = @_;

  if ($firstFile != 0)
  {
    #------------------ Chargement des comptages a effectuer -----------------------
    my $ConfigModul='PL1_Conf';
    if (defined $options->{'--conf'}) {
      $ConfigModul=$options->{'--conf'};
    }

    $ConfigModul =~ s/\.p[ml]$//m;

    ($r_TableMnemos, $r_TableFonctions, $confStatus ) = AnaUtils::Read_ConfAnalyse($ConfigModul, $options);

    AnaUtils::load_ready();

    #------------------ Enregistrement des comptages a effectuer -----------------------
    $firstFile = 0;
    if (defined $options->{'--o'})
    {
        IsoscopeDataFile::csv_file_type_register("PL1", $r_TableMnemos);
    }
  }

}

sub Analyse ($$$$)
{
  my ($fichier, $vue, $options, $couples) = @_;
  my $status =0;

  FileTypeRegister($options);
  $status |= $confStatus;

  my $analyseur_callbacks = [ \&Strip, \&Parse, \&Count, $r_TableFonctions ];
  $status |= AnaUtils::Analyse($fichier, $vue, $options, $couples, $analyseur_callbacks) ;

  return $status ;
}



#sub Analyse($$$$)
#{
#  my ( $fichier, $vue, $options, $couples) = @_;
#  my $status =0;
#
#  FileTypeRegister ($options);
#  $status |= $confStatus;
#
##------------------ Lancement du strip -----------------------
#
#  $status |= Strip( $fichier, $vue, $options, $couples);
#
#  if ( Erreurs::isAborted($status) )
#  {
#    # si le strip genere une erreur fatale,
#    # on ne fera pas de comptages
#    return $status;
#  }
#
#
#  if (defined $options->{'--nocount'})
#  {
#    return $status;
#  }
#
#
##------------------ Lancement des compteurs -----------------------
#
#  if ($status == 0)
#  {
#    $status |= Count($fichier, $vue, $options, $couples, $r_TableFonctions);
#  }
#  else
#  {
#    print STDERR "$fichier : Echec de pre-traitement\n";
#  }
#
#  return $status ;
#}

# Un alias
sub AnaPL1($$$$)
{
    my ( $fichier, $vues, $options, $couples) = @_;
    return Analyse ( $fichier, $vues, $options, $couples);
}

1;


