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
# Description: Composant de comptage pour le langage C
#----------------------------------------------------------------------#

package CountC;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

# prototypes publics
sub CountKeywords($$$);
sub CountUnionStruct($$$);
sub CountBugPatterns($$$);                          # bt_filter_line
sub CountRiskyFunctionCalls($$$);                   # bt_filter_line
sub CountBadPtrAccess($$$);
sub CountCPPKeyWords($$$);
sub CountMultiAssign($$$);
sub CountMacrosParamSansParenthese($$$$);
sub CountMacroNaming($$$$);                         # bt_filter_line

# prototypes prives
sub CountItem($$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des mots cles
#-------------------------------------------------------------------------------
sub CountKeywords($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    #my $code = $vue->{'code'};
    my $code = ${Vues::getView($vue, 'code')};

    $status |= CountItem('include',     Ident::Alias_Include(),  \$code, $compteurs); # bt_filter_line

    # Neutralisation des directives de compilation
    $code =~ s/(^[ \t]*#)\s*[^\n]*\n/$1\n/mg ;

    $status |= CountItem('while',       Ident::Alias_While(),    \$code, $compteurs);
    $status |= CountItem('for',         Ident::Alias_For(),      \$code, $compteurs);
    $status |= CountItem('continue',    Ident::Alias_Continue(), \$code, $compteurs);
    $status |= CountItem('switch',      Ident::Alias_Switch(),   \$code, $compteurs);
    $status |= CountItem('default',     Ident::Alias_Default(),  \$code, $compteurs);
    $status |= CountItem('case',        Ident::Alias_Case(),     \$code, $compteurs);
    $status |= CountItem('goto',        Ident::Alias_Goto(),     \$code, $compteurs);

    $status |= CountItem('exit',        Ident::Alias_Exit(),     \$code, $compteurs);

    $status |= CountItem('malloc',      Ident::Alias_Malloc(),   \$code, $compteurs);
    $status |= CountItem('calloc',      Ident::Alias_Calloc(),   \$code, $compteurs);
    $status |= CountItem('strdup',      Ident::Alias_Strdup(),   \$code, $compteurs);
    $status |= CountItem('free',        Ident::Alias_Free(),     \$code, $compteurs);
    $status |= CountItem('open',        Ident::Alias_Open(),     \$code, $compteurs);
    $status |= CountItem('close',       Ident::Alias_Close(),    \$code, $compteurs);
    $status |= CountItem('fopen',       Ident::Alias_Fopen(),    \$code, $compteurs);
    $status |= CountItem('fclose',      Ident::Alias_Fclose(),   \$code, $compteurs);

    $status |= CountItem('if',          Ident::Alias_If(),       \$code, $compteurs);
    $status |= CountItem('else',        Ident::Alias_Else(),     \$code, $compteurs);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des mots cles union et struct
#-------------------------------------------------------------------------------
sub CountUnionStruct($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    #my $code = $vue->{'code'};

    my $r_code = Vues::getView($vue, 'code');

    # if the vue is the viex 'code', then remove compilation directives.
    # So, copy the view and apply modifications ...
    if ($r_code == \$vue->{'code'}) {
      my $code = $vue->{'code'};

      # Neutralisation des directives de compilation
      $code =~ s/(^\s*#)\s*[^\n]*\n/$1\n/mg ;

      $r_code = \$code;
    }

    $status |= CountItem('union',            Ident::Alias_Union(), $r_code, $compteurs);
    $status |= CountItem('struct',           Ident::Alias_StructDefinitions(), $r_code, $compteurs);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: fonction de comptage d'item
#-------------------------------------------------------------------------------
sub CountItem($$$$)
{
    my ($item, $mnemo_Item, $code, $compteurs) = @_ ;
    my $status = 0;

    if (!defined $$code )
    {
        $status |= Couples::counter_add($compteurs, $mnemo_Item, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $nbr_Item = () = $$code =~ /\b${item}\b/sg;
    $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);

    return $status;
}

# bt_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des patterns de bugs
#-------------------------------------------------------------------------------
sub CountBugPatterns($$$)
{
    # FIXME: AD: compter comme bug pattern: '*(ptr++);' Cf. Nbr_IncrDecrOperatorComplexUses
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $nbr_BugPatterns = 0 ;
    my $mnemo_BugPatterns = Ident::Alias_BugPatterns();

#    my $code = '';
#    if ((exists $vue->{'prepro'}) && (defined $vue->{'prepro'}))
#    {
#        $code = $vue->{'prepro'};
#	Erreurs::LogInternalTraces('DEBUG', $fichier, 1, $mnemo_BugPatterns, "utilisation de la vue prepro.\n");
#    }
#    else
#    {
#        $code = $vue->{'code'};
#    }

    my $code = ${Vues::getView($vue, 'prepro', 'code')};

    if (!defined $code)
    {
        $status |= Couples::counter_add($compteurs, $mnemo_BugPatterns, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status
    }

    # Recherche des patterns d'instruction de controle suivants :
    #----------------------------------------------------------
    # while(xxx);
    # for(xxx);
    # if(xxx);

    # Suppression des imbrications de parentheses, afin de virer l'expression conditionnelle qui se trouve entre le mot cle structurel et le debut de bloc
    # qui est cense commencer par une accolade.
    # Suppression de tous les niveau imbriques de parentheses. Les contenus de parenthese analyses ne doivent pas contenir du code (presence des caracteres "{","}" ou ";" .A
    # EXEMPLE : if ( (toto <1) || (b == titi->prtfunc()))     devient     if ( _X_ || _X_ )
    #           while ( iti->prtfunc() > i++)            devient     while ( iti->prtfunc _X_ > i++)
    #           while ( i++)            devient     while ( i--)
    #           (  i++; if ( (toto <1) || (b == titi->prtfunc()))  )      devient     (  i++; if ( _X_ || _X_ ) )
    while ($code =~ s/(\([^\(\)\{\}\;]*)\([^\(\)\{\}\;]*\)/$1 _X_ /sg)
    { }

    # Comptage des instructions de controle dont la parenthese fermente est suivie d'un caractere ";"
    $nbr_BugPatterns += $code =~ s/\b(if|for|while)\s*\([^\(\)]*\)\s*;/ ;/sg;

    # Decomptage du nombre d'instructions "do", celles-ci etant systematiquement associees a un "while(xxx);" qui ne pose pas de probleme dans ce cas..
    $nbr_BugPatterns -= $code =~ s/\b(do)\b/ /sg;

    # Pour la suite, suppression des structures de controle restantes (celles qui n'ont pas un ";" derriere la parenthese fermante ...:
    $code =~ s/\b(if|for|while)\s*\([^\(\)]*\)/ ;/sg;

    #print STDERR "[BugPattern]  <cond_struct> (xxx); ==> $nbr_BugPatterns occurrences trouvees\n";
    Erreurs::LogInternalTraces('TRACE', $fichier, 1, 'BugPattern', '<cond_struct> (xxx);', "--> $nbr_BugPatterns occurrences trouvees");

    # Recherche du pattern d'instruction *a++, et plus generalement    * ...... ;, lorsqu'il n'y a pas de "=" ni d'appel de fonction dans les "..."
    #----------------------------------------------------------------------------------------------------------------------------------------------
    # Les parentheses de controle ont ete supprimees aupravant.
    # Il n'existe partout plus qu'un seul niveau de parenthses.
    # Les instructions de controle ont ete supprimees auparavant.

    $code =~ s/  +/ /sg ;       # optimisation, en cas de grand nombre d'espaces
    $code =~ s/\n( \n)+/\n/sg ; # optimisation, en cas de grand nombre d'espaces et de retours a la ligne

    $code =~ s/;/;;/sg ;
    while ($code =~ /[}\{;]\s*\*([^=;]*);/sg)
    {
        my $instr = $1;
        if ($instr !~ /(\.|->)\s*\w+\s*\([^\)]*\)/s)
        {
            # Si l'expression ne correspond pas a un appel de methode, alors c'est un bug pattern.
            $nbr_BugPatterns++;
            #print STDERR "[BugPattern]  * ... ; ==> occurrences trouvees\n";
            Erreurs::LogInternalTraces('TRACE', $fichier, 1, 'BugPattern', '* ... ;', "--> $instr");
        }
    }

    # Finir d'applatir toutes les parentheses ... sauf celles dont la fermente est suivie d'un ";", signe que les parentheses enferment une instruction.
    #  while ( $code =~ s/\([^\(\)]*\)\s*[^;\s]//sg ) {}

    # Recherche du pattern d'instruction "a = a ;"
    #-----------------------------------------------
    while ($code =~ /[}\{;\)]\s*([^;=]*=[^;]*)/sg)
    {
        my $instr = $1;
        $instr =~ s/[ \t]//g;
        my ($lvalue, $rvalue) = $instr =~ /([^=]*)=(.*)/s;
        if ($lvalue eq $rvalue)
        {
            $nbr_BugPatterns++;
            #print STDERR "[BugPattern]  a = a ; ==> occurrences trouvees\n";
            Erreurs::LogInternalTraces('TRACE', $fichier, 1, 'BugPattern', 'a = a', "--> $instr");
        }
    }

    # Recherche du pattern d'instruction "a == b ;"
    #---------------------------------------------
    # supprimer tous les patterns "= ...== ... ;" pour filtrer les affectations de resultats de tests d'egalites ....
    $code =~ s/=+[^;=]*==[^;]*;*//g;

    # supprimer tous les patterns "== ... ?" pour filtrer les tests d'egalite dans les operateurs ternaires ....
    $code =~ s/==([^\?:;]*\?)/$1/g;

    # supprimer tous les patterns "return ... ;" pour filtrer les fausses alertes "return ... == ... ;"
    $code =~ s/\n[ \t]*(return|assert)[^;]*//g;

    # CALCUL : Compter les "==".
    my $nbr = () = $code =~ /==/g;
    $nbr_BugPatterns += $nbr;

    #print STDERR "[BugPattern]  a == b ; ==> $nbr occurrences trouvees\n";
    Erreurs::LogInternalTraces('TRACE', $fichier, 1, 'BugPattern', 'a == b', "--> $nbr_BugPatterns occurrences trouvees.");

    $status |= Couples::counter_add($compteurs, $mnemo_BugPatterns, $nbr_BugPatterns);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des fonctions a risque
#-------------------------------------------------------------------------------
sub CountRiskyFunctionCalls($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $nbr_RiskyFunctionCalls = 0;
    my $mnemo_RiskyFunctionCalls = Ident::Alias_RiskyFunctionCalls();

    my $r_code = Vues::getView($vue, 'code');

    if (!defined $r_code)
    {
        $status |= Couples::counter_add($compteurs, $mnemo_RiskyFunctionCalls, Erreurs::COMPTEUR_ERREUR_VALUE );
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    $nbr_RiskyFunctionCalls = () = $$r_code =~ /\b(setjmp|signal)\b/sg;

    $status |= Couples::counter_add($compteurs, $mnemo_RiskyFunctionCalls, $nbr_RiskyFunctionCalls);

    return $status;
}

# bt_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des utilisations de la syntaxe (*ptr).field
#-------------------------------------------------------------------------------
sub CountBadPtrAccess($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $nbr_BadPtrAccess = 0;
    my $mnemo_BadPtrAccess = Ident::Alias_BadPtrAccess();

    if (!defined $vue->{'code'})
    {
        $status |= Couples::counter_add($compteurs, $mnemo_BadPtrAccess, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $code = $vue->{'code'};
    $nbr_BadPtrAccess = () = $code =~ /\(\s*\*\s*\w+\s*\)\s*\.\s*\w+/g ;

    $status |= Couples::counter_add($compteurs, $mnemo_BadPtrAccess, $nbr_BadPtrAccess);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des mots cles C++ utilises comme identifiacteur
#-------------------------------------------------------------------------------
sub CountCPPKeyWords($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $nbr_CPPKeywords = 0;
    my $mnemo_CPPKeywords = Ident::Alias_CPPKeywords();

    if (!defined $vue->{'code'})
    {
        $status |= Couples::counter_add($compteurs, $mnemo_CPPKeywords, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $code = $vue->{'code'};
    $nbr_CPPKeywords = () = $code =~ /\b(and|and_eq|bitand|bitor|bool|catch|class|compl|const_cast|delete|dynamic_cast|explicit|false|friend|inline|mutable|namespace|new|not|not_eq|operator|or|or_eq|private|protected|public|reinterpret_cast|static_cast|template|this|throw|true|try|typeid|typename|using|virtual|xor|xor_eq)\b/g;

    $status |= Couples::counter_add($compteurs, $mnemo_CPPKeywords, $nbr_CPPKeywords);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Description: Module de comptage des affectations multiples a = b = c;
#-------------------------------------------------------------------------------
sub CountMultipleAssignments($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $nbr_MultipleAssignments = 0;
    my $mnemo_MultipleAssignments = Ident::Alias_MultipleAssignments();

    if (!defined $vue->{'code'})
    {
        $status |= Couples::counter_add($compteurs, $mnemo_MultipleAssignments, Erreurs::COMPTEUR_ERREUR_VALUE );
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $code = $vue->{'code'};
    # suppression des = perturbateurs
    $code =~ s/(=|\!|<|>|\+|-|\~|\|\*|%|&|^)=//g;

    # Restriction, les expressions du type (*p1) = (*p2) = 2; ne seront pas comptees
    # les () sont utilisees abusivement ici comme separateur d'expression.
    # Sinon on compterai les cas du type if (a = f(b)) b = c;
    $nbr_MultipleAssignments = () = $code =~ /[^;:\?\{\),]+=[^;:\?\{\),]+=/g;

    $status |= Couples::counter_add($compteurs, $mnemo_MultipleAssignments, $nbr_MultipleAssignments);
    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage du nombre de macros avec au moins un parametre sans parenthese
#-------------------------------------------------------------------------------
sub CountMacrosParamSansParenthese($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0);  # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);          # traces_filter_line
    my $trace_detect_UnparenthesedParamMacros = '' if ($b_TraceDetect); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                   # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                     # traces_filter_line
    my $debug = 0;                                                      # traces_filter_line

    my $status = 0;

    my $nbr_UnparenthesedParamMacros = 0;
    my $mnemo_UnparenthesedParamMacros = Ident::Alias_UnparenthesedParamMacros();
    my $code = $vue->{'prepro_directives'};

    if (!defined $code)
    {
	assert(defined $code) if ($b_assert); # traces_filter_line
	$status |= Couples::counter_add($compteurs, $mnemo_UnparenthesedParamMacros , Erreurs::COMPTEUR_ERREUR_VALUE);
#	$status |= Couples::counter_add($compteurs, Ident::Alias_UnparenthesedParamMacros(), Erreurs::COMPTEUR_ERREUR_VALUE); # compatibilite pour module calcul # bt_filter_line   # Obsolete
	$status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	return $status;
    }

    while ($code =~    m{
			    (
			        ^[ \t]*\#\s*define\s+(\w+)
			        \((.*?)\)                    # param list
			        (.*[^\\\n](\\\n.*[^\\\n])*)  # body
			    )
			}gmx)
    {
        my $full_macro = $1;
        my $macro_name = $2;
        my $param_list = $3;
        my $macro_body = $4;

        my $nbr_params = 0;

        print STDERR "====================\n" if ($debug);    # traces_filter_line
        print STDERR "macro_name1:$macro_name\n" if ($debug); # traces_filter_line
        print STDERR "param_list1:$param_list\n" if ($debug); # traces_filter_line
        print STDERR "macro_body1:$macro_body\n" if ($debug); # traces_filter_line

        my $pos = pos($code);
        my $beginIndex = $pos - length($macro_body) +1;
        my $line_number_macro = TraceDetect::CalcLineMatch($code, $beginIndex) if ($b_TraceDetect); # traces_filter_line

        # Identify parameters
        $param_list =~ s{\s+}{}g;
        print STDERR "param_list2:$param_list\n" if ($debug); # traces_filter_line

        my (%params) = map { ($_, 1); } split(',', $param_list);
        # supprime les identifiers entoures de parentheses
        $macro_body =~ 	s {
                            (
                             \((\s*)\w+(\s*)\)
                            )
                          }
                          {
                                my $match = $1;
                                my $nb = length($match);
                                " " x $nb;
                          }gxse;
        print STDERR "macro_body2:$macro_body\n" if ($debug); # traces_filter_line
        # itere sur les occurrences des identificateurs ds body
        # (sauf ident associes a # et ##)
        while ($macro_body =~ m{
                                    \#\s*(\w+) |
                                    (\w+)\s*(\#) |
                                    (\w+)
                                }gx)
        {
            my $match_name_op1 = $1;
            my $match_name_op2 = $2;
            my $match_diese = $3;
            my $match_name = $4;
            my $pos_macro_body = pos($macro_body);
            print STDERR "\nMATCH\n" if ($debug); # traces_filter_line
            if (defined $match_name_op1)
            {   # il s'agit de l'operateur chaine
                #   #nom : ignore
                # ou de l'operateur de concatenation partie droite comme :
                #   nom1##nom2 : pour match #nom2 : ignore
                print STDERR "match_name_op1:$match_name_op1\n" if ($debug); # traces_filter_line	
                next;
            }
            elsif (defined $match_diese)
            {   # il s'agit l'operateur de concatenation partie gauche comme :
                #   nom1##nom2 : pour match nom1#  : ignore
                print STDERR "match_name_op2:$match_name_op2\n" if ($debug); # traces_filter_line
                print STDERR "match_diese:$match_diese\n" if ($debug);       # traces_filter_line
                next;
            }
            elsif (defined($match_name))
            {
                print STDERR "match_name:$match_name\n" if ($debug); # traces_filter_line
                if (exists $params{$match_name})
                {   # c'est un parametre sans parenthese : compte
                    print STDERR "COMPTAGE\n" if ($debug); # traces_filter_line
                    $nbr_params++;
                    my $line_number = TraceDetect::CalcLineMatch($code, $beginIndex+$pos_macro_body) if ($b_TraceDetect); # traces_filter_line
                    my $trace_line = "$base_filename:$line_number:$macro_name:$match_name\n" if ($b_TraceDetect);      # traces_filter_line
                    $trace_detect_UnparenthesedParamMacros .= $trace_line if ($b_TraceDetect);                         # traces_filter_line
                }
            }
        }
        if ($nbr_params > 0)
        {
            $nbr_UnparenthesedParamMacros++;
            my $trace_line = "$base_filename:$line_number_macro:$macro_name:=>comptage\n" if ($b_TraceDetect); # traces_filter_line
            $trace_detect_UnparenthesedParamMacros .= $trace_line if ($b_TraceDetect);                         # traces_filter_line
        }
    }
    print STDERR "$mnemo_UnparenthesedParamMacros = $nbr_UnparenthesedParamMacros\n" if ($debug);                                      # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_UnparenthesedParamMacros, $trace_detect_UnparenthesedParamMacros, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_UnparenthesedParamMacros, $nbr_UnparenthesedParamMacros);
#    $status |= Couples::counter_add($compteurs, Ident::Alias_UnparenthesedParamMacros(), $nbr_UnparenthesedParamMacros); # compatibilite pour module calcul # bt_filter_line # Obsolete

    return $status;
}

# bt_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage du nombre de macros avec un nom qui n'est pas en majuscules
#-------------------------------------------------------------------------------
sub CountMacroNaming($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $trace_detect = '' if ($b_TraceDetect);                         # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;

    my $nbr_BadMacroNames = 0;
    my $mnemo_BadMacroNames = Ident::Alias_BadMacroNames();

    my $code = $vue->{'prepro_directives'};
    if (!defined $code)
    {
	assert(defined $code) if ($b_assert); # traces_filter_line
	$status |= Couples::counter_add($compteurs, $mnemo_BadMacroNames , Erreurs::COMPTEUR_ERREUR_VALUE);
	$status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	return $status;
    }

    while ($code =~    m{
			    (
			        ^[ \t]*\#\s*define\s+(\w+)
			    )
			}gmx)
    {
        my $full_macro = $1;
        my $macro_name = $2;

        my $pos = pos($code)-1;
        print STDERR "====================\n" if ($debug);    # traces_filter_line
        print STDERR "macro_name1:$macro_name\n" if ($debug); # traces_filter_line
        if (!($macro_name =~ /^[A-Z0-9_]+$/))
        {
            $nbr_BadMacroNames++;
            my $line_number = TraceDetect::CalcLineMatch($code, $pos) if ($b_TraceDetect);       # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$macro_name\n" if ($b_TraceDetect); # traces_filter_line
            $trace_detect .= $trace_line if ($b_TraceDetect);                                 # traces_filter_line
        }
    }
    print STDERR "$mnemo_BadMacroNames = $nbr_BadMacroNames\n" if ($debug);                                 # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_BadMacroNames, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_BadMacroNames, $nbr_BadMacroNames);

    return $status;
}

# bt_filter_end

sub CountVG($$$$)
{
    my $status;
    my $nb_VG = 0;
    my $VG__mnemo = Ident::Alias_VG();
    my ($fichier, $vue, $compteurs, $options) = @_;

    if (  ( ! defined $compteurs->{Ident::Alias_If()}) ||
	  ( ! defined $compteurs->{Ident::Alias_Case()}) || 
	  ( ! defined $compteurs->{Ident::Alias_Default()}) || 
	  ( ! defined $compteurs->{Ident::Alias_For()}) || 
	  ( ! defined $compteurs->{Ident::Alias_While()}) || 
	  ( ! defined $compteurs->{Ident::Alias_FunctionMethodImplementations()}) )
    {
      $nb_VG = Erreurs::COMPTEUR_ERREUR_VALUE;
    }
    else {
      $nb_VG = $compteurs->{Ident::Alias_If()} +
	       $compteurs->{Ident::Alias_Case()} +
	       $compteurs->{Ident::Alias_Default()} +
	       $compteurs->{Ident::Alias_For()} +
	       $compteurs->{Ident::Alias_While()} +
	       $compteurs->{Ident::Alias_FunctionMethodImplementations()};
    }

    $status |= Couples::counter_add($compteurs, $VG__mnemo, $nb_VG);
}




1;
