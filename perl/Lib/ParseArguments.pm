package Lib::ParseArguments;

use strict;
use warnings;

use Lib::NodeUtil ;
use Lib::Log;

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
			if (($2 eq '(') || ($2 eq '{') || ($2 eq '[')) {
				$default .= $2;
				$default .= getUntilPeer($stmt, $2);
				if (! defined pos($$stmt)) {
					# end of function proto has been encountered before the end of the default value expression.
					last;
				}
			}
			else {
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
	
	# arg with trivial type syntax : <type> <name>
	if ($$stmt =~ /\G\s*([*&]*)(\w+)/sgc) {
		$data->{'type'} .= $1;
		$data->{'name'} = $2;
	}
	# arg with complex type syntax (C++)
	elsif ($$stmt =~ /\G\s*\(\s*\*\s*(\w+)\s*\)\s*(\([^)]*\))/sgc) {
			# function pointer ... <type> (*<name>)(<params>)
			$data->{'name'} = $1;
			$data->{'type'} .= ' (*)'.$2;
	}
	elsif ($$stmt =~ /\G\s*\(\s*([*&])\s*(\w+)\s*\)/sgc) {
			# parenthesed ... <type> ([*&]<name>)
			$data->{'name'} = $2;
			$data->{'type'} .= $1;
	}
	else {
		return undef;
	}
	
	# in C++ parseName is used to parse the name of the new type in a typedef statement
	# but it can use template syntax like in : 
	# typedef Matrix<N,1> Vector<N>;  ==> parseName will be used to parse "Vector<N>"
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
	
	while ($$stmt =~ /\G(\s*\[\s*\w*\s*\])/sgc) {
		$data->{'type'} .= $1;
		$tab .= $1;
	}
	
	if ($tab ne "") {
		$data->{'tab'} = $tab;
	}
}

sub parseType($$) {
	my $stmt = shift;
	my $data = shift;
	
	my $typeName = "";
#print STDERR "STMT = $$stmt\n";
	my $initial_pos = pos($$stmt);
	
	# Specific type with modifiers for C++
	#     Modifiers can be followed with macro defining a type, for example :
	#           template<typename LINK> unsigned __int64 CHashTableOfGenericLinks<LINK>::GetKey(...)
	#           bool CHasherForTableOfEscalatedLinks::is_valid_key( const unsigned __int64 & key ) const
	#     So the regexp should take into account that the modifiers can be followed by an arbitrary word, itself followed by another word or a "&" or a "*"
	if ($$stmt =~ /\G\s*((?:(?:signed|unsigned|long|short|int|char|double)\b\s*(?:\w+\s+(?:\b|[&*]))?)+)/gc) {
		$typeName .= $1;
		$typeName =~ s/\s+$//m;
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
	if ($$stmt =~ /\G(\s*(?:far|near))/gc) {
		$typeName .= $1;
	}

	# C++ specific : pointers or references
	if ($$stmt =~ /\G(\s*[*&][*&\s]*)/gc) {
		$typeName .= $1;
	}

	# in C++, const can be placed after the type name
	# swallow "const" qualifier ...
	if ($$stmt =~ /\G\s*const\b([*&\s]*)/gc) {
		$typeName .= $1;
	}
	
	# CLI (managed C++)
	# support hat operator (^)
	if ($$stmt =~ /\G\s*(\^)/gc) {
		$typeName .= $1;
	}
	
    
	# $data->{'type'} = $typeName;
	
	# parseTab($stmt, $data);
	
	# return 1;
 
    if (! defined $typeName)
    {
       return undef;
    }
    else
    {
       $data->{'type'} = $typeName;
#print STDERR "TYPENAME = $typeName\n";
       parseTab($stmt, $data);
       
       return 1;
    }
}

sub parseAnnotation($$) {
	my $stmt = shift;
	my $data = shift;
	
	$data->{'annotation'} = "";
	
	while ($$stmt =~ /\G\s*(\@\w+(?:\s*\([^()]*\)\s*)?)/gc) {
		$data->{'annotation'} .= $1;
	}
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
	
	if (parseEllipsis($stmt, $data)) {
		$data->{'type'} = "";
		$data->{'name'} = "";
		return $data;
	}
	
	# Java specifics ...
	parseAnnotation($stmt, $data);
	
	# C++/CLI specifics : swallow annotations ...
	$$stmt =~ /\G\s*(?:_In_|_Out_|_In_opt_)\b/gc;
	
	# swallow "final" or "const" qualifier ...
	$$stmt =~ /\G\s*(?:final|const)\b/gc;
	
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
	
	parseEllipsis($stmt, $data);

	if (! defined parseName($stmt, $data)) {
		# do not warn : no name is compliant with C++ syntax in prototype 
		# print STDERR "[ParseArguments] warning : ($$stmt) no name for arg at line ".($data->{'line'}||"?")."\n"; 
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
# NOTE : in order to support several languages, the function should support:
# - type and name extraction
# - default values after "=" symbol
# - ellipsis (warning, there are differences between Java and C++)
# - genericite (type<a, b,..>)

sub parseArguments($;$) {
	my $artifactNode = shift;
	my $allowNoType = shift || 0;
	my @argList = ();
	
	my $stmt = GetStatement($artifactNode);
	my $line = GetLine($artifactNode);
	# stop after the first "(" or the last "\n" before the first non blank!
	$$stmt =~ /\A[^(]*\(/sg;
	
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

sub initVarData($) {
	my $line = shift;
	
	return {'line' => $line};
}

sub parseVariableDeclaration($$) {
	my $stmt = shift;
	my $line = shift;
	
	my @varList = ();
	
	my $data = initVarData($line);
	
	if (!defined parseType($stmt, $data)) {
		return undef;
	}
	
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
	
	return \@varList;
}

1;
