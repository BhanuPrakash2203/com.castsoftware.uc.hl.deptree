package Groovy::CountMethods;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;
use Lib::CountUtils;

use Groovy::GroovyNode;
use Groovy::CountNaming;

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
my $FunctionImplementations__mnemo = Ident::Alias_FunctionImplementations();
my $MethodImplementations__mnemo = Ident::Alias_MethodImplementations();
my $UnusedParameters__mnemo = Ident::Alias_UnusedParameters();
my $ClosureAsLastMethodParameter__mnemo = Ident::Alias_ClosureAsLastMethodParameter();
my $ParameterUpdate__mnemo = Ident::Alias_ParameterUpdate();

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
my $nb_MethodImplementations = 0;
my $nb_FunctionImplementations = 0;
my $nb_UnusedParameters = 0;
my $nb_ParameterUpdate = 0;

use constant MAX_METHOD_PARAMETERS => 7;

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
    $nb_MethodImplementations = 0;
    $nb_FunctionImplementations = 0;
    $nb_UnusedParameters=0;
    $nb_EmptyMethods=0;
    $nb_ParameterUpdate=0;

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
		$ret |= Couples::counter_add($compteurs, $MethodImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $FunctionImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $EmptyMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ParameterUpdate__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );

		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $Methods = $KindsLists->{&MethodKind};
	my $Functions = $KindsLists->{&FunctionKind};
	my @routines = (@$Methods, @$Functions);

	for my $routine (@routines) {
		
		my $kind = GetKind($routine);
		my $proto = ${GetStatement($routine)};
		my $kindName = (IsKind($routine, MethodKind) ? "method" : "function");
		my $routineName = GetName($routine);
		my $H_modifiers = getGroovyKindData($routine, 'H_modifiers') || {};
		
		#---------------------------------------------------------------
		#-------------------- equals method ----------------------------
		#---------------------------------------------------------------
		if ($kind eq MethodKind) {
		if ($routineName eq "equals") {
        
            my $NameObjectParameter;
            
            # check prototype : Equals(Object <param>)
			if (${GetStatement($routine)} !~ /\(\s*Object\s+(\w+)\s*\)/) {
				$nb_OverloadEquals++;
				Erreurs::VIOLATION($OverloadEquals__mnemo, "Overloading method Equals at line ".GetLine($routine));
			}
            
            # 14/11/2017 HL-296 Always check argument in Equals functions 
            # on recupere l'objet de la classe Object
            else 
            {
				#----------- The "equals" method if overloaded (not the official prototype) -------------
				
                $NameObjectParameter = $1;
# print 'PARAMETRE DETECTE ' . $NameObjectParameter ."\n";
                
                my $ref_children = GetChildren($routine);
                
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
                    # print 'KO => Object method GetClass() not implemented inside equals method at line ' . GetLine($routine) ."\n";
                    $nb_EqualsNotTestingParameter++;
                    Erreurs::VIOLATION($EqualsNotTestingParameter__mnemo, "Equals method doesn't test its parameter type at line " .GetLine($routine));
                }
            }
		}
		}
        
        #---------------------------------------------------------------
        #---------------- all methods : check children -----------------
        #---------------------------------------------------------------
		my $ref_children = GetChildren($routine);
       
        # 18/01/2018 HL-428 METRIC : total number of methods implementation
        if ((defined $H_modifiers->{'abstract'}) || (IsKind(GetParent($routine), InterfaceKind))) {
        #if (scalar @{$ref_children} == 0) {
			$nb_FunctionMethodDeclarations++;
		}
		else {
			$nb_FunctionMethodImplementations++;
			if ($kind eq MethodKind) {
				$nb_MethodImplementations++;
			}
			else {
				$nb_FunctionImplementations++;
			}
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
        my $args = Lib::NodeUtil::GetKindData($routine)->{'arguments'};
        # 19/02/2018 HL-409 Avoid unused parameters
        my $routineCodeBody = Lib::NodeUtil::GetKindData($routine)->{'codeBody'};
        my $countArgs = 0;

        for my $arg (@$args) {
			# my $type = $arg->{'type'};
			my $name = $arg->{'name'};
			# my $default  = $arg->{'default'}; # N/A for Java
			# my $ellipsis = $arg->{'ellipsis'}; # 0 ou 1

			$countArgs++;

			# HL-408 METRIC: total number of parameters
			$nb_TotalParameters++;

			# HL-414 Avoid ellipsis
			if ($arg->{'ellipsis'} == 1) {
				$nb_FunctionsUsingEllipsis++;
				Erreurs::VIOLATION($FunctionsUsingEllipsis__mnemo, "Varargs $kindName (ellipsis) at line " . GetLine($routine));
			}

			# HL-429 check if parameter is used.
			if (defined $name) {
				if ((defined $routineCodeBody) && ($$routineCodeBody !~ /(?:^|[^\w\.])$name\b/m)) {
					# print "++++++++ Violation : $arg not recognized in $kindName body\n";
					$nb_UnusedParameters++;
					Erreurs::VIOLATION($UnusedParameters__mnemo, "Argument $name is not used in $kindName $routineName body at line " . ($arg->{'line'} || "??"));
				}
			}
			else {
				print "[CountMethods] no name for argument of $kindName " . GetName($routine) . " at line " . GetLine($routine) . "\n";
			}

			# 24/11/2020 HL-1562 Avoid parameters reassignment
			$nb_ParameterUpdate = CountParamaterUpdate($vue->{'code'}, $routine, $name, $nb_ParameterUpdate);
        }
        
        if ($countArgs > MAX_METHOD_PARAMETERS) {
			$nb_WithTooMuchParametersMethods++;
			Erreurs::VIOLATION($UnconditionalJump__mnemo, "$kindName $routineName has too much parameters at line ".GetLine($routine));
		}
		
		#---------------------------------------------------------------
        #---------------- all methods : check name ---------------------
        #---------------------------------------------------------------
        

		if (! Groovy::CountNaming::checkMethodName($routineName)) {
			$nb_BadMethodNames++;
			Erreurs::VIOLATION($BadMethodNames__mnemo, "Bad method name ($routineName) at line ".GetLine($routine));
		}

		if ( ! Groovy::CountNaming::isExceptionMethod($routineName)) {		
			if (! Groovy::CountNaming::checkMethodNameLength($routineName)) {
				$nb_ShortMethodNamesLT++;
				Erreurs::VIOLATION($ShortMethodNamesLT__mnemo, "Method name ($routineName) is too short at line ".GetLine($routine));
			}
		}
        
        #---------------------------------------------------------------
        #---------------- all methods : check emptyness ----------------
        #---------------------------------------------------------------
        
        my $parent = GetParent($routine);
        
        my $parentClassModifiers = getGroovyKindData($parent, 'H_modifiers') || {};
        
        my $checkEmptyness = 1;

        if (IsKind($parent, ClassKind)) {
			my $className = GetName($parent);
			my $nb_constructors = getGroovyKindData($parent, 'nb_constructors');

			if ( ($nb_constructors > 1) && ($className eq $routineName) && ($proto =~ /^\s*\(\s*\)/m) ) {
				# empty constructor and other constructors presents
				$checkEmptyness = 0;
			}
			elsif (defined $parentClassModifiers->{'abstract'}) {
				# class is abstract
				$checkEmptyness = 0;
			}
		}
        
        if ( $checkEmptyness ) {
        
			# PARENT IS A NON ABSTRACT CLASS
        
			if (isEmptyMethod($routine, $vue)) {
				$nb_EmptyMethods++;
				Erreurs::VIOLATION($EmptyMethods__mnemo, "Empty $kindName at line " .GetLine($routine));
			}
		}
	}
    
    Erreurs::VIOLATION($MethodImplementations__mnemo, "METRIC : nb methods implementation = $nb_MethodImplementations");
    Erreurs::VIOLATION($FunctionImplementations__mnemo, "METRIC : nb functions implementation = $nb_FunctionImplementations");
    
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
    $ret |= Couples::counter_add($compteurs, $MethodImplementations__mnemo, $nb_MethodImplementations );
    $ret |= Couples::counter_add($compteurs, $FunctionImplementations__mnemo, $nb_FunctionImplementations );
    $ret |= Couples::counter_add($compteurs, $UnusedParameters__mnemo, $nb_UnusedParameters );
    $ret |= Couples::counter_add($compteurs, $EmptyMethods__mnemo, $nb_EmptyMethods );
    $ret |= Couples::counter_update($compteurs, $ParameterUpdate__mnemo, $nb_ParameterUpdate );

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
		
		#  check presence of @override
		my $previousOverrideAnnotation = Lib::Node::GetPreviousSibling($method);
		if ((defined $previousOverrideAnnotation) && (IsKind ($previousOverrideAnnotation, AnnotationKind))) {
			while (	($previousOverrideAnnotation) and 
					(IsKind ($previousOverrideAnnotation, AnnotationKind)) and 
					(GetName ($previousOverrideAnnotation) ne 'Override') )
			{
				$previousOverrideAnnotation = Lib::Node::GetPreviousSibling ($previousOverrideAnnotation);
			}
		}
		else {
			$previousOverrideAnnotation = undef;
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

# 23/11/2020 HL-1559 Avoid unexpected closure inside parentheses call
sub CountInlineClosureAsParameter($$$$) {
    my ($fichier, $vue, $couples, $options) = @_;
    my $status = 0;

	my $reg = qr/\}\s*\)/;
  
	my $nb_ClosureAsLastMethodParameter = Lib::CountUtils::CountGrepWithLine($reg, $ClosureAsLastMethodParameter__mnemo, "Closure as last method parameter", \$vue->{'code'});
    
    $status |= Couples::counter_add($couples, $ClosureAsLastMethodParameter__mnemo ,$nb_ClosureAsLastMethodParameter );
        
    return $status;
}

sub CountParamaterUpdate($$$$) {

	my $code = shift;
	my $node = shift;
	my $nameParam = shift;
	my $nb_ParameterUpdate = shift;

	my $beginingLine = GetLine($node);
	my $endingLine = GetEndline($node);
	
	my $line = 1;
	pos($code) = 0;

	while ($code =~ /(\n)|([^\.]\b$nameParam\s*(?:\=(?!\=)|\+\=|\-\=|\*\=|\/\=|\%\=|\+\+|\-\-))/g) {
		$line++ if defined $1;
		if ($line >= $beginingLine && $line <= $endingLine) {
			if (defined $2) {
				# print "Parameter \"$nameParam\" reassignment in body of $typeNode $nodeName at line $line\n";
				$nb_ParameterUpdate++;
				
				my $nodeName = "";
				my $typeNode;
				if (IsKind($node, MethodKind)) {
					$typeNode = "method";
					$nodeName = GetName($node);
				}
				elsif (IsKind($node, FunctionKind)) {
					$typeNode = "function";
					$nodeName = GetName($node);
				}
				elsif (IsKind($node, ClosureKind)) {
					$typeNode = "closure";
					$nodeName = "";
				}
				else {
					$typeNode = "unknown_node";
				}
				Erreurs::VIOLATION($ParameterUpdate__mnemo, "Parameter \"$nameParam\" reassignment in body of $typeNode $nodeName at line $line");
			}
		}
		last if ($line == $endingLine);
	}
	return $nb_ParameterUpdate;
}

1;
