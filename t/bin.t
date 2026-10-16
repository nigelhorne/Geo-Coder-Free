#!perl -w

# t/bin.t — the programs the website is built from.
#
# bin/testcgibin drives cgi-bin/page.fcgi the way a browser would and prints the
# answer; bin/address_lookup prints its best answer for an address.  Both find
# their answers in an OpenAddresses database, and a real one is most of a
# gigabyte of downloads and hours of preparation, so these tests make their own:
# a small database holding exactly the addresses the scripts ask about, plus the
# small configuration the CGI page insists on.
#
# OPENADDR_HOME and CONFIG_DIR are pointed at them, so every run — CI included —
# exercises the scripts end to end — CGI page, geocoder, database, output — and
# checks the coordinates they really print, with no downloaded data and no
# dependence on what happens to be installed on the machine.

use strict;

use Test::Needs {
	'Test::Script' => 1.12, 'CGI::Carp' => 0, 'FCGI' => 0, 'FCGI::Buffer' => 0, 'Log::WarnDie' => 0,
	'CGI::ACL' => 0, 'DBI' => 0, 'DBD::SQLite' => 0, 'Geo::Hash' => 0
};
use Test::Most;

use DBI;
use File::Spec;
use File::Temp qw(tempdir);
use Geo::Hash;
use Geo::Coder::Free::OpenAddresses;

my $stub = tempdir(CLEANUP => 1);
my $data_dir = File::Spec->catdir($stub, 'openaddresses');
my $conf_dir = File::Spec->catdir($stub, 'conf');
mkdir $data_dir or BAIL_OUT("Cannot create $data_dir: $!");
mkdir $conf_dir or BAIL_OUT("Cannot create $conf_dir: $!");

# ---------------------------------------------------------------------------
# The stub database
#
# One row per address the scripts look up.  The coordinates are the real
# positions of those places, so the assertions below are the values the live
# service produces, and a stub that answered with the wrong position would be
# caught rather than blessed.
# ---------------------------------------------------------------------------

my @lookups = (
	# bin/testcgibin 1, 3 and 4
	{ query => [ location => 'NASA TIROS RD GREENBELT MD US' ], lat => 38.9917, long => -76.8488 },
	# bin/testcgibin 2 (scantext)
	{ query => [ scantext => 'Washington DC USA' ], lat => 38.8951, long => -77.0100 },
	# bin/address_lookup
	{ query => [ location => 'Fairfield Road, Broadstairs, Kent, UK' ], lat => 51.3607, long => 1.4275 },
);

my $db_file = File::Spec->catfile($data_dir, 'openaddresses.sql');
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", '', '', { RaiseError => 1, PrintError => 0 })
	or BAIL_OUT("Cannot create the stub OpenAddresses database $db_file: $DBI::errstr");
$dbh->do('CREATE TABLE openaddresses (md5 TEXT PRIMARY KEY, geohash TEXT)');

# Which keys the stub has to hold is the geocoder's business, not this file's:
# it rewrites a query into several look-up keys (with and without the country,
# upper and mixed case, and so on).  So ask it — point it at the still-empty
# database with a recorder standing in for the column look-up, and keep every
# key it asks for.
{
	my $recorder;
	no warnings 'once', 'redefine';
	*Geo::Coder::Free::DB::openaddresses::geohash = sub {
		my ($self, %param) = @_;
		push @{$recorder}, $param{'md5'};
		return;
	};

	my $geohash = Geo::Hash->new();
	my $insert = $dbh->prepare('INSERT INTO openaddresses (md5, geohash) VALUES (?, ?)');
	for my $lookup (@lookups) {
		my @keys;
		$recorder = \@keys;
		Geo::Coder::Free::OpenAddresses->new(openaddr => $data_dir)->geocode(@{$lookup->{'query'}});
		my %seen;
		$insert->execute($_, $geohash->encode($lookup->{'lat'}, $lookup->{'long'}))
			for grep { !$seen{$_}++ } @keys;
	}
	$insert->finish();
}

my $rows = $dbh->selectrow_array('SELECT COUNT(*) FROM openaddresses');
ok($rows > 0, "the stub database holds $rows keys for the addresses the scripts look up");

# ---------------------------------------------------------------------------
# The stub configuration
#
# page.fcgi treats every warning as fatal, and the page warns when
# security.csrf.secret is missing, so the page this test drives is given a
# configuration that has one.  It is a fixture value, not a deployment
# credential, and it never leaves the temporary directory.
# ---------------------------------------------------------------------------

my $conf_file = File::Spec->catfile($conf_dir, 'default');
open(my $conf_fh, '>', $conf_file) or BAIL_OUT("Cannot write $conf_file: $!");
print $conf_fh "OPENADDR_HOME: $data_dir\n",
	"security:\n",
	"  csrf:\n",
	"    secret: ", ('a1' x 32), "\n";
close $conf_fh;

# The answers checked below must come from the stub, so the tests do not use
# anyone else's data: the same assertions then hold on a machine with an
# OpenStreetMap or WhosOnFirst download and on one with neither.
delete @ENV{qw(OSM_HOME WHOSONFIRST_HOME DR5HN_HOME)};
local $ENV{'OPENADDR_HOME'} = $data_dir;
local $ENV{'CONFIG_DIR'} = $conf_dir;

Test::Script->import();

script_compiles('bin/testcgibin');
script_compiles('bin/address_lookup');

if($ENV{'AUTHOR_TESTING'}) {
	my $output;
	script_runs(['bin/testcgibin', 3], { stdout => \$output });
	diag($output);

	# Test 1 looks a US postal address up in the stub.
	script_runs(['bin/testcgibin', 1]);
	script_stdout_like(qr/\-76\.84/, 'test 1: the Greenbelt address prints the stub longitude');
	script_stderr_is('', 'test 1: no error output');

	# Test 2 scans free text for place names.
	script_runs(['bin/testcgibin', 2]);
	script_stdout_like(qr/\-77\.01/, 'test 2: the scanned text finds Washington DC in the stub');
	script_stderr_is('', 'test 2: no error output');

	# Tests 3 and 4 ask from a US address, so the page takes the country from
	# the client's IP address: 4 leaves the country out of the address itself.
	script_runs(['bin/testcgibin', 3]);
	script_stdout_like(qr/\-76\.84/, 'test 3: the address resolves when the country comes from the client');
	script_stderr_is('', 'test 3: no error output');

	script_runs(['bin/testcgibin', 4]);
	script_stdout_like(qr/\-76\.84/, 'test 4: the address resolves without a country of its own');
	script_stderr_is('', 'test 4: no error output');

	# A street address, found through the stub rather than an OSM download.
	script_runs(['bin/address_lookup', 'Fairfield Road,', 'Broadstairs,', ' Kent,', ' UK']);
	script_stdout_like(qr/51\.3/, 'address_lookup: the Broadstairs address prints the stub latitude');
	script_stderr_is('', 'address_lookup: no error output');
} else {
	diag('Author tests not required for installation');
}

done_testing();
