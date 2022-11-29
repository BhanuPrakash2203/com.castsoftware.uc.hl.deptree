
package JS::CountNaming ;

use strict;
use warnings;

use Erreurs;
use Lib::NodeUtil;
use JS::JSNode;

use Ident;
use JS::Identifiers;

my $IDENTIFIER = JS::Identifiers::getIdentifiersPattern();
my $IDENT_CHAR = JS::Identifiers::getIdentifiersCharacters();

my $mnemo_ShortFunctionNamesLT = Ident::Alias_ShortFunctionNamesLT();
my $mnemo_BadFunctionNames = Ident::Alias_BadFunctionNames();
my $mnemo_ShortAttributeNamesLT = Ident::Alias_ShortAttributeNamesLT();
my $mnemo_BadAttributeNames = Ident::Alias_BadAttributeNames();
my $mnemo_ShortParameterNamesLT = Ident::Alias_ShortParameterNamesLT();

my $nb_ShortFunctionNamesLT = 0;
my $nb_BadFunctionNames = 0;
my $nb_ShortAttributeNamesLT = 0;
my $nb_BadAttributeNames = 0;
my $nb_ShortParameterNamesLT = 0;

my $mnemo_PublicAttributes = Ident::Alias_PublicAttributes();
my $nb_PublicAttributes = 0;

my $mnemo_TotalParameters = Ident::Alias_TotalParameters();
my $nb_TotalParameters = 0;

my $SumSizeAttributesNames = 0;
my $SumSizeFunctionsNames = 0;
my $SumSizeParametersNames = 0;

my %SHORT_ATTRIBUTE_EXCEPTION = (
	'min' => 1,
	'max' => 1,
	'key' => 1,
	'top' => 1,
	'set' => 1,
	'get' => 1,
	'push' => 1,
	'add' => 1,
	'sub' => 1,
	'data' => 1,
	'type' => 1,
	'row' => 1,
	'left' => 1,
	'stop' => 1,
	'root' => 1,
	'base' => 1,
	'end' => 1,
);

sub isShortAttributeException($) {
  my $name = shift;
  if (exists $SHORT_ATTRIBUTE_EXCEPTION{lc($$name)}) {
    return 1;
  }
  return 0;
}

sub checkAttributeName($) {
  my $name = shift;

  # no leading underscore.
  # camel notation.
  if ($$name !~ /^_/m) {
    
    return 0;
  }

  return 1;
}

sub checkParameterName($) {
  my $name = shift;

  # no leading underscore.
  # camel notation.
  if ( ($$name !~ /^[a-z][a-z0-9_]*(?:[A-Z][a-z0-9_]*)*/m) ||
       (length $$name <3)) {
    return 0;
  }

  return 1;
}

sub checkLocalVarNaming($) {
  my $name = shift;

  # should contains at least one minus ...
  if ($$name =~ /[a-z]/m) {
    return 0;
  }
  # unless containing no letter !!
  elsif ($$name !~ /[A-Z]/m) {
    return 0;
  }
#print "  --> bad local variable name !!\n";
  return 1;
}

sub checkGlobalVarNaming($) {
  my $name = shift;

  # should NOT contain minus ...
  if ($$name =~ /[a-z]/m) {
#print "  --> bad global variable name !!\n";
    return 1;
  }
  return 0;
}

sub checkCamelCase($) {
  my $name = shift;

  # leading underscore possible.
  # camel notation.
  if ($$name =~ /^[a-z_][a-z0-9_]*(?:[A-Z][a-z0-9_]*)*/m) {
    return 0;
  }
#print "  --> not camel case : $$name !!\n";
  return 1;
}

sub isNameTooShort($$) {
  my $r_name = shift;
  my $limit = shift;

  if ( length $$r_name < $limit ) {
#print "  --> too short (length < $limit): $$r_name !!\n";
    return 1;
  }
  return 0;
}


sub checkParameterNaming($) {
  my $r_paramList = shift;

  if ($$r_paramList =~ /\S/) {
    my @params = split ',', $$r_paramList;

    for my $param (@params) {
      $param =~ s/^\s*//sm;
      $param =~ s/\s*$//sm;

      $SumSizeParametersNames += length $param;

      $nb_TotalParameters++;
    }
  }
}

sub isConstrutor($$) {
  my $name = shift;
  my $fullFile = shift;

  my $code = \$fullFile->{'code'};
  
  if ( $$code =~ /\bnew\s+$$name\b|\b$$name\.prototype\b/s) {
    return 1;
  }

  return 0;
}

sub CountNaming($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;
  my $status = 0;
  $nb_ShortFunctionNamesLT = 0;
  $nb_BadFunctionNames = 0;
  $nb_ShortAttributeNamesLT = 0;
  $nb_BadAttributeNames = 0;
  $nb_ShortParameterNamesLT = 0;
  $nb_PublicAttributes = 0;
  $nb_TotalParameters = 0;

  $SumSizeAttributesNames = 0;
  my $nbAttributes = 0;

  $SumSizeFunctionsNames = 0;
  my $nbFunctions = 0;

  $SumSizeParametersNames = 0;

  if (not defined $vue->{'structured_code'})
  {
      $status |= Couples::counter_add ($compteurs, $mnemo_ShortFunctionNamesLT , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BadFunctionNames , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_ShortAttributeNamesLT , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BadAttributeNames , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_ShortParameterNamesLT , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_PublicAttributes , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_TotalParameters , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
  }

  my $root = $vue->{'structured_code'};

  # FUNCTION DECLARTION
  # -----------------------------------------------------------------------
  my @funcs = @{$vue->{'KindsLists'}->{'FunctionDeclaration'}};

  my $fullFileViews = $vue->{'full_file'};
  for my $func (@funcs) {
    ${GetStatement($func)} =~ /\bfunction\s+($IDENTIFIER)?\s*\((.*)\)\s*$/sm;

    my $paramList = $2;

    if (defined $1) {
      # it is not a anonymous function
      my $name = $1;

#print "FUNCTION ...\n";
      $SumSizeFunctionsNames += length $name;
      $nbFunctions++;

      if ( (!defined $fullFileViews) || (! isConstrutor(\$name, $fullFileViews))) {
        $nb_BadFunctionNames += checkCamelCase(\$name); 
      }
#print ".... FUNCTION\n";
    }

    # PARAMETERS (function declaration)
    # --------------------------------------------------
    if (defined $paramList) {
      checkParameterNaming(\$paramList);
    }
  }

  # FUNCTION EXPRESSION
  # -----------------------------------------------------------------------
  @funcs = @{$vue->{'KindsLists'}->{'FunctionExpression'}};
  for my $func (@funcs) {

    ${GetStatement($func)} =~ /\bfunction\s+($IDENTIFIER)?\s*\((.*)\)\s*$/sm;

    my $paramList = $2;

    # PARAMETERS (function expression)
    # --------------------------------------------------
    if (defined $paramList) {
      checkParameterNaming(\$paramList);
    }
  }

  # PROPERTIES
  # -----------------------------------------------------------------------
  my @props = GetNodesByKind($root, MemberKind);
  
  for my $prop (@props) {
    my $name = GetName($prop);

#-------------------------------------------------------------------------
#  NOTE : methods are assimiled to simple property. 
#-------------------------------------------------------------------------
#    # The type of the property depends on what is child is (a property has 
#    # only one child, at offset 0 in his children list !!) 
#    my $memberType = GetChildren($prop)->[0]);
#
#    if (IsKind($memberType, FunctionExpressionKind)) {
#      $nb_ShortFunctionNamesLT += isNameTooShort(\$name, LIMIT_SHORT_METHOD_NAMES);
#      $nb_BadFunctionNames += checkCamelCase(\$name); 
#    }
#    else {

      $SumSizeAttributesNames += length $name;
      $nbAttributes++;

      $nb_PublicAttributes++;

      $nb_BadAttributeNames += checkCamelCase(\$name); 
#    }
#-------------------------------------------------------------------------
  }

  if ($nbAttributes) {
    $nb_ShortAttributeNamesLT =  int ($SumSizeAttributesNames / $nbAttributes);
  }

  if ($nbFunctions) {
    $nb_ShortFunctionNamesLT =  int ($SumSizeFunctionsNames / $nbFunctions);
  }

  if ($nb_TotalParameters) {
    $nb_ShortParameterNamesLT =  int ($SumSizeParametersNames / $nb_TotalParameters);
  }

  $status |= Couples::counter_add ($compteurs, $mnemo_ShortFunctionNamesLT, $nb_ShortFunctionNamesLT);
  $status |= Couples::counter_add ($compteurs, $mnemo_BadFunctionNames, $nb_BadFunctionNames);
  $status |= Couples::counter_add ($compteurs, $mnemo_ShortAttributeNamesLT, $nb_ShortAttributeNamesLT);
  $status |= Couples::counter_add ($compteurs, $mnemo_BadAttributeNames, $nb_BadAttributeNames);
  $status |= Couples::counter_add ($compteurs, $mnemo_ShortParameterNamesLT, $nb_ShortParameterNamesLT);
  $status |= Couples::counter_add ($compteurs, $mnemo_PublicAttributes, $nb_PublicAttributes);
  $status |= Couples::counter_add ($compteurs, $mnemo_TotalParameters, $nb_TotalParameters);
  return $status;
}

1;
