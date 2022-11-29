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
#----------------------------------------------------------------------#
# DESCRIPTION: Composant de verification du codage binaire d'un fichier source
#----------------------------------------------------------------------#

package CountBinaryFile;

use strict;
use warnings;
use Erreurs;

use Timing; # timing_filter_line

# prototypes publics
sub CountBinaryFile($$$);

# prototypes prives
sub bytes_count_re_2($$);
sub bytes_count_re($$);
sub bytes_match_re($$);
sub detect_control_characters($);
sub number_gt_half($);
sub detectIncompatibleNewLines($);
sub detectIncompatibleIndentation($);
sub detectIncompatibleEncoding($);
sub detectIncompatibleByteSequence($);


#-------------------------------------------------------------------------------
# DESCRIPTION: Compte le nombre d'expressions regulieres
#-------------------------------------------------------------------------------
sub bytes_count_re_2($$)
{
use bytes;
  my ($sca, $re) = @_ ;
  my $n = 0;
  while  ( $sca =~ m/$re/smg )
  {
    $n ++;
  }
  return $n;
no bytes;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Compte le nombre d'expressions regulieres
# sur une chaine d'octets
#-------------------------------------------------------------------------------
sub bytes_count_re($$)
{
  my ($sca, $re) = @_ ;
  my $n ;
use bytes;
  $n = () = $sca =~ /$re/smg ;
no bytes;
  return $n;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Sur une chaine d'octets
# detection du matche d'expressions regulieres
#-------------------------------------------------------------------------------
sub bytes_match_re($$)
{
  my ($sca, $re) = @_ ;
  my $n ;
use bytes;
  if ( $sca =~ /$re/sm) 
  {
    $n = 1;
  }
  else
  {
    $n = 0;
  }
no bytes;
  return $n;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Recherche de la presence de caracteres de controle
#-------------------------------------------------------------------------------
sub detect_control_characters($)
{
use bytes;
  my ($buffer) = @_;
  # caracteres de controle (connue sous le nom de C0)  Sauf: 0x09 (tab) 0x0a (lf) 0x0d (cr)
  my $re_control = '(?:[\x{0}-\x{08}\x{0b}\x{0c}\x{0e}-\x{1f}])';
  if  ( $buffer =~ m/$re_control$re_control/smgo )
  {
    return 1;
  }
  else
  {
    return 0;
  }
no bytes;
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Transforme un flottant en booleen en le comparant à 0.5
#-------------------------------------------------------------------------------
sub  number_gt_half($)
{
  my ($nb) = @_;
  if ($nb gt 0.5)
  {
    return 1;
  }
  else
  {
    return 0;
  }
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Detecte le melange de retours a la ligne, en se basant sur le 
# nombre de sequences correspondants a des retours a la ligne distincts
#-------------------------------------------------------------------------------
sub detectIncompatibleNewLines($)
{
  my ($sca) = @_ ;
  my $n =0;
#print "\nrecherche CRLF\n";                                                   # Erreurs::LogInternalTraces
  my $n_crlf =  bytes_match_re($sca, '\x{0d}\n' );
#print "\nrecherche CR\n";                                                     # Erreurs::LogInternalTraces
  my $n_cr =  bytes_match_re($sca, '\x{0d}(?:[^\n])' ); 
#print "\nrecherche LF\n";                                                     # Erreurs::LogInternalTraces
  my $n_lf =  bytes_match_re($sca, '(?:[^\x{0d}]|\A)\n' );
#print "\ncount \n";                                                           # Erreurs::LogInternalTraces
  #print "HASH.*using_incompatible_byte_sequence...   $n_crlf  $n_cr   $n_lf  DEBUG\n"; # Erreurs::LogInternalTraces
  my $incompatible = $n_crlf * $n_cr + $n_lf * $n_crlf  + $n_cr *  $n_lf ;
  return number_gt_half($incompatible);
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Detecte la presence de sequences correspondants a des 
# indentations distinctes
#-------------------------------------------------------------------------------
sub detectIncompatibleIndentation($)
{
  my ($sca) = @_ ;
  my $n =0;
  my $n_indent_esp =  bytes_match_re($sca, '^ +\S' );
  my $n_indent_tab =  bytes_match_re($sca, '^[\t]+\S' );
  my $n_indent_esp_or_tab =  bytes_match_re($sca, '^[ \t]+\S' );
  my $n_indent_misc =  bytes_match_re($sca, '^\s+\S' );

  my $incompatible = $n_indent_esp * $n_indent_tab +
                       ( $n_indent_misc - $n_indent_esp_or_tab );

  #my $n_esp =  bytes_match_re($sca, '^\s*? [^\n]*\S' );                     # Erreurs::LogInternalTraces
  #my $n_tab =  bytes_match_re($sca, '^\s*?[\t][^\n]*\S' );                  # Erreurs::LogInternalTraces
  #my $incompatible = $n_esp * $n_tab ;                                      # Erreurs::LogInternalTraces
  return number_gt_half($incompatible);
}

#-------------------------------------------------------------------------------
# DESCRIPTION: Detecte la presence de sequences correspondants a des encodages distincts
#-------------------------------------------------------------------------------
sub detectIncompatibleEncoding($)
{
  my ($sca) = @_ ;
  my $n =0;
  # expression rationnelle pour les caracteres
  #  U+20AC EURO SIGN
  #  U+00E9 LATIN SMALL LETTER E WITH ACUTE
  #  U+00E8 LATIN SMALL LETTER E WITH GRAVE
  #  U+00E0 LATIN SMALL LETTER A WITH GRAVE
  #  U+00E0 LATIN SMALL LETTER A WITH GRAVE
  #  U+00E7 LATIN SMALL LETTER C WITH CEDILLA
  #  U+00E2 LATIN SMALL LETTER A WITH CIRCUMFLEX
  #  U+00EA LATIN SMALL LETTER E WITH CIRCUMFLEX
  #  U+00EE LATIN SMALL LETTER I WITH CIRCUMFLEX
  #  U+00F4 LATIN SMALL LETTER O WITH CIRCUMFLEX
  #  U+00FB LATIN SMALL LETTER U WITH CIRCUMFLEX
  #  U+00E4 LATIN SMALL LETTER A WITH DIAERESIS
  #  U+00EB LATIN SMALL LETTER E WITH DIAERESIS
  #  U+00EF LATIN SMALL LETTER I WITH DIAERESIS
  #  U+00F6 LATIN SMALL LETTER O WITH DIAERESIS
  #  U+00FC LATIN SMALL LETTER U WITH DIAERESIS

  # code en utf8
  #print "\ncompose utf8\n";                                                   # Erreurs::LogInternalTraces
  my $re_utf8_char = '\x{e2}\x{82}\x{ac}|' .
                '\x{c3}\x{a9}|' .
                '\x{c3}\x{a8}|' .
                '\x{c3}\x{a0}|' .
                '\x{c3}\x{a0}|' .
                '\x{c3}\x{a7}|' .
                '\x{c3}\x{a2}|' .
                '\x{c3}\x{aa}|' .
                '\x{c3}\x{ae}|' .
                '\x{c3}\x{b4}|' .
                '\x{c3}\x{bb}|' .
                '\x{c3}\x{a4}|' .
                '\x{c3}\x{ab}|' .
                '\x{c3}\x{af}|' .
                '\x{c3}\x{b6}|' .
                '\x{c3}\x{bc}' ;

  # Representation binaire UTF-8         Signification
  # 0xxxxxxx         1 octet codant 1 a 7 bits
  # 110xxxxx 10xxxxxx         2 octets codant 8 a 11 bits
  # 1110xxxx 10xxxxxx 10xxxxxx         3 octets codant 12 a 16 bits
  # 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx         4 octets codant 17 a 21 bits
  #
  # On recherche donc les sequences echappant a cette regles, a savoir:
  # 0xxxxxxx 10xxxxxx
  # 11xxxxxx 0xxxxxxx
  # 11xxxxxx 11xxxxxx
  my $re_nonutf8_char = '[\x{00}-\x{7f}][\x{80}-\x{bf}]|[\x{c0}-\x{ff}][\x{00}-\x{7f}\x{c0}-\x{ff}]' ;

  #print "\ncompose latin1\n";                                                 # Erreurs::LogInternalTraces
  # On ne prend pas \x{ef} a cause du BOM
  my $re_windows_1252 = '(?:[\x{20}-\x{7f}\n]|^|\A)'.
       '(?:\x{e9}|\x{80}|\x{e0}|\x{e8}|\x{e7}|\x{e0}|\x{ea}|\x{e2}[^\x{82}]|\x{f4}|\x{ee}|\x{e4}|\x{fb}|\x{eb}|\x{fc}|\x{f6}:)';
  #my $re_windows_1252 =                                                       # Erreurs::LogInternalTraces
    #'(?:\x{e9}|\x{80}|\x{e0}|\x{e8}|\x{e7}|\x{e0}|\x{ea}|\x{f4}|\x{ee}|\x{e4}|\x{fb}|\x{ef}|\x{eb}|\x{fc}|\x{f6})'; # Erreurs::LogInternalTraces
  #print "\nrecherche bom\n";                                                  # Erreurs::LogInternalTraces

  my $n_utf8_bom = bytes_match_re($sca, '\A\x{ef}\x{bb}\x{bf}' ); #utf-8_bom
  my $n_utf8_replacement = bytes_match_re($sca, '\x{ef}\x{bf}\x{bd}' ); # U+FFFD REPLACEMENT CHARACTER
  my $incompatible ;

  if ( $n_utf8_replacement )
  {
    $incompatible = 1 ;
  }
  else
  {
    #print "\nrecherche latin1\n";                                             # Erreurs::LogInternalTraces
    #my $n_latin1 = bytes_count_re($sca, $re_windows_1252 );                   # Erreurs::LogInternalTraces
    my $n_latin1 = bytes_match_re($sca, $re_nonutf8_char );
    #print "\nrecherche utf8\n";                                               # Erreurs::LogInternalTraces
    my $n_utf8   = 0;
    if (  $n_utf8_bom gt 0.5  )
    {
      $n_utf8 = bytes_match_re($sca, $re_utf8_char );
    }
    $incompatible = $n_latin1 * ( $n_utf8 + $n_utf8_bom ) ;
  }
  return number_gt_half($incompatible);
}


#-------------------------------------------------------------------------------
# DESCRIPTION: Detecte la presence de sequences d'octets incoherentes
#-------------------------------------------------------------------------------
sub detectIncompatibleByteSequence($)
{
  my ($sca) = @_ ;
  my $n = 0;
  my $incompatibleByteSequenceTiming = new Timing ( 'incompatibleByteSequenceTiming', Timing->isSelectedTiming ('Algo') );
#print "\nrecherche incompatible newline\n";                                   # Erreurs::LogInternalTraces
  $n += 1 * detectIncompatibleNewLines($sca) ;
  $incompatibleByteSequenceTiming->markTime('detectIncompatibleNewLines');              # timing_filter_line
#print "\nrecherche incompatible indentation\n";                               # Erreurs::LogInternalTraces
  $n += 1 * detectIncompatibleIndentation($sca) ;
  $incompatibleByteSequenceTiming->markTime('detectIncompatibleIndentation');           # timing_filter_line
#print "\nrecherche incompatible encoding\n";                                  # Erreurs::LogInternalTraces
  $n += 1 * detectIncompatibleEncoding($sca) ;
  $incompatibleByteSequenceTiming->markTime('detectIncompatibleEncoding');              # timing_filter_line
  $incompatibleByteSequenceTiming->dump('CountBinary');                                 # timing_filter_line

  return $n;
}


#-------------------------------------------------------------------------------
# Fonction   : CountBinaryFile
# Parametres : nom du fichier traite.
#              vues sur le contenu du fichier traite.
#              table de hachage des couples elementaires.
# Retour     : 0 si succes;
#              1 si au moins 1 comptage a echoue;
#              2 si une vue necessaire aux comptages manque;
#              4 en cas d'erreur d'interface avec la gestion de couples
#              elementaires; 64 en cas d'erreur non caracterisee
#
# DESCRIPTION: Compte Nbr_HeterogeneousEncoding
#-------------------------------------------------------------------------------
sub CountBinaryFile($$$)
{
  my ($fichier, $vues, $compteurs) = @_;
  my $echecs = 0;
  my $mnemo = Ident::Alias_HeterogeneousEncoding() ;
  my $status = 0;

  return Erreurs::COMPTEUR_STATUS_VUE_ABSENTE if ( not defined $vues );
  return Erreurs::COMPTEUR_STATUS_VUE_ABSENTE if ( not defined $vues->{'bin'} );

  my $n = detectIncompatibleByteSequence( $vues->{'bin'} );
  $status |= Couples::counter_add($compteurs, $mnemo, $n);

  return $status;
}


1;
