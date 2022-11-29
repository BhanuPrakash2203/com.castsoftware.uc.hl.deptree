package KeywordScan::projectFiles;

use strict;
use warnings;

use KeywordScan::detection;
use KeywordScan::Count;
use KeywordScan::regexGenerator;
use Encode;

my $APPLI_DATA = ();
my $DEBUG = 0;

my @file_idx = ();

# keyword scan detection for project files (text view)
# scan also source code files (text view) of the selected techno in the CLI
# /!\ only for patternGroup xml version (scope search is not already supported)
sub detect($) {
    my $file = shift;
    print $file . "\n" if ($DEBUG);
    my $H_DETECTORS = KeywordScan::detection::getKeywordDetectors();

    my $file_idx;

    if ($file =~ /(.*[\\\/])?([^\\\/]+)$/) {
        # my $path = $1||"";
        my $basename = $2;

        if ($basename =~ /(.+)\.([^\.]*)$/) {
            my $nameFile = $1;
            my $ext = $2;

            for my $detectorName (keys %{$H_DETECTORS}) {
                my $detector = $H_DETECTORS->{$detectorName};

                for my $keyword (@{$detector->{T_KEYWORDS_DESCRIPTION}}) {
                    my $keywordGroup = $keyword->[0];
                    my $data = $keyword->[1];
                    if (keys %{$data->{'searchItem'}} > 0) {
                        for my $id (keys %{$data->{'searchItem'}}) {
                            # CREATE NEW ENTRY FOR CSV
                            $APPLI_DATA = KeywordScan::detection::addAppliDetection($detectorName, $id);

                            my $searchItem;
                            for my $searchItem (@{$data->{'searchItem'}->{$id}}) {
                                my ($pattFileNameRegex, $pattFileContentRegex) = KeywordScan::regexGenerator::RegexGeneratorNew($searchItem);
                                if (defined $pattFileNameRegex and $basename =~ /$pattFileNameRegex/) {
                                    if (!defined $pattFileContentRegex) {
                                        $file_idx = KeywordScan::detection::setCurrentFileNew($detectorName, $file);
                                        $detector->addFileDetectionNew($file_idx, $keywordGroup, $id, "1");
                                        push(@file_idx, $file_idx);
                                        $APPLI_DATA = KeywordScan::detection::addAppliDetection($detectorName, $id);
                                    }
                                    else {
                                        # For managing file encodings and accent characters in pattern regex
                                        my $encodings = [ 'latin1', 'UTF-8' ];
                                        my $buffer;
                                        local $/ = undef;
                                        open(FILE, "<", $file);
                                        $buffer = <FILE>;
                                        close FILE;
                                        for my $encoding (@$encodings) {
                                            $pattFileContentRegex = encode($encoding, $pattFileContentRegex);
                                            if ($buffer and $pattFileContentRegex and $buffer =~ /$pattFileContentRegex/) {
                                                $file_idx = KeywordScan::detection::setCurrentFileNew($detectorName, $file);
                                                $detector->addFileDetectionNew($file_idx, $keywordGroup, $id, "1");
                                                push(@file_idx, $file_idx);
                                                $APPLI_DATA = KeywordScan::detection::addAppliDetection($detectorName, $id);
                                                last;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

sub postAnalysisDetection() {
    my $file_idx = KeywordScan::Count::get_file_idx();
    if (defined $file_idx) {
        push(@file_idx, @{$file_idx});
    }
    KeywordScan::Count::applyFormula(\@file_idx);
}

1;
