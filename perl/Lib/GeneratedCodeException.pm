package Lib::GeneratedCodeException;

use strict;
use warnings;

# check only when the CLI option --allowGeneratedCode is not declared
sub checkGeneratedCodeFile($$) {
    my $arrayFiles = shift;
    my $techno = shift;
    my @arrayFilesOutput;
    my $regexFileName;

    if (defined $techno && lc($techno) eq 'cs') {
        $regexFileName = qr/\b(?:designer|reference|assemblyinfo)\.cs$/im;
    }
    elsif (defined $techno && lc($techno) eq "vbdotnet") {
        $regexFileName = qr/\b(?:designer|reference|assemblyinfo)\.vb$/im;
    }

    if (defined $regexFileName) {
        for my $file (@$arrayFiles) {
            if ($file =~ /$regexFileName/) {
                print STDERR "[Lib::GeneratedCodeException] File '$file' not analyzed because it contains generated code\n";
            }
            else {
                push (@arrayFilesOutput, $file);
            }
        }
    }
    else {
        return $arrayFiles;
    }

    return \@arrayFilesOutput;
}

1;