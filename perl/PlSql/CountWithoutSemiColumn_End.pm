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

package PlSql::CountWithoutSemiColumn_End;

use strict;
use warnings;
use Erreurs;
use Couples;
use CountUtil;
use PlSql::PlSqlNode;

# prototypes publiques
sub CountWithoutSemiColumn_End($$$);


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des lignes de code en commentaire.
#-------------------------------------------------------------------------------
sub CountWithoutSemiColumn_End($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $mnemo_WithoutSemiColumn_End = Ident::Alias_WithoutSemiColumn_End();
  my $mnemo = $mnemo_WithoutSemiColumn_End;
  my $status = 0;
  my $nbr_WithoutSemiColumn_End = 0;

  my $input =  $vue->{'code_lc_without_directive'} ;
#  my $input =  $vue->{'structured_code'} ;
#
  if ( ! defined $input ) {
    $status |= Couples::counter_add($compteurs, $mnemo_WithoutSemiColumn_End, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  # Capture only "end" statement that are not inside SELECT statement
  while ( $input =~ /\bselect\b(?:[^;]*)|\bend\b([^;\n]*(?:[;\n]|\z))/g ) {

	next if ! defined $1;

    my $expr = $1;
    if ( $expr =~ /^[ \t]*(\w+)?[ \t]*([\w\.\$#]+)?[ \t]*;/ ) {
	
	  #---------------------------------------------------
	  # The END contains a ";" before the end of the line 
	  #   -> violation if the "end" is followed with more items than authorized.
	  #---------------------------------------------------
	   
      my $P1 = $1; # the word that follow the "end"
      my $P2 = $2; # a mix \w\.\$# => identifiant label ?  
  
      # by default, only one item authorized after the end.
      my $nb_item_authorized = 1;
      my $nb_item_found =0;

      if (defined $P1) {
        $nb_item_found ++;

        if ($P1 =~ /^loop$/) {
		  # for the loop, an additional item (captured in P2) is authorized (a loop can be named)...
          $nb_item_authorized += 1;
        }
      }

      if (defined $P2) {
        $nb_item_found++;
      }

      if ( $nb_item_found > $nb_item_authorized ) {
        $nbr_WithoutSemiColumn_End++;
      }
    }
    else {
	  #---------------------------------------------------
	  # The END DO NOT contains a ";" before the end of the line 
	  #   -> true violation
	  #---------------------------------------------------
      $nbr_WithoutSemiColumn_End++;
    }
  }

  $status |= Couples::counter_add($compteurs, $mnemo_WithoutSemiColumn_End, $nbr_WithoutSemiColumn_End);

  return $status;
}

1;
