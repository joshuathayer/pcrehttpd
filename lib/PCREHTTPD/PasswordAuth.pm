package PasswordAuth;

sub new {
	my $this = shift;
	my $class = ref($this) || $this;

	my $self = {};
	$self->{name} = "PasswordAuth";	
	$self->{token} = '';
	$self->{password} = '';

	$self->{createdDate} = time;
	$self->{modifiedDate} = time;

	bless($self, $class);
	return $self;	
}

sub setToken {
	my ($self, $t) = @_;
	$self->{token} = $t;
}

sub setPassword {
	my ($self, $p) = @_;
	$self->{password} = $p;
}

sub checkPassword {
	my ($self, $p) = @_;
	if ($p eq $self->{password}) {
		return 1;
	}
	return 0;
}

sub getToken {
	my $self = shift;
	return $self->{token};
}

sub getPassword {
	my $self = shift;
	return $self->{apssword};
}

1;

