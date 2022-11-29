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
# Description: Outil de detection d'encodage des fichiers.
#

use strict;
use warnings ;

my $VERSION = 'version interne';

BEGIN
{
    my $rep = $0;
    $rep =~ s{(.*)\/[^\/]+}{$1};
    push @INC, $rep;
}

use SourceLoader;
use Options;
use Couples;

use Erreurs; # pour les traces
use IsoscopeDataFile;

#my @table_comptages = (
 ## Keywords
  ##["ID","Mnémonique","Idée","BP","CS","C","L","AD"], ["K2",Ident::Alias_Sql_Alter(),"Compter le nombre d'occurences du mot clé ALTER",,,,,],); 



# liste ordonnee des comptages a calculer et afficher dans le fichier de sortie
my @ColumnsHeaders = (
    "Dat_Language",
    "Dat_AnalysisDate",
    "Dat_AnalysisStatus",

    "Dat_Encoding",

);

#sub _setAllKnownMnemonics ()
#{
  #for my $ligne ( @table_comptages )
  #{
    #push @ColumnsHeaders, $ligne->[1] ;
  #}
#}


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
    usage() if (IsoscopeDataFile::csv_file_open($outFile, \@ColumnsHeaders) != 0);
    
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

    Erreurs::SetCurrentFilenameTrace( $fichier ) ;


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
        $status |= Couples::counter_add($compteurs, "Dat_Encoding", $vues->{'encoding'} );
        #if ($status == 0)
        #{
        #}
    }
    else
    {
        # pour un fichier binaire ou inaccessible,
        # on cree une ligne de resultats minimale
    
        if (defined $vues->{'bin'})
        {
            $status |= Couples::counter_add($compteurs, "Dat_Encoding", "Binary");
            #print STDERR "detect language: " . 'binary' . " " . $fichier . "\n";
        }
        else
        {
            # nom de fichier errone ou fichier illisible
            $status |= Couples::counter_add($compteurs, "Dat_Encoding", "Unreadable");
            #$status |= Couples::counter_add($compteurs, "Dat_Language", "Unknown");
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


#_setAllKnownMnemonics();
print STDERR "Outil de detection d'encodage, pour tous fichiers - " .
             $VERSION . "\n"; 
my $code_final_de_retour= main();

exit ( $code_final_de_retour);

