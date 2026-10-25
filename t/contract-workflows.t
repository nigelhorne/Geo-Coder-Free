#!/usr/bin/perl -w

# The contract job is one body, and the four distributions that run it only
# call it.  This file holds them to that.
#
# .github/workflows/contract-body.yml assembles a workspace/ of the sibling
# checkouts and runs t/consumer-contract.t in it.  The job used to be a whole
# workflow copied into each of the four distributions that run it - this one,
# Database-BI, Geo-Location-Point and HTML-Genealogy-Map - kept in step by hand.
# The copies drifted: one lost the producer's checkout and stopped CI at
# "workspace/Geo-Coder-Free was not checked out" before the contract ran, while
# every test in this distribution still passed; another pinned the Perl setup to
# a different commit.  Each copy is now a caller passing only the three things
# that differ between them, so what is left to go wrong is structural, and that
# is what is checked here:
#
#   * the body lists the distributions it assembles once, in DISTRIBUTIONS, and
#     checks out every name on that list and refuses to run for a name that is
#     not on it - so the list, the checkouts and the check on the way in cannot
#     disagree;
#   * each caller names the body, names itself in `distribution`, hands over the
#     repository and ref to check out, passes the workspace secret through, and
#     carries none of the body's work;
#   * the body is in the repository, not only in this working tree: a caller
#     fetches it by repository and ref, so a file that was never added is one
#     GitHub answers "failed to fetch workflow: workflow was not found" for,
#     at the call site, while every test here still reads it from disk and
#     passes.
#
# The files are read as text rather than as YAML: the distribution declares no
# YAML dependency, and the few lines this needs are the one-line forms the files
# already use.  The parsers are run over files this test writes first, so a
# pattern that stopped matching fails instead of finding nothing to complain
# about.

use strict;
use warnings;

use Cwd qw(abs_path);
use FindBin qw($Bin);
use File::Spec::Functions qw(catdir catfile updir);
use Test::Most;

# The directory holding the sibling distributions: the parent of this checkout.
# Resolved, so the labels below name a directory rather than a path with ..s.
my $WORKSPACE = abs_path(catdir($Bin, updir(), updir()))
	// catdir($Bin, updir(), updir());

# The body, in this checkout: this is the distribution that owns the contract
# test the body runs, and the one every caller checks out.
my $BODY = catfile($Bin, updir(), '.github', 'workflows', 'contract-body.yml');

# .github is not in the MANIFEST, so an installed copy of this distribution has
# neither the body nor a caller: there the file has nothing to guard, and it
# says so before running anything rather than failing on files that are not
# shipped.  This checks CI, not the module.
my $BODY_TEXT = _slurp($BODY);

plan skip_all => 'the contract workflows are not part of the distribution'
	unless defined $BODY_TEXT;

my @callers = grep { -f $_ } map {
	catfile($WORKSPACE, $_, '.github', 'workflows', 'contract.yml')
} _directories();

plan skip_all => "there are no contract.yml callers under $WORKSPACE"
	unless @callers;

diag "Looking for contract.yml callers under $WORKSPACE";

sub _slurp {
	my ($file) = @_;

	open(my $fh, '<', $file) or return;
	local $/;
	my $text = <$fh>;
	close($fh);

	return $text;
}

# A value from the job's env, such as the DISTRIBUTIONS list.  One line, which
# is how the body writes it.
sub _env_list {
	my ($text, $name) = @_;

	(my $source = $text) =~ s/^[ \t]*#.*$//mg;

	return unless $source =~ /^[ \t]*\Q$name\E:[ \t]*(.+?)[ \t]*$/m;

	return split(' ', $1);
}

# What a file checks out into the workspace: the `path: workspace/<name>` of its
# checkout steps.  The wildcard entry is the body's self checkout, which covers
# whichever name the caller passed in.  Commented-out lines go first, so an
# example in a comment is not a checkout, and `working-directory: workspace/...`
# is not `path:` and so is not one.
sub _checked_out {
	my ($text) = @_;

	(my $source = $text) =~ s/^[ \t]*#.*$//mg;

	my %checked;
	while ($source =~ /^[ \t]*path:[ \t]*workspace\/(.+?)[ \t]*$/mg) {
		my $name = $1;
		$name = '*' if $name =~ /\A\$\{\{\s*inputs\.distribution\s*\}\}\z/;
		$checked{$name} = 1;
	}

	return %checked;
}

# The workflow a caller calls, as written: a local path or owner/repo@ref.
sub _body_reference {
	my ($text) = @_;

	(my $source = $text) =~ s/^[ \t]*#.*$//mg;

	return unless $source =~ /^[ \t]*uses:[ \t]*(\S*contract-body\.yml(?:@\S+)?)[ \t]*$/m;

	return $1;
}

# The value a caller passes as its `distribution` input.  Six or more columns of
# indent, so the body's own input declaration - `      distribution:` with no
# value - is not read as one.
sub _distribution_input {
	my ($text) = @_;

	(my $source = $text) =~ s/^[ \t]*#.*$//mg;

	return unless $source =~ /^ {6,}distribution:[ \t]*(\S+)[ \t]*$/m;

	return $1;
}

# The parts of the body's work that a caller must not carry any more.
sub _body_work {
	my ($text) = @_;

	(my $source = $text) =~ s/^[ \t]*#.*$//mg;

	my @found;
	push @found, 'a workspace loop'          if $source =~ /^[ \t]*for[ \t]+dist[ \t]+in\b/m;
	push @found, 'a checkout of a sibling'   if $source =~ /^[ \t]*path:[ \t]*workspace\//m;
	push @found, 'a run of the contract'     if $source =~ /\bprove\b/;
	push @found, 'a workspace check'         if $source =~ /was not checked out/;

	return \@found;
}

# A caller of the shape the four have.
sub _caller {
	my ($distribution, %opt) = @_;

	my $uses = defined $opt{uses} ? $opt{uses}
		: 'nigelhorne/Geo-Coder-Free/.github/workflows/contract-body.yml@master';
	my $secrets = $opt{secrets} // 1;

	my $yaml = <<"YAML";
name: Reader/producer contract

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  contract:
    uses: $uses
    with:
      distribution: $distribution
      repository: \${{ github.repository }}
      ref: \${{ github.ref }}
YAML

	$yaml .= "    secrets: inherit\n" if $secrets;

	$yaml .= $opt{extra} if defined $opt{extra};

	return $yaml;
}

# A body of the shape the real one has.
sub _body {
	my (@names) = @_;

	my $yaml = <<"YAML";
name: Reader/producer contract (reusable)

on:
  workflow_call:
    inputs:
      distribution:
        required: true
        type: string

jobs:
  contract:
    runs-on: ubuntu-latest
    env:
      DISTRIBUTIONS: @{[ join(' ', @names) ]}
    steps:
      - name: Check out this distribution at the commit under test
        uses: actions/checkout\@v7
        with:
          repository: \${{ inputs.repository }}
          ref: \${{ inputs.ref }}
          path: workspace/\${{ inputs.distribution }}

YAML

	for my $name (@names) {
		next if $name eq 'Geo-Coder-Free';
		$yaml .= <<"YAML";
      - name: Check out $name
        uses: actions/checkout\@v7
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
          for dist in $DISTRIBUTIONS; do
            if [ ! -d "workspace/$dist" ]; then
              echo "::error::workspace/$dist was not checked out"
              exit 1
            fi
          done
YAML

	return $yaml;
}

subtest 'the parsers, on files this test writes' => sub {
	my $body = _body(qw(Geo-Coder-Free Database-BI HTML-OSM));

	is_deeply [ _env_list($body, 'DISTRIBUTIONS') ],
		[qw(Geo-Coder-Free Database-BI HTML-OSM)],
		'the DISTRIBUTIONS list is read as the distributions it names';

	my %checked = _checked_out($body);
	is_deeply [ sort keys %checked ], ['*', 'Database-BI', 'HTML-OSM'],
		'each checkout is read, and the self checkout is the wildcard';

	is_deeply _body_work($body), ['a workspace loop', 'a checkout of a sibling',
		'a workspace check'],
		'the body is seen to carry the work, so a caller carrying it is caught';

	is _body_reference(_caller('Database-BI')),
		'nigelhorne/Geo-Coder-Free/.github/workflows/contract-body.yml@master',
		'a caller is seen to name the body';
	is _body_reference(_caller('Geo-Coder-Free', uses => './.github/workflows/contract-body.yml')),
		'./.github/workflows/contract-body.yml',
		'a local call is named as written';
	is _body_reference("name: x\non: workflow_dispatch\n"), undef,
		'and a file that calls nothing names nothing';

	is _distribution_input(_caller('Database-BI')), 'Database-BI',
		'the distribution a caller passes is read';
	is _distribution_input($body), undef,
		"the body's input declaration, which has no value, is not read as one";

	my $copy = _caller('Database-BI', extra => <<'YAML');

      - name: Check that the workspace is there
        run: |
          for dist in Geo-Coder-Free Database-BI; do :; done
YAML
	is_deeply _body_work($copy), ['a workspace loop'],
		'a caller that went back to carrying a copy of the job is caught';

	my $commented = "#          path: workspace/Geo-Location-Point\n" . _caller('Database-BI');
	is_deeply _body_work($commented), [],
		'a commented-out checkout is not a checkout';

	my $elsewhere = _caller('Database-BI', extra => "    working-directory: workspace/Geo-Location-Point\n");
	is_deeply _body_work($elsewhere), [],
		'and a working-directory is not a checkout either';
};

subtest 'the body' => sub {
	my $text = $BODY_TEXT;

	like $text, qr/^[ \t]+workflow_call:[ \t]*$/m,
		'it is callable, so the four distributions can share it';

	for my $input (qw(distribution repository ref)) {
		like $text, qr/^ {6}\Q$input\E:[ \t]*$/m,
			"it takes a $input input from its caller";
	}

	my @listed = _env_list($text, 'DISTRIBUTIONS');
	ok scalar(@listed), 'it names the distributions it assembles' or return;

	my %checked = _checked_out($text);
	my $wildcard = delete $checked{'*'};

	my @unchecked = grep { !$checked{$_} } @listed;
	is_deeply \@unchecked, [], 'and checks out every distribution it lists'
		or diag(explain(\@unchecked));

	ok $wildcard, 'its self checkout is the one the caller names';

	like $text, qr/for[ \t]+dist[ \t]+in[ \t]+\$DISTRIBUTIONS\b/,
		'the workspace check reads the same list, so the two cannot disagree';

	like $text, qr/distribution '\$SELF' is not one of/,
		'and a caller naming itself something else is refused, not half-run';

	like $text, qr/remote get-url origin/,
		'the self checkout is checked to be the repository the caller named';

	# The contract loads these two from the workspace rather than from CPAN,
	# and @INC alone does not bring their dependencies: without them the first
	# require bails under CONTRACT_STRICT, before any test runs, which is how
	# this job failed from its first run until the checker's installdeps was
	# added.  A body that drops one cannot be caught by running the suite.
	for my $checkout (qw(Test-Consumer-Contract Geo-Location-Point)) {
		like $text,
			qr{^[ \t]*cpanm\b[^\n]*--installdeps[ \t]+\./workspace/\Q$checkout\E[ \t]*$}m,
			"it installs ${checkout}'s own dependencies";
	}

	like $text, qr{working-directory: workspace/Geo-Coder-Free},
		'it runs the contract from the producer checkout';
};

# A reusable workflow is fetched from the repository at the ref a caller names,
# so a copy that exists only in a working tree is one no caller can run.  That
# is how Database-BI's contract job failed with "failed to fetch workflow:
# workflow was not found" while this file passed: it read the body from disk,
# which for a few hours was the only place the body was.  The check is in the
# suite rather than in a reviewer's head because the state is invisible - a
# body that is merely staged is already tracked, and a body that is not even
# staged looks like any other file in the editor.
subtest 'the body is in the repository, not only on disk' => sub {
	my $root = abs_path(catdir($Bin, updir()));

	my $inside = qx{git -C "$root" rev-parse --is-inside-work-tree 2>/dev/null};
	plan skip_all => 'not a git checkout, so there is no index to ask'
		unless defined $inside && $inside =~ /\Atrue/;

	my @listed = qx{git -C "$root" ls-files .github/workflows/contract-body.yml 2>/dev/null};
	chomp @listed;
	my @tracked = grep { m{\Q.github/workflows/contract-body.yml\E\z} } @listed;

	ok scalar(@tracked),
		'contract-body.yml is tracked, so the callers in the other distributions can fetch it'
		or diag('a caller names it as <repository>/.github/workflows/contract-body.yml@<ref>;'
			. ' a copy that has never been added to the repository is not there to fetch,'
			. ' whatever this working tree contains');
};

# The checkouts under the workspace: the four distributions that run the job,
# and the siblings that are only checked out.  Hidden directories are not
# checkouts, and neither are plain files.
sub _directories {
	opendir(my $dh, $WORKSPACE) or return ();
	my @names = sort grep { !/\A\./ && -d catdir($WORKSPACE, $_) } readdir($dh);
	closedir($dh);

	return @names;
}

for my $caller (@callers) {
	# Named by distribution in the test names, so a failure says which of the
	# four to fix rather than only what it is missing.
	(my $label = $caller) =~ s/^\Q$WORKSPACE\E\///;
	$label =~ s{/\.github/workflows/contract\.yml\z}{};

	my $text = _slurp($caller);
	ok defined $text, "${label}'s contract.yml is readable" or next;

	my $reference = _body_reference($text);
	ok defined $reference, "$label calls the shared body"
		or next;

	if ($reference =~ /\A\.\//) {
		is $label, 'Geo-Coder-Free',
			'only the distribution that owns the body calls it by local path, so a change to it is tested by the pull request that makes it';
	} else {
		like $reference, qr{\A[\w.-]+/[\w.-]+/\.github/workflows/contract-body\.yml\@\S+\z},
			"$label calls it by repository and ref";
	}

	is _distribution_input($text), $label,
		"$label names itself as the distribution to check out at this commit";

	like $text, qr/^ {6}repository:[ \t]*\$\{\{[ \t]*github\.repository[ \t]*\}\}[ \t]*$/m,
		"$label hands the repository to check out to the body";
	like $text, qr/^ {6}ref:[ \t]*\$\{\{[ \t]*github\.ref[ \t]*\}\}[ \t]*$/m,
		"$label hands the ref to check out to the body";
	like $text, qr/^ {4}secrets:[ \t]*inherit[ \t]*$/m,
		"$label passes the workspace secret through";

	my $work = _body_work($text);
	is_deeply $work, [], "$label carries none of the body's work"
		or diag(explain($work));
}

done_testing();
