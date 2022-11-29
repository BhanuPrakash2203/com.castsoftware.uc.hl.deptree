package Go::CountString;
# les modules importes
use strict;
use warnings;

use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use Go::GoNode;
use Go::GoConfig;

my $DEBUG = 0;

my $DuplicatedString__mnemo = Ident::Alias_DuplicatedString();

my $nb_DuplicatedString= 0;

sub CountString($$$)
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_DuplicatedString = 0;

    my $MixView =  $vue->{'MixBloc'} ;
    my $HString = $vue->{'HString'};

    if ( ( ! defined $MixView ) || ( ! defined $HString ))
    {
        $ret |= Couples::counter_add($compteurs, $DuplicatedString__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my %countID;
    my %numLine;
    my $numLine = 1;
    while ($MixView =~ /(CHAINE_[0-9]+)|(\n)/g) {
        if (defined $1) {
            $countID{$1}++;
            push (@{$numLine{$1}}, $numLine);
        }
        $numLine++ if defined ($2);
    }

    for my $id (keys %countID) {
        if (exists $HString->{$id}) {
            # HL-1588 14/01/2021 String literals should not be duplicated
            # String is enclosed by double quotes " so counter is computed as (2 char + 2 quotes = 4)
            if (length $HString->{$id} > 4 && $countID{$id} > 3) {
                # print "String literals $HString->{$id} should not be duplicated more than 3 times\n";
                $nb_DuplicatedString++;
                Erreurs::VIOLATION($DuplicatedString__mnemo, "String literals $HString->{$id} should not be duplicated more than 3 times.");
            }
        }
        else {
            print STDERR "Error line $numLine{$id}: String ID=$id identified in PARSER but not in STRIP\n";
        }
    }

    $ret |= Couples::counter_add($compteurs, $DuplicatedString__mnemo, $nb_DuplicatedString );

    return $ret;
}



1;
