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

package CountCommentsBlocs;

use strict;
use warnings;
use Erreurs;

# prototypes publiques
sub CountCommentsBlocs($$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage du nombre de blocs de commentaire.
#-------------------------------------------------------------------------------
sub CountCommentsBlocs($$$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $MixBloc = $vue->{'MixBloc'};
  my $status = 0;
  my $nbr_CommentBlocs = 0;
  my $mnemo_CommentBlocs = Ident::Alias_CommentBlocs();
  my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # Erreurs::LogInternalTraces
  my $trace_detect = '' if ($b_TraceDetect);                         # Erreurs::LogInternalTraces
  my $base_filename = $fichier if ($b_TraceDetect);                  # Erreurs::LogInternalTraces
  $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # Erreurs::LogInternalTraces

  if ( ! defined $MixBloc ) {
    $status |= Couples::counter_add($compteurs, $mnemo_CommentBlocs, Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    return $status;
  }

  # Les lignes 100% commentaire qui se terminent par ';' sont suspectees d'etre du code en commentaire, et ne doivent donc
  # pas etre comptabilisees pour ne pas fausser le nombre de 'blocs de commentaires a caractere fonctionnel'.
  # la notion 'a caractere fonctionnel' est une sur-specification de ce qu'est un 'bloc de commentaires', l'optimisation est abandonnee
  # $MixBloc =~ s/^[ \t]*\/\*.*;[ \t]*\*\/[ \t]*$//mg;

  # Analyse ligne par ligne ...

  my $line_number = 0 if ($b_TraceDetect); # Erreurs::LogInternalTraces

  my $FlagBloc = 0;

  my $line;
  my @LINE = split(/\n/, $MixBloc);
  foreach $line (@LINE) {
    
    my ($start, $comment) = $line =~ /(.*)(\/\*.*\*\/)\s*$/m ;

    if ( defined $comment ) {
      # Si la ligne se termine par un commentaire

      my $match = $start . $comment; # Erreurs::LogInternalTraces
      $line_number++;                # Erreurs::LogInternalTraces

      if ( ( defined $start ) && ( $start =~ /\S/ ) ) {
        # Si la ligne contient du code au debut (au moins un caractere non blanc)

        # On marque un nouveau bloc
        $nbr_CommentBlocs++;
	$trace_detect .= "$base_filename:$line_number:---$match---\n" if ($b_TraceDetect); # Erreurs::LogInternalTraces

        # Et on le referme aussitot ...
        $FlagBloc = 0;
      }
      else {
        # Sinon (i.e. la ligne se termine par un commentaire et ne contient pas du code au debut)
        if ( $FlagBloc == 0 ) {
          # Si $FagBloc vaut 0 cela signifie que l'on rencontre un nouveau bloc de commentaires. 
          $FlagBloc=1;
          $nbr_CommentBlocs++;
	  $trace_detect .= "$base_filename:$line_number:---$match---\n" if ($b_TraceDetect); # Erreurs::LogInternalTraces
        }
        else {
          # Sinon il s'agit de la suite du bloc de commentaires precedent.
        }
      }
    }
    else {
      # Sinon (i.e. la ligne ne se termine pas par un commentaire )
      if ( $line =~ /\S/ ) {
        # Si la ligne n'est pas blanche, il s'agit d'une ligne de code.
        $FlagBloc = 0 ;
      }
      else {
        # Sinon il s'agit d'une ligne blanche.
      }
    }
  }

  $status |= Couples::counter_add($compteurs, $mnemo_CommentBlocs, $nbr_CommentBlocs);
  TraceDetect::DumpTraceDetect($fichier, $mnemo_CommentBlocs, $trace_detect, $options) if ($b_TraceDetect); # Erreurs::LogInternalTraces

  return $status;
}

# Count comments blocs using the "agglo" view. The format of this view is
# generic and could be common to all language. 
sub CountCommentsBlocs_agglo($$$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $status = 0;
  my $nbr_CommentBlocs = 0;
  my $mnemo_CommentBlocs = Ident::Alias_CommentBlocs();

  if ( ! defined  $vue->{'agglo'} ) {
    $status |= Couples::counter_add($compteurs, $mnemo_CommentBlocs, Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    return $status;
  }
  $nbr_CommentBlocs = () =  $vue->{'agglo'} =~ /(?:C\n)+/sg;
  $status |= Couples::counter_add($compteurs, $mnemo_CommentBlocs, $nbr_CommentBlocs);

  return $status;
}


1;
