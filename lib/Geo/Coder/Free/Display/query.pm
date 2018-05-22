package Geo::Coder::Free::Display::query;

use strict;
use warnings;
use JSON;

# Run a query on the database

use Geo::Coder::Free::Display;

our @ISA = ('Geo::Coder::Free::Display');

sub html {
	my $self = shift;
	my %args = (ref($_[0]) eq 'HASH') ? %{$_[0]} : @_;

	my $info = $self->{_info};
	my $allowed = {
		'page' => 'query',
		'q' => undef,	# TODO: regex of allowable name formats
		'scantext' => undef,	# TODO: regex of allowable name formats
		'lang' => qr/^[A-Z][A-Z]/i,
	};
	my %params = %{$info->params({ allow => $allowed })};

	# TODO: check requested format (JSON/XML) and return that

	delete $params{'page'};
	delete $params{'lang'};

	my $geocoder = $args{'geocoder'};

	my $rc;
	if(my $q = $params{'q'}) {
		$rc = $geocoder->geocode(location => $q);

		return '{ }' if(!defined($rc));

		delete $rc->{'md5'};
		delete $rc->{'sequence'};
		foreach my $key(keys %{$rc}) {
			if(!defined($rc->{$key})) {
				delete $rc->{$key};
			}
		}

		return encode_json $rc;
	} elsif(my $scantext = $params{'scantext'}) {
		my @rc = $geocoder->geocode(scantext => $scantext);

		return '{ }' if(scalar(@rc) == 0);

		foreach my $l(@rc) {
			delete $l->{'md5'};
			delete $l->{'sequence'};
			foreach my $key(keys %{$l}) {
				if(!defined($l->{$key})) {
					delete $l->{$key};
				}
			}
		}
		return encode_json \@rc;
	}

	return '{ }';
}

1;
