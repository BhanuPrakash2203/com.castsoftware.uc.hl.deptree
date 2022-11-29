package CS::ParseVariables;

use strict;
use warnings;

use Lib::Node; # qw( Leaf Node Append );
use Lib::NodeUtil ;
use Lib::NodeUtil qw( SetName SetStatement SetLine GetLine SetEndline GetEndline);
use Lib::Log;
use CS::CSNode;

my %peer = ('(' => ')', '{' => '}', '[' => '\]');
my %peerReg = (	'(' => qr/\G([^()]*)([()])/, 
				'{' => qr/\G([^{}]*)([{}])/, 
				'[' => qr/\G([^\[\]]*)([\[\]])/);

sub getUntilPeer($$) {
	my $stmt = shift;
	my $open = shift;
	my $close = $peer{$open};
	my $reg = $peerReg{$open};
	if (!defined $close) {
		Lib::Log::ERROR("no closing peer for $open !!!");
		return "";
	}
	
	my $openned = 1;
	my $expr = "";
	
	while ($$stmt =~ /$reg/sgc) {

		$expr .= $1.$2;
		if ($2 eq $open) {
			$openned++;
		}
		else {
			$openned--;
			if (! $openned) {
				last;
			}
		}
	}
	return $expr;
}

sub parseDefaultValue($$) {
	my $stmt = shift;
	my $data = shift;
	
	my $default = "";
	if ($$stmt =~ /\G\s*=\s*/sgc) {

		while ($$stmt =~ /\G([^,()\[\{]*)(.|\z)/sgc) {
			$default .= $1;
			# $2 is , ) ( [ { or ""
			if (($2 eq '(') || ($2 eq '{') || ($2 eq '[')) {
				$default .= $2;
				$default .= getUntilPeer($stmt, $2);
				if (! defined pos($$stmt)) {
					# end of function proto has been encountered before the end of the default value expression.
					last;
				}
			}
			elsif ($2 ne "") {
				# $2 is , or )
				# a character ',' or ')' has been encountered, this is the end of the default value expression.
				pos($$stmt)--;
				last;
			}	
		}
	}
	else {
		return undef;
	}
	$data->{'default'} = $default;

	return 1;
}

sub parseName($$) {
	my $stmt = shift;
	my $data = shift;
	
	if ($$stmt =~ /\G\s*(\@?\w+)/sgc) {
		$data->{'name'} = $1;
	}
	else {
		return undef;
	}
	
	# GENERIC SYNTAX ...
	if ($$stmt =~ /\G\s*<=/gc) {
		# comparision operator just after name => not a variable declaration !!!
		# ex : protected int Left(int node) => prime * prime <= target1;
		return undef;
	}
	if ($$stmt =~ /\G\s*</gc) {
		$data->{'name'} .= '<' . parseTypeGeneric($stmt);
	}
	
	# in java, tab bracket are most often after the type, but can be after the name too.
	parseTab($stmt, $data);
	
	return 1;
}

sub parseTypeGeneric($) {
	my $stmt = shift;
	
	my $level =1;
	my $item = "";
	
	while ($$stmt =~ /\G(?:(>)|(<)|([^<>]+))/gc) {
		if (defined $1) {
			$level--;
			$item .= $1;
		}
		elsif (defined $2) {
			$level++;
			$item .= $2;
		}
		else {
			$item .= $3;
		}
		if (!$level) {
			last;
		}
	}
	
	return $item;
}

sub parseEllipsis($$) {
	my $stmt = shift;
	my $data = shift;
	
	if ($$stmt =~ /\G\s*\.\.\./sgc) {
		$data->{'ellipsis'} = 1;
		return 1;
	}
	else {
		$data->{'ellipsis'} = 0;
		return 0;
	}
}

sub parseTab($$) {
	my $stmt = shift;
	my $data = shift;
	
	my $tab = "";
	
	#while ($$stmt =~ /\G(\s*\[\s*[\w,]*\s*\])/sgc) {
	while ($$stmt =~ /\G(\s*\[[^\[\]]*])/sgc) {
		$data->{'type'} .= $1;
		$tab .= $1;
	}
	
	if ($tab ne "") {
		$data->{'tab'} = $tab;
	}
}

sub parseCompoundType($$$;$);

sub parseType($$) {
	my $stmt = shift;
	my $data = shift;
	
	# a type name cannot begin with a number
	return undef if ($$stmt =~ /\G\s*\d/);
	
	my $typeName = "";
#print STDERR "STMT = $$stmt\n";
	my $initial_pos = pos($$stmt);
	
	# Specific type with modifiers for C++
	#     Modifiers can be followed with macro defining a type, for example :
	#           template<typename LINK> unsigned __int64 CHashTableOfGenericLinks<LINK>::GetKey(...)
	#           bool CHasherForTableOfEscalatedLinks::is_valid_key( const unsigned __int64 & key ) const
	#     So the regexp should take into account that the modifiers can be followed by an arbitrary word, itself followed by another word or a "&" or a "*"
#	if ($$stmt =~ /\G\s*((?:(?:signed|unsigned|long|short|int|char|double)\b\s*(?:\w+\s+(?:\b|[&*]))?)+)/gc) {
#		$typeName .= $1;
#		$typeName =~ s/\s+$//m;
#	}
	
	
	if ($$stmt =~ /\G\s*\(/gc) {
		$typeName .= '(';
		my @items = ();
		my $posBegin = pos($$stmt);
		my $error = parseCompoundType($stmt, \@items, $data->{'line'});
		if ($error) {
			Lib::Log::ERROR("Unable to parse destructuring variables at line $data->{'line'}");
		}
		else {
			my $posEnd = pos($$stmt);
			$typeName .= substr($$stmt, $posBegin, $posEnd-$posBegin);
		}
	}
	# generic case
	else {
		if ($$stmt =~ /\G\s*((:?struct|enum|class)\b\s*[*&]?)/gc) {
			$typeName .= $1;
		}
		
		# annotation !!! specific to Java, example : public boolean equals(@NullableDecl Object object)
		elsif ($$stmt =~ /\G(\@\w+\s*)/gc) {
			# do not integrate the annotation in the name.
			# $typeName .= $1;
		}
	
		# PARSE THE NAME
		#
		# - namespaces separators are :: (C++) or . (Java)
		# - can begin with :: (C++)
		# - spaces are only allowed between :: or . and words ..
		# - prevent from matching several consecutive . (it's a ellipsis) !
		my $type_name_parsing = 1;
		while ($type_name_parsing) {
			
			# parse WORD NAMESPACE part.
			#---------------------------
			if ($$stmt =~ /\G\s*((?:::)?\s*(?:\w+(?:\s*(?:\.(?=[^\.]|$)|::)\s*)?)+)/mgc) {
				$typeName .= $1;
				# the type name ends with : or . 
				if ($typeName =~ /[:\.]$/m) {
					# it is not a type name, it's a incomplete namespace ...
					pos($$stmt) = $initial_pos;
					return undef;
				}
			}
			else {
				# no type name 
				return undef;
			}
	
			# parse GENERIC part
			#--------------------
			if ($$stmt =~ /\G\s*</gc) {
				$typeName .= '<' . parseTypeGeneric($stmt);
			}
		
			# Check name termination ...
			if ($$stmt =~ /\G\s*(::|\.)(?!\.)/gc) {
				# a namespace separator is present => not the end !!
				$typeName .= $1;
			}
			else {
				$type_name_parsing = 0;
			}
		}
	}

	# C++ specific : far & near pointers
#	if ($$stmt =~ /\G(\s*(?:far|near))/gc) {
#		$typeName .= $1;
#	}

	# C++ specific : pointers or references
#	if ($$stmt =~ /\G(\s*[*&][*&\s]*)/gc) {
#		$typeName .= $1;
#	}

	# in C++, const can be placed after the type name
	# swallow "const" qualifier ...
#	if ($$stmt =~ /\G\s*const\b([*&\s]*)/gc) {
#		$typeName .= $1;
#	}
	
	# CLI (managed C++)
	# support hat operator (^)
#	if ($$stmt =~ /\G\s*(\^)/gc) {
#		$typeName .= $1;
#	}
    
    # pointer
	if ($$stmt =~ /\G(\s*\*+)/gc) {
		$typeName .= $1;
	}
    
	# $data->{'type'} = $typeName;
	
	# parseTab($stmt, $data);
	
	# return 1;
 
	$data->{'type'} = $typeName;

    # Question mark for nullable types
	if ($$stmt =~ /\G(\?)/gc) {
		$data->{'type'} .= $1;
	}

	parseTab($stmt, $data);
    
    # Question mark for nullable types
	if ($$stmt =~ /\G(\?)/gc) {
		$data->{'type'} .= $1;
	}
#print STDERR "TYPENAME = $typeName\n";
	return 1;
}

sub parseCompoundType($$$;$) {
	my $stmt = shift;
	my $varList = shift;
	my $line = shift;
	my $commonType = shift || "";;
	
	my $error = 0;
	my $commonData = initVarData($line);

	while ($$stmt !~ /\G\s*\)/gc) {
		
		my %newData = %$commonData;
		my $data = \%newData;
		
		if (!defined parseType($stmt, $data)) {
			$error = 1;
			last;
		}
		
		
		if ($$stmt =~ /\G\s*(?=[,\)])/gc) {
			# expecting name, but encountered coma or closing parenth.
			# coma or closing parenth mean end of the var declaration
			# so, no name means type was the name
			$data->{'name'} = $data->{'type'};
			$data->{'type'} = $commonType;
		}
		else {
			if (! defined parseName($stmt, $data)) {
				Lib::Log::ERROR("Unable to parse destructuring variables at line $line");
				$error = 1;
				last;
			}
			
			# check for end of variable with coma or closing parenth
			# if any, consume coma, but leave closing parenth. 
			if ($$stmt !~ /\G\s*(?=[,\)])/gc) {
				Lib::Log::ERROR("Unable to parse destructuring variables at line $line");
				$error = 1;
				last;
			}
		}
		
		# trash "," if any ...
		$$stmt =~ /\G\s*,/gc;
		
#print STDERR "--> VAR : type=$data->{'type'}, name=$data->{'name'}\n";
		push @$varList, $data;
	}
	
	# trash closing parenthese if any ...
	$$stmt =~ /\G\^s*\)/gc;
	
	return $error;
}


sub parseAttribute($$) {
	my $stmt = shift;
	my $data = shift;
	
	if ($$stmt =~ /\G\s*\[/gc) {
		$data->{'attribute'} = "";
		parseEnclosedStr($stmt, '[', \$data->{'attribute'});
		return 1;
	}
	return 0;
}

sub parseArg($$) {
	my $stmt = shift;
	my $r_line = shift;
	
	my $data = {};
	
	# default indentation
	$data->{'indent'} = "";
	$data->{'line'} = $$r_line;
	
	# capture indentaton
	while ($$stmt =~ /\G(?:([ \t]+)|(\))|(\n))/gc) {
		if (defined $1) {
			# indentation
			$data->{'indent'} = $1;
		}
		elsif (defined $2) {
			# closing parenthesis => end of arg list.
			return undef;
		}
		elsif (defined $3) {
			$$r_line++;
			$data->{'line'} = $$r_line;
			# end of line => parse next line
			next;
		}
	}
	
	# Attribute
	while (parseAttribute($stmt, $data)) {};
	
	# C# in/out/ref and this (extension methods)
	$data->{"mode"} = {};
	if ($$stmt =~ /\G((?:\s*(?:params|out|in|ref|this))+)\b/gc) {
		
		for my $mode (split /\s+/, $1) {
			$data->{"mode"}->{$mode} = 1;
		}
	}
	
	# swallow "final" or "const" qualifier ...
	#$$stmt =~ /\G\s*(?:final|const)\b/gc;
	
	my $typePos = pos($$stmt);
	if (!defined parseType($stmt, $data)) {
		Lib::Log::ERROR(	"unknow type syntax for argument in $$stmt\n".
					"at position (".(pos($$stmt)||0).") -> ".substr($$stmt, (pos($$stmt)||0), 50)." !!");
		$data->{'type'} = "";
		getUntilPeer($stmt, '('); # What's the aim ? stop the argument parsing ? pos($$stmt)=undef would be better, isn't it ?
		return undef;
	}
	
	# swallow "final" or "const" qualifier ...
	#$$stmt =~ /\G\s*(?:final|const)\b\s*\**/gc;
	
	#parseEllipsis($stmt, $data);

	if (! defined parseName($stmt, $data)) {
		# do not warn : no name is compliant with C++ syntax in prototype 
		# print STDERR "[ParseVariables] warning : ($$stmt) no name for arg at line ".($data->{'line'}||"?")."\n"; 
	}
	
	parseDefaultValue($stmt, $data);

	# consume the arg separator if any ...
	if ($$stmt !~ /\G\s*(?:,|(?=\)))/gc) {
		Lib::Log::ERROR(	"unknow type syntax for argument : ".substr($$stmt, $typePos||0, 50)." ... could be due to macro usage. please check !\n");
		$data->{'type'} = "";
		pos($$stmt) = length($$stmt)-1;
		return undef;
	}

	return $data;
}

sub parseArguments($;$) {
	my $artifactNode = shift;
	my $allowNoType = shift || 0;
	my @argList = ();
	
	my $stmt = GetStatement($artifactNode);
	my $line = GetLine($artifactNode);
	# stop after the first "(" or the last "\n" before the first non blank!
	$$stmt =~ /\A[^\(]*/sg;
	
	if ($$stmt =~ /\G\(/sg) {
	
	my $arg;
	while ($arg = parseArg($stmt, \$line)) {
		#$argList{$arg->{'name'}} = $arg;
		
		if (! defined $arg->{'name'}) {
			if ($allowNoType) {
				$arg->{'name'} = $arg->{'type'};
				$arg->{'type'} = undef;
#print STDERR "MISSING NAME : type $arg->{'name'} become name !!!\n";
			}
		}
		
		push @argList, $arg;
		
		#print "ARG : \n";
		#print "\ttype = $arg->{'type'}\n";
		#print "\tname = ".($arg->{'name'}||"undef")."\n";
		#print "\tline = $arg->{'line'}\n";
		#if (defined $arg->{'default'}) {
			#print "\tdefault = $arg->{'default'}\n";
		#}
		#print "\tellipsis = $arg->{'ellipsis'}\n";
	}
	return \@argList;
	}
	else {
		return [];
	}
}

sub initVarData($) {
	my $line = shift;
	
	return {'line' => $line};
}

sub createVariablesNodes($$$$) {
	my $proto = shift;
	my $varData = shift;
	my $kind = shift;
	my $line = shift;

	# get the first var
	my $node = Node($kind, \$proto);
	my $data = shift @$varData;
	SetName($node, $data->{'name'});
	setCSKindData($node, 'type', $data->{'type'});
	if (defined $data->{'default'}) {
		Append($node, Node(InitKind, \$data->{'default'}));
	}
	SetLine($node, $line);
		
	# get additional vars ...
	if (scalar @$varData) {
		my @add_vars = ();
		for	my $data (@$varData) {
			my $addVarNode = Node($kind, \$proto);
			SetName($addVarNode, $data->{'name'});
			setCSKindData($addVarNode, 'type', $data->{'type'});
			if (defined $data->{'default'}) {
				Append($addVarNode, Node(InitKind, \$data->{'default'}));
			}
			SetLine($addVarNode, $line);
			push @add_vars, $addVarNode;
			# record info in the node : the var is declared inside same statement than previous.
			setCSKindData($addVarNode, 'multi_var_decl', 1);
		}
		setCSKindData($node, 'addnode', \@add_vars);
	}
	
	return $node;
}

sub parseVariableList($$$) {
	my $stmt = shift;
	my $data = shift;
	my $line = shift;

	my @varList = ();
	
	# Copy data in case there were several variables. Indeed,
	# the function &parseName() can modify the type if a tab operator
	# is detected behind the name.
	my %commonData = %$data;
	
	if (!defined parseName($stmt, $data)) {
		return undef;
	}

	parseDefaultValue($stmt, $data);
	
	# Save the first variable
	push @varList, $data;
	
	while ($$stmt =~ /\G\s*,/gc) {
		my %otherVarData = %commonData;
		if (!defined parseName($stmt, \%otherVarData)) {
			last;
		}
		
		parseDefaultValue($stmt, \%otherVarData);
		
		push @varList, \%otherVarData;
	}
	
	# At this stage, the whole declaration expression should have been parsed ...
	# If the remaining of the expression is not blank or end of string, then it is not a variable declaration
	if ( $$stmt =~ /\G\s*\S/gc) {

		return undef;
	}
	
	#my $varNodes = createVariablesNodes($stmt, \@varList, $kind, $line);
	
	return \@varList;
}

my %H_CLOSING = ( '(' => ')', '{' => '}', '[' => ']', '<' => '>' );
my %H_REG = ( 	'(' => qr/\(|\)|[^\(\)]*/, 
				'{' => qr/\{|\}|[^\{\}]*/,
				'[' => qr/\[|\]|[^\[\]]*/,
				'<' => qr/<|>|[^<>]*/ );

sub parseEnclosedStr($$;$) {
	my $stmt = shift;
	my $open = shift;
	my $userOutput = shift;
	
	my $output;
	if (defined $userOutput) {
		$output = $userOutput
	}
	else {
		my $tmp = "";
		$output = \$tmp;
	}
	
	my $close = $H_CLOSING{$open};
	my $reg = $H_REG{$open};
	
	my $level = 1;
	
	while ($$stmt =~ /\G($reg)/gc) {
		if ($1 eq $open) {
			$level++;
			$$output .= $1;
		}
		elsif ($1 eq $close) {
			$level--;
			$$output .= $1;
			if ($level == 0) {
				last;
			}
		}
		else {
			$$output .= $1;
		}
	}
	
	return $output;
}

sub parseDestructuring($$$$) {
	my $stmt = shift;
	my $line = shift;
	my $commonType = shift;
	my $kind = shift;
	
	my @varList = ();
	my $commonData = initVarData($line);
	
	my $node = Node(DestructuringKind, createEmptyStringRef());
	SetLine($node, $line);
	
	my $statement = GetStatement($node);
	$$statement .= "(";
	my $coma = "";
	
	my $error = 0;
#print STDERR "DESTRUCTURING : $$stmt\n";

	while ($$stmt !~ /\G\s*\)/gc) {
		# parse until , or )
		my $rawVar = "";
		while ($$stmt =~ /\G\s*(\(|\[|\{|[^,\)\{\[\(]+)/gc ) {
			if (($1 eq '(') || ($1 eq '{') || ($1 eq '[')) {
				$rawVar .= $1;
				parseEnclosedStr($stmt, $1, \$rawVar);
			}
			else {
				$rawVar .= $1;
			}
		}
#print "DESTRUCTURING VAR = $rawVar\n";
		# swallow , if any
		$$stmt =~ /\G\s*,/gc;
		
		my $data = initVarData($line);
		my $var = {};
		if (defined parseType(\$rawVar, $data)) {
			
			# parse the var with default init in any ...
			$var = parseVariableList(\$rawVar, $data, $line);
			
			if (defined $var and (scalar @$var >= 1)) {
				# get the var (parseVariableList return a list, but we know that only one var is present, because $rawVar is only one)
				$var = $var->[0];
			}
			else {
				# no var detected, this mean that the type was not followed by a name.
				# init by default to the incomplete $data
				$var = $data;
			}
			
			if ((! defined $var->{'name'}) && (defined $var->{'type'})) {
				# name is mandatory, and type no ==> the detected type is the name !!!
				$var->{'name'} = $var->{'type'};
				if ($commonType) {
					$var->{'type'} = $commonType;
				}
				else {
					delete $var->{'type'};
				}
			}
		}
		
		if (defined $var->{'type'} && $var->{'type'} ne "") {
			# statement is a variable declaration
			push @varList, $var;
			$$statement .= "$coma __decl__".$var->{'name'};
		}

		$coma = ",";
	}
	
	$$statement .= ")";
	
	if ($error) {
		Lib::Log::ERROR("Unable to parse destructuring variables at line $line");
		my ($rawStmt) = $$stmt =~ /\G([^\)]*)/gc;
		SetStatement($node, $rawStmt);
	}
	
	if (scalar @varList > 0) {
		my $varNodes = createVariablesNodes($stmt, \@varList, $kind, $line);
		Append($node, $varNodes);
	}
	
	if ($$stmt =~ /\G\s*=\s*(.*)/sgc) {
		my $statement = $1;
		my $initNode = Node(InitKind, \$statement);
		SetLine($initNode, $line);
		Append($node, $initNode);
	}
	
	return $node;
}

# called in variable context : class member or methods arguments
# -> if the expression begins with a "(", the prenthese will be parsed as compound type.
# -> destructuring will be considered only if the "(" is preceded with a type ...
sub parseVariableDeclaration($$$) {
	my $stmt = shift;
	my $line = shift;
	my $kind = shift;
	
	my $data = initVarData($line);

	if (defined parseType($stmt, $data)) {
		# if a parenthese is following the type ...
		if ($$stmt =~ /\G\s*\(/gc) {
			if ($$stmt =~ /^[^\)]+\)\s*=/m) {
				return parseDestructuring($stmt, $line, $data->{'type'}, $kind);
			}
		}
		else {
			# type has been parsed and stored inside $data
			my $varList = parseVariableList($stmt, $data, $line);
			if (defined $varList) {
				return createVariablesNodes($stmt, $varList, $kind, $line);
			}	
		}
	}
	return undef;
}

# Called in "instruction statement" context.
# -> for expression beginning with "(", the parentheses will not be parsed as a compound type, but as a destructuring assignment left value
sub parseVariableStatement($$$) {
	my $stmt = shift;
	my $line = shift;
	my $kind = shift;
	
	if ($$stmt =~ /\A\s*\(/gc) {
		if ($$stmt !~ /\G.*?\)\s*=[^=>]/) {
			# the parenthesed expression is not followed by = 
			# => means low probabiliy that it was a variable déclarion statement
			return undef;
		}
		return parseDestructuring($stmt, $line, "", $kind);
	}
	else {
		
		# CHECK : 
		# assume that a statement consisting with something followed by parentheses not followed by =, is a function call.
		# example of FUNCTION CALL: 
		#   Assert.Throws<ArgumentException>(() => Kruskal.Solve(adj), "Graph must be undirected!");
		#
		# example of VARIABLE DECLARATION with destructuring assignment : 
		#   myType(a, b) = <expression>;
		#   myType lastColumn = rotations.Select(x => x[^1])ToArray();
		
		if ($$stmt =~ /\A\s*\S[^\(=]*\(/gc) {
			# statement begin with non blank followed by openning parenthese
			if ($$stmt !~ /\G.*?\)\s*=[^=>]/) {
				# the parenthesed expression is not followed by = 
				# => means low probabiliy that it was a variable déclarion statement
				return undef;
			}
		}
		return parseVariableDeclaration($stmt, $line, $kind);
	}
}

1;
