package Java::CountMethods;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Java::JavaNode;
use Java::CountNaming;

my $OverloadEquals__mnemo = Ident::Alias_OverloadEquals();
my $EqualsNotTestingParameter__mnemo = Ident::Alias_EqualsNotTestingParameter();
my $EmptyMethods__mnemo = Ident::Alias_EmptyMethods();
my $UnconditionalJump__mnemo = Ident::Alias_UnconditionalJump();
my $WithTooMuchParametersMethods__mnemo = Ident::Alias_WithTooMuchParametersMethods();
my $TotalParameters__mnemo = Ident::Alias_TotalParameters();
my $BadMethodNames__mnemo = Ident::Alias_BadMethodNames();
my $ShortMethodNamesLT__mnemo = Ident::Alias_ShortMethodNamesLT();
my $FunctionsUsingEllipsis__mnemo = Ident::Alias_FunctionsUsingEllipsis();
my $FunctionMethodDeclarations__mnemo = Ident::Alias_FunctionMethodDeclarations();
my $FunctionMethodImplementations__mnemo = Ident::Alias_FunctionMethodImplementations();
my $UnusedParameters__mnemo = Ident::Alias_UnusedParameters();

my $nb_OverloadEquals = 0;
my $nb_EqualsNotTestingParameter = 0;
my $nb_EmptyMethods = 0; 
my $nb_UnconditionalJump = 0; 
my $nb_WithTooMuchParametersMethods = 0;
my $nb_TotalParameters = 0;
my $nb_BadMethodNames = 0;
my $nb_ShortMethodNamesLT = 0;
my $nb_FunctionsUsingEllipsis = 0;
my $nb_FunctionMethodDeclarations = 0;
my $nb_FunctionMethodImplementations = 0;
my $nb_UnusedParameters = 0;

use constant MAX_METHOD_PARAMETERS => 7;

sub isParameterUsed($$);

sub isParameterUsed($$) {
	my $argName = shift;
	my $method = shift;

#print STDERR "CHECK arg $argName\n";
	
	# 19/02/2018 HL-409 Avoid unused parameters
    my $methodCodeBody = Lib::NodeUtil::GetKindData($method)->{'codeBody'};
 
    my $used = 0;
    
    if (defined $methodCodeBody) {
		
		if ($$methodCodeBody =~/(?:^|[^\w\.])$argName\b/m) {
			$used = 1;
		}
		else {
			my @subMethods = GetNodesByKind($method, MethodKind);
		
			# check if used inside sub method ...
			method: for my $subMethod (@subMethods) {
			
				my $args = Lib::NodeUtil::GetKindData($subMethod)->{'arguments'};
			
				for my $subArg (@$args) {
					if ($argName eq $subArg->{'name'}) {
						# the sub method has a parameter with the same name, so the searched parameter is hidden and cannot be used.
						next method;
					}
				}
			
				if (isParameterUsed($argName, $subMethod)) {
					$used = 1;
					last;
				}	
			}
		}
	}

	return $used;
}

sub CountMethods($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
    
    # 10/11/2017 HL-295 Avoid Equals Overload
	my $ret = 0;
	$nb_OverloadEquals = 0;
	$nb_EqualsNotTestingParameter = 0;
    $nb_UnconditionalJump = 0;
    $nb_WithTooMuchParametersMethods = 0;
    $nb_BadMethodNames = 0;
    $nb_TotalParameters = 0;
    $nb_ShortMethodNamesLT = 0;
    $nb_FunctionsUsingEllipsis = 0;
    $nb_FunctionMethodDeclarations = 0;
    $nb_FunctionMethodImplementations = 0;
    $nb_UnusedParameters=0;
    $nb_EmptyMethods=0;

    my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $OverloadEquals__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $EqualsNotTestingParameter__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnconditionalJump__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $TotalParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadMethodNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ShortMethodNamesLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $FunctionsUsingEllipsis__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $FunctionMethodDeclarations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $FunctionMethodImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $EmptyMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $Methods = $KindsLists->{&MethodKind};

	for my $method (@$Methods) {
		
		my $MethodName = GetName($method);
		my $H_modifiers = getJavaKindData($method, 'H_modifiers') || {};
		
		#---------------------------------------------------------------
		#-------------------- equals method ----------------------------
		#---------------------------------------------------------------
		if ($MethodName eq "equals") {
        
            my $NameObjectParameter;
            
            # check prototype : Equals(Object <param>)
			if (${GetStatement($method)} !~ /\(\s*Object\s+(\w+)\s*\)/) {
				$nb_OverloadEquals++;
				Erreurs::VIOLATION($OverloadEquals__mnemo, "Overloading method Equals at line ".GetLine($method));
			}
            
            # 14/11/2017 HL-296 Always check argument in Equals functions 
            # on recupere l'objet de la classe Object
            else 
            {
				#----------- The "equals" method if overloaded (not the official prototype) -------------
				
                $NameObjectParameter = $1;
# print 'PARAMETRE DETECTE ' . $NameObjectParameter ."\n";
                
                my $ref_children = GetChildren($method);
                
                my $BoolSuccess = 0;
                
                foreach my $child (@{$ref_children})
                {
                    # si if contient NameObjectParameter 
                    # et contient NameObjectParameter.getclass => OK
                    if (GetKind($child) eq IfKind)
                    {
                    
                        my $ref_subbloc_niv1 = GetChildren($child);
                        foreach my $subbloc (@{$ref_subbloc_niv1})
                        {
                            # si nous sommes au niveau enfant cond
                            # on doit retrouver le NameObjectParameter et getClass()
                            if (GetKind($subbloc) eq ConditionKind )
                            {
                                if (${GetStatement($subbloc)} =~ /\b$NameObjectParameter\b\s*\.\s*getClass\s*\(/)
                                {
# print 'Success => Parameter of equals method <' . $NameObjectParameter ."> and getClass method recognized\n";
                                    $BoolSuccess = 1;
                                    last;
                                }

                            }

                        }
                    }
                }
                
                if ($BoolSuccess == 0)
                {
                    # print 'KO => Object method GetClass() not implemented inside equals method at line ' . GetLine($method) ."\n";
                    $nb_EqualsNotTestingParameter++;
                    Erreurs::VIOLATION($EqualsNotTestingParameter__mnemo, "Equals method doesn't test its parameter type at line " .GetLine($method));
                }
            }
		}
        
        #---------------------------------------------------------------
        #---------------- all methods : check children -----------------
        #---------------------------------------------------------------
		my $ref_children = GetChildren($method);
       
        # 18/01/2018 HL-428 METRIC : total number of methods implementation
        if ((defined $H_modifiers->{'abstract'}) || (IsKind(GetParent($method), InterfaceKind))) {
        #if (scalar @{$ref_children} == 0) {
			$nb_FunctionMethodDeclarations++;
		}
		else {
			$nb_FunctionMethodImplementations++;
		}
       
        # 10/01/2018 HL-405 Avoid unconditional jump statement 
        foreach my $child (@{$ref_children})
        {        
            if ( GetKind ($child) eq ReturnKind 
                or GetKind ($child) eq ThrowKind )
            {
                # print '2++++++' . GetKind ($child)."\n";
               	my $nextSibling = Lib::Node::GetNextSibling($child);
                
                if ($nextSibling) {
					$nb_UnconditionalJump++;
					Erreurs::VIOLATION($UnconditionalJump__mnemo, "Unconditional jump at line ".GetLine($child));
				}
            }
        }
        
        #---------------------------------------------------------------
        #---------------- all methods : check parameters ---------------
        #---------------------------------------------------------------
        
        # 12/01/2018 HL-407 Avoid methods with too much parameters
        my $args = Lib::NodeUtil::GetKindData($method)->{'arguments'};
        
        my $countArgs = 0;
        my @concatNameArgs; 
        
        for my $arg (@$args) 
        {
           # my $type = $arg->{'type'};
           my $name = $arg->{'name'};
           # my $default  = $arg->{'default'}; # N/A for Java
           # my $ellipsis = $arg->{'ellipsis'}; # 0 ou 1
           
           $countArgs++;
           
           # HL-408 METRIC: total number of parameters
           $nb_TotalParameters++;
          
           # HL-414 Avoid ellipsis
           if ($arg->{'ellipsis'} == 1)
           {
               $nb_FunctionsUsingEllipsis++;
               Erreurs::VIOLATION($FunctionsUsingEllipsis__mnemo, "Varargs method (ellipsis) at line ".GetLine($method));
           }
           
           # HL-429 check if parameter is used.
		   if (defined $name) {
			   
			#if ( (defined $methodCodeBody) && ($$methodCodeBody !~/\b$name\b/) )
			if ( ! isParameterUsed($name, $method))
			{
				# print "++++++++ Violation : $arg not recognized in method body\n";
                $nb_UnusedParameters++;
                Erreurs::VIOLATION($UnusedParameters__mnemo, "Argument $name is not used in method $MethodName body at line ".($arg->{'line'}||"??"));
			}
		   }
		   else {
			   print "[CountMethods] no name for argument of method ".GetName($method)." at line ".GetLine($method)."\n";
		   }
        }
        
        if ($countArgs > MAX_METHOD_PARAMETERS) {
			$nb_WithTooMuchParametersMethods++;
			Erreurs::VIOLATION($UnconditionalJump__mnemo, "Method $MethodName has too much parameters at line ".GetLine($method));
		}
		
		#---------------------------------------------------------------
        #---------------- all methods : check name ---------------------
        #---------------------------------------------------------------
        

		if (! Java::CountNaming::checkMethodName($MethodName)) {
			$nb_BadMethodNames++;
			Erreurs::VIOLATION($BadMethodNames__mnemo, "Bad method name ($MethodName) at line ".GetLine($method));
		}

		if ( ! Java::CountNaming::isExceptionMethod($MethodName)) {		
			if (! Java::CountNaming::checkMethodNameLength($MethodName)) {
				$nb_ShortMethodNamesLT++;
				Erreurs::VIOLATION($ShortMethodNamesLT__mnemo, "Method name ($MethodName) is too short at line ".GetLine($method));
			}
		}
        
        #---------------------------------------------------------------
        #---------------- all methods : check emptyness ----------------
        #---------------------------------------------------------------
        
        my $parent = GetParent($method);
        
        my $parentClassModifiers = getJavaKindData($parent, 'H_modifiers') || {};
        
        if (	(IsKind($parent, ClassKind)) &&
				( ! defined $parentClassModifiers->{'abstract'}) ) {
        
        # PARENT IS A NON ABSTRACT CLASS
        
        if (isEmptyMethod($method, $vue)) {
				$nb_EmptyMethods++;
				Erreurs::VIOLATION($EmptyMethods__mnemo, "Empty method at line " .GetLine($method));
			}
		}

	}
    
    $ret |= Couples::counter_add($compteurs, $OverloadEquals__mnemo, $nb_OverloadEquals );
    $ret |= Couples::counter_add($compteurs, $EqualsNotTestingParameter__mnemo, $nb_EqualsNotTestingParameter );
    $ret |= Couples::counter_update($compteurs, $UnconditionalJump__mnemo, $nb_UnconditionalJump );
    $ret |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods__mnemo, $nb_WithTooMuchParametersMethods );
    $ret |= Couples::counter_add($compteurs, $TotalParameters__mnemo, $nb_TotalParameters );
    $ret |= Couples::counter_add($compteurs, $BadMethodNames__mnemo, $nb_BadMethodNames );
    $ret |= Couples::counter_add($compteurs, $ShortMethodNamesLT__mnemo, $nb_ShortMethodNamesLT );
    $ret |= Couples::counter_add($compteurs, $FunctionsUsingEllipsis__mnemo, $nb_FunctionsUsingEllipsis );
    $ret |= Couples::counter_add($compteurs, $FunctionMethodDeclarations__mnemo, $nb_FunctionMethodDeclarations );
    $ret |= Couples::counter_add($compteurs, $FunctionMethodImplementations__mnemo, $nb_FunctionMethodImplementations );
    $ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, $nb_UnusedParameters );
    $ret |= Couples::counter_add($compteurs, $EmptyMethods__mnemo, $nb_EmptyMethods );
    
    return $ret;
}


sub isEmptyMethod($$) 
{   
	my $method = shift;
	my $views = shift;
	
    # JLE 28/11/2017 HL-304 Avoid empty methods
          
	my $instructions = GetChildren($method);

	if (scalar @$instructions == 0)
	{
		# METHOD IS EMPTY

		my $previousOverrideAnnotation = Lib::Node::GetPreviousSibling($method);
		while (	($previousOverrideAnnotation) and 
				(IsKind ($previousOverrideAnnotation, AnnotationKind)) and 
				(GetName ($previousOverrideAnnotation) ne 'Override') )
		{
			$previousOverrideAnnotation = Lib::Node::GetPreviousSibling ($previousOverrideAnnotation);
		}

		if ($previousOverrideAnnotation)
		{
			# OVERRIDE ANNOTATION IS PRESENT
			
			my $resultDetectComment = DetectCommentBetweenTwoLines ($views, GetLine($method), GetEndline ($method));

			if ($resultDetectComment == 0)
			{
				# METHOD IS AN UNCOMMENTED OVERRIDE
				return 1;
			}
		}
		else
		{
			# METHOD IS NOT AN OVERRIDE  
			return 1;
		}
	}
    
    return 0;
}

sub DetectCommentBetweenTwoLines($$$)
{

    my $vue = shift;
    my $BeginningLine = shift;
    my $EndLine = shift;

    my $index1 = $vue->{'agglo_LinesIndex'}->[$BeginningLine];
    my $index2 = $vue->{'agglo_LinesIndex'}->[$EndLine];
    # print "index $index1 a index $index2 \n";
    
    my $bloc;
    if (defined $index2) {
        $bloc = substr ($vue->{'agglo'}, $index1, ($index2-$index1));
    }
    else {
        $bloc = substr ($vue->{'agglo'}, $index1);
    }
    # print 'bloc ' . $bloc."\n";
    if ($bloc  !~ /C/)
    {
        # alert
        return 0;    
    }        
    return 1;

}

1;

