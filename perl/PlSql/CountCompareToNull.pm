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

package PlSql::CountCompareToNull;

use strict;
use warnings;
use Erreurs;
use Couples;
use CountUtil;
use PlSql::PlSqlNode;

use Erreurs;

# prototypes publiques
sub CountCompareToNull($$$);


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des lignes de code en commentaire.
#-------------------------------------------------------------------------------
sub CountCompareToNull($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $mnemo_CompareToNull = Ident::Alias_CompareToNull();
  my $mnemo_CompareToEmptyString = Ident::Alias_CompareToEmptyString();
  my $status = 0;
  my $nbr_CompareToNull = 0;
  my $nbr_CompareToEmptyString = 0;

  my $input =  $vue->{'structured_code'} ;

  if ( ! defined $input ) {
    $status |= Couples::counter_add($compteurs, $mnemo_CompareToNull, Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, $mnemo_CompareToEmptyString, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $rH_String = $vue->{'HString'};

  my @CondNodeList = PlSql::PlSqlNode::GetConditionalNodes ($input) ;

  foreach my $node (@CondNodeList) {

    my $cond = GetCondition($node);

    if ( $cond ) {
      my $found = () = $cond =~ /([^=]=\s*null\b|null\s*[^=]=)/ig;
      $nbr_CompareToNull+= $found;

      while ( $cond =~ /([^=]=\s*(CHAINE_\d+)|(CHAINE_\d+)\s*[^=]=)/ig ) {

        my $chaine_id = '';

        if ( defined $2) { $chaine_id = $2;} else { $chaine_id = $3; }

        my $chaine = $rH_String->{$chaine_id};

        if ( defined $chaine ) {
          if ( $chaine eq '\'\'' ) {
            $nbr_CompareToEmptyString++;
          }
        }
      }
    }
    else {
      print STDERR "ATTENTION: [PARSER] condition nulle pour un 'conditional node' .\n";
    }
  }

  $status |= Couples::counter_add($compteurs, $mnemo_CompareToNull, $nbr_CompareToNull);
  $status |= Couples::counter_add($compteurs, $mnemo_CompareToEmptyString, $nbr_CompareToEmptyString);

  return $status;
}

1;
