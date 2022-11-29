package Cpp::CountNaming;

use strict;
use warnings;

use Erreurs;
use Cpp::ParserIdents;
use Lib::NodeUtil;
use Cpp::CppNode;

use constant LIMIT_SHORT_ATTRIBUTE_NAMES_LT => 6;
use constant LIMIT_SHORT_CLASS_NAMES_LT => 10;
use constant LIMIT_SHORT_METHOD_NAMES_LT => 7;

my $DEBUG = 0;
my $mnemo_ShortAttributeNamesLT = Ident::Alias_ShortAttributeNamesLT();
my $mnemo_ShortClassNamesLT = Ident::Alias_ShortClassNamesLT();
my $mnemo_ShortMethodNamesLT = Ident::Alias_ShortMethodNamesLT();
my $mnemo_BadAttributeNames = Ident::Alias_BadAttributeNames();
my $mnemo_BadClassNames = Ident::Alias_BadClassNames();
my $mnemo_BadMethodNames = Ident::Alias_BadMethodNames();

my $nb_ShortAttributeNamesLT = 0;
my $nb_ShortClassNamesLT = 0;
my $nb_ShortMethodNamesLT = 0;
my $nb_BadAttributeNames = 0;
my $nb_BadClassNames = 0;
my $nb_BadMethodNames = 0;


# HL-618 01/10/2018 C++ DIAG : Avoid short attributes names
# HL-621 02/10/2018 C++ DIAG : Avoid bad attributes names
sub CountAttributeName($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_ShortAttributeNamesLT = 0;
    $nb_BadAttributeNames = 0;

    my $KindsLists = $vue->{'KindsLists'}||[];
    
  	if ( ! defined $KindsLists )
	{
		$status |= Couples::counter_add($compteurs, $mnemo_ShortAttributeNamesLT, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_BadAttributeNames, Erreurs::COMPTEUR_ERREUR_VALUE );
    }    
    
    my $Attributes = $KindsLists->{&AttributeKind};

	for my $Attribute (@$Attributes) 
    {
        my $nameAttribute = GetName ($Attribute);
        
        if (length($nameAttribute) < LIMIT_SHORT_ATTRIBUTE_NAMES_LT) 
        {
            print "+++++ Too short name attribute $nameAttribute found\n" if $DEBUG;
            Erreurs::VIOLATION($mnemo_ShortAttributeNamesLT, "Attribute name $nameAttribute is too short");
            $nb_ShortAttributeNamesLT++;
        }
        
        my $pattern_good_attribute_names_var = qr/^m?_[a-z]+([A-Z][a-z]+)*$/m;

        if ( $nameAttribute !~ /$pattern_good_attribute_names_var/)
        {
            print "+++++ Bad attribute name $nameAttribute found\n" if $DEBUG;
            Erreurs::VIOLATION($mnemo_BadAttributeNames, "Bad attribute name : $nameAttribute");
            $nb_BadAttributeNames++;
        }
    }

    $status |= Couples::counter_add ($compteurs, $mnemo_ShortAttributeNamesLT, $nb_ShortAttributeNamesLT);
    $status |= Couples::counter_add ($compteurs, $mnemo_BadAttributeNames, $nb_BadAttributeNames);
    return $status;
}

# HL-619 01/10/2018 C++ DIAG : Avoid short classes names
# HL-622 03/10/2018 C++ DIAG : Avoid bad classes names
sub CountClassName 
{

    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_ShortClassNamesLT = 0;
    $nb_BadClassNames = 0;

    my $KindsLists = $vue->{'KindsLists'}||[];

  	if ( ! defined $KindsLists )
	{
		$status |= Couples::counter_add($compteurs, $mnemo_ShortClassNamesLT, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_BadClassNames, Erreurs::COMPTEUR_ERREUR_VALUE );
    }    
    
    my $Classes = $KindsLists->{&ClassKind};

 	for my $Class (@$Classes) 
    {
        my $nameClass = GetName ($Class);
        
        if (length($nameClass) < LIMIT_SHORT_CLASS_NAMES_LT) 
        {
            print "+++++ Too short name class $nameClass found\n" if $DEBUG;
            Erreurs::VIOLATION($mnemo_ShortClassNamesLT, "Class name $nameClass is too short");
            $nb_ShortClassNamesLT++;
        }
        
        my $pattern_good_class_names = qr/^([A-Z][a-z]*)?([A-Z][a-z]+)+$/m;

        if ( $nameClass !~ /$pattern_good_class_names/)
        {
            print "+++++ Bad class name $nameClass found\n" if $DEBUG;
            Erreurs::VIOLATION($mnemo_BadClassNames, "Bad class name $nameClass");
            $nb_BadClassNames++;
        }        
    }   
 
    $status |= Couples::counter_add ($compteurs, $mnemo_ShortClassNamesLT, $nb_ShortClassNamesLT);
    $status |= Couples::counter_add ($compteurs, $mnemo_BadClassNames, $nb_BadClassNames);
    return $status;
}

# HL-620 02/10/2018 C++ DIAG : Avoid short methods names
# HL-623 03/10/2018 C++ DIAG : Avoid bad methods names
sub CountMethodName
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_ShortMethodNamesLT = 0;
    $nb_BadMethodNames = 0;

    my $KindsLists = $vue->{'KindsLists'}||[];

  	if ( ! defined $KindsLists )
	{
		$status |= Couples::counter_add($compteurs, $mnemo_ShortMethodNamesLT, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_BadMethodNames, Erreurs::COMPTEUR_ERREUR_VALUE );
    }    
    
    my $Methods = $KindsLists->{&MethodKind} || [];
    my $MPrototypes = $KindsLists->{&MethodPrototypeKind} || [];
    
    my %H_names = ();
    
    my $MethodPrototypes = [ @$Methods, @$MPrototypes ];
    #-----------------#
    # METHODS + PROTO #
    #-----------------#
 	for my $Method (@$MethodPrototypes) 
    {    
        my $nameMethod = GetName ($Method);
        
        if (	(length($nameMethod) < LIMIT_SHORT_METHOD_NAMES_LT) &&
				(! exists $H_names{$nameMethod}))
        {
            print "+++++ Too short name method $nameMethod found\n" if $DEBUG;
            Erreurs::VIOLATION($mnemo_ShortMethodNamesLT, "Method name $nameMethod is too short");
            $nb_ShortMethodNamesLT++;
        }
        
        $H_names{$nameMethod} = 1;

        #----------------#
        #     METHODS    #
        #----------------#
        if (IsKind($Method, MethodKind))
        {        
            my $pattern_good_method_names = qr/^([a-z]+([A-Z][a-z]+)*)?$/;

            if ( $nameMethod !~ /$pattern_good_method_names/
            and $nameMethod !~ /^\~\w+$/m        # exception for destructors
            and $nameMethod !~ /\boperator[^\w]/ # exception for operator overloading
            )
            {
                print "+++++ Bad method name $nameMethod found\n" if $DEBUG;
                Erreurs::VIOLATION($mnemo_BadMethodNames, "Bad method name $nameMethod");
                $nb_BadMethodNames++;
            }  
        }
    }
 
    $status |= Couples::counter_add ($compteurs, $mnemo_ShortMethodNamesLT, $nb_ShortMethodNamesLT);
    $status |= Couples::counter_add ($compteurs, $mnemo_BadMethodNames, $nb_BadMethodNames);
    return $status;
}

1;
