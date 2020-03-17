#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use FindBin '$Bin';
use lib "$Bin/lib";
use OpenQA::Test::Warnings qw(stderr_like combined_like $DEBUG_RE);
use Test::Warnings;
use File::Which 'which';
use File::Basename;

BEGIN {
    $bmwqemu::vars{DISTRI}      = 'unicorn';
    $bmwqemu::vars{CASEDIR}     = '/var/lib/empty';
    $bmwqemu::vars{NEEDLES_DIR} = dirname(__FILE__) . '/data';
}

use needle;
use cv;
use ocr;

cv::init();
require tinycv;

unless (which('tesseract')) {
    plan skip_all => 'No tesseract installed';
    exit(0);
}

stderr_like sub { needle::init }, [qr/git hash/, qr/init needles/, qr/loaded.*needles/], 'log output for needle init';
my $img1   = tinycv::read(needle::needles_dir() . '/bootmenu.test.png');
my $needle = needle->new('bootmenu-ocr.ref.json');
my $res;
stderr_like sub { $res = $img1->search($needle) }, [(qr/Tesseract.*OCR/ , qr/Warning/) x 2], 'log output for OCR';
ok(defined $res, 'ocr match 1');

my $ocr;
for my $area (@{$res->{needle}->{area}}) {
    next unless $area->{type} eq 'ocr';
    stderr_like sub { $ocr .= ocr::tesseract($img1, $area) }, [qr/Tesseract.*OCR/ , qr/Warning/], 'log output for tesseract call';
}

ok($ocr =~ /Memory Test.*Video Mode/s, 'multiple OCR regions');
done_testing;
