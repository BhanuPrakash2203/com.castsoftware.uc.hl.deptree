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

package CountCS;

# les modules importes
use strict;
use warnings;
use Erreurs;
use Couples;
use CountUtil;
use CountBinaryFile;
use CountBreakLoop;

#-------------------------------------------------------------------------------
# Module de comptage des mots cles
#-------------------------------------------------------------------------------
sub CountKeywords($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $status = 0;

  my $sansprepro = \$vue->{'sansprepro'};

  $status |= CountItem('using', Ident::Alias_Using(), $sansprepro, $compteurs);
  $status |= CountItem('if', Ident::Alias_If(), $sansprepro, $compteurs);
  $status |= CountItem('else', Ident::Alias_Else(), $sansprepro, $compteurs);
  $status |= CountItem('while', Ident::Alias_While(), $sansprepro, $compteurs);
  $status |= CountItem('for', Ident::Alias_For(), $sansprepro, $compteurs);
  $status |= CountItem('foreach', Ident::Alias_Foreach(), $sansprepro, $compteurs);
  $status |= CountItem('continue', Ident::Alias_Continue(), $sansprepro, $compteurs);
  $status |= CountItem('switch', Ident::Alias_Switch(), $sansprepro, $compteurs);
  $status |= CountItem('default', Ident::Alias_Default(), $sansprepro, $compteurs);
  $status |= CountItem('try', Ident::Alias_Try(), $sansprepro, $compteurs);
  $status |= CountItem('catch', Ident::Alias_Catch(), $sansprepro, $compteurs);
  $status |= CountItem('exit', Ident::Alias_Exit(), $sansprepro, $compteurs);
  $status |= CountItem('is', Ident::Alias_Instanceof(), $sansprepro, $compteurs);
  $status |= CountItem('new', Ident::Alias_New(), $sansprepro, $compteurs);
  $status |= CountItem('case', Ident::Alias_Case(), $sansprepro, $compteurs);

  return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountIllegalThrows {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $status = 0;

  my $Nbr_IllegalThrow = 0;

  if ( ! defined $vue->{'code'} ) {
    $status |= Couples::counter_add($compteurs, Ident::Alias_IllegalThrows(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  while ($vue->{'code'} =~ /\bthrow\b([^;]*);/sg ) {
    my $exception = $1;
    if ( $exception =~ /SystemException/ ) {
      $Nbr_IllegalThrow++;
    }
  }

  $status |= Couples::counter_add($compteurs, Ident::Alias_IllegalThrows(), $Nbr_IllegalThrow);

  return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountItem($$$$) {
  my ($item, $id, $vue, $compteurs) = @_ ;
  my $status = 0;

#  if ( ! defined $vue->{'code'} ) {
#    $status |= Couples::counter_add($compteurs, $id, Erreurs::COMPTEUR_ERREUR_VALUE );
#    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
#  }

#  my $nb = () = $vue->{'code'} =~ /\b${item}\b/sg ;
  my $nb = () = $$vue =~ /\b${item}\b/sg ;
  $status |= Couples::counter_add($compteurs, $id, $nb);

  return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountAutodocTags ($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $status = 0;
  my $nb_ParamTags=0;
  my $nb_SeeTags=0;
  my $nb_ReturnTags=0;

  if ( ! defined $vue->{comment} ) {
    $status |= Couples::counter_add($compteurs, Ident::Alias_ParamTags(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_SeeTags(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_ReturnTags(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  $nb_ParamTags = () = $vue->{comment} =~ /<[Pp]aram\b/g;
  $nb_SeeTags = () = $vue->{comment} =~ /<[Ss]ee\b/g;
  $nb_ReturnTags = () = $vue->{comment} =~ /<[Rr]eturns?\b/g;

  $status |= Couples::counter_add($compteurs, Ident::Alias_ParamTags(), $nb_ParamTags );
  $status |= Couples::counter_add($compteurs, Ident::Alias_SeeTags(), $nb_SeeTags );
  $status |= Couples::counter_add($compteurs, Ident::Alias_ReturnTags(), $nb_ReturnTags );

  return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountBugPatterns ($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $status = 0;
  my $nb_BugPatterns = 0;
  my $mnemo_BugPatterns = Ident::Alias_BugPatterns();
  my $code = '';

  if ( (exists $vue->{'prepro'}) && ( defined $vue->{'prepro'} ) ) {
    $code = $vue->{'prepro'};
    Erreurs::LogInternalTraces('DEBUG', $fichier, 1, $mnemo_BugPatterns, "utilisation de la vue prepro.\n");
  }
  else {
    $code = $vue->{'code'};
  }

  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, $mnemo_BugPatterns, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  # Recherche des patterns d'instruction de controle suivants :
  #----------------------------------------------------------
  # while(xxx);
  # for(xxx);
  # if(xxx);

  # Suppression des imbrications de parentheses, afin de virer l'expression conditionnelle qui se trouve entre le mot cle structurel et le debut de bloc
  # qui est cense commencer par une accolade.
  while ( $code =~ s/\b((?:if|for|while|foreach)\s*\([^\)]*)\([^\(\)]*\)/$1 _X_ /sg ) {}

  # Comptage des instructions de controles dont la parenthese fermente est suivie d'un caractere ";"
  $nb_BugPatterns += $code =~ s/\b(if|for|while|foreach)\s*\([^\(\)]*\)\s*;/ ;/sg ;

  # Decomptage du nombre d'instruction "do", celles-ci etant systematiquement associees a un "while(xxx);" qui ne pose pas de probleme dans ce cas..
  $nb_BugPatterns -= $code =~ s/\b(do)\b/ /sg ;

  # Pour la suite, suppression des structure de controle restantes (celles qui n'ont pas un ";" derriere la parenthese fermante ...:
  $code =~ s/\b(if|for|while|foreach)\s*\([^\(\)]*\)/ ;/sg ;

#print STDERR "[BugPattern]  <cond_struct> (xxx); ==> $nb_BugPatterns occurrences trouvees\n";
  Erreurs::LogInternalTraces('TRACE', $fichier, 1, $mnemo_BugPatterns, '<cond_struct> (xxx);', "--> $nb_BugPatterns occurrences trouvees");

  # Recherche du pattern d'instruction *a++, et plus generalement    * ...... ;, lorsqu'il n'y a pas de '=' ni d'appel de fonction dans les '...'
  #----------------------------------------------------------------------------------------------------------------------------------------------
  # Finir d'applatir les parentheses des expressions jusqu'a n'avoir qu'un seul niveau.
  # RQ: lorsque qu'une parenthese contient les caracteres {, } ou ; on en deduit que c'est un jeu de parenthses qui contient du code. Ce niveau de
  # parenthses est donc ignore (i.e. on ne l'aplatie pas).
  # On veut applatir : ( <!bloc instructions> ( <!bloc instructions> )   ===> ( <!bloc instructions>  _X_ )
  while ( $code =~ s{(                       # Capture = $1
                       \(                         # Premier niveau de parentheses
                         [^\(\)\{\}\;]*           # N'importe quoi sauf des parentheses ou des signes traduisant la presence d'un bloc d'instructions de code.
                       )
                       \(                    # Deuxieme niveau de parentheses.
                         [^\(\)\{\}\;]*           # N'importe quoi sauf des parentheses ou des signes traduisant la presence d'un bloc d'instructions de code.
                       \)
                    }
                    {$1 _X_ }sgx ) {}

  # Les parentheses de controles ont ete supprimees aupravant.
  # Donc, il n'existe partout plus qu'un seul niveau de parenthses.
  $code =~ s/;/;;/sg ;
  while ( $code =~ /[\}\{;]\s*\*([^=;]*);/sg ) {
    my $instr = $1;
    if ( $instr !~ /(\.|->)\s*\w+\s*\([^\)]*\)/s ) {
      # Si l'expression ne correspond pas a un appel de methode, alors c'est un bug-pattern.
#print STDERR "[BugPattern]  * ... ; ==> occurrences trouvee\n";
      Erreurs::LogInternalTraces('TRACE', $fichier, 1, $mnemo_BugPatterns, '* ... ;', "--> $instr");
    }
  }

  # Finir d'applatir toutes les parentheses ... sauf celles dont la fermente est suivie d'un ';', signe que les parentheses enferment une instruction.
#  while ( $code =~ s/\([^\(\)]*\)\s*[^;\s]//sg ) {}


  # Recherche du pattern d'instruction 'a = a ;'
  #-----------------------------------------------
  while ( $code =~ /[\}\{;\)]\s*([^;=]*=[^;]*)/sg ) {
    my $instr = $1;
    $instr =~ s/[ \t]//g ;
    my ($lvalue, $rvalue) = $instr =~ /([^=]*)=(.*)/s ;
    if ($lvalue eq $rvalue) {
      $nb_BugPatterns++;
#print STDERR "[BugPattern]  a = a ; ==> occurrences trouvee\n";
      Erreurs::LogInternalTraces('TRACE', $fichier, 1, $mnemo_BugPatterns, 'a = a', "--> $instr");
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

#print STDERR "[BugPattern]  a == b ; ==> $nb occurrences trouvee\n";
  Erreurs::LogInternalTraces('TRACE', $fichier, 1, $mnemo_BugPatterns, 'a == b', "--> $nb_BugPatterns occurrences trouvees.");

  $status |= Couples::counter_add($compteurs, $mnemo_BugPatterns, $nb_BugPatterns);

  return $status;
}


#-------------------------------------------------------------------------------
# DESCATIVATED BECAUSE BUGUED !! new version inside CS::CountCS
#-------------------------------------------------------------------------------
#sub CountRiskyFunctionCalls ($$$) {
#  my ($fichier, $vue, $compteurs) = @_ ;
#
#  my $status = 0;
#  my $mnemo_RiskyFunctionCalls = Ident::Alias_RiskyFunctionCalls();
#
#  if ( ! defined $vue->{'code'} ) {
#    $status |= Couples::counter_add($compteurs, $mnemo_RiskyFunctionCalls, Erreurs::COMPTEUR_ERREUR_VALUE );
#    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
#  }
#
#  my $nb_RiskyFunctionCalls= () = $vue->{'code'} =~ /\b(System\.gc\.collect\()/sg;
#
#  $status |= Couples::counter_add($compteurs, $mnemo_RiskyFunctionCalls, $nb_RiskyFunctionCalls);
#
#  return $status;
#}


my $Sep = '(?:[\s\n])';
my $Modifiers = '(?:new\s*|public\s*|protected\s*|internal\s*|private\s*|abstract\s*|sealed\s*|partial\s*|static\s*)';

#my %Modifiers_Order=('static', 'readonly', 'volatile', 'public', 'internal', 'protected', 'private');
#my $Modifier_idx = 0;

#my @Members_Order=('', 'private', 'protected', 'public' );
#my $Members_idx = 0;

my $const_id = 0;
my $event_decl_id = 0;
my $field_id = 0;
my $operator_id = 0;
my $event_access_id = 0;
my $constructor_id = 0;
my $property_id = 0;
my $method_id = 0;
my $class_id = 0;

# Comptages
my $Nbr_Methods = 0;
my $Nbr_Constructors = 0;
my $Nbr_Properties = 0;
my $Nbr_PublicAttributes = 0;
my $Nbr_PrivateProtectedAttributes = 0;
my $Nbr_ClassImplementations =0 ;
my $Nbr_BadDeclarationOrder = 0;
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
my $Nbr_ParentClasses = 0;
my $Nbr_ParentInterfaces = 0;
my $Nbr_Finalize = 0;

my $MetricsFileName='';


# Table de hachage qui repertorie les classes par leur nom.
# Chaque entree de classe contient une liste de table de hachage de types de membres (methodes, attributs, sous-classe, ...), dont la cle est le nom du membre.
my %H_Class = ();

use constant MAX_METHOD_PARAMETER => 7;

# Les ID d'acces 0 et 1 sont reserves ...
use constant CLASS_ID  => 2;
use constant EVENT_DECL_ID  => 3;
use constant EVENT_ACCES_ID  => 4;
use constant CONST_ID  => 5;
use constant FIELD_ID  => 6;
use constant PROPERTY_ID  => 7;
use constant CONSTRUCTOR_ID  => 8;
use constant OPERATOR_ID  => 9;
use constant METHOD_ID  => 10;

use constant VISIBILITY_CODE_ID  => 11;

my @STRING_MEMBER_TYPE = (
				"RESERVED_1",
				"RESERVED_2",
				"CLASS",
				"EVENT DECLARATION",
				"EVENT ACCES",
				"CONSTANT",
				"FIELD",
				"PROPERTY",
				"CONSTRUCTOR",
				"OPERATOR",
				"METHOD",
				"VISIBILITY_CODE",
);

# Rang des declarations
use constant CLASS_RANK  => 2;
use constant EVENT_DECL_RANK  => 3;
use constant EVENT_ACCES_RANK  => 4;

use constant ORDINATION_BEGINNING  => 5;

use constant CONST_RANK  => 5;
use constant FIELD_RANK  => 6;
use constant PROPERTY_RANK  => 7;
use constant CONSTRUCTOR_RANK  => 8;
use constant OPERATOR_RANK  => 9;
use constant METHOD_RANK  => 10;

# Association entre l'ID caracterisant une declaration de membre et son rang attendu dans la classe :
my %H_ID2RANK = (2 => CLASS_RANK, 		# CLASS_ID
                 3 => EVENT_DECL_RANK,	 	# EVENT_DECL_ID
                 4 => EVENT_ACCES_RANK, 	# EVENT_ACCES_ID
                 5 => CONST_RANK, 		# CONST_ID
                 6 => FIELD_RANK, 		# FIELD_ID
                 7 => PROPERTY_RANK, 		# PROPERTY_ID
                 8 => CONSTRUCTOR_RANK, 	# CONSTRUCTOR_ID
                 9 => OPERATOR_RANK, 		# OPERATOR_ID
                 10 => METHOD_RANK ); 		# METHOD_ID

# Rang des declarations de membre en fonction de leur niveau de visibilite.
use constant STATIC_RANK  => 0;
use constant PUBLIC_RANK  => 100;
use constant PROTECTED_RANK => 200 ;
use constant PRIVATE_RANK => 300 ;

#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountMetrics($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  $MetricsFileName=$fichier;

  my $status = 0;

  my $code = '';
  if ( (exists $vue->{'prepro'}) && ( defined $vue->{'prepro'} ) ) {
    $code = \$vue->{'prepro'};
    Erreurs::LogInternalTraces('DEBUG', $fichier, 1, 'CountMetrics', "utilisation de la vue prepro.\n");
  }
  else {
    $code = \$vue->{'sansprepro'};
  }

  my $bloc;
  # $next est 'le prochain bloc a analyser'. Initialement, son contenu est celui de la vue.
  my $next = $$code;

  $Nbr_Methods = 0;
  $Nbr_Constructors = 0;
  $Nbr_Properties = 0;
  $Nbr_PublicAttributes = 0;
  $Nbr_PrivateProtectedAttributes = 0;
  $Nbr_ClassImplementations =0 ;
  $Nbr_BadDeclarationOrder = 0;
  $Nbr_TotalParameters = 0;
  $Nbr_WithTooMuchParametersMethods = 0;
  $Nbr_ShortClassNamesLT = 0;
  $Nbr_ShortClassNamesHT = 0;
  $Nbr_ShortAttributeNamesLT = 0;
  $Nbr_ShortAttributeNamesHT = 0;
  $Nbr_ShortMethodNamesLT = 0;
  $Nbr_ShortMethodNamesHT = 0;
  $Nbr_BadClassNames = 0;
  $Nbr_BadAttributeNames = 0;
  $Nbr_BadMethodNames = 0;
  $Nbr_ParentClasses = 0;
  $Nbr_ParentInterfaces = 0;
  $Nbr_Finalize = 0;

  $const_id = 0;
  $event_decl_id = 0;
  $field_id = 0;
  $operator_id = 0;
  $event_access_id = 0;
  $constructor_id = 0;
  $property_id = 0;
  $method_id = 0;
  $class_id = 0;

  %H_Class = ();

  if ( ! defined $next ) {
    $status |= Couples::counter_add($compteurs, Ident::Alias_FunctionMethodImplementations(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_Constructors(), Erreurs::COMPTEUR_ERREUR_VALUE);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Properties(), Erreurs::COMPTEUR_ERREUR_VALUE);
    $status |= Couples::counter_add($compteurs, Ident::Alias_PublicAttributes(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_PrivateProtectedAttributes(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_ClassImplementations(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_BadClassNames(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_BadMethodNames(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_BadAttributeNames(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_ShortClassNamesLT(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_ShortClassNamesHT(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_ShortMethodNamesLT(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_ShortMethodNamesHT(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_ShortAttributeNamesLT(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_ShortAttributeNamesHT(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_ParentClasses(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_ParentInterfaces(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_BadDeclarationOrder(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_Finalize(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  while ( $next ne '') {
    # Recherhce de la premiere classe :
    #my ( $ClassModifiers, $classBegin, $ClassName, undef, $ClassBase) = $next =~ /(${Modifiers}*)${Sep}*(class${Sep}+(\w*)${Sep}*(?:${Sep}*([\w\.,\s]*))*.*)/sg ;
    my ( $ClassModifiers, $classBegin, $ClassName, undef, $ClassBase) = $next =~ /(${Modifiers}*)${Sep}*(\b(?:class|struct)${Sep}+(\w*)${Sep}*(:${Sep}*([\w\.,\s]*))*.*)/sg ;

    if ( defined $ClassName ) {
      ($bloc, $next) = get_Bloc($classBegin);

      # Construit des listes de declaration de membre de classe dans les tableaux ci-dessus.
      $status |= analyze_Class($bloc, $ClassName, $ClassBase, $ClassModifiers, $compteurs);

      if (Erreurs::isAborted($status)) { return $status;}

      # recupere les statistique de commentaires des membres de classe.
#        my ($nb_C, $nb_CL, $nb_ML, $nb_LOC) = get_CommentStat_Bloc($bloc);
#        print "-----------------------------------------------------------------------------------------------------------------\n";
#        print " Statistiques commentaires :\n";
#        print "              Nombre de lignes de code : $nb_LOC\n";
#        print "      Nombre de lignes de commentaires : $nb_CL\n";
#        print "               Nombre de lignes mixtes : $nb_ML\n";
#        print "                Nombre de commentaires : $nb_C\n";
#        print "        Taux de lignes de commentaires : "; printf "(%.2f\%)\n",($nb_CL+$nb_ML)/($nb_LOC+$nb_ML)*100;
#        print "                  Taux de commentaires : "; printf "(%.2f\%)\n",($nb_C)/($nb_LOC+$nb_ML)*100;

    }
    else {
      ## Le bloc $next actuel ne comporte aucune declaration de classe.

      # si $bloc est vide, c'est que le fichier ne comporte aucune declaration de classe.
      if ( ( ! defined $bloc) || ( $bloc eq '' ) ) {
        print STDERR "[CountCS::CountMetrics] ATTENTION : le fichier $fichier ne contient pas de classe.\n";
      }

      # Si plus de classe trouve, alors inutile de continuer la recherche : on vide le buffer a analyser.
      $next='';
    }
  }
  foreach my $ClassName (keys %H_Class) {

    Compute_Metrics($ClassName, $compteurs);

    $Nbr_Finalize += () = $$code =~ /~${ClassName}\b/;

    #print_ClassStat($ClassName, $fichier);
    #
    # analyse des methodes.
    #my $r=@{$H_Class{$ClassName}}[10];
    #foreach my $key (keys %$r) {
    #  my $line = @{$r->{$key}}[1];
    #  analyze_Method($line, $ClassName);
    #}
  }

  $vue->{'H_Class'} = \%H_Class;

  $status |= Couples::counter_add($compteurs, Ident::Alias_FunctionMethodImplementations(), $Nbr_Methods + $Nbr_Constructors);
  $status |= Couples::counter_add($compteurs, Ident::Alias_Constructors(), $Nbr_Constructors);
  $status |= Couples::counter_add($compteurs, Ident::Alias_Properties(), $Nbr_Properties);
  $status |= Couples::counter_add($compteurs, Ident::Alias_PublicAttributes(), $Nbr_PublicAttributes);
  $status |= Couples::counter_add($compteurs, Ident::Alias_PrivateProtectedAttributes(), $Nbr_PrivateProtectedAttributes);
  $status |= Couples::counter_add($compteurs, Ident::Alias_ClassImplementations(), $Nbr_ClassImplementations );
  $status |= Couples::counter_add($compteurs, Ident::Alias_TotalParameters(), $Nbr_TotalParameters );
  $status |= Couples::counter_add($compteurs, Ident::Alias_WithTooMuchParametersMethods(), $Nbr_WithTooMuchParametersMethods );
  $status |= Couples::counter_add($compteurs, Ident::Alias_BadClassNames(), $Nbr_BadClassNames );
  $status |= Couples::counter_add($compteurs, Ident::Alias_BadMethodNames(), $Nbr_BadMethodNames );
  $status |= Couples::counter_add($compteurs, Ident::Alias_BadAttributeNames(), $Nbr_BadAttributeNames );
  #$status |= Couples::counter_add($compteurs, Ident::Alias_ShortClassNamesLT(), $Nbr_ShortClassNamesLT );
  #$status |= Couples::counter_add($compteurs, Ident::Alias_ShortClassNamesHT(), $Nbr_ShortClassNamesHT );
  #$status |= Couples::counter_add($compteurs, Ident::Alias_ShortMethodNamesLT(), $Nbr_ShortMethodNamesLT );
  #$status |= Couples::counter_add($compteurs, Ident::Alias_ShortMethodNamesHT(), $Nbr_ShortMethodNamesHT );
  #$status |= Couples::counter_add($compteurs, Ident::Alias_ShortAttributeNamesLT(), $Nbr_ShortAttributeNamesLT );
  #$status |= Couples::counter_add($compteurs, Ident::Alias_ShortAttributeNamesHT(), $Nbr_ShortAttributeNamesHT );
  $status |= Couples::counter_add($compteurs, Ident::Alias_ParentClasses(), $Nbr_ParentClasses );
  $status |= Couples::counter_add($compteurs, Ident::Alias_ParentInterfaces(), $Nbr_ParentInterfaces );
  $status |= Couples::counter_add($compteurs, Ident::Alias_BadDeclarationOrder(), $Nbr_BadDeclarationOrder );
  #$status |= Couples::counter_add($compteurs, Ident::Alias_Finalize(), $Nbr_Finalize );
  return $status;
}

# ===================================  Fonctions Internes ==============================


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub get_VisibilityCode {
  my ($member) = @_ ;

  if ( $member =~ /\bstatic\b/ ) {
    return STATIC_RANK;
  }
  elsif ( $member =~ /\bpublic\b/ ) {
    return PUBLIC_RANK;
  }
  elsif ( $member =~ /\bprotected\b/ ) {
    return PROTECTED_RANK;
  }
  else {
    # Par defaut le modificateur de visibilites 'private'.
    return PRIVATE_RANK;
  }
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub get_ClassMemberHash {
  my ($REF_ClassMemberHashList, $numero) = @_ ;

  my @ClassMemberHashList = @{$REF_ClassMemberHashList};

  if ( defined $ClassMemberHashList[$numero]) {
    return $ClassMemberHashList[$numero];
  }
  else {
    my @vide = ();
    return \@vide;
  }

}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub add_ClassMemberElement {
  my ( $class_name, $numero, $member, $member_key ) = @_ ;

  # FOR DEBUGING : 
  #print "*** ADDING ".$STRING_MEMBER_TYPE[$numero]." at line $member->[1]\n";
  #my $m = $member->[0];
  #$m =~ s/\A\s*//s;
  #print "$m\n";

  #my @T_ClassMemberHashList = @{$H_Class{$class_name}};
  my $T_ClassMemberHashList = $H_Class{$class_name};

  if ( ! defined $T_ClassMemberHashList->[$numero]) {
    my %hash = ();
    $T_ClassMemberHashList->[$numero] = \%hash ;
  }

# Evaluation du bon ordre des declaration.
#------------------------------------------
  my $MemberTypeRank = 0;

  if ( exists $H_ID2RANK{$numero} ) {
    $MemberTypeRank = $H_ID2RANK{$numero} ;
  }

  # Calcul du rang du membre en fonction d'apres le rang associe a sa visibilite (static, public, protected, private ...) et a son type (constante, champ, methode ...)
  my $NewOrderNumber = get_VisibilityCode($member->[0]) + $MemberTypeRank;

  # Recuperation du rang complet du membre precedent.
  my $CurrentOrderNumber = $T_ClassMemberHashList->[VISIBILITY_CODE_ID];

  if (! defined $CurrentOrderNumber) {
    $CurrentOrderNumber = ORDINATION_BEGINNING;
    $T_ClassMemberHashList->[VISIBILITY_CODE_ID] = $CurrentOrderNumber;
  }

  # Si le rang du membre est inferieur au rang du membre precedent, alors la declaration n'est pas dans le bon ordre.
  if ($NewOrderNumber < $CurrentOrderNumber) {
    if ( $numero >= ORDINATION_BEGINNING ) {
      $Nbr_BadDeclarationOrder++;
      if ($Nbr_BadDeclarationOrder == 1) {
#print STDERR "[BadDeclarationOrder] Violation avec le membre de classe : ".$member->[0]."\n";
        my $violpattern = $member->[0];
        $violpattern =~ s/^\s*//;
        Erreurs::LogInternalTraces('TRACE',$MetricsFileName,1,'BadDeclarationOrder', $violpattern);
      }
    }
  }
  else {
    $T_ClassMemberHashList->[VISIBILITY_CODE_ID] = $NewOrderNumber;
  }


# Referencement du nouveau membre.
#---------------------------------
  #my %H_Member = %{$T_ClassMemberHashList[$numero]};
  my $H_Member  = $T_ClassMemberHashList->[$numero];

  #if ( defined $H_Member{$member_key} ) \{
  if ( defined $H_Member->{$member_key} ) {
    print STDERR "[CountCS::add_ClassMemberElement] ERREUR : l'element $member_key existe deja dans la classe $class_name.";
  }
  else {
    $H_Member->{$member_key} = $member;
  }

}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub add_ClassItem {
  my ( $member, $class_name, $line, $compteurs ) = @_ ;
  my $moreMethod = 1;
  my $method;
  my $key = '';

  my $recognized=0;

  my $status =0 ;


  #my $ItemLine = get_ItemLine($member);
  #print "$CurrentFile:$ItemLine:VIO_members\n";

  if ( $member !~ /^\s*;/ ) {
  # Si ce n'est pas une instruction vide, alors on l'analyse.

  if ( $member =~ /\A[^\{}]*;/s ) {

    if ( $member =~ /[^\w]+const[^\w]+/s ) {
      $key = 'const'.$const_id;
      $const_id++;
      add_ClassMemberElement($class_name, CONST_ID, [$member, $line], $key);
      $recognized=1;
    }
    if ( $member =~ /[^\w]+event[^\w]+/s ) {
      $key = 'event_decl'.$event_decl_id;
      $event_decl_id++;
      add_ClassMemberElement($class_name, EVENT_DECL_ID, [$member, $line], $key);
      $recognized=1;
    }
    if ( ! $recognized ) {
        $key = 'field'.$field_id;
        $field_id++;
        add_ClassMemberElement($class_name, FIELD_ID, [$member, $line], $key);
    }
  }
  else {

     # recherche des pattern suivants:
     #                   ... (...) \{         ---------> methode
     #                         ... \{         ---------> propriete ou indexeur
     #      ... operator ... (...) \{         ---------> surcharge operateur
     #   ... <classname> (...) ... \{         ---------> constructeur

     my ( $proto ) = ($member =~ /\A([^\{]*)/s);

     #if ( $member =~ /\b(class|struct)\b/s ) {
     if ($proto =~ /\A\s*(${Modifiers}*)${Sep}+(class|struct)${Sep}+(\w*)${Sep}*(:${Sep}*([\w\.]*))*.*/s) {
		 
       # type permet de differencier le cas ou l'on a une classe et le cas ou on a une struct.
       my $SubClassModifiers = $1;
       my $type = $2;
       my $SubClassName = $3;
       my $SubClassBase = $5;
       
       # Recupeartion du code a partir de la ligne de declaration de la classe.
       #if ($type eq 'class') {
       #  ( $SubClassModifiers, $SubClassName, undef, $SubClassBase) = $proto =~ /\A\s*(${Modifiers}*)${Sep}*${type}${Sep}+(\w*)${Sep}*(:${Sep}*([\w\.]*))*.*/s ;
       #}
       #else {
       #  ( $SubClassModifiers, $SubClassName, undef, $SubClassBase) = $proto =~ /\A\s*(${Modifiers}*)${Sep}*${type}${Sep}+(\w*)${Sep}*(:${Sep}*([\w\.]*))*.*/s ;
       #}

       if ( defined $SubClassName ) {

         # Construit des listes de declaration de membre de classe dans les tableaux ci-dessus.
         $status |= analyze_Class($member, $SubClassName, $SubClassBase, $SubClassModifiers, $compteurs);

         if (Erreurs::isAborted($status)) { return $status;}

         # referencement de $SubClassName comme sous-classe de $ClassName.
         $key = $type.$class_id;
         $class_id++;
         add_ClassMemberElement($class_name, CLASS_ID, [$member, $line, $SubClassName], $key);
       }
       else {
         print STDERR "[CountCS::add_ClassItem] Syntax error in class declaration !!\n";
         Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'comptage!!!!', ''); # traces_filter_line
         $status |= Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
       }
       $recognized=1;
     }
     elsif ( $proto =~ /[^\w]operator[^\w]/ ) {
       $key = 'operator'.$operator_id;
       $operator_id++;
       add_ClassMemberElement($class_name, OPERATOR_ID, [$proto, $line], $key);
#       print "====================== Operator Declaration =====================\n";
#       print "ATTENTION : declaration des operateur non encore supportee\n";
#       print $proto."\n";
       $recognized=1;
     }
     elsif ( $proto =~ /[^\w]event[^\w]/ ) {
       $key = 'event_access'.$event_access_id;
       $event_access_id++;
       add_ClassMemberElement($class_name, EVENT_ACCES_ID, [$proto, $line], $key);
       $recognized=1;
#       print "====================== Event Declaration =====================\n";
#       print "ATTENTION : forme de declaration d'evenement non encore supportee\n";
#       print "proto\n";
     }

     elsif ( $proto =~ /[^\w]${class_name}${Sep}*\(/s ) {
       $key = 'constructor'.$constructor_id;
       $constructor_id++;
       add_ClassMemberElement($class_name, CONSTRUCTOR_ID, [$proto, $line], $key);
#       print "====================== Constructor Declaration =====================\n";
#       print "ATTENTION : declaration des constructeurs non encore supportee\n";
#       print $proto."\n";
       $recognized=1;
     }

     elsif ( $proto =~ /\A[^\(\)]*\Z/s ) {
       $key = 'property'.$property_id;
       $property_id++;
       add_ClassMemberElement($class_name, PROPERTY_ID, [$proto, $line], $key);
#       print "====================== Property or Indexer Declaration =====================\n";
#       print "ATTENTION : declaration des proprietes non encore supportee\n";
#       print $proto."\n";
       $recognized=1;
     }

     #if ( ! $recognized ) {
     else {
       $key = 'method'.$method_id;
       $method_id++;
       add_ClassMemberElement($class_name, METHOD_ID, [$proto, $line], $key);
     }
  }
  }
  return $status;
}



#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub IncVisibilityAttribute {
  my ($item, $nb) = @_ ;

  if ( $item =~ /\bpublic\b/s ) {
    $Nbr_PublicAttributes+=$nb;
  }
  elsif ( $item =~ /\b(private|protected)\b/s ) {
    $Nbr_PrivateProtectedAttributes++;
  }
  else {
    $Nbr_PrivateProtectedAttributes++;
  }
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub Compute_Metrics($$) {

  my ($ClassName, $compteurs) = @_ ;
  my $status = 0;

  CheckClassName($ClassName);
  CheckClassInheritance($ClassName);

  # CONSTRUCTORS -----------------------------------------------
  my $r=@{$H_Class{$ClassName}}[CONSTRUCTOR_ID];  # CONSTRUCTOR_ID ==> id de la liste des constructeurs dans la liste des listes de membres associes a une classe ...
  $Nbr_Constructors += scalar(keys %$r);
  foreach my $constructor ( keys %$r ) {
    my $item = @{$r->{$constructor}}[0];   # 0 ==> element 'proto' (i.e. declaration) du membre.
    my ($name) = $item =~ /(\w*)\s*\(/;
    Erreurs::LogInternalTraces('TRACE', $MetricsFileName, 1, 'FunctionMethodImplementations', $name, '-- constructeur --');
  }

  # METHODS ----------------------------------------------------
  $r=@{$H_Class{$ClassName}}[METHOD_ID];  # METHOD_ID ==> id de la liste des methodes dans la liste des listes de membres associes a une classe ...
  $Nbr_Methods += scalar(keys %$r);

  foreach my $method ( keys %$r ) {
    my $item = @{$r->{$method}}[0];   # 0 ==> element 'proto' (i.e. declaration) du membre.
    my $nb_param = CountMethodParameters($item);
    if ($nb_param > MAX_METHOD_PARAMETER) {
      $Nbr_WithTooMuchParametersMethods++;
    }
    $Nbr_TotalParameters += $nb_param ;
    my ($name) = $item =~ /(\w*)\s*\(/;
    CheckMethodName($name);
    Erreurs::LogInternalTraces('TRACE', $MetricsFileName, 1, 'FunctionMethodImplementations', $name);
  }

  # PROPERTIES --------------------------------------------------
  $r=@{$H_Class{$ClassName}}[PROPERTY_ID];  # PROPERTY_ID ==> id de la liste des proprietes dans la liste des listes de membres associes a une classe ...
  $Nbr_Properties += scalar(keys %$r);

  # FIELDS  -----------------------------------------------------
  $r=@{$H_Class{$ClassName}}[FIELD_ID]; # FIELD_ID ==> id de la liste des 'fields' dans la liste des listes de membres associes a une classe ...
  foreach my $field ( keys %$r ) {
    my $item = @{$r->{$field}}[0];   # 0 ==> element 'proto' (i.e. declaration) du membre.

    my @NameList = CountFields($item);
    my $nb = scalar @NameList;
#print "$item ==> $nb declaration fields\n";

    IncVisibilityAttribute($item, $nb);

    foreach my $name (@NameList) {
      CheckAttributeName($name, '-- field --');
    }
  }

  # CONSTS -------------------------------------------------------
  $r=@{$H_Class{$ClassName}}[CONST_ID]; # CONST_ID ==> id de la liste des 'const' dans la liste des listes de membres associes a une classe ...
  foreach my $field ( keys %$r ) {
    my $item = @{$r->{$field}}[0];   # 0 ==> element 'proto' (i.e. declaration) du membre.

    my @NameList = CountConst($item);
    my $nb = scalar @NameList;
#print "$item ==> $nb declaration const\n";

    IncVisibilityAttribute($item, $nb);

    foreach my $name (@NameList) {
      CheckAttributeName($name, '-- const --');
    }
  }


  return $status;
}

#====================================== I N H E R I T A N C E  ================================

#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CheckClassInheritance {
  my ($ClassName) = @_ ;

  my $baseList=@{$H_Class{$ClassName}}[0]; # 0 ==> id de la liste (separee par virgule) des classes/interface de base.

  if (defined $baseList) {
    my @TabBases = split(/,/, $baseList);

    my $nb_Total = scalar @TabBases;
    my $nb_Interfaces=0;

    foreach my $base ( @TabBases ) {
      $base =~ s/\s*//g ;
      if ( $base =~ /\AI[A-Z]/ ) {
        $nb_Interfaces++;
      }
    }

    if (( $nb_Interfaces > 0) && ($nb_Interfaces == $nb_Total)) {
      $Nbr_ParentInterfaces+=$nb_Interfaces;
    }
    elsif ($nb_Interfaces < $nb_Total) {
      $Nbr_ParentClasses += 1;
      $Nbr_ParentInterfaces+=$nb_Total-1;
    }
  }
}

#====================================== N O M E N C L A T U R E  ================================

#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CheckClassName {
  my ($name) = @_ ;

  if ( $name =~ /_/ ) {
    $Nbr_BadClassNames += 1;
  }

  if (length $name < 8) {
    $Nbr_ShortClassNamesLT += 1;
    Erreurs::LogInternalTraces('TRACE', $MetricsFileName, 1, 'ShortClassNamesLT', $name);
  }
  elsif (length $name < 15) {
    $Nbr_ShortClassNamesHT += 1;
    Erreurs::LogInternalTraces('TRACE', $MetricsFileName, 1, 'ShortClassNamesHT', $name);
  }
  else {
    Erreurs::LogInternalTraces('DEBUG', $MetricsFileName, 1, 'ShortClassNames', $name);
  }
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CheckMethodName {
  my ($name) = @_ ;

  if ( $name =~ /_/ ) {
    $Nbr_BadMethodNames += 1;
  }

  if (length $name < 6) {
    $Nbr_ShortMethodNamesLT += 1;
    Erreurs::LogInternalTraces('TRACE', $MetricsFileName, 1, 'ShortMethodNamesLT', $name);
  }
  elsif (length $name < 10) {
    $Nbr_ShortMethodNamesHT += 1;
    Erreurs::LogInternalTraces('TRACE', $MetricsFileName, 1, 'ShortMethodNamesHT', $name);
  }
  else {
    Erreurs::LogInternalTraces('DEBUG', $MetricsFileName, 1, 'ShortMethodNames', $name);
  }
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CheckAttributeName {
  my ($name, $type) = @_ ;

  if ( ! defined $type) {
    $type = '';
  }

  if ( $name =~ /_/ ) {
    $Nbr_BadAttributeNames += 1;
  }

  if (length $name < 6) {
    $Nbr_ShortAttributeNamesLT += 1;
    Erreurs::LogInternalTraces('TRACE', $MetricsFileName, 1, 'ShortAttributeNamesLT', $name, $type);
  }
  elsif (length $name < 10) {
    $Nbr_ShortAttributeNamesHT += 1;
    Erreurs::LogInternalTraces('TRACE', $MetricsFileName, 1, 'ShortAttributeNamesHT', $name, $type);
  }
  else {
    Erreurs::LogInternalTraces('DEBUG', $MetricsFileName, 1, 'ShortAttributeNames', $name, $type);
  }
}

#====================================== M E T H O D S    P A R A M E T E R S  ================================


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountMethodParameters {
  my ($proto) = @_ ;

  # Capture de tout ce qu'il y a entre les parenthese du prototype de methode ...
  #my ($param) = $proto =~ /\(([^\(\)]*)\)[^\(\)]*\z/ ;

  my ($param) = $proto =~ /\((.*)\)/s ;

  my $nb_param = 0;

  # Si les parentheses ne sont pas vides ... on compte les ','.
  if (defined $param && $param !~ /\A\s*\Z/) {
    $nb_param = () = $param =~ /,/g;
    $nb_param++;
  }

  return $nb_param;
}

#====================================== F I E L D ================================


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountFields {

  #     PATTERN :
  #     [<attributes>] [<field-modifiers>] <type> <name> ;
  #
  #     <attributes>           : .....
  #     <field-modifiers>   : list (new | public | protected | internal | private | static | readonly | volatile);
  #     <type>                 : <nom du type>.
  #     <variable-declarators> : list (',', <identifier = constant-expression>)

  my ($decl) = @_ ;

#print STDERR "\n\nFIELD ===> $decl\n";

  my $field_modifiers='(new|public|protected|internal|private|static|readonly|volatile)';

  my $modifiers = '';
  my $type_decl = $decl;

# FIXME: !!!! Code a reactiver lorque les #<prepro> sont presents dans la vue code. !!!!
# FIXME: # Supprimer les directives prepro.
# FIXME: #  $type_decl =~ s/#[^\n]*\n//;

  # elimination des modifiers (dont on ne connait pas le nombre) et capture de ce qui reste dans $type_decl
  #while ( $type_decl =~ /\G(.*${field_modifiers})(.*)/s ) {
  while ( $type_decl =~ /\G(\s*${field_modifiers})(.*)/s ) {
    $modifiers .= $1;
    $type_decl = $3;
#print STDERR "FIELD(modifier) ===> $modifiers\n";
#print STDERR "FIELD(modifier0) ===> $2\n";
#print STDERR "FIELD(type_decl) ===> $type_decl\n";
  }

  while ( $type_decl =~ /\(/ ) {
    $type_decl =~ s/\([^\(\)]*\)// ;
  }
#print STDERR "FIELD(type_decl__) ===> $type_decl\n";

  # Calcul du type de la donnee, et un ajustement de la ligne si le type n'est pas sur la m�me ligne que les modificateurs.
  my ($field_type, $decllist) = ( $type_decl =~ /\s*[^\n\w]*([\w\.]+)\s*(.*);/s );

#print STDERR "FIELD(decllist) ===> $decllist\n";
  # Traitement des declarations
  my @tab = split(',', $decllist);

  my @T = map  { s/[^\w]*(\w*).*/$1/s; $_ ;} @tab;

#print STDERR "FIELD ===> @tab\n";
  return @T;

  #my $nb_decl = () = $decllist =~ /,/sg;
  #$nb_decl++;
  #return $nb_decl;
}

#====================================== C O N S T A N T E ================================


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub CountConst {

  #     PATTERN :
  #     [<attributes>] [<constant-modifiers>] const   <type>   <constant-declarators>   ;
  #
  #     <attributes>           : .....
  #     <constant-modifiers>   : list (new | public | protected | internal | private)
  #     <type>                 : <nom du type>.
  #     <constant-declarators> : list (',', <identifier = constant-expression>)

  my ($decl) = @_ ;

  my ($const_type, $decllist) = ( $decl =~ /\bconst\s*([\w\.]*)\s*(.*);/s );

  #my $nb_decl = () = $decllist =~ /,/sg;
  #$nb_decl++;
  #return $nb_decl;

  # Suppression des initialisatio eventuelle de tableau qui pourraient contenir des ','.
  while ( $decllist =~ s/\{[^\{\}]*\}//g ) {};

  my @tab = split(',', $decllist);

  my @T = map { s/[^\w]*(\w*).*/$1/s; $_; } @tab;
  return @T;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub analyze_Class {
  my ($class_body, $className, $base, $Modifier, $compteurs ) = @_ ;

  my $status = 0;

  $Nbr_ClassImplementations++;

  Erreurs::LogInternalTraces('TRACE', $MetricsFileName, 1, 'ClassImplementations', $className);

  # Les donnees de la classe sont gerees avec une reference sur une liste dont les deux premiers elements sont le nom de sa classe de base et sa liste de modifieurs.
  $H_Class{$className} = [$base, $Modifier];

  $class_body =~ s/(class|struct)[^\{]*\{//s ;

  my $more_to_split = 1;
  my $member = '';
  my @tab_members = ();
  my $previousLine = undef;
  my $line = 0;

  while ($more_to_split) {

    $member = undef ;

    # 1 - RECUPARATION dans un premier temps les membres dont la declaration se termine par un ';'
    # Ces membres ne contiennent pas de '{', sauf s'ils sont precedes d'un '=' ou d'un new.
    #
    #  * Les exemples suivant doivent mactcher l'expression :
    #
    #    public string[] tab = { "data1", "data2", "data3" };
    #    object[] args = new object[1] { new Int32[2] { accountBalances[0], accountBalances[1] } };
    #    CastleProxy ap = new CastleProxyImpl {Id = 1, Name = "first proxy"};
    #    UpdateAccountBalanceesDelagete updateAmounts = new UpdateAccountBalanceesDelagete(AmountsChanged);
    #    object[] args = new object[1] { new Int32[2] { accountBalances[0], accountBalances[1] } };
    #    public static monType maListe = Types.List.GetConstructor(new     Type[] { Types.IEnumerable });
    #    internal enum SchemaTypes { NotSet = 0, Primitive, Enum, Array, Class, XmlSerializable }
    #
    #  * Les exemples suivant NE doivent PAS matcher l'expression :
    #    
    #    public new DataTypeBaseBuilderEnumerator GetEnumerator() {
    #       return new DataTypeBaseBuilderEnumerator(this);
    #    }

    # Si le mot cle "operator" apparait et qu'il ne se trouve pas dans une expression a droite d'un "=",
    # alors il s'agit d'une methode de redefinition d'operateur. On n'effectue donc pas de traitement
    # general car il ne reconna�t pas ce cas particulier.
    if ( $class_body !~ /\A[^=]*\boperator\b[^\{;]*\{/sm) {

      # Traitement du cas general.
#      if ($class_body =~ m{
#           \A(
#               (
#                  [^\{;=]*\benum\b[^\{]*\{ # declaration d'enum
#               )
#               |                           # OU
#               ( (                         #     avant le prochain ";" :
#                    [^\{;]*                #       - tout sauf ";" et "accolade"
#                 |                         #     OU
#                    [^\{\(;]* = [^;]*      #       - un "egal" non precede par une "accolade" ou "parenthese"
#                                           # 
#                 )
#                 ;                         # Obligatoirement termine par un  ;
#               )
#             )
#          }sx ) {
#		$member = $1;
#	  }
		if ($class_body =~ m{\A(
                                 [^\{;=]*\benum\b[^\{]*\{    # declaration d'enum
                               |
                                 [^\{;]*;                    # membre ne contenant pas de d'accolade
                               )}sx ) {
			$member = $1;
		}
		else {
			# check for member initialisation
			if ( $class_body =~ /\A[^\{\(;]*= /) {
				my $level = 0;
				$member = "";
				while ($class_body =~ /([^\{\};]*)(.)/sg) {
					if ($2 eq ";") {
						if ($level <= 0) {
							$member .= $1.$2;
							last;
						}
					}
					elsif ($2 eq "{") {
						$level++;
					}
					elsif ($2 eq "}") {
						$level--;
					}
					$member .= $1.$2;
				}
				pos($class_body)=0;
			}
		}
    }

    if ( defined $member ) {
      # Robustesse contre les instructions vides (par exemple deux ';' consecutifs)
      # Tester si $member contient autre chose que des 'blancs'
      if ( $member =~ /\S*/ ) {

        if ( $member =~ /\benum\b[^\{]*\{/ ) {
            # Si l'attribut est une declaration d'enum, alors on capture en supplement toute la partie
            # contenue par les accolades.
          my ($leftbloc) = CountUtil::splitAtPeer(\$class_body, '{', '}');
          $member = $$leftbloc;
        }

        # Suppression de la partie de code consommee.
        # ==> $class_body = sous-chaine de $class_body commencant a l'offset $length_found !
        my $length_found = length $member;
        $class_body = substr $class_body, $length_found;
        #$class_body =~ s/\A[^;]*;//sg;

        # On gicle les initialisations de structures (s'il y en a)...
        while ( $member =~ /\{[^\{\}]*\}/ ) {
          $member =~ s/\{[^\{\}]*\}/__ISOSCOPE_InitStruct__/;
        }
        if ( $member =~ /[\{\}]/ ) {
          $status |= Erreurs::FatalError(Erreurs::ABORT_CAUSE_SYNTAX_ERROR, $compteurs, '[CountCS::analyze_class] fatal error din struct initialization simplification...');
          return $status;
        }

        # Recuperation du numero de ligne de declaration du membre.
        #$line = get_ItemLine($member, $previousLine);
        $line = 0;
        # Enregistrement des information associee au membre.

#print "ATTRIBUT : $member\n";

        add_ClassItem($member, $className, $line, $compteurs);

        if (Erreurs::isAborted($status)) { return $status;}

        $previousLine = $line;
      }
    }
    else {
      # 2 - RECUPARATION des membres dont la declaration comporte un '{' ou un ':' suivi de base ou this (cas particulier de certains constructeurs)

      my ( $c ) = $class_body =~ /(\{|:\s*(base|this)\b)/ ;

      if (defined $c ){
        # Si on a matche un ':' suivi de 'base' ou 'this', on reduit tout a ':'.
        $c =~ s/:.*/:/s ;
        $c = quotemeta $c;

        # Capture de la declaration jusqu'a '{' ou ':'
        ($member) = ($class_body =~ /\A([^;{}]*)${c}/s );
#print "PROTO : $member\n";
      }
      else {
        $member = undef;
      }

      if ( defined  $member ) {
        # Suppression de la partie de code consommee
        if ( $c eq ':' ) {
          $class_body =~ s/\A[^;\{}:]*:/:/s;
        }
        else {
          $class_body =~ s/\A[^;{}]*\{/\{/s;
        }

        if ( $c eq ':' ) {
          while ( $class_body =~ /\A:\s* (base|this)\s* \( [^\)]* \( /sx ) {
            $class_body =~ s/\([^\(\)]*\)//s;
          }
          my $nb_found = $class_body =~ s/:\s*(base|this)\s*\([^\(\)]*\)//s;
          if ($nb_found != 1) {
            LogInternalTraces ('erreur', undef, undef, "COMPTEUR_STATUS_WARNING", "[CountCS::CountMetrics] erreur de parenthese derriere pour un pattern --> construteur : base (...) <--") ;
            $status |= Erreurs::COMPTEUR_STATUS_WARNING;
          }
        }

        # Recupere le bloc de code correspondant a l'accolade ouvrante.
        my ($bloc, $rest)=get_Bloc($class_body);

#print "BLOC : $bloc\n";

        # Concatenation du prototype du membre et du code correspondant a son body
        $member .= $bloc;
        # Le reste sera analyse a la prochaine iteration (a la fin de chaque iteration, $class_body est ampute de ce qui a ete analyse)
        $class_body = $rest;

        # Si l'accolade fermante du bloc supprime etait suivie de ';', alors $class_body commence par ';'. Il faut supprimer ce ';'
        $class_body =~ s/\A\s*;// ;

        # Recuperation du numero de ligne de declaration du membre.
        #$line = get_ItemLine($member, $previousLine);
        $line = 0;
        # Enregistrement des information associee au membre.
        add_ClassItem($member, $className, $line, $compteurs);
        if (Erreurs::isAborted($status)) { return $status;}
        $previousLine = $line;

      }
      else {
        $more_to_split = 0;
        #print "reliquat de code =\n${class_body}\n";
      }
    }
  }
  #return @tab_members;
  return $status;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub get_Bloc {
  my ($buf) = @_ ;

  my $level=0;
  my $endbloc=0;

  my $bloc='';
  my $rest='';

  while ($buf =~ m/\G([^\{}]*[\{}]?)/g ) {
    my $item = $1;

    if ($endbloc == 0) {
      if ($item =~ /\{/) {
        $level++;
      }
      else {
      if ($item =~ /}/) {
        $level--;
      }}

      if ($level < 0 ) {
        print STDERR "[CountCS::get_Bloc] [$MetricsFileName] ATTENTION : Mauvais appariement de parenthese, bloc non ouvert.\n";
        return (undef, undef);
      }

      if ($level == 0) {
        $endbloc=1;
      }
      $bloc .= $item ;
    }
    else {
      $rest .= $item;
    }

  }
  if ($level > 0) {
    print STDERR "[CountCS::get_Bloc] [$MetricsFileName] ATTENTION : Mauvais appariement de parenthese, bloc non ferme.\n";
    return (undef, undef);
  }

  return ($bloc, $rest);
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub print_AnalyzeError {
  my ($msg, $code) = @_ ;

  print STDERR "[>>>> ANALYZE ERROR : $msg\n";
  print STDERR "$code <<<<]\n";
}


#-------------------------------------------------------------------------------
# DESCRIPTION: # FIXME:
#-------------------------------------------------------------------------------
sub print_ClassStat {

  #my ($ClassName, $ClassBase, $ClassModifiers) = @_ ;
  my ($ClassName, $CurrentFile) = @_ ;
  my $ClassBase = ${$H_Class{$ClassName}}[0] ;
  my $ClassModifiers = ${$H_Class{$ClassName}}[1] ;

  print "|===============================================================================\n";
  print "|                 classe : $ClassName\n";
  print "|-------------------------------------------------------------------------------\n";
  print "|               heritage : ";
  if ( defined $ClassBase) { print $ClassBase."\n"; }
  else { print "----\n";}
  print "|-------------------------------------------------------------------------------\n";
  print "|             modifieurs : ";
  if ( defined $ClassModifiers) { print $ClassModifiers."\n"; }
  else { print "----\n";}
  print "|-------------------------------------------------------------------------------\n";
  print "|                fichier : $CurrentFile\n";
  print "|===============================================================================\n";

  # Constantes
  my $r=@{$H_Class{$ClassName}}[CONST_ID];
  my $item = '';
  foreach my $key (keys %$r) {
    print "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n";
    $item = @{$r->{$key}}[0];
    CONST_analyze($item);
  }

  # Event decl.
  $r=@{$H_Class{$ClassName}}[EVENT_DECL_ID];
  $item = '';
  foreach my $key (keys %$r) {
    print "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n";
    $item = @{$r->{$key}}[0];
    EVENT_DeclVar_analyze($item);
  }

  # class
  $r=@{$H_Class{$ClassName}}[CLASS_ID];
  $item = '';
  foreach my $key (keys %$r) {
    #print "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n";
    $item = @{$r->{$key}}[0];
    CLASS_analyze($item);
  }

  # Field
  $r=@{$H_Class{$ClassName}}[FIELD_ID];
  $item = '';
  foreach my $key (keys %$r) {
    print "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n";
    $item = @{$r->{$key}}[0];
    FIELD_analyze($item);
  }

  # Operator
  $r=@{$H_Class{$ClassName}}[OPERATOR_ID];
  $item = '';
  foreach my $key (keys %$r) {
    #print "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n";
    $item = @{$r->{$key}}[0];
    #OPERATOR_analyze($item);
  }

  # Event access
  $r=@{$H_Class{$ClassName}}[EVENT_ACCES_ID];
  $item = '';
  foreach my $key (keys %$r) {
    #print "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n";
    $item = @{$r->{$key}}[0];
    #EVENT_Access_analyze($item);
  }

  # CONSTRUCTOR
  $r=@{$H_Class{$ClassName}}[CONSTRUCTOR_ID];
  $item = '';
  foreach my $key (keys %$r) {
    #print "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n";
    $item = @{$r->{$key}}[0];
    #CONSTRUCTOR_analyze($item);
  }

  # Property
  $r=@{$H_Class{$ClassName}}[PROPERTY_ID];
  $item = '';
  foreach my $key (keys %$r) {
    #print "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n";
    $item = @{$r->{$key}}[0];
    #PROPERTY_analyze($item);
  }
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
