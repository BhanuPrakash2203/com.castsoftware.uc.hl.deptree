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

use strict;
use warnings;

use Data::Dumper;
use Timeout;

package WinMemoryUsage;
# prototypes

my $win32_process_info =0;
#my $proc_processtable_loaded = 0;
#my $moduleIsInitialized=0;

sub init()
{
  eval {
    print STDERR "Chargement de   Win32::Process::Info ...\n" ;
    require Win32::Process::Info;
    $win32_process_info = 1;
  };
  if ($@)
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Echec du chergement du module: $@\n" ;
  }

}


sub PrintWinMemoryInfo();

sub PrintWinMemoryInfo()
{
  init();
  my $pid = $$; #getppid();
  print "pid:$pid\n";

  if ( $win32_process_info > 0)
  {
    my $pi = Win32::Process::Info->new ();
    my @process_information = $pi->GetProcInfo($pid);

    foreach my $info (@process_information) {
        foreach my $key (keys %{$info}) {
            if ($key eq "Name" or
                $key eq "UserModeTime" or
                $key eq "KernelModeTime")
            {
                my $value = ${$info}{$key};
                print "$key: => $value \n";
            }
            elsif ($key eq "WorkingSetSize")
            {
                my $value = ${$info}{$key}/1024;
                print "$key: => $value Mb\n";
            }
            elsif ($key eq "PeakWorkingSetSize")
            {
                my $value = ${$info}{$key}/1024;
                print "$key: => $value Mb peak\n";
            }
        }
    }
  }
}

1;
