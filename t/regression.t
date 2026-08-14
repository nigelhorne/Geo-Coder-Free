#!/usr/bin/env perl

# t/regression.t — Guards against recurrence of specific bugs fixed in this
# codebase.  Each subtest names the defect and the file that was changed.
#
# REG-1  Utils.pm: _normalize/_abbreviate placed after __END__ — never compiled
# REG-2  Utils.pm: _normalize/_abbreviate absent from @EXPORT_OK — explicit
#         import croaked
# REG-3  t/lib/MyLogger.pm: error() called itself — deep recursion fatal
# REG-4  admin2.db + Makefile.PL: GB.ENG.G5 had 13 corrupt Tooting rows
#         appended on every Makefile.PL run; non-Linux sort returned Tooting
# REG-5  Local.pm: bare require Geo::Address::Parser died when module absent;
#         eval guard was missing

use strict;
use warnings;

use Test::Most;
use Test::Exception;

use lib 'lib';
use lib 't/lib';
use MyLogger;
use Geo::Coder::Free::Local;
use Geo::Coder::Free::Utils;

# One Local object shared across subtests — __DATA__ filehandle is one-shot.
my $LOCAL = Geo::Coder::Free::Local->new();

# -----------------------------------------------------------------------
# REG-1: _normalize and _abbreviate were placed after __END__ in Utils.pm
#         and were therefore never compiled by the Perl parser.
#         perl -c reports "syntax OK" even in this case, so the bug is
#         invisible until the functions are actually called at runtime.
# -----------------------------------------------------------------------
subtest 'REG-1: Utils::_normalize and _abbreviate are compiled and callable' => sub {
	plan tests => 4;

	ok(defined(&Geo::Coder::Free::Utils::_normalize),
		'_normalize sub is defined — was absent when placed after __END__');
	ok(defined(&Geo::Coder::Free::Utils::_abbreviate),
		'_abbreviate sub is defined — was absent when placed after __END__');

	my $n = Geo::Coder::Free::Utils::_normalize('04TH AVENUE');
	ok(defined $n, '_normalize returns a defined value');
	unlike($n, qr/^0/, '_normalize strips leading zeros (04TH → 4TH)');
};

# -----------------------------------------------------------------------
# REG-2: _normalize and _abbreviate were in @EXPORT but not @EXPORT_OK.
#         Exporter allows default export but rejects explicit named import
#         (use Module qw(name)) for symbols absent from @EXPORT_OK.
# -----------------------------------------------------------------------
subtest 'REG-2: explicit import of _normalize and _abbreviate does not croak' => sub {
	plan tests => 2;

	# Before the fix: "\"_normalize\" is not exported by ... module"
	lives_ok {
		Geo::Coder::Free::Utils->import('_normalize');
	} 'explicit import of _normalize succeeds (@EXPORT_OK populated)';

	lives_ok {
		Geo::Coder::Free::Utils->import('_abbreviate');
	} 'explicit import of _abbreviate succeeds (@EXPORT_OK populated)';
};

# -----------------------------------------------------------------------
# REG-3: MyLogger::error called error(@_) — unconditional self-recursion.
#         Database::Abstraction calls $logger->error() on init failures,
#         which caused the test process to exhaust the call stack on BSD
#         CI runners where the database file was absent.
# -----------------------------------------------------------------------
subtest 'REG-3: MyLogger::error does not recurse into itself' => sub {
	plan tests => 2;

	my $logger = MyLogger->new();

	# Before the fix this would die: "Deep recursion on subroutine MyLogger::error"
	lives_ok { $logger->error('test error') }
		'MyLogger::error completes without deep-recursion fatal';

	lives_ok { $logger->error(undef) }
		'MyLogger::error handles undef without croak';
};

# -----------------------------------------------------------------------
# REG-4: admin2.db had 13 duplicate GB.ENG.G5→Tooting lines appended by
#         Makefile.PL on every build.  Kent's own entry existed but was
#         shadowed on BSD/macOS where file iteration order differs from Linux.
#         Fix: removed the wrong entry from the Makefile.PL append block
#         and stripped the duplicates from the committed admin2.db.
# -----------------------------------------------------------------------
subtest 'REG-4: admin2.db has exactly one GB.ENG.G5 entry and it is Kent' => sub {
	my $db = 'lib/Geo/Coder/Free/MaxMind/databases/admin2.db';
	unless(-f $db) {
		plan tests => 1;
		pass('admin2.db not present — skipping data-integrity check');
		return;
	}
	plan tests => 3;

	open(my $fh, '<', $db) or BAIL_OUT("Cannot open $db: $!");
	my @g5 = grep { /^GB\.ENG\.G5\t/ } <$fh>;
	close $fh;

	is(scalar @g5, 1,
		'exactly one line for GB.ENG.G5 (no corrupt duplicates from Makefile.PL)');
	like($g5[0], qr/\tKent\t/,
		'GB.ENG.G5 maps to Kent');
	unlike(join('', @g5), qr/Tooting/,
		'no Tooting under GB.ENG.G5 (Makefile.PL append block no longer wrong)');
};

# -----------------------------------------------------------------------
# REG-5: Local.pm line ~470 called `require Geo::Address::Parser` without
#         an eval guard.  When the optional module is not installed, the bare
#         require propagated "Can't locate ..." as a fatal error even though
#         the unless(->can) guard ran first (it returned false, so the
#         require executed, and it died).
#         Fix: wrapped in eval { require ...; ->import() }.
# -----------------------------------------------------------------------
subtest 'REG-5: missing Geo::Address::Parser does not kill UK geocode' => sub {
	# If the module IS installed, the eval path is never reached; skip gracefully.
	if(eval { require Geo::Address::Parser; 1 }) {
		plan tests => 1;
		pass('Geo::Address::Parser is installed — eval guard path not exercisable here');
		return;
	}
	plan tests => 1;

	# "10 High Street, Canterbury, Kent, England" has 3 commas (4 parts) so it
	# bypasses the early-return guard and reaches the require at line ~470.
	# Before the fix this died: "Can't locate Geo/Address/Parser.pm in @INC"
	lives_ok {
		$LOCAL->geocode(location => '10 High Street, Canterbury, Kent, England');
	} 'UK geocode returns cleanly when Geo::Address::Parser is absent (eval guard)';
};

done_testing();
