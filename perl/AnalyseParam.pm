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
# Description: Module de lecture fichier IHM
#----------------------------------------------------------------------#

package AnalyseParam;

use strict;
use warnings;

use Erreurs;
use Options;

sub new ($$$)
{
    # Attend en parametre le nom du fichier de configuration
    my ($class, $configFilename, $options) = @_;
    my $self = {};

    bless $self, $class;

    $self->{'isCorrect'} = 1 ;
    $self->{'options'} = $options ;
    $self->{'current_ana'} = 0 ;
    $self->initialize($configFilename) ;

    die "Fichier de configuration incorrect" if ( not $self->{'isCorrect'} );

    return $self;
}

sub initialize ($$)
{
  my ($self, $configFilename) = @_;
  $self->{'content'} = $self->load($configFilename) ;
                       $self->ParseContent() ;
}

sub getContent ($$)
{
  my ($self) = @_;
  return $self->{'content'} ;
}

sub load ($$)
{
  my ($self, $configFilename) = @_;
  my @content = ();
  #Valide l'ouverture en lecture du fichier config.
  my $rLignes = $self->open($configFilename) ;
  if (not defined $rLignes)
  {
    print STDERR "Ne peut ouvrir le fichier de configuration\n" ;
    $self->{'isCorrect'} = 0 ;
    return ;
  }
  my @lignes = @{$rLignes};

  my $numLigne = 1;
  my $sectionName ;
  for my $ligne ( @lignes)
  {
    $ligne =~ s/\x{23}.*$//m ; # Suppression des commentaires.
    #$ligne =~ s/\s*$// ; # Suppression des blancs de fin de lignes.
    if ( $ligne =~ /^\s*$/m )
    {
      # Ligne blanche: ne rien faire
    }
    else
    {
      push @content, [  $numLigne  ,$ligne ]
    }
    $numLigne++;
  }
  return \@content;
}

#Valide l'ouverture en lecture du fichier config.
sub open ($$)
{
  my ($self, $configFilename) = @_;

  print STDERR "Utilisation du fichier de configuration >$configFilename<\n" ;
  my $is_opened = open(C, '<:raw', $configFilename)   ;
  if (not defined $is_opened )
  {
    print STDERR  "Le fichier ne peut pas etre lu: $configFilename: cannot read: $!\n";
    $self->{'isCorrect'} = 0 ;
    #die ;
    return undef;
  }
  local $/ = "\n";
  if  ( -d C )
  {
    print STDERR "Fichier ".  $configFilename . " echec (repertoire)\n" ;
    close(C);
    $self->{'isCorrect'} = 0 ;
    #die ;
    return undef ;
  }
  my @lignes = <C>;
  close(C);
  return \@lignes;
}

sub ParseLine($)
{
  my ($data) = @_;
    my ( $NumLigne, $Ligne ) = @{$data};
    if ( $Ligne =~ /\s*[[]\s*(\S*)\s*[]]\s*(.*)/ )
    {
      my ( $fieldname, $valuesString ) = ( $1, $2 );
      # FIXME: check analyseur availability
      #print STDERR $fieldname . ' ' . $valuesString . "\n" ;
      my @values = split ( '\s*[|]\s*', $valuesString);
      for my $value ( @values )
      {
      #print STDERR '         --> ' . $value . "\n" ;
        #print STDERR "Association >$extension< -> >$analyseur< \n" ;
        #FIXME:$AnalyseurBySuffix{$extension} = $analyseur;
      }
      return [ $fieldname, \@values];
    }
    else
    {
      my $message = $NumLigne . ':' . $Ligne;
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'AnalyseParam', 'Ligne non reconnue', $message); 
      return undef;
    }

}

sub _setOptions($$$)
{
  my ($self, $field, $values) = @_;

  return if (scalar @$values == 0);
  
  my @splittedValues = split ( '\s\s*', $values->[0]);
  my ( $refHash, undef) = Options::traite_options( \@splittedValues );
  #my %hashNewOptions = %{$xxx[0]};
  my %hashNewOptions = %{$refHash};
  for my $key ( keys (%hashNewOptions) )
  {
	print STDERR "Take into account option $key -> " . $hashNewOptions{$key} . "\n" ;
    $self->{'options'}->{$key} = $hashNewOptions{$key};
  }
}

sub _setField($$$)
{
  my ($self, $field, $values) = @_;
#print STDERR $field .'   '. $values . "\n" ;
  $self->{'field'}->{$field} = $values->[0];
}

sub GetAnalysisBasename($)
{
  my ($self) = @_;
  return $self->{'field'}->{'nom_fichier'};
}

sub _setOutputFilename($$$)
{
  my ($self, $field, $values) = @_;
#print STDERR $field .'   '. $values . "\n" ;
  $self->{'field'}->{$field} = $values->[0];

  # Dans la ces d'utilisation cle USB standalone, 
  # on souhaite passer le nom de fichier de sortie CSV depuis la ligne de commande.
  # Dans le mode client serveur (application web),
  # on souhaite generer le nom du fichier CSV
  # automatiquement d'apres le nom de l'analyse.
  if ( not defined $self->{'options'}->{'--o'} )
  {
    $self->{'options'}->{'--o'} = $values->[0];
  }
}

sub _setAnaField($$$)
{
  my ($self, $field, $values) = @_;
  for my $i ( 0..scalar @{$values} )
  {
    $self->{'ana'}->[$i]->{$field} = $values->[$i];
  }
  
}

my %fieldActions = (
  'options' => \&_setOptions ,
  'nom_fichier' => \&_setOutputFilename ,
  'nb_fichiers_tot' => \&_setField ,
  'app_type' => \&_setField ,
  'timeout_ana' => \&_setAnaField ,
  'analyseurs_ana' => \&_setAnaField ,
  'fichiers_liste_ana' => \&_setAnaField ,
  'nb_fichiers_ana' => \&_setAnaField ,
);

sub ParseContent($)
{
  my ($self) = @_;
  my $content = $self->getContent();
  my %emptyHash =();
  $self->{'field'} = \%emptyHash;
  my @anas = ();
  $self->{'ana'} = \@anas;
  for my $data ( @{$content} )
  {
    my ( $NumLigne, $Ligne ) = @{$data};
    my $line = ParseLine($data);
    next if not defined $line;
    my ( $field, $values) = @$line;
    my $action = $fieldActions{$field};
    if (defined $action)
    {
      $action->($self, $field, $values);


    }
    else
    {
      my $message = $NumLigne . ':' . $field . ':' . $Ligne;
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'AnalyseParam', 'Champ inconnu', $message); 
    }


  }
  #$isLoaded=1;
}

sub NextAna($)
{
  my ($self) = @_;
  $self->{'current_ana'} ++ ;
}

sub GetCurrentAnaList($)
{
  my ($self) = @_;
  my $i = $self->{'current_ana'};
  my $fileParam = $self->{'ana'}->[$i]->{'fichiers_liste_ana'};
  my $fileNumberExpected = $self->{'ana'}->[$i]->{'nb_fichiers_ana'};
  if (defined $fileParam)
  {
    my $DialogDirectory = AnalyseOptions::GetDialogDirectory( $self->{'options'} );
    my $filelist = FileList->new( $DialogDirectory . $fileParam );
    my $lus = $filelist->GetFileNumber();
    if ( $lus != $fileNumberExpected)
    {
      print STDERR "file number mismatch: expected $fileNumberExpected read $lus \n";
      return undef;
    }
    return $filelist;
  }
  else
  {
    return undef;
  }
}

sub GetCurrentAnaName($)
{
  my ($self) = @_;
  my $i = $self->{'current_ana'};
  my $name = $self->{'ana'}->[$i]->{'analyseurs_ana'};
  return $name;
}

sub GetCurrentAnaTimeout($)
{
  my ($self) = @_;
  my $i = $self->{'current_ana'};
  my $timeout = $self->{'ana'}->[$i]->{'timeout_ana'};
  $timeout -= 60;
  if ($timeout < 1)
  {
    $timeout=1;
  }
  return $timeout;
}

sub GetFilesNumber($)
{
  my ($self) = @_;
  my $number = $self->{'field'}->{'nb_fichiers_tot'};
  return $number;
}

sub GetAppType($)
{
  my ($self) = @_;
  my $value = $self->{'field'}->{'app_type'};
  return $value;
}


1;
