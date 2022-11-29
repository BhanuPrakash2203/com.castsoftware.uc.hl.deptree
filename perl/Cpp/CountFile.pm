package Cpp::CountFile;

use strict;
use warnings;

use CountUtil;
use Erreurs;

my $mnemo_WithoutInterfaceImplementation = Ident::Alias_WithoutInterfaceImplementation();
my $mnemo_CallToBlockingFunction = Ident::Alias_CallToBlockingFunction();

my $nb_WithoutInterfaceImplementation = 0;
my $nb_CallToBlockingFunction = 0;

sub CountWithoutInterfaceImplementation($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    my $nb_WithoutInterfaceImplementation = 0;

    if (not defined $vue->{'code'})
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
    while ( $vue->{'code'} =~ /#include\s+(CHAINE_\d+)/g ) {
      if ($Hstrings->{$1} =~ /$basename\.[HhPp+]+\s*/s) {
         $found = 1;
	 last;
      }
    } 

    # search in #include <>
    if ( ! $found ) {
       if ( $vue->{'code'} =~ /#\s*include\s+<[^>]*$basename\.[HhPp+]+>/s ) {
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

sub CountCallToBlockingFunction($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    my $nb_CallToBlockingFunction = 0;

    if (not defined $vue->{'code'})
    {
        $status |= Couples::counter_add ($compteurs, $mnemo_CallToBlockingFunction, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    while ( $vue->{'code'} =~ /\b(?:WaitForSingleObject|WaitForMultipleObjects|Sleep)\b\s*\(([^;\{]+)/g) {
        if ($1 =~ /\bINFINITE\b/) {
            $nb_CallToBlockingFunction++;
#print "FOUND call to blocking fct !!!\n";
	}
    }
    

    $status |= Couples::counter_add ($compteurs, $mnemo_CallToBlockingFunction, $nb_CallToBlockingFunction);
    return $status;
}



1;

