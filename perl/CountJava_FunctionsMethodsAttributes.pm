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

# Description: Composant de mesure de source Java, pour creation d'alertes

package CountJava_FunctionsMethodsAttributes;

use strict;
use warnings;

use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use TraceDetect;
use Timeout;

# prototypes publics
sub CountFunctionsMethodsAttributes($$$$);


#-------------------------------------------------------------------------------
# 1) Module de comptage du nombre de methodes d'implementation
#    cad celles qui ont du code
# 2) idem mais sans code
# 3) Module de comptage du nombre de classe implemente dans le fichier
# 4) Module de comptage du nombre d'attribut public et package
# 5) Module de comptage du nombre d'attributs protected et private
# 6) Module de comptage du nombre de classes et d'interfaces
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
sub RecupScopeNamespaceClass(@);
sub CountFunctionsMethodsAttributesParse($$$$$);
sub CountFunctionsMethodsAttributesClean($$$$);
sub CountBadDeclarationOrder(@);

sub CountFunctionsMethodsAttributes($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;

    my ($status, $c) = CountFunctionsMethodsAttributesClean($fichier, $vue, $couples, $options);
    $status |= CountFunctionsMethodsAttributesParse($fichier, $vue, $couples, $options, $c);

    return $status;
}

sub CountFunctionsMethodsAttributesClean($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0); # traces_filter_line
    my $b_TraceIn = ((exists $options->{'--TraceIn'})? 1 : 0); # traces_filter_line

    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $status = 0;
    my $debug = 0; # traces_filter_line
    my $debug2 = 0; # traces_filter_line

    if (!defined $vue->{'code'})
    {
	assert(defined $vue->{'code'}) if ($b_assert); # traces_filter_line
	$status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	return $status;
    }

    my $step = 0;

    my $c = $vue->{'code'}; # code
    my $fic_out = $fichier . ".methods_impl_outB" . $step if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    TraceDetect::TraceOutToFile($fic_out, $c) if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    my $f = $c; # code filtre

    $step++;
    print STDERR "#STEP:$step\n" if ($debug); # traces_filter_line
    # effacer les sections de code cad {...} sauf accolades
    # pour ne pas matcher les appels de fonctions
    # dans le code comme :
    # {  int z = add(c1, c2) + add (c1, c2); }
    my @arr_match_pos_start;
    my $b_stack_size_error = 0;
    while ($c =~ m{
                    (\s(class|interface|enum)\s.*?([\{;])) #1 #2 #3
                    | (\{|\})                   #4
                }gxms)
    {
        my $match_grp = $1;
        my $match_grp_end = $3;
        my $match_symb_accolade = $4;
    
        my $pos_c_B0 = pos($c) -1;
        my $start_pos_B0 = 0;
        if (defined $match_grp)
        {
            $start_pos_B0 = $pos_c_B0 - length($match_grp);
        }
        else
        {
            $start_pos_B0 = $pos_c_B0 - 1;
        }
        my $line_number = TraceDetect::CalcLineMatch($c, $start_pos_B0) if ($b_TraceDetect); # traces_filter_line
        my $pile_level = @arr_match_pos_start if ($b_TraceDetect && $debug2); # traces_filter_line
        print STDERR "### line_number:$line_number:pile_level:$pile_level\n" if($b_TraceDetect && $debug2); # traces_filter_line
        if (defined $match_grp)
        {
            # filtre implicitement les forward declaration
            if ($match_grp_end eq '{')
            {
                my $pos_c = pos($c);
                my $value = "grp:$pos_c";
                #print STDERR "push value:$value\n";
                push(@arr_match_pos_start, $value);
            }
        }
        elsif (defined $match_symb_accolade)
        {
            my $pos_c = pos($c);
            print STDERR "$match_symb_accolade =  $match_symb_accolade at $pos_c\n" if ($debug); # traces_filter_line
            if ($match_symb_accolade eq '{')
            {
                push(@arr_match_pos_start, $pos_c);
            }
            elsif ($match_symb_accolade eq '}')
            {
                my $nb = @arr_match_pos_start;
                if ($nb<= 0)
                {
                    $b_stack_size_error = 1;
                    print STDERR "pile vide 2\n" if ($b_TraceInconsistent); # traces_filter_line
                    assert($nb > 0, 'pile vide 2') if ($b_assert); # traces_filter_line
                    next; # continue sans assert
                }
                my $value = pop(@arr_match_pos_start);
            
                #print STDERR "value:$value\n";
                if (!($value =~ /:/))
                {
                    $value++; # ne prends pas '{'
                    $pos_c--; # ne prends pas '}'
                    my $nb = $pos_c - $value +1;
                    my $start_B0 = $value - 1; # base 0
                    my $pos_c_B0 = $pos_c - 1;
                    print STDERR "ERASE $start_B0-$pos_c_B0 : from $start_B0, nb = $nb\n" if ($debug); # traces_filter_line
                    #my $str_efface = substr($f, $start_B0, $nb);
                    #print STDERR "EFFACE:$str_efface\n"; # traces_filter_line
                    substr($f, $start_B0, $nb) =~ s/[^\n\s]/ /sg;
                }
            }
        }
    }
    $fic_out = $fichier . ".methods_impl_outB" . $step if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    TraceDetect::TraceOutToFile($fic_out, $f)  if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    $step++;
    print STDERR "#STEP:$step\n" if ($debug); # traces_filter_line
    #supprime les initialisations de variables membre comme :
    #  public static final Comparator COMPARABLE_COMAPRATOR = new Comparator() {
    #  ...
    while ($c =~ m{
                    (=.*?[;\{])
		}gxms)
    {
        my $match = $1;
        print STDERR "==> $match\n" if ($debug); # traces_filter_line
        my $pos_c = pos($c) - 1; # ne prends pas le ';'
        my $pos_c_B0 = $pos_c - 1; # base 0
        my $nb = length($match) - 1; # ne prends parenthese et le ';'
        $nb--; # ne prend pas le '='
        my $start_B0 = $pos_c_B0 - $nb + 1;
        my $end_B0 = $start_B0 + $nb - 1;
        print STDERR "ERASE init var membre $start_B0-$end_B0, from $start_B0, nb $nb \n" if ($debug); # traces_filter_line
        substr($f, $start_B0, $nb) =~ s/[^\n\s]/ /sg;
    }
    $fic_out = $fichier . ".methods_impl_outB" . $step if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    TraceDetect::TraceOutToFile($fic_out, $f) if ($b_TraceDetect && $b_TraceIn); # traces_filter_line
    $step++;
    print STDERR "#STEP:$step\n" if ($debug); # traces_filter_line

    return ($status, $f);
}

my $parser_java = 0;
use constant PARSER_JAVA_UNDEFINED => $parser_java++;
use constant PARSER_JAVA_DECLARATION_ENUMERE => $parser_java++;
use constant PARSER_JAVA_IMPORT => $parser_java++;
use constant PARSER_JAVA_PACKAGE => $parser_java++;
use constant PARSER_JAVA_DECLARATION_METHOD_VIRTUEL_PURE => $parser_java++;
use constant PARSER_JAVA_DECLARATION_VARIABLE => $parser_java++;
use constant PARSER_JAVA_IMPLEMENTATION_METHOD => $parser_java++;
use constant PARSER_JAVA_DECLARATION_CLASS => $parser_java++;
use constant PARSER_JAVA_DECLARATION_INTERFACE => $parser_java++;
use constant PARSER_JAVA_DECLARATION_CLASS_ENUMERE => $parser_java++;
use constant PARSER_JAVA_INITIALISER_INSTANCE => $parser_java++;
use constant PARSER_JAVA_INITIALISER_STATIQUE => $parser_java++;
use constant PARSER_JAVA_DECLARATION_VARIABLE_AVEC_INIT_CLASS_ANONYM => $parser_java++;
use constant PARSER_JAVA_ACCOL_OUVR_UNKNOWN => $parser_java++;

sub ParseVariables($$$$$$);
sub Count_Parameters($$$$@);
sub Count_AttributeNaming($$$$@);
sub Count_ClassNaming($$$$@);
sub Count_MethodNaming($$$$@);
sub Count_BadDeclarationOrder($$$$@);
sub Count_Equals($$$$@);
sub Count_Parents($$$$@);
sub Count_PublicPrivateAttributes($$$$@);

sub CountFunctionsMethodsAttributesParse($$$$$)
{
    my ($fichier, $vue, $couples, $options, $c) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0); # traces_filter_line
    my @arr_parse_items; # contient des hash

    my $status = 0;
    my $debug = 0; # traces_filter_line
    my $debug2 = ((exists $options->{'--FMAdebug'})? 1 : 0); # traces_filter_line

    my @arr_match_pos_start;
    print STDERR "##############################################\n" if ($debug2); # traces_filter_line
    my $b_stack_size_error = 0;
    my $b_enum = 0;
    while ($c =~ m{
                            (\s*)                   #1
                            |
                            (                       #2
                                (.*?)               #3
                                (                   #4
                                    (;)             #5
                                    |   (\{)        #6
                                    |   (\})        #7
                                )
			    )
		 }gxms )
    {
        my $match_spaces = $1;
        my $match_all = $2;
        my $match_avant = $3;
        my $match_pt_virgule = $5;
        my $match_accolad_ouvre = $6;
        my $match_accolad_ferme = $7;
        if (defined $match_spaces)
        {   next;   }
        # nettoyage
        my $match_avant_multiline = $match_avant;
        $match_avant =~ s/\s+/ /g;
        $match_avant =~ s/\s+$//;
        $match_avant =~ s/\n/ /g;
    
        my $pos_c_B0 = pos($c) -1;
        print STDERR "=============\n" if ($debug2); # traces_filter_line
        print STDERR "=match_all:$match_all\n" if ($debug2); # traces_filter_line
        my $len_match_all = length($match_all);
        my $len_avant = length($match_avant);
        my $start_pos_B0 = $pos_c_B0-$len_match_all+1;
        #print STDERR "start_pos_B0:$start_pos_B0\n" if ($debug); # traces_filter_line
        my $line_number = TraceDetect::CalcLineMatch($c, $start_pos_B0) if ($b_TraceDetect); # traces_filter_line
        print STDERR "line_number:$line_number\n" if($b_TraceDetect && $debug2); # traces_filter_line
    
        my %hash_item;
        $hash_item{'item'} = $match_avant;
        $hash_item{'line_number'} = $line_number if ($b_TraceDetect); # traces_filter_line
    
        if (defined $match_pt_virgule)
        {
            #print STDERR "=> point virgule\n" if ($debug); # traces_filter_line
            if ($b_enum)
            {   # avant le premier ';' c'est l'enumeration
                my $liste_enum = $match_avant_multiline;
                print STDERR "======>>>>>> liste enumere\n" if ($debug2); # traces_filter_line
                $b_enum = 0;
                # supprime les eventuelles init d'enumere
                while ($liste_enum =~ s/\([^\(\)]*\)//)
                { } # vide
                my $offset = 0 if ($b_TraceDetect); # traces_filter_line
                my @arr_lines = split('\n', $liste_enum);
                foreach my $line (@arr_lines)
                {
                    print STDERR "line_enum:$line\n" if ($debug2); # traces_filter_line
                    $hash_item{'line_number'} = ($line_number+$offset)  if ($b_TraceDetect); # traces_filter_line
                    my @arr_enum = split('\s*,\s*', $line);
                    foreach my $enum(@arr_enum)
                    {
                        print STDERR "enum:$enum\n" if ($debug2); # traces_filter_line
                        # nettoyage
                        $enum =~ s/\s+/ /g;
                        $enum =~ s/\s+$//;
                        $enum =~ s/^\s*//;
                        $hash_item{'enum_name'} = $enum;
                        my %hash_item2 = %hash_item; # duplication
                        push(@arr_parse_items, [PARSER_JAVA_DECLARATION_ENUMERE, \%hash_item2]);
                    }
                    $offset++ if ($b_TraceDetect); # traces_filter_line
                }
            }
            elsif ($match_avant =~ /\bimport\b/)
            {
                print STDERR "======>>>>>> import\n" if ($debug2); # traces_filter_line
                push(@arr_parse_items, [PARSER_JAVA_IMPORT, \%hash_item]);
            }
            elsif ($match_avant =~ /\bpackage\s+([\w\.]+)/)
            {
                my $match_package_name = $1;
                print STDERR "======>>>>>> package:$match_package_name\n" if ($debug2); # traces_filter_line
                push(@arr_parse_items, [PARSER_JAVA_PACKAGE, \%hash_item]);
                my $value = "package:$match_package_name:$pos_c_B0";
                push(@arr_match_pos_start, $value);
            }
            elsif ($match_avant =~ /(\w+)\s*\(/)
            {
                my $match_method_name = $1;
                print STDERR "======>>>>>> declaration methode virtuelle pure: $match_method_name\n" if ($debug2); # traces_filter_line
                push(@arr_parse_items, [PARSER_JAVA_DECLARATION_METHOD_VIRTUEL_PURE, \%hash_item]);
                $hash_item{'method_name'} = $match_method_name;
                my $tag = '-Decl-Meth-Vpur-';
                my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass(@arr_match_pos_start);
                $hash_item{'scope_namespace'} = $scope_namespace;
                $hash_item{'scope_class'} = $scope_class;
                $hash_item{'tag'} = $tag;
            }
            elsif ($match_all ne ';')
            {   # filtre implicitement les ';' seuls
                print STDERR "======>>>>>> declaration de variable <<<<<<<<<==============\n" if ($debug2); # traces_filter_line
                #push(@arr_parse_items, [PARSER_JAVA_DECLARATION_VARIABLE, \%hash_item]);
                my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass(@arr_match_pos_start);
                $hash_item{'scope_namespace'} = $scope_namespace;
                $hash_item{'scope_class'} = $scope_class;
                my $match_to_analyse = $match_all;
                $match_to_analyse =~ s/\s*=?\s*;//;
                ParseVariables($fichier, $couples, $options, $match_to_analyse, \@arr_parse_items, \%hash_item);
            }
        }
        elsif (defined $match_accolad_ouvre)
        {
            if ($match_avant =~ /(\w+)\s*\(/)
            {
                my $match_method_name = $1;
                print STDERR "======>>>>>> implementation methode: $match_method_name\n" if ($debug2); # traces_filter_line
                push(@arr_parse_items, [PARSER_JAVA_IMPLEMENTATION_METHOD, \%hash_item]);
                $hash_item{'method_name'} = $match_method_name;
                push(@arr_match_pos_start, $pos_c_B0);
                my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass(@arr_match_pos_start);
                $hash_item{'scope_namespace'} = $scope_namespace;
                $hash_item{'scope_class'} = $scope_class;
                my $tag = '-Imp-Meth-';
                if ($match_avant =~ /\bfinal\b/)
                {   $tag .= 'Final-';    }
                if ($match_avant =~ /(\w+)\s*\(/)
                {
                    my $match_name = $1;
                    if ($match_name eq $scope_class)
                    {
                        $tag .= 'Ctor-';
                        $hash_item{'b_Ctor'} = 1;
                    }
                    else
                    {
                        $hash_item{'b_Ctor'} = 0;
                    }
                }
                $hash_item{'tag'} = $tag;
            }
            elsif ($match_avant =~ /\bclass\s+(\w+)/)
            {
                my $match_class_name = $1;
                $hash_item{'class_name'} = $match_class_name;
                print STDERR "======>>>>>> declaration de classe: $match_class_name\n" if ($debug2); # traces_filter_line
                push(@arr_parse_items, [PARSER_JAVA_DECLARATION_CLASS, \%hash_item]);
                my $value = "class:$match_class_name:$pos_c_B0";
                push(@arr_match_pos_start, $value);
                # nettoyage
                $match_all =~ s/\n/ /g if ($b_TraceDetect); # traces_filter_line
                $match_all =~ s/\s*\{$/ / if ($b_TraceDetect); # traces_filter_line
                $match_all =~ s/\s*$// if ($b_TraceDetect); # traces_filter_line
                $match_all =~ s/\s+/ /g if ($b_TraceDetect); # traces_filter_line
                $hash_item{'item'} = $match_all;
            }
            elsif ($match_avant =~ /\binterface\s+(\w+)/)
            {
                my $match_class_name = $1;
                $hash_item{'class_name'} = $match_class_name;
                print STDERR "======>>>>>> declaration d'interface: $match_class_name\n" if ($debug2); # traces_filter_line
                push(@arr_parse_items, [PARSER_JAVA_DECLARATION_INTERFACE, \%hash_item]);
                my $value = "interface:$match_class_name:$pos_c_B0";
                push(@arr_match_pos_start, $value);
                # nettoyage
                $match_all =~ s/\n/ /g if ($b_TraceDetect); # traces_filter_line
                $match_all =~ s/\s*\{$/ / if ($b_TraceDetect); # traces_filter_line
                $match_all =~ s/\s*$// if ($b_TraceDetect); # traces_filter_line
                $match_all =~ s/\s+/ /g if ($b_TraceDetect); # traces_filter_line
                $hash_item{'item'} = $match_all;
            }
            elsif ($match_avant =~ /\benum\s+(\w+)/)
            {
                my $match_class_name = $1;
                $b_enum = 1;
                $hash_item{'class_name'} = $match_class_name;
                print STDERR "======>>>>>> declaration de classe: $match_class_name\n" if ($debug2); # traces_filter_line
                push(@arr_parse_items, [PARSER_JAVA_DECLARATION_CLASS_ENUMERE, \%hash_item]);
                my $value = "class:$match_class_name:$pos_c_B0";
                push(@arr_match_pos_start, $value);
                # nettoyage
                $match_all =~ s/\n/ /g if ($b_TraceDetect); # traces_filter_line
                $match_all =~ s/\s*\{$/ / if ($b_TraceDetect); # traces_filter_line
                $match_all =~ s/\s*$// if ($b_TraceDetect); # traces_filter_line
                $match_all =~ s/\s+/ /g if ($b_TraceDetect); # traces_filter_line
                $hash_item{'item'} = $match_all;
            }
            elsif ($match_avant eq '')
            {
                print STDERR "======>>>>>> initialiseur d'instance (sans nom)\n" if ($debug2); # traces_filter_line
                push(@arr_parse_items, [PARSER_JAVA_INITIALISER_INSTANCE, \%hash_item]);
                my $value = "initialiseur_d_instance::$pos_c_B0";
                push(@arr_match_pos_start, $value);
            }
            elsif ($match_avant =~ /^static\s*$/)
            {
                print STDERR "======>>>>>> initialiseur statique (sans nom)\n" if ($debug2); # traces_filter_line
                push(@arr_parse_items, [PARSER_JAVA_INITIALISER_STATIQUE, \%hash_item]);
                my $value = "initialiseur_statique::$pos_c_B0";
                push(@arr_match_pos_start, $value);
            }
            elsif ($match_avant =~ /=/)
            {   # c'est une variable avec une initialisation utilisant une classe anonyme comme
                #  public static final Comparator COMPARABLE_COMAPRATOR = new Comparator() {
                #  ...
                my ($scope_namespace, $scope_class) = RecupScopeNamespaceClass(@arr_match_pos_start);
                $hash_item{'scope_namespace'} = $scope_namespace;
                $hash_item{'scope_class'} = $scope_class;
                my $match_to_analyse = $match_avant;
                $match_to_analyse =~ s/\s*=.*//;
                ParseVariables($fichier, $couples, $options, $match_to_analyse, \@arr_parse_items, \%hash_item);
                my $value = "var_inst_clas_ano::$pos_c_B0";
                push(@arr_match_pos_start, $value);
            }
            else
            {
                print STDERR "======>>>>>> ?????????????????????? <<<<<<=======\n" if ($debug2); # traces_filter_line
                push(@arr_parse_items, [PARSER_JAVA_ACCOL_OUVR_UNKNOWN, \%hash_item]);
                push(@arr_match_pos_start, $pos_c_B0);
            }
        }
        elsif (defined $match_accolad_ferme)
        {
            print STDERR "=> accolad ferme\n" if ($debug); # traces_filter_line
            my $nb = @arr_match_pos_start;
            if ($nb <= 0)
            {
                $b_stack_size_error = 1;
                print STDERR "pile vide 3\n" if ($b_TraceInconsistent); # traces_filter_line
                assert($nb > 0, 'pile vide 3') if ($b_assert); # traces_filter_line
                last;
            }
            pop(@arr_match_pos_start);
        }
    }
    my $nb = @arr_match_pos_start;
    if ($nb != 0)
    {
        my $item = $arr_match_pos_start[0];
        if ((($nb == 1) && !($item =~ /^package:/))
            || ($nb > 1))
        {
            $b_stack_size_error = 1;
            print STDERR "la pile devrait etre vide\n" if ($b_TraceInconsistent); # traces_filter_line
            assert($nb != 0, 'la pile devrait etre vide') if ($b_assert); # traces_filter_line
        }
    }

    $status |= Count_Parameters($fichier, $couples, $options, $b_stack_size_error,@arr_parse_items);
    $status |= Count_AttributeNaming($fichier, $couples, $options, $b_stack_size_error,@arr_parse_items);
    $status |= Count_ClassNaming($fichier, $couples, $options, $b_stack_size_error,@arr_parse_items);
    $status |= Count_MethodNaming($fichier, $couples, $options, $b_stack_size_error,@arr_parse_items);
    $status |= Count_BadDeclarationOrder($fichier, $couples, $options, $b_stack_size_error,@arr_parse_items);
    $status |= Count_Equals($fichier, $couples, $options, $b_stack_size_error,@arr_parse_items);
    $status |= Count_Parents($fichier, $couples, $options, $b_stack_size_error,@arr_parse_items);
    $status |= Count_PublicPrivateAttributes($fichier, $couples, $options, $b_stack_size_error,@arr_parse_items);
    $status |= Count_ClassesInterfaces($fichier, $couples, $options, $b_stack_size_error,@arr_parse_items);
    $status |= Count_Methods($fichier, $couples, $options, $b_stack_size_error,@arr_parse_items);

    if ($b_stack_size_error)
    {
        $status |= Erreurs::COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE;
    }

    return $status;
}

sub RecupScopeNamespaceClass(@)
{
    my (@arr_match_pos_start) = @_;
    # recupere le scope de la classe ds la pile
    my $scope_class = '';
    my $nb = @arr_match_pos_start;
    for(my $i=$nb-1; $i>=0; $i--)
    {
        if ($arr_match_pos_start[$i] =~ /class|interface/)
        {
            my $one_scope_class = $arr_match_pos_start[$i];
            $one_scope_class =~ s/.*?:(\w+):.*/$1/;
            if ($scope_class eq '')
            {   $scope_class = $one_scope_class;     }
            else
            {   $scope_class = $one_scope_class . '.' . $scope_class;  }
            #last;
        }
    }
    # recupere le scope du namespace dans la pile
    my $scope_namespace = '';
    for(my $i=$nb-1; $i>=0; $i--)
    {
        if ($arr_match_pos_start[$i] =~ /package/)
        {
            $scope_namespace = $arr_match_pos_start[$i];
            $scope_namespace =~ s/.*?:([\w\.]+):.*/$1/;
            last;
        }
    }
    return ($scope_namespace, $scope_class);
}

# Analyse les declarations de variables
sub ParseVariables($$$$$$)
{
    my ($fichier, $couples, $options, $match_to_analyse, $ref_arr_parse_items, $ref_hash_item) = @_;
    my %hash_item = %$ref_hash_item; # duplication locale
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $status = 0;
    my $debug = 0; # traces_filter_line
    assert(exists $hash_item{'line_number'}) if ($b_TraceDetect); # traces_filter_line
    my $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
    # compte les separateur de variables
    my $match_all_sans_template = $match_to_analyse;
    my $template = '';
    if ($match_to_analyse =~ /(<.*>)/)
    {
        $template = $1; # recupere la partie template
        $match_all_sans_template =~ s/<.*>//; # supprime les < .. >
    }
    my $nb_virg = () = $match_all_sans_template =~ /,/g;
    $hash_item{'item'} = $match_to_analyse;

    # separe decl multiple de variables comme :
    # private int reel, reel2;
    my @arr_var = split(',\s*', $match_all_sans_template);
    # extrait le type comme :
    # protected String[][] tableau;
    my $type_var = $arr_var[0];
    my $type = '';
    my $var1_name = '';
    my $crochets = '';
    if ($type_var =~ /(\[.*\])/)
    {
        $crochets = $1; # recupere les crochets pour les tableaux
        $type_var =~ s/\[.*\]//; # supprime les crochets
    }
    if ($type_var =~ /^(.*)\s(\w+)$/)
    {
       $type = $1 . $template . $crochets;
       $var1_name = $2;
       print "type = $type\n" if ($debug); # traces_filter_line
       print "crochets = $crochets\n" if ($debug); # traces_filter_line
       print "var1_name = $var1_name\n" if ($debug); # traces_filter_line
       $arr_var[0] = $var1_name;
       $hash_item{'var_type'} = $type;
    }
    else
    {
        $hash_item{'var_type'} = 'aucun?';
        print "ICI : $match_to_analyse\n";
        print "type_var=$type_var\n";
    }
    for(my $i=1; $i<=($nb_virg+1); $i++)
    {
        my $attribute_name = $arr_var[$i-1];
        $hash_item{'var_name'} = $attribute_name;
        my $visibility;
        if ($match_to_analyse =~ /\bprivate\b/)
        {
            $visibility = 'private';
        }
        elsif ($match_to_analyse =~ /\bprotected\b/)
        {
            $visibility = 'protected';
        }
        elsif ($match_to_analyse =~ /\bpublic\b/)
        {
            $visibility = 'public';
        }
        else
        {   # package
            $visibility = 'package';
        }
        $hash_item{'var_visibility'} = $visibility;
        my %hash_item2 = %hash_item; # duplication
        push(@$ref_arr_parse_items, [PARSER_JAVA_DECLARATION_VARIABLE, \%hash_item2]);
    }
}

#-------------------------------------------------------------------------------
# comptage des classes qui ne respectent pas l'ordre de declaration
#-------------------------------------------------------------------------------
sub Count_BadDeclarationOrder($$$$@)
{
    my ($fichier, $couples, $options, $error, @arr_parse_items) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $status = 0;
    my $debug = 0; # traces_filter_line
    # mauvais ordre de declaration
    my $nb_bad_declaration_order = 0;
    my $mnemo_bad_declaration_order = Ident::Alias_BadDeclarationOrder();
    my $trace_detect_bad_declaration_order = "#class scope, kind:\n" if ($b_TraceDetect); # traces_filter_line
    my @arr_class_scope_kind; #n°:[VS(var_static), VI(var_instance), CT(ctor), (ME)methode]

    if ($error != 1)
    {
        foreach my $item (@arr_parse_items)
        {
            my $kind = $item->[0];
            my $hash_ref = $item->[1];
            my %hash_item = %$hash_ref;
            my $nb_param = 0;
            if (($kind == PARSER_JAVA_DECLARATION_METHOD_VIRTUEL_PURE)
                 || ($kind == PARSER_JAVA_DECLARATION_VARIABLE)
                 || ($kind == PARSER_JAVA_IMPLEMENTATION_METHOD)
                 || ($kind == PARSER_JAVA_DECLARATION_VARIABLE_AVEC_INIT_CLASS_ANONYM))
            {
                my $line_number = 0; # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                assert(exists $hash_item{'item'}); # traces_filter_line
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
                print STDERR "$item\n" if ($debug); # traces_filter_line
            
                assert(exists $hash_item{'scope_namespace'}); # traces_filter_line
                my $scope_namespace = $hash_item{'scope_namespace'};
                assert(exists $hash_item{'scope_class'}); # traces_filter_line
                my $scope_class = $hash_item{'scope_class'};
                if ($kind == PARSER_JAVA_DECLARATION_METHOD_VIRTUEL_PURE)
                {
                    push(@arr_class_scope_kind, [$scope_class,"ME"]);
                    print STDERR "$scope_class,ME\n" if ($debug); # traces_filter_line
                }
                elsif ($kind == PARSER_JAVA_IMPLEMENTATION_METHOD)
                {
                    assert(exists $hash_item{'b_Ctor'}); # traces_filter_line
                    my $b_ctor = $hash_item{'b_Ctor'};
                    if ($b_ctor)
                    {
                        push(@arr_class_scope_kind, [$scope_class,"CT"]);
                        print STDERR "$scope_class,CT\n" if ($debug); # traces_filter_line
                    }
                    else
                    {
                        push(@arr_class_scope_kind, [$scope_class,"ME"]);
                        print STDERR "$scope_class,ME\n" if ($debug) # traces_filter_line
                    }
                }
                elsif (($kind == PARSER_JAVA_DECLARATION_VARIABLE)
                       || ($kind == PARSER_JAVA_DECLARATION_VARIABLE_AVEC_INIT_CLASS_ANONYM))
                {
                    if ($item =~ /\bstatic\b/)
                    {
                        push(@arr_class_scope_kind, [$scope_class,"VS"]);
                        print STDERR "$scope_class,VS\n" if ($debug); # traces_filter_line
                    }
                    else
                    {
                        push(@arr_class_scope_kind, [$scope_class,"VI"]);
                        print STDERR "$scope_class,VI\n" if ($debug); # traces_filter_line
                    }
                }
            }
        }
        foreach my $item (@arr_class_scope_kind)
        {
            $trace_detect_bad_declaration_order .= $item->[0] . ',' . $item->[1] . "\n" if ($b_TraceDetect); # traces_filter_line
        }
        ($nb_bad_declaration_order, my $trace) = CountBadDeclarationOrder(@arr_class_scope_kind);
        $trace_detect_bad_declaration_order .= $trace if ($b_TraceDetect); # traces_filter_line
    }
    else
    {   # force la valeur erreur
        $nb_bad_declaration_order = Erreurs::COMPTEUR_ERREUR_VALUE;
    }

    print STDERR "$mnemo_bad_declaration_order = $nb_bad_declaration_order\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_bad_declaration_order, $trace_detect_bad_declaration_order, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_bad_declaration_order , $nb_bad_declaration_order);

    return $status;
}

sub CountBadDeclarationOrder(@)
{
    my (@arr_class_scope_kind) = @_;
    my $nb_bad_declaration_order = 0;
    my $trace_detect_bad_declaration_order = "#bad declaration order :\n";
    my %dejavue = ();
    foreach my $class_scope (@arr_class_scope_kind)
    {
        my $class_scope_key = $class_scope->[0];
        $dejavue{$class_scope_key}++;
    }
    my @class_unique = sort(keys %dejavue);
    foreach my $class_scope_key (@class_unique)
    {
        my @arr_sequence_kind;
        foreach my $item (@arr_class_scope_kind)
        {
            if ($class_scope_key eq $item->[0])
            {   # seulement ceux qui sont dans la meme classe
                push(@arr_sequence_kind, $item->[1]);
            }
        }
        my $sequence_kind = join(' ', @arr_sequence_kind);
        if (!($sequence_kind =~ /^(VS\s?)*(VI\s?)*(CT\s?)*(ME\s?)*$/))
        {
            $nb_bad_declaration_order++;
            $trace_detect_bad_declaration_order .= "$class_scope_key\n";
        }
    }
    return ($nb_bad_declaration_order, $trace_detect_bad_declaration_order);
}

#-------------------------------------------------------------------------------
# 1) nommage des classe
# 2) longueur min des noms de classes
#-------------------------------------------------------------------------------
use constant LIMIT_SHORT_CLASS_NAMES_LT => 10;
use constant LIMIT_SHORT_CLASS_NAMES_HT => 15;
sub Count_ClassNaming($$$$@)
{
    my ($fichier, $couples, $options, $error, @arr_parse_items) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $status = 0;
    my $debug = 0; # traces_filter_line
    # nommage des classes
    my $nb_short_class_names_lt = 0;
    my $mnemo_short_class_names_lt = Ident::Alias_ShortClassNamesLT(); # pour stat uniquement
    my $nb_short_class_names_ht = 0;
    my $trace_detect_short_class_names_LT = '' if ($b_TraceDetect); # traces_filter_line
    my $mnemo_short_class_names_ht = Ident::Alias_ShortClassNamesHT();
    my $trace_detect_short_class_names_HT = '' if ($b_TraceDetect); # traces_filter_line
    my $nb_bad_class_names = 0;
    my $mnemo_bad_class_names = Ident::Alias_BadClassNames();
    my $pattern_bad_class_names = '^([A-Z][a-z]+)+$';
    my $trace_detect_bad_class_names = '' if ($b_TraceDetect); # traces_filter_line

    if ($error != 1)
    {
        foreach my $item (@arr_parse_items)
        {
            my $kind = $item->[0];
            my $hash_ref = $item->[1];
            my %hash_item = %$hash_ref;
            my $nb_param = 0;
            if (($kind == PARSER_JAVA_DECLARATION_CLASS) || ($kind == PARSER_JAVA_DECLARATION_CLASS_ENUMERE)
                || ($kind == PARSER_JAVA_DECLARATION_INTERFACE))
            {
                my $line_number = 0; # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                assert(exists $hash_item{'item'}); # traces_filter_line
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
                print STDERR "$item\n" if ($debug); # traces_filter_line
            
                assert(exists $hash_item{'class_name'}); # traces_filter_line
                my $match_class_name = $hash_item{'class_name'};
                my $trace_line = "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                if (length($match_class_name) < LIMIT_SHORT_CLASS_NAMES_LT)
                {
                    $nb_short_class_names_lt++;
                    $trace_detect_short_class_names_LT .= $trace_line if ($b_TraceDetect); # traces_filter_line
                    Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_short_class_names_lt, $match_class_name);
                }
                if (length($match_class_name) < LIMIT_SHORT_CLASS_NAMES_HT)
                {
                    $nb_short_class_names_ht++;
                    $trace_detect_short_class_names_HT .= $trace_line if ($b_TraceDetect); # traces_filter_line
                    Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_short_class_names_ht, $match_class_name);
                }
                Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, 'Nbr_ShortClassNames', $match_class_name);
                if (!($match_class_name =~ /$pattern_bad_class_names/))
                {
                    $nb_bad_class_names++;
                    $trace_detect_bad_class_names .= $trace_line if ($b_TraceDetect); # traces_filter_line
                    Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_bad_class_names, $match_class_name);
                }
                Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, 'Nbr_ClassNames', $match_class_name);
            }
        }
    }
    else
    {   # force la valeur erreur
        $nb_short_class_names_lt = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_short_class_names_ht = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_bad_class_names = Erreurs::COMPTEUR_ERREUR_VALUE;
    }

    print STDERR "$mnemo_short_class_names_lt = $nb_short_class_names_lt\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_short_class_names_lt, $trace_detect_short_class_names_LT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_short_class_names_lt , $nb_short_class_names_lt);

    print STDERR "$mnemo_short_class_names_ht = $nb_short_class_names_ht\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_short_class_names_ht, $trace_detect_short_class_names_HT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_short_class_names_ht , $nb_short_class_names_ht);

    print STDERR "$mnemo_bad_class_names = $nb_bad_class_names\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_bad_class_names, $trace_detect_bad_class_names, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_bad_class_names , $nb_bad_class_names);

    return $status;
}

#-------------------------------------------------------------------------------
# 1) nommage des attributs
# 2) longueur min des noms d'attributs
#    (les valeurs enumeres de java 1.5 ne sont pas prise en compte)
#-------------------------------------------------------------------------------
use constant LIMIT_SHORT_ATTRIBUTE_NAMES_LT => 6;
use constant LIMIT_SHORT_ATTRIBUTE_NAMES_HT => 10;
sub Count_AttributeNaming($$$$@)
{
    my ($fichier, $couples, $options, $error, @arr_parse_items) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $status = 0;
    my $debug = 0; # traces_filter_line
    # nommage des attributs
    my $nb_short_attribute_names_lt = 0;
    my $mnemo_short_attribute_names_lt = Ident::Alias_ShortAttributeNamesLT();
    my $nb_short_attribute_names_ht = 0;
    my $trace_detect_short_attribute_names_LT = '' if ($b_TraceDetect); # traces_filter_line
    my $mnemo_short_attribute_names_ht = Ident::Alias_ShortAttributeNamesHT();
    my $trace_detect_short_attribute_names_HT = '' if ($b_TraceDetect); # traces_filter_line
    my $nb_bad_attribute_names = 0;
    my $mnemo_bad_attribute_names = Ident::Alias_BadAttributeNames();
    my $pattern_bad_attribute_names_var = '^[a-z]+([A-Z][a-z]+)*$';
    my $pattern_bad_attribute_names_cte = '^[A-Z0-9_]*$';
    my $trace_detect_bad_attribute_names = '' if ($b_TraceDetect); # traces_filter_line

    if ($error != 1)
    {
        foreach my $item (@arr_parse_items)
        {
            my $kind = $item->[0];
            my $hash_ref = $item->[1];
            my %hash_item = %$hash_ref;
            my $nb_param = 0;
            if (($kind == PARSER_JAVA_DECLARATION_VARIABLE)
                || ($kind == PARSER_JAVA_DECLARATION_VARIABLE_AVEC_INIT_CLASS_ANONYM))
            {
                my $line_number = 0; # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                assert(exists $hash_item{'item'}); # traces_filter_line
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
                print STDERR "$item\n" if ($debug); # traces_filter_line
                assert(exists $hash_item{'var_name'}); # traces_filter_line
                assert(exists $hash_item{'var_type'}); # traces_filter_line
                my $attribute_name = $hash_item{'var_name'};
                my $type = $hash_item{'var_type'};
                if (length($attribute_name) < LIMIT_SHORT_ATTRIBUTE_NAMES_LT)
                {
                    $nb_short_attribute_names_lt++;
                    my $trace_line = "$base_filename:$line_number:$type:$attribute_name\n" if ($b_TraceDetect); # traces_filter_line
                    $trace_detect_short_attribute_names_LT .= $trace_line if ($b_TraceDetect); # traces_filter_line
                    Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_short_attribute_names_lt, $attribute_name);
                }
                if (length($attribute_name) < LIMIT_SHORT_ATTRIBUTE_NAMES_HT)
                {
                    $nb_short_attribute_names_ht++;
                    my $trace_line = "$base_filename:$line_number:$type:$attribute_name\n" if ($b_TraceDetect); # traces_filter_line
                    $trace_detect_short_attribute_names_HT .= $trace_line if ($b_TraceDetect); # traces_filter_line
                    Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_short_attribute_names_ht, $attribute_name);
                }
                Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, 'Nbr_ShortAttributeNames', $attribute_name);
                if (($type =~ /\bfinal\b/) && ($type =~ /\bstatic\b/))
                {   # pour les final static
                    if (!($attribute_name =~ /$pattern_bad_attribute_names_cte/))
                    {
                        $nb_bad_attribute_names++;
                        my $trace_line = "$base_filename:$line_number:$type:$attribute_name:\n" if ($b_TraceDetect); # traces_filter_line
                        $trace_detect_bad_attribute_names .= $trace_line if ($b_TraceDetect); # traces_filter_line
                        Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_bad_attribute_names, $attribute_name);
                    }
                }
                elsif (!($attribute_name =~ /$pattern_bad_attribute_names_var/))
                {   # pour les autres variables
                    $nb_bad_attribute_names++;
                    my $trace_line = "$base_filename:$line_number:$type:$attribute_name:\n" if ($b_TraceDetect); # traces_filter_line
                    $trace_detect_bad_attribute_names .= $trace_line if ($b_TraceDetect); # traces_filter_line
                    Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_bad_attribute_names, $attribute_name);
                }
                Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, 'Nbr_AttributeNames', $attribute_name);
            }
        }
    }
    else
    {   # force la valeur erreur
        $nb_short_attribute_names_lt = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_short_attribute_names_ht = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_bad_attribute_names = Erreurs::COMPTEUR_ERREUR_VALUE;
    }

    print STDERR "$mnemo_short_attribute_names_lt = $nb_short_attribute_names_lt\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_short_attribute_names_lt, $trace_detect_short_attribute_names_LT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_short_attribute_names_lt , $nb_short_attribute_names_lt);

    print STDERR "$mnemo_short_attribute_names_ht = $nb_short_attribute_names_ht\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_short_attribute_names_ht, $trace_detect_short_attribute_names_HT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_short_attribute_names_ht , $nb_short_attribute_names_ht);

    print STDERR "$mnemo_bad_attribute_names = $nb_bad_attribute_names\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_bad_attribute_names, $trace_detect_bad_attribute_names, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_bad_attribute_names , $nb_bad_attribute_names);

    return $status;
}

#-------------------------------------------------------------------------------
# 1) nommage des methodes
# 2) longueur min des noms de methodes
#-------------------------------------------------------------------------------
use constant LIMIT_SHORT_METHOD_NAMES_LT => 8;
use constant LIMIT_SHORT_METHOD_NAMES_HT => 10;
sub Count_MethodNaming($$$$@)
{
    my ($fichier, $couples, $options, $error, @arr_parse_items) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $status = 0;
    my $debug = 0; # traces_filter_line
    # nommage des methodes
    my $nb_short_method_names_lt = 0;
    my $mnemo_short_method_names_lt = Ident::Alias_ShortMethodNamesLT();
    my $nb_short_method_names_ht = 0;
    my $trace_detect_short_method_names_LT = '' if ($b_TraceDetect); # traces_filter_line
    my $mnemo_short_method_names_ht = Ident::Alias_ShortMethodNamesHT();
    my $trace_detect_short_method_names_HT = '' if ($b_TraceDetect); # traces_filter_line
    my $nb_bad_method_names = 0;
    my $mnemo_bad_method_names = Ident::Alias_BadMethodNames();
    my $pattern_bad_method_names = '^[a-z]+([A-Z][a-z]+)*$';
    my $trace_detect_bad_method_names = '' if ($b_TraceDetect); # traces_filter_line

    if ($error != 1)
    {
        foreach my $item (@arr_parse_items)
        {
            my $kind = $item->[0];
            my $hash_ref = $item->[1];
            my %hash_item = %$hash_ref;
            my $nb_param = 0;
            if (($kind == PARSER_JAVA_IMPLEMENTATION_METHOD) || ($kind == PARSER_JAVA_DECLARATION_METHOD_VIRTUEL_PURE))
            {
                my $line_number = 0; # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                assert(exists $hash_item{'item'}); # traces_filter_line
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
                print STDERR "$item\n" if ($debug); # traces_filter_line
            
                assert(exists $hash_item{'method_name'}); # traces_filter_line
                my $match_method_name = $hash_item{'method_name'};
                my $trace_line = "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                my $len = length($match_method_name);
                my $b_main = ($match_method_name eq 'main'); # exclure main
                if (($len < LIMIT_SHORT_METHOD_NAMES_LT) && !$b_main)
                {
                    $nb_short_method_names_lt++;
                    $trace_detect_short_method_names_LT .= $trace_line if ($b_TraceDetect); # traces_filter_line
                    Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_short_method_names_lt, $match_method_name);
                }
                if (($len < LIMIT_SHORT_METHOD_NAMES_HT)  && !$b_main)
                {
                    $nb_short_method_names_ht++;
                    $trace_detect_short_method_names_HT .= $trace_line if ($b_TraceDetect); # traces_filter_line
                    Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_short_method_names_ht, $match_method_name);
                }
                Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, 'Nbr_ShortMethodNames', $match_method_name);
                if (!($match_method_name =~ /$pattern_bad_method_names/))
                {
                    $nb_bad_method_names++;
                    $trace_detect_bad_method_names .= $trace_line if ($b_TraceDetect); # traces_filter_line
                    Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_bad_method_names, $match_method_name);
                }
                Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, 'Nbr_MethodNames', $match_method_name);
            }
        }
    }
    else
    {   # force la valeur erreur
        $nb_short_method_names_lt = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_short_method_names_ht = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_bad_method_names = Erreurs::COMPTEUR_ERREUR_VALUE;
    }

    print STDERR "$mnemo_short_method_names_lt = $nb_short_method_names_lt\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_short_method_names_lt, $trace_detect_short_method_names_LT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_short_method_names_lt , $nb_short_method_names_lt);

    print STDERR "$mnemo_short_method_names_ht = $nb_short_method_names_ht\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_short_method_names_ht, $trace_detect_short_method_names_HT, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_short_method_names_ht , $nb_short_method_names_ht);

    print STDERR "$mnemo_bad_method_names = $nb_bad_method_names\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_bad_method_names, $trace_detect_bad_method_names, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_bad_method_names , $nb_bad_method_names);

    return $status;
}

#-------------------------------------------------------------------------------
# 1) comptage du nombre de parametre total
# 2) comptage du nombre de methode avec plus de 7 paramtres
#-------------------------------------------------------------------------------
use constant SEUIL_MAX_NB_PARAM => 7;
sub Count_Parameters($$$$@)
{
    my ($fichier, $couples, $options, $error, @arr_parse_items) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $status = 0;
    my $debug = 0; # traces_filter_line
    # nombre de parametres
    my $nb_methods_with_too_much_parameters = 0;
    my $mnemo_methods_with_too_much_parameters = Ident::Alias_WithTooMuchParametersMethods();
    my $trace_detect_methods_with_too_much_parameters = '' if ($b_TraceDetect); # traces_filter_line
    # nombre total de parametres
    my $nb_total_parameters = 0;
    my $mnemo_total_parameters = Ident::Alias_TotalParameters();
    my $trace_detect_total_parameters = '' if ($b_TraceDetect); # traces_filter_line

    if ($error != 1)
    {
        foreach my $item (@arr_parse_items)
        {
            my $kind = $item->[0];
            my $hash_ref = $item->[1];
            my %hash_item = %$hash_ref;
            my $nb_param = 0;
            if (($kind == PARSER_JAVA_DECLARATION_METHOD_VIRTUEL_PURE)
                || ($kind == PARSER_JAVA_IMPLEMENTATION_METHOD))
            {
                my $line_number = 0; # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                assert(exists $hash_item{'item'}); # traces_filter_line
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
                print STDERR "$item\n" if ($debug); # traces_filter_line
                if ($item =~ /\((.*)\)/)
                {
                    my $match = $1;
                    my $match_sans_template = $match;
                    $match_sans_template =~ s/<.*>//;
                    print STDERR "$match_sans_template\n" if ($debug); # traces_filter_line
                    if ($match_sans_template =~ /^\s*$/)
                    {   # pas de parametres
                        $nb_param = 0;
                    }
                    else
                    {   # au moins un parametre
                        $nb_param = () = $match_sans_template =~ /,/g;
                        $nb_param++;
                    }
                }
                print STDERR "nb_param : $nb_param \n" if ($debug); # traces_filter_line
                if ($nb_param > SEUIL_MAX_NB_PARAM)
                {
                    $nb_methods_with_too_much_parameters++;
                    $trace_detect_methods_with_too_much_parameters .= "$base_filename:$line_number:$item:$nb_param\n" if ($b_TraceDetect); # traces_filter_line
                }
                $nb_total_parameters += $nb_param;
                $trace_detect_total_parameters .= "$base_filename:$line_number:$item:$nb_param\n" if ($b_TraceDetect); # traces_filter_line
            }
        }
    }
    else
    {   # force la valeur erreur
        $nb_methods_with_too_much_parameters = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_total_parameters = Erreurs::COMPTEUR_ERREUR_VALUE;
    }

    print STDERR "$mnemo_methods_with_too_much_parameters = $nb_methods_with_too_much_parameters\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_methods_with_too_much_parameters, $trace_detect_methods_with_too_much_parameters, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_methods_with_too_much_parameters , $nb_methods_with_too_much_parameters);

    print STDERR "$mnemo_total_parameters = $nb_total_parameters\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_total_parameters, $trace_detect_total_parameters, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_total_parameters , $nb_total_parameters);

    return $status;
}

#-------------------------------------------------------------------------------
# 1) comptage du nombre de classes avec une methode overload equals
# 2) comptage du nombre de classes avec equals sans hashCode
#
# EXPLANATIONS:
# Whenever a.equals(b), then a.hashCode() must be same as b.hashCode().
# hashCode() works with equals(Object).
#
# Overloading equals(Object) with equals(xx) is confusing, then is to be avoided.
# Overriding equals(Object) need to override hashCode() too, but overloading do not.
#-------------------------------------------------------------------------------
sub Count_Equals($$$$@)
{
    my ($fichier, $couples, $options, $error, @arr_parse_items) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $status = 0;
    my $debug = 0; # traces_filter_line
    #  surcharge d'overload
    my $nb_overload_equals = 0;
    my $mnemo_overload_equals = Ident::Alias_OverloadEquals();
    my $trace_detect_overload_equals = '' if ($b_TraceDetect); # traces_filter_line
    #  hascode manquant
    my $nb_missing_hashcode = 0;
    my $mnemo_missing_hashcode = Ident::Alias_MissingHashcode();
    my $trace_detect_missing_hashcode = '' if ($b_TraceDetect); # traces_filter_line

    if ($error != 1)
    {
        my %hash_presence_equals;
        my %hash_presence_hascode;
        foreach my $item (@arr_parse_items)
        {
            my $kind = $item->[0];
            my $hash_ref = $item->[1];
            my %hash_item = %$hash_ref;
            if (($kind == PARSER_JAVA_DECLARATION_METHOD_VIRTUEL_PURE)
                || ($kind == PARSER_JAVA_IMPLEMENTATION_METHOD))
            {
                my $line_number = 0; # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                assert(exists $hash_item{'item'}); # traces_filter_line
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
                print STDERR "$item\n" if ($debug); # traces_filter_line
            
                assert(exists $hash_item{'scope_namespace'}); # traces_filter_line
                my $scope_namespace = $hash_item{'scope_namespace'};
                assert(exists $hash_item{'scope_class'}); # traces_filter_line
                my $scope_class = $hash_item{'scope_class'};
            
                if ($item =~ /\bequals\s*\(\s*(\w+)/)
                {
                    my $match_type = $1;
                    if ($match_type ne 'Object')
                    {
                        $nb_overload_equals++;
                        $trace_detect_overload_equals .= "$base_filename:$line_number:[$scope_class]:$item\n" if ($b_TraceDetect); # traces_filter_line
			#$hash_presence_equals{$scope_class} = 1;
                    }
		    else {
			# Only equals(Object) is considered... 
  		        $hash_presence_equals{$scope_class} = 1;
		    }
                }
                elsif ($item =~ /\bhashCode\s*\(\s*\)/)
                {
                    $hash_presence_hascode{$scope_class} = 1;
                }
            }
        }

        my @keys = sort(keys %hash_presence_equals);
        foreach my $scope(@keys) {
	    if (! exists $hash_presence_hascode{$scope}) {
	      $nb_missing_hashcode++;
	    }
        }
    }
    else
    {   # force la valeur erreur
        $nb_overload_equals = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_missing_hashcode = Erreurs::COMPTEUR_ERREUR_VALUE;
    }

    print STDERR "$mnemo_overload_equals = $nb_overload_equals\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_overload_equals, $trace_detect_overload_equals, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_overload_equals , $nb_overload_equals);

    print STDERR "$mnemo_missing_hashcode = $nb_missing_hashcode\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_missing_hashcode, $trace_detect_missing_hashcode, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_missing_hashcode , $nb_missing_hashcode);

    return $status;
}

#-------------------------------------------------------------------------------
# 1) comptage du nombre de classes parent
# 2) comptage du nombre d'interfaces parent
#-------------------------------------------------------------------------------
sub Count_Parents($$$$@)
{
    my ($fichier, $couples, $options, $error, @arr_parse_items) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $status = 0;
    my $debug = 0; # traces_filter_line
    #  classes parent
    my $nb_parent_classes = 0;
    my $mnemo_parent_classes = Ident::Alias_ParentClasses();
    my $trace_detect_parent_classes = '' if ($b_TraceDetect); # traces_filter_line
    #  interfaces parent manquant
    my $nb_parent_interfaces = 0;
    my $mnemo_parent_interfaces = Ident::Alias_ParentInterfaces();
    my $trace_detect_parent_interfaces = '' if ($b_TraceDetect); # traces_filter_line

    if ($error != 1)
    {
        foreach my $item (@arr_parse_items)
        {
            my $kind = $item->[0];
            my $hash_ref = $item->[1];
            my %hash_item = %$hash_ref;
            if ($kind == PARSER_JAVA_DECLARATION_CLASS)
            {
                my $line_number = 0; # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                assert(exists $hash_item{'item'}); # traces_filter_line
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
                print STDERR "$item\n" if ($debug); # traces_filter_line
                my $item_sans_template = $item;
                $item_sans_template  =~ s/<.*?>//g;
            
                if ($item_sans_template =~ /\sextends\s/)
                {
                    $nb_parent_classes++;
                    $trace_detect_parent_classes .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                }
                if ($item_sans_template =~ /\simplements\s(.*)/)
                {
                    my $match_interfaces = $1;
                    my $nb = () = $match_interfaces =~ /,/;
                    $nb++;
                    for(my $i=0; $i<$nb; $i++)
                    {
                        $nb_parent_interfaces++;
                        $trace_detect_parent_interfaces .= "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                    }
                }
            }
        }
    }
    else
    {   # force la valeur erreur
        $nb_parent_classes = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_parent_interfaces = Erreurs::COMPTEUR_ERREUR_VALUE;
    }

    print STDERR "$mnemo_parent_classes = $nb_parent_classes\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_parent_classes, $trace_detect_parent_classes, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_parent_classes , $nb_parent_classes);

    print STDERR "$mnemo_parent_interfaces = $nb_parent_interfaces\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_parent_interfaces, $trace_detect_parent_interfaces, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_parent_interfaces , $nb_parent_interfaces);

    return $status;
}

#-------------------------------------------------------------------------------
# 1) comptage le nombre d'attribut public
# 2) comptage le nombre d'attribut private
#-------------------------------------------------------------------------------
sub Count_PublicPrivateAttributes($$$$@)
{
    my ($fichier, $couples, $options, $error, @arr_parse_items) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $status = 0;
    my $debug = 0; # traces_filter_line
    #   Attributs
    my $mnemo_public_attr = Ident::Alias_PublicAttributes();
    my $nmeno_priv_prot_attr = Ident::Alias_PrivateProtectedAttributes();
    my $nb_public_attr = 0;
    my $nb_priv_prot_attr = 0;
    my $trace_detect_public_attr = ''  if ($b_TraceDetect); # traces_filter_line
    my $trace_detect_priv_prot_attr = '' if ($b_TraceDetect); # traces_filter_line

    if ($error != 1)
    {
        foreach my $item (@arr_parse_items)
        {
            my $kind = $item->[0];
            my $hash_ref = $item->[1];
            my %hash_item = %$hash_ref;
            if ($kind == PARSER_JAVA_DECLARATION_VARIABLE)
            {
                my $line_number = 0; # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                assert(exists $hash_item{'item'}); # traces_filter_line
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
                print STDERR "$item\n" if ($debug); # traces_filter_line
                assert(exists $hash_item{'var_visibility'}); # traces_filter_line
                my $visibility = $hash_item{'var_visibility'};
            
                if ($visibility eq 'private')
                {
                    $nb_priv_prot_attr++;
                    my $trace_line = "$base_filename:$line_number:$visibility:$item\n" if ($b_TraceDetect); # traces_filter_line
                    $trace_detect_priv_prot_attr .= $trace_line if ($b_TraceDetect); # traces_filter_line
                }
                elsif ($visibility eq 'protected')
                {
                    $nb_priv_prot_attr++;
                    my $trace_line = "$base_filename:$line_number:$visibility:$item\n" if ($b_TraceDetect); # traces_filter_line
                    $trace_detect_priv_prot_attr .= $trace_line if ($b_TraceDetect); # traces_filter_line
                }
                elsif ($visibility eq 'public')
                {
		    if ((!($item =~ /static/)) || (!($item =~/final/)))
		    {	# les public static final sont des constantes, donc pas comptabilise dans les variables publiques
			$nb_public_attr++;
			my $trace_line = "$base_filename:$line_number:$visibility:$item\n" if ($b_TraceDetect); # traces_filter_line
			$trace_detect_public_attr .= $trace_line if ($b_TraceDetect); # traces_filter_line
		    }
                }
                else
                {   # package
                    $nb_public_attr++;
                    my $trace_line = "$base_filename:$line_number:$visibility:$item\n" if ($b_TraceDetect); # traces_filter_line
                    $trace_detect_public_attr .= $trace_line if ($b_TraceDetect); # traces_filter_line
                }
            }
        }
    }
    else
    {   # force la valeur erreur
        $nb_public_attr = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_priv_prot_attr = Erreurs::COMPTEUR_ERREUR_VALUE;
    }

    print STDERR "$mnemo_public_attr = $nb_public_attr\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_public_attr, $trace_detect_public_attr, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_public_attr , $nb_public_attr);

    print STDERR "$nmeno_priv_prot_attr = $nb_priv_prot_attr\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $nmeno_priv_prot_attr, $trace_detect_priv_prot_attr, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $nmeno_priv_prot_attr , $nb_priv_prot_attr);

    return $status;
}

#-------------------------------------------------------------------------------
# 1) comptage le nombre de classes
# 2) comptage le nombre d'interfaces
#-------------------------------------------------------------------------------
sub Count_ClassesInterfaces($$$$@)
{
    my ($fichier, $couples, $options, $error, @arr_parse_items) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $status = 0;
    my $debug = 0; # traces_filter_line
    #   Classes et Interfaces
    my $mnemo_classes = Ident::Alias_ClassDefinitions();
    my $mnemo_interfaces = Ident::Alias_InterfaceDefinitions();
    my $nb_classes = 0;
    my $nb_interfaces = 0;
    my $trace_detect_classes_interfaces = '' if ($b_TraceDetect); # traces_filter_line

    if ($error != 1)
    {
        foreach my $item (@arr_parse_items)
        {
            my $kind = $item->[0];
            my $hash_ref = $item->[1];
            my %hash_item = %$hash_ref;
            if (($kind == PARSER_JAVA_DECLARATION_CLASS) || ($kind == PARSER_JAVA_DECLARATION_CLASS_ENUMERE))
            {   # en java un enumere est equivalent a une classe
                my $line_number = 0; # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                assert(exists $hash_item{'item'}); # traces_filter_line
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
                print STDERR "$item\n" if ($debug); # traces_filter_line
                assert(exists $hash_item{'class_name'}); # traces_filter_line
                my $class_name = $hash_item{'class_name'};
            
                $nb_classes++;
                my $trace_line = "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                $trace_detect_classes_interfaces .= $trace_line if ($b_TraceDetect); # traces_filter_line
            }
            elsif ($kind == PARSER_JAVA_DECLARATION_INTERFACE)
            {
                my $line_number = 0; # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                assert(exists $hash_item{'item'}); # traces_filter_line
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
                print STDERR "$item\n" if ($debug); # traces_filter_line
                assert(exists $hash_item{'class_name'}); # traces_filter_line
                my $class_name = $hash_item{'class_name'};
            
                $nb_interfaces++;
                my $trace_line = "$base_filename:$line_number:$item\n" if ($b_TraceDetect); # traces_filter_line
                $trace_detect_classes_interfaces .= $trace_line if ($b_TraceDetect); # traces_filter_line
            }
        }
    }
    else
    {   # force la valeur erreur
        $nb_classes = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_interfaces = Erreurs::COMPTEUR_ERREUR_VALUE;
    }

    print STDERR "$mnemo_classes = $nb_classes\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_classes, $trace_detect_classes_interfaces, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_classes , $nb_classes);

    print STDERR "$mnemo_interfaces = $nb_interfaces\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_interfaces, $trace_detect_classes_interfaces, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_interfaces , $nb_interfaces);

    return $status;
}

#-------------------------------------------------------------------------------
# 1) comptage le nombre de methodes avec implementation
# 2) comptage le nombre de methodes sans implementation
# 3) comptage le nombre d classes implementees
#-------------------------------------------------------------------------------
sub Count_Methods($$$$@)
{
    my ($fichier, $couples, $options, $error, @arr_parse_items) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect); # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    my $status = 0;
    my $debug = 0; # traces_filter_line
    #   Fonctions, Methodes
    my $mnemo_method_impl = Ident::Alias_FunctionMethodImplementations();
    my $mnemo_method_decl = Ident::Alias_FunctionMethodDeclarations();
    my $nb_method_impl = 0;
    my $nb_method_decl = 0;
    my $trace_detect_methods = '' if ($b_TraceDetect); # traces_filter_line
    #  Nombre de classes implmentees
    my $mnemo_classes_implemented = Ident::Alias_ClassImplementations();
    my $nb_classes_implemented = 0;
    my %hash_ImplMultClasses;

    if ($error != 1)
    {
        foreach my $item (@arr_parse_items)
        {
            my $kind = $item->[0];
            my $hash_ref = $item->[1];
            my %hash_item = %$hash_ref;
            if ($kind == PARSER_JAVA_IMPLEMENTATION_METHOD)
            {
                my $line_number = 0; # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                assert(exists $hash_item{'item'}); # traces_filter_line
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
                print STDERR "$item\n" if ($debug); # traces_filter_line
                assert(exists $hash_item{'scope_namespace'}); # traces_filter_line
                my $scope_namespace = $hash_item{'scope_namespace'};
                assert(exists $hash_item{'scope_class'}); # traces_filter_line
                my $scope_class = $hash_item{'scope_class'};
                assert(exists $hash_item{'tag'}); # traces_filter_line
                my $tag = $hash_item{'tag'};
            
                $nb_method_impl++;
                my $trace_line = "$base_filename:$line_number:$tag:[$scope_namespace]:" if ($b_TraceDetect); # traces_filter_line
                $trace_line .= "[$scope_class]:$item\n" if ($b_TraceDetect); # traces_filter_line
                $trace_detect_methods .= $trace_line if ($b_TraceDetect); # traces_filter_line
            
                my $full_scope = '';
                $full_scope = $scope_namespace . '::' . $scope_class;
                $hash_ImplMultClasses{$full_scope}++;
            }
            elsif ($kind == PARSER_JAVA_DECLARATION_METHOD_VIRTUEL_PURE)
            {
                my $line_number = 0; # traces_filter_line
                $line_number = $hash_item{'line_number'} if ($b_TraceDetect); # traces_filter_line
                assert(exists $hash_item{'item'}); # traces_filter_line
                my $item = $hash_item{'item'};
                print STDERR "#### line : $line_number\n" if ($debug); # traces_filter_line
                print STDERR "$item\n" if ($debug); # traces_filter_line
                assert(exists $hash_item{'scope_namespace'}); # traces_filter_line
                my $scope_namespace = $hash_item{'scope_namespace'};
                assert(exists $hash_item{'scope_class'}); # traces_filter_line
                my $scope_class = $hash_item{'scope_class'};
                assert(exists $hash_item{'tag'}); # traces_filter_line
                my $tag = $hash_item{'tag'};
            
                $nb_method_decl++;
                my $trace_line = "$base_filename:$line_number:$tag:[$scope_namespace]:" if ($b_TraceDetect); # traces_filter_line
                $trace_line .= "[$scope_class]:$item\n" if ($b_TraceDetect); # traces_filter_line
                $trace_detect_methods .= $trace_line if ($b_TraceDetect); # traces_filter_line
            }
        }
    }
    else
    {   # force la valeur erreur
        $nb_method_impl = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_method_decl = Erreurs::COMPTEUR_ERREUR_VALUE;
        $nb_classes_implemented = Erreurs::COMPTEUR_ERREUR_VALUE;
    }

    my @keys = sort(keys %hash_ImplMultClasses);
    $nb_classes_implemented = @keys;
    my $trace_classes_implemented = join("\n", @keys) if ($b_TraceDetect || $debug); # traces_filter_line

    print STDERR "$mnemo_method_impl = $nb_method_impl\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_method_impl, $trace_detect_methods, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_method_impl, $nb_method_impl);

    print STDERR "$mnemo_method_decl = $nb_method_decl\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_method_decl, $trace_detect_methods, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_method_decl, $nb_method_decl);

    print STDERR "trace_classes_implemented:$trace_classes_implemented\n" if ($debug); # traces_filter_line
    print STDERR "$mnemo_classes_implemented = $nb_classes_implemented\n" if ($debug); # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_classes_implemented, $trace_classes_implemented, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_classes_implemented, $nb_classes_implemented);

    return $status;
}

1;
