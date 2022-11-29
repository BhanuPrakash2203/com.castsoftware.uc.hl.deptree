
package PlSql::CountBody;
use strict;
use warnings;

use Erreurs;

#  Comptage du nombre de lignes non vide du buffer
sub count_nonempty_lines($)
{
    my ($sca) = @_;
    my @x = $sca =~ /\S[^\n]*\n/smgo;
    my $n = @x;
    return $n;
}

#  Comptage du nombre de lignes du buffer
sub count_lines($)
{
    my ($sca) = @_;
    my $n = () = $sca =~ /\n/smgo;
    return $n;
}


sub CountBody($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $status = 0;
  my $body= $vue->{'bloc_body'} ;
  my $spec= $vue->{'bloc_hors_bloc_body'} ;

  my $mnemo_LinesInSpec = Ident::Alias_LinesInSpec(); # Comptage G90b
  my $mnemo_LinesOfCodeInSpec = Ident::Alias_LinesOfCodeInSpec(); # Comptage G91b
  if ( ! defined $spec)
  {
    $status |= Couples::counter_add($compteurs, $mnemo_LinesInSpec, Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, $mnemo_LinesOfCodeInSpec, Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  else
  {
    my $nbr_LinesInSpec = 0;
    my $nbr_LinesOfCodeInSpec = 0;
    $nbr_LinesInSpec = count_lines( $spec);
    $nbr_LinesOfCodeInSpec = count_nonempty_lines( $spec);
    $status |= Couples::counter_add($compteurs, $mnemo_LinesInSpec, $nbr_LinesInSpec);
    $status |= Couples::counter_add($compteurs, $mnemo_LinesOfCodeInSpec, $nbr_LinesOfCodeInSpec);
  }
  
  my $mnemo_LinesInBody = Ident::Alias_LinesInBody(); # Comptage G90c
  my $mnemo_LinesOfCodeInBody = Ident::Alias_LinesOfCodeInBody(); # Comptage G91c
  if ( ! defined $body)
  {
    $status |= Couples::counter_add($compteurs, $mnemo_LinesInBody, Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, $mnemo_LinesOfCodeInBody, Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  else
  {
    my $nbr_LinesInBody = 0;
    my $nbr_LinesOfCodeInBody = 0;
    $nbr_LinesInBody = count_lines( $body);
    $nbr_LinesOfCodeInBody = count_nonempty_lines( $body);
    $status |= Couples::counter_add($compteurs, $mnemo_LinesInBody, $nbr_LinesInBody);
    $status |= Couples::counter_add($compteurs, $mnemo_LinesOfCodeInBody, $nbr_LinesOfCodeInBody);
  }


  return $status;
}


1;
