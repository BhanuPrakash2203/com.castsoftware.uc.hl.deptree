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

package CountMissingFinalElses;
# les modules importes
use strict;
use warnings;
use Erreurs;

# prototypes publics
sub CountMissingFinalElses($$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des instructions 'else' manquantes a la fin d'une cascade d'instructions 'else if'.
#
# LANGAGES: C, C++, C#, Java
#-------------------------------------------------------------------------------
sub CountMissingFinalElses($$$$) {

    my ($fichier, $vue, $compteurs, $options) = @_ ;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $trace_detect = '' if ($b_TraceDetect);                         # traces_filter_line
    my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
    $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    my $nbr_MissingFinalElses = 0 ;
    my $mnemo_MissingFinalElses = Ident::Alias_MissingFinalElses();

    my $code = '';

    if ( (exists $vue->{'prepro'}) && ( defined $vue->{'prepro'} ) ) {
      $code = $vue->{'prepro'};
      Erreurs::LogInternalTraces('DEBUG', $fichier, 1, $mnemo_MissingFinalElses, "utilisation de la vue prepro.\n");
    }
    else {
      $code = $vue->{'code'};
    }

    if ( ! defined $code ) {
      $nbr_MissingFinalElses = Erreurs::COMPTEUR_ERREUR_VALUE;
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
    else {
        # Suppression des imbrications de parentheses, afin de virer l'expression conditionnelle qui se trouve entre le mot cle structurel et
        # le debut de bloc qui est cense commencer par une accolade.
        while ( $code =~ s/\([^\(\)]*\)/ /sg ) {}

        # Neutralisation des mots cles de directive de compilation, en les faisant preceder de '_'
        $code =~ s/(#\s*)(if|ifdef|ifndef|else|elif|elifdef|elifndef|endif)/$1_$2/sg;

        # baliser les identificateurs 'elsif' pour eviter de les reconnaitre a tord
        $code =~ s/\belsif\b/els_balise_if/sg ;

        # on ne considere que les 'else if' et non les 'else { if'
        my $elseIfFound = $code =~ s/(\belse\s*if\b)/elsif/sg ;

        $trace_detect .= "$base_filename:1:$elseIfFound\n" if ($b_TraceDetect); # traces_filter_line

        # $trace_detect .= "$base_filename:1:\n--- code source ---\n$code\n--- fin code source ---\n" if ($b_TraceDetect); # traces_filter_line

        if ($elseIfFound > 0) {
            # il y a au moins un else if, on applique l'algorithme
            my @state;
            my @elsif_line;


            push @state, '';
            push @elsif_line, 1;

            my $line_number = 1 if ($b_TraceDetect); # traces_filter_line

            mainLoop: while ($code =~ m/
                             (\b(if|else|elsif)\b|\{|}|;)
                             /xgs
            )
            {
                 my $match = $1;
                 $line_number = TraceDetect::CalcLineMatch($code, pos($code)) if ($b_TraceDetect); # traces_filter_line
                 $trace_detect .= "$base_filename:$line_number:$match\n" if ($b_TraceDetect);   # traces_filter_line

                 if    ($match eq 'if') {
                     if ($state[-1] eq 'elsif stmt') {
                         $nbr_MissingFinalElses++;
                         $state[-1] = '';
                         $trace_detect .= "$fichier:$elsif_line[-1]:       ****       missing else\n" if ($b_TraceDetect); # traces_filter_line
                     }

                     $state[-1] = $match;
                 }
                 elsif ($match eq 'else') {
                     $state[-1] = $match;
                 }
                 elsif ($match eq 'elsif') {
                     $state[-1] = $match;
                         $elsif_line[-1] = $line_number if ($b_TraceDetect); # traces_filter_line
                 }
                 elsif ($match eq '{') {

                     if ($state[-1] eq 'elsif stmt') {
                         $nbr_MissingFinalElses++;
                             $state[-1] = '';
                         $trace_detect .= "$fichier:$elsif_line[-1]:       ****       missing else\n" if ($b_TraceDetect); # traces_filter_line
                     }

                     push @state, '{';
                     push @elsif_line, $line_number if ($b_TraceDetect); # traces_filter_line
                     # $trace_detect .= "$base_filename:$line_number: push\n" if ($b_TraceDetect); # traces_filter_line
                 }
                 elsif ($match eq '}') {

                     if ($state[-1] eq 'elsif stmt') {
                         $nbr_MissingFinalElses++;
                         $state[-1] = '';
                         $trace_detect .= "$fichier:$elsif_line[-1]:       ****       missing else\n" if ($b_TraceDetect); # traces_filter_line
                     }

                     if (@state > 1) {
                         pop @state;
                         pop @elsif_line if ($b_TraceDetect); # traces_filter_line
                         # $trace_detect .= "$base_filename:$line_number: pop\n" if ($b_TraceDetect); # traces_filter_line
                     }
                     else {
                         Erreurs::LogInternalTraces('ERROR', $fichier, $line_number, $mnemo_MissingFinalElses, "Erreur d'appariement des blocs");
                         $trace_detect .= "$base_filename:$line_number: Erreur d'appariement des blocs\n" if ($b_TraceDetect);       # traces_filter_line
                         TraceDetect::DumpTraceDetect($fichier, $mnemo_MissingFinalElses, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
                         # $status |= Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS; # traces_filter_line
                         next mainLoop;
                     }

                     if (($state[-1] eq ' stmt') || ($state[-1] eq '{ stmt')) {
                         # un bloc d'instructions
                     }
                     elsif ($state[-1] =~ 'stmt') {
                         $state[-1] = ' stmt';
                     }
                     else {
                         $state[-1] .= ' stmt';
                     }

                     # $trace_detect .= "$base_filename:$elsif_line[-1]: accolade fermante:$state[-1]\n" if ($b_TraceDetect); # traces_filter_line
                 }
                 elsif ($match eq ';') {

                     if ($state[-1] eq 'elsif stmt') {
                         $nbr_MissingFinalElses++;
                         $state[-1] = ' stmt';
                         $trace_detect .= "$fichier:$elsif_line[-1]:       ****       missing else\n" if ($b_TraceDetect); # traces_filter_line
                     }
                     elsif (($state[-1] eq ' stmt') || ($state[-1] eq '{ stmt')) {
                         # un bloc d'instructions
                     }
                     elsif ($state[-1] =~ 'stmt') {
                         $state[-1] = ' stmt';
                     }
                     else {
                         $state[-1] .= ' stmt';
                     }
                 }
                 else {                                                                                                  # traces_filter_line
                     Erreurs::LogInternalTraces('ERROR', $fichier, $line_number, $mnemo_MissingFinalElses, "Unexpected token: $state[-1]");
                     $trace_detect .= "$base_filename:$line_number: Unexpected token: $state[-1]\n" if ($b_TraceDetect); # traces_filter_line
                 }                                                                                                       # traces_filter_line

                 $trace_detect .= "$base_filename:$line_number: stmt:$state[-1]\n" if ($b_TraceDetect); # traces_filter_line
            }

            $trace_detect .= "$base_filename:$line_number: taille de state      : " . scalar @state . "\n" if ($b_TraceDetect);      # traces_filter_line
            $trace_detect .= "$base_filename:$line_number: taille de elsif_line : " . scalar @elsif_line . "\n" if ($b_TraceDetect); # traces_filter_line
        }
    }

    print STDERR "$mnemo_MissingFinalElses = $nbr_MissingFinalElses\n" if ($debug);                             # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_MissingFinalElses, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line

    $status |= Couples::counter_add($compteurs, $mnemo_MissingFinalElses, $nbr_MissingFinalElses);

    return $status;
}


1;
