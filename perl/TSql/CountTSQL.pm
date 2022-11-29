

package TSql::CountTSQL;
# Module du comptage TDB: Nombre de procedures internes non referencees.

use strict;
use warnings;

use TSql::Node;
use TSql::TSqlNode;

use Erreurs;

use Ident;

my $Nbr_FetchInLoop__mnemo = Ident::Alias_FetchInLoop();

my $nb_FetchInLoop = 0;


sub CountItem($$$$)
{
    my ($item, $mnemo_Item, $code, $compteurs) = @_ ;
    my $status = 0;

    if (!defined $$code )
    {
        $status |= Couples::counter_add($compteurs, $mnemo_Item, Erreurs::COMPTEUR_ERREUR_VALUE);
        $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
        return $status;
    }

    my $nbr_Item = () = $$code =~ /\b${item}\b/isg;
    $status |= Couples::counter_add($compteurs, $mnemo_Item, $nbr_Item);

    return $status;
}


sub CountKeywords($$$)
{
    my ($fichier, $vue, $compteurs) = @_ ;
    my $status = 0;

    my $code = $vue->{'code_without_directive'};

    $status |= CountItem('goto',             Ident::Alias_Goto(),  \$code, $compteurs);
    $status |= CountItem('truncate\s+table', Ident::Alias_TruncateTable(),  \$code, $compteurs);
    $status |= CountItem('group\s+by',       Ident::Alias_SQLGroupby(),  \$code, $compteurs);
    $status |= CountItem('order\s+by',       Ident::Alias_SQLOrderBy(),  \$code, $compteurs);
    $status |= CountItem('where',       Ident::Alias_SQLWhere(),  \$code, $compteurs);
    $status |= CountItem('while',       Ident::Alias_While(),  \$code, $compteurs);
    $status |= CountItem('break',       Ident::Alias_Break(),  \$code, $compteurs);
    $status |= CountItem('Continue',       Ident::Alias_Continue(),  \$code, $compteurs);
    $status |= CountItem('if',       Ident::Alias_If(),  \$code, $compteurs);
    $status |= CountItem('create\s+view',       Ident::Alias_SQLDeclareView(),  \$code, $compteurs);
    $status |= CountItem('insert',       Ident::Alias_Sql_Insert(),  \$code, $compteurs);
    $status |= CountItem('create\s+table',       Ident::Alias_SQLDeclareTable(),  \$code, $compteurs);
    $status |= CountItem('begin\s+try',       Ident::Alias_Try(),  \$code, $compteurs);
    $status |= CountItem('begin\s+catch',       Ident::Alias_Catch(),  \$code, $compteurs);
    $status |= CountItem('from',       Ident::Alias_From(),  \$code, $compteurs);
    #$status |= CountItem('create\s+(?:UNIQUE|CLUSTERED|NONCLUSTERED)?\s+Index',       'Nbr_SQLDeclareIndex',  \$code, $compteurs);

    return $status;
}

sub CountFetchInLoop($$$)
{
  my ($fichier, $vue, $compteurs) = @_ ;
  my $ret = 0;
  my $nb_FetchInLoop = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $Nbr_FetchInLoop__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @Loops = GetNodesByKind( $root, LoopKind);

  for my $loop (@Loops) {
    if ( TSql::TSqlNode::IsContainingKind($loop, FetchKind) ) {
      $nb_FetchInLoop++;
    }
  }

  $ret |= Couples::counter_add($compteurs, $Nbr_FetchInLoop__mnemo, $nb_FetchInLoop );
  return $ret;

}
  
sub CountVG($$$$)
{
    my $status;
    my $nb_VG = 0;
    my $VG__mnemo = Ident::Alias_VG();
    my ($fichier, $vue, $compteurs, $options) = @_;

    if (  ( ! defined $compteurs->{Ident::Alias_If()}) ||
	  ( ! defined $compteurs->{Ident::Alias_While()}) || 
	  ( ! defined $compteurs->{Ident::Alias_Try()}) || 
	  ( ! defined $compteurs->{Ident::Alias_Catch()}) || 
	  ( ! defined $compteurs->{Ident::Alias_ProcedureImplementations()}) ||
	  ( ! defined $compteurs->{Ident::Alias_FunctionImplementations()}) ||
	  ( ! defined $compteurs->{Ident::Alias_TriggerImplementations()}) )
    {
      $nb_VG = Erreurs::COMPTEUR_ERREUR_VALUE;
    }
    else {
      $nb_VG = $compteurs->{Ident::Alias_If()} +
	       $compteurs->{Ident::Alias_While()} +
	       $compteurs->{Ident::Alias_Try()} +
	       $compteurs->{Ident::Alias_Catch()} +
	       $compteurs->{Ident::Alias_ProcedureImplementations()} +
	       $compteurs->{Ident::Alias_FunctionImplementations()} +
	       $compteurs->{Ident::Alias_TriggerImplementations()};
    }

    $status |= Couples::counter_add($compteurs, $VG__mnemo, $nb_VG);
}



1;



