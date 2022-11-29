
package PlSql::ParseBody;

use strict;
use warnings;

use Lib::Node;
use Lib::NodeUtil;
use PlSql::PlSqlNode;

use Timing; # timing_filter_line
use StripUtils;
use Vues;

use Erreurs;

use StripUtils qw(
                  garde_newlines
                 );

# Declaration prealable des fonctions recursives.
sub Iterate($$$$$);

sub Iterate($$$$$)
{
  my ($baseNode, $level, $callback, $context, $state) = @_;
  my $bloc = GetSubBloc($baseNode);
  for my $node ( @{$bloc} )
  {
    $state = $callback->( $node, $context, $level, $state);

    Iterate($node, $level+1, $callback, $context, $state);
  }
}



## analyse du fichier
#sub ParseBody($$$$)
#{
#  my ($unused, $vue, $options, $couples) = @_;
#  #my ($unused, $vue, $compteurs) = @_ ;
#
#  my $status = 0;
#  my $input= $vue->{'statements_with_blanks'} ;
#
#  my $vues = new Vues( 'statements_with_blanks' ); # creation des nouvelles vues a partir de la vue plsql
#  my $position = 0;
#
#  $vues->declare('bloc_body');
#  $vues->declare('hors_bloc');
#  $vues->declare('bloc_hors_bloc_body');
#
#
#  my @states;
#  my $state = 'no_package';
#
#  for my $statement_mc ( @{$input} )
#  {
#    my $statement_lc = lc ( $statement_mc );
#    my $espaces = $statement_lc ; # les retours a la ligne correspondant.
#    $espaces = garde_newlines($espaces) ;
#
#    Erreurs::LogInternalTraces('trace', undef, undef, 'Strip',  $statement_lc , $state);
#
#    if ( $statement_lc =~ /\bpackage\b/sm )
#    {
#      push @states,  $state;
#      Erreurs::LogInternalTraces('trace', undef, undef, 'StripTree',  $statement_lc , 'push');
#      if ( $statement_lc =~ /\bbody\b/sm )
#      {
#        $state = 'bloc_body' ;
#      }
#      else
#      {
#        $state = 'bloc_hors_bloc_body' ;
#      }
#    }
#    else
#    {
#      # ne rien faire
#    }
#
#    if ( $statement_lc =~ /\bbegin\b/sm )
#    {
#      # FIXME: sauf si deja fait par package?
#      push @states, $state;
#      Erreurs::LogInternalTraces('trace', undef, undef, 'StripTree',  $statement_lc , 'push');
#    }
#
#    if ( $statement_lc =~ /\bend\b/sm )
#    {
#      if ( $statement_lc =~ /\b(?:if|loop)\b/sm )
#      {
#         # ne rien faire
#      }
#      else
#      {
#        $state = pop @states;
#        Erreurs::LogInternalTraces('trace', undef, undef, 'StripTree',  $statement_lc , 'pop');
#      }
#    }
#
#    Erreurs::LogInternalTraces('trace', undef, undef, 'Strip',  $statement_lc , '->' . $state);
#
#    if ( $state eq 'no_package' )
#    {
#      $vues->append( 'hors_bloc',  $statement_mc );
#      $vues->append( 'bloc_hors_bloc_body',  $espaces );
#      $vues->append( 'bloc_body',  $espaces );
#    }
#    elsif ( $state eq 'bloc_body' )
#    {
#      $vues->append( 'hors_bloc',  $espaces );
#      $vues->append( 'bloc_hors_bloc_body',  $espaces );
#      $vues->append( 'bloc_body',  $statement_mc );
#    }
#    elsif ( $state eq 'bloc_hors_bloc_body' )
#    {
#      $vues->append( 'hors_bloc',  $statement_mc );
#      $vues->append( 'bloc_hors_bloc_body',  $statement_mc );
#      $vues->append( 'bloc_body',  $espaces );
#    }
#
#    $vues->commit ( $position);
#    $position += length( $statement_mc) ;
#    
#  }
#
#  $vue->{'hors_bloc'} = $vues->consolidate('hors_bloc');
#  $vue->{'bloc_hors_bloc_body'} = $vues->consolidate('bloc_hors_bloc_body');
#  $vue->{'bloc_body'} = $vues->consolidate('bloc_body');
#
#
#  return $status;
#}
#
#sub CountLocalVariables($$$);



# Reperage de chaque fonction/procedure/package, 
# pour rechercher leurs variables locales.
sub _callbackNode($$$$)
{
  my ( $node, $context, undef, $state )= @_;
  my $statement_mc = PlSql::PlSqlNode::GetStatement($node);

  if (not defined  $statement_mc)
  {
    return $state;
  }

  {
    my $vues = $context->[0];
    my $position = $context->[1];
    #my $state = $context->[2];
    #my @context = ( $vues, $position, $state );

    #Lib::Node::ForEachDirectChild($node, \& _callbackHeader, $context);
 {
    my $statement_lc = lc ( $statement_mc );
    my $espaces = $statement_lc ; # les retours a la ligne correspondant.
    $espaces = garde_newlines($espaces) ;

    Erreurs::LogInternalTraces('trace', undef, undef, 'Strip',  $statement_lc , $state);

    if ( $statement_lc =~ /\bpackage\b/sm )
    {
      #push @states,  $state;
      Erreurs::LogInternalTraces('trace', undef, undef, 'StripTree',  $statement_lc , 'push');
      if ( $statement_lc =~ /\bbody\b/sm )
      {
        $state = 'bloc_body' ;
      }
      else
      {
        $state = 'bloc_hors_bloc_body' ;
      }
    }
    else
    {
      # ne rien faire
    }

    if ( $statement_lc =~ /\bbegin\b/sm )
    {
      # FIXME: sauf si deja fait par package?
      #push @states, $state;
      Erreurs::LogInternalTraces('trace', undef, undef, 'StripTree',  $statement_lc , 'push');
    }

    if ( $statement_lc =~ /\bend\b/sm )
    {
      if ( $statement_lc =~ /\b(?:if|loop)\b/sm )
      {
         # ne rien faire
      }
      else
      {
#FIXME: recuperer le context du noeud?
        #$state = pop @states;
        Erreurs::LogInternalTraces('trace', undef, undef, 'StripTree',  $statement_lc , 'pop');
      }
    }

    Erreurs::LogInternalTraces('trace', undef, undef, 'Strip',  $statement_lc , '->' . $state);

    if ( $state eq 'no_package' )
    {
      $vues->append( 'hors_bloc',  $statement_mc );
      $vues->append( 'bloc_hors_bloc_body',  $espaces );
      $vues->append( 'bloc_body',  $espaces );
    }
    elsif ( $state eq 'bloc_body' )
    {
      $vues->append( 'hors_bloc',  $espaces );
      $vues->append( 'bloc_hors_bloc_body',  $espaces );
      $vues->append( 'bloc_body',  $statement_mc );
    }
    elsif ( $state eq 'bloc_hors_bloc_body' )
    {
      $vues->append( 'hors_bloc',  $statement_mc );
      $vues->append( 'bloc_hors_bloc_body',  $statement_mc );
      $vues->append( 'bloc_body',  $espaces );
    }

    $vues->commit ( $position);
    $position += length( $statement_mc) ;
    
    } 

  #$context->[2] = $state;
  $context->[1] = $position;
  #my @context = ( $vues, $position, $state );
  }
  return $state
}


# Routine point d'entree du module.
# analyse du fichier
sub ParseBody($$$$)
{
  my ($unused, $vue, $options, $compteurs) = @_ ;

  my $ret = 0;

  my $NomVueCode = 'structured_code' ; 
  my $root =  $vue->{$NomVueCode} ;

  if ( ! defined $root )
  {
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $vues = new Vues( 'statements_with_blanks' ); # creation des nouvelles vues a partir de la vue plsql
  $vues->unsetOptionPosition();
  my $position = 0;
  my $state = 'no_package';
  my @context = ( $vues, $position, $state );

  $vues->declare('bloc_body');
  $vues->declare('hors_bloc');
  $vues->declare('bloc_hors_bloc_body');
  
  Iterate ($root, 0, \& _callbackNode, \@context, $state) ;

  $vue->{'hors_bloc'} = $vues->consolidate('hors_bloc');
  $vue->{'bloc_hors_bloc_body'} = $vues->consolidate('bloc_hors_bloc_body');
  $vue->{'bloc_body'} = $vues->consolidate('bloc_body');

  return $ret;
}

1;
