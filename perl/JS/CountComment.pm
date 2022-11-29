package JS::CountComment;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use Lib::NodeUtil;
use JS::JSNode;
use JS::Identifiers;

my $IDENTIFIER = JS::Identifiers::getIdentifiersPattern();

my $IEConditionalComments__mnemo = Ident::Alias_IEConditionalComments();

my $nb_IEConditionalComments = 0;



sub CountIEConditionalComments($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_IEConditionalComments = 0;

  my $comment =  \$vue->{'comment'} ;
  my $code =  \$vue->{'code'} ;

  if ( ( ! defined $comment ) || ( ! defined $code ) ||
       ( ! defined $$comment ) || ( ! defined $$code ))
  {
    $ret |= Couples::counter_add($compteurs, $IEConditionalComments__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  if ( $$comment =~ /\@cc_on\b|\@if\b|\@set\b/s) {
    $nb_IEConditionalComments++;
  }
  elsif ( $$code =~ /\@cc_on\b|\@if\b|\@set\b/s) {
    $nb_IEConditionalComments++;
  }

  $ret |= Couples::counter_add($compteurs, $IEConditionalComments__mnemo, $nb_IEConditionalComments );

  return $ret;
}


1;
