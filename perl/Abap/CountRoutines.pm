

package Abap::CountRoutines;
# Module du comptage TDB: Nombre de procedures internes non referencees.

use strict;
use warnings;

use Lib::Node;
use Abap::AbapNode;

use Erreurs;

use Ident;

my $ARTIFACT_MAX_LENGTH = 100;
my $ComplexArtifact__THRESHOLD = 20;
my $ARTIFACT_MAX_DEPTH = 5;

my $ProcedureImplementations__mnemo = Ident::Alias_ProcedureImplementations();
my $FunctionImplementations__mnemo = Ident::Alias_FunctionImplementations();
my $MethodImplementations__mnemo = Ident::Alias_MethodImplementations();
my $ModuleImplementations__mnemo = Ident::Alias_ModuleImplementations();
my $LongArtifact__mnemo = Ident::Alias_LongArtifact();
my $ComplexArtifact__mnemo = Ident::Alias_ComplexArtifact();
my $EmptyArtifact__mnemo = Ident::Alias_EmptyArtifact();
my $BadFunctionNames__mnemo = Ident::Alias_BadFunctionNames();
my $TooDepthArtifact__mnemo = Ident::Alias_TooDepthArtifact();
my $UsingByValuePassing_Forms__mnemo = Ident::Alias_UsingByValuePassing_Forms();

my $nb_ProcedureImplementations = 0;
my $nb_FunctionImplementations = 0;
my $nb_MethodImplementations = 0;
my $nb_ModuleImplementations = 0;
my $nb_LongArtifact = 0;
my $nb_ComplexArtifact = 0;
my $nb_EmptyArtifact = 0;
my $nb_BadFunctionNames = 0;
my $nb_TooDepthArtifact = 0;
my $nb_UsingByValuePassing_Forms = 0;


sub IsLongArtifact($$) {
  my $artifactView = shift;
  my $artifact = shift;

  my $artiKey = buildArtifactKeyByNode($artifact);

  my $n = () = $artifactView->{$artiKey} =~ /\S[^\n]*(\n|\Z)/smgo;
  my $n_decl = () = ${GetStatement($artifact)} =~ /\S[^\n]*(\n|\Z)/smgo;

  #do not count the EndArtifact Instruction ...
  #$n-- ; 

  # COUNT : declareation instruction + content + EndArtifact instruction.
  #    method xxx.
  #      content
  #    endmethod

#print "ARTIFACT : $artiKey ==> length = $n\n";

  if ( ($n + $n_decl) > $ARTIFACT_MAX_LENGTH) {
#print "===> [".GetName($artifact)."] Violement !!! (".($n + $n_decl).") LOC\n";
    return 1;
  }
  else {
    return 0;
  }
}

sub getNodeDepth($) ;

sub getNodeDepth($) 
{
  my $node = shift;
  my $ret = 0;

  my $Children = Abap::AbapNode::GetChildren($node);

  my $depth = 0;
  for my $child (@{$Children}) {
    my $d = getNodeDepth($child);
    if ( $d > $depth ) {
      $depth = $d;
    }
  }

  my $kind = Abap::AbapNode::GetKind($node);
  if ( ($kind eq IfKind) || ($kind eq DoKind) || ($kind eq LoopKind) || ($kind eq WhileKind) || ($kind eq ProvideKind) || ($kind eq CaseKind)
	  # "elsif" & "else" are child of "if" in the tree representation. So they don't introduce an
	  #  additional depth level, because they should be considered as same level than the "if".
	  #  || ($kind eq ElsifKind) || ($kind eq ElseKind)
      ) {
    $depth++;
  }

  return $depth;
}

# Cyclomatic complexity for a program with multiple exit points is :
#
#    p + 1      with single exit point
#
#    that could be extended to :
#    p - s + 2  with multiple exit points
#
# where :
#     p is the number of decision points in the program,
#     s is the number of exit points.

sub IsComplexArtifact($$) 
{
  my $artifact = shift;
  my $ArtifactsView = shift ;
  my $ret = 0;
  my $name = GetName($artifact) ;

  my $artiKey = buildArtifactKeyByNode($artifact);

  my $content = $ArtifactsView->{$artiKey};

  if (! defined $content) {
    print "WARNING : no content for artifact $name\n";
    return 0;
  }
  # Count p
  my $p = () = $content =~ /(?:\A|\.)\s*(if|elseif|while|do|loop|when|try|catch)\b/isg;
  # Count s
  my $s = () = $content =~ /(?:\A|\.)\s*(?:return)\b/isg;
  if ($s == 0) {
    # if no "return" instruction, then count at least the default exit at end of the
    # routine.
    $s= 1;
  }

  if ( ($p-$s+2) > $ComplexArtifact__THRESHOLD) {
    return 1;
  }
  else {
    return 0;
  }
}

sub IsEmptyArtifact($) 
{
  my $artifact = shift;
  my $ret = 0;

  my $FirstChild = Abap::AbapNode::GetChildren($artifact)->[0];

  if ( defined $FirstChild ) {
    if ( IsKind($FirstChild, EndFormKind) ||
         IsKind($FirstChild, EndModuleKind) ||
         IsKind($FirstChild, EndFunctionKind) ||
         IsKind($FirstChild, EndMethodKind) ) {
      $ret = 1;
    }
  }

  return $ret;
}

sub CountRoutines($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;
  $nb_ProcedureImplementations = 0;
  $nb_FunctionImplementations = 0;
  $nb_MethodImplementations = 0;
  $nb_ModuleImplementations = 0;
  $nb_LongArtifact = 0;
  $nb_ComplexArtifact = 0;
  $nb_EmptyArtifact = 0;
  $nb_BadFunctionNames = 0;
  $nb_TooDepthArtifact = 0;
  $nb_UsingByValuePassing_Forms = 0;

  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $ProcedureImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $FunctionImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $MethodImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ModuleImplementations__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $BadFunctionNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $LongArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ComplexArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $EmptyArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $UsingByValuePassing_Forms__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $TooDepthArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $artifactView = $vue->{'artifact'};
  if ( ! defined $artifactView ) {
    $ret |= Couples::counter_add($compteurs, $LongArtifact__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
  }

  #============ ROUTINES ARTIFACTS =================

  my @Procs = GetNodesByKind( $root, FormKind);
  my @Funcs = GetNodesByKind( $root, FunctionKind);
  my @Meths = GetNodesByKind( $root, MethodKind);
  my @Mods = GetNodesByKind( $root, ModuleKind);
  my @Sects = GetNodesByKind( $root, SectionKind);

  my @Artifacts = (@Procs, @Funcs, @Meths, @Mods, @Sects);

  # Count nb routines ...
  $nb_ProcedureImplementations += scalar @Procs; 
  $nb_FunctionImplementations += scalar @Funcs;  
  $nb_MethodImplementations += scalar @Meths; 
  $nb_ModuleImplementations += scalar @Mods; 

  for my $form ( @Procs) {
    if ( ${GetStatement($form)} =~ /\bvalue\b/is ) {
      $nb_UsingByValuePassing_Forms++;
    }
  }

  for my $artif ( @Artifacts) {

    if (!IsKind($artif, SectionKind)) {
      $nb_EmptyArtifact += IsEmptyArtifact($artif);
    }

    if ( defined $artifactView ) {
      if (!IsKind($artif, SectionKind)) {
        $nb_LongArtifact += IsLongArtifact($artifactView, $artif);
      }
      $nb_ComplexArtifact += IsComplexArtifact($artif, $artifactView);
      if (getNodeDepth($artif) > $ARTIFACT_MAX_DEPTH ) {
        $nb_TooDepthArtifact ++;
      }
    }
  }

  for my $func (@Funcs) {
    if (GetName($func) =~ /\A[^Z]/ ) {
      $nb_BadFunctionNames++;
    }
  }

  $ret |= Couples::counter_add($compteurs, $ProcedureImplementations__mnemo, $nb_ProcedureImplementations );
  $ret |= Couples::counter_add($compteurs, $FunctionImplementations__mnemo, $nb_FunctionImplementations );
  $ret |= Couples::counter_add($compteurs, $MethodImplementations__mnemo, $nb_MethodImplementations );  
  $ret |= Couples::counter_add($compteurs, $ModuleImplementations__mnemo, $nb_ModuleImplementations );  
  $ret |= Couples::counter_add($compteurs, $LongArtifact__mnemo, $nb_LongArtifact );  
  $ret |= Couples::counter_add($compteurs, $ComplexArtifact__mnemo, $nb_ComplexArtifact );  
  $ret |= Couples::counter_add($compteurs, $EmptyArtifact__mnemo, $nb_EmptyArtifact );  
  $ret |= Couples::counter_add($compteurs, $BadFunctionNames__mnemo, $nb_BadFunctionNames );  
  $ret |= Couples::counter_add($compteurs, $TooDepthArtifact__mnemo, $nb_TooDepthArtifact );  
  $ret |= Couples::counter_add($compteurs, $UsingByValuePassing_Forms__mnemo, $nb_UsingByValuePassing_Forms );  
}



1;



