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
# Description: Module de suppression de commentaires sur du code VB6

package StripVb6;
use strict;
use warnings;
use Erreurs;

# Le VB6 peut contenir un header, il est genant, donc on l'enleve.
# Le header est de la forme suivante:
#  VERSION 1.0 CLASS
#  BEGIN
  #  MultiUse = -1  'True
#  END
#  Attribute VB_Name = "HTMLHelp"
sub separer_vb6_header($$$)
{
  my ($unused, $vue, $options ) = @_ ;

  if ( $vue->{'text'} =~ /\A(VERSION\s[^\n]*\n(?:Object\s[^\n]*\n)*BEGIN[^\n]*\n.*?^END\n(?:Attribute[^\n]*\n)*)(.*)/sim )
  {
    my $header = $1;
    my $contenu = $2;
    $vue->{'vb6header'} = $header;
    $vue->{'text'} = $contenu;
  }
  else
  {
    print STDERR "Echec du traitement de l'header VB6 \n" ;
  }

}

1;
