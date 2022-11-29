package CloudReady::lib::HardCodedIP;

use strict;
use warnings;
use CloudReady::lib::ElaborateLog;
use Lib::SHA;

sub checkHardCodedIP($$$$) {

    my $HString = shift;
    my $code = shift;
    pos($$code) = undef;
    my $techno = shift;
    my $text = shift;

    my $rulesDescription = CloudReady::lib::ElaborateLog::keepPortalData();

    my $nb_hardcoded_IP = 0;
    my $regexpr_ipv4;
    my $regexpr_ipv6;

    my $exceptionPatterns = undef;
    my $parameters = AnalyseUtil::recuperer_options();
    my $allowGeneratedCode = $parameters->[0]->{'--allowGeneratedCode'};
    if (defined $techno && $techno eq "CS") {
        # /!\ if --allowGeneratedCode option is defined we dont want add the exception pattern
        if (!defined $allowGeneratedCode) {
            push(@$exceptionPatterns, qr/\bGeneratedCode(?:Attribute)?\b/);
        }
        push(@$exceptionPatterns, qr/Version(?:Attribute)?\b/);
    }

    if (defined $techno && $techno eq "VB") {
        $regexpr_ipv4 = qr/^\[?([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\]?(?:\/[0-9]+)?$/m;
    }
    else {
        $regexpr_ipv4 = qr/^["']\[?([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\]?(?:\/[0-9]+)?["']$/m;
    }

    for my $stringId (keys %$HString) {

        ### IPv4
        if ($HString->{$stringId} =~ /$regexpr_ipv4/) {
            if (int($1) > 10 or int($2) > 10 or int($3) > 10) {
                $nb_hardcoded_IP = checkContextDetectionIP($code, $text, $exceptionPatterns, $HString, $stringId, $nb_hardcoded_IP, $rulesDescription);
            }
        }
        ### IPv6
        # RFC 4291 
        # IPv6 compress format
        elsif ($HString->{$stringId} =~ /\:\:/) {
            # IPV6 compressed with port
            # [2002:400:2A41:378::34A2:36]:8080
            if (defined $techno && $techno eq "VB") {
                $regexpr_ipv6 = qr/^\[?(?:[0-9a-f]{1,4}\:\:?){1,6}[0-9a-f]{1,4}\]?(?:\:[0-9]+)?$/im;
            }
            else {
                $regexpr_ipv6 = qr/^["']\[?(?:[0-9a-f]{1,4}\:\:?){1,6}[0-9a-f]{1,4}\]?(?:\:[0-9]+)?["']/im;
            }
            if ($HString->{$stringId} =~ /$regexpr_ipv6/) {
                $nb_hardcoded_IP = checkContextDetectionIP($code, $text, $exceptionPatterns, $HString, $stringId, $nb_hardcoded_IP, $rulesDescription);
            }
        }
        # IPv6 classic format
        else {
            my $IPv6 = $HString->{$stringId};
            # check presence of IPv4 embedded in IPv6
            if ($IPv6 =~ /\[?([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\]?(?:\/[0-9]+)?["']$/m) {
                if (int($1) > 10 or int($2) > 10 or int($3) > 10) {
                    # print 'IPv6 detected with IPv4 embedded: ' . $HString->{$stringId} . "\n";
                    # Replacing IPv4 embedded by the pattern 0:0
                    $IPv6 =~ s/([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})(?:\/[0-9]+)?["']$/0\:0\'/m;
                }
            }
            if (defined $techno && $techno eq "VB") {
                $regexpr_ipv6 = qr/^\[?(?:[0-9a-f]{1,4}\:){7,7}[0-9a-f]{1,4}\]?/im;
            }
            else {
                $regexpr_ipv6 = qr/^["']\[?(?:[0-9a-f]{1,4}\:){7,7}[0-9a-f]{1,4}\]?["']/im;
            }
            if ($IPv6 =~ /$regexpr_ipv6/) {
                $nb_hardcoded_IP = checkContextDetectionIP($code, $text, $exceptionPatterns, $HString, $stringId, $nb_hardcoded_IP, $rulesDescription);
            }
        }
    }

    return $nb_hardcoded_IP;
}

sub checkContextDetectionIP ($$$$$$$) {
    my $code = shift;
    my $text = shift;
    my $exceptionPatterns = shift;
    my $HString = shift;
    my $stringId = shift;
    my $nb_hardcoded_IP = shift;
    my $rulesDescription = shift;

    my $string = quotemeta($HString->{$stringId});
    # remove quotes due to search from XML tag values
    $string =~ s/^\\["']//m;
    $string =~ s/\\["']$//m;
    my $regex = qr/$string/;
    while ($$code =~ /^(.*)\b$stringId\b/mg) {
        if (defined $1) {
            my $previousPattern = $1;
            my $result = checkExceptionsIP($previousPattern, $exceptionPatterns, $stringId);
            if ($result == 0) {
                # to avoid duplicates counter must be computed in parallel of ElaborateLogPartOne
                $nb_hardcoded_IP++;
                CloudReady::lib::ElaborateLog::ElaborateLogPartOne($text, $regex, CloudReady::Ident::Alias_HardCodedIP, $rulesDescription);
                # print 'IP detected: ' . $HString->{$stringId} . "\n";
            }
        }
    }
    return $nb_hardcoded_IP;
}


sub checkExceptionsIP($$$) {
    my $previousPattern = shift;
    my $exceptionPatterns = shift;
    my $stringId = shift;

    foreach my $exceptionPattern (@$exceptionPatterns) {
        if ($previousPattern =~ /$exceptionPattern/m) {
            return 1;
        }
    }

    return 0;
}

1;
