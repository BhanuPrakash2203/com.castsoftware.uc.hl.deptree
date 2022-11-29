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
# Description: lecture de liste de fichier.
#----------------------------------------------------------------------#


package FileList;

# les modules importes
use strict;
use warnings;

sub new ($)
{
  my $perlClass=shift;
  my ($FileList)=@_;

  my $self = {};

  bless $self;
  $self->Load( $FileList );

  return $self;
}

# Description: Lecture du fichier liste des sources a traiter
# Parametres : une liste d'options (de la ligne de commande)
# Retour :
#          - une liste de nom de fichiers sources si l'option --file-list
#            a ete utilisee a bon escient
#          - une liste vide si l'option --file-list n'est pas positionnee
#            ou si le fichier liste designe n'est pas accessible en lecture
sub Load($$)
{
  my ($self, $FilelistOption) = @_;
  my @tbFiles = ();
   my @array = ( split ( ',' , $FilelistOption ) );
   foreach my $item ( @array)
   {
    $item =~ /^(?:([^#]*)#)?(.*)/ ;

    my $context = $1;
    my $listFile = $2;

	# Force the content of the file to UTF8. So we can have a right representation
	# non ascii characters.
    if (open(LISTFILE, "<:encoding(UTF_8)", "$listFile"))
    {
      # lecture du fichier contenant la liste des fichiers a analyser.
      while (<LISTFILE>)
      {
        $_ =~ s/\s*$//; # nettoyage de fin de ligne
        # chaque ligne non vide est consideree
        # comme un nom de fichier source
        if (length($_) > 0)
        {
          my $filename = $_;
          push @tbFiles, [ $context, $filename ]; 
        }
      }
        close LISTFILE;
    }
    else
    {
      print STDERR "Unable to read $listFile: $!\n";
    }
   }
  $self->{'list'} = \@tbFiles;
}

sub GetFileList($)
{
  my ($self) = @_;
  return $self->{'list'};
}

sub GetFileNumber($)
{
  my ($self) = @_;
  return scalar @{$self->{'list'}};
}


1;
