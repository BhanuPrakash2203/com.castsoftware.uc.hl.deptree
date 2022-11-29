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

# Composant: Plugin

package CountSuspiciousComments;

use strict;
use warnings;

# les modules importes
use Erreurs;
use Couples;
use charnames ':full';

# prototypes publics
sub CountSuspiciousComments($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des commentaires suspects
#-------------------------------------------------------------------------------

sub _CountSuspiciousComments($$$$) {
  my ($fichier, $vue, $compteurs, $re) = @_ ;

  my $mnemo_SuspiciousComments = Ident::Alias_SuspiciousComments();
  my $status = 0;
  my $nbr_SuspiciousComments=0;

  my %Hpattern = () ;

  if ( ! defined $vue->{'comment'} ) {
    $status |= Couples::counter_add($compteurs, $mnemo_SuspiciousComments, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  # lc pour convertir tous les caracteres en minuscule pour attraper aussi bien 'a faire' que 'A faire' ou 'A FAIRE'
  my @TLines = split(/\n/, lc ($vue->{'comment'}));

  foreach my $line (@TLines) {

    # FIXME: que signifie le commentaire suivant:
    # Suppression des marqueurs de commentaires dans la vue "commentaire".

    #NB: Astuce: On tente de cacher le composition des caracteres, afin d'eviter leur alteration par stunnix
    #my $x00e0 = chr ( 0x00e0 );
    #my $x00e9 = chr ( 0x00e9 );
    #my $x00e0 = pack("U0C*", 0xc3, 0xa0); # U+00E0 LATIN SMALL LETTER A WITH GRAVE
    #my $x00e9 = pack("U0C*", 0xc3 , 0xa9); # U+00E9 LATIN SMALL LETTER E WITH ACUTE
    

    #my $pattern =  '([\!\?][\!\?]+|\b[\x{' . '00e0}a]\s+(?:v[\x{' . '00e9}e]rifier|faire|voir|revoir)|\b(?:todo|fixme|tbc|tbd|attention)\b';

    #my $re =  qr/([\!\?][\!\?]+|\b(?:$x00e0|a)\s+(?:v(?:$x00e9|e)rifier|faire|voir|revoir)|\b(?:todo|fixme|tbc|tbd|attention)\b)/;
    #my $re =  qr/$pattern/;
    #if ( $line =~ /([\!\?][\!\?]+|\b[\x{00e0}a]\s+(?:v[\x{00e9}e]rifier|faire|voir|revoir)|\b(?:todo|fixme|tbc|tbd|attention)\b)/) 
    #if ( $line =~ /([\!\?][\!\?]+|\b[\N{LATIN SMALL LETTER A WITH GRAVE}a]\s+(?:v[\N{LATIN SMALL LETTER E WITH ACUTE}e]rifier|faire|voir|revoir)|\b(?:todo|fixme|tbc|tbd|attention)\b)/) 
    if ( $line =~ $re) 
    {

      $nbr_SuspiciousComments++;

      if (defined $1) {                                                         # Erreurs::LogInternalTraces
        if ( ! exists $Hpattern{$1} ) { $Hpattern{$1} = 1; }                    # Erreurs::LogInternalTraces
        else { $Hpattern{$1} += 1; }                                           # Erreurs::LogInternalTraces
      }                                                                         # Erreurs::LogInternalTraces

    }
  }

  my @wordlist = keys %Hpattern;                                                # Erreurs::LogInternalTraces
  if (scalar @wordlist > 0) {                                                   # Erreurs::LogInternalTraces
    foreach my $word (@wordlist) {                                              # Erreurs::LogInternalTraces
      my $nb_occurrences = $Hpattern{$word};                                    # Erreurs::LogInternalTraces
      my $msg = "--> $nb_occurrences occurrences" ;                             # Erreurs::LogInternalTraces
      my $mnemo = $mnemo_SuspiciousComments;                                    # Erreurs::LogInternalTraces
      Erreurs::LogInternalTraces('TRACE', $fichier, 1, $mnemo, $word, $msg);    # Erreurs::LogInternalTraces
    }                                                                           # Erreurs::LogInternalTraces
  }                                                                             # Erreurs::LogInternalTraces

  $status |= Couples::counter_add($compteurs, $mnemo_SuspiciousComments, $nbr_SuspiciousComments);

  return $status;
}

my $x00e0 = pack("U0C*", 0xc3, 0xa0); # U+00E0 LATIN SMALL LETTER A WITH GRAVE
my $x00e9 = pack("U0C*", 0xc3 , 0xa9); # U+00E9 LATIN SMALL LETTER E WITH ACUTE

sub CountSuspiciousComments($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  
  my $re =  qr/([\!\?][\!\?]+|\b(?:$x00e0|a)\s+(?:v(?:$x00e9|e)rifier|faire|voir|revoir)|\b(?:todo|fixme|tbc|tbd|attention)\b)/;
  
  return _CountSuspiciousComments($fichier, $vue, $compteurs, $re);
}

sub CountSuspiciousCommentsInternational($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  
  my $re =  qr/([\!\?][\!\?]+|\b(?:$x00e0|a)\s+(?:v(?:$x00e9|e)rifier|faire|voir|revoir)|(to\s+be\s+(?:verified|done))|\b(?:todo|fixme|tbc|tbd|attention|warning)\b)/;
  
  return _CountSuspiciousComments($fichier, $vue, $compteurs, $re);
}

1;
