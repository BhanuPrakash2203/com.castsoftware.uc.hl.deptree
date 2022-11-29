# Composant: Plugin
# Description: Module de verification de l'adequation de l'analyseur pour le fichier.

package TSql::CheckTSql;

sub CheckCodeAvailability($)
{
  my ($buffer) = @_;

  if ($buffer =~ /\A(.*?) : insufficient code for HIGHLIGHT analysis./sm)
  {
    return 'None bloc of code';
  }
  return undef;
}

1;
