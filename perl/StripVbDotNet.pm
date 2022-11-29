#------------------------------------------------------------------------------#
#                         @ISOSCOPE 2008                                       #
#------------------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                          #
#               Adresse : TERSUD - Bat A                                       #
#                         5, AVENUE MARCEL DASSAULT                            #
#                         31500  TOULOUSE                                      #
#               SIRET   : 410 630 164 00037                                    #
#------------------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                                #
# l'Institut National de la Propriete Industrielle (lettre Soleau)             #
#------------------------------------------------------------------------------#

# Composant: Plugin
# Description: Module de suppression de commentaires sur du code VB.net

package StripVbDotNet;
use strict;
use warnings;
use Erreurs;

use StripVb6 ; # Idealement, on ne devrait pas avoir cette dependance.
use VBKeepCode ;

# Renvoie un code d'erreur lorsque l'on ne sait pas faire le Strip.
sub ErrStripError()
{
  return Erreurs::COMPTEUR_STATUS_PB_STRIP;
}

sub StripVbDotNet ($$$)
{
  my ($fichier, $vue, $options ) = @_ ;

  # workaround VB6
  my $textoriginal = $vue->{'text'};

  if ( $vue->{'text'} =~ /\AVERSION\s/i )
  {
    StripVb6::separer_vb6_header(undef, $vue, $options);
  }


    my $r = VBKeepCode::VbKeepCodeFromBuffer ( $fichier, $vue->{'text'}, $options );
    return ErrStripError() if (not defined $r); 
    my $code_buffer = $r->{'code'};
    my $comment_buffer = $r->{'comment'};
    $vue->{'code'} = $code_buffer ;
    $vue->{'code_lc'} = lc ($code_buffer) ;
    $vue->{'comment'} = $comment_buffer ;
    $vue->{'MixBloc'} = $r->{'MixBloc'} ;
    $vue->{'string'} = $r->{'string'} ;

    $vue->{'sansprepro'} = $r->{'code'} ;
    $vue->{'sansprepro'} =~ s/^[ \t]*#.*$//gm ;
    
    $vue->{'agglo'} = "";
    StripUtils::agglomerate_C_Comments(\$vue->{'MixBloc'}, \$vue->{'agglo'});

    my $comment_sans_tag_buffer = $r->{'comment'};
    $comment_sans_tag_buffer =~ s/[<][^>]*(?:[>]|\n)/<>/smg ;
    $vue->{'comment_sans_tag'} = $comment_sans_tag_buffer ;

    # FIXME: workaround VB6
    $vue->{'text'} = $textoriginal ;

    return 0;
}



1;
