#!/usr/bin/perl -w
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
#
# Description: Outil de comptages Korn shell (programme principal)
#

use strict;
use warnings ;

my $VERSION = "V2.0";

BEGIN
{
    my $rep = $0;
    $rep =~ s{(.*)\/[^\/]+}{$1};
    push @INC, $rep;
}

use SourceLoader;
use Options;
use Couples;
use AnaKsh;
use IsoscopeDataFile;

# liste ordonnee des comptages a calculer et afficher dans le fichier de sortie
my @CompteursKsh = (
    "Dat_Language",
    "Dat_AnalysisDate",
    "Dat_AnalysisStatus",
    Ident::Alias_Words(),
    Ident::Alias_DistinctWords(),
    Ident::Alias_WithoutKshFirstLine(),
    "Nbr_CommentBlocks",
    Ident::Alias_CommentedOutCode(),
    Ident::Alias_SuspiciousComments(),
    Ident::Alias_HeterogeneousEncoding(),
    Ident::Alias_IndentedLines(),
    Ident::Alias_LinesOfCode(),
    Ident::Alias_NotPureKsh(),
    "Nbr_ContinuationChar",
    Ident::Alias_ModifiedIFS(),
    Ident::Alias_Getopt(),
    Ident::Alias_CheckedArgs(),
    Ident::Alias_WellDeclaredVariables(),
    Ident::Alias_VariableDeclarations(),
    Ident::Alias_WellNamedExportedVariables(),
    Ident::Alias_ExportedVariables(),
    Ident::Alias_WellNamedLocalVariables(),
    Ident::Alias_ShortVarName(),
    Ident::Alias_LocalVariables(),
    Ident::Alias_Pipes(),
    Ident::Alias_MaxChainedPipes(),
    Ident::Alias_Background(),
    Ident::Alias_Alias(),
    Ident::Alias_FunctionMethodImplementations(),
    Ident::Alias_Then(),
    Ident::Alias_Do(),
    Ident::Alias_Case(),
    Ident::Alias_Switch(),
    Ident::Alias_Default(),
    Ident::Alias_SuspiciousLastCase(),
    Ident::Alias_Exit(),
    Ident::Alias_WithoutValueExit(),
    Ident::Alias_WithoutFinalExit(),
    Ident::Alias_Break(),
    Ident::Alias_Continue(),
    Ident::Alias_MultipleStatementsOnSameLine(),
    Ident::Alias_BadTmpName()
);


# Affichage d'une aide sommaire
sub usage ()
{
    print STDERR "\n" ;
    print STDERR "Usage:\n" ;
    print STDERR ' perl -S count_ksh.pl --o=<fichier_resultat> <nom_fichier_source> ...  ' . "\n" ;
    print STDERR "ou\n";
    print STDERR ' perl -S count_ksh.pl --o=<fichier_resultat> --file-list=<fichier_liste_des_sources>' . "\n" ;
    print STDERR 'exemple:' . "\n" ;
    print STDERR ' perl -S count_ksh.pl --o=cpt_appli.csv $(find appli/ -name "*.ksh")  ; echo $?' . "\n" ;
    print STDERR 'exemple:' . "\n" ;
    print STDERR ' perl -S count_ksh.pl --o=cpt_appli.csv --file-list=appli_src.lst  ; echo $?' . "\n" ;

    print STDERR "    \n" ;
    exit -1;
}


# Point d'entree, traitement de la ligne de commande
sub main()
{
    my $status = 0; # l'analyse d'un fichier retourne un code d'erreur forme
                    # par la combinaison par OU binaire
                    # des retours d'erreurs de ses creations de vues et comptages;
                    # la fonction retourne la combinaison par OU binaire
                    # du retour d'analyse de l'ensemble des fichiers

    my ( $options, $fichiers ) = Options::traite_options(\@ARGV);
    my @tabFiles = @{$fichiers};

    if ( scalar(@tabFiles) == 0)
    {
        # aucun nom de fichier source n'ayant ete passe en ligne de commande,
        # l'option --file-list devrait designer un fichier contenant
        # la liste des fichiers sources a analyser
        @tabFiles = Options::getFileList($options);
    }
    usage() if ( scalar(@tabFiles) == 0);

    my $outFile = Options::GetOutputFile($options, '--o');
    usage() if (! defined $outFile);

    # tentative d'initialisation du fichier de sortie :
    # creation de l'en-tete du fichier CSV
    usage() if (IsoscopeDataFile::csv_file_open($outFile, \@CompteursKsh) != 0);
    
    for my $fichier (@tabFiles)
    {
        $status |= AnalyseFile ($fichier, $options);
    }

    IsoscopeDataFile::csv_file_close();

    return $status;
}


# Lancement de l'analyse sur un fichier source
sub AnalyseFile($$)
{
    my ($fichier, $options) = @_ ;
    my $compteurs ; 
    my $status = 0; # l'analyse d'un fichier retourne un code d'erreur forme
                    # par la combinaison par OU binaire
                    # des retours d'erreurs de ses creations de vues
                    # et comptages et de leur memorisation

    my $date = Options::get_date_as_numerical_string();

    $compteurs = new Couples() ; 
    $status |= Couples::counter_add($compteurs, "Dat_AnalysisDate", $date);
    $status |= Couples::counter_add($compteurs, "Dat_FileName", $fichier);

    my $vues = SourceLoader::mainLoadFile($fichier, $options);

    if (defined $vues->{'text'})
    {
        # le fichier n'est pas detecte comme binaire; on va tenter les comptages
        $status |= Couples::counter_add($compteurs, "Dat_Language", "Ksh");
        if ($status == 0)
        {
            $status = AnaKsh::Analyse($fichier, $vues, $options, $compteurs);
        }
    }
    else
    {
        # pour un fichier binaire ou inaccessible,
	# on cree une ligne de resultats minimale

	if (defined $vues->{'bin'})
	{
            $status |= Couples::counter_add($compteurs, "Dat_Language", "Binary");
            print STDERR "detect language: " . 'binary' . " " . $fichier . "\n";
	}
	else
	{
	    # nom de fichier errone ou fichier illisible
            $status |= Couples::counter_add($compteurs, "Dat_Language", "Unknown");
	}
        $status |= 16;
    }

    $status |= Couples::counter_add($compteurs, "Dat_AnalysisStatus", $status);
    IsoscopeDataFile::csv_file_append($compteurs);
    if ( $status != 0)
    {
        printf STDERR "\nError: L'analyse du fichier $fichier s'est terminee avec le code 0x%x\n", $status;
    }

    return $status;
}


print STDERR "Outil de comptages sur codes sources Korn shell - " .
             $VERSION . "\n"; 
my $code_final_de_retour= main();

exit ( $code_final_de_retour);

