package Swift::CountException;
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

my $DangerousTry__mnemo = Ident::Alias_DangerousTry();
my $OnlyRethrowingCatches__mnemo = Ident::Alias_OnlyRethrowingCatches();

my $nb_DangerousTry= 0;
my $nb_OnlyRethrowingCatches= 0;

sub CountException($$$) 
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_DangerousTry = 0;
    $nb_OnlyRethrowingCatches = 0;

    my $root =  \$vue->{'code'} ;

    if ( ( ! defined $root ) )
    {
        $ret |= Couples::counter_add($compteurs, $DangerousTry__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
	my @tryExceptions = @{$vue->{'KindsLists'}->{'Try'}};
	my @catchExceptions = @{$vue->{'KindsLists'}->{'Catch'}};

    for my $tryException (@tryExceptions) {
        my $stmt = GetStatement($tryException);
        # HL-1092 : "try!" should not be used
        if (defined $$stmt && $$stmt =~ /^try\!/m) {
            # print "\"try!\" should not be used at line ".GetLine($tryException)."\n";
            $nb_DangerousTry++;
            Erreurs::VIOLATION($DangerousTry__mnemo, "\"try!\" should not be used at line ".GetLine($tryException).".");
        }
    }

    # HL-1115 "catch" clauses should do more than throw
    for my $catch (@catchExceptions) {
        my $acco = GetChildren($catch)->[0];
        my $children = GetChildren($acco);

        if (scalar @{$children} == 1 && IsKind($children->[0], ThrowKind)) {
            # print "\"catch\" clauses should do more than throw at line ". GetLine($children->[0]) ."\n";
            $nb_OnlyRethrowingCatches++;
            Erreurs::VIOLATION($OnlyRethrowingCatches__mnemo, "\"catch\" clauses should do more than throw at line ".GetLine($children->[0]).".");
        }
    }

    $ret |= Couples::counter_add($compteurs, $DangerousTry__mnemo, $nb_DangerousTry );
    $ret |= Couples::counter_add($compteurs, $OnlyRethrowingCatches__mnemo, $nb_OnlyRethrowingCatches );

    return $ret;
}



1;
