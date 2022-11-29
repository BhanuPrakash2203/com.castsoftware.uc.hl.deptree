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

# Composant: Framework
#----------------------------------------------------------------------#
# DESCRIPTION: Utilitaire de reconnaissance de langage
# base sur des mots clefs.
#----------------------------------------------------------------------#

package LangDetect;
# les modules importes
use strict;
use warnings;

# prototypes publics
sub AutodetectCCpp($);
sub AutodetectLanguage($);

# prototypes prives
#  aucun
sub AutodetectVB($);                                                            # bt_filter_line
sub AutodetectCobol_PrepareBuffer ($);                                          # bt_filter_line
sub AutodetectCobol($);                                                         # bt_filter_line
sub AutodetectLanguageFromBuffer($);                                            # bt_filter_line

# bt_filter_start

sub AutodetectVB($)
{
  my ($buffer) = @_;
  my $detectedLanguage = 'vb';
  # NB: pour le VB
  # les fichiers conteant PROCEDURE ou --region ou
  # SELECT ou GO sont susceptibles d'etre du
  # microsoft SQL .net
  if ($buffer =~ m/\bPROCEDURE\b/sgm) {
    $detectedLanguage = 'MsSqlDotNet';
  } elsif ($buffer =~ m/--region\b/sgm) {
    $detectedLanguage = 'MsSqlDotNet';

  # NB: pour le VB, eviter les fichiers commenceant par:
  # vti_encoding:
  } elsif ($buffer =~ m/\Avti_encoding:/sgm) {
    $detectedLanguage = 'vti inconnu';

  # NB: pour le vb, il peut s'agir de visual basic, comme
  # de electronic CAD board.
  #
  # // ProDesign CHIPit Gold Edition, Two XC2V6000-5
  # // Certify version 3.1 from Synplicity, Inc.
  # // Board
  # // Pro Design Electronic & CAD-Layout
  # `include "xilinx/plandata/xc2v6000ff1152.v"
  # // sram module
  # module sram (
  # endmodule
  } elsif ($buffer =~ m/`\s*include\b/sgm) {
    $detectedLanguage = 'electronic cad';
  } elsif ($buffer =~ m/\bendmodule\b/sgm) {
    $detectedLanguage = 'electronic cad';
  } else {
    $detectedLanguage = 'vb';
  }

  return $detectedLanguage;
}


# Fonction interne utilisee par AutodetectCobol
sub AutodetectCobol_PrepareBuffer ($)
{
  my ($RefBuf) =@_;
  $$RefBuf =~ s/\r//mg;
  #suppression des blancs de fin de ligne
  $$RefBuf =~ s/[ \t]*\n/ \n/mg;

  $$RefBuf =~ s/ID\s+DIVISION/IDENTIFICATION DIVISION/img;
  #  print $$RefBuf . "\n JENSUISLA\n\n";
  # suppression des 6 premiers
  # caracteres si PROCEDURE|IDENTIFICATION)\s+DIVISION est en colonne 7
  if ($$RefBuf =~ /^[^\*].....[ \t]+(PROCEDURE|IDENTIFICATION)\s+DIVISION/img)
  {
    #       $$RefBuf =~ s/^.?.?.?.?.?.?\n/       \n/mg;
    $$RefBuf =~ s/^.?.?.?.?.?.?//mg;
    #       $$RefBuf =~ s/\r//mg;
    #       print $$RefBuf ;
  }
  else
  {
    print STDERR "Ce fichier ne semble pas colonné en 6ieme colonne\n";
    print STDERR "Les colonnes n'ont pas été supprimées.\n";
    print STDERR "Vérifier le fichier et supprimer les colonnes " ;
    print STDERR      "manuellement si nécessaire.\n";
  }
  $$RefBuf =~ s/\r//mg;
  #suppression des 8 digits de fin de ligne
  $$RefBuf =~ s/\d\d\d\d\d\d\d\d\s*\n/\n/mg;

  # ESSAI suppression ligne continuation
  $$RefBuf =~ s/\n\-\s*([^\n]*)\n/$1\n\n/img;
}


# Autodetection du langage de programmation dans le fichier analyse.
# En se basant sur le fait que le fichier est soit cobol, soit pas cobol
sub AutodetectCobol($)
{
  my ($buffer) = @_;
  AutodetectCobol_PrepareBuffer (\$buffer);

  #Detection d'un programme ou d'un copy
  my $detectedLanguage = undef;
  my $type = undef;
  if ($buffer =~ m/^\s+(PROCEDURE|IDENTIFICATION)\s+DIVISION\s*\./sgm) {
    $detectedLanguage = "cobol";
  } else {
  }

  return $detectedLanguage;
}

# bt_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: Utilitaire de reconnaissance du langage C/C++
# Autodetection du langage de programmation dans le fichier analyse.
# En se basant sur le fait que le fichier est soit du c, soit du C++.
#-------------------------------------------------------------------------------
sub AutodetectCCpp($)
{
  my ($buffer) = @_;
  # Supprimer commentaires et chaines.
  $buffer =~  s{
                  (
                    \"(\\.|[^\"]*)*\"     |
                    \'(\\.|[^\']*)*\'     |
                    //[^\n]*              |
                    /\*.*?\*/
                  )
               }
               {
                 my $match = $1;
                 $match =~ s{\S+}{ }g;
                 $match =~ s{\n}{\\\n}g;
                 $match;
               }gxse;

  my $detectedLanguage = 'c';

  if ($buffer =~ m/::/sgm) {
      $detectedLanguage = 'c++';
  } elsif ($buffer =~ m/\bclass\s/sgm) {
      $detectedLanguage = 'c++';
  } elsif ($buffer =~ m/\bpublic\s*:/sgm) {
      $detectedLanguage = 'c++';
  } elsif ($buffer =~ m/\bprivate\s*:/sgm) {
      $detectedLanguage = 'c++';
  } elsif ($buffer =~ m/\bprotected\s*:/sgm) {
      $detectedLanguage = 'c++';
  } elsif ($buffer =~ m/\btemplate\b/sgm) {
      $detectedLanguage = 'c++';
  } elsif ($buffer =~ m/\soperator\s/sgm) {
      $detectedLanguage = 'c++';
  } elsif ($buffer =~ m/\bnew\s/sgm) {
      $detectedLanguage = 'c++';
  } elsif ($buffer =~ m/\bdelete\s/sgm) {
      $detectedLanguage = 'c++';
  } elsif ($buffer =~ m/\bnamespace\s/sgm) {
      $detectedLanguage = 'c++';
  }

  return $detectedLanguage;
}

# bt_filter_start

#-------------------------------------------------------------------------------
# DESCRIPTION: Autodetection du langage de programmation
# dans le fichier analyse.
#-------------------------------------------------------------------------------
sub AutodetectLanguageFromBuffer($)
{
  my ($buffer) = @_;
  my $detectedLanguage = undef;

#print ">>>>>>>>>>>>>>>\n" ;
#print $buffer ;
#print "<<<<<<<<<<<<<<<\n" ;

  if ($buffer =~ m/\A#![^\n]*perl\b/sm) {
      $detectedLanguage = 'perl';
  } elsif ($buffer =~ m/\A#![^\n]*python\b/sm) {
      $detectedLanguage = 'python';
  } elsif ($buffer =~ m/^\s*def\b[^\n]*:\s*\n/sm) {
      $detectedLanguage = 'python';
  } elsif ($buffer =~ m/\A#![^\n]*ksh\b/sm) {
      $detectedLanguage = "ksh";
  } elsif ($buffer =~ m/\A#![^\n]*sh\b/sm) {
      $detectedLanguage = "sh";
  } elsif ($buffer =~ m/\bif\s*\[/sm) {
      $detectedLanguage = "sh";
  } elsif ($buffer =~ m/^\s*for\b[^\n]*\bin\b/sm) {
      $detectedLanguage = "sh";
  } elsif ($buffer =~ m/^\s*fi\b/sm) {
      $detectedLanguage = "sh";
  } elsif ($buffer =~ m/^\s*esac\b/sm) {
      $detectedLanguage = "sh";
  } elsif ( ($buffer =~ m/\A\s*\z/sm) ) {
      $detectedLanguage = "empty";
  } elsif ( ($buffer =~ m/\A</sgm) && ($buffer =~ m{ />|</}sm) ) {
      $detectedLanguage = "xml";
  } elsif ($buffer =~ m/\A<\?xml/sgm)  {
      $detectedLanguage = "xml";
  #} elsif ( undef )  {                                                  #DEBUG
  #} elsif ( $buffer =~ m/\A(?:[^\n;]*;[^\n;]*;[^\n]*\n)+/mo )  {        #DEBUG
  } elsif ( not $buffer =~ m/^[^:\n]*(?:\S|:)[^:\n]*$/mso )  {           #DEBUG
      $detectedLanguage = "csv_col";
  } elsif ( not $buffer =~ m/^[^,\n]*(?:\S|,)[^,\n]*$/mso )  {           #DEBUG
      $detectedLanguage = "csv_com";
  } elsif ( not ( $buffer =~ m/^([^;\n]*(?:\S|;)[^;\n]*)$/sm ))  {       #DEBUG
  #} elsif ( not $buffer =~ m/([^;\n]*;?[^;\n]*)\n/sg )  {               #DEBUG
  #} elsif ( $buffer =~ m/\A((?:[^\n]*;[^\n]*;[^\n]*\n|\s*\n)*)/sgm )  { #DEBUG
print STDERR ">>>>>>>>>>>>>>> d1\n" ;
print STDERR "d1: " .  "\n" ;
print STDERR "<<<<<<<<<<<<<<< d1\n" ;
      $detectedLanguage = "csv_sem";
  # FIXME: } elsif (
  #     $buffer =~ m/\A(?:[^:\n]*:[^:\n]*:[^\n]*[\r\n]+|\s*[\n]+)*\z/sgm )
  # { #FIXME
      #$detectedLanguage = "csv";
  # FIXME: } elsif (
  #     $buffer =~ m/\A(?:[^,\n]*,[^,\n]*,[^\n]*[\r\n]+|\s*[\n]+)*\z/sgm )
  # { #FIXME
      #$detectedLanguage = "csv";
  # FIXME: } elsif (
  #     $buffer =~ m/\A(?:[^;\n]*;[^;\n]*;[^\n]*[\r\n]+|\s*[\n]+)*\z/sgm )
  # { #FIXME $detectedLanguage = "csv";
  } elsif ($buffer =~ m/^\s*Imports\s/sgmi) {
      $detectedLanguage = "vb";
  } elsif ($buffer =~ m/^\s*import\s/sgm)  {
      $detectedLanguage = "java";
  } elsif ($buffer =~ m/^\s*using\s*([a-z]*)/sgm)  {
      if ($1 eq 'namespace' )
      {
        $detectedLanguage = "c++";
      }
      else
      {
          $detectedLanguage = "cs";
      }
  } elsif ($buffer =~ m/^\s*#endregion\s/sgm)  {
      $detectedLanguage = "cs";
  } elsif ($buffer =~ m/^\s*package\s/sgm)  {
      $detectedLanguage = "java";
  } elsif ($buffer =~ m/^\bextends\s/sgm)  {
      $detectedLanguage = "java";
  } elsif ($buffer =~ m/^\binherits\s/sgm)  {
      $detectedLanguage = "java";
  } elsif ($buffer =~ m/::/sgm) {
      $detectedLanguage = "c++";
  } elsif ($buffer =~ m/public\s*:/sgm) {
      $detectedLanguage = "c++";
  } elsif ($buffer =~ m/->/sgm) {
      $detectedLanguage = "c or c++";
  } elsif ($buffer =~ m/^\s*#\s*define\s/sgm) {
      $detectedLanguage = "c or c++";
  } elsif ($buffer =~ m/^\s*#\s*include\s/sgm) {
      $detectedLanguage = "c or c++";
  } elsif ($buffer =~ m/^\s*#\s*ifdef\s/sgm) {
      $detectedLanguage = "c or c++";
  } elsif ($buffer =~ m/\btypedef\b/sgm) {
      $detectedLanguage = "c or c++";
  } elsif ($buffer =~ m/\bextern\b/sgm) {
      $detectedLanguage = "c or c++";
  } elsif ($buffer =~ m/(PROCEDURE|IDENTIFICATION)\s+DIVISION/sgm) {
      $detectedLanguage = "cobol";
  }

  if (defined $detectedLanguage ) {
    if ($detectedLanguage =~ m/c or c[+][+]/sgm) {
      if ($buffer =~ m/\bclass\b/sgm) {
          $detectedLanguage = "c++";
      } else {
          $detectedLanguage = "c";
      }
    }
  }
  #if ( defined $detectedLanguage )
  #{
    #print "detectedLanguage :" .  $detectedLanguage . "\n" ;
  #}
  #else
  #{
    #print "detectedLanguage :" .  'undetected' . "\n" ;
  #}
  return $detectedLanguage;
}

# bt_filter_end

#-------------------------------------------------------------------------------
# DESCRIPTION: Autodetection du langage de programmation dans le fichier analyse.
#-------------------------------------------------------------------------------
sub AutodetectLanguage($)
{
  my ($vue) = @_;
  my $buffer = substr ( $vue->{'text'}, 0, 20000);
  return AutodetectLanguageFromBuffer($buffer);
}

1;
