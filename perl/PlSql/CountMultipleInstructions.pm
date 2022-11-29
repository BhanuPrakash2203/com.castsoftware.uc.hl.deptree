
package PlSql::CountMultipleInstructions ;
# Module de comptage des lignes de plusieurs instructions 

use strict;
use warnings;

use Erreurs;



sub CountMultipleInstructions($$$);


sub CountMultipleInstructions($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;
  my $mnemo = Ident::Alias_MultipleInstructions() ;

  my $NomVueCode = 'code_without_directive' ; 
  my $buffer = (  $vue->{$NomVueCode} ) ;

  if ( ! defined $vue->{$NomVueCode} ) {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  

  #my $nb = () = $buffer  =~ /^[^\n]*\S[^\n]*;[\n]*\S/smg ;
  my @matches = $buffer  =~ /^[^\n]*\S[^\n]*;[^\n]*\S/smg ;
  my $nb = @matches;
  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  for my $ligne ( @matches )
  {
      Erreurs::LogInternalTraces('comptage', undef, undef, $mnemo, $ligne, '@');
  }

  for my $ligne ( $buffer =~ /([^\n]*)/sm )
  {
    if ( $ligne =~ /^[^\n]*\S[^\n]*;[^\n]*\S/sm )
    {
      Erreurs::LogInternalTraces('comptage', undef, undef, $mnemo, $ligne, '');
    }
  }

  return $ret;
}

1;



