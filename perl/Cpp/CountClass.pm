package Cpp::CountClass;

use strict;
use warnings;

use Erreurs;
use Cpp::ParserIdents;
use Lib::NodeUtil;
use Cpp::CppNode;

my $DEBUG = 0;

my $mnemo_WithoutVirtualDestructorAbstractClass = Ident::Alias_WithoutVirtualDestructorAbstractClass();
my $mnemo_NonPrivateDataMember = Ident::Alias_NonPrivateDataMember();
my $mnemo_RuleOf3_WithCopyAssignator = Ident::Alias_RuleOf3_WithCopyAssignator();
my $mnemo_RuleOf3_WithCopyConstructor= Ident::Alias_RuleOf3_WithCopyConstructor();
my $mnemo_RuleOf3_WithDestructor = Ident::Alias_RuleOf3_WithDestructor();
my $mnemo_WhithoutPrivateDefaultConstructorUtilityClass = Ident::Alias_WhithoutPrivateDefaultConstructorUtilityClass();
my $mnemo_IllegalOperatorOverload = Ident::Alias_IllegalOperatorOverload();
my $mnemo_CopyAssignableAbstractClass = Ident::Alias_CopyAssignableAbstractClass();
my $mnemo_ClassDefinitions = Ident::Alias_ClassDefinitions();
my $mnemo_StructDefinitions = Ident::Alias_StructDefinitions();
my $mnemo_PublicAttributes = Ident::Alias_PublicAttributes();
my $mnemo_PrivateAttributes = Ident::Alias_PrivateAttributes();
my $mnemo_ProtectedAttributes = Ident::Alias_ProtectedAttributes();


my $nb_WithoutVirtualDestructorAbstractClass = 0;
my $nb_NonPrivateDataMember = 0;
my $nb_RuleOf3_WithCopyAssignator = 0;
my $nb_RuleOf3_WithCopyConstructor = 0;
my $nb_RuleOf3_WithDestructor = 0;
my $nb_WhithoutPrivateDefaultConstructorUtilityClass = 0;
my $nb_IllegalOperatorOverload = 0;
my $nb_CopyAssignableAbstractClass = 0;
my $nb_ClassDef = 0;
my $nb_StructDefinitions = 0;
my $nb_PublicAttributes = 0;
my $nb_ProtectedAttributes = 0;
my $nb_PrivateAttributes = 0;

# sub setObjectProperty($$$;$) {
  # my $r_Objects = shift;
  # my $ID = shift;
  # my $property = shift;
  # my $value = shift;

  # if ( ! defined $value) {
    # $value = 1;
  # }

  # if (! exists $r_Objects->{$ID}) {
    # my %empty = ();
    # $r_Objects->{$ID} = \%empty;
  # }
  # $r_Objects->{$ID}->{$property} = $value;
# }

###############################################################################################################""""

# HL-624 05/10/2018 Avoid too many classes definition
# HL-683 15/10/2018 Avoid abstract classes without virtual destructor
# HL-684 16/10/2018 Avoid abstract classes with copy assignment operator
# HL-685 25/10/2018 Avoid classes not implementing "rule of three"
# HL-686 29/10/2018 Avoid utility class without private default constructor
# HL-687 30/10/2018 Avoid illegal operator overload
sub CountClass($$$$) {
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_ClassDef = 0;
    $nb_StructDefinitions = 0;
    $nb_WithoutVirtualDestructorAbstractClass = 0;
    $nb_CopyAssignableAbstractClass = 0;
    $nb_RuleOf3_WithCopyAssignator = 0;
    $nb_RuleOf3_WithCopyConstructor = 0;
    $nb_RuleOf3_WithDestructor = 0;
    $nb_WhithoutPrivateDefaultConstructorUtilityClass = 0;
    $nb_IllegalOperatorOverload = 0;
    my $bool_abstract_class = 0;

    my $KindsLists = $vue->{'KindsLists'}||[];

    if ( ! defined $KindsLists )
	{
		$status |= Couples::counter_add($compteurs, $mnemo_ClassDefinitions, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_StructDefinitions, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_WithoutVirtualDestructorAbstractClass, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_CopyAssignableAbstractClass, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_RuleOf3_WithCopyAssignator, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_RuleOf3_WithCopyConstructor, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_RuleOf3_WithDestructor, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_WhithoutPrivateDefaultConstructorUtilityClass, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_IllegalOperatorOverload, Erreurs::COMPTEUR_ERREUR_VALUE );
    }  
    
    $nb_StructDefinitions = scalar @{$KindsLists->{&StructKind}};
    
    my $Classes = $KindsLists->{&ClassKind};
    my $bool_copy_constructor = 0;
    my $bool_assignment_operator = 0;
    my $bool_destructor = 0;
    my $node_destructor;
    
 	for my $ClassDef (@$Classes) 
    {
        my $nameClassDef = GetName ($ClassDef);
        print "+++++ Class definition $nameClassDef found\n" if $DEBUG;
        Erreurs::VIOLATION($mnemo_ClassDefinitions, "METRIC : Class definition $nameClassDef found");
        $nb_ClassDef++;

        my $children = GetChildren ($ClassDef);
        my $count_StaticMethod = 0;
        my $count_NonStaticMethod = 0;
        my $modifierDefaultConstructor;
        
        $bool_copy_constructor = 0;
        $bool_assignment_operator = 0;
        $bool_destructor = 0;
        $node_destructor = undef;
        
        for my $child (@$children)
        {
            ##########
            # METHODS AND METHOD PROTOTYPES
            ##########
            if ((IsKind($child, MethodKind)) or (IsKind($child, MethodPrototypeKind)))
            {
                my $Routine = $child;
                my $H_modifiers = getCppKindData($Routine, 'H_modifiers') || {};
                
                my $nameRoutine = GetName($Routine);
                print "+++++ Routine $nameRoutine found\n" if $DEBUG;
                
                # Destructor ? 
                #-------------
                if ($nameRoutine =~ /\~\s*$nameClassDef\b/)
                {
                    print "+++++ Destructor into class $nameClassDef found\n" if $DEBUG;
                    $bool_destructor = 1; 
                    $node_destructor = $Routine; 
                }

                # Constructor ? 
                #-------------
                elsif ($nameRoutine =~ /\b$nameClassDef\b/)
                {
					my $arguments = getCppKindData($Routine, 'arguments');
                    if ((defined $arguments) && (scalar @$arguments)) 
                    {
                        for my $arg (@$arguments)
                        {
                            # Copy constructor ?
                            if (defined $arg->{'type'} and $arg->{'type'} =~ /\b$nameClassDef\b/)
                            {
                                print "+++++ Copy constructor into class $nameClassDef found\n" if $DEBUG;
                                $bool_copy_constructor = 1;                            
                            }
                        }
                    }
                    # default constructor
                    else
                    {
                        $modifierDefaultConstructor = $H_modifiers;
                    }
                }
                
                # Assignment operator ? 
                #----------------------
                elsif ($nameRoutine =~ /\boperator\s*([^\w\s]+)/)
                {
                    my $sign = $1;
                    my $args = Lib::NodeUtil::GetKindData($Routine)->{'arguments'};
                    for my $arg (@$args) 
                    {
                        # COPY (!) assignment operator ?  
                        if ($arg->{'type'} =~ /\b$nameClassDef\&?/ and $sign eq '=')
                        {
                            print "+++++ Copy asssignment operator into class $nameClassDef found\n" if $DEBUG;
                            $bool_assignment_operator = 1; 
                            
                            # not PROTECTED nor PRIVATE nor =delete ?
                            # abstract class
                            if (	defined getCppKindData($ClassDef, "abstract")
								and (
									(getCppKindData($Routine, 'visibility') eq "public")
                               #      ! defined $H_modifiers->{'protected'}) 
                               # and (! defined $H_modifiers->{'private'}) 
									and (! defined getCppKindData($Routine, 'delete'))
							)) {
                                print "+++++ Copy assignment operator into abstract class $nameClassDef found\n" if $DEBUG;
                                Erreurs::VIOLATION($mnemo_CopyAssignableAbstractClass, "usable copy assignment operator into abstract class $nameClassDef");
                                $nb_CopyAssignableAbstractClass++;
                            }
                        }
                    }
                    if ($sign =~ /^(?: \&\& | \& | \|\| | \,)$/mx)
                    {
                        print "+++++ Illegal operator $sign overloading into class $nameClassDef found\n" if $DEBUG;
                        Erreurs::VIOLATION($mnemo_IllegalOperatorOverload, "Illegal operator $sign overloading into class $nameClassDef found");
                        $nb_IllegalOperatorOverload++;
                    }
                }
                # Other method ? 
                #----------------------
                else
                {
                    print "+++++ Other method $nameRoutine found\n" if $DEBUG;
					if ( defined $H_modifiers->{'static'} ) 
                    {
						$count_StaticMethod++;
					}
                    else
                    {
						$count_NonStaticMethod++;
                    }
                }                
            }
        }
        
        # Destructor ? 
        if (defined $node_destructor) {
			my $H_destructorModifiers = getCppKindData($node_destructor, 'H_modifiers') || {};

			# Abstract class + non virtual destructor ? 
			if (	defined getCppKindData($ClassDef, "abstract") and
					! defined $H_destructorModifiers->{'virtual'})
			{
				print "+++++ Missing virtual destructor into abstract class $nameClassDef\n" if $DEBUG;
				Erreurs::VIOLATION($mnemo_WithoutVirtualDestructorAbstractClass, "Virtual destructor into class $nameClassDef not found");
				$nb_WithoutVirtualDestructorAbstractClass++;                            
			}
		}
        
        
        # Rule of 3 failed
        my $nb_ruleOf3_required = $bool_assignment_operator + $bool_copy_constructor + $bool_destructor;
        # The rule is 3 required implemented or none.
        # 1 or 2 required implemented is symptomatic of a violation.
        if ( ($nb_ruleOf3_required == 1) or ($nb_ruleOf3_required == 2) ) {
			
			my @missing = grep defined, ( 	( $bool_assignment_operator==0 ? "assignment operator" : undef),
											( $bool_copy_constructor==0 ? "copy constructor" : undef),
											( $bool_destructor==0 ? "destructor" : undef)
										);
										
			Erreurs::VIOLATION($mnemo_RuleOf3_WithCopyAssignator, "RuleOf3 violation for class $nameClassDef (missing ". join(" and ", @missing) .")");
            
            $nb_RuleOf3_WithCopyAssignator += $bool_assignment_operator;
            $nb_RuleOf3_WithCopyConstructor += $bool_copy_constructor;
            $nb_RuleOf3_WithDestructor += $bool_destructor;
        }
        
        # Utility class  
        if ($count_StaticMethod >= 1 and $count_NonStaticMethod == 0)
        {
            print "+++++ Utility class $nameClassDef found\n" if $DEBUG;
            if (! defined $modifierDefaultConstructor->{'private'} ) 
            {
                print "+++++ Utility class $nameClassDef found without private default constructor\n" if $DEBUG;
                Erreurs::VIOLATION($mnemo_WhithoutPrivateDefaultConstructorUtilityClass, "Utility class $nameClassDef found without private default constructor");
                $nb_WhithoutPrivateDefaultConstructorUtilityClass++;
            }
        }
    }   
 
    $status |= Couples::counter_add ($compteurs, $mnemo_ClassDefinitions, $nb_ClassDef);
    $status |= Couples::counter_add ($compteurs, $mnemo_StructDefinitions, $nb_StructDefinitions);
    $status |= Couples::counter_add ($compteurs, $mnemo_WithoutVirtualDestructorAbstractClass, $nb_WithoutVirtualDestructorAbstractClass);
    $status |= Couples::counter_add ($compteurs, $mnemo_CopyAssignableAbstractClass, $nb_CopyAssignableAbstractClass);
    $status |= Couples::counter_add ($compteurs, $mnemo_RuleOf3_WithCopyAssignator, $nb_RuleOf3_WithCopyAssignator);
    $status |= Couples::counter_add ($compteurs, $mnemo_RuleOf3_WithCopyConstructor, $nb_RuleOf3_WithCopyConstructor);
    $status |= Couples::counter_add ($compteurs, $mnemo_RuleOf3_WithDestructor, $nb_RuleOf3_WithDestructor);
    $status |= Couples::counter_add ($compteurs, $mnemo_WhithoutPrivateDefaultConstructorUtilityClass, $nb_WhithoutPrivateDefaultConstructorUtilityClass);
    $status |= Couples::counter_add ($compteurs, $mnemo_IllegalOperatorOverload, $nb_IllegalOperatorOverload);
    
    return $status;
}

# HL-681 09/10/2018 Avoid non private data members
sub CountAttributes($$$$) {
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_NonPrivateDataMember = 0;
    $nb_PublicAttributes = 0;
	$nb_ProtectedAttributes = 0;
	$nb_PrivateAttributes = 0;

    my $KindsLists = $vue->{'KindsLists'}||[];

    if ( ! defined $KindsLists )
	{
		$status |= Couples::counter_add($compteurs, $mnemo_NonPrivateDataMember, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_PublicAttributes, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_PrivateAttributes, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_ProtectedAttributes, Erreurs::COMPTEUR_ERREUR_VALUE );
    }  
    
    my $Attributes = $KindsLists->{&AttributeKind};

    for my $Attribute (@$Attributes) 
    {
        my $nameAttribute = GetName ($Attribute);
      
		my $H_modifiers = getCppKindData($Attribute, 'H_modifiers') || {};
        
        # Do not consider "struct" (only classes) ...
        if (IsKind(GetParent($Attribute), ClassKind)) {
			#if (! defined $H_modifiers->{'private'} )
			my $visibility = getCppKindData($Attribute, 'visibility');
			if ($visibility eq 'public') {
				$nb_PublicAttributes++;
			}
			elsif ($visibility eq 'protected') {
				$nb_ProtectedAttributes++;
			}
			else {
				# private
				Erreurs::VIOLATION($mnemo_NonPrivateDataMember, "Non private attribute : $nameAttribute at line ".GetLine($Attribute));
				print "+++++ Non private attribute $nameAttribute at line ".GetLine($Attribute)."\n" if ($DEBUG);
				$nb_NonPrivateDataMember++;
				$nb_PrivateAttributes++;
			}
		}
    }   

    $status |= Couples::counter_add ($compteurs, $mnemo_NonPrivateDataMember, $nb_NonPrivateDataMember);
    $status |= Couples::counter_add ($compteurs, $mnemo_PublicAttributes, $nb_PublicAttributes);
    $status |= Couples::counter_add ($compteurs, $mnemo_ProtectedAttributes, $nb_ProtectedAttributes);
    $status |= Couples::counter_add ($compteurs, $mnemo_PrivateAttributes, $nb_PrivateAttributes);
    return $status;
}

1;
