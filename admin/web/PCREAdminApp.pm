package PCREAdminApp;
use strict;
use File::Find;
use Cwd;
use Data::Dumper;

sub staticTree {
	my $dir = shift;

	my $wd = getcwd;
	chdir($dir);

	my $tree;

	find(sub {
		my $d = $File::Find::dir;
		my $n = $File::Find::name;
		my $s = '';
		my $cwd = getcwd;
		my $fn = "$cwd/$_";
		open FH, "<$fn" or die $!;
		while (<FH>) { $s .= $_; }
		close(FH);
		$n =~ s/^$dir\///;
		$tree->{$n} = $s;
	}, $dir);
	#print Dumper $tree;
	return $tree;
}	

sub new {
	my $class = shift;

	my $self = {};

	my $p = AWP::Parser->new();
	$p->includeMods("/Users/joshua/projects/pcrehttpd/admin/web/mods");
	$p->parsefile("/Users/joshua/projects/pcrehttpd/admin/web/templates/index.xhtml");
	$self->{templates}->{index} = $p;

	# ok static tree.
	# this should be a parent class method
	# this should also set up subs, so we don't have to write subs like "css", below
	$self->{static} = staticTree("/Users/joshua/projects/pcrehttpd/admin/web/pcre_admin_static");
	# and in fact, we don't want to write things like "index" below, either... parsing
	# the tree should add methods to our classes

	bless($self, $class);
	return($self);
}

sub pcre_admin_static {
	my ($self, $context, $cb, $logcb) = @_;
	my $u = $context->{url};
	my ($p) = $u =~ /pcre_admin_static\/(.*)$/;
	my $c = $self->{static}->{$p};

	$cb->(200, "OK", {"content->type" => "text/css"}, $c);
}

sub pcre_admin {
	my ($self, $context, $cb, $logcb) = @_;
	my $out = $self->{templates}->{index}->walk($context);

	$cb->(200, "OK", {"content-type" => "text/html"}, $out);
}

1;
	
