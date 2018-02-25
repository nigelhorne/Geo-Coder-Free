#!perl -w

use warnings;
use strict;
use Test::Most tests => 41;
use Test::Number::Delta;
use Test::Carp;
use lib 't/lib';
use MyLogger;

BEGIN {
	use_ok('Geo::Coder::Free');
}

OPENADDR: {
	SKIP: {
		if($ENV{'OPENADDR_HOME'}) {
			diag('This will take some time and memory');

			Geo::Coder::Free::DB::init(logger => new_ok('MyLogger'));

			my $geocoder = new_ok('Geo::Coder::Free' => [ openaddr => $ENV{'OPENADDR_HOME'} ]);

			my $location = $geocoder->geocode('Indianapolis, Indiana, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 38.62, 1e-2);
			delta_within($location->{longitude}, -87.18, 1e-2);

			$location = $geocoder->geocode(location => 'Edmonton, Alberta, Canada');
			ok(defined($location));
			delta_within($location->{latitude}, 53.55, 1e-2);
			delta_within($location->{longitude}, -113.53, 1e-2);

			TODO: {
				local $TODO = "Don't know how to parse 'London, England'";

				eval {
					$location = $geocoder->geocode('London, England');
					ok(defined($location));
				};
			}

			$location = $geocoder->geocode('Silver Spring, Maryland, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 38.99, 1e-2);
			delta_within($location->{longitude}, -76.99, 1e-2);

			$location = $geocoder->geocode('Silver Spring, MD, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 38.99, 1e-2);
			delta_within($location->{longitude}, -76.99, 1e-2);

			$location = $geocoder->geocode('Silver Spring, Montgomery, MD, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 38.99, 1e-2);
			delta_within($location->{longitude}, -76.99, 1e-2);

			$location = $geocoder->geocode('Silver Spring, Maryland, United States');
			ok(defined($location));
			delta_within($location->{latitude}, 38.99, 1e-2);
			delta_within($location->{longitude}, -76.99, 1e-2);

			$location = $geocoder->geocode('Silver Spring, Montgomery County, Maryland, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 38.99, 1e-2);
			delta_within($location->{longitude}, -76.99, 1e-2);

			$location = $geocoder->geocode('Rockville Pike, Rockville, Montgomery County, MD, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 39.09, 1e-2);
			delta_within($location->{longitude}, -77.15, 1e-2);

			$location = $geocoder->geocode('Rockville Pike, Rockville, MD, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 39.09, 1e-2);
			delta_within($location->{longitude}, -77.15, 1e-2);

			$location = $geocoder->geocode({ location => 'Rockville, Montgomery County, MD, USA' });
			ok(defined($location));
			delta_within($location->{latitude}, 39.08, 1e-2);
			delta_within($location->{longitude}, -77.14, 1e-2);

			$location = $geocoder->geocode(location => 'Rockville, Montgomery County, Maryland, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 39.08, 1e-2);
			delta_within($location->{longitude}, -77.14, 1e-2);

			$location = $geocoder->geocode(location => '1600 Pennsylvania Avenue NW, Washington DC, USA');
			delta_within($location->{latitude}, 38.90, 1e-2);
			delta_within($location->{longitude}, -77.04, 1e-2);

			# my $address = $geocoder->reverse_geocode(latlng => '51.50,-0.13');
			# like($address->{'city'}, qr/^London$/i, 'test reverse');

			does_croak(sub {
				$location = $geocoder->geocode();
			});

			does_croak(sub {
				$location = $geocoder->reverse_geocode();
			});
		} else {
			diag('Set OPENADDR_HOME to enable openaddresses.io testing');
			skip 'OPENADDR_HOME not defined', 40;
		}
	}
}
