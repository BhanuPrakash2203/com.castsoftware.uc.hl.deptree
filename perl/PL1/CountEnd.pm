package PL1::CountEnd;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Ident;
use PL1::PL1Node;
use Lib::NodeUtil;

my $End__mnemo = Ident::Alias_End();
my $WhithoutLabelEnd__mnemo = Ident::Alias_WithoutLabel_End();

my $nb_End = 0 ;
my $nb_WhithoutLabelEnd = 0 ;

sub Count_End_Of_NodeContainingEnds($$);

sub Count_End_Of_NodeContainingEnds($$)
{
  my ($baseNode, $outputlist) = @_;
  my $bloc = Lib::Node::GetSubBloc($baseNode);
  my $nb_ContainedEnd = 0;
  foreach my $node ( @{$bloc} )
  {
    if (IsKind ( $node, EndKind )) {

      if ($nb_ContainedEnd > 0) {
	# record the End node as ending a structure containing other ends ...
        push @$outputlist, $node;
      }
      $nb_ContainedEnd += 1;
      return $nb_ContainedEnd;
    }
    else {
      $nb_ContainedEnd += Count_End_Of_NodeContainingEnds($node, $outputlist);
    }
  }

  return $nb_ContainedEnd;
}



sub CountWithoutLabelEnd($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  $nb_End = 0 ;
  $nb_WhithoutLabelEnd = 0 ;

  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root ) {
    $ret |= Couples::counter_add($compteurs, $End__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $WhithoutLabelEnd__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Ends = Lib::NodeUtil::GetNodesByKind( $root, EndKind);
  my @End_Of_NodeContainingEnds = ();
  my $nb_ContainedEnd = Count_End_Of_NodeContainingEnds( $root, \@End_Of_NodeContainingEnds);

  $nb_End = scalar @Ends ;

  # For ALL End 
  for my $end (@End_Of_NodeContainingEnds) {

    my $tag = GetName($end);
    if ( (! defined $tag) || ($tag eq '') ) {
      $nb_WhithoutLabelEnd++ ;
    }
  }

  $ret |= Couples::counter_add($compteurs, $End__mnemo, $nb_End );
  $ret |= Couples::counter_add($compteurs, $WhithoutLabelEnd__mnemo, $nb_WhithoutLabelEnd );

  return $ret;
}


1;
