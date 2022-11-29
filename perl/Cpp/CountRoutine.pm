
package Cpp::CountRoutine;

use strict;
use warnings;

use Erreurs;
use Cpp::ParserIdents;
use Lib::Node;
use Lib::NodeUtil;
use Cpp::CppNode;

my $DEBUG = 0;

my $mnemo_TotalParameters = Ident::Alias_TotalParameters();
my $mnemo_FunctionMethodImplementations = Ident::Alias_FunctionMethodImplementations();
my $mnemo_WithoutFinalExit = Ident::Alias_WithoutFinalExit();
my $mnemo_FunctionsUsingEllipsis = Ident::Alias_FunctionsUsingEllipsis();
my $mnemo_EmptyReturn = Ident::Alias_EmptyReturn();

my $nb_TotalParameters = 0;
my $nb_FunctionMethodImplementations = 0;
my $nb_WithoutFinalExit = 0;
my $nb_FunctionsUsingEllipsis = 0;
my $nb_EmptyReturn = 0;

# HL-616 26/09/2018 C++ DIAG : Avoid routines with too much parameters
# HL-625 05/10/2018 C++ DIAG : Avoid too many functions/methods
# HL-748 21/01/2019 C++ DIAG : Avoid functions with several exit points
# HL-758 28/01/2019 C++ DIAG : Avoid ellipsis in function declaration
# HL-759 29/01/2019 C++ DIAG : Avoid empty return
sub CountRoutine($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_TotalParameters = 0;
    $nb_FunctionMethodImplementations = 0;
    $nb_WithoutFinalExit = 0;
    $nb_FunctionsUsingEllipsis = 0;
    $nb_EmptyReturn = 0;

    my $KindsLists = $vue->{'KindsLists'}||[];
    my $Artifacts = $vue->{'artifact'}||[];

    if  (! defined $Artifacts )
    {
		$status |= Couples::counter_add($nb_EmptyReturn, $mnemo_EmptyReturn, Erreurs::COMPTEUR_ERREUR_VALUE );
    }
    
  	if ( ! defined $KindsLists )
	{
		$status |= Couples::counter_add($compteurs, $mnemo_TotalParameters, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_FunctionMethodImplementations, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_WithoutFinalExit, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_FunctionsUsingEllipsis, Erreurs::COMPTEUR_ERREUR_VALUE );
    }    
    
    my $Methods = $KindsLists->{&MethodKind}||[];
    my $Functions = $KindsLists->{&FunctionKind}||[];
    
    my $Routines = [ @$Methods, @$Functions];
    
    #-----------------------#
    #  METHODS + FUNCTIONS  #
    #-----------------------#
    for my $routine (@$Routines) 
    {
		my $RoutineName = GetName($routine);
        print "+++++ Routine $RoutineName found\n" if $DEBUG;
        $nb_FunctionMethodImplementations++;
        
        my $type = Lib::NodeUtil::GetKindData($routine)->{'type'} || "";
        my $args = Lib::NodeUtil::GetKindData($routine)->{'arguments'};
        
        for my $arg (@$args) 
        {
            $nb_TotalParameters++;
            
            if ($arg->{'ellipsis'} == 1)
            {
                Erreurs::VIOLATION($mnemo_FunctionsUsingEllipsis, "Ellipsis notation for function or Method $RoutineName");
                print "Ellipsis notation for function or Method $RoutineName\n" if ($DEBUG);
                $nb_FunctionsUsingEllipsis++;
            }
        }
        
        if ($type ne 'void')
        {
            my $artifactKey = getCppKindData($routine, 'artifact_key');
            if (defined $artifactKey) {
				my $codeBody = $Artifacts->{$artifactKey};
				if ($codeBody =~ /\breturn\s*\;/)
				{
					Erreurs::VIOLATION($mnemo_EmptyReturn, "Empty return inside function = $RoutineName");
					print "Empty return inside function = $RoutineName\n" if ($DEBUG);
					$nb_EmptyReturn++;
				}
			}
        }

        if ($RoutineName ne "main")
        {
            my @returnNodes = GetNodesByKindList ($routine, [ReturnKind]);

            # Exception for function try-block 
            if (! defined getCppKindData($routine, 'function-try-block'))
            {
               if (scalar @returnNodes > 1)
                {
                    Erreurs::VIOLATION($mnemo_WithoutFinalExit, "Several exit points for function $RoutineName");
                    print "Several exit points for function $RoutineName\n" if ($DEBUG);
                    $nb_WithoutFinalExit++;            
                }
                else
                {
                    if ($type ne 'void')
                    {
                        my $children = GetChildren ($routine);
                        
                        # function is empty or not ? 
                        if (scalar @$children) {
							my $last_child = $children->[-1];

							if (! IsKind($last_child, ReturnKind))
							{
								Erreurs::VIOLATION($mnemo_WithoutFinalExit, "Missing ending return for Function $RoutineName");
								print "Missing ending return for Function $RoutineName\n" if ($DEBUG);
								$nb_WithoutFinalExit++;
							}
						}
                    }
                }
            }
        }
    }
        
    Erreurs::VIOLATION($mnemo_TotalParameters, "METRIC : total number of parameters = $nb_TotalParameters");
    Erreurs::VIOLATION($mnemo_FunctionMethodImplementations, "METRIC : total number of routines = $nb_FunctionMethodImplementations");
        
    $status |= Couples::counter_add ($compteurs, $mnemo_TotalParameters, $nb_TotalParameters);
    $status |= Couples::counter_add ($compteurs, $mnemo_FunctionMethodImplementations, $nb_FunctionMethodImplementations);
    $status |= Couples::counter_add ($compteurs, $mnemo_WithoutFinalExit, $nb_WithoutFinalExit);
    $status |= Couples::counter_add ($compteurs, $mnemo_FunctionsUsingEllipsis, $nb_FunctionsUsingEllipsis);
    $status |= Couples::counter_add ($compteurs, $mnemo_EmptyReturn, $nb_EmptyReturn);
    return $status;
}

1;
