#------------------------------------------------------------------------------#
#                         @ISOSCOPE 2008                                       #
#------------------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                          #
#               Adresse : TERSUD - Bat A                                       #
#                         5, AVENUE MARCEL DASSAULT                            #
#                         31500  TOULOUSE                                      #
#               SIRET   : 410 630 164 00037                                    #
#------------------------------------------------------------------------------#

# Composant: Plugin
#
# Description: Composant de mesure de source VB, pour creation d'alertes.
#              Ce composant regroupe les comptages qui travaillent sur un pattern d'instruction
#              plutot que sur une vue du code.

package CountVbInstructionPatterns;
use strict;
use warnings;

use Erreurs;
use Couples ;
use CountVbUtils ;


# Stockage des valeurs courantes de differents comptages en cours.
my $nb_NullStringComparisons = 0;
my $nb_PrivateProtectedAttributes = 0;
my $nb_PublicAttributes = 0;
my $nb_BadDeclareUse = 0;
my $nb_ImportsAlias = 0;
my $nb_Case = 0;
my $nb_ClassImplementations = 0;
my $nb_ComplexConditions = 0;
my $nb_For = 0;
my $nb_ForEach = 0;
my $nb_ProceduresDecl = 0;
my $nb_ProceduresImpl = 0;



# Initialisation des comptages
sub Init_InstructionPatternCounters ($)
{
  my ($valeur) = @_;
  $nb_NullStringComparisons = $valeur ;
  $nb_PrivateProtectedAttributes = $valeur;
  $nb_PublicAttributes = $valeur;
  $nb_BadDeclareUse = $valeur;
  $nb_ImportsAlias = $valeur;
  $nb_Case = $valeur;
  $nb_ClassImplementations = $valeur;
  $nb_ComplexConditions = $valeur;
  $nb_For = $valeur;
  $nb_ForEach = $valeur;
  $nb_ProceduresDecl = $valeur;
  $nb_ProceduresImpl = $valeur;
}

# Terminaison/Validation des comptages
sub Record_InstructionPatternCounters ($) 
{
  my ( $compteurs ) = @_ ;
  my $ret = 0;
  $ret |= Couples::counter_add($compteurs, Ident::Alias_NullStringComparisons(), $nb_NullStringComparisons);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_PrivateProtectedAttributes(), $nb_PrivateProtectedAttributes);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_PublicAttributes(), $nb_PublicAttributes);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_BadDeclareUse(), $nb_BadDeclareUse);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_ImportAlias(), $nb_ImportsAlias);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_Case(), $nb_Case);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_ClassImplementations(), $nb_ClassImplementations);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_ComplexConditions(), $nb_ComplexConditions);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_For(), $nb_For);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_ForEach(), $nb_ForEach);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_FunctionMethodImplementations(), $nb_ProceduresImpl);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_FunctionMethodDeclarations(), $nb_ProceduresDecl);
  Init_InstructionPatternCounters(0);
  return $ret;
}

# Comptage de Nbr_Case
# Fonction appellee pour chaque instruction.
sub Count_Case($$$)
{
  my ($unused, $vue, $instruction) = @_ ;

  # Pour chaque instruction
  pos ( $instruction )=0;
    while ( $instruction =~ /(?:\bselect\s*case\b|[.]\s*case\b|(\bcase\b))/smg )
    {
      if (defined $1)
      {
        $nb_Case ++;
      }
    }
}

# Comptage de Nbr_ClassImplementations
# Fonction appellee pour chaque instruction.
sub Count_ClassImplementations($$$)
{
  my ($unused, $vue, $instruction) = @_ ;
  #my ($fichier, $vue, $compteurs) = @_ ;

  #my $code = $vue->{'code_lc'};

  # Pour chaque instruction
  pos ( $instruction )=0;
  #while ( $instruction =~ /(?:\bend\s*class\b|[\[\.{,]\s*class\b|(\bclass\b))/smg )
  # Searching "end class" will be sufficient in the overall cases ...
  #
  while ( $instruction =~ /(\bend\s*class\b)/smg )
  {
    if (defined $1)
    {
      $nb_ClassImplementations ++;
    }
  }
}

# Comptage de Nbr_ClassImplementations
# Fonction appellee pour chaque instruction.
# Description = comptage des conditions complexes
# Langages = VB.net
sub Count_ComplexConditions($$$)
{
  my ($unused, $vue, $instruction) = @_ ;
  #my ($fichier, $vue, $compteurs) = @_ ;
  my $seuil = 2;
  my $ret = 0;
  my $fatalerror = 0;

  # Neutralisation des mots cles de directive de compilation, en les faisant preceder de "_"
  $instruction =~ s/(#\s*)(if|else|elseif|end\s+if)/$1_$2/sg;

  my $buf = $instruction;

  # Suppression de toutes les parentheses internes au niveau de la premiere structure d'imbrication de parentheses rencontree,
  $instruction =~ s/[\(\)]/ /smg ;

  # capture de la condition
  my ($cond) ;
  if ( $instruction =~ /\b(?:if|elseif)\b\s*(.*)\bthen\b/smg )
  {
    $cond = $1;
  }
  elsif ( $instruction =~ /\b(?:while|loop|until)\b\s*(.*)/smg )
  {
    $cond = $1;
  }

  if (defined $cond) {
    # Calcul du nombre de && et de ||
    my $nbET = () = $cond =~ /and|andalso/sg ;
    my $nbOU = () = $cond =~ /or|orelse/sg ;

    if ( ($nbET > 0) && ($nbOU > 0) ) {
      if ( $nbET + $nbOU > $seuil) {
        $nb_ComplexConditions++;
      }
    }
  }
}


# Comptage de boucles
# Fonction appellee pour chaque instruction.
# compte le nombre de boucles de taille determinee
sub Count_For($$$)
{
  my ($unused, $vue, $instruction) = @_ ;

  # Pour chaque instruction
  pos ( $instruction )=0;
    while ( $instruction =~ /(?:\bexit\s*for\b|\bcontinue\s*for\b|[\[\.\{,]\s*for\b|(\bfor\s*each\b)|(\bfor\b))/smg )
    {
      if (defined $1)
      {
        $nb_ForEach ++;
      }
      if (defined $2)
      {
        $nb_For ++;
      }
    }
}


# compte le nombre de procedures/fonctions
# Fonction appellee pour chaque instruction.
sub Count_Procedures($$$)
{
  my ($unused, $vue, $instruction) = @_ ;

  # Pour chaque instruction
  pos ( $instruction )=0;
    while ( $instruction =~ /(?:\bexit\b\s*\b(?:function|sub)\b|(\bend\b\s*\b(?:function|sub)\b)|[\[\.\{,]\s*(?:function|sub)\b|(\b(?:function|sub)\b))/smg )
    {
      if (defined $1)
      {
        $nb_ProceduresImpl ++;
      }
      if (defined $2)
      {
        $nb_ProceduresDecl ++;
      }
    }
}



# Comptage : Count_NullStringComparisons
#
# Spec :
#
# * Mauvais (a rechercher) :
#        <> ""
#        = ""
#        <> vbNullString
#        = vbNullString
#        "" <> 
#        "" =
#        vbNullString <>
#        vbNullString =
#
# * Bon (pour info)
#                   <>
#        Len ( ...) =  0
#                   > 
#
#         <>
#        0 = Len ( ...)
#         <

sub Count_NullStringComparisons ($$$) 
{
  my ($fichier, $vue, $instr) = @_ ;

  my $r_TabString = $vue->{'string'};

  my $ret = 0;

  # Remplacement des chaines originales.
  while ( $instr =~ /"(ch\d+)"/ ) {
    my $key = $1;
    my $orig = $r_TabString->{$key};
    $instr =~ s/${key}/${orig}/;
  }

  if ( ! defined $instr ) {
    print STDERR "[Count_NullStringComparisons] [$fichier] ATTENTION : pattern d'instruction non defini.\n";
    return $ret ;
  }

  while ( $instr =~ /(<>|[^:]=)\s*(\"\"|vbnullstring)/g ) {
    $nb_NullStringComparisons++;
    Erreurs::LogInternalTraces("TRACE", $fichier, 1, "NullStringComparisons", $instr);
  }

  while ( $instr =~ /(\"\"|vbnullstring)\s*(<>|=)/g ) {
    $nb_NullStringComparisons++;
    Erreurs::LogInternalTraces("TRACE", $fichier, 1, "NullStringComparisons", $instr);
  }

  return $ret;
}


sub Count_BadDeclareUse ($$$) 
{
  #my ($fichier, $vue, $instr) = @_ ;
  my ( $profondeur, $instr, $vue ) = @_ ;
  my $fichier = "undef";

  my $r_TabString = $vue->{'string'};

  my $ret = 0;

  if ( ! defined $instr ) {
    print STDERR "[Count_BadDeclareUse] [$fichier] ATTENTION : pattern d'instruction non defini.\n";
    return $ret ;
  }

  if ( $instr =~ /\bdeclare\b/ ) {

    if ( $instr =~ /\bas\s*any\b/ ) {
      $nb_BadDeclareUse++;
      Erreurs::LogInternalTraces("TRACE", $fichier, 1, "BadDeclareUse", $instr, "*** As Any ***");
    }

    if ( $instr !~ /\bprivate\b/ ) {
      $nb_BadDeclareUse++;
      Erreurs::LogInternalTraces("TRACE", $fichier, 1, "BadDeclareUse", $instr, "*** non private ***");
    }

    {
      $instr =~ /\balias\s*\"([^\"]*)/ ;
      if (defined $1) {
        my $orig = $r_TabString->{$1};

        if ($orig =~ /^#\d/) {
          $nb_BadDeclareUse++;
          Erreurs::LogInternalTraces("TRACE", $fichier, 1, "BadDeclareUse", $instr, "*** alias avec ordinal ***");
        }
      }
    }

    {
      $instr =~ /\blib\s*\"([^\"]*)/ ;
      if (defined $1) {
        my $orig = $r_TabString->{$1};

        if ($orig =~ /[\\\/]/) {
          $nb_BadDeclareUse++;
          Erreurs::LogInternalTraces("TRACE", $fichier, 1, "BadDeclareUse", $instr, "*** chemin de librairie***");
        }
      }
    }
  }
  return $ret;
}





# Comptage des alias a l'interieur des imports.
# Ce comptage est baptise Nbr_ImportAlias sans doute en lien avec le C#.
sub InstrParLev_ImportsAlias ($$$) 
{
  my ( $profondeur, $instr, $vue ) = @_ ;
  my $ret = 0;

  if ( $profondeur == 0 )
  {
    Erreurs::LogInternalTraces('debug', undef, undef, 'InstrParLev_ImportsAlias', '<'.$instr.'>', $profondeur);
    if ( $instr =~ /\A\s*\bimports\b[^\n]*/sm )
    {
      Erreurs::LogInternalTraces('debug', undef, undef, 'InstrParLev_ImportsAlias:imports', '<'.$instr.'>', $profondeur);
      my @clauses = split ( /,/ , $instr   ) ;
      for my $clause  ( @clauses )
      {
        Erreurs::LogInternalTraces('debug', undef, undef, 'InstrParLev_ImportsAlias:clause', '<'.$clause.'>', $profondeur);
        if ( $clause =~ /=/sm )
        {
          $nb_ImportsAlias += 1 ;
          Erreurs::LogInternalTraces('trace', undef, undef, Ident::Alias_ImportAlias(), '<'.$clause.'>');
        }
      }
    }
  }
  return $ret;
}




# Estimation du nombre d'attributs publics
# TBC: traiter les instruction declarant plusieurs variables
sub InstrParLev_PublicAttributes ($$$) 
{
  my ( $profondeur, $instr, $vue ) = @_ ;
  my $ret = 0;

  Erreurs::LogInternalTraces('debug', undef, undef, 'InstrParLev_PublicAttributes', '<'.$instr.'>', $profondeur);
  if ( $profondeur == 0 )
  {
    if ( $instr =~ /\bpublic\b[^\n]*\b/sm )
    {
      if ( $instr !~ /\b(?:class|event|interface|property|enum|region)\b/sm )
      {
        my $nb_coma = () = $instr =~ /,/smg ;
        $nb_PublicAttributes += 1 + $nb_coma;
        Erreurs::LogInternalTraces('debug', undef, undef, Ident::Alias_PublicAttributes(), '<'.$instr.'>', $nb_coma);
      }
    }
  }
  return $ret;
}

# Estimation du nombre d'attributs publics
# TBC: traiter les instruction declarant plusieurs variables
sub Count_PublicAttributes ($$$) 
{
  my ($unused, $vue, $instr) = @_ ;
  my $ret = 0;

  if ( $instr =~ /\bpublic\b[^\n]*\b/sm )
  {
    if ( $instr !~ /\b(?:class|event|interface|property|enum|region)\b/sm )
    {
      $nb_PublicAttributes += 1;
    }
  }
  return $ret;
}
# Terminaison/Validation des comptages

# Estimation du nombre d'attributs prives ou protected
# TBC: traiter les instruction declarant plusieurs variables
sub Count_PrivateProtectedAttributes ($$$) 
{
  my ($unused, $vue, $instr) = @_ ;
  my $ret = 0;
  if(  $instr =~ /\b(?:private|protected)\b[^\n]*\b/sm )
  {
    if ( $instr !~ /\b(?:class|event|interface|property|enum|region)\b/sm )
    {
      $nb_PrivateProtectedAttributes += 1;
    }
  }
  return $ret;
}




# call back 
# Recherche les conditions
# permet de n'appeler Count_NullStringComparisons que pour du code parenthese.
sub internalSequencementCondition ($$$)
{
  my ( $profondeur, $expr_part, $vue ) = @_ ;
  #Erreurs::LogInternalTraces('debug', undef, undef, 'expr_null', '<'.$expr_part.'>', $profondeur);
  if ( $profondeur > 0 )
  {
      CountVbInstructionPatterns::Count_NullStringComparisons(undef, $vue, $expr_part) ;
  }
}


# Fonction de sequencement appellee pour chaque instruction
sub internalSequencementInstruction($$)
{
  my ($vue, $instruction) = @_ ;

  # Pour toutes les instructions
  CountVbUtils::analyse_parentheses ($instruction, 0, $vue, \&InstrParLev_ImportsAlias, undef);

  CountVbInstructionPatterns::Count_Case (undef, $vue, $instruction);
  CountVbInstructionPatterns::Count_ClassImplementations (undef, $vue, $instruction);
  CountVbInstructionPatterns::Count_ComplexConditions (undef, $vue, $instruction);
  CountVbInstructionPatterns::Count_For (undef, $vue, $instruction);
  CountVbInstructionPatterns::Count_Procedures (undef, $vue, $instruction);

  if ( $instruction =~ /\b(?:sub|function|property|event|addhandler|removehandler|raiseevent)\b/sm )
  {
    # essaye d'approfondir la signiifcation du code
    # en separant les expressions des instructions
    # La grammaire VB etant complexe et semblant parfois ambigue,
    # on procede par approximations naives.

    # Le caractere egal peut etre dansune liste de parametre de :
    # AddHandlerDeclaration # RemoveHandlerDeclaration # RaiseEventDeclaration
    # ConstructorMemberDeclaration
    # SubDeclaration # MustOverrideSubDeclaration # InterfaceSubDeclaration
    # FunctionDeclaration # MustOverrideFunctionDeclaration # InterfaceFunctionDeclaration
    # RegularPropertyMemberDeclaration # MustOverridePropertyDeclaration # InterfacePropertyDeclaration
    # RegularEventMemberMemberDeclaration # InterfaceEventMemberDeclaration
    # ExternalSubDeclaration # ExternalFunctionDeclaration

    # A priori, ici le = est une affectation.
  }
  else
  {
    CountVbUtils::analyse_parentheses ($instruction, 0, $vue, \&internalSequencementCondition, undef);
  }

  # Pour toutes les instructions.
    #CountVbUtils::analyse_parentheses ($instruction, 0, $vue, \&CountVbInstructionPatterns::Count_BadDeclareUse, undef);
    CountVbInstructionPatterns::Count_BadDeclareUse ( 0, $instruction, $vue )  ;

  # Les attributs ne sont pas des fonctions
  if ( $instruction !~ /\b(?:sub|function|property|event|addhandler|removehandler|raiseevent)\b/sm )
  {
    CountVbUtils::analyse_parentheses ($instruction, 0, $vue, \&InstrParLev_PublicAttributes, undef);

    # Ces deux appels de comptage d'attributs sont mis ici a titre experimental.
    #CountVbInstructionPatterns::Count_PublicAttributes (undef, $vue, $instruction);
    CountVbInstructionPatterns::Count_PrivateProtectedAttributes (undef, $vue, $instruction);
  }
}




# Sequencement des comptages necessitant un decoupage par instruction.
sub CountVbInstructionPatterns ($$$)
{
  my ($param1, $vue, $compteurs) = @_ ;

  my $ret = 0;
  # Recuperation de la vue
  if ( ! exists $vue->{'code_lc'} ) {
    $ret |= Couples::counter_add($compteurs, Ident::Alias_Statements(), Erreurs::COMPTEUR_ERREUR_VALUE );
    Init_InstructionPatternCounters(Erreurs::COMPTEUR_ERREUR_VALUE);
    CountVbInstructionPatterns::Record_InstructionPatternCounters ($compteurs);
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my $code = $vue->{'code_lc'};

  # Comptage des instructions
  my $nbr_statements = 0;
  $nbr_statements +=  CountVbUtils::count_re($code, '^\s*[^\s_]' );
  $nbr_statements -=  CountVbUtils::count_re($code, '_\s*\n' );
  $nbr_statements +=  CountVbUtils::count_re($code, ':' );
  $ret |= Couples::counter_add($compteurs, Ident::Alias_Statements(), $nbr_statements);

  # Pour chaque instruction
  pos ( $code )=0;
  while ( $code =~ /\G([^\n]*?(?:_\s*?\n[^\n]*?)*)(?:$)([\n]*)/smg )
  {
    my $instruction = $1;
    my $d2 = $2;

    internalSequencementInstruction( $vue, $instruction );
  }
  # Enregistrement du resultat
  CountVbInstructionPatterns::Record_InstructionPatternCounters ($compteurs);
  return $ret;
}

1;
