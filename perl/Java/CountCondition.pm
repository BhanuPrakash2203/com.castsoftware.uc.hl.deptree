package Java::CountCondition;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Lib::NodeUtil;

use Java::JavaNode;

my $UnconditionalCondition__mnemo = Ident::Alias_UnconditionalCondition();

my $nb_UnconditionalCondition = 0;


sub CountUnconditionalCondition($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_UnconditionalCondition = 0;

  my $code = \$vue->{'code'};
  
  if ( ! defined $$code )
  {
    $ret |= Couples::counter_add($compteurs, $UnconditionalCondition__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  $nb_UnconditionalCondition += () = $$code =~ /\bif\s*\(\s*(?:true|false)\s*\)/g;

# ------------ VERSION WITH PARSER VIEW --------------------  
# my $root =  $vue->{'structured_code'} ;
  
#  if ( ! defined $root ) )
#  {
#    $ret |= Couples::counter_add($compteurs, $UnconditionalCondition__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
#    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
#  }
  
#  my @Ifs = GetNodesByKindList( $root, [IfKind] );

#  for my $if (@Ifs) {
#    my $children = GetSubBloc($if);
 
#    if (${GetStatement($children->[0])} =~ /\(\s*\b(?:false|true)\b\s*\)/si) {
#print "UNCONDITIONAL CONDITION\n";
#      $nb_UnconditionalCondition++;
#    }
#  }

  $ret |= Couples::counter_add($compteurs, $UnconditionalCondition__mnemo, $nb_UnconditionalCondition );

  return $ret;
}

1;
