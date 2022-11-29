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

package CountBasicTypeUses;
# les modules importes
use strict;
use warnings;
use Erreurs;
use TraceDetect;

# prototypes publics
sub Count_Cpp_BasicTypeUses($$$$);
sub Count_C_BasicTypeUses($$$$);

#-------------------------------------------------------------------------------
# DESCRIPTION:
# Module de comptage des utilisations de type de base
# Module de comptage des declarations de type structure
#
# COMPATIBILITE: C, CPP
#-------------------------------------------------------------------------------
sub Count_Cpp_BasicTypeUses ($$$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;
  return __CountBasicTypeUses($fichier, $vue, $compteurs, $options, 'Cpp');
}

sub Count_C_BasicTypeUses ($$$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;
  return __CountBasicTypeUses($fichier, $vue, $compteurs, $options, 'C');
}

sub __CountBasicTypeUses ($$$$$) {

  my ($fichier, $vue, $compteurs, $options, $langage) = @_ ;
  my $mnemo_BasicTypeUses = Ident::Alias_BasicTypeUses();
  my $mnemo_StructuredTypedefs = Ident::Alias_StructuredTypedefs();
  my $b_TraceDetect = ((exists $options->{'--TraceDetect'})? 1 : 0); # traces_filter_line
  my $trace_detect = '' if ($b_TraceDetect);                         # traces_filter_line
  my $base_filename = $fichier if ($b_TraceDetect);                  # traces_filter_line
  $base_filename =~ s{.*/}{} if ($b_TraceDetect);                    # traces_filter_line
  my $b_analyse_hpp_cpp = ($langage eq 'Hpp') || ($langage eq 'Cpp');

  my $status = 0;

  my $code = $vue->{'code'};

  if ( ! defined $code )
  {
    $status |= Couples::counter_add($compteurs, $mnemo_BasicTypeUses, Erreurs::COMPTEUR_ERREUR_VALUE );

    if ($b_analyse_hpp_cpp)
    {
      $status |= Couples::counter_add($compteurs, $mnemo_StructuredTypedefs, Erreurs::COMPTEUR_ERREUR_VALUE );
    }

    return $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $nbr_StructuredTypedefs = 0;

  if ($b_analyse_hpp_cpp)
  {
    # nombre de typedef struct
    $nbr_StructuredTypedefs = () = $code =~ /\btypedef\s+struct\b/sg ;
  }

  # Suppression des typedefs pour eviter de comptabiliser des bonnes utilisations des types de base
  $code =~ s/\b(typedef)(\s+(\w+))*/typedef .../sg ;

  $trace_detect .= "$base_filename:1:\n--- code source ---\n$code\n--- fin code source ---\n" if ($b_TraceDetect); # traces_filter_line

  # remplacement des types de base par une balise
  $code =~ s/\b(bool|char|short|int|long|signed|unsigned|float|double)\b/£/sg ;

  # $trace_detect .= "$base_filename:1:\n--- code source ---\n$code\n--- fin code source ---\n" if ($b_TraceDetect); # traces_filter_line

  # remplacement des suites de balises par une balise, pour ne compter que 1 quand 'unsigned int' est utilisé
  $code =~ s/£(\s*£)+/£/sg ;

  # $trace_detect .= "$base_filename:1:\n--- code source ---\n$code\n--- fin code source ---\n" if ($b_TraceDetect); # traces_filter_line

  # nombre d'utilisations de type de base en dehors d'une definition d'un nouveau type (typedef)
  my $nbr_BasicTypeUses = () = $code =~ /£/sg ;

  TraceDetect::DumpTraceDetect($fichier, $mnemo_BasicTypeUses, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
  $status |= Couples::counter_add($compteurs, $mnemo_BasicTypeUses, $nbr_BasicTypeUses);

  if ($b_analyse_hpp_cpp)
  {
    TraceDetect::DumpTraceDetect($fichier, $mnemo_StructuredTypedefs, $trace_detect, $options) if ($b_TraceDetect); # traces_filter_line
    $status |= Couples::counter_add($compteurs, $mnemo_StructuredTypedefs, $nbr_StructuredTypedefs);
  }

  return $status;
}


1;
