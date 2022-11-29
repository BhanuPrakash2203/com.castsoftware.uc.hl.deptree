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

package PlSql::CountGlobalVariables;

use strict;
use warnings;
use Erreurs;
use Couples;
use CountUtil;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;




# Module de comptage 
sub CountGlobalVariables($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $mnemo_GlobalVariables = Ident::Alias_PackageBodyVariables();
  my $status = 0;
  my $nbr_GlobalVariables = 0;

  my $input =  $vue->{'structured_code_by_kind'} ;

  if ( ! defined $input ) {
    $status |= Couples::counter_add($compteurs, $mnemo_GlobalVariables, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @PackList = Lib::NodeUtil::GetNodesByKindFromSpecificView($input, PackageKind) ;

  foreach my $pack (@PackList) {

    my $stmt = Lib::NodeUtil::GetStatement($pack);
    
    if ( $stmt !~ /\bbody\b/ ) {
      my @VarList = Lib::NodeUtil::GetNodesByKind($pack, VariableDeclarationKind) ;

      $nbr_GlobalVariables += scalar @VarList ;
    }

  }

  $status |= Couples::counter_add($compteurs, $mnemo_GlobalVariables, $nbr_GlobalVariables);

  return $status;
}

1;
