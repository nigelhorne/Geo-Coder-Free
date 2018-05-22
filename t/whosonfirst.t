#!perl -w

use warnings;
use strict;
use Test::Most tests => 21;
use Test::Number::Delta;
use Test::Carp;
use lib 't/lib';
use MyLogger;

BEGIN {
	use_ok('Geo::Coder::Free');
}

WHOSONFIRST: {
	SKIP: {
		if($ENV{'WHOSONFIRST_HOME'} && $ENV{'OPENADDR_HOME'}) {
			diag('This will take some time and memory');

			my $libpostal_is_installed = 0;
			if(eval { require Geo::libpostal; }) {
				$libpostal_is_installed = 1;
			}

			Geo::Coder::Free::DB::init(logger => new_ok('MyLogger'));

			my $geocoder = new_ok('Geo::Coder::Free' => [ openaddr => $ENV{'OPENADDR_HOME'} ]);
			my $location = $geocoder->geocode(location => 'Margate, Kent, England');
			delta_within($location->{latitude}, 51.39, 1e-2);
			delta_within($location->{longitude}, 1.42, 1e-2);
			$location = $geocoder->geocode(location => 'Summerfield Road, Margate, Kent, England');
			delta_within($location->{latitude}, 51.39, 1e-2);
			delta_within($location->{longitude}, 1.42, 1e-2);
			$location = $geocoder->geocode(location => '7 Summerfield Road, Margate, Kent, England');
			delta_within($location->{latitude}, 51.39, 1e-2);
			delta_within($location->{longitude}, 1.42, 1e-2);

			$location = $geocoder->geocode('Silver Diner, 12276 Rockville Pike, Rockville, MD, USA');
			ok(defined($location));
			ok(ref($location) eq 'HASH');
			delta_within($location->{latitude}, 39.06, 1e-2);
			delta_within($location->{longitude}, -77.12, 1e-2);

			$location = $geocoder->geocode('12276 Rockville Pike, Rockville, MD, USA');
			delta_within($location->{latitude}, 39.06, 1e-2);
			delta_within($location->{longitude}, -77.12, 1e-2);

			$location = $geocoder->geocode(location => 'Ramsgate, Kent, England');
			delta_within($location->{latitude}, 51.33, 1e-2);
			delta_within($location->{longitude}, 1.41, 1e-2);

			$location = $geocoder->geocode({ location => 'Silver Diner, Rockville Pike, Rockville, MD, USA' });
			ok(defined($location));
			ok(ref($location) eq 'HASH');
			# FIXME: Stop the different results
			if($libpostal_is_installed) {
				delta_within($location->{latitude}, 39.07, 1e-2);
				delta_within($location->{longitude}, -77.13, 1e-2);
			} else {
				delta_within($location->{latitude}, 39.06, 1e-2);
				delta_within($location->{longitude}, -77.12, 1e-2);
			}
		} else {
			diag('Set WHOSONFIRST_HOME and OPENADDR_HOME to enable whosonfirst.org testing');
			skip 'WHOSONFIRST_HOME and/or OPENADDR_HOME not defined', 20;
		}
	}
}
