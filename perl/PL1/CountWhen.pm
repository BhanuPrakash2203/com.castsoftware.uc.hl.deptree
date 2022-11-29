package PL1::CountWhen;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Ident;
use PL1::PL1Node;
use Lib::NodeUtil;
use CountUtil;

my $ComplexWhen__mnemo = Ident::Alias_ComplexWhen();
my $Select__mnemo = Ident::Alias_Switch();
my $MissingDefault__mnemo = Ident::Alias_MissingDefaults();

my $nb_ComplexWhen = 0 ;
my $nb_Select = 0 ;
my $nb_MissingDefault = 0 ;


sub CountMissingDefault($$$) {

  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_Select = 0 ;
  $nb_MissingDefault = 0 ;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root ) {
    $ret |= Couples::counter_add($compteurs, $Select__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $MissingDefault__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @selects = Lib::NodeUtil::GetNodesByKind( $root, SelectKind);
  $nb_Select = scalar @selects ;
  # For ALL select 
  for my $select (@selects) {

    my $blocs = GetSubBloc($select);
    my $otherfound = 0;
    for my $node ( @{$blocs} )
    {
      if (IsKind($node, OtherwiseKind)) {
        $otherfound=1;
      }
    }
    if (! $otherfound) {
      $nb_MissingDefault++ ;
    }
  }
  $ret |= Couples::counter_add($compteurs, $Select__mnemo, $nb_Select );
  $ret |= Couples::counter_add($compteurs, $MissingDefault__mnemo, $nb_MissingDefault );

  return $ret;
}


sub CountComplexWhen($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_ComplexWhen = 0 ;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root ) {
    $ret |= Couples::counter_add($compteurs, $ComplexWhen__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Whens = Lib::NodeUtil::GetNodesByKind( $root, WhenKind);
  # For ALL End 
  for my $when (@Whens) {
    my $statement = GetStatement($when);

    my ($WhenPart, $Instrpart) = CountUtil::splitAtPeer($statement, '(', ')');

    if (defined $WhenPart) {
      if ( $$WhenPart =~ /[\&\|]/ ) {
         $nb_ComplexWhen++;
      }
    }
  }
  $ret |= Couples::counter_add($compteurs, $ComplexWhen__mnemo, $nb_ComplexWhen );

  return $ret;
}


1;
