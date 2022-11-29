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

package CountNsdk;

# les modules importes
use strict;
use warnings;
use Erreurs;

use Couples;
use CountBinaryFile;
use CountBreakLoop;

my $RE_TYPE = '[%$#£]';
#my $RE_FUNC = '[A-Za-z_][A-Za-z0-9_]*[%$#£]?'; # '_' en debut de nom pas
my $RE_FUNC = '[A-Za-z_][A-Za-z0-9_]*';  # '_' en debut de nom pas
                                         # clairement autorise, ni interdit
                                         # mais existe
my $RE_VAR = '[A-Za-z][A-Za-z0-9_]*[%$#£]?';

my $contSep = " \001 "; # coupure de ligne


#-------------------------------------------------------------------------------
# DESCRIPTION: fonctions de comptages des mots cles
#-------------------------------------------------------------------------------
sub CountKeywords($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;


  $ret |= CountItem("if", Ident::Alias_If(), $vue, $compteurs);
#  $ret |= CountItem("else", Ident::Alias_Else(), $vue, $compteurs);
  $ret |= CountItem("elseif", Ident::Alias_Elsif(), $vue, $compteurs);
#  $ret |= CountItem("endif", "Nbr_Endif", $vue, $compteurs);
  $ret |= CountItem("while", Ident::Alias_While(), $vue, $compteurs);
  $ret |= CountItem("loop", Ident::Alias_Loop(), $vue, $compteurs);
  $ret |= CountItem("for", Ident::Alias_For(), $vue, $compteurs);
  $ret |= CountItem("repeat", Ident::Alias_Repeat(), $vue, $compteurs);
  $ret |= CountItem("break", Ident::Alias_Break(), $vue, $compteurs);
  $ret |= CountItem("continue", Ident::Alias_Continue(), $vue, $compteurs);
  $ret |= CountItem("evaluate", Ident::Alias_Switch(), $vue, $compteurs);
  $ret |= CountItem("where", Ident::Alias_Case(), $vue, $compteurs);
#  $ret |= CountItem("default", Ident::Alias_Default(), $vue, $compteurs);
  $ret |= CountItem("return", Ident::Alias_Return(), $vue, $compteurs);
  $ret |= CountItem("halt", Ident::Alias_Halt(), $vue, $compteurs);
  $ret |= CountItem("exit", Ident::Alias_Exit(), $vue, $compteurs);
  $ret |= CountItem("new", Ident::Alias_New(), $vue, $compteurs);
  $ret |= CountItem("dispose", Ident::Alias_Delete(), $vue, $compteurs);
  $ret |= CountItem("mov", Ident::Alias_Mov(), $vue, $compteurs);
  $ret |= CountItem("fill", Ident::Alias_Fill(), $vue, $compteurs);
  $ret |= CountItem("loadDLL", Ident::Alias_LoadDLL(), $vue, $compteurs);
  $ret |= CountItem("unloadDLL", Ident::Alias_UnloadDLL(), $vue, $compteurs);

  return $ret;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountItem($$$$) {
  my ($item, $id, $vue, $compteurs) = @_ ;
  my $ret = 0;

  if ( ! defined $vue->{'code'} ) {
    $ret |= Couples::counter_add($compteurs, $id, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nb = () = $vue->{'code'} =~ /\b${item}\b/sgi ;
  $ret |= Couples::counter_add($compteurs, $id, $nb);

  return $ret;
}




#-------------------------------------------------------------------------------
# Module de comptage des instructions mot-clé du langage.
#-------------------------------------------------------------------------------




# Comptages
my $Nbr_Methods = 0;
my $Nbr_TotalParameters = 0;
my $Nbr_WithTooMuchParametersMethods = 0;
my $Nbr_ShortClassNamesLT = 0;
my $Nbr_ShortClassNamesHT = 0;
my $Nbr_ShortAttributeNamesLT = 0;
my $Nbr_ShortAttributeNamesHT = 0;
my $Nbr_ShortMethodNamesLT = 0;
my $Nbr_ShortMethodNamesHT = 0;
my $Nbr_BadClassNames = 0;
my $Nbr_BadAttributeNames = 0;
my $Nbr_BadMethodNames = 0;

my $MetricsFileName=""; 


#use constant MAX_METHOD_PARAMETER => 7;


#PC#-------------------------------------------------------------------------------
#PC# DESCRIPTION: # FIXME:
#PC#-------------------------------------------------------------------------------
#PCsub CountMetrics($$$) {
#PC  my ($fichier, $vue, $compteurs) = @_ ;
#PC
#PC  $MetricsFileName=$fichier;
#PC
#PC  my $ret = 0;
#PC
#PC  #my $BufCode = \$vue->{code};
#PC  my $BufCode = "";
#PC  if ( (exists $vue->{'prepro'}) && ( defined $vue->{'prepro'} ) ) {
#PC    $BufCode = \$vue->{'prepro'};
#PC    Erreurs::LogInternalTraces('DEBUG', $fichier, 1, 'CountMetrics', "utilisation de la vue prepro.\n");
#PC  }
#PC  else {
#PC    $BufCode = \$vue->{'code'};
#PC  }
#PC
#PC  my $bloc;
#PC  # $next est "le prochain bloc a analyser". Initialement, son contenu est celui de la vue.
#PC  my $next=$$BufCode;
#PC
#PC  $Nbr_Methods = 0;
#PC  $Nbr_Constructors = 0;
#PC  $Nbr_Properties = 0;
#PC  $Nbr_PublicAttributes = 0;
#PC  $Nbr_PrivateProtectedAttributes = 0;
#PC  $Nbr_ClassImplementations =0 ;
#PC  $Nbr_BadDeclarationOrder = 0;
#PC  $Nbr_TotalParameters = 0;
#PC  $Nbr_WithTooMuchParametersMethods = 0;
#PC  $Nbr_ShortClassNamesLT = 0;
#PC  $Nbr_ShortClassNamesHT = 0;
#PC  $Nbr_ShortAttributeNamesLT = 0;
#PC  $Nbr_ShortAttributeNamesHT = 0;
#PC  $Nbr_ShortMethodNamesLT = 0;
#PC  $Nbr_ShortMethodNamesHT = 0;
#PC  $Nbr_BadClassNames = 0;
#PC  $Nbr_BadAttributeNames = 0;
#PC  $Nbr_BadMethodNames = 0;
#PC  $Nbr_ParentClasses = 0;
#PC  $Nbr_ParentInterfaces = 0;
#PC  $Nbr_Finalize = 0;
#PC
#PC  $const_id = 0;
#PC  $event_decl_id = 0;
#PC  $field_id = 0;
#PC  $operator_id = 0;
#PC  $event_access_id = 0;
#PC  $constructor_id = 0;
#PC  $property_id = 0;
#PC  $method_id = 0;
#PC  $class_id = 0;
#PC
#PC  %H_Class = ();
#PC
#PC  if ( ! defined $next ) {
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_FunctionMethodImplementations(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_Constructors(), Erreurs::COMPTEUR_ERREUR_VALUE);
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_Properties(), Erreurs::COMPTEUR_ERREUR_VALUE);
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_PublicAttributes(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_PrivateProtectedAttributes(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_ClassImplementations(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_BadClassNames(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_BadMethodNames(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_BadAttributeNames(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_ShortClassNamesLT(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_ShortClassNamesHT(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_ShortMethodNamesLT(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_ShortMethodNamesHT(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_ShortAttributeNamesLT(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_ShortAttributeNamesHT(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_ParentClasses(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_ParentInterfaces(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_BadDeclarationOrder(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    $ret |= Couples::counter_add($compteurs, Ident::Alias_Finalize(), Erreurs::COMPTEUR_ERREUR_VALUE );
#PC    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
#PC  }
#PC
#PC  while ( $next ne "") {
#PC    # Recherhce de la premiere classe :
#PC    #my ( $ClassModifiers, $classBegin, $ClassName, undef, $ClassBase) = $next =~ /(${Modifiers}*)${Sep}*(class${Sep}+(\w*)${Sep}*(?:${Sep}*([\w\.,\s]*))*.*)/sg ;
#PC    my ( $ClassModifiers, $classBegin, $ClassName, undef, $ClassBase) = $next =~ /(${Modifiers}*)${Sep}*(class${Sep}+(\w*)${Sep}*(:${Sep}*([\w\.,\s]*))*.*)/sg ;
#PC
#PC    if ( defined $ClassName ) {
#PC      ($bloc, $next) = get_Bloc($classBegin);
#PC
#PC      # Construit des listes de declaration de membre de classe dans les tableaux ci-dessus.
#PC      analyze_Class($bloc, $ClassName, $ClassBase, $ClassModifiers);
#PC
#PC      # recupere les statistique de commentaires des membres de classe.
#PC#        my ($nb_C, $nb_CL, $nb_ML, $nb_LOC) = get_CommentStat_Bloc($bloc);
#PC#        print "-----------------------------------------------------------------------------------------------------------------\n";
#PC#        print " Statistiques commentaires :\n";
#PC#        print "              Nombre de lignes de code : $nb_LOC\n";
#PC#        print "      Nombre de lignes de commentaires : $nb_CL\n";
#PC#        print "               Nombre de lignes mixtes : $nb_ML\n";
#PC#        print "                Nombre de commentaires : $nb_C\n";
#PC#        print "        Taux de lignes de commentaires : "; printf "(%.2f\%)\n",($nb_CL+$nb_ML)/($nb_LOC+$nb_ML)*100;
#PC#        print "                  Taux de commentaires : "; printf "(%.2f\%)\n",($nb_C)/($nb_LOC+$nb_ML)*100;
#PC
#PC    }
#PC    else {
#PC      ## Le bloc $next actuel ne comporte aucune déclaration de classe.
#PC
#PC      # si $bloc est vide, c'est que le fichier ne comporte aucune déclaration de classe.
#PC      if ( ( ! defined $bloc) || ( $bloc eq "" ) ) {
#PC        print STDERR "[CountCS::CountMetrics] ATTENTION : le fichier $fichier ne contient pas de classe.\n";
#PC      }
#PC
#PC      # Si plus de classe trouve, alors inutile de continuer la recherche : on vide le buffer à analyser.
#PC      $next="";
#PC    }
#PC  }
#PC  foreach my $ClassName (keys %H_Class) {
#PC
#PC    Compute_Metrics($ClassName, $compteurs);
#PC
#PC    $Nbr_Finalize += () = $$BufCode =~ /~${ClassName}\b/;
#PC
#PC    #print_ClassStat($ClassName, $fichier);
#PC    #
#PC    # analyse des methodes.
#PC    #my $r=@{$H_Class{$ClassName}}[10];
#PC    #foreach my $key (keys %$r) {
#PC    #  my $line = @{$r->{$key}}[1];
#PC    #  analyze_Method($line, $ClassName);
#PC    #}
#PC  }
#PC
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_FunctionMethodImplementations(), $Nbr_Methods + $Nbr_Constructors);
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_Constructors(), $Nbr_Constructors);
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_Properties(), $Nbr_Properties);
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_PublicAttributes(), $Nbr_PublicAttributes);
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_PrivateProtectedAttributes(), $Nbr_PrivateProtectedAttributes);
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_ClassImplementations(), $Nbr_ClassImplementations );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_TotalParameters(), $Nbr_TotalParameters );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_WithTooMuchParametersMethods(), $Nbr_WithTooMuchParametersMethods );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_BadClassNames(), $Nbr_BadClassNames );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_BadMethodNames(), $Nbr_BadMethodNames );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_BadAttributeNames(), $Nbr_BadAttributeNames );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_ShortClassNamesLT(), $Nbr_ShortClassNamesLT );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_ShortClassNamesHT(), $Nbr_ShortClassNamesHT );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_ShortMethodNamesLT(), $Nbr_ShortMethodNamesLT );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_ShortMethodNamesHT(), $Nbr_ShortMethodNamesHT );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_ShortAttributeNamesLT(), $Nbr_ShortAttributeNamesLT );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_ShortAttributeNamesHT(), $Nbr_ShortAttributeNamesHT );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_ParentClasses(), $Nbr_ParentClasses );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_ParentInterfaces(), $Nbr_ParentInterfaces );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_BadDeclarationOrder(), $Nbr_BadDeclarationOrder );
#PC  $ret |= Couples::counter_add($compteurs, Ident::Alias_Finalize(), $Nbr_Finalize );
#PC  return $ret;
#PC}

# ===================================  Fonctions Internes ==============================


use constant MAX_COMB_ANDOR => 4;


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub _checkCond($$$$)
{
    my ($file, $numLigne, $ligne, $compteurs) = @_;

    my $cond = $ligne;
    $cond =~s/\A\s*\w+\s*//;

    my $nbAnd = 0;
    my $nbOr = 0;
    my $isComplex = 0;

    while ($cond =~ /\b(AND|OR)\b/gi)
    {
        if (uc($1) eq 'AND')
        {
            $nbAnd++;
        }
        else
        {
            $nbOr++;
        }
    }
    if ($nbAnd != 0 && $nbOr != 0 && ($nbAnd + $nbOr) > MAX_COMB_ANDOR)
    {
        $isComplex = 1;
        Erreurs::LogInternalTraces("TRACE", $file, $numLigne, Ident::Alias_ComplexConditions(), $ligne, "$nbAnd AND + $nbOr OR");
    }
    return ($nbAnd, $nbOr, $isComplex);
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub _countMultDecl($$$$$$)
{
    my ($decl, $type, $numLigne, $file, $minLength, $rCptShort ) = @_;

    my @tbDecl = split(/,/, $decl);
    my $nbVirg = $#tbDecl;
    for my $name (@tbDecl)
    {
        $name =~ s/[\(\[].*\z//;
        $name =~ s/\s*\z//;
        $name =~ s/$RE_TYPE\z//;
        $name =~ s/\A.*\s//;
        Erreurs::LogInternalTraces("INFO", $file, $numLigne, $type, $name);
        if ($minLength > 0)
        {
            if (length($name) < $minLength)
            {
                Erreurs::LogInternalTraces("TRACE", $file, $numLigne, "Nbr_Short" . $type . "NamesLT", '`' . $name . "' nom trop court : " . length($name));
                $$rCptShort++;
            }
        }
    }
    return $nbVirg;
}


use constant TYPE_NONE   => 0;
use constant TYPE_INT    => 1;
use constant TYPE_REAL   => 2;
use constant TYPE_STRING => 3;


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub _typeCode($)
{
    my ($typeName) = @_;
    my $type = TYPE_NONE;

    $typeName = uc($typeName);

    if ($typeName eq 'INT')
    {
        $type = TYPE_INT;
    }
    elsif ($typeName eq 'NUM')
    {
        $type = TYPE_REAL;
    }
    elsif ($typeName eq 'STRING' or $typeName eq 'CSTRING')
    {
        $type = TYPE_STRING;
    }
    return $type;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub _detectType($)
{
    my ($suff) = @_;
    my $type = TYPE_NONE;

    return $type if (! defined $suff);

    if ($suff eq '%')
    {
        $type = TYPE_INT;
    }
    elsif ($suff eq '#' or $suff eq '£')
    {
        $type = TYPE_REAL;
    }
    elsif ($suff eq '$')
    {
        $type = TYPE_STRING;
    }
    return $type;
}


# ===================================  Fin Fonctions Internes ==============================


use constant MAX_COMPONENT_PARAMS => 4;


use constant TOK_ELSE => 10053;
use constant TOK_EVALUATE => 10058;
use constant TOK_IF => 10095;

use constant METHOD_NAME_MIN_LENGTH => 15;
use constant CONST_NAME_MIN_LENGTH => 10;
use constant GLOBAL_NAME_MIN_LENGTH => 10;
use constant SEGMENT_NAME_MIN_LENGTH => 11;


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountContext($$$)
{
    my ($file, $vues, $compteurs) = @_;

    my $curProc = "";
    my $curSeg = "";
    my $maxParams = 0;
    my $nbDefault = 0;
    my $nbDiffUpdate = 0;
    my $nbDynamic = 0;
    my $nbElse = 0;
    my $nbExitFunc = 0;
    my $nbGlobVar = 0;
    my $nbMissingDefaults = 0;
    my $nbMultipleDeclarationsInSameStatement = 0;
    my $nbNoUpdate;
    my $nbOddSetptr = 0;
    my $nbParams = 0;
    my $nbReturn;
    my $nbSegments = 0;
    my $nbSetptr;
    my $nbTooManyParams = 0;
    my $nbTotalParams = 0;
    my $nbUpdate;
    my $numLigne = 0;
    my %hComp = ();
    my @tbElseWhere = ();
    my $nbAndOr = 0;
    my $nbComplexCond = 0;
    my $nbConst = 0;

    my $nbShortConst = 0;
    my $nbShortGlob = 0;
    my $nbShortMeth = 0;
    my $nbShortSeg = 0;

    my $status = 0;

    my $code = $vues->{'code'};

    while ($code =~ /([^\n]*)\n/g)
    {
        my $ligne = $1;
        $numLigne++;
        if ($ligne =~ /\A\s*\Z/)
        {
            next;
        }
        # traitement de composant
        if ($curProc ne "")
        {
            my $cond = 0;

            # fin de composant
            if ($ligne =~ /\A\s*END(INSTRUCTION|FUNCTION)/i)
            {
                if (uc($1) eq 'FUNCTION')
                {
                    if ($nbReturn == 0)
                    {
                        Erreurs::LogInternalTraces("TRACE", $file, $numLigne, "_detectProcs", $ligne, "FIN DE FUNCTION $curProc sans RETURN");
                    }
                    elsif ($nbReturn > 1)
                    {
                        Erreurs::LogInternalTraces("TRACE", $file, $numLigne, "_detectProcs", $ligne, "Trop de RETURN (" . $nbReturn . ") dans $curProc");
                    }
                }
                Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "_detectProcs", $ligne, "FIN DEFINITION DE $curProc");
                if ($nbUpdate != $nbNoUpdate)
                {
                    Erreurs::LogInternalTraces("TRACE", $file, $numLigne, Ident::Alias_DiffUpdate(), $ligne, "$curProc contient $nbUpdate UPDATE et $nbNoUpdate NOUPDATE");
                    $nbDiffUpdate++;
                }
                if ( ($nbSetptr % 2) != 0 )
                {
                    Erreurs::LogInternalTraces("TRACE", $file, $numLigne, "Nbr_OddSetPtr", $ligne, "$curProc contient un nombre impair de Setptr ($nbSetptr)");
                    $nbOddSetptr++;
                }
                $curProc = "";
                $curProc = "";
            }
            # declaration de variable(s) locale(s)
            elsif ($ligne =~ /\A\s*LOCAL\b/i)
            {
                my $virg = _countMultDecl($ligne, "Local", $numLigne, $file, 0, undef);
                if ($virg != 0)
                {
                    $nbMultipleDeclarationsInSameStatement++;
                    Erreurs::LogInternalTraces("TRACES", $file, $numLigne, Ident::Alias_MultipleDeclarationsInSameStatement(), $ligne, ($virg + 1) . " variables locales declarees sur la meme ligne");
                }
            }
            # recherche d'absence de cas par defaut dans structure Evaluate
            elsif ($ligne =~ /\A\s*EVALUATE\b/i)
            {
                push(@tbElseWhere, TOK_EVALUATE);
            }
            elsif ($ligne =~ /\A\s*IF\b/i)
            {
                $cond =1;
                push(@tbElseWhere, TOK_IF);
            }
            elsif ($ligne =~ /\A\s*ELSE\b/i)
            {
                if ($tbElseWhere[$#tbElseWhere] == TOK_EVALUATE)
                {
                    push(@tbElseWhere, TOK_ELSE) if ($tbElseWhere[$#tbElseWhere] == TOK_EVALUATE);
                    $nbDefault++;
                }
                else
                {
                    $nbElse++;
                }
            }
            elsif ($ligne =~ /\A\s*ENDIF\b/i)
            {
                if ($tbElseWhere[$#tbElseWhere] != TOK_IF)
                {
                    Erreurs::LogInternalTraces("ERROR", $file, $numLigne, Ident::Alias_MissingDefaults(), $ligne, "ENDIF inattendu");
                }
                else
                {
                    pop(@tbElseWhere);
                }
            }
            elsif ($ligne =~ /\A\s*ENDEVALUATE\b/i)
            {
                if ($tbElseWhere[$#tbElseWhere] != TOK_ELSE)
                {
                    $nbMissingDefaults++;
                    Erreurs::LogInternalTraces("TRACE", $file, $numLigne, Ident::Alias_MissingDefaults(), $ligne, "cas defaut manquant");
                }
                else
                {
                    pop(@tbElseWhere);
                }
                if ($tbElseWhere[$#tbElseWhere] != TOK_EVALUATE)
                {
                    Erreurs::LogInternalTraces("ERROR", $file, $numLigne, Ident::Alias_MissingDefaults(), $ligne, "ENDEVALUATE inattendu");
                }
                else
                {
                    pop(@tbElseWhere);
                }
            }
            # verification de placement d'exit uniquement dans une instruction
            elsif ($ligne =~ /\A\s*EXIT\b/i)
            {
                if ($hComp{$curProc}->{'Nature'} eq "FUNCTION")
                {
                    Erreurs::LogInternalTraces("TRACE", $file, $numLigne, "Nbr_ExitInFunction", $ligne, "EXIT interdit dans une fonction");
                    $nbExitFunc++;
                }
            }
            # comptage de Return
            elsif ($ligne =~ /\A\s*RETURN\b(.*)/i)
            {
                my $retVal = $1;
                if ($hComp{$curProc}->{'Nature'} eq 'FUNCTION')
                {
                    # FIXME: Compter les Return par fonction ?
                    $nbReturn++;
                    if ($retVal !~ /\w/)
                    {
                        Erreurs::LogInternalTraces("TRACE", $file, $numLigne, "Nbr_BadReturn", $ligne, "Manque valeur de RETURN une fonction");
                    }
                }
                elsif ($retVal =~ /\w/)
                {
                    # FIXME: Utile ? Compteur a creer ?
                    Erreurs::LogInternalTraces("TRACE", $file, $numLigne, "Nbr_BadReturn", $ligne, "Valeur de RETURN inattendue dans une instruction");
                }
            }
            # comptage SETPTR
            elsif ($ligne =~ /\A\s*SETPTR\b/i)
            {
                $nbSetptr++;
                Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "Nbr_SetPtr", $ligne, "Numero Setptr : $nbSetptr");
            }
            # comptage appariement de UPDATE/NOUPDATE
            elsif ($ligne =~ /\A\s*(NO)?(UPDATE)\b/i)
            {
                if ( uc($1) eq 'NO' )
                {
                    $nbNoUpdate++;
                    Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "NOUPDATE", $ligne, "");
                }
                else
                {
                    $nbUpdate++;
                    Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "UPDATE", $ligne, "");
                }
            }
            if ($cond !=0 || $ligne =~ /\A\s*(UNTIL|ELSEIF|WHILE)\b/)
            {
                my ($nbOr, $nbAnd, $isComplex) = _checkCond($file, $numLigne, $ligne, $compteurs);
                $nbAndOr += $nbAnd + $nbOr;
                $nbComplexCond += $isComplex;
            }
            $cond = 0;
        } # fin de traitement d'une ligne de composant
        # detection de debut de composant
        elsif ($ligne =~ /\A(\s*INSTRUCTION|FUNCTION)\s+($RE_FUNC)($RE_TYPE)?(?:\(|\s|$)\s*(.*)/io)
        {
            my $typeComp;
            my $genre = uc($1);
            $curProc = $2;
            my $spec = $4;
            $nbUpdate = 0;
            $nbNoUpdate = 0;
            $nbReturn = 0;
            $nbSetptr = 0;

            if ($spec =~ /\b(EXTERNAL|DYNAMIC)\b/i)
            {
                Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "_detectProcs", $ligne, "PROTOTYPE EXTERNE DE $curProc");
                $curProc = "";
                if (uc($1) eq 'DYNAMIC')
                {
                    $nbDynamic++;
                }
                next; # Attention : raccourci car il s'agit d'une declaration de methode en librairie
            }

            Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "_detectProcs", $ligne, "DEBUT $genre $curProc");
            # type accole au nom du composant
            if (defined $3)
            {
                my $typeString = $3;
                Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "_detectProcs", $ligne, "FUNCTION DE TYPE '" . $typeString . "'");
                $typeComp = _detectType($typeString);
            }
            else
            {
                $typeComp = TYPE_NONE;
            }
            if ($genre eq "INSTRUCTION")
            {
                $typeComp = TYPE_NONE;
                Erreurs::LogInternalTraces("INFO", $file, $numLigne, "INSTRUCTION", $curProc);
            }
            else
            {
                Erreurs::LogInternalTraces("INFO", $file, $numLigne, "FUNCTION", $curProc);
            }
            # verification taille dun nom de la procedure ou fonction
            if (length($curProc) < METHOD_NAME_MIN_LENGTH)
            {
                Erreurs::LogInternalTraces("TRACE", $file, $numLigne, Ident::Alias_ShortMethodNamesLT(), $ligne, '`' . $curProc . "' nom de methode trop court : " . length($curProc));
                $nbShortMeth++;
            }

            # type de retour de fonction
            if ($spec =~ /\bRETURN\s+(\w+)/i)
            {
                my $retSpec = $1;
                my $retType = _typeCode($retSpec);
                if ($retType == TYPE_NONE)
                {
                    Erreurs::LogInternalTraces("ERROR", $file, $numLigne, "_detectProcs", $ligne, "TYPE INCONNU $retSpec");
                }
                elsif ($typeComp != TYPE_NONE && $retType != $typeComp)
                {
                    Erreurs::LogInternalTraces("ERROR", $file, $numLigne, "_detectProcs", $ligne, "TYPE INCOHERENT");
                }
                else
                {
                    $typeComp = $retType;
                    Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "_detectProcs", $ligne, "RETOUR TYPE '" . $retSpec . "'");
                }
                $spec =~ s/\bRETURN\b.*//i;
            }

            # calcul du nombre de parametres
            if ($spec =~ /\w/)
            {
                $nbParams = ($spec =~ tr/,/,/) + 1;
            }
            else
            {
                $nbParams = 0;
            }
            Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "nbParams", $ligne, " " . $nbParams . " Parametres dans '" . $spec . "'");
            $hComp{$curProc} = {
                                 'Name' => $curProc,
                                 'Nature' => $genre,
                                 'Type' => $typeComp,
                                 'NbParams' => $nbParams,
                                 'Ligne' => $numLigne,
                               };
            $maxParams = $nbParams if ($maxParams < $nbParams);
            if ($nbParams > MAX_COMPONENT_PARAMS)
            {
                $nbTooManyParams++;
                Erreurs::LogInternalTraces("TRACE", $file, $numLigne, "Nbr_TooMuchParameters", $ligne, " " . $nbParams . " parametres dans '" . $spec . "'");
            }
            $nbTotalParams += $nbParams;
        } # fin de declaration de composant
        # declaration de constante(s)
        elsif ($ligne =~ /\A\s*CONST\s+(\w+)/i)
        {
            my $constName = $1;
            Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "_detectProcs", $ligne, "DECLARATION DE CONSTANTE");
            Erreurs::LogInternalTraces("INFO", $file, $numLigne, "CONST", $constName);
            if (length($constName) < CONST_NAME_MIN_LENGTH)
            {
                Erreurs::LogInternalTraces("TRACE", $file, $numLigne, Ident::Alias_ShortConstNamesLT(), $ligne, '`' . $constName . "' nom de constante trop court : " . length($constName));
                $nbShortConst++;
            }
            $nbConst++;

        }
        # declatation de variable(s) globale(s)
        elsif ($ligne =~ /\A\s*GLOBAL\b/i)
        {
            my $nbGlob = _countMultDecl($ligne, "Global", $numLigne, $file, GLOBAL_NAME_MIN_LENGTH, \$nbShortGlob) + 1;
            $nbGlobVar += $nbGlob;
            Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "_detectProcs", $ligne, "DECLARATION DE $nbGlob VARIABLE(s) GLOBALE(s)");
            if ($nbGlob > 1)
            {
                $nbMultipleDeclarationsInSameStatement++;
                Erreurs::LogInternalTraces("TRACES", $file, $numLigne, Ident::Alias_MultipleDeclarationsInSameStatement(), $ligne, $nbGlob . " variables globales declarees sur la meme ligne");
            }
        }
        # Segments
        elsif ($curSeg ne "") 
        {
            if ($ligne =~ /\A\s*ENDSEGMENT\b/i)
            {
                $curSeg = "";
            }
        }
        elsif ($ligne =~ /\A\s*SEGMENT\s+(\w+)\b/i)
        {
            $curSeg = $1;
            Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "_detectProcs", $ligne, "DEFINITION DE SEGMENT $curSeg");
            Erreurs::LogInternalTraces("INFO", $file, $numLigne, "SEGMENT", $curSeg);
            $nbSegments++;
            if (length($curSeg) < SEGMENT_NAME_MIN_LENGTH)
            {
                Erreurs::LogInternalTraces("TRACE", $file, $numLigne, Ident::Alias_ShortSegmentNamesLT(), $ligne, '`' . $curSeg . "' nom de segment trop court : " . length($curSeg));
                $nbShortSeg++;
            }
        }
        # ligne inattendue
        else
        {
            Erreurs::LogInternalTraces("DEBUG", $file, $numLigne, "_detectProcs", $ligne, "Hors procedure ou fonction");
        }
    }

    $status |= Couples::counter_add($compteurs, Ident::Alias_AndOr(), $nbAndOr);
    $status |= Couples::counter_add($compteurs, Ident::Alias_ComplexConditions(), $nbComplexCond);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Default(), $nbDefault);
    $status |= Couples::counter_add($compteurs, Ident::Alias_DiffUpdate(), $nbDiffUpdate);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Dynamic(), $nbDynamic);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Else(), $nbElse);
    $status |= Couples::counter_add($compteurs, Ident::Alias_WithExitFunctions(), $nbExitFunc);
    $status |= Couples::counter_add($compteurs, Ident::Alias_FunctionMethodImplementations(), scalar(keys(%hComp)));
    $status |= Couples::counter_add($compteurs, Ident::Alias_ApplicationGlobalVariables(), $nbGlobVar);
    $status |= Couples::counter_add($compteurs, Ident::Alias_MaxParameters(), $maxParams);
    $status |= Couples::counter_add($compteurs, Ident::Alias_WithTooMuchParametersMethods(), $nbTooManyParams);
    $status |= Couples::counter_add($compteurs, Ident::Alias_MissingDefaults(), $nbMissingDefaults);
    $status |= Couples::counter_add($compteurs, Ident::Alias_MultipleDeclarationsInSameStatement(), $nbMultipleDeclarationsInSameStatement);
    $status |= Couples::counter_add($compteurs, Ident::Alias_OddSetptr(), $nbOddSetptr);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Segments(), $nbSegments);
    $status |= Couples::counter_add($compteurs, Ident::Alias_ConstantDefinitions(), $nbConst);
    $status |= Couples::counter_add($compteurs, Ident::Alias_TotalParameters(), $nbTotalParams);
    $status |= Couples::counter_add($compteurs, Ident::Alias_ShortConstNamesLT(), $nbShortConst);
    $status |= Couples::counter_add($compteurs, Ident::Alias_ShortMethodNamesLT(), $nbShortMeth);
    $status |= Couples::counter_add($compteurs, Ident::Alias_ShortSegmentNamesLT(), $nbShortSeg);
    $status |= Couples::counter_add($compteurs, Ident::Alias_ShortGlobalNamesLT(), $nbShortGlob);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountMagicNumbers($$$)
{
    my ($fichier, $vues, $compteurs) = @_ ;

    my $code = $vues->{code};
    my $ret = 0;
    my $beg = 0;
    my $line = 1;

    if ( ! defined $code ) {
        $ret |= Couples::counter_add($compteurs, Ident::Alias_MagicNumbers(), Erreurs::COMPTEUR_ERREUR_VALUE);
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    # Suppression des declarations de constantes
    $code =~ s/\bconst\b[^\n]*//gi;

    # Suppression des magic numbers toleres.
    $code =~ s/([^\w])[01]?\.0?[^\w]/$1---/sg; # 0.0, 1.0, 0. 1. .0

    my $nb_MagicNumbers = 0;

    # reconnaissance des magic numbers :
    # 1) identifiants commencant forcement par un chiffre decimal.
    # 2) peut contenir des "." (flottants)
    # 3) peut contenir des "E" ou "e" suivis eventuellement de "+/-" pour les flottants
    while ( $code =~ /(\n|[^\w]((\d|\.\d)([Ee][+-]?\d|[\w\.])*))/g )
    {
        if ($1 eq "\n")
        {
            $beg = pos($code);
            $line++;
        }
        else
        {
            my $number = $2 ;
            my $end = pos($code);
            if ( ($1 !~ /\A[\(\[]/)
                 ||
                 ( substr($code, $end, 1) !~ /\A[\)\]]/ )
               )
            {
            # suppression du 0 si le nombre commence par 0.
            $number =~ s/^0*(.)/$1/;
            # Si la donnee trouvee n'est pas un simple chiffre, alors ce n'est pas un magic number tolere ...
            if ($number !~ /^\d$/ )
            {
              #print "magic = >$number<\n";
              Erreurs::LogInternalTraces("TRACE", $fichier, $line, Ident::Alias_MagicNumbers(), substr($code, $beg, $end - $beg), "Valeur littérale : " . $number);
              $nb_MagicNumbers++;
            }
            }
        }
    };

    $ret |= Couples::counter_add($compteurs, Ident::Alias_MagicNumbers(), $nb_MagicNumbers);

    return $ret;

}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountBadSpacing($$$)
{
    my ($fichier, $vues, $compteurs) = @_ ;

    my $code = $vues->{'code'};

    my $status = 0;
    my $contLen = length $contSep;

    my $beg = 0;
    my $lineBeg = 0;
    my $nextLineBeg = 0;
    my $lastLinePb = 0;
    my $codeLine = 1;
    my $nbLines80 = 0;
    my $nbLines100 = 0;
    my $nbLines132 = 0;
    my $cumulCont = 0;
    my $maxCont = 0;
    my $ligne;
    my $purgeCont = -1;
#    my $lastContSep = -1;
    my $nbBadSpace = 0;

    # parcours de la vue code
    while ($code =~ m{($contSep|\n|[.,])}go)
    {
        my $end = pos($code);

        if ($1 eq $contSep)
        {
            $codeLine++;
            $cumulCont++;
            $maxCont++;
            $nextLineBeg = $end;
#            $lastContSep = $end - 1;
        }
        elsif ($1 eq "\n")
        {
            $codeLine++;
            if ($maxCont > 0)
            {
                $purgeCont++;
                # la 1ere fin de ligne apres une continuation de ligne
                # doit etre prise comme tel
                if ($purgeCont > 0)
                {
                    # tant qu'on n'a pas purge le nombre de continuations de lignes
                    # deja comptees comme des fin de ligne, il faut ignore le retour
                    # a la ligne rencontre
                    $codeLine--;
                }
                if ($purgeCont == $maxCont)
                {
                    # recalage termine entre vues text et code
                    $purgeCont = -1;
                    $maxCont = 0;
                }
            }
            $nextLineBeg = $end;
        }
        elsif ($1 eq ',' && $codeLine > $lastLinePb)
        {
            if (substr($code, $end, 1) !~ /\s/)
            {
                $nbBadSpace++;
                $lastLinePb = $codeLine;
                $ligne = substr($code, $lineBeg, $end + 1 - $lineBeg);
                Erreurs::LogInternalTraces("TRACE", $fichier, $codeLine, Ident::Alias_BadSpacing(), $ligne, "Manque un espace derriere la virgule");
            }
        }
        elsif ($1 eq '.' && $codeLine > $lastLinePb)
        {
            # FIXME: on ne traite pas les '..' qui sont des constructions a haut risque
            if ( ($end > 1) && (substr($code, $end - 2, 1) =~ /\s/) )
            {
                # le point est precede d'un espace
                $nbBadSpace++;
                $lastLinePb = $codeLine;
                $ligne = substr($code, $lineBeg, $end - $lineBeg);
                Erreurs::LogInternalTraces("TRACE", $fichier, $codeLine, Ident::Alias_BadSpacing(), $ligne, "Espace inattendu devant le point");
            }
            elsif (substr($code, $end, 1) =~ /\s/) 
            {
                # le point est suivi d'un espace
                $nbBadSpace++;
                $lastLinePb = $codeLine;
                $ligne = substr($code, $lineBeg, $end + 1 - $lineBeg);
                Erreurs::LogInternalTraces("TRACE", $fichier, $codeLine, Ident::Alias_BadSpacing(), $ligne, "Espace inattendu derriere le point");
            }
        }

        $beg = $end;
        $lineBeg = $nextLineBeg if ($nextLineBeg > $lineBeg);
    }

    $status |= Couples::counter_add($compteurs, Ident::Alias_BadSpacing(), $nbBadSpace);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountCodeLines($$$)
{
    my ($fichier, $vues, $compteurs) = @_ ;

    my $code = $vues->{'code'};

    my $status = 0;
    my $contLen = length $contSep;

    my $deb = 0;
    my $codeLine = 0;
    my $nbLines80 = 0;
    my $nbLines100 = 0;
    my $nbLines132 = 0;
    my $nbLoc = 0;
    my $cumulCont = 0;
    my $maxCont = 0;
    my $ligne;
    my $purgeCont = -1;

    # parcours de la vue code
    while ($code =~ m{($contSep|\n)}go)
    {
        my $codeLen;
        my $end = pos($code);

        $codeLine++;
        if ($1 eq $contSep)
        {
            $codeLen = $end - $deb - $contLen;
            $cumulCont++;
            $maxCont++;
        }
        else
        {
            if ($maxCont > 0)
            {
                $purgeCont++;
                # la 1ere fin de ligne apres une continuation de ligne
                # doit etre prise comme tel
                if ($purgeCont > 0)
                {
                    # tant qu'on n'a pas purge le nombre de continuations de lignes
                    # deja comptees comme des fin de ligne, il faut ignore le retour
                    # a la ligne rencontre
                    $codeLine--;
                }
                if ($purgeCont == $maxCont)
                {
                    # recalage termine entre vues text et code
                    $purgeCont = -1;
                    $maxCont = 0;
                }
            }
            $codeLen = $end - $deb - 1;
        }
        $ligne = substr($code, $deb, $codeLen);
        if ($ligne =~ /\S/)
        {
            $nbLoc++;
            Erreurs::LogInternalTraces ("TRACE", $fichier, $codeLine, Ident::Alias_LinesOfCode(), $ligne);
        }

#        if ($codeLen >= 80)
#        {
#            $nbLines80++;
#            Erreurs::LogInternalTraces ("TRACE", $fichier, $codeLine, Ident::Alias_LongLines80(), $ligne, "Longueur de ligne : " . $codeLen);
#        }
#        if ($codeLen >= 100)
#        {
#            $nbLines100++;
#            Erreurs::LogInternalTraces ("TRACE", $fichier, $codeLine, Ident::Alias_LongLines100(), $ligne, "Longueur de ligne : " . $codeLen);
#        }
#        if ($codeLen >= 132)
#        {
#            $nbLines132++;
#            Erreurs::LogInternalTraces ("TRACE", $fichier, $codeLine, Ident::Alias_LongLines132(), $ligne, "Longueur de ligne : " . $codeLen);
#        }
        $deb = $end;
    }
    $status |= Couples::counter_add($compteurs, Ident::Alias_LinesOfCode(), $nbLoc);
#    $status |= Couples::counter_add($compteurs, Ident::Alias_LongLines80(), $nbLines80);
#    $status |= Couples::counter_add($compteurs, Ident::Alias_LongLines100(), $nbLines100);
#    $status |= Couples::counter_add($compteurs, Ident::Alias_LongLines132(), $nbLines132);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountCommentsBlocs($$$)
{
    my ($fichier, $vues, $compteurs) = @_ ;

    my $status = 0;

    # parcours de la vue commentaires
    my $deb = 0;
    my $cmtLine = 0;
    my $prevIndent = -1;
    my $nbCmtBlocks = 0;
    my $nbCmtLines = 0;
    my $nbAlphaNumCmt = 0;
    my $ligne = '';

    my $cmt = $vues->{'comment'};

    while ($cmt =~ m{\n}g)
    {
        my $end = pos($cmt);
        $ligne = substr($cmt, $deb, $end - $deb);

        $cmtLine++;

        if ($ligne =~ /\A\s*\Z/)
        {
            # pas de commentaire sur cette ligne
            $prevIndent = -1;
        }
        else
        {
            $nbCmtLines++;
            Erreurs::LogInternalTraces ("TRACE", $fichier, $cmtLine, Ident::Alias_CommentLines(), $ligne, $nbCmtLines);
            # comptage du nombre de blocs de commentaires
            my $content = $ligne;
            $content =~ s/\A[^;]*;//;

            my $code = $ligne;
            $code =~ s/;.*$//;
            $code =~ tr/\n//d;
            my $indent = length($code);

            if ($content =~ /\w/)
            {
                $nbAlphaNumCmt++;
                Erreurs::LogInternalTraces ("TRACE", $fichier, $cmtLine, Ident::Alias_AlphaNumCommentLines(), $ligne, $nbAlphaNumCmt);
                if ($indent != $prevIndent)
                {
                    Erreurs::LogInternalTraces ("TRACE", $fichier, $cmtLine, Ident::Alias_CommentBlocs(), $ligne, "Indentation commentaire : " . $indent);
                    $nbCmtBlocks++;
                    $prevIndent = $indent;
                }
            }
        }
        $deb = $end;
    }

    Erreurs::LogInternalTraces ("TRACE", $fichier, $cmtLine, "Nbr_Lines", $ligne, $cmtLine . " lignes");

    $status |= Couples::counter_add($compteurs, Ident::Alias_CommentBlocs(), $nbCmtBlocks);
    $status |= Couples::counter_add($compteurs, Ident::Alias_CommentLines(), $nbCmtLines);
    $status |= Couples::counter_add($compteurs, Ident::Alias_AlphaNumCommentLines(), $nbAlphaNumCmt);
    $status |= Couples::counter_add($compteurs, Ident::Alias_LinesNsdk(), $cmtLine);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountWords($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;

    my @NsdkFunction=
      (
        'ASC',             #%
        'ASK2',            #%
        'ASK3',            #%
        'CHR',             #$
        'COPY',            #$
        'DELETE',          #$
        'DWORD',           #%
        'FILLER',          #$
        'GETBACKCOL',      #%
        'GETCLIENTHEIGHT', #%
        'GETCLIENTWIDTH',  #%
        'GETDATA',         #%
        'GETFORECOL',      #%
        'GETHEIGHT',       #%
        'GETSPTR',         #%
        'GETTEXT',         #$
        'GETWIDTH',        #%
        'GETXPOS',         #%
        'GETYPOS',         #%
        'INSERT',          #$ attention : c'est aussi une instruction (suivie de AT)
        'ISDISABLED',      #%
        'ISHIDDEN',        #%
        'ISINT',           #%
        'ISLOCKED',        #%
        'ISMAXIMIZED',     #%
        'ISMINIMIZED',     #%
        'ISMOUSE',         #%
        'ISNUM',           #%
        'ISSELECTED',      #%
        'LINECOUNT',       #%
        'MAINWINDOW',      #%
        'NBBUTTONS',       #%
        'PARAM1',          #%
        'PARAM2',          #%
        'PARAM3',          #%
        'PARAM4',          #%
        'PARAM12',         #%
        'PARAM34',         #%
        'PARENTWINDOW',    #%
        'POS',             #%
        'ROUND',           #%
        'SCREENHEIGHT',    #%
        'SCREENWIDTH',     #%
        'SELECTION',       #%
        'SELF',            #% attention : c'est aussi un controle systeme
        'TRUNC',           #%
        'WORD',            #%
      );


    my @NsdkType=
      (
        'CHAR',
        'CONTROL',
        'CSTRING',
        'INT',      # attention : c'est aussi un operateur de conversion de type
        'NUM',      # attention : c'est aussi un operateur de conversion de type
        'STRING',   # attention : c'est aussi un operateur de conversion de type
      );


    my @NsdkConst=
      (
        'CANCEL',          #%
        'CHECKED',         #%
        'DEFRET',          #%
        'FALSE',           #%
        'INDETERMINATE',   #%
        'NO',              #%
        'NOSELECTION',     #%
        'TRUE',            #%
        'UNCHECKED',       #%
        'YES',             #%
      );


    my @NsdkInstruction=
      (
        'BEEP',
        'BREAK',
        'CALL',
        'CALLH',
        'CAPTURE',
        'CHANGE',
        'CLOSE',
        'COMMENT',
        'CONST',
        'CONTINUE',
        'DELETE',
        'DISABLE',
        'DISPOSE',
        'ELSE',
        'ELSEIF',
        'ENABLE',
        'ENDEVALUATE',
        'ENDFOR',
        'ENDFUNCTION',
        'ENDIF',
        'ENDINSTRUCTION',
        'ENDLOOP',
        'ENDSEGMENT',
        'ENDWHERE',
        'ENDWHILE',
        'EVALUATE',
        'EXIT',
        'FILL',
        'FOR',
        'FUNCTION',
        'GETPROC',
        'GLOBAL',
        'HALT',
        'HIDE',
        'IF',
        'INCLUDE',
        'INSERT',
        'INSTRUCTION',
        'INVALIDATE',
        'LOAD',
        'LOADDLL',
        'LOCAL',
        'LOCK',
        'LOOP',
        'MAXIMIZE',
        'MESSAGE',
        'MINIMIZE',
        'MOV',
        'MOVE',
        'NEW',
        'NOUPDATE',
        'OPEN',
        'OPENH',
        'OPENS',
        'PASS',
        'REPEAT',
        'RESTORE',
        'RETURN',
        'SAVE',
        'SEGMENT',
        'SELECT',
        'SEND',
        'SETBACKCOL',
        'SETDATA',
        'SETFOCUS',
        'SETFORECOL',
        'SETPOS',
        'SETPTR',
        'SETRANGE',
        'SETTEXT',
        'SHOW',
        'STARTTIMER',
        'STOPTIMER',
        'STRCALL',
        'STRCALLH',
        'STROPEN',
        'STROPENH',
        'STROPENS',
        'UNCAPTURE',
        'UNLOADDLL',
        'UNLOCK',
        'UNSELECT',
        'UNTIL',
        'UPDATE',
        'WAIT',
        'WHERE',
        'WHILE'
     );

    my @NsdkOperateur=
      (
        'ABS',
        'AND',
        'BAND',
        'BNOT',
        'BXOR',
        'HIB',
        'HIW',
        'INT',
        'LENGTH',
        'LOB',
        'LOW',
        'LOWCASE',
        'LSKIP',
        'NOT',
        'NUM',
        'OR',
        'RSKIP',
        'SIZEOF',
        'SKIP',
        'STRING',
        'UPCASE'
      );

    my @NsdkSeparateur=
      (
        'ASCENDING',
        'AT',
        'DESCENDING',
        'DYNAMIC',
        'END',
        'EXTERNAL',
        'FROM',
        'RETURN',
        'TO',
        'USING'
     );

    my $status = 0;

    my $deb = 0;
    my $end = 0;
    my $lastLine = 1;

    my %hFunc = ();
    my %hOp = ();
    my %hSep = ();
    my %hTyp = ();
    my %hInst = ();
    my %hConst = ();
    my %hSym = ();

    my $nbFunc = 0;
    my $nbInst = 0;
    my $nbSep = 0;
    my $nbOp = 0;
    my $nbTyp = 0;
    my $nbConst = 0;
    my $nbSym = 0;
    my $totalSym = 0;

    my $nbDistinct = 0;
    my $nbWord = 0;

    my $nbKey = 0;
  
    my $code = $vue->{'code'};
  
    if ( ! defined $code )
    {
        $status |= Couples::counter_add($compteurs, Ident::Alias_Words(), Erreurs::COMPTEUR_ERREUR_VALUE );
        $status |= Couples::counter_add($compteurs, "Nbr_Distinct", Erreurs::COMPTEUR_ERREUR_VALUE );
        return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    $code =~ s/\)/ /g; # on ne compte que les parentheses ouvrantes
    
    # Remplacement des operateurs composes de 2 symboles
    if ( $nbSym = ( $code =~ s/(<>)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(<=)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(>=)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(&&)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(\.\.)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    # Remplacement des operateurs composes de 1 symbole
#    if ( $nbSym = ( $code =~ s/(!)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
#    if ( $nbSym = ( $code =~ s/(%)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(&)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(\*)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(\+)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(,)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(-)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(\.)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(\/)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(<)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(=)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(>)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
    if ( $nbSym = ( $code =~ s/(\()/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
#    if ( $nbSym = ( $code =~ s/(\?)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
#    if ( $nbSym = ( $code =~ s/(\^)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
#    if ( $nbSym = ( $code =~ s/(\|)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}
#    if ( $nbSym = ( $code =~ s/({)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}  #} bidon pour balance
#    if ( $nbSym = ( $code =~ s/(;)/§/g )) { $nbDistinct++; $hSym{$1}=$nbSym; $totalSym += $nbSym;}

    for my $sep (@NsdkSeparateur)
    {
        $nbKey = ($code =~ s/\b$sep\b/§/gi);
        if ($nbKey != 0)
        {
            $nbDistinct++;
            $hSep{$sep} = $nbKey;
            $nbSep += $nbKey;
        }
    }

    for my $oper (@NsdkOperateur)
    {
        $nbKey = ($code =~ s/\b$oper\b/§/gi);
        if ($nbKey != 0)
        {
            $nbDistinct++;
            $hOp{$oper} = $nbKey;
            $nbOp += $nbKey;
        }
    }

    for my $cst (@NsdkConst)
    {
        $nbKey = ($code =~ s/\b$cst\W/§/gi);
        if ($nbKey != 0)
        {
            $nbDistinct++;
            $hConst{$cst} = $nbKey;
            $nbConst += $nbKey;
        }
    }

    for my $func (@NsdkFunction)
    {
        $nbKey = ($code =~ s/\b$func\W/§/gi);
        if ($nbKey != 0)
        {
            $nbDistinct++;
            $hFunc{$func} = $nbKey;
            $nbFunc += $nbKey;
        }
    }

    for my $inst (@NsdkInstruction)
    {
        $nbKey = ($code =~ s/\b$inst\b/§/gi);
        if ($nbKey != 0)
        {
            $nbDistinct++;
            $hInst{$inst} = $nbKey;
            $nbInst += $nbKey;
        }
    }

    for my $typ (@NsdkType)
    {
        $nbKey = ($code =~ s/\b$typ\b/§/gi);
        if ($nbKey != 0)
        {
            $nbDistinct++;
            $hTyp{$typ} = $nbKey;
            $nbTyp += $nbKey;
        }
    }
    $code =~ s/$RE_TYPE/ /g; # FIXME: un peu violent avec le % de modulo

    # traitement des symboles supposes applicatifs
    my $item;
    my %hOthers =();
    my $nbOthers = 0;
    while ( $code =~ /(\w+)/g )
    {
        $item = $1;
        $nbOthers++;
        if (! defined $hOthers{$item} )
        {
            $nbDistinct++;
            $hOthers{$item} = 1;
        }
        else
        {
            $hOthers{$item} += 1;
        }
    }    
my $debug = 0; # Erreurs::LogInternalTraces
if ($debug != 0) # Erreurs::LogInternalTraces
{ # Erreurs::LogInternalTraces
    my %tbAll = (  # Erreurs::LogInternalTraces
                 "Symboliques" => \%hSym, # Erreurs::LogInternalTraces
                 "Separateurs" => \%hSep, # Erreurs::LogInternalTraces
                 "Operateurs" => \%hOp, # Erreurs::LogInternalTraces
                 "Constantes" => \%hConst, # Erreurs::LogInternalTraces
                 "Fonctions" => \%hFunc, # Erreurs::LogInternalTraces
                 "Instructions" => \%hInst, # Erreurs::LogInternalTraces
                 "Types" => \%hTyp, # Erreurs::LogInternalTraces
                 "Applicatifs" => \%hOthers # Erreurs::LogInternalTraces
                ); # Erreurs::LogInternalTraces
    my $nbAll = 0; # Erreurs::LogInternalTraces
    my $nbDiff= 0; # Erreurs::LogInternalTraces
    while ( my ($categ , $refMem) = each %tbAll ) # Erreurs::LogInternalTraces
    { # Erreurs::LogInternalTraces
        my %hTab = %{$refMem}; # Erreurs::LogInternalTraces
        my $sum = 0; # Erreurs::LogInternalTraces
        my $distincts = 0; # Erreurs::LogInternalTraces
        print STDERR "\nDetection de $categ :\n"; # Erreurs::LogInternalTraces
        for my $cle (keys %hTab) # Erreurs::LogInternalTraces
        { # Erreurs::LogInternalTraces
            $sum += $hTab{$cle}; # Erreurs::LogInternalTraces
            $distincts++; # Erreurs::LogInternalTraces
            print STDERR $cle . " : " . $hTab{$cle} . "\n"; # Erreurs::LogInternalTraces
        } # Erreurs::LogInternalTraces
        print STDERR "Total dans la categorie $categ : $sum\n"; # Erreurs::LogInternalTraces
        print STDERR "Distincts dans la categorie $categ : $distincts\n"; # Erreurs::LogInternalTraces
        $nbAll += $sum; # Erreurs::LogInternalTraces
        $nbDiff += $distincts; # Erreurs::LogInternalTraces
        print STDERR "--------\n"; # Erreurs::LogInternalTraces
    } # Erreurs::LogInternalTraces
    print STDERR "TOTAL : $nbAll \t DISTINCTS : $nbDiff\n"; # Erreurs::LogInternalTraces
}# Erreurs::LogInternalTraces

    $nbWord = $totalSym + $nbFunc + $nbTyp + $nbConst + $nbInst + $nbSep + $nbOp + $nbOthers;

    Erreurs::LogInternalTraces("TRACE", $fichier, 1, Ident::Alias_Words(), "", $totalSym . " operateurs symboliques");
    Erreurs::LogInternalTraces("TRACE", $fichier, 1, Ident::Alias_Words(), "", $nbSep . " separateurs");
    Erreurs::LogInternalTraces("TRACE", $fichier, 1, Ident::Alias_Words(), "", $nbOp . " operateurs");
    Erreurs::LogInternalTraces("TRACE", $fichier, 1, Ident::Alias_Words(), "", $nbConst . " constantes");
    Erreurs::LogInternalTraces("TRACE", $fichier, 1, Ident::Alias_Words(), "", $nbFunc . " fonctions");
    Erreurs::LogInternalTraces("TRACE", $fichier, 1, Ident::Alias_Words(), "", $nbInst . " instructions");
    Erreurs::LogInternalTraces("TRACE", $fichier, 1, Ident::Alias_Words(), "", $nbTyp . " types");
    Erreurs::LogInternalTraces("TRACE", $fichier, 1, Ident::Alias_Words(), "", $nbOthers . " mots applicatifs");

    Erreurs::LogInternalTraces("TRACE", $fichier, 1, Ident::Alias_DistinctWords(), "", $nbDistinct . " mots distincts");

    $status |= Couples::counter_add($compteurs, Ident::Alias_Words(), $nbWord);
    $status |= Couples::counter_add($compteurs, Ident::Alias_DistinctWords(), $nbDistinct);

    print STDERR "RESTE dans $fichier apres substitution de CountWords : \n" . $code . "-------------\n"if ($debug != 0); # Erreurs::LogInternalTraces

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountKeywordCase($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;

    my $status = 0;
    my $nbNotUpCase = 0;
    my $nbKeys = 0;

    my $deb = 0;
    my $end = 0;
    my $lastLine = 1;

  
    my $code = $vue->{'code'};
  
    # ci-dessous, l'indentation sert de separateur de rubriques
    # 1) separateurs (ASCENDING -> USING)
    # 2) constantes pre-definies (CANCEL -> YES)
    # 3) operateurs (ABS -> UPCASE)
    # 4) les instructions (BEEP- > WHILE)
    # 5) les fonctions (ASC- > WORD)
    # 6) types (CHAR, CONTROL, CSTRING)
    while ($code =~ /\b(
                       ASCENDING|
                       AT|
                       DESCENDING|
                       DYNAMIC|
                       END|
                       EXTERNAL|
                       FROM|
                       RETURN|
                       TO|
                       USING|
                         CANCEL|
                         CHECKED|
                         DEFRET|
                         FALSE|
                         INDETERMINATE|
                         NO|
                         NOSELECTION|
                         TRUE|
                         UNCHECKED|
                         YES|
                           ABS|
                           AND|
                           BAND|
                           BNOT|
                           BXOR|
                           HIB|
                           HIW|
                           INT|
                           LENGTH|
                           LOB|
                           LOW|
                           LOWCASE|
                           LSKIP|
                           NOT|
                           NUM|
                           OR|
                           RSKIP|
                           SIZEOF|
                           SKIP|
                           STRING|
                           UPCASE|
                             BEEP|
                             BREAK|
                             CALL|
                             CALLH|
                             CAPTURE|
                             CHANGE|
                             CLOSE|
                             COMMENT|
                             CONST|
                             CONTINUE|
                             DELETE|
                             DISABLE|
                             DISPOSE|
                             ELSE|
                             ELSEIF|
                             ENABLE|
                             ENDEVALUATE|
                             ENDFOR|
                             ENDFUNCTION|
                             ENDIF|
                             ENDINSTRUCTION|
                             ENDLOOP|
                             ENDSEGMENT|
                             ENDWHERE|
                             ENDWHILE|
                             EVALUATE|
                             EXIT|
                             FILL|
                             FOR|
                             FUNCTION|
                             GLOBAL|
                             HALT|
                             HIDE|
                             IF|
                             INCLUDE|
                             INSERT|
                             INSTRUCTION|
                             INVALIDATE|
                             LOAD|
                             LOADDLL|
                             LOCAL|
                             LOCK|
                             LOOP|
                             MAXIMIZE|
                             MESSAGE|
                             MINIMIZE|
                             MOV|
                             MOVE|
                             NEW|
                             NOUPDATE|
                             OPEN|
                             OPENH|
                             OPENS|
                             PASS|
                             REPEAT|
                             RESTORE|
                             RETURN|
                             SAVE|
                             SEGMENT|
                             SELECT|
                             SEND|
                             SETBACKCOL|
                             SETDATA|
                             SETFOCUS|
                             SETFORECOL|
                             SETPOS|
                             SETPTR|
                             SETRANGE|
                             SETTEXT|
                             SHOW|
                             STARTTIMER|
                             STOPTIMER|
                             STRCALL|
                             STRCALLH|
                             STROPEN|
                             STROPENH|
                             STROPENS|
                             UNCAPTURE|
                             UNLOADDLL|
                             UNLOCK|
                             UNSELECT|
                             UNTIL|
                             UPDATE|
                             WAIT|
                             WHERE|
                             WHILE|
                               ASC|
                               ASK2|
                               ASK3|
                               CHR|
                               COPY|
                               DELETE|
                               DWORD|
                               FILLER|
                               GETBACKCOL|
                               GETCLIENTHEIGHT|
                               GETCLIENTWIDTH|
                               GETDATA|
                               GETFORECOL|
                               GETHEIGHT|
                               GETPROC|
                               GETSPTR|
                               GETTEXT|
                               GETWIDTH|
                               GETXPOS|
                               GETYPOS|
                               INSERT|
                               ISDISABLED|
                               ISHIDDEN|
                               ISINT|
                               ISLOCKED|
                               ISMAXIMIZED|
                               ISMINIMIZED|
                               ISMOUSE|
                               ISNUM|
                               ISSELECTED|
                               LINECOUNT|
                               MAINWINDOW|
                               NBBUTTONS|
                               PARAM1|
                               PARAM2|
                               PARAM3|
                               PARAM4|
                               PARAM12|
                               PARAM34|
                               PARENTWINDOW|
                               POS|
                               ROUND|
                               SCREENHEIGHT|
                               SCREENWIDTH|
                               SELECTION|
                               SELF|
                               TRUNC|
                               WORD|
                      CHAR|
                      CONTROL|
                      CSTRING
           )\b/gix)
    {
        $end = pos($code);
        my $keyword = $1;

        my $chaine = substr($code, $deb, $end - $deb);
        my $lignes = ($chaine =~ tr/\n/\n/);
        $chaine =~ s/.*\n//g if ($lignes != 0);
    
        $lastLine += $lignes;

        if ($keyword ne uc($keyword))
        {
            $nbNotUpCase++;
            Erreurs::LogInternalTraces("TRACE", $fichier, $lastLine, Ident::Alias_BadCaseKeyword(), $chaine, "Mot-cle pas en majuscule (" . $keyword . ")");
        }
        else
        {
            Erreurs::LogInternalTraces("TRACE", $fichier, $lastLine, Ident::Alias_Keywords(), $chaine, "Mot-cle (" . $keyword . ")");
        }
        $deb = $end;
        $nbKeys++;
    }
    $status |= Couples::counter_add($compteurs, Ident::Alias_BadCaseKeyword(), $nbNotUpCase);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Keywords(), $nbKeys);

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CheckIndent($$$)
{
    my ($fichier, $vues, $compteurs) = @_;

    my $code = $vues->{'code'};

    my $status = 0;

    my $deb = 0;         # position de debut de la ligne de code courante
    my @tabIndent = ( ); # memorisation des indentations de toutes lignes par niveaux logiques
    my @tbKIndent = ( ); # memorisation des indentations de mot-cles de changements de niveau logique
    my $indent = 0;      # indentation calculee pour la ligne courante
    my $nextLevel = 0;   # niveau logique attendu pour la ligne de code suivante
    my $prevLevel = 0;   # niveau logique calcule pour la ligne de code precedente
    my $level = 0;       # niveau logique courant
    my $codeLines = 0;   # cumul du nombre de lignes de code non vide
    my $codeLinesOk = 0; # nombre de lignes de code correctement indentees
    my $waitIn = 0;      # booleen d'attente du mot-cle in apres le mot-cle case
    my $totalLines = 0;  # nombre de lignes lues dans le code source
    my @caseEntryLevels = ( ); # memorisation booleenne des niveaux logiques
                               # presentant des entrees de cas dans une structure
                               # EVALUATE/ENDEVALUATE

    my $nbThen= 0;
    my $nbDo = 0;
    my $nbCase = 0;
    my $nbSwitch = 0;
    my $nbDefault = 0;
    my $nbComponent = 0;
    my $nbSeg = 0;
    my $nbKeyIndentOk = 0;
    my $nbChgLevelKey = 0;

    use constant CASE_TYP_NONE => 0;
    use constant CASE_TYP_WAITING => 1;
    use constant CASE_TYP_WHERE => 2;
    use constant CASE_TYP_ELSE => 3;

    $caseEntryLevels[0] = CASE_TYP_NONE;

    while ($code =~ m{\n}g)
    {
        $totalLines++;
        my $end = pos($code);
        my $ligne = substr($code, $deb, $end - $deb);

        if ( $ligne =~ m{\A\s*\n\Z} )
        {
            # ligne vide
            $deb = $end;
            next;
        }

        $codeLines++;

        # calcul indentation
        if ($ligne =~ /\A(\s*).*/)
        {
            if (defined $1)
            {
                $indent = length($1);
            }
            else
            {
                $indent = 0;
            }
        }
        else
        {
            print STDERR "Ligne suspecte : " . $ligne;
            $indent = 0;
        }

        # determination des niveaux logiques courant et prochain

        my $isKey = 1; # cet indicateur doit rester vrai si un des identificateur de mot-cle
                       # recherche ci-dessous est trouve
        if ($ligne =~ /\A\s*EVALUATE\b/i)
        {
            $nextLevel = $level + 1;
            $caseEntryLevels[$nextLevel] = CASE_TYP_WAITING;
            $nbSwitch++;
        }
        elsif ($ligne =~ /\A\s*WHERE\b/i)
        {
            if ($caseEntryLevels[$level] == CASE_TYP_NONE)
            {
                print STDERR "WHERE inattendu hors d'une structure EVALUATE\n";
                Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "WHERE inattendu au niveau $level");
            }
            elsif ($level > 1 && $caseEntryLevels[$level - 1] == CASE_TYP_ELSE)
            {
                print STDERR "WHERE inattendu apres ELSE\n";
                Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "WHERE inattendu apres ELSE au niveau $level");
            }
            else
            {
#                Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "WHERE attendu au niveau $level");
                $caseEntryLevels[$level] = CASE_TYP_WHERE;
                $nbCase++;
                $nextLevel = $level + 1;
                $caseEntryLevels[$nextLevel] = CASE_TYP_NONE;
            }
        }
        elsif ($ligne =~ /\A\s*ENDWHERE/i)
        {
            $level-- if ($level > 0);
            $nextLevel = $level;
            Erreurs::LogInternalTraces ("ERROR", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "WHERE inattendu au niveau $level") if ($caseEntryLevels[$level] != CASE_TYP_WHERE);
        }
        elsif ($ligne =~ /\A\s*ELSE\b/i)
        {
            if ($caseEntryLevels[$level] == CASE_TYP_NONE)
            {
                $level-- if ($level > 0);
                $nextLevel = $level + 1;
                $caseEntryLevels[$nextLevel] = CASE_TYP_NONE;
                $nbThen++;
#                Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "ELSE probablement dans une structure IF/ENDIF au niveau $level");
            }
            elsif ($caseEntryLevels[$level] == CASE_TYP_ELSE)
            {
                print STDERR "ELSE inattendu apres ELSE\n";
                Erreurs::LogInternalTraces ("ERROR", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "ELSE inattendu apres ELSE au niveau $level");
            }
            elsif ($caseEntryLevels[$level] == CASE_TYP_WAITING)
            {
                print STDERR "ELSE inattendu non precede de WHERE\n";
                Erreurs::LogInternalTraces ("ERROR", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "ELSE inattendu non precede de WHERE au niveau $level");
            }
            else
            {
                # ELSE precede d'un ENDWHERE
#                Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "ELSE attendu au niveau $level");
                $caseEntryLevels[$level] = CASE_TYP_ELSE;
                $nbDefault++;
                $nextLevel = $level + 1;
                $caseEntryLevels[$nextLevel] = CASE_TYP_NONE;
            }
        }
        elsif ($ligne =~ /\A\s*ENDEVALUATE\b/i)
        {
            if ( ($caseEntryLevels[$level] == CASE_TYP_NONE)
                &&
                 ($level > 1 && $caseEntryLevels[$level - 1] == CASE_TYP_ELSE)
               )
            {
                # la ligne precedente appartient au traitement
                # du cas par defaut de la structure EVALUATE/ENDEVALUATE
                $level -= 2;
                $nextLevel = $level;
#               Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "ENDEVALUATE attendu apres ELSE au niveau $level");
            }
            elsif ($caseEntryLevels[$level] == CASE_TYP_WHERE)
            {
                # la ligne precedente appartient au traitement
                # d'un cas explicite de la structure EVALUATE/ENDEVALUATE
                $level-- if ($level > 0);
                $nextLevel = $level;
#                Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "ENDEVALUATE attendu apres WHERE au niveau $level");
            }
            elsif ($caseEntryLevels[$level] == CASE_TYP_WAITING)
            {
                $level-- if ($level > 0);
                $nextLevel = $level;
                Erreurs::LogInternalTraces ("WARNING", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "fermeture de EVALUATE vide au niveau $level");
            }
            else
            {
                print STDERR "ENDEVALUATE inattendu hors structure EVALUATE\n";
                Erreurs::LogInternalTraces ("ERROR", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "ENDEVALUATE inattendu au niveau $level");
                #$level-- if ($level > 0);
                #$nextLevel = $level;
            }
            # apres fermeture d'une structure EVALUATE/ENDEVALUATE, on re-initialise
            # les entrees des niveaux logiques imbriques 
            # dans le tableau caseEntryLevels
            for (my $supLevel = $level + 1; $supLevel <= $#caseEntryLevels; $supLevel++)
            {
                $caseEntryLevels[$supLevel] = CASE_TYP_NONE;
            }
        }
        elsif ($ligne =~ /\A\s*IF\b/i)
        {
            $nbThen++;
            $nextLevel = $level + 1;
            $caseEntryLevels[$nextLevel] = CASE_TYP_NONE;
        }
        elsif ($ligne =~ /\A\s*ELSEIF\b/i)
        {
            $nbThen++;
            $level-- if ($level > 0);
            $nextLevel = $level + 1;
            $caseEntryLevels[$nextLevel] = CASE_TYP_NONE;
        }
        elsif ($ligne =~ /\A\s*ENDIF\b/xi)
        {
            # fermeture d'une structure IF/[ELSEIFi...]/[ELSE...]/ENDIF
            $level-- if ($level > 0);
            $nextLevel = $level;
        }
        elsif ($ligne =~ /\A\s*(LOOP|REPEAT|WHILE|FOR)\b/xi)
        {
            # ouverture d'une boucle
            $nextLevel = $level + 1;
            $caseEntryLevels[$nextLevel] = CASE_TYP_NONE;
            $nbDo++;
        }
        elsif ($ligne =~ /\A\s*(ENDLOOP|UNTIL|ENDWHILE|ENDFOR)\b/xi)
        {
            # fermeture d'une boucle
            $level-- if ($level > 0);
            $nextLevel = $level;
        }
        elsif ($ligne =~ /\A\s*(FUNCTION|INSTRUCTION)\b/xi && $ligne !~ /\b(EXTERNAL|DYNAMIC)\b/xi)
        {
            $nextLevel = $level + 1;
            $caseEntryLevels[$nextLevel] = CASE_TYP_NONE;
            Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "Debut de FUNCTION ou INSTRUCTION au niveau $level");
            $nbComponent++;
        }
        elsif ($ligne =~ /\A\s*END(FUNCTION|INSTRUCTION)\b/xi)
        {
            $level-- if ($level > 0);
            $nextLevel = $level;
            Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "Fin de FUNCTION ou INSTRUCTION au niveau $level");
        }
        elsif ($ligne =~ /\A\s*SEGMENT\b/xi)
        {
            $nextLevel = $level + 1;
            $caseEntryLevels[$nextLevel] = CASE_TYP_NONE;
            Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "Debut de SEGMENT au niveau $level");
            $nbSeg++;
        }
        elsif ($ligne =~ /\A\s*ENDSEGMENT\b/xi)
        {
            $level-- if ($level > 0);
            $nextLevel = $level;
            Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "Fin de SEGMENT au niveau $level");
        }
        else
        {
            $isKey = 0;
        }


        #print STDERR "Niveau : $level Prochain : $nextLevel\n" if ($debug != 0);

        # verification de l'indentation de la ligne
        # en fonction de son niveau logique

        my $indentLOk = 0;
        if ($level > $#tabIndent)
        {
            # niveau de profondeur jamais atteint
            if ($#tabIndent >= 0)
            {
                # niveau superieur connu
                if ($indent > $tabIndent[$level-1])
                {
                    $indentLOk = 1;
                    #$codeLinesOk++;
                }
                else
                {
                    # niveau mal indentee : indentation <= celle du niveau imbriquant
                    Erreurs::LogInternalTraces ("TRACE", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "indentation ($indent) pour niveau $level <= celle du niveau precedent");
                }
            }
            else
            {
                # 1ere ligne de code
                $indentLOk = 1;
                #$codeLinesOk++;
            }
            # meme si le 1ere ligne d'un niveau est mal indentee
            # elle va servir de reference pour ce niveau
            $tabIndent[$level] = $indent;
            Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "Indentation $indent pour niveau $level");
        }
        elsif ($indent == $tabIndent[$level])
        {
            if ($level > $prevLevel && $indent <= $tabIndent[$level-1])
            {
                # cette ligne est la 1ere d'un bloc imbrique et n'est pas decalee
                # vers la droite par rapport au niveau logique imbriquant;
                # on ne la compte pas comme bien indentee (meme si cette erreur
                # a deja ete rencontree pour un bloc logique de meme profondeur)
                Erreurs::LogInternalTraces ("TRACE", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "bloc de niveau $level non decale a droite ($indent)");
            }
            else
            {
                $indentLOk = 1;
                #$codeLinesOk++;
            }
        }
        elsif ($level > 0 && $tabIndent[$level-1] >= $tabIndent[$level]
                          && $indent > $tabIndent[$level-1])
        {
            # on essaie de rattraper une mauvaise indentation en debut de niveau
            $tabIndent[$level] = $indent;
            Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "Rattrapage mauvaise indentation niveau $level devient $indent\n");
            $indentLOk = 1;
            #$codeLinesOk++;
        }
        else
        {
            Erreurs::LogInternalTraces ("TRACE", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "Ligne (niveau $level) mal indentee ($indent) (cas desespere)");
            # meme si l'homogeneite de l'indentation du fichier est critiquable
            # peut-etre les lignes suivantes du meme niveau logique vont-elles
            # suivre ce nouveau pas d'indentation
            $tabIndent[$level] = $indent; # pas trop exigeant ...
        }
        if ($indentLOk != 0)
        {
            $codeLinesOk += (($ligne =~ s/$contSep/§/g) + 1);
        }

        # verification de l'indentation d'un mot-cle de changement
        # de niveau logique
        if ($isKey != 0)
        {
            $nbChgLevelKey++;
            if ($level > $#tbKIndent)
            {
                $tbKIndent[$level] = $indent;
                Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "Indentation $indent pour changement de niveau depuis niveau $level");
                $nbKeyIndentOk++;
            }
            elsif ($indent != $tbKIndent[$level])
            {
                Erreurs::LogInternalTraces ("TRACE", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "Mauvaise indentation (" . $indent . " etait " . $tbKIndent[$level] . ") de changement niveau pour niveau $level");
                $tbKIndent[$level] = $indent; # forcage de cette nouvelle indentation pour ce niveau logique
            }
            else
            {
                $nbKeyIndentOk++;
            }
        }

        $prevLevel = $level;
        $level = $nextLevel;
        $deb = $end;
    }


#    $status |= Couples::counter_add($compteurs, Ident::Alias_LinesOfCode(), $codeLines);
    $status |= Couples::counter_add($compteurs, Ident::Alias_IndentedLines(), $codeLinesOk);
    $status |= Couples::counter_add($compteurs, Ident::Alias_TotalLogicIndents(), $nbChgLevelKey);
    $status |= Couples::counter_add($compteurs, Ident::Alias_BadLogicIndents(), ($nbChgLevelKey - $nbKeyIndentOk));

#    $status |= Couples::counter_add($compteurs, Ident::Alias_Then(), $nbThen);
#    $status |= Couples::counter_add($compteurs, Ident::Alias_Do(), $nbDo);
#    $status |= Couples::counter_add($compteurs, Ident::Alias_Case(), $nbCase);
#    $status |= Couples::counter_add($compteurs, Ident::Alias_Switch(), $nbSwitch);
#    $status |= Couples::counter_add($compteurs, Ident::Alias_Default(), $nbDefault);

    Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), "", $nbSwitch . " Evaluate  " . $nbCase . " Where  " .  $nbDefault . " Else de Where  " . $nbDo .  " boucles  " . $nbThen . " If ou Elseif  " . $nbComponent . " Function ou Instruction  " . $nbSeg . " Segments");
    Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), "", $nbChgLevelKey . " mots-cles de changement de niveau logique");
    Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), "", $nbKeyIndentOk . " mots-cles de changement de niveau logique bien indentes");

    #$debug = $saveDebug;

    return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountCommentedOutCode($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;

    my $nbCmtCode = 0;
    my $status = 0;

    my $lastLine = 0;
  
    my $cmt = $vue->{'comment'};
  
    while ($cmt =~ /([^\n]*)\n/g)
    {
        $lastLine++;
        my $ligne = $1;
        # listes indentees :
        # 1) instructions
        # 2) operateurs
        # 3) separateurs
        # 4) fonctions
        # 5) types
        if ($ligne =~ /\A\s*;[\s;]*\b(
            BEEP|
            BREAK|
            CALL|
            CALLH|
            CHANGE|
            CLOSE|
            COMMENT|
            CONST|
            CONTINUE|
            DELETE|
            DISABLE|
            DISPOSE|
            ELSE|
            ELSEIF|
            ENABLE|
            ENDEVALUATE|
            ENDFOR|
            ENDFUNCTION|
            ENDIF|
            ENDINSTRUCTION|
            ENDLOOP|
            ENDSEGMENT|
            ENDWHERE|
            ENDWHILE|
            EVALUATE|
            EXIT|
            FILL|
            FOR|
            FUNCTION|
            GLOBAL|
            HALT|
            HIDE|
            IF|
            INCLUDE|
            INSERT|
            INSTRUCTION|
            INVALIDATE|
            LOAD|
            LOADDLL|
            LOCAL|
            LOCK|
            LOOP|
            MAXIMIZE|
            MINIMIZE|
            MOV|
            MOVE|
            NEW|
            NOUPDATE|
            OPEN|
            OPENH|
            OPENS|
            PASS|
            REPEAT|
            RESTORE|
            RETURN|
            SAVE|
            SELECT|
            SEND|
            SETBACKCOL|
            SETDATA|
            SETFOCUS|
            SETFORECOL|
            SETPOS|
            SETPTR|
            SETRANGE|
            SETTEXT|
            SHOW|
            STARTTIMER|
            STOPTIMER|
            STRCALL|
            STRCALLH|
            STROPEN|
            STROPENH|
            STROPENS|
            UNCAPTURE|
            UNLOADDLL|
            UNLOCK|
            UNSELECT|
            UNTIL|
            UPDATE|
            WAIT|
            WHERE|
            WHILE|
              ABS|
              AND|
              BAND|
              BNOT|
              BXOR|
              HIB|
              HIW|
              LENGTH|
              LOB|
              LOW|
              LOWCASE|
              LSKIP|
              NOT|
              OR|
              RSKIP|
              SIZEOF|
              SKIP|
              STRING|
              UPCASE|
                ASCENDING|
                AT|
                DESCENDING|
                DYNAMIC|
                END|
                EXTERNAL|
                FROM|
                RETURN|
                TO|
                USING|
                    ASC|
                    ASK2|
                    ASK3|
                    CHR|
                    COPY|
                    DELETE|
                    DWORD|
                    FILLER|
                    GETBACKCOL|
                    GETCLIENTHEIGHT|
                    GETCLIENTWIDTH|
                    GETDATA|
                    GETFORECOL|
                    GETHEIGHT|
                    GETPROC|
                    GETSPTR|
                    GETTEXT|
                    GETWIDTH|
                    GETXPOS|
                    GETYPOS|
                    ISDISABLED|
                    ISHIDDEN|
                    ISINT|
                    ISLOCKED|
                    ISMAXIMIZED|
                    ISMINIMIZED|
                    ISMOUSE|
                    ISNUM|
                    ISSELECTED|
                    LINECOUNT|
                    MAINWINDOW|
                    NBBUTTONS|
                    PARENTWINDOW|
                    POS|
                    ROUND|
                    SCREENHEIGHT|
                    SCREENWIDTH|
                    SELF|
                    TRUNC|
                    WORD|
                      CHAR|
                      CONTROL|
                      CSTRING
           )\b(.*)/ix)
       # otes de la liste des instructions
#    CAPTURE| 
#    MESSAGE|
#    SEGMENT|
       # otes de la liste des operateurs
#            INT|
#            NUM|

       # otes de la liste des fonctions
#                    PARAM1|
#                    PARAM2|
#                    PARAM3|
#                    PARAM4|
#                    PARAM12|
#                    PARAM34|
#                    SELECTION|
        {
            Erreurs::LogInternalTraces("TRACE", $fichier, $lastLine, Ident::Alias_CommentedOutCode(), $ligne, "Code en commentaire (" . $1 . ")");
            $nbCmtCode++;
        }
    }
    $status |= Couples::counter_add($compteurs, Ident::Alias_CommentedOutCode(), $nbCmtCode);

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
	  ( ! defined $compteurs->{Ident::Alias_Loop()}) || 
	  ( ! defined $compteurs->{Ident::Alias_Repeat()}) || 
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
	       $compteurs->{Ident::Alias_Loop()} +
	       $compteurs->{Ident::Alias_Repeat()} +
	       $compteurs->{Ident::Alias_FunctionMethodImplementations()};
    }

    $status |= Couples::counter_add($compteurs, $VG__mnemo, $nb_VG);
}


1;

