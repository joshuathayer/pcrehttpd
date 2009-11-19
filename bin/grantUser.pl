#!/usr/bin/perl
use strict;

# create a new pcrehttp user
# makes one (1) active user with password authentication and zero grants

use lib ('/Users/joshua/projects/pcrehttpd/lib/');

# TODO add flags: -force (check for extant user before adding new one!)
if (scalar(@ARGV) < 4) {
	print "USAGE: $0 kvd_config_file username application grant [value]\n";
	exit;
}

use PCREUser; 
use MyKVClient;
use PasswordAuth;
use Data::Dumper;
use AnyEvent;

require $ARGV[0];

my $kvc = MyKVClient->new({
	cluster => $Config::cluster,
	pending_cluster => $Config::pending_cluster,
	cluster_state => $Config::cluster_state,
});

$PCREUser::kvc = $kvc;

my $cv = AnyEvent->condvar;
$cv->begin;
my $u = PCREUser->new($ARGV[1], sub {
	my $u = shift; 

	unless ($u) {
		print "sorry user ". $ARGV[1] ." known m'bro\n";
		exit;
	}

	$u->grant($ARGV[2], $ARGV[3], $ARGV[4]);

	$cv->begin;
	$u->store(sub { 
		print "user " . $ARGV[1] . " granted " .  $ARGV[3] . " on " . $ARGV[2] . "\n";
		$cv->end;
	});

	$cv->end;

});

$cv->recv;
