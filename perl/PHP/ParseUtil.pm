package PHP::ParseUtil;
# les modules importes
use strict;
use warnings;
#use diagnostics; #FIXME: est-ce compatible Strawberry?
#no warnings 'recursion'; 

use Erreurs;

use CountUtil;

use Lib::Node qw( Leaf Node Append UnknowKind);

use PHP::PHPNode ;
use PHP::PHPNode qw( SetName SetStatement SetLine GetLine ); 

use Exporter 'import';
our @EXPORT_OK = ( 'getNextStatement', 'nextStatement');
our @EXPORT = ( 'getNextStatement', 'nextStatement', 'getStatementLine',
              );

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

my @conditionContent = (#\&parseSelect, \&parseQueryOp
                       ) ;
my @SQLContent = (#\&parseSelect, \&parseQueryOp
                 ) ;
my @selectContent = (#\&parseSelect, \&parseQueryOp
                    ) ;

my @procedureContent = (#\&parseEnd, \&parseGo, \&parseLabel,\&parseBegin, \&parseDeclare, \&parseFetch, \&parseCreate, @selectContent, \&parseAlter, \&parseDrop, \&parseSQL, \&parseWhile, \&parseIf, \&parseReturn, \&parseBeginTran, \&parseCommitTran, \&parseRollbackTran, \&parseBeginTry, \&parseBeginCatch, \&parseEndTry, \&parseEndCatch
                        );
my @rootContent = ( 
                    );

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

sub getArtifacts() {
  return \%H_ARTIFACTS_BUFFER;
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

# Replace the specified element with a given list of new elements.
sub replaceSplitStatement($$$) {
  my ($idx, $r_split1, $r_split2) = @_;

  splice (@$r_statements, $idx, 1, $$r_split1, $$r_split2);
  return;
}

# Replace the current element with a given list of new elements.
sub replaceCurrentStatement($$) {
  my ($r_split1, $r_split2) = @_;

  splice (@$r_statements, $idx_statement, 1, $$r_split1, $$r_split2);
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
    if ( $1 ne '') { 
      push @list, $1;
    }

    if ($KeepPattern) { push @list, $2; }

    if ( $3 ne '' ) { 
      push @list, $3;
    }

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

sub parseUnknow_DEFAULT() {
  if (! defined nextStatement() ) {
    return undef;
  }
  else {
     return Node(UnknowKind, getNextStatement());
  }
}

my $PARSE_UNKNOW = \&parseUnknow_DEFAULT;

sub registerParseUnknow($) {
  my $callback = shift;
  if (defined $callback) {
    $PARSE_UNKNOW = $callback;
  }
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
    #$node = Node(UnknowKind, getNextStatement());
    $node = $PARSE_UNKNOW->();
print "+++ UNRECOGNIZED ...\n" if ($DEBUG);
    return $node ;
  }

  # by default, undef is returned.
  return undef;
}


sub InitParser($) {

  $r_statements = shift;
  if (scalar @{$r_statements} > 0) {
    $moreStatements = 1;
  }
  else {
    $moreStatements = 1;
  }

  %H_ARTIFACTS_BUFFER = ();
  %CURRENT_ARTIFACTS = ();

  $UNIQ_ID = 0;

  $SQL_ID = 0;
  @CURRENT_SQL_ARTIFACT = ();
  $UNNAMED_ROUTINE_ID = 0;

  initStatementManager();

}

sub parseUntilPeer($$) {
  my $begin = shift;
  my $end = shift;
  my $level =0;
  my $continue = 1;
  my $output = "";
  my $stmt1 = "";
  my $stmt2 = "";
  my $dest = \$stmt1;

  while ( defined nextStatement() && $continue ) {
     $stmt1 = "";
     my $stmt = ${nextStatement()};
	  #while ( ${nextStatement()} =~ /\G([^${begin}${end}]*)(${begin}|${end}|\Z)/sim) {
    while ( $stmt =~ /([^\(\)]*)(\(|\)|\Z)/simg) {
      my $code=$1;
      my $sep=$2;
      # begin delimiter
      if ($sep eq $begin) {
        $level++;
	$$dest .= $code.$sep;
      }
      # end delimiter
      elsif ($sep eq $end) {
	$$dest .= $code.$sep;

	if ($level != 0) {
          $level--;
	  if ($level == 0) {
            $continue = 0;
	    $dest = \$stmt2;
	  }
        }
	else {
	  print "[parseUntilPeer] PARSE ERROR : no corresponding '$begin' for '$end'\n";
	  $continue = 0;
	  $dest = \$stmt2;
	}
      }
      # end of statement
      else {
        $$dest .= $code;
      }
    }
    $output .= $stmt1;
    if ( $level == 0) {
      if ($stmt2 =~ /\S/) {
      # replace current statement by the two stmt1 & $stmt2 (unless stmt2 empty)
        replaceCurrentStatement(\$stmt1, \$stmt2);
      }
      # consumn the current statement (i.e stmt1).
      getNextStatement(); 
      return \$output;
    }
    else {
      # consumn the current statement.
      getNextStatement();
    }
  }
  # unless an algorithmic programing error, we should never execute this line :
  print "[parseUntilPeer] ALGO ERROR : unexpected algorithmic case encountered! \n";
}

##################################################################
#              Generic bloc of code
#              --------------------
#  Create a "CodeBloc" node that will contain all subnodes build.
#  Parse all statements until the one is recongnized as the end statement.
#  All nodes build are attached to the "CodeBloc" node created.
#
#  parameters :
#  	- kind : kind of the resulting bloc
#  	- isEnd_callback : a ref. array of callback for testing closing statements.
#  	- r_tab_StatementContent : a ref. array of callback for parsing
#  	  authorized instruction in the bloc.
#  	- keepClosing : a flag indicating if the closing statement should be keeped or trashed.
#
#################################################################
sub parseCodeBloc($$$$) {
  my ($kind, $isEnd_callback, $r_tab_StatementContent, $keepClosing) = @_;
  my $BlocNode = Node($kind, \$NullString);

  my $line_begin = getStatementLine();

print "+++ BEGIN CodeBloc\n" if ($DEBUG);
  while ($moreStatements) {

    my $endfound=0;
    for my $cb (@{$isEnd_callback}) {
      if ($cb->()) {
        $endfound = 1;
      }
    }

    if ( $endfound ) {
      if (! $keepClosing) {
        # Trash the end bloc delimiter statement.
        getNextStatement();
      }
print "+++ END CodeBloc\n" if ($DEBUG);
      return $BlocNode;
    }
    else {
      my $node = tryParse_OrUnknow($r_tab_StatementContent);
      Append($BlocNode, $node);
    }
  }
  print "PARSE error : unterminated bloc of code, openned at line $line_begin\n";
  #exit;
  return $BlocNode;
}

##################################################################
#              Generic end-terminated artifact
#              -------------------------------
#  Parse all statements until one is recongnized as the end statement.
#  All nodes build are attached to the parent node given in parameter.
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
#       	DoKind() => 'do', 	EndDoKind() => 'enddo',
#       	ClassKind() => 'class\b[^\-](?:.*)\bimplementation', 	EndClassKind() => 'endclass',
	);

my %H_EndCallback = ( 
#	DoKind() => \&parseEndDo,
#	ClassKind() => \&parseEndClass,
        );

my %H_GetName = (
#	ClassKind() => \&getClassName,
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

#sub isNextDo() { return isNextGenericStruct(DoKind); }
#sub parseDo() { return parseGenericStruct(DoKind); }
#sub isNextEndDo() { return isNextGenericStruct(EndDoKind); }
#sub parseEndDo() { return parseGenericEndStruct(EndDoKind); }

#sub isNextClass() { return isNextGenericStruct(ClassKind); }
#sub parseClass() { return parseGenericStruct(ClassKind); }
#sub isNextEndClass() { return isNextGenericStruct(EndClassKind); }
#sub parseEndClass() { return parseGenericEndStruct(EndClassKind); }

#sub getClassName($) {
#  my $r_instr = shift;
#  if ( $$r_instr =~ /\bclass\s+(\w+)/si) {
#    return $1;
#  }
#  else {
#     return "CLASS_".getUniqID();
#  }
#}



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
         $PartNode = Node(UnknowKind, getNextStatement());
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
     my $endMethodNode = Node( UnknowKind, \$NullString); 
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
     my $endFunctionNode = Node( UnknowKind, \$NullString); 
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

1;
