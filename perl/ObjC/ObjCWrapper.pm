
package ObjC::ObjCWrapper ;

use strict;
use warnings;

use Erreurs;

my %EmptyH = ();
my $WrappedViews = \%EmptyH;

# associate a given buffer to a view
sub replaceView($$) {
  my $viewName = shift;
  my $r_buf = shift;

  if (! exists $WrappedViews->{$viewName} ) {
    $WrappedViews->{$viewName} = $$r_buf;
  } 
}

sub CountBadSpacing($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;
  replaceView('code',\$vue->{'ObjC'});
  return CountBadSpacing::CountBadSpacing($fichier, $vue, $compteurs, $options);
}

1;
