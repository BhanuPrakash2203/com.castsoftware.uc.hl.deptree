package Scala::CountVariable;
# les modules importes
use strict;
use warnings;

use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use Scala::ScalaNode;
use Scala::ScalaConfig;

my $DEBUG = 0;

my $PublicAttributes__mnemo = Ident::Alias_PublicAttributes();

my $nb_PublicAttributes= 0;

sub CountVariable($$$)
{
    my ($file, $vue, $compteurs) = @_;

    my $ret = 0;
    $nb_PublicAttributes = 0;

    my $code = \$vue->{'code'};

    if (!defined $code) {
        $ret |= Couples::counter_add($compteurs, $PublicAttributes__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);

        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @VarStatements = @{$vue->{'KindsLists'}->{&VarKind}};

    for my $var (@VarStatements) {
        if (IsKind(GetParent($var), ClassKind) || IsKind(GetParent($var), ObjectKind)) {
            # HL-1997 30/03/2022 Avoid public attributes
            my $modifiers = getScalaKindData($var, 'modifiers');
            # no modifier = public
            if (!defined $modifiers) {
                # print "Public attribute for " . GetKind(GetParent($var)) . " " . GetName(GetParent($var)) . " at line " . GetLine($var) . "\n";
                Erreurs::VIOLATION($PublicAttributes__mnemo, "Public attribute for " . GetKind(GetParent($var)) . " " . GetName(GetParent($var)) . " at line " . GetLine($var));
                $nb_PublicAttributes++;
            }
        }
    }

    $ret |= Couples::counter_add($compteurs, $PublicAttributes__mnemo, $nb_PublicAttributes);

    return $ret;
}

1;
