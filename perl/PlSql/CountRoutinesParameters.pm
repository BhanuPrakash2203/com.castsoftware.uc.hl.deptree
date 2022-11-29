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

package PlSql::CountRoutinesParameters;

use strict;
use warnings;
use Erreurs;
use Couples;
use CountUtil;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Erreurs;

# prototypes publiques
sub CountRoutinesParameters($$$);

my $mnemo_WithMissingParametersModes_Routines = Ident::Alias_WithMissingParametersModes_Routines();
my $mnemo_WithParametersModeOut_Functions = Ident::Alias_WithParametersModeOut_Functions();
my $mnemo_WithTooMuchParametersMethods = Ident::Alias_WithTooMuchParametersMethods();


use constant SEUIL_MAX_NB_PARAM => 7;

# Recuperation de l'algorithme lie a Nbr_WithTooMuchParametersMethods:
# Routine de comptage du nombre de parametres total
# (declaration et implementation)
# Module de comptage du nombre de methodes avec trop de parametres
# (plus de 7) (declaration et implementation)
# Les comptages sont realises dans le body uniquement
sub _CountParameters($) 
{
  my ($r_param) =  @_ ;

  my $nb_param = 0;
  my @arr_params;

  my $item = $$r_param;
  #if ($item =~ /\((.*)\)/)
  {	# il y a un ou des parametres
		# comptages des parametres
                my $match_param = $item;
                if ($match_param =~ /^\s*$/)
                {   # pas de parametres(normalement ce cas de doit pas arriver en PL-SQL
                    $nb_param = 0;
                }
                else
                {   # au moins un parametre
                    @arr_params = split(',', $match_param);
                    $nb_param = @arr_params;
                }
  }
  return $nb_param;

}

# Comptage du noeud, s'il est dans une arborescence
# correspondant aux criteres d'imbrication voulu
sub _IsInBody($)
{
  my ( $node)= @_;
  my $parent = PlSql::PlSqlNode::GetParent($node);
  $node = $parent;
  while ( ( not IsKind ( $node, RootKind) ) )
  {
    if( IsKind ( $node, PackageKind) )
    {
      my $stmt = GetStatement($node);
      if ( $stmt =~ /\bbody\b/smi )
      {
        return 1;
      }
    }
    $parent = PlSql::PlSqlNode::GetParent($node);
    $node = $parent;
  }
  return 0;
}


# Recuperation de l'algorithme lie a Nbr_WithTooMuchParametersMethods:
# Routine de comptage du nombre de parametres total
# (declaration et implementation)
# Module de comptage du nombre de methodes avec trop de parametres
# (plus de 7) (declaration et implementation)
# Les comptages sont realises dans le body uniquement
sub _CountImplementationParameters($$$$$) 
{
  my ($r_param, $context, $func, $implementation, $node) =  @_ ;

  #if ( $implementation )
  {
    my $nb_param = _CountParameters($r_param);
    if ($nb_param > SEUIL_MAX_NB_PARAM)
    {
      if ( _IsInBody($node) )
      {
        $context->[2] += 1;
      }
    }
  }

}

sub _CountModes($$$) {

  my ($r_param, $context, $func) =  @_ ;

  # Le nombre de parametre est egal au nombre de ',' + 1.
  # Exception : if the buffer that contains the parameters list does not contains any alphanum,
  #             that signifies that there is 0 parameters ...
  my $nbr_parameters = 0;

  if ( $$r_param =~ /\w/ ) {
    $nbr_parameters = () = $$r_param =~ /,/smg ;
    $nbr_parameters++;
  }

  my $nbr_IN = () = $$r_param =~ /\bIN\b/ismg;
  my $nbr_OUT = () = $$r_param =~ /\bOUT\b/ismg;
  my $nbr_INOUT = () = $$r_param =~ /\b(IN +OUT|OUT +IN)\b/ismg;
 
  Erreurs::LogInternalTraces('debug', undef, undef, $mnemo_WithMissingParametersModes_Routines, $$r_param, "($nbr_IN+$nbr_OUT-$nbr_INOUT) < $nbr_parameters");
  if ( ($nbr_IN+$nbr_OUT-$nbr_INOUT) < $nbr_parameters) {
    # Incrementation de Nbr_WithMissingParametersModes_Routines
    #
    Erreurs::LogInternalTraces('trace', undef, undef, $mnemo_WithMissingParametersModes_Routines, $$r_param, '');
    $context->[0] += 1;
  }

  if ( ($func) && ($nbr_OUT > 0)) {
    # Incrementation de Nbr_WithParametersModeOut_Functions
    $context->[1] += 1;
  }
}

# Reperage de chaque declare.
sub _callbackRoutine($$$$)
{
  my ( $node, $context )= @_;

  my $r_param;



  if ( IsKind($node, ProcedureKind) or IsKind($node, FunctionKind) or 
             IsKind($node, PrototypeSpecKind)  )
  {
    my $statement = GetStatement($node);
    my $stmt = lc($statement);

    my $implementation = IsKind($node, ProcedureKind) or IsKind($node, FunctionKind) ;

    if (defined $stmt) {
      Erreurs::LogInternalTraces('debug', undef, undef, $mnemo_WithMissingParametersModes_Routines, $stmt, "node");

      # Suppression de tout ce qu'il y a avant la parenthese ouvrante de debut des parametres.

      if ( $stmt =~ /.*(procedure|function)[^\(]*/smig)
      {
      my $str_key = lc ( $1 ) if defined ($1);
      $stmt =~ s/.*(?:procedure|function)[^\(]*//smig;


      my $type = 0;
      if ((defined $str_key) && (lc($str_key) eq 'function')) {
        $type = 1;
      }
      # troncage du resultat a la parenthese fermante de fin de parametre.
      ($r_param) = CountUtil::splitAtPeer(\$stmt, '(', ')');

#print STDERR "Type: " .$type . "\n" ;
#print STDERR "str_key: " .$str_key . "\n" ;
#print STDERR "params: " .$$r_param . "\n" ;
#print STDERR "Statement: " .$statement . "\n" ;

      # Analyse des parametres.
      _CountModes($r_param, $context, $type);
      _CountImplementationParameters($r_param, $context, $type, $implementation, $node);
      }
    }
    else {
      print STDERR "NODE ERROR : 'node'  de fonction ou  de procedure sans 'statement'\n";
    }
  }
  return undef;

}

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des lignes de code en commentaire.
#-------------------------------------------------------------------------------
sub CountRoutinesParameters($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $status = 0;
  my $nbr_WithMissingParametersModes_Routines = 0;
  my $nbr_WithParametersModeOut_Functions = 0;
  my $nbr_WithTooMuchParametersMethods = 0;

  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root ) {
    $status |= Couples::counter_add($compteurs, $mnemo_WithMissingParametersModes_Routines, Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, $mnemo_WithParametersModeOut_Functions,  Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, $mnemo_WithTooMuchParametersMethods,  Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @context = ( 0, 0, 0 );

  Lib::Node::Iterate ($root, 0, \& _callbackRoutine, \@context) ;

  $nbr_WithMissingParametersModes_Routines = $context[0];
  $nbr_WithParametersModeOut_Functions = $context[1];
  $nbr_WithTooMuchParametersMethods = $context[2];

  $status |= Couples::counter_add($compteurs, $mnemo_WithMissingParametersModes_Routines, $nbr_WithMissingParametersModes_Routines);
  $status |= Couples::counter_add($compteurs, $mnemo_WithParametersModeOut_Functions, $nbr_WithParametersModeOut_Functions);
  $status |= Couples::counter_add($compteurs, $mnemo_WithTooMuchParametersMethods, $nbr_WithTooMuchParametersMethods);

  return $status;
}

1;
