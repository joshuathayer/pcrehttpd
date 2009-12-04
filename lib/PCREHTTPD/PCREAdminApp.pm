package PCREHTTPD::PCREAdminApp;
use strict;
use File::Find;
use Cwd;
use Data::Dumper;
use File::ShareDir;
use AWP::Parser;

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

	my $dir = File::ShareDir::dist_dir('pcrehttpd');


	my $p = AWP::Parser->new();
	$p->includeMods("$dir/mods");
	$p->parsefile("$dir/templates/index.xhtml");
	$self->{templates}->{index} = $p;

	# ok static tree.
	# this should be a parent class method
	# this should also set up subs, so we don't have to write subs like "css", below
	$self->{static} = staticTree("$dir/pcre_admin_static");
	# and in fact, we don't want to write things like "index" below, either... parsing
	# the tree should add methods to our classes

	bless($self, $class);
	return($self);
}

sub pcre_admin_static {
	my ($self, $context) = @_;
	my $u = $context->{url};
	my ($p) = $u =~ /pcre_admin_static\/(.*)$/;
	my $c = $self->{static}->{$p};

	$context->{_pcrehttpd_cb}->(200, "OK", {"content->type" => "text/css"}, $c);
}

sub pcre_admin {
	my ($self, $context) = @_;
	$self->{templates}->{'index'}->walk($context, {}, sub {
		my ($dat) = @_;
		$context->{_pcrehttpd_cb}->(200, "OK", {"content-type" => "text/html"}, $dat);
	});

}

1;
	
