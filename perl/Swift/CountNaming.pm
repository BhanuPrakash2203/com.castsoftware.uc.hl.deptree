package Swift::CountNaming;
# les modules importes
use strict;
use warnings;

use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use Swift::SwiftNode;
use Swift::Identifiers;
use Swift::SwiftConfig;

my $DEBUG = 0;

my $BadClassNames__mnemo = Ident::Alias_BadClassNames();
my $BadAttributeNames__mnemo = Ident::Alias_BadAttributeNames();
my $BadEnumNames__mnemo = Ident::Alias_BadEnumNames();
my $BadProtocolNames__mnemo = Ident::Alias_BadProtocolNames();
my $BadConstantNames__mnemo = Ident::Alias_BadConstantNames();
my $FieldNameIsClassName__mnemo = Ident::Alias_FieldNameIsClassName();
my $BadParameterNames__mnemo = Ident::Alias_BadParameterNames();
my $ClassNameLengthAverage__mnemo = Ident::Alias_ClassNameLengthAverage();
my $RoutineNameLengthAverage__mnemo = Ident::Alias_RoutineNameLengthAverage();
my $AttributeNameLengthAverage__mnemo = Ident::Alias_AttributeNameLengthAverage();
my $ParameterNameLengthAverage__mnemo = Ident::Alias_ParameterNameLengthAverage();

my $nb_BadClassNames= 0;
my $nb_BadAttributeNames= 0;
my $nb_BadEnumNames= 0;
my $nb_BadProtocolNames= 0;
my $nb_BadConstantNames= 0;
my $nb_FieldNameIsClassName= 0;
my $nb_BadParameterNames= 0;
my $nb_ClassNameLengthAverage= 0;
my $nb_RoutineNameLengthAverage= 0;
my $nb_AttributeNameLengthAverage= 0;
my $nb_ParameterNameLengthAverage= 0;

sub CountNaming($$$)
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_BadClassNames = 0;
    $nb_BadAttributeNames = 0;
    $nb_BadEnumNames = 0;
    $nb_BadProtocolNames = 0;
    $nb_BadConstantNames = 0;
    $nb_FieldNameIsClassName = 0;
    $nb_BadParameterNames = 0;
    $nb_ClassNameLengthAverage = 0;
    $nb_RoutineNameLengthAverage = 0;
    $nb_AttributeNameLengthAverage = 0;
    $nb_ParameterNameLengthAverage = 0;

    my $root =  \$vue->{'code'} ;

    if ( ( ! defined $root ) )
    {
        $ret |= Couples::counter_add($compteurs, $BadClassNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $BadAttributeNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $BadEnumNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $BadProtocolNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $BadConstantNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $FieldNameIsClassName__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $BadParameterNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $ClassNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $RoutineNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $AttributeNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $ParameterNameLengthAverage__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @classes = @{$vue->{'KindsLists'}->{'ClassDeclaration'}};
    my @structs = @{$vue->{'KindsLists'}->{'StructDeclaration'}};
    my @classOrStruct = (@classes, @structs);
    my @enums = @{$vue->{'KindsLists'}->{'Enum'}};
    my @protocols = @{$vue->{'KindsLists'}->{'Protocol'}};
    my @enumOrProtocol = (@enums, @protocols);
    my @constants = @{$vue->{'KindsLists'}->{'Constant'}};
    my @functionsDecl = @{$vue->{'KindsLists'}->{'FunctionDeclaration'}};
    my @varDecl = @{$vue->{'KindsLists'}->{'VarDecl'}};
    my @methods = @{$vue->{'KindsLists'}->{'Method'}};

    my $cumulated_name_size = 0;
    my $nb_namedClasses = 0;

	my $SumSizeParamNames = 0;
	my $nbParam = 0;

    for my $classOrStruct (@classOrStruct) {
        my $nameClassOrStruct = GetName ($classOrStruct);
		
		if (defined $nameClassOrStruct) {
			$nb_namedClasses++;
			$cumulated_name_size += length($nameClassOrStruct);
		}

        # HL-1106 Class or struct names should comply with a naming convention
        if ($nameClassOrStruct !~ /^[A-Z][a-zA-Z0-9]*$/m) {
            # print "Class or struct names '$name' should comply with a naming convention at line " . GetLine($classOrStruct) ."\n";
            $nb_BadClassNames++;
            Erreurs::VIOLATION($BadClassNames__mnemo, "Class or struct names should comply with a naming convention at line " . GetLine($classOrStruct) .".");
        }

        my @variables = GetChildrenByKind ($classOrStruct, VarKind);
        for my $var (@variables) {
            my @varDecl = GetChildrenByKind ($var, VarDeclKind);
            for my $varDecl (@varDecl) {
                my $nameVarDecl = GetName ($varDecl);
                # HL-1108 Field names should comply with a naming convention
                if ( $nameVarDecl !~ /^[a-z][a-zA-Z0-9]*$/m ) {
                    # print "Field names should comply with a naming convention at line " . GetLine($varDecl). "\n";
                    $nb_BadAttributeNames++;
                    Erreurs::VIOLATION($BadAttributeNames__mnemo, "Field names should comply with a naming convention at line " . GetLine($varDecl) .".");
                }

                # HL-1113 A field should not duplicate the name of its containing class or struct
                if (lc($nameClassOrStruct) eq lc($nameVarDecl)) {
                    # print "A field should not duplicate the name of its containing class or struct at line " . GetLine($varDecl). "\n";
                    $nb_FieldNameIsClassName++;
                    Erreurs::VIOLATION($FieldNameIsClassName__mnemo, "A field should not duplicate the name of its containing class or struct at line " . GetLine($varDecl) .".");
                }
            }
        }
        # HL-1109 Generic type parameter names should comply with a naming convention
        my $genericParams = Lib::NodeUtil::GetXKindData($classOrStruct, 'generic_param');

        for my $genericParam (@{$genericParams}) {
            my $typeGenericParam = GetKind ($genericParam);
            if ($typeGenericParam !~ /^\s*(?:(?i)key|(?i)value|[A-Z][0-9]?)\s*$/m) {
                # print "Generic type parameter name \"$typeGenericParam\" should comply with a naming convention at line ". GetLine($classOrStruct) ."\n";
                $nb_BadParameterNames++;
                Erreurs::VIOLATION($BadParameterNames__mnemo, "Generic type parameter name \"$typeGenericParam\" should comply with a naming convention at line " . GetLine($classOrStruct) .".");
            }
        }

		my $params = Lib::NodeUtil::GetXKindData($classOrStruct, 'parameters');

        for my $param (@{$params}) {
            my $nameParam = GetName ($param);
			if (defined $nameParam) {
				$SumSizeParamNames += length $nameParam;
				$nbParam++;
			}
        }

		if ($nbParam) {
			$nb_ParameterNameLengthAverage =  int ($SumSizeParamNames / $nbParam);
		}

    }

	if ($nb_namedClasses) {
		$nb_ClassNameLengthAverage = int ($cumulated_name_size / $nb_namedClasses);
	}

	my $SumSizeMethodsNames = 0;
	my $nbRoutine = 0;

    for my $functionDecl (@functionsDecl) {

		my $nameFunc = GetName($functionDecl);

		if (defined $nameFunc) {
		  $SumSizeMethodsNames += length $nameFunc;
		  $nbRoutine++;
		}

        # HL-1109 Generic type parameter names should comply with a naming convention
        my $genericParams = Lib::NodeUtil::GetXKindData($functionDecl, 'generic_param');

        for my $genericParam (@{$genericParams}) {
            my $typeGenericParam = GetKind ($genericParam);
            if ($typeGenericParam !~ /^\s*(?:(?i)key|(?i)value|[A-Z][0-9]?)\s*$/m) {
                # print "Generic type parameter name \"$typeGenericParam\" should comply with a naming convention at line ". GetLine($functionDecl) ."\n";
                $nb_BadParameterNames++;
                Erreurs::VIOLATION($BadParameterNames__mnemo, "Generic type parameter name \"$typeGenericParam\" should comply with a naming convention at line " . GetLine($functionDecl) .".");
            }
        }

		my $params = Lib::NodeUtil::GetXKindData($functionDecl, 'parameters');

        for my $param (@{$params}) {
            my $nameParam = GetName ($param);
			if (defined $nameParam) {
				$SumSizeParamNames += length $nameParam;
				$nbParam++;
			}
        }

		if ($nbParam) {
			$nb_ParameterNameLengthAverage =  int ($SumSizeParamNames / $nbParam);
		}

    }

	for my $method (@methods) {
		my $nameMethod = GetName($method);

		if (defined $nameMethod) {
		  $SumSizeMethodsNames += length $nameMethod;
		  $nbRoutine++;
		}

        # HL-1109 Generic type parameter names should comply with a naming convention
        my $genericParams = Lib::NodeUtil::GetXKindData($method, 'generic_param');

        for my $genericParam (@{$genericParams}) {
            my $typeGenericParam = GetKind ($genericParam);
            if ($typeGenericParam !~ /^\s*(?:(?i)key|(?i)value|[A-Z][0-9]?)\s*$/m) {
                # print "Generic type parameter name \"$typeGenericParam\" should comply with a naming convention at line ". GetLine($functionDecl) ."\n";
                $nb_BadParameterNames++;
                Erreurs::VIOLATION($BadParameterNames__mnemo, "Generic type parameter name \"$typeGenericParam\" should comply with a naming convention at line " . GetLine($method) .".");
            }
        }
	}

	if ($nbRoutine) {
		$nb_RoutineNameLengthAverage =  int ($SumSizeMethodsNames / $nbRoutine);
	}

    for my $enumOrProtocol (@enumOrProtocol) {
        my $name = GetName ($enumOrProtocol);
        # HL-1111 Enumeration types & Protocol should comply with a naming convention
        if (defined $name && $name !~ /^[A-Z][a-zA-Z0-9]*$/m) {

            if (IsKind($enumOrProtocol, EnumKind)) {
                # print "Enumeration types should comply with a naming convention at line " . GetLine($enumOrProtocol) . "\n";
                $nb_BadEnumNames++;
                Erreurs::VIOLATION($BadEnumNames__mnemo, "Enumeration types should comply with a naming convention at line " . GetLine($enumOrProtocol) . ".");
            }
            elsif (IsKind($enumOrProtocol, ProtocolKind)) {
                # print "Protocol types should comply with a naming convention at line " . GetLine($enumOrProtocol) . "\n";
                $nb_BadProtocolNames++;
                Erreurs::VIOLATION($BadProtocolNames__mnemo, "Protocol types should comply with a naming convention at line " . GetLine($enumOrProtocol) . ".");
            }
        }
    }

    for my $constant (@constants) {
        # HL-1112 Constant names should comply with a naming convention
        my $varDecl = GetChildren($constant);
        my $name = GetName($varDecl->[0]);
        if (defined $name && $name !~ /^[a-z][a-zA-Z0-9]*$/m) {
            # print "Constant names should comply with a naming convention at line " . GetLine($constant) . "\n";
            $nb_BadConstantNames++;
            Erreurs::VIOLATION($BadConstantNames__mnemo, "Constant names should comply with a naming convention at line " . GetLine($constant) . ".");
        }
    }

	my $SumSizeVarNames = 0;
	my $nbVarDecl = 0;

    for my $varDecl (@varDecl) {
        my $nameVarDecl = GetName ($varDecl);

		if (defined $nameVarDecl) {
		  $SumSizeVarNames += length $nameVarDecl;
		  $nbVarDecl++;
		}
	}

	if ($nbVarDecl) {
		$nb_AttributeNameLengthAverage =  int ($SumSizeVarNames / $nbVarDecl);
	}

    $ret |= Couples::counter_add($compteurs, $BadClassNames__mnemo, $nb_BadClassNames );
    $ret |= Couples::counter_add($compteurs, $BadAttributeNames__mnemo, $nb_BadAttributeNames );
    $ret |= Couples::counter_add($compteurs, $BadEnumNames__mnemo, $nb_BadEnumNames );
    $ret |= Couples::counter_add($compteurs, $BadProtocolNames__mnemo, $nb_BadProtocolNames );
    $ret |= Couples::counter_add($compteurs, $BadConstantNames__mnemo, $nb_BadConstantNames );
    $ret |= Couples::counter_add($compteurs, $FieldNameIsClassName__mnemo, $nb_FieldNameIsClassName );
    $ret |= Couples::counter_add($compteurs, $BadParameterNames__mnemo, $nb_BadParameterNames );
    $ret |= Couples::counter_add($compteurs, $ClassNameLengthAverage__mnemo, $nb_ClassNameLengthAverage );
    $ret |= Couples::counter_add($compteurs, $RoutineNameLengthAverage__mnemo, $nb_RoutineNameLengthAverage );
    $ret |= Couples::counter_add($compteurs, $AttributeNameLengthAverage__mnemo, $nb_AttributeNameLengthAverage );
    $ret |= Couples::counter_add($compteurs, $ParameterNameLengthAverage__mnemo, $nb_ParameterNameLengthAverage );

    return $ret;
}



1;
