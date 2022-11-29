package framework::version;
use strict;
use warnings;

use framework::Logs;

sub compareVersion($$);

sub getCanonicalVersion($) {
	my $version = shift;
	
	if (! defined $version) {
		return undef;
	}
	
	# replace  by a ".", all "-" or "_" not followed by a "x" or a digit
	$version =~ s/[\-_](?=[^x\d]|$)/\./mg;
	#my $VERSION_BASE_ITEM = '(?:[\d\.]|x(?:\.|$))';
	my $VERSION_BASE_ITEM = '(?:\d+|x(?:\.|$))';
	my ($vers, $tag) = $version =~ /($VERSION_BASE_ITEM(?:\.$VERSION_BASE_ITEM)*)[\.\-_]*(.*)/m;
#print "=============> VERSION/TAG ($version) ==> $vers  /  $tag \n";
	return ($vers, $tag);
}

sub isComparable($) {
	my $ver = shift;
	
	if (!defined $ver) {
		return 1;
	}
	
	if ($ver eq "-") {
		return 1;
	}
	
	if ($ver =~ /[^\.\dx]/) {
		return 0;
	}
	return 1;
}

sub makeComparable($) {
	my $version = shift;
	
	if (!defined $version) {
		return [];
	}
	
	if ($version eq "-") {
		return [];
	}
	
	if (! isComparable($version) ) {
		framework::Logs::Warning("version format <$version> is not supported\n");
		return [];
	}
	
	# by robustness, remove all that is behind a "x" digit.
	# ex:   version 2.x.1 will become version 2.x ...
	$version =~ s/\.x.*$/\.x/;
	
	my @normalized = split '\.', $version;
	return \@normalized;
}

sub getMinVersion($$) {
	my $v1 = shift;
	my $v2 = shift;

	if (! defined $v1) {
		return $v2;
	}
	elsif (!defined $v2) {
		return $v1;
	}
	else {
		my $c_v1 = makeComparable($v1);
		my $c_v2 = makeComparable($v2);

		my ($comp) = compareVersion($c_v1, $c_v2);
		if ($comp == 1) {
			return $v1;
		}
		else {
			return $v2;
		}
	}
}

sub getMaxVersion($$) {
	my $v1 = shift;
	my $v2 = shift;

	if (! defined $v1) {
		return $v2;
	}
	elsif (!defined $v2) {
		return $v1;
	}
	else {
		my $c_v1 = makeComparable($v1);
		my $c_v2 = makeComparable($v2);
		
		my ($comp) = compareVersion($c_v1, $c_v2);
		if ($comp == 1) {
			return $v2;
		}
		else {
			return $v1;
		}
	}
}

# Build a range [ min, max ] from a version formalism.
# The formalism is based on >, <, >=, <=, ==, ~>
# NOTE : 1 - strict comparisons are not supported and promoted in non strict comparison.
#        2 - ~> means : from the version indicated, until the last version where only the last digit is changing.

sub makeRange($);
sub makeRange($) {
	my $version = shift;

	if (!defined $version) {
		return (undef, undef);
	}
#print "[makeRange] : $version\n";

	# extract from parentheses or brackets ...
	#-----------------------------------------
	if ($version =~ /^\s*\(/) {
		($version) = $version =~ /\(([^\)]*)/;
	}
	elsif ($version =~ /^\s*\[/) {
		($version) = $version =~ /\(([^\]]*)/;
	}

	# Case of version containing range : split if coma separated...
	#--------------------------------------------------------------
	if ($version =~ /,/) {
		my ($v1, $v2) = split ',', $version;
		my ($min_v1, $max_v1) = makeRange($v1);
		my ($min_v2, $max_v2) = makeRange($v2);
		my $MIN = getMaxVersion($min_v1, $min_v2);
		my $MAX = getMinVersion($max_v1, $max_v2);

		return ($MIN, $MAX);
	}
	
	
	# basic treatment of a simple version 
	#----------------------------------
	if ($version =~ />=\s*(.*)/m) {
		return ($1, undef);
	}
	elsif ($version =~ /<=\s*(.*)/m) {
		return (undef, $1);
	}
	elsif ($version =~ /~>\s*(.*)/m) {
		return ($1, undef);
	}
	elsif ($version =~ /~=\s*(.*)/m) {
		#print "WARNING COMPATIBLE RELEASE COMPARISON IS NOT SUPPORTED !!!\n";
		# ~=V.N is both both >=V.N & ==V.*,
		# so range should be [V.N, (V+1)[
		# the best approximation is [V.N, (V+1)]
		
		return ($1, undef);
	}
	elsif ($version =~ />\s*(.*)/m) {
		#print "WARNING STRICT COMPARISON IS NOT SUPPORTED !!!\n";
		return ($1, undef);
	}
	elsif ($version =~ /<\s*(.*)/m) {
		#print "WARNING STRICT COMPARISON IS NOT SUPPORTED !!!\n";
		return ($1, undef);
	}
	elsif ($version =~ /!=?\s*(.*)/m) {
		#print "WARNING NEGATION IS NOT SUPPORTED !!!\n";
		return (undef, undef);
	}
	elsif ($version =~ /==?\s*(.*)/m) {
		return ($1, $1);
	}

	# FIXE : should support the caret syntax. for semver, mins all version up to the specified taht do not increment the major version.
	#      ex : ^1.2.3 is [1.2.3 - 2.0[

	return ($version, $version);
}

sub detectFrameworkNameInFileName($) {
	my $basefilename = shift; # no dirname inside
	
	my ($fw_name) = $basefilename =~ /^(.*?)(?:[\.\-]\d|$)/;
	
	return $fw_name;
}

sub detectVersionInFileName($$) {
	my $pattern = shift; # generally the BASE FILENAME 
	my $options = shift; # options
	
	$options //= {};
	
	my $getVersion = $options->{'getVersion'};
	
	return undef if ((defined $getVersion) and ($getVersion eq 'no'));
	
	my %REGS = (
		'strict' 		=> qr/[\.\-_](\d+(?:[\.\-_][\d]+)*)/,
		'endplaced' 	=> qr/[\.\-_](\d+.*)\.\w+$/,
	);
		
	# default regexp for version extraction in files names
	my $regexp = $REGS{'strict'};
		
	# use highlight's base configuration (if any...)
	if (defined $getVersion) {
		if (ref $getVersion eq 'Regexp') {
			$regexp = $getVersion;
		}
		else {
			if (defined $REGS{$getVersion}) {
				$regexp = $REGS{$getVersion};
			}
			elsif ($getVersion ne 'yes') {
				framework::Logs::Warning("No file name version extraction regexpr for id : $getVersion\n");
			}
		}
	}

	if ($pattern =~ /$regexp/m) {
		if ($1) {
			my ($version, $tag) = framework::version::getCanonicalVersion($1);
			framework::Logs::Debug(" ** extracted version : $version\n");
			return ($version, $tag);
		}
	}
	
	return undef;
}

#********************* DEFAULT MERGING CALLBACK ************************


# return (compare, finest):
# ** compare value is:
#	-1 if previous version is greater
#	 0 if both are equal (or empty)
#  	 1 if new version is greater.
#
# ** finest value is
#	undef if compare is not 0
#	-1 if the previous version has the more accurate representation.
#	 1 if the new version has the more accurate representation.
#		note : the more accurate representation is the one who has the farthest "x", or no "x".

sub compareVersion($$) {
	my $preVer = shift;
	my $newVer = shift;

	if (scalar @$preVer) {
		if (scalar @$newVer) {
			my $i;
			for (my $i=0;;$i++) {
				my $preNum = $preVer->[$i];
				my $newNum = $newVer->[$i];
				
				if ((! defined $preNum) && (! defined $newNum)) {
					# same number of nums, all equals => same version
					return (0, 1);
				}
				
				if (! defined $newNum) {
					$newNum = 0;
				}
				elsif ($newNum eq 'x') {
					# x is equal with anything
					# same version representation but "preVer" is the more accurate.
					return (0, -1);
				}
				
				if (! defined $preNum) {
					$preNum = 0;
				}
				elsif ($preNum eq 'x') {
					# x is equal with anything
					# same version representation but "newVer" is the more accurate.
					return (0, 1);
				}

				if ($preNum == $newNum) {
					next;
				}
				
				if ($preNum > $newNum) {
					return (-1, undef);
				}
				else {
					return (1, undef);
				}
			}
		}
		else {
			return (-1, undef);
		}
	}
	elsif (scalar @$newVer) {
		return (1, undef);
	}
	
	# versions are identical. 
	return (0, 1);
}

1;
