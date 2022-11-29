# Composant: Plugin
# Module de creation des vues code et comment a partir de la vue text d'un
# source Cobol

package StripCobol;

use strict;
use warnings ;


# parser is working on text vue, we are adding code view & string extraction for diags
sub separer_code_chaines($$)
{
    my ($vues, $options) = @_;
    my $text = $vues->{'text'};
    my $code = \$vues->{'code'};

    my %HString;
    my $stringID;
    my $error = 0;

    while ($text =~ /([^\n]*)\n/g) {

        my $line = $1;

        if ($line =~ /^\d*\s*\*/m) {
            $$code .= "\n";
        }
        else {
            my $line_stringID;
            while ($line =~ /(["'].*?["'])/g) {
                # if value doesn't exists
                if (! grep {$_ eq $1} values %HString) {
                    $stringID++;
                    $HString{"CHAINE_".$stringID} = $1;
                }
                $line_stringID = $line;
                my $chaine_str = quotemeta ($HString{"CHAINE_".$stringID});
                $line_stringID =~ s/$chaine_str/CHAINE_$stringID/g;
            }
            if (defined $line_stringID) {
                $$code .= $line_stringID . "\n";
            }
            elsif  (defined $line) {
                $$code .= $line . "\n";
            }
            else {
                $error = 1;
            }
        }
    }

    if ($error == 0)
    {
        $vues->{'HString'} = \%HString;
    }
    return $error;
}


# analyse du fichier
sub StripCobol($$$$)
{
    my ($filename, $vues, $options, $couples) = @_;
    if (defined $options->{'--verbose'} )
    {
        print "working with  $filename \n";
    }
    return separer_code_chaines($vues, $options);
}


1;

