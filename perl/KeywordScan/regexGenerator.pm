package KeywordScan::regexGenerator;

use strict;
use warnings;

sub RegexGeneratorNew($) {
    my $hash_properties = shift;

    my $pattFileNameRegex;
    my $pattFileContentRegex;

    my $filename = $hash_properties->{'filename'}; # mandatory
    my $content = $hash_properties->{'content'} if (defined $hash_properties->{'content'});
    my $regexContent = $hash_properties->{'regexContent'} if (defined $hash_properties->{'regexContent'});

    # Filename using wildcards <*> replaced by <.*>
    $filename =~ s/(?<!\.)\*\./\.\*\\\./g;
    $filename =~ s/(?<!\.)\*/\.\*/g;
    # Step for escaping characters automatically
    $content = quotemeta($content) if (defined $content);

    if (defined $hash_properties->{'sensitive'} and $hash_properties->{'sensitive'} == 0) {
        $pattFileNameRegex = '(?i)';
        $pattFileContentRegex = '(?i)' if (defined $content || defined $regexContent);
    }

    if (defined $hash_properties->{'full_word'}
        and $hash_properties->{'full_word'} == 1) {
        # set full match
        $pattFileContentRegex .= "\\b$content\\b" if (defined $content);
    }
    else {
        # set partial match
        $pattFileContentRegex .= $content if (defined $content);
    }

    $pattFileContentRegex .= $regexContent if (defined $regexContent);
    # set full match for file name
    $pattFileNameRegex .= "\\b(?:$filename)\\b";

    if (defined $pattFileContentRegex) {
        return ($pattFileNameRegex, $pattFileContentRegex);
    }
    else {
        return ($pattFileNameRegex);
    }
}


sub RegexGenerator($$;$) {
    my $hash_properties = shift;
    my $filenameItem = shift;
    my $filecontentItem = shift;
    my $mod = "";
    my $pattRegex;
    my $pattFileContentRegex;

    for my $property (keys %{$hash_properties}) {
        if ($property eq 'sensitive' and $hash_properties->{$property} == 0) {
            # set insensitive
            $mod .= 'i';
        }
        elsif ($property eq 'full_word') {
            if ($hash_properties->{$property} == 1) {
                # set full match
                $pattRegex = "\\b$filenameItem\\b";
                $pattFileContentRegex = "\\b$filecontentItem\\b" if ($filecontentItem);
            }
            else {
                # set partial match
                $pattRegex = $filenameItem;
                $pattFileContentRegex = $filecontentItem if ($filecontentItem);
            }
        }
    }

    return ($mod, $pattRegex, $pattFileContentRegex);
}

1;