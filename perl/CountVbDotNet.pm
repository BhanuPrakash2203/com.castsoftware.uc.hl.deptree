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
#
# Description: Composant de mesure de source VB, pour creation d'alertes

package CountVbDotNet;
use strict;
use warnings;

use Ident;

use Couples ;
use CountVbUtils ;
#use CountVbInstructionPatterns;
use VBKeepCode ;
use Timeout;





# compte le nombre de case else
sub count_case_else($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\bcase\s\s*else\b/smgo ;
    return $n;
}

# compte le nombre de select case
sub count_select_case($)
{
    my ($sca) = @_ ;
    # on compte les 'end' 'select' car le 'case' est facultatif
    my $n = () = $sca =~ /\bend\s\s*select\b/smgo ;
    return $n;
}

# compte le nombre de conditions
# compte le nombre de # IF?
sub count_if($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\b(then)\b/smg ;
    return $n;
}

# compte le nombre de continue
sub count_continue($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\b(continue)\b/smg ;
    return $n;
}

# compte le nombre de goto
sub count_goto($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\b(goto)\b/smg ;
    return $n;
}

# compte le nombre de gosub
sub count_gosub($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\b(gosub)\b/smg ;
    return $n;
}

# compte le nombre de exit
sub count_exit($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\b(exit)\b/smg ;
    return $n;
}

# compte le nombre de typeof
sub count_typeof($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\b(typeof)\b/smg ;
    return $n;
}


# compte le nombre de boucle de type while
sub count_while($)
{
    my ($sca) = @_ ;
# compter les 'end while' revient a compter les boucles de type 'while'
    my $n = () = $sca =~ /\b(end\s\s*while)\b/smg ;
    return $n;
}

# compte le nombre de boucle de type loop
sub count_loop($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\b(loop)\b/smg ;
    return $n;
}

# compte le nombre de # Else?
sub count_else($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\b(else)\b/smg ;
# TBC: AD: performances?
    my $nce = () = $sca =~ /\bcase\s\s*else\b/smg ;
    return $n - $nce;
}

# compte le nombre de # Elseif
sub count_elseif($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\b(elseif)\b/smg ;
    return $n ;
}

# compte le nombre de mots clefs en commentaire
# Incident 128: ce devrait etre des lignes
sub count_code_in_comments($)
{
    my ($sca) = @_ ;
    my $n =0;
    my $nb_lignes =0;
    # FIXME: les parentheses ne sont pas super discriminantes, alors qu'elles semblent tres utiles.
    while ( $sca =~ /([^\n]*)\n/g )
    {
      my $ligne = $1;
      $n = 0;
      $n += 0.47 *  CountVbUtils::count_re_i($ligne, '\'\s*\b(?:function|sub|public|private|protected|for|while|until|do|loop|case|next|dim|get|end|set)\b' );
      $n += 0.05 * CountVbUtils::count_re_i($ligne, '\b(?:then)\b' );
      $n += 0.25 * CountVbUtils::count_re  ($ligne, '(?:=|;|\.[^\s.]|\(|\))' );
      if ( $n > 0.51 )
      {
        $nb_lignes ++;
      }
    }
    return $nb_lignes;
}

# compte le nombre de lignes logiques d'instructions
sub count_LogicalLinesOfCode($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /^\s*[^\s_]/smgo ;
    return $n;
}

# compte les literaux numeriques ne correspondant pas a des symboles
sub count_literaux_numeriques_sans_symbole($)
{
    my ($sca) = @_ ;
    my $buffer_sans_symbole = $sca;
    $buffer_sans_symbole =~ s/^[^\n]*\bconst\b[^\n]*//smgo ;
    my $n = () = $buffer_sans_symbole =~ /'^\p{IsAlpha}[0-9.e+-]+/smgo ;
    return $n;
}

# compte les literaux numeriques composes d'au moins deux chiffres
sub count_two_digits_numbers($)
{
    my ($sca) = @_ ;
#    my $n = () = $sca =~ /^\p{IsAlpha}[0-9.e+-][0-9.e+-]+/smgo ;
      # Suppression des #define <id> <value>.

    # Concatenation lignes d'une instruction multiligne.
    $sca =~ s/\s_[ \t]*\n//sg ;

    # Suppression des declarations "const" ou "final" (en java)
    $sca =~ s/([\n]|[:][^=])    # Commence par \n ou : (sauf :=)
               [^;\n:]*             # Tout sauf fin d'instruction, fin de ligne ou separateur d'instructions.
               \bconst\b         # Mot cle const.
               ([^\n:]|:=)*//ixsg; # Suppression juqu'à fin de ligne

    # Suppression des magic numbers toleres.
    $sca =~ s/([^\w])[01]?\.0?[^\w]/$1---/sg; # 0.0, 1.0, 0. 1. .0

    my $nb_MagicNumbers = 0;

    # reconnaissance des magic numbers :
    # 1) identifiants commencant forcement par un chiffre decimal.
    # 2) peut contenir des "." (flottants)
    # 3) peut contenir des "E" ou "e" suivis eventuellement de "+/-" pour les flottants
    while ( $sca =~ /[^\w]((\d|\.\d)([Ee][+-]?\d|[\w\.])*)/sg )
    {
      my $number = $1 ;
      # suppression du 0 si le nombre commence par 0.
      $number =~ s/^0*(.)/$1/;
      # Si la donnee trouvee n'est pas un simple chiffre, alors ce n'est pas un magic number tolere ...
      if ($number !~ /^\d$/ ) {
        #print "magic = >$number<\n";
        $nb_MagicNumbers++;
      }
    };

    return $nb_MagicNumbers;
}


# utilise strict on
sub detect_using_option_strict_on($)
{
    my ($sca) = @_ ;
    my $n =0;
    my $re = '^\s*option\s\s*strict\s\s*on\b' ;
    #while ( $sca =~ m/(^\s*\n|^\s*option\b)/smgi )
    $sca =~ m/((?:^\s*\n|^\s*option\b[^\n]*\n)*)/smgo ;
    {
        if ($1 =~ m/$re/smgi)
        {
            $n ++;
        }
    }
    return $n;
}

# utilise explicit on
sub detect_using_option_explicit_on($)
{
    my ($sca) = @_ ;
    my $n =0;
    my $re = '^\s*option\s\s*explicit\s\s*on\b' ;
    $sca =~ m/((?:^\s*\n|^\s*option\b[^\n]*\n)*)/smgo ;
    {
        if ($1 =~ m/$re/smgio)
        {
            $n ++;
        }
    }
    return $n;
}

# compte le nombre d'instructions next
sub count_next($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\bnext\b/smg ;
    return $n;
}

# compte le nombre d'instructions next vide
sub count_next_empty($)
{
    my ($sca) = @_ ;
    my $n = () = $sca =~ /\bnext\b\s*(?:|\n)/smg ;
    return $n;
}



# compte le nombre de mauvais commentaires
sub count_bad_comments($)
{
    my ($sca) = @_ ;
    my $n =  CountVbUtils::count_re_i($sca, '(?:\!\!\!|\?\?\?|[A\x{00e0}a]\s+(?:v[\x{00e9}e]rifier|faire|voir|revoir)|\b(?:TODO|FIXME|TBC|TBD|Attention)\b)' );
    return $n;
}

# compte le nombre de bug pattern
sub count_bug_patternTrace($)
{
    my ($sca) = @_ ;

    $sca =~ s/:=/ affectation /g ;
    $sca =~ s/\b(or|orelse|and|andelse|then|else)\b/,/g ;

    my $labelPattern = '^\s*\w+\s*:' ;

    # if ( $sca =~ /($labelPattern)/sm )
    # {
    #    Erreurs::LogInternalTraces ('trace', undef, undef, Ident::Alias_BugPatterns(), $1, '') ;
    # }

    $sca =~ s/($labelPattern)/ \nlabel /smg ;

    my $pattern1 = ':\s*\n|^\s*:|:\s*:' ; # instruction vide
    my $pattern2 = '=[^\n:,]*=' ;         # Affectation d'un test d'egalite
    my $pattern = '(?:' . $pattern1 . ')|(' .$pattern2 . ')' ;

    my $n=0;

    while ( $sca =~ /($pattern)/smg )
    {
      Erreurs::LogInternalTraces ('trace', undef, undef, Ident::Alias_BugPatterns(), $1, '') ;
      $n=$n+1;
    }

    return $n;
}

sub count_bug_pattern($)
{
    my ($sca) = @_ ;

    $sca =~ s/:=/ affectation /g ;
    $sca =~ s/\b(or|orelse|and|andelse|then|else)\n/,/g ;

    my $labelPattern = '^\s*\w+\s*:' ;

    $sca =~ s/($labelPattern)/ \nlabel /smg ;

    my $pattern1 = ':\s*\n|^\s*:|:\s*:' ; # instruction vide
    my $pattern2 = '=[^\n:,]*=' ;         # Affectation d'un test d'egalite
    my $pattern = '(?:' . $pattern1 . ')|(' .$pattern2 . ')' ;

    my $n =  CountVbUtils::count_re($sca, $pattern );

    return $n;
}

# compte le nombre de try
sub count_try($)
{
    my ($sca) = @_ ;
    my $n =  CountVbUtils::count_re($sca, '\bend\s+try\b' );
    return $n;
}


# compte le nombre de catch
sub count_catch($)
{
    my ($sca) = @_ ;
    my $n =  CountVbUtils::count_re($sca, '\bcatch\b' );
    return $n;
}

# compte le nombre de catch vide
sub count_catch_vide($)
{
    my ($sca) = @_ ;
    my $n =  CountVbUtils::count_re($sca, '\bcatch\b[^\n]*\n\s*(?:catch|end)\b' );
    return $n;
}

# compte le nombre de on error
sub count_on_error($)
{
    my ($sca) = @_ ;
    my $n =  CountVbUtils::count_re($sca, '\bon\s+error\b' );
    return $n;
}


# Recuperation en cas d'erreur sur un comptage
sub try_count_measure($$$)
{
    my ($desc, $proc, $arg) = @_;
    my $c;

    if (not defined ($arg))
    {
			$c = Erreurs::COMPTEUR_ERREUR_VALUE;
    }
    else
    {
            #my $ok = 1 ;
            eval
            {
                $c = $proc->($arg);
            };
            if ($@)
            {
                Timeout::DontCatchTimeout();   # propagate timeout errors
                print STDERR "\n\n erreur dans $desc, avec $proc \n avec le buffer \n" . substr($arg,0,400) . "\n...\n\n";
                #$ok=0;
				$c = Erreurs::COMPTEUR_ERREUR_VALUE;
            }
    }
    return $c;
}

# Mnemonique nouvelle	Mnemonique ancienne
# Nbr_CaseElse	"count_case_else"
# Nbr_Select	"count_select_case"
# Nbr_continue "count_continue"
# Nbr_goto "count_goto"
# Nbr_gosub "count_gosub"
# Nbr_exit "count_exit"
# Nbr_CodeInComment	"count_code_in_comment"
# Nbr_WithoutSymbolNumerics	"count_literaux_numeriques_sans_symbole"
# Nbr_MagicNumbers	"count_two_digits_numbers"
# Using_OptionStrictOn	"using_option_strict_on"
# Using_OptionExplicitOn	"using_option_explicit_on"
# Nbr_Next	"count_next"
# Nbr_SuspiciousComments	"count_bad_comments"
# Nbr_Catch	"count_catch"
# Nbr_OnError	"count_on_error"

# Les compteurs a mesurer pour le VB.
my @comptages = (

    [Ident::Alias_CommentedOutCode(), \&count_code_in_comments, "comment_sans_tag"],
    [Ident::Alias_SuspiciousComments(), \&count_bad_comments, "comment"], # FIXME: pourquoi ne pas utiliser le Countcommun?

    #[Ident::Alias_FunctionMethodImplementations(), \&count_methods, "code_lc"],

    [Ident::Alias_WithoutSymbolNumerics(), \&count_literaux_numeriques_sans_symbole, "code_lc"],
    [Ident::Alias_MagicNumbers(), \&count_two_digits_numbers, "code_lc"],

    [Ident::Alias_If(), \&count_if, "code_lc"],
    [Ident::Alias_Else(), \&count_else, "code_lc"],
    [Ident::Alias_Elsif(), \&count_elseif, "code_lc"],
    [Ident::Alias_Next(), \&count_next, "code_lc"],
    [Ident::Alias_UnparametrizedNext(), \&count_next_empty, "code_lc"],
    [Ident::Alias_While(), \&count_while, "code_lc"],
    [Ident::Alias_Loop(), \&count_loop, "code_lc"],
    [Ident::Alias_Select(), \&count_select_case, "code_lc"],
    [Ident::Alias_Default(), \&count_case_else, "code_lc"],

    [Ident::Alias_Continue(), \&count_continue, "code_lc"],
    [Ident::Alias_Goto(), \&count_goto, "code_lc"],
    [Ident::Alias_Gosub(), \&count_gosub, "code_lc"],
    [Ident::Alias_Exit(), \&count_exit, "code_lc"],

    [Ident::Alias_LogicalLinesOfCode(), \&count_LogicalLinesOfCode, "code_lc"],

    ["Using_OptionStrictOn", \&detect_using_option_strict_on, "code_lc"],
    ["Using_OptionExplicitOn", \&detect_using_option_explicit_on, "code_lc"],

    [Ident::Alias_Try(), \&count_try, "code_lc"],
    [Ident::Alias_Catch(), \&count_catch, "code_lc"],
    [Ident::Alias_EmptyCatches(), \&count_catch_vide, "code_lc"],
    [Ident::Alias_OnError(), \&count_on_error, "code_lc"],

    [Ident::Alias_BugPatterns(), \&count_bug_pattern, "code_lc"],
    [Ident::Alias_BugPatternsTrace(), \&count_bug_patternTrace, "code_lc"], # Erreurs::LogInternalTraces
    [Ident::Alias_InstanceOf(), \&count_typeof, "code_lc"],
);


# Point d'entree du module de comptage
sub CountVbDotNet($$$)
{
    my ($fichier, $vue, $compteurs) = @_;
    my $status = 0;
    foreach  my $c (  @comptages )
    {
        $status |= Couples::counter_add($compteurs, $c->[0], try_count_measure ( $c->[0], $c->[1], $vue->{ $c->[2] } ) );
    }
    return $status;
}


# Comptage des lignes de plusieurs instructions.
sub CountParam_Tags($$$) {
  my ($param1, $vue, $compteurs) = @_ ;
  my $retour = 0;

  my $Nbr_ParamTags = 0;

  my $comment = $vue->{'comment'};

  if ( ! defined $comment ) {
    $retour |= Couples::counter_add($compteurs, Ident::Alias_ParamTags(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $retour |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  $Nbr_ParamTags = CountVbUtils::count_re  ($comment, qr{[<]/param\s*[>]} );


  $retour |= Couples::counter_add($compteurs, Ident::Alias_ParamTags(), $Nbr_ParamTags);

  return $retour;
}



# Comptage des lignes de plusieurs instructions.
sub CountMultInst($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $retour = 0;

  my $Nbr_MultipleStatementsOnSameLine= 0;

  my $code = $vue->{'code_lc'};

  if ( ! defined $code ) {
    $retour |= Couples::counter_add($compteurs, Ident::Alias_MultipleStatementsOnSameLine(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $retour |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  while ( $code =~ /^(.*)$/mg ) {
    my $prog = $1;

    $prog =~ s/:=/=/g ;
    my @instructions = split ( /:\s*/, $prog );
    my $p = scalar @instructions ;
    #my $nb = () = $prog =~ /:\s*\S/g ;
    my $VB8_Identifier = '\b' . $VBKeepCode::VB8_Identifier  . '\b' ;

    #if ($nb > 0) {
    if ($p == 2 )
    {
      if ( $instructions[0] !~ /^(?:[0-9]*|${VB8_Identifier})\s*$/ )
      {
        $Nbr_MultipleStatementsOnSameLine++;
      }
    }
    elsif ($p > 2)
    {
      $Nbr_MultipleStatementsOnSameLine++;
    }
  }

  $retour |= Couples::counter_add($compteurs, Ident::Alias_MultipleStatementsOnSameLine(), $Nbr_MultipleStatementsOnSameLine);

  return $retour;
}



sub CountRiskyFunctionCallsTraces ($$$)
{
  my ($param, $vue, $compteurs) = @_ ;
  my $fichier = $param;

  my $ret = 0;
  if ( ! defined $vue->{code} ) {
    return $ret;
  }
  my $r_code = \$vue->{code} ;

  my $nb_RiskyFunctionCalls = 0;
  if ( ( $$r_code =~ /\bsystem\b/smi )
   and ( $$r_code =~ /\bgc\b/smi ) )
  {
    while($$r_code =~ /\b(collect\s*\()/smgi )
    {
      $nb_RiskyFunctionCalls += 1;
      my $pattern = $1;
      Erreurs::LogInternalTraces ('trace', $fichier, undef, Ident::Alias_RiskyFunctionCalls(), $pattern, 'collect') ;
    }
  }

  while($$r_code =~ /\b(objptr|strptr|varpptr|ismissing|as\s*new|resume|for\b.*\blbound|to\b.*\bubound)\b/smgi )
  {
    $nb_RiskyFunctionCalls += 1;
    my $pattern = $1;
    Erreurs::LogInternalTraces ('trace', $fichier, undef, Ident::Alias_RiskyFunctionCalls(), $pattern, 'mot clef') ;
  }
  my $comptage = Couples::counter_get_values($compteurs)->{Ident::Alias_RiskyFunctionCalls()} ;
  if ( $comptage !=  $nb_RiskyFunctionCalls)
  {
    Erreurs::LogInternalTraces ('error', $fichier, undef, Ident::Alias_RiskyFunctionCalls(), $comptage . ' != ' . $nb_RiskyFunctionCalls , 'coherence') ;
  }
  return $ret;
}# Comptage des appels a System.gc.collect()

sub CountRiskyFunctionCalls ($$$)
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;

  if ( ! defined $vue->{code_lc} ) {
    $ret |= Couples::counter_add($compteurs, Ident::Alias_RiskyFunctionCalls(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my $r_code = \$vue->{code_lc} ;

  my $nb_RiskyFunctionCalls = 0;
  if ( ( $$r_code =~ /\bsystem\b/sm )
   and ( $$r_code =~ /\bgc\b/sm ) )
  {
    $nb_RiskyFunctionCalls += () = $$r_code =~ /\b(?:collect\s*\()/smg;
  }

  $nb_RiskyFunctionCalls +=  CountVbUtils::count_re($$r_code, '\b(?:objptr|strptr|varpptr|ismissing|as\s*new|resume|for\b.*\blbound|to\b.*\bubound)\b' );

  Couples::counter_add($compteurs, Ident::Alias_RiskyFunctionCalls(), $nb_RiskyFunctionCalls);

  CountRiskyFunctionCallsTraces ($fichier, $vue, $compteurs); # Erreurs::LogInternalTraces
  return $ret;
}



# compte le nombre de statement illegals.
sub CountIllegalStatements($$$)
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  if ( ! exists $vue->{'code_lc'} ) {
    $ret |= Couples::counter_add($compteurs, Ident::Alias_IllegalStatements(),
              Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    return $ret ;
  }
  my $code = $vue->{'code_lc'};
  my $nb_IllegalStatements = 0;

  while ($vue->{code_lc} =~ /[^\[\.]\b(
                           end\s*[:\n] |
                           stop\b[ \t]*[^\(]    |
                           def\b     |
                           option\s*base\b)
                         /xsg )
  {
    Erreurs::LogInternalTraces ('trace', undef, undef, Ident::Alias_IllegalStatements(), $1, '') ;
    $nb_IllegalStatements++;
  }

  Couples::counter_add($compteurs, Ident::Alias_IllegalStatements(), $nb_IllegalStatements);

  return $ret;
}

sub CountIllegalThrows {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $ret = 0;

  my $Nbr_IllegalThrow = 0;

  if ( ! defined $vue->{'code_lc'} ) {
    $ret |= Couples::counter_add($compteurs, Ident::Alias_IllegalThrows(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  while ($vue->{'code_lc'} =~ /\bthrow\b([^:\n]*)/sg ) {
    my $exception = $1;
    if ( $exception =~ /systemexception/ ) {
      $Nbr_IllegalThrow++;
    }
  }

  $ret |= Couples::counter_add($compteurs, Ident::Alias_IllegalThrows(), $Nbr_IllegalThrow);

  return $ret;
}



sub CountVG($$$$)
{
    my $status;
    my $nb_VG = 0;
    my $VG__mnemo = Ident::Alias_VG();
    my ($fichier, $vue, $compteurs, $options) = @_;

    if (  ( ! defined $compteurs->{Ident::Alias_If()}) ||
	    #( ! defined $compteurs->{Ident::Alias_Elsif()}) ||
	  ( ! defined $compteurs->{Ident::Alias_Case()}) || 
	  #( ! defined $compteurs->{Ident::Alias_Default()}) || 
	 
	  
	  ( ! defined $compteurs->{Ident::Alias_Try()}) || 
	  ( ! defined $compteurs->{Ident::Alias_Catch()}) || 

	  # For .. next
	  ( ! defined $compteurs->{Ident::Alias_For()}) || 
	  # while .. end while
	  ( ! defined $compteurs->{Ident::Alias_While()}) || 
	  # do .. loop
	  ( ! defined $compteurs->{Ident::Alias_Loop()}) || 

	  ( ! defined $compteurs->{Ident::Alias_FunctionMethodImplementations()}) )
    {
      $nb_VG = Erreurs::COMPTEUR_ERREUR_VALUE;
    }
    else {
      $nb_VG = $compteurs->{Ident::Alias_If()} +

               # As number of "if" is the number of "then" keyword, it encompasses number of elseif too... So, carreful to not count elseif two time !!!
               #$compteurs->{Ident::Alias_Elsif()} +
	       
	       $compteurs->{Ident::Alias_Case()} +

               # As number of "case" encompasses the number of "case else",  carreful to not count "case else"  two time !!!
	       #$compteurs->{Ident::Alias_Default()} +

	       $compteurs->{Ident::Alias_Try()} +
	       $compteurs->{Ident::Alias_Catch()} +
	       $compteurs->{Ident::Alias_For()} +
	       $compteurs->{Ident::Alias_While()} +
	       $compteurs->{Ident::Alias_Loop()} +
	       $compteurs->{Ident::Alias_FunctionMethodImplementations()};
    }

    $status |= Couples::counter_add($compteurs, $VG__mnemo, $nb_VG);
}




1;
