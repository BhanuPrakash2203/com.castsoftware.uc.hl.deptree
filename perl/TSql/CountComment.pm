

package TSql::CountComment;
# Module du comptage TDB: Nombre de procedures internes non referencees.

use strict;
use warnings;

use TSql::Node;
use TSql::TSqlNode;
use TSql::Identifier;

use Erreurs;
use Ident;
use CountUtil;

my $Nbr_UnCommentedRoutine__mnemo = Ident::Alias_UnCommentedRoutines();
my $Nbr_UnCommentedParameters__mnemo = Ident::Alias_UnCommentedParameters();
my $Nbr_TotalParameters__mnemo = Ident::Alias_TotalParameters();
my $Nbr_UnCommentedViews__mnemo = Ident::Alias_UnCommentedViews();

my $nb_UnCommentedRoutine = 0;
my $nb_UnCommentedParameters = 0;
my $nb_TotalParameters = 0;
my $nb_UnCommentedViews = 0;

# Number of line before a "create view" in which a comment line should be found.
my $SIZE_COMMENT_ZONE_BEFORE_VIEW = 10;

# Number of line before a routine in which a comment line should be found.
my $SIZE_COMMENT_ZONE_BEFORE_ROUTINE = 10;

my $COMMENT_ZONE_BEFORE_PARAM = 2;



sub ptr_checkUnCommentedViews($) {
  my $agglo = shift;
#print "Here's the callback (ptr_checkUnCommentedViews) !!!!\n";
  if (! CountUtil::IsCommentBefore($agglo)) {
    $nb_UnCommentedViews++;
#print "=======> FOUND a violement !!!\n";
  }
}


sub ptr_checkUnCommentedRoutine($) {
  my $agglo = shift;
#print "Here's the callback (ptr_checkUnCommentedRoutine) !!!!\n";
  if (! CountUtil::IsCommentBefore($agglo)) {
    $nb_UnCommentedRoutine++;
#print "=======> FOUND a violement !!!\n";
  }
}

sub ptr_checkUnCommentedParameter($) {
  my $agglo = shift;
#print "Here's the callback (ptr_checkUnCommentedParameter) !!!!\n";
  if (! CountUtil::IsCommentBeforeAndAt($agglo)) {
    $nb_UnCommentedParameters++;
#print "=======> FOUND a violement !!!\n";
  }
}

sub addCommentParamToCheck($$) {
  my $rout = shift;
  my $r_TabToCheck = shift;
  my $artifactLine = GetLine($rout);
  my $currentLine = $artifactLine;

#my ($before, $parameters) = GetStatement($rout) =~ /\A\s*((?:create\s+(?:procedure|function|proc|func)\s+)?[\w\.]+\s+)(.*?)(?:\bwith\b.*|for\s+repetition|as)?$/is;
  my ($before, $parameters) = GetStatement($rout) =~ /\A\s*((?:create\s+(?:procedure|function|proc|func)\s+)?$ROUTINE_NAME_PATTERN\s*)(.*?)(?:\bwith\b.*|for\s+repetition|as)?$/is;

  if ( ! defined $before ) {
    print "[addCommentParamToCheck] WARNING : ".GetStatement($rout)." not recognized as a routine ...\n";
    return;
  }

  $currentLine += () = $before =~ /\n/g ;
  if ( $parameters =~ /\A\s*\(/s) {
    #($before, $parameters) = $parameters =~ /\A(\s*\(\s*)(.*)\)[^\)]*$/s;
    my ($r_param, $r_rest) = CountUtil::splitAtPeer(\$parameters, "(", ")");
    if (defined $r_param ) {
      ($before, $parameters) = $$r_param =~ /\A(\s*\(\s*)(.*)\)$/s;
      $currentLine += () = $before =~ /\n/g ;
    }
    else {
      $parameters = ""; 
    }
  }

  my @Params = split (',', $parameters);

    # ANALYZE EACH PARAMETER ...
    for my $param (@Params) {
	
      # skip empty param (due to enexpected tailing coma ...)
      next if ($param !~ /\S/);

      $nb_TotalParameters++;

#print "PARAM = $param\n";
      # Check if commented...
      my ($BeginningPadding) = $param =~ /\A(\s*)\S/s ;
      my $currentParamLine = $currentLine;
      $currentParamLine += () = $BeginningPadding =~ /(\n)/g ;

      my $beginLine = $currentParamLine-$COMMENT_ZONE_BEFORE_PARAM;
      if ($beginLine < $artifactLine) {
        $beginLine = $artifactLine;
      }

      push @{$r_TabToCheck}, [$beginLine, $currentParamLine,  \&ptr_checkUnCommentedParameter ];

      $currentLine += () = $param =~ /(\n)/g ;
    }

}


sub CountRoutineComment($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_UnCommentedRoutine = 0;
  $nb_UnCommentedParameters = 0;
  $nb_TotalParameters = 0;

  if ( ! defined $vue->{'agglo'} ) {
    $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedRoutine__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret;
  }

  if ( ! defined $vue->{'structured_code'} ) {
    $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedRoutine__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_TotalParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret;
  }

  my $ArtifactsView =  $vue->{'routines'} ;
  if ( ! defined $ArtifactsView )
  {
    $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedParameters__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $nb_UnCommentedParameters = Erreurs::COMPTEUR_ERREUR_VALUE ;
    $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }


  my $root = $vue->{'structured_code'};

  my @Procs = GetNodesByKind( $root, ProcedureKind);
  my @Funcs = GetNodesByKind( $root, FunctionKind);
  #my @Triggs = GetNodesByKind( $root, TriggerKind);

  my @Routines = (@Procs, @Funcs);

  my @TabToCheck = ();
  # For ALL routines 
  for my $rout (@Routines) {

     my $routName = GetName($rout) ;
     my $artifactLine = GetLine($rout);

     # prepare zones to check for routines commments
     my $beginLine = $artifactLine-$SIZE_COMMENT_ZONE_BEFORE_ROUTINE;
     if ($beginLine < 1) { $beginLine = 1;}
     push @TabToCheck, [$beginLine, $artifactLine-1, \&ptr_checkUnCommentedRoutine];

     # prepare zones to check for parameters commments
     addCommentParamToCheck($rout, \@TabToCheck);


  }

  # Check comments in the pre-defined zones ...
  CountUtil::checkComment(\$vue->{'agglo'}, \@TabToCheck);

  $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedRoutine__mnemo, $nb_UnCommentedRoutine );
  $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedParameters__mnemo, $nb_UnCommentedParameters );
  $ret |= Couples::counter_add($compteurs, $Nbr_TotalParameters__mnemo, $nb_TotalParameters );
  return $ret;
} 



sub CountViewComment($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_UnCommentedViews = 0;

  if ( ! defined $vue->{'agglo'} ) {
    $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedViews__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret;
  }

  if ( ! defined $vue->{'structured_code'} ) {
    $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedViews__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret;
  }

  my $ArtifactsView =  $vue->{'routines'} ;
  if ( ! defined $ArtifactsView )
  {
    $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedViews__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $root = $vue->{'structured_code'};

  my @Creates = GetNodesByKind( $root, CreateKind);

  my @TabToCheck = ();
  # For ALL Create nodes ... 
  for my $create (@Creates) {
    my $tag = GetName($create);
    if (exists $ArtifactsView->{$tag}) {
      # If it is a Create View node ...
      if ($ArtifactsView->{$tag} =~ /\A\s*create\s+view\b/i ) {
        my $artifactLine = GetLine($create);
        # Check if there is a comment before the artifact.     
	

        # prepare zones to check for create table commments
        my $beginLine = $artifactLine-$SIZE_COMMENT_ZONE_BEFORE_VIEW;
        if ($beginLine < 1) { $beginLine = 1;}
	push @TabToCheck, [$beginLine, $artifactLine-1, \&ptr_checkUnCommentedViews];
      }
    }
  }
  # Check comments in the pre-defined zones ...
  CountUtil::checkComment(\$vue->{'agglo'}, \@TabToCheck);

  $ret |= Couples::counter_add($compteurs, $Nbr_UnCommentedViews__mnemo, $nb_UnCommentedViews );
  return $ret;
}

1;



