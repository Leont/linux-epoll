package Linux::Epoll;

use strict;
use warnings FATAL => 'all';
use Carp qw/croak/;
use Const::Fast;

use parent 'IO::Handle';

our $VERSION = '0.001';

XSLoader::load(__PACKAGE__, $VERSION);

const my $fail_fd => -1;

sub create {
	my $class = shift;
	croak if ((my $fd = _create()) == $fail_fd);
	open my $self, '+<&', $fd or croak "Couldn't fdopen: $!";
	bless $self, $class;
	return $self;
}

1;    # End of Linux::Epoll

__END__

=head1 NAME

Linux::Epoll - O(1) multiplexing for Linux

=head1 VERSION

Version 0.001

=head1 SYNOPSIS

    use Linux::Epoll;

    my $foo = Linux::Epoll->create();
	$foo->add($fh, 'in', sub { do_something($fh) });
	$foo->wait;

=head1 DESCRIPTION

Epoll is a multiplexing mechanism that scales up O(1) with number of watched files. Linux::Epoll is a callback style epoll module, unlike other epoll modules availible on CPAN.

=head1 METHODS

=head2 create()

=head2 add($fh, $events, $callback)

=head2 modify($fh, $events, $callback)

=head2 delete($fh)

=head2 wait($number, $timeout = undef, $sigmask = undef)

=head1 AUTHOR

Leon Timmermans, C<< <leont at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-linux-epoll at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Linux-Epoll>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Linux::Epoll

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Linux-Epoll>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Linux-Epoll>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Linux-Epoll>

=item * Search CPAN

L<http://search.cpan.org/dist/Linux-Epoll/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Leon Timmermans.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
