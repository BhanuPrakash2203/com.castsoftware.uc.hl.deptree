

package PL1::CountDeclare;
# Module du comptage TDB: Nombre de procedures internes non referencees.

use strict;
use warnings;

use PL1::PL1Node;
use Lib::NodeUtil;

use Erreurs;
use CountUtil;
use Ident;

my $Declare__mnemo = Ident::Alias_Declare();
my $ImpreciseNumericDeclaration__mnemo = Ident::Alias_ImpreciseNumericDeclaration();
my $RepeatInVarInit__mnemo = Ident::Alias_RepeatInVarInit();

my $nb_Declare=0;
my $nb_ImpreciseNumericDeclaration=0;
my $nb_RepeatInVarInit=0;


sub CountDeclare($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_Declare=0;
  $nb_ImpreciseNumericDeclaration=0;
  $nb_RepeatInVarInit=0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $Declare__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ImpreciseNumericDeclaration__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $RepeatInVarInit__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  
  my @Dcls = Lib::NodeUtil::GetNodesByKind( $root, DeclareKind);

  $nb_Declare = scalar @Dcls;

  # For ALL Declaration 
  for my $dcl (@Dcls) {

    my $statement = ${GetStatement($dcl)} ;

    if ( $statement =~ /\b(FIXED|FLOAT)\b/is ) {
      if ( $statement !~ /\b(BIN|BINARY|DEC|DECIMAL)\b/is ) {
	$nb_ImpreciseNumericDeclaration++;
      }
    }

    if ( $statement =~ /\b(BIN|BINARY|DEC|DECIMAL)\b/is ) {
      if ( $statement !~ /\b(FIXED|FLOAT)\b/is ) {
	$nb_ImpreciseNumericDeclaration++;
      }
    }

    if ( $statement =~ /\b(?:init|initial|value)\s*(\(.*)/is ) {
       my $init_expr = $1;
       my ($init_content, $after) = CountUtil::splitAtPeer(\$init_expr, '(', ')');
       if (( defined $init_content) && ( $$init_content =~ /\brepeat\b/is )) {
         $nb_RepeatInVarInit++;
       }
    }
  }


  $ret |= Couples::counter_add($compteurs, $Declare__mnemo, $nb_Declare );
  $ret |= Couples::counter_add($compteurs, $ImpreciseNumericDeclaration__mnemo, $nb_ImpreciseNumericDeclaration );
  $ret |= Couples::counter_add($compteurs, $RepeatInVarInit__mnemo, $nb_RepeatInVarInit );

  return $ret;
}

1;



