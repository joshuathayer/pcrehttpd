use inc::Module::Install;

name     'pcrehttpd';
all_from 'lib/PCREHTTPD/PCREHTTPD.pm';
author   'Joshua Thayer <joshuamilesthayer@gmail.com>';

build_requires 'Test::More';
requires	'Sisyphus'		=> 0;
requires	'File::ShareDir'	=> '1.01';

license		'perl';
install_share;
auto_install;

WriteAll;

