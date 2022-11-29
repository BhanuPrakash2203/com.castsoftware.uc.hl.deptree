package Java::ParseCommon;
# les modules importes
use strict;
use warnings;

use Lib::ParseUtil;
use Java::JavaNode;
use Lib::Node;
use Lib::NodeUtil;
use Lib::NodeUtil qw( SetName SetStatement SetLine GetLine SetEndline GetEndline);

our $MULTIVAR_SEPARATORS = { "=" => 1, "," => 1, ")" => 1};

# FIXE : rename into "Parse_SimpleDeclaration"
sub parse_SimpleVariable($$;$) {
	my $stmt = shift;
	my $data = shift;
	my $kind = shift || VariableKind;
	
	if (!defined Lib::ParseArguments::parseName($stmt, $data)) {
		return undef;
	}
	
	my $EmptyStr = "";
	my $varNode = Node($kind, \$EmptyStr);
	SetLine($varNode, $data->{'line'});
	SetName($varNode, $data->{'name'});
	setJavaKindData($varNode, 'type', $data->{'type'});
#print "VAR type = $data->{'type'}\n";
#print "    name = $data->{'name'}\n";
	if (defined $data->{'tab'}) {
		setJavaKindData($varNode, 'tab', $data->{'tab'});
#print "    tab = $data->{'tab'}\n";
	}
	my $next;
	if (defined ($next = nextStatement()) && ($$next eq "=") ) {
		# trashes the "="
		getNextStatement();
		
		my $initStmt = "";
		my $initNode = Node(InitKind, \$initStmt);
		SetLine($initNode, getNextStatementLine());
		
		my @expUpdateInfos = Lib::ParseUtil::parse_Expression($MULTIVAR_SEPARATORS);
		
		Lib::ParseUtil::updateGenericParse(\$initStmt, $initNode, \@expUpdateInfos);

		Append($varNode, $initNode);
	}
	
	return $varNode;
}

sub parse_VariablesList($$;$) {
	my $stmt = shift;
	my $data = shift;
	my $kind = shift;
	
	# Copy data in case there were several variables. Indeed,
	# the function &parseName() can modify the type if a tab operator
	# is detected behind the name.
	my %commonData = %$data;

	# PARSE THE FIRST VARIABLE
	my $varNode = parse_SimpleVariable($stmt, $data, $kind);
	
	if (! defined $varNode) {
		return undef;
	}
	else {
		SetStatement($varNode, $stmt);
	}

	# PARSE ADDITIONAL VARIABLES
	my @add_vars = ();
	my $next;
	while ( (defined ($next = nextStatement())) && ($$next eq ",") ) {
		
		# trashes the ","
		getNextStatement();
		
		my %data_ = %commonData;
		my $data = \%data_;

		$data->{'line'} = getNextStatementLine();
		
		my ($stmt, $subNodes) = Lib::ParseUtil::parse_Expression($MULTIVAR_SEPARATORS);
		
		my $addVarNode = parse_SimpleVariable($stmt, $data, $kind);
		if (defined $addVarNode) {
			SetStatement($varNode, $stmt);
			push @add_vars, $addVarNode;
		}
	}
	
	setJavaKindData($varNode, 'addnode', \@add_vars);

	return $varNode;
}

# Check if a given statement is a variable declaration.
# If yes, return a "var" node.
# FIXE : rename into "Parse_TypedDeclaration"
sub parse_VariablesDeclaration($$;$$$) {
	my $stmt = shift;
	my $line = shift;
	my $kind = shift;
	
	# 0 mean the parser assume that each declaration statement is introduced by a type !!!
	my $OPTIONAL_TYPE = shift || 0;
	my $NO_MULTIVAR = shift;
	
	my $data = Lib::ParseArguments::initVarData($line);
	
	# PARSE THE TYPE OF THE VARIABLE DECLARATION
	if (!defined Lib::ParseArguments::parseType($stmt, $data)) {
		if (! $OPTIONAL_TYPE) {
			# no type detected whereas mandatory
			return undef;
		}
	}
	else {
		# something like a type detected, but ...
		if ($OPTIONAL_TYPE) {
			# type optional, so is it really a type ?
			# check if it is followed by name
			my $currentpos = pos($$stmt);
			if ($$stmt !~ /\G\s*\w+/g) {
				# not followed by a name => declaration without type, so reset statement
				pos($$stmt) = 0;
				$data->{'type'} = undef;
			}
			else {
				pos($$stmt) = $currentpos;
			}
		}
	}
	
	# Copy data in case there were several variables. Indeed,
	# the function &parseName() can modify the type if a tab operator
	# is detected behind the name.
	my %commonData = %$data;

	# PARSE THE FIRST VARIABLE
	my $varNode = parse_SimpleVariable($stmt, $data, $kind);
	
	if (! defined $varNode) {
		return undef;
	}
	else {
		SetStatement($varNode, $stmt);
	}

	if (! $NO_MULTIVAR) {
		# PARSE ADDITIONAL VARIABLES
		my @add_vars = ();
		my $next;
		while ( (defined ($next = nextStatement())) && ($$next eq ",") ) {
		
			# trashes the ","
			getNextStatement();
		
			my %data_ = %commonData;
			my $data = \%data_;

			$data->{'line'} = getNextStatementLine();

			my ($stmt, $subNodes) = Lib::ParseUtil::parse_Expression($MULTIVAR_SEPARATORS);

			my $addVarNode = parse_SimpleVariable($stmt, $data, $kind);
			if (defined $addVarNode) {
				SetStatement($addVarNode, $stmt);
				push @add_vars, $addVarNode;
			}
		}
	
		setJavaKindData($varNode, 'addnode', \@add_vars);
	}

	return $varNode;
}

#
# 1 - build the statement representing the beginning of the declaration
#
# 2 - call  parse_VariableDeclaration() with the statement
#
# return :
# - statement : the beginning of the statement. 
#               the statement is ended on ; or } in case of a full instruction, 
#               Or the statement is ended on = , < in case of a variable declaration, respectively with initialisation, multiple decl, or template.
#
# - the node corresponding to the variable if the statement has been recognized as a variable declaration.


# FIXE : rename into "Parse_TypedDeclarationList"
sub Parse_Variable(;$$$$$) {
	my $statement = shift || createEmptyStringRef();
	my $line = shift || getNextStatementLine();
	my $kind = shift;
	my $OPTIONAL_TYPE = shift || 0; # type mandatory by default
	my $NO_MULTIVAR = shift || 0;   # multiple vars by default
	
	if (! defined nextStatement()) {
		return ($statement, undef, 1);
	}
	
	# we want the expression to stop if a "=" or "," is encountered.
    
    # we need to split on :
    #      "=" and "," because it is stop item for parse_Expression()
    #      "<" because there is a "trigger expression" for this item
    Lib::ParseUtil::register_SplitPattern(qr/[=,<]/);
		my ($stmt, $subNodes, $endInstruction) = Lib::ParseUtil::parse_Expression($MULTIVAR_SEPARATORS);
		
		$$statement .= $$stmt;
		
		# check variable declaration.
		my $node = parse_VariablesDeclaration($statement, $line, $kind, $OPTIONAL_TYPE, $NO_MULTIVAR);
		
	Lib::ParseUtil::release_SplitPattern();
	
	return ($statement, $node, $endInstruction, $subNodes);
}

sub Parse_VariableOrUnknow(;$$$) {
	my $stmt = shift;
	my $line = shift;
	my $kind = shift;
	
	my ($statement, $node, $endInstruction, $subNodes) = Parse_Variable($stmt, $line, $kind);
	
	if (! defined $node) {
		$node = Node(UnknowKind, $statement);
		
		# add subnodes.
		Lib::ParseUtil::updateGenericParse($statement, $node, [createEmptyStringRef(), $subNodes] );
		
		SetLine($node, getStatementLine());
		if (! $endInstruction) {
			# Finishes to parse the instruction ...
			my @UpdateInfos = Lib::ParseUtil::parse_Instruction();
			Lib::ParseUtil::updateGenericParse($statement, $node, \@UpdateInfos );
		}
	}
	else {
		# The instructions is assumed to be parsed ...
		Lib::ParseUtil::purgeSemicolon();
	}
	return $node;
}

# Anonymous block have a structural existance, but no logical incidence in terms of control flow.
# So, considering the following code :
#
# a=1;
# {
#   b=0;
# }
# return
#
# We have a STRUCTURAL representation :
#
# root 
# |_unk
# |_block
# | |_unk
# |_ret
#
# and a LOGICAL representation
#
# root 
# |_unk
# |_unk
# |_ret
#
# The parser build the STRUCTURAL representation, so we should build the LOGICAL.
# The LOGICAL we then be the default representation.

sub	flattenBlocks($);
sub	flattenBlocks($) {
	my $parent = shift;

	my $idx = 0;
	my @blockIdx = ();
	my $STRUCTURAL_children = GetChildren($parent);
	
	# Search blocks in structural representation.
	# + apply recursivity to all childs ...
	for my $child (@{$STRUCTURAL_children}) {

		# recursive treatment ..
		flattenBlocks($child);	
		if ( IsKind ( $child,  BlockKind)) {
			# save the index of the anonymous block
			push @blockIdx, $idx;
		}
		$idx++;
	}
	
	# If the "parent" node contains block in its direct child,
	# then create logical representation of the children (remove bloc level from the tree)
	my $parentKind = GetKind($parent);
	if ((scalar @blockIdx) && ( ($parentKind ne ClassKind) and ($parentKind ne InterfaceKind) and ($parentKind ne InterfaceKind)) ) {
		
		my @LOGICAL_children = @$STRUCTURAL_children;
		my $offset = 0;
		
		for my $id_block (@blockIdx) {
			my $block = $STRUCTURAL_children->[$id_block];

			# Get children of the block ...
			my $childrenOfBlock = GetChildren($block);

			# In the logical representation (of the parent's children !), replace the block node with its children (i.e. remove block level)...
			splice @LOGICAL_children, $id_block+$offset, 1, @$childrenOfBlock;

			# the logical has some nodes in addition and one node (the block) in less,
			# so we should create an offset to take into account.
			$offset += scalar @$childrenOfBlock-1;
		}

		if (scalar @blockIdx) {
			# Blocks have been found so we have a LOGICAL and a STRUCTURAL representation.
			
			# make the LOGICAL the default:
			SetChildren($parent, \@LOGICAL_children);	
		
			# record the STRUCTURAL in additional data of the node 
			setJavaKindData($parent, 'structural_children', \@LOGICAL_children);
		}
	}
}

1;
