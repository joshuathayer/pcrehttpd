use inc::Module::Install;

name     'pcrehttpd';
all_from 'lib/PCREHTTPD/PCREHTTPD.pm';
author   'Joshua Thayer <joshuamilesthayer@gmail.com>';

build_requires 'Test::More';
requires	'Sisyphus'		=> 0;

license		'perl';

auto_install;

WriteAll;

