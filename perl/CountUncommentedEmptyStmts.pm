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

package CountUncommentedEmptyStmts;

# les modules importes
use strict;
use warnings;
use Erreurs;
use Couples;
use TraceDetect;

# prototypes publics
sub CountUncommentedEmptyStmts($$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des instructions vides ( {} ou ; ) sans commentaire non vide
# FIXME: Anomalie 227.
# LANGAGES: C C++, C#, Java
#-------------------------------------------------------------------------------
sub CountUncommentedEmptyStmts($$$$) {
    my ($fichier, $vue, $compteurs, $options) = @_ ;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $trace_detect = '' if ($b_TraceDetect);                         # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $mnemo_UncommentedEmptyStmts = Ident::Alias_UncommentedEmptyStmts();
    my $status = 0;

    if ( ! defined $vue->{'text'} ) {
      $status |= Couples::counter_add($compteurs, $mnemo_UncommentedEmptyStmts, Erreurs::COMPTEUR_ERREUR_VALUE );
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
    }

    # FIXME: il faudrait une vue avec code + commentaire mais avec les strings et les caracteres zappes
    my $code = $vue->{'text'};

    # Suppression du contenu des lignes vides
    while ( $code =~ s/^[ \t]+$//g ) {}

    # Suppression des commentaires // vides
    while ( $code =~ s/\/\/[ \t]*\n/\n/sg ) {}

    # Suppression des commentaires /* */ vides
    while ( $code =~ s/\/\*(\n*)[ \t]*(\n*)\*\//$1$2/sg ) {}

    # Suppression du contenu des commentaires //
    while ( $code =~ s/\/\/[^\n]*\n/balise isoscope £\n/g ) {}
    while ( $code =~ s/balise isoscope £/\/\/ commentaire/sg ) {}

    # Suppression du contenu des commentaires /* */

    # s'il y a des livres, on les conserves
    $code =~ s/£/balise isoscope/g ;

    # les fins de commentaires sont tranformees en livres pour eviter la gourmandise
    while ( $code =~ s/\*\//£/g ) {}

    # Supprime les mots contenus dans les commentaires C
    while ( $code =~ s/\/\*([\s]*)(?:[^\n£]+)(.*)£/\/\*$1$2£/sg ) {}

    # remet un commentaire non vide
    $code =~ s/£/ commentaire \*\//g ;

    # Neutralisation des directives de compilations
    $code =~ s/(^[ \t]*#)\s*[^\n]*\n/$1directive de compilation\n/mg ;

    # Neutralisation des ordres sql

    # les debut d'ordre sql sont tranformes en livres pour eviter la gourmandise
    $code =~ s/\bEXEC\s+SQL\b/£/g ;

    # Neutralisation des EXEC SQL ... END-EXEC ;
    $code =~ s/£[^£]*\bEND\-EXEC\b\s*;/ordre1 sql;/smg ;

    # Neutralisation des EXEC SQL ... ;
    $code =~ s/£[^£;]*;/ordre2 sql;/smg ;

    # restaure les livres
    while ( $code =~ s/balise isoscope/£/g ) {}

    # Suppression des \" et \'
    $code =~ s/\\["']/x/sg ;

    # Suppression des '"'
    $code =~ s/'"'/'x'/sg ;

    # Suppression du contenu des caracteres
    $code =~ s/'.'|'\\\w\w\w'/caractere/sg ;

    # Suppression du contenu des strings
    $code =~ s/"[^"]*"/string/sg ;

    # FIXME: fin du FIXME

    # Suppression des imbrications de parentheses.
    while ( $code =~ s/(\([^\(\)]*\))/balise isoscope £/sg ) {}
    while ( $code =~ s/balise isoscope £/()/sg ) {}

    $trace_detect .= "$code\n--- fin code source ---\n" if ($b_TraceDetect); # traces_filter_line

    my $nbr_UncommentedEmptyStmts = () = $code =~ /
                                                    # pas de commentaire dans une instruction vide suivant:
                                                    # - une autre instruction,
                                                    # - une etiquette, un 'case' ou un 'default'
                                                    # - un debut ou une fin de bloc.
                                                    [;:\{] \s* ;
                                                    # pas de commentaire dans un bloc vide
                                                  | \{ \s* }
                                                    # pas de commentaire entre la condition et le ';'
                                                  | \b (?: if
                                                      | while
                                                      | for
                                                      | foreach )
                                                    \s* \( [^;\{\(]* \) \s* ;
                                                    # pas de commentaire entre le 'else' et le ';'
                                                  | \b else \s* ;
                                                  /xsg ;

    $trace_detect .= "nombre de uncommented empty stmts $nbr_UncommentedEmptyStmts\n"; # traces_filter_line

    # tous les 'while (cond) ;' ont ete comptabilises, il faut soustraire les 'do ... while (cond) ;'
    my $nbr_doWhiles = () = $code =~ /\bdo\b/sg ;

    $trace_detect .= "nombre de do ... while (...); $nbr_doWhiles\n";   # traces_filter_line

    $nbr_UncommentedEmptyStmts -= $nbr_doWhiles;

    # les blocs ou instructions vides precedes ou suivis d'un commentaire sont soustraits
    my $nbr_CommentedEmptyStmts = () = $code =~ /
                                                  # un commentaire apres le ';' sur la meme ligne
                                                  [;:\{] \s* ; [\ \t]* \/[\/\*]
                                                  # un commentaire apres le bloc vide sur la meme ligne
                                                | \{ \s* } [\ \t]* \/[\/\*]
                                                  # un commentaire avant la structure
                                                | [\/\*]\/ \s* \b(?: if
                                                    | while
                                                    | for
                                                    | foreach )
                                                  \s* \( [^;\{\(]* \) \s* ;
                                                  # un commentaire apres le ';' sur la meme ligne
                                                | \b(?: if
                                                    | while
                                                    | for
                                                    | foreach )
                                                  \s* \( [^;\{\(]* \) \s* ; [\ \t]* \/[\/\*]
                                                  # un commentaire avant le 'else'
                                                | [\/\*]\/ \s* \b else \s* ;
                                                  # un commentaire apres le ';' sur la meme ligne
                                                | \b else \s* ; [\ \t]* \/[\/\*]
                                                /xsg ;

    $trace_detect .= "nombre de commented empty stmts $nbr_CommentedEmptyStmts\n"; # traces_filter_line

    $nbr_UncommentedEmptyStmts -= $nbr_CommentedEmptyStmts;

    my $nbr_CommentedDoWhiles = () = $code =~ /
                                                # un commentaire avant la structure
                                                # il peut y avoir plusieurs lignes de commentaire entre '}' et 'while'
                                                \} \s* \/ [\/\*] [^;\{\(]* \b while \s* \( [^;\{\(]* \) \s* ;
                                                # un commentaire apres le ';' sur la meme ligne
                                              | \} [\ \t]* while \s* \( [^;\{\(]* \) \s* ; [\ \t]* \/ [\/\*]
                                              /xsg ;


    $nbr_UncommentedEmptyStmts += $nbr_CommentedDoWhiles;

    $trace_detect .= "nombre de commented do while $nbr_CommentedDoWhiles\n";                 # traces_filter_line

    print STDERR "$mnemo_UncommentedEmptyStmts = $nbr_UncommentedEmptyStmts\n" if ($debug);                         # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_UncommentedEmptyStmts, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_UncommentedEmptyStmts, $nbr_UncommentedEmptyStmts);

    return $status;
}


1;
