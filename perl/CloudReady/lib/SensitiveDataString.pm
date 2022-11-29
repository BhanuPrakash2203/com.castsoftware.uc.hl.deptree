package CloudReady::lib::SensitiveDataString;

use strict;
use warnings;

my $THRESHOLD_ENTROPY = 4.5;
my $MIN_TOKEN = 20;

# HL-1751 17/06/21 Detect passwords, security strings and other secret keys
sub CountSensitiveDataString($$$) {
    my $code = shift;
    my $HString = shift;
    my $techno = shift;
    my $rulesDescription = CloudReady::lib::ElaborateLog::keepPortalData();

    my $nb_SensitiveDataString = 0;
    my $PKCertificateDeclaration = 0;
    my $boolPKCertificate = 0;
    my $regex_code = qr /(\n)|((?:(\w+)\s+\=\s*)?(CHAINE_[0-9]+))/;

    my %HString_no_empty_string = %{$HString};
    # purge $HString locally
    foreach my $strID (keys %HString_no_empty_string) {
        if ($HString_no_empty_string{$strID} eq "" || $HString_no_empty_string{$strID} =~ /^["']["']$/m) {
            delete $HString_no_empty_string{$strID};
        }
    }

    # VbDotNet techno
    if (defined $techno && $techno eq "VB") {
        $regex_code = qr /(\n)|((?:(\w+)\s+(?:As\s+\w+\s+)?\=\s*)?\"(ch[0-9]+)\")/;
    }
    my $numline = 1;
    my $numlineBeginPrivateKey;
    while ($$code =~ /$regex_code/g) {
        my $match = $2;
        my $varName = $3;
        my $stringID = $4;
        
        # line counter
        if (defined $1 && $1 ne '') {
            $numline++;
        }
        elsif (defined $match) {

            # line counter
            while ($match =~ /\n/g) {$numline++;}

            if (exists $HString_no_empty_string{$stringID} && $HString_no_empty_string{$stringID} =~ /\bBEGIN\s+(?:RSA|DSA|EC)?\s*\b(?:PRIVATE\s+KEY|CERTIFICATE)\b/) {
                $PKCertificateDeclaration = 1;
                $numlineBeginPrivateKey = $numline;

                if ($HString_no_empty_string{$stringID} =~ /\bBEGIN\s+(?:RSA|DSA|EC)?\s*\b(?:PRIVATE\s+KEY|CERTIFICATE)\b[\s\-]*(.*)[\s\-]*\bEND\s+(?:RSA|DSA|EC)?\s*\b(?:PRIVATE\s+KEY|CERTIFICATE)\b/s) {
                    # check private key is not empty
                    if (defined $1 && $1 =~ /\S/) {
                        # print "[Sensitive data string] Private key/certificate used at line $numlineBeginPrivateKey\n";
                        $nb_SensitiveDataString++;
                        # my $regexLabel = '\bBEGIN\s+(?:RSA|DSA|EC)?\s*\b(?:PRIVATE\s+KEY|CERTIFICATE)\b[\s\-]*(.*)[\s\-]*\bEND\s+(?:RSA|DSA|EC)?\s*\b(?:PRIVATE\s+KEY|CERTIFICATE)\b';
                        CloudReady::lib::ElaborateLog::SimpleElaborateLog($code, $numlineBeginPrivateKey, CloudReady::Ident::Alias_SensitiveDataString, $rulesDescription, "Use_Unsecured_Data_Strings");
                    }
                    $PKCertificateDeclaration = 0;
                }
                else {
                    next;
                }
            }
            #################
            ## PRIVATE KEY ##
            #################
            if ($PKCertificateDeclaration == 1) {
                if (exists $HString_no_empty_string{$stringID} && $HString_no_empty_string{$stringID} =~ /\bEND\s+(?:RSA|DSA|EC)?\s*\b(?:PRIVATE\s+KEY|CERTIFICATE)\b/) {
                    if ($PKCertificateDeclaration == 1 && $boolPKCertificate ==1) {
                        # print "[Sensitive data string] Private key/certificate used at line $numlineBeginPrivateKey\n";
                        $nb_SensitiveDataString++;
                        # my $regexLabel = '\bEND\s+(?:RSA|DSA|EC)?\s*\b(?:PRIVATE\s+KEY|CERTIFICATE)\b';
                        CloudReady::lib::ElaborateLog::SimpleElaborateLog($code, $numlineBeginPrivateKey, CloudReady::Ident::Alias_SensitiveDataString, $rulesDescription, "Use_Unsecured_Data_Strings");
                    }

                    $boolPKCertificate = 0;
                    $PKCertificateDeclaration = 0;
                }
                # detect string inside private key
                elsif ($PKCertificateDeclaration == 1 && $boolPKCertificate == 0) {
                    if (exists $HString_no_empty_string{$stringID} && $HString_no_empty_string{$stringID} =~ /\S/) {
                        $boolPKCertificate = 1;
                    }
                    # string is not really a private key declaration
                    else {
                        $boolPKCertificate = 0;
                        $PKCertificateDeclaration = 0;
                    }
                }
            }
            ######################################
            ## VAR NAME & HOT KEYWORDS & TOKENS ##
            ######################################
            else {
                # var name
                if (defined $varName && $varName =~ /\b(?:password|pwd|user(?:name)?|uid|auth|db|database|account)\b/i) {
                    # filter on null value
                    if (exists $HString_no_empty_string{$stringID} && $HString_no_empty_string{$stringID} !~ /\"\s*\"/) {
                        # print "[Sensitive data string] Var name '$varName' used at line $numline\n";
                        $nb_SensitiveDataString++;
                        # my $regexLabel = '\b(?:password|pwd|user(?:name)?|uid|auth|db|database|account)\b';
                        CloudReady::lib::ElaborateLog::SimpleElaborateLog($code, $numline, CloudReady::Ident::Alias_SensitiveDataString, $rulesDescription, "Use_Unsecured_Data_Strings");
                    }
                }
                # hot keywords
                elsif (exists $HString_no_empty_string{$stringID} && $HString_no_empty_string{$stringID} =~ /\b(?:password|pwd|user(?:name)?|uid|auth|db|database|account)\b\s*\=\s*\\?["']+([^\\"]+)\\?["']+/i) {
                    # count detection if identifier value is not null
                    my $match = $1;
                    if ($match =~ /\S/) {
                        # print "[Sensitive data string] Sensitive keyword '$HString_no_empty_string{$stringID}' used at line $numline\n";
                        $nb_SensitiveDataString++;
                        # my $regexLabel = '\b(?:password|pwd|user(?:name)?|uid|auth|db|database|account)\b\s*[=:](?:\s|\n)*[\"\'](.+?)[\"\']';
                        CloudReady::lib::ElaborateLog::SimpleElaborateLog($code, $numline,  CloudReady::Ident::Alias_SensitiveDataString, $rulesDescription, "Use_Unsecured_Data_Strings");
                    }
                }
                # RFC-7519
                # Token = base64Header + '.' + base64Payload + '.' + signature
                # signature = HS256(base64Header + '.' + base64Payload, �secret�)
                # signature is optional
                # website https://jwt.io/
                # JWT header always begin by eyJ as a result of encoding part <{ "alg":> of json
                # JWT, for some exception of algo kinds, payload part not begins by eyJ
                elsif (exists $HString_no_empty_string{$stringID} && $HString_no_empty_string{$stringID} =~ /^["']?(?:(eyJ[\w\-_=]+\.[\w\-_=]+(?:\.[\w\-_=]+)?))["']?$/m) {
                    my $match = $1;
                    if (length($match) >= $MIN_TOKEN && $match =~ /^\S+$/m && $match =~ /[A-Z]+/i
                        && $match =~ /[0-9]+/) {
                        my $entropy = entropy(split //, $match);
                        if ($entropy > $THRESHOLD_ENTROPY) {
                            # print "[Sensitive data string] Token used at line $numline\n";
                            $nb_SensitiveDataString++;
                            # my $regexLabel =  '^["\']?(?:(eyJ[\w\-_=]+\.[\w\-_=]+(?:\.[\w\-_=]+)?))["\']?$';
                            CloudReady::lib::ElaborateLog::SimpleElaborateLog($code, $numline, CloudReady::Ident::Alias_SensitiveDataString, $rulesDescription, "Use_Unsecured_Data_Strings");
                        }
                    }
                }
            }
        }
    }

    return $nb_SensitiveDataString;
}

# https://rosettacode.org/wiki/Entropy#Perl
sub entropy {
    my %count; $count{$_}++ for @_;
    my $entropy = 0;
    for (values %count) {
        my $p = $_/@_;
        $entropy -= $p * log $p;
    }
    return $entropy / log 2;
}

1;