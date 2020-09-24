# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2019-2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package consoles::network_console;

use strict;
use warnings;

use base 'consoles::console';

use Try::Tiny;
use Scalar::Util 'blessed';

sub activate {
    my ($self) = @_;
    try {
        local $SIG{__DIE__} = undef;
        $self->connect_remote($self->{args});
        return $self->SUPER::activate;
    }
    catch {
        die $_ unless blessed $_ && $_->can('rethrow');
        return {error => $_->error};
    };
}

# to be overwritten
sub connect_remote { }

1;
