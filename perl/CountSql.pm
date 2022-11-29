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

# Description: Composant de comptages sur code source

package CountSql;
use strict;
use warnings; 
use Erreurs;
use Couples;
use Timeout;

# compte le nombre de lignes non vides du buffer
sub count_nonempty_lines($)
{
    my ($sca) = @_ ;
    my @x = $sca =~ /\S[^\n]*\n/smgo ;
    my $n = @x ;
    return $n;
}

# compte le nombre de lignes du buffer
sub count_lines($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\n/smgo ;
    return $n;
}

# compte le nombre de lignes blanches du buffer
sub count_blank_lines($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /^\s*?\n/smgo ;
    return $n;
}

# compte le nombre de lignes avec caractere alphanum du buffer
sub count_alphanum_lines($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\p{IsAlnum}[^\n]*\n/smgo ;
    return $n;
}




# Recuperation en cas d'erreur sur un comptage
sub try_count_measure($$$$)
{
    my ($desc, $proc, $arg, $ref_status) = @_;
    my $c;

    if (not defined ($arg))
    { 
				$c = Erreurs::COMPTEUR_ERREUR_VALUE;
                $$ref_status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE; # si une vue necessaire a l'algorithme de comptage n'est pas disponible
    }
    else
    {
            #my $ok = 1 ;
            eval
            {
                $c = $proc->($arg);
            };
            if ($@)
            {
                Timeout::DontCatchTimeout();   # propagate timeout errors
                print STDERR "\n\n erreur dans $desc, avec $proc : $@ : $!\n avec le buffer \n" . substr($arg,0,400) . "\n...\n\n";
                #$ok=0;
				$c = Erreurs::COMPTEUR_ERREUR_VALUE;
                $$ref_status |= Erreurs::COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE; # si un ou plusieurs comptages n'ont pas pu etre effectues
            }
    }
    return $c;
}

my @comptages = (
    [Ident::Alias_SqlLines(), \&count_nonempty_lines, "sql"],
    #[Ident::Alias_BlankLines(), \&count_blank_lines, "text"],
    #[Ident::Alias_CommentLines(), \&count_nonempty_lines, "comment"],
    #[Ident::Alias_AlphaNumCommentLines(), \&count_alphanum_lines, "comment"],
    #[Ident::Alias_LinesOfCode(), \&count_nonempty_lines, "code"],
);


# Point d'entree du module de comptage
sub CountSql($$$)
{
    my ($fichier, $vue, $compteurs) = @_;
    my $status = 0;

    foreach  my $c (  @comptages )
    {
        my $m = try_count_measure ( $c->[0], $c->[1], $vue->{ $c->[2] }, \$status );
        eval
        {
          Couples::counter_add($compteurs, $c->[0], $m );
        };
        if ($@)
        {
          Timeout::DontCatchTimeout();   # propagate timeout errors
          print STDERR "Mesure non prise en compte: $@\n" ;
        }
    }
    return $status;
}


1;

