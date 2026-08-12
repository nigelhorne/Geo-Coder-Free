package Geo::Coder::Free;

use strict;
use warnings;
use autodie qw(:all);

use Carp;
use Config::Auto;
use Geo::Coder::Abbreviations;
use Geo::Coder::Free::Local;
use Geo::Coder::Free::MaxMind;
use Geo::Coder::Free::OpenAddresses;
use Object::Configure;
use Params::Get;
use Readonly;
use Scalar::Util;

=encoding utf-8

=head1 NAME

Geo::Coder::Free - Geocoding using free, locally-hosted databases

=head1 VERSION

Version 0.42

=cut

our $VERSION = '0.42';

=head1 SYNOPSIS

    use Geo::Coder::Free;

    my $geo = Geo::Coder::Free->new();
    my $pt  = $geo->geocode(location => 'Ramsgate, Kent, UK');
    printf "%.6f, %.6f\n", $pt->lat(), $pt->long();

    # With OpenAddresses/WhoOnFirst data:
    my $geo2 = Geo::Coder::Free->new(openaddr => $ENV{OPENADDR_HOME});
    my $pt2  = $geo2->geocode(location => '1600 Pennsylvania Avenue NW, Washington DC, USA');

    # Free-text scanning:
    my @hits = $geo2->geocode(scantext => 'She grew up in Ramsgate, Kent.',
                              region   => 'GB');

=head1 DESCRIPTION

C<Geo::Coder::Free> translates addresses into latitude/longitude coordinates
using local SQLite databases built from free data sources — MaxMind/GeoNames,
OpenAddresses, Who's On First, OpenStreetMap, and dr5hn's countries/states/cities
database.  It deliberately avoids paid or rate-limited online geocoding services.

Geocoding is attempted in priority order:

=over 4

=item 1. C<Geo::Coder::Free::Local> — user-curated CSV entries (highest confidence)

=item 2. C<Geo::Coder::Free::OpenAddresses> — requires C<OPENADDR_HOME>

=item 3. C<Geo::Coder::Free::MaxMind> — bundled, always available

=back

=head1 LIMITATIONS

=over 4

=item * C<scantext> mode only finds locations in OpenAddresses; it falls back
silently when C<OPENADDR_HOME> is not set (B<FIXME>: should warn).

=item * C<_abbreviate> and C<_normalize> are package functions called cross-package
by C<Local.pm>, creating a tight coupling that prevents marking them C<:Private>.
The correct fix is a C<Geo::Coder::Free::Utils> module; deferred.

=item * The C<__DATA__> alternatives table is hard-coded; it should live in a
user-editable config file.

=item * The address-regex scantext path misses birth-year sentences such as
C<"She was born May 21, 1937 in Noblesville, IN."> because the regex requires
a preceding capital-letter word directly before the city.

=item * C<reverse_geocode> is only partially implemented; the MaxMind path does
not return meaningful results.

=back

=cut

# -----------------------------------------------------------------------
# Module-level singletons — initialised once, shared across all instances.
# Using 'our' so that test code can reset them between test runs if needed.
# -----------------------------------------------------------------------
our $alternatives;
our $abbreviations;

# -----------------------------------------------------------------------
# Error-message table.  All user-facing strings live here so that a future
# i18n layer only needs to swap this hash, not touch every call site.
# -----------------------------------------------------------------------
my %_MESSAGES = (
	usage_geocode       => 'Usage: %s::geocode(location => $location|scantext => $text)',
	usage_reverse       => 'Usage: %s::reverse_geocode(latlng => "$lat,$long")',
	invalid_location    => '%s: invalid location to geocode(), %s',
	invalid_scantext    => '%s: invalid scantext to geocode(), %s',
	geocoding_failed    => '%s: geocoding failed',
	reverse_unsupported => 'Reverse lookup is not yet supported',
	use_arrow_new       => '%s: use ->new() not ::new() to instantiate',
	bad_ref_arg         => 'Usage: %s — do not pass a non-hash reference',
);

# Confidence thresholds for scantext results, expressed as named constants
# rather than magic numbers so call sites document intent.
Readonly::Scalar my $CONF_TRIPLET => 0.8;
Readonly::Scalar my $CONF_DUPLET  => 0.7;
Readonly::Scalar my $CONF_REGEX   => 0.7;

# Stopwords excluded from word-window scantext searches.
my %_COMMON_WORDS = map { $_ => 1 } qw(
	a age an and at be by cross for how i in is more of on or over pm
	road she side some the to was with
);

=head1 METHODS

=head2 new

=head3 SYNOPSIS

    my $geo = Geo::Coder::Free->new();
    my $geo = Geo::Coder::Free->new(openaddr => '/data/openaddr');
    my $geo = Geo::Coder::Free->new(directory => '/data/maxmind');

=head3 DESCRIPTION

Constructor.  Accepts a hash or hashref of options.  If called without
C<openaddr>, the module checks C<$ENV{OPENADDR_HOME}> before giving up.

=head3 API SPECIFICATION

    # (Params::Validate schema)
    openaddr  => SCALAR | undef   # path to OpenAddresses/WOF data dir
    directory => SCALAR | undef   # path to MaxMind/GeoNames files
    cache     => OBJECT | undef   # CHI-compatible cache object

Returns: Blessed C<Geo::Coder::Free> instance.

=head3 EXAMPLE

    use Geo::Coder::Free;

    # Minimal — uses only the bundled MaxMind data:
    my $geo = Geo::Coder::Free->new();

    # Full — also searches OpenAddresses/WOF:
    my $geo = Geo::Coder::Free->new(openaddr => $ENV{OPENADDR_HOME});

=head3 MESSAGES

    use ->new() not ::new()   Called as a function; use arrow syntax.

=head3 FORMAL SPECIFICATION

    GeoCoderFreeState ::= ⟨⟨ maxmind     : MaxMind_Geocoder;
                              openaddr    : OpenAddr_Geocoder | undef;
                              alternatives: Map[STRING → STRING];
                              cache       : Cache | undef ⟩⟩

    Init : Params → GeoCoderFreeState
    ∀ p : Params •
      let oa_path == p.openaddr ∨ env.OPENADDR_HOME •
      GeoCoderFreeState.openaddr = if oa_path ≠ ∅ then OpenAddresses(oa_path) else undef fi

=cut

sub new {
	my $class = shift;

	my $params = Params::Get::get_params(undef, @_) // {};

	# Called as a function (Geo::Coder::Free::new) rather than a method
	if (!defined($class)) {
		if (keys %{$params}) {
			Carp::carp(_i18n('use_arrow_new', __PACKAGE__));
			return;
		}
		$class = __PACKAGE__;	# FIXME: only works with no arguments
	} elsif (Scalar::Util::blessed($class)) {
		return bless { %{$class}, %{$params} }, ref($class);
	}

	# Populate the alternatives map once from __DATA__ and cache it
	# across all instances.  Config::Auto parses the INI-like DATA block.
	if (!$alternatives) {
		my $keep = $/;
		local $/ = undef;
		my $data = <DATA>;
		$/ = $keep;

		$alternatives = Config::Auto->new(source => $data)->parse();
		# Config::Auto turns multi-value keys into arrayrefs; flatten them.
		while (my ($key, $value) = each %{$alternatives}) {
			$alternatives->{$key} = join(', ', @{$value});
		}
	}

	# Resolve OPENADDR_HOME before Object::Configure so plug-ins can see it
	if (!defined($params->{'openaddr'}) && $ENV{'OPENADDR_HOME'}) {
		$params->{'openaddr'} = $ENV{'OPENADDR_HOME'};
	}

	$params = Object::Configure::configure($class, $params);

	my $rc = {
		%{$params},
		maxmind      => Geo::Coder::Free::MaxMind->new($params),
		alternatives => $alternatives,
	};

	if ($params->{'openaddr'}) {
		$rc->{'openaddr'} = Geo::Coder::Free::OpenAddresses->new(id => 'md5', %{$params});
	}
	if (my $cache = $params->{'cache'}) {
		$rc->{'cache'} = $cache;
	}

	return bless $rc, $class;
}

=head2 geocode

=head3 SYNOPSIS

    # Standard lookup (returns a Geo::Location::Point or undef)
    my $pt = $geo->geocode(location => 'Ramsgate, Kent, UK');
    printf "lat=%.6f lon=%.6f\n", $pt->lat(), $pt->long();

    # Scantext — returns a list of Geo::Location::Point objects
    my @hits = $geo->geocode(
        scantext     => 'She lived in Ramsgate, Kent.',
        region       => 'GB',
        ignore_words => [qw(lived)],
    );

    # Invocation flexibility (all equivalent)
    $geo->geocode('Ramsgate, Kent, UK');
    $geo->geocode({ location => 'Ramsgate, Kent, UK' });
    $geo->geocode(location => 'Ramsgate, Kent, UK');

=head3 API SPECIFICATION

    location     => SCALAR          # address string (mutually exclusive with scantext)
    scantext     => SCALAR          # free text to scan for place names
    region       => SCALAR | undef  # ISO 3166-1 alpha-2 country code hint
    ignore_words => ARRAYREF | undef

    Returns (scalar context): Geo::Location::Point | undef
    Returns (list context):   list of Geo::Location::Point

=head3 MESSAGES

    Usage: ...::geocode(...)        No location or scantext argument given.
    invalid location to geocode()   location is purely numeric.
    invalid scantext to geocode()   scantext is purely numeric.

=head3 FORMAL SPECIFICATION

    Geocode : Address × Region? → Point?
    ∀ addr : Address; r : Region? •
      let backends == [Local, OpenAddresses, MaxMind] •
      result = first { defined } map { b.geocode(addr, r) } backends

=head3 PSEUDOCODE

    if self is not a blessed object → delegate to new()->geocode(@args)
    normalise @_ into %params
    validate: location is not purely numeric; scantext is not purely numeric
    if openaddr backend is available:
        if scantext:
            try the raw scantext string as a direct location
            build stopword set from %_COMMON_WORDS + ignore_words param
            try 3-word windows (triplets) at confidence 0.8
            try 2-word windows (duplets) at confidence 0.7
            try the address-pattern regex at confidence 0.7
            try region-specific address finders (GB / US / CA)
            mark scantext as a miss; return undef
        else:
            try openaddr backend
            try local backend
            try __DATA__ alternatives map
    try maxmind backend for location lookups
    croak if no scantext and no location

=cut

sub geocode {
	my $self = shift;

	# Handle being called as a function rather than a method
	if (!ref($self)) {
		if (scalar @_) {
			return __PACKAGE__->new()->geocode(@_);
		} elsif (!defined($self)) {
			Carp::croak(_i18n('usage_geocode', __PACKAGE__));
		} elsif ($self eq __PACKAGE__) {
			Carp::croak(_i18n('usage_geocode', $self));
		}
		return __PACKAGE__->new()->geocode($self);
	} elsif (ref($self) eq 'HASH') {
		return __PACKAGE__->new()->geocode($self);
	}

	my %params = _normalize_args(_i18n('usage_geocode', __PACKAGE__), 'location', @_);

	# Reject pure-numeric inputs early — they are never valid addresses
	if (defined($params{'location'}) && $params{'location'} !~ /\D/) {
		Carp::croak(_i18n('invalid_location', __PACKAGE__, $params{'location'}))
			if length($params{'location'});
		return;
	}
	if (defined($params{'scantext'}) && $params{'scantext'} !~ /\D/) {
		Carp::croak(_i18n('invalid_scantext', __PACKAGE__, $params{'scantext'}))
			if length($params{'scantext'});
		return;
	}

	if ($self->{'openaddr'}) {
		if (my $scantext = $params{'scantext'}) {
			return if $self->{'scantext_misses'}{$scantext};

			# First try the whole scantext as a direct location lookup —
			# saves work when the text happens to be a valid address string.
			$self->{'local'} ||= Geo::Coder::Free::Local->new();
			my @direct = grep { defined }
				$self->{'local'}->geocode($scantext),
				$self->{'openaddr'}->geocode($scantext),
				$self->{'maxmind'}->geocode($scantext);
			return @direct if @direct;

			my $region = $params{'region'};

			# Merge caller-supplied ignore_words with the module-level stoplist
			my %ignore_words = %_COMMON_WORDS;
			if (my $iw = $params{'ignore_words'}) {
				$ignore_words{lc $_} = 1 for @{$iw};
			}

			my @rc;

			# 3-word window search
			my @triplets = _find_word_ngrams($scantext, 3, \%ignore_words);
			my $res = $self->_resolve_scan_candidates(\@triplets, $region, $CONF_TRIPLET, $scantext);
			if (@{$res}) {
				return wantarray ? @{$res} : $res->[0];
			}

			# 2-word window search
			my @duplets = _find_word_ngrams($scantext, 2, \%ignore_words);
			$res = $self->_resolve_scan_candidates(\@duplets, $region, $CONF_DUPLET, $scantext);
			if (@{$res}) {
				return wantarray ? @{$res} : $res->[0];
			}

			# Regex-based address pattern — catches "City, ST"-style fragments.
			# Note: misses sentences like "born May 21, 1937 in Noblesville, IN"
			# because the pattern requires a capitalised word before the city.
			my @regex_matches = $scantext =~
				/\b(?:\d+\s+)?(?:[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\.?),\s*
				 (?:[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*(?:,\s*[A-Z]{2,})*)\b/gx;
			my @places = grep { defined && $_ ne '' } @regex_matches;
			$res = $self->_resolve_scan_candidates(\@places, $region, $CONF_REGEX, $scantext);
			if (@{$res}) {
				return wantarray ? @{$res} : $res->[0];
			}

			# Region-specific structured address patterns
			if ($region) {
				my @candidates;
				if    ($region eq 'GB') { @candidates = _find_gb_addresses($scantext) }
				elsif ($region eq 'US') { @candidates = _find_us_addresses($scantext) }
				elsif ($region eq 'Canada') { @candidates = _find_ca_addresses($scantext) }

				if (@candidates) {
					my @regional;
					for my $candidate (@candidates) {
						next if $ignore_words{lc $candidate};
						my @hits = grep { defined }
							$self->{'openaddr'}->geocode("$candidate, $region");
						push @regional, @hits if @hits;
					}
					return @regional if @regional;
				}
			}

			$self->{'scantext_misses'}{$scantext} = 1;
			return;
		}

		# Standard (non-scantext) lookup path
		if (wantarray) {
			my @rc = $self->{'openaddr'}->geocode(\%params);
			return @rc if @rc && $rc[0];
			$self->{'local'} ||= Geo::Coder::Free::Local->new();
			@rc = $self->{'local'}->geocode(\%params);
			return @rc if @rc && $rc[0];
		} else {
			if (my $rc = $self->{'openaddr'}->geocode(\%params)) {
				return $rc;
			}
			$self->{'local'} ||= Geo::Coder::Free::Local->new();
			if (my $rc = $self->{'local'}->geocode(\%params)) {
				return $rc;
			}
		}

		# Try the alternatives table — hand-curated mappings for locations that
		# the databases have under slightly different names.
		if (!$params{'scantext'}) {
			if (my $alt = $self->{'alternatives'}) {
				my $location = $params{'location'};
				while (my ($key, $value) = each %{$alt}) {
					next unless $location =~ $key;
					(my $new_loc = $location) =~ s/$key/$value/;
					$params{'location'} = $new_loc;
					if (my $rc = $self->geocode(\%params)) {
						return $rc;
					}
					# Also try the comma-free variant ("Tyne and Wear" etc.)
					if ($value =~ /, /) {
						(my $flat = $value) =~ s/,//g;
						($new_loc = $location) =~ s/$key/$flat/;
						$params{'location'} = $new_loc;
						if (my $rc = $self->geocode(\%params)) {
							return $rc;
						}
					}
					# Restore for the next iteration
					$params{'location'} = $location;
				}
			}
		}
	}

	# Final fallback: MaxMind for location lookups.
	# Scantext without OPENADDR_HOME will silently reach here and return undef;
	# a proper fix would warn here (see LIMITATIONS).
	if ($params{'location'}) {
		return wantarray
			? $self->{'maxmind'}->geocode(\%params)
			: $self->{'maxmind'}->geocode(\%params);
	}

	Carp::croak(_i18n('usage_geocode', __PACKAGE__)) unless $params{'scantext'};
	return;
}

=head2 reverse_geocode

=head3 SYNOPSIS

    my $loc = $geo->reverse_geocode(latlng => '51.3341,-1.4159');

=head3 DESCRIPTION

Translates a latitude/longitude pair back to a place name.
B<Partially implemented>: the MaxMind backend does not return meaningful results.
OpenAddresses is attempted first when available.

=head3 API SPECIFICATION

    latlng => "$lat,$long"   # comma-separated decimal degrees

    Returns: Geo::Location::Point | undef

=cut

sub reverse_geocode {
	my $self = shift;

	if (!ref($self)) {
		if (scalar @_) {
			return __PACKAGE__->new()->reverse_geocode(@_);
		} elsif (!defined($self)) {
			Carp::croak(_i18n('usage_reverse', __PACKAGE__));
		} elsif ($self eq __PACKAGE__) {
			Carp::croak(_i18n('usage_reverse', $self));
		}
		return __PACKAGE__->new()->reverse_geocode($self);
	} elsif (ref($self) eq 'HASH') {
		return __PACKAGE__->new()->reverse_geocode($self);
	}

	my %params = _normalize_args(_i18n('usage_reverse', __PACKAGE__), 'latlng', @_);

	# Require at least one location parameter — give a usage error rather than
	# a cryptic "not yet supported" message when the caller omits all of them.
	unless ($params{'latlng'} || $params{'lat'} || $params{'lon'} || $params{'long'}) {
		Carp::croak(_i18n('usage_reverse', __PACKAGE__));
	}

	if ($self->{'openaddr'}) {
		return wantarray
			? $self->{'openaddr'}->reverse_geocode(\%params)
			: $self->{'openaddr'}->reverse_geocode(\%params);
	}

	if ($params{'latlng'}) {
		return wantarray
			? $self->{'maxmind'}->reverse_geocode(\%params)
			: $self->{'maxmind'}->reverse_geocode(\%params);
	}

	Carp::croak(_i18n('reverse_unsupported'));
}

=head2 ua

Does nothing.  Present for drop-in compatibility with other Geo::Coder::* modules.

=cut

sub ua { }

=head2 run

Command-line entry point.  Use as:

    perl lib/Geo/Coder/Free.pm 1600 Pennsylvania Avenue NW, Washington DC

=cut

__PACKAGE__->run(@ARGV) unless caller();

sub run {
	require Data::Dumper;

	my $class    = shift;
	my $location = join ' ', @_;

	my @rc = $ENV{'OPENADDR_HOME'}
		? $class->new(openaddr => $ENV{'OPENADDR_HOME'})->geocode($location)
		: $class->new()->geocode($location);

	Carp::croak(_i18n('geocoding_failed', $0)) unless @rc;

	print Data::Dumper->new([\@rc])->Dump();
}

# -----------------------------------------------------------------------
# Private helpers
# -----------------------------------------------------------------------

# Purpose:  Return a formatted message string from the message table.
#           Falls back to the raw key so call sites never die on a missing key.
# Entry:    $key — message key; @args — sprintf format arguments.
# Exit:     Formatted string.
# Side Effects: None.
sub _i18n {
	my ($key, @args) = @_;
	my $fmt = $_MESSAGES{$key} // $key;
	return @args ? sprintf($fmt, @args) : $fmt;
}

# Purpose:  Normalise the four calling conventions accepted by geocode/reverse_geocode:
#             hashref, even-length key-val list, odd-length list, single bare string.
# Entry:    $error_msg — message to croak if a non-hash reference is passed.
#           $bare_key  — hash key to assign to a single bare string argument
#                        ('location' for geocode, 'latlng' for reverse_geocode).
#           @args — raw @_ after $self has been shifted.
# Exit:     Flat key-value %params hash.
# Side Effects: None; croaks on unsupported reference argument.
sub _normalize_args {
	my ($error_msg, $bare_key, @args) = @_;
	return %{$args[0]}              if ref($args[0]) eq 'HASH';
	Carp::croak($error_msg)         if ref($args[0]);
	return @args                    if @args && @args % 2 == 0;
	return ($bare_key => $args[0])  if @args;
	return ();
}

# Purpose:  Try to geocode each candidate place string via the openaddr backend,
#           annotating every hit with location/text/confidence metadata and
#           memoising misses to avoid re-querying the same failing string.
# Entry:    $self       — geocoder instance with {openaddr} and {scantext_misses}.
#           $candidates — arrayref of place-name strings to probe.
#           $region     — optional ISO country code appended to each candidate.
#           $confidence — numeric confidence score assigned to all hits.
#           $scantext   — original free text (stored inside each result object).
# Exit:     Arrayref of Geo::Location::Point objects; empty arrayref on no hits.
# Side Effects: Populates $self->{scantext_misses} for every non-matching place.
sub _resolve_scan_candidates {
	my ($self, $candidates, $region, $confidence, $scantext) = @_;
	my @results;
	for my $place (@{$candidates}) {
		my $location = $region ? "$place, $region" : $place;
		next if $self->{'scantext_misses'}{$location};
		my @res = grep { defined } $self->{'openaddr'}->geocode($location);
		if (@res) {
			for my $entry (@res) {
				$entry->{'location'}   = $location;
				$entry->{'text'}       = $scantext;
				$entry->{'confidence'} = $confidence;
			}
			push @results, @res;
		} else {
			$self->{'scantext_misses'}{$location} = 1;
		}
	}
	return \@results;
}

# Purpose:  Slide a window of $n words across $text and return all comma-joined
#           n-grams, excluding pure-numeric tokens and stopwords.
#           Replaces the former _find_word_triplets ($n=3) and
#           _find_word_duplets ($n=2) which were identical except for window size
#           and the duplets version was missing the lc() normalisation on stopwords.
# Entry:    $text — raw string; $n — window size; $stop — stopword hashref.
# Exit:     Flat list of n-gram strings.
# Side Effects: None.
sub _find_word_ngrams {
	my ($text, $n, $stop) = @_;
	$text =~ s/,+/ /g;
	$text =~ s/\s+/ /g;
	$text =~ s/^\s+|\s+$//g;
	my @words = grep { !/^\d+$/ && !$stop->{lc $_} } split /\s+/, $text;
	my @ngrams;
	for my $i (0 .. $#words - ($n - 1)) {
		push @ngrams, join ', ', @words[$i .. $i + $n - 1];
	}
	return @ngrams;
}

# Purpose:  Extract structured US street addresses from free text.
# Entry:    $text — arbitrary string.
# Exit:     List of full address strings matching the US pattern.
# Side Effects: None.
sub _find_us_addresses {
	my $text = shift;
	my @addresses;
	my $re = qr/
		\b (\d{1,5}) \s+
		([A-Za-z0-9\s]+?) \s+
		(Avenue|Ave\.?|Boulevard|Blvd\.?|Road|Rd\.?|Lane|Ln\.?|Drive|Dr\.?|Street|St\.?)
		(\s+[A-Za-z]{2})? ,\s*
		([A-Za-z\s]+) ,\s*
		([A-Z]{2}) \s* (\d{5}(-\d{4})?)? \b
	/x;
	while ($text =~ /$re/g) {
		push @addresses, $&;
	}
	return @addresses;
}

# Purpose:  Extract British-style addresses from free text.
# Entry:    $text — arbitrary string.
# Exit:     List of trimmed address strings.
# Side Effects: None.
sub _find_gb_addresses {
	my $text = shift;
	my @addresses;
	my $re = qr/
		\b (\d{1,5}|\w[\w\s'-]+) \s+
		([A-Za-z0-9\s'-]+) \s*,?\s*
		([A-Za-z\s'-]+)    \s*,?\s*
		([A-Za-z\s'-]+)    \s*,?\s*
		([A-Za-z\s'-]+)    \b
	/x;
	while ($text =~ /$re/g) {
		(my $addr = $&) =~ s/[,\s]+$//;
		push @addresses, $addr;
	}
	return @addresses;
}

# Purpose:  Extract Canadian street addresses from free text.
# Entry:    $text — arbitrary string.
# Exit:     List of full address strings matching the Canadian pattern.
# Side Effects: None.
sub _find_ca_addresses {
	my $text = shift;
	my @addresses;
	my $re = qr/
		\b (\d{1,5}) \s+
		([A-Za-z0-9\s]+?) \s+
		(Avenue|Ave\.?|Boulevard|Blvd\.?|Road|Rd\.?|Lane|Ln\.?|Drive|Dr\.?|Street|St\.?|Circle|Crescent|Cres\.?)
		\s*,\s* ([A-Za-z\s]+) \s*,\s*
		([A-Z]{2}) \s*,?\s*
		([A-Z]\d[A-Z]\s?\d[A-Z]\d)? \b
	/x;
	while ($text =~ /$re/g) {
		push @addresses, $&;
	}
	return @addresses;
}

# Purpose:  Normalise a street name to its abbreviated canonical form.
#           Public (not :Private) because Local.pm calls this cross-package.
#           See LIMITATIONS for the coupling issue.
# Entry:    $street — raw street string (may be multi-word).
# Exit:     Uppercased, abbreviated street string with leading zeros removed.
# Side Effects: Lazy-initialises $abbreviations singleton.
sub _normalize {
	my $street = uc(shift);
	$abbreviations ||= Geo::Coder::Abbreviations->new();

	if ($street =~ /(.+)\s+(.+)\s+(.+)/) {
		my $a;
		if (lc($2) ne 'cross' && ($a = $abbreviations->abbreviate($2))) {
			$street = "$1 $a $3";
		} elsif ($a = $abbreviations->abbreviate($3)) {
			$street = "$1 $2 $a";
		}
	} elsif ($street =~ /(.+)\s(.+)$/) {
		if (my $a = $abbreviations->abbreviate($2)) {
			$street = "$1 $a";
		}
	}
	$street =~ s/^0+//;	# "04th St" → "4th St"
	return $street;
}

# Purpose:  Abbreviate a single street-type word (e.g. "Street" → "ST").
#           Public (not :Private) because Local.pm calls this cross-package.
#           See LIMITATIONS.
# Entry:    $type — street-type word.
# Exit:     Abbreviated uppercase string, or the original if no abbreviation found.
# Side Effects: Lazy-initialises $abbreviations singleton.
sub _abbreviate {
	my $type = uc(shift);
	$abbreviations ||= Geo::Coder::Abbreviations->new();
	return $abbreviations->abbreviate($type) || $type;
}

=head1 GETTING STARTED

Set C<OPENADDR_HOME> to an empty directory then run:

    bin/download_databases   # downloads OpenAddr, WOF, OSM, dr5hn data
    bin/create_sqlite        # MaxMind CSV → SQLite
    bin/create_db            # builds openaddresses.sql from all sources

=head1 BUGS

Some lookups fail.  Please file a bug report at
L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Geo-Coder-Free>.

The MaxMind data contains cities only.
The OpenAddresses data does not cover the whole globe.
C<London, England> cannot be parsed yet.

=head1 SEE ALSO

L<Geo::Coder::Free::Local>, L<Geo::Coder::Free::MaxMind>,
L<Geo::Coder::Free::OpenAddresses>,
L<https://openaddresses.io/>, L<https://www.maxmind.com/>,
L<https://www.geonames.org/>, L<https://www.whosonfirst.org/>.

=head1 AUTHOR

Nigel Horne C<< <njh@nigelhorne.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2017-2026 Nigel Horne.  Licensed under GPL2 for personal use.

This product uses GeoLite2 data created by MaxMind,
available from L<https://www.maxmind.com/>.

=cut

1;

# Common mappings for looser lookups.  A future version should load these from
# an external, user-editable config file.  See also Local.pm's %alternatives.
__DATA__
St Lawrence, Thanet, Kent = Ramsgate, Kent
St Peters, Thanet, Kent = Broadstairs, Kent
Minster, Thanet, Kent = Ramsgate, Kent
Tyne and Wear = Borough of North Tyneside
