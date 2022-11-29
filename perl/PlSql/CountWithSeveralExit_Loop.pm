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

package PlSql::CountWithSeveralExit_Loop;

use strict;
use warnings;
use Erreurs;
use Couples;
use CountUtil;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

# prototypes prives
sub RecursivSearchExit($);

# prototypes publiques
sub CountWithSeveralExit_Loop($$$);


sub RecursivSearchExit($) {

  my ( $node ) = @_ ;

  my $children = GetSubBloc($node);

  my $child;
  my $nb_exit = 0;
  foreach $child (@{$children}) {

    if ( IsKind($child, LoopKind) || IsKind($child, ExceptionKind) ) {
      #last;
      next;
    }

    if (defined GetSubBloc($child)) {
      # Si c'est un bloc on le parcoure.
      $nb_exit += RecursivSearchExit($child);
    }
    else {
      # Si c'est un statement on l'analyse.
      if (IsKind($child, StatementKind)) {
        my $stmt = GetStatement($child);

        if (defined $stmt) {
          if ($stmt =~ /^\s*(exit|return)\b/smi) {
            $nb_exit++;
          }
        }
      }
    }
  }

  return $nb_exit;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des lignes de code en commentaire.
#-------------------------------------------------------------------------------
sub CountWithSeveralExit_Loop($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $mnemo_WithSeveralExit_Loop = Ident::Alias_WithSeveralExit_Loop();
  my $status = 0;
  my $nbr_WithSeveralExit_Loop = 0;

  my $input =  $vue->{'structured_code_by_kind'} ;

  if ( ! defined $input ) {
    $status |= Couples::counter_add($compteurs, $mnemo_WithSeveralExit_Loop, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @LoopList = PlSql::PlSqlNode::GetNodesByKindFromSpecificView($input, LoopKind) ;

  foreach my $loop (@LoopList) {
    my $nb_exit = RecursivSearchExit($loop);

    if ($nb_exit > 1) {
      $nbr_WithSeveralExit_Loop++;
    }
  }

  $status |= Couples::counter_add($compteurs, $mnemo_WithSeveralExit_Loop, $nbr_WithSeveralExit_Loop);

  return $status;
}

1;
