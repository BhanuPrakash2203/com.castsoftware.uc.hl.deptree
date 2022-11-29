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

package CountAssignmentsInConditionalExpr;

# les modules importes
use strict;
use warnings;
use Erreurs;

# prototypes publics
sub CountAssignmentsInConditionalExpr($$$);

# prototypes prives
sub splitAtPeer($$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module interne separe un buffer en deux partie :
#    - la partie gauche contiendra le debut du buffer jusqu'au premier 'ouvrant',
#      ainsi que tout le code entre le premier ouvrant et le 'fermant' correspondant
#      inclus.
#    - la parie droite contiendra le reste du buffer.
#-------------------------------------------------------------------------------

sub splitAtPeer($$$)
{
  my ($r_prog, $open, $close) = @_ ;

  my $left = '';
  my $right = '';
  my $opened = 0;
  my $before_split = 1;

  while ($$r_prog =~ /(.)/sg)
  {
    my $c = $1;
    if ($before_split == 1)
    {
      if ($c eq $open)
      {
        $opened += 1;
      }
      elsif ($c eq $close)
      {
        if ( $opened == 0)
        {
          print STDERR "[CountAssignmentsInConditionalExpr::SplitAtPeer] Defaut d'appariement des $open et $close..\n";
          #print "$$r_prog\n";
          return (undef, undef);
        }
        $opened -=1 ;
        if ($opened == 0)
        {
          $before_split = 0;
        }
      }
      $left .= $c;
    }
    else
    {
      $right .= $c;
    }
  }

  if ($opened > 0)
  {
    print STDERR "[CountAssignmentsInConditionalExpr::SplitAtPeer] Defaut d'appariement des $open et $close : un caractere $open n'a pas de correspondance dans $$r_prog\n";
    return (undef, undef) ;
  }

  return ($left, $right);
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des conditions complexes. 
#-------------------------------------------------------------------------------

sub CountAssignmentsInConditionalExpr($$$)
{
  my ($fichier, $vue, $compteurs) = @_ ;

  my $Sep = '[\s\n]';
  my $status = 0;

  my $nbr_AssignmentsInConditionalExpr = 0;
  my $mnemo_AssignmentsInConditionalExpr = Ident::Alias_AssignmentsInConditionalExpr();

  my $fatalerror = 0;

#  my $code = '';
#  if ((exists $vue->{'prepro'}) && ( defined $vue->{'prepro'}))
#  {
#    $code = $vue->{'prepro'};
#    Erreurs::LogInternalTraces('DEBUG', $fichier, 1, $mnemo_AssignmentsInConditionalExpr, "utilisation de la vue prepro.\n");
#  }
#  else
#  {
#    $code = $vue->{'code'};
#  }

  # If exists get 'prepro' view, else work with 'code', unless another view
  # is forced by parameter stored in the $vue Hash table.
  my $code = ${Vues::getView($vue, 'prepro', 'code')};

  if (!defined $code)
  {
    $status |= Couples::counter_add($compteurs, $mnemo_AssignmentsInConditionalExpr, Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    return $status;
  }

  # remplacement :
  #    operateur comparaison --> C
  #    operateur logique --> L

  $code =~ s/=>/ _LAMBDA_ /sg ;
  $code =~ s/(==|!=|<=|>=)/ C /sg ;
  $code =~ s/([^-])(<|>)/$1 C /sg ;
  $code =~ s/(\&\&|\|\||\!|\&|\|)/ L /sg ;

  # Neutralisation des mots cles de directive de compilation, en les faisant preceder de '_'
  $code =~ s/(#\s*)(if|ifdef|ifndef|else|elif|elifdef|elifndef|endif)/$1_$2/sg;
  my $x001 = pack("U0C*", 0x01);             # U+0001 <control>

  $code =~ s/\b((if|while|for)\b\s*\()/$x001$1/sg ;
  $code .= chr(1);

  $code =~ s/\(\s*\)//sg;

  while ( $code =~ /\b((if|while|for)\b\s*\([^\x01]*)$x001/sg )
  {

    my $buf = $1;
    my $instr = $2;
    my $foo ;

    # Si l'instruction est un for, il faut extraire l'expression qui est entre les deux ';'.
    # Attention au cas particulier du java, qui peut ne pas avoir de ';'.
    if ( $instr eq 'for' )
    {
      # Capture de l'ensemble de l'expression du for
      ($buf, $foo)  = splitAtPeer(\$buf, '(', ')');

      if ($buf =~ /;/ )
      {
        # Suppression de la premiere clause des boucles 'for', dans le cas d'une forme 'for(;;)'.
        $buf =~ s/\A\bfor\b\s*\([^;]*;([^;]*);/\($1\)/;
      }
    }

     # Recuperation de la condition avec matching exact des parentheses.
    ($buf, $foo)  = splitAtPeer(\$buf, '(', ')');

    if ( ! defined $buf )
    {
      $status |= Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'comptage!!!!', ''); # traces_filter_line
      $nbr_AssignmentsInConditionalExpr = Erreurs::COMPTEUR_ERREUR_VALUE;
      last;
    }

    # Pour chaque expression elementaire parenthesee ...
    # Pour la condition associee au 'if' ou au 'while', les expression elementaires (parenthesee) sont analysees.
    # Si une expression elementaire comporte un operateur d'affectation, si elle n'est pas reliee a au moins un
    # operateur de comparaison, alors qu'elle est reliee a au moins un operateur logique, alors il s'agit d'une violation.

    # On boucle tant qu'on trouve AU MOINS deux parentheses ouvrantes imbriquees ...
    # Si la derniere ouvrante n'est pas associe a une parenthese ouvrante, alors il y a erreur de parenthese ...
    while ($buf =~ /\A[^\(]*\([^\(\)]*\(([^\)]*\))?/s )
    {

      if (defined $1)
      {
        my ($pre, $cond, $post) = $buf =~ /([^\(\)\s\#]*)${Sep}*\(([^\(\)]*)\)${Sep}*([^\(\)\s\#]*)/s ;

        if ( $cond =~ /=/s )
        {
          if ( ($pre ne 'C') && ($post ne 'C') )
          {
              $nbr_AssignmentsInConditionalExpr++;
              Erreurs::LogInternalTraces('TRACE', $fichier, 1, $mnemo_AssignmentsInConditionalExpr, $buf);
          }
        }
        $buf =~ s/(\([^\(\)]*\))/ X/s;
      }
      else
      {
        print STDERR "Erreur d'appariement des parentheses dans $fichier. Abandon du Comptage [AssignmentsInConditionalExpr]\n";
        $fatalerror = 1;
        last;
      }
    }

    if ( $fatalerror == 1 )
    {
      $status |= Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'comptage!!!!', ''); # traces_filter_line
      $nbr_AssignmentsInConditionalExpr = Erreurs::COMPTEUR_ERREUR_VALUE;
      last;
    }

    # Analyse du dernier niveau de parenthese ...
    # Il ne doit pas subsister de '='. La moindre des choses pour s'autoriser a mettre une affectation dans une condition serait
    # d'isoler l'affection dans un jeu de sous-parentheses.
    my ($cond) = $buf =~ /\(([^\(\)]*)\)/s;
    if ((defined $cond) && ($cond =~ /=/s))
    {
      $nbr_AssignmentsInConditionalExpr++;
      Erreurs::LogInternalTraces('TRACE', $fichier, 1, $mnemo_AssignmentsInConditionalExpr, $buf);
    }
  }
  $status |= Couples::counter_add($compteurs, $mnemo_AssignmentsInConditionalExpr, $nbr_AssignmentsInConditionalExpr);

  return $status;
}


1;
