#!/usr/bin/perl

use 5.018;
use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::MockObject;
use FindBin '$Bin';
use lib "$Bin/lib";
use OpenQA::Test::Warnings qw(stderr_like combined_like $DEBUG_RE);
use Test::Warnings;

use backend::qemu;


my $proc = Test::MockModule->new('OpenQA::Qemu::Proc');
$proc->mock(exec_qemu            => undef);
$proc->mock(connect_qmp          => undef);
$proc->mock(init_blockdef_images => undef);
ok(my $backend = backend::qemu->new(), 'backend can be created');
# disable any graphics display in tests
$bmwqemu::vars{QEMU_APPEND} = '-nographic';
# as needed to start backend
$bmwqemu::vars{VNC} = '1';
my $jsonrpc = Test::MockModule->new('myjsonrpc');
$jsonrpc->mock(read_json => undef);
my $backend_mock = Test::MockModule->new('backend::qemu', no_auto => 1);
$backend_mock->mock(handle_qmp_command => undef);
my $distri = Test::MockModule->new('distribution');
my %called;
$distri->mock(add_console => sub {
        $called{add_console}++;
        my $ret = Test::MockObject->new();
        $ret->set_true('backend');
        return $ret;
});
$backend_mock->mock(select_console => undef);
$testapi::distri = distribution->new;
($backend->{"select_$_"} = Test::MockObject->new)->set_true('add') for qw(read write);
stderr_like { ok($backend->start_qemu(), 'qemu can be started'); }
qr/\A$DEBUG_RE running .*chattr.*\n$DEBUG_RE running.*qemu-img.*\n$DEBUG_RE Formatting.*\n\z/,
  'preparing local files';
ok(exists $called{add_console}, 'a console has been added');
is($called{add_console}, 1, 'one console has been added');

done_testing();

END {
    unlink "$Bin/../virtio_console.in";
    unlink "$Bin/../virtio_console.out";
}
