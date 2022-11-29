
package TSql::Identifier;

use strict;
use warnings;

use Exporter  'import';

our @ISA = qw(Exporter);
our @EXPORT = qw( $ROUTINE_NAME_PATTERN );

my $IDENT_CHAR='[\w$#@]';
my $DELIMITED_IDENT = '\[[^\]]+\]';

our $ROUTINE_NAME_PATTERN = "(?:(?:$IDENT_CHAR+(?:\\s*\\.\\s*$IDENT_CHAR+)?)|(?:$DELIMITED_IDENT(?:\\s*\\.\\s*$DELIMITED_IDENT)?))";



# For information :
#
# http://msdn.microsoft.com/fr-fr/library/ms175874.aspx
#
#Il existe deux classes d'identificateurs :
#
#Identificateurs r�guliers
#
#    Les identificateurs r�guliers respectent les r�gles relatives au format des identificateurs.Ils ne sont pas d�limit�s lorsqu'ils sont utilis�s dans des instructions Transact-SQL.
#
#    SELECT *
#    FROM TableX
#    WHERE KeyCol = 124
#
#Identificateurs d�limit�s
#
#    Les identificateurs d�limit�s sont mis entre guillemets (") ou entre crochets ([ ]).Les identificateurs qui respectent les r�gles relatives au format des identificateurs peuvent ne pas �tre d�limit�s.Exemple :
#
#    SELECT *
#    FROM [TableX]         --Delimiter is optional.
#    WHERE [KeyCol] = 124  --Delimiter is optional.
#
#    Ceux qui ne respectent pas ces r�gles ne peuvent �tre utilis�s dans une instruction Transact-SQL qu'en �tant d�limit�s.Exemple :
#
#    SELECT *
#    FROM [My Table]      --Identifier contains a space and uses a reserved keyword.
#    WHERE [order] = 10   --Identifier is a reserved keyword.
#
#Qu'ils soient r�guliers ou d�limit�s, les identificateurs doivent contenir de 1 � 128 caract�res.Dans le cas des tables temporaires locales, l'identificateur peut contenir jusqu'� 116 caract�res.
#
#
#--------------------------------------
#R�gles pour identificateurs r�guliers
#--------------------------------------
#
#Les r�gles relatives au format des identificateurs r�guliers d�pendent du niveau de compatibilit� de la base de donn�es.Ce niveau peut �tre d�fini au moyen de ALTER DATABASE.Lorsque le niveau de compatibilit� est 100, les r�gles applicables sont les suivantes :
#
#    Le premier caract�re doit �tre l'un des suivants :
#
#        une des lettres d�finies par Unicode Standard 3.2.Elles incluent les caract�res latins de a � z et de A � Z ainsi que des caract�res alphab�tiques d'autres langues.
#
#        Les symboles trait de soulignement (_), arobase (@) ou di�se (#).
#
#        Certains symboles au d�but d'un identificateur ont une signification particuli�re dans SQL Server.Un identificateur r�gulier qui commence par le signe arobase (@) d�note toujours une variable ou un param�tre local et ne peut pas �tre utilis� comme le nom d'un autre type d'objet.Un identificateur commen�ant par un symbole num�ro indique un objet temporaire (table ou proc�dure).Un identificateur commen�ant par le double signe # (##) indique un objet temporaire global.Bien que les symboles di�se (#) et double di�se (##) puissent �tre utilis�s pour commencer les noms d'autres types d'objets, nous ne recommandons pas cette pratique.
#
#        Le nom de certaines fonctions Transact-SQL commence par un double arobas (@@).Pour �viter toute confusion avec ces fonctions, n'utilisez pas de noms commen�ant par @@.
#
#    Les caract�res suivants peuvent inclure les �l�ments suivants :
#
#        Des lettres d�finies dans Unicode Standard 3.2.
#
#        Des nombres d�cimaux de Basic Latin ou d'autres scripts nationaux.
#
#        L'arobase, le symbole dollar ($), le symbole di�se ou le trait de soulignement.
#
#    L'identificateur ne doit pas �tre un mot r�serv� Transact-SQL.SQL Server conserve les majuscules et les minuscules des mots r�serv�s.
#
#    Les espaces incorpor�s ou les caract�res sp�ciaux ne sont pas autoris�s.
#
#    L'utilisation de caract�res suppl�mentaires n'est pas autoris�e.
#
#Un identificateur qui ne respecte pas toutes ces r�gles doit toujours �tre d�limit� par des crochets ou des guillemets doubles lors de son utilisation dans une instruction Transact-SQL.
#RemarqueRemarque
#
#Les noms de variables, de fonctions et de proc�dures stock�es doivent toujours respecter les r�gles portant sur les identificateurs Transact-SQL.


1;



