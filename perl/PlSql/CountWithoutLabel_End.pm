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

package PlSql::CountWithoutLabel_End;

use strict;
use warnings;
use Erreurs;
use Couples;
use CountUtil;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

# prototypes publiques
sub CountWithoutLabel_End($$$);


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des lignes de code en commentaire.
#-------------------------------------------------------------------------------
sub CountWithoutLabel_End($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $mnemo_WithoutLabel_End = Ident::Alias_WithoutLabel_End();
  my $status = 0;
  my $nbr_WithoutLabel_End = 0;

  my $input =  $vue->{'structured_code_by_kind'} ;

  if ( ! defined $input ) {
    $status |= Couples::counter_add($compteurs, $mnemo_WithoutLabel_End, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }


  my @EndList = PlSql::PlSqlNode::GetNodesByKindFromSpecificView($input, EndKind) ;

  foreach my $End (@EndList) {
    my $Parent = GetParent($End);

    my $stmt = GetStatement($End);

    my $Pstmt = GetStatement($Parent);

    if ( IsKind($Parent, ProcedureKind) or
         IsKind($Parent, FunctionKind) or
         IsKind($Parent, PackageKind) or
         IsKind($Parent, TypeKind) ) {

      if (defined $stmt) {
        if ( $stmt !~ /\bend[ \t]+\w+[\s;]/i) {
          $nbr_WithoutLabel_End++;
        }
        else {
          # OK.
        }
      }
      else {
        print STDERR "ATTENTION : la valeur du 'statement' associe a un 'node EndKind' n'est pas disponible.\n";
      }
    }
    else {
      # Cas de figure non recherche.
    }
  }

  $status |= Couples::counter_add($compteurs, $mnemo_WithoutLabel_End, $nbr_WithoutLabel_End);

  return $status;
}

1;
