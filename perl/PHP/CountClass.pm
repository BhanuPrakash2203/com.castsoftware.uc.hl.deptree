package PHP::CountClass;
# les modules importes
use strict;
use warnings;
use Carp::Assert; # traces_filter_line
use Erreurs;
use Couples;

use PHP::PHPNode;

my $UnnecessaryFinalModifier__mnemo = Ident::Alias_UnnecessaryFinalModifier();
my $UnassignedObjectInstanciation__mnemo = Ident::Alias_UnassignedObjectInstanciation();
my $UselessOverridingMethod__mnemo = Ident::Alias_UselessOverridingMethod();
my $BadClassNames__mnemo = Ident::Alias_BadClassNames();
my $ClassNameIsNotFileName__mnemo = Ident::Alias_ClassNameIsNotFileName();
my $BadConstructorNames__mnemo = Ident::Alias_BadConstructorNames();
my $ConstructorWithReturn__mnemo = Ident::Alias_ConstructorWithReturn();
my $MissingSetter__mnemo = Ident::Alias_MissingSetter();

my $nb_UnnecessaryFinalModifier = 0;
my $nb_UnassignedObjectInstanciation = 0;
my $nb_UselessOverridingMethod = 0;
my $nb_BadClassNames = 0;
my $nb_ClassNameIsNotFileName = 0;
my $nb_BadConstructorNames = 0;
my $nb_ConstructorWithReturn = 0;
my $nb_MissingSetter = 0;


sub countUselessOverridingMethod($) {
  my $class = shift ;
  my $nb_Violations = 0;

  my @Methods = GetNodesByKind( $class, FunctionKind);

  for my $method (@Methods) {
    # forget the bloc level that contains the children instruction of the
    # method :
    #   GetSubBloc($method)
    #       ==> the list of first-level node children of the method
    #   GetSubBloc($method)->[0])
    #       ==> the first element of this list, that is the bloc that contains the instructions children.
    #   GetSubBloc(GetSubBloc($method)->[0]) 
    #       ==> the list of node instructions of the function.
    my $children = GetSubBloc(GetSubBloc($method)->[0]);
    
    my $name = GetName($method);

    my ($params) = ${GetStatement($method)} =~ /\((.*)\)/s ;
    my @paramList = $params =~ /(\$\w+)/sg ;
    my $parametersPattern = join '\s*,\s*', @paramList;
    # protect all '$' presents in the param list
      $parametersPattern =~ s/([\$])/\\$1/sg;
     
    if (scalar @{$children} == 1 ) {
      if (${GetStatement($children->[0])} =~ /\A\s*(?:return\s+)?parent\s*::\s*${name}\s*\(\s*${parametersPattern}\s*\)\s*\Z/si) {
      #if (${GetStatement($children->[0])} =~ /\A\s*(?:return\s+)?parent::${name}\s*\(\s*\$a,\s*\$b\s*\)\s*\Z/si) {
        $nb_Violations++;
#print "USELESS OVERRIDDING METHOD : $name !!!\n";
      }
    }
  }
  return $nb_Violations;
}

#sub countBadConstructorName($) {
#  my $class = shift;

#  my $name = GetName($class);

#  my @Meths = GetNodesByKind($class, FunctionKind);

#  for my $meth (@Meths) {
#    if ( $name eq GetName($meth)) {
#      return 1;
#    }
#  }
#  return 0;
#}

sub CountClass($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_UnnecessaryFinalModifier = 0;
  $nb_UselessOverridingMethod = 0;
  $nb_BadClassNames = 0;
  $nb_ClassNameIsNotFileName = 0;
  $nb_BadConstructorNames = 0;
  $nb_ConstructorWithReturn = 0;
  $nb_MissingSetter = 0;
  my $nb_MethodImplementations = 0;


  my $root =  $vue->{'structured_code'} ;

  if ( ! defined $root )
  {
    $ret |= Couples::counter_add($compteurs, $UnnecessaryFinalModifier__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $UselessOverridingMethod__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $BadClassNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ClassNameIsNotFileName__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $BadConstructorNames__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $ConstructorWithReturn__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    $ret |= Couples::counter_add($compteurs, $MissingSetter__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }

  my $ClassHavingFileName = 0;

  my @Classes = GetNodesByKind( $root, ClassKind);

  my $nb_ClassImplementations = scalar @Classes;

  for my $class (@Classes) {
    my $stmt = GetStatement($class);
    if ( $$stmt =~ /(?:\A|\b)final\b/si ) {
      my $children = GetSubBloc(GetSubBloc($class)->[0]);

      for my $child ( @{$children}) {
        if ( ${GetStatement($child)} =~ /(?:\A|\b)final\b/is ) {
          $nb_UnnecessaryFinalModifier++;
#print "UNNECESSARY FINAL MODIFIER : ".${GetStatement($child)}."\n";
	}
      }
    }

    # Check for useless methods
    $nb_UselessOverridingMethod += countUselessOverridingMethod($class);

    my $ClassName = GetName($class);
    if ( $ClassName !~ /^[A-Z]/) {
      $nb_BadClassNames++;
    }

    # Get the basename of the file.
    $file =~ s/.*[\\\/]// ;
    # Remove extension
    $file =~ s/\.[^\.]*$//sm ;

    if ( $file eq $ClassName) {
      $ClassHavingFileName++;
    }

    # CHECKS applying to methods ...
    my @Meths = GetNodesByKind($class, FunctionKind);
    $nb_MethodImplementations = scalar @Meths;

    my $get_defined = 0;
    my $set_defined = 0;
    my $Constructor = undef;
    for my $meth (@Meths) {

      my $MethName = GetName($meth);

      if ( $MethName eq $ClassName ) {
	# if a method has the same name than the class, 
	#   then it is a constructor naming convention violation.
        $nb_BadConstructorNames++;

	if (! defined $Constructor) {
          $Constructor = $meth;
	}
      }
      elsif ( $MethName eq "__construct" ) {
        $Constructor = $meth;
      }
      elsif ( $MethName eq "__get" ) {
        $get_defined = 1;
      }
      elsif ( $MethName eq "__set" ) {
        $set_defined = 1;
      }
    }

    # Check if the constructor has a "return" statement.
    my @BadReturn = GetNodesByKind($Constructor, ReturnKind);
    if ( scalar @BadReturn > 0 ) {
      $nb_ConstructorWithReturn ++;
#print "RETURN IN CONSTRUCTOR ".GetName($Constructor)."\n";
    }

    # Check if __set is defined in cas where __get is defined.
    if (($get_defined) && (!$set_defined)) {
      $nb_MissingSetter++;
#print "MISSING SETTER !!!\n";
    }
  }

  if ( (scalar @Classes > 0) && (! $ClassHavingFileName)) {
    $nb_ClassNameIsNotFileName++;
  }

  $ret |= Couples::counter_add($compteurs, $UnnecessaryFinalModifier__mnemo, $nb_UnnecessaryFinalModifier );
  $ret |= Couples::counter_add($compteurs, $UselessOverridingMethod__mnemo, $nb_UselessOverridingMethod );
  $ret |= Couples::counter_add($compteurs, $BadClassNames__mnemo, $nb_BadClassNames );
  $ret |= Couples::counter_add($compteurs, $ClassNameIsNotFileName__mnemo, $nb_ClassNameIsNotFileName );
  $ret |= Couples::counter_add($compteurs, $BadConstructorNames__mnemo, $nb_BadConstructorNames );
  $ret |= Couples::counter_add($compteurs, $ConstructorWithReturn__mnemo, $nb_ConstructorWithReturn );
  $ret |= Couples::counter_add($compteurs, $MissingSetter__mnemo, $nb_MissingSetter );
  $ret |= Couples::counter_add($compteurs, Ident::Alias_MethodImplementations(), $nb_MethodImplementations );
  $ret |= Couples::counter_add($compteurs, Ident::Alias_ClassImplementations(), $nb_ClassImplementations );

  return $ret;
}

sub CountUnassignedObjectInstanciation($$$) 
{
  my ($file, $vue, $compteurs) = @_ ;

  my $ret = 0;
  $nb_UnassignedObjectInstanciation = 0;

  if ( ! defined $vue->{'code'} )
  {
    $ret |= Couples::counter_add($compteurs, $UnassignedObjectInstanciation__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
    return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
  }
  while ($vue->{'code'} =~ /(=|=>|throw\s|return\s|\?|:)?\s*(?:&\s*)?(\$)?\bnew\b/isg) {

    if (( (! defined $1) || ($1 eq '')) &&   # IF 'new' is not behind =|=>|throw\s|return\s|\?|:
        (! defined $2) ) {                   # AND is not a variable ($new)
       $nb_UnassignedObjectInstanciation++;  # THEN it is a non assigned instanciation !!!
#print "UNASSIGNED OBJECT FOUND !! \n";
    } 
  }

  $ret |= Couples::counter_add($compteurs, $UnassignedObjectInstanciation__mnemo, $nb_UnassignedObjectInstanciation );

  return $ret;
}


1;
