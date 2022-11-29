
package JS::CountVariable ;

use strict;
use warnings;

use Erreurs;
use Lib::NodeUtil;
use JS::JSNode;

use Ident;
use JS::Identifiers;
use JS::CountNaming;

my $IDENTIFIER = JS::Identifiers::getIdentifiersPattern();
my $IDENT_CHAR = JS::Identifiers::getIdentifiersCharacters();
my $DEREF_EXPR = JS::Identifiers::getDereferencementPattern();

my $SELECTOR = '(?:document\.getElementById|\$)\s*\(';

use constant LIMIT_SHORT_GLOBALVAR_NAMES => 5;

my $mnemo_ShortGlobalNamesLT = Ident::Alias_ShortGlobalNamesLT();
my $mnemo_BadVariableNames = Ident::Alias_BadVariableNames();
my $mnemo_BadSelectorCaching = Ident::Alias_BadSelectorCaching();
my $mnemo_ImpliedGlobalVar = Ident::Alias_ImpliedGlobalVar();
my $mnemo_MultipleDeclarationsInSameStatement = Ident::Alias_MultipleDeclarationsInSameStatement();
#my $mnemo_VariableDeclarations = Ident::Alias_VariableDeclarations();

my $nb_ShortGlobalNamesLT = 0;
my $nb_BadVariableNames = 0;
my $nb_BadSelectorCaching = 0;
my $nb_ImpliedGlobalVar = 0;
my $nb_MultipleDeclarationsInSameStatement = 0;
#my $nb_VariableDeclarations = 0;

my $UnitAnalysisStarted = 0;

sub startUnitAnalysis() {
  $UnitAnalysisStarted = 1;
}

sub incUnitCounter($;$) {
  my $counter = shift;
  my $value = shift;
  if ($UnitAnalysisStarted) {
    if (defined $value) {
      $$counter += $value;
    }
    else {
      $$counter++;
    }
  }
}


sub analyzeArtifact($$$$$);

sub analyzeArtifact($$$$$) {
  my $unit = shift;              # unit is the unit of code beeing analyzed. It is the same for all recusions of analyzeArtifact()
  my $ENV_var = shift;
  my $ENV_SelectorVar = shift;
  my $node = shift;              # node is a sub artifact of the main artifact "unit".
  my $artifactView = shift;

  # Check if the node is the unit we want to analyze...
  if ($node == $unit) {
    # From now, violations will be counted. 
    startUnitAnalysis();
  }


  # List of functions contained in the artifact.
  my @LOCAL_func = ();
  # List of var declared or used in the artifact.
  # When a variable is referenced in this list, it can not be considered
  # as an undeclared variable (and then an implicit global variable)
  my %LOCAL_or_IMPLICIT_GLOBAL_var = ();

  #-------------------------------------------------------------
  #----------- Get the artifact name ---------------------------
  #-------------------------------------------------------------
  my $artifactKey;
  if (IsKind($node, RootKind)) {
    $artifactKey = 'root';
  }
  else {
    my $name = GetName($node);
    my $line = GetLine($node);
    $artifactKey = buildArtifactKeyByData($name, $line);
  }

#print "----------ANALYZING $artifactKey ---------\n";

  #-------------------------------------------------------------
  #----------- Get parameters ----------------------------------
  #-------------------------------------------------------------
  
  my $r_params = Lib::NodeUtil::GetKindData($node);
  for my $param (@$r_params) {
    $LOCAL_or_IMPLICIT_GLOBAL_var{$param} = 1;
  }
  #-------------------------------------------------------------
  #----------- Get declared var & funcs ------------------------
  #-------------------------------------------------------------

  # Retrieve variables and functions declared in the scope (do not search into
  # functions).
  my @funcs_vars = GetNodesByKindList_StopAtBlockingNode(
	        $node, 
		[VarDeclKind, FunctionDeclarationKind, FunctionExpressionKind],
		[FunctionDeclarationKind, FunctionExpressionKind]);

  for my $node1 (@funcs_vars) {
    if (IsKind($node1, VarDeclKind)) {
      my $name = GetName($node1);

      #->->->->->-> treatment for declared variable ------
      #---------------------------------------------------
      
      incUnitCounter(\$nb_BadVariableNames, JS::CountNaming::checkLocalVarNaming(\$name));
#print "Found LOCAL ".$name."\n";
      $LOCAL_or_IMPLICIT_GLOBAL_var{$name} = 1;
    }
    else {
      push @LOCAL_func, $node1;
    }
  }

  #-------------------------------------------------------------
  #----------- Search variables intialized the artifact --------
  #-------------------------------------------------------------
  # get the corresponding artifact ...
  my $Artifact = $artifactView->{$artifactKey};
  my @SelectorVar = ();
  my %alreadyPunishedSelectorVar = ();

  # search VAR in a variable init expression of the form :
  #     VAR[.FIELD1.FIELD2. ...] = ...
  #     VAR[.FIELD1.FIELD2. ...] = $(...)
  #     VAR[.FIELD1.FIELD2. ...] = document.getElementById(...)
  #
#  while ($Artifact =~ /(?:\A|[^\.])($IDENTIFIER)(?:\.$DEREF_EXPR)?\s*=(?:\s*($SELECTOR)|[^=])/sg) {
  while ($Artifact =~ /(\.\s*)?($IDENTIFIER)(\s*\.\s*$DEREF_EXPR)?\s*(?:[+\-*\/\%\&\^\|]|<<|>>>?)?=(?:\s*($SELECTOR)|[^=])/sg) {

    # If the variable is preceded by a dot, go to next ...
    # -----------------------------------------------------
    if (defined $1) {
      next;
    }

    # detect if the variable is initialized with a selector.
    # -----------------------------------------------------
    my $selector = $4;

    # get name of the variable
    # ------------------------
    my $name = $2;
#print "VARIABLE $name\n";
    
    # Some name to exclude from the rule ...
    if ( $name =~ /^this|document|window|localStorage|sessionStorage$/ ) {
      next;
    }

    # If it is a prototype modification, go to next.
    # ----------------------------------------------
    if (defined $3) {
#print "DEREF = $3\n";
      if ( $3 =~ /\A\s*\.\s*prototype\b/ ) {
        next;
      }
    }

    # check if the variable has been declared before.
    # ------------------------------------------------
    my $declared_outside = 0;
    for my $H_var (@$ENV_var) {
      if ( exists $H_var->{$name}) {
#print "   --> is declared outside.\n";
        $declared_outside = 1;
        last;
      }
    }

    # If variable is not local
    if (! exists $LOCAL_or_IMPLICIT_GLOBAL_var{$name}) {

      # If variable is not from outside
      if (! $declared_outside ) {
      #->->->->->-> treatment for NEVER declared variable (implicit global) ----
      #-------------------------------------------------------------------------
#if ($UnitAnalysisStarted) {
#print "   --> global implicit !!!\n";
#}
#else {
#print "   --> global implicit, BUT FOR CONTEXT ONLY !!!\n";
#}
      incUnitCounter(\$nb_BadVariableNames,JS::CountNaming::checkGlobalVarNaming(\$name));
      incUnitCounter(\$nb_ShortGlobalNamesLT, JS::CountNaming::isNameTooShort(\$name, LIMIT_SHORT_GLOBALVAR_NAMES));
      incUnitCounter(\$nb_ImpliedGlobalVar, 1);

      if (defined $selector) {
#print "   --> bad selector caching (implicit global caching) ($name)!!!\n";
        # The variable is caching a selector and is implicit global.
	# If it has not already been encountered in this artifact,
	# punish it !!
        if (! exists $alreadyPunishedSelectorVar{$name}) {
          incUnitCounter(\$nb_BadSelectorCaching, 1);
	  $alreadyPunishedSelectorVar{$name}=1;
        } 
      }

      # if the variable was not declared, it is now known : in the future don't
      # count the violation several time in its scope (this artifact and inner
      # func).
      # RQ : LOCAL_or_IMPLICIT_GLOBAL_var has been added to the %ENV_var list, it's because the
      # var will not continue to be considered undeclared ... (!)
      $LOCAL_or_IMPLICIT_GLOBAL_var{$name} = 1;
      }


    else {
      # Variable has been declared in calling environment.
      # If it use a selector, it will share it at upper level ==> punish it !!
      if (defined $selector) {
        if (! exists $alreadyPunishedSelectorVar{$name}) {
#print "   --> bad selector caching (caching at upper level) ($name)!!!\n";
          incUnitCounter(\$nb_BadSelectorCaching, 1);
	  $alreadyPunishedSelectorVar{$name} = 1;
        }
      }
    }
    }

    # if the variable is not local,
    # check if it is a selector var initialized in calling environment :
    # --------------------------------------------------------------------
    if (! exists $LOCAL_or_IMPLICIT_GLOBAL_var{$name} ) {
      if ( exists $ENV_SelectorVar->{$name}) {
        if (! exists $alreadyPunishedSelectorVar{$name}) {
#print "   --> bad selector caching (using upper level caching) ($name)!!!\n";
          incUnitCounter(\$nb_BadSelectorCaching, 1);
	  $alreadyPunishedSelectorVar{$name} = 1;
        }
      }
    }

    # if the variable is caching a selector, memorizes it ...
    if (defined $selector) {
#print "** $name is caching $selector !!\n";
      push @SelectorVar, $name;
    }

   }
    # Add new selector caching vars in the list for inner artifacts analysis.
  for my $SV (@SelectorVar) {
    $ENV_SelectorVar->{$SV} = 1;
  }

  #-------------------------------------------------------------
  #----------- Analyze inner function artifact -----------------
  #-------------------------------------------------------------
  
  # Add local data to env for context of inner function ...
  unshift @$ENV_var, \%LOCAL_or_IMPLICIT_GLOBAL_var;

  if (!IsKind($unit, RootKind)) {
    # $node is the function that has just been analyzed. If $node == $unit,
    # don't analyzed it twice !!!
    # Don't start the unit analysis too if it is allready started !!!
    if  (($unit != $node) && (! $UnitAnalysisStarted)) {
      analyzeArtifact($unit, $ENV_var, $ENV_SelectorVar, $unit, $artifactView);
    }
    else {
      for my $func (@LOCAL_func) {
       analyzeArtifact($unit, $ENV_var, $ENV_SelectorVar, $func, $artifactView);
    }
    }
  }
  else {
    for my $func (@LOCAL_func) {
       analyzeArtifact($unit, $ENV_var, $ENV_SelectorVar, $func, $artifactView);
    }
  }

  # remove local data ...
  shift @$ENV_var;
}

sub CountVariable($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;
  my $status = 0;
  $nb_ShortGlobalNamesLT = 0;
  $nb_BadVariableNames = 0;
  $nb_BadSelectorCaching = 0;
  $nb_ImpliedGlobalVar = 0;

  $UnitAnalysisStarted = 0;
  
  if (not defined $vue->{'structured_code'})
  {
      $status |= Couples::counter_add ($compteurs, $mnemo_ShortGlobalNamesLT, Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BadVariableNames, Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BadSelectorCaching, Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_ImpliedGlobalVar, Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
  }

  my $root = $vue->{'structured_code'};

  # by default, the unit to analyze is root.
  my $unitArtifact = $root;

  # But if it is a virtual root (created for containing an unit), then the unit
  # to analyze should be extracted.
  if (GetName($root) eq 'virtualRoot') {

    # get the unit to analyze. 
    $unitArtifact = Lib::NodeUtil::GetChildren($root)->[0];

    # get the root corresponding to the full file (the original root)
    $root = $vue->{'full_file'}->{'structured_code'};
  }

  my $artifactView = $vue->{'artifact'};

  my @func = ();
  my %H_var = ();

  my @ENV_var         = (\%H_var);
  my %ENV_SelectorVar = ();

  # We will record only violations for $unitArtifact, but the analysis will 
  # start from the original root, because we need the context from the top
  # level.
  analyzeArtifact($unitArtifact, \@ENV_var, \%ENV_SelectorVar, $root, $artifactView);

  $status |= Couples::counter_add ($compteurs, $mnemo_ShortGlobalNamesLT, $nb_ShortGlobalNamesLT);
  $status |= Couples::counter_add ($compteurs, $mnemo_BadVariableNames, $nb_BadVariableNames);
  $status |= Couples::counter_add ($compteurs, $mnemo_BadSelectorCaching, $nb_BadSelectorCaching);
  $status |= Couples::counter_add ($compteurs, $mnemo_ImpliedGlobalVar, $nb_ImpliedGlobalVar);

  return $status;
}

sub CountMultipleDeclarations($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;
  my $status = 0;
  $nb_MultipleDeclarationsInSameStatement = 0;
  #$nb_VariableDeclarations = 0;

  my $root = $vue->{'structured_code'};

  if (not defined $root)
  {
      $status |= Couples::counter_add ($compteurs, $mnemo_MultipleDeclarationsInSameStatement, Erreurs::COMPTEUR_ERREUR_VALUE);
  }

  my @vars = GetNodesByKind($root, VarKind);

  #$nb_VariableDeclarations = scalar @vars;

  for my $var (@vars) {
    my @decl = GetNodesByKind($var, VarDeclKind, 1); # 1 : do not walk into subnodes.
    if (scalar @decl > 1) {
      $nb_MultipleDeclarationsInSameStatement++;
    }
  }

  $status |= Couples::counter_add ($compteurs, $mnemo_MultipleDeclarationsInSameStatement, $nb_MultipleDeclarationsInSameStatement);
  #$status |= Couples::counter_add ($compteurs, $mnemo_VariableDeclarations, $nb_VariableDeclarations);
}

1;
