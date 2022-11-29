#------------------------------------------------------------------------------#
#                         @ISOSCOPE 2008                                       #
#------------------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                          #
#               Adresse : TERSUD - Bat A                                       #
#                         5, AVENUE MARCEL DASSAULT                            #
#                         31500  TOULOUSE                                      #
#               SIRET   : 410 630 164 00037                                    #
#------------------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                                #
# l'Institut National de la Propriete Industrielle (lettre Soleau)             #
#------------------------------------------------------------------------------#

# Composant: Plugin

# Ce paquetage fournit une separation du code et des commentaires d'un script
# Korn Shell


package StripNsdk;

use strict;
use warnings;

use Couples;
use Erreurs;

my $debug = 0;

my $CONT_LINE = " \001 ";

my %chaines_recues = ();
my $nb_chaines = 0;

# Fonction   : init
# Parametres : 
# Retour     : 
#
# Initialise les variables de package
#
sub init()
{
    %chaines_recues = ();
    $nb_chaines = 0;
}


# Fonction   : memorize_string
# Parametres : chaine de caracteres detectee dans le code source.
# Retour     : chaine symbolique de substitution.
#
# Retourne un nom de chaine simplifiee
#
sub memorize_string($$)
{
    my ($chaine, $rTabChaines) = @_;


    if (! exists($chaines_recues{$chaine}))
    {
        push(@{$rTabChaines}, $chaine);
        $nb_chaines++;
        $chaines_recues{$chaine} = "CHAINE_" . $nb_chaines;
    }
    return $chaines_recues{$chaine};
}


# Fonction   : StripNsdk
# Parametres : nom du fichier analyse.
#              table de hachage des vues du code source a analyser.
#              options de traitement.
# Retour     : 0 si succes; 1 si echec
#
# Cree les vues "code" et "comment" a partir de la vue "text"
#
sub StripNsdk($$$$)
{
    my ($fichier, $vues, $options, $compteurs) = @_;

    my $retour = 0; # code de retour de la fonction

    my $debForCode = 0;   # position de debut du code source non sauvegarde
                          # dans la vue 'code'
    my $debForCmt = 0;    # position de debut du code source non sauvegarde
                          # dans la vue 'comment'
    my $cmtNoFlush = 0;   # indique qu'en presence d'une continuation de ligne
                          # de code la vue 'comment' ne doit pas encore etre
                          # mise a jour
    my $diese = -1;       # position de debut d'un commentaire
    my $lignes = 0;       # comptages dans des blocs multilignes en cas de
                          # simplification de chaines de caracteres ou de
                          # lignes de code terminees par le caractere de
                          # continuation '\'

    my $cmt = "";         # vue 'comment' en cours de construction
    my $code = "";        # vue 'code' en cours de construction

    my $forCmt;           # portion de la vue 'text' a transformer pour la
                          # placer dans la vue 'comment'
    my $forCode;          # portion de code source a ajouter a la vue 'code'
    my $end;              # position atteinte dans le parcours de la vue 'text'
    my $cmtNumLigne = 1;
    my $codeNumLigne = 1;

    my @tb_chaines;       # tableau des chaines de caracteres pour la vue 'strings'

    my $nb_continuation = 0;
    my $nbBadContinuation = 0;

    init();

    # suppression des retours chariot
    return 1 if (! defined($vues->{'text'}));
    my $text = $vues->{'text'};

    while ($text =~ m{
                     (\;|
                      \" |
                      \' |
                      \\ |
                      \n)
                     }gx)
    {
        $end = pos($text);
        # position debut du delimiteur
        my $beg = pos($text) - length($1);

        # analyse du separateur rencontre
        if ($1 eq ";")
        {
            if ($diese < 0)
            {
                $diese = $end - 1;
            }
        }
        elsif ($1 eq "'" || $1 eq '"')
        {
            my $sep = $1;

            if ($diese < 0)
            {
                my $debQuote = $beg;

                if ($text !~ m{$sep}gx)
                {
                    print STDERR "unterminated string\n";
                    return 1;
                }
                my $finQuote = pos($text) -1;
                if ($debQuote > $debForCode)
                {
                    $code .= substr($text, $debForCode, $debQuote - $debForCode);
                }
                $code .= $sep;
                if ($finQuote > $debQuote + 1)
                {
                    $code .= memorize_string(substr($text, $debQuote +1, $finQuote - $debQuote -1), \@tb_chaines);
                }
                else
                {
                    $code .= "CHAINE_VIDE";
                }
                $code .= $sep;
                $debForCode = $finQuote + 1;
            }
        }
        elsif ($1 eq "\\")
        {
            if ($diese < 0)
            {
                #if ($end > ($debForCode + 1)
                #    && (substr($text, $end - 2, 1) eq "\\")
                #   )
                {
                    $nb_continuation++;
                    if ($debForCode < ($end - 1))
                    {
                        # on ecrit la ligne sans le caractere de continuation
                        $code .= substr($text, $debForCode, $end - 1 - $debForCode);
                        Erreurs::LogInternalTraces("DEBUG", $fichier, $codeNumLigne, "Nbr_ContinuationChar", substr($text, $debForCode, $end - $debForCode -1), "DEBUT de ligne decoupee");
                        $code .= $CONT_LINE;        # mais avec un marqueur de fin de ligne
                    }
                    $cmtNoFlush = 1;
                }
                if (substr($text, $end, 1) ne "\n")
                {
                    Erreurs::LogInternalTraces("WARNING", $fichier, $codeNumLigne, "Nbr_BadLineContinuation", substr($text, $debForCode, $end - $debForCode), "ligne decoupee illegalement");
                    $nbBadContinuation++;
                }
            }
        }
        elsif ($1 eq "\n")
        {
            if ($diese >= 0)
            {
                # la ligne courante se termine par un commentaire
                if ($diese > $debForCode)
                {
                    # Ajout de fin de ligne(s) de code en cours d'analyse
                    $code .= substr($text, $debForCode, $diese - $debForCode);
                }
                $code .= "\n";
                $codeNumLigne++;
                
                if ($diese != $debForCmt)
                {
                    # Transformation de tout caractere de code en espace pour la vue 'comment'
                    $forCmt = substr($text, $debForCmt, $diese - $debForCmt);
                    $forCmt =~ s{[^\n]}{ }gm;
                    $cmt = $cmt . $forCmt ;
                }
                $cmt = $cmt . substr($text, $diese, $end - $diese);
                $cmtNumLigne++;
            }
            else
            {
                # pas de commentaire dans la ligne
                #if ($end > ($debForCode + 1)
                #    && (substr($text, $end - 2, 1) eq "\\")
                #   )
                #{
                #    if ($nb_continuation == 0)
                #    {
                #        $nb_continuation = 1;
                #    }
                #    if ($debForCode < ($end -2))
                #    {
                #        # on ecrit la ligne sans le caractere de continuation ni le \n
                #        $code .= substr($text, $debForCode, $end - 2 - $debForCode);
                #        Erreurs::LogInternalTraces("DEBUG", $fichier, $codeNumLigne, "Nbr_ContinuationChar", substr($text, $debForCode, $end - $debForCode -1), "DEBUT de ligne decoupee");
                #        $code .= $CONT_LINE;        # mais avec un marqueur de fin de ligne
                #    }
                #    $cmtNoFlush = 1;
                #}
                if ($cmtNoFlush == 0)
                {
                    $forCode = substr($text, $debForCode, $end - $debForCode);
                    $code = $code . $forCode;

                    $codeNumLigne++;
                    $forCmt = substr($text, $debForCmt, $end - $debForCmt);
                    $lignes = $forCmt =~tr{\n}{\n};
                    $cmt = $cmt . "\n" x $lignes;

                    $cmtNumLigne += $lignes;
                    if ($lignes > 1)
                    {
                        # Creation de lignes vides pour compenser
                        # la concatenation des lignes de code decoupees par \\\n
                        $code .= "\n" x ($lignes -1);
                        $codeNumLigne += ($lignes -1);
                        Erreurs::LogInternalTraces("DEBUG", $fichier, $codeNumLigne, "Nbr_ContinuationChar", substr($text, $debForCode, $end - $debForCode -1), "FIN ligne decoupee");
                    }
                }
            }
            $diese = -1;
            $debForCode = $end;
            if ($cmtNoFlush == 1)
            {
                $cmtNoFlush = 0;
            }
            else
            {
                $debForCmt = $end;
            }
        }
    }


    $retour |= Couples::counter_add($compteurs, "Nbr_ContinuationChar", $nb_continuation);
    $retour |= Couples::counter_add($compteurs, "Nbr_BadLineContinuation", $nbBadContinuation);
    $vues->{'code'} = $code;
    $vues->{'comment'} = $cmt;
    $vues->{'strings'} = \@tb_chaines;

#    print STDERR "FICHIER " . $fichier . "\n";
#    my $index = 1;
#    for my $chaine (@tb_chaines)
#    {
#        print STDERR "chaine_" . $index . " : " . $tb_chaines[$index-1] . "\n";
#        $index++;
#    }


    return $retour;
}

1;
