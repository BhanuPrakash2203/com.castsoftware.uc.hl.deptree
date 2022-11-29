package PHP::CountPHP;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use PHP::PHPNode;

my $EmptyStatementBloc__mnemo = Ident::Alias_EmptyStatementBloc();
my $UpperCaseKeywords__mnemo = Ident::Alias_UpperCaseKeywords();
my $UnnecessaryConcat__mnemo = Ident::Alias_UnnecessaryConcat();
my $LonelyVariableInString__mnemo = Ident::Alias_LonelyVariableInString();
my $RequiredParamsBeforeOptional__mnemo = Ident::Alias_RequiredParamsBeforeOptional();
my $BadFileNames__mnemo = Ident::Alias_BadFileNames();
my $ToManyNestedLoop__mnemo = Ident::Alias_ToManyNestedLoop();

my $nb_EmptyStatementBloc = 0;
my $nb_UpperCaseKeywords = 0;
my $nb_UnnecessaryConcat = 0;
my $nb_LonelyVariableInString = 0;
my $nb_RequiredParamsBeforeOptional = 0;
my $nb_BadFileNames = 0;
my $nb_ToManyNestedLoop = 0;


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

    my $nbr_Item = () = $$code =~ /${item}/isg;

    $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);

    return $status;
}


sub CountKeywords($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;
    my $code = $vue->{'code'};

    $status |= CountItem('\$this\b\s*=',                     Ident::Alias_AssignmentToThis(),  \$code, $compteurs);
    $status |= CountItem('\bcatch\b',                     Ident::Alias_Catch(),  \$code, $compteurs);
    $status |= CountItem('\bif\b',                     Ident::Alias_If(),  \$code, $compteurs);
    $status |= CountItem('\belseif\b',                     Ident::Alias_Elsif(),  \$code, $compteurs);
    $status |= CountItem('\belse\b',                     Ident::Alias_Else(),  \$code, $compteurs);
    $status |= CountItem('\bphpinfo\b',                     Ident::Alias_phpinfo(),  \$code, $compteurs);
    $status |= CountItem('\binterface\b',                     Ident::Alias_InterfaceDefinitions(),  \$code, $compteurs);

    return $status;
}


# Difference with CodeSniffer :
#  1 - CodeSniffer ignore alternative syntaxes (colon bloc)
#  2 - CodeSniffer take catch bloc into account. But Highlight use a dedicated rule for empty catches.
sub CountEmptyStatementBloc($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_EmptyStatementBloc = 0;


  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $EmptyStatementBloc__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Empties = GetNodesByKind( $root, EmptyKind );

  for my $empty (@Empties) {
    my $parent = GetParent($empty);
    if ( IsKind($parent, CurlyBlocKind) || IsKind($parent, ColonBlocKind) ) {
      my $siblings = GetSubBloc($parent);
      my $Grandparent = GetParent($parent);
      if ( (scalar @{$siblings} == 1) &&
	 ( (IsKind($Grandparent, ThenKind)) ||
	   (IsKind($Grandparent, ElsifKind)) ||
	   (IsKind($Grandparent, ElseKind)) ||
	   (IsKind($Grandparent, WhileKind)) ||
	   (IsKind($Grandparent, ForKind)) ||
	   (IsKind($Grandparent, ForeachKind)) ||
	   (IsKind($Grandparent, DoKind)) ||
	   (IsKind($Grandparent, SwitchKind)) ||
	   (IsKind($Grandparent, CatchKind)) ||
	   (IsKind($Grandparent, TryKind)) )) {
#print "VIOLATION : empty statement bloc !!\n";
        $nb_EmptyStatementBloc++;
      }
    }
  }

  $ret |= Couples::counter_add($compteurs, $EmptyStatementBloc__mnemo, $nb_EmptyStatementBloc );

  return $ret;
}

sub CountUpperCaseKeywords($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_UpperCaseKeywords = 0;

  if ( ! defined $vue->{'code'} )
  {
    $ret |= Couples::counter_add($compteurs, $UpperCaseKeywords__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Keywords = $vue->{'code'} =~ /\b(if|else|elseif|foreach|for|do|switch|while|try|catch)\b/isg;

  for my $keyword (@Keywords) {
    if ( $keyword =~ /[A-Z]/ ) {
       $nb_UpperCaseKeywords++;
#print "UPPERCASE KEYWORD : $keyword\n";
    }
  }

  $ret |= Couples::counter_add($compteurs, $UpperCaseKeywords__mnemo, $nb_UpperCaseKeywords );

  return $ret;
}

sub CountUnnecessaryConcat($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_UnnecessaryConcat = 0;

  if ( ( ! defined $vue->{code}) || ( ! defined $vue->{HString} ) )
  {
    $ret |= Couples::counter_add($compteurs, $UnnecessaryConcat__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $HStrings = $vue->{HString};

  while ( $vue->{'code'} =~ /(CHAINE_\d+(?:\s*\.\s*CHAINE_\d+)+)/sg ) {
    my @tab = split /\s*\.\s*/, $1 ;
    my $previous = $HStrings->{$tab[0]};
    for (my $i=1; $i<scalar @tab; $i++) {
      my $str = $HStrings->{$tab[$i]};
      if ( (($previous !~ /\?["']/ ) || ($str !~ /["']>/)) &&
           (($previous !~ /<["']/ ) || ($str !~ /["']\?/)) ) {

        my ($previous_type_string) = $previous =~ /^(.)/ ;
        my ($str_type_string) = $str =~ /^(.)/;

        if ($previous_type_string eq $str_type_string) {
          $nb_UnnecessaryConcat++;
#print "UNNECESSARY CONCAT : $previous.$str\n";
        }
      }
      $previous = $str;
    }
  }

  $ret |= Couples::counter_add($compteurs, $UnnecessaryConcat__mnemo, $nb_UnnecessaryConcat );

  return $ret;
}

sub CountLonelyVariableInString($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_LonelyVariableInString = 0;

  if ( ( ! defined $vue->{code}) || ( ! defined $vue->{HString} ) )
  {
    $ret |= Couples::counter_add($compteurs, $LonelyVariableInString__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $HStrings = $vue->{HString};

  my $PATTERN1 = '\b(CHAINE_\d+)\s*\.\s*\$\w+\s*\.\s*(CHAINE_\d+)\b'; # "".$var.""
  my $PATTERN2 = '\b(CHAINE_\d+)\s*\.\s*\$\w+';  # "".$var
  my $PATTERN3 = '\$\w+\s*\.\s*(CHAINE_\d+)\b';  # $var.""
  my $PATTERN4 = '\b(CHAINE_\d+)\b';            # "$var" or "{$var}"

  while ( $vue->{'code'} =~ /$PATTERN1|$PATTERN2|$PATTERN3/sg ) {

    if (defined $1) {
      my $dollar1= $1;
      my $dollar2= $2;

      if ( ($HStrings->{$dollar1} =~ /\A["]["]\Z/) ||
           ($HStrings->{$dollar2} =~ /\A["]["]\Z/) ) {
#print "==> VIOLATION 1 : Lonely String : ".$HStrings->{$dollar1}." \$var ".$HStrings->{$dollar2}."\n";
        $nb_LonelyVariableInString++;
      }

    }
    elsif (defined $3) {
my $dollar3= $3;
      if ($HStrings->{$3} =~ /\A["]["]\Z/) {
#print "==> VIOLATION 2 : Lonely String : ".$HStrings->{$dollar3}."\n";
        $nb_LonelyVariableInString++;
      }
    }
    elsif (defined $4) {
my $dollar4= $4;
      if ($HStrings->{$4} =~ /\A["]["]\Z/) {
#print "==> VIOLATION 3 : Lonely String : ".$HStrings->{$dollar4}."\n";
        $nb_LonelyVariableInString++;
      }
    }

  }

  pos($vue->{'code'}) = 0;

  while ( $vue->{'code'} =~ /$PATTERN4/sg ) {
    if (defined $1) {
my $dollar1 = $1;
#print "PATTERN4 : ".$HStrings->{$1}."\n";
      if ($HStrings->{$1} =~ /\A["]\s*\{?\$\w+\}?\s*["]\Z/) {
#print "==> VIOLATION 4 : Lonely String : ".$HStrings->{$dollar1}."\n";
        $nb_LonelyVariableInString++;
      }
    }
  }
#print "NB LonelyVariableInString Violation : $nb_LonelyVariableInString\n";

  $ret |= Couples::counter_add($compteurs, $LonelyVariableInString__mnemo, $nb_LonelyVariableInString );

  return $ret;
}



sub CountRequiredParamsBeforeOptional($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_RequiredParamsBeforeOptional = 0;

  my $root =  $vue->{'structured_code'} ;

  if ( ! $root )
  {
    $ret |= Couples::counter_add($compteurs, $RequiredParamsBeforeOptional__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Methods = GetNodesByKind( $root, FunctionKind);

  for my $method (@Methods) {

    my ($params) = ${GetStatement($method)} =~ /\((.*)\)/s ;
    my @paramList = $params =~ /(\$\w+(?:\s*=)?)/sg ;

    my $nb_defaultValues = 0;
    for my $param (@paramList) {

      if ($param =~ /=/) {
        $nb_defaultValues++;
      }
      elsif ($nb_defaultValues != 0) {
#print "BAD ARGUMENT POSITION in ".${GetStatement($method)}."\n";
         $nb_RequiredParamsBeforeOptional ++;
	 last;
      }
    }
  }

  $ret |= Couples::counter_add($compteurs, $RequiredParamsBeforeOptional__mnemo, $nb_RequiredParamsBeforeOptional );

  return $ret;
}

sub CountBadFileNames($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_BadFileNames = 0;

  $file =~ s/.*[\\\/]// ;

  if ( $file !~ /^[A-Z]/ ) {
    $nb_BadFileNames++;
  }

  $ret |= Couples::counter_add($compteurs, $BadFileNames__mnemo, $nb_BadFileNames );

  return $ret;

}

sub CountToManyNestedLoop($$$) {
    my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

    my $ToManyNestedLoop__mnemo = Ident::Alias_ToManyNestedLoop();
    my $nb_ToManyNestedLoop=0;

    my $NomVueCode = 'structured_code' ; 
    my $root =  $vue->{$NomVueCode} ;

    if ( ! defined $root )
    {
      $ret |= Couples::counter_add($compteurs, $ToManyNestedLoop__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
      return $ret;
    }

    my @KindList = (ForKind, DoKind, WhileKind, ForeachKind);
    my @LoopTab = GetNodesByKindList($root, \@KindList, 1); # flag 1 signifies we want only the first loop encountered on each path ...

    for my $loop (@LoopTab) {
      my @NestedLoopTab = GetNodesByKindList($loop, \@KindList, 0); 
      $nb_ToManyNestedLoop += scalar @NestedLoopTab ;
    }

    $ret |= Couples::counter_add($compteurs, $ToManyNestedLoop__mnemo, $nb_ToManyNestedLoop );
}


sub CountMissingBreakInCasePath($$$) {
    my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

    my $MissingBreakInCasePath__mnemo = Ident::Alias_MissingBreakInCasePath();
    my $nb_MissingBreakInCasePath=0;
    my $nb_Case = 0;
    my $nb_Default = 0;

    my $NomVueCode = 'structured_code' ; 
    my $root =  $vue->{$NomVueCode} ;

    if ( ! defined $root )
    {
      $ret |= Couples::counter_add($compteurs, $MissingBreakInCasePath__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
      return $ret;
    }

    my @Switches = GetNodesByKind($root, SwitchKind);
    my $nb_Switch = scalar @Switches;

    for my $switch (@Switches) {
      # get the list of case/default:
      # PHP::PHPNode::GetChildren($switch)->[0] is the bloc node that contains the children of
      # the switch.
      my $r_cases = PHP::PHPNode::GetChildren(PHP::PHPNode::GetChildren($switch)->[0]);

      my $nb_total_cases = scalar @{$r_cases};

      my $nb_cases = 0;
      for my $case (@{$r_cases}) {
        $nb_cases++;

	# Update Nbr_Case & Nbr_Default counters ...
	if (IsKind($case, CaseKind)) {
          $nb_Case++;
	}
	else {
          $nb_Default++;
	}

        # get the list of instructions in the case:
        # PHP::PHPNode::GetChildren($case)->[0] is the bloc node that contains the children of
        # the case.
        my $caseContent = PHP::PHPNode::GetChildren(PHP::PHPNode::GetChildren($case)->[0]);

	# if there is at least one child node that is not an "empty" node ...
	if ((defined $caseContent) && (scalar @{$caseContent} > 0) && (! IsKind($caseContent->[0], EmptyKind))) {
	  # ... and if the last child node is not a break instruction ...
          if (! IsKind($caseContent->[-1], BreakKind)) {
	    # ... and if the it is not a default statement situated in the last place (last statement of the switch)...
	    if (( $nb_cases < $nb_total_cases) || (!IsKind($case, DefaultKind))) {
	      # ... then the break is missing.
              $nb_MissingBreakInCasePath++;
#print "MISSING BREAK !!!\n";
            }
	  }
	}
      }

    }


    $ret |= Couples::counter_add($compteurs, $MissingBreakInCasePath__mnemo, $nb_MissingBreakInCasePath );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_Switch(), $nb_Switch );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_Case(), $nb_Case );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_Default(), $nb_Default );
}

1;
