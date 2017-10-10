#!perl -w

use warnings;
use strict;
use Test::Most tests => 18;
use Test::Number::Delta;
use Test::Carp;

BEGIN {
	use_ok('Geo::Coder::Free');
}

LOOKUP: {
	diag('This will take some time and consume a lot of memory until the database has been changed from CSV to SQLite');

	my $geocoder = new_ok('Geo::Coder::Free');

	my $location = $geocoder->geocode('Ramsgate, Kent, England');
	ok(defined($location));
	delta_within($location->{latitude}, 51.33, 1e-2);
	delta_within($location->{longitude}, 1.43, 1e-2);

	$location = $geocoder->geocode('Wokingham, Berkshire, England');
	ok(defined($location));
	delta_within($location->{latitude}, 51.42, 1e-2);
	delta_within($location->{longitude}, -0.84, 1e-2);

	$location = $geocoder->geocode('Silver Spring, Maryland, USA');
	ok(defined($location));
	delta_within($location->{latitude}, 38.99, 1e-2);
	delta_within($location->{longitude}, -77.03, 1e-2);

	$location = $geocoder->geocode('Silver Spring, MD, USA');
	ok(defined($location));
	delta_within($location->{latitude}, 38.99, 1e-2);
	delta_within($location->{longitude}, -77.03, 1e-2);

	$location = $geocoder->geocode('St Nicholas-at-Wade, Kent, England');
	ok(defined($location));
	delta_within($location->{latitude}, 51.35, 1e-2);
	delta_within($location->{longitude}, 1.25, 1e-2);

	does_croak(sub { 
		$location = $geocoder->geocode('Minster, Thanet, Kent, England');
	});
}
