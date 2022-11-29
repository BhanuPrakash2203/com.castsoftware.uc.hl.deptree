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

package CountBreakLoop;

use strict;
use warnings;
use Erreurs;

# prototypes publics
sub CountBreakLoop($$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage des instructions 'break' situees dans une boucle.
# Module de comptage des boucles contenant plus d'une instruction 'break'.
# Module de comptages des instructions 'break' manquants avant un 'case' ou un 'default'.
#
# Langages: C, C++, C#, Java
#-------------------------------------------------------------------------------

sub CountBreakLoop($$$$) {

    my ($fichier, $vue, $compteurs, $options) = @_ ;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
    my $trace_detect = ''; 						                        # traces_filter_line
    my $base_filename = $fichier; 										# traces_filter_line
    $base_filename =~ s{.*/}{};											# traces_filter_line
    my $debug = 0;                                                     # traces_filter_line
    my $status = 0;
    my $nbr_BreakLoop = 0 ;
    my $nbr_MultipleBreakLoops = 0 ;
    my $nbr_MissingBreakInSwitch = 0;
    my $mnemo_Break = Ident::Alias_Break();
    my $mnemo_MultipleBreakLoops = Ident::Alias_MultipleBreakLoops();
    my $mnemo_MissingBreakInSwitch = Ident::Alias_MissingBreakInSwitch();

    my @state;
    my @insideSwitchOrLoop;
    my @breakAlreadyFound;
    my @previousStmt;

    my $code = '';
    my $currentStmt = 'stmt';
    my $match = '';

    my $line_number = 1;												# traces_filter_line

    #--------------------------------------------------------------------------------------
    # Description: subroutine $popState qui mene les actions necessaires lors du depilement
    #--------------------------------------------------------------------------------------
    my $popState = sub () {

        my $localStatus = 0;

        $trace_detect .= "\n$base_filename:$line_number:*}*:insideSwitchOrLoop:$insideSwitchOrLoop[-1]\n" if ($b_TraceDetect); # traces_filter_line
        $trace_detect .= "$base_filename:$line_number:*}*:state:$state[-1]\n" if ($b_TraceDetect);                             # traces_filter_line
        $trace_detect .= "$base_filename:$line_number:*}*:token:$match\n" if ($b_TraceDetect);                                 # traces_filter_line
        $trace_detect .= "$base_filename:$line_number:*}*:break already found:$breakAlreadyFound[-1]\n" if ($b_TraceDetect);   # traces_filter_line
        $trace_detect .= "$base_filename:$line_number:*}*:previous stmt:$previousStmt[-1]\n" if ($b_TraceDetect);              # traces_filter_line

        $trace_detect .= "$base_filename:$line_number: pop $insideSwitchOrLoop[-1], $state[-1]\n" if ($b_TraceDetect);         # traces_filter_line

        if (@state <= 1) {
            Erreurs::LogInternalTraces('ERROR', $fichier, $line_number, $mnemo_Break, "Erreur d'appariement des blocs d'instuctions");
            Erreurs::LogInternalTraces('ERROR', $fichier, $line_number, $mnemo_MultipleBreakLoops, 'Erreur d\'appariement  des blocs d\'instuctions');
            Erreurs::LogInternalTraces('ERROR', $fichier, $line_number, $mnemo_MissingBreakInSwitch, 'Erreur d\'appariement  des blocs d\'instuctions');
            $trace_detect .= "$base_filename:$line_number: Erreur d'appariement des blocs d'instuctions\n" if ($b_TraceDetect); # traces_filter_line
            $localStatus |= Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
            Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'comptage!!!!', ''); # traces_filter_line
            # $status |= $localStatus; # traces_filter_line
        }
        else {
            my $currentBreakAlreadyFound = pop @breakAlreadyFound;
            my $leavingState = pop @state;
            my $leavingInsideSwitchOrLoop = pop @insideSwitchOrLoop;
            my $leavingPreviousStmt = pop @previousStmt;

            $trace_detect .= "pop\n$base_filename:$line_number:*}*:leavingInsideSwitchOrLoop:$leavingInsideSwitchOrLoop\n" if ($b_TraceDetect); # traces_filter_line
            $trace_detect .= "$base_filename:$line_number:*}*:leavingState:$leavingState\n" if ($b_TraceDetect);                       # traces_filter_line
            $trace_detect .= "$base_filename:$line_number:*}*:leavingPreviousStmt:$leavingPreviousStmt\n" if ($b_TraceDetect);         # traces_filter_line

            # gestion des 'break' en trop
            if ($state[-1] !~ /\b(loop|switch)\b/ ) {
                if (defined $breakAlreadyFound[-1]) { $breakAlreadyFound[-1] += $currentBreakAlreadyFound; }
            }

            # gestion des break manquants dans le case ou default
            if ($leavingInsideSwitchOrLoop eq 'switch') {
                if ($leavingState eq 'stmt') {
                    # on fini un bloc qui n'est pas lie a une structure de controle,
                    # on propage le break eventuel
                    $currentStmt = $leavingPreviousStmt;
                }
                elsif ($leavingState =~ 'if|else') {
                    # pour les break manquants en fin de case ou default,
                    # on ne tient pas compte des break contenus dans une structure de test
                    $currentStmt = 'stmt';
                }
                elsif ($leavingState eq 'loop') {
                    # pour les break manquants en fin de case ou default,
                    # on ne tient pas compte des break contenus dans une structure de boucle
                    $currentStmt = 'stmt';
                }
                elsif ($leavingState eq 'switch') {
                    # on sort du switch
                    if ($leavingPreviousStmt ne 'break ;') {
                        # la derniere instruction n'est pas un break
                        $nbr_MissingBreakInSwitch++;
                        $trace_detect .= "$base_filename:$line_number:$mnemo_MissingBreakInSwitch: Missing break in switch\n" if ($b_TraceDetect); # traces_filter_line

                    }
                    $currentStmt = 'stmt';
                }
                else {
                    $currentStmt = 'stmt';
                    $trace_detect .= "$base_filename:$line_number: Unexpected leavingState: $leavingState\n" if ($b_TraceDetect); # traces_filter_line
                }
            }
            elsif ($leavingInsideSwitchOrLoop eq 'loop') {
                # pour les breaks manquants en fin de case ou default,
                # on ne tient pas compte des break contenus dans une structure de boucle
                $currentStmt = 'stmt';
            }
            else {
                # on sort de la methode ou fonction
                $currentStmt = 'stmt';
            }

            $previousStmt[-1] = $currentStmt;
        }

        return $localStatus;
    };
    #-------------------------------
    # fin de la subroutine $popState
    #-------------------------------


#    if ( (exists $vue->{'prepro'}) && ( defined $vue->{'prepro'} ) ) {
#        $code = $vue->{'prepro'};
#	Erreurs::LogInternalTraces('DEBUG', $fichier, 1, $mnemo_Break, "utilisation de la vue prepro.\n");
#	Erreurs::LogInternalTraces('DEBUG', $fichier, 1, $mnemo_MultipleBreakLoops, "utilisation de la vue prepro.\n");
#	Erreurs::LogInternalTraces('DEBUG', $fichier, 1, $mnemo_MissingBreakInSwitch, "utilisation de la vue prepro.\n");
#    }
#    else {
#        $code = $vue->{'code'};
#    }

    $code = ${Vues::getView($vue, 'prepro', 'code')};

    if (! defined $code) {
      $nbr_BreakLoop = Erreurs::COMPTEUR_ERREUR_VALUE;
      $nbr_MultipleBreakLoops = Erreurs::COMPTEUR_ERREUR_VALUE;
      $nbr_MissingBreakInSwitch = Erreurs::COMPTEUR_ERREUR_VALUE;
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
    else {
        # Suppression des imbrications de parentheses.
        while ( $code =~ s/\([^\(\)]*\)/ /sg ) {}

        # FIXME: # Suppression des instructions vides.
        # FIXME: # demande eventuelle de BT
        # FIXME: while ( $code =~ s/;\s*;/;/sg ) {}

        # Suppression des directives de compilation, sinon probleme avec directive entre '}' et 'else'
        $code =~ s/(#\s*)(if|ifdef|ifndef|else|elif|elifdef|elifndef|endif)[^\n]*/ /sg;

        $trace_detect .= "$base_filename:1:\n--- code source ---\n$code\n--- fin code source ---\n" if ($b_TraceDetect); # traces_filter_line

        push @state, 'stmt';
        push @insideSwitchOrLoop, 'stmt';
        push @breakAlreadyFound, 0;
        push @previousStmt, 'stmt';

        mainLoop: while ($code =~ m/
                          (\b(if|else|while|do|for|foreach|break|continue|switch|case|default|return|throw|goto)\b
                         |\{
                         |(}|;)\s*(else\b)?)
                         /xgs
        )
        {
            $match = $1;

            $match =~ s/\s+/ /sg ;

            while ($match ne '')
            {
                $line_number = TraceDetect::CalcLineMatch($code, pos($code)) if ($b_TraceDetect);                                     # traces_filter_line
                $trace_detect .= "\n$base_filename:$line_number:insideSwitchOrLoop:$insideSwitchOrLoop[-1]\n" if ($b_TraceDetect); # traces_filter_line
                $trace_detect .= "$base_filename:$line_number:state:$state[-1]\n" if ($b_TraceDetect);                             # traces_filter_line
                $trace_detect .= "$base_filename:$line_number:token:$match\n" if ($b_TraceDetect);                                 # traces_filter_line
                $trace_detect .= "$base_filename:$line_number:break already found:$breakAlreadyFound[-1]\n" if ($b_TraceDetect);   # traces_filter_line
                $trace_detect .= "$base_filename:$line_number:previous stmt:$previousStmt[-1]\n" if ($b_TraceDetect);              # traces_filter_line

                $trace_detect .= "$base_filename:$line_number: $match\n" if ($b_TraceDetect);                                      # traces_filter_line

                if ($match eq 'break') {
                    if ($insideSwitchOrLoop[-1] eq 'loop') {
                        $nbr_BreakLoop++;

                        $breakAlreadyFound[-1]++;

                        if ($breakAlreadyFound[-1] > 1) { # traces_filter_line
                            $trace_detect .= "$base_filename:$line_number:$mnemo_MultipleBreakLoops: Unexpected break\n" if ($b_TraceDetect); # traces_filter_line
                        } # traces_filter_line

                        if ($breakAlreadyFound[-1] == 2) {
                            # la boucle est 'fautive' a partir de 2 break.
                            # on ne doit compter la boucle qu'une seule fois, et pas à chaque fois qu'un break en trop apparait.
                            $nbr_MultipleBreakLoops++;
                            $trace_detect .= "$base_filename:$line_number:$mnemo_MultipleBreakLoops: Multiple break loop\n" if ($b_TraceDetect); # traces_filter_line
                        }
                    }

                    $currentStmt = $match;

                    $match = '';
                }
                elsif ($match eq '{') {

                    if ($state[-1] eq 'switch') {
                        $currentStmt = 'break ;'; # sinon signalement a tord sur le 1er case
                    }
                    else {
                        $currentStmt = 'stmt';
                    }

                    push @state, 'stmt';
                    push @insideSwitchOrLoop, $insideSwitchOrLoop[-1];
                    push @breakAlreadyFound, $breakAlreadyFound[-1];
                    push @previousStmt, 'stmt';

                    $trace_detect .= "$base_filename:$line_number: push $insideSwitchOrLoop[-1], $state[-1]\n" if ($b_TraceDetect); # traces_filter_line
                    $match = '';
                }
                elsif ($match =~ /}/ ) {

                    if (@state > 1) {

                          my $localStatus = &$popState();

                          if ($localStatus != 0) {
                              next mainLoop;
                          }
                    }
                    else {
                        Erreurs::LogInternalTraces('ERROR', $fichier, $line_number, $mnemo_Break, "Erreur d'appariement des blocs d'instuctions");
                        Erreurs::LogInternalTraces('ERROR', $fichier, $line_number, $mnemo_MultipleBreakLoops, "Erreur d'appariement des blocs d'instuctions");
                        Erreurs::LogInternalTraces('ERROR', $fichier, $line_number, $mnemo_MissingBreakInSwitch, "Erreur d'appariement des blocs d'instuctions");
                        $trace_detect .= "$base_filename:$line_number: Erreur d'appariement des blocs d'instuctions\n" if ($b_TraceDetect); # traces_filter_line
                        # $status |= Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS; # traces_filter_line
                        next mainLoop;
                    }

                    if ($match =~ /\belse\b/ ) {
                        $match = 'else';
                    }
                    else {
                        $match = 'stmt';

                        while ((@state > 0) && ($state[-1] ne 'stmt')) {

                            my $localStatus = &$popState();

                            if ($localStatus != 0) {
                                next mainLoop;
                            }
                        }
                        $match = '';
                    }
                }
                elsif ($match =~ /;/ ) {

                    if ($currentStmt eq 'break') {
                      $currentStmt = 'break ;';
                    }
                    else {
                      $currentStmt = 'stmt';
                    }

                    if ($match =~ /\belse\b/ ) {
                        $match = 'else';
                    }
                    else {
                        $match = 'stmt';

                        while ((@state > 0) && ($state[-1] ne 'stmt')) {

                            my $localStatus = &$popState();

                            if ($localStatus != 0) {
                                next mainLoop;
                            }
                        }

                        $match = '';
                    }
                }
                elsif ($match =~ /\b(while|do|for|foreach)\b/ ) {
                    push @state, 'loop';
                    push @insideSwitchOrLoop, 'loop';
                    push @breakAlreadyFound, 0;
                    push @previousStmt, 'loop';

                    $currentStmt = $match;

                    $trace_detect .= "$base_filename:$line_number: push $insideSwitchOrLoop[-1], $state[-1]\n" if ($b_TraceDetect); # traces_filter_line
                    $match = '';
                }
                elsif ($match eq 'switch') {
                    push @state, $match;
                    push @insideSwitchOrLoop, $match;
                    push @breakAlreadyFound, 0;
                    push @previousStmt, 'break ;'; # sinon signalement a tord sur le 1er case

                    $currentStmt = $match;

                    $trace_detect .= "$base_filename:$line_number: push $insideSwitchOrLoop[-1], $state[-1]\n" if ($b_TraceDetect); # traces_filter_line
                    $match = '';
                }
                elsif ($match eq 'if' ) {
                    push @state, $match;
                    push @insideSwitchOrLoop, $insideSwitchOrLoop[-1];
                    push @breakAlreadyFound, $breakAlreadyFound[-1];
                    push @previousStmt, $match;

                    $currentStmt = $match;

                    $trace_detect .= "$base_filename:$line_number: push $insideSwitchOrLoop[-1], $state[-1]\n" if ($b_TraceDetect); # traces_filter_line
                    $match = '';
                }
                elsif ($match eq 'else' ) {
                    $state[-1] = $match;
                    $currentStmt = $match;
                    $match = '';
                }
                elsif ($match =~ /\b(continue|return|throw|goto)\b/ ) {
                    $currentStmt = 'break';
                    $match = '';
                }
                elsif ($match =~ /\b(case|default)\b/ ) {

                    $currentStmt = $match;

                    if ($previousStmt[-1] !~ /switch|case|default|break ;/ ) {
                        # un case ou default non precede d'un case, default, break, return, continue, throw ou goto
                        $nbr_MissingBreakInSwitch++;
print STDERR "MISSING BREAK before case/default\n";
                        $trace_detect .= "$base_filename:$line_number:$mnemo_MissingBreakInSwitch: Missing break in switch\n" if ($b_TraceDetect); # traces_filter_line
                    }
                    # else OK
                    $match = '';
                }
                else {
                    Erreurs::LogInternalTraces('ERROR', $fichier, $line_number, $mnemo_Break, "Erreur, unexpected token: $match");
                    Erreurs::LogInternalTraces('ERROR', $fichier, $line_number, $mnemo_MultipleBreakLoops, "Erreur, unexpected token: $match");
                    Erreurs::LogInternalTraces('ERROR', $fichier, $line_number, $mnemo_MissingBreakInSwitch, "Erreur, unexpected token: $match");
                    $trace_detect .= "$base_filename:$line_number: Unexpected token: $match\n" if ($b_TraceDetect); # traces_filter_line
                    # $status |= Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS; # traces_filter_line
                    $currentStmt = 'stmt';
                    $match = '';
                }

                $previousStmt[-1] = $currentStmt;
            }
        }

        $trace_detect .= "$base_filename:$line_number: taille de state             : " . scalar @state . "\n" if ($b_TraceDetect); # traces_filter_line
        $trace_detect .= "$base_filename:$line_number: taille de insideSwitchOrLoop           : " . scalar @insideSwitchOrLoop . "\n" if ($b_TraceDetect); # traces_filter_line
        $trace_detect .= "$base_filename:$line_number: taille de breakAlreadyFound : " . scalar @breakAlreadyFound . "\n" if ($b_TraceDetect); # traces_filter_line
    }

    print STDERR "$mnemo_Break = $nbr_BreakLoop\n" if ($debug);                                                    # traces_filter_line
    print STDERR "$mnemo_MultipleBreakLoops = $nbr_MultipleBreakLoops\n" if ($debug);                              # traces_filter_line
    print STDERR "$mnemo_MissingBreakInSwitch = $nbr_MissingBreakInSwitch\n" if ($debug);                          # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_Break, $trace_detect, $options) if ($b_TraceDetect);                # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_MultipleBreakLoops, $trace_detect, $options) if ($b_TraceDetect);   # traces_filter_line
    TraceDetect::DumpTraceDetect($fichier, $mnemo_MissingBreakInSwitch, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line

    $status |= Couples::counter_add($compteurs, $mnemo_Break, $nbr_BreakLoop);
    $status |= Couples::counter_add($compteurs, $mnemo_MultipleBreakLoops, $nbr_MultipleBreakLoops);
    $status |= Couples::counter_add($compteurs, $mnemo_MissingBreakInSwitch, $nbr_MissingBreakInSwitch);

    return $status;
}


1;
