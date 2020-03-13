#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Warnings;
use FindBin '$Bin';
use lib "$Bin/lib";
use OpenQA::Test::Warnings qw(stderr_like $DEBUG_RE);

use lockapi;

# mock api_call return value
my $api_call_return;
my %locks;
my %action = (
    method => undef,
    action => undef,
    params => undef,
);

package ua_return;

sub new  { my $t = shift; return bless {res => @_}, $t; }
sub code { return shift->{res} }
1;

package main;
# simulate responses from openQA WebUI or overridden by $api_call_return
sub fake_api_call {
    my ($method, $action, $params, $expected_codes) = @_;
    %action = (
        method => $method,
        action => $action,
        params => $params
    );
    return ua_return->new($api_call_return);
}

# monkey-patch mmap::api_call
my $mod = Test::MockModule->new('lockapi');
$mod->mock(api_call => \&fake_api_call);

# So barriers can call record_info
use basetest;
$autotest::current_test = basetest->new();
my $mock_bmwqemu = Test::MockModule->new('bmwqemu');
$mock_bmwqemu->mock(result_dir => File::Temp->newdir());

sub check_action {
    my ($method, $action, $params) = @_;
    my $res = 0;
    $res++ if ($method eq $action{method});
    $res++ if ($action eq $action{action});
    #     return unless($params

    %action = (
        method => undef,
        action => undef,
        params => undef,
    );
    return $res;
}

eval { mutex_create; };
ok($@, 'missing create name catched');
eval { mutex_try_lock; };
ok($@, 'missing try lock name catched');
eval { mutex_lock; };
ok($@, 'missing lock name catched');
eval { mutex_unlock; };
ok($@, 'missing unlock name catched');

# check successful ops
$api_call_return = 200;
stderr_like { ok(mutex_create('lock1'), 'mutex created') }
qr{\A$DEBUG_RE mutex create 'lock1'\n\z}, 'mutex create STDERR ok';
ok(check_action('POST', 'mutex', {name => 'lock1'}), 'mutex_create request valid');

stderr_like { ok(mutex_lock('lock1'), 'mutex locked') }
qr{\A$DEBUG_RE mutex lock 'lock1'\n\z}, 'mutext lock STDERR ok';
ok(check_action('POST', 'mutex/lock1', {action => 'lock'}), 'mutex_lock request valid');

stderr_like { ok(mutex_try_lock('lock1'), 'mutex locked') }
qr{\A$DEBUG_RE mutex try lock 'lock1'\n\z}, 'mutex try lock STDERR ok';
ok(check_action('POST', 'mutex/lock1', {action => 'lock'}), 'mutex_lock request valid');

stderr_like { ok(mutex_unlock('lock1'), 'lock unlocked') }
qr{\A$DEBUG_RE mutex unlock 'lock1'\n\z}, 'mutext unlock STDERR ok';
ok(check_action('POST', 'mutex/lock1', {action => 'unlock'}), 'mutex_unlock request valid');

# check unsuccessful ops
$api_call_return = 409;
stderr_like { ok(!mutex_create('lock1'), 'mutex not created') }
qr{\A$DEBUG_RE mutex create 'lock1'\n\z}, 'mutex create lock STDERR ok';
ok(check_action('POST', 'mutex', {name => 'lock1'}), 'mutex_create request valid');

# instead of mutex_lock test mutex_try_lock to avoid block
stderr_like { ok(!mutex_try_lock('lock1'), 'mutex not locked') }
qr{\A$DEBUG_RE mutex try lock 'lock1'\n\z}, 'mutex try lock STDERR ok';
ok(check_action('POST', 'mutex/lock1', {action => 'lock'}), 'mutex_lock request valid');

stderr_like { ok(!mutex_unlock('lock1'), 'lock not unlocked') }
qr{\A$DEBUG_RE mutex unlock 'lock1'\n\z}, 'mutex unlock STDERR ok';
ok(check_action('POST', 'mutex/lock1', {action => 'unlock'}), 'mutex_unlock request valid');



# barriers testing
$api_call_return = 200;
eval { barrier_create; };
ok($@, 'missing create name catched');
eval { barrier_create('barrier1'); };
ok($@, 'missing create tasks catched');
eval { barrier_wait; };
ok($@, 'missing wait name catched');
eval { barrier_destroy; };
ok($@, 'missing destroy name catched');

stderr_like { ok(barrier_create('barrier1', 3), 'barrier created') }
qr{\A$DEBUG_RE barrier create 'barrier1' for 3 tasks\n\z}, 'barrier create STDERR ok';
ok(check_action('POST', 'barrier', {name => 'barrier1', tasks => 3}), 'barrier create request valid');
my $qr = qr{\A$DEBUG_RE \Qbarrier wait 'barrier1'\E.*\Qtestapi::record_info(output="Wait for barrier1 (on parent job)", result="ok", title="Paused")\E.*\Qtestapi::record_info(output="Wait for barrier1 (on parent job)", result="ok", title="Paused 0m0s")\E\n\z}s;

stderr_like { ok(barrier_wait('barrier1'), 'registered for waiting and released immideately') }
$qr, 'barrier wait STDERR ok';
ok(check_action('POST', 'barrier/barrier1', undef), 'barrier wait request valid');

stderr_like { ok(barrier_wait {name => 'barrier1'}, 'registered for waiting and released immediately') }
$qr, 'barrier wait STDERR ok';
ok(check_action('POST', 'barrier/barrier1', undef), 'barrier wait request valid');

stderr_like { ok(barrier_wait({name => 'barrier1', check_dead_job => 1}), 'registered for waiting and destroy barrier if one of the jobs die') }
$qr, 'barrier wait STDERR ok';
ok(check_action('POST', 'barrier/barrier1', {check_dead_job => 1}), 'barrier wait request valid with check_dead_job');

stderr_like { ok(barrier_destroy('barrier1'), 'barrier destroyed') }
qr{\A$DEBUG_RE barrier destroy 'barrier1'\n\z}, 'barrier destroy STDERR ok';
ok(check_action('DELETE', 'barrier/barrier1', undef), 'barrier destroy request valid');

$api_call_return = 409;
stderr_like { ok(!barrier_create('barrier1', 3), 'barrier not created') }
qr{\A$DEBUG_RE barrier create 'barrier1' for 3 tasks\n\z},
  'barrier create STDERR ok';

ok(check_action('POST', 'barrier', {name => 'barrier1', tasks => 3}), 'barrier create request valid');

# instead of barrier_wait test barrier_try_wait to avoid block
stderr_like { ok(!barrier_try_wait('barrier1'), 'registered for waiting and waiting'); }
qr{\A$DEBUG_RE barrier try wait 'barrier1'\n\z}, 'barrier try wait STDERR ok';
ok(check_action('POST', 'barrier/barrier1', undef), 'barrier wait request valid');

ok(!barrier_destroy('barrier1'),                      'barrier not destroyed');
ok(check_action('DELETE', 'barrier/barrier1', undef), 'barrier destroy request valid');

done_testing;
