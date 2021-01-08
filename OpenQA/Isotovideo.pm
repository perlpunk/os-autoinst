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
use autodie ':all';
no autodie 'kill';
use Mojo::IOLoop::ReadWriteProcess::Session 'session';
use Time::HiRes qw(gettimeofday tv_interval sleep time);
use IPC::System::Simple;

use OpenQA::Isotovideo::Utils qw(checkout_git_repo_and_branch
  checkout_git_refspec handle_generated_assets load_test_schedule);
use OpenQA::Isotovideo::CommandHandler;
use bmwqemu;
use needle;
use autotest;
use commands;
use distribution;
use testapi 'diag';

use base 'Exporter';

our $backend_process;
our $cmd_srv_process;
our $testprocess;
our $command_handler;
our $testfd;
our $cmd_srv_port;
our $loop = 1;

our @EXPORT_OK = qw( $backend_process $cmd_srv_process $testprocess
  $command_handler $testfd $cmd_srv_port $loop );

sub startup {
    session->enable;
    session->enable_subreaper;
}

sub _shutdown {
    my ($msg) = @_;
    stop_backend();
    stop_commands($msg);
    stop_autotest();
}

sub main {
    my $cmd_srv_fd;

    checkout_git_repo_and_branch('CASEDIR');

    # Try to load the main.pm from one of the following in this order:
    #  - product dir
    #  - casedir
    #
    # This allows further structuring the test distribution collections with
    # multiple distributions or flavors in one repository.
    $bmwqemu::vars{PRODUCTDIR} ||= $bmwqemu::vars{CASEDIR};

    # checkout Git repo NEEDLES_DIR refers to (if it is a URL) and re-assign NEEDLES_DIR to contain the checkout path
    checkout_git_repo_and_branch('NEEDLES_DIR');

    bmwqemu::ensure_valid_vars();

    # as we are about to load the test modules checkout the specified git refspec,
    # if specified, or simply store the git hash that has been used. If it is not a
    # git repo fail silently, i.e. store an empty variable

    $bmwqemu::vars{TEST_GIT_HASH} = checkout_git_refspec($bmwqemu::vars{CASEDIR} => 'TEST_GIT_REFSPEC');

    # set a default distribution if the tests don't have one
    $testapi::distri = distribution->new;

    load_test_schedule;

    # start the command fork before we get into the backend, the command child
    # is not supposed to talk to the backend directly
    ($cmd_srv_process, $cmd_srv_fd) = commands::start_server($cmd_srv_port = $bmwqemu::vars{QEMUPORT} + 1);

    testapi::init();
    needle::init();
    bmwqemu::save_vars();

    ($testprocess, $testfd) = autotest::start_process();

    OpenQA::Isotovideo::init_backend();

    open(my $fd, ">", "os-autoinst.pid");
    print $fd "$$\n";
    close $fd;

    if (!$bmwqemu::backend->_send_json({cmd => 'alive'})) {
        # might throw an exception
        $bmwqemu::backend->start_vm();
    }

    # launch debugging tools
    my %debugging_tools;
    $debugging_tools{vncviewer}   = ['vncviewer', '-viewonly', '-shared', "localhost:$bmwqemu::vars{VNC}"] if $ENV{RUN_VNCVIEWER};
    $debugging_tools{debugviewer} = ["$bmwqemu::scriptdir/debugviewer/debugviewer", 'qemuscreenshot/last.png'] if $ENV{RUN_DEBUGVIEWER};
    for my $tool (keys %debugging_tools) {
        next if fork() != 0;
        no autodie 'exec';
        { exec(@{$debugging_tools{$tool}}) };
        exit -1;    # don't continue in any case (exec returns if it fails to spawn the process printing an error message on its own)
    }

    $backend_process = $bmwqemu::backend->{backend_process};
    my $io_select = IO::Select->new();
    $io_select->add($testfd);
    $io_select->add($cmd_srv_fd);
    $io_select->add($backend_process->channel_out);

    # stop main loop as soon as one of the child processes terminates
    my $stop_loop = sub { $loop = 0 if $loop; };
    $testprocess->once(collected => $stop_loop);
    $backend_process->once(collected => $stop_loop);
    $cmd_srv_process->once(collected => $stop_loop);

    # now we have everything, give the tests a go
    $testfd->write("GO\n");

    $command_handler = OpenQA::Isotovideo::CommandHandler->new(
        cmd_srv_fd => $cmd_srv_fd,
        backend_fd => $backend_process->channel_in,
    );
    $command_handler->on(tests_done => sub {
            CORE::close($testfd);
            $testfd = undef;
            OpenQA::Isotovideo::stop_autotest();
            $loop = 0;
    });

    my $return_code = 0;

    # enter the main loop: process messages from autotest, command server and backend
    while ($loop) {
        my ($ready_for_read, $ready_for_write, $exceptions) = IO::Select::select($io_select, undef, $io_select, $command_handler->timeout);
        for my $readable (@$ready_for_read) {
            my $rsp = myjsonrpc::read_json($readable);
            if (!defined $rsp) {
                diag sprintf("THERE IS NOTHING TO READ %d %d %d", fileno($readable), fileno($testfd), fileno($cmd_srv_fd));
                $readable = 1;
                $loop     = 0;
                last;
            }
            if ($readable == $backend_process->channel_out) {
                $command_handler->send_to_backend_requester({ret => $rsp->{rsp}});
                next;
            }
            $command_handler->process_command($readable, $rsp);
        }
        if (defined($command_handler->tags)) {
            OpenQA::Isotovideo::check_asserted_screen($command_handler->no_wait);
        }
    }

    # tell the command server that it should no longer process isotovideo commands since we've
    # just left the loop which would handle such commands (otherwise the command server would just
    # hang on the next isotovideo command)
    $command_handler->stop_command_processing;

    # terminate/kill the command server and let it inform its websocket clients before
    OpenQA::Isotovideo::stop_commands('test execution ended');

    if ($testfd) {
        $return_code = 1;    # unusual shutdown
        CORE::close $testfd;
        OpenQA::Isotovideo::stop_autotest();
    }

    diag 'isotovideo ' . ($return_code ? 'failed' : 'done');

    my $clean_shutdown;
    if (!$return_code) {
        eval {
            $clean_shutdown = $bmwqemu::backend->_send_json({cmd => 'is_shutdown'});
            diag('backend shutdown state: ' . ($clean_shutdown // '?'));
        };

        # don't rely on the backend in a sane state if we failed - just stop it later
        eval { bmwqemu::stop_vm(); };
        if ($@) {
            bmwqemu::serialize_state(component => 'backend', msg => "unable to stop VM: $@", log => 1);
            $return_code = 1;
        }
    }

    # read calculated variables from backend and tests
    bmwqemu::load_vars();

    $return_code = handle_generated_assets($command_handler, $clean_shutdown) unless $return_code;
    return $return_code;
}


sub init_backend {
    my ($name) = @_;

    $bmwqemu::vars{BACKEND} ||= "qemu";
    $bmwqemu::backend = backend::driver->new($bmwqemu::vars{BACKEND});
    return $bmwqemu::backend;
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
