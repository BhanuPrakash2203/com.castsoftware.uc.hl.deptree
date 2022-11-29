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

# Composant: Framework
#----------------------------------------------------------------------#
# DESCRIPTION: Composant de chargement d'un fichier source
#----------------------------------------------------------------------#


package SourceLoader;
use strict ;
use warnings ;

use AutoDecode ;

# prototypes publics
sub mainLoadFile($$);

# prototypes prives
sub LoadBinaryBuffer($);

#-------------------------------------------------------------------------------
# DESCRIPTION: Chargement d'un fichier, en mode binaire.
#-------------------------------------------------------------------------------
sub LoadBinaryBuffer($)
{
  my ($fileName ) = @_;
  #print ">$fileName<\n" ;                                                      # traces_filter_line
  $fileName = AutoDecode::RemoveNonPrintableCharacters($fileName);
  #print ">$fileName<\n" ;                                                      # traces_filter_line
  #print STDERR " file: $fileName \n" ;                                         # traces_filter_line
  my $is_opened = open(C, '<:raw', $fileName)   ;
  if (not defined $is_opened )
  {
    print STDERR  "Le fichier ne peut pas etre lu: $fileName: cannot read: $!\n";
    return undef;
  }
  local $/ = undef;
  if  ( -d C )
  {
    print STDERR "Fichier ".  $fileName . " echec (repertoire)\n" ;
    close(C);
    return undef ;
  }
  my $octets = <C>;
  close(C);
  return $octets ;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Chargement d'un fichier de code source.
#-------------------------------------------------------------------------------
sub mainLoadFile($$)
{
  my ($fichier, $options) = @_;
  my %h_vues = ();
  my $vue = \%h_vues;
  my $binary_buffer = '';
  if (not exists $options->{'--directload'})
  {
    #print "process_file debut " . $fichier ."\n";                              # traces_filter_line
    # Chargement du fichier binaire
    $binary_buffer = LoadBinaryBuffer ( $fichier );

    if ( defined $binary_buffer) # Si ce n'est pas un repertoire (
    # Et si le fichier ne peut pas etre lu?
    {
      my $detectedEncoding ;
      $vue->{'bin'} = $binary_buffer;
      # Decodage du fichier.
      my $text_buffer ;
      # L'option --NoAutoDetectEncoding est livree (cachee) a Bouygues pour le projet 482 # traces_filter_line
      if (not defined $options->{'--NoAutoDetectEncoding'})
      # par defaut, on veux notamment reperer les fichiers binaires.
      {
        #print STDERR "detection de l'option :" .                                         # traces_filter_line
        #  $options->{'--AutoDetectEncoding'}  ."\n";                                     # traces_filter_line
        # L'option --AutoDetectEncoding est livree (cachee) a Bouygues pour le projet 482 # traces_filter_line
        $text_buffer = AutoDecode::BinaryBufferToTextBuffer ( $fichier,
          \$binary_buffer, $options->{'--AutoDetectEncoding'}, \$detectedEncoding );
      }
      else # pour des raisons de test,
      # on n'utilise pas un encodage defini.
      {
        $text_buffer = $binary_buffer ;
        $text_buffer =~ s/\r\n/\n/g ;
      }
      
      if (defined $text_buffer) {
        # The \r should have been managed in previous decoding treatments. If it still remains some, then it is
        # an error, they should be replaced here ...
        $text_buffer =~ s/\r\n|\n\r/\n/g;

        # Les \r solidaires doivent devenir des nouvelles lignes.
        # RQ : les \r\n ont daja ete traite lors du chargement du fichier (en principe!).
      $text_buffer =~ s/\r/\n/g;
      }

      $vue->{'text'} = $text_buffer ;

      $vue->{'encoding'} = $detectedEncoding ;
    }
  }
  else
  {
    # le direct load
    # Dans ce cas, l'ouverture du fichier est native et dependant de la plateforme.

    # Modification des valeurs par defaut:
    # Sur un systeme du genre MS-DOS avec transformation
    # automatique du CRLF en "\n"
    # pour les fichiers texte alors les couches par defaut sont:
    #     unix crlf
    # (La couche basse "unix" peut etre remplacee par une couche specifique
    # au systeme.)
    # Sinon, si le "Configure" a trouve comment faire des appels
    # rapides au stdio du systeme, alors les couches par defaut sont:
    #     unix stdio
    # Sinon, les couches par defaut sont:
    #     unix perlio
    # Ces valeurs par defaut pourront changer une fois que perlio a ete mieux
    # teste et adapte.
    # Les comportements par defaut peuvent etre changes en positionnant la
    # variable d'environnement PERLIO avec une liste de couches separees par
    # des espaces ("unix" ou d'autres couches de bas niveau specifiques au
    # systeme sont toujours empilees en premier ).
    # Ceci permet de voir les effets de bogues dans differentes couches
    # par exemple:
    #     cd .../perl/t
    #     PERLIO=stdio  ./perl harness
    #     PERLIO=perlio ./perl harness
    # Pour les differentes valeurs de PERLIO voir "PERLIO" dans perlrun.
    print STDERR 'DirectLoad ... ';
    open(C, '<', $fichier) || die "$fichier: cannot read: $!\n";
    local $/ = undef;
    $binary_buffer = <C>;
    close(C);
    if ($binary_buffer =~ /\r\n/)
    {
      print STDERR "format Windows\n";
    }
    else
    {
      print STDERR "format Unix\n";
    }
    $vue->{'bin'}  = $binary_buffer;
    $vue->{'text'} = $binary_buffer;
  }

  if ( defined  $vue->{'text'} )
  {
    my $x000a = pack("U0C*", 0x0a);             # U+000A <control>
    # On veut que la derniere ligne de la vue texte se termine par \n.
    $vue->{'text'} =~ s/((?:$x000a)?)\z/\n/sm ;
  }
  return $vue;
}

1;

