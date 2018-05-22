#!perl -w

use warnings;
use strict;
use Test::Most tests => 9;
use Test::Number::Delta;
use Test::Carp;
use lib 't/lib';
use MyLogger;

BEGIN {
	use_ok('Geo::Coder::Free');
}

SCANTEXT: {
	SKIP: {
		if($ENV{'OPENADDR_HOME'}) {
			diag('This will take some time and memory');

			Geo::Coder::Free::DB::init(logger => new_ok('MyLogger'));

			my $geocoder = new_ok('Geo::Coder::Free' => [ openaddr => $ENV{'OPENADDR_HOME'} ]);
			my @locations = $geocoder->geocode(scantext => 'I was born in Ramsgate, Kent, England');
			ok(scalar(@locations) == 1);
			my $location = $locations[0];
			delta_within($location->{latitude}, 51.33, 1e-2);
			delta_within($location->{longitude}, 1.41, 1e-2);
				
			@locations = $geocoder->geocode(scantext => "I was born at St Mary's Hospital in Newark, DE in 1987");
			my $found = 0;
			foreach $location(@locations) {
				if($location->{'city'} ne 'NEWARK') {
					next;
				};
				if($location->{'state'} ne 'DE') {
					next;
				};
				if($location->{'country'} ne 'US') {
					next;
				};
				$found++;
				delta_within($location->{latitude}, 39.68, 1e-2);
				delta_within($location->{longitude}, -75.66, 1e-2);

			}
			ok($found == 1);
		} else {
			diag('Set OPENADDR_HOME to enable openaddresses.io testing');
			skip 'OPENADDR_HOME not defined', 8;
		}
	}
}
