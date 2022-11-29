

package TSql::CountRoutine;
# Module du comptage TDB: Nombre de procedures internes non referencees.

use strict;
use warnings;

use TSql::Node;
use TSql::TSqlNode;

use Erreurs;

use Ident;

my $DEBUG=1;

sub analyze_Transaction_SQL($;$$$);
sub countUnsafeSQL($$);
sub checkFinalReturn($);
sub CountRoutine($$$);
sub CheckComplexArtifact($$);

my $SHORT_FUNCTION_NAME_LT__LIMIT = 7;
my $SHORT_FUNCTION_NAME_HT__LIMIT = 10;
my $ComplexArtifact__THRESHOLD = 5;
my $MAX_ARTIFACT_LINE_THRESHOLD = 50 ;
my $MAX_ROUTINE_PARAM_THRESHOLD = 5 ;

my $Procedure__mnemo = Ident::Alias_ProcedureImplementations();
my $Function__mnemo = Ident::Alias_FunctionImplementations();
my $Trigger__mnemo = Ident::Alias_TriggerImplementations();
my $ShortRoutNameLT__mnemo = Ident::Alias_ShortFunctionNamesLT();
my $ShortRoutNameHT__mnemo = Ident::Alias_ShortFunctionNamesHT();
my $UnmanagedSQLRoutine__mnemo = Ident::Alias_UnmanagedSQLRoutine();
my $UnsecureSQLRoutine__mnemo = Ident::Alias_UnsecureSQLRoutine();
my $ComplexArtifact__mnemo = Ident::Alias_ComplexArtifact();
my $LongArtifact__mnemo = Ident::Alias_LongArtifact();
my $WithoutFinalReturn__mnemo = Ident::Alias_WithoutFinalReturn_Functions();
my $WithTooMuchParametersMethods__mnemo = Ident::Alias_WithTooMuchParametersMethods();
my $RecursiveTrigger__mnemo = 'Nbr_RecursiveTrigger';

#my $UnmanagedTransSQLRoutine__mnemo = 'Nbr_UnmanagedTransSQLRoutine';
#my $UnmanagedErrorSQLRoutine__mnemo = 'Nbr_UnmanagedErrorSQLRoutine';


my $nb_Procedure = 0;
my $nb_Function = 0;
my $nb_Trigger = 0;
my $nb_ShortRoutNameLT = 0;
my $nb_ShortRoutNameHT = 0;
my $nb_UnmanagedSQLRoutine = 0;
my $nb_UnsecureSQLRoutine = 0;

my $nb_UnmanagedTransSQLRoutine = 0;
my $nb_UnmanagedErrorSQLRoutine = 0;
my $nb_ComplexArtifact = 0;
my $nb_LongArtifact = 0;
my $nb_WithoutFinalReturn = 0;
my $nb_WithTooMuchParametersMethods = 0;
my $nb_RecursiveTrigger = 0;

# Variables for CountComplexArtifact


###################################################################
###### Following algorithm is not actually used because too complex
###################################################################
my %H_Tran_ID = ();

sub get_Tran_ID($) {
  my $name = shift;

  if ( ! exists $H_Tran_ID{$name} ) {
    $H_Tran_ID{$name} = 0;
  }
  else {
    $H_Tran_ID{$name} += 1 ;
  }

  return $name."_".$H_Tran_ID{$name};
}

my %H_Sql_ID = ();

sub get_Sql_ID($) {
  my $name = shift;

  if ( ! exists $H_Sql_ID{$name} ) {
    $H_Sql_ID{$name} = 0;
  }
  else {
    $H_Sql_ID{$name}++ ;
  }

  return $name."_".$H_Sql_ID{$name};
}

sub mergeTran($$) {
  my ($Tran1, $Tran2) = @_ ;

  if (! defined $Tran1) {
    return $Tran2;
  }
  if (! defined $Tran2) {
    return $Tran1;
  }
  # Creation of the global table.
  my %H_Tran = ();
  for my $tran (@$Tran1) {
    $H_Tran{$tran} = 1;
  }
  for my $tran (@$Tran2) {
    if (exists $H_Tran{$tran}) {;
      $H_Tran{$tran} ++;
    }
    else {
      $H_Tran{$tran} = 1;
    }
  }

  # Merge of the lists
  my @Tran = ();
  my $same = 1;
  my $S1 = scalar @$Tran1;
  my $S2 = scalar @$Tran2;
  my $i1=0;
  my $i2=0;
  while (($i1 < $S1) && ($i2<$S2)) {
    if ($Tran1->[$i1] eq $Tran2->[$i2]) {

      # The test is to prevent from doubles.
      if ($H_Tran{$Tran1->[$i1]} > 0) {
        push (@Tran, $Tran1->[$i1]);
	$H_Tran{$Tran1->[$i1]} = 0;
      }
      $i1++; $i2++;
    }
    # the transition belong only to the first list ...
    elsif ($H_Tran{$Tran1->[$i1]} == 1) {
      push (@Tran, $Tran1->[$i1]);
      $i1++;
      $same = 0;
    }
    # the transition belong only to the second list ...
    elsif ($H_Tran{$Tran2->[$i2]} == 1) {
      push (@Tran, $Tran2->[$i2]);
      $i2++;
      $same = 0;
    }
    else {
      # Both transactions of the two lists belong to both lists !!! They are
      # both pushed unless they have allready been (ie 0 in the Hash table)...
      #
      # REMARK :This case should never happen. If both transaction belong to
      # the both lists, then they should be at the same place and should be
      # treated in the first case of this "if" sequence.
      print "[mergeTran] error : bad order for transaction.\n";
      if ($H_Tran{$Tran1->[$i1]} > 0) {
        push (@Tran, $Tran1->[$i1]);
	$H_Tran{$Tran1->[$i1]} = 0;
      }
      if ($H_Tran{$Tran2->[$i2]} > 0) {
        push (@Tran, $Tran2->[$i2]);
	$H_Tran{$Tran2->[$i2]} = 0;
      }
      $i1++; $i2++;
      $same = 0;
    }
  }

  while ($i1 < $S1) {
    if ($H_Tran{$Tran1->[$i1]} > 0) {
      push (@Tran, $Tran1->[$i1]);
      $H_Tran{$Tran1->[$i1]} = 0;
     }
     $i1++;
     $same = 0;
  }

  while ($i2 < $S2) {
    if ($H_Tran{$Tran2->[$i2]} > 0) {
      push (@Tran, $Tran2->[$i2]);
      $H_Tran{$Tran2->[$i2]} = 0;
     }
     $i2++;
     $same = 0;
  }

  if ($same) {
    # Both lists are identical
    return \@Tran;
  }
  else {
    # Lists are differents, return the merged list.
    print "[mergeTran] warning : parallele path don't affect transactions in the same way.\n";
    print "[mergeTran] merged => ".join (", ", @Tran)."\n";
    return \@Tran;
  }
}

sub mergeSql($$) {
  my ($Sql1, $Sql2) = @_ ;

  my @Sql = ();
  my %H_Sql = ();

  # Push all entry of Sql1 in the result.
  for my $sql (@$Sql1) {
    my $tag = $sql->[0];
    $H_Sql{$tag} = 1;
    push @Sql, $sql;
  }
  # Push only entry of Sql2 that do not belong to sql1 in the result.
  for my $sql (@$Sql2) {
    my $tag = $sql->[0];
    if (exists $H_Sql{$tag}) {
      push @Sql, $sql;
    }
  }
  return \@Sql;
}

sub closeTran($$$) {
  my ($name, $Tran, $Sql) = @_ ;

  my $name_id = "";

  if (scalar @$Tran > 0) {
    my $lastTran = $Tran->[-1];
    if ($lastTran =~ /^${name}[_]\d+$/m ) {
      $name_id = pop @$Tran;
    }
    else {
      $name_id = pop @$Tran;
      print "[closeTran] error : bad transaction ($name) for commit or rollback ($name_id was expected).\n";
    }
  }
  else {
    print "[closeTran] error : rollback or commit ($name) without begin tran !!\n";
  }

  # Remove all sql that depend on closed transition.
  my $i=0;
  for my $sql (@$Sql) {
    if ($sql->[1] eq $name_id) {
      splice @$Sql, $i, 1;
    }
    $i++;
  }
}

#sub getLabelNode($$) {
#  my ($name, $root) = @_ ;
#
#  my @Labels = GetNodesByKind($root, LabelKind);
#
#  for my $label (@Labels) {
#    if (GetName($label) eq $name ) {
#      return $label;
#    }
#  }
#}

# If the function is called with only one parameter, then it signifies this
# is the base node for the analysis.
sub analyze_Transaction_SQL($;$$$) {
  my ($node, $Tran, $Sql, $root) = @_ ;

  if (! defined $root) {
    $root = $node;
  }

  if (! defined $Tran) {
    $Tran = [];
  }
  if (! defined $Sql) {
    $Sql = [];
  }

  # IF
  if (IsKind($node, IfKind)) {
    my $children = GetSubBloc($node);
print "TREATING IF ...\n";

    my $then_Tran=undef;
    my $then_Sql=undef;
    my $then_continue = 1;
    my $else_Tran=undef;
    my $else_Sql=undef;
    my $else_continue = 1;

    # Traitement du IF.
    if (IsKind($children->[1], ThenKind)) {
      # $Tran and $Sql are dupplicated because they will be treated in parallel
      # and merged after. analyze_Transaction_SQL modifies the parameters passed to it. 
      my @If_Tran = @$Tran;
      my @If_Sql = @$Sql;
      ($then_Tran, $then_Sql) = analyze_Transaction_SQL($children->[1], \@If_Tran, \@If_Sql, $root);
    }
    else {
      print "[analyze_Transaction_SQL] error : second child of 'if' is not a 'then'\n";
      @$then_Tran = @$Tran;
    }

    # Traitement du ELSE (s'il y en a un)
    if ( (defined $children->[2]) && IsKind($children->[2], ElseKind)) {
      # $Tran and $Sql are dupplicated because they will be treated in parallel
      # and merged after. analyze_Transaction_SQL modifies the parameters passed to it.
      my @If_Tran = @$Tran;
      my @If_Sql = @$Sql;
      ($else_Tran, $else_Sql) = analyze_Transaction_SQL($children->[2], \@If_Tran, \@If_Sql, $root);
    }
    else {
      # If there's no "else" then the transaction list can't be effected. So
      # it is the same of when entering in the if.
      @$else_Tran = @$Tran;
    }

#print "THEN : ". join (" ", @$then_Tran)."\n";
#print "ELSE : ". join (" ", @$else_Tran)."\n";
      # Check for compliance. Both ways should have the same impact.
      # and update Tran in consequence.
print "--> THEN : ";
      if (defined $then_Tran) {
print join (" ", @$then_Tran)."\n";
      }
      else {print "undef\n";}
print "--> ELSE : ";
      if (defined $else_Tran) {
print join (" ", @$else_Tran)."\n";
      }
      else {print "undef\n";}
    $Tran = mergeTran($then_Tran, $else_Tran);
#      my $merged_Tran = mergeTran($then_Tran, $else_Tran);
#      if ( defined $merged_Tran ) {
#        print "[analyze_Transaction_SQL] warning : parallele path don't affect transactions in the same way.\n";
#        print "[analyze_Transaction_SQL] merged => ".join (", ", @$merged_Tran)."\n";
#      }
#      else {
#	# Both lists are identicall => no merge to do ...
#        $Tran = $then_Tran;
#      }

    # Update lists
    $Sql = mergeSql($then_Sql, $else_Sql);
  }

  # BEGIN TRANSITION.
  elsif (IsKind($node, BeginTranKind)) {
    my $name = GetName($node);
    if (! defined $name) { $name = "ano";} # anonymous transaction;
    push @$Tran, get_Tran_ID($name);
    print "NEW LIST = ".join (" ", @$Tran)."\n";
  }
  # COMMIT
  elsif (IsKind($node, CommitTranKind)) {
    my $name = GetName($node);
    if (! defined $name) { $name = "ano";} # anonymous transaction;
    closeTran($name, $Tran, $Sql);
  }
  # ROOLBACK
  elsif (IsKind($node, RollbackTranKind)) {
    my $name = GetName($node);
    if (! defined $name) { $name = "ano";} # anonymous transaction;
    closeTran($name, $Tran, $Sql);
  }
  # GOTO
#  elsif (IsKind($node, GotoKind)) {
#    my $name = GetName($node);
#    if (! defined $name) { ;} # anonymous transaction;
#    my $LabelNode = getLabelNode($name, $root);
#    return analyze_Transaction_SQL($LabelNode, $Tran, $Sql, $root);
#  }
  # RETURN
  elsif (IsKind($node, ReturnKind)) {
    if (scalar @$Tran > 0) {
      print "[analyze_Transaction_SQL] error : unmatched transactions.\n";
      print "[analyze_Transaction_SQL] list => ".join (", ", @$Tran)."\n";
    }
    return (undef, undef, 0);
  }
  # SQL INSTRUCTION
  elsif (IsKind($node, SQLKind)) {
    my $stmt = GetStatement($node);
    if ($stmt =~ /\A\s*(insert|update|delete)\b/) {
      my $SqlName = get_Sql_ID($1);
      my $TranName = "";
      if (scalar @$Tran > 0) {
        $TranName=$Tran->[-1];
      }
      push @$Sql, [ $SqlName, $TranName];
    }
  }
  else {
    my $children = GetSubBloc($node);

    for my $child (@$children) {
      ($Tran, $Sql) = analyze_Transaction_SQL($child, $Tran, $Sql, $root);
      if (! defined $Tran) {
        last;
      }
    }
  }

  # The number of violation ise number of SQL statement that are not in a 
  # transaction section, or wh corresponding section has not been close.
  return ($Tran, $Sql);
}

###################################################################
###### END OF UNUSED ALGO
###################################################################

sub countUnsafeSQL($$) {
  my $root = shift;
  my $ArtifactsView = shift ;


  my $sql_found =0;
  my $select_found =0;
  my $manage_tran_found = 0;
  my $manage_error_found = 0;

  # Chech MANAGEMENT of SQL instructions : check presence of "begin tran" instruction
  # or use of @@trancount (not implemented, because it seems that check presence of 
  # "begin tran" is sufficient) ...

  my @BeginTrans = GetNodesByKind($root, BeginTranKind);
  # update & delete instructions are identified with general SQLKind.
  my @Sqls = GetNodesByKind($root, SQLKind);
  # Inserts instructions are identified with specific InsertKind.
  my @Inserts = GetNodesByKind($root, InsertKind);

  my @Creates = GetNodesByKind($root, CreateKind);

  for my $sql (@Sqls) {
    my $stmt = ${GetStatement($sql)};
    if ($stmt =~ /\A\s*(update|delete|insert)\b/i) {
      $sql_found =1;
      last;
    }
  }

  if ( scalar @Inserts > 0) {
    $sql_found=1;
  } 

  if ($sql_found && (scalar @BeginTrans == 0)) {
    $nb_UnmanagedSQLRoutine ++;
  }

  # Chech SECUTIRTY of SQL instructions : check presence of try...catch or @@error check ...
  if (defined $ArtifactsView) {
    my $name = GetName($root) ;
    my $content = $ArtifactsView->{$name};
    if (! defined $content) {
      print "WARNING : no content for $name\n";
      return ;
    }
  
    my @Catches = GetNodesByKind($root, BeginCatchKind);
    my @Selects = GetNodesByKind($root, SelectKind);
  
    # Add new case to SQL finding : SQL is found if there is at least one create table ...
    for my $create (@Creates) {
      my $stmt = ${GetStatement($create)};
      if ($stmt =~ /\A\s*(table)\b/i) {
        $sql_found =1;
        last;
      }
    }
  
    my $testErrorVar = () = $content =~ /\@\@error/isg ;
  
    # Add new case to SQL finding : SQL is found if there is at least one select ...
    # RQ : valid only if the select contains a FROM (not just an assignment)...
    for my $select (@Selects) {
      my $name = GetName($select);
      my $content = $ArtifactsView->{$name};
      if ( $content =~ /\bfrom\b/is ) {
        $sql_found = 1;
        last;
      }
    }
  
    if ($sql_found && ((scalar @Catches == 0) && ($testErrorVar == 0))) {
      $nb_UnsecureSQLRoutine ++;
    }
  }

}

sub checkFinalReturn($) {
  my $procfunc = shift;
  my $MissingFinalReturn=1;
 
  my $bloc = GetSubBloc($procfunc);
  foreach my $node ( @{$bloc} )
  {
    # separators (;) will fail the algo. They must be ignored.
	if (IsKind($node, SeparatorKind)) {
		next;
	}
	  
    if (IsKind($node, BeginKind)) {
      $MissingFinalReturn = checkFinalReturn($node);     
    }
    elsif ( IsKind($node, IfKind) ) {
      my $then =  GetSubBloc($node)->[1];
      my $else =  GetSubBloc($node)->[2];
      my $thenMissingFinalReturn;
      my $elseMissingFinalReturn;
      if ((defined $then) && (IsKind($then, ThenKind))) {
        $thenMissingFinalReturn = checkFinalReturn($then);
      }
      if ((defined $else) && (IsKind($else, ElseKind))) {
        $elseMissingFinalReturn = checkFinalReturn($else);
      }
      if ( (! $thenMissingFinalReturn) && (! $elseMissingFinalReturn) ) {
        $MissingFinalReturn = 0;
      }
    }
    elsif ( IsKind($node, ReturnKind) ) {
      $MissingFinalReturn = 0;
    }
    elsif ( ! (IsKind($node, EndKind) || IsKind($node, GoKind))) {
      $MissingFinalReturn = 1;
    }
  }
  return $MissingFinalReturn;
}


sub hasTooMuchParameters($) {
  my $rout = shift;

  # The statement contains only the declarative part of the routine.
  my $nb_param = () = GetStatement($rout) =~ /,/sg ;
  if ($nb_param > 0) {
    $nb_param++;
  }
  if ( $nb_param > $MAX_ROUTINE_PARAM_THRESHOLD) {
    return 1;
  }
  else {
    return 0;
  }
}


# Trigger on a CREATE, ALTER, DROP, GRANT, DENY, REVOKE, or UPDATE STATISTICS statement (DDL Trigger)
# CREATE TRIGGER trigger_name 
# ON { ALL SERVER | DATABASE } 
# [ WITH <ddl_trigger_option> [ ,...n ] ]
# { FOR | AFTER } { event_type | event_group } [ ,...n ]
# AS { sql_statement  [ ; ] [ ,...n ] | EXTERNAL NAME < method specifier >  [ ; ] }
#
# <ddl_trigger_option> ::=
#    [ ENCRYPTION ]
#    [ EXECUTE AS Clause ]
#
# Trigger on an INSERT, UPDATE, or DELETE statement to a table or view (DML Trigger)
# CREATE TRIGGER [ schema_name . ]trigger_name 
# ON { table | view } 
# [ WITH <dml_trigger_option> [ ,...n ] ]
# { FOR | AFTER | INSTEAD OF } 
# { [ INSERT ] [ , ] [ UPDATE ] [ , ] [ DELETE ] } 
# [ WITH APPEND ] 
# [ NOT FOR REPLICATION ] 
# AS { sql_statement  [ ; ] [ ,...n ] | EXTERNAL NAME <method specifier [ ; ] > }
# 
# <dml_trigger_option> ::=
# [ ENCRYPTION ]
# [ EXECUTE AS Clause ]
# 
#
# CONSOLIDATED PATTERN :
# -----------------------
#
# CREATE TRIGGER trigger_name 
#               ON { ALL SERVER | DATABASE | table | view } 
#               [ WITH <ddl_trigger_option> [ ,...n ] ]
#	       { FOR | AFTER | INSTEAD OF}
#	       {
#		 { event_type | event_group } [ ,...n ]
#		 |       
#	         { [ INSERT ] [ , ] [ UPDATE ] [ , ] [ DELETE ] }
#	       }
#              [ WITH APPEND ] [ NOT FOR REPLICATION ] AS 


sub CheckRecursiveTrigger($$) {
 my $trig =shift;
 my $ArtifactsView = shift;

 return 0;
}


sub CountRoutine($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_Procedure = 0;
  $nb_Function = 0;
  $nb_Trigger = 0;
  $nb_ShortRoutNameLT = 0;
  $nb_ShortRoutNameHT = 0;
  $nb_UnmanagedSQLRoutine = 0;
  $nb_UnsecureSQLRoutine = 0;
  $nb_ComplexArtifact = 0;
  $nb_LongArtifact = 0;
  $nb_WithoutFinalReturn = 0;
  $nb_WithTooMuchParametersMethods = 0;
  $nb_RecursiveTrigger = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $Procedure__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Function__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Trigger__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ShortRoutNameLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ShortRoutNameHT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $UnmanagedSQLRoutine__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $UnsecureSQLRoutine__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ComplexArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $LongArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $WithoutFinalReturn__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $RecursiveTrigger__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  $NomVueCode = 'routines' ; 
  my $ArtifactsView =  $vue->{$NomVueCode} ;
  if ( ! defined $ArtifactsView )
  {
    $ret |= Couples::counter_add($compteurs, $ComplexArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $LongArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $UnsecureSQLRoutine__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $RecursiveTrigger__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @Procs = GetNodesByKind( $root, ProcedureKind);
  my @Funcs = GetNodesByKind( $root, FunctionKind);
  my @Triggs = GetNodesByKind( $root, TriggerKind);

  my @Routines = (@Procs, @Funcs, @Triggs);
  my @ProcsFuncs =  (@Procs, @Funcs);

  # Count nb routines ...
  $nb_Procedure += scalar @Procs; 
  $nb_Function += scalar @Funcs;  
  $nb_Trigger += scalar @Triggs; 

  # For ALL routines 
  for my $rout (@Routines) {

     my $routName = GetName($rout) ;

     # CHECK name length
     if ( $routName !~ /^unnamed_routine_\d+$/m) {
       if ( length($routName) < $SHORT_FUNCTION_NAME_LT__LIMIT ) {
         $nb_ShortRoutNameLT++;
       }
       if ( length($routName) < $SHORT_FUNCTION_NAME_HT__LIMIT ) {
         $nb_ShortRoutNameHT++;
       }
     }


     if ( defined $ArtifactsView ) {
       countUnsafeSQL($rout, $ArtifactsView);
       $nb_ComplexArtifact += CheckComplexArtifact($rout, $ArtifactsView);
       $nb_LongArtifact += CheckLongArtifact($rout, $ArtifactsView);
     }
     else {
       $nb_ComplexArtifact=Erreurs::COMPTEUR_ERREUR_VALUE
       $nb_UnmanagedSQLRoutine=Erreurs::COMPTEUR_ERREUR_VALUE
       $nb_UnsecureSQLRoutine=Erreurs::COMPTEUR_ERREUR_VALUE
       $nb_LongArtifact=Erreurs::COMPTEUR_ERREUR_VALUE
     }
  }

  # For ALL procedures and function only... 
  for my $procfunc (@ProcsFuncs) {
    $nb_WithoutFinalReturn += checkFinalReturn($procfunc);
    $nb_WithTooMuchParametersMethods += hasTooMuchParameters($procfunc);
  }

  for my $trigg (@Triggs) {
    my $name = GetName($trigg);
    if ( defined $ArtifactsView ) {
       $nb_RecursiveTrigger += CheckRecursiveTrigger($name, $ArtifactsView);
    }
     else {
       $nb_RecursiveTrigger=Erreurs::COMPTEUR_ERREUR_VALUE
     }
  }

  $ret |= Couples::counter_add($compteurs, $Procedure__mnemo, $nb_Procedure );
  $ret |= Couples::counter_add($compteurs, $Function__mnemo, $nb_Function );
  $ret |= Couples::counter_add($compteurs, $Trigger__mnemo, $nb_Trigger );
  $ret |= Couples::counter_add($compteurs, $ShortRoutNameLT__mnemo, $nb_ShortRoutNameLT );
  $ret |= Couples::counter_add($compteurs, $ShortRoutNameHT__mnemo, $nb_ShortRoutNameHT );
  $ret |= Couples::counter_add($compteurs, $UnmanagedSQLRoutine__mnemo, $nb_UnmanagedSQLRoutine );
  $ret |= Couples::counter_add($compteurs, $UnsecureSQLRoutine__mnemo, $nb_UnsecureSQLRoutine );
  $ret |= Couples::counter_add($compteurs, $ComplexArtifact__mnemo, $nb_ComplexArtifact );
  $ret |= Couples::counter_add($compteurs, $LongArtifact__mnemo, $nb_LongArtifact );
  $ret |= Couples::counter_add($compteurs, $WithoutFinalReturn__mnemo, $nb_WithoutFinalReturn );
  $ret |= Couples::counter_add($compteurs, $WithTooMuchParametersMethods__mnemo, $nb_WithTooMuchParametersMethods );
  $ret |= Couples::counter_add($compteurs, $RecursiveTrigger__mnemo, $nb_RecursiveTrigger );

  return $ret;
}


# Cyclomatic complexity for a program with multiple exit points is :
#
#    p + 1      with single exit point
#
#    that could be extended to :
#    p - s + 2  with multiple exit points
#
# where :
#     p is the number of decision points in the program,
#     s is the number of exit points.

sub CheckComplexArtifact($$) 
{
  my $artifact = shift;
  my $ArtifactsView = shift ;
  my $ret = 0;
  my $name = GetName($artifact) ;

  my $content = $ArtifactsView->{$name};

  if (! defined $content) {
    print "WARNING : no content for $name\n" if ($DEBUG);
    return 0;
  }
  
  # Count p
  my $p = () = $content =~ /\b(?:if|while)\b/isg;

  # Count s
  my $s = () = $content =~ /\b(?:return)\b/isg;
  if ($s == 0) {
    # if no "return" instruction, then count at least the default exit at end of the
    # routine.
    $s= 1;
  }

  if ( ($p-$s+2) > $ComplexArtifact__THRESHOLD) {
    return 1;
  }
  else {
    return 0;
  }
}

sub CheckLongArtifact($$) 
{
  my $artifact = shift;
  my $ArtifactsView = shift ;
  my $name = GetName($artifact) ;

  my $content = $ArtifactsView->{$name};

  if (! defined $content) {
    print "WARNING : no content for $name\n" if ($DEBUG);
    return 0;
  }

  if ( scalar ( () = $content =~ /(\n)/sg ) > $MAX_ARTIFACT_LINE_THRESHOLD ) {

    return 1;
  }
  else {
    return 0;
  }

}

1;



