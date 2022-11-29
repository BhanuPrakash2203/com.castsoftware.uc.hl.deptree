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

# Composant: Framework
#----------------------------------------------------------------------#
# DESCRIPTION:
# Les fonctions communes aux modules Ana de differents langages
#----------------------------------------------------------------------#

package AnaUtils;

# les modules importes
use strict;
use warnings;
use Erreurs;
use Timing; # timing_filter_line
use Memory; # memory_filter_line
use Timeout;
use IsoscopeDataFile;
use Couples;
use KeywordScan::Count;

# prototypes publics
sub Count ($$$$$;$);
sub file_type_register ($$$$);
sub AnalyseAccoladesParenthesesRapide ($$$$);
sub VerifieCoherenceAccoladesParenthesesDirectActiveBuffer ($$$$);


use constant DUMMYFILENAME => '__iso__dummy__iso__';

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Fonction permettant au module Ana de lancer chaque fonction de comptage,
# a partir d'une table de configuration.
#-------------------------------------------------------------------------------
sub Count ($$$$$;$)
{
    my ($fichier, $vue, $options, $couples, $ref_ArrayTableCountersAndNames, $allowKeywordScan) = @_;

	if (!defined $allowKeywordScan) {
		$allowKeywordScan = 1;
	}

    my $countersTiming = new Timing ("Temps des fonctions de comptage", Timing->isSelectedTiming ('Count'));
    my $memory = new Memory('AnaUtils');                                                                         # memory_filter_line

    my $b_option_run_only_one_function = exists ($options->{'--runonecounterfunction'});                         # traces_filter_line
    my $option_run_only_one_function = '';                                                                       # traces_filter_line

    my $status = 0;

    $option_run_only_one_function = $options-> {'--runonecounterfunction'} if ($b_option_run_only_one_function); # traces_filter_line

    $countersTiming->markTimeAndPrint ('--start--') if ( defined $options->{'--timing'});                        # timing_filter_line

    my $index = 0;
    foreach my $counter_item ( @{$ref_ArrayTableCountersAndNames} )
    {
        my $counter = $counter_item->[0];
        my $counterName = $counter_item->[1];
        my $CountConfParam = $counter_item->[2];

	$vue->{'CountConfParam'} = \$CountConfParam;

        next if ($b_option_run_only_one_function && not ($counterName =~ /^$option_run_only_one_function$/));    # traces_filter_line

        my $parametres = prototype ($counter);

        # print STDERR 'Lancement de ' . $counterName; # traces_filter_line
        Erreurs::LogInternalTraces ('trace', undef, undef, 'Lancement de ', $counterName, '') ;

        eval
        {
            my $local_status = 0;

            if (not defined $parametres )
            {
                # Dans le doute, un argument inutile ne peut pas faire de mal.
                $local_status |= $counter->($fichier, $vue, $couples, $options);
            }
            elsif ($parametres eq '$$$' )
            {
                # Les fonctions avec 3 parametres
                $local_status |= $counter->($fichier, $vue, $couples);
            }
            elsif ($parametres eq '$$$$' )
            {
                # Les fonctions avec 4 parametres
                $local_status |= $counter->($fichier, $vue, $couples, $options);
            }
            else
            {
                # Dans le doute, un argument inutile ne peut pas faire de mal.
                # print STDERR 'Prototype de '.$counterName.' en $position '.$index.' non reconnu: (' .$parametres. ")\n";
                Erreurs::LogInternalTraces ('trace', undef, undef, 'Prototype',                                    # traces_filter_line
                'Prototype de '.$counterName.' en $position '.$index.' non reconnu: (' .$parametres. ")", ' ') ; # traces_filter_line
                $local_status |= $counter->($fichier, $vue, $couples, $options);                                 # traces_filter_line
            }

            if ($local_status != 0)
            {
                # print STDERR "=> STATUS=$local_status"; # traces_filter_line
                Erreurs::LogInternalTraces ('trace', undef, undef, 'STATUS', $local_status, "$counterName") ;
            }

            # print STDERR "\n"; # traces_filter_line

            $status |= $local_status;
        };

        if ($@)
        {
            Timeout::DontCatchTimeout();   # propagate timeout errors
            #die ($@) if $@ eq "alarm\n";   # propagate timeout errors

            $parametres = '' if not defined ($parametres);
            print STDERR "\n\n erreur dans le module de comptage " . $counterName . " : " . $parametres . " : $@\n";
            $status |= Erreurs::COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE;
        }

        # print STDERR 'Lancement de ' . $counterName; # traces_filter_line
        Erreurs::LogInternalTraces ('trace', undef, undef, 'Fin de ', $counterName, '') ;

        if ( defined $options->{'--timing'})                                    # timing_filter_line
        {                                                                       # timing_filter_line
            $parametres = '' if not defined ($parametres);                      # timing_filter_line
            my $display = $index . ':' . $counterName . '(' . $parametres .')'; # timing_filter_line
            $countersTiming->markTimeAndPrint($display);                        # timing_filter_line
        }                                                                       # timing_filter_line

        $index++;

        $parametres = '' if not defined ($parametres);                          # timing_filter_line
        my $display = $index . ':' . $counterName . '(' . $parametres . ')';    # memory_filter_line
        $memory->memusage($display);                                            # memory_filter_line
    }

	if (($allowKeywordScan) &&  (defined $options->{'--KeywordScan'}))
	{ 
		eval {
            # TODO: for adding scope support to searchItem (csv version)
            # modify this subroutine to allow parsing searchItem csv version
			KeywordScan::Count::Count($fichier, $vue, $couples);
		};
			
		if ($@) {
			Timeout::DontCatchTimeout();   # propagate timeout errors
			#die ($@) if $@ eq "alarm\n";   # propagate timeout errors
			print STDERR "\n\n ERROR when launching user scans : $@\n";
			$status |= Erreurs::COMPTEUR_STATUS_UN_OU_PLUSIEUR_CPT_NON_EFFECTUE;
		}
	}

    $countersTiming->dump('PerfParComptage');                                   # timing_filter_line
    $countersTiming->finish();                                                  # timing_filter_line

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Allow to launch all counter (DIAG) function for each analysis unit.
# A specific callback provided by the language parser is used to get successively all units.
#-------------------------------------------------------------------------------
sub CountForSeveralUnits($$$$$$) {
  my ($fichier, $vue, $options, $couples, $r_FunctionPtr_list, $cb_NextUnit) = @_;
  
  # if (defined $options->{'--CloudReady'})  {
	# print STDERR "\nWARNING : CloudReady analysis is not supported in several units splitting mode !!\n\n";
  # }


  # built list of counters common to all units and list of counters that must
  # be computed for each unit.
  # ----------------------------------------------------------------------------
  my @UnitCounters_list = ();
  my @CommonCounters_list = ();
  for my $counter_item ( @{$r_FunctionPtr_list} ) {
    # field 3 is the selection type. 
    if ($counter_item->[3] == 2) {
      # The value 2 signifies the counter must be evaluated for each unit...
      push @UnitCounters_list, $counter_item;
    }
    else {
      # ... else the counter is evaluated on the whole file, and the value will
      # be assigned for all units.
      push @CommonCounters_list, $counter_item;
    }
  }
  
  # compute value for the counters common to all unit (computed in the whole
  # file)
  # ----------------------------------------------------------------------------
  
  # O in last parm mean do not perform keyword scan (do it only on the units)
  my $status = Count($fichier, $vue, $options, $couples, \@CommonCounters_list, 0);

  my %H_ErrorClass = ("1" => 0, "2" => 0, "3" => 0);

  # Iterate on each unit.
  # ----------------------------------------------------------------------------
  my ($unitViews, $unitName) = $cb_NextUnit->($vue); 
  while (defined $unitViews ) {

     # PRE TREATMENT
     # --------------
     
     $unitName = "$fichier"."::"."$unitName";
     print "Analyzing unit $unitName\n";

     # retrieves the common counters
     my $unitCounters = Couples::clone($couples);

     # Compute the number of lines (Nbr_Lines) based on the 'text' view (1 to force update).
     $status |= FileLines::CountFileLines(1,  $unitViews, $unitCounters);

     # modifies some counters
     Couples::counter_modify($unitCounters, 'Dat_FileName', $unitName);

     # TREATMENT : launch all counter computing
     # -----------------------------------------
     eval {
        $status |= Count($unitName, $unitViews, $options, $unitCounters, \@UnitCounters_list);
     };


     # POST TREATMENT
     # --------------

     # STEP 0 : exception treatment
     # -----------------------------
     if ($@) {
       # If fail is due to a timeout, don't catch and propagate the error to upper level.
       Timeout::DontCatchTimeout();

       # !!! Treatment for exception raised by process_file !!!!
       Timeout::DontCatchTimeout();   # propagate timeout errors
       print STDERR "[ERROR] undefined error when analysing unit $unitName : $@" ;
       $status = Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
     }


     # STEP 1 : Set default abort casue.
     # (analyse.pm, after tryCatchTimeout analyze ....)
     # -------------------------------------------------
     if (not exists $unitCounters->{Erreurs::MNEMO_ABORT_CAUSE})
     { 
       # By default, there is no abort cause.
       $status |= Erreurs::FatalError( Erreurs::ABORT_CAUSE_NONE, $unitCounters, undef);
     }

     # STEP 2 : produce chrono counter if needed.
     # FIXME : Note : N/A for units ??
     # --------------------------------------------------
     if (defined $options->{'--chrono'} )
     {
       $status |= Couples::counter_add($unitCounters, 'Dat_Chrono', 'N/A' );
     }

     # SETP 3 : check counters.
     # If the analysis has not ended with fatal error, check for missing
     # mnemonics ...
     # --------------------------------------------------------------------
     if (! Erreurs::isAborted($status)) {
       $status |= AnalyseUtil::checkMissingMnemonics($unitCounters);
     }

     # STEP 4 : Record result
     # -----------------------------------------------------------------
     AnalyseUtil::recordResults($unitCounters, $status, $options);


     # STEP 6 : memorize the class error for the final synthesis.
     # -----------------------------------------------------------
     my $errorClass = $unitCounters->counter_get_values()->{Erreurs::MNEMO_ABORT_CAUSE_CLASS};
#print "CLASS error = $errorClass\n";
     $H_ErrorClass{$errorClass}++;

     # get next unit
     ($unitViews, $unitName) = $cb_NextUnit->($vue);
  }

  # FINAL STEP :
  # Compute the resulting error class for the whole file.
  my $globalErrorClass = 0;
  if ( ($H_ErrorClass{'1'} == 0) &&
       ($H_ErrorClass{'2'} == 0) ) {
	# Not analyzed
        $globalErrorClass = 3;
  }
  elsif ( $H_ErrorClass{'2'} != 0) {
	# partialy analyzed
        $globalErrorClass = 2;
  }
  else {
	# OK
        $globalErrorClass = 1;
  }

  my $globalStatus = 0;

  # FIXME : if no error (none unit aborted) 
  #if () {
  #  $globalStatus |= Erreurs::setAbortCause( Erreurs::ABORT_CAUSE_NONE, $compteurs);
  #}
  #else {
  #$globalStatus |= Erreurs::setAbortCause( Erreurs::ABORT_CAUSE_ANALYSIS_UNIT_MODE, $couples, $globalErrorClass);
  Couples::counter_add($couples, 'Dat_UnitMode', 1);
  #}


}

sub Analyse($$$$$)
{
  my ($fichier, $vue, $options, $couples, $analyseur_callbacks) = @_;
  my ($Strip, $Parse, $Count, $r_TableFonctions, $status) = @{$analyseur_callbacks} ;

  if (! defined $status) {
    # if an initial status has not been specified (this is the case when the strip is
    # realized before calling this function), then init it to 0.
    $status = 0;
  }

  if ( defined $Strip ) {
    # If strip callback is not defined, we consider the strip has been realized
    # before calling this "Analyse" function.
    $status |= $Strip->($fichier, $vue, $options, $couples);
  }

  if ( Erreurs::isAborted($status) )
  {
    #print STDERR "$fichier : Echec de pre-traitement Strip\n";
    Erreurs::LogInternalTraces ('warning', undef, undef, 'abandon', 'Echec de pre-traitement Strip', '');
  }
  elsif ( defined $Parse) 
  {
    $status |= $Parse->($fichier, $vue, $options, $couples);
    if ( Erreurs::isAborted($status) )
    {
      #print STDERR "$fichier : Echec de pre-traitement Parse\n";
      Erreurs::LogInternalTraces ('warning', undef, undef, 'abandon', 'Echec de pre-traitement Parse', '');
    }
  }

  # Creation des fichiers de debug de vue de maniere inconditionnelle,          # dumpvues_filter_line
  # lorsque la fonctionnalite est utilisee.                                     # dumpvues_filter_line
  #if (($fichier ne AnaUtils::DUMMYFILENAME) and defined $options->{'--strip'})  # dumpvues_filter_line
  if ( defined $options->{'--strip'})  # dumpvues_filter_line
  {                                                                             # dumpvues_filter_line
    Vues::dump_vues ($fichier, $vue, $options);                                 # dumpvues_filter_line
  }                                                                             # dumpvues_filter_line

  if ( Erreurs::isAborted($status) )
  {
    return $status;
  }

  if (defined $options->{'--nocount'})
  {
    return $status;
  }

  #if ($status == 0)
  if (defined $Count)
  {
    $status |= $Count->($fichier, $vue, $options, $couples, $r_TableFonctions);
  }
  else
  {
    print STDERR "$fichier : Comptage non lances\n";
  }
  return $status ;
}




#-------------------------------------------------------------------------------
# DESCRIPTION:
# Fonction permettant de detecter automatiquement la liste des compteurs
# en lancant les fonctions de 'strip' et de comptages sur un buffer vide
#-------------------------------------------------------------------------------
#
# FIXME : this function is obsolete. Some remaining calls for techno Perl (non official) and Nsdk
#
#      ===> could be certainly removed !!
#
#--------------------------------------------------------------------------------
sub file_type_register ($$$$)
{
    my ($type, $options, $stripFunc, $countFunc) = @_;

    return 0 if (not defined $options->{'--o'});

    return 0 if (defined $options->{'--debug-no-vide-analysis'});                 # traces_filter_line

    if (not IsoscopeDataFile::csv_is_file_type_registered ($type))
    {
        # si le module principal (ou une invocation de la presente fonction)
        # n'a pas enregistre la liste des mnemoniques attendus dans le resultat au format CSV,
        # on lance la detection automatique de la liste maximale des compteurs calcules
        my $fichier = DUMMYFILENAME;
        my %vues;
        $vues{'bin'} = "\n";
        $vues{'text'} = "\n";

        my $compteurs = new Couples();
        $compteurs->{'Dat_Language'} = $type;

        print STDERR "Debut auto-detection de la liste des mnemoniques de comptages du type $type\n"; # traces_filter_line

          $stripFunc->($fichier, \%vues, $options, $compteurs);
          $countFunc->($fichier, \%vues, $options, $compteurs);

        print STDERR "Fin auto-detection de la liste des mnemoniques de comptages du type $type\n";   # traces_filter_line

        my @mnemos = sort (keys (%$compteurs));

        IsoscopeDataFile::csv_file_type_register ($type, \@mnemos);
    }

    return 0;
}


#-------------------------------------------------------------------------------
# DESCRIPTION:
# module de verification de coherences accolades/parentheses
# analyse rapidement si probleme d'accolades/parenthese a cause de directives
# de compilation
# l'analyse commence apres la premiere accolade ou la premiere parenthese
# afin d'eviter les eventuelles directives include dans des #ifdef
#-------------------------------------------------------------------------------
sub AnalyseAccoladesParenthesesRapide ($$$$)
{
    my ($fichier, $compteurs, $options, $c) = @_;

    my $base_filename = $fichier;
    $base_filename =~ s{.*/}{};

    my $status = 0;
    my $debug = 0; # traces_filter_line

    my $b_directive_preprocessing = 0;
    my $b_egalite_parenth_accolad = 0;

    # recherche si directive de compilation
    my $c_after = '';

    if ($c =~ /([()\{}].*$)/s)
    {
        $c_after = $1;
    }

    if ($c_after =~ /#/)
    {
        # il y a au moins une directive de compilation
        $b_directive_preprocessing = 1;
    }

    # recherche si egalite accolades et egalite parentheses
    my $nb_parenth_ouvre = () = $c_after =~ /\(/g;
    my $nb_parenth_ferme = () = $c_after =~ /\)/g;
    my $nb_accolad_ouvre = () = $c_after =~ /\{/g;
    my $nb_accolad_ferme = () = $c_after =~ /}/g;

    my $diff_parenth = abs($nb_parenth_ouvre - $nb_parenth_ferme);
    my $diff_accolad = abs($nb_accolad_ouvre - $nb_accolad_ferme);

    if (($diff_parenth == 0 ) && ($diff_accolad == 0))
    {
        $b_egalite_parenth_accolad = 1;
    }
    
    return ($b_egalite_parenth_accolad, $b_directive_preprocessing);
}


my %PEER = ('{' => '}', '(' => ')');

sub checkMatchingError($$) {
	my $closing = shift;
	my $r_stack = shift;
	
	my $opening;
	if (scalar @{$r_stack}) {
		$opening = $r_stack->[-1];
	}
	
	# offset 0 : type '(' or '}'
	# offset 1 : line
	# offset 2 : undef or macro name
	
	# return 0 means : no inconsistency
	# return 1 means : inconsistency
	
	# 1 - OPENING & CLOSING do not match ..
	if ((!defined $opening) || ($closing->[0] ne $PEER{$opening->[0]})) {
		
		# CLOSING INSIDE MACRO ?
		if (defined $closing->[2]) {
			if (defined $opening) {
				# the openning is in the same macro ?  
				if (defined $closing->[2]) {
					# macting inconsistency inside macro
					Lib::Log::WARNING("matching inconsistency inside macro $closing->[2] : openning '$opening->[0]' at line $opening->[1] is conflicting with closing $closing->[0] at line $closing->[1]");
					# remove opening
					pop @{$r_stack};
					# no inconsistency in a macro
					return 0;
				}
				else {
					# opening is in the code
					# no inconsistency beween macro and code
					Lib::Log::WARNING("matching inconsistency inside macro : unmatched $closing->[0] at line $closing->[1]");
					return 0;
				}
			}
			else {
				# unmatched inside macros.
				Lib::Log::WARNING("matching inconsistency inside macro $closing->[2] : unmatched $closing->[0] at line $closing->[1]");
				return 0;
			}
		}
	
		# CLOSING INSIDE CODE !
		elsif (defined $opening) {
			# matching inconsistency
			Lib::Log::ERROR("matching inconsistency : openning '$opening->[0]' at line $opening->[1] is conflicting with closing $closing->[0] at line $closing->[1]");
			# remove opening
			pop @{$r_stack};
			# return inconsistency
			return 1;
		}
		else {
			# unmatched
			Lib::Log::ERROR("matching inconsistency : unmatched $closing->[0] at line $closing->[1]");
			# return inconsistency
			return 1;
		}
	}
	
	# 2 - OPENING & CLOSING match
	else {
		if ( defined $closing->[2] && (! defined $opening->[2])) {
			# closing is in a macro and openning in the code, they can't match !!!
			# no inconsistency beween macro and code
			Lib::Log::WARNING("matching inconsistency inside macro : unmatched $closing->[0] at line $closing->[1]");
			return 0;
		}
		else {
			# match OK => remove opening from the stack.
			pop @{$r_stack};
			return 0;
		}
	}
	return 0;
}

#-------------------------------------------------------------------------------
# DESCRIPTION:
# verifie si probleme d'accolades/parenthese a cause de directives de compilation
#-------------------------------------------------------------------------------
sub VerifieCoherenceAccoladesParenthesesDirectActiveBuffer ($$$$)
{
    my ($fichier, $compteurs, $options, $c) = @_;

    my $base_filename = $fichier;
    $base_filename =~ s{.*/}{};

    my $status = 0;
    my $debug = 0;
    my $nb_incoherences = 0;

    my @arr_stack = ();
    my $line = 1;
    my $inside_macro = undef;;
    while (($nb_incoherences == 0)
           && ($c =~ /([()\{\}\n])/gs )
          )
    {
		if ($1 eq "\n") {
			$line++;
			if ($c =~ /\G(?=\s*#\s*define\s+(\w+))/gc) {
				$inside_macro = $1;
			}
			else {
				$inside_macro = undef;
				# check unmatched inside macro
				while ((scalar @arr_stack) && (defined $arr_stack[-1]->[2])) {
					my $opening = pop @arr_stack;
					Lib::Log::WARNING("matching inconsistency inside macro : unmatched $opening->[0] at line $opening->[1]");
				}
			}
		}
        elsif ($1 eq '{')
        {
            push(@arr_stack, ['{', $line, $inside_macro]);
        }
		elsif ($1 eq '(')
        {
            push(@arr_stack, ['(', $line, $inside_macro]);
        }
        else
        {
			$nb_incoherences += checkMatchingError([$1,$line,$inside_macro], \@arr_stack);
            
        }
    }

    # stack should be empty
    my $nb = @arr_stack;

    for(my $i=1; $i<=$nb; $i++)
    {
        $nb_incoherences++;
        my $item = pop(@arr_stack);
        Lib::Log::ERROR("accolade parenthese inconsistency : unmatched openning '$item->[0]' at ligne $item->[1]");
    }
    
    return $nb_incoherences;
}

#---------------------------------------------------------------------------------------------------------
#                                   CHARGEMENT AUTOMATIQUE DE CONF
#---------------------------------------------------------------------------------------------------------

sub get_Comptages($$$) {
  my $ConfMod = shift;
  my $getter = shift;
  my $options = shift;

  my $status = 0;

  my $f_get_table_Comptages =  \&{"${ConfMod}::${getter}"} ;

  #my $r_table_Comptages = \@{"${ConfMode}::table_Comptages"} ;
  my $r_table_Comptages = $f_get_table_Comptages->();

  my $nb_comptages = scalar @{$r_table_Comptages};

  #my $nb_comptages = scalar @{eval("${ConfMod}::table_Comptages")};
  #my $nb_comptages = scalar @CS_Conftable_Comptages;
  my @TableMnemos = () ;
  my @TableFonctions = () ;
  my %H_Fonctions = ();
  my %H_CallParam = ();
  my %H_Modules = ();
  my %H_Selection = ();

  # Pour chaque ligne de comptage de la table
  for (my $i=0; $i < $nb_comptages; $i++) {

Traces::debug (1, 'Read_ConfAnalyse:' .  $r_table_Comptages->[$i]->[0] );

    my $selection = $r_table_Comptages->[$i]->[5];

    # Si le comptage est marque comme selectionne
    if ( ($selection != 0) || (defined $options->{'--force-all-counters'}) ) {

                # **** lecture de la mnemonique ****
        push (@TableMnemos, $r_table_Comptages->[$i]->[0]) ;

                # **** lecture du nom complet de la fonction associee ****
      my $fonction = $r_table_Comptages->[$i]->[2].'::'.$r_table_Comptages->[$i]->[1] ;

                # **** lecture des modules ****
      $H_Modules{$r_table_Comptages->[$i]->[2]} = 1;

                # **** lecture du pointeur de fonction ***
      my $fonction_ptr = $r_table_Comptages->[$i]->[3];
      $H_Fonctions{$fonction} = $fonction_ptr;
                # **** lecture du parametre d'appel ***
      $H_CallParam{$fonction} = $r_table_Comptages->[$i]->[4];
                # **** memorize the selection type ***
      $H_Selection{$fonction} = $selection;
    }
  }
  # Chargement des modules
  foreach my $module (keys %H_Modules) {
    $module =~ s/::/\//g ;
    eval
    {
      my $packmodule = $module.".pm";
      require $packmodule;
    };
    if ($@)
    {
      Timeout::DontCatchTimeout();   # propagate timeout errors
      print STDERR 'Module non disponible: '. $module . ' : ' . $@ . "\n" ;
      Erreurs::LogInternalTraces ('error', undef, undef, 'Module non disponible:', $module, $@) ;
      $status |= Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS ;
    }
  }

  # Tri des mnemoniques.
  @TableMnemos = sort @TableMnemos;

  # Contruction d'une table d'appel : [ &ptr_fct , nom_fonction, parameters, selection type ]
  foreach my $fct (keys %H_Fonctions) {
    push (@TableFonctions, [ $H_Fonctions{$fct}, $fct, $H_CallParam{$fct}, $H_Selection{$fct} ]);
  }
  return (\@TableMnemos, \@TableFonctions, $status);
}

sub Read_ConfAnalyse ($$) {

  my ($ConfMod, $options) = @_ ;
  my $status = 0;

  my $packConfMod = $ConfMod.".pm" ;
  require $packConfMod;

  my @TableMnemos = () ;
  my @TableFonctions = () ;

  my ($r_TableMnemos, $r_TableFonctions, $ret) = get_Comptages($ConfMod, "get_table_Comptages", $options);
  $status |= $ret;

  push @TableMnemos, @$r_TableMnemos;
  push @TableFonctions, @$r_TableFonctions;

  ($r_TableMnemos, $r_TableFonctions, $ret) = get_Comptages($ConfMod, "get_table_Synth_Comptages", $options);
  $status |= $ret;

  push @TableMnemos, @$r_TableMnemos;
  push @TableFonctions, @$r_TableFonctions;


  return (\@TableMnemos, \@TableFonctions, $status);
}

sub load_ready {
  return 1;
}


1;

