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

# Composant: Framework
#----------------------------------------------------------------------#
# DESCRIPTION: Mecanisme de vues permettant d'associer
# un emplacement dans un buffer a un emplacement dans un autre buffer.
#----------------------------------------------------------------------#

package Vues;
use strict;
use warnings;


# prototypes publics

# pour l'objet vues
sub new ($$);
sub declare ($$;$);
sub append ($$$);
sub commit ($$);
sub consolidate ($$);
sub convert ($$$$);

# autres fonctions
sub dump_vues($$$);                                                             # dumpvues_filter_line

# prototypes prives

# pour l'objet vues
sub _rechercheposition_dans_table($$);
sub initialize ($$);


#-------------------------------------------------------------------------------
# DESCRIPTION: Le constructeur
#-------------------------------------------------------------------------------
sub new ($$)
{
  # Attend en parametre le nom d'un fichier modele.
  my ($class, $filename) = @_;
  my $self = {};

  bless $self, $class;

  $self->initialize($filename ) ;

  return $self;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Methode d'initialisation
#-------------------------------------------------------------------------------
sub initialize ($$)
{
  my ($self, $lien_vue) = @_;
  $self->{'lien_vue'} = $lien_vue;

  my %hash = ();
  $self->{'arrays'} = \%hash;
  my %hash2 = ();
  $self->{'deltas'} = \%hash2;

  $self->{'option_iso_size'} = 0;
  $self->{'option_position'} = 1;

  $self->declare($lien_vue, 1);
}


# Activation d'une configuration pour que les vues crees aient la meme taille 
sub setOptionIsoSize($)
{
  my ($self) = @_;
  $self->{'option_iso_size'} = 1;
}

sub unsetOptionPosition($)
{
  my ($self) = @_;
  $self->{'option_position'} = 0;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Declaration d'un element a une vue
#-------------------------------------------------------------------------------
sub declare ($$;$)
{
  my ($self, $bufferName, $isMain) = @_;

  if (not defined $isMain)
  {
    $self->{'arrays'}->{$bufferName} = [];
  }
  $self->{'pos'}->{$bufferName} = [0];
  $self->{'deltas'}->{$bufferName} = '';
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Ajout d'un element a une vue
#-------------------------------------------------------------------------------
sub append ($$$)
{
  my ($self, $bufferName, $element) = @_;
  #push @{$self->{'arrays'}->{$bufferName}}, $element ;                         # traces_filter_line
  $self->{'deltas'}->{$bufferName} .= $element ;
}

sub commit_fast ($$)
{
  my ($self, $position) = @_;
  my $max_len_delta = 0;
  # config pour (certaines) vues de meme taille

  my $len; 
  my $arrayName;

  push @{$self->{'pos'}->{$self->{'lien_vue'}}}, $position;

  for $arrayName (keys ( %{$self->{'arrays'}} ) )
  {
    my $delta = $self->{'deltas'}->{$arrayName} ;
    push @{$self->{'arrays'}->{$arrayName}}, $delta ;

    $self->{'deltas'}->{$arrayName} = '';
  }

}

#-------------------------------------------------------------------------------
# DESCRIPTION: Indique la correspondance des positions entre les differentes vues.
# La parametre position indique la position dans la vue d'origine.
#-------------------------------------------------------------------------------
sub commit ($$)
{
  my ($self, $position) = @_;

  my $option_position  = $self->{'option_position'} ;

  if ( $option_position )
  {
    return commit_with_position($self, $position);
  }
  else
  {
    return commit_fast($self, $position);
  }
}

#-------------------------------------------------------------------------------
sub commit_with_position ($$)
{
  my ($self, $position) = @_;
  my $max_len_delta = 0;
  # config pour (certaines) vues de meme taille
  my $option_iso_size  = $self->{'option_iso_size'} ;

  my $len; 
  my $arrayName;
  if ( $option_iso_size )
  {
    for $arrayName (keys ( %{$self->{'arrays'}} ) )
    {
      $len = length ( $self->{'deltas'}->{$arrayName} ) ;
      if ($len > $max_len_delta)
      {
        $max_len_delta = $len ;
      }
    }
  }

  #print STDERR "Avant push\n" ;                                                                            # traces_filter_line
  #print STDERR $self->{'lien_vue'} . "\t" . join ( ',' , @{$self->{'pos'}->{$self->{'lien_vue'}}} ) ."\n"; # traces_filter_line
  push @{$self->{'pos'}->{$self->{'lien_vue'}}}, $position;
  #print STDERR $self->{'lien_vue'} . "\t" . join ( ',' , @{$self->{'pos'}->{$self->{'lien_vue'}}} ) ."\n"; # traces_filter_line
  #print STDERR "Apres push\n" ;                                                                            # traces_filter_line

  #my $sd = 

  #print STDERR "positions :" . $position  ;                                                                # traces_filter_line
  for $arrayName (keys ( %{$self->{'arrays'}} ) )
  {
    my $delta = $self->{'deltas'}->{$arrayName} ;
    if ( $option_iso_size )
    {
      $len = length ( $self->{'deltas'}->{$arrayName} ) ;
      my $blancs = ' ' x ( $max_len_delta - $len ) ;
      $delta .= $blancs;
    }
    push @{$self->{'arrays'}->{$arrayName}}, $delta ;

    my $prev_pos = @{$self->{'pos'}->{$arrayName}}[-1] ;
    my $cur_pos = $prev_pos + length($delta) ;
    push @{$self->{'pos'}->{$arrayName}}, $cur_pos;
    #print STDERR  "\t" . $cur_pos;                                             # traces_filter_line
    $self->{'deltas'}->{$arrayName} = '';
  }

# traces_filter_start

  #print STDERR $self->{'lien_vue'} . "\t" . join ( ',' , @{$self->{'pos'}->{$self->{'lien_vue'}}} ) ."\n";
 # pour tests et debug
  if (0)
  {
  for $arrayName (keys ( %{$self->{'arrays'}} ) )
  {
    #print STDERR "\nvue: " . $key . "\n" ;
    my $cur_pos = @{$self->{'pos'}->{$arrayName}}[-1] ;

    my $debug_test1 = $self->convert ($arrayName, 'text', $cur_pos );
    if ( $debug_test1 != $position )
    {
      print STDERR "( ! $arrayName($cur_pos) -> text $debug_test1 attendu: $position ! )" ;
    }

    my $debug_test2 = $self->convert ('text', $arrayName, $position );
    if ( $debug_test2 != $cur_pos )
    {
      print STDERR "( ! text($position) -> $arrayName $debug_test2 attendu: $cur_pos ! )" ;
    }
  }
  print STDERR  "\n" ;
  }

# traces_filter_end

}

#-------------------------------------------------------------------------------
# DESCRIPTION: Recuperation du buffer pour une vue donnee.
# Le parametre contient le nom de la vue que l'on souhaite recuperer.
#-------------------------------------------------------------------------------
sub consolidate ($$)
{
  my ($self, $bufferName) = @_;
  # Consolidation de la vue demandee.
  my $buffer = join ( '', @{$self->{'arrays'}->{$bufferName}} );
  return $buffer;
}


#-------------------------------------------------------------------------------
# FIXME:
# FIXME: fonction/methode privee
# DESCRIPTION: Recherche dans une table ordonnee, et strictement croissante.
# Retourne l'indice correspondant a une position egale ou precedente
#-------------------------------------------------------------------------------
sub _rechercheposition_dans_table($$)
{
  my ($ref_tab, $position) = @_;

  my $indice_moyen ;
  my ($index1, $index2) = ( 0 ,  scalar ( @{$ref_tab}) ) ;
  while (($index2-$index1)>1)
  {
    $indice_moyen = int ( ($index1+$index2) /2 );
    if ($position >= $ref_tab->[$indice_moyen] )
    {
      $index1 = $indice_moyen;
    }
    else
    {
      $index2 = $indice_moyen;
    }
  }
  $indice_moyen =$index1;
  #print STDERR "indice_moyen provisoire = " . $indice_moyen . "\n" ;         # traces_filter_line
  while ( $indice_moyen <=  scalar ( @{$ref_tab}) && $position > $ref_tab->[$indice_moyen] )
  {
    #print STDERR "Recherche $position; mais $indice_moyen " . "donne $ref_tab->[$indice_moyen] !\n" ; # traces_filter_line
    $indice_moyen += 1 ;
  }
  #print STDERR "indice_moyen definitif = " . $indice_moyen . "\n" ;          # traces_filter_line
  return $indice_moyen;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Convertit une position d'une vue, en une position d'une autre vue.
#-------------------------------------------------------------------------------
sub convert ($$$$)
{
  my ($self, $sourceBufferName, $destBufferName, $sourcePosition) = @_;

# traces_filter_start

#print STDERR "tailles : " . length ( @{$self->{'pos'}->{$sourceBufferName}} ) . ' et ' . length ( @{$self->{'pos'}->{$destBufferName}} ) . "\n";
#print STDERR $sourceBufferName . "\t" . join ( ',' , @{$self->{'pos'}->{$sourceBufferName}} ) ."\n";
#print STDERR $destBufferName . "\t" . join ( ',' , @{$self->{'pos'}->{$destBufferName}} ) ."\n";

# traces_filter_end

  my $source_Ref = $self->{'pos'}->{$sourceBufferName} ;
  my $indice = _rechercheposition_dans_table($source_Ref, $sourcePosition);
  my $destPosition = $self->{'pos'}->{$destBufferName}->[$indice] ;

  return $destPosition ;
}

# dumpvues_filter_start

# fonction de stockage des vues, pour debug
sub dump_vues($$$)
{
  my ($fichier, $vues, $options) = @_;

  my $output_dir  = AnalyseOptions::GetOutputDirectory ( $options, '--strip_dir' ) ||
                    AnalyseOptions::GetOutputDirectory ( $options, '--dir' ) ||
                    'output/met/' .             # traces_filter_line
                    './' ;

  my $base_filename = $fichier;
  $base_filename =~ s{.*[/\\]}{};

  my $dump_functions = $vues->{'dump_functions'};

  my $param_vues  =  $options->{'--strip'};
  my @liste_vues = keys ( %{$vues});
  if ( $param_vues ne '')
  {
    @liste_vues = split ( ',' , $param_vues );
  }
  print  STDERR "Repertoire de sortie des vues internes: " . $output_dir . "\n" ;
  foreach my $vueName ( @liste_vues )
  {
    my $vue = $vues->{$vueName};

    next if (not defined $vue);

    #print  STDERR "Repertoire de sortie des vues internes: " . $output_dir . "\n" ;
    my $outputFilename =  $output_dir .$base_filename.'.'.$vueName.'.txt' ;

    Options::rec_mkdir_forfile ($outputFilename);

    my $mode;
    if ( $vueName eq 'bin' )
    {
      $mode = ':raw' ;
    }
    else
    {
      $vue =~ s/\r/R/g ;

      if ( not defined $vues->{'encoding'} )
      {
        # Avant modification, on enregistrait systematiquement la vue au format utf-8:
        # on utilise raw, pour eviter la conversion crlf specifique a windows
        # on utilise utf8, pour eviter les erreurs d'ecriture pour des caracteres unicode non ascii
        $mode = ':raw:utf8';

        # As a consequence of the fact that ":raw" normally pops layers it usually only makes sense to
        # have it as the only or first element in a layer specification.  When used as the first element
        # it provides a known base on which to build
            # open($fh,":raw:utf8",
        # will construct a "binary" stream, but then enable UTF-8 translation.
      }
      else
      {
        # Maintenant, par defaut, on enregistre la vue avec l'encodage original du fichier,
        # dans le but de pouvoir comparer la vue au fichier d'origine.
        # sinon probleme sous windows (transforme 1 caractere accentue en 2 octets, donc faux probleme de diff)
        # print STDERR 'encoding : ' .  $vues->{'encoding'} . "\n" ;
        $mode = ':raw:encoding(' . $vues->{'encoding'} . ')' ;
      }
    }

    #open my $outputFile, ">utf8:", $outputFilename or die "cannot write to dump $!";
    open my $outputFile, '>' . $mode . ':', $outputFilename or die "cannot write to dump $!";

    if ( $outputFile )
    {
      #print STDERR "DD:" . $dump_functions . "\n" ;
      #print STDERR "DD:" . $dump_functions->{$vueName} . "\n" ;
      if ( defined $dump_functions and defined $dump_functions->{$vueName} )
      {
        $dump_functions->{$vueName}->($vue, $outputFile);
      }
      else
      {
        print $outputFile $vue;
      }
      close($outputFile);
    }
  }
}

# dumpvues_filter_end


sub getView($$;$$) {
  my $views = shift;
  my $default1 = shift;
  my $default2 = shift;
  my $default3 = shift;

  # Default view.
  my $r_code = undef;
  
  if (exists $views->{$default1}) {
    $r_code = \$views->{$default1};
  }

  if ( ! defined $r_code) {
    if ((defined $default2) && (exists $views->{$default2})) {
      $r_code = \$views->{$default2} ;
    }
    if ( ! defined $r_code) {
      if ((defined $default3) && (exists $views->{$default3})) {
        $r_code = \$views->{$default3} ;
      }
    }
  }

  # Check if another view is forced by parameter
  if ( exists $views->{'CountConfParam'} ) {
    my $CountParam = $views->{'CountConfParam'};
    if (exists $views->{$$CountParam}) {
      $r_code = \$views->{$$CountParam};
    } 
  }

  return $r_code;
}

1;
