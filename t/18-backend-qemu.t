#!/usr/bin/perl

use Test::Most;
use Mojo::Base -strict, -signatures;

use FindBin '$Bin';
use lib "$Bin/../external/os-autoinst-common/lib";
use OpenQA::Test::CheckGitStatus;
use OpenQA::Test::TimeLimit '5';
use Test::MockModule;
use Test::MockObject;
use Test::Output qw(combined_like stderr_like);
use Test::Warnings qw(:all :report_warnings);
use Test::Fatal;
use Mojo::File 'tempdir';
use Mojo::Util qw(scope_guard);
use Mojo::JSON;

use backend::qemu;

my $dir = tempdir("/tmp/$FindBin::Script-XXXX");
chdir $dir;
my $cleanup = scope_guard sub { chdir $Bin; undef $dir };

my $proc = Test::MockModule->new('OpenQA::Qemu::Proc');
$proc->redefine(exec_qemu => undef);
$proc->redefine(connect_qmp => undef);
$proc->redefine(init_blockdev_images => undef);
ok(my $backend = backend::qemu->new(), 'backend can be created');
# disable any graphics display in tests
$bmwqemu::vars{QEMU_APPEND} = '-nographic';
# as needed to start backend
$bmwqemu::vars{VNC} = '1';
my $jsonrpc = Test::MockModule->new('myjsonrpc');
$jsonrpc->redefine(read_json => undef);
my $backend_mock = Test::MockModule->new('backend::qemu', no_auto => 1);
$backend_mock->redefine(handle_qmp_command => undef);
my $distri = Test::MockModule->new('distribution');
my %called;
$distri->redefine(add_console => sub {
        $called{add_console}++;
        my $ret = Test::MockObject->new();
        $ret->set_true('backend');
        return $ret;
});
# "redefine" fails with "backend::qemu::select_console does not exist!" but
# defining this still matters for unknown reason
$backend_mock->mock(select_console => undef);
$testapi::distri = distribution->new;
($backend->{"select_$_"} = Test::MockObject->new)->set_true('add') for qw(read write);
stderr_like { ok($backend->start_qemu(), 'qemu can be started') } qr/running .*chattr/, 'preparing local files';
ok(exists $called{add_console}, 'a console has been added');
is($called{add_console}, 1, 'one console has been added');

subtest 'using Open vSwitch D-Bus service' => sub {
    my $expected = qr/Open vSwitch command.*show.*arguments 'foo bar'.*(The name.*not provided|Failed to connect)/;
    my $msg = 'error about missing service';
    like exception { $backend->_dbus_call('show', 'foo', 'bar') }, $expected, $msg . ' in exception';
    $bmwqemu::vars{QEMU_NON_FATAL_DBUS_CALL} = 1;
    combined_like { ok($backend->_dbus_call('show', 'foo', 'bar'), 'failed dbus call ignored gracefully') } $expected, $msg;
    $bmwqemu::vars{QEMU_NON_FATAL_DBUS_CALL} = 0;
    $backend_mock->redefine(_dbus_do_call => sub { (1, 'failed') });
    like exception { $backend->_dbus_call('show') }, qr/failed/, 'failed dbus call throws exception';
};

$backend_mock->redefine(handle_qmp_command => sub { push @{$called{handle_qmp_command}}, $_[1] });
$backend->power({action => 'off'});
ok(exists $called{handle_qmp_command}, 'a qmp command has been called');
is_deeply($called{handle_qmp_command}, [{execute => 'quit'}], 'quit has been called for off');
$called{handle_qmp_command} = undef;
$backend->power({action => 'acpi'});
is_deeply($called{handle_qmp_command}, [{execute => 'system_powerdown'}], 'powerdown has been called for acpi');
$called{handle_qmp_command} = undef;

subtest 'eject cd' => sub {
    my %default_eject_params = (execute => 'eject', arguments => {id => 'cd0-device', force => Mojo::JSON->true});
    my %default_remove_params = (execute => 'blockdev-remove-medium', arguments => {id => 'cd0-device'});
    my %custom_eject_params = (execute => 'eject', arguments => {id => 'cd1', force => Mojo::JSON->false});
    my %custom_remove_params = (execute => 'blockdev-remove-medium', arguments => {id => 'cd1'});

    $called{handle_qmp_command} = undef;
    $backend->eject_cd;
    is_deeply $called{handle_qmp_command}[0], \%default_eject_params, 'eject called with correct defaults';
    is_deeply $called{handle_qmp_command}[1], \%default_remove_params, 'blockdev-remove-medium called with correct defaults';
    $called{handle_qmp_command} = undef;
    $backend->eject_cd({id => 'cd1', force => 0});
    is_deeply $called{handle_qmp_command}[0], \%custom_eject_params, 'eject called with custom parameters';
    is_deeply $called{handle_qmp_command}[1], \%custom_remove_params, 'blockdev-remove-medium called with custom parameters';
};

subtest 'execute arbitrary QMP command' => sub {
    my %query = (execute => 'foo', arguments => {bar => 1});
    $called{handle_qmp_command} = undef;
    $backend->execute_qmp_command({query => \%query});
    is_deeply $called{handle_qmp_command}, [\%query], 'query params passed as-is';
};

subtest 'process_qemu_output' => sub {
    my $qemu_log = <<'EOF';
QEMU emulator version 4.2.1 (openSUSE Leap 15.2)
Copyright 2003-2019 Fabrice Bellard and the QEMU Project developers
qemu-system-x86_64: cannot set up guest memory 'pc.ram': Cannot allocate memory
EOF
    my $expected = qr/\[debug\].*QEMU emulator version.*\[warn\].*Cannot allocate memory/s;
    my $msg = 'qemu output logged with distinct log levels';
    combined_like { backend::qemu::process_qemu_output($qemu_log) } $expected, $msg;
};

done_testing();
