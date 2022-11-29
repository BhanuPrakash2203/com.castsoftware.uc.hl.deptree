use strict;
use warnings;
use File::Basename;
use JSON;

my @expectedTechnolist = (
    'CCPP',
    'CLOJURE',
    'COBOL',
    'CSHARP',
    'JAVA',
    'JS',
    'KOTLIN',
    'PHP',
    'PYTHON',
    'SCALA',
    'SWIFT',
    'TSQL',
    'TYPESCRIPT',
    'VB'
);

my $jsonFileInput = '.\export_rule_doc.json';
my $jsonFileOutput = '..\..\..\..\..\Highlight\Highlight-Portal\src\main\resources\com\castsoftware\highlight\cloud\service\cloud_patterns_definition.json';
my $perl_json_filtered;
my %hash_log;
my %hash_warning_log;

local $/; # enable slurp
open my $fh, "<", $jsonFileInput or die $!;
my $json = <$fh>;
close $fh;

if (defined $json) {
    $perl_json_filtered = from_json($json);
    my $perl_json_origin = from_json($json);
    my $limit = scalar(@{$perl_json_origin});
    for (my $i = 0; $i < $limit; $i++) {
        # print "Analyzing rule $perl_json_origin->[$i]->{'title'}\n";
        if ($perl_json_origin->[$i]->{'scope'}) {
            my @scope = @{$perl_json_origin->[$i]->{'scope'}};
            my $limit_scope = scalar(@scope);
            my $ruleName= $perl_json_origin->[$i]->{'title'};
            my $flag_expected_techno = 0;
            for (my $j = 0; $j < $limit_scope; $j++) {
                my $technology = $perl_json_origin->[$i]->{'scope'}->[$j]->{'technology'}->{'code'};
                my $platform = $perl_json_origin->[$i]->{'scope'}->[$j]->{'platform'}->{'name'};
                if ($platform eq 'Agnostic') {
                    $platform = "";
                }
                else {
                    $platform = '[' . $platform . ']';
                }
                $flag_expected_techno = 0;
                for my $expectedTechno (@expectedTechnolist) {
                    if (defined $technology && $technology eq $expectedTechno) {
                        $flag_expected_techno = 1;
                        last;
                    }
                }
                if ($flag_expected_techno == 0) {
                    if ($limit_scope == 1) {
                        # techno is not expected in documentation and is the only one in the scope,
                        #  so we delete the complete rule
                        $hash_warning_log{"WARNING: Techno $technology not expected and is the only one techno this rule contains.\nWARNING: Rule $ruleName not exported\n"} = 1;
                        #print "WARNING: Techno $technology not expected and is the only one techno this rule contains.\nWARNING: Rule $ruleName not exported\n";
                        delete $perl_json_filtered->[$i];
                    }
                    else {
                        # techno is not expected in documentation, so we delete it in scope list
                        $hash_warning_log{"WARNING: Techno $technology not exported for rule '$ruleName' $platform\n"} = 1;
                        #print "WARNING: Techno $technology not exported for rule '$ruleName' $platform\n";
                        delete $perl_json_filtered->[$i]->{'scope'}->[$j];
                    }
                }
            }
            if ($flag_expected_techno == 1) {
                $hash_log{"INFO: Rule '$ruleName'... OK\n"} = 1;
            }
        }
        # sort scope elements by id
        if ($perl_json_filtered->[$i]->{'scope'}) {
            my $scope = $perl_json_filtered->[$i]->{'scope'};
            @$scope = sort { $a->{'technology'}->{'id'} <=> $b->{'technology'}->{'id'} } @$scope;
            my $json_scope = encode_json $scope;
            my $perl_json_scope = from_json($json_scope);
            # replace scope array elements by sorted elements
            $perl_json_filtered->[$i]->{'scope'} = $perl_json_scope;
        }
    }

    # last step to delete not defined ref array element
    @{$perl_json_filtered} = grep {defined $_} @{$perl_json_filtered};
}

# json output
if (defined $perl_json_filtered) {
    my $json_text_sorted = to_json($perl_json_filtered, { pretty => 1, canonical => 1 });
    open(FH, '>', $jsonFileOutput) or die $!;
    print FH $json_text_sorted;
    close FH;
}

# log output
open (OUTPUT, '>', 'C:\Users\JLE\Desktop\temp.txt') or die $!;
print OUTPUT "Analysis of " . $jsonFileInput . "\n";
print OUTPUT localtime."\n";
print OUTPUT "---\n";
if (%hash_warning_log) {
    foreach my $key (sort keys %hash_warning_log) {
        print OUTPUT $key;
    }
}
else {
    print OUTPUT "No WARNING\n"
}
print OUTPUT "---\n";
foreach my $key (sort keys %hash_log) {
    print OUTPUT $key;
}
print OUTPUT "---\n";
print OUTPUT "See output: $jsonFileOutput\n";
close OUTPUT;

system(exec 'notepad C:\Users\JLE\Desktop\temp.txt');
