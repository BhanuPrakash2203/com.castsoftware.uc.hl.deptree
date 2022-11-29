package Lib::Sources;

use strict;
use warnings;
use AnalyseOptions;
use Encode qw (encode);

sub getFileContent($) {
	my $filename = shift;
	
	my $ret = open FIC, "<$filename";
	
	if (! defined $ret ) {
		return undef;
	}
	
	local $/=undef;
	my $buf = <FIC>;
	close FIC;
	
	return \$buf;
}

sub getSourceRootDir($) {
	my $fileList = shift;
	
	my %H_reps = ();
	
	for my $file (@$fileList) {
		my @subreps = split /[\/\\]/, $file;
		# remove the file name.
		pop @subreps;
		
		# extract the base of the path: ., .., <ident>, <drive>: (windows), <empty string> (root linux)
		my $base;
		if (scalar @subreps > 0) {
			$base = shift @subreps;
		}
		else {
			$base = '.';
		}
		
		# init the path related to the base ...
		my $tree = $H_reps{$base};
		if (! defined $tree) {
			# THE FILE IS IN AN UNKNOW PATH
			# Associate a hash with each sub rep (for late exploitation, hash existing test is faster than string comparison) !!
			my @hreps = ();	
			for my $rep (@subreps) {
				push @hreps, { $rep => 1};
			}
			$H_reps{$base} = \@hreps;
			next;
		}
		
		# THE FILE IS IN AN KNOWNED PATH
		# compare the path of the file to the base tree ... subrep by subrep
		# and truncate the base tree where it differs from the file path !
		my $idx = 0;
		my $nb_subreps = scalar @subreps;
		for my $hrep (@$tree) {
			# check if the idx'th subrep of the file is the same of the idx'th subrep of the tree:
			if ( ($idx == $nb_subreps) || (! exists $hrep->{$subreps[$idx]})) {
				# the path element of the file differs from the base element.
				# So the base element do not belong to a common base of all files directories.
				# So all base element from the index $idx are removed !!
				splice @$tree, $idx;
			}
			$idx++;
		}
	}
	
	# build sources directories (generally one, but it can be several if the list of files is build manually by user !!
	my @tabSrcDir = ();
	for my $base (keys %H_reps) {
		my $tree = $H_reps{$base};
		my $sourceDir = $base."/";
		for my $hrep (@$tree) {
			my @tab = keys %$hrep;
			$sourceDir .= "/".(shift @tab);
		}
		push @tabSrcDir, $sourceDir;
		print "Source directory detected : $sourceDir\n";
	}
	return \@tabSrcDir;
}


# get a list of base directories corresponding to a list of files.
# There can be several directories if there is no common root directory.
sub getSourceDir($$) {
	my $fileList = shift;
	my $options = shift;
	
	# return undef, '' or a directory name terminated with '/' corresponding to the directory specified with "--dir-source" ...
	my $SourceDir = AnalyseOptions::GetSourceDirectory($options);
	my $tabSourceDir ;
	if ((!defined $SourceDir) || ($SourceDir eq '')) {
		$tabSourceDir = getSourceRootDir($fileList);
	}
	else {
		print "Source directory detected : $SourceDir\n";
		$tabSourceDir = [$SourceDir];
	}

	return $tabSourceDir;
}

#-----------------------------------------------------------------------



my $findFiles_fileList;
my $findFiles_filePattern;

my $R_IGNORED = undef;

sub buildIgnoreRE($) {
	my $ignore = shift;
	my $orig = $ignore;
	$ignore =~ s/,/|/g;
	$ignore &&= '^('.$ignore.')$';
	if ($ignore) {
		eval {
			$R_IGNORED = qr($ignore);
		};
		if (defined $@) {
			print STDERR "[Lib::Sources] ERROR : Bad regexp for file exclusion pattern : $orig\n";
		}
	}
}

sub init($) {
	my $options = shift;
	
	if (defined $options->{'--ignore'}) {
		buildIgnoreRE($options->{'--ignore'});
	}
}


sub isIgnoredFile($) {
    my $name = shift;
    return $R_IGNORED && $name =~ $R_IGNORED;
}

sub findFiles_triggerAdd($) {
	my $file = shift;
	push @$findFiles_fileList, $file;
}

sub findFiles_fileMatch($) {
	my $file = shift;
	
	if (!defined $findFiles_filePattern) {
		return 1;
	}
	
	if ($file =~ /^$findFiles_filePattern$/m) {
		return 1;
	}
	return 0;
}

sub _findFiles($$);
sub _findFiles($$) {
	my $dir = shift;
	my $triggers = shift;
	
	my $ret = opendir DIR, $dir;
	
	if (! $ret) {
		print "unable to read directory : $dir\n";
		return
	}
	my @entries = readdir DIR;
	closedir DIR;
	
	for my $file (@entries) {
		
		next if (isIgnoredFile($file));
		
		my $fullfilename = $dir."/".$file;

		if (-f $fullfilename) {
			#if ($file eq $findFiles_filePattern) {
			if (findFiles_fileMatch($file)) {
				#push @$findFiles_fileList, $fullfilename;
				for my $trigger (@$triggers) {
					$trigger->($fullfilename);
				}	
			}  
		}
		elsif ( -d $fullfilename) {
			if (($file eq ".") || ($file eq "..")) {
				next;
			}
			_findFiles($fullfilename, $triggers);
		}
	}
}

sub findFiles($$;$) {
	my $dir = shift;
	$findFiles_filePattern = shift;
	my $callbacks = shift;
	
	if (! defined $callbacks) {
		$callbacks = [\&findFiles_triggerAdd];
		
		# Init the output list.
		$findFiles_fileList = [];
	
		# search ...
		_findFiles($dir, $callbacks);
		
		return $findFiles_fileList;
	}
	
	_findFiles($dir, $callbacks);
	return 0;
}

########################################################################

my @T_Triggers = ();

sub registerPostAnalysisProjectFilesTrigger($) {
	my $callback = shift;
	push @T_Triggers, $callback;
}

sub postAnalysisProjectFilesScanning($) {
	my $tabSourcesDir = shift;
	if (scalar @T_Triggers) {
		findFiles($tabSourcesDir->[0], undef, \@T_Triggers);
	}
}

########################################################################
#                  Check encoding
########################################################################

my @encoding_list = ('iso_8859-1', 'windows-1252');

sub needEncodingForExisting($$) {
	my $path = shift;
	my $filename = shift;
	
	if (! -f $path.$filename) {
		# the file cannot be found  ==> try different enconding
		for my $encoding (@encoding_list) {
			my $encoded = Encode::encode($encoding, $filename);
			if (-f $path.$encoded) {
				return $encoding;
			}
		}
	}
	else {
		# the file can be found ==> needed encoding is none
		return undef;
	}
	
	
	return "unknow";
	
}

1;
