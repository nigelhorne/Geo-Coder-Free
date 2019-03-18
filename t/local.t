#!perl -wT

use warnings;
use strict;
use Test::Most tests => 10;
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

	TODO: {
		local $TODO = "Can't parse this yet";
		$location = $geo_coder->geocode('St Mary the Virgin Church, Minster, Thanet, Kent, England');
		ok(defined($location));

		$location = $geo_coder->geocode('St Mary the Virgin Church, Church St, Minster, Thanet, Kent, England');
		ok(defined($location));
		# delta_within($location->{latitude}, 39.00, 1e-2);
		# delta_within($location->{longitude}, -77.10, 1e-2);
	}

	$location = $geo_coder->geocode(location => '106, Tothill St, Minster, Thanet, Kent, England');
	ok(defined($location));
	delta_within($location->{latitude}, 51.34, 1e-2);
	delta_within($location->{longitude}, 1.32, 1e-2);
}
