package TypeScript::CountString;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use TypeScript::TypeScriptNode;
use TypeScript::Identifiers;

my $IDENTIFIER = TypeScript::Identifiers::getIdentifiersPattern();
my $IDENT_CHAR = TypeScript::Identifiers::getIdentifiersCharacters();
my $DEBUG = 0;

my $MultilineString__mnemo = Ident::Alias_MultilineString();
my $UnexpectedDoubleQuoteStr__mnemo = Ident::Alias_UnexpectedDoubleQuoteStr();
my $String__mnemo = Ident::Alias_String();
my $MultilineBreak__mnemo = Ident::Alias_MultilineBreak();

my $nb_MultilineString = 0;
my $nb_UnexpectedDoubleQuoteStr = 0;
my $nb_String = 0;
my $nb_MultilineBreak = 0;

sub isBadDoubleQuote($) {
  my $value = shift;

  if ( $$value =~ /\A"(.*)"\z/s ) {
    if ( $1 !~ /'/s ) {
      return 1;
    }
  }
  return 0;
}

sub CountString($$$) 
{
    my ($file, $view, $compteurs) = @_ ;

    my $ret = 0;
    $nb_MultilineString = 0;
    $nb_UnexpectedDoubleQuoteStr = 0;
    $nb_String = 0;
    $nb_MultilineBreak = 0;

    my $strings = $view->{'HString'};
    my $root = $view->{'structured_code'};
    my $code = $view->{'code'};

    if ( ( ! defined $strings ) || 
       ( ! defined $view->{'KindsLists'}) ||
       ( ! defined $view->{'artifact'}) )
    {
        $ret |= Couples::counter_add($compteurs, $MultilineString__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $UnexpectedDoubleQuoteStr__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $MultilineBreak__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @funcs = ( @{$view->{'KindsLists'}->{'FunctionDeclaration'}},
                @{$view->{'KindsLists'}->{'FunctionExpression'}},
                $root
                );

    for my $func (@funcs) {
        my $name = GetName($func);
        # Do not proceed in case of a virtual root node, if we are in unit analysis
        # mode.
        # Virtual root node have been created to contain analysis units
        # extracted from the real root node. But they corresponds to nothing in
        # the code.
        if ( (! IsKind($func, RootKind)) || ($name ne 'virtualRoot') ) {
            my $line = GetLine($func);
            my $artiKey = buildArtifactKeyByData($name, $line);
            my $funcArtifact = $view->{'artifact'}->{$artiKey};

            if (defined $funcArtifact) {
                while ($funcArtifact =~ /\b(CHAINE_\d+)/sg) {
                    my $value = $strings->{$1};
                    if ($value =~ /\n/) {
                        #print "STRING VALUE : $value\n";
                        #print " --> violation !!\n";
                        $nb_MultilineString++;
                    }

                    if (isBadDoubleQuote(\$value)) {
                        #print "STRING VALUE : $value\n";
                        #print "-->Bad Double quote !!\n";
                        $nb_UnexpectedDoubleQuoteStr++;
                    }
                }
            }
            else {
                    print "ERROR : no artifact for $artiKey !!\n";
                    $ret |= Couples::counter_add($compteurs, $MultilineString__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
                    $ret |= Couples::counter_add($compteurs, $UnexpectedDoubleQuoteStr__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
                    return $ret |= Erreurs::COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE;
            }
        }
    }

    $nb_String = scalar keys %{$strings};
    
    # HL-855 25/04/2019 Multiline string literals should not be used
    my $numline = 1;
    while ($code =~ /(\n)|(\bCHAINE_[0-9]+\b)|[^\n]/g)
    {
        if (defined $1)
        {
            $numline++;
        }
        elsif (defined $2)
        {
            if ($strings->{$2} =~ /\\\s*\n/)
            {
                $nb_MultilineBreak++;
                print "Multiline string literals should not be used at line $numline\n" if $DEBUG;
                Erreurs::VIOLATION($MultilineBreak__mnemo, "Multiline string literals should not be used at line $numline");
            }
        }
    
    }
    
    $ret |= Couples::counter_add($compteurs, $MultilineString__mnemo, $nb_MultilineString );
    $ret |= Couples::counter_add($compteurs, $UnexpectedDoubleQuoteStr__mnemo, $nb_UnexpectedDoubleQuoteStr );
    $ret |= Couples::counter_add($compteurs, $String__mnemo, $nb_String );
    $ret |= Couples::counter_add($compteurs, $MultilineBreak__mnemo, $nb_MultilineBreak );

    return $ret;
}


1;
