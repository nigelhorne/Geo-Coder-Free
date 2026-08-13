#!/usr/bin/env perl

# Black-box unit tests for the public API of all Geo::Coder::Free modules.
# Tests are driven strictly by the API contracts documented in each module's POD.
# External dependencies (MaxMind DB, OA SQLite) are mocked so the suite runs
# without any downloaded databases and regardless of OPENADDR_HOME being set.

use strict;
use warnings;

use File::Temp qw(tempdir);
use Readonly;
use Scalar::Util qw(blessed refaddr);
use Test::Most;
use Test::Mockingbird qw(mock restore_all);
use Test::Returns;

use lib 'lib';

BEGIN {
	use_ok('Geo::Coder::Free')               or BAIL_OUT('Geo::Coder::Free failed to load');
	use_ok('Geo::Coder::Free::Local')        or BAIL_OUT('Geo::Coder::Free::Local failed to load');
	use_ok('Geo::Coder::Free::OpenAddresses') or BAIL_OUT('Geo::Coder::Free::OpenAddresses failed to load');
	use_ok('Geo::Coder::Free::Utils')        or BAIL_OUT('Geo::Coder::Free::Utils failed to load');
	use_ok('Geo::Location::Point')           or BAIL_OUT('Geo::Location::Point failed to load');
}

# ---------------------------------------------------------------------------
# Suppress environment variables that auto-configure backends, making all
# Geo::Coder::Free->new() calls without an explicit 'openaddr' parameter
# create objects backed only by the bundled MaxMind data (which we mock below).
# This keeps tests deterministic across developer machines and CI environments.
# ---------------------------------------------------------------------------
local $ENV{OPENADDR_HOME}    = '';
local $ENV{WHOSONFIRST_HOME} = '';

# ---------------------------------------------------------------------------
# Named constants — eliminate magic values from test assertions.
# ---------------------------------------------------------------------------

Readonly::Scalar my $GCF_PKG   => 'Geo::Coder::Free';
Readonly::Scalar my $LOCAL_PKG => 'Geo::Coder::Free::Local';
Readonly::Scalar my $OA_PKG    => 'Geo::Coder::Free::OpenAddresses';

# An address present in Local.pm's __DATA__ section; used for geocode hit tests.
Readonly::Scalar my $LOCAL_ADDR => 'St andrews church, Church Hill, Earls Colne, Essex, GB';
Readonly::Scalar my $LOCAL_LAT  => '51.926793';
Readonly::Scalar my $LOCAL_LON  => '0.70408';

# US address present in Local __DATA__; used to verify "USA" -> "US" normalisation.
Readonly::Scalar my $US_ADDR_US  => '5350 Chillum Pl NE, Washington, DC, US';
Readonly::Scalar my $US_ADDR_USA => '5350 Chillum Pl NE, Washington, DC, USA';
Readonly::Scalar my $US_ADDR_LAT => '38.955403';

# A hard-coded OA known_location entry — returns a GLP without any DB access.
Readonly::Scalar my $OA_KNOWN_ADDR => 'Newport Pagnell, Buckinghamshire, England';
Readonly::Scalar my $OA_KNOWN_LAT  => '52.08675';

# Coordinates used for the mocked MaxMind / OA responses.
Readonly::Scalar my $MOCK_LAT => 51.3341;
Readonly::Scalar my $MOCK_LON => -1.4159;

# Great-circle distances NYC -> LA (computed by the Haversine implementation).
Readonly::Scalar my $NYC_LAT     => 40.7128;
Readonly::Scalar my $NYC_LON     => -74.0060;
Readonly::Scalar my $LA_LAT      => 34.0522;
Readonly::Scalar my $LA_LON      => -118.2437;
Readonly::Scalar my $NYC_LA_MI   => 2446;   # statute miles
Readonly::Scalar my $NYC_LA_KM   => 3936;   # kilometres
Readonly::Scalar my $NYC_LA_NM   => 2125;   # nautical miles
Readonly::Scalar my $DIST_TOL_MI => 5;
Readonly::Scalar my $DIST_TOL_KM => 10;
Readonly::Scalar my $DIST_TOL_NM => 5;

# ---------------------------------------------------------------------------
# API LEDGER — every documented message and return state must be exercised.
# Each subtest deletes its key when triggered. Any remaining keys at the end
# cause an explicit fail(), proving no documented state went untested.
# ---------------------------------------------------------------------------

my %LEDGER = (
	# Geo::Coder::Free::new
	'GCF::new returns object'        => 1,
	'GCF::new with cache'            => 1,
	'GCF::new clones object'         => 1,
	'GCF::new function-call carp'    => 1,

	# Geo::Coder::Free::geocode
	'GCF::geocode returns GLP'       => 1,
	'GCF::geocode returns undef'     => 1,
	'GCF::geocode invalid_location'  => 1,
	'GCF::geocode invalid_scantext'  => 1,
	'GCF::geocode usage_geocode'     => 1,
	'GCF::geocode bare string'       => 1,
	'GCF::geocode hashref'           => 1,

	# Geo::Coder::Free::reverse_geocode
	'GCF::reverse_geocode usage_reverse'  => 1,
	'GCF::reverse_geocode unsupported'    => 1,
	'GCF::reverse_geocode with latlng'    => 1,

	# Geo::Coder::Free::ua
	'GCF::ua returns undef'          => 1,

	# Geo::Coder::Free::Local::new
	'Local::new returns object'      => 1,
	'Local::new loads data rows'     => 1,
	'Local::new builds index'        => 1,

	# Geo::Coder::Free::Local::geocode
	'Local::geocode returns GLP'          => 1,
	'Local::geocode one-comma rejected'   => 1,
	'Local::geocode no-location croak'    => 1,
	'Local::geocode arrayref croak'       => 1,
	'Local::geocode bare string'          => 1,
	'Local::geocode USA normalisation'    => 1,

	# Geo::Coder::Free::Local::reverse_geocode
	'Local::reverse_geocode latlng'         => 1,
	'Local::reverse_geocode lat+long'       => 1,
	'Local::reverse_geocode scalar ctx'     => 1,
	'Local::reverse_geocode list ctx'       => 1,
	'Local::reverse_geocode no-coord croak' => 1,

	# Geo::Coder::Free::Local::ua
	'Local::ua returns undef'        => 1,

	# Geo::Coder::Free::OpenAddresses::new
	'OA::new no-openaddr croak'      => 1,
	'OA::new bad-path croak'         => 1,
	'OA::new returns object'         => 1,

	# Geo::Coder::Free::OpenAddresses::geocode
	'OA::geocode known_location hit'      => 1,
	'OA::geocode numeric returns undef'   => 1,
	'OA::geocode too-short returns undef' => 1,

	# Geo::Coder::Free::OpenAddresses::ua
	'OA::ua returns undef'           => 1,

	# Geo::Coder::Free::Utils::distance
	'Utils::distance same point'     => 1,
	'Utils::distance miles'          => 1,
	'Utils::distance km'             => 1,
	'Utils::distance NM'             => 1,
	'Utils::distance undef lat'      => 1,
	'Utils::distance non-numeric'    => 1,
	'Utils::distance lat > 90'       => 1,
	'Utils::distance lat < -90'      => 1,
	'Utils::distance lon > 180'      => 1,
	'Utils::distance invalid unit'   => 1,

	# Geo::Coder::Free::Utils::create_disc_cache
	'Utils::disc_cache valid'        => 1,
	'Utils::disc_cache no config'    => 1,

	# Geo::Coder::Free::Utils::create_memory_cache
	'Utils::mem_cache valid'         => 1,
	'Utils::mem_cache no config'     => 1,
);

# ---------------------------------------------------------------------------
# Shared mock point — a valid Geo::Location::Point for backend responses.
# ---------------------------------------------------------------------------

my $MOCK_PT = Geo::Location::Point->new({ lat => $MOCK_LAT, long => $MOCK_LON });

# This scalar is set per-test to control what the mocked MaxMind backend returns.
my $mock_mm_result;

# Mock the MaxMind backend so no database files are required.
mock('Geo::Coder::Free::MaxMind', 'geocode',
	sub { return $mock_mm_result });
mock('Geo::Coder::Free::MaxMind', 'reverse_geocode',
	sub { return $mock_mm_result });

# Note: Geo::Coder::Free::OpenAddresses is NOT mocked globally.
# With OPENADDR_HOME suppressed, the GCF facade never creates an OA backend,
# so OA::geocode is never called through the facade.  The OA-specific subtests
# below call $oa->geocode(...) directly on a tempdir-backed instance, and the
# real OA code handles early-return paths (known_locations, numeric check,
# short-scantext check) without touching any SQLite database.

# ---------------------------------------------------------------------------
# SECTION 1: Geo::Coder::Free (the facade)
# ---------------------------------------------------------------------------

subtest 'GCF::new — constructor' => sub {
	my $geo = new_ok('Geo::Coder::Free');
	isa_ok($geo, 'Geo::Coder::Free', 'new() returns Geo::Coder::Free object');
	returns_ok($geo, { type => 'object', isa => 'Geo::Coder::Free' }, 'new() return schema');
	delete $LEDGER{'GCF::new returns object'};

	# The cache parameter must be stored and accessible on the returned object.
	{
		package FakeCache;
		sub new { bless {}, shift }
		sub get { }
		sub set { }
	}
	my $cache = FakeCache->new();
	my $geo_cached = Geo::Coder::Free->new(cache => $cache);
	is(refaddr($geo_cached->{'cache'}), refaddr($cache),
		'new(cache => ...) stores the cache object');
	delete $LEDGER{'GCF::new with cache'};

	# Clone path: when new() is called as an instance method on an existing
	# blessed object, it returns a shallow copy with a distinct identity.
	my $clone = $geo->new();
	isa_ok($clone, 'Geo::Coder::Free', 'clone is a Geo::Coder::Free');
	isnt(refaddr($clone), refaddr($geo), 'clone is a distinct reference');
	delete $LEDGER{'GCF::new clones object'};

	# Function-call path: calling new() as a plain function with a leading
	# undef "class" argument and keyword args triggers the usage carp.
	my $warned = 0;
	local $SIG{__WARN__} = sub { $warned = 1 if $_[0] =~ /use ->new\(\)/i };
	my $bad = Geo::Coder::Free::new(undef, openaddr => '/tmp');
	ok(!defined($bad), 'function-form new with args returns undef');
	ok($warned,         'function-form new with args carps usage message');
	delete $LEDGER{'GCF::new function-call carp'};
};

subtest 'GCF::geocode — standard and invalid inputs' => sub {
	my $geo = Geo::Coder::Free->new();

	# Normal location lookup: MaxMind (mocked) returns the mock point.
	$mock_mm_result = $MOCK_PT;
	my $result = $geo->geocode(location => 'Ramsgate, Kent, UK');
	isa_ok($result, 'Geo::Location::Point', 'geocode(location => ...) returns GLP');
	ok(abs($result->lat()  - $MOCK_LAT) < 0.001, 'latitude matches mock');
	ok(abs($result->long() - $MOCK_LON) < 0.001, 'longitude matches mock');
	returns_ok($result, { type => 'object', isa => 'Geo::Location::Point' },
		'geocode return schema');
	delete $LEDGER{'GCF::geocode returns GLP'};

	# When no backend returns a result, geocode returns undef.
	$mock_mm_result = undef;
	my $miss = $geo->geocode(location => 'Nowhere, Imaginary, ZZ');
	ok(!defined($miss), 'geocode returns undef for unknown location');
	delete $LEDGER{'GCF::geocode returns undef'};

	# A purely numeric location string is invalid and must croak.
	throws_ok { $geo->geocode(location => '12345') }
		qr/invalid location to geocode/,
		'purely numeric location croaks invalid_location';
	delete $LEDGER{'GCF::geocode invalid_location'};

	# A purely numeric scantext string is equally invalid.
	throws_ok { $geo->geocode(scantext => '9999') }
		qr/invalid scantext to geocode/,
		'purely numeric scantext croaks invalid_scantext';
	delete $LEDGER{'GCF::geocode invalid_scantext'};

	# Calling geocode() with no arguments at all must croak with the usage message.
	throws_ok { $geo->geocode() }
		qr/Usage:.*geocode/,
		'geocode() with no args croaks usage message';
	delete $LEDGER{'GCF::geocode usage_geocode'};

	# POD documents that all three calling forms are equivalent.
	$mock_mm_result = $MOCK_PT;
	my $bare = $geo->geocode('Ramsgate, Kent, UK');
	isa_ok($bare, 'Geo::Location::Point', 'bare string geocode returns GLP');
	delete $LEDGER{'GCF::geocode bare string'};

	my $href = $geo->geocode({ location => 'Ramsgate, Kent, UK' });
	isa_ok($href, 'Geo::Location::Point', 'hashref geocode returns GLP');
	delete $LEDGER{'GCF::geocode hashref'};

	diag 'GCF::geocode: all standard paths exercised' if $ENV{TEST_VERBOSE};
};

subtest 'GCF::reverse_geocode — error states and delegation' => sub {
	my $geo = Geo::Coder::Free->new();   # no openaddr (OPENADDR_HOME suppressed)

	# Calling as an undefined self triggers the usage croak immediately.
	throws_ok { Geo::Coder::Free::reverse_geocode(undef) }
		qr/Usage:.*reverse_geocode/,
		'undef self croaks usage_reverse';
	delete $LEDGER{'GCF::reverse_geocode usage_reverse'};

	# Without openaddr and without a latlng argument the "not yet supported" croak fires.
	# OPENADDR_HOME is suppressed so $geo has no OA backend.
	throws_ok { $geo->reverse_geocode() }
		qr/not yet supported/i,
		'no openaddr + no latlng croaks reverse_unsupported';
	delete $LEDGER{'GCF::reverse_geocode unsupported'};

	# When latlng is provided, the call is delegated to MaxMind (mocked here).
	$mock_mm_result = $MOCK_PT;
	my $r = $geo->reverse_geocode(latlng => "$MOCK_LAT,$MOCK_LON");
	isa_ok($r, 'Geo::Location::Point', 'reverse_geocode with latlng returns GLP');
	delete $LEDGER{'GCF::reverse_geocode with latlng'};
};

subtest 'GCF::ua — compatibility stub' => sub {
	my $geo = Geo::Coder::Free->new();
	# POD: "Does nothing.  Present for drop-in compatibility."
	my $ret = $geo->ua();
	ok(!defined($ret), 'ua() returns undef');
	delete $LEDGER{'GCF::ua returns undef'};
};

# ---------------------------------------------------------------------------
# SECTION 2: Geo::Coder::Free::Local
# ---------------------------------------------------------------------------
#
# IMPORTANT: Geo::Coder::Free::Local reads its data from <DATA> — a Perl
# per-module filehandle that can only be read once.  Creating a second
# instance via Local->new() would produce an empty object because the
# filehandle is at EOF after the first read.  For this reason a single
# $LOCAL_OBJ is constructed here at module scope and shared across all
# Local subtests.
#
my $LOCAL_OBJ = Geo::Coder::Free::Local->new();

subtest 'Local::new — construction and index build' => sub {
	isa_ok($LOCAL_OBJ, 'Geo::Coder::Free::Local', 'new() returns Local object');
	delete $LEDGER{'Local::new returns object'};

	# The module reads its __DATA__ section; at least one row must be loaded.
	ok(scalar @{$LOCAL_OBJ->{'data'}} > 0, 'data array is populated from __DATA__');
	diag 'Local data rows: ' . scalar @{$LOCAL_OBJ->{'data'}} if $ENV{TEST_VERBOSE};
	delete $LEDGER{'Local::new loads data rows'};

	# The hash index must have one key per data row for O(1) exact lookups.
	is(scalar keys %{$LOCAL_OBJ->{'index'}},
	   scalar @{$LOCAL_OBJ->{'data'}},
	   'index has one entry per data row');
	delete $LEDGER{'Local::new builds index'};
};

subtest 'Local::geocode — valid and invalid inputs' => sub {
	my $local = $LOCAL_OBJ;

	# A full address present in the bundled __DATA__ block must be found.
	my $pt = $local->geocode(location => $LOCAL_ADDR);
	isa_ok($pt, 'Geo::Location::Point', 'geocode() returns GLP for known address');
	is($pt->lat(), $LOCAL_LAT, 'latitude matches known value');
	delete $LEDGER{'Local::geocode returns GLP'};

	# An address with only one comma has insufficient components and is rejected.
	my $short = $local->geocode(location => 'Ramsgate, Kent');
	ok(!defined($short), 'address with one comma returns undef');
	delete $LEDGER{'Local::geocode one-comma rejected'};

	# Calling geocode() with no args must croak with the short usage message.
	throws_ok { $local->geocode() }
		qr/Usage:.*geocode/,
		'geocode() with no location croaks';
	delete $LEDGER{'Local::geocode no-location croak'};

	# Passing a non-hash reference triggers the full-form usage croak.
	throws_ok { $local->geocode([]) }
		qr/Geo::Coder::Free::Local::geocode/,
		'geocode([]) with arrayref croaks full usage message';
	delete $LEDGER{'Local::geocode arrayref croak'};

	# Bare string calling convention — POD shows all three forms are supported.
	my $bare = $local->geocode($LOCAL_ADDR);
	isa_ok($bare, 'Geo::Location::Point', 'bare-string geocode returns GLP');
	delete $LEDGER{'Local::geocode bare string'};

	# "USA" must be normalised to "US" before the index lookup so that
	# "..., US" and "..., USA" both resolve to the same record.
	my $us  = $local->geocode(location => $US_ADDR_US);
	my $usa = $local->geocode(location => $US_ADDR_USA);
	ok(defined($us)  && $us->lat()  eq $US_ADDR_LAT, '"US" address found');
	ok(defined($usa) && $usa->lat() eq $US_ADDR_LAT, '"USA" normalised and found');
	delete $LEDGER{'Local::geocode USA normalisation'};

	diag 'Local::geocode: all paths exercised' if $ENV{TEST_VERBOSE};
};

subtest 'Local::reverse_geocode — all argument forms and contexts' => sub {
	my $local = $LOCAL_OBJ;

	# latlng form: "$lat,$lon" comma-separated string.
	my $r_latlng = $local->reverse_geocode(latlng => "$LOCAL_LAT,$LOCAL_LON");
	ok(defined($r_latlng), 'reverse_geocode(latlng => ...) returns a result');
	delete $LEDGER{'Local::reverse_geocode latlng'};

	# Separate lat / long parameters must also work (long is the alias for lon).
	my $r_latlong = $local->reverse_geocode(lat => $LOCAL_LAT, long => $LOCAL_LON);
	ok(defined($r_latlong), 'reverse_geocode(lat => ..., long => ...) returns a result');
	delete $LEDGER{'Local::reverse_geocode lat+long'};

	# In scalar context the method returns one location string.
	my $scalar = $local->reverse_geocode(latlng => "$LOCAL_LAT,$LOCAL_LON");
	ok(!ref($scalar), 'scalar context returns a plain string');
	delete $LEDGER{'Local::reverse_geocode scalar ctx'};

	# In list context the method may return multiple strings.
	my @list = $local->reverse_geocode(latlng => "$LOCAL_LAT,$LOCAL_LON");
	ok(@list >= 1, 'list context returns at least one string');
	delete $LEDGER{'Local::reverse_geocode list ctx'};

	# Neither latlng nor lat/lon must croak with the full usage message.
	throws_ok { $local->reverse_geocode() }
		qr/Usage:.*reverse_geocode/,
		'reverse_geocode() with no coords croaks';
	delete $LEDGER{'Local::reverse_geocode no-coord croak'};
};

subtest 'Local::ua — compatibility stub' => sub {
	my $ret = $LOCAL_OBJ->ua();
	ok(!defined($ret), 'ua() returns undef');
	delete $LEDGER{'Local::ua returns undef'};
};

# ---------------------------------------------------------------------------
# SECTION 3: Geo::Coder::Free::OpenAddresses
# ---------------------------------------------------------------------------

subtest 'OA::new — argument validation' => sub {
	# Without the required openaddr parameter the constructor must croak.
	throws_ok { Geo::Coder::Free::OpenAddresses->new() }
		qr/Usage: new\(openaddr/,
		'new() without openaddr croaks usage message';
	delete $LEDGER{'OA::new no-openaddr croak'};

	# A non-existent directory must also croak immediately.
	throws_ok { Geo::Coder::Free::OpenAddresses->new(openaddr => '/no/such/path') }
		qr/Can't find the directory/,
		'new() with nonexistent path croaks';
	delete $LEDGER{'OA::new bad-path croak'};

	# A real, readable directory succeeds — no database file is opened at new() time.
	my $tmpdir = tempdir(CLEANUP => 1);
	my $oa = Geo::Coder::Free::OpenAddresses->new(openaddr => $tmpdir);
	isa_ok($oa, 'Geo::Coder::Free::OpenAddresses',
		'new(openaddr => $valid_dir) returns object');
	delete $LEDGER{'OA::new returns object'};
};

subtest 'OA::geocode — early-return paths (no DB required)' => sub {
	# These tests exercise code paths that return before touching the SQLite DB.
	my $tmpdir = tempdir(CLEANUP => 1);
	my $oa = Geo::Coder::Free::OpenAddresses->new(openaddr => $tmpdir);

	# The module hard-codes a %known_locations table; matching entries are
	# returned as Geo::Location::Point objects without any DB lookup.
	my $known = $oa->geocode(location => $OA_KNOWN_ADDR);
	isa_ok($known, 'Geo::Location::Point', 'known_location returns GLP without DB');
	ok(abs($known->lat() - $OA_KNOWN_LAT) < 0.001, 'latitude matches known value');
	delete $LEDGER{'OA::geocode known_location hit'};

	# A purely numeric location is rejected before any DB access.
	my $numeric = $oa->geocode(location => '12345');
	ok(!defined($numeric), 'purely numeric location returns undef');
	delete $LEDGER{'OA::geocode numeric returns undef'};

	# A scantext shorter than 6 characters is rejected immediately (hardcoded guard).
	my $short = $oa->geocode(scantext => 'hi');
	ok(!defined($short), 'scantext shorter than 6 chars returns undef');
	delete $LEDGER{'OA::geocode too-short returns undef'};

	diag 'OA::geocode: early-return paths exercised' if $ENV{TEST_VERBOSE};
};

subtest 'OA::ua — compatibility stub' => sub {
	my $tmpdir = tempdir(CLEANUP => 1);
	my $oa = Geo::Coder::Free::OpenAddresses->new(openaddr => $tmpdir);
	my $ret = $oa->ua();
	ok(!defined($ret), 'ua() returns undef');
	delete $LEDGER{'OA::ua returns undef'};
};

# ---------------------------------------------------------------------------
# SECTION 4: Geo::Coder::Free::Utils (exported functions)
# ---------------------------------------------------------------------------

# Import after the rest of the test is set up to avoid namespace collisions.
Geo::Coder::Free::Utils->import(qw(distance create_disc_cache create_memory_cache));

subtest 'Utils::distance — valid distances and unit conversion' => sub {
	# Identical coordinates must yield zero distance by definition.
	is(distance($NYC_LAT, $NYC_LON, $NYC_LAT, $NYC_LON), 0,
		'distance to self is 0');
	delete $LEDGER{'Utils::distance same point'};

	# NYC -> LA in statute miles (default unit 'M').
	my $miles = distance($NYC_LAT, $NYC_LON, $LA_LAT, $LA_LON, 'M');
	ok(abs($miles - $NYC_LA_MI) <= $DIST_TOL_MI,
		"NYC->LA ~$NYC_LA_MI miles (got $miles)");
	delete $LEDGER{'Utils::distance miles'};

	# NYC -> LA in kilometres.
	my $km = distance($NYC_LAT, $NYC_LON, $LA_LAT, $LA_LON, 'K');
	ok(abs($km - $NYC_LA_KM) <= $DIST_TOL_KM,
		"NYC->LA ~$NYC_LA_KM km (got $km)");
	delete $LEDGER{'Utils::distance km'};

	# NYC -> LA in nautical miles.
	my $nm = distance($NYC_LAT, $NYC_LON, $LA_LAT, $LA_LON, 'N');
	ok(abs($nm - $NYC_LA_NM) <= $DIST_TOL_NM,
		"NYC->LA ~$NYC_LA_NM NM (got $nm)");
	delete $LEDGER{'Utils::distance NM'};

	diag "Distances — miles=$miles km=$km NM=$nm" if $ENV{TEST_VERBOSE};
};

subtest 'Utils::distance — invalid input croaks' => sub {
	# Each undefined coordinate must be caught before any calculation begins.
	throws_ok { distance(undef, 0, 0, 0) }
		qr/lat1 must be defined/,
		'undef lat1 croaks';
	delete $LEDGER{'Utils::distance undef lat'};

	# A non-numeric coordinate string is not acceptable.
	throws_ok { distance('abc', 0, 0, 0) }
		qr/lat1 must be numeric/,
		'non-numeric lat1 croaks';
	delete $LEDGER{'Utils::distance non-numeric'};

	# Latitude is only valid in the range [-90, 90].
	throws_ok { distance(91, 0, 0, 0) }
		qr/Latitude must be between -90 and 90/,
		'lat1 = 91 croaks';
	delete $LEDGER{'Utils::distance lat > 90'};

	throws_ok { distance(-91, 0, 0, 0) }
		qr/Latitude must be between -90 and 90/,
		'lat1 = -91 croaks';
	delete $LEDGER{'Utils::distance lat < -90'};

	# Longitude is only valid in the range [-180, 180].
	throws_ok { distance(0, 181, 0, 0) }
		qr/Longitude must be between -180 and 180/,
		'lon1 = 181 croaks';
	delete $LEDGER{'Utils::distance lon > 180'};

	# An unrecognised unit string must croak with the unit name in the message.
	# NOTE: distance(0,0,0,0,'X') returns 0 early (same point) before unit validation;
	# we must pass distinct coordinates so the unit-check code path is reached.
	throws_ok { distance(0, 0, 1, 1, 'X') }
		qr/Unknown unit 'X'/,
		"unit 'X' croaks";
	delete $LEDGER{'Utils::distance invalid unit'};
};

subtest 'Utils::create_disc_cache — CHI disc cache' => sub {
	my $tmpdir = tempdir(CLEANUP => 1);

	my $valid_config = {
		disc_cache => { driver => 'File', root_dir => $tmpdir }
	};

	# A valid configuration must return a CHI-family object.
	my $cache = create_disc_cache({ config => $valid_config, namespace => 'unit_test' });
	ok(defined($cache), 'create_disc_cache with valid config returns object');
	like(ref($cache), qr/^CHI/, 'returned object is a CHI instance');
	delete $LEDGER{'Utils::disc_cache valid'};

	# A missing config key must croak (Error::Simple thrown by _create_cache).
	throws_ok { create_disc_cache({}) }
		qr/config is not optional/,
		'create_disc_cache without config croaks';
	delete $LEDGER{'Utils::disc_cache no config'};
};

subtest 'Utils::create_memory_cache — CHI memory cache' => sub {
	my $valid_config = {
		memory_cache => { driver => 'Null' }
	};

	my $cache = create_memory_cache({ config => $valid_config, namespace => 'unit_test' });
	ok(defined($cache), 'create_memory_cache with valid config returns object');
	like(ref($cache), qr/^CHI/, 'returned object is a CHI instance');
	delete $LEDGER{'Utils::mem_cache valid'};

	throws_ok { create_memory_cache({}) }
		qr/config is not optional/,
		'create_memory_cache without config croaks';
	delete $LEDGER{'Utils::mem_cache no config'};
};

# ---------------------------------------------------------------------------
# Restore all mocks before the ledger check so teardown is clean.
# ---------------------------------------------------------------------------
restore_all();

# ---------------------------------------------------------------------------
# LEDGER ASSERTION — every documented API state must have been exercised.
# Any untested states mean the test file has a coverage gap.
# ---------------------------------------------------------------------------
if (my @untested = sort keys %LEDGER) {
	fail('Untested documented API states: ' . join(', ', @untested));
} else {
	pass('All documented API states covered by unit tests');
}

done_testing();
