#!perl -w

# Author test: code that this distribution has added to a file VWF master owns.
#
# Four modules here are copies of modules in the VWF checkout beside this one,
# renamed on the way in:
#
#	lib/Geo/Coder/Free/Utils.pm	is a copy of	vwf/lib/VWF/Utils.pm
#	lib/Geo/Coder/Free/Config.pm	is a copy of	vwf/lib/VWF/Config.pm
#	lib/Geo/Coder/Free/Display.pm	is a copy of	vwf/lib/VWF/Display.pm
#	lib/Geo/Coder/Free/Allow.pm	is a copy of	vwf/lib/VWF/Allow.pm
#
# A sync copies the master's file over ours and edits the namespace on the way
# in, so anything we add to one of them is lost the next time it runs.  Local
# code belongs in a module of its own: Provenance.pm and Validate.pm exist for
# exactly that reason, and the note at the top of Provenance.pm says so.
#
# This test diffs the master's file against ours and fails for every block of
# lines ours has that the master's has not.  A block rather than a line, so that
# a subroutine added to a tracked file is one failure naming its whole body.
#
# A block is one of two things and the test cannot tell them apart:
#
#   - code this distribution has added, which the sync will discard;
#   - an older revision of a line the master has since changed, which the sync
#     will replace.
#
# Both are a reason to look before the next sync, and the lines are printed for
# the reader to tell which is which.
#
# What the comparison does not see:
#
#   - a line the master has and we have not is a diagnostic, not a failure.
#     Our copy being behind the master is a different problem from local code
#     being at risk, and the sync is what brings those lines in.  A local
#     deletion with nothing put in its place is therefore not caught;
#   - POD, blank lines and the $VERSION line are ignored, so a reworded
#     paragraph or a version bump is not an addition.  A paragraph of local POD
#     standing on its own would not be reported;
#   - the comparison is textual.  A reindented or reflowed copy of an upstream
#     line reads as a local addition.
#
# The master is found through $VWF_HOME, or as ../vwf beside this checkout.
# Without one the test skips, so a CPAN install is unaffected, and so is a
# workspace that does not carry VWF.
#
#   AUTHOR_TESTING=1 prove -l t/vwf-sync.t
#   VWF_HOME=~/src/njh/vwf AUTHOR_TESTING=1 prove -l t/vwf-sync.t

use strict;
use warnings;

use File::Spec;
use FindBin qw($Bin);
use Test::DescribeMe qw(author);
use Test::Most;

# The files this distribution tracks from VWF master: ours => the master's name.
# Add an entry when another file becomes a copy of one of VWF's.
my %TRACKED = (
	'lib/Geo/Coder/Free/Utils.pm'	=> 'Utils.pm',
	'lib/Geo/Coder/Free/Config.pm'	=> 'Config.pm',
	'lib/Geo/Coder/Free/Display.pm'	=> 'Display.pm',
	'lib/Geo/Coder/Free/Allow.pm'	=> 'Allow.pm',
);

# Under prove -t, $Bin is tainted; detaint it before it reaches a file name.
my $root = do {
	(my $d = File::Spec->catdir($Bin, File::Spec->updir())) =~ /\A(.*)\z/s;
	$1;
};

my $vwf = _master_dir();

if(!defined($vwf)) {
	plan skip_all => 'No VWF checkout to compare against: set VWF_HOME, or put one at ../vwf';
} else {
	diag("VWF master read from $vwf");
}

# The comparison, on literal source
# ---------------------------------------------------------------------------
# The check is only worth anything if it can tell an addition from the
# differences every copy is expected to have, so it is run here on source whose
# answer is known.  Without this, a broken comparison would report no local code
# in any file and the test would pass whatever the tracked files said.

{
	my $master_source = <<'MASTER';
package VWF::Utils;

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

sub distance {
	return 1;
}
MASTER

	my $our_source = <<'OURS';
package Geo::Coder::Free::Utils;

=head1 VERSION

Version 0.46

=cut

our $VERSION = '0.46';

use Geo::Coder::Abbreviations;

sub distance {
	return 1;
}

sub _abbreviate {
	return 1;
}
OURS

	my @master = _code_lines($master_source);
	my @ours = _code_lines($our_source);

	my ($blocks, $behind) = _local_additions(\@ours, \@master);

	is scalar @{ $blocks }, 2,
		'the renamed copy with two additions in it reports two blocks';

	is $blocks->[0][0][0], 11,
		'the block for the added use line names the line it is on';
	is $blocks->[0][0][1], 'use Geo::Coder::Abbreviations;',
		'the block for the added use line names the line that was added';

	is_deeply [map { $_->[0] } @{ $blocks->[1] }], [17, 18, 19],
		'the block for the added subroutine spans its whole body';

	# The namespace, the version and the POD are what a copy is expected to
	# differ by, and none of them is an addition.
	is $behind, 0, 'the renamed copy is not reported as behind the master';
}

# The files themselves
# ---------------------------------------------------------------------------

foreach my $local_path(sort keys %TRACKED) {
	my $name = $TRACKED{$local_path};
	my $local_file = File::Spec->catfile($root, $local_path);
	my $master_file = File::Spec->catfile($vwf, 'lib', 'VWF', $name);

	my $our_text = -r $local_file ? _read_file($local_file) : undef;
	ok(defined($our_text), "$local_path is readable") or next;

	if(-r $master_file) {
		ok(1, "the master's $name is readable");
	} else {
		# Upstream moving or renaming its own files is a change this test has
		# to be told about: it cannot compare against a file that is not there.
		fail("VWF master has no lib/VWF/$name, so $local_path has no master to check against: update the table in this test");
		next;
	}

	my $master_text = _read_file($master_file);

	# The file compared with must be VWF's own.  Comparing our file with a copy
	# of itself would pass whatever we had written into it.
	my $package = "VWF::$name";
	$package =~ s/\.pm\z//;
	like($master_text, qr/^package \Q$package\E;/m,
		"$master_file declares $package, so it is the master's file and not ours");

	my @ours = _code_lines($our_text);
	my @master = _code_lines($master_text);

	cmp_ok(scalar @ours, '>', 0, "$local_path has code to compare");
	cmp_ok(scalar @master, '>', 50, "the master's $name has a body of code to compare against");

	my ($blocks, $behind) = _local_additions(\@ours, \@master);

	my $local_only = 0;
	$local_only += scalar @{ $_ } foreach @{ $blocks };

	# A file that shares almost nothing with the master's file of the same name
	# is not a copy of it, and its entry in the table is a mistake.  This is
	# also what stops the rest of this file from passing by comparing two
	# unrelated modules.
	cmp_ok(scalar(@ours) - $local_only, '>', scalar(@ours) / 2,
		"$local_path is a renamed copy of the master's $name, not a module of its own");

	foreach my $block(@{ $blocks }) {
		my $start = $block->[0][0];
		my $end = $block->[-1][0];
		my $where = $start == $end ? $start : "$start-$end";

		fail("$local_path:$where has " . scalar(@{ $block })
			. ($end == $start ? ' line' : ' lines') . " that the master's $name has not got");
		diag("    $_->[2]") foreach @{ $block };
	}

	if(!@{ $blocks }) {
		pass("$local_path has no code that the master's $name has not got");
	}

	if($behind) {
		diag("$local_path is behind the master: the master's $name has $behind line"
			. ($behind == 1 ? ' that is' : 's that are') . ' not in it.  That is not a '
			. 'failure here, but the sync will bring them in, and the two have '
			. 'already parted company.');
	}
}

done_testing();

# ---------------------------------------------------------------------------

# The checkout VWF is read from: $VWF_HOME first, then the two places a
# workspace beside this distribution keeps it.  A directory that is not VWF's
# (no lib/VWF in it) is not one of them.
sub _master_dir
{
	my @candidates = (
		$ENV{'VWF_HOME'},
		File::Spec->catdir($root, 'vwf'),
		File::Spec->catdir($root, File::Spec->updir(), 'vwf'),
	);

	foreach my $dir(grep { defined($_) && length($_) } @candidates) {
		return $dir if(-d File::Spec->catdir($dir, 'lib', 'VWF'));
	}

	return;
}

sub _read_file
{
	my $file = shift;

	open(my $fh, '<', $file) or return;
	my $text = do { local $/; <$fh> };
	close($fh);

	return $text;
}

# The lines of code in a file, each paired with the number of the line it is on
# in the file it came from: [line number, comparable text, text as written].
#
# POD, blank lines and the $VERSION line are left out.  POD because a reworded
# paragraph is not the kind of addition a sync loses in the way that a
# subroutine is; $VERSION because every distribution carries its own; blank
# lines because they say nothing either way.
sub _code_lines
{
	my $text = shift;

	my @code;
	my $in_pod;
	my $line_number = 0;

	foreach my $line(split(/\n/, $text, -1)) {
		$line_number++;

		# A POD directive starts at column 0; =cut is the one that ends it.
		if($line =~ /^=(\w+)/) {
			$in_pod = ($1 ne 'cut');
			next;
		}

		next if($in_pod);
		next if($line =~ /^\s*\z/);
		next if($line =~ /^\s*our\s+\$VERSION\s*=/);

		push @code, [$line_number, _neutral($line), $line];
	}

	return @code;
}

# A line as it reads in either file.  The namespace is the one thing a copy is
# expected to change, so it is replaced on both sides rather than allowed for
# on one: what is left is the code, not the name it is filed under.
sub _neutral
{
	my $line = shift;
	$line =~ s/\b(?:VWF|Geo::Coder::Free)\b/DISTRIBUTION/g;
	return $line;
}

# What ours has that the master's has not: a list of blocks of consecutive
# lines, and how many lines the master's has that ours has not.
sub _local_additions
{
	my ($ours, $master) = @_;

	my ($ours_only, $master_only) = _diff($ours, $master);

	# Consecutive lines are one addition: a subroutine moved into a tracked
	# file should read as one failure naming its body, not one failure per
	# line of it.
	my @blocks;
	foreach my $line(@{ $ours_only }) {
		if(@blocks && $line->[0] == $blocks[-1][-1][0] + 1) {
			push @{ $blocks[-1] }, $line;
		} else {
			push @blocks, [$line];
		}
	}

	return (\@blocks, scalar @{ $master_only });
}

# The lines each file has that the other has not, as [line number, text, text]
# triples.  The longest common subsequence of the two files' lines, because
# lines repeat: a bare "}" appears dozens of times in both, and looking a line
# up in a set would pair the wrong ones and call the rest an addition.  The
# subsequence pairs the most lines it can, so what is left over really is the
# difference between the two files.
sub _diff
{
	my ($ours, $master) = @_;

	my $n = scalar @{ $ours };
	my $m = scalar @{ $master };
	my $width = $m + 1;

	# Cell (i, j) of the table is the length of the longest common subsequence
	# of ours[i ..] and master[j ..], built from the end of both files back.
	# Cells past the end of either file read as zero, which is what the
	# recurrence wants there, so the table is a string of 16 bit cells rather
	# than a million scalars.
	my $lcs = '';

	for(my $i = $n - 1; $i >= 0; $i--) {
		my $row = $i * $width;
		my $below = $row + $width;

		for(my $j = $m - 1; $j >= 0; $j--) {
			my $length;

			if($ours->[$i][1] eq $master->[$j][1]) {
				$length = vec($lcs, ($below + $j + 1) * 16, 16) + 1;
			} else {
				my $down = vec($lcs, ($below + $j) * 16, 16);
				my $across = vec($lcs, ($row + $j + 1) * 16, 16);
				$length = $down > $across ? $down : $across;
			}

			vec($lcs, ($row + $j) * 16, 16) = $length;
		}
	}

	# Walk the table: a pair of lines that matches is part of the subsequence,
	# and a line taken from one file alone is one the other has not got.
	my (@ours_only, @master_only);
	my ($i, $j) = (0, 0);

	while($i < $n && $j < $m) {
		if($ours->[$i][1] eq $master->[$j][1]) {
			$i++;
			$j++;
		} elsif(vec($lcs, (($i + 1) * $width + $j) * 16, 16)
			>= vec($lcs, ($i * $width + $j + 1) * 16, 16)) {
			push @ours_only, $ours->[$i++];
		} else {
			push @master_only, $master->[$j++];
		}
	}

	push @ours_only, $ours->[$_] foreach $i .. $n - 1;
	push @master_only, $master->[$_] foreach $j .. $m - 1;

	return (\@ours_only, \@master_only);
}
