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
# Description: Module d'analyse pour Ksh
#
# Enchaine la creation des vues necessaires aux comptages
# et le lancement des compteurs
#

package AnaKsh ;
use strict;
use warnings;

use Erreurs;
use Ident;

use CheckKsh;  # parser Ksh
use StripKsh;  # parser Ksh
use CountKsh;  # comptages Ksh
use Vues;
use IsoscopeDataFile;


my $debug = 0;

my @TableMnemos = (
    Ident::Alias_Alias(),
    Ident::Alias_Background(),
    "Nbr_BadStringEnd",
    Ident::Alias_BadTmpName(),
    Ident::Alias_BlankLines(),
    Ident::Alias_Break(),
    Ident::Alias_Case(),
    Ident::Alias_CheckedArgs(),
    Ident::Alias_AlphaNumCommentLines(),
    Ident::Alias_CommentLines(),
    Ident::Alias_CommentedOutCode(),
    Ident::Alias_CommentBlocs(),
    "Nbr_ContinuationChar",
    Ident::Alias_Continue(),
    Ident::Alias_Default(),
    Ident::Alias_DistinctWords(),
    Ident::Alias_Do(),
    Ident::Alias_Exit(),
    Ident::Alias_WithoutValueExit(),
    Ident::Alias_ExportedVariables(),
    Ident::Alias_WithoutFinalExit(),
    Ident::Alias_FunctionMethodImplementations(),
    Ident::Alias_Getopt(),
    Ident::Alias_HeterogeneousEncoding(),
    Ident::Alias_IndentedLines(),
    Ident::Alias_WithoutKshFirstLine(),
    #"Nbr_Lines",
    Ident::Alias_LinesOfCode(),
    Ident::Alias_LocalVariables(),
    Ident::Alias_LongLines80(),
    Ident::Alias_LongLines100(),
    Ident::Alias_LongLines132(),
    Ident::Alias_MaxChainedPipes(),
    Ident::Alias_ModifiedIFS(),
    Ident::Alias_MultipleStatementsOnSameLine(),
    Ident::Alias_NotPureKsh(),
    Ident::Alias_Pipes(),
    Ident::Alias_ShortVarName(),
    Ident::Alias_SuspiciousComments(),
    Ident::Alias_SuspiciousLastCase(),
    Ident::Alias_Switch(),
    Ident::Alias_Then(),
    Ident::Alias_VariableDeclarations(),
    Ident::Alias_WellDeclaredVariables(),
    Ident::Alias_WellNamedExportedVariables(),
    Ident::Alias_WellNamedLocalVariables(),
    Ident::Alias_Words(),
    Ident::Alias_VG(),
);


sub Strip($$$$)
{
  my ($fichier, $vue, $options, $compteurs) = @_;
  my $status = 0;
  $status = StripKsh::StripKsh ($fichier, $vue, $options, $compteurs);
  return $status;
}

# module de lancement des comptages
sub Count ($$$$$)
{
  my ($fichier, $vues, $options, $compteurs, $r_TableFonctions) = @_;

  my $status = 0;
  $status |= CountKsh::CountKsh($fichier, $vues, $compteurs, $options);
  # FIXME: utiliser une table de fonction comme dans les autres analyseurs.
  #my $status |= AnaUtils::Count ($fichier, $vue, $options, $compteurs, $r_TableFonctions );
  return $status;
}

my $firstFile = 1;


sub FileTypeRegister ($)
{
  my ($options) = @_;

    if ($firstFile != 0)
    {
        $firstFile = 0;

        if (defined $options->{'--o'})
        {
            #print STDERR "AnaHpp : appel de csv_file_type_register\n";
            IsoscopeDataFile::csv_file_type_register("Ksh", \@TableMnemos);
        }
    }

}


# Traitement d'un fichier en Ksh
sub Analyse($$$$)
{
  my ($fichier, $vues, $options, $couples) = @_;
  my $compteurs = $couples;
  my $status = 0;

  FileTypeRegister($options);

  if (not defined $options->{'--analyse-short-files'})
  {
    my $erreur_checkKsh = CheckKsh::CheckLanguageCompatibility( \$vues->{'text'} );
    if ( defined $erreur_checkKsh )
    {
      return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_BAD_ANALYZER, $couples, $erreur_checkKsh);
    }
  }

  my $analyseur_callbacks = [ \&Strip, undef, \&Count, undef ];
  $status |= AnaUtils::Analyse($fichier, $vues, $options, $couples, $analyseur_callbacks) ;


if (0) #ancien code.
{
    $status = Strip( $fichier, $vues, $options, $compteurs) ;
    if (defined $options->{'--nocount'})
    {
      return $status;
    }

    if ($status == 0)
    {
        $status |= CountKsh::CountKsh($fichier, $vues, $compteurs, $options);
    }
    else
    {
        print STDERR "$fichier : Echec de pre-traitement\n";
    }
}

    return $status;
}


1;

