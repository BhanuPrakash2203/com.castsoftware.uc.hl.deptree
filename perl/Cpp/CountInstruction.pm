
package Cpp::CountInstruction;

use strict;
use warnings;

use Erreurs;
use Cpp::ParserIdents;
use Lib::Node;
use Lib::NodeUtil;
use Cpp::CppNode;

my $DEBUG = 0;

my $mnemo_MisplacedInclude                = Ident::Alias_MisplacedInclude();
my $mnemo_MisplacedDefine                 = Ident::Alias_MisplacedDefine();
my $mnemo_Undef                           = Ident::Alias_Undef();
my $mnemo_ImplementationDefinedLibraryUse = Ident::Alias_ImplementationDefinedLibraryUse();
my $mnemo_OnError                         = Ident::Alias_OnError();

my $nb_MisplacedInclude     = 0;
my $nb_MisplacedDefine      = 0;
my $nb_Undef                = 0;
my $nb_ImplementationDefinedLibraryUse   = 0;
my $nb_OnError              = 0;

# HL-764 05/02/2019 Avoid code before #include directive
# HL-767 06/02/2019 Avoid macro definition in namespaces
# HL-768 11/02/2019 Avoid using #undef
# HL-770 11/02/2019 Avoid using <cstdio> library
# HL-771 13/02/2019 Avoid using "errno"
sub CountInstruction($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $status = 0;
    $nb_MisplacedInclude    = 0;
    $nb_MisplacedDefine     = 0;
    $nb_Undef               = 0;
    $nb_ImplementationDefinedLibraryUse  = 0;
    $nb_OnError             = 0;
    
    my $codeView = \$vue->{'code_with_prepro'};

  	if ( ! defined $codeView )
	{
		$status |= Couples::counter_add($compteurs, $mnemo_MisplacedInclude, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_MisplacedDefine, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_Undef, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_ImplementationDefinedLibraryUse, Erreurs::COMPTEUR_ERREUR_VALUE );
		$status |= Couples::counter_add($compteurs, $mnemo_OnError, Erreurs::COMPTEUR_ERREUR_VALUE );
    }
    
    my $bool_previous_line_code = 0;
    my $numline_view = 1;
    my $numline_previous_line_code;
    my $ScopeLevel = 0;
  
    my $regCommand = qr/include|define|undef/;
 
    while ($$codeView =~ /
        (\n)                                            # newLine
        |([\{\}]+)                                      # newBrace to delimit namespaces
        |^\s*\#\s*($regCommand)\s*(?:\<|\")?(\w+)?      # preproDirective listed in $regCommand
        |(^\s*[^\#\}])                                  # preproElement
        |[^\n\#\{\}]                                    # codeLine
        /xmg)
    {
        my $newLine         = $1;
        my $newBrace        = $2;
        my $preproDirective = $3;
        my $preproElement   = $4;
        my $codeLine        = $5;
        
        # preprocessor directives
        if (defined $preproDirective)
        {
            if ($preproDirective eq "include" )
            {
                if ($bool_previous_line_code == 1)
                {
                    Erreurs::VIOLATION($mnemo_MisplacedInclude, "Code command before #include directive at line $numline_previous_line_code");
                    print "Code command before #include directive at line $numline_previous_line_code [$numline_view]\n" if ($DEBUG);
                    $nb_MisplacedInclude++;
                    
                    # initialize
                    $bool_previous_line_code = 0;
                    $numline_previous_line_code = 0;
                }
                
                if (defined $preproElement)
                {
                    if ($preproElement =~ /^(CHAINE\_[0-9]+)/m)
                    {
                        if (defined $1)
                        {
                            # string treatment
                            my $Hstrings = $vue->{'HString'};

                            if ( ! defined $Hstrings)
                            {
                                $status |= Couples::counter_add($compteurs, $mnemo_ImplementationDefinedLibraryUse, Erreurs::COMPTEUR_ERREUR_VALUE );
                            }    

                            if ($Hstrings->{$1} eq "\"cstdio\"" or $Hstrings->{$1} eq "\"csignal\"")
                            {
                                $preproElement = $Hstrings->{$1};
                                $preproElement =~ s/\"//mg;
                            }
                        }
                    }
                    if ($preproElement eq "cstdio" or $preproElement eq "csignal")
                    {
                        Erreurs::VIOLATION($mnemo_ImplementationDefinedLibraryUse, "Defined library \<$preproElement\> used at line $numline_view");
                        print "Defined library \<$preproElement\> used at line $numline_view\n" if ($DEBUG);
                        $nb_ImplementationDefinedLibraryUse++;  
                    }
                    elsif ($preproElement eq "cerrno")
                    {
                        Erreurs::VIOLATION($mnemo_OnError, "Defined library \<$preproElement\> used at line $numline_view");
                        print "Defined library \<$preproElement\> used at line $numline_view\n" if ($DEBUG);
                        $nb_OnError++;  
                    }
                }
            }

            elsif ($preproDirective eq "define" and $ScopeLevel != 0)
            {
                Erreurs::VIOLATION($mnemo_MisplacedDefine, "Macro definition in namespace at line $numline_view");
                print "Macro definition in namespace at line $numline_view\n" if ($DEBUG);
                $nb_MisplacedDefine++;
            }

            elsif ($preproDirective eq "undef")
            {
                Erreurs::VIOLATION($mnemo_Undef, "Using preprocessor directive #undef at line $numline_view");
                print "Using preprocessor directive #undef at line $numline_view\n" if ($DEBUG);
                $nb_Undef++;

                if ($ScopeLevel != 0)
                {
                    Erreurs::VIOLATION($mnemo_MisplacedDefine, "Macro definition in namespace at line $numline_view");
                    print "Macro definition in namespace at line $numline_view\n" if ($DEBUG);
                    $nb_MisplacedDefine++;          
                }
            }
        }
        # code line
        elsif (defined $codeLine)
        {
            $bool_previous_line_code = 1;
            $numline_previous_line_code = $numline_view;
        }
        elsif (defined $newBrace )
        {
            $ScopeLevel++ if ($newBrace eq '{');
            $ScopeLevel-- if ($newBrace eq '}');
        }
        elsif (defined $newLine)
        {   $numline_view++; }
    }

    $status |= Couples::counter_add ($compteurs, $mnemo_MisplacedInclude, $nb_MisplacedInclude);
    $status |= Couples::counter_add ($compteurs, $mnemo_MisplacedDefine, $nb_MisplacedDefine);
    $status |= Couples::counter_add ($compteurs, $mnemo_Undef, $nb_Undef);
    $status |= Couples::counter_add ($compteurs, $mnemo_ImplementationDefinedLibraryUse, $nb_ImplementationDefinedLibraryUse);
    $status |= Couples::counter_add ($compteurs, $mnemo_OnError, $nb_OnError);
    return $status;
}

1;
