package Lib::Data;

use strict;
use warnings;

sub hexdump_String($)
{
    my $str = shift;
    my $flag = Encode::is_utf8($str) ? 'UTF8_flag_ON ' : "UTF8_flag_OFF";
    use bytes; # this tells unpack to deal with raw bytes
    my @internal_rep_bytes = unpack('C*', $str);
    return
        $flag
        . ' ('
        . join(' ', map { sprintf("%02x", $_) } @internal_rep_bytes)
        . ')';
}

1;
