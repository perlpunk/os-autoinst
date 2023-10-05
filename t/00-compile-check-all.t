#!/usr/bin/perl
# Copyright 2015-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Test::Most;
use Mojo::Base -strict, -signatures;
# We need :no_end_test here because otherwise it would output a no warnings
# test for each of the modules, but with the same test number
use Test::Warnings qw(:report_warnings);

diag "PERL_TEST_WARNINGS_ONLY_REPORT_WARNINGS=$ENV{PERL_TEST_WARNINGS_ONLY_REPORT_WARNINGS}";
diag(Test::Warnings->VERSION);

my $x;
my $y = 1 + $x;

pass "dummy";

done_testing;

