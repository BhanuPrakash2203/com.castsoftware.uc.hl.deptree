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


package StripKsh;

use strict;
use warnings;

use Erreurs;
use Couples;

my $debug = 0;

my %chaines_recues = ();
my $nb_chaines = 0;
my $nb_continuation = 0;

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
    $nb_continuation = 0;
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
        if ($nb_continuation == 0)
        {

            if ($chaine =~ m{\\\n}x)
            {

                $nb_continuation = 1;
            }
        }
        push(@{$rTabChaines}, $chaine);
#        print STDERR "nombre de chaines memorisees : " . ($#{@{$rTabChaines}} + 1) . "\n";
#        print STDERR "Derniere chaine memorisee : " . $chaine . "\n";
        $nb_chaines++;
        $chaines_recues{$chaine} = "CHAINE_" . $nb_chaines;
    }
    return $chaines_recues{$chaine};
}


# Fonction   : StripKsh
# Parametres : nom du fichier analyse.
#              table de hachage des vues du code source a analyser.
#              options de traitement.
# Retour     : 0 si succes; 1 si echec
#
# Cree les vues "code" et "comment" a partir de la vue "text"
#
sub StripKsh($$$$)
{
    my ($fichier, $vues, $options, $couples) = @_;
  my $compteurs = $couples;

    my $retour = 0; # code de retour de la fonction

    my $debForCode = 0;   # position de debut du code source non sauvegarde
                          # dans la vue 'code'
    my $debForCmt = 0;    # position de debut du code source non sauvegarde
                          # dans la vue 'comment'
    my $cmtNoFlush = 0;   # indique qu'en presence d'une continuation de ligne
                          # de code la vue 'comment' ne doit pas encore etre
                          # mise a jour
    my $openBrace = -1;   # position d'une accolade ouvrante non fermee
                          # de definition de l'utilisation d'une variable
                          # (evite l'ambiguite entre un diese ouvrant un
                          # commentaire et celui contenu dans ${var#pattern}

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

    my $nbBackQ = 0;      # nombre d'antiquotes trouvees en dehors de chaines
    my $nbBadStrEnd = 0;  # nombre de chaines fermees par une anti-quote

    my @tb_chaines;       # tableau des chaines de caracteres pour la vue 'strings'

  my $status= 0;

    init();

    # suppression des retours chariot

  if (! exists($vues->{'text'}))
  {
    my $message = 'Misisng text view';
    return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
  }

    #return 1 if (! exists($vues->{'text'}));

    my $text = $vues->{'text'};

    while ($text =~ m{
                     (<<-?\s*"?([^\s">]+)"?.*?\n |
                      \#|
                      \{ |
                      \} |
                      \" |
                      \' |
                      \` |
                      \n)
                     }gx)
    {
        $end = pos($text);
        # position debut du delimiteur
        my $beg = pos($text) - length($1);

        # analyse du separateur rencontre

        if (defined($2) && substr($1, 0, 2) eq "<<")
        {
            # insertion de document ?

            if ($diese >= 0)
            {
                # il ne faut pas se laisser perturber par '<<' dans un commentaire

                $code .= substr($text, $debForCode, $diese - $debForCode) if ($diese > $debForCode);
                $code .= "\n";

                $codeNumLigne++;
               
                if ($diese > $debForCmt)
                {
                    my $forCmt = substr($text, $debForCmt, $diese - $debForCmt);
                    $forCmt =~ s/./ /g;
                    $cmt .= $forCmt;
                }
                $cmt .= "\n";

                $cmtNumLigne++;
                $diese = -1;
                $openBrace = -1;
                $debForCode = $end;
                $debForCmt = $end;
                next;
            }

            
            # detection de here document
            my $mark = $2;
            my $hereLines = 0;
            if (substr($text, $end, length($mark)) ne $mark)
            {
                # on n'est pas dans le cas trivial de l'insertion vide

                $code .= substr($text, $debForCode, $end - $debForCode);

                $codeNumLigne++;
                $debForCode = $end;

                $mark = quotemeta($mark);
                if ($text !~ m{\W(?=($mark)\W)}mg)
                {
                  my $message = "unmatched <<$mark\n";
                  return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
                }
                else
                {
                    $beg = pos($text);
                    $hereLines = (substr($text, $debForCode, $beg - $debForCode) =~ tr{\n}{\n});
                    $code .= "\n" x $hereLines;

                    $codeNumLigne += $hereLines;
                    $debForCode = $beg;
                }
            }
            if ($text !~ m{\n}gx)
            {
                if ($text !~ m{\W(?=($mark)\W)}mg)
                {
                  my $message = "Fin de ligne non atteinte apres insertion de texte $mark";
                  return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
                }
            }
            $end = pos($text);

            my $forCode = substr($text, $debForCode, $end - $debForCode);
            $hereLines = $forCode =~ tr{\n}{\n};
            $code .= substr($text, $debForCode, $end - $debForCode);

            $codeNumLigne += $hereLines;

            $hereLines = substr($text, $debForCmt, $end - $debForCmt) =~ tr{\n}{\n};
            $cmt = $cmt . "\n" x $hereLines;

            $cmtNumLigne += $hereLines;

            $debForCmt = $end;
            $debForCode = $end;
        }
        elsif ($1 eq "#")
        {
            # detection d'un commentaire ?

            if ($diese < 0
                && ( ($beg == $debForCmt)
                       ||
                     (($openBrace < 0) && (substr($text, $beg - 1, 1) =~ /\s/))
                   )
               )
            {
                $diese = $end - 1;

            }
        }
        elsif ($1 eq "{")
        {
            if ($diese < 0
                &&  $beg > $debForCode && substr($text, $beg - 1, 1) eq "\$")
            {
                # eviter d'etre perturbe par ${var#pattern}
                $openBrace = $end - 1;
            }
        }
        elsif ($1 eq "}")
        {
            if ($diese < 0 && $openBrace > 0)
            {
                $openBrace = -1;
            }
        }
        elsif ($1 eq '`')
        {
            # on compte les quotes inverses de substitutions de commandes
            if ( ($diese < 0)
                 &&
                 (
                     ($beg == 0)
                     ||
                     ( ($end > 1) && (substr($text, $end - 2, 1) ne "\\") )
                 )
               )
            {
                $nbBackQ++;
            }
        }
        elsif ($1 eq "'")
        {
            # ouverture d'une chaine entouree d'apostrophes ?
            if ($diese < 0
                && ( ($beg == $debForCode)
                     ||
                     (substr($text, $beg - 1, 1) ne "\\")
                   )
               )
            {
                my $debQuote = $beg;
                my $finQuote;

                if ( ($nbBackQ % 2) != 0)
                {
                    # l'interpreteur du ksh semble assez permissif pour fermer une chaine non fermee
                    # lorsqu'il rencontre la fin d'une substitution de commande
                    # essayons de caracteriser cette anomalie syntaxique
                    if ($text =~ m{(?<!\\)([`'])}gx)
                    {
                        if ($1 eq '`')
                        {
                            $finQuote = pos($text) - 2; # attention : c'est l'antiquote
                                                        # qui est prise pour l'apostrophe
                                                        # fermant la chaine
                            print STDERR "Fin de chaine inattendue : " .
                                         substr($text, $beg, $finQuote + 2 - $beg) .
                                         "\n";
                            $nbBadStrEnd++;
                            $nbBackQ++;
                        }
                        elsif ($1 eq "'")
                        {
                            $finQuote = pos($text) - 1;
                        }
                    }
                    else
                    {
                      my $message = "unterminated string\n";
                      return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
                    }
                }
                elsif ($text !~ m{\'}gx)
                {
                  my $message = "unterminated string\n";
                  return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
                }
                else
                {
                    $finQuote = pos($text) - 1;
                }
                if ($debQuote > $debForCode)
                {
                    $code .= substr($text, $debForCode, $debQuote - $debForCode);
                }
                $code .= "'";
                if ($finQuote > $debQuote + 1)
                {
                    $code .= memorize_string(substr($text, $debQuote + 1, $finQuote - $debQuote - 1), \@tb_chaines);
                }
                else
                {
                    $code .= "CHAINE_VIDE";
                }
                $code .= "'";
                $debForCode = $finQuote + 1;
            }
        }
        elsif ($1 eq '"')
        {

            if ($diese < 0
                && ( ($beg == $debForCode)
                     ||
                     (substr($text, $beg - 1, 1) ne "\\")
                   )
               )
            {
                my $debDoubleQ = $beg;
                my $finDoubleQ;

                if ( ($nbBackQ % 2) == 0 )
                {
                    # cas ordinaire : on recherche un guillemet fermant
                    # (non precede du caractere d'echappement)
                    if ($text !~ m{(?<!\\)(\")}gx)
                    {
                      my $message = "unterminated string\n";
                      return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
                    }
                    else
                    {
                        $finDoubleQ = pos($text) - 1;
                    }
                }
                else
                {
                    # on est dans une substitution de commande
                    # il faut se mefier des chaines fermees par une quote inverse
                    # au lieu d'un guillemet car l'interpreteur ksh semble supporter
                    # l'omission du guillemet fermant
                    if ($text =~ m{(?<!\\)([`"])}gx)
                    {
                        if ($1 eq '`')
                        {
                            $nbBackQ++;
                            $finDoubleQ = pos($text) - 2;
                            print STDERR "Fin de chaine inattendue : " .
                                         substr($text, $beg, $finDoubleQ + 2 - $beg) .
                                         "\n";
                            $nbBadStrEnd++;
                        }
                        else
                        {
                            $finDoubleQ = pos($text) - 1;
                        }
                    }
                    else
                    {
                      my $message = "unterminated string\n";
                      return $status | Erreurs::FatalError( Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $couples, $message);
                    }
                }

                if ($debDoubleQ > $debForCode)
                {
                    $code .= substr($text, $debForCode, $debDoubleQ - $debForCode);
                }
                $code .= "\"";
                if ($finDoubleQ > $debDoubleQ + 1)
                {
                    $code .= memorize_string(substr($text, $debDoubleQ + 1, $finDoubleQ - $debDoubleQ - 1), \@tb_chaines);
                }
                else
                {
                    $code .= "CHAINE_VIDE";
                }
                $code .= "\"";
                $debForCode = $finDoubleQ + 1;
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
                    $lignes = $forCmt =~ tr{\n}{\n};
                    if ($lignes != 0)
                    {
                        # Ajout de lignes vides pour compenser la simplification des chaines multilignes
                        $code .= "\n" x $lignes;

                        $codeNumLigne += $lignes;
                    }
                }
                $cmt = $cmt . substr($text, $diese, $end - $diese);

                $cmtNumLigne++;
            }
            else
            {
                # pas de commentaire dans la ligne
                if ($end > ($debForCode + 1)
                    && (substr($text, $end - 2, 1) eq "\\")
                   )
                {
                    if ($nb_continuation == 0)
                    {
                        $nb_continuation = 1;
                    }
                    if ($debForCode < ($end -2))
                    {
                        # on ecrit la ligne sans le caractere de continuation ni le \n
                        $code .= substr($text, $debForCode, $end - 2 - $debForCode);
                    }
                    $cmtNoFlush = 1;
                }
                else
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
                        # la simplification de chaines multilignes
                        $code .= "\n" x ($lignes - 1);

                        $codeNumLigne += ($lignes - 1);
                    }
                }
            }
            $diese = -1;
            $openBrace = -1;
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
    $retour |= Couples::counter_add($compteurs, "Nbr_BadStringEnd", $nbBadStrEnd);
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
