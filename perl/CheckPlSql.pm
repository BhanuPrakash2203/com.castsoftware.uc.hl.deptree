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

package CheckPlSql;

# Comptage des labels du style Transact-SQL
sub _CountMsTransactSqlStyleLabel($)
{
  my ($buffer) = @_;
  my $NbrMsTransactSqlStyleLabel = 0;
  my @items = split ( /(^.*:|goto\s*[a-zA-Z0-9]*)/im ,  $buffer );
  my %MsTransactLabel = ();
  my %MsTransactGoto = ();
  for my $item ( @items )
  {
#print STDERR "---\nITEM: " . $item . "\n" ;
    if ( $item =~ /^\s*([a-zA-Z0-9]*)\s*:[^=]/im  )
    {
      $MsTransactLabel{$1} = $1;
#print STDERR "MsTransactSqlStyleLabel label: $1\n";
    }
    elsif ( $item =~ /goto\s*([a-zA-Z0-9]*)/im  )
    {
      $MsTransactGoto{$1} = $1;
#print STDERR "MsTransactSqlStyleLabel goto : $1\n";
    }
  }
  for my $label ( keys (  %MsTransactGoto ) )
  {
    if (defined $MsTransactLabel{$label})
    {
      $NbrMsTransactSqlStyleLabel ++;
    }
  }
  return $NbrMsTransactSqlStyleLabel;
}

# Comptage des declarations du style Transact-SQL
sub _CountMsTransactSqlDeclareAt($)
{
  my ($buffer) = @_;
  my @x = $buffer =~ /\bdeclare\s*[@]/ismg;
  my $NbrDeclareAt = @x;
  return $NbrDeclareAt;
}

# Comptage des elseif du style Transact-SQL
sub _CountMsTransactSqlElseIf($)
{
  my ($buffer) = @_;
  
  # note : the robustness '^(?:\-[^\-]|[^\-])*?' has been added to prevent from comments side effects.
  #        See following example, found in client code :
  #
  #      END IF; -- 2.10.2003 Kuiis end
  #  ELSE
  #      IF W_PITA > 1 and W_PITA >= ind THEN
  
  my @x = $buffer =~ /^(?:\-[^\-]|[^\-])*?\bend\s*else\s+if\b/ismg;
   #my @x = $buffer =~ /\bend\s*else\s+if\b/ismg;
  my $NbrDeclareAt = @x;
  return $NbrDeclareAt;
}

# Comptage des go du style Transact-SQL
sub _CountMsTransactSqlGo($)
{
  my ($buffer) = @_;
  my @go = $buffer =~ /^[ ]*go\s*$/ismg;
  my $NbrGo = @go;
  return $NbrGo;
}

sub CheckLanguageCompatibility($)
{
  my ($buffer) = @_;
  if ( _CountMsTransactSqlStyleLabel($buffer) > 0 )
  {
    return "Microsoft Transact-SQL style label";
  }
  if ( _CountMsTransactSqlDeclareAt($buffer) > 0 )
  {
    return "Microsoft Transact-SQL style declaration";
  }
  if ( _CountMsTransactSqlElseIf($buffer) > 0 )
  {
    return "Microsoft Transact-SQL style control flow";
  }
  if ( _CountMsTransactSqlGo($buffer) > 0 )
  {
    return "Microsoft Transact-SQL style go";
  }
  return undef; # Pas d'erreur, le code ressemble a du code PlSql.
}


1;
