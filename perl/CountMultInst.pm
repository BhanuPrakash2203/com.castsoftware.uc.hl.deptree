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

package CountMultInst;
# les modules importes
use strict;
use warnings;
use Erreurs;

# prototypes publics
sub CountMultInst($$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION: Module de comptage des lignes comportant plusieurs instructions.
# 
# The rule could be called too "missing new line"
# 
# Specification
#       Count one violation each time a an instruction is on the same line than the previous one.
#       Consider the statement separator is ";"
#
# with : 
# * stmt = instruction followed by ;
# * control = control flow statement with missing accolade
#
# the patterns to detect are :
# * stmt ; stmt ;
# * { stmt ; * stmt ; }
# * control stmt;
# 
# For C#, exception for { get; set; } that is just sugar sugar syntax for getter/setter of a property
#-------------------------------------------------------------------------------

sub CountMultInst($$$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $techno = $options->{'--language'}|| "";

  my $mnemo_MultipleStatementsOnSameLine = Ident::Alias_MultipleStatementsOnSameLine();
  my $status = 0;
  my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # Erreurs::LogInternalTraces

  my $nbr_MultipleStatementsOnSameLine= 0;
#  my $mnemo_compatibilite_MultInst = Ident::Alias_MultipleStatementsOnSameLine(); # compatibilite pour module calcul #bt_filter_line # Obsolete

  my $code = ${Vues::getView($vue, 'code')};

  if ( ! defined $code ) {
    $status |= Couples::counter_add($compteurs, $mnemo_MultipleStatementsOnSameLine, Erreurs::COMPTEUR_ERREUR_VALUE );
#    $status |= Couples::counter_add($compteurs, $mnemo_compatibilite_MultInst, Erreurs::COMPTEUR_ERREUR_VALUE ); # compatibilite pour module calcul #bt_filter_line # Obsolete
    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  # Ne pas aggrafer les '};', ce sont souvent des déclarations
  $code =~ s/\};/\}\n;/g;

  # Ne pas aggrafer les '} while();', ce sont souvent des 'do ... while ();'
  $code =~ s/^([\ \t]*)\}[\ \t]*(\bwhile\b[^;\{\n]*;)/$1\}\n$2/mg;

  my @LINES = split (/\n/, $code);
  my $ligne;
  my $line_number=0;
  foreach $ligne ( @LINES) {

    my $match = $ligne; # Erreurs::LogInternalTraces
    $line_number++;  # Erreurs::LogInternalTraces
    # Suppression des parentheses. Remplace par un espace pour eviter de "coller" 2 tokens
    while ( $ligne =~ s/\([^\(\)]*\)/ /sg ) {}

    # Ne pas aggrafer les '};', ce sont souvent des déclarations
    $ligne =~ s/\};/\}\n;/g;

    # Ne pas aggrafer les 'else if'
    $ligne =~ s/\belse\s+if\b/if/g;

    # Ne pas aggrafer les 'while/for (...) ;'
    $ligne =~ s/\b(while|for|foreach)\b\s+;/;/g;

    # Ne pas aggrafer les 'while/for/... (...) {\n'
    $ligne =~ s/\b(while|for|foreach|if|else|switch|try|catch|finally|do)\b\s*\{\s*$/\{/g;

    # Remplacement des structures de controle (sauf boucles) par des ';'
    $ligne =~ s/\b(if|else|switch|try|catch|finally|do)\b/;/g ;

    # Remplacement des mots cles de boucle par des ';' lorsque la boucle comprend au moins une instruction sur la meme ligne.
    $ligne =~ s/\b(while|for|foreach)\b(\s*[^\s;]+\s*;)/;$2/g ;

	if ($techno eq "CS") {
		# remove false positive due to getter/setter.
		# ex : public SelectList Medarbejdere { get; set; }
		$ligne =~ s/\b[gs]et\s*;\s*[sg]et\s*;//g;
	}

    # nombre de ';' sur la ligne
    my $nb = () = $ligne =~ /;/g ;

    if ($nb == 1) {
      # pris en compte de: ' { stmt; ' et ' stmt; } '
      $nb += () = $ligne =~ /\{|\}/g ;
    }

    if ($nb > 1) {
      # il y a plus d'un ';' sur la ligne
      $nbr_MultipleStatementsOnSameLine++;
      Erreurs::VIOLATION($mnemo_MultipleStatementsOnSameLine, "Several statements on line $line_number");
    }
  }

  $status |= Couples::counter_add($compteurs, $mnemo_MultipleStatementsOnSameLine, $nbr_MultipleStatementsOnSameLine);

  return $status;
}


1;
