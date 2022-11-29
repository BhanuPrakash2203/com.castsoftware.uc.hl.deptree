package PL1::CountLoop;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use PL1::PL1Node;
use Lib::NodeUtil;

my $nb_MaxNestedLoops = 4;

my $WhileLoop__mnemo = Ident::Alias_WhileLoop();
my $UntilLoop__mnemo = Ident::Alias_UntilLoop();

my $nb_WhileLoop = 0 ;
my $nb_UntilLoop = 0 ;


sub isWhileLoop($) {
  my ($loop) = @_ ;

  my $statement = GetStatement($loop);
  if ($$statement =~ /\bwhile\b/i ) {
    return 1;
  }
  else {
    return 0;
  }
}

sub isUntilLoop($) {
  my ($loop) = @_ ;

  my $statement = GetStatement($loop);
  if ($$statement =~ /\buntil\b/i ) {
    return 1;
  }
  else {
    return 0;
  }
}


sub CountHeterogeneousLoop($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_WhileLoop = 0 ;
  $nb_UntilLoop = 0 ;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $WhileLoop__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $UntilLoop__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Loops = Lib::NodeUtil::GetNodesByKind( $root, DoloopKind);
  my $nb_while = 0;
  my $nb_until = 0;
  # For ALL loops 
  for my $loop (@Loops) {

     if (isWhileLoop($loop)) {
       $nb_WhileLoop++;
     }
     if (isUntilLoop($loop) ) {
       $nb_UntilLoop++;
     }
  }
  $ret |= Couples::counter_add($compteurs, $WhileLoop__mnemo, $nb_WhileLoop );
  $ret |= Couples::counter_add($compteurs, $UntilLoop__mnemo, $nb_UntilLoop );

  return $ret;
}


1;
