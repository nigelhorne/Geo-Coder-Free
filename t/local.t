#!perl -wT

use warnings;
use strict;
use Test::Most tests => 73;
use Test::Number::Delta;
use Test::Carp;
use Test::Deep;
use lib 't/lib';
use MyLogger;
# use Test::Without::Module qw(Geo::libpostal);

BEGIN {
	use_ok('Geo::Coder::Free::Local');
}

LOCAL: {
	my $geo_coder = new_ok('Geo::Coder::Free::Local');

	cmp_deeply($geo_coder->geocode('NCBI, MEDLARS DR, BETHESDA, MONTGOMERY, MD, USA'),
		methods('lat' => num(39.00, 1e-2), 'long' => num(-77.10, 1e-2)));

	like($geo_coder->reverse_geocode('39,-77.10'), qr/Bethesda/i, 'test reverse_geocode');

	my $libpostal_is_installed = 0;
	if(eval { require Geo::libpostal; }) {
		$libpostal_is_installed = 1;
	}

	if($libpostal_is_installed) {
		cmp_deeply($geo_coder->geocode(location => 'NCBI, Bethesda, Maryland, USA'),
			methods('lat' => num(39.00, 1e-2), 'long' => num(-77.10, 1e-2)));
	} else {
		cmp_deeply($geo_coder->geocode('NCBI, MEDLARS DR, BETHESDA, MONTGOMERY, MD, USA'),
			methods('lat' => num(39.00, 1e-2), 'long' => num(-77.10, 1e-2)));
	}

	check($geo_coder,
		'NCBI, MEDLARS DR, BETHESDA, MONTGOMERY, MD, USA',
		38.99516556,
		-77.09943963
	);

	TODO: {
		local $TODO = "Can't parse this yet";
		my $location = $geo_coder->geocode('St Mary the Virgin Church, Minster, Thanet, Kent, England');
		ok(defined($location));

		$location = $geo_coder->geocode('St Mary the Virgin Church, Church St, Minster, Thanet, Kent, England');
		ok(defined($location));
		# delta_within($location->{latitude}, 39.00, 1e-2);
		# delta_within($location->{longitude}, -77.10, 1e-2);
	}

	check($geo_coder,
		'Minster Cemetery, 116 Tothill Street, Minster, Thanet, Kent, England',
		51.34203083,
		1.31609075,
		'Minster Cemetery, 116 Tothill St, Minster, Thanet, Kent, GB',
	);

	check($geo_coder,
		'Minster Cemetery, Tothill Street, Minster, Thanet, Kent, England',
		51.34203083,
		1.31609075,
		'Minster Cemetery, 116 Tothill St, Minster, Thanet, Kent, GB',
	);

	check($geo_coder,
		'106 Tothill St, Ramsgate, Kent, GB',
		51.33995174,
		1.31570211
	);

	cmp_deeply($geo_coder->geocode(location => '106 Tothill St, Minster, Thanet, Kent, England'),
		methods('lat' => num(51.34, 1e-2), 'long' => num(1.32, 1e-2)));

	eval 'use Test::Memory::Cycle';
	if($@) {
		skip('Test::Memory::Cycle required to check for cicular memory references', 1);
	} else {
		memory_cycle_ok($geo_coder);
	}
}

sub check {
	my ($geo_coder, $location, $lat, $long, $expect) = @_;

	$location = uc($location);
	if(defined($expect)) {
		$expect = uc($expect);
	} else {
		$expect = $location;
	}
	if($location =~ /(.+)\s+STREET,\s+(.+)/) {
		$location = "$1 ST, $2";
	}
	# diag($location);
	my @rc = $geo_coder->geocode({ location => $location });
	# diag(Data::Dumper->new([\@rc])->Dump());
	ok(scalar(@rc) > 0);
	cmp_deeply(@rc,
		methods('lat' => num($lat, 1e-2), 'long' => num($long, 1e-2)));

	@rc = $geo_coder->geocode(location => $location);
	ok(scalar(@rc) > 0);
	cmp_deeply(@rc,
		methods('lat' => num($lat, 1e-2), 'long' => num($long, 1e-2)));

	@rc = $geo_coder->geocode($location);
	ok(scalar(@rc) > 0);
	cmp_deeply(@rc,
		methods('lat' => num($lat, 1e-2), 'long' => num($long, 1e-2)));

	@rc = $geo_coder->reverse_geocode(lat => $lat, long => $long);
	ok(scalar(@rc) > 0);
	my $found;

	if($expect =~ /(.+),\s+USA$/) {
		$expect = "$1, US";
	}

	foreach my $loc(@rc) {
		# diag(uc($loc), '<->', $expect);
		if(uc($loc) eq $expect) {
			# diag("match: $expect");
			$found = 1;
			last;
		}
	}

	if(!$found) {
		diag(__LINE__, ": failed reverse lookup $expect");
		diag(Data::Dumper->new([\@rc])->Dump());
	}
	ok($found);

	@rc = $geo_coder->reverse_geocode({ lat => $lat, long => $long });
	ok(scalar(@rc) > 0);
	$found = 0;

	foreach my $loc(@rc) {
		if(uc($loc) eq $expect) {
			$found = 1;
			last;
		}
	}

	if(!$found) {
		diag(__LINE__, ": failed reverse lookup $expect");
		diag(Data::Dumper->new([\@rc])->Dump());
	}
	ok($found);

	@rc = $geo_coder->reverse_geocode(latlng => "$lat,$long");
	ok(scalar(@rc) > 0);
	$found = 0;

	foreach my $loc(@rc) {
		if(uc($loc) eq $expect) {
			$found = 1;
			last;
		}
	}

	if(!$found) {
		diag(__LINE__, ": failed reverse lookup $expect");
		diag(Data::Dumper->new([\@rc])->Dump());
	}
	ok($found);

	@rc = $geo_coder->reverse_geocode({ latlng => "$lat,$long" });
	ok(scalar(@rc) > 0);
	$found = 0;

	foreach my $loc(@rc) {
		if(uc($loc) eq $expect) {
			$found = 1;
			last;
		}
	}

	if(!$found) {
		diag(__LINE__, ": failed reverse lookup $expect");
		diag(Data::Dumper->new([\@rc])->Dump());
	}
	ok($found);

	@rc = $geo_coder->reverse_geocode("$lat,$long");
	ok(scalar(@rc) > 0);
	$found = 0;

	foreach my $loc(@rc) {
		if(uc($loc) eq $expect) {
			$found = 1;
			last;
		}
	}

	if(!$found) {
		diag(__LINE__, ": failed reverse lookup $expect");
		diag(Data::Dumper->new([\@rc])->Dump());
	}
	ok($found);
}
