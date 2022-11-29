package Swift::CountVariable;
# les modules importes
use strict;
use warnings;

use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use Swift::SwiftNode;
use Swift::Identifiers;
use Swift::SwiftConfig;

my $DEBUG = 0;

my $MultipleDeclarationsInSameStatement__mnemo = Ident::Alias_MultipleDeclarationsInSameStatement();

my $nb_MultipleDeclarationsInSameStatement= 0;

sub CountVariable($$$)
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_MultipleDeclarationsInSameStatement = 0;

    my $code =  $vue->{'code'} ;

    if ( ! defined $code )
    {
        $ret |= Couples::counter_add($compteurs, $MultipleDeclarationsInSameStatement__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @varDecl = @{$vue->{'KindsLists'}->{'VarDecl'}};
    my %numLineVar;

    for my $varDecl (@varDecl) {
        # HL-1110 Multiple variables should not be declared on the same line
        if ( exists $numLineVar{ GetLine($varDecl) } && $numLineVar{ GetLine($varDecl) } < 2) {
            # print "Multiple variables should not be declared on the same line at line " . GetLine($varDecl). "\n";
            $nb_MultipleDeclarationsInSameStatement++;
            Erreurs::VIOLATION($MultipleDeclarationsInSameStatement__mnemo, "Multiple variables should not be declared on the same line at line " . GetLine($varDecl) .".");
        }
        $numLineVar{ GetLine($varDecl) }++;
    }

    $ret |= Couples::counter_add($compteurs, $MultipleDeclarationsInSameStatement__mnemo, $nb_MultipleDeclarationsInSameStatement );

    return $ret;
}



1;
