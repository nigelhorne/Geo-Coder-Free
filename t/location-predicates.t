#!perl -w

# The location-predicate fuzz is what makes "the six ask the rule" a fact rather
# than an assertion: it drives each sibling's real geocode() with a user agent
# that dies at the lookup, and compares the verdict with
# Geo::Coder::Free::Validate::_valid_location().  The scheduled CI job runs it
# with --check, and what --check does with the exit status is what this test
# checks:
#
#   1. the workspace passes - the six answer what the rule answers on every
#      curated class and on randomly generated scalars, references and undef;
#   2. a sibling whose predicate stops refusing a string of digits fails the run,
#      with the sibling, the class and both verdicts named;
#   3. a sibling that accepts a reference does not fail it.  That disagreement is
#      a real finding and is reported, but the gate is about the question a
#      numeric column asks - digits, the empty string, undef - so a reference
#      verdict cannot turn the job red on its own.
#
# The divergence is planted in a copy of the workspace in a temporary directory,
# never in the checkouts: the harness works out which workspace it is in from the
# path it was loaded from, so a copy of it in the temporary tree fuzzes the
# siblings copied beside it.  The copy is a real file, not a link, because
# following a link back to the real harness would put the real siblings in front
# of the planted one.
#
# The harness needs all seven checkouts, so this test skips when they are not
# beside each other, like t/location-rule.t and t/contract-strict.t do.
#
#   prove -l t/location-predicates.t

use strict;
use warnings;

use File::Copy qw(copy);
use File::Find qw(find);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use Test::Most;

# The six that carry a copy of the rule, and the distribution that holds it.
my @DISTS = qw(
	Geo-Coder-Free
	Geo-Coder-CA
	Geo-Coder-DataScienceToolkit
	Geo-Coder-GeoApify
	Geo-Coder-List
	Geo-Coder-Postcodes
	Geo-Coder-XYZ
);

# The distributions copied with a divergence planted in them.
my $PATCHED = 'Geo-Coder-XYZ';
my $MODULE  = 'lib/Geo/Coder/XYZ.pm';

# The guard, as each of the six writes it.  The planted source has to contain it
# exactly once, so a sibling that rewrites its guard fails this test rather than
# passing it with the patch silently not applied.
my $GUARD = 'if(!Geo::Coder::Free::Validate::_valid_location($location)) {';

# Each divergence replaces the guard with a test of its own.  They are the two
# shapes the six had before they were changed.
my %DIVERGENCE = (
	'digits' => {
		what   => 'a string of digits is no longer refused: the predicate that of a'
			. ' numeric column read by mistake is gone',
		guard  => 'if(!defined($location) || ref($location)) {',
		fails  => 1,
	},
	'reference' => {
		what   => 'a reference is accepted again, while a string of digits is still'
			. ' refused, so the disagreement is about references only',
		guard  => "if(!defined(\$location) || (!ref(\$location) && \$location !~ /\\D/)) {",
		fails  => 0,
	},
);

# Under prove -t $Bin is tainted; detaint before it reaches a file name.
my $root = do {
	(my $d = File::Spec->catdir($Bin, File::Spec->updir())) =~ /\A(.*)\z/s;
	$1;
};

# The directory holding the sibling distributions.
my $workspace = do {
	(my $d = File::Spec->catdir($root, File::Spec->updir())) =~ /\A(.*)\z/s;
	$1;
};

my $harness = File::Spec->catfile($root, 'scripts', 'location-predicate-fuzz.pl');

# Enough values that every generated class is reached, and few enough that three
# runs are quick: the curated classes are what the gate is proved on.
my $ITERATIONS = 200;

my @absent = grep { !-d File::Spec->catdir($workspace, $_, 'lib') } @DISTS;
plan skip_all => 'the sibling checkouts are not in the workspace: ' . join(', ', @absent)
	if @absent;

BAIL_OUT("$harness is not in the distribution") unless -f $harness;

# ---------------------------------------------------------------------------
# Running the harness
# ---------------------------------------------------------------------------

# Run it as the CI job does, and read back what it said on both streams: the
# report on stdout, the failures on stderr.  -| rather than a shell, so a path
# with a space in it needs no quoting and nothing else is inherited.
sub run_harness
{
	my ($program, $iterations) = @_;

	my $dir = tempdir(CLEANUP => 1);
	my $echo = File::Spec->catfile($dir, 'stderr.txt');

	# The child's stderr is a file of ours rather than this test's, and the
	# file descriptor is the one it inherits, so the gate's own complaints are
	# readable here and do not appear as bare text in the TAP stream.
	open(my $saved, '>&', \*STDERR) or BAIL_OUT("Cannot save stderr: $!");
	open(STDERR, '>', $echo) or BAIL_OUT("Cannot write $echo: $!");

	my $pid = open(my $fh, '-|', $^X, $program, '--iterations', $iterations, '--check');
	BAIL_OUT("Cannot run $program: $!") unless defined($pid);
	my $report = do { local $/; <$fh> };
	close($fh);
	my $status = $? >> 8;

	open(STDERR, '>&', $saved) or BAIL_OUT("Cannot restore stderr: $!");

	open(my $err_fh, '<', $echo) or BAIL_OUT("Cannot read $echo: $!");
	my $errors = do { local $/; <$err_fh> };
	close($err_fh);

	return ($status, $report // '', $errors // '');
}

# ---------------------------------------------------------------------------
# Building a workspace with a divergence in it
# ---------------------------------------------------------------------------

sub copy_tree
{
	my ($from, $to) = @_;

	find({
		no_chdir => 1,
		wanted   => sub {
			my $target = File::Spec->catfile($to, File::Spec->abs2rel($_, $from));
			if(-d $_) {
				make_path($target) unless -d $target;
			} else {
				copy($_, $target) or BAIL_OUT("Cannot copy $_ to $target: $!");
			}
		},
	}, $from);

	return;
}

sub plant
{
	my ($file, $guard) = @_;

	open(my $in, '<', $file) or BAIL_OUT("Cannot read $file: $!");
	my $source = do { local $/; <$in> };
	close($in);

	my $planted = ($source =~ s/\Q$GUARD\E/$guard/);
	BAIL_OUT("$file does not contain the guard this test plants a divergence in,"
		. " so the divergence was not planted:\n\t$GUARD")
		unless $planted == 1;

	open(my $out, '>', $file) or BAIL_OUT("Cannot write $file: $!");
	print {$out} $source or BAIL_OUT("Cannot write $file: $!");
	close($out) or BAIL_OUT("Cannot write $file: $!");

	return;
}

# A workspace of copies: the rule, the six modules, and the harness itself.  The
# rule is one file of this distribution rather than its whole lib/, which holds
# the databases; nothing else here is loaded by the harness.
sub build_workspace
{
	my ($dir, $divergence) = @_;

	for my $dist (@DISTS) {
		copy_tree(
			File::Spec->catdir($workspace, $dist, 'lib'),
			File::Spec->catdir($dir, $dist, 'lib')
		);
	}

	my $scripts = File::Spec->catdir($dir, 'scripts');
	make_path($scripts);
	copy($harness, File::Spec->catfile($scripts, 'location-predicate-fuzz.pl'))
		or BAIL_OUT("Cannot copy $harness: $!");

	plant(File::Spec->catfile($dir, $PATCHED, $MODULE), $DIVERGENCE{$divergence}{'guard'});

	return File::Spec->catfile($scripts, 'location-predicate-fuzz.pl');
}

# ---------------------------------------------------------------------------
# 1. The workspace passes
# ---------------------------------------------------------------------------

my ($status, $report, $errors) = run_harness($harness, $ITERATIONS);

is($status, 0, 'the six answer what the rule answers, so the gate passes')
	or diag($report);
like($report, qr/^### Gate$/m, 'the report says what the gate decided');
like($report, qr/^- PASS: /m, 'and it passed');
like($report, qr/^- Scalar\/undef disagreements: 0\.$/m, 'no scalar or undef disagreed');
like($report, qr/^- Unclassified errors: 0\.$/m, 'and nothing went unclassified');
like($errors, qr/^Ok: /m, 'the run says so on stderr as well, which is what CI keeps');

# ---------------------------------------------------------------------------
# 2. A sibling that stops refusing a string of digits fails the run
# ---------------------------------------------------------------------------

{
	my $dir = tempdir(CLEANUP => 1);
	my $program = build_workspace($dir, 'digits');
	my ($patched_status, $patched_report, $patched_errors) = run_harness($program, $ITERATIONS);

	cmp_ok($patched_status, '!=', 0, 'the gate fails when a sibling stops refusing digits');
	like($patched_report,
		qr/curated class 'digits only': Geo::Coder::XYZ says ACCEPT, the rule says REJECT/,
		'and names the sibling, the class and both verdicts');
	like($patched_report, qr/^- FAIL: /m, 'the report says the gate failed');
	unlike($patched_report, qr/^- PASS: /m, 'and does not say it passed');
	like($patched_errors, qr/^FAIL: /m, 'the failure is on stderr, where the log keeps it');
	like($patched_errors, qr/Geo::Coder::XYZ says ACCEPT, the rule says REJECT/,
		'with the same detail');
}

# ---------------------------------------------------------------------------
# 3. A reference disagreement is reported but does not fail the run
# ---------------------------------------------------------------------------

{
	my $dir = tempdir(CLEANUP => 1);
	my $program = build_workspace($dir, 'reference');
	my ($patched_status, $patched_report) = run_harness($program, $ITERATIONS);

	is($patched_status, 0, 'a reference disagreement alone does not fail the gate');
	like($patched_report, qr/^- PASS: /m, 'the gate passes');
	like($patched_report,
		qr/- \*\*unblessed reference\*\* - Validate says REJECT; .*Geo::Coder::XYZ says ACCEPT/,
		'although the class it disagrees on is in the report');
	like($patched_report, qr/^- Reference disagreements: [1-9]\d* distinct verdict patterns\.$/m,
		'and the generated references are reported too');
	like($patched_report, qr/^- Scalar\/undef disagreements: 0\.$/m,
		'while the scalars and undef still agree');
}

done_testing();
