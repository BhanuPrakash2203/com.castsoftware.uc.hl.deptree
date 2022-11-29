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

# Composant: Plugin

package CountMissingDefaults;

# les modules importes
use strict;
use warnings;
use Erreurs;
use Couples;

# prototypes publics
sub CountMissingDefaults($$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des defaults manquants.
# FIXME: Anomalie 228
#-------------------------------------------------------------------------------
sub CountMissingDefaults($$$$)
{
  my ($fichier, $vue, $compteurs, $options) = @_ ;
  my $status = 0;
  my $mnemo_MissingDefaults = Ident::Alias_MissingDefaults();

  my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
  my $trace_detect = '' if ($b_TraceDetect);                         # traces_filter_line
  my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
  $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
  my $debug = 0;                                                     # traces_filter_line

  if ( ! ((defined $compteurs->{Ident::Alias_Switch()}) && (defined $compteurs->{Ident::Alias_Default()} ))) {
    $status |= Couples::counter_add($compteurs, $mnemo_MissingDefaults, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nbr_MissingDefaults = $compteurs->{Ident::Alias_Switch()} - $compteurs->{Ident::Alias_Default()} ;

  $trace_detect .= "$base_filename:1:Nbr_Switch = $compteurs->{Ident::Alias_Switch()}\n" if ($b_TraceDetect);   # traces_filter_line
  $trace_detect .= "$base_filename:1:Nbr_Default = $compteurs->{Ident::Alias_Default()}\n" if ($b_TraceDetect); # traces_filter_line
  $trace_detect .= "$base_filename:1:$mnemo_MissingDefaults = $nbr_MissingDefaults\n" if ($b_TraceDetect);             # traces_filter_line

  if ($nbr_MissingDefaults < 0) {
    Erreurs::LogInternalTraces("ERROR", $fichier, 1, $mnemo_MissingDefaults, "erreur d'appariement switch..default");
    $nbr_MissingDefaults = Erreurs::COMPTEUR_ERREUR_VALUE;
  }

  print STDERR "$mnemo_MissingDefaults = $nbr_MissingDefaults\n" if ($debug);                               # traces_filter_line
  TraceDetect::DumpTraceDetect($fichier, $mnemo_MissingDefaults, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
  $status |= Couples::counter_add($compteurs, $mnemo_MissingDefaults, $nbr_MissingDefaults);

  return $status;
}

1;
