

package TSql::CountSQL_DDL_DML;
# Module du comptage TDB: Nombre de procedures internes non referencees.

use strict;
use warnings;

use TSql::Node;
use TSql::TSqlNode;

use TSql::ParseDetailed;

use Erreurs;

use Ident;

my $DEBUG=1;

my $Nbr_Bad_DDL_DML_Interleaving__mnemo = Ident::Alias_Bad_DDL_DML_Interleaving();
my $Nbr_DBUsedObjects__mnemo = Ident::Alias_DBUsedObjects();

my $nb_Bad_DDL_DML_Interleaving = 0;
my $nb_DBUsedObjects = 0;

sub BADLY_USED {return -1} ;
sub USE_CREATE {return 0} ;
sub USE_INSERT {return 1} ;
sub USE_ALTER {return 2} ;
sub USE_UPDATE {return 2} ;
sub USE_CREATE_INDEX {return 2} ;
sub USE_SELECT {return 3} ;
sub USE_DROP {return 4} ;

my %Tab_Objects = ();

sub _cb_compute_UseOfObject($$;$)
{
  my ($node, $context, $level) = @_;
  my $use;
  my @objects=();
  if ( IsKind($node, CreateKind)) {
    if ( ${GetStatement($node)} =~ /\A\s*\b(?:view|table)\b\s+([#.\w]+)/isg ) {
#print "OBJECT CREATE: $1\n";
      $use = USE_CREATE;
      push @objects, $1;
    }
    elsif ( ${GetStatement($node)} =~ /\A\s*\w*\s*\bindex\b.*?\bON\b\s+([#.\w]+)/isg ) {
#print "OBJECT INDEX: $1\n";
      $use = USE_CREATE_INDEX;
      push @objects, $1;
    }
  } 
  elsif ( IsKind($node, InsertKind)) {
    if ( ${GetStatement($node)} =~ /\binto\b\s+([#.\w]+)/isg ) {
#print "OBJECT INSERT: $1\n";
      $use = USE_INSERT;
      push @objects, $1;
    }
  }
  elsif ( IsKind($node, SQLKind)) {
    if ( ${GetStatement($node)} =~ /\A\s*\bupdate\b\s+([#.\w]+)/isg ) {
#print "OBJECT UPDATE: $1\n";
      $use = USE_UPDATE;
      push @objects, $1;
    }
  }
  elsif ( IsKind($node, DropKind)) {
    if ( ${GetStatement($node)} =~ /\btable\b\s+([#.\w]+)/isg ) {
#print "OBJECT DROP: $1\n";
      $use = USE_DROP;
      push @objects, $1;
    }
  }
  elsif ( IsKind($node, SelectKind)) {
    my $artifact = GetName($node);
#print "SELECT artifact = $artifact\n";
      $use = USE_SELECT;
      @objects = @{TSql::ParseDetailed::get_ObjectsList($artifact)};
  }

  for my $object (@objects) {

    $nb_DBUsedObjects++;

    if ( (exists $Tab_Objects{$object}) && ( $Tab_Objects{$object} != BADLY_USED)) {
      if ( $use >= $Tab_Objects{$object}) {
        $Tab_Objects{$object} = $use;
      }
      else {
#print "------------------------BAD USE !!!!!\n";
        $nb_Bad_DDL_DML_Interleaving++;
        $Tab_Objects{$object} = BADLY_USED;
      }
    }
    else {
      $Tab_Objects{$object} = $use;
    }
  }

  return undef;
}


sub CountSQL_DDL_DML($$$) 
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_Bad_DDL_DML_Interleaving = 0;
  $nb_DBUsedObjects = 0;


my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $Nbr_Bad_DDL_DML_Interleaving__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_DBUsedObjects__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  $NomVueCode = 'routines' ; 
  my $ArtifactsView =  $vue->{$NomVueCode} ;
  if ( ! defined $ArtifactsView )
  {
    $ret |= Couples::counter_add($compteurs, $Nbr_Bad_DDL_DML_Interleaving__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $Nbr_DBUsedObjects__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @Procs = GetNodesByKind( $root, ProcedureKind);
  my @Funcs = GetNodesByKind( $root, FunctionKind);

  my @ProcsFuncs =  (@Procs, @Funcs);

  for my $rout (@ProcsFuncs) {
    my @context = ();
    TSql::Node::Iterate($rout, 0, \&_cb_compute_UseOfObject, \@context);
  }

  $ret |= Couples::counter_add($compteurs, $Nbr_Bad_DDL_DML_Interleaving__mnemo, $nb_Bad_DDL_DML_Interleaving );
  $ret |= Couples::counter_add($compteurs, $Nbr_DBUsedObjects__mnemo, $nb_DBUsedObjects );

  return $ret;
}

1;



