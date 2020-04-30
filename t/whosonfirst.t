#!perl -wT

# TODO:  Try using Test::Without::Module to try without Geo::libpostal is that
#	is installed

use warnings;
use strict;
use Test::Most tests => 22;
use Test::Number::Delta;
use Test::Carp;
use Test::Deep;
use lib 't/lib';
use MyLogger;

BEGIN {
	use_ok('Geo::Coder::Free');
}

WHOSONFIRST: {
	SKIP: {
		if($ENV{'WHOSONFIRST_HOME'} && $ENV{'OPENADDR_HOME'}) {
			if($ENV{AUTHOR_TESTING}) {
				diag('This will take some time and memory');

				my $libpostal_is_installed = 0;
				if(eval { require Geo::libpostal; }) {
					$libpostal_is_installed = 1;
				}

				if($ENV{'TEST_VERBOSE'}) {
					Geo::Coder::Free::DB::init(logger => new_ok('MyLogger'));
				}

				my $geocoder = new_ok('Geo::Coder::Free');
				my $location = $geocoder->geocode(location => 'Margate, Kent, England');
				ok(defined($location));
				cmp_deeply($location,
					methods('lat' => num(51.38, 1e-2), 'long' => num(1.39, 1e-2)));

				TODO: {
					local $TODO = 'UK only supports towns and venues';

					$location = $geocoder->geocode(location => 'Summerfield Road, Margate, Kent, England');
					is(ref($location), 'HASH');
					# delta_within($location->{latitude}, 51.38, 1e-2);
					# delta_within($location->{longitude}, 1.36, 1e-2);
					$location = $geocoder->geocode(location => '7 Summerfield Road, Margate, Kent, England');
					is(ref($location), 'HASH');
					# delta_within($location->{latitude}, 51.38, 1e-2);
					# delta_within($location->{longitude}, 1.36, 1e-2);
				}

				$location = $geocoder->geocode('Silver Diner, 12276 Rockville Pike, Rockville, MD, USA');
				ok(defined($location));
				cmp_deeply($location,
					methods('lat' => num(39.06, 1e-2), 'long' => num(-77.12, 1e-2)));

				# https://spelunker.whosonfirst.org/id/772834215/
				$location = $geocoder->geocode('Rock Bottom, Norfolk Ave, Bethesda, MD, USA');
				ok(defined($location));
				cmp_deeply($location,
					methods('lat' => num(38.99, 1e-2), 'long' => num(-77.10, 1e-2)));

				$location = $geocoder->geocode('Rock Bottom, Bethesda, MD, USA');
				cmp_deeply($location,
					methods('lat' => num(38.99, 1e-2), 'long' => num(-77.10, 1e-2)));

				$location = $geocoder->geocode('Rock Bottom Restaurant & Brewery, Norfolk Ave, Bethesda, MD, USA');
				ok(defined($location));
				cmp_deeply($location,
					methods('lat' => num(38.99, 1e-2), 'long' => num(-77.10, 1e-2)));

				$location = $geocoder->geocode('12276 Rockville Pike, Rockville, MD, USA');
				cmp_deeply($location,
					methods('lat' => num(39.06, 1e-2), 'long' => num(-77.12, 1e-2)));

				$location = $geocoder->geocode(location => 'Ramsgate, Kent, England');
				cmp_deeply($location,
					methods('lat' => num(51.34, 1e-2), 'long' => num(1.42, 1e-2)));

				$location = $geocoder->geocode({ location => 'Silver Diner, Rockville Pike, Rockville, MD, USA' });
				if($libpostal_is_installed) {
					cmp_deeply($location,
						methods('lat' => num(39.06, 1e-2), 'long' => num(-77.13, 1e-2)));
				} else {
					cmp_deeply($location,
						methods('lat' => num(39.06, 1e-2), 'long' => num(-77.12, 1e-2)));
				}

				$location = $geocoder->geocode({ location => '106 Tothill St, Minster, Thanet, Kent, England' });
				cmp_deeply($location,
					methods('lat' => num(51.34, 1e-2), 'long' => num(1.32, 1e-2)));

				$location = $geocoder->geocode({ location => 'Minster Cemetery, Tothill St, Minster, Thanet, Kent, England' });
				cmp_deeply($location,
					methods('lat' => num(51.34, 1e-2), 'long' => num(1.32, 1e-2)));

				$location = $geocoder->geocode(location => '13 Ashburnham Road, St Lawrence, Thanet, Kent, England');
				cmp_deeply($location,
					methods('lat' => num(51.34, 1e-2), 'long' => num(1.41, 1e-2)));

				$location = $geocoder->geocode('Wickhambreaux, Kent, England');
				ok(defined($location));
				cmp_deeply($location,
					methods('lat' => num(51.30, 1e-2), 'long' => num(1.19, 1e-2)));

				# diag(Data::Dumper->new([$location])->Dump());
			} else {
				diag('Author tests not required for installation');
				skip('Author tests not required for installation', 21);
			}
		} else {
			diag('Set WHOSONFIRST_HOME and OPENADDR_HOME to enable whosonfirst.org testing');
			skip('WHOSONFIRST_HOME and/or OPENADDR_HOME not defined', 21);
		}
	}
}
