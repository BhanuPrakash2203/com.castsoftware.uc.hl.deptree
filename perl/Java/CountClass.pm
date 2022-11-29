package Java::CountClass;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Java::JavaNode;
use Java::CountNaming;


my $ShortClassNamesLT__mnemo = Ident::Alias_ShortClassNamesLT();
my $BadClassNames__mnemo = Ident::Alias_BadClassNames();
my $ShortAttributeNamesLT__mnemo = Ident::Alias_ShortAttributeNamesLT();
my $BadAttributeNames__mnemo = Ident::Alias_BadAttributeNames();
my $ClassImplementations__mnemo = Ident::Alias_ClassImplementations();
my $ClassDefinitions__mnemo = Ident::Alias_ClassDefinitions();
my $PrivateProtectedAttributes__mnemo = Ident::Alias_PrivateProtectedAttributes();
my $PublicAttributes__mnemo = Ident::Alias_PublicAttributes();
my $InterfaceDefinitions__mnemo = Ident::Alias_InterfaceDefinitions();
my $TotalAttributes__mnemo = Ident::Alias_TotalAttributes();
my $EmptyClasses__mnemo = Ident::Alias_EmptyClasses();
my $UnexpectedAbstractClass__mnemo = Ident::Alias_UnexpectedAbstractClass();
my $ProtectedMemberInFinalClass__mnemo = Ident::Alias_ProtectedMemberInFinalClass();
my $PublicConstructorInUtilityClass__mnemo = Ident::Alias_PublicConstructorInUtilityClass();
my $MagicNumbers__mnemo = Ident::Alias_MagicNumbers();
my $OctalLiteralValues__mnemo = Ident::Alias_OctalLiteralValues();
my $LCLiteralSuffixes__mnemo = Ident::Alias_LCLiteralSuffixes();
my $BadDeclarationOrder__mnemo = Ident::Alias_BadDeclarationOrder();
my $MissingHashcode__mnemo = Ident::Alias_MissingHashcode();


my $nb_ShortClassNamesLT = 0;
my $nb_BadClassNames = 0;
my $nb_ShortAttributeNamesLT = 0;
my $nb_BadAttributeNames = 0;
my $nb_ClassImplementations = 0;
my $nb_ClassDefinitions = 0;
my $nb_PrivateProtectedAttributes = 0;
my $nb_PublicAttributes = 0;
my $nb_InterfaceDefinitions = 0;
my $nb_TotalAttributes = 0;
my $nb_EmptyClasses = 0;
my $nb_UnexpectedAbstractClass = 0;
my $nb_ProtectedMemberInFinalClass = 0;
my $nb_PublicConstructorInUtilityClass = 0;
my $nb_MagicNumbers = 0;
my $nb_OctalLiteralValues = 0;
my $nb_LCLiteralSuffixes = 0;
my $nb_BadDeclarationOrder = 0;
my $nb_MissingHashcode = 0;

sub CountClass($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
    
	my $ret = 0;
    $nb_ShortClassNamesLT = 0;
    $nb_BadClassNames = 0;
    $nb_ClassImplementations = 0;
    $nb_EmptyClasses = 0;
    $nb_UnexpectedAbstractClass = 0;
    $nb_PublicConstructorInUtilityClass = 0;
    $nb_ProtectedMemberInFinalClass = 0;
    $nb_BadDeclarationOrder = 0;
    $nb_MissingHashcode = 0;
    
    my $KindsLists = $vue->{'KindsLists'};

	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $ShortClassNamesLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadClassNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ClassImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ClassDefinitions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $EmptyClasses__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $UnexpectedAbstractClass__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $PublicConstructorInUtilityClass__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $ProtectedMemberInFinalClass__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadDeclarationOrder__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $classes = $KindsLists->{&ClassKind};
	for my $class (@$classes) 
    {
		my $className = GetName($class);
        
		if (! Java::CountNaming::checkClassName($className)) {
			$nb_BadClassNames++;
			Erreurs::VIOLATION($BadClassNames__mnemo, "Bad class name ($className) at line ".GetLine($class));
		}
		
		if (! Java::CountNaming::checkClassNameLength($className)) {
			$nb_ShortClassNamesLT++;
			Erreurs::VIOLATION($ShortClassNamesLT__mnemo, "Class name ($className) is too short at line ".GetLine($class));
		}
        
        # 18/01/2018 HL-430 METRIC : total number of classes implementation
        $nb_ClassImplementations++;
        
        # 24/01/2018 HL-439 : Avoid empty classes
        my $members = GetChildren($class);

        if (scalar @$members == 0)
        {
            # Class is empty
            # print '+++++++++'."empty class => $className\n";
            $nb_EmptyClasses++;
 			Erreurs::VIOLATION($EmptyClasses__mnemo, "Class name ($className) is empty at line ".GetLine($class));
        }
       
       # 25/01/2018 HL-440 : Avoid abstract classes without abstract or concrete methods
        my $H_modifiers = getJavaKindData($class, 'H_modifiers') || {};

        my $bool_astract_method = 0;
        my $bool_concrete_method = 0;
        my $bool_abstract_class = defined $H_modifiers->{'abstract'};
        my $bool_final_class = defined $H_modifiers->{'final'};
        
        my $nb_methods_static  = 0;
        my $nb_methods_non_static  = 0;
        my $nb_private_constructor = 0;
        my $nb_non_private_constructor = 0;
        my $string_violation;

       # 06/04/2018 HL-514 : Avoid bad declaration order (mnemonic BadDeclarationOrder)
       # declaration order inside a class should be :
       # pos 0  :   static variables      :       (SV)
       # pos 1  :   non-static variables  :       (V)
       # pos 2  :   constructors          :       (C)
       # pos 3  :   static methods        :       (SM)
       # pos 4  :   non-static methods    :       (M)
 
        my $rank_member=0;
        my %rank_member_class;
        my %name_element;
        my $bool_override_equals_method=0;
        my $bool_hashCode_method=0;
        
        foreach my $member (@{$members})
        {
            # print '++++ class '. $className . ' position=' . $rank_member .' & name=' . GetName($member) ."\n";
            $name_element{$rank_member} = GetName($member);
            
            if ( IsKind($member, MethodKind) ) 
            {
                #-------------------------------------------------
                # -------- MEMBER IS A METHOD --------------------
                #-------------------------------------------------
                my $method = $member;
                my $methodName = GetName($method);
                
                my $H_modifiers_meth = getJavaKindData($member, 'H_modifiers') || {};

				if ($methodName eq $className) {
					# constructor ...
                    if (defined $H_modifiers_meth->{'private'}) {
						$nb_private_constructor++;
					}
					else {
						$nb_non_private_constructor++;
					}
                    
                    push( @{ $rank_member_class {'2_C'} }, $rank_member); 
				}
				else {
					# not a constructor ...
					if (defined $H_modifiers_meth->{'static'}) 
                    {
						$nb_methods_static++;
                        push( @{ $rank_member_class {'3_SM'} }, $rank_member); 
					}
					else 
                    {
						$nb_methods_non_static++;
                        push( @{ $rank_member_class {'4_M'} }, $rank_member); 
                    }
                    
                    # 09/04/2018 HL-515 DIAG : Avoid missing hashcode() override
                    if ($methodName eq 'equals') 
                    {
                        #$bool_override_equals_method = isOverrideMethod($method);                 
                        my $args = Lib::NodeUtil::GetKindData($method)->{'arguments'};
                        if (scalar @$args == 1) {
							if ($args->[0]->{'type'} eq 'Object') {
								$bool_override_equals_method = 1
							}
						}
                    }
                    elsif ($methodName eq 'hashCode') 
                    {
                        $bool_hashCode_method = 1;
                    }
				}

                if ($bool_abstract_class) {
                    #-------------- CLASS IS ABSTRACT ---------------------
                    last if ($bool_astract_method == 1 and $bool_concrete_method == 1);
                    
                    if (defined $H_modifiers_meth->{'abstract'})
                    {
                        $bool_astract_method = 1;
                        # print "+++++++++abstract method=".GetName($instruction)."\n";
                    }
                    else
                    {
                        $bool_concrete_method=1;
                        # print "+++++++++concrete method=".GetName($instruction)."\n";
                    }
                }
                
                elsif ($bool_final_class) 
                {
                    #-------------- CLASS IS FINAL ------------------------
                    # 29/01/2018 HL-441 Avoid protected member in final classes
                    if (defined $H_modifiers_meth->{'protected'})
                    {
                        # print '+++++++++'."method protected $MethodName detected \n";
                        $nb_ProtectedMemberInFinalClass++;
                        Erreurs::VIOLATION($ProtectedMemberInFinalClass__mnemo, "Final class $className with protected attribute(s) at line ".GetLine($method));                             
                    }
                }
            }
            else 
            {
                #-------------------------------------------------
                # -------- MEMBER IS AN ATTRIBUTE ----------------
                #-------------------------------------------------
                my $attribute = $member;
                my $H_modifiers_attr = getJavaKindData($member, 'H_modifiers') || {};
                
                # 29/01/2018 HL-441 Avoid protected member in final classes
                if ($bool_final_class) 
                {
                    #-------------- CLASS IS FINAL ------------------------
                    if (defined $H_modifiers_attr->{'protected'})
                    {
                        # print '+++++++++'."member protected $className detected \n";
                        $nb_ProtectedMemberInFinalClass++;
                        Erreurs::VIOLATION($ProtectedMemberInFinalClass__mnemo, "Final class $className with protected attribute(s) at line ".GetLine($attribute));                             
                    }
                }
                
                if (defined $H_modifiers_attr->{'static'})
                {
                    push( @{ $rank_member_class {'0_SV'} }, $rank_member); 
                }
                else
                {
                    push( @{ $rank_member_class {'1_V'} }, $rank_member);
                }
            }
            $rank_member++;
        }
        
        $nb_BadDeclarationOrder = Check_rank_member_class(\%rank_member_class, \%name_element, $className, GetLine($class));

        if ($bool_abstract_class == 1 and $bool_astract_method == 0 ) 
        {
            # print '+++++++++'."Abstract class $className without abstract method\n";
            $nb_UnexpectedAbstractClass++;
            Erreurs::VIOLATION($UnexpectedAbstractClass__mnemo, "Abstract class $className without abstract method at line ".GetLine($class));            
        }     
        elsif ($bool_abstract_class == 1 and $bool_concrete_method == 0 ) 
        {
            # print '+++++++++'."Abstract class $className without concrete method\n";
            $nb_UnexpectedAbstractClass++;
            Erreurs::VIOLATION($UnexpectedAbstractClass__mnemo, "Abstract class $className without concrete method at line ".GetLine($class));            
        }               
    
#        # 29/01/2018 HL-442 Avoid public constructors in utility classes
#        if ($bool_abstract_class == 0)
#        {
#            # print '+++++++++'."Non-abstract class $className detected\n";
#            my $nb_methods_static = 0;
#            my $nb_private_constructor = 0;
#            my $exit_scan = 0;
#            my $violation_constructor = 0;
#            
#            foreach my $member (@{$members})
#            {
#                if ( IsKind($member, MethodKind) ) 
#                {
#                    my $method = $member;
#                    
#                    my $H_modifiers = getJavaKindData($method, 'H_modifiers') || {};
#                    my $name_method = GetName ($method);
#                    
#                    if (defined $name_method)
#                    {
#                        if (defined $H_modifiers->{'static'})
#                        {
#                            $nb_methods_static++;
#                        }
#                        elsif ($name eq $name_method)
#                       {
#                            # print '+++++++++'."Constructor $name_method detected\n";
#                            if (defined $H_modifiers->{'private'})
#                            {
#                                $nb_private_constructor++;
#                            }
#                            else
#                            {
#                                $violation_constructor = 1;
#                            }
#                        }
#                        else
#                        {
#                            # Non-utility classes
#                            # print '+++++++++'."Non-utility class $name detected on method $name_method\n";
#                            $exit_scan = 1;
#                            last;
#                        }
#                    }
#                }
#            }
            
            # print '+++++++++'."All $nb_methods_static methods static scanned\n" if ($exit_scan == 0 and $nb_methods_static > 0);
            #print 'nb_methods_static='.$nb_methods_static."\n";
            #print 'nb_methods_non_static='.$nb_methods_non_static."\n";
            #print 'nb_private_constructor='.$nb_private_constructor."\n";
            #print 'nb_non_private_constructor='.$nb_non_private_constructor."\n";
            
            # if scan complete with only static(s) method(s) : utility class detected  
            # if utility class without private constructor => violation
			if (	(( $nb_methods_static > 0) && ( $nb_methods_non_static == 0))         # all methods are static (utility class)
					&&
					(($nb_private_constructor == 0) || ($nb_non_private_constructor > 0)) # not all constructor are private ...
				)
            {
                $nb_PublicConstructorInUtilityClass++;
                Erreurs::VIOLATION($PublicConstructorInUtilityClass__mnemo, "Utility class named ($className) has public constructor at line ".GetLine($class));
            }
            
            if ($bool_override_equals_method == 1 and $bool_hashCode_method == 0)
            {
                # print '++++ Method equals overidden detected but no hashCode '."\n";
                $nb_MissingHashcode++;
                Erreurs::VIOLATION($MissingHashcode__mnemo, "Equals() method overriden without hashCode() method at line " .GetLine($class));            
            }
#       }
	}
    
    my $interfaces = $KindsLists->{&InterfaceKind};
	for my $interface (@$interfaces) 
    {
		my $name = GetName($interface);
        
		if (! Java::CountNaming::checkClassName($name)) {
			$nb_BadClassNames++;
			Erreurs::VIOLATION($BadClassNames__mnemo, "Bad interface name ($name) at line ".GetLine($interface));
		}
		
		if (! Java::CountNaming::checkClassNameLength($name)) {
			$nb_ShortClassNamesLT++;
			Erreurs::VIOLATION($ShortClassNamesLT__mnemo, "Interface name ($name) is too short at line ".GetLine($interface));
		}
	}
	
	my $enums = $KindsLists->{&EnumKind};
	for my $enum (@$enums) 
    {
		my $name = GetName($enum);
        
		if (! Java::CountNaming::checkClassName($name)) {
			$nb_BadClassNames++;
			Erreurs::VIOLATION($BadClassNames__mnemo, "Bad enum name ($name) at line ".GetLine($enum));
		}
		
		if (! Java::CountNaming::checkClassNameLength($name)) {
			$nb_ShortClassNamesLT++;
			Erreurs::VIOLATION($ShortClassNamesLT__mnemo, "Enum name ($name) is too short at line ".GetLine($enum));
		}
	}

    $ret |= Couples::counter_add($compteurs, $ShortClassNamesLT__mnemo, $nb_ShortClassNamesLT );
    $ret |= Couples::counter_add($compteurs, $BadClassNames__mnemo, $nb_BadClassNames );
    $ret |= Couples::counter_add($compteurs, $EmptyClasses__mnemo, $nb_EmptyClasses );
    $ret |= Couples::counter_add($compteurs, $UnexpectedAbstractClass__mnemo, $nb_UnexpectedAbstractClass );
    $ret |= Couples::counter_add($compteurs, $PublicConstructorInUtilityClass__mnemo, $nb_PublicConstructorInUtilityClass );
    $ret |= Couples::counter_add($compteurs, $ProtectedMemberInFinalClass__mnemo, $nb_ProtectedMemberInFinalClass );
    $ret |= Couples::counter_add($compteurs, $BadDeclarationOrder__mnemo, $nb_BadDeclarationOrder );
    $ret |= Couples::counter_add($compteurs, $MissingHashcode__mnemo, $nb_MissingHashcode );
    
    # Old java parser was providing both "ClassImplementations" and "ClassDefinitions" mnemo
    # BUT : only "ClassDefinitions" is used in the model, so "ClassImplementations" is useless.
    #
    # For compatibility reason, new parser will provide both counters with the same value corresponding to
    # the number of classes contained inside the file.
    #
    # WARNING : New parser will not make any distinction between declaration and implementation of class.
    $ret |= Couples::counter_add($compteurs, $ClassImplementations__mnemo, $nb_ClassImplementations );
    $ret |= Couples::counter_add($compteurs, $ClassDefinitions__mnemo, $nb_ClassImplementations );
    return $ret;
}

sub CountAttribute($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
	my $ret = 0;
    $nb_ShortAttributeNamesLT = 0;
    $nb_BadAttributeNames = 0;
    $nb_PrivateProtectedAttributes = 0;
    $nb_PublicAttributes = 0;
    
    $nb_TotalAttributes = 0;
    $nb_MagicNumbers = 0;
    $nb_OctalLiteralValues = 0;
    $nb_LCLiteralSuffixes = 0;
    
	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $ShortAttributeNamesLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $BadAttributeNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $PrivateProtectedAttributes__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $PublicAttributes__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $TotalAttributes__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $attributes = $KindsLists->{&AttributeKind};

	for my $attr (@$attributes) 
    {
		my $name = GetName($attr);
		if (defined $name) {
            
			my $H_modifiers = getJavaKindData($attr, 'H_modifiers') || {};
			my $cb_checkAttributeName = \&Java::CountNaming::checkAttributeName;
		
			if ((defined $H_modifiers->{'final'}) && (defined $H_modifiers->{'static'})) {
				$cb_checkAttributeName = \&Java::CountNaming::checkFinalStaticAttributeName;
			}			
  
            # 22/01/2018 HL-426 METRIC : total number of private or protected attribute
            if ((defined $H_modifiers->{'private'}) || (defined $H_modifiers->{'protected'})) {
            # print '++++++attribute private or protected'."\n";
				$nb_PrivateProtectedAttributes++;
			}
			else {
				$nb_PublicAttributes++;
			}
            
			if (! $cb_checkAttributeName->($name)) {
				$nb_BadAttributeNames++;
				Erreurs::VIOLATION($BadAttributeNames__mnemo, "Bad attribute name ($name) at line ".GetLine($attr));
			}
		
			if (! Java::CountNaming::checkAttributeNameLength($name)) {
				$nb_ShortAttributeNamesLT++;
				Erreurs::VIOLATION($ShortAttributeNamesLT__mnemo, "Attribute name ($name) is too short at line ".GetLine($attr));
			}
            
            # 23/01/2018 HL-434 METRIC : total number of attributes
            # Class attributes (interfaces not included)
            my $parent = GetParent($attr);
            if ( IsKind($parent, ClassKind) ) 
            {
                $nb_TotalAttributes++;
            }
		}
		else {
			print "WARNING : unknow name for attribute at line ".GetLine($attr)."\n";
		}
	}
    
    # 02/02/2018 HL-449 DIAG : Avoid magic number
    my $view_code = $vue->{'code'};
	if ( ! defined $view_code )
	{
		$ret |= Couples::counter_add($compteurs, $MagicNumbers__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $OctalLiteralValues__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		$ret |= Couples::counter_add($compteurs, $LCLiteralSuffixes__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}    
    
    my $regexp_float_Decimal = qr/(?:\d+\.\d*|\d*\.\d+)/;
    my $regexp_Int_Decimal   = qr/\d+\b/;
    my $regexp_Hexadecimal   = qr/0x[0-9a-fA-F]+/;
    my $regexp_Exponential   = qr/(?:\d+\.\d*|\d*\.\d+|\d+)[eE+-]+\d+/;
        
    # Magic numbers detection
    while ( $view_code =~ /
    (?: (?: (?:	\b(final)\s+(?:\w+\s+)*[\w\.]+\s+\w+\s*\=\s*([+-])?  |
            	[\w)]\b\s*[+-]? |       # number preceded by identifier or closing parenth => DON'T capture operator because it's the binary  operator, not the unary ! 
            	[^\w)]([+-])?           # number NOT preceded by identifier or closing parenth => capture operator, because it is unary.
            )
			(
				$regexp_Exponential
				|$regexp_float_Decimal
				|$regexp_Hexadecimal
				|$regexp_Int_Decimal
            )
        )
        ([dDfFlL])?
    )
    /xgc)
    
    {
		my $sign = $2|| $3;
		$sign //= '';
		my $MagicNumber = $4;
		my $LiteralSuffix = $5;
#print "MAGIC = $sign $MagicNumber\n";
        #------------------------------------------------
        #----------- MAGIC NUMBER DETECTED --------------
        #------------------------------------------------
        
        # $1 is defined if the magic number is assigned to a "final" var.
        # if this means the magic is not assigned to a constant ...
        if (! defined $1 )
        {
            if ( ( $sign ne '-') and 
                 ($MagicNumber =~ /^\d$/ or ($MagicNumber =~ /\b\d+\b/ and ($MagicNumber == 0 or $MagicNumber == 1))) )
            {
                # Exceptions
                #print 'exception for '. $MagicNumber."\n";
            }
            else
            {
                $nb_MagicNumbers++;
#print "----> Violation\n";
                Erreurs::VIOLATION($MagicNumbers__mnemo, "Unauthorized magic number: $MagicNumber");
            }
        }
        
        # 06/02/2018 HL-450 DIAG : Avoid octal values
        if ($MagicNumber =~ /\b[+-]?0[0-7]+\b/)
        {
            $nb_OctalLiteralValues++;
            Erreurs::VIOLATION($OctalLiteralValues__mnemo, "Unauthorized octal values : $MagicNumber");
        }
        
        # 06/02/2018 HL-451 DIAG : Avoid lowercase suffix for numbers
        if (defined $LiteralSuffix and 
            (
            $LiteralSuffix eq 'd' 
            or $LiteralSuffix eq 'f' 
            or $LiteralSuffix eq 'l'
            )
        )
        {
            $nb_LCLiteralSuffixes++;
            Erreurs::VIOLATION($LCLiteralSuffixes__mnemo, "Unauthorized literal suffix in lowercase in the magic number : $MagicNumber");
        }
        
    }   
    
    $ret |= Couples::counter_add($compteurs, $ShortAttributeNamesLT__mnemo, $nb_ShortAttributeNamesLT );
    $ret |= Couples::counter_add($compteurs, $BadAttributeNames__mnemo, $nb_BadAttributeNames );
    $ret |= Couples::counter_add($compteurs, $PrivateProtectedAttributes__mnemo, $nb_PrivateProtectedAttributes );
    $ret |= Couples::counter_add($compteurs, $PublicAttributes__mnemo, $nb_PublicAttributes );
    $ret |= Couples::counter_add($compteurs, $TotalAttributes__mnemo, $nb_TotalAttributes );
    $ret |= Couples::counter_add($compteurs, $MagicNumbers__mnemo, $nb_MagicNumbers );
    $ret |= Couples::counter_add($compteurs, $OctalLiteralValues__mnemo, $nb_OctalLiteralValues );
    $ret |= Couples::counter_add($compteurs, $LCLiteralSuffixes__mnemo, $nb_LCLiteralSuffixes );
    return $ret;
}

sub CountInterface($$$) 
{
	my ($file, $vue, $compteurs) = @_ ;
    
	my $ret = 0;
    # 23/01/2018 HL-427 METRIC : total number of interface declaration
    $nb_InterfaceDefinitions = 0;
    
	my $KindsLists = $vue->{'KindsLists'};
  
	if ( ! defined $KindsLists )
	{
		$ret |= Couples::counter_add($compteurs, $InterfaceDefinitions__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
  
	my $interfaces = $KindsLists->{&InterfaceKind};

    for my $interface (@$interfaces) 
    {
		my $name = GetName($interface);
        # print '++++++++++name='.$name."\n";
        $nb_InterfaceDefinitions++ if (defined $name);
    }
    
    $ret |= Couples::counter_add($compteurs, $InterfaceDefinitions__mnemo, $nb_InterfaceDefinitions );
    return $ret;
}
    
    
sub Check_rank_member_class
{
    my $ref_rank_member_class = shift;
    my $ref_name_element = shift;
    my $className = shift;
    my $lineClass = shift;
    
    my $rank_previous_element;
    my $element_kind;
    my $previous_element_kind;
    my $first_pass=0;
    my $nb_BadDeclarationOrder=0;
    my $string_violation;
    
    for my $member_class ( sort keys %{$ref_rank_member_class} ) {
		
		$element_kind = 'static variable' if ($member_class eq '0_SV');
		$element_kind = 'non-static variable' if ($member_class eq '1_V');
		$element_kind = 'constructor' if ($member_class eq '2_C');
		$element_kind = 'static method' if ($member_class eq '3_SM');
		$element_kind = 'non-static method' if ($member_class eq '4_M');
		
        for my $nb_elt ( 0 .. $#{ $ref_rank_member_class->{$member_class} } ) 
        {         
            # print "$element_kind: ";
            # print " elt=$nb_elt position inside class $ref_rank_member_class->{$member_class}[$nb_elt]\n";
            
            $previous_element_kind = $element_kind if ($first_pass == 0);
            
            # print "Compare $rank_previous_element > $ref_rank_member_class->{$member_class}[$nb_elt]\n" if ($rank_previous_element);
            
            if ($rank_previous_element and $rank_previous_element > $ref_rank_member_class->{$member_class}[$nb_elt])
            {
				# a greater rank means the member is declared after members having lower rank. So, because members are ordered by type priority, previous element should not have a greater rank
				# than the following. This would reveal a bad declaration order. 
                $nb_BadDeclarationOrder++;
                Erreurs::VIOLATION(	$BadDeclarationOrder__mnemo, 
									"Bad declaration order for class $className: ".
									"$element_kind <".($ref_name_element->{$ref_rank_member_class->{$member_class}[$nb_elt]} || "undef").
									"> before $previous_element_kind <".($ref_name_element->{$rank_previous_element} || "undef").
									#"> after $element_kind <".($ref_name_element->{$ref_rank_member_class->{$member_class}[$nb_elt]} || "undef").
									"> at line $lineClass");
                # print "Bad declaration order for class $className: misplaced $previous_element_kind <$ref_name_element->{$rank_previous_element}> at line $lineClass\n";
            }

            $previous_element_kind = $element_kind;
            $rank_previous_element = $ref_rank_member_class->{$member_class}[$nb_elt];
            $first_pass = 1;
        }
    }
    
    # return ($nb_BadDeclarationOrder, $string_violation);
    return $nb_BadDeclarationOrder;
}    

sub isOverrideMethod($)
{
    my $method = shift;
    
    my $previousOverrideAnnotation = Lib::Node::GetPreviousSibling($method);
    while (	($previousOverrideAnnotation) and 
            (IsKind ($previousOverrideAnnotation, AnnotationKind)) and 
            (GetName ($previousOverrideAnnotation) ne 'Override') )
    {
        $previousOverrideAnnotation = Lib::Node::GetPreviousSibling ($previousOverrideAnnotation);
    }

    if ($previousOverrideAnnotation)
    {
        # print "++++ Method ".GetName($method)." is overridden\n";
        return 1; # method is overridden
    }
    
    return 0;
}
    
1;
