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
# Module pour tuer le process en cas de demande d'abandon.
#----------------------------------------------------------------------#

package ProcessManager;

# les modules importes
use strict;
use warnings;
use POSIX ":sys_wait_h";
use POSIX;
use Erreurs;
use AnalyseOptions;

my $debug=1;

# Recupere le code d'erreur
sub Get_System_Error_Value($)
{
  my ($errorCode)=@_;
  my $message = $errorCode >> 8;
  return $message;
}

# Gestion des codes d'erreurs etendus
sub PropageCodeErreurEtendu($)
{
  my ($status) = @_;
  if (($status & 0xFFFFFF00) != 0)
  {
    $status |= Erreurs::COMPTEUR_STATUS_ERREUR_ETENDUE;
    print STDERR "status etendu\n" if ($debug);
  }
  return $status;
}


sub ProcessParent($$)
{
  my ( $pid_enfant, $options) =@_;
  my $status = 0;
  my $fichier = 'no filename' ;
  
  my $attente = 1;
  my $DialogDirectory = AnalyseOptions::GetDialogDirectory($options);

  if (1)
  {
    while ($attente)
    {
      my $cnt = kill (0, $pid_enfant);
      my $waitpidStatus = POSIX::waitpid($pid_enfant, &POSIX::WNOHANG);
      print STDERR "\nwaitpitSattus  = " . $waitpidStatus . "\n";
      #if (($waitpidStatus == 0) || ($waitpidStatus == -1))  
      if ($waitpidStatus == 0) 
      {
        $cnt = 1; # Processus en cours
      }
      else
      {
        $cnt = 0; # Processus termine
      }

      my $stop = -f $DialogDirectory . 'stop.stop' ;
      #print STDERR "\n\nprocessus actif = " . $cnt . "  stop = " . $stop . "\n\n";
      if ( defined $stop ) 
      {
        kill (1, $pid_enfant);
        #sleep(1);
        #die "\n\nArret utilisateur demande\n\n" ;
        print STDERR "\n\nArret utilisateur demande\n\n" ;
      }
      if ( $cnt == 0)
      { 
        $attente = 0;
      }
      else
      {
        sleep (1);
      }
    }
    
  }
  else
    {
        # processus parent
        print STDERR "pid_enfant:$pid_enfant\n" if ($debug);                    # traces_filter_line
        print STDERR "Ici c'est le processus parent.\n" if ($debug);            # traces_filter_line

        my $waitpidSatus = 0;
        do
        {
            my $localStatus;
            if ($^O eq 'MSWin32')
            {
                $waitpidSatus = POSIX::waitpid($pid_enfant, &POSIX::WNOHANG);
                if (($waitpidSatus != 0) && ($waitpidSatus != -1))  # ok pour activestate
                {
                    print STDERR "waitpidSatus:$waitpidSatus\n" if ($debug);                           # traces_filter_line
                    $localStatus = Get_System_Error_Value($?);
                    print STDERR "localStatus:$localStatus\n" if ($debug);                             # traces_filter_line
                    $status |= $localStatus;

                    if ($status == Erreurs::COMPTEUR_STATUS_CRASH_ANALYSEUR)                           # traces_filter_line
                    {                                                                                  # traces_filter_line
                      Erreurs::LogInternalTraces ('erreur', undef, undef, '', '', 'Crash analyseur!'); # traces_filter_line
                      print STDERR "$fichier:1:Crash analyseur !\n" if ($debug);                       # traces_filter_line
                    }                                                                                  # traces_filter_line
                }
            }
            else
            {
                # autres cas std : unix et clones
                $waitpidSatus = waitpid($pid_enfant, 0);
                if ($waitpidSatus > 0)
                {
                    print STDERR "waitpidSatus:$waitpidSatus\n" if ($debug);                           # traces_filter_line
                    $localStatus = Get_System_Error_Value($?);
                    print STDERR "localStatus:$localStatus\n" if ($debug);                             # traces_filter_line
                    $status |= $localStatus;
                    if ($status == Erreurs::COMPTEUR_STATUS_CRASH_ANALYSEUR)                           # traces_filter_line
                    {                                                                                  # traces_filter_line
                      Erreurs::LogInternalTraces ('erreur', undef, undef, '', '', 'Crash analyseur!'); # traces_filter_line
                      print STDERR "$fichier:1:Crash analyseur !\n" if ($debug);                       # traces_filter_line
                    }                                                                                  # traces_filter_line
                }
            }
        } until ($waitpidSatus == -1);
        print STDERR "Le processus parent est termine.\n" if ($debug);          # traces_filter_line
    }
  return $status;
}

sub ProcessEnfant($$)
{
  my ($callback, $context) = @_;
  my $fichier = 'no filename' ;
  my $status = 0;
      # processus enfant
      print STDERR "Ici c'est le processus enfant.\n" if ($debug);              # traces_filter_line
      Timing->superTimerRestart ($fichier, Timing->isSelectedTiming ('Super')); # timing_filter_line
      $status |= $callback->($context);
      print STDERR "Ici fin du processus enfant.\n" if ($debug);                # traces_filter_line
      $status |= PropageCodeErreurEtendu ($status);
      Timing->superTimerDump ();                                                # timing_filter_line
      exit ($status);
  return $status;
}

# DESCRIPTION:
# Lancement de l'analyse sur un fichier source avec un processus 'fork'
sub ProcessCallbackWaitingStopFileInternal($$$)
{
    my ( $options,  $callback, $context) = @_ ;
    my $debug = defined($options->{'--debugfork'});                              # traces_filter_line
    my $status = 0;

    my $pid_enfant = POSIX::fork();

    if (not defined $pid_enfant )
    # D'apres man perlfunc, retourne  "undef" if the fork is unsuccessful
    {
      $status |= Erreurs::COMPTEUR_STATUS_CRASH_ANALYSEUR;
      Erreurs::LogInternalTraces ('erreur', undef, undef, '', '', 'fork impossible'); # traces_filter_line
      # FIXME: a mettre en conformite avec l'eventuelle strategie de gestion des erreurs.
    }
    elsif ($pid_enfant != 0)
    {
      $status |= ProcessParent( $pid_enfant, $options); # Le pere
    }
    else
    {
      $status |= ProcessEnfant( $callback, $context); # Le fils
    }
    $status |= PropageCodeErreurEtendu($status);
    return $status;
}


# DESCRIPTION: Lancement de l'analyse sur un fichier source
# avec detection de crash de l'analyseur sur option
sub ProcessCallbackWaitingStopFile($$$$)
#sub AnalyseFile($$$$;$$)
{
  my ( $options,  $callback, $context, $flag) = @_ ;
  my $status = 0;
  if ( not $flag )
  {
    # analyse sans surveillance du fichier stop
    $status |= $callback->( $context);
  }
  else
  {
    # analyse avec surveillance du fichier stop
    $status |= ProcessCallbackWaitingStopFileInternal( $options,  $callback, $context);
  }
  return $status;
}



1;
