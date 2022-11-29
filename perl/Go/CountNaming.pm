package Go::CountNaming;
# les modules importes
use strict;
use warnings;

use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use Go::GoNode;
use Go::GoConfig;

my $DEBUG = 0;

my $BadVariableNames__mnemo = Ident::Alias_BadVariableNames();
my $BadFunctionNames__mnemo = Ident::Alias_BadFunctionNames();
my $BadMethodNames__mnemo = Ident::Alias_BadMethodNames();
my $BadParameterNames__mnemo = Ident::Alias_BadParameterNames();
my $ShortVarName__mnemo = Ident::Alias_ShortVarName();
my $ShortFunctionNamesLT__mnemo = Ident::Alias_ShortFunctionNamesLT();
my $ShortParameterNamesLT__mnemo = Ident::Alias_ShortParameterNamesLT();
my $VariableNameLengthAverage__mnemo = Ident::Alias_VariableNameLengthAverage();
my $FunctionNameLengthAverage__mnemo = Ident::Alias_FunctionNameLengthAverage();
my $ParameterNameLengthAverage__mnemo = Ident::Alias_ParameterNameLengthAverage();

my $nb_BadVariableNames = 0;
my $nb_BadFunctionNames = 0;
my $nb_BadMethodNames = 0;
my $nb_BadParameterNames = 0;
my $nb_ShortVarName = 0;
my $nb_ShortFunctionNamesLT = 0;
my $nb_ShortParameterNamesLT = 0;
my $nb_VariableNameLengthAverage= 0;
my $nb_FunctionNameLengthAverage= 0;
my $nb_ParameterNameLengthAverage= 0;

sub CountNaming($$$)
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_BadVariableNames = 0;
    $nb_BadFunctionNames = 0;
    $nb_BadMethodNames = 0;
    $nb_BadParameterNames = 0;
    $nb_ShortVarName = 0;
    $nb_ShortFunctionNamesLT = 0;
    $nb_ShortParameterNamesLT = 0;
    $nb_VariableNameLengthAverage = 0;
    $nb_FunctionNameLengthAverage = 0;
    $nb_ParameterNameLengthAverage = 0;

    my $root =  \$vue->{'code'} ;

    if ( ! defined $root )
    {
        $ret |= Couples::counter_add($compteurs, $BadVariableNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $BadFunctionNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $BadMethodNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $BadParameterNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $ShortVarName__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $ShortFunctionNamesLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $ShortParameterNamesLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $VariableNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $FunctionNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $ParameterNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    # HL 1601 22/01/2021 Local variable and function/method parameter and function/method names should comply with a naming convention
    my @vars = @{$vue->{'KindsLists'}->{&VarKind}};
    my @funcs = @{$vue->{'KindsLists'}->{&FunctionDeclarationKind}};
    my @methods = @{$vue->{'KindsLists'}->{&MethodKind}};

    my $kindElements = [@vars, @funcs, @methods];

    my $totalVar;
    my $totalFunc;
    my $totalParam;
    my $sumLenghtVarName;
    my $sumLenghtFuncName;
    my $sumLenghtParamName;

    for my $elementNaming (@{$kindElements}) {
        my $nameEltNaming = GetName($elementNaming);
        my $kind = GetKind($elementNaming);
        my $regexNaming = qr/\_|[0-9]+/;

        # vars + funcs + methods
        if (defined $nameEltNaming) {
            $nameEltNaming =~ s/\s+//g;
            if ($nameEltNaming =~ /$regexNaming/) {
                if (IsKind($elementNaming, VarKind) && $nameEltNaming ne '_') {
                    # print "Local variable <$nameEltNaming> should comply with a naming convention at line " . GetLine($elementNaming) . "\n";
                    $nb_BadVariableNames++;
                    Erreurs::VIOLATION($BadVariableNames__mnemo, "Local variable <$nameEltNaming> should comply with a naming convention at line " . GetLine($elementNaming));
                }
                elsif (IsKind($elementNaming, FunctionDeclarationKind)) {
                    # print "Function <$nameEltNaming> should comply with a naming convention at line " . GetLine($elementNaming) . "\n";
                    $nb_BadFunctionNames++;
                    Erreurs::VIOLATION($BadFunctionNames__mnemo, "Function <$nameEltNaming> should comply with a naming convention at line " . GetLine($elementNaming));
                }
                elsif (IsKind($elementNaming, MethodKind)) {
                    # print "Method <$nameEltNaming> should comply with a naming convention at line " . GetLine($elementNaming) . "\n";
                    $nb_BadMethodNames++;
                    Erreurs::VIOLATION($BadFunctionNames__mnemo, "Method <$nameEltNaming> should comply with a naming convention at line " . GetLine($elementNaming));
                }
            }
            # HL-1670 04/03/2021 Avoid short identifiers names
            if (IsKind($elementNaming, VarKind) && !IsKind(GetParent($elementNaming), ConstantKind)
                && $nameEltNaming ne '_') {
                my $lenghtVarName = length($nameEltNaming);
                if ($lenghtVarName < Go::GoConfig::MIN_VAR_NAME_LENTGH) {
                    # print "Avoid short identifiers names for variable <$nameEltNaming> at line " . GetLine($elementNaming) . "\n";
                    $nb_ShortVarName++;
                    Erreurs::VIOLATION($ShortVarName__mnemo, "Avoid short identifiers names for variable <$nameEltNaming> at line " . GetLine($elementNaming));
                }
                $sumLenghtVarName += $lenghtVarName;
                $totalVar++;
            }
            elsif (IsKind($elementNaming, FunctionDeclarationKind) && $nameEltNaming ne '_') {
                my $lenghtFuncName = length($nameEltNaming);
                if ($lenghtFuncName < Go::GoConfig::MIN_FUNCTION_NAME_LENTGH) {
                    # print "Avoid short identifiers names for function <$nameEltNaming> at line " . GetLine($elementNaming) . "\n";
                    $nb_ShortFunctionNamesLT++;
                    Erreurs::VIOLATION($ShortFunctionNamesLT__mnemo, "Avoid short identifiers names for function <$nameEltNaming> at line " . GetLine($elementNaming));
                }
                $sumLenghtFuncName += $lenghtFuncName;
                $totalFunc++;
            }
        }

        # function or method parameters (not covering receiver names)
        my $params;
        if (IsKind($elementNaming, FunctionDeclarationKind)) {
            my @methodEmbedded = GetChildrenByKind($elementNaming, MethodKind);
            if (!@methodEmbedded) {
                $params = Lib::NodeUtil::GetXKindData($elementNaming, 'parameters');
            }
        }
        elsif (IsKind($elementNaming, MethodKind)) {
            $params = Lib::NodeUtil::GetXKindData($elementNaming, 'parameters');
        }

        if (defined $params) {
            foreach my $param (@{$params}) {
                my $paramName = GetName($param);
                $paramName =~ s/\s+//g;
                if (defined $paramName && $paramName ne '_') {
                    if ($paramName =~ /$regexNaming/) {
                        # print "Function/method parameter <$paramName> should comply with a naming convention at line " . GetLine($elementNaming) . "\n";
                        $nb_BadParameterNames++;
                        Erreurs::VIOLATION($BadParameterNames__mnemo, "Function/method parameter <$paramName> should comply with a naming convention at line " . GetLine($elementNaming));
                    }
                    my $lenghtParamName = length($paramName);
                    if ($lenghtParamName < Go::GoConfig::MIN_PARAMETERS_NAME_LENTGH) {
                        # print "Avoid short identifiers names for parameter <$paramName> at line " . GetLine($elementNaming) . "\n";
                        $nb_ShortParameterNamesLT++;
                        Erreurs::VIOLATION($ShortParameterNamesLT__mnemo, "Avoid short identifiers names for parameter <$paramName> at line " . GetLine($elementNaming));
                    }
                    $sumLenghtParamName += $lenghtParamName;
                    $totalParam++;
                }
            }
        }
    }

    # Computing averages
    $nb_VariableNameLengthAverage = int ($sumLenghtVarName / $totalVar) if defined $totalVar && $totalVar != 0;
    $nb_FunctionNameLengthAverage = int($sumLenghtFuncName / $totalFunc) if defined $totalFunc && $totalFunc != 0;
    $nb_ParameterNameLengthAverage = int($sumLenghtParamName / $totalParam) if defined $totalParam && $totalParam != 0;

    $ret |= Couples::counter_add($compteurs, $BadVariableNames__mnemo, $nb_BadVariableNames );
    $ret |= Couples::counter_add($compteurs, $BadFunctionNames__mnemo, $nb_BadFunctionNames );
    $ret |= Couples::counter_add($compteurs, $BadMethodNames__mnemo, $nb_BadMethodNames );
    $ret |= Couples::counter_add($compteurs, $BadParameterNames__mnemo, $nb_BadParameterNames );
    $ret |= Couples::counter_add($compteurs, $ShortVarName__mnemo, $nb_ShortVarName );
    $ret |= Couples::counter_add($compteurs, $ShortFunctionNamesLT__mnemo, $nb_ShortFunctionNamesLT );
    $ret |= Couples::counter_add($compteurs, $ShortParameterNamesLT__mnemo, $nb_ShortParameterNamesLT );
    $ret |= Couples::counter_add($compteurs, $VariableNameLengthAverage__mnemo, $nb_VariableNameLengthAverage );
    $ret |= Couples::counter_add($compteurs, $FunctionNameLengthAverage__mnemo, $nb_FunctionNameLengthAverage );
    $ret |= Couples::counter_add($compteurs, $ParameterNameLengthAverage__mnemo, $nb_ParameterNameLengthAverage );

    return $ret;
}



1;
