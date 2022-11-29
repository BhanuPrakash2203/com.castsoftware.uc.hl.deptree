#----------------------------------------------------------------------#
#                 @ISOSCOPE 2008                                       #
#----------------------------------------------------------------------#
#       Auteur  : ISOSCOPE SA                                          #
#       Adresse : TERSUD - Bat A                                       #
#                 5, AVENUE MARCEL DASSAULT                            #
#                 31500  TOULOUSE                                      #
#       SIRET   : 410 630 164 00037                                    #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Plugin
#----------------------------------------------------------------------#
# Description: Composant pour fonctions/methodes/attributs en C++
#----------------------------------------------------------------------#

package CountC_CPP_FunctionsMethodsAttributes;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use TraceDetect;
use List::Util qw(max);
use Timing;                                                 # timing_filter_line
use CppKinds;

# prototypes publics
sub Parse($$$$);

sub Count_ClassNaming($$$$);                # bt_filter_line
sub Count_AttributeNaming($$$$);            # bt_filter_line
sub Count_MethodNaming($$$$);               # bt_filter_line
sub Count_FunctionNaming($$$$);             # bt_filter_line
sub Count_OperatorsParamNotAsConstRef($$$$);
sub Count_ForbiddenOverloadedOperators($$$$);
sub Count_ForbiddenReferenceReturningOperators($$$$);
sub Count_Parameters($$$$);                 # bt_filter_line
sub Count_VarArg($$$$);
sub Count_ParametersObjects($$$$);
sub Count_BadDeclarationOrder($$$$);        # bt_filter_line
sub Count_Inheritances($$$$);
sub Count_ClassesStructs($$$$);
sub Count_Attributes($$$$);
sub Count_AppGlobalVar($$$$);
sub Count_FileGlobalVar($$$$);              # bt_filter_line
sub Count_DefinitionsInH($$$$);
sub Count_MultipleDeclarationSameLine($$$$);
sub Count_BadDynamicClassDef($$$$);
sub Count_Cpp_Methods($$$$);
sub Count_C_Functions($$$$);
sub Count_Friends($$$$);
sub Count_MissingDtor($$$$);
sub Count_MissingCtor($$$$);
sub Count_InlineMethods($$$$);
sub Count_ComplexMethods($$$$);
sub Count_MultipleReturnFunctionsMethods($$$$);
sub Count_AssignmentsInFunctionCall($$$$);
sub Count_DestructorsWithThrow($$$$);
sub Count_AssignmentOperatorsWithoutAutoAssignmentTest($$$$);
sub Count_AssignmentOperatorsWithoutReturningStarThis($$$$);
sub Count_GlobalDefinition($$$$);
#sub Count_PoorlyCommentedMethods($$$$);

# prototype prive
sub ParseVariableFullLine($$$$);

# declaration globale au module
use constant LISTE_TYPE_NON_OBJET =>  '... void char short int long float double bool SW_INT8 SW_UINT8 SW_INT16 SW_UINT16 SW_INT32 SW_UINT32 SW_INT64 SW_UINT64 SW_FLOAT SW_DOUBLE SW_BOOLEAN'; # espace initial et final est un separateur


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# DESCRIPTION: LE MODULE PARSE C++ (point d'entree)
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
sub CountFunctionsMethodsAttributesParse($$$$$);
sub CountFunctionsMethodsAttributesClean($$$$);
sub ExtractFunctionsMethodsCode($$$$);
sub Parse($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;

    #  analyse
    my $parseTiming = new Timing ('Parse', Timing->isSelectedTiming ('Parse') ); # timing_filter_line

    my ($status, $code) = CountFunctionsMethodsAttributesClean ($fichier, $vue, $compteurs, $options);

    $parseTiming->markTime ('CountFunctionsMethodsAttributesClean');             # timing_filter_line

    $status |= CountFunctionsMethodsAttributesParse ($fichier, $vue, $compteurs, $options, $code);

    $parseTiming->markTime ('CountFunctionsMethodsAttributesParse');             # timing_filter_line

    $status |= ExtractFunctionsMethodsCode ($fichier, $vue, $compteurs, $options);

    $parseTiming->markTime ('ExtractFunctionsMethodsCode');                      # timing_filter_line

    $parseTiming->dump ('Parse');                                                # timing_filter_line

    return $status;
}

my $second = 0;

# variables globales pour gerer la compatibilite entre la vue 'comment' et celle dont le nom est contenu dans $code_only_base.
my $code_only_base = 'code';

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# DESCRIPTION: LE MODULE CLEAN C++
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
sub CountFunctionsMethodsAttributesClean($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;

    my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0); # traces_filter_line
    my $b_TraceIn = ((exists $options->{'--TraceIn'})? 1 : 0);                  # traces_filter_line
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0);          # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);                  # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                           # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                             # traces_filter_line
    my $debug = 0;                                                              # traces_filter_line
    my $status = 0;

    if (not defined $vue->{'code'})
    {
        assert (defined $vue->{'code'}) if ($b_assert); # traces_filter_line
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $step = 0;

    my $code;

    if ((not exists $vue->{'prepro'}) || (not defined $vue->{'prepro'}))
    {
        $code = $vue->{'code'}; # code
        $code_only_base = 'code';
    }
    else
    {
        $code = $vue->{'prepro'}; # code
        $code_only_base = 'prepro';
    }

    my $outputFile = $fichier . ".methods_impl_outB" . $step if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    TraceDetect::TraceOutToFile ($outputFile, $code) if ($b_TraceDetect && $b_TraceIn);            # traces_filter_line

    my $filteredCode = $code; # code filtre
    my $statementsOnly = $code;

    $step++;

    print STDERR "#STEP:$step\n"  if ($debug); # traces_filter_line
    #############################################
    # ne garde que les declarations et definitions


    # effacer les sections de code cad {...} sauf accolades
    # pour ne pas matcher les appels de fonctions
    # dans le code comme :
    # {  int z = add(c1, c2) + add (c1, c2); }
    my @match_pos_start1;
    my @erased;
    my $stackSizeError = 0;
    while ($code =~ m{
                    (<\s*\bclass\b.*?>) #1
                    | (\b(class|struct|enum|namespace|union)\b.*?([\{;\)])) #2 #3 #4
                    | (\{|\})                   #5
                }gxms)
    {
        my $templateParameters = $1;
        my $declarationHeader = $2;
        my $declarationHeaderEnd = $4;
        my $accolade = $5;

        if (defined $templateParameters)
        {
            # filtre les templates cad <class T, class W>  comme:
            # template <class T, class W> class CAVector: public std::vector<T> {};

            print "templateParameters$templateParameters\n" if ($debug); # traces_filter_line

            next;
        }

        if (defined $declarationHeader)
        {
            # filtre implicitement les forward declaration
            # les parametres de type struct
            # les templates

            print "declarationHeader:$declarationHeader\n"  if ($debug); # traces_filter_line

            if ($declarationHeaderEnd eq '{')
            {
                if (not $declarationHeader =~ /\bstruct\b.*=/)
                {
                    # cas standards
                    my $pos_c = pos ($code);
                    my $value = "grp:$pos_c";

                    # print STDERR "push value:$value\n"; if ($debug); # traces_filter_line

                    push (@match_pos_start1, $value);
                }
                else
                {
                    # il y a un '=', ce n'est pas une declaration de structure, c'est de la forme
                    # struct __req liste[] = { ...}
                    my $pos_c = pos ($code);
                    push (@match_pos_start1, $pos_c);
                }
            }
        }
        elsif (defined $accolade)
        {
            print "accolade:$accolade\n"  if ($debug); # traces_filter_line

            my $pos_c = pos ($code);

            print STDERR "$accolade = $accolade at $pos_c\n" if ($debug); # traces_filter_line

            if ($accolade eq '{')
            {
                push (@match_pos_start1, $pos_c);
            }
            elsif ($accolade eq '}')
            {
                my $stackSize = @match_pos_start1;
                if ($stackSize <= 0)
                {
                    $stackSizeError = 1;

                    print STDERR "pile vide 1\n" if ($b_TraceInconsistent); # traces_filter_line
                    assert ($stackSize > 0, 'pile vide 1') if ($b_assert);         # traces_filter_line

                    next; # continue sans assert
                }

                my $value = pop (@match_pos_start1);

                if (not ($value =~ /:/))
                {
                    # optimisation : seul le premier niveau au dessus de class doit etre efface
                    my $elementNumber = @match_pos_start1;
                    my $lastElement;
                    my $b_efface = 0;
                    if ($elementNumber > 0)
                    {
                        $lastElement = $match_pos_start1[$#match_pos_start1];
                        if ($lastElement =~ /:/)
                        {
                            $b_efface = 1;
                        }
                    }
                    else
                    {
                        $b_efface = 1;
                    }

                    if ($b_efface)
                    {
                        $value++; # ne prends pas '{'
                        $pos_c--; # ne prends pas '}'
                        my $length = $pos_c - $value + 1;
                        my $start_B0 = $value - 1; # base 0
                        my $pos_c_B0 = $pos_c - 1;

                        print STDERR "ERASE entre $start_B0-$pos_c_B0 : from $start_B0, length = $length\n" if ($debug); # traces_filter_line

                        # print STDERR "\n-------------\n" . substr ($filteredCode, $start_B0, $length) . "\n-------------\n" if ($debug); # traces_filter_line

                        substr ($filteredCode, $start_B0, $length) =~ s/[^\n\s]/ /sg;

                        # print STDERR "ERASE\n-----------\n$filteredCode\n-----------\n" if ($debug); # traces_filter_line

                        # attention, en cas de methode imbriquee dans une autre methode (via une classe par exemple)
                        # il faut retirer les erases les plus internes
                        # ces portions de code sont reperees avant et sont au sommet de la pile au moment ou on empile le morceau englobant
                        while ((scalar (@erased) > 0) && ($erased[-1]->[0] > $start_B0))
                        {
                            # supprime une portion imbriquee dans la courante
                            pop (@erased);
                        }

                        print STDERR "top erased $erased[-1]->[0] ? $start_B0\n" if ((scalar (@erased) > 0) && $debug); # traces_filter_line

                        push (@erased, [$start_B0, $start_B0 + $length - 1]);

# traces_filter_start
                        print STDERR "\nstart building erased\n" if ($debug);

                        foreach my $erased (@erased)
                        {
                            my $start = $erased->[0];
                            my $end = $erased->[1];

                            print STDERR "building erased $start - $end\n" if ($debug);
                        }

                        print STDERR "\nbuilding erased\n" if ($debug);
# traces_filter_end

                    }
                }
            }
        }
    }

    $outputFile = $fichier . ".methods_impl_outB" . $step if ($b_TraceDetect && $b_TraceIn);  # traces_filter_line
    TraceDetect::TraceOutToFile ($outputFile, $filteredCode)  if ($b_TraceDetect && $b_TraceIn); # traces_filter_line

    $step++;

    print STDERR "#STEP:$step\n"  if ($debug); # traces_filter_line

    $code = $filteredCode;
    # Effacer le nom du type declare par le typedef pour eviter de les compter comme variables
    # comme :
    #    typedef struct{   // declaration seule
    #        float  min;
    #        float  max;
    #    } param_t;
    # attention une structure peut contenir une structure
    my @match_pos_start2;

    while ($code =~ m{
                    (\btypedef\b\s*\b(?:struct|class|union|enum)\b\s*\w*\s*\{) #1
                    | (\}[\s\*\&]*\w+\s*;)     #2
                    | (\{|\})                  #3
                }gxms)
    {
        my $typedefHeader = $1;
        my $typename = $2;
        my $accolade = $3;
        if (defined $typedefHeader)
        {
            my $pos_c = pos ($code);
            my $value = "typedef_struct:$pos_c";

            # print STDERR "push value:$value\n"; # traces_filter_line

            push (@match_pos_start2, $value);
        }
        elsif (defined $typename)
        {
            my $stackSize = @match_pos_start2;
            if ($stackSize <= 0)
            {
                $stackSizeError = 1;

                print STDERR "pile vide 2\n" if ($b_TraceInconsistent); # traces_filter_line
                assert ($stackSize > 0, 'pile vide 2') if ($b_assert);         # traces_filter_line

                next; # continue sans assert
            }

            my $value = pop (@match_pos_start2);
            if ($value =~ /typedef_struct/)
            {
                # efface le nom du typedef
                my $TypenameLength = length ($typename) - 2; # ne prends pas '}' et ';'
                my $beginOfTypename = (pos ($code) - 1) - $TypenameLength;

                print STDERR "ERASE : from $beginOfTypename, length = $TypenameLength\n" if ($debug); # traces_filter_line

                substr ($filteredCode, $beginOfTypename, $TypenameLength) =~ s/[^\n\s]/ /sg;

                # print STDERR "ERASE\n-----------\n$filteredCode\n-----------\n" if ($debug); # traces_filter_line
            }
        }
        elsif (defined $accolade)
        {
            my $pos_c = pos ($code);

            print STDERR "$accolade = $accolade at $pos_c\n" if ($debug); # traces_filter_line

            if ($accolade eq '{')
            {
                push (@match_pos_start2, $pos_c);
            }
            elsif ($accolade eq '}')
            {
                my $stackSize = @match_pos_start2;
                if ($stackSize <= 0)
                {
                    $stackSizeError = 1;

                    print STDERR "pile vide 3\n" if ($b_TraceInconsistent); # traces_filter_line
                    assert ($stackSize > 0, 'pile vide 3') if ($b_assert);         # traces_filter_line

                    next; # continue sans assert
                }

                my $value = pop (@match_pos_start2);
            }
        }
    }

    $outputFile = $fichier . ".methods_impl_outB" . $step if ($b_TraceDetect && $b_TraceIn);  # traces_filter_line
    TraceDetect::TraceOutToFile ($outputFile, $filteredCode)  if ($b_TraceDetect && $b_TraceIn); # traces_filter_line

    $step++;

    print STDERR "#STEP:$step\n"  if ($debug); # traces_filter_line

    $code = $filteredCode;
    ######################
    # supprime les macros de type ATL (sans supprimer le nom de fonction) ex :
    # STDMETHOD(GetTypeInfo)(UINT itinfo, LCID lcid, ITypeInfo** pptinfo)
    while ($code =~ m{
                    ((STDMETHOD\()(\w+)\)) #1 #2
                }gxms)
    {
        my $macroCall = $1;
        my $macroName = $2;

        my $methodName = $3;                                          # traces_filter_line
        print STDERR "match_method_name : $methodName\n" if ($debug); # traces_filter_line

        my $closingParenthesis = pos ($code) - 1;
        my $macroCallLength = length ($macroCall);
        my $macroNameLength = length ($macroName);
        my $macroNameBegin = ($closingParenthesis - $macroCallLength + 1);

        # efface 'STDMETHOD('

        print STDERR "ERASE : from $macroNameBegin, macroNameLength = $macroNameLength\n" if ($debug); # traces_filter_line

        substr ($filteredCode, $macroNameBegin, $macroNameLength) =~ s/[^\n\s]/ /sg;

        # print STDERR "ERASE\n-----------\n$filteredCode\n-----------\n" if ($debug); # traces_filter_line

        # efface ')'

        print STDERR "ERASE : from $closingParenthesis, length = 1\n" if ($debug); # traces_filter_line

        substr ($filteredCode, $closingParenthesis, 1) =~ s/[^\n\s]/ /sg;

        # print STDERR "ERASE\n-----------\n$filteredCode\n-----------\n" if ($debug); # traces_filter_line
    }

    $outputFile = $fichier . ".methods_impl_outB" . $step if ($b_TraceDetect && $b_TraceIn);  # traces_filter_line
    TraceDetect::TraceOutToFile ($outputFile, $filteredCode)  if ($b_TraceDetect && $b_TraceIn); # traces_filter_line

    $step++;

    print STDERR "#STEP:$step\n"  if ($debug); # traces_filter_line

    $code = $filteredCode;
    ######################
    # supprime les macros de type MFC comme :
    # BEGIN_OBJECT_MAP(ObjectMap)
    #   OBJECT_ENTRY(CLSID_IPServer, CIPServer)
    # END_OBJECT_MAP()
    # autre exemple :
    #   ACE_UNIMPLEMENTED_FUNC (ACE_Managed_Object (const ACE_Managed_Object<TYPE> &))
    # autre exemple :
    # XERCES_CPP_NAMESPACE_USE

    while ($code =~ m{
                    (^[ \t]*[A-Z_0-9]+\s*(\(.*\))?\s*\n) #1 #2
                }gxm)  # pas de s sinon ne fonctionne pas !
    {
        my $match_macro_mfc = $1;
        # my $match_macro_content = $2;  # peut etre vide

        # if (defined $match_macro_content)
        # {   # si n'est pas vide
        #     # supprime pointeurs et references
        #     $match_macro_content =~ s/[&\*]/ /g;
        #     if ($match_macro_content =~ /\w+\s+\w+/)
        #     {
        #         next;  # ce n'est pas une macro type MFC
        #     }
        # }

        print STDERR "Macro_MFC : $match_macro_mfc\n" if ($debug);                                    # traces_filter_line

        my $MFCMacroLength = length ($match_macro_mfc);
        my $beginOfMFCMacro = pos ($code) - $MFCMacroLength;

        print STDERR "ERASE : from $beginOfMFCMacro, MFCMacroLength = $MFCMacroLength\n" if ($debug); # traces_filter_line

        substr ($filteredCode, $beginOfMFCMacro, $MFCMacroLength) =~ s/[^\n\s]/ /sg;

        # print STDERR "ERASE\n-----------\n$filteredCode\n-----------\n" if ($debug);                # traces_filter_line
    }

    $outputFile = $fichier . ".methods_impl_outB" . $step if ($b_TraceDetect && $b_TraceIn);  # traces_filter_line
    TraceDetect::TraceOutToFile ($outputFile, $filteredCode)  if ($b_TraceDetect && $b_TraceIn); # traces_filter_line

    $step++;

    print STDERR "#STEP:$step\n"  if ($debug); # traces_filter_line

    $code = $filteredCode;
    ######################
    # supprime les identificateurs avant le mot-cle class ex :
    # ILB_EXPORT class MgAbstractWM { ...
    while ($code =~ m{
                    ((\w+)\s+class\b) #1 #2
                }gxms)
    {
        my $classHeader = $1;
        my $identifierBeforeClass = $2;

        if ($identifierBeforeClass ne 'friend')
        {
            print STDERR "identifierBeforeClass : $identifierBeforeClass\n" if ($debug); # traces_filter_line

            my $classHeaderEnd = pos ($code) - 1;
            my $classHeaderLength = length ($classHeader);
            my $identifierLength = length ($identifierBeforeClass);
            my $classHeaderBegin = $classHeaderEnd - $classHeaderLength + 1;

            print STDERR "ERASE $classHeaderBegin-$classHeaderEnd : from $classHeaderBegin, identifierLength = $identifierLength\n" if ($debug); # traces_filter_line

            substr ($filteredCode, $classHeaderBegin, $identifierLength) =~ s/[^\n\s]/ /sg;

            # print STDERR "ERASE\n-----------\n$filteredCode\n-----------\n" if ($debug); # traces_filter_line
        }
    }

    $outputFile = $fichier . ".methods_impl_outB" . $step if ($b_TraceDetect && $b_TraceIn);  # traces_filter_line
    TraceDetect::TraceOutToFile ($outputFile, $filteredCode)  if ($b_TraceDetect && $b_TraceIn); # traces_filter_line

    $step++;

    print STDERR "#STEP:$step\n"  if ($debug); # traces_filter_line

    $code = $filteredCode;
    ######################
    # supprime les identificateurs apres le mot-cle class ex :
    # class ATL_NO_VTABLE IDelegatingDispImpl : public T, public D { ...
    while ($code =~ m{
                    ((\bclass\s+)(\w+)\s+(\w+)\s*[:\{;]) #1 #2 #3 #4
                }gxms)
    {
        my $classHeader = $1;
        my $classToken = $2;
        my $identifierAfterClass = $3;

        if ($identifierAfterClass ne 'friend')
        {
            print STDERR "identifierAfterClass : $identifierAfterClass\n" if ($debug); # traces_filter_line

            my $classHeaderEnd = pos ($code) - 1;
            my $classHeaderlength = length ($classHeader);
            my $classTokenLength = length ($classToken);
            my $identifierLength = length ($identifierAfterClass);
            my $identifierBegin = ($classHeaderEnd - $classHeaderlength + 1) + $classTokenLength;

            print STDERR "ERASE $identifierBegin-$classHeaderEnd : from $identifierBegin, identifierLength = $identifierLength\n" if ($debug); # traces_filter_line

            substr ($filteredCode, $identifierBegin, $identifierLength) =~ s/[^\n\s]/ /sg;

            # print STDERR "ERASE\n-----------\n$filteredCode\n-----------\n" if ($debug); # traces_filter_line
        }
    }

    $outputFile = $fichier . ".methods_impl_outB" . $step if ($b_TraceDetect && $b_TraceIn);  # traces_filter_line
    TraceDetect::TraceOutToFile ($outputFile, $filteredCode)  if ($b_TraceDetect && $b_TraceIn); # traces_filter_line

    $step++;

    print STDERR "#STEP:$step\n"  if ($debug); # traces_filter_line

    $code = $filteredCode;
    ######################
    # ne garde que le code avec les accolades

    my @code_to_erase;
    my $previous = 0;

# traces_filter_start

    foreach my $erased (@erased)
    {
        my $start = $erased->[0];
        my $end = $erased->[1];

        print STDERR "erased $start - $end\n" if ($debug);
    }

# traces_filter_end

    foreach my $erased (@erased)
    {
        my $start = $erased->[0];
        my $end = $erased->[1];

        print STDERR "code_to_erase $previous - " . ($start - 1 - 1) . "\n" if ($debug); # traces_filter_line

        push (@code_to_erase, [$previous, $start - 1 - 1]); # garde accolade

        if ($previous > $start - 1 - 1)
        {
          # un probleme dans le calcul de debut et fin de zone a eraser
          # print STDERR "un probleme dans le calcul de debut et fin de zone a eraser: $previous, " . ($start - 1 - 1) . "\n"  if ($debug); # traces_filter_line
          $status |= Erreurs::COMPTEUR_STATUS_PB_STRIP;
          Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_PB_STRIP', 'CountFunctionsMethodsAttributesClean!!!!', ''); # traces_filter_line
        }

        $previous = $end + 1 + 1; # garde accolade
    }

    if ($previous != 0)
    {
        # le dernier segment
        my $length = length ($statementsOnly);

        # print STDERR "code_to_erase $previous - " . ($length - 1) . "\n" if ($debug);  # traces_filter_line

        push (@code_to_erase, [$previous, $length - 1]);
    }
    else
    {
        # il n'y a pas de zone a effacer :
        # il n'y a pas de fonctions, .... : il faut tout effacer
        my $start = 0;
        my $length = length ($statementsOnly);

        # print STDERR "ERASE $start-$length : from $start, length = $length\n" if ($debug);         # traces_filter_line

        substr ($statementsOnly, $start, $length) =~ s/[^\n]/ /g;

        # print STDERR "ERASE\n-----------\n$statementsOnly\n-----------\n" if ($debug); # traces_filter_line
    }

    foreach my $item_foreach (@code_to_erase)
    {
        my $start = $item_foreach->[0];
        my $end = $item_foreach->[1];
        my $length = $end - $start + 1;

        print STDERR "ERASE $start-$end : from $start, length = $length\n" if ($debug); # traces_filter_line

        substr ($statementsOnly, $start, $length) =~ s/[^\n]/ /g;

        # print STDERR "ERASE correct\n-----------\n$statementsOnly\n-----------\n" if ($debug); # traces_filter_line
    }

    $step = 0;

    $outputFile = $fichier . ".code_only" . $step if ($b_TraceDetect && $b_TraceIn);            # traces_filter_line
    TraceDetect::TraceOutToFile ($outputFile, $statementsOnly)  if ($b_TraceDetect && $b_TraceIn); # traces_filter_line

    print STDERR "#STEP:end\n"  if ($debug); # traces_filter_line

    if ($stackSizeError)
    {
       $status |= Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES;
    }

    $vue->{'code_only'} = $statementsOnly;

    return ($status, $filteredCode);
}


sub ExtractImplementationScopeClass($);
sub ExtractClassNameFromScopeClass($);
sub RecupScopeNamespaceClass(@);
sub ParseVariables($$$$$$$$);

sub CountFunctionsMethodsAttributesParse($$$$$)
{
    my ($fichier, $vue, $compteurs, $options, $code) = @_;
    my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0); # traces_filter_line
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0);          # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);                  # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                           # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                             # traces_filter_line
    my $debug = 0;                                                              # traces_filter_line
    my $debug2 = ((exists $options->{'--FMAdebug'})? 1 : 0);                    # traces_filter_line
    my $debug3 = 0;                                                             # traces_filter_line

    my $status = 0;
    my $langage = $$compteurs{'Dat_Language'};
    my $b_analyse_cpp = ($langage eq 'Cpp') || ($langage eq 'Hpp');
    my @parsed_code; # contient des hash

    my @match_pos_start;

    my @visibilities;        # public, private, protected, struct_public, proto_KR, methode,
                               # var_glob_struct_init_accol, enum, namespace, template_class, template_struct,
                               # var_glob_init_accol, autres
    my $prototype_KR_increment = ''; # stocke le prototype par increment
    my $prototype_KR_line_number_start = 0; # traces_filter_line
    my $b_prototype_KR_en_cours = 0;

    my $stackSizeError = 0;
    my $uid = 1;

    print STDERR "##############################################\n" if ($debug2); # traces_filter_line

    while ($code =~    m{
                            (\s*)                       #1
                            |
                            (                           #2
                                (.*?)                   #3
                                (                       #4
                                    (;)                 #5
                                    |   (\{)            #6
                                    |   (\})            #7
                                    |   (\b(public|protected|private)\s*:) #8 #9
                                    |   (\#.*?\n)       #10
                                    |   (\z)            #11
                                )
                            )
                        }gxms )
    {
        my $match_spaces = $1;
        my $match_all = $2;
        my $match_avant = $3;
        my $match_pt_virgule = $5;
        my $match_accolade_ouvre = $6;
        my $match_accolade_ferme = $7;
        my $match_visibility = $9;
        my $match_prepro = $10;
        my $match_end = $11;

        if (defined $match_spaces)
        {
            next;
        }

        if (defined $match_end)  # optimisation
        {
            last;
        }

        # nettoyage
        $match_avant =~ s/\n/ /g;
        $match_avant =~ s/\s+/ /g;
        $match_avant =~ s/\s+$//;

        my $pos_c_B0 = pos ($code) - 1;

        print STDERR "=============\n" if ($debug2);         # traces_filter_line
        print STDERR "=match_all:$match_all\n" if ($debug2); # traces_filter_line

        my $length_match_all = length ($match_all);
        my $length_avant = length ($match_avant);
        my $start_pos_B0 = $pos_c_B0 - $length_match_all + 1;

        my $line_number = TraceDetect::CalcLineMatch ($code, $start_pos_B0) if ($b_TraceDetect); # traces_filter_line
        print STDERR "line_number:$line_number\n"  if ($b_TraceDetect && $debug2);            # traces_filter_line

        my %hash_item;
        $hash_item{'uid'} = $uid++;
        $hash_item{'item'} = $match_avant;
        $hash_item{'line_number'} = $line_number if ($b_TraceDetect); # traces_filter_line
        $hash_item{'start_pos'} = $start_pos_B0;
        $hash_item{'end_pos'} = $pos_c_B0;

        my $b_global_def = 0;
        if (@match_pos_start == 0)
        {
            $b_global_def = 1;
        }

        $hash_item{'b_global_def'} = $b_global_def;

        if (defined $match_pt_virgule)
        {
            # c'est un point virgule

            print STDERR "=> point virgule\n" if ($debug3); # traces_filter_line

            if ($b_prototype_KR_en_cours == 1)
            {
                # stocke incrementallement prototype KR
                $prototype_KR_increment .= $match_all;

                print STDERR "prototype_KR_increment:$match_all\n"  if ($debug2); # traces_filter_line
            }
            elsif ($match_avant =~ /\)\s*\w+[\s\*]+\w+/)
            {
                # c'est un debut de prototype KR

                print STDERR "======>>>>>> (start) prototype KR\n" if ($debug2); # traces_filter_line

                $prototype_KR_increment = $match_all;
                $b_prototype_KR_en_cours = 1;
                $prototype_KR_line_number_start = $line_number if ($b_TraceDetect); # traces_filter_line
            }
            elsif (($match_avant =~ /\(/)
            && not (($match_avant =~ /=\s*.*?\(/) && not ($match_avant =~ /\boperator\b/))
                  )
            {
                # 2eme test pour eviter :
                # const char* NAII01Ecran01::NA_NFS = getenv(CHAINE_35);
                # ATCPOS_CTR* ATCPOS_CTR::_instance = new ATCPOS_CTR();
                # attention au cas : Complex operator=( const Complex& a);
                if ($match_avant =~ /\btypedef\b/)
                {
                    # c'est un typedef pointeur sur fonction
                    print STDERR "======>>>>>> typedef pointeur sur fonction\n" if ($debug2); # traces_filter_line
                    push (@parsed_code, [PARSER_CPP_TYPEDEF_PTR_SUR_FONCTION, \%hash_item]);
                }
                elsif ($match_avant =~ /\(\s*[&\*]/)
                {
                    # c'est une variable pointeur ou reference sur fonction ex :
                    # int (*pointeur_de_fonction1)(int, int);

                    print STDERR "======>>>>>> declaration variable pointeur sur fonction\n" if ($debug2); # traces_filter_line

		    if (defined $visibilities[-1]) {
                       $hash_item{'visibility'} = $visibilities[-1];
	            }
		    else {
                       $hash_item{'visibility'} = 'private';
	            }
                    push (@parsed_code, [PARSER_CPP_DECLARATION_VARIABLE_PTR_SUR_FONCTION, \%hash_item]);
                }
                else
                {
                    print STDERR "\nmatch avant = $match_avant\n" if ($debug2); # traces_filter_line

                    # c'est une declaration fonction ou methode
                    while ($match_avant =~ s/<[^<]*?>/ /g ) {} # supprime les templates

                    print STDERR "\nmatch apres = $match_avant\n" if ($debug2); # traces_filter_line

                    $match_avant =~ s/\btemplate\b\s*//; # supprime les templates de methode typename ou class

                    my $match_method_name = '';
                    if ($match_avant =~ /(\w+)\s*\(/)
                    {
                        # recup nom de methode (sauf operator)
                        $match_method_name = $1;
                    }

                    print STDERR "======>>>>>> declaration fonction ou methode: $match_method_name\n" if ($debug2); # traces_filter_line

                    push (@parsed_code, [PARSER_CPP_DECLARATION_FONCTION_OU_METHODE, \%hash_item]);
                    $hash_item{'method_name'} = $match_method_name;
                    my $tag = '-Decl-',
                    my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass (@match_pos_start);
                    $hash_item{'scope_namespace'} = $scope_namespace;
                    $hash_item{'scope_class'} = $scope_class;
                    my $b_method_friend = 0;
                    my $b_method_stream = 0;
                    my $b_method_operator = 0;
                    my $b_method_virtuelle_pure = 0;
                    my $b_method_virtuelle = 0;
                    my $b_dtor = 0;
                    my $b_ctor = 0;
                    my $b_methode = 0; # 0 : fonction ; 1 : methode
                    my $b_item_inside_class = 0;

		    # FRIEND Methods
		    # STREAM Methods
                    if ($match_avant =~ /\bfriend\b/)
                    {
                        $b_methode = 1;
                        $b_method_friend = 1;
                        if ($match_avant =~ /(>>|<<)/)
                        {
                            $b_method_stream = 1;
                        }

                        print STDERR "friend:$match_avant\n" if ($debug); # traces_filter_line
                    }
		    # VIRTUAL Methods
                    if ($match_avant =~ /\bvirtual\b/)
                    {
                        $b_methode = 1;
                        $b_method_virtuelle = 1;

                        print STDERR "virtuelle:$match_avant\n" if ($debug); # traces_filter_line

			# VIRTUAL pure
                        if ($match_avant =~ /\)\s*(const)?\s*=\s*0/)
                        {
                            $b_methode = 1;
                            $b_method_virtuelle_pure = 1;
                        }
	            }
                    if ($match_avant =~ /\boperator\b/)
                    {
                        $b_methode = 1;
                        $b_method_operator = 1;
                    }
                    if ($scope_class eq '')
                    {
                        # pas dans une classe
                        if ($match_avant =~ /::/)
                        {
                            $b_methode = 1;
                            $tag .= 'Meth-';
                        }
                        else
                        {
                            $tag .= 'Funct-';
                        }
                    }
                    else
                    {
                        # dans une classe
                        $b_item_inside_class = 1;

                        if ($b_method_friend == 0)
                        {
                            # autre classique non-friend
                            $b_methode = 1;
                            $tag .= 'Meth-';
                        }
                        else
                        {
                            # methode friend
                            if ($b_method_operator == 0)
                            {
                                # pas un operator
                                if ($match_avant =~ /::/)
                                {
                                    # c'est une methode friend
                                    $b_methode = 1;
                                    $tag .= 'Meth-Friend-';
                                }
                                else
                                {
                                    # c'est une fonction friend
                                    $tag .= 'Funct-Friend-';
                                }
                            }
                            else
                            {
                                # c'est un operator
                                $tag .= 'Funct-Friend-';
                            }
                        }
                    }

                    if ($b_method_stream == 1)
                    {
                        $tag .= 'Strm-';
                    }

                    if ($b_method_operator == 1)
                    {
                        $tag .= 'Op-';
                    }

                    if ($match_avant =~ /\s*(~)?\s*(\w+)\s*\(/ )
                    {
                        my $tilde = $1;
                        my $match_name = $2;
                        my $class_name = ExtractClassNameFromScopeClass($scope_class);

                        if ($match_name eq $class_name)
                        {
                            if (defined $tilde)
                            {
                                $tag .= 'Dtor-';
                                $b_dtor = 1;
                                $b_methode = 1;
                            }
                            else
                            {
                                $tag .= 'Ctor-';
                                $b_ctor = 1;
                                $b_methode = 1;
                            }
                        }
                    }

                    if ($b_method_virtuelle_pure == 1)
                    {
                        $b_methode = 1;
                        $tag .= 'Vpur-';
                    }

                    $hash_item{'b_method'} = $b_methode;
                    $hash_item{'b_friend_method'} = $b_method_friend;
                    $hash_item{'b_virtual'} = $b_method_virtuelle;
                    $hash_item{'b_pure_virtual'} = $b_method_virtuelle_pure;
                    $hash_item{'b_stream_method'} = $b_method_stream;
                    $hash_item{'b_dtor'} = $b_dtor;
                    $hash_item{'b_ctor'} = $b_ctor;
                    $hash_item{'b_method_operator'} = $b_method_operator;
                    $hash_item{'tag'} = $tag;
                    $hash_item{'b_item_inside_class'} = $b_item_inside_class;
		    if (defined $visibilities[-1]) {
                       $hash_item{'visibility'} = $visibilities[-1];
	            }
		    else {
                       $hash_item{'visibility'} = 'private';
	            }
                }
            }
            elsif ($match_avant =~ /\bfriend\s+class\s/)
            {
                # c'est une friend class

                print STDERR "======>>>>>> friend class <<<<<<<<<==============\n" if ($debug2); # traces_filter_line

                push (@parsed_code, [PARSER_CPP_FRIEND_CLASS, \%hash_item]);
                my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass (@match_pos_start);
                $hash_item{'scope_namespace'} = $scope_namespace;
                $hash_item{'scope_class'} = $scope_class;
                my $tag = '-FriendClas-';
                $hash_item{'tag'} = $tag;
            }
            elsif ($match_avant =~ /(\btemplate\b)?.*?\bclass\b/)
            {
                # c'est une forward declaration class
                # exemples :
                # class CToto;
                # template <class T> class ACE_Array_Iterator;

                print STDERR "======>>>>>> forward declaration class <<<<<<<<<==============\n" if ($debug2); # traces_filter_line

                push (@parsed_code, [PARSER_CPP_FORWARD_DECLARATION_CLASS, \%hash_item]);
            }
            elsif ($match_avant =~ /\btypedef\b/)
            {
                # c'est un typedef scalaire

                print STDERR "======>>>>>> typedef scalaire\n" if ($debug2); # traces_filter_line

                push (@parsed_code, [PARSER_CPP_TYPEDEF_SCALAIRE, \%hash_item]);
            }
            elsif ($match_avant =~ /\busing\b/)
            {
                # c'est une clause d'utilisation namespace

                print STDERR "======>>>>>> clause d'utilisation namespace <<<<<<<<<==============\n" if ($debug2); # traces_filter_line

                push (@parsed_code, [PARSER_CPP_USING, \%hash_item]);
            }
            elsif ($match_all ne ';')
            {
                # filtre implicitement les ';' seuls

                print STDERR "======>>>>>> declaration de variable <<<<<<<<<==============\n" if ($debug2); # traces_filter_line

                my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass (@match_pos_start);
                $hash_item{'scope_namespace'} = $scope_namespace;
                $hash_item{'scope_class'} = $scope_class;
                my $match_to_analyse = $match_all;
                ParseVariables($fichier, $compteurs, $options, $match_to_analyse, \@parsed_code, \%hash_item, \@visibilities, PARSER_CPP_DECLARATION_VARIABLE);
            }
        }
        elsif (defined $match_accolade_ouvre)
        {
            # c'est une accolade ouvrante

            print STDERR "=> accolade ouvre\n" if ($debug3); # traces_filter_line

            if ($b_prototype_KR_en_cours == 1)
            {
                # termine de stocker incrementallement le prototype KR

                print STDERR "======>>>>>> (fin) prototype KR\n" if ($debug2); # traces_filter_line

                push (@parsed_code, [PARSER_CPP_PROTOTYPE_KR, \%hash_item]);
                $prototype_KR_increment .= $match_avant;
                print STDERR "prototype_KR_increment:$match_all\n" if ($debug2);                 # traces_filter_line
                print STDERR "prototype_KR_increment:$prototype_KR_increment\n"  if ($debug2);   # traces_filter_line
                $hash_item{'line_number'} = $prototype_KR_line_number_start if ($b_TraceDetect); # traces_filter_line
                $prototype_KR_increment =~ s/\n//g;
                $prototype_KR_increment =~ s/\s+/ /g;

                $hash_item{'item'} = $prototype_KR_increment;
                my $match_method_name = '';
                if ($prototype_KR_increment =~ /(\w+)\s*\(/)
                {
                    # recup nom de methode (sauf operator)
                    $match_method_name = $1;
                }

                $hash_item{'method_name'} = $match_method_name;

                push (@match_pos_start, $pos_c_B0);
                push (@visibilities, 'proto_KR');
                my $tag = '-Imp-Funct-KR-';
                my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass (@match_pos_start);
                $hash_item{'line_number'} = $prototype_KR_line_number_start if ($b_TraceDetect); # surcharge # traces_filter_line
                $hash_item{'item'} = $prototype_KR_increment;                                    # surcharge
                $hash_item{'scope_namespace'} = '';
                $hash_item{'scope_class'} = '';
                $hash_item{'full_scope'} = '';
                $hash_item{'tag'} = $tag;

                $prototype_KR_increment = '';
                $prototype_KR_line_number_start = 0; # traces_filter_line
                $b_prototype_KR_en_cours = 0;
            }
            elsif (($match_avant =~ /^template\b\s*/) && not ($match_avant =~ /^template\s*<.*?>.*?\(/))
            {
                # c'est un template de (classe ou de struct)
                # les templates de fonctions/methodes sont pris en compte comme des fonctions/methodes classiques
                if ($match_avant =~ /^template\s*<.*?>\s*class\s+(\w+)\b/ )
                {
                    # c'est un template de classe
                    my $match_class_name = $1;
                    $hash_item{'class_name'} = $match_class_name;

                    print STDERR "======>>>>>> declaration de template de classe :$match_class_name\n" if ($debug2); # traces_filter_line

                    push (@parsed_code, [PARSER_CPP_TEMPLATE_CLASSE, \%hash_item]);
                    my $value = "class:$match_class_name:$pos_c_B0";
                    push (@match_pos_start, $value);
                    push (@visibilities, 'private');
                    my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass (@match_pos_start);
                    $hash_item{'scope_namespace'} = $scope_namespace;
                    $hash_item{'scope_class'} = $scope_class;
                }
                elsif ($match_avant =~ /^template\s*<.*?>\s*struct\s+(\w+)\b/)
                {
                    # c'est un template de struct
                    my $match_class_name = $1;
                    $hash_item{'class_name'} = $match_class_name;

                    print STDERR "======>>>>>> declaration de template de struct :$match_class_name\n" if ($debug2); # traces_filter_line

                    push (@parsed_code, [PARSER_CPP_TEMPLATE_STRUCT, \%hash_item]);
                    my $value = "class:$match_class_name:$pos_c_B0";
                    push (@match_pos_start, $value);
                    push (@visibilities, 'public');
                    my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass (@match_pos_start);
                    $hash_item{'scope_namespace'} = $scope_namespace;
                    $hash_item{'scope_class'} = $scope_class;
                }
                else
                {
                    # c'est un template variable membre init accolade

                    print STDERR "======>>>>>> template variable membre init accolade\n" if ($debug2); # traces_filter_line

                    push (@match_pos_start, $pos_c_B0);
                    push (@visibilities, 'var_glob_init_accol');
                    ParseVariables($fichier, $compteurs, $options, $match_avant, \@parsed_code, \%hash_item, \@visibilities, PARSER_CPP_VAR_GLOB_INIT_ACCOLADE);
                }
            }
            elsif ($match_avant =~ /\(/)
            {
                # c'est une fonction ou une methode
                # les templates de fonctions/methodes sont pris en compte comme des fonctions/methodes classiques
                my $match_method_name = '';

                print STDERR "\nmatch avant = $match_avant\n" if ($debug2); # traces_filter_line

                # supprime les parametres template
                while ($match_avant =~ s/<[^<]*?>/ /g ) {} # supprime les templates

                $match_avant =~ s/\btemplate\b\s*//; # supprime les templates de methode typename ou class

                print STDERR "\nmatch apres = $match_avant\n" if ($debug2); # traces_filter_line

                # supprime les scopes 'inutiles' de methodes comme :
                # A::A() a l'interieur de la class A
                my ($scope_namespace2, $scope_class2) = RecupScopeNamespaceClass (@match_pos_start);
                if ($scope_class2 ne '')
                {
                    $match_avant =~ s/^.*:://;
                }

                if ($match_avant =~ /(\w+)\s*\(/)
                {
                    # recup nom de methode (sauf operator)
                    $match_method_name = $1;
                }

                print STDERR "======>>>>>> implementation fonction ou methode: $match_method_name\n" if ($debug2); # traces_filter_line

                push (@parsed_code, [PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE, \%hash_item]);
                $hash_item{'method_name'} = $match_method_name;
                # suppression de la liste d'initialisation
                $match_avant =~ s/\)\s*:.*/)/;
                $hash_item{'item'} = $match_avant; # surcharge
                my $b_method_operator = 0;
                push (@match_pos_start, $pos_c_B0);

                if ($match_avant =~ /\boperator\b/)
                {
                    $b_method_operator = 1;
                }

                my $tag = '-Imp-';
                my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass (@match_pos_start);
                $hash_item{'scope_namespace'} = $scope_namespace;
                $hash_item{'scope_class'} = $scope_class;
                $hash_item{'full_scope'} = '';
                my $b_dtor = 0;
                my $b_ctor = 0;
                my $b_method = 0; # 0 :fonction ; 1 : methode
                my $b_item_inside_class = 0;

                if ($scope_class ne '')
                {
                    # dans une classe
                    $b_item_inside_class = 1;
                    $b_method = 1;
                    my $full_scope = '';
                    if ($scope_namespace ne '')
                    {
                        $full_scope = $scope_namespace . '::' . $scope_class;
                    }
                    else
                    {
                        $full_scope = $scope_class;
                    }

                    $hash_item{'full_scope'} = $full_scope;
                }
                else
                {
                    # pas dans une classe : recup nom de la classe
                    if ($match_avant =~ /(((\w+)\s*::\s*)+)(~)?\s*(\w+)\s*\(/)
                    {
                        my $match_full_scope = $1;
                        my $match_method_name = $4;
                        $match_full_scope =~ s/\s+//g;
                        $match_full_scope =~ s/::$//;
                        if ($scope_namespace ne '')
                        {
                            $match_full_scope = $scope_namespace . '::' . $match_full_scope;
                        }
                        $hash_item{'full_scope'} = $match_full_scope;
                    }

                    # il faut calculer le $scope_class d'implementation
                    my $match_scope_class_impl = ExtractImplementationScopeClass($match_avant);
                    $hash_item{'scope_class'} = $match_scope_class_impl;

                }
                if ($scope_class eq '')
                {
                    # pas dans une classe
                    if ($match_avant =~ /::/)
                    {
                        $b_method = 1;
                        $tag .= 'Meth-';
                        # il faut calculer le $scope_class d'implementation
                        my $match_scope_class_impl = ExtractImplementationScopeClass($match_avant);
                        $hash_item{'scope_class'} = $match_scope_class_impl;

                    }
                    else
                    {
                        $tag .= 'Funct-';
                    }
                }
                else
                {
                    $b_method = 1;
                    $tag .= 'Meth-';
                }
                if ($scope_class ne '')
                {
                    # dans une classe
                    $b_method = 1;
                    if ($match_avant =~ /^\s*(~)?\s*(\w+)\s*\(/)
                    {
                        my $tilde = $1;
                        my $match_name = $2;
                        my $class_name = ExtractClassNameFromScopeClass($scope_class);
                        if ($match_name eq $class_name)
                        {
                            if (defined $tilde)
                            {
                                $tag .= 'Dtor-';
                                $b_dtor = 1;
                            }
                            else
                            {
                                $tag .= 'Ctor-';
                                $b_ctor = 1;
                            }
                        }
                    }
                }
                else
                {
                    # pas dans une classe
                    if ($match_avant =~ /\s*(\w+)\s*::\s*(~)?\s*(\w+)\s*\(/ )
                    {
                        my $class_name = $1;
                        my $tilde = $2;
                        my $match_name = $3;
                        if ($class_name eq $match_name)
                        {
                            $b_method = 1;
                            # il faut calculer le $scope_class d'implementation
                            my $match_scope_class_impl = ExtractImplementationScopeClass($match_avant);
                            $hash_item{'scope_class'} = $match_scope_class_impl;

                            if (defined $tilde)
                            {
                                $tag .= 'Dtor-';
                                $b_dtor = 1;
                            }
                            else
                            {
                                $tag .= 'Ctor-';
                                $b_ctor = 1;
                            }
                        }
                    }
                }

                if ($b_method_operator == 1)
                {
                    $b_method = 1;
                    $tag .= 'Op-';
                }

                push (@visibilities, 'methode');
                $hash_item{'tag'} = $tag;
                $hash_item{'b_dtor'} = $b_dtor;
                $hash_item{'b_ctor'} = $b_ctor;
                $hash_item{'b_method_operator'} = $b_method_operator;
                $hash_item{'b_method'} = $b_method;
                $hash_item{'b_item_inside_class'} = $b_item_inside_class;
		if (defined $visibilities[-1]) {
                   $hash_item{'visibility'} = $visibilities[-1];
	        }
		else {
                   $hash_item{'visibility'} = 'private';
		}
            }
            elsif ($match_avant =~ /^class\s+(\w+)/)
            {
                # c'est une declaration de classe
                my $match_class_name = $1;
                $hash_item{'class_name'} = $match_class_name;

                print STDERR "======>>>>>> declaration de classe :$match_class_name\n" if ($debug2); # traces_filter_line

                push (@parsed_code, [PARSER_CPP_DECLARATION_CLASS, \%hash_item]);
                my $value = "class:$match_class_name:$pos_c_B0";
                push (@match_pos_start, $value);
                push (@visibilities, 'private');
                my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass (@match_pos_start);
                $hash_item{'scope_namespace'} = $scope_namespace;
                $hash_item{'scope_class'} = $scope_class;
            }
            elsif ($match_avant =~ /^struct\s+(\w+)/ )
            {
                # c'est une declaration de structure
                my $match_struct_name = $1;
                if ($match_avant =~ /=/)
                {
                    # c'est une declaration de variable struct avec init

                    print STDERR "======>>>>>> declaration de variable struct avec init\n" if ($debug2); # traces_filter_line

                    # comme struct test b = { 3, 4, 5};
                    push (@match_pos_start, $pos_c_B0);
                    push (@visibilities, 'var_glob_struct_init_accol');
                    ParseVariables($fichier, $compteurs, $options, $match_avant, \@parsed_code, \%hash_item, \@visibilities, PARSER_CPP_DECLARATION_STRUCT_AVEC_INIT);
                }
                else
                {
                    # c'est une declaration de structure
                    # une structure est presque une classe

                    print STDERR "======>>>>>> declaration de structure\n" if ($debug2); # traces_filter_line

                    push (@parsed_code, [PARSER_CPP_DECLARATION_STRUCT, \%hash_item]);
                    my $value = "struct:$match_struct_name:$pos_c_B0";
                    push (@match_pos_start, $value);
                    push (@visibilities, 'struct_public');
                    my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass (@match_pos_start);
                    $hash_item{'scope_namespace'} = $scope_namespace;
                    $hash_item{'scope_class'} = $scope_class;
                }
            }
            elsif ($match_avant =~ /^enum\b/)
            {
                # c'est une declaration d'enumere

                print STDERR "======>>>>>> declaration d'enumere\n" if ($debug2); # traces_filter_line

                push (@parsed_code, [PARSER_CPP_DECLARATION_ENUM, \%hash_item]);
                push (@match_pos_start, $pos_c_B0);
                push (@visibilities, 'enum');
            }
            elsif ($match_avant =~ /\bnamespace\b(?:\s+(\w+))?/)
            {
                # c'est une declaration de namespace
                my $match_namespace_name;

                if (defined $1)	
                {
                    $match_namespace_name = $1;
                }
                else
                {
                    $match_namespace_name = '';
                }

                print STDERR "======>>>>>> declaration de namespace :$match_namespace_name\n" if ($debug2); # traces_filter_line

                push (@parsed_code, [PARSER_CPP_DECLARATION_NAMESPACE, \%hash_item]);
                my $value = "namespace:$match_namespace_name:$pos_c_B0";
                push (@match_pos_start, $value);
                push (@visibilities, 'namespace');
            }
            elsif ($match_avant =~ /=\s*$/)
            {
                # c'est une variable globale initialisee avec accolade

                print STDERR "======>>>>>> variable globale initialisee avec accolade <<<<<<=======\n" if ($debug2); # traces_filter_line

                push (@match_pos_start, $pos_c_B0);
                push (@visibilities, 'var_glob_init_accol');
                ParseVariables($fichier, $compteurs, $options, $match_avant, \@parsed_code, \%hash_item, \@visibilities, PARSER_CPP_VAR_GLOB_INIT_ACCOLADE);
            }
            else
            {
                # c'est un element inconnu que l'on ignore

                print STDERR "======>>>>>> ?????????????????????? <<<<<<=======\n" if ($debug2); # traces_filter_line

                push (@parsed_code, [PARSER_CPP_ACCOL_OUVR_UNKNOWN, \%hash_item]);
                push (@match_pos_start, $pos_c_B0);
                push (@visibilities, 'autres');
            }
        }
        elsif (defined $match_accolade_ferme)
        {
            # c'est une accolade fermante

            print STDERR "=> accolade ferme\n" if ($debug3); # traces_filter_line

            my $stackSize = @match_pos_start;
            if ($stackSize <= 0)
            {
                $stackSizeError = 1;
                print STDERR "pile vide 4\n" if ($b_TraceInconsistent); # traces_filter_line
                assert ($stackSize > 0, 'pile vide 4') if ($b_assert);         # traces_filter_line
                last;
            }

            pop (@match_pos_start);

            $stackSize = @visibilities;
            if ($stackSize <= 0)
            {
                $stackSizeError = 1;
                print STDERR "pile vide 5\n" if ($b_TraceInconsistent); # traces_filter_line
                assert ($stackSize > 0, 'pile vide 5') if ($b_assert);         # traces_filter_line
                last;
            }

            my $visibility = pop (@visibilities);
            if ($visibility =~ /\bprivate\b|\bpublic\b|\bprotected\b/)
            {
                # on est dans une classe (ou une structure ...)
                push (@parsed_code, [PARSER_CPP_CLASS_END, \%hash_item]);
            }
            elsif ($visibility =~ /\bmethode\b/)
            {
                # fin de methode
                push (@parsed_code, [PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE_END, \%hash_item]);
            }
        }
        elsif (defined $match_visibility)
        {
            # c'est un changement de visibilite

            print STDERR "=> visibility\n" if ($debug3); # traces_filter_line

            push (@parsed_code, [PARSER_CPP_VISIBILITY, \%hash_item]);
            $hash_item{'item'} = $match_visibility;
            $hash_item{'visibility'} = $match_visibility;
            my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass (@match_pos_start);
            $hash_item{'scope_namespace'} = $scope_namespace;
            $hash_item{'scope_class'} = $scope_class;

            my $stackSize = @visibilities;
            if ($stackSize <= 0)
            {
                $stackSizeError = 1;
                print STDERR "pile vide 8\n" if ($b_TraceInconsistent); # traces_filter_line
                assert ($stackSize > 0, 'pile vide 8') if ($b_assert);         # traces_filter_line
                last;
            }

            pop (@visibilities);
            push (@visibilities, $match_visibility);
        }
        elsif (defined $match_prepro)
        {
            # c'est une directive prepro
            # pas de traitement
            print STDERR "=> point prepro\n" if ($debug3); # traces_filter_line
        }
    }

    my $stackSize = @match_pos_start;
    if ($stackSize != 0)
    {
        # la pile devrait etre vide
        $stackSizeError = 1;
        print STDERR "la pile devrait etre vide\n" if ($b_TraceInconsistent); # traces_filter_line
        assert ($stackSize != 0, 'la pile devrait etre vide') if ($b_assert);        # traces_filter_line
    }

    if (not $stackSizeError)
    {
        $vue->{'parsed_code'} = \@parsed_code;
    }
    else
    {
        $status |= Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES;
    }

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Extrait le scope de la classe a partir de la signature d'implementation
#-------------------------------------------------------------------------------
sub ExtractImplementationScopeClass($)
{
    my ($impl_signature) = @_;
    my $debug = 0;  # traces_filter_line
    print STDERR "#ExtractImplementationScopeClass\n" if ($debug); # traces_filter_line
    print STDERR "impl_signature:$impl_signature\n" if ($debug);   # traces_filter_line
    my $scope_class = '';
    # ex1 : 'A::Complex3 A::Complex3::operator=( const Complex3& a)'
    # ex2 : 'A::Complex3::Complex3( const Complex3& a)'
    # separe type de retour scope nom_fonction

    my $match_scope_nom_fonction = '';
    if ($impl_signature =~ /(.*(\w+))\s+((\w+).*?)\(/)
    {
        # ce n'est pas un constructeur
        my $match_type_retour = $1;
        $match_scope_nom_fonction = $3;
        print STDERR "=>match_type_retour:$match_type_retour\n" if ($debug);               # traces_filter_line
        print STDERR "=>match_scope_nom_fonction:$match_scope_nom_fonction\n" if ($debug); # traces_filter_line
    }
    elsif ($impl_signature =~ /(.*?)\(/)
    {
        # c'est un constructeur
        $match_scope_nom_fonction = $1;
        print STDERR "=>match_scope_nom_fonction:$match_scope_nom_fonction\n" if ($debug); # traces_filter_line
    }

    if ($match_scope_nom_fonction =~ /((\s*\w+\s*::)+)/)
    {
        my $match_scope_class = $1;
        $match_scope_class =~ s/^\s*//; # nettoyage
        $match_scope_class =~ s/::$//;  # nettoyage
        $match_scope_class =~ s/\s//g;  # nettoyage
        $scope_class = $match_scope_class;
        print STDERR "=>scope_class:$scope_class\n" if ($debug); # traces_filter_line
    }

    return $scope_class;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Extrait le nom de la class a partir du scope de la classe
#-------------------------------------------------------------------------------
sub ExtractClassNameFromScopeClass($)
{
    my ($scope_class) = @_;
    my $class_name = '';

    if ($scope_class =~ /(?::)?(\w+)$/)
    {
        $class_name = $1;
    }

    return $class_name;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Recuper le namespace et l'arborescence des classes
#-------------------------------------------------------------------------------
sub RecupScopeNamespaceClass(@)
{
    my (@match_pos_start) = @_;
    # recupere le scope de la classe dans la pile
    my $scope_class = '';

    my $stackSize = @match_pos_start;
    for (my $i = $stackSize - 1; $i >= 0; $i--)
    {
        if ($match_pos_start[$i] =~ /class|struct/)
        {
            my $one_scope_class = $match_pos_start[$i];
            $one_scope_class =~ s/.*?:(\w+):.*/$1/;

            if ($scope_class eq '')
            {
                $scope_class = $one_scope_class;
            }
            else
            {
                $scope_class = $one_scope_class . '::' . $scope_class;
            }
            # last;
        }
    }

    # recupere le scope du namespace dans la pile
    my $scope_namespace = '';
    for (my $i = $stackSize - 1; $i >= 0; $i--)
    {
        if ($match_pos_start[$i] =~ /namespace/)
        {
            $scope_namespace = $match_pos_start[$i];
            $scope_namespace =~ s/.*?:(\w+):.*/$1/;
            last;
        }
    }
    return ($scope_namespace, $scope_class);
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# extrait un tableau contenant le prototype des fonctions avec implementation,
# le code associe et les informations associes
#-------------------------------------------------------------------------------
sub ExtractFunctionsMethodsCode($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;

    if ((not defined $vue->{'code_only'})
     || (not defined $vue->{'parsed_code'})
     || (not defined $vue->{'comment'}) )
#     || (length ($vue->{'code_only'}) != length ($vue->{'code'}))
#     || (length ($vue->{'comment'})   != length ($vue->{'code'})))
    {
#        assert (length ($vue->{'code_only'}) == length ($vue->{'code'})) if ($b_assert); # traces_filter_line
#       assert (length ($vue->{'comment'}) == length ($vue->{'code'})) if ($b_assert);   # traces_filter_line
        assert (defined $vue->{'code_only'}) if ($b_assert);                             # traces_filter_line
        assert (defined $vue->{'comment'}) if ($b_assert);                               # traces_filter_line
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    if  (length ($vue->{'code_only'}) != length ($vue->{$code_only_base})) {
      print STDERR "ERREUR FATALE : la vue 'code_only' n'a pas la meme taille que la vue $code_only_base.\n";
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
    }

    my $code = $vue->{'code'};
    my $code_only = $vue->{'code_only'};
    my @parsed_code = @{$vue->{'parsed_code'}};
    my $comment = $vue->{'comment'};

    my @flat_function_method;
    my @function_method;
    my @function_method_code_comment;

    my $stackSizeError = 0;
    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        assert (exists $hash_item{'uid'}); # traces_filter_line

        my $uid = $hash_item{'uid'};
        if ($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE)
        {
            my $line_number_1 = 0;                                                          # traces_filter_line
            $line_number_1 = $hash_item{'line_number'} if ($b_TraceDetect);                 # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            print STDERR "#### line : $line_number_1\n" if ($debug);                        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                                           # traces_filter_line
            print STDERR "=>PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE\n" if ($debug); # traces_filter_line
            assert (exists $hash_item{'start_pos'});                                      # traces_filter_line
            my $start_pos = $hash_item{'start_pos'};
            assert (exists $hash_item{'end_pos'});                                        # traces_filter_line
            my $end_pos =$hash_item{'end_pos'};                                           # traces_filter_line

            push (@flat_function_method, [PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE, $start_pos, $item]);
        }
        elsif ($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE_END)
        {
            my $line_number = 0;                                                              # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect);                     # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};                                                    # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);                            # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                                            # traces_filter_line
            print STDERR "=>PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE_END\n" if ($debug); # traces_filter_line
            assert (exists $hash_item{'start_pos'});                                          # traces_filter_line
            my $start_pos = $hash_item{'start_pos'};                                          # traces_filter_line
            assert (exists $hash_item{'end_pos'});                                            # traces_filter_line
            my $end_pos =$hash_item{'end_pos'};

            push (@flat_function_method, [PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE_END, $end_pos]);
        }
    }

    my $flatFunctionNumber = @flat_function_method;
    print STDERR "stackSize flat_function_method:$flatFunctionNumber\n" if ($debug); # traces_filter_line

    if ($flatFunctionNumber % 2 == 0)
    {
        for (my $i = 0; $i < $flatFunctionNumber; $i += 2)
        {
            # deux par deux
            if (($flat_function_method[$i][0]     != PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE)
             || ($flat_function_method[$i + 1][0] != PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE_END))
            {
                $stackSizeError = 1;
            }
            else
            {
                my $function_start_pos = $flat_function_method[$i][1];
                my $function_prototype = $flat_function_method[$i][2];
                my $function_end_pos = $flat_function_method[$i + 1][1];
                my $item = [$function_start_pos, $function_end_pos, $function_prototype];
                push (@function_method, $item);
            }
        }

        # recupere le code de la fonction/methode
        foreach my $function (@function_method)
        {
            my $function_start_pos = $function->[0];
            my $function_end_pos = $function->[1];
            my $function_prototype = $function->[2];
            my $function_length = $function_end_pos - $function_start_pos + 1;
            my $function_code = substr ($code_only, $function_start_pos, $function_length);
            my $function_nb_lines_of_code = () = $function_code =~ /\n/g;
            $function_nb_lines_of_code++;

            my $function_comment=undef;
            my $function_nb_lines_of_comment=0;

            print STDERR "#########################\n" if ($debug);                                  # traces_filter_line
            print STDERR "$function_prototype\n" if ($debug);                                        # traces_filter_line
            print STDERR "#\n" if ($debug);                                                          # traces_filter_line
            print STDERR "function_nb_lines_of_code:$function_nb_lines_of_code\n" if ($debug);       # traces_filter_line
            print STDERR "$function_code\n" if ($debug);                                             # traces_filter_line
            print STDERR "#\n" if ($debug);                                                          # traces_filter_line

            my $function_code_line_number_start = TraceDetect::CalcLineMatch ($code_only, $function_start_pos) if ($b_TraceDetect); # traces_filter_line
            my $function_code_line_number_end = TraceDetect::CalcLineMatch ($code_only, $function_end_pos) if ($b_TraceDetect);     # traces_filter_line

            my %hash_item_ft;
            $hash_item_ft{'function_prototype'} = $function_prototype;
            $hash_item_ft{'function_code'} = $function_code;
            $hash_item_ft{'function_comment'} = $function_comment;
            $hash_item_ft{'function_code_line_number_start'} = $function_code_line_number_start if ($b_TraceDetect); # traces_filter_line
            $hash_item_ft{'function_code_line_number_end'} = $function_code_line_number_end if ($b_TraceDetect);     # traces_filter_line
            $hash_item_ft{'function_nb_lines_of_code'} = $function_nb_lines_of_code;
            $hash_item_ft{'function_nb_lines_of_comment'} = $function_nb_lines_of_comment;
            push (@function_method_code_comment, \%hash_item_ft);
        }
    }
    else
    {
        $stackSizeError = 1;
    }
    if ($stackSizeError == 1)
    {
        $status |= Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
        Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'comptage!!!!', ''); # traces_filter_line
    }
    else
    {
        $vue->{'function_method_code_comment'} = \@function_method_code_comment;
    }

    if (not defined $vue->{'function_method_code_comment'}) {
      print STDERR "ATTENTION vue function_method_code_comment non disponible.\n";
    }
    my $functionNumber = @function_method;                           # traces_filter_line
    print STDERR "nb function_method:$functionNumber\n" if ($debug); # traces_filter_line

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Analyse les declarations de variables
#-------------------------------------------------------------------------------
sub ParseVariables($$$$$$$$)
{
    my ($fichier, $compteurs, $options, $match_to_analyse, $ref_parse_items, $ref_hash_item, $ref_visibilities, $kind) = @_;
    my %hash_item = %$ref_hash_item; # duplication locale
    my @visibilities = @$ref_visibilities;

    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    assert (exists $hash_item{'line_number'}) if ($b_TraceDetect);     # traces_filter_line
    my $line_number = $hash_item{'line_number'} if ($b_TraceDetect);   # traces_filter_line
    my $status = 0;

    my $match_all = $match_to_analyse;
    $match_all =~ s/\s*;//;
    # supprime les ',' relatifs aux templates comme :
    # Array<CVide, CVide> toto;
    my $match_all_clean = $match_all;

    while ($match_all_clean =~ s/<[^<]*?>/ /g ) {}    # supprime les templates
    $match_all_clean =~ s/\btemplate\b\s*/ /;         # supprime les templates
    while ($match_all_clean =~ s/\([^\(]*?\)/ /g ) {} # supprime les parametres des appels de fonction (initialisation)

    if ($match_all_clean =~ /\bextern\b/)
    {
        $hash_item{'b_variable_membre'} = 0;
        return; #variables externes ne sont pas prises en compte
    }

    my $cur_class_visibility;
    if (@visibilities > 0)
    {
        # dans une classe, une struct ou init var avec accolade
        $cur_class_visibility = $visibilities[-1];  # dernier elt
        if (($cur_class_visibility eq 'var_glob_struct_init_accol')
         || ($cur_class_visibility eq 'var_glob_init_accol'))
        {
            if ($match_all_clean =~ /\bstatic\b/)
            {
                $cur_class_visibility = 'file_global';
            }
            elsif ($match_all_clean =~ /::\s*(\w+)\s*=/)
            {
                # initialisation de variable membre statique, c'est du code
                my $variableName = $1;                                                            # traces_filter_line
                print STDERR "=> init de variable membre statique : $variableName\n" if ($debug); # traces_filter_line

                # c'est du code, pas pris en compte
                return;
            }
            else
            {
                $cur_class_visibility = 'app_global';
            }
        }
    }
    else
    {
        # pas de visibilite : variable globale
        if ($match_all_clean =~ /\bstatic\b/)
        {
            $cur_class_visibility = 'file_global';
        }
        elsif ($match_all_clean =~ /::\s*(\w+)\s*=/)
        {
            # initialisation de variable membre statique, c'est du code
            my $variableName = $1;                                                            # traces_filter_line
            print STDERR "=> init de variable membre statique : $variableName\n" if ($debug); # traces_filter_line

            # c'est du code, pas pris en compte
            return;
        }
        else
        {
            $cur_class_visibility = 'app_global';
        }
    }

    # compte les separateurs de variable
    my $comaNumber = () = $match_all_clean =~ /,/g;
    # separe decl multiple de variables comme :
    # private int reel, reel2;
    my @var = split (',\s*', $match_all_clean);

    #--------------------------------------------------
    # TYPE + First variable
    #--------------------------------------------------

    # extrait le type comme :
    # protected String[][] tableau;
    my $type_var = $var[0];

    print STDERR "type_var:$type_var\n" if ($debug); # traces_filter_line

    my $type = '';
    my $var1_name = '';
    my $crochets = '';
    if ($type_var =~ /(\[.*\])/)
    {
        $crochets = $1; # recupere les crochets pour les tableaux
        $type_var =~ s/\[.*\]//; # supprime les crochets
    }

    # FIX CAST : did not work in case of an initialisation : int a = 0;
    #  OLD : if ($type_var =~ /^(.*)\s(\w+)$/)
    if ($type_var =~ /^(.*)\s+(\w+)(\s*=.*)?$/s)
    {
       $type = $1 . $crochets;
       $var1_name = $2;
       print "type = $type\n" if ($debug);           # traces_filter_line
       print "var1_name = $var1_name\n" if ($debug); # traces_filter_line
       $var[0] = $var1_name;
    }

    $hash_item{'var_type'} = $type;
    $hash_item{'b_variable_membre'} = 0;

    if (($cur_class_visibility eq 'public') || ($cur_class_visibility eq 'private')
     || ($cur_class_visibility eq 'protected'))
    {
        $hash_item{'b_variable_membre'} = 1;
    }

    $hash_item{'var_visibility'} = $cur_class_visibility;

    # ligne entiere de declaration de variables
    #------------------------------------------
    my %hash_item_full_line = %hash_item; # duplication
    push (@$ref_parse_items, [PARSER_CPP_DECLARATION_VARIABLE_FULL_LINE, \%hash_item_full_line]);

    #--------------------------------------------------
    # OTHER VARIABLES.
    #--------------------------------------------------
    
    # declaration variable par variable
    for (my $i = 1; $i <= ($comaNumber + 1); $i++)
    {
        my $var_name = $var[$i - 1];
        print STDERR "type:$type\n" if ($debug);                                                               # traces_filter_line
        print STDERR "var_name:$var_name\n" if ($debug);                                                       # traces_filter_line
        print STDERR "cur_class_visibility:$cur_class_visibility\n" if ($debug);                               # traces_filter_line
        my $trace_line = "$base_filename:$line_number:$cur_class_visibility:$match_all\n" if ($b_TraceDetect); # traces_filter_line

        $hash_item{'var_name'} = $var_name;
        my %hash_item2 = %hash_item; # duplication
        push (@$ref_parse_items, [$kind, \%hash_item2]);
    }
}

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# DESCRIPTION: LES MODULES DE COMPTAGE
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

# bt_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage de nommage des classes
# Module de comptage de longueur min des noms de classes
#-------------------------------------------------------------------------------
use constant LIMIT_SHORT_CLASS_NAMES_LT => 10;
use constant LIMIT_SHORT_CLASS_NAMES_HT => 15;

sub Count_ClassNaming($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    # nommage des classes
    my $nbr_ShortClassNamesLT = 0;
    my $mnemo_ShortClassNamesLT = Ident::Alias_ShortClassNamesLT();
    my $trace_detect_ShortClassNamesLT = '' if ($b_TraceDetect); # traces_filter_line

    my $nbr_ShortClassNamesHT = 0;
    my $mnemo_ShortClassNamesHT = Ident::Alias_ShortClassNamesHT();
    my $trace_detect_ShortClassNamesHT = '' if ($b_TraceDetect); # traces_filter_line

    my $nbr_BadClassNames = 0;
    my $mnemo_BadClassNames = Ident::Alias_BadClassNames();
    my $trace_detect_BadClassNames = '' if ($b_TraceDetect);     # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert);   # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_ShortClassNamesLT, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_ShortClassNamesHT, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_BadClassNames, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    my $pattern_bad_class_names = '^([A-Z][a-z]*)?([A-Z][a-z]+)+$';

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        if (($kind == PARSER_CPP_DECLARATION_CLASS)
         || ($kind == PARSER_CPP_TEMPLATE_CLASSE))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'class_name'});                     # traces_filter_line

            my $match_class_name = $hash_item{'class_name'};
            my $length = length ($match_class_name);

            my $trace_line = "$base_filename:$line_number:$item:$length\n" if ($b_TraceDetect); # traces_filter_line

            if ($length < LIMIT_SHORT_CLASS_NAMES_LT)
            {
                $nbr_ShortClassNamesLT++;
                $trace_detect_ShortClassNamesLT .= $trace_line if ($b_TraceDetect); # traces_filter_line
            }
            if ($length < LIMIT_SHORT_CLASS_NAMES_HT)
            {
                $nbr_ShortClassNamesHT++;
                $trace_detect_ShortClassNamesHT .= $trace_line if ($b_TraceDetect); # traces_filter_line
            }

            if (not ($match_class_name =~ /$pattern_bad_class_names/))
            {
                $nbr_BadClassNames++;
                $trace_detect_BadClassNames .= $trace_line if ($b_TraceDetect);     # traces_filter_line
            }
        }
    }

    print STDERR "$mnemo_ShortClassNamesLT = $nbr_ShortClassNamesLT\n" if ($debug);                                                # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ShortClassNamesLT, $trace_detect_ShortClassNamesLT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ShortClassNamesLT, $nbr_ShortClassNamesLT);

    print STDERR "$mnemo_ShortClassNamesHT = $nbr_ShortClassNamesHT\n" if ($debug);                                                # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ShortClassNamesHT, $trace_detect_ShortClassNamesHT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ShortClassNamesHT, $nbr_ShortClassNamesHT);

    print STDERR "$mnemo_BadClassNames = $nbr_BadClassNames\n" if ($debug);                                                # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_BadClassNames, $trace_detect_BadClassNames, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_BadClassNames, $nbr_BadClassNames);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage de nommage des attributs
# Module de comptage de longueur min des noms d'attributs
#-------------------------------------------------------------------------------
use constant LIMIT_SHORT_ATTRIBUTE_NAMES_LT => 6;
use constant LIMIT_SHORT_ATTRIBUTE_NAMES_HT => 10;

sub Count_AttributeNaming($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    # nommage des attributs
    my $nbr_ShortAttributeNamesLT = 0;
    my $mnemo_ShortAttributeNamesLT = Ident::Alias_ShortAttributeNamesLT();
    my $trace_detect_ShortAttributeNamesLT = '' if ($b_TraceDetect); # traces_filter_line

    my $nbr_ShortAttributeNamesHT = 0;
    my $mnemo_ShortAttributeNamesHT = Ident::Alias_ShortAttributeNamesHT();
    my $trace_detect_ShortAttributeNamesHT = '' if ($b_TraceDetect); # traces_filter_line

    my $nbr_BadAttributeNames = 0;
    my $mnemo_BadAttributeNames = Ident::Alias_BadAttributeNames();
    my $trace_detect_BadAttributeNames = '' if ($b_TraceDetect);     # traces_filter_line
    # FIXME: AD: a optimiser avec une fonction 'qr' finissant par 'o'
    my $pattern_bad_attribute_names_var = '^m?_[a-z]*([A-Z][a-z]+)*$';

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_ShortAttributeNamesLT, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_ShortAttributeNamesHT, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_BadAttributeNames, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        if ($kind == PARSER_CPP_DECLARATION_VARIABLE)
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists($hash_item{'b_variable_membre'}));             # traces_filter_line
            my $b_variable_membre = $hash_item{'b_variable_membre'};
            assert (exists($hash_item{'var_type'}));                      # traces_filter_line
            my $type = $hash_item{'var_type'};
            print STDERR "type:$type\n" if ($debug);                      # traces_filter_line
            assert (exists($hash_item{'var_name'}));                      # traces_filter_line
            my $name = $hash_item{'var_name'};
            print STDERR "name:$name\n" if ($debug);                      # traces_filter_line

            if ($b_variable_membre == 0)
            {
                next;
            }

            my $attribute_name = $name;
            if (length ($attribute_name) < LIMIT_SHORT_ATTRIBUTE_NAMES_LT)
            {
                $nbr_ShortAttributeNamesLT++;

                my $trace_line = "$base_filename:$line_number:$type:$attribute_name\n" if ($b_TraceDetect); # traces_filter_line
                $trace_detect_ShortAttributeNamesLT .= $trace_line if ($b_TraceDetect);                     # traces_filter_line
            }

            if (length ($attribute_name) < LIMIT_SHORT_ATTRIBUTE_NAMES_HT)
            {
                $nbr_ShortAttributeNamesHT++;

                my $trace_line = "$base_filename:$line_number:$type:$attribute_name\n" if ($b_TraceDetect); # traces_filter_line
                $trace_detect_ShortAttributeNamesHT .= $trace_line if ($b_TraceDetect);                     # traces_filter_line
            }

            if (not ($attribute_name =~ /$pattern_bad_attribute_names_var/))
            {
                # pour les autres variables
                $nbr_BadAttributeNames++;

                my $trace_line = "$base_filename:$line_number:$type:$attribute_name:\n" if ($b_TraceDetect); # traces_filter_line
                $trace_detect_BadAttributeNames .= $trace_line if ($b_TraceDetect);                          # traces_filter_line
            }
        }
    }

    print STDERR "$mnemo_ShortAttributeNamesLT = $nbr_ShortAttributeNamesLT\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ShortAttributeNamesLT, $trace_detect_ShortAttributeNamesLT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ShortAttributeNamesLT, $nbr_ShortAttributeNamesLT);

    print STDERR "$mnemo_ShortAttributeNamesHT = $nbr_ShortAttributeNamesHT\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ShortAttributeNamesHT, $trace_detect_ShortAttributeNamesHT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ShortAttributeNamesHT, $nbr_ShortAttributeNamesHT);

    print STDERR "$mnemo_BadAttributeNames = $nbr_BadAttributeNames\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_BadAttributeNames, $trace_detect_BadAttributeNames, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_BadAttributeNames, $nbr_BadAttributeNames);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage de nommage des methodes
# Module de comptage de longueur min des noms de methodes
#-------------------------------------------------------------------------------
use constant LIMIT_SHORT_METHOD_NAMES_LT => 7;
use constant LIMIT_SHORT_METHOD_NAMES_HT => 10;

sub Count_MethodNaming($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    # nommage des methodes
    my $nbr_ShortMethodNamesLT = 0;
    my $mnemo_ShortMethodNamesLT = Ident::Alias_ShortMethodNamesLT();
    my $trace_detect_ShortMethodNamesLT = '' if ($b_TraceDetect); # traces_filter_line

    my $nbr_ShortMethodNamesHT = 0;
    my $mnemo_ShortMethodNamesHT = Ident::Alias_ShortMethodNamesHT();
    my $trace_detect_ShortMethodNamesHT = '' if ($b_TraceDetect); # traces_filter_line

    my $nbr_BadMethodNames = 0;
    my $mnemo_BadMethodNames = Ident::Alias_BadMethodNames();
    my $trace_detect_BadMethodNames = '' if ($b_TraceDetect); # traces_filter_line

    my $pattern_BadMethodNames = '^([a-z]+([A-Z][a-z]+)*)?$'; # vide pour operator

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_ShortMethodNamesLT, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_ShortMethodNamesHT, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_BadMethodNames, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        if (($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_PROTOTYPE_KR))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'method_name'});                    # traces_filter_line

            my $matchMethodName = $hash_item{'method_name'};
            my $length = length ($matchMethodName);

            my $trace_line = "$base_filename:$line_number:$item:$matchMethodName:$length\n" if ($b_TraceDetect); # traces_filter_line

            if (($length != 0) && ($matchMethodName ne 'main'))
            {
                # main est exclue et la chaine est non vide (sinon c'est un operateur)
                if ($length < LIMIT_SHORT_METHOD_NAMES_LT)
                {
                    $nbr_ShortMethodNamesLT++;
                    $trace_detect_ShortMethodNamesLT .= $matchMethodName . ' dans: ' . $trace_line if ($b_TraceDetect); # traces_filter_line
                }
                if ($length < LIMIT_SHORT_METHOD_NAMES_HT)
                {
                    $nbr_ShortMethodNamesHT++;
                    $trace_detect_ShortMethodNamesHT .= $matchMethodName . ' dans: ' . $trace_line if ($b_TraceDetect); # traces_filter_line
                }
                if ($matchMethodName !~ /$pattern_BadMethodNames/)
                {
                    $nbr_BadMethodNames++;
                    $trace_detect_BadMethodNames .= $matchMethodName . ' dans: ' . $trace_line if ($b_TraceDetect);     # traces_filter_line
                }
            }
        }
    }

    print STDERR "$mnemo_ShortMethodNamesLT = $nbr_ShortMethodNamesLT\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ShortMethodNamesLT, $trace_detect_ShortMethodNamesLT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ShortMethodNamesLT , $nbr_ShortMethodNamesLT);

    print STDERR "$mnemo_ShortMethodNamesHT = $nbr_ShortMethodNamesHT\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ShortMethodNamesHT, $trace_detect_ShortMethodNamesHT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ShortMethodNamesHT , $nbr_ShortMethodNamesHT);

    print STDERR "$mnemo_BadMethodNames = $nbr_BadMethodNames\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_BadMethodNames, $trace_detect_BadMethodNames, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_BadMethodNames , $nbr_BadMethodNames);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage de longueur min des noms de fonctions
#-------------------------------------------------------------------------------
use constant LIMIT_SHORT_FUNCTION_NAMES_LT => 7;
use constant LIMIT_SHORT_FUNCTION_NAMES_HT => 10;

sub Count_FunctionNaming($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    # nommage des fonctions
    my $nbr_ShortFunctionNamesLT = 0;
    my $mnemo_ShortFunctionNamesLT = Ident::Alias_ShortFunctionNamesLT();
    my $trace_detect_ShortFunctionNamesLT = '' if ($b_TraceDetect); # traces_filter_line

    my $nbr_short_ShortFunctionNamesHT = 0;
    my $mnemo_ShortFunctionNamesHT = Ident::Alias_ShortFunctionNamesHT();
    my $trace_detect_ShortFunctionNamesHT = '' if ($b_TraceDetect); # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_ShortFunctionNamesLT, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_ShortFunctionNamesHT, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        if (($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_PROTOTYPE_KR))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'method_name'});                    # traces_filter_line

            my $match_function_name = $hash_item{'method_name'};
            my $length = length ($match_function_name);

            my $trace_line = "$base_filename:$line_number:$item:$match_function_name:$length\n" if ($b_TraceDetect); # traces_filter_line

            my $b_main = ($match_function_name eq 'main'); # exclure main
            if (($length != 0) && ($length< LIMIT_SHORT_FUNCTION_NAMES_LT) && not $b_main) # vide pour operator
            {
                $nbr_ShortFunctionNamesLT++;
                $trace_detect_ShortFunctionNamesLT .= $trace_line if ($b_TraceDetect); # traces_filter_line
                Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_ShortFunctionNamesLT, $match_function_name);
            }

            if (($length != 0) && ($length < LIMIT_SHORT_FUNCTION_NAMES_HT)  && not $b_main) # vide pour operator
            {
                $nbr_short_ShortFunctionNamesHT++;
                $trace_detect_ShortFunctionNamesHT .= $trace_line if ($b_TraceDetect); # traces_filter_line
                Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_ShortFunctionNamesHT, $match_function_name);
            }

            Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, 'Nbr_ShortFunctionNames', $match_function_name);
        }
    }

    print STDERR "$mnemo_ShortFunctionNamesLT = $nbr_ShortFunctionNamesLT\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ShortFunctionNamesLT, $trace_detect_ShortFunctionNamesLT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ShortFunctionNamesLT, $nbr_ShortFunctionNamesLT);

    print STDERR "$mnemo_ShortFunctionNamesHT = $nbr_short_ShortFunctionNamesHT\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ShortFunctionNamesHT, $trace_detect_ShortFunctionNamesHT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ShortFunctionNamesHT, $nbr_short_ShortFunctionNamesHT);

    return $status;
}
# bt_filter_end
#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de constructeur par copie
# et d'operateur d'affectation dont l'argument n'est pas une ref constante
# (declaration et implementation)
#-------------------------------------------------------------------------------
sub Count_OperatorsParamNotAsConstRef($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;

    my $nbr_WithNotConstRefParametersOperators = 0;
    my $mnemo_WithNotConstRefParametersOperators = Ident::Alias_WithNotConstRefParametersOperators();
    my $trace_detect_WithNotConstRefParametersOperators = '' if ($b_TraceDetect); # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_WithNotConstRefParametersOperators, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        my $parameterNumber = 0;
        my @parameters;
        if (($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            assert (exists $hash_item{'b_dtor'});                         # traces_filter_line
            my $b_ctor = $hash_item{'b_ctor'};
            assert (exists $hash_item{'b_method_operator'});              # traces_filter_line
            my $b_method_operator = $hash_item{'b_method_operator'};

            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line

            # supprime les parametres template
            my $item_no_template = $item;
            while ($item_no_template =~ s/<[^<]*?>/ /g ) {}
            if ($item_no_template =~ /\((.*)\)/)
            {
                my $parametersString = $1;
                if ($parametersString =~ /^\s*$/)
                {
                    # pas de parametre
                    $parameterNumber = 0;
                }
                else
                {
                    # au moins un parametre
                    @parameters = split (',', $parametersString);
                    print STDERR "parameters:@parameters\n" if ($debug); # traces_filter_line
                    $parameterNumber = @parameters;
                }
            }

            print STDERR "parameterNumber : $parameterNumber \n" if ($debug); # traces_filter_line

            if ($parameterNumber == 1)
            {
                # les 2 cas a trouver n'ont qu'un seul parametre
                if ($b_ctor == 1)
                {
                    # 1er cas : construteur par copy  ex ok : 'Complex( const Complex& a)'
                    print STDERR "test : construteur par copy ? \n" if ($debug); # traces_filter_line

                    my $parameter = $parameters [0];
                    if ($item =~ /(\w+)\s*\(/)
                    {
                        my $match_ctor_name = $1;
                        if ($parameter =~ /\b$match_ctor_name\b/)
                        {
                            # il s'agit bien du constructeur par copie (parametre meme type que classe)
                            if (not $parameter =~ /^\s*const\s+$match_ctor_name\s*&/)
                            {
                                $nbr_WithNotConstRefParametersOperators++;
                                $trace_detect_WithNotConstRefParametersOperators .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                                print STDERR "nbr_operator_param_not_as_const_ref : $nbr_WithNotConstRefParametersOperators \n" if ($debug); # traces_filter_line
                            }
                        }
                    }
                }
                elsif ($b_method_operator == 1)
                {
                    # 2eme cas : l'operateur d'assignation ex ok :
                    # -ds une classe :          'Complex operator=( const Complex& a)'
                    # -en dehors d'une classe : 'Complex2& Complex2::operator=( const Complex2& a)'

                    print STDERR "test : operateur assignation ? \n" if ($debug); # traces_filter_line

                    if ($item =~ /(\w+)\s*&?\s*\boperator\s*=\s*\(/)
                    {
                        # dans une classe
                        my $match_class_name = $1;

                        my $parameter = $parameters [0];
                        if ($parameter =~ /\b$match_class_name\b/)
                        {
                            # il s'agit bien de l'operateur d'affectation (parametre meme type que classe)
                            if (not ($parameter =~ /^\s*const\s+$match_class_name\s*&/))
                            {
                                $nbr_WithNotConstRefParametersOperators++;
                                $trace_detect_WithNotConstRefParametersOperators .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                                print STDERR "nbr_operator_param_not_as_const_ref : $nbr_WithNotConstRefParametersOperators \n" if ($debug); # traces_filter_line
                            }
                        }
                    }
                    elsif ($item =~ /(\w+)\s*::\s*operator\s*=\s*\(/)
                    {
                        # en dehors d'une classe
                        my $match_class_name = $1;

                        my $parameter = $parameters [0];
                        if ($parameter =~ /\b$match_class_name\b/)
                        {
                            # il s'agit bien de l'operateur d'affectation (parametre meme type que classe)
                            if (not ($parameter =~ /^\s*const\s+$match_class_name\s*&/))
                            {
                                $nbr_WithNotConstRefParametersOperators++;
                                $trace_detect_WithNotConstRefParametersOperators .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                                print STDERR "nbr_operator_param_not_as_const_ref : $nbr_WithNotConstRefParametersOperators \n" if ($debug); # traces_filter_line
                            }
                        }
                    }
                }
                else
                {
                    print STDERR "test : dafaut rien\n" if ($debug); # traces_filter_line
                }
            }
        }
    }

    print STDERR "$mnemo_WithNotConstRefParametersOperators = $nbr_WithNotConstRefParametersOperators\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_WithNotConstRefParametersOperators, $trace_detect_WithNotConstRefParametersOperators, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_WithNotConstRefParametersOperators, $nbr_WithNotConstRefParametersOperators);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de surcharge d'operateurs '&&' '||' ','
# Module de comptage du nombre de surcharge d'operateurs qui doivent
# retourner un objet au lieu d'une reference (a&b, a^b, a|b, ~a, a!=b, a<=b,
# a<b, a==b, a>=b, a>b, # a!b, a&&b, a||b, +a, -a, a%b, a*b, a+b, a-b, a/b)
#-------------------------------------------------------------------------------
my @liste_operators = qw {& ^ | ~ != <= < == >= > ! && || + - % * + - /};

sub Count_ForbiddenOverloadedOperators($$$$) {
    my ($fichier, $vue, $compteurs, $options) = @_;
    return __Count_OverloadedOperators($fichier, $vue, $compteurs, $options, 'Hpp');
}

sub Count_ForbiddenReferenceReturningOperators($$$$) {
    my ($fichier, $vue, $compteurs, $options) = @_;
    return __Count_OverloadedOperators($fichier, $vue, $compteurs, $options, 'Cpp');
}

sub __Count_OverloadedOperators($$$$$)
{
    my ($fichier, $vue, $compteurs, $options, $langage) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    my $b_analyse_cpp = ($langage eq 'Cpp');
    my $b_analyse_hpp = ($langage eq 'Hpp');
    my $b_all_counters = ((exists $options->{'--allcounters'})? 1 : 0);

    my $nbr_ForbiddenOverloadedOperators = 0;
    my $mnemo_ForbiddenOverloadedOperators = Ident::Alias_ForbiddenOverloadedOperators();
    my $trace_detect_ForbiddenOverloadedOperators = '' if ($b_TraceDetect); # traces_filter_line

    my $nbr_ForbiddenReferenceReturningOperators = 0;
    my $mnemo_ForbiddenReferenceReturningOperators = Ident::Alias_ForbiddenReferenceReturningOperators();
    my $trace_detect_ForbiddenReferenceReturningOperators = '' if ($b_TraceDetect); # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        if ($b_all_counters || $b_analyse_hpp)
        {
            $status |= Couples::counter_add ($compteurs, $mnemo_ForbiddenOverloadedOperators, Erreurs::COMPTEUR_ERREUR_VALUE);
        }
        if ($b_analyse_cpp)
        {
            $status |= Couples::counter_add ($compteurs, $mnemo_ForbiddenReferenceReturningOperators, Erreurs::COMPTEUR_ERREUR_VALUE);
        }
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    my @liste_operators_escape;
    foreach my $op (@liste_operators)
    {
        my $local_op = $op;
        $local_op =~ s/(\^)/\\$1/g; # pour '^'
        $local_op =~ s/(\|)/\\$1/g; # pour '|'
        $local_op =~ s/(\*)/\\$1/g; # pour '*'
        $local_op =~ s/(\+)/\\$1/g; # pour '+'
        push (@liste_operators_escape, $local_op);
    }

    my $pattern = join('|', @liste_operators_escape);

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        if (($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line

            assert (exists $hash_item{'b_method_operator'});              # traces_filter_line

            my $b_method_operator = $hash_item{'b_method_operator'};
            # supprime les parametres template
            my $item_no_template = $item;
            while ($item_no_template =~ s/<[^<]*?>/ /g ) {}
            if ($b_method_operator == 1)
            {
                if ($item_no_template =~ /\boperator\s*(&&|\|\||,)\s*\(/)
                {
                    my $match_operators = $1;

                    $nbr_ForbiddenOverloadedOperators++;
                    $trace_detect_ForbiddenOverloadedOperators .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                    print STDERR "nbr_forbidden_overloaded_operator : $nbr_ForbiddenOverloadedOperators\n" if ($debug); # traces_filter_line
                }
                if ($item_no_template =~ /\boperator\b\s*($pattern)\s*\(/)
                {
                    my $match_operators = $1;
                    if ($item_no_template =~ /&.*?operator\b/)
                    {
                        $nbr_ForbiddenReferenceReturningOperators++;
                        $trace_detect_ForbiddenReferenceReturningOperators .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                        print STDERR "nbr_forbidden_reference_returning_operator : $nbr_ForbiddenReferenceReturningOperators\n" if ($debug); # traces_filter_line
                    }
                }
            }
        }
    }

# print "b_all_counters = $b_all_counters\n";
# print "b_analyse_hpp = $b_analyse_hpp\n";

    if ($b_all_counters || $b_analyse_hpp)
    {
        print STDERR "$mnemo_ForbiddenOverloadedOperators = $nbr_ForbiddenOverloadedOperators\n" if ($debug); # traces_filter_line
        TraceDetect::DumpTraceDetect ($fichier, $mnemo_ForbiddenOverloadedOperators, $trace_detect_ForbiddenOverloadedOperators, $options) if ($b_TraceDetect); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_ForbiddenOverloadedOperators, $nbr_ForbiddenOverloadedOperators);
    }

    if ($b_analyse_cpp)
    {
        print STDERR "$mnemo_ForbiddenReferenceReturningOperators = $nbr_ForbiddenReferenceReturningOperators\n" if ($debug); # traces_filter_line
        TraceDetect::DumpTraceDetect ($fichier, $mnemo_ForbiddenReferenceReturningOperators, $trace_detect_ForbiddenReferenceReturningOperators, $options) if ($b_TraceDetect); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_ForbiddenReferenceReturningOperators, $nbr_ForbiddenReferenceReturningOperators);
    }

    return $status;
}

# bt_filter_start
#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de parametres total
# (declaration et implementation)
# Module de comptage du nombre de methodes avec trop de parametres
# (plus de 7) (declaration et implementation)
#-------------------------------------------------------------------------------
use constant SEUIL_MAX_NB_PARAM => 7;
sub Count_Parameters($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    # methodes avec trop de parametres
    my $nbr_WithTooMuchParametersMethods = 0;
    my $mnemo_WithTooMuchParametersMethods = Ident::Alias_WithTooMuchParametersMethods();
    my $trace_detect_WithTooMuchParametersMethods = '' if ($b_TraceDetect); # traces_filter_line
    # nombre total de parametres
    my $nbr_totalParameters = 0;
    my $mnemo_totalParameters = Ident::Alias_TotalParameters();
    my $trace_detect_total_parameters = '' if ($b_TraceDetect); # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_WithTooMuchParametersMethods, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_totalParameters, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    my @liste_type_non_objet = split ("\\s+", LISTE_TYPE_NON_OBJET);
    my %hash_type_non_objets;
    foreach my $type (@liste_type_non_objet)
    {
        $hash_type_non_objets{"$type"} = 1;
    }

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;
        my $parameterNumber = 0;
        my @parameters;
        if (($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_PROTOTYPE_KR))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line

            # supprime les parametres template
            my $item_no_template = $item;
            while ($item_no_template =~ s/<[^<]*?>/ /g ) {}
            if ($item_no_template =~ /\((.*)\)/)
            {
                my $parametersString = $1;
                if ($parametersString =~ /^\s*$/)
                {
                    # pas de parametre
                    $parameterNumber = 0;
                }
                else
                {
                    # au moins un parametre
                    @parameters = split (',', $parametersString);
                    print STDERR "parameters:@parameters\n" if ($debug); # traces_filter_line
                    $parameterNumber = @parameters;
                }
            }

            print STDERR "parameterNumber : $parameterNumber \n" if ($debug);  # traces_filter_line

            if ($parameterNumber > SEUIL_MAX_NB_PARAM)
            {
                $nbr_WithTooMuchParametersMethods++;
                $trace_detect_WithTooMuchParametersMethods .= "$base_filename:$line_number:$item:$parameterNumber\n" if ($b_TraceDetect); # traces_filter_line
            }

            $nbr_totalParameters += $parameterNumber;
            $trace_detect_total_parameters .= "$base_filename:$line_number:$item:$parameterNumber\n" if ($b_TraceDetect); # traces_filter_line
        }
    }

    print STDERR "$mnemo_WithTooMuchParametersMethods = $nbr_WithTooMuchParametersMethods\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_WithTooMuchParametersMethods, $trace_detect_WithTooMuchParametersMethods, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_WithTooMuchParametersMethods, $nbr_WithTooMuchParametersMethods);

    print STDERR "$mnemo_totalParameters = $nbr_totalParameters\n" if ($debug);                                                 # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_totalParameters, $trace_detect_total_parameters, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_totalParameters, $nbr_totalParameters);

    return $status;
}
# bt_filter_end
#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de methodes avec un parametre
# argument variable '...'  (declaration et implementation)
#-------------------------------------------------------------------------------
sub Count_VarArg($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    # methodes avec trop de parametres
    my $nbr_VariableArgumentMethods = 0;
    my $mnemo_VariableArgumentMethods = Ident::Alias_VariableArgumentMethods();
    my $trace_detect_VariableArgumentMethods = '' if ($b_TraceDetect); # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_VariableArgumentMethods, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    my @liste_type_non_objet = split ("\\s+", LISTE_TYPE_NON_OBJET);
    my %hash_type_non_objets;
    foreach my $type (@liste_type_non_objet)
    {
        $hash_type_non_objets{"$type"} = 1;
    }

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;
        my $parameterNumber = 0;
        my @parameters;
        if (($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_PROTOTYPE_KR))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line

            # supprime les parametres template
            my $item_no_template = $item;
            while ($item_no_template =~ s/<[^<]*?>/ /g ) {}

            if ($item_no_template =~ /\((.*)\)/)
            {
                my $parametersString = $1;
                if ($parametersString =~ /^\s*$/)
                {
                    # pas de parametre
                    $parameterNumber = 0;
                }
                else
                {
                    # au moins un parametre
                    @parameters = split (',', $parametersString);
                    print STDERR "parameters:@parameters\n" if ($debug); # traces_filter_line
                    $parameterNumber = @parameters;
                }
            }
            print STDERR "parameterNumber : $parameterNumber \n" if ($debug); # traces_filter_line
            # argument variable
            if ($item_no_template =~ /\.\.\.\s*\)/)
            {
                $nbr_VariableArgumentMethods++;
                $trace_detect_VariableArgumentMethods .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
            }
        }
    }

    print STDERR "$mnemo_VariableArgumentMethods = $nbr_VariableArgumentMethods\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_VariableArgumentMethods, $trace_detect_VariableArgumentMethods, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_VariableArgumentMethods, $nbr_VariableArgumentMethods);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de parametre objets passes
# par pointeur (declaration et implementation)
# Module de comptage du nombre de parametre objets passes par valeur
# (declaration et implementation)
#-------------------------------------------------------------------------------
sub Count_ParametersObjects($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    # parametres objets passés par pointeur
    my $nbr_PointerObjectParameters = 0;
    my $mnemo_PointerObjectParameters = Ident::Alias_PointerObjectParameters();
    my $trace_detect_PointerObjectParameters = '' if ($b_TraceDetect); # traces_filter_line
    # parametres objets passés par valeur
    my $nbr_ObjectParameters = 0;
    my $mnemo_ObjectParameters = Ident::Alias_ObjectParameters();
    my $trace_detect_ObjectParameters = '' if ($b_TraceDetect); # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_PointerObjectParameters, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_ObjectParameters, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    my @liste_type_non_objet = split ("\\s+", LISTE_TYPE_NON_OBJET);
    my %hash_type_non_objets;
    foreach my $type (@liste_type_non_objet)
    {
        $hash_type_non_objets{"$type"} = 1;
    }

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;
        my $parameterNumber = 0;
        my @parameters;
        if (($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_PROTOTYPE_KR))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line

            # supprime les parametres template
            my $item_no_template = $item;
            while ($item_no_template =~ s/<[^<]*?>/ /g ) {}

            if ($item_no_template =~ /\((.*)\)/)
            {
                my $parametersString = $1;
                if ($parametersString =~ /^\s*$/)
                {
                    # pas de parametre
                    $parameterNumber = 0;
                }
                else
                {
                    # au moins un parametre
                    @parameters = split (',', $parametersString);

                    print STDERR "parameters:@parameters\n" if ($debug); # traces_filter_line

                    $parameterNumber = @parameters;
                }
            }

            print STDERR "parameterNumber : $parameterNumber \n" if ($debug);  # traces_filter_line

            # parametre objet par pointeur
            my $param_number = 0;
            foreach my $parameter (@parameters)
            {
                $param_number++;
                if ($parameter =~ /\s*(.*)\s*\*/)
                {
                    # c'est un pointeur ex: 'const char* const* c'
                    my $parameterType = $1;    # jusqu'au dernier '*', on n'a pas le nom de variable si presente
                    my $parameterRootType = $parameterType;
                    $parameterRootType =~ s/[&\*]//g; # enleve les '*' du type
                    print STDERR "parameterRootType:$parameterRootType\n" if ($debug); # traces_filter_line
                    my @typenames = split ("\\s+", $parameterRootType);

                    print STDERR "typenames:" . join('/', @typenames) . " \n" if ($debug);         # traces_filter_line

                    my $StdCTypeFound = 0;

                    # verifie si c'est un type std du C ou assimile
                    foreach my $typename (@typenames)
                    {
                        # partie de parametre
                        print STDERR "typename:$typename\n" if ($debug); # traces_filter_line

                        if (exists $hash_type_non_objets{"$typename"})
                        {
                            $StdCTypeFound = 1;
                            last;
                        }
                    }

                    if ($StdCTypeFound == 0)
                    {
                        # c'est un objet passe par pointeur
                        $nbr_PointerObjectParameters++;
                        $trace_detect_PointerObjectParameters .= "$base_filename:$line_number:$item:n°$param_number:$parameterType*\n" if ($b_TraceDetect); # traces_filter_line
                    }
                }
            }

            # parametre objet par valeur
            $param_number = 0;
            foreach my $parameter (@parameters)
            {
                $param_number++;
                if (not ($parameter =~ /[&\*]/))
                {
                    # c'est un passage de parametre par valeur ex: 'const int i' ou 'Complex a'
                    my $cleanParameter = $parameter;    # jusqu'au dernier '*', on n'a pas le nom de variable si presente
                    $cleanParameter =~ s/const//g;
                    my @typenames = split ("\\s+", $cleanParameter);

                    print STDERR "typenames:" . join('/', @typenames) . " \n" if ($debug); # traces_filter_line

                    # verifie si c'est un type std du C ou assimile
                    my $StdCTypeFound = 0;
                    foreach my $typename (@typenames)
                    {
                        # partie de parametre
                        print STDERR "typename:$typename\n" if ($debug); # traces_filter_line

                        if (exists $hash_type_non_objets{"$typename"})
                        {
                            $StdCTypeFound=1;
                            last;
                        }
                    }

                    if ($StdCTypeFound == 0)
                    {
                        # c'est tres probablement un objet passe par pointeur
                        $nbr_ObjectParameters++;
                        $trace_detect_ObjectParameters .= "$base_filename:$line_number:$item:n°$param_number:$parameter\n" if ($b_TraceDetect); # traces_filter_line
                    }
                }
            }
        }
    }

    print STDERR "$mnemo_PointerObjectParameters = $nbr_PointerObjectParameters\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_PointerObjectParameters, $trace_detect_PointerObjectParameters, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_PointerObjectParameters, $nbr_PointerObjectParameters);

    print STDERR "$mnemo_ObjectParameters = $nbr_ObjectParameters\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ObjectParameters, $trace_detect_ObjectParameters, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ObjectParameters, $nbr_ObjectParameters);

    return $status;
}

# bt_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage des classes qui ne respectent pas l'ordre
# de declaration public/protected/private
#-------------------------------------------------------------------------------
sub CountBadDeclarationOrder(@);

sub Count_BadDeclarationOrder($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    # mauvais ordre de declaration
    my $nbr_BadDeclarationOrder = 0;
    my $mnemo_BadDeclarationOrder = Ident::Alias_BadDeclarationOrder();
    my $trace_detect_BadDeclarationOrder = "#class scope, kind:\n" if ($b_TraceDetect); # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_BadDeclarationOrder, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    my @class_scope_kind; #n°:[IRP(private), BUP(public), ORP(protected)]

    my $current_class_uid = 0;
    my $current_scope_class = '';
    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        assert (exists $hash_item{'uid'}); # traces_filter_line

        my $uid = $hash_item{'uid'};
        if (($kind == PARSER_CPP_DECLARATION_CLASS)
         || ($kind == PARSER_CPP_TEMPLATE_CLASSE))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            my $visibility = 'private';
            print STDERR "visibility=$visibility\n" if ($debug);          # traces_filter_line

            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};

            $current_class_uid = $uid;
            $current_scope_class = $scope_class;
            push (@class_scope_kind, [$scope_class,"classIRP"]);
            print STDERR "$scope_class,classIRP\n" if ($debug); # traces_filter_line
        }
        elsif (($kind == PARSER_CPP_DECLARATION_STRUCT)
            || ($kind == PARSER_CPP_TEMPLATE_STRUCT))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            my $visibility = 'public';
            print STDERR "visibility=$visibility\n" if ($debug);          # traces_filter_line

            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};

            $current_class_uid = $uid;
            $current_scope_class = $scope_class;
            push (@class_scope_kind, [$scope_class,"structBUP"]);

            print STDERR "$scope_class,structBUP\n" if ($debug); # traces_filter_line
        }
        elsif ($kind == PARSER_CPP_VISIBILITY)
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line

            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};
            assert (exists $hash_item{'visibility'});                     # traces_filter_line
            my $visibility = $hash_item{'visibility'};
            if ($visibility eq 'private')
            {
                push (@class_scope_kind, [$scope_class,"IRP"]);
                print STDERR "$scope_class,IRP\n" if ($debug); # traces_filter_line
            }
            elsif ($visibility eq 'public')
            {
                push (@class_scope_kind, [$scope_class,"BUP"]);
                print STDERR "$scope_class,BUP\n" if ($debug); # traces_filter_line
            }
            elsif ($visibility eq 'protected')
            {
                push (@class_scope_kind, [$scope_class,"ORP"]);
                print STDERR "$scope_class,ORP\n" if ($debug); # traces_filter_line
            }
        }
        elsif ($kind != PARSER_CPP_CLASS_END)
        {
            # traite le cas du premier element de la classe
            # seul le premier element est traite car c'est suffisant pour l'algo
            my $stackSize = @class_scope_kind;
            if ($stackSize > 0)
            {
                # on est dans une classe (ou une structure)
                my $line_number = 0;                                          # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                # FIXME: meme nom de variable que pour la boucle foreach!!!
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
                print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
                print STDERR "$item\n" if ($debug);                           # traces_filter_line

                if (($current_class_uid + 1) == $uid)
                {
                    my $lastElement = $class_scope_kind[-1]->[1]; # dernier element

                    if ($lastElement =~ /class/)
                    {
                        # si c'est une classe, le premier element est prive
                        push (@class_scope_kind, [$current_scope_class,"IRP"]);
                    }
                    elsif ($lastElement =~ /struct/)
                    {
                        # si c'est une structure, le premier element est public
                        push (@class_scope_kind, [$current_scope_class,"BUP"]);
                    }
                }
            }
        }
    }

    foreach my $item_foreach (@class_scope_kind)                                                               # traces_filter_line
    {                                                                                                  # traces_filter_line
        $trace_detect_BadDeclarationOrder .= $item_foreach->[0] . ',' . $item_foreach->[1] . "\n" if ($b_TraceDetect); # traces_filter_line
    }                                                                                                  # traces_filter_line

    ($nbr_BadDeclarationOrder, my $trace) = CountBadDeclarationOrder(@class_scope_kind);
    $trace_detect_BadDeclarationOrder .= $trace if ($b_TraceDetect); # traces_filter_line

    print STDERR "$mnemo_BadDeclarationOrder = $nbr_BadDeclarationOrder\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_BadDeclarationOrder, $trace_detect_BadDeclarationOrder, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_BadDeclarationOrder, $nbr_BadDeclarationOrder);

    return $status;
}


# comptage les declarations qui ne sont pas dans l'ordre
sub CountBadDeclarationOrder(@)
{
    my (@class_scope_kind) = @_;
    my $nb_bad_declaration_order = 0;
    my $trace_detect_bad_declaration_order = "#bad declaration order :\n";
    my %dejavue = ();
    foreach my $class_scope (@class_scope_kind)
    {
        my $class_scope_key = $class_scope->[0];
        $dejavue{$class_scope_key}++;
    }

    my @class_unique = sort(keys %dejavue);
    foreach my $class_scope_key (@class_unique)
    {
        my @sequence_kind;
        foreach my $item_foreach (@class_scope_kind)
        {
            if ($class_scope_key eq $item_foreach->[0])
            {
                # seulement ceux qui sont dans la meme classe
                push (@sequence_kind, $item_foreach->[1]);
            }
        }

        my $sequence_kind = join(' ', @sequence_kind);
        if (not ($sequence_kind =~ /^((classIRP|structBUP)\s?)(BUP\s?)*(ORP\s?)*(IRP\s?)*$/))
        {
            $nb_bad_declaration_order++;
            $trace_detect_bad_declaration_order .= "$class_scope_key\n";
        }
    }

    return ($nb_bad_declaration_order, $trace_detect_bad_declaration_order);
}

# bt_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de classes qui utilisent
# l'heritage multiple
# Module de comptage du nombre de classes qui utilisent
# l'heritage private
#-------------------------------------------------------------------------------
sub Count_Inheritances($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    # heritage multiple
    my $nbr_MultipleInheritances = 0;
    my $mnemo_MultipleInheritances = Ident::Alias_MultipleInheritances();
    my $trace_MultipleInheritances = '' if ($b_TraceDetect); # traces_filter_line
    # heritage private
    my $nbr_PrivateInheritances = 0;
    my $mnemo_PrivateInheritances = Ident::Alias_PrivateInheritances();
    my $trace_PrivateInheritances = '' if ($b_TraceDetect); # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_PrivateInheritances, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;
        assert (exists $hash_item{'uid'}); # traces_filter_line
        my $uid = $hash_item{'uid'};
        if (($kind == PARSER_CPP_DECLARATION_CLASS)
         || ($kind == PARSER_CPP_TEMPLATE_CLASSE))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line

            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};

            # supprime les templates <..>
            my $item_no_template = $item;
            while ($item_no_template =~ s/<[^<]*?>/ /g ) {}
            if ($item_no_template =~ /\bclass\b\s*\w+\s*:(.*)/)
            {
                my $match_heritage = $1;
                print STDERR "$match_heritage\n" if ($debug); # traces_filter_line
                my $comaNumber = () = $match_heritage =~ /,/g;

                print STDERR "comaNumber = $comaNumber\n" if ($debug); # traces_filter_line

                if ($comaNumber > 0)
                {
                    $nbr_MultipleInheritances++;
                    $trace_MultipleInheritances .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                }
                if ($match_heritage =~ /\sprivate\s/)
                {
                    $nbr_PrivateInheritances++;
                    $trace_PrivateInheritances .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                }
            }
        }
    }

    print STDERR "$mnemo_MultipleInheritances = $nbr_MultipleInheritances\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_MultipleInheritances, $trace_MultipleInheritances, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_MultipleInheritances, $nbr_MultipleInheritances);

    print STDERR "$mnemo_PrivateInheritances = $nbr_PrivateInheritances\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_PrivateInheritances, $trace_PrivateInheritances, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_PrivateInheritances, $nbr_PrivateInheritances);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de classes
# Module de comptage du nombre de structures
#-------------------------------------------------------------------------------
sub Count_ClassesStructs($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    # classes
    my $nbr_ClassDefinitions = 0;
    my $mnemo_ClassDefinitions = Ident::Alias_ClassDefinitions();
    my $trace_detect_ClassDefinitions = '' if ($b_TraceDetect);        # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert);          # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_ClassDefinitions, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;

        return $status;
    }

    my @parsed_items= @{$vue->{'parsed_code'}};

    foreach my $item_foreach (@parsed_items)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;
        assert (exists $hash_item{'uid'});                                                              # traces_filter_line
        my $uid = $hash_item{'uid'};
        if (($kind == PARSER_CPP_DECLARATION_CLASS)
         || ($kind == PARSER_CPP_TEMPLATE_CLASSE))
        {
            $nbr_ClassDefinitions++;

            my $line_number = 0;                                                                        # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect);                               # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};                                                              # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);                                      # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                                                      # traces_filter_line
            print STDERR "$item\n" if ($debug);                                                         # traces_filter_line
            assert (exists $hash_item{'scope_namespace'});                                              # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};                                        # traces_filter_line
            assert (exists $hash_item{'scope_class'});                                                  # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};                                                # traces_filter_line
            my $path_classname = "[$scope_namespace][$scope_class]";                                    # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$path_classname:$item\n" if ($b_TraceDetect); # traces_filter_line
            $trace_detect_ClassDefinitions .= $trace_line if ($b_TraceDetect);                          # traces_filter_line
        }
        elsif (($kind == PARSER_CPP_DECLARATION_STRUCT)
            || ($kind == PARSER_CPP_TEMPLATE_STRUCT))
        {
            my $line_number = 0;                                                                        # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect);                               # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};                                                              # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);                                      # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                                                      # traces_filter_line
            print STDERR "$item\n" if ($debug);                                                         # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$item\n" if ($b_TraceDetect);                 # traces_filter_line
        }
    }

    print STDERR "$mnemo_ClassDefinitions = $nbr_ClassDefinitions\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ClassDefinitions, $trace_detect_ClassDefinitions, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ClassDefinitions, $nbr_ClassDefinitions);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre d'attribut publics
# Module de comptage du nombre d'attribut protected
# Module de comptage du nombre d'attribut protected/private  # traces_filter_line    # bt_filter_line
#-------------------------------------------------------------------------------
sub Count_Attributes($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    #  attributs publics
    my $mnemo_PublicAttributes = Ident::Alias_PublicAttributes();
    my $nbr_PublicAttributes = 0;
    my $trace_detect_PublicAttributes = '' if ($b_TraceDetect);             # traces_filter_line
    #  attributs protected
    my $mnemo_ProtectedAttributes = Ident::Alias_ProtectedAttributes();
    my $nbr_ProtectedAttributes = 0;
    my $trace_ProtectedAttributes = '' if ($b_TraceDetect);             # traces_filter_line
    #  attributs proteges, prive
    my $nmeno_PrivateProtectedAttributes = Ident::Alias_PrivateProtectedAttributes();                                       # bt_filter_line
    my $nbr_PrivateProtectedAttributes = 0;                                                                        # bt_filter_line
    my $trace_detect_PrivateProtectedAttributes = '' if ($b_TraceDetect);          # traces_filter_line    # bt_filter_line

    my $trace_detect_global_var = '' if ($b_TraceDetect);              # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert);          # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_PublicAttributes, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_ProtectedAttributes, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $nmeno_PrivateProtectedAttributes, Erreurs::COMPTEUR_ERREUR_VALUE); # bt_filter_line
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;
        assert (exists $hash_item{'uid'}); # traces_filter_line
        my $uid = $hash_item{'uid'};
        if (($kind == PARSER_CPP_DECLARATION_VARIABLE)
         || ($kind == PARSER_CPP_DECLARATION_STRUCT_AVEC_INIT)
         || ($kind == PARSER_CPP_VAR_GLOB_INIT_ACCOLADE))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            assert (defined ($line_number));                              # traces_filter_line
            assert (exists $hash_item{'item'});                           # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};                                # traces_filter_line
            assert (defined $item);                                       # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'var_visibility'});                 # traces_filter_line

            my $cur_class_visibility = $hash_item{'var_visibility'};

            assert (defined ($cur_class_visibility));                                                         # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$cur_class_visibility:$item\n" if ($b_TraceDetect); # traces_filter_line

            if (($cur_class_visibility eq 'public') || ($cur_class_visibility eq 'struct_public'))
            {
                $nbr_PublicAttributes++;
                print "nb_public_attr++\n" if ($debug);                            # traces_filter_line
                $trace_detect_PublicAttributes .= $trace_line if ($b_TraceDetect); # traces_filter_line
            }
            elsif ($cur_class_visibility eq 'protected')
            {
                $nbr_ProtectedAttributes++;
                print "nb_protected_attr++\n" if ($debug);                         # traces_filter_line
                $trace_ProtectedAttributes .= $trace_line if ($b_TraceDetect);     # traces_filter_line
            }

            if (($cur_class_visibility eq 'protected') || ($cur_class_visibility eq 'private')) # bt_filter_line
            {                                                                                   # bt_filter_line
                $nbr_PrivateProtectedAttributes++;                                              # bt_filter_line
                print "nb_priv_prot_attr++\n" if ($debug);                                      # bt_filter_line # traces_filter_line
                $trace_detect_PrivateProtectedAttributes .= $trace_line if ($b_TraceDetect);    # bt_filter_line # traces_filter_line
            }                                                                                   # bt_filter_line
        }
    }

    print STDERR "$mnemo_PublicAttributes = $nbr_PublicAttributes\n" if ($debug);                                                # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_PublicAttributes, $trace_detect_PublicAttributes, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_PublicAttributes, $nbr_PublicAttributes);

    print STDERR "$mnemo_ProtectedAttributes = $nbr_ProtectedAttributes\n" if ($debug);                                         # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ProtectedAttributes, $trace_ProtectedAttributes, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ProtectedAttributes, $nbr_ProtectedAttributes);

    print STDERR "$nmeno_PrivateProtectedAttributes = $nbr_PrivateProtectedAttributes\n" if ($debug);                                                # bt_filter_line # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $nmeno_PrivateProtectedAttributes, $trace_detect_PrivateProtectedAttributes, $options) if ($b_TraceDetect); # bt_filter_line # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $nmeno_PrivateProtectedAttributes, $nbr_PrivateProtectedAttributes); # bt_filter_line

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre d'attributs variables globales a l'application
#-------------------------------------------------------------------------------
sub Count_AppGlobalVar($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    my $langage = $$compteurs{'Dat_Language'};

    my $nbr_ApplicationGlobalVariables = 0;
    my $nmeno_ApplicationGlobalVariables = Ident::Alias_ApplicationGlobalVariables();
    my $trace_detect_ApplicationGlobalVariables = '' if ($b_TraceDetect); # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $nmeno_ApplicationGlobalVariables, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        assert (exists $hash_item{'uid'}); # traces_filter_line

        my $uid = $hash_item{'uid'};
        if (($kind == PARSER_CPP_DECLARATION_VARIABLE)
         || ($kind == PARSER_CPP_DECLARATION_STRUCT_AVEC_INIT)
         || ($kind == PARSER_CPP_VAR_GLOB_INIT_ACCOLADE))
        {
            my $line_number = 0;                                                                              # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect);                                     # traces_filter_line
            assert (defined ($line_number));                                                                  # traces_filter_line
            assert (exists $hash_item{'item'});                                                               # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            assert (defined $item);                                                                           # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);                                            # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                                                            # traces_filter_line
            print STDERR "$item\n" if ($debug);                                                               # traces_filter_line
            assert (exists $hash_item{'var_visibility'});                                                     # traces_filter_line

            my $cur_class_visibility = $hash_item{'var_visibility'};

            assert (defined ($cur_class_visibility));                                                         # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$cur_class_visibility:$item\n" if ($b_TraceDetect); # traces_filter_line

            if ($cur_class_visibility eq 'app_global')
            {
                $nbr_ApplicationGlobalVariables++;

                print "nb_app_global_var++\n" if ($debug);                                   # traces_filter_line
                $trace_detect_ApplicationGlobalVariables .= $trace_line if ($b_TraceDetect); # traces_filter_line
            }
        }
    }

    print STDERR "$nmeno_ApplicationGlobalVariables = $nbr_ApplicationGlobalVariables\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $nmeno_ApplicationGlobalVariables, $trace_detect_ApplicationGlobalVariables, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $nmeno_ApplicationGlobalVariables, $nbr_ApplicationGlobalVariables);

    return $status;
}

# bt_filter_start
#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre d'attribut variables globales au fichier
#-------------------------------------------------------------------------------
sub Count_FileGlobalVar($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    my $langage = $$compteurs{'Dat_Language'};

    my $nmeno_FileGlobalVariables = Ident::Alias_FileGlobalVariables();
    my $nbr_FileGlobalVariables = 0;
    my $trace_detect_FileGlobalVariables = '' if ($b_TraceDetect); # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $nmeno_FileGlobalVariables, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;
        assert (exists $hash_item{'uid'}); # traces_filter_line
        my $uid = $hash_item{'uid'};
        if (($kind == PARSER_CPP_DECLARATION_VARIABLE)
         || ($kind == PARSER_CPP_DECLARATION_STRUCT_AVEC_INIT)
         || ($kind == PARSER_CPP_VAR_GLOB_INIT_ACCOLADE))
        {
            my $line_number = 0;                                                                              # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect);                                     # traces_filter_line
            assert (defined ($line_number));                                                                  # traces_filter_line
            assert (exists $hash_item{'item'});                                                               # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            assert (defined $item);                                                                           # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);                                            # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                                                            # traces_filter_line
            print STDERR "$item\n" if ($debug);                                                               # traces_filter_line
            assert (exists $hash_item{'var_visibility'});                                                     # traces_filter_line

            my $cur_class_visibility = $hash_item{'var_visibility'};

            assert (defined ($cur_class_visibility));                                                         # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$cur_class_visibility:$item\n" if ($b_TraceDetect); # traces_filter_line

            if ($cur_class_visibility eq 'file_global')
            {
                $nbr_FileGlobalVariables++;

                print "nb_file_global_var++\n" if ($debug);                           # traces_filter_line
                $trace_detect_FileGlobalVariables .= $trace_line if ($b_TraceDetect); # traces_filter_line
            }
        }
    }

    print STDERR "$nmeno_FileGlobalVariables = $nbr_FileGlobalVariables\n" if ($debug);                                                # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $nmeno_FileGlobalVariables, $trace_detect_FileGlobalVariables, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $nmeno_FileGlobalVariables, $nbr_FileGlobalVariables);

    return $status;
}
# bt_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de variables globales definies dans un .h
# ou de méthodes avec implementation
#-------------------------------------------------------------------------------
sub Count_DefinitionsInH($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    my $langage = $$compteurs{'Dat_Language'};
    my $b_analyse_cpp = ($langage eq 'Cpp') || ($langage eq 'Hpp');
    my $b_analyse_h = ($langage eq 'H');
    my $b_fichier_h_ou_hpp = 0;
    if (($fichier =~ /\.h$/) || ($fichier =~ /\.hpp$/))
    {
        $b_fichier_h_ou_hpp = 1;
    }

    my $nbr_DefinitionsInH = 0;
    my $mnemo_DefinitionsInH = Ident::Alias_DefinitionsInH();
    my $trace_detect_DefinitionsInH = '' if ($b_TraceDetect); # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        assert (exists $hash_item{'uid'}); # traces_filter_line

        my $uid = $hash_item{'uid'};
        if (($kind == PARSER_CPP_DECLARATION_VARIABLE)
         || ($kind == PARSER_CPP_DECLARATION_STRUCT_AVEC_INIT)
         || ($kind == PARSER_CPP_VAR_GLOB_INIT_ACCOLADE))
        {
            my $line_number = 0;                                                                              # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect);                                     # traces_filter_line
            assert (defined ($line_number));                                                                  # traces_filter_line
            assert (exists $hash_item{'item'});                                                               # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            assert (defined $item);                                                                           # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);                                            # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                                                            # traces_filter_line
            print STDERR "$item\n" if ($debug);                                                               # traces_filter_line
            assert (exists $hash_item{'var_visibility'});                                                     # traces_filter_line

            my $cur_class_visibility = $hash_item{'var_visibility'};

            assert (defined ($cur_class_visibility));                                                         # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$cur_class_visibility:$item\n" if ($b_TraceDetect); # traces_filter_line

            if ($cur_class_visibility eq 'app_global')
            {
                if ($b_analyse_h)
                {
                    $nbr_DefinitionsInH++;

                    print "nbr_def_in_h++\n" if ($debug);                            # traces_filter_line
                    $trace_detect_DefinitionsInH .= $trace_line if ($b_TraceDetect); # traces_filter_line
                }
            }
        }
        elsif (($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE)
            || ($kind == PARSER_CPP_PROTOTYPE_KR))
        {
            my $line_number = 0;                                                                      # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect);                             # traces_filter_line
            assert (defined ($line_number));                                                          # traces_filter_line
            assert (exists $hash_item{'item'});                                                       # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            assert (defined $item);                                                                   # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);                                    # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                                                    # traces_filter_line
            print STDERR "$item\n" if ($debug);                                                       # traces_filter_line
            my $trace_line = "$base_filename:$line_number:function_impl:$item\n" if ($b_TraceDetect); # traces_filter_line

            if ($b_analyse_h)
            {
                $nbr_DefinitionsInH++;

                print "nbr_def_in_h++\n" if ($debug);                            # traces_filter_line
                $trace_detect_DefinitionsInH .= $trace_line if ($b_TraceDetect); # traces_filter_line
            }
        }
    }

    if (not $b_fichier_h_ou_hpp)
    {
        $nbr_DefinitionsInH = 0;
        $trace_detect_DefinitionsInH = ''  if ($b_TraceDetect); # traces_filter_line
    }
    print STDERR "$mnemo_DefinitionsInH = $nbr_DefinitionsInH\n" if ($debug);                                                # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_DefinitionsInH, $trace_detect_DefinitionsInH, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_DefinitionsInH, $nbr_DefinitionsInH);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de declarations sur la meme ligne
# (variables globales, variables membres, variables locales)
# Module de comptage du nombre de variables locales non initialisees
#-------------------------------------------------------------------------------
use constant LINEDECLMULT  => 1;
use constant DECLVAR  => 2;
sub Count_MultipleDeclarationSameLine($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $debug2 = 0;                                                    # traces_filter_line
    my $status = 0;
    my $langage = $$compteurs{'Dat_Language'};
    my $b_analyse_c_cpp_objc = ($langage eq 'C') || ($langage eq 'Cpp') || ($langage eq 'ObjC') ||($langage eq 'ObjCpp');
    my $b_all_counters = ((exists $options->{'--allcounters'})? 1 : 0);
    my $b_timing = 0;                                                   # timing_filter_line

    my $trace_detect_var_decl = '' if ($b_TraceDetect); # traces_filter_line

    my $mnemo_MultipleDeclarationsInSameStatement = Ident::Alias_MultipleDeclarationsInSameStatement();
    my $nbr_MultipleDeclarationsInSameStatement = 0;

    my $mnemo_UninitializedLocalVariables = Ident::Alias_UninitializedLocalVariables();
    my $nbr_UninitializedLocalVariables = 0;

    if ((not defined $vue->{'code_only'}) || (not defined $vue->{'parsed_code'}))
    {
        assert (defined $vue->{'code_only'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_MultipleDeclarationsInSameStatement , Erreurs::COMPTEUR_ERREUR_VALUE);
        if ($b_analyse_c_cpp_objc)
        {
            $status |= Couples::counter_add ($compteurs, $mnemo_UninitializedLocalVariables , Erreurs::COMPTEUR_ERREUR_VALUE);
        }
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $c = $vue->{'code_only'};
    my @parsed_code = @{$vue->{'parsed_code'}};

    my @liste_type_non_objet = split ("\\s+", LISTE_TYPE_NON_OBJET);
    my %hash_type_non_objets;
    foreach my $type (@liste_type_non_objet)
    {
        $hash_type_non_objets{"$type"} = 1;
    }

    # 1ere partie : traitement des variables locales dans le code
    print STDERR "#1ere partie (var locales):\n" if ($b_TraceDetect); # traces_filter_line
    $trace_detect_var_decl .= "#1ere partie (var locales):\n" if ($b_TraceDetect); # traces_filter_line

    my $cpt_timing = new Timing('Count_MultipleDeclarationSameLine', Timing->isSelectedTiming ('Algo'));
    $cpt_timing->markTimeAndPrint('--init--') if ($b_timing);                    # timing_filter_line

    #my @tab = split ("[;{}]", $c);
    $c =~ s/;/;£/g; # ajout separateur unique
    $c =~ s/\{/\{£/g; # ajout separateur unique
    $c =~ s/}/}£/g; # ajout separateur unique
    my @tab = split ('£', $c);

    my $line_number = 1;  # traces_filter_line
    for (my $i = 0; $i < @tab; $i++)
    {
        # nettoyage
        $tab[$i] =~ s/^[\t ]+//mg;  # supprime les espaces en debut de chaine
        $tab[$i] =~ s/\#[^\n]*//;   # supprime les directives
        my $nb_lines = () = $tab[$i] =~ /\n/g;              # traces_filter_line
        $line_number += $nb_lines;                          # traces_filter_line
    }

    print STDERR "line_number:$line_number\n" if ($b_TraceDetect); # traces_filter_line

    $line_number = 1;                                       # traces_filter_line
    foreach my $match_all (@tab)
    {
        my $nb_lines = () = $match_all =~ /\n/g;            # traces_filter_line
        my $value = 0;
        $value = $line_number if ($b_TraceDetect);          # traces_filter_line

        if (not $match_all =~ /;$/)
        {
            # ce n'est pas une declaration de variable
            $line_number += $nb_lines;                      # traces_filter_line
            next;
        }

        if (not ($match_all =~ /\b(return|break|goto|extern)\b/))
        {
            my @kind_type_variable = ParseVariableFullLine ($fichier, $options, $match_all, $value);

            foreach my $item_foreach (@kind_type_variable)
            {
                my $kind = $item_foreach->[0];
                my $offset = $item_foreach->[1];
                my $var_list_clean = $item_foreach->[2];
                my $var_type = $item_foreach->[3];
                my $line = $item_foreach->[4]; # pour LINEDECLMULT
                my $var = $item_foreach->[4];  # pour DECLVAR
                my $line_number_offset = $line_number + $offset if ($b_TraceDetect); # traces_filter_line

                if ($kind == DECLVAR)
                {
                    # verifie si non initialise (pour pointeur ou type std du C ou assimile)

                    my $qualifier = '' if ($b_TraceDetect); # traces_filter_line

                    if (not $var =~ /=/)
                    {
                        # la variable locale n'est pas initialisee
                        if ($var =~ /[&\*]/)
                        {
                            # c'est un pointeur non initialise
                            $nbr_UninitializedLocalVariables++;
#print "[TMP] variable non initialisee = $var_type $var\n";

                            $qualifier = 'PTR_NON_INIT' if ($b_TraceDetect); # traces_filter_line
                        }
                        else
                        {
                            # verifie si c'est un type std du C ou assimile
                            my $rootType = $var_type;
                            $rootType =~ s/[&\*]//g; # enleve les '*' ou '&' du type
                            my @typenames = split ("\\s+", $rootType);

                            print STDERR "typenames:" . join('/', @typenames) . " \n" if ($debug); # traces_filter_line

                            my $StdCTypeFound = 0;
                            foreach my $typename (@typenames)
                            {
                                # partie de parametre

                                print STDERR "typename:$typename\n" if ($debug); # traces_filter_line

                                if (exists $hash_type_non_objets{"$typename"})
                                {
                                    $StdCTypeFound = 1;
                                    last;
                                }
                            }

                            if ($StdCTypeFound == 1)
                            {
                                # c'est une variable de type c ou assimile qui n'est pas initialisee
                                $nbr_UninitializedLocalVariables++;
#print "[TMP] variable non initialisee = $var_type $var\n";

                                $qualifier = 'TYPE_C_NON_INIT' if ($b_TraceDetect); # traces_filter_line
                            }
                        }
                    }

                    $match_all =~ s/\n/ /g;  # nettoyage  # traces_filter_line
                    $match_all =~ s/;$//;    # nettoyage  # traces_filter_line
                    $match_all =~ s/\s+/ /g; # nettoyage  # traces_filter_line
                    $trace_detect_var_decl .= "$base_filename:$line_number_offset:DECLVAR:$match_all:($var_list_clean):=>[$var_type/$var]:$qualifier\n" if ($b_TraceDetect); # traces_filter_line
                }
                elsif ($kind == LINEDECLMULT)
                {
                    $nbr_MultipleDeclarationsInSameStatement++;

                    $match_all =~ s/\n/ /g;  # nettoyage  # traces_filter_line
                    $match_all =~ s/;$//;    # nettoyage  # traces_filter_line
                    $match_all =~ s/\s+/ /g; # nettoyage  # traces_filter_line
                    $var_type  =~ s/\n/ /g;  # nettoyage  # traces_filter_line
                    $trace_detect_var_decl .= "$base_filename:$line_number_offset:LINEDECLMULT:$match_all:($var_list_clean):[$var_type/$line]\n" if ($b_TraceDetect); # traces_filter_line
                }
            }
        }

        $line_number += $nb_lines; # traces_filter_line
    }

    $cpt_timing->markTimeAndPrint('--1ere_partie--') if ($b_timing);                    # timing_filter_line

    # 2eme partie : traitement des variables globales, variables membres dans les declarations
    print STDERR "#2eme partie (var membres ou var globales) :\n" if ($b_TraceDetect); # traces_filter_line
    $trace_detect_var_decl .= "#2eme partie (var membres ou var globales) :\n" if ($b_TraceDetect); # traces_filter_line
    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        assert (exists $hash_item{'uid'}); # traces_filter_line

        my $uid = $hash_item{'uid'};
        if ($kind == PARSER_CPP_DECLARATION_VARIABLE_FULL_LINE)
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            assert (defined ($line_number));                              # traces_filter_line

            assert (exists $hash_item{'item'});                           # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            assert (defined $item);                                       # traces_filter_line

            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line

            my $value = 0;
            $value = $line_number if ($b_TraceDetect);                    # traces_filter_line
            # nettoyage
            my $item_clean = $item;
            $item_clean =~ s/\n/ /g;
            $item_clean =~ s/\s+/ /g;
            $item_clean =~ s/\s+$//;

            assert (exists($hash_item{'b_variable_membre'}));             # traces_filter_line

            my $b_variable_membre = $hash_item{'b_variable_membre'};

            assert (exists($hash_item{'var_type'}));                      # traces_filter_line

            my $type = $hash_item{'var_type'};

            print STDERR "type:$type\n" if ($debug);                      # traces_filter_line

            my @kind_type_variable = ParseVariableFullLine ($fichier, $options, $item, $value);

            foreach my $item (@kind_type_variable)
            {
                my $kind = $item->[0];
                my $offset = $item->[1];
                my $var_list_clean = $item->[2];
                my $var_type = $item->[3];
                my $line = $item->[4]; # pour LINEDECLMULT
                my $var = $item->[4];  # pour DECLVAR

                my $line_number_offset = $line_number + $offset if ($b_TraceDetect); # traces_filter_line

                if ($kind == DECLVAR)
                {
                    $trace_detect_var_decl .= "$base_filename:$line_number_offset:DECLVAR:$item_clean:($var_list_clean):=>[$var_type/$var]\n" if ($b_TraceDetect); # traces_filter_line
                }
                elsif ($kind == LINEDECLMULT)
                {
                    $trace_detect_var_decl .= "$base_filename:$line_number:LINEDECLMULT:$item_clean:($var_list_clean):[$var_type/$line]\n" if ($b_TraceDetect); # traces_filter_line
                    $nbr_MultipleDeclarationsInSameStatement++;
                }
            }
        }
    }

    $cpt_timing->markTimeAndPrint('--2eme_partie--') if ($b_timing);                    # timing_filter_line

    print STDERR "$mnemo_MultipleDeclarationsInSameStatement = $nbr_MultipleDeclarationsInSameStatement\n" if ($debug);                            # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_MultipleDeclarationsInSameStatement, $trace_detect_var_decl, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_MultipleDeclarationsInSameStatement, $nbr_MultipleDeclarationsInSameStatement);

    if ($b_analyse_c_cpp_objc)
    {
        print STDERR "$mnemo_UninitializedLocalVariables = $nbr_UninitializedLocalVariables\n" if ($debug);                          # traces_filter_line
        TraceDetect::DumpTraceDetect ($fichier, $mnemo_UninitializedLocalVariables, $trace_detect_var_decl, $options) if ($b_TraceDetect); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_UninitializedLocalVariables, $nbr_UninitializedLocalVariables);
    }

    $cpt_timing->dump('Count_MultipleDeclarationSameLine') if ($b_timing);              # timing_filter_line

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# analyse les declarations de variable afin de detecter celles qui sont sur
# la meme ligne
#-------------------------------------------------------------------------------
sub ParseVariableFullLine($$$$)
{
    my ($fichier, $options, $match_to_analyse, $value) = @_;

    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line

    if (not $match_to_analyse =~ /[;,=]$/)
    {
        # par defaut doit se terminer par ';'
        $match_to_analyse .= ';';
    }

    my @kind_type_variable;

    my $match_all_clean = $match_to_analyse;

    while ($match_all_clean =~ s/<[^<]*?>/ /g ) {}    # supprime les templates
    while ($match_all_clean =~ s/\([^\(]*?\)/ /g ) {} # supprime les parametres des appels de fonction (initialisation)
    $match_all_clean =~ s/(=).*?(,|;)/$1$2/g;         # supprime les initialisations sauf '=' et le caractere de fin
    $match_all_clean =~ s/\[.*?\]//g;                 # supprime les dimensions de tableau
    $match_all_clean =~ s/(\w+\s*::)+//g;             # supprime les scopes

    my $match_all_clean_for_type = $match_all_clean;
    $match_all_clean =~ s/[&\*]//g;            # supprime les * des pointeurs et les & des references

    if (($match_all_clean =~ /^\n*\w+\s+\w+/))
    {
        # c'est une declaration de variable locale
        print STDERR "======>>>>>> declaration de variable locale\n" if ($debug); # traces_filter_line
        print STDERR "line : $value\n" if ($debug); # traces_filter_line
        # extrait le type
        my $var_avant = '';
        my $var_type = '';
        my $var_list = '';
        # les caracteres '*' et '&' ne font pas partie du type, ils sont associes au nom de la variable
        # ex :         int *y = 0, z = 1, &a =z; => le type est int, les var sont '*y', 'z' et '&a'
        if ($match_all_clean_for_type =~ /^(\n*)(.*?)([&\*]*\s*\w+\s*[,=;].*)$/s) # multiligne
        {
            $var_avant = $1;
            $var_type = $2;
            $var_list = $3;
            $var_type =~ s/\s+$//; # supprime espaces finaux
        }

        print STDERR "match_all_clean:$match_all_clean\n" if ($debug);                   # traces_filter_line
        print STDERR "match_all_clean_for_type:$match_all_clean_for_type\n" if ($debug); # traces_filter_line
        print STDERR "var_type:$var_type\n" if ($debug);                                 # traces_filter_line
        print STDERR "var_list:$var_list\n" if ($debug);                                 # traces_filter_line
        my $nb_lignes_avant = () = $var_avant =~ /\n/g;                                  # traces_filter_line
        my $nb_lignes_type = () = $var_type =~ /\n/g;                                    # traces_filter_line

        my $var_list_clean = $var_list;
        $var_list =~ s/;$//;    # supprime ';' final

        $var_list =~ s/( |\t)+/ /g; # nettoyage                                          # traces_filter_line
        $var_list_clean =~ s/\n/ /g; # nettoyage                                         # traces_filter_line
        $var_list_clean =~ s/\s+/ /g; # nettoyage                                        # traces_filter_line
        print STDERR "var_list2:$var_list\n" if ($debug);                                # traces_filter_line

        my @lines = split ("\n", $var_list);
        my $offset = 0;

        $offset += $nb_lignes_avant;                                                     # traces_filter_line
        $offset += $nb_lignes_type;                                                      # traces_filter_line

        foreach my $line (@lines)
        {
            if ($line =~ /^\s*$/)
            {
                # ligne vide
                $offset++;
                next;
            }

            print STDERR "ligne : $line\n" if ($debug); # traces_filter_line

            my @var_list = split ("\\s*,\\s*", $line);

            my $declarationNumber = () = $line =~ /\w+\s*=?\s*,[\s&\*]*\w+\s*=?/;

            if ($declarationNumber >= 1)
            {
                # plus d'une declaration par ligne
                my $item = [LINEDECLMULT, $offset, $var_list_clean, $var_type, $line];
                push (@kind_type_variable, $item);
            }

            foreach my $var (@var_list)
            {
                $var_list_clean =~ s/\n/ /g; # nettoyage      # traces_filter_line
                $var_type =~ s/\n/ /g;       # nettoyage      # traces_filter_line
                $var =~ s/\n/ /g;            # nettoyage      # traces_filter_line

                my $item = [DECLVAR, $offset, $var_list_clean, $var_type, $var] ;
                push (@kind_type_variable, $item);
            }

            $offset++;
        }
    }

    return @kind_type_variable;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de classes qui utilisent
# l'allocation dynamique (cad au moins une variable membre pointeur)
# et qui n'ont pas de constructeur par copie ou pas d'operateur d'affectation
#-------------------------------------------------------------------------------
sub Count_BadDynamicClassDef($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;


    my $mnemo_BadDynamicClassDefinitions = Ident::Alias_BadDynamicClassDefinitions();
    my $nbr_BadDynamicClassDefinitions = 0;
    my $trace_detect_BadDynamicClassDefinitions = '' if ($b_TraceDetect); # traces_filter_line


    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_BadDynamicClassDefinitions, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }
    my @parsed_code = @{$vue->{'parsed_code'}};

    # 1ere partie : recherche des variables membres qui sont des pointeurs

    my %hash_classes_avec_ptr_membre;

    print STDERR "#1ere partie : recherche des variables membres qui sont des pointeurs :\n" if ($b_TraceDetect);                      # traces_filter_line
    $trace_detect_BadDynamicClassDefinitions .= "#1ere partie : recherche des variables membres qui sont des pointeurs\n" if ($b_TraceDetect); # traces_filter_line

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        assert (exists $hash_item{'uid'});                                # traces_filter_line

        my $uid = $hash_item{'uid'};
        if ($kind == PARSER_CPP_DECLARATION_VARIABLE_FULL_LINE)
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            assert (defined ($line_number));                              # traces_filter_line
            assert (exists $hash_item{'item'});                           # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            assert (defined $item);                                       # traces_filter_line

            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line

            my $value = 0;
            $value = $line_number if ($b_TraceDetect);                    # traces_filter_line
            # nettoyage
            my $item_clean = $item;
            $item_clean =~ s/\n/ /g;
            $item_clean =~ s/\s+/ /g;
            $item_clean =~ s/\s+$//;

            assert (exists($hash_item{'b_variable_membre'}));             # traces_filter_line

            my $b_variable_membre = $hash_item{'b_variable_membre'};
            if ($b_variable_membre == 0)
            {
                 # ce n'est pas une variable membre
                next;
            }

            assert (exists $hash_item{'scope_namespace'}); # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};
            assert (exists $hash_item{'scope_class'});     # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};
            assert (exists($hash_item{'var_type'}));       # traces_filter_line
            my $type = $hash_item{'var_type'};
            print STDERR "type:$type\n" if ($debug);       # traces_filter_line

            my @kind_type_variable = ParseVariableFullLine ($fichier, $options, $item, $value);
            foreach my $item (@kind_type_variable)
            {
                my $kind = $item->[0];
                my $offset = $item->[1];
                my $var_list_clean = $item->[2];
                my $var_type = $item->[3];
                my $var = $item->[4];  # pour DECLVAR
                my $line_number_offset = $line_number + $offset if ($b_TraceDetect); # traces_filter_line
                if ($kind == DECLVAR)
                {
                    if ($var =~ /\*/)
                    {
                        # c'est un pointeur
                        my $full_scope = "[$scope_namespace][$scope_class]";
                        print STDERR "====>pointeur:$full_scope==>$var\n" if ($debug); # traces_filter_line
                        $trace_detect_BadDynamicClassDefinitions .= "$base_filename:$line_number_offset:DECLVARMEMBREPTR:$item_clean:($var_list_clean):=>[$var_type/$var]\n" if ($b_TraceDetect); # traces_filter_line
                        $hash_classes_avec_ptr_membre{$full_scope} = 1;
                    }
                }
            }
        }
    }

    # 2eme partie :
    # recherche des classes qui ont un constructeur par copie
    # recherche des classes qui ont un operateur d'affectation
    my %hash_classes_avec_ctor_par_copie;
    my %hash_classes_avec_oper_egal;

    print STDERR "#2eme partie : recherche des classes qui n'ont pas de constructeur par copie ou pas d'operator d'affectation :\n" if ($b_TraceDetect); # traces_filter_line
    $trace_detect_BadDynamicClassDefinitions .= "#2eme partie : recherche des classes qui n'ont pas de constructeur par copie ou pas d'operator d'affectation :\n" if ($b_TraceDetect); # traces_filter_line

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        my $parameterNumber = 0;
        my @parameters;
        if ($kind == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE)
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};
            assert (exists $hash_item{'b_dtor'});                         # traces_filter_line
            my $b_ctor = $hash_item{'b_ctor'};
            assert (exists $hash_item{'b_method_operator'});              # traces_filter_line
            my $b_method_operator = $hash_item{'b_method_operator'};
            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};

            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line

            # supprime les parametres template
            my $item_no_template = $item;
            while ($item_no_template =~ s/<[^<]*?>/ /g ) {}

            if ($item_no_template =~ /\((.*)\)/)
            {
                my $parameters = $1;
                if ($parameters =~ /^\s*$/)
                {
                    # pas de parametre
                    $parameterNumber = 0;
                }
                else
                {
                    # au moins un parametre
                    @parameters = split (',', $parameters);

                    print STDERR "parameters:@parameters\n" if ($debug);          # traces_filter_line

                    $parameterNumber = @parameters;
                }
            }

            print STDERR "parameterNumber : $parameterNumber \n" if ($debug);           # traces_filter_line

            if ($parameterNumber == 1)
            {
                # les 2 cas a trouver n'ont qu'un seul parametre
                if ($b_ctor == 1)
                {
                    # 1er cas : construteur par copy  ex ok : 'Complex( const Complex& a)'

                    print STDERR "test : construteur par copy ? \n" if ($debug); # traces_filter_line

                    my $parameter = $parameters [0];
                    if ($item =~ /(\w+)\s*\(/)
                    {
                        my $match_ctor_name = $1;
                        if ($parameter =~ /^\s*const\s+$match_ctor_name\s*&/)
                        {
                            # il s'agit bien du constructeur par copie (parametre meme type que classe)
                            my $full_scope = "[$scope_namespace][$scope_class]";
                            $hash_classes_avec_ctor_par_copie{$full_scope} = 1;
                            $trace_detect_BadDynamicClassDefinitions .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                            print STDERR "==> ctor par copie: $item: \n" if ($debug); # traces_filter_line
                        }
                    }
                }
                elsif ($b_method_operator == 1)
                {
                    # 2eme cas : l'operateur d'assignation ex ok :
                    # -dans une classe :         'Complex& operator=( const Complex& a)'

                    print STDERR "test : operateur assignation ? \n" if ($debug);        # traces_filter_line

                    if ($item =~ /(\w+)\s*&?\s*\boperator\s*=\s*\(/)
                    {
                        # dans une classe
                        my $match_class_name = $1;

                        print STDERR "match_class_name:$match_class_name\n" if ($debug); # traces_filter_line

                        my $parameter = $parameters [0];

                        print STDERR "parameter:$parameter\n" if ($debug); # traces_filter_line

                        if ($parameter =~ /^\s*const\s+$match_class_name\s*&/)
                        {
                            # il s'agit bien de l'operateur d'affectation (parametre meme type que classe)
                            my $full_scope = "[$scope_namespace][$scope_class]";
                            $hash_classes_avec_oper_egal{$full_scope} = 1;
                            $trace_detect_BadDynamicClassDefinitions .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                            print STDERR "==> op affectation: $item: \n" if ($debug);                                      # traces_filter_line
                        }
                    }
                }
                else
                {
                    print STDERR "test : dafaut rien\n" if ($debug); # traces_filter_line
                }
            }
        }
    }

    # 3eme partie :
    # recherche des classes qui ont un pointeur membre
    # sans avoir un constructeur par copie
    # ou sans avoir un operateur d'affectation

    print STDERR "#3eme partie : synthese :\n" if ($b_TraceDetect);                         # traces_filter_line
    $trace_detect_BadDynamicClassDefinitions .= "#3eme partie : synthese : \n" if ($b_TraceDetect); # traces_filter_line

    my @classes_avec_ptr = sort keys %hash_classes_avec_ptr_membre;
    foreach my $classe (@classes_avec_ptr)
    {
        my $b_missing = 0;
        if (not exists $hash_classes_avec_ctor_par_copie{$classe})
        {
            $b_missing = 1;

            my $txt = "MANQUE CTOR COPIE : $classe \n"  if ($b_TraceDetect); # traces_filter_line
            print STDERR $txt if ($debug);                                   # traces_filter_line
            $trace_detect_BadDynamicClassDefinitions .= $txt if ($b_TraceDetect);    # traces_filter_line
        }

        if (not exists $hash_classes_avec_oper_egal{$classe})
        {
            $b_missing = 1;

            my $txt = "MANQUE OP EGALE : $classe \n" if ($b_TraceDetect); # traces_filter_line
            print STDERR $txt if ($debug);                                # traces_filter_line
            $trace_detect_BadDynamicClassDefinitions .= $txt if ($b_TraceDetect); # traces_filter_line
        }

        if ($b_missing == 1)
        {
            $nbr_BadDynamicClassDefinitions++;
        }
    }

    print STDERR "$mnemo_BadDynamicClassDefinitions = $nbr_BadDynamicClassDefinitions\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_BadDynamicClassDefinitions, $trace_detect_BadDynamicClassDefinitions, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_BadDynamicClassDefinitions, $nbr_BadDynamicClassDefinitions);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de declaration de fonctions/methodes
# Module de comptage du nombre d'implementation de fonctions/methodes
# Module de comptage du nombre de classe qui sont implementees dans
# le fichier
#-------------------------------------------------------------------------------

sub Count_Cpp_Methods($$$$) {
    my ($fichier, $vue, $compteurs, $options) = @_;
    return __Count_Methods($fichier, $vue, $compteurs, $options, 'Cpp');
}

sub Count_C_Functions($$$$) {
    my ($fichier, $vue, $compteurs, $options) = @_;
    return __Count_Methods($fichier, $vue, $compteurs, $options, 'C');
}

sub __Count_Methods($$$$$)
{
    my ($fichier, $vue, $compteurs, $options, $langage) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    my $b_analyse_cpp_hpp = ($langage eq 'Cpp') || ($langage eq 'Hpp') ||
                            ($langage eq 'ObjCpp') || ($langage eq 'ObjHpp');
    my $b_analyse_c = ($langage eq 'C') ||
                      ($langage eq 'ObjC');
    my $b_all_counters = ((exists $options->{'--allcounters'})? 1 : 0);

    my $trace_detect_methods = '' if ($b_TraceDetect); # traces_filter_line
    #  implementation de fonctions/methodes
    my $mnemo_FunctionMethodImplementations = Ident::Alias_FunctionMethodImplementations();
    my $nbr_FunctionMethodImplementations = 0;
    #  declaration de fonctions/methodes
    my $mnemo_FunctionMethodDeclarations = Ident::Alias_FunctionMethodDeclarations();
    my $nbr_FunctionMethodDeclarations = 0;
    #  implementations de classes
    my $mnemo_ClassImplementations = Ident::Alias_ClassImplementations();
    my $nbr_ClassImplementations = 0;

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line

        if ($b_analyse_c || $b_analyse_cpp_hpp)
        {
            $status |= Couples::counter_add ($compteurs, $mnemo_FunctionMethodImplementations, Erreurs::COMPTEUR_ERREUR_VALUE);
        }

        if ($b_all_counters || $b_analyse_cpp_hpp)
        {
            $status |= Couples::counter_add ($compteurs, $mnemo_FunctionMethodDeclarations, Erreurs::COMPTEUR_ERREUR_VALUE);
        }

        if ($b_analyse_cpp_hpp)
        {
            $status |= Couples::counter_add ($compteurs, $mnemo_ClassImplementations, Erreurs::COMPTEUR_ERREUR_VALUE);
        }

        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    my %hash_ImplMultClasses;
    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        assert (exists $hash_item{'uid'}); # traces_filter_line

        my $uid = $hash_item{'uid'};
        if ($kind == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE)
        {
            $nbr_FunctionMethodDeclarations++;

            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'tag'});                            # traces_filter_line
            my $tag = $hash_item{'tag'};                                  # traces_filter_line
            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};          # traces_filter_line
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};                  # traces_filter_line

            my $trace_line = "$base_filename:$line_number:$tag:[$scope_namespace]:" if ($b_TraceDetect); # traces_filter_line
            $trace_line .= "[$scope_class]:$item\n" if ($b_TraceDetect);                                 # traces_filter_line
            $trace_detect_methods .= $trace_line if ($b_TraceDetect);                                    # traces_filter_line
        }
        elsif (($kind == PARSER_CPP_PROTOTYPE_KR)
            || ($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE))
        {
            assert (exists $hash_item{'full_scope'});                     # traces_filter_line
            my $full_scope = $hash_item{'full_scope'};

            $nbr_FunctionMethodImplementations++;
            if (($kind != PARSER_CPP_PROTOTYPE_KR) && ($full_scope ne ''))
            {
                $hash_ImplMultClasses{$full_scope}++;
            }

            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'tag'});                            # traces_filter_line
            my $tag = $hash_item{'tag'};                                  # traces_filter_line
            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};          # traces_filter_line
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};                  # traces_filter_line

            my $trace_line = "$base_filename:$line_number:$tag:[$scope_namespace]:" if ($b_TraceDetect); # traces_filter_line
            $trace_line .= "[$scope_class]:$item\n" if ($b_TraceDetect);                                 # traces_filter_line
            $trace_detect_methods .= $trace_line if ($b_TraceDetect);                                    # traces_filter_line
        }
    }

    if ($b_analyse_c || $b_analyse_cpp_hpp)
    {
        print STDERR "$mnemo_FunctionMethodImplementations = $nbr_FunctionMethodImplementations\n" if ($debug);                       # traces_filter_line
        TraceDetect::DumpTraceDetect ($fichier, $mnemo_FunctionMethodImplementations, $trace_detect_methods, $options) if ($b_TraceDetect); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_FunctionMethodImplementations, $nbr_FunctionMethodImplementations);
    }

    if ($b_all_counters || $b_analyse_cpp_hpp)
    {
        print STDERR "$mnemo_FunctionMethodDeclarations = $nbr_FunctionMethodDeclarations\n" if ($debug);                             # traces_filter_line
        TraceDetect::DumpTraceDetect ($fichier, $mnemo_FunctionMethodDeclarations, $trace_detect_methods, $options) if ($b_TraceDetect); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_FunctionMethodDeclarations, $nbr_FunctionMethodDeclarations);
    }

    if ($b_analyse_cpp_hpp)
    {
        my @keys = sort(keys %hash_ImplMultClasses);
        $nbr_ClassImplementations = @keys;

        my $trace_classes_implemented = join("\n", @keys) if ($debug || $b_TraceDetect);                                             # traces_filter_line
        print STDERR "trace_classes_implemented:$trace_classes_implemented\n" if ($debug);                                           # traces_filter_line
        print STDERR "$mnemo_ClassImplementations = $nbr_ClassImplementations\n" if ($debug);                                        # traces_filter_line
        TraceDetect::DumpTraceDetect ($fichier, $mnemo_ClassImplementations, $trace_classes_implemented, $options) if ($b_TraceDetect); # traces_filter_line

        $status |= Couples::counter_add ($compteurs, $mnemo_ClassImplementations, $nbr_ClassImplementations);
    }

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de classes amies
# Module de comptage du nombre de methodes amies
# (en excluant les streams)
# Module de comptage du nombre de classes/methodes amies
#-------------------------------------------------------------------------------
sub Count_Friends($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    my $langage = $$compteurs{'Dat_Language'};
    my $b_analyse_cpp = ($langage eq 'Cpp') || ($langage eq 'Hpp');
    #  methodes ou classes friends                                                 # bt_filter_line
    my $trace_detect_Friends = '' if ($b_TraceDetect);       # traces_filter_line  # bt_filter_line
    my $mnemo_Friends = Ident::Alias_Friends();                                             # bt_filter_line
    my $nbr_Friends = 0;                                                           # bt_filter_line
    # methodes amies
    my $trace_detect_FriendMethods = '' if ($b_TraceDetect); # traces_filter_line
    my $nmemo_FriendMethods = Ident::Alias_FriendMethods();
    my $nbr_FriendMethods = 0;
    # classes amies
    my $trace_detect_FriendClasses = '' if ($b_TraceDetect); # traces_filter_line
    my $nmemo_FriendClasses = Ident::Alias_FriendClasses();
    my $nbr_friend_Classes = 0;

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert);                                              # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_Friends, Erreurs::COMPTEUR_ERREUR_VALUE);       # bt_filter_line
        $status |= Couples::counter_add ($compteurs, $nmemo_FriendMethods, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $nmemo_FriendClasses, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        assert (exists $hash_item{'uid'}); # traces_filter_line

        my $uid = $hash_item{'uid'};

        if ($kind == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE)
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            # FIXME: meme nom de variable que pour la boucle foreach!!!
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'tag'});                            # traces_filter_line
            my $tag = $hash_item{'tag'};                                  # traces_filter_line
            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};          # traces_filter_line
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};                  # traces_filter_line
            assert (exists $hash_item{'b_friend_method'});                # traces_filter_line
            my $b_method_friend = $hash_item{'b_friend_method'};
            assert (exists $hash_item{'b_stream_method'});                # traces_filter_line
            my $b_method_stream = $hash_item{'b_stream_method'};

            if (($b_method_friend == 1) && ($b_method_stream == 0))
            {
                $nbr_Friends++;                                                                              # bt_filter_line
                $nbr_FriendMethods++;

                my $trace_line = "$base_filename:$line_number:$tag:[$scope_namespace]:" if ($b_TraceDetect); # traces_filter_line
                $trace_line .= "[$scope_class]:$item\n" if ($b_TraceDetect);                                 # traces_filter_line
                $trace_detect_FriendMethods .= $trace_line if ($b_TraceDetect);                              # traces_filter_line
            }

            if ($b_method_friend == 1)
            {
                my $trace_line = "$base_filename:$line_number:$tag:[$scope_namespace]:" if ($b_TraceDetect); # traces_filter_line
                $trace_line .= "[$scope_class]:$item\n" if ($b_TraceDetect);                                 # traces_filter_line
                $trace_detect_Friends .= $trace_line if ($b_TraceDetect);                                    # traces_filter_line # bt_filter_line
            }
        }
        elsif ($kind == PARSER_CPP_FRIEND_CLASS)
        {
            $nbr_Friends++;                                               # bt_filter_line
            $nbr_friend_Classes++;

            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'tag'});                            # traces_filter_line
            my $tag = $hash_item{'tag'};                                  # traces_filter_line
            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};          # traces_filter_line
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};                  # traces_filter_line

            my $trace_line = "$base_filename:$line_number:$tag:[$scope_namespace]:" if ($b_TraceDetect); # traces_filter_line
            $trace_line .= "[$scope_class]:$item\n" if ($b_TraceDetect);                                 # traces_filter_line
            $trace_detect_Friends .= $trace_line if ($b_TraceDetect);                                    # traces_filter_line # bt_filter_line
            $trace_detect_FriendClasses .= $trace_line if ($b_TraceDetect);                              # traces_filter_line
        }
    }

    print STDERR "$mnemo_Friends = $nbr_Friends\n" if ($debug);                                                # traces_filter_line # bt_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_Friends, $trace_detect_Friends, $options) if ($b_TraceDetect); # traces_filter_line # bt_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_Friends, $nbr_Friends);                                                     # bt_filter_line

    print STDERR "$nmemo_FriendMethods = $nbr_FriendMethods\n" if ($debug);                                                # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $nmemo_FriendMethods, $trace_detect_FriendMethods, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $nmemo_FriendMethods, $nbr_FriendMethods);

    print STDERR "$nmemo_FriendClasses = $nmemo_FriendClasses\n" if ($debug);                                              # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $nmemo_FriendClasses, $trace_detect_FriendClasses, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $nmemo_FriendClasses, $nbr_friend_Classes);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de classes qui n'ont pas de destructeur
# Alorithme : principe strictement identique a celui de Count_MissingCtor
#-------------------------------------------------------------------------------
sub Count_MissingDtor($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0); # traces_filter_line
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0);          # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);                  # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                           # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                             # traces_filter_line
    my $debug = 0;                                                              # traces_filter_line
    my $status = 0;
    #  destructeur manquant
    my $nbr_MissingClassDestructor = 0;
    my $trace_detect_MissingClassDestructor = '' if ($b_TraceDetect);           # traces_filter_line
    my $mnemo_MissingClassDestructor = Ident::Alias_MissingClassDestructor();

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_MissingClassDestructor, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    my @stack_missing_dtor;
    my @stack_missing_dtor_detect if ($b_TraceDetect); # traces_filter_line

    my $stackSizeError = 0;
    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;
        assert (exists $hash_item{'uid'}); # traces_filter_line
        my $uid = $hash_item{'uid'};

        if (($kind == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'b_dtor'});                         # traces_filter_line
            my $b_dtor = $hash_item{'b_dtor'};
            print STDERR "b_dtor:$b_dtor\n" if ($debug);                  # traces_filter_line
            assert (exists $hash_item{'b_item_inside_class'});            # traces_filter_line
            my $b_item_inside_class = $hash_item{'b_item_inside_class'};

            print STDERR "b_item_inside_class:$b_item_inside_class\n" if ($debug); # traces_filter_line

            if ($b_item_inside_class == 1)
            {
                if ($b_dtor == 1)
                {
                    $stack_missing_dtor[-1] = 0; # dernier element
                }
            }
        }
        elsif (($kind == PARSER_CPP_DECLARATION_CLASS)
            || ($kind == PARSER_CPP_TEMPLATE_CLASSE))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};          # traces_filter_line
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line

            my $scope_class = $hash_item{'scope_class'};

            push (@stack_missing_dtor, 1);

            my $path_classname = "[$scope_namespace][$scope_class]";                                    # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$path_classname:$item\n" if ($b_TraceDetect); # traces_filter_line
            push (@stack_missing_dtor_detect, $trace_line) if ($b_TraceDetect);                         # traces_filter_line
        }
        elsif (($kind == PARSER_CPP_DECLARATION_STRUCT)
            || ($kind == PARSER_CPP_TEMPLATE_STRUCT))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};          # traces_filter_line
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};

            push (@stack_missing_dtor, 0); # pas de destructeur attendu

            my $path_classname = "[$scope_namespace][$scope_class]";                                    # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$path_classname:$item\n" if ($b_TraceDetect); # traces_filter_line
            push (@stack_missing_dtor_detect, $trace_line) if ($b_TraceDetect);                         # traces_filter_line
        }
        elsif ($kind == PARSER_CPP_CLASS_END)
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line

            my $stackSize = @stack_missing_dtor;

            if ($stackSize <= 0)
            {
                $stackSizeError = 1;

                print STDERR "pile vide 6\n" if ($b_TraceInconsistent);  # traces_filter_line
                assert ($stackSize > 0, 'pile vide 6') if ($b_assert);   # traces_filter_line

                last;
            }

            my $b_missing_dtor = pop (@stack_missing_dtor);

            $stackSize = @stack_missing_dtor_detect if ($b_TraceDetect);                  # traces_filter_line
            if ($b_TraceDetect && ($stackSize <= 0))                                      # traces_filter_line
            {                                                                             # traces_filter_line
                $stackSizeError = 1;                                                      # traces_filter_line
                print STDERR "pile vide 7\n" if ($b_TraceInconsistent);                   # traces_filter_line
                assert ($stackSize > 0, 'pile vide 7') if ($b_assert && $b_TraceDetect);  # traces_filter_line
                last if ($b_TraceDetect);                                                 # traces_filter_line
            }                                                                             # traces_filter_line
            my $trace_line = pop (@stack_missing_dtor_detect) if ($b_TraceDetect);        # traces_filter_line

            if ($b_missing_dtor)
            {
                $nbr_MissingClassDestructor++;

                $trace_detect_MissingClassDestructor .= $trace_line if ($b_TraceDetect); # traces_filter_line
            }
        }
    }

    if ($stackSizeError)
    {
        $nbr_MissingClassDestructor = Erreurs::COMPTEUR_ERREUR_VALUE;
        $status |= Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES;
    }

    print STDERR "$mnemo_MissingClassDestructor = $nbr_MissingClassDestructor\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_MissingClassDestructor, $trace_detect_MissingClassDestructor, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_MissingClassDestructor, $nbr_MissingClassDestructor);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de classes qui n'ont pas de constructeur
# Alorithme : principe strictement identique a celui de Count_MissingDtor
#-------------------------------------------------------------------------------
sub Count_MissingCtor($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0); # traces_filter_line
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0);          # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);                  # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                           # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                             # traces_filter_line
    my $debug = 0;                                                              # traces_filter_line
    my $status = 0;
    #  constructeur manquant
    my $nbr_detect_MissingClassConstructor = 0;
    my $trace_detect_MissingClassConstructor = '' if ($b_TraceDetect);          # traces_filter_line
    my $mnemo_MissingClassConstructor = Ident::Alias_MissingClassConstructor();

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_MissingClassConstructor, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    my @stack_missing_ctor;
    my @stack_missing_ctor_detect if ($b_TraceDetect); # traces_filter_line

    my $stackSizeError = 0;
    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;

        assert (exists $hash_item{'uid'}); # traces_filter_line

        my $uid = $hash_item{'uid'};

        if (($kind == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'b_ctor'});                         # traces_filter_line
            my $b_ctor = $hash_item{'b_ctor'};
            my $b_item_inside_class = $hash_item{'b_item_inside_class'};

            print STDERR "b_item_inside_class:$b_item_inside_class\n" if ($debug); # traces_filter_line

            if ($b_item_inside_class == 1)
            {
                if ($b_ctor)
                {
                    $stack_missing_ctor[-1] = 0; # dernier element
                }
            }
        }
        elsif (($kind == PARSER_CPP_DECLARATION_CLASS)
            || ($kind == PARSER_CPP_TEMPLATE_CLASSE))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};          # traces_filter_line
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};                  # traces_filter_line

            push (@stack_missing_ctor, 1);

            my $path_classname = "[$scope_namespace][$scope_class]";                                    # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$path_classname:$item\n" if ($b_TraceDetect); # traces_filter_line
            push (@stack_missing_ctor_detect, $trace_line) if ($b_TraceDetect);                         # traces_filter_line
        }
        elsif (($kind == PARSER_CPP_DECLARATION_STRUCT)
            || ($kind == PARSER_CPP_TEMPLATE_STRUCT))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};          # traces_filter_line
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};                  # traces_filter_line

            push (@stack_missing_ctor, 0); # pas de destructeur attendu

            my $path_classname = "[$scope_namespace][$scope_class]";                                    # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$path_classname:$item\n" if ($b_TraceDetect); # traces_filter_line
            push (@stack_missing_ctor_detect, $trace_line) if ($b_TraceDetect);                         # traces_filter_line
        }
        elsif ($kind == PARSER_CPP_CLASS_END)
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line

            my $stackSize = @stack_missing_ctor;

            if ($stackSize <= 0)
            {
                $stackSizeError = 1;

                print STDERR "pile vide 6\n" if ($b_TraceInconsistent); # traces_filter_line
                assert ($stackSize > 0, 'pile vide 6') if ($b_assert);         # traces_filter_line

                last;
            }

            my $b_missing_ctor = pop (@stack_missing_ctor);

            $stackSize = @stack_missing_ctor_detect if ($b_TraceDetect);                 # traces_filter_line
            if ($b_TraceDetect && ($stackSize <= 0))                                     # traces_filter_line
            {                                                                            # traces_filter_line
                $stackSizeError = 1;                                                     # traces_filter_line
                print STDERR "pile vide 7\n" if ($b_TraceInconsistent);                  # traces_filter_line
                assert ($stackSize > 0, 'pile vide 7') if ($b_assert && $b_TraceDetect); # traces_filter_line
                last if ($b_TraceDetect);                                                # traces_filter_line
            }                                                                            # traces_filter_line
            my $trace_line = pop (@stack_missing_ctor_detect) if ($b_TraceDetect);       # traces_filter_line

            if ($b_missing_ctor)
            {
                $nbr_detect_MissingClassConstructor++;

                $trace_detect_MissingClassConstructor .= $trace_line if ($b_TraceDetect); # traces_filter_line
            }
        }
    }
    if ($stackSizeError)
    {
        $nbr_detect_MissingClassConstructor = Erreurs::COMPTEUR_ERREUR_VALUE;
        $status |= Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES;
    }

    print STDERR "$mnemo_MissingClassConstructor = $nbr_detect_MissingClassConstructor\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_MissingClassConstructor, $trace_detect_MissingClassConstructor, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_MissingClassConstructor, $nbr_detect_MissingClassConstructor);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de fonctions/methodes qui sont inline
# (le mot-cle inline peut etre soit a la declaration soit a l'implementation)
#-------------------------------------------------------------------------------
sub Count_InlineMethods($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    #  methodes inline
    my $mnemo_InlineMethods = Ident::Alias_InlineMethods();
    my $nbr_InlineMethods = 0;
    my $trace_detect_InlineMethods = '' if ($b_TraceDetect); # traces_filter_line

    if (not defined $vue->{'parsed_code'})
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_InlineMethods, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};

    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;
        assert (exists $hash_item{'uid'}); # traces_filter_line
        my $uid = $hash_item{'uid'};

        if (($kind == PARSER_CPP_DECLARATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE))
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'tag'});                            # traces_filter_line
            my $tag = $hash_item{'tag'};                                  # traces_filter_line
            assert (exists $hash_item{'scope_namespace'});                # traces_filter_line
            my $scope_namespace = $hash_item{'scope_namespace'};          # traces_filter_line
            assert (exists $hash_item{'scope_class'});                    # traces_filter_line
            my $scope_class = $hash_item{'scope_class'};                  # traces_filter_line
            assert (exists $hash_item{'b_method'});                       # traces_filter_line

            my $b_method = $hash_item{'b_method'};

            if ($b_method == 1)
            {
                # c'est une methode
                if ($item =~ /^inline\b/)
                {
                    $nbr_InlineMethods++;

                    my $trace_line = "$base_filename:$line_number:$tag:[$scope_namespace]:" if ($b_TraceDetect); # traces_filter_line
                    $trace_line .= "[$scope_class]:$item\n" if ($b_TraceDetect);                                 # traces_filter_line
                    $trace_detect_InlineMethods .= $trace_line if ($b_TraceDetect);                              # traces_filter_line
                }
            }
        }
    }

    print STDERR "$mnemo_InlineMethods = $nbr_InlineMethods\n" if ($debug);                                                # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_InlineMethods, $trace_detect_InlineMethods, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_InlineMethods, $nbr_InlineMethods);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de methodes complexes
# vg = somme des 'if', 'for', 'while', 'case', 'default' + 1
# (on ne compte pas les 'case' successifs vides)
#-------------------------------------------------------------------------------
use constant VG_SEUIL_LT_DEFAULT => 20;
use constant VG_SEUIL_HT_DEFAULT => 50;
sub Count_ComplexMethods($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $trace_detect_complex_methods = '' if ($b_TraceDetect);         # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;


    my $mnemo_ComplexMethodsLT = Ident::Alias_ComplexMethodsLT();
    my $nbr_ComplexMethodsLT = 0;

    my $mnemo_ComplexMethodsHT = Ident::Alias_ComplexMethodsHT();
    my $nbr_ComplexMethodsHT = 0;
    # calculs max
    my $max_ComplexMethodsVg = 0;
    my $mnemo_max_ComplexMethodsVg = Ident::Alias_Max_ComplexMethodsVg();

    if (not defined $vue->{'function_method_code_comment'})
    {
        assert (defined $vue->{'function_method_code_comment'}) if ($b_assert);                                    # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_ComplexMethodsLT, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_ComplexMethodsHT, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add ($compteurs, $mnemo_max_ComplexMethodsVg, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $vg_seuil_LT = 0;
    if (exists $options->{'Nbr_ComplexMethodsLT_Seuil'})
    {   $vg_seuil_LT = $options->{'Nbr_ComplexMethodsLT_Seuil'};    }
    else
    {   $vg_seuil_LT = VG_SEUIL_LT_DEFAULT;    }

    my $vg_seuil_HT = 0;
    if (exists $options->{'Nbr_ComplexMethodsHT_Seuil'})
    {   $vg_seuil_HT = $options->{'Nbr_ComplexMethodsHT_Seuil'};    }
    else
    {   $vg_seuil_HT = VG_SEUIL_HT_DEFAULT;    }

    my @function_method_code_comment= @{$vue->{'function_method_code_comment'}};

    my $functionNumber = @function_method_code_comment;                           # traces_filter_line
    print STDERR "nb function_method_code_comment:$functionNumber\n" if ($debug); # traces_filter_line

    foreach my $ref_hash_ft(@function_method_code_comment)
    {
        my %hash_ft = %$ref_hash_ft;
        assert (exists $hash_ft{'function_prototype'});                                                        # traces_filter_line
        my $function_prototype = $hash_ft{'function_prototype'};
        assert (exists $hash_ft{'function_code'});                                                             # traces_filter_line
        my $function_code = $hash_ft{'function_code'};
        assert (exists $hash_ft{'function_code_line_number_start'}) if ($b_TraceDetect);                       # traces_filter_line
        my $function_code_line_number_start = $hash_ft{'function_code_line_number_start'} if ($b_TraceDetect); # traces_filter_line
        assert (exists $hash_ft{'function_code_line_number_end'}) if ($b_TraceDetect);                         # traces_filter_line
        my $function_code_line_number_end = $hash_ft{'function_code_line_number_end'} if ($b_TraceDetect);     # traces_filter_line

        my $nb_lines_in_code = () = $function_code =~ /\n/g;

        print STDERR "#########################\n" if ($debug);          # traces_filter_line
        print STDERR "$function_prototype\n" if ($debug);                # traces_filter_line
        print STDERR "#\n" if ($debug);                                  # traces_filter_line
        print STDERR "nb_lines_in_code:$nb_lines_in_code\n" if ($debug); # traces_filter_line
        print STDERR "function_code:\n" if ($debug);                     # traces_filter_line
        print STDERR "$function_code\n" if ($debug);                     # traces_filter_line
        print STDERR "#\n" if ($debug);                                  # traces_filter_line

        my $vg = 1;
        $trace_detect_complex_methods .= "$base_filename:$function_code_line_number_start:$function_code_line_number_start->$function_code_line_number_end:nouvelle_fonction_methode\n" if ($b_TraceDetect); # traces_filter_line
        while ($function_code =~ m{
                              (\b(if|while|for)\b|((\bcase\s+(\w\s*::\s*)*\w +\s*:\s*)|(\bdefault\s*:))+)  #1
                          }gxms)
        {
            $vg++;

            my $match = $1;                                                                                        # traces_filter_line
            my $length = length ($match);                                                                          # traces_filter_line
            my $start_pos_B0 = pos ($function_code) - $length;                                                     # traces_filter_line
            my $offset_line_number = TraceDetect::CalcLineMatch ($function_code, $start_pos_B0) if ($b_TraceDetect);  # traces_filter_line
            my $real_line_number = $function_code_line_number_start + $offset_line_number - 1 if ($b_TraceDetect); # traces_filter_line
            print STDERR "offset_line_number:$offset_line_number\n"  if ($debug);                                  # traces_filter_line
            print STDERR "real_line_number:$real_line_number\n"  if ($debug);                                      # traces_filter_line
            my $comptage_vg = 'comptage_vg' if ($b_TraceDetect);                                                   # traces_filter_line

            if ($vg == ($vg_seuil_LT + 1))
            {
                $nbr_ComplexMethodsLT++;
                $comptage_vg .= ":=>$mnemo_ComplexMethodsLT" if ($b_TraceDetect); # traces_filter_line
            }

            if ($vg == ($vg_seuil_HT + 1))
            {
                $nbr_ComplexMethodsHT++;
                $comptage_vg .= ":=>$mnemo_ComplexMethodsHT" if ($b_TraceDetect); # traces_filter_line
            }

            $trace_detect_complex_methods .= "$base_filename:$real_line_number:vg=$vg:$comptage_vg\n" if ($b_TraceDetect); # traces_filter_line
        }

        # calculs max
        $max_ComplexMethodsVg = max($max_ComplexMethodsVg, $vg);
    }

    print STDERR "max_vg:$max_ComplexMethodsVg\n"  if ($debug); # traces_filter_line

    print STDERR "$mnemo_ComplexMethodsLT = $nbr_ComplexMethodsLT\n" if ($debug);                                                   # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ComplexMethodsLT, $trace_detect_complex_methods, $options) if ($b_TraceDetect);     # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ComplexMethodsLT, $nbr_ComplexMethodsLT);

    print STDERR "$mnemo_ComplexMethodsHT = $nbr_ComplexMethodsHT\n" if ($debug);                                                   # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_ComplexMethodsHT, $trace_detect_complex_methods, $options) if ($b_TraceDetect);     # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_ComplexMethodsHT, $nbr_ComplexMethodsHT);

    print STDERR "$mnemo_max_ComplexMethodsVg = $max_ComplexMethodsVg\n" if ($debug);                                               # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_max_ComplexMethodsVg, $trace_detect_complex_methods, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_max_ComplexMethodsVg, $max_ComplexMethodsVg);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de fonctions/methodes qui ont plus d'un return
#-------------------------------------------------------------------------------
sub Count_MultipleReturnFunctionsMethods($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;

    my $trace_detect_MultipleReturnFunctionsMethods = '' if ($b_TraceDetect); # traces_filter_line
    my $mnemo_MultipleReturnFunctionsMethods = Ident::Alias_MultipleReturnFunctionsMethods();
    my $nbr_MultipleReturnFunctionsMethods = 0;

    if (not defined $vue->{'function_method_code_comment'})
    {
        assert (defined $vue->{'function_method_code_comment'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_MultipleReturnFunctionsMethods, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @function_method_code_comment= @{$vue->{'function_method_code_comment'}};

    my $functionNumber = @function_method_code_comment;                           # traces_filter_line
    print STDERR "nb function_method_code_comment:$functionNumber\n" if ($debug); # traces_filter_line

    foreach my $ref_hash_ft(@function_method_code_comment)
    {
        my %hash_ft = %$ref_hash_ft;
        assert (exists $hash_ft{'function_prototype'});                                                        # traces_filter_line
        my $function_prototype = $hash_ft{'function_prototype'};
        assert (exists $hash_ft{'function_code'});                                                             # traces_filter_line
        my $function_code = $hash_ft{'function_code'};
        assert (exists $hash_ft{'function_code_line_number_start'}) if ($b_TraceDetect);                       # traces_filter_line
        my $function_code_line_number_start = $hash_ft{'function_code_line_number_start'} if ($b_TraceDetect); # traces_filter_line
        assert (exists $hash_ft{'function_code_line_number_end'}) if ($b_TraceDetect);                         # traces_filter_line
        my $function_code_line_number_end = $hash_ft{'function_code_line_number_end'} if ($b_TraceDetect);     # traces_filter_line

        print STDERR "#########################\n" if ($debug); # traces_filter_line
        print STDERR "$function_prototype\n" if ($debug);       # traces_filter_line
        print STDERR "#\n" if ($debug);                         # traces_filter_line
        print STDERR "function_code:\n" if ($debug);            # traces_filter_line
        print STDERR "$function_code\n" if ($debug);            # traces_filter_line
        print STDERR "#\n" if ($debug);                         # traces_filter_line

        my $nb_return = 0;
        $trace_detect_MultipleReturnFunctionsMethods .= "$base_filename:$function_code_line_number_start:$function_code_line_number_start->$function_code_line_number_end:nouvelle_fonction_methode\n" if ($b_TraceDetect); # traces_filter_line
        while ($function_code =~    m{
                                (\breturn\b)  #1
                        }gxms)
        {
            $nb_return++;

            my $match = $1;                                                                                        # traces_filter_line
            my $length = length ($match);                                                                          # traces_filter_line
            my $start_pos_B0 = pos ($function_code) - $length;                                                     # traces_filter_line
            my $offset_line_number = TraceDetect::CalcLineMatch ($function_code, $start_pos_B0) if ($b_TraceDetect);  # traces_filter_line
            my $real_line_number = $function_code_line_number_start + $offset_line_number - 1 if ($b_TraceDetect); # traces_filter_line
            print STDERR "offset_line_number:$offset_line_number\n"  if ($debug);                                  # traces_filter_line
            print STDERR "real_line_number:$real_line_number\n"  if ($debug);                                      # traces_filter_line
            my $comptage = '';                                                                                     # traces_filter_line
            $comptage = '=>comptage' if ($nb_return == 2);                                                         # traces_filter_line
            $trace_detect_MultipleReturnFunctionsMethods .= "$base_filename:$real_line_number:return n°$nb_return:$comptage\n" if ($b_TraceDetect); # traces_filter_line
        }

        print STDERR "===> nb_return:$nb_return\n" if ($debug); # traces_filter_line

        if ($nb_return > 1)
        {
            # il y a de multiples return
            $nbr_MultipleReturnFunctionsMethods++;
            print STDERR "===> $mnemo_MultipleReturnFunctionsMethods ++\n" if ($debug); # traces_filter_line
        }
    }

    print STDERR "$mnemo_MultipleReturnFunctionsMethods = $nbr_MultipleReturnFunctionsMethods\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_MultipleReturnFunctionsMethods, $trace_detect_MultipleReturnFunctionsMethods, $options) if ($b_TraceDetect); # traces_filter_line

    $status |= Couples::counter_add ($compteurs, $mnemo_MultipleReturnFunctionsMethods, $nbr_MultipleReturnFunctionsMethods);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre d'affectations dans un appel de fonction methode
# Les operateurs concernes sont : = += -= *= /= %= ^= &= |= >>= <<= ++ --
#-------------------------------------------------------------------------------
sub Count_AssignmentsInFunctionCall($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    my $stackSizeError = 0;

    my $trace_detect_AssignmentsInFunctionCall = '' if ($b_TraceDetect); # traces_filter_line
    my $mnemo_AssignmentsInFunctionCall = Ident::Alias_AssignmentsInFunctionCall();
    my $nbr_AssignmentsInFunctionCall = 0;

    if (not defined $vue->{'function_method_code_comment'})
    {
        assert (defined $vue->{'function_method_code_comment'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_AssignmentsInFunctionCall, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @function_method_code_comment= @{$vue->{'function_method_code_comment'}};

    my $functionNumber = @function_method_code_comment;                           # traces_filter_line
    print STDERR "nb function_method_code_comment:$functionNumber\n" if ($debug); # traces_filter_line

    foreach my $ref_hash_ft(@function_method_code_comment)
    {
        my %hash_ft = %$ref_hash_ft;
        assert (exists $hash_ft{'function_prototype'});                                                        # traces_filter_line
        my $function_prototype = $hash_ft{'function_prototype'};
        assert (exists $hash_ft{'function_code'});                                                             # traces_filter_line
        my $function_code = $hash_ft{'function_code'};
        assert (exists $hash_ft{'function_code_line_number_start'}) if ($b_TraceDetect);                       # traces_filter_line
        my $function_code_line_number_start = $hash_ft{'function_code_line_number_start'} if ($b_TraceDetect); # traces_filter_line
        assert (exists $hash_ft{'function_code_line_number_end'}) if ($b_TraceDetect);                         # traces_filter_line
        my $function_code_line_number_end = $hash_ft{'function_code_line_number_end'} if ($b_TraceDetect);     # traces_filter_line

        print STDERR "#########################\n" if ($debug); # traces_filter_line
        print STDERR "$function_prototype\n" if ($debug);       # traces_filter_line
        print STDERR "#\n" if ($debug);                         # traces_filter_line
        print STDERR "function_code:\n" if ($debug);            # traces_filter_line
        print STDERR "$function_code\n" if ($debug);            # traces_filter_line
        print STDERR "#\n" if ($debug);                         # traces_filter_line

        $trace_detect_AssignmentsInFunctionCall .= "$base_filename:$function_code_line_number_start:$function_code_line_number_start->$function_code_line_number_end:nouvelle_fonction_methode\n" if ($b_TraceDetect); # traces_filter_line

        # pour mots-cles if, for, while : effacer le contenu entre parentheses
        # afin d'eviter de prendre en compte les eventuelles affectations
        my @stk;
        my $function_code_clean = $function_code;
        while ($function_code =~ m{
                            (                               #1
                                (\b(for|while|if)\s*\()     #2 #3
                                | (\()                      #4
                                | (\))                      #5
                            )
                         }gxms)
        {
            my $match_all = $1;
            my $match_keyword = $2;
            my $match_perenth_start = $4;
            my $match_perenth_end = $5;

            my $pos = pos ($function_code) - 1; # sur dernier caractere
            if (defined $match_keyword)
            {
                my $value = "keyword:$pos";
                push (@stk, $value);
                print STDERR "push:$value\n" if ($debug); # traces_filter_line
            }
            elsif (defined $match_perenth_start)
            {
                my $value = "$pos";
                push (@stk, $value);
                print STDERR "push:$value\n" if ($debug); # traces_filter_line
            }
            elsif (defined $match_perenth_end)
            {
                if (@stk == 0)
                {
                    assert (@stk > 0, "pile vide\n") if ($b_assert); # traces_filter_line
                    $stackSizeError = 1;
                    last;
                }

                my $value = pop (@stk);
                print STDERR "pop:$value\n" if ($debug); # traces_filter_line

                if ($value =~ /^keyword:(\d+)/)
                {
                    my $match_start_pos = $1;

                    my $length = $pos - $match_start_pos - 1;

                    substr ($function_code_clean, $match_start_pos + 1, $length) =~ s/[^\n]/ /g;

                    print STDERR "length:$length\n" if ($debug); # traces_filter_line
                }
            }
        }

        $function_code = $function_code_clean;

        print STDERR "function_code_clean:\n" if ($debug); # traces_filter_line
        print STDERR "$function_code_clean\n" if ($debug); # traces_filter_line
        print STDERR "#\n" if ($debug);                    # traces_filter_line

        my $StackLevel = 0;
        while ($function_code =~ m{
                            (                                           #1
                                (\()                                    #2
                                | (\))                                  #3
                                | (\w+\s*[><]?[+\-*/%^&|><]?=\s*\w+)    #4
                                | ((\+\+|--)\s*\w+)                     #5 #6
                                | (\w+\s*(\+\+|--))                     #7 #8
                            )
                         }gxms)
        {
            my $match_all = $1;
            my $match_parenth_start = $2;
            my $match_parenth_end = $3;
            my $match_expr_egale = $4;
            my $match_expr_pre = $5;
            my $match_expr_post = $7;

            print STDERR "match_all:$match_all\n"  if ($debug); # traces_filter_line

            if (defined $match_parenth_start)
            {
              $StackLevel++;
            }
            elsif (defined $match_parenth_end)
            {
              $StackLevel--;
            }
            elsif (defined $match_expr_egale)
            {
                if ($StackLevel > 0)
                {
                    $nbr_AssignmentsInFunctionCall++;

                    my $length = length ($match_all);                                                                      # traces_filter_line
                    my $start_pos_B0 = pos ($function_code) - $length;                                                     # traces_filter_line
                    my $offset_line_number = TraceDetect::CalcLineMatch ($function_code, $start_pos_B0) if ($b_TraceDetect);  # traces_filter_line
                    my $real_line_number = $function_code_line_number_start + $offset_line_number - 1 if ($b_TraceDetect); # traces_filter_line
                    print STDERR "offset_line_number:$offset_line_number\n"  if ($debug);                                  # traces_filter_line
                    print STDERR "real_line_number:$real_line_number\n"  if ($debug);                                      # traces_filter_line
                    print STDERR "match_all:$match_all\n"  if ($debug);                                                    # traces_filter_line
                    print STDERR "match_expr_egale:$match_expr_egale\n"  if ($debug);                                      # traces_filter_line
                    $trace_detect_AssignmentsInFunctionCall .= "$base_filename:$real_line_number:$match_expr_egale\n" if ($b_TraceDetect); # traces_filter_line
                }
            }
            elsif (defined $match_expr_pre)
            {
                if ($StackLevel > 0)
                {
                    $nbr_AssignmentsInFunctionCall++;

                    my $length = length ($match_all);                                                                      # traces_filter_line
                    my $start_pos_B0 = pos ($function_code) - $length;                                                     # traces_filter_line
                    my $offset_line_number = TraceDetect::CalcLineMatch ($function_code, $start_pos_B0) if ($b_TraceDetect);  # traces_filter_line
                    my $real_line_number = $function_code_line_number_start + $offset_line_number - 1 if ($b_TraceDetect); # traces_filter_line
                    print STDERR "offset_line_number:$offset_line_number\n"  if ($debug);                                  # traces_filter_line
                    print STDERR "real_line_number:$real_line_number\n"  if ($debug);                                      # traces_filter_line
                    print STDERR "match_all:$match_all\n"  if ($debug);                                                    # traces_filter_line
                    print STDERR "match_expr_egale:$match_expr_pre\n"  if ($debug);                                        # traces_filter_line
                    $trace_detect_AssignmentsInFunctionCall .= "$base_filename:$real_line_number:$match_expr_pre\n" if ($b_TraceDetect); # traces_filter_line
                }
            }
            elsif (defined $match_expr_post)
            {
                if ($StackLevel > 0)
                {
                    $nbr_AssignmentsInFunctionCall++;

                    my $length = length ($match_all);                                                                      # traces_filter_line
                    my $start_pos_B0 = pos ($function_code) - $length;                                                     # traces_filter_line
                    my $offset_line_number = TraceDetect::CalcLineMatch ($function_code, $start_pos_B0) if ($b_TraceDetect);  # traces_filter_line
                    my $real_line_number = $function_code_line_number_start + $offset_line_number - 1 if ($b_TraceDetect); # traces_filter_line
                    print STDERR "offset_line_number:$offset_line_number\n"  if ($debug);                                  # traces_filter_line
                    print STDERR "real_line_number:$real_line_number\n"  if ($debug);                                      # traces_filter_line
                    print STDERR "match_all:$match_all\n"  if ($debug);                                                    # traces_filter_line
                    print STDERR "match_expr_egale:$match_expr_post\n"  if ($debug);                                       # traces_filter_line
                    $trace_detect_AssignmentsInFunctionCall .= "$base_filename:$real_line_number:$match_expr_post\n" if ($b_TraceDetect); # traces_filter_line
                }
            }
        }
    }

    if ($stackSizeError)
    {
        $nbr_AssignmentsInFunctionCall = Erreurs::COMPTEUR_ERREUR_VALUE;
        $status |= Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES;
    }

    print STDERR "$mnemo_AssignmentsInFunctionCall = $nbr_AssignmentsInFunctionCall\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_AssignmentsInFunctionCall, $trace_detect_AssignmentsInFunctionCall, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_AssignmentsInFunctionCall, $nbr_AssignmentsInFunctionCall);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de destructeurs qui ont au moins un throw
#-------------------------------------------------------------------------------
sub Count_DestructorsWithThrow($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;

    my $trace_DestructorsWithThrow = '' if ($b_TraceDetect); # traces_filter_line
    my $mnemo_WithThrowDestructors = Ident::Alias_WithThrowDestructors();
    my $nbr_WithThrowDestructors = 0;

    if (not defined $vue->{'function_method_code_comment'})
    {
        assert (defined $vue->{'function_method_code_comment'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_WithThrowDestructors, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @function_method_code_comment= @{$vue->{'function_method_code_comment'}};

    my $functionNumber = @function_method_code_comment;                           # traces_filter_line
    print STDERR "nb function_method_code_comment:$functionNumber\n" if ($debug); # traces_filter_line

    foreach my $ref_hash_ft(@function_method_code_comment)
    {
        my %hash_ft = %$ref_hash_ft;
        assert (exists $hash_ft{'function_prototype'});                                                        # traces_filter_line
        my $function_prototype = $hash_ft{'function_prototype'};
        assert (exists $hash_ft{'function_code'});                                                             # traces_filter_line
        my $function_code = $hash_ft{'function_code'};
        assert (exists $hash_ft{'function_code_line_number_start'}) if ($b_TraceDetect);                       # traces_filter_line
        my $function_code_line_number_start = $hash_ft{'function_code_line_number_start'} if ($b_TraceDetect); # traces_filter_line
        assert (exists $hash_ft{'function_code_line_number_end'}) if ($b_TraceDetect);                         # traces_filter_line
        my $function_code_line_number_end = $hash_ft{'function_code_line_number_end'} if ($b_TraceDetect);     # traces_filter_line

        if (not ($function_prototype =~ /~\s*\w+\s*\(/))
        {   # ce n'est pas un destructeur
            next;
        }

        print STDERR "#########################\n" if ($debug); # traces_filter_line
        print STDERR "$function_prototype\n" if ($debug);       # traces_filter_line
        print STDERR "#\n" if ($debug);                         # traces_filter_line
        print STDERR "function_code:\n" if ($debug);            # traces_filter_line
        print STDERR "$function_code\n" if ($debug);            # traces_filter_line
        print STDERR "#\n" if ($debug);                         # traces_filter_line

        my $throwNumber = 0;

        $trace_DestructorsWithThrow .= "$base_filename:$function_code_line_number_start:$function_code_line_number_start->$function_code_line_number_end:nouvelle_fonction_methode\n" if ($b_TraceDetect); # traces_filter_line

        # apres le throw, les parentheses sont optionnelles
        while ($function_code =~ m{
                                (                               #1
                                    \bthrow\b
                                )
                                  }gxms)
        {
            $throwNumber++;

            my $match_all = $1;                                                                                           # traces_filter_line
            my $length = length ($match_all);                                                                             # traces_filter_line
            my $start_pos_B0 = pos ($function_code) - $length;                                                            # traces_filter_line
            my $offset_line_number = TraceDetect::CalcLineMatch ($function_code, $start_pos_B0) if ($b_TraceDetect);         # traces_filter_line
            my $real_line_number = $function_code_line_number_start + $offset_line_number - 1 if ($b_TraceDetect);        # traces_filter_line
            print STDERR "offset_line_number:$offset_line_number\n"  if ($debug);                                         # traces_filter_line
            print STDERR "real_line_number:$real_line_number\n"  if ($debug);                                             # traces_filter_line
            my $comptage = '';                                                                                            # traces_filter_line
            $comptage = '=>comptage' if ($throwNumber == 1);                                                                 # traces_filter_line
            $trace_DestructorsWithThrow .= "$base_filename:$real_line_number:$match_all:$comptage\n" if ($b_TraceDetect); # traces_filter_line
        }

        print STDERR "===> throwNumber:$throwNumber\n" if ($debug); # traces_filter_line

        if ($throwNumber > 0)
        {
            # il y a au moins un throw
            $nbr_WithThrowDestructors++;

            print STDERR "===> $mnemo_WithThrowDestructors ++\n" if ($debug); # traces_filter_line
        }
    }

    print STDERR "$mnemo_WithThrowDestructors = $nbr_WithThrowDestructors\n" if ($debug);                                         # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_WithThrowDestructors, $trace_DestructorsWithThrow, $options) if ($b_TraceDetect); # traces_filter_line

    $status |= Couples::counter_add ($compteurs, $mnemo_WithThrowDestructors, $nbr_WithThrowDestructors);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre d'operateur d'assignation (operator=) sans test
# de protection contre l'auto-assignation (la verification est faite dans le code)
# la methode doit commencer par le test de protection
#-------------------------------------------------------------------------------
# modele d'assignment operator qui est correct :
# const X& X::operator= (const X& rhs)
# {
#   if ( &rhs != this )
#   {
#      // Assign data members here
#   }
#   return *this;
# }
sub Count_AssignmentOperatorsWithoutAutoAssignmentTest($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;

    my $trace_detect_WithoutAutoAssignmentTestAssignmentOperators = '' if ($b_TraceDetect); # traces_filter_line
    my $mnemo_WithoutAutoAssignmentTestAssignmentOperators = Ident::Alias_WithoutAutoAssignmentTestAssignmentOperators();
    my $nbr_WithoutAutoAssignmentTestAssignmentOperators = 0;

    if (not defined $vue->{'function_method_code_comment'})
    {
        assert (defined $vue->{'function_method_code_comment'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_WithoutAutoAssignmentTestAssignmentOperators, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @function_method_code_comment= @{$vue->{'function_method_code_comment'}};

    my $functionNumber = @function_method_code_comment;                           # traces_filter_line
    print STDERR "nb function_method_code_comment:$functionNumber\n" if ($debug); # traces_filter_line

    foreach my $ref_hash_ft(@function_method_code_comment)
    {
        my %hash_ft = %$ref_hash_ft;
        assert (exists $hash_ft{'function_prototype'});                                                        # traces_filter_line
        my $function_prototype = $hash_ft{'function_prototype'};
        assert (exists $hash_ft{'function_code'});                                                             # traces_filter_line
        my $function_code = $hash_ft{'function_code'};
        assert (exists $hash_ft{'function_code_line_number_start'}) if ($b_TraceDetect);                       # traces_filter_line
        my $function_code_line_number_start = $hash_ft{'function_code_line_number_start'} if ($b_TraceDetect); # traces_filter_line
        assert (exists $hash_ft{'function_code_line_number_end'}) if ($b_TraceDetect);                         # traces_filter_line
        my $function_code_line_number_end = $hash_ft{'function_code_line_number_end'} if ($b_TraceDetect);     # traces_filter_line

        if (not ($function_prototype =~ /\boperator\s*=\s*\(\s*(const\b)?.*?&/))
        {
            # ce n'est pas un operator=
            next;
        }

        print STDERR "#########################\n" if ($debug); # traces_filter_line
        print STDERR "$function_prototype\n" if ($debug);       # traces_filter_line
        print STDERR "#\n" if ($debug);                         # traces_filter_line
        print STDERR "function_code:\n" if ($debug);            # traces_filter_line
        print STDERR "$function_code\n" if ($debug);            # traces_filter_line
        print STDERR "#\n" if ($debug);                         # traces_filter_line

        # extrait le nom du parametre
        my $parameterName = '';
        if ($function_prototype =~ /\s(\w+)\s*\)/)
        {
            $parameterName = $1;
            print STDERR "parameterName:$parameterName\n" if ($debug); # traces_filter_line
        }

        my $found = 0;
        if ($function_code =~    m{
                                (                                           #1
                                    \{\s*if\s*\(\s*&\s*$parameterName\s*!=\s*this\s*\)
                                )
                        }gxms)
        {
            my $match_all = $1;
            $found = 1;
        }

        my $comptage = '' if ($b_TraceDetect); # traces_filter_line
        if (not $found)
        {
            $nbr_WithoutAutoAssignmentTestAssignmentOperators++;

            $comptage = '=>comptage' if ($b_TraceDetect); # traces_filter_line
        }
        $trace_detect_WithoutAutoAssignmentTestAssignmentOperators .= "$base_filename:$function_code_line_number_start:$function_code_line_number_start->$function_code_line_number_end:nouvelle_fonction_methode:$comptage\n" if ($b_TraceDetect); # traces_filter_line
    }

    print STDERR "$mnemo_WithoutAutoAssignmentTestAssignmentOperators = $nbr_WithoutAutoAssignmentTestAssignmentOperators\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_WithoutAutoAssignmentTestAssignmentOperators, $trace_detect_WithoutAutoAssignmentTestAssignmentOperators, $options) if ($b_TraceDetect); # traces_filter_line

    $status |= Couples::counter_add ($compteurs, $mnemo_WithoutAutoAssignmentTestAssignmentOperators, $nbr_WithoutAutoAssignmentTestAssignmentOperators);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre d'operateur d'assignation (operator=) qui ne
# retournent pas '*this' en fin de methode
#-------------------------------------------------------------------------------
sub Count_AssignmentOperatorsWithoutReturningStarThis($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;

    my $trace_detect_assign_op_without_returning_star_this = '' if ($b_TraceDetect); # traces_filter_line
    my $mnemo_assign_op_without_returning_star_this = Ident::Alias_WithoutReturningStarThisAssignmentOperators();
    my $nbr_assign_op_without_returning_star_this = 0;

    if (not defined $vue->{'function_method_code_comment'})
    {
        assert (defined $vue->{'function_method_code_comment'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add ($compteurs, $mnemo_assign_op_without_returning_star_this, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @function_method_code_comment= @{$vue->{'function_method_code_comment'}};

    my $functionNumber = @function_method_code_comment;                           # traces_filter_line
    print STDERR "nb function_method_code_comment:$functionNumber\n" if ($debug); # traces_filter_line

    foreach my $ref_hash_ft(@function_method_code_comment)
    {
        my %hash_ft = %$ref_hash_ft;
        assert (exists $hash_ft{'function_prototype'});                                                        # traces_filter_line
        my $function_prototype = $hash_ft{'function_prototype'};
        assert (exists $hash_ft{'function_code'});                                                             # traces_filter_line
        my $function_code = $hash_ft{'function_code'};
        assert (exists $hash_ft{'function_code_line_number_start'}) if ($b_TraceDetect);                       # traces_filter_line
        my $function_code_line_number_start = $hash_ft{'function_code_line_number_start'} if ($b_TraceDetect); # traces_filter_line
        assert (exists $hash_ft{'function_code_line_number_end'}) if ($b_TraceDetect);                         # traces_filter_line
        my $function_code_line_number_end = $hash_ft{'function_code_line_number_end'} if ($b_TraceDetect);     # traces_filter_line

        if (not ($function_prototype =~ /\boperator\s*=\s*\(\s*const.*?&/))
        {
            # ce n'est pas un operator=
            next;
        }

        print STDERR "#########################\n" if ($debug); # traces_filter_line
        print STDERR "$function_prototype\n" if ($debug);       # traces_filter_line
        print STDERR "#\n" if ($debug);                         # traces_filter_line
        print STDERR "function_code:\n" if ($debug);            # traces_filter_line
        print STDERR "$function_code\n" if ($debug);            # traces_filter_line
        print STDERR "#\n" if ($debug);                         # traces_filter_line

        my $found = 0;
        if ($function_code =~    m{
                                (                                           #1
                                    \breturn\s*\*\s*this\s*;\s*\}\s*\z
                                )
                        }gxms)
        {
            my $match_all = $1;
            $found = 1;
        }

        my $comptage = '' if ($b_TraceDetect); # traces_filter_line
        if (not $found)
        {
            $nbr_assign_op_without_returning_star_this++;
            $comptage = '=>comptage' if ($b_TraceDetect); # traces_filter_line
        }

        $trace_detect_assign_op_without_returning_star_this .= "$base_filename:$function_code_line_number_start:$function_code_line_number_start->$function_code_line_number_end:nouvelle_fonction_methode:$comptage\n" if ($b_TraceDetect); # traces_filter_line
    }

    print STDERR "$mnemo_assign_op_without_returning_star_this = $nbr_assign_op_without_returning_star_this\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_assign_op_without_returning_star_this, $trace_detect_assign_op_without_returning_star_this, $options) if ($b_TraceDetect); # traces_filter_line

    $status |= Couples::counter_add ($compteurs, $mnemo_assign_op_without_returning_star_this, $nbr_assign_op_without_returning_star_this);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage du nombre de definitions globales (hors namespace hors classe)
#-------------------------------------------------------------------------------
sub Count_GlobalDefinition($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    my $langage = $$compteurs{'Dat_Language'};
    my $b_analyse_cpp = ($langage eq 'Cpp') || ($langage eq 'Hpp');

    my $trace_detect_GlobalDefinitions = '' if ($b_TraceDetect); # traces_filter_line
    #  declaration de fonctions/methodes
    my $mnemo_GlobalDefinitions = Ident::Alias_GlobalDefinitions();
    my $nbr_GlobalDefinitions = 0;

    if ((not defined $vue->{'parsed_code'}) || (not defined $vue->{'prepro_directives'}))
    {
        assert (defined $vue->{'parsed_code'}) if ($b_assert);       # traces_filter_line
        assert (defined $vue->{'prepro_directives'}) if ($b_assert); # traces_filter_line

        $status |= Couples::counter_add ($compteurs, $mnemo_GlobalDefinitions, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my @parsed_code = @{$vue->{'parsed_code'}};
    my $prepro_directives = $vue->{'prepro_directives'};
    # 1ere partie : tout sauf macros
    my %hash_ImplMultClasses;
    $trace_detect_GlobalDefinitions .= "#1ere partie : tout sauf macros:\n" if ($b_TraceDetect); # traces_filter_line
    foreach my $item_foreach (@parsed_code)
    {
        my $kind = $item_foreach->[0];
        my $hash_ref = $item_foreach->[1];
        my %hash_item = %$hash_ref;
        assert (exists $hash_item{'uid'}); # traces_filter_line
        my $uid = $hash_item{'uid'};
        if (($kind == PARSER_CPP_PROTOTYPE_KR)
         || ($kind == PARSER_CPP_TYPEDEF_PTR_SUR_FONCTION)
         || ($kind == PARSER_CPP_TYPEDEF_SCALAIRE)
         || ($kind == PARSER_CPP_DECLARATION_VARIABLE)
         || ($kind == PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE)
         || ($kind == PARSER_CPP_DECLARATION_STRUCT_AVEC_INIT)
         || ($kind == PARSER_CPP_DECLARATION_STRUCT)
         || ($kind == PARSER_CPP_DECLARATION_ENUM)
         || ($kind == PARSER_CPP_TEMPLATE_STRUCT)
         || ($kind == PARSER_CPP_VAR_GLOB_INIT_ACCOLADE)
            )
        {
            my $line_number = 0;                                          # traces_filter_line
            $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
            my $item = $hash_item{'item'};                                # traces_filter_line
            print STDERR "#### line : $line_number\n" if ($debug);        # traces_filter_line
            print STDERR "uid:$uid\n" if ($debug);                        # traces_filter_line
            print STDERR "$item\n" if ($debug);                           # traces_filter_line
            assert (exists $hash_item{'b_global_def'});                   # traces_filter_line

            my $b_global_def = $hash_item{'b_global_def'};

            if ($b_global_def == 1)
            {
                $nbr_GlobalDefinitions++;

                my $trace_line = "$base_filename:$line_number:$item:\n" if ($b_TraceDetect); # traces_filter_line
                $trace_detect_GlobalDefinitions .= $trace_line if ($b_TraceDetect);          # traces_filter_line
            }
        }
    }

    # 2eme partie : macros:
    $trace_detect_GlobalDefinitions .= "#2eme partie : macros:\n" if ($b_TraceDetect); # traces_filter_line

    # ne compte pas la protection de fichier .h comme :
    # #ifndef FICHIER_H
    # #define FICHIER_H
    # ni les definitions vides comme
    # #define VALZ
    while ($prepro_directives =~    m{
                            (
                                ^[[:blank:]]*\#[[:blank:]]*define\s+(\w+)(.*)$
                            )
                        }gmx)
    {
        my $full_macro = $1;
        my $macro_name = $2;
        my $macro_val = $3;

        print STDERR "====================\n" if ($debug);                          # traces_filter_line
        print STDERR "full_macro:$full_macro\n" if ($debug);                        # traces_filter_line
        print STDERR "==\n" if ($debug);                                            # traces_filter_line
        print STDERR "macro_name1:$macro_name:\n" if ($debug);                      # traces_filter_line
        print STDERR "macro_val:$macro_val:\n" if ($debug && defined ($macro_val)); # traces_filter_line

        if ((defined $macro_val) && ($macro_val =~ /[^\s]/))
        {
            $nbr_GlobalDefinitions++;

            my $pos = pos ($prepro_directives) if ($b_TraceDetect);                                   # traces_filter_line
            my $line_number = TraceDetect::CalcLineMatch ($prepro_directives, $pos) if ($b_TraceDetect); # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$macro_name\n" if ($b_TraceDetect);         # traces_filter_line
            $trace_detect_GlobalDefinitions .= $trace_line if ($b_TraceDetect);                       # traces_filter_line
        }
    }

    print STDERR "$mnemo_GlobalDefinitions = $nbr_GlobalDefinitions\n" if ($debug);                                                # traces_filter_line
    TraceDetect::DumpTraceDetect ($fichier, $mnemo_GlobalDefinitions, $trace_detect_GlobalDefinitions, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add ($compteurs, $mnemo_GlobalDefinitions, $nbr_GlobalDefinitions);

    return $status;
}

1;

