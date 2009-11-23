#!/usr/bin/perl
use strict;

# dump everything i know about a user

use lib ('/Users/joshua/projects/pcrehttpd/lib/');

# TODO add flags: -force (check for extant user before adding new one!)
if (scalar(@ARGV) < 2) {
	print "USAGE: $0 kvd_config_file username\n";
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
		print "sorry user ". $ARGV[1] ." unknown known m'bro\n";
		exit;
	}

	print Dumper $u;

	$cv->end;

});

$cv->recv;
