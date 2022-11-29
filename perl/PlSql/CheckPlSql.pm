
#----------------------------------------------------------------------#
#                         @ISOSCOPE 2008                               #
#----------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                  #
#               Adresse : TERSUD - Bat A                               #
#                         5, AVENUE MARCEL DASSAULT                    #
#                         31500  TOULOUSE                              #
#               SIRET   : 410 630 164 00037                            #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Plugin
# Description: Module de verification de l'adequation de l'analyseur pour le fichier.

package PlSql::CheckPlSql;
use PlSql::PlSqlNode;
use Lib::NodeUtil;

# Determine si ce noeud est un bloc de l'un des types recherches.
#  package function procedure trigger anonyme
# pour rechercher leurs variables locales.
sub _callbackCheckBlocInNode($$)
{
  my ( $node, $context )= @_;
  if ( IsKind ( $node, DeclarativeKind)  ||
       IsKind ( $node, AnonymousKind)    ||
       IsKind ( $node, ProcedureKind)    ||
       IsKind ( $node, FunctionKind)     ||
       IsKind ( $node, PackageKind)      ||
       IsKind ( $node, TriggerKind)      ||
       IsKind ( $node, TypeBodyKind)     ||
       IsKind ( $node, BeginKind)        ||
       IsKind ( $node, LabelKind)        ||
       IsKind ( $node, CaseKind)         ||
     #  IsKind ( $node, ElseKind)         ||
     #  IsKind ( $node, WhenKind)         ||
       IsKind ( $node, LoopKind)         ||
       IsKind ( $node, IfKind)           ||
     #  IsKind ( $node, ElsifKind)        ||
     #  IsKind ( $node, ThenKind)         ||
     0)

  {
    $context->[0] =  GetKind($node);
  }
}


  #if ( $buffer =~ /\bcreate\b\s*or\b\s*replace\b\s*(?:package|function|procedure|trigger)\b/smi )
  #{
    #return undef; # Code availability
  #}
  #if ( ( $buffer =~ /\bbegin\b/smi ) and ( $buffer =~ /\bvarchar2\b/smi ) )
  #{
    #return undef; # Code availability
  #}
sub CheckCodeAvailability($)
{
  my ($vue) = @_;
  my $Root =  $vue;
  if ( ! defined $Root )
  {
    return undef;
  }
  
  my @context = (  undef );
  Lib::Node::ForEachDirectChild($Root, \&_callbackCheckBlocInNode, \@context);
  if (defined  $context[0])
  {
    return undef;
  }
  return 'None bloc of code';
}

1;
