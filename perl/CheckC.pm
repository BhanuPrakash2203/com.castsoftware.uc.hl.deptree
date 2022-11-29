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

package CheckC;


sub _DetectCplusplusKeywords($)
{
  my ($buffer) = @_;


  if ($buffer =~ m/::/sgm) {
      return 'contains ::';
  } elsif ($buffer =~ m/\bclass\s\s*\w/sgm) {
      return 'contains C++ class keyword';

# Descative en raison des trois cas suivants:
#   case public:
#   x = flag ? public : private;
#   x = { public:17, private:0 }; // initialisation par nommage de champs.


  #} elsif ($buffer =~ m/\bpublic\s*:/sgm) {
      #return 'contains C++ public declaration';
  #} elsif ($buffer =~ m/\bprivate\s*:/sgm) {
      #return 'contains C++ private declaration';
  #} elsif ($buffer =~ m/\bprotected\s*:/sgm) {
      #return 'contains C++ protected declaration';



  } elsif ($buffer =~ m/\btemplate\b\s*(?:\w|[<])/sgm) {
      return 'contains C++ template keyword';

# Desactive en regard des risques de faux positifs.
  #} elsif ($buffer =~ m/\soperator\s/sgm) {
      #return 'contains C++ operator keyword';

  } elsif ($buffer =~ m/\bnew\s\s*(?:\w|::)/sgm) {
      return 'contains C++ new operator';

# Desactive en regard des risques de faux positifs.
  #} elsif ($buffer =~ m/\bdelete\s\s*(?:\w|::)/sgm) {
      #return 'contains C++ delete operator';

  } elsif ($buffer =~ m/\bnamespace\s\s*(?:\w|::)/sgm) {
      return 'contains C++ namespace keyword';
  }

  return undef; # Pas d'erreur, le code ressemble a du code C.
}

sub CheckLanguageCompatibility($)
{
  my ($buffer) = @_;
  return ( _DetectCplusplusKeywords($buffer)  )
}


1;
