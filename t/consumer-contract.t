#!perl -w

# Reader/producer contract for the Geo::Location::Point objects that
# Geo::Coder::Free hands back.
#
# PART 1  every key this test claims a producer sets is checked against the
#         source that is supposed to set it, so a backend that quietly stops
#         stamping (say) 'database' fails here.
# PART 2  every registered consumer of a Geo::Coder::Free result may only read
#         the keys that *every* backend guarantees.  Reading a key that only
#         some backends set is the bug this test exists for: the value is undef
#         for the other backends and the caller silently takes a wrong branch.
# PART 3  discovery: a file that can receive a Geo::Coder::Free result but is
#         not registered is a failure, so a new consumer cannot slip past
#         PART 2 unnoticed.
#
# Parts 2 and 3 need the sibling checkouts (HTML-Genealogy-Map and friends) that
# share this workspace; they are skipped, with a diagnostic, when this dist is
# installed on its own.  PART 1 runs everywhere.

use strict;
use warnings;

use Test::Most;
use File::Basename qw(basename dirname);
use File::Find ();
use File::Spec;
use Cwd qw(abs_path);

my $DIST_ROOT = dirname(dirname(abs_path($0)));
$DIST_ROOT = abs_path(File::Spec->curdir())
	unless -d File::Spec->catdir($DIST_ROOT, 'lib');
my $WORKSPACE = dirname($DIST_ROOT);
my $DIST_NAME = basename($DIST_ROOT);

# Prefer the sibling Geo::Location::Point checkout over an installed copy when
# this is a workspace: the contract below is about the code in this tree.
BEGIN {
	my $sibling = File::Spec->catdir(
		dirname(dirname(dirname(abs_path($0)))), 'Geo-Location-Point', 'lib');
	unshift @INC, $sibling if(-d $sibling);
}

# ---------------------------------------------------------------------------
# The contract
# ---------------------------------------------------------------------------

# Set on every result, whichever backend answered.  'lat', 'long' and 'lng' come
# from Geo::Location::Point::new() (long/lng are synonyms); 'database' names the
# backend and is set by all three of them.
my @GUARANTEED = qw(lat long lng database);

# Set by some backends or only by some paths through a backend.  A consumer may
# not read these off a result - it can be undef for another backend - unless it
# registers the reason in %CONSUMERS below.
my %CONDITIONAL = (
	location   => 'OpenAddresses and Local set it; the MaxMind cities path does not',
	confidence => 'the MaxMind cities path, Local and the scantext path set it; OpenAddresses does not',
	text       => 'only the scantext path sets it',
	lon        => "only MaxMind's %known_locations shortcut sets it - Point::new() makes long and lng, never lon",
);

# Part 1: file => keys the file is responsible for setting, with the evidence
# checked below.  The latitude/longitude that become lat/long/lng arrive
# differently in each backend (OpenAddresses passes them as literals, MaxMind and
# Local splat in a database row), so only the explicit keys are listed here.
my %PRODUCER_EVIDENCE = (
	'lib/Geo/Coder/Free/OpenAddresses.pm'        => [qw(lat long lng location database)],
	'lib/Geo/Coder/Free/MaxMind.pm'              => [qw(database confidence lon)],
	'lib/Geo/Coder/Free/Local.pm'                => [qw(location confidence database)],
	'lib/Geo/Coder/Free.pm'                      => [qw(location text confidence)],
	"$WORKSPACE/Geo-Location-Point/lib/Geo/Location/Point.pm" => [qw(lat long lng)],
);

# Part 2: files that can be handed a Geo::Coder::Free result.  'may_rely_on'
# names the keys the file reads beyond @GUARANTEED, each with the reason it is
# safe; a read that is not listed there fails the test, and an entry that is no
# longer read is reported as stale (see the end of PART 2).
#
# Discovered by scanning the workspace for files that both mention
# Geo::Coder::Free and bind a variable from a geocode() call - see PART 3, which
# fails if a new one appears and is not registered here or in %IGNORED.
my %CONSUMERS = (
	'HTML-Genealogy-Map/lib/HTML/Genealogy/Map.pm' => {
		# The geocoder is injected (->onload_render(geocoder => ...)), and
		# HTML-Genealogy-Map's own POD and tests pass Geo::Coder::Free, so a
		# result here is a Geo::Location::Point, or a plain hash from some other
		# geocoder.  _coordinates() reads the position, _is_local() reads the
		# provenance.
		# Keyed by sub, not just by key: an exception covers the read inside the
		# adapter it was reviewed for, and the same key read anywhere else in the
		# file is still an offence.  A helper outside the adapters that reads an
		# unset key cannot hide behind one of these entries.
		'may_rely_on' => {
			'_coordinates' => {
				'lon' => "the third fallback, after {long} and {lng}, for the geocoders that"
					. ' spell longitude that way. Never the only evidence of a position, and'
					. ' never used to test whether a lookup succeeded',
			},
			'_is_local' => {
				'geocoder' => "a secondary hint, tested after {database}. A wrapper such as"
					. ' Geo::Coder::List stamps it; Geo::Coder::Free does not, which is why'
					. ' {database} is tested first and decides on its own',
			},
		},
	},
);

# Files that match the discovery rule but are not consumers of a raw
# Geo::Coder::Free result.  Keyed by path prefix, with the reason it is safe.
my @IGNORED = (
	[
		'Geo-Coder-List/',
		"reads Geo::Coder::List's own normalised output, which sets lon, lng,"
		. ' geometry and geocoder itself and treats lon as an optional alias'
	],
	[
		'Config-Abstraction/',
		'names Geo::Coder::Free as a configuration value; it never reads a result',
	],
	[
		'NJH-Snippets/',
		'optional chaining in a helper; reads no result key',
	],
);

# Documented accessors of Geo::Location::Point, plus the AUTOLOAD-documented
# 'attr'.  A result object is read through these, never through a raw hash key.
my @ACCESSORS = qw(lat latitude long lng longitude distance equal not_equal
	tz timezone as_string as_uri attr new);

# Class introspection, not result data: asking whether a result can answer
# latitude() is not the same as reading an attribute off it.
my @INSPECTION = qw(can isa DOES);

# ---------------------------------------------------------------------------
# PART 1 - the producers still set what the contract says they set
# ---------------------------------------------------------------------------

sub _slurp
{
	my $file = shift;

	open(my $fh, '<', $file) or return;
	local $/;
	my $content = <$fh>;
	close($fh);

	return $content;
}

sub _sets_key
{
	my ($text, $key) = @_;

	my $k = quotemeta($key);

	# 'key' => value  /  key => value
	return 1 if $text =~ /['"]$k['"]\s*=>/;
	return 1 if $text =~ /(?:^|[\s(,{])$k\s*=>/m;
	# $obj->{'key'} = value  /  $obj->{'key'} //= value
	return 1 if $text =~ /->\s*\{\s*['"]?$k['"]?\s*\}\s*(?:=[^=]|\|\|=|\/\/=)/;

	return 0;
}

subtest 'the producers still set the keys the contract claims' => sub {
	for my $file (sort keys %PRODUCER_EVIDENCE) {
		my $path = ($file =~ m{^\s*/} || $file =~ m{^[A-Za-z]:})
			? $file
			: File::Spec->catfile($DIST_ROOT, split(m{/}, $file));
		my $text = _slurp($path);
		ok(defined($text), "$file is readable") or next;

		for my $key (@{$PRODUCER_EVIDENCE{$file}}) {
			ok(_sets_key($text, $key), "$file sets '$key'");
		}
	}
};

# 'lat', 'long' and 'lng' are made by the value object itself, so the guarantee
# that matters is that it still derives them from the documented spellings.
subtest 'Geo::Location::Point derives lat, long and lng' => sub {
	require Geo::Location::Point;

	my $point = Geo::Location::Point->new(latitude => 10, longitude => 20);
	ok($point, 'a point can still be made from latitude/longitude');
	is($point->lat(),  10, 'lat is derived');
	is($point->long(), 20, 'long is derived');
	is($point->lng(),  20, 'lng is derived');
};

# ---------------------------------------------------------------------------
# Reading a consumer
# ---------------------------------------------------------------------------

# Strip POD and comments so that prose about a key is not mistaken for a use of
# it.  Both replacements preserve the line structure, so the line numbers
# reported below point at the real file.
sub _strip
{
	my $text = shift;

	$text =~ s{^=[a-zA-Z].*?^=cut[^\n]*$}{ my $m = $&; $m =~ s/[^\n]//g; $m }gems;
	$text =~ s{^[ \t]*\#[^\n]*}{}gm;

	return $text;
}

sub _line_number
{
	my ($text, $pos) = @_;

	# Count on a copy: a /g match here would clobber the caller's position.
	my $prefix = substr($text, 0, $pos);

	return 1 + ($prefix =~ tr/\n//);
}

# Every ->{key} and ->method() read of a variable that holds a geocoder result.
#
# A variable holds one if it is bound from a ->geocode() / ->reverse_geocode()
# call, or if it is the first parameter of a sub that this file calls with such
# a variable - so a helper that takes the result still counts, whatever it names
# it.  One level of that is enough for the adapters in this workspace, and a
# deeper chain than that is a sign the read belongs in the adapter's registry
# entry.
sub _sub_ranges
{
	my $text = shift;

	my @ranges;
	while($text =~ /^sub\s+(\w+).*?\n.*?^\}/msg) {
		my $name = $1;
		my $start = $-[0];
		my $end = $+[0];
		my $body = substr($text, $start, $end - $start);
		my $param;
		$param = $1 if($body =~ /^\s*my\s+\(?\s*(\$[A-Za-z_]\w*)/m);
		push @ranges, { name => $name, start => $start, end => $end, param => $param };
	}

	return @ranges;
}

sub _enclosing_sub
{
	my ($ranges, $pos) = @_;

	for my $range (@{$ranges}) {
		return $range->{'name'} if($pos >= $range->{'start'} && $pos < $range->{'end'});
	}

	return '(file scope)';
}

sub _reads_of_results
{
	my $text = shift;

	my %bound;
	while($text =~ /(?:my|our|local)?\s*(\$[A-Za-z_]\w*)\s*=\s*[^;{}]*?->(?:reverse_)?geocode\s*\(/g) {
		$bound{$1} = 1;
	}

	my @ranges = _sub_ranges($text);
	my %parameter = map { $_->{'name'} => $_->{'param'} }
		grep { defined($_->{'param'}) } @ranges;

	my $found = 1;
	while($found) {
		$found = 0;
		for my $name (sort keys %parameter) {
			my $param = $parameter{$name};
			next if($bound{$param});
			my $n = quotemeta($name);
			next unless grep { $bound{$_} } keys %bound;
			for my $caller_var (sort keys %bound) {
				my $v = quotemeta($caller_var);
				if($text =~ /\b$n\s*\(\s*$v\b/ || $text =~ /\b$n\s*\(\s*\{\s*\w+\s*=>\s*$v\b/) {
					$bound{$param} = 1;
					$found = 1;
					last;
				}
			}
		}
	}

	my @reads;
	for my $var (sort keys %bound) {
		my $v = quotemeta($var);
		while($text =~ /$v\s*->\s*\{\s*['"]?(\w+)['"]?\s*\}/g) {
			my $at = pos($text);
			push @reads, [$1, _line_number($text, $at), 'key', _enclosing_sub(\@ranges, $at)];
		}
		while($text =~ /$v\s*->\s*(\w+)\s*\(/g) {
			my $at = pos($text);
			push @reads, [$1, _line_number($text, $at), 'accessor', _enclosing_sub(\@ranges, $at)];
		}
	}

	return @reads;
}

sub _why
{
	my $key = shift;

	return $CONDITIONAL{$key} if(exists($CONDITIONAL{$key}));

	return 'no producer in this workspace ever sets it';
}

# ---------------------------------------------------------------------------
# PART 2 - registered consumers read only guaranteed keys
# ---------------------------------------------------------------------------

my $WORKSPACE_PRESENT = -d File::Spec->catdir($WORKSPACE, 'HTML-Genealogy-Map')
	&& -d File::Spec->catdir($WORKSPACE, 'Geo-Location-Point');

subtest 'registered consumers read only what every backend sets' => sub {
	plan skip_all => 'sibling checkouts are not present' unless $WORKSPACE_PRESENT;

	for my $rel (sort keys %CONSUMERS) {
		my $path = File::Spec->catfile($WORKSPACE, split(m{/}, $rel));
		my $raw = _slurp($path);

		ok(defined($raw), "$rel is readable") or next;

		my $may_rely_on = $CONSUMERS{$rel}{'may_rely_on'} || {};
		my @reads = _reads_of_results(_strip($raw));
		my %used = map { $_->[3] . '|' . $_->[0] => 1 } @reads;

		my @offenders;
		for my $read (@reads) {
			my ($key, $line, $kind, $sub) = @{$read};

			next if(grep { $_ eq $key } @GUARANTEED);
			next if($may_rely_on->{$sub} && exists($may_rely_on->{$sub}{$key}));
			next if(($kind eq 'accessor') && grep { $_ eq $key } (@ACCESSORS, @INSPECTION));

			push @offenders, "$rel line $line in $sub() reads '$key' ($kind) - " . _why($key);
		}

		is_deeply(\@offenders, [], "$rel reads only keys every backend sets")
			or diag("\n\t" . join("\n\t", @offenders) . "\n");

		my @stale;
		for my $sub (sort keys %{$may_rely_on}) {
			for my $key (sort keys %{$may_rely_on->{$sub}}) {
				push @stale, "$sub() reads '$key' - " . $may_rely_on->{$sub}{$key}
					unless $used{"$sub|$key"};
			}
		}
		is_deeply(\@stale, [], "$rel still reads the keys it is allowed to rely on")
			or diag("\n\t" . join("\n\t", @stale)
				. "\n\tRemove the stale entry, so the registry keeps describing the code.\n");
	}
};

# ---------------------------------------------------------------------------
# PART 3 - no unregistered consumer
# ---------------------------------------------------------------------------

sub _workspace_sources
{
	my @files;

	my @dists = _children($WORKSPACE);

	for my $dist (sort @dists) {
		next if($dist eq $DIST_NAME);

		my $dir = File::Spec->catdir($WORKSPACE, $dist);
		next unless -d $dir;

		for my $sub (qw(lib bin t xt)) {
			my $root = File::Spec->catdir($dir, $sub);
			next unless -d $root;

			File::Find::find({
				no_chdir => 1,
				wanted   => sub {
					my $path = $File::Find::name;
					$File::Find::prune = 1
						if(-d $path && $path =~ m{/(?:blib|xt|inc|local|node_modules|\.git|\.build)$});
					return unless -f $path;
					return unless $path =~ /\.(?:pm|t|pl|PL|pm6)$/;
					push @files, File::Spec->abs2rel($path, $WORKSPACE);
				},
			}, $root);
		}
	}

	return @files;
}

sub _children
{
	my $dir = shift;

	opendir(my $dh, $dir) or return;
	my @entries = grep { $_ ne '.' && $_ ne '..' && !/^\./ } readdir($dh);
	closedir($dh);

	return @entries;
}

sub _ignored
{
	my $rel = shift;

	for my $rule (@IGNORED) {
		return $rule->[1] if(index($rel, $rule->[0]) == 0);
	}

	return;
}

# Referenced so the documented-accessor list cannot rot silently: a key read as
# an accessor must be a documented method, and every name here is checked to be
# either documented in the POD or actually implemented.
subtest 'the accessor list matches the value object' => sub {
	require Geo::Location::Point;

	my $pod = _slurp(File::Spec->catfile($WORKSPACE, 'Geo-Location-Point',
		'lib', 'Geo', 'Location', 'Point.pm'));
	plan skip_all => 'sibling checkouts are not present' unless defined($pod);

	for my $accessor (@ACCESSORS) {
		ok(Geo::Location::Point->can($accessor) || $pod =~ /^=head2\s+$accessor\b/m
			|| $pod =~ /sub\s+$accessor\b/,
			"$accessor is a documented accessor of Geo::Location::Point");
	}
};

subtest 'every discovered consumer is registered' => sub {
	plan skip_all => 'sibling checkouts are not present' unless $WORKSPACE_PRESENT;

	my @unregistered;
	my @discovered;
	my $checked = 0;
	for my $rel (_workspace_sources()) {
		my $raw = _slurp(File::Spec->catfile($WORKSPACE, split(m{/}, $rel)));
		next unless defined($raw);
		next unless $raw =~ /Geo::Coder::Free/;

		$checked++;
		my $text = _strip($raw);
		next unless grep { $_->[2] } _reads_of_results($text);

		push @discovered, $rel;

		next if(exists($CONSUMERS{$rel}));
		next if(_ignored($rel));

		push @unregistered, $rel;
	}

	cmp_ok($checked, '>', 0, "found sources mentioning Geo::Coder::Free ($checked checked)");
	# Without this the whole subtest could pass by finding nothing at all.
	ok(scalar(grep { exists($CONSUMERS{$_}) } @discovered),
		'the scanner found the registered consumer (' . scalar(@discovered) . ' read a result)');
	is_deeply(\@unregistered, [], 'no unregistered consumer reads a Geo::Coder::Free result')
		or diag("\n\tunregistered consumers of Geo::Coder::Free results:\n\t"
			. join("\n\t", @unregistered)
			. "\n\tRegister each in %CONSUMERS (with its justification) or in \@IGNORED\n\t"
			. "\t(with the reason it cannot receive one).\n");
};

done_testing();
