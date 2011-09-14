use 5.006;
use strict;
use warnings;
use Module::Build;

if ($^O ne 'linux') {
	print "No support for OS\n";
	exit 0;
}

my $builder = Module::Build->new(
	module_name => 'Linux::Epoll',
	##{ $plugin->get_prereqs ##}
	##{ $plugin->get_default('share_dir') ##}
);

$builder->create_build_script();
