
package Cpp::CountVariable;

use strict;
use warnings;

use Erreurs;
use Cpp::ParserIdents;
use Lib::NodeUtil;
use Cpp::CppNode;
use Cpp::ParseCpp;

my $DEBUG = 0;

my $mnemo_ApplicationGlobalVariables = Ident::Alias_ApplicationGlobalVariables();
my $mnemo_StaticGlobalVariableInHeader = Ident::Alias_StaticGlobalVariableInHeader();
my $mnemo_BadLiteralConstant  = Ident::Alias_BadLiteralConstant ();
my $mnemo_MissingTabSize   = Ident::Alias_MissingTabSize  ();
my $mnemo_GlobalVariableHidding   = Ident::Alias_GlobalVariableHidding  ();
 
my $nb_ApplicationGlobalVariables = 0;
my $nb_StaticGlobalVariableInHeader = 0;
my $nb_BadLiteralConstant = 0;
my $nb_MissingTabSize = 0;
my $nb_GlobalVariableHidding = 0;


# HL-617 28/09/2018 C++ DIAG : Avoid application global variables
# HL-682 10/10/2018 Never define static variables in header files
# HL-745 17/01/2019 C++ DIAG : Avoid unspecified tab size
sub CountVariable($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_ApplicationGlobalVariables = 0;
    $nb_StaticGlobalVariableInHeader = 0;
    $nb_MissingTabSize = 0;

    my $Structured_code = $vue->{'structured_code'};

  	if ( ! defined $Structured_code )
	{
		$status |= Couples::counter_add($compteurs, $mnemo_ApplicationGlobalVariables, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_StaticGlobalVariableInHeader, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_MissingTabSize, Erreurs::COMPTEUR_ERREUR_VALUE );
    }    
    
    my @GlobVar = GetNodesByKindList_StopAtBlockingNode($Structured_code, [VariableKind], [ClassKind, StructKind, FunctionKind]); 

	for my $GlobVar (@GlobVar) 
    {
        my $H_modifiers = getCppKindData($GlobVar, 'H_modifiers') || {};

        my $nameVar = GetName ($GlobVar);
        
        if (defined $H_modifiers->{'static'})
        {
            # The rule applies only to header file
            if ($fichier =~ /\.h[^\.]*$/i) 
            {
                Erreurs::VIOLATION($mnemo_StaticGlobalVariableInHeader, "Static global variable $nameVar into header file: $fichier");
                print "+++++ Static global variable $nameVar into header file: $fichier\n" if ($DEBUG);
                $nb_StaticGlobalVariableInHeader++;
            }
        }
        else{
            Erreurs::VIOLATION($mnemo_ApplicationGlobalVariables, "Non static global variable : $nameVar");
            $nb_ApplicationGlobalVariables++;
        }
    }
 
    
    my @Variables = GetNodesByKindList($Structured_code, [VariableKind]); 
    
	for my $varNode (@Variables) 
    {
        my $namevarNode = GetName ($varNode);
                
        my $array_properties = getCppKindData($varNode, 'tab') || {};

        $array_properties =~ s/\s+//g;
        $array_properties =~ s/\[//g;
        $array_properties =~ s/\]//g;
        
        # check array size value definition
        if (defined $array_properties and $array_properties eq "")
        {
            my $initNode = GetChildren($varNode)->[0];
            
            if (defined $initNode) 
            {
                my $statement = ${GetStatement($initNode)};
                
                $statement =~ s/\s+//g;
                $statement =~ s/\{//g;
                $statement =~ s/\}//g;  
                
                if (defined $statement and $statement eq "")
                {            
                    Erreurs::VIOLATION($mnemo_MissingTabSize, "Array declaration $namevarNode without size and initialization");
                    print "Array declaration $namevarNode without size and initialization\n" if ($DEBUG);
                    $nb_MissingTabSize++;                
                }
            }
            else
            {
                Erreurs::VIOLATION($mnemo_MissingTabSize, "Array declaration $namevarNode without size and initialization");
                print "Array declaration $namevarNode without size and initialization\n" if ($DEBUG);
                $nb_MissingTabSize++;               
            }
        }
    }

    $status |= Couples::counter_add ($compteurs, $mnemo_ApplicationGlobalVariables, $nb_ApplicationGlobalVariables);
    $status |= Couples::counter_add ($compteurs, $mnemo_StaticGlobalVariableInHeader, $nb_StaticGlobalVariableInHeader);
    $status |= Couples::counter_add ($compteurs, $mnemo_MissingTabSize, $nb_MissingTabSize);
    return $status;
}

# HL-743 15/01/2019 C++ DIAG : Avoid bad literal constant
sub CountBadLiteralConstant($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_BadLiteralConstant = 0;

    my $HMagic_view = $vue->{'HMagic'}; # magic numbers
    my $Hstrings = $vue->{'HString'}; # octal sequence form \ddd+

  	if ( ! defined $HMagic_view or ! defined $Hstrings)
	{
		$status |= Couples::counter_add($compteurs, $mnemo_BadLiteralConstant, Erreurs::COMPTEUR_ERREUR_VALUE );
    }    
        
    foreach my $key (keys %{$HMagic_view})
    {
        if ($key !~ /^0+$/m)
        {
            if ($key =~ /^0\d+/m or $key =~ /^[\w\d\.]+[a-z]{1}$/m)
            {
                Erreurs::VIOLATION($mnemo_BadLiteralConstant, "Bad literal constant found : $key");
                print "Bad literal constant found $key !!!!!\n" if ($DEBUG);
                $nb_BadLiteralConstant++;        
            }
        }
    }

    foreach my $key (keys %{$Hstrings})
    {
        if ($Hstrings->{$key} !~ /^\'\\0+\'$/m)
        {
            if ($Hstrings->{$key} =~ /^\'\\\d+/m)
            {
                Erreurs::VIOLATION($mnemo_BadLiteralConstant, "Bad literal constant found : $Hstrings->{$key}");
                print "Bad literal constant found $Hstrings->{$key} !!!!!\n" if ($DEBUG);
                $nb_BadLiteralConstant++;
            }
        }
    }
    
    $status |= Couples::counter_add ($compteurs, $mnemo_BadLiteralConstant, $nb_BadLiteralConstant);
    return $status;
}



my %KindScope = (
	&IfKind 	=> 1,
	&ElseKind 	=> 1,
	&WhileKind	=> 1,
	&ForKind 	=> 1,
	&MethodKind	=> 1,
	&FunctionKind	=> 1,
	&ClassKind 	=> 1,
	&EnumKind	=> 1,
	&TryKind	=> 1,
	&CatchKind	=> 1,
	&FinallyKind	=> 1,
	&EForKind	=> 1,
	&DoKind		=> 1,
	&CaseKind	=> 1,
	&DefaultKind	=> 1,
	&BlockKind	=> 1,
	&NamespaceKind	=> 1
);

sub isNewScope($) {
	my $node = shift;
	
	if ($KindScope{GetKind($node)}) {
		return 1;
	}
	
	return 0;
}

sub CountScope($$$);
sub CountScope($$$) {
	my $node = shift;
	my $context = shift;
	my $localVars = shift;
	
    # Check for functions or methods parameters ...
    if ((IsKind($node, FunctionKind)) or (IsKind($node, MethodKind))) 
    {
        my $arguments = getCppKindData($node, 'arguments');
        if (defined $arguments) 
        {
            my $line = GetLine($node);

            for my $arg (@$arguments)
            {
                # check if the variable is hidding another of outer scope
                SETVAR:
                for my $varSet (@{$context->{'outer_vars'}}) 
                {
                    for my $var (@$varSet) 
                    {
                        if (defined $arg->{'name'} and $arg->{'name'} eq $var->[0]) 
                        {
                            print "Variable \"$arg->{'name'}\" in parameter at line $line is hidding variable declared at line $var->[1]\n" if ($DEBUG);
                            Erreurs::VIOLATION($mnemo_GlobalVariableHidding, "Variable \"$arg->{'name'}\" in parameter at line $line is hidding variable declared at line $var->[1]\n");
                            $nb_GlobalVariableHidding++;
                            last SETVAR;
                        }
                    }
                }
            }
        }
    }
    
	# check each subnodes ...
	for my $child (@{GetChildren($node)}) 
    {
		# Check for variable.
		if (IsKind($child, VariableKind)) 
        {
			my $name = GetName($child);
			my $line = GetLine($child);
			push @$localVars, [$name, $line];
			
			# check if the variable is hidding another of outer scope
			VARSET:
            for my $varSet (@{$context->{'outer_vars'}}) 
            {
				for my $var (@$varSet) 
                {
					if ($name eq $var->[0]) 
                    {
                        print "Variable \"$name\" at line $line is hidding variable declared at line $var->[1]\n" if ($DEBUG);
						Erreurs::VIOLATION($mnemo_GlobalVariableHidding, "Variable \"$name\" at line $line is hidding variable declared at line $var->[1]\n");
						$nb_GlobalVariableHidding++;
                        last VARSET;
					}
				}
			}
		}
				
        # check if the subnode introduce an inner scope
		# The difference will be the status of current local variables ...
        if (isNewScope($child)) 
        {
 			push @{$context->{'outer_vars'}}, $localVars;
            CountScope($child, $context, []);
			pop @{$context->{'outer_vars'}};
		}
		else 
        {
			# inner structural level (subnode) is not a new scope => keep same local variables set.
			CountScope($child, $context, $localVars);
		}
	}
}

sub CountVariableHidding($$$$) {
	my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_GlobalVariableHidding = 0;
    
    my $root = $vue->{'structured_code'};
    
    my %context = ('outer_vars' => []);
    
    CountScope($root, \%context, [] );
    
    $status |= Couples::counter_add ($compteurs, $mnemo_GlobalVariableHidding, $nb_GlobalVariableHidding);
    return $status;
}

1;
