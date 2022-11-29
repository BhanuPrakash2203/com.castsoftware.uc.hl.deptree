package Swift::CountString;
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

my $DuplicatedString__mnemo = Ident::Alias_DuplicatedString();
my $HardCodedPaths__mnemo = Ident::Alias_HardCodedPaths();
my $HardCodedUrl__mnemo = Ident::Alias_HardCodedUrl();

my $nb_DuplicatedString= 0;
my $nb_HardCodedPaths= 0;
my $nb_HardCodedUrl= 0;

sub CountString($$$)
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_DuplicatedString = 0;
    $nb_HardCodedPaths = 0;
    $nb_HardCodedUrl = 0;

    my $MixView =  $vue->{'MixBloc'} ;
    my $HString = $vue->{'HString'};

    if ( ( ! defined $MixView ) || ( ! defined $HString ))
    {
        $ret |= Couples::counter_add($compteurs, $DuplicatedString__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $HardCodedPaths__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $HardCodedUrl__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
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
            # HL-1093 : String literals should not be duplicated
            # String is enclosed by double quotes " so counter is computed as (2 char + 2 quotes = 4)
            if (length $HString->{$id} > 4 && $countID{$id} > 2) {
                # print "String literals $HString->{$id} should not be duplicated more than 3 times\n";
                $nb_DuplicatedString++;
                Erreurs::VIOLATION($DuplicatedString__mnemo, "String literals $HString->{$id} should not be duplicated more than 3 times.");
            }

            # HL-1117 URIs (URL & path) should not be hardcoded
            if ( $HString->{$id} =~ /^"\s*(?:\/|\w:\\)/ ) {
                for my $numLine (@{$numLine{$id}}) {
                    # print "URIs path<$HString->{$id}> should not be hardcoded at line $numLine\n";
                    $nb_HardCodedPaths++;
                    Erreurs::VIOLATION($HardCodedPaths__mnemo, "URIs path<$HString->{$id}> should not be hardcoded at line $numLine.");
                }

            }
            elsif ( $HString->{$id} =~ /^"\s*((http[s]?|[s]?ftp)\:\/\/|www\.|(?:mailto|news)\:|\w+\@)/ ) {
                for my $numLine (@{$numLine{$id}}) {
                    # print "URIs URL<$HString->{$id}> should not be hardcoded at line $numLine\n";
                    $nb_HardCodedUrl++;
                    Erreurs::VIOLATION($HardCodedUrl__mnemo, "URIs URL<$HString->{$id}> should not be hardcoded at line $numLine.");
                }
            }
        }
        else {
            print STDERR "Error line $numLine{$id}: String ID=$id identified in PARSER but not in STRIP\n";
        }
    }

    $ret |= Couples::counter_add($compteurs, $DuplicatedString__mnemo, $nb_DuplicatedString );
    $ret |= Couples::counter_add($compteurs, $HardCodedPaths__mnemo, $nb_HardCodedPaths );
    $ret |= Couples::counter_add($compteurs, $HardCodedUrl__mnemo, $nb_HardCodedUrl );

    return $ret;
}



1;
