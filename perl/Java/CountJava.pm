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

package Java::CountJava;
use strict;
use warnings;

use Carp::Assert; # Erreurs::LogInternalTraces
use Erreurs;
use Couples;
use TraceDetect;


# prototypes
sub CountKeywords($$$);
sub CountStarImport($$$$);
sub CountOutOfFinallyJumps($$$$);
sub CountIllegalThrows($$$$);

# compte le nombre d'expressions regulieres
# en etant sensitif a la casse.
sub count_re($$)
{
    my ($sca, $re) = @_ ;
    my $n;
    $n = () = $sca =~ /$re/smg ;
    return $n;
}


# Comptage generique d'expressions rationnelles
sub GenericReCount($$$$)
{
    my ($buffer, $re, $couples, $mnemo) = @_;
    my $status = 0;
    my $n = count_re ($buffer, $re); # comptage des lettres ASCII
    $status |= Couples::counter_add($couples, $mnemo, $n );
    return $status;
}


#-------------------------------------------------------------------------------
# Module de comptage des instructions continue, goto, exit.
#-------------------------------------------------------------------------------

sub CountKeywords($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;


  $ret |= CountItem('import', Ident::Alias_Import(), $vue, $compteurs);
  $ret |= CountItem('if', Ident::Alias_If(), $vue, $compteurs);
  $ret |= CountItem('else', Ident::Alias_Else(), $vue, $compteurs);
  $ret |= CountItem('while', Ident::Alias_While(), $vue, $compteurs);
  $ret |= CountItem('for', Ident::Alias_For(), $vue, $compteurs);
  $ret |= CountItem('continue', Ident::Alias_Continue(), $vue, $compteurs);
  $ret |= CountItem('switch', Ident::Alias_Switch(), $vue, $compteurs);
  $ret |= CountItem('default', Ident::Alias_Default(), $vue, $compteurs);
  $ret |= CountItem('try', Ident::Alias_Try(), $vue, $compteurs);
  $ret |= CountItem('catch', Ident::Alias_Catch(), $vue, $compteurs);
  $ret |= CountItem('System.exit', Ident::Alias_Exit(), $vue, $compteurs);
  $ret |= CountItem('instanceof', Ident::Alias_Instanceof(), $vue, $compteurs);
  $ret |= CountItem('case', Ident::Alias_Case(), $vue, $compteurs);
  $ret |= CountItem('\bDateUtils\.truncate\b', Ident::Alias_DateUtilsTruncate(), $vue, $compteurs);
  
  return $ret;
}


sub CountItem($$$$) {
  my ($item, $id, $vue, $compteurs) = @_ ;
  my $ret = 0;

  if ( ! defined $vue->{'code'} ) {
    $ret |= Couples::counter_add($compteurs, $id, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nb = () = $vue->{'code'} =~ /\b${item}\b/sg ;
  $ret |= Couples::counter_add($compteurs, $id, $nb);

  return $ret;
}

sub CountAutodocTags ($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  my $nb_ParamTags=0;
  my $nb_SeeTags=0;
  my $nb_ReturnTags=0;

  if ( ! defined $vue->{comment} ) {
    $ret |= Couples::counter_add($compteurs, Ident::Alias_ParamTags(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_SeeTags(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_ReturnTags(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  $nb_ParamTags = () = $vue->{comment} =~ /@[Pp]aram\b/g;
  $nb_SeeTags = () = $vue->{comment} =~ /@[Ss]ee\b/g;
  $nb_ReturnTags = () = $vue->{comment} =~ /@[Rr]eturn\b/g;

  $ret |= Couples::counter_add($compteurs, Ident::Alias_ParamTags(), $nb_ParamTags );
  $ret |= Couples::counter_add($compteurs, Ident::Alias_SeeTags(), $nb_SeeTags );
  $ret |= Couples::counter_add($compteurs, Ident::Alias_ReturnTags(), $nb_ReturnTags );

  return $ret;
}


sub CountBugPatterns ($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  my $nb_BugPatterns=0;
  my $code = '';

  if ( (exists $vue->{'prepro'}) && ( defined $vue->{'prepro'} ) ) {
    $code = $vue->{'prepro'};
  }
  else {
    $code = $vue->{'code'};
  }

  if ( ! defined $code ) {
    $ret |= Couples::counter_add($compteurs, Ident::Alias_BugPatterns(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  # Recherche des patterns d'instruction de controle suivants :
  #----------------------------------------------------------
  # while(xxx);
  # for(xxx);
  # if(xxx);

  # Suppression des imbrications de parentheses associees au mots-cles if/for/while, afin de virer l'expression conditionnelle qui se trouve entre le mot cle structurel et le debut de bloc
  # qui est cense commencer par une accolade.
  while ( $code =~ s/\b((?:if|for|while)\s*\([^\)]*)(\([^\(\)]*\))/$1 _X_ /sg ) {
    #print "1 -- $1\n";
    #print "2 -- $2\n";
  }

  # Comptage des instructions de controles dont la parenthese fermente est suivie d'un caractere ';'
  $nb_BugPatterns += $code =~ s/\b(if|for|while)\s*\([^\(\)]*\)\s*;/ ;/sg ;

  # Decomptage du nombre d'instruction 'do', celles-ci etant systematiquement associees a un 'while(xxx);' qui ne pose pas de probleme dans ce cas..
  $nb_BugPatterns -= $code =~ s/\b(do)\b/ /sg ;

  # Pour la suite, suppression des structure de controle restantes (celles qui n'ont pas un ';' derriere la parenthese fermante ...:
  $code =~ s/\b(if|for|while)\s*\([^\(\)]*\)/ ;/sg ;

#print STDERR "[BugPattern]  <cond_struct> (xxx); ==> $nb_BugPatterns occurrences trouvées\n";
  Erreurs::LogInternalTraces('TRACE', $fichier, 1, 'BugPattern', '<cond_struct> (xxx);', "--> $nb_BugPatterns occurrences trouvées");

  # Recherche du pattern d'instruction *a++, et plus generalement    * ...... ;, lorsqu'il n'y a pas de '=' ni d'appel de fonction dans les '...'
  #----------------------------------------------------------------------------------------------------------------------------------------------
  # Finir d'applatir les parentheses des expressions jusqu'à n'avoir qu'un seul niveau.
  # RQ: lorsque qu'une parenthese contient les caracteres {, } ou ; on en deduit que c'est un jeu de parenthses qui contient du code. Ce niveau de
  # parenthses est donc ignore (i.e. on ne l'aplatie pas).
  while ( $code =~ s/(\([^\(\)\{\}\;]*)(\([^\(\)\{\}\;]*\))/$1 _X_ /sg ) {}

  # Les parentheses de controles ont ete supprimes auparavant.
  # Il n'existe partout plus qu'un seul niveau de parenthses.
  $code =~ s/;/;;/sg ;
  while ( $code =~ /[\}{;]\s*\*([^=;]*);/sg ) {
    my $instr = $1;
    if ( $instr !~ /(\.|->)\s*\w+\s*\([^\)]*\)/s ) {
      # Si l'expression ne correspond pas a un appel de methode, alors c'est un bug-pattern.
      $nb_BugPatterns++;
#print STDERR "[BugPattern]  * ... ; ==> occurrence trouvee\n";
      Erreurs::LogInternalTraces('TRACE', $fichier, 1, 'BugPattern', '* ... ;', "--> $instr");
    }
  }

  # Finir d'applatir toutes les parentheses ... sauf celles dont la fermente est suivie d'un ';', signe que les parentheses enferment une instruction.
#  while ( $code =~ s/\([^\(\)]*\)\s*[^;\s]//sg ) {}


  # Recherche du pattern d'instruction 'a = a ;'
  #-----------------------------------------------
  while ( $code =~ /[\}{;\)]\s*([^;=]*=[^;]*)/sg ) {
    my $instr = $1;
    $instr =~ s/[ \t]//g ;
    my ($lvalue, $rvalue) = $instr =~ /([^=]*)=(.*)/s ;
    if ($lvalue eq $rvalue) {
      $nb_BugPatterns++;
#print STDERR "[BugPattern]  a = a ; ==> occurrence trouvee\n";
      Erreurs::LogInternalTraces('TRACE', $fichier, 1, 'BugPattern', 'a = a', "--> $instr");
    }
  }


  # Recherche du pattern d'instruction 'a == b ;'
  #---------------------------------------------
  # supprimer tout les patterns '= ...== ... ;' pour filtrer les affectations de resultats de tests d'egalites ....
  $code =~ s/=[^;=]*==[^;]*//g;

  # supprimer tout les patterns '== ... ?' pour filtrer les tests d'egalite dans les operateurs ternaires ....
  $code =~ s/==([^\?:;]*\?)/$1/g;

  # supprimer tout les patterns 'return ... ;' pour filtrer les fausses alertes 'return ... == ... ;'
  $code =~ s/\n\s*(return|assert)[^;]*//g;

  # CALCUL : Compter les '=='.
  my $nb = () = $code =~ /==/g ;
  $nb_BugPatterns += $nb ;

#print STDERR "[BugPattern]  a == b ; ==> $nb occurrences trouvees\n";
  Erreurs::LogInternalTraces('TRACE', $fichier, 1, 'BugPattern', 'a == b', "--> $nb_BugPatterns occurrences trouvees.");

  $ret |= Couples::counter_add($compteurs, Ident::Alias_BugPatterns(), $nb_BugPatterns);

  return $ret;
}

sub CountRiskyFunctionCalls ($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  my $nb_RiskyFunctionCalls=0;
  #$nb_RiskyFunctionCalls= () = $vue->{code} =~ /(\bSystem\.gc\s*\(|\b(System|Runtime)\.runFinalizersOnExit\()/sg;

  if ( ! defined $vue->{code} ) {
    $ret |= Couples::counter_add($compteurs, Ident::Alias_RiskyFunctionCalls(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  while ( $vue->{code} =~ /(\bSystem\.gc\s*\(|\b(System|Runtime)\.runFinalizersOnExit\()/sg ) {
    $nb_RiskyFunctionCalls++;
  }

  $ret |= Couples::counter_add($compteurs, Ident::Alias_RiskyFunctionCalls(), $nb_RiskyFunctionCalls);
  return $ret;
}


#-------------------------------------------------------------------------------
# Module de comptage du nombre de d'import etoile
#-------------------------------------------------------------------------------
sub CountStarImport($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # Erreurs::LogInternalTraces
    my $base_filename = $fichier if ($b_TraceDetect); # Erreurs::LogInternalTraces
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # Erreurs::LogInternalTraces
    #
    my $status = 0;
    my $debug = 0; # Erreurs::LogInternalTraces
    #    
    my $trace_detect = ''; # Erreurs::LogInternalTraces
    my $n = 0;
    my $mnemo = Ident::Alias_StarImport();
    #
    my $c = $vue->{'code'}; # code
    #
    while ($c =~ m{
                    (\simport\s+.*?\.\s*\*\s*;)
		}gxms)
    {
        my $match = $1;
        $n++;
        $match =~ s/\n//g;
        my $line_number = TraceDetect::CalcLineMatch($c, pos($c)) if ($b_TraceDetect); # Erreurs::LogInternalTraces
        $trace_detect .= "$base_filename:$line_number:$match\n" if($b_TraceDetect); # Erreurs::LogInternalTraces
    }
    #
    print STDERR "$mnemo = $n \n" if ($debug); # Erreurs::LogInternalTraces
    TraceDetect::DumpTraceDetect($fichier, $mnemo, $trace_detect, $options) if ($b_TraceDetect); # Erreurs::LogInternalTraces
    $status |= Couples::counter_add($couples, $mnemo , $n );
    #
    return $status;
}

#-------------------------------------------------------------------------------
# Module de comptage du nombre de throws illegaux
#-------------------------------------------------------------------------------
sub CountIllegalThrows($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # Erreurs::LogInternalTraces
    my $base_filename = $fichier if ($b_TraceDetect); # Erreurs::LogInternalTraces
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # Erreurs::LogInternalTraces
    #
    my $status = 0;
    my $debug = 0; # Erreurs::LogInternalTraces
    #    
    my $trace_detect = ''; # Erreurs::LogInternalTraces
    my $n = 0;
    my $mnemo = Ident::Alias_IllegalThrows();
    #
    my $c = $vue->{'code'}; # code
    #
    while ($c =~ m{
                    (
                            \sthrow\s+new\s+(java\.lang\.)?Error\s*\(
                        |   \sthrow\s+new\s+(java\.lang\.)?RuntimeException\s*\(
                    )    
		}gxms)
    {
        my $match = $1;
        $n++;
        my $line_number = TraceDetect::CalcLineMatch($c, pos($c)) if ($b_TraceDetect); # Erreurs::LogInternalTraces
        $trace_detect .= "$base_filename:$line_number:$match\n" if($b_TraceDetect); # Erreurs::LogInternalTraces
    }
    #
    print STDERR "$mnemo = $n \n" if ($debug); # Erreurs::LogInternalTraces
    TraceDetect::DumpTraceDetect($fichier, $mnemo, $trace_detect, $options) if ($b_TraceDetect); # Erreurs::LogInternalTraces
    $status |= Couples::counter_add($couples, $mnemo , $n );
    #
    return $status;
}


#-------------------------------------------------------------------------------
# Module de comptage du nombre de sauts dans les clauses finally
#-------------------------------------------------------------------------------
# principe :
#   dans un finally :
#       -dans tous les cas detecter return ou throw
#       -ignorer les continue et break dans les boucles
#       -ignorer les break dans les switch
sub CountOutOfFinallyJumps($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # Erreurs::LogInternalTraces
    my $b_assert = (exists $options->{'--TraceDetect'}? 1 :0); # Erreurs::LogInternalTraces
    my $b_TraceInconsistent = (exists $options->{'--TraceInconsistent'}? 1 :0); # Erreurs::LogInternalTraces
    my $base_filename = $fichier if ($b_TraceDetect); # Erreurs::LogInternalTraces
    $base_filename =~ s{.*/}{} if ($b_TraceDetect); # Erreurs::LogInternalTraces
    #
    my $status = 0;
    my $debug = 0; # Erreurs::LogInternalTraces
    #    
    my $trace_detect = ''; # Erreurs::LogInternalTraces
    my $n = 0;
    my $mnemo = Ident::Alias_OutOfFinallyJumps();
    #
    if (!defined $vue->{'code'})
    {
	assert(defined $vue->{'code'}) if ($b_assert); # Erreurs::LogInternalTraces
	$status |= Couples::counter_add($couples, $mnemo , Erreurs::COMPTEUR_ERREUR_VALUE);
	$status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	return $status;
    }
    my $c = $vue->{'code'}; 
    #
    my @arr_match_pos_start;
    my $b_stack_size_error = 0;
    while ($c =~ m{
                        (\sfinally\s*?\{)
                    |   (\sswitch[\s\(].*?\{)
                    |   (\swhile[\s\(].*?([\{;]))
                    |   (\sfor[\s\(].*?\{)
                    |   (\sdo[\s]*?\{)
                    |   ([\{])
                    |   ([\}])
                    |   (\sreturn[\s;] | \sthrow\s)
                    |   (\sbreak[\s;])
                    |   (\scontinue[\s;])
		}gxms)
    {
        my $match_finally = $1;
        #
        my $match_switch = $2;
        #
        my $match_while = $3;
        my $match_while_end_symb = $4;
        #
        my $match_for = $5;
        #
        my $match_do = $6;
        #
        my $match_start_accolade = $7;
        #
        my $match_end_accolade = $8;
        #
        my $match_return_throw = $9;
        #
        my $match_break = $10;
        #
        my $match_continue = $11;
        #
        my $pos_c = pos($c);
        my $line_number = TraceDetect::CalcLineMatch($c, $pos_c) if ($b_TraceDetect); # Erreurs::LogInternalTraces
        print STDERR "###line_number:$line_number\n" if ($debug); # Erreurs::LogInternalTraces
        #
        if (defined $match_finally)
        {
            my $value = 'finally:'.$pos_c;
            push(@arr_match_pos_start, $value);
            print STDERR "==>match class with $match_finally at $pos_c\n" if ($debug); # Erreurs::LogInternalTraces
        }
        elsif (defined $match_switch)
        {
            my $value = 'switch:'.$pos_c;
            push(@arr_match_pos_start, $value);
            print STDERR "==>match switch with $match_switch at $pos_c\n" if ($debug); # Erreurs::LogInternalTraces
        }
        elsif (defined $match_while)
        {
            # filtre implicitement ';' pour do { ... } while (...) ;
            if ($match_while_end_symb eq '{')
            {
                my $value = 'boucle:'.$pos_c;
                push(@arr_match_pos_start, $value);
                print STDERR "==>match boucle with $match_while at $pos_c\n" if ($debug); # Erreurs::LogInternalTraces
            }
        }
        elsif (defined $match_for)
        {
            my $value = 'boucle:'.$pos_c;
            push(@arr_match_pos_start, $value);
            print STDERR "==>match boucle with $match_for at $pos_c\n" if ($debug); # Erreurs::LogInternalTraces
        }
        elsif (defined $match_do)
        {
            my $value = 'boucle:'.$pos_c;
            push(@arr_match_pos_start, $value);
            print STDERR "==>match boucle with $match_do at $pos_c\n" if ($debug); # Erreurs::LogInternalTraces
        }
        elsif (defined $match_start_accolade)
        {
            my $value = 'startaccolade:'.$pos_c;
            push(@arr_match_pos_start, $value);
            print STDERR "==>match start_accolade with $match_start_accolade at $pos_c\n" if ($debug); # Erreurs::LogInternalTraces
        }
        elsif (defined $match_end_accolade)
        {
            print STDERR "==>match end_accolade with $match_end_accolade at $pos_c\n" if ($debug); # Erreurs::LogInternalTraces
            my $nb = @arr_match_pos_start;
            if ($nb <= 0)
            {
                $b_stack_size_error = 1;
                print STDERR "pile vide 1\n" if ($b_TraceInconsistent); # Erreurs::LogInternalTraces
                assert($nb>0, 'pile vide 1') if ($b_assert); # Erreurs::LogInternalTraces
                last;
            }
            my $value = pop(@arr_match_pos_start);
        }
        elsif (defined $match_return_throw)
        {
            print STDERR "==>match match_return_throw with $match_return_throw at $pos_c\n" if ($debug); # Erreurs::LogInternalTraces
            # verifie si dans finally
            my $liste = join(';', @arr_match_pos_start);
            if ($liste =~ /\bfinally\b/)
            {
                $n++;
                $match_return_throw =~ s/\s//g;
                $trace_detect .= "$base_filename:$line_number:$match_return_throw\n" if($b_TraceDetect); # Erreurs::LogInternalTraces
            }
        }
        elsif (defined $match_break)
        {
            print STDERR "==>match match_break with $match_break at $pos_c\n" if ($debug); # Erreurs::LogInternalTraces
            my $nb = @arr_match_pos_start;
            # verifie si dans finally
            my $liste = join(';', @arr_match_pos_start);
            if ($liste =~ /\bfinally\b/)
            {
                # verifie si dans switch+startaccolade* : ignore
                # verifie si dans boucle+startaccolade* : ignore
                my $found_other = 0;
                for(my $i = $nb-1; $i>=0; $i--)
                {
                    my $current = $arr_match_pos_start[$i];
                    if ($current =~ /\bstartaccolade\b/)
                    {
                        next; # ignore mais continue
                    }
                    elsif ($current =~ /\bswitch\b/)
                    {
                        last; # c'est autorise no pb
                    }
                    elsif ($current =~ /\bboucle\b/)
                    {
                        last; # c'est autorise no pb
                    }
                    else
                    {   # violation
                        $found_other = 1;
                        last;
                    }
                }
                if ($found_other == 1)
                {
                    $n++;
                    $match_break =~ s/\s//g;
                    $trace_detect .= "$base_filename:$line_number:$match_break\n" if($b_TraceDetect); # Erreurs::LogInternalTraces
                    #print STDERR "###trace_detect=$trace_detect"; # Erreurs::LogInternalTraces
                }
            }
        }
        elsif (defined $match_continue)
        {
            print STDERR "==>match match_continue with $match_continue at $pos_c\n" if ($debug); # Erreurs::LogInternalTraces
            my $nb = @arr_match_pos_start;
            # verifie si dans finally
            my $liste = join(';', @arr_match_pos_start);
            if ($liste =~ /\bfinally\b/)
            {
                # verifie si dans boucle+startaccolade* : ignore
                my $found_other = 0;
                for(my $i = $nb-1; $i>=0; $i--)
                {
                    my $current = $arr_match_pos_start[$i];
                    if ($current =~ /\bstartaccolade\b/)
                    {
                        next; # ignore mais continue
                    }
                    elsif ($current =~ /\bboucle\b/)
                    {
                        last; # c'est autorise no pb
                    }
                    else
                    {   # violation
                        $found_other = 1;
                        last;
                    }
                }
                if ($found_other == 1)
                {
                    $n++;
                    $match_continue =~ s/\s//g;
                    $trace_detect .= "$base_filename:$line_number:$match_continue\n" if($b_TraceDetect); # Erreurs::LogInternalTraces
                }
            }
        }
    }
    if ($b_stack_size_error)
    {
        $n = Erreurs::COMPTEUR_ERREUR_VALUE;
        $status |= Erreurs::COMPTEUR_STATUS_PB_COHERENCES_ACCOLADES_PARENTHESES;
    }
    #
    print STDERR "$mnemo = $n \n" if ($debug); # Erreurs::LogInternalTraces
    TraceDetect::DumpTraceDetect($fichier, $mnemo, $trace_detect, $options) if ($b_TraceDetect); # Erreurs::LogInternalTraces
    $status |= Couples::counter_add($couples, $mnemo , $n );
    #
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

# 24/01/2018 HL-437 : DIAG : Avoid using contructors of primitive type wrapper
sub CountPrimitiveClassConstructor($$$)
{
    my $ret = 0;
    my $nb_PrimitiveTypeWrapperInstanciation = 0;
    my $PrimitiveTypeWrapperInstanciation__mnemo = Ident::Alias_PrimitiveTypeWrapperInstanciation();
    my ($fichier, $vue, $compteurs) = @_;
   
    if ( ! defined $vue->{'code'} ) {
        $ret |= Couples::counter_add($compteurs, $PrimitiveTypeWrapperInstanciation__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
    else 
    {
        $nb_PrimitiveTypeWrapperInstanciation = () = $vue->{'code'} =~ /\bnew\s*(?:Boolean|Byte|Character|Double|Float|Integer|Long|Short|String)\s*\(/g ;
    }

    $ret |= Couples::counter_add($compteurs, $PrimitiveTypeWrapperInstanciation__mnemo, $nb_PrimitiveTypeWrapperInstanciation);
    return $ret;
}


1;
