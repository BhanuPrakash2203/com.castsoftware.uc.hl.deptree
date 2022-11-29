# Composant: Plugin
# Description: Module de verification de l'adequation de l'analyseur pour le fichier.

package Abap::CheckAbap;

use SourceUnit;

sub FilterFile($)
{
  my ($name) = @_;
#
#  if ($name =~ /\.flow$/i ) {
#    return undef;
#  }
#
#  if ($name =~ /^SAP_R3WDYN_.*\.xml$/i ) {
#    # Abap dyn ...
#    return undef;
#  }
#
#
#  # name format for .abap file :
#  #  <root>[-=]*(
#  #              ([CI][OPTUI]+)      |     --> abap standard if [PT], else pool so do not analyze
#  #              (CCDEF|CCIMP|CCMAC) |     --> pool, do not analyze
#  #              (CMxxx)                   --> pool method, to be analyzed.
#  if ( $name =~ /([CI][PT]|CM...)\.abap$/i ) {
#    # Analyze only standard code and pool methods ...
#    return undef;
#  }
#
#  if ( ($name =~ /\.abap$/i ) && ($name !~ /^SAPLY/i ) ){
#    return undef;
#  }

  my $mode=SourceUnit::get_UnitInfo($name, 'mode');

  if ( (defined $mode) && ( $mode ==$SourceUnit::MODE_EXCLUDED )) {
    return 'Not a analyzable ABAP file';
  }
  else {
    return undef;
  }

}

1;
