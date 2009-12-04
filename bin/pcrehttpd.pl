#!/usr/bin/perl

use strict;

use Sisyphus::Listener;
use Sisyphus::Proto::HTTP;
use AnyEvent::Strict;
use PCREHTTPD::PCREHTTPD;

BEGIN {
	if ($#ARGV < 1) {
		print "Usage: $0 PATH_TO_CONFFILE PATH_TO_KV_CONFFILE\n";
		exit;
	}
}

# import PCREConfig namespace
my $confPath = $ARGV[0];
require $confPath;

my $kv_conf = $ARGV[1];

# logging
my $applog = Sislog->new({use_syslog=>1, facility=>$PCREConfig::applog});
my $httplog = Sislog->new({use_syslog=>1, facility=>$PCREConfig::httplog});
$applog->open();
$httplog->open();

my $listener = new Sisyphus::Listener;

$listener->{port} = $PCREConfig::port;
$listener->{ip} = $PCREConfig::ip;
$listener->{protocol} = "Sisyphus::Proto::HTTP";
$listener->{application} = PCREHTTPD::PCREHTTPD->new(
	$PCREConfig::module,
	$PCREConfig::re,
	$httplog,
	$applog,
	undef,
	$kv_conf,
);
$listener->listen();

AnyEvent->condvar->recv;
