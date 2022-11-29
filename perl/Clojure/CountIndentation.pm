package Clojure::CountIndentation;

use strict;
use warnings;

use Erreurs;

use Clojure::ClojureNode;
use Lib::NodeUtil;

my $TabInsideIndentation__mnemo = Ident::Alias_TabInsideIndentation();
my $FormBodyIndentation__mnemo = Ident::Alias_FormBodyIndentation();
my $ParameterIndentation__mnemo = Ident::Alias_ParameterIndentation();

my $nb_TabInsideIndentation = 0;
my $nb_FormBodyIndentation = 0;
my $nb_ParameterIndentation = 0;

sub CountTabInsideIndentation($$$) {
 my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_TabInsideIndentation = 0;
    
    my $code =  \$vue->{'code'} ;

    if ( ! defined $code )
    {
        $ret |= Couples::counter_add($compteurs, $TabInsideIndentation__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }
	my $line = 0;
	while ($$code =~ /^([ \t]*\t[ \t]*)?.*$/mg) {
		$line++;
		if (defined $1) {
#print STDERR "<$1> ($line)\n";
			$nb_TabInsideIndentation++;
			Erreurs::VIOLATION($TabInsideIndentation__mnemo, "Avoid tab inside indentation at line $line");
		}
	}

	$ret |= Couples::counter_add($compteurs, $TabInsideIndentation__mnemo, $nb_TabInsideIndentation );
  
	return $ret;
}

my %WITH_BODY_FORM = ( 	"loop"=>1, "let"=>1, "defmacro"=>1, "try"=>1, "binding"=>1);
my %WITH_BODY_KIND = ( 	&SwitchCaseKind() => 1,
						&SwitchKind() => 1,
						&SwitchpKind() => 1,
						&SwitchArrowKind() => 1,
						&WhenKind() => 1,
						&WhileKind() => 1,
						&IfKind() => 1);


sub checkBodyInstructionIndentation($$) {
	my $instr = shift;
	my $formIndent = shift;
	
	my $childIndent = Clojure::ClojureNode::getClojureKindData($instr, 'indentation');
	if (defined $childIndent) {
#print STDERR "  --> INDENTATION CHILD  = <$childIndent> at line ".(GetLine($child)||"??")."\n";
		if ($childIndent =~ /^$formIndent(.*)/m) {
			# indentation of child should be 2 spaces after indentation of perent.
			if ($1 ne "  ") {
				$nb_FormBodyIndentation++;
				Erreurs::VIOLATION($FormBodyIndentation__mnemo, "Indentation of body parameter at line ".(GetLine($instr)||"??")." is not 2 space more than instruction indentation");
			}
		}
		else {
			$nb_FormBodyIndentation++;
			Erreurs::VIOLATION($FormBodyIndentation__mnemo, "Indentation of body parameter at line ".(GetLine($instr)||"??")." is not compliant with instruction indentation");
		}
	}
	else {
		# indentation is unknown
		print STDERR "Missing indentation for node ".GetKind($instr)." at line ".(GetLine($instr)||"??")."\n";
	}
}

sub checkBodyIndentation($) {
	my $node = shift;
	
	my $formLine = GetLine($node);
	my $formIndent = Clojure::ClojureNode::getClojureKindData($node, 'indentation');
#print STDERR "INDENTATION FORM = <$formIndent>\n" ;

	# check children indentation
	for my $child (@{Lib::NodeUtil::GetChildren($node)}) {
		
		# do not consider children on the same line.
		next if ($formLine == GetLine($child));
		# do not consider conditions nodes
		next if (IsKind($child, ConditionKind));
		
		if ((IsKind($child, ThenKind)) || (IsKind($child, ElseKind))) {
			for my $instr (@{Lib::NodeUtil::GetChildren($child)}) {
				checkBodyInstructionIndentation($instr, $formIndent);
			}
		}
		else {
			checkBodyInstructionIndentation($child, $formIndent);
		}
	}
}

sub checkParametersIndentation($) {
	my $node = shift;

	my $kind = $node->[0];
	return if (($kind eq ThenKind) || ($kind eq ElseKind) || ($kind eq VectorKind) || ($kind eq MapKind) || ($kind eq CaseKind));

	my $formLine = GetLine($node);
#print STDERR "FORM ".GetKind($node)." (".(GetName($node)||"??").") at line ".($formLine||"??")."\n";	
	if (! defined $formLine) {
		print STDERR "MISSING LINE for ".GetKind($node)."\n";
		return;
	}

	my $children = Lib::NodeUtil::GetChildren($node);
	
#print STDERR "  first child on line ".(GetLine($children->[0])||"??")."\n" if (scalar @$children > 1);

	my $expectedIndent;
	my $textViolation;
	my $previousChildLine;
	my $idx = 0;
	
	# first child is on the same line ...
	if ((scalar @$children > 1) && (GetLine($children->[0]) == $formLine)) {
		$expectedIndent = Clojure::ClojureNode::getClojureKindData($children->[0], 'indentation');
		$textViolation = "is not the same than first parameter";
		$idx = 0;
		$previousChildLine = GetLine($children->[0]);
		
		if (! defined $expectedIndent) {
			Erreurs::VIOLATION($ParameterIndentation__mnemo, "Missing indentation for first parameter (kind=".GetKind($children->[0]).") at line ".(GetLine($children->[0])||"??"));
		}
	}
	# first child is on another line
	elsif ((@$children > 0) && (GetLine($children->[0]) > $formLine)) {
		$expectedIndent = Clojure::ClojureNode::getClojureKindData($node, 'indentation');
		$expectedIndent .= " " if defined $expectedIndent;
		$textViolation = "is not a single space more than the function";
		$idx = 1;  # do not skip treatment for first child.
		$previousChildLine = GetLine($node);
		
		if (! defined $expectedIndent) {
			Erreurs::VIOLATION($ParameterIndentation__mnemo, "Missing indentation for form ".GetKind($node)." at line ".(GetLine($node)||"??"));
		}
	}
		
		if (defined $expectedIndent) {

			my $previousIllegalIndentation = undef;
			
			# CHECK EACH children indentation
			for my $child (@{$children}) {
		
				# skip first child
				next if (! $idx++);
				
				# skip parameters that are on the same line than previous one.
				next if (GetLine($child) == $previousChildLine);
				
				# update $previousChildLine
				$previousChildLine = GetLine($child);
				
				my $childIndent = Clojure::ClojureNode::getClojureKindData($child, 'indentation');
				if (defined $childIndent) {
#print STDERR "  --> PARAMETER INDENTATION  = <$childIndent> at line ".(GetLine($child)||"??")."\n";
#print STDERR "      FIRST INDENT           = <$expectedIndent>\n";
					if ($childIndent ne $expectedIndent) {
						# indentation of child should be the same then first parameter
						
						if ((! defined $previousIllegalIndentation) || ($childIndent ne $previousIllegalIndentation)){
							# indentation is illegal and has not been previously sanctioned
							$nb_ParameterIndentation++;
							$previousIllegalIndentation = $childIndent;
							Erreurs::VIOLATION($ParameterIndentation__mnemo, "Indentation of parameter at line ".(GetLine($child)||"??")." $textViolation");
						}
					}
					else {
						# indentation OK, 
						$previousIllegalIndentation = undef;
					}
				}
				else {
					# indentation is unknown
					Erreurs::VIOLATION($ParameterIndentation__mnemo, "Missing indentation parameter ".GetKind($child)." at line ".(GetLine($child)||"??"));
				}
			}
		}
}

sub _cbFormIndentation() {
	my ($node, $context) = @_;
	  
	my $name = GetName($node);
		
	# CHECK with KIND
	if ((defined $WITH_BODY_KIND{GetKind($node)})) {
#print STDERR "CHECK INDENTATION of KIND ".GetKind($node)."\n";
		checkBodyIndentation($node);
	}
	# CHECK with NAME
	elsif ((defined $name) && (defined $WITH_BODY_FORM{$name})) {
		checkBodyIndentation($node);
	}
	else {
		checkParametersIndentation($node);
	}
	return undef;
}

sub CountFormIndentation($$$) {
 my ($file, $vue, $compteurs) = @_ ;

    my $ret = 0;
    $nb_FormBodyIndentation = 0;
    $nb_ParameterIndentation = 0;
    
    my $root =  \$vue->{'structured_code'} ;

    if ( ! defined $root )
    {
        $ret |= Couples::counter_add($compteurs, $FormBodyIndentation__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        $ret |= Couples::counter_add($compteurs, $ParameterIndentation__mnemo, Erreurs::COMPTEUR_ERREUR_VALUE );
        
        return $ret |= Erreurs::COMPTEUR_STATUS_VUE_ABSENTE;
    }

	my @context = ();
	Lib::Node::Iterate ($$root, 0, \&_cbFormIndentation, \@context);

	$ret |= Couples::counter_add($compteurs, $FormBodyIndentation__mnemo, $nb_FormBodyIndentation );
	$ret |= Couples::counter_add($compteurs, $ParameterIndentation__mnemo, $nb_ParameterIndentation );
  
	return $ret;
}
1;
