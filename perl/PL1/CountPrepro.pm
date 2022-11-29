package PL1::CountPrepro;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;
use Ident;
use PL1::PL1Node;
use CountUtil;

my $ProcessStatement__mnemo = Ident::Alias_ProcessStatement();

my $nb_ProcessStatement = 0 ;



sub CountProcessStatement($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;

  $nb_ProcessStatement = 0 ;

  # This routine search the occurence of "%PROCESS" in the view "prepro_directives" 
  # or "*process" in the view "code".

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( (! defined $vue->{'code'}) && (! defined $vue->{'prepro_directives'})  ) {
    $ret |= Couples::counter_add($compteurs, $ProcessStatement__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  if ( ($vue->{'code'}              =~ /\*process\b/si) ||
       ($vue->{'prepro_directives'} =~ /%process\b/si) ) {
     $nb_ProcessStatement =1;
  }

  $ret |= Couples::counter_add($compteurs, $ProcessStatement__mnemo, $nb_ProcessStatement );

  return $ret;
}


1;
