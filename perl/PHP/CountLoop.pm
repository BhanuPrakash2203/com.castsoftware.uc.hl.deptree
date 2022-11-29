package PHP::CountLoop;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use PHP::PHPNode;

my $nb_MaxNestedLoops = 4;

my $While__mnemo = Ident::Alias_While();
my $Do__mnemo = Ident::Alias_Do();
my $For__mnemo = Ident::Alias_For();
my $Foreach__mnemo = Ident::Alias_Foreach();
my $UselessForLoop__mnemo = Ident::Alias_UselessForLoop();
my $FunctionCallInForLoopTest__mnemo = Ident::Alias_FunctionCallInForLoopTest();
my $IncrementerJumblingInLoop__mnemo = Ident::Alias_IncrementerJumblingInLoop();

my $nb_Do = 0;
my $nb_For = 0;
my $nb_While = 0;
my $nb_Foreach = 0;
my $nb_UselessForLoop = 0;
my $nb_FunctionCallInForLoopTest = 0;
my $nb_IncrementerJumblingInLoop = 0;

sub getNbJumbledIncrementer($;$);

sub getNbJumbledIncrementer($;$) {
  my $node = shift;
  my $forbidden = shift;
  my $nb_JumbledIncrementer = 0;
  my $local_forbidden = [];

  if (! defined $forbidden) {
    $forbidden = [];
  }
  
  if (IsKind($node, ForKind)) {
    my $cond = GetStatement(PHP::PHPNode::GetChildren($node)->[0]);
    my ($inc_expr) = $$cond =~ /;([^;]*)\)\s*$/sm;

    # if an inc expression is fouond then analyze it ...
    if (defined $inc_expr) {

      # The expression contains a variable ? 
      if ($inc_expr =~ /\$/) {

        # retrieves the name of the inc variable
        my ($incrementer) = $inc_expr =~ /\$(\w+)/sm;
        if (defined $incrementer) {
  	  # Check if the variable belongs to the forbidden list ...
	  my $violation =0;
	  for my $inc (@{$forbidden}) {
            if ($inc eq $incrementer) {
              $violation = 1;
	    }
	  }

	  if ($violation) {
#print "---->VIOLATION : Jumbled incrementer ($incrementer) at line ".GetLine($node)."\n";
	    $nb_JumbledIncrementer ++;
          }
	  else {
	    # Add the variable to the forbidden list.
            push @{$local_forbidden}, $incrementer;
#print " Adding forbidden incrementer ($incrementer) at line ".GetLine($node)."\n";
          }
        }
      }
    }
  }

  for my $child (@{PHP::PHPNode::GetChildren($node)}) {
    $nb_JumbledIncrementer += getNbJumbledIncrementer($child, [@{$forbidden}, @{$local_forbidden}]);
  }
  return $nb_JumbledIncrementer;
}

sub CountIncrementerJumblingInLoop($$$) {
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_IncrementerJumblingInLoop = 0;

  my $root =  $vue->{'structured_code'} ;
  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $IncrementerJumblingInLoop__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @Fors = GetNodesByKind($root,ForKind,1);

  for my $for (@Fors) {
    $nb_IncrementerJumblingInLoop += getNbJumbledIncrementer( $for );
  }

#print "TOTAL VIOLATION = $nb_IncrementerJumblingInLoop\n";
  $ret |= Couples::counter_add($compteurs, $IncrementerJumblingInLoop__mnemo, $nb_IncrementerJumblingInLoop );

  return $ret;
}


sub CountLoop($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_Do = 0;
  $nb_For = 0;
  $nb_While = 0;
  $nb_Foreach = 0;
  $nb_UselessForLoop = 0;
  $nb_FunctionCallInForLoopTest = 0;


  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $While__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Do__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $For__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Foreach__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $UselessForLoop__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $FunctionCallInForLoopTest__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @While = GetNodesByKind( $root, WhileKind);
  my @Do = GetNodesByKind( $root, DoKind);
  my @For = GetNodesByKind( $root, ForKind);
  my @Foreach = GetNodesByKind( $root, ForeachKind);

  $nb_While = scalar @While;
  $nb_Do = scalar @Do;
  $nb_For = scalar @For;
  $nb_Foreach = scalar @Foreach;

  my @Loops = (@While, @Do, @For, @Foreach);

  for my $for (@For) {
    my $cond = GetStatement(PHP::PHPNode::GetChildren($for)->[0]);
#print "for cond = $$cond\n";

    # Test if the "init" part is empty ...
    if ( $$cond =~ /^\s*\(\s*;[^;]*;\s*\)\s*$/sm ) {
      $nb_UselessForLoop ++;
#print "USELESS FOR : $$cond\n";
    }

    # Test if the test expression conatains a call to a function.
    if ( $$cond =~ /^[^;]*;([^;]*);[^;]*$/sm ) {
      my $testExpression = $1;
      if ($testExpression =~ /\w\s*\(/sg) {
        $nb_FunctionCallInForLoopTest ++;
#print "FUNCTION CALL IN FOR LOOP END TEST : $testExpression\n";
      }
    }
  }

  $ret |= Couples::counter_add($compteurs, $While__mnemo, $nb_While );
  $ret |= Couples::counter_add($compteurs, $Do__mnemo, $nb_Do );
  $ret |= Couples::counter_add($compteurs, $For__mnemo, $nb_For );
  $ret |= Couples::counter_add($compteurs, $Foreach__mnemo, $nb_Foreach );
  $ret |= Couples::counter_add($compteurs, $UselessForLoop__mnemo, $nb_UselessForLoop );
  $ret |= Couples::counter_add($compteurs, $FunctionCallInForLoopTest__mnemo, $nb_FunctionCallInForLoopTest );

  return $ret;
}


1;
