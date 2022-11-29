

package PlSql::CountComplexConditions ;
# Module de comptage des and et or dans des conditions;

use strict;
use warnings;

use Erreurs;

sub CountComplexConditions($$$);


sub CountComplexConditions($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'conditionnal_expressions' ; 
  my $input =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_ComplexConditions();

  if ( ! defined $input )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my $nb=0;
  for my $condition ( @{$input} )
  {
    my $nb_and = () = $condition  =~ /\b(and)\b/smig ;
    my $nb_or = () = $condition  =~ /\b(or)\b/smig ;
    if ( $nb_and + $nb_or >= 4 )
    {
      if ( ( $nb_and > 0 ) and ( $nb_or > 0) )
      {
        $nb ++ ;
      }
    }
  }
  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;



