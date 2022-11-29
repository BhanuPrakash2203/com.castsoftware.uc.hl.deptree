package Go::CountVariable;
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

my $SelfAssigned__mnemo = Ident::Alias_SelfAssigned();
my $GlobalVariables__mnemo = Ident::Alias_GlobalVariables();
my $MissingShortVariableDeclaration__mnemo = Ident::Alias_MissingShortVariableDeclaration();
my $UnnamedData__mnemo = Ident::Alias_UnnamedData();
my $VariableDeclarations__mnemo = Ident::Alias_VariableDeclarations();

my $nb_SelfAssigned= 0;
my $nb_GlobalVariables= 0;
my $nb_MissingShortVariableDeclaration= 0;
my $nb_UnnamedData= 0;
my $nb_VariableDeclarations= 0;

sub CountVariable($$$)
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_SelfAssigned = 0;
    $nb_GlobalVariables = 0;
    $nb_MissingShortVariableDeclaration = 0;
    $nb_UnnamedData = 0;
    $nb_VariableDeclarations = 0;

    my $root =  \$vue->{'code'} ;

    if ( ! defined $root )
    {
        $ret |= Couples::counter_add($compteurs, $SelfAssigned__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $GlobalVariables__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $MissingShortVariableDeclaration__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $UnnamedData__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $VariableDeclarations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my @VarStatements = @{$vue->{'KindsLists'}->{&VarKind}};

    # HL 1595 20/01/2021 Variables should not be self-assigned
    my $numLine = 1;
    while ($$root =~ /(\n)|([\w\.]+)\s*(?:[\w\[\]]+)?(?:\s*\:?\=\s*)(.*?)\s*$/mg) {
        my $nameVar = $2;
        my $valueVar = $3;

        if (defined $1 && $1 eq "\n") {
            $numLine++;
        }
        
        if (defined $nameVar && defined $valueVar && $nameVar eq $valueVar ) {
            # print "Variables <$nameVar> should not be self-assigned at line $numLine\n";
            $nb_SelfAssigned++;
            Erreurs::VIOLATION($SelfAssigned__mnemo, "Variables should not be self-assigned at line $numLine");
        }
    }

    # HL-1631 05/02/2021 Avoid global variables
    for my $var (@VarStatements) {
        ############
        # GLOBAL VAR
        ############
        if (IsKind(GetParent($var), RootKind)) {
            my $typeVar = Lib::NodeUtil::GetXKindData($var, 'type') || "";
            if (defined $typeVar
                && $typeVar =~ /\b(?:bool|string|int[0-9]*|uint(?:[0-9]+|ptr)?|float[0-9]*|complex[0-9]+|byte|rune)\b/) {
                # print "Avoid global variables at line ".GetLine($var)."\n";
                $nb_GlobalVariables++;
                Erreurs::VIOLATION($GlobalVariables__mnemo, "Avoid global variables at line " . GetLine($var));
            }
            elsif ($typeVar eq '') {
                my $varStatement = GetStatement($var);
                if (defined $varStatement) {
                    $varStatement =~ s/\s+//g;
                    if ($varStatement =~ /^(?:CHAINE\_[0-9]+|[\d\.]+)$/m) {
                        # print "Avoid global variables at line ".GetLine($var)."\n";
                        $nb_GlobalVariables++;
                        Erreurs::VIOLATION($GlobalVariables__mnemo, "Avoid global variables at line " . GetLine($var));
                    }
                }
            }
        }
        ############
        # LOCAL VAR
        ############
        else {
            # HL-1630 05/02/2021 Use short variable declarations (:=) for variables with default values
            # Except for constant nodes
            if (!IsKind(GetParent($var), ConstantKind)) {
                my @initNodes = GetNodesByKindList($var, [ InitKind ], 1); # flag 1 signifies we want only the first loop encountered on each path
                if ($initNodes[0]) {
                    my $varName = GetName($var);
                    my $varStatement = GetStatement($initNodes[0]);
                    if (defined $varStatement) {
                        $varStatement =~ s/\s+//g;
                        if (defined $varName && $varStatement eq '=') {
                            # print "Use short variable declaration (:=) for variable '$varName' with default values at line " . GetLine($var) . "\n";
                            $nb_MissingShortVariableDeclaration++;
                            Erreurs::VIOLATION($MissingShortVariableDeclaration__mnemo, "Use short variable declaration (:=) for variable '$varName' with default values at line " . GetLine($var));
                        }
                        elsif ($varStatement eq ':=') {
                            my $statement = GetStatement($var);
                            # HL-1629 08/02/2021 Use field names to initialize structs
                            if (defined $statement && $statement =~ /\w+\s*\{([\"\w\s]\,?)+\}$/) {
                                # print "Use field names to initialize structs at line " . GetLine($var) . "\n";
                                $nb_UnnamedData++;
                                Erreurs::VIOLATION($UnnamedData__mnemo, "Use field names to initialize structs at line " . GetLine($var));
                            }
                        }
                    }
                }
            }
        }

        my $children = GetChildren($var);
        if (defined $children && scalar @{$children} > 0) {
            if (IsKind($children->[0], InitKind)) {
                $nb_VariableDeclarations++;
            }
        }
        else {
            $nb_VariableDeclarations++;
        }

    }

    $ret |= Couples::counter_add($compteurs, $SelfAssigned__mnemo, $nb_SelfAssigned );
    $ret |= Couples::counter_add($compteurs, $GlobalVariables__mnemo, $nb_GlobalVariables );
    $ret |= Couples::counter_add($compteurs, $MissingShortVariableDeclaration__mnemo, $nb_MissingShortVariableDeclaration );
    $ret |= Couples::counter_update($compteurs, $UnnamedData__mnemo, $nb_UnnamedData );
    $ret |= Couples::counter_add($compteurs, $VariableDeclarations__mnemo, $nb_VariableDeclarations );

    return $ret;
}



1;
