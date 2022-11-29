package TypeScript::CountClass;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use TypeScript::TypeScriptNode;
use TypeScript::Identifiers;
use TypeScript::CountNaming;

my $DEBUG = 0;
my $BadInterfaceConstructor__mnemo = Ident::Alias_BadInterfaceConstructor();
my $OptionalProperty__mnemo = Ident::Alias_OptionalProperty();
my $ShortClassNamesLT__mnemo = Ident::Alias_ShortClassNamesLT();
my $BadClassNames__mnemo = Ident::Alias_BadClassNames();
my $TotalAttributes__mnemo = Ident::Alias_TotalAttributes();


my $nb_BadInterfaceConstructor = 0;
my $nb_OptionalProperty = 0;
my $nb_ShortClassNamesLT = 0;
my $nb_BadClassNames = 0;
my $nb_TotalAttributes = 0;

# HL-854 24/04/2019 Constructors should not be declared inside interfaces
sub CountInterface($$$) 
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_BadInterfaceConstructor = 0;
    
    my $root =  $vue->{'structured_code'} ;

    if ( ! defined $root )
    {
        $ret |= Couples::counter_add($compteurs, $BadInterfaceConstructor__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
    
    my @interfaces = GetNodesByKind($root, InterfaceKind);
    
    for my $interface (@interfaces)
    {
        my @MethodProto = GetNodesByKind($interface, MethodProtoKind);
        
        for my $MethodProto (@MethodProto)
        {
            # print "name = ".GetName($MethodProto)."\n";
            if (defined GetName($MethodProto) and GetName($MethodProto) =~ /\bnew\b|\bconstructor\b/)
            {
                $nb_BadInterfaceConstructor++;
                print "Constructors should not be declared inside interfaces at line ".GetLine($MethodProto) ."\n" if $DEBUG;
                Erreurs::VIOLATION($BadInterfaceConstructor__mnemo, "Constructors should not be declared inside interfaces at line ".GetLine($MethodProto));
            }
        }
    }

    $ret |= Couples::counter_add($compteurs, $BadInterfaceConstructor__mnemo, $nb_BadInterfaceConstructor );

    return $ret;
}

# HL-860 30/04/2019 Optional property declarations should use '?' syntax
sub CountAttribute
{
    my ($fichier, $vue, $compteurs, $options) = @_ ;
    my $ret = 0;
    $nb_OptionalProperty = 0;
    $nb_TotalAttributes = 0;
        
    my $root = $vue->{'structured_code'};

    if (not defined $root)
    {
        $ret |= Couples::counter_add ($compteurs, $OptionalProperty__mnemo , Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add ($compteurs, $TotalAttributes__mnemo , Erreurs::COMPTEUR_ERREUR_VALUE);
        return $ret;
    }
    
    my @props = GetNodesByKind($root, AttributeKind);
    
    $nb_TotalAttributes = scalar @props;

    for my $prop (@props) 
    {
        my $propName = GetName($prop);
        my $PropertyType = Lib::NodeUtil::GetXKindData($prop, 'type');
        
        if (defined $PropertyType and $PropertyType =~ /\|\s*undefined\b/)
        {
            $nb_OptionalProperty++;
            print "Optional property declarations should use '?' and not '|undefined' syntax at line ".GetLine($prop) ."\n" if $DEBUG;
            Erreurs::VIOLATION($OptionalProperty__mnemo, "Optional property declarations should use '?' and not '|undefined' syntax at line ".GetLine($prop));
        }
    }
    
    $ret |= Couples::counter_add($compteurs, $OptionalProperty__mnemo, $nb_OptionalProperty );
    $ret |= Couples::counter_add($compteurs, $TotalAttributes__mnemo, $nb_TotalAttributes );
    
    return $ret;
}

sub CountClass() {
	my ($fichier, $vue, $compteurs, $options) = @_ ;
    my $ret = 0;
    $nb_ShortClassNamesLT = 0;
    $nb_BadClassNames = 0;
    
    my $root = $vue->{'structured_code'};

    if (not defined $root)
    {
        $ret |= Couples::counter_add ($compteurs, $ShortClassNamesLT__mnemo , Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add ($compteurs, $BadClassNames__mnemo , Erreurs::COMPTEUR_ERREUR_VALUE);
        return $ret;
    }
    
    my @artifacts = GetNodesByKindList($root, [ClassDeclarationKind, InterfaceKind]);
    
    my $cumulated_name_size = 0;
    my $nb_namedClasses = 0;
    
	for my $arti (@artifacts) {
		my $name = GetName($arti);
	
		$nb_BadClassNames += TypeScript::CountNaming::checkPascalCase(\$name);
		
		$nb_namedClasses++;
		$cumulated_name_size += length($name);
	}
	
	if ($nb_namedClasses) {
		$nb_ShortClassNamesLT = int ($cumulated_name_size / $nb_namedClasses);
	}
   
   
	Erreurs::VIOLATION($ShortClassNamesLT__mnemo , "METRIC : class name length average = $nb_ShortClassNamesLT ");
	
    $ret |= Couples::counter_add($compteurs, $ShortClassNamesLT__mnemo, $nb_ShortClassNamesLT );
    $ret |= Couples::counter_add($compteurs, $BadClassNames__mnemo, $nb_BadClassNames );
    
    return $ret;
}

1;
