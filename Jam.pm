package CGI::Cookie::Jam;

use 5.008;
use strict;
use warnings;
use Carp;

our $VERSION = '0.08'; # 2005-11-05 (since 2003-04-09)

require Exporter;
our @ISA = 'Exporter';
our @EXPORT = qw(
    enjam dejam
    encryptjam decryptjam
);
our @EXPORT_OK = qw(
    rotate
    uri_encode uri_decode
    uri_escape uri_unescape
    datetime_cookie
);

=head1 NAME

CGI::Cookie::Jam - Jam a large number of cookies to a small one.

=head1 SYNOPSIS

 use CGI::Cookie::Jam;
 
 my %param1(
     name    => 'Masanori HATA'           ,
     mail    => 'lovewing@dream.big.or.jp',
     sex     => 'male'                    ,
     birth   => '2003-04-09'              ,
     nation  => 'Japan'                   ,
     pref    => 'Saitama'                 ,
     city    => 'Kawaguchi'               ,
     tel     => '+81-48-2XX-XXXX'         ,
     fax     => '+81-48-2XX-XXXX'         ,
     job     => 'student'                 ,
     role    => 'president'               ,
     hobby   => 'exaggeration'            ,
     );
 my @cookie = enjam('jam', '4096', %param1);
 
 my %param2 = dejam($ENV{'HTTP_COOKIE'});

=head1 DESCRIPTION

This module provides jamming mean to WWW cookie. Cookie is convenient but there are some limitations on number of cookies that a client can store at a time: 

 300 total cookies
 4KB per cookie, where the NAME and the VALUE combine to form the 4KB limit.
 20 cookies per server or domain.

Especially, 20 cookies limitation could be a bottle neck. So this module try to jam some cookies (which holds single pair of the NAME and the VALUE) to a cookie at maximum size of 4KB, that you can save total number of cookies to a minimum one.

=head1 FUNCTIONS

=over

=item enjam($cookie_name, $maximum_size, %param)

This function jams a lot number of multiple C<NAME=VALUE> strings for C<Set-Cookie:> HTTP header to a minimum number of C<NAME=VALUE> strings for C<Set-Cookie:> HTTP header. It returns a list of multiple enjammed strings.

The enjamming algorithm is realized by twice uri-escaping. At first, each cookie's C<NAME> and C<VALUE> pairs are uri-escaped and joined with C<=> (an equal mark). Then, multiple C<NAME=VALUE> pairs are joined with C<&> (an ampersand mark). This procedure is very the uri-encoding (see L<http://www.w3.org/TR/html4/interact/forms.html#h-17.13.4.1>).

Still a cookie has only one C<NAME=VALUE> pair, the uri-encoded string must be re-uri-escaped at the second procedure. As a result:

 '=' is converted to '%3D'
 '&' is converted to '%26'
 '%' is converted to '%25'

At last, this module uses the jam's C<$cookie_name> (which is, of course, uri-escaped, and coupled with a serial number like C<$cookie_name_XX>) as cookie C<NAME> and uses the twice uri_escaped string as cookie C<VALUE>, then join both with C<=> to make a C<NAME=VALUE> string. The final product is very the enjammed multi-spanning cookies.

With C<size> attribute you can specify the size (bytes) of a cookie (that is the size of C<NAME=VALUE> string). Generally, to set C<4096> bytes (4KB) is recommended. If you set C<0> byte, no size limitation will work and only one cookie will be generated without filename numbering (C<_XX>).

When you use enjammed cookies, you may dejam to reverse the above procedure:

 1: Extract VALUEs
    and join the splitted enjammed VALUE strings to a string.
 2: uri-unescape '%3D' to '=', '%26' to '&', '%25' to '%'.
 3: uri-decode the uri-encoded string to multiple NAME and VALUE pairs.

This module implements above the function as dejam() method except for the first procedure. Otherwise, you may implement dejam() function by client side using with JavaScript and so on.

=cut

sub enjam ($$%) {
    my($cookie_name, $size, @attr) = @_;
    
    $cookie_name = uri_escape($cookie_name);
    
    my @pair;
    for (my $i = 0; $i < $#attr; $i += 2) {
        my($name, $value) = ($attr[$i], $attr[$i + 1]);
        $name  = uri_escape($name );
        $value = uri_escape($value);
        $name  =~ s/%/%25/g;
        $value =~ s/%/%25/g;
        push @pair, "$name%3D$value";
    }
    my $jam = join('%26', @pair);
    
    if ($size) {
        return _jam_cutter($cookie_name, $jam, $size);
    }
    else {
        return "$cookie_name=$jam";
    }
}

sub _jam_cutter {
    my($cookie_name, $jam, $size) = @_;
    
    my $limit = $size - length($cookie_name) - 4; # 4 = length("_00=")
    
    my @jam;
    while ($jam) {
        my $part;
        if ( length($jam) >= $limit) {
            $part = substr($jam, 0, $limit);
            $jam = substr($jam, $limit);
        }
        else {
            $part = $jam;
            $jam = '';
        }
        push @jam, $part;
    }
    
    if ($#jam > 99) {
        croak "Too many amount of data to store for cookie. This module can handle upto 100 (enjamed) cookies. (The Netscape's regulation is upto 30 cookies.)";
    }
    
    for (my $i = 0; $i <= $#jam; $i++ ) {
        my $serial = sprintf('%02d', $i);
        $jam[$i] = $cookie_name . "_$serial=$jam[$i]";
    }
    
    return @jam;
}

=item dejam($jam_string)

This function dejams an enjammed cookie string. It returns C<NAME> and C<VALUE> pairs as a list. You may use those dejammed data to put into an hash.

Note that this method does not care multi-spanning enjammed cookies.

=cut

sub dejam ($) {
    my $jam = shift;
    
    $jam =~ s/^.*?=//;
    
    $jam =~ s/%3D/=/g;
    $jam =~ s/%26/&/g;
    $jam =~ s/%25/%/g;
    
    return uri_decode($jam);
}

=item encryptjam($cookie_name, $maximum_size, $magic_number, %param)

=item decryptjam($cryptjam_string, $magic_number)

These functions are used to handle an encrypted/decrypted cookie jam. Magic number will be used as a seed of encrypting. To decrypt an encrypted jam, you must use the same magic number for the string.

These are alternatives for enjam() and dejam() functions.

=back

=cut

sub encryptjam ($$$%) {
    my($cookie_name, $size, $magic, @attr) = @_;
    $magic = _magic_normalize($magic);
    
    $cookie_name = uri_escape($cookie_name);
    
    my @pair;
    for (my $i = 0; $i < $#attr; $i += 2) {
        my($name, $value) = ($attr[$i], $attr[$i + 1]);
        $name  = uri_escape($name );
        $value = uri_escape($value);
        push @pair, "$name=$value";
    }
    my $jam = join('&', @pair);
    
    my $cryptjam = rotate($jam, $magic);
    $cryptjam = uri_escape($cryptjam);
    
    if ($size) {
        return _jam_cutter($cookie_name, $cryptjam, $size);
    }
    else {
        return "$cookie_name=$cryptjam";
    }
}

sub decryptjam ($$) {
    my($cryptjam, $magic) = @_;
    $magic = _magic_normalize($magic);
    
    $cryptjam =~ s/^.*?=//;
    $cryptjam = uri_unescape($cryptjam);
    
    my $jam = rotate($cryptjam, 7 - $magic);
    
    return uri_decode($jam);
}

sub _magic_normalize {
    my $magic = shift;
    my $mode = int($magic) % 7;
    
    if ($mode == 0) {
        $mode = (int($magic) / 7) % 7;
        if ($mode == 0) {
            $mode = 1;
        }
    }
    
    return $mode;
}

sub rotate ($$) {
    my($str, $magic) = @_;
    
    my @str;
    while ($str) {
        my $char = chop($str);
        $char = unpack('B*', $char); # binary code
        $char = substr($char, 1, 7); # 8bit -> 7bit
        
        # rotate to the left
        my $left  = substr($char, $magic, 7 - $magic);
        my $right = substr($char, 0, $magic);
        $char = $left . $right;
        
        $char = '0' . $char; # 7bit -> 8bit
        $char = pack('B*', $char); # ascii code
        
        unshift @str, $char;
    }
    
    return join '', @str;
}

sub uri_encode (@) {
    my @attr = @_;
    
    my @pair;
    for (my $i = 0; $i < $#attr; $i += 2) {
        my($name, $value) = ($attr[$i], $attr[$i + 1]);
        $name  = uri_escape($name);
        $value = uri_escape($value);
        push @pair, "$name=$value";
    }
    
    return join('&', @pair);
}

sub uri_decode ($) {
    my $encoded = shift;
    
    my @string = split('&', $encoded);
    my @decoded;
    foreach my $string (@string) {
        $string =~ tr/+/ /;
        my($name, $value) = split('=', $string);
        $name  = uri_unescape($name );
        $value = uri_unescape($value);
        push(@decoded, $name, $value);
    }
    
    return @decoded;
}

sub uri_escape ($) {
    utf8::encode(my $string = shift);
    
    # build conversion map
    my %hexhex;
    for (my $i = 0; $i <= 255; $i++) {
        $hexhex{chr($i)} = sprintf('%02X', $i);
    }
    
    # my $Reserved = ';/?:@&=+$,[]'; # "[" and "]" have been added in the RFC 2732
    # my $Alphanum = '0-9A-Za-z';
    # my $Mark = q/-_.!~*'()/;
    # my $Unreserved = $Alphanum . $Mark;
    my $Unreserved = q/0-9A-Za-z\-_.!~*'()/;
    
    $string =~ s/([^$Unreserved])/%$hexhex{$1}/og;
    
    return $string;
}

sub uri_unescape ($) {
    my $string = shift;
    
    # build conversion map
    my %unescaped;
    for (my $i = 0; $i <= 255; $i++) {
        $unescaped{ sprintf('%02X', $i) } = chr($i); # for %HH
        $unescaped{ sprintf('%02x', $i) } = chr($i); # for %hh
    }
    
    $string =~ s/%([0-9A-Fa-f]{2})/$unescaped{$1}/g;
    
    utf8::decode($string);
    return $string;
}

sub datetime_cookie ($) {
    my $time  = shift;
    my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        gmtime($time);
    $year += 1900;
    $mon  = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$mon];
    $wday = qw(Sun Mon Tue Wed Thu Fri Sat)[$wday];
    foreach my $digit ($mday, $hour, $min, $sec) {
        $digit = sprintf('%02d', $digit);
    }
    return "$wday, $mday-$mon-$year $hour:$min:$sec GMT";
}

########################################################################
1;
__END__

=head1 SEE ALSO

=over

=item Netscape: L<http://wp.netscape.com/newsref/std/cookie_spec.html> (Cookie)

=item RFC 2965: L<http://www.ietf.org/rfc/rfc2965.txt> (Cookie)

=item HTML 4: L<http://www.w3.org/TR/html4/interact/forms.html#h-17.13.4.1> (uri-encode)

=back

=head1 AUTHOR

Masanori HATA E<lt>lovewing@dream.big.or.jpE<gt> (Saitama, JAPAN)

=head1 COPYRIGHT

Copyright (c) 2003-2005 Masanori HATA. All rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

