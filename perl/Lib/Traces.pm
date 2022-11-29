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
# DESCRIPTION: Composant de traces pour Lib
#----------------------------------------------------------------------#

package Traces;

# les modules importes

use strict;
use warnings;
use IO::Handle;   # traces_filter_line


# prototypes


# variables privees
my $_debugLevel = 0;

my $FD_Log = undef ;
my $current_filename = '';
my $callback = undef;

sub SetCallback($)
{
  my ( $LogInternalTraces)=@_;
  $callback = $LogInternalTraces;
}

sub LogInternalTraces ($$$$$;$)
{
  my ($type, $filename, $line, $comptage, $pattern, $free) = @_ ;
  if (defined $callback)
  {
    return $callback->(@_);
  }

  if (defined $FD_Log) {

    if (not defined $free) {
      $free = '';
    }

    if (not defined $filename) {
      $filename = $current_filename;
    }

    if (not defined $line) {
      $line = 1;
    }

    # Suppression des blancs de fin de ligne dans la pattern.
    $pattern =~ s/\s*\n?\z//;

    print $FD_Log "$filename:$line:[$comptage]:**** $type ****: $pattern : $free\n";
  }
}

sub debug($$)
{
  my (undef, $message) = @_;
  if ( $_debugLevel gt 0)
  {
    print STDERR 'debug: ' . $message . "\n" ;
  }

}



1;
