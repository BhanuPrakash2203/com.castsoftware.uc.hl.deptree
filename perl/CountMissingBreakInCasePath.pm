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

# Composant: Plugin

package CountMissingBreakInCasePath;

use strict;
use warnings;
use Erreurs;

#-------------------------------------------------------------------------------
# Description =
# 	Module de comptage des 'break' manquants dans un des chemins menant du debut du 'case' à sa fin.
#
# 	Le dernier statement du 'switch' (en general c'est le 'default') n'est pas pris en compte.
#
# 	Pour chaque 'case', les 'break' situes dans des structure de controle ne sont pas pris en compte, car:
# 	  - Dans le cas des boucle, les 'break' ne se reporte pas au 'case'
# 	  - Dans le cas des 'if/else', les 'break' sont conditionnel, alors que la regle les veut obligatoire.
#
# Langages = 
# 	C, C++, C#, Java
#-------------------------------------------------------------------------------

sub CountMissingBreakInCasePath($$$) {
  my ($fichier, $vue, $compteurs) = @_ ;

  my $status = 0;

  

#  my $code = "";
#  if ( (exists $vue->{'prepro'}) && ( defined $vue->{'prepro'} ) ) {
#    $code = $vue->{'prepro'};
#    Erreurs::LogInternalTraces('DEBUG', $fichier, 1, 'CountMissingBreakInCasePath', "utilisation de la vue prepro.\n");
#  }
#  else {
#    $code = $vue->{'sansprepro'};

# FIXME : Certains langages ne possedent pas la vue sansprepro. Dans ce cas, le comptage sera effectue sur la vue code.
# FIXME : Ce FIXME disparaitra lorsque l'outil fera l'objet d'une homogeneisation des vues dans les differents langages
# FIXME : afin de pouvoir partager en toute coherence le code de comptages communs.
#    if (!defined $code) {
#      $code = $vue->{'code'};
#    }
#  }

  my $code = ${Vues::getView($vue,'prepro', 'sansprepro', 'code')};

  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, Ident::Alias_MissingBreakInCasePath(), Erreurs::COMPTEUR_ERREUR_VALUE );
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

#$code =~s/\n\s*\n/\n/g;

  my $nb_MissingBreakInCasePath = 0;

  my $Wcode;

  # !!! Suppression des parentheses (conditions, appels) !!!! Remplace par un espace pour eviter de "coller" 2 tokens
  while ($code =~ /\([^\(\)\?\:]*\)/s ) {
    $code =~ s/(\([^\(\)]*\))/ /sg ;
  }

  # Neutralisation des mots cles de directive de compilation, en les faisant preceder de "_"
  $code =~ s/(#\s*)\b(if|ifdef|ifndef|else|elif|elifdef|elifndef|endif)/$1_$2/sg;

  # Ajout des accolades implicites :
  # Attention : ne fonctionne pas pour un do .. while !!!
  # Attention : ne fonctionne pas pour des structures imbriquees.
  $code =~ s/((\b(if|else|for|while|do)\s*)([^\{;]*);)/$2\{$4;\}/sg ;

  while ( $code =~ /\bswitch\b(.*)/sg ) {
    # Capture du code a partir de l'accolade du switch
    $code = $1 ;

    # chargement de $code dans $Wcode pour pouvoir faire des modification temporaire.
    $Wcode = $code;

#print STDERR "\n\n\nSWITCH \n";
#$code =~ /\A(.*\s*.*\s*.*)/;
#print STDERR "switch : $1\n";

    # Suppression de tous le code situe apres le bloc de la boucle analysee.
    # ATTENTION : cette technique est basee sur l'appariement des accolades et peut ne pas marcher
    # en cas de code conditionnel pourri ...
    my $loop1="";
    my $stop=0;
    my $depth=0;
    my $cut=255;
    my $item;
    my $acco;
    while ( ($Wcode =~ /(([^\{\}]*)([\{\}]))/sg ) && ($stop == 0) ) {
      $item = $1;
      $acco = $3;
      if ($acco eq '{') {

        if (($cut == 255) && ($item =~ /(while|for|switch|do|if|else)\s*\{/)) {
          # Marquer le niveau de parenthese a partir duquel on coupe le code.
          $cut = $depth;
          # Recuperer maintenant le code qui se trouve avant la structure de controle a supprimer ...
          $item =~ s/\b(while|for|switch|do|if|else).*//s ;
          $loop1 .= $item;
          # Insertion d'un marqueur pour signaler que du code a ete coupe.
          $loop1 .= "structure;\n";
        }

        # Augmentation de la profondeur de parentheses ...
        $depth++;

      }
      elsif ($acco eq '}') {
        # Diminution de la profondeur de parentheses ...
        $depth--;
        if ($depth <= 0) {
          $stop=1;
        }
      }
      if ($depth < $cut) {
        # On n'ecrit le code que si on n'est pas dans une structure de controle a couper.
        # Si $cut vaut 255, cela signifie que l'on n'est pas dans une structure a couper.
        $loop1 .= $item;
      }
      elsif ($depth == $cut) {
        # Si cette contition vaut "true", cela signifie que l'on vient juste de fermer l'accolade d'une structure a couper.
        $cut = 255 ;
      }
    }
    $Wcode = $loop1;

#my $printableLoop = $loop1;
#$printableLoop =~s/\n\s*\n/\n/g;
#print STDERR "LOOP: $printableLoop\n" ;

    if ($depth > 0) {
      $status |= Couples::counter_add($compteurs, Ident::Alias_MissingBreakInCasePath(), Erreurs::COMPTEUR_ERREUR_VALUE);
      print STDERR "$fichier : Probleme d'appariement de parentheses\n";
      $status |= Erreurs::COMPTEUR_STATUS_AUTRES_ERREURS;
      Erreurs::LogInternalTraces ('erreur', undef, undef, 'COMPTEUR_STATUS_AUTRES_ERREURS', 'comptage!!!!', ''); # traces_filter_line
      return $status;
    }

    # remplacement de tous les "case i" ou "default" par "::", pour simplifier l'analyse.
    $Wcode =~ s/(\bcase\s*\w*\s*:|\bdefault\s*:)/-+case :/sg ;

#print STDERR
    #" remplacement de tous les 'case i' ou 'default' par '::', pour simplifier l'analyse: fait.\n";
#$printableLoop = $Wcode;
#$printableLoop =~s/\n\s*\n/\n/g;
#print STDERR "SIMPLE: $printableLoop\n" ;

    # La boucle ne traite pas le dernier item, mais cela est voulu.
#    while ( $Wcode =~ /item :([^:]*)item :/sg ) {

# Boucle plantant en cygwin perl 5.8.7, lorsque 100 lignes de commentaires 
# dans un bloc case.
    #while ( $Wcode =~ /case :((?:-[^\+]|[^-])*)-\+/sg ) {
      #my $bloc = $1;

    my @blocs = split ( /[-][+]case :/s, $Wcode);
    my $lastcount = 0;
    #my $first = 1;
    shift @blocs;
    for my $bloc ( @blocs )
    {

#print STDERR "BLOC \n";
##$bloc =~ /\A(.*\s*.*\s*.*)/;
#my $printableBloc = $bloc;
#$printableBloc =~s/\n\s*\n/\n/g;
#print STDERR "bloc : $printableBloc\n";
      $lastcount = 0;

      # Si le case ne comporte pas ni break/return/goto/throw, et si il n'est pas vide (excepté un ";") alors on compte une erreur ...
      # FIXME: AD: si le 'case' est completement vide (2 'case' contigus) alors on compte aussi une erreur alors qu'il ne faut pas
      if ( ( $bloc !~ /\b(break|return|goto|throw|continue)\b/s) && ( $bloc !~ /^[\s;]*$/) ) {
      #if ( ( $bloc !~ /\b(?:break|return|goto|throw|continue)\b/s) && ( $bloc !~ /\A(?:\s|;)*\z/sm) ) {
        $lastcount++;
        $nb_MissingBreakInCasePath++;
print STDERR "MISSING break\n";
        Erreurs::LogInternalTraces("TRACE", $fichier, 1, "MissingBreakInCasePath",  $bloc );
#print "======> Break manquant\n";
      }


    #print STDERR " On repasse ici\n";
    }
    #print STDERR " La boucle ne traite pas le dernier item, mais cela est voulu.\n";

    $nb_MissingBreakInCasePath -= $lastcount;
  }

  Erreurs::LogInternalTraces("TRACE", $fichier, 1, "MissingBreakInCasePath", "$nb_MissingBreakInCasePath occurrences" );
  $status |= Couples::counter_add($compteurs, Ident::Alias_MissingBreakInCasePath(), $nb_MissingBreakInCasePath);

  return $status;
}

1;
