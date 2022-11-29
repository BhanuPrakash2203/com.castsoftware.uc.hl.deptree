package PL1::CountVg;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use PL1::PL1Node;
use Lib::NodeUtil;


my $nb_MaxNestedLoops = 4;

my $Loop__mnemo = Ident::Alias_Loop();
my $If__mnemo = Ident::Alias_If();
my $When__mnemo = Ident::Alias_Case();
my $Other__mnemo = Ident::Alias_Default();

my $Goto__mnemo = Ident::Alias_Goto();
my $Iterate__mnemo = Ident::Alias_Continue();
my $Leave__mnemo = Ident::Alias_Break();

my $nb_Loop = 0 ;
my $nb_If = 0 ;
my $nb_When = 0 ;
my $nb_Other = 0 ;
my $nb_Goto = 0 ;
my $nb_Iterate = 0 ;
my $nb_Leave = 0 ;

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

sub CalculNodeVg($) {
  my ($node) = @_ ;

  my @Loops = Lib::NodeUtil::GetNodesByKind( $node, DoloopKind);
  my @Proc = Lib::NodeUtil::GetNodesByKind( $node, ProcedureKind);
  my @When = Lib::NodeUtil::GetNodesByKind( $node, WhenKind);
  my @Other = Lib::NodeUtil::GetNodesByKind( $node, OtherwiseKind);
  my @If = Lib::NodeUtil::GetNodesByKind( $node, IfKind);

  return scalar @Loops + scalar @Proc + scalar @When + scalar @Other + scalar @If;
}

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

sub CountVg($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_Loop = 0 ;
  $nb_If = 0 ;
  $nb_When = 0 ;
  $nb_Other = 0 ;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $Loop__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $If__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $When__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Other__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Loops = Lib::NodeUtil::GetNodesByKind( $root, DoloopKind);
  my @When = Lib::NodeUtil::GetNodesByKind( $root, WhenKind);
  my @Other = Lib::NodeUtil::GetNodesByKind( $root, OtherwiseKind);
  my @If = Lib::NodeUtil::GetNodesByKind( $root, IfKind);

  $nb_Loop = scalar @Loops ;
  $nb_If = scalar @If ;
  $nb_When = scalar @When ;
  $nb_Other = scalar @Other ;


  $ret |= Couples::counter_add($compteurs, $Loop__mnemo, $nb_Loop );
  $ret |= Couples::counter_add($compteurs, $If__mnemo, $nb_If );
  $ret |= Couples::counter_add($compteurs, $When__mnemo, $nb_When );
  $ret |= Couples::counter_add($compteurs, $Other__mnemo, $nb_Other );

  return $ret;
}

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
sub CountSpaghettiCode($$$) 
{

  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_Goto = 0 ;
  $nb_Iterate = 0 ;
  $nb_Leave = 0 ;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $Goto__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Iterate__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Leave__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Goto = Lib::NodeUtil::GetNodesByKind( $root, GotoKind);
  $nb_Goto = scalar @Goto ;

  my @Loops = Lib::NodeUtil::GetNodesByKind( $root, DoloopKind);

  for my $loop (@Loops) {
    my @Iterate = Lib::NodeUtil::GetNodesByKind( $loop, IterateKind);
    my @Leave = Lib::NodeUtil::GetNodesByKind( $loop, LeaveKind);

    $nb_Iterate += scalar @Iterate;
    $nb_Leave += scalar @Leave;
  }

  $ret |= Couples::counter_add($compteurs, $Goto__mnemo, $nb_Goto );
  $ret |= Couples::counter_add($compteurs, $Iterate__mnemo, $nb_Iterate );
  $ret |= Couples::counter_add($compteurs, $Leave__mnemo, $nb_Leave );

  return $ret;
}

1;
