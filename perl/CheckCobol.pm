
#----------------------------------------------------------------------#
#                         @ISOSCOPE 2008                               #
#----------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                  #
#               Adresse : TERSUD - Bat A                               #
#                         5, AVENUE MARCEL DASSAULT                    #
#                         31500  TOULOUSE                              #
#               SIRET   : 410 630 164 00037                            #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Plugin
# Description: Module de verification de l'adequation de l'analyseur pour le fichier.

package CheckCobol;

use Cobol::Vue;

# On verifie qu'il s'agit d'un fichier cobol 
# contenant du code analysable.
sub CheckCodeAvailability($)
{
  my ($buf) = @_;

  # Copy the buffer.
  my $buffer = $$buf;

  my $fixForm = Cobol::Vue::PrepareBuffer (\$buffer);

  #Detection d'un programme ou d'un copy
  my $type = undef;

  if ($buffer =~ m/^\s+(PROCEDURE|IDENTIFICATION)\s+DIVISION\s*\./sm) {
    return undef;
  }
  elsif ($fixForm eq 1) {
    return undef;
  }
  elsif ($buffer =~ m/^\s*(?:IF|MOVE|PERFORM|CALL|RETURN|EVALUATE)\b/ism) {
    return undef;
  }
  elsif ($buffer =~ m/^ 01\s+[\w\-]*.*\.\s*$/ism) {
    return undef;
  }
  else {
    return 'No or insufficient cobol patterns found';
  }

}

1;

