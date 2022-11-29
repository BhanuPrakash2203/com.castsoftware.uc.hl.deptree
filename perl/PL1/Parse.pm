package PL1::Parse;
# les modules importes
use strict;
use warnings;
#use diagnostics; #FIXME: est-ce compatible Strawberry?
#no warnings 'recursion'; 

use Erreurs;

use CountUtil;

use Lib::Node;
use PL1::PL1Node ;
use Lib::NodeUtil;

# prototypes publics
sub Parse($$$$);
sub parseDeclare();
sub parseIf();
sub parseNul();
sub parseEnd();
sub parseBegin();
sub parseDo();
sub parseSelect();
sub parseGoto();
sub parseEntry();
sub parseCall();
sub parseFetch();
sub parseSQL();
sub parseOn();

my $DEBUG=0;

# Rational expression
my $LABEL='\s*(?:[\w\#\$,\s]*\s*:)?\s*';


##################################################################
# FOR MEMORY :
#
# LABEL :
# -------
# Any statement, except DECLARE, DEFAULT, WHEN, OTHERWISE, and ON
# statements, can have a label prefix. 
#
# CONDITION PREFIX :
# ------------------
# Condition prefixes are not valid for DECLARE, DEFAULT, FORMAT,
# OTHERWISE, END, ELSE, ENTRY, and %statements
#
##################################################################

my @UnitParse_List = (\&parseIf, \&parseNul, \&parseBegin, \&parseDo, \&parseSelect, \&parseGoto, \&parseEntry, \&parseCall, \&parseFetch, \&parseSQL, \&parseOn );

my @InstructionParse_List = (\&parseDeclare,  @UnitParse_List);

##################################################################
#              STATEMENTS MANAGEMENT
##################################################################
my @statements = ();
my $idx_statement = 0;
my $moreStatements = 1;
 

sub init_parser() {
   @statements = ();
   $idx_statement = 0;
   $moreStatements = 1;
}


# Consume the next statement in the list and return a reference on it.
sub getNextStatement() {
  my $statement = $statements[$idx_statement++];
  if ( $idx_statement == scalar @statements ) {
    $moreStatements = 0;
  }
print "-----------------------------------------\n" if ( $DEBUG);
print "USING : $statement\n" if ( $DEBUG);
  return \$statement;
}

# return the a reference to the next statement without consuming it from the list.
sub nextStatement() {
   if ( $moreStatements ) {
     return \$statements[$idx_statement];
   }
   else {
     my $empty = "";
     return return \$empty;
   }
}

# Replace the current element with a given list of new elements.
sub replaceSplitStatement($$$) {
  my ($idx, $r_split1, $r_split2) = @_;

  splice (@statements, $idx, 1, $$r_split1, $$r_split2);
  return;
}

sub splitCompoundStatement () {
   my $idx=0;

   while ($idx < scalar @statements)
   {
      # Removing of line white characters that slow the regular
      # expressions when there are in a huge amount.
#      $statements[$idx] =~ s/\A\s+/ /sg ;

	   #if ( $statements[$idx] =~ /^[\s\n]*(\b(?:when|other|otherwise)\b\s*(?:\([^\(\)]*\))?)(.*)/is ) {
      if ( $statements[$idx] =~ /\A[\s\n]*\bwhen\b\s*\(/is ) {
        my ($when, $action) = CountUtil::splitAtPeer(\$statements[$idx], '(', ')');
        # Split the uniq statement "WHEN <instruction>" into two statements : WHEN and <instruction>. 
        replaceSplitStatement($idx, $when, $action);
      }
      elsif ( $statements[$idx] =~ /\A\s*\b(other|otherwise)\b\s*(.*)/is ) {
        # Split the uniq statement "OTHER <instruction>" into two statements : OTHER and <instruction>. 
        replaceSplitStatement($idx, \$1, \$2);
      }
      elsif ( $statements[$idx] =~ /\A${LABEL}(\bif\b(?:.*?))\b(then\b.*)/is ) {
        # Split the uniq statement "IF ... THEN" into two statements : IF and THEN.
        replaceSplitStatement($idx, \$1, \$2);
      }
      elsif ( $statements[$idx] =~ /\A\s*(\bthen\b)(.*)/is ) {
        # Split the uniq statement "THEN <instruction>" into two statements : THEN and <instruction>. 
        replaceSplitStatement($idx, \$1, \$2);
      }
      elsif ( $statements[$idx] =~ /\A${LABEL}(\belse\b)(.*)/is ) {
        # Split the uniq statement "ELSE <instruction>" into two statements : ELSE and <instruction>. 
        replaceSplitStatement($idx, \$1, \$2);
      }
      elsif ( $statements[$idx] =~ /\A${LABEL}(\bon\s+[\w\#\$]+(?:\s*\([^\)]*\))?\s+(?:snap\b)?\s*(system\b)?)(.*)/is ) {
        # Split the uniq statement "ON <condition> [SNAP] (SYSTEM|<instruction>) " 
	# into two statements : "ON condition [SNAP] [SYSTEM]" and "<instruction>",
	# except if "SYSTEM" is specified, because it signifies that the action
# is implicit, and there is then no ON-unit statement. 
	if (!defined $2) {
          replaceSplitStatement($idx, \$1, \$3);
        }
      }
      $idx++;
   }
}

##################################################################
#              PARSE MANAGEMENT ROUTINES
##################################################################

#-----------------------------------------------------------------
# Description : Automatise a try sequence of parse routines.
#
#  - If one routines matches, return the node resulting from the parsing.
#  - If none routine matche, a UnknowKind node is returned.
#-----------------------------------------------------------------
sub tryParse($;$) {
  my ($r_try_list, $r_unexp_list) = @_ ;

  my $node;
  for my $callback ( @$r_try_list ) {
 
    # If a previous parse callback returns undef while the end of the statement
    # list has been encountered, the iteration must end. A unknow node will
    # then be returned. e
    if ( ! $moreStatements ) {
      # This case is theorically impossible, else it would reveal an error. 
      # Indeed a parse function MUST NOT return undef if it has consumed
      # a statement. And a parse function should'nt be called id there is
      # no more statement. So, if a parse function return "undef" while it
      # remained statements when it has been called, there should remain
      # statements after its call, because it is presumed not having consumming
      # any statement. This signifies $moreStatements is not nul !
      print "PARSE ERROR : end statements list encountered when it should'nt...\n";
      last;
    }

    if ( defined ($node = $callback->() )) {
      return $node;
    }
  }
  $node = Node(UnknowKind, getNextStatement());
 print "+++ FOUND UNKNOW statement\n" if ($DEBUG);
 return $node;
}

##################################################################
#              ON statement
##################################################################
sub parseOn() {

  if ( ${nextStatement()} =~ /\A${LABEL}\bon\s+(\S+)/si ) {
    my $name = $1;

    my $onStatement = getNextStatement();
    my $onNode = Node( OnKind, $onStatement); 
    Lib::NodeUtil::SetName($onNode, $name);

    # If the statement is not the implicit action (indicated by SYSTEM)
    # then the following staement should be the ON action. (ON-unit)
    if ($$onStatement !~ /\bsystem\b/si ) {
      if ($moreStatements) {
        # Try to parse instructions ...
        my $node = tryParse(\@UnitParse_List);
        Append($onNode, $node);
      }
     }
     return $onNode;
  }
  else {
    return undef;
  }
}
##################################################################
#              CALL STATEMENT;
##################################################################
sub parseCall() {

   if ( ${nextStatement()} =~ /\bcall\s*([\w\#\$]+)/is ) {
     my $name = $1;
     my $callNode = Node( CallKind, getNextStatement()); 
     Lib::NodeUtil::SetName($callNode, $name);
     return $callNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              SQL STATEMENT
##################################################################
sub parseSQL() {

   if ( ${nextStatement()} =~ /\bexec\s*sql\b/is ) {
       my $SQLNode = Node( SQLKind, getNextStatement()); 
       return $SQLNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              FETCH STATEMENT
##################################################################
sub parseFetch() {

   if ( ${nextStatement()} =~ /(.*?)\bfetch\b(.*)/is ) {
     my $before = $1;
     my $after = $2;
     if ( $before !~ /\bexec\s+sql\b/is ) {
       my $FetchNode = Node( FetchKind, getNextStatement()); 
       return $FetchNode;
     }
     else {
       return undef;
     }
   }
   else {
     return undef;
   }
}

##################################################################
#              NUL STATEMENT;
##################################################################
sub parseNul() {

   if ( ${nextStatement()} !~ /\S/is ) {
     my $nulNode = Node( NulKind, getNextStatement()); 
     return $nulNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              SELECT
##################################################################


sub parseWhenOther() {

   if ( ${nextStatement()} =~ /\b(when|other|otherwise)\b/is ) {
     my $kind = $1;
     my $WhenotherNode;
     if ( $kind =~ /when/is ) {
	$WhenotherNode = Node( WhenKind, getNextStatement()); 
     }
     else {
	$WhenotherNode = Node( OtherwiseKind, getNextStatement()); 
     }

     if ($moreStatements) {
       # Try to parse instructions ...
       my $node = tryParse(\@UnitParse_List);
       Append($WhenotherNode, $node);
       return $WhenotherNode;
     }
     else {
       print "PARSE error : unterminated WHEN/OTHER statement.\n";
     }

     return $WhenotherNode;
   }
   else {
     return undef;
   }
}

sub parseSelect() {
  if ( ${nextStatement()} =~ /(.*?)\bselect\b/is ) {
     my $before = $1;
     if ( $before !~ /\bexec\s+sql\b/is ) {

     #     if ( ${nextStatement()} =~ /\bselect\b/is ) {
         my $SelectNode = Node( SelectKind, getNextStatement()); 
 print "+++ FOUND select statement\n" if ($DEBUG);
         while ($moreStatements) {
           my $node;
           if (defined ($node = parseWhenOther()) ) {
             Append($SelectNode, $node);
           }
           elsif (defined ($node = parseEnd()) ) {
             Append($SelectNode, $node);
print "+++ FIN Select ".${GetStatement($SelectNode)}."\n" if ($DEBUG);
             return $SelectNode;
           }
           else {
             print "PARSE error : bad statement in SELECT while expecting WHEN or OTHER.\n";
	     #exit;
	     # IMPORTANT : Return the incomplete node. Indeed as some statements
	     # have consumed, the parse can't return UNDEF. 
	     return $SelectNode;
           }
         }
         print "PARSE error : unterminated SELECT statement.\n";
	 #exit;
	 # IMPORTANT : Return the incomplete node. Indeed as some statements
	 # have consumed, the parse can't return UNDEF. 
	 return $SelectNode;
	 #   }
       }
       else {
	 # it is a SQL select !!
         return undef;
       }
    }
    else {
      # it is not a select.
      return undef;
    }
}

##################################################################
#              BEGIN block
##################################################################

sub parseEndTerminatedBlock($$) {
     my ($parent, $r_tab_StatementContent) = @_;
     my $node;
     while ($moreStatements) {
       if ( defined ($node = parseEnd())) {
         Append($parent, $node);
print "+++ FIN Terminated block ".${GetStatement($parent)}."\n" if ($DEBUG);
         return $parent;
       }
       else {
         $node = tryParse($r_tab_StatementContent);
         Append($parent, $node);
       }
     }
     print "PARSE error : unterminated ".$parent->[0]." block !!! \n";
     #exit;
     return $parent;
}

##################################################################
#              DO block
##################################################################
sub parseDo() {

   if ( ${nextStatement()} =~ /\A${LABEL}\bdo\b(.*)/si ) {
     my $loopoption = $1;
     my $DoNode;
     if ($loopoption =~ /\b(to|while|until|repeat)\b/si) {
       $DoNode = Node( DoloopKind, getNextStatement()); 
     } 
     else {
       $DoNode = Node( DoKind, getNextStatement()); 
     }

     return parseEndTerminatedBlock($DoNode, \@InstructionParse_List);
   }
   else {
     return undef;
   }
}

##################################################################
#              BEGIN block
##################################################################
sub parseBegin() {

   if ( ${nextStatement()} =~ /\A${LABEL}\b(begin)\b/si ) {
   my $BeginNode = Node( BeginKind, getNextStatement()); 

     return parseEndTerminatedBlock($BeginNode, \@InstructionParse_List);
   }
   else {
     return undef;
   }
}

##################################################################
#              IF / THEN / ELSE
##################################################################

sub parseThen() {
   if ( ${nextStatement()} =~ /\bthen\b/is ) {
     my $ThenNode = Node( ThenKind, getNextStatement()); 

     if ($moreStatements) {
       # Try to parse instructions ...
       my $node = tryParse(\@UnitParse_List);
       Append($ThenNode, $node);
     }
     else {
       print "PARSE error : unterminated THEN statement.\n";
     }
     return $ThenNode;
   }
   else {
     return undef;
   }
}

sub parseElse() {

   if ( ${nextStatement()} =~ /\A${LABEL}\belse\b/is ) {
     my $ElseNode = Node( ElseKind, getNextStatement()); 

     if ($moreStatements) {
       # Try to parse instructions ...
       my $node = tryParse(\@UnitParse_List);
       Append($ElseNode, $node);
     }
     else {
       print "PARSE error : unterminated ELSE statement.\n";
     }

     return $ElseNode;
   }
   else {
     return undef;
   }
}

sub parseIf() {
   my $next = ${nextStatement()} ;

   if ( ${nextStatement()} =~ /\A${LABEL}\bif\b\s*[^=]/is ) {
     my $IfNode = Node( IfKind, getNextStatement()); 

     my $ThenNode;
     if (defined ($ThenNode = parseThen()) ) {
       Append($IfNode, $ThenNode);
     } 
     else {
       print "PARSE error : No corresponding THEN for IF\n";
     }

     my $ElseNode;
     if (defined ($ElseNode = parseElse()) ) {
       Append($IfNode, $ElseNode);
     } 

     return $IfNode; 
   }
   else {
     return undef;
   }
}

##################################################################
#              DECLARE
##################################################################
sub parseDefault() {

   if ( ${nextStatement()} =~ /^\s*\b(dft|default)\b/si ) {
     my $defaultNode = Node( DefaultKind, getNextStatement()); 
     return $defaultNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              DECLARE
##################################################################
sub parseDeclare() {

   if ( ${nextStatement()} =~ /^\s*\b(dcl|declare)\b/si ) {
     my $declareNode = Node( DeclareKind, getNextStatement()); 
     return $declareNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              END
##################################################################
sub parseEnd() {


   if ( ${nextStatement()} =~ /\A${LABEL}\bend\b\s*([\w\#\$]*)?/si ) {
     my $tag = $1;
     my $endNode = Node( EndKind, getNextStatement()); 
     if ( defined $tag ) {
       Lib::NodeUtil::SetName($endNode, $tag);
     }	     
     return $endNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              GO TO 
##################################################################
sub parseGoto() {

   if ( ${nextStatement()} =~ /\A${LABEL}\b(go\s+to)\b/si ) {
     my $endGoto = Node( GotoKind, getNextStatement()); 
     return $endGoto;
   }
   else {
     return undef;
   }
}
##################################################################
#              ENTRY 
##################################################################
sub parseEntry() {
   if ( ${nextStatement()} =~ /\A${LABEL}\b(entry)\b/si ) {
     my $endEntry = Node( EntryKind, getNextStatement()); 
     return $endEntry;
   }
   else {
     return undef;
   }
}
##################################################################
#              PROCEDURE
##################################################################
sub parseProcedure() {

   if ( ${nextStatement()} =~ /([\#\w\$]+)\s*:\s*\b(procedure|proc)\b/si ) {
   my $name = $1;

   my $procedureNode = Node( ProcedureKind, getNextStatement()); 
   Lib::NodeUtil::SetName($procedureNode, $name);
print "+++ Debut PROC $name\n" if ($DEBUG);
     my @try_list = (@InstructionParse_List, \&parseProcedure);

     my $node;
     while ($moreStatements) {
       if ( defined ($node = parseEnd())) {
         Append($procedureNode, $node);
print "+++ Fin PROC $name\n" if ($DEBUG);
         return $procedureNode;
       }
       else {
         $node = tryParse(\@try_list);
         Append($procedureNode, $node);
       }
     }
     print "PARSE error : unterminated procedure !!! \n";
     #exit;  
     # IMPORTANT : Return the incomplete node. Indeed as some statements
     # have consumed (creation of a node), the parse can't return UNDEF. 
     return $procedureNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              PACKAGE
##################################################################
sub parsePackage() {

   if ( ${nextStatement()} =~ /\b(package)\b/si ) {
     my $packageNode = Node( PackageKind, getNextStatement()); 
     
     my @try_list = (\&parseDeclare, \&parseProcedure, \&parseDefault);

     my $node;
     while ($moreStatements) {
       if ( defined ($node = parseEnd())) {
         Append($packageNode, $node);
print "+++ FIN Package\n" if ($DEBUG);
         return $packageNode;
       }
       else {
         $node = tryParse(\@try_list);
         Append($packageNode, $node);
       }
     }
     print "PARSE error : unterminated package !!! \n";
     #exit;
     # IMPORTANT : Return the incomplete node. Indeed as some statements
     # have consumed (creation of a node), the parse can't return UNDEF. 
     return $packageNode;
   }
   else {
     return undef;
   }
}

##################################################################
#              ROOT
##################################################################
sub parseRoot() {
  
  my $Root = Node(RootKind, undef);

  my @try_list = (@InstructionParse_List, \&parseProcedure, \&parsePackage);

  my $node;
  while ($moreStatements) {
    $node = tryParse(\@try_list);
    Append($Root, $node);
  }
  return $Root;
}

# description: PL1 parse module Entry point.
sub Parse($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $status = 0;

    init_parser();

     # Dupplication of the 'sansprepro' view in order to suppress blanks
     # whithout modifying the original view that could be used by another way...

     my $DupSansprepro = $vue->{'sansprepro'} ;
     # remove end line old-format pattern ...
     $DupSansprepro =~ s/([^\d])\d[\d\*]*$/$1/sgm;

     # 1) Removing of line white characters that slow the regular
     # expressions when there are in a huge amount.
     # 2) remove isolated "/" that could be found before instructions ...
     $DupSansprepro =~ s/\A\s*(?:\/)?/ /sgm;
     $DupSansprepro =~ s/;\s*(?:\/)?/;/sgm;

#    my $statements =  $vue->{'statements_with_blanks'} ;
     @statements = split (/;/, $DupSansprepro);
 
     # if the last statement is a Null statement, it should be removed
     # because it is not significant.
     if ($statements[-1] !~ /\S/ ) {
       pop @statements ;
     }

     splitCompoundStatement();

#      my @statementReader = ( $statements, 0);
#      

      my $rootNode = parseRoot();

      Lib::Node::Dump($rootNode, *STDOUT, "ARCHI") if ($DEBUG);
      
      $vue->{'structured_code'} = $rootNode;
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
