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

package PlSql::CountIllegalException;

use strict;
use warnings;
use Erreurs;
use Couples;
use CountUtil;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

# prototypes publiques
sub CountIllegalException($$$);


my @T_StandardException = ('ACCESS_INTO_NULL', 'CASE_NOT_FOUND', 'COLLECTION_IS_NULL', 'CURSOR_ALREADY_OPEN', 'DUP_VAL_ON_INDEX', 'INVALID_CURSOR', 'INVALID_NUMBER', 'LOGIN_DENIED', 'NO_DATA_FOUND', 'NOT_LOGGED_ON', 'PROGRAM_ERROR', 'ROWTYPE_MISMATCH', 'SELF_IS_NULL', 'STORAGE_ERROR', 'SUBSCRIPT_BEYOND_COUNT', 'SUBSCRIPT_OUTSIDE_LIMIT', 'SYS_INVALID_ROWID', 'TIMEOUT_ON_RESOURCE', 'TOO_MANY_ROWS', 'VALUE_ERROR', 'ZERO_DIVIDE');


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des lignes de code en commentaire.
#-------------------------------------------------------------------------------
sub CountIllegalException($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $mnemo_IllegalException = Ident::Alias_IllegalException();
  my $status = 0;
  my $nbr_IllegalException = 0;

  my $input =  $vue->{'structured_code_by_kind'} ;

  if ( ! defined $input ) {
    $status |= Couples::counter_add($compteurs, $mnemo_IllegalException, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my %H_ID = ();

  foreach my $ID (@T_StandardException) {
    $H_ID{$ID} = 1;
  }

  my @DeclList = PlSql::PlSqlNode::GetNodesByKindFromSpecificView ($input, DeclarativeKind) ;

  foreach my $decl (@DeclList) {
    
    my $children = GetSubBloc($decl);

    my $child;
    foreach $child (@{$children}) {
      if ( IsKind($child, VariableDeclarationKind)) {
        my $stmt = GetStatement($child);

        if ($stmt =~ /\b([\w\.\$#]+)\s*exception\b/i) {
          if ( defined $H_ID{$1}) {
            $nbr_IllegalException++;
          }
        }
      }
    }

  }

  $status |= Couples::counter_add($compteurs, $mnemo_IllegalException, $nbr_IllegalException);

  return $status;
}

1;
