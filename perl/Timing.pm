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

package Timing;

#use strict;
#FIXME: Can't use string ("Timing") as a HASH ref while "strict refs" in use at ../Src/V1/Timing.pm line 71.

use warnings;

use Time::HiRes qw( gettimeofday tv_interval );
use Options;

#my $TimingStream = *STDERR;

open my $TimingStream, ">&STDERR";

sub p($)
{
  my ($message) = @_;
  print $TimingStream $message;

}

# methode statique d'initialisation de la classe
sub classInit($$$)
{
  my ($class, $selected_timing_names, $TimingFilename) = @_ ;
  my %hash = ();
  $class->{'selected_timing_names'} = \%hash ;
  if ( defined $selected_timing_names) {
    if ( $selected_timing_names ne '') {
      my @array = ( split ( ',' , $selected_timing_names ) );
      foreach my $option ( @array)
      {
        $class->{'selected_timing_names'}->{$option} = 1 ;
      }
    }
    else {
        $class->{'selected_timing_names'}->{'All'} = 1 ;
    }
  }
  Options::rec_mkdir_forfile($TimingFilename);
  open $TimingStream, '>:raw',$TimingFilename or die "Ne peut creer le fichier $TimingFilename $! $@ $?\n";
}

sub classDestroy($)
{
  my ($class) = @_;
  print STDERR "Close timing stream\n";
  #close ($TimingStream);
  $TimingStream = *STDERR;
}

# methode statique de test d'option de timing
sub isSelectedTiming($$)
{
  my ($class, $timing) = @_;
  return $class->{'selected_timing_names'}->{$timing};
}

# Creation d'un chronometre de mesure de performance
# parametres:
# cComment: premiere identification de timing
# actif: un booleen indiquant s'il faut utiliser le timer
sub new ($$;$)
{
    my ($class, $Comment, $actif) = @_;
    my $self = {};

    bless $self, $class;

    $self->{'enable'} = $actif ;
    $self->initialize($Comment ) ;

    if ( ( defined $self->{'enable'} ) and 
       (defined $class->{'superTimer'} ) )
    {
      $class->{'superTimer'}->markTimeAndPrint( 'Timing::start=' . $Comment);
    }

    return $self;
}

sub initialize ($$)
{
  my ($self, $Comment) = @_;
  return if ( not defined $self->{'enable'} );
  $self->{'index'} = 0;
  $self->{'times'} = [];
  $self->{'comments'} = [];
  $self->{'name'} = $Comment || ''  ;
  $self->{'name'} .= ' '  ;
  $self->markTime('--init--');
}


# Cette fonction marque le moment present
# Elle doit etre rapide pour des mesures precises
sub markTime ($$)
{
  my ($self, $Comment) = @_;
  return if ( not defined $self->{'enable'} );
  if ( ! defined $Comment) {
    $Comment = "";
  }
  my $Current_time = [gettimeofday];
  my $index = $self->{'index'} ;
  $self->{'times'}->[$index] = $Current_time;
  $self->{'comments'}->[$index] = $Comment;
  $self->{'index'} ++;
  return $Current_time;
}

# Cette fonction marque le moment present
# Elle doit etre rapide pour des mesures precises
sub markTimeAndPrint ($$)
{
  my ($self, $Comment) = @_;
  return if ( not defined $self->{'enable'} );
  my $LastTime = $self->markTime($Comment);;
  my $StartTime = $self->{'times'}->[0];
  my $ElapsedFromStart = tv_interval ( $StartTime, $LastTime);
  my $PreviousTime = $self->{'times'}->[$self->{'index'}-2];
  my $ElapsedFromPrevious = tv_interval ( $PreviousTime, $LastTime);
  p( "Timing:" .  $self->{'name'} . $Comment . "\t:" . $ElapsedFromStart .
                                                         "\tdelta:" . $ElapsedFromPrevious . " secondes \n" );
#print "  --> $Comment : duration : $ElapsedFromPrevious seconds !!\n";
}

# Cette fonction marque le moment present
# Elle doit etre rapide pour des mesures precises
sub printFromStart ($$)
{
  my ($self, $Comment) = @_;
  return if ( not defined $self->{'enable'} );
  my $LastTime = $self->markTime($Comment);;
  my $StartTime = $self->{'times'}->[0];
  my $Elapsed = tv_interval ( $StartTime, $LastTime);
  p(  "Timing:" .  $self->{'name'} . $Comment . "\t:" . $Elapsed . " secondes \n" );
}

# Cette fonction marque le moment present
# Elle doit etre rapide pour des mesures precises
sub printFromLast ($$)
{
  my ($self, $Comment) = @_;
  return if ( not defined $self->{'enable'} );
  my $LastTime = $self->markTime($Comment);;
  my $PreviousTime = $self->{'times'}->[$self->{'index'}-2];
  my $Elapsed = tv_interval ( $PreviousTime, $LastTime);
  p( "Timing:" .  $self->{'name'} . $Comment . "\t:" . $Elapsed . " secondes \n" );
}


# Affiche l'ensemble des temps mesures par cet objet.
# parametres:
# $Comment: l'identification de dump (deuxieme identification de timing)
sub dump ($$)
{
  my ($self, $Comment) = @_;
  return if ( not defined $self->{'enable'} );

  my $lastNumber = $self->{'index'} ;
  for (my $index=0; $index < $lastNumber ; $index++)
  {
    my $Elapsed ;
    if ($index > 0 )
    {
      $Elapsed = sprintf ( '%.6f', tv_interval ( $self->{'times'}->[$index-1], $self->{'times'}->[$index]) );
    } else {
      $Elapsed = ' ' x 8;
    }
    my $ElapsedFromStart =  sprintf ( '%.6f',
          tv_interval ( $self->{'times'}->[0], $self->{'times'}->[$index]) );

    p ( "" .  $self->{'name'} . $Comment .
                             "\t:" . $ElapsedFromStart .
                             "\t:" . $Elapsed .
                             "\t:" . $index .
                             "\t:" . $self->{'comments'}->[$index] . "\n" );
#,
                             #$ElapsedFromStart ,
                             #$Elapsed   );
  }


}

# methode indiquant la fin d'utilisation du timer
sub finish ($)
{
  my ($self) = @_;
  return if ( not defined $self->{'enable'} );

  #my $class=ref($self);
  my $class =  __PACKAGE__ ;
  if (defined $class->{'superTimer'} )
  {
    $class->{'superTimer'}->markTimeAndPrint( 'Timing::finish=' . $self->{'name'} );
  }
}

sub DESTROY ($)
{
  my ($self) = @_;
  #print STDERR "DESTROY Timing object!\n";
  $self->finish();
}


# methode statique de redemarrage du supertimer
sub superTimerRestart ($$$)
{
  my ($class, $Comment, $actif) = @_;
  $class->{'superTimer'} = new Timing('superTimer:' . $Comment , $actif);
}

# methode statique de dump du supertimer
sub superTimerDump ($)
{
  my ($class) = @_;
  $class->{'superTimer'}->finish();
  $class->{'superTimer'}->dump('pour le fichier');
}


1;
