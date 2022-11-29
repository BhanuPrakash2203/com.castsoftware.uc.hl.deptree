

package PL1::CountSQL;
# Module du comptage TDB: Nombre de procedures internes non referencees.

use strict;
use warnings;

use PL1::PL1Node;
use Lib::NodeUtil;

use Erreurs;

use Ident;

my $SQL__mnemo = Ident::Alias_SQL();
my $GroupBy__mnemo = Ident::Alias_GroupBy();
my $NotExists__mnemo = Ident::Alias_NotExists();
my $NotIn__mnemo = Ident::Alias_NotIn();
my $SelectAll__mnemo = Ident::Alias_SelectAll();
my $NotTestedSQLCODE__mnemo = Ident::Alias_NotTestedSQLCODE();

my $nb_SQL = 0;
my $nb_GroupBy = 0;
my $nb_NotExists = 0;
my $nb_NotIn = 0;
my $nb_SelectAll = 0;
my $nb_NotTestedSQLCODE = 0;

sub CountSQL($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_SQL = 0;
  $nb_GroupBy = 0;
  $nb_NotExists = 0;
  $nb_NotIn = 0;
  $nb_SelectAll = 0;
  $nb_NotTestedSQLCODE = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $SQL__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $GroupBy__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $NotExists__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $NotIn__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $SelectAll__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $NotTestedSQLCODE__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @SQLs = Lib::NodeUtil::GetNodesByKind( $root, SQLKind);

  $nb_SQL = scalar @SQLs ;

  # For ALL procedure 
  for my $sql (@SQLs) {

    my $statement = ${GetStatement($sql)} ;

    if ( $statement =~ /\bgroup\s+by\b/is ) {
      $nb_GroupBy++;
    }

    if ( $statement =~ /\bnot\s+exists\b/is ) {
      $nb_NotExists++;
    }

    if ( $statement =~ /\bnot\s+in\b/is ) {
      $nb_NotIn++;
    }

    if ( $statement =~ /\bselect\s+\*\s+from\b/is ) {
      $nb_SelectAll++;
    }


    my $SQLCODE_is_tested = 0;
    my $r_FollowingSiblings = getFollowingSiblings($sql);

    # Test each following statement.
    for my $following (@$r_FollowingSiblings) {
      # If one is a test on SQLCODE, it's OK.
      if ( IsKind($following, IfKind) || IsKind($following, SelectKind)) {
        $statement = ${GetStatement($following)} ;
        if ( $statement =~ /\bSQLCODE\b/is ) {
          $SQLCODE_is_tested=1;;
	  last;
        }
	# The search ends as soon a new SQL request is encountered.
        elsif (IsKind($following, SQLKind)) {
	  last;
	}
      }
    }
    if (! $SQLCODE_is_tested) {
      $nb_NotTestedSQLCODE++;
    }
  }
  $ret |= Couples::counter_add($compteurs, $SQL__mnemo, $nb_SQL );
  $ret |= Couples::counter_add($compteurs, $GroupBy__mnemo, $nb_GroupBy );
  $ret |= Couples::counter_add($compteurs, $NotExists__mnemo, $nb_NotExists );
  $ret |= Couples::counter_add($compteurs, $NotIn__mnemo, $nb_NotIn );
  $ret |= Couples::counter_add($compteurs, $SelectAll__mnemo, $nb_SelectAll );
  $ret |= Couples::counter_add($compteurs, $NotTestedSQLCODE__mnemo, $nb_NotTestedSQLCODE );

  return $ret;
}

1;



