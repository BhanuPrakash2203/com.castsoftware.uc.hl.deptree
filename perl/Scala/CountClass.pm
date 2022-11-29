package Scala::CountClass;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Scala::ScalaNode;

my $ClassImplementations__mnemo = Ident::Alias_ClassImplementations();
my $Object__mnemo = Ident::Alias_ObjectDeclaration();
my $Interface__mnemo = Ident::Alias_Interface();
my $TotalAttributes__mnemo = Ident::Alias_TotalAttributes();

my $nb_ClassImplementations = 0;
my $nb_Object = 0;
my $nb_Interface = 0;
my $nb_TotalAttributes = 0;

sub CountClass($$$) {
	my ($file, $vue, $compteurs) = @_;

	my $ret = 0;
	$nb_ClassImplementations = 0;
	$nb_Object = 0;
	$nb_Interface = 0;
	$nb_TotalAttributes = 0;

	my $KindsLists = $vue->{'KindsLists'};

	if (!defined $KindsLists) {
		$ret |= Couples::counter_add($compteurs, $ClassImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
		$ret |= Couples::counter_add($compteurs, $Object__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
		$ret |= Couples::counter_add($compteurs, $Interface__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
		$ret |= Couples::counter_add($compteurs, $TotalAttributes__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);

		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}

	my @classes = @{$vue->{'KindsLists'}->{&ClassKind}};
	my @objects = @{$vue->{'KindsLists'}->{&ObjectKind}};
	my @interfaces = @{$vue->{'KindsLists'}->{&TraitKind}};
	my @attributes = @{$vue->{'KindsLists'}->{&VarKind}};

	for my $attribute (@attributes) {
		if (IsKind(GetParent($attribute), ClassKind) || IsKind(GetParent($attribute), ObjectKind)) {
			$nb_TotalAttributes++;
		}
	}

	## METRICS
	$nb_ClassImplementations = scalar(@classes);
	$nb_Object = scalar(@objects);
	$nb_Interface = scalar(@interfaces);

	$ret |= Couples::counter_add($compteurs, $ClassImplementations__mnemo, $nb_ClassImplementations);
	$ret |= Couples::counter_add($compteurs, $Object__mnemo, $nb_Object);
	$ret |= Couples::counter_add($compteurs, $Interface__mnemo, $nb_Interface);
	$ret |= Couples::counter_add($compteurs, $TotalAttributes__mnemo, $nb_TotalAttributes);

	return $ret;
}

1;
