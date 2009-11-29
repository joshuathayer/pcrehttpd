#!/usr/bin/perl

use strict;

use Sisyphus::Listener;
use Sisyphus::Proto::HTTP;
use AnyEvent::Strict;
use PCREHTTPD;

BEGIN {
	if ($#ARGV < 0) {
		print "Usage: $0 PATH_TO_CONFFILE\n";
		exit;
	}
}

# import PCREConfig namespace
my $confPath = $ARGV[0];
require $confPath;

# logging
my $applog = Sislog->new({use_syslog=>1, facility=>$PCREConfig::applog});
my $httplog = Sislog->new({use_syslog=>1, facility=>$PCREConfig::httplog});
$applog->open();
$httplog->open();

my $listener = new Sisyphus::Listener;

$listener->{port} = $PCREConfig::port;
$listener->{ip} = $PCREConfig::ip;
$listener->{protocol} = "Sisyphus::Proto::HTTP";
$listener->{application} = PCREHTTPD->new(
	$PCREConfig::module,
	$PCREConfig::re,
	$httplog,
	$applog,
);
$listener->listen();

AnyEvent->condvar->recv;
