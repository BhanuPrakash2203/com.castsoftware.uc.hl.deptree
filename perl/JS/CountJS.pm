package JS::CountJS;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use JS::JSNode;
use JS::Identifiers;
use CountBadSpacing;

my $IDENTIFIER = JS::Identifiers::getIdentifiersPattern();
my $IDENT_CHAR = JS::Identifiers::getIdentifiersCharacters();

my $UnecessaryNestedObjectResolution__mnemo = Ident::Alias_UnecessaryNestedObjectResolution();
my $MissingBreakInCasePath__mnemo = Ident::Alias_MissingBreakInCasePath();
my $UnauthorizedPrototypeModification__mnemo = Ident::Alias_UnauthorizedPrototypeModification();
my $This__mnemo = Ident::Alias_UnexpectedThis();

my $nb_UnecessaryNestedObjectResolution = 0;
my $nb_MissingBreakInCasePath = 0;
my $nb_UnauthorizedPrototypeModification = 0;
my $nb_UnexpectedThis = 0;

#-------------------------------------------------------------------------------
# DESCRIPTION: fonction de comptage d'item
#-------------------------------------------------------------------------------
sub CountItem($$$$)
{
    my ($item, $mnemo_Item, $code, $compteurs) = @_ ;
    my $status = 0;

    if (!defined $$code )
    {
        $status |= Couples::counter_add($compteurs, $mnemo_Item, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $nbr_Item = () = $$code =~ /${item}/sg;

#print STDERR "NB ITEM ${item} = $nbr_Item\n";

    $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);

    return $status;
}

sub CountItemKeyword($$$$)
{
    my ($item, $mnemo_Item, $code, $compteurs) = @_ ;
    my $status = 0;

    if (!defined $$code )
    {
        $status |= Couples::counter_add($compteurs, $mnemo_Item, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $nbr_Item = () = $$code =~ /(\A|[^\.\s])\s*\b${item}\b\s*[^\.]/sg;

#print STDERR "NB ITEM KEYWORD ${item} = $nbr_Item\n";

    $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);

    return $status;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des mots cles
#-------------------------------------------------------------------------------
sub CountKeywords($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $code = \$vue->{'code'};

    $status |= CountItem('\bArray\s*\(',                  Ident::Alias_BadArrayDeclaration(),                 $code, $compteurs);
    $status |= CountItem('[^\.]\bObject(?:.create)?\s*\(\s*(?:null)?\s*\)',                  Ident::Alias_BadObjectDeclaration(),                 $code, $compteurs);
    $status |= CountItem('\bObject\s*\(',                  Ident::Alias_ObjectDeclaration(),                 $code, $compteurs);
    $status |= CountItem('\bnew\s+(?:'.$IDENTIFIER.'\.)*[a-z](?:'.$IDENTIFIER.')*\b[^\.]',                  Ident::Alias_BadConstructorNames(),                 $code, $compteurs);
#    $status |= CountItem('\breturn\b\s*\n\s*[^;\s]',                  Ident::Alias_MultilineReturn(),                 $code, $compteurs);
    $status |= CountItem('\bnew\b\s*(?:Boolean|Number|String)\b',                  Ident::Alias_MissingScalarType(),                 $code, $compteurs);
    $status |= CountItem('\barguments\.callee\b',                  Ident::Alias_ArgumentCallee(),                 $code, $compteurs);
    $status |= CountItemKeyword('with',                  Ident::Alias_With(),                 $code, $compteurs);
#    $status |= CountItem('\bbreak\b',                  Ident::Alias_Break(),                 $code, $compteurs);
    $status |= CountItemKeyword('continue',                  Ident::Alias_Continue(),                 $code, $compteurs);
    $status |= CountItemKeyword('eval',                  Ident::Alias_Evaluate(),                 $code, $compteurs);
    $status |= CountItem('\bsetTimeout\(\s*CHAINE_\d+\s*,\s*\d+\s*\)',                  Ident::Alias_BadSetTimeout(),                 $code, $compteurs);
    $status |= CountItem('\bsetInterval\(\s*CHAINE_\d+\s*,\s*\d+\s*\)',                  Ident::Alias_BadSetInterval(),                 $code, $compteurs);
    $status |= CountItemKeyword('eval',                  Ident::Alias_Eval(),                 $code, $compteurs);
    $status |= CountItemKeyword('if',                  Ident::Alias_If(),                 $code, $compteurs);
    $status |= CountItemKeyword('else',                  Ident::Alias_Else(),                 $code, $compteurs);
    $status |= CountItemKeyword('case',                  Ident::Alias_Case(),                 $code, $compteurs);
    $status |= CountItemKeyword('return',                  Ident::Alias_Return(),                 $code, $compteurs);
    $status |= CountItem('\?',                  Ident::Alias_TernaryOperators(),                 $code, $compteurs);
    $status |= CountItem('\|\||&&',                  Ident::Alias_AndOr(),                 $code, $compteurs);
    $status |= CountItemKeyword('var',                  Ident::Alias_VariableDeclarations(),                 $code, $compteurs);


    return $status;
}


sub addHash($$) {
  my $hash = shift;
  my $item = shift;
  if (exists $hash->{$$item}) {
    $hash->{$$item}++;
  }
  else {
    $hash->{$$item} = 1;
  }
}


sub checkReuse($$;$) {
  my $item = shift;
  # list of differents derefs found.
  my $deref = shift;
  # list of deref in violation (number of violation for each)
  my $multiple = shift;
  
  my $reused = 0;

#print "DEREFERENCEMENT : $$item\n";
        if (exists $deref->{$$item}) {
	  # if $item is already used, add it as a multiple.
#print "     ---> $$item\n";
	  #addHash($multiple, $item);
          $nb_UnecessaryNestedObjectResolution++;
	  $reused = 1;
	}
	else {
	  for my $key (keys %{$deref}) {
#print "    PREVIOUS $key\n";
            my $Qkey = quotemeta $key;
            my $Qitem = quotemeta $$item;
	    # if one previous item begins with item
	    if ($key =~ /^$Qitem\b/) {
#print "     ---> $key (previous) begins with $$item\n";
	      # mark item as multiple
	      #addHash($multiple, $item);
              $nb_UnecessaryNestedObjectResolution++;
	      $reused = 1;
              last;
	    }
	    # if item begins with one previous item
	    elsif ($$item =~ /^$Qkey\b/) {
#print "     ---> $$item begins with $key (previous)\n";
	      # mark previous item as multiple
	      #addHash($multiple, \$key);
              $nb_UnecessaryNestedObjectResolution++;
	      $reused = 1;
              last;
	    }
          }
        }

	return $reused;
}

sub countExpression($) 
{
  my $buf = shift ;

  my $ret = 0;

      my %multiple = ();
      my %deref = ();

      while ( $$buf =~ /(($IDENTIFIER\.(?:$IDENTIFIER)?)\.?(?:$IDENTIFIER|\.)+)/mg) {
	      #while ( $buf =~ /([\w]+(\.|[\w]+)+)/mg) {
        my $item = $1;
	my $parent_item = $2;

	# my $reused = checkReuse(\$item, \%deref, \%multiple );
	my $reused = checkReuse(\$item, \%deref);

        if (! $reused) {
	  # if the item is not a reuse, check if the parent does ...
	  # my $reused = checkReuse(\$parent_item, \%deref, \%multiple );
	  checkReuse(\$parent_item, \%deref);
        }

        # memorizes item and parent item.
	$deref{$parent_item} = 1;
	$deref{$item} = 1;
      }
#      for my $item (keys %multiple) {
#        print "$item : " . $multiple{$item}."\n";
#      }

}

sub CountMultilineReturn($$$) {
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  my $MultilineReturn__mnemo = Ident::Alias_MultilineReturn();
  my $nb_MultilineReturn = 0;

  my $code =  \$vue->{'code'} ;

  if ( ! defined $code )
  {
    $ret |= Couples::counter_add($compteurs, $MultilineReturn__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  while ( $$code =~ /\breturn\b\s*\n\s*([^;}\s]\w*)/sg ) {
#print "Found potention multiline return with parameter $1\n";
    if ($1 !~ /^(?:beak|case|continue|default|do|while|for|if|else|return|switch|throw|try|catch|finally|var|with|debugger)$/) {
        $nb_MultilineReturn++;
#print "--> MULTILINE RETURN : <<$1>>\n";
    }
  }

  $ret |= Couples::counter_add($compteurs, $MultilineReturn__mnemo, $nb_MultilineReturn );

  return $ret;
}

sub countBadThis($) 
{
  my ($buf) = @_ ;

  my $ret = 0;

  if ( $$buf =~ /\bthis\s+instanceof\b/s) {
    return 0;
  }

  pos $$buf = 0;
  my $nb_goodThis = () = $$buf =~ /(?:\bjquery|\$)\s*\(\s*this\s*\)|\bvar\s+$IDENTIFIER\s*=\s*this\b/sg ;

  pos $$buf = 0;
  my $nb_This = () = $$buf =~ /\bthis\b/sg ;

  return $nb_This-$nb_goodThis;
}

sub CountArtifact($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_UnecessaryNestedObjectResolution = 0;
  $nb_UnexpectedThis = 0;

  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $UnecessaryNestedObjectResolution__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $This__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $artifactView = $vue->{'artifact'};

  my @funcs = GetNodesByKindList($root, [FunctionDeclarationKind, FunctionExpressionKind]);

  my @Artifacts = ();
  # Check if the name is 'root'. Indeed, some RootKind node are not named
  # "root" because they are virtual root node added for "unit" mode, to contain
  # the top-level functions that are the analysis unit.
  if (GetName($root) eq 'root') {
    push @Artifacts, 'root';
  }

  for my $func (@funcs) {
    my $name = GetName($func);
    my $line = GetLine($func);
    my $artiKey = buildArtifactKeyByData($name, $line);
    push @Artifacts, $artiKey;
  }

  for my $artiKey (@Artifacts) {
    my %multiple = ();
    my %deref = ();

    if (exists $artifactView->{$artiKey}) {
#print "--------------- $artiKey -------------------\n";
#print $artifactView->{$artiKey}."\n";
      my $buf = $artifactView->{$artiKey};

      $nb_UnexpectedThis += countBadThis(\$artifactView->{$artiKey});
      countExpression(\$artifactView->{$artiKey});
    }    
  }

  $ret |= Couples::counter_add($compteurs, $UnecessaryNestedObjectResolution__mnemo, $nb_UnecessaryNestedObjectResolution );
  $ret |= Couples::counter_add($compteurs, $This__mnemo, $nb_UnexpectedThis );

  return $ret;
}



sub checkMissingBreak($) {
  my $children = shift;

  if (scalar @{$children} > 0) {
     my $lastChild = $children->[-1];
     if ( (! IsKind($lastChild, BreakKind)) &&
          (! IsKind($lastChild, ReturnKind)) &&
          (! IsKind($lastChild, ContinueKind))
                ) {
	   #(! IsKind($lastChild, ThrowKind)) ) {
	
#print "--> violation\n";
            return 1;
    }
  }
  return 0;
}


sub CountSwitch($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_MissingBreakInCasePath = 0;

  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $MissingBreakInCasePath__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @switches = GetNodesByKind($root, SwitchKind);

  for my $switch (@switches) {
#print "SWITCH : ". ${GetStatement(Lib::NodeUtil::GetChildren($switch)->[0])}."\n";
    my @cases = GetNodesByKindList($switch, [CaseKind, DefaultKind], 1);

    my $lastCase = 0; # FLAG 1 for the last case of the switch.
    my $lastCaseWasEmpty = 0;
    my $lastCaseWasACase = 0;
    for my $case (@cases) {

     if (($lastCaseWasEmpty) && (!IsKind($case, CaseKind))) {
       # Count a violation for the previous case that was empty and not followed by another
       # case (i.e. followed by a Default) .
       $nb_MissingBreakInCasePath++;
#print "--> violation empty case\n";
     }

      my $children = Lib::NodeUtil::GetChildren($case);

      # if the number of children is 1 (or 0, but this would be an error)
      # then it is an empty case (no statement, just the case value expression).
      # In this case, don't count a violation.
      # UNLESS it's followed with "default" or "nothing".
      if (scalar @$children <=1) {
	if (IsKind($case, CaseKind)) { 
	  $lastCaseWasACase = 1;
        }
	else {
	  $lastCaseWasACase = 0;
	}
	$lastCaseWasEmpty = 1;
	next;
      }
      else {
        $lastCaseWasEmpty = 0;
        $lastCaseWasACase = 0;
      }

      if ($case == $cases[-1]) {
        $lastCase = 1;
      }

      # Check violations, unless it is the last case statement of the
      # switch and that is a default statement.
      #if ((! $lastCase) || (! IsKind($case, DefaultKind))) {
      if (! (($lastCase) && (IsKind($case, DefaultKind)) ) ) {  
	# Count a violation if the last statement of the case in not in the following :
        $nb_MissingBreakInCasePath += checkMissingBreak($children);	    
      }
    }

    if ($lastCaseWasEmpty && $lastCaseWasACase) {
      # Count a violation if the last statement was empty and was a case :
      $nb_MissingBreakInCasePath += 1;	    
#print "--> violation last empty case\n";
    }
  }

  $ret |= Couples::counter_add($compteurs, $MissingBreakInCasePath__mnemo, $nb_MissingBreakInCasePath );

  return $ret;
}

sub CountUnauthorizedPrototypeModification($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_UnauthorizedPrototypeModification = 0;

  my $code =  $vue->{'code'} ;

  if ( ! defined $code )
  {
    $ret |= Couples::counter_add($compteurs, $UnauthorizedPrototypeModification__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  $nb_UnauthorizedPrototypeModification += () = $code =~ /\b(?:Object|Array|Function)\.prototype(?:\.$IDENTIFIER|\[$IDENTIFIER\])?\s*=/g;

  $ret |= Couples::counter_add($compteurs, $UnauthorizedPrototypeModification__mnemo, $nb_UnauthorizedPrototypeModification );
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des Magic Number. 
#-------------------------------------------------------------------------------

sub CountMagicNumbers($) {
  my $magics = shift;
  my $status = 0;

  my $nbr_MagicNumbers = 0;

  for my $magic (keys %{$magics}) {
#print "MAGIC : $magic\n";
    if ( $magic !~ /^(?:0\.0|1\.0|0\.|1\.|\.0)$/) {
      # suppression du 0 si le nombre commence par 0.
      my $canon = $magic;
      $canon =~ s/^0*(.)/$1/;
      # Si la donnee trouvee n'est pas un simple chiffre, alors ce n'est pas un magic number tolere ...
      if ($canon !~ /^\d$/ ) {
         $nbr_MagicNumbers+=$magics->{$magic};
#print "--> ".$magics->{$magic}." violations for $magic\n";
      }
    }
  }

  return $nbr_MagicNumbers;

}


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
sub CountMissingInstructionSeparator($$$) {
  my ($fichier, $view, $compteurs) = @_ ;

  my $mnemo_MissingSemicolon = Ident::Alias_MissingSemicolon();
  my $missingSemicolon = $view->{'HMissingSemicolon'};

  my $mnemo_MissingBraces = Ident::Alias_MissingBraces();
  my $missingAcco = $view->{'HMissingAcco'};

  my $mnemo_MagicNumbers = Ident::Alias_MagicNumbers();
  my $magic = $view->{'HMagic'};

  my $root = $view->{'structured_code'};

  my $status = 0;

  if ( ( ! defined $missingSemicolon ) || ( ! defined $missingAcco ) || ( ! defined $root ) ){
    $status |= Couples::counter_add($compteurs, $mnemo_MissingSemicolon, Erreurs::COMPTEUR_ERREUR_VALUE);
    $status |= Couples::counter_add($compteurs, $mnemo_MissingBraces, Erreurs::COMPTEUR_ERREUR_VALUE);
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nbr_MissingSemicolon = 0;
  my $nbr_MissingBraces = 0;
  my $nbr_MagicNumbers = 0;

  my @funcs = ( @{$view->{'KindsLists'}->{'FunctionDeclaration'}},
                @{$view->{'KindsLists'}->{'FunctionExpression'}},
		$root
              );

  for my $func (@funcs) {
    my $name = GetName($func);

    # Do not proceed in case of a virtual root node, if we are in unit analysis
    # mode.
    # Virtual root node have been created to contain analysis units
    # extracted from the real root node. But they corresponds to nothing in
    # the code.
    if ( (! IsKind($func, RootKind)) || ($name ne 'virtualRoot') ) {
      my $line = GetLine($func);
      my $artiKey = buildArtifactKeyByData($name, $line);

      if (defined $missingSemicolon->{$artiKey}) {
        $nbr_MissingSemicolon += $missingSemicolon->{$artiKey};
#print STDERR "ADDING ".$missingSemicolon->{$artiKey}." missing semicolon\n";
      }
      if (defined $missingAcco->{$artiKey}) {
        $nbr_MissingBraces += $missingAcco->{$artiKey};
      }

      if (defined $magic->{$artiKey}) {
        $nbr_MagicNumbers += CountMagicNumbers($magic->{$artiKey});
      }
    }
  }

  $status |= Couples::counter_add($compteurs, $mnemo_MissingSemicolon, $nbr_MissingSemicolon);
  $status |= Couples::counter_add($compteurs, $mnemo_MissingBraces, $nbr_MissingBraces);
  $status |= Couples::counter_add($compteurs, $mnemo_MagicNumbers, $nbr_MagicNumbers);

  return $status;

}

sub CountBadSpacing($$$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;
  my $status = 0;

  my $nb_BadSpacing = 0;
  my $mnemo_BadSpacing = Ident::Alias_BadSpacing();

  # Default view.
  my $code = $vue->{'code'} ;

  if (!defined $code) {
    $status |= Couples::counter_add($compteurs, $mnemo_BadSpacing, Erreurs::COMPTEUR_ERREUR_VALUE);
    $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    return $status;
  }

  my $ComparisonOp = '===|==|!==|!=|>=|<=';
  my $AssignmentOp = '\+=|-=|\*=|/=|\%=|<<=|>>>=|>>=|&=|\^=|\|=|=';
  my $LogicalOp = '&&|\|\|';
  my $ArithOp = '\+|\-|\*|\/|\%|<<|>>>|>>|&|\^|\|';
  my $ComparisonOp1 = '>|<';
  my $TernaryOp = '\?|:';

  my $ops = $ComparisonOp.'|'.$AssignmentOp.'|'.$LogicalOp.'|'.$ArithOp.'|'.$ComparisonOp1.'|'.$TernaryOp;

  $nb_BadSpacing = CountBadSpacing::_countBadSpacing_1(\$code, \$ops);

  $status |= Couples::counter_add($compteurs, $mnemo_BadSpacing, $nb_BadSpacing);

  return $status;
}

sub CountBreakInLoop($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  my $nb_Break = 0;
  my $Break__mnemo = Ident::Alias_Break();

  my $code =  \$vue->{'code'} ;
  my $root = $vue->{'structured_code'};
  if ( ( ! defined $code ) || ( ! defined $root ))
  {
    $ret |= Couples::counter_add($compteurs, $Break__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @breaks = GetNodesByKind($root, BreakKind);

  if ($$code =~ /\bswitch\b/) {
    for my $break (@breaks) {
      my $parent = GetParent($break);
      if ((!IsKind($parent, CaseKind)) && (!IsKind($parent, DefaultKind))) {
        $nb_Break++;
#print "Break in loop !!!\n";
      }
    }
  }
  else {
    $nb_Break = scalar @breaks;
  }

  $ret |= Couples::counter_add($compteurs, $Break__mnemo, $nb_Break );

  return $ret;
}


1;
