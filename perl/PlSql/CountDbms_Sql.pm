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

package PlSql::CountDbms_Sql;

use strict;
use warnings;
use Erreurs;
use Couples;
use CountUtil;
use PlSql::PlSqlNode;

use Erreurs;

# prototypes publiques
sub CountDbms_Sql($$$);


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des lignes de code en commentaire.
#-------------------------------------------------------------------------------
sub CountDbms_Sql($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $mnemo_Dbms_Sql_Parse = Ident::Alias_Dbms_Sql_Parse();
  my $mnemo_Dbms_Sql_Open = Ident::Alias_Dbms_Sql_Open();
  my $status = 0;
  my $nbr_Dbms_Sql_Parse = 0;
  my $nbr_Dbms_Sql_Open = 0;

  my $input =  $vue->{'code_lc_without_directive'} ;

  if ( ! defined $input ) {
    $status |= Couples::counter_add($compteurs, $mnemo_Dbms_Sql_Parse, Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, $mnemo_Dbms_Sql_Open, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  $nbr_Dbms_Sql_Parse += () = $input =~ /\bdbms_sql[ \t]*\.[ \t]*parse\b/g;
  $nbr_Dbms_Sql_Open += () = $input =~ /\bdbms_sql[ \t]*\.[ \t]*open\b/g;

  $status |= Couples::counter_add($compteurs, $mnemo_Dbms_Sql_Parse, $nbr_Dbms_Sql_Parse);
  $status |= Couples::counter_add($compteurs, $mnemo_Dbms_Sql_Open, $nbr_Dbms_Sql_Open);

  return $status;
}

1;
