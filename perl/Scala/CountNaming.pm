package Scala::CountNaming;
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

my $BadClassNames__mnemo = Ident::Alias_BadClassNames();
my $BadMethodNames__mnemo = Ident::Alias_BadMethodNames();
my $BadAttributeNames__mnemo = Ident::Alias_BadAttributeNames();
my $ShortClassNamesLT__mnemo = Ident::Alias_ShortClassNamesLT();
my $ShortMethodNamesLT__mnemo = Ident::Alias_ShortMethodNamesLT();
my $ShortAttributeNamesLT__mnemo = Ident::Alias_ShortAttributeNamesLT();
my $ShortParameterNamesLT__mnemo = Ident::Alias_ShortParameterNamesLT();
my $ClassNameLengthAverage__mnemo = Ident::Alias_ClassNameLengthAverage();
my $MethodNameLengthAverage__mnemo = Ident::Alias_MethodNameLengthAverage();
my $AttributeNameLengthAverage__mnemo = Ident::Alias_AttributeNameLengthAverage();
my $ParameterNameLengthAverage__mnemo = Ident::Alias_ParameterNameLengthAverage();

my $nb_BadClassNames = 0;
my $nb_BadMethodNames = 0;
my $nb_BadAttributeNames = 0;
my $nb_ShortClassNamesLT = 0;
my $nb_ShortMethodNamesLT = 0;
my $nb_ShortAttributeNamesLT = 0;
my $nb_ShortParameterNamesLT = 0;
my $nb_ClassNameLengthAverage = 0;
my $nb_MethodNameLengthAverage = 0;
my $nb_AttributeNameLengthAverage = 0;
my $nb_ParameterNameLengthAverage = 0;

sub CountNaming($$$) {
    my ($file, $vue, $compteurs) = @_;

    my $ret = 0;
    $nb_BadClassNames = 0;
    $nb_BadMethodNames = 0;
    $nb_BadAttributeNames = 0;
    $nb_ShortClassNamesLT = 0;
    $nb_ShortMethodNamesLT = 0;
    $nb_ShortAttributeNamesLT = 0;
    $nb_ShortParameterNamesLT = 0;
    $nb_ClassNameLengthAverage = 0;
    $nb_MethodNameLengthAverage = 0;
    $nb_AttributeNameLengthAverage = 0;
    $nb_ParameterNameLengthAverage = 0;

    my $root = \$vue->{'code'};

    if (!defined $root) {
        $ret |= Couples::counter_add($compteurs, $BadClassNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $BadMethodNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $BadAttributeNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $ShortClassNamesLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $ShortMethodNamesLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $ShortAttributeNamesLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $ShortParameterNamesLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $ClassNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $MethodNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $AttributeNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        $ret |= Couples::counter_add($compteurs, $ParameterNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE);
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    # HL-1977 22/03/2022 Class / objects names should comply with a naming convention
    # HL-1978 22/03/2022 Method names should comply with a naming convention
    # HL-2010 08/04/2022 Attributes names should comply with a naming convention
    my @classes = @{$vue->{'KindsLists'}->{&ClassKind}};
    my @objects = @{$vue->{'KindsLists'}->{&ObjectKind}};
    my @methods = @{$vue->{'KindsLists'}->{&MethodKind}};
    my @functions = @{$vue->{'KindsLists'}->{&FunctionDeclarationKind}};

    my $cumulClassNameSize = 0;
    my $totalNamedClasses = 0;
    my $cumulMethodNameSize = 0;
    my $totalNamedMethods = 0;
    my $cumulAttributeNameSize = 0;
    my $totalNamedAttributes = 0;
    my $cumulParameterNameSize = 0;
    my $totalNamedParameters = 0;

    my $kindElements = [ @classes, @objects, @methods, @functions ];

    for my $elementNaming (@{$kindElements}) {
        my $nameEltNaming = GetName($elementNaming);
        my $kind = GetKind($elementNaming);
        my $regexNaming;
        if (IsKind($elementNaming, ClassKind) || IsKind($elementNaming, ObjectKind)) {
            if (defined $nameEltNaming) {
                $regexNaming = qr/^[a-z0-9]+/m;
                $nameEltNaming =~ s/\s+//g;
                $cumulClassNameSize += length($nameEltNaming);
                $totalNamedClasses++;
                if ($nameEltNaming =~ /$regexNaming/) {
                    # print "Class/object <$nameEltNaming> should comply with a naming convention at line " . GetLine($elementNaming) . "\n";
                    $nb_BadClassNames++;
                    Erreurs::VIOLATION($BadClassNames__mnemo, "Class/object '$nameEltNaming' should comply with a naming convention at line " . GetLine($elementNaming));
                }
                # HL-2012 11/04/2022 Avoid short class/object, method, attribute and parameter names
                if (length($nameEltNaming) < Scala::ScalaConfig::LIMIT_SHORT_CLASS_NAMES_LT) {
                    # print "Class name $nameEltNaming is too short at line ". GetLine($elementNaming) ."\n";
                    Erreurs::VIOLATION($ShortClassNamesLT__mnemo, "Class name $nameEltNaming is too short at line " . GetLine($elementNaming));
                    $nb_ShortClassNamesLT++;
                }
                # HL-2010 11/04/2022 Attributes names should comply with a naming convention
                $regexNaming = qr/^[A-Z0-9]+/m;
                my @attributes = GetChildrenByKind($elementNaming, VarKind);
                for my $attribute (@attributes) {
                    my $nameAttibuteNaming = GetName($attribute);
                    if (defined $nameAttibuteNaming) {
                        $nameAttibuteNaming =~ s/\s+//g;
                        $cumulAttributeNameSize += length($nameAttibuteNaming);
                        $totalNamedAttributes++;
                        if ($nameAttibuteNaming =~ /$regexNaming/) {
                            # print "Class/object <$nameEltNaming> should comply with a naming convention at line " . GetLine($attribute) . "\n";
                            $nb_BadAttributeNames++;
                            Erreurs::VIOLATION($BadClassNames__mnemo, "Class/object '$nameAttibuteNaming' should comply with a naming convention at line " . GetLine($attribute));
                        }
                        # HL-2012 11/04/2022 Avoid short class/object, method, attribute and parameter names
                        if (length($nameAttibuteNaming) < Scala::ScalaConfig::LIMIT_SHORT_ATTRIBUTE_NAMES_LT) {
                            # print "Attribute name $nameEltNaming is too short at line ". GetLine($attribute) ."\n";
                            Erreurs::VIOLATION($ShortAttributeNamesLT__mnemo, "Attribute name $nameAttibuteNaming is too short at line " . GetLine($attribute));
                            $nb_ShortAttributeNamesLT++;
                        }
                    }
                }
            }
        }
        ## METHODS
        elsif (IsKind($elementNaming, MethodKind)) {
            if (defined $nameEltNaming) {
                $regexNaming = qr/^[A-Z0-9]+/m;
                $nameEltNaming =~ s/\s+//g;
                $cumulMethodNameSize += length($nameEltNaming);
                $totalNamedMethods++;
                if ($nameEltNaming =~ /$regexNaming/) {
                    # print "Method <$nameEltNaming> should comply with a naming convention at line " . GetLine($elementNaming) . "\n";
                    $nb_BadMethodNames++;
                    Erreurs::VIOLATION($BadMethodNames__mnemo, "Method <$nameEltNaming> should comply with a naming convention at line " . GetLine($elementNaming));
                }
                # HL-2012 11/04/2022 Avoid short class/object, method, attribute and parameter names
                if (length($nameEltNaming) < Scala::ScalaConfig::LIMIT_SHORT_METHOD_NAMES_LT) {
                    # print "Method name $nameEltNaming is too short at line ". GetLine($elementNaming) ."\n";
                    Erreurs::VIOLATION($ShortClassNamesLT__mnemo, "Method name $nameEltNaming is too short at line " . GetLine($elementNaming));
                    $nb_ShortMethodNamesLT++;
                }
            }
        }
        ## FUNCTIONS
        elsif (IsKind($elementNaming, FunctionDeclarationKind)) {
            # HL-2012 11/04/2022 Avoid short class/object, method, attribute and parameter names
            my @parameters = GetChildrenByKind($elementNaming, ParamKind);
            for my $param (@parameters) {
                my $paramName = GetName($param);
                if (defined $paramName) {
                    $paramName =~ s/\s+//g;
                    $cumulParameterNameSize += length($paramName);
                    $totalNamedParameters++;
                    if (defined $paramName) {
                        if (length($paramName) < Scala::ScalaConfig::LIMIT_SHORT_PARAMETER_NAMES_LT) {
                            # print "Parameter name $paramName is too short at line ". GetLine($elementNaming) ."\n";
                            Erreurs::VIOLATION($ShortParameterNamesLT__mnemo, "Parameter name $paramName is too short at line " . GetLine($elementNaming));
                            $nb_ShortParameterNamesLT++;
                        }
                    }
                }
            }
        }
    }

    # computing averages
    if ($totalNamedClasses > 0) {
        $nb_ClassNameLengthAverage = int($cumulClassNameSize / $totalNamedClasses);
    }
    if ($totalNamedMethods > 0) {
        $nb_MethodNameLengthAverage = int($cumulMethodNameSize / $totalNamedMethods);
    }
    if ($totalNamedAttributes > 0) {
        $nb_AttributeNameLengthAverage = int($cumulAttributeNameSize / $totalNamedAttributes);
    }
    if ($totalNamedParameters > 0) {
        $nb_ParameterNameLengthAverage = int($cumulParameterNameSize / $totalNamedParameters);
    }

    $ret |= Couples::counter_add($compteurs, $BadClassNames__mnemo, $nb_BadClassNames);
    $ret |= Couples::counter_add($compteurs, $BadMethodNames__mnemo, $nb_BadMethodNames);
    $ret |= Couples::counter_add($compteurs, $BadAttributeNames__mnemo, $nb_BadAttributeNames);
    $ret |= Couples::counter_add($compteurs, $ShortClassNamesLT__mnemo, $nb_ShortClassNamesLT);
    $ret |= Couples::counter_add($compteurs, $ShortMethodNamesLT__mnemo, $nb_ShortMethodNamesLT);
    $ret |= Couples::counter_add($compteurs, $ShortAttributeNamesLT__mnemo, $nb_ShortAttributeNamesLT);
    $ret |= Couples::counter_add($compteurs, $ShortParameterNamesLT__mnemo, $nb_ShortParameterNamesLT);
    $ret |= Couples::counter_add($compteurs, $ClassNameLengthAverage__mnemo, $nb_ClassNameLengthAverage);
    $ret |= Couples::counter_add($compteurs, $MethodNameLengthAverage__mnemo, $nb_MethodNameLengthAverage);
    $ret |= Couples::counter_add($compteurs, $AttributeNameLengthAverage__mnemo, $nb_AttributeNameLengthAverage);
    $ret |= Couples::counter_add($compteurs, $ParameterNameLengthAverage__mnemo, $nb_ParameterNameLengthAverage);

    return $ret;
}



1;
