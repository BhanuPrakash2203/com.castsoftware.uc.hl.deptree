package TypeScript::CountLoop;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use TypeScript::TypeScriptNode;

my $While__mnemo = Ident::Alias_While();
my $Do__mnemo = Ident::Alias_Do();
my $For__mnemo = Ident::Alias_For();
my $FunctionCallInLoopTest__mnemo = Ident::Alias_FunctionCallInLoopTest();
my $ForinLoop__mnemo = Ident::Alias_ForinLoop();

my $nb_Do = 0;
my $nb_For = 0;
my $nb_While = 0;
my $nb_FunctionCallInLoopTest = 0;
my $nb_ForinLoop = 0;

sub CountLoop($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_Do = 0;
  $nb_For = 0;
  $nb_While = 0;
  $nb_FunctionCallInLoopTest = 0;
  $nb_ForinLoop = 0;

  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $While__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Do__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $For__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $FunctionCallInLoopTest__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ForinLoop__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @While = GetNodesByKind( $root, WhileKind);
  my @Do = GetNodesByKind( $root, DoKind);
  my @For = GetNodesByKind( $root, ForKind);

  $nb_While = scalar @While;
  $nb_Do = scalar @Do;
  $nb_For = scalar @For;

  my @Loops = (@While, @Do, @For);

  for my $loop (@Loops) {

    # Check condition
    if ( ! IsKind($loop, DoKind)) {
    
      my $condNode = Lib::NodeUtil::GetChildren($loop)->[0]; 

      my $condTest = ${Lib::NodeUtil::GetXKindData($condNode, 'flatexpr');};
#print "loop cond = $condTest\n";

      # get the first node if any ...
      my @calls = GetNodesByKind($condNode, FunctionCallKind, 1);
      if ( scalar @calls > 0) {
        $nb_FunctionCallInLoopTest ++;
#print "----> FUNCTION CALL IN LOOP END TEST\n";
      }

      if (IsKind($loop, ForKind)) {
        if ($condTest =~ /\bin\b/s) {
          $nb_ForinLoop++;
        }
      }
    }
  }

  $ret |= Couples::counter_add($compteurs, $While__mnemo, $nb_While );
  $ret |= Couples::counter_add($compteurs, $Do__mnemo, $nb_Do );
  $ret |= Couples::counter_add($compteurs, $For__mnemo, $nb_For );
  $ret |= Couples::counter_add($compteurs, $FunctionCallInLoopTest__mnemo, $nb_FunctionCallInLoopTest );
  $ret |= Couples::counter_add($compteurs, $ForinLoop__mnemo, $nb_ForinLoop );

  return $ret;
}


1;
