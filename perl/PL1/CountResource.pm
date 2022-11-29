
package PL1::CountResource ;
# Module de comptage des instructions continue, goto, exit.

use strict;
use warnings;

use Erreurs;

sub CountResource($$$);

my $MissingFileClose__mnemo = Ident::Alias_MissingFileClose();
my $MissingVarFree__mnemo = Ident::Alias_MissingVarFree();

my $nb_MissingFileClose=0;
my $nb_MissingVarFree=0;


sub get_opened_files($) {
  my $r_view = shift;

  my @varfiles = ();

  while ( $$r_view =~ /open\s+file\s*\(\s*(\w*)\s*\)/isg ) {
    push @varfiles, $1 ;
  }
  return \@varfiles ;
}

sub get_closed_files($) {
  my $r_view = shift;

  my %varfiles = ();

  while ( $$r_view =~ /close\s+file\s*\(\s*([\*\w]*)\s*\)/isg ) {
    $varfiles{$1}=1 ;
  }
  return \%varfiles ;
}



sub get_allocated_vars($) {
  my $r_view = shift;

  my @variables = ();

  while ( $$r_view =~ /allocate\s+([^;]*)/isg ) {
    my $varlist = $1;
    @variables = split ',', $varlist;
    map { $_ =~ s/^\s*\d*\s*// } @variables;
    map { $_ =~ s/^(\w*).*/$1/ } @variables;
  }
  return \@variables ;
}

sub get_freed_vars($) {
  my $r_view = shift;

  my %variables = ();

  while ( $$r_view =~ /free\s+([^;]*)/isg ) {
    my $varlist = $1;
    my @list = split ',', $varlist;
    map { $_ =~ s/\s*//sg } @list;
    for my $var (@list) {
       $variables{$var} = 1;
    }
  }
  return \%variables ;
}

sub CountResource($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_MissingFileClose=0;
  $nb_MissingVarFree=0;

  my $NomVueCode = 'sansprepro'; 
  my $buffer = undef;

  if ( ! defined $vue->{$NomVueCode} )
  {
    $ret |= Couples::counter_add($compteurs, $MissingFileClose__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $MissingVarFree__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  # Check for missing file closing ...
  my $r_H_closed_files = get_closed_files(\$vue->{$NomVueCode}) ;

  if ( ! exists $r_H_closed_files->{'*'} ) {
    my $r_T_opened_files = get_opened_files(\$vue->{$NomVueCode}) ;

    for my $file (@$r_T_opened_files) {
      if ( ! exists $r_H_closed_files->{$file} ) {
	$nb_MissingFileClose++;
      }
    }
  }

  # Check for missing file closing ...

  my $r_T_allocated_vars = get_allocated_vars(\$vue->{$NomVueCode});
  my $r_H_Freed_vars = get_freed_vars(\$vue->{$NomVueCode});

  for my $var (@$r_T_allocated_vars) {
    if ( ! exists $r_H_Freed_vars->{$var} ) {
	$nb_MissingVarFree++;
    }
  }

  $ret |= Couples::counter_add($compteurs, $MissingFileClose__mnemo, $nb_MissingFileClose );
  $ret |= Couples::counter_add($compteurs, $MissingVarFree__mnemo, $nb_MissingVarFree );

  return $ret;


}

1;



