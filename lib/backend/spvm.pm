# Copyright © 2018-2020 SUSE LLC
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

package backend::spvm;

use strict;
use warnings;

use base 'backend::virt';

use testapi qw(get_var get_required_var);

# supporting the minimal command set of NovaLink through a ssh tunnel

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new;
    get_required_var('WORKER_HOSTNAME');

    return $self;
}

# only define the novalink console - we leave the actual
# poweron to the test
sub do_start_vm {
    my ($self) = @_;
    $self->truncate_serial_file;
    my $ssh = $testapi::distri->add_console(
        'novalink-ssh',
        'ssh-xterm',
        {
            hostname   => get_required_var('NOVALINK_HOSTNAME'),
            password   => get_required_var('NOVALINK_PASSWORD'),
            username   => get_var('NOVALINK_USERNAME', 'root'),
            persistent => 1});
    $ssh->backend($self);

    return {};
}

sub do_stop_vm {
    my ($self) = @_;

    $self->stop_serial_grab;
    $self->deactivate_console({testapi_console => 'novalink-ssh'});
    return {};
}

sub run_cmd {
    my ($self, $cmd, $hostname, $password) = @_;
    $hostname ||= get_required_var('NOVALINK_HOSTNAME');
    $password ||= get_required_var('NOVALINK_PASSWORD');
    my $username = get_var('NOVALINK_USERNAME', 'root');

    return $self->run_ssh_cmd($cmd, username => $username, password => $password, hostname => $hostname, keep_open => 0);
}

sub can_handle {
    my ($self, $args) = @_;
    return;
}

sub is_shutdown {
    my ($self) = @_;
    my $lpar_id = get_required_var('NOVALINK_LPAR_ID');
    return $self->run_cmd("! pvmctl  lpar list -i id=${lpar_id} | grep  'not a'");
}

sub check_socket {
    my ($self, $fh, $write) = @_;

    return $self->check_ssh_serial($fh) || $self->SUPER::check_socket($fh, $write);
}

sub stop_serial_grab {
    my ($self) = @_;

    $self->stop_ssh_serial;
    return;
}

sub power {
    # parameters: on, off, reset
    my ($self, $args) = @_;
    my $action  = $args->{action};
    my $lpar_id = get_required_var('NOVALINK_LPAR_ID');

    my %cmds = (
        on    => "pvmctl lpar power-on -i id=${lpar_id} --bootmode norm",
        off   => "pvmctl lpar power-off -i id=${lpar_id} --hard",
        reset => "pvmctl lpar restart -i id=${lpar_id}");
    $self->run_cmd($cmds{$action}) if (exists($cmds{$action})) || die "Unknown power action ${action}";
}

1;
