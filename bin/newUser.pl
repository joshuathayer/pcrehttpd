#!/usr/bin/perl
use strict;

# create a new pcrehttp user
# makes one (1) active user with password authentication and zero grants

# TODO add flags: -force (check for extant user before adding new one!)
if (scalar(@ARGV) < 3) {
	print "USAGE: $0 kvd_config_file username password\n";
	exit;
}

use PCREHTTPD::PCREUser; 
use Mykeyv::MyKVClient;
use PCREHTTPD::PasswordAuth;
use Data::Dumper;
use AnyEvent;

require $ARGV[0];

my $kvc = Mykeyv::MyKVClient->new({
	cluster => $Config::cluster,
	pending_cluster => $Config::pending_cluster,
	cluster_state => $Config::cluster_state,
});

$PCREHTTPD::PCREUser::kvc = $kvc;

my $u = PCREHTTPD::PCREUser->new;

$u->setToken($ARGV[1]);

my $a = PCREHTTPD::PasswordAuth->new();
$a->setToken($ARGV[1]);
$a->setPassword($ARGV[2]);

$u->setAuthentication($a);
my $cv = AnyEvent->condvar;
$u->store(sub { $cv->send; });
$cv->recv;

print Dumper $u;
print "User $u->{token} added thanks.\n";
