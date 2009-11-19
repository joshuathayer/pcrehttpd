package PCREUser;
use strict;
use Data::Dumper;

use lib ('/Users/joshua/projects/mykeyv/lib/');

=head1 NAME

PCREUser - a user class for the PCREHTTPD web application server

=head1 VERSION

Version 0.01

=cut

our $VERSION  = '0.01';

=head1 SYNOPSIS

	use PCREUser;

	my $u =  $PCREUser->new();

	# recover from kvd
	$u->fromToken($userID);

	# modify
	$u->grant($application, $perm);
	$u->setToken("joshuamilesthayer\@gmail.com");

	# store back to kvd
	$u->store();

=head1 DESCRIPTION

This module provides a user class to PCREHTTPD. Applications using PCREHTTPD should use
this model.

=cut

our $kvc = undef;

sub new {
	my $this = shift;
	my $tok = shift;
	my $class = ref($this) || $this;
	my $self;

	if ($tok) {
		my $cb = shift;
		$self = fromToken($tok, sub {
			$self = shift;
			bless($self, $class);
			$cb->($self);
		});
	} else {
		
		my $self= {};

		$self->{token} = undef;
		$self->{createDate} = time;
		$self->{modifiedDate} = time;
		$self->{active} = 1;
	
		# a hash of arrays of names of "grants" this user has.
		# applications maintain this... so something like
		# $self->{grants}->{pcrehttpd}->{admin}=1;
		$self->{grants} = {};
		
		# a hash of authentication schemes
		# $self->{authentication}->{password} = new PasswordAuth();
		$self->{authentication} = undef;	

		bless($self,$class);
		return $self;
	}	
}

sub fromToken {
	my ($token, $cb) = @_;

	$token = "pcrehttpd-user-$token";

	unless ($kvc) {
		die("cannot use kvd without a valid client instance");
	}
	
	$kvc->get($token, sub {
		my $result = shift;
		# $result is a get result, not a user object 
		# so...	
		my $u = $result->{data};
		
		# we bless this above...
		$cb->($u);
	});
}

sub setToken {
	my ($self, $token) = @_;
	
	if (defined($self->{token})) {
		die("can't re-set user token...");
	}

	$self->{token} = $token;
}

sub grant {
	my ($self, $app, $grant, $val) = @_;

	die ("no app or grant to grant to") unless $app && $grant;
	$val = $val ? $val : 1;
	$self->{grants}->{$app}->{$grant} = $val;
}

# return our value for a given authentication scheme...
sub getAuthentication {
	my ($self, $scheme) = @_;

	return $self->{authentication}->{$scheme};
}

sub setAuthentication {
	my ($self, $scheme) = @_;
	die ("unknown scheme!") unless ($scheme->{name});
	$self->{authentication}->{ $scheme->{name} } = $scheme;	
}

# stash this dude away into kvd-land
sub store {
	my ($self, $cb) = @_;

	unless ($kvc) {
		die("cannot use kvd without a valid client instance");
	}

	$self->{modifiedDate} = time;

	# probably going to stick this into a number of indexes as well
	$kvc->set(
		"pcrehttpd-user-".$self->{token},
		$self,
		sub { $cb->(); }
	);

}

# actually no. class users should just set the class variable directly
# allow another app (pcrehttpd) to give us a kvd client instance to use.
#sub setKVC {
#	my ($self, $lkvc) = @_;

#	# this might need to get a lot more complex. do we really want
#	# to be able to re-set our kvc mid-flight?
#	$kvc = $lkvc;
#}

1;
