package Geo::Coder::Free;

use strict;
use warnings;

use Geo::Coder::Free::DB::cities;
use Carp;

=head1 NAME

Geo::Coder::Free - Provides a geocoding functionality using free databases of towns

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

      use Geo::Coder::Free;

      my $geocoder = Geo::Coder::Free->new();
      my $location = $geocoder->geocode(location => 'Ramsgate, Kent, UK');

=head1 DESCRIPTION

Geo::Coder::Free provides an interface to free databases.

=head1 METHODS

=head2 new

    $geocoder = Geo::Coder::Free->new();

=cut

sub new {
	my($proto, %param) = @_;
	my $class = ref($proto) || $proto;

	# Geo::Coder::Free->new not Geo::Coder::Free::new
	return unless($class);

	# FIXME: use Findbin
	Geo::Coder::Free::DB::init(directory => 'lib/Geo/Coder/Free/databases');

	my $cities = Geo::Coder::Free::DB::cities->new() or die;

	return bless { cities => $cities }, $class;
}

=head2 geocode

    $location = $geocoder->geocode(location => $location);

    print 'Latitude: ', $location->{'latt'}, "\n";
    print 'Longitude: ', $location->{'longt'}, "\n";

    @locations = $geocoder->geocode('Portland, USA');
    diag 'There are Portlands in ', join (', ', map { $_->{'state'} } @locations);
    	
=cut

sub geocode {
	my $self = shift;

	my %param;
	if (@_ % 2 == 0) {
		%param = @_;
	} else {
		$param{location} = shift;
	}

	my $location = $param{location}
		or Carp::croak("Usage: geocode(location => \$location)");

	my $rc;
	if(wantarray && $rc->{'otherlocations'} && $rc->{'otherlocations'}->{'loc'} &&
	   (ref($rc->{'otherlocations'}->{'loc'}) eq 'ARRAY')) {
		my @rc = @{$rc->{'otherlocations'}->{'loc'}};
		if(scalar(@rc)) {
			return @rc;
		}
	}
	return $rc;
	# my @results = @{ $data || [] };
	# wantarray ? @results : $results[0];
}

=head2 reverse_geocode

    $location = $geocoder->reverse_geocode(latlng => '37.778907,-122.39732');

Similar to geocode except it expects a latitude/longitude parameter.

=cut

sub reverse_geocode {
	my $self = shift;

	my %param;
	if (@_ % 2 == 0) {
		%param = @_;
	} else {
		$param{latlng} = shift;
	}

	my $latlng = $param{latlng}
		or Carp::croak("Usage: reverse_geocode(latlng => \$latlng)");

	return $self->geocode(location => $latlng, reverse => 1);
};

=head1 AUTHOR

Nigel Horne <njh@bandsman.co.uk>

Based on L<Geo::Coder::Coder::Googleplaces>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 BUGS

CSV files take a long time to load.  Convert to SQLite.

=head1 SEE ALSO

VWF, Maxmind and geonames.

=head1 LICENSE AND COPYRIGHT

Copyright 2017 Nigel Horne.

This program is released under the following licence: GPL2

=cut

1;
