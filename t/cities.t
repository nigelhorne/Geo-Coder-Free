#!perl -wT

# Check the cities database is sensible

use strict;
use warnings;
use Test::Most tests => 6;
use Test::Number::Delta;

BEGIN {
	use_ok('Geo::Coder::Free::DB::cities');
}

CITIES: {
	$ENV{'TEST_VERBOSE'} = 1;	# find what travis is complaining about
	Geo::Coder::Free::DB::init(directory => 'lib/Geo/Coder/Free/databases');
	my $cities = new_ok('Geo::Coder::Free::DB::cities' => [logger => new_ok('MyLogger')]);

	# diag($cities->population(Country => 'gb', City => 'ramsgate'));
	ok($cities->population(Country => 'gb', City => 'ramsgate') == 38624);

	my $ramsgate = $cities->fetchrow_hashref({ Country => 'gb', City => 'ramsgate' });
	delta_within($ramsgate->{latitude}, 51.33, 1e-2);
	delta_within($ramsgate->{longitude}, 1.43, 1e-2);
};

package MyLogger;

sub new {
	my ($proto, %args) = @_;

	my $class = ref($proto) || $proto;

	return bless { }, $class;
}

sub info {
	my $self = shift;
	my $message = shift;

	if($ENV{'TEST_VERBOSE'}) {
		::diag($message);
	}
}

sub trace {
	my $self = shift;
	my $message = shift;

	if($ENV{'TEST_VERBOSE'}) {
		::diag($message);
	}
}

sub debug {
	my $self = shift;
	my $message = shift;

	if($ENV{'TEST_VERBOSE'}) {
		::diag($message);
	}
}

sub AUTOLOAD {
	our $AUTOLOAD;
	my $param = $AUTOLOAD;

	unless($param eq 'MyLogger::DESTROY') {
		::diag("Need to define $param");
	}
}
