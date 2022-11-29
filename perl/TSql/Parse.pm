package TSql::Parse;
# les modules importes
use strict;
use warnings;
#use diagnostics; #FIXME: est-ce compatible Strawberry?
#no warnings 'recursion'; 

use Erreurs;

use CountUtil;

use TSql::Node qw( Leaf Node Append );

use TSql::TSqlNode ;
use TSql::TSqlNode qw( SetName SetStatement SetLine GetLine); 

use TSql::ParseDetailed ;

use TSql::Identifier;

# prototypes publics
sub Parse($$$$);
sub parseProcedure();
sub parseFunction();
sub parseTrigger();
sub parseEndTry();
sub parseEndCatch();
sub parseGo();
sub parseBegin();
sub parseBeginTry();
sub parseBeginCatch();
sub parseBeginTran();
sub parseCommitTran();
sub parseRollbackTran();
sub parseDeclare();
sub parseFetch();
sub parseSelect();
sub parseQueryOp();
sub parseWhile();
sub parseReturn();
sub parseCreate();
sub parseAlter();
sub parseDrop();
sub parseSQL();
sub parseLabel();

sub isNextProcedure();
sub isNextFunction();
sub isNextTrigger();
sub isNextEnd();
sub isNextEndTry();
sub isNextEndCatch();
sub isNextGo();
sub isNextBegin();
sub isNextBeginTry();
sub isNextBeginiCatch();
sub isNextBeginTran();
sub isNextCommitTran();
sub isNextRollbackTran();
sub isNextDeclare();
sub isNextFetch();
sub isNextSelect();
sub isNextQueryOp();
sub isNextWhile();
sub isNextBreak();
sub isNextReturn();
sub isNextCreate();
sub isNextAlter();
sub isNextDrop();
sub isNextSQL_withoutSelect();
sub isNextSQL_withSelect();
sub isNextLabel();
sub parseSeparator();


my $DEBUG=0;

sub makeStringRef($) {
	my $str = shift;
	return \$str;
}

# Operators list

# Operators with two operands ...
my $BiOps = '\b(?:\+=|\-=|\*=|\/=|%=|&=|\^=|\|=|\+|\-|\*|\%|AND|OR|>=|<=|<>|!=|!<|!>|=|>|<)';

# Operators with Right-only operand ...
my $ROps = '\b(?:NOT|LIKE|IN|EXISTS|BETWEEN|ANY|SOME|ALL)\b';

# Rational expression
#
#

my @conditionContent = (\&parseSelect, \&parseQueryOp) ;
my @SQLContent = (\&parseSelect, \&parseQueryOp) ;
my @selectContent = (\&parseSelect, \&parseQueryOp) ;

my @procedureContent = (\&parseEnd, \&parseGo, \&parseLabel,\&parseBegin, \&parseDeclare, \&parseFetch, \&parseCreate, @selectContent, \&parseAlter, \&parseDrop, \&parseSQL, \&parseWhile, \&parseIf, \&parseReturn, \&parseBeginTran, \&parseCommitTran, \&parseRollbackTran, \&parseBeginTry, \&parseBeginCatch, \&parseEndTry, \&parseEndCatch, \&parseSeparator);

my @rootContent = (@procedureContent, \&parseProcedure, \&parseFunction, \&parseTrigger);

my @container = ('root');


my $Separator = Node(SeparatorKind, makeStringRef(";"));

##################################################################
#              REPLACEMENT MANAGEMENT
#               (case statement ...)
##################################################################

my %replaced_CODE = ();
my $replaced_ID=0;

##################################################################
#               ARTIFACT BUFFER Management
##################################################################

my %H_ARTIFACTS_BUFFER = ();
my %CURRENT_ARTIFACTS = ();

sub newArtifact($) {
  my $name = shift;
  $H_ARTIFACTS_BUFFER{$name} = "";
  $CURRENT_ARTIFACTS{$name} = \$H_ARTIFACTS_BUFFER{$name};
}

sub beginArtifact($) {
  my $name = shift;
  $CURRENT_ARTIFACTS{$name} = \$H_ARTIFACTS_BUFFER{$name};
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

sub pushArtifact($$) {
  my $r_tab = shift;
  my $artifact = shift;

  if (scalar @{$r_tab} > 0) {
    # Deactivate bufferisation of the previous artifact (the last of the list)
    endArtifact($r_tab->[-1]);
  }
  # The new select artifact becomes the new buffered active one.
  push(@{$r_tab}, $artifact);
  newArtifact($artifact);
#print "activate $artifact\n";
}

sub popArtifact($$) {
  my $r_tab = shift;
  my $artifact = shift;

  endArtifact($artifact);
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

sub skipBlankStatement() {
  my $blank = "";
  while ( ($idx_statement < scalar @{$r_statements}) &&
	  ( $r_statements->[$idx_statement] =~ /^[\n\s]*$/ ) ){
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
  my $skippedBlanks = skipBlankStatement();
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
  my $skippedBlanks = skipBlankStatement();
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

##################################################################
#              PARSE MANAGEMENT ROUTINES
##################################################################

sub isNextKnown() {
  # Those "known" statements are in fact "structural" statements that can't belong to a 
  # SQL instruction or an another instruction.
  #
  # RQ : 1/QueryOPs are not tested here because it does not end conditions nor SQL expressions. 
  #      QueryOps terminate select expression, but only if there's no open parenthesis.
  #      2/Select is not tested here because it does not end conditions nor SQL expressions. 
  return (isNextSeparator() || isNextLabel() || isNextProcedure() || isNextFunction() || isNextTrigger() || isNextEnd() || isNextGo() || isNextBegin() || isNextDeclare() || isNextFetch() || isNextCreate() || isNextAlter() || isNextDrop() || isNextSQL_withoutSelect() || isNextSQL_withSelect() || isNextWhile() || isNextBreak() || isNextIf() || isNextReturn() || isNextElse() || isNextBeginTran() || isNextCommitTran() || isNextRollbackTran() || isNextBeginTry() || isNextBeginCatch() || isNextEndTry() || isNextEndCatch() );
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

##################################################################
#              SEPARATOR
##################################################################

sub isNextSeparator() {
   if ( ${nextStatement()} =~ /;/si ) {
      return 1;
   }
   return 0;
}

sub parseSeparator() {

#   if ( ${nextStatement()} =~ /;/si ) {
   if (isNextSeparator()) {
     getNextStatement();     # to consume the ";" statement...

     return $Separator;
   }
   else {
     return undef;
   }
}

##################################################################
#              LABEL
##################################################################

sub isNextLabel() {
   if ( ${nextStatement()} =~ /\A\s*(\w+):/si ) {
      return 1;
   }
   return 0;
}

sub parseLabel() {

#   if ( ${nextStatement()} =~ /;/si ) {
   if (isNextLabel()) {
     my ($name) = ${getNextStatement()} =~ /\A\s*(\w+):/;     # to consume the ";" statement...

     my $LabelNode = Node( LabelKind, makeStringRef("")); 
     SetName($LabelNode, $name);
     return $LabelNode;
   }
   else {
     return undef;
   }
}
##################################################################
#              CONDITION
##################################################################

sub ImpactParenthesis($) {
  my ($r_stmt) =@_;
  
  my $open_par = () = $$r_stmt =~ /\(/sg ; 
  my $close_par = () = $$r_stmt =~ /\)/sg ; 
  return $open_par - $close_par ;
}

sub ExprTerminatedWith_RvalueExpectindOp($) {
  my ($stmt) =@_;
  if ($$stmt =~ /(?:${BiOps}|${ROps})\s*$/sim ) {
    return 1;
  }
  else {
    return 0;
  }
}

sub ExprBeginningWith_LvalueExpectindOp($) {
  my ($stmt) =@_;
  if ($$stmt =~ /\A\s*${BiOps}/sim ) {
    return 1;
  }
  else {
    return 0;
  }
}

sub parseCondition() {

  my $CondNode = Node( ConditionKind, makeStringRef(''));

  my $condition_not_finished = 1;

  my $soldeParenthesis = 0;
  my $Nstat = "";
  my $Cond_Statement = "";
  my $nchild = 0;

  while ($moreStatements  && $condition_not_finished ) {

     # split on new line, keeping the "\n".
      splitNextStatementOnPattern('\n+', 1);

     my $node = tryParse(\@conditionContent);

     if ( defined $node ) {
       Append($CondNode, $node);
       $Cond_Statement .= " CHILD_${nchild}_".$node->[0]." ";
       $nchild++;
     }
     else {
       if ( isNextKnown()) {
	 # If the next instruction is known as a statement (basic or structural) that can not belong
	 # to the condition, then the condition will end.
         $condition_not_finished = 0;
       }
       else {
	 # The statement belongs to the condition ...
	 $Nstat = ${getNextStatement()};
	 $Cond_Statement .= $Nstat;
         $soldeParenthesis += ImpactParenthesis(\$Nstat);
     
         # Check criteria for the end of the condition :
         if ( ($soldeParenthesis == 0) &&
            ( ! ExprTerminatedWith_RvalueExpectindOp(\$Nstat)) &&
	    ( ! ExprBeginningWith_LvalueExpectindOp(nextStatement()) ) ) {
           $condition_not_finished = 0;
         }
       }
     }
  } 
print "CONDITION = $Cond_Statement\n" if ($DEBUG);
  SetStatement($CondNode, \$Cond_Statement);
  return $CondNode;
}

##################################################################
#               <block> END [TRY|CATCH]
##################################################################

sub parseEndTerminatedBlock($$$$) {
     my ($parent, $r_tab_StatementContent, $typeBegin, $parseEnd_callback) = @_;
     my $node;
print "+++ Debut de bloc $typeBegin\n" if ($DEBUG);
     while ($moreStatements) {

       if (isNextGo() ) {
         print "PARSE warning : unterminated ".$parent->[0]." block $typeBegin, interrupted by 'go' !!! \n";
	 return $parent;
       }

#       if ( defined ($node = parseEnd())) {
       if ( defined ($node = $parseEnd_callback->())) {
         Append($parent, $node);
print "+++ FIN Terminated block $typeBegin  : ".${GetStatement($parent)}."\n" if ($DEBUG);
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
#              WHILE
##################################################################
sub isNextElse() {
   if ( ${nextStatement()} =~ /\A\s*\belse\b/si ) {
      return 1;
   }
   return 0;
}

sub parseElse() {

   if (isNextElse()) {
     my $ElseNode = Node( ElseKind, getNextStatement()); 
     return $ElseNode;
   }
   else {
     return undef;
   }
}
sub isNextIf() {
   if ( ${nextStatement()} =~ /\A\s*\bif\b/si ) {
      return 1;
   }
   return 0;
}

sub parseIf() {

#   if ( ${nextStatement()} =~ /\A\s*\bif\b/si ) {
   if (isNextIf()) {
     getNextStatement();     # to consume the "if" statement...

     my $IfNode = Node(IfKind, makeStringRef("if"));
print "+++ If\n" if ($DEBUG);

     Append($IfNode, parseCondition());

print "+++ Fin de la condition du IF\n" if ($DEBUG);

     my $thenNode = Node(ThenKind, makeStringRef("then"));
     Append($IfNode, $thenNode);

     if ( ! $moreStatements ) {
       print "PARSE error : unterminated if (or missing first instruction) !!! \n";
       return $IfNode;
     }

     # A uniq statement is expected. If "then" contains severall instructions, then it should be
     # encapsulated in begin/end statement.
     # A "then" statement can not begin with a "else" or a "end" !!!
     if ( (! isNextElse()) && (! isNextEnd()) ) {
       Append($thenNode, tryParse_OrUnknow(\@procedureContent));

       # If the next instruction is a separator, then append it ...
       if ( $moreStatements && isNextSeparator()) {
         Append($thenNode, parseSeparator());
       }
     }
     else {
       print "WARNING : THEN without instruction ...\n";
     }

     if ($moreStatements) {
       my $elseNode = parseElse();
       if (defined $elseNode) {
         Append($IfNode, $elseNode);
         # A uniq statement is expected. If "then" contains severall instructions, then it will be
         # encapsulated in begin/end statement.
         if ( $moreStatements) {
           Append($elseNode, tryParse_OrUnknow(\@procedureContent));
         }
         else {
           print "PARSE error : unterminated else (missing first instruction) !!! \n";
         }
       }
     }
     return $IfNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              WHILE
##################################################################

sub isNextBreak() {
   if ( ${nextStatement()} =~ /\A\s*\bbreak\b/si ) {
      return 1;
   }
   return 0;
}

sub isNextWhile() {
   if ( ${nextStatement()} =~ /\A\s*\bwhile\b/si ) {
      return 1;
   }
   return 0;
}

sub parseWhile() {

#   if ( ${nextStatement()} =~ /\A\s*\bwhile\b/si ) {
   if (isNextWhile()) {
     getNextStatement();     # to consume the "while" statement...

   # Assume the next statement belong to the "while" statement. So 
   # it is not parsed for creating a new node, but is recorded as
   # a belonging to the textual statement of the "while" node ...
     my $WhileNode = Node(LoopKind, makeStringRef("while"));
print "+++ WHILE\n" if ($DEBUG);

     Append($WhileNode, parseCondition());

print "+++ Fin de la condition du WHILE\n" if ($DEBUG);

     if ( $moreStatements) {
       Append($WhileNode, tryParse_OrUnknow(\@procedureContent));

       # If the next instruction is a separator, then append it ...
       if ( $moreStatements && isNextSeparator()) {
         Append($WhileNode, parseSeparator());
       }
     }
     else {
       print "PARSE error : unterminated loop (missing first instruction) !!! \n";
     }

     return $WhileNode;
   }
   else {
     return undef;
   }
}


##################################################################
#              DECLARE
##################################################################

sub isNextDeclare() {
   if ( ${nextStatement()} =~ /\A\s*\bdeclare\b/si ) {
      return 1;
   }
   return 0;
}

sub parseDeclare() {

#   if ( ${nextStatement()} =~ /\A\s*\bdeclare\b/si ) {
   if (isNextDeclare()) {
     getNextStatement();     # to consume the "declare" statement...

   # Assume the next statement belong to the "declare" statement. So 
   # it is not parsed for creating a new node, but is recorded as
   # a belonging to the textual statement of the "declare" node ...
   my $DeclareNode ;
   if ( ${nextStatement()} =~ /[^\"\']\bcursor\b/ ) {
     $DeclareNode = Node( CursorDeclarationKind, getNextStatement()); 
   }
   else {
     $DeclareNode = Node( VariableDeclarationKind, getNextStatement()); 
   }

print "+++ DECLARE\n" if ($DEBUG);
     return $DeclareNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              FETCH
##################################################################

sub isNextFetch() {
   if ( ${nextStatement()} =~ /\A\s*\bfetch\b/si ) {
      return 1;
   }
   return 0;
}

sub parseFetch() {

   if (isNextFetch()) {
     getNextStatement();     # to consume the "fetch" statement...

   # Assume the next statement belong to the "fetch" statement. So 
   # it is not parsed for creating a new node, but is recorded as
   # a belonging to the textual statement of the "fetch" node ...
   my $FetchNode = Node( FetchKind, getNextStatement()); 

print "+++ FETCH\n" if ($DEBUG);
     return $FetchNode;
   }
   else {
     return undef;
   }
}


##################################################################
#              QUERY OPERATOR (UNION / INTERSECT / EXCEPT)
##################################################################

sub isNextQueryOp() {
   if ( ${nextStatement()} =~ /\A\s*\b(?:union|intersect|except)\b/si ) {
      return 1;
   }
   return 0;
}

sub parseQueryOp() {

#   if ( ${nextStatement()} =~ /\A\s*\b(?:union|intersect|except)\b/si ) {
   if (isNextQueryOp()) {
     my $QueryOpNode = Node( QueryOpKind, getNextStatement()); 
     return $QueryOpNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              SELECT
##################################################################

sub isNextSelect() {
   if ( ${nextStatement()} =~ /\A\s*\bselect\b/si ) {
      return 1;
   }
   return 0;
}


sub isASelectSubStatement($) {
  my $Nstat = shift ;

  if ( $Nstat =~ /\b(?:into|from|where|group\s+by|having|order\s*by|and|or)\b/si ) {
    return 1;
  }
  else {
    return 0;
  }
}

sub parseSelect() {

	#if ( ${nextStatement()} =~ /\A\s*\bselect\b/si ) {
   if (isNextSelect()) {
     getNextStatement();     # to consume the "select" statement...

print "+++ SELECT\n" if ($DEBUG);
     my $SelectStatement = "";
     my $soldeParenthesis = 0; 

     my $SelectNode = Node( SelectKind, \$SelectStatement ); 
     SetLine($SelectNode, getStatementLine());

     my $tag = "Artifact_select_".$SQL_ID++;
     $tag .= "-LINE-".getStatementLine()."-";
     SetName($SelectNode, $tag);

     pushArtifact(\@CURRENT_SQL_ARTIFACT, $tag);
     # While :
     #   1 - Next statement contains Select keywords (FROM, WHERE ...)
     #   2 - OR solde parenthesis is not nul.
     #   3 - AND Next statement is not ";"
     #   4 - AND Next statement is not a an unexpected ")"   *
     #   	* in this case, the select goes until the ")" and then ends :
     #   	  the statement should be split before the parenthesis.

     # If the next statement has an negative parenthesis impact, it will be split into two parts,
     # whom the first have a null impact. The second will  then begin with the incriminated closing
     # arenthesis.
     # If the result is a blank first part, then it is ignored, but at this step of the analysis,
     # it will reveal a syntactic error.
     splitNextStatementOnExtraClosingParenthesis(0) ;

     my $Nstat = ${nextStatement()};

     # Check if the next statement is closing the parent structure : in this case the result will
     # be less than zero, and the loop should not be executed. This case would be an error because the
     # select should contain at least one statement.
     $soldeParenthesis += ImpactParenthesis(\$Nstat);

     if ($soldeParenthesis < 0) {
       print "PARSE error : Select with no statement !!!!\n";
     }

     # the first following statement is mandatorily attached to the select statement, even if it is an
     # unknow statement.
     my $force = 1;

     # Remark on $soldeParenthesis :
     #   1) This variable must be always >=0 to continue the select analysis. This conditions is
     #      necessary but not sufficient, so it can be related to a OR relation. For exemple, a
     #      QueryOp statement should end the select analysis because it is not a Select SubStatement,
     #       unless there is parenthesis opened. So if the statement is not a Select sub-statement,
     #      then ($soldeParenthesis==0) must be a blocking condition.
     #   2) The Select analysis should imperatively continue while parenthesis are still opened
     #      (that is ($soldeParenthesis>0) ), even if the statement is not a select sub-statement.
     #      ($soldeParenthesis>0) is not necessary but is sufficient, so it is related to a OR relation.
     while ( ($moreStatements) && ( $Nstat !~ /;/ ) && ( $soldeParenthesis >= 0) && 
	   ( ( isASelectSubStatement($Nstat) ) ||
	     ( $soldeParenthesis > 0) || 
             ( $force )) ) {
       $force = 0;
       # Consumes the next statement ...
       #my $Nstat = getNextStatement();

       # If the next statement is a query Operator, then  it can belong to the select statement only
       # if it is placed between parenthesis. If not, then the QueryOp is the end of the select
       # ==> in fact, the select is the left member of the QueryOp in this case !!!
       #if ((isNextQueryOp() == 0) || (isNextQueryOp() && ($soldeParenthesis >0))) {
         my $node = tryParse_OrUnknow(\@selectContent);

         Append($SelectNode, $node);
	 #}

#print "Parenthesis = $soldeParenthesis\n";
       if ($moreStatements) {
	 # Split the next statement on the next closing parenthesis (that will pass the parenthesis
	 # level to null)...
         splitNextStatementOnExtraClosingParenthesis($soldeParenthesis) ;

         $Nstat = ${nextStatement()};
#print "Nstat = $Nstat\n";
         # Check if the next statement is closing the parent structure : in this case the result will
         # be less than zero.
         if ( ($Nstat =~ /^\s*\)/sm ) && ($soldeParenthesis == 0)) {
           # This case is to force stopping if the next statement have a >=0 parenthesis impact
	   # while the first closing parenthesis indicates the end of the statement. For example
	   # if $Nstat is like ") and not exists ("
           $soldeParenthesis = -1;
	 }
	 else {
           $soldeParenthesis += ImpactParenthesis(\$Nstat);
           if ($Nstat =~ /^\s*\)/sm ) {
	   # force to consider the closing parenthesis as belonging to the select ...
	   # Note that if this parenthesis were not belonging to the select, solde parenthesis
	   # would have been -1 !!!
#print "FORCE ACCEPT PARENTHESIS\n";
             $force = 1;
	   }
         }
       }
       elsif ($soldeParenthesis >0) {
	 # If the last statement has been encountered while parenthesis bloc is still open, then
	 # it is an error.
         print "PARSE error : unterminated select\n";
       }
     }


print "+++ Fin du SELECT\n" if ($DEBUG);
     popArtifact(\@CURRENT_SQL_ARTIFACT, $tag);
     return $SelectNode;
   }
   else {
     return undef;
   }
}
##################################################################
#              known SQL instructions nor using select instruction
#                         (non exhaustive list)
##################################################################

sub parseSQL_WithSelect($) {
  my $kind = shift;


  my $SQLNode = Node($kind, makeStringRef(""));
  my $SQL_not_finished = 1;
  my $soldeParenthesis = 0;
  my $SQL_Statement = "";
  my $nchild = 0;

#  if ($moreStatements) {
#    $SQL_Statement .= ${getNextStatement()};
#  }
#  else {
#    print "PARSE error : unterminated SQL instruction ...\n";
#  }

#  $soldeParenthesis += ImpactParenthesis(\$SQLStatement);

  while ($moreStatements  && $SQL_not_finished ) {

     # try to parse a statement specified in SQLContent or return unknow, unless
     # a known ("Structural") statement is encountered 
     my $node = tryParse(\@SQLContent);

     if ( defined $node ) {
       Append($SQLNode, $node);
       $SQL_Statement .= " CHILD_${nchild}_".$node->[0]." ";
       $nchild++;
     }
     else {
       if ( isNextKnown()) {
	 # If the next instruction is known as a statement (basic or structural) that can not belong
	 # to the SQL instruction, then the SQL will end.
         $SQL_not_finished = 0;
	 if ( $soldeParenthesis > 0) {
           print "PARSE error : unterminated SQL statement ...\n";
	 }
       }
       else {
	 # The statement belongs to the SQL ...
	 my $Nstat = ${getNextStatement()};
	 $SQL_Statement .= $Nstat;
         $soldeParenthesis += ImpactParenthesis(\$Nstat);
     
         # Check criteria for the end of the condition :
         if ( ($soldeParenthesis == 0) && (($moreStatements) && (! isNextSelect())) ) {
           $SQL_not_finished = 0;
         }
       }
     }
  }
  SetStatement($SQLNode, \$SQL_Statement);
  return $SQLNode;
}

##################################################################
#                      CREATE
##################################################################
sub isNextCreate() {
   if ( ${nextStatement()} =~ /\A\s*\bcreate\b\s*$/si ) {
      return 1;
   }
   return 0;
}

sub parseCreate() {
  if (isNextCreate()) {

    my $ArtifactLine = getNextStatementLine();
    my $tag = 'Artifact_SQL_'.$SQL_ID++;
    $tag .= "-LINE-".$ArtifactLine."-";
    pushArtifact(\@CURRENT_SQL_ARTIFACT, $tag);

     getNextStatement();     # to consume the "create" statement...

    my $kind = CreateKind;
    my $WithoutSelect = 0;
    my $CreateNode;
    if (${nextStatement()} =~ /\A\s*\btable\b/si ) { 
	    $WithoutSelect=1; }
    elsif (${nextStatement()} =~ /\A\s*\w*\s*(index|view)\b/si ) { 
	    $WithoutSelect=1; }
    
    if ( $WithoutSelect ) {
print "+++ CREATE without select : $kind\n" if ($DEBUG);
      $CreateNode = Node($kind, getNextStatement());
    }
    else {
print "+++ CREATE with (potential) select : $kind\n" if ($DEBUG);
      $CreateNode = parseSQL_WithSelect($kind);
    }

    SetLine($CreateNode, $ArtifactLine);
    popArtifact(\@CURRENT_SQL_ARTIFACT, $tag);
    SetName($CreateNode, $tag);
    return $CreateNode;
  }
  else {
    return undef;
  }
}

##################################################################
#                      ALTER
##################################################################
sub isNextAlter() {
   if ( ${nextStatement()} =~ /\A\s*\bAlter\b\s*$/si ) {
      return 1;
   }
   return 0;
}

sub parseAlter() {
  if (isNextAlter()) {

  my $tag = 'Artifact_SQL_'.$SQL_ID++;
  pushArtifact(\@CURRENT_SQL_ARTIFACT, $tag);

     getNextStatement();     # to consume the "Alter" statement...

    my $kind = AlterKind;
    my $WithoutSelect = 0;
    my $AlterNode;
    if (${nextStatement()} =~ /\A\s*\btable\b/si ) { 
	    $WithoutSelect=1; }
    
    if ( $WithoutSelect ) {
print "+++ ALTER without select\n" if ($DEBUG);
      $AlterNode = Node($kind, getNextStatement());
    }
    else {
print "+++ ALTER with (potential) select : $kind\n" if ($DEBUG);
      $AlterNode = parseSQL_WithSelect($kind);
    }

    popArtifact(\@CURRENT_SQL_ARTIFACT, $tag);
    return $AlterNode;
  }
  else {
    return undef;
  }
}

##################################################################
#                      DROP
##################################################################
sub isNextDrop() {
   if ( ${nextStatement()} =~ /\A\s*\bDrop\b\s*$/si ) {
      return 1;
   }
   return 0;
}

sub parseDrop() {
  if (isNextDrop()) {

    my $tag = 'Artifact_SQL_'.$SQL_ID++;
    pushArtifact(\@CURRENT_SQL_ARTIFACT, $tag);

    getNextStatement();     # to consume the "Drop" statement...

    my $kind = DropKind;
    my $WithoutSelect = 0;
    my $DropNode;
    if (${nextStatement()} =~ /\A\s*\btable\b/si ) { 
	    $WithoutSelect=1; }
    
    if ( $WithoutSelect ) {
print "+++ DROP without select\n" if ($DEBUG);
      $DropNode = Node($kind, getNextStatement());
    }
    else {
print "+++ DROP with (potential) select : $kind\n" if ($DEBUG);
      $DropNode = parseSQL_WithSelect($kind);
    }

    popArtifact(\@CURRENT_SQL_ARTIFACT, $tag);
    return $DropNode;
  }
  else {
    return undef;
  }
}

##################################################################
#                      SQL (any)
##################################################################
sub isNextSQL_withoutSelect() {
   if (  ( ${nextStatement()} =~ /\A\s*\b(Bulk\s*insert)\b\s*$/si )
      || ( ${nextStatement()} =~ /\A\s*\btruncate\s*table\b\s*$/si ) ) { 
      return 1;
   }
   return 0;
}

sub isNextSQL_withSelect() {
   if ( ${nextStatement()} =~ /\A\s*\b(insert|update|merge|delete)\b\s*$/si ) {
      return 1;
   }
   return 0;
}


sub parseSQL() {
  my $r_SQLStatement = "";
  my $SQLNode;

  if (isNextSQL_withoutSelect()) {

    my $tag = 'Artifact_SQL_'.$SQL_ID++;
    pushArtifact(\@CURRENT_SQL_ARTIFACT, $tag);

     $r_SQLStatement = getNextStatement();     # to consume the statement...
print "+++ SQL without select : $$r_SQLStatement\n" if ($DEBUG);

     $$r_SQLStatement .= ${getNextStatement()};
     $SQLNode = Node(SQLKind, $r_SQLStatement);

     popArtifact(\@CURRENT_SQL_ARTIFACT, $tag);
     return $SQLNode;
  }
  elsif (isNextSQL_withSelect()) {
     

    my $tag = 'Artifact_SQL_'.$SQL_ID++;
    pushArtifact(\@CURRENT_SQL_ARTIFACT, $tag);

     $r_SQLStatement = getNextStatement();     # to consume the statement...
     my $kind;

     if ( $$r_SQLStatement =~ /\A\s*insert\s*$/is ) {
       $$r_SQLStatement = ""; # Remove the "insert" keyword, because we know that it is an InsertKind
       $kind = InsertKind;
     }
     else {
       $kind = SQLKind ;      # Undefined SQLcommand.
     }
print "+++ SQL with (potential) select : $$r_SQLStatement\n" if ($DEBUG);
     $SQLNode = parseSQL_WithSelect($kind);
     $$r_SQLStatement .= ${GetStatement($SQLNode)};
     SetStatement($SQLNode, $r_SQLStatement);

     popArtifact(\@CURRENT_SQL_ARTIFACT, $tag);
     return $SQLNode;
  }
  else {
    return undef;
  }
}

##################################################################
#             Generic keyword ...
##################################################################

# WARNING : must not be used to parse a SQL instruction that can contain a select instruction ...
sub parseBasicInstruction($) {
  my $Node = shift ;
  # Consumes the "KEYWORD" statement.
  getNextStatement();

  if ( $moreStatements && (! isNextKnown()) && (! isNextSelect()) ) {
    # If the next statement is unknow, then it is maybe the name or option of
    # the instruction.
    # RQ : 
    #   (1) - SELECT is not a "Known" statement (ie a pure structural instruction that can not belong
    # to SQL instruction nor any other instruction), but will nevertheless mark the end of a non
    # SQL instruction.
    SetStatement($Node, getNextStatement()) ;
  }
  else {
    my $empty_string = "";
    SetStatement($Node, \$empty_string) ;
  }
  return $Node;
}

##################################################################
#              RETURN
##################################################################
sub isNextReturn() {

   if ( ${nextStatement()} =~ /\A\s*\breturn\b/sim ) {
      return 1;
   }
   return 0;
}

sub parseReturn() {
   if (isNextReturn()) {
     my $ReturnNode = Node( ReturnKind, makeStringRef("")); 

print "+++ RETURN\n" if ($DEBUG);

     return parseBasicInstruction($ReturnNode);
   }
   else {
     return undef;
   }
}

##################################################################
#              ROLLBACK TRAN
##################################################################
sub isNextRollbackTran() {

   if ( ${nextStatement()} =~ /\A\s*\brollback\s+(transaction|tran)\b\s*$/sim ) {
      return 1;
   }
   return 0;
}

sub parseRollbackTran() {
   if (isNextRollbackTran()) {
     my $RollbackNode = Node( RollbackTranKind, makeStringRef("")); 

     $RollbackNode = parseBasicInstruction($RollbackNode);
print "+++ ROLLBACK TRAN\n" if ($DEBUG);
     if (${GetStatement($RollbackNode)} =~ /\A[ \t]*(\w+)/) {
       SetName($RollbackNode, $1);
     }
     return $RollbackNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              COMMIT TRAN
##################################################################
sub isNextCommitTran() {

   if ( ${nextStatement()} =~ /\A\s*\bcommit\s+(transaction|tran)\b\s*$/sim ) {
      return 1;
   }
   return 0;
}

sub parseCommitTran() {
   if (isNextCommitTran()) {
     my $CommitNode = Node( CommitTranKind, makeStringRef("")); 

     $CommitNode = parseBasicInstruction($CommitNode);
print "+++ COMMIT TRAN\n" if ($DEBUG);
     if (${GetStatement($CommitNode)} =~ /\A[ \t]*(\w+)/) {
       SetName($CommitNode, $1);
     }
     return $CommitNode
   }
   else {
     return undef;
   }
}

##################################################################
#              BEGIN TRAN
##################################################################
sub isNextBeginTran() {

   if ( ${nextStatement()} =~ /\A\s*\bbegin\s+(transaction|tran)\b\s*$/sim ) {
      return 1;
   }
   return 0;
}

sub parseBeginTran() {
   if (isNextBeginTran()) {
     my $BeginNode = Node( BeginTranKind, makeStringRef("")); 

     $BeginNode = parseBasicInstruction($BeginNode);
print "+++ BEGIN TRAN\n" if ($DEBUG);
     # In the following regular expr, new line is not eccepted as blank,
     # because we suppose the transaction name is on the same line.
     if (${GetStatement($BeginNode)} =~ /\A[ \t]*(\w+)/) {
       SetName($BeginNode, $1);
     }
     return $BeginNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              BEGIN TRY
##################################################################
sub isNextBeginTry() {

   if ( ${nextStatement()} =~ /\A\s*\bbegin\s+try\b\s*$/sim ) {
      return 1;
   }
   return 0;
}

sub parseBeginTry() {
   if (isNextBeginTry()) {
   my $BeginNode = Node( BeginTryKind, getNextStatement()); 

print "+++ BEGIN TRY\n" if ($DEBUG);
     return parseEndTerminatedBlock($BeginNode, \@procedureContent, "TRY", \&parseEndTry);
   }
   else {
     return undef;
   }
}

##################################################################
#              BEGIN CATCH
##################################################################
sub isNextBeginCatch() {
   if ( ${nextStatement()} =~ /\A\s*\bbegin\s+catch\b\s*$/sim ) {
      return 1;
   }
   return 0;
}

sub parseBeginCatch() {
   if (isNextBeginCatch()) {
   my $BeginNode = Node( BeginCatchKind, getNextStatement()); 

print "+++ BEGIN CATCH\n" if ($DEBUG);
     return parseEndTerminatedBlock($BeginNode, \@procedureContent, "CATCH", \&parseEndCatch);
   }
   else {
     return undef;
   }
}

##################################################################
#              BEGIN
##################################################################
sub isNextBegin() {

   if ( ${nextStatement()} =~ /\A\s*\bbegin\b\s*$/sim ) {
      return 1;
   }
   return 0;
}

sub parseBegin() {
   if (isNextBegin()) {
   my $BeginNode = Node( BeginKind, getNextStatement()); 

print "+++ BEGIN\n" if ($DEBUG);
     return parseEndTerminatedBlock($BeginNode, \@procedureContent, "", \&parseEnd);
   }
   else {
     return undef;
   }
}

##################################################################
#              GO
######################Go############################################
sub isNextGo() {

   if ( ${nextStatement()} =~ /\A\s*go\b/si ) {
      return 1;
   }
   return 0;
}

sub parseGo() {

#   if ( ${nextStatement()} =~ /\A\s*go\b/si ) {
   if ( isNextGo()) {
     getNextStatement();     # to consume the go statement...
     my $endNode = Node( GoKind, makeStringRef('')); 
     return $endNode;
   }
   else {
     return undef;
   }
}
##################################################################
#              END TRY
##################################################################
sub isNextEndTry() {
   if ( ${nextStatement()} =~ /\A\s*end\s+try\b/si ) {
      return 1;
   }
   return 0;
}

sub parseEndTry() {
   if (isNextEndTry() ) {
     getNextStatement();     # to consume the end statement ...
     my $endNode = Node( EndTryKind, makeStringRef('')); 
     return $endNode;
   }
   else {
     return undef;
   }
}
##################################################################
#              END CATCH
##################################################################
sub isNextEndCatch() {
   if ( ${nextStatement()} =~ /\A\s*end\s+catch\b/si ) {
      return 1;
   }
   return 0;
}

sub parseEndCatch() {

#   if ( ${nextStatement()} =~ /\A\s*end\b/si ) {
   if (isNextEndCatch() ) {
     getNextStatement();     # to consume the end statement ...
     my $endNode = Node( EndCatchKind, makeStringRef('')); 
     return $endNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              END
##################################################################
sub isNextEnd() {

   if ( ${nextStatement()} =~ /\A\s*end\b\s*$/sim ) {
      return 1;
   }
   return 0;
}

sub parseEnd() {

#   if ( ${nextStatement()} =~ /\A\s*end\b/si ) {
   if (isNextEnd() ) {
     getNextStatement();     # to consume the end statement ...
     my $endNode = Node( EndKind, makeStringRef('')); 
     return $endNode;
   }
   else {
     return undef;
   }
}


##################################################################
#              ROUTINE CONTENT
##################################################################

sub parseFunctionDeclaration($) {
  my $node = shift;
print "[parseFunctionDeclaration]\n";
  # Retrieves the procedures declarations options
     my $RoutineDeclareStatement = "";
     while ( $moreStatements && (${nextStatement()} !~ /\breturns\b/si) ) {
	$RoutineDeclareStatement .= ${getNextStatement()};
     }

     if ( $moreStatements ) {
       splitNextStatementOnPattern('\breturns\b');

       # Consumes the statement before the RETURNS, if any.
       while ( ${nextStatement()} !~ /\breturns\b/si ) {
	  $RoutineDeclareStatement .= ${getNextStatement()};
       }

       # Consumes the "RETURNS" statement.
       getNextStatement();  
     }
     else {
       print "PARSE error : missing RETURNS for routine routine beginning\n";
     }

     # There is two possibility for the end of the déclaration :
     #
     # RETURNS TABLE ..... RETURN
     # RETURNS ........... BEGIN
     my $EndsWith = "";
     if ( $moreStatements && (${nextStatement()} =~ /\A\s*table\b/si) ) {
	     #splitNextStatementOnPattern('\btable\b');
#print "NEXT (return): ".${nextStatement()}."\n";
        $EndsWith = "return";
     }
     else {
#print "NEXT (begin): ".${nextStatement()}."\n";
        $EndsWith = "begin";
     }

     # Consumes the last statements of the declaration, if any.
     while ( $moreStatements && (${nextStatement()} !~ /\b$EndsWith\b/si) ) {
       $RoutineDeclareStatement .= ${getNextStatement()};
     }


     return \$RoutineDeclareStatement;
}


sub parseProcTriggDeclaration($) {
  my $node = shift;

  # Retrieves the procedures declarations options
     my $RoutineDeclareStatement = "";
     
     # work with statement until there remain none (it would be a error)
     # or the loop will be broken by encountering the 'AS' keyword.
     while ( $moreStatements ) {
	   
       if ( ${nextStatement()} =~ /\b(?:execute\s+)?as\b/si ) {
	  	 splitNextStatementOnPattern('\b(?:execute\s+)?as\b');
	  	 while ( ${nextStatement()} !~ /^(execute\s+)?as$/im ) {
		   $RoutineDeclareStatement .= ${getNextStatement()};	 
		 }
		 
		 if (${nextStatement()} =~ /^as$/im) {
			 last;
		 }
		 else {
			 $RoutineDeclareStatement .= ${getNextStatement()};
		 }
	   }
	   else {
		   $RoutineDeclareStatement .= ${getNextStatement()};
	   }
	 }
     
#     while ( $moreStatements && (${nextStatement()} !~ /\bas\b/si) ) {
#	$RoutineDeclareStatement .= ${getNextStatement()};
#     }

     if ( $moreStatements ) {
       splitNextStatementOnPattern('\bas\b');

       # Consumes the statement before the AS, if any.
       while ( ${nextStatement()} !~ /\bas\b/si ) {
	  $RoutineDeclareStatement .= ${getNextStatement()};
       }

       # Consumes the "AS" statement.
       getNextStatement();  
     }
     else {
       print "PARSE error : missing AS for routine routine beginning\n";
     }

     return \$RoutineDeclareStatement;
}


sub parseRoutineContent($$) {

   my ($RoutineNode, $kind) = @_;

   my $r_RoutineDeclareStatement = "";

   if (IsKind($RoutineNode, FunctionKind)) {
     $r_RoutineDeclareStatement = parseFunctionDeclaration($RoutineNode);
   }
   else {
     $r_RoutineDeclareStatement = parseProcTriggDeclaration($RoutineNode);
   }


     # create the procedure node.
     #my $procedureNode = Node( ProcedureKind, \$ProcDeclareStatement); 
     SetStatement($RoutineNode, $$r_RoutineDeclareStatement);

     # retrieves the procedure name
     my $name = "";
     #if ( $$r_RoutineDeclareStatement =~ /\A\s*(\w*(?:\s*\.\s*\w+)?)/si ) {
     if ( $$r_RoutineDeclareStatement =~ /\A\s*($ROUTINE_NAME_PATTERN)/si ) {
       $name = $1;
     }
     else {
       print "PARSE error : no name for $kind !!! \n";
       $name = "unnamed_routine_".$UNNAMED_ROUTINE_ID++;
     }

     SetName($RoutineNode, $name);

     # Declare a routine beginning, so that all statement encountered until
     # call to endArtifact() will be concatened and recorded associated with 
     # the routine name.
     #beginRoutine($name);
     newArtifact($name);

print "+++ Debut $kind $name\n" if ($DEBUG);
     my $node;
     while ($moreStatements) {
       if ( defined ($node = parseGo())) {
         Append($RoutineNode, $node);
print "+++ Fin $kind $name\n" if ($DEBUG);
     endArtifact($name);
         return $RoutineNode;
       }
       else {
         $node = tryParse_OrUnknow(\@procedureContent);
         Append($RoutineNode, $node);
       }
     }
     
     endArtifact($name);

     # A procedure can ends whithout a go statement (ex : end of file). So this message is not appropriated :
#     print "PARSE error : unterminated $kind ($name) !!! \n";
     
     # IMPORTANT : Return the incomplete node. Indeed as some statements
     # have consumed (creation of a node), the parse can't return UNDEF. 
     return $RoutineNode;
}

##################################################################
#              TRIGGER
##################################################################
sub isNextTrigger() {
   if ( ${nextStatement()} =~ /\A\s*\bcreate\s+(?:trigger)\b/si ) {
     return 1;
   }
   return 0;
}

sub parseTrigger() {

	#  if ( ${nextStatement()} =~ /\A\s*\bcreate\s+(?:proc|procedure)\b/si ) {
   if (isNextTrigger() ) {
     # consume the "create trigger" statement ...
     getNextStatement();

     my $TriggerNode = Node( TriggerKind, makeStringRef(""));
     SetLine($TriggerNode, getStatementLine());

     return parseRoutineContent($TriggerNode, "TRIGGER");
   }
   else {
     return undef;
   }
}

##################################################################
#              PROCEDURE
##################################################################
sub isNextProcedure() {
   if ( ${nextStatement()} =~ /\A\s*\bcreate\s+(?:proc|procedure)\b/si ) {
     return 1;
   }
   return 0;
}

sub parseProcedure() {

	#  if ( ${nextStatement()} =~ /\A\s*\bcreate\s+(?:proc|procedure)\b/si ) {
   if (isNextProcedure() ) {
     # consume the "create proc" statement ...
     getNextStatement();

     my $ProcNode = Node( ProcedureKind, makeStringRef(""));
     SetLine($ProcNode, getStatementLine());

     return parseRoutineContent($ProcNode, "PROC");
   }
   else {
     return undef;
   }
}

##################################################################
#              FUNCTION
##################################################################
sub isNextFunction() {
   if ( ${nextStatement()} =~ /\A\s*\bcreate\s+function\b/si ) {
     return 1;
   }
   return 0;
}

sub parseFunction() {
   if (isNextFunction() ) {
     # consume the "create function" statement ...
     getNextStatement();

     my $ProcNode = Node( FunctionKind, makeStringRef(""));
     SetLine($ProcNode, getStatementLine());

     return parseRoutineContent($ProcNode, "FUNC");
   }
   else {
     return undef;
   }
}
##################################################################
#              ROOT
#################################################################
sub parseRoot() {
  
  my $Root = Node(RootKind, undef);

  my $node;
  while ($moreStatements) {
    $node = tryParse_OrUnknow(\@rootContent);
    Append($Root, $node);
  }
  return $Root;
}


sub replace_CASE() {

  my $endcase_expected = 0;
  my $i = 0;
  my $start_remove = -1;
  my $CODE = "";
  my $replaced_KEY = "";
  my $replaced_ID = 0;

  #for my $stmt (@{$r_statements}) {
  while (defined $r_statements->[$i]) {

    my $stmt = $r_statements->[$i];

    if ( $stmt =~ /\bcase\b(.*)/smi ) {
      my $pattern = $1;
      if ( $pattern =~ /\S/ ) {
        splice @{$r_statements}, $i+1, 0, $pattern;
      }

      if ($start_remove == -1) {
        $start_remove = $i+1;
	$replaced_KEY = "HIGHLIGHT_CASE_$replaced_ID";
	$replaced_ID++;
        $CODE .= " case";
      }
      else {
	# in case of imbricated case, the entire statement will be replaced, so the code statement
	# to be retained is the entirety, and not only the "case" keyword.
        $CODE .= ' '.$stmt ;
      }
      $r_statements->[$i] =~ s/\bcase\b.*/HIGHLIGHT_CASE_$replaced_ID/smi;

      $endcase_expected++;
      if ($endcase_expected == 1) {
	# In case of imbricated case, memorize only the statement ID of the most encompassing "case"
        $replaced_ID = $i;
      }
    }

    elsif ( $endcase_expected ) {

      $CODE .= $stmt;

      if ( $stmt =~ /\bend\b/si ) {
        $endcase_expected--;
        if ($endcase_expected == 0) {
          splice @{$r_statements}, $start_remove, ($i-$start_remove+1) ;
	  # suppressing statement entry implie decrement the statement progression conter to take into 
	  # account the left shift of the statement list.
	  $i -= $i-$start_remove+1;

	  $replaced_CODE{$replaced_KEY} = $CODE;
#print "REPLACED : $replaced_KEY ==> $CODE\n";
          $start_remove = -1;

	  # Count the number of new lines that have been removed ...
	  my $nbnl = () = $CODE =~ /\n/sg;
          $r_statements->[$replaced_ID] .= "\n" x $nbnl ;

	  $CODE = "";
        }
      }
    }

    $i++;
  }

  if ( $endcase_expected ) {
    splice @{$r_statements}, $start_remove, ($i-$start_remove) ;
    print "PARSE error : untermnated case ...\n";
  }


}



sub InitParser() {
  %H_ARTIFACTS_BUFFER = ();
  %CURRENT_ARTIFACTS = ();

  %replaced_CODE = ();
  $replaced_ID=0;

  $SQL_ID = 0;
  @CURRENT_SQL_ARTIFACT = ();
  $UNNAMED_ROUTINE_ID = 0;

  initStatementManager();

}

# description: TSQL parse module Entry point.
sub Parse($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $status = 0;

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

     replace_CASE();

#     splitCompoundStatement();

#      my @statementReader = ( $statements, 0);
#

      my $rootNode = parseRoot();

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

      TSql::Node::Dump($rootNode, *STDERR, "ARCHI") if ($DEBUG);
      
      $vue->{'structured_code'} = $rootNode;

      $vue->{'routines'} = \%H_ARTIFACTS_BUFFER;

      TSql::ParseDetailed::ParseDetailed($vue);

      #for my $key ( keys %{$vue->{'routines'}} ) {
      #  print "-------- $key -----------------------------------\n";
	#print  $vue->{'routines'}->{$key}."\n";
      #}

#      my @context = ();
#      PlSql::Node::Iterate ($rootNode, 0, \& _MarkConditionnalNode, \@context) ;
#      $vue->{'dump_functions'}->{'structured_code'} = \&PlSql::Node::Dump;
#
#      @context = (0);
#      PlSql::Node::Iterate ($rootNode, 0, \& _CountUnexpectedStatements, \@context) ;
#      $status |= $context[0];
#
#      $vue->{'structured_code_by_kind'} = PlSql::PlSqlNode::BuildListByKind ($rootNode) ;
#      
#      $vue->{'structured_code_cloned'} = PlSql::Node::Clone( $rootNode );
#      $vue->{'dump_functions'}->{'structured_code_cloned'} = \&PlSql::Node::Dump;

    return $status;
}

1;
