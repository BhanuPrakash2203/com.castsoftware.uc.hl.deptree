
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
#Identificateurs réguliers
#
#    Les identificateurs réguliers respectent les règles relatives au format des identificateurs.Ils ne sont pas délimités lorsqu'ils sont utilisés dans des instructions Transact-SQL.
#
#    SELECT *
#    FROM TableX
#    WHERE KeyCol = 124
#
#Identificateurs délimités
#
#    Les identificateurs délimités sont mis entre guillemets (") ou entre crochets ([ ]).Les identificateurs qui respectent les règles relatives au format des identificateurs peuvent ne pas être délimités.Exemple :
#
#    SELECT *
#    FROM [TableX]         --Delimiter is optional.
#    WHERE [KeyCol] = 124  --Delimiter is optional.
#
#    Ceux qui ne respectent pas ces règles ne peuvent être utilisés dans une instruction Transact-SQL qu'en étant délimités.Exemple :
#
#    SELECT *
#    FROM [My Table]      --Identifier contains a space and uses a reserved keyword.
#    WHERE [order] = 10   --Identifier is a reserved keyword.
#
#Qu'ils soient réguliers ou délimités, les identificateurs doivent contenir de 1 à 128 caractères.Dans le cas des tables temporaires locales, l'identificateur peut contenir jusqu'à 116 caractères.
#
#
#--------------------------------------
#Règles pour identificateurs réguliers
#--------------------------------------
#
#Les règles relatives au format des identificateurs réguliers dépendent du niveau de compatibilité de la base de données.Ce niveau peut être défini au moyen de ALTER DATABASE.Lorsque le niveau de compatibilité est 100, les règles applicables sont les suivantes :
#
#    Le premier caractère doit être l'un des suivants :
#
#        une des lettres définies par Unicode Standard 3.2.Elles incluent les caractères latins de a à z et de A à Z ainsi que des caractères alphabétiques d'autres langues.
#
#        Les symboles trait de soulignement (_), arobase (@) ou dièse (#).
#
#        Certains symboles au début d'un identificateur ont une signification particulière dans SQL Server.Un identificateur régulier qui commence par le signe arobase (@) dénote toujours une variable ou un paramètre local et ne peut pas être utilisé comme le nom d'un autre type d'objet.Un identificateur commençant par un symbole numéro indique un objet temporaire (table ou procédure).Un identificateur commençant par le double signe # (##) indique un objet temporaire global.Bien que les symboles dièse (#) et double dièse (##) puissent être utilisés pour commencer les noms d'autres types d'objets, nous ne recommandons pas cette pratique.
#
#        Le nom de certaines fonctions Transact-SQL commence par un double arobas (@@).Pour éviter toute confusion avec ces fonctions, n'utilisez pas de noms commençant par @@.
#
#    Les caractères suivants peuvent inclure les éléments suivants :
#
#        Des lettres définies dans Unicode Standard 3.2.
#
#        Des nombres décimaux de Basic Latin ou d'autres scripts nationaux.
#
#        L'arobase, le symbole dollar ($), le symbole dièse ou le trait de soulignement.
#
#    L'identificateur ne doit pas être un mot réservé Transact-SQL.SQL Server conserve les majuscules et les minuscules des mots réservés.
#
#    Les espaces incorporés ou les caractères spéciaux ne sont pas autorisés.
#
#    L'utilisation de caractères supplémentaires n'est pas autorisée.
#
#Un identificateur qui ne respecte pas toutes ces règles doit toujours être délimité par des crochets ou des guillemets doubles lors de son utilisation dans une instruction Transact-SQL.
#RemarqueRemarque
#
#Les noms de variables, de fonctions et de procédures stockées doivent toujours respecter les règles portant sur les identificateurs Transact-SQL.


1;



