

package PHP::CountComments;

use strict;
use warnings;

use Lib::Node;
use PHP::PHPNode;

use Erreurs;
use CountUtil;
use Ident;

use PHP::PHPConfig;

my $MissingEndComment__mnemo = Ident::Alias_MissingEndComment();
my $EmptyCatches__mnemo = Ident::Alias_EmptyCatches();
my $MissingThrowsTags__mnemo = Ident::Alias_MissingThrowsTags();
my $UnusedThrowsTags__mnemo = Ident::Alias_UnusedThrowsTags();
my $LowCommentedRoutines__mnemo = Ident::Alias_LowCommentedRoutines();
my $UnCommentedRoutines__mnemo = Ident::Alias_UnCommentedRoutines();
my $UnCommentedClasses__mnemo = Ident::Alias_UnCommentedClasses();
my $LowCommentedRootCode__mnemo = Ident::Alias_LowCommentedRootCode();
my $ComplexRootCode__mnemo = Ident::Alias_ComplexRootCode();

my $nb_MissingEndComment = 0;
my $nb_EmptyCatches = 0;
my $nb_MissingThrowsTags = 0;
my $nb_UnusedThrowsTags = 0;
my $nb_LowCommentedRoutines = 0;
my $nb_UnCommentedRoutines = 0;
my $nb_UnCommentedClasses = 0;
my $nb_LowCommentedRootCode = 0;
my $nb_ComplexRootCode = 0;

my $COMMENT_RATIO = 10; # value for AIP is 5

#------------------------------------------------------------------------------
#                                    SPEC 
#------------------------------------------------------------------------------
# A/ Nbr_UnCommentedRoutines:
#------------------------------------------------------------------------------
#
# An artifact (function/routine) is considered commented if it is preceded by an
# documental comment (introduced by /**) that contain at least one tag (i.e. one @)
#
#------------------------------------------------------------------------------
# B/ Nbr_MissingThrowsTags
#    Nbr_UnusedThrowsTags
#------------------------------------------------------------------------------
# CHECHKING @Throw DIAGS 
#
# There are 2 diags :
# ------------------
#
# 1) Nbr_MissingThrowsTags
#
#     Count the number of tag missing in the documental comment
#     (introduced by /**). A tag is missing if there is at least one throw
#     instruction on it in the function body and no corresponding @throws tag.
# 
# 2) Nbr_UnusedThrowTags
#     
#     Count the number of throws tags presents in the documental comment of the
#     function, that are never thrown in the function body.
#
# Correspondence between @throws tags and throw instructions.
# -----------------------------------------------------------
#
# A/ the matching is based on the type of the exception.
#
#       Documental comment      <=>        function body
#    @throw <type> <comment>    <=>     throw new <type>(...);
#
# B/ When the type of the exception can not been determined,
#
#      exemple:      throw $e;
#
#    their number is computed (nb_UnknowEx) and the diags results are updated
#    like this :
#
#    a) if [(Nbr_UnusedThrowTags =0) && (nb_UnknowEx > 0)] 
#
#         then count AT LEAST ONE additional missing tag :
#              ==>  Nbr_MissingThrowsTags++
#
#    b) if ( Nbr_UnusedThrowTags > nb_UnknowEx ) 
#
#         then count AT LEAST (Nbr_UnusedThrowTags-nb_UnknowEx) unused tags.
#              ==> Nbr_UnusedThrowTags += Nbr_UnusedThrowTags-nb_UnknowEx;



my @DATA_ARTIFACT = ();
my @DATA_CLASSES = ();

# 1 - Fill a list of throw documented exception
# 2 - Check if the $buffer parameter is a documental comment. 
sub ptr_checkDocumentalComment() {
  my $buffer = shift;
  my $params = shift;
  my $documental = 0;
  my $documental_tag_found = 0;

  my $r_H_Throws = $params->[0];
  my $r_nb_viol = $params->[1];

  while ( $$buffer =~ /\@throws\s+((?:\w|\.|::)*)|((?:\A|[^\/])\/\*\*)|(\@)/sig ) {
    if (defined $2) {
      $documental = 1;
    }
    elsif ($documental) {
      if (defined $1) {
        $r_H_Throws->{$1}=1;
      }
      $documental_tag_found = 1;
    }
  }

  if ( ! $documental_tag_found ) {
#print "==> Found an UnCommented comment !!!!\n";
    if (defined $params->[1]) {
      $$r_nb_viol++;
    }
    else {
      $nb_UnCommentedRoutines++;
    }
  } 
}

sub fillBeginArtifactCommentBloc($$) {
  my $agglo = shift;
  my $data = shift;

  if (scalar @{$data} == 0) {
    return;
  }

  my $next_fct_idx = 0;
  my $next_fct_line = $data->[$next_fct_idx]->[0];

  my $line="";
  my $nb_line=0;
  my $InComment = 0;
  my $BeginComment = 0;
  while ( $$agglo =~ /^(.*)$/mg ) {
    $nb_line++;
    if ($nb_line == $next_fct_line) {
#print "Begin comment for ".GetName($data->[$next_fct_idx]->[1])." at line $BeginComment\n";
      $data->[$next_fct_idx]->[2] = $BeginComment;
      $BeginComment = -1;
      $next_fct_idx++;
      if ($next_fct_idx < scalar @$data) {
        $next_fct_line = $data->[$next_fct_idx]->[0];
#print "next function line = $next_fct_line\n";
      }
    }

    $line = $1;
    # If line of comment ...
    if ($line =~ /^\s*C\s*$/m) {
      # If new comment bloc
      if ($BeginComment == -1) {
        $BeginComment = $nb_line;
      }
    }
    else {
      # If non blank code line ... end of the current comment bloc !
      if ($line =~ /\S/m) {
        $BeginComment=-1;
      }
    }
  }
}

sub ptr_checkLowCommentedFunctions($$) {
  my $agglo = shift;

  my $nbC = () = $$agglo=~/C/sg;
  my $nbP = () = $$agglo=~/P/sg;
#print "AGGLO = $$agglo\n";
#print "C = $nbC, P = $nbP\n";
  if ( $nbC < (($nbP * $COMMENT_RATIO) / 100) ) {
    $nb_LowCommentedRoutines++;
#print "=======> FOUND a LowCommented Violement!!!\n";
  }
}


sub CountArtifacts($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  $nb_MissingThrowsTags = 0;
  $nb_UnusedThrowsTags = 0;
  $nb_LowCommentedRoutines = 0;
  $nb_UnCommentedRoutines = 0;
  $nb_UnCommentedClasses = 0;
  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $MissingThrowsTags__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $UnusedThrowsTags__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $LowCommentedRoutines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $UnCommentedRoutines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @Artifacts = GetNodesByKindList($root, [ FunctionKind, ClassKind ] );

  #***************************************************************
  # ******* PRELIMINARY TREATMENTS FOR EACH FUNCTION  ************
  #***************************************************************
  my @tmp = ();
  my @comment_ratio_data = ();
  for my $artif (@Artifacts) {
      my $BeginLine = GetLine($artif);
      my $EndLine = GetEndline($artif);
      my %EmptyList = ();
      # record data for THROW tags analysis 
      push @tmp, [$BeginLine, $artif, -1, \%EmptyList];

      if (IsKind($artif, FunctionKind)) {
        # record data for comment ratio analysis
        push @comment_ratio_data, [$BeginLine, $EndLine, \&ptr_checkLowCommentedFunctions]
      }
  }

  #***************************************************************
  # ******* SYNTHESIS TREATMENTS  ********************************
  #***************************************************************


            #     1  -- Comment ratio analysis
            #----------------------------------------

  # Check comments in the pre-defined zones ...
  CountUtil::checkComment(\$vue->{'agglo'}, \@comment_ratio_data);


            #     2  -- Function header / THROW tags analysis
            #----------------------------------------


  @DATA_ARTIFACT = sort { $a->[0] <=> $b->[0] } @tmp;

  # ******** Search line beginning of each comment bloc preceding the artifact
  #----------------------------------------------------------------------------
  fillBeginArtifactCommentBloc(\$vue->{'agglo'}, \@DATA_ARTIFACT);

  # ******** Get "Throw" informations contained in each comment bloc
  #-----------------------------------------------------------------------------
  my @TabToCheck = ();
  for my $data (@DATA_ARTIFACT) {
    # Corresponding of data :
    #  [$data->[2] = <Begin comment line>
    #  $data->[0] = <Begin fct line>
    #  \&ptr_checkDocumentalComment = &<callback>
    #  $data->[3] = <thow_data_buffer> ]
    if (($data->[2] != -1) && ($data->[0] > 1)) {

      my $r_VAR_nb_viol;

      if (IsKind($data->[1], FunctionKind)) {
        $r_VAR_nb_viol = \$nb_UnCommentedRoutines;
      }
      else {
        $r_VAR_nb_viol = \$nb_UnCommentedClasses;
      }

      push @TabToCheck, [$data->[2], $data->[0]-1,  \&ptr_checkDocumentalComment, [$data->[3], $r_VAR_nb_viol]];
    }
    else {
      # this signifies the data have badly been filled by fillBeginArtifactCommentBloc !!
    } 
  }

  # Check comments in the pre-defined zones ...
  CountUtil::checkComment(\$vue->{'comment'}, \@TabToCheck);

  # *************** Get "Throw" informations contained in each function body 
  #----------------------------------------------------

    for my $data (@DATA_ARTIFACT) {

      # Check Throw tags only for functions ...
      if ( IsKind($data->[1], FunctionKind)) {
        my @Throws = GetNodesByKind($data->[1], ThrowKind);
  	    #my $artiKey = buildArtifactKeyByData(GetName($data->[1]), $line);
  #print "LIST of throws = ".join (',',keys %{$data->[3]})."\n";
  
        my %MissingThrowTag = ();
        my %UsedThrowTag = ();
        my $nb_unknowException = 0;
        for my $throw ( @Throws ) {
          if ( ${GetStatement($throw)} =~ /\bthrow\s+new\b\s*\(?\s*((?:\w|::)*)/si) {
  	  # KNOWN EXCEPTION
  
            if (!exists $data->[3]->{$1} ) {
  	    # No corresponding @throws tag
  #print "==> violement : $1 not described !!!\n";
              $MissingThrowTag{$1} = 1;
  	  } 
  	  else {
  	    # corresponding @throws tag is present
              $UsedThrowTag{$1} = 1;
  	  }
  	}
  	else {
            # UNKNOWN EXCEPTION
            $nb_unknowException++;
  	}
        }
        # nb type of exceptions which do not have a corresponding @throws tag.
        $nb_MissingThrowsTags += scalar keys  %MissingThrowTag;
  #print "MISSING THROW for ". GetName($data->[1]). " : $nb_MissingThrowsTags\n";
  
        # Compute number of unused @throws tags :
        my $local_unused = 0;
        for my $tag (keys %{$data->[3]}) {
          if ( !exists $UsedThrowTag{$tag}) {
            $local_unused++;
  	}
        }
  
        # refine unused result, taking into account the number of throw with an
        # unknow exception type. 
        if (($local_unused == 0) && ($nb_unknowException >0)) {
  	# If there is no unused tag and there are unknown exceptions thrown,
  	# then there is at least ONE MISSING TAG.
          $nb_MissingThrowsTags++;
        }
        elsif ($local_unused > $nb_unknowException) {
  	# If there is more unused tag than unknown exceptions thrown, then 
  	# the difference is at least the number of unused/useless @throws tags.
          $nb_UnusedThrowsTags += $local_unused - $nb_unknowException;
        }
        else {
          # Nothing. We are not able to say if the unused @throws tags correspond
  	# to the unknown exceptions thrown.
        }
      }
    }

#print "MISSING THROW TAGS = $nb_MissingThrowsTags\n";
#print "UNUSED THROW TAGS = $nb_UnusedThrowsTags\n";

  $ret |= Couples::counter_add($compteurs, $MissingThrowsTags__mnemo, $nb_MissingThrowsTags );
  $ret |= Couples::counter_add($compteurs, $UnusedThrowsTags__mnemo, $nb_UnusedThrowsTags );
  $ret |= Couples::counter_add($compteurs, $LowCommentedRoutines__mnemo, $nb_LowCommentedRoutines );
  $ret |= Couples::counter_add($compteurs, $UnCommentedRoutines__mnemo, $nb_UnCommentedRoutines );
  $ret |= Couples::counter_add($compteurs, $UnCommentedClasses__mnemo, $nb_UnCommentedClasses );

  return $ret;
}


sub ptr_checkEmptyCatches() {
  my $buffer = shift;
#print "ptr/CATCH BUFFER = $$buffer\n";
  if ( $$buffer !~ /\S/si ) {
#print "==> Empty catch !!\n";
    $nb_EmptyCatches++;
  }
}

sub CountEmptyCatches($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  $nb_EmptyCatches = 0;
  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $EmptyCatches__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @TabToCheck = ();
  my @Catches = GetNodesByKind($root, CatchKind );

  for my $catch (@Catches) {

    # get Instructions contained ion the catch :
    # The first contains only the curly braced bloc that contains the instructions, 
    # forget this node level :
    #   GetSubBloc($method)
    #       ==> the list of first-level node children of the catch
    #   GetSubBloc($catch)->[0])
    #       ==> the first ComplexRootCodeelement of this list, that is the bloc that contains the instructions children.
    #   GetSubBloc(GetSubBloc($catch)->[0]) 
    #       ==> the list of node instructions of the catch.
    my $children = GetSubBloc(GetSubBloc($catch)->[0]);

    if ((scalar @{$children} == 0 ) || (IsKind($children->[0], EmptyKind))) {
      #  if there are no instructions in the catch, then check if a comment is present ...
      my $BeginLine = GetLine($catch);
      my $EndLine = GetEndline($catch);
      if ($EndLine > $BeginLine) {
	# Dont check if a comment is present on the same line than the closing curly bracket.
        $EndLine--;
      }
      push @TabToCheck, [$BeginLine, $EndLine, \&ptr_checkEmptyCatches ];
    }
  }

  # Check comments in the pre-defined zones ...
  CountUtil::checkComment(\$vue->{'comment'}, \@TabToCheck);

  $ret |= Couples::counter_add($compteurs, $EmptyCatches__mnemo, $nb_EmptyCatches );

  return $ret;
}

sub ptr_checkMissingEndComment() {
  my $buffer = shift;
 
  if ( $$buffer !~ /\A(?:\s|#|\/\/|\/\*)*\bend\b/si ) {
#print "==> Missing End comment !!\n";
    $nb_MissingEndComment++;
  }
}

sub CountMissingEndComment($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  $nb_MissingEndComment = 0;
  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $MissingEndComment__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @TabToCheck = ();
  my @Artifs = GetNodesByKindList($root, [ClassKind, InterfaceKind, FunctionKind ] );

  for my $artif (@Artifs) {
    my $EndLine = GetEndline($artif);

	if (defined $EndLine) {
		push @TabToCheck, [$EndLine, $EndLine, \&ptr_checkMissingEndComment ];
	}
	else {
		print STDERR "[PHP::CountComments::CountMissingEndComment] ERROR missing end line for artifact beginning at line ".GetLine($artif)."\n";
	}
  }

  # Check comments in the pre-defined zones ...
  CountUtil::checkComment(\$vue->{'comment'}, \@TabToCheck);

  $ret |= Couples::counter_add($compteurs, $MissingEndComment__mnemo, $nb_MissingEndComment );

  return $ret;
}


sub ptr_countRootComment($;$) {
  my $buffer = shift;
  my $r_nbLines = shift;
  $$buffer =~ s/\/\*\*(?:\*[^\/]|[^\*])*\*\///sg;
  $$r_nbLines += () = $$buffer =~ /^.*\S.*$/mg;
}


sub ptr_countRootCode($;$) {
  my $buffer = shift;
  my $counts = shift;
  $$buffer =~ s/<\?(php)?|\?>//sg;
  $counts->[0] += () = $$buffer =~ /^.*\S.*$/mg;
  $counts->[1] += () = $$buffer =~ /\b(if|elseif|while|for|foreach|catch|case)\b/isg;
}


sub CountRootComment($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  $nb_LowCommentedRootCode = 0;
  $nb_ComplexRootCode = 0;
  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $LowCommentedRootCode__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ComplexRootCode__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @ExcludedArtifacts = GetNodesByKindList($root, [FunctionKind], 1);

  my @TabToCheckComment = ();
  my @TabToCheckCode = ();
  my $root_line = 1;
  my $nbRootCommentLines = 0;
  my $nbRootCounts = [0,    # ==> number of LOC in root part of the code
	              0];   # ==> number of decisions in the root part of the code.
  for my $artif (@ExcludedArtifacts) {
    my $start = GetLine($artif);
    my $end = GetEndline($artif);
    if ($start > 1) {
#print "Checking $root_line --> ".($start-1)."\n";
      push @TabToCheckComment, [$root_line, $start-1, \&ptr_countRootComment, \$nbRootCommentLines ];
      push @TabToCheckCode, [$root_line, $start-1, \&ptr_countRootCode, $nbRootCounts ];
    }
    $root_line = $end+1;
  }

  # Add the last bloc. Value -1 for the end line signifies the end of the file buffer.
#print "Checking $root_line --> -1\n";
  push @TabToCheckComment, [$root_line, -1, \&ptr_countRootComment, \$nbRootCommentLines ];
  push @TabToCheckCode, [$root_line, -1, \&ptr_countRootCode, $nbRootCounts ];

  CountUtil::checkComment(\$vue->{'comment'}, \@TabToCheckComment);
  CountUtil::checkComment(\$vue->{'code'}, \@TabToCheckCode);

#print "NB ROOT COMMENT LINES = $nbRootCommentLines\n";
#print "NB ROOT CODE LINES = ".$nbRootCounts->[0]."\n";

  # $nbRootCounts->[0] number of LOC in the root part of the code
  if ( $nbRootCommentLines < (($nbRootCounts->[0] * $COMMENT_RATIO) / 100) ) {
    $nb_LowCommentedRootCode++;
#print "==> LOW COMMENTED ROOT !!!\n";
  }

  # $nbRootCounts->[1] number of decisions in the root part of the code
  if ( ($nbRootCounts->[1]+1) > $PHP::PHPConfig::ComplexArtifact__THRESHOLD) {
    $nb_ComplexRootCode ++;
  }

  $ret |= Couples::counter_add($compteurs, $LowCommentedRootCode__mnemo, $nb_LowCommentedRootCode );
  $ret |= Couples::counter_add($compteurs, $ComplexRootCode__mnemo, $nb_ComplexRootCode );
}

1;




