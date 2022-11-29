

package PlSql::CountConditionsAndOr ;
# Module de comptage des and et or dans des conditions;

use strict;
use warnings;

use Erreurs;

sub CountConditionsAndOr($$$);


sub CountConditionsAndOr($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'conditionnal_expressions' ; 
  my $input =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_AndOr();

  if ( ! defined $input )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my $nb=0;
  for my $condition ( @{$input} )
  {
    my $nb_local = () = $condition  =~ /\b(and|or)\b/smig ;
    $nb += $nb_local;
    if ( $nb_local gt 0)
    {
      Erreurs::LogInternalTraces('comptage', undef, undef, $mnemo, $condition, $nb_local);
    }

  }
  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



