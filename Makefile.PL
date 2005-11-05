use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'CGI::Cookie::Jam',
    'VERSION_FROM' => 'Jam.pm',
    'PREREQ_PM'    => {
        'CGI::Uricode' => '0.05',
    },
    ($] >= 5.005 ? (
        'ABSTRACT' => 'Jam a large number of cookies to a small one',
        'AUTHOR'   => 'Masanori HATA <http://go.to/hata>',
        ) : ()),
);
