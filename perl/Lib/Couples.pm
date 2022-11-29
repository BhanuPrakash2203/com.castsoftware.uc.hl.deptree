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
#----------------------------------------------------------------------#

package Couples;

# les modules importes
use strict;
use warnings;
use Traces;

# prototypes publics
sub new;
sub counter_add($$$);
sub counter_update($$$);
sub counter_dump($;$);  # traces_filter_line
sub counter_read_csv($);
sub counter_write_csv_tag_crash($$$); # dumpvues_filter_line
sub counter_write_csv($$$);           # dumpvues_filter_line
sub counter_get_values($);

# prototypes prives
sub return_error ($$);

my $debug = 0;  # traces_filter_line


# Creation d'une structure de donnees de couples.
# Constructeur
sub new
{
  my %h = ();
  bless \%h;
  return \%h;
}

my $RETOUR_ERREUR = 1;

#$RETOUR_ERREUR = Erreurs::COMPTEUR_STATUS_INTERFACE_COMPTEUR;

sub ClassSetErrorNumber($)
{
  my ($errorNumber) = @_;
  $RETOUR_ERREUR = $errorNumber;
}


sub counter_modify($$$)
{
  my ($out, $mnemo, $value) = @_;
  if(  (not defined $out) or  (not defined $mnemo) or (not defined $value)  )
  {
    my ($package, $filename, $line) = caller;
    my $location = join ( ':', ($package, $filename, $line) );
    ($package, $filename, $line) = caller(1);
    my $location2 = join ( ':', ($package, $filename, $line) );
    if (defined $mnemo)
    {
      print STDERR 'Can not modify counter ' . $mnemo .  "\n" ;
    }
    else
    {
      print STDERR "[counter_modify] Undefined counter\n" ;
    }
    print "lost counter at : $location";
    print "lost counter at : $location, at\n$location2";
    return $RETOUR_ERREUR;
  }
  $out->{$mnemo} = $value ;
  return 0;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Ajout d'un couple.
#-------------------------------------------------------------------------------
sub counter_add($$$)
{
  my ($out, $mnemo, $value) = @_;
  if(  (not defined $out) or  (not defined $mnemo) or (not defined $value)  )
  {
    my ($package, $filename, $line) = caller;
    my $location = join ( ':', ($package, $filename, $line) );
    ($package, $filename, $line) = caller(1);
    my $location2 = join ( ':', ($package, $filename, $line) );
    if (defined $mnemo)
    {
      print STDERR 'Counter ' . $mnemo .  " not taken into account\n" ;
    }
    else
    {
      print STDERR "Counter not taken into account\n" ;
    }
    Traces::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'comptage perdu', $location);
    Traces::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'comptage perdu', $location2);
    return $RETOUR_ERREUR;
  }
  if(  defined $out->{$mnemo} )
  {
    print STDERR "Mnemonic $mnemo already present\n" ;
    Traces::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_INTERFACE_COMPTEUR', 'comptage redondant', 
      "$mnemo ne peut etre positionne a $value, car il vaut deja $out->{$mnemo} !" ); 
    return $RETOUR_ERREUR;
  }
  $out->{$mnemo} = $value ;
  return 0;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Ajout d'un couple.
#-------------------------------------------------------------------------------
sub counter_update($$$)
{
  my ($out, $mnemo, $value) = @_;
  if(  (not defined $out) or  (not defined $mnemo) or (not defined $value)  )
  {
    my ($package, $filename, $line) = caller;
    my $location = join ( ':', ($package, $filename, $line) );
    ($package, $filename, $line) = caller(1);
    my $location2 = join ( ':', ($package, $filename, $line) );
    if (defined $mnemo)
    {
      print STDERR 'Counter ' . $mnemo .  " not taken into account\n" ;
    }
    else
    {
      print STDERR "Counter not taken into account\n" ;
    }
    Traces::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'comptage perdu', $location);
    Traces::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'comptage perdu', $location2);
    return $RETOUR_ERREUR;
  }
  if( ! defined $out->{$mnemo} ) {
    $out->{$mnemo} = $value;
  }
  else {
    $out->{$mnemo} += $value ;
  }
  return 0;
}


# traces_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: pour debug
#-------------------------------------------------------------------------------
sub counter_dump($;$)
{
  my ($out, $stream) = @_;
  my $sep = ':';
  $stream = $STDERR if not defined $stream;
  for my $k (sort keys(%{$out}))
  {
    print $stream 'result' . $sep . $k  . $sep . $out->{$k} . $sep  . $out->{'filename'} ."\n";
  }
}

# traces_filter_end

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


#-------------------------------------------------------------------------------
# DESCRIPTION: Lecture d'un fichier csv correspondant a un fichier source analyse
#-------------------------------------------------------------------------------
sub counter_read_csv($)
{
  my ($filename) = @_;
  my $sep = ':';
  open my $INPUT , '<' . $filename or  return undef;
                                       #die ": $! : $? : $filename" ;            # traces_filter_line

  my $couples = new Couples();
  while (<$INPUT>)
  {
    $_ =~ s/\s*$//;
    my ($ident, $value) = split(/:\s*/);
    counter_add($couples, $ident, $value);
    #print $OUTPUT 'result' . $sep . $k  . $sep . $out->{$k} . $sep  . "\n";     # traces_filter_line
  }

  close $INPUT;
  return $couples;
}


# dumpvues_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: Ajout de traces pour CRASH
#-------------------------------------------------------------------------------
sub counter_write_csv_tag_crash($$$)
{
  my ($out, $filename, $options) = @_;
  my $sep = ':';
  open my $OUTPUT , '>' . $filename or return return_error ("Cannot create file: $! : $? : $filename", 4);
  print $OUTPUT "Dat_CRASH:-1:Analysis aborted\n";
  close $OUTPUT;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Creation d'un fichier csv (par fichier source analyse)
# et creation d'un csv pour toutes les analyses
#-------------------------------------------------------------------------------
sub counter_write_csv($$$)
{
  my ($out, $filename, $options) = @_;

  my $sep = ':';

  open my $OUTPUT , '>' . $filename or return return_error ("Cannot create file: $! : $? : $filename", 4);
                                        #die ": $! : $? : $filename" ;           # traces_filter_line
  for my $k (sort keys(%{$out}))
  {
    #print $OUTPUT 'result' . $sep . $k  . $sep . $out->{$k} . $sep  . "\n";     # traces_filter_line
    print $OUTPUT  $k  . $sep . $out->{$k} .  "\n";
  }

  close $OUTPUT;

  # tous les comptages de tous les fichiers analyses dans le meme fichier
  if (exists $options->{'--concatene-tous-les-comptages'})
  {
    my $filename_tous_comptages = $options->{'--concatene-tous-les-comptages'};

    open my $OUTPUT , '>>' . $filename_tous_comptages or return return_error ("Cannot create file: $! : $? : $filename_tous_comptages", 4);

    my $filename_clean = $filename;
    $filename_clean =~ s{^\.//\./}{./};
    $filename_clean =~ s{\.comptages\.txt$}{};

    print $OUTPUT "### File : $filename_clean ###\n";

    for my $k (sort keys(%{$out}))
    {
      my $line;
      if ($k eq 'Dat_AnalysisDate')
      {   # pas de date qui change ...
        $line = $k  . $sep  .  "\n";
      }
      else
      {
        $line = $k  . $sep . $out->{$k} .  "\n";
      }
      print $OUTPUT $line;
    }

    print $OUTPUT "### END ###\n";

    close $OUTPUT;
  }

  return 0;
}

sub clone($) {
  my $old = shift;
  my $counters = new Couples;
  %$counters = %$old;
  return $counters;
}

# dumpvues_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: Retourne une (references de) hash table, a partir de l'objet courant.
#-------------------------------------------------------------------------------
sub counter_get_values($)
{
  my ($out) = @_;
  return $out ;
}


1;

