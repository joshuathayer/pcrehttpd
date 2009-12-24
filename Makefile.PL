use inc::Module::Install;

name         'pcrehttpd';
author       'Joshua Thayer <joshuamilesthayer@gmail.com>';
perl_version '5.005';
license      'perl';
all_from     'lib/PCREHTTPD/PCREHTTPD.pm';

build_requires 'Test::More';
requires	'Sisyphus'		=> '0.01';
requires	'File::ShareDir'	=> '1.01';

install_share;
auto_install;

WriteAll;

