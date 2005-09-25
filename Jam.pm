package CGI::Cookie::Jam;

use 5.008;
use strict;
use warnings;
use Carp;

our $VERSION = '0.02'; # 2005-09-25 (since 2003-04-09)

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    uri_encode uri_decode
    uri_escape uri_unescape
    datetime_cookie
);

=head1 NAME

CGI::Cookie::Jam - Jam a large number of cookies to a small.

=head1 SYNOPSIS

 use CGI::Cookie::Jam;
 
 my $jam = CGI::Cookie::Jam->new('cookie_jammed');
 
 my @cookie = $jam->enjam(
    name    => 'Masanori HATA'           ,
    mail    => 'lovewing@geocities.co.jp',
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
 
 my %param = CGI::Cookie::Jam::dejam($ENV{'HTTP_COOKIE'});

=head1 DESCRIPTION

This module provides jam-ming method about WWW cookie. Cookie is convenient but there are limitations on the number of cookies that a client can store at any one time: 

 300 total cookies
 4KB per cookie, where the NAME and the VALUE combine to form the 4KB limit.
 20 cookies per server or domain.

Especially, 20 cookies limitation could be a bottle neck. So this module try to jam some cookies to a cookie at maximum size of 4KB, that you can save the total number of cookies to a minimum number.

=head1 METHODS and FUNCTIONS

=over

=item new($cookie_name [, size => $byte])

Constructor class method. C<$cookie_name> will be coupled with numbering C<_XX> (XX: 00~99) and be used as the C<NAME> of C<NAME=VALUE> string in C<Set-Cookie:> HTTP header.

When you put C<size> attribute, the size of a cookie (that is the size of C<NAME=VALUE> string) will be less than C<$byte> Bytes. The default value of C<size> is 4096 Bytes (4KB). If you set 0 Byte, no size limitation will issue and only one cookie will be generated without filename numbering.

=cut

sub new {
    my($class, $name, %option) = @_;
    my $self = {};
    bless $self, $class;
    
    if ($name) {
        $$self{'name'} = $name;
    }
    else {
        croak "The 'name' attribute must not be omitted";
    }
    
    $$self{'size'} = '4096';
    foreach my $key (keys %option) {
        my $lowercase = $key;
        $lowercase =~ tr/A-Z/a-z/;
        unless ($lowercase eq 'size') {
            croak "Invalid attribute: $key";
        }
        $$self{$lowercase} = $option{$key};
    }
    
    return $self;
}

=item enjam( $name1 => $value1 [, $name2 => $value2, ...] )

This object-class method jams a lot number of multiple C<NAME=VALUE> strings for C<Set-Cookie:> HTTP header to a minimum number of C<NAME=VALUE> strings for C<Set-Cookie:> HTTP header. Then returns a list of multiple en-jam-med strings.

The en-jam-ming algorithm is realized by twice uri-escaping. At first, each cookie's C<NAME> and C<VALUE> pairs are uri-escaped and joined with C<=> (an equal mark). Then, multiple C<NAME=VALUE> pairs are joined with C<&> (an ampersand mark). This procedure is the very uri-encoding (see L<http://www.w3.org/TR/html4/interact/forms.html#h-17.13.4.1>).

Still a cookie has only one C<NAME=VALUE> pair, the uri-encoded string must be re-uri-escaped at the second procedure. As a result:

 '=' is converted to '%3D'
 '&' is converted to '%26'
 '%' is converted to '%25'

At last, this module uses the jam's C<$cookie_name> (which is, of course, uri-escaped, and coupled with a serial number like C<$cookie_name_XX>) as cookie C<NAME> and uses the twice uri_escaped string as cookie C<VALUE>, then join both with C<=> to make a C<NAME=VALUE> string. The final product is the very en-jam-med cookie.

When you use en-jam-med cookie, you may de-jam to reverse the above procedure:

 1: Extract VALUEs
    and join the splitted en-jam-med VALUE strings to a string.
 2: uri-unescape '%3D' to '=', '%26' to '&', '%25' to '%'.
 3: uri-decode the uri-encoded string to multiple NAME and VALUE pairs.

This module implements above the function as dejam() method except for the first procedure. Otherwise, you may implement dejam() function by client side using with JavaScript and so on.

=cut

sub enjam {
    my($self, @attr) = @_;
    if (@attr % 2 == 1) {
        croak 'odd: total number of the attributes should be even number';
    }
    
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
    
    my $name = uri_escape($$self{'name'});
    
    if ($$self{'size'}) {
        my $size = $$self{'size'} - length($name) - 4; # 4 = length("_00=")
        
        my @jam;
        while ($jam) {
            my $part;
            if ( length($jam) >= $size) {
                $part = substr($jam, 0, $size);
                $jam = substr($jam, $size);
            }
            else {
                $part = $jam;
                $jam = '';
            }
            push @jam, $part;
        }
        
        if ($#jam > 99) {
            croak "Too many amount of data to store for cookie. This module can handle upto 100 (en-jam-ed) cookies. (The Netscape's regulation is upto 30 cookies.)";
        }
        
        for (my $i = 0; $i <= $#jam; $i++ ) {
            my $serial = sprintf('%02d', $i);
            $jam[$i] = "${name}_$serial=$jam[$i]";
        }
        
        return @jam;
    }
    else {
        return "$name=$jam";
    }
}

=item dejam($cookie_string)

This function de-jams an en-jam-med cookie string. It returns C<NAME> and C<VALUE> pairs as a list. You could use those de-jam-med data to put into an hash.

Note that this method does not care multiple spanning en-jam-med cookies.

=back

=cut

sub dejam {
    my $cookie = shift;
    
    $cookie =~ s/^.*?=//;
    
    $cookie =~ s/%3D/=/g;
    $cookie =~ s/%26/&/g;
    $cookie =~ s/%25/%/g;
    
    return uri_decode($cookie);
}

sub uri_encode {
    my @attr = @_;
    if (@attr % 2 == 1) {
        croak 'odd: total number of the attributes should be even number';
    }
    
    my @pair;
    for (my $i = 0; $i < $#attr; $i += 2) {
        my($name, $value) = ($attr[$i], $attr[$i + 1]);
        $name  = uri_escape($name);
        $value = uri_escape($value);
        push @pair, "$name=$value";
    }
    
    return join('&', @pair);
}

sub uri_decode {
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

sub uri_escape {
    my $string = shift;
    my %escaped;
    foreach my $i (0 .. 255) {
        $escaped{chr($i)} = sprintf('%%%02X', $i);
    }
    # my $reserved = ';/?:@&=+$,[]'; # "[" and "]" have added in RFC2732
    # my $alphanum = '0-9A-Za-z';
    # my $mark = q/-_.!~*'()/;
    # my $unreserved = $alphanum . $mark;
    my $unreserved = q/0-9A-Za-z-_.!~*'()/;
    $string =~ s/([^$unreserved])/$escaped{$1}/og;
    return $string;
}

sub uri_unescape {
    my $string = shift;
    my %unescaped;
    foreach my $i (0 .. 255) {
        $unescaped{ sprintf('%02X', $i) } = chr($i); # for %HH
        $unescaped{ sprintf('%02x', $i) } = chr($i); # for %hh
    }
    $string =~ s/%([0-9A-Fa-f]{2})/$unescaped{$1}/g;
    return $string;
}

sub datetime_cookie {
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

=item RFC2965: L<http://www.ietf.org/rfc/rfc2965.txt> (Cookie)

=item HTML4.01: L<http://www.w3.org/TR/html4/interact/forms.html#h-17.13.4.1> (uri-encode)

=back

=head1 AUTHOR

Masanori HATA E<lt>lovewing@dream.big.or.jpE<gt> (Saitama, JAPAN)

=head1 COPYRIGHT

Copyright (c) 2003-2005 Masanori HATA. All rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

