

package TSql::ParseDetailed;

use strict;
use warnings;

use TSql::Node;
use TSql::TSqlNode;

use Erreurs;

use Ident;

my %Metrics = () ;
my %FROM_Parsed = () ;
my %JOIN_Parsed = () ;


# Pattern for the from list :<table> [[AS] <alias>], ... n
 my $FROM_LIST = '[\w\.\#]+\s*(?:(?:AS\s+)?(?:\w+\s*))?(?:,\s*[\w\.\#]+\s*(?:(?:AS\s+)?(?:\w+\s*))?)*';

 my $JOIN_TYPE='\b(?:inner|(?:left|right|full)\s*(?:outer)?|cross)?';

 my $JOIN_HINT='(?:LOOP|HASH|MERGE|REMOTE)?';

sub get_NbObjects($) {
  my $artifact = shift ;

  if ( (exists $Metrics{$artifact}) &&
       (exists $Metrics{$artifact}->{'nb_objects'}) &&
       (defined $Metrics{$artifact}->{'nb_objects'}) ) {
    return $Metrics{$artifact}->{'nb_objects'};
  }
  else {
    return 0;
  }
}

sub get_JointureList_ObjectsList($) {
  my $r_JointureList = shift;
  my @ObjectsList = ();

  # For each jointure ...
  for my $r_jointure (@{$r_JointureList}) {

    # For each used object list of the jointure.
    for my $r_UsedObject ( @{ $r_jointure->[1] }) {
      # keep the object name ...
      push @ObjectsList, $r_UsedObject->[0];
#print "   OBJECT : ".$r_UsedObject->[0]."\n";
      if (defined $r_UsedObject->[1]) {
#print "        --> ALIAS IS  :  ".$r_UsedObject->[1]."\n";
      }
      else {
#print "      ==> NO ALIAS !!!!\n";
      }
    }
  }
  return \@ObjectsList;
}

sub get_ObjectsList($) {
  my $artifact = shift;
  my @ObjectsList = ();

  if (defined $artifact) {
    push @ObjectsList, @{ get_JointureList_ObjectsList($FROM_Parsed{$artifact}) };
    push @ObjectsList, @{ get_JointureList_ObjectsList($JOIN_Parsed{$artifact}) };
  }

  return \@ObjectsList;
}


sub ParseSelect($$) {
  my $ArtifactsView = shift;
  my $artifact = shift ;

  $FROM_Parsed{$artifact} = [];
  $JOIN_Parsed{$artifact} = [];
  #$Metrics{$artifact} ;

  my $r_buf = \$ArtifactsView->{$artifact};
  my $nb_nonCanonical = 0;
  my $NotANSI = 0;
  my $nb_MissingAliases = 0;
  my $nb_tables = 0;

  my @tab_clause = split /(\bfrom\b|${JOIN_TYPE}\s*${JOIN_HINT}\s*\bjoin)/i, $$r_buf ;
  my $i = 0;
  my $imax = scalar @tab_clause - 2;
  while ($i <= $imax) {
    if ( $tab_clause[$i] =~ /\b(?:from|join)\b/i) {
#print "JOINTURE : ".$tab_clause[$i]."\n";

      my @JOINTURE = ($tab_clause[$i], []);

      if ($tab_clause[$i] =~ /from/i) {
        push @{$FROM_Parsed{$artifact}},\@JOINTURE;
      }
      else {
        push @{$JOIN_Parsed{$artifact}},\@JOINTURE;
      }

      $i++;
      if (defined $tab_clause[$i] && ($tab_clause[$i] =~ /\s+(${FROM_LIST})/isg)) {
	my @items=split ",", $1;

	if (scalar @items > 1) {
          $NotANSI = 1;
	}

	for my $item (@items) {
	   $item =~ s/\b(?:on|where|having|order\s+by|group\s+by)\b.*//si;
	   if ( $item =~ /([\w\.\#]+)(?:\s+AS)?(\s+[\w\.\#]+)?/) {
	     my $table=$1;
	     my $alias=$2;
	     #if (defined $table) { print "    TABLE : $table\n";}
	     #if (defined $alias) { print "    ALIAS : $alias\n";}

             $nb_tables ++;

	     if (!defined $alias) {
               $nb_MissingAliases++;
	     }

	     push @{$JOINTURE[1]}, [$table, $alias];
	   }
        }
      }
    }
    $i++;
  }
  $Metrics{$artifact}->{'NotANSI'} = $NotANSI;
  $Metrics{$artifact}->{'nb_objects'} = $nb_tables;
  $Metrics{$artifact}->{'nb_MissingAliases'} = $nb_MissingAliases;

  #get_ObjectsList($artifact);
}


sub ParseDetailed($) {
  my $vues = shift ;

  my $NomVue = 'routines' ; 
  my $ArtifactsView =  $vues->{$NomVue} ;
  if ( ! defined $ArtifactsView )
  {
    print "PARSE ERROR : unable to parse select details : $NomVue view not availbable.\n";
    return 0;
  }

  for my $artifact (keys %{$ArtifactsView}) {
    #**************** Artifact_Select *************
    if ( $artifact =~ /Artifact_select_/)   {
      ParseSelect($ArtifactsView, $artifact);

    }
  }

}

1;



