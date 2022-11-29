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
# Description: Module d'analyse de la consommation memoire

package Memory;
use strict;
use warnings;
use Timeout;

my $bsd_resource_loaded =0;
my $proc_processtable_loaded = 0;
my $moduleIsInitialized=0;

sub init()
{
  eval {
    print STDERR "Chargement de   BSD::Resource ...\n" ;
    require BSD::Resource;
    $bsd_resource_loaded = 1;
  };
  if ($@)
  {
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Echec du chergement du module: $@\n" ;
  }

  eval {
    print STDERR "Chargement de  Proc::ProcessTable ...\n" ;
    require Proc::ProcessTable;
    $proc_processtable_loaded = 1;
  };
  if ($@)
  {      
    Timeout::DontCatchTimeout();   # propagate timeout errors
    print STDERR "Echec du chergement du module: $@ \n" ;
  }
  $moduleIsInitialized =1;
}


# FIXME: a appeler explicitement sur option.
# FIXME: init(); # initialisation du module

sub new($$)
{
  my ($class, $name) = @_;
  my $self = {};
  #my $self = \%h_self ;
  bless $self, $class ;
  $self->{'bytes_used'} = 0;
  $self->{'percent_used'} = 0;
  $self->{'name'} = $name;
  $self->memusage_proc_processtable('--init--');
  return $self;
}

sub memusage($$)
{
  my ($self, $display) = @_;
  #print STDERR $self . "\n" ;
  #print STDERR $self->memusage_proc_processtable . "\n" ;
  my $ref_mem = $self->memusage_proc_processtable() ;
  if ( defined $ref_mem )
  {
    my @mem = @{$ref_mem} ;
    print STDERR $self->{'name'} . ':Memory: ' . $display . ':' . ($mem[0]/1024/1024)  . " Mo\t". $mem[1] . "%" .
          "\tdelta " . ( ($mem[0]-$self->{'bytes_used'} )/1024) . " Kbytes \t". ($mem[1]-  $self->{'percent_used'})  . " points\n" ;
    $self->{'bytes_used'} = $mem[0];
    $self->{'percent_used'} = $mem[1];
  }
  else
  {
    #print STDERR 'Memory: ' . 'not available ' . "\n" ;
    ;
  }
}

sub memory_bsd_resource($)
{
  my ($self) = @_;
  return undef unless  ($bsd_resource_loaded == 1);
  print join("\n", &memusage), "\n";
  if (0)
  {
    my @r = BSD::Resource::getrusage();

                #  2      maxrss          maximum shared memory or current resident set
                #  3      ixrss           integral shared memory
                #  4      idrss           integral or current unshared data
                #  5      isrss           integral or current unshared stack

    if (0)
    {
      #print STDERR "Entering $DB::sub, maxrss = $r[2]\n" if $DB::sub =~ /SVN::Web/;
      print STDERR " BSD::Resource::getrusage , " . join ( ' , ' , @r ) . "\n" ;
      print STDERR "Entering ,\t maxrss = $r[2] " . 
                             "\t ixrss = $r[3] " . 
                             "\t idrss = $r[4] " . 
                             "\t isrss = $r[5] " . 
                  "\n" ;
    }

    # sous debian
    print STDERR "Entering ,\t minflt = $r[6] \n" ; 
  }
}

#   memusage subroutine
#
#   usage: memusage [processid]
#
#   this subroutine takes only one parameter, the process id for 
#   which memory usage information is to be returned.  If 
#   undefined, the current process id is assumed.
#
#   Returns array of two values, raw process memory size and 
#   percentage memory utilisation, in this order.  Returns 
#   undefined if these values cannot be determined.

sub memusage_proc_processtable($)
{
  my ($self) = @_;
  unless  ($proc_processtable_loaded == 1)
  {
    #print STDERR "Proc::ProcessTable; non disponible \n" ;
    return undef ;
  }
  my @results =();
  #my $pid = (defined($_[0])) ? $_[0] : $$;
  my $pid =  $$;
  my $proc = Proc::ProcessTable->new;
  my %fields = map { $_ => 1 } $proc->fields;
  if (not  exists $fields{'pid'})
  {
    print STDERR "Proc::ProcessTable; no such PID \n" ;
    return undef ;
  }
  foreach my $pr (@{$proc->table}) {
    #print STDERR 'Proc::ProcessTable; PID: ' . $pr->pid  . ' ... ' .  $pid . "\n" ;
        if ($pr->pid eq $pid) {
    #print STDERR "Proc::ProcessTable; PID: $pid \n" ;
            push (@results, $pr->size) if exists $fields{'size'};
            push (@results, $pr->pctmem) if exists $fields{'pctmem'};
        };
  };
  #print STDERR "memusage_proc_processtable : retour nominal\n" ;
  return \@results;
}

return 1;

