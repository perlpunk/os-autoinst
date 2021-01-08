package OpenQA::Isotovideo;
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2020 SUSE LLC
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
#

use strict;
use warnings;
use Mojo::IOLoop::ReadWriteProcess::Session 'session';
use Time::HiRes qw(gettimeofday tv_interval sleep time);

use testapi 'diag';

use base 'Exporter';

our $backend_process;
our $cmd_srv_process;
our $testprocess;
our $command_handler;
our $testfd;
our $cmd_srv_port;

our @EXPORT_OK = qw( $backend_process $cmd_srv_process $testprocess
  $command_handler $testfd $cmd_srv_port );

sub startup {
    session->enable;
    session->enable_subreaper;
}

sub shutdown {
    stop_backend();
    stop_commands('test execution ended through exception');
    stop_autotest();
}

# note: The subsequently defined stop_* functions are used to tear down the process tree.
#       However, the worker also ensures that all processes are being terminated (and
#       eventually killed).

sub stop_backend {
    return unless defined $bmwqemu::backend && $backend_process;

    diag('stopping backend process ' . $backend_process->pid);
    $backend_process->stop if $backend_process->is_running;
    $backend_process = undef;
    diag('done with backend process');
}

sub stop_commands {
    my ($reason) = @_;
    return unless defined $cmd_srv_process;
    return unless $cmd_srv_process->is_running;

    my $pid = $cmd_srv_process->pid;
    diag("stopping command server $pid because $reason");

    if ($cmd_srv_port && $reason && $reason eq 'test execution ended') {
        my $job_token = $bmwqemu::vars{JOBTOKEN};
        my $url       = "http://127.0.0.1:$cmd_srv_port/$job_token/broadcast";
        diag('isotovideo: informing websocket clients before stopping command server: ' . $url);

        # note: If the job is stopped by the worker because it has been
        # aborted, the worker will send this command on its own to the command
        # server and also stop the command server. So this is only done in the
        # case the test execution just ends.

        my $timeout = 15;
        # The command server might have already been stopped by the worker
        # after the user has aborted the job or the job timeout has been
        # exceeded so no checks for failure done.
        Mojo::UserAgent->new(request_timeout => $timeout)->post($url, json => {stopping_test_execution => $reason});
    }

    $cmd_srv_process->stop();
    $cmd_srv_process = undef;
    diag('done with command server');
}

sub stop_autotest {
    return unless defined $testprocess;

    diag('stopping autotest process ' . $testprocess->pid);
    $testprocess->stop() if $testprocess->is_running;
    $testprocess = undef;
    diag('done with autotest process');
}

my ($last_check_seconds, $last_check_microseconds);
sub check_asserted_screen {
    my $no_wait = shift;

    if ($no_wait) {
        # prevent CPU overload by waiting at least a little bit
        $command_handler->timeout(0.1);
    }
    else {
        _calc_check_delta();
        # come back later, avoid too often called function
        return if $command_handler->timeout > 0.05;
    }
    ($last_check_seconds, $last_check_microseconds) = gettimeofday;
    my $rsp = $bmwqemu::backend->_send_json({cmd => 'check_asserted_screen'}) || {};
    # the test needs that information
    $rsp->{tags} = $command_handler->tags;
    if ($rsp->{found} || $rsp->{timeout}) {
        myjsonrpc::send_json($testfd, {ret => $rsp});
        $command_handler->clear_tags_and_timeout();
    }
    else {
        _calc_check_delta() unless $no_wait;
    }
}

sub _calc_check_delta {
    # an estimate of eternity
    my $delta = 100;
    if ($last_check_seconds) {
        $delta = tv_interval([$last_check_seconds, $last_check_microseconds], [gettimeofday]);
    }
    # sleep the remains of one second if $delta > 0
    my $timeout = $delta > 0 ? 1 - $delta : 0;
    $command_handler->timeout($timeout < 0 ? 0 : $timeout);
    return $delta;
}



1;
