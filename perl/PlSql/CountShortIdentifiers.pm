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

package PlSql::CountShortIdentifiers;

use strict;
use warnings;
use Erreurs;
use Couples;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

# prototypes publiques
sub CountShortIdentifiers($$$);

my $mnemo_ShortIdentifiers = Ident::Alias_ShortIdentifiers();



sub _CheckIdentSize($$$)
{
  my ($id, $context, $kind ) = @_;

  if ( !defined $id ) {
    if ( $kind ne StatementKind ) {
      #print STDERR "ERREUR : probleme lors de l'analyse du noeud ($kind) ==> $stmt\n";
      Erreurs::LogInternalTraces('erreur', undef, undef, 'CountShortIdentifiers.pm' , "probleme lors de l'analyse du noeud", $kind . ' ==> ' );
    }
  }
  else {
    # Suppression de la partie "espace de nom" de l'identifiant...
    $id =~ s/.*\.//;
    if ( $id ne "" ) {
  #print " ID = $id\n";
      if ( length $id <= 4 ) {
        $context->[0] += 1;
        Erreurs::LogInternalTraces('trace', undef, undef, $mnemo_ShortIdentifiers, $id);
      }
    }
  }
}


sub _callbackHeader($$)
{
  my ( $node, $context )= @_;

  my $kind = GetKind($node );
  my $stmt = GetStatement($node);

#print "-----------------\n";
#print "STATEMENT : $stmt\n";

  my $id;
  if ( IsKind($node, AnonymousKind) ) {
    $id = "";
  }
  elsif ( IsKind($node, ProcedureKind) or  IsKind($node, PrototypeSpecKind )) {
    ($id) = $stmt =~ /procedure\s*([\w\.\$#]+)/i ;
  }
  elsif ( IsKind($node, FunctionKind) or  IsKind($node, PrototypeSpecKind )) {
    ($id) = $stmt =~ /function\s*([\w\.\$#]+)/i ;
  }
  elsif ( IsKind($node, PackageKind) ) {
    ($id) = $stmt =~ /package\s*(?:\bbody\b\s*)?([\w\.\$#_]+)/i ;
  }
  else
  {
    return ;
  }

  if (defined $stmt) 
  {
    _CheckIdentSize($id, $context, $kind);
  }
}


sub _callbackDeclarativeZone($$)
{
  my ( $node, $context )= @_;

  my $kind = GetKind($node );
  my $stmt = GetStatement($node);

#print "-----------------\n";
#print "STATEMENT : $stmt\n";

  my $id;
  if ( IsKind($node, AnonymousKind) ) {
    return;
    $id = "";
  }
  elsif ( IsKind($node, ProcedureKind) or  IsKind($node, PrototypeSpecKind )) {
    return;
    ($id) = $stmt =~ /procedure\s*([\w\.\$#]+)/i ;
  }
  elsif ( IsKind($node, FunctionKind) or  IsKind($node, PrototypeSpecKind )) {
    return;
    ($id) = $stmt =~ /function\s*([\w\.\$#]+)/i ;
  }
  elsif ( IsKind($node, PackageKind) ) {
    return;
    ($id) = $stmt =~ /package\s*([\w\.\$#]+)/i ;
  }
  else {
    if (( IsKind($node, StatementKind) ) or
       ( IsKind($node, VariableDeclarationKind) ) or
       ( IsKind($node, CursorKind) ))
    {
    # Par defaut on considere le statement inconnu comme une variable !!!
    # A condition qu'il y ait plus d'un mot sur la ligne.
      ($id) = $stmt =~ /^\s*(?:(?:variable|cursor|constant)\b\s*)*([\w\.\$#]+)[ \t]+[^\s]+/mi ;
    }
    else {
      $id = "";
    }
  }
  if (defined $stmt) 
  {
    _CheckIdentSize($id, $context, $kind);
  }
}

# Reperage de chaque declare.
sub _callbackNode($$$$)
{
  my ( $node, $context )= @_;

  my $kind = PlSql::PlSqlNode::GetKind($node );

  _callbackHeader($node, $context);
  if (( $kind eq DeclarativeKind ) or ( $kind eq PackageKind ) )
  {
#print "BLOC DE DECLARATION : \n";
    #_callbackDeclarativeZone($node, $context);
    Lib::Node::ForEachDirectChild($node, \& _callbackDeclarativeZone, $context);
  }
  return undef;
}





#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des lignes de code en commentaire.
#-------------------------------------------------------------------------------
sub CountShortIdentifiers($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $status = 0;
  my $nbr_ShortIdentifiers = 0;

  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root ) {
    $status |= Couples::counter_add($compteurs, $mnemo_ShortIdentifiers, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @context = ( 0, 0 );

  Lib::Node::Iterate ($root, 0, \& _callbackNode, \@context) ;

  $nbr_ShortIdentifiers = $context[0];

  $status |= Couples::counter_add($compteurs, $mnemo_ShortIdentifiers, $nbr_ShortIdentifiers);

  return $status;
}

1;
