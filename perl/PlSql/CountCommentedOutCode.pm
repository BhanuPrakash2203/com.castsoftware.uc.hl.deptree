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

package PlSql::CountCommentedOutCode;

use strict;
use warnings;
use Erreurs;
use Couples;

use Erreurs;

# prototypes publiques
sub CountCommentedOutCode($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des lignes de code en commentaire.
#-------------------------------------------------------------------------------
sub CountCommentedOutCode($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $mnemo_CommentedOutCode = Ident::Alias_CommentedOutCode();
  my $status = 0;
  my $nbr_CommentedOutCode = 0;

  if ( ! defined $vue->{comment} ) {
    $status |= Couples::counter_add($compteurs, $mnemo_CommentedOutCode, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @TLines = split(/\n/, $vue->{comment});

  foreach my $line (@TLines) {

    # Suppression des marqueurs de commentaires dans la vue "commentaire".
    $line =~ s{(/[*]|[*]/|--)}{  }g;

    # reperage des lignes qui se terminent par ";" ou "," ou "{" ou "}"
    if ( $line =~ /[;,\{}]\s*$/ ) {
      $nbr_CommentedOutCode++;
      Erreurs::LogInternalTraces('DEBUG', undef, undef, $mnemo_CommentedOutCode, $line, '');
    }

    # reperage des lignes qui commencent par "for", "while", ...
    elsif ( $line =~ /^\s*(if\s*\(|else\b|while\s*\(|for\s*\(|elsif\b|end\b|create\b|begin\b)/i ) { 
      $nbr_CommentedOutCode++;
      Erreurs::LogInternalTraces('DEBUG', undef, undef, $mnemo_CommentedOutCode, $line, '');
    }
    else {
    }
  }
  $status |= Couples::counter_add($compteurs, $mnemo_CommentedOutCode, $nbr_CommentedOutCode);

  return $status;
}

1;
