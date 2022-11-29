package TypeScript::CountParameter ;

use strict;
use warnings;

use Erreurs;
use Lib::NodeUtil;
use TypeScript::TypeScriptNode;

use Ident;
use TypeScript::Identifiers;

use constant {
    MAXPARAM   => 4, # Max number for function parameters
    CONSTRUCTORNAME   => "constructor", # constructor name
};

my $DEBUG = 0;

my $mnemo_MaxParameters = Ident::Alias_MaxParameters();
my $mnemo_ParametersAverage = Ident::Alias_ParametersAverage();

my $nb_MaxParameters = 0;
my $nb_ParametersAverage = 0;

# HL-846 17/04/2019 Functions should not have too many parameters
sub CountParameter($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;
    $nb_MaxParameters = 0;
    $nb_ParametersAverage = 0;
  
    my $root = $vue->{'structured_code'};

    if (not defined $root)
    {
        $status |= Couples::counter_add ($compteurs, $mnemo_MaxParameters, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_ParametersAverage, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @funcs = GetNodesByKindList($root, [FunctionDeclarationKind, FunctionExpressionKind, MethodKind]);
    my $nb_routines = 0;
    for my $func (@funcs)
    {
		# mnemo_MaxParameters: diag exception for constructors
		my $routineName = GetName($func);
		if ($routineName ne CONSTRUCTORNAME)
		{
			#-------------------------------------------------------------
			#----------- Get parameters ----------------------------------
			#-------------------------------------------------------------
			my $r_params = Lib::NodeUtil::GetXKindData($func, 'parameters');
			
			if (defined $r_params)
			{
				my $nb_params = scalar(@$r_params);
				
				if (scalar(@$r_params) > MAXPARAM)
				{
					print "Functions should not have too many parameters (max=".MAXPARAM.") at line ".GetLine($func)."\n" if $DEBUG;
					$nb_MaxParameters++;
					Erreurs::VIOLATION($mnemo_MaxParameters, "Functions should not have too many parameters (max=".MAXPARAM.") at line ".GetLine($func));
				}
				
				$nb_routines++;
				$nb_ParametersAverage += $nb_params;
			}
		}
    }
    
    if ($nb_routines) {
		$nb_ParametersAverage = int($nb_ParametersAverage / $nb_routines);
	}
    
    $status |= Couples::counter_add ($compteurs, $mnemo_MaxParameters, $nb_MaxParameters);
    $status |= Couples::counter_add ($compteurs, $mnemo_ParametersAverage, $nb_ParametersAverage);
   
    return $status;
    
}

1;
