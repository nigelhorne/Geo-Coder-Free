#!perl -wT

use warnings;
use strict;
use Test::Most tests => 79;
use Test::Number::Delta;
use Test::Carp;
use lib 't/lib';
use MyLogger;

BEGIN {
	use_ok('Geo::Coder::Free');
}

MAXMIND: {
	SKIP: {
		if($ENV{AUTHOR_TESTING}) {
			diag('This may take some time and consume a lot of memory if the database is not SQLite');

			Geo::Coder::Free::DB::init(logger => new_ok('MyLogger'));

			my $geo_coder = new_ok('Geo::Coder::Free::MaxMind');

			my $location = $geo_coder->geocode('Woolwich, London, England');
			ok(defined($location));
			delta_within($location->{latitude}, 51.47, 1e-2);
			delta_within($location->{longitude}, 0.20, 1e-2);

			TODO: {
				local $TODO = "Don't know how to parse 'London, England'";

				eval {
					$location = $geo_coder->geocode('London, England');
					ok(defined($location));
				};
			}

			$location = $geo_coder->geocode('Indianapolis, Indiana, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 39.77, 1e-2);
			delta_within($location->{longitude}, -86.15, 1e-2);

			$location = $geo_coder->geocode('Ramsgate, Kent, England');
			ok(defined($location));
			delta_within($location->{latitude}, 51.33, 1e-2);
			delta_within($location->{longitude}, 1.43, 1e-2);

			$location = $geo_coder->geocode('Wokingham, Berkshire, United Kingdom');
			ok(defined($location));
			delta_within($location->{latitude}, 51.42, 1e-2);
			delta_within($location->{longitude}, -0.83, 1e-2);

			$location = $geo_coder->geocode('Wokingham, Berkshire, UK');
			ok(defined($location));
			delta_within($location->{latitude}, 51.42, 1e-2);
			delta_within($location->{longitude}, -0.83, 1e-2);

			$location = $geo_coder->geocode('Wokingham, Berkshire, GB');
			ok(defined($location));
			delta_within($location->{latitude}, 51.42, 1e-2);
			delta_within($location->{longitude}, -0.83, 1e-2);

			$location = $geo_coder->geocode('Wokingham, Berkshire, England');
			ok(defined($location));
			delta_within($location->{latitude}, 51.42, 1e-2);
			delta_within($location->{longitude}, -0.83, 1e-2);

			# FIXME: This finds the Wokingham in England because of a problem in the unitary city handling
			# which actually looks for Wokingham, GB.

			# $location = $geo_coder->geocode('Wokingham, Berkshire, Scotland');
			# ok(!defined($location));

			$location = $geo_coder->geocode('Minster, Thanet, Kent, England');
			TODO: {
				local $TODO = 'Minster, Thanet not yet supported';

				ok(!defined($location));
			}

			$location = $geo_coder->geocode('Silver Spring, Maryland, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 39.00, 1e-2);
			delta_within($location->{longitude}, -77.03, 1e-2);

			$location = $geo_coder->geocode('Silver Spring, MD, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 39.00, 1e-2);
			delta_within($location->{longitude}, -77.03, 1e-2);

			$location = $geo_coder->geocode('Silver Spring, Montgomery, MD, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 39.00, 1e-2);
			delta_within($location->{longitude}, -77.03, 1e-2);

			$location = $geo_coder->geocode('Silver Spring, Maryland, United States');
			ok(defined($location));
			delta_within($location->{latitude}, 39.00, 1e-2);
			delta_within($location->{longitude}, -77.03, 1e-2);

			$location = $geo_coder->geocode('Silver Spring, Montgomery County, Maryland, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 39.00, 1e-2);
			delta_within($location->{longitude}, -77.03, 1e-2);

			$location = $geo_coder->geocode('Montgomery County, Maryland, USA');
			ok(!defined($location));

			$location = $geo_coder->geocode('St Nicholas-at-Wade, Kent, UK');
			ok(defined($location));
			delta_within($location->{latitude}, 51.35, 1e-2);
			delta_within($location->{longitude}, 1.25, 1e-2);

			$location = $geo_coder->geocode('Rockville Pike, Rockville, Montgomery County, MD, USA');
			TODO: {
				local $TODO = "Don't know how to parse counties in the USA";
				ok(!defined($location));
			}

			# FIXME:  this actually does a look up that fails
			$location = $geo_coder->geocode('Rockville Pike, Rockville, MD, USA');
			ok(!defined($location));

			$location = $geo_coder->geocode({ location => 'Rockville, Montgomery County, MD, USA' });
			ok(defined($location));
			delta_within($location->{latitude}, 39.08, 1e-2);
			delta_within($location->{longitude}, -77.15, 1e-2);

			$location = $geo_coder->geocode(location => 'Rockville, Montgomery County, Maryland, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 39.08, 1e-2);
			delta_within($location->{longitude}, -77.15, 1e-2);

			$location = $geo_coder->geocode(location => 'Temple Ewell, Kent, England');
			ok(defined($location));
			delta_within($location->{latitude}, 51.15, 1e-2);
			delta_within($location->{longitude}, 1.27, 1e-2);

			$location = $geo_coder->geocode(location => 'Edmonton, Alberta, Canada');
			ok(defined($location));
			delta_within($location->{latitude}, 53.55, 1e-2);
			delta_within($location->{longitude}, -113.50, 1e-2);

			my @locations = $geo_coder->geocode(location => 'Temple Ewell, Kent, England');
			ok(defined($locations[0]));
			delta_within($locations[0]->{latitude}, 51.15, 1e-2);
			delta_within($locations[0]->{longitude}, 1.27, 1e-2);

			$location = $geo_coder->geocode(location => 'Newport Pagnell, Buckinghamshire, England');
			ok(defined($location));
			delta_within($location->{latitude}, 52.08, 1e-2);
			delta_within($location->{longitude}, -0.72, 1e-2);

			$location = $geo_coder->geocode('Thanet, Kent, England');
			ok(defined($location));

			$location = $geo_coder->geocode('Kent, England');
			ok(defined($location));
			delta_within($location->{latitude}, 51.25, 1e-2);
			delta_within($location->{longitude}, 0.75, 1e-2);

			$location = $geo_coder->geocode('Maryland, USA');
			ok(defined($location));
			delta_within($location->{latitude}, 38.25, 1e-2);
			delta_within($location->{longitude}, -76.74, 1e-2);

			$location = $geo_coder->geocode('Nebraska, USA');
			ok(defined($location));

			$location = $geo_coder->geocode('New Brunswick, Canada');
			ok(defined($location));
			delta_within($location->{latitude}, 39.95, 1e-2);
			delta_within($location->{longitude}, -86.52, 1e-2);

			$location = $geo_coder->geocode('Vessels, Misc Ships At sea or abroad, England');
			ok(!defined($location));

			# my $address = $geo_coder->reverse_geocode(latlng => '51.50,-0.13');
			# like($address->{'city'}, qr/^London$/i, 'test reverse');

			does_croak(sub {
				$location = $geo_coder->geocode();
			});

			does_croak(sub {
				$location = $geo_coder->reverse_geocode();
			});
		} else {
			diag('Author tests not required for installation');
			skip('Author tests not required for installation', 78);
		}
	}
}
