#------------------------------------------------------------------------------#
#                         @ISOSCOPE 2008                                       #
#------------------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                          #
#               Adresse : TERSUD - Bat A                                       #
#                         5, AVENUE MARCEL DASSAULT                            #
#                         31500  TOULOUSE                                      #
#               SIRET   : 410 630 164 00037                                    #
#------------------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                                #
# l'Institut National de la Propriete Industrielle (lettre Soleau)             #
#------------------------------------------------------------------------------#

# Composant: Plugin
#-------------------------------------------------------------------------------
# DESCRIPTION: Composant de mesure de vulnerabilites pour C, C++ et Java
#-------------------------------------------------------------------------------

package CountVulnerabilite;

# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use TraceDetect;
use Timeout;

# prototypes publics
sub CountAll_Java($$$$);                        #bt_filter_line
sub CountAll_C_CPP($$$$);
sub CountClassComparaison($$$$);                #bt_filter_line
sub CountWeakStringFunctionCalls($$$$);
sub CountShellLauncherFunctionCalls($$$$);
sub CountFormat($$$$);
sub CountDefArrayFixedSize($$$$);

# prototypes prives
sub SubProcessxParam($$$$$$@);


#bt_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage de toutes les vulnerabilites Java
#-------------------------------------------------------------------------------
sub CountAll_Java($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # traces_filter_line
    assert(defined $fichier);                                  # traces_filter_line
    assert(defined $vue);                                      # traces_filter_line
    assert(defined $compteurs);                                # traces_filter_line
    assert(defined $options);                                  # traces_filter_line

    my $status = 0;

    $status |= CountClassComparaison($fichier, $vue, $compteurs, $options);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage de l'utilisation des noms de classes
# recherche de getClass().getName()
# langage : Java
#-------------------------------------------------------------------------------
sub CountClassComparaison($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $trace_detect = '' if ($b_TraceDetect);                         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line

    my $status = 0;

    my $nbr_ClassesComparisons = 0;
    my $mnemo_ClassesComparisons = Ident::Alias_ClassesComparisons();

    if (not defined $vue->{'code'})
    {
        assert(defined $vue->{'code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add($compteurs, $mnemo_ClassesComparisons, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $code = $vue->{'code'};

    while ($code =~ m{
                        (
                            \bgetClass\s*\(\)\s*\.\s*getName\s*\(\)
                        )
                    }gxm)
    {
        $nbr_ClassesComparisons++;
        my $match = $1;                                                                   # traces_filter_line
        $match =~ s/\n//g if ($b_TraceDetect);                                            # traces_filter_line
        my $line_number = TraceDetect::CalcLineMatch($code, pos($code)) if ($b_TraceDetect); # traces_filter_line
        $trace_detect .= "$base_filename:$line_number:$match\n" if ($b_TraceDetect);      # traces_filter_line
    }

    print STDERR "$mnemo_ClassesComparisons = $nbr_ClassesComparisons\n" if $debug;                              # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_ClassesComparisons, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_ClassesComparisons, $nbr_ClassesComparisons);

    return $status;
}

#bt_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage d'appel de fonctions non securisees
# langage : C, C++
#-------------------------------------------------------------------------------
my @weakFunctions  = qw /strcpy strcat sprintf vsprintf gets/;
sub CountWeakStringFunctionCalls($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $trace_detect = '' if ($b_TraceDetect);                         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;

    my $nbr_WeakStringFunctionCalls = 0;
    my $mnemo_WeakStringFunctionCalls = Ident::Alias_WeakStringFunctionCalls();

    if (not defined $vue->{'code'})
    {
        assert(defined $vue->{'code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add($compteurs, $mnemo_WeakStringFunctionCalls, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $code = $vue->{'code'};

    my $nb = @weakFunctions;

    for (my $i = 0; $i < $nb; $i++)
    {
        my $pattern = "\\b$weakFunctions[$i]\\s*\\(";

        $trace_detect .= "pattern = $pattern\n" if ($b_TraceDetect); # traces_filter_line

        # Suppression des '.' ou '->' pattern, ce sont des surcharges ne faisant pas partie de stdio
        $code =~ s/(?:\.|\-\>)\s*(?:$pattern)/\(/sg ;

        while ($code =~ m{
                          (\w+\s*::\s*)?($pattern)
                         }gxm )
        {
            my $wordsBefore = $1;
            my $match = $2;                                                                                     # traces_filter_line
            my $line_number = TraceDetect::CalcLineMatch($code, pos($code)) if ($b_TraceDetect);                   # traces_filter_line

            $trace_detect .= "$base_filename:$line_number: \'$wordsBefore\' $match\n" if ($b_TraceDetect);      # traces_filter_line

            if ((defined $wordsBefore) && ($wordsBefore =~ /::/ ))
            {
                if ($wordsBefore =~ /std\s*::/ )
                {
                    # $trace_detect .= "$base_filename:trouve1: \'$wordsBefore\' $match\n" if ($b_TraceDetect); # traces_filter_line
                    $nbr_WeakStringFunctionCalls++;
                }
            }
            else
            {
              # $trace_detect .= "$base_filename:trouve2: \'$wordsBefore\' $match\n" if ($b_TraceDetect);       # traces_filter_line
              $nbr_WeakStringFunctionCalls++;
            }
        }
    }

    print STDERR "$mnemo_WeakStringFunctionCalls = $nbr_WeakStringFunctionCalls\n" if $debug;                         # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_WeakStringFunctionCalls, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_WeakStringFunctionCalls, $nbr_WeakStringFunctionCalls);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage d'appel de fonctions shell
# langage : C, C++
#-------------------------------------------------------------------------------
my @shellFunctions = qw /popen system exec execl execlp execle execv execvp ShellExecute/;
sub CountShellLauncherFunctionCalls($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $trace_detect = '' if ($b_TraceDetect);                         # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;

    my $nbr_ShellLauncherFunctionCalls = 0;
    my $mnemo_ShellLauncherFunctionCalls = Ident::Alias_ShellLauncherFunctionCalls();

    if (not defined $vue->{'code'})
    {
        assert(defined $vue->{'code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add($compteurs, $mnemo_ShellLauncherFunctionCalls, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $code = $vue->{'code'};

    my $nb = @shellFunctions;

    for (my $i = 0; $i < $nb; $i++)
    {
        my $pattern = "\\b$shellFunctions[$i]\\s*\\(";

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

            $trace_detect .= "$base_filename:$line_number: \'$wordsBefore\' $match\n" if ($b_TraceDetect);       # traces_filter_line

            if ((defined $wordsBefore) && ($wordsBefore =~ /::/ ))
            {
                if ($wordsBefore =~ /std\s*::/ )
                {
                    # $trace_detect .= "$base_filename:trouve1: \'$wordsBefore\' $match\n" if ($b_TraceDetect);  # traces_filter_line
                    $nbr_ShellLauncherFunctionCalls++;
                }
            }
            else
            {
              # $trace_detect .= "$base_filename:trouve2: \'$wordsBefore\' $match\n" if ($b_TraceDetect);        # traces_filter_line
              $nbr_ShellLauncherFunctionCalls++;
            }
        }
    }

    print STDERR "$mnemo_ShellLauncherFunctionCalls = $nbr_ShellLauncherFunctionCalls \n" if $debug;                     # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_ShellLauncherFunctionCalls, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_ShellLauncherFunctionCalls, $nbr_ShellLauncherFunctionCalls);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage de vulnerabilite de type format
# langage : C, C++
# FIXME: Anomalie 229.
#-------------------------------------------------------------------------------
my @fonctions_1er_param  = qw /printf syslog setproctitle/;
my @fonctions_2eme_param = qw /fprintf sprintf vsprintf/;
my @fonctions_3eme_param = qw /snprintf/;
sub CountFormat($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line

    my $status = 0;

    my $mnemo_BadEffectiveParameter = Ident::Alias_BadEffectiveParameter();
    my $nbr_total_BadEffectiveParameter = 0;

    my $mnemo_BadEffectiveFirstParameter = Ident::Alias_BadEffectiveFirstParameter();
    my $mnemo_BadEffectiveSecondParameter = Ident::Alias_BadEffectiveSecondParameter();
    my $mnemo_BadEffectiveThirdParameter = Ident::Alias_BadEffectiveThirdParameter();

    if (not defined $vue->{'text'})
    {
        assert(defined $vue->{'text'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add($compteurs, $mnemo_BadEffectiveFirstParameter, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add($compteurs, $mnemo_BadEffectiveSecondParameter, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Couples::counter_add($compteurs, $mnemo_BadEffectiveThirdParameter, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        #
        return $status;
    }

    my $code = $vue->{'text'};
    # Ecrabouiller commentaires et chaines.
    $code =~ s{
                (
                    \"(\\.|[^\"]*)*\"    |
                    \'(\\.|[^\']*)*\'    |
                    //[^\n]*             |
                    /\*.*?\*/
                )
              }
            {
                my $match = $1;
                $match =~ s{\S+}{ }g;
                $match =~ s{\n}{\\\n}g;
                $match;
            }gxse;

    my $pattern = "\\s*\\((.*?)[,\\)] ";
    my $status_ex = 0;
    my $nb_ex = 0;
    ($status_ex, $nb_ex) = SubProcessxParam($fichier, $code, $pattern, $mnemo_BadEffectiveFirstParameter, $compteurs, $options, @fonctions_1er_param);
    $status |= $status_ex;
    $nbr_total_BadEffectiveParameter += $nb_ex;

    $pattern = '\\s*\\(.*?,(.*?)[,\\)] ';
    ($status_ex, $nb_ex) = SubProcessxParam($fichier, $code, $pattern, $mnemo_BadEffectiveSecondParameter, $compteurs, $options, @fonctions_2eme_param);
    $status |= $status_ex;
    $nbr_total_BadEffectiveParameter += $nb_ex;

    $pattern = '\\s*\\(.*?,.*?,(.*?)[,\\)] ';
    ($status_ex, $nb_ex) = SubProcessxParam($fichier, $code, $pattern, $mnemo_BadEffectiveThirdParameter, $compteurs, $options, @fonctions_3eme_param);
    $status |= $status_ex;
    $nbr_total_BadEffectiveParameter += $nb_ex;

    print STDERR "$mnemo_BadEffectiveParameter = $nbr_total_BadEffectiveParameter \n" if ($debug); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_BadEffectiveParameter, $nbr_total_BadEffectiveParameter);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: sous-fonction du module de comptage de vulnerabilite de type format
#-------------------------------------------------------------------------------
sub SubProcessxParam($$$$$$@)
{
    # extraire le nom du nieme parametre de la fonction
    my ($fichier, $code, $pattern, $mnemo, $compteurs, $options, @functionList) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $trace_detect = '' if ($b_TraceDetect);                         # traces_filter_line
    my $status = 0;

    my $nb = 0;
    foreach my $function(@functionList)
    {
        my $line_number = 0; # traces_filter_line
        my $function_pattern = "\\s($function)$pattern";
        while ($code =~ m{
                            (
                             $function_pattern
                            )
                            (.*)
                         }gxm )
        {
            my $match = $1;        # traces_filter_line
            my $functionName = $2; # traces_filter_line
            my $param = $3;
            # si le parametre contient autre chose que des espaces
            # cad un nom de variable
            if (($param =~ /\w/))
            {
                $nb++;
                my $line_number = TraceDetect::CalcLineMatch($code, pos($code)) if ($b_TraceDetect);    # traces_filter_line
                $trace_detect .= "$base_filename:$line_number:$match:$param\n"  if ($b_TraceDetect); # traces_filter_line
            }
        }
    }

    print STDERR "$mnemo = $nb \n" if $debug;                                                 # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo, $nb);  #bt_filter_line

    return ($status, $nb);
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage d'utilisation de tableau de taille fixe
# langage : C, C++
#-------------------------------------------------------------------------------
sub CountDefArrayFixedSize($$$$)
{
    my ($fichier, $vue, $compteurs, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0);         # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $trace_detect_FixedSizeArrays = '' if ($b_TraceDetect);         # traces_filter_line
    my $status = 0;

    my $nbr_FixedSizeArrays = 0;
    my $mnemo_FixedSizeArrays = Ident::Alias_FixedSizeArrays();

    if (not defined $vue->{'code'})
    {
        assert(defined $vue->{'code'}) if ($b_assert); # traces_filter_line
        $status |= Couples::counter_add($compteurs, $mnemo_FixedSizeArrays, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $code = $vue->{'code'};
    while ($code =~ m{
                        (
                            ((unsigned|signed)\s*)?\bchar\s+\w*\s*\[.*?[^;=]+
                        )
                    }gxm)
    {
        $nbr_FixedSizeArrays++;
        my $match = $1;                                                                              # traces_filter_line
        my $line_number = TraceDetect::CalcLineMatch($code, pos($code)) if ($b_TraceDetect);            # traces_filter_line
        $trace_detect_FixedSizeArrays .= "$base_filename:$line_number:$match\n" if ($b_TraceDetect); # traces_filter_line
    }

    TraceDetect::DumpTraceDetect($fichier, $mnemo_FixedSizeArrays, $trace_detect_FixedSizeArrays, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_FixedSizeArrays, $nbr_FixedSizeArrays);

    return $status;
}


1;
