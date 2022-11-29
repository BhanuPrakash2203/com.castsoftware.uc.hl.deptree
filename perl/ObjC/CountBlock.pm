
package ObjC::CountBlock ;

use strict;
use warnings;

use Erreurs;
use ObjC::ObjCNode;
use Lib::Node;

my $mnemo_UnnecessaryBlockParameter = Ident::Alias_UnnecessaryBlockParameter();
my $mnemo_UnnecessaryBlockreturnType = Ident::Alias_UnnecessaryBlockreturnType();
my $mnemo_WithMissingParameterNameBlock = Ident::Alias_WithMissingParameterNameBlock();
my $mnemo_BadBlockNames = Ident::Alias_BadBlockNames();

my $nb_UnnecessaryBlockParameter = 0;
my $nb_UnnecessaryBlockreturnType = 0;
my $nb_WithMissingParameterNameBlock = 0;
my $nb_BadBlockNames = 0;

sub CountBlock($$$) {
  my ($fichier, $vue, $compteurs, $options) = @_ ;

  my $status = 0;
  $nb_UnnecessaryBlockParameter = 0;
  $nb_UnnecessaryBlockreturnType = 0;
  $nb_WithMissingParameterNameBlock = 0;
  $nb_BadBlockNames = 0;

  if (not defined $vue->{'structured_code'})
  {
      $status |= Couples::counter_add ($compteurs, $mnemo_UnnecessaryBlockParameter , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_UnnecessaryBlockreturnType , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_WithMissingParameterNameBlock , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Couples::counter_add ($compteurs, $mnemo_BadBlockNames , Erreurs::COMPTEUR_ERREUR_VALUE);
      $status |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
      return $status;
  }

  my $root = $vue->{'structured_code'};


  my @unks = GetNodesByKind($root, BlockDeclKind);

  for my $unk (@unks) {
    my $stmt = GetStatement($unk);

    # Check if it is a block variable definition, then parse it
    if ($$stmt =~ /(\w+)?\s*\(\^\s*(\w+)\)\s*\(([^\(\)]+)?\)\s*(=)?\s*(__BLOCK__)?/sm ) {
      my $type = $1;
      my $name = $2;
      my $parameter = $3;
      my $init = $4;
      my $block = $5;
#print "FOUND BLOCK VARIABLE : $name\n";

      # If the block variable is not initialized, or initialized with everythink
      # else than a directly defined block, then check presence of paramters names.
      if ((! defined $init) || (!defined $block)) {
        # Analyze parameters ...
        if (defined $parameter) {
          my @params = split ',', $parameter ;
	  for my $param (@params) {
	    if ($param =~ /^\s*\w+\s*$/sm) {
	      $nb_WithMissingParameterNameBlock++;
#print "==> Missing parameter name !!\n";
	    }
  	  }
        }
      }
      # if an initialisation with a defined block is given ...
#      else {
#	 # get the node of the block :
#         my $children = ObjC::ObjCNode::GetChildren($unk);
#	 my $blockDef;
#	 for my $child (@$children) {
#	   if (IsKind($child, BlockKind)) {
#	     $blockDef = $child;
#	     last;
#	   }
#	 }
#print "BLOCK DEF STATEMENT = ".${GetStatement($blockDef)}."\n";
#         if (${GetStatement($blockDef)} =~ /(\^\s*(\w+)?\s*(\([^()]*\))?\s*)$/sm) {
#           my $type1 = $1;
#	   my $parameter1 = $2;
#
#	   if ((defined $type1) && ($type eq "void")) {
#	     $nb_UnnecessaryBlockType++;
#	   }
#	 }
#      }

    }
  }

  my @blocks = GetNodesByKind($root, BlockKind);

  for my $block (@blocks) {
    my $stmt = GetStatement($block);
#print "BLOCK STATEMENT = $$stmt\n";
    if ($$stmt =~ /\^\s*(\w+)?\s*(\([^()]*\))?\s*$/sm) {
      my $type1 = $1;
      my $parameter1 = $2;

      if ((defined $type1) && ( $type1 eq 'void')) {
        $nb_UnnecessaryBlockreturnType++;
#print "---> Unnecessary block return type\n";
      }
      if ((defined $parameter1) && ( $parameter1 =~ /\bvoid\b/sm)) {
        $nb_UnnecessaryBlockParameter++;
#print "---> Unnecessary block parameter\n";
      }
    }
  }

  my @blockDecls = GetNodesByKind($root, BlockDeclKind);

  for my $block (@blockDecls) {
     my $name = GetName($block);
     if (! ObjC::CountNaming::checkMethodName(\$name)) {
        $nb_BadBlockNames++;
#print "Bad block name : $name !!!\n";
     } 
  }

  $status |= Couples::counter_add ($compteurs, $mnemo_UnnecessaryBlockParameter, $nb_UnnecessaryBlockParameter);
  $status |= Couples::counter_add ($compteurs, $mnemo_UnnecessaryBlockreturnType, $nb_UnnecessaryBlockreturnType);
  $status |= Couples::counter_add ($compteurs, $mnemo_WithMissingParameterNameBlock, $nb_WithMissingParameterNameBlock);
  $status |= Couples::counter_add ($compteurs, $mnemo_BadBlockNames, $nb_BadBlockNames);
  return $status;
}

1;
