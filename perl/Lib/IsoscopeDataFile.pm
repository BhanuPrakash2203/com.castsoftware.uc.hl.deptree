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
# DESCRIPTION: Composant de gestion d'attributs (couples identifiant, valeur).
# dans un fichier csv.
#----------------------------------------------------------------------#


package IsoscopeDataFile;

# les modules importes
use strict;
use warnings;

use Traces;

# prototypes publics
sub getBinaryMnemos();
sub getUnknownMnemos();
sub checkMnemoList($);

sub csv_file_open($);
sub csv_file_type_register($$);
sub csv_is_file_type_registered($);
sub csv_print_type_header($);
sub csv_file_append($);
sub csv_file_close();

# prototypes prives
sub return_error ($$);

my $debug = 0;  # traces_filter_line
my $optionChronoColumn=undef;

#-------------------------------------------------------------------------------
# DESCRIPTION: Routine de remontee d'erreur
#-------------------------------------------------------------------------------
sub return_error ($$)
{
  my ($msg, $val) = @_;
  #print STDERR "Ne peut pas creer le fichier: $! : $? : $filename" ;            # traces_filter_line
  print STDERR $msg;
  return $val;
  #die ": $! : $? : $filename" ;                                                 # traces_filter_line
}

sub SetOptionChronoColumn()
{
  $optionChronoColumn = 1;
}



# dumpvues_filter_start


#-------------------------------------------------------------------------------
# DESCRIPTION: Creation d'un fichier resultat unique au format CSV
#-------------------------------------------------------------------------------

my @binaryMnemos = ('Dat_FileName', 'Dat_Language', 'Dat_AnalysisDate', 'Dat_AnalysisStatus', 'Dat_AbortCause');

my @unknownMnemos = ('Dat_FileName', 'Dat_Language', 'Dat_AnalysisDate', 'Dat_AnalysisStatus', 'Dat_AbortCause', 
                      'Dat_Lines', 'Nbr_Lines');
                      
# WARNING : the first mnemonics MUST be 'Dat_FileName' and 'Dat_Language' because the function Lib::CsvFile::new assumed they are at this position.
my @textMnemos = ('Dat_FileName', 'Dat_Language', 'Dat_CRC', 'Dat_SHA256', 'Dat_AnalysisDate', 'Dat_AnalysisStatus', 'Dat_AbortCause', 
                      'Dat_AnaModel', 'Dat_Lines', 'Nbr_Lines', 'Dat_ContextType');


#-------------------------------------------------------------------------------
# DESCRIPTION: Recuperation de la liste des mnemoniques devant etre renseignees
#   pour les fichiers binaires
#-------------------------------------------------------------------------------
sub getBinaryMnemos()
{
  return \@binaryMnemos;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Recuperation de la liste des mnemoniques devant etre renseignees
#   pour les fichiers non reconnus
#-------------------------------------------------------------------------------
sub getUnknownMnemos()
{
  return \@unknownMnemos;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Table de listes triee des mnemoniques
# par type de code source
#-------------------------------------------------------------------------------
my %hMnemoLists;

#-------------------------------------------------------------------------------
# DESCRIPTION: Memorisation des types de fichiers dont l'en-tete
# a ete memorise dans le fichier CSV resultat
#-------------------------------------------------------------------------------
my %hSectionUsed;

#-------------------------------------------------------------------------------
# DESCRIPTION: Handler de fichier de sortie CSV
#-------------------------------------------------------------------------------
my $csv_fh = undef;

#-------------------------------------------------------------------------------
# DESCRIPTION: Separateur de champs
#-------------------------------------------------------------------------------
my $csv_sep = ';';

sub classDestroy($)
{
  my ($class) = @_;
  close ($csv_fh);
  $csv_fh = undef;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Verification de la presence des mnemoniques minimaux
# et de l'unicite de chaque mnemonique
#-------------------------------------------------------------------------------
sub checkMnemoList($)
{
  my ($rList) = @_;

  my %hSaved  = ();
  my @tbSaved = ();

  # on veut figer les colonnes obligatoires
  push(@tbSaved, @textMnemos);
  
  if (defined $optionChronoColumn)
  {
    push ( @tbSaved, 'Dat_Chrono');
  }

  for my $mnemo (@tbSaved) {
	  $hSaved{$mnemo} = 1;
  }

  my @tbInMnemos = @$rList;

  # Eviter les doublons
  for (my $indMnemo = 0; $indMnemo <= $#tbInMnemos; $indMnemo++) {
    #my $indSaved;
    #for ($indSaved = 0; $indSaved <= $#tbSaved; $indSaved++)
    #{
    #  last if ($tbSaved[$indSaved] eq $tbInMnemos[$indMnemo]);
    #}
    #push(@tbSaved, $tbInMnemos[$indMnemo]) if ($indSaved > $#tbSaved);
    
    # HASH are more efficient than searching in array.
    next if exists $hSaved{ $tbInMnemos[$indMnemo] };
    push(@tbSaved, $tbInMnemos[$indMnemo]);
    $hSaved{ $tbInMnemos[$indMnemo] } = 1;
  }

  return \@tbSaved;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Ouverture du fichier de resultat CSV
# FIXME: et ecriture (eventuelle) de son en-tete
#
# Parametres : nom de fichier.
#              (optionnel) reference sur une liste ordonnees de mnemoniques,
#              supporte uniquement en analyse d'un lot de codes sources mono-langage.
#-------------------------------------------------------------------------------
sub csv_file_open($)
{
  my ($fileName) = @_;

  return return_error ('Erreur interne : fichier de sortie deja ouvert', 4) if (defined $csv_fh);

  open $csv_fh , '>' . $fileName or return return_error ("Impossible de creer le fichier: $! : $? : $fileName", 4);

  binmode($csv_fh, ":utf8");

  %hMnemoLists = ( 'Binary' => \@binaryMnemos,
                   'Unknown' => \@unknownMnemos);
  %hSectionUsed = ();

  return 0;
}

# bt_filter_start

# ajout de l'entete de metadonnees.
sub csv_set_metadata($)
{
  my ($refMetadata) = @_;

  print $csv_fh "#Info \n" ;
  for my $key (keys %{$refMetadata} )
  {
    my $value = $refMetadata->{$key} ;
    if (not defined $value)
    {
      Traces::LogInternalTraces('warning', undef, undef, 'csv_set_metadata', 'metadonnee indisponible', $key); # traces_filter_line
      $value = 'undefined';
    }
    print $csv_fh '# ' . $key . $csv_sep . $value . "\n" ;
  }
}

# bt_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: Enregistrement des mnemoniques d'un type de fichier
#-------------------------------------------------------------------------------
sub csv_file_type_register($$)
{
  my ($type, $rMnemos) = @_;

  print STDERR "csv_file_type_register pour $type\n" if ($debug != 0); # traces_filter_line
  return_error ('Type deja enregistre' . $type, 64) if (defined $hMnemoLists{$type});

  my $rMnemoList = checkMnemoList($rMnemos);
  $hMnemoLists{$type} = $rMnemoList;

  print STDERR "Mnemoniques du type $type : " . join('|', @{$rMnemoList}) . "\n" if ($debug != 0);  # traces_filter_line

  return 0;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Verifie qu'il est necessaire de calculer la liste des
# mnemoniques du type de fichier
#-------------------------------------------------------------------------------
sub csv_is_file_type_registered($)
{
  my ($type) = @_;

  my $retour = 0;

  $retour = 1 if (defined $hMnemoLists{$type});

  return $retour;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Ecriture d'un en-tete de type de fichier dans le fichier de resultat CSV
#-------------------------------------------------------------------------------
sub csv_print_type_header($)
{
  my ($type) = @_;

# SHOULD BE USELESS, since $hMnemoLists{'default'} definitively doesn't exists ...
  #if (exists($hMnemoLists{'default'}) && $type ne 'Unknown' && $type ne 'Binary')
  #{
  #  $hMnemoLists{$type} = $hMnemoLists{'default'};   # Comment est créé $hMnemoLists{'default'} ???? puisque 'default' n'est jamais utilisé ???
  #  delete $hMnemoLists{'default'};
  #}

  return 0 if (exists($hSectionUsed{$type}));

  # FIXME: est-il vraiment necessaire d'afficher un en-tete particulier
  # FIXME: pour les fichiers binaires et de type inconnu ???

  # creation d'une ligne ne contenant que le type
  # print $csv_fh "$type\n";
  print $csv_fh "section=$type\n";

  if (! exists($hMnemoLists{$type}))
  {
    $hMnemoLists{$type} = $hMnemoLists{'Unknown'};
  }

  my @mnemo_list = @{$hMnemoLists{$type}};
  my $first = 1;

  for my $mnemo (@mnemo_list)
  {
    if ($first == 1)
    {
      $first = 0;
    }
    else
    {
      print $csv_fh $csv_sep;
    }
    print $csv_fh $mnemo;
  }
  print $csv_fh "\n";

  $hSectionUsed{$type} = 1;

  return 0;
}

sub find_missing_columns($)
{
  my ( $couples) = @_;

  my $type;
  my @missings=();

  if ( exists($couples->{'Dat_Language'}) )
  {
    $type = $couples->{'Dat_Language'};
  }
  else
  {
    $type = 'Unknown';
  }

  if (! defined $hMnemoLists{$type}) {
	  print "[find_missing_columns] no mnemonic for type $type\n";
	  print "[find_missing_columns] possibilities are ".(join " ", keys %hMnemoLists)."\n";
  }
  my @mnemo_list = @{$hMnemoLists{$type}};
  my $first = 1;

  for my $mnemo (@mnemo_list)
  {
    my $val = $couples->{$mnemo};
    if ( (not defined $val ) or
         ( $val eq '' ) or 
         ( $val =~ /\A[-]/ ) )
    {
      Traces::debug(1,"Donnee manquante: $mnemo: $val\n") if defined $val;
      Traces::debug(1,"Donnee manquante: $mnemo \n") if not defined $val;
      #$count++;
      push @missings, $mnemo;
    }
  }
  return \@missings;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Ajout d'une ligne de resultats de comptages pour un fichier analyse
#-------------------------------------------------------------------------------
sub csv_file_append($)
{
  my ($couples) = @_;

  my $type;

  if ( exists($couples->{'Dat_Language'}) )
  {
    $type = $couples->{'Dat_Language'};
  }
  else
  {
    $type = 'Unknown';
  }
  csv_print_type_header($type);

  my @mnemo_list = @{$hMnemoLists{$type}};
  my $first = 1;

  for my $mnemo (@mnemo_list)
  {
    if ($first == 0)
    {
      print $csv_fh $csv_sep;
    }
    else
    {
      $first = 0;
    }
    if (exists($couples->{$mnemo}))
    {
      print $csv_fh $couples->{$mnemo}
    }
  }
  print $csv_fh "\n";
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Fermeture du fichier global de resultats de comptages d'un ensemble
# de fichiers
#-------------------------------------------------------------------------------
sub csv_file_close()
{
  close $csv_fh;
}


1;

