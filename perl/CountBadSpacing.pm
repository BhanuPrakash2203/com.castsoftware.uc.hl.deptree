#----------------------------------------------------------------------#
#                 @ISOSCOPE 2008                                       #
#----------------------------------------------------------------------#
#       Auteur  : ISOSCOPE SA                                          #
#       Adresse : TERSUD - Bat A                                       #
#                 5, AVENUE MARCEL DASSAULT                            #
#                 31500  TOULOUSE                                      #
#       SIRET   : 410 630 164 00037                                    #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Plugin

package CountBadSpacing;

# les modules importes
use strict;
use warnings;
use Erreurs;

# prototypes publics
sub CountBadSpacing($$$$);

sub _countBadSpacing($$) {
  my $code = shift;
  my $ops = shift;
  my $left = '';
  my $right = '';
  my $lspace = '' ;
  my $op = '';
  my $rspace = '' ;
  my $nb_violations = 0;

  $$code =~ s/(\+\+|--)//sg;

  # Suppression des + et - unaires (optimisation des performances pour certains types de fichier qui declarent beaucoup de donnees ... )
  # On garde les espaces presents avant l'operateur unaire, mais on supprime ceux apres cet operateur,
  # sinon ca perturbe le resultat concernant l'operateur avant l'operateur unaire.
  # Attention: ne sont supprimes que les espaces ou tablulations, pas les retour a la ligne.
  $$code =~ s/((?:=|\(|\{|\+|\-|\*|\/|<|>|,)\s*)(?:-|\+)[\ \t]*/$1/sg;

  while ( $$code =~ /\G(.*?)($$ops)([\s]*)([^\s])/sg ) {

    $op = $2;
    $rspace = $3;
    $right = $4;

    my $match = $1 . $2 . $3 . $4;

    # $1 contient ce qu'il y avait devant (i.e. a gauche de) l'operateur.
    #   -> $lspace doit etre positionne a \s si le dernier caractere de $1 est un \s, et a '' sinon.
    #   -> $left doit etre positionne a la valeur du dernier caractere de $1 qui ne soit pas un espace.
    my $templeft=$1;
    if ($templeft eq '' ) {
      # si rien n'est matche devant l'operateur, alors il n'y a pas d'espaces ($lspace='') et $left vaut le $right de l'iteration precedente.
      $lspace = '';
    }
    else {
      # Sinon, $lspace prend la valeur du dernier caractere du pattern.
      $lspace = substr($templeft, -1, 1);

      # Si $lspace est bien un espace ...
      if ( $lspace =~ /\s/ ) {
        my $i = -2;
        my $l = length($templeft);
        while ( ($l+$i>=0) && ( ($left=substr($templeft, $i, 1)) =~ /\s/) ) {
          $i--;
        }
      }
      else {
        $left=$lspace;
        $lspace = '';
      }
    }

     # Si l'un des deux cote de l'operateur n'est pas un espace...
     if ( ($lspace =~ /[^\s]/sg) || ($rspace =~ /[^\s]/sg ) || ($lspace eq '' ) || ($rspace eq '' ) ) {

       # Si l'operateur est '-'
       if (($op eq '-') || ($op eq '+')) {
         # Si ce n'est pas l'operateur 'signe moins' ou 'signe plus', alors l'absence d'espace est un defaut.
         # RQ: si le signe '-' ou '+' est colle a droite d'un des operateur ci-dessous, alors ils s'agit bien du moins unaire...
         if (( $left =~ /[^=\(\{\+\*\/<>]/ ) && ($right =~ /[^>]/) ) {
           $nb_violations++;
#print "[BadSpacing] $match\n";
         }
       }
       # Sinon c'est un defaut...
       else {
         $nb_violations++;
#print "[BadSpacing] $match\n";
       }
     }
     $left=$right;
  }
  return $nb_violations;
}

sub _countBadSpacing_1($$) {
  my $code = shift;
  my $ops = shift;
  my $left = '';
  my $right = '';
  my $lspace = '' ;
  my $op = '';
  my $rspace = '' ;
  my $nb_violations = 0;

  $$code =~ s/(\+\+|--)//sg;

  # Suppression des + et - unaires (optimisation des performances pour certains types de fichier qui declarent beaucoup de donnees ... )
  # On garde les espaces presents avant l'operateur unaire, mais on supprime ceux apres cet operateur,
  # sinon ca perturbe le resultat concernant l'operateur avant l'operateur unaire.
  # Attention: ne sont supprimes que les espaces ou tablulations, pas les retour a la ligne.
  $$code =~ s/(\b(?:return|exit)\b\s*)(?:-|\+)[\ \t]*/$1/sg;
  $$code =~ s/((?:=|\[|\(|\{|\+|\-|\*|\/|<|>|,|\^|\%|\|\||\&\&|:|\?)\s*)(?:-|\+)[\ \t]*/$1/sg;

  # remove ":" from cases
  # ---------------------
  # Pattern should not be multi-line !!!! to prevent to recognize the following :
  #    case toto : 
  #          a = ( tata ? titi : tutu)
  #
  #  et transformé en 
  #
  #    case toto : 
  #          a = ( tata ? titi  tutu) 
  my $ternaryPattern = '[^\?\n:]*\?[^:\n]*:';
  $$code =~ s/(\b(?:case|default)\b(?:$ternaryPattern)?[^:\n]*):/$1/g;
  # remove ":" from objects.
  $$code =~ s/((?:\{|,)\s*\w+\s*):/$1/g;

  $$code =~ s/\s(?:$$ops)\s//sg;
#print "BADSPACING:<<$$code>>\n";  
  $nb_violations = () = $$code =~ /$$ops/g;
  
#my @viol = $$code =~ /$$ops/g;
#$nb_violations = scalar @viol;
#print "FOUND : $nb_violations\n";
#print join("\n", @viol)."\n";

  return $nb_violations;
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des erreurs d'espacement entre operateurs et operandes.
#-------------------------------------------------------------------------------
sub CountBadSpacing($$$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;
  my $status = 0;

  my $nbr_BadSpacing = 0;
  my $mnemo_BadSpacing = Ident::Alias_BadSpacing();

  # Default view.
  my $code = $vue->{'code'} ;

  # Check if another view is forced by parameter
  if ( exists $vue->{'CountConfParam'} ) {
    my $CountParam = $vue->{'CountConfParam'};
    if (defined $vue->{$$CountParam}) {
      $code = $vue->{$$CountParam};
    } 
  }


  if (!defined $code) {
    $status |= Couples::counter_add($compteurs, $mnemo_BadSpacing, Erreurs::COMPTEUR_ERREUR_VALUE);
    $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    return $status;
  }

  my $ops = '&&|\|\||\+=|-=|\|=|&=|-|\+|<=|>=|==|!=|=';

  $nbr_BadSpacing = _countBadSpacing(\$code, \$ops);

  $status |= Couples::counter_add($compteurs, $mnemo_BadSpacing, $nbr_BadSpacing);

  return $status;
}


1;
