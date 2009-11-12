package PCREHTTPD;

# this is a Sisyphus Application.
# An HTTPD where url->method routing is taken care of by a config file
# that is simply a regular expression, which maps URLs to methods

use strict;
use base 'Sisyphus::Application';

use Data::Dumper;
use IO::AIO;
use AnyEvent::AIO;
use Fcntl;
use Sislog;

use Time::HiRes;

my $responses;


sub new {
	my $class = shift;

	my $mod = shift;
	my $re = shift;
	my $httplog = shift;
	my $applog = shift;
	my $appargs = shift;	# a ref to pass to the app at instantiation

	my $self = { };

	# "routing" regex
	$self->{re} = $re;
	# module that has runnable functions
	$self->{mod} = $mod;
	require $mod. ".pm";

	$self->{httplog} = $httplog;
	$self->{applog} = $applog;

	$self->{applog}->log("internal", "PCREHTTPD starting up");

	$self->{appinstance} = $mod->new($appargs);

	bless($self, $class);

	return($self);
}

sub new_connection {
	my $self = shift;
}

sub remote_closed {
	my ($self, $host, $port, $fh) = @_;
	delete $responses->{$fh};
}

sub message {
	my ($self, $host, $port, $dat, $fh) = @_;

	my $req = $dat->[0];

    # $req is an AE::HTTPD::Request instance
    # Request class has methods for talking to the AE loop
    # but we'll do it by hand here to demonstrate the use of Sisyphus
    my $meth = $req->method();
    my $url= $req->url;
    my $params = $req->vars();
    my $headers = $req->headers();

	my $f;
	foreach my $r (@{$self->{re}}) {
		if ($url->as_string() =~ /$r->[0]/) {
			$f = $r->[1];
			last;
		}
	}
	unless ($f) {
			my $cont = "404 notfound bro";
			$self->{httplog}->log($fh, "$host $meth " .
			    $url->as_string() . " -> ?? 404 " . length($cont));
			$responses->{$fh} =
				[404, "NOT_FOUND", {"Content-type" => "text/html",}, $cont];
			$self->{client_callback}->([$fh]);	
	} else {

		my $m = $self->{mod} . "::" . $f;
		print "f is $f\n";

		if (defined &{$m}) {
			my ($code, $str, $headers, $cont);
			eval {
				# indirectly call the proper method on the pcre app's class
				# see http://docstore.mik.ua/orelly/perl/cookbook/ch13_08.htm
				# and http://perldoc.perl.org/strict.html
				$self->{appinstance}->$f($meth, $url, $params, $headers, sub {

					# callback from our app to the user
					($code, $str, $headers, $cont) = @_;	
					$responses->{$fh} = [$code, $str, $headers, $cont];
					$self->{client_callback}->([$fh]);	

				}, sub {
					# logging callback for our app
					my $dat = shift;
					$self->{applog}->log($fh, $dat);
				});
			};

			if ($! or $@) {
				# error. death.
				my $errm = $!;
				undef $!; undef $@;
				$cont = "Alas. It seems as though we found a server error.";
				$responses->{$fh} =
					[500, "ERROR", {"Content-type" => "text/html",}, $cont];
				$self->{httplog}->log($fh, "$host $meth " .
				    $url->as_string() . " -> $m 500 " . length($cont));
				$self->{client_callback}->([$fh]);	
			} else {
				# woo. a message from our application	
				$self->{httplog}->log($fh, "$host $meth " .
				     $url->as_string() . " -> $m $code " . length($cont));
			}

		} else {
			my $cont = "404 notfound bro";
			$self->{httplog}->log($fh, "$host $meth " .
			    $url->as_string() . " -> ??? 404 " . length($cont));
			$responses->{$fh} =
				[404, "NOT_FOUND", {"Content-type" => "text/html",}, $cont];
			$self->{client_callback}->([$fh]);	
		}

		return undef;
	}
}

sub get_data {
	my ($self, $fh) = @_;

	unless ($responses->{$fh}) { return; }
	my $v = $responses->{$fh};
	$responses->{$fh} = undef;
	return $v;
}

1;
