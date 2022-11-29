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

# Ce paquetage fournit des compteurs sur le code et les commentaires
# d'un fichier script ecrit en Korn Shell


package CountKsh;

use CountSuspiciousComments;
use CountBinaryFile;
use CountCommun;
use CountLongLines;
use Memory; # memory_filter_line

use strict;
use warnings;

use Couples;

my $debug = 0;

use Erreurs;


# Variables globales
my %alternCase;    # ecrite par CheckIndent, lue par CheckPipes
                   # liste des lignes contenant une declaration une entree
                   # de cas multiples separes par '|' (a ne pas confondre avec
                   # un pipe entre 2 processus)

# Fonction   : init
# Parametres :
#
# Retour     : aucun
#
# Initialise les variables echangees entre routines pour un fichier verifie
sub init()
{
    %alternCase = ();
}


# Fonction   : CountWords
# Parametres : nom de fichier.
#              table de hachage des vues.
#              table de hachage des couples elementaires.
#
# Retour     : 0 si succes
#              64 si la sauvegarde d'un couple a echoue
#
# Renseigne les compteurs :
# Nbr_Words : nombre total de mots
# Nbr_DistinctWords : nombre de mots distincts
sub CountWords($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $memory = new Memory('CountWords'); # memory_filter_line

  my $savDebug = $debug;
  #$debug = 1;

  my $status = 0;
  my $code = $vue->{code};

  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, Ident::Alias_Words(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_DistinctWords(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nb_DistinctWords = 0;
  my $nb_Words = 0;
  my $nbOps = 0;


  # suppression des dollars (l'euro c'est bien mieux)
  $code =~ s/\$([0-9])/__ISOSCO_DOLLAR__$1/g;
  $code =~ s/\$\{(\w+)[^}]+\$(\w+)}/$1 $2 /g;
  $code =~ s/\$\{(\w+)[^}]*}/$1/g;
  $code =~ s/\$\#/__ISOSCO_DOLLAR__DIESE/g;
  $code =~ s/\$\?/__ISOSCO_DOLLAR__INTERROG/g;
  $code =~ s/\$\*/__ISOSCO_DOLLAR__ETOILE/g;
  $code =~ s/\$\@/__ISOSCO_DOLLAR__AROBASE/g;
  $code =~ s/\$\$/__ISOSCO_DOLLAR__DOLLAR/g;
  $code =~ s/\$\(/__ISOSCO_DOLLAR__CMD /g;
  $code =~ s/\$(\w+)/$1/g;
  # Ici, il ne devrait plus rester de dollar
  if ($code =~ /\$/)
  {
      Erreurs::LogInternalTraces ("DEBUG", $fichier, 1, Ident::Alias_Words(), "", "Mauvais nettoyage de dollar");
  }

  # separation des chaines
  $code =~ s/"/ /g;

  # supression des elements fermants (ils vont de pair avec des ouvrants comptabilises).
  #if ( $code =~ s/}/ /g ) { $nb_DistinctWords++; }
  #if ( $code =~ s/\)/ /g ) { $nb_DistinctWords++; }
  #if ( $code =~ s/\]/ /g ) { $nb_DistinctWords++; }

  $code =~ s/}|\)|\]/ /g;  # on ne comptabilise pas ')' dans les entry_cases de case ... esac

  my %Hop = ();
  my $nb = 0;
  $memory->memusage('init'); # memory_filter_line

  # Remplacement des operateurs composes de 3 symboles.
  if ( $nb = ( $code =~ s/(>>&)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(<<-)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }

  # Remplacement des operateurs composes de 2 symboles.
  if ( $nb = ( $code =~ s/(&&)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(\|\|)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  #if ( $nb = ( $code =~ s/(\+\+)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; }
  #if ( $nb = ( $code =~ s/(\-\-)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; }
  if ( $nb = ( $code =~ s/(!=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(<=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(==)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(>=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(>>)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(\|\&)/§/g ))
  {   if (! defined($1))
      {
          Erreurs::LogInternalTraces ("DEBUG", $fichier, 1, Ident::Alias_Words(), "", "pb interne");
      }
      else
      {
          $nb_DistinctWords++; 
          $Hop{$1}=$nb;
          $nbOps += $nb;
      }
  }
  if ( $nb = ( $code =~ s/(>&)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(<<)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(\[\[)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(;;)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(\(\()/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }

  # Remplacement des operateurs composes de 1 symbole.
  if ( $nb = ( $code =~ s/(!)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(%)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(&)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(\*)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(\+)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  #if ( $nb = ( $code =~ s/(,)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; }
  #if ( $nb = ( $code =~ s/(\.)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; }
# FIXME:  if ( $nb = ( $code =~ s/(\/)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; }
  # / etant utilise pour des chemins ou pour de l'arithmethique, on ne fait rien
  if ( $nb = ( $code =~ s/(<)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(=)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(>)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  #if ( $nb = ( $code =~ s/(\?)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; }
  if ( $nb = ( $code =~ s/(\^)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(\|)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(\{)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(;)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(\[)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
  if ( $nb = ( $code =~ s/(\`)/§/g )) { $nb_DistinctWords++; $Hop{$1}=(($nb + 1) - (($nb+1) % 2) )/2; $nbOps += $Hop{$1};} # on ne compte qu'1 quote inverse sur 2
  if ( $nb = ( $code =~ s/(\()/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; $nbOps += $nb; }
# FIXME:  if ( $nb = ( $code =~ s/(-)/§/g )) { $nb_DistinctWords++; $Hop{$1}=$nb; }
  # il y a une multitude de cas d'utilisations de '-' en shell
  # [a-zA-Z], -eq, -f, -monOptionAMoi, ((c=a-b))
  # le plus simple est de compter ce '-' dans les opérandes, même si c'est discutable pour l'arithmétique
  $code =~ s/\-/__ISOSCO_MOINS__/g;

  $memory->memusage('operateurs'); # memory_filter_line

  $memory->memusage('derniers operateurs'); # memory_filter_line
  # Compter le nombre de mots distincts (il reste les identificateurs et les chaines)
  # FIXME: en shell il peut rester des symboles non textuel comme ':', '\'', '/', ...
  # FIXME: ils seront ignores
  my $item;
  my %Hword =();
  while ( $code =~ /(\w+)/g ) {
    $item = $1;
    $nb_Words++;
    if (! defined $Hword{$item} ) {
      $nb_DistinctWords++;
      $Hword{$item} = 1;
    }
    else {
      $Hword{$item} += 1;
    }
  }

  $memory->memusage('boucle'); # memory_filter_line

  $memory->memusage('divers'); # memory_filter_line

  # Affichage des resultats ...
  # FIXME: AD: mettre en commentaire tout le bloc d'instructions
if ($debug != 0)
{
  my $total = 0;
  my $different = 0;

  my $word;
  my $key;
  my $rStrings = $vue->{'strings'};
  for $key ( sort keys %Hword) {
   if ( $key =~ /CHAINE_(\d+)/ ) {
     my $index = $1 - 1;
     $word = $rStrings->[$index];
   }
   else {
     $word = $key ;
   }
   Erreurs::LogInternalTraces ("DEBUG", $fichier, 1, Ident::Alias_Words(), "$key", "$Hword{$key}");
   $total += $Hword{$key};
   $different++;
  }

  for $key ( sort keys %Hop) {
    Erreurs::LogInternalTraces ("DEBUG", $fichier, 1, Ident::Alias_Words(), "$key", "$Hop{$key}");
    $total += $Hop{$key};
    $different++;
  }
}


  # Finalisation des resultats.
  # Ajout de tout ce qui a ete trouve precedemment (et remplace par des §).
#  $nb_Words += () = $code =~ /§/g ; 
  $nb_Words += $nbOps;

  $status |= Couples::counter_add($compteurs, Ident::Alias_Words(), $nb_Words);
  $status |= Couples::counter_add($compteurs, Ident::Alias_DistinctWords(), $nb_DistinctWords);
  $debug = $savDebug;
  $memory->memusage('fin');

  return $status;
}


# Fonction   : Line1Ctrl
# Parametres : table de hachage des couples elementaires.
#              vue sur les commentaires.
#              
# Retour     : 0 si succes
#              64 si la sauvegarde d'un couple a echoue
#
# Renseigne le compteur booleen de presence d'une 1ere ligne
# indiquant l'utilisation de l'interpreteur Ksh
#
sub Line1Ctrl($$)
{
    my ($compteurs, $cmt) = @_;

    my $status = 0;

    if ($cmt =~  /^#!\/[\w\/]+\/ksh\W.*/)
    {
        # #!/usr/bin/ksh -p devrait etre admis
        $status |= Couples::counter_add($compteurs, Ident::Alias_WithoutKshFirstLine(), 1);
    }
    else
    {
        $status |= Couples::counter_add($compteurs, Ident::Alias_WithoutKshFirstLine(), 0);
    }
    return $status;
}


# Fonction   : CountComments
# Parametres : table de hachage des couples elementaires.
#              vue sur les commentaires.
#              nom du fichier (optionnel)
#              
# Retour     : 0 si succes
#              64 si la sauvegarde d'un couple a echoue
#
# Analyse la vue commentaire pour en compter
# Nbr_CommentBlocs : nombre de blocs de commentaires
# Nbr_CommentedOutCode : nombre de lignes de code en commentaire
#
sub CountComments($$$;)
{
    my ($compteurs, $cmt, $fName) = @_;

    $fName = "" if (!defined $fName);

    my $status = 0;

    my $saveDebug = $debug;


    # parcours de la vue commentaires
    my $deb = 0;
    my $cmtLine = 0;
    my $prevIndent = -1;
    my $nbCmtBlocks = 0;
    my $nbCmtCode = 0;

    while ($cmt =~ m{\n}g)
    {
        my $end = pos($cmt);
        my $ligne = substr($cmt, $deb, $end - $deb);

        $cmtLine++;

        if ($ligne =~ /\A\s*\Z/)
        {
            # pas de commentaire sur cette ligne
            $prevIndent = -1;
        }
        else
        {
            # recherche de code en commentaire
            my $comment = $ligne;
            $comment =~ s/[^#]*#\s*//;
            if ($comment =~ m{
                              (
                               \Aif\s+\[ |
                               \Athen\b |
                               \Aelse\b |
                               \Aelif\b |
                               \Afi\b |
                               \Afor\s+\S+\s+in |
                               \Ado\b |
                               \Adone\b |
                               \Awhile\b |
                               \Abreak\b |
                               \Acontinue\b |
                               \Atypeset\b |
                               \Ainteger\b |
                               \A\w+= |
                               \Alet\b |
                               \A\(\( |
                               \[ |
                               \] |
                               \&\& |
                               \|\| |
                               \bawk\b |
                               \bbasename\b |
                               \bcat\b |
                               \bcd\b |
                               \bcp\b |
                               \bcut\b |
                               \bdiff\b |
                               \Aecho\b |
                               \benv\b |
                               \bexpr\b |
                               \bfind\b |
                               \bgetopt(s)?\b |
                               \bgrep\b |
                               \bhead\b |
                               \bkill\b |
                               \bln\b |
                               \bls\b |
                               \bmkdir\b |
                               \bmv\b |
                               \Aprint(f)?\b |
                               \bpwd\b |
                               \brm\b |
                               \brmdir\b |
                               \bsed\b |
                               \bsleep\s+[\$\d]\b |
                               \btail\b |
                               \btee\b |
                               \btouch\b |
                               \btr\b |
                               \bumask\b |
                               \buname\b |
                               \buniq\b |
                               \bwait\b |
                               \bwc\b |
                               \bxargs\b
                              )
                             }ox
               )
#                               \bread\b |
#                               \bfalse\b |
#                               \btrue\b |
               {
                   Erreurs::LogInternalTraces ("DEBUG", $fName, $cmtLine, Ident::Alias_CommentedOutCode(), $ligne, "");
                   $nbCmtCode++;
               }

                            

            # comptage du nombre de blocs de commentaires
            my $code = $ligne;
            $code =~ s/#.*$//;
            $code =~ tr/\n//d;
            my $indent = length($code);

            if ($indent != 0 || $indent != $prevIndent)
            {
#                if ($indent != 0 && $prevIndent > 0)
#                {
#                    Erreurs::LogInternalTraces ("DEBUG", $fName, $cmtLine, Ident::Alias_CommentBlocs(), $ligne, "litigieux");
#                }
#                else
                { ;
                    Erreurs::LogInternalTraces ("DEBUG", $fName, $cmtLine, Ident::Alias_CommentBlocs(), $ligne, "");
                }
                $nbCmtBlocks++;
            }
            $prevIndent = $indent;
        }
        $deb = $end;
    }

    $status |= Couples::counter_add($compteurs, Ident::Alias_CommentBlocs(), $nbCmtBlocks);
    $status |= Couples::counter_add($compteurs, Ident::Alias_CommentedOutCode(), $nbCmtCode);

    $debug = $saveDebug;

    return $status;
}


# Fonction   : isIFSModified
# Parametres : table de hachage des couples elementaires.
#              vue sur le code.
#              
# Retour     : 0 si succes
#              64 si la sauvegarde d'un couple a echoue
#
# Renseigne le compteur booleen de modification de variable IFS.
#
sub isIFSModified($$)
{
    my ($compteurs, $code) = @_;

    my $status = 0;

    #if ($code =~ m{\n\s*\(\s*IFS=["']?CHAINE})
    #  There is not rrerason to have a opening parenthesis a in previous line :
    if ($code =~ m{\n\s*IFS=["']?CHAINE})
    {
        $status |= Couples::counter_add($compteurs, Ident::Alias_ModifiedIFS(), 1);
    }
    else
    {
        $status |= Couples::counter_add($compteurs, Ident::Alias_ModifiedIFS(), 0);
    }
    return $status;
}


# Fonction   : isGetoptUsed
# Parametres : table de hachage des couples elementaires.
#              vue sur le code.
#              
# Retour     : 0 si succes
#              64 si la sauvegarde d'un couple a echoue
#
# Renseigne le compteur booleen de modification de variable IFS.
#
sub isGetoptUsed($$)
{
    my ($compteurs, $code) = @_;

    my $status = 0;

    if ($code =~ m{\bgetopt\b})
    {
        $status |= Couples::counter_add($compteurs, Ident::Alias_Getopt(), 1);
    }
    else
    {
        $status |= Couples::counter_add($compteurs, Ident::Alias_Getopt(), 0);
    }
    return $status;
}


# Fonction   : ArgsNbrChecked
# Parametres : table de hachage des couples elementaires.
#              vue sur le code.
#              
# Retour     : 0
#              64 si la sauvegarde d'un couple a echoue
#
# Renseigne le compteur Nbr_CheckedArgs
#
sub ArgsNbrChecked($$)
{
    my ($compteurs, $code) = @_;

    my $status = 0;

    my $found = 0;
    my $deb = 0;

    my $numLigne = 0;

    while ($found == 0 && $code =~ /\n/g)
    {
        my $end = pos($code);
        my $ligne = substr($code, $deb, $end - $deb);
        $numLigne++;

        if ($ligne =~ /\b\w+=\$\#\W/)
        {
            # $# est affecte a une variable
            $found = 1;
        }
        elsif ($ligne =~ /\$\#\s+(-eq|-ne|-lt|-gt|-le|-ge|=|!=)/)
        {
            # la valeur de $# est testee
            $found = 1;
        }
        elsif ($ligne =~ /\A\s*case\s+\$#/)
        {
            # la valeur de $# est testee
            $found = 1;
        }
        $deb = $end;
    }

    $status |= Couples::counter_add($compteurs, Ident::Alias_CheckedArgs(), $found);

    return $status;
}


# Fonction   : DetectVarsFuncAlias
# Parametres : table de hachage des couples elementaires.
#              vue sur le code.
#              vue sur les commentaires.
#              
# Retour     : 0
#              64 si la sauvegarde d'un couple a echoue
#
# Renseigne les compteurs de :
# - nombre de variables locales, fonctions et alias (Nbr_LocalVariables)
# - nombre de variables locales, fonctions et alias nommes correctement (Nbr_WellNamedLocalVariables)
# - nombre de variables exportees (Nbr_ExportedVariables)
# - nombre de variables exportees correctement nommees (Nbr_WellNamedExportedVariables)
# - nombre de declarations de variables (Nbr_VariableDeclarations)
# - nombre de variables declarees avec un bon operateur (Nbr_WellDeclaredVariables)
# - nombre de declarations de variables et fonctions (Nbr_VarFuncDecl) TBC
# - nombre de fonctions et declarations de variables commentees (Nbr_CommentedVarFunc) TBC
#
sub DetectVarsFuncAlias($$$$)
{
    my ($fileName, $compteurs, $code, $cmt) = @_;

    # Constantes
    my $maxLength = 16; # longueur maxi d'un identifiant de variable
    my $exportFilter = qw{\b[[A-Z\d_]+\b}; # regle de nommage des variables exportees
    my $localFilter = qw{\b[a-z]\w*\b}; # regle de nommage des variables locales
    my $FONC = 1;
    my $EXPORT_DECL = 2;
    my $EXPORT_ADD = 3;
    my $ALIAS = 4;
    my $TYPESET = 5;
    my $SET = 6;
    my $AFFECT = 7;
    my $LET = 8;
    my $funcCmtNoCheck = -2; # FIXME:
    my $varCmtNoCheck = -1; # FIXME:

    # Variables locales
    my @tab_cmt; # FIXME:
    my $deb = 0; # debut de ligne de code
    my $maybeFunc = undef; # nom de fonction potentiel
    my %localNames = (); # table de noms de symboles locaux : variables, alias et fonctions
    my %exportNames = (); # table de nom de variables exportees
    my $codeLine = -1;
    my $funcCmtToCheck = $funcCmtNoCheck; # FIXME:
    my $varCmtToCheck = $varCmtNoCheck; # FIXME:
    my $commentedVars = 0; # FIXME:
    my $commentedFuncs = 0; # FIXME:
    my $nbVariableDeclarations = 0; # nombre de variables correctement declarees
    my $nbBadDecl = 0; # nombre de variables incorrectement declarees
    my $nbFunc = 0; # nombre de fonctions
    my $totalCmtLines = 0;
    my $mainFunc = 0; # detection d'une fonction nommee 'main'
    my $nbAlias = 0; # nombre d'alias
    my $varName = "";
    my $foncName = "";

    my $status = 0;

    # mise en tableau de la vue 'comment' (evite split piegeux)
    while ($cmt =~ /([^\n]*)\n/g)
    {
        $tab_cmt[$totalCmtLines] = $1;
        $totalCmtLines++;
    }

    # parcours de la vue code
    while ($code =~ m{\n}g)
    {
        my $end = pos($code);
        my $ligne = substr($code, $deb, $end - $deb);

        $codeLine++;
        if ($ligne =~ /\A\s*\Z/)
        {
            # pas de code sur cette ligne
            $deb = $end;
            next;
        }

        # analyse de la ligne de code
        if (defined $maybeFunc)
        {
            # confirmation de definition de fonction ?
            if ($ligne =~ /\A\s*\{/)
            {
                if ($mainFunc == 0 && $maybeFunc =~ /\Amain\Z/)
                {
                    $mainFunc = 1;
                }
                $localNames{$maybeFunc} = $FONC;
                Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_LocalVariables(), $ligne, "Fonction = $maybeFunc");
                $funcCmtToCheck = $codeLine - 2;
                $nbFunc++;
            }
            else
            {
                Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_LocalVariables(), $ligne, "$maybeFunc ignore");
            }
            $maybeFunc = undef;
        }
        elsif ($ligne =~ /\A\s*function\s+(\S+)\b\s*(\{)?.*/)
        {
            # definition de fonction ?
            if (defined $2)
            {
                $foncName = $1;
                if ($mainFunc == 0 && $foncName =~ /\Amain\Z/)
                {
                    $mainFunc = 1;
                }
                $localNames{$foncName} = $FONC;
                Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_LocalVariables(), $ligne, "Fonction = $foncName");
                $funcCmtToCheck = $codeLine - 1;
                $nbFunc++;
            }
            else
            {
                $maybeFunc = $1;
            }
        }
        elsif ($ligne =~ /\A\s*(\w+)\s*\(\)\s*(\{)?.*/)
        {
            # definition de fonction ?
            if (defined $2)
            {
                $foncName = $1;
                if ($mainFunc == 0 && $foncName =~ /\Amain\Z/)
                {
                    $mainFunc = 1;
                }
                $localNames{$foncName} = $FONC;
                Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_LocalVariables(), $ligne, "Fonction = $foncName");
                $funcCmtToCheck = $codeLine - 1;
                $nbFunc++;
            }
            else
            {
                $maybeFunc = $1;
            }
        }
        elsif ($ligne =~ /\A\s*export\s+([^=\s]+)=.*/)
        {
            # definition d'une variable exportee
            if (exists($localNames{$1}))
            {
                # la variable etait deja apparue declaree comme locale
                delete $localNames{$1};
                $exportNames{$1} = $EXPORT_DECL;
                $varName = $1;
                Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_ExportedVariables(), $ligne, "variable $varName locale devient exportee");
            }
            elsif (! exists($exportNames{$1}))
            {
                # on compte une seule fois la declaration d'une variable
                # exportee eventuellement redefinie
                $exportNames{$1} = $EXPORT_DECL;
                $varCmtToCheck = $codeLine;
                $nbVariableDeclarations++;
                my $expVar = $1;
                Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_ExportedVariables(), $ligne, "variable exportee $expVar");
            }
        }
        elsif ($ligne =~ /\A\s*export\s+([^=]+)\s*\n/)
        {
            my @exportList = split(/\s+/, $1);
            foreach my $exportVar (@exportList)
            {
                if (exists($localNames{$exportVar}))
                {
                    # exportation d'une variable precedemment declaree comme locale
                    delete $localNames{$exportVar};
                    Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_ExportedVariables(), $ligne, "variable $exportVar locale devient exportee");
                }
                else
                {
                    Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_ExportedVariables(), $ligne, "variable definie exportee $exportVar");
                }
                $exportNames{$exportVar} = $EXPORT_ADD;
            }
        }
        elsif ($ligne =~ /\A\s*alias\s+(-\w\s+)?(\S+)=/)
        {
            if (defined $2)
            { 
                # alias avec option(s)
                $localNames{$2} = $ALIAS;
                $nbAlias++;
                Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_Alias(), $ligne, "");
            }
            else
            {
                # alias sans option
                $localNames{$1} = $ALIAS;
                $nbAlias++;
                Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_Alias(), $ligne, "");
            }
        }
        elsif ($ligne =~ /\A\s*typeset\s+(-\w+\s+)?([^\s=]+)/)
        {
            # detection de typeset avec ou sans option,
            # avec ou sans affectation
            if (! exists($exportNames{$2}) && ! exists($localNames{$2}) )
            {
                $localNames{$2} = $TYPESET;
                $varName = $2;
                Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_LocalVariables(), $ligne, "TYPESET variable $varName");
                $varCmtToCheck = $codeLine;
                $nbVariableDeclarations++;
            }
        }
        elsif ($ligne =~ /\A\s*integer\s+(\w+)/)
        {
            # detection de integer (equivalent a typeset -i)
            $localNames{$1} = $TYPESET;
            $varName = $1;
            Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_LocalVariables(), $ligne, "INTEGER variable $varName");
            $varCmtToCheck = $codeLine;
            $nbVariableDeclarations++;
        }
        elsif ($ligne =~ /\A\s*set\s+-A\s+(\S+).*/)
        {
            # detection de declaration d'un tableau par 'set -A'
            $localNames{$1} = $SET;
            $varName = $1;
            Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_LocalVariables(), $ligne, "SET ARRAY $varName");
            $varCmtToCheck = $codeLine;
            $nbVariableDeclarations++;
        }
        elsif ($ligne =~ /\A\s*\(?\(?(\s*[^\$\s=]+)=[^=]/)
        {
            # detection d'une affectation de variable
            my $left = $1;
            if ($left =~ /\[.*\]/)
            {
                $left =~ s/\[.*//;
            }
            if (! exists($exportNames{$left}) && ! exists($localNames{$left}) )
            {
                # la variable n'a pas ete precedemment declaree
                # cette affectation est comptee comme une mauvaise declaration
                # de la variable
                $localNames{$left} = $AFFECT;
                Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_LocalVariables(), $ligne, "AFFECTATION variable $left");
                $nbBadDecl++;
            }
        }
        elsif ($ligne =~ /\A\s*let\s+([^=]+)=.*/)
        {
            # detection d'une affectation de variable par let
            my $letVar = $1;
            if (! exists($exportNames{$letVar}) && ! exists($localNames{$letVar}) )
            {
                # la variable n'a pas ete precedemment declaree
                # cette affectation est comptee comme une mauvaise declaration
                # de la variable
                $localNames{$letVar} = $LET;
                Erreurs::LogInternalTraces ("DEBUG", $fileName, $codeLine + 1, Ident::Alias_LocalVariables(), $ligne, "LET variable $letVar");
                $nbBadDecl++;
            }
        }

        # presence d'un commentaire de declaration ?
        if ($varCmtToCheck != $varCmtNoCheck)
        {
            my $lineCmt = $tab_cmt[$varCmtToCheck];
            if ($lineCmt =~ /\s*#\s*\S+/)
            {
                $commentedVars++;
            }
            $varCmtToCheck = $varCmtNoCheck;
        }
        elsif ($funcCmtToCheck > $funcCmtNoCheck)
        {
            my $funcHdr = $tab_cmt[$funcCmtToCheck];
            if ($funcHdr =~ /\A#/)
            {
                $commentedFuncs++;
            }
            $funcCmtToCheck = $funcCmtNoCheck;
        }

        $deb = $end;
    }

    print STDERR "nbVariableDeclarations : $nbVariableDeclarations   nbBadDecl : $nbBadDecl\n" if ($debug != 0);

    $status |= Couples::counter_add($compteurs, Ident::Alias_LocalVariables(), scalar keys %localNames);
    $status |= Couples::counter_add($compteurs, Ident::Alias_ExportedVariables(), scalar keys %exportNames);

    # verification de nomenclature des symboles locaux (variables, alias, fonctions)
    my $goodChars = 0;
    my $tooShort = 0;
    my $MIN_VAR_LENGTH = 3;


    foreach my $locName (sort keys %localNames)
    {
        if (length($locName) <= $maxLength)
        {
            if ($locName =~ /$localFilter/o)
            {
                $goodChars++;
            }
            else
            {
                Erreurs::LogInternalTraces ("DEBUG", $fileName, 1, Ident::Alias_WellNamedLocalVariables(), "", "Nom de variable locale ($locName) nok");
            }
            if (length($locName) < $MIN_VAR_LENGTH)
            {
                $tooShort++;
                my $savDebug = $debug;
                Erreurs::LogInternalTraces ("DEBUG", $fileName, 1, Ident::Alias_ShortVarName(), "", "Nom de variable locale trop court ($locName)");
                $debug = $savDebug;
            }
        }
    }
    $status |= Couples::counter_add($compteurs, Ident::Alias_WellNamedLocalVariables(), $goodChars);
    $status |= Couples::counter_add($compteurs, Ident::Alias_ShortVarName(), $tooShort);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Alias(), $nbAlias);

    # verification de nomenclature des variables exportees
    my $good = 0;

    foreach my $expName (keys %exportNames)
    {
        if (length($expName) <= $maxLength)
        {
            if ($expName =~ /$exportFilter/o)
            {
                $good++;
            }
        }
    }
    $status |= Couples::counter_add($compteurs, Ident::Alias_WellNamedExportedVariables(), $good);

#    $status |= Couples::counter_add($compteurs, "Nbr_VarFuncDecl", $nbFunc + $nbVariableDeclarations);
    $status |= Couples::counter_add($compteurs, "Nbr_CommentedVarFunc", $commentedFuncs + $commentedVars);

    $status |= Couples::counter_add($compteurs, Ident::Alias_FunctionMethodImplementations(), $nbFunc);
    $status |= Couples::counter_add($compteurs, Ident::Alias_VariableDeclarations(), ($nbVariableDeclarations + $nbBadDecl));
    $status |= Couples::counter_add($compteurs, Ident::Alias_WellDeclaredVariables(), $nbVariableDeclarations);

 
    return $status;
}


# Fonction   : CheckIndent
# Parametres : table de hachage des couples elementaires.
#              vue sur le code.
#              
# Retour     : 0 si succes
#              64 si la sauvegarde d'un couple a echoue
#
# Renseigne les compteurs de :
# - nombre de lignes de code (obsolete : fait par CountCommun)
# - nombre de lignes de code correctement indentees
#
# Restriction : une ligne de cloture d'insertion de document en place
# commence sans indentation et peut donc apparaitre comme mal indentee
# (par rapport au niveau logique de son ouverture)
#
sub CheckIndent($$$)
{
    my ($fichier, $compteurs, $code) = @_;

    my $status = 0;

    my $deb = 0;         # position de debut de la ligne de code courante
    my @tabIndent = ( ); # memorisation des indentations par niveaux logiques
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
                               # case-esac

    my $nbThen= 0;
    my $nbDo = 0;
    my $nbCase = 0;
    my $nbSwitch = 0;
    my $nbDefault = 0;
    my $nbSuspiciousLastCase = 0;

    $caseEntryLevels[0] = 0;

    my $saveDebug = $debug;

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
        if ($waitIn != 0)
        {
            # confirmation de debut de definition de case ... in
            if ($ligne =~ /\A\s*in\b/)
            {
                $nextLevel = $level +1;
                $caseEntryLevels[$nextLevel] = 1;
                $nbSwitch++;
            }
            $waitIn = 0;
        }
        elsif ($ligne =~ /\A\s*case\b.*(in)?.*/x)
        {
            if ($ligne =~ /\A\s*case\b.*\b(in)\b/)
            {
                $nextLevel = $level + 1;
                $caseEntryLevels[$nextLevel] = 1;
                $nbSwitch++;
            }
            else
            {
                # 'case' a ete lu mais pas le 'in' qui devrait le suivre
                # attendu en ligne suivante ...
                $waitIn = 1;
            }
        }
        elsif ($ligne =~ /\A\s*\(\(/)
        {
            # on neutralise la confusion possible entre calcul aritmethique
            # et entree d'un cas d'une structure case-esac
        }
        elsif ($ligne =~ /\A\s*(.*)\bthen\b\s*\n/x)
        {
            $nbThen++;
            if ($1 =~ /elif\b.*/)
            {
                # elif ... then
                $level-- if ($level > 0);
                $nextLevel = $level + 1;
            }
            else
            {
                # then non precede de elif
                $nextLevel = $level + 1;
                $caseEntryLevels[$nextLevel] = 0;
            }
        }
        elsif ($ligne =~ /\A.*\bdo\b\s*\n/)
        {
            # mot-cle 'do' en fin de ligne
            $nextLevel = $level + 1;
            $caseEntryLevels[$nextLevel] = 0;
            $nbDo++;
        }
        elsif ($ligne =~ /\A\s*else\b/)
        {
            $level-- if ($level > 0);
            $nextLevel = $level + 1;
        }
        elsif ($ligne =~ /\A\s*elif\b/)
        {
            $level-- if ($level > 0);
            $nextLevel = $level; # en attente de then
        }
        elsif ($ligne =~ /\A\s*(done\b|fi\b)/x)
        {
            $level-- if ($level > 0);
            $nextLevel = $level;
        }
        elsif ($ligne =~ /\A\s*(esac\b)/)
        {
            my $esacOk = 1;
            if ($caseEntryLevels[$level] == 0)
            {
                if ($level > 1 && $caseEntryLevels[$level-1] != 0)
                {
                    # esac est precede d'un dernier cas non termine par ;;
                    $level -= 2;
                    $nbSuspiciousLastCase++;
                }
                else
                {
                    $esacOk = 0;
                }
            }
            elsif ($caseEntryLevels[$level] != 0)
            {
                $level-- if ($level > 0);
            }
            else
            {
                $esacOk = 0;
            }
            if ($esacOk != 0 && $#caseEntryLevels >= ($level+1))
            {
                # apres fermeture d'une structure case-esac, on re-initialise
                # les entrees des niveaux logiques imbriques 
                # dans le tableau caseEntryLevels
                for (my $supLevel = $level+1; $supLevel <= $#caseEntryLevels; $supLevel++)
                {
                    $caseEntryLevels[$supLevel] = 0;
                }
            }
            else
            {
                Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "esac inattendu au niveau $level");
            }
            $nextLevel = $level;
        }
        elsif ($caseEntryLevels[$level] != 0 && $ligne =~ /\A\s*\(?([^\)]+)\)[^\)]/x)
        {
            if ($1 eq "*")
            {
                $nbDefault++;
            }
            else
            {
                $nbCase++;
            }
            # on s'attend a ce que la ligne suivante traite le cas ouvert
            # dans la ligne courante
            $nextLevel = $level +1;
            $caseEntryLevels[$nextLevel] = 0;
            # Test ajoute pour lever l'ambiguite entre une alternative
            # de cas de test et un enchainement de processus
            if (($1 =~ tr{|}{|}) != 0)
            {
                $alternCase{$totalLines} = 1;
            }

        }
        if ($ligne =~ /\A.*;;/)
        {
            if ($caseEntryLevels[$level] != 0)
            {
                # caseEntry) .... ;;
                $nextLevel = $level;
            }
            elsif ($level > 0)
            {
                # la ligne suivante devrait ouvrir le traitement d'un nouveau cas
                # de structure case-esac
                $nextLevel = $level - 1;
            }
            else
            {
                # garde-fou
                $nextLevel = $level;
            }
        }

        # recherche des ouvertures ou fermetures de blocs entoures d'accolades
        my $openBrace = ($ligne =~ tr/\{/\{/);
        my $closeBrace = ($ligne =~ tr/}/}/);

        if ($closeBrace != $openBrace)
        {
            if ($openBrace == ($closeBrace+1))
            {
                $nextLevel++;
                $caseEntryLevels[$nextLevel] = 0;
            }
            elsif ($closeBrace == ($openBrace+1))
            {
                $level-- if ($level > 0);
                $nextLevel = $level;
            }
            else
            {
                Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "Trop d'accolades");
            }
        }

        print STDERR "Niveau : $level Prochain : $nextLevel\n" if ($debug != 0);
        # verification de l'indentation de la ligne
        # en fonction de son niveau logique
        if ($level > $#tabIndent)
        {
            # niveau de profondeur jamais atteint
            if ($#tabIndent >= 0)
            {
                # niveau superieur connu
                if ($indent > $tabIndent[$level-1])
                {
                    $codeLinesOk++;
                }
                else
                {
                    # niveau mal indentee : indentation <= celle du niveau imbriquant
                    Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "indentation ($indent) pour niveau $level <= celle du niveau precedent");
                }
            }
            else
            {
                # 1ere ligne de code
                $codeLinesOk++;
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
                Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "bloc de niveau $level non decale a droite ($indent)");
            }
            else
            {
                $codeLinesOk++;
            }
        }
        elsif ($level > 0 && $tabIndent[$level-1] >= $tabIndent[$level]
                          && $indent > $tabIndent[$level-1])
        {
            # on essaie de rattraper une mauvaise indentation en debut de niveau
            $tabIndent[$level] = $indent;
            Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "Rattrapage mauvaise indentation niveau $level devient $indent\n");
            $codeLinesOk++;
        }
        else
        {
            Erreurs::LogInternalTraces ("DEBUG", $fichier, $totalLines, Ident::Alias_IndentedLines(), $ligne, "Ligne (niveau $level) mal indentee ($indent) (cas desespere)");
            # meme si l'homogeneite de l'indentation du fichier est critiquable
            # peut-etre les lignes suivantes du meme niveau logique vont-elles
            # suivre ce nouveau pas d'indentation
            $tabIndent[$level] = $indent; # pas trop exigeant ...
        }

        $prevLevel = $level;
        $level = $nextLevel;
        $deb = $end;
    }


#    $status |= Couples::counter_add($compteurs, Ident::Alias_LinesOfCode(), $codeLines);
    $status |= Couples::counter_add($compteurs, Ident::Alias_IndentedLines(), $codeLinesOk);

    $status |= Couples::counter_add($compteurs, Ident::Alias_Then(), $nbThen);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Do(), $nbDo);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Case(), $nbCase);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Switch(), $nbSwitch);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Default(), $nbDefault);
    $status |= Couples::counter_add($compteurs, Ident::Alias_SuspiciousLastCase(), $nbSuspiciousLastCase);

    $debug = $saveDebug;

    return $status;
}


# Fonction   : CountNotPureKsh
# Parametres : options de la ligne de commande.
#              table de hachage des couples elementaires.
#              vue sur le code.
#              
# Retour     : 0 si OK
#              1 si le nombre de quotes inverses lues est impair
#              64 si la sauvegarde d'un couple a echoue
#
# Renseigne le compteur d'invocations n'utilisant pas les intrinsèques du
# Korn shell
#
# Korn intrincic     Bourne     External
# print              echo
# $(command)         `command`
# [[ ]]                         [ ]
#
# Vu sa frequence d'utilisation, le mot cle 'echo' n'est comptabilise que sur
# option '--count-echo'
#
sub CountNotPureKsh($$$)
{
    my ($options, $compteurs, $code) = @_;

    my $status = 0;

    my $backQ = 0;    # comptage des quotes inverses (a l'unite puis par paires)
    my $brackets = 0; # comptage des ouvertures de test par crochet simple '['
    my $echos = 0;    # comptage de l'utilisation de la commande echo

    my $beg = 0;


    # detection des constructions non optimales
    while ($code =~ /(`|[^\[]\[\s|\becho\b)/gx)
    {
        if ($1 eq "echo")
        {
            $echos++;
        }
        else
        {
            $beg = pos($code) - length($1);
            next if ( ( $beg > 0 ) && ( substr($code, $beg - 1, 1) eq "\\"));
            if ($1 eq "`")
            {
                $backQ++;
            }
            else
            {
                $brackets++;
            }
        }
    }

    # verification de la parite des quotes inverses
    my $impair = 0;
    if ( ($backQ % 2) != 0 )
    {
        $impair = 1;
        $backQ = ($backQ - 1) / 2;
    }
    else
    {
        $backQ = $backQ / 2;
    }
    my $cptNotPure = $backQ + $brackets;
    if (exists($options->{'--count-echo'}))
    {
        $cptNotPure += $echos;
    }
    if ($impair)
    {
#FL : L'utilisation d'une , dans le csv entraine un problème de compatibilité
#FL : dans l'outil de calcul car une valeur x,y n'est pas numérique pour perl
#FL : c'est pas grave de ne prendre que la valeur entière pour la valeur du compteur
#FL
#        my $virgule = ","; # valeur du separateur decimal pour MS-Excel
                           # en version francaise
#        $cptNotPure .= $virgule . "5";
    }

    $status |= Couples::counter_add($compteurs, Ident::Alias_NotPureKsh(), $cptNotPure);

    return ($status | $impair);
}


# Fonction   : CountPipes
# Parametres : table de hachage des couples elementaires.
#              vue sur le code.
#              
# Retour     : 0
#              64 si la sauvegarde d'un couple a echoue
#
# Renseigne les compteurs :
# - d'enchainements de processus (pipes)
# - d'enchainement maximal de processus (maximum de pipes relies)
#
# Restriction : ignore les pipes sur la meme ligne qu'une alternative de cas
#
# Requis : la fonction CheckIndent doit avoir ete appelee au prealable
#
sub CountPipes($$)
{
    my ($compteurs, $code) = @_;

    my $status = 0;

    # variables locales
    my $maxPipeChain = 0;
    my $cumulPipes = 0;   # cumul courant de pipes enchaines
    my $lastPipe = -1;
    my $totalPipes = 0;
    my $curLine = 1;

    while ($code =~ /([^\|\>]\|[^\|\&]|\n)/gx)
    {
        if ($1 eq "\n")
        {
            if ($lastPipe > 0)
            {
                my $end = pos($code);
                if (substr($code, $lastPipe + 1, $end - $lastPipe - 2) =~ /\w/)
                {
                    # l'enchainement de processus est termine
                    $lastPipe = -1;
                    $maxPipeChain = $cumulPipes if ($cumulPipes > $maxPipeChain);
                    $cumulPipes = 0;
                }
                else
                {
                    # un caractère '|' est toujours en attente de sa cloture
                }
            }
            $curLine++;
        }
        else
        {
            # un pipe est plausible
            # un caractere '|' a ete detecte et n'est pas precede de '|' ou '>'
            # et n'est pas suivi de '|', ni de '&'
            if (! exists($alternCase{$curLine}) )
            {
                # on n'est pas dans le cas de la description
                # d'une alternative de cas
                $totalPipes++;
                $lastPipe = pos($code) - 2;
                $cumulPipes++;
            }
            else
            {
                # Restriction : on ignore une ligne vicieuse
                # debutant par une alternative de cas (structure case-esac)
                # suivie de code comprenant un ou plusieurs "pipes"
            }
            if (substr($1, 2, 1) eq "\n")
            {
                # une fin de ligne a ete capturee juste derriere le pipe
                $curLine++;
            }
        }
    }

    $status |= Couples::counter_add($compteurs, Ident::Alias_Pipes(), $totalPipes);
    $status |= Couples::counter_add($compteurs, Ident::Alias_MaxChainedPipes(), $maxPipeChain);

    return $status;
}


# Fonction   : DetectBackground
# Parametres : table de hachage des couples elementaires.
#              vue sur le code.
#              
# Retour     : 0 si succes
#              64 si la sauvegarde d'un couple a echoue
#
# Renseigne le compteur booleen de lancement d'un processus en arriere-plan
# par & ou nohup
#
sub DetectBackground($$)
{
    my ($compteurs, $code) = @_;

    my $status = 0;

    # variables locales
    my $bg = 0; # compteur booleen de detection de lancement de tache de fond
                # par nohup ou &

    #if ($code =~ /\n\s*nohup\b|[^&|]\&\s*\n/x)
    # nohup does not turn automatically the process in background.
    if ($code =~ /[^&|]\&\s*\n/x)
    {
        $bg = 1;
    }

    $status |= Couples::counter_add($compteurs, Ident::Alias_Background(), $bg);

    return $status;
}


# Fonction   : CountFlow
# Parametres : table de hachage des couples elementaires.
#              vue sur le code.
#              nom du fichier source (optionnel)
#              
# Retour     : 0 si succes
#              64 si la sauvegarde d'un couple a echoue
#
# Detecte les destructurations ou deroutement suspect du flot de controle
# Nbr_Exit, Nbr_WithoutFinalExit, Nbr_WithoutValueExit, Nbr_Break, Nbr_Continue
#
sub CountFlow($$$;)
{
    my ($compteurs, $code, $fName) = @_;

    my $status = 0;
    my $nbExit = 0;
    my $nbExitNoVal = 0;
    my $nbWithoutFinalExit = 0;
    my $nbBrk = 0;
    my $nbCont = 0;
    my $lastExit = 0;
    my $lastCodeLine = 0;

    my $saveDebug = $debug;

    $fName = "" if (!defined $fName);

    # parcours de la vue code
    my $deb = 0;
    my $codeLine = 0;
    while ($code =~ m{\n}g)
    {
        my $end = pos($code);
        my $ligne = substr($code, $deb, $end - $deb);

        $codeLine++;
        if ($ligne =~ /\A\s*\Z/)
        {
            # pas de code sur cette ligne
            $deb = $end;
            next;
        }
        $lastCodeLine = $codeLine;

        # analyse de la ligne de code

        if ($ligne =~ /\bbreak\b/)
        {
            $nbBrk++;
            Erreurs::LogInternalTraces ("DEBUG", $fName, $codeLine, Ident::Alias_Break(), $ligne, "($nbBrk)");
        }
        elsif ($ligne =~ /\bcontinue\b/)
        {
            $nbCont++;
            Erreurs::LogInternalTraces ("DEBUG", $fName, $codeLine, Ident::Alias_Continue(), $ligne, "($nbCont)");
        }
        elsif ($ligne =~ /\bexit\b\s*([\-\$\w]*)/)
        {
            $nbExit++;
            $lastExit = $lastCodeLine;
            if (! defined $1 || $1 =~ /\A\s*\Z/)
            {
                $nbExitNoVal++;
                Erreurs::LogInternalTraces ("DEBUG", $fName, $codeLine, Ident::Alias_WithoutValueExit(), $ligne, "($nbExitNoVal)");
            }
            else
            {
                Erreurs::LogInternalTraces ("DEBUG", $fName, $codeLine, Ident::Alias_Exit(), $ligne, "($nbExit)");
            }
        }
        $deb = $end;
    }

    if ($lastExit == $lastCodeLine)
    {
        $nbWithoutFinalExit = 1;
    }

    $status |= Couples::counter_add($compteurs, Ident::Alias_Exit(), $nbExit);
    $status |= Couples::counter_add($compteurs, Ident::Alias_WithoutValueExit(), $nbExitNoVal);
    $status |= Couples::counter_add($compteurs, Ident::Alias_WithoutFinalExit(), $nbWithoutFinalExit);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Break(), $nbBrk);
    $status |= Couples::counter_add($compteurs, Ident::Alias_Continue(), $nbCont);

    $debug = $saveDebug;

    return $status;
}


# Fonction   : CountMultInst
# Parametres : table de hachage des couples elementaires.
#              vue sur le code.
#              nom du fichier source (optionnel)
#              
# Retour     : 0 si succes
#              64 si la sauvegarde d'un couple a echoue
#
# Compte les lignes de codes contenant plusieurs instructions (hors pipe-lines)
# Calcule le compteur :
# Nbr_Mult_Inst : nombre de lignes contenant plusieurs instructions séparées par ';'
#                 ('\;' ignore pour find ... -exec)
#
sub CountMultInst($$$;)
{
    my ($compteurs, $code, $fName) = @_;

    $fName = "" if (!defined $fName);

    my $status = 0;
    my $nbMultipleStatementsOnSameLine = 0;

    my $saveDebug = $debug;


    # parcours de la vue code
    my $deb = 0;
    my $codeLine = 0;
    while ($code =~ m{\n}g)
    {
        my $end = pos($code);
        my $ligne = substr($code, $deb, $end - $deb);

        $codeLine++;
        if ($ligne =~ /\A\s*\Z/)
        {
            # pas de code sur cette ligne
            $deb = $end;
            next;
        }

        # analyse de la ligne de code

#        if ($ligne =~ /[^;]*[^\\];.*\w/)  # ignore \; bien aime de find -exec ... {} \;
        if ($ligne =~ /[^;]*;\s*(\w.*)$/)
        {
            if (defined($1) && $1 !~ /(then|do)\s*$/x)
            {
                $nbMultipleStatementsOnSameLine++;
                Erreurs::LogInternalTraces ("DEBUG", $fName, $codeLine, Ident::Alias_MultipleStatementsOnSameLine(), $ligne, "($nbMultipleStatementsOnSameLine)");
            }
        }
        $deb = $end;
    }

    $status |= Couples::counter_add($compteurs, Ident::Alias_MultipleStatementsOnSameLine(), $nbMultipleStatementsOnSameLine);

    $debug = $saveDebug;

    return $status;
}

# Fonction   : DetectTmpFile
# Parametres : table de hachage des couples elementaires.
#              vue sur le code.
#              nom du fichier source (optionnel)
#
# Retour     : 0 si succes
#              64 si la sauvegarde d'un couple a echoue
#
# Detecte les utilisations de fichiers temporaires
# Calcule les compteurs :
# Nbr_BadTmpName : nombre de fichiers temporaires dont le nom ne depend pas de
#                  l'instance du processus
# Nbr_TmpNotCleaned : nombre de fichiers temporaires non detruits (TBC)
#
sub DetectTmpFile($$$;)
{
    my ($compteurs, $code, $fName) = @_;

    $fName = "" if (!defined $fName);

    my $status = 0;
    my $nbBadTmp = 0;

    my $saveDebug = $debug;


    # parcours de la vue code
    my $deb = 0;
    my $codeLine = 0;
    while ($code =~ m{\n}g)
    {
        my $end = pos($code);
        my $ligne = substr($code, $deb, $end - $deb);

        $codeLine++;
        if ($ligne =~ /\A\s*\Z/)
        {
            # pas de code sur cette ligne
            $deb = $end;
            next;
        }

        # analyse de la ligne de code

        if ($ligne =~ /\/tmp\//)
        {
            if ($ligne =~ /\$\(([^\)]*)\)/)
            {
                if (defined $1)
                {
                    $ligne =~ s/\$\(/__ISOSCO__CMD__/;
                    $ligne =~ s/(__ISOSCO__CMD__[^\)]*)\)/$1__ISOSCO__FIN__CMD__/;
                }
            }
            elsif ($ligne =~ /(\`[^\`]+\`)/)
            {
                if (defined $1)
                {
                    $ligne =~ s/\`/__ISOSCO__CMD__/;
                    $ligne =~ s/(__ISOSCO__CMD__[^\`]*)\`/$1__ISOSCO__FIN__CMD__/;
                }
            }
            if ($ligne =~ /\/tmp\/(.*__ISOSCO__CMD__.*__ISOSCO__FIN__CMD__)/)
            {
                if (defined $1 && $1 !~ /\$\$/)
                {
                    if ($ligne !~ /__ISOSCO__FIN__CMD__\S*\$\$/)
                    {
                        $nbBadTmp++;
                        Erreurs::LogInternalTraces ("DEBUG", $fName, $codeLine, Ident::Alias_BadTmpName(), $ligne, "($nbBadTmp)");
                    }
                }
            }
            elsif ($ligne !~ /\/tmp\/\S*\$\$/)
            {
                $nbBadTmp++;
                Erreurs::LogInternalTraces ("DEBUG", $fName, $codeLine, Ident::Alias_BadTmpName(), $ligne, "($nbBadTmp)");
            }
        }
        $deb = $end;
    }

    $status |= Couples::counter_add($compteurs, Ident::Alias_BadTmpName(), $nbBadTmp);

    $debug = $saveDebug;

    return $status;
}


# Fonction   : CountKsh
# Parametres : nom du fichier traite.
#              vues sur le contenu du fichier traite.
#              table de hachage des couples elementaires.
# Retour     : 0 si succes;
#              1 si au moins 1 comptage a echoue;
#              2 si une vue necessaire aux comptages manque;
#              4 en cas d'erreur d'interface avec la gestion de couples
#                elementaires;
#              64 si la sauvegarde d'un couple a echoue
#
# Lance successivement chacun des compteurs propres au langage Ksh
#
sub CountKsh($$$$)
{
    my ($fichier, $vues, $couples, $options) = @_;
    my $echecs = 0;
    my $status = 0;

    init();

    if (!defined $vues)
    {
        return Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
    if (! defined $couples)
    {
        return Erreurs::COMPTEUR_STATUS_INTERFACE_COMPTEUR;
    }

    $echecs |= CountBinaryFile::CountBinaryFile($fichier, $vues, $couples);
    if (defined $vues->{'comment'})
    {
        $echecs |= Line1Ctrl($couples, $vues->{'comment'});
        $echecs |= CountComments($couples, $vues->{'comment'}, $fichier);
        $echecs |= CountSuspiciousComments::CountSuspiciousComments($fichier, $vues, $couples);
    }
    else
    {
        $status = Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    if (defined $vues->{'code'})
    {
        $echecs |= isIFSModified($couples, $vues->{'code'});
        $echecs |= isGetoptUsed($couples, $vues->{'code'});
        $echecs |= DetectVarsFuncAlias($fichier, $couples, $vues->{'code'}, $vues->{'comment'});
        $echecs |= ArgsNbrChecked($couples, $vues->{'code'});
        $echecs |= CheckIndent($fichier, $couples, $vues->{'code'});
        $echecs |= CountNotPureKsh($options, $couples, $vues->{'code'});
        $echecs |= CountPipes($couples, $vues->{'code'});
        $echecs |= DetectBackground($couples, $vues->{'code'});
        $echecs |= CountFlow($couples, $vues->{'code'}, $fichier);
        $echecs |= CountMultInst($couples, $vues->{'code'}, $fichier);
        $echecs |= DetectTmpFile($couples, $vues->{'code'}, $fichier);
        $echecs |= CountWords($fichier, $vues, $couples);
    }
    else
    {
        $status = Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

    $echecs |= CountVG($fichier, $vues, $couples, $options);

    if ($status == 0)
    {
        $echecs |= CountCommun::CountCommun($fichier, $vues, $couples);
        $echecs |= CountCommun::CountLinesOfCode(undef, $vues, $couples);
        $echecs |= CountLongLines::CountLongLines(undef,  $vues, $couples);
    }

    return ($status | $echecs);
}

sub _Strip_ {
  # Fonction bouchon identifiee dans "global_archi.conf" pour le calcul des comptages deja effectues dans le Strip.
  return;
}

sub CountVG($$$$)
{
    my $status;
    my $nb_VG = 0;
    my $VG__mnemo = Ident::Alias_VG();
    my ($fichier, $vue, $compteurs, $options) = @_;

    if (  ( ! defined $compteurs->{Ident::Alias_Then()}) ||
	  ( ! defined $compteurs->{Ident::Alias_Case()}) || 
	  ( ! defined $compteurs->{Ident::Alias_Default()}) || 
	  ( ! defined $compteurs->{Ident::Alias_Do()}) || 
	  ( ! defined $compteurs->{Ident::Alias_FunctionMethodImplementations()}) )
    {
      $nb_VG = Erreurs::COMPTEUR_ERREUR_VALUE;
    }
    else {
      $nb_VG = $compteurs->{Ident::Alias_Then()} +
	       $compteurs->{Ident::Alias_Case()} +
	       $compteurs->{Ident::Alias_Default()} +
	       $compteurs->{Ident::Alias_Do()} +
	       $compteurs->{Ident::Alias_FunctionMethodImplementations()};
    }

    $status |= Couples::counter_add($compteurs, $VG__mnemo, $nb_VG);
}


1;

