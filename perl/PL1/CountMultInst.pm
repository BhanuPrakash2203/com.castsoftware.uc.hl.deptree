# Composant: Plugin

package PL1::CountMultInst;
# les modules importes
use strict;
use warnings;
use Erreurs;

# prototypes publics
sub CountMultInst($$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des lignes comportant plusieurs instructions.
#-------------------------------------------------------------------------------

sub CountMultInst($$$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $mnemo_MultipleStatementsOnSameLine = Ident::Alias_MultipleStatementsOnSameLine();
  my $status = 0;
  my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # Erreurs::LogInternalTraces

  my $nbr_MultipleStatementsOnSameLine= 0;
#  my $mnemo_compatibilite_MultInst = Ident::Alias_MultipleStatementsOnSameLine(); # compatibilite pour module calcul #bt_filter_line # Obsolete

  my $code = $vue->{'code'};

  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, $mnemo_MultipleStatementsOnSameLine, Erreurs::COMPTEUR_ERREUR_VALUE );
#    $status |= Couples::counter_add($compteurs, $mnemo_compatibilite_MultInst, Erreurs::COMPTEUR_ERREUR_VALUE ); # compatibilite pour module calcul #bt_filter_line # Obsolete
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @LINES = split (/\n/, $code);
  my $ligne;
  my $line_number=0;
  foreach $ligne ( @LINES) {

    my $match = $ligne; # Erreurs::LogInternalTraces
    my $line_number++;  # Erreurs::LogInternalTraces
    # Suppression des parentheses. Remplace par un espace pour eviter de "coller" 2 tokens
    while ( $ligne =~ s/\([^\(\)]*\)/ /sg ) {}

    # Ne pas aggrafer les 'else if'
    $ligne =~ s/\belse\s+if\b/if/ig;

    # Ne pas aggrafer les 'if ... then'
    $ligne =~ s/\bif\b(.*)*?\bthen\b/if/ig;

    # Remplacement des structures de controle qui ne se terminent pas par des ";", par des ';'
    $ligne =~ s/\b(if|else|then)\b/;/ig ;

    # nombre de ';' sur la ligne
    my $nb = () = $ligne =~ /;/g ;

    if ($nb > 1) {
      # il y a plus d'un ';' sur la ligne
      $nbr_MultipleStatementsOnSameLine++;
      Erreurs::LogInternalTraces('TRACE', $fichier, $line_number, $mnemo_MultipleStatementsOnSameLine, $match) if ($b_TraceDetect); # Erreurs::LogInternalTraces
    }
  }

  $status |= Couples::counter_add($compteurs, $mnemo_MultipleStatementsOnSameLine, $nbr_MultipleStatementsOnSameLine);
#  $status |= Couples::counter_add($compteurs, $mnemo_compatibilite_MultInst, $nbr_MultipleStatementsOnSameLine); # compatibilite pour module calcul #bt_filter_line # Obsolete

  return $status;
}


1;
