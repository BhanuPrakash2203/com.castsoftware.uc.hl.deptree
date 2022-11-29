

package Abap::CountComments;

use strict;
use warnings;

use Lib::Node;
use Abap::AbapNode;

use Erreurs;
use CountUtil;
use Ident;

my $COMMENT_RATIO_METHOD = 5;
my $COMMENT_RATIO_FUNCTION = 30;


my $UnCommentedRoutines__mnemo = Ident::Alias_UnCommentedRoutines();
my $LowCommentedRoutines__mnemo = Ident::Alias_LowCommentedRoutines();

my $nb_UnCommentedRoutines = 0;
my $nb_LowCommentedRoutines = 0;

sub ptr_checkUnCommentedRoutines($$) {
  my $agglo = shift;
  my $COMMENT_RATIO = shift;

  my $nbC = () = $$agglo=~/C/sg;
  my $nbP = () = $$agglo=~/P/sg;
#my $ratio = $nbC/$nbP *100;
#print "RIATO = $ratio\n";
  if ( $nbC < (($nbP * $COMMENT_RATIO) / 100) ) {
    $nb_LowCommentedRoutines++;
#print "=======> FOUND a LowCommented Violement!!!\n";
  }
  if ( $nbC == 0 ) {
    $nb_UnCommentedRoutines++;
#print "=======> FOUND a UnCommented Violement!!!\n";
  }
}

sub ptr_checkUnCommentedFunctions($) {
  my $agglo = shift;
  ptr_checkUnCommentedRoutines($agglo, $COMMENT_RATIO_FUNCTION)
}

sub ptr_checkUnCommentedMethods($) {
  my $agglo = shift;
  ptr_checkUnCommentedRoutines($agglo, $COMMENT_RATIO_METHOD)
}

sub CountUnCommentedRoutines($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  $nb_UnCommentedRoutines = 0;
  $nb_LowCommentedRoutines = 0;

  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $UnCommentedRoutines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $LowCommentedRoutines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  if ( ! defined $vue->{'agglo'} ) {
    $ret |= Couples::counter_add($compteurs, $UnCommentedRoutines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $LowCommentedRoutines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret;
  }

  my $artifactView = $vue->{'artifact'};
  if ( ! defined $artifactView ) {
    $ret |= Couples::counter_add($compteurs, $UnCommentedRoutines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $LowCommentedRoutines__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret;
  }

  #============ ROUTINES ARTIFACTS =================

  # my @Procs = GetNodesByKind( $root, FormKind);
  my @Funcs = GetNodesByKind( $root, FunctionKind);
  my @Meths = GetNodesByKind( $root, MethodKind);
  #my @Mods = GetNodesByKind( $root, ModuleKind);

  #my @Artifacts = (@Procs, @Funcs, @Meths, @Mods);
  my @Artifacts = ( @Funcs, @Meths);

  my @TabToCheck = ();
  for my $artif ( @Artifacts) {
    my $line = GetLine($artif);
    my $name = GetName($artif);
    my $artiKey = buildArtifactKeyByData($name, $line);

#    if ($artifactView->{$artiKey} =~ /\A\s*\bend(method|function|form|module)\b/is) {
#      # Do not apply commentary rules to empty artifact.
#      next;
#    }

    my $size = () =  $artifactView->{$artiKey} =~ /\n/sg ;
    my $endline = $line + $size;

    if (IsKind($artif, FunctionKind)) {
      push @TabToCheck, [$line, $endline, \&ptr_checkUnCommentedFunctions];
    }
    elsif (IsKind($artif, MethodKind)) {
      push @TabToCheck, [$line, $endline, \&ptr_checkUnCommentedMethods];
    }
  }

  # Check comments in the pre-defined zones ...
  CountUtil::checkComment(\$vue->{'agglo'}, \@TabToCheck);
  

  $ret |= Couples::counter_add($compteurs, $UnCommentedRoutines__mnemo, $nb_UnCommentedRoutines );
  $ret |= Couples::counter_add($compteurs, $LowCommentedRoutines__mnemo, $nb_LowCommentedRoutines );
}



1;




