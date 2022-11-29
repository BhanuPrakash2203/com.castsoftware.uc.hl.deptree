

package Abap::CountAbap;
# Module du comptage TDB: Nombre de procedures internes non referencees.

use strict;
use warnings;

use Lib::Node qw(GetNextSibling);
use Abap::AbapNode;

use Erreurs;

use Ident;

my $IDENTIFIER = '\w';

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

    my $nbr_Item = () = $$code =~ /${item}(?:[^\-]|\Z)/isg;

    $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);

    return $status;
}


sub CountKeywords($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;
    my $code = $vue->{'code'};

    $status |= CountItem('\bon\s+change\s+of\b',                     Ident::Alias_OnChangeOf(),  \$code, $compteurs);
    $status |= CountItem('\bbreak\b|\bbreak-point\b',                Ident::Alias_BreakPoint(),  \$code, $compteurs);
    $status |= CountItem('\bselect\s*\*|\bselect\s+single\s*\*',      Ident::Alias_SelectAll(),  \$code, $compteurs);
    #?$status |= CountItem('\bread\s+table[^\.]*\bbinary\s+search\b',  Ident::Alias_WithoutBinarySearch_ReadTable(),  \$code, $compteurs);
    #$status |= CountItem('\bread\s+table\b',                         Ident::Alias_ReadTable(),  \$code, $compteurs);
    $status |= CountItem('\bINTO\s+CORRESPONDING\s+FIELDS\s+OF\b',   Ident::Alias_IntoCorrespondingFieldsOf(),  \$code, $compteurs);
    $status |= CountItem('\border\s+by\b',                            Ident::Alias_SQLOrderBy(),  \$code, $compteurs);
    $status |= CountItem('\bselect\b\s*(?:count\s*\(\s*)?distinct\b', Ident::Alias_SelectDistinct(),  \$code, $compteurs);
    $status |= CountItem('\bEXEC\s+SQL\b',                           Ident::Alias_NativeSQL(),  \$code, $compteurs);
    $status |= CountItem('\bLOOP\b[^\.]+\bINTO\b',                   Ident::Alias_LoopInto(),  \$code, $compteurs);
    $status |= CountItem('\bSYSTEM-CALL\b',                   	     Ident::Alias_SystemCall(),  \$code, $compteurs);
    $status |= CountItem('\bme\s*->',                                Ident::Alias_RefToMe(),  \$code, $compteurs);
    #$status |= CountItem('\binclude\b',                   	     Ident::Alias_Include(),  \$code, $compteurs);
    $status |= CountItem('\bexit\b',                   	             Ident::Alias_Exit(),  \$code, $compteurs);
    $status |= CountItem('\bendselect\b',                   	     Ident::Alias_EndSelect(),  \$code, $compteurs);
    $status |= CountItem('\bup\s+to\s+(?:1|one)\s+rows\b',            Ident::Alias_UpTo1Row(),  \$code, $compteurs);
    $status |= CountItem('\A\s*(?:report|program)\b[^\.]*\.\s*$',    Ident::Alias_EmptyProgram(), \$code, $compteurs);
    $status |= CountItem('\A\s*(?:include_name\b)\s*[^\.\s]*\s*\.\s*\Z',       Ident::Alias_EmptyInclude(), \$code, $compteurs);
    $status |= CountItem('\(\s*select\b',                            Ident::Alias_SubQueries(), \$code, $compteurs);
    $status |= CountItem('\bendif\b',                   	     Ident::Alias_If(),  \$code, $compteurs);
    $status |= CountItem('\benddo\b',                   	     Ident::Alias_Do(),  \$code, $compteurs);
    $status |= CountItem('\bendwhile\b',                   	     Ident::Alias_While(),  \$code, $compteurs);
    $status |= CountItem('\bendloop\b',                   	     Ident::Alias_Loop(),  \$code, $compteurs);
    $status |= CountItem('\bendprovide\b',                   	     Ident::Alias_Provide(),  \$code, $compteurs);
    $status |= CountItem('(?:\A|\.)\s*modify\b',                     Ident::Alias_Sql_Modify(),  \$code, $compteurs);
    $status |= CountItem('(?:\A|\.)\s*insert\b',                     Ident::Alias_Sql_Insert(),  \$code, $compteurs);
    $status |= CountItem('(?:\A|\.)\s*update\b',                     Ident::Alias_Sql_Update(),  \$code, $compteurs);
    $status |= CountItem('(?:\A|\.)\s*delete\b',                     Ident::Alias_Sql_Delete(),  \$code, $compteurs);
    $status |= CountItem('(?:\A|\.)\s*authority-check\b',            Ident::Alias_AuthorityCheck(),  \$code, $compteurs);
    $status |= CountItem('(?:\A|\.)\s*read\b',                       Ident::Alias_Read(),  \$code, $compteurs);
    $status |= CountItem('(?:\A|\.)\s*open\s+dataset\b',             Ident::Alias_OpenDataset(),  \$code, $compteurs);
    $status |= CountItem('(?:\A|\.)\s*fetch\s+next\s+cursor\b',    Ident::Alias_FetchNextCursor(),  \$code, $compteurs);

    return $status;
}

sub CountReadTable($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $nb_ReadTable = 0;
#  my $nb_WithoutBinarySearch_ReadTable = 0;
  my $ret = 0;

  my $code = \$vue->{'code'};

  while ( $$code =~ /(\bread\s+table[^\.]*)/isg ) {
    $nb_ReadTable++;
    #if ($1 !~ /\bbinary\s+search\b/is ) {
    #  $nb_WithoutBinarySearch_ReadTable++;
    #}
  }
  
  $ret |= Couples::counter_add($compteurs, Ident::Alias_ReadTable(), $nb_ReadTable );
  #$ret |= Couples::counter_add($compteurs, Ident::Alias_WithoutBinarySearch_ReadTable(), $nb_WithoutBinarySearch_ReadTable );
  return $ret;
}

sub CountInclude ($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $nb_Include = 0;
  my $ret = 0;

  my $code = \$vue->{'code'};

  while ( $$code =~ /\binclude\b\s*(from|into)?\b/sig ) {
    if (!defined $1) {
      $nb_Include++;
    }
  }
  $ret |= Couples::counter_add($compteurs, Ident::Alias_Include(), $nb_Include );
  return $ret;
}

sub CountCodeCheckDisabling($$$) {
    my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

    my $code = \$vue->{'code'};
    my $comment = \$vue->{'comment'};

    my $nb_CodeCheckDisabling = 0;

    $nb_CodeCheckDisabling += () = $$code =~ /(\bSET\s+EXTENDED\s+CHECK\s+OFF\b)/ig ;
    $nb_CodeCheckDisabling += () = $$comment =~ /(#EC\b)/ig ;

    $ret |= Couples::counter_add($compteurs, Ident::Alias_CodeCheckDisabling(), $nb_CodeCheckDisabling );

    return $ret;
}

sub CountBadProgramNames($$$) {
    my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

    my $BadProgramNames__mnemo = Ident::Alias_BadProgramNames();
    my $BadIncludeNames__mnemo = Ident::Alias_BadIncludeNames();

    my $nb_BadProgramNames=0;
    my $nb_BadIncludeNames=0;

    my $code = \$vue->{'code'};

    while ( $$code =~ /(?:\A|\.)\s*\b(?:(include)|(program))\s+((?:$IDENTIFIER)+)/sig ) {
      my $nb;
      if (defined $1) {
        $nb=\$nb_BadIncludeNames;
      }
      else {
        $nb=\$nb_BadProgramNames;
      }

      if (defined $3) {
        if ( $3 !~ /\A(?:Y|Z|LY|LZ|SAPLY|SAPLZ)/) {
          $$nb++;
	}
      }
      else {
        print "ERROR : missing program or include name ...\n";
      }
    }

    $ret |= Couples::counter_add($compteurs, $BadProgramNames__mnemo, $nb_BadProgramNames );
    $ret |= Couples::counter_add($compteurs, $BadIncludeNames__mnemo, $nb_BadIncludeNames );
}

sub CountMissingDefaults($$$) {
    my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

    my $MissingDefaults__mnemo = Ident::Alias_MissingDefaults();
    my $nb_MissingDefaults=0;
    my $Case__mnemo = Ident::Alias_Switch();
    my $nb_Case=0;

    my $NomVueCode = 'structured_code' ; 
    my $root =  $vue->{$NomVueCode} ;

    if ( ! defined $root )
    {
      $ret |= Couples::counter_add($compteurs, $MissingDefaults__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
      $ret |= Couples::counter_add($compteurs, $Case__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
      return $ret;
    }

    my @Cases = GetNodesByKind( $root, CaseKind);

    $nb_Case = scalar @Cases;

    for my $case (@Cases) {
     # my @WhenOthers = GetNodesByKind( $case, WhenOtherKind);
      if (scalar GetChildrenByKind($case, WhenOtherKind) == 0 ) {
        $nb_MissingDefaults++;
      }
    }

    $ret |= Couples::counter_add($compteurs, $MissingDefaults__mnemo, $nb_MissingDefaults );
    $ret |= Couples::counter_add($compteurs, $Case__mnemo, $nb_Case );
} 

sub CountEmptyCatches($$$) {
    my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

    my $EmptyCatches__mnemo = Ident::Alias_EmptyCatches();
    my $nb_EmptyCatches=0;
    my $Catch__mnemo = Ident::Alias_Catch();
    my $nb_Catch=0;

    my $NomVueCode = 'structured_code' ; 
    my $root =  $vue->{$NomVueCode} ;

    if ( ! defined $root )
    {
      $ret |= Couples::counter_add($compteurs, $EmptyCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
      $ret |= Couples::counter_add($compteurs, $Catch__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
      return $ret;
    }

    my @Catch = GetNodesByKind( $root, CatchKind);
    $nb_Catch = scalar @Catch;

    for my $catch (@Catch) {
      if ( scalar @{ Abap::AbapNode::GetChildren($catch)} == 0 ) {
        $nb_EmptyCatches++;
      }
    }

    $ret |= Couples::counter_add($compteurs, $EmptyCatches__mnemo, $nb_EmptyCatches );
    $ret |= Couples::counter_add($compteurs, $Catch__mnemo, $nb_Catch );
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

    my @KindList = (LoopKind, DoKind, WhileKind, ProvideKind);
    my @LoopTab = GetNodesByKindList($root, \@KindList, 1); # flag 1 signifies we want only the first loop encountered on each path ...

    for my $loop (@LoopTab) {
      my @NestedLoopTab = GetNodesByKindList($loop, \@KindList, 0); # flag 1 signifies we want all loop nodes.
      $nb_ToManyNestedLoop += scalar @NestedLoopTab ;
    }

    $ret |= Couples::counter_add($compteurs, $ToManyNestedLoop__mnemo, $nb_ToManyNestedLoop );
}

sub _countUncheckedReturn($);

sub _countUncheckedReturn($) {
  my $node = shift;

#print "NODE : ".$node->[0]."\n";

  if (
	  IsKind($node, OpenDatasetKind) ||
	  IsKind($node, ReadKind) ||
	  IsKind($node, FetchNextCursorKind) ||
	  IsKind($node, AuthorityCheckKind) ||
	  IsKind($node, SelectKind) ||
	  IsKind($node, EndSelectKind) ||
	  #IsKind($node, InsertKind) ||
	  #IsKind($node, DeleteKind) ||
	  IsKind($node, UpdateKind)
	  #IsKind($node, ModifyKind) 
     ) {
    # Do not check "SELECT COUNT"
    if ( ${GetStatement($node)} !~ /\bCOUNT\b/is ) {
#print "TO CHECK : ".GetKind($node)."\n";
      return (1, 0, GetKind($node)); # Check is expected
    }
  }

  if ( IsKind($node, OpenCursorKind) ) {
    # do not walk into open Cursor !!
#print "DON'T CHECK : OPEN CURSOR\n";
    return (0,0);
  }

  my $children = Abap::AbapNode::GetChildren($node);

  my $needCheck = 0;    # indicate if a child should be checked.
  my $nb_unchecked = 0; # count unchecked childs differents from select.
  my $unchecked = 0;    # temprorary flag
  my $nb_unchecked_select = 0; # count unchecked select instructions.
  my $nb_checked_endselect = 0; # count checked endselect instructions.
  my $previous_kind = undef;

  # final unchecked will be : $nb_unchecked + ($nb_unchecked_select - $nb_checked_endselect).
  for my $child (@{$children}) {

    $unchecked = 0 ; # by default ...

    # test if previous instruction has generated a SY-SUBRC that should be checked ...
    if ( $needCheck ) {
      if ( IsKind( $child, IfKind) || IsKind( $child, CaseKind) || IsKind($child, CheckKind)) {
        if (${GetStatement($child)} !~ /\bSY-SUBRC\b/is ) {
          # Followed by a if, but SUBRC not checked ...
	  $unchecked = 1;
        }
      }
      else {
        # Not followed by a if, so SUBRC not checked ...
        $unchecked = 1;
      }

      # treatment if previous instruction is unchecked
      if ( $unchecked) {

        # NOTE : unchecked EndSelect are not counted because they are allready counted with the select.
        if ($previous_kind ne EndSelectKind)  {
     	  if ( (defined $previous_kind) && ($previous_kind eq SelectKind) ) {
            $nb_unchecked_select += 1;
#print "--> UNCHECKED_SELECT +1 = $nb_unchecked_select\n";
	  }
	  else {
	    $nb_unchecked++;
#print "--> UNCHECKED_ANY +1 = $nb_unchecked\n";
          }
        }
      }
      # treatment if previous instruction is checked ...
      else {
	if ( (defined $previous_kind) && ($previous_kind eq EndSelectKind) ) {
	  $nb_checked_endselect++;
#print "++> CHECKED_ENDSELECT +1 = $nb_checked_endselect\n";
	}
      }

      # Reset to false for following instruction ...
      $needCheck = 0;
    }

    # Informations inherited from recursive analyse of child node...
    # -> if node contains subnodes, retrieves the number of violations in subnodes ...
    my ( $_needCheck, $_nb_unchecked ) = (0,0);

    # Case of a IF ...
    if ( IsKind( $child, IfKind)) {
#print "** ENTER IF \n";
      my $IfBranches = Abap::AbapNode::GetChildren($child);

      for my $branch ( @{$IfBranches}) {
#print "     IF_BRANCH (".$branch->[0].")\n";
        my ($need, $nb) = _countUncheckedReturn($branch);
	if ($need) {
          $_needCheck = $need;
	}
	# if (($nb > 0) && ($need != 0)) {
	  # The last instruction of a IF are authorised to have a have of SY-SUBRC
	  # after the IF. If such an instruction needs to be checked ($need != 0),
	  #  it should not be counted here, but after the IF, if none check of
	  #  SY-SUBRC is present. So, the number of "unchecked" instruction of
	  #  the branch of the IF should be decremented.
#print "nb ($nb) > 0, so decrementing ...\n";
	  #  $nb--;
	  #}
        $_nb_unchecked += $nb;
#print " BRANCH ===>  need = $need, unchecked = $_nb_unchecked\n";
      }
#print " result IF : ($_needCheck, $_nb_unchecked)\n";
    }
    # Generic case...
    else {
      ( $_needCheck, $_nb_unchecked ) = _countUncheckedReturn($child);
    }

    $needCheck = $_needCheck;
#print "           nb_unchecked => adding unchecked ($_nb_unchecked) of child (".$child->[0].")\n";
    $nb_unchecked += $_nb_unchecked ;
    $previous_kind = GetKind($child);
  }

  # if there is more checked EndSelect than unchecked select (i.e. the following condition is false),
  # it is probably an error, but we ignore it...
  if ( $nb_unchecked_select > $nb_checked_endselect ) {
#print "           * nb_unchecked => $nb_unchecked\n";
#print "           * nb_unchecked_select => $nb_unchecked_select\n";
#print "           * nb_checked_endselect => $nb_checked_endselect\n";
    $nb_unchecked += $nb_unchecked_select - $nb_checked_endselect;
  }
  
  # If the last instruction is a EndSelect, decrement the unchecked. Indeed, if
  # there is an endselect, there is a corresponding select that has already been 
  # taggued in "unchecked endselect". There will be only one violation if the
  # endselect is not checked in the suite.
  if ($needCheck && ($previous_kind eq EndSelectKind)) {
    $nb_unchecked--;
  }
  # If the last instruction is to be checked, inc the number of unchecked children of the node !
  # In case of a "Endselect", do not, because :
  # - if the corresponding select has been checked -> no need to count the endselect
  # - if the corresponding select has not been checked -> no need, because the violation has allready been recorded related to the select.
  #if ($needCheck && ($previous_kind ne EndSelectKind )) {
  #  $nb_unchecked++;
  #  $needCheck = 0;
  #}
  if ($needCheck && (!IsKind($node, ThenKind)) && (!IsKind($node, ElseKind)) && (!IsKind($node, ElsifKind)) ) {
    $nb_unchecked++;
    $needCheck = 0;
  }
#print "           _countUncheckedReturn(".GetKind($node).") => ($needCheck, $nb_unchecked)\n";
  return ($needCheck, $nb_unchecked);
}


sub CountUncheckedReturn($$$) {
    my ($fichier, $vue, $compteurs) = @_ ;
    my $ret = 0;

    my $UncheckedReturn__mnemo = Ident::Alias_UncheckedReturn();
    my $nb_UncheckedReturn=0;

    my $NomVueCode = 'structured_code' ; 
    my $root =  $vue->{$NomVueCode} ;

    if ( ! defined $root )
    {
      $ret |= Couples::counter_add($compteurs, $UncheckedReturn__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
      return $ret;
    }

    (undef, $nb_UncheckedReturn) = _countUncheckedReturn($root);
#print "CHECK SY-SUBRC MISSING = $nb_UncheckedReturn\n";
    $ret |= Couples::counter_add($compteurs, $UncheckedReturn__mnemo, $nb_UncheckedReturn );
}

sub CountTestUnameAgainstSpecificValue($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $ret = 0;

  my $TestUnameAgainstSpecificValue__mnemo = Ident::Alias_TestUnameAgainstSpecificValue();
  my $nb_TestUnameAgainstSpecificValue=0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $TestUnameAgainstSpecificValue__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret;
  }
 
  my @KindList = (IfKind, ElsifKind);
  my @Ifs = GetNodesByKindList($root, \@KindList); 

  for my $if (@Ifs) {
  if ( ${GetStatement($if)} =~ /\bsy-uname\s*(=|<>|EQ|NE|CO|CN|CA|NA|CS|NS|CP|NP)\s*CHAINE_\d+\b/si ) {
      $nb_TestUnameAgainstSpecificValue++;
    }
  }

  my @Cases = GetNodesByKind($root, CaseKind);

  for my $case (@Cases) {
    if ( ${GetStatement($case)} =~ /\bsy-uname\b/is ) {
      my @Whens = GetNodesByKind($root, WhenKind);
      for my $when (@Whens) {
        if ( ${GetStatement($when)} =~ /\bCHAINE_\d+\b/si ) {
          $nb_TestUnameAgainstSpecificValue++;
        }
      }
    }
  }

  $ret |= Couples::counter_add($compteurs, $TestUnameAgainstSpecificValue__mnemo, $nb_TestUnameAgainstSpecificValue );
 }


sub _cb_HardCodedValues($$) {
  my ($node, $context) = @_;
  my $ref_nb = $context->[0];
  #my $kind = GetKind($node);
  if ( ! IsKind($node,IfKind) ) {
#print "Searching in : ".${GetStatement($node)}."\n";
    if ( (${GetStatement($node)} =~ /[^=]=\s*CHAINE_\d+\b/is) ) {
      $$ref_nb++;
#print "===> FOUND violation : = ($$ref_nb) !!\n";
    }
    elsif (${GetStatement($node)} =~ /\A\s*move\b/is) {
      $$ref_nb += () = ${GetStatement($node)} =~ /\bCHAINE_\d+\b/isg;
#print "===> FOUND violation : move ($$ref_nb) !!\n";
    }
    elsif (${GetStatement($node)} =~ /\A\s*concatenate\b/is) {
      $$ref_nb += () = ${GetStatement($node)} =~ /\bCHAINE_\d+\b/isg;
#print "===> FOUND violation : concatenate ($$ref_nb) !!\n";
    }
    #elsif (${GetStatement($node)} =~ /\A\s*concatenate\s.*?\bCHAINE_\d+\b.*?\binto\b/is) ) {
    #  $$ref_nb++;
    #}
    elsif (${GetStatement($node)} =~ /\A\s*replace\b/is) {
      $$ref_nb += () = ${GetStatement($node)} =~ /\bCHAINE_\d+\b/isg;
#print "===> FOUND violation : replace ($$ref_nb) !!\n";
    }
    elsif (${GetStatement($node)} =~ /\A\s*(data|constants)\b/is) {
      $$ref_nb += () = ${GetStatement($node)} =~ /\bvalue\b\s*CHAINE_\d+\b/isg;
#print "===> FOUND violation : data ($$ref_nb) !!\n";
    }
  }
  return undef;
}

sub CountHardCodedValues($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $ret = 0;

  my $HardCodedValues__mnemo = Ident::Alias_HardCodedValues();
  my $nb_HardCodedValues=0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $HardCodedValues__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret;
  }

  my @context=(\$nb_HardCodedValues);
  Lib::Node::Iterate ($root, 0, \&_cb_HardCodedValues, \@context);

  $ret |= Couples::counter_add($compteurs, $HardCodedValues__mnemo, $nb_HardCodedValues );
 }

sub CountHardCodedPaths($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $ret = 0;

  my $HardCodedPaths__mnemo = Ident::Alias_HardCodedPaths();
  my $nb_HardCodedPaths=0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $vue->{'HString'} )
  {
    $ret |= Couples::counter_add($compteurs, $HardCodedPaths__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret;
  }

  for my $string (keys %{$vue->{'HString'}->{'strings_values'}}) {
    # String contain the generic string ID.
    # Get the original string :
    my $r_chain = \$vue->{'HString'}->{'strings_values'}->{$string};

    # Check the original string :
    if ( $$r_chain =~ /^'\s*(?:(?:(?:[a-z]:|\\\\\w+)[\\\/])|\/)(?:[\.\w[-_.^\{}@()\[\$#%'~ \]\/])*'$/i ) {
#print "HardCodedPath : FOUND : $$r_chain\n";
      # Add number of occurences :
      $nb_HardCodedPaths += $vue->{'HString'}->{'strings_counts'}->{$$r_chain}->[1] ;
    }
  }

  $ret |= Couples::counter_add($compteurs, $HardCodedPaths__mnemo, $nb_HardCodedPaths );
 }

sub CountAtInLoopAtWhere($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $ret = 0;

  my $AtInLoopAtWhere__mnemo = Ident::Alias_AtInLoopAtWhere();
  my $nb_AtInLoopAtWhere=0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $AtInLoopAtWhere__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret;
  }

   my @Loops = GetNodesByKind( $root, LoopKind);

    for my $loop (@Loops) {
      if ( ${GetStatement($loop)} =~ /\bwhere\b/i ) {
        my @Ats = GetNodesByKind( $loop, AtKind);
        if (scalar @Ats > 0) {
          $nb_AtInLoopAtWhere ++;
	}
      }
    }

  $ret |= Couples::counter_add($compteurs, $AtInLoopAtWhere__mnemo, $nb_AtInLoopAtWhere );
 }

sub CountExitInInclude($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  my $ret = 0;
  my $ExitInInclude__mnemo = Ident::Alias_ExitInInclude();
  my $nb_ExitInInclude=0;

  my $code =\$vue->{'code'};
  if ($$code =~ /\A\s*(?:include_name\b)\s*[^\.\s]*\s*\./si ) {

    my $root =  $vue->{'structured_code'} ;

    if ( ! defined $root )
    {
       $ret |= Couples::counter_add($compteurs, $ExitInInclude__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
       return $ret;
    }

    my @KindList = (ExitKind);
    my @BlockingKindList = (DoKind, WhileKind, LoopKind, SelectKind);
    my @Exits = GetNodesByKindList_StopAtBlockingNode($root, \@KindList, \@BlockingKindList, 0 ); # 0 signify analyze child of searched kind node.

    for my $exit ( @Exits ) {
      # EXIT FROM STEP LOOP in a <form>is not concerned because it indicates just ending
      #  processing the EXEC SQL content in case of a EXEC SQL PERFORMING <form> ...
      if ( ${GetStatement($exit)} !~ /\bexit\s+from\s+sql\b/si ) {
        $nb_ExitInInclude++;
      }
    }
  }

  $ret |= Couples::counter_add($compteurs, $ExitInInclude__mnemo, $nb_ExitInInclude );
  return $ret;
}


#sub CountVG($$$$)
#{
#    my $status;
#    my $nb_VG = 0;
#    my $VG__mnemo = Ident::Alias_VG();
#    my ($fichier, $vue, $compteurs, $options) = @_;
#
#    if (  ( ! defined $compteurs->{Ident::Alias_If()}) ||
#	  ( ! defined $compteurs->{Ident::Alias_While()}) || 
#	  ( ! defined $compteurs->{Ident::Alias_Try()}) || 
#	  ( ! defined $compteurs->{Ident::Alias_Catch()}) || 
#	  ( ! defined $compteurs->{Ident::Alias_ProcedureImplementations()}) ||
#	  ( ! defined $compteurs->{Ident::Alias_FunctionImplementations()}) ||
#	  ( ! defined $compteurs->{Ident::Alias_TriggerImplementations()}) )
#    {
#      $nb_VG = Erreurs::COMPTEUR_ERREUR_VALUE;
#    }
#    else {
#      $nb_VG = $compteurs->{Ident::Alias_If()} +
#	       $compteurs->{Ident::Alias_While()} +
#	       $compteurs->{Ident::Alias_Try()} +
#	       $compteurs->{Ident::Alias_Catch()} +
#	       $compteurs->{Ident::Alias_ProcedureImplementations()} +
#	       $compteurs->{Ident::Alias_FunctionImplementations()} +
#	       $compteurs->{Ident::Alias_TriggerImplementations()};
#    }
#
#    $status |= Couples::counter_add($compteurs, $VG__mnemo, $nb_VG);
#}



1;



