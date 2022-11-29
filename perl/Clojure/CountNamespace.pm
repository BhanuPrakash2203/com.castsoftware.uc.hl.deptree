package Clojure::CountNamespace;
# les modules importes
use strict;
use warnings;
use Erreurs;

use Clojure::ClojureNode;
use Lib::NodeUtil;

my $DeprecatedReferenceInNamespace__mnemo = Ident::Alias_DeprecatedReferenceInNamespace();
my $BadDeclarationOrder__mnemo = Ident::Alias_BadDeclarationOrder();
my $MissingIdiomaticAliases__mnemo = Ident::Alias_MissingIdiomaticAliases();

my $nb_DeprecatedReferenceInNamespace = 0;
my $nb_BadDeclarationOrder = 0;
my $nb_MissingIdiomaticAliases = 0;

my %IDIOMATIC_ALIASES = (
		"clojure.java.io" => "io",
		"clojure.set" => "set",
		"clojure.string" => "str",
		"clojure.walk" => "walk",
		"clojure.zip" => "zip",
		"clojure.data.xml" => "xml",
		"clojure.core.async" => "as",
		"clojure.core.matrix" => "mat",
		"clojure.edn" => "edn",
		"clojure.pprint" => "pp",
		"clojure.spec.alpha" => "spec",
		"clojure.data.csv" => "csv",
		"cheshire.core" => "json",
		"java-time" => "time",
		"clj-http.client" => "http",
		"clojure.tools.logging" => "log",
		"hugsql.core" => "sql",
		"clj-yaml.core" => "yaml",
		"clojure.java.shell" => "sh"
);

sub CountNamespace() {
	my ($file, $vue, $compteurs) = @_ ;
	
	my $ret = 0;
    $nb_DeprecatedReferenceInNamespace = 0;
    $nb_BadDeclarationOrder = 0;
    $nb_MissingIdiomaticAliases = 0;
    
	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
    {
        $ret |= Couples::counter_add($compteurs, $DeprecatedReferenceInNamespace__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $BadDeclarationOrder__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $MissingIdiomaticAliases__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
    
    my $namespaces = $KindsLists->{&NamespaceKind};
    
    for my $namespace (@$namespaces) {
		my $references = Clojure::ClojureNode::getClojureKindData($namespace, 'references');
		
		for my $importKey (keys %$references) {
#print STDERR "IMPORT KEY : $importKey\n";
			if ($importKey eq ":use") {
				$nb_DeprecatedReferenceInNamespace++;
				Erreurs::VIOLATION($DeprecatedReferenceInNamespace__mnemo,"Derecated use of ':use' in namespace at line ".GetLine($namespace));
			}
			my $previous = "";
			my $badOrder = 0;
			for my $module (@{$references->{$importKey}}) {
#print STDERR "     --> import MODULE = $module->{'name'}, DEF = $module->{'definition'}\n";
				my $name = $module->{'name'};
				if ( (! $badOrder) && (lc($name) lt lc($previous)) ) {
					$nb_BadDeclarationOrder++;
					Erreurs::VIOLATION($BadDeclarationOrder__mnemo,"$importKey clause is not ordered in namespace ($previous is not < $name) at line ".GetLine($namespace));
					$badOrder = 1;
				}
				
				my $def = $module->{'definition'};
#print STDERR "DEFINTION $def\n";
				if ( $def =~ /:as\s+([^\s]+)/) {
					if (defined $IDIOMATIC_ALIASES{$module->{'name'}}) {
						if ($IDIOMATIC_ALIASES{$module->{'name'}} ne $1) {
							$nb_MissingIdiomaticAliases++;
							Erreurs::VIOLATION($MissingIdiomaticAliases__mnemo,"Bad idiomatic alias ($1) for $module->{'name'} at line ".GetLine($namespace));
						} 
					}
				}
				
				$previous = $name;
			}
		}
	}

	$ret |= Couples::counter_add($compteurs, $DeprecatedReferenceInNamespace__mnemo, $nb_DeprecatedReferenceInNamespace );
	$ret |= Couples::counter_add($compteurs, $BadDeclarationOrder__mnemo, $nb_BadDeclarationOrder );
	$ret |= Couples::counter_add($compteurs, $MissingIdiomaticAliases__mnemo, $nb_MissingIdiomaticAliases );
  
	return $ret;
}

1;
