package Linux::Epoll::Util;

use strict;
use warnings FATAL => 'all';

our $VERSION = '0.001';

use Linux::Epoll;

use Sub::Exporter -setup => { exports => [qw/event_names_to_bits event_bits_to_hash/] };

1;    # End of Linux::Epoll::Util

__END__

=head1 NAME

Linux::Epoll::Util - Utility functions for Linux::Epoll

=head1 VERSION

Version 0.001

=head1 DESCRIPTION

This module provides a few utility functions for Linux::Epoll

=head1 SUBROUTINES

=head2 event_bits_to_hash($bits)

Convert a bitset into a hashref, with keys being the names of the bits that are set and the values being true.

=head2 event_names_to_bits($names)

Convert $names into a event bitset. $names must either be a string from the set described in L<Linux::Epoll>, or an arrayref containing such strings.

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
