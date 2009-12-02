package PCREHTTPD;

# this is a Sisyphus Application.
# An HTTPD where url->method routing is taken care of by a config file
# that is simply a regular expression, which maps URLs to methods

use strict;
use base 'Sisyphus::Application';

use Data::Dumper;
use AnyEvent;
use URI;
use Fcntl;
use Sislog;
use MyKVClient;
use PCREHTTPD::PCREUser;
use PCREAdminApp;

use Time::HiRes;
use constant INTERNAL_SESSION_TIMEOUT_SEC => 60*60*24;

my $responses;

my $kv_config = "./kvcluster.conf";
require $kv_config;

sub new {
	my $class = shift;

	my $mod = shift;
	my $re = shift;
	my $httplog = shift;
	my $applog = shift;
	my $appargs = shift;	# a ref to pass to the app at instantiation

	my $self = { };

	# connection to db cluster
	$self->{kvc} = MyKVClient->new({
		cluster => $Config::cluster,
		pending_cluster => $Config::pending_cluster,
		cluster_state => $Config::cluster_state,
	});

	$PCREHTTPD::PCREUser::kvc = $self->{kvc};

	# "routing" regex
	$self->{re} = $re;
	# module that has runnable functions
	$self->{mod} = $mod;
	require $mod. ".pm";

	$self->{httplog} = $httplog;
	$self->{applog} = $applog;

	$self->{applog}->log("internal", "PCREHTTPD starting up");

	$self->{appinstance} = $mod->new($appargs);
	$self->{space} = ['A'..'Z','a'..'z',0..9];

	# session class, and session container class, should be their own things
	$self->{sessions} = {};

	# instantiate admin app 
	$self->{adminappinstance} = PCREAdminApp->new();

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
	my $url= $req->url(); # this won't have GET params
	my %params = $req->vars();
	my $headers = $req->headers();
	# AE::HTTPD::Request does not seem to have a method to retrieve GET params
	# so we will do that here. lame... TODO submit patch?
	# this sucks because it bypasses the Request object's accessor to get to the
	# url data
	my $gurl = URI->new( $req->{url} );
	my %p = $gurl->query_form();
	foreach my $k (keys(%p)) {
		$params{$k} = $p{$k};
	}

	# server-internal sessioning
	# cookie parsing. please put this in its own lib
	#print "client -> server\n";
	#print Dumper $headers;
	my $cookies;
	if ($headers->{cookie}) {
		my @f = split(/;\s*/, $headers->{cookie});
		foreach my $i (@f) {
			# using Cookie (not Cookie2), we just get the key->val 
			my ($k, $v) = $i =~ /(.*)\s*=\s*"*(.*?)"*$/;
			$cookies->{$k} = $v;
		}
	}

	my $sessionID = $cookies->{PCRESESSION};
	#print "sessionID $sessionID\n";

	my $f;

	# internal admin page, first
	print "url ".$url->as_string()."\n";
	if ($url->as_string() =~ /^\/pcre_admin\/?(.*)/) {
		if ($1 =~ /static.*/) {
			$f = "pcre_admin_static";
		} else {
			$f = "pcre_admin";
		}
		print "f $f\n";
	} else {
		foreach my $r (@{$self->{re}}) {
			if ($url->as_string() =~ /$r->[0]/) {
				$f = $r->[1];
				last;
			}
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
		my ($m, $instance);
		if ($f =~ "pcre_admin") {
			print "ADMIN $f\n";
			$m = "PCREAdminApp::$f";
			$instance = $self->{adminappinstance};
		} else {
			$m = $self->{mod} . "::" . $f;
			$instance = $self->{appinstance};
		}
		
		if (defined &{$m}) {
			# ok, it's a valid request. we only bother with sessions
			# at this point
			my $session = $self->getSession($sessionID);

			my $setCookie = 0;
			unless(length($session->{_pcre_session_id})) {
				$setCookie = 1;
				$sessionID = $self->generateSessionID();
				$session->{_pcre_session_id} = $sessionID;
				$session->{_created} = time;
			} 

			# create the request context..
			my $context = {
				method => $meth,
				url => $url,
				params => \%params,
				headers => $headers,
				cookies => $cookies,
				pcre_session => $session,
				server => $self,
			};

			my ($code,$str,$headers,$cont);

			eval {
				$context->{_pcrehttpd_cb} = sub {
					# callback from our app to the user
					# here we massage what we're going to send back to the user,
					# fix up our session, etc
					($code, $str, $headers, $cont) = @_;
					$session->{_last_seen} = time;
					$session->{_expire} = time + INTERNAL_SESSION_TIMEOUT_SEC;
					$self->setSession($session);
					# set a cookie...
					if ($setCookie) {
						# create a session id...
						#print "creating session id\n";
						$headers->{'Set-Cookie'} = "PCRESESSION=\"$sessionID\";";
					}

					$responses->{$fh} = [$code, $str, $headers, $cont];
					$self->{client_callback}->([$fh]);	
				};

				$context->{_pcrehttpd_app_log} = sub {
					# logging callback for our app
					my $dat = shift;
					$self->{applog}->log($fh, $dat);
				};

				# actually make the call
				# indirectly call the proper method on the pcre app's class
				# see http://docstore.mik.ua/orelly/perl/cookbook/ch13_08.htm
				# and http://perldoc.perl.org/strict.html
				$instance->$f($context);
			};

			if ($! or $@) {
				# error. death.
				my $errm = "$! - $@";
				undef $!; undef $@;
				$cont = "Alas. It seems as though we found a server error.";
				$responses->{$fh} =
					[500, "ERROR", {"Content-type" => "text/html",}, $cont];
				$self->{httplog}->log($fh, "$host $meth " .
				    $url->as_string() . " -> $m 500 " . length($cont) . " $errm");
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

sub pcre_admin {
	my ($self, $context, $cb, $logging) = @_;

	my $sessionID = $context->{pcre_session}->{_pcre_session_id};
	my $user = $context->{pcre_session}->{_pcre_user};

	my $cont = "<html><head><title>pcrehttpd admin</title></head>";
	$cont .= "<body><br />";

	unless ($user) {
		# no user. we need the "who are you" dialog
		$self->pcre_admin_no_user($context, $cb, $logging, $cont);
		return;
	}

	# we re-get user just in case
	$self->getUser($context->{pcre_session}->{_pcre_user}, sub {
		my $user = shift;

		my $action = $context->{params}->{action};

		if ($action eq "logout") {
			$context->{pcre_session}->{_pcre_user} = undef;
			$cb->(301, "redirected", {"Location"=> "/pcre_admin",}, "You're logged out. Go <a href=\"/pcre_admin\">home</a>");
			return;
		}

		my $message;
		# suck in params

		my $newUser = $context->{params}->{newUserName};
		my $newPass = $context->{params}->{newUserPassword};
		
		# this should be a sub.
		if ($newUser && $newPass) {
			my $u = PCREHTTPD::PCREUser->new;
			$u->setToken($newUser);
			$a = PasswordAuth->new;
			$a->setToken($newUser);
			$a->setPassword($newPass);
			$u->setAuthentication($a);

			$u->store(sub {
				$context->{params}->{newUserName} = undef;
				$context->{params}->{newUserPassword} = undef;
				$context->{actionResults} .= "New user $newUser created.<br/>";
				$self->pcre_admin($context, $cb, $logging);
				return;
			});
		};

		my $message = $context->{actionResults};

		$cont .= "<h3>pcrehttpd admin</h3>";
		$cont .= "$message\n";
		$cont .= "<p>user: $user->{username} <a href='/pcre_admin?action=logout'>logout</a>";
		$cont .= '<form method="post" action="/pcre_admin">';
		$cont .= "<hr><h4>add user</h4>";
		$cont .= 'new user name <input name="newUserName"><br />new user password <input name="newUserPassword"><br />';
		$cont .= '<input type="submit"></form>';
		$cont .= "</body></html>";
		$cb->(200, "OK", {"Content-type"=> "text/html",}, $cont);
	});

}

sub pcre_admin_no_user {
	my ($self, $context, $cb, $logging, $cont) = @_;

	my $action = $context->{params}->{action};
	my $username = $context->{params}->{username};
	my $password= $context->{params}->{pass};

	if ($username) {
		PCREHTTPD::PCREUser->new($username, sub {
			my $u = shift;
			# need a more general-case authentication checking scheme.
			# it's insane to write this code here.
			if (($u->{authentication}->{PasswordAuth}->{password} eq $password)
			    and ($u->{grants}->{pcrehttpd}->{admin}))	{
				# haha logged in
				$context->{pcre_session}->{_pcre_user} = $u;
				$self->setSession($context->{pcre_session});
				$cb->(301, "redirected", {"Location"=> "/pcre_admin",}, "You're logged in. Go <a href=\"/pcre_admin\">home</a>");
			} else {
				# recursively call this- it'll give a login screen
				print "password is not $password or no credentials\n";
				$context->{params}->{action} = undef;
				$context->{params}->{username} = undef;
				$context->{params}->{pass} = undef;
				$self->pcre_admin_no_user($context, $cb, $logging, $cont);
			}
		});
		return;
	}
	
	$cont .= "you have no user. you must log in.<br/>";
	$cont .= '<form method="post" action="/pcre_admin">username <input name="username"><br/>pass <input name="pass">';
	$cont .= '<br /><input type="submit">';
	$cb->(200, "OK", {"Content-type"=> "text/html",}, $cont);

	return $cont;
}

sub getUser {
	my ($self, $u, $cb) = @_;
	PCREHTTPD::PCREUser->new($u->{token}, $cb);
}

sub setUser {
	my ($self, $user, $cb) = @_;
	print "setUser!\n";
	#print Dumper $user;

	$self->{users}->{ $user->{token} } = $user;
	my $id = $user->{user_id};

	my $cv = AnyEvent->condvar;
	$self->{kvc}->set("pcrehttpd-user-".$user->{username}, $user, sub {
		$self->{kvc}->set($id, $user, $cb);
	});
}

sub getSession {
	my ($self, $sid) = @_;

	return $self->{sessions}->{$sid};
}

sub setSession {
	my ($self, $session) = @_;
	
	my $sid = $session->{_pcre_session_id};
	$self->{sessions}->{ $sid } = $session;
	#print Dumper $self->{sessions};

}

sub generateSessionID {
	my $self = shift;
	my $sessionID;
	foreach my $n (0..31) {
		$sessionID .= $self->{space}->[ int(rand(scalar(@{$self->{space}}))) ];
	}
	return $sessionID;
}

sub get_data {
	my ($self, $fh) = @_;

	unless ($responses->{$fh}) { return; }
	my $v = $responses->{$fh};
	$responses->{$fh} = undef;
	return $v;
}

1;
