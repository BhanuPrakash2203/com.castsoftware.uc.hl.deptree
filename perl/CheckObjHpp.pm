# Composant: Plugin
# Description: Module de verification de l'adequation de l'analyseur pour le fichier.

package CheckObjHpp;

use technos::id;

sub _DetectObjcClassKeywords($)
{
  my ($buffer) = @_;

  if ($buffer !~ m/\@(?:interface)\b/sgm) {
      return 'does not contain Objective C/C++ class';
  }

  return undef; # Pas d'erreur, le code ressemble a un fichier declarant une classe.
}

sub CheckCodeAvailability($)
{
  my ($buffer) = @_;
  return ( _DetectObjcClassKeywords($buffer)  )
}

1;
