package technos::lib;

use warnings;
use strict;

use technos::id;
use technos::config;
use technos::check;

use Lib::SHA;
use Lib::IsoscopeVersion;
use AnalyseOptions;


use Time::HiRes qw( gettimeofday tv_interval );
use File::Path qw(make_path);

my $TRACE = 1;
my $TRACE_OUTPUT = 1;
my $TRACE_PROGRESSION = 1;

sub setProgression($) {
  $TRACE_PROGRESSION = shift;
}

sub setOutput($) {
  $TRACE_OUTPUT = shift;
}

my $OutputDir = "./";
my $baseSearchDir = "";

sub setOutputDir($) {
  my $dir = shift;

  $OutputDir = $dir;

  if (! -d $OutputDir ) {
	  make_path($OutputDir);
  }
}

sub setBaseSearchDir($) {
  my $dir = shift;

  $baseSearchDir = $dir;
  $baseSearchDir =~ s/\\/\//g;
}

# forward declarations
sub getDirNode($);

sub OUTPUT($) {
  my $msg =shift;
  if ($TRACE_OUTPUT) {
    print $msg;
  }
}

sub PROGRESSION($) {
  my $msg =shift;
  if ($TRACE_PROGRESSION) {
    print STDERR $msg;
  }
}

#--------------------  GUI COMMUNICATION -------------------

my $FD_GUI = undef;
my $close_GUI_callback = undef;

sub OPEN_GUI($) {
  my $dialog = shift;

  if ($dialog eq "stdout") {
    OUTPUT "Dialog set to stdout\n";
    $FD_GUI = *STDOUT;
    # perform flush after each write
    select $FD_GUI; $| = 1;
    select STDOUT;
    binmode(STDOUT, ":utf8");

    # deactive output traces (because the sdtout stream i required for dialog.
    setOutput(0);
  }
  else {
    # normalize path with "/"
    $dialog =~ s/\\/\//g;

    # add missing terminal "/"
    if ($dialog =~ /[^\/]$/m) {
      $dialog .= "/";
    }

    # open dialog file
    my $filename = $dialog."technos_detection.txt";
    my $ret = open GUI, ">$filename";
    if ( ! $ret ) {
      print "problem with openning $filename : $!\n";
      print "Unable to dialog with GUI";
      exit 1;
    }
    else {
      OUTPUT "Dialog file <$filename> created\n";
      $FD_GUI = *GUI;
      # perform flush after each write
      select $FD_GUI; $| = 1;
      select STDOUT;
      $close_GUI_callback = sub () {close $FD_GUI;};
    }
  }
}

sub SEND_EVENT($) {
	# the function
}

sub SEND_GUI($) {
  my $msg = shift;

  if (defined $FD_GUI) {
    print $FD_GUI $msg."\n";
  }
}

sub SEND_GUI_FILE($$) {
	my $file=shift;
	my $status = shift;

	# quote filename to escape csv delimiter ";".
	my $filename = "\"" . $file->[FILE_DIR]->[DIR_NAME] . "/" . $file->[FILE_NAME] . "\"";
    my @techs = keys %{$file->[FILE_TECHNOS]};
    my @potechs = keys %{$file->[FILE_POTENTIAL_TECHNOS]};

    SEND_GUI("FILE;".$file->[FILE_ID].";".
                   $filename.";".
                   join(':', @{technos::config::getAnalyzableTechnos(\@potechs)}).";".
                   join(':', @{technos::config::getAnalyzableTechnos(\@techs)}).";".
                   $status
            );
}

sub CLOSE_GUI() {
  technos::lib::SEND_GUI("STOP");

  if (defined $close_GUI_callback) {
    $close_GUI_callback->();
  }
}

#---------------------- some services --------------------------

sub ERROR($) {
  my $msg =shift;
  print $msg;
}

sub canonizeDir($) {
  my $dir = shift;

  # Mark network root
  $$dir =~ s/^\\\\/RESO/;
  # several "\" become "/"
  $$dir =~ s/\\+/\//g;
  # several "/" become "/"
  $$dir =~ s/\/+/\//g;
  # remove ending "/"
  $$dir =~ s/\/+$//gm;
  # root network is restored if any.
  $$dir =~ s/^RESO/\\\\/;
}

sub splitFilename($) {
	my $file = shift;
	my ($dir, $name) = $$file =~ /^(.*)[\\\/]+([^\\\/]+)/m;
	return (\$dir, \$name);
}


sub getFileContentOnly($;$) {
  my $file = shift;
  my $mode = shift;

  my $dir = getFileDir($file);

  my $filepath = ($dir->[0])."/".($file->[0]);

  if (! defined open FIC, "<$filepath") {
    print STDERR "ERROR : unable to open $filepath\n";
    return undef;
  }
  if (defined $mode) {
		binmode (FIC, $mode);
  }

  local $/=undef;
  my $buf = <FIC>;
  close FIC;

  return \$buf;
}

sub getFileContent($) {
  my $file = shift;

  my $buf = getFileContentOnly($file);

  if (! defined $buf) {
	addFileError("unreadable", $file);
	return undef;
  }

  if (technos::config::isBinary($buf)) {
    addFileError("binary file", $file);
    return undef;
  }

  return $buf;
}

#------------- TECHNOS WITHOUT EXTENSION  -----------------
# List of technos for witch source files can have any extension.

my @TechnosWithAnyExt = (
	KornShell,
# PL1 should be checked before Cobol because PL1 code embed some cobol code
# in comment. Recognizing PL1 first will avoid recoignizing erroneous cobol
# program !
	PL1,
	Cobol,
	Abap,
);

sub getTechnosWithAnyExt() {
  return \@TechnosWithAnyExt;
}

#------------- EXCLUSIVE TECHNOS -----------------
# List of technos for which source file can contain only one techno.
# When the content of a file is reconized to a such techno, then other
# technos are impossible.
#
# WARNING : each techno referenced here must have a callback referenced in
#           H_CheckingCallback

my %H_ExclusiveTechnos = (
    Objective_C() => 1,
#    PlSql() => 1,
#    TSql() => 1,
    PL1() => 1,
    Cobol() => 1,
);

sub isExclusiveTechno($) {
  my $tech = shift;
  if (exists $H_ExclusiveTechnos{$tech}) {
    return 1;
  }
  return 0;
}

#------------- TECHNOS <-> CONTENT TYPE ----------------------

my %Techno2Type = (
	PHP 		=> 'WEB',
	JS_EMBEDDED => 'WEB',
	PlSql		=> 'SQL',
	TSql		=> 'SQL',
	Sybase		=> 'SQL',
	MySQL		=> 'SQL',
    PostgreSQL	=> 'SQL',
	DB2			=> 'SQL',
    MariaDB		=> 'SQL'
);

sub getType($) {
  my $tech = shift;
  return $Techno2Type{$tech};
}

#------------- FILE TYPE <-> TECHNO EXTRACTION ---------------

my %H_TechnosExtractionCallback = (
	'WEB' => \&technos::check::checkWebContent,
	'SQL' => \&technos::check::ExtractSQL,
);

sub getExtractionCallback($) {
  my $type=shift;
  return $H_TechnosExtractionCallback{$type};
}


#------------- TECHNOS <-> CHECKING CALLBACK ------------------

my %H_CheckingCallback = (
    C_Cpp()       => \&technos::check::check_CCpp,
    Cobol()       => \&technos::check::checkCobol,
    KornShell()   => \&technos::check::checkKsh,
    Matlab()      => \&technos::check::checkMatlab,
    Objective_C() => \&technos::check::check_ObjC,
    #PlSql() => \&technos::check::checkPlSql,
    PL1() => \&technos::check::checkPL1,
    #TSql() => \&technos::check::checkTSql,
    VB_DotNet() => \&technos::check::check_VbDotNet,
    Apex()      => \&technos::check::check_Apex
);

sub checkTechno($$;$) {
  my $tech = shift;
  my $content = shift;
  my $opt = shift;

  if (exists $H_CheckingCallback{$tech}) {
    return $H_CheckingCallback{$tech}->($content, $opt);
  }

  return undef;
}


#------------- TECHNOS DISCRIMINATION <-> CHECKING CALLBACK ------------------

sub checkExclusiveTechno($$) {
  my $tech = shift;
  my $content = shift;

  if (exists $H_ExclusiveTechnos{$tech}) {
    return checkTechno($tech, $content);
  }

  return undef;
}

#------------- POTENTIAL/UNKNOW TECHNO FILE LIST ------------------

my @PotentialFilesTechnos = ();
my @UnknowFilesTechnos = ();

sub getPotentialTechnoFileList() {
  return \@PotentialFilesTechnos;
}

sub getUnknowTechnoFileList() {
  return \@UnknowFilesTechnos;
}

sub addUnknowFileTechno($) {
  my $file = shift;

  push @UnknowFilesTechnos, $file;
  SEND_EVENT("UNKNOW;".$file->[FILE_ID]);
  SEND_GUI_FILE($file, "UNKNOW");
}

sub addOutOfContextFile($) {
}

sub addPotentialFileTechno($$) {
  my $file = shift;
  my $technos = shift;

  if (defined $technos) {
    for my $techno (@$technos) {
      addFileTechno($file, $techno)
    }
  }

  push @PotentialFilesTechnos, $file;
}


#--------------------------------------------------
#------------- PROGRESSION MANAGEMENT -------------
#--------------------------------------------------

my $nb_file_total = 0;
my $nb_file_total_resolved = 0;

my $nb_file_to_resolve = 0;
my $nb_file_resolved = 0;
my $resolved_percent_done = 0;

my $nb_to_process = 0;
my $nb_processed = 0;
my $percent_done = 0;

my $nb_file_error=0;

sub printCurrentStat() {
my $potential = scalar @PotentialFilesTechnos;
my $unknown = scalar @UnknowFilesTechnos;

print "---------\n";
print "| POTENTIAL   = $potential\n";
print "| UNKNOW      = $unknown\n";
print "| Resolved    = $nb_file_total_resolved\n";
print "| TOTAL       = ".($potential + $unknown + $nb_file_total_resolved)."\n";
print "---------\n";
}

sub printSummary() {

  OUTPUT "\nSummary :\n";
  OUTPUT "------------ :\n";
  OUTPUT "Total input file : $nb_file_total\n";
  OUTPUT "File processed : $nb_processed\n";
  OUTPUT "File resolved : $nb_file_total_resolved\n";
  OUTPUT "File unresolved with potential techno : ".(scalar @PotentialFilesTechnos)."\n";
  OUTPUT "File unresolved with unknow techno : ".(scalar @UnknowFilesTechnos)."\n";
  OUTPUT "File with errors : $nb_file_error\n";

}

sub initProgression() {
  $nb_to_process = scalar @PotentialFilesTechnos + scalar @UnknowFilesTechnos;
  $nb_processed = 0;
  $percent_done = 0;
}

sub incRemainingProgression() {
    $nb_to_process++;
}

sub incProcessedProgression() {
  $nb_processed++;

    my $percent;
    $percent = int ($nb_processed / $nb_to_process * 100);

    if ($percent != $percent_done) {
      $percent_done = $percent;
      PROGRESSION("--> $percent_done\% files processed\n");
    }
}

sub incResolvedProgression() {

  $nb_file_total_resolved++;

    my $percent;
    $percent = int ($nb_file_total_resolved / $nb_file_total * 100);

    if ($percent != $resolved_percent_done) {
      $resolved_percent_done = $percent;
      PROGRESSION("  ==> $resolved_percent_done\% files resolved.\n");
    }
}

# --------------- phases switching --------------

sub phase_file_discovering() {
  PROGRESSION("Searching files ...\n");
  SEND_GUI("STAGE;EXTENSION");
}

sub phase_checking_potential($) {
  my $nbPotential = shift;
  $nb_file_to_resolve = $nb_file_total - $nb_file_resolved;

# init progression !
#  $nb_to_process = scalar @PotentialFilesTechnos;
#  $nb_processed = 0;
#  $percent_done = 0;

# FIXME : file with several techno will lead to percentage > 100 !!
  #PROGRESSION("--> $nb_file_total_resolved/$nb_file_total files have been directly resolved with extensions.\n");
  PROGRESSION("\nChecking content of file with recognized extensions.\n");
  SEND_EVENT("NB_TOTAL_FILE;$nb_file_total");
  SEND_GUI("STAGE;POTENTIAL;$nb_file_total;$nb_file_total_resolved;$nbPotential");
}

sub phase_checking_without_potential($) {
 my $nbUnknown = shift;
# init progression !
#  $nb_to_process = scalar @UnknowFilesTechnos;
#  $nb_processed = 0;
#  $percent_done = 0;

  #PROGRESSION("--> $nb_file_total_resolved/$nb_file_total have been resolved.\n");
  PROGRESSION("\nChecking content of ".(scalar @UnknowFilesTechnos)." files with unrecognized extensions.\n");
  SEND_GUI("STAGE;UNKNOWN;$nb_file_total;$nb_file_total_resolved;$nbUnknown");
}

sub phase_checking_with_context() {
  #PROGRESSION("--> $nb_file_total_resolved/$nb_file_total have been resolved.\n");
  PROGRESSION("\nChecking content of file using context.\n");
  SEND_GUI("STAGE;CONTEXT;$nb_file_total;$nb_file_total_resolved");
}

sub printResolvedStat() {
	PROGRESSION("--> $nb_file_total_resolved/$nb_file_total have been resolved.\n");
}

# statistic adjustment
sub phase_finalizing() {
  SEND_GUI("STAGE;END;$nb_file_total;$nb_file_total_resolved");
}

#--------------------------------------------------
#------------- ERROR MANAGEMENT ------------------
#--------------------------------------------------

my %H_ERRORS = ();

sub getErrors() {
  return \%H_ERRORS;
}

sub addFileError($$;$) {
  my $error = shift;
  my $file = shift;
  my $comment = shift;

  if (! defined $comment) {
    $comment = "";
  }

  $nb_file_error++;

  if (! exists $H_ERRORS{$error}) {
    $H_ERRORS{$error} = [];
  }

  push @{$H_ERRORS{$error}}, [$file, $comment];

  SEND_EVENT("ERROR;$error;".$file->[FILE_ID]);

  #FIXME : should make a SEND_GUI_FILE (but the GUI should take it into account) ...
}


#--------------------------------------------------
#------------- TECHNO MANAGEMENT ------------------
#--------------------------------------------------

my %H_technosStatus = ();

sub getTechnosStatus() {
  return \%H_technosStatus;
}

sub addTechnoFileError($$) {
  my $error = shift;
  my $file = shift;

  if (! exists $H_technosStatus{$error}) {
    $H_technosStatus{$error} = [ [], [] ];
  }

  push @{$H_technosStatus{$error}->[1]}, $file;
}

sub addTechnoFile($$) {
  my $techno = shift;
  my $file = shift;

  if (! exists $H_technosStatus{$techno}) {
    $H_technosStatus{$techno} = [ [], [] ];
  }

  push @{$H_technosStatus{$techno}->[1]}, $file;

}

sub addTechnoDir($$) {
  my $techno = shift;
  my $dir = shift;

  if (! exists $H_technosStatus{$techno}) {
    $H_technosStatus{$techno} = [ [], [] ];
  }
  else {
    push @{$H_technosStatus{$techno}->[0]}, $dir;
  }
}

#-------------------------------------------------------
#------------- FILE MANAGEMENT -------------------------
#-------------------------------------------------------

my %H_file = ();

sub referenceFileNode($$) {
  my $filename=shift;
  my $filenode=shift;

  $H_file{$filename} = $filenode;
}

sub createFileNode($) {
  my $file = shift;
  my %potentialTechnos = ();
  my %technos = ();
  my %excludedTechnos = ();
  my ($dir, $name) = $$file =~ /^(.*)[\\\/]+([^\\\/]+)/m;

  my ($ext) = $name =~ /\.([^\.]*$)/m;

  if (!defined $ext) {
    $ext = "";
  }

  canonizeDir(\$dir);

#  my $dirnode = $H_dir{$dir};
  my $dirnode = getDirNode($dir);

  if (!defined $dirnode) {
    OUTPUT "WARNING : no node for directory <$dir> when adding file $$file.\n";
  }

  return [$name, \%potentialTechnos, \%technos, $dirnode, $ext, undef, $nb_file_total, \%excludedTechnos];
}

sub newFile($$) {
  my $file = shift;
  my $filenode = shift;
  my $dirnode = $filenode->[FILE_DIR];
  my $name = $filenode->[FILE_NAME];
  $nb_file_total++;

  referenceFileNode($$file, $filenode);

  # reference the file in the dir node ...
  addDirFile($dirnode, $filenode);

  SEND_EVENT("NEW FILE;$nb_file_total;$name");
}

sub addFileTechno($$) {
  my $filenode = shift;
  my $techno = shift;

  $filenode->[FILE_POTENTIAL_TECHNOS]->{$techno} = 1;
  SEND_EVENT("POTENTIAL;".$filenode->[FILE_ID].";$techno");
  SEND_GUI_FILE($filenode, "");
}

sub removeFileTechno($$) {
  my $filenode = shift;
  my $techno = shift;

  delete $filenode->[FILE_POTENTIAL_TECHNOS]->{$techno};

  SEND_EVENT("NOT;".$filenode->[FILE_ID].";$techno");
  SEND_GUI_FILE($filenode, "");

  # If all potential technos are invalidated, print a warning ...
  if ( (scalar keys %{$filenode->[FILE_POTENTIAL_TECHNOS]} == 0) &&
       (scalar keys %{$filenode->[FILE_TECHNOS]} == 0) &&
       (scalar keys %{$filenode->[FILE_EXCLUDED_TECHNOS]} == 0) ) {
    OUTPUT "WARNING : all potential technos invalidated for :";
    my $dir = getFileDir($filenode);
    OUTPUT "$dir->[0]/$filenode->[0]. ";
    OUTPUT "File is classed with files with unknow technos\n";
    addUnknowFileTechno($filenode);

    # as the number of Unknow is increased, the number of file remaining to be
    # processed is increased too.
    incRemainingProgression();
  }
}

# Remove all potential techno.
sub clearFileTechnos($;$) {
	my $filenode = shift;
	my $sendGUI = shift;

	for my $tech (keys %{$filenode->[FILE_POTENTIAL_TECHNOS]}) {
		SEND_EVENT("NOT;".$filenode->[FILE_ID].";$tech");
	}

	$filenode->[FILE_POTENTIAL_TECHNOS] = {};

	if (! defined $sendGUI) {
		$sendGUI = 1;
	}

	if ($sendGUI) {
		SEND_GUI_FILE($filenode, "");
	}

	return undef;
}

sub setFileTechno($$;$) {
  my $filenode = shift;
  my $techno = shift;
  my $mode = shift;

  my $realTechno = technos::config::getRealTechno($techno);

  if ($TRACE == 1) {
    OUTPUT "SET TECHNO [$realTechno] to file $filenode->[0]";

    if (defined $mode) {
      OUTPUT " ($mode)\n";
      $filenode->[FILE_RESOLUTION_MODE] = $mode;
    }
    else {
      OUTPUT "\n";
      $filenode->[FILE_RESOLUTION_MODE] = "";
    }
  }

  # delete from potential techno list.
  delete $filenode->[FILE_POTENTIAL_TECHNOS]->{$techno};

  # Add the file to the list of files of the techno.
  addTechnoFile($realTechno, $filenode);

  # add the techno to the list of techno contained in the directory.
  my $dirnode = getFileDir($filenode);
  addDirTechno($dirnode, $realTechno);

  incResolvedProgression();

  if (technos::config::isOutOfContext([$techno])) {
		$filenode->[FILE_EXCLUDED_TECHNOS]->{$realTechno}=1;
		SEND_EVENT("OUT_OF_CONTEXT;".$filenode->[FILE_ID]);
		SEND_GUI_FILE($filenode, "EXCLUDED");
  }
  else {
		# add to techno list
		$filenode->[FILE_TECHNOS]->{$realTechno} = 1;
		SEND_EVENT("RESOLVED;".$filenode->[FILE_ID].";$realTechno");
		SEND_GUI_FILE($filenode, "");
  }
}

# Set the specified techno and clear all potential.
sub resolveFileTechno($$;$) {
	my $filenode = shift;
	my $techno = shift;
	my $mode = shift;

	clearFileTechnos($filenode, 0);
	setFileTechno($filenode, $techno, $mode);
}

sub setFileOutOfContext($) {
  my $filenode = shift;

  # Add the file to the list of files "out of context".
  #addOutOfContextFile($filenode);

  incResolvedProgression();
}

sub getFileDir($) {
  my $filenode = shift;
  return $filenode->[FILE_DIR];
}

sub getFilePath($) {
	my $filenode = shift;
	return $filenode->[FILE_DIR]->[DIR_NAME] . "/" . $filenode->[FILE_NAME]
}

sub getFilePotentialTechnos($) {
  my $filenode = shift;
  return $filenode->[FILE_POTENTIAL_TECHNOS];
}

sub getFileTechnos($) {
  my $filenode = shift;
  return $filenode->[FILE_TECHNOS];
}

sub getFileExcludedTechnos($) {
  my $filenode = shift;
  return $filenode->[FILE_EXCLUDED_TECHNOS];
}

sub isFilePotentialTechnosRemaining($) {
  my $filenode = shift;

  if (scalar keys %{$filenode->[FILE_POTENTIAL_TECHNOS]} > 0) {
    return 1
  }
  return 0;
}

sub resetFilePotentialTechnos($) {
  my $filenode = shift;
  my %emptyHash = ();

  $filenode->[FILE_POTENTIAL_TECHNOS] = \%emptyHash;
}


#-------------------------------------------------------
#------------- DIRECTORIES MANAGEMENT ------------------
#-------------------------------------------------------

my %H_dir=();

sub printTree($;$);

sub printTechnoStat($) {
  my $dir = shift;
  my $list = getDirTechnoStat($dir);

  for my $tech (@$list) {
    OUTPUT "$tech->[0]: $tech->[1]\%, ";
  }
}

sub printTree($;$) {
  my $node = shift;
  my $level = shift;
  if (! defined $level) {
    $level = 0;
  }

  my $name = $node->[0];
  $name =~ s/^.*\///;

  OUTPUT (" "x($level*3)); OUTPUT $name;
  my $technos = $node->[1];

  OUTPUT " ( ";
#  for my $techno (keys %$technos) {
#    OUTPUT $techno." ";
#  }
  printTechnoStat($node);
  OUTPUT " )\n";

  my $children = $node->[3];

  for my $child (@$children) {
    printTree($child, $level+1);
  }
}

sub addDirNode($$) {
  my $name = shift;
  my $node = shift;
#print "ADDING node for dir : <$name>\n";
  $H_dir{$name} = $node;
}

sub getDirNode($) {
  my $name = shift;
#print "GETTING node for dir <$name> !!\n";
  return $H_dir{$name};
}

sub addDirChild($$) {
  my $parent = shift;
  my $child = shift;

  push @{$parent->[3]}, $child;
}

sub newDir($$;$) {
  my $name = shift;
  my $relativeDir = shift;
  my $parent = shift;
  my @children = ();
  my %technos = ();
  my @files = ();

  canonizeDir(\$name);

  my $dir = [$name, \%technos, $parent, \@children, \@files, $relativeDir];

  if ( defined $parent ) {
    addDirChild($parent, $dir);
  }

  # Reference the directory node.
  addDirNode($name, $dir);

  SEND_EVENT("DIRECTORY;".$relativeDir);

  return $dir;
}

sub addDirTechno($$) {
  my $dirnode = shift;
  my $techno = shift;
  if (exists $dirnode->[1]->{$techno}) {
    $dirnode->[1]->{$techno}++;
  }
  else {
    $dirnode->[1]->{$techno} = 1;
  }

  # Add the directory to the list of dir of the techno.
  addTechnoDir($techno, $dirnode);
}

sub addDirFile($$) {
  my $dirnode = shift;
  my $file = shift;
#OUTPUT "--> ADD FILE : $file->[FILE_NAME]\n";
  push @{$dirnode->[4]}, $file;
}

sub getDirFiles($) {
  my $dirnode = shift;

  return $dirnode->[4];
}

sub getDirTechnos($) {
  my $dirnode = shift;

  return $dirnode->[1];
}

sub getDirTechnoStat($) {
  my $dirnode = shift;

  my @list = ();

  my $technos = getDirTechnos($dirnode);

  # Compute total number of technos resolved.
  # NOTE : can be greater than number of files because files can contain several
  #        technos ...
  my $total = 0;
  for my $tech (keys %$technos) {
    $total += $technos->{$tech};
  }

  # buid output list with percents ...
  if ($total > 0) {
    for my $tech (keys %$technos) {
      my $percent = int (($technos->{$tech} *100) / $total);
      push @list, [$tech, $percent];
    }
  }

  # sort in percent not growing.
  @list = sort {$b->[1] <=> $a->[1]} @list;

  return \@list;
}


#---------------------------------------
#------------- TIMING ------------------
#---------------------------------------

my @time_logs = ();
my $startTime = 0;

sub initTime() {
  $startTime = [gettimeofday];
  @time_logs = ();
}

sub tagTime($;$) {
  my $eventName = shift;
  my $trace = shift;

  my $time = [gettimeofday];

  push @time_logs, [$eventName, $time, $trace];
}

sub traceEvent($) {
  my $eventName = shift;
  tagTime($eventName, 1);
}

sub printTimeLog() {
  my $previous = $startTime;

  OUTPUT "\nEvents log :\n";
  OUTPUT "------------ :\n";
  for my $event (@time_logs) {
    if (defined $event->[2]) {
      my $elapsed = tv_interval($previous, $event->[1]);
      OUTPUT "   - $event->[0] : $elapsed seconds.\n";
    }
    $previous = $event->[1];
  }
}

#---------------------------------------
#------------- EXPORT ------------------
#---------------------------------------

my $CurrentTechno = "";
my $FD_TECH_FOUND = undef;
my $FD_TECH_OOC = undef;  # Out Of Context

sub get_FD_TECH_FOUND() {
	return $FD_TECH_FOUND;
}

sub get_FD_TECH_OOC() {
	return $FD_TECH_OOC;
}

sub openFileTechnoFound($$) {
	my $filename = shift;
	my $format = shift;

	my $ret = open my $fd, ">$filename";

	if (! $ret) {
		print "ERROR : Unable to generate file $filename.\n";
		return undef;
	}
	else {
		if ($format eq "csv") {
			print $fd "techno;File name; Directory;Extension;resolution mode\n";
		}
		return $fd;
	}
}

sub ExportStartTechnoFound($) {
	my $format = shift;

	if (($format eq "csv") || ($format eq "lst")) {
		$FD_TECH_FOUND = openFileTechnoFound("$OutputDir/technoFound.$format", $format);
		$FD_TECH_OOC = openFileTechnoFound("$OutputDir/technoOutOfContext.$format", $format);

		# need both "found" and "out of context" export files to activate export process
		if (defined $FD_TECH_FOUND && defined $FD_TECH_OOC) {
			# activate export process (activation is checkable with "defined $FD_TECH_FOUND" !!
			return;
		}
		else {
			close $FD_TECH_FOUND if defined $FD_TECH_FOUND;
			close $FD_TECH_OOC if defined $FD_TECH_OOC;
			$FD_TECH_FOUND = undef;
			$FD_TECH_OOC = undef;
		}
	}

	# format is not csv or lst, or output file(s) cannot have been openned : so write to output ...
	OUTPUT " * Technos found :\n";
	OUTPUT "   ---------------\n";
}

sub Export_TechnoFound_Techno($$) {
	my $format = shift;
	my $techno = shift;

	if (defined $FD_TECH_FOUND) {
		if ( ($format eq "csv") || ($format eq "lst") ) {
			$CurrentTechno = $techno;
			return;
		}
	}

	OUTPUT  "   $techno:\n";
}

sub Export_TechnoFound_File($$$) {
	my $format = shift;
	my $file = shift;
	my $FD = shift;

	if (defined $FD_TECH_FOUND) {
		if ($format eq "csv") {
			print $FD $CurrentTechno.";".
						$file->[FILE_NAME].";".
						$file->[FILE_DIR]->[5].";".
						$file->[FILE_EXTENSION].";".
						$file->[FILE_RESOLUTION_MODE].";\n";
		}
		elsif ($format eq "lst") {
			print $FD $baseSearchDir."/".$file->[FILE_DIR]->[5]."/".$file->[FILE_NAME]."\n";
		}

		return;
	}

  OUTPUT "    - ".$file->[FILE_DIR]->[5]."/".$file->[FILE_NAME]."\n";
}

sub ExportStopTechnoFound($) {
  my $format = shift;

  if ( (($format eq "csv") || ($format eq "lst")) && (defined $FD_TECH_FOUND)) {
    close $FD_TECH_FOUND;
    close $FD_TECH_OOC if defined $FD_TECH_OOC;
    $FD_TECH_FOUND = undef;
    $FD_TECH_OOC = undef;
  }
}

sub printUnknowOrPotentialFileTechno($$$$) {
  my $list = shift;
  my $title = shift;
  my $exportname = shift;
  my $format = shift;

  if ($format eq 'csv') {
    my $filename = "$OutputDir/$exportname.$format";
    my $ret = open FIC, ">$filename";
    if (! $ret) {
      print "Unable to generate file $filename\n";
    }
    else {
      # print columns names:
      print FIC "Directory;File;Extension;Technos\n";

      for my $file (@$list) {

        # print dir name :
        my $dir = getFileDir($file);

        if (defined $dir) {
          print FIC "$dir->[0]";
        }
        else {
          print FIC "???";
        }
        print FIC ";";

        # print file name :
        print FIC "$file->[FILE_NAME];";

        # print file name :
        print FIC $file->[FILE_EXTENSION].";";

        # print techno list
        my $technos = getFilePotentialTechnos($file);
        for my $techno (keys %$technos) {
          print FIC "$techno,";
        }
        print FIC "\n";
      }

      return;
    }
  }

  # DEFAULT FORMAT IS STDOUT
  OUTPUT $title;

  for my $file (@$list) {

    # print file name :
    OUTPUT "    - $file->[0] -- ";

    # print techno list
    my $technos = getFilePotentialTechnos($file);
    OUTPUT "[ ";
    for my $techno (keys %$technos) {
      OUTPUT "$techno ";
    }
    OUTPUT "]";

    # print dir name :
    my $dir = getFileDir($file);

    if (defined $dir) {
      OUTPUT "  [ $dir->[0] ]\n";
    }
    else {
      OUTPUT "  [ ??? ]\n";
    }
  }
}

sub remove_OOC_Technos_From_PotentialTechnos() {
	for my $file (@PotentialFilesTechnos) {

	my $technos = getFilePotentialTechnos($file);
	# build techno list, without out of context technos
	for my $techno (keys %$technos) {
		if (technos::config::isOutOfContext([$techno])) {
				delete $technos->{$techno};
			}
		}

		if (scalar keys %$technos == 0) {
			addUnknowFileTechno($file);
			$file = undef
		}
	}

	@PotentialFilesTechnos = grep defined, @PotentialFilesTechnos;
}

sub printPotentialFileTechno($) {
  my $format = shift;
  my $title = " * Potential techno for following files\n";
  $title   .= "   ------------------------------------\n";

  # potential technos should not be exported, so remove them.
  # After that, if there remain no potential techno in a file, it will be moved inside Unknow technos file list.
  remove_OOC_Technos_From_PotentialTechnos();

  printUnknowOrPotentialFileTechno(\@PotentialFilesTechnos, $title, "PotentialTechnos", $format);
}

sub printUnknowFileTechno($) {
  my $format = shift;
  my $title = " * Unknow techno for following files\n";
  $title   .= "   ---------------------------------\n";
  printUnknowOrPotentialFileTechno(\@UnknowFilesTechnos, $title, "UnknowTechno", $format);
}

sub export_Errors($) {
  my $format = shift;

  if ($format eq "csv") {
    my $exportname = "$OutputDir/detectionErrors.$format";
    my $ret = open FIC, ">$exportname";
    if (! $ret) {
      print "Unable to generate file $exportname\n";
      return;
    }
    # print columns names:
    print FIC "Directory;File;Error;comment\n";
    for my $error (keys %H_ERRORS) {
      my $list = $H_ERRORS{$error};
      for my $fileItem (@$list) {
        my $fileNode = $fileItem->[0];
	my $additionnalComment = $fileItem->[1];
        my $dir = getFileDir($fileItem->[0]);
        my $dirname = $dir->[0];
        if ( ! defined $dirname) {
          $dirname = "";
        }

        print FIC "$dirname;".$fileNode->[FILE_NAME].";$error;".$additionnalComment."\n";
      }
    }
    close  FIC;
  }
}

#---------------------------------------
#------------- HISTORY ------------------
#---------------------------------------

my %H_history = ();

sub loadHistory($) {
	my $dirnode = shift;

	my $baseDir = $dirnode->[DIR_NAME];
	my $historyFile = $baseDir."/.casthighlight";

	if (-f $historyFile) {
#		print "HISTORY FILE : $historyFile\n";

		open HISTO, "<$historyFile" or return;

		while (<HISTO>) {
			my $line=$_;
#			print $line."\n";
			if ($line =~ /^FILE;(\d+);(\"[^\"]\"|[^;]+)(?:;([\w:]+))?/) {
				my $id = $1;
				my $name = $2;
				my @technos=();
				if (defined $3) {
					@technos = split ":",$3;
				}
				$name =~ s/"//;

				my $fullname = $baseDir."/$name";
				#my ($r_relativeDir, $r_basename) = splitFilename(\$name);
				#my $fullDir = $baseDir ."/". $$r_relativeDir;

				canonizeDir(\$fullname);
				$H_history{$fullname} = [ \@technos ];
			}
		}
	}
}

sub getHistory($) {
	my $filenode = shift;
	my $fullname = $filenode->[FILE_DIR]->[DIR_NAME]."/".$filenode->[FILE_NAME];
	return $H_history{$fullname};
}

#---------------------------------------
#------------- BINARY LIBRARIES --------
#---------------------------------------

my $BinLibCsvDir = '.';

sub setBinaryLibCsvDir($) {
	$BinLibCsvDir = shift;
}

sub openBinaryLibCsv() {
	my $filename = "$OutputDir/BinaryLibraries.csv";
	my $ret = open BINLIB, ">$filename";

	PROGRESSION("Openning binary lib csv : $filename\n");

	if (! defined $ret) {
		print STDERR "WARNING : unable to open binary lib csv : $filename !!\n";
	}
	print BINLIB "#BinaryLibSha\n";
	print BINLIB "#version_highlight;".Lib::IsoscopeVersion::getHighlightVersion()."\n";
	print BINLIB "#start_date;".AnalyseOptions::get_date_as_amj_hm()."\n";
	print BINLIB "\n";
	print BINLIB "file;SHA256\n";
}

sub addBinaryLib($) {
	my $filenode = shift;

	# get content file.
	# (only means, do not export if any : this error reporting mechanisms
	#  are for files involved in the techno discovering process ... binary libs are not involved...)
	my $content = getFileContentOnly($filenode, ":raw");

	if (! technos::config::isBinary($content) ) {
		return 0;
	}

	# compute SHA
	my $dir = getFileDir($filenode);
	my $filepath = ($dir->[0])."/".($filenode->[0]);

	my $sha;
	if (defined $content) {
		$sha = Lib::SHA::SHA256($content);
	}
	else {
		$sha = "error";
	}

	print BINLIB "$filepath;$sha\n";

	return 1;
}

1;
