package Cpp::ParserIdents;

use strict;
use warnings;

my $parser_cpp = 0;
use constant PARSER_CPP_UNDEFINED => $parser_cpp++;
use constant PARSER_CPP_PROTOTYPE_KR => $parser_cpp++;
use constant PARSER_CPP_TYPEDEF_PTR_SUR_FONCTION => $parser_cpp++;
use constant PARSER_CPP_DECLARATION_VARIABLE_PTR_SUR_FONCTION => $parser_cpp++;
use constant PARSER_CPP_DECLARATION_FONCTION_OU_METHODE => $parser_cpp++;
use constant PARSER_CPP_FORWARD_DECLARATION_CLASS => $parser_cpp++;
use constant PARSER_CPP_TYPEDEF_SCALAIRE => $parser_cpp++;
use constant PARSER_CPP_FRIEND_CLASS => $parser_cpp++;
use constant PARSER_CPP_USING => $parser_cpp++;
use constant PARSER_CPP_DECLARATION_VARIABLE => $parser_cpp++;
use constant PARSER_CPP_DECLARATION_VARIABLE_FULL_LINE => $parser_cpp++;
use constant PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE => $parser_cpp++;
use constant PARSER_CPP_DECLARATION_CLASS => $parser_cpp++;
use constant PARSER_CPP_DECLARATION_STRUCT_AVEC_INIT => $parser_cpp++;
use constant PARSER_CPP_DECLARATION_STRUCT => $parser_cpp++;
use constant PARSER_CPP_DECLARATION_ENUM => $parser_cpp++;
use constant PARSER_CPP_DECLARATION_NAMESPACE => $parser_cpp++;
use constant PARSER_CPP_TEMPLATE_CLASSE => $parser_cpp++;
use constant PARSER_CPP_TEMPLATE_STRUCT => $parser_cpp++;
use constant PARSER_CPP_VAR_GLOB_INIT_ACCOLADE => $parser_cpp++;
use constant PARSER_CPP_ACCOL_OUVR_UNKNOWN => $parser_cpp++;
use constant PARSER_CPP_VISIBILITY => $parser_cpp++;
use constant PARSER_CPP_CLASS_END => $parser_cpp++;
use constant PARSER_CPP_IMPLEMENTATION_FONCTION_OU_METHODE_END => $parser_cpp++;

1;

