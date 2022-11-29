use warnings;
use strict;

BEGIN
{
  my $rep = $0;

  if ( $rep =~ m/[\/\\]/ )
  {
    $rep =~ s/(.*)[\/\\][^\/\\]+/$1/;
  }
  else
  {
    $rep = '.' ;
  }
  unshift @INC, $rep.'/..';
  unshift @INC, $rep.'/../Lib';
  unshift @INC, $rep.'/../../../../Config';
}

use technos::lib;
use technos::detection;
use technos::config;
use Lib::IsoscopeVersion;

my $HighlightVersion = Lib::IsoscopeVersion::getHighlightVersion();
print "HIGHLIGHT analyzer version : $HighlightVersion\n";

my $root = technos::lib::newDir("", "");

sub usage() {
  print "find_technos.pl\n";
  print "  MANDATORY : \n";
  print "    <dir>\n";
  print "  OPTIONAL : \n";
  print "    --output      = <dir>             # directory where to write exported results\n";
  print "    --export      = <format>          # ask exportation. Available formats are : csv and lst\n";
  print "    --dialog      = <dir>|stdout      # activate GUI dialog\n";
  print "    --technos     = <technos list>    # list of searched technos (all technos by default)\n";
  print "    --extensions  = <config file>     # config file for own extensions/techno association\n";
  print "    --ignore      = <file name list>  # comma separated list of directories or files base name to ignore\n";
  print "    --ignorePath  = <regex>           # regular expression to ignore relative path to <dir>\n";
  print "    --no-context                      # no context resolution\n";
  print "    --no-direct-resolution            # no direct resolution (from extension)\n";
  print "    --no-progression                  # do not display progression events\n";
  print "    --print-available-technos         # print the list of available technos\n";
}

sub printAvailableTechnos() {
	my $technos = technos::config::getAvailableTechnos();
	
	print "Available technos are : ". join(', ', @$technos) ."\n";
}

sub getCommandLine() {
  my %options = ();
  my $dir;

  if ( scalar @ARGV < 1) {
    usage();
    exit(0);
  }

  foreach my $param ( @ARGV ) {
    if ( $param !~ /^-/m ) {
      if (defined $dir) {
        print "WARNING : parameter $param will be ignored !!\n";
      }
      else {
        $dir = $param;
        technos::lib::setBaseSearchDir($dir);
      } 
    }
    elsif ($param =~ /^--([^=]+)=(.+)/m) {
    technos::lib::OUTPUT "Set option $1 to $2\n";
      $options{$1} = $2;
    }
    elsif ($param =~ /^--([^=]+)/m) {
      technos::lib::OUTPUT "Set option $1 to ON\n";
      $options{$1} = 1;
    }
  }

  # fast handling of informative options
  if (defined $options{'print-available-technos'}) {
    printAvailableTechnos();
    exit 0;
  }

  if (!defined $dir) {
    technos::lib::OUTPUT "You must specify a directory.\n";
    exit;
  }

  return ($dir, \%options);
}

my $FD_OUTPUT_LIST;

sub find_REGULAR($;$) {
  my ($dir, $OUTPUT_LISTING) = @_ ;
  
  sub recurse($$$);

  sub recurse($$$) {
    my ( $fullDir, $relativeDir, $parent ) = @_ ;
#technos::lib::OUTPUT "dhECTORY ANALYZED : $fullDir\n";

    #----------------------------------------------------------
    #  CREATE DATA
    #----------------------------------------------------------
    my @subDirs = ();
    my $dirnode = technos::lib::newDir($fullDir, $relativeDir, $parent);
#    technos::lib::ddDirNode($fullDir, $dirnode);

    # Load from .casthighlight if any
    #  Applies the user's discovery settings for given files
    technos::lib::loadHistory($dirnode);
	
#print "---> ".(scalar @files)." files\n";
    # for each element of the directory,
    # verify its statut (directory -d or file -f)
    #----------------------------------------------------------
    #  TREAT dhECTORIES ENTRIES
    #----------------------------------------------------------

    #----------------------------------------------------------
    #  READ dhECTORY
    #----------------------------------------------------------
    opendir(my $dh, $fullDir) or die "can't open $fullDir: $!\n";
    while (readdir $dh) {

       next if technos::config::isIgnoredFile($_);

       # write the full path of the element 
       #my $file_path = $fullDir."\\".$file;

       # If the element is a directory (-d matches directory) : launch again ...
       my $complete_path = $fullDir."/".$_;
       my $relative_path = $relativeDir;
       if ($relativeDir eq "") {
           $relative_path .= $_;
       }
       else {
           $relative_path .= "/$_";
       }

       next if technos::config::isIgnoredPath($relative_path);

       if (-d $complete_path) {
           push @subDirs, [$complete_path, $relative_path, $dirnode];
       }
       else {
			if (defined $FD_OUTPUT_LIST) {
				print $FD_OUTPUT_LIST "$complete_path\n";
			}
           technos::detection::declareFile(\$complete_path);
       }
    }
    closedir($dh);

    #----------------------------------------------------------
    #  TREAT SUBdhECTORIES
    #----------------------------------------------------------
    for my $subDir (@subDirs) {
        recurse($subDir->[0],     # complete path
                $subDir->[1],     # relative path
		$subDir->[2]);    # parent node.
    }
  }

  if (defined $OUTPUT_LISTING) {
	  my $ret = open $FD_OUTPUT_LIST, ">$OUTPUT_LISTING";
	  if (! $ret) {
		  print STDERR "[find_techno.pl] unable to open source listing file : $OUTPUT_LISTING\n";
		  $FD_OUTPUT_LIST = undef;
	  }
	  else {
		  binmode($FD_OUTPUT_LIST, ":utf8");
	  }
  }
  my $relativeDir = "";
  recurse($dir, $relativeDir, $root);
}

#--------------------------------------------------
#---------------------- MAIN ----------------------
#--------------------------------------------------

my ($SrcDir, $options) = getCommandLine();


if ((defined $options->{'export'}) && ($options->{'export'} eq 'lst')) {
	if (! defined $options->{'technos'}) {
		print "Command line error : --export=lst require usage of --technos specifying a single techno\n";
		exit 1;
	}
	elsif ($options->{'technos'} =~ /,/) {
		print "Command line error : --export=lst require usage of --technos specifying a single techno\n";
		exit 1;
	}
}

technos::config::setCommandLineOptions($options);

technos::lib::canonizeDir(\$SrcDir);

if (defined $options->{'no-progression'}) {
  technos::lib::setProgression(0);
}

if (defined $options->{'export'}) {
  # if an export format is specified, then do not print the result on the
  # output.
  technos::lib::setOutput(0);
}

if (defined $options->{'output'}) {
  technos::lib::setOutputDir($options->{'output'});
  technos::lib::setBinaryLibCsvDir($options->{'output'});
}

if (defined $options->{'dialog'}) {
  technos::lib::OPEN_GUI($options->{'dialog'});
}

technos::lib::openBinaryLibCsv();

technos::lib::initTime();

technos::lib::phase_file_discovering();

my $SourceListingFile = undef;
if (defined $options->{'source-listing'}) {
	if (defined $options->{'output'}) {
		$SourceListingFile = $options->{'output'}."/".$options->{'source-listing'};
	}
	else {
		$SourceListingFile = $options->{'source-listing'};
	}
}

find_REGULAR($SrcDir, $SourceListingFile);

technos::detection::start();

# COMPUTE UNRECOGNIZED with potential
technos::detection::checkPotentialTechno();

if (! defined $options->{'--no-unknow-resolution'}) {
  # COMPUTE UNRECOGNIZED without potential
  technos::detection::checkWithoutPotentialTechno();
}

# COMPUTE USING CONTEXT 
if (! defined $options->{'no-context'}) {
  technos::detection::checkWithContext();
}

technos::lib::phase_finalizing();

technos::detection::exportResult($root, $options);

technos::lib::CLOSE_GUI();

technos::lib::traceEvent("STOP");

technos::lib::printSummary();

technos::lib::printTimeLog();
