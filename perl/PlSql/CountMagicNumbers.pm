#------------------------------------------------------------------------------#
#                         @ISOSCOPE 2008                                       #
#------------------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                          #
#               Adresse : TERSUD - Bat A                                       #
#                         5, AVENUE MARCEL DASSAULT                            #
#                         31500  TOULOUSE                                      #
#               SIRET   : 410 630 164 00037                                    #
#------------------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                                #
# l'Institut National de la Propriete Industrielle (lettre Soleau)             #
#------------------------------------------------------------------------------#

package PlSql::CountMagicNumbers;
# les modules importes
use strict;
use warnings;
use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;
use Erreurs;

my $mnemo_MagicNumbers = Ident::Alias_MagicNumbers();

# prototypes publics
sub CountMagicNumbers($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des Magic Number. 
#-------------------------------------------------------------------------------
sub _CountMagicNumbersInBuffer($) 
{
  my ($statement) = @_ ;

  my $code = $statement;

  # Suppression des declarations 'const' ou 'final' (en java, c et c++)
  #$code =~ s/[\n;][ \t]*\b(const|final)\b[^=\{]*=[^;]*//sg;

  # Suppression des magic numbers toleres flottants
  $code =~ s/(\G|[^\w])0*[01]?\.0*d?([^\w])/$1---$2/sg; # 0.0, 1.0, 0. 1. .0
  # Suppression des magic numbers toleres entiers
  $code =~ s/(\G|[^\w])0*[01]d?([^\w])/$1---$2/sg; # 0, 1

  my $nbr_MagicNumbers = 0;

  # reconnaissance des magic numbers :
  # 1) identifiants commencant forcement par un chiffre decimal.
  # 2) peut contenir des '.' (flottants)
  # 3) peut contenir des 'E' ou 'e' suivis eventuellement de '+/-' pour les flottants
  while ( $code =~ /[^\w\$%]((?:\d|\.\d)(?:[Ee][+-]?\d|[\w\.])*)/sg )
  {
    my $number = $1 ;
    my $match = $1 ; # traces_filter_line

    # suppression du 0 si le nombre commence par 0.
    $number =~ s/^0*(.)/$1/;

    # Si la donnee trouvee n'est pas un simple chiffre, alors ce n'est pas un magic number tolere ...
    #if ($number !~ /^\d$/ ) {

      Erreurs::LogInternalTraces('trace', undef, 1, $mnemo_MagicNumbers, $match);
      $nbr_MagicNumbers++;

    #}
  };
  return $nbr_MagicNumbers;
}





sub _callbackNode($$)
{
  my ( $node, $context )= @_;
  my $statement = Lib::NodeUtil::GetStatement($node);
  return undef if not defined $statement;
  $statement = lc ($statement);
  if ( $statement !~ m/\bconstant\b/sm )
  {
      $context->[0] += _CountMagicNumbersInBuffer($statement);
  }
  return undef;
}


# Routine point d'entree du module.
sub CountMagicNumbers($$$) 
{
  my (undef, $vue, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;
  my $mnemo = $mnemo_MagicNumbers;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  my @context = ( 0, 0 );
  
  #my @executiveNodes = GetNodesByKind( $root, ExecutiveKind);
  #for my $node ( @executiveNodes )
  {
    Lib::Node::Iterate($root, 0, \&_callbackNode, \@context);
  }
  my $nb = $context[0];

  $ret |= Couples::counter_add($compteurs, $mnemo, $nb);

  return $ret;
}

1;
