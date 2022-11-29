
package ObjC::CountFunctionCall ;

use strict;
use warnings;

use Erreurs;
use ObjC::ObjCNode;
use Lib::Node;

my $mnemo_InstanciationWithNew = Ident::Alias_InstanciationWithNew();
my $mnemo_UncheckedInit = Ident::Alias_UncheckedInit();

my $nb_InstanciationWithNew = 0;
my $nb_UncheckedInit = 0;

sub CountFunctionCall($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $status = 0;
  $nb_InstanciationWithNew = 0;
  $nb_UncheckedInit = 0;

  if (not defined $vue->{'structured_code'})
  {
      $status |= Couples::counter_add ($compteurs, $mnemo_InstanciationWithNew , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_UncheckedInit , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
  }

  my $root = $vue->{'structured_code'};
  my @calls = GetNodesByKind($root, CallKind);

  for my $call (@calls) {
    my $stmt = GetStatement($call);

    # get the name of the function called..
    my ($fct) = $$stmt =~ /(\w+\s*(?:[:]|$))/sm;

    if (! defined $fct) {
      print "[CountFunctionCall] WARNING : incorrect syntax for call : $$stmt !!!\n";     
    }

    # Case of a "new" method ...
    if ( $fct eq 'new') {
      $nb_InstanciationWithNew++;
    }

    # Case of an "init" method ...
    if ( $fct =~ /\binit(?:With\w+)?\b/) {
      my $name = GetName($call);
      my $parent = GetParent($call);
      my $parentStmt = GetStatement($parent);

      # If the call belongs to a condition, then we consider it is tested.
      # So, do no do the following checks ...
      if ( !IsKind($parent, CondKind) ) {

        # if the statement of the parent 
        if ( $$parentStmt =~ /(\w+)\s*=\s*\[$name\]/) {
          my $VarToCheck = $1;
  
  	# get the instruction that follow the instruction containing the call.
  	my $nextSibling = Lib::Node::GetNextSibling($parent);
  
  	if (defined $nextSibling) {
  
    	  # check if it is a "if"
  	  if (IsKind($nextSibling, IfKind)) {
              # get the Condition node (the first child of the if).
  	    my $condNode = ObjC::ObjCNode::GetChildren($nextSibling)->[0];
  	    if (${GetStatement($condNode)} !~ /\b$VarToCheck\b/ ) {
                $nb_UncheckedInit++;
#print "UNCHECKED INIT : variable $VarToCheck is not checked in the if condition !!!\n";
  	    }
  	  }
            else {
              $nb_UncheckedInit++;
#print "UNCHECKED INIT : variable $VarToCheck is not checked!!!\n";
            }
          }
  	else {
            $nb_UncheckedInit++;
#print "UNCHECKED INIT : variable $VarToCheck is not checked!!!\n";
  	}
        }
        else {
          $nb_UncheckedInit++;
#print "UNCHECKED INIT : not assigned call result for $$stmt !!!\n";
        }
      }
    }
  }

  $status |= Couples::counter_add ($compteurs, $mnemo_InstanciationWithNew, $nb_InstanciationWithNew);
  $status |= Couples::counter_add ($compteurs, $mnemo_UncheckedInit, $nb_UncheckedInit);
  return $status;
}

1;
