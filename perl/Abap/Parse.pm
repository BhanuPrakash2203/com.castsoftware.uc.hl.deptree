package Abap::Parse;
# les modules importes
use strict;
use warnings;
#use diagnostics; #FIXME: est-ce compatible Strawberry?
#no warnings 'recursion'; 

use Erreurs;

use CountUtil;

use Lib::Node;

use Abap::AbapNode ;
use Abap::AbapNode qw( SetName SetStatement SetLine GetLine); 

#use Abap::Identifier;

# prototypes publics
sub Parse($$$$);
sub parseForm();
sub parseEndForm();
sub parseFunction();
sub parseEndFunction();
sub parseMethod();
sub parseEndMethod();

sub isNextForm();
sub isNextEndForm();
sub isNextFunction();
sub isNextEndFunction();
sub isNextMethod();
sub isNextEndMethod();
sub isNextElse();


my $DEBUG=0;

my $IDENTIFIER='\w';

my $NullString = '';

my $MODULE_DEFINED = 0;

my @conditionContent = (#\&parseSelect, \&parseQueryOp
                       ) ;
my @SQLContent = (#\&parseSelect, \&parseQueryOp
                 ) ;
my @selectContent = (#\&parseSelect, \&parseQueryOp
                    ) ;

my @procedureContent = (#\&parseEnd, \&parseGo, \&parseLabel,\&parseBegin, \&parseDeclare, \&parseFetch, \&parseCreate, @selectContent, \&parseAlter, \&parseDrop, \&parseSQL, \&parseWhile, \&parseIf, \&parseReturn, \&parseBeginTran, \&parseCommitTran, \&parseRollbackTran, \&parseBeginTry, \&parseBeginCatch, \&parseEndTry, \&parseEndCatch
                        );
my @rootContent = ( \&parseSection, \&parseForm, \&parseFunction, \&parseMethod,
                    \&parseDo, \&parseLoop, \&parseAt, \&parseWhile, \&parseProvide, \&parseTry, \&parseCatch, \&parseCase, \&parseModule, \&parseIf,
                    \&parseSelect, \&parseEndSelect, \&parseEndCatch, \&parseOpenSQL, \&parseWhen,
                    \&parseWhenOther, \&parseOpenDataset, 
                    \&parseRead, \&parseOpenCursor, \&parseFetchNextCursor, \&parseCheck, \&parseAuthorityCheck, \&parseExit, \&parseCleanup, \&parseClass, \&parseExecSql );

my @container = ('root');

##################################################################
#              UNIQ DEFAULT DATA
##################################################################

my $UNIQ_ID = 0;

sub getUniqID() {
  return $UNIQ_ID++;
}

##################################################################
#               ARTIFACT BUFFER Management
##################################################################

my %H_ARTIFACTS_BUFFER = ();
my %CURRENT_ARTIFACTS = ();

sub newArtifact($) {
  my $name = shift;
  my $line = shift;
  my $key = buildArtifactKeyByData($name,$line);
  $H_ARTIFACTS_BUFFER{$key} = "";
  $CURRENT_ARTIFACTS{$key} = \$H_ARTIFACTS_BUFFER{$key};
}

sub beginArtifact($) {
  my $key = shift;
  $CURRENT_ARTIFACTS{$key} = \$H_ARTIFACTS_BUFFER{$key};
}

sub endArtifact($) {
  my $name = shift;
  if (exists $CURRENT_ARTIFACTS{$name}) {
    $CURRENT_ARTIFACTS{$name} = undef;
    delete $CURRENT_ARTIFACTS{$name};
  }
  else {
    print "PARSE ERROR : no $name artifact.\n";
  }
}

#--------------------------------------------------------------------------------------
# WARNING:
# Since newArtifact needs a "line" parameter, its call in the following function can not
# be adapted whithout redesigning the whole function (the $line info is not avalaible
# in it).
#--------------------------------------------------------------------------------------

#sub pushArtifact($$) {
#  my $r_tab = shift;
#  my $artifact = shift;
#
#  if (scalar @{$r_tab} > 0) {
#    # Deactivate bufferisation of the previous artifact (the last of the list)
#    endArtifact($r_tab->[-1]);
#  }
#  # The new select artifact becomes the new buffered active one.
#  push(@{$r_tab}, $artifact);
#  newArtifact($artifact);
##print "activate $artifact\n";
#}


# This function is unused, and could not be because pushArtifact is no more available ...

sub popArtifact($$) {
  my $r_tab = shift;
  my $key = shift;

  endArtifact($key);
#print "end of ".$r_tab->[-1]."\n";
  # remove the select from the list.
  pop @{$r_tab};
  if (scalar @{$r_tab} > 0) {
    # re-activate the previous select (the last of the list)
#print "reactivate ".$r_tab->[-1]."\n";
    beginArtifact($r_tab->[-1]);
  }
}

my $SQL_ID = 0;
my @CURRENT_SQL_ARTIFACT = ();
my $UNNAMED_ROUTINE_ID = 0;

##################################################################
#              STATEMENTS MANAGEMENT
##################################################################
my $r_statements = ();
my $idx_statement = 0;
my $moreStatements = 1;
my $lastInstrLine = 1; # line of the last statement returned
my $nextInstrLine = 1;

sub getStatementLine() {
  return $lastInstrLine ;
}

# Return the line of the next statement. This is the effective line where
# the instruction is, unless the statement buffer contains empty line before.
sub getNextStatementLine() {
  return $nextInstrLine ;
}

sub skipBlankAndSeparators() {
  my $blank = "";
  while ( ($idx_statement < scalar @{$r_statements}) &&
	  ( $r_statements->[$idx_statement] =~ /^[\n\s\.]*$/ ) ){
    $blank .= $r_statements->[$idx_statement] ;
    $idx_statement++;
  }
  return \$blank;
}


sub initStatementManager() {

  # Initial values ...
  $idx_statement = 0;
  $moreStatements = 1;
  $lastInstrLine = 1; # line of the last statement returned
  $nextInstrLine = 1;

  # Seek to next statement non blank ...
  my $skippedBlanks = skipBlankAndSeparators();
  if ( $idx_statement == scalar @$r_statements ) {
    $moreStatements = 0;
  }
  $nextInstrLine += () = $$skippedBlanks =~ /\n/sg ;
}


# Consume the next statement in the list and return a reference on it.
sub getNextStatement() {
if (! $moreStatements) {
  print "ERRONEOUS call to getNextSatement() !!!\n";
  return \"";
}
  my $statement = $r_statements->[$idx_statement++];
  my $skippedBlanks = skipBlankAndSeparators();
  if ( $idx_statement == scalar @$r_statements ) {
    $moreStatements = 0;
  }

print "-----------------------------------------\n" if ( $DEBUG);
print "USING : $statement\n" if ( $DEBUG);

  # If the code belong to an artifact, then the statement is concatened to
  # the corresponding buffer. %CURRENT_ARTIFACTS contains the list of buffer associated to
  # each artifact actualy being parsed and registered to record statements ...
  for my $artifact (keys %CURRENT_ARTIFACTS) {
    ${$CURRENT_ARTIFACTS{$artifact}} .= ' ' . $statement . $$skippedBlanks; 
  }

  $lastInstrLine = $nextInstrLine;
  # Add blanks that are before the statements ...
  my ($blanksBeforeStatement, $stat) = $statement =~ /^([\n\s]*)(.*)/sg ;
  $lastInstrLine += () = $blanksBeforeStatement =~ /\n/sg ; 

  $nextInstrLine += () = $statement =~ /\n/sg ;
  $nextInstrLine += () = $$skippedBlanks =~ /\n/sg ;
  return \$statement;
}

# return the a reference to the next statement without consuming it from the list.
sub nextStatement(;$) {
  my ( $idx ) = @_ ;
  if (!defined $idx) { $idx = 0;}
  $idx += $idx_statement;
   if ( $idx < scalar @$r_statements) {
     return \$r_statements->[$idx];
   }
   else {
     return undef;
   }
}

# insert elements at the specified position (current position by default).
sub insertStatements($@) {
  my ($idx, @elements) = @_;

  if (!defined $idx) {
    $idx = $idx_statement;
  }

  splice (@$r_statements, $idx, 0, @elements);
  return;
}

# Replace the current element with a given list of new elements.
sub replaceSplitStatement($$$) {
  my ($idx, $r_split1, $r_split2) = @_;

  splice (@$r_statements, $idx, 1, $$r_split1, $$r_split2);
  return;
}

# Use a given pattern to split the next statement in two parts, with
# the pattern between them.
sub splitNextStatementOnPattern($;$) {
  my ($pattern, $KeepPattern) = @_ ;

  if (! defined $KeepPattern) {
    $KeepPattern = 1;
  }

  ${nextStatement()} =~ /(.*?)(${pattern})(.*)/smi ;
  if (defined $2) {
    my @list = ();
#    if ( $1 !~ /^[\n\s]*$/ ) { 
      push @list, $1;
#    }

    if ($KeepPattern) { push @list, $2; }

#    if ( $3 !~ /^[\n\s]*$/ ) { 
      push @list, $3;
#    }

    splice (@$r_statements, $idx_statement, 1, @list);
  }
}


sub splitNextStatementOnExtraClosingParenthesis($) {
  my $solde = shift;
  my $before = "";
  my $after = "";
  my $current = \$before;

#print "[splitNextStatementOnExtraClosingParenthesis] ENTREE...\n";
  if ( ${nextStatement()} =~ /\)/ ) {
    my $s = ${nextStatement()};
    while ($s =~ /([^\(\)]*)([\(\)]|$)/sg ) {

      if ($current == \$after) {
        $$current .= $1.$2;
      } 
      elsif ( $2 eq '(' ) {
        $solde++;
        $$current .= $1.$2;
      }
      elsif ( $2 eq ')' ) {
        $$current .= $1; 
        if ( $solde > 0) {
          $$current .= $2; 
        }
        else {
          $current = \$after;
          $$current .= $2;
        }
        $solde--;
      }
      else {
        $$current.= $1.$2;
      }
    }
#    if (( $before !~ /^[\s\n]*$/ ) && ($after !~ /^[\s\n]*$/ )) {
#print "Part__ 1 : $before\n";
#print "Part__ 2 : $after\n";
#      splice (@$r_statements, $idx_statement, 1, $before, $after);
#    }

    #if $after is empty, then no closing parenthesis has been found, then no need to spleet ...
    if ($after ne "") {
      my $offset = 0;
      $after =~ s/^\)//;
      my $parenthesis = ')';

      # once ')' has been removed from after, if $before is empty and $after is empty, there is no
      # need to split.
      if (( $before !~ /^[\s\n]*$/ ) || ($after !~ /^[\s\n]*$/ )) {

      if ($before =~ /^[\s\n]*$/) {
        $parenthesis = $before.$parenthesis;
	$before = "";
      }

      if ($after =~ /^[\s\n]*$/) {
        $parenthesis = $parenthesis.$after;
	$after = "";
      }

      if ( $before ne "" ) {
	# insert statement at current index whithout removing current statement at this index.
#print "Part 1 : $before\n"; 
        splice (@$r_statements, $idx_statement, 0, $before);
        $offset++;
      }

      # replace current statement with the parenthesis pattern.
      splice (@$r_statements, $idx_statement+$offset, 1, $parenthesis);
#print "Part ". (1+$offset)." : $parenthesis\n"; 
      $offset++;

      if ( $after ne "" ) {
	# insert statement after current index.
        splice (@$r_statements, $idx_statement+$offset, 0, $after);
#print "Part ". (1+$offset)." : $after\n"; 
      }
      }
    }
  }
}


#-----------------------------------------------------------------
# Description : Automatise a try sequence of parse routines.
#
#  - If one routines matches, return the node resulting from the parsing.
#  - If none routine matche, a UnknowKind node is returned
#    parameter) the undef value is returned.
#-----------------------------------------------------------------

sub tryParse_OrUnknow($) {
  my ($r_try_list)  = @_ ;

  return tryParse($r_try_list, 1);
}

#-----------------------------------------------------------------
# Description : Automatise a try sequence of parse routines.
#
#  - If one routines matches, return the node resulting from the parsing.
#  - If none routine matche, undef is returned.
#-----------------------------------------------------------------
sub tryParse($;$) {
  my ($r_try_list, $mode) = @_ ;


    if ( ! $moreStatements ) {
print "ERROR : tryParse called while no more statement\n";
    }

    # Else statement should only be encountered in a "if' context. An "else" statement should never
    # be encountered here ...
    if (isNextElse() ) {
      print "PARSE error : unexpected Else ...\n";
    }

  my $node;
  for my $callback ( @$r_try_list ) {
 
    # If a previous parse callback returns undef while the end of the statement
    # list has been encountered, the iteration must end. A unknow node will
    # then be returned. 
    if ( ! $moreStatements ) {
      last;
    }

    if ( defined ($node = $callback->() )) {
      return $node;
    }
  }

  # if statement does not correspond to the expected list :
  #
  # MODE 2:
  # if "unless known_mode" is active and the next statement is effectively a known "new" instruction 
  # (that is, it can not be a part of the previous instruction), undef is return, else a unknow mode
  # will be returned (by activating MODE 1!!)
  #if ( defined $mode && ($mode==2)) {
  #   if ( isNextKnown() ) {
  #     return undef;
  #   }
  #   else {
  #     $mode =1;
  #   }
  #}

  # MODE 1 :
  # The statement is considered unknow => an unknow node is returned
  if (defined $mode && ($mode==1)) {
    $node = Node(UnknowKind, getNextStatement());
print "+++ UNRECOGNIZED ...\n" if ($DEBUG);
    return $node ;
  }

  # by default, undef is returned.
  return undef;
}


sub InitParser() {
  %H_ARTIFACTS_BUFFER = ();
  %CURRENT_ARTIFACTS = ();

  $UNIQ_ID = 0;

  $SQL_ID = 0;
  @CURRENT_SQL_ARTIFACT = ();
  $UNNAMED_ROUTINE_ID = 0;

  initStatementManager();

}

##################################################################
#              EXIT
#################################################################

sub isNextExit() {
   if ( ${nextStatement()} =~ /\A\s*exit\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseExit($$$) {
  if (isNextExit()) {

    my $Node = Node( ExitKind, getNextStatement());

    SetLine($Node, getStatementLine());

    my $name = "EXIT_".getUniqID();
    SetName($Node, $name);

    return $Node;
  }
  else {
     return undef;
   }
}

##################################################################
#              CLEANUP
#################################################################

sub isNextCleanup() {
   if ( ${nextStatement()} =~ /\A\s*cleanup\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseCleanup($$$) {
  if (isNextCleanup()) {

    my $CleanupNode = Node(CleanupKind, getNextStatement());

    SetLine($CleanupNode, getStatementLine());

    SetName($CleanupNode, "");
    while ($moreStatements && 
         !(isNextCatch() | isNextCleanup() | isNextEndTry() )) {

      my $node = tryParse_OrUnknow(\@rootContent);
      Append($CleanupNode, $node);
    }

    if (! $moreStatements) {
      print STDERR "ERROR : unterminated TRY/CATCH.\n";
    }
    return $CleanupNode;
  }
  else {
    return undef;
   }
}

##################################################################
#              CATCH
##################################################################

sub isNextCatch() {
   if ( ${nextStatement()} =~ /\A\s*catch\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseCatch($$) {

  if (isNextCatch() ) {
    my $CatchNode = Node( CatchKind, getNextStatement());

    SetLine($CatchNode, getStatementLine());
    SetName($CatchNode, "");
    while ($moreStatements && 
         !(isNextCatch() | isNextEndCatch() | isNextCleanup() | isNextEndTry() )) {

      my $node = tryParse_OrUnknow(\@rootContent);
      Append($CatchNode, $node);
    }

    if (! $moreStatements) {
      print STDERR "ERROR : unterminated TRY/CATCH.\n";
    }
    return $CatchNode;
  }
  else {
    return undef;
  }
}

sub isNextEndCatch() {
   if ( ${nextStatement()} =~ /\A\s*endcatch\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseEndCatch($$$) {
  if (isNextEndCatch()) {

    my $Node = Node( EndCatchKind, getNextStatement());

    SetLine($Node, getStatementLine());

    my $name = "END_CATCH_".getUniqID();
    SetName($Node, $name);

    return $Node;
  }
  else {
     return undef;
   }
}

##################################################################
#              EXEC SQL
##################################################################

sub isNextExecSql() {
   if ( ${nextStatement()} =~ /\A\s*exec\s+sql\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseExecSql($$) {

  if (isNextExecSql() ) {
    my $ExecSqlNode = Node( ExecSqlKind, getNextStatement());

    SetLine($ExecSqlNode, getStatementLine());
    SetName($ExecSqlNode, "");
    while ($moreStatements && 
         !(isNextEndExec() )) {

	 # trash the instruction found....
	 getNextStatement();
    }

    if (! $moreStatements) {
      print STDERR "ERROR : unterminated EXEC SQL.\n";
    }
    return $ExecSqlNode;
  }
  else {
    return undef;
  }
}

sub isNextEndExec() {
   # endexec is recognized at the end of the statement, and not mandatorily
   # at beginning. Indeed, content of the EXE ... ENDEXEC is not nessarily ended
   # with a ".". So, due to the split of the ABAP parser, the endexec statement
   # will often be concatened with the last instruction of the EXEC block if it 
   # don't terminate with a "."
   if ( ${nextStatement()} =~ /\bendexec\b\s*\Z/si ) {
     return 1;
   }
   return 0;
}

sub parseEndExec($$$) {
  if (isNextEndExec()) {

    my $Node = Node( EndExecKind, getNextStatement());

    SetLine($Node, getStatementLine());

    my $name = "END_EXEC_".getUniqID();
    SetName($Node, $name);

    return $Node;
  }
  else {
     return undef;
   }
}


##################################################################
#              WHEN / WHEN OTHER
##################################################################

sub parseGenericWhenOther($$) {
  my $kind = shift;
  my $WhenNode = shift;

  SetLine($WhenNode, getStatementLine());

  SetName($WhenNode, "");

  while ($moreStatements && 
         !(isNextWhen() | isNextWhenOther() | isNextEndCase())) {

    my $node = tryParse_OrUnknow(\@rootContent);
    Append($WhenNode, $node);
  }

  if (! $moreStatements) {
    print STDERR "ERROR : unterminated CASE.\n";
  }

  return $WhenNode;
}


sub isNextWhenOther() {
   if ( ${nextStatement()} =~ /\A\s*when\s+others\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}


sub isNextWhen() {
   if ( (! isNextWhenOther()) && (${nextStatement()} =~ /\A\s*when\b(?:[^\-]|\Z)/si) ) {
     return 1;
   }
   return 0;
}

sub parseWhen() {

  if (isNextWhen() ) {
    my $Node = Node( WhenKind, getNextStatement());

    return parseGenericWhenOther(WhenKind, $Node);
  }
  else {
    return undef;
  }
}

sub parseWhenOther() {

  if (isNextWhenOther() ) {
    my $Node = Node( WhenOtherKind, getNextStatement());

    return parseGenericWhenOther(WhenOtherKind, $Node);
  }
  else {
    return undef;
  }
}

##################################################################
#              CHECK
#################################################################

sub isNextCheck() {
   if ( ${nextStatement()} =~ /\A\s*check\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseCheck($$$) {
  if (isNextCheck()) {

    my $Node = Node( CheckKind, getNextStatement());

    SetLine($Node, getStatementLine());

    my $name = "CHECK_".getUniqID();
    SetName($Node, $name);

    return $Node;
  }
  else {
     return undef;
   }
}
##################################################################
#              OPEN CURSOR
#################################################################

sub isNextOpenCursor() {
   if ( ${nextStatement()} =~ /\A\s*open\s+cursor\b/si ) {
     return 1;
   }
   return 0;
}

sub parseOpenCursor($$$) {
  if (isNextOpenCursor()) {


    my $Node = Node( OpenCursorKind, \$NullString);

    SetLine($Node, getStatementLine());

    my $name = "OPEN_CURSOR_".getUniqID();
    SetName($Node, $name);

    my $stmt = getNextStatement();

    my @parts = split /for/i, $$stmt;

    my @insertList = ();
    for my $part (@parts) {
      if ( $part =~ /\bselect\b/i ) {
	# remove next cursor name in case of factorised open cursor instruction,
	# where each declaration is separated with a coma ...
	# example : 
        #    OPEN CURSOR : c1 FOR SELECT newsletter_name FROM znewsletter 
        #                       where newsletter_email = 'BOB@email.com',
	#                  c2 FOR SELECT newsletter_name newsletter_comp from znewsletter 
	#      where newsletter_comp = 'SAPCONSULTING'.
	# 
        $part =~ s/,\s*[\w~\^]+\Z//is;
	
	push @insertList, $part;
      }
    }
    my $nb_inserted = scalar @insertList;
    insertStatements(undef, @insertList );

    for (my $i=0; $i<$nb_inserted; $i++) {
      my $SubNode = tryParse_OrUnknow(\@rootContent);
      Append($Node, $SubNode);
    }

    return $Node;
  }
  else {
     return undef;
   }
}

##################################################################
#              FETCH NEXT CURSOR
#################################################################

sub isNextFetchNextCursor() {
   if ( ${nextStatement()} =~ /\A\s*fetch\s+next\s+cursor\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseFetchNextCursor($$$) {
  if (isNextFetchNextCursor()) {

    my $Node = Node( FetchNextCursorKind, getNextStatement());

    SetLine($Node, getStatementLine());

    my $name = "FETCH_NEXT_CURSOR_".getUniqID();
    SetName($Node, $name);

    return $Node;
  }
  else {
     return undef;
   }
}

##################################################################
#              OPEN DATASET
#################################################################

sub isNextOpenDataset() {
   if ( ${nextStatement()} =~ /\A\s*open\s+dataset\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseOpenDataset($$$) {
  if (isNextOpenDataset()) {

    my $Node = Node( OpenDatasetKind, getNextStatement());

    SetLine($Node, getStatementLine());

    my $name = "OPEN_DATASET_".getUniqID();
    SetName($Node, $name);

    return $Node;
  }
  else {
     return undef;
   }
}

##################################################################
#              READ DATASET
#################################################################

#sub isNextReadDataset() {
#   if ( ${nextStatement()} =~ /\A\s*read\s+dataset\b/si ) {
#     return 1;
#   }
#   return 0;
#}

#sub parseReadDataset($$$) {
#  if (isNextReadDataset()) {
#
#    my $Node = Node( ReadDatasetKind, getNextStatement());
#
#    SetLine($Node, getStatementLine());
#
#    my $name = "READ_DATASET_".getUniqID();
#    SetName($Node, $name);
#
#    return $Node;
#  }
#  else {
#     return undef;
#   }
#}

##################################################################
#              READ
#################################################################

sub isNextRead() {
   #if ( (! isNextReadDataset()) && (${nextStatement()} =~ /\A\s*read\b/si) ) {
   if ( ${nextStatement()} =~ /\A\s*read\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseRead($$$) {
  if (isNextRead()) {

    my $Node = Node( ReadKind, getNextStatement());

    SetLine($Node, getStatementLine());

    my $name = "READ_".getUniqID();
    SetName($Node, $name);

    return $Node;
  }
  else {
     return undef;
   }
}


##################################################################
#              AUTHORITY-CHECK
#################################################################

sub isNextAuthorityCheck() {
   if ( ${nextStatement()} =~ /\A\s*authority-check\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseAuthorityCheck($$$) {
  if (isNextAuthorityCheck()) {

    my $Node = Node( AuthorityCheckKind, getNextStatement());

    SetLine($Node, getStatementLine());

    my $name = "AUTHORITY_CHECK_".getUniqID();
    SetName($Node, $name);

    return $Node;
  }
  else {
     return undef;
   }
}


##################################################################
#              OPEN SQL
#################################################################

my %H_OpenSqlKind = ( 'insert' => InsertKind(),
	              'delete' => DeleteKind(),
	              'update' => UpdateKind(),
	              'modify' => ModifyKind() );

sub isNextOpenSQL() {
   if ( ${nextStatement()} =~ /\A\s*(insert|delete|update|modify)\b(?:[^\-]|\Z)/si ) {
     return lc($1);
   }
   return 0;
}

sub parseOpenSQL($$) {

  my $OpenSql = isNextOpenSQL();
  if ( $OpenSql ) {
    my $OSqlNode = Node( $H_OpenSqlKind{$OpenSql}, getNextStatement());

    SetLine($OSqlNode, getStatementLine());
    SetName($OSqlNode, "");

    parseNestedSelect($OSqlNode);

  return $OSqlNode;
  }
  else {
    return undef;
  }
}


##################################################################
#              Sub Query
#################################################################

sub parseNestedSelect($);

sub parseNestedSelect($) {
  my $node = shift;
  my $stmt = GetStatement($node);

  if ( $$stmt =~ /(.*?)(\(select.*)/si ) {
    my $stmt1=$1;
    my $stmt2=$2;
    my ($nestedSelect, $rest) = CountUtil::splitAtPeer(\$stmt2, '(', ')');

    if ( ! defined $nestedSelect ) {
      return $node;
    }
    # Remove parenthesis wrapping the nested select statement ...
    $$nestedSelect =~ s/^\(//;
    $$nestedSelect =~ s/\)$//;

    # Create a Subquery Node containing the nested Select ....
    #--------------------------------------------------------
    my $SubqueryNode = Node(SubqueryKind, \$NullString);
    my $NestedSelectNode = Node( SelectKind, $nestedSelect);
    Append($SubqueryNode, $NestedSelectNode);

    SetLine($NestedSelectNode, GetLine($node));
    my $name = "SELECT_".getUniqID();
    SetName($NestedSelectNode, $name);
    parseNestedSelect($NestedSelectNode);

    # replace the nested select by its name in the parent statement.
    #--------------------------------------------------------
    $$stmt = $stmt1.'( '.$name.' )'.$$rest;
    SetStatement($node, $stmt);

    # Append the Dynamic node to the parent node
    #--------------------------------------------------------
    Append($node, $SubqueryNode);
  }
}

##################################################################
#              SELECT
#################################################################

sub isNextSelect() {
   if ( ${nextStatement()} =~ /\A\s*select\b(?:[^\-]|\Z)/si )  {
     # If the statement conatins the ENDEXEC instruction, then it is a native SQL select ...
     if ( ${nextStatement()} !~ /\bendexec\b(?:[^\-]|\Z)/si )  {
       return 1;
     }
   }
   return 0;
}

sub parseSelect($$$) {
  if (isNextSelect()) {

    my $Node = Node( SelectKind, getNextStatement());

    SetLine($Node, getStatementLine());

    my $name = "SELECT_".getUniqID();
    SetName($Node, $name);

    parseNestedSelect($Node);

    return $Node;
  }
  else {
     return undef;
   }
}

sub isNextEndSelect() {
   if ( ${nextStatement()} =~ /\A\s*endselect\b(?:[^\-]|\Z)/si )  {
     return 1;
   }
   return 0;
}

sub parseEndSelect($$$) {
  if (isNextEndSelect()) {

    my $Node = Node( EndSelectKind, getNextStatement());

    SetLine($Node, getStatementLine());

    my $name = "END_SELECT_".getUniqID();
    SetName($Node, $name);

    return $Node;
  }
  else {
     return undef;
   }
}


##################################################################
#              Generic end-terminated artifact
#################################################################
sub parseBlock($$$$) {
  my ($parent, $r_tab_StatementContent, $typeBegin, $parseEnd_callback) = @_;
  my $node;

print "+++ Debut de bloc $typeBegin\n" if ($DEBUG);
  while ($moreStatements) {

    if ( defined ($node = $parseEnd_callback->())) {
      Append($parent, $node);
print "+++ FIN block $typeBegin  : ".GetName($parent)."\n" if ($DEBUG);
      return $parent;
    }
    else {
      $node = tryParse_OrUnknow($r_tab_StatementContent);
      Append($parent, $node);
    }
  }
  print "PARSE error : unterminated ".$parent->[0]." block $typeBegin!!! \n";
  #exit;
  return $parent;
}



##################################################################
#              SECTION
#################################################################

sub isNextSection() {
   if ( ${nextStatement()} !~ /\A\s*GET\s+(?:BIT|BADI|CONNECTION|CURSOR|DATASET|LOCALE|PARAMETER|PF-STATUS|PROPERTY|REFERENCE|RUN\s+TIME|TIME\s+STAMP)\b/) {

     if ( ${nextStatement()} =~ /\A\s*(initialization|START-OF-SELECTION|END-OF-SELECTION|AT\s+(?:LINE-SELECTION|SELECTION-SCREEN|USER-COMMAND|PF\d\d)|TOP-OF-PAGE|END-OF-PAGE|PROCESS)\b(?:[^\-]|\Z)/si )  {
       return 1;
     }
   }
   return 0;
}

sub parseSection($$$) {

   if (isNextSection()) {

     my $SectionNode = Node( SectionKind, \$NullString);

     my $stmt = getNextStatement() ;
     my ($name) = $$stmt =~ /\A\s*((:?at\s+)?[^\s]+)/is ;

     SetStatement($SectionNode, $stmt);
     my $line = getStatementLine();
     SetLine($SectionNode, $line);
     if (! defined $name) {
       $name = "SECTION_".getUniqID();
     }
     SetName($SectionNode, $name);

     my $artiKey = buildArtifactKeyByData($name,$line);
     newArtifact($artiKey);

     while ( $moreStatements &&
             (! isNextForm()) &&
             (! isNextFunction()) &&
             (! isNextMethod()) &&
             (! isNextModule()) &&
             (! isNextSection())
	   ) {
       
       my $node = tryParse_OrUnknow(\@rootContent);
       Append($SectionNode, $node);
     }

     endArtifact($artiKey);

     return $SectionNode;
   }
   else {
     return undef;
   }
}



##################################################################
#              ROUTINE
#################################################################

sub parseRoutine($$$) {

   my ($type, $keyword, $endcallback) = @_ ;

     my $Node = Node( $type, \$NullString);

     my $stmt = getNextStatement() ;
     my ($name) = $$stmt =~ /\b$keyword\s+($IDENTIFIER*)/is ;

     SetStatement($Node, $stmt);
     my $line = getStatementLine();
     SetLine($Node, $line);
     if (! defined $name) {
       $name = "ROUTINE_".getUniqID();
     }
     SetName($Node, $name);

     my $artiKey = buildArtifactKeyByData($name,$line);
     newArtifact($artiKey);

     $Node = parseBlock($Node, \@rootContent, $type, $endcallback) ;

     endArtifact($artiKey);

     return $Node;
}


##################################################################
#              CONTROL STRUCTURES
##################################################################

my %H_BeginStructKeyword = (
       	DoKind() => 'do', 	EndDoKind() => 'enddo',
       	LoopKind() => 'loop', 	EndLoopKind() => 'endloop', 
       	AtKind() => 'at', 	EndAtKind() => 'endat', 
       	WhileKind() => 'while', EndWhileKind() => 'endwhile',
       	ProvideKind() => 'provide', EndProvideKind() => 'endProvide',
       	TryKind() => 'try', 	EndTryKind() => 'endtry',
       	CaseKind() => 'case', 	EndCaseKind() => 'endcase',
       	ClassKind() => 'class\b[^\-](?:.*)\bimplementation', 	EndClassKind() => 'endclass',
	);

my %H_EndCallback = ( 
	DoKind() => \&parseEndDo,
	LoopKind() => \&parseEndLoop,
	AtKind() => \&parseEndAt,
	WhileKind() => \&parseEndWhile,
	ProvideKind() => \&parseEndProvide,
	TryKind() => \&parseEndTry,
	CaseKind() => \&parseEndCase,
	ClassKind() => \&parseEndClass,
        );

my %H_GetName = (
	ClassKind() => \&getClassName,
);

sub isNextGenericStruct($) {
   my $type = shift;
   my $keyword = $H_BeginStructKeyword{$type};
   if ( ${nextStatement()} =~ /\A\s*$keyword\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseGenericStruct($) {
   my $type = shift;
   if (isNextGenericStruct($type) ) {
     my $Node = Node( $type, \$NullString);
     
     my $r_stmt = getNextStatement();
     SetStatement($Node, $r_stmt );
     SetLine($Node, getStatementLine());

     my $name = "";
     if ( exists $H_GetName{$type} && defined $H_GetName{$type} ) {
       $name = $H_GetName{$type}->($r_stmt);
     }
     else {
       $name = "STRUCT_".getUniqID();
     }
     SetName($Node, $name);
     return parseBlock($Node, \@rootContent, $type, $H_EndCallback{$type}) ;
   }
   else {
     return undef;
   }
}

sub parseGenericEndStruct($) {
   my $type = shift;
   if (isNextGenericStruct($type) ) {
     my $Node = Node( $type, \$NullString);
     
     SetStatement($Node, getNextStatement());
     SetLine($Node, getStatementLine());

     return $Node;
   }
   else {
     return undef;
   }
}

sub isNextDo() { return isNextGenericStruct(DoKind); }
sub parseDo() { return parseGenericStruct(DoKind); }
sub isNextEndDo() { return isNextGenericStruct(EndDoKind); }
sub parseEndDo() { return parseGenericEndStruct(EndDoKind); }

sub isNextLoop() { return isNextGenericStruct(LoopKind); }
sub parseLoop() { return parseGenericStruct(LoopKind); }
sub isNextEndLoop() { return isNextGenericStruct(EndLoopKind); }
sub parseEndLoop() { return parseGenericEndStruct(EndLoopKind); }

sub isNextWhile() { return isNextGenericStruct(WhileKind); }
sub parseWhile() { return parseGenericStruct(WhileKind); }
sub isNextEndWhile() { return isNextGenericStruct(EndWhileKind); }
sub parseEndWhile() { return parseGenericEndStruct(EndWhileKind); }

sub isNextProvide() { return isNextGenericStruct(ProvideKind); }
sub parseProvide() { return parseGenericStruct(ProvideKind); }
sub isNextEndProvide() { return isNextGenericStruct(EndProvideKind); }
sub parseEndProvide() { return parseGenericEndStruct(EndProvideKind); }

sub isNextTry() { return isNextGenericStruct(TryKind); }
sub parseTry() { return parseGenericStruct(TryKind); }
sub isNextEndTry() { return isNextGenericStruct(EndTryKind); }
sub parseEndTry() { return parseGenericEndStruct(EndTryKind); }

sub isNextCase() { return isNextGenericStruct(CaseKind); }
sub parseCase() { return parseGenericStruct(CaseKind); }
sub isNextEndCase() { return isNextGenericStruct(EndCaseKind); }
sub parseEndCase() { return parseGenericEndStruct(EndCaseKind); }

# Some event section (like AT USER-COMMAND) name begins with AT but are 
# not relevant from the AT ... ENDAT structure.
sub isNextAt() { return (isNextGenericStruct(AtKind) && (!isNextSection())); }
sub parseAt() { return parseGenericStruct(AtKind); }
sub isNextEndAt() { return isNextGenericStruct(EndAtKind); }
sub parseEndAt() { return parseGenericEndStruct(EndAtKind); }

sub isNextClass() { return isNextGenericStruct(ClassKind); }
sub parseClass() { return parseGenericStruct(ClassKind); }
sub isNextEndClass() { return isNextGenericStruct(EndClassKind); }
sub parseEndClass() { return parseGenericEndStruct(EndClassKind); }
sub getClassName($) {
  my $r_instr = shift;
  if ( $$r_instr =~ /\bclass\s+(\w+)/si) {
    return $1;
  }
  else {
     return "CLASS_".getUniqID();
  }
}



##################################################################
#              IF / ELSEIF
##################################################################
sub isNextIf() {
   if ( ${nextStatement()} =~ /\A\s*if\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub isNextElseif() {
   if ( ${nextStatement()} =~ /\A\s*elseif\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub isNextElse() {
   if ( ${nextStatement()} =~ /\A\s*else\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub isNextEndIf() {
   if ( ${nextStatement()} =~ /\A\s*endif\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}
sub parseIf() {

   if (isNextIf() ) {
     my $IfNode = Node(IfKind, getNextStatement());
     SetLine($IfNode, getStatementLine());
     my $StructID = getUniqID();
     SetName($IfNode, "IF_".$StructID);
print "+++ IF ...\n" if ($DEBUG);

     # Create a virtual Then ...
     my $PartNode = Node(ThenKind, \$NullString);
     SetLine($PartNode, getStatementLine());
     SetName($PartNode, "THEN_".$StructID);
     Append($IfNode, $PartNode);
	
     while ( $moreStatements ) {

       # ELSEIF ...
       if ( isNextElseif()) {
         $PartNode = Node(ElsifKind, getNextStatement());
         SetLine($PartNode, getStatementLine());
         SetName($PartNode, "ELSEIF_".$StructID);
         Append($IfNode, $PartNode);
       }
       # ELSE ...
       elsif ( isNextElse()) {
         $PartNode = Node(ElseKind, getNextStatement());
         SetLine($PartNode, getStatementLine());
         SetName($PartNode, "ELSE_".$StructID);
         Append($IfNode, $PartNode);
       }
       # ENDIF ==> quit the IF pasing !
       elsif ( isNextEndIf()) {
         $PartNode = Node(EndIfKind, getNextStatement());
         SetLine($PartNode, getStatementLine());
         SetName($PartNode, "ENDIF_".$StructID);
         Append($IfNode, $PartNode);
	 return $IfNode;
       }
       else {
	 # Add the next instruction to the current part of the IF ...
         Append($PartNode, tryParse_OrUnknow(\@rootContent))
       }
     }

     # At this step, the end of statement has been encountered, whereas end of
     # the IF is still expected ...
     print "PARSE error : unterminated if !!! \n";
     return $IfNode;
   }
   else {
     return undef;
   }
}


sub parseEndIf() {

   if (isNextEndIf() ) {
	   return undef;#return parseRoutine(FormKind, "form", \&parseEndForm);
   }
   else {
     return undef;
   }
}

##################################################################
#              FORM
##################################################################
sub isNextForm() {
   if ( ${nextStatement()} =~ /\A\s*form\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseForm() {

   if (isNextForm() ) {
     return parseRoutine(FormKind, "form", \&parseEndForm);
   }
   else {
     return undef;
   }
}
############# END FORM #########################

sub isNextEndForm() {
   if ( ${nextStatement()} =~ /\A\s*endform\b(?:[^\-]|\Z)/si ) {
      return 1;
   }
   return 0;
}

sub parseEndForm() {
   if (isNextEndForm() ) {
     getNextStatement();     # to consume the endform statement ...
     my $endFormNode = Node( EndFormKind, \$NullString); 
     return $endFormNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              MODULE
##################################################################
sub isNextModule() {
   if ( $MODULE_DEFINED ) {
     if ( ${nextStatement()} =~ /\A\s*module\b(?:[^\-]|\Z)/si ) {
       return 1;
     }
   }
   return 0;
}

sub parseModule() {

   if (isNextModule() ) {
     return parseRoutine(MethodKind, "module", \&parseEndModule);
   }
   else {
     return undef;
   }
}
############# END METHOD #########################

sub isNextEndModule() {
   if ( ${nextStatement()} =~ /\A\s*endmodule(?:[^\-]|\Z)\b/si ) {
      return 1;
   }
   return 0;
}

sub parseEndModule() {
   if (isNextEndModule() ) {
     getNextStatement();     # to consume the endmethod statement ...
     my $endModuleNode = Node( EndModuleKind, \$NullString); 
     return $endModuleNode;
   }
   else {
     return undef;
   }
}


##################################################################
#              METHOD
##################################################################
sub isNextMethod() {
   if ( ${nextStatement()} =~ /\A\s*method\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseMethod() {

   if (isNextMethod() ) {
     return parseRoutine(MethodKind, "method", \&parseEndMethod);
   }
   else {
     return undef;
   }
}
############# END METHOD #########################

sub isNextEndMethod() {
   if ( ${nextStatement()} =~ /\A\s*endmethod\b(?:[^\-]|\Z)/si ) {
      return 1;
   }
   return 0;
}

sub parseEndMethod() {
   if (isNextEndMethod() ) {
     getNextStatement();     # to consume the endmethod statement ...
     my $endMethodNode = Node( EndMethodKind, \$NullString); 
     return $endMethodNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              FUNCTION
##################################################################
sub isNextFunction() {
   if ( ${nextStatement()} =~ /\A\s*function\b(?:[^\-]|\Z)/si ) {
     return 1;
   }
   return 0;
}

sub parseFunction() {
   if (isNextFunction() ) {
     return parseRoutine(FunctionKind, "function", \&parseEndFunction);
   }
   else {
     return undef;
   }
}
############# END FUNCTION #########################

sub isNextEndFunction() {
   if ( ${nextStatement()} =~ /\A\s*endfunction\b(?:[^\-]|\Z)/si ) {
      return 1;
   }
   return 0;
}

sub parseEndFunction() {
   if (isNextEndFunction() ) {
     getNextStatement();     # to consume the endfunction statement ...
     my $endFunctionNode = Node( EndFunctionKind, \$NullString); 
     return $endFunctionNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              ROOT
#################################################################
sub parseRoot() {
  
  my $Root = Node(RootKind, \$NullString);

  my $node;
  while ($moreStatements) {
    $node = tryParse_OrUnknow(\@rootContent);
    Append($Root, $node);
  }
  return $Root;
}


# description: Abap parse module Entry point.
sub Parse($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $status = 0;

    # Check if the files defines some MODULES ...
    if ( $vue->{'code'} =~ /\bendmodule\b/i ) {
      $MODULE_DEFINED = 1;
    }
    else {
      $MODULE_DEFINED = 0;
    }

#    my $statements =  $vue->{'statements_with_blanks'} ;
     $r_statements = $vue->{'statements_with_blanks'};

# As the statement manager work with blank, the following task should be removed ...
     if (scalar @$r_statements > 0) {
     # if the last statement is a Null statement, it should be removed
     # because it is not significant.
     if ($r_statements->[-1] !~ /\S/ ) {
       pop @$r_statements ;
     }
     }
     else {
       $moreStatements = 0;
     }

     InitParser();

#     splitCompoundStatement();

#      my @statementReader = ( $statements, 0);
#

     my $rootNode = parseRoot();

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

      Lib::Node::Dump($rootNode, *STDERR, "ARCHI") if ($DEBUG);
      
        $vue->{'structured_code'} = $rootNode;

      $vue->{'artifact'} = \%H_ARTIFACTS_BUFFER;

      #TSql::ParseDetailed::ParseDetailed($vue);
      if ($DEBUG) {
      for my $key ( keys %{$vue->{'artifact'}} ) {
        print "-------- $key -----------------------------------\n";
	print  $vue->{'artifact'}->{$key}."\n";
      }
      }

	if (defined $options->{'--print-tree'}) {
		Lib::Node::Dump($rootNode, *STDERR, "ARCHI");
	}
	if (defined $options->{'--print-test-tree'}) {
		print STDERR ${Lib::Node::dumpTree($rootNode, "ARCHI")} ;
	}

    return $status;
}

1;
