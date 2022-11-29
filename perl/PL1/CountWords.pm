
package PL1::CountWords;
# modules importes
use strict;
use warnings;
use Erreurs;
use TraceDetect;

# prototypes publics
sub CountWords($$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des mots (halstead)
#-------------------------------------------------------------------------------
sub CountWords($$$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $mnemo_Words = Ident::Alias_Words();
  my $status = 0;
  my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # Erreurs::LogInternalTraces
  my $trace_detect = '' if ($b_TraceDetect); # Erreurs::LogInternalTraces
  my $base_filename = $fichier if ($b_TraceDetect); # Erreurs::LogInternalTraces
  $base_filename =~ s{.*/}{} if ($b_TraceDetect); # Erreurs::LogInternalTraces

  my $code = $vue->{'sansprepro'};

  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, $mnemo_Words, Erreurs::COMPTEUR_ERREUR_VALUE );
    $status |= Couples::counter_add($compteurs, Ident::Alias_DistinctWords(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nbr_DistinctWords = 0;
  my $nbr_Words = 0;


  # Les parentheses ouvrantes seront comptees avec le mot qui les precede ...
  $code =~ s/(\w+)\s*[\(]/$1_ /g;

#  $trace_detect .= "--- debut code ---\n" . $code . "--- fin code ---\n"; # Erreurs::LogInternalTraces

  # supression des elements fermants (ils vont de pair avec des ouvrants comptabilises).
  $code =~ s/\)/ /g;

  my %Hop = ();
  my $nb = 0;

  # Remplacement des operateurs composes de 3 symboles.
  if ( $nb = ( $code =~ s/(\|\|=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\*\*=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}

  # Remplacement des operateurs composes de 2 symboles.
  if ( $nb = ( $code =~ s/(¬=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(¬>)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(¬<)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
#  if ( $nb = ( $code =~ s/(%=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(&=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\*=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\+=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(-=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\/=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
#  if ( $nb = ( $code =~ s/(\^=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\|=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
#  if ( $nb = ( $code =~ s/(&&)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\|\|)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
#  if ( $nb = ( $code =~ s/(\+\+)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
#  if ( $nb = ( $code =~ s/(\-\-)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(->)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(=>)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
#  if ( $nb = ( $code =~ s/(<<)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(<=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
#  if ( $nb = ( $code =~ s/(==)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(>=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
#  if ( $nb = ( $code =~ s/(>>)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\*\*)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}

  # Remplacement des operateurs composes de 1 symbole.
#  if ( $nb = ( $code =~ s/(!)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(%)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\*)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\+)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(,)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(-)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\.)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\/)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(<)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(=)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(>)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
#  if ( $nb = ( $code =~ s/(\?)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
#  if ( $nb = ( $code =~ s/(\^)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
#  if ( $nb = ( $code =~ s/({)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(;)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\()/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\))/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\¬)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(&)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}
  if ( $nb = ( $code =~ s/(\|)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}


  # Dans 'case xxx :', les ':' ne compte pas.
  # $code =~ s/\b(case\s*\w*\s*):/$1 /g;

  # Maintenant on s'occupe des ':' qui restent ...
  # if ( $nb = ( $code =~ s/(:)/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}

  # Comptage des '(' et '[' qui restent.
  if ( $nb = ( $code =~ s/(\()/§/g )) { $nbr_DistinctWords++; $Hop{$1}=$nb;}

  # Compter le nombre de mots distincts (il reste les identificateurs et les chaines)
  my $item;
  my %H =();

  my @WWW = split (/[^\w]+/, $code);
  foreach $item (@WWW) {

    $nbr_Words++;
    if (! defined $H{$item} ) {
      $nbr_DistinctWords++;
      $H{$item} = 1;
    }
    else {
      $H{$item} += 1;
    }
  }


  # Ajout de tout ce qui a ete trouve precedemment (et remplace par des §).
  $nbr_Words += () = $code =~ /§/g ;

# traces_filter_start

  # Affichage des resultats ...
  if ($b_TraceDetect) {
    my $total = 0;
    my $different = 0;
    my $word;
    my $key;
    my $HStrings = $vue->{HString};
    for $key ( keys %H) {
      if ( $key =~ /CHAINE_/ ) {
	$word = $HStrings->{$key};
      } else {
	$word = $key ;
      }

      if ( defined $word ) {
	$trace_detect .= $word." ............................. ".$H{$key}."\n";
      }

      $total += $H{$key};
      $different++;
    }

    for $key ( keys %Hop) {
      $trace_detect .= $key." ............................. ".$Hop{$key}."\n";
      $total += $Hop{$key};
      $different++;
    }
    $trace_detect .=  "TOTAL = $total\n";
    $trace_detect .=  "DISTINCT = $different\n";

    TraceDetect::DumpTraceDetect($fichier, Ident::Alias_DistinctWords(), $trace_detect, $options) if ($b_TraceDetect);
  }

# traces_filter_end

  # Finalisation des resultats.
  $status |= Couples::counter_add($compteurs, $mnemo_Words, $nbr_Words);
  $status |= Couples::counter_add($compteurs, Ident::Alias_DistinctWords(), $nbr_DistinctWords);

  return $status;
}


1;

