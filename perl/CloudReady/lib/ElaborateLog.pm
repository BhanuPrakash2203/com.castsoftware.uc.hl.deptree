package CloudReady::lib::ElaborateLog;

use strict;
use warnings;
use File::Basename;
use File::Spec;

use AnalyseUtil;


my %SCAN_LOG = ();
my $DEBUG = 0;

#my $techno = getTechno();
my $techno;

# Agent GUI is not using the --language option
# techno name is retrieved from GetCurrentAnaName() in Analyse.pl
sub init($) {
	my $options = shift;
	
	$techno = $options->{'--language'};
}

# option --dbgMatchPatternDetail is activated if user want export log files

sub ElaborateLogPartOne ($$$$) {
    my $view = shift;
    my $regex = shift;
    my $mnemoID = shift;
    my $rulesDescription = shift;

    if (!defined $view || !defined $mnemoID) {
        print STDERR "[ElaborateLogPartOne] Error missing view or mnemo!!!\n";
    }

    my $parameters = AnalyseUtil::recuperer_options();
    my $dbgMatchPatternDetail = $parameters->[0]->{'--dbgMatchPatternDetail'};

	my $savepos;

   if (defined $dbgMatchPatternDetail) {
       my $SHA = getSHA();
       # /!\ avoid the following issue:
       # "strings with code points over 0xFF may not be mapped into in-memory file handles"
       #    search & replace non ascii characters (may be encountered in comments)
       $savepos = pos($$view);
       $$view =~ s/[^[:ascii:]]/ /g;

       open my $handle, '<', $view;
       while (<$handle>) {
           if (/$regex/) {
               my $numline = $.;
               my $res = isCommentLine($techno, $numline);
               if ($res == 0) {
                   # $-[0] position before matching
                   # $+[0] position after matching
                   my $previousPos = $-[0];
                   my $lastpos = $+[0];
                   # export only mnemonics with label (blockers)
                   my $technoLabelInPortal = getTechnoLabelInPortal($techno);

                   if (exists $rulesDescription->{$mnemoID}->{$technoLabelInPortal}) {
                       foreach my $ruleName (keys %{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}}) {
                           # avoid duplicates
                           if (exists $SCAN_LOG{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[0]}{$SHA}[0]) {
                               if ($SCAN_LOG{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[0]}{$SHA}[0] !~ /$numline\[$previousPos,$lastpos]\|/) {
                                   $SCAN_LOG{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[0]}{$SHA}[0] .= "$numline\[$previousPos,$lastpos]\|";
                               }
                           }
                           else {
                               $SCAN_LOG{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[0]}{$SHA}[0] = "$numline\[$previousPos,$lastpos]\|";
                           }
                           # urldoc
                           $SCAN_LOG{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[0]}{$SHA}[1] = $rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[1];
                           # blockerMultiPatternFormula
                           if ($rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[2]) {
                               $SCAN_LOG{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[0]}{$SHA}[2] = $rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[2];
                               # avoid duplicates
                               if (exists $SCAN_LOG{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[0]}{$SHA}[3]) {
                                   if ($SCAN_LOG{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[0]}{$SHA}[3] !~ /$mnemoID\|/) {
                                       $SCAN_LOG{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[0]}{$SHA}[3] .= $mnemoID . "\|";
                                   }
                               }
                               else {
                                   $SCAN_LOG{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleName}->[0]}{$SHA}[3] = $mnemoID . "\|";
                               }
                           }
                       }
                   }
                   # else {
                   #     $SCAN_LOG{$mnemoID}{$SHA}[0] .= "$numline\[$previousPos,$lastpos]\|";
                   #     $SCAN_LOG{$mnemoID}{$SHA}[1] = $rulesDescription->{$mnemoID}->{$techno}->[1];
                   # }
               }
           }
       }
       close $handle;
   }

    # TODO: improve test
    # if ($DEBUG) {
    #     my $nb_detect_logged = 0;
    #     open my $handle, '<', $view;
    #     while (<$handle>) {
    #         if (/$regex/) {
    #             $nb_detect_logged++;
    #         }
    #     }
    #     my $nb_detect_no_logged = () = ($$view =~ /$regex/gm);
    #     if ($nb_detect_logged != $nb_detect_no_logged) {
    #         print STDERR "TO CHECK: [$mnemoID] regex <$regex> => nb detect log =$nb_detect_logged\/$nb_detect_no_logged\n";
    #         sleep(5);
    #     }
    # }
   

   my $nb_patterns = () = ($$view =~ /$regex/gm);
   pos($$view) = $savepos;
   return $nb_patterns;
}

sub ElaborateLogPartTwo ($$$) {
    my $code = shift;
    my $text = shift;
    my $file = shift;

    my $SHA = getSHA();
    # check formula for blockers multi pattern
    foreach my $alert (keys %SCAN_LOG) {
        if (exists $SCAN_LOG{$alert}{$SHA} && $SCAN_LOG{$alert}{$SHA}[3]) {
            my @split_values = split(/\|/, $SCAN_LOG{$alert}{$SHA}[3]);
            foreach my $val (@split_values) {
                $SCAN_LOG{$alert}{$SHA}[2] =~ s/\b$val\b/1/g;
            }
            $SCAN_LOG{$alert}{$SHA}[2] =~ s/Id_[0-9]+/0/g;
            $SCAN_LOG{$alert}{$SHA}[2] =~ s/\&\&/\*/g;
            $SCAN_LOG{$alert}{$SHA}[2] =~ s/\|\|/\+/g;
            # if formula is not valid => delete data
            if (!eval $SCAN_LOG{$alert}{$SHA}[2]) {
                delete $SCAN_LOG{$alert}{$SHA};
            }
        }
    }

    # replace SHA
    foreach my $alert (keys %SCAN_LOG) {
        if (exists $SCAN_LOG{$alert}{$SHA}) {
            my $filename = basename($file);
            $SCAN_LOG{$alert}{$filename}{$file} = delete $SCAN_LOG{$alert}{$SHA};
        }
    }
}

sub SimpleElaborateLog ($$$$$) {
    my $code = shift;
    my $numline = shift;
    my $mnemoID = shift;
    my $rulesDescription = shift;
    my $ruleNamePortal = shift;

    my $parameters = AnalyseUtil::recuperer_options();
    my $dbgMatchPatternDetail = $parameters->[0]->{'--dbgMatchPatternDetail'};

    if (defined $dbgMatchPatternDetail) {
        my $SHA = getSHA();
        my $technoLabelInPortal = getTechnoLabelInPortal($techno);

        if (exists $rulesDescription->{$mnemoID}->{$technoLabelInPortal}) {
            $SCAN_LOG{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleNamePortal}->[0]}{$SHA}[0] .= "$numline\[\-\]\|";
            $SCAN_LOG{$rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleNamePortal}->[0]}{$SHA}[1] = $rulesDescription->{$mnemoID}->{$technoLabelInPortal}->{$ruleNamePortal}->[1];
        }
    }
}

sub getScanLog {
    return \%SCAN_LOG;
}

#sub deleteScanLog {
#	%SCAN_LOG = undef;
#}

# RulesDescription.csv is generated by executing java class
# .\Highlight\Highlight-Engine\src\test\java\com\castsoftware\highlight\azur\CloudLabelFileGenerator.java
sub keepPortalData {
    my %rulesDescription;
    my $dirname = dirname(__FILE__);
    open my $handle_csv, '<', File::Spec->catfile($dirname, 'RulesDescription.csv');

    # [0] techno
    # [1] rule name (portal)
    # [2] alert label
    # [3] url doc
    # [4] ID mnemo
    # [5] mnemo
    # [6] blockerMultiPattern

    while (my $line = <$handle_csv>) {
        my @lines = split(/;/, $line);
        $rulesDescription{$lines[4]}{$lines[0]}{$lines[1]}[0] = $lines[2];
        $rulesDescription{$lines[4]}{$lines[0]}{$lines[1]}[1] = $lines[3];
        if ($lines[6] ne "\n") {
            $lines[6] =~ s/\n$//m;
            $rulesDescription{$lines[4]}{$lines[0]}{$lines[1]}[2] = $lines[6];
        }
    }
    close $handle_csv;

    return \%rulesDescription;
}

# sub getTechno(;$) {
#
# 	# try to retrieve the techno from the $option structure, updated for CLI & Agent context
# 	my $CLI_and_GUI_options = shift;
# 	$techno = $$CLI_and_GUI_options{'--language'};
#
# 	if (! defined $techno) {
#
# 		# no techno supplied, so try to retrieve from the perl ARGV.
# 		# BUT, unfortunately, will not work because the Agent GUI is not using the --language option
#
# 		my $parameters = AnalyseUtil::recuperer_options();
# 		my $techno = $parameters->[0]->{'--language'};
# 	}
#
# 	# list of technos we want export to vscode extension
# 	# supported technos : C#, VB.Net, Java, JS, Typescript, Clojure
# 	#if (defined $techno) {
# 	#	if (lc($techno) eq 'cs') {$techno = 'CSHARP'}
# 	#	elsif (lc($techno) eq 'vbdotnet') {$techno = 'VB'}
# 	#	else {
# 	#		$techno = uc($techno);
# 	#	}
# 	#}
#
#     return $techno;
# }

sub isCommentLine($$) {
    my $techno = shift;
    my $lineWanted = shift;
    my $success = 1;
    my $libSource;
    my $regex = qr/(?<!P)C/;

    if ($techno eq 'CS' || $techno eq 'VbDotNet') {
        $libSource = CloudReady::CountDotnet::getAggloView();
    }
    elsif ($techno eq 'Java') {
        $libSource = CloudReady::CountJava::getAggloView();
    }
    elsif ($techno eq 'JS' || $techno eq 'TypeScript') {
        $libSource = CloudReady::CountNodeJS::getAggloView();
    }
    elsif ($techno eq 'Clojure') {
        $libSource = CloudReady::CountClojure::getAggloView();
    }
    elsif ($techno eq 'CCpp') {
        $libSource = CloudReady::CountCCpp::getAggloView();
    }
    elsif ($techno eq 'Scala') {
        $libSource = CloudReady::CountScala::getAggloView();
    }
    else {
        print STDERR "ERROR: Unknown techno name '$techno': please redefined it with case sensitive in the CLI\n";
        $success = 0;
    }

    if ($success == 0) {
        return 1;
    }
    else {
        # get agglo view (could be comment view if agglo not exists) for current file
        # for agglo : P is a code line & C is a comment line
        my $view = $libSource;
        # /!\ avoid the following issue:
        # "strings with code points over 0xFF may not be mapped into in-memory file handles"
        #    search & replace non ascii characters (may be encountered in comments)
        $$view =~ s/[^[:ascii:]]/ /g;
        open my $fh, '<', $view;
        while (<$fh>) {
            if ($. == $lineWanted) {
                # my $match = $_;
                if ($_ =~ /$regex/) {
                    return 1;
                }
            }
        }
        return 0;
    }
}

sub getSHA() {
    my $success = 1;
    my $binaryView;
    # get binary view
    if ($techno eq 'CS' || $techno eq 'VbDotNet') {
        $binaryView = CloudReady::CountDotnet::getBinaryView();
    }
    elsif ($techno eq 'Java') {
        $binaryView = CloudReady::CountJava::getBinaryView();
    }
    elsif ($techno eq 'JS' || $techno eq 'TypeScript') {
        $binaryView = CloudReady::CountNodeJS::getBinaryView();
    }
    elsif ($techno eq 'Clojure') {
        $binaryView = CloudReady::CountClojure::getBinaryView();
    }
    elsif ($techno eq 'CCpp') {
        $binaryView = CloudReady::CountCCpp::getBinaryView();
    }
    elsif ($techno eq 'Scala') {
        $binaryView = CloudReady::CountScala::getBinaryView();
    }
    else {
        $success = 0;
    }
    if ($success == 1) {
        return Lib::SHA::SHA256($binaryView);
    }
    return 0;
}

sub getTechnoLabelInPortal($) {
    my $techno = shift;

    my $technoLabelInPortal = uc($techno);
    # techno name changes between CLI and portal
    if ($technoLabelInPortal eq 'CS') {
        $technoLabelInPortal = 'CSHARP'
    }
    elsif ($technoLabelInPortal eq 'VBDOTNET') {
        $technoLabelInPortal = 'VB'
    }
    return $technoLabelInPortal;
}

1;
