#! perl

use strict;
use warnings;
use IO::Handle;
use Test::More tests => 8;
use Linux::Epoll;
use Socket;

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $poll = Linux::Epoll->new();

my $stdout = \*STDOUT;
my $dupout = IO::Handle->new_from_fd(fileno $stdout, "w");

alarm 2;

my $subnum = 1;

is $poll->wait(1, 0), 0, 'No events to wait for';

socketpair my $in, my $out, AF_UNIX, SOCK_STREAM, PF_UNSPEC or die 'Failed';

$poll->add($in, 'in', sub { my $foo = shift; sub { ok $foo, 'anonymous closure works'; is $subnum, 1, 'First handler' } }->(1));

is $poll->wait(1, 0), 0, 'Still no events to wait for';

syswrite $out, 'foo', 3;

is $poll->wait(1, 0), 1, 'Finally an event';

sysread $in, my $buffer, 3;

is $poll->wait(1, 0), 0, 'No more events to wait for';

$poll->modify($in, [ qw/in out/ ], sub { is $subnum, 2, 'Second handler' });

$subnum = 2;

syswrite $out, 'bar', 3;

is $poll->wait(1, 0), 1, 'Finally an event';

