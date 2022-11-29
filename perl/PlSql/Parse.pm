#----------------------------------------------------------------------#
#                 @ISOSCOPE 2008                                       #
#----------------------------------------------------------------------#
#       Auteur  : ISOSCOPE SA                                          #
#       Adresse : TERSUD - Bat A                                       #
#                 5, AVENUE MARCEL DASSAULT                            #
#                 31500  TOULOUSE                                      #
#       SIRET   : 410 630 164 00037                                    #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#
#
#----------------------------------------------------------------------#
# DESCRIPTION: Reconnaissance de l'arborescence 
#   d'instructions et de blocs, pour le PL/SQL.
#----------------------------------------------------------------------#


package PlSql::Parse;
# les modules importes
use strict;
use warnings;
#use diagnostics; #FIXME: est-ce compatible Strawberry?
#no warnings 'recursion'; 

use Erreurs;

use Lib::Node qw( Leaf Node );
use Lib::NodeUtil;

# on aliase les principales fonction
use PlSql::PlSqlNode;

# mais aussi les fonctions de creation 
use PlSql::PlSqlNode qw( SetCondition ); 

# prototypes publics
sub Parse($$$$);

my $CurrentLine = 1;
my $StatementLine = 1;

sub getStatementLine() {
	return $StatementLine;
}

# Recuperation de laprochaine instruction a traiter.
sub getNextStatement($)
{
  my ($statementReader) = @_;
  my $index =  $statementReader->[1];
  my $value = $statementReader->[0]->[$index];
  $index++;
  $statementReader->[1] = $index;
#print STDERR "DEBUG: Traitement de " . $value . "\n" ;

  if (defined $value) {
	$value =~ /\A(\s*)/;
	$StatementLine = $CurrentLine + scalar ($1 =~ /\n/g);
    $CurrentLine += () = $value =~ /\n/g ; 
  }

  return $value;
}

sub nextStatement($)
{
  my ($statementReader) = @_;
  my $index =  $statementReader->[1];
  my $value = $statementReader->[0]->[$index];

  return \$value;
}

# Detecte s'il reste une instruction a analyser.
sub hasNextStatement($)
{
  my ($statementReader) = @_;
  my $index =  $statementReader->[1];
  my $size = scalar @{$statementReader->[0]} ;
  return $index < $size;
}

sub registerStatement($$$);

#FIXME: quelle difference entre les deux?
use constant CALLBACK_STATE_CONTINUE => -1 ;
use constant CALLBACK_STATE_DONE => 1 ;
use constant CALLBACK_STATE_END => 2 ;
use constant CALLBACK_STATE_UNKNOW => undef ;

use constant GENERIC_STATE_UNKNOW => undef ;
use constant GENERIC_STATE_ERROR => 1 ;
use constant GENERIC_STATE_CONTINUE => -1 ;

sub IsCallbackStateUnknow($)
{
  my ($v) = @_;
  return ( not defined $v );
}

sub IsGenericStateUnknow($)
{
  my ($v) = @_;
  return ( not defined $v );
}

sub IsCallbackStateContinue($)
{
  my ($v) = @_;
  return ( ( defined $v )  and ( $v < 0 ) ) ;
}

sub IsGenericStateContinue($)
{
  my ($v) = @_;
  return ( ( defined $v )  and ( $v < 0 ) ) ;
}

sub ParseGeneric($$$$)
{
  my ($statementReader, $registerCallback, $node, $userContext) = @_;
  my $statement;
  my $v = CALLBACK_STATE_UNKNOW;
  $statement = getNextStatement($statementReader) ;

  while ( defined $statement )
  {
    my $w = GENERIC_STATE_UNKNOW;
    if (defined $registerCallback)
    {
      # Cette instruction est-elle lie au bloc courant/parent?
      $v = $registerCallback->($node, $statementReader, $statement, $userContext); # FIXME: Deep recursion
    }
    if ( IsCallbackStateUnknow ( $v ) )
    {
      # Utilisation de la detection standard de debut de bloc
      $w = registerStatement($node, $statementReader, $statement);
    }
    if ( ( IsCallbackStateUnknow($v) and ( IsGenericStateUnknow($w) or IsGenericStateContinue($w) ) ) or
          IsCallbackStateContinue($v)  ) 
    {
      # Passage à l'instruction suivante.
      $statement = getNextStatement($statementReader) ;
    }
    else
    {
      $statement = undef;
    }
  }
  return $v;
}

# Debut du parse sur le fichier.
sub ParseRoot($)
{
  my ($statementReader) = @_;

  my $node = Node(RootKind, undef);
  Lib::NodeUtil::SetName($node, 'root');
  #my $bloc = $node->[2];

  # Theoriquement, un seul appel devrait suffire.
  # Toutefois, le mecanisme de recuperation suivant permet d'analyser le 
  # code restant, en particulier si les association de debut de bloc et de fin 
  # de blocs ont ete mal detectes.
  while ( hasNextStatement($statementReader) )
  {
    ParseGeneric($statementReader, undef, $node, $node);
  }

  return $node;
}

sub _Unexpected ($)
{
  my ( $statement ) = @_;
  print STDERR "Unexpected statement: " . $statement . "\n" ;
}

sub registerPackageStatement($$$$)
{
  my ($node, undef, $statement, $previousBlock) = @_;

  if ( $statement =~ /\A\s*\b(?:end)\b/i )
  {
    Lib::NodeUtil::Append( $node, Leaf( EndKind, $statement) );
    return 2;
  }
  return undef;
}


sub ParsePackage($$$)
{
  my ($statementReader, $bloc, $previousBlock) = @_;
  ParseGeneric($statementReader, \&registerPackageStatement, $bloc, $previousBlock);
}

sub TryParseAlterStatement($$$$)
{
  my ($node, $statementReader, $statement, $previousBlock) = @_;

  if ( $statement =~ /\A\s*\b(?:alter\b)/ism )
  {
    Lib::NodeUtil::Append ( $node, Leaf ( AlterKind, $statement) );

    return 1;
  }
  return 0;
}

my $_ReIdentifier = qr/[a-z][a-z\$\%_#0-9]*/i ;

#FIXME: unused?
sub TryParseBlocPackage($$$$)
{
  my ($bloc, $statementReader, $statement, $previousBlock) = @_;

  if ( $statement =~ /\A\s*\b(?:(?:create\s*(?:or\s*replace\s*)?)?package)\b\s*(?:\bbody\b\s*)?($_ReIdentifier)/ism )
  {
    my $name = $1;
    Erreurs::LogInternalTraces('DEBUG', undef, undef, 'Parse_name', $statement, $name);
    my $nodePackage =  Node ( PackageKind, $statement);
    Lib::NodeUtil::SetName ($nodePackage, $name);
    Lib::NodeUtil::Append( $bloc, $nodePackage);
    ParsePackage($statementReader, $nodePackage, $bloc) ; 
    return 1;
  }
  return 0;
}

sub TryParseBlocTypeBody($$$$)
{
  my ($bloc, $statementReader, $statement, $previousBlock) = @_;

  if ( $statement =~ /\A\s*\b(?:create\s*(?:or\s*replace\s*)?\btype\s\s*body\b\s*)\b($_ReIdentifier)/ism )
  {
    my $name = $1;
    Erreurs::LogInternalTraces('DEBUG', undef, undef, 'Parse_name', $statement, $name);
    my $nodePackage =  Node ( TypeBodyKind, $statement);
    Lib::NodeUtil::SetName ($nodePackage, $name);
    Lib::NodeUtil::Append( $bloc, $nodePackage);
    ParseGeneric($statementReader, \&registerPackageStatement, $nodePackage, $bloc);
    return 1;
  }
  return 0;
}

sub _CallbackBlocDeclaratifAvantBegin($$$$)
{
  my ($node, $statementReader, $statement, $context) = @_;
  my $previousBlock = $context->[0];
  if ( $statement =~ /\A\s*\b(?:begin)\b/i )
  {
    my $execNode =  Node ( ExecutiveKind, $statement);
    Lib::NodeUtil::Append( $previousBlock, $execNode);
    $context->[2] = $execNode;
    return 1;
  }
  elsif ( $statement =~ /\A\s*\b(?:end)\b/i )
  {
    Lib::NodeUtil::Append( $previousBlock, Leaf ( EndKind , $statement) );
    Lib::NodeUtil::SetEndline($previousBlock, getStatementLine());
    $context->[1] = 1;
    return 2; # FIXME: ne pas chercher un bloc exec apres...
  }
  elsif ( $statement =~ /\A\s*cursor\b/i )
  {
    Lib::NodeUtil::Append ( $node, Leaf ( CursorKind, $statement) );
    return CALLBACK_STATE_CONTINUE;
  }
  elsif ( $statement =~ /\A\s*pragma\b/i )
  {
    Lib::NodeUtil::Append ( $node, Leaf ( PragmaKind, $statement) );
    return CALLBACK_STATE_CONTINUE;
  }
  elsif ( $statement =~ /\A\s*(?:create\b\s*(?:or\s*\breplace\b\s*)?)?type\b/i )
  {
    Lib::NodeUtil::Append ( $node, Leaf ( TypeKind, $statement) );
    return CALLBACK_STATE_CONTINUE;
  }
  #elsif ( 0 != TryParseBlocPackage($node, $context, $statement, $node) )
  #{ 
    ## ne rien faire
    #return -1;
  #}
  elsif ( 0 != TryParseBlocTypeBody($node, $statementReader, $statement, $node) )
  {
    # ne rien faire
    return CALLBACK_STATE_CONTINUE;
  }
  elsif ( 0 != TryParseBlocCode($node, $statementReader, $statement, $node) )
  {
    # ne rien faire
    return CALLBACK_STATE_CONTINUE;
  }
  elsif ( $statement =~ /\A\s*\b(?:function|procedure)\b/i )
  {
    Lib::NodeUtil::Append ( $node, Leaf ( PrototypeSpecKind, $statement) );
    return CALLBACK_STATE_CONTINUE;
  }
  elsif ( $statement =~ /\A\s*\b($_ReIdentifier)\b/i )
  {
    my $name = $1;
    my $variableNode =  Leaf ( VariableDeclarationKind , $statement);
    Lib::NodeUtil::Append( $node, $variableNode );
    Erreurs::LogInternalTraces('DEBUG', undef, undef, 'Parse_name', $statement, $name);
    Lib::NodeUtil::SetName ( $variableNode, $name );
    return CALLBACK_STATE_CONTINUE; # on continue
  }
  return undef;
}




sub ParseBlocDeclaratifBeginEnd($$)
{
  my ($statementReader, $blocNode) = @_;
  my $declarativeNode =  Node ( DeclarativeKind, undef);
  my $executiveNode ; #=  Node ( ExecutiveKind, undef);
  
  # ParseBlocDeclaratifBeginEnd is called each time a bloc of code is detected (cf. TryParseBlocCode)
  # It declares inconditionally a DeclarativeKind node (see just above!).
  # But if there is an explicit declare bloc, it should be consumed. If not, an anonymous bloc will be declared 
  # inside the logical (default) "declare" bloc.
  if (${nextStatement($statementReader)} =~ /\Adeclare\b/is) {
	  getNextStatement($statementReader);
  }
  
  Lib::NodeUtil::Append ($blocNode, $declarativeNode);
  my @context = ( $blocNode, undef, undef);
  ParseGeneric($statementReader, \&_CallbackBlocDeclaratifAvantBegin, $declarativeNode, \@context);
  #ParseBlocDeclaratifAvantBegin($statementReader, $declarativeNode, $blocNode) ; 
  if ( not defined $context[1] )
  {
    if ( defined $context[2] )
    {
      $executiveNode = $context[2];
      ParseBeginExceptionEnd_FromBegin ($statementReader, $executiveNode, $blocNode) ;
    }
  }
}

#sub TraiteBlocCode($$$$)
sub TryParseBlocCode($$$$)
{
  my ($bloc, $statementReader, $statement, $previousBlock) = @_;

  # FIXME: test redondant avec appelant.
  my $type = undef ;
  my $name ;
  if ( $statement =~ /\A\s*(?:\bcreate\s*(?:or\s*replace\s*)?)?(?:constructor\s*|static\s*|(?:order\s*|map\s*|overriding\s*)?member\s*)?\b(?:function\b\s*)($_ReIdentifier).*\b(?:is|as)\b/ism )
  {
    # une function 
    $type = FunctionKind ;
    $name = $1;
  }
  elsif ( $statement =~ /\A\s*(?:\bcreate\s*(?:or\s*replace\s*)?)?(?:constructor\s*|(?:order\s*|map\s*|overriding\s*)?member\s*)?\b(?:procedure\b\s*)($_ReIdentifier).*\b(?:is|as)\b/ism )
  {
    # une procedure 
    $type = ProcedureKind ;
    $name = $1;
  }
  elsif ( $statement =~ /\A\s*\b(?:(?:create\s*(?:or\s*replace\s*)?)?package)\b\s*(?:\bbody\b\s*)?($_ReIdentifier)/ism )
  {
    $type = PackageKind ;
    $name = $1;

    #my $nodePackage =  Node ( PackageKind, $statement);
    #Lib::NodeUtil::SetName ($nodePackage, $name);
    #Lib::NodeUtil::Append( $bloc, $nodePackage);
    #ParsePackage($context, $nodePackage, $bloc) ; 
  }
  elsif ( $statement =~ /\A\s*\b(?:create\s*(?:or\s*replace\s*)?trigger)\b\s*($_ReIdentifier)/ism )
  {
    $type = TriggerKind ;
    $name = $1;
  }
  elsif ( $statement =~ /\A\s*\b(?:declare\b\s*)\b($_ReIdentifier?)/ism )
  {
    # un bloc anonyme
    $type = AnonymousKind ;
    $name = $1;
  }
  else
  {
    return 0;
  }

  my $blocNode =  Node (  $type, $statement );
  PlSql::PlSqlNode::SetLine($blocNode, getStatementLine());
  Erreurs::LogInternalTraces('DEBUG', undef, undef, 'Parse_name', $statement, $name);
  Lib::NodeUtil::SetName ( $blocNode, $name);
  Lib::NodeUtil::Append( $bloc, $blocNode);

  ParseBlocDeclaratifBeginEnd($statementReader,$blocNode);

  #my $declarativeNode =  Node ( DeclarativeKind, undef);
  #my $executiveNode =  Node ( ExecutiveKind, undef);
  #Lib::NodeUtil::Append ($blocNode, $declarativeNode);
  #ParseBlocDeclaratifAvantBegin($statementReader, $declarativeNode, $blocNode) ; 
  #Lib::NodeUtil::Append ($blocNode, $executiveNode);
  #ParseBeginExceptionEnd_FromBegin ($statementReader, $executiveNode, $blocNode) ;
  return 1;
}

# Au niveau d'un bloc BEGIN EXCEPTION WHEN END,
# on est dans le BEGIN,
# on attend EXCEPTION ou END
sub registerBeginExceptionWhenEnd_FromBegin($$$$)
{
  my ($bloc, $statementReader, $statement, $previousBlock) = @_;

  if ( $statement =~ /\A\s*\b(?:exception)\b/ism )
  {
    my $exceptionNode =  Node ( ExceptionKind, $statement);
    Lib::NodeUtil::Append( $previousBlock, $exceptionNode);
    ParseBeginExceptionEnd_FromException($statementReader, $exceptionNode, $exceptionNode) ;

    return 1;
  }
  elsif ( $statement =~ /\A\s*\b(?:end)\b/ism )
  {
    Lib::NodeUtil::Append( $previousBlock, Leaf ( EndKind, $statement) );
    Lib::NodeUtil::SetEndline($previousBlock, getStatementLine());
    return 2;
  }
  return undef;
}

# Au niveau d'un bloc BEGIN EXCEPTION WHEN END,
# on est dans l'EXCEPTION, 
# on attend WHEN ou END
sub registerBeginExceptionWhenEnd_FromException($$$$)
{
  my ($lastWhenNode, $statementReader, $statement, $exceptionNode) = @_;

  if ( $statement =~ /\A\s*\b(?:when)\b/ism )
  {
    my $whenNode = Node ( WhenKind, $statement);
    Lib::NodeUtil::Append( $exceptionNode, $whenNode);
    ParseBeginExceptionEnd_FromException($statementReader, $whenNode, $exceptionNode) ;

    return 1;
  }
  elsif ( $statement =~ /\A\s*\b(?:end)\b/ism )
  {
    my $upperNode = GetParent ( $exceptionNode);
    Lib::NodeUtil::Append( $upperNode, Leaf ( EndKind, $statement) );
    Lib::NodeUtil::SetEndline($upperNode, getStatementLine());
    return 2;
  }
  return undef;
}

sub ParseBeginExceptionEnd_FromBegin($$$)
{
  my ($statementReader, $bloc, $previousBlock) = @_;
  ParseGeneric($statementReader, \&registerBeginExceptionWhenEnd_FromBegin, $bloc, $previousBlock);
}

sub ParseBeginExceptionEnd_FromException($$$)
{
  my ($statementReader, $bloc, $previousBlock) = @_;
  ParseGeneric($statementReader, \&registerBeginExceptionWhenEnd_FromException, $bloc, $previousBlock);
}

sub TraiteBlocBegin($$$$)
{
  my ($node, $statementReader, $statement, $previousBlock) = @_;
  # FIXME: test redondant avec appelant.
  if ( $statement =~ /\A\s*\b(?:begin)\b/ism )
  {

    my $anonymousNode =  Node (  AnonymousKind, undef);
    Lib::NodeUtil::Append( $node, $anonymousNode);
    #my $executiveNode =  Node (  ExecutiveKind, undef);
    my $executiveNode =  Node (  ExecutiveKind, $statement);
    #my $beginNode =  Node (  BeginKind, $statement);
    #Lib::NodeUtil::Append( $anonymousNode, $beginNode);
    Lib::NodeUtil::Append( $anonymousNode, $executiveNode);

    ParseBeginExceptionEnd_FromBegin($statementReader, $executiveNode, $anonymousNode) ; 
    return 1;
  }
}


#use constant CALLBACK_STATE_CONTINUE => -1 ;
#use constant CALLBACK_STATE_DONE => 1 ;
#use constant CALLBACK_STATE_END => 2 ;
#use constant CALLBACK_STATE_UNKNOW => undef ;
sub registerIfEndif($$$$)
{
  my ($node, $statementReader, $statement, $previousBlock) = @_;
  if ( $statement =~ /\A\s*\b(?:else)\b/i )
  {
    my $elseNode =  Node ( ElseKind, $statement);
    Lib::NodeUtil::Append( $previousBlock, $elseNode);
    #ParseIfEndif($statementReader, $elseNode, $previousBlock) ;
    return [ CALLBACK_STATE_CONTINUE, $elseNode ];
    #return 1; # FIXME: pour eviter Deep, faire CALLBACK_STATE_CONTINUE
              # FIXME: mais sue quel noeud?
  }
  elsif ( $statement =~ /\A\s*\b(?:elsif)\b/i )
  {
    my $elsifNode =  Node ( ElsifKind, $statement);
    Lib::NodeUtil::Append( $previousBlock, $elsifNode);
    #ParseIfEndif($statementReader, $elsifNode, $previousBlock) ; # FIXME: Deep recursion
    return [ CALLBACK_STATE_CONTINUE, $elsifNode ];
    #return 1;
  }
  elsif ( $statement =~ /\A\s*\b(?:end\s*if)\b/i )
  {
    Lib::NodeUtil::Append( $previousBlock, Leaf ( EndKind, $statement) );
    return [ CALLBACK_STATE_END, undef ];
    #return 2;
  }
  return undef;
}

sub ParseIfEndif($$$)
{
  my ($statementReader, $ifNode, $previousBlock) = @_;

  #my $v = undef ;
  #$v = ParseGeneric($statementReader, \&registerIfEndif, $ifNode, $previousBlock); # FIXME: Deep recursion

  my ( $registerCallback, $node, $userContext) = 
         ( \&registerIfEndif, $ifNode, $previousBlock);
  my $statement;
  my $v = CALLBACK_STATE_UNKNOW;
  $statement = getNextStatement($statementReader) ;
  while ( defined $statement )
  {
    my $w = GENERIC_STATE_UNKNOW;
    if (defined $registerCallback)
    {
      # Cette instruction est-elle lie au bloc courant/parent?
      my $x = $registerCallback->($node, $statementReader, $statement, $userContext); # FIXME: Deep recursion
      if ( defined $x)
      {
        my $futureNode = $x->[1];
        $v = $x->[0];
        if (defined $futureNode and defined $v)
        {
          $node = $futureNode;
        }
      }
      else
      {
        $v = undef;
      }
    }
    if ( IsCallbackStateUnknow ( $v ) )
    {
      # Utilisation de la detection standard de debut de bloc
      $w = registerStatement($node, $statementReader, $statement);
    }
    if ( ( IsCallbackStateUnknow($v) and ( IsGenericStateUnknow($w) or IsGenericStateContinue($w) ) ) or
          IsCallbackStateContinue($v)  ) 
    {
      # Passage à l'instruction suivante.
      $statement = getNextStatement($statementReader) ;
    }
    else
    {
      $statement = undef;
    }
  }
  return $v;
}

sub TraiteBlocIf($$$$)
{
  my ($bloc, $statementReader, $statement, $previousBlock) = @_;
  # FIXME: test redondant avec appelant.
  if ( $statement =~ /\A\s*\b(?:if)\b/i )
  {

    my $ifNode =  Node ( IfKind , $statement) ;
    Lib::NodeUtil::Append( $bloc, $ifNode);
    my $thenNode =  Node ( ThenKind, undef) ;
    Lib::NodeUtil::Append( $ifNode, $thenNode);
    ParseIfEndif($statementReader, $thenNode, $ifNode) ; 
    return 1;
  }

}

sub registerLoopEnd($$$$)
{
  my ($node, undef, $statement, $previousBlock) = @_;
  if ( $statement =~ /\A\s*\b(?:end)\b/i )
  {
    if ( $statement !~ /\A\s*\b(?:end\s*loop)\b/i )
    {
      Erreurs::LogInternalTraces('DEBUG', undef, undef, 'end loop without loop', $statement);
    }
    Lib::NodeUtil::Append( $node, Leaf ( EndKind, $statement) );
    return 2;
  }
  return undef;
}


sub TraiteBlocLoop($$$$)
{
  my ($bloc, $statementReader, $statement, $previousBlock) = @_;

  # FIXME: test redondant avec appelant.
  if ( $statement =~ /\A\s*\b(?:for|loop|while)\b/i )
  {
    my $loopNode =  Node ( LoopKind, $statement);
    Lib::NodeUtil::Append( $bloc, $loopNode);
    my $v = undef ;
    $v = ParseGeneric($statementReader, \&registerLoopEnd, $loopNode, $bloc);
    return 1;
  }
}


sub registerCaseWhenElseEnd($$$$)
{
  my ($node, $statementReader, $statement, $caseNode) = @_;
  
  if ( $statement =~ /\A\s*\b(?:when)\b/ism )
  {
    my $whenNode = Node ( WhenKind, $statement);
    Lib::NodeUtil::Append( $caseNode, $whenNode);
    ParseCaseWhenElseEnd($statementReader, $whenNode, $caseNode) ;
    return 1;
  }
  elsif ( $statement =~ /\A\s*\b(?:else)\b/i )
  {
    my $elseNode = Node ( CaseElseKind, $statement);
    Lib::NodeUtil::Append( $caseNode, $elseNode);
    ParseCaseWhenElseEnd($statementReader, $elseNode, $caseNode) ;
    return 1;
  }
  elsif ( $statement =~ /\A\s*\b(?:end)\b/i )
  {
    Lib::NodeUtil::Append( $caseNode, Leaf (  EndKind, $statement) );
    return 2;
  }
  return undef;
}

sub ParseCaseWhenElseEnd($$$)
{
  my ($statementReader, $bloc, $previousBlock) = @_;
  ParseGeneric($statementReader, \&registerCaseWhenElseEnd, $bloc, $previousBlock);
}

sub TraiteBlocCase($$$$)
{
  my ($bloc, $statementReader, $statement, $previousBlock) = @_;

  # FIXME: test redondant avec appelant.
  if ( $statement =~ /\A\s*\b(?:case)\b/ism )
  {
    my $caseNode = Node ( CaseKind, $statement);
    Lib::NodeUtil::Append( $bloc, $caseNode);
    ParseCaseWhenElseEnd($statementReader, $caseNode, $caseNode) ; 
    return 1;
  }
}

# FIXME: unused
sub ParseStatements($)
{
  my ($statementReader) = @_;
  return ParseRoot ( $statementReader);
}

sub registerStatement($$$)
{
  my ($bloc, $statementReader, $statement) = @_;

  #if ( 0 != TryParseBlocPackage($bloc, $context, $statement, $bloc) )
  #{ 
    ## ne rien faire
  #}
  if ( 0 != TryParseAlterStatement($bloc, $statementReader, $statement, $bloc) )
  {
    # ne rien faire
  }
  elsif ( 0 != TryParseBlocTypeBody($bloc, $statementReader, $statement, $bloc) )
  {
    # ne rien faire
  }
  elsif ( 0 != TryParseBlocCode($bloc, $statementReader, $statement, $bloc) )
  {
    # ne rien faire
  }
  elsif ( $statement =~ /\A\s*\b(?:begin)\b/i )
  {
    TraiteBlocBegin($bloc, $statementReader, $statement, $bloc);
  }
  elsif ( $statement =~ /\A\s*\b(?:for|loop|while)\b/i )
  {
    TraiteBlocLoop($bloc, $statementReader, $statement, $bloc);
  }
  elsif ( $statement =~ /\A\s*\b(?:if)\b/i )
  {
    TraiteBlocIf($bloc, $statementReader, $statement, $bloc);
  }
  elsif ( $statement =~ /\A\s*\b(?:case)\b/i )
  {
    TraiteBlocCase($bloc, $statementReader, $statement, $bloc);
  }
  elsif ( $statement =~ /\A\s*\b(?:end)\b/i )
  {
    # NB: fin de bloc non reconnue.
    _Unexpected( $statement);
    Lib::NodeUtil::Append ( $bloc, Leaf ( UnexpectedKind, $statement) );
    return 1;
  }
  elsif ( $statement =~ /\A\s*(?:create\b\s*(?:or\s*\breplace\b\s*)?)?type\b/i )
  {
    Lib::NodeUtil::Append ( $bloc, Leaf ( TypeKind, $statement) );
  }
  elsif ( $statement =~ /\A\s*<</i )
  {
    Lib::NodeUtil::Append ( $bloc, Leaf ( LabelKind, $statement) );
  }
  else
  {
	if ($statement !~ /\A[\s;]*\z/is) {
		Lib::NodeUtil::Append ( $bloc, Leaf ( StatementKind , $statement) );
	}
  }
  return undef;
}


# Reperage de chaque condition 
# presente dans une instruction
sub _MarkConditionnalNode($$)
{
  my ( $node, $context )= @_;
  my $statement = PlSql::PlSqlNode::GetStatement($node);
  return undef if ( not defined $statement);

  my $statement_lc =  $statement ;
  
    if ( $statement_lc =~ /\b(?:elsif|if|when)\b\s*([^;]*)\bthen\b/smi )
    {
      my $condition = $1;
      SetCondition ( $node, $condition );
    }
    elsif ( $statement_lc =~ /\b(?:while)\b\s*([^;]*)\bloop\b/smi )
    {
      my $condition = $1;
      SetCondition ( $node, $condition );
    }
    elsif ( $statement_lc =~ /\b(?:exit\s*when)\b\s*([^;]*)/smi )
    {
      my $condition = $1;
      SetCondition ( $node, $condition );
    }
  return undef;
  
}

sub _CountUnexpectedStatements($$)
{
  my ( $node, $context )= @_;
  if ( IsKind($node, UnexpectedKind) )
  {
    $context->[0] |= Erreurs::COMPTEUR_STATUS_INCOHERENCE_PARSE;
  }
  return undef;
}

# description: le module parse pl-sql (point d'entree)
sub Parse($$$$)
{
    my ($fichier, $vue, $couples, $options) = @_;
    my $status = 0;

    my $statements =  $vue->{'statements_with_blanks'} ;

    if (defined $statements)
    {
	  $CurrentLine = 1;
	  $StatementLine = 1;
      my @statementReader = ( $statements, 0);
      
      my $rootNode = ParseRoot(\@statementReader);
      $vue->{'structured_code'} = $rootNode;
      my @context = ();
      Lib::Node::Iterate ($rootNode, 0, \& _MarkConditionnalNode, \@context) ;
      $vue->{'dump_functions'}->{'structured_code'} = \&Lib::Node::Dump;

      @context = (0);
      Lib::Node::Iterate ($rootNode, 0, \& _CountUnexpectedStatements, \@context) ;
      $status |= $context[0];

      $vue->{'structured_code_by_kind'} = Lib::NodeUtil::BuildListByKind ($rootNode) ;
      
      $vue->{'structured_code_cloned'} = Lib::Node::Clone( $rootNode );
      $vue->{'dump_functions'}->{'structured_code_cloned'} = \&Lib::Node::Dump;
    }

	if (defined $options->{'--dump-tree'}) {
		Lib::Node::Dump($vue->{'structured_code'}, *STDOUT, "");
	}

	initUnitSplitter();

    return $status;
}


#-------------------------------------------------------------------------
#   Routines for spliting into severall units.
#-------------------------------------------------------------------------

sub containsArtifact($) {
	my $views = shift;
	
	my @funcs = PlSql::PlSqlNode::GetNodesByKind($views->{'structured_code'}, FunctionKind);
	
	if (! scalar @funcs) {
		my @procs = PlSql::PlSqlNode::GetNodesByKind($views->{'structured_code'}, ProcedureKind);
		if (! scalar @procs) {
			my @trigs = PlSql::PlSqlNode::GetNodesByKind($views->{'structured_code'}, TriggerKind);
			if (! scalar @trigs) {
				return 0;
			}
		}
	}
	return 1;
}

my $idx_unit = undef;
my @TopLevelFunc = undef;
my @sortedLineTab = undef;

sub initUnitSplitter() {
  $idx_unit = undef;
  @TopLevelFunc = undef;
  @sortedLineTab = undef;
}

#------------------------ UNIT initialisation ---------------------

sub dumpBuffer($$) {
	my $buf = shift;
	my $name = shift;
	
	open FIC, "> $name";
	print FIC $$buf;
	close FIC;
}

sub initUnits($) {
    my $fullViews = shift;
    $idx_unit = 0;
    my $root = $fullViews->{'structured_code'};

    @TopLevelFunc = ();
    @sortedLineTab = ();

	# Get top level function, including those that are inside package.
	my @artifacts = Lib::NodeUtil::GetNodesByKindList($root, [FunctionKind, ProcedureKind, TriggerKind], 1);

    for my $node (@artifacts) {
#print "KIND = ".GetKind($node)."\n";
	      #print "FOUND function ".GetName($node)."\n";
        push @TopLevelFunc, $node;
    }

    my @separationLines = ();

    for my $func (@TopLevelFunc) {
#print "UNIT : ".GetName($func)."\n";
      # remove the node from the root tree
      # ----------------------------------
      Lib::Node::Detach($func);

      # add begin / end lines of unit in a separator list.
      # This is for extract the unit code from the whole file.
      # ------------------------------------------------------
      push @separationLines, PlSql::PlSqlNode::GetLine($func);
      push @separationLines, (Lib::NodeUtil::GetEndline($func)+1);
      
      #print "BEGIN : ".PlSql::PlSqlNode::GetLine($func)." // END : ".PlSql::PlSqlNode::GetEndLine($func)."\n";
    }

    # The root code is considered as an unit. It corresponds to the code that is
    # outside the unit defined above.
    push @TopLevelFunc, $root;

    # init the variable that contain the association between line and
    # positions index in the whole buffer.
    CountUtil::initViewIndexes();

    # Sort lines
    @sortedLineTab = sort { $a <=> $b } @separationLines;
    
    # For each buffer view, built a indexation of all separator lines.
    CountUtil::buildViewsIndexes(\$fullViews->{'text'}, \@sortedLineTab, 'text');
    CountUtil::buildViewsIndexes(\$fullViews->{'comment'}, \@sortedLineTab, 'comment');
    CountUtil::buildViewsIndexes(\$fullViews->{'MixBloc'}, \@sortedLineTab, 'MixBloc');
    CountUtil::buildViewsIndexes(\$fullViews->{'code'}, \@sortedLineTab, 'code');
    CountUtil::buildViewsIndexes(\$fullViews->{'code_and_directives'}, \@sortedLineTab, 'code_and_directives');
    CountUtil::buildViewsIndexes(\$fullViews->{'code_with_prepro'}, \@sortedLineTab, 'code_with_prepro');
    CountUtil::buildViewsIndexes(\$fullViews->{'code_without_directive'}, \@sortedLineTab, 'code_without_directive');
    CountUtil::buildViewsIndexes(\$fullViews->{'code_lc_without_directive'}, \@sortedLineTab, 'code_lc_without_directive');
    CountUtil::buildViewsIndexes(\$fullViews->{'directives'}, \@sortedLineTab, 'directives');
    CountUtil::buildViewsIndexes(\$fullViews->{'plsql'}, \@sortedLineTab, 'plsql');
}

#------------------------ UNIT getter ---------------------

sub getNextUnit($) {
  my $fullViews = shift;

  if (! defined $idx_unit) {
    initUnits($fullViews);
  }
  
  if ($idx_unit >= scalar @TopLevelFunc) {
    return undef, undef;
  }

  # The views needed by the DIAG functions to compute counters. These views
  # are to be generated for each unit.
  my %views = ();

  $views{'full_file'} = $fullViews;

  # Hash table that contains the indexes of line, required with buildViewsIndexes() ... 
  my $H_ViewIndexes = CountUtil::getViewIndexes();

  # Get unit's root node ...
  # ------------------------
  my $unit = $TopLevelFunc[$idx_unit];

  if (! IsKind($unit, RootKind)) {
    # create a virtual root code to contain the unit.
    # Indeed, some algorithms need a root node to work perfectly.
    my $virtualRoot =Node(RootKind, Lib::Node::createEmptyStringRef());
    Lib::NodeUtil::SetName($virtualRoot, 'virtualRoot');
    Lib::NodeUtil::Append($virtualRoot, $unit);
    $unit = $virtualRoot;
  }

  $views{'structured_code'} = $unit;
 
  $views{'structured_code_by_kind'} = Lib::NodeUtil::BuildListByKind($unit) ;

  # assign "strings" view "as is" ... (all artifact will be present)
  # --------------------------------
  $views{'HString'} = $fullViews->{'HString'};

  # Get buffer views ...
  # ------------------------------
  my $name = "";

  # A root node is added before non-root unit. If the name is virtualRoot,
  # then it contains an artifact, else it is the real root.
  if (GetName($unit) eq 'virtualRoot') {
#  if (IsKind($unit, FunctionDeclarationKind)) {
    my $artifactUnit = Lib::NodeUtil::GetChildren($unit)->[0];
    $name = GetName($artifactUnit);
    my $line = Lib::NodeUtil::GetLine($artifactUnit) ;
#    my $artiKey = buildArtifactKeyByData($name, $line);

    # Extract artifact views from the whole file views
    # ------------------------------------------------

    $views{'text'} = CountUtil::extractView(\$fullViews->{'text'}, 
                                 $line,
				 Lib::NodeUtil::GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'text'});

    $views{'code'} = CountUtil::extractView(\$fullViews->{'code'}, 
                                 $line,
				 Lib::NodeUtil::GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'code'});


    $views{'comment'} = CountUtil::extractView(\$fullViews->{'comment'}, 
                                 $line,
				 Lib::NodeUtil::GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'comment'});

    $views{'MixBloc'} = CountUtil::extractView(\$fullViews->{'MixBloc'}, 
                                 $line,
				 Lib::NodeUtil::GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'MixBloc'});
                                 
    $views{'code_and_directives'} = CountUtil::extractView(\$fullViews->{'code_and_directives'}, 
                                 $line,
				 Lib::NodeUtil::GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'code_and_directives'});

    $views{'code_with_prepro'} = CountUtil::extractView(\$fullViews->{'code_with_prepro'}, 
                                 $line,
				 Lib::NodeUtil::GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'code_with_prepro'});                       
                                 
     $views{'code_without_directive'} = CountUtil::extractView(\$fullViews->{'code_without_directive'}, 
                                 $line,
				 Lib::NodeUtil::GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'code_without_directive'});                                

    $views{'code_lc_without_directive'} = CountUtil::extractView(\$fullViews->{'code_lc_without_directive'}, 
                                 $line,
				 Lib::NodeUtil::GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'code_lc_without_directive'});
                                
    $views{'directives'} = CountUtil::extractView(\$fullViews->{'directives'}, 
                                 $line,
				 Lib::NodeUtil::GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'directives'});
                 
    $views{'plsql'} = CountUtil::extractView(\$fullViews->{'plsql'}, 
                                 $line,
				 Lib::NodeUtil::GetEndline($artifactUnit)+1,
                                 $H_ViewIndexes->{'plsql'});
                     
                                 
#print ">>>".$views{'text'}."<<<\n";
  }
  else {
    $name = 'root';

    # rebuild views corresponding to the "root" code.
    # -----------------------------------------------

    $views{'text'} = CountUtil::extractRoot(\$fullViews->{'text'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'text'});

    $views{'comment'} = CountUtil::extractRoot(\$fullViews->{'comment'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'comment'});

    $views{'code'} = CountUtil::extractRoot(\$fullViews->{'code'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'code'});
                                 
    $views{'MixBloc'} = CountUtil::extractRoot(\$fullViews->{'MixBloc'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'MixBloc'});
                                 
    $views{'code_and_directives'} = CountUtil::extractRoot(\$fullViews->{'code_and_directives'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'code_and_directives'});
                                 
    $views{'code_with_prepro'} = CountUtil::extractRoot(\$fullViews->{'code_with_prepro'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'code_with_prepro'});
                                 
    $views{'code_without_directive'} = CountUtil::extractRoot(\$fullViews->{'code_without_directive'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'code_without_directive'});
                                 
    $views{'code_lc_without_directive'} = CountUtil::extractRoot(\$fullViews->{'code_lc_without_directive'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'code_lc_without_directive'});
                                 
    $views{'directives'} = CountUtil::extractRoot(\$fullViews->{'directives'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'directives'});
                                 
    $views{'plsql'} = CountUtil::extractRoot(\$fullViews->{'plsql'}, 
                                 \@sortedLineTab,
                                 $H_ViewIndexes->{'plsql'});

#print ">>>".$views{'text'}."<<<\n";
  }

  # build views obtained from buffered views
  StripPlSql::StripStatements(\%views);
  $views{'conditionnal_expressions'} = StripPlSql::StripConditions( \%views );

  $idx_unit++;
#print "UNIT : $name\n";
#print "<<<<".$views{'code'}.">>>>\n";
  if ($views{'code'} !~ /\A[\s;]*\z/is) {
    return (\%views, $name);
  }
  else {
	  print "[INFO] skipping empty view: $name\n";
	  return undef, undef;
  }
  
}


1;
