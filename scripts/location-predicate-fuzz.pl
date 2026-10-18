#!/usr/bin/env perl

# Fuzz the six sibling geocoders' "could this be a location?" rule against
# Geo::Coder::Free::Validate, and report every class of input on which they
# disagree.
#
# Each sibling geocode() asks Geo::Coder::Free::Validate::_valid_location() and
# nothing else, so the harness does not re-implement any of it.  It drives the
# real geocode() with a user agent that dies the moment a lookup would be made,
# and reads the verdict off what happened: a croak naming the input means the
# predicate refused it, a returned value or the sentinel means it was accepted.
# Nothing touches the network.
#
# Usage:
#     perl xt/location-predicate-fuzz.pl [--iterations N] [--seed S] [--check]
#
# The output is Markdown: a table of the curated input classes, then the
# randomised run over scalars, references and undef.  --check turns the exit
# status into a gate: it fails when a sibling's verdict on a scalar or undef
# differs from the rule's, which is what the scheduled CI job runs.  That is the
# runtime half of t/location-rule.t, which reads the same six siblings' source
# for the rule's spellings; this one asks them.
#
# It needs the six checkouts beside this distribution - the layout the CI job
# assembles, and the one an author's workspace has - and says so when they are
# not there rather than reporting a skip that looks like agreement.

use strict;
use warnings;

use FindBin qw($Bin);

# The checkouts sit side by side, and this file is run from different places: the
# workspace root, which is where it was written, and Geo-Coder-Free/xt, which is
# where it lives.  So the workspace is whichever of those holds the
# Geo-Coder-Free checkout, and every sibling has to be in it.
BEGIN {
	require Cwd;
	require File::Spec;

	my @DISTS = qw(
		Geo-Coder-Free
		Geo-Coder-CA
		Geo-Coder-DataScienceToolkit
		Geo-Coder-GeoApify
		Geo-Coder-List
		Geo-Coder-Postcodes
		Geo-Coder-XYZ
	);

	my $workspace;
	for my $candidate ($Bin, "$Bin/..", "$Bin/../..") {
		next unless -d "$candidate/Geo-Coder-Free/lib/Geo/Coder/Free";
		$workspace = $candidate;
		last;
	}
	die 'Cannot find a Geo-Coder-Free checkout beside ', File::Spec->canonpath($Bin), "\n"
		unless defined($workspace);

	# Spelled out without the '..' the candidate was built from: this is the message
	# a build reads when a checkout failed, and it names the directory to look in.
	my $here = Cwd::abs_path($workspace) // File::Spec->canonpath($workspace);
	for my $dist (@DISTS) {
		die "The sibling checkout $dist is not in $here: this fuzz needs all seven checkouts beside each other\n"
			unless -d "$workspace/$dist/lib";
	}

	unshift @INC, map { "$workspace/$_/lib" } @DISTS;
}

use Getopt::Long qw(GetOptions);
use Geo::Coder::Free::Validate qw(_valid_location);

for my $module (qw(
	Geo::Coder::CA
	Geo::Coder::DataScienceToolkit
	Geo::Coder::GeoApify
	Geo::Coder::List
	Geo::Coder::Postcodes
	Geo::Coder::XYZ
)) {
	(my $file = $module) =~ s{::}{/}g;
	require "$file.pm";	## no critic (Modules::RequireBarewordIncludes)
}

# ---------------------------------------------------------------------------
# The stub user agent
# ---------------------------------------------------------------------------

package Fuzz::UA;

sub new { return bless {}, shift }

# Any value that gets this far has passed the predicate: the module is about to
# do the lookup, which is the line the fuzz must not cross.
sub get { die "FUZZ_REACHED_NETWORK\n" }

sub default_header { return $_[0] }
sub env_proxy      { return $_[0] }
sub ssl_opts       { return $_[0] }
sub DESTROY        { }

# Values with a stringification of their own, for the reference classes.
# Geo::Coder::List sends its "not a location" complaints to a logger rather
# than through warn/croak, so the harness supplies one that records them.
package Fuzz::Logger;

sub new { return bless { events => [] }, shift }

sub _record
{
	my $self = shift;
	my $level = shift;

	push @{$self->{'events'}}, "$level: " . join('', @_);

	return;
}

sub warn  { return $_[0]->_record('warn',  @_[1 .. $#_]) }
sub error { return $_[0]->_record('error', @_[1 .. $#_]) }
sub debug { return; }
sub info  { return; }
sub trace { return; }
sub events { return $_[0]->{'events'} }
sub clear { return @{$_[0]->{'events'}} = () }
sub DESTROY { }

package Fuzz::Plain;

sub new { return bless {}, shift }

package Fuzz::Str;

use overload '""' => sub { $_[0]->{'s'} }, fallback => 1;

sub new
{
	my ($class, $s) = @_;

	return bless { s => $s }, $class;
}

# A reference whose boolean value is false, as a db row object might be.
package Fuzz::FalseStr;

use overload '""' => sub { $_[0]->{'s'} }, 'bool' => sub { 0 }, fallback => 1;

sub new
{
	my ($class, $s) = @_;

	return bless { s => $s }, $class;
}

package main;

# ---------------------------------------------------------------------------
# The predicates under test
# ---------------------------------------------------------------------------

my @SIBLINGS = (
	{
		name   => 'Geo::Coder::CA',
		file   => 'Geo-Coder-CA/lib/Geo/Coder/CA.pm',
		maker  => sub { Geo::Coder::CA->new(ua => Fuzz::UA->new(), host => 'localhost') },
	},
	{
		name   => 'Geo::Coder::DataScienceToolkit',
		file   => 'Geo-Coder-DataScienceToolkit/lib/Geo/Coder/DataScienceToolkit.pm',
		# This one's new() hands Object::Configure an arrayref, so the user agent
		# goes in through the accessor instead of the constructor.
		maker  => sub {
			my $geocoder = Geo::Coder::DataScienceToolkit->new();
			$geocoder->ua(Fuzz::UA->new());
			return $geocoder;
		},
	},
	{
		name   => 'Geo::Coder::GeoApify',
		file   => 'Geo-Coder-GeoApify/lib/Geo/Coder/GeoApify.pm',
		maker  => sub {
			Geo::Coder::GeoApify->new(
				apiKey => 'fuzz',
				ua     => Fuzz::UA->new(),
				host   => 'localhost',
			)
		},
	},
	{
		name   => 'Geo::Coder::List',
		file   => 'Geo-Coder-List/lib/Geo/Coder/List.pm',
		# Object::Configure puts its own logger in, so ours is installed after
		# construction rather than passed to new().
		maker  => sub {
			my $list = Geo::Coder::List->new();
			$list->{'logger'} = Fuzz::Logger->new();
			return $list;
		},
		logger => 1,	# read the recorded messages after each call
	},
	{
		name   => 'Geo::Coder::Postcodes',
		file   => 'Geo-Coder-Postcodes/lib/Geo/Coder/Postcodes.pm',
		maker  => sub { Geo::Coder::Postcodes->new(ua => Fuzz::UA->new(), host => 'localhost') },
	},
	{
		name   => 'Geo::Coder::XYZ',
		file   => 'Geo-Coder-XYZ/lib/Geo/Coder/XYZ.pm',
		maker  => sub { Geo::Coder::XYZ->new(ua => Fuzz::UA->new(), host => 'localhost') },
	},
);

sub build_predicates
{
	for my $sibling (@SIBLINGS) {
		my $object = eval { $sibling->{'maker'}->() };
		die "Cannot construct $sibling->{'name'}: $@" if $@;
		$sibling->{'object'} = $object;
		$sibling->{'logger'} = $object->{'logger'} if $sibling->{'logger'};
	}

	return @SIBLINGS;
}

# ---------------------------------------------------------------------------
# One verdict
# ---------------------------------------------------------------------------

sub _oneline
{
	my $text = shift;

	$text =~ s/\s+/ /g;
	$text =~ s/^\s+|\s+$//g;

	return $text;
}

# 'REJECT' when the predicate refused the value; 'ACCEPT' when it let it
# through to the lookup (or returned before reaching one, as List does with no
# geocoders); 'ERROR' for anything the harness did not anticipate, which is
# itself worth reporting.
sub verdict
{
	my ($sibling, $value) = @_;

	my @warnings;
	$sibling->{'logger'}->clear() if $sibling->{'logger'};
	my $returned = eval {
		local $SIG{__WARN__} = sub { push @warnings, $_[0] };
		$sibling->{'object'}->geocode(location => $value);
		1;
	};
	my $error = $@ // '';
	push @warnings, @{$sibling->{'logger'}->events()} if $sibling->{'logger'};

	if(!$returned) {
		return ('ACCEPT', 'reached the lookup')
			if $error =~ /FUZZ_REACHED_NETWORK/;
		# Postcodes.io rejects an address after the location predicate has
		# accepted it; that is the endpoint's policy, not the predicate.
		return ('ACCEPT', 'post-predicate policy: ' . _oneline($error))
			if $error =~ /only supports towns/;
		return ('REJECT', _oneline($error))
			if $error =~ /invalid input|Usage:/;
		return ('ERROR', _oneline($error));
	}

	# Geo::Coder::List warns and returns for undef and '' rather than croaking,
	# and with a logger configured it does not even warn.
	for my $warning (@warnings) {
		return ('REJECT', _oneline($warning))
			if $warning =~ /usage: geocode|invalid input/i;
	}

	return ('ACCEPT', 'returned without a lookup');
}

sub free_verdict
{
	my $value = shift;

	return _valid_location($value) ? 'ACCEPT' : 'REJECT';
}

# ---------------------------------------------------------------------------
# The curated classes
# ---------------------------------------------------------------------------

sub blessed
{
	my ($class, $string) = @_;

	return $class->new($string);
}

my @CLASSES = (
	{
		name   => 'undef',
		values => [undef],
	},
	{
		name   => 'empty string',
		values => [''],
	},
	{
		name   => 'zero',
		values => ['0', 0, 0.0],
	},
	{
		name   => 'digits only',
		values => [
			'1',
			'0044',
			'12345678901234567890',
			'9' x 200,
			"\x{0661}\x{0662}",	# Arabic-Indic digits
			"\x{FF11}\x{FF12}",	# fullwidth digits
		],
	},
	{
		name   => 'string with a non-digit',
		values => [
			'London',
			'Ramsgate, Kent',
			' ',
			'-',
			'+44',
			'3.14',
			"12\n",
			'12a',
			"\x{00E9}",
			'0 but true',
		],
	},
	{
		name   => 'unblessed reference',
		values => [
			\1,
			[1, 2],
			{ a => 1 },
			sub { },
			\*STDOUT,
			qr/x/,
		],
		note   => 'A reference is not a string, so the rule refuses it before it looks'
			. ' at anything else; the string form `ARRAY(0x...)` contains a non-digit and'
			. ' is what a check on the string would have accepted.',
	},
	{
		name   => 'blessed reference, plain',
		values => [blessed('Fuzz::Plain')],
		note   => 'As above: the default string form `Fuzz::Plain=HASH(0x...)` is a'
			. ' non-digit string, so a check on the string would have accepted it.',
	},
	{
		name   => 'blessed reference, stringifies to a location',
		values => [blessed('Fuzz::Str', 'London')],
		note   => 'An overloaded `""` returns `London`, which is accepted on its own;'
			. ' the reference must be refused all the same.',
	},
	{
		name   => 'blessed reference, stringifies to digits',
		values => [blessed('Fuzz::Str', '0044')],
		note   => 'The overload returns `0044`, which is refused on its own; the'
			. ' reference must be refused for being a reference and not for its digits.',
	},
	{
		name   => 'blessed reference, false boolean, stringifies to a location',
		values => [blessed('Fuzz::FalseStr', 'London')],
		note   => 'A false object is refused for being a reference, not for being'
			. ' false: the two reasons have to give the same answer in every module.',
	},
	{
		name   => 'blessed reference, false boolean, stringifies to digits',
		values => [blessed('Fuzz::FalseStr', '0044')],
		note   => 'Both a false boolean and digits, which the one rule answers once.',
	},
);

sub class_summary
{
	my ($sibling, $class) = @_;

	my %seen;
	for my $value (@{$class->{'values'}}) {
		my ($verdict) = verdict($sibling, $value);
		$seen{$verdict}++;
	}

	return join('/', sort keys %seen);
}

sub free_summary
{
	my $class = shift;

	my %seen;
	for my $value (@{$class->{'values'}}) {
		$seen{free_verdict($value)}++;
	}

	return join('/', sort keys %seen);
}

# ---------------------------------------------------------------------------
# The randomised run
# ---------------------------------------------------------------------------

my @SCALAR_CHARS = ('a' .. 'z', 'A' .. 'Z', '0' .. '9', ' ', ',', '.', '-', '+', "\n", "\t", 'é', 'ß', '£');

sub random_scalar
{
	my $kind = int(rand(5));

	# Numeric strings, including the long ones a numeric column holds.
	if($kind == 0) {
		my $length = 1 + int(rand(24));
		return join('', map { int(rand(10)) } 1 .. $length);
	}

	# Actual numbers.
	if($kind == 1) {
		return int(rand(2_000_000)) - 1_000_000;
	}
	if($kind == 2) {
		return (rand(2) ? -1 : 1) * rand(1000);
	}

	# Arbitrary text, often with a digit or two to keep it near the boundary.
	my $length = int(rand(20));
	my $text = join('', map { $SCALAR_CHARS[int(rand(@SCALAR_CHARS))] } 1 .. $length);

	return $text;
}

sub random_reference
{
	my $kind = int(rand(10));

	return \1                 if $kind == 0;
	return [1, 2, 3]          if $kind == 1;
	return { a => 1 }         if $kind == 2;
	return sub { }            if $kind == 3;
	return \*STDOUT           if $kind == 4;
	return qr/x/              if $kind == 5;
	return blessed('Fuzz::Plain') if $kind == 6;
	return blessed('Fuzz::Str', random_scalar()) if $kind == 7;
	return blessed('Fuzz::FalseStr', random_scalar()) if $kind == 8;
	return blessed('Fuzz::Str', join('', map { int(rand(10)) } 1 .. (1 + int(rand(6)))));
}

sub random_value
{
	my $kind = int(rand(10));

	return undef if $kind == 0;          # undef
	return random_reference() if $kind >= 7;  # references
	return random_scalar();
}

sub describe
{
	my $value = shift;

	return 'undef' unless defined($value);
	return "reference ($value)" if ref($value);
	(my $shown = $value) =~ s/([^\x20-\x7e])/sprintf('\\x{%X}', ord($1))/ge;
	$shown = substr($shown, 0, 40) . '...' if length($shown) > 40;

	return "scalar ('$shown')";
}

sub random_phase
{
	my ($iterations) = @_;

	my @predicates = @SIBLINGS;
	my %scalar_disagreements;
	my %reference_disagreements;
	my %sibling_splits;
	my %errors;
	my $scalars = 0;
	my $refs = 0;
	my $undefs = 0;

	for my $iteration (1 .. $iterations) {
		my $value = random_value();

		if(!defined($value)) {
			$undefs++;
		} elsif(ref($value)) {
			$refs++;
		} else {
			$scalars++;
		}

		my $free = free_verdict($value);
		my @pairs = map { my ($v) = verdict($_, $value); [$_, $v] } @predicates;
		my @verdicts = map { $_->[1] } @pairs;
		my %distinct = map { $_ => 1 } @verdicts;

		for my $verdict (@verdicts) {
			if($verdict eq 'ERROR') {
				$errors{describe($value)} = 1;
			}
		}

		my $sibling_differs = grep { $_ ne $free } @verdicts;
		next unless $sibling_differs || scalar(keys %distinct) > 1;

		my $key = join(' ', map { $_->[0]->{'name'} . '=' . $_->[1] } @pairs);
		# The rule's own verdict travels with the value: it is what the gate is
		# measured against, and a scalar verdict pattern alone does not say
		# which of the two a sibling came from.
		if(!defined($value) || !ref($value)) {
			$scalar_disagreements{$key} //= { value => describe($value), rule => $free };
		} else {
			$reference_disagreements{$key} //= describe($value);
		}
		$sibling_splits{$key}++ if(scalar(keys %distinct) > 1);
	}

	return {
		iterations             => $iterations,
		scalars                => $scalars,
		references             => $refs,
		undefs                 => $undefs,
		scalar_disagreements   => \%scalar_disagreements,
		reference_disagreements => \%reference_disagreements,
		sibling_splits         => \%sibling_splits,
		errors                 => \%errors,
	};
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

sub pattern
{
	my $class = shift;

	my %verdict;
	for my $sibling (@SIBLINGS) {
		$verdict{$sibling->{'name'}} = class_summary($sibling, $class);
	}

	return (free_summary($class), \%verdict);
}

# Every curated class and every generated value on which a sibling does not answer
# what the rule answers.  Only scalars and undef are collected: that is what the
# CI gate is about.  A reference disagreement is a real finding and is reported in
# the table above, but it does not fail a run, so the gate cannot go red on the
# question the six were changed for.
sub violations
{
	my @found;

	for my $class (@CLASSES) {
		for my $value (@{$class->{'values'}}) {
			next if ref($value);
			my $free = free_verdict($value);
			for my $sibling (@SIBLINGS) {
				my ($verdict, $why) = verdict($sibling, $value);
				next if $verdict eq $free;
				push @found, sprintf("curated class '%s': %s says %s, the rule says %s (%s)",
					$class->{'name'}, $sibling->{'name'}, $verdict, $free, $why);
			}
		}
	}

	return @found;
}

sub main
{
	my $iterations = 5000;
	my $seed = 20261017;
	my $check = 0;

	GetOptions(
		'iterations=i' => \$iterations,
		'seed=i'       => \$seed,
		'check'        => \$check,
	) or die "Usage: $0 [--iterations N] [--seed S] [--check]\n";

	build_predicates();
	srand($seed);

	print "## Harness output\n\n";
	print "Six sibling geocoders, each asking `_valid_location()` from `geocode()`:\n\n";
	for my $sibling (@SIBLINGS) {
		print "- `$sibling->{'name'}` - `$sibling->{'file'}`\n";
	}
	print "\nThe reference rule is `Geo::Coder::Free::Validate::_valid_location`",
		" (`Geo-Coder-Free/lib/Geo/Coder/Free/Validate.pm`).\n\n";
	print "Verdicts: `ACCEPT` means the predicate let the value through to the lookup",
		" (the stub user agent dies there, so no request is made); `REJECT` means it",
		" refused the value before that point.  The random seed is $seed.\n\n";

	print "### Curated classes\n\n";
	# Printed as a table, then walked again for the ones that disagree.
	print '| Input class | Validate | ', join(' | ', map { $_->{'name'} } @SIBLINGS), " |\n";
	print '| --- | --- | ', join(' | ', map { '---' } @SIBLINGS), " |\n";

	for my $class (@CLASSES) {
		my ($free, $verdicts) = pattern($class);
		print "| $class->{'name'} | $free | ",
			join(' | ', map { $verdicts->{$_->{'name'}} } @SIBLINGS), " |\n";
	}

	print "\n#### Where they disagree\n\n";
	my $disagreements = 0;
	for my $class (@CLASSES) {
		my ($free, $verdicts) = pattern($class);
		my %distinct = map { $verdicts->{$_} => 1 } keys %{$verdicts};
		next unless(scalar(keys %distinct) > 1
			|| grep { $verdicts->{$_} ne $free } keys %{$verdicts});
		$disagreements++;

		print "- **$class->{'name'}** - Validate says $free; ",
			join(', ', map { "$_->{'name'} says $verdicts->{$_->{'name'}}" } @SIBLINGS),
			".\n";
		print "  $class->{'note'}\n" if $class->{'note'};
	}
	print "- None: every curated class is answered the same way by all seven.\n"
		unless $disagreements;

	print "\n### Randomised run\n\n";
	my $random = random_phase($iterations);
	print "Generated $random->{'iterations'} values: $random->{'scalars'} scalars,",
		" $random->{'undefs'} undefs and $random->{'references'} references.\n\n";

	my $scalar_count = scalar keys %{$random->{'scalar_disagreements'}};
	print "- Scalar/undef disagreements: $scalar_count.\n";
	for my $key (sort keys %{$random->{'scalar_disagreements'}}) {
		my $record = $random->{'scalar_disagreements'}{$key};
		print "  - $record->{'value'}: the rule says $record->{'rule'}; $key\n";
	}

	my $reference_count = scalar keys %{$random->{'reference_disagreements'}};
	print "- Reference disagreements: $reference_count distinct verdict patterns.\n";
	my $shown = 0;
	for my $key (sort keys %{$random->{'reference_disagreements'}}) {
		last if $shown++ >= 6;
		print "  - e.g. $random->{'reference_disagreements'}{$key}: $key\n";
	}

	print "- Inter-sibling splits: ", scalar(keys %{$random->{'sibling_splits'}}),
		" distinct verdict patterns.\n";
	for my $key (sort keys %{$random->{'sibling_splits'}}) {
		print "  - $key\n";
	}

	print "- Unclassified errors: ", scalar(keys %{$random->{'errors'}}), ".\n";
	for my $key (sort keys %{$random->{'errors'}}) {
		print "  - $key\n";
	}

	# The gate.  A pattern recorded by the randomised run is always a disagreement
	# with the rule: the siblings can only split among themselves after one of them
	# has left the rule, so every recorded pattern carries a sibling that does not
	# answer what the rule answers.
	my @violations = violations();
	for my $key (sort keys %{$random->{'scalar_disagreements'}}) {
		my $record = $random->{'scalar_disagreements'}{$key};
		push @violations, sprintf('generated %s: %s; the rule says %s',
			$record->{'value'}, $key, $record->{'rule'});
	}

	if($check) {
		print "\n### Gate\n\n";
		if(@violations) {
			print '- FAIL: ', scalar(@violations),
				" disagreement(s) with Geo::Coder::Free::Validate on a scalar or undef.\n";
			print "  - $_\n" for @violations;
			# The report goes to the job summary; this goes to the log.
			print STDERR 'FAIL: ', scalar(@violations),
				" disagreement(s) with Geo::Coder::Free::Validate on a scalar or undef:\n";
			print STDERR "  - $_\n" for @violations;
			return 1;
		}

		print "- PASS: every sibling answers what the rule answers on every scalar",
			" and every undef.\n";
		print STDERR "Ok: every sibling answers what the rule answers on every scalar and every undef.\n";
	}

	return 0;
}

# A probing caller can load this file and use the pieces above.
exit(main()) unless $ENV{'FUZZ_NO_RUN'};
