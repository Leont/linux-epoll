use 5.010;
use strict;
use warnings;
use Module::Build;

if ($^O ne 'linux') {
	print "No support for OS\n";
	exit 0;
}

my $builder = Module::Build->new(
	module_name         => 'Linux::Epoll',
	license             => 'perl',
	dist_author         => q{Leon Timmermans <leont@cpan.org>},
	dist_version_from   => 'lib/Linux/Epoll.pm',
	configure_requires  => {
		'Module::Build' => 0.28,
	},
	build_requires      => {
		'Module::Build' => 0.28,
		'ExtUtils::CBuilder' => 0,
		'Test::More'    => 0,
	},
	requires	        => {
		perl            => 5.010,
		parent          => 0,
		'Sub::Exporter' => 0,
	},
	add_to_cleanup      => [ 'Linux-Epoll-*' ],
	create_makefile_pl  => 'small',
	sign                => 1,
);

$builder->create_build_script();
