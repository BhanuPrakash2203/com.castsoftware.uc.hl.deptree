
package ObjC::CountCondition ;

use strict;
use warnings;

use Erreurs;
use ObjC::ObjCNode;

my $mnemo_NegativeComparison = Ident::Alias_NegativeComparison();
my $mnemo_BooleanPitfall = Ident::Alias_BooleanPitfall();
#my $mnemo_SuspiciousAssignment = "Nbr_SuspiciousAssignment";

my $nb_NegativeComparison = 0;
my $nb_BooleanPitfall = 0;
#my $nb_SuspiciousAssignment = 0;

sub CountCondition($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $status = 0;
  $nb_NegativeComparison = 0;
  $nb_BooleanPitfall = 0;
#  $nb_SuspiciousAssignment = 0;

  if (not defined $vue->{'structured_code'})
  {
      $status |= Couples::counter_add ($compteurs, $mnemo_NegativeComparison , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BooleanPitfall , Erreurs::COMPTEUR_ERREUR_VALUE);
#      $status |= Couples::counter_add ($compteurs, $mnemo_SuspiciousAssignment , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
  }

  my $root = $vue->{'structured_code'};
  my @conds = GetNodesByKind($root, CondKind, 0);

  for my $cond (@conds) {

      my $stmt = GetStatement($cond);

      if ($$stmt =~ /;([^;]*);/s) {
        # case of a "for" loop.
	my $condStmt = $1;
	$stmt = \$condStmt;
      }

      if ($$stmt =~ /\bfalse\b|\bno\b|![^=]/smi ) {
        $nb_NegativeComparison++;
#print "negative comparison in ".${GetStatement($cond)}."\n";
      } 

      if ($$stmt =~ /\byes\s*[!=]=|[!=]=\s*\byes\b/smi ) {
        $nb_BooleanPitfall++;
#print "Boolean PITFALL in ".${GetStatement($cond)}."\n";
      } 

#      if ($$stmt =~ /\b(\w+)\s*=[^=]/) {
#         if ($1 ne 'self') {
#            $nb_SuspiciousAssignment++;  
#	 }
#      }
  }

  $status |= Couples::counter_add ($compteurs, $mnemo_NegativeComparison, $nb_NegativeComparison);
  $status |= Couples::counter_add ($compteurs, $mnemo_BooleanPitfall, $nb_BooleanPitfall);
#  $status |= Couples::counter_add ($compteurs, $mnemo_SuspiciousAssignment, $nb_SuspiciousAssignment);
  return $status;
}

1;
