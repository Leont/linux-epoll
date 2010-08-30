#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Linux::Epoll' ) || print "Bail out!
";
}

diag( "Testing Linux::Epoll $Linux::Epoll::VERSION, Perl $], $^X" );
