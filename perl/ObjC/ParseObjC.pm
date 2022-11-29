package ObjC::ParseObjC;
# les modules importes
use strict;
use warnings;
#use diagnostics; #FIXME: est-ce compatible Strawberry?
#no warnings 'recursion'; 

use Erreurs;

use CountUtil;
use ObjC::Ternary;

use Lib::Node;
use Lib::Node qw( Leaf Node Append );
use Lib::ParseUtil;

use ObjC::ObjCNode ;
use ObjC::ObjCNode qw( SetName SetStatement SetLine GetLine); 
use ObjC::ParseObjCPass2;

my $DEBUG = 1;

my $C_SEPARATOR = ';|{|}';
my $OBJC_SEPARATOR = '\@(?:interface|implementation|end|property|synthesize|public|private|protected|package)\b';
my $STATEMENT_SEPARATOR = $C_SEPARATOR.'|'.$OBJC_SEPARATOR;

my $NullString = '';



##############################################################################
#          SCOPE
##############################################################################

sub ROOT_SCOPE {return  0;}
sub OBJC_CLASS_INTERFACE_SCOPE {return 1;}
sub OBJC_CLASS_IMPLEMENTATION_SCOPE {return 2;}
sub OBJC_CLASS_ATTRIBUTE_SCOPE {return 3;}
sub OBJC_FUNCTION_SCOPE {return 4;}

my @ScopeLevel = ( ROOT_SCOPE, # type
          	   'ObjC');     # name

my @Scope = ();

sub initScope() {
  @Scope = ();
  push @Scope, \@ScopeLevel;
}

sub getCurrentScope() {
  return $Scope[-1];
}

sub getCurrentScopeType() {
  return $Scope[-1]->[0];
}

sub pushScope($;$) {
  my $type = shift;
  my $name = shift;

  if (! defined $name) {
    $name = "";
  }

  push @Scope, [ $type, $name ];
}

sub popScope() {
  if (scalar @Scope > 0) {
    return pop @Scope;
  }
  else {
    return undef;
  }
}

##############################################################################
#          PARSING CONTEXTS
##############################################################################

# Possible instructions / contexts
# --------------------------------
# Instructions are statement ended with a ";"
my @DefaultInstructionList = (\&parseEmpty);
my @ObjCClassInterfInstructionList = (\&parseEmpty, \&parseObjCMethod);
my @ObjCClassImplInstructionList = (\&parseEmpty, \&parseObjCMethod);
my @ObjCClassAttribInstructionList = (\&parseEmpty, \&parseBlockDeclaration, \&parseObjCAttribute);
my @ObjCFunctionInstructionList = (\&parseEmpty, \&parseIf, \&parseElse, \&parseWhile, \&parseFor, \&parseFor, \&parseDo, \&parseBlockDeclaration);

my %InstructionListDB = (OBJC_CLASS_INTERFACE_SCOPE() => \@ObjCClassInterfInstructionList,
                         OBJC_CLASS_IMPLEMENTATION_SCOPE() => \@ObjCClassImplInstructionList,
                         OBJC_CLASS_ATTRIBUTE_SCOPE() => \@ObjCClassAttribInstructionList,
                         OBJC_FUNCTION_SCOPE() => \@ObjCFunctionInstructionList
                        );

# Possible structs / contexts (statement ended with a "{"
# -------------------------------------------------------

# default context
my @ObjC_Default_Struct_List = (\&ObjC::ParseObjCPass2::parseBlock, \&parseIf, \&parseElse, \&parseWhile, \&parseFor, \&parseFor, \&parseDo, \&parseEnum);

# class implementation context.
my @ObjC_ClassImpl_Struct_List = (\&parseEnum, \&parseObjCMethod, \&ObjC::ParseObjCPass2::parseBlock);

my %StructListDB = (OBJC_CLASS_IMPLEMENTATION_SCOPE() => \@ObjC_ClassImpl_Struct_List
                   );

# Possible content in a ObjC keyword (@xxx)
# -----------------------------------------
my @ObjCContent = ( \&parseInterface, \&parseImplementation, \&parseProperty, \&parseSynthesize );


my @ControlFlowContent = ();

sub getPossibleInstructionList($) {
  my $type_scope = shift;
  if (exists $InstructionListDB{$type_scope}) {
    return $InstructionListDB{$type_scope};
  }
  else {
    return \@DefaultInstructionList;
  }
}

sub getPossibleStructList($) {
  my $type_scope = shift;
  if (exists $StructListDB{$type_scope}) {
    return $StructListDB{$type_scope};
  }
  else {
    return \@ObjC_Default_Struct_List;
  }
}



##############################################################################
#          UNKNOW
##############################################################################

# All unrecognized statement are intended to be semicolon terminated instruction.
# SO, all statement are concatened to re-compose the instruction.
sub parseUnknow() {
  my $stmt = "";

  if (! defined nextStatement() ) { return undef;}

  while (defined nextStatement()&&
         (${nextStatement()} ne ';')) {

    $stmt .= ${getNextStatement()};
  }

  my $node;
  if ( $stmt !~ /\S/sm ) {
    $node = Node(EmptyKind, \$stmt); 
  }
  else {
    $node = Node(UnknowKind, \$stmt);
  }

  if ( ! defined nextStatement()) {
    print "syntax ERROR : missing \";\" for instruction at line ".getStatementLine()."\n";
  }  
  else {
    trashSemiColon();
  }
  return $node;
}

##################################################################
#              EMPTY STATEMENT
##################################################################

sub parseEmpty(;$) {
   my $r_stmt = shift;

  if ( (${nextStatement()} eq ';') && ( defined $r_stmt ) && ( $$r_stmt =~ /^\s*$/s)) {
    # Consumes the separator
    getNextStatement();
    return Node(EmptyKind, \$NullString)
  }
  else {
    return undef;
  }
}

##################################################################
#              ObjC ATTRIBUTE
##################################################################

sub parseObjCAttribute(;$) {
   my $r_stmt = shift;

  if ( (${nextStatement()} =~ /[;]/) && ( defined $r_stmt ) ) {

      # Consumes the separator
      getNextStatement();

      my $kind = ObjCAttribKind;

      # Do not count ',' that are in a struct definition :
      # struct {
      #    unsigned int usesTime:1;
      #    unsigned int usesMVP:1;
      #    int riri, fifi, loulou;
      # } _flags;
      if ( $$r_stmt =~ /,[^}]*$/s ) {
        $kind = ObjCMultAttribKind;
      }

      my $node = Node($kind, $r_stmt);

      return $node;
  }
  return undef;
}

##################################################################
#              IF
##################################################################

sub parseIf(;$) {
   my $r_stmt = shift;

  if ( (${nextStatement()} =~ /[;\{]/) && ( defined $r_stmt ) ) {

    if ( $$r_stmt =~ /^\s*if\b/s ) {

      my $IfNode = Node(IfKind, \$NullString);

      # Capture condition and "then" statement.
      # ---------------------------------------
      my ($r_cond, $r_then) = CountUtil::splitAtPeer($r_stmt, '(', ')');

      $$r_cond =~ s/^\s*if\b\s*//s;
      Append($IfNode, Node(CondKind, $r_cond));

      # Parse Then statement
      # --------------------
      my $ThenNode = Node(ThenKind, \$NullString);
      
      # if the statement between the condition and the separator ({ or ;) is not empty,
      # then try to parse it. This case corresponds to a "if" whithout accolade
      if ($$r_then =~ /\S/s) {
        my $node = Lib::ParseUtil::tryParse_OrUnknow([ \&parseStatement ], $r_then);
        Append($ThenNode, $node);
      }
      else {
      # else two case : 
        # 1 - "if" with accolade ==> parse the bloc defined by the accolade
        if (${nextStatement()} eq "{") {
	  # consumes the separator
          getNextStatement();

          my $possibleContent = [ \&parseStatement ];
          Append ($ThenNode, Lib::ParseUtil::parseCodeBloc(AccoladeKind, [ \&Lib::ParseUtil::isNextClosingCurlyBrace ], $possibleContent, 0));
        }
	# 2 - "if" with empty "then" (ex : if (toto) ;) ==> create an empty "then node" !
        else {  # separator is ";"
          # Consumes the separator
          my $sep = getNextStatement();

          Append($ThenNode, Node(EmptyKind, $r_stmt));
        }
      }

      Append($IfNode, $ThenNode);

      if ( ${nextStatement()} =~ /^\s*else\b/s) {
        Append($IfNode, parseStatement());
      }

      return $IfNode;
    }
  }
  return undef;
}


##################################################################
#              ELSE
##################################################################

sub parseElse(;$) {
   my $r_stmt = shift;

  if ( (${nextStatement()} =~ /[;\{]/) && ( defined $r_stmt ) ) {

    if ( $$r_stmt =~ /^\s*else\b/s ) {

      my $ElseNode = Node(ElseKind, \$NullString);

      # Capture else branch statement.
      # ---------------------------------------
      my $branch = $$r_stmt;
      $branch =~ s/^\s*else\b\s*//s;

      # Parse Else statement
      # --------------------
      
      # if the statement between the condition and the separator ({ or ;) is not empty,
      # then try to parse it. This case corresponds to a "else" whithout accolade
      if ($branch =~ /\S/s) {
        my $node = Lib::ParseUtil::tryParse_OrUnknow([ \&parseStatement ], \$branch);
        Append($ElseNode, $node);
      }
      else {
      # else two case : 
        # 1 - "if" with accolade ==> parse the bloc defined by the accolade
        if (${nextStatement()} eq "{") {
	  # consumes the separator
          getNextStatement();

          my $possibleContent = [ \&parseStatement ];
          Append ($ElseNode, Lib::ParseUtil::parseCodeBloc(AccoladeKind, [ \&Lib::ParseUtil::isNextClosingCurlyBrace ], $possibleContent, 0));
        }
	# 2 - "if" with empty "then" (ex : if (toto) ;) ==> create an empty "then node" !
        else {  # separator is ";"
          # Consumes the separator
          my $sep = getNextStatement();

          Append($ElseNode, Node(EmptyKind, $r_stmt));
        }
      }

      return $ElseNode;
    }
  }
  return undef;
}

##################################################################
#              LOOP
##################################################################

sub parseLoop($$;$) {
   my $kind = shift;
   my $keyword = shift;
   my $r_stmt = shift;

  if ( (${nextStatement()} =~ /[;\{]/) && ( defined $r_stmt ) ) {

    if ( $$r_stmt =~ /^\s*$keyword\b/s ) {

      my $LoopNode = Node($kind, \$NullString);

      # Capture condition and the branch statement.
      # ---------------------------------------
      my ($r_cond, $r_branch) = CountUtil::splitAtPeer($r_stmt, '(', ')');

      $$r_cond =~ s/^\s*$keyword\b\s*//s;
      Append($LoopNode, Node(CondKind, $r_cond));

      # Parse the branch statement
      # --------------------------
      
      # if the statement between the condition and the separator ({ or ;) is not empty,
      # then try to parse it. This case corresponds to a loop whithout accolade
      if ($$r_branch =~ /\S/s) {
        my $node = Lib::ParseUtil::tryParse_OrUnknow([ \&parseStatement ], $r_branch);
        Append($LoopNode, $node);
      }
      else {
      # else two case : 
        # 1 - "if" with accolade ==> parse the bloc defined by the accolade
        if (${nextStatement()} eq "{") {
	  # consumes the separator
          getNextStatement();

          my $possibleContent = [ \&parseStatement ];
          Append ($LoopNode, Lib::ParseUtil::parseCodeBloc(AccoladeKind, [ \&Lib::ParseUtil::isNextClosingCurlyBrace ], $possibleContent, 0));
        }
	# 2 - "if" with empty "then" (ex : if (toto) ;) ==> create an empty "then node" !
        else {  # separator is ";"
          # Consumes the separator
          my $sep = getNextStatement();

          Append($LoopNode, Node(EmptyKind, $r_stmt));
        }
      }

      return $LoopNode;
    }
  }
  return undef;
}

sub parseWhile(;$) {
  my $r_stmt = shift;
  return parseLoop(WhileKind, "while", $r_stmt);
}

sub parseFor(;$) {
  my $r_stmt = shift;
  return parseLoop(ForKind, "for", $r_stmt);
}

sub parseForeach(;$) {
  my $r_stmt = shift;
  return parseLoop(ForeachKind, 'for\s*each', $r_stmt);
}

##################################################################
#              DO
##################################################################

sub parseDo(;$) {
   my $r_stmt = shift;

  if ( (${nextStatement()} =~ /[;\{]/) && ( defined $r_stmt ) ) {

    if ( $$r_stmt =~ /^\s*do\b/s ) {

      my $DoNode = Node(DoKind, \$NullString);

      # Capture branch statement.
      # ---------------------------------------
      my $branch = $$r_stmt;
      $branch =~ s/^\s*do\b\s*//s;

      # Parse branch statement
      # ----------------------
      
      # if the statement between the condition and the separator ({ or ;) is not empty,
      # then try to parse it. This case corresponds to a "do" whithout accolade
      if ($branch =~ /\S/s) {
        my $node = Lib::ParseUtil::tryParse_OrUnknow([ \&parseStatement ], \$branch);
        Append($DoNode, $node);
      }
      else {
      # else two cases : 
        # 1 - "do" with accolade ==> parse the bloc defined by the accolade
        if (${nextStatement()} eq "{") {
	  # consumes the separator
          getNextStatement();

          my $possibleContent = [ \&parseStatement ];
          Append ($DoNode, Lib::ParseUtil::parseCodeBloc(AccoladeKind, [ \&Lib::ParseUtil::isNextClosingCurlyBrace ], $possibleContent, 0));
        }
	# 2 - "do" with empty instruction (ex : do ; while(toto);) ==> create an empty "then node" !
        else {  # separator is ";"
          # Consumes the separator
          my $sep = getNextStatement();

          Append($DoNode, Node(EmptyKind, $r_stmt));
        }
      }

      if ( ${nextStatement()} =~ /^\s*while\b/s) {
        Append($DoNode, parseStatement());
      }
      else {
        print "Parse ERROR : missing while for do statement !\n"; 
      }

      return $DoNode;
    }
  }
  return undef;
}

##################################################################
#              ENUM
##################################################################

sub parseEnum(;$) {
   my $r_stmt = shift;

  # block prototype pattern :    ^type(param1, ... , paramN) {
  if ( (${nextStatement()} =~ /\{/) && ( defined $r_stmt ) &&
		( $$r_stmt =~ /\benum(\s+\w+)?\s*$/sm)) {
    my $statement = $$r_stmt;

    my $line = getStatementLine();

    while ( (defined nextStatement()) && (${nextStatement()} !~ /[;]/s)) {
      $statement .= ${getNextStatement()};
    }

    if ( ! defined nextStatement() ) {
      # the enum should has ended with a ';', else it's an error.
      print "parse ERROR : unterminated enum beginning at line : $line";
    }
    else {
      # consumes the ';'
      $statement .= ${getNextStatement()};
    }

    # create the Enum node.
    my $enumNode = Node(EnumKind, \$statement);
    SetLine($enumNode, $line);

    return $enumNode;
  }
  return undef;
}



##################################################################
#              ObjC BLOCKS
##################################################################

sub parseBlockDeclaration(;$) {
   my $r_stmt = shift;

  if ( (${nextStatement()} eq ';') && ( defined $r_stmt ) ) {

    if ( $$r_stmt =~ /^\s*\w*\s*[*&]?\s*\s*\(\s*\^\s*(\w+)\s*\)/s ) {

#print "BLOCK DECL = <$$r_stmt>\n";
      my $blockDecl = Node(BlockDeclKind, $r_stmt);
      SetName($blockDecl, $1);
      
      # trashes the semi-colon
      getNextStatement();

      return $blockDecl;
    }
  }
  return undef;
}

##################################################################
#              ObjC METHOD
##################################################################


sub parseObjCMethodBody() {

  # trashes the '{' that begins the list of attributes.
  getNextStatement();

  pushScope(OBJC_FUNCTION_SCOPE);

  my $possibleContent = [ \&parseStatement ];
  my $attrib = Lib::ParseUtil::parseCodeBloc(AccoladeKind, [ \&Lib::ParseUtil::isNextClosingCurlyBrace ], $possibleContent, 0);

  popScope();

  return $attrib;
}

sub parseObjCMethod(;$) {
   my $r_stmt = shift;

  if ( (${nextStatement()} =~ /[;\{]/) && ( defined $r_stmt ) ) {

    # +/- (void) setPersonName: (char *)name andAge:(int)age andHeight:(float)height {
    my $visibility = '(?:[+-])?';
    my $return = '(?:\([^()]+\))?';
    my $name = '(?:\w+)';
    if ( $$r_stmt =~ /^\s*$visibility\s*$return\s*($name)/ ) {

      my $methodName = $1;

      my $node;
      if (${nextStatement()} eq "{") {
        $node = Node(ObjCMethodImplKind, $r_stmt);
	Append($node, parseObjCMethodBody());
      }
      else {
        # Consumes the separator
        my $sep = getNextStatement();
        $node = Node(ObjCMethodDeclKind, $r_stmt);
      }
      SetName($node, $methodName);
      return $node;
    }
  }
  return undef;
}

##################################################################
#              SEMICOLON TERMINATED OBJC
##################################################################



sub parseSemiColonTerminatedObjC($) {
   my $kind = shift;

    # Consummes the @Property .
    my $Node = Node($kind, \$NullString );
    getNextStatement();

    my $statement = "";
    while ( (defined nextStatement()) && (${nextStatement()} ne';') ) {
      $statement .= ${getNextStatement()};
    }

    if ( ! defined nextStatement() ) {
      print "Parse ERROR : unexpected end of ".$kind." definition !!\n";
      return $Node;
    }

    # trashes the ";"
    getNextStatement();
    SetStatement($Node, \$statement);
    return $Node;
}


sub isNextProperty() {
   if ( ${nextStatement()} eq '@property' ) {
     return 1;
   }
   return 0;
} 

sub parseProperty(;$) {
   my $stmt = shift;

  if  ( isNextProperty() ) {
    my $node = parseSemiColonTerminatedObjC(PropertyKind);
    my $stmt = GetStatement($node);
    if ( $$stmt =~ /(\w+)\s*$/sm ) {
      SetName($node, $1);
    }
    return $node;
  }
  else {
    return undef;
  }
}

sub isNextSynthesize() {
   if ( ${nextStatement()} eq '@synthesize' ) {
     return 1;
   }
   return 0;
} 

sub parseSynthesize(;$) {
   my $stmt = shift;

  if  ( isNextSynthesize() ) {
    return parseSemiColonTerminatedObjC(SynthesizeKind);
  }
  else {
    return undef;
  }
}

##################################################################
#              INTERFACE
##################################################################

my $defaultVisibility = ProtectedKind;

sub setAttributeDefaultVisibility($) {
  my $visib = shift;
  $defaultVisibility = $visib
}

sub parseVisibility(;$) {
  my $stmt = shift;

  my $kind;
  my $visib = "";
  if ( (${nextStatement()} =~ /\@(?:public|private|protected|package)\b/ )) {
    my $visib = ${getNextStatement()};

    if ($visib eq '@private') {
      $kind = PrivateKind;
    }
    elsif ($visib eq '@public') {
      $kind = PublicKind;
    }
    elsif ($visib eq '@package') {
      $kind = PackageKind;
    }
    else {
      $kind = ProtectedKind;
    }
  }
  else {
      $kind = $defaultVisibility;
      $visib = "<implicit>";
  }

  my $visibNode = Node ($kind, \$visib);

  my $possibleContent = [ \&parseInstruction ];

  while ((defined nextStatement()) && (${nextStatement()} !~ /\}|\@/)) {
    my $node = Lib::ParseUtil::tryParse($possibleContent);

    if (defined $node) {
      Append($visibNode, $node);
    }
    else {
      # parseInstruction returns "undef" only when encountering an objective C
      # structural keyword 
    }
  }
  return $visibNode;
}

sub parseInterfaceAttributes() {

  # trashes the '{' that begins the list of attributes.
  getNextStatement();

  pushScope(OBJC_CLASS_ATTRIBUTE_SCOPE);

  my $possibleContent = [ \&parseVisibility ];
  my $attrib = Lib::ParseUtil::parseCodeBloc(AttribBlocKind, [ \&Lib::ParseUtil::isNextClosingCurlyBrace ], $possibleContent, 0);

  popScope();

  return $attrib;
}

sub isNextInterface() {
   if ( ${nextStatement()} eq '@interface' ) {
     return 1;
   }
   return 0;
}  

sub parseInterface(;$) {
   my $stmt = shift;

  if ( isNextInterface() ) {

    # Consummes the @interface element.
    getNextStatement();
    my $InterfaceNode = Node(InterfaceKind, \$NullString);
    SetLine($InterfaceNode, getStatementLine());

    # split next statement after the class name 
    Lib::ParseUtil::splitNextStatementAfterPattern('\s*\w+\s*');
    my $ClassName = ${getNextStatement()};
    $ClassName =~ s/\s//g;
    SetStatement($InterfaceNode, \$NullString);
    SetName($InterfaceNode, $ClassName);

    pushScope(OBJC_CLASS_INTERFACE_SCOPE, $ClassName);

    # split next statement after the class options ...
    #
    # ${getNextSt
    # interfaces options :  [:parent] [([category])] [<protocol1 [, ..., protocoleN]>]
    my $InterfaceOptionsPattern = 
                      '\s*(?::\s*\w+)?(?:\s*\(\s*\w*\s*\))?(?:\s*<\s*\w+(?:\s*,\s*\w*)*\s*>)?\s*';
    if (${nextStatement()} =~ /^$InterfaceOptionsPattern/) {
      Lib::ParseUtil::splitNextStatementAfterPattern($InterfaceOptionsPattern);
      my $stmt = getNextStatement();
      SetStatement($InterfaceNode, $stmt );
    }

    # If any, parse attributes of the interface.
    if ( defined nextStatement() ) {
      if ( ${nextStatement()} eq '{') {
	setAttributeDefaultVisibility(ProtectedKind);
        my $attribNode = parseInterfaceAttributes();
        Append($InterfaceNode, $attribNode);
      }
      elsif ( ${nextStatement()} eq ';') {
        # No accolades were found... don't know if this is a realistic case, but in this case,
	# trashes the semicolon !
	getNextStatement();
      }

      #parse content of the interface :
      while ( defined nextStatement() ) {
        if ( ${nextStatement()} ne '@end' ) {
          Append($InterfaceNode, Lib::ParseUtil::tryParse_OrUnknow([ \&parseStatement ] ));
        }
        else {
	  # trashes the @end
	  getNextStatement();

	  # Nominal exit.
          popScope();
          return $InterfaceNode;
        }
      }
    }

    print "Parse ERROR : missing end of interface (2)!!\n";

    # exit on error.
    popScope();
    return $InterfaceNode;
  }
  else {
    return undef;
  }
}

##################################################################
#              IMPLEMENTATION
##################################################################

sub isNextImplementation() {
   if ( ${nextStatement()} eq '@implementation' ) {
     return 1;
   }
   return 0;
}  

sub parseImplementation(;$) {
   my $stmt = shift;

  if ( isNextImplementation() ) {

    # Consummes the @implementation element.
    getNextStatement();
    my $ImplementationNode = Node(ImplementationKind, \$NullString);
    SetLine($ImplementationNode, getStatementLine());

    if (  defined nextStatement() ) {
      Lib::ParseUtil::splitNextStatementAfterPattern('\s*\w+\s*(?::\s*\w+\s*)?(?:\([^)]*\))?');
      my ($ClassName, $options) = ${getNextStatement()} =~ /\s*(\w+)(.*)/s;

      SetStatement($ImplementationNode, \$options);
      SetName($ImplementationNode, $ClassName);

      if ( defined nextStatement() ) {
        if ( ${nextStatement()} eq '{') {
	  setAttributeDefaultVisibility(PrivateKind);
          my $attribNode = parseInterfaceAttributes();
          Append($ImplementationNode, $attribNode);
        } 
      }

      pushScope(OBJC_CLASS_IMPLEMENTATION_SCOPE, $ClassName);

      #parse content of the implementation :
      while ( defined nextStatement() ) {
        if ( ${nextStatement()} ne '@end' ) {
          Append($ImplementationNode, Lib::ParseUtil::tryParse_OrUnknow([ \&parseStatement ] ));
        }
        else { 
	  # trashes the @end
	  getNextStatement();

   	  # nominal exit
	  popScope();
          return $ImplementationNode;
        }
      }
    }

    print "Parse ERROR : unexpected end of implementation !!\n";

    # exit on error
    popScope();
    return $ImplementationNode;
  }
  else {
    return undef;
  }
}

##################################################################
#              STATEMENT
##################################################################

# Parse until encountered the next ";" or "@" (instruction separator)
# When encountered it:
# -- if the statement found is empty and the separator is "@", then
# returns noting. Indeed, a blank statement before a ";" is an empty statement, while
# before a "@xxx" it is nothing.
# -- else try parse the statement found or return unknow statement if can not parse.
#
# Prerequisite:
# - next statement should be defined.
sub parseInstruction() {
 
  my $statement = "";
  my $possibleContent = getPossibleInstructionList(getCurrentScopeType());


  # Default line number, if no instruction if found before the next separator.
  my $SeparatorLine = getNextStatementLine();

  # Will be set when retriving the next instruction.
  my $InstrLine = undef;
  my $nb_OpenningAcco = 0;
  my $nb_ClosingAcco = 0;

  while (defined nextStatement()) {

    # The instruction will end on the next ';' or the next '@' (except '@"').
    # Rq : if openning braces are not equal to closing braces (or parenthesis), then
    # the ";" is inside a struct belonging to the instruction. It it not the
    # end of the instruction
    if ( 
	 (${nextStatement()} =~ /^(?:[^\@]|\@")/m ) &&
	 ( 
	   (${nextStatement()} ne ";" ) ||
	   ( $nb_OpenningAcco !=  $nb_ClosingAcco)
	 )
       ) {
      if (${nextStatement()} eq "{" ) {
        $nb_OpenningAcco++;
      }
      elsif (${nextStatement()} eq "}" ) {
	$nb_ClosingAcco++;
      }

      $statement .= ${getNextStatement()};

      if ( ! defined $InstrLine ) {
        $InstrLine = getStatementLine();
      }
    }
    else {

      # CASE OF NOTHING FOUND
      if ((${nextStatement()} =~ /^\@/m ) && ($statement !~ /\S/)) {
	# if the instruction parsing has ended on an "obj C" separator and the instruction
	# is empty, then it is not an empty statement, so return nothing.
        return undef; 
      }

      # ELSE ... 
      my $node = Lib::ParseUtil::tryParse($possibleContent, \$statement);
      
      if (! defined $node) {
        # Create an unknow statement node.
        $node = Node(UnknowKind, \$statement);

        # trashes the ";"
	getNextStatement();
      }
      
      if (! defined $InstrLine) {
        # For robustness only, but should never occur : all separators should be preceded by an
        # instruction whose line should have been set when getting the instruction ...
        $InstrLine = $SeparatorLine;
      }
      SetLine($node, $InstrLine);
      return $node;
    }
  }
  print "Parse ERROR : encountered unterminated instruction\n";
  return Node(UnknowKind, \$statement);
}

##################################################################
#              STATEMENT
##################################################################

# Parse until encountered the next separator.
# Prerequisite:
# - next statement should be defined.
sub parseStatement(;$) {
  my $r_stmt = shift;

  my $statement = "";

  if (defined $r_stmt) {
    $statement = $$r_stmt;
  }

  my $nb_openning_parent = 0;
  my $nb_closing_parent = 0;
  my $nb_openning_bracket = 0;
  my $nb_closing_bracket = 0;

  # Default line number, if no instruction if found before the next separator.
  my $SeparatorLine = getNextStatementLine();

  # Will be set when retriving the next instruction.
  my $InstrLine = undef;

  # Statements are sequential, but there are exceptions, for exemple when parsing
  # blocks => blocks can be declared inside other instruction. In this cas, the
  # instruction that contains blocks can not be parsed until the blocks have been
  # parsed and reduced to a subnode.
  # used to memorize the subnode(s) of the statement beeing analyzed. 
  my $FixmeNode = undef;

  while (defined nextStatement()) {
    if ((${nextStatement()} =~ /($STATEMENT_SEPARATOR)/ ) &&
	# separators that are enclosed inside parenthesis or bracket are
	# considered belonging to the instruction, not ending it.
	#    Example : ";" in a "for" close,
	#                       ==> for (i=0; i<max; i++) {...
	#              "{" and "}" of a block definition  use in a call 
	#                       ==> a = [ myObj meth:^(){i++;} ] ;
	($nb_openning_parent == $nb_closing_parent)   &&
	($nb_openning_bracket == $nb_closing_bracket) ) {

	my $separator = $1;
	my $possibleContent;
	my $node = undef;

	# 1 - check separator type and load corresponding parse context.
	# ----------------------------------------------------------
	if ( $separator eq '{' ) {
	  $possibleContent = getPossibleStructList(getCurrentScopeType());
	}
	elsif ( $separator eq ';' ) {
	   $possibleContent = getPossibleInstructionList(getCurrentScopeType());
	}
	elsif ( $separator =~ /\@\w+/ ) {
	  # all statement before an ObjC directive should have been consummed (should have
	  # matched with the previous statement)
          if ($statement ne "") {
            print "Parse WARNING : missing separator for statement $statement.";
            $node = Node(UnknowKind, \$statement); 
          }

	  $possibleContent = \@ObjCContent;
	}
	elsif ($separator eq '}' ) {
          $node = Node(UnknowKind, \$statement);
          print "Parse NOTE : encountered suspicious closing bracket after statement :\n$statement\n";
	}
	else {
	  print "Parse ERROR : encountered unknown separator : $separator !\n";
	}


	# 2 - Parse statement
	# ----------------
	# If node has not already been set, try to parse the statement.
	if (! defined $node) { 
	  $node = Lib::ParseUtil::tryParse($possibleContent, \$statement);
        }

	# 3 - case of an Unknow statement
	# ----------------------------
        if (! defined $node) {

	  # if nothing matched, then the separator has not been consumed. Get it !
	  my $separator = ${getNextStatement()};

	  # Create an unknow statement node.
	  $node = Node(UnknowKind, \$statement);

          # This unknow statement is a structured statement. Parse it !
          if ($separator eq '{' ) {
	    # Content of this structure is assumed to be any kind of statement.
	    $possibleContent = [ \&parseStatement ];
	    my $subnode = Lib::ParseUtil::parseCodeBloc(AccoladeKind, [ \&Lib::ParseUtil::isNextClosingCurlyBrace ], $possibleContent, 0);
            if (defined $subnode) {
	      Append($node, $subnode);
	    }
          }
        }

	# 4 - set statement beginning line number.
	# ----------------------------------------
	if (! defined $InstrLine) {
	  # For robustness only, but should never occur : all separators should be preceded by an
	  # instruction whose line should have been set when getting the instruction ...
          $InstrLine = $SeparatorLine;
        }
        SetLine($node, $InstrLine);

	# 5 - return node or continue parsing if needed.
	# ----------------------------------------------
        if (! IsKind($node, FixmeKind)) {
	  if (defined $FixmeNode) {
	    # if $FixmeNode is defined, this signifies that the $node is the result
	    # of parsing a FixmeKind node statement. So, append children to it.
	    for my $child (@{ObjC::ObjCNode::GetChildren($FixmeNode)}) {
	      Append($node, $child);
	    }
          }

	  return $node;
	}

	# 6 - treatment of Fixme node
	# statement is updated to the rest that has not been parsed by the parse
	# callback. This resulting code statement has been stored in the fixme node.
        $statement = ${GetStatement($node)};

	if (! defined $FixmeNode) {
	  # keep the Fixme Node as local fixme node ...
	  $FixmeNode = $node;
	}
	else {
	  # Add the child of the fixme node to the local fixme node.
	  Append($FixmeNode, ObjC::ObjCNode::GetChildren($node)->[0] )
	}

    }
    else {
      my $r_next = getNextStatement();
      $nb_openning_parent += () = $$r_next =~ /\(/g;
      $nb_closing_parent += () = $$r_next =~ /\)/g;
      $nb_openning_bracket += () = $$r_next =~ /\[/g;
      $nb_closing_bracket += () = $$r_next =~ /\]/g;
      $statement .= $$r_next;
      if (! defined $InstrLine) {
        $InstrLine = getStatementLine();
      }
    }
  }
  print "syntax ERROR : missing statement separator for instruction $statement, at line ".$SeparatorLine."\n";
  return undef;
}

##################################################################
#              ROOT
##################################################################
sub parseRoot() {

  my $root = Node(RootKind, \$NullString);

  while ( defined nextStatement() ) {
     my $subNode = parseStatement();
     if (defined $subNode) {
        Append($root, $subNode);
     }
  }
  return $root;
}


#
# Split an ObjC buffer into token separated by ObjC language separators.
#
sub splitObjC($) {
   my $r_view = shift;
   my  @statements = split /(;|\{|}|\@\w+)/smi, $$r_view;
   
   if (scalar @statements > 0) {
    # if the last statement is a Null statement, it should be removed
    # because it is not significant.
    if ($statements[-1] !~ /\S/ ) {
      pop @statements ;
    }
  }
   return \@statements;
}


sub ParseObjC ($) {
  my $r_view = shift;
  
  my $r_statements = splitObjC($r_view);

  # Register a "unknow instruction" parser callback that manage semicolon end-
  # terminated instruction, potentially split on several statements.
  #Lib::ParseUtil::registerParseUnknow(\&parseUnknow);

  Lib::ParseUtil::InitParser($r_statements);

  my $root = parseRoot();
  my $Artifacts = Lib::ParseUtil::getArtifacts();
  return ($root, $Artifacts);
}

###################################################################################
#              MAIN
###################################################################################

# description: ObjC parse module Entry point.
sub Parse($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $status = 0;

#    my $statements =  $vue->{'statements_with_blanks'} ;

     initScope();
     ObjC::ParseObjCPass2::init();

     # launch first parsing pass : strutural parse.
     my ($ObjCNode, $Artifacts) = ParseObjC(\$vue->{'ObjC'});

     # Add a detail parsing pass to parse calls...
     ObjC::ParseObjCPass2::parseAllCall($ObjCNode);

     # Add a detail parsing pass to parse calls...
     ObjC::ParseObjCPass2::parseAllBlocks($ObjCNode);

     # Add a detail parsing pass to parse calls...
     ObjC::Ternary::parseAllTernaryOp($ObjCNode);

#      print "Buffered routines = ".join(', ', keys %H_ROUTINE_BUFFER)."\n";
#      print $H_ROUTINE_BUFFER{'IsValidUser'}."\n------\n";

     if (defined $options->{'--print-tree'}) {
       Lib::Node::Dump($ObjCNode, *STDERR, "ARCHI") if ($DEBUG);
     }
     if (defined $options->{'--print-test-tree'}) {
       print STDERR ${Lib::Node::dumpTree($ObjCNode, "ARCHI")} ;
     }
      
      $vue->{'structured_code'} = $ObjCNode;

      # pre-compute some list of items :
      my @InterfacesList = GetNodesByKind($ObjCNode, InterfaceKind, 1);
      my @ImplementationsList = GetNodesByKind($ObjCNode, ImplementationKind, 1);
      my %H_KindsLists = ();
      $H_KindsLists{'Interface'}=\@InterfacesList;
      $H_KindsLists{'Implementation'}=\@ImplementationsList;
      $vue->{'KindsLists'} = \%H_KindsLists;

      $vue->{'artifact'} = $Artifacts;

      #TSql::ParseDetailed::ParseDetailed($vue);
      if ($DEBUG) {
      for my $key ( keys %{$vue->{'artifact'}} ) {
        print "-------- $key -----------------------------------\n";
	print  $vue->{'artifact'}->{$key}."\n";
      }
      }

    return $status;
}

1;
