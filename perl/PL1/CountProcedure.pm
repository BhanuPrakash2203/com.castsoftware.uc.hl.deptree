

package PL1::CountProcedure;
# Module du comptage TDB: Nombre de procedures internes non referencees.

use strict;
use warnings;

use PL1::PL1Node;
use Lib::NodeUtil;

use Erreurs;

use Ident;

sub CountUnrefInternalProc($);
sub CountProcedure($$$);
sub CountWithoutTitleFetch($$$);

my $SHORT_FUNCTION_NAME_LT__LIMIT = 7;
my $SHORT_FUNCTION_NAME_HT__LIMIT = 10;

my $Procedure__mnemo = Ident::Alias_FunctionMethodImplementations();
my $ShortProcNameLT__mnemo = Ident::Alias_ShortFunctionNamesLT();
my $ShortProcNameHT__mnemo = Ident::Alias_ShortFunctionNamesHT();
my $UnrefInternalProc__mnemo = Ident::Alias_UnrefInternalProc();
my $Fetch__mnemo = Ident::Alias_Fetch();
my $WithoutTitleFetch__mnemo = Ident::Alias_WithoutTitleFetch();
my $BadMainProcedureName__mnemo = Ident::Alias_BadMainProcedureName();
my $MissingOnError__mnemo = Ident::Alias_MissingOnError();

my $nb_Procedure = 0;
my $nb_ShortProcNameLT = 0;
my $nb_ShortProcNameHT = 0;
my $nb_UnrefInternalProc = 0;
my $nb_Fetch = 0;
my $nb_WithoutTitleFetch = 0;
my $nb_BadMainProcedureName = 0;
my $nb_MissingOnError = 0;

# FIXME : there is a known limitation :
#         if too internal routines reference each other, but none of them is 
#         referenced in the main proc, then they are both unreferenced internals
#         whereas the current algo will not found that ...


sub _cbUnrefInternalProc($$) {
  my ($node, $context) = @_;
  if ( $node == $context->[1] )
  {
    # The call to an internal routine should not be searched in the internal
    # routine itself ...
    return 0;  # to say to the iterator not analysing subnodes.
  }

  my $name = GetName($context->[1]);
  if ( ${GetStatement($node)} =~ /\b${name}\b/ ) {
    $context->[0] = 1;
    # if found, no need to analyze child node ...
    return 0
  }
  return undef;
}

sub CountUnrefInternalProc($) {
  my ($procNode) = @_ ;

      my %calledProc = ();
      my $nb_Unref = 0;

      #search for internal proc ...
      my @Procs = Lib::NodeUtil::GetNodesByKind( $procNode, ProcedureKind);
      for my $proc (@Procs) {
	 my $name = GetName($proc);

	 my @list = ();
         my @context = ( 0, $proc);
	 # For Each node of the top main proc being analyzed, search fo
	 # a call to the internal proc
	 # $context[0] is 0 if such call not found, 1 else.
	 # $context[1] is the node of the internal procedure...
         Lib::Node::Iterate ($procNode, 0, \&_cbUnrefInternalProc, \@context);
         if (! $context[0]) {
           $nb_Unref++;
	 }
      }
      return $nb_Unref;
}


sub CountProcedure($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_Procedure = 0;
  $nb_ShortProcNameLT = 0;
  $nb_ShortProcNameHT = 0;
  $nb_UnrefInternalProc = 0;
  $nb_BadMainProcedureName = 0;
  $nb_MissingOnError = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = Ident::Alias_UnrefInternalProc();

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
  $ret |= Couples::counter_add($compteurs, $Procedure__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ShortProcNameLT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ShortProcNameHT__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $BadMainProcedureName__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $MissingOnError__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Procs = Lib::NodeUtil::GetNodesByKind( $root, ProcedureKind);

  # Count nb procedures ...
  $nb_Procedure += scalar @Procs ; 

  # For ALL procedure 
  for my $proc (@Procs) {

     my $procName = GetName($proc) ;

     # CHECK name length
     if ( length($procName) < $SHORT_FUNCTION_NAME_LT__LIMIT ) {
       $nb_ShortProcNameLT++;
     }
     if ( length($procName) < $SHORT_FUNCTION_NAME_HT__LIMIT ) {
        $nb_ShortProcNameHT++;
     }

     # Specific treatment for "main" procedure :
     $nb_UnrefInternalProc += CountUnrefInternalProc($proc);

     if ( ${GetStatement($proc)} =~ /\bmain\b/si ) {

       # Check if the procedure name complies with the file name ...
       my $filename = $fichier;
       $filename =~ s/.*[\/\\]//;
       $filename =~ s/\.(?:pli|plc)$//si ;

       if ( $procName ne $filename ) {
         $nb_BadMainProcedureName++;
       }

       # check the procedure has an "ON ERROR" statement...
       # FIXME : the seach could be limited to the first level nodes of
       #         the main proc in order to ensure it will be Fully reachable. 
       my @Ons = Lib::NodeUtil::GetNodesByKind( $proc, OnKind);
       my $on_error_declared=0;
       for my $on (@Ons) {
         if (GetName($on) =~ /\berror\b/ ) {
           $on_error_declared++;
	 }
       }
       if ( ! $on_error_declared) {
         $nb_MissingOnError++;
       }
     } # End specific end treatment.

  }
  $ret |= Couples::counter_add($compteurs, $UnrefInternalProc__mnemo, $nb_UnrefInternalProc );

  $ret |= Couples::counter_add($compteurs, $Procedure__mnemo, $nb_Procedure );
  $ret |= Couples::counter_add($compteurs, $ShortProcNameLT__mnemo, $nb_ShortProcNameLT );
  $ret |= Couples::counter_add($compteurs, $ShortProcNameHT__mnemo, $nb_ShortProcNameHT );
  $ret |= Couples::counter_add($compteurs, $BadMainProcedureName__mnemo, $nb_BadMainProcedureName );
  $ret |= Couples::counter_add($compteurs, $MissingOnError__mnemo, $nb_MissingOnError );

  return $ret;
}

sub CountWithoutTitleFetch($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_Fetch = 0;
  $nb_WithoutTitleFetch = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $Fetch__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $WithoutTitleFetch__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Fetches = Lib::NodeUtil::GetNodesByKind( $root, FetchKind);

  $nb_Fetch = scalar @Fetches ;

  # For ALL Fetches
  for my $fetch (@Fetches) {

     my $statement = ${GetStatement($fetch)} ;

     if ( $statement =~ /\bfetch\b(.*)/is ) {
       my $params = $1;
       if ($params !~ /\btitle\b/is ) {
	 # FETCH instruction does not have TITLE option : it's a violation.
         $nb_WithoutTitleFetch += 1;
       }
     }
  }
  $ret |= Couples::counter_add($compteurs, $Fetch__mnemo, $nb_Fetch );
  $ret |= Couples::counter_add($compteurs, $WithoutTitleFetch__mnemo, $nb_WithoutTitleFetch );

  return $ret;
}

1;



