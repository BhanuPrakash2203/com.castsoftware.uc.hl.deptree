package Python::CountImport;

use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Python::PythonNode;
use Python::PythonConf;

my $ConflictingImports__mnemo = Ident::Alias_ConflictingImports();
my $StarImport__mnemo = Ident::Alias_StarImport();
my $MultipleImports__mnemo = Ident::Alias_MultipleImports();
my $UnusedImports__mnemo = Ident::Alias_UnusedImports();
my $BadAliasAgreement__mnemo = Ident::Alias_BadAliasAgreement();

my $nb_ConflictingImports = 0;
my $nb_StarImport = 0;
my $nb_MultipleImports = 0;
my $nb_UnusedImports = 0;
my $nb_BadAliasAgreement = 0;

my %H_aliases = ();
my %H_imports = ();


sub checkUsed($$) {
	my $import =shift;
	my $r_code = shift;
	
	if ($import ne "*") {
		if ($$r_code !~ /\b$import\b/s) {
			$nb_UnusedImports++;
			Erreurs::VIOLATION($UnusedImports__mnemo, "Unused import $import");
		}
	}
}

sub checkMissingDedicatedAlias($$) {
	my $module = shift;
	my $alias = shift;
	
	my $expectedAlias = $Python::PythonConf::DEDICATED_ALIASES{$module};

	if (defined $expectedAlias) {
		if ((defined $alias) && ($alias ne $expectedAlias)) {
			Erreurs::VIOLATION($BadAliasAgreement__mnemo, "Bad alias agreement ($alias) for module $module");
			$nb_BadAliasAgreement++;
		}
	}
}

sub checkImport($$$) {
	my $T_imports = shift;
	my $module = shift;
	my $r_code = shift;

	for my $import (@$T_imports) {
		
		if ($import =~ /([\w\*\.]+)(?:\s+\bas\s+(\w+))?/) {
			
			checkMissingDedicatedAlias($1, $2);
			
			if (defined $2) {
				# --- found an alias
				
				checkUsed($2, $r_code);
				
				if (defined $H_aliases{$2}) {
					$nb_ConflictingImports++;
					Erreurs::VIOLATION($ConflictingImports__mnemo, "Conflicting alias $2 for import $1");
				}
				$H_aliases{$2} = 1;
			}
			else {
				# --- found a single import
				
				checkUsed($1, $r_code);

				if (defined $module) {
					if ((defined $H_imports{$1}) && ($H_imports{$1} ne $module)) {
						$nb_ConflictingImports++;
						Erreurs::VIOLATION($ConflictingImports__mnemo, "Conflicting import $1 from module $module (conflicting with module $H_imports{$1})");
					}
					else {
						$H_imports{$1} = $module;
					}
				}
			}
			
			if ($1 eq '*') {
				$nb_StarImport++;
				Erreurs::VIOLATION($StarImport__mnemo, "import * ");
			}
		}
		else {
			print STDERR "[CountImport] WARNING : strange import syntax encountered (invalid or none import clause, or maybe an empty element in the import list)!!!\n";
		} 
	}
}

sub CountImports($$$) {
	my ($file, $views, $compteurs) = @_ ;
	my $ret =0;

	$nb_ConflictingImports = 0;
	$nb_StarImport = 0;
	$nb_MultipleImports = 0;
	$nb_UnusedImports = 0;
	$nb_BadAliasAgreement = 0;
	
	my $kindLists = $views->{'KindsLists'};
	my $code = $views->{'code'};

	if (!defined $code) {
		$ret |= Couples::counter_add($compteurs, $UnusedImports__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	if ( ! defined $kindLists ) {
		$ret |= Couples::counter_add($compteurs, $ConflictingImports__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $StarImport__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $MultipleImports__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadAliasAgreement__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	# remove import statement, if not they will falsify the grep to check for unused imports.
	$code =~ s/^\s*(?:from|import)\b.*?[^\\]\n//msg;

	while ($code =~ /\bself\._\w|(\w+\._[a-zA-Z0-9]\w+)/sg) {
	#while ($code =~ /\bself\._/sg) {
		if (defined $1) {
			Erreurs::VIOLATION("TBD", "Exposing private member : $1");
		}
	}
	
	my $froms = $kindLists->{&FromKind};
	my $imports = $kindLists->{&ImportKind};

	%H_aliases = ();
	%H_imports = ();

	for my $from (@$froms) {
		${GetStatement($from)} =~ s/\\\n/ /g;
		if (${GetStatement($from)} =~ /\A\s*([\w\.]+)\s+import([^)]+)/) {
			my $module = $1;
			my @T_imports = split '\s*,\s*', $2;
			checkImport(\@T_imports, $module, \$code);
		}
		else {
			print STDERR "[CountImport] WARNING : strange import syntax encountered : ${GetStatement($from)} !!!\n";
		}
	}
	
	for my $import (@$imports) {
		my @T_imports = split ',', ${GetStatement($import)};
		
		checkImport(\@T_imports, undef, \$code);
		
		if (scalar @T_imports > 1) {
			$nb_MultipleImports++;
			Erreurs::VIOLATION($MultipleImports__mnemo, "Multiple imports on the same line at line ".GetLine($import));
		}
	}

	$ret |= Couples::counter_update($compteurs, $ConflictingImports__mnemo, $nb_ConflictingImports );
	$ret |= Couples::counter_update($compteurs, $StarImport__mnemo, $nb_StarImport );
	$ret |= Couples::counter_update($compteurs, $MultipleImports__mnemo, $nb_MultipleImports );
	$ret |= Couples::counter_update($compteurs, $UnusedImports__mnemo, $nb_UnusedImports );
	$ret |= Couples::counter_update($compteurs, $BadAliasAgreement__mnemo, $nb_BadAliasAgreement );

	return $ret;
}

1;



