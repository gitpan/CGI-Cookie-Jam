use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'         => 'CGI::Cookie::Jam',
	'VERSION_FROM' => 'Jam.pm',
	'PREREQ_PM'    => {
		'Exporter' => '5.566',
	},
	($] >= 5.005 ? (
		'ABSTRACT' => 'Jam a large number of cookies to a small',
		'AUTHOR'   => 'Masanori HATA <lovewing@geocities.co.jp>',
	) : ()),
);
