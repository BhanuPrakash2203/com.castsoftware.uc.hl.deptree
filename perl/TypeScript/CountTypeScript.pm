package TypeScript::CountTypeScript;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use TypeScript::TypeScriptNode;
use TypeScript::Identifiers;
use CountBadSpacing;

my $IDENTIFIER = TypeScript::Identifiers::getIdentifiersPattern();
my $IDENT_CHAR = TypeScript::Identifiers::getIdentifiersCharacters();
my $DEBUG = 0;

my $UnecessaryNestedObjectResolution__mnemo = Ident::Alias_UnecessaryNestedObjectResolution();
my $MissingBreakInCasePath__mnemo = Ident::Alias_MissingBreakInCasePath();
my $UnauthorizedPrototypeModification__mnemo = Ident::Alias_UnauthorizedPrototypeModification();
my $This__mnemo = Ident::Alias_UnexpectedThis();
my $SwitchNested__mnemo = Ident::Alias_SwitchNested();
my $BadIncDecUse__mnemo = Ident::Alias_BadIncDecUse();
my $SwitchDefaultMisplaced__mnemo = Ident::Alias_SwitchDefaultMisplaced();
my $ErrorWithoutThrow__mnemo = Ident::Alias_ErrorWithoutThrow();
my $BadCaseLogical_mnemo = Ident::Alias_BadCaseLogical();
my $SmallSwitchCase_mnemo = Ident::Alias_SmallSwitchCase();

my $nb_UnecessaryNestedObjectResolution = 0;
my $nb_MissingBreakInCasePath = 0;
my $nb_UnauthorizedPrototypeModification = 0;
my $nb_UnexpectedThis = 0;
my $nb_nested_switches = 0;
my $nb_BadIncDecUse = 0;
my $nb_SwitchDefaultMisplaced = 0;
my $nb_ErrorWithoutThrow = 0;
my $nb_BadCaseLogical = 0;
my $nb_SmallSwitchCase = 0;

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

#if ($mnemo_Item eq Ident::Alias_MissingScalarType()) {
#print "Applying pattern : $item\n";
#	pos $$code =0;
#   
#	while ($$code =~ /(${item})/sg) {
#	    print $1."\n";
#	}
#}

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
    $status |= CountItem('\bwith\b',                  Ident::Alias_With(),                 $code, $compteurs);
#    $status |= CountItem('\bbreak\b',                  Ident::Alias_Break(),                 $code, $compteurs);
    $status |= CountItem('\bcontinue\b',                  Ident::Alias_Continue(),                 $code, $compteurs);
    $status |= CountItem('\bsetTimeout\(\s*CHAINE_\d+\s*,\s*\d+\s*\)',                  Ident::Alias_BadSetTimeout(),                 $code, $compteurs);
    $status |= CountItem('\bsetInterval\(\s*CHAINE_\d+\s*,\s*\d+\s*\)',                  Ident::Alias_BadSetInterval(),                 $code, $compteurs);
    $status |= CountItem('\beval\b',                  Ident::Alias_Eval(),                 $code, $compteurs);
    $status |= CountItem('\bif\b',                  Ident::Alias_If(),                 $code, $compteurs);
    $status |= CountItem('\belse\b',                  Ident::Alias_Else(),                 $code, $compteurs);
    $status |= CountItem('\bcase\b',                  Ident::Alias_Case(),                 $code, $compteurs);
    $status |= CountItem('\breturn\b',                  Ident::Alias_Return(),                 $code, $compteurs);
    # $status |= CountItem('\?',                  Ident::Alias_TernaryOperators(),                 $code, $compteurs);
    $status |= CountItem('\|\||&&',                  Ident::Alias_AndOr(),                 $code, $compteurs);
    $status |= CountItem('\bvar\b',                  Ident::Alias_Var(),                 $code, $compteurs);
    $status |= CountItem('\bswitch\b',                  Ident::Alias_Switch(),                 $code, $compteurs);
    $status |= CountItem('\bthrow\b',                  Ident::Alias_Throw(),                 $code, $compteurs);
    $status |= CountItem('\blet\b',                  Ident::Alias_Let(),                 $code, $compteurs);
    $status |= CountItem('\bconst\b',                  Ident::Alias_Const(),                 $code, $compteurs);


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

  my @funcs = GetNodesByKindList($root, [FunctionDeclarationKind, FunctionExpressionKind, MethodKind]);

  my @Artifacts = ();
  # Check if the name is 'root'. Indeed, some RootKind node are not named
  # "root" because they are virtual root node added for "unit" mode, to contain
  # the top-level functions that are the analysis unit.
  if (GetName($root) eq 'root') {
    push @Artifacts, ['root', RootKind];
  }

  for my $func (@funcs) {
    my $name = GetName($func);
    my $line = GetLine($func);
    my $artiKey = buildArtifactKeyByData($name, $line);
    push @Artifacts, [$artiKey, GetKind($func)];
  }

  for my $artifact (@Artifacts) {
	my $artiKey = $artifact->[0];
    my %multiple = ();
    my %deref = ();

    if (exists $artifactView->{$artiKey}) {
#print "--------------- $artiKey -------------------\n";
#print $artifactView->{$artiKey}."\n";
      my $buf = $artifactView->{$artiKey};

      # check "this" usage if the artifact is not a method ...
      if ( $artifact->[1] ne MethodKind ) {
	    $nb_UnexpectedThis += countBadThis(\$artifactView->{$artiKey});
      }
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
    $nb_nested_switches = 0;
    $nb_SwitchDefaultMisplaced = 0;
    $nb_BadCaseLogical = 0;
    $nb_SmallSwitchCase = 0;

    my $root =  $vue->{'structured_code'} ;

    if ( ! defined $root )
    {
        $ret |= Couples::counter_add($compteurs, $MissingBreakInCasePath__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $SwitchNested__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $SwitchDefaultMisplaced__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $BadCaseLogical_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $SmallSwitchCase_mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
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
            
            # HL-849 18/04/2019 In switch "default" clauses should be last
            if ($lastCase != 1 && IsKind($case, DefaultKind))
            {
                $nb_SwitchDefaultMisplaced++;
                print "In switch \"default\" clause should be last at line ".GetLine($case)."\n" if $DEBUG;
                Erreurs::VIOLATION($SwitchDefaultMisplaced__mnemo, "In switch \"default\" clause should be last at line ".GetLine($case));
            }
        }

        if ($lastCaseWasEmpty && $lastCaseWasACase) {
            # Count a violation if the last statement was empty and was a case :
            $nb_MissingBreakInCasePath += 1;	    
            #print "--> violation last empty case\n";
        }
    
        # HL-839 12/04/2019 "switch" statements should not be nested
        my @nested_switches = GetNodesByKind($switch, SwitchKind, 1); # 1 : do not walk into subnodes

        if (defined scalar(@nested_switches) and scalar (@nested_switches) > 0)
        {
            for my $nested_switch (@nested_switches)
            {        
                $nb_nested_switches++;
                print "Switch statement should not be nested at line ".GetLine($nested_switch) ."\n" if $DEBUG;
                Erreurs::VIOLATION($SwitchNested__mnemo, "Switch statement should not be nested at line ".GetLine($nested_switch));
            }            
        }
        
        # HL-837 29/04/2019 "switch" statements should have at least 3 "case" clauses
        # HL-852 19/04/2019 Logical OR should not be used in switch cases
        my @casesExpression = GetNodesByKind($switch, CaseExprKind, 1); # 1 : do not walk into subnodes
        
        if (defined scalar(@casesExpression) and scalar(@casesExpression) < 3)
        {
            $nb_SmallSwitchCase++; 
            print "Switch statements should have at least 3 \"case\" clauses at line ".GetLine($switch) ."\n" if $DEBUG;
            Erreurs::VIOLATION($SmallSwitchCase_mnemo, "Switch statements should have at least 3 \"case\" clauses at line ".GetLine($switch));
        }
        
        for my $caseExpr (@casesExpression)
        {
            my $statement = ${GetStatement($caseExpr)};

            if ( $statement =~ /\|\|/ )
            {
                $nb_BadCaseLogical++;
                print "Logical OR should not be used in switch case at line ".GetLine($switch) ."\n" if $DEBUG;
                Erreurs::VIOLATION($BadCaseLogical_mnemo, "Logical OR should not be used in switch case at line ".GetLine($switch));
            }
        }
    }

    $ret |= Couples::counter_add($compteurs, $MissingBreakInCasePath__mnemo, $nb_MissingBreakInCasePath );
    $ret |= Couples::counter_add($compteurs, $SwitchNested__mnemo, $nb_nested_switches );
    $ret |= Couples::counter_add($compteurs, $SwitchDefaultMisplaced__mnemo, $nb_SwitchDefaultMisplaced );
    $ret |= Couples::counter_add($compteurs, $BadCaseLogical_mnemo, $nb_BadCaseLogical );
    $ret |= Couples::counter_add($compteurs, $SmallSwitchCase_mnemo, $nb_SmallSwitchCase );

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

sub cb_CountStatement($$) {
	my ($node, $context) = @_;

	my $stmt = Lib::NodeUtil::GetStatement($node);
	
	if (IsKind($node, FunctionCallKind)) {
		while ($$stmt =~ /(\+\+|\-\-)/g) {
			$nb_BadIncDecUse++;
			Erreurs::VIOLATION($BadIncDecUse__mnemo, "Operator $1 should not be used in a method call at line ".(GetLine($node)||"??"));
		}
	}
	else {
		my @tab_IndDec = $$stmt =~ /\+\+|\-\-/g;
		if (scalar @tab_IndDec) {
			my $statement = $$stmt;
			$statement =~ s/\+\+|\-\-/ /g;
			if ($statement =~ /[+\-*\/%]/) {
				for my $operatorIncrement (@tab_IndDec) {
					$nb_BadIncDecUse++;
					Erreurs::VIOLATION($BadIncDecUse__mnemo, "Operator $operatorIncrement should not be used in an expression at line ".(GetLine($node)||"??"));
				}
			}
		}
	}
	return undef;
}

sub CountStatement($$$)
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_BadIncDecUse = 0;

    my $root =  $vue->{'structured_code'} ;

	if ( ! defined $root )
	{
		$ret |= Couples::counter_add($compteurs, $BadIncDecUse__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
		return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
	}
    
	my @context = ();
	Lib::Node::Iterate($root, 0, \&cb_CountStatement, \@context);
    
    $ret |= Couples::counter_add($compteurs, $BadIncDecUse__mnemo, $nb_BadIncDecUse );

    return $ret;
}

# HL-850 19/04/2019 Errors should not be created without being thrown
sub CountError($$$)
{
    my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    my $nb_ErrorWithoutThrow = 0;

    my $code =  \$vue->{'code'} ;
    if ( ! defined $code )
    {
        $ret |= Couples::counter_add($compteurs, $ErrorWithoutThrow__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    } 
    
    my $numligne = 1;
    while ($$code =~ /(\n)|((?<!throw)\s+new\s+(?:Eval|Internal|Range|Reference|Syntax|Type|URI)?Error\b)|[^\n]/mg)
    {
        $numligne++ if (defined $1);
        if (defined $2)
        {
            print "Errors should not be created without being thrown at line $numligne\n" if $DEBUG;
            $nb_ErrorWithoutThrow++;
            Erreurs::VIOLATION($ErrorWithoutThrow__mnemo, "Errors should not be created without being thrown at line $numligne");
        }
    }
    
    $ret |= Couples::counter_add($compteurs, $ErrorWithoutThrow__mnemo, $nb_ErrorWithoutThrow );

    return $ret;
}

1;
