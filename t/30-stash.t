#! perl

use strict;
use warnings;

use Test::More;
use B ();
use Linux::Epoll;

sub gen_entries {
	no strict 'refs';
	return grep { /^_GEN_\d+$/ } keys %{'Linux::Epoll::'};
}

sub fd_is_open {
	my $fd = shift;
	return -e "/proc/self/fd/$fd";
}

my @before = gen_entries();
is_deeply \@before, [], 'No generated globs in the stash at start';

{
	my $poll = Linux::Epoll->new;
	is_deeply [ gen_entries() ], [], 'A live epoll leaves nothing in the stash';
	ok defined fileno $poll, 'The handle still has a file descriptor';
	is $poll->wait(1, 0), 0, 'The handle still works';
}

is_deeply [ gen_entries() ], [], 'A freed epoll leaves nothing in the stash';

{
	my $poll = Linux::Epoll->new;
	my $fd = fileno $poll;
	ok fd_is_open($fd), 'The epoll descriptor is open while the object lives';
	undef $poll;
	ok !fd_is_open($fd), 'Freeing the object closes the epoll descriptor';
}

{
	package My::Epoll;
	our @ISA = ('Linux::Epoll');
}

{
	my $poll = My::Epoll->new;
	isa_ok $poll, 'My::Epoll';
	my $fd = fileno $poll;
	undef $poll;
	ok !fd_is_open($fd), 'Freeing a subclass object closes its descriptor';
	no strict 'refs';
	is_deeply [ grep { /^_GEN_\d+$/ } keys %{'My::Epoll::'} ], [], 'Nor does a subclass leave stash entries';
}

{
	Linux::Epoll->new for 1 .. 3;
	my $walked = 0;
	no strict 'refs';
	for my $name (sort keys %{'Linux::Epoll::'}) {
		B::svref_2object(\*{"Linux::Epoll::$name"})->NAME;
		$walked++;
	}
	ok $walked, 'Walking the stash after freeing epolls survives';
	is_deeply [ gen_entries() ], [], 'And finds no generated globs';
}

done_testing;
