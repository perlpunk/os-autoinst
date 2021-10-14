package Foo;
use strict;
use warnings;
use 5.010;
use Test::More;
use File::Which qw(which);
use Cwd qw(cwd);
my $cwd = cwd;
my $pid = $$;

sub check_status {
    chdir $cwd;
    my $git = which 'git';
    my $cmd = 'git rev-parse --git-dir';
    my $out = qx{$cmd};
    if ($?) {
        # Probably we aren't in a git repo
        return;
    }
    $cmd = 'git status --porcelain=v1 2>&1';
    my @lines = qx{$cmd};
    if ($? != 0) {
        diag "Problem running git:\n" . join '', @lines;
        exit 1;
    }
    my @modified;
    my @untracked;
    for my $line (@lines) {
        if ($line =~ m/^.M +(.*)/) {
            push @modified, $1;
        }
        elsif ($line =~ m/^\?\? +(.*)/) {
            push @untracked, $1;
        }
    }
    diag "Error: Modified files\n" . join '', map { "* $_\n" } @modified if @modified;
    diag "Error: Untracked files\n" . join '', map { "* $_\n" } @untracked if @untracked;
    exit 1 if (@modified or @untracked);
}

END {
    check_status() if $$ == $pid and $ENV{CHECK_GIT_STATUS};
}

1;
