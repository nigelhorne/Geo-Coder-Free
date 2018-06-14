#!perl -w

use strict;

use Test::Most tests => 16;

BIN: {
	eval 'use Test::Script';
	if($@) {
		plan skip_all => 'Test::Script required for testing scripts';
	} else {
		SKIP: {
			script_compiles('bin/testcgibin');
			if($ENV{AUTHOR_TESTING}) {
				script_runs(['bin/testcgibin', 1]);
				ok(script_stdout_like(qr/\-77\.03/, 'test 1'));
				ok(script_stderr_is('', 'no error output'));

				script_runs(['bin/testcgibin', 2]);
				ok(script_stdout_like(qr/\-77\.01/, 'test 2'));
				ok(script_stderr_is('', 'no error output'));

				script_runs(['bin/testcgibin', 3]);
				ok(script_stdout_like(qr/\-77\.03/, 'test 3'));
				ok(script_stderr_is('', 'no error output'));
			} else {
				diag('Author tests not required for installation');
				skip('Author tests not required for installation', 16);
			}
		}
	}
}
