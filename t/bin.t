#!perl -w

use strict;

use Test::Needs {
	'Test::Script' => 1.12, 'CGI::Carp' => 0, 'FCGI' => 0, 'FCGI::Buffer' => 0, 'Log::WarnDie' => 0,
	'CGI::ACL' => 0
};
use Test::Most;

BIN: {
	# The scripts this file runs look their answers up in a database, so without
	# OPENADDR_HOME there is nothing here to test: the file says so and stops,
	# rather than padding itself out to a count that a plan declares and that the
	# next person to add a test has to keep in step.
	if(!defined($ENV{'OPENADDR_HOME'})) {
		plan skip_all => 'Set OPENADDR_HOME required for testing scripts';
	} else {
		Test::Script->import();

		script_compiles('bin/testcgibin');
		script_compiles('bin/address_lookup');

		if($ENV{AUTHOR_TESTING}) {
			my $foo;
			script_runs(['bin/testcgibin', 3], { stdout => \$foo });
			diag($foo);

			script_runs(['bin/testcgibin', 1]);
			ok(script_stdout_like(qr/\-76\.84/, 'test 1'));
			# ok(script_stderr_is('', 'no error output'));

			script_runs(['bin/testcgibin', 2]);
			ok(script_stdout_like(qr/\-77\.01/, 'test 2'));
			ok(script_stderr_is('', 'no error output'));

			script_runs(['bin/testcgibin', 3]);
			ok(script_stdout_like(qr/\-76\.84/, 'test 3'));
			ok(script_stderr_is('', 'no error output'));

			script_runs(['bin/testcgibin', 4]);
			ok(script_stdout_like(qr/\-76\.84/, 'test 4'));
			ok(script_stderr_is('', 'no error output'));

			# A street address needs the OpenStreetMap or the WhosOnFirst data
			# to resolve, and there is no assertion to make without it.
			if($ENV{'OSM_HOME'} || $ENV{'WHOSONFIRST_HOME'}) {
				script_runs(['bin/address_lookup', 'Fairfield Road,', 'Broadstairs,', ' Kent,', ' UK']);
				ok(script_stdout_like(qr/51\.3/, 'test 5'));
				ok(script_stderr_is('', 'no error output'));
			} else {
				diag('Set OSM_HOME or WHOSONFIRST_HOME for street addresses');
			}
		} else {
			diag('Author tests not required for installation');
		}

		done_testing();
	}
}
