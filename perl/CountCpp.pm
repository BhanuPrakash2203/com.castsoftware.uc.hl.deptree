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
# DESCRIPTION: Composant de mesure de source c++, pour creation d'alertes
#----------------------------------------------------------------------#

package CountCpp;

# les modules importes
use strict;
use warnings;
use Erreurs;
use Carp::Assert; # traces_filter_line
use Couples;
use TraceDetect;

# prototypes publics
sub CountKeywords($$$);
sub CountBugPatterns($$$);
sub CountRiskyFunctionCalls($$$);
sub CountConstantMacroDefinitions($$$$);
sub CountAnonymousNamespaces($$$);
sub CountStdioFunctionCalls($$$$);
sub CountWithoutSizeCins($$$$);
sub CountCCastUses($$$$);
sub CountWithoutFormatSizeScanfs($$$);

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

    $status |= CountItem('include',          Ident::Alias_Include(),          \$vue->{'prepro_directives'}, $compteurs); # bt_filter_line

    # Neutralisation des directives de compilation
    $code =~ s/(^[ \t]*#)\s*[^\n]*\n/$1\n/mg ;

    $status |= CountItem('while',            Ident::Alias_While(),             \$code, $compteurs);
    $status |= CountItem('for',              Ident::Alias_For(),               \$code, $compteurs);
    $status |= CountItem('continue',         Ident::Alias_Continue(),          \$code, $compteurs);
    $status |= CountItem('switch',           Ident::Alias_Switch(),            \$code, $compteurs);
    $status |= CountItem('case',             Ident::Alias_Case(),              \$code, $compteurs);
    $status |= CountItem('default',          Ident::Alias_Default(),           \$code, $compteurs);
    $status |= CountItem('goto',             Ident::Alias_Goto(),              \$code, $compteurs);
    $status |= CountItem('try',              Ident::Alias_Try(),               \$code, $compteurs);
    $status |= CountItem('catch',            Ident::Alias_Catch(),             \$code, $compteurs);
    $status |= CountItem('new',              Ident::Alias_New(),               \$code, $compteurs);
    $status |= CountItem('delete',           Ident::Alias_Delete(),            \$code, $compteurs);
    $status |= CountItem('reinterpret_cast', Ident::Alias_ReinterpretCasts(),  \$code, $compteurs);

    $status |= CountItem('union',            Ident::Alias_Union(),             \$code, $compteurs);

    $status |= CountItem('exit',             Ident::Alias_Exit(),              \$code, $compteurs);

    $status |= CountItem('malloc',           Ident::Alias_Malloc(),            \$code, $compteurs);
    $status |= CountItem('calloc',           Ident::Alias_Calloc(),            \$code, $compteurs);
    $status |= CountItem('realloc',          Ident::Alias_Realloc(),           \$code, $compteurs);
    $status |= CountItem('strdup',           Ident::Alias_Strdup(),            \$code, $compteurs);
    $status |= CountItem('free',             Ident::Alias_Free(),              \$code, $compteurs);

    $status |= CountItem('if',               Ident::Alias_If(),                \$code, $compteurs);
    $status |= CountItem('else',             Ident::Alias_Else(),              \$code, $compteurs);
    $status |= CountItem('using namespace',  Ident::Alias_Using(),             \$code, $compteurs);
    $status |= CountItem('return',           Ident::Alias_Return(),            \$code, $compteurs);


    return $status;
}

sub CountKeywordsHpp($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    #my $code = $vue->{'code'};
    my $code = ${Vues::getView($vue, 'code')};
    
    # Neutralisation des directives de compilation
    $code =~ s/(^[ \t]*#)\s*[^\n]*\n/$1\n/mg ;

    $status |= CountItem('struct',            Ident::Alias_StructDefinitions(),             \$code, $compteurs);

    return $status;
}

sub CountRiskyKeywords($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $code = ${Vues::getView($vue, 'code')};

    # Neutralisation des directives de compilation
    $code =~ s/(^[ \t]*#)\s*[^\n]*\n/$1\n/mg ;
    $status |= CountItem('gets',             Ident::Alias_Gets(),                      \$code, $compteurs);
    $status |= CountItem('strtrns',             Ident::Alias_Strtrns(),                      \$code, $compteurs);
    $status |= CountItem('strlen',             Ident::Alias_Strlen(),                      \$code, $compteurs);
    $status |= CountItem('strecpy',             Ident::Alias_Strecpy(),                      \$code, $compteurs);
    $status |= CountItem('streadd',             Ident::Alias_Streadd(),                      \$code, $compteurs);
    $status |= CountItem('snprintf',            Ident::Alias_Snprintf(),                      \$code, $compteurs);
    $status |= CountItem('realpath',            Ident::Alias_Realpath(),                      \$code, $compteurs);
    $status |= CountItem('getpass',            Ident::Alias_Getpass(),                      \$code, $compteurs);
    $status |= CountItem('getopt',            Ident::Alias_Getopt(),                      \$code, $compteurs);
    $status |= CountItem('delete\s+this',     Ident::Alias_DeleteThis(),                      \$code, $compteurs);
    $status |= CountItem('std::find_first_of',             Ident::Alias_find_first_of(),                      \$code, $compteurs);
    $status |= CountItem2('\bnew\s+\w+\[',             Ident::Alias_NewArray(),                      \$code, $compteurs);

   return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: fonction de comptage d'item
#-------------------------------------------------------------------------------
sub CountItem($$$$)
{
    my ($item, $mnemo_Item, $code, $compteurs) = @_ ;
    my $status = 0;

    if (not defined $$code)
    {
        $status |= Couples::counter_add($compteurs, $mnemo_Item, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my $nbr_Item = () = $$code =~ /\b${item}\b/sg ;
    $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: fonction de comptage d'item, non encadre par des \b
#-------------------------------------------------------------------------------
sub CountItem2($$$$)
{
    my ($item, $mnemo_Item, $code, $compteurs) = @_ ;
    my $status = 0;

    if (not defined $$code)
    {
        $status |= Couples::counter_add($compteurs, $mnemo_Item, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my $nbr_Item = () = $$code =~ /${item}/sg ;
    $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);

    return $status;
}

# bt_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage du nombre de bug patterns
#-------------------------------------------------------------------------------
sub CountBugPatterns($$$)
{
    # FIXME: AD: compter comme bug pattern: '*(ptr++);' Cf. Nbr_IncrDecrOperatorComplexUses
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $bugTiming = new Timing ('Bug', Timing->isSelectedTiming ('Count') );    # timing_filter_line
    $bugTiming->markTimeAndPrint ('start');                                     # timing_filter_line

    my $nbr_BugPatterns = 0;
    my $mnemo_BugPatterns = Ident::Alias_BugPatterns();

#    my $code;
#    if ( (exists $vue->{'prepro'}) && ( defined $vue->{'prepro'} ) )
#    {
#        $code = $vue->{'prepro'};
#        Erreurs::LogInternalTraces('DEBUG', $fichier, 1, $mnemo_BugPatterns, "utilisation de la vue prepro.\n");
#    }
#    else
#    {
#        $code = $vue->{'code'};
#    }

    my $code = ${Vues::getView($vue, 'prepro', 'code')};

    if (not defined $code)
    {
        $status |= Couples::counter_add($compteurs, $mnemo_BugPatterns, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
    $bugTiming->markTimeAndPrint ('check vues');                                # timing_filter_line

    # Recherche des patterns d'instruction de controle suivants :
    #----------------------------------------------------------
    # while(xxx);
    # for(xxx);
    # if(xxx);

    # Suppression des imbrications de parentheses, afin de virer l'expression conditionnelle qui se trouve entre le mot cle structurel et le debut de bloc
    # qui est cense commencer par une accolade.
    while ( $code =~ s/(\([^\(\)\{\}\;]*)\([^\(\)\{\}\;]*\)/$1 _X_ /sg ) { }

    $bugTiming->markTimeAndPrint ('Suppression des imbrications de parentheses') ; # timing_filter_line

    # Comptage des instructions de controle dont la parenthese fermente est suivie d'un caractere ';'
    $nbr_BugPatterns += $code =~ s/\b(if|for|while)\s*\([^\(\)]*\)\s*;/ ;/sg ;

    # Decomptage du nombre d'instructions 'do', celles-ci etant systematiquement associees a un 'while(xxx);' qui ne pose pas de probleme dans ce cas..
    $nbr_BugPatterns -= $code =~ s/\b(do)\b/ /sg ;

    # Pour la suite, suppression des structures de controle restantes (celles qui n'ont pas un ';' derriere la parenthese fermante ...:
    $code =~ s/\b(if|for|while)\s*\([^\(\)]*\)/ ;/sg ;

    $bugTiming->markTimeAndPrint ('Suppression des structures de controle') ; # timing_filter_line

    #print STDERR "[BugPattern]  <cond_struct> (xxx); ==> $nbr_BugPatterns occurrences trouvees\n";
    Erreurs::LogInternalTraces('TRACE', $fichier, 1, 'BugPattern', '<cond_struct> (xxx);', "--> $nbr_BugPatterns occurrences trouvees");

    # Recherche du pattern d'instruction *a++, et plus generalement    * ...... ;, lorsqu'il n'y a pas de '=' ni d'appel de fonction dans les '...'
    #----------------------------------------------------------------------------------------------------------------------------------------------
    # Les parentheses de controle ont ete supprimees aupravant.
    # Il n'existe partout plus qu'un seul niveau de parenthses.
    # Les instructions de controle ont ete supprimees auparavant.

    $code =~ s/  +/ /sg ;       # optimisation, en cas de grand nombre d'espaces
    $bugTiming->markTimeAndPrint ('optimisation espaces') ; # timing_filter_line
    $code =~ s/\n( \n)+/\n/sg ; # optimisation, en cas de grand nombre d'espaces et de retours a la ligne
    $bugTiming->markTimeAndPrint ('optimisation newlines') ; # timing_filter_line

    $code =~ s/;/;;/sg ;
    while ( $code =~ /[}\{;]\s*\*([^=;]*);/sg )
    {
        my $instr = $1;
        if ( $instr !~ /(\.|->)\s*\w+\s*\([^\)]*\)/s )
        {
            # Si l'expression ne correspond pas a un appel de methode, alors c'est un bug pattern.
            $nbr_BugPatterns++;
            #print STDERR "[BugPattern]  * ... ; ==> occurrences trouvees\n";
            Erreurs::LogInternalTraces('TRACE', $fichier, 1, 'BugPattern', '* ... ;', "--> $instr");
        }
    }
    $bugTiming->markTimeAndPrint (' pattern d\'instruction *a++') ; # timing_filter_line

    # Finir d'applatir toutes les parentheses ... sauf celles dont la fermente est suivie d'un ';', signe que les parentheses enferment une instruction.
    #  while ( $code =~ s/\([^\(\)]*\)\s*[^;\s]//sg ) {}

    # Recherche du pattern d'instruction 'a = a ;'
    #-----------------------------------------------
    while ( $code =~ /[}\{;\)]\s*([^;=]*=[^;]*)/sg )
    {
        my $instr = $1;
        $instr =~ s/[ \t]//g ;
        my ($lvalue, $rvalue) = $instr =~ /([^=]*)=(.*)/s ;
        if ($lvalue eq $rvalue)
        {
            $nbr_BugPatterns++;
            #print STDERR "[BugPattern]  a = a ; ==> occurrences trouvees\n";
            Erreurs::LogInternalTraces('TRACE', $fichier, 1, 'BugPattern', 'a = a', "--> $instr");
        }
    }
    $bugTiming->markTimeAndPrint (' pattern d\'instruction a = a ;') ; # timing_filter_line

    # Recherche du pattern d'instruction 'a == b ;'
    #---------------------------------------------
    # supprimer tous les patterns '= ...== ... ;' pour filtrer les affectations de resultats de tests d'egalites ....
    $code =~ s/=+[^;=]*==[^;]*;*//g;

    # supprimer tous les patterns '== ... ?' pour filtrer les tests d'egalite dans les operateurs ternaires ....
    $code =~ s/==([^\?:;]*\?)/$1/g;

    # supprimer tous les patterns 'return ... ;' pour filtrer les fausses alertes 'return ... == ... ;'
    $code =~ s/\n[ \t]*(return|assert)[^;]*//g;

    $bugTiming->markTimeAndPrint ('supprimer ... ') ; # timing_filter_line

    # CALCUL : Compter les '=='.
    my $nb = () = $code =~ /==/g ;
    $nbr_BugPatterns += $nb;

    #print STDERR "[BugPattern]  a == b ; ==> $nbr occurrences trouvees\n";
    Erreurs::LogInternalTraces('TRACE', $fichier, 1, 'BugPattern', 'a == b', "--> $nbr_BugPatterns occurrences trouvees.");

    $status |= Couples::counter_add($compteurs, $mnemo_BugPatterns, $nbr_BugPatterns);
    $bugTiming->markTimeAndPrint ('fin') ; # timing_filter_line
    $bugTiming->dump ('BugPattren') ; # timing_filter_line

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage du nombre d'instructions risquees
#-------------------------------------------------------------------------------
sub CountRiskyFunctionCalls($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $mnemo_RiskyFunctionCalls = Ident::Alias_RiskyFunctionCalls();
    my $nbr_RiskyFunctionCalls = 0;

    my $r_code = Vues::getView($vue, 'code');

    if (not defined $r_code)
    {
        $status |= Couples::counter_add($compteurs, $mnemo_RiskyFunctionCalls, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    $nbr_RiskyFunctionCalls = () = $$r_code =~ /\b(setjmp|signal)\b/sg;
    $status |= Couples::counter_add($compteurs, $mnemo_RiskyFunctionCalls, $nbr_RiskyFunctionCalls);

    return $status;
}

# bt_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION:
# module de comptage du nombre de definitions de macro           # bt_filter_line
# module de comptage du nombre de definitions de macro utilisees comme constantes
#-------------------------------------------------------------------------------
sub CountConstantMacroDefinitions($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;

    my $nbr_MacroDefinitions = 0;                                                               # bt_filter_line
    my $mnemo_MacroDefinitions = Ident::Alias_MacroDefinitions();                                        # bt_filter_line
    my $trace_detect = '';                                             # traces_filter_line     # bt_filter_line

    my $nbr_ConstantMacroDefinitions = 0;
    my $mnemo_ConstantMacroDefinitions = Ident::Alias_ConstantMacroDefinitions();
    my $trace_detect_ConstantMacroDefinitions = '';                    # traces_filter_line

    my $code = $vue->{'prepro_directives'};

    if (not defined $code)
    {
        assert(defined $code) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add($couples, $mnemo_MacroDefinitions, Erreurs::COMPTEUR_ERREUR_VALUE); # bt_filter_line
        $status |= Couples::counter_add($couples, $mnemo_ConstantMacroDefinitions, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    # ne compte pas la protection de fichier .h comme :
    # #ifndef 	FICHIER_H
    # #define FICHIER_H
    while ($code =~    m{
                            (
                                ^[ \t]*\#\s*define\s+(\w+)(.*)$
                            )
                        }gmx)
    {
        my $full_macro = $1;
        my $macro_name = $2;
        my $macro_val = $3;
        print STDERR "====================\n" if ($debug);                         # traces_filter_line
        print STDERR "full_macro:$full_macro\n" if ($debug);                       # traces_filter_line
        print STDERR "==\n" if ($debug);                                           # traces_filter_line
        print STDERR "macro_name1:$macro_name:\n" if ($debug);                     # traces_filter_line
        print STDERR "macro_val:$macro_val:\n" if ($debug && defined($macro_val)); # traces_filter_line
        if ((defined $macro_val) && ($macro_val =~ /[^\s]/))
        {
            my $pos = pos($code) if ($b_TraceDetect);                                         # traces_filter_line
            $nbr_MacroDefinitions++;                                                                                  # bt_filter_line
            my $line_number = TraceDetect::CalcLineMatch($code, $pos) if ($b_TraceDetect);       # traces_filter_line
            my $trace_line = "$base_filename:$line_number:$macro_name\n" if ($b_TraceDetect); # traces_filter_line
            $trace_detect .= $trace_line if ($b_TraceDetect);                                 # traces_filter_line    # bt_filter_line
            # comptages des macros utilisees comme constantes
            # sont consideres comme constantes des macros sans parametre, commencant comme un nombre (123, .25, \123), un caractere ('...) ou une chaine ('...)
            if ((not ($macro_val =~ /^\(/)) && (($macro_val =~ /^\s*[\.\\]?[0-9]/) || ($macro_val =~ /^\s*['"]/)))
            {
                $nbr_ConstantMacroDefinitions++;
                $trace_detect_ConstantMacroDefinitions .= $trace_line if ($b_TraceDetect); # traces_filter_line
            }
        }
    }
    print STDERR "$mnemo_MacroDefinitions = $nbr_MacroDefinitions\n" if ($debug);                              # traces_filter_line    # bt_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_MacroDefinitions, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line    # bt_filter_line
    $status |= Couples::counter_add($couples, $mnemo_MacroDefinitions, $nbr_MacroDefinitions);                                         # bt_filter_line

    print STDERR "$mnemo_ConstantMacroDefinitions = $nbr_ConstantMacroDefinitions\n" if ($debug);                                               # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_ConstantMacroDefinitions, $trace_detect_ConstantMacroDefinitions, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_ConstantMacroDefinitions, $nbr_ConstantMacroDefinitions);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des namespaces anonymes.
#-------------------------------------------------------------------------------
sub CountAnonymousNamespaces($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $mnemo_AnonymousNamespaces = Ident::Alias_AnonymousNamespaces();
    my $nbr_AnonymousNamespaces = 0;

    if (not defined $vue->{'code'})
    {
        $status |= Couples::counter_add($compteurs, $mnemo_AnonymousNamespaces, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    $nbr_AnonymousNamespaces = () = $vue->{'code'} =~ /\b(namespace)\s*\{/sg ;

    $status |= Couples::counter_add($compteurs, $mnemo_AnonymousNamespaces, $nbr_AnonymousNamespaces);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des appels des fonctions contenues dans stdio
#-------------------------------------------------------------------------------
my @stdioFunctions = qw /clearerr dprintf fclose fcloseall fdopen feof ferror fflush fgetc fgetpos fgets fileno fopen fprintf fputc fputs fread freopen fscanf fseek fsetpos ftell fwrite getc getc_unlocked getchar getdelim getline gets getw iprintf iscanf mktemp perror printf putc putc_unlocked putchar putchar_unlocked puts putw remove rename rewind scanf setbuf setbuffer setlinebuff setvbuf sprintf sscanf tmpfile tmpnam ungetc vfprintf vfscanf vprintf vscanf vsprintf vsscanf/;
sub CountStdioFunctionCalls($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $trace_detect = '' if ($b_TraceDetect);                         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;

    my $nbr_StdioFunctionCalls = 0;
    my $mnemo_StdioFunctionCalls = Ident::Alias_StdioFunctionCalls();

    if (not defined $vue->{'code'})
    {
        assert(defined $vue->{'code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add($couples, $mnemo_StdioFunctionCalls, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $code = $vue->{'code'};
    my $nb = @stdioFunctions;

    #for (my $i = 0; $i < $nb; $i++)
    {
        #my $pattern = "\\b$stdioFunctions[$i]\\s*\\(";

        my $pattern = "\\b" . "(?:" . join ( '|', @stdioFunctions ) .")" .  "\\s*\\(";

        $trace_detect .= "pattern = $pattern\n" if ($b_TraceDetect); # traces_filter_line

        # Suppression des '.' ou '->' pattern, ce sont des surcharges ne faisant pas partie de stdio
        $code =~ s/(?:\.|\-\>)\s*(?:$pattern)/\(/sg ;

        while ($code =~ m{
                          (\w+\s*::\s*)?($pattern)
                         }gxm )
        {
            my $wordsBefore = $1;
            my $match = $2;                                                                                      # traces_filter_line
            my $line_number = TraceDetect::CalcLineMatch($code, pos($code)) if ($b_TraceDetect);                    # traces_filter_line

            if (defined $wordsBefore) {    # traces_filter_line
              $trace_detect .= "$base_filename:$line_number: \'$wordsBefore\' $match\n" if ($b_TraceDetect); }       # traces_filter_line
            else {     # traces_filter_line
              $trace_detect .= "$base_filename:$line_number: $match\n" if ($b_TraceDetect); }      # traces_filter_line


            if ((defined $wordsBefore) && ($wordsBefore =~ /::/ ))
            {
                if ($wordsBefore =~ /std\s*::/ )
                {
                    # $trace_detect .= "$base_filename:trouve1: \'$wordsBefore\' $match\n" if ($b_TraceDetect);  # traces_filter_line
                    $nbr_StdioFunctionCalls++;
                }
            }
            else
            {
              # $trace_detect .= "$base_filename:trouve2: \'$wordsBefore\' $match\n" if ($b_TraceDetect);        # traces_filter_line
              $nbr_StdioFunctionCalls++;
            }
        }
    }

    print STDERR "$mnemo_StdioFunctionCalls = $nbr_StdioFunctionCalls \n" if $debug;                             # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_StdioFunctionCalls, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($couples, $mnemo_StdioFunctionCalls, $nbr_StdioFunctionCalls );

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des utilisations de cin sans taille minimale
#-------------------------------------------------------------------------------
sub CountWithoutSizeCins($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_ ;
    my $status = 0;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $trace_detect = '';                                             # traces_filter_line

    my $nbr_WithoutSizeCins = 0;
    my $mnemo_WithoutSizeCins = Ident::Alias_WithoutSizeCins();

    if (not defined $vue->{'code'}) {
        $status |= Couples::counter_add($compteurs, $mnemo_WithoutSizeCins, Erreurs::COMPTEUR_ERREUR_VALUE );
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $code = $vue->{'code'};

    while ($code =~ m{
                         (
                           (\bcin\s*>>[^;]*)
                         )
                     }gmx)
    {
        my $match = $1;
        my $pos = pos($code) if ($b_TraceDetect);                                    # traces_filter_line
        my $line_number = TraceDetect::CalcLineMatch($code, $pos) if ($b_TraceDetect);  # traces_filter_line
        my $trace_line = "$base_filename:$line_number:$match\n" if ($b_TraceDetect); # traces_filter_line

        # le pattern contient-il setw?
        if ((defined $match) && not ($match =~ /setw\s*\(/))
        {
            $nbr_WithoutSizeCins++;
            $trace_line = "$base_filename:$line_number:$match\n" if ($b_TraceDetect); # traces_filter_line
        }
        else
        {
            $trace_line = "$base_filename:$line_number:          REJETER:       $match\n" if ($b_TraceDetect); # traces_filter_line
        }

        $trace_detect .= $trace_line if ($b_TraceDetect); # traces_filter_line
    }

    TraceDetect::DumpTraceDetect($fichier, $mnemo_WithoutSizeCins, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_WithoutSizeCins, $nbr_WithoutSizeCins);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des utilisations du cast du langage C
#-------------------------------------------------------------------------------
sub CountCCastUses ($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_ ;
    my $mnemo_CCastUses = Ident::Alias_CCastUses();
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $status = 0;

    my $code = $vue->{'code'};

    if (not defined $code) {
        $status |= Couples::counter_add($compteurs, $mnemo_CCastUses, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    my $operator         = qr/ \+ | \- | \* | \/ | \% | \^ | \~ | \! | \< | \> | \| |\& /sxo ;
    my $avant            = qr/ (?: \G | ; | , | \? | \: | \= | \{ | \} | \( | \) | $operator | \breturn\b ) /sxo ;

    my $name             = qr/ (?: \w* \s* \:\: \s* )* \w+ /sxo ;

    my $templateTypeName = qr/ $name \s* \< \s* (?: $name \s* \, \s* )* $name \s* \> /sxo ;

    my $type             = qr/ (?: \b (?: class | struct | union | signed | unsigned | long | short ) \s+ )*
                               $name
                               (?: \s+ (?: signed | unsigned | long | short ) \s+ )*
                               (?: \s* (?: \* | \& ) )* /sxo ;

    my $debutExpression  = qr/ (?: (?: (?: \& | \* | \- | \+ | \! | \~ ) \s* )? (?: \w+ | \( )
                             | (?: (?: \- | \+ | \! |\~ ) \s* )? \d+
                             | \"
                             | \' )/sxo ;

    # supprime le mot-cle 'const' pour faciliter l'ecriture des patterns de recherche
    $code =~ s/\bconst\b/ /sg ;

    # remplace les noms de type template par des noms de type simple pour faciliter l'ecriture des patterns de recherche
    while ( $code =~ s/$templateTypeName/typename/sg ) {}

    # ne compte pas les cast en 'void'
    $code =~ s/\(\s*void\s*\)/ /sg ;

#    $trace_detect .= "$base_filename:1:\n--- code source ---\n$code\n--- fin code source ---\n" if ($b_TraceDetect); # traces_filter_line

    my $CCastPattern = qr/ ( $avant \s* \( \s* $type \s* \) \s* $debutExpression ) /sxo ;
    my $nbr_CCastUses = () = $code =~ m/ $CCastPattern /sxg ;

# traces_filter_start

#     while ($code =~ m/ $CCastPattern /sxg ) {
#         my $line_number = TraceDetect::CalcLineMatch($code, pos($code)) if ($b_TraceDetect);
#         my $match = $1;
#         $match =~ s/\s*\n\s*/ /smg ;
#         Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_CCastUses, "pattern trouve: $match");
#         $trace_detect .= "$base_filename:$line_number:$match\n" if ($b_TraceDetect);
#     }

#     my $debutExpressionCandidate  = qr/ (?: (?: (?: \& | \* | \- | \+ | \! | \~ ) \s* )? (?: \w+ | \( )
#                                       | (?: (?: \- | \+ | \! |\~ ) \s* )? \d+
#                                       | \"
#                                       | \' )/sxo ;

#     my $CCastPatternCandidate = qr/ ( $avant \s* \( \s* $type \s* \) \s* (?: \{ \s* ) $debutExpressionCandidate ) /sxo ;

#     while ($code =~ m/ $CCastPatternCandidate /sxg ) {
#         my $line_number = TraceDetect::CalcLineMatch($code, pos($code)) if ($b_TraceDetect);
#         my $match = $1;
#         $match =~ s/\s*\n\s*/ /smg ;
#         Erreurs::LogInternalTraces("TRACE", $fichier, $line_number, $mnemo_CCastUses, "pattern candidat: $match");
#         $trace_detect .= "$base_filename:$line_number:$match\n" if ($b_TraceDetect);
#     }

# traces_filter_end

#    TraceDetect::DumpTraceDetect($fichier, $mnemo_CCastUses, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_CCastUses, $nbr_CCastUses);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des scanf contenant au moins un format sans taille
#-------------------------------------------------------------------------------
sub CountWithoutFormatSizeScanfs($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;

    my $status = 0;
    my $debug = 1; # traces_filter_line;

    my $mnemo_WithoutFormatSizeScanfs = Ident::Alias_WithoutFormatSizeScanfs();
    my $nbr_WithoutFormatSizeScanfs = 0;
    my $code = $vue->{'code'};
    my $HString = $vue->{'HString'};

    if ( (not defined $code) || (not defined $HString)) {
        $status |= Couples::counter_add($compteurs, $mnemo_WithoutFormatSizeScanfs, Erreurs::COMPTEUR_ERREUR_VALUE);
        return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    # scanf | vscanf ( Format
    # fscanf | sscanf | vfscanf | vsscanf ( ..., Format
    # _scanf_r ( ..., Format
    # _fscanf_r | _sscanf_r | ( ..., ..., Format

    # traitement des fonctions: [_][f|s]scanf
    while ( $code =~ /
                     \b (?: v?      scanf   \s* \( \s*
                          | v? [fs] scanf   \s* \( [^;,]* ,
                          |        _scanf_r \s* \( [^;,]* ,
                          |  _ [fs] scanf_r \s* \( [^;,]* , [^;,]* ,
                        )
                     \s* ( CHAINE_ \d+ )
                     /sxg )
    {
        my $match_key = $1;
        my $line_number = TraceDetect::CalcLineMatch($code, pos($code)); # traces_filter_line

        if (defined $match_key) {
            my $string = $HString->{$match_key};

            if (not defined $string) {
                print STDERR "[CountWithoutFormatSizeScanfs] cle de chaine non associee : $match_key\n";
            }
            elsif ( $string =~ /[^\\]\%[\*]?[\[A-Za-z]/ ) {
                # au moins un format sans taille precisee, cad qui n'est de la forme %3s
                $nbr_WithoutFormatSizeScanfs++;
                Erreurs::LogInternalTraces ('TRACE', $fichier, $line_number, $mnemo_WithoutFormatSizeScanfs, $string);
            }
        }
    }

    $status |= Couples::counter_add($compteurs, $mnemo_WithoutFormatSizeScanfs, $nbr_WithoutFormatSizeScanfs);

    return $status;
}

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
	  ( ! defined $compteurs->{Ident::Alias_Try()}) || 
	  ( ! defined $compteurs->{Ident::Alias_Catch()}) || 
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
	       $compteurs->{Ident::Alias_Try()} +
	       $compteurs->{Ident::Alias_Catch()} +
	       $compteurs->{Ident::Alias_FunctionMethodImplementations()};
    }

    $status |= Couples::counter_add($compteurs, $VG__mnemo, $nb_VG);
}


1;
