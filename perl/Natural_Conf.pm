package Natural_Conf;

use strict;
use warnings;
use Ident;

# Ne pas modifier ce fichier

# Composant: Plugin

our @table_Comptages = (

     [ Ident::Alias_LinesOfCode(), 'CountLinesOfCode', 'CountCommun', \&CountCommun::CountLinesOfCode, 'APPEL', 1 ],
     [ Ident::Alias_CommentBlocs(), 'CountCommentsBlocs', 'CountCommentsBlocs', \&CountCommentsBlocs::CountCommentsBlocs, 'APPEL', 1 ],
     [ Ident::Alias_BlankLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_CommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
     [ Ident::Alias_AlphaNumCommentLines(), 'CountCommun', 'CountCommun', \&CountCommun::CountCommun, 'APPEL', 1 ],
);

sub get_table_Comptages() {
  return \@table_Comptages;
}

our @table_Synth_Comptages = (
     # [ Ident::Alias_VG(), 'CountVG', 'Java::CountJava', \&Java::CountJava::CountVG, 'APPEL', 1 ],

);

sub get_table_Synth_Comptages() {
  return \@table_Synth_Comptages;
}

1;
