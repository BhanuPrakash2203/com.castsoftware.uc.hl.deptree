

package TSql::CountSelect;

use strict;
use warnings;

use TSql::Node;
use TSql::TSqlNode;

use Erreurs;

use Ident;

my $DEBUG=1;

sub CountSelect($$$);

my $NotANSI_Joins__mnemo = Ident::Alias_NotANSI_Joins();
my $MissingTableAlias__mnemo = Ident::Alias_MissingTableAlias();
my $SubQueries__mnemo = Ident::Alias_SubQueries();
my $ComplexQueries__mnemo = Ident::Alias_ComplexQueries();


my $nb_NotANSI_Joins = 0;
my $nb_MissingTableAlias = 0;
my $nb_SubQueries = 0;
my $nb_ComplexQueries = 0;

my $MAX_SELECT_COLUMN = 9 ;

sub hasSubQuerie($) {
  my $SelectNode = shift;

  if (TSql::TSqlNode::IsContainingKind($SelectNode, SelectKind)) {
    return 1;
  }
  else {
    return 0;
  }
}

sub checkMissingAlias($) {
  my $r_from = shift;

  my @tables = split ",", $$r_from;

  for my $table (@tables) {
    if ( $table !~ /[\w\.#]+\s+\w+/) {
      return 1;
    }
  }
  return 0;
}


sub CountSelect($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_NotANSI_Joins = 0;
  $nb_MissingTableAlias = 0;
  $nb_SubQueries = 0;
  $nb_ComplexQueries = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $SubQueries__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $nb_SubQueries = Erreurs::COMPTEUR_ERREUR_VALUE;
    $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  else {
    my @Selects = GetNodesByKind( $root, SelectKind);

    for my $select (@Selects) {
       $nb_SubQueries += hasSubQuerie($select);
    }
  }


  $NomVueCode = 'routines' ; 
  my $ArtifactsView =  $vue->{$NomVueCode} ;
  if ( ! defined $ArtifactsView )
  {
    $ret |= Couples::counter_add($compteurs, $NotANSI_Joins__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $MissingTableAlias__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ComplexQueries__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $nb_NotANSI_Joins= Erreurs::COMPTEUR_ERREUR_VALUE;
    $nb_MissingTableAlias = Erreurs::COMPTEUR_ERREUR_VALUE;
    $nb_ComplexQueries = Erreurs::COMPTEUR_ERREUR_VALUE;
    $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  else {
  for my $artifact (keys %{$ArtifactsView}) {
    if ( $artifact =~ /Artifact_select/) {

      # CHECK NUMBER OF COLUMNS ( Nbr_ComplexQueries )
      
      my ($columns) = $ArtifactsView->{$artifact} =~ /\A(.*?)(\bINTO\b|\bFROM\b)/si ;
      if (defined $columns) {

        # Removing of parasitic patterns ("top" and "with") !!
        $columns =~ s/(?:\ball\b|\bdistinct\b|top\s*\([^()]*\)\s*(?:percent\b)?\s*(with\s*ties\b)?)//i;
        my $nb_columns = () = $columns =~ /,/g ;
	$nb_columns++;

	if ( ( $nb_columns > $MAX_SELECT_COLUMN ) ||
             ( $columns =~ /\A\s*[\*]\s*\Z/s ) ) {	
          $nb_ComplexQueries ++;
#print "COMPLEX QUERY : $columns\n";
        }
      }

      # CHECK JOINTURE

 # Pattern for the from list :<table> [[AS] <alias>], ... n
 my $FROM_LIST = '[\w\.\#]+\s*(?:(?:AS\s+)?(?:\w+\s*))?(?:,\s*[\w\.\#]+\s*(?:(?:AS\s+)?(?:\w+\s*))?)*';

 # Pattern for a join
 my $JOIN='\s*\b(?:inner|(?:left|right|full)\s*(?:outer)?|cross)?\s*\bjoin';

      while ($ArtifactsView->{$artifact} =~ 
	      /from\s+(?:(${FROM_LIST})(${JOIN})|(${FROM_LIST}))/isg) {
          my $FROM_LIST_item;
	  my $JOIN_item;
	  if (defined $1) {
	     # The FROM + JOIN pattern has been recognized. 
	     $FROM_LIST_item=$1;
	     $JOIN_item=$2;
	     
	     # WARNING, bord effect : in case the list defines no alias, first word of the join
	     # expression can be captured in the from list pattern. This
	     # case will be detected and regularized ...
	     if ($FROM_LIST_item =~ /(.*?)(\b(?:inner|(?:left|right|full)\s*(?:outer)?|cross)\b\s*)$/smi) {
	       $FROM_LIST_item=$1;
               $JOIN_item=$2.$JOIN_item;
	     }
	  }
	  else {
	     # No JOIN expression found.
	     $FROM_LIST_item=$3;
	     $JOIN_item=undef;

	     # Managing bord effect in case there were no alias in the last object ...
	     # example : FROM CWRef c,toto where @Id=1
             $FROM_LIST_item =~ s/\b(?:where|having|order\s+by|group\s+by)\b.*//si;

	  }

	  if ( $FROM_LIST_item =~ /,/sg ) {
            $nb_NotANSI_Joins++;
	    $nb_MissingTableAlias += checkMissingAlias(\$FROM_LIST_item);
	  }
      }

    }
  }
  }


  $ret |= Couples::counter_add($compteurs, $NotANSI_Joins__mnemo, $nb_NotANSI_Joins );
  $ret |= Couples::counter_add($compteurs, $MissingTableAlias__mnemo, $nb_MissingTableAlias );
  $ret |= Couples::counter_add($compteurs, $SubQueries__mnemo, $nb_SubQueries );
  $ret |= Couples::counter_add($compteurs, $ComplexQueries__mnemo, $nb_ComplexQueries );

  return $ret;
}


1;



