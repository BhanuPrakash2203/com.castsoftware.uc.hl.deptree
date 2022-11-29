package ObjC::CountObjC;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

# prototypes publics
sub CountKeywords($$$);

# prototypes prives
sub CountItem($$$$);

my $mnemo_WithoutInterfaceImplementation = Ident::Alias_WithoutInterfaceImplementation();

my $nb_WithoutInterfaceImplementation = 0;


#-------------------------------------------------------------------------------
# DESCRIPTION: fonction de comptage d'item
#-------------------------------------------------------------------------------
sub CountItem($$$$)
{
    my ($item, $mnemo_Item, $code, $compteurs) = @_ ;
    my $status = 0;

    if (!defined $$code )
    {
        $status |= Couples::counter_add($compteurs, $mnemo_Item, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $nbr_Item = () = $$code =~ /${item}/sg;
    $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des mots cles
#-------------------------------------------------------------------------------
sub CountKeywords($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $code = \$vue->{'ObjC'};

    my $prepro_directives = \$vue->{'prepro_directives'};

    #$status |= CountItem('\[\s*NSNumber\s+numberWith', Ident::Alias_MissingBoxedOrLiteral(), $code, $compteurs);
    $status |= CountItem('\bNSLog\b',                  Ident::Alias_NSLog(),                 $code, $compteurs);
    $status |= CountItem('#pragma\s+mark\b',           Ident::Alias_PragmaMark(),            $prepro_directives, $compteurs);
    $status |= CountItem('import',                     Ident::Alias_Import(),       $prepro_directives, $compteurs);
    $status |= CountItem('(?:s|v|f|vf|vs)?scanf',      Ident::Alias_Scanf(),        $code, $compteurs);
    $status |= CountItem('@class',                     Ident::Alias_ForwardClass(),          $code, $compteurs);
#    $status |= CountItem('include', Ident::Alias_Include(),  $prepro_directives, $compteurs);

    return $status;
}

sub CountMissingBoxedOrLiteral($$$$)
{
    my $status = 0;

    my $mnemo_MissingBoxedOrLiteral = Ident::Alias_MissingBoxedOrLiteral();
    my $nb_MissingBoxedOrLiteral = 0;
    my ($fichier, $vue, $compteurs, $options) = @_;

    my $code = \$vue->{'ObjC'};
 
    $nb_MissingBoxedOrLiteral = () = $$code =~ /(?:\[\s*NSNumber\s+numberWith|\[\s*\[\s*NSNumber\s+alloc\s*\]\s*initWith)/sg;

    $status |= Couples::counter_add ($compteurs, $mnemo_MissingBoxedOrLiteral, $nb_MissingBoxedOrLiteral);
    return $status;
}
    
sub CountWithoutInterfaceImplementation($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_WithoutInterfaceImplementation = 0;

    my $code = \$vue->{'prepro_directives'};

    if (not defined $code)
    {
        $status |= Couples::counter_add ($compteurs, $mnemo_WithoutInterfaceImplementation, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    # capture basename
    my ($basename) = $fichier =~ /([^\/\\]*)$/;
    #remove extension (if any)
    $basename =~ s/\.[^\.]*$//s;

    my $found = 0;
    my $Hstrings = $vue->{'HString'};
    # search in #include "...."
    while ( $$code =~ /#(?:include|import)\s+(CHAINE_\d+)/g ) {
      if ($Hstrings->{$1} =~ /$basename\.[HhPp+]+\s*/s) {
         $found = 1;
	 last;
      }
    } 

    # search in #include <>
    if ( ! $found ) {
       if ( $$code =~ /#\s*include\s+<[^>]*$basename\.[HhPp+]+>/s ) {
          $found = 1;
       }
    }

    if ( ! $found ) {
      	  $nb_WithoutInterfaceImplementation++;
#print "VIOLEMENT ==> WithoutInterfaceImplementation\n";
    }

    $status |= Couples::counter_add ($compteurs, $mnemo_WithoutInterfaceImplementation, $nb_WithoutInterfaceImplementation);
    return $status;
}



1;
