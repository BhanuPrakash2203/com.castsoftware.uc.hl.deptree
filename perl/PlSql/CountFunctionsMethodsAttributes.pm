
package PlSql::CountFunctionsMethodsAttributes;

use strict;
use warnings;

use Erreurs;
use Lib::NodeUtil;
use PlSql::PlSqlNode ;

sub CountFunctionsMethodsAttributes($$$) 
{
  my ($unused, $vue, $compteurs) = @_ ;

  my $root =  $vue->{'structured_code'} ;
  my $ret=0;

  if ( ! defined $root)
  {
    $ret |= Couples::counter_add($compteurs, Ident::Alias_FunctionDeclarations(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_ProcedureDeclarations(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_ProcedureImplementations(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_AnonymousBlocs(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_BodyPackage(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_SpecPackage(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_BodyType(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_NonObjectType(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_SpecObjectType(), Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, Ident::Alias_TriggerImplementations(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my @context = ( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
                # 0  1  2  3  4  5  6  7  8  9

  Lib::Node::Iterate ($root, 0, \& _callbackRoutine, \@context) ;

  my $nb_FunctionDeclarations= $context[0];
  my $nb_ProcedureDeclarations= $context[1];
  my $nb_ProcedureImplementations= $context[2];
  my $nb_AnonymousBlocs = $context[3];
  my $nb_BodyPackage = $context[4];
  my $nb_NonBodyPackage = $context[5];
  my $nb_BodyType = $context[6];
  my $nb_NonObjectType = $context[7];
  my $nb_SpecObjectType = $context[8];
  my $nb_TriggerImplementations = $context[9];

  # Comptage G66a: Nombre de declarations de fonctions
  $ret |= Couples::counter_add($compteurs, Ident::Alias_FunctionDeclarations(), $nb_FunctionDeclarations);
  # Comptage G66b: Nombre de declarations de procedures
  $ret |= Couples::counter_add($compteurs, Ident::Alias_ProcedureDeclarations(), $nb_ProcedureDeclarations);

  # Comptage G67b: Nombre d'implementations de procedures
  $ret |= Couples::counter_add($compteurs, Ident::Alias_ProcedureImplementations(), $nb_ProcedureImplementations);

  # Comptages definis en avril 2009
  $ret |= Couples::counter_add($compteurs, Ident::Alias_AnonymousBlocs(), $nb_AnonymousBlocs);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_BodyPackage(), $nb_BodyPackage);
  $ret |= Couples::counter_add($compteurs, Ident::Alias_SpecPackage(), $nb_NonBodyPackage );
  $ret |= Couples::counter_add($compteurs, Ident::Alias_BodyType(), $nb_BodyType );
  $ret |= Couples::counter_add($compteurs, Ident::Alias_NonObjectType(), $nb_NonObjectType );
  $ret |= Couples::counter_add($compteurs, Ident::Alias_SpecObjectType(), $nb_SpecObjectType );
  $ret |= Couples::counter_add($compteurs, Ident::Alias_TriggerImplementations(), $nb_TriggerImplementations );

  return $ret;
}


# Reperage de chaque declare.
sub _callbackRoutine($$;$$)
{
  my ( $node, $context )= @_;

  #my $r_param;

  my $nb_FunctionDeclarations= $context->[0];
  my $nb_ProcedureDeclarations= $context->[1];
  my $nb_ProcedureImplementations= $context->[2];

  #if ( IsKind($node, ProcedureKind) or IsKind($node, FunctionKind))
  #{
  my $statement_mixed_case = GetStatement($node);
  my $statement; 
  if (defined $statement_mixed_case)
  {
     $statement = lc ( $statement_mixed_case );
  }
  else {
     # $statement_mixed_case may be undefined. This case as been encountered for the ThenKind node for example.
     # In this case, $statement is set to empty string for security, but a such node should not
     # be concerned by the following treatment... 
     $statement = ""; 
  }

  {
    Erreurs::LogInternalTraces('grep', undef, undef, 'FunctionsMethodsAttributes', $statement, '');

    #if ( $statement =~ /\bis\b/sm )
    if ( IsKind($node, ProcedureKind) )
    {
      # il ne peut pas s'agir d'une declaration, mais plutot d'une implementation

      if ( $statement =~ /\bprocedure\b/sm )
      {
        $nb_ProcedureImplementations++;
      }

    }
    elsif  ( IsKind($node, PrototypeSpecKind ))
    {
      # il ne peut pas s'agir d'une implementation, mais plutot d'une declaration
      if ( $statement =~ /\bfunction\b/sm )
      {
        $nb_FunctionDeclarations++;
      }
      if ( $statement =~ /\bprocedure\b/sm )
      {
        $nb_ProcedureDeclarations++;
      }
    }
    elsif ( IsKind($node, AnonymousKind ))
    {
      $context->[3] ++;
    }
    elsif ( IsKind($node, PackageKind ))
    {
      if ( $statement =~ /\bbody\b/sm )
      {
        $context->[4] ++;
      }
      else
      {
        $context->[5] ++;
      }
    }
    elsif ( IsKind($node, TypeBodyKind ))
    {
      $context->[6] ++;
    }
    elsif ( IsKind($node, TypeKind ))
    {
      if ( $statement !~ /\b(?:object|under)\b/sm )
      {
        $context->[7] ++;
      }
      else
      {
        $context->[8] ++;
      }
    }
    elsif ( IsKind($node, TriggerKind ))
    {
      $context->[9] ++;
      my $name = PlSql::PlSqlNode::GetName($node);
      Erreurs::LogInternalTraces('trace', undef, undef, Ident::Alias_TriggerImplementations(), $name, $statement);
    }
  }
  $context->[0] =  $nb_FunctionDeclarations;
  $context->[1] =  $nb_ProcedureDeclarations;
  $context->[2] =  $nb_ProcedureImplementations;
  
  return undef;
}


1;
