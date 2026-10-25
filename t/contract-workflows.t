#!/usr/bin/perl -w

# The contract job's workspace check, checked against the job that runs it.
#
# .github/workflows/contract.yml assembles workspace/ from the sibling
# distributions and then runs a shell loop that fails if a directory its
# `for dist in ...` list names is not there.  A copy of that job which checks
# out fewer distributions than its own list requires therefore stops at that
# check - "workspace/Geo-Coder-Free was not checked out" - before the contract
# runs at all.  The job is copied into four distributions (this one,
# Database-BI, Geo-Location-Point and HTML-Genealogy-Map) and kept in step by
# hand, so one copy can lose a checkout while the other three - and every test
# in this distribution - still pass.
#
# So this reads this distribution's copy, and the sibling copies when the
# checkout is inside the assembled workspace, and fails if a distribution named
# in a copy's loop has no checkout in that same copy.  The parser is run over
# workflow files this test writes first, one complete and one missing a
# checkout, so a pattern that stopped matching fails here instead of finding
# nothing to complain about.
#
# The copies are read as text rather than as YAML: the distribution declares no
# YAML dependency, and the two things this needs - the loop's list and the
# checkout paths - are the one-line forms each copy already uses.

use strict;
use warnings;

use Cwd qw(abs_path);
use FindBin qw($Bin);
use File::Spec::Functions qw(catdir catfile updir);
use File::Temp qw(tempdir);
use Test::Most;

# The directory holding the sibling distributions: the parent of this checkout.
# Resolved, so the labels below name a directory rather than a path with ..s.
my $WORKSPACE = abs_path(catdir($Bin, updir(), updir()))
	// catdir($Bin, updir(), updir());

sub _slurp {
	my ($file) = @_;

	open(my $fh, '<', $file) or return;
	local $/;
	my $text = <$fh>;
	close($fh);

	return $text;
}

# The names a copy's workspace check requires: the list in `for dist in ...; do`.
# Some copies write it across lines with backslash continuations, so those are
# joined before the loop is looked for.
sub _required_distributions {
	my ($text) = @_;

	(my $joined = $text) =~ s/\\\n\s*/ /g;

	my @names;
	while ($joined =~ /^[ \t]*for\s+dist\s+in\s+([^;]+);[ \t]*do\b/mg) {
		push @names, split(' ', $1);
	}

	return @names;
}

# What a copy checks out: the `path: workspace/<name>` of its checkout steps.
# Commented-out lines go first, so an example in a comment is not a checkout,
# and `working-directory: workspace/<name>` is not `path:` and so is not one.
sub _checked_out {
	my ($text) = @_;

	(my $source = $text) =~ s/^[ \t]*#.*$//mg;

	my %checked;
	$checked{$1} = 1 while $source =~ /^[ \t]*path:[ \t]*workspace\/(\S+)[ \t]*$/mg;

	return %checked;
}

# The distributions a copy names but does not check out, in the order it names
# them.
sub _missing_checkouts {
	my ($text) = @_;

	my %checked = _checked_out($text);

	return [ grep { !$checked{$_} } _required_distributions($text) ];
}

# Every contract.yml copy worth checking: always this distribution's own, and
# the siblings' when the parent really is the workspace the job assembles.
#
# The siblings are only a workspace when the two distributions every copy names,
# Test-Consumer-Contract and Geo-Location-Point, are beside this checkout.  In
# a build directory - an unpacked tarball next to other releases - they are not,
# and reading an unrelated release's stale copy of the job as if it were the one
# this job assembles would fail an install for something it does not control.
sub _copies {
	my $own = catfile($Bin, updir(), '.github', 'workflows', 'contract.yml');
	my @copies = (-f $own ? ($own) : ());

	for my $marker (qw(Test-Consumer-Contract Geo-Location-Point)) {
		return @copies unless -d catdir($WORKSPACE, $marker);
	}

	opendir(my $dh, $WORKSPACE) or return @copies;
	for my $name (sort grep { !/\A\./ && -d catdir($WORKSPACE, $_) } readdir($dh)) {
		my $file = catfile($WORKSPACE, $name, '.github', 'workflows', 'contract.yml');
		push @copies, $file if -f $file && $file ne $own;
	}
	closedir($dh);

	return @copies;
}

# A workflow file of the shape the job has: a checkout per name, then the loop
# the check runs.  The loop is written across lines, as the production copies
# that need it are, so the parser is tested against a continuation.
sub _workflow {
	my (@checked) = @_;

	my $yaml = '';
	for my $name (@checked) {
		$yaml .= <<"YAML";
      - uses: actions/checkout\@v7
        with:
          repository: nigelhorne/$name
          path: workspace/$name

YAML
	}

	$yaml .= <<'YAML';
      - name: Check that the workspace is there
        shell: bash
        run: |
          set -eu
          for dist in Geo-Coder-Free Database-BI \
            Geo-Location-Point; do
            if [ ! -d "workspace/$dist" ]; then
              echo "::error::workspace/$dist was not checked out"
              exit 1
            fi
          done
YAML

	return $yaml;
}

subtest 'the parser, on workflow files this test writes' => sub {
	is scalar(_required_distributions(_workflow())), 3,
		'a list written across a continuation is read as one list';

	is_deeply _missing_checkouts(_workflow(qw(Geo-Coder-Free Database-BI Geo-Location-Point))),
		[], 'a copy that checks out what its loop names has nothing missing';

	is_deeply _missing_checkouts(_workflow(qw(Geo-Coder-Free Database-BI))),
		['Geo-Location-Point'], 'a copy that leaves one out is reported, by name';

	my $commented = "#          path: workspace/Geo-Location-Point\n"
		. _workflow(qw(Geo-Coder-Free Database-BI));
	is_deeply _missing_checkouts($commented), ['Geo-Location-Point'],
		'a commented-out checkout is not a checkout';

	my $elsewhere = _workflow(qw(Geo-Coder-Free Database-BI))
		. "      - name: Run the contract\n        working-directory: workspace/Geo-Location-Point\n";
	is_deeply _missing_checkouts($elsewhere), ['Geo-Location-Point'],
		'and a working-directory is not one either';
};

my @copies = _copies();

plan skip_all => "there is no contract.yml in a checkout under $WORKSPACE"
	unless @copies;

diag "Looking for contract.yml copies under $WORKSPACE";

for my $copy (@copies) {
	# Named by distribution in the test names, so a failure says which of the
	# copies to fix rather than only what it is missing.
	(my $label = $copy) =~ s/^\Q$WORKSPACE\E\///;
	$label =~ s{/\.github/workflows/contract\.yml\z}{};

	my $text = _slurp($copy);

	ok defined $text, "${label}'s contract.yml is readable";
	next unless defined $text;

	my @required = _required_distributions($text);
	ok scalar(@required), "$label names the distributions its workspace check requires";
	next unless @required;

	my %checked = _checked_out($text);
	ok scalar(keys %checked), "$label checks distributions out into the workspace";

	my $missing = _missing_checkouts($text);
	is_deeply $missing, [], "$label checks out every distribution its loop requires"
		or diag(explain($missing));
}

done_testing();
