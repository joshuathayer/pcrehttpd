package ExamplePCREApp;

sub new {
	my $class = shift;

	my $self = {};

	bless ($self, $class);
	return $self;
}
	

# this is an example PCREHTTPD app
sub index {
	my ($self, $meth, $u, $params, $cont, $cb, $logcb) = @_;

	$cb->(200, "OK", {"content-type" => "text/html"},
	                  "<html><head><title>it worked</title></head><body><h4>it worked hooray</h4></body></html>"
	);
}

sub test {
	my ($self, $meth, $u, $params, $cont, $cb, $logcb) = @_;

	$logcb->("log test in test function");

	$cb->(200, "OK", {"content-type" => "text/html"},
	                  "<html><head><title>HAHA TEST</title></head><body>keep killing them regularly!</body></html>"
	);
}

sub dienow {
	my ($self, $meth, $u, $params, $cont, $cb, $logcb) = @_;

	$logcb->("going to try dying");

	die;
}

1;
