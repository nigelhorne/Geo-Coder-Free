package Geo::Coder::Free;

use strict;
use warnings;

use Geo::Coder::Free::DB::admin1;
use Geo::Coder::Free::DB::admin2;
use Geo::Coder::Free::DB::cities;
use Geo::Coder::Free::DB::OpenAddr;
use Module::Info;
use Carp;
use Error::Simple;
use File::Spec;
use Locale::CA;
use Locale::US;
use CHI;
use Locale::Country;

our %admin1cache;
our %admin2cache;

#  Some locations aren't found because of inconsistencies in the way things are stored - these are some values I know
# FIXME: Should be in a configuration file
my %known_locations = (
	'Newport Pagnell, Buckinghamshire, England' => {
		'latitude' => 52.08675,
		'longitude' => -0.72270
	},
);

=head1 NAME

Geo::Coder::Free - Provides a geocoding functionality using free databases of towns

=head1 VERSION

Version 0.05

=cut

our $VERSION = '0.05';

=head1 SYNOPSIS

    use Geo::Coder::Free;

    my $geocoder = Geo::Coder::Free->new();
    my $location = $geocoder->geocode(location => 'Ramsgate, Kent, UK');

    # Use a local download of http://results.openaddresses.io/
    my $openaddr_geocoder = Geo::Coder::Freee->new(openaddr => $ENV{'OPENADDR_HOME'});
    $location = $openaddr_geocoder->geocode(location => '1600 Pennsylvania Avenue NW, Washington DC, USA');

=head1 DESCRIPTION

Geo::Coder::Free provides an interface to free databases.

Refer to the source URL for licencing information for these files
cities.csv is from https://www.maxmind.com/en/free-world-cities-database
admin1.db is from http://download.geonames.org/export/dump/admin1CodesASCII.txt
admin2.db is from http://download.geonames.org/export/dump/admin2Codes.txt
openaddress data can be downloaded from http://results.openaddresses.io/

See also http://download.geonames.org/export/dump/allCountries.zip

To significantly speed this up,
gunzip cities.csv and run it through the db2sql script to create an SQLite file.

=head1 METHODS

=head2 new

    $geocoder = Geo::Coder::Free->new();

=cut

sub new {
	my($proto, %param) = @_;
	my $class = ref($proto) || $proto;

	# Geo::Coder::Free->new not Geo::Coder::Free::new
	return unless($class);

	# Geo::Coder::Free::DB::init(directory => 'lib/Geo/Coder/Free/databases');

	my $directory = Module::Info->new_from_loaded(__PACKAGE__)->file();
	$directory =~ s/\.pm$//;

	Geo::Coder::Free::DB::init({
		directory => File::Spec->catfile($directory, 'databases'),
		cache => CHI->new(driver => 'Memory', datastore => { })
	});

	# TODO: This has not been written yet, so it isn't documented
	if(my $openaddr = $param{'openaddr'}) {
		die "Can't find the directory $openaddr" if((!-d $openaddr) || (!-r $openaddr));
		return bless { openaddr => $openaddr}, $class;
	}

	return bless { }, $class;
}

=head2 geocode

    $location = $geocoder->geocode(location => $location);

    print 'Latitude: ', $location->{'latt'}, "\n";
    print 'Longitude: ', $location->{'longt'}, "\n";

    # TODO:
    # @locations = $geocoder->geocode('Portland, USA');
    # diag 'There are Portlands in ', join (', ', map { $_->{'state'} } @locations);

=cut

sub geocode {
	my $self = shift;

	my %param;
	if(ref($_[0]) eq 'HASH') {
		%param = %{$_[0]};
	} elsif(@_ % 2 == 0) {
		%param = @_;
	} else {
		$param{location} = shift;
	}

	my $location = $param{location}
		or Carp::croak("Usage: geocode(location => \$location)");

	if($location =~ /^(.+),\s*Washington\s*DC,(.+)$/) {
		$location = "$1, Washington, DC, $2";
	}

	if($known_locations{$location}) {
		return $known_locations{$location};
	}

	my $county;
	my $state;
	my $country;
	my $country_code;
	my $street;
	my $concatenated_codes;

	if($location =~ /^([\w\s\-]+)?,([\w\s]+),([\w\s]+)?$/) {
		# Turn 'Ramsgate, Kent, UK' into 'Ramsgate'
		$location = $1;
		$county = $2;
		$country = $3;
		$location =~ s/\-/ /g;
		$county =~ s/^\s//g;
		$county =~ s/\s$//g;
		$country =~ s/^\s//g;
		$country =~ s/\s$//g;
		if($location =~ /^St\.? (.+)/) {
			$location = "Saint $1";
		}
	} elsif($location =~ /^([\w\s\-]+)?,([\w\s]+),([\w\s]+),\s*(Canada|United States|USA|US)?$/) {
		$location = $1;
		$county = $2;
		$state = $3;
		$country = $4;
		$county =~ s/^\s//g;
		$county =~ s/\s$//g;
		$state =~ s/^\s//g;
		$state =~ s/\s$//g;
		$country =~ s/^\s//g;
		$country =~ s/\s$//g;
	} elsif($self->{openaddr}) {
		if($location =~ /^([\w\s\-]+)?,([\w\s]+),([\w\s]+),([\w\s]+),\s*(Canada|United States|USA|US)?$/) {
			$street = $1;
			$location = $2;
			$county = $3;
			$state = $4;
			$country = $5;
			$location =~ s/^\s//g;
			$location =~ s/\s$//g;
			$county =~ s/^\s//g;
			$county =~ s/\s$//g;
			$state =~ s/^\s//g;
			$state =~ s/\s$//g;
			$country =~ s/^\s//g;
			$country =~ s/\s$//g;
		} else {
			# TODO: Parse full postal address
			die 'TODO - add support for full addresses on openaddr';
		}
	} else {
		Carp::croak(__PACKAGE__, ' only supports towns, not full addresses when openaddr is not given');
		return;
	}
	if(($country eq 'UK') || ($country eq 'United Kingdom')) {
		$country = 'Great Britain';
		$concatenated_codes = 'GB';
	}

	if($country) {
		if($self->{openaddr} && country2code($country)) {
			my $openaddr_db;
			my $countrydir = File::Spec->catfile($self->{openaddr}, lc(country2code($country)));
			# TODO:  Don't use statewide if the county can be determined, since that file will be much smaller
			if($state && (-d $countrydir)) {
				# TODO:  Locale::CA for Canadian provinces
				if(($state =~ /^(United States|USA|US)$/) && (length($state) > 2)) {
					if(my $twoletterstate = Locale::US->new()->{state2code}{uc($state)}) {
						$state = $twoletterstate;
					}
				} elsif($country =~ /^(United States|USA|US)$/) {
					if(my $twoletterstate = Locale::US->new()->{state2code}{uc($state)}) {
						$state = $twoletterstate;
					}
					my $l = length($state);
					if($l > 2) {
						if(my $twoletterstate = Locale::US->new()->{state2code}{uc($state)}) {
							$state = $twoletterstate;
						}
					} elsif($l == 2) {
						$state = lc($state);
					}
				}
				my $statedir = File::Spec->catfile($countrydir, $state);
				if(-d $statedir) {
					$openaddr_db = $self->{$statedir} || Geo::Coder::Free::DB::OpenAddr->new(directory => $statedir, table => 'statewide');
					if($location) {
						$self->{$statedir} = $openaddr_db;
						my $rc;
						if($street) {
							$rc = $openaddr_db->fetchrow_hashref('street' => uc($street), 'city' => uc($location));
						} else {
							$rc = $openaddr_db->fetchrow_hashref('city' => uc($location));
						}
						if($rc && defined($rc->{'lat'})) {
							$rc->{'latitude'} = $rc->{'lat'};
							$rc->{'longitude'} = $rc->{'lon'};
							return $rc;
						}
						if($location =~ /^(\d+)\s+(.+)$/) {
							$rc = $openaddr_db->fetchrow_hashref('number' => $1, 'street' => uc($2), 'city' => uc($county));
						} else {
							$rc = $openaddr_db->fetchrow_hashref('street' => uc($location), 'city' => uc($county));
						}
						if($rc && defined($rc->{'lat'})) {
							$rc->{'latitude'} = $rc->{'lat'};
							$rc->{'longitude'} = $rc->{'lon'};
							return $rc;
						}
					}
					die $statedir;
				}
			} elsif($county && (-d $countrydir)) {
				my $is_state;
				my $table;
				if($country =~ /^(United States|USA|US)$/) {
					my $l = length($county);
					if($l > 2) {
						if(my $twoletterstate = Locale::US->new()->{state2code}{uc($county)}) {
							$county = $twoletterstate;
							$is_state = 1;
							$table = 'statewide';
						}
					} elsif($l == 2) {
						$county = lc($county);
						$is_state = 1;
						$table = 'statewide';
					}
				} elsif($country eq 'Canada') {
					my $l = length($county);
					if($l > 2) {
						if(my $province = Locale::CA->new()->{province2code}{uc($county)}) {
							$county = $province;
							$is_state = 1;
							$table = 'province';
						}
					} elsif($l == 2) {
						$county = lc($county);
						$is_state = 1;
						$table = 'province';
					}
					my $city_file = 'city_of_' . lc($location);
					# FIXME:  allow SQLite file
					if(-r File::Spec->catfile($countrydir, lc($county), "$city_file.csv")) {
						$table = $city_file;
						$location = '';	# Get the first location in the city.  Anyone will do
					}
				}
				my $countydir = File::Spec->catfile($countrydir, lc($county));
				if(-d $countydir) {
					if($is_state) {
						# FIXME - self->{$countydir} can point to a town in Canada
						$openaddr_db = $self->{$countydir} || Geo::Coder::Free::DB::OpenAddr->new(directory => $countydir, table => $table);
						if(defined($location)) {
							if($location eq '') {
								# Get the first location in the city.  Anyone will do
								my $rc = $openaddr_db->execute('SELECT DISTINCT LAT, LON FROM city_of_edmonton WHERE city IS NULL');
								if($rc && defined($rc->{'LAT'})) {
									$rc->{'latitude'} = $rc->{'LAT'};
									$rc->{'longitude'} = $rc->{'LON'};
									return $rc;
								}
							}
							my $rc = $openaddr_db->fetchrow_hashref('city' => uc($location));
							if($rc && defined($rc->{'lat'})) {
								$rc->{'latitude'} = $rc->{'lat'};
								$rc->{'longitude'} = $rc->{'lon'};
								$self->{$countydir} = $openaddr_db;
								return $rc;
							}
						die;
						}
						die;
					} else {
						$openaddr_db = Geo::Coder::Free::DB::OpenAddr->new(directory => $countydir);
						die $countydir;
					}
				}
			} else {
				$openaddr_db = Geo::Coder::Free::DB::OpenAddr->new(directory => $countrydir);
						die;
			}
			if($openaddr_db) {
				die "TBD";
			}
			die;
		}
		if($state && $admin1cache{$state}) {
			$concatenated_codes = $admin1cache{$state};
		} elsif($admin1cache{$country} && !defined($state)) {
			$concatenated_codes = $admin1cache{$country};
		} else {
			if(!defined($self->{'admin1'})) {
				$self->{'admin1'} = Geo::Coder::Free::DB::admin1->new() or die "Can't open the admin1 database";
			}
			if(my $admin1 = $self->{'admin1'}->fetchrow_hashref(asciiname => $country)) {
				$concatenated_codes = $admin1->{'concatenated_codes'};
				$admin1cache{$country} = $concatenated_codes;
			} else {
				require Locale::Country;
				if($state) {
					if($state =~ /^[A-Z]{2}$/) {
						$concatenated_codes = uc(Locale::Country::country2code($country)) . ".$state";
					} else {
						$concatenated_codes = uc(Locale::Country::country2code($country));
						$country_code = $concatenated_codes;
						my @admin1s = @{$self->{'admin1'}->selectall_hashref(asciiname => $state)};
						foreach my $admin1(@admin1s) {
							if($admin1->{'concatenated_codes'} =~ /^$concatenated_codes\./i) {
								$concatenated_codes = $admin1->{'concatenated_codes'};
								last;
							}
						}
					}
					$admin1cache{$state} = $concatenated_codes;
				} elsif(my $rc = Locale::Country::country2code($country)) {
					$concatenated_codes = uc($rc);
					$admin1cache{$country} = $concatenated_codes;
				} elsif(Locale::Country::code2country($country)) {
					$concatenated_codes = uc($country);
					$admin1cache{$country} = $concatenated_codes;
				}
			}
		}
	}
	return unless(defined($concatenated_codes));

	if(!defined($self->{'admin2'})) {
		$self->{'admin2'} = Geo::Coder::Free::DB::admin2->new() or die "Can't open the admin1 database";
	}
	my @admin2s;
	my $region;
	my @regions;
	if(($country =~ /^(United States|USA|US)$/) && (length($county) > 2)) {
		if(my $twoletterstate = Locale::US->new()->{state2code}{uc($county)}) {
			$county = $twoletterstate;
		}
	} elsif(($country eq 'Canada') && (length($county) > 2)) {
		if(my $twoletterstate = Locale::CA->new()->{province2code}{uc($county)}) {
			$county = $twoletterstate;
		}
	}
	if(($county =~ /^[A-Z]{2}/) && ($country =~ /^(United States|USA|US)$/)) {
		# US state. Not Canadian province.
		$region = $county;
	} else {
		if($county && $admin1cache{$county}) {
			$region = $admin1cache{$county};
		} elsif($county && $admin2cache{$county}) {
			$region = $admin2cache{$county};
		} elsif(defined($state) && $admin2cache{$state} && !defined($county)) {
			$region = $admin2cache{$state};
		} else {
			@admin2s = $self->{'admin2'}->selectall_hash(asciiname => $county);
			foreach my $admin2(@admin2s) {
				if($admin2->{'concatenated_codes'} =~ $concatenated_codes) {
					$region = $admin2->{'concatenated_codes'};
					if($region =~ /^[A-Z]{2}\.([A-Z]{2})\./) {
						my $rc = $1;
						if(defined($state) && ($state =~ /^[A-Z]{2}$/)) {
							if($state eq $rc) {
								$region = $rc;
								@regions = ();
								last;
							}
						} else {
							push @regions, $region;
							push @regions, $rc;
						}
					} else {
						push @regions, $region;
					}
				}
			}
			if($state && !defined($region)) {
				if($state =~ /^[A-Z]{2}$/) {
					$region = $state;
					@regions = ();
				} else {
					@admin2s = $self->{'admin2'}->selectall_hash(asciiname => $state);
					foreach my $admin2(@admin2s) {
						if($admin2->{'concatenated_codes'} =~ $concatenated_codes) {
							$region = $admin2->{'concatenated_codes'};
							last;
						}
					}
				}
			}
		}
	}

	if((scalar(@regions) == 0) && !defined($region)) {
		# e.g. Unitary authorities in the UK
		@admin2s = $self->{'admin2'}->selectall_hash(asciiname => $location);
		if(scalar(@admin2s) && defined($admin2s[0]->{'concatenated_codes'})) {
			foreach my $admin2(@admin2s) {
				my $concat = $admin2->{'concatenated_codes'};
				if($concat =~ /^CA\.(\d\d)\./) {
					# Canadian provinces are not stored in the same way as US states
					$region = $1;
					last;
				} elsif($concat =~ $concatenated_codes) {
					$region = $concat;
					last;
				}
			}
		} else {
			# e.g. states in the US
			my @admin1s = $self->{'admin1'}->selectall_hash(asciiname => $county);
			foreach my $admin1(@admin1s) {
				if($admin1->{'concatenated_codes'} =~ /^$concatenated_codes\./i) {
					$region = $admin1->{'concatenated_codes'};
					$admin1cache{$county} = $region;
					last;
				}
			}
		}
	}

	if(!defined($self->{'cities'})) {
		$self->{'cities'} = Geo::Coder::Free::DB::cities->new();
	}

	my $options = { City => lc($location) };
	if($region) {
		if($region =~ /^.+\.(.+)$/) {
			$region = $1;
		}
		$options->{'Region'} = $region;
		if($country_code) {
			$options->{'Country'} = lc($country_code);
		}
		if($state) {
			$admin2cache{$state} = $region;
		} elsif($county) {
			$admin2cache{$county} = $region;
		}
	}

	# This case nonsense is because DBD::CSV changes the columns to lowercase, wherease DBD::SQLite does not
	if(wantarray) {
		my @rc = $self->{'cities'}->selectall_hash($options);
		foreach my $city(@rc) {
			if($city->{'Latitude'}) {
				$city->{'latitude'} = delete $city->{'Latitude'};
				$city->{'longitude'} = delete $city->{'Longitude'};
			}
		}
		return @rc;
	}
	my $city = $self->{'cities'}->fetchrow_hashref($options);
	if(!defined($city)) {
		foreach $region(@regions) {
			if($region =~ /^.+\.(.+)$/) {
				$region = $1;
			}
			if($country =~ /^(Canada|United States|USA|US)$/) {
				next unless($region =~ /^[A-Z]{2}$/);
			}
			$options->{'Region'} = $region;
			$city = $self->{'cities'}->fetchrow_hashref($options);
			last if(defined($city));
		}
	}

	if(defined($city) && defined($city->{'Latitude'})) {
		$city->{'latitude'} = delete $city->{'Latitude'};
		$city->{'longitude'} = delete $city->{'Longitude'};
	}
	return $city;
	# my $rc;
	# if(wantarray && $rc->{'otherlocations'} && $rc->{'otherlocations'}->{'loc'} &&
	   # (ref($rc->{'otherlocations'}->{'loc'}) eq 'ARRAY')) {
		# my @rc = @{$rc->{'otherlocations'}->{'loc'}};
		# if(scalar(@rc)) {
			# return @rc;
		# }
	# }
	# return $rc;
	# my @results = @{ $data || [] };
	# wantarray ? @results : $results[0];
}

=head2 reverse_geocode

    $location = $geocoder->reverse_geocode(latlng => '37.778907,-122.39732');

To be done.

=cut

sub reverse_geocode {
	Carp::croak('Reverse lookup is not yet supported');
}

=head2	ua

Does nothing, here for compatibility with other geocoders

=cut

sub ua {
}

=head1 AUTHOR

Nigel Horne <njh@bandsman.co.uk>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 BUGS

Lots of lookups fail at the moment.

The openaddresses.io code has yet to be compeleted.  There are die()s where the code path has yet to be written.

The MaxMind data only contains cities.  The openaddresses data doesn't cover the globe.

=head1 SEE ALSO

VWF, openaddresses, MaxMind and geonames.

=head1 LICENSE AND COPYRIGHT

Copyright 2017-2018 Nigel Horne.

The program code is released under the following licence: GPL for personal use on a single computer.
All other users (including Commercial, Charity, Educational, Government)
must apply in writing for a licence for use from Nigel Horne at `<njh at nigelhorne.com>`.

This product includes GeoLite2 data created by MaxMind, available from
http://www.maxmind.com

=cut

1;
