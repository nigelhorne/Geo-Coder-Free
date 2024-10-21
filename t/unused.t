#!perl -w

use strict;
use warnings;

use Test::DescribeMe qw(author);
use Test::Most;
use Test::Needs { 'warnings::unused' => '0.04' };

use_ok('Geo::Coder::Free');
new_ok('Geo::Coder::Free');
plan(tests => 2);
