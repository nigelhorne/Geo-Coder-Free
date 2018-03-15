#!/usr/bin/env perl

use strict;
use warnings;
use autodie qw(:all);
use File::Copy;
use DBI;
use Text::xSV::Slurp;
use Data::Dumper;
use JSON;
use LWP::UserAgent::Throttled;
use Locale::US;
use Digest::MD5;
use Encode;

my %zipcodes = (
	'04350' => { city => 'Litchfield', county => 'Kennebec' },
	'04410' => { city => 'Bradford', county => 'Penobscot' },
	'04490' => { city => 'Topsfield', county => 'Washington' },
	'04653' => { city => 'Bass Harbor', county => 'Hancock' },
	'04654' => { city => 'Machias', county => 'Washington' },
	'04664' => { city => 'Sullivan', county => 'Hancock' },
	'04674' => { city => 'Seal Cove', county => 'Hancock' },
	'04677' => { city => 'Sorrento', county => 'Hancock' },
	'04679' => { city => 'Southwest Harbor', county => 'Hancock' },
	'04681' => { city => 'Stonington', county => 'Hancock' },
	'04685' => { city => 'Swans Island', county => 'Hancock' },
	'04787' => { city => 'Westfield', county => 'Aroostook' },
	'04984' => { city => 'Temple', county => 'Franklin' },
	'32346' => { city => 'Panacea', county => 'Wakulla' },
	'46204' => { city => 'Indianapolis', county => 'Marion' },
	'46206' => { city => 'Indianapolis', county => 'Marion' },
	'46222' => { city => 'Indianapolis', county => 'Marion' },
	'46231' => { city => 'Indianapolis', county => 'Marion' },
	'46282' => { city => 'Indianapolis', county => 'Marion' },
	'46259' => { city => 'Indianapolis', county => 'Marion' },
	'47001' => { city => 'Aurora', county => 'Dearborn' },
	'47864' => { city => 'New Lebanon', county => 'Sullivan' },
	'59276' => { city => 'Whitetail', county => 'Daniels' },
	'59645' => { city => 'White Sulphur Springs', county => 'Meagher' },
	'80011' => { city => 'Aurora', county => 'Arapahoe' },
	'80015' => { city => 'Aurora', county => 'Arapahoe' },
	'80016' => { city => 'Aurora', county => 'Arapahoe' },
	'80018' => { city => 'Aurora', county => 'Arapahoe' },
	'80131' => { city => 'Louviers', county => 'Douglas' },
	'80118' => { city => 'Larkspur', county => 'Douglas' },
	'80202' => { city => 'Denver', county => 'Adams' },
	'80218' => { city => 'Denver', county => 'Adams' },
	'80221' => { city => 'Denver', county => 'Adams' },
	'80222' => { city => 'Denver', county => 'Adams' },
	'80230' => { city => 'Denver', county => 'Adams' },
	'80233' => { city => 'Denver', county => 'Adams' },
	'80234' => { city => 'Denver', county => 'Adams' },
	'80236' => { city => 'Denver', county => 'Adams' },
	'80241' => { city => 'Denver', county => 'Adams' },
	'80293' => { city => 'Denver', county => 'Adams' },
	'80294' => { city => 'Denver', county => 'Adams' },
	'81501' => { city => 'Grand Junction', county => 'Mesa' },
	'81507' => { city => 'Grand Junction', county => 'Mesa' },
	'81432' => { city => 'Ridgway', county => 'Ouray' },
	'80513' => { city => 'Berthoud', county => 'Larimer' },
	'80516' => { city => 'Erie', county => 'Weld' },
	'80550' => { city => 'Windsor', county => 'Weld' },
	'80610' => { city => 'Auld', county => 'Weld' },
	'80615' => { city => 'Eaton', county => 'Weld' },
	'80631' => { city => 'Greeley', county => 'Weld' },
	'80634' => { city => 'Greeley', county => 'Weld' },
	'80642' => { city => 'Hudson', county => 'Weld' },
	'80645' => { city => 'La Salle', county => 'Weld' },
	'80650' => { city => 'Pierce', county => 'Weld' },
);
my %postcodes = ();

if(!-r 'lib/Geo/Coder/Free/MaxMind/databases/cities.sql') {
	(system('bash bin/createdatabase') == 0)
		or warn "Can't create the SQLite database - expect poor performance";

	if(-r 'lib/Geo/Coder/Free/MaxMind/databases/cities.sql') {
		copy('lib/Geo/Coder/Free/MaxMind/databases/cities.sql', 'blib/lib/Geo/Coder/Free/MaxMind/databases/cities.sql')
			or die "Can't copy SQLite file to blib";
	}
}

if(my $oa = $ENV{'OPENADDR_HOME'}) {
	# Import openaddresses.io data into an SQLite database
	# TODO: download and unzip the files from results.openaddresses.io
	# TODO: only US and Canadian data is supported at the moment

	my $sqlite_file = "$oa/openaddresses.sql";
	if(!-r $sqlite_file) {
		my $dbh = DBI->connect("dbi:SQLite:dbname=$sqlite_file", undef, undef, { RaiseError => 1, AutoCommit => 0, synchronous => 0, locking_mode => 'EXCLUSIVE' });
		if(!-d $oa) {
			mkdir $oa;
		}
		my $ua = LWP::UserAgent::Throttled->new(keep_alive => 1);
		$ua->throttle({ 'api.zippopotam.us' => 1 });
		$ua->env_proxy(1);

		# TODO: Work out a good key
		$dbh->prepare("CREATE TABLE openaddresses(md5 CHAR UNIQUE PRIMARY KEY NOT NULL, lat INTEGER, lon INTEGER, number CHAR, street CHAR, city CHAR, county CHAR, state char NOT NULL, country char NOT NULL)")->execute();

		print "This will take some time.\nBest to do it last thing at night and go to sleep, it should be ready in the morning.\n";


		my $filename = 'lib/Geo/Coder/Free/OpenAddresses/databases/states.txt';
		if(-r $filename) {
			# Import counties and states from https://github.com/openaddresses/openaddresses/tree/master/us-data
			printf "%-70s\r", $filename;
			my %state_fips;

			my @data = @{xsv_slurp(
				shape => 'aoh',
				text_csv => {
					sep_char => "\t",
					allow_loose_quotes => 1,
					blank_is_undef => 1,
					empty_is_undef => 1,
					binary => 1,
				},
				file => $filename
			)};
			foreach my $row(@data) {
				# print Data::Dumper->new([\$row])->Dump();
				my $state;
				unless($state = Locale::US->new()->{state2code}{uc($row->{'Name'})}) {
					die $row->{'Name'};
				}
				my $digest = Digest::MD5::md5_base64($state, 'US');
				my $query = "INSERT INTO openaddresses('MD5','LAT','LON','STATE','COUNTRY'" .
					') VALUES (' .
					"'$digest'," .
					"'" . $row->{'Latitude'} . "'," .
					"'" . $row->{'Longitude'} . "'," .
					"'$state', 'US')";
				$dbh->prepare($query)->execute();
				# print "$query\n";
				$state_fips{$row->{'State FIPS'}} = $state;
			}

			$filename = 'lib/Geo/Coder/Free/OpenAddresses/databases/counties.txt';
			printf "%-70s\r", $filename;

			@data = @{xsv_slurp(
				shape => 'aoh',
				text_csv => {
					sep_char => "\t",
					allow_loose_quotes => 1,
					blank_is_undef => 1,
					empty_is_undef => 1,
					binary => 1,
				},
				file => $filename
			)};
			foreach my $row(@data) {
				# print Data::Dumper->new([\$row])->Dump();
				my $state = $state_fips{$row->{'State FIPS'}};
				die $row->{'Name'} unless(defined($state));
				my $county = uc($row->{'Name'});
				$county =~ s/'/''/g;	# O'Brien County, IA
				my $digest = Digest::MD5::md5_base64($county, $state, 'US');
				my $query = "INSERT INTO openaddresses('MD5','LAT','LON','COUNTY','STATE','COUNTRY'" .
					') VALUES (' .
					"'$digest'," .
					"'" . $row->{'Latitude'} . "'," .
					"'" . $row->{'Longitude'} . "'," .
					"'$county'," .
					"'$state', 'US')";
				# print "$query\n";
				$dbh->prepare($query)->execute();
			}
		}

		foreach my $csv_file (create_tree($oa)) {
			# next unless($csv_file =~ /statewide/);
			# next unless($csv_file =~ /us\/ne\/dawes/);
			my $f = $csv_file;
			$f =~ s/^$oa\///;
			$| = 1;
			printf "%-70s\r", $f;
			$| = 0;
			# print "\n";
			my @components = split(/\//, $f);
			if(my $country = $components[0]) {
				my $query;
				my $state = uc($components[1]);
				my $file = $components[2];

				if($country eq 'us') {
					# Workaround for https://github.com/openaddresses/openaddresses/issues/3905
					my @data;
					if($csv_file =~ /us\/ne\/dawes/) {
						open(my $pin, '-|', "grep -v \\\\\\\\ $csv_file");

						@data = @{xsv_slurp(
							shape => 'aoh',
							text_csv => {
								# sep_char => $sep_char,
								allow_loose_quotes => 1,
								blank_is_undef => 1,
								empty_is_undef => 1,
								binary => 1,
								# escape_char => '\\',	# Put back once issue 3905 has been fixed
							},
							handle => $pin
						)};
						close $pin;
					} else {
						@data = @{xsv_slurp(
							shape => 'aoh',
							text_csv => {
								# sep_char => $sep_char,
								allow_loose_quotes => 1,
								blank_is_undef => 1,
								empty_is_undef => 1,
								binary => 1,
								# escape_char => '\\',	# Put back once issue 3905 has been fixed
							},
							file => $csv_file
						)};
					}
					foreach my $row(@data) {
						my $city = $row->{'CITY'};
						my $county;
						if(defined($city) && ($file !~ /^statewide/)) {
							if($file =~ /^city_of_(.+).csv$/) {
								$city = $1;
							} elsif($file =~ /^town_of_(.+).csv$/) {
								$city = $1;
							} elsif($file =~ /^(.+)_borough.csv$/) {
								$city = $1;
							} else {
								$county = $file;
								$county =~ s/\.csv$//;
							}
						} else {
							if(!defined($city)) {
								if($file =~ /^city_of_(.+).csv$/) {
									$city = $1;
								} elsif($file =~ /^town_of_(.+).csv$/) {
									$city = $1;
								} elsif($file =~ /^(.+)_borough.csv$/) {
									$city = $1;
								}
							}
							if((!defined($city)) && ($file !~ /^statewide/)) {
								$city = $file;
							}
							my $zip = $row->{'POSTCODE'};
							if((!defined($city)) && defined($zip) && (my $info = $zipcodes{$zip})) {
								$city = $info->{'city'};
								$county = $info->{'county'};
							}
							if((!defined($city)) && defined($zip) && ($zip =~ /^(\d{5})/)) {
								$zip = $1;
								my $res = $ua->get("http://api.zippopotam.us/us/$zip");
								my $rc = JSON->new()->utf8()->decode($res->content());
								if(!defined($rc)) {
									# print "\n", Data::Dumper->new([\$row])->Dump();
									next;
								}
								my $place = @{$rc->{'places'}}[0];
								if(!$place) {
									# print "\n", Data::Dumper->new([\$row])->Dump();
									next;
								}
								$city = uc($place->{'place name'});
								$zipcodes{$zip} = { 'city' => $city };
								# print "$zip => $city\n";
								my $digest = Digest::MD5::md5_base64($city, $state, 'US');
								$query = "INSERT OR IGNORE INTO openaddresses('MD5','LAT','LON','CITY','STATE','COUNTRY'" .
									') VALUES (' .
									"'$digest'," .
									"'" . $place->{'latitude'} . "'," .
									"'" . $place->{'longitude'} . "'," .
									"'$city','$state','US')";
								# print "$zip => $query\n";
								$dbh->prepare($query)->execute();
							}
							if(!defined($city)) {
								next if(!$zip);
								next if($zip !~ /^\d{5}/);
								# print "\n", Data::Dumper->new([\$row])->Dump();
								$dbh->disconnect();
								die $csv_file;
							}
						}
						$city =~ s/\.csv$//;
						$city = uc($city);
						$city =~ s/\s+BORO$//;
						$city =~ s/\s+TWP$//;
						$city =~ s/_/ /g;
						my $street = $row->{'STREET'};
						if($street) {
							$street = uc($street);
							if($street =~ /(.+)\s+STREET$/) {
								$street = "$1 ST";
							} elsif($street =~ /(.+)\s+ROAD$/) {
								$street = "$1 RD";
							} elsif($street =~ /(.+)\s+AVENUE$/) {
								$street = "$1 AVE";
							} elsif($street =~ /(.+)\s+AVENUE\s+(.+)/) {
								$street = "$1 AVE $2";
							}
							$street =~ s/^0+//;	# Turn 04th St into 4th St
						}
						if($file =~ /^(.+)_county.csv$/) {
							$county = $1;
						}
						if((!defined($county)) && ($row->{'DISTRICT'}) && ($row->{'DISTRICT'} ne $state)) {
							$county = $row->{'DISTRICT'};
						}
						if($county) {
							$county =~ s/\s+County$//i;
							$county = uc($county);
							$county =~ s/_/ /g;
							if($county eq $city) {
								$county = undef;
							}
						}
						if($state eq 'IN') {
							if($city eq 'FW') {
								$city = 'FORT WAYNE';
								$county = 'ALLEN';
							} elsif(defined($county) && ($county eq 'LAPORTE')) {
								$county = 'LA PORTE';
							}
						}
						my %columns = (
							'COUNTRY' => 'US',
							'CITY' => $city,
							'STATE' => $state,
							'COUNTY' => $county,
							'STREET' => $street
						);
						if($street) {
							$row->{'STREET'} =~ s/\s\s+/ /g;
						}
						foreach my $c('LAT', 'LON') {
							$columns{$c} = delete $row->{$c};
						}
						foreach my $column(keys %columns) {
							if(!defined($columns{$column})) {
								delete $columns{$column};
							}
						}
						insert($dbh, \%columns);
						if(delete($columns{'NUMBER'})) {
							# Match somewhere in the street when number isn't known
							insert($dbh, \%columns);
							if(delete($columns{'STREET'})) {
								# Match somewhere in the city when street isn't known
								# TODO:  Work out a way to only do this once
								#	Could maintain a list of hashes and remove
								#	it all when starting a new state
								insert($dbh, \%columns);
							}
						}
					}
				} elsif($country eq 'ca') {
					# TODO: remove duplication with the US code
					my @data = @{xsv_slurp(
						shape => 'aoh',
						text_csv => {
							# sep_char => $sep_char,
							allow_loose_quotes => 1,
							blank_is_undef => 1,
							empty_is_undef => 1,
							binary => 1,
							escape_char => '\\',	# Put back once issue 3905 has been fixed
						},
						file => $csv_file
					)};
					foreach my $row(@data) {
						my $city = $row->{'CITY'};
						my $county;
						if(defined($city) && ($file !~ /^province/)) {
							if($file =~ /^city_of_(.+).csv$/) {
								$city = $1;
							} elsif($file =~ /^town_of_(.+).csv$/) {
								$city = $1;
							} elsif($file =~ /^(.+)_borough.csv$/) {
								$city = $1;
							} else {
								$county = $file;
								$county =~ s/\.csv$//;
							}
						} else {
							if(!defined($city)) {
								if($file =~ /^city_of_(.+).csv$/) {
									$city = $1;
								} elsif($file =~ /^town_of_(.+).csv$/) {
									$city = $1;
								} elsif($file =~ /^(.+)_borough.csv$/) {
									$city = $1;
								}
							}
							if((!defined($city)) && ($file !~ /^province/)) {
								$city = $file;
							}
							my $postcode = $row->{'POSTCODE'};
							if((!defined($city)) && defined($postcode) && (my $info = $postcodes{$postcode})) {
								$city = $info->{'city'};
								$county = $info->{'county'};
							}
							if((!defined($city)) && defined($postcode) && ($postcode =~ /^(\[A-Z]\d[A-Z])/)) {
								$postcode = $1;
								my $res = $ua->get("http://api.zippopotam.us/ca/$postcode");
								my $rc = JSON->new()->utf8()->decode($res->content());
								if(!defined($rc)) {
									# print "\n", Data::Dumper->new([\$row])->Dump();
									next;
								}
								my $place = @{$rc->{'places'}}[0];
								if(!$place) {
									# print "\n", Data::Dumper->new([\$row])->Dump();
									next;
								}
								$city = uc($place->{'place name'});
								$postcodes{$postcode} = { 'city' => $city };
								# print "$zip => $city\n";
								$query = "INSERT INTO openaddresses('LAT','LON','CITY','STATE','COUNTRY'" .
									') VALUES (' .
									"'" . $place->{'latitude'} . "'," .
									"'" . $place->{'longitude'} . "'," .
									"'$city'," .
									# "'" . $place->{'province abbreviation'} . "'," .
									"'$state', 'CA')";
								# print "$postcode => $query\n";
								$dbh->prepare($query)->execute();
							}
							if(!defined($city)) {
								next if(!$postcode);
								next if($postcode !~ /^[A-Z]\d[A-Z]/);
								# print "\n", Data::Dumper->new([\$row])->Dump();
								$dbh->disconnect();
								die $csv_file;
							}
						}
						$city =~ s/\.csv$//;
						$city = uc($city);
						$city =~ s/\s+BORO$//;
						$city =~ s/\s+TWP$//;
						$city =~ s/_/ /g;
						my $street = $row->{'STREET'};
						if($street) {
							$street = uc($street);
							if($street =~ /(.+)\s+STREET$/) {
								$street = "$1 ST";
							} elsif($street =~ /(.+)\s+ROAD$/) {
								$street = "$1 RD";
							} elsif($street =~ /(.+)\s+AVENUE$/) {
								$street = "$1 AVE";
							} elsif($street =~ /(.+)\s+AVENUE\s+(.+)/) {
								$street = "$1 AVE $2";
							}
							$street =~ s/^0+//;	# Turn 04th St into 4th St
						}
						if($file =~ /^(.+)_county.csv$/) {
							$county = $1;
						}
						if((!defined($county)) && ($row->{'DISTRICT'}) && ($row->{'DISTRICT'} ne $state)) {
							$county = $row->{'DISTRICT'};
						}
						if($county) {
							$county =~ s/\s+County$//i;
							$county = uc($county);
							$county =~ s/_/ /g;
							if(uc($county) eq uc($city)) {
								$county = undef;
							}
						}
						my %columns = (
							'COUNTRY' => 'CA',
							'STATE' => $state,
							'CITY' => uc($city),
							'COUNTY' => $county,
							'STREET' => $street
						);
						if($street) {
							$row->{'STREET'} =~ s/\s\s+/ /g;
						}
						foreach my $c('LAT', 'LON', 'NUMBER') {
							$columns{$c} = delete $row->{$c};
						}
						foreach my $column(keys %columns) {
							if(!defined($columns{$column})) {
								delete $columns{$column};
							}
						}
						insert($dbh, \%columns);
						if(delete($columns{'NUMBER'})) {
							# Match somewhere in the street when number isn't known
							insert($dbh, \%columns);
							if(delete($columns{'STREET'})) {
								# Match somewhere in the city when street isn't known
								# TODO:  Work out a way to only do this once
								#	Could maintain a list of hashes and remove
								#	it all when starting a new province
								insert($dbh, \%columns);
							}
						}
					}
				}
			}
		}

		print ' ' x 70, "\r";
		$dbh->commit();
		$dbh->disconnect();
	}
}

sub create_tree {
	my $where = shift;
	my @list = shift || ();

	foreach my $file(<"$where/*">) {
		next if($file =~ /summary$/);
		if(-d $file) {
			push(@list, create_tree($file, @list));
		} elsif(($file =~ /\.csv$/) && (-f $file)) {
			push(@list, $file);
		}
	}
	return @list;
}

sub insert {
	my ($dbh, $columns) = @_;

	my $digest = Digest::MD5::md5_base64(map { Encode::encode_utf8($columns->{$_}) } sort keys %{$columns});
	# TODO: instead of INSERT OR IGNORE, give a warning for duplicates and just INSERT
	my $query = 'INSERT OR IGNORE INTO openaddresses(' .
		join(',', sort keys %{$columns}) .
		',MD5) VALUES (';
	foreach my $column(sort keys %{$columns}) {
		$columns->{$column} =~ s/'/''/g;
		$query .= "'" . $columns->{$column} . "',";
	}
	$query .= "'$digest')";

	# print "$query\n";
	$dbh->prepare($query)->execute();
}
