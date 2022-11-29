package CS::CountClass;

use strict;
use warnings;

use Erreurs;
use Lib::NodeUtil;
use CS::CSNode;
use CS::CountNaming;

my $TotalAttributes_mnemo = Ident::Alias_TotalAttributes();
my $ShortAttributeNamesLT_mnemo = Ident::Alias_ShortAttributeNamesLT();
my $AttributeNameLengthAverage_mnemo = Ident::Alias_AttributeNameLengthAverage();
my $ShortClassNamesLT_mnemo = Ident::Alias_ShortClassNamesLT();
my $ClassNameLengthAverage_mnemo = Ident::Alias_ClassNameLengthAverage();
my $ClassImplementations_mnemo = Ident::Alias_ClassImplementations();
my $PrivateProtectedAttributes_mnemo = Ident::Alias_PrivateProtectedAttributes();
my $PublicAttributes_mnemo = Ident::Alias_PublicAttributes();
my $TopLevelClasses_mnemo = Ident::Alias_TopLevelClasses();
my $AbstractClassWithPublicConstructor_mnemo = Ident::Alias_AbstractClassWithPublicConstructor();
my $UnusedAttributes_mnemo = Ident::Alias_UnusedAttributes();
my $FieldShadow_mnemo = Ident::Alias_FieldShadow();
my $BadClassNames_mnemo = Ident::Alias_BadClassNames();
my $BadAttributeNames_mnemo = Ident::Alias_BadAttributeNames();
my $Properties_mnemo = Ident::Alias_Properties();

my $nb_TotalAttributes = 0;
my $nb_ShortAttributeNamesLT = 0;
my $nb_AttributeNameLengthAverage = 0;
my $nb_ShortClassNamesLT = 0;
my $nb_ClassNameLengthAverage = 0;
my $nb_ClassImplementations = 0;
my $nb_PrivateProtectedAttributes = 0;
my $nb_PublicAttributes = 0;
my $nb_TopLevelClasses = 0;
my $nb_AbstractClassWithPublicConstructor = 0;
my $nb_UnusedAttributes = 0;
my $nb_FieldShadow = 0;
my $nb_BadClassNames = 0;
my $nb_BadAttributeNames = 0;
my $nb_Properties = 0;

sub checkMethodUsage($$$) {
	my $method = shift;
	my $methods = shift;
	my $properties = shift;
	
	my $methodname = GetName($method);
	my $methodline = GetLine($method);
	
	# search in methods
	for my $meth (@$methods) {
		my $methodCodeBody = getCSKindData($meth, 'codeBody');
		
		next if (! defined $methodCodeBody);
		
		if (defined $methodCodeBody) {
			
			if ( $$methodCodeBody =~ /(?:(\w+)\.|(?:\A|[^\.]))\s*\b$methodname\s*\(/) {				
				if ((!defined $1) || ($1 eq "this")) {
					# the field is used
					return;
				}
			}
		}
	}
	
	# search in properties getter/setter
	for my $prop (@$properties) {
		
		my $codeBody = GetStatement($prop);
		
		if ( $$codeBody =~ /(?:(\w+)\.|(?:\A|[^\.]))\s*\b$methodname\s*\(/) {
			if ((!defined $1) || ($1 eq "this")) {
				# the field is used
				return;
			}
		}
	}
	
	#$nb_UnusedAttributes++;
	Erreurs::VIOLATION($UnusedAttributes_mnemo, "Unused method '$methodname' at line $methodline");
}

sub checkFieldUsage($$$$$) {
	my $field = shift;
	my $H_fields = shift;
	my $methods = shift;
	my $constructors = shift;
	my $properties = shift;
	
	my $fieldname = GetName($field);
	my $fieldline = GetLine($field);
	my $kind = GetKind($field);
	
	# search in methods
	for my $meth (@$methods, @$constructors) {
		my $methodCodeBody = getCSKindData($meth, 'codeBody');
		
		next if (! defined $methodCodeBody);
		
		my $H_args = getCSKindData($meth, 'H_args');
		my $H_vars = getCSKindData($meth, 'H_vars');
		if (defined $methodCodeBody) {
			
			# check field vs argument : 
			
			# name is argument or variable
			#  --> used only if précéded from 'this.' or '<class_name>.' ...
			#  --> else used if not preceded by '.'
			if ( (exists $H_args->{$fieldname}) || (exists $H_vars->{$fieldname}) ) {
				if ( $$methodCodeBody =~ /\bthis\.$fieldname\b/) {
					# the field is used.
					return;
				}
			}
			else{
				if ( $$methodCodeBody =~ /(?:(\w+)\.|(?:\A|[^\.]))\s*\b$fieldname\b/) {				
					if ((!defined $1) || ($1 eq "this")) {
						# the field is used
						return;
					}
				}
			}
		}
	}
	
	# search in properties getter/setter
	for my $prop (@$properties) {
		
		my $codeBody = GetStatement($prop);
		
		if ( $$codeBody =~ /(?:(\w+)\.|(?:\A|[^\.]))\s*\b$fieldname\b/) {
			if ((!defined $1) || ($1 eq "this")) {
				# the field is used
				return;
			}
		}
	}
	
	$nb_UnusedAttributes++;
	Erreurs::VIOLATION($UnusedAttributes_mnemo, "Unused field '$fieldname' at line $fieldline");
}

sub checkFieldOcculted($$) {
	my $H_fields = shift;
	my $methods = shift;
	
	for my $meth (@$methods) {
		my $H_args = getCSKindData($meth, 'H_args');
		
		for my $arg (keys %$H_args) {
			if (exists $H_fields->{$arg}) {
				$nb_FieldShadow++;
				Erreurs::VIOLATION($FieldShadow_mnemo, "Argument '$arg' is hidding field at line ".GetLine($meth));
			}
		}
		
		my $H_vars = getCSKindData($meth, 'H_vars');
		for my $var (keys %$H_vars) {
			if (exists $H_fields->{$var}) {
				$nb_FieldShadow++;
				Erreurs::VIOLATION($FieldShadow_mnemo, "Local variable '$var' is hidding field at line ".GetLine($H_vars->{$var}));
			}
		}
	}
}

sub CountClasses($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
	my $status = 0;
	
	$nb_TotalAttributes = 0;
	$nb_ShortAttributeNamesLT = 0;
	$nb_AttributeNameLengthAverage = 0;
	$nb_ShortClassNamesLT = 0;
	$nb_ClassNameLengthAverage = 0;
	$nb_ClassImplementations = 0;
	$nb_PrivateProtectedAttributes = 0;
	$nb_PublicAttributes = 0;
	$nb_AbstractClassWithPublicConstructor = 0;
	$nb_UnusedAttributes = 0;
	$nb_FieldShadow = 0;
	$nb_BadClassNames = 0;
	$nb_BadAttributeNames = 0;
	$nb_Properties = 0;
	
	my $KindsLists = $views->{'KindsLists'};

	if ( ! defined $KindsLists ) {
		$status |= Couples::counter_add($compteurs, $TotalAttributes_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $ShortAttributeNamesLT_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $AttributeNameLengthAverage_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $ShortClassNamesLT_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $ClassImplementations_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $PrivateProtectedAttributes_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $PublicAttributes_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $AbstractClassWithPublicConstructor_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $UnusedAttributes_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $FieldShadow_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $BadClassNames_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $BadAttributeNames_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $Properties_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my $classes = $KindsLists->{&ClassKind};
	
	$nb_ClassImplementations = scalar @$classes;
	
	for my $class (@$classes) {
		
		my $name = GetName($class);
		my $line = GetLine($class);
		
		if (! CS::CountNaming::checkClassName($name)) {
			$nb_BadClassNames++;
			Erreurs::VIOLATION($BadClassNames_mnemo, "Bad class name : $name at line $line");
		}
	
		my $classModifiers = getCSKindData($class, 'H_modifiers');
		
		my $statement = GetStatement($class);
		
		# chech name
		if (CS::CountNaming::checkClassNameLength($name)) {
				Erreurs::VIOLATION($ShortClassNamesLT_mnemo, "Too short class name : $name at line $line");
				$nb_ShortClassNamesLT++;
		}
		
		$nb_ClassNameLengthAverage += length($name);
		
		# build usefull lists
		my @attributes = ();
		my @properties = ();
		my @constructors = ();
		my @methods = ();
		my @static_AttrProp = ();
		my $UTIITY_FLAG = 1;
		my $DERIVED_FLAG = 0;
		my $nb_fields = 0;
		my %H_fields = ();
		my $children = GetChildren($class);
		for my $child (@$children) {
			my $kind = GetKind($child);
			my $fieldName = GetName($child);

			if (($kind eq AttributeKind) || ($kind eq PropertyKind)) {
				
				if ($kind eq AttributeKind) {
					push @attributes, $child;
				}
				else {
					push @properties, $child;
				}

				$H_fields{$fieldName} = 1;
				my $mods = getCSKindData($child, 'H_modifiers');
				if (exists $mods->{'static'}) {
					push @static_AttrProp, $child;
				}
				else {
					# Asume an utility class has all attributes & properties static
					$UTIITY_FLAG = 0;
				}
			}
			elsif (IsKind($child, MethodKind)) {
				push @methods, $child;
			}
			elsif (IsKind($child, ConstructorKind)) {
				push @constructors, $child;
			}
		}
		
		if ($$statement =~ /:/) {
			$DERIVED_FLAG = 1;
		}
		
		# assume NO DATA FIELDS => NOT AN UTLITY CLASS
		if ((scalar @attributes == 0) && (scalar @properties == 0)) {
			$UTIITY_FLAG = 0;
		}
		
		# check FIELDS (variable or properties)
		my @fields = (@attributes, @properties);
		$nb_fields = scalar @fields;
		$nb_TotalAttributes += $nb_fields;
		$nb_Properties +=  scalar @properties;
		for my $field (@fields) {
			
			my $fieldname = GetName($field);
			my $fieldline = GetLine($field);
			
			my $H_modifiers = getCSKindData($field, 'H_modifiers');
			
			
			$nb_AttributeNameLengthAverage += length($fieldname);
			
			if (CS::CountNaming::checkAttributeNameLength($fieldname)) {
				Erreurs::VIOLATION($ShortAttributeNamesLT_mnemo, "Too short attribute name : $fieldname at line $fieldline");
				$nb_ShortAttributeNamesLT++;
			}
			
			if (! CS::CountNaming::checkAttributeName($fieldname, (not exists $H_modifiers->{'public'}))) {
				$nb_BadAttributeNames++;
				Erreurs::VIOLATION($BadAttributeNames_mnemo, "Bad attribute name : $fieldname at line $fieldline");
			}
			
			# Only attributes (not properties)
			if (IsKind($field, AttributeKind)) {
				if ((defined $H_modifiers->{'private'}) || (defined $H_modifiers->{'protected'})) {
					#Erreurs::VIOLATION($PrivateProtectedAttributes_mnemo, "private or protected field : $fieldname at line $fieldline");
					$nb_PrivateProtectedAttributes++;
				}
				elsif (defined $H_modifiers->{'public'}) {
					Erreurs::VIOLATION($PublicAttributes_mnemo, "Public field : $fieldname at line $fieldline");
					$nb_PublicAttributes++;
				}
				else {
					Erreurs::VIOLATION($PrivateProtectedAttributes_mnemo, "default private attribute : $fieldname at line $fieldline");
					$nb_PrivateProtectedAttributes++;
				}
			}
			
			# check field usage
			if ( (! exists $H_modifiers->{'public'}) ) {
				if (($name !~ /Tests?$/m) && (scalar @methods > 0)){
					checkFieldUsage($field, \%H_fields, \@methods, \@constructors, \@properties);
				}
			}
		}
		
		# DESACTIVATED => too many litigious cases ...
		# check METHODS
		#for my $meth (@methods) {
		#	my $H_modifiers = getCSKindData($meth, 'H_modifiers');
		#	if ( (! exists $H_modifiers->{'public'}) && (! exists $H_modifiers->{'protected'})) {
		#		if ($name !~ /Tests?$/m) {
		#			checkMethodUsage($meth, \@methods, \@properties);
		#		}
		#	}
		#}
		
		my $PublicConstructors = 0;
		
		# check CONSTRUCTORS
		if (scalar @constructors == 0) {
			# case : NO CONSTRUCTOR ==> public default constructor
			if (exists $classModifiers->{'abstract'}) {
				# defaut constructors are always public
				$nb_AbstractClassWithPublicConstructor++;
				Erreurs::VIOLATION($AbstractClassWithPublicConstructor_mnemo, "Public default constructor for abstract class at line ".GetLine($class));
			}
			
			# default generated constructor is public
			$PublicConstructors =1;
		}
		else {
			my $PublicConstructors = 0;
			# case : CHECK CONSTRUCTOR
			for my $cons (@constructors) {
			
				# check PUBLIC constructorS
				# user constructor are private by default => check for explicit public modifier
				my $consModifiers = getCSKindData($cons, 'H_modifiers');
				if (exists $consModifiers->{'public'}) {
					
					$PublicConstructors++;
					
					# case of abstract classes
					if (exists $classModifiers->{'abstract'}) {	
						$nb_AbstractClassWithPublicConstructor++;
						Erreurs::VIOLATION($AbstractClassWithPublicConstructor_mnemo, "Public constructor in abstract class at line ".GetLine($cons));
					} 
				}
			
				#if (scalar @static_AttrProp) {
				#	my $constructorBody = getCSKindData($cons,'codeBody');
				#	if (defined $constructorBody) {
				#		for my $static (@static_AttrProp) {
				#			my $name = GetName($static);
				#			if ($$constructorBody =~ /([^\.]|\A)\b$name\b\s*=[^=]/) {
#print STDERR "[Id_YYY] STATIC FIELD initialized in constructor at line ".GetLine($cons)."\n";
				#			}
				#		}
				#	}
				#}
			}
			
			#if (($DERIVED_FLAG == 0) && ($UTIITY_FLAG) && ($PublicConstructors > 0) && (! exists $classModifiers->{'partial'}) && (! exists $classModifiers->{'static'})) { 
#print STDERR "Utility class should not have public constructor at line $line\n";
			#}
		}
		
		checkFieldOcculted(\%H_fields, \@methods);
	}

	if ($nb_TotalAttributes) {
		$nb_AttributeNameLengthAverage = int($nb_AttributeNameLengthAverage/$nb_TotalAttributes);
	}

	if ($nb_ClassImplementations) {
		$nb_ClassNameLengthAverage = int($nb_ClassNameLengthAverage/$nb_ClassImplementations);
	}

	$status |= Couples::counter_add($compteurs, $TotalAttributes_mnemo, $nb_TotalAttributes);
	$status |= Couples::counter_add($compteurs, $ShortAttributeNamesLT_mnemo, $nb_ShortAttributeNamesLT );
	$status |= Couples::counter_add($compteurs, $AttributeNameLengthAverage_mnemo, $nb_AttributeNameLengthAverage );
	$status |= Couples::counter_add($compteurs, $ShortClassNamesLT_mnemo, $nb_ShortClassNamesLT );
	$status |= Couples::counter_add($compteurs, $ClassNameLengthAverage_mnemo, $nb_ClassNameLengthAverage );
	$status |= Couples::counter_add($compteurs, $ClassImplementations_mnemo, $nb_ClassImplementations );
	$status |= Couples::counter_add($compteurs, $PrivateProtectedAttributes_mnemo, $nb_PrivateProtectedAttributes );
	$status |= Couples::counter_add($compteurs, $PublicAttributes_mnemo, $nb_PublicAttributes );
	$status |= Couples::counter_add($compteurs, $AbstractClassWithPublicConstructor_mnemo, $nb_AbstractClassWithPublicConstructor );
	$status |= Couples::counter_add($compteurs, $UnusedAttributes_mnemo, $nb_UnusedAttributes );
	$status |= Couples::counter_add($compteurs, $FieldShadow_mnemo, $nb_FieldShadow );
	$status |= Couples::counter_add($compteurs, $BadClassNames_mnemo, $nb_BadClassNames );
	$status |= Couples::counter_add($compteurs, $BadAttributeNames_mnemo, $nb_BadAttributeNames );
	$status |= Couples::counter_add($compteurs, $Properties_mnemo, $nb_Properties );
	
	return $status;
}

sub CountTopLevelClasses($$$$)
{
    my ($fichier, $views, $compteurs, $options) = @_;
    
	my $status = 0;
	
	$nb_TopLevelClasses = 0;

	my $root = $views->{'structured_code'};

	if ( ! defined $root ) {
		$status |= Couples::counter_add($compteurs, $TopLevelClasses_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
	
	my @classes = GetNodesByKindList_StopAtBlockingNode($root, [ClassKind], [ClassKind]);

	$nb_TopLevelClasses = scalar @classes;

	$status |= Couples::counter_add($compteurs, $TopLevelClasses_mnemo, $nb_TopLevelClasses );
	
	return $status;	
}

1;
