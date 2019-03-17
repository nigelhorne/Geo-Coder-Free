#!perl -wT

use warnings;
use strict;
use Test::Most tests => 5;
use Test::Number::Delta;
use Test::Carp;
use lib 't/lib';
use MyLogger;

BEGIN {
	use_ok('Geo::Coder::Free::Local');
}

LOCAL: {
	my $geo_coder = new_ok('Geo::Coder::Free::Local');

	my $location = $geo_coder->geocode('NCBI, MEDLARS DR, BETHESDA, MONTGOMERY, MD, USA');
	ok(defined($location));
	delta_within($location->{latitude}, 39.00, 1e-2);
	delta_within($location->{longitude}, -77.10, 1e-2);
}
