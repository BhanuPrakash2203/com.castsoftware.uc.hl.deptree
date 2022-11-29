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
#
# Description: Composant de comptages sur code source COBOL

package Cobol::violation;

# Ajout 06 03 27
sub violation {
  my($rule, $filename, $lineno, $param)=(@_);
#  Erreurs::LogInternalTraces("VIOLATION",$filename,$lineno,$rule,$param);
# print "$filename:$lineno:$rule:$param.\n";
}
sub metrique {
  my($rule, $filename, $lineno, $param)=(@_);

# print "$filename:$lineno:$rule:$param\n";
}
sub violationdebug {
  my($rule, $filename, $lineno, $param)=(@_);

#print "$filename:$lineno:$rule:$param.\n";
}
sub violationdebug2 {
  my($rule, $filename, $lineno, $param)=(@_);
#  Erreurs::LogInternalTraces("DEBUG2",$filename,$lineno,$rule,$param);
}
sub violationInfo {
  my($rule, $filename, $lineno, $param)=(@_);

# print "$filename:$lineno:$rule:$param.\n";
}

sub violation2 {
  my($rule, $filename, $lineno, $param)=(@_);

#   print "$filename:$lineno:$rule:v2:$param.\n";
}
sub violation4 {
  my($rule, $filename, $lineno, $param)=(@_);
#  Erreurs::LogInternalTraces("VIOLATION4",$filename,$lineno,$rule,$param);

}

sub violationavoir {
  my($rule, $filename, $lineno, $param)=(@_);

#   print "$filename:$lineno:$rule:$param.\n";
}

sub genereC {
  my($rule, $filenameout, $code, $filenamein, $lineno, $param)=(@_);
#print "$code //$rule: $filenameout $filenamein  #line $lineno $param.\n";
#   print $filenameout "$filenamein:$lineno:CODE:$code //$rule: $filenamein #line $lineno $param.\n";
}

1;
#                genereC("CODE",C,  " }", $FICHIER, $CptLine, "");
