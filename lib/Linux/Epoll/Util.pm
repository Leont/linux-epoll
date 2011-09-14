package Linux::Epoll::Util;

use strict;
use warnings FATAL => 'all';

use Linux::Epoll;

use Sub::Exporter -setup => { exports => [qw/event_names_to_bits event_bits_to_names event_bits_to_hash/] };

1;    # End of Linux::Epoll::Util

__END__

#ABSTRACT: Utility functions for Linux::Epoll

=head1 DESCRIPTION

This module provides a few utility functions for Linux::Epoll

=func event_names_to_bits($names)

Convert $names into a event bitset. $names must either be a string from the set described in L<Linux::Epoll>, or an arrayref containing such strings.

=func event_bits_to_names($bits)

Convert bitset $bits into an arrayref of strings containing the names of the bits that are set.

=func event_bits_to_hash($bits)

Convert a bitset into a hashref, with keys being the names of the bits that are set and the values being true.

=cut
