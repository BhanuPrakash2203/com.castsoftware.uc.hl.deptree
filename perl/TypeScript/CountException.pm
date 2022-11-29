package TypeScript::CountException;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use TypeScript::TypeScriptNode;
use TypeScript::Identifiers;

my $DEBUG = 0;
my $IllegalThrows__mnemo = Ident::Alias_IllegalThrows();

my $nb_IllegalThrows = 0;

# HL-856 25/04/2019 Strings should not be thrown
sub CountException($$$) 
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_IllegalThrows = 0;

    my $root =  $vue->{'structured_code'} ;

    if ( ! defined $root )
    {
        $ret |= Couples::counter_add($compteurs, $IllegalThrows__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @throws = GetNodesByKind($root, ThrowKind);

    for my $throw (@throws)
    {
        if (defined ${GetStatement($throw)} and ${GetStatement($throw)} =~ /\bCHAINE_[0-9]+\b/)
        {
            print "Strings should not be thrown at line ".GetLine($throw)."\n" if $DEBUG;
            $nb_IllegalThrows++;
            Erreurs::VIOLATION($IllegalThrows__mnemo, "Strings should not be thrown at line ".GetLine($throw));
        }
    }
  
    $ret |= Couples::counter_add($compteurs, $IllegalThrows__mnemo, $nb_IllegalThrows );

    return $ret;
}


1;
