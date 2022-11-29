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
package Timeout;


sub DontCatchTimeout()
{
    die ($@) if $@ eq "alarm\n";   # propagate timeout errors
}

sub TryCatchTimeout($$$$$)
{
  my ($try_routine, $try_arguments, $catch_routine, $catch_arguments, $timeout) = @_;
  my ($val1, $val2);
    eval {
      local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
      alarm $timeout;
      $val1 = $try_routine->(@{$try_arguments});
      alarm 0;
    };
    alarm 0; # dans le cas ou le timeout risque d'etre leve apres une autre exception
    if ($@) {
      die ($@) unless $@ eq "alarm\n";   # propagate unexpected errors
      # timed out
      $val2 = $catch_routine->(@{$catch_arguments});
    }
    else {
      # didn't
    }
  return ($val1, $val2);
}
    


1;

