package Geo::Coder::Free::DB::MaxMind::admin;

use strict;
use warnings;

=head1 NAME

Geo::Coder::Free::DB::MaxMind::admin

=head1 VERSION

Version 0.34

=cut

our $VERSION = '0.34';

# admin1.db is from http://download.geonames.org/export/dump/admin1CodesASCII.txt

use Geo::Coder::Free::DB;

our @ISA = ('Geo::Coder::Free::DB');

sub _open {
	my $self = shift;

	return $self->SUPER::_open(sep_char => "\t", column_names => ['concatenated_codes', 'name', 'asciiname', 'geonameId']);
}

1;
